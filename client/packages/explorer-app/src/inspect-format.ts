import type { HexInspectPayload } from "@gen-dungeon/explorer-types";

const MAX_ROWS_PER_SECTION = 8;

export type InspectDetailMode = "compact" | "full";

export interface RenderInspectPanelOptions {
  mode?: InspectDetailMode;
}

export function renderInspectPanelHtml(
  payload: HexInspectPayload | null,
  options: RenderInspectPanelOptions = {}
): string {
  if (!payload) {
    return [
      '<section class="inspect-empty">',
      "<h3>No Selection</h3>",
      "<p>Select a discovered hex to load full inspect details.</p>",
      "</section>"
    ].join("");
  }

  const compact = [
    renderHero(payload),
    renderOperationsSummaryCard(payload),
    renderAreaSlotsCard(payload),
    renderMineOperationsCard(payload),
    renderAdventurerAssignmentsCard(payload),
    renderProductionFeedCard(payload),
    renderAreasCard(payload),
    renderOwnershipCard(payload),
    renderDecayCard(payload),
    renderClaimsCard(payload),
    renderPlantsCard(payload),
    renderReservationsCard(payload),
    renderAdventurersCard(payload),
    renderEconomicsCard(payload),
    renderInventoryCard(payload),
    renderBackpackCard(payload),
    renderBuildingsCard(payload),
    renderConstructionCard(payload),
    renderDeathsCard(payload),
    renderEventsCard(payload)
  ].join("");

  if (options.mode === "full") {
    return [compact, renderRawPayloadCards(payload)].join("");
  }

  return compact;
}

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

function renderHero(payload: HexInspectPayload): string {
  const discoveredClass = payload.hex.is_discovered ? "is-yes" : "is-no";
  return [
    '<section class="inspect-hero">',
    '<div class="inspect-hero-grid">',
    `<div class="inspect-hero-item"><span class="inspect-k">Hex</span>${renderFelt(payload.hex.coordinate)}</div>`,
    `<div class="inspect-hero-item"><span class="inspect-k">Head Block</span>${renderNumber(payload.headBlock)}</div>`,
    `<div class="inspect-hero-item"><span class="inspect-k">Discoverer</span>${renderFelt(payload.hex.discoverer)}</div>`,
    `<div class="inspect-hero-item"><span class="inspect-k">Area Count</span>${renderNumber(payload.hex.area_count)}</div>`,
    "</div>",
    '<div class="inspect-badges">',
    `<span class="inspect-badge biome">Biome: ${escapeHtml(formatValue(payload.hex.biome))}</span>`,
    `<span class="inspect-badge discovered ${discoveredClass}">Discovered: ${escapeHtml(formatValue(payload.hex.is_discovered))}</span>`,
    "</div>",
    "</section>"
  ].join("");
}

function renderOperationsSummaryCard(payload: HexInspectPayload): string {
  const activeReservations = payload.activeReservations.filter((row) => isActiveEnumStatus(row.status));
  const activeMiningShifts = payload.miningShifts.filter((row) => isActiveEnumStatus(row.status));
  const collapsedOrDepletedCount = payload.mineNodes.filter((mine) => {
    const collapsed =
      toSafeNumber(mine.repair_energy_needed, 0) > 0 ||
      toSafeNumber(mine.collapsed_until_block, 0) > toSafeNumber(payload.headBlock, 0);
    return collapsed || isTrueValue(mine.is_depleted);
  }).length;
  const unbankedOre = activeMiningShifts.reduce((sum, row) => {
    return sum + toSafeNumber(row.accrued_ore_unbanked, 0);
  }, 0);

  return renderCard(
    "Operations Summary",
    renderTable(
      ["Metric", "Value"],
      [
        ["Adventurers", renderNumber(payload.adventurers.length)],
        ["Active Harvest", renderNumber(activeReservations.length)],
        ["Active Mining", renderNumber(activeMiningShifts.length)],
        ["Initialized Mines", renderNumber(payload.mineNodes.length)],
        ["Collapsed/Depleted", renderNumber(collapsedOrDepletedCount)],
        ["Unbanked Ore", renderNumber(unbankedOre)]
      ]
    )
  );
}

