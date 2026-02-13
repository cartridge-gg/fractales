import type { StreamPatchEnvelope, StreamStatus } from "@gen-dungeon/explorer-types";

export interface ExplorerStreamState {
  lastSequence: number;
  status: StreamStatus;
  resyncRequired: boolean;
}

export function createStreamState(): ExplorerStreamState {
  return {
    lastSequence: 0,
    status: "live",
    resyncRequired: false
  };
}

export function applyIncomingPatchMetadata(
  state: ExplorerStreamState,
  patch: StreamPatchEnvelope
): ExplorerStreamState {
  if (patch.sequence <= state.lastSequence) {
    return state;
  }

  if (state.lastSequence !== 0 && patch.sequence > state.lastSequence + 1) {
    return {
      lastSequence: patch.sequence,
      status: "catching_up",
      resyncRequired: true
    };
  }

  return {
    lastSequence: patch.sequence,
    status: "live",
    resyncRequired: false
  };
}
