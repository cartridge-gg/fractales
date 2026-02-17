import type { ExplorerStreamSubscription } from "@gen-dungeon/explorer-data";
import type {
  ChunkSnapshot,
  HexCoordinate,
  LayerId,
  LayerToggleState,
  SearchQuery,
  StreamPatchEnvelope,
  StreamStatus,
  ViewportWindow
} from "@gen-dungeon/explorer-types";
import type {
  ExplorerApp,
  ExplorerAppDependencies,
  ExplorerAppSnapshot,
  ExplorerUiBindings
} from "./contracts.js";

export interface CreateExplorerAppOptions {
  ui: ExplorerUiBindings;
  initialViewport?: ViewportWindow;
  initialLayerState?: LayerToggleState;
  initialStatus?: StreamStatus;
  mobileBreakpointPx?: number;
  routeBasePath?: string;
}

const DEFAULT_VIEWPORT: ViewportWindow = {
  center: { x: 0, y: 0 },
  width: 1280,
  height: 720,
  zoom: 1
};

const DEFAULT_LAYER_STATE: LayerToggleState = {
  biome: true,
  ownership: false,
  claims: false,
  adventurers: false,
  resources: false,
  decay: false
};

const MIN_ZOOM = 0.5;
const MAX_ZOOM = 3;

