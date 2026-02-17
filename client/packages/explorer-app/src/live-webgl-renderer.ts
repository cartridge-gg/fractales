import type { ExplorerRenderer, RendererHandlers } from "@gen-dungeon/explorer-renderer-webgl";
import {
  buildChunkRenderSet,
  renderSceneSnapshot,
  type ChunkRenderSet,
  type OverlayMode
} from "@gen-dungeon/explorer-renderer-webgl";
import type {
  ChunkKey,
  ChunkSnapshot,
  HexCoordinate,
  LayerToggleState,
  StreamPatchEnvelope,
  ViewportWindow
} from "@gen-dungeon/explorer-types";
import { CanvasMockRenderer } from "./dev-runtime.js";

const DEFAULT_LAYER_STATE: LayerToggleState = {
  biome: true,
  ownership: false,
  claims: false,
  adventurers: false,
  resources: false,
  decay: false
};

const DEFAULT_VIEWPORT: ViewportWindow = {
  center: { x: 0, y: 0 },
  width: 1280,
  height: 720,
  zoom: 1
};

interface HexPatchUpdate {
  chunkKey: ChunkKey;
  hex: ChunkSnapshot["hexes"][number];
  headBlock?: number;
}

export class LiveWebglRendererAdapter implements ExplorerRenderer {
  private readonly delegate: CanvasMockRenderer;
  private chunks: ChunkSnapshot[] = [];
  private layerState: LayerToggleState = DEFAULT_LAYER_STATE;
  private viewport: ViewportWindow = DEFAULT_VIEWPORT;
  private lastAppliedSequence = 0;
  private sceneSnapshot = "";
  private renderSet: ChunkRenderSet = {
    visibleChunkKeys: [],
    prefetchChunkKeys: [],
    renderChunkKeys: []
  };

  constructor(canvas: HTMLCanvasElement) {
    this.delegate = new CanvasMockRenderer(canvas);
  }

  setHandlers(handlers: RendererHandlers): void {
    this.delegate.setHandlers({
      ...handlers,
      onViewportChanged: (viewport) => {
        this.viewport = viewport;
        this.recomputeWebglScene();
        handlers.onViewportChanged?.(viewport);
      }
    });
  }

  setViewport(viewport: ViewportWindow): void {
    this.viewport = viewport;
    this.delegate.setViewport(viewport);
    this.recomputeWebglScene();
  }

  setLayerState(layerState: LayerToggleState): void {
    this.layerState = layerState;
    this.delegate.setLayerState(layerState);
    this.recomputeWebglScene();
  }

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.chunks = chunks;
    this.delegate.replaceChunks(chunks);
    this.recomputeWebglScene();
  }

  applyPatch(patch: StreamPatchEnvelope): void {
    if (patch.sequence <= this.lastAppliedSequence) {
      return;
    }
    this.lastAppliedSequence = patch.sequence;
    this.chunks = applyPatchToChunks(this.chunks, patch);
    this.delegate.applyPatch(patch);
    this.recomputeWebglScene();
  }

  setSelectedHex(hexCoordinate: HexCoordinate | null): void {
    this.delegate.setSelectedHex(hexCoordinate);
  }

  resize(width: number, height: number, dpr?: number): void {
    this.viewport = {
      ...this.viewport,
      width,
      height
    };
    this.delegate.resize(width, height, dpr);
    this.recomputeWebglScene();
  }

  renderFrame(nowMs: number): void {
    this.delegate.renderFrame(nowMs);
  }

  dispose(): void {
    this.delegate.dispose();
  }

  getDebugSceneSnapshot(): string {
    return this.sceneSnapshot;
  }

  getDebugRenderSet(): ChunkRenderSet {
    return this.renderSet;
  }

  private recomputeWebglScene(): void {
    this.renderSet = buildChunkRenderSet({
      loadedChunks: this.chunks,
      viewport: this.viewport,
      prefetchRing: 1
    });
    const renderSet = new Set(this.renderSet.renderChunkKeys);
    const renderableChunks = this.chunks.filter((chunk) => renderSet.has(chunk.chunk.key));
    this.sceneSnapshot = renderSceneSnapshot(
      renderableChunks,
      overlayModeFromLayerState(this.layerState)
    );
  }
}

function overlayModeFromLayerState(layerState: LayerToggleState): OverlayMode {
  const nonBiomeEnabled = Number(layerState.ownership) +
    Number(layerState.claims) +
    Number(layerState.adventurers) +
    Number(layerState.resources) +
    Number(layerState.decay);

  if (nonBiomeEnabled === 0) {
    return "biome";
  }

  if (nonBiomeEnabled === 1 && layerState.claims) {
    return "claims";
  }

  return "composite";
}

function applyPatchToChunks(
  chunks: ChunkSnapshot[],
  patch: StreamPatchEnvelope
): ChunkSnapshot[] {
  if (patch.kind === "chunk_snapshot") {
    const snapshot = toChunkSnapshotFromPatchPayload(patch.payload);
    if (!snapshot) {
      return chunks;
    }
    return upsertChunk(chunks, snapshot);
  }

  if (patch.kind === "hex_patch") {
    const update = toHexPatchUpdate(patch.payload);
    if (!update) {
      return chunks;
    }
    return upsertHex(chunks, update, patch.blockNumber);
  }

  return chunks;
}

