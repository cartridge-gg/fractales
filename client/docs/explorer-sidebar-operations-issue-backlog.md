# Explorer Sidebar Operations Git Issue Backlog

Status: Draft for issue creation  
Last updated: 2026-02-17

## 1. Purpose

Translate sidebar operations PRD + TDD into dependency-ordered Git issues.

Source docs:
- `./explorer-sidebar-operations-prd.md`
- `./explorer-sidebar-operations-tdd-plan.md`
- `./explorer-prd.md`

## 2. Milestone Map

| Milestone | Goal | Exit gate |
|---|---|---|
| `SID-P1` | Extend inspect contract/read-path with mining families | Runtime + proxy contract tests green |
| `SID-P2` | Ship compact loop-first sidebar cards | Inspect formatter + app flow tests green |
| `SID-P3` | Hardening for refresh/perf/readability | Reliability row-cap tests + docs update green |

## 3. Issue Template Contract

Use this structure for each Git issue body:
- `Context`
- `Scope`
- `Out of Scope`
- `Acceptance`
- `Depends On`
- `Validation Command`

Labels recommendation:
- `client`
- `explorer`
- `sidebar`
- `milestone:SID-Px`
- `type:red|green|refactor|doc|ci`

## 4. Issues

### SID-P1 (Read Path)

#### `EXP-SID-01` (red)

Title: `EXP-SID-01: Add failing inspect contract tests for mining payload families`

Context:
Current `HexInspectPayload` does not expose mining model families.

Scope:
- Add failing tests asserting inspect payload includes `mineNodes`, `miningShifts`, `mineAccessGrants`, `mineCollapseRecords`.

Out of Scope:
- Rendering/UI changes.

Acceptance:
- Tests fail before payload contract updates.

Depends On:
- none

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-02` (green)

Title: `EXP-SID-02: Extend explorer DTO contract for mining inspect payload`

Context:
Need typed payload support before runtime mapping and UI work.

Scope:
- Update `explorer-dtos.ts` with mining arrays on `HexInspectPayload`.
- Update fixtures/types where required.

Out of Scope:
- Snapshot query and mapping.

Acceptance:
- Contract tests introduced in `EXP-SID-01` pass.

Depends On:
- `EXP-SID-01`

Validation Command:
- `bun run typecheck`

---

#### `EXP-SID-03` (red)

Title: `EXP-SID-03: Add failing live-runtime tests for mining GraphQL hydration`

Context:
Live read path currently hydrates harvest/economy/construction but not mining.

Scope:
- Add failing tests in `live-runtime.red.test.ts` asserting:
  - query requests mining models
  - inspect payload includes filtered mining rows for selected hex

Out of Scope:
- Proxy route behavior.

Acceptance:
- Tests fail before runtime implementation.

Depends On:
- `EXP-SID-02`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-04` (green)

Title: `EXP-SID-04: Implement live-runtime mining snapshot mapping for inspect payload`

Context:
Mining data must be hydrated from Torii for selected hex inspect.

Scope:
- Extend `SNAPSHOT_QUERY` with mining model connections.
- Map/filter rows into inspect payload deterministically.

Out of Scope:
- Sidebar rendering.

Acceptance:
- `EXP-SID-03` tests pass.

Depends On:
- `EXP-SID-03`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-05` (red)

Title: `EXP-SID-05: Add failing proxy API contract tests for mining inspect passthrough`

Context:
Proxy contract must preserve enriched inspect payload and deterministic event tail merge.

Scope:
- Add failing tests in `api.red.test.ts` for mining payload passthrough and event ordering semantics.

Out of Scope:
- HTTP server CORS/transport changes.

Acceptance:
- Tests fail before proxy adaptation.

Depends On:
- `EXP-SID-04`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-proxy-node test`

---

#### `EXP-SID-06` (green)

Title: `EXP-SID-06: Implement proxy inspect response support for mining payload contract`

Context:
Proxy `getHex` is the inspect API contract boundary.

Scope:
- Ensure API and route responses preserve mining inspect arrays and deterministic event ordering.

Out of Scope:
- New endpoints.

Acceptance:
- `EXP-SID-05` tests pass.

