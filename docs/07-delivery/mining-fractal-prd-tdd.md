# Mining Fractal PRD + TDD (Post-MVP Module)

## 1. Purpose

Define a build-ready, test-first specification for adding deterministic, multiplayer mining to `gen-dungeon` as a post-MVP module.

This document is implementation-facing and should be treated as the contract for mining behavior, test coverage, and rollout sequence.

## 2. Product Goal

Add a second deterministic extraction loop that complements harvesting:

- Harvesting is primarily solo optimization.
- Mining is shared-risk optimization.

Mining should create a clear social dilemma:

- More miners and longer mining sessions increase short-term output.
- The same behavior increases collapse risk for everyone.
- Players must decide between greed (`continue_mining`) and sustainability (`stabilize_mine` or `exit_mine`).

## 3. Scope

In scope:

- Deterministic mine generation from world seed and coordinates.
- Mine discovery and initialization flow mirroring hex/area/plant deterministic rules.
- Multiplayer mining lifecycle with collapse pressure from elapsed mining time per adventurer and concurrent miner density.
- Mine stabilization action and cooldown/repair lifecycle.
- Ore inventory minting and conversion integration.
- Full owner-only control guardrails on adventurer actions.
- Unit, integration, and live-Katana simulation coverage.

Out of scope for this phase:

- Permission hooks and custom access contracts.
- Building/infrastructure systems.
- Offchain AI control loops.
- Non-deterministic randomness sources.

## 4. Design Constraints

- Deterministic only: all generation and collapse outcomes derive from onchain state + deterministic formulas.
- No caller-defined content payloads: no user-supplied ore quality, mine health, or thresholds.
- Access-controlled multiplayer: area controller always has access and can grant/revoke access to other adventurers.
- Owner-only adventurer control: only adventurer owner can call move/mine/stabilize/exit for that adventurer.
- Alive-only mutation: dead adventurers cannot start, continue, stabilize, or exit mining.
- Replay safety: discovery/init actions are idempotent and immutable on replay.
- Soft-cap only: no hard miner count cap; anti-swarm friction and collapse risk scale continuously.
- Collapse is lethal: collapse applies permadeath to active miners in the collapsed mine.
- Unbanked ore is lost on collapse.
- Mine depletion is permanent: depleted mines do not regenerate.

## 5. Fractal Generation Tree

Mining extends the existing deterministic tree:

1. `HexProfile = f(seed, hex_coordinate)`
2. `AreaProfile = f(seed, hex_coordinate, area_index)`
3. `MineProfile = f(seed, hex_coordinate, area_id, mine_id)`
4. `StrataProfile = f(seed, mine_key, depth_index)`
5. `OreProfile = f(seed, mine_key, stratum, ore_slot)`

Domain tags (proposed):

- `MINE_V1`
- `STRATA_V1`
- `ORE_V1`
- `COLLAPSE_V1`

All derivation uses domain-separated hashing plus Cubit-backed noise rolls, consistent with current world generation architecture.

## 6. Proposed Game Loop

1. Player discovers hex and areas as normal.
2. Some areas are deterministic `MineField` areas.
3. Area controller initializes a mine node (`init_mining`) on a discovered mine slot.
4. Area controller grants access (`grant_mine_access`) to selected adventurers.
5. Authorized player starts mining (`start_mining`) and receives activity lock.
6. Each `continue_mining` tick spends energy and accrues unbanked ore.
7. `stabilize_mine` trades personal action efficiency for lower shared collapse pressure.
8. `exit_mine` banks accrued ore and clears lock.
9. Anti-swarm friction increases per-tick energy cost as concurrent miner count increases.
10. If stress exceeds threshold, mine collapses:
- all active shifts are force-settled
- all active miners die (permadeath)
- all unbanked ore is lost
11. Collapsed mines can be reopened only through permissionless energy-funded repair.
12. Once reserve reaches zero, mine becomes permanently depleted and unusable.

## 7. Social Dilemma Mechanics

### 7.1 Core variables

- `active_miners`: current active shift count on mine.
- `mine_stress`: cumulative stress accumulator.
- `collapse_threshold`: deterministic per mine profile.
- `safe_shift_blocks`: deterministic per mine profile.
- `shift_elapsed_blocks`: per-adventurer current shift duration.
- `biome_risk_bp`: biome-derived risk multiplier.
- `rarity_risk_bp`: ore-rarity-derived risk multiplier.

