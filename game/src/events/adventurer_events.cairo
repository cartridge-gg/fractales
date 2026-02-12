use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdventurerCreated {
    #[key]
    pub adventurer_id: felt252,
    pub owner: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdventurerMoved {
    #[key]
    pub adventurer_id: felt252,
    pub from: felt252,
    pub to: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdventurerDied {
    #[key]
    pub adventurer_id: felt252,
    pub owner: ContractAddress,
    pub cause: felt252,
}
