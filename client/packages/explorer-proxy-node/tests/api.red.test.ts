import { describe, expect, it } from "vitest";
import type { ChunkSnapshot, EventTailRow, HexInspectPayload } from "@gen-dungeon/explorer-types";
import type { ToriiViewsReader } from "@gen-dungeon/torii-views";
import { createExplorerProxyApi } from "../src/api.js";

function makeChunkSnapshot(key: `${number}:${number}`): ChunkSnapshot {
  const [chunkQRaw, chunkRRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ: chunkQRaw ?? 0,
      chunkR: chunkRRaw ?? 0
    },
    headBlock: 100,
    hexes: []
  };
}

function makeInspectPayload(hexCoordinate: string): HexInspectPayload {
  return {
    schemaVersion: "explorer-v1",
    headBlock: 100,
    hex: {
      coordinate: hexCoordinate,
      biome: {} as any,
      is_discovered: true,
      discovery_block: 100,
      discoverer: "0x1",
      area_count: 1
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
}

describe("proxy API adapter (RED)", () => {
  it("chunks.endpoint.rejects_oversized_keyset.red", async () => {
    const reader: ToriiViewsReader = {
      getChunks: async () => [],
      getHexInspect: async () => makeInspectPayload("0x1"),
      search: async () => [],
      getEventTail: async () => []
    };
    const api = createExplorerProxyApi({ reader, maxChunkKeys: 2 });

    await expect(api.getChunks(["0:0", "0:1", "0:2"])).rejects.toThrow(
      "chunk key set exceeds max of 2"
    );
  });

  it("chunks endpoint dedupes keys and returns typed snapshots", async () => {
    let lastKeys: string[] = [];
    const reader: ToriiViewsReader = {
      getChunks: async (query) => {
        lastKeys = query.keys;
        return [makeChunkSnapshot("0:0")];
      },
      getHexInspect: async () => makeInspectPayload("0x1"),
      search: async () => [],
      getEventTail: async () => []
    };
    const api = createExplorerProxyApi({ reader, maxChunkKeys: 4 });

    const result = await api.getChunks(["0:0", "0:0", "1:0"]);
    expect(lastKeys).toEqual(["0:0", "1:0"]);
    expect(result[0]?.schemaVersion).toBe("explorer-v1");
  });

  it("hex.endpoint.includes_complete_inspect_payload.red", async () => {
    const payload = makeInspectPayload("0xabc");
    const reader: ToriiViewsReader = {
      getChunks: async () => [],
      getHexInspect: async () => payload,
      search: async () => [],
      getEventTail: async () => []
    };
    const api = createExplorerProxyApi({ reader });

    await expect(api.getHex("0xabc")).resolves.toEqual(payload);
  });

  it("hex.endpoint.includes_mining_inspect_families.red", async () => {
    const payload = makeInspectPayload("0xabc");
    const reader: ToriiViewsReader = {
      getChunks: async () => [],
      getHexInspect: async () => payload,
      search: async () => [],
      getEventTail: async () => []
    };
    const api = createExplorerProxyApi({ reader });

    const result = (await api.getHex("0xabc")) as unknown as Record<string, unknown>;
    expect(Array.isArray(result.mineNodes)).toBe(true);
    expect(Array.isArray(result.miningShifts)).toBe(true);
    expect(Array.isArray(result.mineAccessGrants)).toBe(true);
    expect(Array.isArray(result.mineCollapseRecords)).toBe(true);
  });

  it("hex.endpoint.merges_ordered_event_tail_from_reader.red", async () => {
    const payload = makeInspectPayload("0xabc");
    let eventTailQuery: { hexCoordinate?: string; limit: number } | null = null;
    const reader: ToriiViewsReader = {
      getChunks: async () => [],
      getHexInspect: async () => payload,
      search: async () => [],
      getEventTail: async (query) => {
        eventTailQuery = query;
        const rows: EventTailRow[] = [
          {
            blockNumber: 120,
            txIndex: 1,
            eventIndex: 1,
            eventName: "LateEvent",
            payloadJson: "{}"
          },
          {
            blockNumber: 119,
            txIndex: 2,
            eventIndex: 0,
            eventName: "FirstEvent",
            payloadJson: "{}"
          },
          {
            blockNumber: 120,
            txIndex: 0,
            eventIndex: 9,
            eventName: "MidEvent",
            payloadJson: "{}"
          }
        ];
        return rows;
      }
    };
    const api = createExplorerProxyApi({ reader, eventTailLimit: 16 });

    const result = await api.getHex("0xabc");
    expect(eventTailQuery).toEqual({ hexCoordinate: "0xabc", limit: 16 });
    expect(result.eventTail.map((row) => row.eventName)).toEqual([
      "FirstEvent",
      "MidEvent",
      "LateEvent"
    ]);
  });

  it("status endpoint returns explorer-v1 schema metadata", async () => {
    const reader: ToriiViewsReader = {
      getChunks: async () => [],
      getHexInspect: async () => makeInspectPayload("0x1"),
      search: async () => [],
      getEventTail: async () => []
    };
    const api = createExplorerProxyApi({
      reader,
      getStatus: () => ({
        schemaVersion: "explorer-v1",
        headBlock: 77,
        lastSequence: 990,
        streamLagMs: 1200
      })
    });

    await expect(api.status()).resolves.toEqual({
      schemaVersion: "explorer-v1",
      headBlock: 77,
      lastSequence: 990,
      streamLagMs: 1200
    });
  });
});
