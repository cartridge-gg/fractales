import { describe, expect, it } from "vitest";
import {
  LiveToriiProxyClient,
  buildChunkSnapshotsFromToriiRows,
  chunkKeyForHexCoordinate,
  decodeCubeCoordinate,
  type ToriiAdventurerRow,
  type ToriiAreaOwnershipRow,
  type ToriiClaimEscrowRow,
  type ToriiHexAreaRow,
  type ToriiHexDecayRow,
  type ToriiHexRow,
  type ToriiPlantRow
} from "../src/live-runtime.js";

const HEX_A = "0x3ffffe0000100001";
const HEX_B = "0x40000200002fffff";
const AREA_A_CONTROL = "0xaaa";
const AREA_B_CONTROL = "0xbbb";

describe("live runtime mapping (RED)", () => {
  it("decode_cube_coordinate_roundtrip_known_live_hex.red", () => {
    expect(decodeCubeCoordinate(HEX_A)).toEqual({ x: -1, y: 0, z: 1 });
    expect(chunkKeyForHexCoordinate(HEX_A)).toBe("-1:1");

    expect(decodeCubeCoordinate("0x3ffffd0000200003")).toBeNull();
    expect(chunkKeyForHexCoordinate("0x3ffffd0000200003")).toBeNull();
  });

  it("builds_chunk_rows_from_live_torii_models.red", () => {
    const hexes: ToriiHexRow[] = [
      {
        coordinate: HEX_A,
        biome: "Forest",
        is_discovered: true,
        discovery_block: "0xaa",
        discoverer: "0xowner-a",
        area_count: 3
      },
      {
        coordinate: HEX_B,
        biome: "Desert",
        is_discovered: true,
        discovery_block: "0xab",
        discoverer: "0xowner-b",
        area_count: 2
      }
    ];

    const areas: ToriiHexAreaRow[] = [
      {
        area_id: AREA_A_CONTROL,
        hex_coordinate: HEX_A,
        area_index: 0,
        area_type: "Control",
        is_discovered: true,
        discoverer: "0xowner-a",
        resource_quality: 42,
        size_category: "Medium",
        plant_slot_count: 5
      },
      {
        area_id: "0xa1",
        hex_coordinate: HEX_A,
        area_index: 1,
        area_type: "PlantField",
        is_discovered: true,
        discoverer: "0xowner-a",
        resource_quality: 55,
        size_category: "Small",
        plant_slot_count: 4
      },
      {
        area_id: AREA_B_CONTROL,
        hex_coordinate: HEX_B,
        area_index: 0,
        area_type: "Control",
        is_discovered: true,
        discoverer: "0xowner-b",
        resource_quality: 77,
        size_category: "Large",
        plant_slot_count: 7
      }
    ];

    const ownership: ToriiAreaOwnershipRow[] = [
      {
        area_id: AREA_A_CONTROL,
        owner_adventurer_id: "0xadv-a",
        discoverer_adventurer_id: "0xadv-a",
        discovery_block: "0xaa",
        claim_block: "0xaa"
      },
      {
        area_id: AREA_B_CONTROL,
        owner_adventurer_id: "0xadv-b",
        discoverer_adventurer_id: "0xadv-b",
        discovery_block: "0xab",
        claim_block: "0xab"
      }
    ];

    const decay: ToriiHexDecayRow[] = [
      {
        hex_coordinate: HEX_A,
        owner_adventurer_id: "0xadv-a",
        current_energy_reserve: 100,
        last_energy_payment_block: "0xb0",
        last_decay_processed_block: "0xb0",
        decay_level: 81,
        claimable_since_block: "0xb0"
      }
    ];

    const claims: ToriiClaimEscrowRow[] = [
      {
        claim_id: "0xclaim-active",
        hex_coordinate: HEX_A,
        claimant_adventurer_id: "0xadv-c",
        energy_locked: 20,
        created_block: "0xb1",
        expiry_block: "0xb8",
        status: "Active"
      },
      {
        claim_id: "0xclaim-completed",
        hex_coordinate: HEX_A,
        claimant_adventurer_id: "0xadv-c",
        energy_locked: 20,
        created_block: "0xb1",
        expiry_block: "0xb8",
        status: "Completed"
      }
    ];

    const adventurers: ToriiAdventurerRow[] = [
      {
        adventurer_id: "0xadv-a",
        owner: "0xowner-a",
        name: "0x1",
        energy: 40,
        max_energy: 100,
        current_hex: HEX_A,
        activity_locked_until: 0,
        is_alive: true
      },
      {
        adventurer_id: "0xadv-z",
        owner: "0xowner-z",
        name: "0x2",
        energy: 10,
        max_energy: 100,
        current_hex: HEX_A,
        activity_locked_until: 0,
        is_alive: true
      }
    ];

    const plants: ToriiPlantRow[] = [
      {
        plant_key: "0xplant-a",
        hex_coordinate: HEX_A,
        area_id: AREA_A_CONTROL,
        plant_id: 0,
        species: "0x10",
        current_yield: 10,
        reserved_yield: 0,
        max_yield: 12,
        regrowth_rate: 3,
        health: 90,
        stress_level: 4,
        genetics_hash: "0xgen",
        last_harvest_block: "0x90",
        discoverer: "0xowner-a"
      }
    ];

    const chunks = buildChunkSnapshotsFromToriiRows(
      {
        hexes,
        areas,
        ownership,
        decay,
        claims,
        adventurers,
        plants
      },
      {
        chunkSize: 1,
        headBlock: 172
      }
    );

    expect(chunks).toHaveLength(2);

    const chunkA = chunks.find((entry) => entry.chunk.key === "-1:1");
    expect(chunkA).toBeDefined();
    expect(chunkA?.hexes).toEqual([
      {
        hexCoordinate: HEX_A,
        biome: "Forest",
        ownerAdventurerId: "0xadv-a",
        decayLevel: 81,
        isClaimable: true,
        activeClaimCount: 1,
        adventurerCount: 2,
        plantCount: 1
      }
    ]);

    const chunkB = chunks.find((entry) => entry.chunk.key === "0:-1");
    expect(chunkB).toBeDefined();
    expect(chunkB?.hexes).toEqual([
      {
        hexCoordinate: HEX_B,
        biome: "Desert",
        ownerAdventurerId: "0xadv-b",
        decayLevel: 0,
        isClaimable: false,
        activeClaimCount: 0,
        adventurerCount: 0,
        plantCount: 0
      }
    ]);
  });

  it("live_inspect_payload_includes_economy_inventory_buildings.red", async () => {
    const fetchImpl: typeof fetch = async (_input, init) => {
      const parsed = JSON.parse(String(init?.body ?? "{}")) as { query?: string };
      expect(parsed.query).toContain("plant_slot_count");
      expect(parsed.query).toContain("dojoStarterAdventurerEconomicsModels");
      expect(parsed.query).toContain("dojoStarterInventoryModels");
      expect(parsed.query).toContain("dojoStarterBackpackItemModels");
      expect(parsed.query).toContain("dojoStarterConstructionBuildingNodeModels");

      return new Response(
        JSON.stringify({
          data: {
            dojoStarterHexModels: {
              edges: [
                {
                  node: {
                    coordinate: HEX_A,
                    biome: "Forest",
                    is_discovered: true,
                    discovery_block: "0xaa",
                    discoverer: "0xowner-a",
                    area_count: 3
                  }
                }
              ]
            },
            dojoStarterHexAreaModels: {
              edges: [
                {
                  node: {
                    area_id: AREA_A_CONTROL,
                    hex_coordinate: HEX_A,
                    area_index: 0,
                    area_type: "Control",
                    is_discovered: true,
                    discoverer: "0xowner-a",
                    resource_quality: 42,
                    size_category: "Medium",
                    plant_slot_count: 5
                  }
                }
              ]
            },
            dojoStarterAreaOwnershipModels: {
              edges: [
                {
                  node: {
                    area_id: AREA_A_CONTROL,
                    owner_adventurer_id: "0xadv-a",
                    discoverer_adventurer_id: "0xadv-a",
                    discovery_block: "0xaa",
                    claim_block: "0xab"
                  }
                }
              ]
            },
            dojoStarterHexDecayStateModels: {
              edges: [
                {
                  node: {
                    hex_coordinate: HEX_A,
                    owner_adventurer_id: "0xadv-a",
                    current_energy_reserve: 100,
                    last_energy_payment_block: "0xb0",
                    last_decay_processed_block: "0xb0",
                    decay_level: 10,
                    claimable_since_block: "0x0"
                  }
                }
              ]
            },
            dojoStarterClaimEscrowModels: { edges: [] },
            dojoStarterPlantNodeModels: { edges: [] },
            dojoStarterHarvestReservationModels: { edges: [] },
            dojoStarterAdventurerModels: {
              edges: [
                {
                  node: {
                    adventurer_id: "0xadv-a",
                    owner: "0xowner-a",
                    name: "0x1",
                    energy: 40,
                    max_energy: 100,
                    current_hex: HEX_A,
                    activity_locked_until: 0,
                    is_alive: true
                  }
                }
              ]
            },
            dojoStarterAdventurerEconomicsModels: {
              edges: [
                {
                  node: {
                    adventurer_id: "0xadv-a",
                    energy_balance: 39,
                    total_energy_spent: 11,
                    total_energy_earned: 9,
                    last_regen_block: 120
                  }
                }
              ]
            },
            dojoStarterInventoryModels: {
              edges: [
                {
                  node: {
                    adventurer_id: "0xadv-a",
                    current_weight: 5,
                    max_weight: 750
                  }
                }
              ]
            },
            dojoStarterBackpackItemModels: {
              edges: [
                {
                  node: {
                    adventurer_id: "0xadv-a",
                    item_id: "0xitem-a",
                    quantity: 2,
                    quality: 99,
                    weight_per_unit: 1
                  }
                }
              ]
            },
            dojoStarterDeathRecordModels: { edges: [] },
            dojoStarterConstructionBuildingNodeModels: {
              edges: [
                {
                  node: {
                    area_id: AREA_A_CONTROL,
                    hex_coordinate: HEX_A,
                    owner_adventurer_id: "0xadv-a",
                    building_type: "0x1",
                    tier: 1,
                    condition_bp: 9500,
                    upkeep_reserve: 10,
                    last_upkeep_block: 111,
                    is_active: true
                  }
                }
              ]
            },
            dojoStarterConstructionProjectModels: {
              edges: [
                {
                  node: {
                    project_id: "0xproject-a",
                    adventurer_id: "0xadv-a",
                    hex_coordinate: HEX_A,
                    area_id: AREA_A_CONTROL,
                    building_type: "0x1",
                    target_tier: 2,
                    start_block: 100,
                    completion_block: 140,
                    energy_staked: 12,
                    status: "Active"
                  }
                }
              ]
            },
            dojoStarterConstructionMaterialEscrowModels: {
              edges: [
                {
                  node: {
                    project_id: "0xproject-a",
                    item_id: "0xitem-a",
                    quantity: 3
                  }
                }
              ]
            }
          }
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json"
          }
        }
      );
    };

    const proxy = new LiveToriiProxyClient({
      toriiGraphqlUrl: "https://example.test/torii/graphql",
      cacheTtlMs: 0,
      pollIntervalMs: 1_000,
      chunkSize: 1,
      queryLimit: 50,
      fetchImpl
    });

    const inspect = await proxy.getHexInspect(HEX_A);
    expect((inspect.areas[0] as unknown as Record<string, unknown>)?.plant_slot_count).toBe(5);
    expect((inspect as unknown as Record<string, unknown>).adventurerEconomics).toHaveLength(1);
    expect((inspect as unknown as Record<string, unknown>).inventories).toHaveLength(1);
    expect((inspect as unknown as Record<string, unknown>).backpackItems).toHaveLength(1);
    expect((inspect as unknown as Record<string, unknown>).buildings).toHaveLength(1);
    expect((inspect as unknown as Record<string, unknown>).constructionProjects).toHaveLength(1);
    expect((inspect as unknown as Record<string, unknown>).constructionEscrows).toHaveLength(1);
  });
});
