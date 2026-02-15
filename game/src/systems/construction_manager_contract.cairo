#[starknet::interface]
pub trait IConstructionManager<T> {
    fn process_plant_material(
        ref self: T, adventurer_id: felt252, source_item_id: felt252, quantity: u16, target_material: felt252,
    ) -> u16;
    fn start_construction(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, building_type: felt252,
    ) -> felt252;
    fn complete_construction(ref self: T, adventurer_id: felt252, project_id: felt252) -> bool;
    fn pay_building_upkeep(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, amount: u16,
    ) -> bool;
    fn repair_building(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, amount: u16,
    ) -> bool;
    fn upgrade_building(ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252) -> bool;
    fn inspect_building(
        self: @T, hex_coordinate: felt252, area_id: felt252,
    ) -> dojo_starter::models::construction::ConstructionBuildingNode;
}

#[dojo::contract]
pub mod construction_manager {
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::construction_events::{
        ConstructionCompleted, ConstructionPlantProcessed, ConstructionRejected, ConstructionRepaired,
        ConstructionStarted, ConstructionUpgradeQueued, ConstructionUpkeepPaid,
    };
    use dojo_starter::libs::construction_balance::{
        B_WORKSHOP, I_PLANT_COMPOUND, I_PLANT_FIBER, I_PLANT_RESIN, build_time_blocks_for_building,
        energy_stake_for_building, timed_params_for_building,
    };
    use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by, spend_energy};
    use dojo_starter::models::construction::{
        BUILDING_DISABLE_THRESHOLD_BP, ConstructionBuildingNode, ConstructionProject, is_building_effective,
    };
    use dojo_starter::models::inventory::BackpackItem;
    use dojo_starter::models::world::{Hex, derive_area_id};
    use dojo_starter::systems::construction_manager::{
        ConstructionCheckpointOutcome, ConstructionCompleteOutcome, ConstructionStartOutcome,
        complete_project_transition, pay_building_upkeep_transition,
        repair_building_transition, start_project_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    use super::IConstructionManager;

    const ACTION_PROCESS: felt252 = 'PROCESS'_felt252;
    const ACTION_START: felt252 = 'START'_felt252;
    const ACTION_COMPLETE: felt252 = 'COMPLETE'_felt252;
    const ACTION_UPKEEP: felt252 = 'UPKEEP'_felt252;
    const ACTION_REPAIR: felt252 = 'REPAIR'_felt252;
    const ACTION_UPGRADE: felt252 = 'UPGRADE'_felt252;
    const REPAIR_BP_PER_ENERGY: u16 = 100_u16;
    const DEFAULT_CONDITION_BP: u16 = 10_000_u16;
    const BP_ONE: u16 = 10_000_u16;
    const MAX_U32: u64 = 4_294_967_295_u64;
    const MAX_U16: u64 = 65_535_u64;

    fn saturating_add_u32(lhs: u32, rhs: u32) -> u32 {
        let sum: u64 = lhs.into() + rhs.into();
        if sum > MAX_U32 {
            4_294_967_295_u32
        } else {
            sum.try_into().unwrap()
        }
    }

    fn apply_bp_floor_u16(value: u16, bp: u16) -> u16 {
        if value == 0_u16 || bp == 0_u16 {
            return 0_u16;
        }

        let scaled: u64 = value.into() * bp.into() / BP_ONE.into();
        if scaled > MAX_U16 { 65_535_u16 } else { scaled.try_into().unwrap() }
    }

    fn apply_bp_floor_u64(value: u64, bp: u16) -> u64 {
        if value == 0_u64 || bp == 0_u16 {
            return 0_u64;
        }
        value * bp.into() / BP_ONE.into()
    }

    fn apply_discount_u16(value: u16, discount_bp: u16) -> u16 {
        if discount_bp == 0_u16 {
            return value;
        }
        if discount_bp >= BP_ONE {
            return 0_u16;
        }
        apply_bp_floor_u16(value, BP_ONE - discount_bp)
    }

    fn apply_discount_u64(value: u64, discount_bp: u16) -> u64 {
        if discount_bp == 0_u16 {
            return value;
        }
        if discount_bp >= BP_ONE {
            return 0_u64;
        }
        apply_bp_floor_u64(value, BP_ONE - discount_bp)
    }

    fn active_hex_workshop_params(
        ref world: dojo::world::WorldStorage, hex_coordinate: felt252,
    ) -> (u16, u16) {
        let (discount_bp, time_cut_bp) = timed_params_for_building(B_WORKSHOP);
        if discount_bp == 0_u16 && time_cut_bp == 0_u16 {
            return (0_u16, 0_u16);
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

            if building.hex_coordinate == hex_coordinate && building.building_type == B_WORKSHOP
                && is_building_effective(building) {
                return (discount_bp, time_cut_bp);
            }

            idx += 1_u8;
        };

        (0_u16, 0_u16)
    }

    fn emit_rejection(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        area_id: felt252,
        action: felt252,
        reason: felt252,
    ) {
        world.emit_event(@ConstructionRejected { adventurer_id, area_id, action, reason });
    }

    fn is_valid_target_material(target_material: felt252) -> bool {
        target_material == I_PLANT_FIBER || target_material == I_PLANT_RESIN
            || target_material == I_PLANT_COMPOUND
    }

    #[abi(embed_v0)]
    impl ConstructionManagerImpl of IConstructionManager<ContractState> {
        fn process_plant_material(
            ref self: ContractState,
            adventurer_id: felt252,
            source_item_id: felt252,
            quantity: u16,
            target_material: felt252,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_PROCESS, 'DEAD'_felt252);
                return 0_u16;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_PROCESS, 'NOT_OWNER'_felt252);
                return 0_u16;
            }
            if quantity == 0_u16 {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_PROCESS, 'ZERO_QTY'_felt252);
                return 0_u16;
            }
            if !is_valid_target_material(target_material) {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_PROCESS, 'BAD_TARGET'_felt252);
                return 0_u16;
            }

            let quantity_u32: u32 = quantity.into();
            let mut source_item: BackpackItem = world.read_model((adventurer_id, source_item_id));
            source_item.adventurer_id = adventurer_id;
            source_item.item_id = source_item_id;
            if source_item.quantity < quantity_u32 {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_PROCESS, 'NO_MATERIAL'_felt252);
                return 0_u16;
            }

            let mut target_item: BackpackItem = world.read_model((adventurer_id, target_material));
            target_item.adventurer_id = adventurer_id;
            target_item.item_id = target_material;
            if target_item.quality == 0_u16 {
                target_item.quality = if source_item.quality == 0_u16 { 100_u16 } else { source_item.quality };
            }
            if target_item.weight_per_unit == 0_u16 {
                target_item.weight_per_unit = if source_item.weight_per_unit == 0_u16 {
                    1_u16
                } else {
                    source_item.weight_per_unit
                };
            }

            source_item.quantity -= quantity_u32;
            target_item.quantity = saturating_add_u32(target_item.quantity, quantity_u32);

            world.write_model(@source_item);
            world.write_model(@target_item);
            world.emit_event(
                @ConstructionPlantProcessed {
                    adventurer_id,
                    source_item_id,
                    target_material,
                    input_qty: quantity,
                    output_qty: quantity,
                },
            );
            quantity
        }

        fn start_construction(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_id: felt252,
            building_type: felt252,
        ) -> felt252 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'DEAD'_felt252);
                return 0_felt252;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'NOT_OWNER'_felt252);
                return 0_felt252;
            }
            if adventurer.current_hex != hex_coordinate {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'WRONG_HEX'_felt252);
                return 0_felt252;
            }
            if adventurer.activity_locked_until > now_block {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'LOCKED'_felt252);
                return 0_felt252;
            }

            let energy_stake = energy_stake_for_building(building_type);
            let build_time_blocks = build_time_blocks_for_building(building_type);
            if energy_stake == 0_u16 || build_time_blocks == 0_u64 {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'BAD_BUILDING'_felt252);
                return 0_felt252;
            }
            let (workshop_discount_bp, workshop_time_cut_bp) = active_hex_workshop_params(
                ref world, hex_coordinate,
            );
            let effective_energy_stake = {
                let discounted = apply_discount_u16(energy_stake, workshop_discount_bp);
                if energy_stake > 0_u16 && discounted == 0_u16 { 1_u16 } else { discounted }
            };
            let effective_build_time_blocks = {
                let discounted = apply_discount_u64(build_time_blocks, workshop_time_cut_bp);
                if build_time_blocks > 0_u64 && discounted == 0_u64 { 1_u64 } else { discounted }
            };

            if adventurer.energy < effective_energy_stake {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'LOW_ENERGY'_felt252);
                return 0_felt252;
            }

            let mut slot_project: ConstructionProject = world.read_model(area_id);
            slot_project.project_id = area_id;
            let mut existing_building: ConstructionBuildingNode = world.read_model(area_id);
            existing_building.area_id = area_id;
            let target_tier = if existing_building.tier == 0_u8 {
                1_u8
            } else if existing_building.tier == 255_u8 {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'TIER_MAX'_felt252);
                return 0_felt252;
            } else {
                existing_building.tier + 1_u8
            };

            let started = start_project_transition(
                slot_project,
                adventurer_id,
                hex_coordinate,
                area_id,
                building_type,
                target_tier,
                now_block,
                effective_build_time_blocks,
                effective_energy_stake,
                adventurer.energy,
            );

            if started.outcome != ConstructionStartOutcome::Applied {
                let reason = match started.outcome {
                    ConstructionStartOutcome::AlreadyActive => 'ACTIVE'_felt252,
                    ConstructionStartOutcome::InvalidStake => 'BAD_STAKE'_felt252,
                    ConstructionStartOutcome::InsufficientEnergy => 'LOW_ENERGY'_felt252,
                    _ => 'START_FAIL'_felt252,
                };
                emit_rejection(ref world, adventurer_id, area_id, ACTION_START, reason);
                return 0_felt252;
            }

            adventurer = match spend_energy(adventurer, effective_energy_stake) {
                Option::Some(next) => next,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, area_id, ACTION_START, 'LOW_ENERGY'_felt252);
                    return 0_felt252;
                },
            };
            adventurer.activity_locked_until = started.project.completion_block;

            world.write_model(@adventurer);
            world.write_model(@started.project);
            let mut slot_write = started.project;
            slot_write.project_id = area_id;
            world.write_model(@slot_write);
            world.emit_event(
                @ConstructionStarted {
                    project_id: started.project.project_id,
                    adventurer_id,
                    hex_coordinate,
                    area_id,
                    building_type,
                    target_tier: started.project.target_tier,
                    completion_block: started.project.completion_block,
                },
            );

            started.project.project_id
        }

        fn complete_construction(ref self: ContractState, adventurer_id: felt252, project_id: felt252) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_COMPLETE, 'DEAD'_felt252);
                return false;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, 0_felt252, ACTION_COMPLETE, 'NOT_OWNER'_felt252);
                return false;
            }

            let mut project: ConstructionProject = world.read_model(project_id);
            project.project_id = project_id;
            if project.adventurer_id != adventurer_id {
                emit_rejection(ref world, adventurer_id, project.area_id, ACTION_COMPLETE, 'WRONG_ADV'_felt252);
                return false;
            }

            let completed = complete_project_transition(project, now_block);
            match completed.outcome {
                ConstructionCompleteOutcome::Applied => {
                    let mut building: ConstructionBuildingNode = world.read_model(completed.project.area_id);
                    building.area_id = completed.project.area_id;
                    building.hex_coordinate = completed.project.hex_coordinate;
                    building.owner_adventurer_id = adventurer_id;
                    building.building_type = completed.project.building_type;
                    building.tier = completed.project.target_tier;
                    building.condition_bp = DEFAULT_CONDITION_BP;
                    building.last_upkeep_block = now_block;
                    building.is_active = true;

                    adventurer.activity_locked_until = now_block;

                    world.write_model(@adventurer);
                    world.write_model(@completed.project);
                    let mut slot_project = completed.project;
                    slot_project.project_id = completed.project.area_id;
                    world.write_model(@slot_project);
                    world.write_model(@building);
                    world.emit_event(
                        @ConstructionCompleted {
                            project_id,
                            adventurer_id,
                            hex_coordinate: completed.project.hex_coordinate,
                            area_id: completed.project.area_id,
                            building_type: completed.project.building_type,
                            resulting_tier: completed.project.target_tier,
                        },
                    );
                    true
                },
                ConstructionCompleteOutcome::NotReady => {
                    emit_rejection(ref world, adventurer_id, project.area_id, ACTION_COMPLETE, 'NOT_READY'_felt252);
                    false
                },
                _ => {
                    emit_rejection(ref world, adventurer_id, project.area_id, ACTION_COMPLETE, 'NOT_ACTIVE'_felt252);
                    false
                },
            }
        }

        fn pay_building_upkeep(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_id: felt252,
            amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, 'DEAD'_felt252);
                return false;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, 'NOT_OWNER'_felt252);
                return false;
            }
            if adventurer.current_hex != hex_coordinate {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, 'WRONG_HEX'_felt252);
                return false;
            }

            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;
            if building.hex_coordinate != hex_coordinate {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, 'WRONG_HEX'_felt252);
                return false;
            }

            let paid = pay_building_upkeep_transition(building, amount, now_block);
            if paid.outcome != ConstructionCheckpointOutcome::Maintained {
                let reason = match paid.outcome {
                    ConstructionCheckpointOutcome::Inactive => 'INACTIVE'_felt252,
                    ConstructionCheckpointOutcome::InvalidAmount => 'BAD_AMOUNT'_felt252,
                    _ => 'UPKEEP_FAIL'_felt252,
                };
                emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, reason);
                return false;
            }

            adventurer = match spend_energy(adventurer, amount) {
                Option::Some(next) => next,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, area_id, ACTION_UPKEEP, 'LOW_ENERGY'_felt252);
                    return false;
                },
            };

            world.write_model(@adventurer);
            world.write_model(@paid.building);
            world.emit_event(
                @ConstructionUpkeepPaid {
                    area_id,
                    adventurer_id,
                    amount,
                    upkeep_reserve: paid.building.upkeep_reserve,
                },
            );
            true
        }

        fn repair_building(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_id: felt252,
            amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let mut adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, 'DEAD'_felt252);
                return false;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, 'NOT_OWNER'_felt252);
                return false;
            }
            if adventurer.current_hex != hex_coordinate {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, 'WRONG_HEX'_felt252);
                return false;
            }

            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;
            if building.hex_coordinate != hex_coordinate {
                emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, 'WRONG_HEX'_felt252);
                return false;
            }

            let repaired = repair_building_transition(
                building, amount, REPAIR_BP_PER_ENERGY, BUILDING_DISABLE_THRESHOLD_BP,
            );
            if repaired.outcome != ConstructionCheckpointOutcome::Repaired
                && repaired.outcome != ConstructionCheckpointOutcome::Reactivated {
                let reason = match repaired.outcome {
                    ConstructionCheckpointOutcome::InvalidAmount => 'BAD_AMOUNT'_felt252,
                    _ => 'REPAIR_FAIL'_felt252,
                };
                emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, reason);
                return false;
            }

            adventurer = match spend_energy(adventurer, amount) {
                Option::Some(next) => next,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, area_id, ACTION_REPAIR, 'LOW_ENERGY'_felt252);
                    return false;
                },
            };

            world.write_model(@adventurer);
            world.write_model(@repaired.building);
            world.emit_event(
                @ConstructionRepaired {
                    area_id,
                    adventurer_id,
                    amount,
                    condition_bp: repaired.building.condition_bp,
                    is_active: repaired.building.is_active,
                },
            );
            true
        }

        fn upgrade_building(ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252) -> bool {
            let world = self.world_default();
            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;
            if building.tier == 0_u8 {
                return false;
            }

            let project_id = self.start_construction(
                adventurer_id, hex_coordinate, area_id, building.building_type,
            );
            if project_id == 0_felt252 {
                return false;
            }

            let mut world_write = self.world_default();
            let mut project: ConstructionProject = world_write.read_model(project_id);
            project.project_id = project_id;
            world_write.emit_event(
                @ConstructionUpgradeQueued {
                    area_id,
                    project_id,
                    adventurer_id,
                    target_tier: project.target_tier,
                },
            );
            true
        }

        fn inspect_building(self: @ContractState, hex_coordinate: felt252, area_id: felt252) -> ConstructionBuildingNode {
            let world = self.world_default();
            let mut building: ConstructionBuildingNode = world.read_model(area_id);
            building.area_id = area_id;
            if building.hex_coordinate == 0_felt252 {
                building.hex_coordinate = hex_coordinate;
            }
            building
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
