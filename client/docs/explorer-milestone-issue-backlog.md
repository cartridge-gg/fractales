# Gen Dungeon Explorer Milestone Issue Backlog

Status: Draft for issue creation  
Last updated: 2026-02-16  
Owner: Client Platform + Game Infra

## 1. Purpose

Translate PRD + TDD requirements into milestone-scoped, dependency-ordered Git issues.
This backlog is intended to be copied into issue tracker tickets with explicit `depends_on` links.

Source docs:
- `./explorer-prd.md`
- `./explorer-tdd-plan.md`
- `./torii-sql-views-package-prd.md`

## 2. Baseline Snapshot

Current baseline in repo:
- P0 complete (workspace compiles, core contract tests in place).
- P1 started:
  - v1 logical view catalog scaffolding exists.
  - inspect-view join coverage test added.
  - proxy API adapter skeleton exists (`createExplorerProxyApi`).
- Remaining work is to finish P1 exit gates, then execute P2 through P5 in order.

## 3. Milestone Map

| Milestone | PRD ref | TDD ref | Goal | Exit gate |
|---|---|---|---|---|
| P1 Completion | `explorer-prd.md` §15 P1 | `explorer-tdd-plan.md` T1 + T2(proxy subset) | Lock view semantics and read-path proxy contracts | Seeded integration tests prove view correctness; chunk/inspect typed contracts pass |
| P2 | `explorer-prd.md` §15 P2 | `explorer-tdd-plan.md` T2 | Build deterministic client data store and chunk cache | Replay determinism and cache eviction tests green |
| P3 | `explorer-prd.md` §15 P3 | `explorer-tdd-plan.md` T3 | Deliver WebGL renderer core | Snapshot + picking correctness tests green |
| P4 | `explorer-prd.md` §15 P4 | `explorer-tdd-plan.md` T4 | Ship app shell UX and full spectator flows | Desktop/mobile E2E flow suite green |
| P5 | `explorer-prd.md` §15 P5 | `explorer-tdd-plan.md` T5 | Meet perf/freshness reliability SLOs | 30 FPS baseline mobile; p95 freshness under 2s |

## 4. Issue Template Contract

Use this for each issue:
- `Title`: `<milestone-code>: <short action + behavior>`
- `Labels`: `client`, `explorer`, `milestone:<Px>`, `stage:<Tx>`, `type:<red|green|refactor|doc|ci>`
- `Body sections`: `Context`, `Scope`, `Out of Scope`, `Acceptance`, `Depends On`
- `Depends On` format: issue IDs from this document
- `Validation command`: required command(s) to run before close

ID format in this backlog:
- `EXP-P1-XX`, `EXP-P2-XX`, `EXP-P3-XX`, `EXP-P4-XX`, `EXP-P5-XX`

## 5. Issues by Milestone

### P1 Completion (Views + Proxy Read Path)

| ID | Type | Title | Scope | Acceptance | Depends On |
|---|---|---|---|---|---|
| EXP-P1-01 | red | Add seeded SQL fixture harness for torii view tests | Create deterministic fixture datasets for discovered/undiscovered hexes, claims, ownership, events | Fixture loader runs locally and in CI; tests can query seeded state | none |
| EXP-P1-02 | red | Add view-shape tests for full v1 catalog | One test file covering required columns/types for each `explorer_*_v1` view | Fails if any view shape drifts from contract | EXP-P1-01 |
| EXP-P1-03 | red | Add view-semantics tests for claim/ownership/ordering | Add behavior tests: discovered-only filter, active-claim filtering, single-controller consistency, event ordering | Tests fail against incorrect SQL semantics | EXP-P1-01 |
| EXP-P1-04 | green | Implement semantic SQL corrections for v1 views | Update SQL templates/mapping strategy to satisfy `EXP-P1-02` and `EXP-P1-03` | All view shape and semantics tests pass | EXP-P1-02, EXP-P1-03 |
| EXP-P1-05 | red | Add proxy contract tests for chunk/inspect/search/status routes | Route-level tests for payload shape, bounds, and error branches | Failing tests confirm missing route behavior | EXP-P1-04 |
| EXP-P1-06 | green | Implement proxy HTTP handlers using typed reader adapter | Implement `GET /v1/chunks`, `GET /v1/hex/:hex_coordinate`, `GET /v1/search`, `GET /v1/status` | Route tests pass with stable schema and validation | EXP-P1-05 |
| EXP-P1-07 | red | Add websocket ordering/gap-resync contract tests | Test monotonic sequence, tie-break order, `RESYNC_REQUIRED` emission on gap | Tests fail when ordering/gap logic is absent | EXP-P1-06 |
| EXP-P1-08 | green | Implement proxy websocket stream contract | Add stream producer with monotonic sequence and explicit gap handling | WS tests pass and schema envelope is stable | EXP-P1-07 |
| EXP-P1-09 | refactor | Separate mapping resolution from query handlers | Extract mapping, SQL contract types, and handler wiring to avoid cyclic coupling | No behavior changes; tests remain green | EXP-P1-08 |
| EXP-P1-10 | doc | Publish P1 read-path runbook and version manifest usage | Document startup checks, required view versions, and failure modes | Docs reviewed and linked from package README | EXP-P1-08 |

