import { describe, expect, it } from "vitest";
import { checkSchemaParity } from "../src/parity.js";
import type { ToriiViewsManifest } from "../src/manifest.js";

const manifestFixture: ToriiViewsManifest = {
  packageName: "@gen-dungeon/torii-views",
  schemaVersion: "explorer-v1",
  views: [
    {
      id: "explorer_hex_render_v1",
      sqlPath: "sql/views/v1/explorer_hex_render_v1.sql",
      description: "Chunk render payload rows for discovered hexes.",
      requiredModelFields: ["Hex.coordinate", "Hex.biome"]
    }
  ]
};

describe("schema parity (RED)", () => {
  it("flags missing required model fields", () => {
    const result = checkSchemaParity(manifestFixture, new Set(["Hex.coordinate"]));

    expect(result.ok).toBe(false);
    expect(result.missing).toContain("Hex.biome");
  });

  it("passes when all required model fields exist", () => {
    const result = checkSchemaParity(manifestFixture, new Set(["Hex.coordinate", "Hex.biome"]));

    expect(result.ok).toBe(true);
    expect(result.missing).toEqual([]);
  });
});
