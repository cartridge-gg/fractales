import type { ChunkKey, EventTailRow, SearchQuery } from "@gen-dungeon/explorer-types";
import type { ToriiViewsReader } from "@gen-dungeon/torii-views";
import type { ExplorerProxyApi, ProxyStatusPayload } from "./contracts.js";

const DEFAULT_MAX_CHUNK_KEYS = 128;
const DEFAULT_EVENT_TAIL_LIMIT = 20;

export interface CreateExplorerProxyApiOptions {
  reader: ToriiViewsReader;
  maxChunkKeys?: number;
  eventTailLimit?: number;
  getStatus?: () => ProxyStatusPayload | Promise<ProxyStatusPayload>;
}

export function createExplorerProxyApi(options: CreateExplorerProxyApiOptions): ExplorerProxyApi {
  const maxChunkKeys = options.maxChunkKeys ?? DEFAULT_MAX_CHUNK_KEYS;
  const eventTailLimit = normalizeEventTailLimit(options.eventTailLimit);

  return {
    async getChunks(keys) {
      const normalized = normalizeChunkKeys(keys, maxChunkKeys);
      return options.reader.getChunks({ keys: normalized });
    },
    async getHex(hexCoordinate) {
      const inspect = await options.reader.getHexInspect(hexCoordinate);
      const eventTail = await options.reader.getEventTail({
        hexCoordinate,
        limit: eventTailLimit
      });
      return {
        ...inspect,
        eventTail: sortEventTailRows(eventTail)
      };
    },
    async search(query) {
      validateSearchQuery(query);
      return options.reader.search(query);
    },
    async status() {
      if (!options.getStatus) {
        return {
          schemaVersion: "explorer-v1",
          headBlock: 0,
          lastSequence: 0,
          streamLagMs: 0
        };
      }

      return options.getStatus();
    }
  };
}

function normalizeEventTailLimit(limit: number | undefined): number {
  if (limit === undefined) {
    return DEFAULT_EVENT_TAIL_LIMIT;
  }
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new Error("event tail limit must be a positive integer");
  }
  return limit;
}

function sortEventTailRows(rows: EventTailRow[]): EventTailRow[] {
  return [...rows].sort((left, right) => {
    if (left.blockNumber !== right.blockNumber) {
      return left.blockNumber - right.blockNumber;
    }
    if (left.txIndex !== right.txIndex) {
      return left.txIndex - right.txIndex;
    }
    if (left.eventIndex !== right.eventIndex) {
      return left.eventIndex - right.eventIndex;
    }
    return 0;
  });
}

function normalizeChunkKeys(keys: ChunkKey[], maxChunkKeys: number): ChunkKey[] {
  if (keys.length === 0) {
    throw new Error("chunk key set must not be empty");
  }

  if (keys.length > maxChunkKeys) {
    throw new Error(`chunk key set exceeds max of ${maxChunkKeys}`);
  }

  return Array.from(new Set(keys));
}

function validateSearchQuery(query: SearchQuery): void {
  const modeCount =
    Number(query.coord !== undefined) +
    Number(query.owner !== undefined) +
    Number(query.adventurer !== undefined);

  if (modeCount !== 1) {
    throw new Error("search query must provide exactly one mode: coord, owner, or adventurer");
  }
}
