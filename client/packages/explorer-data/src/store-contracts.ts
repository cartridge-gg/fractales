import type {
  ChunkKey,
  ChunkSnapshot,
  HexCoordinate,
  LayerToggleState,
  StreamPatchEnvelope,
  StreamStatus,
  ViewportWindow
} from "@gen-dungeon/explorer-types";

export interface ExplorerStoreSnapshot {
  status: StreamStatus;
  headBlock: number;
  selectedHex: HexCoordinate | null;
  loadedChunks: ChunkSnapshot[];
}

export interface ExplorerDataStore {
  replaceChunks(chunks: ChunkSnapshot[]): void;
  applyPatch(patch: StreamPatchEnvelope): void;
  evictChunk(key: ChunkKey): void;
  setSelectedHex(hex: HexCoordinate | null): void;
  snapshot(): ExplorerStoreSnapshot;
}

export interface ExplorerSelectors {
  visibleChunkKeys(viewport: ViewportWindow): ChunkKey[];
  visibleHexes(viewport: ViewportWindow, layers: LayerToggleState): ReadonlyArray<ChunkSnapshot["hexes"][number]>;
}