### 7.2 Stress growth model (proposed)

Per settlement/update:

- `density_factor_bp = 10_000 + density_k_bp * (active_miners - 1)^2`
- `overstay_factor_bp = 10_000` while `shift_elapsed <= safe_shift_blocks`
- `overstay_factor_bp = 10_000 + overstay_k_bp * (shift_elapsed - safe_shift_blocks)` after safe window
- `stress_delta = floor(dt_blocks * base_stress_per_block * density_factor_bp * overstay_factor_bp * biome_risk_bp * rarity_risk_bp / 1e16)`

Mine collapse occurs when `mine_stress >= collapse_threshold`.

### 7.3 Yield model (proposed)

- `base_yield_per_block` is deterministic from mine richness.
- `stress_penalty_bp = min(max_stress_penalty_bp, floor(mine_stress * 10_000 / collapse_threshold))`
- `effective_yield_per_block = floor(base_yield_per_block * (10_000 - stress_penalty_bp) / 10_000)`

This creates the intended tension:

- crowding and overstaying increase risk.
- late-stage mining yields worse returns even before collapse.

### 7.4 Stabilization model (proposed)

`stabilize_mine` spends energy and applies:

- immediate stress reduction (`stabilize_flat_reduction`)
- temporary multiplier reduction for subsequent stress deltas (`stabilize_window_blocks`)

Stabilization is always a personal sacrifice (time/energy) for shared future benefit.

### 7.5 Anti-swarm friction (locked)

No hard miner cap is used. Instead each `continue_mining` tick applies:

- `energy_cost_tick = base_tick_energy + ore_energy_weight + depth_energy_weight + swarm_energy_surcharge(active_miners)`
- `swarm_energy_surcharge(n) = floor(swarm_k * (n - 1)^2)`

This is deterministic and scales superlinearly with miner count.

### 7.6 Ore taxonomy and conversion targets (locked)

Mining v1 uses 13 ores across 5 rarity groups, each with ore-specific conversion targets and energy weights:

| Ore | Rarity | Target conversion energy / unit | Tick energy weight |
|---|---|---:|---:|
| Iron | Common | 8 | 1 |
| Copper | Common | 9 | 1 |
| Tin | Common | 10 | 1 |
| Coal | Common | 12 | 2 |
| Silver | Uncommon | 16 | 2 |
| Nickel | Uncommon | 18 | 2 |
| Cobalt | Uncommon | 22 | 3 |
| Gold | Rare | 30 | 3 |
| Titanium | Rare | 36 | 4 |
| Uranium | Rare | 45 | 5 |
| Mithril | Epic | 62 | 5 |
| Adamantite | Epic | 78 | 6 |
| Aetherium | Legendary | 120 | 8 |

Rarity and biome both influence collapse pressure:

- rarer ore profiles have higher `rarity_risk_bp`
- higher-risk biomes add `biome_risk_bp`

Result: high-value mines are intrinsically less stable.

## 8. Data Model Additions (Proposed)

### 8.1 World model extension

`World.HexArea`:

- add `mine_slot_count: u8`
- extend `AreaType` with `MineField`

### 8.2 Mining models

`Mining.MineNode`:

- `mine_key` (key)
- `hex_coordinate`
- `area_id`
- `mine_id`
- `ore_family`
- `depth_tier`
- `richness_bp`
- `remaining_reserve`
- `base_stress_per_block`
- `collapse_threshold`
- `mine_stress`
- `safe_shift_blocks`
- `active_miners`
- `last_update_block`
- `collapsed_until_block`
- `repair_energy_needed`
- `is_depleted`

`Mining.MiningShift`:

- `shift_id` (key, deterministic from adventurer + mine)
- `adventurer_id`
- `mine_key`
- `status` (`Inactive`, `Active`, `Exited`, `Collapsed`, `Completed`)
- `start_block`
- `last_settle_block`
- `accrued_ore_unbanked`
- `accrued_stabilization_work`

`Mining.MineAccessGrant`:

- key tuple `(mine_key, grantee_adventurer_id)`
- `is_allowed`
- `granted_by_adventurer_id`
- `grant_block`
- `revoked_block`

`Mining.MineCollapseRecord`:

- `mine_key` (key)
- `collapse_count`
- `last_collapse_block`
- `trigger_stress`
- `trigger_active_miners`

## 9. System API (Proposed)

