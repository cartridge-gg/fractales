#[cfg(test)]
mod tests {
    use dojo_starter::models::world::{
        AreaType, Biome, DiscoveryWriteStatus, Hex, HexArea, SizeCategory, derive_area_id,
        discover_area_once, discover_area_once_with_status, discover_hex_once,
        discover_hex_once_with_status, is_valid_area_identity, is_valid_area_index,
    };
    use starknet::ContractAddress;

    #[test]
    fn world_models_area_id_is_deterministic() {
        let hex_a: felt252 = 1234567;
        let hex_b: felt252 = 7654321;

        let area_a0_first = derive_area_id(hex_a, 0_u8);
        let area_a0_second = derive_area_id(hex_a, 0_u8);
        let area_a1 = derive_area_id(hex_a, 1_u8);
        let area_b0 = derive_area_id(hex_b, 0_u8);

        assert(area_a0_first == area_a0_second, 'AREAID_SAME_INPUT');
        assert(area_a0_first != area_a1, 'AREAID_DIFF_INDEX');
        assert(area_a0_first != area_b0, 'AREAID_DIFF_HEX');
    }

    #[test]
    fn world_models_area_id_matches_poseidon_domain_hash() {
        let hex: felt252 = 2026;
        let area_index: u8 = 7_u8;
        let area_index_felt: felt252 = area_index.into();

        let expected = {
            let (hashed, _, _) = core::poseidon::hades_permutation(
                hex, area_index_felt, 'AREA_ID_V1'_felt252,
            );
            hashed
        };

        let derived = derive_area_id(hex, area_index);
        assert(derived == expected, 'AREAID_HASH_MISMATCH');
    }

    #[test]
    fn world_models_area_index_validation_bounds() {
        assert(is_valid_area_index(0_u8, 1_u8), 'AREA_IDX_ZERO_VALID');
        assert(is_valid_area_index(5_u8, 6_u8), 'AREA_IDX_LAST_VALID');
        assert(!is_valid_area_index(6_u8, 6_u8), 'AREA_IDX_EQUAL_COUNT');
        assert(!is_valid_area_index(255_u8, 0_u8), 'AREA_IDX_EMPTY_HEX');
    }

    #[test]
    fn world_models_area_identity_validation() {
        let hex: felt252 = 6060;
        let valid_area = HexArea {
            area_id: derive_area_id(hex, 3_u8),
            hex_coordinate: hex,
            area_index: 3_u8,
            area_type: AreaType::Wilderness,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };

        let invalid_area = HexArea { area_id: derive_area_id(hex, 2_u8), ..valid_area };

        assert(is_valid_area_identity(valid_area), 'AREA_IDENTITY_VALID');
        assert(!is_valid_area_identity(invalid_area), 'AREA_IDENTITY_INVALID');
    }

    #[test]
    fn world_models_hex_discovery_idempotent_and_immutable() {
        let undiscovered = Hex {
            coordinate: 101,
            biome: Biome::Plains,
            is_discovered: false,
            discovery_block: 0,
            discoverer: 0.try_into().unwrap(),
            area_count: 0_u8,
        };

        let first_discoverer: ContractAddress = 111.try_into().unwrap();
        let replay_discoverer: ContractAddress = 222.try_into().unwrap();

        let first = discover_hex_once(
            undiscovered, first_discoverer, 50_u64, Biome::Forest, 6_u8,
        );
        assert(first.is_discovered, 'HEX_DISCOVERED_FALSE');
        assert(first.discoverer == first_discoverer, 'HEX_DISCOVERER_FIRST');
        assert(first.discovery_block == 50_u64, 'HEX_DISCOVERY_BLOCK_FIRST');
        assert(first.area_count == 6_u8, 'HEX_AREA_COUNT_FIRST');
        assert(first.biome == Biome::Forest, 'HEX_BIOME_FIRST');

        let replay = discover_hex_once(first, replay_discoverer, 99_u64, Biome::Desert, 3_u8);
        assert(replay.is_discovered, 'HEX_REPLAY_DISCOVERED_FALSE');
        assert(replay.discoverer == first_discoverer, 'HEX_REPLAY_DISCOVERER_MUT');
        assert(replay.discovery_block == 50_u64, 'HEX_REPLAY_BLOCK_MUT');
        assert(replay.area_count == 6_u8, 'HEX_REPLAY_COUNT_MUT');
        assert(replay.biome == Biome::Forest, 'HEX_REPLAY_BIOME_MUT');
    }

