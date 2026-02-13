import type {
  ChunkKey,
  ChunkSnapshot,
  EventTailQuery,
  EventTailRow,
  HexCoordinate,
  HexInspectPayload,
  LayerToggleState,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope,
  StreamStatus,
  ViewportWindow
} from "@gen-dungeon/explorer-types";

export interface ExplorerProxyClient {
  getChunks(keys: ChunkKey[]): Promise<ChunkSnapshot[]>;
  getHexInspect(hexCoordinate: HexCoordinate): Promise<HexInspectPayload>;
  search(query: SearchQuery): Promise<SearchResult[]>;
  getEventTail(query: EventTailQuery): Promise<EventTailRow[]>;
  subscribePatches(handlers: PatchStreamHandlers): ExplorerStreamSubscription;
}

export interface PatchStreamHandlers {
  onPatch: (patch: StreamPatchEnvelope) => void;
  onStatus: (status: StreamStatus) => void;
  onError: (error: Error) => void;
}

export interface ExplorerStreamSubscription {
  close: () => void;
}

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
