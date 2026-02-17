import { describe, expect, it } from "vitest";
import type { ExplorerProxyApi } from "../src/contracts.js";
import { handleExplorerProxyHttpRequest } from "../src/http-routes.js";

function createApiStub(): ExplorerProxyApi {
  return {
    async getChunks(keys) {
      return [
        {
          schemaVersion: "explorer-v1",
          chunk: { key: keys[0] ?? "0:0", chunkQ: 0, chunkR: 0 },
          headBlock: 100,
          hexes: []
        }
      ];
    },
    async getHex(hexCoordinate) {
      return {
        schemaVersion: "explorer-v1",
        headBlock: 100,
        hex: {
          coordinate: hexCoordinate,
          biome: {} as any,
          is_discovered: true,
          discovery_block: 100,
          discoverer: "0xabc",
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
    },
    async search() {
      return [{ hexCoordinate: "0x1", score: 1, reason: "owner" }];
    },
    async status() {
      return {
        schemaVersion: "explorer-v1",
        headBlock: 100,
        lastSequence: 900,
        streamLagMs: 750
      };
    }
  };
}

describe("proxy HTTP routes (RED)", () => {
  it("chunks.endpoint.returns_stable_schema.red", async () => {
    const response = await handleExplorerProxyHttpRequest(
      createApiStub(),
      new Request("http://local/v1/chunks?keys=0:0,0:1")
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.schemaVersion).toBe("explorer-v1");
    expect(Array.isArray(body.chunks)).toBe(true);
  });

  it("chunks endpoint returns 400 when keys query is missing", async () => {
    const response = await handleExplorerProxyHttpRequest(
      createApiStub(),
      new Request("http://local/v1/chunks")
    );

    expect(response.status).toBe(400);
    const body = await response.json();
    expect(String(body.error)).toContain("keys");
  });

  it("hex endpoint returns inspect payload for coordinate path", async () => {
    const response = await handleExplorerProxyHttpRequest(
      createApiStub(),
      new Request("http://local/v1/hex/0xabc")
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.hex.coordinate).toBe("0xabc");
  });

  it("search.endpoint.coord_owner_adventurer_modes.red", async () => {
    const response = await handleExplorerProxyHttpRequest(
      createApiStub(),
      new Request("http://local/v1/search?owner=0x1")
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.results[0]?.reason).toBe("owner");
  });

  it("status endpoint returns stream metadata", async () => {
    const response = await handleExplorerProxyHttpRequest(
      createApiStub(),
      new Request("http://local/v1/status")
    );

    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.lastSequence).toBe(900);
  });
});
