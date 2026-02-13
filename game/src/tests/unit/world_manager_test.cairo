#[cfg(test)]
mod tests {
    use dojo_starter::models::world::{AreaType, Biome, Hex, HexArea, SizeCategory, derive_area_id};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::libs::coord_codec::CubeCoord;
    use dojo_starter::systems::world_manager::{
        ActorSpendGuardOutcome, ActorSpendGuardResult, AreaDiscoverOutcome, DiscoverAreaResult,
        DiscoverHexResult, HexDiscoverOutcome, MoveOutcome, MoveResult, discover_area_transition,
        discover_hex_transition, guard_owner_alive_and_spend, move_cost_if_adjacent, move_transition,
    };
    use starknet::ContractAddress;

    #[test]
    fn world_manager_discover_hex_first_discovery_spends_energy_and_emits() {
        let undiscovered = Hex {
            coordinate: 9001,
            biome: Biome::Plains,
            is_discovered: false,
            discovery_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
            area_count: 0_u8,
        };
        let discoverer: ContractAddress = 42.try_into().unwrap();
        let result: DiscoverHexResult = discover_hex_transition(
            undiscovered, discoverer, 15_u64, Biome::Forest, 6_u8, 25_u16,
        );

        assert(result.outcome == HexDiscoverOutcome::Applied, 'HEX_OUTCOME_FIRST');
        assert(result.energy_spent == 25_u16, 'HEX_ENERGY_FIRST');
        assert(result.emit_event, 'HEX_EVENT_FIRST');
        assert(result.hex.discoverer == discoverer, 'HEX_DISCOVERER_FIRST');
        assert(result.hex.discovery_block == 15_u64, 'HEX_BLOCK_FIRST');
    }

    #[test]
    fn world_manager_discover_hex_replay_spends_zero_and_no_event() {
        let discovered = Hex {
            coordinate: 9002,
            biome: Biome::Desert,
            is_discovered: true,
            discovery_block: 10_u64,
            discoverer: 11.try_into().unwrap(),
            area_count: 4_u8,
        };

        let replay_discoverer: ContractAddress = 99.try_into().unwrap();
        let result: DiscoverHexResult = discover_hex_transition(
            discovered, replay_discoverer, 50_u64, Biome::Swamp, 7_u8, 25_u16,
        );

        assert(result.outcome == HexDiscoverOutcome::Replay, 'HEX_OUTCOME_REPLAY');
        assert(result.energy_spent == 0_u16, 'HEX_ENERGY_REPLAY');
        assert(!result.emit_event, 'HEX_EVENT_REPLAY');
        assert(result.hex.discoverer == 11.try_into().unwrap(), 'HEX_DISCOVERER_IMMUTABLE');
        assert(result.hex.discovery_block == 10_u64, 'HEX_BLOCK_IMMUTABLE');
    }

    #[test]
    fn world_manager_discover_area_rejects_invalid_index() {
        let discoverer: ContractAddress = 99.try_into().unwrap();
        let area = HexArea {
            area_id: derive_area_id(1111, 6_u8),
            hex_coordinate: 1111,
            area_index: 6_u8,
            area_type: AreaType::Control,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };

        let result: DiscoverAreaResult = discover_area_transition(
            area, discoverer, AreaType::PlantField, 55_u16, SizeCategory::Large, 5_u8, 6_u8,
        );

        assert(result.outcome == AreaDiscoverOutcome::InvalidAreaIndex, 'AREA_OUTCOME_INVALID');
        assert(!result.emit_event, 'AREA_EVENT_INVALID');
        assert(!result.area.is_discovered, 'AREA_DISCOVERED_INVALID');
    }

    #[test]
    fn world_manager_discover_area_first_discovery_emits_event() {
        let area = HexArea {
            area_id: derive_area_id(2222, 2_u8),
            hex_coordinate: 2222,
            area_index: 2_u8,
            area_type: AreaType::Control,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };

        let discoverer: ContractAddress = 77.try_into().unwrap();
        let result: DiscoverAreaResult = discover_area_transition(
            area, discoverer, AreaType::PlantField, 88_u16, SizeCategory::Medium, 6_u8, 6_u8,
        );

        assert(result.outcome == AreaDiscoverOutcome::Applied, 'AREA_OUTCOME_FIRST');
        assert(result.emit_event, 'AREA_EVENT_FIRST');
        assert(result.area.is_discovered, 'AREA_DISCOVERED_FIRST');
        assert(result.area.discoverer == discoverer, 'AREA_DISCOVERER_FIRST');
        assert(result.area.resource_quality == 88_u16, 'AREA_QUALITY_FIRST');
    }

