import { describe, expect, it } from "vitest";
import type { ChunkKey, ChunkSnapshot } from "@gen-dungeon/explorer-types";
import {
  createChunkCache,
  createChunkCacheForProfile,
  getChunk,
  pinChunk,
  upsertChunk
} from "../src/chunk-cache.js";

function snapshot(key: ChunkKey, headBlock: number): ChunkSnapshot {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  const q = qRaw ?? 0;
  const r = rRaw ?? 0;
  return {
    schemaVersion: "explorer-v1",
    chunk: { key, chunkQ: q, chunkR: r },
    headBlock,
    hexes: []
  };
}

describe("chunk cache (RED->GREEN)", () => {
  it("uses mobile and desktop profile budgets", () => {
    const mobile = createChunkCacheForProfile("mobile");
    const desktop = createChunkCacheForProfile("desktop");

    expect(mobile.maxChunks).toBe(96);
    expect(desktop.maxChunks).toBe(192);
  });

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

  it("enforces hard cap when all resident entries are pinned", () => {
    let cache = createChunkCache(2);
    cache = upsertChunk(cache, snapshot("0:0", 1));
    cache = upsertChunk(cache, snapshot("1:0", 1));
    cache = pinChunk(cache, "0:0", true);
    cache = pinChunk(cache, "1:0", true);
    cache = upsertChunk(cache, snapshot("2:0", 2));

    expect(cache.entries.size).toBe(2);
    expect(cache.entries.has("0:0")).toBe(true);
    expect(cache.entries.has("1:0")).toBe(true);
    expect(cache.entries.has("2:0")).toBe(false);
  });

  it("stays within profile budget under sustained insert pressure", () => {
    let cache = createChunkCacheForProfile("mobile");
    for (let i = 0; i < 200; i += 1) {
      cache = upsertChunk(cache, snapshot(`0:${i}` as ChunkKey, 100 + i));
    }

    expect(cache.entries.size).toBeLessThanOrEqual(cache.maxChunks);
  });
});
