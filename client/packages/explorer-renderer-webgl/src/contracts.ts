import type {
  ChunkSnapshot,
  HexCoordinate,
  LayerToggleState,
  StreamPatchEnvelope,
  ViewportWindow
} from "@gen-dungeon/explorer-types";

export interface RendererCameraConfig {
  minZoom: number;
  maxZoom: number;
  initialZoom: number;
}

export interface RendererInit {
  canvas: HTMLCanvasElement;
  dpr?: number;
  camera: RendererCameraConfig;
}

export interface RendererHandlers {
  onSelectHex?: (hexCoordinate: HexCoordinate) => void;
  onViewportChanged?: (viewport: ViewportWindow) => void;
}

export interface ExplorerRenderer {
  setHandlers(handlers: RendererHandlers): void;
  setViewport(viewport: ViewportWindow): void;
  setLayerState(layerState: LayerToggleState): void;
  replaceChunks(chunks: ChunkSnapshot[]): void;
  applyPatch(patch: StreamPatchEnvelope): void;
  setSelectedHex(hexCoordinate: HexCoordinate | null): void;
  resize(width: number, height: number, dpr?: number): void;
  renderFrame(nowMs: number): void;
  dispose(): void;
}
