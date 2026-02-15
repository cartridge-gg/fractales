pub const CONTROLLER_SCALE: i32 = 100_i32;

fn abs_i32(value: i32) -> i32 {
    if value < 0_i32 {
        0_i32 - value
    } else {
        value
    }
}

pub fn clamp_policy_i32(value: i32, min_value: i32, max_value: i32) -> i32 {
    assert(min_value <= max_value, 'AR_BOUNDS');

    if value < min_value {
        return min_value;
    }

    if value > max_value {
        return max_value;
    }

    value
}

pub fn apply_deadband(error: i32, deadband: i32) -> i32 {
    assert(deadband >= 0_i32, 'AR_DEADBAND');

    if abs_i32(error) <= deadband {
        0_i32
    } else {
        error
    }
}

pub fn update_integral(prev_integral: i32, error: i32, min_value: i32, max_value: i32) -> i32 {
    clamp_policy_i32(prev_integral + error, min_value, max_value)
}

pub fn pi_output_bp(error: i32, integral: i32, kp_bp: u16, ki_bp: u16) -> i32 {
    let kp: i32 = kp_bp.into();
    let ki: i32 = ki_bp.into();
    let p_term = (error * kp) / CONTROLLER_SCALE;
    let i_term = (integral * ki) / CONTROLLER_SCALE;
    p_term + i_term
}

pub fn slew_limit_i32(current: i32, target: i32, max_delta: i32) -> i32 {
    assert(max_delta >= 0_i32, 'AR_SLEW');

    let delta = target - current;
    if delta > max_delta {
        return current + max_delta;
    }

    let lower_limit = 0_i32 - max_delta;
    if delta < lower_limit {
        return current - max_delta;
    }

    target
}
