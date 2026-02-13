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
