# Gen Dungeon Explorer TDD Plan

Status: Draft
Last updated: 2026-02-13

## 1. TDD Operating Rule

No production code is written before a failing test exists for the intended behavior.
Every story follows RED -> GREEN -> REFACTOR.

Definition in this plan:
- RED: add one failing behavior test
- GREEN: implement minimal code to pass that test
- REFACTOR: cleanup only with tests green

## 2. Scope Under Test

Packages:
- `@gen-dungeon/explorer-types`
- `@gen-dungeon/torii-views`
- `@gen-dungeon/explorer-data`
- `@gen-dungeon/explorer-renderer-webgl`
- `@gen-dungeon/explorer-app`
- Node proxy service used by explorer-data

Canonical type contract:
- `../client/typescript/models.gen.ts`

## 3. Test Stack (Proposed)

Unit and contract tests:
- `vitest`

Integration tests (proxy + sql + ws):
- `vitest` + ephemeral db fixture + ws harness

Browser E2E:
- `playwright`

Render verification:
- deterministic framebuffer hash snapshots for selected scenes

Performance harness:
- scripted camera path benchmark producing FPS and frame-time stats

## 4. Stage Order and Gates

1. `T0` Harness + Contracts
2. `T1` Torii Views Package
3. `T2` Proxy + Data Store
4. `T3` WebGL Renderer
5. `T4` App Shell + End-to-End
6. `T5` Performance and Reliability Hardening

No stage advances without green exit tests for that stage.

## 5. T0 - Harness + Contract Baseline

RED tests to write first:
- generated model contract parity test fails when expected fields are missing in explorer DTOs
- websocket envelope schema decode test fails for missing ordering fields
- chunk key codec test fails for unsupported coordinate edge cases

GREEN implementation targets:
- base test utilities
- typed fixtures from generated models
- schema validator for proxy envelopes

Exit gate:
- all parity and envelope contract tests pass

## 6. T1 - `@gen-dungeon/torii-views`

### 6.1 RED tests

- `views.hex_render.returns_discovered_rows_only.red`
- `views.hex_inspect.includes_all_joined_fields.red`
- `views.owner_lookup.resolves_controller_consistently.red`
- `views.claim_active.filters_expired_escrow.red`
- `views.event_tail.orders_by_block_tx_event.red`
- `views.schema_parity.detects_model_drift.red`

### 6.2 GREEN implementation

- create logical view definitions v1
- create physical mapping config for Torii table names
- add seed dataset fixtures mirroring game model semantics
- add validation script that checks required columns against generated model contracts

### 6.3 REFACTOR

- remove duplicate select fragments via SQL templates
- centralize shared filters in view helper macros

### 6.4 Exit gate

- view tests pass on seeded db
- schema parity test passes
- query plans meet agreed index usage checks

## 7. T2 - Node Proxy + `@gen-dungeon/explorer-data`

### 7.1 RED tests

Proxy:
- `chunks.endpoint.rejects_oversized_keyset.red`
- `chunks.endpoint.returns_stable_schema.red`
- `hex.endpoint.includes_complete_inspect_payload.red`
- `search.endpoint.coord_owner_adventurer_modes.red`
- `ws.stream.sequence_monotonicity.red`
- `ws.stream.emits_resync_required_on_gap.red`

Data package:
- `apply_patch.orders_by_sequence_block_tx_event.red`
- `apply_patch.idempotent_for_duplicate_sequence.red`
- `reconnect.triggers_snapshot_resync.red`
- `chunk_cache.evicts_lru_respecting_pin.red`
- `selectors.visible_hexes_respect_layer_filters.red`

### 7.2 GREEN implementation

- implement HTTP handlers and ws stream in proxy
- implement ordered patch reducer in explorer-data
- implement chunk cache budget behavior for mobile/desktop defaults
- implement selectors for render and inspect models

### 7.3 REFACTOR

- isolate transport adapters from store logic
- isolate cache policy from query selectors

### 7.4 Exit gate

- proxy contract tests pass
- reducer determinism tests pass
- reconnect/resync flow verified in integration test

## 8. T3 - `@gen-dungeon/explorer-renderer-webgl`

### 8.1 RED tests