export function createExplorerApp(
  dependencies: ExplorerAppDependencies,
  options: CreateExplorerAppOptions
): ExplorerApp {
  const ui = options.ui;
  const routeBasePath = options.routeBasePath ?? "/explorer";
  const mobileBreakpointPx = options.mobileBreakpointPx ?? 768;
  const state: InternalAppState = {
    mounted: false,
    status: options.initialStatus ?? "live",
    selectedHex: null,
    viewport: options.initialViewport ?? DEFAULT_VIEWPORT,
    layerState: options.initialLayerState ?? DEFAULT_LAYER_STATE,
    visibleHexes: [],
    layout:
      (options.initialViewport ?? DEFAULT_VIEWPORT).width < mobileBreakpointPx
        ? "mobile"
        : "desktop",
    url: routeBasePath
  };

  let subscription: ExplorerStreamSubscription | null = null;

  const app: ExplorerApp = {
    async mount() {
      if (state.mounted) {
        return;
      }

      state.mounted = true;
      dependencies.renderer.setHandlers({
        onSelectHex: (hexCoordinate) => {
          void selectHex(hexCoordinate);
        },
        onViewportChanged: (viewport) => {
          void setViewport(viewport);
        }
      });

      dependencies.renderer.setLayerState(state.layerState);
      dependencies.renderer.setViewport(state.viewport);
      ui.setLayerState(state.layerState);
      ui.setConnectionStatus(state.status);
      ui.setInspectPayload(null);

      await reloadVisibleChunks();
      refreshVisibleHexes();

      subscription = dependencies.proxyClient.subscribePatches({
        onPatch: (patch) => {
          dependencies.store.applyPatch(patch);
          dependencies.renderer.applyPatch(patch);
          refreshVisibleHexes();
          void refreshSelectedInspectIfAffected(patch);
        },
        onStatus: (status) => {
          void app.updateStreamStatus(status);
        },
        onError: () => {
          void app.updateStreamStatus("degraded");
        }
      });
    },
    unmount() {
      if (!state.mounted) {
        return;
      }

      subscription?.close();
      subscription = null;
      dependencies.renderer.dispose();
      state.mounted = false;
    },
    async jumpTo(query) {
      const normalizedQuery = normalizeSearchQuery(query);
      const results = await dependencies.proxyClient.search(normalizedQuery);
      const searchResults = results.map((result) => ({
        hexCoordinate: result.hexCoordinate,
        label: `${result.reason}:${result.hexCoordinate}`
      }));
      ui.setSearchResults(searchResults);

      if (searchResults.length > 0) {
        const first = searchResults[0];
        if (first) {
          await selectHex(first.hexCoordinate);
        }
      }

      state.url = buildDeepLink(routeBasePath, normalizedQuery, state.selectedHex);
    },
    setLayerToggle(layer, enabled) {
      state.layerState = {
        ...state.layerState,
        [layer]: enabled
      };
      dependencies.renderer.setLayerState(state.layerState);
      ui.setLayerState(state.layerState);
      refreshVisibleHexes();
    },
    setAllLayers(enabled) {
      state.layerState = setAllLayers(state.layerState, enabled);
      dependencies.renderer.setLayerState(state.layerState);
      ui.setLayerState(state.layerState);
      refreshVisibleHexes();
    },
    async panBy(deltaX, deltaY) {
      await setViewport({
        ...state.viewport,
        center: {
          x: state.viewport.center.x + deltaX,
          y: state.viewport.center.y + deltaY
        }
      });
    },
    async zoomTo(zoom) {
      await setViewport({
        ...state.viewport,
        zoom: clamp(zoom, MIN_ZOOM, MAX_ZOOM)
      });
    },
    async updateStreamStatus(status) {
      state.status = status;
      ui.setConnectionStatus(status);

      if (status === "catching_up") {
        await reloadVisibleChunks();
        state.status = "live";
        ui.setConnectionStatus("live");
      }
    },
    async hydrateFromUrl(url) {
      const query = parseDeepLink(url);
      if (!query) {
        state.url = routeBasePath;
        return;
      }

      if (query.coord) {
        await selectHex(query.coord);
      } else {
        await app.jumpTo(query);
      }
      state.url = buildDeepLink(routeBasePath, query, state.selectedHex);
    },
    currentUrl() {
      return state.url;
    },
    async applyMobilePan(deltaX, deltaY) {
      await app.panBy(deltaX, deltaY);
    },
    async applyMobilePinch(scale) {
      const nextZoom = state.viewport.zoom * scale;
      await app.zoomTo(nextZoom);
    },
    async applyMobileTap(hexCoordinate) {
      await selectHex(hexCoordinate);
    },
    async resize(width, height, dpr = 1) {
      dependencies.renderer.resize(width, height, dpr);
      state.layout = width < mobileBreakpointPx ? "mobile" : "desktop";
      await setViewport({
        ...state.viewport,
        width,
        height
      });
    },
    snapshot() {
      return {
        status: state.status,
        selectedHex: state.selectedHex,
        viewport: state.viewport,
        layerState: state.layerState,
        visibleHexes: state.visibleHexes.map((hex) => ({ hexCoordinate: hex.hexCoordinate })),
        layout: state.layout,
        url: state.url
      } satisfies ExplorerAppSnapshot;
    }
  };

  return app;

  async function setViewport(nextViewport: ViewportWindow): Promise<void> {
    state.viewport = nextViewport;
    dependencies.renderer.setViewport(nextViewport);
    await reloadVisibleChunks();
    refreshVisibleHexes();
  }

  async function selectHex(hexCoordinate: HexCoordinate | null): Promise<void> {
    state.selectedHex = hexCoordinate;
    dependencies.store.setSelectedHex(hexCoordinate);
    dependencies.renderer.setSelectedHex(hexCoordinate);
    ui.setSelectedHex(hexCoordinate);

    if (hexCoordinate !== null) {
      const inspectPayload = await dependencies.proxyClient.getHexInspect(hexCoordinate);
      ui.setInspectPayload(inspectPayload);
      state.url = buildDeepLink(routeBasePath, { coord: hexCoordinate }, hexCoordinate);
    } else {
      ui.setInspectPayload(null);
      state.url = routeBasePath;
    }
  }

  async function reloadVisibleChunks(): Promise<void> {
    const keys = dependencies.selectors.visibleChunkKeys(state.viewport);
    if (keys.length === 0) {
      dependencies.store.replaceChunks([]);
      dependencies.renderer.replaceChunks([]);
      return;
    }

    const chunks = await dependencies.proxyClient.getChunks(keys);
    dependencies.store.replaceChunks(chunks);
    dependencies.renderer.replaceChunks(chunks);
  }

  function refreshVisibleHexes(): void {
    state.visibleHexes = dependencies.selectors.visibleHexes(
      state.viewport,
      state.layerState
    );
  }

  async function refreshSelectedInspectIfAffected(
    patch: StreamPatchEnvelope
  ): Promise<void> {
    if (state.selectedHex === null) {
      return;
    }

    if (!patchTouchesHex(patch, state.selectedHex)) {
      return;
    }

    const inspectPayload = await dependencies.proxyClient.getHexInspect(state.selectedHex);
    ui.setInspectPayload(inspectPayload);
  }
}

