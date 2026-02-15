#[cfg(test)]
mod tests {
    use core::traits::TryInto;
    use dojo_starter::models::economics::{
        RegulatorConfig, RegulatorPolicy, RegulatorState, RegulatorTreasury,
    };
    use dojo_starter::systems::autoregulator_manager::{
        TickStatus, tick_transition,
    };

    fn base_state() -> RegulatorState {
        RegulatorState {
            slot: 1_u8,
            has_ticked: false,
            last_tick_block: 0_u64,
            last_tick_epoch: 0_u32,
        }
    }

    fn base_policy() -> RegulatorPolicy {
        RegulatorPolicy {
            slot: 1_u8,
            policy_epoch: 0_u32,
            conversion_tax_bp: 300_u16,
            upkeep_bp: 10_000_u16,
            mint_discount_bp: 0_u16,
        }
    }

    fn base_config() -> RegulatorConfig {
        RegulatorConfig {
            slot: 1_u8,
            epoch_blocks: 100_u64,
            keeper_bounty_energy: 10_u16,
            keeper_bounty_max: 20_u16,
            bounty_funding_share_bp: 100_u16,
            inflation_target_pct: 10_u16,
            inflation_deadband_pct: 1_u16,
            policy_slew_limit_bp: 100_u16,
            min_conversion_tax_bp: 100_u16,
            max_conversion_tax_bp: 5000_u16,
        }
    }

    fn base_treasury(pool: u64) -> RegulatorTreasury {
        RegulatorTreasury {
            slot: 1_u8,
            regulator_bounty_pool: pool,
            last_bounty_epoch: 0_u32,
            last_bounty_paid: 0_u16,
            last_bounty_caller: 0.try_into().unwrap(),
        }
    }

    #[test]
    fn tick_first_valid_call_applies_and_pays_bounty() {
        let result = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(100_u64),
            100_u64,
            123.try_into().unwrap(),
        );

        assert(result.outcome.status == TickStatus::Applied, 'AR_TICK_APPLIED');
        assert(result.outcome.epoch == 1_u32, 'AR_TICK_EPOCH');
        assert(result.outcome.bounty_paid == 10_u16, 'AR_TICK_BOUNTY');
        assert(result.state.has_ticked, 'AR_TICK_FLAG');
        assert(result.treasury.regulator_bounty_pool == 90_u64, 'AR_TICK_POOL');
    }

    #[test]
    fn tick_second_call_same_epoch_noop_and_zero_bounty() {
        let first = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(100_u64),
            100_u64,
            123.try_into().unwrap(),
        );
        let second = tick_transition(
            first.state,
            first.policy,
            base_config(),
            first.treasury,
            150_u64,
            456.try_into().unwrap(),
        );

        assert(second.outcome.status == TickStatus::NoOpAlreadyTicked, 'AR_TICK_REPLAY');
        assert(second.outcome.bounty_paid == 0_u16, 'AR_TICK_REPLAY_BOUNTY');
        assert(second.treasury.regulator_bounty_pool == 90_u64, 'AR_TICK_REPLAY_POOL');
    }

    #[test]
    fn tick_before_boundary_noop_and_zero_bounty() {
        let result = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(100_u64),
            50_u64,
            123.try_into().unwrap(),
        );

        assert(result.outcome.status == TickStatus::NoOpEarly, 'AR_TICK_EARLY');
        assert(result.outcome.bounty_paid == 0_u16, 'AR_TICK_EARLY_BOUNTY');
        assert(result.treasury.regulator_bounty_pool == 100_u64, 'AR_TICK_EARLY_POOL');
    }

    #[test]
    fn tick_low_bounty_pool_clips_payout_without_revert() {
        let result = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(4_u64),
            100_u64,
            123.try_into().unwrap(),
        );

        assert(result.outcome.status == TickStatus::Applied, 'AR_TICK_CLIP_STATUS');
        assert(result.outcome.bounty_paid == 4_u16, 'AR_TICK_CLIP_BOUNTY');
        assert(result.treasury.regulator_bounty_pool == 0_u64, 'AR_TICK_CLIP_POOL');
    }

    #[test]
    fn bounty_pool_never_negative() {
        let result = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(0_u64),
            100_u64,
            123.try_into().unwrap(),
        );

        assert(result.outcome.status == TickStatus::Applied, 'AR_TICK_ZP_STATUS');
        assert(result.outcome.bounty_paid == 0_u16, 'AR_TICK_ZP_BOUNTY');
        assert(result.treasury.regulator_bounty_pool == 0_u64, 'AR_TICK_ZP_POOL');
    }

    #[test]
    fn policy_updates_even_if_bounty_zero() {
        let result = tick_transition(
            base_state(),
            base_policy(),
            base_config(),
            base_treasury(0_u64),
            100_u64,
            123.try_into().unwrap(),
        );

        assert(result.outcome.status == TickStatus::Applied, 'AR_TICK_POL_STATUS');
        assert(result.outcome.policy_changed, 'AR_TICK_POL_CHANGED');
        assert(result.policy.policy_epoch == 1_u32, 'AR_TICK_POL_EPOCH');
    }
}
