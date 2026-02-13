import { describe, expect, it } from "vitest";
import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
import { applyStreamPatch, createPatchReducerState } from "../src/patch-reducer";

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
});
