import { describe, expect, it } from "vitest";
import {
  assignSequences,
  comparePatchOrder,
  sortRowsForStreaming,
  type ProxyPatchRow
} from "../src/patch-order";

const rows: ProxyPatchRow[] = [
  { blockNumber: 11, txIndex: 1, eventIndex: 0, kind: "hex_patch", payload: {} },
  { blockNumber: 10, txIndex: 2, eventIndex: 0, kind: "hex_patch", payload: {} },
  { blockNumber: 10, txIndex: 1, eventIndex: 2, kind: "hex_patch", payload: {} },
  { blockNumber: 10, txIndex: 1, eventIndex: 1, kind: "hex_patch", payload: {} }
];

describe("proxy patch ordering (RED->GREEN)", () => {
  it("sorts rows by block, tx, event index", () => {
    const sorted = sortRowsForStreaming(rows);
    const order = sorted.map((row) => `${row.blockNumber}-${row.txIndex}-${row.eventIndex}`);

    expect(order).toEqual(["10-1-1", "10-1-2", "10-2-0", "11-1-0"]);
  });

  it("assigns monotonic sequence values", () => {
    const sorted = sortRowsForStreaming(rows);
    const enveloped = assignSequences(sorted, 40);

    expect(enveloped[0].sequence).toBe(41);
    expect(enveloped[3].sequence).toBe(44);
  });

  it("comparePatchOrder is deterministic", () => {
    expect(comparePatchOrder(rows[0], rows[1])).toBeGreaterThan(0);
    expect(comparePatchOrder(rows[1], rows[0])).toBeLessThan(0);
  });
});