    #[test]
    fn world_manager_discover_area_rejects_invalid_identity() {
        let discoverer: ContractAddress = 66.try_into().unwrap();
        let area = HexArea {
            area_id: derive_area_id(3333, 1_u8),
            hex_coordinate: 3333,
            area_index: 2_u8,
            area_type: AreaType::Control,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };

        let result: DiscoverAreaResult = discover_area_transition(
            area, discoverer, AreaType::PlantField, 33_u16, SizeCategory::Medium, 4_u8, 6_u8,
        );

        assert(
            result.outcome == AreaDiscoverOutcome::InvalidAreaIdentity, 'AREA_OUTCOME_IDENTITY',
        );
        assert(!result.emit_event, 'AREA_EVENT_IDENTITY');
        assert(!result.area.is_discovered, 'AREA_DISCOVERED_IDENTITY');
    }

    #[test]
    fn world_manager_move_requires_adjacency() {
        let from = CubeCoord { x: 0, y: 0, z: 0 };
        let to_adjacent = CubeCoord { x: 1, y: -1, z: 0 };
        let to_far = CubeCoord { x: 2, y: -1, z: -1 };

        let adjacent_cost = move_cost_if_adjacent(from, to_adjacent, 15_u16);
        let far_cost = move_cost_if_adjacent(from, to_far, 15_u16);

        match adjacent_cost {
            Option::Some(found_cost) => assert(found_cost == 15_u16, 'MOVE_COST_ADJ'),
            Option::None => assert(1 == 0, 'MOVE_ADJ_NONE'),
        }
        match far_cost {
            Option::None => {},
            Option::Some(_) => assert(1 == 0, 'MOVE_FAR_SOME'),
        }
    }

    #[test]
    fn world_manager_move_transition_sets_outcome_energy_and_event() {
        let from = CubeCoord { x: 0, y: 0, z: 0 };
        let to_adjacent = CubeCoord { x: 0, y: 1, z: -1 };
        let to_far = CubeCoord { x: 2, y: -1, z: -1 };

        let applied: MoveResult = move_transition(from, to_adjacent, 15_u16);
        let rejected: MoveResult = move_transition(from, to_far, 15_u16);

        assert(applied.outcome == MoveOutcome::Applied, 'MOVE_OUTCOME_APPLIED');
        assert(applied.energy_spent == 15_u16, 'MOVE_ENERGY_APPLIED');
        assert(applied.emit_event, 'MOVE_EVENT_APPLIED');
        assert(applied.from == from, 'MOVE_FROM_APPLIED');
        assert(applied.to == to_adjacent, 'MOVE_TO_APPLIED');

        assert(rejected.outcome == MoveOutcome::NotAdjacent, 'MOVE_OUTCOME_REJECTED');
        assert(rejected.energy_spent == 0_u16, 'MOVE_ENERGY_REJECTED');
        assert(!rejected.emit_event, 'MOVE_EVENT_REJECTED');
    }

    #[test]
    fn world_manager_actor_guard_enforces_owner_alive_and_energy() {
        let base = Adventurer {
            adventurer_id: 11,
            owner: 111.try_into().unwrap(),
            name: 'ACTOR'_felt252,
            energy: 20_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let owner: ContractAddress = 111.try_into().unwrap();
        let stranger: ContractAddress = 222.try_into().unwrap();

        let success: ActorSpendGuardResult = guard_owner_alive_and_spend(
            base, owner, 15_u16,
        );
        assert(success.outcome == ActorSpendGuardOutcome::Applied, 'GUARD_OK_OUTCOME');
        assert(success.adventurer.energy == 5_u16, 'GUARD_OK_ENERGY');

        let wrong_owner = guard_owner_alive_and_spend(base, stranger, 5_u16);
        assert(wrong_owner.outcome == ActorSpendGuardOutcome::NotOwner, 'GUARD_OWNER_OUTCOME');
        assert(wrong_owner.adventurer.energy == 20_u16, 'GUARD_OWNER_ENERGY');

        let dead = Adventurer { is_alive: false, ..base };
        let dead_result = guard_owner_alive_and_spend(dead, owner, 1_u16);
        assert(dead_result.outcome == ActorSpendGuardOutcome::Dead, 'GUARD_DEAD_OUTCOME');

        let low_energy = guard_owner_alive_and_spend(base, owner, 21_u16);
        assert(low_energy.outcome == ActorSpendGuardOutcome::InsufficientEnergy, 'GUARD_LOW_OUTCOME');
    }
}
