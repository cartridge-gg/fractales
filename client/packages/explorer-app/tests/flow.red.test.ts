import { describe, expect, it } from "vitest";
import type {
  ExplorerDataStore,
  ExplorerProxyClient,
  ExplorerSelectors,
  PatchStreamHandlers
} from "@gen-dungeon/explorer-data";
import type { ExplorerRenderer, RendererHandlers } from "@gen-dungeon/explorer-renderer-webgl";
import type {
  ChunkSnapshot,
  HexInspectPayload,
  LayerToggleState,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope,
  StreamStatus
} from "@gen-dungeon/explorer-types";
import { createExplorerApp, type ExplorerUiBindings } from "../src/index.js";

function chunk(
  key: `${number}:${number}`,
  hexes: ChunkSnapshot["hexes"]
): ChunkSnapshot {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ: qRaw ?? 0,
      chunkR: rRaw ?? 0
    },
    headBlock: 100,
    hexes
  };
}

function inspectPayload(hexCoordinate: string): HexInspectPayload {
  return {
    schemaVersion: "explorer-v1",
    headBlock: 100,
    hex: {
      coordinate: hexCoordinate,
      biome: {} as never,
      is_discovered: true,
      discovery_block: 100,
      discoverer: "0x1",
      area_count: 1
    },
    areas: [],
    ownership: [],
    decayState: null,
    activeClaims: [],
    plants: [],
    activeReservations: [],
    adventurers: [],
    adventurerEconomics: [],
    inventories: [],
    backpackItems: [],
    buildings: [],
    constructionProjects: [],
    constructionEscrows: [],
    deathRecords: [],
    eventTail: []
  };
}

function layerFilteredHexes(
  chunks: ChunkSnapshot[],
  layers: LayerToggleState
): ChunkSnapshot["hexes"] {
  const all = chunks.flatMap((entry) => entry.hexes);
  if (layers.biome) {
    return all;
  }

  return all.filter((hex) => {
    return (
      (layers.ownership && hex.ownerAdventurerId !== null) ||
      (layers.claims && (hex.activeClaimCount > 0 || hex.isClaimable)) ||
      (layers.adventurers && hex.adventurerCount > 0) ||
      (layers.resources && hex.plantCount > 0) ||
      (layers.decay && hex.decayLevel > 0)
    );
  });
}

class FakeStore implements ExplorerDataStore {
  private chunks: ChunkSnapshot[] = [];
  private selectedHex: string | null = null;
  private patches: StreamPatchEnvelope[] = [];
  private lastSequence = 0;

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.chunks = chunks;
  }

  applyPatch(patch: StreamPatchEnvelope): void {
    if (patch.sequence <= this.lastSequence) {
      return;
    }
    this.lastSequence = patch.sequence;
    this.patches.push(patch);
    this.chunks = applyPatchToChunks(this.chunks, patch);
  }

  evictChunk(key: `${number}:${number}`): void {
    this.chunks = this.chunks.filter((chunk) => chunk.chunk.key !== key);
  }

  setSelectedHex(hex: string | null): void {
    this.selectedHex = hex;
  }

  snapshot() {
    return {
      status: "live" as const,
      headBlock: this.chunks.reduce((max, entry) => Math.max(max, entry.headBlock), 0),
      selectedHex: this.selectedHex,
      loadedChunks: this.chunks
    };
  }
}

class FakeRenderer implements ExplorerRenderer {
  handlers: RendererHandlers = {};
  layerStates: LayerToggleState[] = [];
  replacedChunks: ChunkSnapshot[][] = [];
  appliedPatches: StreamPatchEnvelope[] = [];
  selectedHexes: (string | null)[] = [];
  resizeCalls: Array<{ width: number; height: number; dpr: number }> = [];
  disposedCount = 0;

  setHandlers(handlers: RendererHandlers): void {
    this.handlers = handlers;
  }

