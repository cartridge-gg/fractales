import { describe, expect, it } from "vitest";
import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
import {
  applyIncomingPatchMetadata,
  applyBufferedReplay,
  applySnapshotWatermark,
  beginSnapshotResync,
  bufferReplayPatch,
  createStreamState,
  markStreamDisconnected
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

function resyncPatch(
  sequence: number,
  expectedSourceSequence: number,
  receivedSourceSequence: number
): StreamPatchEnvelope {
  return {
    schemaVersion: "explorer-v1",
    sequence,
    blockNumber: 100 + sequence,
    txIndex: 0,
    eventIndex: 0,
    kind: "resync_required",
    payload: {
      expectedSourceSequence,
      receivedSourceSequence
    },
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

  it("reconnect.triggers_snapshot_resync.red", () => {
    let state = createStreamState();
    state = applyIncomingPatchMetadata(state, patch(1));
    state = markStreamDisconnected(state);

    expect(state.status).toBe("degraded");
    expect(state.resyncRequired).toBe(true);

    state = beginSnapshotResync(state);

    expect(state.status).toBe("catching_up");
    expect(state.resyncRequired).toBe(true);
    expect(state.replayBuffer).toEqual([]);
  });

  it("reconnect.enters_catching_up_on_resync_required_patch.red", () => {
    let state = createStreamState();
    state = applyIncomingPatchMetadata(state, patch(1));
    state = applyIncomingPatchMetadata(state, resyncPatch(2, 2, 4));

    expect(state.status).toBe("catching_up");
    expect(state.resyncRequired).toBe(true);
  });

  it("reconnect.replays_buffer_newer_than_snapshot_watermark.red", () => {
    let state = createStreamState();
    state = applyIncomingPatchMetadata(state, patch(10));
    state = markStreamDisconnected(state);
    state = beginSnapshotResync(state);
    state = applySnapshotWatermark(state, 12);

    state = bufferReplayPatch(state, patch(11));
    state = bufferReplayPatch(state, patch(14));
    state = bufferReplayPatch(state, patch(13));
    state = bufferReplayPatch(state, patch(13));

    expect(state.replayBuffer.map((entry) => entry.sequence)).toEqual([13, 14]);

    state = applyBufferedReplay(state);

    expect(state.status).toBe("live");
    expect(state.resyncRequired).toBe(false);
    expect(state.lastSequence).toBe(14);
    expect(state.replayBuffer).toHaveLength(0);
  });
});
