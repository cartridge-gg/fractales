export interface SqlHarness {
  getViewColumns(viewName: string): string[];
  select<T>(sql: string): T[];
}

export function createSeededToriiSqlHarness(): SqlHarness {
  const seeded = seedTables();
  const views = buildViews(seeded);

  return {
    getViewColumns(viewName: string) {
      const rows = views.get(viewName);
      if (!rows || rows.length === 0) {
        return [];
      }
      const first = rows[0] as Record<string, unknown>;
      return Object.keys(first);
    },
    select<T>(sql: string) {
      return executeSelect<T>(views, sql);
    }
  };
}

interface SeededTables {
  hexes: Array<{
    coordinate: string;
    biome: string;
    is_discovered: number;
    discovery_block: number;
    discoverer: string;
    area_count: number;
  }>;
  areas: Array<{
    area_id: string;
    hex_coordinate: string;
    area_index: number;
    area_type: string;
    is_discovered: number;
  }>;
  ownership: Array<{
    area_id: string;
    owner_adventurer_id: string;
    claim_block: number;
  }>;
  decay: Array<{
    hex_coordinate: string;
    owner_adventurer_id: string;
    current_energy_reserve: number;
    last_decay_processed_block: number;
    decay_level: number;
    claimable_since_block: number;
  }>;
  claims: Array<{
    claim_id: string;
    hex_coordinate: string;
    claimant_adventurer_id: string;
    energy_locked: number;
    created_block: number;
    expiry_block: number;
    status: number;
  }>;
  adventurers: Array<{
    adventurer_id: string;
    owner: string;
    is_alive: number;
    current_hex: string;
    energy: number;
    activity_locked_until: number;
  }>;
  plants: Array<{
    plant_key: string;
    hex_coordinate: string;
    area_id: string;
    plant_id: string;
    species: string;
    current_yield: number;
    reserved_yield: number;
    max_yield: number;
    regrowth_rate: number;
    stress_level: number;
    health: number;
  }>;
  reservations: Array<{
    reservation_id: string;
    adventurer_id: string;
    plant_key: string;
    reserved_amount: number;
    created_block: number;
    expiry_block: number;
    status: number;
  }>;
  events: Array<{
    block_number: number;
    tx_index: number;
    event_index: number;
    event_name: string;
    hex_coordinate: string;
    adventurer_id: string;
    payload_json: string;
  }>;
}

