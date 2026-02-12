# Infinite Hex Adventurers — MVP Functional Specification (TDD-Ready)

## 0. Scope (MVP)

- Core loop: discover hex → discover area → mint ownership (NFT model parity) → initialize harvesting module → start/complete time-locked harvest → convert to energy → pay hex maintenance → decay → claim/defend.
- Adventurer basics: create, move (adjacent only), energy spend/regenerate, activity time-locks, backpack capacity, and true permadeath.
- World gen: deterministic hex/area/plant generation from `(global_seed, coordinate/id)` using Cubit noise, materialized lazily on first discover/init and immutable on replay.
- Coordinates: gameplay uses cube coordinates centered at `(0,0,0)`; storage uses felt encoding via deterministic codec.
- Economics: energy balances, universal conversion (plants → energy), territorial maintenance and decay, claim/defend.
- Events: HexDiscovered, AreaDiscovered, AdventurerCreated, AdventurerMoved, HarvestingStarted/Completed, ItemsConverted, HexEnergyPaid, HexBecameClaimable, HexClaimed/Defended, AdventurerDied.
- Non-goals (post-MVP): mining, crafting, buildings, AI agent service, complex hooks beyond simple fee.

## 1. Actors, IDs, and Models (Dojo)

- Identifiers

  - AdventurerId: felt252
  - HexCoordinate: felt252 (encoded cube `(x,y,z)` via codec)
  - AreaId: felt252
  - ItemId: felt252

- Models (storage schema)
  - World.Hex { coordinate, biome, is_discovered, discovery_block, discoverer, area_count }
  - World.HexArea { area_id, hex_coordinate, area_index, area_type, is_discovered, discoverer, resource_quality, size_category }
  - World.WorldGenConfig { generation_version, global_seed, biome_scale_bp, area_scale_bp, plant_scale_bp, biome_octaves, area_octaves, plant_octaves }
  - Adventurer.Adventurer { adventurer_id, owner, name, energy, max_energy, current_hex, activity_locked_until, is_alive }
  - Adventurer.Inventory { adventurer_id, current_weight, max_weight }
  - Adventurer.BackpackItem { adventurer_id, item_id, quantity, quality, weight_per_unit }
  - Economics.AdventurerEconomics { adventurer_id, energy_balance, total_energy_spent, total_energy_earned, last_regen_block }
  - Economics.ConversionRate { item_type, current_rate, base_rate, last_update_block }
  - Economics.HexDecayState { hex_coordinate, owner_adventurer_id, current_energy_reserve, last_energy_payment_block, last_decay_processed_block, decay_level }
  - Economics.ClaimEscrow { claim_id, hex_coordinate, claimant_adventurer_id, energy_locked, created_block, expiry_block, status }
  - Ownership.AreaOwnership { area_id, owner_adventurer_id, discoverer_adventurer_id, discovery_block, claim_block }
  - Harvesting.PlantNode { key(hash(hex, area_id, plant_id)), hex_coordinate, area_id, plant_id, species, current_yield, reserved_yield, max_yield, regrowth_rate, health, stress_level, genetics_hash, last_harvest_block, discoverer }
  - Harvesting.HarvestReservation { reservation_id, adventurer_id, plant_key, reserved_amount, created_block, expiry_block, status }
  - Adventurer.DeathRecord { adventurer_id, owner, death_block, death_cause, inventory_lost_hash }

Note: NFT parity modeled by `Ownership.AreaOwnership`; ERC-721 can be added post-MVP.

## 2. System APIs (External)

WorldManager

- discover_hex(adventurer_id, hex) → Hex; Pre: adjacent to current; Behavior: derive `biome` and `area_count` from deterministic Cubit noise; idempotent replay; Cost: ENERGY_PER_EXPLORE only on first discovery; Events: HexDiscovered on first discovery only
- discover_area(adventurer_id, hex, area_index) → AreaId; Pre: hex discovered; area_index valid; deterministic `AreaId = hash(hex, area_index)`; Behavior: derive `area_type`, `resource_quality`, and `size_category` from deterministic generation keyed by `(hex, area_index)`; Events: AreaDiscovered
- move_adventurer(adventurer_id, to_hex) → ok; Pre: adjacent; Effects: energy spend, position update; Events: AdventurerMoved

AdventurerManager

