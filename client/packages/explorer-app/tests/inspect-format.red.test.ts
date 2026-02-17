import { describe, expect, it } from "vitest";
import type { HexInspectPayload } from "@gen-dungeon/explorer-types";
import { renderInspectPanelHtml } from "../src/inspect-format.js";

const HEX = "0x3ffffe0000100001";
const ADV = "0xadv1";
const ADV_2 = "0xadv2";
const AREA = "0xarea1";
const AREA_2 = "0xarea2";
const PROJECT = "0xproject1";
const ITEM = "0xitem1";
const MINE_KEY = "0xmine1";
const PLANT_KEY = "0xplant1";

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
    plants: [
      {
        plant_key: PLANT_KEY,
        hex_coordinate: HEX,
        area_id: AREA,
        plant_id: 7,
        species: "0xspecies1",
        current_yield: 12,
        reserved_yield: 4,
        max_yield: 30,
        regrowth_rate: 2,
        health: 95,
        stress_level: 3,
        genetics_hash: "0xgene1",
        last_harvest_block: 221,
        discoverer: "0xowner"
      }
    ] as never,
    activeReservations: [
      {
        reservation_id: "0xres1",
        adventurer_id: ADV,
        plant_key: PLANT_KEY,
        reserved_amount: 3,
        created_block: 220,
        expiry_block: 280,
        status: "Active" as never
      }
    ] as never,
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
      },
      {
        adventurer_id: ADV_2,
        owner: "0xowner2",
        name: "0x6e616d6532",
        energy: 30,
        max_energy: 90,
        current_hex: HEX,
        activity_locked_until: 200,
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
      },
      {
        adventurer_id: ADV_2,
        energy_balance: 30,
        total_energy_spent: 44,
        total_energy_earned: 20,
        last_regen_block: 209
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
    mineNodes: [
      {
        mine_key: MINE_KEY,
        hex_coordinate: HEX,
        area_id: AREA_2,
        mine_id: 1,
        ore_id: "0xore1",
        rarity_tier: 2,
        depth_tier: 1,
        richness_bp: 7700,
        remaining_reserve: 80,
        base_stress_per_block: 2,
        collapse_threshold: 100,
        mine_stress: 30,
        safe_shift_blocks: 15,
        active_miners: 1,
        last_update_block: 220,
        collapsed_until_block: 0,
        repair_energy_needed: 0,
        is_depleted: false,
        active_head_shift_id: "0xshift1",
        active_tail_shift_id: "0xshift1",
        biome_risk_bp: 300,
        rarity_risk_bp: 600,
        base_tick_energy: 2,
        ore_energy_weight: 1,
        conversion_energy_per_unit: 2
      }
    ] as never,
    miningShifts: [
      {
        shift_id: "0xshift1",
        adventurer_id: ADV_2,
        mine_key: MINE_KEY,
        status: "Active" as never,
        start_block: 219,
        last_settle_block: 221,
        accrued_ore_unbanked: 11,
        accrued_stabilization_work: 1,
        prev_active_shift_id: "0x0",
        next_active_shift_id: "0x0"
      }
    ] as never,
    mineAccessGrants: [
      {
        mine_key: MINE_KEY,
        grantee_adventurer_id: ADV_2,
        is_allowed: true,
        granted_by_adventurer_id: ADV,
        grant_block: 218,
        revoked_block: 0
      }
    ] as never,
    mineCollapseRecords: [],
    eventTail: [
      {
        blockNumber: 220,
        txIndex: 0,
        eventIndex: 1,
        eventName: "MiningStarted",
        payloadJson: "{}"
      },
      {
        blockNumber: 221,
        txIndex: 2,
        eventIndex: 0,
        eventName: "HarvestingCompleted",
        payloadJson: "{}"
      },
      {
        blockNumber: 219,
        txIndex: 1,
        eventIndex: 0,
        eventName: "ClaimStarted",
        payloadJson: "{}"
      }
    ]
  } as HexInspectPayload;
}

