/**
 * Basic World Seed Data
 *
 * A minimal but complete world state for testing view queries.
 * Includes discovered and undiscovered hexes, areas, adventurers,
 * plants, claims, and event timelines.
 */

import type { SeedData } from "../harness.js";

/** Origin hex coordinate (encoded cube 0,0,0) */
export const ORIGIN_HEX = "0x4000020000100000";

/** Adjacent hex (cube 1,-1,0) */
export const ADJACENT_HEX = "0x400005fffff00000";

/** Undiscovered hex coordinate */
export const UNDISCOVERED_HEX = "0x400009ffffe00002";

/** Test owner address */
export const OWNER_ALICE = "0xalice";
export const OWNER_BOB = "0xbob";

/** Test adventurer IDs */
export const ADVENTURER_JOYSTICK = "0xadv_joystick";
export const ADVENTURER_WARRIOR = "0xadv_warrior";

/** Test area IDs */
export const AREA_ORIGIN_CONTROL = "0xarea_origin_control";
export const AREA_ADJACENT_PLANT = "0xarea_adjacent_plant";

/** Test plant key */
export const PLANT_DATEP = "0xplant_datep_0";

/**
 * Basic world seed with:
 * - 2 discovered hexes (origin + adjacent)
 * - 1 undiscovered hex
 * - 2 areas (control + plant field)
 * - 2 adventurers
 * - 1 plant node
 * - 1 active claim
 * - Timeline of discovery events
 */
export const basicWorldSeed: SeedData = {
  hexes: [
    {
      coordinate: ORIGIN_HEX,
      biome: "Grassland",
      areaCount: 2,
      isDiscovered: true,
      discoverer: OWNER_ALICE,
      discoveredAtBlock: 100,
    },
    {
      coordinate: ADJACENT_HEX,
      biome: "Oasis",
      areaCount: 3,
      isDiscovered: true,
      discoverer: OWNER_ALICE,
      discoveredAtBlock: 105,
    },
    {
      coordinate: UNDISCOVERED_HEX,
      biome: "Desert",
      areaCount: 2,
      isDiscovered: false,
    },
  ],

  areas: [
    {
      areaId: AREA_ORIGIN_CONTROL,
      hexCoordinate: ORIGIN_HEX,
      areaIndex: 0,
      areaType: "Control",
      plantSlotCount: 0,
      controller: OWNER_ALICE,
      controllerSetAtBlock: 100,
      owner: OWNER_ALICE,
      ownerAssignedAtBlock: 100,
    },
    {
      areaId: AREA_ADJACENT_PLANT,
      hexCoordinate: ADJACENT_HEX,
      areaIndex: 1,
      areaType: "PlantField",
      plantSlotCount: 6,
      controller: OWNER_ALICE,
      controllerSetAtBlock: 110,
      owner: OWNER_ALICE,
      ownerAssignedAtBlock: 110,
    },
  ],

  adventurers: [
    {
      adventurerId: ADVENTURER_JOYSTICK,
      owner: OWNER_ALICE,
      name: "Joystick",
      energy: 85,
      maxEnergy: 100,
      hexCoordinate: ADJACENT_HEX,
      isAlive: true,
      createdAtBlock: 100,
    },
    {
      adventurerId: ADVENTURER_WARRIOR,
      owner: OWNER_BOB,
      name: "Warrior",
      energy: 100,
      maxEnergy: 100,
      hexCoordinate: ORIGIN_HEX,
      isAlive: true,
      createdAtBlock: 120,
    },
  ],

  plants: [
    {
      plantKey: PLANT_DATEP,
      hexCoordinate: ADJACENT_HEX,
      areaId: AREA_ADJACENT_PLANT,
      plantId: 0,
      species: "DATEP",
      currentYield: 45,
      maxYield: 61,
      regrowthRate: 2,
    },
  ],

  claims: [
    {
      hexCoordinate: ORIGIN_HEX,
      claimant: OWNER_BOB,
      energyLocked: 50,
      initiatedAtBlock: 150,
      expiresAtBlock: 250,
      isActive: true,
    },
  ],

  events: [
    {
      eventType: "HexDiscovered",
      blockNumber: 100,
      txIndex: 0,
      eventIndex: 0,
      data: { coordinate: ORIGIN_HEX, discoverer: OWNER_ALICE },
    },
    {
      eventType: "AdventurerCreated",
      blockNumber: 100,
      txIndex: 1,
      eventIndex: 0,
      data: { adventurer_id: ADVENTURER_JOYSTICK, owner: OWNER_ALICE },
    },
    {
      eventType: "HexDiscovered",
      blockNumber: 105,
      txIndex: 0,
      eventIndex: 0,
      data: { coordinate: ADJACENT_HEX, discoverer: OWNER_ALICE },
    },
    {
      eventType: "AreaDiscovered",
      blockNumber: 110,
      txIndex: 0,
      eventIndex: 0,
      data: { area_id: AREA_ADJACENT_PLANT, area_type: "PlantField" },
    },
    {
      eventType: "AdventurerCreated",
      blockNumber: 120,
      txIndex: 0,
      eventIndex: 0,
      data: { adventurer_id: ADVENTURER_WARRIOR, owner: OWNER_BOB },
    },
    {
      eventType: "ClaimInitiated",
      blockNumber: 150,
      txIndex: 0,
      eventIndex: 0,
      data: { hex_coordinate: ORIGIN_HEX, claimant: OWNER_BOB },
    },
  ],
};

