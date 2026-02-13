# Design Decisions Log

This file tracks resolved design choices that align the documentation set.

Status values:
- `open`: needs owner decision
- `proposed`: recommended default, pending owner confirmation
- `locked`: confirmed and authoritative

Decision lock date: 2026-02-11

## DD-001 - MVP Scope Boundary
- Status: `locked`
- Context: MVP spec excludes mining/crafting/buildings/AI/advanced hooks, but other docs describe them as active.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/05-modules/mining.md`, `docs/05-modules/construction.md`, `docs/06-platform/ai-service-architecture.md`, `docs/03-architecture/hooks-and-permissions.md`
- Options:
1. MVP is strictly `mvp-functional-spec` only; all other systems are post-MVP design.
2. Expand MVP to include selected non-spec systems now.
- Locked decision: Option 1.

## DD-002 - Spawn Coordinate Canonical Rule
- Status: `locked`
- Context: Some docs use `(0,0)`, others use `2**31` centered unsigned coordinates.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/01-foundation/game-design-v0.3.md`, `docs/01-foundation/world-generation-and-systems.md`
- Options:
1. Canonical gameplay coordinates use signed axial `(0,0)` spawn.
2. Canonical gameplay coordinates use unsigned storage-centered `(2**31, 2**31)` spawn.
3. Gameplay API uses origin-centered coordinates while storage encodes with unsigned offset.
- Locked decision: Option 3.

## DD-003 - Ownership Model in MVP
- Status: `locked`
- Context: MVP spec says model parity only; NFT/ERC-721 is described in architecture docs.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/03-architecture/ownership-and-nfts.md`
- Options:
1. MVP uses `Ownership.AreaOwnership` model only (no ERC-721 contract).
2. MVP includes full ERC-721 mint/transfer/revenue integration.
- Locked decision: Option 1.

## DD-004 - Permadeath in MVP
- Status: `locked`
- Context: Vision docs make permadeath core; MVP spec previously omitted death.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/01-foundation/game-design-v0.3.md`, `docs/01-foundation/world-generation-and-systems.md`
- Options:
1. Permadeath deferred post-MVP.
2. Permadeath enabled in MVP.
- Locked decision: Option 2.

## DD-005 - Discovery Privacy Model
- Status: `locked`
- Context: Commit-reveal appears in vision docs; direct first-visit discovery appears in system docs.
- References: `docs/01-foundation/game-design-v0.3.md`, `docs/01-foundation/world-generation-and-systems.md`, `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Implement commit-reveal in MVP.
2. Use direct discovery in MVP; commit-reveal post-MVP.
- Locked decision: Option 2.

## DD-006 - HexCoordinate Encoding
- Status: `locked`
- Context: Spec left axial/cube and packing unresolved.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Axial `(q,r)` packed into `felt252`.
2. Cube `(x,y,z)` packed into `felt252`.
3. Axial in API + explicit codec module for storage/indexing.
- Locked decision: Option 2.

## DD-007 - Documented Implementation Status
- Status: `locked`
- Context: Architecture review uses completion labels while repository state is documentation-centric.
- References: `docs/03-architecture/architecture-review.md`
- Options:
1. Keep "completed/in-progress" labels as historical intent.
2. Re-label status as design maturity only until code is present.
- Locked decision: Option 2.

## DD-008 - Numeric Semantics (Rounding, Units)
- Status: `locked`
- Context: Several formulas are ambiguous for integer math and percentages.
- References: `docs/01-foundation/world-generation-and-systems.md`, `docs/04-economy/economic-stability.md`
- Options:
1. Define all percentages in basis points (`1e4`) and floor rounding.
2. Define all percentages in fixed-point (`1e6`) and banker/nearest rounding.
3. Mixed scheme per system.
- Locked decision: Option 1.

## DD-009 - Canonical Path and Link Consistency
- Status: `locked`
- Context: Some references still point to pre-reorg paths.
- References: `docs/03-architecture/architecture-review.md`
- Options:
1. Enforce post-reorg path consistency now.
2. Keep legacy paths and handle later.
- Locked decision: Option 1.

## DD-010 - `discover_hex` Replay Semantics
- Status: `locked`
- Context: Spec/action text previously mixed "hex not yet discovered" with acceptance behavior requiring repeat calls to return the same record.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Revert on already-discovered hex.
2. Idempotent replay returns existing record without mutating state.
- Locked decision: Option 2, with no energy spend and no event emission on replay.

## DD-011 - `discover_area` Signature and AreaId Derivation
- Status: `locked`
- Context: API previously omitted area identity input while rules referred to undiscovered areas.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Keep implicit "next area" discovery behavior.
2. Require explicit `area_index` and deterministic `AreaId` derivation.
- Locked decision: Option 2. API is `discover_area(adventurer_id, hex, area_index)` and `AreaId = hash(hex, area_index)`.

## DD-012 - Ownership Scope for Hex-Level Maintenance/Claim
- Status: `locked`
- Context: Ownership is modeled per area, but maintenance/decay/claim are hex-level.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Allow multiple area owners per hex in MVP.
2. Enforce single-controller-per-hex semantics in MVP.
- Locked decision: Option 2. Controller is owner of control area `area_index = 0`; all area ownership rows in that hex align to controller; successful claim/defend updates all rows in that hex.

## DD-013 - Energy Regeneration Schedule
- Status: `locked`
- Context: Regen timing was unresolved (per-block vs action-based).
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Action-based fixed regen only.
2. Per-block lazy regen using block delta.
- Locked decision: Option 2. Regen is deterministic per block delta, applied lazily on `regenerate_energy` and before energy-spending actions, capped at `max_energy`.

## DD-014 - Conversion Volume Penalty Window
- Status: `locked`
- Context: Volume penalty window and update semantics were unresolved.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/04-economy/economic-stability.md`
- Options:
1. Undefined/ad hoc window.
2. Fixed rolling window with explicit formula.
- Locked decision: Option 2. Rolling 100-block window per `item_type`; `penalty_bp = min(5000, floor(units_converted_in_window / 10) * 100)`.

