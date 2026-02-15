# Resource Sharing Permissions PRD + TDD (Post-MVP Module)

## 1. Goal

Define a build-ready, test-first implementation plan for permissioned resource sharing so players can:

- delegate access to controlled resources
- configure deterministic yield/fee sharing
- preserve ownership safety under claim/defend transfer

This document is implementation-facing and should be treated as the contract for behavior, APIs, and test gates.

## 2. Why This Module

Current implementation supports only partial sharing:

- owner-only adventurer control via `can_be_controlled_by`
- mine access grants/revokes in `mining_manager`
- ownership transfer via ownership manager and claim/defend resolution

Missing capabilities:

- unified ACL model across mining, harvesting, and construction
- deterministic split rules for shared outputs
- coherent invalidation/reset semantics on ownership transfer

## 2.1 Locked v1 Design Choices

The following are explicitly locked for this phase:

- Scope layering: `area + hex + global`.
- Default access: controller-only unless grant exists.
- Grant lifetime: persistent until revoked.
- Split model: static basis-point rules only.
- Recipient cap: max `8` active recipients per resource/rule kind.
- Policy authority: controller-only edits.
- Ownership transfer behavior: invalidate old grants/shares via epoch bump.
- Mutation friction: enforced cooldown + energy cost.
- Emergence stance: cartel/rent-seeking behavior is allowed if core invariants hold.
- Scope precedence: `area > hex > global`.
- Cross-scope split resolution: nearest-scope override (no additive layering).
- Global-scope controller authority: namespace owner.
- Locked friction constants (v1): `100` blocks cooldown and `5` energy per mutation.

## 3. Product Outcome (v1)

Ship a deterministic `sharing_manager` domain that powers three concrete loops:

1. Mine co-op: controller grants mining rights and can configure output split.
2. Harvest co-op: controller grants harvest rights and can configure output split.
3. Construction co-op: controller grants build/upkeep rights with optional fee routing.

All state-changing actions remain owner-authenticated per adventurer.

## 4. Scope

In scope:

- Shared ACL primitives for area-scoped resources.
- Deterministic split math in basis points (`bp`) with replay-safe rounding rules.
- Mining/harvesting/construction integration paths.
- Claim/defend transfer coherence for sharing policies.
- Full unit + integration + E2E coverage.

Out of scope (v1):

- Arbitrary user-deployed hook contracts.
- Signature-based offchain approvals.
- Multi-asset escrow vaults and AMM-style accounting.
- NFT ownership contract migration.

## 5. Design Constraints

- Deterministic only: no external randomness, no timestamps from offchain.
- Owner-authenticated actor control remains mandatory.
- Policy evaluation must be O(1) or bounded small loops onchain.
- No negative balances or mint inflation through splits.
- Ownership transfer must not leave stale privileged access.

## 6. Domain Model Additions (Proposed)

New models in `game/src/models/sharing.cairo`:

### `ResourcePolicy`

- key: `resource_key`
- `resource_kind` (`MINE`, `PLANT_AREA`, `CONSTRUCTION_AREA`)
- `controller_adventurer_id`
- `policy_epoch` (`u32`) used to invalidate stale grants/shares on transfer
- `is_enabled` (`bool`)
- `updated_block`

### `ResourceAccessGrant`

- key: `(resource_key, grantee_adventurer_id)`
- `permissions_mask` (`u16`) bitset:
- bit 0: inspect
- bit 1: extract
- bit 2: build
- bit 3: upkeep
- `granted_by_adventurer_id`
- `grant_block`
- `revoke_block`
- `is_active`
- `policy_epoch`

### `ResourceShareRule`

- key: `(resource_key, recipient_adventurer_id)`
- `share_bp` (`u16`)
- `rule_kind` (`OUTPUT_ITEM`, `OUTPUT_ENERGY`, `FEE_ONLY`)
- `is_active`
- `policy_epoch`
- `updated_block`

### `ResourceDistributionNonce`

- key: `resource_key`
- `last_nonce` (`u64`) to enforce one-way distribution progression

## 7. Permission and Split Semantics

### 7.1 Access Evaluation

An action is allowed when:

