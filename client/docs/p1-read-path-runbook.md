# Explorer P1 Read-Path Runbook

Status: Draft  
Last updated: 2026-02-17  
Owners: Client Platform + Game Infra

## 1. Scope

This runbook covers P1 read-path operation for:
- `@gen-dungeon/torii-views` v1 logical views
- `@gen-dungeon/explorer-proxy-node` read endpoints and stream contract
- sidebar inspect payload/read-path stability used by `@gen-dungeon/explorer-app`

Covered routes:
- `GET /v1/chunks`
- `GET /v1/hex/:hex_coordinate`
- `GET /v1/search`
- `GET /v1/status`
- websocket stream contract (`resync_required` on source gaps)

## 2. Startup Checks

Run from `client/`:

```bash
bun install
bun run typecheck
bun run test
```

Required package checks:
- `torii-views` tests:
  - SQL contract coverage (`view-contracts.red.test.ts`)
  - view shape coverage (`sql-shape.red.test.ts`)
  - seeded semantics coverage (`sql-semantics.red.test.ts`)
- `explorer-proxy-node` tests:
  - API adapter contracts (`api.red.test.ts`)
  - HTTP route contracts (`http-routes.red.test.ts`)
  - websocket contract (`ws-stream.red.test.ts`)
- sidebar operations smoke checks:
  - app flows/inspect rendering (`flow.red.test.ts`, `inspect-format.red.test.ts`)
  - runtime hydration (`live-runtime.red.test.ts`)

Sidebar-focused validation command:

```bash
bun run typecheck && bun run test:app && bun run test:proxy
```

## 3. Version and Contract Invariants

Must stay true:
- schema version remains `explorer-v1` in proxy responses and stream envelopes.
- `toriiViewsManifestV1` IDs are one-to-one with shipped `sql/views/v1/*.sql`.
- `explorer_hex_render_v1` remains discovered-only.
- `explorer_claim_active_v1` keeps ACTIVE filtering (`status = 1`).
- stream emits `resync_required` before patch emission when `sourceSequence` gaps are detected.
- inspect payload includes mining families:
  - `mineNodes`
  - `miningShifts`
  - `mineAccessGrants`
  - `mineCollapseRecords`
- selected inspect refreshes on operation-relevant patches when payload carries selected-hex coordinates.

## 4. Route Contract Summary

### `GET /v1/chunks?keys=<k1,k2,...>`

- Requires `keys` query parameter.
- Returns:
  - `200` with `{ schemaVersion, chunks }`
  - `400` for missing/invalid keys

### `GET /v1/hex/:hex_coordinate`

- Requires coordinate path segment.
- Returns:
  - `200` inspect payload (`HexInspectPayload`)
  - `400` for malformed coordinate path

Sidebar operations requirement:
- payload must preserve mining rows and deterministic event-tail merge for compact operations cards.

### `GET /v1/search?coord|owner|adventurer=<value>[&limit=n]`

- Exactly one mode is required.
- Optional positive integer `limit`.
- Returns:
  - `200` with `{ schemaVersion, results }`
  - `400` for invalid mode combination/limit

### `GET /v1/status`

- Returns stream and head metadata (`schemaVersion`, `headBlock`, `lastSequence`, `streamLagMs`).

## 5. Websocket Contract Summary

Input assumptions:
- producer ingests rows with `(sourceSequence, blockNumber, txIndex, eventIndex, kind, payload)`.

Output behavior:
- patch rows are emitted in deterministic `(block, tx, event)` order.
- output `sequence` is strictly monotonic.
- when `sourceSequence` jumps, emit `kind = resync_required` before next patch.

## 6. Common Failure Modes and Actions

### Missing view/table mappings

Symptoms:
- view tests fail on shape/semantics
- proxy read routes return 400/500 during query execution

Actions:
1. verify `toriiViewsManifestV1` and SQL file presence/parity.
2. verify physical mapping names in `torii-views/src/mapping.ts`.
3. run `bun run --filter @gen-dungeon/torii-views test`.

### Route validation drift

Symptoms:
- `/v1/chunks` and `/v1/search` reject valid requests or accept invalid ones.

Actions:
1. review parser logic in `explorer-proxy-node/src/http-mapping.ts`.
2. run `bun run --filter @gen-dungeon/explorer-proxy-node test`.

### Stream sequence anomalies

Symptoms:
- client patch apply stalls or duplicate/out-of-order behavior.

Actions:
1. inspect stream state from `createExplorerProxyStream().snapshot()`.
2. validate gap behavior in `ws-stream.red.test.ts`.
3. ensure producer sends monotonic `sourceSequence` per stream partition.

### Sidebar inspect not updating on live operations

Symptoms:
- selected hex inspect remains stale after mining/harvest/claim/adventurer updates.

Actions:
1. verify patch payload includes hex-bearing fields (`hexCoordinate`, `hex_coordinate`, `current_hex`).
2. validate refresh behavior in `explorer-app/tests/flow.red.test.ts`.
3. run `bun run --filter @gen-dungeon/explorer-app test`.

### Dense inspect cards silently truncate rows

Symptoms:
- large row sections clip entries without user-visible notice.

Actions:
1. verify capped-table rendering in `explorer-app/src/inspect-format.ts`.
2. validate truncation assertions in `explorer-app/tests/inspect-format.red.test.ts`.
3. run `bun run --filter @gen-dungeon/explorer-app test`.

## 7. Handoff Checklist

Before declaring P1 done:
- all P1 tests green (`torii-views` + proxy contracts/routes/stream).
- runbook updated if any route/stream contract changes.
- issue tracker dependencies for `EXP-P1-*` updated and closed only when acceptance is met.
