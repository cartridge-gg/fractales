import { describe, expect, it } from "vitest";
import { extractModelFieldSetFromSource } from "../src/model-field-parser.js";

const sampleGeneratedModels = `
export interface Hex {
  coordinate: string;
  biome: string;
  is_discovered: boolean;
}

export interface HexArea {
  area_id: string;
  hex_coordinate: string;
}
`;

describe("model field parser (RED->GREEN)", () => {
  it("extracts Model.field pairs from generated interface source", () => {
    const fields = extractModelFieldSetFromSource(sampleGeneratedModels);

    expect(fields.has("Hex.coordinate")).toBe(true);
    expect(fields.has("Hex.biome")).toBe(true);
    expect(fields.has("HexArea.area_id")).toBe(true);
  });

  it("ignores non-interface declarations", () => {
    const fields = extractModelFieldSetFromSource(
      `${sampleGeneratedModels}\nexport const schema = {};`
    );

    expect(fields.has("schema.foo")).toBe(false);
  });
});
