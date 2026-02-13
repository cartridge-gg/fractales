import { describe, expect, it } from "vitest";
import type { ChunkKey, ChunkSnapshot } from "@gen-dungeon/explorer-types";
import { createChunkCache, getChunk, pinChunk, upsertChunk } from "../src/chunk-cache";

function snapshot(key: ChunkKey, headBlock: number): ChunkSnapshot {
  const [q, r] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: { key, chunkQ: q, chunkR: r },
    headBlock,
    hexes: []
  };
}

describe("chunk cache (RED->GREEN)", () => {
  it("evicts least-recently-used unpinned chunk when capacity is exceeded", () => {
    let cache = createChunkCache(2);
    cache = upsertChunk(cache, snapshot("0:0", 1));
    cache = upsertChunk(cache, snapshot("1:0", 1));

    const access = getChunk(cache, "0:0");
    cache = access.cache;
    cache = upsertChunk(cache, snapshot("2:0", 2));

    expect(cache.entries.has("0:0")).toBe(true);
    expect(cache.entries.has("2:0")).toBe(true);
    expect(cache.entries.has("1:0")).toBe(false);
  });

  it("respects pinned chunks during eviction", () => {
    let cache = createChunkCache(2);
    cache = upsertChunk(cache, snapshot("0:0", 1));
    cache = upsertChunk(cache, snapshot("1:0", 1));
    cache = pinChunk(cache, "0:0", true);
    cache = upsertChunk(cache, snapshot("2:0", 2));

    expect(cache.entries.has("0:0")).toBe(true);
    expect(cache.entries.has("2:0")).toBe(true);
    expect(cache.entries.has("1:0")).toBe(false);
  });
});