  setLayerState(layerState: LayerToggleState): void {
    this.layerStates.push(layerState);
  }

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.replacedChunks.push(chunks);
  }

  applyPatch(patch: StreamPatchEnvelope): void {
    this.appliedPatches.push(patch);
  }

  setSelectedHex(hexCoordinate: string | null): void {
    this.selectedHexes.push(hexCoordinate);
  }

  resize(width: number, height: number, dpr: number = 1): void {
    this.resizeCalls.push({ width, height, dpr });
  }

  renderFrame(_nowMs: number): void {}

  dispose(): void {
    this.disposedCount += 1;
  }

  emitSelect(hexCoordinate: string): void {
    this.handlers.onSelectHex?.(hexCoordinate);
  }
}

class FakeProxyClient implements ExplorerProxyClient {
  private handlers: PatchStreamHandlers | null = null;
  readonly chunkCalls: string[][] = [];
  readonly inspectCalls: string[] = [];
  readonly searchCalls: SearchQuery[] = [];

  constructor(
    private readonly chunksByKey: Record<string, ChunkSnapshot>,
    private readonly searchByMode: Record<string, SearchResult[]>
  ) {}

  async getChunks(keys: `${number}:${number}`[]): Promise<ChunkSnapshot[]> {
    this.chunkCalls.push([...keys]);
    return keys.flatMap((key) => {
      const chunk = this.chunksByKey[key];
      return chunk ? [chunk] : [];
    });
  }

  async getHexInspect(hexCoordinate: string): Promise<HexInspectPayload> {
    this.inspectCalls.push(hexCoordinate);
    return inspectPayload(hexCoordinate);
  }

  async search(query: SearchQuery): Promise<SearchResult[]> {
    this.searchCalls.push(query);
    const key = query.coord
      ? `coord:${query.coord}`
      : query.owner
        ? `owner:${query.owner}`
        : query.adventurer
          ? `adventurer:${query.adventurer}`
          : "none";
    return this.searchByMode[key] ?? [];
  }

  async getEventTail(): Promise<never[]> {
    return [];
  }

  subscribePatches(handlers: PatchStreamHandlers) {
    this.handlers = handlers;
    return {
      close: () => {
        this.handlers = null;
      }
    };
  }

  emitStatus(status: StreamStatus): void {
    this.handlers?.onStatus(status);
  }

  emitPatch(patch: StreamPatchEnvelope): void {
    this.handlers?.onPatch(patch);
  }
}

class FakeUi implements ExplorerUiBindings {
  statuses: StreamStatus[] = [];
  layerStates: LayerToggleState[] = [];
  selectedHexes: (string | null)[] = [];
  searchResults: ReadonlyArray<{ hexCoordinate: string; label: string }>[] = [];
  inspectPayloads: Array<HexInspectPayload | null> = [];

  setConnectionStatus(status: StreamStatus): void {
    this.statuses.push(status);
  }

  setLayerState(state: LayerToggleState): void {
    this.layerStates.push(state);
  }

  setSelectedHex(hexCoordinate: string | null): void {
    this.selectedHexes.push(hexCoordinate);
  }

  setSearchResults(results: readonly { hexCoordinate: string; label: string }[]): void {
    this.searchResults.push(results);
  }

  setInspectPayload(payload: HexInspectPayload | null): void {
    this.inspectPayloads.push(payload);
  }
}

function applyPatchToChunks(
  chunks: ChunkSnapshot[],
  patch: StreamPatchEnvelope
): ChunkSnapshot[] {
  if (patch.kind === "chunk_snapshot") {
    const payload = patch.payload as ChunkSnapshot;
    if (!payload?.chunk?.key || !Array.isArray(payload.hexes)) {
      return chunks;
    }
    return upsertChunk(chunks, payload);
  }

  if (patch.kind === "hex_patch") {
    const payload = patch.payload as {
      chunkKey?: `${number}:${number}`;
      hex?: ChunkSnapshot["hexes"][number];
    };
    if (!payload.chunkKey || !payload.hex) {
      return chunks;
    }

    const index = chunks.findIndex((chunk) => chunk.chunk.key === payload.chunkKey);
    const base =
      index === -1
        ? chunk(payload.chunkKey, [])
        : chunks[index] ?? chunk(payload.chunkKey, []);
    const hexes = [...base.hexes];
    const hexIndex = hexes.findIndex((hex) => hex.hexCoordinate === payload.hex?.hexCoordinate);
    if (hexIndex === -1) {
      hexes.push(payload.hex);
    } else {
      hexes[hexIndex] = payload.hex;
    }
    const updated: ChunkSnapshot = {
      ...base,
      headBlock: Math.max(base.headBlock, patch.blockNumber),
      hexes
    };
    return upsertChunk(chunks, updated);
  }

  return chunks;
}

