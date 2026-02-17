import {
  applyIncomingPatchMetadata,
  applyStreamPatch,
  createPatchReducerState,
  createStreamState,
  ExplorerDataStore,
  ExplorerProxyClient,
  ExplorerSelectors,
  PatchStreamHandlers
} from "@gen-dungeon/explorer-data";
import type { ExplorerRenderer } from "@gen-dungeon/explorer-renderer-webgl";
import type {
  Adventurer,
  AdventurerEconomics,
  AreaOwnership,
  BackpackItem,
  ChunkKey,
  ChunkSnapshot,
  ClaimEscrow,
  ConstructionBuildingNode,
  ConstructionMaterialEscrow,
  ConstructionProject,
  DeathRecord,
  EventTailQuery,
  EventTailRow,
  HarvestReservation,
  Hex,
  HexArea,
  HexCoordinate,
  HexInspectPayload,
  HexRenderRow,
  HexDecayState,
  Inventory,
  LayerToggleState,
  MineAccessGrant,
  MineCollapseRecord,
  MineNode,
  MiningShift,
  PlantNode,
  SearchQuery,
  SearchResult,
  StreamPatchEnvelope
} from "@gen-dungeon/explorer-types";
import type { ExplorerAppDependencies } from "./contracts.js";
import { LiveWebglRendererAdapter } from "./live-webgl-renderer.js";

export const DEFAULT_LIVE_TORII_GRAPHQL_URL =
  "https://api.cartridge.gg/x/gen-dungeon-live-20260215a/torii/graphql";
export const DEFAULT_LIVE_PROXY_ORIGIN = "http://127.0.0.1:3001";

const DEFAULT_CACHE_TTL_MS = 2_500;
const DEFAULT_POLL_INTERVAL_MS = 4_000;
const DEFAULT_CHUNK_SIZE = 1;
const DEFAULT_QUERY_LIMIT = 2_000;
const DEFAULT_MAX_PROXY_CHUNK_KEYS = 64;
const VIEWPORT_CHUNK_SPAN_PX = 640;
const PREFETCH_RING_CHUNKS = 1;
const MAX_VIEWPORT_CHUNK_KEYS = 49;

const AXIS_OFFSET = 1_048_576n;
const AXIS_MASK = 2_097_151n;
const MAX_PACKED = 9_223_372_036_854_775_807n;
const PACK_X_MULT = 4_398_046_511_104n;
const PACK_Y_MULT = 2_097_152n;
const PACK_RANGE = 2_097_152n;

const SNAPSHOT_QUERY = `
query LiveSnapshot($hexLimit: Int!, $modelLimit: Int!) {
  dojoStarterHexModels(limit: $hexLimit) {
    edges {
      node {
        coordinate
        biome
        is_discovered
        discovery_block
        discoverer
        area_count
      }
    }
  }
  dojoStarterHexAreaModels(limit: $modelLimit) {
    edges {
      node {
        area_id
        hex_coordinate
        area_index
        area_type
        is_discovered
        discoverer
        resource_quality
        size_category
        plant_slot_count
      }
    }
  }
  dojoStarterAreaOwnershipModels(limit: $modelLimit) {
    edges {
      node {
        area_id
        owner_adventurer_id
        discoverer_adventurer_id
        discovery_block
        claim_block
      }
    }
  }
  dojoStarterHexDecayStateModels(limit: $modelLimit) {
    edges {
      node {
        hex_coordinate
        owner_adventurer_id
        current_energy_reserve
        last_energy_payment_block
        last_decay_processed_block
        decay_level
        claimable_since_block
      }
    }
  }
  dojoStarterClaimEscrowModels(limit: $modelLimit) {
    edges {
      node {
        claim_id
        hex_coordinate
        claimant_adventurer_id
        energy_locked
        created_block
        expiry_block
        status
      }
    }
  }
  dojoStarterPlantNodeModels(limit: $modelLimit) {
    edges {
      node {
        plant_key
        hex_coordinate
        area_id
        plant_id
        species
        current_yield
        reserved_yield
        max_yield
        regrowth_rate
        health
        stress_level
        genetics_hash
        last_harvest_block
        discoverer
      }
    }
  }
  dojoStarterHarvestReservationModels(limit: $modelLimit) {
    edges {
      node {
        reservation_id
        adventurer_id
        plant_key
        reserved_amount
        created_block
        expiry_block
        status
      }
    }
  }
  dojoStarterAdventurerModels(limit: $modelLimit) {
    edges {
      node {
        adventurer_id
        owner
        name
        energy
        max_energy
        current_hex
        activity_locked_until
        is_alive
      }
    }
  }
  dojoStarterAdventurerEconomicsModels(limit: $modelLimit) {
    edges {
      node {
        adventurer_id
        energy_balance
        total_energy_spent
        total_energy_earned
        last_regen_block
      }
    }
  }
  dojoStarterInventoryModels(limit: $modelLimit) {
    edges {
      node {
        adventurer_id
        current_weight
        max_weight
      }
    }
  }
  dojoStarterBackpackItemModels(limit: $modelLimit) {
    edges {
      node {
        adventurer_id
        item_id
        quantity
        quality
        weight_per_unit
      }
    }
  }
  dojoStarterDeathRecordModels(limit: $modelLimit) {
    edges {
      node {
        adventurer_id
        owner
        death_block
        death_cause
        inventory_lost_hash
      }
    }
  }
  dojoStarterConstructionBuildingNodeModels(limit: $modelLimit) {
    edges {
      node {
        area_id
        hex_coordinate
        owner_adventurer_id
        building_type
        tier
        condition_bp
        upkeep_reserve
        last_upkeep_block
        is_active
      }
    }
  }
  dojoStarterConstructionProjectModels(limit: $modelLimit) {
    edges {
      node {
        project_id
        adventurer_id
        hex_coordinate
        area_id
        building_type
        target_tier
        start_block
        completion_block
        energy_staked
        status
      }
    }
  }
  dojoStarterConstructionMaterialEscrowModels(limit: $modelLimit) {
    edges {
      node {
        project_id
        item_id
        quantity
      }
    }
  }
  dojoStarterMineNodeModels(limit: $modelLimit) {
    edges {
      node {
        mine_key
        hex_coordinate
        area_id
        mine_id
        ore_id
        rarity_tier
        depth_tier
        richness_bp
        remaining_reserve
        base_stress_per_block
        collapse_threshold
        mine_stress
        safe_shift_blocks
        active_miners
        last_update_block
        collapsed_until_block
        repair_energy_needed
        is_depleted
        active_head_shift_id
        active_tail_shift_id
        biome_risk_bp
        rarity_risk_bp
        base_tick_energy
        ore_energy_weight
        conversion_energy_per_unit
      }
    }
  }
  dojoStarterMiningShiftModels(limit: $modelLimit) {
    edges {
      node {
        shift_id
        adventurer_id
        mine_key
        status
        start_block
        last_settle_block
        accrued_ore_unbanked
        accrued_stabilization_work
        prev_active_shift_id
        next_active_shift_id
      }
    }
  }
  dojoStarterMineAccessGrantModels(limit: $modelLimit) {
    edges {
      node {
        mine_key
        grantee_adventurer_id
        is_allowed
        granted_by_adventurer_id
        grant_block
        revoked_block
      }
    }
  }
  dojoStarterMineCollapseRecordModels(limit: $modelLimit) {
    edges {
      node {
        mine_key
        collapse_count
        last_collapse_block
        trigger_stress
        trigger_active_miners
      }
    }
  }
}
`;

