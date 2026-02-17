import { describe, expect, it } from "vitest";
import type { ChunkSnapshot, ViewportWindow } from "@gen-dungeon/explorer-types";
import { buildChunkRenderSet } from "../src/culling.js";

function chunk(key: `${number}:${number}`): ChunkSnapshot {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ: qRaw ?? 0,
      chunkR: rRaw ?? 0
    },
    headBlock: 100,
    hexes: []
  };
}

function viewport(centerX: number, centerY: number, width: number, height: number): ViewportWindow {
  return {
    center: { x: centerX, y: centerY },
    width,
    height,
    zoom: 1
  };
}

describe("chunk culling (RED)", () => {
  it("culling.visible_chunks_within_viewport.red", () => {
    const renderSet = buildChunkRenderSet({
      loadedChunks: [chunk("-1:0"), chunk("0:0"), chunk("2:0"), chunk("0:2")],
      viewport: viewport(0, 0, 2, 2),
      prefetchRing: 1
    });

    expect(renderSet.visibleChunkKeys).toEqual(["-1:0", "0:0"]);
  });

  it("culling.includes_one_ring_prefetch_neighbors.red", () => {
    const renderSet = buildChunkRenderSet({
      loadedChunks: [chunk("0:0"), chunk("1:0"), chunk("0:1"), chunk("5:5")],
      viewport: viewport(0, 0, 1, 1),
      prefetchRing: 1
    });

    expect(renderSet.prefetchChunkKeys).toEqual(["-1:0", "-1:1", "0:-1", "0:1", "1:-1", "1:0"]);
    expect(renderSet.renderChunkKeys).toEqual(["0:0", "0:1", "1:0"]);
  });
});
