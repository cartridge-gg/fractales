import type { HexInspectPayload } from "@gen-dungeon/explorer-types";

export function formatInspectPanelText(payload: HexInspectPayload | null): string {
  if (!payload) {
    return "No inspect payload. Select a hex.";
  }

  const lines: string[] = [];
  lines.push("Hex");
  lines.push(`  coordinate: ${formatFelt(payload.hex.coordinate)}`);
  lines.push(`  biome: ${String(payload.hex.biome)}`);
  lines.push(`  discovered: ${String(payload.hex.is_discovered)}`);
  lines.push(`  area_count: ${toSafeNumber(payload.hex.area_count, 0)}`);
  lines.push(`  discoverer: ${formatFelt(payload.hex.discoverer)}`);
  lines.push(`  head_block: ${payload.headBlock}`);

  lines.push("");
  lines.push(`Areas (${payload.areas.length})`);
  for (const area of payload.areas.slice(0, 8)) {
    const areaAny = area as unknown as Record<string, unknown>;
    lines.push(
      `  idx=${toSafeNumber(areaAny.area_index, 0)} type=${String(areaAny.area_type)} quality=${toSafeNumber(areaAny.resource_quality, 0)} slots=${toSafeNumber(areaAny.plant_slot_count, 0)}`
    );
  }

  lines.push("");
  lines.push(`Ownership (${payload.ownership.length})`);
  for (const row of payload.ownership.slice(0, 8)) {
    lines.push(
      `  area=${formatFelt(row.area_id)} owner=${formatFelt(row.owner_adventurer_id)} claim_block=${toSafeNumber(row.claim_block, 0)}`
    );
  }

  lines.push("");
  lines.push("Decay");
  if (payload.decayState) {
    lines.push(`  owner: ${formatFelt(payload.decayState.owner_adventurer_id)}`);
    lines.push(`  reserve: ${toSafeNumber(payload.decayState.current_energy_reserve, 0)}`);
    lines.push(`  decay_level: ${toSafeNumber(payload.decayState.decay_level, 0)}`);
    lines.push(
      `  claimable_since: ${toSafeNumber(payload.decayState.claimable_since_block, 0)}`
    );
  } else {
    lines.push("  none");
  }

  lines.push("");
  lines.push(`Claims (${payload.activeClaims.length})`);
  for (const claim of payload.activeClaims.slice(0, 8)) {
    lines.push(
      `  claim=${formatFelt(claim.claim_id)} claimant=${formatFelt(claim.claimant_adventurer_id)} locked=${toSafeNumber(claim.energy_locked, 0)} expiry=${toSafeNumber(claim.expiry_block, 0)}`
    );
  }

  lines.push("");
  lines.push(`Plants (${payload.plants.length})`);
  for (const plant of payload.plants.slice(0, 8)) {
    lines.push(
      `  plant=${toSafeNumber(plant.plant_id, 0)} species=${formatFelt(plant.species)} yield=${toSafeNumber(plant.current_yield, 0)}/${toSafeNumber(plant.max_yield, 0)} reserved=${toSafeNumber(plant.reserved_yield, 0)}`
    );
  }

  lines.push("");
  lines.push(`Reservations (${payload.activeReservations.length})`);
  for (const reservation of payload.activeReservations.slice(0, 8)) {
    lines.push(
      `  reservation=${formatFelt(reservation.reservation_id)} adventurer=${formatFelt(reservation.adventurer_id)} amount=${toSafeNumber(reservation.reserved_amount, 0)} status=${String(reservation.status)}`
    );
  }

  lines.push("");
  lines.push(`Adventurers (${payload.adventurers.length})`);
  for (const adventurer of payload.adventurers.slice(0, 8)) {
    lines.push(
      `  id=${formatFelt(adventurer.adventurer_id)} energy=${toSafeNumber(adventurer.energy, 0)}/${toSafeNumber(adventurer.max_energy, 0)} locked_until=${toSafeNumber(adventurer.activity_locked_until, 0)} alive=${String(adventurer.is_alive)}`
    );
  }

  lines.push("");
  lines.push(`Economics (${payload.adventurerEconomics.length})`);
  for (const economics of payload.adventurerEconomics.slice(0, 8)) {
    lines.push(
      `  id=${formatFelt(economics.adventurer_id)} balance=${toSafeNumber(economics.energy_balance, 0)} spent=${toSafeNumber(economics.total_energy_spent, 0)} earned=${toSafeNumber(economics.total_energy_earned, 0)}`
    );
  }

  lines.push("");
  lines.push(`Inventory (${payload.inventories.length})`);
  for (const inventory of payload.inventories.slice(0, 8)) {
    lines.push(
      `  id=${formatFelt(inventory.adventurer_id)} weight=${toSafeNumber(inventory.current_weight, 0)}/${toSafeNumber(inventory.max_weight, 0)}`
    );
  }

  lines.push("");
  lines.push(`Backpack (${payload.backpackItems.length})`);
  for (const item of payload.backpackItems.slice(0, 8)) {
    lines.push(
      `  id=${formatFelt(item.adventurer_id)} item=${formatFelt(item.item_id)} qty=${toSafeNumber(item.quantity, 0)} quality=${toSafeNumber(item.quality, 0)}`
    );
  }

  lines.push("");
  lines.push(`Buildings (${payload.buildings.length})`);
  for (const building of payload.buildings.slice(0, 8)) {
    lines.push(
      `  area=${formatFelt(building.area_id)} type=${formatFelt(building.building_type)} tier=${toSafeNumber(building.tier, 0)} condition_bp=${toSafeNumber(building.condition_bp, 0)} active=${String(building.is_active)}`
    );
  }

  lines.push("");
  lines.push(
    `Construction (projects=${payload.constructionProjects.length}, escrows=${payload.constructionEscrows.length})`
  );
  for (const project of payload.constructionProjects.slice(0, 8)) {
    lines.push(
      `  project=${formatFelt(project.project_id)} adventurer=${formatFelt(project.adventurer_id)} tier=${toSafeNumber(project.target_tier, 0)} status=${String(project.status)}`
    );
  }
  for (const escrow of payload.constructionEscrows.slice(0, 8)) {
    lines.push(
      `  escrow project=${formatFelt(escrow.project_id)} item=${formatFelt(escrow.item_id)} qty=${toSafeNumber(escrow.quantity, 0)}`
    );
  }

  lines.push("");
  lines.push(`Deaths (${payload.deathRecords.length})`);
  for (const death of payload.deathRecords.slice(0, 8)) {
    lines.push(
      `  id=${formatFelt(death.adventurer_id)} block=${toSafeNumber(death.death_block, 0)} cause=${formatFelt(death.death_cause)}`
    );
  }

  lines.push("");
  lines.push(`Events (${payload.eventTail.length})`);
  for (const event of payload.eventTail.slice(0, 8)) {
    lines.push(
      `  ${event.blockNumber}/${event.txIndex}/${event.eventIndex} ${event.eventName}`
    );
  }

  return lines.join("\n");
}

function formatFelt(value: unknown): string {
  const normalized = String(value);
  if (normalized.length <= 22) {
    return normalized;
  }
  return `${normalized.slice(0, 10)}...${normalized.slice(-8)}`;
}

function toSafeNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.floor(value);
  }

  if (typeof value === "bigint") {
    return Number.isSafeInteger(Number(value)) ? Number(value) : fallback;
  }

  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return fallback;
    }

    try {
      if (trimmed.startsWith("0x") || trimmed.startsWith("-0x")) {
        const parsed = BigInt(trimmed);
        const asNumber = Number(parsed);
        return Number.isSafeInteger(asNumber) ? asNumber : fallback;
      }
      const parsed = Number(trimmed);
      return Number.isFinite(parsed) ? Math.floor(parsed) : fallback;
    } catch {
      return fallback;
    }
  }

  return fallback;
}
