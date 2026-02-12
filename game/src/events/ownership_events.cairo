#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AreaOwnershipAssigned {
    #[key]
    pub area_id: felt252,
    pub owner_adventurer_id: felt252,
    pub discoverer_adventurer_id: felt252,
    pub claim_block: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct OwnershipTransferred {
    #[key]
    pub area_id: felt252,
    pub from_adventurer_id: felt252,
    pub to_adventurer_id: felt252,
    pub claim_block: u64,
}