`MiningManager` external entrypoints:

- `init_mining(hex_coordinate, area_id, mine_id) -> bool`
- `grant_mine_access(controller_adventurer_id, mine_key, grantee_adventurer_id) -> bool`
- `revoke_mine_access(controller_adventurer_id, mine_key, grantee_adventurer_id) -> bool`
- `start_mining(adventurer_id, hex_coordinate, area_id, mine_id) -> bool`
- `continue_mining(adventurer_id, mine_key) -> mined_ore`
- `stabilize_mine(adventurer_id, mine_key) -> stress_reduced`
- `exit_mining(adventurer_id, mine_key) -> banked_ore`
- `repair_mine(adventurer_id, mine_key, energy_amount) -> remaining_repair_energy`
- `inspect_mine(hex_coordinate, area_id, mine_id) -> MineView`

Guard requirements on every state-changing action:

- adventurer exists
- adventurer is alive
- caller controls adventurer
- adventurer located on mine hex
- activity lock/state allows requested action
- access rule for mining actions: `is_controller(adventurer, area)` OR active access grant on `mine_key`
- controller-only for grant/revoke calls

## 10. Event Contract (Proposed)

- `MineInitialized`
- `MineAccessGranted`
- `MineAccessRevoked`
- `MiningStarted`
- `MiningContinued`
- `MineStabilized`
- `MiningExited`
- `MineCollapsed`
- `MineRepaired`
- `MiningRejected`

Event assertions should include both:

- payload correctness
- selector cardinality (exact counts in integration scenarios)

## 11. Security and Fairness Invariants

- No player can alter another player’s adventurer or shift state.
- `active_miners` equals count of active shifts for mine at all times.
- `remaining_reserve` never negative.
- `mine_stress` monotonic except explicit stabilization reductions.
- Collapse can only trigger once per threshold crossing and updates are idempotent on replay block.
- Collapse settlement kills all active miners deterministically (`death_cause = MINE_COLLAPSE`).
- Collapse settlement clears all unbanked ore for affected active shifts.
- Dead adventurer settlement releases or resolves any active mining shift deterministically.
- Access check is enforced on every mining action; controller grant/revoke is the only authorization path.
- Ownership/claim transfer of area does not mutate already-active shifts in-progress.
- Depleted mines are terminal and cannot be reopened by repair.
- Claim/ownership changes cannot transfer adventurer control; only area ownership changes.

## 12. TDD Plan (Mandatory Red-Green-Refactor)

No production mining code may be merged without a failing test first.

## MIN0 - Spec + Decision Lock

RED tests:

- compile-level expectation tests for proposed enums/models/signatures.

GREEN:

- finalize doc + decision lock; no implementation yet.

Exit gate:

- unresolved behavior questions answered and reflected in this document.

## MIN1 - Pure Deterministic Generation

Files:

- `src/libs/mining_rng.cairo`
- `src/libs/mining_gen.cairo`

RED tests:

- same inputs => same mine profile
- domain separation changes outputs
- output bounds (`mine_slot_count`, thresholds, richness) are valid

GREEN:

- minimal derivation helpers passing tests.

Exit gate:

- deterministic reproducibility and bounds proven.

## MIN2 - Models + Transition Math

Files:

- `src/models/mining.cairo`
- `src/libs/mining_math.cairo`

RED tests:

- stress delta monotonicity with miner count
- overstay penalty onset exactly at safe boundary
- stabilization cannot underflow stress
- collapse threshold crossing behavior
- reserve and accrued yield conservation invariants
- anti-swarm energy surcharge monotonicity
- biome and rarity risk multipliers increase collapse pressure as configured

GREEN:

- minimal pure transitions for start/continue/stabilize/exit/collapse.

Exit gate:

- all model invariants pass.

## MIN3 - Contract Wiring + Guards

Files:

- `src/systems/mining_manager.cairo`
- `src/systems/mining_manager_contract.cairo`
- `src/events/mining_events.cairo`

RED tests:

- not-owner, dead, wrong-hex, and invalid-area guards
- replay-safe `init_mining`
- one-active-shift-per-adventurer
- no cross-adventurer shift mutation
- non-controller cannot grant or revoke mine access
- non-granted adventurer cannot start/continue mining

GREEN:

- contract wiring with rejection events and minimal writes.

Exit gate:

- full guard matrix green.

## MIN4 - Collapse Lifecycle

RED tests:

