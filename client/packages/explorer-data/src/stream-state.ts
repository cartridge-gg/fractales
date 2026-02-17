import type { StreamPatchEnvelope, StreamStatus } from "@gen-dungeon/explorer-types";

export interface ExplorerStreamState {
  lastSequence: number;
  status: StreamStatus;
  resyncRequired: boolean;
  snapshotWatermarkSequence: number;
  replayBuffer: StreamPatchEnvelope[];
}

export function createStreamState(): ExplorerStreamState {
  return {
    lastSequence: 0,
    status: "live",
    resyncRequired: false,
    snapshotWatermarkSequence: 0,
    replayBuffer: []
  };
}

export function applyIncomingPatchMetadata(
  state: ExplorerStreamState,
  patch: StreamPatchEnvelope
): ExplorerStreamState {
  if (patch.sequence <= state.lastSequence) {
    return state;
  }

  if (patch.kind === "resync_required") {
    return {
      ...state,
      lastSequence: patch.sequence,
      status: "catching_up",
      resyncRequired: true
    };
  }

  if (state.lastSequence !== 0 && patch.sequence > state.lastSequence + 1) {
    return {
      ...state,
      lastSequence: patch.sequence,
      status: "catching_up",
      resyncRequired: true
    };
  }

  return {
    ...state,
    lastSequence: patch.sequence,
    status: "live",
    resyncRequired: false
  };
}

export function markStreamDisconnected(
  state: ExplorerStreamState
): ExplorerStreamState {
  return {
    ...state,
    status: "degraded",
    resyncRequired: true
  };
}

export function beginSnapshotResync(
  state: ExplorerStreamState
): ExplorerStreamState {
  return {
    ...state,
    status: "catching_up",
    resyncRequired: true,
    snapshotWatermarkSequence: state.lastSequence,
    replayBuffer: []
  };
}

export function applySnapshotWatermark(
  state: ExplorerStreamState,
  watermarkSequence: number
): ExplorerStreamState {
  const nextWatermark = Math.max(
    state.lastSequence,
    state.snapshotWatermarkSequence,
    watermarkSequence
  );
  const replayBuffer = state.replayBuffer.filter((patch) => patch.sequence > nextWatermark);

  return {
    ...state,
    status: "catching_up",
    resyncRequired: false,
    lastSequence: nextWatermark,
    snapshotWatermarkSequence: nextWatermark,
    replayBuffer
  };
}

function comparePatchOrder(
  a: StreamPatchEnvelope,
  b: StreamPatchEnvelope
): number {
  if (a.sequence !== b.sequence) {
    return a.sequence - b.sequence;
  }

  if (a.blockNumber !== b.blockNumber) {
    return a.blockNumber - b.blockNumber;
  }

  if (a.txIndex !== b.txIndex) {
    return a.txIndex - b.txIndex;
  }

  if (a.eventIndex !== b.eventIndex) {
    return a.eventIndex - b.eventIndex;
  }

  return 0;
}

export function bufferReplayPatch(
  state: ExplorerStreamState,
  patch: StreamPatchEnvelope
): ExplorerStreamState {
  if (patch.sequence <= state.snapshotWatermarkSequence) {
    return state;
  }

  const nextReplayBuffer = [...state.replayBuffer];
  const existingIndex = nextReplayBuffer.findIndex((entry) => entry.sequence === patch.sequence);

  if (existingIndex !== -1) {
    const current = nextReplayBuffer[existingIndex];
    if (current && comparePatchOrder(patch, current) < 0) {
      nextReplayBuffer[existingIndex] = patch;
    }
  } else {
    nextReplayBuffer.push(patch);
  }

  nextReplayBuffer.sort(comparePatchOrder);

  return {
    ...state,
    status: "catching_up",
    replayBuffer: nextReplayBuffer
  };
}

export function applyBufferedReplay(
  state: ExplorerStreamState
): ExplorerStreamState {
  const ordered = [...state.replayBuffer].sort(comparePatchOrder);
  const seeded: ExplorerStreamState = {
    ...state,
    status: "catching_up",
    resyncRequired: false,
    replayBuffer: [],
    lastSequence: Math.max(state.lastSequence, state.snapshotWatermarkSequence)
  };

  const replayed = ordered.reduce(applyIncomingPatchMetadata, seeded);
  if (replayed.resyncRequired) {
    return replayed;
  }

  return {
    ...replayed,
    status: "live",
    resyncRequired: false
  };
}