function toChunkSnapshotFromPatchPayload(payload: unknown): ChunkSnapshot | null {
  if (isChunkSnapshotPayload(payload)) {
    return payload;
  }

  if (
    payload &&
    typeof payload === "object" &&
    "chunk" in payload &&
    isChunkSnapshotPayload((payload as { chunk?: unknown }).chunk)
  ) {
    return (payload as { chunk: ChunkSnapshot }).chunk;
  }

  return null;
}

function toHexPatchUpdate(payload: unknown): HexPatchUpdate | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const row = payload as {
    chunkKey?: unknown;
    chunk?: { key?: unknown } | null;
    hex?: unknown;
    row?: unknown;
    headBlock?: unknown;
  };
  const chunkKeyRaw = row.chunkKey ?? row.chunk?.key;
  if (typeof chunkKeyRaw !== "string") {
    return null;
  }

  const hexRaw = row.hex ?? row.row;
  if (!isHexRenderRowPayload(hexRaw)) {
    return null;
  }

  const headBlock =
    typeof row.headBlock === "number" && Number.isFinite(row.headBlock)
      ? Math.floor(row.headBlock)
      : undefined;

  const update: HexPatchUpdate = {
    chunkKey: chunkKeyRaw as ChunkKey,
    hex: hexRaw
  };
  if (headBlock !== undefined) {
    update.headBlock = headBlock;
  }
  return update;
}

function isChunkSnapshotPayload(payload: unknown): payload is ChunkSnapshot {
  if (!payload || typeof payload !== "object") {
    return false;
  }

  const row = payload as {
    schemaVersion?: unknown;
    chunk?: { key?: unknown; chunkQ?: unknown; chunkR?: unknown } | null;
    headBlock?: unknown;
    hexes?: unknown;
  };
  if (row.schemaVersion !== "explorer-v1") {
    return false;
  }
  if (!row.chunk || typeof row.chunk.key !== "string") {
    return false;
  }
  if (typeof row.chunk.chunkQ !== "number" || typeof row.chunk.chunkR !== "number") {
    return false;
  }
  if (typeof row.headBlock !== "number" || !Number.isFinite(row.headBlock)) {
    return false;
  }
  if (!Array.isArray(row.hexes)) {
    return false;
  }

  return row.hexes.every(isHexRenderRowPayload);
}

function isHexRenderRowPayload(
  payload: unknown
): payload is ChunkSnapshot["hexes"][number] {
  if (!payload || typeof payload !== "object") {
    return false;
  }

  const row = payload as {
    hexCoordinate?: unknown;
    biome?: unknown;
    ownerAdventurerId?: unknown;
    decayLevel?: unknown;
    isClaimable?: unknown;
    activeClaimCount?: unknown;
    adventurerCount?: unknown;
    plantCount?: unknown;
  };

  return (
    typeof row.hexCoordinate === "string" &&
    typeof row.biome === "string" &&
    (typeof row.ownerAdventurerId === "string" || row.ownerAdventurerId === null) &&
    typeof row.decayLevel === "number" &&
    Number.isFinite(row.decayLevel) &&
    typeof row.isClaimable === "boolean" &&
    typeof row.activeClaimCount === "number" &&
    Number.isFinite(row.activeClaimCount) &&
    typeof row.adventurerCount === "number" &&
    Number.isFinite(row.adventurerCount) &&
    typeof row.plantCount === "number" &&
    Number.isFinite(row.plantCount)
  );
}

function upsertChunk(chunks: ChunkSnapshot[], updated: ChunkSnapshot): ChunkSnapshot[] {
  const next = [...chunks];
  const index = next.findIndex((chunk) => chunk.chunk.key === updated.chunk.key);
  if (index === -1) {
    next.push(updated);
  } else {
    next[index] = updated;
  }

  return next.sort((left, right) => compareChunkKeys(left.chunk.key, right.chunk.key));
}

function upsertHex(
  chunks: ChunkSnapshot[],
  update: HexPatchUpdate,
  blockNumber: number
): ChunkSnapshot[] {
  const index = chunks.findIndex((chunk) => chunk.chunk.key === update.chunkKey);
  const baseChunk = index === -1 ? createEmptyChunk(update.chunkKey) : chunks[index];
  if (!baseChunk) {
    return chunks;
  }

  const hexes = [...baseChunk.hexes];
  const hexIndex = hexes.findIndex((hex) => hex.hexCoordinate === update.hex.hexCoordinate);
  if (hexIndex === -1) {
    hexes.push(update.hex);
  } else {
    hexes[hexIndex] = update.hex;
  }

  const updated: ChunkSnapshot = {
    ...baseChunk,
    headBlock: Math.max(baseChunk.headBlock, update.headBlock ?? 0, blockNumber),
    hexes
  };
  return upsertChunk(chunks, updated);
}

function compareChunkKeys(a: ChunkKey, b: ChunkKey): number {
  const [aq, ar] = parseChunkKey(a);
  const [bq, br] = parseChunkKey(b);
  if (aq !== bq) {
    return aq - bq;
  }
  return ar - br;
}

function parseChunkKey(key: ChunkKey): [number, number] {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return [qRaw ?? 0, rRaw ?? 0];
}

function createEmptyChunk(key: ChunkKey): ChunkSnapshot {
  const [chunkQ, chunkR] = parseChunkKey(key);
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ,
      chunkR
    },
    headBlock: 0,
    hexes: []
  };
}
