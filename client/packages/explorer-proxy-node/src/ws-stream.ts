import type { StreamPatchEnvelope } from "@gen-dungeon/explorer-types";
import type { ExplorerProxyStream } from "./contracts.js";
import { sortRowsForStreaming, type ProxyPatchRow } from "./patch-order.js";

export interface ProxyPatchStreamRow extends ProxyPatchRow {
  sourceSequence: number;
}

export interface ExplorerProxyStreamController extends ExplorerProxyStream {
  ingest(rows: ProxyPatchStreamRow[]): void;
  snapshot(): {
    lastOutputSequence: number;
    lastSourceSequence: number;
  };
}

export interface CreateExplorerProxyStreamOptions {
  initialOutputSequence?: number;
  initialSourceSequence?: number;
  clock?: () => number;
}

export function createExplorerProxyStream(
  options: CreateExplorerProxyStreamOptions = {}
): ExplorerProxyStreamController {
  let lastOutputSequence = options.initialOutputSequence ?? 0;
  let lastSourceSequence = options.initialSourceSequence ?? 0;
  const now = options.clock ?? Date.now;
  const subscribers = new Set<(patch: StreamPatchEnvelope) => void>();

  return {
    subscribe(handler) {
      subscribers.add(handler);
      return () => {
        subscribers.delete(handler);
      };
    },
    ingest(rows) {
      const orderedRows = sortRowsForStreaming(rows) as ProxyPatchStreamRow[];
      for (const row of orderedRows) {
        if (row.sourceSequence <= lastSourceSequence) {
          continue;
        }

        if (lastSourceSequence !== 0 && row.sourceSequence > lastSourceSequence + 1) {
          emit({
            kind: "resync_required",
            payload: {
              expectedSourceSequence: lastSourceSequence + 1,
              receivedSourceSequence: row.sourceSequence
            },
            blockNumber: row.blockNumber,
            txIndex: row.txIndex,
            eventIndex: row.eventIndex
          });
        }

        emit({
          kind: row.kind,
          payload: row.payload,
          blockNumber: row.blockNumber,
          txIndex: row.txIndex,
          eventIndex: row.eventIndex
        });

        lastSourceSequence = row.sourceSequence;
      }
    },
    snapshot() {
      return {
        lastOutputSequence,
        lastSourceSequence
      };
    }
  };

  function emit(input: {
    kind: StreamPatchEnvelope["kind"];
    payload: unknown;
    blockNumber: number;
    txIndex: number;
    eventIndex: number;
  }): void {
    lastOutputSequence += 1;
    const patch: StreamPatchEnvelope = {
      schemaVersion: "explorer-v1",
      sequence: lastOutputSequence,
      blockNumber: input.blockNumber,
      txIndex: input.txIndex,
      eventIndex: input.eventIndex,
      kind: input.kind,
      payload: input.payload,
      emittedAtMs: now()
    };

    for (const subscriber of subscribers) {
      subscriber(patch);
    }
  }
}
