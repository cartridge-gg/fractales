# Gen Dungeon Explorer Client PRD (WebGL + Torii SQL)

Status: Draft
Last updated: 2026-02-13
Owners: Client Platform + Game Infra

## 1. Purpose

Define a build-ready product and engineering scope for a read-only world explorer for `gen-dungeon`.
The explorer is for human players/spectators while gameplay actions remain agent/onchain driven.

This PRD is explicitly aligned to:
- deterministic world/state rules from game contracts
- near-real-time indexing through Torii SQL + websocket streaming
- WebGL-first rendering (raw WebGL2), with minimal DOM controls
- `@client` codegen as canonical type source of truth

## 2. Canonical Inputs

- `../docs/02-spec/design-decisions.md`
- `../docs/02-spec/mvp-functional-spec.md`
- `../docs/07-delivery/dojo-mvp-prd.md`
- `../docs/07-delivery/dojo-mvp-implementation-checklist.md`
- `../docs/07-delivery/agent-handoff.md`
- `../client/typescript/models.gen.ts`
- `../client/typescript/contracts.gen.ts`
- `../client/docs/p3-renderer-architecture.md` (renderer pass/shader/fixture contracts)
- `../client/docs/p5-perf-runbook.md` (SLOs, dashboards, alerts, mitigation)

## 3. Product Scope

### 3.1 In Scope (v1)

- Read-only interactive world explorer for desktop and mobile web.
- Strict top-down navigation: pan + zoom only (no rotate/tilt).
- Infinite world support via chunked loading.
- Default load strategy: discovered/onchain-touched hexes only.
- Hex inspection panel with all available model fields.
- Overlay layers:
  - biome
  - ownership/controller
  - claim/escrow state
  - adventurer presence
  - plant/resource state
  - decay/maintenance state
- Search and jump:
  - by hex coordinate
  - by owner/adventurer id
  - by agent/adventurer presence
- Near-real-time updates from websocket, freshness target under 2s p95.
- Visual style: black-and-white terminal line-art, ASCII flavor.

### 3.2 Out of Scope (v1)

- Human-triggered onchain writes/transactions from explorer.
- Time controls, replay, or historic block scrubbing.
- 3D free camera rotation.
- Rich asset/art pipeline (textures, meshes, animation rigs).
- Non-WebGL scene engines.

## 4. Users and Jobs

### 4.1 Primary Users

- Spectators tracking live world evolution.
- Players monitoring territory, claims, and resource zones.
- Internal operators debugging live world state and indexing behavior.

### 4.2 Jobs To Be Done

- "Show me where activity is happening now."
- "Let me inspect one hex and understand all relevant state."
- "Let me quickly jump to an owner/adventurer/coordinate of interest."
- "Let me trust what I see is current and committed onchain state."

## 5. Product Requirements

### 5.1 Navigation and Viewport

- Pan at 60hz input handling with frame-decoupled camera updates.
- Zoom bounds must preserve readable hex/cell boundaries at min and max zoom.
- Viewport computes required chunk set + 1 ring prefetch.

### 5.2 Inspection

Selecting a hex must expose all available fields from these model families:
- `Hex`, `HexArea`, `AreaOwnership`
- `HexDecayState`, `ClaimEscrow`
- `PlantNode`, `HarvestReservation`
- adventurer presence from `Adventurer` and current position links
- related event tail for recent state changes

### 5.3 Realtime

- Websocket stream is primary.
- HTTP snapshot fetch is fallback and reconnect recovery path.
- Client applies updates in strict order using `(sequence, block_number, tx_index, event_index)`.
- UI exposes sync status (`live`, `catching_up`, `degraded`).

### 5.4 Mobile + Desktop

- Mobile support required for modern iOS Safari and Android Chrome (last 2 major versions).
- Target frame rate: 30 FPS minimum on baseline mobile profile.
- Adaptive quality mode must reduce draw complexity before dropping correctness.

## 6. Technical Constraints

- Renderer must use raw `WebGL2` APIs only.
- Utility libraries are allowed (math, compression, buffer helpers), but no scene abstraction engines.
- Minimal DOM only for non-canvas controls:
  - layer toggles
  - inspect panel
  - search inputs
  - connection status

## 7. Package Architecture (Non-Circular)

Proposed package split:

1. `@gen-dungeon/explorer-types`
- Responsibility:
  - Re-export canonical generated types from `@client`.
  - Define explorer DTOs (chunk payloads, patch envelopes, render view models).
- Constraints:
  - No runtime side effects.
  - No network/WebGL dependencies.

