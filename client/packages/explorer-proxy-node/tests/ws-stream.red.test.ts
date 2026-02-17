import { describe, expect, it } from "vitest";
import { createExplorerProxyStream, type ProxyPatchStreamRow } from "../src/ws-stream.js";

function row(
  sourceSequence: number,
  blockNumber: number,
  txIndex: number,
  eventIndex: number
): ProxyPatchStreamRow {
  return {
    sourceSequence,
    blockNumber,
    txIndex,
    eventIndex,
    kind: "hex_patch",
    payload: { id: `${blockNumber}-${txIndex}-${eventIndex}` }
  };
}

describe("proxy websocket stream contract (RED)", () => {
  it("ws.stream.sequence_monotonicity.red", () => {
    const stream = createExplorerProxyStream({
      initialOutputSequence: 40,
      initialSourceSequence: 0,
      clock: () => 1700000000000
    });
    const seen: number[] = [];
    stream.subscribe((patch) => {
      seen.push(patch.sequence);
    });

    stream.ingest([
      row(1, 10, 0, 0),
      row(2, 10, 1, 0),
      row(3, 11, 0, 0)
    ]);

    expect(seen).toEqual([41, 42, 43]);
  });

  it("ws.stream.emits_resync_required_on_gap.red", () => {
    const stream = createExplorerProxyStream({
      initialOutputSequence: 0,
      initialSourceSequence: 0,
      clock: () => 1700000000000
    });
    const seenKinds: string[] = [];
    stream.subscribe((patch) => {
      seenKinds.push(patch.kind);
    });

    stream.ingest([row(1, 10, 0, 0)]);
    stream.ingest([row(3, 11, 0, 0)]);

    expect(seenKinds).toEqual(["hex_patch", "resync_required", "hex_patch"]);
  });

  it("orders rows by block/tx/event before assigning output sequence", () => {
    const stream = createExplorerProxyStream({
      initialOutputSequence: 10,
      initialSourceSequence: 0,
      clock: () => 1700000000000
    });
    const ids: string[] = [];
    stream.subscribe((patch) => {
      if (patch.kind === "hex_patch") {
        ids.push(String((patch.payload as { id?: string }).id));
      }
    });

    stream.ingest([
      row(3, 11, 0, 0),
      row(2, 10, 1, 0),
      row(1, 10, 0, 1)
    ]);

    expect(ids).toEqual(["10-0-1", "10-1-0", "11-0-0"]);
  });
});
