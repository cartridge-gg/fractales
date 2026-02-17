import type {
  ExplorerDataStore,
  ExplorerProxyClient,
  ExplorerSelectors,
  PatchStreamHandlers
} from "@gen-dungeon/explorer-data";
import type { ExplorerRenderer, RendererHandlers } from "@gen-dungeon/explorer-renderer-webgl";
import type {
  ChunkKey,
  ChunkSnapshot,
  EventTailQuery,
  EventTailRow,
  HexCoordinate,
  HexInspectPayload,
  LayerToggleState,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope
} from "@gen-dungeon/explorer-types";
import type { ExplorerAppDependencies } from "./contracts.js";
import {
  buildHexPolygonVertices,
  expandHexWindowCoordinates,
  isPointInHexPolygon,
  layoutHexCoordinates
} from "./hex-layout.js";

export interface DevRuntimeBundle {
  dependencies: ExplorerAppDependencies;
  renderer: CanvasMockRenderer;
  proxy: MockProxyClient;
}

interface HexSearchMeta {
  owner: HexCoordinate | null;
  adventurer: HexCoordinate | null;
}

const BIOMES = [
  "Plains",
  "Forest",
  "Desert",
  "Swamp",
  "Taiga",
  "Highlands",
  "Coast"
];

export function createDevRuntime(canvas: HTMLCanvasElement): DevRuntimeBundle {
  const fixtures = createFixtureChunks();
  const chunkByKey = new Map<ChunkKey, ChunkSnapshot>(
    fixtures.chunks.map((chunk) => [chunk.chunk.key, chunk])
  );

  const store = new InMemoryStore();
  const proxy = new MockProxyClient(chunkByKey, fixtures.searchMeta);
  const renderer = new CanvasMockRenderer(canvas);

  const selectors: ExplorerSelectors = {
    visibleChunkKeys(viewport) {
      const centerQ = Math.round(viewport.center.x);
      const centerR = Math.round(viewport.center.y);
      const keys = Array.from(chunkByKey.keys())
        .filter((key) => {
          const [q, r] = parseChunkKey(key);
          return Math.abs(q - centerQ) <= 1 && Math.abs(r - centerR) <= 1;
        })
        .sort(compareChunkKeys);

      if (keys.length > 0) {
        return keys;
      }

      const nearest = Array.from(chunkByKey.keys())
        .sort((a, b) => {
          const [aq, ar] = parseChunkKey(a);
          const [bq, br] = parseChunkKey(b);
          const ad = Math.abs(aq - centerQ) + Math.abs(ar - centerR);
          const bd = Math.abs(bq - centerQ) + Math.abs(br - centerR);
          if (ad !== bd) {
            return ad - bd;
          }
          return compareChunkKeys(a, b);
        })
        .slice(0, 1);

      return nearest;
    },
    visibleHexes(_viewport, layers) {
      const loaded = store.snapshot().loadedChunks;
      const all = loaded.flatMap((chunk) => chunk.hexes);
      return filterHexesByLayer(all, layers);
    }
  };

  return {
    dependencies: {
      proxyClient: proxy,
      store,
      selectors,
      renderer
    },
    renderer,
    proxy
  };
}

function createFixtureChunks(): {
  chunks: ChunkSnapshot[];
  searchMeta: Map<HexCoordinate, HexSearchMeta>;
} {
  const chunks: ChunkSnapshot[] = [];
  const searchMeta = new Map<HexCoordinate, HexSearchMeta>();
  let hexCounter = 0;

  for (let q = -1; q <= 1; q += 1) {
    for (let r = -1; r <= 1; r += 1) {
      const key = `${q}:${r}` as ChunkKey;
      const hexes: ChunkSnapshot["hexes"] = [];
      for (let index = 0; index < 4; index += 1) {
        hexCounter += 1;
        const hexCoordinate = `0x${(512 + hexCounter).toString(16)}`;
        const owner = index % 3 === 0 ? (`0xowner${Math.abs(q + r + index) % 2}` as HexCoordinate) : null;
        const adventurer =
          index % 2 === 1 ? (`0xadv${Math.abs(q + r + index) % 2}` as HexCoordinate) : null;
        const activeClaimCount = index === 1 ? 1 : 0;
        const isClaimable = index === 2;

        hexes.push({
          hexCoordinate,
          biome: BIOMES[(Math.abs(q * 3 + r + index) % BIOMES.length)] ?? "Plains",
          ownerAdventurerId: owner,
          decayLevel: Math.max(0, index * 15 - (q + r) * 3),
          isClaimable,
          activeClaimCount,
          adventurerCount: adventurer ? 1 + (index % 2) : 0,
          plantCount: index % 3
        });
        searchMeta.set(hexCoordinate, {
          owner,
          adventurer
        });
      }

      chunks.push({
        schemaVersion: "explorer-v1",
        chunk: {
          key,
          chunkQ: q,
          chunkR: r
        },
        headBlock: 100 + q * 5 + r * 3,
        hexes
      });
    }
  }

  return {
    chunks,
    searchMeta
  };
}

