import type {
  ChunkKey,
  ChunkSnapshot,
  LayerToggleState,
  ViewportWindow
} from "@gen-dungeon/explorer-types";
import type { ExplorerSelectors } from "./store-contracts.js";

export interface CreateExplorerSelectorsInput {
  loadedChunks: ChunkSnapshot[];
}

export function createExplorerSelectors(
  input: CreateExplorerSelectorsInput
): ExplorerSelectors {
  return {
    visibleChunkKeys(viewport) {
      return visibleChunks(input.loadedChunks, viewport)
        .map((chunk) => chunk.chunk.key)
        .sort(compareChunkKeys);
    },
    visibleHexes(viewport, layers) {
      const includeHex = buildLayerFilter(layers);
      if (!includeHex) {
        return [];
      }

      return visibleChunks(input.loadedChunks, viewport)
        .flatMap((chunk) => chunk.hexes)
        .filter(includeHex);
    }
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

function buildLayerFilter(
  layers: LayerToggleState
): ((hex: ChunkSnapshot["hexes"][number]) => boolean) | null {
  if (layers.biome) {
    return () => true;
  }

  if (
    !layers.ownership &&
    !layers.claims &&
    !layers.adventurers &&
    !layers.resources &&
    !layers.decay
  ) {
    return null;
  }

  return (hex) =>
    (layers.ownership && hex.ownerAdventurerId !== null) ||
    (layers.claims && (hex.activeClaimCount > 0 || hex.isClaimable)) ||
    (layers.adventurers && hex.adventurerCount > 0) ||
    (layers.resources && hex.plantCount > 0) ||
    (layers.decay && hex.decayLevel > 0);
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
