import { describe, expect, it } from "vitest";
import type { ChunkSnapshot } from "@gen-dungeon/explorer-types";
import { CanvasMockRenderer } from "../src/dev-runtime.js";

const HEX_LEFT = "0x3ffffe0000100001";
const HEX_TOP_LEFT = "0x3ffffe0000300000";

function chunk(hexCoordinates: string[]): ChunkSnapshot {
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key: "0:0",
      chunkQ: 0,
      chunkR: 0
    },
    headBlock: 100,
    hexes: hexCoordinates.map((hexCoordinate) => ({
      hexCoordinate,
      biome: "Forest",
      ownerAdventurerId: null,
      decayLevel: 0,
      isClaimable: false,
      activeClaimCount: 0,
      adventurerCount: 0,
      plantCount: 0
    }))
  };
}

function fakeCanvas(): HTMLCanvasElement {
  return {
    addEventListener: () => {},
    removeEventListener: () => {},
    getContext: () => null,
    style: {}
  } as unknown as HTMLCanvasElement;
}

describe("renderer discovery cache (RED)", () => {
  it("keeps previously discovered hex styling when chunk window changes.red", () => {
    const renderer = new CanvasMockRenderer(fakeCanvas());
    renderer.replaceChunks([chunk([HEX_LEFT, HEX_TOP_LEFT])]);
    renderer.replaceChunks([chunk([HEX_LEFT])]);

    const layout = (renderer as unknown as { layout: Array<{ hexCoordinate: string; isDiscovered: boolean }> }).layout;
    const topLeft = layout.find((entry) => entry.hexCoordinate.toLowerCase() === HEX_TOP_LEFT);
    expect(topLeft?.isDiscovered).toBe(true);
  });
});