function denseInspectFixture(rowCount = 10): HexInspectPayload {
  const payload = inspectFixture();
  payload.areas = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.areas[0] as unknown as Record<string, unknown>),
    area_id: `0xarea${index.toString(16)}`,
    area_index: index
  })) as never;
  payload.ownership = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.ownership[0] as unknown as Record<string, unknown>),
    area_id: `0xarea${index.toString(16)}`,
    owner_adventurer_id: `0xowner${index.toString(16)}`
  })) as never;
  payload.plants = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.plants[0] as unknown as Record<string, unknown>),
    plant_key: `0xplant${index.toString(16)}`,
    area_id: `0xarea${index.toString(16)}`,
    plant_id: index
  })) as never;
  payload.activeReservations = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.activeReservations[0] as unknown as Record<string, unknown>),
    reservation_id: `0xres${index.toString(16)}`,
    adventurer_id: `0xadv${index.toString(16)}`,
    plant_key: `0xplant${index.toString(16)}`
  })) as never;
  payload.adventurers = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.adventurers[0] as unknown as Record<string, unknown>),
    adventurer_id: `0xadv${index.toString(16)}`
  })) as never;
  payload.adventurerEconomics = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.adventurerEconomics[0] as unknown as Record<string, unknown>),
    adventurer_id: `0xadv${index.toString(16)}`
  })) as never;
  payload.inventories = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.inventories[0] as unknown as Record<string, unknown>),
    adventurer_id: `0xadv${index.toString(16)}`
  })) as never;
  payload.backpackItems = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.backpackItems[0] as unknown as Record<string, unknown>),
    adventurer_id: `0xadv${index.toString(16)}`,
    item_id: `0xitem${index.toString(16)}`
  })) as never;
  payload.buildings = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.buildings[0] as unknown as Record<string, unknown>),
    area_id: `0xarea${index.toString(16)}`
  })) as never;
  payload.constructionProjects = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.constructionProjects[0] as unknown as Record<string, unknown>),
    project_id: `0xproject${index.toString(16)}`,
    adventurer_id: `0xadv${index.toString(16)}`
  })) as never;
  payload.constructionEscrows = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.constructionEscrows[0] as unknown as Record<string, unknown>),
    project_id: `0xproject${index.toString(16)}`,
    item_id: `0xescrow${index.toString(16)}`
  })) as never;
  payload.deathRecords = Array.from({ length: rowCount }, (_, index) => ({
    adventurer_id: `0xdead${index.toString(16)}`,
    death_block: 300 + index,
    death_cause: `0xcause${index.toString(16)}`
  })) as never;
  payload.mineNodes = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.mineNodes[0] as unknown as Record<string, unknown>),
    mine_key: `0xmine${index.toString(16)}`,
    area_id: `0xarea${index.toString(16)}`,
    mine_id: index
  })) as never;
  payload.miningShifts = Array.from({ length: rowCount }, (_, index) => ({
    ...(payload.miningShifts[0] as unknown as Record<string, unknown>),
    shift_id: `0xshift${index.toString(16)}`,
    adventurer_id: `0xadv${index.toString(16)}`,
    mine_key: `0xmine${index.toString(16)}`,
    status: "Active"
  })) as never;
  payload.eventTail = Array.from({ length: rowCount }, (_, index) => ({
    blockNumber: 400 + index,
    txIndex: 0,
    eventIndex: 0,
    eventName: "MiningStarted",
    payloadJson: `{\"idx\":${index}}`
  }));
  return payload;
}

