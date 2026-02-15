use core::traits::TryInto;
use dojo_starter::libs::autoregulator_math::{clamp_policy_i32, slew_limit_i32};
use dojo_starter::models::economics::{
    RegulatorConfig, RegulatorPolicy, RegulatorState, RegulatorTreasury,
};
use starknet::ContractAddress;

const U16_MAX_U128: u128 = 65_535_u128;
const U32_MAX_U128: u128 = 4_294_967_295_u128;
const U64_MAX_U128: u128 = 18_446_744_073_709_551_615_u128;

pub const DEFAULT_EPOCH_BLOCKS: u64 = 100_u64;
pub const DEFAULT_KEEPER_BOUNTY_ENERGY: u16 = 10_u16;
pub const DEFAULT_KEEPER_BOUNTY_MAX: u16 = 20_u16;
pub const DEFAULT_BOUNTY_FUNDING_SHARE_BP: u16 = 100_u16;
pub const DEFAULT_INFLATION_TARGET_PCT: u16 = 10_u16;
pub const DEFAULT_INFLATION_DEADBAND_PCT: u16 = 1_u16;
pub const DEFAULT_POLICY_SLEW_LIMIT_BP: u16 = 100_u16;
pub const DEFAULT_MIN_CONVERSION_TAX_BP: u16 = 100_u16;
pub const DEFAULT_MAX_CONVERSION_TAX_BP: u16 = 5000_u16;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum TickStatus {
    #[default]
    NoOpEarly,
    NoOpAlreadyTicked,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct TickOutcome {
    pub status: TickStatus,
    pub epoch: u32,
    pub bounty_paid: u16,
    pub policy_changed: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct TickResult {
    pub state: RegulatorState,
    pub policy: RegulatorPolicy,
    pub config: RegulatorConfig,
    pub treasury: RegulatorTreasury,
    pub outcome: TickOutcome,
}

fn saturating_add_u64(lhs: u64, rhs: u64) -> u64 {
    let sum_u128: u128 = lhs.into() + rhs.into();
    if sum_u128 > U64_MAX_U128 {
        18_446_744_073_709_551_615_u64
    } else {
        sum_u128.try_into().unwrap()
    }
}

fn to_u16_saturating(value: u64) -> u16 {
    let value_u128: u128 = value.into();
    if value_u128 > U16_MAX_U128 {
        65_535_u16
    } else {
        value_u128.try_into().unwrap()
    }
}

fn epoch_for_block(now_block: u64, epoch_blocks: u64) -> u32 {
    let blocks = if epoch_blocks == 0_u64 { 1_u64 } else { epoch_blocks };
    let epoch_u64 = now_block / blocks;
    let epoch_u128: u128 = epoch_u64.into();
    if epoch_u128 > U32_MAX_U128 {
        4_294_967_295_u32
    } else {
        epoch_u128.try_into().unwrap()
    }
}

fn next_policy_epoch(policy_epoch: u32) -> u32 {
    if policy_epoch == 4_294_967_295_u32 {
        policy_epoch
    } else {
        policy_epoch + 1_u32
    }
}

pub fn normalize_config(mut config: RegulatorConfig) -> RegulatorConfig {
    if config.epoch_blocks == 0_u64 {
        config.epoch_blocks = DEFAULT_EPOCH_BLOCKS;
    }

    if config.keeper_bounty_max == 0_u16 {
        config.keeper_bounty_max = DEFAULT_KEEPER_BOUNTY_MAX;
    }

    if config.keeper_bounty_energy == 0_u16 {
        config.keeper_bounty_energy = DEFAULT_KEEPER_BOUNTY_ENERGY;
    }

    if config.keeper_bounty_energy > config.keeper_bounty_max {
        config.keeper_bounty_energy = config.keeper_bounty_max;
    }

    if config.bounty_funding_share_bp == 0_u16 {
        config.bounty_funding_share_bp = DEFAULT_BOUNTY_FUNDING_SHARE_BP;
    }

    if config.inflation_target_pct == 0_u16 {
        config.inflation_target_pct = DEFAULT_INFLATION_TARGET_PCT;
    }

    if config.inflation_deadband_pct == 0_u16 {
        config.inflation_deadband_pct = DEFAULT_INFLATION_DEADBAND_PCT;
    }

    if config.policy_slew_limit_bp == 0_u16 {
        config.policy_slew_limit_bp = DEFAULT_POLICY_SLEW_LIMIT_BP;
    }

    if config.min_conversion_tax_bp == 0_u16 {
        config.min_conversion_tax_bp = DEFAULT_MIN_CONVERSION_TAX_BP;
    }

    if config.max_conversion_tax_bp == 0_u16 {
        config.max_conversion_tax_bp = DEFAULT_MAX_CONVERSION_TAX_BP;
    }

    if config.max_conversion_tax_bp < config.min_conversion_tax_bp {
        config.max_conversion_tax_bp = config.min_conversion_tax_bp;
    }

    config
}

fn policy_step(mut policy: RegulatorPolicy, config: RegulatorConfig) -> RegulatorPolicy {
    let current_tax: i32 = policy.conversion_tax_bp.into();
    let desired_tax: i32 = config.max_conversion_tax_bp.into();
    let max_delta: i32 = config.policy_slew_limit_bp.into();
    let stepped_tax = slew_limit_i32(current_tax, desired_tax, max_delta);
    let clamped_tax = clamp_policy_i32(
        stepped_tax,
        config.min_conversion_tax_bp.into(),
        config.max_conversion_tax_bp.into(),
    );

    policy.conversion_tax_bp = clamped_tax.try_into().unwrap();
    policy.policy_epoch = next_policy_epoch(policy.policy_epoch);
    policy
}

pub fn tick_transition(
    state: RegulatorState,
    policy: RegulatorPolicy,
    config_in: RegulatorConfig,
    treasury: RegulatorTreasury,
    now_block: u64,
    caller: ContractAddress,
) -> TickResult {
    let config = normalize_config(config_in);
    let epoch = epoch_for_block(now_block, config.epoch_blocks);

    if state.has_ticked && state.last_tick_epoch == epoch {
        return TickResult {
            state,
            policy,
            config,
            treasury,
            outcome: TickOutcome {
                status: TickStatus::NoOpAlreadyTicked,
                epoch,
                bounty_paid: 0_u16,
                policy_changed: false,
            },
        };
    }

    if !state.has_ticked {
        if now_block < config.epoch_blocks {
            return TickResult {
                state,
                policy,
                config,
                treasury,
                outcome: TickOutcome {
                    status: TickStatus::NoOpEarly,
                    epoch,
                    bounty_paid: 0_u16,
                    policy_changed: false,
                },
            };
        }
    } else {
        let earliest_next = saturating_add_u64(state.last_tick_block, config.epoch_blocks);
        if now_block < earliest_next {
            return TickResult {
                state,
                policy,
                config,
                treasury,
                outcome: TickOutcome {
                    status: TickStatus::NoOpEarly,
                    epoch,
                    bounty_paid: 0_u16,
                    policy_changed: false,
                },
            };
        }
    }

    let next_policy = policy_step(policy, config);

    let mut next_treasury = treasury;
    let bounty_target = if config.keeper_bounty_energy < config.keeper_bounty_max {
        config.keeper_bounty_energy
    } else {
        config.keeper_bounty_max
    };
    let bounty_target_u64: u64 = bounty_target.into();
    let bounty_paid_u64 = if next_treasury.regulator_bounty_pool < bounty_target_u64 {
        next_treasury.regulator_bounty_pool
    } else {
        bounty_target_u64
    };
    let bounty_paid = to_u16_saturating(bounty_paid_u64);
    next_treasury.regulator_bounty_pool -= bounty_paid_u64;
    next_treasury.last_bounty_epoch = epoch;
    next_treasury.last_bounty_paid = bounty_paid;
    next_treasury.last_bounty_caller = caller;

    let mut next_state = state;
    next_state.has_ticked = true;
    next_state.last_tick_block = now_block;
    next_state.last_tick_epoch = epoch;

    TickResult {
        state: next_state,
        policy: next_policy,
        config,
        treasury: next_treasury,
        outcome: TickOutcome {
            status: TickStatus::Applied,
            epoch,
            bounty_paid,
            policy_changed: true,
        },
    }
}
