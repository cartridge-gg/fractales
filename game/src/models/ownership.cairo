#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct AreaOwnership {
    #[key]
    pub area_id: felt252,
    pub owner_adventurer_id: felt252,
    pub discoverer_adventurer_id: felt252,
    pub discovery_block: u64,
    pub claim_block: u64,
}