function upsertChunk(
  chunks: ChunkSnapshot[],
  updated: ChunkSnapshot
): ChunkSnapshot[] {
  const next = [...chunks];
  const index = next.findIndex((chunk) => chunk.chunk.key === updated.chunk.key);
  if (index === -1) {
    next.push(updated);
  } else {
    next[index] = updated;
  }
  return next.sort((left, right) => left.chunk.key.localeCompare(right.chunk.key));
}

function createHarness() {
  const chunksByKey: Record<string, ChunkSnapshot> = {
    "0:0": chunk("0:0", [
      {
        hexCoordinate: "0x10",
        biome: "Plains",
        ownerAdventurerId: null,
        decayLevel: 0,
        isClaimable: false,
        activeClaimCount: 0,
        adventurerCount: 0,
        plantCount: 0
      },
      {
        hexCoordinate: "0x11",
        biome: "Forest",
        ownerAdventurerId: "0x1",
        decayLevel: 5,
        isClaimable: false,
        activeClaimCount: 1,
        adventurerCount: 2,
        plantCount: 1
      }
    ]),
    "1:0": chunk("1:0", [
      {
        hexCoordinate: "0x20",
        biome: "Desert",
        ownerAdventurerId: null,
        decayLevel: 2,
        isClaimable: true,
        activeClaimCount: 0,
        adventurerCount: 0,
        plantCount: 0
      }
    ])
  };
  const proxy = new FakeProxyClient(chunksByKey, {
    "coord:0xcoord": [{ hexCoordinate: "0x10", score: 1, reason: "coord" }],
    "owner:0xowner": [{ hexCoordinate: "0x11", score: 2, reason: "owner" }],
    "adventurer:0xadv": [{ hexCoordinate: "0x20", score: 3, reason: "adventurer" }]
  });
  const store = new FakeStore();
  const renderer = new FakeRenderer();
  const ui = new FakeUi();
  const selectors: ExplorerSelectors = {
    visibleChunkKeys(viewport) {
      return viewport.center.x >= 10 ? ["1:0"] : ["0:0"];
    },
    visibleHexes(_viewport, layers) {
      return layerFilteredHexes(store.snapshot().loadedChunks, layers);
    }
  };

  const app = createExplorerApp(
    {
      proxyClient: proxy,
      store,
      selectors,
      renderer
    },
    { ui, routeBasePath: "/explorer" }
  );

  return { app, proxy, renderer, ui };
}

