import type { ExplorerDataStore, ExplorerProxyClient, ExplorerSelectors } from "@gen-dungeon/explorer-data";
import type { ExplorerRenderer } from "@gen-dungeon/explorer-renderer-webgl";
import type { HexCoordinate, LayerToggleState, SearchQuery, StreamStatus } from "@gen-dungeon/explorer-types";

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
  setSearchResults(results: readonly { hexCoordinate: HexCoordinate; label: string }[]): void;
}

export interface ExplorerApp {
  mount(): Promise<void>;
  unmount(): void;
  jumpTo(query: SearchQuery): Promise<void>;
}