export interface LiveRuntimeBundle {
  dependencies: ExplorerAppDependencies;
  renderer: ExplorerRenderer;
  proxy: ExplorerProxyClient;
}

export interface LiveToriiRuntimeOptions {
  proxyOrigin?: string;
  toriiGraphqlUrl?: string;
  cacheTtlMs?: number;
  pollIntervalMs?: number;
  chunkSize?: number;
  queryLimit?: number;
  fetchImpl?: typeof fetch;
  webSocketFactory?: LiveProxyWebSocketFactory;
  maxProxyChunkKeys?: number;
  nowMs?: () => number;
}

interface ProxyChunksResponse {
  schemaVersion: "explorer-v1";
  chunks: ChunkSnapshot[];
}

interface ProxySearchResponse {
  schemaVersion: "explorer-v1";
  results: SearchResult[];
}

interface ProxyStatusResponse {
  schemaVersion: "explorer-v1";
  headBlock: number;
  lastSequence: number;
  streamLagMs: number;
}

interface LiveProxyMessageEvent {
  data: unknown;
}

interface LiveProxyErrorEvent {
  error?: unknown;
  message?: string;
}

interface LiveProxyWebSocket {
  readonly readyState: number;
  addEventListener(type: "open", listener: () => void): void;
  addEventListener(
    type: "message",
    listener: (event: LiveProxyMessageEvent) => void
  ): void;
  addEventListener(type: "close", listener: () => void): void;
  addEventListener(
    type: "error",
    listener: (event: LiveProxyErrorEvent) => void
  ): void;
  removeEventListener(type: "open", listener: () => void): void;
  removeEventListener(
    type: "message",
    listener: (event: LiveProxyMessageEvent) => void
  ): void;
  removeEventListener(type: "close", listener: () => void): void;
  removeEventListener(
    type: "error",
    listener: (event: LiveProxyErrorEvent) => void
  ): void;
  close(code?: number, reason?: string): void;
}

export type LiveProxyWebSocketFactory = (url: string) => LiveProxyWebSocket;

export interface ToriiHexRow {
  coordinate: HexCoordinate;
  biome: string;
  is_discovered: boolean | number | string;
  discovery_block: unknown;
  discoverer: string;
  area_count: unknown;
}

export interface ToriiHexAreaRow {
  area_id: string;
  hex_coordinate: HexCoordinate;
  area_index: unknown;
  area_type: string;
  is_discovered: boolean | number | string;
  discoverer: string;
  resource_quality: unknown;
  size_category: string;
  plant_slot_count: unknown;
}

export interface ToriiAreaOwnershipRow {
  area_id: string;
  owner_adventurer_id: string;
  discoverer_adventurer_id: string;
  discovery_block: unknown;
  claim_block: unknown;
}

export interface ToriiHexDecayRow {
  hex_coordinate: HexCoordinate;
  owner_adventurer_id: string;
  current_energy_reserve: unknown;
  last_energy_payment_block: unknown;
  last_decay_processed_block: unknown;
  decay_level: unknown;
  claimable_since_block: unknown;
}

export interface ToriiClaimEscrowRow {
  claim_id: string;
  hex_coordinate: HexCoordinate;
  claimant_adventurer_id: string;
  energy_locked: unknown;
  created_block: unknown;
  expiry_block: unknown;
  status: unknown;
}

export interface ToriiPlantRow {
  plant_key: string;
  hex_coordinate: HexCoordinate;
  area_id: string;
  plant_id: unknown;
  species: unknown;
  current_yield: unknown;
  reserved_yield: unknown;
  max_yield: unknown;
  regrowth_rate: unknown;
  health: unknown;
  stress_level: unknown;
  genetics_hash: unknown;
  last_harvest_block: unknown;
  discoverer: string;
}

export interface ToriiHarvestReservationRow {
  reservation_id: string;
  adventurer_id: string;
  plant_key: string;
  reserved_amount: unknown;
  created_block: unknown;
  expiry_block: unknown;
  status: unknown;
}

export interface ToriiAdventurerRow {
  adventurer_id: string;
  owner: string;
  name: unknown;
  energy: unknown;
  max_energy: unknown;
  current_hex: HexCoordinate;
  activity_locked_until: unknown;
  is_alive: boolean | number | string;
}

export interface ToriiAdventurerEconomicsRow {
  adventurer_id: string;
  energy_balance: unknown;
  total_energy_spent: unknown;
  total_energy_earned: unknown;
  last_regen_block: unknown;
}

export interface ToriiInventoryRow {
  adventurer_id: string;
  current_weight: unknown;
  max_weight: unknown;
}

export interface ToriiBackpackItemRow {
  adventurer_id: string;
  item_id: unknown;
  quantity: unknown;
  quality: unknown;
  weight_per_unit: unknown;
}

export interface ToriiDeathRecordRow {
  adventurer_id: string;
  owner: string;
  death_block: unknown;
  death_cause: unknown;
  inventory_lost_hash: unknown;
}

export interface ToriiConstructionBuildingRow {
  area_id: string;
  hex_coordinate: HexCoordinate;
  owner_adventurer_id: string;
  building_type: unknown;
  tier: unknown;
  condition_bp: unknown;
  upkeep_reserve: unknown;
  last_upkeep_block: unknown;
  is_active: boolean | number | string;
}

export interface ToriiConstructionProjectRow {
  project_id: string;
  adventurer_id: string;
  hex_coordinate: HexCoordinate;
  area_id: string;
  building_type: unknown;
  target_tier: unknown;
  start_block: unknown;
  completion_block: unknown;
  energy_staked: unknown;
  status: unknown;
}

export interface ToriiConstructionMaterialEscrowRow {
  project_id: string;
  item_id: unknown;
  quantity: unknown;
}

export interface ToriiMineNodeRow {
  mine_key: string;
  hex_coordinate: HexCoordinate;
  area_id: string;
  mine_id: unknown;
  ore_id: unknown;
  rarity_tier: unknown;
  depth_tier: unknown;
  richness_bp: unknown;
  remaining_reserve: unknown;
  base_stress_per_block: unknown;
  collapse_threshold: unknown;
  mine_stress: unknown;
  safe_shift_blocks: unknown;
  active_miners: unknown;
  last_update_block: unknown;
  collapsed_until_block: unknown;
  repair_energy_needed: unknown;
  is_depleted: boolean | number | string;
  active_head_shift_id: unknown;
  active_tail_shift_id: unknown;
  biome_risk_bp: unknown;
  rarity_risk_bp: unknown;
  base_tick_energy: unknown;
  ore_energy_weight: unknown;
  conversion_energy_per_unit: unknown;
}

export interface ToriiMiningShiftRow {
  shift_id: string;
  adventurer_id: string;
  mine_key: string;
  status: unknown;
  start_block: unknown;
  last_settle_block: unknown;
  accrued_ore_unbanked: unknown;
  accrued_stabilization_work: unknown;
  prev_active_shift_id: unknown;
  next_active_shift_id: unknown;
}

