use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by};
use starknet::ContractAddress;

pub const SWARM_K_LOCKED: u16 = 2_u16;
pub const OVERSTAY_K_BP: u16 = 120_u16;
pub const DENSITY_K_BP: u16 = 2_u16;
pub const MAX_STRESS_PENALTY_BP: u16 = 8_500_u16;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum MiningGuardOutcome {
    #[default]
    Dead,
    NotOwner,
    WrongHex,
    NoAccess,
    Applied,
}

pub fn can_control_alive(adventurer: Adventurer, caller: ContractAddress) -> bool {
    adventurer.is_alive && can_be_controlled_by(adventurer, caller)
}
