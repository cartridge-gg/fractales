import type { ChunkKey, ChunkSnapshot } from "@gen-dungeon/explorer-types";

export interface ChunkCacheEntry {
  snapshot: ChunkSnapshot;
  lastAccessTick: number;
  pinned: boolean;
}

export interface ChunkCacheState {
  maxChunks: number;
  tick: number;
  entries: Map<ChunkKey, ChunkCacheEntry>;
}

export function createChunkCache(maxChunks: number): ChunkCacheState {
  return {
    maxChunks,
    tick: 0,
    entries: new Map()
  };
}

export function getChunk(
  cache: ChunkCacheState,
  key: ChunkKey
): { cache: ChunkCacheState; snapshot: ChunkSnapshot | null } {
  const entry = cache.entries.get(key);
  if (!entry) {
    return { cache, snapshot: null };
  }

  const nextTick = cache.tick + 1;
  const nextEntries = new Map(cache.entries);
  nextEntries.set(key, {
    ...entry,
    lastAccessTick: nextTick
  });

  return {
    cache: {
      ...cache,
      tick: nextTick,
      entries: nextEntries
    },
    snapshot: entry.snapshot
  };
}

export function pinChunk(
  cache: ChunkCacheState,
  key: ChunkKey,
  pinned: boolean
): ChunkCacheState {
  const entry = cache.entries.get(key);
  if (!entry) {
    return cache;
  }

  const nextEntries = new Map(cache.entries);
  nextEntries.set(key, {
    ...entry,
    pinned
  });

  return {
    ...cache,
    entries: nextEntries
  };
}

export function upsertChunk(
  cache: ChunkCacheState,
  snapshot: ChunkSnapshot
): ChunkCacheState {
  const key = snapshot.chunk.key;
  const nextTick = cache.tick + 1;
  const existing = cache.entries.get(key);
  const nextEntries = new Map(cache.entries);

  nextEntries.set(key, {
    snapshot,
    pinned: existing?.pinned ?? false,
    lastAccessTick: nextTick
  });

  const compacted = evictIfNeeded(nextEntries, cache.maxChunks);

  return {
    ...cache,
    tick: nextTick,
    entries: compacted
  };
}

function evictIfNeeded(
  entries: Map<ChunkKey, ChunkCacheEntry>,
  maxChunks: number
): Map<ChunkKey, ChunkCacheEntry> {
  if (entries.size <= maxChunks) {
    return entries;
  }

  const evictable = Array.from(entries.entries())
    .filter(([, entry]) => !entry.pinned)
    .sort((a, b) => a[1].lastAccessTick - b[1].lastAccessTick);

  const nextEntries = new Map(entries);
  let cursor = 0;
  while (nextEntries.size > maxChunks && cursor < evictable.length) {
    const [key] = evictable[cursor];
    nextEntries.delete(key);
    cursor += 1;
  }

  return nextEntries;
}
