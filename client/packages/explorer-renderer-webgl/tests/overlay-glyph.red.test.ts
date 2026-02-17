import { describe, expect, it } from "vitest";
import type { ChunkSnapshot } from "@gen-dungeon/explorer-types";
import { renderGlyphAtlasSnapshot, renderSceneSnapshot } from "../src/draw-pipeline.js";

function chunkWithFixtureHexes(): ChunkSnapshot {
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
        ownerAdventurerId: null,
        decayLevel: 0,
        isClaimable: false,
        activeClaimCount: 1,
        adventurerCount: 0,
        plantCount: 0
      },
      {
        hexCoordinate: "0x3",
        biome: "Desert",
        ownerAdventurerId: null,
        decayLevel: 0,
        isClaimable: true,
        activeClaimCount: 0,
        adventurerCount: 0,
        plantCount: 0
      }
    ]
  };
}

describe("overlay and glyph snapshots (RED)", () => {
  it("overlay.biome_snapshot.red", () => {
    const snapshot = renderSceneSnapshot([chunkWithFixtureHexes()], "biome");
    expect(snapshot).toBe(
      [
        "grid|0:0|#",
        "hex|0x1|H",
        "hex|0x2|H",
        "hex|0x3|H",
        "overlay|0x1|P",
        "overlay|0x2|F",
        "overlay|0x3|D",
        "glyph|0x1|PLN",
        "glyph|0x2|FOR",
        "glyph|0x3|DES"
      ].join("\n")
    );
  });

  it("overlay.claim_snapshot.red", () => {
    const snapshot = renderSceneSnapshot([chunkWithFixtureHexes()], "claims");
    expect(snapshot).toBe(
      [
        "grid|0:0|#",
        "hex|0x1|H",
        "hex|0x2|H",
        "hex|0x3|H",
        "overlay|0x1|.",
        "overlay|0x2|C",
        "overlay|0x3|!",
        "glyph|0x1|DOT",
        "glyph|0x2|CLM",
        "glyph|0x3|ALR"
      ].join("\n")
    );
  });

  it("glyph.atlas_snapshot.red", () => {
    const snapshot = renderGlyphAtlasSnapshot(["PLN", "FOR", "DES"]);
    expect(snapshot).toBe(["DES|44-45-53", "FOR|46-4F-52", "PLN|50-4C-4E"].join("\n"));
  });
});