function renderAreaSlotsCard(payload: HexInspectPayload): string {
  const areaRows = [...payload.areas].sort(compareAreaRows);
  const plantByKey = new Map<string, HexInspectPayload["plants"][number]>();
  const mineByKey = new Map<string, HexInspectPayload["mineNodes"][number]>();
  const plantCountByArea = new Map<string, number>();
  const mineCountByArea = new Map<string, number>();
  const activeWorkersByArea = new Map<string, Set<string>>();

  for (const plant of payload.plants) {
    const plantKey = normalizeKey(plant.plant_key);
    const areaKey = normalizeKey(plant.area_id);
    plantByKey.set(plantKey, plant);
    plantCountByArea.set(areaKey, (plantCountByArea.get(areaKey) ?? 0) + 1);
  }

  for (const mine of payload.mineNodes) {
    const mineKey = normalizeKey(mine.mine_key);
    const areaKey = normalizeKey(mine.area_id);
    mineByKey.set(mineKey, mine);
    mineCountByArea.set(areaKey, (mineCountByArea.get(areaKey) ?? 0) + 1);
  }

  for (const reservation of payload.activeReservations) {
    if (!isActiveEnumStatus(reservation.status)) {
      continue;
    }
    const plant = plantByKey.get(normalizeKey(reservation.plant_key));
    if (!plant) {
      continue;
    }
    const areaKey = normalizeKey(plant.area_id);
    const workers = activeWorkersByArea.get(areaKey) ?? new Set<string>();
    workers.add(normalizeKey(reservation.adventurer_id));
    activeWorkersByArea.set(areaKey, workers);
  }

  for (const shift of payload.miningShifts) {
    if (!isActiveEnumStatus(shift.status)) {
      continue;
    }
    const mine = mineByKey.get(normalizeKey(shift.mine_key));
    if (!mine) {
      continue;
    }
    const areaKey = normalizeKey(mine.area_id);
    const workers = activeWorkersByArea.get(areaKey) ?? new Set<string>();
    workers.add(normalizeKey(shift.adventurer_id));
    activeWorkersByArea.set(areaKey, workers);
  }

  const rows = areaRows.map((area) => {
    const areaAny = area as unknown as Record<string, unknown>;
    const areaKey = normalizeKey(area.area_id);
    const initializedPlants = plantCountByArea.get(areaKey) ?? 0;
    const initializedMines = mineCountByArea.get(areaKey) ?? 0;
    const activeWorkers = activeWorkersByArea.get(areaKey)?.size ?? 0;

    return [
      renderNumber(areaAny.area_index),
      escapeHtml(formatValue(areaAny.area_type)),
      `${renderNumber(initializedPlants)}/${renderNumber(areaAny.plant_slot_count)}`,
      renderNumber(initializedMines),
      renderNumber(activeWorkers)
    ];
  });

  return renderCard(
    "Area Slots",
    [
      renderTable(["Area", "Type", "Plants", "Mines", "Workers"], rows.slice(0, MAX_ROWS_PER_SECTION)),
      renderTruncationNote(rows.length)
    ].join("")
  );
}

function renderMineOperationsCard(payload: HexInspectPayload): string {
  const activeShiftCountByMine = new Map<string, number>();
  for (const shift of payload.miningShifts) {
    if (!isActiveEnumStatus(shift.status)) {
      continue;
    }
    const mineKey = normalizeKey(shift.mine_key);
    activeShiftCountByMine.set(mineKey, (activeShiftCountByMine.get(mineKey) ?? 0) + 1);
  }

  const sortedMines = [...payload.mineNodes].sort(compareMineRows);
  const rows = sortedMines.map((mine) => {
    const mineKey = normalizeKey(mine.mine_key);
    const activeShiftCount = activeShiftCountByMine.get(mineKey) ?? 0;
    const status = deriveMineStatus(mine, activeShiftCount, payload.headBlock);

    return [
      renderFelt(mine.mine_key),
      renderFelt(mine.area_id),
      escapeHtml(status),
      renderNumber(Math.max(activeShiftCount, toSafeNumber(mine.active_miners, 0))),
      renderNumber(mine.remaining_reserve),
      `${renderNumber(mine.mine_stress)}/${renderNumber(mine.collapse_threshold)}`,
      renderNumber(mine.repair_energy_needed)
    ];
  });

  const content =
    rows.length === 0
      ? '<p class="inspect-muted">No mine operations in this hex.</p>'
      : [
          renderTable(
            ["Mine", "Area", "Status", "Miners", "Reserve", "Stress", "Repair"],
            rows.slice(0, MAX_ROWS_PER_SECTION)
          ),
          renderTruncationNote(rows.length)
        ].join("");

  return renderCard("Mine Operations", content);
}

