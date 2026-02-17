import { describe, expect, it } from "vitest";
import type { ExplorerProxyApi } from "../src/contracts.js";
import { startExplorerProxyHttpServer } from "../src/http-server.js";
import WebSocket from "ws";
import { createExplorerProxyStream } from "../src/ws-stream.js";

function createApiStub(): ExplorerProxyApi {
  return {
    async getChunks(keys) {
      return [
        {
          schemaVersion: "explorer-v1",
          chunk: { key: keys[0] ?? "0:0", chunkQ: 0, chunkR: 0 },
          headBlock: 120,
          hexes: []
        }
      ];
    },
    async getHex(hexCoordinate) {
      return {
        schemaVersion: "explorer-v1",
        headBlock: 120,
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
        headBlock: 120,
        lastSequence: 44,
        streamLagMs: 100
      };
    }
  };
}

describe("proxy http server runtime (RED)", () => {
  it("boots and serves v1 http routes over localhost.red", async () => {
    const server = await startExplorerProxyHttpServer({
      api: createApiStub(),
      host: "127.0.0.1",
      port: 0
    });

    try {
      const chunkResponse = await fetch(`${server.origin}/v1/chunks?keys=0:0`);
      expect(chunkResponse.status).toBe(200);
      expect(chunkResponse.headers.get("access-control-allow-origin")).toBe("*");
      const chunksPayload = await chunkResponse.json();
      expect(chunksPayload.schemaVersion).toBe("explorer-v1");
      expect(Array.isArray(chunksPayload.chunks)).toBe(true);

      const statusResponse = await fetch(`${server.origin}/v1/status`);
      expect(statusResponse.status).toBe(200);
      const statusPayload = await statusResponse.json();
      expect(statusPayload.lastSequence).toBe(44);
    } finally {
      await server.close();
    }
  });

  it("handles CORS preflight for browser fetch from app origin.red", async () => {
    const server = await startExplorerProxyHttpServer({
      api: createApiStub(),
      host: "127.0.0.1",
      port: 0
    });

    try {
      const response = await fetch(`${server.origin}/v1/chunks?keys=0:0`, {
        method: "OPTIONS",
        headers: {
          origin: "http://127.0.0.1:4174",
          "access-control-request-method": "GET",
          "access-control-request-headers": "accept"
        }
      });
      expect(response.status).toBe(204);
      expect(response.headers.get("access-control-allow-origin")).toBe("*");
      expect(response.headers.get("access-control-allow-methods")).toContain("GET");
      expect(response.headers.get("access-control-allow-headers")).toContain("accept");
    } finally {
      await server.close();
    }
  });

  it("returns 405 for unsupported methods.red", async () => {
    const server = await startExplorerProxyHttpServer({
      api: createApiStub(),
      host: "127.0.0.1",
      port: 0
    });

    try {
      const response = await fetch(`${server.origin}/v1/chunks?keys=0:0`, {
        method: "POST"
      });
      expect(response.status).toBe(405);
    } finally {
      await server.close();
    }
  });

  it("upgrades /v1/stream websocket and forwards ordered patches.red", async () => {
    const stream = createExplorerProxyStream({
      initialOutputSequence: 10,
      clock: () => 1700000000000
    });
    const server = await startExplorerProxyHttpServer({
      api: createApiStub(),
      stream,
      host: "127.0.0.1",
      port: 0
    });

    const socket = new WebSocket(`${toWsOrigin(server.origin)}/v1/stream`);
    try {
      await waitForOpen(socket);
      const messagesPromise = waitForMessages(socket, 3);
      stream.ingest([
        {
          sourceSequence: 1,
          blockNumber: 10,
          txIndex: 0,
          eventIndex: 1,
          kind: "hex_patch",
          payload: { id: "a" }
        },
        {
          sourceSequence: 3,
          blockNumber: 10,
          txIndex: 1,
          eventIndex: 0,
          kind: "hex_patch",
          payload: { id: "b" }
        }
      ]);

      const messages = await messagesPromise;
      expect(messages).toHaveLength(3);
      const first = JSON.parse(messages[0]!);
      const second = JSON.parse(messages[1]!);
      const third = JSON.parse(messages[2]!);

      expect(first.sequence).toBe(11);
      expect(first.kind).toBe("hex_patch");
      expect(second.sequence).toBe(12);
      expect(second.kind).toBe("resync_required");
      expect(third.sequence).toBe(13);
      expect(third.kind).toBe("hex_patch");
    } finally {
      socket.close();
      await server.close();
    }
  });
});

function toWsOrigin(origin: string): string {
  if (origin.startsWith("https://")) {
    return `wss://${origin.slice("https://".length)}`;
  }
  if (origin.startsWith("http://")) {
    return `ws://${origin.slice("http://".length)}`;
  }
  return origin;
}

function waitForOpen(socket: WebSocket): Promise<void> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      socket.off("open", onOpen);
      socket.off("error", onError);
      reject(new Error("websocket open timeout"));
    }, 2_000);
    const onOpen = (): void => {
      clearTimeout(timeout);
      socket.off("error", onError);
      resolve();
    };
    const onError = (error: Error): void => {
      clearTimeout(timeout);
      socket.off("open", onOpen);
      reject(error);
    };

    socket.once("open", onOpen);
    socket.once("error", onError);
  });
}

function waitForMessages(socket: WebSocket, count: number): Promise<string[]> {
  return new Promise((resolve, reject) => {
    const messages: string[] = [];
    const timeout = setTimeout(() => {
      socket.off("message", onMessage);
      socket.off("error", onError);
      reject(new Error("websocket message timeout"));
    }, 2_000);

    const onMessage = (data: WebSocket.RawData): void => {
      messages.push(String(data));
      if (messages.length >= count) {
        clearTimeout(timeout);
        socket.off("error", onError);
        socket.off("message", onMessage);
        resolve(messages);
      }
    };
    const onError = (error: Error): void => {
      clearTimeout(timeout);
      socket.off("message", onMessage);
      reject(error);
    };

    socket.on("message", onMessage);
    socket.once("error", onError);
  });
}