### P2 (Data Store + Chunk Cache)

| ID | Type | Title | Scope | Acceptance | Depends On |
|---|---|---|---|---|---|
| EXP-P2-01 | red | Add reducer ordering tests with full tie-break tuple | Verify ordering by `(sequence, block, tx, event)` and duplicate rejection | Failing tests prove current gaps | EXP-P1-08 |
| EXP-P2-02 | green | Implement deterministic patch reducer with dedupe | Build reducer state transitions for ordered apply + idempotency | Reducer tests pass | EXP-P2-01 |
| EXP-P2-03 | red | Add reconnect/resync orchestration tests | Simulate disconnect, sequence gap, snapshot reload, replay buffer apply | Failing tests demonstrate missing orchestration | EXP-P2-02 |
| EXP-P2-04 | green | Implement reconnect + snapshot watermark flow | Add state-machine transitions for `live/catching_up/degraded` and replay | Reconnect tests pass | EXP-P2-03 |
| EXP-P2-05 | red | Add chunk cache budget and eviction pressure tests | Stress mobile/desktop caps, LRU policy, pin semantics | Failing tests show wrong eviction behavior | EXP-P2-02 |
| EXP-P2-06 | green | Implement bounded chunk cache policy | Implement deterministic LRU with pinned reserve behavior | Cache tests pass under load fixtures | EXP-P2-05 |
| EXP-P2-07 | red | Add selector tests for viewport and layer filters | Validate visible chunk/hex selection by viewport + toggle state | Failing tests confirm selector contract | EXP-P2-06 |
| EXP-P2-08 | green | Implement normalized selectors for render/inspect | Add selectors consumed by renderer/app contracts | Selector tests pass | EXP-P2-07 |
| EXP-P2-09 | refactor | Isolate transport adapters from store core | Split proxy transport from pure store modules | Existing tests unchanged and green | EXP-P2-08 |
| EXP-P2-10 | doc/ci | Add deterministic replay CI gate for explorer-data | Add CI job for reducer/cache/resync suites | CI gate fails on replay drift | EXP-P2-08 |

### P3 (WebGL Renderer Core)

| ID | Type | Title | Scope | Acceptance | Depends On |
|---|---|---|---|---|---|
| EXP-P3-01 | red | Add camera constraints tests (top-down pan/zoom only) | Verify no rotate/tilt and zoom bounds behavior | RED tests fail without camera constraints | EXP-P2-08 |
| EXP-P3-02 | green | Implement camera transforms and viewport math | Add camera state and world-to-screen transforms | Camera tests pass | EXP-P3-01 |
| EXP-P3-03 | red | Add culling and prefetch ring tests | Validate chunk inclusion + one-ring prefetch logic | RED tests fail without culling logic | EXP-P3-02 |
| EXP-P3-04 | green | Implement culling and render set assembly | Build visible set computation for render passes | Culling tests pass | EXP-P3-03 |
| EXP-P3-05 | red | Add picking correctness tests via id buffer fixtures | Test selected hex identity for click/tap coordinates | RED tests fail before picking implementation | EXP-P3-04 |
| EXP-P3-06 | green | Implement picking pass and selection decode | Add offscreen id buffer and hit-test decode | Picking tests pass | EXP-P3-05 |
| EXP-P3-07 | red | Add overlay and glyph atlas snapshot tests | Biome/claim symbol map and glyph atlas snapshots | RED tests fail without overlay/glyph passes | EXP-P3-04 |
| EXP-P3-08 | green | Implement grid/hex/overlay/glyph draw passes | Complete WebGL2 pass pipeline with monochrome style | Snapshot tests pass on reference scenes | EXP-P3-07 |
| EXP-P3-09 | refactor | Batch draw state and extract shader constants | Reduce pass churn and centralize symbol constants | No regressions; render tests remain green | EXP-P3-08 |
| EXP-P3-10 | doc | Publish renderer architecture notes and scene fixtures | Document pass ordering, uniforms, and fixture scenes | Docs linked in renderer package | EXP-P3-08 |

