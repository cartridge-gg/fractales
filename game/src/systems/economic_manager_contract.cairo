const CONVERSION_WINDOW_BLOCKS: u64 = 100_u64;
const DECAY_PERIOD_BLOCKS: u64 = 100_u64;
const CLAIM_TIMEOUT_BLOCKS: u64 = 100_u64;
const CLAIM_GRACE_BLOCKS: u64 = 500_u64;
const CLAIMABLE_DECAY_THRESHOLD: u16 = 80_u16;
const DECAY_RECOVERY_BP: u16 = 20_u16;

#[starknet::interface]
pub trait IEconomicManager<T> {
    fn convert_items_to_energy(
        ref self: T, adventurer_id: felt252, item_id: felt252, quantity: u16,
    ) -> u16;
    fn pay_hex_maintenance(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, amount: u16,
    ) -> bool;
    fn process_hex_decay(ref self: T, hex_coordinate: felt252) -> u16;
    fn initiate_hex_claim(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, energy_offered: u16,
    ) -> bool;
    fn defend_hex_from_claim(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, defense_energy: u16,
    ) -> bool;
}

#[dojo::contract]
pub mod economic_manager {
    use super::{
        CLAIMABLE_DECAY_THRESHOLD, CLAIM_GRACE_BLOCKS, CLAIM_TIMEOUT_BLOCKS, CONVERSION_WINDOW_BLOCKS,
        DECAY_PERIOD_BLOCKS, DECAY_RECOVERY_BP, IEconomicManager,
    };
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::economic_events::{
        ClaimExpired, ClaimInitiated, ClaimRefunded, HexBecameClaimable, HexDefended, HexEnergyPaid,
        ItemsConverted,
    };
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::libs::construction_balance::{
        B_HERBAL_PRESS, B_SMELTER, B_WATCHTOWER, I_ORE_COAL, I_ORE_COBALT, I_ORE_COPPER,
        I_ORE_IRON, I_ORE_NICKEL, I_ORE_TIN, I_PLANT_COMPOUND, I_PLANT_FIBER, I_PLANT_RESIN,
        effect_bp_for_building,
    };
    use dojo_starter::libs::decay_math::{min_claim_energy, upkeep_for_biome};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::construction::{ConstructionBuildingNode, is_building_effective};
    use dojo_starter::models::economics::{
        AdventurerEconomics, ClaimEscrow, ClaimEscrowExpireOutcome, ClaimEscrowStatus,
        ConversionRate, HexDecayState, derive_hex_claim_id, expire_claim_escrow_once_with_status,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{Hex, derive_area_id};
    use dojo_starter::systems::economic_manager::{
        ClaimInitOutcome, ConvertOutcome, DecayOutcome, DefendOutcome, PayOutcome, convert_transition,
        defend_claim_transition, initiate_claim_transition, pay_maintenance_transition,
        process_decay_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    const U64_MAX_U128: u128 = 18_446_744_073_709_551_615_u128;
    const U16_MAX_U128: u128 = 65_535_u128;
    const BP_ONE: u16 = 10_000_u16;

    fn saturating_add_u16(lhs: u16, rhs: u16) -> u16 {
        let sum_u128: u128 = lhs.into() + rhs.into();
        if sum_u128 > U16_MAX_U128 {
            65_535_u16
        } else {
            sum_u128.try_into().unwrap()
        }
    }

    fn saturating_add_u64(lhs: u64, rhs: u64) -> u64 {
        let sum_u128: u128 = lhs.into() + rhs.into();
        if sum_u128 > U64_MAX_U128 {
            18_446_744_073_709_551_615_u64
        } else {
            sum_u128.try_into().unwrap()
        }
    }

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

    fn bonus_extra_from_bp(base_value: u16, bp: u16) -> u16 {
        if bp <= BP_ONE {
            return 0_u16;
        }
        apply_bp_floor_u16(base_value, bp - BP_ONE)
    }

    fn mint_bonus_energy_with_cap(
        mut adventurer: Adventurer, mut economics: AdventurerEconomics, raw_bonus: u16,
    ) -> (Adventurer, AdventurerEconomics, u16) {
        if raw_bonus == 0_u16 {
            return (adventurer, economics, 0_u16);
        }

        let cap_room = if adventurer.max_energy > adventurer.energy {
            adventurer.max_energy - adventurer.energy
        } else {
            0_u16
        };
        let minted = if raw_bonus > cap_room { cap_room } else { raw_bonus };
        if minted > 0_u16 {
            adventurer.energy += minted;
            economics.total_energy_earned = saturating_add_u64(economics.total_energy_earned, minted.into());
        }
        economics.energy_balance = adventurer.energy;
        (adventurer, economics, minted)
    }

    fn is_ore_item(item_id: felt252) -> bool {
        item_id == I_ORE_IRON || item_id == I_ORE_COAL || item_id == I_ORE_COPPER
            || item_id == I_ORE_TIN || item_id == I_ORE_NICKEL || item_id == I_ORE_COBALT
    }

    fn is_plant_material_item(item_id: felt252) -> bool {
        item_id == I_PLANT_FIBER || item_id == I_PLANT_RESIN || item_id == I_PLANT_COMPOUND
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

    fn conversion_bonus_bp_for_item(
        ref world: dojo::world::WorldStorage, hex_coordinate: felt252, item_id: felt252,
    ) -> u16 {
        if is_ore_item(item_id) {
            return active_hex_building_effect_bp(ref world, hex_coordinate, B_SMELTER);
        }
        if is_plant_material_item(item_id) {
            return active_hex_building_effect_bp(ref world, hex_coordinate, B_HERBAL_PRESS);
        }
        BP_ONE
    }

    fn settle_expired_claim_if_needed(
        ref world: dojo::world::WorldStorage,
        hex_coordinate: felt252,
        now_block: u64,
        escrow: ClaimEscrow,
    ) -> ClaimEscrow {
        if escrow.status != ClaimEscrowStatus::Active || now_block <= escrow.expiry_block {
            return escrow;
        }

        if escrow.claimant_adventurer_id == 0_felt252 {
            let mut invalid_expired = escrow;
            invalid_expired.status = ClaimEscrowStatus::Expired;
            invalid_expired.energy_locked = 0_u16;
            world.write_model(@invalid_expired);
            return invalid_expired;
        }

        let claimant_before: Adventurer = world.read_model(escrow.claimant_adventurer_id);
        let claimant_economics_before: AdventurerEconomics = world.read_model(escrow.claimant_adventurer_id);
        let expired = expire_claim_escrow_once_with_status(claimant_before, escrow, now_block);

        match expired.outcome {
            ClaimEscrowExpireOutcome::Applied => {
                let refunded = expired.adventurer.energy - claimant_before.energy;
                let mut claimant_economics_after = claimant_economics_before;
                claimant_economics_after.energy_balance = expired.adventurer.energy;
                claimant_economics_after.total_energy_earned = saturating_add_u64(
                    claimant_economics_after.total_energy_earned, refunded.into(),
                );

                world.write_model(@expired.adventurer);
                world.write_model(@claimant_economics_after);
                world.write_model(@expired.escrow);
                world.emit_event(
                    @ClaimExpired {
                        hex: hex_coordinate,
                        claim_id: expired.escrow.claim_id,
                        claimant: expired.escrow.claimant_adventurer_id,
                    },
                );
                world.emit_event(
                    @ClaimRefunded {
                        hex: hex_coordinate,
                        claim_id: expired.escrow.claim_id,
                        claimant: expired.escrow.claimant_adventurer_id,
                        amount: refunded,
                    },
                );
                expired.escrow
            },
            _ => escrow,
        }
    }

    fn sync_hex_area_ownership_controller(
        ref world: dojo::world::WorldStorage,
        hex_coordinate: felt252,
        controller_adventurer_id: felt252,
        claim_block: u64,
        set_claim_block: bool,
    ) {
        let hex: Hex = world.read_model(hex_coordinate);
        let mut idx: u8 = 0_u8;
        loop {
            if idx >= hex.area_count {
                break;
            };

            let area_id = derive_area_id(hex_coordinate, idx);
            let mut ownership: AreaOwnership = world.read_model(area_id);
            ownership.area_id = area_id;
            let previous_owner = ownership.owner_adventurer_id;
            ownership.owner_adventurer_id = controller_adventurer_id;
            if set_claim_block {
                ownership.claim_block = claim_block;
            }
            world.write_model(@ownership);

            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;
            if building.hex_coordinate == hex_coordinate && building.building_type != 0_felt252 {
                building.owner_adventurer_id = controller_adventurer_id;
                world.write_model(@building);
            }

            if previous_owner != 0_felt252 && previous_owner != controller_adventurer_id {
                world.emit_event(
                    @OwnershipTransferred {
                        area_id,
                        from_adventurer_id: previous_owner,
                        to_adventurer_id: controller_adventurer_id,
                        claim_block: ownership.claim_block,
                    },
                );
            }

            idx += 1_u8;
        };
    }

    #[abi(embed_v0)]
    impl EconomicManagerImpl of IEconomicManager<ContractState> {
        fn convert_items_to_energy(
            ref self: ContractState, adventurer_id: felt252, item_id: felt252, quantity: u16,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let mut rate: ConversionRate = world.read_model(item_id);
            rate.item_type = if rate.item_type == 0_felt252 { item_id } else { rate.item_type };

            let converted = convert_transition(
                adventurer,
                economics,
                caller,
                inventory,
                item,
                rate,
                quantity,
                now_block,
                CONVERSION_WINDOW_BLOCKS,
            );

            match converted.outcome {
                ConvertOutcome::Applied => {
                    let bonus_bp = conversion_bonus_bp_for_item(
                        ref world, converted.adventurer.current_hex, item_id,
                    );
                    let bonus_raw = bonus_extra_from_bp(converted.energy_gained, bonus_bp);
                    let (bonus_adventurer, bonus_economics, _) = mint_bonus_energy_with_cap(
                        converted.adventurer, converted.economics, bonus_raw,
                    );
                    let total_energy_gained = saturating_add_u16(converted.energy_gained, bonus_raw);

                    world.write_model(@bonus_adventurer);
                    world.write_model(@bonus_economics);
                    world.write_model(@converted.inventory);
                    world.write_model(@converted.item);
                    world.write_model(@converted.rate);
                    world.emit_event(
                        @ItemsConverted {
                            adventurer_id,
                            item_id,
                            quantity,
                            energy_gained: total_energy_gained,
                        },
                    );
                    total_energy_gained
                },
                _ => 0_u16,
            }
        }

        fn pay_hex_maintenance(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);

            let paid = pay_maintenance_transition(
                adventurer,
                economics,
                caller,
                state,
                amount,
                upkeep,
                now_block,
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match paid.outcome {
                PayOutcome::Applied => {
                    world.write_model(@paid.adventurer);
                    world.write_model(@paid.economics);
                    world.write_model(@paid.state);
                    world.emit_event(
                        @HexEnergyPaid { hex: hex_coordinate, payer: adventurer_id, amount },
                    );
                    true
                },
                PayOutcome::InsufficientEnergy => {
                    world.write_model(@paid.adventurer);
                    world.write_model(@paid.economics);
                    false
                },
                _ => false,
            }
        }

        fn process_hex_decay(ref self: ContractState, hex_coordinate: felt252) -> u16 {
            let mut world = self.world_default();
            let now_block = get_block_info().unbox().block_number;

            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);

            let processed = process_decay_transition(
                state,
                hex.biome,
                now_block,
                DECAY_PERIOD_BLOCKS,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match processed.outcome {
                DecayOutcome::Applied => {
                    world.write_model(@processed.state);
                    if processed.became_claimable {
                        world.emit_event(
                            @HexBecameClaimable {
                                hex: hex_coordinate,
                                min_energy_to_claim: processed.min_energy_to_claim,
                            },
                        );
                    }
                },
                _ => {},
            }

            processed.state.decay_level
        }

        fn initiate_hex_claim(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, energy_offered: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let claimant: Adventurer = world.read_model(adventurer_id);
            let claimant_economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);
            let min_required_u16 = min_claim_energy(
                upkeep, state.decay_level, CLAIMABLE_DECAY_THRESHOLD,
            );

            let claim_id = derive_hex_claim_id(hex_coordinate);
            let mut escrow: ClaimEscrow = world.read_model(claim_id);
            escrow.claim_id = claim_id;
            escrow.hex_coordinate = hex_coordinate;
            escrow = settle_expired_claim_if_needed(ref world, hex_coordinate, now_block, escrow);

            let initiated = initiate_claim_transition(
                claimant,
                claimant_economics,
                caller,
                state,
                escrow,
                energy_offered,
                now_block,
                CLAIM_TIMEOUT_BLOCKS,
                CLAIM_GRACE_BLOCKS,
                min_required_u16.into(),
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match initiated.outcome {
                ClaimInitOutcome::AppliedPending | ClaimInitOutcome::AppliedImmediate => {
                    world.write_model(@initiated.claimant);
                    world.write_model(@initiated.claimant_economics);
                    world.write_model(@initiated.state);
                    world.write_model(@initiated.escrow);
                    if initiated.outcome == ClaimInitOutcome::AppliedImmediate {
                        sync_hex_area_ownership_controller(
                            ref world,
                            hex_coordinate,
                            initiated.state.owner_adventurer_id,
                            now_block,
                            true,
                        );
                    }
                    world.emit_event(
                        @ClaimInitiated {
                            hex: hex_coordinate,
                            claimant: adventurer_id,
                            claim_id: initiated.escrow.claim_id,
                            energy_locked: initiated.escrow.energy_locked,
                            expiry_block: initiated.escrow.expiry_block,
                        },
                    );
                    true
                },
                _ => false,
            }
        }

        fn defend_hex_from_claim(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, defense_energy: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let defender: Adventurer = world.read_model(adventurer_id);
            let defender_economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);

            let claim_id = derive_hex_claim_id(hex_coordinate);
            let mut escrow: ClaimEscrow = world.read_model(claim_id);
            escrow.claim_id = claim_id;
            escrow.hex_coordinate = hex_coordinate;
            escrow = settle_expired_claim_if_needed(ref world, hex_coordinate, now_block, escrow);

            if escrow.claimant_adventurer_id == 0_felt252 || escrow.status != ClaimEscrowStatus::Active {
                return false;
            }

            let claimant: Adventurer = world.read_model(escrow.claimant_adventurer_id);
            let claimant_economics: AdventurerEconomics = world.read_model(escrow.claimant_adventurer_id);
            let watchtower_bp = active_hex_building_effect_bp(ref world, hex_coordinate, B_WATCHTOWER);
            let defense_effective = apply_bp_floor_u16(defense_energy, watchtower_bp);

            let defended = defend_claim_transition(
                defender,
                defender_economics,
                caller,
                state,
                escrow,
                claimant,
                claimant_economics,
                defense_energy,
                defense_effective,
                now_block,
                upkeep,
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match defended.outcome {
                DefendOutcome::Applied => {
                    world.write_model(@defended.defender);
                    world.write_model(@defended.defender_economics);
                    world.write_model(@defended.claimant);
                    world.write_model(@defended.claimant_economics);
                    world.write_model(@defended.state);
                    world.write_model(@defended.escrow);
                    sync_hex_area_ownership_controller(
                        ref world,
                        hex_coordinate,
                        defended.state.owner_adventurer_id,
                        0_u64,
                        false,
                    );
                    world.emit_event(
                        @ClaimRefunded {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                            amount: defended.claimant.energy - claimant.energy,
                        },
                    );
                    world.emit_event(
                        @HexDefended {
                            hex: hex_coordinate,
                            owner: adventurer_id,
                            energy: defense_energy,
                        },
                    );
                    true
                },
                DefendOutcome::InsufficientEnergy => {
                    world.write_model(@defended.defender);
                    world.write_model(@defended.defender_economics);
                    false
                },
                DefendOutcome::ClaimExpired => {
                    world.write_model(@defended.claimant);
                    world.write_model(@defended.claimant_economics);
                    world.write_model(@defended.escrow);
                    world.emit_event(
                        @ClaimExpired {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                        },
                    );
                    world.emit_event(
                        @ClaimRefunded {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                            amount: defended.claimant.energy - claimant.energy,
                        },
                    );
                    false
                },
                _ => false,
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