## DD-015 - Backpack Capacity Rule in MVP
- Status: `locked`
- Context: Open question remained on slot vs weight trade-off.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Weight-only capacity.
2. Weight + slot capacity.
- Locked decision: Option 1 for MVP (weight-only). Slot caps are post-MVP.

## DD-016 - Harvest Reservation on Start
- Status: `locked`
- Context: Concurrent `start_harvesting` calls can over-commit plant yield if inventory checks happen without reservation writes.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Check availability only at completion time; no start-time reservation.
2. Reserve yield at `start_harvesting` and release/settle reservation on completion/cancel/death.
- Locked decision: Option 2. MVP requires reservation-based accounting with `available_yield = current_yield - reserved_yield`.

## DD-017 - Claim Escrow Lock Timing
- Status: `locked`
- Context: Claim energy commitment timing was ambiguous, enabling potential double-use of the same balance during pending claims.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Deduct energy only when claim resolves.
2. Deduct and escrow energy at `initiate_hex_claim`.
- Locked decision: Option 2. Claim energy is locked immediately and excluded from available spend until settlement.

## DD-018 - Claim Attempt Expiry and Refund Lifecycle
- Status: `locked`
- Context: Pending claim attempts need deterministic timeout and refund behavior to avoid indefinite locks and stale claim state.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. No explicit timeout; claims stay pending until manually resolved.
2. Enforce fixed expiry window with automatic transition and refund semantics.
- Locked decision: Option 2. ACTIVE escrow expires at deadline and refunds exactly once; non-winning escrows refund on resolution.

## DD-019 - Decay Processing Checkpoint Idempotency
- Status: `locked`
- Context: Re-running decay processing for the same elapsed period can double-charge reserves if no explicit processed-window checkpoint exists.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Recompute from payment timestamp each call.
2. Track and advance a dedicated `last_decay_processed_block` checkpoint.
- Locked decision: Option 2. Repeated `process_hex_decay` calls without newly elapsed periods are no-ops.

## DD-020 - Dead Adventurer Global State-Change Guard
- Status: `locked`
- Context: Permadeath is defined for MVP, but guard coverage across all state-changing entrypoints must be explicit.
- References: `docs/02-spec/mvp-functional-spec.md`
- Options:
1. Enforce alive checks only in selected systems.
2. Enforce alive checks for every state-changing entrypoint.
- Locked decision: Option 2. Dead adventurers are rejected globally, and `kill_adventurer` settles active reservations/escrows.