function seedTables(): SeededTables {
  return {
    hexes: [
      { coordinate: "0x1", biome: "Plains", is_discovered: 1, discovery_block: 10, discoverer: "0xabc", area_count: 2 },
      { coordinate: "0x2", biome: "Forest", is_discovered: 0, discovery_block: 0, discoverer: "0x0", area_count: 0 },
      { coordinate: "0x3", biome: "Desert", is_discovered: 1, discovery_block: 12, discoverer: "0xdef", area_count: 2 }
    ],
    areas: [
      { area_id: "area-1", hex_coordinate: "0x1", area_index: 0, area_type: "Control", is_discovered: 1 },
      { area_id: "area-2", hex_coordinate: "0x1", area_index: 1, area_type: "Harvest", is_discovered: 1 },
      { area_id: "area-3", hex_coordinate: "0x3", area_index: 0, area_type: "Control", is_discovered: 1 },
      { area_id: "area-4", hex_coordinate: "0x3", area_index: 1, area_type: "Harvest", is_discovered: 1 }
    ],
    ownership: [
      { area_id: "area-1", owner_adventurer_id: "adv-owner-a", claim_block: 10 },
      { area_id: "area-2", owner_adventurer_id: "adv-owner-a", claim_block: 10 },
      { area_id: "area-3", owner_adventurer_id: "adv-owner-b", claim_block: 12 },
      { area_id: "area-4", owner_adventurer_id: "adv-owner-c", claim_block: 12 }
    ],
    decay: [
      { hex_coordinate: "0x1", owner_adventurer_id: "adv-owner-a", current_energy_reserve: 120, last_decay_processed_block: 10, decay_level: 40, claimable_since_block: 0 },
      { hex_coordinate: "0x3", owner_adventurer_id: "adv-owner-b", current_energy_reserve: 80, last_decay_processed_block: 12, decay_level: 85, claimable_since_block: 12 }
    ],
    claims: [
      { claim_id: "claim-active", hex_coordinate: "0x1", claimant_adventurer_id: "adv-claimer", energy_locked: 25, created_block: 15, expiry_block: 25, status: 1 },
      { claim_id: "claim-closed", hex_coordinate: "0x1", claimant_adventurer_id: "adv-claimer", energy_locked: 30, created_block: 16, expiry_block: 26, status: 2 }
    ],
    adventurers: [
      { adventurer_id: "adv-owner-a", owner: "0xaaa", is_alive: 1, current_hex: "0x1", energy: 40, activity_locked_until: 0 },
      { adventurer_id: "adv-owner-b", owner: "0xbbb", is_alive: 1, current_hex: "0x3", energy: 30, activity_locked_until: 0 },
      { adventurer_id: "adv-owner-c", owner: "0xccc", is_alive: 1, current_hex: "0x3", energy: 20, activity_locked_until: 0 }
    ],
    plants: [
      {
        plant_key: "plant-1",
        hex_coordinate: "0x1",
        area_id: "area-2",
        plant_id: "plant-a",
        species: "berry",
        current_yield: 10,
        reserved_yield: 2,
        max_yield: 20,
        regrowth_rate: 3,
        stress_level: 1,
        health: 100
      }
    ],
    reservations: [
      {
        reservation_id: "res-1",
        adventurer_id: "adv-owner-a",
        plant_key: "plant-1",
        reserved_amount: 2,
        created_block: 13,
        expiry_block: 16,
        status: 1
      }
    ],
    events: [
      { block_number: 10, tx_index: 0, event_index: 0, event_name: "HexDiscovered", hex_coordinate: "0x1", adventurer_id: "adv-owner-a", payload_json: "{}" },
      { block_number: 12, tx_index: 0, event_index: 0, event_name: "HexBecameClaimable", hex_coordinate: "0x3", adventurer_id: "adv-owner-b", payload_json: "{}" },
      { block_number: 11, tx_index: 1, event_index: 0, event_name: "ClaimInitiated", hex_coordinate: "0x1", adventurer_id: "adv-claimer", payload_json: "{}" },
      { block_number: 11, tx_index: 0, event_index: 1, event_name: "HexEnergyPaid", hex_coordinate: "0x1", adventurer_id: "adv-owner-a", payload_json: "{}" }
    ]
  };
}