- create_adventurer(owner, name) → adventurer_id; Effects: spawn at (0,0,0), energy=max
- consume_energy(adventurer_id, amount) → ok
- regenerate_energy(adventurer_id) → new_balance; Behavior: per-block lazy regen from `last_regen_block` with cap at `max_energy`
- kill_adventurer(adventurer_id, cause) → ok; Effects: mark dead permanently, clear activity, lose inventory; Events: AdventurerDied

Harvesting

- init_harvesting(hex, area_id, plant_id) → instance_ok; Pre: hex discovered; Behavior: derive `species`, `max_yield`, `regrowth_rate`, and `genetics_hash` from deterministic generation keyed by `(hex, area_id, plant_id)`
- start_harvesting(adventurer_id, hex, area_id, plant_id, amount) → activity; Pre: IDLE, `available_yield = current_yield - reserved_yield ≥ amount`, energy≥cost; Effects: create reservation + time-lock; Events: HarvestingStarted
- complete_harvesting(adventurer_id) → {actual_yield, quality}; Effects: settle reservation, mint items, update plant yield/stress; Events: HarvestingCompleted
- cancel_harvesting(adventurer_id) → {partial_yield}; Effects: settle reservation with partial/zero yield; Events: HarvestingCancelled
- inspect_plant(hex, area_id, plant_id) → status

EconomicManager

- convert_items_to_energy(adventurer_id, items[]) → energy_gained; Effects: burn items, add energy; Events: ItemsConverted
- pay_hex_maintenance(adventurer_id, hex, energy) → ok; Effects: move energy to hex reserve; Events: HexEnergyPaid
- process_hex_decay(hex) → DecayResult; Behavior: checkpointed and idempotent within same processed window; May mark claimable
- initiate_hex_claim(adventurer_id, hex, energy_offered) → ClaimPending|Success; Effects: lock offered energy into escrow immediately; transfers hex control and all area ownership rows for that hex on success; Events: ClaimInitiated|HexClaimed
- defend_hex_from_claim(adventurer_id, hex, energy) → DefenseSuccessful; Effects: settles or cancels active escrows per rules; Events: HexDefended|ClaimRefunded

AreaOwnership

- get_owner(area_id) → adventurer_id
- transfer_ownership(area_id, to_adventurer_id) → ok (post-MVP or admin for tests)

## 3. Actions: Preconditions → Effects → Events

- discover_hex

  - Pre: `is_adjacent(from,to)`; adventurer is alive
  - Effects (first discovery): create Hex using deterministic generated `biome` + `area_count`; set discoverer; spend energy
  - Effects (replay on discovered hex): return existing Hex only; no writes; no energy spend
  - Events: HexDiscovered on first discovery only

- discover_area

  - Pre: hex.discovered; `area_index < hex.area_count`; area not discovered
  - Effects: create HexArea with deterministic `AreaId = hash(hex, area_index)` and deterministic generated `area_type`, `resource_quality`, `size_category`
  - Ownership rule: MVP uses single-controller-per-hex semantics. Controller is the owner of control area `area_index = 0`. All `Ownership.AreaOwnership` rows in a hex must share the current controller as `owner_adventurer_id`.
  - First control-area discoverer becomes controller.
  - Non-control area discoveries set `discoverer_adventurer_id` to caller, but `owner_adventurer_id` to current controller.
  - Events: AreaDiscovered

- init_harvesting

  - Pre: hex.discovered; area discovered; plant not yet initialized
  - Effects: initialize `PlantNode` from deterministic generated profile (`species`, `max_yield`, `regrowth_rate`, `genetics_hash`) using `(hex, area_id, plant_id)` domain-separated seed derivation
  - Events: none

- start_harvesting

  - Pre: adventurer is alive; activity unlocked; adventurer.energy ≥ cost; `plant.current_yield - plant.reserved_yield ≥ amount`
  - Effects: create `HarvestReservation(status=ACTIVE)`; increment `plant.reserved_yield += amount`; lock adventurer; commit energy; set estimated completion
  - Events: HarvestingStarted

- complete_harvesting

  - Pre: adventurer is alive; block ≥ estimated_completion; activity=HARVESTING; active reservation exists for the activity
  - Effects: settle reservation as `COMPLETED`; reduce `plant.current_yield` by consumed amount; decrement `plant.reserved_yield` by reserved amount; update stress/health; add BackpackItem (or partial); free lock
  - Events: HarvestingCompleted

