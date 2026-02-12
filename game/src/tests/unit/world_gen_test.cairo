#[cfg(test)]
mod tests {
    use dojo_starter::libs::world_gen::{
        derive_area_profile, derive_hex_profile, derive_plant_profile,
    };
    use dojo_starter::models::world::{AreaType, Biome, SizeCategory};

    #[test]
    fn world_gen_hex_profile_is_deterministic_and_bounded() {
        let coordinate = 12345_felt252;
        let first = derive_hex_profile(coordinate);
        let second = derive_hex_profile(coordinate);

        assert(first.biome == second.biome, 'GEN_HEX_BIOME_DET');
        assert(first.area_count == second.area_count, 'GEN_HEX_AREAS_DET');
        assert(first.area_count >= 3_u8, 'GEN_HEX_AREAS_LOW');
        assert(first.area_count <= 6_u8, 'GEN_HEX_AREAS_HIGH');
    }

    #[test]
    fn world_gen_hex_profile_changes_with_coordinate() {
        let first = derive_hex_profile(111_felt252);
        let second = derive_hex_profile(112_felt252);
        assert(
            first.biome != second.biome || first.area_count != second.area_count,
            'GEN_HEX_CHANGE',
        );
    }

    #[test]
    fn world_gen_area_control_index_forces_control_type() {
        let profile = derive_area_profile(555_felt252, 0_u8, Biome::Forest);
        assert(profile.area_type == AreaType::Control, 'GEN_AREA_CTRL');
    }

    #[test]
    fn world_gen_area_profile_is_deterministic_and_bounded() {
        let first = derive_area_profile(777_felt252, 2_u8, Biome::Desert);
        let second = derive_area_profile(777_felt252, 2_u8, Biome::Desert);

        assert(first.area_type == second.area_type, 'GEN_AREA_TYPE_DET');
        assert(first.resource_quality == second.resource_quality, 'GEN_AREA_QUAL_DET');
        assert(first.size_category == second.size_category, 'GEN_AREA_SIZE_DET');
        assert(first.resource_quality >= 30_u16, 'GEN_AREA_QUAL_LOW');
        assert(first.resource_quality <= 100_u16, 'GEN_AREA_QUAL_HIGH');
    }

    #[test]
    fn world_gen_area_profile_size_is_valid_enum() {
        let profile = derive_area_profile(888_felt252, 5_u8, Biome::Swamp);
        assert(
            profile.size_category == SizeCategory::Small
                || profile.size_category == SizeCategory::Medium
                || profile.size_category == SizeCategory::Large,
            'GEN_AREA_SIZE_ENUM',
        );
    }

    #[test]
    fn world_gen_plant_profile_is_deterministic_and_bounded() {
        let first = derive_plant_profile(990_felt252, 991_felt252, 1_u8, Biome::Forest);
        let second = derive_plant_profile(990_felt252, 991_felt252, 1_u8, Biome::Forest);

        assert(first.species == second.species, 'GEN_PLANT_SPEC_DET');
        assert(first.max_yield == second.max_yield, 'GEN_PLANT_MAX_DET');
        assert(first.regrowth_rate == second.regrowth_rate, 'GEN_PLANT_REGROW_DET');
        assert(first.genetics_hash == second.genetics_hash, 'GEN_PLANT_GENE_DET');
        assert(first.max_yield > 0_u16, 'GEN_PLANT_MAX_POS');
        assert(first.regrowth_rate > 0_u16, 'GEN_PLANT_REGROW_POS');
        assert(first.max_yield <= 80_u16, 'GEN_PLANT_MAX_HIGH');
        assert(first.regrowth_rate <= 4_u16, 'GEN_PLANT_REGROW_HIGH');
    }

    #[test]
    fn world_gen_plant_profile_is_biome_aware() {
        let forest = derive_plant_profile(992_felt252, 993_felt252, 2_u8, Biome::Forest);
        let desert = derive_plant_profile(992_felt252, 993_felt252, 2_u8, Biome::Desert);
        assert(forest.species != desert.species, 'GEN_PLANT_BIOME_SPECIES');
    }

    #[test]
    fn world_gen_plant_profile_changes_with_plant_id() {
        let plant_a = derive_plant_profile(994_felt252, 995_felt252, 1_u8, Biome::Swamp);
        let plant_b = derive_plant_profile(994_felt252, 995_felt252, 2_u8, Biome::Swamp);
        assert(plant_a.genetics_hash != plant_b.genetics_hash, 'GEN_PLANT_GENE_CHANGE');
    }
}