function renderAdventurerAssignmentsCard(payload: HexInspectPayload): string {
  const adventurerById = new Map<string, HexInspectPayload["adventurers"][number]>();
  const economicsById = new Map<string, HexInspectPayload["adventurerEconomics"][number]>();
  const activeReservationByAdventurer = new Map<string, HexInspectPayload["activeReservations"][number]>();
  const activeShiftByAdventurer = new Map<string, HexInspectPayload["miningShifts"][number]>();
  const relevantAdventurerIds = new Set<string>();

  for (const adventurer of payload.adventurers) {
    const key = normalizeKey(adventurer.adventurer_id);
    adventurerById.set(key, adventurer);
    relevantAdventurerIds.add(key);
  }

  for (const economics of payload.adventurerEconomics) {
    const key = normalizeKey(economics.adventurer_id);
    economicsById.set(key, economics);
    relevantAdventurerIds.add(key);
  }

  for (const reservation of payload.activeReservations) {
    if (!isActiveEnumStatus(reservation.status)) {
      continue;
    }
    const key = normalizeKey(reservation.adventurer_id);
    activeReservationByAdventurer.set(key, reservation);
    relevantAdventurerIds.add(key);
  }

  for (const shift of payload.miningShifts) {
    if (!isActiveEnumStatus(shift.status)) {
      continue;
    }
    const key = normalizeKey(shift.adventurer_id);
    activeShiftByAdventurer.set(key, shift);
    relevantAdventurerIds.add(key);
  }

  const rows = [...relevantAdventurerIds]
    .sort((left, right) => left.localeCompare(right))
    .map((adventurerIdKey) => {
      const adventurer = adventurerById.get(adventurerIdKey);
      const economics = economicsById.get(adventurerIdKey);
      const activeShift = activeShiftByAdventurer.get(adventurerIdKey);
      const activeReservation = activeReservationByAdventurer.get(adventurerIdKey);

      const activity = activeShift ? "mining" : activeReservation ? "harvesting" : "idle";
      const target = activeShift
        ? renderFelt(activeShift.mine_key)
        : activeReservation
          ? renderFelt(activeReservation.plant_key)
          : '<span class="inspect-muted">none</span>';
      const energy = adventurer
        ? `${renderNumber(adventurer.energy)}/${renderNumber(adventurer.max_energy)}`
        : renderNumber(economics?.energy_balance ?? 0);
      const lockState = adventurer
        ? toSafeNumber(adventurer.activity_locked_until, 0) > toSafeNumber(payload.headBlock, 0)
          ? `locked@${renderNumber(adventurer.activity_locked_until)}`
          : "open"
        : "unknown";
      const unbankedOre = activeShift ? renderNumber(activeShift.accrued_ore_unbanked) : "0";
      const displayAdventurerId =
        adventurer?.adventurer_id ?? economics?.adventurer_id ?? adventurerIdKey;

      return [
        renderFelt(displayAdventurerId),
        escapeHtml(activity),
        target,
        energy,
        escapeHtml(lockState),
        unbankedOre
      ];
    });

  return renderCard(
    "Adventurer Assignments",
    [
      renderTable(
        ["Adventurer", "Activity", "Target", "Energy", "Lock", "Ore"],
        rows.slice(0, MAX_ROWS_PER_SECTION)
      ),
      renderTruncationNote(rows.length)
    ].join("")
  );
}

