import { describe, expect, it } from "vitest";
import { createSeededToriiSqlHarness } from "./sql-test-harness.js";

describe("torii SQL view semantics (RED)", () => {
  it("returns discovered rows only in hex_render", () => {
    const harness = createSeededToriiSqlHarness();
    const rows = harness.select<{ hex_coordinate: string }>(
      "SELECT hex_coordinate FROM explorer_hex_render_v1 ORDER BY hex_coordinate"
    );

    const coords = rows.map((row) => row.hex_coordinate);
    expect(coords).toEqual(["0x1", "0x3"]);
  });

  it("filters claim_active to ACTIVE claims", () => {
    const harness = createSeededToriiSqlHarness();
    const rows = harness.select<{ claim_id: string }>(
      "SELECT claim_id FROM explorer_claim_active_v1 ORDER BY claim_id"
    );

    expect(rows.map((row) => row.claim_id)).toEqual(["claim-active"]);
  });

  it("marks ownership consistency false when multiple owners control one hex", () => {
    const harness = createSeededToriiSqlHarness();
    const rows = harness.select<{ hex_coordinate: string; ownership_consistent: number }>(
      "SELECT hex_coordinate, ownership_consistent FROM explorer_area_control_v1 ORDER BY hex_coordinate"
    );

    const byHex = new Map(rows.map((row) => [row.hex_coordinate, row.ownership_consistent]));
    expect(byHex.get("0x1")).toBe(1);
    expect(byHex.get("0x3")).toBe(0);
  });

  it("orders event tail deterministically by block, tx, event desc", () => {
    const harness = createSeededToriiSqlHarness();
    const rows = harness.select<{ block_number: number; tx_index: number; event_index: number }>(
      "SELECT block_number, tx_index, event_index FROM explorer_event_tail_v1"
    );

    const order = rows.map((row) => `${row.block_number}-${row.tx_index}-${row.event_index}`);
    expect(order).toEqual(["12-0-0", "11-1-0", "11-0-1", "10-0-0"]);
  });

  it("computes claimable from claimable_since_block, not decay threshold", () => {
    const harness = createSeededToriiSqlHarness();
    const rows = harness.select<{ hex_coordinate: string; is_claimable: number }>(
      "SELECT hex_coordinate, is_claimable FROM explorer_hex_render_v1 ORDER BY hex_coordinate"
    );

    const byHex = new Map(rows.map((row) => [row.hex_coordinate, row.is_claimable]));
    expect(byHex.get("0x1")).toBe(0);
    expect(byHex.get("0x3")).toBe(1);
  });
});
