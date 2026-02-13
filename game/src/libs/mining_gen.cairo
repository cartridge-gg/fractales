use core::traits::TryInto;
use dojo_starter::libs::mining_rng::{DOMAIN_MINE_V1, derive_mine_seed, derive_ore_seed, derive_strata_seed};
use dojo_starter::libs::world_gen::default_world_gen_config;
use dojo_starter::libs::world_noise::noise_percentile_roll;
use dojo_starter::models::world::Biome;

const ENTROPY_MINE_SLOT_ROLL: felt252 = 'MINE_SLOT_ROLL_V1'_felt252;
const ENTROPY_RARITY_ROLL: felt252 = 'MINE_RARITY_ROLLV1'_felt252;
const ENTROPY_DEPTH_ROLL: felt252 = 'MINE_DEPTH_ROLLV1'_felt252;
const ENTROPY_RICHNESS_ROLL: felt252 = 'MINE_RICH_ROLL_V1'_felt252;
const ENTROPY_RESERVE_ROLL: felt252 = 'MINE_RESV_ROLL_V1'_felt252;
const ENTROPY_COLLAPSE_ROLL: felt252 = 'MINE_COLL_ROLL_V1'_felt252;
const ENTROPY_SAFE_ROLL: felt252 = 'MINE_SAFE_ROLL_V1'_felt252;

const ORE_IRON: felt252 = 'ORE_IRON'_felt252;
const ORE_COPPER: felt252 = 'ORE_COPPER'_felt252;
const ORE_TIN: felt252 = 'ORE_TIN'_felt252;
const ORE_COAL: felt252 = 'ORE_COAL'_felt252;
const ORE_SILVER: felt252 = 'ORE_SILVER'_felt252;
const ORE_NICKEL: felt252 = 'ORE_NICKEL'_felt252;
const ORE_COBALT: felt252 = 'ORE_COBALT'_felt252;
const ORE_GOLD: felt252 = 'ORE_GOLD'_felt252;
const ORE_TITAN: felt252 = 'ORE_TITAN'_felt252;
const ORE_URAN: felt252 = 'ORE_URAN'_felt252;
const ORE_MITH: felt252 = 'ORE_MITH'_felt252;
const ORE_ADAM: felt252 = 'ORE_ADAM'_felt252;
const ORE_AETHER: felt252 = 'ORE_AETHER'_felt252;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct MineProfile {
    pub ore_id: felt252,
    pub rarity_tier: u8,
    pub depth_tier: u8,
    pub richness_bp: u16,
    pub remaining_reserve: u32,
    pub base_stress_per_block: u16,
    pub collapse_threshold: u32,
    pub safe_shift_blocks: u64,
    pub biome_risk_bp: u16,
    pub rarity_risk_bp: u16,
    pub ore_energy_weight: u16,
    pub conversion_energy_per_unit: u16,
}

pub fn derive_area_mine_slot_count(hex_coordinate: felt252, area_id: felt252, biome: Biome) -> u8 {
    let cfg = default_world_gen_config();
    let mine_seed = derive_mine_seed(cfg.global_seed, hex_coordinate, area_id);
    let roll = noise_percentile_roll(mine_seed, ENTROPY_MINE_SLOT_ROLL, cfg.area_scale_bp, cfg.area_octaves);
    // Locked bounds: 1..=8
    let biome_bias = biome_slot_bias(biome);
    let base = 1_u32 + (roll * 8_u32) / 101_u32;
    let biased = if biome_bias > 0_i16 {
        let add: u32 = biome_bias.try_into().unwrap();
        if base + add > 8_u32 { 8_u32 } else { base + add }
    } else if biome_bias < 0_i16 {
        let sub: u32 = (-biome_bias).try_into().unwrap();
        if base > 1_u32 + sub { base - sub } else { 1_u32 }
    } else {
        base
    };
    biased.try_into().unwrap()
}

