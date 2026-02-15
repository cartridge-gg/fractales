const HARVEST_ENERGY_PER_UNIT: u16 = 10_u16;
const HARVEST_TIME_PER_UNIT: u16 = 2_u16;
const ENERGY_REGEN_PER_100_BLOCKS: u16 = 20_u16;
const WORLD_GEN_VERSION_ACTIVE: u16 = 2_u16;
const PHASE_INIT: felt252 = 'INIT'_felt252;
const PHASE_START: felt252 = 'START'_felt252;
const PHASE_COMPLETE: felt252 = 'COMPLETE'_felt252;
const PHASE_CANCEL: felt252 = 'CANCEL'_felt252;

#[starknet::interface]
pub trait IHarvestingManager<T> {
    fn init_harvesting(
        ref self: T,
        hex_coordinate: felt252,
        area_id: felt252,
        plant_id: u8,
    ) -> bool;
    fn start_harvesting(
        ref self: T,
        adventurer_id: felt252,
        hex_coordinate: felt252,
        area_id: felt252,
        plant_id: u8,
        amount: u16,
    ) -> bool;
    fn complete_harvesting(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
    ) -> u16;
    fn cancel_harvesting(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
    ) -> u16;
    fn inspect_plant(self: @T, hex_coordinate: felt252, area_id: felt252, plant_id: u8)
        -> dojo_starter::models::harvesting::PlantNode;
}