function renderProductionFeedCard(payload: HexInspectPayload): string {
  const interestingEvents = new Set<string>([
    "miningstarted",
    "miningcontinued",
    "miningexited",
    "minecollapsed",
    "minerepaired",
    "harvestingstarted",
    "harvestingcompleted",
    "harvestingcancelled",
    "itemsconverted"
  ]);

  const rows = [...payload.eventTail]
    .filter((event) => interestingEvents.has(event.eventName.trim().toLowerCase()))
    .sort(compareEventsDesc)
    .map((event) => [
      escapeHtml(`${event.blockNumber}/${event.txIndex}/${event.eventIndex}`),
      escapeHtml(event.eventName),
      escapeHtml(event.payloadJson)
    ]);

  const content =
    rows.length === 0
      ? '<p class="inspect-muted">No production events in tail.</p>'
      : [
          renderTable(["Pos", "Event", "Payload"], rows.slice(0, MAX_ROWS_PER_SECTION)),
          renderTruncationNote(rows.length)
        ].join("");

  return renderCard("Production Feed", content);
}

function renderAreasCard(payload: HexInspectPayload): string {
  const rows = payload.areas.map((area) => {
    const areaAny = area as unknown as Record<string, unknown>;
    return [
      renderNumber(areaAny.area_index),
      escapeHtml(formatValue(areaAny.area_type)),
      renderNumber(areaAny.resource_quality),
      renderNumber(areaAny.plant_slot_count)
    ];
  });

  return renderCard(
    `Areas (${payload.areas.length})`,
    renderCappedTable(["Idx", "Type", "Quality", "Slots"], rows, payload.areas.length)
  );
}

function renderOwnershipCard(payload: HexInspectPayload): string {
  const rows = payload.ownership.map((row) => [
    renderFelt(row.area_id),
    renderFelt(row.owner_adventurer_id),
    renderNumber(row.claim_block)
  ]);

  return renderCard(
    `Ownership (${payload.ownership.length})`,
    renderCappedTable(["Area", "Owner", "Claim Block"], rows, payload.ownership.length)
  );
}

function renderDecayCard(payload: HexInspectPayload): string {
  const content = payload.decayState
    ? renderTable(
        ["Owner", "Reserve", "Decay", "Claimable Since"],
        [
          [
            renderFelt(payload.decayState.owner_adventurer_id),
            renderNumber(payload.decayState.current_energy_reserve),
            renderNumber(payload.decayState.decay_level),
            renderNumber(payload.decayState.claimable_since_block)
          ]
        ]
      )
    : '<p class="inspect-muted">No decay state for this hex.</p>';

  return renderCard("Decay", content);
}

function renderClaimsCard(payload: HexInspectPayload): string {
  const rows = payload.activeClaims.map((claim) => [
    renderFelt(claim.claim_id),
    renderFelt(claim.claimant_adventurer_id),
    renderNumber(claim.energy_locked),
    renderNumber(claim.expiry_block),
    escapeHtml(formatValue(claim.status))
  ]);

  return renderCard(
    `Claims (${payload.activeClaims.length})`,
    renderCappedTable(
      ["Claim", "Claimant", "Locked", "Expiry", "Status"],
      rows,
      payload.activeClaims.length
    )
  );
}

function renderPlantsCard(payload: HexInspectPayload): string {
  const rows = payload.plants.map((plant) => [
    renderNumber(plant.plant_id),
    renderFelt(plant.species),
    `${renderNumber(plant.current_yield)}/${renderNumber(plant.max_yield)}`,
    renderNumber(plant.reserved_yield)
  ]);

  return renderCard(
    `Plants (${payload.plants.length})`,
    renderCappedTable(["Plant", "Species", "Yield", "Reserved"], rows, payload.plants.length)
  );
}

