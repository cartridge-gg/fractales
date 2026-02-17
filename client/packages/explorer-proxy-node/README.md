# @gen-dungeon/explorer-proxy-node

HTTP/stream proxy contracts and runtime bootstrap for the explorer read path.

## Run local server bootstrap

From `client/`:

```bash
bun run --filter @gen-dungeon/explorer-proxy-node dev
```

The server listens on:
- host: `EXPLORER_PROXY_HOST` (default `127.0.0.1`)
- port: `EXPLORER_PROXY_PORT` (default `3001`)

## Routes

- `GET /v1/chunks?keys=<k1,k2,...>`
- `GET /v1/hex/:hex_coordinate`
- `GET /v1/search?coord|owner|adventurer=<value>`
- `GET /v1/status`
- `WS /v1/stream`

## Current bootstrap behavior

Default reader mode is Torii-backed (`EXPLORER_PROXY_READER_MODE=torii`) and queries:
- `EXPLORER_PROXY_TORII_GRAPHQL_URL` (default live slot endpoint)

Available runtime env vars:
- `EXPLORER_PROXY_READER_MODE=torii|stub`
- `EXPLORER_PROXY_TORII_GRAPHQL_URL=<graphql-url>`
- `EXPLORER_PROXY_CACHE_TTL_MS=<ms>`
- `EXPLORER_PROXY_POLL_INTERVAL_MS=<ms>`
- `EXPLORER_PROXY_CHUNK_SIZE=<int>`
- `EXPLORER_PROXY_QUERY_LIMIT=<int>`

Set `EXPLORER_PROXY_READER_MODE=stub` to run in offline stub mode.
