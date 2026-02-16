/**
 * Seeded SQL Fixture Harness for Torii View Tests
 *
 * Creates ephemeral SQLite databases with deterministic seed data
 * mirroring Torii's table structure for discovered/undiscovered hexes,
 * claims, ownership, and event timelines.
 *
 * @module fixtures/harness
 */

import Database from "better-sqlite3";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

/** Torii model table name mapping (matches dojo codegen pattern) */
const MODEL_TABLE_PREFIX = "dojo_starter_";

/** Core model tables required for view tests */
const CORE_TABLES = [
  "Hex",
  "HexArea",
  "AreaOwnership",
  "HexDecayState",
  "ClaimEscrow",
  "PlantNode",
  "HarvestReservation",
  "Adventurer",
  "AdventurerEconomics",
  "BackpackItem",
] as const;

export type CoreModel = (typeof CORE_TABLES)[number];

/**
 * Schema definitions for each model table.
 * These mirror Torii's SQLite schema from Dojo model indexing.
 */
const TABLE_SCHEMAS: Record<CoreModel, string> = {
  Hex: `
    CREATE TABLE {{Hex}} (
      id TEXT PRIMARY KEY,
      coordinate TEXT NOT NULL,
      biome TEXT NOT NULL,
      area_count INTEGER NOT NULL DEFAULT 0,
      is_discovered INTEGER NOT NULL DEFAULT 0,
      discoverer TEXT,
      discovered_at_block INTEGER
    )
  `,
  HexArea: `
    CREATE TABLE {{HexArea}} (
      id TEXT PRIMARY KEY,
      area_id TEXT NOT NULL UNIQUE,
      hex_coordinate TEXT NOT NULL,
      area_index INTEGER NOT NULL,
      area_type TEXT NOT NULL,
      plant_slot_count INTEGER NOT NULL DEFAULT 0,
      controller TEXT,
      controller_set_at_block INTEGER
    )
  `,
  AreaOwnership: `
    CREATE TABLE {{AreaOwnership}} (
      id TEXT PRIMARY KEY,
      area_id TEXT NOT NULL,
      owner TEXT NOT NULL,
      assigned_at_block INTEGER NOT NULL
    )
  `,
  HexDecayState: `
    CREATE TABLE {{HexDecayState}} (
      id TEXT PRIMARY KEY,
      hex_coordinate TEXT NOT NULL UNIQUE,
      decay_level INTEGER NOT NULL DEFAULT 0,
      last_maintenance_block INTEGER,
      claimable_since_block INTEGER
    )
  `,
  ClaimEscrow: `
    CREATE TABLE {{ClaimEscrow}} (
      id TEXT PRIMARY KEY,
      hex_coordinate TEXT NOT NULL,
      claimant TEXT NOT NULL,
      energy_locked INTEGER NOT NULL,
      initiated_at_block INTEGER NOT NULL,
      expires_at_block INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1
    )
  `,
  PlantNode: `
    CREATE TABLE {{PlantNode}} (
      id TEXT PRIMARY KEY,
      plant_key TEXT NOT NULL UNIQUE,
      hex_coordinate TEXT NOT NULL,
      area_id TEXT NOT NULL,
      plant_id INTEGER NOT NULL,
      species TEXT NOT NULL,
      current_yield INTEGER NOT NULL DEFAULT 0,
      max_yield INTEGER NOT NULL,
      regrowth_rate INTEGER NOT NULL,
      state INTEGER NOT NULL DEFAULT 0
    )
  `,
  HarvestReservation: `
    CREATE TABLE {{HarvestReservation}} (
      id TEXT PRIMARY KEY,
      reservation_key TEXT NOT NULL UNIQUE,
      adventurer_id TEXT NOT NULL,
      plant_key TEXT NOT NULL,
      reserved_amount INTEGER NOT NULL,
      start_block INTEGER NOT NULL,
      end_block INTEGER NOT NULL,
      state INTEGER NOT NULL DEFAULT 0
    )
  `,
  Adventurer: `
    CREATE TABLE {{Adventurer}} (
      id TEXT PRIMARY KEY,
      adventurer_id TEXT NOT NULL UNIQUE,
      owner TEXT NOT NULL,
      name TEXT NOT NULL,
      energy INTEGER NOT NULL DEFAULT 100,
      max_energy INTEGER NOT NULL DEFAULT 100,
      hex_coordinate TEXT NOT NULL,
      is_alive INTEGER NOT NULL DEFAULT 1,
      created_at_block INTEGER NOT NULL
    )
  `,
  AdventurerEconomics: `
    CREATE TABLE {{AdventurerEconomics}} (
      id TEXT PRIMARY KEY,
      adventurer_id TEXT NOT NULL UNIQUE,
      total_harvested INTEGER NOT NULL DEFAULT 0,
      total_converted INTEGER NOT NULL DEFAULT 0,
      last_regen_block INTEGER
    )
  `,
  BackpackItem: `
    CREATE TABLE {{BackpackItem}} (
      id TEXT PRIMARY KEY,
      adventurer_id TEXT NOT NULL,
      item_id TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      UNIQUE(adventurer_id, item_id)
    )
  `,
};

