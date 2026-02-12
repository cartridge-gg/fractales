# Deterministic Generation Plan (Hex -> Area -> Plant Tree)

## 1. Goal

Move discovery and harvesting content from caller-provided inputs to a deterministic generative pipeline:

- Hex-level generation: biome + area count from coordinate.
- Area-level generation: area type + quality + size from `(hex, area_index)`.
- Plant-level generation: species + yield/regrowth/genetics from `(hex, area_id, plant_id)`.

Primary objective: world content should be reproducible from seed + coordinates, with replay-safe onchain persistence.

## 2. Current Gap

Current entrypoints accept gameplay-defining values from callers:

- `discover_hex(..., biome, area_count)`
- `discover_area(..., area_type, resource_quality, size_category)`
- `init_harvesting(..., species, max_yield, regrowth_rate)`

This allows arbitrary inputs and prevents a coherent fractal world tree from being enforced at protocol level.

## 3. Design Principles

- Deterministic only: outputs depend on seed + coordinates/ids, never caller or block timestamp.
- Domain separation: each derivation step uses explicit hash tags/version tags.
- Lazy materialization: generated values are computed on first discovery/init and persisted.
- Replay immutability: repeated calls return existing values without mutation.
- Version pinning: generation algorithm version is explicit and upgrade-safe.

## 4. Cubit Decision

Reference: https://github.com/influenceth/cubit

Project decision:

- Cubit is the canonical noise backend for deterministic generation.
- Generation APIs and tests are authored against Cubit-derived outputs.
- Domain-separated seed derivation and config versioning still apply to keep behavior stable across upgrades.

## 5. Architecture

### 5.1 New Generation Config Model

Add `WorldGenConfig` (single row):

- `generation_version: u16`
- `global_seed: felt252`
- `biome_scale_bp: u16`
- `area_scale_bp: u16`
- `plant_scale_bp: u16`
- `biome_octaves: u8`
- `area_octaves: u8`
- `plant_octaves: u8`

### 5.2 New Libraries

- `libs/world_rng.cairo`
  - domain-separated seed derivation
  - deterministic bounded ints
  - weighted choice helpers
- `libs/world_noise.cairo`
  - `noise2d` backend interface
  - Cubit-based implementation (canonical)
- `libs/world_gen.cairo`
  - `derive_hex_profile`
  - `derive_area_profile`
  - `derive_plant_profile`

### 5.3 Seed Tree (Domain-Separated)

Example derivation chain:

- `hex_seed = H(global_seed, hex_coordinate, 'HEX_V1')`
- `area_seed = H(hex_seed, area_index, 'AREA_V1')`
- `plant_seed = H(area_seed, plant_id, 'PLANT_V1')`
- `genetics_hash = H(plant_seed, species, 'GENE_V1')`

### 5.4 System API Changes

World:

- `discover_hex(adventurer_id, hex_coordinate)` (remove biome/area_count input)
- `discover_area(adventurer_id, hex_coordinate, area_index)` (remove area payload input)

Harvesting:

- `init_harvesting(hex_coordinate, area_id, plant_id)` (remove caller-supplied plant config)
- Keep `start/complete/cancel/inspect` signatures stable.

Optional read APIs (recommended):

- `preview_hex(hex_coordinate) -> generated hex profile`
- `preview_area(hex_coordinate, area_index) -> generated area profile`
- `preview_plant(hex_coordinate, area_id, plant_id) -> generated plant profile`

## 6. Generation Rules (Initial)

### 6.1 Hex Level

- Biome from low-frequency fractal noise + deterministic thresholds.
- Area count from deterministic bounded mapping, e.g. `3..6`.

### 6.2 Area Level

- `area_index=0` is always `Control` (preserves single-controller semantics).
- Non-control areas derive `AreaType` by biome-weighted selection.
- `resource_quality` derived from noise percentile and clamped (e.g. `30..100`).
- `size_category` from deterministic bins.

### 6.3 Plant Level

- Species determined by biome+area distributions and `plant_seed`.
- `max_yield` and `regrowth_rate` from bounded deterministic curves.
- `genetics_hash` deterministically derived from seed + species.

## 7. Delivery Plan

## G0 - Spec Lock (Docs + Decisions)

- Update MVP spec signatures for world/harvest init to remove caller-defined generation fields.
- Add generation invariants and deterministic tree rules to spec.
- Add/lock a decision entry for Cubit as canonical generation backend.

Exit gate:

- Spec + decision docs updated and internally consistent.

## G1 - Seed/RNG Foundation

- Implement `world_rng` and deterministic derivation tests.
- Add invariant tests for domain separation and reproducibility.

Exit gate:

- Unit tests prove same input -> same output, different domain tag -> different output.

## G2 - Deterministic Hex/Area Discovery

- Wire `discover_hex` and `discover_area` to generated profiles.
- Remove caller-provided biome/area payload from interfaces and tests.

Exit gate:

- Replay semantics unchanged.
- Area identity and ownership invariants unchanged.
- Integration tests green after signature migration.

## G3 - Deterministic Plant Generation

- Wire `init_harvesting` to generated plant profile.
- Ensure generated fields satisfy current harvest invariants (`max_yield > 0`, `regrowth_rate > 0`).

Exit gate:

- Harvest start/complete/cancel tests green with no caller-configurable plant stats.

## G4 - Fractal Tuning on Cubit

- Add parameterized octave/scale settings from `WorldGenConfig`.
- Tune Cubit sampling scales/octaves from `WorldGenConfig`.
- Add bounded output tests for biome/area/plant distributions and quality bands.

Exit gate:

- Cubit-backed generation remains deterministic and production-safe under configured ranges.
- Cubit-backed generation passes deterministic tests and perf budget checks.

## G5 - Migration, Indexing, and Ops

- Migration for changed interfaces/events.
- Torii/event compatibility checks for updated payload behavior.
- Update runbooks with generation config initialization.

Exit gate:

- Full integration suite + indexing checks green.

## 8. Edge Cases to Explicitly Test

- Invalid coordinate decode -> no mutation.
- Extreme coordinate magnitudes do not overflow generation math.
- `area_count` bounds always valid and non-zero.
- `area_index=0` control rule remains enforced.
- Replay calls never mutate generated attributes.
- Plant generation always returns valid harvest config.
- Deterministic outputs are independent of caller and block number.
- Generation version changes do not mutate already-discovered rows.
- Cubit determinism safety: identical seed/config inputs produce identical outputs across replays/reruns.

## 9. Performance/Size Controls

Use existing P2.2 gates:

- `cd game && scarb run perf-budget`
- `cd game && scarb run size-budget`

Additional gates for this work:

- Add targeted gas assertions for generated `discover_hex`, `discover_area`, and `init_harvesting`.
- Keep noise octaves bounded (start with low octaves; increase only if budgets allow).

## 10. Recommended Execution Order

1. G0 spec + decision lock
2. G1 RNG foundation + tests
3. G2 world discovery migration
4. G3 harvest generation migration
5. G4 Cubit tuning + benchmarking
6. G5 ops/indexing completion

This order minimizes risk by locking behavior first, then replacing world generation, then replacing harvest initialization, while preserving current economic/death/ownership invariants.
