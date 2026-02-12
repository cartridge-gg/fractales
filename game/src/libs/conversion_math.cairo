use core::traits::TryInto;
use dojo_starter::models::economics::ConversionRate;

pub const MAX_VOLUME_PENALTY_BP: u16 = 5000_u16;
pub const VOLUME_UNITS_STEP: u32 = 10_u32;
pub const VOLUME_PENALTY_STEP_BP: u16 = 100_u16;

pub fn penalty_bp_for_units(units_converted_in_window: u32) -> u16 {
    let steps_u32 = units_converted_in_window / VOLUME_UNITS_STEP;
    let steps_u128: u128 = steps_u32.into();
    let penalty_u128: u128 = steps_u128 * VOLUME_PENALTY_STEP_BP.into();
    if penalty_u128 > MAX_VOLUME_PENALTY_BP.into() {
        MAX_VOLUME_PENALTY_BP
    } else {
        penalty_u128.try_into().unwrap()
    }
}

pub fn effective_rate_for_window(base_rate: u16, units_converted_in_window: u32) -> u16 {
    let penalty_bp = penalty_bp_for_units(units_converted_in_window);
    let kept_bp: u128 = 10000_u128 - penalty_bp.into();
    let rate_u128: u128 = base_rate.into();
    let effective_u128: u128 = (rate_u128 * kept_bp) / 10000_u128;
    if effective_u128 == 0_u128 && base_rate > 0_u16 {
        1_u16
    } else {
        effective_u128.try_into().unwrap()
    }
}

pub fn effective_rate(rate: ConversionRate, now_block: u64, window_blocks: u64) -> u16 {
    if window_blocks == 0_u64 {
        return rate.base_rate;
    }

    let in_window = if now_block >= rate.last_update_block {
        now_block - rate.last_update_block < window_blocks
    } else {
        true
    };

    if in_window {
        effective_rate_for_window(rate.current_rate, rate.units_converted_in_window)
    } else {
        rate.base_rate
    }
}

pub fn quote_energy(quantity: u16, rate_per_unit: u16) -> u16 {
    let qty_u128: u128 = quantity.into();
    let rate_u128: u128 = rate_per_unit.into();
    let energy_u128: u128 = qty_u128 * rate_u128;
    if energy_u128 > 65535_u128 {
        65535_u16
    } else {
        energy_u128.try_into().unwrap()
    }
}