export interface ToriiMineAccessGrantRow {
  mine_key: string;
  grantee_adventurer_id: string;
  is_allowed: boolean | number | string;
  granted_by_adventurer_id: string;
  grant_block: unknown;
  revoked_block: unknown;
}

export interface ToriiMineCollapseRecordRow {
  mine_key: string;
  collapse_count: unknown;
  last_collapse_block: unknown;
  trigger_stress: unknown;
  trigger_active_miners: unknown;
}

export interface ToriiSnapshotRows {
  hexes: ToriiHexRow[];
  areas: ToriiHexAreaRow[];
  ownership: ToriiAreaOwnershipRow[];
  decay: ToriiHexDecayRow[];
  claims: ToriiClaimEscrowRow[];
  plants: ToriiPlantRow[];
  reservations: ToriiHarvestReservationRow[];
  adventurers: ToriiAdventurerRow[];
  economics: ToriiAdventurerEconomicsRow[];
  inventories: ToriiInventoryRow[];
  backpackItems: ToriiBackpackItemRow[];
  deathRecords: ToriiDeathRecordRow[];
  buildings: ToriiConstructionBuildingRow[];
  constructionProjects: ToriiConstructionProjectRow[];
  constructionEscrows: ToriiConstructionMaterialEscrowRow[];
  mineNodes: ToriiMineNodeRow[];
  miningShifts: ToriiMiningShiftRow[];
  mineAccessGrants: ToriiMineAccessGrantRow[];
  mineCollapseRecords: ToriiMineCollapseRecordRow[];
}

interface SnapshotBundle extends ToriiSnapshotRows {
  headBlock: number;
}

interface HexPatchUpdate {
  chunkKey: ChunkKey;
  headBlock?: number;
  hex: HexRenderRow;
}

export interface BuildChunkOptions {
  chunkSize?: number;
  headBlock: number;
}

interface GraphqlConnection<TNode> {
  edges?: Array<{ node?: TNode | null } | null> | null;
}

interface SnapshotQueryData {
  dojoStarterHexModels?: GraphqlConnection<ToriiHexRow>;
  dojoStarterHexAreaModels?: GraphqlConnection<ToriiHexAreaRow>;
  dojoStarterAreaOwnershipModels?: GraphqlConnection<ToriiAreaOwnershipRow>;
  dojoStarterHexDecayStateModels?: GraphqlConnection<ToriiHexDecayRow>;
  dojoStarterClaimEscrowModels?: GraphqlConnection<ToriiClaimEscrowRow>;
  dojoStarterPlantNodeModels?: GraphqlConnection<ToriiPlantRow>;
  dojoStarterHarvestReservationModels?: GraphqlConnection<ToriiHarvestReservationRow>;
  dojoStarterAdventurerModels?: GraphqlConnection<ToriiAdventurerRow>;
  dojoStarterAdventurerEconomicsModels?: GraphqlConnection<ToriiAdventurerEconomicsRow>;
  dojoStarterInventoryModels?: GraphqlConnection<ToriiInventoryRow>;
  dojoStarterBackpackItemModels?: GraphqlConnection<ToriiBackpackItemRow>;
  dojoStarterDeathRecordModels?: GraphqlConnection<ToriiDeathRecordRow>;
  dojoStarterConstructionBuildingNodeModels?: GraphqlConnection<ToriiConstructionBuildingRow>;
  dojoStarterConstructionProjectModels?: GraphqlConnection<ToriiConstructionProjectRow>;
  dojoStarterConstructionMaterialEscrowModels?: GraphqlConnection<ToriiConstructionMaterialEscrowRow>;
  dojoStarterMineNodeModels?: GraphqlConnection<ToriiMineNodeRow>;
  dojoStarterMiningShiftModels?: GraphqlConnection<ToriiMiningShiftRow>;
  dojoStarterMineAccessGrantModels?: GraphqlConnection<ToriiMineAccessGrantRow>;
  dojoStarterMineCollapseRecordModels?: GraphqlConnection<ToriiMineCollapseRecordRow>;
}

interface GraphqlResponse<TData> {
  data?: TData;
  errors?: Array<{ message?: string } | null>;
}