interface InternalAppState {
  mounted: boolean;
  status: StreamStatus;
  selectedHex: HexCoordinate | null;
  viewport: ViewportWindow;
  layerState: LayerToggleState;
  visibleHexes: readonly { hexCoordinate: HexCoordinate }[];
  layout: "desktop" | "mobile";
  url: string;
}

function normalizeSearchQuery(query: SearchQuery): SearchQuery {
  if (query.coord) {
    return query.limit === undefined
      ? { coord: query.coord }
      : { coord: query.coord, limit: query.limit };
  }

  if (query.owner) {
    return query.limit === undefined
      ? { owner: query.owner }
      : { owner: query.owner, limit: query.limit };
  }

  if (query.adventurer) {
    return query.limit === undefined
      ? { adventurer: query.adventurer }
      : { adventurer: query.adventurer, limit: query.limit };
  }

  return {};
}

function setAllLayers(
  state: LayerToggleState,
  enabled: boolean
): LayerToggleState {
  const next: Partial<LayerToggleState> = {};
  for (const layer of Object.keys(state) as LayerId[]) {
    next[layer] = enabled;
  }
  return next as LayerToggleState;
}

function parseDeepLink(url: string): SearchQuery | null {
  const parsed = new URL(url, "https://explorer.local");
  const coord = parsed.searchParams.get("coord");
  const owner = parsed.searchParams.get("owner");
  const adventurer = parsed.searchParams.get("adventurer");

  if (coord) {
    return { coord };
  }

  if (owner) {
    return { owner };
  }

  if (adventurer) {
    return { adventurer };
  }

  return null;
}

function buildDeepLink(
  basePath: string,
  query: SearchQuery,
  selectedHex: HexCoordinate | null
): string {
  const params = new URLSearchParams();
  if (query.coord) {
    params.set("coord", query.coord);
  } else if (query.owner) {
    params.set("owner", query.owner);
  } else if (query.adventurer) {
    params.set("adventurer", query.adventurer);
  } else if (selectedHex) {
    params.set("coord", selectedHex);
  }

  const serialized = params.toString();
  return serialized.length > 0 ? `${basePath}?${serialized}` : basePath;
}

function patchTouchesHex(
  patch: StreamPatchEnvelope,
  hexCoordinate: HexCoordinate
): boolean {
  if (patch.kind === "chunk_snapshot") {
    const snapshot = patch.payload as Partial<ChunkSnapshot>;
    if (!Array.isArray(snapshot.hexes)) {
      return false;
    }

    return snapshot.hexes.some((hex) => {
      return (
        typeof hex?.hexCoordinate === "string" &&
        normalizeCoordinate(hex.hexCoordinate) === normalizeCoordinate(hexCoordinate)
      );
    });
  }

  if (patch.kind === "hex_patch") {
    const payload = patch.payload as {
      hex?: { hexCoordinate?: unknown };
      row?: { hexCoordinate?: unknown };
    };
    const candidate = payload.hex?.hexCoordinate ?? payload.row?.hexCoordinate;
    return (
      typeof candidate === "string" &&
      normalizeCoordinate(candidate as HexCoordinate) === normalizeCoordinate(hexCoordinate)
    );
  }

  return false;
}

function normalizeCoordinate(value: HexCoordinate): string {
  return String(value).toLowerCase();
}

function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }

  if (value > max) {
    return max;
  }

  return value;
}
