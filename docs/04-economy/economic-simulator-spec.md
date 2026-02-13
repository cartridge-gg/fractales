# Economic Simulator Spec (10k Adventurers)

## 1. Purpose

Define a high-fidelity, off-chain economic simulator that models the MVP loop at scale (10,000 adventurers) and answers:

1. Does the current source/sink mix stabilize energy and territory ownership over time?
2. Where do bottlenecks or runaway effects appear (energy caps, decay, claim dynamics)?
3. Which balance parameters most strongly affect retention, churn, and territorial turnover?

This spec is implementation-ready and aligned to the current MVP contract behavior.

## 2. Scope

In scope:

- 10,000 adventurers running autonomous policies.
- Infinite-hex exploration abstraction with deterministic biome generation.
- Harvest -> convert -> maintain -> decay -> claim/defend cycle.
- Energy economy accounting (available, reserves, locked escrows, spent).
- KPI time-series and scenario sweeps.

Out of scope:

- Mining/crafting/buildings/hooks/AI services (post-MVP).
- On-chain execution or proving.
- UI gameplay rendering.

## 3. Canonical Behavior Source

Simulator equations and transitions must mirror:

- `docs/02-spec/mvp-functional-spec.md`
- `docs/02-spec/design-decisions.md`
- `game/src/systems/world_manager_contract.cairo`
- `game/src/systems/harvesting_manager_contract.cairo`
- `game/src/systems/economic_manager_contract.cairo`
- `game/src/systems/adventurer_manager.cairo`
- `game/src/libs/conversion_math.cairo`
- `game/src/libs/decay_math.cairo`

## 4. Fidelity Modes

The simulator must support two explicit fidelity modes.

`code_exact` (default):

- Mirrors current contract behavior exactly, including known quirks.
- Lazy regen applied only through `consume_transition` call sites (not world move/discover paths).
- Conversion burns items even when adventurer energy is already at cap.
- Claim refund paths can raise adventurer energy above `max_energy`.
- Plant `regrowth_rate` exists but no periodic regrowth logic is applied.

`design_intended` (optional comparative mode):

- Applies expected design behavior where it diverges from current code.
- Used only for "what-if" comparison, never as baseline truth.

## 5. Simulation Model

### 5.1 Entities

Adventurer:

- `adventurer_id`
- `strategy`
- `is_alive`
- `energy`, `max_energy`
- `current_hex`
- `activity_locked_until`
- `inventory_weight`, `inventory_capacity`
- `inventory_items[item_id]`
- `economics`: `total_energy_spent`, `total_energy_earned`, `last_regen_block`

Hex:

- `hex_coordinate`
- `biome`
- `area_count`
- `controller_adventurer_id`
- `decay_state`: `reserve`, `decay_level`, `last_decay_processed_block`, `claimable_since_block`
- `areas[]` ownership rows (single-controller per hex)
- `plants[]` (initialized on-demand)

Plant:

- `plant_key`, `species`
- `current_yield`, `reserved_yield`, `max_yield`
- `regrowth_rate` (stored, not applied in `code_exact`)
- `health`, `stress_level`

Claim Escrow:

- `claim_id`, `hex_coordinate`, `claimant_id`
- `energy_locked`, `created_block`, `expiry_block`, `status`

### 5.2 Time Model

- Block-based discrete event simulation.
- Global `block_number`.
- Adventurers act when `block_number >= next_action_block`.
- Decay windows processed at `DECAY_PERIOD_BLOCKS` boundaries or on demand per action path.

### 5.3 Engine

Event-driven scheduler:

- Min-heap keyed by `next_action_block`.
- Pop due adventurers, execute one policy action, enqueue next timestamp.
- Periodic background pass each `100` blocks:
  - decay processing on active controlled hexes
  - KPI snapshot emission

Target scale:

- `N = 10,000` adventurers
- `T = 50,000` to `200,000` simulated blocks (configurable)

## 6. Economic Constants (Baseline)

Use code defaults unless scenario overrides:

- `ENERGY_PER_HEX_MOVE = 15`
- `ENERGY_PER_EXPLORE = 25`
- `ENERGY_REGEN_PER_100_BLOCKS = 20`
- `HARVEST_ENERGY_PER_UNIT = 10`
- `HARVEST_TIME_PER_UNIT = 2`
- `CONVERSION_WINDOW_BLOCKS = 100`
- Volume penalty:
  - `penalty_bp = min(5000, floor(units_in_window / 10) * 100)`
- Upkeep per biome:
  - plains `25`, forest `35`, mountain `45`, desert `55`, swamp `65`
