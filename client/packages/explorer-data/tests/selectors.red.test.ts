import { describe, expect, it } from "vitest";
import type { ChunkSnapshot, LayerToggleState, ViewportWindow } from "@gen-dungeon/explorer-types";
import { createExplorerSelectors } from "../src/selectors.js";

function makeChunk(
  key: `${number}:${number}`,
  hexes: ChunkSnapshot["hexes"]
): ChunkSnapshot {
  const [chunkQRaw, chunkRRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ: chunkQRaw ?? 0,
      chunkR: chunkRRaw ?? 0
    },
    headBlock: 100,
    hexes
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

const noneLayers: LayerToggleState = {
  biome: false,
  ownership: false,
  claims: false,
  adventurers: false,
  resources: false,
  decay: false
};

describe("selectors (RED)", () => {
  it("selectors.visible_chunks_respect_viewport_window.red", () => {
    const selectors = createExplorerSelectors({
      loadedChunks: [
        makeChunk("-1:0", []),
        makeChunk("0:0", []),
        makeChunk("2:0", [])
      ]
    });

    const visible = selectors.visibleChunkKeys(viewport(0, 0, 2, 2));
    expect(visible).toEqual(["-1:0", "0:0"]);
  });

  it("selectors.visible_hexes_respect_layer_filters.red", () => {
    const selectors = createExplorerSelectors({
      loadedChunks: [
        makeChunk("0:0", [
          {
            hexCoordinate: "0x1",
            biome: "Plains",
            ownerAdventurerId: null,
            decayLevel: 0,
            isClaimable: false,
            activeClaimCount: 0,
            adventurerCount: 0,
            plantCount: 0
          },
          {
            hexCoordinate: "0x2",
            biome: "Forest",
            ownerAdventurerId: "0xa",
            decayLevel: 0,
            isClaimable: false,
            activeClaimCount: 0,
            adventurerCount: 0,
            plantCount: 0
          },
          {
            hexCoordinate: "0x3",
            biome: "Desert",
            ownerAdventurerId: null,
            decayLevel: 0,
            isClaimable: false,
            activeClaimCount: 1,
            adventurerCount: 0,
            plantCount: 0
          },
          {
            hexCoordinate: "0x4",
            biome: "Jungle",
            ownerAdventurerId: null,
            decayLevel: 0,
            isClaimable: false,
            activeClaimCount: 0,
            adventurerCount: 2,
            plantCount: 0
          },
          {
            hexCoordinate: "0x5",
            biome: "Swamp",
            ownerAdventurerId: null,
            decayLevel: 0,
            isClaimable: false,
            activeClaimCount: 0,
            adventurerCount: 0,
            plantCount: 3
          },
          {
            hexCoordinate: "0x6",
            biome: "Mountain",
            ownerAdventurerId: null,
            decayLevel: 9,
            isClaimable: false,
            activeClaimCount: 0,
            adventurerCount: 0,
            plantCount: 0
          }
        ])
      ]
    });
    const window = viewport(0, 0, 1, 1);

    const ownership = selectors.visibleHexes(window, { ...noneLayers, ownership: true });
    expect(ownership.map((hex) => hex.hexCoordinate)).toEqual(["0x2"]);

    const claims = selectors.visibleHexes(window, { ...noneLayers, claims: true });
    expect(claims.map((hex) => hex.hexCoordinate)).toEqual(["0x3"]);

    const adventurers = selectors.visibleHexes(window, { ...noneLayers, adventurers: true });
    expect(adventurers.map((hex) => hex.hexCoordinate)).toEqual(["0x4"]);

    const resources = selectors.visibleHexes(window, { ...noneLayers, resources: true });
    expect(resources.map((hex) => hex.hexCoordinate)).toEqual(["0x5"]);

    const decay = selectors.visibleHexes(window, { ...noneLayers, decay: true });
    expect(decay.map((hex) => hex.hexCoordinate)).toEqual(["0x6"]);

    const none = selectors.visibleHexes(window, noneLayers);
    expect(none).toEqual([]);
  });
});
