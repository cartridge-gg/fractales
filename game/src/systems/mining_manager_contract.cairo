#[starknet::interface]
pub trait IMiningManager<T> {
    fn init_mining(ref self: T, hex_coordinate: felt252, area_id: felt252, mine_id: u8) -> bool;
    fn grant_mine_access(
        ref self: T, controller_adventurer_id: felt252, mine_key: felt252, grantee_adventurer_id: felt252,
    ) -> bool;
    fn revoke_mine_access(
        ref self: T, controller_adventurer_id: felt252, mine_key: felt252, grantee_adventurer_id: felt252,
    ) -> bool;
    fn start_mining(ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, mine_id: u8)
        -> bool;
    fn continue_mining(ref self: T, adventurer_id: felt252, mine_key: felt252) -> u16;
    fn stabilize_mine(ref self: T, adventurer_id: felt252, mine_key: felt252) -> u32;
    fn exit_mining(ref self: T, adventurer_id: felt252, mine_key: felt252) -> u16;
    fn repair_mine(ref self: T, adventurer_id: felt252, mine_key: felt252, energy_amount: u16) -> u32;
    fn inspect_mine(self: @T, hex_coordinate: felt252, area_id: felt252, mine_id: u8) -> dojo_starter::models::mining::MineNode;
}

#[dojo::contract]
pub mod mining_manager {
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::mining_events::{
        MineAccessGranted, MineAccessRevoked, MineCollapsed, MineInitialized, MineRepaired,
        MiningContinued, MiningExited, MiningRejected, MiningStarted, MineStabilized,
    };
    use dojo_starter::libs::construction_balance::{B_SHORING_RIG, B_STOREHOUSE, effect_bp_for_building};
    use dojo_starter::libs::mining_gen::{derive_area_mine_slot_count, derive_mine_profile};
    use dojo_starter::libs::mining_math::{
        compute_stress_delta, compute_tick_energy_cost, compute_tick_yield, will_collapse,
    };
    use dojo_starter::libs::sharing_math::{PERM_EXTRACT, PERM_INSPECT, has_permissions};
    use dojo_starter::models::adventurer::{
        Adventurer, AdventurerWriteStatus, kill_once_with_status, spend_energy,
    };
    use dojo_starter::models::construction::{ConstructionBuildingNode, is_building_effective};
    use dojo_starter::models::deaths::{build_death_record, derive_inventory_loss_hash};
    use dojo_starter::models::economics::ConversionRate;
    use dojo_starter::models::inventory::{BackpackItem, Inventory, clear_inventory};
    use dojo_starter::models::mining::{
        MineAccessGrant, MineCollapseRecord, MineNode, MiningShift, MiningShiftStatus, derive_mine_key,
        derive_mining_item_id, derive_mining_shift_id,
    };
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::sharing::{
        PolicyScope, ResourceAccessGrant, ResourceKind, ResourcePolicy, is_grant_effective,
        is_policy_effective,
    };
    use dojo_starter::models::world::{AreaType, Hex, HexArea, derive_area_id};
    use dojo_starter::systems::mining_manager::{
        DENSITY_K_BP, MAX_STRESS_PENALTY_BP, OVERSTAY_K_BP, SWARM_K_LOCKED, apply_shoring_stress_delta,
        can_control_alive,
    };
    use starknet::{get_block_info, get_caller_address};

    use super::IMiningManager;

    const ACTION_INIT: felt252 = 'MINE_INIT'_felt252;
    const ACTION_GRANT: felt252 = 'MINE_GRANT'_felt252;
    const ACTION_REVOKE: felt252 = 'MINE_REVOKE'_felt252;
    const ACTION_START: felt252 = 'MINE_START'_felt252;
    const ACTION_CONTINUE: felt252 = 'MINE_CONT'_felt252;
    const ACTION_STABILIZE: felt252 = 'MINE_STAB'_felt252;
    const ACTION_EXIT: felt252 = 'MINE_EXIT'_felt252;
    const ACTION_REPAIR: felt252 = 'MINE_REPAIR'_felt252;
    const MINE_COLLAPSE_CAUSE: felt252 = 'MINE_COLLAPSE'_felt252;
    const BP_ONE: u16 = 10_000_u16;
    const U32_MAX_U128: u128 = 4_294_967_295_u128;