function filterHexesByLayer(
  hexes: ChunkSnapshot["hexes"],
  layers: LayerToggleState
): ChunkSnapshot["hexes"] {
  if (layers.biome) {
    return hexes;
  }

  return hexes.filter((hex) => {
    return (
      (layers.ownership && hex.ownerAdventurerId !== null) ||
      (layers.claims && (hex.activeClaimCount > 0 || hex.isClaimable)) ||
      (layers.adventurers && hex.adventurerCount > 0) ||
      (layers.resources && hex.plantCount > 0) ||
      (layers.decay && hex.decayLevel > 0)
    );
  });
}

class InMemoryStore implements ExplorerDataStore {
  private chunks: ChunkSnapshot[] = [];
  private selectedHex: HexCoordinate | null = null;

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.chunks = chunks;
  }

  applyPatch(_patch: StreamPatchEnvelope): void {}

  evictChunk(key: ChunkKey): void {
    this.chunks = this.chunks.filter((chunk) => chunk.chunk.key !== key);
  }

  setSelectedHex(hex: HexCoordinate | null): void {
    this.selectedHex = hex;
  }

  snapshot() {
    return {
      status: "live" as const,
      headBlock: this.chunks.reduce((max, chunk) => Math.max(max, chunk.headBlock), 0),
      selectedHex: this.selectedHex,
      loadedChunks: this.chunks
    };
  }
}

export class MockProxyClient implements ExplorerProxyClient {
  private sequence = 0;

  constructor(
    private readonly chunkByKey: Map<ChunkKey, ChunkSnapshot>,
    private readonly searchMeta: Map<HexCoordinate, HexSearchMeta>
  ) {}

  async getChunks(keys: ChunkKey[]): Promise<ChunkSnapshot[]> {
    return keys.flatMap((key) => {
      const chunk = this.chunkByKey.get(key);
      return chunk ? [chunk] : [];
    });
  }