function renderReservationsCard(payload: HexInspectPayload): string {
  const rows = payload.activeReservations.map((reservation) => [
    renderFelt(reservation.reservation_id),
    renderFelt(reservation.adventurer_id),
    renderNumber(reservation.reserved_amount),
    escapeHtml(formatValue(reservation.status))
  ]);

  return renderCard(
    `Reservations (${payload.activeReservations.length})`,
    renderCappedTable(
      ["Reservation", "Adventurer", "Amount", "Status"],
      rows,
      payload.activeReservations.length
    )
  );
}

function renderAdventurersCard(payload: HexInspectPayload): string {
  const rows = payload.adventurers.map((adventurer) => [
    renderFelt(adventurer.adventurer_id),
    `${renderNumber(adventurer.energy)}/${renderNumber(adventurer.max_energy)}`,
    renderNumber(adventurer.activity_locked_until),
    escapeHtml(formatValue(adventurer.is_alive))
  ]);

  return renderCard(
    `Adventurers (${payload.adventurers.length})`,
    renderCappedTable(["ID", "Energy", "Locked Until", "Alive"], rows, payload.adventurers.length)
  );
}

function renderEconomicsCard(payload: HexInspectPayload): string {
  const rows = payload.adventurerEconomics.map((economics) => [
    renderFelt(economics.adventurer_id),
    renderNumber(economics.energy_balance),
    renderNumber(economics.total_energy_spent),
    renderNumber(economics.total_energy_earned)
  ]);

  return renderCard(
    `Economics (${payload.adventurerEconomics.length})`,
    renderCappedTable(
      ["ID", "Balance", "Spent", "Earned"],
      rows,
      payload.adventurerEconomics.length
    )
  );
}

function renderInventoryCard(payload: HexInspectPayload): string {
  const rows = payload.inventories.map((inventory) => [
    renderFelt(inventory.adventurer_id),
    `${renderNumber(inventory.current_weight)}/${renderNumber(inventory.max_weight)}`
  ]);

  return renderCard(
    `Inventory (${payload.inventories.length})`,
    renderCappedTable(["ID", "Weight"], rows, payload.inventories.length)
  );
}

function renderBackpackCard(payload: HexInspectPayload): string {
  const rows = payload.backpackItems.map((item) => [
    renderFelt(item.adventurer_id),
    renderFelt(item.item_id),
    renderNumber(item.quantity),
    renderNumber(item.quality)
  ]);

  return renderCard(
    `Backpack (${payload.backpackItems.length})`,
    renderCappedTable(["ID", "Item", "Qty", "Quality"], rows, payload.backpackItems.length)
  );
}

function renderBuildingsCard(payload: HexInspectPayload): string {
  const rows = payload.buildings.map((building) => [
    renderFelt(building.area_id),
    renderFelt(building.building_type),
    renderNumber(building.tier),
    renderNumber(building.condition_bp),
    escapeHtml(formatValue(building.is_active))
  ]);

  return renderCard(
    `Buildings (${payload.buildings.length})`,
    renderCappedTable(
      ["Area", "Type", "Tier", "Condition", "Active"],
      rows,
      payload.buildings.length
    )
  );
}

function renderConstructionCard(payload: HexInspectPayload): string {
  const projectRows = payload.constructionProjects.map((project) => [
    renderFelt(project.project_id),
    renderFelt(project.adventurer_id),
    renderNumber(project.target_tier),
    escapeHtml(formatValue(project.status))
  ]);
  const projectTable = renderCappedTable(
    ["Project", "Adventurer", "Tier", "Status"],
    projectRows,
    payload.constructionProjects.length
  );
  const escrowRows = payload.constructionEscrows.map((escrow) => [
    renderFelt(escrow.project_id),
    renderFelt(escrow.item_id),
    renderNumber(escrow.quantity)
  ]);
  const escrowTable = renderCappedTable(
    ["Project", "Item", "Qty"],
    escrowRows,
    payload.constructionEscrows.length
  );

  return renderCard(
    `Construction (projects=${payload.constructionProjects.length}, escrows=${payload.constructionEscrows.length})`,
    [
      '<p class="inspect-subhead">Projects</p>',
      projectTable,
      '<p class="inspect-subhead">Escrows</p>',
      escrowTable
    ].join("")
  );
}

