# `@gen-dungeon/torii-views` Package PRD

Status: Draft
Last updated: 2026-02-13
Owner: Data Platform

## 1. Package Goal

Ship a versioned, testable Torii SQL view package for explorer read workloads.
The package provides stable logical views so proxy and client packages are insulated from Torii physical schema details.

## 2. Canonical Contracts

Type and model authority:
- `../client/typescript/models.gen.ts`

Gameplay semantics authority:
- `../docs/02-spec/mvp-functional-spec.md`
- `../docs/02-spec/design-decisions.md`

## 3. Scope

### 3.1 In Scope

- SQL view definitions for explorer read patterns.
- Logical-to-physical schema mapping config.
- Optional coordinate/chunk index artifacts.
- Schema parity checker against generated model names/fields required by views.
- Test fixtures and query validation suite.

### 3.2 Out of Scope

- Renderer/client UI logic.
- Onchain contract write operations.
- Direct browser SQL access.

## 4. Package Outputs

- `sql/views/v1/*.sql`
- `sql/indexes/v1/*.sql`
- `sql/migrations/*.sql`
- `src/mapping/*.ts` (physical table mapping)
- `src/contracts/*.ts` (typed query contracts for proxy)
- `src/parity/check-schema.ts`
- `tests/views/*.test.ts`

## 5. Logical View Catalog (v1)

Note: physical table names differ by Torii deployment/config.
All SQL shipped as logical templates resolved through mapping config.

### 5.1 `explorer_hex_base_v1`

Purpose:
- one row per discovered/onchain-known hex with core static + dynamic fields

Columns:
- `hex_coordinate`
- `biome`
- `discovery_block`
- `discoverer`
- `area_count`
- `decay_level`
- `current_energy_reserve`
- `last_decay_processed_block`
- `owner_adventurer_id`

### 5.2 `explorer_hex_render_v1`

Purpose:
- renderer-focused minimal payload for chunk fetch

Columns:
- `hex_coordinate`
- `biome`
- `owner_adventurer_id`
- `decay_level`
- `is_claimable`
- `active_claim_count`
- `adventurer_count`
- `plant_count`

### 5.3 `explorer_hex_inspect_v1`

Purpose:
- complete inspect payload seed for one hex

Columns include all fields needed to hydrate:
- `Hex`
- `HexArea`
- `AreaOwnership`
- `HexDecayState`
- active `ClaimEscrow`
- `PlantNode`
- `HarvestReservation` summary
- adventurer presence summaries

### 5.4 `explorer_area_control_v1`

Purpose:
- resolve single-controller-per-hex ownership for query and validation

Columns:
- `hex_coordinate`
- `control_area_id`
- `controller_adventurer_id`
- `area_count`
- `ownership_consistent` (boolean check)

### 5.5 `explorer_claim_active_v1`

Purpose:
- current actionable claim states (ACTIVE only, non-expired)

Columns:
- `hex_coordinate`
- `claim_id`
- `claimant_adventurer_id`
- `energy_locked`
- `created_block`
- `expiry_block`

### 5.6 `explorer_adventurer_presence_v1`

Purpose:
- adventurer position/liveness summary for overlays and search

Columns:
- `adventurer_id`
- `owner`
- `is_alive`
- `current_hex`
- `energy`
- `activity_locked_until`

### 5.7 `explorer_plant_status_v1`

Purpose:
- plant/resource overlay and inspect source

Columns:
- `plant_key`
- `hex_coordinate`
- `area_id`
- `plant_id`
- `species`
- `current_yield`
- `reserved_yield`
- `max_yield`
- `regrowth_rate`
- `stress_level`
- `health`

### 5.8 `explorer_event_tail_v1`

Purpose:
- stable recent event stream query for inspect timeline

Columns:
- `block_number`
- `tx_index`
- `event_index`
- `event_name`
- `hex_coordinate` (nullable)
- `adventurer_id` (nullable)
- `payload_json`

## 6. Coordinate and Chunk Indexing Strategy

Problem:
- Core model key uses encoded cube `felt252`.
- Chunk queries require decoded `(q,r,s)` and chunk membership.

