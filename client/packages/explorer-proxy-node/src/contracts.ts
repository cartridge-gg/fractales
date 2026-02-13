import type {
  ChunkKey,
  ChunkSnapshot,
  HexCoordinate,
  HexInspectPayload,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope
} from "@gen-dungeon/explorer-types";

export interface ProxyStatusPayload {
  schemaVersion: "explorer-v1";
  headBlock: number;
  lastSequence: number;
  streamLagMs: number;
}

export interface ExplorerProxyApi {
  getChunks(keys: ChunkKey[]): Promise<ChunkSnapshot[]>;
  getHex(hexCoordinate: HexCoordinate): Promise<HexInspectPayload>;
  search(query: SearchQuery): Promise<SearchResult[]>;
  status(): Promise<ProxyStatusPayload>;
}

export interface ExplorerProxyStream {
  subscribe(handler: (patch: StreamPatchEnvelope) => void): () => void;
}
