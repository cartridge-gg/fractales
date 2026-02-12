use dojo_starter::models::adventurer::Adventurer;
use core::traits::TryInto;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct AdventurerEconomics {
    #[key]
    pub adventurer_id: felt252,
    pub energy_balance: u16,
    pub total_energy_spent: u64,
    pub total_energy_earned: u64,
    pub last_regen_block: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ConversionRate {
    #[key]
    pub item_type: felt252,
    pub current_rate: u16,
    pub base_rate: u16,
    pub last_update_block: u64,
    pub units_converted_in_window: u32,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ClaimEscrowStatus {
    #[default]
    Inactive,
    Active,
    Expired,
    Resolved,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ClaimEscrow {
    #[key]
    pub claim_id: felt252,
    pub hex_coordinate: felt252,
    pub claimant_adventurer_id: felt252,
    pub energy_locked: u16,
    pub created_block: u64,
    pub expiry_block: u64,
    pub status: ClaimEscrowStatus,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ClaimEscrowInitOutcome {
    #[default]
    InvalidAmount,
    Dead,
    InsufficientEnergy,
    AlreadyActive,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ClaimEscrowInitResult {
    pub adventurer: Adventurer,
    pub escrow: ClaimEscrow,
    pub outcome: ClaimEscrowInitOutcome,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ClaimEscrowExpireOutcome {
    #[default]
    Replay,
    NotActive,
    NotExpired,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ClaimEscrowExpireResult {
    pub adventurer: Adventurer,
    pub escrow: ClaimEscrow,
    pub outcome: ClaimEscrowExpireOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct HexDecayState {
    #[key]
    pub hex_coordinate: felt252,
    pub owner_adventurer_id: felt252,
    pub current_energy_reserve: u32,
    pub last_energy_payment_block: u64,
    pub last_decay_processed_block: u64,
    pub decay_level: u16,
    pub claimable_since_block: u64,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DecayProcessOutcome {
    #[default]
    NoElapsedPeriods,
    InvalidPeriod,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct DecayProcessResult {
    pub state: HexDecayState,
    pub outcome: DecayProcessOutcome,
    pub periods_processed: u64,
    pub became_claimable: bool,
}

pub fn derive_hex_claim_id(hex_coordinate: felt252) -> felt252 {
    let (claim_id, _, _) = core::poseidon::hades_permutation(
        hex_coordinate, 'HEX_CLAIM_V1'_felt252, 0_felt252,
    );
    claim_id
}

pub fn initiate_claim_escrow_once_with_status(
    mut adventurer: Adventurer,
    mut escrow: ClaimEscrow,
    energy_offered: u16,
    created_block: u64,
    timeout_blocks: u64,
) -> ClaimEscrowInitResult {
    if !adventurer.is_alive {
        return ClaimEscrowInitResult {
            adventurer, escrow, outcome: ClaimEscrowInitOutcome::Dead,
        };
    }

    if energy_offered == 0_u16 {
        return ClaimEscrowInitResult {
            adventurer, escrow, outcome: ClaimEscrowInitOutcome::InvalidAmount,
        };
    }

    if escrow.status == ClaimEscrowStatus::Active {
        return ClaimEscrowInitResult {
            adventurer, escrow, outcome: ClaimEscrowInitOutcome::AlreadyActive,
        };
    }

    if adventurer.energy < energy_offered {
        return ClaimEscrowInitResult {
            adventurer, escrow, outcome: ClaimEscrowInitOutcome::InsufficientEnergy,
        };
    }

    adventurer.energy -= energy_offered;
    escrow.claimant_adventurer_id = adventurer.adventurer_id;
    escrow.energy_locked = energy_offered;
    escrow.created_block = created_block;
    escrow.expiry_block = created_block + timeout_blocks;
    escrow.status = ClaimEscrowStatus::Active;

    ClaimEscrowInitResult { adventurer, escrow, outcome: ClaimEscrowInitOutcome::Applied }
}

pub fn expire_claim_escrow_once_with_status(
    mut adventurer: Adventurer, mut escrow: ClaimEscrow, now_block: u64,
) -> ClaimEscrowExpireResult {
    if escrow.status == ClaimEscrowStatus::Expired {
        return ClaimEscrowExpireResult {
            adventurer, escrow, outcome: ClaimEscrowExpireOutcome::Replay,
        };
    }

    if escrow.status != ClaimEscrowStatus::Active {
        return ClaimEscrowExpireResult {
            adventurer, escrow, outcome: ClaimEscrowExpireOutcome::NotActive,
        };
    }

    if now_block <= escrow.expiry_block {
        return ClaimEscrowExpireResult {
            adventurer, escrow, outcome: ClaimEscrowExpireOutcome::NotExpired,
        };
    }

    adventurer.energy += escrow.energy_locked;
    escrow.energy_locked = 0_u16;
    escrow.status = ClaimEscrowStatus::Expired;

    ClaimEscrowExpireResult { adventurer, escrow, outcome: ClaimEscrowExpireOutcome::Applied }
}

pub fn process_hex_decay_once_with_status(
    mut state: HexDecayState,
    now_block: u64,
    period_blocks: u64,
    upkeep_per_period: u32,
    claimable_threshold: u16,
) -> DecayProcessResult {
    if period_blocks == 0_u64 {
        return DecayProcessResult {
            state,
            outcome: DecayProcessOutcome::InvalidPeriod,
            periods_processed: 0_u64,
            became_claimable: false,
        };
    }

    let elapsed_blocks = if now_block > state.last_decay_processed_block {
        now_block - state.last_decay_processed_block
    } else {
        0_u64
    };
    let elapsed_periods = elapsed_blocks / period_blocks;

    if elapsed_periods == 0_u64 {
        return DecayProcessResult {
            state,
            outcome: DecayProcessOutcome::NoElapsedPeriods,
            periods_processed: 0_u64,
            became_claimable: false,
        };
    }

    let total_upkeep_u128: u128 = upkeep_per_period.into() * elapsed_periods.into();
    let reserve_u128: u128 = state.current_energy_reserve.into();
    let prior_decay = state.decay_level;

    if reserve_u128 >= total_upkeep_u128 {
        let next_reserve_u128 = reserve_u128 - total_upkeep_u128;
        state.current_energy_reserve = next_reserve_u128.try_into().unwrap();
    } else {
        state.current_energy_reserve = 0_u32;

        let deficit_u128 = total_upkeep_u128 - reserve_u128;
        let decay_headroom = if state.decay_level < 100_u16 {
            100_u16 - state.decay_level
        } else {
            0_u16
        };
        let added_decay = if deficit_u128 > decay_headroom.into() {
            decay_headroom
        } else {
            deficit_u128.try_into().unwrap()
        };
        state.decay_level += added_decay;
    }

    state.last_decay_processed_block += elapsed_periods * period_blocks;

    let became_claimable = prior_decay < claimable_threshold && state.decay_level >= claimable_threshold;
    if became_claimable && state.claimable_since_block == 0_u64 {
        state.claimable_since_block = now_block;
    }

    DecayProcessResult {
        state,
        outcome: DecayProcessOutcome::Applied,
        periods_processed: elapsed_periods,
        became_claimable,
    }
}
