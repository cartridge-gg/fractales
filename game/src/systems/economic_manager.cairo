use dojo_starter::libs::conversion_math::{effective_rate, quote_energy};
use dojo_starter::libs::decay_math::{
    maintenance_decay_recovery, min_claim_energy, upkeep_for_biome,
};
use core::traits::TryInto;
use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by};
use dojo_starter::models::economics::{
    AdventurerEconomics, ClaimEscrow, ClaimEscrowInitOutcome, ClaimEscrowStatus, ConversionRate,
    DecayProcessOutcome, HexDecayState, derive_hex_claim_id, initiate_claim_escrow_once_with_status,
    process_hex_decay_once_with_status,
};
use dojo_starter::models::inventory::{BackpackItem, Inventory};
use dojo_starter::models::world::Biome;
use dojo_starter::systems::adventurer_manager::{ConsumeOutcome, consume_transition};
use starknet::ContractAddress;

const ENERGY_REGEN_PER_100_BLOCKS: u16 = 20_u16;
const CLAIM_SURFACE_MIN_ENERGY_CAP: u16 = 100_u16;
const U16_MAX_U128: u128 = 65535_u128;
const U32_MAX_U128: u128 = 4_294_967_295_u128;
const U64_MAX_U128: u128 = 18_446_744_073_709_551_615_u128;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConvertOutcome {
    #[default]
    Dead,
    NotOwner,
    InvalidQuantity,
    InvalidRate,
    InsufficientItems,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum PayOutcome {
    #[default]
    Dead,
    NotOwner,
    NotController,
    InvalidAmount,
    InsufficientEnergy,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DecayOutcome {
    #[default]
    InvalidPeriod,
    NoElapsedPeriods,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ClaimInitOutcome {
    #[default]
    Dead,
    NotOwner,
    NotClaimable,
    BelowMinimum,
    InvalidAmount,
    InsufficientEnergy,
    EscrowAlreadyActive,
    AppliedPending,
    AppliedImmediate,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DefendOutcome {
    #[default]
    Dead,
    NotOwner,
    NotController,
    NoActiveClaim,
    ClaimExpired,
    InvalidAmount,
    InsufficientEnergy,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ConvertResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub inventory: Inventory,
    pub item: BackpackItem,
    pub rate: ConversionRate,
    pub outcome: ConvertOutcome,
    pub energy_gained: u16,
    pub minted_energy: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct PayResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub state: HexDecayState,
    pub outcome: PayOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct DecayResult {
    pub state: HexDecayState,
    pub outcome: DecayOutcome,
    pub periods_processed: u64,
    pub became_claimable: bool,
    pub min_energy_to_claim: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ClaimInitResult {
    pub claimant: Adventurer,
    pub claimant_economics: AdventurerEconomics,
    pub state: HexDecayState,
    pub escrow: ClaimEscrow,
    pub outcome: ClaimInitOutcome,
    pub min_energy_to_claim: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct DefendResult {
    pub defender: Adventurer,
    pub defender_economics: AdventurerEconomics,
    pub claimant: Adventurer,
    pub claimant_economics: AdventurerEconomics,
    pub state: HexDecayState,
    pub escrow: ClaimEscrow,
    pub outcome: DefendOutcome,
}

fn saturating_add_u16(lhs: u16, rhs: u16) -> u16 {
    let sum_u128: u128 = lhs.into() + rhs.into();
    if sum_u128 > U16_MAX_U128 {
        65535_u16
    } else {
        sum_u128.try_into().unwrap()
    }
}

fn saturating_add_u32(lhs: u32, rhs: u32) -> u32 {
    let sum_u128: u128 = lhs.into() + rhs.into();
    if sum_u128 > U32_MAX_U128 {
        4_294_967_295_u32
    } else {
        sum_u128.try_into().unwrap()
    }
}

fn saturating_add_u64(lhs: u64, rhs: u64) -> u64 {
    let sum_u128: u128 = lhs.into() + rhs.into();
    if sum_u128 > U64_MAX_U128 {
        18_446_744_073_709_551_615_u64
    } else {
        sum_u128.try_into().unwrap()
    }
}

fn mint_energy_with_cap(
    mut adventurer: Adventurer,
    mut economics: AdventurerEconomics,
    raw_energy: u16,
) -> (Adventurer, AdventurerEconomics, u16) {
    let cap_room = if adventurer.max_energy > adventurer.energy {
        adventurer.max_energy - adventurer.energy
    } else {
        0_u16
    };
    let minted = if raw_energy > cap_room { cap_room } else { raw_energy };

    if minted > 0_u16 {
        adventurer.energy += minted;
        economics.total_energy_earned = saturating_add_u64(economics.total_energy_earned, minted.into());
    }
    economics.energy_balance = adventurer.energy;

    (adventurer, economics, minted)
}

pub fn convert_transition(
    adventurer: Adventurer,
    economics: AdventurerEconomics,
    caller: ContractAddress,
    mut inventory: Inventory,
    mut item: BackpackItem,
    mut rate: ConversionRate,
    quantity: u16,
    now_block: u64,
    window_blocks: u64,
) -> ConvertResult {
    if !adventurer.is_alive {
        return ConvertResult {
            adventurer,
            economics,
            inventory,
            item,
            rate,
            outcome: ConvertOutcome::Dead,
            energy_gained: 0_u16,
            minted_energy: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return ConvertResult {
            adventurer,
            economics,
            inventory,
            item,
            rate,
            outcome: ConvertOutcome::NotOwner,
            energy_gained: 0_u16,
            minted_energy: 0_u16,
        };
    }
    if quantity == 0_u16 {
        return ConvertResult {
            adventurer,
            economics,
            inventory,
            item,
            rate,
            outcome: ConvertOutcome::InvalidQuantity,
            energy_gained: 0_u16,
            minted_energy: 0_u16,
        };
    }

    let quantity_u32: u32 = quantity.into();
    if quantity_u32 > item.quantity {
        return ConvertResult {
            adventurer,
            economics,
            inventory,
            item,
            rate,
            outcome: ConvertOutcome::InsufficientItems,
            energy_gained: 0_u16,
            minted_energy: 0_u16,
        };
    }

    if rate.item_type == 0_felt252 {
        rate.item_type = item.item_id;
    }
    if rate.current_rate == 0_u16 {
        if rate.base_rate == 0_u16 {
            rate.base_rate = 10_u16;
            rate.current_rate = 10_u16;
        } else {
            rate.current_rate = rate.base_rate;
        }
    }

    let rate_per_unit = effective_rate(rate, now_block, window_blocks);
    if rate_per_unit == 0_u16 {
        return ConvertResult {
            adventurer,
            economics,
            inventory,
            item,
            rate,
            outcome: ConvertOutcome::InvalidRate,
            energy_gained: 0_u16,
            minted_energy: 0_u16,
        };
    }

    let raw_energy = quote_energy(quantity, rate_per_unit);
    let (next_adventurer, next_economics, minted_energy) = mint_energy_with_cap(
        adventurer, economics, raw_energy,
    );

    item.quantity -= quantity_u32;
    let removed_weight_u128: u128 = quantity_u32.into() * item.weight_per_unit.into();
    let removed_weight = if removed_weight_u128 > inventory.current_weight.into() {
        inventory.current_weight
    } else {
        removed_weight_u128.try_into().unwrap()
    };
    inventory.current_weight -= removed_weight;

    let in_window = if now_block >= rate.last_update_block {
        now_block - rate.last_update_block < window_blocks
    } else {
        true
    };
    if in_window {
        rate.units_converted_in_window = saturating_add_u32(
            rate.units_converted_in_window, quantity_u32,
        );
    } else {
        rate.units_converted_in_window = quantity_u32;
    }
    rate.last_update_block = now_block;

    ConvertResult {
        adventurer: next_adventurer,
        economics: next_economics,
        inventory,
        item,
        rate,
        outcome: ConvertOutcome::Applied,
        energy_gained: raw_energy,
        minted_energy,
    }
}

pub fn pay_maintenance_transition(
    adventurer: Adventurer,
    economics: AdventurerEconomics,
    caller: ContractAddress,
    mut state: HexDecayState,
    amount: u16,
    upkeep_per_period: u32,
    now_block: u64,
    recovery_bp: u16,
    claimable_threshold: u16,
) -> PayResult {
    if !adventurer.is_alive {
        return PayResult { adventurer, economics, state, outcome: PayOutcome::Dead };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return PayResult { adventurer, economics, state, outcome: PayOutcome::NotOwner };
    }
    if adventurer.adventurer_id != state.owner_adventurer_id {
        return PayResult { adventurer, economics, state, outcome: PayOutcome::NotController };
    }
    if amount == 0_u16 {
        return PayResult { adventurer, economics, state, outcome: PayOutcome::InvalidAmount };
    }

    let consumed = consume_transition(
        adventurer, economics, caller, amount, now_block, ENERGY_REGEN_PER_100_BLOCKS,
    );
    match consumed.outcome {
        ConsumeOutcome::Applied => {},
        ConsumeOutcome::InsufficientEnergy => {
            return PayResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                state,
                outcome: PayOutcome::InsufficientEnergy,
            };
        },
        ConsumeOutcome::Dead => {
            return PayResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                state,
                outcome: PayOutcome::Dead,
            };
        },
        ConsumeOutcome::NotOwner => {
            return PayResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                state,
                outcome: PayOutcome::NotOwner,
            };
        },
    }

    state.current_energy_reserve = saturating_add_u32(state.current_energy_reserve, amount.into());
    state.last_energy_payment_block = now_block;

    let recovery = maintenance_decay_recovery(amount, upkeep_per_period, recovery_bp);
    if recovery >= state.decay_level {
        state.decay_level = 0_u16;
    } else {
        state.decay_level -= recovery;
    }
    if state.decay_level < claimable_threshold {
        state.claimable_since_block = 0_u64;
    }

    PayResult {
        adventurer: consumed.adventurer,
        economics: consumed.economics,
        state,
        outcome: PayOutcome::Applied,
    }
}

pub fn process_decay_transition(
    state: HexDecayState,
    biome: Biome,
    now_block: u64,
    period_blocks: u64,
    claimable_threshold: u16,
) -> DecayResult {
    let upkeep = upkeep_for_biome(biome);
    let processed = process_hex_decay_once_with_status(
        state, now_block, period_blocks, upkeep, claimable_threshold,
    );

    let min_energy = if processed.state.decay_level >= claimable_threshold {
        let computed = min_claim_energy(upkeep, processed.state.decay_level, claimable_threshold);
        if computed > CLAIM_SURFACE_MIN_ENERGY_CAP {
            CLAIM_SURFACE_MIN_ENERGY_CAP
        } else {
            computed
        }
    } else {
        0_u16
    };

    let outcome = match processed.outcome {
        DecayProcessOutcome::Applied => DecayOutcome::Applied,
        DecayProcessOutcome::NoElapsedPeriods => DecayOutcome::NoElapsedPeriods,
        DecayProcessOutcome::InvalidPeriod => DecayOutcome::InvalidPeriod,
    };

    DecayResult {
        state: processed.state,
        outcome,
        periods_processed: processed.periods_processed,
        became_claimable: processed.became_claimable,
        min_energy_to_claim: min_energy,
    }
}

pub fn initiate_claim_transition(
    claimant: Adventurer,
    mut claimant_economics: AdventurerEconomics,
    caller: ContractAddress,
    mut state: HexDecayState,
    mut escrow: ClaimEscrow,
    energy_offered: u16,
    now_block: u64,
    timeout_blocks: u64,
    grace_blocks: u64,
    min_energy_required: u32,
    _recovery_bp: u16,
    claimable_threshold: u16,
) -> ClaimInitResult {
    let min_required_u16 = if min_energy_required > 65535_u32 {
        65535_u16
    } else {
        min_energy_required.try_into().unwrap()
    };
    let effective_min_required_u16 = if min_required_u16 > claimant.max_energy {
        claimant.max_energy
    } else {
        min_required_u16
    };

    if !claimant.is_alive {
        return ClaimInitResult {
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: ClaimInitOutcome::Dead,
            min_energy_to_claim: effective_min_required_u16,
        };
    }
    if !can_be_controlled_by(claimant, caller) {
        return ClaimInitResult {
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: ClaimInitOutcome::NotOwner,
            min_energy_to_claim: effective_min_required_u16,
        };
    }

    if state.decay_level < claimable_threshold || state.claimable_since_block == 0_u64 {
        return ClaimInitResult {
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: ClaimInitOutcome::NotClaimable,
            min_energy_to_claim: effective_min_required_u16,
        };
    }

    if energy_offered == 0_u16 {
        return ClaimInitResult {
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: ClaimInitOutcome::InvalidAmount,
            min_energy_to_claim: effective_min_required_u16,
        };
    }

    if energy_offered < effective_min_required_u16 {
        return ClaimInitResult {
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: ClaimInitOutcome::BelowMinimum,
            min_energy_to_claim: effective_min_required_u16,
        };
    }

    escrow.claim_id = if escrow.claim_id == 0_felt252 {
        derive_hex_claim_id(state.hex_coordinate)
    } else {
        escrow.claim_id
    };
    escrow.hex_coordinate = state.hex_coordinate;

    let initiated = initiate_claim_escrow_once_with_status(
        claimant, escrow, energy_offered, now_block, timeout_blocks,
    );

    let mut next_escrow = initiated.escrow;
    let outcome = match initiated.outcome {
        ClaimEscrowInitOutcome::Applied => {
            let elapsed = if now_block > state.claimable_since_block {
                now_block - state.claimable_since_block
            } else {
                0_u64
            };

            claimant_economics.energy_balance = initiated.adventurer.energy;
            claimant_economics.total_energy_spent = saturating_add_u64(
                claimant_economics.total_energy_spent, energy_offered.into(),
            );

            if elapsed >= grace_blocks {
                state.owner_adventurer_id = initiated.adventurer.adventurer_id;
                state.current_energy_reserve = saturating_add_u32(
                    state.current_energy_reserve, energy_offered.into(),
                );
                state.decay_level = 0_u16;
                state.claimable_since_block = 0_u64;
                next_escrow.status = ClaimEscrowStatus::Resolved;
                next_escrow.energy_locked = 0_u16;
                ClaimInitOutcome::AppliedImmediate
            } else {
                ClaimInitOutcome::AppliedPending
            }
        },
        ClaimEscrowInitOutcome::InvalidAmount => ClaimInitOutcome::InvalidAmount,
        ClaimEscrowInitOutcome::Dead => ClaimInitOutcome::Dead,
        ClaimEscrowInitOutcome::InsufficientEnergy => ClaimInitOutcome::InsufficientEnergy,
        ClaimEscrowInitOutcome::AlreadyActive => ClaimInitOutcome::EscrowAlreadyActive,
    };

    ClaimInitResult {
        claimant: initiated.adventurer,
        claimant_economics,
        state,
        escrow: next_escrow,
        outcome,
        min_energy_to_claim: effective_min_required_u16,
    }
}

pub fn defend_claim_transition(
    defender: Adventurer,
    defender_economics: AdventurerEconomics,
    caller: ContractAddress,
    mut state: HexDecayState,
    mut escrow: ClaimEscrow,
    mut claimant: Adventurer,
    mut claimant_economics: AdventurerEconomics,
    defense_energy: u16,
    now_block: u64,
    upkeep_per_period: u32,
    recovery_bp: u16,
    claimable_threshold: u16,
) -> DefendResult {
    if !defender.is_alive {
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::Dead,
        };
    }
    if !can_be_controlled_by(defender, caller) {
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::NotOwner,
        };
    }
    if defender.adventurer_id != state.owner_adventurer_id {
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::NotController,
        };
    }
    if escrow.status != ClaimEscrowStatus::Active || escrow.hex_coordinate != state.hex_coordinate {
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::NoActiveClaim,
        };
    }
    if now_block > escrow.expiry_block {
        let refunded = escrow.energy_locked;
        claimant.energy = saturating_add_u16(claimant.energy, refunded);
        claimant_economics.energy_balance = claimant.energy;
        claimant_economics.total_energy_earned = saturating_add_u64(
            claimant_economics.total_energy_earned, refunded.into(),
        );
        escrow.status = ClaimEscrowStatus::Expired;
        escrow.energy_locked = 0_u16;
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::ClaimExpired,
        };
    }
    if defense_energy == 0_u16 || defense_energy < escrow.energy_locked {
        return DefendResult {
            defender,
            defender_economics,
            claimant,
            claimant_economics,
            state,
            escrow,
            outcome: DefendOutcome::InvalidAmount,
        };
    }

    let consumed = consume_transition(
        defender, defender_economics, caller, defense_energy, now_block, ENERGY_REGEN_PER_100_BLOCKS,
    );
    match consumed.outcome {
        ConsumeOutcome::Applied => {},
        ConsumeOutcome::InsufficientEnergy => {
            return DefendResult {
                defender: consumed.adventurer,
                defender_economics: consumed.economics,
                claimant,
                claimant_economics,
                state,
                escrow,
                outcome: DefendOutcome::InsufficientEnergy,
            };
        },
        ConsumeOutcome::Dead => {
            return DefendResult {
                defender: consumed.adventurer,
                defender_economics: consumed.economics,
                claimant,
                claimant_economics,
                state,
                escrow,
                outcome: DefendOutcome::Dead,
            };
        },
        ConsumeOutcome::NotOwner => {
            return DefendResult {
                defender: consumed.adventurer,
                defender_economics: consumed.economics,
                claimant,
                claimant_economics,
                state,
                escrow,
                outcome: DefendOutcome::NotOwner,
            };
        },
    }

    state.current_energy_reserve = saturating_add_u32(state.current_energy_reserve, defense_energy.into());
    let recovery = maintenance_decay_recovery(defense_energy, upkeep_per_period, recovery_bp);
    if recovery >= state.decay_level {
        state.decay_level = 0_u16;
    } else {
        state.decay_level -= recovery;
    }
    if state.decay_level < claimable_threshold {
        state.claimable_since_block = 0_u64;
    }

    claimant.energy = saturating_add_u16(claimant.energy, escrow.energy_locked);
    claimant_economics.energy_balance = claimant.energy;
    claimant_economics.total_energy_earned = saturating_add_u64(
        claimant_economics.total_energy_earned, escrow.energy_locked.into(),
    );

    escrow.status = ClaimEscrowStatus::Resolved;
    escrow.energy_locked = 0_u16;

    DefendResult {
        defender: consumed.adventurer,
        defender_economics: consumed.economics,
        claimant,
        claimant_economics,
        state,
        escrow,
        outcome: DefendOutcome::Applied,
    }
}
