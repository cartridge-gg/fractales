#[cfg(test)]
mod tests {
    use dojo_starter::events::world_events::{
        AreaDiscovered, HexDiscovered, WorldActionRejected, WorldGenConfigInitialized,
    };
    use dojo_starter::models::world::{AreaType, Biome};
    use starknet::ContractAddress;

    #[test]
    fn world_events_hex_discovered_payload_shape() {
        let discoverer: ContractAddress = 777.try_into().unwrap();
        let event = HexDiscovered {
            hex: 4242_felt252,
            biome: Biome::Forest,
            discoverer,
        };

        assert(event.hex == 4242_felt252, 'HEX_EVENT_HEX');
        assert(event.biome == Biome::Forest, 'HEX_EVENT_BIOME');
        assert(event.discoverer == discoverer, 'HEX_EVENT_DISCOVERER');
    }

    #[test]
    fn world_events_area_discovered_payload_shape() {
        let discoverer: ContractAddress = 888.try_into().unwrap();
        let event = AreaDiscovered {
            area_id: 9999_felt252,
            hex: 5555_felt252,
            area_type: AreaType::PlantField,
            discoverer,
        };

        assert(event.area_id == 9999_felt252, 'AREA_EVENT_ID');
        assert(event.hex == 5555_felt252, 'AREA_EVENT_HEX');
        assert(event.area_type == AreaType::PlantField, 'AREA_EVENT_TYPE');
        assert(event.discoverer == discoverer, 'AREA_EVENT_DISCOVERER');
    }

    #[test]
    fn world_events_world_gen_config_initialized_payload_shape() {
        let event = WorldGenConfigInitialized {
            generation_version: 1_u16,
            global_seed: 'WORLD_GEN_SEED_V1'_felt252,
            biome_scale_bp: 2200_u16,
            area_scale_bp: 2400_u16,
            plant_scale_bp: 2600_u16,
            biome_octaves: 3_u8,
            area_octaves: 4_u8,
            plant_octaves: 5_u8,
        };

        assert(event.generation_version == 1_u16, 'GEN_EVENT_VERSION');
        assert(event.global_seed == 'WORLD_GEN_SEED_V1'_felt252, 'GEN_EVENT_SEED');
        assert(event.plant_octaves == 5_u8, 'GEN_EVENT_OCT');
    }

    #[test]
    fn world_events_action_rejected_payload_shape() {
        let event = WorldActionRejected {
            adventurer_id: 7004_felt252,
            action: 'MOVE'_felt252,
            target: 4242_felt252,
            reason: 'NOT_ADJ'_felt252,
        };

        assert(event.adventurer_id == 7004_felt252, 'REJ_EVENT_ADV');
        assert(event.action == 'MOVE'_felt252, 'REJ_EVENT_ACTION');
        assert(event.target == 4242_felt252, 'REJ_EVENT_TARGET');
        assert(event.reason == 'NOT_ADJ'_felt252, 'REJ_EVENT_REASON');
    }
}