- multi-miner pressure collapses deterministically
- collapse settlement handles all active shifts exactly once
- collapse settlement marks active miners dead with `MINE_COLLAPSE`
- repair gating blocks re-entry correctly until repair threshold met
- post-repair re-entry works if mine not depleted

GREEN:

- collapse and settlement path implemented.

Exit gate:

- collapse edge-case suite green.

## MIN5 - Economy Integration

RED tests:

- mined ore mints deterministic item id/type
- `convert_items_to_energy` supports ore items with correct rates
- conversion window penalties still bounded and deterministic
- ore-specific conversion rates follow the 13-ore table

GREEN:

- minimal ore conversion wiring.

Exit gate:

- end-to-end mine -> convert path green.

## MIN6 - Integration + Event Hardening

Integration tests:

- `e2e_discover_mine_convert_maintain`
- `e2e_multiplayer_mine_stabilize_vs_greed`
- `e2e_collapse_and_recovery`
- `e2e_permadeath_during_active_mining`
- `e2e_controller_grants_and_revokes_mine_access`

Event requirements:

- payload assertions for mining lifecycle events
- selector cardinality assertions (exact counts per scenario)

Exit gate:

- integration suite green with event strictness.

## MIN7 - Live Simulation and Ops

Artifacts:

- `game/sim/live_katana_mining_sim.sh`
- extension to `game/sim/live_katana_full_sim.sh`

Required live scenarios:

- 5 adventurers mine same node greedily -> collapse
- 5 adventurers split stabilize/continue strategy -> delayed or avoided collapse
- controller grant/revoke access gates mine entry as expected
- ownership, death, claim interactions do not break mining invariants

Exit gate:

- live script reports zero FAIL lines for mining scenarios.

## 13. Implementation Checklist

- Add mining model/event/system modules and register in `lib.cairo`.
- Add Dojo resource declarations for new models/events/contracts.
- Extend area generation with deterministic mine capacity fields.
- Add mine ACL grant/revoke storage and controller authorization checks.
- Add ore item taxonomy and conversion table wiring for all 13 ores.
- Add migration for new models and ensure backward-safe defaults.
- Add focused `snforge` unit/integration suites.
- Add and run local live simulation script on Katana.

## 14. Risks and Mitigations

- Risk: collapse math too punitive, forcing non-play.
- Mitigation: bounded stress and tuned coefficients, plus deterministic simulation sweeps.

- Risk: griefing via miner swarms.
- Mitigation: one-active-shift-per-adventurer, anti-swarm energy surcharge, and fast collapse penalties that punish swarm participants.

- Risk: controller lockout abuse (access never granted/revoked aggressively).
- Mitigation: explicitly intentional governance surface; test ACL invariants and event transparency for grant/revoke.

- Risk: event/index drift under complex settlement.
- Mitigation: selector cardinality assertions in integration and live scripts.

- Risk: generation drift between discovery and runtime checks.
- Mitigation: derive-once store fields (`mine_slot_count`, profile constants) and enforce same values at entrypoints.

## 15. Owner Decisions Locked

The following decisions are now locked for mining v1:

1. Mines use a new `AreaType::MineField`.
2. Each mineable area has multiple deterministic `mine_id` slots.
3. Collapse destroys all unbanked ore from active shifts.
4. Collapse kills active miners (permadeath).
5. Collapsed mines reopen via explicit repair funded by energy.
6. Repair is permissionless.
7. Area controller has mine access authority and can grant/revoke others.
8. Miner concurrency uses a soft-cap model only (risk/friction), no hard cap.
9. `continue_mining` consumes energy on each call.
10. Mining is hard-locked; no movement during mining; collapse deaths occur in-lock.
11. Ores use ore-specific rates with 13 ores across 5 rarity groups.
12. Mine depletion is permanent.
13. Claim/ownership transfer changes ownership only and does not mutate active shifts.
14. Collapse behavior is biome-specific and more punishing for rarer minerals.
15. v1 includes anti-swarm friction.

## 16. Numeric and ACL Locks (Final)

1. Deterministic `mine_slot_count` bounds per `MineField` area are `1..=8`.
2. Anti-swarm surcharge constant is `swarm_k = 2` in `swarm_k * (n - 1)^2`.
3. Repair baseline is `repair_energy_needed = floor(collapse_threshold * 30%)`.
4. ACL grant granularity is per `mine_key`.
