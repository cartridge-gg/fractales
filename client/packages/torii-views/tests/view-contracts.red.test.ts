import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { toriiViewsManifestV1 } from "../src/manifest.js";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

describe("torii view contracts (RED)", () => {
  it("views.hex_render.returns_discovered_rows_only.red", () => {
    const renderSql = readFileSync(
      resolve(packageRoot, "sql/views/v1/explorer_hex_render_v1.sql"),
      "utf8"
    );

    expect(renderSql).toContain("WHERE h.is_discovered = 1");
  });

  it("views.hex_inspect.includes_all_joined_fields.red", () => {
    const inspectSql = readFileSync(
      resolve(packageRoot, "sql/views/v1/explorer_hex_inspect_v1.sql"),
      "utf8"
    );

    const requiredJoinModels = [
      "{{HexArea}}",
      "{{AreaOwnership}}",
      "{{HexDecayState}}",
      "{{ClaimEscrow}}",
      "{{PlantNode}}",
      "{{HarvestReservation}}",
      "{{Adventurer}}"
    ];

    for (const modelTag of requiredJoinModels) {
      expect(inspectSql).toContain(modelTag);
    }
  });

  it("views.claim_active.filters_expired_escrow.red", () => {
    const claimSql = readFileSync(
      resolve(packageRoot, "sql/views/v1/explorer_claim_active_v1.sql"),
      "utf8"
    );

    expect(claimSql).toContain("WHERE ce.status = 1");
  });

  it("manifest declares full v1 logical view catalog", () => {
    const actualIds = new Set(toriiViewsManifestV1.views.map((view) => view.id));
    const expectedIds = [
      "explorer_hex_base_v1",
      "explorer_hex_render_v1",
      "explorer_hex_inspect_v1",
      "explorer_area_control_v1",
      "explorer_claim_active_v1",
      "explorer_adventurer_presence_v1",
      "explorer_plant_status_v1",
      "explorer_event_tail_v1"
    ];

    for (const expectedId of expectedIds) {
      expect(actualIds.has(expectedId)).toBe(true);
    }
  });
});
