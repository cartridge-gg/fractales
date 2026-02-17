import { describe, expect, it } from "vitest";
import type {
  ChunkSnapshot,
  HexInspectPayload,
  StreamPatchEnvelope
} from "@gen-dungeon/explorer-types";
import {
  LiveProxyHttpClient,
  LiveToriiProxyClient,
  buildChunkSnapshotsFromToriiRows,
  createLiveToriiRuntime,
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
import { LiveWebglRendererAdapter } from "../src/live-webgl-renderer.js";

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

  it("uses canonical claimable_since_block for claimability.red", () => {
    const chunks = buildChunkSnapshotsFromToriiRows(
      {
        hexes: [
          {
            coordinate: HEX_A,
            biome: "Forest",
            is_discovered: true,
            discovery_block: 1,
            discoverer: "0xowner-a",
            area_count: 1
          },
          {
            coordinate: HEX_B,
            biome: "Desert",
            is_discovered: true,
            discovery_block: 1,
            discoverer: "0xowner-b",
            area_count: 1
          }
        ],
        areas: [],
        ownership: [],
        claims: [],
        adventurers: [],
        plants: [],
        decay: [
          {
            hex_coordinate: HEX_A,
            owner_adventurer_id: "0xadv-a",
            current_energy_reserve: 100,
            last_energy_payment_block: 20,
            last_decay_processed_block: 20,
            decay_level: 99,
            claimable_since_block: 0
          },
          {
            hex_coordinate: HEX_B,
            owner_adventurer_id: "0xadv-b",
            current_energy_reserve: 100,
            last_energy_payment_block: 20,
            last_decay_processed_block: 20,
            decay_level: 5,
            claimable_since_block: 7
          }
        ]
      },
      { chunkSize: 1, headBlock: 25 }
    );

    const byCoord = new Map(
      chunks.flatMap((chunk) => chunk.hexes.map((hex) => [hex.hexCoordinate, hex.isClaimable]))
    );
    expect(byCoord.get(HEX_A)).toBe(false);
    expect(byCoord.get(HEX_B)).toBe(true);
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

describe("live proxy transport (RED)", () => {
  it("loads chunks from /v1/chunks.red", async () => {
    const calls: string[] = [];
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      calls.push(url);
      if (url.startsWith("https://proxy.example.test/v1/chunks?")) {
        return jsonResponse({
          schemaVersion: "explorer-v1",
          chunks: [
            {
              schemaVersion: "explorer-v1",
              chunk: { key: "0:0", chunkQ: 0, chunkR: 0 },
              headBlock: 99,
              hexes: []
            }
          ]
        });
      }
      throw new Error(`unexpected url ${url}`);
    };

    const proxy = new LiveProxyHttpClient({
      proxyOrigin: "https://proxy.example.test",
      fetchImpl,
      cacheTtlMs: 2_500,
      maxChunkKeys: 64
    });

    const chunks = await proxy.getChunks(["0:0"]);
    expect(chunks).toHaveLength(1);
    expect(chunks[0]?.headBlock).toBe(99);
    expect(calls).toEqual(["https://proxy.example.test/v1/chunks?keys=0%3A0"]);
  });

  it("subscribes via /v1/status then /v1/stream.red", async () => {
    const calls: string[] = [];
    const sockets: FakeProxyWebSocket[] = [];
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      calls.push(url);
      if (url === "https://proxy.example.test/v1/status") {
        return jsonResponse({
          schemaVersion: "explorer-v1",
          headBlock: 120,
          lastSequence: 44,
          streamLagMs: 0
        });
      }
      throw new Error(`unexpected url ${url}`);
    };

    const proxy = new LiveProxyHttpClient({
      proxyOrigin: "https://proxy.example.test",
      fetchImpl,
      cacheTtlMs: 2_500,
      maxChunkKeys: 64,
      webSocketFactory: (url) => {
        const socket = new FakeProxyWebSocket(url);
        sockets.push(socket);
        return socket;
      }
    });

    const statuses: string[] = [];
    const patches: StreamPatchEnvelope[] = [];
    const errors: Error[] = [];
    const subscription = proxy.subscribePatches({
      onPatch: (patch) => patches.push(patch),
      onStatus: (status) => statuses.push(status),
      onError: (error) => errors.push(error)
    });

    try {
      await waitFor(() => sockets.length === 1);
      const socket = sockets[0];
      expect(socket?.url).toBe("wss://proxy.example.test/v1/stream");

      socket?.emitOpen();
      socket?.emitMessage(
        JSON.stringify({
          schemaVersion: "explorer-v1",
          sequence: 45,
          blockNumber: 121,
          txIndex: 1,
          eventIndex: 0,
          kind: "hex_patch",
          payload: { hexCoordinate: HEX_A },
          emittedAtMs: 1700000000000
        })
      );

      expect(calls).toEqual(["https://proxy.example.test/v1/status"]);
      expect(statuses).toEqual(["catching_up", "live"]);
      expect(patches).toHaveLength(1);
      expect(errors).toEqual([]);
      expect(patches[0]?.sequence).toBe(45);
    } finally {
      subscription.close();
    }
  });

  it("caches chunk responses within ttl and refreshes after expiry.red", async () => {
    let now = 1_000;
    const calls: string[] = [];
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      calls.push(url);
      if (url.startsWith("https://proxy.example.test/v1/chunks?")) {
        return jsonResponse({
          schemaVersion: "explorer-v1",
          chunks: [
            {
              schemaVersion: "explorer-v1",
              chunk: { key: "0:0", chunkQ: 0, chunkR: 0 },
              headBlock: 100,
              hexes: []
            }
          ]
        });
      }
      throw new Error(`unexpected url ${url}`);
    };

    const proxy = new LiveProxyHttpClient({
      proxyOrigin: "https://proxy.example.test",
      fetchImpl,
      cacheTtlMs: 50,
      maxChunkKeys: 64,
      nowMs: () => now
    });

    await proxy.getChunks(["0:0"]);
    await proxy.getChunks(["0:0"]);
    now += 51;
    await proxy.getChunks(["0:0"]);

    expect(calls).toEqual([
      "https://proxy.example.test/v1/chunks?keys=0%3A0",
      "https://proxy.example.test/v1/chunks?keys=0%3A0"
    ]);
  });

  it("hydrates inspect payload with proxy event tail rows.red", async () => {
    const baseInspect = makeProxyInspectPayload(HEX_A);
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      if (url === `https://proxy.example.test/v1/hex/${encodeURIComponent(HEX_A)}`) {
        return jsonResponse({
          ...baseInspect,
          eventTail: [
            {
              blockNumber: 100,
              txIndex: 0,
              eventIndex: 0,
              eventName: "ClaimStarted",
              payloadJson: "{}"
            },
            {
              blockNumber: 101,
              txIndex: 2,
              eventIndex: 1,
              eventName: "ClaimDefended",
              payloadJson: "{}"
            }
          ]
        });
      }
      throw new Error(`unexpected url ${url}`);
    };

    const proxy = new LiveProxyHttpClient({
      proxyOrigin: "https://proxy.example.test",
      fetchImpl,
      cacheTtlMs: 2_500,
      maxChunkKeys: 64
    });

    const inspect = await proxy.getHexInspect(HEX_A);
    expect(inspect.eventTail).toHaveLength(2);
    expect(inspect.eventTail[0]?.eventName).toBe("ClaimStarted");
    expect(inspect.eventTail[1]?.eventName).toBe("ClaimDefended");
  });
});

