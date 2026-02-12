#[cfg(test)]
mod tests {
    use dojo_starter::events::world_events::{AreaDiscovered, HexDiscovered};
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
}