- cancel_harvesting

  - Pre: activity=HARVESTING; active reservation exists
  - Effects: settle reservation as `CANCELED`; compute partial amount by elapsed progress; decrement `plant.current_yield` by partial consumed amount; decrement `plant.reserved_yield` by full reserved amount; mint partial/zero yield; free lock
  - Events: HarvestingCancelled

- convert_items_to_energy

  - Pre: items exist; rate available
  - Effects: burn items; add adventurer energy per rate and modifiers (including global per-item-type rolling volume penalty window)
  - Events: ItemsConverted

- pay_hex_maintenance

  - Pre: caller is current hex controller (owner of control area `area_index = 0`); adventurer.energy ≥ amount
  - Effects: move energy to HexDecayState reserve; reduce decay if excess
  - Events: HexEnergyPaid

- process_hex_decay

  - Effects: compute elapsed periods from `last_decay_processed_block`; apply consumption/deficit for newly elapsed periods only; update `last_decay_processed_block` to processed boundary; mark claimable at ≥80
  - Events: HexBecameClaimable at threshold

- initiate_hex_claim / defend_hex_from_claim

  - initiate pre: adventurer is alive; hex is claimable; no existing ACTIVE escrow by same claimant for same hex; `energy_offered` satisfies min claim requirement
  - initiate effects: deduct energy immediately; create `ClaimEscrow(status=ACTIVE, expiry_block=now+CLAIM_ATTEMPT_TIMEOUT_BLOCKS)`; claimant cannot reuse locked energy
  - initiate events: ClaimInitiated
  - expiry effects: when `now > escrow.expiry_block` and status ACTIVE, set status EXPIRED and refund locked energy atomically
  - expiry events: ClaimExpired, ClaimRefunded
  - resolve effects: on successful claim/defend resolution, settle escrows (winner consumed per rule, non-winners refunded), update controller, transfer all `Ownership.AreaOwnership` rows in hex to resolved controller, update HexDecayState
  - resolve events: HexClaimed / HexDefended / ClaimRefunded

- kill_adventurer (permadeath)
  - Pre: adventurer is alive
  - Effects: set alive=false permanently; clear active activity; clear inventory; if a harvest reservation is ACTIVE for this adventurer, settle as CANCELED and release reserved yield; if claim escrow is ACTIVE for this adventurer, set EXPIRED and refund locked energy; block further actions by that adventurer
  - Events: AdventurerDied

## 4. Economic & Balance Parameters (Defaults)

- Numeric semantics: percentages are represented in basis points (`1e4`) with floor rounding.
- ENERGY_PER_HEX_MOVE: 15
- ENERGY_PER_EXPLORE: 25
- ENERGY_REGEN_PER_100_BLOCKS: 20 (lazy application on `regenerate_energy` and before energy-spending actions)
- HARVEST_BASE_ENERGY_PER_UNIT: 10; modifiers: vigor, stress
- HARVEST_BASE_TIME_PER_UNIT: 2 blocks; batch/time modifiers
- CONVERSION_BASE_RATE (plant): 10 energy/unit; supply/demand multiplier 0.5–1.5
- CONVERSION_VOLUME_WINDOW_BLOCKS: 100 (rolling)
- CONVERSION_VOLUME_PENALTY: per item_type, `penalty_bp = min(5000, floor(units_converted_in_window / 10) * 100)` (1% per 10 units, max 50%)
- HEX_BASE_UPKEEP/100 blocks by biome: plains 25, forest 35, mountain 45, desert 55, swamp 65
- CLAIMABLE_DECAY_THRESHOLD: 80; CLAIM_GRACE_BLOCKS: 500
- BACKPACK_CAPACITY_RULE: weight-only in MVP (`current_weight <= max_weight`), no slot cap in MVP
- CLAIM_ATTEMPT_TIMEOUT_BLOCKS: 100

## 5. Invariants & Safety