    #[test]
    fn world_models_area_discovery_idempotent_and_immutable() {
        let hex: felt252 = 8080;
        let area_index: u8 = 2_u8;
        let area_id = derive_area_id(hex, area_index);
        let undiscovered = HexArea {
            area_id,
            hex_coordinate: hex,
            area_index,
            area_type: AreaType::Control,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };

        let first_discoverer: ContractAddress = 333.try_into().unwrap();
        let replay_discoverer: ContractAddress = 444.try_into().unwrap();

        let first = discover_area_once(
            undiscovered,
            first_discoverer,
            AreaType::PlantField,
            77_u16,
            SizeCategory::Large,
            6_u8,
        );
        assert(first.is_discovered, 'AREA_DISCOVERED_FALSE');
        assert(first.discoverer == first_discoverer, 'AREA_DISCOVERER_FIRST');
        assert(first.area_type == AreaType::PlantField, 'AREA_TYPE_FIRST');
        assert(first.resource_quality == 77_u16, 'AREA_QUALITY_FIRST');
        assert(first.size_category == SizeCategory::Large, 'AREA_SIZE_FIRST');
        assert(first.plant_slot_count == 6_u8, 'AREA_SLOTS_FIRST');

        let replay = discover_area_once(
            first,
            replay_discoverer,
            AreaType::Wilderness,
            1_u16,
            SizeCategory::Medium,
            1_u8,
        );
        assert(replay.is_discovered, 'AREA_REPLAY_DISCOVERED_FALSE');
        assert(replay.discoverer == first_discoverer, 'AREA_REPLAY_DISCOVERER_MUT');
        assert(replay.area_type == AreaType::PlantField, 'AREA_REPLAY_TYPE_MUT');
        assert(replay.resource_quality == 77_u16, 'AREA_REPLAY_QUALITY_MUT');
        assert(replay.size_category == SizeCategory::Large, 'AREA_REPLAY_SIZE_MUT');
        assert(replay.plant_slot_count == 6_u8, 'AREA_REPLAY_SLOTS_MUT');
    }

    #[test]
    fn world_models_discover_helpers_return_write_status() {
        let undiscovered_hex = Hex {
            coordinate: 500,
            biome: Biome::Plains,
            is_discovered: false,
            discovery_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
            area_count: 0_u8,
        };
        let discoverer: ContractAddress = 321.try_into().unwrap();
        let first_hex = discover_hex_once_with_status(
            undiscovered_hex, discoverer, 10_u64, Biome::Desert, 4_u8,
        );
        assert(first_hex.status == DiscoveryWriteStatus::Applied, 'HEX_STATUS_FIRST');
        let replay_hex = discover_hex_once_with_status(
            first_hex.value, 999.try_into().unwrap(), 99_u64, Biome::Swamp, 2_u8,
        );
        assert(replay_hex.status == DiscoveryWriteStatus::Replay, 'HEX_STATUS_REPLAY');

        let area = HexArea {
            area_id: derive_area_id(500, 0_u8),
            hex_coordinate: 500,
            area_index: 0_u8,
            area_type: AreaType::Control,
            is_discovered: false,
            discoverer: 0.try_into().unwrap(),
            resource_quality: 0_u16,
            size_category: SizeCategory::Small,
            plant_slot_count: 0_u8,
        };
        let first_area = discover_area_once_with_status(
            area, discoverer, AreaType::PlantField, 55_u16, SizeCategory::Medium, 5_u8,
        );
        assert(first_area.status == DiscoveryWriteStatus::Applied, 'AREA_STATUS_FIRST');
        let replay_area = discover_area_once_with_status(
            first_area.value,
            888.try_into().unwrap(),
            AreaType::Wilderness,
            1_u16,
            SizeCategory::Large,
            1_u8,
        );
        assert(replay_area.status == DiscoveryWriteStatus::Replay, 'AREA_STATUS_REPLAY');
    }
}