/**
 * Seed with multiple hexes for chunk/render testing.
 * 10 discovered hexes in a grid pattern.
 */
export const multiHexSeed: SeedData = {
  hexes: Array.from({ length: 10 }, (_, i) => ({
    coordinate: `0x40000${i}0000100000`,
    biome: ["Grassland", "Oasis", "Desert", "Forest", "Tundra"][i % 5],
    areaCount: 2,
    isDiscovered: true,
    discoverer: OWNER_ALICE,
    discoveredAtBlock: 100 + i,
  })),
};

/**
 * Seed with expired and active claims for claim filtering tests.
 */
export const claimsSeed: SeedData = {
  hexes: [
    {
      coordinate: ORIGIN_HEX,
      biome: "Grassland",
      isDiscovered: true,
      discoverer: OWNER_ALICE,
      discoveredAtBlock: 100,
    },
    {
      coordinate: ADJACENT_HEX,
      biome: "Oasis",
      isDiscovered: true,
      discoverer: OWNER_BOB,
      discoveredAtBlock: 100,
    },
  ],
  claims: [
    // Active claim (expires in future)
    {
      hexCoordinate: ORIGIN_HEX,
      claimant: OWNER_BOB,
      energyLocked: 50,
      initiatedAtBlock: 100,
      expiresAtBlock: 999999, // Far future
      isActive: true,
    },
    // Expired claim (should be filtered out)
    {
      hexCoordinate: ADJACENT_HEX,
      claimant: OWNER_ALICE,
      energyLocked: 30,
      initiatedAtBlock: 50,
      expiresAtBlock: 100, // Already expired
      isActive: false,
    },
  ],
};

/**
 * Seed with event ordering scenarios.
 * Multiple events at same block with different tx/event indices.
 */
export const eventOrderingSeed: SeedData = {
  events: [
    // Block 100, tx 0
    { eventType: "A", blockNumber: 100, txIndex: 0, eventIndex: 0, data: {} },
    { eventType: "B", blockNumber: 100, txIndex: 0, eventIndex: 1, data: {} },
    // Block 100, tx 1
    { eventType: "C", blockNumber: 100, txIndex: 1, eventIndex: 0, data: {} },
    // Block 101
    { eventType: "D", blockNumber: 101, txIndex: 0, eventIndex: 0, data: {} },
    // Block 99 (earlier, should come first when sorted)
    { eventType: "E", blockNumber: 99, txIndex: 0, eventIndex: 0, data: {} },
  ],
};
