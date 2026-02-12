#[cfg(test)]
mod tests {
    use dojo_starter::libs::world_rng::{
        DOMAIN_AREA_V1, DOMAIN_HEX_V1, bounded_u32, derive_area_seed, derive_gene_seed,
        derive_hex_seed, derive_plant_seed, derive_with_domain,
    };

    #[test]
    fn world_rng_seed_tree_is_deterministic() {
        let global_seed = 111222333444_felt252;
        let hex_coordinate = 987654321_felt252;
        let area_index = 2_u8;
        let plant_id = 5_u8;
        let species = 'ROOT'_felt252;

        let hex_a = derive_hex_seed(global_seed, hex_coordinate);
        let hex_b = derive_hex_seed(global_seed, hex_coordinate);
        assert(hex_a == hex_b, 'RNG_HEX_DET');

        let area_a = derive_area_seed(hex_a, area_index);
        let area_b = derive_area_seed(hex_b, area_index);
        assert(area_a == area_b, 'RNG_AREA_DET');

        let plant_a = derive_plant_seed(area_a, plant_id);
        let plant_b = derive_plant_seed(area_b, plant_id);
        assert(plant_a == plant_b, 'RNG_PLANT_DET');

        let gene_a = derive_gene_seed(plant_a, species);
        let gene_b = derive_gene_seed(plant_b, species);
        assert(gene_a == gene_b, 'RNG_GENE_DET');
    }

    #[test]
    fn world_rng_domain_separation_changes_output() {
        let parent_seed = 77_felt252;
        let entropy = 12_felt252;
        let hex_seed = derive_with_domain(parent_seed, entropy, DOMAIN_HEX_V1);
        let area_seed = derive_with_domain(parent_seed, entropy, DOMAIN_AREA_V1);
        assert(hex_seed != area_seed, 'RNG_DOMAIN_COLLIDE');
    }

    #[test]
    fn world_rng_seed_tree_changes_with_input() {
        let global_seed = 123_felt252;

        let hex_a = derive_hex_seed(global_seed, 1000_felt252);
        let hex_b = derive_hex_seed(global_seed, 1001_felt252);
        assert(hex_a != hex_b, 'RNG_HEX_CHANGE');

        let area_a = derive_area_seed(hex_a, 1_u8);
        let area_b = derive_area_seed(hex_a, 2_u8);
        assert(area_a != area_b, 'RNG_AREA_CHANGE');

        let plant_a = derive_plant_seed(area_a, 1_u8);
        let plant_b = derive_plant_seed(area_a, 2_u8);
        assert(plant_a != plant_b, 'RNG_PLANT_CHANGE');
    }

    #[test]
    fn world_rng_bounded_u32_is_deterministic_and_in_range() {
        let seed = derive_hex_seed(999_felt252, 123456_felt252);
        let first_opt = bounded_u32(seed, 30_u32, 101_u32);
        let second_opt = bounded_u32(seed, 30_u32, 101_u32);

        let first = match first_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'RNG_BOUND_NONE');
                0_u32
            },
        };
        let second = match second_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'RNG_BOUND_NONE2');
                0_u32
            },
        };

        assert(first == second, 'RNG_BOUND_DET');
        assert(first >= 30_u32, 'RNG_BOUND_LOW');
        assert(first < 101_u32, 'RNG_BOUND_HIGH');
    }

    #[test]
    fn world_rng_bounded_u32_rejects_invalid_range() {
        match bounded_u32(10_felt252, 5_u32, 5_u32) {
            Option::None => {},
            Option::Some(_) => {
                assert(1 == 0, 'RNG_BOUND_EQ_BAD');
            },
        };
        match bounded_u32(10_felt252, 9_u32, 2_u32) {
            Option::None => {},
            Option::Some(_) => {
                assert(1 == 0, 'RNG_BOUND_INV_BAD');
            },
        };
    }
}
