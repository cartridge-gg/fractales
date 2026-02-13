use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by};
use dojo_starter::models::ownership::AreaOwnership;
use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum OwnershipTransferOutcome {
    #[default]
    NoOwner,
    NotOwner,
    InvalidTarget,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct OwnershipTransferResult {
    pub ownership: AreaOwnership,
    pub outcome: OwnershipTransferOutcome,
}

pub fn get_owner_transition(ownership: AreaOwnership) -> felt252 {
    ownership.owner_adventurer_id
}

pub fn transfer_transition(
    mut ownership: AreaOwnership,
    owner_adventurer: Adventurer,
    to_adventurer: Adventurer,
    caller: ContractAddress,
    to_adventurer_id: felt252,
    claim_block: u64,
) -> OwnershipTransferResult {
    if ownership.owner_adventurer_id == 0_felt252 {
        return OwnershipTransferResult {
            ownership, outcome: OwnershipTransferOutcome::NoOwner,
        };
    }

    if to_adventurer_id == 0_felt252 || to_adventurer_id == ownership.owner_adventurer_id {
        return OwnershipTransferResult {
            ownership, outcome: OwnershipTransferOutcome::InvalidTarget,
        };
    }
    if to_adventurer.adventurer_id != to_adventurer_id || !to_adventurer.is_alive {
        return OwnershipTransferResult {
            ownership, outcome: OwnershipTransferOutcome::InvalidTarget,
        };
    }

    if owner_adventurer.adventurer_id != ownership.owner_adventurer_id
        || !owner_adventurer.is_alive
        || !can_be_controlled_by(owner_adventurer, caller) {
        return OwnershipTransferResult {
            ownership, outcome: OwnershipTransferOutcome::NotOwner,
        };
    }

    ownership.owner_adventurer_id = to_adventurer_id;
    ownership.claim_block = claim_block;
    OwnershipTransferResult { ownership, outcome: OwnershipTransferOutcome::Applied }
}
