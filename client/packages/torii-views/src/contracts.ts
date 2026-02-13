import type {
  ChunkKey,
  ChunkSnapshot,
  EventTailQuery,
  EventTailRow,
  HexCoordinate,
  HexInspectPayload,
  SearchQuery,
  SearchResult
} from "@gen-dungeon/explorer-types";

export interface ChunkQuery {
  keys: ChunkKey[];
}

export interface ToriiViewsReader {
  getChunks(query: ChunkQuery): Promise<ChunkSnapshot[]>;
  getHexInspect(hexCoordinate: HexCoordinate): Promise<HexInspectPayload>;
  search(query: SearchQuery): Promise<SearchResult[]>;
  getEventTail(query: EventTailQuery): Promise<EventTailRow[]>;
}