    fn saturating_add_u32(lhs: u32, rhs: u32) -> u32 {
        let sum_u128: u128 = lhs.into() + rhs.into();
        if sum_u128 > 4_294_967_295_u128 {
            4_294_967_295_u32
        } else {
            sum_u128.try_into().unwrap()
        }
    }

    fn to_u16_saturated(value: u32) -> u16 {
        if value > 65_535_u32 {
            65_535_u16
        } else {
            value.try_into().unwrap()
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

    fn min_u16(a: u16, b: u16) -> u16 {
        if a < b { a } else { b }
    }

    fn min_u32(a: u32, b: u32) -> u32 {
        if a < b { a } else { b }
    }

    fn emit_rejection(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        mine_key: felt252,
        action: felt252,
        reason: felt252,
    ) {
        world.emit_event(@MiningRejected { adventurer_id, mine_key, action, reason });
    }

    fn is_controller(
        ref world: dojo::world::WorldStorage, area_id: felt252, adventurer_id: felt252,
    ) -> bool {
        let mut ownership: AreaOwnership = world.read_model(area_id);
        ownership.area_id = area_id;
        ownership.owner_adventurer_id == adventurer_id
    }

    fn has_access(
        ref world: dojo::world::WorldStorage, mine: MineNode, adventurer_id: felt252,
    ) -> bool {
        if is_controller(ref world, mine.area_id, adventurer_id) {
            return true;
        }

        let mut grant: MineAccessGrant = world.read_model((mine.mine_key, adventurer_id));
        grant.mine_key = mine.mine_key;
        grant.grantee_adventurer_id = adventurer_id;
        if grant.is_allowed {
            return true;
        }

        let mut policy: ResourcePolicy = world.read_model(mine.mine_key);
        policy.resource_key = mine.mine_key;
        if !is_policy_effective(policy) {
            return false;
        }
        if policy.controller_adventurer_id == adventurer_id {
            return true;
        }

        let mut shared_grant: ResourceAccessGrant = world.read_model((mine.mine_key, adventurer_id));
        shared_grant.resource_key = mine.mine_key;
        shared_grant.grantee_adventurer_id = adventurer_id;
        is_grant_effective(shared_grant, policy.policy_epoch)
            && has_permissions(shared_grant.permissions_mask, PERM_EXTRACT)
    }

    fn upsert_shared_mine_policy(
        ref world: dojo::world::WorldStorage,
        mine: MineNode,
        controller_adventurer_id: felt252,
        now_block: u64,
    ) -> ResourcePolicy {
        let mut policy: ResourcePolicy = world.read_model(mine.mine_key);
        policy.resource_key = mine.mine_key;
        policy.scope = PolicyScope::Area;
        policy.scope_key = mine.area_id;
        policy.resource_kind = ResourceKind::Mine;
        policy.is_enabled = true;
        policy.updated_block = now_block;
        policy.last_mutation_block = now_block;

        if policy.policy_epoch == 0_u32 {
            policy.policy_epoch = 1_u32;
        } else if policy.controller_adventurer_id != 0_felt252
            && policy.controller_adventurer_id != controller_adventurer_id {
            policy.policy_epoch += 1_u32;
        }

        policy.controller_adventurer_id = controller_adventurer_id;
        world.write_model(@policy);
        policy
    }

    fn active_hex_building_effect_bp(
        ref world: dojo::world::WorldStorage, hex_coordinate: felt252, building_type: felt252,
    ) -> u16 {
        let base_bp = effect_bp_for_building(building_type);
        if base_bp == 0_u16 {
            return 10_000_u16;
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

        10_000_u16
    }

    fn remove_shift_from_active_list(
        ref world: dojo::world::WorldStorage, ref mine: MineNode, mut shift: MiningShift,
    ) {
        let prev_id = shift.prev_active_shift_id;
        let next_id = shift.next_active_shift_id;

        if prev_id != 0_felt252 {
            let mut prev_shift: MiningShift = world.read_model(prev_id);
            prev_shift.shift_id = prev_id;
            prev_shift.next_active_shift_id = next_id;
            world.write_model(@prev_shift);
        } else {
            mine.active_head_shift_id = next_id;
        }

        if next_id != 0_felt252 {
            let mut next_shift: MiningShift = world.read_model(next_id);
            next_shift.shift_id = next_id;
            next_shift.prev_active_shift_id = prev_id;
            world.write_model(@next_shift);
        } else {
            mine.active_tail_shift_id = prev_id;
        }

        if mine.active_miners > 0_u16 {
            mine.active_miners -= 1_u16;
        }

        shift.prev_active_shift_id = 0_felt252;
        shift.next_active_shift_id = 0_felt252;
        world.write_model(@shift);
    }

    fn collapse_active_miners(
        ref world: dojo::world::WorldStorage, mut mine: MineNode, now_block: u64,
    ) -> (MineNode, u16, u32) {
        let trigger_active = mine.active_miners;
        let mut killed_miners: u16 = 0_u16;
        let mut current_shift_id = mine.active_head_shift_id;

        loop {
            if current_shift_id == 0_felt252 {
                break;
            }

            let mut shift: MiningShift = world.read_model(current_shift_id);
            shift.shift_id = current_shift_id;
            let next_shift_id = shift.next_active_shift_id;

            let adventurer_before: Adventurer = world.read_model(shift.adventurer_id);
            let inventory_before: Inventory = world.read_model(shift.adventurer_id);
            let killed = kill_once_with_status(adventurer_before);

            if killed.status == AdventurerWriteStatus::Applied {
                let inventory_lost_hash = derive_inventory_loss_hash(
                    killed.value.adventurer_id,
                    inventory_before.current_weight,
                    mine.mine_key,
                    MINE_COLLAPSE_CAUSE,
                    now_block,
                );
                let death_record = build_death_record(
                    killed.value.adventurer_id,
                    killed.value.owner,
                    now_block,
                    MINE_COLLAPSE_CAUSE,
                    inventory_lost_hash,
                );

                world.write_model(@killed.value);
                world.write_model(@clear_inventory(inventory_before));
                world.write_model(@death_record);
                killed_miners += 1_u16;
            }

            shift.status = MiningShiftStatus::Collapsed;
            shift.accrued_ore_unbanked = 0_u32;
            shift.accrued_stabilization_work = 0_u32;
            shift.prev_active_shift_id = 0_felt252;
            shift.next_active_shift_id = 0_felt252;
            world.write_model(@shift);

            current_shift_id = next_shift_id;
        }

        mine.active_head_shift_id = 0_felt252;
        mine.active_tail_shift_id = 0_felt252;
        mine.active_miners = 0_u16;
        mine.repair_energy_needed = {
            let candidate = mine.collapse_threshold / 3_u32;
            if candidate == 0_u32 { 1_u32 } else { candidate }
        };
        mine.collapsed_until_block = now_block;
        if mine.collapse_threshold > 0_u32 {
            mine.mine_stress = mine.collapse_threshold;
        }
        mine.last_update_block = now_block;

        let mut collapse: MineCollapseRecord = world.read_model(mine.mine_key);
        collapse.mine_key = mine.mine_key;
        collapse.collapse_count = saturating_add_u32(collapse.collapse_count, 1_u32);
        collapse.last_collapse_block = now_block;
        collapse.trigger_stress = mine.mine_stress;
        collapse.trigger_active_miners = trigger_active;
        world.write_model(@collapse);

        (mine, killed_miners, collapse.collapse_count)
    }

    #[abi(embed_v0)]
    impl MiningManagerImpl of IMiningManager<ContractState> {
        fn init_mining(ref self: ContractState, hex_coordinate: felt252, area_id: felt252, mine_id: u8) -> bool {
            let mut world = self.world_default();
            let now_block = get_block_info().unbox().block_number;

            let hex: Hex = world.read_model(hex_coordinate);
            if !hex.is_discovered {
                return false;
            }

            let mut area: HexArea = world.read_model(area_id);
            area.area_id = area_id;
            if !area.is_discovered || area.hex_coordinate != hex_coordinate {
                return false;
            }
            if area.area_type != AreaType::MineField {
                return false;
            }

            let slot_count = derive_area_mine_slot_count(hex_coordinate, area_id, hex.biome);
            if mine_id >= slot_count {
                return false;
            }

            let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold > 0_u32 {
                return true;
            }

            let profile = derive_mine_profile(hex_coordinate, area_id, mine_id, hex.biome);
            mine.hex_coordinate = hex_coordinate;
            mine.area_id = area_id;
            mine.mine_id = mine_id;
            mine.ore_id = profile.ore_id;
            mine.rarity_tier = profile.rarity_tier;
            mine.depth_tier = profile.depth_tier;
            mine.richness_bp = profile.richness_bp;
            mine.remaining_reserve = profile.remaining_reserve;
            mine.base_stress_per_block = profile.base_stress_per_block;
            mine.collapse_threshold = profile.collapse_threshold;
            mine.mine_stress = 0_u32;
            mine.safe_shift_blocks = profile.safe_shift_blocks;
            mine.active_miners = 0_u16;
            mine.last_update_block = now_block;
            mine.collapsed_until_block = 0_u64;
            mine.repair_energy_needed = 0_u32;
            mine.is_depleted = false;
            mine.active_head_shift_id = 0_felt252;
            mine.active_tail_shift_id = 0_felt252;
            mine.biome_risk_bp = profile.biome_risk_bp;
            mine.rarity_risk_bp = profile.rarity_risk_bp;
            mine.base_tick_energy = 3_u16;
            mine.ore_energy_weight = profile.ore_energy_weight;
            mine.conversion_energy_per_unit = profile.conversion_energy_per_unit;

            world.write_model(@mine);
            let mut ownership: AreaOwnership = world.read_model(area_id);
            ownership.area_id = area_id;
            if ownership.owner_adventurer_id != 0_felt252 {
                upsert_shared_mine_policy(
                    ref world, mine, ownership.owner_adventurer_id, now_block,
                );
            }
            world.emit_event(
                @MineInitialized {
                    mine_key,
                    hex_coordinate,
                    area_id,
                    mine_id,
                    ore_id: mine.ore_id,
                    rarity_tier: mine.rarity_tier,
                },
            );
            true
        }

        fn grant_mine_access(
            ref self: ContractState, controller_adventurer_id: felt252, mine_key: felt252, grantee_adventurer_id: felt252,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                return false;
            }

            let controller: Adventurer = world.read_model(controller_adventurer_id);
            if !can_control_alive(controller, caller) {
                emit_rejection(ref world, controller_adventurer_id, mine_key, ACTION_GRANT, 'NOT_OWNER'_felt252);
                return false;
            }
            if !is_controller(ref world, mine.area_id, controller_adventurer_id) {
                emit_rejection(ref world, controller_adventurer_id, mine_key, ACTION_GRANT, 'NOT_CTRL'_felt252);
                return false;
            }

            let mut grant: MineAccessGrant = world.read_model((mine_key, grantee_adventurer_id));
            grant.mine_key = mine_key;
            grant.grantee_adventurer_id = grantee_adventurer_id;
            grant.is_allowed = true;
            grant.granted_by_adventurer_id = controller_adventurer_id;
            grant.grant_block = now_block;
            grant.revoked_block = 0_u64;
            world.write_model(@grant);

            let shared_policy = upsert_shared_mine_policy(
                ref world, mine, controller_adventurer_id, now_block,
            );
            let mut shared_grant: ResourceAccessGrant = world.read_model((mine_key, grantee_adventurer_id));
            shared_grant.resource_key = mine_key;
            shared_grant.grantee_adventurer_id = grantee_adventurer_id;
            shared_grant.permissions_mask = PERM_INSPECT + PERM_EXTRACT;
            shared_grant.granted_by_adventurer_id = controller_adventurer_id;
            shared_grant.grant_block = now_block;
            shared_grant.revoke_block = 0_u64;
            shared_grant.is_active = true;
            shared_grant.policy_epoch = shared_policy.policy_epoch;
            world.write_model(@shared_grant);

            world.emit_event(
                @MineAccessGranted {
                    mine_key,
                    grantee_adventurer_id,
                    granted_by_adventurer_id: controller_adventurer_id,
                },
            );
            true
        }

        fn revoke_mine_access(
            ref self: ContractState, controller_adventurer_id: felt252, mine_key: felt252, grantee_adventurer_id: felt252,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                return false;
            }

            let controller: Adventurer = world.read_model(controller_adventurer_id);
            if !can_control_alive(controller, caller) {
                emit_rejection(ref world, controller_adventurer_id, mine_key, ACTION_REVOKE, 'NOT_OWNER'_felt252);
                return false;
            }
            if !is_controller(ref world, mine.area_id, controller_adventurer_id) {
                emit_rejection(ref world, controller_adventurer_id, mine_key, ACTION_REVOKE, 'NOT_CTRL'_felt252);
                return false;
            }

            let mut grant: MineAccessGrant = world.read_model((mine_key, grantee_adventurer_id));
            grant.mine_key = mine_key;
            grant.grantee_adventurer_id = grantee_adventurer_id;
            grant.is_allowed = false;
            grant.granted_by_adventurer_id = controller_adventurer_id;
            grant.revoked_block = now_block;
            world.write_model(@grant);

            let shared_policy = upsert_shared_mine_policy(
                ref world, mine, controller_adventurer_id, now_block,
            );
            let mut shared_grant: ResourceAccessGrant = world.read_model((mine_key, grantee_adventurer_id));
            shared_grant.resource_key = mine_key;
            shared_grant.grantee_adventurer_id = grantee_adventurer_id;
            shared_grant.is_active = false;
            shared_grant.revoke_block = now_block;
            shared_grant.policy_epoch = shared_policy.policy_epoch;
            world.write_model(@shared_grant);

            world.emit_event(
                @MineAccessRevoked {
                    mine_key,
                    grantee_adventurer_id,
                    revoked_by_adventurer_id: controller_adventurer_id,
                },
            );
            true
        }

        fn start_mining(ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, mine_id: u8)
            -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'MINE_UNINIT'_felt252);
                return false;
            }
            if mine.is_depleted {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'MINE_DEPLETED'_felt252);
                return false;
            }
            if mine.repair_energy_needed > 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'MINE_COLLAPSED'_felt252);
                return false;
            }

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !can_control_alive(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'NOT_OWNER'_felt252);
                return false;
            }
            if adventurer.current_hex != mine.hex_coordinate {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'WRONG_HEX'_felt252);
                return false;
            }
            if !has_access(ref world, mine, adventurer_id) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'NO_ACCESS'_felt252);
                return false;
            }

            let shift_id = derive_mining_shift_id(adventurer_id, mine_key);
            let mut shift: MiningShift = world.read_model(shift_id);
            shift.shift_id = shift_id;
            if shift.status == MiningShiftStatus::Active {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_START, 'SHIFT_ACTIVE'_felt252);
                return false;
            }

            shift.adventurer_id = adventurer_id;
            shift.mine_key = mine_key;
            shift.status = MiningShiftStatus::Active;
            shift.start_block = now_block;
            shift.last_settle_block = now_block;
            shift.accrued_ore_unbanked = 0_u32;
            shift.accrued_stabilization_work = 0_u32;
            shift.prev_active_shift_id = 0_felt252;
            shift.next_active_shift_id = mine.active_head_shift_id;

            if mine.active_head_shift_id != 0_felt252 {
                let mut head_shift: MiningShift = world.read_model(mine.active_head_shift_id);
                head_shift.shift_id = mine.active_head_shift_id;
                head_shift.prev_active_shift_id = shift_id;
                world.write_model(@head_shift);
            } else {
                mine.active_tail_shift_id = shift_id;
            }
            mine.active_head_shift_id = shift_id;
            mine.active_miners += 1_u16;
            mine.last_update_block = now_block;

            let mut locked_adventurer = adventurer;
            locked_adventurer.activity_locked_until = 18_446_744_073_709_551_615_u64;

            world.write_model(@locked_adventurer);
            world.write_model(@shift);
            world.write_model(@mine);
            world.emit_event(@MiningStarted { adventurer_id, mine_key, start_block: now_block });
            true
        }

        fn continue_mining(ref self: ContractState, adventurer_id: felt252, mine_key: felt252) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !can_control_alive(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'NOT_OWNER'_felt252);
                return 0_u16;
            }

            let shift_id = derive_mining_shift_id(adventurer_id, mine_key);
            let mut shift: MiningShift = world.read_model(shift_id);
            shift.shift_id = shift_id;
            if shift.status != MiningShiftStatus::Active || shift.mine_key != mine_key {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'SHIFT_INACTIVE'_felt252);
                return 0_u16;
            }

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'MINE_UNINIT'_felt252);
                return 0_u16;
            }
            if mine.repair_energy_needed > 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'MINE_COLLAPSED'_felt252);
                return 0_u16;
            }
            if mine.is_depleted {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'MINE_DEPLETED'_felt252);
                return 0_u16;
            }

            let dt_blocks = if now_block > shift.last_settle_block {
                now_block - shift.last_settle_block
            } else {
                1_u64
            };
            let shift_elapsed_blocks = if now_block > shift.start_block {
                now_block - shift.start_block
            } else {
                0_u64
            };

            let energy_cost = compute_tick_energy_cost(
                mine.base_tick_energy,
                mine.ore_energy_weight,
                mine.depth_tier,
                mine.active_miners,
                SWARM_K_LOCKED,
            );
            let charged = spend_energy(adventurer, energy_cost);
            let charged_adventurer = match charged {
                Option::Some(updated) => updated,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, mine_key, ACTION_CONTINUE, 'LOW_ENERGY'_felt252);
                    return 0_u16;
                },
            };

            let base_yield_per_block_u32: u32 = 1_u32 + mine.richness_bp.into() / 1_000_u32;
            let base_yield_per_block: u16 = to_u16_saturated(base_yield_per_block_u32);

            let mut tick_yield = compute_tick_yield(
                base_yield_per_block,
                mine.mine_stress,
                mine.collapse_threshold,
                MAX_STRESS_PENALTY_BP,
                dt_blocks,
            );
            tick_yield = min_u32(tick_yield, mine.remaining_reserve);

            let stress_delta = compute_stress_delta(
                dt_blocks,
                mine.base_stress_per_block,
                mine.active_miners,
                shift_elapsed_blocks,
                mine.safe_shift_blocks,
                mine.biome_risk_bp,
                mine.rarity_risk_bp,
                OVERSTAY_K_BP,
                DENSITY_K_BP,
            );
            let shoring_bp = active_hex_building_effect_bp(ref world, mine.hex_coordinate, B_SHORING_RIG);
            let stress_delta_effective = apply_shoring_stress_delta(stress_delta, shoring_bp);

            mine.remaining_reserve -= tick_yield;
            if mine.remaining_reserve == 0_u32 {
                mine.is_depleted = true;
            }
            mine.mine_stress = saturating_add_u32(mine.mine_stress, stress_delta_effective);
            mine.last_update_block = now_block;

            shift.accrued_ore_unbanked = saturating_add_u32(shift.accrued_ore_unbanked, tick_yield);
            shift.last_settle_block = now_block;

            world.write_model(@charged_adventurer);
            world.write_model(@shift);

            if will_collapse(mine.mine_stress, mine.collapse_threshold) {
                let (collapsed_mine, killed_miners, collapse_count) = collapse_active_miners(ref world, mine, now_block);
                world.write_model(@collapsed_mine);
                world.emit_event(@MineCollapsed { mine_key, killed_miners, collapse_count });
                return 0_u16;
            }

            world.write_model(@mine);
            world.emit_event(
                @MiningContinued {
                    adventurer_id,
                    mine_key,
                    mined_ore: tick_yield,
                    energy_spent: energy_cost,
                },
            );
            to_u16_saturated(tick_yield)
        }

        fn stabilize_mine(ref self: ContractState, adventurer_id: felt252, mine_key: felt252) -> u32 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !can_control_alive(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_STABILIZE, 'NOT_OWNER'_felt252);
                return 0_u32;
            }

            let shift_id = derive_mining_shift_id(adventurer_id, mine_key);
            let mut shift: MiningShift = world.read_model(shift_id);
            shift.shift_id = shift_id;
            if shift.status != MiningShiftStatus::Active {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_STABILIZE, 'SHIFT_INACTIVE'_felt252);
                return 0_u32;
            }

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 || mine.repair_energy_needed > 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_STABILIZE, 'MINE_BLOCKED'_felt252);
                return 0_u32;
            }

            let charged = spend_energy(adventurer, mine.base_tick_energy);
            let charged_adventurer = match charged {
                Option::Some(updated) => updated,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, mine_key, ACTION_STABILIZE, 'LOW_ENERGY'_felt252);
                    return 0_u32;
                },
            };

            let target_reduce = {
                let candidate = mine.collapse_threshold / 20_u32;
                if candidate == 0_u32 { 1_u32 } else { candidate }
            };
            let reduced = min_u32(target_reduce, mine.mine_stress);
            mine.mine_stress -= reduced;
            mine.last_update_block = now_block;
            shift.accrued_stabilization_work = saturating_add_u32(shift.accrued_stabilization_work, reduced);
            shift.last_settle_block = now_block;

            world.write_model(@charged_adventurer);
            world.write_model(@mine);
            world.write_model(@shift);
            world.emit_event(@MineStabilized { adventurer_id, mine_key, stress_reduced: reduced });
            reduced
        }

        fn exit_mining(ref self: ContractState, adventurer_id: felt252, mine_key: felt252) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !can_control_alive(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_EXIT, 'NOT_OWNER'_felt252);
                return 0_u16;
            }

            let shift_id = derive_mining_shift_id(adventurer_id, mine_key);
            let mut shift: MiningShift = world.read_model(shift_id);
            shift.shift_id = shift_id;
            if shift.status != MiningShiftStatus::Active {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_EXIT, 'SHIFT_INACTIVE'_felt252);
                return 0_u16;
            }

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_EXIT, 'MINE_UNINIT'_felt252);
                return 0_u16;
            }

            let mut inventory: Inventory = world.read_model(adventurer_id);
            let item_id = derive_mining_item_id(mine.ore_id);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let storehouse_bp = active_hex_building_effect_bp(ref world, mine.hex_coordinate, B_STOREHOUSE);
            let effective_max_weight = if storehouse_bp <= BP_ONE {
                inventory.max_weight
            } else {
                let boosted = apply_bp_floor_u32(inventory.max_weight, storehouse_bp);
                if boosted < inventory.max_weight { inventory.max_weight } else { boosted }
            };
            let capacity_left = if effective_max_weight > inventory.current_weight {
                effective_max_weight - inventory.current_weight
            } else {
                0_u32
            };
            let minted = min_u32(shift.accrued_ore_unbanked, capacity_left);
            if minted > 0_u32 {
                inventory.current_weight = saturating_add_u32(inventory.current_weight, minted);
                item.quantity = saturating_add_u32(item.quantity, minted);
                item.weight_per_unit = 1_u16;
                item.quality = 100_u16;
            }

            shift.accrued_ore_unbanked = 0_u32;
            shift.status = MiningShiftStatus::Exited;
            remove_shift_from_active_list(ref world, ref mine, shift);

            let mut unlocked = adventurer;
            unlocked.activity_locked_until = 0_u64;
            mine.last_update_block = now_block;

            world.write_model(@unlocked);
            world.write_model(@inventory);
            world.write_model(@item);
            world.write_model(@mine);

            let mut rate: ConversionRate = world.read_model(item_id);
            if rate.item_type == 0_felt252 {
                rate.item_type = item_id;
            }
            if rate.base_rate == 0_u16 {
                rate.base_rate = mine.conversion_energy_per_unit;
            }
            if rate.current_rate == 0_u16 {
                rate.current_rate = mine.conversion_energy_per_unit;
            }
            world.write_model(@rate);

            world.emit_event(@MiningExited { adventurer_id, mine_key, banked_ore: minted });
            to_u16_saturated(minted)
        }

        fn repair_mine(ref self: ContractState, adventurer_id: felt252, mine_key: felt252, energy_amount: u16) -> u32 {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !can_control_alive(adventurer, caller) {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_REPAIR, 'NOT_OWNER'_felt252);
                return 0_u32;
            }

            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            if mine.collapse_threshold == 0_u32 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_REPAIR, 'MINE_UNINIT'_felt252);
                return 0_u32;
            }
            if adventurer.current_hex != mine.hex_coordinate {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_REPAIR, 'WRONG_HEX'_felt252);
                return mine.repair_energy_needed;
            }
            if mine.is_depleted || mine.repair_energy_needed == 0_u32 {
                return mine.repair_energy_needed;
            }
            if energy_amount == 0_u16 {
                return mine.repair_energy_needed;
            }

            let repair_cap_u16 = if mine.repair_energy_needed > 65_535_u32 {
                65_535_u16
            } else {
                mine.repair_energy_needed.try_into().unwrap()
            };
            let to_spend = min_u16(min_u16(energy_amount, adventurer.energy), repair_cap_u16);
            if to_spend == 0_u16 {
                emit_rejection(ref world, adventurer_id, mine_key, ACTION_REPAIR, 'LOW_ENERGY'_felt252);
                return mine.repair_energy_needed;
            }

            let charged = spend_energy(adventurer, to_spend);
            let charged_adventurer = match charged {
                Option::Some(updated) => updated,
                Option::None => {
                    emit_rejection(ref world, adventurer_id, mine_key, ACTION_REPAIR, 'LOW_ENERGY'_felt252);
                    return mine.repair_energy_needed;
                },
            };

            mine.repair_energy_needed -= to_spend.into();
            if mine.repair_energy_needed == 0_u32 {
                mine.mine_stress = mine.collapse_threshold / 4_u32;
                mine.collapsed_until_block = 0_u64;
            }

            world.write_model(@charged_adventurer);
            world.write_model(@mine);
            world.emit_event(
                @MineRepaired {
                    mine_key,
                    adventurer_id,
                    energy_contributed: to_spend,
                    repair_energy_remaining: mine.repair_energy_needed,
                },
            );
            mine.repair_energy_needed
        }

        fn inspect_mine(self: @ContractState, hex_coordinate: felt252, area_id: felt252, mine_id: u8) -> MineNode {
            let world = self.world_default();
            let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
            let mut mine: MineNode = world.read_model(mine_key);
            mine.mine_key = mine_key;
            mine
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
