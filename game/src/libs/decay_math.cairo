use core::traits::TryInto;
use dojo_starter::models::world::Biome;

pub fn upkeep_for_biome(biome: Biome) -> u32 {
    match biome {
        Biome::Plains => 25_u32,
        Biome::Forest => 35_u32,
        Biome::Mountain => 45_u32,
        Biome::Desert => 55_u32,
        Biome::Swamp => 65_u32,
        Biome::Unknown => 35_u32,
    }
}

pub fn maintenance_decay_recovery(energy_paid: u16, upkeep_per_period: u32, recovery_bp: u16) -> u16 {
    if upkeep_per_period == 0_u32 || energy_paid == 0_u16 {
        return 0_u16;
    }

    let paid_u128: u128 = energy_paid.into();
    let upkeep_u128: u128 = upkeep_per_period.into();
    let covered_periods_u128: u128 = paid_u128 / upkeep_u128;
    let recovery_per_period = if recovery_bp >= 5_u16 { recovery_bp / 5_u16 } else { 1_u16 };
    let recovery_u128: u128 = covered_periods_u128 * recovery_per_period.into();

    if recovery_u128 > 100_u128 {
        100_u16
    } else {
        recovery_u128.try_into().unwrap()
    }
}

pub fn min_claim_energy(upkeep_per_period: u32, decay_level: u16, claimable_threshold: u16) -> u16 {
    let base_u128: u128 = upkeep_per_period.into() * 2_u128;
    let extra_decay = if decay_level > claimable_threshold {
        decay_level - claimable_threshold
    } else {
        0_u16
    };
    let penalty_u128: u128 = extra_decay.into() * 5_u128;
    let total_u128 = base_u128 + penalty_u128;

    if total_u128 == 0_u128 {
        1_u16
    } else if total_u128 > 65535_u128 {
        65535_u16
    } else {
        total_u128.try_into().unwrap()
    }
}
