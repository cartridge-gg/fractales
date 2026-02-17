import type {
  ChunkKey,
  ChunkSnapshot,
  EventTailQuery,
  EventTailRow,
  HexCoordinate,
  HexInspectPayload,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope,
  StreamStatus
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