pub fn derive_mine_profile(
    hex_coordinate: felt252,
    area_id: felt252,
    mine_id: u8,
    biome: Biome,
) -> MineProfile {
    let cfg = default_world_gen_config();
    let mine_seed_root = derive_mine_seed(cfg.global_seed, hex_coordinate, area_id);
    let (mine_seed, _, _) = core::poseidon::hades_permutation(
        mine_seed_root, mine_id.into(), DOMAIN_MINE_V1,
    );

    let rarity_roll = noise_percentile_roll(mine_seed, ENTROPY_RARITY_ROLL, cfg.area_scale_bp, cfg.area_octaves);
    let rarity_tier = rarity_tier_from_roll(rarity_roll);

    let depth_roll = noise_percentile_roll(mine_seed, ENTROPY_DEPTH_ROLL, cfg.area_scale_bp, cfg.area_octaves);
    let depth_tier = depth_tier_from_roll(depth_roll);

    let strata_seed = derive_strata_seed(mine_seed, depth_tier);
    let ore_seed = derive_ore_seed(strata_seed, mine_id);
    let ore_pick_roll = noise_percentile_roll(ore_seed, ENTROPY_RESERVE_ROLL, cfg.plant_scale_bp, cfg.plant_octaves);
    let ore_id = ore_id_from_tier_roll(rarity_tier, ore_pick_roll);

    let richness_roll = noise_percentile_roll(mine_seed, ENTROPY_RICHNESS_ROLL, cfg.plant_scale_bp, cfg.plant_octaves);
    let reserve_roll = noise_percentile_roll(mine_seed, ENTROPY_RESERVE_ROLL, cfg.plant_scale_bp, cfg.plant_octaves);
    let collapse_roll = noise_percentile_roll(mine_seed, ENTROPY_COLLAPSE_ROLL, cfg.plant_scale_bp, cfg.plant_octaves);
    let safe_roll = noise_percentile_roll(mine_seed, ENTROPY_SAFE_ROLL, cfg.plant_scale_bp, cfg.plant_octaves);

    let richness_bp = (7_000_u32 + (richness_roll * 9_000_u32) / 100_u32).try_into().unwrap();
    let remaining_reserve = reserve_from_roll(rarity_tier, reserve_roll);
    let base_stress_per_block = base_stress_for_tier(rarity_tier, biome);
    let collapse_threshold = collapse_threshold_from_roll(rarity_tier, collapse_roll);
    let safe_shift_blocks = safe_shift_from_roll(rarity_tier, safe_roll);

    MineProfile {
        ore_id,
        rarity_tier,
        depth_tier,
        richness_bp,
        remaining_reserve,
        base_stress_per_block,
        collapse_threshold,
        safe_shift_blocks,
        biome_risk_bp: biome_risk_bp(biome),
        rarity_risk_bp: rarity_risk_bp(rarity_tier),
        ore_energy_weight: ore_energy_weight(ore_id),
        conversion_energy_per_unit: ore_conversion_energy(ore_id),
    }
}

fn biome_slot_bias(biome: Biome) -> i16 {
    match biome {
        Biome::Mountain => 1_i16,
        Biome::Volcanic => 2_i16,
        Biome::Highlands => 1_i16,
        Biome::Glacier => -1_i16,
        _ => 0_i16,
    }
}

fn rarity_tier_from_roll(roll: u32) -> u8 {
    if roll < 40_u32 {
        0_u8
    } else if roll < 70_u32 {
        1_u8
    } else if roll < 90_u32 {
        2_u8
    } else if roll < 98_u32 {
        3_u8
    } else {
        4_u8
    }
}

fn depth_tier_from_roll(roll: u32) -> u8 {
    if roll < 20_u32 {
        1_u8
    } else if roll < 40_u32 {
        2_u8
    } else if roll < 65_u32 {
        3_u8
    } else if roll < 85_u32 {
        4_u8
    } else {
        5_u8
    }
}

fn ore_id_from_tier_roll(tier: u8, roll: u32) -> felt252 {
    match tier {
        0_u8 => {
            if roll < 25_u32 {
                ORE_IRON
            } else if roll < 50_u32 {
                ORE_COPPER
            } else if roll < 75_u32 {
                ORE_TIN
            } else {
                ORE_COAL
            }
        },
        1_u8 => {
            if roll < 34_u32 {
                ORE_SILVER
            } else if roll < 67_u32 {
                ORE_NICKEL
            } else {
                ORE_COBALT
            }
        },
        2_u8 => {
            if roll < 34_u32 {
                ORE_GOLD
            } else if roll < 67_u32 {
                ORE_TITAN
            } else {
                ORE_URAN
            }
        },
        3_u8 => {
            if roll < 50_u32 {
                ORE_MITH
            } else {
                ORE_ADAM
            }
        },
        _ => ORE_AETHER,
    }
}