describe("inspect formatter (RED)", () => {
  it("renders placeholder shell when no selection payload.red", () => {
    const output = renderInspectPanelHtml(null);
    expect(output).toContain("inspect-empty");
    expect(output).toContain("Select a discovered hex");
  });

  it("renders readable section cards and tables.red", () => {
    const output = renderInspectPanelHtml(inspectFixture());
    expect(output).toContain("inspect-hero");
    expect(output).toContain("inspect-badge biome");
    expect(output).toContain("inspect-card");
    expect(output).toContain("<h3>Operations Summary</h3>");
    expect(output).toContain("<h3>Area Slots</h3>");
    expect(output).toContain("<h3>Mine Operations</h3>");
    expect(output).toContain("<h3>Adventurer Assignments</h3>");
    expect(output).toContain("<h3>Production Feed</h3>");
    expect(output).toContain("<h3>Areas");
    expect(output).toContain("<h3>Ownership");
    expect(output).toContain("<h3>Decay");
    expect(output).toContain("<h3>Adventurers");
    expect(output).toContain("<h3>Economics");
    expect(output).toContain("<h3>Inventory");
    expect(output).toContain("<h3>Backpack");
    expect(output).toContain("<h3>Construction");
    expect(output).toContain("inspect-table");
    expect(output).toContain("title=");
  });

  it("renders event tail rows in inspect table.red", () => {
    const payload = inspectFixture();
    payload.eventTail = [
      {
        blockNumber: 222,
        txIndex: 1,
        eventIndex: 0,
        eventName: "ClaimStarted",
        payloadJson: "{}"
      },
      {
        blockNumber: 223,
        txIndex: 0,
        eventIndex: 4,
        eventName: "ClaimDefended",
        payloadJson: "{}"
      }
    ];

    const output = renderInspectPanelHtml(payload);
    expect(output).toContain("<h3>Events (2)</h3>");
    expect(output).toContain("222/1/0");
    expect(output).toContain("ClaimStarted");
    expect(output).toContain("223/0/4");
    expect(output).toContain("ClaimDefended");
  });

  it("supports compact/full mode and exposes raw field names in full.red", () => {
    const payload = inspectFixture();
    const compact = renderInspectPanelHtml(payload, { mode: "compact" });
    const full = renderInspectPanelHtml(payload, { mode: "full" });

    expect(compact).not.toContain("Hex Raw Fields");
    expect(full).toContain("Hex Raw Fields");
    expect(full).toContain("last_energy_payment_block");
    expect(full).toContain("weight_per_unit");
    expect(full.length).toBeGreaterThan(compact.length);
  });

  it("renders operation details and deterministic production ordering.red", () => {
    const output = renderInspectPanelHtml(inspectFixture(), { mode: "compact" });

    expect(output).toContain("Active Harvest");
    expect(output).toContain("Active Mining");
    expect(output).toContain("Unbanked Ore");
    expect(output).toContain("harvesting");
    expect(output).toContain("mining");
    expect(output).toContain("0xmine1");
    expect(output).toContain("active");

    const harvestIndex = output.indexOf("HarvestingCompleted");
    const miningIndex = output.indexOf("MiningStarted");
    expect(harvestIndex).toBeGreaterThan(-1);
    expect(miningIndex).toBeGreaterThan(-1);
    expect(harvestIndex).toBeLessThan(miningIndex);
  });

  it("escapes dynamic values in operations cards.red", () => {
    const payload = inspectFixture();
    payload.mineNodes = [
      {
        ...(payload.mineNodes[0] as unknown as Record<string, unknown>),
        mine_key: "0xmine<script>alert(1)</script>",
        ore_id: "0xore\"bad\""
      }
    ] as never;
    payload.eventTail = [
      {
        blockNumber: 300,
        txIndex: 1,
        eventIndex: 2,
        eventName: "MiningStarted",
        payloadJson: "{\"k\":\"<tag>\"}"
      }
    ];

    const output = renderInspectPanelHtml(payload, { mode: "compact" });
    expect(output).not.toContain("<script>");
    expect(output).toContain("&lt;script&gt;");
    expect(output).toContain("&quot;");
  });

  it("caps_dense_sections_and_surfaces_truncation_notices.red", () => {
    const output = renderInspectPanelHtml(denseInspectFixture(10), { mode: "compact" });
    const noticeCount = (output.match(/Showing 8 of 10 rows\./g) ?? []).length;

    expect(output).toContain("Showing 8 of 10 rows.");
    expect(noticeCount).toBeGreaterThanOrEqual(8);
    expect(output).not.toContain("0xmine8");
    expect(output).not.toContain("0xproject8");
  });
});
