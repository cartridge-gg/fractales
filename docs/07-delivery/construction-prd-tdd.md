# Construction PRD + TDD (Post-MVP Module)

## 1. Goal

Implement a deterministic construction module that converts ore + plant outputs into persistent hex infrastructure with upkeep and claim/defend integration.

This PRD is implementation-facing and uses the tuned balance envelope from:

- `07-delivery/construction-balance-scope.md`
- `04-economy/tools/construction_balance_config.v1.json`

## 2. Locked v1 Balance Inputs

Seven building types are in scope:

- `SMELTER`
- `SHORING_RIG`
- `GREENHOUSE`
- `HERBAL_PRESS`
- `WORKSHOP`
- `STOREHOUSE`
- `WATCHTOWER`

Tuned recipes/stakes/upkeep/effect parameters are locked to the simulator config for v1 coding.

## 3. Current Implementation Status

Completed:

- Construction balance constants + mapping library in game code:
  - `game/src/libs/construction_balance.cairo`
- Unit tests for tuned constants/recipes/capex/effects:
  - `game/src/tests/unit/construction_balance_test.cairo`
- Slice C1 models and deterministic helpers:
  - `game/src/models/construction.cairo`
  - `game/src/tests/unit/construction_models_test.cairo`
- Slice C2 pure transition logic (start/complete/upkeep/checkpoint/repair-reactivate):
  - `game/src/systems/construction_manager.cairo`
  - `game/src/tests/unit/construction_manager_test.cairo`
- Slice C3 contract + events API surface:
  - `game/src/events/construction_events.cairo`
  - `game/src/systems/construction_manager_contract.cairo`
  - `game/src/tests/unit/construction_events_test.cairo`
  - `game/src/tests/integration/construction_manager_integration_test.cairo`
- Slice C4 plumbing (phase A: active-building bonus wiring):
  - `game/src/systems/economic_manager_contract.cairo`
  - `game/src/systems/economic_manager.cairo`
  - `game/src/systems/mining_manager_contract.cairo`
  - `game/src/systems/mining_manager.cairo`
  - `game/src/tests/integration/economic_manager_integration_test.cairo`
  - `game/src/tests/integration/mining_manager_integration_test.cairo`
  - `game/src/tests/unit/mining_manager_test.cairo`
- Slice C4 plumbing (phase B: remaining building effects + balance assertions):
  - `game/src/systems/construction_manager_contract.cairo` (`WORKSHOP` stake/time reduction on active hex)
  - `game/src/systems/harvesting_manager_contract.cairo` (`GREENHOUSE` bonus mint + `STOREHOUSE` capacity uplift)
  - `game/src/systems/mining_manager_contract.cairo` (`STOREHOUSE` capacity uplift on `exit_mining`)
  - `game/src/tests/integration/construction_manager_integration_test.cairo`
  - `game/src/tests/integration/harvesting_manager_integration_test.cairo`
  - `game/src/tests/integration/mining_manager_integration_test.cairo`
- Slice C5 dedicated E2E coverage:
  - `game/src/tests/integration/e2e_mine_build_convert.cairo`
  - `game/src/tests/integration/e2e_harvest_process_build.cairo`
  - `game/src/tests/integration/e2e_claim_transfer_buildings.cairo`
- Test wiring in:
  - `game/src/lib.cairo`
  - `game/src/models.cairo`
  - `game/src/systems.cairo`
  - `game/src/events.cairo`

Validated with:

```bash
cd game
snforge test construction_
snforge test e2e_07_mine_build_convert_progression_applies_smelter_bonus
snforge test e2e_08_harvest_process_build_progression_applies_greenhouse_and_storehouse
snforge test e2e_09_claim_transfer_keeps_building_ownership_coherent
snforge test
```

## 4. Build Slices (TDD Order)

### Slice C1: Construction Models

Add deterministic storage models and IDs.

Files:

- `game/src/models/construction.cairo` (new)
- `game/src/models.cairo` (register module)
- `game/src/lib.cairo` (register unit tests)
- `game/src/tests/unit/construction_models_test.cairo` (new)

Models:

- `ConstructionBuildingNode`
- `ConstructionProject`
- `ConstructionMaterialEscrow`
- project/build status enums

### Slice C2: Pure Transition Logic

Add stateless transition helpers before contract wiring.

Files:

- `game/src/systems/construction_manager.cairo` (new)
- `game/src/tests/unit/construction_manager_test.cairo` (new)

Functions:

- start project transition (preconditions + escrow lock)
- complete project transition (time gate + settle)
- upkeep + deterioration transition
- repair/reactivation transition

### Slice C3: Contract + Events

Add callable entrypoints and event emission.

Files:

- `game/src/events/construction_events.cairo` (new)
- `game/src/events.cairo` (register)
- `game/src/systems/construction_manager_contract.cairo` (new)
- `game/src/systems.cairo` (register)

External API:

- `process_plant_material`
- `start_construction`
- `complete_construction`
- `pay_building_upkeep`
- `repair_building`
- `upgrade_building`
- `inspect_building`

### Slice C4: Economic + Claim/Defend Plumbing

Wire bonuses into existing systems with caps.

Files:

- `game/src/systems/economic_manager.cairo`
- `game/src/systems/economic_manager_contract.cairo`
- `game/src/systems/mining_manager.cairo`
- `game/src/systems/mining_manager_contract.cairo`

Rules:

- bonuses only apply when building is active
- transfer of building ownership follows claim/defend owner resolution
- no mixed-owner state in one hex

### Slice C5: Integration + E2E

Files:

- `game/src/tests/integration/construction_manager_integration_test.cairo` (new)
- `game/src/tests/integration/e2e_mine_build_convert.cairo` (new)
- `game/src/tests/integration/e2e_harvest_process_build.cairo` (new)
- `game/src/tests/integration/e2e_claim_transfer_buildings.cairo` (new)

## 5. Acceptance Criteria (v1)

1. Building recipes and capex match tuned balance constants exactly.
2. Start/complete/upkeep/repair transitions are deterministic and replay-safe.
3. Inactive buildings apply zero bonus.
4. Claim transfer updates building ownership coherently.
5. No negative inventory/energy under tested interleavings.
6. Simulator thresholds pass and onchain constants remain in sync.

## 6. Sync Rule (Critical)

When recipe/effect constants change in code, update both:

- `game/src/libs/construction_balance.cairo`
- `04-economy/tools/construction_balance_config.v1.json`

Then re-run:

```bash
python3 04-economy/tools/construction_balance_sim.py --check
cd game && snforge test construction_balance
```

## 7. Immediate Next Task

Begin post-C5 hardening:

- add stricter event-cardinality assertions to the new E2E paths
- add one negative E2E assertion proving inactive buildings yield no bonus in each loop
- decide whether to formalize construction material escrow consumption in `start_construction`