2. `@gen-dungeon/torii-views`
- Responsibility:
  - Versioned SQL view definitions and query contracts for explorer read patterns.
  - Optional index/mirror artifacts for coordinate/chunk lookup.
  - Schema parity tooling against `@client` generated types.
- Constraints:
  - SQL and metadata package only.
  - No renderer/data-store logic.

3. `@gen-dungeon/explorer-data`
- Responsibility:
  - Node proxy client (HTTP + WS protocol).
  - Chunk cache and normalized state store.
  - Patch ordering, dedupe, reconnect/resync.
  - Selector/query layer consumed by renderer/app.
- Constraints:
  - No direct DOM/WebGL rendering code.

4. `@gen-dungeon/explorer-renderer-webgl`
- Responsibility:
  - Camera, input mapping, culling, draw passes, picking.
  - ASCII/line-art render pipeline.
  - Overlay compositing.
- Constraints:
  - Pure rendering + interaction translation only.
  - No network and no Torii/proxy knowledge.

5. `@gen-dungeon/explorer-app`
- Responsibility:
  - Thin shell wiring data + renderer.
  - Minimal DOM controls and URL/deep-link handling.
- Constraints:
  - Keep app logic orchestration-only.

Dependency direction:
- `@client` -> `@gen-dungeon/explorer-types`
- `@client` -> `@gen-dungeon/torii-views`
- `@gen-dungeon/explorer-types` -> `@gen-dungeon/explorer-data`
- `@gen-dungeon/explorer-types` -> `@gen-dungeon/explorer-renderer-webgl`
- `@gen-dungeon/explorer-data` + `@gen-dungeon/explorer-renderer-webgl` + `@gen-dungeon/explorer-types` -> `@gen-dungeon/explorer-app`

## 8. Torii SQL + Node Proxy Design

### 8.1 Why a Proxy Layer

- Browser should not have unrestricted SQL/indexer exposure.
- Enables query shaping for chunk + inspect use cases.
- Allows rate limits, caching, and replay-safe websocket fanout.
- Provides a stable contract independent of Torii physical schema drift.

### 8.2 Node Proxy Responsibilities

- Serve chunk snapshots using explorer-focused views.
- Stream ordered patches over websocket.
- Detect stream gaps and emit `RESYNC_REQUIRED`.
- Maintain optional coordinate/chunk index mirror if Torii schema does not expose decoded coordinates.

### 8.3 Proxy API (v1)

`GET /v1/chunks?keys=<k1,k2,...>&version=<schema_version>`
- Returns chunk-scoped render payloads.

`GET /v1/hex/:hex_coordinate`
- Returns complete inspect payload for one hex.

`GET /v1/search?coord=<felt>|owner=<id>|adventurer=<id>`
- Returns jump targets and summary rows.

`GET /v1/status`
- Returns head block, stream lag, schema/view version.

`WS /v1/stream`
- Emits ordered patches and periodic heartbeats.

### 8.4 Websocket Envelope

```json
{
  "schema_version": "explorer-v1",
  "sequence": 934455,
  "block_number": 1283321,
  "tx_index": 4,
  "event_index": 2,
  "kind": "hex_patch",
  "payload": {
    "hex_coordinate": "0x...",
    "changed": {
      "decay_level": 81,
      "current_energy_reserve": 120
    }
  },
  "emitted_at_ms": 1739485000123
}
```

Ordering guarantees:
- strictly monotonic `sequence` per stream partition
- deterministic tie-break by block/tx/event indexes

Gap handling:
- if sequence jump > 1, client transitions to `catching_up`
- fetch snapshot for visible+prefetch chunks
- replay buffered patches newer than snapshot watermark

## 9. Chunking and Spatial Strategy

### 9.1 Defaults

- `chunk_size = 32`
- `prefetch_ring = 1`
- `max_chunks_in_memory = 96` mobile, `192` desktop
- LRU eviction with pinning for selected/inspected chunk

### 9.2 Coordinate Handling

- Canonical coordinate key is encoded cube `felt252` (`Hex.coordinate` / `hex_coordinate`).
- Proxy resolves chunk membership from decoded cube/axial coordinates.
- If Torii storage cannot directly query by decoded coords, proxy maintains `hex_coordinate -> (q,r,s,chunk_q,chunk_r)` mirror index updated from stream.

### 9.3 Default World Loading

- Initial camera boot queries chunks around spawn/default anchor.
- Only discovered/onchain-touched hexes are returned/rendered.
- Undiscovered empty cells are represented implicitly in renderer grid, not fetched as full records.

## 10. Rendering Architecture (Raw WebGL2)

### 10.1 Draw Passes

