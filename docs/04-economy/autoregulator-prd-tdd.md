# Autoregulator PRD + TDD (Permissionless + Keeper Bounty)

## 1. Purpose

Define a deterministic, self-regulating economy controller that requires no operator intervention after deployment.

The controller is:

- permissionless to execute,
- bounded and anti-oscillation by design,
- coupled to explicit inflation and activity targets.

## 2. Core Requirement

`tick_autoregulator()` must be permissionless.

- Anyone can call it.
- It can be called every day (or any cadence), but only executes once per epoch.
- First valid caller in an epoch gets a small energy bounty.

## 3. Control Objectives

Primary target:

- baseline inflation near `10%` over an 8-week horizon.

Secondary targets:

- exploration remains healthy,
- collapse risk remains meaningful but not catastrophic,
- concentration pressure remains bounded.

## 4. Control Loop

Every `EPOCH_BLOCKS`:

1. Finalize current epoch accumulator into snapshot.
2. Compute control error from target metrics.
3. Update controller state (`P/I` terms with clamps and deadband).
4. Compute next policy with slew limits.
5. Persist policy for next epoch actions.

## 5. Permissionless Tick + Bounty

### 5.1 Tick semantics

- `tick_autoregulator()` is external and permissionless.
- Tick is executable only when `now_block >= last_tick_block + EPOCH_BLOCKS`.
- If called early, return no-op.
- If already executed for the same epoch, return no-op.

### 5.2 Bounty semantics

- First successful tick in epoch receives `keeper_bounty_energy`.
- Bounty is paid from `regulator_bounty_pool`.
- Bounty is clipped to available pool balance (never revert on low pool).
- No bounty is paid for no-op calls.
- Max one bounty payout per epoch.

### 5.3 Funding

- `regulator_bounty_pool` is funded automatically from a bounded share of conversion tax/treasury inflow.
- Funding share is fixed in config and bounded by min/max.

## 6. Data Model Scope

Add models:

- `EconomyAccumulator`
  - per-epoch counters (`sources`, `sinks`, `new_hexes`, `deaths`, `mints`, etc.)
- `EconomyEpochSnapshot`
  - finalized immutable epoch metrics
- `RegulatorState`
  - `last_tick_block`, `last_tick_epoch`, integral terms, regime
- `RegulatorPolicy`
  - live policy values consumed by economic systems
- `RegulatorConfig`
  - immutable/boot-time bounds, gains, deadbands, slew limits
- `RegulatorTreasury`
  - `regulator_bounty_pool`, `last_bounty_epoch`

## 7. System API Scope

Add new manager:

- `tick_autoregulator() -> TickOutcome`
- `get_regulator_policy() -> RegulatorPolicy`
- `get_latest_snapshot() -> EconomyEpochSnapshot`

`TickOutcome` includes:

- `status` (`NoOpEarly`, `NoOpAlreadyTicked`, `Applied`)
- `epoch`
- `bounty_paid`
- `policy_changed`

## 8. Determinism and Safety Rules

- All arithmetic is deterministic and bounded.
- Deadband around target prevents micro-jitter.
- Integral term uses anti-windup clamps.
- Per-tick policy changes are slew-limited.
- Policy values are hard-clamped to safe min/max.
- Bounty pool cannot go negative.
- Tick never reverts due to insufficient bounty pool.

## 9. Events

- `RegulatorTicked { epoch, caller, bounty_paid, status }`
- `RegulatorPolicyUpdated { epoch, ...policy_fields }`
- `RegimeChanged { from, to, epoch }`
- `BountyPaid { epoch, caller, amount }`

## 10. TDD Plan

### Stage A: Math primitives

Files:

- `game/src/libs/autoregulator_math.cairo`
- `game/src/tests/unit/autoregulator_math_test.cairo`

RED tests:

1. `pi_deadband_zero_output`
2. `pi_positive_error_increases_output`
3. `pi_negative_error_decreases_output`
4. `integral_clamped_anti_windup`
5. `slew_limit_caps_delta`
6. `policy_clamps_hold_bounds`

### Stage B: Epoch accounting models

Files:

- `game/src/models/economics.cairo`
- `game/src/tests/unit/economics_models_test.cairo`

RED tests:

1. `epoch_finalize_once`
2. `accumulator_reset_after_finalize`
3. `snapshot_non_negative_fields`

### Stage C: Permissionless tick + bounty

Files:

- `game/src/systems/autoregulator_manager_contract.cairo`
- `game/src/tests/unit/autoregulator_manager_test.cairo`
- `game/src/tests/integration/autoregulator_keeper_bounty_integration_test.cairo`

RED tests:

1. `tick_first_valid_call_applies_and_pays_bounty`
2. `tick_second_call_same_epoch_noop_and_zero_bounty`
3. `tick_before_boundary_noop_and_zero_bounty`
4. `tick_low_bounty_pool_clips_payout_without_revert`
5. `bounty_pool_never_negative`
6. `policy_updates_even_if_bounty_zero`

### Stage D: Wire live policy consumers

Files:

- `game/src/systems/economic_manager_contract.cairo`
- `game/src/systems/adventurer_manager_contract.cairo` (mint pricing path)
- integration tests in `game/src/tests/integration/`

RED tests:

1. `conversion_tax_reads_regulator_policy`
2. `upkeep_reads_regulator_policy`
3. `mint_discount_reads_regulator_policy`
4. `policy_changes_apply_next_epoch`

### Stage E: Stability assertions

Simulator tests:

- baseline inflation in `9..11`
- matrix inflation in `-5..21`
- no sustained oscillation in policy values over long horizon

## 11. Acceptance Criteria

1. No privileged actor required to rebalance economy.
2. Exactly one successful policy tick per epoch.
3. Exactly one bounty payout per epoch max.
4. Tick path remains safe under empty bounty pool.
5. Baseline and matrix inflation test bands pass.

## 12. Default Parameters (Initial)

- `EPOCH_BLOCKS = 100`
- `keeper_bounty_energy = 10`
- `keeper_bounty_max = 20`
- `bounty_funding_share_bp = 100` (1% of configured inflow stream)
- `inflation_target_pct = 10`
- `inflation_deadband_pct = 1`
- `policy_slew_limit_bp = 100`
