import type { ExplorerSchemaVersion } from "@gen-dungeon/explorer-types";

export interface ViewDefinition {
  id: string;
  sqlPath: string;
  description: string;
  requiredModelFields: readonly string[];
}

export interface ToriiViewsManifest {
  packageName: "@gen-dungeon/torii-views";
  schemaVersion: ExplorerSchemaVersion;
  views: readonly ViewDefinition[];
}

export const toriiViewsManifestV1: ToriiViewsManifest = {
  packageName: "@gen-dungeon/torii-views",
  schemaVersion: "explorer-v1",
  views: [
    {
      id: "explorer_hex_render_v1",
      sqlPath: "sql/views/v1/explorer_hex_render_v1.sql",
      description: "Chunk render payload rows for discovered hexes.",
      requiredModelFields: ["Hex.coordinate", "Hex.biome", "Hex.is_discovered"]
    },
    {
      id: "explorer_hex_inspect_v1",
      sqlPath: "sql/views/v1/explorer_hex_inspect_v1.sql",
      description: "Full inspect joins for one hex.",
      requiredModelFields: ["Hex.coordinate", "HexArea.area_id", "PlantNode.plant_id", "ClaimEscrow.claim_id"]
    }
  ]
};
