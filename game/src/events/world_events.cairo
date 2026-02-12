use dojo_starter::models::world::{AreaType, Biome};
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HexDiscovered {
    #[key]
    pub hex: felt252,
    pub biome: Biome,
    pub discoverer: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AreaDiscovered {
    #[key]
    pub area_id: felt252,
    pub hex: felt252,
    pub area_type: AreaType,
    pub discoverer: ContractAddress,
}
