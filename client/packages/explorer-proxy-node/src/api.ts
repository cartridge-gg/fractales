import type { ChunkKey, SearchQuery } from "@gen-dungeon/explorer-types";
import type { ToriiViewsReader } from "@gen-dungeon/torii-views";
import type { ExplorerProxyApi, ProxyStatusPayload } from "./contracts.js";

const DEFAULT_MAX_CHUNK_KEYS = 128;

export interface CreateExplorerProxyApiOptions {
  reader: ToriiViewsReader;
  maxChunkKeys?: number;
  getStatus?: () => ProxyStatusPayload | Promise<ProxyStatusPayload>;
}

export function createExplorerProxyApi(options: CreateExplorerProxyApiOptions): ExplorerProxyApi {
  const maxChunkKeys = options.maxChunkKeys ?? DEFAULT_MAX_CHUNK_KEYS;

  return {
    async getChunks(keys) {
      const normalized = normalizeChunkKeys(keys, maxChunkKeys);
      return options.reader.getChunks({ keys: normalized });
    },
    async getHex(hexCoordinate) {
      return options.reader.getHexInspect(hexCoordinate);
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
