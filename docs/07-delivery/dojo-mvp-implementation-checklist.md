# Dojo MVP Implementation Checklist

This checklist operationalizes `docs/07-delivery/dojo-mvp-prd.md` into executable implementation steps.

Canonical references:
- `docs/02-spec/mvp-functional-spec.md`
- `docs/02-spec/design-decisions.md`
- `docs/07-delivery/dojo-mvp-prd.md`

## Usage Rules

- Build in order: `M0 -> M4` then `S1 -> S5`.
- Do not start a stage until previous stage exit gates are green.
- Keep contracts domain-focused; split when cohesion drops.
- Add/adjust tests with every model/system change.

## 0. Repository Preparation

- [ ] Verify docs lock-in before coding:
- [ ] Read `docs/02-spec/design-decisions.md`.
- [ ] Read `docs/02-spec/mvp-functional-spec.md`.
- [ ] Confirm contract boundaries in `docs/07-delivery/dojo-mvp-prd.md`.
- [ ] Create target source tree under `game/src/`:
- [ ] `models/`
- [ ] `systems/`
- [ ] `libs/`
- [ ] `events/`
- [ ] `tests/unit/`
- [ ] `tests/integration/`
- [ ] `tests/fixtures/`

## 1. Model-First Checklist

## M0 - Shared Types, Codec, and Math

Target files:
- `game/src/libs/coord_codec.cairo`
- `game/src/libs/math_bp.cairo`
- `game/src/libs/adjacency.cairo`
- `game/src/libs/mod.cairo`
- `game/src/lib.cairo`

Implementation:
- [ ] Define cube coordinate struct `(x, y, z)` and invariant helper (`x + y + z == 0`).
- [ ] Implement felt encode/decode functions for cube coordinates.
- [ ] Implement round-trip-safe codec tests.
- [ ] Implement basis-point helpers (`mul_bp_floor`, `div_floor`, clamp helpers).
- [ ] Implement cube neighbor/adjacency helpers (6-direction movement).

Unit tests (add first):
- [ ] `game/src/tests/unit/coord_codec_test.cairo`
- [ ] `game/src/tests/unit/math_bp_test.cairo`
- [ ] `game/src/tests/unit/adjacency_test.cairo`

Exit gate:
- [ ] Codec round-trip tests green.
- [ ] Adjacency tests green.
- [ ] Basis-point floor semantics tests green.

## M1 - World and Discovery Models

Target files:
- `game/src/models/world.cairo`
- `game/src/models/mod.cairo`
- `game/src/events/world_events.cairo`
- `game/src/events/mod.cairo`

Models:
- [ ] `World.Hex`
- [ ] `World.HexArea`

Implementation:
- [ ] Add model fields from MVP spec exactly.
- [ ] Add helper keys/derivations for deterministic area IDs.
- [ ] Add immutability guards for first discoverer metadata.

Unit tests:
- [ ] `game/src/tests/unit/world_models_test.cairo`
- [ ] Verify idempotent discover writes.
- [ ] Verify duplicate discover attempts do not mutate immutable fields.

Exit gate:
- [ ] All world model invariants tested and green.

## M2 - Adventurer, Inventory, Death Models

Target files:
- `game/src/models/adventurer.cairo`
- `game/src/models/inventory.cairo`
- `game/src/models/deaths.cairo`
- `game/src/events/adventurer_events.cairo`

Models:
- [ ] `Adventurer.Adventurer`
- [ ] `Adventurer.Inventory`
- [ ] `Adventurer.BackpackItem`
- [ ] `Adventurer.DeathRecord`

Implementation:
- [ ] Define alive/dead state model.
- [ ] Define inventory weight and item stack fields.
- [ ] Define death record payload fields and storage semantics.

Unit tests:
- [ ] `game/src/tests/unit/adventurer_models_test.cairo`
- [ ] `game/src/tests/unit/inventory_models_test.cairo`
- [ ] `game/src/tests/unit/death_models_test.cairo`
- [ ] Verify alive -> dead monotonicity.
- [ ] Verify death inventory loss hash behavior.