describe("explorer app flows (RED)", () => {
  it("flow.default_load_shows_discovered_hexes_only.red", async () => {
    const { app, proxy, renderer } = createHarness();
    await app.mount();

    expect(proxy.chunkCalls[0]).toEqual(["0:0"]);
    const initialChunks = renderer.replacedChunks[0];
    expect(initialChunks?.[0]?.hexes.map((hex) => hex.hexCoordinate)).toEqual(["0x10", "0x11"]);
    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toEqual(["0x10", "0x11"]);
  });

  it("flow.pan_zoom_and_select_hex_updates_inspect.red", async () => {
    const { app, proxy, renderer, ui } = createHarness();
    await app.mount();

    await app.panBy(12, 0);
    await app.zoomTo(2);
    renderer.emitSelect("0x20");
    await Promise.resolve();

    expect(proxy.chunkCalls.some((keys) => keys[0] === "1:0")).toBe(true);
    expect(proxy.inspectCalls).toContain("0x20");
    expect(ui.selectedHexes).toContain("0x20");
    expect(ui.inspectPayloads.at(-1)?.hex.coordinate).toBe("0x20");
  });

  it("flow.pan_updates_visible_window.red", async () => {
    const { app } = createHarness();
    await app.mount();
    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toEqual(["0x10", "0x11"]);

    await app.panBy(12, 0);
    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toEqual(["0x20"]);
  });

  it("flow.toggle_all_layers_and_render_deltas.red", async () => {
    const { app } = createHarness();
    await app.mount();

    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toEqual(["0x10", "0x11"]);

    app.setAllLayers(false);
    expect(app.snapshot().visibleHexes).toEqual([]);

    app.setLayerToggle("claims", true);
    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toEqual(["0x11"]);
  });

  it("flow.search_jump_by_coord_owner_adventurer.red", async () => {
    const { app, proxy, ui } = createHarness();
    await app.mount();

    await app.jumpTo({ coord: "0xcoord" });
    await app.jumpTo({ owner: "0xowner" });
    await app.jumpTo({ adventurer: "0xadv" });

    expect(proxy.searchCalls).toEqual([
      { coord: "0xcoord", limit: undefined },
      { owner: "0xowner", limit: undefined },
      { adventurer: "0xadv", limit: undefined }
    ]);
    expect(ui.searchResults).toHaveLength(3);
    expect(app.snapshot().selectedHex).toBe("0x20");
    expect(app.currentUrl()).toContain("adventurer=0xadv");
  });

  it("flow.ws_disconnect_reconnect_without_reload.red", async () => {
    const { app, proxy, renderer, ui } = createHarness();
    await app.mount();
    const initialLoads = proxy.chunkCalls.length;

    await app.updateStreamStatus("degraded");
    await app.updateStreamStatus("catching_up");

    expect(proxy.chunkCalls.length).toBeGreaterThan(initialLoads);
    expect(ui.statuses).toContain("degraded");
    expect(app.snapshot().status).toBe("live");
    expect(renderer.disposedCount).toBe(0);
  });

  it("flow.patch_updates_visible_hexes_without_full_reload.red", async () => {
    const { app, proxy } = createHarness();
    await app.mount();
    const initialLoads = proxy.chunkCalls.length;

    proxy.emitPatch({
      schemaVersion: "explorer-v1",
      sequence: 1,
      blockNumber: 111,
      txIndex: 0,
      eventIndex: 0,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: {
          hexCoordinate: "0x30",
          biome: "Plains",
          ownerAdventurerId: null,
          decayLevel: 0,
          isClaimable: false,
          activeClaimCount: 0,
          adventurerCount: 0,
          plantCount: 0
        }
      },
      emittedAtMs: 111
    });
    await Promise.resolve();

    expect(app.snapshot().visibleHexes.map((hex) => hex.hexCoordinate)).toContain("0x30");
    expect(proxy.chunkCalls.length).toBe(initialLoads);
  });

  it("flow.deep_link_restore_coord_owner_adventurer.red", async () => {
    const { app, proxy } = createHarness();
    await app.mount();

    await app.hydrateFromUrl("https://example.test/explorer?coord=0x20");
    expect(app.snapshot().selectedHex).toBe("0x20");
    expect(proxy.inspectCalls).toContain("0x20");

    await app.hydrateFromUrl("https://example.test/explorer?owner=0xowner");
    await app.hydrateFromUrl("https://example.test/explorer?adventurer=0xadv");

    expect(proxy.searchCalls).toEqual([
      { owner: "0xowner", limit: undefined },
      { adventurer: "0xadv", limit: undefined }
    ]);
    expect(app.currentUrl()).toContain("adventurer=0xadv");
  });

  it("flow.mobile_viewport_controls_operate.red", async () => {
    const { app, renderer } = createHarness();
    await app.mount();

    await app.resize(390, 844, 2);
    const before = app.snapshot().viewport;
    await app.applyMobilePan(5, -3);
    await app.applyMobilePinch(1.25);
    await app.applyMobileTap("0x11");

    const after = app.snapshot();
    expect(after.layout).toBe("mobile");
    expect(after.viewport.center.x).toBe(before.center.x + 5);
    expect(after.viewport.center.y).toBe(before.center.y - 3);
    expect(after.viewport.zoom).toBeGreaterThan(before.zoom);
    expect(after.selectedHex).toBe("0x11");
    expect(renderer.resizeCalls).toContainEqual({ width: 390, height: 844, dpr: 2 });
  });
});