/** Event table for timeline tests */
const EVENT_TABLE_SCHEMA = `
  CREATE TABLE events (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    block_number INTEGER NOT NULL,
    tx_index INTEGER NOT NULL,
    event_index INTEGER NOT NULL,
    data TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
`;

/** Index for event ordering */
const EVENT_INDEX = `
  CREATE INDEX idx_events_order ON events (block_number, tx_index, event_index)
`;

export interface FixtureHarnessOptions {
  /** Use in-memory database (default: true) */
  inMemory?: boolean;
  /** Custom database path for persistent tests */
  dbPath?: string;
  /** Enable verbose SQL logging */
  verbose?: boolean;
}

export interface SeedData {
  hexes?: HexSeed[];
  areas?: AreaSeed[];
  adventurers?: AdventurerSeed[];
  plants?: PlantSeed[];
  claims?: ClaimSeed[];
  events?: EventSeed[];
}

export interface HexSeed {
  coordinate: string;
  biome: string;
  areaCount?: number;
  isDiscovered?: boolean;
  discoverer?: string;
  discoveredAtBlock?: number;
}

export interface AreaSeed {
  areaId: string;
  hexCoordinate: string;
  areaIndex: number;
  areaType: "Control" | "PlantField" | "MineShaft" | "BuildSite";
  plantSlotCount?: number;
  controller?: string;
  controllerSetAtBlock?: number;
  owner?: string;
  ownerAssignedAtBlock?: number;
}

export interface AdventurerSeed {
  adventurerId: string;
  owner: string;
  name: string;
  energy?: number;
  maxEnergy?: number;
  hexCoordinate: string;
  isAlive?: boolean;
  createdAtBlock: number;
}

export interface PlantSeed {
  plantKey: string;
  hexCoordinate: string;
  areaId: string;
  plantId: number;
  species: string;
  currentYield?: number;
  maxYield: number;
  regrowthRate: number;
}

export interface ClaimSeed {
  hexCoordinate: string;
  claimant: string;
  energyLocked: number;
  initiatedAtBlock: number;
  expiresAtBlock: number;
  isActive?: boolean;
}

export interface EventSeed {
  eventType: string;
  blockNumber: number;
  txIndex: number;
  eventIndex: number;
  data: Record<string, unknown>;
}

/**
 * Test fixture harness for Torii SQL view tests.
 *
 * Creates an ephemeral SQLite database with the same schema as Torii,
 * seeds it with deterministic test data, and provides query utilities.
 */
export class FixtureHarness {
  private db: Database.Database;
  private options: Required<FixtureHarnessOptions>;

  constructor(options: FixtureHarnessOptions = {}) {
    this.options = {
      inMemory: options.inMemory ?? true,
      dbPath: options.dbPath ?? ":memory:",
      verbose: options.verbose ?? false,
    };

    const dbPath = this.options.inMemory ? ":memory:" : this.options.dbPath;
    this.db = new Database(dbPath, {
      verbose: this.options.verbose ? console.log : undefined,
    });

    this.initSchema();
  }

