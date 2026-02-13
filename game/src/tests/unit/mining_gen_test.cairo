#[cfg(test)]
mod tests {
    use dojo_starter::libs::mining_gen::{
        MineProfile, derive_area_mine_slot_count, derive_mine_profile,
    };
    use dojo_starter::models::world::Biome;

    #[test]
    fn mining_gen_area_slot_count_is_deterministic_and_bounded() {
        let first = derive_area_mine_slot_count(777_felt252, 778_felt252, Biome::Mountain);
        let second = derive_area_mine_slot_count(777_felt252, 778_felt252, Biome::Mountain);
        assert(first == second, 'MGEN_SLOT_DET');
        assert(first >= 1_u8, 'MGEN_SLOT_LOW');
        assert(first <= 8_u8, 'MGEN_SLOT_HIGH');
    }

    #[test]
    fn mining_gen_mine_profile_is_deterministic() {
        let first: MineProfile = derive_mine_profile(1001_felt252, 1002_felt252, 3_u8, Biome::Volcanic);
        let second: MineProfile = derive_mine_profile(1001_felt252, 1002_felt252, 3_u8, Biome::Volcanic);

        assert(first.ore_id == second.ore_id, 'MGEN_ORE_DET');
        assert(first.rarity_tier == second.rarity_tier, 'MGEN_RAR_DET');
        assert(first.depth_tier == second.depth_tier, 'MGEN_DEPTH_DET');
        assert(first.richness_bp == second.richness_bp, 'MGEN_RICH_DET');
        assert(first.remaining_reserve == second.remaining_reserve, 'MGEN_RESV_DET');
        assert(first.collapse_threshold == second.collapse_threshold, 'MGEN_COLL_DET');
    }

    #[test]
    fn mining_gen_profile_bounds_match_locked_ranges() {
        let p: MineProfile = derive_mine_profile(2001_felt252, 2002_felt252, 6_u8, Biome::Highlands);
        assert(p.rarity_tier <= 4_u8, 'MGEN_RAR_RANGE');
        assert(p.depth_tier >= 1_u8, 'MGEN_DEPTH_LOW');
        assert(p.depth_tier <= 5_u8, 'MGEN_DEPTH_HIGH');
        assert(p.richness_bp >= 7_000_u16, 'MGEN_RICH_LOW');
        assert(p.richness_bp <= 16_000_u16, 'MGEN_RICH_HIGH');
        assert(p.remaining_reserve > 0_u32, 'MGEN_RESV_POS');
        assert(p.collapse_threshold > 0_u32, 'MGEN_COLL_POS');
        assert(p.safe_shift_blocks >= 4_u64, 'MGEN_SAFE_LOW');
        assert(p.biome_risk_bp >= 10_000_u16, 'MGEN_BRISK_LOW');
        assert(p.rarity_risk_bp >= 10_000_u16, 'MGEN_RRISK_LOW');
    }
}