describe("live selector budgets (RED)", () => {
  it("scales chunk keys with viewport size and keeps hard bounds.red", () => {
    const runtime = createLiveToriiRuntime(createCanvasStub(), {
      proxyOrigin: "https://proxy.example.test",
      fetchImpl: async () => jsonResponse({ schemaVersion: "explorer-v1", chunks: [] })
    });
    const selectors = runtime.dependencies.selectors;

    const small = selectors.visibleChunkKeys({
      center: { x: 0, y: 0 },
      width: 390,
      height: 844,
      zoom: 1
    });
    const large = selectors.visibleChunkKeys({
      center: { x: 0, y: 0 },
      width: 2560,
      height: 1440,
      zoom: 1
    });

    expect(new Set(small).size).toBe(small.length);
    expect(new Set(large).size).toBe(large.length);
    expect(large.length).toBeGreaterThan(small.length);
    expect(large.length).toBeLessThanOrEqual(49);
  });
});

describe("live renderer binding (RED)", () => {
  it("uses webgl renderer adapter in live runtime and applies patch deltas.red", () => {
    const runtime = createLiveToriiRuntime(createCanvasStub(), {
      proxyOrigin: "https://proxy.example.test",
      fetchImpl: async () => jsonResponse({ schemaVersion: "explorer-v1", chunks: [] })
    });
    expect(runtime.renderer).toBeInstanceOf(LiveWebglRendererAdapter);

    runtime.renderer.replaceChunks([makeChunk("0:0", "Forest")]);
    const adapter = runtime.renderer as LiveWebglRendererAdapter;
    const before = adapter.getDebugSceneSnapshot();

    runtime.renderer.applyPatch({
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
          biome: "Desert",
          ownerAdventurerId: null,
          decayLevel: 0,
          isClaimable: false,
          activeClaimCount: 0,
          adventurerCount: 0,
          plantCount: 0
        }
      },
      emittedAtMs: 1
    });
    const after = adapter.getDebugSceneSnapshot();

    expect(after).not.toEqual(before);
    expect(adapter.getDebugRenderSet().renderChunkKeys).toContain("0:0");
  });
});

