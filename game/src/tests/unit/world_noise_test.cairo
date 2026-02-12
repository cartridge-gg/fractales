#[cfg(test)]
mod tests {
    use dojo_starter::libs::world_noise::{
        noise_percentile_roll, sanitize_octaves, sanitize_scale_bp,
    };

    #[test]
    fn world_noise_roll_is_deterministic_and_bounded() {
        let a = noise_percentile_roll(123_felt252, 321_felt252, 2500_u16, 4_u8);
        let b = noise_percentile_roll(123_felt252, 321_felt252, 2500_u16, 4_u8);
        assert(a == b, 'NOISE_DET');
        assert(a <= 100_u32, 'NOISE_HIGH');
    }

    #[test]
    fn world_noise_tuning_changes_roll() {
        let base = noise_percentile_roll(777_felt252, 888_felt252, 1500_u16, 2_u8);
        let tuned = noise_percentile_roll(777_felt252, 888_felt252, 9500_u16, 7_u8);
        assert(base != tuned, 'NOISE_TUNE_CHANGE');
    }

    #[test]
    fn world_noise_sanitizers_enforce_ranges() {
        assert(sanitize_scale_bp(0_u16, 2200_u16) == 2200_u16, 'NOISE_SCALE_DEFAULT');
        assert(sanitize_scale_bp(30000_u16, 2200_u16) == 20000_u16, 'NOISE_SCALE_CLAMP');
        assert(sanitize_octaves(0_u8, 3_u8) == 3_u8, 'NOISE_OCT_DEFAULT');
        assert(sanitize_octaves(22_u8, 3_u8) == 8_u8, 'NOISE_OCT_CLAMP');
    }
}