#[dojo::contract]
pub mod harvesting_manager {
    use super::{
        ENERGY_REGEN_PER_100_BLOCKS, HARVEST_ENERGY_PER_UNIT,
        HARVEST_TIME_PER_UNIT, IHarvestingManager, PHASE_CANCEL, PHASE_COMPLETE, PHASE_INIT,
        PHASE_START, WORLD_GEN_VERSION_ACTIVE,
    };
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::harvesting_events::{
        HarvestingCancelled, HarvestingCompleted, HarvestingRejected, HarvestingStarted,
    };
    use dojo_starter::libs::construction_balance::{
        B_GREENHOUSE, B_STOREHOUSE, effect_bp_for_building,
    };
    use dojo_starter::libs::sharing_math::{PERM_EXTRACT, alloc_from_bp_floor_u32, has_permissions};
    use dojo_starter::models::construction::{ConstructionBuildingNode, is_building_effective};
    use dojo_starter::libs::world_gen::derive_plant_profile_with_config;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{
        HarvestReservation, PlantNode, derive_harvest_item_id, derive_harvest_reservation_id,
        derive_plant_key,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::sharing::{
        ResourceAccessGrant, ResourceKind, ResourcePolicy, derive_area_resource_key, is_grant_effective,
        is_policy_effective, is_share_rule_effective, ResourceShareRule, ResourceShareRuleTally, ShareRuleKind,
    };
    use dojo_starter::models::world::{AreaType, Hex, HexArea, WorldGenConfig, derive_area_id};
    use dojo_starter::systems::harvesting_manager::{
        CancelOutcome, CompleteOutcome, InitOutcome, StartOutcome, cancel_transition, complete_transition,
        init_transition, start_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    const BP_ONE: u16 = 10_000_u16;
    const U16_MAX_U128: u128 = 65_535_u128;
    const U32_MAX_U128: u128 = 4_294_967_295_u128;

    fn apply_bp_floor_u16(value: u16, bp: u16) -> u16 {
        if value == 0_u16 || bp == 0_u16 {
            return 0_u16;
        }

        let scaled_u128: u128 = value.into() * bp.into() / BP_ONE.into();
        if scaled_u128 > U16_MAX_U128 {
            65_535_u16
        } else {
            scaled_u128.try_into().unwrap()
        }
    }

    fn apply_bp_floor_u32(value: u32, bp: u16) -> u32 {
        if value == 0_u32 || bp == 0_u16 {
            return 0_u32;
        }

        let scaled_u128: u128 = value.into() * bp.into() / BP_ONE.into();
        if scaled_u128 > U32_MAX_U128 {
            4_294_967_295_u32
        } else {
            scaled_u128.try_into().unwrap()
        }
    }

    fn bonus_extra_from_bp(base_value: u16, bp: u16) -> u16 {
        if bp <= BP_ONE {
            return 0_u16;
        }
        apply_bp_floor_u16(base_value, bp - BP_ONE)
    }

    fn active_hex_building_effect_bp(
        ref world: dojo::world::WorldStorage, hex_coordinate: felt252, building_type: felt252,
    ) -> u16 {
        let base_bp = effect_bp_for_building(building_type);
        if base_bp == 0_u16 {
            return BP_ONE;
        }

        let hex: Hex = world.read_model(hex_coordinate);
        let mut idx: u8 = 0_u8;
        loop {
            if idx >= hex.area_count {
                break;
            };

            let area_id = derive_area_id(hex_coordinate, idx);
            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;

            if building.hex_coordinate == hex_coordinate && building.building_type == building_type
                && is_building_effective(building) {
                return base_bp;
            }

            idx += 1_u8;
        };

        BP_ONE
    }

    fn effective_capacity_with_storehouse(max_weight: u32, storehouse_bp: u16) -> u32 {
        if storehouse_bp <= BP_ONE {
            return max_weight;
        }
        let boosted = apply_bp_floor_u32(max_weight, storehouse_bp);
        if boosted < max_weight { max_weight } else { boosted }
    }

    fn mint_bonus_item_with_capacity(
        mut inventory: Inventory,
        mut item: BackpackItem,
        quantity: u16,
        quality: u16,
        effective_max_weight: u32,
    ) -> (Inventory, BackpackItem, u16) {
        if quantity == 0_u16 {
            return (inventory, item, 0_u16);
        }

        let capacity_left = if effective_max_weight > inventory.current_weight {
            effective_max_weight - inventory.current_weight
        } else {
            0_u32
        };
        let desired_u32: u32 = quantity.into();
        let minted_u32 = if desired_u32 > capacity_left { capacity_left } else { desired_u32 };
        if minted_u32 > 0_u32 {
            inventory.current_weight += minted_u32;
            item.quantity += minted_u32;
            item.quality = quality;
            item.weight_per_unit = 1_u16;
        }

        (inventory, item, minted_u32.try_into().unwrap())
    }

    fn init_outcome_reason(outcome: InitOutcome) -> felt252 {
        match outcome {
            InitOutcome::HexUndiscovered => 'HEX_UNDISC'_felt252,
            InitOutcome::AreaUndiscovered => 'AREA_UNDISC'_felt252,
            InitOutcome::AreaNotPlantField => 'NOT_PLANT'_felt252,
            InitOutcome::PlantIdOutOfRange => 'PLANT_RANGE'_felt252,
            InitOutcome::AlreadyInitialized => 'ALREADY_INIT'_felt252,
            InitOutcome::InvalidConfig => 'BAD_CONFIG'_felt252,
            InitOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn start_outcome_reason(outcome: StartOutcome) -> felt252 {
        match outcome {
            StartOutcome::Dead => 'DEAD'_felt252,
            StartOutcome::NotOwner => 'NOT_OWNER'_felt252,
            StartOutcome::WrongHex => 'WRONG_HEX'_felt252,
            StartOutcome::Locked => 'LOCKED'_felt252,
            StartOutcome::NotInitialized => 'NOT_INIT'_felt252,
            StartOutcome::AlreadyActive => 'ACTIVE'_felt252,
            StartOutcome::InvalidAmount => 'BAD_AMOUNT'_felt252,
            StartOutcome::InvalidPlantState => 'BAD_PLANT'_felt252,
            StartOutcome::InsufficientYield => 'LOW_YIELD'_felt252,
            StartOutcome::InsufficientEnergy => 'LOW_ENERGY'_felt252,
            StartOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn complete_outcome_reason(outcome: CompleteOutcome) -> felt252 {
        match outcome {
            CompleteOutcome::Dead => 'DEAD'_felt252,
            CompleteOutcome::NotOwner => 'NOT_OWNER'_felt252,
            CompleteOutcome::WrongHex => 'WRONG_HEX'_felt252,
            CompleteOutcome::NoActiveReservation => 'NO_ACTIVE'_felt252,
            CompleteOutcome::NotLinked => 'NOT_LINKED'_felt252,
            CompleteOutcome::TooEarly => 'TOO_EARLY'_felt252,
            CompleteOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn cancel_outcome_reason(outcome: CancelOutcome) -> felt252 {
        match outcome {
            CancelOutcome::Dead => 'DEAD'_felt252,
            CancelOutcome::NotOwner => 'NOT_OWNER'_felt252,
            CancelOutcome::WrongHex => 'WRONG_HEX'_felt252,
            CancelOutcome::NoActiveReservation => 'NO_ACTIVE'_felt252,
            CancelOutcome::NotLinked => 'NOT_LINKED'_felt252,
            CancelOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn has_harvest_access(
        ref world: dojo::world::WorldStorage,
        area_id: felt252,
        adventurer_id: felt252,
    ) -> bool {
        let mut ownership: AreaOwnership = world.read_model(area_id);
        ownership.area_id = area_id;
        if ownership.owner_adventurer_id == 0_felt252 {
            return true;
        }
        if ownership.owner_adventurer_id == adventurer_id {
            return true;
        }

        let resource_key = derive_area_resource_key(area_id, ResourceKind::PlantArea);
        let mut policy: ResourcePolicy = world.read_model(resource_key);
        policy.resource_key = resource_key;
        if !is_policy_effective(policy) {
            return false;
        }
        if policy.controller_adventurer_id == adventurer_id {
            return true;
        }

        let mut grant: ResourceAccessGrant = world.read_model((resource_key, adventurer_id));
        grant.resource_key = resource_key;
        grant.grantee_adventurer_id = adventurer_id;
        is_grant_effective(grant, policy.policy_epoch)
            && has_permissions(grant.permissions_mask, PERM_EXTRACT)
    }

    fn recipient_from_slot(tally: ResourceShareRuleTally, slot: u8) -> felt252 {
        match slot {
            0_u8 => tally.recipient_0,
            1_u8 => tally.recipient_1,
            2_u8 => tally.recipient_2,
            3_u8 => tally.recipient_3,
            4_u8 => tally.recipient_4,
            5_u8 => tally.recipient_5,
            6_u8 => tally.recipient_6,
            7_u8 => tally.recipient_7,
            _ => 0_felt252,
        }
    }

    fn apply_shared_item_distribution(
        ref world: dojo::world::WorldStorage,
        area_id: felt252,
        actor_adventurer_id: felt252,
        item_id: felt252,
        gross_minted: u16,
        mut actor_inventory: Inventory,
        mut actor_item: BackpackItem,
    ) -> (Inventory, BackpackItem) {
        if gross_minted == 0_u16 {
            return (actor_inventory, actor_item);
        }

        let resource_key = derive_area_resource_key(area_id, ResourceKind::PlantArea);
        let mut policy: ResourcePolicy = world.read_model(resource_key);
        policy.resource_key = resource_key;
        if !is_policy_effective(policy) {
            return (actor_inventory, actor_item);
        }

        let mut tally: ResourceShareRuleTally = world.read_model((resource_key, ShareRuleKind::OutputItem));
        tally.resource_key = resource_key;
        tally.rule_kind = ShareRuleKind::OutputItem;
        if tally.policy_epoch != policy.policy_epoch || tally.active_recipient_count == 0_u8 {
            return (actor_inventory, actor_item);
        }

        let gross_u32: u32 = gross_minted.into();
        let mut slot: u8 = 0_u8;
        loop {
            if slot >= 8_u8 {
                break;
            };

            let recipient_adventurer_id = recipient_from_slot(tally, slot);
            if recipient_adventurer_id != 0_felt252 && recipient_adventurer_id != actor_adventurer_id {
                let mut rule: ResourceShareRule = world.read_model(
                    (resource_key, recipient_adventurer_id, ShareRuleKind::OutputItem),
                );
                rule.resource_key = resource_key;
                rule.recipient_adventurer_id = recipient_adventurer_id;
                rule.rule_kind = ShareRuleKind::OutputItem;

                if is_share_rule_effective(rule, policy.policy_epoch) {
                    let requested_u32 = alloc_from_bp_floor_u32(gross_u32, rule.share_bp);
                    if requested_u32 > 0_u32 && actor_item.quantity > 0_u32 {
                        let actor_available = actor_item.quantity;
                        let request_capped = if requested_u32 > actor_available {
                            actor_available
                        } else {
                            requested_u32
                        };

                        let mut recipient_inventory: Inventory = world.read_model(recipient_adventurer_id);
                        let mut recipient_item: BackpackItem = world.read_model(
                            (recipient_adventurer_id, item_id),
                        );
                        recipient_item.adventurer_id = recipient_adventurer_id;
                        recipient_item.item_id = item_id;

                        let recipient_capacity = if recipient_inventory.max_weight > recipient_inventory.current_weight {
                            recipient_inventory.max_weight - recipient_inventory.current_weight
                        } else {
                            0_u32
                        };
                        let transferable_u32 = if request_capped > recipient_capacity {
                            recipient_capacity
                        } else {
                            request_capped
                        };

                        if transferable_u32 > 0_u32 {
                            actor_item.quantity -= transferable_u32;
                            actor_inventory.current_weight = if actor_inventory.current_weight > transferable_u32 {
                                actor_inventory.current_weight - transferable_u32
                            } else {
                                0_u32
                            };

                            recipient_inventory.current_weight += transferable_u32;
                            recipient_item.quantity += transferable_u32;
                            if recipient_item.quality == 0_u16 {
                                recipient_item.quality = actor_item.quality;
                            }
                            if recipient_item.weight_per_unit == 0_u16 {
                                recipient_item.weight_per_unit = 1_u16;
                            }

                            world.write_model(@recipient_inventory);
                            world.write_model(@recipient_item);
                        }
                    }
                }
            }

            slot += 1_u8;
        };

        (actor_inventory, actor_item)
    }

    #[abi(embed_v0)]
    impl HarvestingManagerImpl of IHarvestingManager<ContractState> {
        fn init_harvesting(
            ref self: ContractState,
            hex_coordinate: felt252,
            area_id: felt252,
            plant_id: u8,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let hex: Hex = world.read_model(hex_coordinate);
            let area: HexArea = world.read_model(area_id);
            let area_is_discovered = area.area_id == area_id && area.hex_coordinate == hex_coordinate
                && area.is_discovered;
            let area_is_plant_field = area.area_type == AreaType::PlantField;
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let mut plant: PlantNode = world.read_model(plant_key);
            plant.plant_key = plant_key;
            plant.hex_coordinate = hex_coordinate;
            plant.area_id = area_id;
            plant.plant_id = plant_id;
            let world_gen_config: WorldGenConfig = world.read_model(WORLD_GEN_VERSION_ACTIVE);
            let plant_id_in_range = if hex.is_discovered && area_is_discovered && area_is_plant_field {
                plant_id < area.plant_slot_count
            } else {
                true
            };

            let generated = derive_plant_profile_with_config(
                hex_coordinate, area_id, plant_id, hex.biome, world_gen_config,
            );

            let initialized = init_transition(
                plant,
                caller,
                hex.is_discovered,
                area_is_discovered,
                area_is_plant_field,
                plant_id_in_range,
                generated.species,
                generated.max_yield,
                generated.regrowth_rate,
                generated.genetics_hash,
                block_number,
            );

            match initialized.outcome {
                InitOutcome::Applied => {
                    world.write_model(@initialized.plant);
                    true
                },
                _ => {
                    world.emit_event(
                        @HarvestingRejected {
                            adventurer_id: 0_felt252,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            phase: PHASE_INIT,
                            reason: init_outcome_reason(initialized.outcome),
                        },
                    );
                    false
                },
            }
        }

        fn start_harvesting(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_id: felt252,
            plant_id: u8,
            amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);

            if !has_harvest_access(ref world, area_id, adventurer_id) {
                world.emit_event(
                    @HarvestingRejected {
                        adventurer_id,
                        hex: hex_coordinate,
                        area_id,
                        plant_id,
                        phase: PHASE_START,
                        reason: 'NO_ACCESS'_felt252,
                    },
                );
                return false;
            }

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let started = start_transition(
                adventurer,
                economics,
                caller,
                plant,
                reservation,
                amount,
                block_number,
                ENERGY_REGEN_PER_100_BLOCKS,
                HARVEST_ENERGY_PER_UNIT,
                HARVEST_TIME_PER_UNIT,
            );

            match started.outcome {
                StartOutcome::Applied => {
                    world.write_model(@started.adventurer);
                    world.write_model(@started.economics);
                    world.write_model(@started.plant);
                    world.write_model(@started.reservation);
                    world.emit_event(
                        @HarvestingStarted {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            amount,
                            eta: started.eta,
                        },
                    );
                    true
                },
                StartOutcome::InsufficientEnergy => {
                    world.write_model(@started.adventurer);
                    world.write_model(@started.economics);
                    world.emit_event(
                        @HarvestingRejected {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            phase: PHASE_START,
                            reason: start_outcome_reason(started.outcome),
                        },
                    );
                    false
                },
                _ => {
                    world.emit_event(
                        @HarvestingRejected {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            phase: PHASE_START,
                            reason: start_outcome_reason(started.outcome),
                        },
                    );
                    false
                },
            }
        }

        fn complete_harvesting(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);
            let greenhouse_bp = active_hex_building_effect_bp(ref world, hex_coordinate, B_GREENHOUSE);
            let storehouse_bp = active_hex_building_effect_bp(ref world, hex_coordinate, B_STOREHOUSE);
            let effective_max_weight = effective_capacity_with_storehouse(inventory.max_weight, storehouse_bp);
            let mut inventory_for_transition = inventory;
            inventory_for_transition.max_weight = effective_max_weight;

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let item_id = derive_harvest_item_id(plant_key);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let completed = complete_transition(
                adventurer, caller, plant, reservation, inventory_for_transition, item, block_number,
            );
            match completed.outcome {
                CompleteOutcome::Applied => {
                    let bonus_raw = bonus_extra_from_bp(completed.actual_yield, greenhouse_bp);
                    let quality_for_bonus = if completed.item.quality == 0_u16 {
                        completed.plant.health
                    } else {
                        completed.item.quality
                    };
                    let (mut inventory_with_bonus, item_with_bonus, _) = mint_bonus_item_with_capacity(
                        completed.inventory,
                        completed.item,
                        bonus_raw,
                        quality_for_bonus,
                        effective_max_weight,
                    );
                    let (distributed_inventory, distributed_item) = apply_shared_item_distribution(
                        ref world,
                        area_id,
                        adventurer_id,
                        item_id,
                        completed.minted_yield,
                        inventory_with_bonus,
                        item_with_bonus,
                    );
                    inventory_with_bonus = distributed_inventory;
                    inventory_with_bonus.max_weight = inventory.max_weight;

                    world.write_model(@completed.adventurer);
                    world.write_model(@completed.plant);
                    world.write_model(@completed.reservation);
                    world.write_model(@inventory_with_bonus);
                    world.write_model(@distributed_item);
                    world.emit_event(
                        @HarvestingCompleted {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            actual_yield: completed.actual_yield,
                        },
                    );
                    completed.actual_yield
                },
                _ => {
                    world.emit_event(
                        @HarvestingRejected {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            phase: PHASE_COMPLETE,
                            reason: complete_outcome_reason(completed.outcome),
                        },
                    );
                    0_u16
                },
            }
        }

        fn cancel_harvesting(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);
            let greenhouse_bp = active_hex_building_effect_bp(ref world, hex_coordinate, B_GREENHOUSE);
            let storehouse_bp = active_hex_building_effect_bp(ref world, hex_coordinate, B_STOREHOUSE);
            let effective_max_weight = effective_capacity_with_storehouse(inventory.max_weight, storehouse_bp);
            let mut inventory_for_transition = inventory;
            inventory_for_transition.max_weight = effective_max_weight;

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let item_id = derive_harvest_item_id(plant_key);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let canceled = cancel_transition(
                adventurer, caller, plant, reservation, inventory_for_transition, item, block_number,
            );
            match canceled.outcome {
                CancelOutcome::Applied => {
                    let bonus_raw = bonus_extra_from_bp(canceled.partial_yield, greenhouse_bp);
                    let quality_for_bonus = if canceled.item.quality == 0_u16 {
                        canceled.plant.health
                    } else {
                        canceled.item.quality
                    };
                    let (mut inventory_with_bonus, item_with_bonus, _) = mint_bonus_item_with_capacity(
                        canceled.inventory,
                        canceled.item,
                        bonus_raw,
                        quality_for_bonus,
                        effective_max_weight,
                    );
                    let (distributed_inventory, distributed_item) = apply_shared_item_distribution(
                        ref world,
                        area_id,
                        adventurer_id,
                        item_id,
                        canceled.minted_yield,
                        inventory_with_bonus,
                        item_with_bonus,
                    );
                    inventory_with_bonus = distributed_inventory;
                    inventory_with_bonus.max_weight = inventory.max_weight;

                    world.write_model(@canceled.adventurer);
                    world.write_model(@canceled.plant);
                    world.write_model(@canceled.reservation);
                    world.write_model(@inventory_with_bonus);
                    world.write_model(@distributed_item);
                    world.emit_event(
                        @HarvestingCancelled {
                            adventurer_id,
                            partial_yield: canceled.partial_yield,
                        },
                    );
                    canceled.partial_yield
                },
                _ => {
                    world.emit_event(
                        @HarvestingRejected {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            phase: PHASE_CANCEL,
                            reason: cancel_outcome_reason(canceled.outcome),
                        },
                    );
                    0_u16
                },
            }
        }

        fn inspect_plant(self: @ContractState, hex_coordinate: felt252, area_id: felt252, plant_id: u8) -> PlantNode {
            let world = self.world_default();
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            world.read_model(plant_key)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