Depends On:
- `EXP-SID-05`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-proxy-node test`

### SID-P2 (Sidebar UX)

#### `EXP-SID-07` (red)

Title: `EXP-SID-07: Add failing inspect formatter tests for operations-first cards`

Context:
Current compact inspect output is model-family oriented, not loop-oriented.

Scope:
- Add failing tests for cards:
  - Operations Summary
  - Area Slots
  - Mine Operations
  - Adventurer Assignments
  - Production Feed

Out of Scope:
- Runtime query changes.

Acceptance:
- Tests fail before renderer implementation.

Depends On:
- `EXP-SID-06`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-08` (green)

Title: `EXP-SID-08: Implement compact sidebar operations cards and deterministic sorting`

Context:
Need readable loop-first observability in right sidebar.

Scope:
- Implement new compact card renderers.
- Add deterministic sorting and row caps.
- Preserve full mode raw cards.

Out of Scope:
- New route contracts.

Acceptance:
- `EXP-SID-07` tests pass.

Depends On:
- `EXP-SID-07`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-09` (red)

Title: `EXP-SID-09: Add failing app flow tests for selected-hex refresh on operation patches`

Context:
Sidebar must stay current during live operation changes.

Scope:
- Add failing flow tests proving selected inspect refreshes on relevant patch payloads.

Out of Scope:
- Stream transport redesign.

Acceptance:
- Tests fail before refresh trigger changes.

Depends On:
- `EXP-SID-08`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-10` (green)

Title: `EXP-SID-10: Implement selected inspect refresh triggers for operation-relevant patches`

Context:
Patch-triggered refresh needs to cover operation model changes touching selected hex.

Scope:
- Update patch-touch logic to refresh selected inspect deterministically for relevant patch kinds/shapes.

Out of Scope:
- Additional websocket routes.

Acceptance:
- `EXP-SID-09` tests pass.

Depends On:
- `EXP-SID-09`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

### SID-P3 (Hardening)

#### `EXP-SID-11` (red)

Title: `EXP-SID-11: Add failing stress tests for row-cap and truncation behavior`

Context:
High-density hexes can produce large mining/adventurer/event rows.

Scope:
- Add failing tests for bounded rendering and truncation indicators.

Out of Scope:
- Perf benchmark harness changes.

Acceptance:
- Tests fail before cap/truncation implementation.

Depends On:
- `EXP-SID-10`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-12` (green)

Title: `EXP-SID-12: Implement bounded rendering and explicit truncation indicators`

Context:
Prevent DOM/perf regressions in compact sidebar.

Scope:
- Enforce card row caps and visible truncation notices.

Out of Scope:
- Data contract changes.

Acceptance:
- `EXP-SID-11` tests pass.

Depends On:
- `EXP-SID-11`

Validation Command:
- `bun run --filter @gen-dungeon/explorer-app test`

---

#### `EXP-SID-13` (doc)

Title: `EXP-SID-13: Update explorer read-path runbook for sidebar operations payload`

Context:
Operational docs must reflect new inspect contract and debugging expectations.

Scope:
- Update runbook with new payload fields, troubleshooting, and validation commands.

Out of Scope:
- Production code changes.

Acceptance:
- Docs reviewed and linked from relevant package README/docs index.

Depends On:
- `EXP-SID-12`

Validation Command:
- `bun run test:app && bun run test:proxy`

---

#### `EXP-SID-14` (ci)

Title: `EXP-SID-14: Add CI gate for sidebar operations regression suite`

Context:
Need stable, repeatable gate for this feature set.

Scope:
- Add focused CI job running app + proxy + typecheck suites for sidebar scope.

Out of Scope:
- New performance SLO harness.

Acceptance:
- CI fails on contract/render/refresh regressions.

Depends On:
- `EXP-SID-12`

Validation Command:
- `bun run typecheck && bun run test:app && bun run test:proxy`

## 5. Recommended Creation Order

1. Create `EXP-SID-01` -> `EXP-SID-06` first (contract/read path).
2. Create `EXP-SID-07` -> `EXP-SID-10` next (UI + refresh).
3. Create `EXP-SID-11` -> `EXP-SID-14` last (hardening/docs/CI).
4. Keep one active GREEN implementation issue per package to reduce merge conflicts.
