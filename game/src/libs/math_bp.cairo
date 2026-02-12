pub const BP_DENOMINATOR: u128 = 10000;

pub fn mul_bp_floor(value: u128, bp: u128) -> u128 {
    (value * bp) / BP_DENOMINATOR
}

pub fn div_floor(numerator: u128, denominator: u128) -> u128 {
    assert(denominator != 0, 'DIV_ZERO');
    numerator / denominator
}

pub fn clamp_u128(value: u128, min_value: u128, max_value: u128) -> u128 {
    assert(min_value <= max_value, 'BAD_BOUNDS');

    if value < min_value {
        return min_value;
    }

    if value > max_value {
        return max_value;
    }

    value
}