- `DECAY_PERIOD_BLOCKS = 100`
- `CLAIMABLE_DECAY_THRESHOLD = 80`
- `CLAIM_TIMEOUT_BLOCKS = 100`
- `CLAIM_GRACE_BLOCKS = 500`
- `DECAY_RECOVERY_BP = 20`

## 7. Required Transition Equations

Implement exact formulas for:

1. Lazy regen:
- `gain = floor((now - last_regen_block) * regen_per_100 / 100)`, cap at `max_energy`.

2. Harvest start/complete/cancel:
- Reserve-yield safety invariant:
  - `0 <= reserved_yield <= current_yield <= max_yield`

3. Conversion:
- Effective rate from rolling window penalty.
- Item burn and inventory weight reduction.

4. Maintenance:
- Spend from adventurer, add to hex reserve, bounded decay recovery.

5. Decay:
- Process only newly elapsed full windows.
- Deficit increases decay up to 100.
- Threshold crossing sets `claimable_since_block`.

6. Claim initiation:
- Immediate escrow lock.
- Pending vs immediate claim based on grace elapsed.

7. Defend / expiry:
- Defender spend + claimant refund on defend.
- Expiry when `now > expiry_block`.

## 8. Adventurer Policy Layer

Initial policy mix (configurable):

- Explorer-Operators: 40%
- Harvester-Maintainers: 35%
- Raiders-Claimants: 15%
- Passive Holders: 10%

Policy primitives:

- explore adjacent hex
- discover control area
- move to owned/work hex
- init/start/complete harvest
- convert inventory to energy
- pay maintenance on controlled hexes
- initiate claims on high-decay competitor hexes
- defend owned claim-under-attack hexes

Each policy uses utility scoring with bounded rationality and local info.

## 9. Metrics and Outputs

### 9.1 Time-Series (every 100 blocks)

- total adventurer energy
- total hex reserve energy
- total locked escrow energy
- energy minted by source:
  - regen
  - conversion
  - refunds
- energy spent by sink:
  - move/explore
  - harvest start
  - maintenance/defense
  - decay burn
  - claim consumption
- claimable hex count
- active escrow count
- ownership transfer count
- defended vs claimed outcomes

### 9.2 End-of-Run KPIs

- sink/source ratio
- median and p95 time-to-claimable for owned hexes
- territory churn rate
- controller concentration (Gini/HHI)
- % adventurers energy-starved (`energy < move+explore cost`)
- % adventurers above max energy (`code_exact` diagnostic)

### 9.3 Artifacts

- `run_summary.json`
- `timeseries.csv`
- `scenario_comparison.csv`
- `invariant_report.json`

## 10. Scenario Matrix

Minimum scenario suite:

1. Baseline-10k (default constants)
2. No-raider control (raider population = 0%)
3. Raider-heavy (raider population = 35%)
4. Regen-low (`10/100`) sensitivity
5. Regen-high (`30/100`) sensitivity
6. Upkeep+20% stress
7. Conversion penalty disabled (counterfactual)
8. Claim grace shorter (`250`) and longer (`1000`)

Each scenario runs with fixed seed set (`S = 20`) for confidence bands.

## 11. Invariants and Validation

### 11.1 Hard Invariants

- no negative energy
- no negative inventory weight
- `reserved_yield <= current_yield`
- escrow refunded at most once
- ownership rows in a hex share one controller

### 11.2 Golden Path Checks

Simulator must reproduce key contract test behaviors:

- E2E discover/harvest/convert/maintain energy arithmetic
- claim pending + defend refund lifecycle
- expiry at `now > expiry_block`, not `>=`
- decay idempotency in same processed window

## 12. Performance Targets

On a typical dev laptop:

- Baseline-10k, 50k blocks, 1 seed:
  - wall time <= 60s
  - memory <= 2 GB

Use deterministic seeds and stable ordering for reproducibility.

## 13. Implementation Plan

Phase A:

- Build deterministic transition core with unit tests per formula.

Phase B:

- Add event scheduler and 1,000-adventurer dry run.

Phase C:

- Scale to 10,000 adventurers; optimize hotspots.

Phase D:

- Add scenario runner + aggregate reports.

Phase E:

- Calibrate against on-chain integration tests and adjust fidelity gaps.

## 14. Open Decisions

1. Should baseline remain strictly `code_exact`, with `design_intended` only as comparison?
2. Should we model exogenous death events now, or defer until combat/hazards exist in MVP?
3. Should controller strategies include deliberate abandonment/reclaim behavior in baseline?

