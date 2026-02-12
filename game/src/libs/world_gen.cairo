use core::traits::TryInto;
use dojo_starter::libs::world_rng::{
    DOMAIN_AREA_V1, DOMAIN_HEX_V1, DOMAIN_PLANT_V1, derive_area_seed, derive_gene_seed,
    derive_hex_seed, derive_plant_seed, derive_u32_in_range, derive_with_domain,
};
use dojo_starter::models::world::{AreaType, Biome, SizeCategory};

const WORLD_GLOBAL_SEED_V1: felt252 = 'WORLD_GEN_SEED_V1'_felt252;

const ENTROPY_HEX_BIOME_ROLL: felt252 = 'HEX_BIOME_ROLL_V1'_felt252;
const ENTROPY_HEX_AREA_COUNT_ROLL: felt252 = 'HEX_AREA_COUNT_ROL'_felt252;
const ENTROPY_AREA_TYPE_ROLL: felt252 = 'AREA_TYPE_ROLL_V1'_felt252;
const ENTROPY_AREA_QUALITY_ROLL: felt252 = 'AREA_QUALITY_ROLL'_felt252;
const ENTROPY_AREA_SIZE_ROLL: felt252 = 'AREA_SIZE_ROLL_V1'_felt252;
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
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct PlantProfile {
    pub species: felt252,
    pub max_yield: u16,
    pub regrowth_rate: u16,
    pub genetics_hash: felt252,
}

pub fn derive_hex_profile(hex_coordinate: felt252) -> HexProfile {
    let hex_seed = derive_hex_seed(WORLD_GLOBAL_SEED_V1, hex_coordinate);

    let biome_roll = match derive_u32_in_range(
        hex_seed, ENTROPY_HEX_BIOME_ROLL, DOMAIN_HEX_V1, 0_u32, 100_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 0_u32,
    };

    let area_count_u32 = match derive_u32_in_range(
        hex_seed, ENTROPY_HEX_AREA_COUNT_ROLL, DOMAIN_HEX_V1, 3_u32, 7_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 3_u32,
    };

    HexProfile {
        biome: biome_from_roll(biome_roll),
        area_count: area_count_u32.try_into().unwrap(),
    }
}

pub fn derive_area_profile(hex_coordinate: felt252, area_index: u8, biome: Biome) -> AreaProfile {
    let hex_seed = derive_hex_seed(WORLD_GLOBAL_SEED_V1, hex_coordinate);
    let area_seed = derive_area_seed(hex_seed, area_index);

    let area_type = if area_index == 0_u8 {
        AreaType::Control
    } else {
        let area_type_roll = match derive_u32_in_range(
            area_seed, ENTROPY_AREA_TYPE_ROLL, DOMAIN_AREA_V1, 0_u32, 100_u32,
        ) {
            Option::Some(value) => value,
            Option::None => 0_u32,
        };
        area_type_from_roll(biome, area_type_roll)
    };

    let quality_u32 = match derive_u32_in_range(
        area_seed, ENTROPY_AREA_QUALITY_ROLL, DOMAIN_AREA_V1, 30_u32, 101_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 30_u32,
    };
    let size_roll = match derive_u32_in_range(
        area_seed, ENTROPY_AREA_SIZE_ROLL, DOMAIN_AREA_V1, 0_u32, 100_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 0_u32,
    };

    AreaProfile {
        area_type,
        resource_quality: quality_u32.try_into().unwrap(),
        size_category: size_from_roll(size_roll),
    }
}

pub fn derive_plant_profile(
    hex_coordinate: felt252, area_id: felt252, plant_id: u8, biome: Biome,
) -> PlantProfile {
    let hex_seed = derive_hex_seed(WORLD_GLOBAL_SEED_V1, hex_coordinate);
    let area_seed = derive_with_domain(hex_seed, area_id, DOMAIN_AREA_V1);
    let plant_seed = derive_plant_seed(area_seed, plant_id);

    let species_roll = match derive_u32_in_range(
        plant_seed, ENTROPY_PLANT_SPECIES_ROLL, DOMAIN_PLANT_V1, 0_u32, 100_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 0_u32,
    };
    let max_yield_u32 = match derive_u32_in_range(
        plant_seed, ENTROPY_PLANT_MAX_YIELD_ROLL, DOMAIN_PLANT_V1, 35_u32, 81_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 35_u32,
    };
    let regrowth_u32 = match derive_u32_in_range(
        plant_seed, ENTROPY_PLANT_REGROWTH_ROLL, DOMAIN_PLANT_V1, 1_u32, 5_u32,
    ) {
        Option::Some(value) => value,
        Option::None => 1_u32,
    };

    let species = species_from_roll(biome, species_roll);
    PlantProfile {
        species,
        max_yield: max_yield_u32.try_into().unwrap(),
        regrowth_rate: regrowth_u32.try_into().unwrap(),
        genetics_hash: derive_gene_seed(plant_seed, species),
    }
}

fn biome_from_roll(roll: u32) -> Biome {
    if roll < 20_u32 {
        Biome::Plains
    } else if roll < 40_u32 {
        Biome::Forest
    } else if roll < 60_u32 {
        Biome::Mountain
    } else if roll < 80_u32 {
        Biome::Desert
    } else {
        Biome::Swamp
    }
}

fn area_type_from_roll(biome: Biome, roll: u32) -> AreaType {
    let plant_threshold = match biome {
        Biome::Plains => 60_u32,
        Biome::Forest => 70_u32,
        Biome::Mountain => 25_u32,
        Biome::Desert => 30_u32,
        Biome::Swamp => 55_u32,
        Biome::Unknown => 45_u32,
    };

    if roll < plant_threshold {
        AreaType::PlantField
    } else {
        AreaType::Wilderness
    }
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

fn species_from_roll(biome: Biome, roll: u32) -> felt252 {
    match biome {
        Biome::Plains => {
            if roll < 65_u32 { 'GRAIN'_felt252 } else { 'CLOVR'_felt252 }
        },
        Biome::Forest => {
            if roll < 65_u32 { 'HERB'_felt252 } else { 'MUSHR'_felt252 }
        },
        Biome::Mountain => {
            if roll < 65_u32 { 'MOSS'_felt252 } else { 'LICHN'_felt252 }
        },
        Biome::Desert => {
            if roll < 65_u32 { 'CACTS'_felt252 } else { 'AGAVE'_felt252 }
        },
        Biome::Swamp => {
            if roll < 65_u32 { 'REED'_felt252 } else { 'LOTUS'_felt252 }
        },
        Biome::Unknown => {
            if roll < 65_u32 { 'FERN'_felt252 } else { 'BRIAR'_felt252 }
        },
    }
}