  async getHexInspect(hexCoordinate: HexCoordinate): Promise<HexInspectPayload> {
    const row = findHex(this.chunkByKey, hexCoordinate);
    const now = Date.now();
    const eventTail: EventTailRow[] = [
      {
        blockNumber: 1000,
        txIndex: 0,
        eventIndex: 0,
        eventName: "HexInspected",
        payloadJson: JSON.stringify({ hexCoordinate, at: now })
      }
    ];

    return {
      schemaVersion: "explorer-v1",
      headBlock: 1000,
      hex: {
        coordinate: hexCoordinate,
        biome: {} as never,
        is_discovered: true,
        discovery_block: 100,
        discoverer: "0xdev",
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
      eventTail: row ? eventTail : []
    };
  }

  async search(query: SearchQuery): Promise<SearchResult[]> {
    if (query.coord) {
      return this.searchMeta.has(query.coord)
        ? [{ hexCoordinate: query.coord, score: 100, reason: "coord" }]
        : [];
    }

    if (query.owner) {
      return Array.from(this.searchMeta.entries())
        .filter(([, meta]) => meta.owner === query.owner)
        .slice(0, query.limit ?? 20)
        .map(([hexCoordinate], index) => ({
          hexCoordinate,
          score: 100 - index,
          reason: "owner" as const
        }));
    }

    if (query.adventurer) {
      return Array.from(this.searchMeta.entries())
        .filter(([, meta]) => meta.adventurer === query.adventurer)
        .slice(0, query.limit ?? 20)
        .map(([hexCoordinate], index) => ({
          hexCoordinate,
          score: 100 - index,
          reason: "adventurer" as const
        }));
    }

    return [];
  }

  async getEventTail(_query: EventTailQuery): Promise<EventTailRow[]> {
    return [];
  }

  subscribePatches(handlers: PatchStreamHandlers) {
    handlers.onStatus("live");
    const interval = window.setInterval(() => {
      this.sequence += 1;
      const patch: StreamPatchEnvelope = {
        schemaVersion: "explorer-v1",
        sequence: this.sequence,
        blockNumber: 1500 + this.sequence,
        txIndex: 0,
        eventIndex: 0,
        kind: "heartbeat",
        payload: {
          source: "dev-runtime"
        },
        emittedAtMs: Date.now()
      };
      handlers.onPatch(patch);
    }, 2500);

    return {
      close: () => {
        window.clearInterval(interval);
      }
    };
  }
}

interface HexLayoutEntry {
  hexCoordinate: HexCoordinate;
  x: number;
  y: number;
  radius: number;
  vertices: Array<{ x: number; y: number }>;
  fill: string;
  label: string;
  isDiscovered: boolean;
}

export class CanvasMockRenderer implements ExplorerRenderer {
  private handlers: RendererHandlers = {};
  private layerState: LayerToggleState = {
    biome: true,
    ownership: false,
    claims: false,
    adventurers: false,
    resources: false,
    decay: false
  };
  private chunks: ChunkSnapshot[] = [];
  private selectedHex: HexCoordinate | null = null;
  private cssWidth = 1280;
  private cssHeight = 720;
  private dpr = 1;
  private layout: HexLayoutEntry[] = [];
  private knownDiscoveredHexes = new Map<string, ChunkSnapshot["hexes"][number]>();

  constructor(private readonly canvas: HTMLCanvasElement) {
    this.onPointerDown = this.onPointerDown.bind(this);
    this.canvas.addEventListener("pointerdown", this.onPointerDown);
  }

  setHandlers(handlers: RendererHandlers): void {
    this.handlers = handlers;
  }

  setLayerState(layerState: LayerToggleState): void {
    this.layerState = layerState;
  }

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.chunks = chunks;
    for (const chunk of chunks) {
      for (const hex of chunk.hexes) {
        this.knownDiscoveredHexes.set(normalizeHexCoordinate(hex.hexCoordinate), hex);
      }
    }
    this.layout = buildLayout(
      chunks,
      this.cssWidth,
      this.cssHeight,
      this.layerState,
      this.knownDiscoveredHexes
    );
  }

  applyPatch(_patch: StreamPatchEnvelope): void {}

  setSelectedHex(hexCoordinate: HexCoordinate | null): void {
    this.selectedHex = hexCoordinate;
  }

  resize(width: number, height: number, dpr: number = window.devicePixelRatio || 1): void {
    this.cssWidth = Math.max(320, Math.floor(width));
    this.cssHeight = Math.max(240, Math.floor(height));
    this.dpr = Math.max(1, dpr);
    this.canvas.style.width = `${this.cssWidth}px`;
    this.canvas.style.height = `${this.cssHeight}px`;
    this.canvas.width = Math.floor(this.cssWidth * this.dpr);
    this.canvas.height = Math.floor(this.cssHeight * this.dpr);
    this.layout = buildLayout(
      this.chunks,
      this.cssWidth,
      this.cssHeight,
      this.layerState,
      this.knownDiscoveredHexes
    );
  }

