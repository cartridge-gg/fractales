import { describe, expect, it } from "vitest";
import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
import {
  applyIncomingPatchMetadata,
  createStreamState
} from "../src/stream-state.js";

function patch(sequence: number): StreamPatchEnvelope {
  return {
    schemaVersion: "explorer-v1",
    sequence,
    blockNumber: 100 + sequence,
    txIndex: 0,
    eventIndex: 0,
    kind: "heartbeat",
    payload: {},
    emittedAtMs: 1700000000000 + sequence
  };
}

describe("stream state (RED->GREEN)", () => {
  it("stays live for contiguous sequences", () => {
    let state = createStreamState();
    state = applyIncomingPatchMetadata(state, patch(1));
    state = applyIncomingPatchMetadata(state, patch(2));

    expect(state.status).toBe("live");
    expect(state.lastSequence).toBe(2);
  });

  it("moves to catching_up and flags resync on sequence gaps", () => {
    let state = createStreamState();
    state = applyIncomingPatchMetadata(state, patch(1));
    state = applyIncomingPatchMetadata(state, patch(4));

    expect(state.status).toBe("catching_up");
    expect(state.resyncRequired).toBe(true);
  });
});
