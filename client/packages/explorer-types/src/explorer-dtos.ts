import type {
  Adventurer,
  AreaOwnership,
  ClaimEscrow,
  HarvestReservation,
  Hex,
  HexArea,
  HexDecayState,
  PlantNode
} from "./generated";

export type ExplorerSchemaVersion = "explorer-v1";
export type Felt = `0x${string}` | string;
export type HexCoordinate = Felt;
export type AreaId = Felt;
export type AdventurerId = Felt;
export type ClaimId = Felt;

export type ChunkKey = `${number}:${number}`;

export interface ChunkAddress {
  key: ChunkKey;
  chunkQ: number;
  chunkR: number;
}

export interface HexRenderRow {
  hexCoordinate: HexCoordinate;
  biome: string;
  ownerAdventurerId: AdventurerId | null;
  decayLevel: number;
  isClaimable: boolean;
  activeClaimCount: number;
  adventurerCount: number;
  plantCount: number;
}

export interface ChunkSnapshot {
  schemaVersion: ExplorerSchemaVersion;
  chunk: ChunkAddress;
  headBlock: number;
  hexes: HexRenderRow[];
}

export interface HexInspectPayload {
  schemaVersion: ExplorerSchemaVersion;
  headBlock: number;
  hex: Hex;
  areas: HexArea[];
  ownership: AreaOwnership[];
  decayState: HexDecayState | null;
  activeClaims: ClaimEscrow[];
  plants: PlantNode[];
  activeReservations: HarvestReservation[];
  adventurers: Adventurer[];
  eventTail: EventTailRow[];
}

export type PatchKind =
  | "chunk_snapshot"
  | "hex_patch"
  | "claim_patch"
  | "adventurer_patch"
  | "plant_patch"
  | "resync_required"
  | "heartbeat";

export interface PatchPosition {
  sequence: number;
  blockNumber: number;
  txIndex: number;
  eventIndex: number;
}

export interface StreamPatchEnvelope<TPayload = unknown> extends PatchPosition {
  schemaVersion: ExplorerSchemaVersion;
  kind: PatchKind;
  payload: TPayload;
  emittedAtMs: number;
}

export interface EventTailQuery {
  hexCoordinate?: HexCoordinate;
  adventurerId?: AdventurerId;
  limit: number;
}

export interface EventTailRow {
  blockNumber: number;
  txIndex: number;
  eventIndex: number;
  eventName: string;
  payloadJson: string;
  hexCoordinate?: HexCoordinate;
  adventurerId?: AdventurerId;
}

export type LayerId =
  | "biome"
  | "ownership"
  | "claims"
  | "adventurers"
  | "resources"
  | "decay";

export type LayerToggleState = Record<LayerId, boolean>;

export interface ViewportWindow {
  center: { x: number; y: number };
  width: number;
  height: number;
  zoom: number;
}

export interface SearchQuery {
  coord?: HexCoordinate;
  owner?: AdventurerId;
  adventurer?: AdventurerId;
  limit?: number;
}

export interface SearchResult {
  hexCoordinate: HexCoordinate;
  score: number;
  reason: "coord" | "owner" | "adventurer";
}

export type StreamStatus = "live" | "catching_up" | "degraded";