  renderFrame(_nowMs: number): void {
    const context = this.canvas.getContext("2d");
    if (!context) {
      return;
    }

    context.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    context.clearRect(0, 0, this.cssWidth, this.cssHeight);
    paintBackground(context, this.cssWidth, this.cssHeight);

    for (const hex of this.layout) {
      context.beginPath();
      const [firstVertex, ...otherVertices] = hex.vertices;
      if (firstVertex) {
        context.moveTo(firstVertex.x, firstVertex.y);
        for (const vertex of otherVertices) {
          context.lineTo(vertex.x, vertex.y);
        }
        context.closePath();
      } else {
        context.arc(hex.x, hex.y, hex.radius, 0, Math.PI * 2);
      }
      context.fillStyle = hex.fill;
      context.fill();
      const isSelected = hex.isDiscovered && hex.hexCoordinate === this.selectedHex;
      context.lineWidth = isSelected ? 3 : 1.2;
      context.strokeStyle = isSelected ? "#ffe08a" : hex.isDiscovered ? "#284f6b" : "#1a3347";
      context.stroke();

      const labelSize = clampLabelSize(hex.radius);
      context.font = `${labelSize}px 'IBM Plex Mono', ui-monospace, monospace`;
      context.fillStyle = hex.isDiscovered ? "#dce9f7" : "#7f9ab0";
      context.textAlign = "center";
      context.fillText(hex.label, hex.x, hex.y + 4);
    }
  }

  dispose(): void {
    this.canvas.removeEventListener("pointerdown", this.onPointerDown);
  }

  private onPointerDown(event: PointerEvent): void {
    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    const hit = this.layout.find((entry) => {
      if (!entry.isDiscovered) {
        return false;
      }
      if (entry.vertices.length > 0 && isPointInHexPolygon(x, y, entry.vertices)) {
        return true;
      }
      return Math.hypot(entry.x - x, entry.y - y) <= entry.radius;
    });

    if (hit) {
      this.handlers.onSelectHex?.(hit.hexCoordinate);
    }
  }
}

function findHex(
  chunkByKey: Map<ChunkKey, ChunkSnapshot>,
  hexCoordinate: HexCoordinate
): ChunkSnapshot["hexes"][number] | null {
  for (const chunk of chunkByKey.values()) {
    const row = chunk.hexes.find((hex) => hex.hexCoordinate === hexCoordinate);
    if (row) {
      return row;
    }
  }

  return null;
}

