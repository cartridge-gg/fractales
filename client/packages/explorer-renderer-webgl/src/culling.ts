import type { ChunkKey, ChunkSnapshot, ViewportWindow } from "@gen-dungeon/explorer-types";

export interface BuildChunkRenderSetInput {
  loadedChunks: ChunkSnapshot[];
  viewport: ViewportWindow;
  prefetchRing?: number;
}

export interface ChunkRenderSet {
  visibleChunkKeys: ChunkKey[];
  prefetchChunkKeys: ChunkKey[];
  renderChunkKeys: ChunkKey[];
}

export function buildChunkRenderSet(
  input: BuildChunkRenderSetInput
): ChunkRenderSet {
  const visibleChunkKeys = visibleChunks(input.loadedChunks, input.viewport)
    .map((chunk) => chunk.chunk.key)
    .sort(compareChunkKeys);
  const visibleKeySet = new Set<ChunkKey>(visibleChunkKeys);
  const prefetchRing = input.prefetchRing ?? 1;

  const prefetchSet = new Set<ChunkKey>();
  for (const key of visibleChunkKeys) {
    for (const neighbor of expandAxialNeighbors(key, prefetchRing)) {
      if (!visibleKeySet.has(neighbor)) {
        prefetchSet.add(neighbor);
      }
    }
  }

  const prefetchChunkKeys = Array.from(prefetchSet).sort(compareChunkKeys);
  const renderChunkKeys = input.loadedChunks
    .map((chunk) => chunk.chunk.key)
    .filter((key) => visibleKeySet.has(key) || prefetchSet.has(key))
    .sort(compareChunkKeys);

  return {
    visibleChunkKeys,
    prefetchChunkKeys,
    renderChunkKeys
  };
}

function visibleChunks(
  loadedChunks: ChunkSnapshot[],
  viewport: ViewportWindow
): ChunkSnapshot[] {
  const safeZoom = viewport.zoom <= 0 ? 1 : viewport.zoom;
  const halfWidth = viewport.width / (2 * safeZoom);
  const halfHeight = viewport.height / (2 * safeZoom);
  const minQ = viewport.center.x - halfWidth;
  const maxQ = viewport.center.x + halfWidth;
  const minR = viewport.center.y - halfHeight;
  const maxR = viewport.center.y + halfHeight;

  return loadedChunks.filter((chunk) => {
    return (
      chunk.chunk.chunkQ >= minQ &&
      chunk.chunk.chunkQ <= maxQ &&
      chunk.chunk.chunkR >= minR &&
      chunk.chunk.chunkR <= maxR
    );
  });
}

function expandAxialNeighbors(
  key: ChunkKey,
  radius: number
): ChunkKey[] {
  if (radius <= 0) {
    return [];
  }

  const [originQ, originR] = parseChunkKey(key);
  const neighbors: ChunkKey[] = [];
  for (let dq = -radius; dq <= radius; dq += 1) {
    const drMin = Math.max(-radius, -dq - radius);
    const drMax = Math.min(radius, -dq + radius);
    for (let dr = drMin; dr <= drMax; dr += 1) {
      if (dq === 0 && dr === 0) {
        continue;
      }
      neighbors.push(`${originQ + dq}:${originR + dr}`);
    }
  }

  return neighbors;
}

function compareChunkKeys(a: ChunkKey, b: ChunkKey): number {
  const [aq, ar] = parseChunkKey(a);
  const [bq, br] = parseChunkKey(b);

  if (aq !== bq) {
    return aq - bq;
  }

  return ar - br;
}

function parseChunkKey(key: ChunkKey): [number, number] {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return [qRaw ?? 0, rRaw ?? 0];
}