describe("live store patch reducer (RED)", () => {
  it("applies chunk_snapshot and hex_patch deterministically.red", () => {
    const runtime = createLiveToriiRuntime(createCanvasStub(), {
      proxyOrigin: "https://proxy.example.test",
      fetchImpl: async () => jsonResponse({ schemaVersion: "explorer-v1", chunks: [] })
    });
    const store = runtime.dependencies.store;
    store.replaceChunks([makeChunk("0:0", "Forest")]);

    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 1,
      blockNumber: 101,
      txIndex: 0,
      eventIndex: 0,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: makeHex("Desert")
      },
      emittedAtMs: 1
    });
    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 2,
      blockNumber: 102,
      txIndex: 0,
      eventIndex: 1,
      kind: "chunk_snapshot",
      payload: makeChunk("1:0", "Swamp"),
      emittedAtMs: 2
    });

    const snapshot = store.snapshot();
    expect(snapshot.status).toBe("live");
    expect(snapshot.loadedChunks.map((chunk) => chunk.chunk.key)).toEqual(["0:0", "1:0"]);
    expect(snapshot.loadedChunks[0]?.hexes[0]?.biome).toBe("Desert");
    expect(snapshot.loadedChunks[1]?.hexes[0]?.biome).toBe("Swamp");
  });

  it("ignores duplicate and stale patch sequences.red", () => {
    const runtime = createLiveToriiRuntime(createCanvasStub(), {
      proxyOrigin: "https://proxy.example.test",
      fetchImpl: async () => jsonResponse({ schemaVersion: "explorer-v1", chunks: [] })
    });
    const store = runtime.dependencies.store;
    store.replaceChunks([makeChunk("0:0", "Forest")]);

    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 7,
      blockNumber: 107,
      txIndex: 0,
      eventIndex: 0,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: makeHex("Desert")
      },
      emittedAtMs: 7
    });
    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 7,
      blockNumber: 108,
      txIndex: 0,
      eventIndex: 1,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: makeHex("Swamp")
      },
      emittedAtMs: 8
    });
    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 6,
      blockNumber: 109,
      txIndex: 0,
      eventIndex: 2,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: makeHex("Highlands")
      },
      emittedAtMs: 9
    });

    const chunk = store.snapshot().loadedChunks[0];
    expect(chunk?.hexes[0]?.biome).toBe("Desert");
  });

  it("enters catching_up on resync and returns live after chunk replace.red", () => {
    const runtime = createLiveToriiRuntime(createCanvasStub(), {
      proxyOrigin: "https://proxy.example.test",
      fetchImpl: async () => jsonResponse({ schemaVersion: "explorer-v1", chunks: [] })
    });
    const store = runtime.dependencies.store;
    store.replaceChunks([makeChunk("0:0", "Forest")]);

    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 10,
      blockNumber: 110,
      txIndex: 0,
      eventIndex: 0,
      kind: "resync_required",
      payload: {
        expectedSourceSequence: 10,
        receivedSourceSequence: 13
      },
      emittedAtMs: 10
    });
    expect(store.snapshot().status).toBe("catching_up");

    store.applyPatch({
      schemaVersion: "explorer-v1",
      sequence: 11,
      blockNumber: 111,
      txIndex: 0,
      eventIndex: 1,
      kind: "hex_patch",
      payload: {
        chunkKey: "0:0",
        hex: makeHex("Swamp")
      },
      emittedAtMs: 11
    });
    expect(store.snapshot().loadedChunks[0]?.hexes[0]?.biome).toBe("Forest");

    store.replaceChunks([makeChunk("0:0", "Taiga")]);
    expect(store.snapshot().status).toBe("live");
    expect(store.snapshot().loadedChunks[0]?.hexes[0]?.biome).toBe("Taiga");
  });
});

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      "content-type": "application/json"
    }
  });
}