  /** Initialize all table schemas */
  private initSchema(): void {
    // Create model tables with Torii naming convention
    for (const model of CORE_TABLES) {
      const schema = TABLE_SCHEMAS[model].replace(
        /\{\{(\w+)\}\}/g,
        (_, name) => `${MODEL_TABLE_PREFIX}${name}`
      );
      this.db.exec(schema);
    }

    // Create events table and index
    this.db.exec(EVENT_TABLE_SCHEMA);
    this.db.exec(EVENT_INDEX);
  }

  /** Get the underlying database instance for raw queries */
  get database(): Database.Database {
    return this.db;
  }

  /**
   * Resolve table name with Torii prefix.
   * Use this in SQL templates: {{Hex}} -> dojo_starter_Hex
   */
  resolveTableName(model: CoreModel): string {
    return `${MODEL_TABLE_PREFIX}${model}`;
  }

  /**
   * Load and execute a SQL view definition file.
   * Replaces {{Model}} placeholders with actual table names.
   */
  loadView(viewPath: string): void {
    const fullPath = resolve(packageRoot, viewPath);
    let sql = readFileSync(fullPath, "utf8");

    // Replace model placeholders with prefixed table names
    sql = sql.replace(
      /\{\{(\w+)\}\}/g,
      (_, model) => `${MODEL_TABLE_PREFIX}${model}`
    );

    this.db.exec(sql);
  }

  /**
   * Seed the database with test data.
   */
  seed(data: SeedData): void {
    const transaction = this.db.transaction(() => {
      if (data.hexes) {
        this.seedHexes(data.hexes);
      }
      if (data.areas) {
        this.seedAreas(data.areas);
      }
      if (data.adventurers) {
        this.seedAdventurers(data.adventurers);
      }
      if (data.plants) {
        this.seedPlants(data.plants);
      }
      if (data.claims) {
        this.seedClaims(data.claims);
      }
      if (data.events) {
        this.seedEvents(data.events);
      }
    });

    transaction();
  }