- Movement adjacency enforced (no teleport)
- No double discovery: hex/area idempotent
- `discover_hex` replay path is read-only (no write, no energy spend, no event)
- `AreaId` is deterministic (`hash(hex, area_index)`)
- Generated hex/area/plant attributes are deterministic for fixed `(generation_version, global_seed, coordinate/id)`.
- Generation outputs are independent of caller address and block number.
- Domain-separated generation derivation is enforced (`HEX_V1`, `AREA_V1`, `PLANT_V1`, `GENE_V1` tags).
- Changing generation config/version does not mutate already materialized discovered hex/area/plant rows.
- Single controller per hex: all area ownership rows in a hex share one controller at all times
- Reservation safety: for every plant, `0 <= reserved_yield <= current_yield <= max_yield`
- Active harvest exclusivity: an adventurer can own at most one ACTIVE harvest reservation
- Claim escrow conservation: locked escrow energy is excluded from available energy and is either consumed on winning resolution or refunded exactly once
- Claim expiry safety: ACTIVE escrow cannot remain active past `expiry_block`
- Energy non-negative; spends atomically precede effects
- Energy regen is deterministic and capped at `max_energy`
- Activity time-lock exclusivity (no overlapping)
- Decay monotone in deficit; recovery bounded by maintenance
- Decay checkpoint idempotency: repeated `process_hex_decay` calls without new elapsed period do not change reserves/decay
- Claim only transfers if thresholds and payments satisfied
- Death is irreversible in MVP; dead adventurers cannot execute any state-changing action

## 6. Events (Indexing contract → Torii)

- HexDiscovered {hex, biome, discoverer}
- AreaDiscovered {area_id, hex, area_type, discoverer}
- AdventurerCreated {adventurer_id, owner}
- AdventurerMoved {adventurer_id, from, to}
- AdventurerDied {adventurer_id, owner, cause}
- HarvestingStarted {adventurer_id, hex, area_id, plant_id, amount, eta}
- HarvestingCompleted {adventurer_id, hex, area_id, plant_id, actual_yield}
- HarvestingCancelled {adventurer_id, partial_yield}
- ItemsConverted {adventurer_id, items[], energy_gained}
- HexEnergyPaid {hex, payer, amount}
- HexBecameClaimable {hex, min_energy_to_claim}
- ClaimInitiated {hex, claimant, claim_id, energy_locked, expiry_block}
- ClaimExpired {hex, claim_id, claimant}
- ClaimRefunded {hex, claim_id, claimant, amount}
- HexClaimed {hex, from_owner, to_owner, energy}
- HexDefended {hex, owner, energy}

## 7. Test Plan (TDD)

Unit (per system)

- WorldManager: adjacency, first-discovery write path, replay read-only path, deterministic area id derivation, Cubit-backed deterministic biome/area generation view
- AdventurerManager: create, energy spend/regen bounds, activity locks, permadeath finality, dead-actor global guard behavior
- Harvesting: deterministic plant init profile generation, yield bounds, reservation lifecycle (start/complete/cancel/death), energy/time calc, stress/health progression
- Economics: conversion math (supply/demand + exact 100-block volume window penalty), upkeep calc per biome
- Decay/Claim: checkpointed decay processing, claim marking at 80, escrow lock/refund/expiry, defend and transfer correctness

Integration (end-to-end)

- E2E-01 Discover→Area→Init Harvest→Start/Complete→Convert→Pay Upkeep
- E2E-02 Neglect→Decay crosses 80→Third-party claim→Owner defend within grace
- E2E-03 Multi-adventurer backpack capacity limits affect harvest completion
- E2E-04 Adventurer death during/after activity permanently blocks further actions and clears inventory
- E2E-05 Ownership consistency: all area ownership rows in a claimed hex transfer to the resolved controller
- E2E-06 Two adventurers race same plant: reservation prevents over-commit
- E2E-07 Claim escrow lifecycle: lock on initiate, expiry refund, winning consume, loser refund
- E2E-08 Repeated `process_hex_decay` call in same processed window is a no-op

Property/Fuzz

- Conversion monotonicity: more items → ≥ energy (subject to exact windowed penalty upper bound)
- Reservation invariants hold across start/complete/cancel/death interleavings
- Escrow conservation: `available + locked + spent` remains conserved over claim lifecycle
- No negative balances; no overflows on accumulated counters
- Deterministic generation reproducibility: same seed/config + same inputs always produce same hex/area/plant outputs

Performance

- Single-block harvesting start/complete gas bounds under threshold
- Decay processing amortized O(areas in hex)

Acceptance Criteria (per story)

