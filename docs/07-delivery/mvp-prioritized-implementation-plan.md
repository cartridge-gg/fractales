# MVP Prioritized Implementation Plan (P0-P2)

This plan converts the MVP spec into an execution order that closes the highest-risk gaps first, then delivers the game loop, then hardens for launch.

Canonical references:
- `docs/02-spec/mvp-functional-spec.md`
- `docs/02-spec/design-decisions.md`
- `docs/07-delivery/dojo-mvp-prd.md`
- `docs/07-delivery/dojo-mvp-implementation-checklist.md`
- `docs/07-delivery/agent-handoff.md`

If this plan conflicts with `docs/02-spec/*`, the spec and decision log win.

## Priority Summary

- `P0` (spec hardening + blockers): remove ambiguity and exploit-prone behavior before model/system coding.
- `P1` (core build): execute `M0 -> M4` then `S1 -> S5` with edge-case tests in every stage.
- `P2` (hardening + release): fuzz/perf/indexing/ops signoff.

## P0 - Spec Hardening and Blocker Removal

Goal: finish all design-level decisions that can create rework or economic exploits.

### P0.1 Workspace and Tooling Alignment

- Decision: canonical implementation workspace path is `game/`.
- Delivery docs must reference `game/` and `game/src/` paths consistently.
- Keep one command contract for all contributors:
- `cd <workspace>`
- `dojo build`
- `dojo test`

Exit gate:
- Zero path/tooling contradictions across delivery docs.

### P0.2 Lock Remaining MVP Behavior Ambiguities

Update `docs/02-spec/mvp-functional-spec.md` and `docs/02-spec/design-decisions.md` to lock:

1. `discover_hex` replay behavior:
- Revert if already discovered, or idempotent return-without-mutation.
- Keep one behavior only.

2. `discover_area` identity:
- Explicit function shape (`hex + area_index` or equivalent).
- Deterministic `AreaId` derivation rule.

3. Ownership scope for maintenance/claim:
- Define exactly how area ownership maps to hex-level upkeep/claim/defend.

4. Energy regeneration schedule:
- Per-block, action-based, or hybrid with exact formula and cap semantics.

5. Conversion volume penalty window:
- Exact rolling window (block length), update cadence, and floor/ceiling behavior.

Exit gate:
- No unresolved MVP behavior in open questions.
- No conflicting behavior between `02-spec` and delivery docs.

### P0.3 Lock Anti-Exploit State Transitions

Add explicit normative rules (preconditions, writes, events, failure) for:

1. Harvest reservation:
- Reserve plant yield at `start_harvesting` to prevent over-commit from concurrent starts.
- Define reservation release on cancel/fail/death.

2. Claim escrow:
- Lock claimant energy on `initiate_hex_claim`.
- Prevent same energy from backing multiple concurrent claim attempts.

3. Claim attempt expiry:
- Enforce `claim_completion_deadline` semantics (auto-expire/refund behavior).

4. Decay processing checkpoint:
- Ensure repeated `process_hex_decay` calls cannot double-charge the same elapsed window.

5. Death guard:
- Dead adventurers are rejected by all state-changing entrypoints.

Exit gate:
- Normative transition tables added to spec for harvest, decay, claim/defend, death.

### P0.4 Write Tests First for the New Edges

Before implementation, add failing tests for:

- Duplicate discovery replay behavior.
- Concurrent harvest starts on one plant.
- One claimant initiating multiple claims with limited energy.
- Claim deadline expiry path.
- Repeated decay processing in the same block/window.
- Death during active harvesting lock.

Exit gate:
- Red tests exist for all new edge rules.

## P1 - Core MVP Build (Model-First, Then Systems)

Goal: deliver the playable loop with locked invariants and stage isolation.

Follow strict order from checklist:
- `M0 -> M4`
- `S1 -> S5`

One PR per stage, as defined in `docs/07-delivery/agent-handoff.md`.

