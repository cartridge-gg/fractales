#[cfg(test)]
mod tests {
    use dojo_starter::systems::mining_manager::apply_shoring_stress_delta;

    #[test]
    fn mining_manager_shoring_stress_delta_reduces_by_bonus_margin() {
        let base = 500_u32;
        assert(apply_shoring_stress_delta(base, 10_000_u16) == 500_u32, 'MMGR_SHORE_NONE');
        assert(apply_shoring_stress_delta(base, 14_000_u16) == 300_u32, 'MMGR_SHORE_40');
        assert(apply_shoring_stress_delta(base, 9_900_u16) == 500_u32, 'MMGR_SHORE_SUB');
        assert(apply_shoring_stress_delta(base, 20_000_u16) == 0_u32, 'MMGR_SHORE_ZERO');
    }
}
