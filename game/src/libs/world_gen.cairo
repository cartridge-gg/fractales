use core::traits::TryInto;
use dojo_starter::libs::biome_profiles::{
    mine_field_threshold_for_biome, plant_field_threshold_for_biome, species_for_biome_roll,
    weighted_biome_from_roll,
};
use dojo_starter::libs::world_noise::{
    noise_percentile_roll, sanitize_octaves, sanitize_scale_bp,
};
use dojo_starter::libs::world_rng::{
    DOMAIN_AREA_V1, derive_gene_seed, derive_hex_seed, derive_plant_seed, derive_with_domain,
};
use dojo_starter::models::world::{AreaType, Biome, SizeCategory, WorldGenConfig};

const DEFAULT_GENERATION_VERSION: u16 = 2_u16;
const WORLD_GLOBAL_SEED_V1: felt252 = 'WORLD_GEN_SEED_V1'_felt252;
const DEFAULT_BIOME_SCALE_BP: u16 = 2_200_u16;
const DEFAULT_AREA_SCALE_BP: u16 = 2_800_u16;
const DEFAULT_PLANT_SCALE_BP: u16 = 3_200_u16;
const DEFAULT_BIOME_OCTAVES: u8 = 3_u8;
const DEFAULT_AREA_OCTAVES: u8 = 4_u8;
const DEFAULT_PLANT_OCTAVES: u8 = 5_u8;

