# AGENTS.md

## Mission
Build `gen-dungeon` as a deterministic, testable onchain game using Dojo.

## Canonical Docs
- Master index: `../docs/MASTER_DOC.md`
- MVP behavior authority: `../docs/02-spec/mvp-functional-spec.md`
- Locked decisions: `../docs/02-spec/design-decisions.md`
- Delivery contract: `../docs/07-delivery/agent-handoff.md`
- Build checklist: `../docs/07-delivery/dojo-mvp-implementation-checklist.md`

## Mandatory Read Order (Before Coding)
1. `../docs/02-spec/design-decisions.md`
2. `../docs/02-spec/mvp-functional-spec.md`
3. `../docs/07-delivery/dojo-mvp-prd.md`
4. `../docs/07-delivery/dojo-mvp-implementation-checklist.md`
5. `../docs/07-delivery/agent-handoff.md`

## Operating Rules
- Keep changes small and reviewable.
- Use test-first development for behavior changes and bugfixes.
- Prefer explicit model transitions over implicit side effects.
- Never ship silent behavior changes; update tests and docs in the same diff.
- Keep namespace/resource wiring explicit and consistent.
- Follow stage order only: `M0 -> M4`, then `S1 -> S5`.
- Keep one active stage owner; coordinate any shared-file overlap.

## Locked Decision Guardrails
- MVP scope is strict: no mining/crafting/buildings/AI/advanced hooks in MVP (DD-001).
- Gameplay coordinates are origin-centered cube coords; storage uses deterministic felt codec (DD-002, DD-006).
- Ownership is model parity only in MVP (no full ERC-721) (DD-003).
- Permadeath is mandatory in MVP (DD-004).
- Discovery is direct in MVP, not commit-reveal (DD-005).
- Percent math uses basis points (`1e4`) with floor rounding (DD-008).

## Dojo Build Practices
- Model design:
  - Choose keys that match gameplay identity (`player`, `entity`, etc.).
  - Keep defaults safe; guard against underflow/overflow from default reads.
  - Use compact, serializable types.
- System design:
  - Validate preconditions early and return fast.
  - Separate read -> compute -> write clearly.
  - Emit events for externally relevant state transitions.
- World and permissions:
  - Apply least privilege for writer permissions.
  - Keep manifests/config files in sync with resource changes.
- Determinism:
  - No non-deterministic logic in contracts.
  - Keep movement/combat/math logic reproducible from state alone.

## Testing Standard
- Unit tests for helper logic and math.
- World integration tests per system action:
  - setup world/resources
  - execute dispatcher call
  - assert model deltas and relevant events
- Every bugfix adds a regression test.
- Before merge: run `sozo build` and `sozo test` in this repo (or `dojo build`/`dojo test` if structure changes to `contracts/`).

## Change Workflow
1. Read relevant spec section in `../docs/` and existing tests.
2. Add or update failing tests for intended behavior.
3. Implement the minimal code needed to pass.
4. Run full impacted build/tests.
5. Update `../docs/` and `AGENTS.md` when a new invariant, pitfall, or workflow improvement is found.

## Stop and Escalate
Stop and ask for clarification when:
- Requested behavior conflicts with locked decisions.
- A needed decision is not locked in `../docs/02-spec/design-decisions.md`.
- Change crosses multiple stages or requires MVP scope expansion.
- Tooling/build issues prevent reliable validation.

## Self-Learning Rule (Mandatory)
After every non-trivial task, update this file with at least one concise improvement:
- New invariant.
- New pitfall and guardrail.
- Better test pattern.
- Better build/release workflow step.

