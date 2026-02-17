import { describe, expect, it } from "vitest";
import type { HexInspectPayload } from "@gen-dungeon/explorer-types";
import { formatInspectPanelText } from "../src/inspect-format.js";

const HEX = "0x3ffffe0000100001";
const ADV = "0xadv1";
const AREA = "0xarea1";
const PROJECT = "0xproject1";
const ITEM = "0xitem1";

function inspectFixture(): HexInspectPayload {
  return {
    schemaVersion: "explorer-v1",
    headBlock: 222,
    hex: {
      coordinate: HEX,
      biome: "Forest" as never,
      is_discovered: true,
      discovery_block: 100,
      discoverer: "0xowner",
      area_count: 3
    },
    areas: [
      {
        area_id: AREA,
        hex_coordinate: HEX,
        area_index: 0,
        area_type: "Control" as never,
        is_discovered: true,
        discoverer: "0xowner",
        resource_quality: 88,
        size_category: "Medium" as never,
        plant_slot_count: 5
      }
    ] as never,
    ownership: [
      {
        area_id: AREA,
        owner_adventurer_id: ADV,
        discoverer_adventurer_id: ADV,
        discovery_block: 100,
        claim_block: 120
      }
    ] as never,
    decayState: {
      hex_coordinate: HEX,
      owner_adventurer_id: ADV,
      current_energy_reserve: 120,
      last_energy_payment_block: 210,
      last_decay_processed_block: 211,
      decay_level: 11,
      claimable_since_block: 0
    } as never,
    activeClaims: [],
    plants: [],
    activeReservations: [],
    adventurers: [
      {
        adventurer_id: ADV,
        owner: "0xowner",
        name: "0x6e616d65",
        energy: 40,
        max_energy: 100,
        current_hex: HEX,
        activity_locked_until: 250,
        is_alive: true
      }
    ] as never,
    adventurerEconomics: [
      {
        adventurer_id: ADV,
        energy_balance: 38,
        total_energy_spent: 90,
        total_energy_earned: 60,
        last_regen_block: 212
      }
    ] as never,
    inventories: [
      {
        adventurer_id: ADV,
        current_weight: 12,
        max_weight: 750
      }
    ] as never,
    backpackItems: [
      {
        adventurer_id: ADV,
        item_id: ITEM,
        quantity: 2,
        quality: 95,
        weight_per_unit: 1
      }
    ] as never,
    buildings: [
      {
        area_id: AREA,
        hex_coordinate: HEX,
        owner_adventurer_id: ADV,
        building_type: "0x3",
        tier: 1,
        condition_bp: 9800,
        upkeep_reserve: 17,
        last_upkeep_block: 215,
        is_active: true
      }
    ] as never,
    constructionProjects: [
      {
        project_id: PROJECT,
        adventurer_id: ADV,
        hex_coordinate: HEX,
        area_id: AREA,
        building_type: "0x3",
        target_tier: 2,
        start_block: 200,
        completion_block: 260,
        energy_staked: 14,
        status: "Active" as never
      }
    ] as never,
    constructionEscrows: [
      {
        project_id: PROJECT,
        item_id: ITEM,
        quantity: 4
      }
    ] as never,
    deathRecords: [],
    eventTail: []
  } as HexInspectPayload;
}

describe("inspect formatter (RED)", () => {
  it("formats placeholder when no selection payload.red", () => {
    const output = formatInspectPanelText(null);
    expect(output).toContain("No inspect payload");
  });

  it("formats core and economy/building sections.red", () => {
    const output = formatInspectPanelText(inspectFixture());
    expect(output).toContain("Hex");
    expect(output).toContain("biome");
    expect(output).toContain("Areas");
    expect(output).toContain("Ownership");
    expect(output).toContain("Decay");
    expect(output).toContain("Adventurers");
    expect(output).toContain("Economics");
    expect(output).toContain("Inventory");
    expect(output).toContain("Backpack");
    expect(output).toContain("Buildings");
    expect(output).toContain("Construction");
  });
});
