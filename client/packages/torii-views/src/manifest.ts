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
      id: "explorer_hex_base_v1",
      sqlPath: "sql/views/v1/explorer_hex_base_v1.sql",
      description: "Base discovered hex rows with decay overlays.",
      requiredModelFields: [
        "Hex.coordinate",
        "Hex.biome",
        "Hex.is_discovered",
        "HexDecayState.decay_level",
        "HexDecayState.claimable_since_block"
      ]
    },
    {
      id: "explorer_hex_render_v1",
      sqlPath: "sql/views/v1/explorer_hex_render_v1.sql",
      description: "Chunk render payload rows for discovered hexes.",
      requiredModelFields: [
        "Hex.coordinate",
        "Hex.biome",
        "Hex.is_discovered",
        "HexDecayState.decay_level",
        "HexDecayState.claimable_since_block"
      ]
    },
    {
      id: "explorer_hex_inspect_v1",
      sqlPath: "sql/views/v1/explorer_hex_inspect_v1.sql",
      description: "Full inspect joins for one hex.",
      requiredModelFields: [
        "Hex.coordinate",
        "HexArea.area_id",
        "AreaOwnership.owner_adventurer_id",
        "HexDecayState.decay_level",
        "HexDecayState.claimable_since_block",
        "ClaimEscrow.claim_id",
        "PlantNode.plant_id",
        "HarvestReservation.reservation_id",
        "Adventurer.adventurer_id"
      ]
    },
    {
      id: "explorer_area_control_v1",
      sqlPath: "sql/views/v1/explorer_area_control_v1.sql",
      description: "Single-controller ownership resolution per hex.",
      requiredModelFields: ["HexArea.area_id", "HexArea.hex_coordinate", "AreaOwnership.owner_adventurer_id"]
    },
    {
      id: "explorer_claim_active_v1",
      sqlPath: "sql/views/v1/explorer_claim_active_v1.sql",
      description: "Active claim escrow rows for claim overlays.",
      requiredModelFields: ["ClaimEscrow.claim_id", "ClaimEscrow.hex_coordinate", "ClaimEscrow.status"]
    },
    {
      id: "explorer_adventurer_presence_v1",
      sqlPath: "sql/views/v1/explorer_adventurer_presence_v1.sql",
      description: "Adventurer location and liveness overlay rows.",
      requiredModelFields: ["Adventurer.adventurer_id", "Adventurer.current_hex", "Adventurer.is_alive"]
    },
    {
      id: "explorer_plant_status_v1",
      sqlPath: "sql/views/v1/explorer_plant_status_v1.sql",
      description: "Plant status rows for resource overlays.",
      requiredModelFields: ["PlantNode.plant_key", "PlantNode.hex_coordinate", "PlantNode.current_yield"]
    },
    {
      id: "explorer_event_tail_v1",
      sqlPath: "sql/views/v1/explorer_event_tail_v1.sql",
      description: "Recent event tail rows ordered by block/tx/event.",
      requiredModelFields: []
    }
  ]
};