### P1.1 Model and Library Stages (`M0-M4`)

1. `M0`: codec/math/adjacency foundation.
2. `M1`: world + area models with immutable first-discoverer fields.
3. `M2`: adventurer/inventory/death models with alive->dead monotonicity.
4. `M3`: harvesting model + bounded math + reservation fields.
5. `M4`: economics/ownership models + conversion/decay math libs + claim escrow fields.

Required edge-focused unit coverage:
- Codec round-trip stability and invalid coordinate rejection.
- Discovery idempotency and immutable discoverer metadata.
- Death irreversibility and deterministic inventory-loss hash.
- Yield/stress/health bounds on complete/cancel/death.
- Decay monotonicity under deficit and bounded recovery.
- Escrow accounting invariants (no double-use energy).

Exit gate:
- All `M0-M4` checklist tests green.

### P1.2 System Stages (`S1-S5`)

1. `S1 WorldManager`: adjacency, move, discover hex/area, world events.
2. `S2 AdventurerManager`: create, consume/regenerate, kill, alive guards.
3. `S3 HarvestingManager`: init/start/progress/complete/cancel/inspect with reservation.
4. `S4 EconomicManager`: convert, maintenance, decay processing checkpoint, claim/defend escrow.
5. `S5 OwnershipManager`: ownership query/transfer paths limited to allowed contexts.

Mandatory system-level edge tests:
- Replay-safe discovery behavior.
- Concurrent harvest start/complete ordering.
- Claim initiation escrow and refund/expiration correctness.
- Defend during grace window with pending claims.
- Dead adventurer lockout on all system entrypoints.

Exit gate:
- All `S1-S5` checklist tests green.
- No cross-domain write leakage beyond stage responsibility.

### P1.3 Integration and Event Contracts

Pass the integration suite in checklist plus two added regressions:

- Existing:
- `E2E-01` discover->harvest->convert->maintain.
- `E2E-02` neglect->claimable->claim/defend.
- `E2E-03` backpack constraints during harvest completion.
- `E2E-04` permadeath lockout.

- Added:
- `E2E-05` concurrent claims with escrow + deadline expiry.
- `E2E-06` repeated decay processing is idempotent for same elapsed window.

Event requirements:
- Payloads match `docs/02-spec/mvp-functional-spec.md` exactly.
- Single emission per state transition.

Exit gate:
- Integration + event snapshot tests green.

## P2 - Hardening and Release Readiness

Goal: ensure economic safety, deterministic behavior, and operational readiness.

### P2.1 Property and Regression Hardening

- Conversion monotonicity with bounded penalties.
- No-negative-balance and no-overflow invariants under fuzz.
- Harvest and claim regression pack for all previously fixed exploit paths.

### P2.2 Performance and Size Control

- Enforce gas/size budgets from PRD.
- Profile harvesting start/complete and decay processing hot paths.
- Refactor if contract cohesion degrades.

### P2.3 Indexing and Ops Readiness

- Torii event verification under integration load.
- Deployment/migration rehearsal in local Dojo stack.
- Final docs lock and acceptance review.

Exit gate:
- Final checklist signoff complete.
- MVP acceptance criteria pass and map to tests.

## Suggested Timeline (10 Working Days)

1. Day 1-2: `P0` (spec locks, blocker removal, failing edge tests).
2. Day 3-5: `M0-M4`.
3. Day 6-8: `S1-S5`.
4. Day 9: integration + event snapshots + regressions.
5. Day 10: hardening, profiling, and MVP signoff.

## First Execution Ticket (Start Here)

1. Confirm `game/` remains the canonical workspace path in all new delivery docs.
2. Lock `discover_hex` replay behavior, `discover_area` signature, and ownership-scope mapping in `02-spec`.
3. Add failing tests for harvest reservation, claim escrow, and decay idempotency.
4. Start `M0` only after the three items above are merged.