function renderDeathsCard(payload: HexInspectPayload): string {
  const rows = payload.deathRecords.map((death) => [
    renderFelt(death.adventurer_id),
    renderNumber(death.death_block),
    renderFelt(death.death_cause)
  ]);

  return renderCard(
    `Deaths (${payload.deathRecords.length})`,
    renderCappedTable(["Adventurer", "Block", "Cause"], rows, payload.deathRecords.length)
  );
}

function renderEventsCard(payload: HexInspectPayload): string {
  const rows = payload.eventTail.map((event) => [
    escapeHtml(`${event.blockNumber}/${event.txIndex}/${event.eventIndex}`),
    escapeHtml(event.eventName)
  ]);

  return renderCard(
    `Events (${payload.eventTail.length})`,
    renderCappedTable(["Pos", "Name"], rows, payload.eventTail.length)
  );
}

function renderRawPayloadCards(payload: HexInspectPayload): string {
  return [
    renderRawObjectCard("Hex Raw Fields", payload.hex),
    renderRawRowsCard("Areas Raw Fields", payload.areas),
    renderRawRowsCard("Ownership Raw Fields", payload.ownership),
    renderRawObjectCard("Decay Raw Fields", payload.decayState),
    renderRawRowsCard("Claims Raw Fields", payload.activeClaims),
    renderRawRowsCard("Plants Raw Fields", payload.plants),
    renderRawRowsCard("Reservations Raw Fields", payload.activeReservations),
    renderRawRowsCard("Adventurers Raw Fields", payload.adventurers),
    renderRawRowsCard("Economics Raw Fields", payload.adventurerEconomics),
    renderRawRowsCard("Inventories Raw Fields", payload.inventories),
    renderRawRowsCard("Backpack Raw Fields", payload.backpackItems),
    renderRawRowsCard("Buildings Raw Fields", payload.buildings),
    renderRawRowsCard("Construction Projects Raw Fields", payload.constructionProjects),
    renderRawRowsCard("Construction Escrows Raw Fields", payload.constructionEscrows),
    renderRawRowsCard("Mine Nodes Raw Fields", payload.mineNodes),
    renderRawRowsCard("Mining Shifts Raw Fields", payload.miningShifts),
    renderRawRowsCard("Mine Access Grants Raw Fields", payload.mineAccessGrants),
    renderRawRowsCard("Mine Collapse Records Raw Fields", payload.mineCollapseRecords),
    renderRawRowsCard("Deaths Raw Fields", payload.deathRecords),
    renderRawRowsCard("Events Raw Fields", payload.eventTail)
  ].join("");
}

function renderRawRowsCard(title: string, rows: unknown[]): string {
  return renderRawObjectCard(
    `${title} (${rows.length})`,
    rows.slice(0, MAX_ROWS_PER_SECTION)
  );
}

function renderRawObjectCard(title: string, value: unknown): string {
  return renderCard(
    title,
    `<pre class="inspect-raw-pre">${escapeHtml(JSON.stringify(value, null, 2) ?? "null")}</pre>`
  );
}

function renderCard(title: string, content: string): string {
  return [
    '<section class="inspect-card">',
    `<h3>${escapeHtml(title)}</h3>`,
    content,
    "</section>"
  ].join("");
}

function renderTable(headers: string[], rows: string[][]): string {
  if (rows.length === 0) {
    return '<p class="inspect-muted">No rows.</p>';
  }

  const headerHtml = headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("");
  const bodyHtml = rows
    .map(
      (row) =>
        `<tr>${row
          .map((cell) => `<td>${cell}</td>`)
          .join("")}</tr>`
    )
    .join("");
  return [
    '<div class="inspect-table-wrap">',
    '<table class="inspect-table">',
    `<thead><tr>${headerHtml}</tr></thead>`,
    `<tbody>${bodyHtml}</tbody>`,
    "</table>",
    "</div>"
  ].join("");
}

function renderCappedTable(
  headers: string[],
  rows: string[][],
  totalRows: number
): string {
  return [
    renderTable(headers, rows.slice(0, MAX_ROWS_PER_SECTION)),
    renderTruncationNote(totalRows)
  ].join("");
}