- AC-W1: Adjacent movement enforced; attempts beyond neighbors revert
- AC-W2: First discoverer recorded; repeat `discover_hex` returns same record with no state mutation, no energy spend, and no event
- AC-W3: `discover_area` uses deterministic `AreaId = hash(hex, area_index)` and enforces single-controller-per-hex ownership
- AC-W4: `discover_hex` and `discover_area` ignore caller-provided world-content payloads (none accepted) and materialize deterministic Cubit-generated values only
- AC-H1: Harvesting start fails with insufficient yield/energy; succeeds otherwise
- AC-H2: Completing harvest mints items or returns partial/failed with full/partial state updates
- AC-H3: Concurrent starts cannot reserve beyond available yield (`current_yield - reserved_yield`)
- AC-H4: `init_harvesting(hex, area_id, plant_id)` materializes deterministic plant profile values and rejects replay mutation
- AC-E1: Conversion produces expected energy within tolerance given rate and penalties
- AC-E2: Regen is deterministic per block delta, applied lazily, and capped at `max_energy`
- AC-E3: Conversion volume penalty uses rolling 100-block window and never exceeds 50%
- AC-D1: Hex reaches claimable at decay≥80 with computed min claim energy
- AC-D2: `process_hex_decay` is idempotent for repeated calls without new elapsed periods
- AC-C1: Successful claim transfers ownership and resets decay as specified
- AC-C2: Claim initiation locks escrowed energy immediately; expired/non-winning claims refund exactly once
- AC-A1: Dead adventurers cannot be revived
- AC-A2: Dead adventurers are rejected by all state-changing entrypoints

## 8. Implementation Stages (with exit tests)

Stage 0 — Project skeleton (Dojo setup)

- Exit: `dojo build` green; empty tests run

Stage 1 — WorldManager minimal

- Implement move, discover_hex; Events; adjacency math
- Exit tests: AC-W1, AC-W2 unit + snapshot events

Stage 2 — Adventurer basics + permadeath

- Create, energy spend/regen, activity lock fields, death record handling
- Exit tests: energy bounds; lock exclusivity; permadeath finality

Stage 3 — Harvesting core

- PlantNode gen on area explore; start/complete; yield/stress
- Exit tests: AC-H1, AC-H2, AC-H3; property: yield/reservation bounds hold

Stage 4 — Economics: conversion + upkeep

- ConversionRate, convert_items_to_energy; pay maintenance; decay processing
- Exit tests: AC-E1, AC-E3, AC-D2, AC-C2; base upkeep by biome; decay increments on deficit with checkpoint idempotency

Stage 5 — Ownership + claim/defend

- AreaOwnership model; claim threshold; transfer
- Exit tests: AC-D1, AC-C1, ownership transfer consistency for all rows in claimed hex

Stage 6 — Integration E2E

- E2E-01/02/03/04/05/06/07/08 pass; event stream validated

## 9. Balance Lock Decisions (Resolved 2026-02-11)

- Energy regen schedule: per-block lazy regen with deterministic block delta and cap.
- Conversion penalty window: rolling 100-block window per item_type with max 50% penalty.
- Backpack capacity in MVP: weight-only; no slot cap.
- Harvest anti-race rule: reservation-based available-yield accounting is mandatory.
- Claim anti-race rule: escrow lock on initiation with deterministic expiry/refund lifecycle.
- Decay anti-double-charge rule: checkpointed processing via `last_decay_processed_block`.

## 10. Appendix — Constants (candidate defaults)

```
ENERGY_PER_HEX_MOVE = 15
ENERGY_PER_EXPLORE = 25
ENERGY_REGEN_PER_100_BLOCKS = 20
HARVEST_BASE_ENERGY_PER_UNIT = 10
HARVEST_BASE_TIME_PER_UNIT = 2  # blocks
CONVERSION_BASE_RATE_PLANT = 10 # energy/unit
CONVERSION_VOLUME_WINDOW_BLOCKS = 100
CONVERSION_VOLUME_PENALTY_MAX_BP = 5000
CLAIM_ATTEMPT_TIMEOUT_BLOCKS = 100
DECAY_THRESHOLD_CLAIMABLE = 80
CLAIM_GRACE_BLOCKS = 500
PERMADEATH_ENABLED = true
BACKPACK_WEIGHT_ONLY_MVP = true
```