1. caller controls the acting adventurer (existing owner guard), and
2. actor is controller of the resource OR has an active grant with required permission bit.

### 7.2 Split Evaluation

For each distributable output `gross`:

1. active rules matching `resource_key` and current `policy_epoch` are evaluated.
2. each recipient allocation uses floor math:
- `alloc_i = floor(gross * share_bp_i / 10_000)`
3. residual `gross - sum(alloc_i)` goes to the actor (or controller for fee-only paths).
4. invariant: `sum(alloc_i) <= gross`.

### 7.3 Share Cap Rules

- Total active `share_bp` for a `(resource_key, rule_kind)` cannot exceed `10_000`.
- If update would exceed cap, reject.

### 7.4 Ownership Transfer Rule

On area/hex controller transfer:

- `ResourcePolicy.controller_adventurer_id` is updated.
- `policy_epoch` increments.
- Existing grants and shares become stale automatically (epoch mismatch), no unbounded cleanup loop required.

## 8. Contract/API Surface (Proposed)

New contract: `sharing_manager_contract.cairo`.

### External API

- `upsert_resource_policy(controller_adventurer_id, resource_key, resource_kind, is_enabled) -> bool`
- `grant_resource_access(controller_adventurer_id, resource_key, grantee_adventurer_id, permissions_mask) -> bool`
- `revoke_resource_access(controller_adventurer_id, resource_key, grantee_adventurer_id) -> bool`
- `set_resource_share_rule(controller_adventurer_id, resource_key, recipient_adventurer_id, rule_kind, share_bp) -> bool`
- `clear_resource_share_rule(controller_adventurer_id, resource_key, recipient_adventurer_id, rule_kind) -> bool`
- `inspect_resource_permissions(resource_key, adventurer_id) -> u16`
- `inspect_resource_share(resource_key, recipient_adventurer_id, rule_kind) -> u16`

### Internal Integration Hooks

- `check_permission(resource_key, adventurer_id, required_mask) -> bool`
- `distribute_item_output(resource_key, actor_adventurer_id, item_id, gross_qty) -> distributed_qty`
- `distribute_energy_output(resource_key, actor_adventurer_id, gross_energy) -> distributed_energy`
- `on_controller_transfer(resource_key, new_controller_adventurer_id, now_block)`

## 9. Module Integrations

### 9.1 Mining

- `start_mining` checks sharing permission `extract` (or controller).
- `exit_mining` routes banked ore through `distribute_item_output`.
- Existing `grant_mine_access/revoke_mine_access` become compatibility wrappers that call sharing manager.

### 9.2 Harvesting

- `start_harvesting` checks sharing permission `extract` on plant area resource key.
- `complete_harvesting/cancel_harvesting` route minted yield via `distribute_item_output`.

### 9.3 Construction

- `start_construction` requires `build` permission.
- `pay_building_upkeep/repair_building` require `upkeep` permission.
- Optional `FEE_ONLY` rule_kind applies deterministic fee routing in energy terms.

### 9.4 Ownership / Claim-Defend

- On transfer events, call `on_controller_transfer` for each affected area resource key.
- Ensure no stale grants remain valid post-transfer.

## 10. Build Slices (TDD Order)

### Slice R1: Models + Pure Math

Files:

- `game/src/models/sharing.cairo` (new)
- `game/src/models.cairo` (register)
- `game/src/tests/unit/sharing_models_test.cairo` (new)
- `game/src/tests/unit/sharing_math_test.cairo` (new)

Tests:

- permission bit checks
- split floor math and residual handling
- share cap bounds
- epoch invalidation behavior

### Slice R2: Sharing Transition Library

Files:

- `game/src/systems/sharing_manager.cairo` (new, pure transitions)
- `game/src/tests/unit/sharing_manager_test.cairo` (new)

Tests:

- grant/revoke lifecycle
- share upsert/clear lifecycle
- permission resolution precedence
- reject paths (dead, not controller, invalid mask, share overflow)

### Slice R3: Sharing Contract + Events

Files:

- `game/src/events/sharing_events.cairo` (new)
- `game/src/events.cairo` (register)
- `game/src/systems/sharing_manager_contract.cairo` (new)
- `game/src/systems.cairo` (register)
- `game/src/tests/unit/sharing_events_test.cairo` (new)
- `game/src/tests/integration/sharing_manager_integration_test.cairo` (new)