Exit gate:
- [ ] Permadeath model invariants green.
- [ ] Inventory model bounds/integrity tests green.

## M3 - Harvesting Models

Target files:
- `game/src/models/harvesting.cairo`
- `game/src/libs/harvesting_math.cairo`
- `game/src/events/harvesting_events.cairo`

Models:
- [ ] `Harvesting.PlantNode`

Implementation:
- [ ] Implement plant yield/regrowth/stress/health fields.
- [ ] Implement bounded update math in harvesting lib.
- [ ] Enforce `[0, max_yield]` and stress/health bounds.

Unit tests:
- [ ] `game/src/tests/unit/harvesting_models_test.cairo`
- [ ] `game/src/tests/unit/harvesting_math_test.cairo`
- [ ] Verify no underflow/overflow in yield transitions.
- [ ] Verify stress and health bounds after complete/cancel paths.

Exit gate:
- [ ] Harvesting model/math tests green.

## M4 - Economics and Ownership Models

Target files:
- `game/src/models/economics.cairo`
- `game/src/models/ownership.cairo`
- `game/src/libs/decay_math.cairo`
- `game/src/libs/conversion_math.cairo`
- `game/src/events/economic_events.cairo`
- `game/src/events/ownership_events.cairo`

Models:
- [ ] `Economics.AdventurerEconomics`
- [ ] `Economics.ConversionRate`
- [ ] `Economics.HexDecayState`
- [ ] `Ownership.AreaOwnership`

Implementation:
- [ ] Implement conversion-rate model fields.
- [ ] Implement decay-state model fields.
- [ ] Implement ownership transfer state fields (MVP parity model).

Unit tests:
- [ ] `game/src/tests/unit/economics_models_test.cairo`
- [ ] `game/src/tests/unit/ownership_models_test.cairo`
- [ ] `game/src/tests/unit/decay_math_test.cairo`
- [ ] `game/src/tests/unit/conversion_math_test.cairo`
- [ ] Verify decay monotonicity under deficit.
- [ ] Verify ownership transfer invariants.

Exit gate:
- [ ] Economics and ownership model tests green.

## 2. System Checklist

## S1 - WorldManager

Target files:
- `game/src/systems/world_manager.cairo`

Entry points:
- [ ] `discover_hex`
- [ ] `discover_area`
- [ ] `move_adventurer`

Implementation:
- [ ] Enforce cube adjacency via `libs/adjacency.cairo`.
- [ ] Enforce discovery idempotency.
- [ ] Emit world events with stable payload shape.

Unit tests:
- [ ] `game/src/tests/unit/world_manager_test.cairo`
- [ ] Adjacent move pass / non-adjacent fail.
- [ ] First discoverer recorded once.

Exit gate:
- [ ] AC-W1 and AC-W2 equivalent tests green.

## S2 - AdventurerManager

Target files:
- `game/src/systems/adventurer_manager.cairo`

Entry points:
- [ ] `create_adventurer`
- [ ] `consume_energy`
- [ ] `regenerate_energy`
- [ ] `kill_adventurer`

Implementation:
- [ ] Spawn at cube origin `(0,0,0)` semantics.
- [ ] Enforce energy non-negative updates.
- [ ] Enforce dead-adventurer action rejection.
- [ ] Emit `AdventurerCreated`, `AdventurerDied`.

Unit tests:
- [ ] `game/src/tests/unit/adventurer_manager_test.cairo`
- [ ] Energy boundary tests.
- [ ] Permadeath irreversibility tests.

Exit gate:
- [ ] AC-A1 equivalent tests green.

## S3 - HarvestingManager

Target files:
- `game/src/systems/harvesting_manager.cairo`

Entry points:
- [ ] `init_harvesting`
- [ ] `start_harvesting`
- [ ] `complete_harvesting`
- [ ] `inspect_plant`

Optional (if included in API now):
- [ ] `check_harvesting_progress`
- [ ] `cancel_harvesting`