fn reserve_from_roll(tier: u8, roll: u32) -> u32 {
    match tier {
        0_u8 => 1_400_u32 + (roll * 1_000_u32) / 100_u32,
        1_u8 => 1_000_u32 + (roll * 800_u32) / 100_u32,
        2_u8 => 700_u32 + (roll * 600_u32) / 100_u32,
        3_u8 => 450_u32 + (roll * 450_u32) / 100_u32,
        _ => 250_u32 + (roll * 350_u32) / 100_u32,
    }
}

fn base_stress_for_tier(tier: u8, biome: Biome) -> u16 {
    let biome_extra: u16 = match biome {
        Biome::Volcanic => 8_u16,
        Biome::Glacier => 5_u16,
        Biome::Mountain => 4_u16,
        Biome::Highlands => 3_u16,
        _ => 0_u16,
    };

    let tier_base = 8_u16 + tier.into() * 4_u16;
    tier_base + biome_extra
}

fn collapse_threshold_from_roll(tier: u8, roll: u32) -> u32 {
    match tier {
        0_u8 => 9_000_u32 + (roll * 3_000_u32) / 100_u32,
        1_u8 => 7_000_u32 + (roll * 2_500_u32) / 100_u32,
        2_u8 => 5_000_u32 + (roll * 2_000_u32) / 100_u32,
        3_u8 => 3_500_u32 + (roll * 1_500_u32) / 100_u32,
        _ => 2_500_u32 + (roll * 1_000_u32) / 100_u32,
    }
}

fn safe_shift_from_roll(tier: u8, roll: u32) -> u64 {
    let base: u64 = match tier {
        0_u8 => 16_u64,
        1_u8 => 13_u64,
        2_u8 => 10_u64,
        3_u8 => 7_u64,
        _ => 5_u64,
    };
    let delta = (roll * 6_u32) / 100_u32;
    let shifted: u64 = delta.into();
    if shifted + base < 4_u64 {
        4_u64
    } else {
        shifted + base
    }
}

fn biome_risk_bp(biome: Biome) -> u16 {
    match biome {
        Biome::Volcanic => 14_000_u16,
        Biome::Glacier => 13_000_u16,
        Biome::Mountain => 12_500_u16,
        Biome::Highlands => 11_500_u16,
        Biome::Canyon => 11_500_u16,
        Biome::Badlands => 11_250_u16,
        _ => 10_000_u16,
    }
}

fn rarity_risk_bp(tier: u8) -> u16 {
    match tier {
        0_u8 => 10_000_u16,
        1_u8 => 11_250_u16,
        2_u8 => 13_000_u16,
        3_u8 => 15_000_u16,
        _ => 17_500_u16,
    }
}

fn ore_energy_weight(ore_id: felt252) -> u16 {
    if ore_id == ORE_IRON || ore_id == ORE_COPPER || ore_id == ORE_TIN {
        1_u16
    } else if ore_id == ORE_COAL || ore_id == ORE_SILVER || ore_id == ORE_NICKEL {
        2_u16
    } else if ore_id == ORE_COBALT || ore_id == ORE_GOLD {
        3_u16
    } else if ore_id == ORE_TITAN {
        4_u16
    } else if ore_id == ORE_URAN || ore_id == ORE_MITH {
        5_u16
    } else if ore_id == ORE_ADAM {
        6_u16
    } else {
        8_u16
    }
}

fn ore_conversion_energy(ore_id: felt252) -> u16 {
    if ore_id == ORE_IRON {
        8_u16
    } else if ore_id == ORE_COPPER {
        9_u16
    } else if ore_id == ORE_TIN {
        10_u16
    } else if ore_id == ORE_COAL {
        12_u16
    } else if ore_id == ORE_SILVER {
        16_u16
    } else if ore_id == ORE_NICKEL {
        18_u16
    } else if ore_id == ORE_COBALT {
        22_u16
    } else if ore_id == ORE_GOLD {
        30_u16
    } else if ore_id == ORE_TITAN {
        36_u16
    } else if ore_id == ORE_URAN {
        45_u16
    } else if ore_id == ORE_MITH {
        62_u16
    } else if ore_id == ORE_ADAM {
        78_u16
    } else {
        120_u16
    }
}
