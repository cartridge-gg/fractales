import { describe, expect, it } from "vitest";
import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
import { applyStreamPatch, applyStreamPatches, createPatchReducerState } from "../src/patch-reducer.js";

function patch(sequence: number): StreamPatchEnvelope {
  return {
    schemaVersion: "explorer-v1",
    sequence,
    blockNumber: 1000 + sequence,
    txIndex: 0,
    eventIndex: 0,
    kind: "hex_patch",
    payload: { hexCoordinate: "0x1" },
    emittedAtMs: 1700000000000 + sequence
  };
}

describe("stream patch ordering (RED)", () => {
  it("ignores stale out-of-order patches", () => {
    const afterSecond = applyStreamPatch(createPatchReducerState(), patch(2));
    const afterStale = applyStreamPatch(afterSecond, patch(1));

    expect(afterStale.lastAppliedSequence).toBe(2);
    expect(afterStale.applied).toHaveLength(1);
  });

  it("dedupes duplicate sequence patches", () => {
    const afterFirst = applyStreamPatch(createPatchReducerState(), patch(7));
    const afterDuplicate = applyStreamPatch(afterFirst, patch(7));

    expect(afterDuplicate.applied).toHaveLength(1);
  });

  it("apply_patch.orders_by_sequence_block_tx_event.red", () => {
    const patches: StreamPatchEnvelope[] = [
      {
        schemaVersion: "explorer-v1",
        sequence: 2,
        blockNumber: 12,
        txIndex: 0,
        eventIndex: 0,
        kind: "hex_patch",
        payload: { id: "s2-b12-t0-e0" },
        emittedAtMs: 1700000000002
      },
      {
        schemaVersion: "explorer-v1",
        sequence: 1,
        blockNumber: 10,
        txIndex: 1,
        eventIndex: 0,
        kind: "hex_patch",
        payload: { id: "s1-b10-t1-e0" },
        emittedAtMs: 1700000000001
      },
      {
        schemaVersion: "explorer-v1",
        sequence: 1,
        blockNumber: 10,
        txIndex: 0,
        eventIndex: 1,
        kind: "hex_patch",
        payload: { id: "s1-b10-t0-e1" },
        emittedAtMs: 1700000000001
      }
    ];

    const reduced = applyStreamPatches(createPatchReducerState(), patches);
    const ids = reduced.applied.map((entry) => String((entry.payload as { id?: string }).id));

    expect(ids).toEqual(["s1-b10-t0-e1", "s2-b12-t0-e0"]);
  });

  it("apply_patch.idempotent_for_duplicate_sequence.red", () => {
    const patches: StreamPatchEnvelope[] = [patch(3), patch(3), patch(4)];
    const reduced = applyStreamPatches(createPatchReducerState(), patches);

    expect(reduced.applied).toHaveLength(2);
    expect(reduced.lastAppliedSequence).toBe(4);
  });
});
