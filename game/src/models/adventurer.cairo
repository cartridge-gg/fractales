use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Adventurer {
    #[key]
    pub adventurer_id: felt252,
    pub owner: ContractAddress,
    pub name: felt252,
    pub energy: u16,
    pub max_energy: u16,
    pub current_hex: felt252,
    pub activity_locked_until: u64,
    pub is_alive: bool,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AdventurerWriteStatus {
    #[default]
    Replay,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct AdventurerMutationResult {
    pub value: Adventurer,
    pub status: AdventurerWriteStatus,
}

pub fn origin_hex_coordinate() -> felt252 {
    match encode_cube(CubeCoord { x: 0, y: 0, z: 0 }) {
        Option::Some(encoded) => encoded,
        Option::None => 0,
    }
}

pub fn can_be_controlled_by(adventurer: Adventurer, caller: ContractAddress) -> bool {
    adventurer.owner == caller
}

pub fn spend_energy(mut adventurer: Adventurer, amount: u16) -> Option<Adventurer> {
    if !adventurer.is_alive {
        return Option::None;
    }
    if adventurer.energy < amount {
        return Option::None;
    }

    adventurer.energy -= amount;
    Option::Some(adventurer)
}

pub fn kill_once_with_status(mut adventurer: Adventurer) -> AdventurerMutationResult {
    if !adventurer.is_alive {
        return AdventurerMutationResult { value: adventurer, status: AdventurerWriteStatus::Replay };
    }

    adventurer.is_alive = false;
    adventurer.activity_locked_until = 0_u64;

    AdventurerMutationResult { value: adventurer, status: AdventurerWriteStatus::Applied }
}