function parseChunkKey(key: ChunkKey): [number, number] {
  const [qRaw, rRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return [qRaw ?? 0, rRaw ?? 0];
}

function compareChunkKeys(a: ChunkKey, b: ChunkKey): number {
  const [aq, ar] = parseChunkKey(a);
  const [bq, br] = parseChunkKey(b);
  if (aq !== bq) {
    return aq - bq;
  }
  return ar - br;
}

function buildLayout(
  chunks: ChunkSnapshot[],
  width: number,
  height: number,
  layerState: LayerToggleState,
  knownDiscoveredHexes: ReadonlyMap<string, ChunkSnapshot["hexes"][number]> = new Map()
): HexLayoutEntry[] {
  const orderedChunks = [...chunks].sort((a, b) => compareChunkKeys(a.chunk.key, b.chunk.key));
  const orderedHexes = orderedChunks
    .flatMap((chunk) => chunk.hexes)
    .sort((a, b) => normalizeHexCoordinate(a.hexCoordinate).localeCompare(normalizeHexCoordinate(b.hexCoordinate)));

  const discoveredByCoordinate = new Map(knownDiscoveredHexes);
  for (const hex of orderedHexes) {
    discoveredByCoordinate.set(normalizeHexCoordinate(hex.hexCoordinate), hex);
  }
  const surfaceCoordinates = expandHexWindowCoordinates(
    orderedHexes.map((hex) => hex.hexCoordinate),
    4
  );
  const geometry = layoutHexCoordinates(
    surfaceCoordinates,
    width,
    height,
    {
      padding: 42,
      minRadius: 14,
      maxRadius: 40
    }
  );

  if (geometry.length === 0) {
    return buildLegacyLayout(orderedChunks, width, height, layerState);
  }

  return geometry
    .map((resolved) => {
      const discovered = discoveredByCoordinate.get(normalizeHexCoordinate(resolved.hexCoordinate)) ?? null;
      return {
        hexCoordinate: resolved.hexCoordinate,
        x: resolved.x,
        y: resolved.y,
        radius: resolved.radius,
        vertices: resolved.vertices,
        fill: discovered ? hexFillForLayer(discovered, layerState) : "#0d1f30",
        label: formatCubeLabel(resolved.cube),
        isDiscovered: discovered !== null
      };
    })
    .sort((left, right) => {
      if (left.isDiscovered !== right.isDiscovered) {
        return Number(left.isDiscovered) - Number(right.isDiscovered);
      }
      if (left.y !== right.y) {
        return left.y - right.y;
      }
      return left.x - right.x;
    });
}

function buildLegacyLayout(
  orderedChunks: ChunkSnapshot[],
  width: number,
  height: number,
  layerState: LayerToggleState
): HexLayoutEntry[] {
  const entries: HexLayoutEntry[] = [];
  const baseX = width / 2;
  const baseY = height / 2;
  const chunkSpacing = Math.min(230, Math.max(160, width / 4));

  for (const chunk of orderedChunks) {
    const chunkX = baseX + chunk.chunk.chunkQ * chunkSpacing + chunk.chunk.chunkR * (chunkSpacing * 0.48);
    const chunkY = baseY + chunk.chunk.chunkR * (chunkSpacing * 0.78);
    const sortedHexes = [...chunk.hexes].sort((a, b) =>
      a.hexCoordinate.localeCompare(b.hexCoordinate)
    );

    for (let index = 0; index < sortedHexes.length; index += 1) {
      const hex = sortedHexes[index];
      if (!hex) {
        continue;
      }

      const angle = (index / Math.max(1, sortedHexes.length)) * Math.PI * 2;
      const radius = 36;
      const x = chunkX + Math.cos(angle) * 54;
      const y = chunkY + Math.sin(angle) * 42;
      entries.push({
        hexCoordinate: hex.hexCoordinate,
        x,
        y,
        radius,
        vertices: buildHexPolygonVertices(x, y, radius),
        fill: hexFillForLayer(hex, layerState),
        label: hex.hexCoordinate.slice(-3).toUpperCase(),
        isDiscovered: true
      });
    }
  }

  return entries;
}

function normalizeHexCoordinate(hexCoordinate: HexCoordinate): string {
  return String(hexCoordinate).toLowerCase();
}

function hexFillForLayer(
  hex: ChunkSnapshot["hexes"][number],
  layerState: LayerToggleState
): string {
  if (layerState.claims) {
    if (hex.activeClaimCount > 0) {
      return "#b14644";
    }
    if (hex.isClaimable) {
      return "#d48f4e";
    }
    return "#4b5e73";
  }

  if (layerState.ownership) {
    return hex.ownerAdventurerId ? "#5483b3" : "#445a70";
  }

  if (layerState.adventurers) {
    return hex.adventurerCount > 0 ? "#6dad68" : "#435d45";
  }

  if (layerState.resources) {
    return hex.plantCount > 0 ? "#6d8c60" : "#455844";
  }

  if (layerState.decay) {
    return hex.decayLevel > 0 ? "#8c6d59" : "#505056";
  }

  return biomeColor(hex.biome);
}

function biomeColor(biome: string): string {
  switch (biome) {
    case "Plains":
      return "#577c93";
    case "Forest":
      return "#4f7d64";
    case "Desert":
      return "#9b8459";
    case "Swamp":
      return "#637267";
    case "Taiga":
      return "#64808a";
    case "Highlands":
      return "#7d6f8e";
    case "Coast":
      return "#5f86a6";
    default:
      return "#50667b";
  }
}

function paintBackground(
  context: CanvasRenderingContext2D,
  width: number,
  height: number
): void {
  const gradient = context.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "#081523");
  gradient.addColorStop(1, "#0a1b2d");
  context.fillStyle = gradient;
  context.fillRect(0, 0, width, height);

  const glow = context.createRadialGradient(width * 0.48, height * 0.44, 50, width * 0.48, height * 0.44, width);
  glow.addColorStop(0, "rgba(42, 88, 126, 0.16)");
  glow.addColorStop(1, "rgba(42, 88, 126, 0)");
  context.fillStyle = glow;
  context.fillRect(0, 0, width, height);
}

function formatCubeLabel(cube: { x: number; z: number }): string {
  return `${cube.x},${cube.z}`;
}

function clampLabelSize(radius: number): number {
  if (!Number.isFinite(radius)) {
    return 10;
  }
  if (radius < 16) {
    return 7;
  }
  if (radius > 36) {
    return 11;
  }
  return Math.floor(radius * 0.3);
}