## Lessons Learned
- 2026-02-11: Default model reads can return zeroed values; guard movement/decrement logic with explicit spawn/can-move checks before subtracting.
- 2026-02-12: Use `snforge test <filter>` for executable red/green loops; `sozo test` in this starter layout can report zero discovered tests.
- 2026-02-12: For felt-based codecs, convert `felt252 -> Option<u128>` first and pack/unpack with division/modulo constants (not bit-shifts) for broad Cairo compatibility.
- 2026-02-12: Remove starter `actions/world` boilerplate early; keep only stage-owned modules to avoid false failures from legacy harness resources.
- 2026-02-12: Keep M1 discovery semantics in pure helpers (`discover_*_once`) so idempotency and immutability can be unit-tested before world dispatchers exist.
- 2026-02-12: Add world event schemas during M1 so payload contracts are locked before S1; run `snforge` validations sequentially to avoid cache/parser races from parallel runs.
- 2026-02-12: Use `discover_*_once_with_status` (`Applied`/`Replay`) and poseidon domain-separated `derive_area_id` so S1 can gate energy/events without re-deriving replay logic.
- 2026-02-12: Start S1 with pure transition helpers (`discover_*_transition`, `move_cost_if_adjacent`) and unit tests first; wire contract entrypoints only after downstream models (M2-M4) exist.
- 2026-02-12: In S1 area discovery flows, reject mismatched `area_id`/`(hex_coordinate, area_index)` before write/event so deterministic identity (DD-011) is enforced at transition boundaries.
- 2026-02-12: Keep Dojo contract entrypoints in a dedicated module (`world_manager_contract`) and keep transition helpers pure in `world_manager`; this avoids semantic/macro cycles and keeps unit-testable logic separate from world I/O.
- 2026-02-12: For snforge integration tests, prefer `dojo_snf_test::spawn_test_world` (resource names) over `dojo_cairo_test` class-hash wiring to avoid undeclared world class failures in this project layout.
- 2026-02-12: Implement DD-016 with a pure reservation primitive first (`available_yield`, `reserve_yield_once_with_status`) so race-prevention logic is testable before S3 contract wiring.
- 2026-02-12: Implement DD-017 with a pure escrow-init primitive that deducts adventurer energy immediately and writes ACTIVE escrow metadata, so “locked energy is unavailable” is provable without claim-resolution logic.
- 2026-02-12: Implement DD-018 with an explicit expiry primitive that expires only when `now > expiry_block`, refunds locked energy atomically, and returns replay/no-op outcomes for idempotent reprocessing.
- 2026-02-12: Implement DD-019 by advancing `last_decay_processed_block` only by full elapsed windows and returning a no-op outcome when elapsed windows are zero, which prevents double-charge on repeated calls.
- 2026-02-12: For DD-020, model death effects as pure settlements: cancel active harvest reservation (release `plant.reserved_yield`), expire/refund active claim escrow, and hard-block dead actors in claim-init guards.
- 2026-02-12: Keep S2 deterministic by storing `last_regen_block` in `AdventurerEconomics`, applying lazy regen before spend actions, and returning structured transition outcomes (`Applied/NotOwner/Dead/...`) so contracts can gate writes/events precisely.
- 2026-02-12: In S3 integration flows, set restart/cancel block numbers from explicit regen math (`regen_per_100_blocks` + `energy_per_unit`) so restart assertions don’t silently depend on impossible energy states.
- 2026-02-12: For Dojo integration event checks, assert `world::Event::EventEmitted` payloads via `spy_events().assert_emitted(...)` and pin selectors with `Event::<T>::selector(world.namespace_hash)` to validate real world-emitted envelopes.
- 2026-02-12: Harden event integration tests with both payload assertions and selector cardinality checks (scan `spy.get_events().emitted_by(world)` and count `EventEmitted` by `keys[1]`) to catch duplicate/missing emissions.
- 2026-02-12: In S4 claim flows, keep claimability explicit on `HexDecayState` (`claimable_since_block`) and gate `initiate_hex_claim` on both decay threshold and checkpoint presence to avoid false-positive claim starts after maintenance recovery.
- 2026-02-12: For S4 escrow safety, settle expired ACTIVE claims on actionable entrypoints (`initiate_hex_claim`/`defend_hex_from_claim`) and emit `ClaimExpired` + `ClaimRefunded` together so stale escrows never block progress or hide refunds.
- 2026-02-12: Enforce S5 single-controller consistency by writing `AreaOwnership` during area discovery (control area seeds controller; non-control uses control owner) and syncing all area rows on immediate claim/defend resolution paths.
- 2026-02-12: For cross-system ownership observability, register ownership events in each integration namespace that can emit them and assert selector cardinality (`AreaOwnershipAssigned`, `OwnershipTransferred`) across discovery + claim flows.
- 2026-02-12: For P2.2 guardrails, enforce hot-path L2 gas ceilings and manager artifact-size ceilings with executable scripts (`scarb run perf-budget`, `scarb run size-budget`) so regressions fail fast outside long E2E runs.
- 2026-02-12: For deterministic world rollout, replace caller-supplied discovery/init payloads with domain-separated seed derivation (`hex -> area -> plant`) behind a versioned generator config, with Cubit as the canonical noise backend.
- 2026-02-12: G0 for deterministic generation must lock spec + decision docs first: remove caller content inputs at API boundaries, declare Cubit as canonical noise backend, and pin domain tags (`HEX_V1`, `AREA_V1`, `PLANT_V1`, `GENE_V1`) before contract rewiring.
- 2026-02-12: In this Cairo toolchain, `felt252` remainder is not available directly for bounded RNG; convert seed to `u256` and use integer modulo for deterministic range mapping helpers.
- 2026-02-12: For G3 plant init, derive profile fields (`species`, `max_yield`, `regrowth_rate`, `genetics_hash`) from `(hex_coordinate, area_id, plant_id, biome)` inside `harvesting_manager_contract`, and keep integration assertions profile-relative (not hardcoded yield constants).
- 2026-02-12: Do not run `snforge`/`scarb` build-heavy commands in parallel in this repo; shared output-file locks can produce corrupted artifacts (`trailing characters`) and require a clean rebuild.
- 2026-02-12: For Dojo models keyed by a field (e.g., `WorldGenConfig.generation_version`), `read_model(key)` always reflects that key in the returned struct even when the row is otherwise zeroed; detect initialization from non-key fields, not key equality.
- 2026-02-12: For live-play coordinate automation, always round-trip validate packed cube felts (`decode(encode(x,y,z)) == (x,y,z)`) before sending txs; malformed packed values fail adjacency/cube checks and silently no-op system entrypoints.
- 2026-02-12: Energy regen floors by elapsed blocks (`regen_per_100_blocks`), so scripted regen loops must preserve enough inter-call block distance (for this config, 5-block cadence) or actors can stall just below thresholds (e.g., 39 -> 39).
- 2026-02-12: Enforce location-coupled harvesting (`adventurer.current_hex == plant.hex_coordinate`) and emit explicit rejection events for world/harvest no-op guards so off-hex actions are blocked and observable in integration logs.
- 2026-02-12: World discovery is adjacency-gated; after moving, `discover_hex(current_hex)` is intentionally rejected (`DISC_HEX`/`NOT_ADJ`), so expansion loops must target the next adjacent hex, not self.
- 2026-02-12: For economy simulations, define and run a `code_exact` mode first (matching contract quirks) before any `design_intended` counterfactuals, so balance conclusions are grounded in actual on-chain behavior.
- 2026-02-13: For enum-space expansions, start TDD with behavior-level RED tests that avoid compile-time variant coupling (for example: "generated biomes include extended space" and "samples surface higher upkeep tiers"), then expand enum/mappings minimally to turn those tests GREEN.
- 2026-02-13: When adding deterministic per-area constraints (like plant slot caps), thread the generated value through discovery (`derive_area_profile -> discover_area write`) and enforce the same derivation in action entrypoints (`init_harvesting`) to avoid model/runtime drift.
- 2026-02-13: Keep biome behavior tables in one shared profile module and have both generation (`world_gen`) and economy/decay (`decay_math`) consume it; this prevents silent drift in upkeep/species/area-threshold logic.
- 2026-02-13: When bumping active generation version keys, update every consumer contract constant in the same change (`world_gen_manager`, `world_manager`, `harvesting_manager`) and run full-suite tests to catch cross-system key mismatches.
- 2026-02-13: For spawn-share calibration, use a deterministic coordinate window test that counts every canonical biome at least once; keep the sample large enough for coverage but bounded to avoid excessive unit-test gas/runtime.
- 2026-02-13: To enforce v2-only generation behavior, reject zeroed `HexArea.plant_slot_count` at harvest init (no derived fallback) and lock this with an integration test so legacy rows cannot silently initialize plants.
- 2026-02-13: For multiplayer collapse mechanics without onchain map iteration, track active participants via linked-list pointers on shift rows (`prev_active_shift_id`/`next_active_shift_id`) anchored in the mine node so collapse can deterministically settle every active miner in one pass.
- 2026-02-13: For client explorer planning, treat `@client` generated types as canonical and ship Torii SQL views as a versioned package with schema-parity tests to prevent proxy query drift.
- 2026-02-13: For client package scaffolding, keep runtime dependencies one-way (`types -> views/data/renderer -> app`) and expose only typed interfaces first so TDD can drive implementations without circular imports.
- 2026-02-13: For client realtime state, start with RED tests for strict stream ordering (`sequence`) and dedupe before implementing reducers, or stale websocket patches can silently regress inspect/render correctness.
- 2026-02-13: For Torii view contracts, make schema-parity checks data-driven from view manifests (`requiredModelFields`) so drift detection remains deterministic as new views are added.
- 2026-02-13: For explorer proxy contracts, validate and normalize API inputs (`chunk keys`, search mode, limits) at the boundary so websocket/store logic can assume canonical query shapes.
- 2026-02-13: For proxy websocket determinism, sort outbound rows by `(block_number, tx_index, event_index)` before assigning sequences, so all clients converge on identical patch order.
- 2026-02-15: In the client TypeScript workspace (`moduleResolution: NodeNext`), keep explicit `.js` suffixes on all relative imports/exports (including test files and barrel exports) or `tsc -b` fails before P0 gates can run.
- 2026-02-15: For `@client` package-manager consistency, pin `packageManager` to Bun, keep internal workspace deps as `workspace:*`, and validate with `bun install && bun run typecheck && bun run test` after lockfile migrations.
- 2026-02-15: For P1 Torii views, keep manifest view IDs in one-to-one parity with shipped `sql/views/v1/*.sql` files and lock inspect coverage with explicit placeholder-join tests so model families cannot silently drop from read paths.
- 2026-02-15: For bootstrap economy balancing, keep the simulator `code_exact`-first and require artifact outputs (`scenario_comparison.csv`, `timeseries.csv`, `run_summary.json`, `invariant_report.json`) per matrix run so policy changes can be diffed and audited.
- 2026-02-15: Lock target calibrations with explicit tests first (for example baseline inflation band), then use parameter sweeps to find viable defaults before patching simulator constants.
- 2026-02-15: After meeting baseline calibration, add a matrix-wide inflation bound test (for example `-5%..+25%`) before final tuning so stress scenarios cannot regress while keeping baseline green.
- 2026-02-16: For client execution planning, define one issue-ID namespace per milestone (for example `EXP-Px-YY`) and include explicit `Depends On` links in every issue body before work starts, or stage ordering drifts and parallel work creates hidden blockers.
- 2026-02-16: For proxy read-path stability, keep URL parsing in a dedicated module (`http-mapping`) and keep route handlers pure wrappers around typed APIs; this makes validation behavior testable without transport mocking and prevents parser drift across endpoints.
- 2026-02-16: For explorer stream reducers, sort incoming patch batches by `(sequence, blockNumber, txIndex, eventIndex)` before applying monotonic sequence guards, or equal-sequence duplicates can resolve inconsistently across clients.
- 2026-02-16: Keep a dedicated explorer-data replay gate (`test:deterministic-replay`) in CI for reducer/cache/resync/selectors so ordering and watermark regressions fail fast without waiting for full workspace suites.
- 2026-02-16: For renderer milestone T3, lock deterministic contracts in pure modules first (`camera`, `culling`, `picking`, `draw-pipeline`) and snapshot those outputs before wiring GPU paths; this keeps red/green loops fast and prevents WebGL harness flakiness from masking logic regressions.
- 2026-02-16: For app-shell milestone T4, keep orchestration deterministic by driving UI/renderer/proxy through a single stateful app boundary (`createExplorerApp`) and validating desktop + reconnect + deep-link + mobile flows in one package-level harness before any DOM framework wiring.
- 2026-02-16: For performance milestone T5, use deterministic simulation harnesses (scripted camera path + patch-pipeline queue model) with explicit thresholds (`fps`, `p95 latency`, `queue depth`, `drop ratio`) so CI can gate regressions without flaky hardware-dependent benchmarks.
- 2026-02-15: For tighter matrix compression, tune closed-loop controller gains (`inflation_upper/lower_band_bp`, `anti_inflation_gain_bp`, `anti_deflation_release_gain_bp`) after base economy constants; otherwise baseline and stress scenarios drift in opposite directions.
- 2026-02-15: Permissionless rebalance keepers need idempotent epoch guards and clipped bounty payouts (never revert on low pool), so second callers in an epoch deterministically receive zero reward and no state mutation.
- 2026-02-15: Keep epoch accounting deterministic by finalizing only when `snapshot.epoch == accumulator.epoch`, blocking replay via `is_finalized`, and always rolling the live accumulator to `epoch + 1` with zeroed counters.
- 2026-02-15: In permissionless tick flows, check `already_ticked_this_epoch` before early-boundary logic so duplicate calls in the same epoch classify as replay (`NoOpAlreadyTicked`) rather than timing no-op, keeping keeper outcomes deterministic.
- 2026-02-15: For regulator consumers, gate policy activation with `policy_epoch < current_epoch` and preserve safe defaults (`tax=0`, `upkeep=10000`, `mint_discount=0`) when policy rows are unset, so ticked changes apply next epoch without breaking legacy behavior.
- 2026-02-15: For simulator stability gates, quantify “no sustained oscillation” with sign-change counting on policy time series under a deadband, and assert this on an extended-horizon baseline run to avoid overfitting to short windows.
- 2026-02-15: In oscillation metrics, require reversal persistence (at least two consecutive opposite-direction moves) before counting a sign flip; this filters one-step jitter while still catching sustained policy ping-pong behavior.
- 2026-02-16: For client visual smoke checks, run the explorer harness via Bun (`bun run dev:app`) and capture a Playwright screenshot against localhost to lock a deterministic render sanity check in one command.
- 2026-02-17: In browser live-runtime adapters, bind `fetch` to `globalThis` and avoid Torii `where` operators that are not present on deployed schema inputs (for example `is_discoveredEQ`), or mount can fail with silent empty-state/degraded UI.
- 2026-02-17: For explorer map fidelity, decode packed cube felts to world coordinates for tile layout and polygon hit-testing; keep a legacy fallback layout for non-packed fixture coords so mock harnesses remain usable.
- 2026-02-17: Before scoping inspect UI coverage, probe live Torii model counts/sample rows (not just generated types) so milestones prioritize populated families first (for current live: economics/inventory/plants/reservations populated; construction/mine/sharing mostly zero-row).
- 2026-02-17: Treat inspect payload as a single contract across app/proxy/runtime; when adding model families (for example economics/inventory/construction), update DTO + runtime query + fixture payloads + app flow tests in one diff to avoid silent UI no-op reads.
- 2026-02-17: For map readability, render a coordinate-driven hex surface (discovered + generated unexplored window) instead of Cartesian background grids; keep unexplored tiles non-interactive so inspect calls never target missing rows.
- 2026-02-17: In app chunk reloads, merge incoming chunk snapshots with cached loaded chunks before render/update (`mergeChunkSnapshots`) so panning windows do not visually downgrade previously discovered tiles to unexplored.
- 2026-02-17: Preserve pan responsiveness by keeping viewport chunk replacement (not global chunk accumulation) and cache discovered hex styling inside the renderer (`knownDiscoveredHexes`), so discovered tiles stay visually discovered when they reappear in generated unexplored windows.