function buildViews(seed: SeededTables): Map<string, Record<string, unknown>[]> {
  const viewRows = new Map<string, Record<string, unknown>[]>();

  const decayByHex = new Map(seed.decay.map((row) => [row.hex_coordinate, row]));
  const areasByHex = groupBy(seed.areas, (row) => row.hex_coordinate);
  const ownershipByArea = new Map(seed.ownership.map((row) => [row.area_id, row]));
  const plantsByHex = groupBy(seed.plants, (row) => row.hex_coordinate);
  const activeClaims = seed.claims.filter((claim) => claim.status === 1);
  const activeClaimsByHex = groupBy(activeClaims, (row) => row.hex_coordinate);
  const adventurersByHex = groupBy(seed.adventurers, (row) => row.current_hex);
  const reservationsByPlant = groupBy(seed.reservations, (row) => row.plant_key);

  const hexBase = seed.hexes
    .filter((hex) => hex.is_discovered === 1)
    .map((hex) => {
      const decay = decayByHex.get(hex.coordinate);
      return {
        hex_coordinate: hex.coordinate,
        biome: hex.biome,
        discovery_block: hex.discovery_block,
        discoverer: hex.discoverer,
        area_count: hex.area_count,
        decay_level: decay?.decay_level ?? 0,
        current_energy_reserve: decay?.current_energy_reserve ?? 0,
        last_decay_processed_block: decay?.last_decay_processed_block ?? 0,
        owner_adventurer_id: decay?.owner_adventurer_id ?? null
      };
    });
  viewRows.set("explorer_hex_base_v1", hexBase);

  const areaControl = Array.from(areasByHex.entries())
    .filter(([, areas]) => areas.some((area) => area.is_discovered === 1))
    .map(([hexCoordinate, areas]) => {
      const owners = areas
        .map((area) => ownershipByArea.get(area.area_id)?.owner_adventurer_id)
        .filter((owner): owner is string => !!owner);
      return {
        hex_coordinate: hexCoordinate,
        control_area_id: areas[0]?.area_id ?? null,
        controller_adventurer_id: owners[0] ?? null,
        area_count: areas.length,
        ownership_consistent: new Set(owners).size <= 1 ? 1 : 0
      };
    });
  viewRows.set("explorer_area_control_v1", areaControl);

  const claimActive = activeClaims.map((claim) => ({
    hex_coordinate: claim.hex_coordinate,
    claim_id: claim.claim_id,
    claimant_adventurer_id: claim.claimant_adventurer_id,
    energy_locked: claim.energy_locked,
    created_block: claim.created_block,
    expiry_block: claim.expiry_block
  }));
  viewRows.set("explorer_claim_active_v1", claimActive);

  const adventurerPresence = seed.adventurers.map((adv) => ({
    adventurer_id: adv.adventurer_id,
    owner: adv.owner,
    is_alive: adv.is_alive,
    current_hex: adv.current_hex,
    energy: adv.energy,
    activity_locked_until: adv.activity_locked_until
  }));
  viewRows.set("explorer_adventurer_presence_v1", adventurerPresence);

  const plantStatus = seed.plants.map((plant) => ({
    plant_key: plant.plant_key,
    hex_coordinate: plant.hex_coordinate,
    area_id: plant.area_id,
    plant_id: plant.plant_id,
    species: plant.species,
    current_yield: plant.current_yield,
    reserved_yield: plant.reserved_yield,
    max_yield: plant.max_yield,
    regrowth_rate: plant.regrowth_rate,
    stress_level: plant.stress_level,
    health: plant.health
  }));
  viewRows.set("explorer_plant_status_v1", plantStatus);

  const eventTail = [...seed.events].sort((a, b) => {
    if (a.block_number !== b.block_number) {
      return b.block_number - a.block_number;
    }
    if (a.tx_index !== b.tx_index) {
      return b.tx_index - a.tx_index;
    }
    return b.event_index - a.event_index;
  });
  viewRows.set("explorer_event_tail_v1", eventTail);

  const areaControlByHex = new Map(areaControl.map((row) => [row.hex_coordinate, row]));
  const renderRows = seed.hexes
    .filter((hex) => hex.is_discovered === 1)
    .map((hex) => {
      const control = areaControlByHex.get(hex.coordinate);
      const decay = decayByHex.get(hex.coordinate);
      return {
        hex_coordinate: hex.coordinate,
        biome: hex.biome,
        owner_adventurer_id: control?.controller_adventurer_id ?? null,
        decay_level: decay?.decay_level ?? 0,
        is_claimable: (decay?.decay_level ?? 0) >= 80 ? 1 : 0,
        active_claim_count: activeClaimsByHex.get(hex.coordinate)?.length ?? 0,
        adventurer_count: adventurersByHex.get(hex.coordinate)?.length ?? 0,
        plant_count: plantsByHex.get(hex.coordinate)?.length ?? 0
      };
    });
  viewRows.set("explorer_hex_render_v1", renderRows);

  const inspectRows = seed.hexes
    .filter((hex) => hex.is_discovered === 1)
    .map((hex) => {
      const decay = decayByHex.get(hex.coordinate);
      const area = areasByHex.get(hex.coordinate)?.[0];
      const ownership = area ? ownershipByArea.get(area.area_id) : undefined;
      const plant = plantsByHex.get(hex.coordinate)?.[0];
      const reservation = plant ? reservationsByPlant.get(plant.plant_key)?.[0] : undefined;
      const claim = activeClaimsByHex.get(hex.coordinate)?.[0];
      const adventurer = adventurersByHex.get(hex.coordinate)?.[0];

      return {
        hex_coordinate: hex.coordinate,
        biome: hex.biome,
        discovery_block: hex.discovery_block,
        discoverer: hex.discoverer,
        area_count: hex.area_count,
        area_id: area?.area_id ?? null,
        area_index: area?.area_index ?? null,
        area_type: area?.area_type ?? null,
        area_discovered: area?.is_discovered ?? null,
        owner_adventurer_id: ownership?.owner_adventurer_id ?? decay?.owner_adventurer_id ?? null,
        claim_block: ownership?.claim_block ?? null,
        current_energy_reserve: decay?.current_energy_reserve ?? null,
        decay_level: decay?.decay_level ?? null,
        last_decay_processed_block: decay?.last_decay_processed_block ?? null,
        claimable_since_block: decay?.claimable_since_block ?? null,
        claim_id: claim?.claim_id ?? null,
        claimant_adventurer_id: claim?.claimant_adventurer_id ?? null,
        energy_locked: claim?.energy_locked ?? null,
        claim_created_block: claim?.created_block ?? null,
        claim_expiry_block: claim?.expiry_block ?? null,
        claim_status: claim?.status ?? null,
        plant_key: plant?.plant_key ?? null,
        plant_area_id: plant?.area_id ?? null,
        plant_id: plant?.plant_id ?? null,
        species: plant?.species ?? null,
        current_yield: plant?.current_yield ?? null,
        reserved_yield: plant?.reserved_yield ?? null,
        max_yield: plant?.max_yield ?? null,
        regrowth_rate: plant?.regrowth_rate ?? null,
        health: plant?.health ?? null,
        stress_level: plant?.stress_level ?? null,
        reservation_id: reservation?.reservation_id ?? null,
        reservation_adventurer_id: reservation?.adventurer_id ?? null,
        reserved_amount: reservation?.reserved_amount ?? null,
        reservation_created_block: reservation?.created_block ?? null,
        reservation_expiry_block: reservation?.expiry_block ?? null,
        reservation_status: reservation?.status ?? null,
        adventurer_id: adventurer?.adventurer_id ?? null,
        adventurer_owner: adventurer?.owner ?? null,
        current_hex: adventurer?.current_hex ?? null,
        adventurer_energy: adventurer?.energy ?? null,
        is_alive: adventurer?.is_alive ?? null
      };
    });
  viewRows.set("explorer_hex_inspect_v1", inspectRows);

  return viewRows;
}