  private seedHexes(hexes: HexSeed[]): void {
    const stmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}Hex
        (id, coordinate, biome, area_count, is_discovered, discoverer, discovered_at_block)
      VALUES
        (@id, @coordinate, @biome, @areaCount, @isDiscovered, @discoverer, @discoveredAtBlock)
    `);

    for (const hex of hexes) {
      stmt.run({
        id: `hex_${hex.coordinate}`,
        coordinate: hex.coordinate,
        biome: hex.biome,
        areaCount: hex.areaCount ?? 0,
        isDiscovered: hex.isDiscovered ? 1 : 0,
        discoverer: hex.discoverer ?? null,
        discoveredAtBlock: hex.discoveredAtBlock ?? null,
      });
    }
  }

  private seedAreas(areas: AreaSeed[]): void {
    const areaStmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}HexArea
        (id, area_id, hex_coordinate, area_index, area_type, plant_slot_count, controller, controller_set_at_block)
      VALUES
        (@id, @areaId, @hexCoordinate, @areaIndex, @areaType, @plantSlotCount, @controller, @controllerSetAtBlock)
    `);

    const ownershipStmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}AreaOwnership
        (id, area_id, owner, assigned_at_block)
      VALUES
        (@id, @areaId, @owner, @assignedAtBlock)
    `);

    for (const area of areas) {
      areaStmt.run({
        id: `area_${area.areaId}`,
        areaId: area.areaId,
        hexCoordinate: area.hexCoordinate,
        areaIndex: area.areaIndex,
        areaType: area.areaType,
        plantSlotCount: area.plantSlotCount ?? 0,
        controller: area.controller ?? null,
        controllerSetAtBlock: area.controllerSetAtBlock ?? null,
      });

      if (area.owner) {
        ownershipStmt.run({
          id: `ownership_${area.areaId}`,
          areaId: area.areaId,
          owner: area.owner,
          assignedAtBlock: area.ownerAssignedAtBlock ?? 1,
        });
      }
    }
  }

  private seedAdventurers(adventurers: AdventurerSeed[]): void {
    const stmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}Adventurer
        (id, adventurer_id, owner, name, energy, max_energy, hex_coordinate, is_alive, created_at_block)
      VALUES
        (@id, @adventurerId, @owner, @name, @energy, @maxEnergy, @hexCoordinate, @isAlive, @createdAtBlock)
    `);

    for (const adv of adventurers) {
      stmt.run({
        id: `adv_${adv.adventurerId}`,
        adventurerId: adv.adventurerId,
        owner: adv.owner,
        name: adv.name,
        energy: adv.energy ?? 100,
        maxEnergy: adv.maxEnergy ?? 100,
        hexCoordinate: adv.hexCoordinate,
        isAlive: adv.isAlive !== false ? 1 : 0,
        createdAtBlock: adv.createdAtBlock,
      });
    }
  }

  private seedPlants(plants: PlantSeed[]): void {
    const stmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}PlantNode
        (id, plant_key, hex_coordinate, area_id, plant_id, species, current_yield, max_yield, regrowth_rate, state)
      VALUES
        (@id, @plantKey, @hexCoordinate, @areaId, @plantId, @species, @currentYield, @maxYield, @regrowthRate, 0)
    `);

    for (const plant of plants) {
      stmt.run({
        id: `plant_${plant.plantKey}`,
        plantKey: plant.plantKey,
        hexCoordinate: plant.hexCoordinate,
        areaId: plant.areaId,
        plantId: plant.plantId,
        species: plant.species,
        currentYield: plant.currentYield ?? plant.maxYield,
        maxYield: plant.maxYield,
        regrowthRate: plant.regrowthRate,
      });
    }
  }

  private seedClaims(claims: ClaimSeed[]): void {
    const stmt = this.db.prepare(`
      INSERT INTO ${MODEL_TABLE_PREFIX}ClaimEscrow
        (id, hex_coordinate, claimant, energy_locked, initiated_at_block, expires_at_block, is_active)
      VALUES
        (@id, @hexCoordinate, @claimant, @energyLocked, @initiatedAtBlock, @expiresAtBlock, @isActive)
    `);

    for (const claim of claims) {
      stmt.run({
        id: `claim_${claim.hexCoordinate}_${claim.claimant}`,
        hexCoordinate: claim.hexCoordinate,
        claimant: claim.claimant,
        energyLocked: claim.energyLocked,
        initiatedAtBlock: claim.initiatedAtBlock,
        expiresAtBlock: claim.expiresAtBlock,
        isActive: claim.isActive !== false ? 1 : 0,
      });
    }
  }

  private seedEvents(events: EventSeed[]): void {
    const stmt = this.db.prepare(`
      INSERT INTO events
        (id, event_type, block_number, tx_index, event_index, data)
      VALUES
        (@id, @eventType, @blockNumber, @txIndex, @eventIndex, @data)
    `);

    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      stmt.run({
        id: `event_${i}`,
        eventType: event.eventType,
        blockNumber: event.blockNumber,
        txIndex: event.txIndex,
        eventIndex: event.eventIndex,
        data: JSON.stringify(event.data),
      });
    }
  }

  /**
   * Execute a raw SQL query and return results.
   */
  query<T = unknown>(sql: string, params?: Record<string, unknown>): T[] {
    const stmt = this.db.prepare(sql);
    return (params ? stmt.all(params) : stmt.all()) as T[];
  }

  /**
   * Execute a raw SQL query and return a single result.
   */
  queryOne<T = unknown>(
    sql: string,
    params?: Record<string, unknown>
  ): T | undefined {
    const stmt = this.db.prepare(sql);
    return (params ? stmt.get(params) : stmt.get()) as T | undefined;
  }

  /**
   * Close the database connection.
   */
  close(): void {
    this.db.close();
  }
}

/**
 * Create a fixture harness with common test seeds.
 */
export function createTestHarness(
  seeds?: SeedData,
  options?: FixtureHarnessOptions
): FixtureHarness {
  const harness = new FixtureHarness(options);
  if (seeds) {
    harness.seed(seeds);
  }
  return harness;
}