- `camera.top_down_pan_zoom_only.red`
- `chunk_culling.includes_prefetch_ring.red`
- `picking.id_buffer_returns_correct_hex.red`
- `overlay.biome_mode_maps_expected_symbols.red`
- `overlay.claim_mode_prioritizes_active_claim.red`
- `ascii.glyph_atlas_renders_expected_codes.red`

### 8.2 GREEN implementation

- implement camera and viewport transforms
- implement draw passes with instancing
- implement offscreen picking
- implement ASCII glyph atlas and monochrome shader set

### 8.3 REFACTOR

- batch draw calls by pass and state
- extract shader constants and symbol maps

### 8.4 Exit gate

- deterministic framebuffer snapshot tests pass for reference scenes
- picking correctness tests pass

## 9. T4 - `@gen-dungeon/explorer-app` E2E

### 9.1 RED tests

- `flow.default_load_shows_discovered_hexes_only.red`
- `flow.pan_zoom_and_select_hex_updates_inspect.red`
- `flow.toggle_all_layers_and_render_deltas.red`
- `flow.search_jump_by_coord_owner_adventurer.red`
- `flow.ws_disconnect_reconnect_without_reload.red`
- `flow.mobile_viewport_controls_operate.red`

### 9.2 GREEN implementation

- minimal DOM shell components
- wire search/jump interactions
- wire inspect panel and sync status
- deep-link routing for selected target

### 9.3 REFACTOR

- trim UI state to orchestration-only
- remove renderer/data leakage into UI components

### 9.4 Exit gate

- all E2E flows pass in desktop and mobile emulation profiles

## 10. T5 - Performance and Reliability TDD

### 10.1 RED tests

- `perf.mobile_baseline_maintains_30fps.red`
- `perf.large_visible_set_stays_within_memory_budget.red`
- `freshness.p95_update_latency_under_2s.red`
- `reliability.long_run_no_unbounded_queue_growth.red`

### 10.2 GREEN implementation

- adaptive overlay quality knobs
- queue backpressure and batch apply tuning
- telemetry hooks for fps and lag

### 10.3 Exit gate

- baseline perf/freshness tests pass in staging harness

## 11. Torii SQL View-Specific Test Matrix

For each view version (`v1`, future `v2+`), include:
- shape test: required columns and types
- semantics test: filters/joins match expected gameplay meaning
- ordering test: deterministic sort stability
- drift test: generated model field changes force test failure
- compatibility test: existing proxy query contracts remain valid

## 12. Regression Policy

Every defect adds:
- one failing test reproducing the bug
- minimal fix
- no merge unless regression test passes

Required regression buckets:
- ordering and dedupe
- stale/expired claim handling
- chunk eviction correctness
- inspect payload completeness
- renderer picking mismatch

## 13. CI Gate Plan

Suggested CI sequence:

1. `types-and-contracts`
- schema parity
- DTO and envelope validation

2. `views-and-proxy`
- sql view tests
- proxy API + ws contract tests

3. `data-and-renderer`
- reducer/cache tests
- renderer deterministic snapshot tests

4. `app-e2e`
- core UX flow tests (desktop + mobile emulation)

5. `perf-smoke`
- lightweight fps/freshness sanity checks

## 14. Definition of Done (TDD)

- Every shipped behavior has a corresponding RED-first test record.
- View/proxy/data/renderer/app tests are green.
- No unresolved schema parity failures against `@client` codegen.
- No unowned flaky tests in CI.
- Performance and freshness thresholds are passing.

## 15. Initial Ticket Sequence (Ready to Execute)

1. `T0.1` Create schema parity test harness against `models.gen.ts`.
2. `T1.1` Add failing tests for `hex_render` and `hex_inspect` views.
3. `T1.2` Implement v1 views + parity checker.
4. `T2.1` Add failing ws ordering/dedupe tests.
5. `T2.2` Implement ordered patch reducer and resync protocol.
6. `T3.1` Add failing top-down camera and picking tests.
7. `T3.2` Implement renderer passes for grid + overlay + picking.
8. `T4.1` Add failing E2E flow tests for inspect/search/layer toggles.
9. `T4.2` Implement app shell wiring and deep-linking.
10. `T5.1` Add failing perf/freshness tests and tune to green.
