#[cfg(test)]
mod tests {
    use dojo_starter::libs::decay_math::upkeep_for_biome;
    use dojo_starter::libs::world_gen::{
        default_world_gen_config, derive_area_profile, derive_area_profile_with_config,
        derive_hex_profile, derive_hex_profile_with_config, derive_plant_profile,
        derive_plant_profile_with_config,
    };
    use dojo_starter::models::world::{AreaType, Biome, SizeCategory, WorldGenConfig};

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
        let base = derive_hex_profile(111_felt252);
        let c1 = derive_hex_profile(112_felt252);
        let c2 = derive_hex_profile(113_felt252);
        let c3 = derive_hex_profile(114_felt252);
        assert(base != c1 || base != c2 || base != c3, 'GEN_HEX_CHANGE');
    }

    #[test]
    fn world_gen_hex_profile_exposes_extended_biome_space() {
        let mut found_extended = false;
        let mut idx: u32 = 0_u32;
        loop {
            if idx == 500_u32 {
                break;
            };

            let coordinate: felt252 = (10_000_u32 + idx).into();
            let profile = derive_hex_profile(coordinate);
            match profile.biome {
                Biome::Plains => {},
                Biome::Forest => {},
                Biome::Mountain => {},
                Biome::Desert => {},
                Biome::Swamp => {},
                Biome::Unknown => {},
                _ => {
                    found_extended = true;
                    break;
                },
            }

            idx += 1_u32;
        };

        assert(found_extended, 'GEN_HEX_EXT_SPACE');
    }

    #[test]
    fn world_gen_hex_profile_surfaces_high_upkeep_biomes() {
        let mut found_high_upkeep = false;
        let mut idx: u32 = 0_u32;
        loop {
            if idx == 500_u32 {
                break;
            };

            let coordinate: felt252 = (20_000_u32 + idx).into();
            let profile = derive_hex_profile(coordinate);
            let upkeep = upkeep_for_biome(profile.biome);
            if upkeep > 65_u32 {
                found_high_upkeep = true;
                break;
            }

            idx += 1_u32;
        };

        assert(found_high_upkeep, 'GEN_HEX_HIGH_UPKEEP');
    }

    #[test]
    fn world_gen_hex_profile_sample_covers_all_20_biomes() {
        let mut plains: u32 = 0_u32;
        let mut forest: u32 = 0_u32;
        let mut mountain: u32 = 0_u32;
        let mut desert: u32 = 0_u32;
        let mut swamp: u32 = 0_u32;
        let mut tundra: u32 = 0_u32;
        let mut taiga: u32 = 0_u32;
        let mut jungle: u32 = 0_u32;
        let mut savanna: u32 = 0_u32;
        let mut grassland: u32 = 0_u32;
        let mut canyon: u32 = 0_u32;
        let mut badlands: u32 = 0_u32;
        let mut volcanic: u32 = 0_u32;
        let mut glacier: u32 = 0_u32;
        let mut wetlands: u32 = 0_u32;
        let mut steppe: u32 = 0_u32;
        let mut oasis: u32 = 0_u32;
        let mut mire: u32 = 0_u32;
        let mut highlands: u32 = 0_u32;
        let mut coast: u32 = 0_u32;

        let mut idx: u32 = 0_u32;
        loop {
            if idx == 600_u32 {
                break;
            };

            let coordinate: felt252 = (30_000_u32 + idx).into();
            let profile = derive_hex_profile(coordinate);
            match profile.biome {
                Biome::Plains => plains += 1_u32,
                Biome::Forest => forest += 1_u32,
                Biome::Mountain => mountain += 1_u32,
                Biome::Desert => desert += 1_u32,
                Biome::Swamp => swamp += 1_u32,
                Biome::Tundra => tundra += 1_u32,
                Biome::Taiga => taiga += 1_u32,
                Biome::Jungle => jungle += 1_u32,
                Biome::Savanna => savanna += 1_u32,
                Biome::Grassland => grassland += 1_u32,
                Biome::Canyon => canyon += 1_u32,
                Biome::Badlands => badlands += 1_u32,
                Biome::Volcanic => volcanic += 1_u32,
                Biome::Glacier => glacier += 1_u32,
                Biome::Wetlands => wetlands += 1_u32,
                Biome::Steppe => steppe += 1_u32,
                Biome::Oasis => oasis += 1_u32,
                Biome::Mire => mire += 1_u32,
                Biome::Highlands => highlands += 1_u32,
                Biome::Coast => coast += 1_u32,
                Biome::Unknown => {},
            }

            idx += 1_u32;
        };

        assert(plains > 0_u32, 'GEN_DIST_PLAINS');
        assert(forest > 0_u32, 'GEN_DIST_FOREST');
        assert(mountain > 0_u32, 'GEN_DIST_MTN');
        assert(desert > 0_u32, 'GEN_DIST_DESERT');
        assert(swamp > 0_u32, 'GEN_DIST_SWAMP');
        assert(tundra > 0_u32, 'GEN_DIST_TUNDRA');
        assert(taiga > 0_u32, 'GEN_DIST_TAIGA');
        assert(jungle > 0_u32, 'GEN_DIST_JUNGLE');
        assert(savanna > 0_u32, 'GEN_DIST_SAVANNA');
        assert(grassland > 0_u32, 'GEN_DIST_GRASS');
        assert(canyon > 0_u32, 'GEN_DIST_CANYON');
        assert(badlands > 0_u32, 'GEN_DIST_BADLAND');
        assert(volcanic > 0_u32, 'GEN_DIST_VOLC');
        assert(glacier > 0_u32, 'GEN_DIST_GLACIER');
        assert(wetlands > 0_u32, 'GEN_DIST_WET');
        assert(steppe > 0_u32, 'GEN_DIST_STEPPE');
        assert(oasis > 0_u32, 'GEN_DIST_OASIS');
        assert(mire > 0_u32, 'GEN_DIST_MIRE');
        assert(highlands > 0_u32, 'GEN_DIST_HIGH');
        assert(coast > 0_u32, 'GEN_DIST_COAST');
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
    fn world_gen_area_profile_reports_deterministic_plant_slot_bounds() {
        let first = derive_area_profile(778_felt252, 3_u8, Biome::Wetlands);
        let second = derive_area_profile(778_felt252, 3_u8, Biome::Wetlands);

        let slots_in_range = first.plant_slot_count >= 5_u8 && first.plant_slot_count <= 8_u8;
        assert(first.plant_slot_count == second.plant_slot_count, 'GEN_AREA_SLOTS_DET');
        assert(slots_in_range, 'GEN_AREA_SLOTS_RANGE');
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

    #[test]
    fn world_gen_with_config_defaults_match_plain_derivations() {
        let default_cfg = default_world_gen_config();
        let hex_plain = derive_hex_profile(222_felt252);
        let hex_cfg = derive_hex_profile_with_config(222_felt252, default_cfg);
        assert(hex_plain.biome == hex_cfg.biome, 'GEN_CFG_HEX_BIOME');
        assert(hex_plain.area_count == hex_cfg.area_count, 'GEN_CFG_HEX_AREAS');

        let area_plain = derive_area_profile(333_felt252, 2_u8, Biome::Forest);
        let area_cfg = derive_area_profile_with_config(333_felt252, 2_u8, Biome::Forest, default_cfg);
        assert(area_plain.area_type == area_cfg.area_type, 'GEN_CFG_AREA_TYPE');
        assert(area_plain.resource_quality == area_cfg.resource_quality, 'GEN_CFG_AREA_QUAL');
        assert(area_plain.size_category == area_cfg.size_category, 'GEN_CFG_AREA_SIZE');

        let plant_plain = derive_plant_profile(444_felt252, 445_felt252, 1_u8, Biome::Mountain);
        let plant_cfg = derive_plant_profile_with_config(
            444_felt252, 445_felt252, 1_u8, Biome::Mountain, default_cfg,
        );
        assert(plant_plain.species == plant_cfg.species, 'GEN_CFG_PLANT_SPEC');
        assert(plant_plain.max_yield == plant_cfg.max_yield, 'GEN_CFG_PLANT_MAX');
        assert(plant_plain.regrowth_rate == plant_cfg.regrowth_rate, 'GEN_CFG_PLANT_REGROW');
        assert(plant_plain.genetics_hash == plant_cfg.genetics_hash, 'GEN_CFG_PLANT_GENE');
    }

    #[test]
    fn world_gen_with_config_changes_output_when_tuning_changes() {
        let base = default_world_gen_config();
        let tuned = WorldGenConfig {
            generation_version: 2_u16,
            global_seed: 'WORLD_GEN_SEED_V1'_felt252,
            biome_scale_bp: 4000_u16,
            area_scale_bp: 9000_u16,
            plant_scale_bp: 12000_u16,
            biome_octaves: 6_u8,
            area_octaves: 7_u8,
            plant_octaves: 8_u8,
        };

        let base_hex = derive_hex_profile_with_config(555_felt252, base);
        let tuned_hex = derive_hex_profile_with_config(555_felt252, tuned);
        let base_area = derive_area_profile_with_config(555_felt252, 2_u8, Biome::Forest, base);
        let tuned_area = derive_area_profile_with_config(555_felt252, 2_u8, Biome::Forest, tuned);
        let base_plant = derive_plant_profile_with_config(555_felt252, 556_felt252, 1_u8, Biome::Forest, base);
        let tuned_plant = derive_plant_profile_with_config(
            555_felt252, 556_felt252, 1_u8, Biome::Forest, tuned,
        );

        assert(
            base_hex.biome != tuned_hex.biome || base_hex.area_count != tuned_hex.area_count
                || base_area.area_type != tuned_area.area_type
                || base_area.resource_quality != tuned_area.resource_quality
                || base_area.size_category != tuned_area.size_category
                || base_plant.species != tuned_plant.species
                || base_plant.max_yield != tuned_plant.max_yield
                || base_plant.regrowth_rate != tuned_plant.regrowth_rate
                || base_plant.genetics_hash != tuned_plant.genetics_hash,
            'GEN_CFG_TUNING_CHANGE',
        );
    }
}