class FakeProxyWebSocket {
  readonly url: string;
  readyState = 0;
  closed = false;

  private readonly listeners: {
    open: Set<() => void>;
    close: Set<() => void>;
    message: Set<(event: { data: unknown }) => void>;
    error: Set<(event: { error?: unknown; message?: string }) => void>;
  } = {
    open: new Set(),
    close: new Set(),
    message: new Set(),
    error: new Set()
  };

  constructor(url: string) {
    this.url = url;
  }

  addEventListener(type: "open", listener: () => void): void;
  addEventListener(type: "close", listener: () => void): void;
  addEventListener(type: "message", listener: (event: { data: unknown }) => void): void;
  addEventListener(
    type: "error",
    listener: (event: { error?: unknown; message?: string }) => void
  ): void;
  addEventListener(
    type: "open" | "close" | "message" | "error",
    listener:
      | (() => void)
      | ((event: { data: unknown }) => void)
      | ((event: { error?: unknown; message?: string }) => void)
  ): void {
    this.listeners[type].add(listener as never);
  }

  removeEventListener(type: "open", listener: () => void): void;
  removeEventListener(type: "close", listener: () => void): void;
  removeEventListener(type: "message", listener: (event: { data: unknown }) => void): void;
  removeEventListener(
    type: "error",
    listener: (event: { error?: unknown; message?: string }) => void
  ): void;
  removeEventListener(
    type: "open" | "close" | "message" | "error",
    listener:
      | (() => void)
      | ((event: { data: unknown }) => void)
      | ((event: { error?: unknown; message?: string }) => void)
  ): void {
    this.listeners[type].delete(listener as never);
  }

  close(): void {
    this.closed = true;
    this.readyState = 3;
    for (const listener of this.listeners.close) {
      listener();
    }
  }

  emitOpen(): void {
    this.readyState = 1;
    for (const listener of this.listeners.open) {
      listener();
    }
  }

  emitMessage(data: unknown): void {
    for (const listener of this.listeners.message) {
      listener({ data });
    }
  }
}

async function waitFor(predicate: () => boolean, timeoutMs = 1_000): Promise<void> {
  const started = Date.now();
  while (Date.now() - started <= timeoutMs) {
    if (predicate()) {
      return;
    }
    await Promise.resolve();
  }
  throw new Error("waitFor timeout");
}

function makeProxyInspectPayload(hexCoordinate: string): HexInspectPayload {
  return {
    schemaVersion: "explorer-v1",
    headBlock: 120,
    hex: {
      coordinate: hexCoordinate,
      biome: "Forest" as never,
      is_discovered: true,
      discovery_block: 110,
      discoverer: "0xowner",
      area_count: 2
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
    mineNodes: [],
    miningShifts: [],
    mineAccessGrants: [],
    mineCollapseRecords: [],
    deathRecords: [],
    eventTail: []
  } as HexInspectPayload;
}

function makeChunk(key: `${number}:${number}`, biome: string): ChunkSnapshot {
  const [chunkQ, chunkR] = key.split(":").map((value) => Number.parseInt(value, 10));
  return {
    schemaVersion: "explorer-v1",
    chunk: {
      key,
      chunkQ: chunkQ ?? 0,
      chunkR: chunkR ?? 0
    },
    headBlock: 100,
    hexes: [makeHex(biome)]
  };
}

function makeHex(biome: string): ChunkSnapshot["hexes"][number] {
  return {
    hexCoordinate: HEX_A,
    biome,
    ownerAdventurerId: null,
    decayLevel: 0,
    isClaimable: false,
    activeClaimCount: 0,
    adventurerCount: 0,
    plantCount: 0
  };
}

function createCanvasStub(): HTMLCanvasElement {
  return {
    addEventListener() {},
    removeEventListener() {},
    getContext() {
      return null;
    },
    style: {},
    width: 0,
    height: 0
  } as unknown as HTMLCanvasElement;
}
