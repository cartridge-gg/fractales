import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";

export interface PatchReducerState {
  lastAppliedSequence: number;
  applied: StreamPatchEnvelope[];
}

export function createPatchReducerState(): PatchReducerState {
  return {
    lastAppliedSequence: 0,
    applied: []
  };
}

export function applyStreamPatch(
  state: PatchReducerState,
  patch: StreamPatchEnvelope
): PatchReducerState {
  if (patch.sequence <= state.lastAppliedSequence) {
    return state;
  }

  return {
    lastAppliedSequence: patch.sequence,
    applied: [...state.applied, patch]
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

export function applyStreamPatches(
  state: PatchReducerState,
  patches: StreamPatchEnvelope[]
): PatchReducerState {
  if (patches.length === 0) {
    return state;
  }

  const ordered = [...patches].sort(comparePatchOrder);
  return ordered.reduce(applyStreamPatch, state);
}