1. Background grid pass (line-art hex lattice).
2. Hex state pass (instanced outlines/fills by active overlay mode).
3. Overlay pass (ownership/claims/decay/resource indicators).
4. ASCII glyph pass (labels and compact values via atlas texture).
5. Picking pass (offscreen id buffer for hit-testing).

### 10.2 Visual Language

- Monochrome palette (`#000`, `#fff`, with optional gray ramp only).
- Terminal-like glyph aesthetics.
- Emphasize contour and symbol over texture.

### 10.3 Interaction

- Pointer/touch panning.
- Wheel/pinch zoom.
- Tap/click selection.
- No camera rotation.

## 11. Data Model and Type Ownership

Source of truth:
- `../client/typescript/models.gen.ts`

Rules:
- Explorer DTOs may compose generated types but may not redefine canonical fields.
- Any schema drift requires regeneration in `@client` first, then explorer updates.
- `@gen-dungeon/torii-views` must include a schema parity check against `models.gen.ts` names and required fields used by views.

## 12. Performance and Reliability Requirements

### 12.1 Freshness

- Target `p95 < 2s` from block inclusion to explorer-visible update.

### 12.2 Frame Rate

- `>= 30 FPS` on baseline mobile profile in active exploration mode.

### 12.3 Memory

- Respect chunk budget caps and evict deterministically.
- Avoid unbounded event buffers.

### 12.4 Recovery

- Network drop must recover without full page reload.
- Reconnect and replay must preserve monotonic state application.

## 13. Observability

Client metrics:
- current fps
- frame time percentile
- loaded chunk count
- ws lag (head block - local applied block)
- patch apply queue depth

Proxy metrics:
- chunk query latency p50/p95
- websocket delivery lag
- resync frequency
- view query error rate

## 14. Security and Abuse Controls

- Proxy enforces request quotas and burst limits.
- Search endpoints require bounded pagination/limits.
- No raw SQL exposure to browser clients.
- WS sessions authenticated or keyed as needed for rate shaping.

## 15. Delivery Plan

### Milestone P0: Foundations

- Create package skeletons and dependency graph.
- Lock schema/versioning contract between `@client` and explorer packages.
- Define proxy API + websocket envelope types.

Exit criteria:
- all package build targets compile
- contract test stubs exist and fail intentionally (TDD red)

### Milestone P1: Torii Views + Proxy Read Path

- Implement `@gen-dungeon/torii-views` logical views v1.
- Implement proxy chunk and inspect endpoints.
- Implement proxy websocket envelope and ordering.

Exit criteria:
- seeded integration tests prove view correctness
- chunk and inspect endpoints satisfy typed contracts

### Milestone P2: Data Store + Chunk Cache

- Build `@gen-dungeon/explorer-data` normalized store.
- Add chunk lifecycle management and reconnect/resync.
- Add search/jump query selectors.

Exit criteria:
- deterministic replay tests pass
- cache eviction tests pass under load

### Milestone P3: WebGL Renderer Core

- Implement top-down camera, grid pass, hex pass, picking pass.
- Implement overlays and line-art style baseline.

Exit criteria:
- render integration tests pass on desktop + mobile emulation
- inspect selection correctness proven by picking tests

### Milestone P4: App Shell and UX Completion

- Wire minimal DOM controls.
- Implement all layer toggles and inspect panel.
- Implement sync state indicators and deep-linking.

Exit criteria:
- full read-only spectator flow acceptance passes

### Milestone P5: Hardening and Perf

- Optimize instancing/culling/atlas batching.
- Tune mobile quality knobs.
- Add telemetry dashboards and runbooks.

Exit criteria:
- p95 freshness under 2s
- baseline mobile sustained 30 FPS
- hardening gate passes via `bun run test:perf-smoke`
- CI publishes `artifacts/p5-hardening-gate-report.json`

## 16. Risks and Mitigations

Risk: Torii physical schema drift breaks SQL view assumptions.
- Mitigation: logical-to-physical mapping layer and parity tests against generated model names.

Risk: sequence gaps under websocket fanout.
- Mitigation: explicit resync protocol + snapshot watermarking.

Risk: mobile GPU bottlenecks with overlays.
- Mitigation: adaptive overlay simplification and batched instancing.

Risk: infinite-world memory growth.
- Mitigation: strict LRU and chunk budget hard caps.

## 17. Definition of Done (v1)

- All listed in-scope workflows are available.
- Explorer reads all required fields from canonical generated model contracts.
- Proxy + views are packaged and versioned.
- Tests in TDD plan pass for all packages.
- Performance and freshness SLOs are met in staging.
