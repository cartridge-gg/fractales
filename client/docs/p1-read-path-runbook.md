# Explorer P1 Read-Path Runbook

Status: Draft  
Last updated: 2026-02-16  
Owners: Client Platform + Game Infra

## 1. Scope

This runbook covers P1 read-path operation for:
- `@gen-dungeon/torii-views` v1 logical views
- `@gen-dungeon/explorer-proxy-node` read endpoints and stream contract

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

## 3. Version and Contract Invariants

Must stay true:
- schema version remains `explorer-v1` in proxy responses and stream envelopes.
- `toriiViewsManifestV1` IDs are one-to-one with shipped `sql/views/v1/*.sql`.
- `explorer_hex_render_v1` remains discovered-only.
- `explorer_claim_active_v1` keeps ACTIVE filtering (`status = 1`).
- stream emits `resync_required` before patch emission when `sourceSequence` gaps are detected.

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

## 7. Handoff Checklist

Before declaring P1 done:
- all P1 tests green (`torii-views` + proxy contracts/routes/stream).
- runbook updated if any route/stream contract changes.
- issue tracker dependencies for `EXP-P1-*` updated and closed only when acceptance is met.