const ENTROPY_HEX_BIOME_ROLL: felt252 = 'HEX_BIOME_ROLL_V1'_felt252;
const ENTROPY_HEX_AREA_COUNT_ROLL: felt252 = 'HEX_AREA_COUNT_ROL'_felt252;
const ENTROPY_AREA_TYPE_ROLL: felt252 = 'AREA_TYPE_ROLL_V1'_felt252;
const ENTROPY_AREA_QUALITY_ROLL: felt252 = 'AREA_QUALITY_ROLL'_felt252;
const ENTROPY_AREA_SIZE_ROLL: felt252 = 'AREA_SIZE_ROLL_V1'_felt252;
const ENTROPY_AREA_PLANT_SLOT_ROLL: felt252 = 'AREA_PLANT_SLOT_RL'_felt252;
const ENTROPY_PLANT_SPECIES_ROLL: felt252 = 'PLANT_SPECIES_ROL'_felt252;
const ENTROPY_PLANT_MAX_YIELD_ROLL: felt252 = 'PLANT_MAX_YIELDR'_felt252;
const ENTROPY_PLANT_REGROWTH_ROLL: felt252 = 'PLANT_REGROWTH_RL'_felt252;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct HexProfile {
    pub biome: Biome,
    pub area_count: u8,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct AreaProfile {
    pub area_type: AreaType,
    pub resource_quality: u16,
    pub size_category: SizeCategory,
    pub plant_slot_count: u8,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct PlantProfile {
    pub species: felt252,
    pub max_yield: u16,
    pub regrowth_rate: u16,
    pub genetics_hash: felt252,
}

pub fn default_world_gen_config() -> WorldGenConfig {
    WorldGenConfig {
        generation_version: DEFAULT_GENERATION_VERSION,
        global_seed: WORLD_GLOBAL_SEED_V1,
        biome_scale_bp: DEFAULT_BIOME_SCALE_BP,
        area_scale_bp: DEFAULT_AREA_SCALE_BP,
        plant_scale_bp: DEFAULT_PLANT_SCALE_BP,
        biome_octaves: DEFAULT_BIOME_OCTAVES,
        area_octaves: DEFAULT_AREA_OCTAVES,
        plant_octaves: DEFAULT_PLANT_OCTAVES,
    }
}

pub fn normalize_world_gen_config(config: WorldGenConfig) -> WorldGenConfig {
    let defaults = default_world_gen_config();
    let generation_version = if config.generation_version == 0_u16 {
        defaults.generation_version
    } else {
        config.generation_version
    };
    let global_seed = if config.global_seed == 0_felt252 {
        defaults.global_seed
    } else {
        config.global_seed
    };

    WorldGenConfig {
        generation_version,
        global_seed,
        biome_scale_bp: sanitize_scale_bp(config.biome_scale_bp, defaults.biome_scale_bp),
        area_scale_bp: sanitize_scale_bp(config.area_scale_bp, defaults.area_scale_bp),
        plant_scale_bp: sanitize_scale_bp(config.plant_scale_bp, defaults.plant_scale_bp),
        biome_octaves: sanitize_octaves(config.biome_octaves, defaults.biome_octaves),
        area_octaves: sanitize_octaves(config.area_octaves, defaults.area_octaves),
        plant_octaves: sanitize_octaves(config.plant_octaves, defaults.plant_octaves),
    }
}

pub fn derive_hex_profile(hex_coordinate: felt252) -> HexProfile {
    derive_hex_profile_with_config(hex_coordinate, default_world_gen_config())
}

pub fn derive_hex_profile_with_config(
    hex_coordinate: felt252, config: WorldGenConfig,
) -> HexProfile {
    let cfg = normalize_world_gen_config(config);
    let hex_seed = derive_hex_seed(cfg.global_seed, hex_coordinate);

    let biome_roll = noise_percentile_roll(
        hex_seed, ENTROPY_HEX_BIOME_ROLL, cfg.biome_scale_bp, cfg.biome_octaves,
    );
    let area_count_roll = noise_percentile_roll(
        hex_seed, ENTROPY_HEX_AREA_COUNT_ROLL, cfg.area_scale_bp, cfg.area_octaves,
    );

    HexProfile {
        biome: biome_from_roll(biome_roll),
        area_count: area_count_from_roll(area_count_roll),
    }
}

pub fn derive_area_profile(hex_coordinate: felt252, area_index: u8, biome: Biome) -> AreaProfile {
    derive_area_profile_with_config(
        hex_coordinate, area_index, biome, default_world_gen_config(),
    )
}

pub fn derive_area_profile_with_config(
    hex_coordinate: felt252, area_index: u8, biome: Biome, config: WorldGenConfig,
) -> AreaProfile {
    let cfg = normalize_world_gen_config(config);
    let hex_seed = derive_hex_seed(cfg.global_seed, hex_coordinate);
    let area_seed = derive_with_domain(hex_seed, area_index.into(), DOMAIN_AREA_V1);

    let area_type = if area_index == 0_u8 {
        AreaType::Control
    } else {
        let area_type_roll = noise_percentile_roll(
            area_seed, ENTROPY_AREA_TYPE_ROLL, cfg.area_scale_bp, cfg.area_octaves,
        );
        area_type_from_roll(biome, area_type_roll)
    };

    let quality_roll = noise_percentile_roll(
        area_seed, ENTROPY_AREA_QUALITY_ROLL, cfg.area_scale_bp, cfg.area_octaves,
    );
    let size_roll = noise_percentile_roll(
        area_seed, ENTROPY_AREA_SIZE_ROLL, cfg.area_scale_bp, cfg.area_octaves,
    );
    let plant_slot_roll = noise_percentile_roll(
        area_seed, ENTROPY_AREA_PLANT_SLOT_ROLL, cfg.area_scale_bp, cfg.area_octaves,
    );

    AreaProfile {
        area_type,
        resource_quality: quality_from_roll(quality_roll),
        size_category: size_from_roll(size_roll),
        plant_slot_count: plant_slot_count_from_roll(plant_slot_roll),
    }
}

pub fn derive_plant_profile(
    hex_coordinate: felt252, area_id: felt252, plant_id: u8, biome: Biome,
) -> PlantProfile {
    derive_plant_profile_with_config(
        hex_coordinate, area_id, plant_id, biome, default_world_gen_config(),
    )
}

pub fn derive_plant_profile_with_config(
    hex_coordinate: felt252,
    area_id: felt252,
    plant_id: u8,
    biome: Biome,
    config: WorldGenConfig,
) -> PlantProfile {
    let cfg = normalize_world_gen_config(config);
    let hex_seed = derive_hex_seed(cfg.global_seed, hex_coordinate);
    let area_seed = derive_with_domain(hex_seed, area_id, DOMAIN_AREA_V1);
    let plant_seed = derive_plant_seed(area_seed, plant_id);

    let species_roll = noise_percentile_roll(
        plant_seed, ENTROPY_PLANT_SPECIES_ROLL, cfg.plant_scale_bp, cfg.plant_octaves,
    );
    let max_yield_roll = noise_percentile_roll(
        plant_seed, ENTROPY_PLANT_MAX_YIELD_ROLL, cfg.plant_scale_bp, cfg.plant_octaves,
    );
    let regrowth_roll = noise_percentile_roll(
        plant_seed, ENTROPY_PLANT_REGROWTH_ROLL, cfg.plant_scale_bp, cfg.plant_octaves,
    );

    let species = species_from_roll(biome, species_roll);
    PlantProfile {
        species,
        max_yield: max_yield_from_roll(max_yield_roll).try_into().unwrap(),
        regrowth_rate: regrowth_from_roll(regrowth_roll).try_into().unwrap(),
        genetics_hash: derive_gene_seed(plant_seed, species),
    }
}

fn biome_from_roll(roll: u32) -> Biome {
    weighted_biome_from_roll(roll)
}

fn area_count_from_roll(roll: u32) -> u8 {
    if roll < 25_u32 {
        3_u8
    } else if roll < 50_u32 {
        4_u8
    } else if roll < 75_u32 {
        5_u8
    } else {
        6_u8
    }
}

fn area_type_from_roll(biome: Biome, roll: u32) -> AreaType {
    let plant_threshold = plant_field_threshold_for_biome(biome);
    let mine_threshold = mine_field_threshold_for_biome(biome);

    if roll < plant_threshold {
        AreaType::PlantField
    } else if roll >= mine_threshold {
        AreaType::MineField
    } else {
        AreaType::Wilderness
    }
}

fn quality_from_roll(roll: u32) -> u16 {
    let quality = 30_u32 + (roll * 70_u32) / 100_u32;
    quality.try_into().unwrap()
}

fn size_from_roll(roll: u32) -> SizeCategory {
    if roll < 30_u32 {
        SizeCategory::Small
    } else if roll < 75_u32 {
        SizeCategory::Medium
    } else {
        SizeCategory::Large
    }
}

fn max_yield_from_roll(roll: u32) -> u32 {
    35_u32 + (roll * 45_u32) / 100_u32
}

fn regrowth_from_roll(roll: u32) -> u32 {
    1_u32 + (roll * 3_u32) / 100_u32
}

fn plant_slot_count_from_roll(roll: u32) -> u8 {
    if roll < 25_u32 {
        5_u8
    } else if roll < 50_u32 {
        6_u8
    } else if roll < 75_u32 {
        7_u8
    } else {
        8_u8
    }
}

fn species_from_roll(biome: Biome, roll: u32) -> felt252 {
    species_for_biome_roll(biome, roll)
}