Implementation:
- [ ] Enforce IDLE precondition for harvest start.
- [ ] Commit energy at start.
- [ ] Respect time lock for complete.
- [ ] Emit harvesting events.

Unit tests:
- [ ] `game/src/tests/unit/harvesting_manager_test.cairo`
- [ ] Insufficient yield/energy failure paths.
- [ ] Complete/cancel state transitions.

Exit gate:
- [ ] AC-H1 and AC-H2 equivalent tests green.

## S4 - EconomicManager

Target files:
- `game/src/systems/economic_manager.cairo`

Entry points:
- [ ] `convert_items_to_energy`
- [ ] `pay_hex_maintenance`
- [ ] `process_hex_decay`
- [ ] `initiate_hex_claim`
- [ ] `defend_hex_from_claim`

Implementation:
- [ ] Use `conversion_math` and `decay_math` libs only (no inline duplicated formulas).
- [ ] Enforce claim threshold and grace logic.
- [ ] Emit economic and claim events.

Unit tests:
- [ ] `game/src/tests/unit/economic_manager_test.cairo`
- [ ] Conversion boundedness and monotonicity checks.
- [ ] Decay threshold crossing checks.
- [ ] Claim/defend transfer correctness checks.

Exit gate:
- [ ] AC-E1, AC-D1, AC-C1 equivalent tests green.

## S5 - OwnershipManager

Target files:
- `game/src/systems/ownership_manager.cairo`

Entry points:
- [ ] `get_owner`
- [ ] `transfer_ownership` (restricted/admin/test path per MVP)

Implementation:
- [ ] Restrict transfer pathways to allowed call contexts.
- [ ] Maintain ownership consistency with claim/defend outcomes.

Unit tests:
- [ ] `game/src/tests/unit/ownership_manager_test.cairo`
- [ ] Unauthorized transfer rejection.
- [ ] Authorized transfer success and state integrity.

Exit gate:
- [ ] Ownership authorization matrix tests green.

## 3. Integration Checklist

Target files:
- `game/src/tests/integration/e2e_discover_harvest_convert_maintain.cairo`
- `game/src/tests/integration/e2e_decay_claim_defend.cairo`
- `game/src/tests/integration/e2e_permadeath_lockout.cairo`

Flows:
- [ ] E2E-01 Discover -> Area -> Init Harvest -> Start/Complete -> Convert -> Pay Upkeep
- [ ] E2E-02 Neglect -> Decay >= threshold -> Claim -> Defend window behavior
- [ ] E2E-03 Backpack capacity constraints during harvest outcomes
- [ ] E2E-04 Permadeath prevents future actions and activity continuation

Exit gate:
- [ ] All E2E tests green in local Dojo test run.

## 4. Event and Indexing Checklist

Target files:
- `game/src/events/*.cairo`
- integration event assertions in `game/src/tests/integration/`

Checklist:
- [ ] Event names and payloads match MVP spec exactly.
- [ ] Event emissions occur once per state transition.
- [ ] Snapshot tests assert event shape stability.

## 5. Refactor/Size Control Checklist

Run this at end of every stage:
- [ ] Any system doing cross-domain writes beyond its responsibility?
- [ ] Any repeated formula not moved to libs?
- [ ] Any entrypoint with overly broad branching that should split?
- [ ] Any test setup too large due to poor cohesion?
- [ ] `cd game && scarb run perf-budget` passes.
- [ ] `cd game && scarb run size-budget` passes.

If yes:
- [ ] Split file/logic by domain behavior.
- [ ] Re-run affected unit and integration tests.

## 6. Final MVP Signoff Checklist

- [ ] All model stages (`M0-M4`) complete with passing tests.
- [ ] All system stages (`S1-S5`) complete with passing tests.
- [ ] MVP acceptance criteria mapped to tests and passing.
- [ ] Decision-locked behavior reflected in code:
- [ ] Permadeath enabled in MVP.
- [ ] Cube coordinate encoding active.
- [ ] Model-only ownership (no ERC-721 in MVP).
- [ ] Basis-point + floor rounding used consistently.
- [ ] Docs updated for any implementation-level deviations (if any).
