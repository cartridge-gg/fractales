import type { ToriiViewsReader } from "@gen-dungeon/torii-views";
import { createExplorerProxyApi } from "./api.js";
import { startExplorerProxyHttpServer } from "./http-server.js";
import { createExplorerProxyStream } from "./ws-stream.js";
import {
  DEFAULT_LIVE_TORII_GRAPHQL_URL,
  LiveToriiProxyClient
} from "../../explorer-app/src/live-runtime.js";
import type { ChunkKey } from "@gen-dungeon/explorer-types";

const host = process.env.EXPLORER_PROXY_HOST ?? "127.0.0.1";
const portRaw = Number.parseInt(process.env.EXPLORER_PROXY_PORT ?? "3001", 10);
const port = Number.isFinite(portRaw) && portRaw >= 0 ? portRaw : 3001;
const readerMode = (process.env.EXPLORER_PROXY_READER_MODE ?? "torii").toLowerCase();
const toriiGraphqlUrl =
  process.env.EXPLORER_PROXY_TORII_GRAPHQL_URL ?? DEFAULT_LIVE_TORII_GRAPHQL_URL;
const cacheTtlMs = parseNonNegativeInt(process.env.EXPLORER_PROXY_CACHE_TTL_MS, 2_500);
const pollIntervalMs = parseNonNegativeInt(process.env.EXPLORER_PROXY_POLL_INTERVAL_MS, 4_000);
const chunkSize = Math.max(1, parseNonNegativeInt(process.env.EXPLORER_PROXY_CHUNK_SIZE, 1));
const queryLimit = Math.max(
  1,
  parseNonNegativeInt(process.env.EXPLORER_PROXY_QUERY_LIMIT, 2_000)
);

const runtime = createRuntimeReader();
const api = createExplorerProxyApi({
  reader: runtime.reader,
  getStatus: runtime.getStatus
});
const stream = createExplorerProxyStream();

const server = await startExplorerProxyHttpServer({
  api,
  stream,
  host,
  port
});

console.log(`explorer-proxy listening on ${server.origin}`);
if (readerMode === "stub") {
  console.log("reader mode: stub");
} else {
  console.log(`reader mode: torii (${toriiGraphqlUrl})`);
}

const shutdown = async (): Promise<void> => {
  await server.close();
  process.exit(0);
};

process.on("SIGINT", () => {
  void shutdown();
});
process.on("SIGTERM", () => {
  void shutdown();
});

function createStubReader(): ToriiViewsReader {
  return {
    async getChunks({ keys }) {
      return keys.map((key) => ({
        schemaVersion: "explorer-v1",
        chunk: {
          key,
          chunkQ: chunkQFromKey(key),
          chunkR: chunkRFromKey(key)
        },
        headBlock: 0,
        hexes: []
      }));
    },
    async getHexInspect(hexCoordinate) {
      return {
        schemaVersion: "explorer-v1",
        headBlock: 0,
        hex: {
          coordinate: hexCoordinate,
          biome: {} as never,
          is_discovered: false,
          discovery_block: 0,
          discoverer: "0x0",
          area_count: 0
        },
        areas: [],
        ownership: [],
        decayState: null,
        activeClaims: [],
        plants: [],
        activeReservations: [],
        adventurers: [],
        adventurerEconomics: [],
        inventories: [],
        backpackItems: [],
        buildings: [],
        constructionProjects: [],
        constructionEscrows: [],
        deathRecords: [],
        mineNodes: [],
        miningShifts: [],
        mineAccessGrants: [],
        mineCollapseRecords: [],
        eventTail: []
      };
    },
    async search() {
      return [];
    },
    async getEventTail() {
      return [];
    }
  };
}

interface RuntimeReader {
  reader: ToriiViewsReader;
  getStatus: () => Promise<{
    schemaVersion: "explorer-v1";
    headBlock: number;
    lastSequence: number;
    streamLagMs: number;
  }>;
}

function createRuntimeReader(): RuntimeReader {
  if (readerMode === "stub") {
    return {
      reader: createStubReader(),
      getStatus: async () => ({
        schemaVersion: "explorer-v1",
        headBlock: 0,
        lastSequence: 0,
        streamLagMs: 0
      })
    };
  }

  const proxyClient = new LiveToriiProxyClient({
    toriiGraphqlUrl,
    cacheTtlMs,
    pollIntervalMs,
    chunkSize,
    queryLimit,
    fetchImpl: fetch.bind(globalThis)
  });

  const reader: ToriiViewsReader = {
    getChunks: ({ keys }) => proxyClient.getChunks(keys),
    getHexInspect: (hexCoordinate) => proxyClient.getHexInspect(hexCoordinate),
    search: (query) => proxyClient.search(query),
    getEventTail: (query) => proxyClient.getEventTail(query)
  };

  return {
    reader,
    getStatus: async () => {
      const chunks = await proxyClient.getChunks(STATUS_SAMPLE_KEYS);
      const headBlock = chunks.reduce((max, chunk) => Math.max(max, chunk.headBlock), 0);
      return {
        schemaVersion: "explorer-v1",
        headBlock,
        lastSequence: 0,
        streamLagMs: 0
      };
    }
  };
}

function parseNonNegativeInt(raw: string | undefined, fallback: number): number {
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return parsed;
}

const STATUS_SAMPLE_KEYS: ChunkKey[] = buildStatusSampleKeys(2);

function buildStatusSampleKeys(radius: number): ChunkKey[] {
  const keys: ChunkKey[] = [];
  for (let q = -radius; q <= radius; q += 1) {
    for (let r = -radius; r <= radius; r += 1) {
      keys.push(`${q}:${r}` as ChunkKey);
    }
  }
  return keys;
}

function chunkQFromKey(key: string): number {
  const [chunkQ] = key.split(":").map((value) => Number.parseInt(value, 10));
  return Number.isFinite(chunkQ) ? (chunkQ ?? 0) : 0;
}

function chunkRFromKey(key: string): number {
  const [, chunkR] = key.split(":").map((value) => Number.parseInt(value, 10));
  return Number.isFinite(chunkR) ? (chunkR ?? 0) : 0;
}
