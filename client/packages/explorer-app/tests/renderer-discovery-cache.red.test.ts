import { describe, expect, it } from "vitest";
import type { ChunkSnapshot, StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
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

function signalChunk(hexCoordinate: string): ChunkSnapshot {
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key: "0:0",
      chunkQ: 0,
      chunkR: 0
    },
    headBlock: 100,
    hexes: [
      {
        hexCoordinate,
        biome: "Forest",
        ownerAdventurerId: "0xowner",
        decayLevel: 35,
        isClaimable: true,
        activeClaimCount: 1,
        adventurerCount: 2,
        plantCount: 3
      }
    ]
  };
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

  it("applies hex patch incrementally without full chunk replace.red", () => {
    const renderer = new CanvasMockRenderer(fakeCanvas());
    renderer.replaceChunks([chunk([HEX_LEFT])]);
    renderer.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 1,
      blockNumber: 101,
      txIndex: 0,
      eventIndex: 0,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: {
          hexCoordinate: HEX_TOP_LEFT,
          biome: "Forest",
          ownerAdventurerId: null,
          decayLevel: 0,
          isClaimable: false,
          activeClaimCount: 0,
          adventurerCount: 0,
          plantCount: 0
        }
      },
      emittedAtMs: 1
    } satisfies StreamPatchEnvelope);

    const layout = (
      renderer as unknown as { layout: Array<{ hexCoordinate: string; isDiscovered: boolean }> }
    ).layout;
    const topLeft = layout.find((entry) => entry.hexCoordinate.toLowerCase() === HEX_TOP_LEFT);
    expect(topLeft?.isDiscovered).toBe(true);
  });

  it("composites multiple active layers without hiding claim or ownership signal.red", () => {
    const renderer = new CanvasMockRenderer(fakeCanvas());
    renderer.setLayerState({
      biome: false,
      ownership: true,
      claims: true,
      adventurers: true,
      resources: true,
      decay: true
    });
    renderer.replaceChunks([signalChunk(HEX_LEFT)]);

    const layout = (
      renderer as unknown as { layout: Array<{ hexCoordinate: string; fill: string }> }
    ).layout;
    const rendered = layout.find((entry) => entry.hexCoordinate.toLowerCase() === HEX_LEFT);
    expect(rendered?.fill).toBe("#5d6a44");
  });
});
