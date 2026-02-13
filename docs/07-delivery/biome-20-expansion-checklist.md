# 20-Biome Expansion Execution Checklist

## PR1: Decision + Spec Lock
- [x] `docs/02-spec/design-decisions.md`: add `DD-024` (20 playable biomes), `DD-025` (deterministic plant slot count + `plant_id` bounds), `DD-026` (data-driven biome profiles), `DD-027` (generation v2 rollout rules).
- [x] `docs/02-spec/mvp-functional-spec.md`: add canonical 20-biome list.
- [x] `docs/02-spec/mvp-functional-spec.md`: add `HexArea.plant_slot_count` model field.
- [x] `docs/02-spec/mvp-functional-spec.md`: add invariant `0 <= plant_id < plant_slot_count` for `init_harvesting`.
- [x] `docs/02-spec/mvp-functional-spec.md`: add biome profile-driven behavior (upkeep, plant-field odds, species tables, slots).

## PR2: Model + Version Scaffolding
- [x] `game/src/models/world.cairo`: expand `Biome` enum from 5+unknown to 20+unknown.
- [x] `game/src/models/world.cairo`: add `plant_slot_count: u8` to `HexArea`.
- [x] `game/src/events/world_events.cairo`: keep event compatibility (no breaking change needed unless slot count is emitted).
- [x] `game/src/systems/world_gen_manager_contract.cairo`: switch active version constant to `2`.
- [x] `game/src/systems/world_gen_manager.cairo`: ensure one-time init behavior unchanged.

## PR3: Generation Refactor (Data-Driven Profiles)
- [x] Add `game/src/libs/biome_profiles.cairo` with all 20 biome configs.
- [x] `game/src/libs/world_gen.cairo`: replace hardcoded `biome_from_roll` with weighted 20-biome selector.
- [x] `game/src/libs/world_gen.cairo`: replace hardcoded `area_type_from_roll` thresholds with profile values.
- [x] `game/src/libs/world_gen.cairo`: replace hardcoded `species_from_roll` with biome species tables.
- [x] `game/src/libs/world_gen.cairo`: derive deterministic `plant_slot_count` in area profile.
- [x] `game/src/libs/world_gen.cairo`: extend `AreaProfile` to include `plant_slot_count`.

## PR4: Runtime Wiring + Guardrails
- [x] `game/src/systems/world_manager_contract.cairo`: persist generated `plant_slot_count` on `discover_area`.
- [x] `game/src/systems/harvesting_manager_contract.cairo`: reject `init_harvesting` when `plant_id >= area.plant_slot_count`.
- [x] `game/src/systems/harvesting_manager.cairo`: add outcome branch/reason for out-of-range plant ID.
- [x] `game/src/libs/decay_math.cairo`: move upkeep mapping to 20-biome profile source (single source of truth).

## PR5: Tests
- [x] `game/src/tests/unit/world_gen_test.cairo`: add deterministic coverage for 20-biome space.
- [x] `game/src/tests/unit/world_gen_test.cairo`: add deterministic `plant_slot_count` bounds assertions.
- [x] `game/src/tests/unit/harvesting_manager_test.cairo`: add regression test for out-of-range `plant_id`.
- [x] `game/src/tests/integration/smoke_generation_pipeline_integration_test.cairo`: assert generated `plant_slot_count` and slot-bounded init.
- [x] `game/src/tests/unit/economic_manager_test.cairo`: add upkeep checks for representative low/mid/high new biomes.
- [x] Keep existing E2E green (`e2e_discover_harvest_convert_maintain`, `e2e_decay_claim_defend`, `e2e_permadeath_lockout`).

## PR6: Balance Calibration
- [x] Define first-pass profile table for all 20 biomes (upkeep tier, plant-field chance, species mix, slot range).
- [x] Add deterministic sampling test/script to validate biome distribution is not degenerate.
- [x] Validate no biome has zero practical spawn share.
- [x] Validate loop economy still works across low- and high-upkeep biomes.

## PR7: Rollout + Docs
- [x] `readme.md`: update biome count and generation/version note.
- [x] `docs/MASTER_DOC.md`: link new biome/profile notes.
- [x] Remove legacy fallback note: harvesting init is v2-only and rejects zero-slot legacy rows.
- [x] Run full test/build pass before merge.

## Merge Gates
- [x] `sozo build` passes.
- [x] `snforge test` passes.
- [x] No failing integration tests related to generation determinism or harvest init guards.
- [x] Docs and code reflect the same biome/version rules.
