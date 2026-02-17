# Explorer Sidebar Operations TDD Plan

Status: Draft  
Last updated: 2026-02-17

## 1. TDD Rule

No production changes before failing tests exist for the intended behavior.
Every item follows RED -> GREEN -> REFACTOR.

## 2. Scope Under Test

Packages:
- `@gen-dungeon/explorer-types`
- `@gen-dungeon/explorer-app`
- `@gen-dungeon/explorer-proxy-node`
- `@gen-dungeon/explorer-data` (refresh/selectors interactions)

Primary files expected to change:
- `client/packages/explorer-types/src/explorer-dtos.ts`
- `client/packages/explorer-app/src/live-runtime.ts`
- `client/packages/explorer-proxy-node/src/api.ts`
- `client/packages/explorer-app/src/inspect-format.ts`
- `client/packages/explorer-app/src/app.ts`

## 3. Stage Order and Exit Gates

1. `S0` Contract Baseline
2. `S1` Read-Path Mining Hydration
3. `S2` Sidebar Rendering
4. `S3` Inspect Refresh + Reliability

No stage advances without green gate.

## 4. S0 - Contract Baseline

### 4.1 RED tests

- `explorer_dtos_hex_inspect_includes_mining_model_families.red`
- `inspect_formatter_handles_missing_mining_rows_without_throw.red`

Suggested locations:
- `client/packages/explorer-app/tests/inspect-format.red.test.ts`
- new contract-focused tests where needed in app/runtime suites

### 4.2 GREEN targets

- Extend `HexInspectPayload` with mining model arrays.
- Ensure fixtures compile with new payload shape.

### 4.3 Exit gate

- All inspect fixture tests pass with mining fields present and nullable/empty-state-safe behavior.

## 5. S1 - Read-Path Mining Hydration

### 5.1 RED tests

- `live_snapshot_query_requests_mining_models.red`
- `live_inspect_payload_includes_mine_nodes_and_shifts.red`
- `live_inspect_payload_filters_mining_rows_to_selected_hex.red`
- `proxy_hex_endpoint_passthroughs_mining_payload.red`

Suggested locations:
- `client/packages/explorer-app/tests/live-runtime.red.test.ts`
- `client/packages/explorer-proxy-node/tests/api.red.test.ts`

### 5.2 GREEN targets

- Add mining models to `SNAPSHOT_QUERY`.
- Add runtime mapping types and filtered selection logic.
- Keep proxy `getHex` merge stable with event tail ordering.

### 5.3 REFACTOR

- Consolidate repeated row-filtering helpers in `live-runtime.ts`.
- Keep deterministic sort helpers centralized.

### 5.4 Exit gate

- Runtime + proxy tests prove mining rows are fetched, mapped, and returned deterministically.

## 6. S2 - Sidebar Rendering (Compact Loop-First Cards)

### 6.1 RED tests

- `inspect_compact_renders_operations_summary_card.red`
- `inspect_compact_renders_area_slots_card.red`
- `inspect_compact_renders_mine_operations_card.red`
- `inspect_compact_renders_adventurer_assignments_card.red`
- `inspect_compact_renders_production_feed_card.red`
- `inspect_full_mode_still_includes_raw_cards.red`
- `inspect_html_escapes_all_dynamic_mining_values.red`

Location:
- `client/packages/explorer-app/tests/inspect-format.red.test.ts`

### 6.2 GREEN targets

- Add card renderers + deterministic sorting.
- Add row caps and explicit truncation hints.
- Keep existing compact cards that remain useful for debugging.

### 6.3 REFACTOR

- Extract shared summary builders from renderer functions.
- Keep rendering functions pure and side-effect-free.

### 6.4 Exit gate

- Snapshot/assertion tests verify new card sections and stable deterministic output.

## 7. S3 - Inspect Refresh + Reliability

### 7.1 RED tests

- `selected_inspect_refreshes_on_operation_relevant_patch.red`
- `selected_inspect_does_not_refresh_on_unrelated_patch.red`
- `sidebar_row_caps_prevent_unbounded_dom_growth.red`

Locations:
- `client/packages/explorer-app/tests/flow.red.test.ts`
- `client/packages/explorer-app/tests/live-runtime.red.test.ts`

### 7.2 GREEN targets

- Expand `patchTouchesHex` coverage for relevant patch kinds/shape.
- Ensure refresh keeps selected inspect coherent under active stream traffic.

### 7.3 Exit gate

- Flow tests prove timely refresh behavior for selected hex operations.

## 8. Regression Buckets

Every defect in this scope must add a regression test in one of:
- payload completeness
- assignment derivation
- deterministic sorting
- refresh triggers
- rendering safety and escaping

## 9. Validation Commands

Run from `client/`:

```bash
bun run test:app
bun run test:proxy
bun run typecheck
```

Optional full suite before merge:

```bash
bun run test
```

## 10. Definition of Done

- All RED tests introduced for this scope are green.
- No regressions in existing inspect/search/status flow tests.
- New cards render deterministically with stable sorting and escaping.
- Docs and issue backlog are updated with final behavior.
