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