export function createLiveToriiRuntime(
  canvas: HTMLCanvasElement,
  options: LiveToriiRuntimeOptions = {}
): LiveRuntimeBundle {
  const chunkSize = Math.max(1, Math.floor(options.chunkSize ?? DEFAULT_CHUNK_SIZE));
  const fetchImpl =
    options.fetchImpl?.bind(globalThis) ?? globalThis.fetch.bind(globalThis);
  const store = new LiveStore();
  const renderer = new LiveWebglRendererAdapter(canvas);
  const proxyClientOptions: {
    proxyOrigin: string;
    fetchImpl: typeof fetch;
    cacheTtlMs: number;
    maxChunkKeys: number;
    webSocketFactory?: LiveProxyWebSocketFactory;
    nowMs?: () => number;
  } = {
    proxyOrigin: options.proxyOrigin ?? DEFAULT_LIVE_PROXY_ORIGIN,
    fetchImpl,
    cacheTtlMs: options.cacheTtlMs ?? DEFAULT_CACHE_TTL_MS,
    maxChunkKeys: options.maxProxyChunkKeys ?? DEFAULT_MAX_PROXY_CHUNK_KEYS
  };
  if (options.webSocketFactory) {
    proxyClientOptions.webSocketFactory = options.webSocketFactory;
  }
  if (options.nowMs) {
    proxyClientOptions.nowMs = options.nowMs;
  }
  const proxy = new LiveProxyHttpClient(proxyClientOptions);
  const selectors = createLiveSelectors(store, chunkSize);

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

export function decodeCubeCoordinate(
  coordinate: HexCoordinate
): { x: number; y: number; z: number } | null {
  let packed: bigint;
  try {
    packed = BigInt(coordinate);
  } catch {
    return null;
  }

  if (packed < 0n || packed > MAX_PACKED) {
    return null;
  }

  const xShifted = packed / PACK_X_MULT;
  const yShifted = (packed / PACK_Y_MULT) % PACK_RANGE;
  const zShifted = packed % PACK_RANGE;

  if (xShifted > AXIS_MASK || yShifted > AXIS_MASK || zShifted > AXIS_MASK) {
    return null;
  }

  const x = Number(xShifted - AXIS_OFFSET);
  const y = Number(yShifted - AXIS_OFFSET);
  const z = Number(zShifted - AXIS_OFFSET);

  if (!Number.isSafeInteger(x) || !Number.isSafeInteger(y) || !Number.isSafeInteger(z)) {
    return null;
  }

  if (x + y + z !== 0) {
    return null;
  }

  return { x, y, z };
}

export function chunkKeyForHexCoordinate(
  coordinate: HexCoordinate,
  chunkSize: number = DEFAULT_CHUNK_SIZE
): ChunkKey | null {
  const decoded = decodeCubeCoordinate(coordinate);
  if (!decoded) {
    return null;
  }

  const safeChunkSize = Math.max(1, Math.floor(chunkSize));
  const chunkQ = floorDiv(decoded.x, safeChunkSize);
  const chunkR = floorDiv(decoded.z, safeChunkSize);

  return `${chunkQ}:${chunkR}` as ChunkKey;
}

export function buildChunkSnapshotsFromToriiRows(
  rows: Pick<
    ToriiSnapshotRows,
    "hexes" | "areas" | "ownership" | "decay" | "claims" | "adventurers" | "plants"
  > &
    Partial<Pick<ToriiSnapshotRows, "reservations">>,
  options: BuildChunkOptions
): ChunkSnapshot[] {
  const chunkSize = Math.max(1, Math.floor(options.chunkSize ?? DEFAULT_CHUNK_SIZE));
  const headBlock = options.headBlock;

  const controlAreaByHex = new Map<HexCoordinate, string>();
  for (const area of rows.areas) {
    if (!isTrueValue(area.is_discovered)) {
      continue;
    }

    if (!isControlArea(area.area_type)) {
      continue;
    }

    const current = controlAreaByHex.get(area.hex_coordinate);
    if (!current || normalizeHex(area.area_id) < normalizeHex(current)) {
      controlAreaByHex.set(area.hex_coordinate, area.area_id);
    }
  }

  const ownerByAreaId = new Map<string, string>();
  for (const entry of rows.ownership) {
    ownerByAreaId.set(normalizeHex(entry.area_id), normalizeHex(entry.owner_adventurer_id));
  }

  const decayByHex = new Map<HexCoordinate, ToriiHexDecayRow>();
  for (const entry of rows.decay) {
    decayByHex.set(entry.hex_coordinate, entry);
  }

  const activeClaimCountByHex = new Map<HexCoordinate, number>();
  for (const claim of rows.claims) {
    if (!isActiveEnumStatus(claim.status)) {
      continue;
    }

    activeClaimCountByHex.set(
      claim.hex_coordinate,
      (activeClaimCountByHex.get(claim.hex_coordinate) ?? 0) + 1
    );
  }

  const adventurerCountByHex = new Map<HexCoordinate, number>();
  for (const adventurer of rows.adventurers) {
    adventurerCountByHex.set(
      adventurer.current_hex,
      (adventurerCountByHex.get(adventurer.current_hex) ?? 0) + 1
    );
  }

  const plantCountByHex = new Map<HexCoordinate, number>();
  for (const plant of rows.plants) {
    plantCountByHex.set(plant.hex_coordinate, (plantCountByHex.get(plant.hex_coordinate) ?? 0) + 1);
  }

  const chunks = new Map<ChunkKey, ChunkSnapshot>();

  for (const hex of rows.hexes) {
    if (!isTrueValue(hex.is_discovered)) {
      continue;
    }

    const chunkKey = chunkKeyForHexCoordinate(hex.coordinate, chunkSize);
    if (!chunkKey) {
      continue;
    }

    const [chunkQ, chunkR] = parseChunkKey(chunkKey);

    let chunk = chunks.get(chunkKey);
    if (!chunk) {
      chunk = {
        schemaVersion: "explorer-v1",
        chunk: {
          key: chunkKey,
          chunkQ,
          chunkR
        },
        headBlock,
        hexes: []
      };
      chunks.set(chunkKey, chunk);
    }

    const controlAreaId = controlAreaByHex.get(hex.coordinate);
    const ownerAdventurerId = controlAreaId
      ? ownerByAreaId.get(normalizeHex(controlAreaId)) ?? null
      : null;

    const decay = decayByHex.get(hex.coordinate);
    const decayLevel = toSafeNumber(decay?.decay_level, 0);
    const claimableSinceBlock = toSafeNumber(decay?.claimable_since_block, 0);

    const row: HexRenderRow = {
      hexCoordinate: hex.coordinate,
      biome: String(hex.biome),
      ownerAdventurerId,
      decayLevel,
      isClaimable: claimableSinceBlock > 0,
      activeClaimCount: activeClaimCountByHex.get(hex.coordinate) ?? 0,
      adventurerCount: adventurerCountByHex.get(hex.coordinate) ?? 0,
      plantCount: plantCountByHex.get(hex.coordinate) ?? 0
    };

    chunk.hexes.push(row);
  }

  return Array.from(chunks.values())
    .map((chunk) => ({
      ...chunk,
      hexes: [...chunk.hexes].sort((a, b) => normalizeHex(a.hexCoordinate).localeCompare(normalizeHex(b.hexCoordinate)))
    }))
    .sort((a, b) => compareChunkKeys(a.chunk.key, b.chunk.key));
}

function createLiveSelectors(store: LiveStore, chunkSize: number): ExplorerSelectors {
  return {
    visibleChunkKeys(viewport) {
      const zoom = Math.min(4, Math.max(0.25, viewport.zoom));
      const scaledWidth = viewport.width / zoom;
      const scaledHeight = viewport.height / zoom;
      const centerQ = floorDiv(Math.round(viewport.center.x), chunkSize);
      const centerR = floorDiv(Math.round(viewport.center.y), chunkSize);
      const visibleRadiusQ = Math.max(
        0,
        Math.ceil(scaledWidth / (chunkSize * VIEWPORT_CHUNK_SPAN_PX)) - 1
      );
      const visibleRadiusR = Math.max(
        0,
        Math.ceil(scaledHeight / (chunkSize * VIEWPORT_CHUNK_SPAN_PX)) - 1
      );
      const queryRadiusQ = visibleRadiusQ + PREFETCH_RING_CHUNKS;
      const queryRadiusR = visibleRadiusR + PREFETCH_RING_CHUNKS;
      const keys: ChunkKey[] = [];

      for (let qDelta = -queryRadiusQ; qDelta <= queryRadiusQ; qDelta += 1) {
        for (let rDelta = -queryRadiusR; rDelta <= queryRadiusR; rDelta += 1) {
          keys.push(`${centerQ + qDelta}:${centerR + rDelta}` as ChunkKey);
        }
      }

      const bounded = keys
        .sort((left, right) => {
          const [leftQ, leftR] = parseChunkKey(left);
          const [rightQ, rightR] = parseChunkKey(right);
          const leftDistance = Math.abs(leftQ - centerQ) + Math.abs(leftR - centerR);
          const rightDistance = Math.abs(rightQ - centerQ) + Math.abs(rightR - centerR);
          if (leftDistance !== rightDistance) {
            return leftDistance - rightDistance;
          }
          return compareChunkKeys(left, right);
        })
        .slice(0, MAX_VIEWPORT_CHUNK_KEYS);

      return bounded.sort(compareChunkKeys);
    },
    visibleHexes(_viewport, layers) {
      const loaded = store.snapshot().loadedChunks;
      const all = loaded.flatMap((chunk) => chunk.hexes);
      return filterHexesByLayer(all, layers);
    }
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

class LiveStore implements ExplorerDataStore {
  private chunks: ChunkSnapshot[] = [];
  private selectedHex: HexCoordinate | null = null;
  private patchState = createPatchReducerState();
  private streamState = createStreamState();
  private awaitingSnapshotResync = false;

  replaceChunks(chunks: ChunkSnapshot[]): void {
    this.chunks = chunks;
    if (this.awaitingSnapshotResync || this.streamState.resyncRequired) {
      this.awaitingSnapshotResync = false;
      this.streamState = {
        ...this.streamState,
        status: "live",
        resyncRequired: false
      };
    }
  }

  applyPatch(patch: StreamPatchEnvelope): void {
    this.streamState = applyIncomingPatchMetadata(this.streamState, patch);
    if (patch.kind === "resync_required" || this.streamState.resyncRequired) {
      this.awaitingSnapshotResync = true;
      this.streamState = {
        ...this.streamState,
        status: "catching_up",
        resyncRequired: true
      };
    }

    const nextPatchState = applyStreamPatch(this.patchState, patch);
    if (nextPatchState === this.patchState) {
      return;
    }
    this.patchState = nextPatchState;

    if (this.awaitingSnapshotResync || patch.kind === "resync_required") {
      return;
    }

    if (patch.kind === "chunk_snapshot") {
      const chunk = toChunkSnapshotFromPatchPayload(patch.payload);
      if (!chunk) {
        return;
      }
      this.upsertChunk(chunk);
      return;
    }

    if (patch.kind === "hex_patch") {
      const update = toHexPatchUpdate(patch.payload);
      if (!update) {
        return;
      }
      this.upsertHex(update, patch.blockNumber);
    }
  }

  evictChunk(key: ChunkKey): void {
    this.chunks = this.chunks.filter((chunk) => chunk.chunk.key !== key);
  }

  setSelectedHex(hex: HexCoordinate | null): void {
    this.selectedHex = hex;
  }

  snapshot() {
    return {
      status: this.streamState.status,
      headBlock: this.chunks.reduce((max, chunk) => Math.max(max, chunk.headBlock), 0),
      selectedHex: this.selectedHex,
      loadedChunks: this.chunks
    };
  }

  private upsertChunk(chunk: ChunkSnapshot): void {
    const next = [...this.chunks];
    const index = next.findIndex((entry) => entry.chunk.key === chunk.chunk.key);
    if (index === -1) {
      next.push(chunk);
    } else {
      next[index] = chunk;
    }
    this.chunks = next.sort((left, right) => compareChunkKeys(left.chunk.key, right.chunk.key));
  }

  private upsertHex(update: HexPatchUpdate, fallbackHeadBlock: number): void {
    const next = [...this.chunks];
    const index = next.findIndex((entry) => entry.chunk.key === update.chunkKey);
    const existing = index === -1 ? null : next[index];
    const baseChunk = existing ?? createEmptyChunk(update.chunkKey);

    const hexes = [...baseChunk.hexes];
    const hexIndex = hexes.findIndex(
      (entry) => normalizeHex(entry.hexCoordinate) === normalizeHex(update.hex.hexCoordinate)
    );
    if (hexIndex === -1) {
      hexes.push(update.hex);
    } else {
      hexes[hexIndex] = update.hex;
    }

    const headBlock = Math.max(baseChunk.headBlock, update.headBlock ?? 0, fallbackHeadBlock);
    const updated: ChunkSnapshot = {
      ...baseChunk,
      headBlock,
      hexes
    };

    if (index === -1) {
      next.push(updated);
    } else {
      next[index] = updated;
    }
    this.chunks = next.sort((left, right) => compareChunkKeys(left.chunk.key, right.chunk.key));
  }
}

export class LiveProxyHttpClient implements ExplorerProxyClient {
  private readonly proxyOrigin: string;
  private readonly fetchImpl: typeof fetch;
  private readonly cacheTtlMs: number;
  private readonly maxChunkKeys: number;
  private readonly nowMs: () => number;
  private readonly webSocketFactory: LiveProxyWebSocketFactory;
  private readonly chunkCache = new Map<
    ChunkKey,
    { cachedAtMs: number; chunk: ChunkSnapshot }
  >();

  constructor(options: {
    proxyOrigin: string;
    fetchImpl: typeof fetch;
    cacheTtlMs: number;
    maxChunkKeys: number;
    webSocketFactory?: LiveProxyWebSocketFactory;
    nowMs?: () => number;
  }) {
    this.proxyOrigin = options.proxyOrigin.replace(/\/+$/, "");
    this.fetchImpl = options.fetchImpl;
    this.cacheTtlMs = Math.max(0, Math.floor(options.cacheTtlMs));
    this.maxChunkKeys = Math.max(1, Math.floor(options.maxChunkKeys));
    this.nowMs = options.nowMs ?? Date.now;
    this.webSocketFactory =
      options.webSocketFactory ??
      ((url) => {
        if (typeof WebSocket === "undefined") {
          throw new Error("WebSocket is not available in this runtime");
        }
        return new WebSocket(url) as unknown as LiveProxyWebSocket;
      });
  }

  async getChunks(keys: ChunkKey[]): Promise<ChunkSnapshot[]> {
    const normalizedKeys = Array.from(new Set(keys)).slice(0, this.maxChunkKeys);
    if (normalizedKeys.length === 0) {
      return [];
    }

    const now = this.nowMs();
    const missing: ChunkKey[] = [];
    for (const key of normalizedKeys) {
      const cached = this.chunkCache.get(key);
      if (!cached || now - cached.cachedAtMs >= this.cacheTtlMs) {
        missing.push(key);
      }
    }

    if (missing.length > 0) {
      const params = new URLSearchParams();
      params.set("keys", missing.join(","));
      const response = await this.fetchJson<ProxyChunksResponse>(
        `/v1/chunks?${params.toString()}`
      );
      const byKey = new Map(response.chunks.map((chunk) => [chunk.chunk.key, chunk]));
      for (const key of missing) {
        const chunk = byKey.get(key);
        if (!chunk) {
          this.chunkCache.delete(key);
          continue;
        }
        this.chunkCache.set(key, {
          cachedAtMs: now,
          chunk
        });
      }
    }

    return normalizedKeys.flatMap((key) => {
      const cached = this.chunkCache.get(key);
      return cached ? [cached.chunk] : [];
    });
  }

  async getHexInspect(hexCoordinate: HexCoordinate): Promise<HexInspectPayload> {
    return this.fetchJson<HexInspectPayload>(`/v1/hex/${encodeURIComponent(hexCoordinate)}`);
  }

  async search(query: SearchQuery): Promise<SearchResult[]> {
    const params = new URLSearchParams();
    if (query.coord) {
      params.set("coord", query.coord);
    } else if (query.owner) {
      params.set("owner", query.owner);
    } else if (query.adventurer) {
      params.set("adventurer", query.adventurer);
    }
    if (query.limit !== undefined) {
      params.set("limit", String(query.limit));
    }

    const response = await this.fetchJson<ProxySearchResponse>(
      `/v1/search?${params.toString()}`
    );
    return response.results;
  }

  async getEventTail(_query: EventTailQuery): Promise<EventTailRow[]> {
    return [];
  }

  subscribePatches(handlers: PatchStreamHandlers) {
    let closed = false;
    let socket: LiveProxyWebSocket | null = null;

    const onOpen = (): void => {
      handlers.onStatus("live");
    };
    const onClose = (): void => {
      if (closed) {
        return;
      }
      handlers.onStatus("degraded");
    };
    const onError = (event: LiveProxyErrorEvent): void => {
      if (closed) {
        return;
      }
      handlers.onStatus("degraded");
      const details =
        event.error instanceof Error
          ? event.error
          : new Error(event.message ?? "proxy websocket error");
      handlers.onError(details);
    };
    const onMessage = (event: LiveProxyMessageEvent): void => {
      if (closed) {
        return;
      }

      try {
        const patch = decodeProxyPatchEnvelope(event.data);
        handlers.onPatch(patch);
      } catch (error) {
        handlers.onStatus("degraded");
        handlers.onError(error instanceof Error ? error : new Error(String(error)));
      }
    };

    const bootstrap = async (): Promise<void> => {
      handlers.onStatus("catching_up");
      try {
        await this.fetchJson<ProxyStatusResponse>("/v1/status");
      } catch (error) {
        handlers.onStatus("degraded");
        handlers.onError(error instanceof Error ? error : new Error(String(error)));
        return;
      }

      if (closed) {
        return;
      }

      const streamUrl = buildWebSocketUrl(this.proxyOrigin, "/v1/stream");
      socket = this.webSocketFactory(streamUrl);
      socket.addEventListener("open", onOpen);
      socket.addEventListener("message", onMessage);
      socket.addEventListener("close", onClose);
      socket.addEventListener("error", onError);
    };

    void bootstrap();

    return {
      close: () => {
        if (closed) {
          return;
        }
        closed = true;
        if (socket) {
          socket.removeEventListener("open", onOpen);
          socket.removeEventListener("message", onMessage);
          socket.removeEventListener("close", onClose);
          socket.removeEventListener("error", onError);
          socket.close();
          socket = null;
        }
      }
    };
  }

  private async fetchJson<TResponse>(pathAndQuery: string): Promise<TResponse> {
    const response = await this.fetchImpl(`${this.proxyOrigin}${pathAndQuery}`, {
      method: "GET",
      headers: {
        accept: "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(
        `Proxy request failed (${response.status}) for ${pathAndQuery}`
      );
    }

    return (await response.json()) as TResponse;
  }
}

export class LiveToriiProxyClient implements ExplorerProxyClient {
  private readonly toriiGraphqlUrl: string;
  private readonly cacheTtlMs: number;
  private readonly pollIntervalMs: number;
  private readonly chunkSize: number;
  private readonly queryLimit: number;
  private readonly fetchImpl: typeof fetch;

  private cachedSnapshot: SnapshotBundle | null = null;
  private cachedAtMs = 0;
  private inFlightSnapshot: Promise<SnapshotBundle> | null = null;

  constructor(options: {
    toriiGraphqlUrl: string;
    cacheTtlMs: number;
    pollIntervalMs: number;
    chunkSize: number;
    queryLimit: number;
    fetchImpl: typeof fetch;
  }) {
    this.toriiGraphqlUrl = options.toriiGraphqlUrl;
    this.cacheTtlMs = options.cacheTtlMs;
    this.pollIntervalMs = options.pollIntervalMs;
    this.chunkSize = options.chunkSize;
    this.queryLimit = options.queryLimit;
    this.fetchImpl = options.fetchImpl;
  }

  async getChunks(keys: ChunkKey[]): Promise<ChunkSnapshot[]> {
    const snapshot = await this.loadSnapshot(false);
    const chunks = buildChunkSnapshotsFromToriiRows(snapshot, {
      chunkSize: this.chunkSize,
      headBlock: snapshot.headBlock
    });
    const byKey = new Map(chunks.map((chunk) => [chunk.chunk.key, chunk]));

    return keys.flatMap((key) => {
      const chunk = byKey.get(key);
      return chunk ? [chunk] : [];
    });
  }

  async getHexInspect(hexCoordinate: HexCoordinate): Promise<HexInspectPayload> {
    const snapshot = await this.loadSnapshot(false);
    const hexRow = snapshot.hexes.find(
      (row) => normalizeHex(row.coordinate) === normalizeHex(hexCoordinate)
    );

    if (!hexRow) {
      throw new Error(`Hex not found in live Torii snapshot: ${hexCoordinate}`);
    }

    const areas = snapshot.areas.filter(
      (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
    );

    const areaIds = new Set(areas.map((row) => normalizeHex(row.area_id)));
    const ownership = snapshot.ownership.filter((row) => areaIds.has(normalizeHex(row.area_id)));

    const decayState =
      snapshot.decay.find(
        (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
      ) ?? null;

    const activeClaims = snapshot.claims.filter((row) => {
      return (
        normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate) &&
        isActiveEnumStatus(row.status)
      );
    });

    const plants = snapshot.plants.filter(
      (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
    );

    const mineNodes = snapshot.mineNodes.filter(
      (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
    );
    const mineKeys = new Set(mineNodes.map((row) => normalizeHex(row.mine_key)));
    const miningShifts = snapshot.miningShifts.filter((row) =>
      mineKeys.has(normalizeHex(row.mine_key))
    );
    const mineAccessGrants = snapshot.mineAccessGrants.filter((row) =>
      mineKeys.has(normalizeHex(row.mine_key))
    );
    const mineCollapseRecords = snapshot.mineCollapseRecords.filter((row) =>
      mineKeys.has(normalizeHex(row.mine_key))
    );

    const plantKeys = new Set(plants.map((row) => normalizeHex(row.plant_key)));
    const activeReservations = snapshot.reservations.filter((row) => {
      return plantKeys.has(normalizeHex(row.plant_key)) && isActiveEnumStatus(row.status);
    });

    const buildings = snapshot.buildings.filter(
      (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
    );

    const constructionProjects = snapshot.constructionProjects.filter(
      (row) => normalizeHex(row.hex_coordinate) === normalizeHex(hexCoordinate)
    );

    const projectIds = new Set(constructionProjects.map((row) => normalizeHex(row.project_id)));
    const constructionEscrows = snapshot.constructionEscrows.filter((row) => {
      return projectIds.has(normalizeHex(row.project_id));
    });

    const adventurers = snapshot.adventurers.filter(
      (row) => normalizeHex(row.current_hex) === normalizeHex(hexCoordinate)
    );

    const relatedAdventurerIds = new Set<string>();
    for (const row of adventurers) {
      relatedAdventurerIds.add(normalizeHex(row.adventurer_id));
    }
    for (const row of ownership) {
      relatedAdventurerIds.add(normalizeHex(row.owner_adventurer_id));
      relatedAdventurerIds.add(normalizeHex(row.discoverer_adventurer_id));
    }
    for (const row of activeClaims) {
      relatedAdventurerIds.add(normalizeHex(row.claimant_adventurer_id));
    }
    for (const row of activeReservations) {
      relatedAdventurerIds.add(normalizeHex(row.adventurer_id));
    }
    for (const row of buildings) {
      relatedAdventurerIds.add(normalizeHex(row.owner_adventurer_id));
    }
    for (const row of constructionProjects) {
      relatedAdventurerIds.add(normalizeHex(row.adventurer_id));
    }
    for (const row of miningShifts) {
      relatedAdventurerIds.add(normalizeHex(row.adventurer_id));
    }
    for (const row of mineAccessGrants) {
      relatedAdventurerIds.add(normalizeHex(row.grantee_adventurer_id));
      relatedAdventurerIds.add(normalizeHex(row.granted_by_adventurer_id));
    }
    if (decayState) {
      relatedAdventurerIds.add(normalizeHex(decayState.owner_adventurer_id));
    }

    const adventurerEconomics = snapshot.economics.filter((row) =>
      relatedAdventurerIds.has(normalizeHex(row.adventurer_id))
    );
    const inventories = snapshot.inventories.filter((row) =>
      relatedAdventurerIds.has(normalizeHex(row.adventurer_id))
    );
    const backpackItems = snapshot.backpackItems.filter((row) =>
      relatedAdventurerIds.has(normalizeHex(row.adventurer_id))
    );
    const deathRecords = snapshot.deathRecords.filter((row) =>
      relatedAdventurerIds.has(normalizeHex(row.adventurer_id))
    );

    return {
      schemaVersion: "explorer-v1",
      headBlock: snapshot.headBlock,
      hex: hexRow as unknown as Hex,
      areas: areas as unknown as HexArea[],
      ownership: ownership as unknown as AreaOwnership[],
      decayState: decayState as unknown as HexDecayState | null,
      activeClaims: activeClaims as unknown as ClaimEscrow[],
      plants: plants as unknown as PlantNode[],
      activeReservations: activeReservations as unknown as HarvestReservation[],
      adventurers: adventurers as unknown as Adventurer[],
      adventurerEconomics: adventurerEconomics as unknown as AdventurerEconomics[],
      inventories: inventories as unknown as Inventory[],
      backpackItems: backpackItems as unknown as BackpackItem[],
      buildings: buildings as unknown as ConstructionBuildingNode[],
      constructionProjects: constructionProjects as unknown as ConstructionProject[],
      constructionEscrows: constructionEscrows as unknown as ConstructionMaterialEscrow[],
      deathRecords: deathRecords as unknown as DeathRecord[],
      mineNodes: mineNodes as unknown as MineNode[],
      miningShifts: miningShifts as unknown as MiningShift[],
      mineAccessGrants: mineAccessGrants as unknown as MineAccessGrant[],
      mineCollapseRecords: mineCollapseRecords as unknown as MineCollapseRecord[],
      eventTail: []
    };
  }

  async search(query: SearchQuery): Promise<SearchResult[]> {
    const snapshot = await this.loadSnapshot(false);
    const discoveredHexes = new Set(
      snapshot.hexes
        .filter((row) => isTrueValue(row.is_discovered))
        .map((row) => normalizeHex(row.coordinate))
    );

    if (query.coord) {
      const target = normalizeHex(query.coord);
      if (!discoveredHexes.has(target)) {
        return [];
      }

      return [{ hexCoordinate: target, score: 100, reason: "coord" }];
    }

    const limit = query.limit ?? 20;

    if (query.owner) {
      const owner = normalizeHex(query.owner);
      const coordinates = dedupeHexes(
        snapshot.adventurers
          .filter((row) => normalizeHex(row.owner) === owner)
          .map((row) => normalizeHex(row.current_hex))
          .filter((coordinate) => discoveredHexes.has(coordinate))
      );

      return coordinates.slice(0, limit).map((hexCoordinate, index) => ({
        hexCoordinate,
        score: 100 - index,
        reason: "owner" as const
      }));
    }

    if (query.adventurer) {
      const adventurer = normalizeHex(query.adventurer);
      const coordinates = dedupeHexes(
        snapshot.adventurers
          .filter((row) => normalizeHex(row.adventurer_id) === adventurer)
          .map((row) => normalizeHex(row.current_hex))
          .filter((coordinate) => discoveredHexes.has(coordinate))
      );

      return coordinates.slice(0, limit).map((hexCoordinate, index) => ({
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
    let closed = false;
    let sequence = 0;
    let previousDigest: string | null = null;
    handlers.onStatus("live");

    const poll = async (forceRefresh: boolean): Promise<void> => {
      if (closed) {
        return;
      }

      try {
        const snapshot = await this.loadSnapshot(forceRefresh);
        const digest = `${snapshot.headBlock}:${snapshot.hexes.length}:${snapshot.claims.length}:${snapshot.reservations.length}`;

        if (digest !== previousDigest) {
          previousDigest = digest;
          sequence += 1;
          handlers.onPatch({
            schemaVersion: "explorer-v1",
            sequence,
            blockNumber: snapshot.headBlock,
            txIndex: 0,
            eventIndex: 0,
            kind: "heartbeat",
            payload: {
              source: "live-torii",
              hexCount: snapshot.hexes.length
            },
            emittedAtMs: Date.now()
          });
        }

        handlers.onStatus("live");
      } catch (error) {
        handlers.onStatus("degraded");
        handlers.onError(error instanceof Error ? error : new Error(String(error)));
      }
    };

    void poll(false);
    const interval = globalThis.setInterval(() => {
      void poll(true);
    }, this.pollIntervalMs);

    return {
      close: () => {
        closed = true;
        globalThis.clearInterval(interval);
      }
    };
  }

  private async loadSnapshot(forceRefresh: boolean): Promise<SnapshotBundle> {
    const now = Date.now();
    if (!forceRefresh && this.cachedSnapshot && now - this.cachedAtMs < this.cacheTtlMs) {
      return this.cachedSnapshot;
    }

    if (this.inFlightSnapshot) {
      return this.inFlightSnapshot;
    }

    this.inFlightSnapshot = this.fetchSnapshot()
      .then((snapshot) => {
        this.cachedSnapshot = snapshot;
        this.cachedAtMs = Date.now();
        return snapshot;
      })
      .finally(() => {
        this.inFlightSnapshot = null;
      });

    return this.inFlightSnapshot;
  }

  private async fetchSnapshot(): Promise<SnapshotBundle> {
    const payload = await this.queryGraphql<SnapshotQueryData>(SNAPSHOT_QUERY, {
      hexLimit: this.queryLimit,
      modelLimit: this.queryLimit
    });

    const rows: ToriiSnapshotRows = {
      hexes: toNodes(payload.dojoStarterHexModels),
      areas: toNodes(payload.dojoStarterHexAreaModels),
      ownership: toNodes(payload.dojoStarterAreaOwnershipModels),
      decay: toNodes(payload.dojoStarterHexDecayStateModels),
      claims: toNodes(payload.dojoStarterClaimEscrowModels),
      plants: toNodes(payload.dojoStarterPlantNodeModels),
      reservations: toNodes(payload.dojoStarterHarvestReservationModels),
      adventurers: toNodes(payload.dojoStarterAdventurerModels),
      economics: toNodes(payload.dojoStarterAdventurerEconomicsModels),
      inventories: toNodes(payload.dojoStarterInventoryModels),
      backpackItems: toNodes(payload.dojoStarterBackpackItemModels),
      deathRecords: toNodes(payload.dojoStarterDeathRecordModels),
      buildings: toNodes(payload.dojoStarterConstructionBuildingNodeModels),
      constructionProjects: toNodes(payload.dojoStarterConstructionProjectModels),
      constructionEscrows: toNodes(payload.dojoStarterConstructionMaterialEscrowModels),
      mineNodes: toNodes(payload.dojoStarterMineNodeModels),
      miningShifts: toNodes(payload.dojoStarterMiningShiftModels),
      mineAccessGrants: toNodes(payload.dojoStarterMineAccessGrantModels),
      mineCollapseRecords: toNodes(payload.dojoStarterMineCollapseRecordModels)
    };

    return {
      ...rows,
      headBlock: deriveHeadBlock(rows)
    };
  }

  private async queryGraphql<TData>(
    query: string,
    variables: Record<string, unknown>
  ): Promise<TData> {
    const response = await this.fetchImpl(this.toriiGraphqlUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json"
      },
      body: JSON.stringify({ query, variables })
    });

    if (!response.ok) {
      throw new Error(`Torii GraphQL request failed with status ${response.status}`);
    }

    const json = (await response.json()) as GraphqlResponse<TData>;

    if (json.errors && json.errors.length > 0) {
      const message = json.errors
        .map((entry) => entry?.message)
        .filter((entry): entry is string => Boolean(entry))
        .join("; ");
      throw new Error(`Torii GraphQL error: ${message || "unknown"}`);
    }

    if (!json.data) {
      throw new Error("Torii GraphQL response missing data");
    }

    return json.data;
  }
}

function buildWebSocketUrl(origin: string, path: string): string {
  const normalized = origin.replace(/\/+$/, "");
  if (normalized.startsWith("https://")) {
    return `wss://${normalized.slice("https://".length)}${path}`;
  }
  if (normalized.startsWith("http://")) {
    return `ws://${normalized.slice("http://".length)}${path}`;
  }
  return `${normalized}${path}`;
}

function decodeProxyPatchEnvelope(data: unknown): StreamPatchEnvelope {
  const raw = decodeWebSocketMessageData(data);
  const parsed = JSON.parse(raw) as Partial<StreamPatchEnvelope>;
  if (
    typeof parsed.sequence !== "number" ||
    typeof parsed.blockNumber !== "number" ||
    typeof parsed.txIndex !== "number" ||
    typeof parsed.eventIndex !== "number" ||
    typeof parsed.kind !== "string"
  ) {
    throw new Error("proxy stream payload is not a valid patch envelope");
  }

  return parsed as StreamPatchEnvelope;
}

function decodeWebSocketMessageData(data: unknown): string {
  if (typeof data === "string") {
    return data;
  }

  if (data instanceof ArrayBuffer) {
    return new TextDecoder().decode(data);
  }

  if (ArrayBuffer.isView(data)) {
    return new TextDecoder().decode(data);
  }

  throw new Error("proxy websocket message must be text or binary");
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

function isHexRenderRowPayload(payload: unknown): payload is HexRenderRow {
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

function toNodes<TNode>(connection: GraphqlConnection<TNode> | null | undefined): TNode[] {
  if (!connection?.edges) {
    return [];
  }

  const nodes: TNode[] = [];
  for (const edge of connection.edges) {
    const node = edge?.node;
    if (node) {
      nodes.push(node);
    }
  }

  return nodes;
}

function deriveHeadBlock(rows: ToriiSnapshotRows): number {
  let head = 0;

  for (const hex of rows.hexes) {
    head = Math.max(head, toSafeNumber(hex.discovery_block, 0));
  }

  for (const ownership of rows.ownership) {
    head = Math.max(head, toSafeNumber(ownership.discovery_block, 0));
    head = Math.max(head, toSafeNumber(ownership.claim_block, 0));
  }

  for (const decay of rows.decay) {
    head = Math.max(head, toSafeNumber(decay.last_energy_payment_block, 0));
    head = Math.max(head, toSafeNumber(decay.last_decay_processed_block, 0));
    head = Math.max(head, toSafeNumber(decay.claimable_since_block, 0));
  }

  for (const claim of rows.claims) {
    head = Math.max(head, toSafeNumber(claim.created_block, 0));
    head = Math.max(head, toSafeNumber(claim.expiry_block, 0));
  }

  for (const reservation of rows.reservations) {
    head = Math.max(head, toSafeNumber(reservation.created_block, 0));
    head = Math.max(head, toSafeNumber(reservation.expiry_block, 0));
  }

  for (const plant of rows.plants) {
    head = Math.max(head, toSafeNumber(plant.last_harvest_block, 0));
  }

  for (const adventurer of rows.adventurers) {
    head = Math.max(head, toSafeNumber(adventurer.activity_locked_until, 0));
  }

  for (const economics of rows.economics) {
    head = Math.max(head, toSafeNumber(economics.last_regen_block, 0));
  }

  for (const deathRecord of rows.deathRecords) {
    head = Math.max(head, toSafeNumber(deathRecord.death_block, 0));
  }

  for (const building of rows.buildings) {
    head = Math.max(head, toSafeNumber(building.last_upkeep_block, 0));
  }

  for (const project of rows.constructionProjects) {
    head = Math.max(head, toSafeNumber(project.start_block, 0));
    head = Math.max(head, toSafeNumber(project.completion_block, 0));
  }

  return head;
}

function parseChunkKey(key: ChunkKey): [number, number] {
  const [chunkQRaw, chunkRRaw] = key.split(":").map((value) => Number.parseInt(value, 10));
  return [chunkQRaw ?? 0, chunkRRaw ?? 0];
}

function compareChunkKeys(left: ChunkKey, right: ChunkKey): number {
  const [leftQ, leftR] = parseChunkKey(left);
  const [rightQ, rightR] = parseChunkKey(right);

  if (leftQ !== rightQ) {
    return leftQ - rightQ;
  }

  return leftR - rightR;
}

function isControlArea(areaType: unknown): boolean {
  return String(areaType).toLowerCase() === "control";
}

function isActiveEnumStatus(status: unknown): boolean {
  const normalized = String(status).toLowerCase();
  return normalized === "active" || normalized === "1";
}

function isTrueValue(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "number") {
    return value !== 0;
  }

  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1";
  }

  return false;
}

function toSafeNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.floor(value);
  }

  if (typeof value === "bigint") {
    return bigintToNumber(value, fallback);
  }

  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return fallback;
    }

    try {
      if (trimmed.startsWith("0x") || trimmed.startsWith("-0x")) {
        return bigintToNumber(BigInt(trimmed), fallback);
      }

      const parsed = Number.parseInt(trimmed, 10);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    } catch {
      return fallback;
    }
  }

  return fallback;
}

function bigintToNumber(value: bigint, fallback: number): number {
  const max = BigInt(Number.MAX_SAFE_INTEGER);
  const min = BigInt(Number.MIN_SAFE_INTEGER);
  if (value > max || value < min) {
    return fallback;
  }

  return Number(value);
}

function normalizeHex(value: unknown): HexCoordinate {
  return String(value).toLowerCase() as HexCoordinate;
}

function dedupeHexes(values: HexCoordinate[]): HexCoordinate[] {
  const deduped = Array.from(new Set(values));
  deduped.sort((left, right) => normalizeHex(left).localeCompare(normalizeHex(right)));
  return deduped;
}

function floorDiv(value: number, divisor: number): number {
  return Math.floor(value / divisor);
}
