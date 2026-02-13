use core::traits::TryInto;

const BP_DEN: u128 = 10_000_u128;
const U16_MAX_U128: u128 = 65_535_u128;
const U32_MAX_U128: u128 = 4_294_967_295_u128;

fn saturating_to_u16(value: u128) -> u16 {
    if value > U16_MAX_U128 {
        65_535_u16
    } else {
        value.try_into().unwrap()
    }
}

fn saturating_to_u32(value: u128) -> u32 {
    if value > U32_MAX_U128 {
        4_294_967_295_u32
    } else {
        value.try_into().unwrap()
    }
}

pub fn swarm_energy_surcharge(active_miners: u16, swarm_k: u16) -> u16 {
    if active_miners <= 1_u16 {
        return 0_u16;
    }

    let delta: u128 = (active_miners - 1_u16).into();
    let value = delta * delta * swarm_k.into();
    saturating_to_u16(value)
}

pub fn compute_tick_energy_cost(
    base_tick_energy: u16,
    ore_energy_weight: u16,
    depth_tier: u8,
    active_miners: u16,
    swarm_k: u16,
) -> u16 {
    let depth_weight: u16 = depth_tier.into();
    let surcharge = swarm_energy_surcharge(active_miners, swarm_k);
    let total: u128 = base_tick_energy.into() + ore_energy_weight.into() + depth_weight.into()
        + surcharge.into();
    saturating_to_u16(total)
}

pub fn compute_stress_delta(
    dt_blocks: u64,
    base_stress_per_block: u16,
    active_miners: u16,
    shift_elapsed_blocks: u64,
    safe_shift_blocks: u64,
    biome_risk_bp: u16,
    rarity_risk_bp: u16,
    overstay_k_bp: u16,
    density_k_bp: u16,
) -> u32 {
    if dt_blocks == 0_u64 || base_stress_per_block == 0_u16 {
        return 0_u32;
    }

    let n_minus_one = if active_miners > 1_u16 {
        active_miners - 1_u16
    } else {
        0_u16
    };
    let n_sq: u128 = n_minus_one.into() * n_minus_one.into();

    let density_factor_bp: u128 = BP_DEN + density_k_bp.into() * n_sq;

    let overstay_blocks = if shift_elapsed_blocks > safe_shift_blocks {
        shift_elapsed_blocks - safe_shift_blocks
    } else {
        0_u64
    };
    let overstay_factor_bp: u128 = BP_DEN + overstay_k_bp.into() * overstay_blocks.into();

    let numerator: u128 = dt_blocks.into()
        * base_stress_per_block.into()
        * density_factor_bp
        * overstay_factor_bp
        * biome_risk_bp.into()
        * rarity_risk_bp.into();

    let denom: u128 = BP_DEN * BP_DEN * BP_DEN * BP_DEN;
    let result = numerator / denom;
    saturating_to_u32(result)
}

pub fn compute_tick_yield(
    base_yield_per_block: u16,
    mine_stress: u32,
    collapse_threshold: u32,
    max_stress_penalty_bp: u16,
    dt_blocks: u64,
) -> u32 {
    if base_yield_per_block == 0_u16 || dt_blocks == 0_u64 || collapse_threshold == 0_u32 {
        return 0_u32;
    }

    let ratio_bp_u128: u128 = mine_stress.into() * BP_DEN / collapse_threshold.into();
    let ratio_bp = if ratio_bp_u128 > BP_DEN { BP_DEN } else { ratio_bp_u128 };
    let penalty_bp_u128: u128 = if ratio_bp > max_stress_penalty_bp.into() {
        max_stress_penalty_bp.into()
    } else {
        ratio_bp
    };

    let effective_per_block: u128 = base_yield_per_block.into() * (BP_DEN - penalty_bp_u128) / BP_DEN;
    let total = effective_per_block * dt_blocks.into();
    saturating_to_u32(total)
}

pub fn will_collapse(next_stress: u32, collapse_threshold: u32) -> bool {
    collapse_threshold > 0_u32 && next_stress >= collapse_threshold
}