### P4 (App Shell + E2E)

| ID | Type | Title | Scope | Acceptance | Depends On |
|---|---|---|---|---|---|
| EXP-P4-01 | red | Add desktop spectator flow E2E RED suite | Add flows: default load, pan/zoom/select, inspect update | RED tests fail before shell wiring | EXP-P3-08 |
| EXP-P4-02 | green | Implement app shell orchestration and mount lifecycle | Wire proxy client, store, renderer, and shell lifecycle | Flow tests start passing | EXP-P4-01 |
| EXP-P4-03 | red | Add layer toggle and search/jump E2E tests | Validate layer toggles and search modes (`coord/owner/adventurer`) | RED tests fail before wiring controls | EXP-P4-02 |
| EXP-P4-04 | green | Implement controls: toggles, inspect, search/jump | Add minimal DOM controls and selectors integration | Control flow tests pass | EXP-P4-03 |
| EXP-P4-05 | red | Add reconnect and sync-status E2E tests | Validate ws drop/reconnect and status transitions | RED tests fail before reconnection UX | EXP-P4-02 |
| EXP-P4-06 | green | Implement sync indicators and recovery UX | Expose `live/catching_up/degraded` and retry behavior | Reconnect tests pass without page reload | EXP-P4-05 |
| EXP-P4-07 | red | Add deep-link routing tests for selected targets | Ensure URL routes restore selection and viewport target | RED tests fail before routing implementation | EXP-P4-04 |
| EXP-P4-08 | green | Implement deep-linking and hydration logic | Support direct links by coordinate/owner/adventurer targets | Routing tests pass | EXP-P4-07 |
| EXP-P4-09 | red | Add mobile emulation E2E flow suite | Verify touch pan/zoom/select and control access | Mobile tests fail before tuning | EXP-P4-04 |
| EXP-P4-10 | green | Implement mobile interaction tuning and layout guards | Tune touch handlers and responsive controls | Mobile E2E suite passes | EXP-P4-09 |

### P5 (Performance + Reliability)

| ID | Type | Title | Scope | Acceptance | Depends On |
|---|---|---|---|---|---|
| EXP-P5-01 | red | Add perf harness with scripted camera path | Produce repeatable FPS/frame-time metrics from fixed scenarios | Harness fails thresholds before optimization | EXP-P4-10 |
| EXP-P5-02 | green | Implement renderer perf optimizations | Instancing/culling/atlas batching improvements | Perf harness trend improves; no correctness regressions | EXP-P5-01 |
| EXP-P5-03 | red | Add freshness latency test for end-to-end patch path | Measure block-to-visible latency p95 in staging harness | RED test fails when >2s | EXP-P4-06 |
| EXP-P5-04 | green | Implement queue/backpressure tuning for freshness | Optimize patch apply batching and queue management | Freshness p95 under 2s in harness | EXP-P5-03 |
| EXP-P5-05 | red | Add memory growth and long-run reliability tests | Validate bounded memory and queue sizes in endurance run | RED tests fail without guards | EXP-P4-10 |
| EXP-P5-06 | green | Implement memory/queue guardrails and telemetry hooks | Add caps, telemetry, and alert thresholds | Reliability tests pass without unbounded growth | EXP-P5-05 |
| EXP-P5-07 | ci | Add perf-smoke CI stage with thresholds | Add CI job for lightweight fps/freshness/reliability checks | CI fails on threshold regressions | EXP-P5-02, EXP-P5-04, EXP-P5-06 |
| EXP-P5-08 | doc | Publish perf runbook and SLO dashboard spec | Define dashboards, alerting, and oncall actions | Runbook reviewed and linked | EXP-P5-07 |

## 6. Dependency Graph (Milestone-Level)

- `P1` must complete before `P2` starts.
- `P2` must complete before `P3` starts.
- `P3` must complete before `P4` starts.
- `P4` must complete before `P5` starts.
- Cross-cutting CI/doc issues can run in parallel only after their milestone’s core green tasks.

## 7. Recommended Git Issue Creation Order

1. Create all `EXP-P1-*` issues first and wire dependencies.
2. Pre-create `EXP-P2-*` through `EXP-P5-*` as `blocked` with explicit `depends_on`.
3. Add milestone labels and board columns:
   - `Backlog`
   - `Ready (deps clear)`
   - `In Progress`
   - `Review`
   - `Done`
4. Enforce one in-progress GREEN implementation issue per package to reduce merge conflicts.

## 8. Close Criteria for This Backlog Doc

- Every issue above exists in the tracker with matching ID in title/body.
- Every issue has `Depends On` links populated.
- Milestone board reflects dependency order and stage gates.
