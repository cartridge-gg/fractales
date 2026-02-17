import { describe, expect, it } from "vitest";
import { createSeededToriiSqlHarness } from "./sql-test-harness.js";

function expectColumns(harness: ReturnType<typeof createSeededToriiSqlHarness>, viewName: string, expected: string[]) {
  const actual = harness.getViewColumns(viewName);
  for (const column of expected) {
    expect(actual).toContain(column);
  }
}

describe("torii SQL view shape (RED)", () => {
  it("exposes required columns for every v1 explorer view", () => {
    const harness = createSeededToriiSqlHarness();

    expectColumns(harness, "explorer_hex_base_v1", [
      "hex_coordinate",
      "biome",
      "discovery_block",
      "discoverer",
      "area_count",
      "decay_level",
      "current_energy_reserve",
      "last_decay_processed_block",
      "owner_adventurer_id"
    ]);

    expectColumns(harness, "explorer_hex_render_v1", [
      "hex_coordinate",
      "biome",
      "owner_adventurer_id",
      "decay_level",
      "is_claimable",
      "active_claim_count",
      "adventurer_count",
      "plant_count"
    ]);

    expectColumns(harness, "explorer_hex_inspect_v1", [
      "hex_coordinate",
      "area_id",
      "owner_adventurer_id",
      "claim_id",
      "plant_key",
      "reservation_id",
      "adventurer_id"
    ]);

    expectColumns(harness, "explorer_area_control_v1", [
      "hex_coordinate",
      "control_area_id",
      "controller_adventurer_id",
      "area_count",
      "ownership_consistent"
    ]);

    expectColumns(harness, "explorer_claim_active_v1", [
      "hex_coordinate",
      "claim_id",
      "claimant_adventurer_id",
      "energy_locked",
      "created_block",
      "expiry_block"
    ]);

    expectColumns(harness, "explorer_adventurer_presence_v1", [
      "adventurer_id",
      "owner",
      "is_alive",
      "current_hex",
      "energy",
      "activity_locked_until"
    ]);

    expectColumns(harness, "explorer_plant_status_v1", [
      "plant_key",
      "hex_coordinate",
      "area_id",
      "plant_id",
      "species",
      "current_yield",
      "reserved_yield",
      "max_yield",
      "regrowth_rate",
      "stress_level",
      "health"
    ]);

    expectColumns(harness, "explorer_event_tail_v1", [
      "block_number",
      "tx_index",
      "event_index",
      "event_name",
      "hex_coordinate",
      "adventurer_id",
      "payload_json"
    ]);
  });
});
