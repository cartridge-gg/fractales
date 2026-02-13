use dojo_starter::models::world::Biome;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct BiomeProfile {
    pub upkeep_per_period: u32,
    pub plant_field_threshold: u32,
    pub primary_species: felt252,
    pub secondary_species: felt252,
}

fn profile(
    upkeep_per_period: u32,
    plant_field_threshold: u32,
    primary_species: felt252,
    secondary_species: felt252,
) -> BiomeProfile {
    BiomeProfile {
        upkeep_per_period,
        plant_field_threshold,
        primary_species,
        secondary_species,
    }
}

pub fn profile_for_biome(biome: Biome) -> BiomeProfile {
    match biome {
        Biome::Plains => profile(25_u32, 60_u32, 'GRAIN'_felt252, 'CLOVR'_felt252),
        Biome::Forest => profile(35_u32, 70_u32, 'HERB'_felt252, 'MUSHR'_felt252),
        Biome::Mountain => profile(45_u32, 25_u32, 'MOSS'_felt252, 'LICHN'_felt252),
        Biome::Desert => profile(55_u32, 30_u32, 'CACTS'_felt252, 'AGAVE'_felt252),
        Biome::Swamp => profile(65_u32, 55_u32, 'REED'_felt252, 'LOTUS'_felt252),
        Biome::Tundra => profile(70_u32, 20_u32, 'LCHEN'_felt252, 'SNWRT'_felt252),
        Biome::Taiga => profile(50_u32, 58_u32, 'PINEC'_felt252, 'BRYER'_felt252),
        Biome::Jungle => profile(75_u32, 72_u32, 'VINES'_felt252, 'ORCHD'_felt252),
        Biome::Savanna => profile(40_u32, 50_u32, 'ACACI'_felt252, 'SORGM'_felt252),
        Biome::Grassland => profile(30_u32, 62_u32, 'PRAIR'_felt252, 'THYME'_felt252),
        Biome::Canyon => profile(60_u32, 24_u32, 'SAGEB'_felt252, 'YUCCA'_felt252),
        Biome::Badlands => profile(68_u32, 28_u32, 'SHRUB'_felt252, 'RESIN'_felt252),
        Biome::Volcanic => profile(90_u32, 18_u32, 'ASHFR'_felt252, 'EMBER'_felt252),
        Biome::Glacier => profile(85_u32, 15_u32, 'ICEFN'_felt252, 'SNOWL'_felt252),
        Biome::Wetlands => profile(62_u32, 64_u32, 'BULRU'_felt252, 'SEDGE'_felt252),
        Biome::Steppe => profile(38_u32, 52_u32, 'RYEGR'_felt252, 'FLAXS'_felt252),
        Biome::Oasis => profile(58_u32, 68_u32, 'DATEP'_felt252, 'MINTS'_felt252),
        Biome::Mire => profile(72_u32, 57_u32, 'PEATM'_felt252, 'HEMPL'_felt252),
        Biome::Highlands => profile(52_u32, 40_u32, 'HEATH'_felt252, 'JUNPR'_felt252),
        Biome::Coast => profile(48_u32, 48_u32, 'KELP'_felt252, 'SEAGR'_felt252),
        Biome::Unknown => profile(35_u32, 45_u32, 'FERN'_felt252, 'BRIAR'_felt252),
    }
}

pub fn weighted_biome_from_roll(roll: u32) -> Biome {
    if roll < 5_u32 {
        Biome::Plains
    } else if roll < 10_u32 {
        Biome::Forest
    } else if roll < 15_u32 {
        Biome::Mountain
    } else if roll < 20_u32 {
        Biome::Desert
    } else if roll < 25_u32 {
        Biome::Swamp
    } else if roll < 30_u32 {
        Biome::Tundra
    } else if roll < 35_u32 {
        Biome::Taiga
    } else if roll < 40_u32 {
        Biome::Jungle
    } else if roll < 45_u32 {
        Biome::Savanna
    } else if roll < 50_u32 {
        Biome::Grassland
    } else if roll < 55_u32 {
        Biome::Canyon
    } else if roll < 60_u32 {
        Biome::Badlands
    } else if roll < 65_u32 {
        Biome::Volcanic
    } else if roll < 70_u32 {
        Biome::Glacier
    } else if roll < 75_u32 {
        Biome::Wetlands
    } else if roll < 80_u32 {
        Biome::Steppe
    } else if roll < 85_u32 {
        Biome::Oasis
    } else if roll < 90_u32 {
        Biome::Mire
    } else if roll < 95_u32 {
        Biome::Highlands
    } else {
        Biome::Coast
    }
}

pub fn upkeep_for_biome_profile(biome: Biome) -> u32 {
    profile_for_biome(biome).upkeep_per_period
}

pub fn plant_field_threshold_for_biome(biome: Biome) -> u32 {
    profile_for_biome(biome).plant_field_threshold
}

pub fn mine_field_threshold_for_biome(biome: Biome) -> u32 {
    match biome {
        Biome::Mountain => 58_u32,
        Biome::Desert => 60_u32,
        Biome::Canyon => 58_u32,
        Biome::Badlands => 58_u32,
        Biome::Volcanic => 55_u32,
        Biome::Glacier => 62_u32,
        Biome::Highlands => 60_u32,
        _ => 68_u32,
    }
}

pub fn species_for_biome_roll(biome: Biome, roll: u32) -> felt252 {
    let profile = profile_for_biome(biome);
    if roll < 65_u32 { profile.primary_species } else { profile.secondary_species }
}
