import type { ExplorerDataStore, ExplorerProxyClient, ExplorerSelectors } from "@gen-dungeon/explorer-data";
import type { ExplorerRenderer } from "@gen-dungeon/explorer-renderer-webgl";
import type {
  HexCoordinate,
  HexInspectPayload,
  LayerId,
  LayerToggleState,
  SearchQuery,
  StreamStatus,
  ViewportWindow
} from "@gen-dungeon/explorer-types";

export interface ExplorerAppDependencies {
  proxyClient: ExplorerProxyClient;
  store: ExplorerDataStore;
  selectors: ExplorerSelectors;
  renderer: ExplorerRenderer;
}

export interface ExplorerUiBindings {
  setConnectionStatus(status: StreamStatus): void;
  setLayerState(state: LayerToggleState): void;
  setSelectedHex(hexCoordinate: HexCoordinate | null): void;
  setInspectPayload(payload: HexInspectPayload | null): void;
  setSearchResults(results: readonly { hexCoordinate: HexCoordinate; label: string }[]): void;
}

export interface ExplorerAppSnapshot {
  status: StreamStatus;
  selectedHex: HexCoordinate | null;
  viewport: ViewportWindow;
  layerState: LayerToggleState;
  visibleHexes: readonly { hexCoordinate: HexCoordinate }[];
  layout: "desktop" | "mobile";
  url: string;
}

export interface ExplorerApp {
  mount(): Promise<void>;
  unmount(): void;
  jumpTo(query: SearchQuery): Promise<void>;
  setLayerToggle(layer: LayerId, enabled: boolean): void;
  setAllLayers(enabled: boolean): void;
  panBy(deltaX: number, deltaY: number): Promise<void>;
  zoomTo(zoom: number): Promise<void>;
  updateStreamStatus(status: StreamStatus): Promise<void>;
  hydrateFromUrl(url: string): Promise<void>;
  currentUrl(): string;
  applyMobilePan(deltaX: number, deltaY: number): Promise<void>;
  applyMobilePinch(scale: number): Promise<void>;
  applyMobileTap(hexCoordinate: HexCoordinate): Promise<void>;
  resize(width: number, height: number, dpr?: number): Promise<void>;
  snapshot(): ExplorerAppSnapshot;
}
