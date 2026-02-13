pub const DOMAIN_MINE_V1: felt252 = 'MINE_V1'_felt252;
pub const DOMAIN_STRATA_V1: felt252 = 'STRATA_V1'_felt252;
pub const DOMAIN_ORE_V1: felt252 = 'ORE_V1'_felt252;
pub const DOMAIN_COLLAPSE_V1: felt252 = 'COLLAPSE_V1'_felt252;

pub fn derive_with_domain(parent_seed: felt252, entropy: felt252, domain: felt252) -> felt252 {
    let (derived, _, _) = core::poseidon::hades_permutation(parent_seed, entropy, domain);
    derived
}

pub fn derive_mine_seed(global_seed: felt252, hex_coordinate: felt252, area_id: felt252) -> felt252 {
    let (stage_one, _, _) = core::poseidon::hades_permutation(global_seed, hex_coordinate, DOMAIN_MINE_V1);
    let (mine_seed, _, _) = core::poseidon::hades_permutation(stage_one, area_id, DOMAIN_MINE_V1);
    mine_seed
}

pub fn derive_strata_seed(mine_seed: felt252, depth_index: u8) -> felt252 {
    derive_with_domain(mine_seed, depth_index.into(), DOMAIN_STRATA_V1)
}

pub fn derive_ore_seed(strata_seed: felt252, ore_slot: u8) -> felt252 {
    derive_with_domain(strata_seed, ore_slot.into(), DOMAIN_ORE_V1)
}

pub fn derive_collapse_seed(mine_seed: felt252, now_block: u64) -> felt252 {
    derive_with_domain(mine_seed, now_block.into(), DOMAIN_COLLAPSE_V1)
}
