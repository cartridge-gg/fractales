import type { PatchKind, StreamPatchEnvelope } from "@gen-dungeon/explorer-types";

export interface ProxyPatchRow {
  blockNumber: number;
  txIndex: number;
  eventIndex: number;
  kind: PatchKind;
  payload: unknown;
}

export function comparePatchOrder(a: ProxyPatchRow, b: ProxyPatchRow): number {
  if (a.blockNumber !== b.blockNumber) {
    return a.blockNumber - b.blockNumber;
  }
  if (a.txIndex !== b.txIndex) {
    return a.txIndex - b.txIndex;
  }
  return a.eventIndex - b.eventIndex;
}

export function sortRowsForStreaming(rows: ProxyPatchRow[]): ProxyPatchRow[] {
  return [...rows].sort(comparePatchOrder);
}

export function assignSequences(
  rows: ProxyPatchRow[],
  previousSequence: number
): StreamPatchEnvelope[] {
  let sequence = previousSequence;
  return rows.map((row) => {
    sequence += 1;
    return {
      schemaVersion: "explorer-v1",
      sequence,
      blockNumber: row.blockNumber,
      txIndex: row.txIndex,
      eventIndex: row.eventIndex,
      kind: row.kind,
      payload: row.payload,
      emittedAtMs: Date.now()
    };
  });
}
