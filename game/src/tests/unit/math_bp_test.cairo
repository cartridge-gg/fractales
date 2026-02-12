#[cfg(test)]
mod tests {
    use dojo_starter::libs::math_bp::{clamp_u128, div_floor, mul_bp_floor};

    #[test]
    fn math_bp_mul_floor() {
        // floor(333 * 1500 / 10000) = floor(49.95) = 49
        let result = mul_bp_floor(333_u128, 1500_u128);
        assert(result == 49_u128, 'MUL_FLOOR');
    }

    #[test]
    fn math_bp_div_floor() {
        let result = div_floor(10_u128, 3_u128);
        assert(result == 3_u128, 'DIV_FLOOR');
    }

    #[test]
    fn math_bp_clamp_low_mid_high() {
        let low = clamp_u128(3_u128, 5_u128, 9_u128);
        let mid = clamp_u128(7_u128, 5_u128, 9_u128);
        let high = clamp_u128(12_u128, 5_u128, 9_u128);

        assert(low == 5_u128, 'CLAMP_LOW');
        assert(mid == 7_u128, 'CLAMP_MID');
        assert(high == 9_u128, 'CLAMP_HIGH');
    }
}