function executeSelect<T>(views: Map<string, Record<string, unknown>[]>, sql: string): T[] {
  const parsed = parseSimpleSelect(sql);
  if (!parsed) {
    throw new Error(`unsupported harness SQL: ${sql}`);
  }

  const rows = views.get(parsed.from) ?? [];
  const projected = rows.map((row) => {
    const next: Record<string, unknown> = {};
    for (const field of parsed.fields) {
      next[field] = row[field];
    }
    return next;
  });

  if (parsed.orderBy.length > 0) {
    projected.sort((a, b) => compareOrderBy(a, b, parsed.orderBy));
  }

  return projected as T[];
}

function parseSimpleSelect(sql: string): { fields: string[]; from: string; orderBy: string[] } | null {
  const compact = sql.replace(/\s+/g, " ").trim();
  const match = compact.match(/^SELECT (.+) FROM ([a-zA-Z0-9_]+)(?: ORDER BY (.+))?$/i);
  if (!match) {
    return null;
  }

  const fieldsPart = match[1];
  const from = match[2];
  if (!fieldsPart || !from) {
    return null;
  }

  const fields = fieldsPart
    .split(",")
    .map((field) => field.trim())
    .filter((field) => field.length > 0);
  const orderBy = (match[3] ?? "")
    .split(",")
    .map((field) => field.trim().replace(/\s+(ASC|DESC)$/i, ""))
    .filter((field) => field.length > 0);

  return { fields, from, orderBy };
}

function compareOrderBy(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
  fields: string[]
): number {
  for (const field of fields) {
    const left = a[field];
    const right = b[field];
    if (left === right) {
      continue;
    }
    if (left === undefined) {
      return -1;
    }
    if (right === undefined) {
      return 1;
    }
    if (typeof left === "number" && typeof right === "number") {
      return left - right;
    }
    return String(left).localeCompare(String(right));
  }
  return 0;
}

function groupBy<T>(rows: T[], key: (row: T) => string): Map<string, T[]> {
  const grouped = new Map<string, T[]>();
  for (const row of rows) {
    const rowKey = key(row);
    const bucket = grouped.get(rowKey) ?? [];
    bucket.push(row);
    grouped.set(rowKey, bucket);
  }
  return grouped;
}
