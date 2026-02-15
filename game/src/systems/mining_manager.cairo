use core::traits::TryInto;
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

pub fn apply_shoring_stress_delta(base_stress_delta: u32, shoring_bp: u16) -> u32 {
    if base_stress_delta == 0_u32 || shoring_bp <= 10_000_u16 {
        return base_stress_delta;
    }

    let reduction_bp = shoring_bp - 10_000_u16;
    if reduction_bp >= 10_000_u16 {
        return 0_u32;
    }

    let keep_bp_u64: u64 = (10_000_u16 - reduction_bp).into();
    let scaled_u64: u64 = base_stress_delta.into() * keep_bp_u64 / 10_000_u64;
    if scaled_u64 > 4_294_967_295_u64 {
        4_294_967_295_u32
    } else {
        scaled_u64.try_into().unwrap()
    }
}