## DD-021 - Deterministic Discovery and Harvest Initialization Source
- Status: `locked`
- Context: Current contracts accept caller-provided discovery and harvesting initialization payloads (`biome`, `area_count`, `area_type`, `resource_quality`, `size_category`, `species`, `max_yield`, `regrowth_rate`), which breaks deterministic world generation guarantees.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/deterministic-generation-plan.md`
- Options:
1. Keep caller-provided content payloads and validate loosely.
2. Remove content payload parameters and derive all world/harvest init attributes from deterministic generation.
- Locked decision: Option 2. `discover_hex`, `discover_area`, and `init_harvesting` materialize deterministic generated values only.

## DD-022 - Noise Backend for Deterministic World Generation
- Status: `locked`
- Context: Deterministic generation requires a canonical noise implementation for biome/area/plant profiling.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/deterministic-generation-plan.md`, `https://github.com/influenceth/cubit`
- Options:
1. Custom hash-only noise implementation.
2. Cubit-based deterministic noise implementation.
- Locked decision: Option 2. Cubit is the canonical deterministic noise backend for MVP generation rollout.

## DD-023 - Domain-Separated Seed Tree for Generation
- Status: `locked`
- Context: Without explicit domain separation, coordinate/id collisions can leak state between generation stages.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/deterministic-generation-plan.md`
- Options:
1. Reuse a shared seed derivation path across hex/area/plant generation.
2. Use versioned domain-separated derivations per generation stage.
- Locked decision: Option 2. Generation uses domain tags (`HEX_V1`, `AREA_V1`, `PLANT_V1`, `GENE_V1`) over deterministic hash derivation.

## DD-024 - Canonical Biome Count and Roster
- Status: `locked`
- Context: Earlier deterministic generation shipped with a smaller biome surface; expansion requires a single canonical roster for balancing and test determinism.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/biome-20-expansion-checklist.md`
- Options:
1. Keep the original 5-biome MVP surface.
2. Expand MVP deterministic generation to 20 playable biomes with a canonical roster.
- Locked decision: Option 2. Canonical playable biome roster is 20 biomes: Plains, Forest, Mountain, Desert, Swamp, Tundra, Taiga, Jungle, Savanna, Grassland, Canyon, Badlands, Volcanic, Glacier, Wetlands, Steppe, Oasis, Mire, Highlands, Coast.

## DD-025 - Deterministic Plant Slot Bounds and `plant_id` Guard
- Status: `locked`
- Context: Harvest init must be bounded per discovered area to prevent invalid plant addressing and profile drift.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/biome-20-expansion-checklist.md`
- Options:
1. Allow unbounded `plant_id` on init and rely on best-effort generation.
2. Persist deterministic per-area slot count and enforce `plant_id` bounds at init.
- Locked decision: Option 2. `HexArea.plant_slot_count` is deterministic from area generation and `init_harvesting` enforces `0 <= plant_id < plant_slot_count`.

## DD-026 - Data-Driven Biome Profile Source of Truth
- Status: `locked`
- Context: Duplicated biome behavior tables (upkeep, plant-field thresholds, species rolls) create drift risk.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/biome-20-expansion-checklist.md`
- Options:
1. Keep per-system hardcoded biome mappings.
2. Centralize biome behavior in a single profile source consumed by generation and decay logic.
- Locked decision: Option 2. Biome upkeep/threshold/species behavior must come from one shared profile table.

## DD-027 - Generation Version 2 Rollout Rule
- Status: `locked`
- Context: Biome expansion and slot-bound rules change generation semantics; rollout needs version isolation for deterministic replay safety.
- References: `docs/02-spec/mvp-functional-spec.md`, `docs/07-delivery/biome-20-expansion-checklist.md`
- Options:
1. Mutate generation semantics in-place under version 1.
2. Activate generation version 2 and enforce v2-only runtime behavior on generation-dependent entrypoints.
- Locked decision: Option 2. Active generation key is version `2`; harvesting initialization requires persisted v2 area slot data (`plant_slot_count`) and does not fallback to legacy zero-slot rows.
