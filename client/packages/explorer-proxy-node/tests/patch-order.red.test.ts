import { describe, expect, it } from "vitest";
import {
  assignSequences,
  comparePatchOrder,
  sortRowsForStreaming,
  type ProxyPatchRow
} from "../src/patch-order.js";

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

    expect(enveloped[0]?.sequence).toBe(41);
    expect(enveloped[3]?.sequence).toBe(44);
  });

  it("comparePatchOrder is deterministic", () => {
    const first = rows[0];
    const second = rows[1];
    if (!first || !second) {
      throw new Error("expected fixture rows");
    }
    expect(comparePatchOrder(first, second)).toBeGreaterThan(0);
    expect(comparePatchOrder(second, first)).toBeLessThan(0);
  });
});
