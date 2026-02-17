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

function renderAreasCard(payload: HexInspectPayload): string {
  return renderCard(
    `Areas (${payload.areas.length})`,
    renderTable(
      ["Idx", "Type", "Quality", "Slots"],
      payload.areas.slice(0, MAX_ROWS_PER_SECTION).map((area) => {
        const areaAny = area as unknown as Record<string, unknown>;
        return [
          renderNumber(areaAny.area_index),
          escapeHtml(formatValue(areaAny.area_type)),
          renderNumber(areaAny.resource_quality),
          renderNumber(areaAny.plant_slot_count)
        ];
      })
    )
  );
}

function renderOwnershipCard(payload: HexInspectPayload): string {
  return renderCard(
    `Ownership (${payload.ownership.length})`,
    renderTable(
      ["Area", "Owner", "Claim Block"],
      payload.ownership.slice(0, MAX_ROWS_PER_SECTION).map((row) => [
        renderFelt(row.area_id),
        renderFelt(row.owner_adventurer_id),
        renderNumber(row.claim_block)
      ])
    )
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
  return renderCard(
    `Claims (${payload.activeClaims.length})`,
    renderTable(
      ["Claim", "Claimant", "Locked", "Expiry", "Status"],
      payload.activeClaims.slice(0, MAX_ROWS_PER_SECTION).map((claim) => [
        renderFelt(claim.claim_id),
        renderFelt(claim.claimant_adventurer_id),
        renderNumber(claim.energy_locked),
        renderNumber(claim.expiry_block),
        escapeHtml(formatValue(claim.status))
      ])
    )
  );
}

function renderPlantsCard(payload: HexInspectPayload): string {
  return renderCard(
    `Plants (${payload.plants.length})`,
    renderTable(
      ["Plant", "Species", "Yield", "Reserved"],
      payload.plants.slice(0, MAX_ROWS_PER_SECTION).map((plant) => [
        renderNumber(plant.plant_id),
        renderFelt(plant.species),
        `${renderNumber(plant.current_yield)}/${renderNumber(plant.max_yield)}`,
        renderNumber(plant.reserved_yield)
      ])
    )
  );
}

function renderReservationsCard(payload: HexInspectPayload): string {
  return renderCard(
    `Reservations (${payload.activeReservations.length})`,
    renderTable(
      ["Reservation", "Adventurer", "Amount", "Status"],
      payload.activeReservations.slice(0, MAX_ROWS_PER_SECTION).map((reservation) => [
        renderFelt(reservation.reservation_id),
        renderFelt(reservation.adventurer_id),
        renderNumber(reservation.reserved_amount),
        escapeHtml(formatValue(reservation.status))
      ])
    )
  );
}

function renderAdventurersCard(payload: HexInspectPayload): string {
  return renderCard(
    `Adventurers (${payload.adventurers.length})`,
    renderTable(
      ["ID", "Energy", "Locked Until", "Alive"],
      payload.adventurers.slice(0, MAX_ROWS_PER_SECTION).map((adventurer) => [
        renderFelt(adventurer.adventurer_id),
        `${renderNumber(adventurer.energy)}/${renderNumber(adventurer.max_energy)}`,
        renderNumber(adventurer.activity_locked_until),
        escapeHtml(formatValue(adventurer.is_alive))
      ])
    )
  );
}

function renderEconomicsCard(payload: HexInspectPayload): string {
  return renderCard(
    `Economics (${payload.adventurerEconomics.length})`,
    renderTable(
      ["ID", "Balance", "Spent", "Earned"],
      payload.adventurerEconomics.slice(0, MAX_ROWS_PER_SECTION).map((economics) => [
        renderFelt(economics.adventurer_id),
        renderNumber(economics.energy_balance),
        renderNumber(economics.total_energy_spent),
        renderNumber(economics.total_energy_earned)
      ])
    )
  );
}

function renderInventoryCard(payload: HexInspectPayload): string {
  return renderCard(
    `Inventory (${payload.inventories.length})`,
    renderTable(
      ["ID", "Weight"],
      payload.inventories.slice(0, MAX_ROWS_PER_SECTION).map((inventory) => [
        renderFelt(inventory.adventurer_id),
        `${renderNumber(inventory.current_weight)}/${renderNumber(inventory.max_weight)}`
      ])
    )
  );
}

function renderBackpackCard(payload: HexInspectPayload): string {
  return renderCard(
    `Backpack (${payload.backpackItems.length})`,
    renderTable(
      ["ID", "Item", "Qty", "Quality"],
      payload.backpackItems.slice(0, MAX_ROWS_PER_SECTION).map((item) => [
        renderFelt(item.adventurer_id),
        renderFelt(item.item_id),
        renderNumber(item.quantity),
        renderNumber(item.quality)
      ])
    )
  );
}

function renderBuildingsCard(payload: HexInspectPayload): string {
  return renderCard(
    `Buildings (${payload.buildings.length})`,
    renderTable(
      ["Area", "Type", "Tier", "Condition", "Active"],
      payload.buildings.slice(0, MAX_ROWS_PER_SECTION).map((building) => [
        renderFelt(building.area_id),
        renderFelt(building.building_type),
        renderNumber(building.tier),
        renderNumber(building.condition_bp),
        escapeHtml(formatValue(building.is_active))
      ])
    )
  );
}

function renderConstructionCard(payload: HexInspectPayload): string {
  const projectTable = renderTable(
    ["Project", "Adventurer", "Tier", "Status"],
    payload.constructionProjects.slice(0, MAX_ROWS_PER_SECTION).map((project) => [
      renderFelt(project.project_id),
      renderFelt(project.adventurer_id),
      renderNumber(project.target_tier),
      escapeHtml(formatValue(project.status))
    ])
  );
  const escrowTable = renderTable(
    ["Project", "Item", "Qty"],
    payload.constructionEscrows.slice(0, MAX_ROWS_PER_SECTION).map((escrow) => [
      renderFelt(escrow.project_id),
      renderFelt(escrow.item_id),
      renderNumber(escrow.quantity)
    ])
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
  return renderCard(
    `Deaths (${payload.deathRecords.length})`,
    renderTable(
      ["Adventurer", "Block", "Cause"],
      payload.deathRecords.slice(0, MAX_ROWS_PER_SECTION).map((death) => [
        renderFelt(death.adventurer_id),
        renderNumber(death.death_block),
        renderFelt(death.death_cause)
      ])
    )
  );
}

function renderEventsCard(payload: HexInspectPayload): string {
  return renderCard(
    `Events (${payload.eventTail.length})`,
    renderTable(
      ["Pos", "Name"],
      payload.eventTail.slice(0, MAX_ROWS_PER_SECTION).map((event) => [
        escapeHtml(`${event.blockNumber}/${event.txIndex}/${event.eventIndex}`),
        escapeHtml(event.eventName)
      ])
    )
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