function renderTruncationNote(totalRows: number): string {
  if (totalRows <= MAX_ROWS_PER_SECTION) {
    return "";
  }
  return `<p class="inspect-muted">Showing ${MAX_ROWS_PER_SECTION} of ${totalRows} rows.</p>`;
}

function compareAreaRows(
  left: HexInspectPayload["areas"][number],
  right: HexInspectPayload["areas"][number]
): number {
  const leftAny = left as unknown as Record<string, unknown>;
  const rightAny = right as unknown as Record<string, unknown>;
  const leftIndex = toSafeNumber(leftAny.area_index, 0);
  const rightIndex = toSafeNumber(rightAny.area_index, 0);
  if (leftIndex !== rightIndex) {
    return leftIndex - rightIndex;
  }
  return normalizeKey(left.area_id).localeCompare(normalizeKey(right.area_id));
}

function compareMineRows(
  left: HexInspectPayload["mineNodes"][number],
  right: HexInspectPayload["mineNodes"][number]
): number {
  const mineIdDiff = toSafeNumber(left.mine_id, 0) - toSafeNumber(right.mine_id, 0);
  if (mineIdDiff !== 0) {
    return mineIdDiff;
  }
  return normalizeKey(left.mine_key).localeCompare(normalizeKey(right.mine_key));
}

function compareEventsDesc(
  left: HexInspectPayload["eventTail"][number],
  right: HexInspectPayload["eventTail"][number]
): number {
  if (left.blockNumber !== right.blockNumber) {
    return right.blockNumber - left.blockNumber;
  }
  if (left.txIndex !== right.txIndex) {
    return right.txIndex - left.txIndex;
  }
  return right.eventIndex - left.eventIndex;
}

function deriveMineStatus(
  mine: HexInspectPayload["mineNodes"][number],
  activeShiftCount: number,
  headBlock: number
): "active" | "collapsed" | "depleted" | "idle" {
  if (isTrueValue(mine.is_depleted)) {
    return "depleted";
  }

  if (
    toSafeNumber(mine.repair_energy_needed, 0) > 0 ||
    toSafeNumber(mine.collapsed_until_block, 0) > toSafeNumber(headBlock, 0)
  ) {
    return "collapsed";
  }

  if (activeShiftCount > 0 || toSafeNumber(mine.active_miners, 0) > 0) {
    return "active";
  }

  return "idle";
}

function normalizeKey(value: unknown): string {
  return String(value).trim().toLowerCase();
}

function isActiveEnumStatus(status: unknown): boolean {
  const normalized = normalizeKey(extractEnumTag(status));
  return normalized === "active" || normalized === "1";
}

function extractEnumTag(value: unknown): string {
  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean" ||
    typeof value === "bigint"
  ) {
    return String(value);
  }

  if (value && typeof value === "object") {
    const keys = Object.keys(value as Record<string, unknown>);
    if (keys.length === 1) {
      return keys[0] ?? "unknown";
    }
  }

  return "unknown";
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

function renderFelt(value: unknown): string {
  const normalized = String(value);
  const short = normalized.length <= 22 ? normalized : `${normalized.slice(0, 10)}...${normalized.slice(-8)}`;
  const escapedFull = escapeHtml(normalized);
  const escapedShort = escapeHtml(short);
  return `<span class="inspect-felt" title="${escapedFull}">${escapedShort}</span>`;
}

function renderNumber(value: unknown): string {
  return String(toSafeNumber(value, 0));
}

function formatValue(value: unknown): string {
  if (typeof value === "boolean" || typeof value === "number" || typeof value === "bigint") {
    return String(value);
  }
  if (typeof value === "string") {
    return value;
  }
  if (value === null || value === undefined) {
    return "none";
  }
  if (typeof value === "object") {
    const objectValue = value as Record<string, unknown>;
    const keys = Object.keys(objectValue);
    if (keys.length === 1) {
      return keys[0] ?? "unknown";
    }
    return JSON.stringify(value);
  }
  return String(value);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
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