Plan:
- package includes optional mirror table + sync routine:
  - `explorer_hex_coord_index_v1(hex_coordinate, q, r, s, chunk_q, chunk_r, updated_block)`
- mirror updates occur from ws patch ingestion in proxy, or periodic backfill job.
- chunk endpoints query this index then join `explorer_hex_render_v1`.

Default chunk params:
- `chunk_size = 32`
- prefetch handled in proxy/client, not in SQL view.

## 7. Query Contracts for Proxy

### 7.1 `getChunks(keys[])`

Input:
- list of chunk keys (`chunk_q:chunk_r`)

Output per chunk:
- list of `explorer_hex_render_v1` rows
- optional summary counts (`claims`, `adventurers`)

### 7.2 `getHexInspect(hex_coordinate)`

Output:
- one composite payload assembled from `explorer_hex_inspect_v1` and related detail views

### 7.3 `search`

Modes:
- by coordinate
- by owner/controller
- by adventurer id

Outputs:
- canonical jump target coordinates + summary metadata

### 7.4 `getEventTail(filters)`

Filters:
- `hex_coordinate`
- `adventurer_id`
- `limit`

Order:
- `(block_number DESC, tx_index DESC, event_index DESC)`

## 8. Schema Drift and Versioning

Rules:
- Views are immutable once shipped (`*_v1`).
- Breaking change requires new view version (`*_v2`) and proxy contract bump.
- Package publishes `schema_version` manifest consumed by proxy and client.

Parity checks:
- parse generated model interfaces from `models.gen.ts`
- assert required fields for each view mapping still exist
- fail CI on mismatch

## 9. Example Logical SQL (Template)

```sql
-- logical template: explorer_hex_render_v1
CREATE VIEW explorer_hex_render_v1 AS
SELECT
  h.coordinate AS hex_coordinate,
  h.biome AS biome,
  ac.controller_adventurer_id AS owner_adventurer_id,
  COALESCE(ds.decay_level, 0) AS decay_level,
  CASE WHEN COALESCE(ds.decay_level, 0) >= 80 THEN 1 ELSE 0 END AS is_claimable,
  COALESCE(claims.active_claim_count, 0) AS active_claim_count,
  COALESCE(ap.adventurer_count, 0) AS adventurer_count,
  COALESCE(ps.plant_count, 0) AS plant_count
FROM {{Hex}} h
LEFT JOIN explorer_area_control_v1 ac ON ac.hex_coordinate = h.coordinate
LEFT JOIN {{HexDecayState}} ds ON ds.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT hex_coordinate, COUNT(*) AS active_claim_count
  FROM explorer_claim_active_v1
  GROUP BY hex_coordinate
) claims ON claims.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT current_hex AS hex_coordinate, COUNT(*) AS adventurer_count
  FROM explorer_adventurer_presence_v1
  GROUP BY current_hex
) ap ON ap.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT hex_coordinate, COUNT(*) AS plant_count
  FROM explorer_plant_status_v1
  GROUP BY hex_coordinate
) ps ON ps.hex_coordinate = h.coordinate
WHERE h.is_discovered = 1;
```

`{{ModelName}}` placeholders are resolved by mapping config.

## 10. Test Plan (Package)

Unit tests:
- mapping resolver correctness
- schema manifest parser
- contract output typing

Integration tests with seeded db:
- each logical view returns expected rows for curated world scenarios
- claim expiry semantics respected
- controller consistency flag catches deliberate data inconsistency
- event ordering stable under same-block multi-event cases

Performance tests:
- chunk query latency under target cardinality
- inspect query latency with high area/plant density

## 11. Operational Plan

- Proxy loads view manifest at startup.
- Startup fails fast if expected view version missing.
- Health endpoint reports:
  - view version
  - mapping version
  - parity check build hash

## 12. Deliverables and Exit Criteria

Deliverables:
- published `@gen-dungeon/torii-views` package
- SQL templates + mapping config + tests
- version manifest consumed by proxy

Exit criteria:
- all package tests green
- schema parity green against current generated models
- proxy integration tests pass for chunks, inspect, search, event tail
- documented migration path for future view versions
