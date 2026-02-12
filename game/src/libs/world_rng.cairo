use core::traits::TryInto;

pub const DOMAIN_HEX_V1: felt252 = 'HEX_V1'_felt252;
pub const DOMAIN_AREA_V1: felt252 = 'AREA_V1'_felt252;
pub const DOMAIN_PLANT_V1: felt252 = 'PLANT_V1'_felt252;
pub const DOMAIN_GENE_V1: felt252 = 'GENE_V1'_felt252;

pub fn derive_with_domain(parent_seed: felt252, entropy: felt252, domain: felt252) -> felt252 {
    let (derived, _, _) = core::poseidon::hades_permutation(parent_seed, entropy, domain);
    derived
}

pub fn derive_hex_seed(global_seed: felt252, hex_coordinate: felt252) -> felt252 {
    derive_with_domain(global_seed, hex_coordinate, DOMAIN_HEX_V1)
}

pub fn derive_area_seed(hex_seed: felt252, area_index: u8) -> felt252 {
    let area_entropy: felt252 = area_index.into();
    derive_with_domain(hex_seed, area_entropy, DOMAIN_AREA_V1)
}

pub fn derive_plant_seed(area_seed: felt252, plant_id: u8) -> felt252 {
    let plant_entropy: felt252 = plant_id.into();
    derive_with_domain(area_seed, plant_entropy, DOMAIN_PLANT_V1)
}

pub fn derive_gene_seed(plant_seed: felt252, species: felt252) -> felt252 {
    derive_with_domain(plant_seed, species, DOMAIN_GENE_V1)
}

pub fn bounded_u32(seed: felt252, low: u32, high_exclusive: u32) -> Option<u32> {
    if high_exclusive <= low {
        return Option::None;
    }

    let span: u32 = high_exclusive - low;
    let seed_u256: u256 = seed.into();
    let span_u256: u256 = span.into();
    let span_u128: u128 = span.into();
    let low_u128: u128 = low.into();

    let rolled_u256: u256 = seed_u256 % span_u256;
    let mixed_u128 = rolled_u256.low ^ rolled_u256.high;
    let rolled_u128 = mixed_u128 % span_u128;
    let shifted_u128 = rolled_u128 + low_u128;
    shifted_u128.try_into()
}

pub fn derive_u32_in_range(
    parent_seed: felt252,
    entropy: felt252,
    domain: felt252,
    low: u32,
    high_exclusive: u32,
) -> Option<u32> {
    let seed = derive_with_domain(parent_seed, entropy, domain);
    bounded_u32(seed, low, high_exclusive)
}