Tests:

- event cardinality and payload checks
- state writes and replay behavior
- inspect endpoints

### Slice R4: Mining Integration

Files:

- `game/src/systems/mining_manager_contract.cairo`
- `game/src/tests/integration/mining_manager_integration_test.cairo`

Tests:

- granted miner can start/exit
- ungranted miner rejected
- split output allocation matches bp rules
- residual allocation correctness

### Slice R5: Harvesting Integration

Files:

- `game/src/systems/harvesting_manager_contract.cairo`
- `game/src/tests/integration/harvesting_manager_integration_test.cairo`

Tests:

- granted harvester can start/complete
- split minted yield correctness
- capacity edge cases under distribution

### Slice R6: Construction Integration

Files:

- `game/src/systems/construction_manager_contract.cairo`
- `game/src/tests/integration/construction_manager_integration_test.cairo`

Tests:

- collaborator `build/upkeep` permission checks
- fee-only routing behavior
- unauthorized actions rejected

### Slice R7: Transfer Coherence

Files:

- `game/src/systems/economic_manager_contract.cairo`
- `game/src/systems/ownership_manager_contract.cairo`
- `game/src/tests/integration/ownership_events_integration_test.cairo`
- `game/src/tests/integration/e2e_claim_transfer_buildings.cairo`

Tests:

- policy epoch increments on transfer
- pre-transfer grants invalid post-transfer
- new controller can regrant cleanly

### Slice R8: Cross-Loop E2E

Files:

- `game/src/tests/integration/e2e_shared_mine_ops.cairo` (new)
- `game/src/tests/integration/e2e_shared_harvest_ops.cairo` (new)
- `game/src/tests/integration/e2e_shared_build_ops.cairo` (new)

Tests:

- multi-actor cooperative loops
- deterministic split conservation
- no inflation/negative state under interleavings

## 11. Acceptance Criteria (v1)

1. Sharing permissions are enforced consistently across mining/harvesting/construction.
2. All distributed outputs conserve quantity/energy exactly (`sum allocations + residual == gross`).
3. Share cap and invalid-mask rejects are deterministic and fully tested.

## 12. Implementation Status (Current)

Completed in code:

- `R1`: models + sharing math + unit tests.
- `R2`: pure sharing transitions (`sharing_manager`) + unit tests.
- `R3`: sharing events + `sharing_manager_contract` + integration tests.
- `R4` (partial): mining compatibility wrappers now sync shared ACL rows; mining access resolution accepts shared extract grants.
- `R5`: harvesting access + split integration is complete:
- owned-area permission enforcement (`controller or granted extract`) at `start_harvesting`
- deterministic output-item split routing on `complete_harvesting` and `cancel_harvesting`
- recipient-capacity edge handling with conservation-preserving residual kept by actor
- integration coverage for collaborator access, split correctness, and capacity edge cases

Pending slices:

- `R6`: construction permission/fee integration.
- `R7`: controller transfer coherence hooks wired into ownership/economic claim flows.
- `R8`: cross-loop E2E scenarios for shared mine/harvest/build ops and conservation checks.
4. Ownership transfer invalidates prior grants/shares via epoch semantics.
5. Existing owner-authenticated adventurer control invariants remain intact.
6. Full test suite passes with new sharing tests included.

## 12. Rollout Strategy

1. Ship R1-R3 behind integration-only paths.
2. Integrate mining first (R4) for lowest-risk live validation.
3. Integrate harvesting and construction (R5-R6).
4. Enable transfer invalidation (R7) and run focused regression suite.
5. Ship E2E pack (R8), then full `snforge test` gate.

## 13. Test Commands (Target)

```bash
cd game
snforge test sharing_
snforge test mining_manager_integration_
snforge test harvesting_manager_integration_
snforge test construction_manager_integration_
snforge test e2e_shared_
snforge test
```

## 14. Immediate Next Task

Start Slice R1 by implementing `sharing.cairo` models and locking split math/epoch invariants with pure unit tests before any contract wiring.
