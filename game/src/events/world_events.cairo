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

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct WorldGenConfigInitialized {
    #[key]
    pub generation_version: u16,
    pub global_seed: felt252,
    pub biome_scale_bp: u16,
    pub area_scale_bp: u16,
    pub plant_scale_bp: u16,
    pub biome_octaves: u8,
    pub area_octaves: u8,
    pub plant_octaves: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct WorldActionRejected {
    #[key]
    pub adventurer_id: felt252,
    pub action: felt252,
    pub target: felt252,
    pub reason: felt252,
}
