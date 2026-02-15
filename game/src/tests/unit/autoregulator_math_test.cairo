#[cfg(test)]
mod tests {
    use dojo_starter::libs::autoregulator_math::{
        apply_deadband, clamp_policy_i32, pi_output_bp, update_integral, slew_limit_i32,
    };

    #[test]
    fn pi_deadband_zero_output() {
        let filtered = apply_deadband(1_i32, 1_i32);
        assert(filtered == 0_i32, 'AR_DB_Z');

        let output = pi_output_bp(filtered, 0_i32, 200_u16, 100_u16);
        assert(output == 0_i32, 'AR_PI_Z');
    }

    #[test]
    fn pi_positive_error_increases_output() {
        let integral = update_integral(0_i32, 8_i32, -100_i32, 100_i32);
        let output = pi_output_bp(8_i32, integral, 200_u16, 100_u16);
        assert(output > 0_i32, 'AR_PI_POS');
    }

    #[test]
    fn pi_negative_error_decreases_output() {
        let integral = update_integral(0_i32, -8_i32, -100_i32, 100_i32);
        let output = pi_output_bp(-8_i32, integral, 200_u16, 100_u16);
        assert(output < 0_i32, 'AR_PI_NEG');
    }

    #[test]
    fn integral_clamped_anti_windup() {
        let capped_high = update_integral(95_i32, 20_i32, -100_i32, 100_i32);
        assert(capped_high == 100_i32, 'AR_INT_HI');

        let capped_high_again = update_integral(capped_high, 20_i32, -100_i32, 100_i32);
        assert(capped_high_again == 100_i32, 'AR_INT_AW_H');

        let capped_low = update_integral(-95_i32, -20_i32, -100_i32, 100_i32);
        assert(capped_low == -100_i32, 'AR_INT_LO');

        let capped_low_again = update_integral(capped_low, -20_i32, -100_i32, 100_i32);
        assert(capped_low_again == -100_i32, 'AR_INT_AW_L');
    }

    #[test]
    fn slew_limit_caps_delta() {
        let up_limited = slew_limit_i32(100_i32, 140_i32, 20_i32);
        assert(up_limited == 120_i32, 'AR_SLEW_UP');

        let down_limited = slew_limit_i32(100_i32, 70_i32, 20_i32);
        assert(down_limited == 80_i32, 'AR_SLEW_DN');

        let unchanged = slew_limit_i32(100_i32, 115_i32, 20_i32);
        assert(unchanged == 115_i32, 'AR_SLEW_OK');
    }

    #[test]
    fn policy_clamps_hold_bounds() {
        let low = clamp_policy_i32(-10_i32, 5_i32, 25_i32);
        assert(low == 5_i32, 'AR_CLAMP_LO');

        let mid = clamp_policy_i32(15_i32, 5_i32, 25_i32);
        assert(mid == 15_i32, 'AR_CLAMP_MI');

        let high = clamp_policy_i32(40_i32, 5_i32, 25_i32);
        assert(high == 25_i32, 'AR_CLAMP_HI');
    }
}
