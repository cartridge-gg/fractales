# Construction Module: 7-Building Hex Development Scope (Post-MVP)

## Intent

Add a deterministic construction loop that lets players build up controlled hexes using both mined ores and plant-derived materials.

This module extends the live gameplay from:

`explore -> discover -> harvest/convert -> maintain -> defend/claim`

to:

`explore -> discover -> harvest/mine -> process materials -> build -> upkeep -> defend/expand`

## Scope Summary

- Status: post-MVP module design.
- Build rights: current hex controller only (single-controller-per-hex semantics stay intact).
- Placement model: one building slot per discovered `HexArea`.
- Resource model: ore IDs + plant-derived construction materials.
- Building count in scope: 7.
- Balance workflow: `07-delivery/construction-balance-scope.md` using `04-economy/tools/construction_balance_sim.py`.
- Implementation workflow: `07-delivery/construction-prd-tdd.md`.

## Design Constraints

1. Deterministic and replay-safe transitions.
2. No freeform geometry placement in v1 (slot-based via `area_id`).
3. Buildings must require upkeep and can become inactive.
4. Claim/defend transfer must move building control with hex control.
5. No dependence on offchain simulation for core settlement.

## Material Model

### Inputs

- Ore resources from mining (`ORE_IRON`, `ORE_COAL`, `ORE_COPPER`, `ORE_TIN`, `ORE_NICKEL`, `ORE_COBALT`, ...).
- Plant-derived materials produced from harvested plant inventory via deterministic processing.

### Plant Material Classes (for construction)

To avoid recipe fragmentation across per-plant item IDs, construction consumes three fungible plant materials:

- `PLANT_FIBER`
- `PLANT_RESIN`
- `PLANT_COMPOUND`

Processing entrypoint (proposed):

```text
process_plant_material(adventurer_id, source_item_id, quantity, target_material) -> output_quantity
```

## Core Loop

`discover areas -> gather ores + plants -> process plant materials -> start construction -> complete construction -> fund upkeep -> leverage bonuses for economy/defense`

## Seven Buildings (Gameplay Fit)

| Building | Primary Loop Impact | Deterministic Effect (v1) | Typical Inputs (T1) |
|---|---|---|---|
| `SMELTER` | Ore economy | Ore conversion multiplier on this hex | `ORE_IRON`, `ORE_COAL`, `ORE_COPPER` |
| `SHORING_RIG` | Mining risk control | Reduces mine stress accumulation in this hex | `ORE_IRON`, `ORE_TIN`, `ORE_COBALT`, `PLANT_RESIN` |
| `GREENHOUSE` | Harvest sustainability | Improves plant regrowth/available yield in this hex | `PLANT_FIBER`, `PLANT_COMPOUND`, `ORE_COPPER` |
| `HERBAL_PRESS` | Plant monetization | Plant conversion multiplier on this hex | `PLANT_COMPOUND`, `PLANT_RESIN`, `ORE_TIN` |
| `WORKSHOP` | Build acceleration | Material discount + build-time reduction on this hex | `ORE_IRON`, `ORE_NICKEL`, `PLANT_FIBER` |
| `STOREHOUSE` | Logistics | Increases effective carry/storage capacity for controller operations in hex | `ORE_IRON`, `ORE_COAL`, `PLANT_FIBER` |
| `WATCHTOWER` | Territorial defense | Defense efficiency bonus in `defend_hex_from_claim` | `ORE_IRON`, `ORE_COBALT`, `PLANT_RESIN` |

## v1 Effect Formulas

All effect bonuses are basis points and applied only when building is active.

- `SMELTER`: `ore_energy_out = floor(base * smelter_bp / 10_000)` where `smelter_bp = 11_250`.
- `SHORING_RIG`: `mine_stress_saved = floor(base_risk_loss * shoring_bp / 10_000)` where `shoring_bp = 14_000`.
- `GREENHOUSE`: `regrowth_effective = floor(base_regrowth * greenhouse_bp / 10_000)` where `greenhouse_bp = 12_000`.
- `HERBAL_PRESS`: `plant_energy_out = floor(base * herbal_press_bp / 10_000)` where `herbal_press_bp = 11_500`.
- `WORKSHOP`: `recipe_cost = floor(base_cost * (10_000 - discount_bp)/10_000)` and `build_time = floor(base_time * (10_000 - time_cut_bp)/10_000)` where `discount_bp=1_200`, `time_cut_bp=1_800`.
- `STOREHOUSE`: `hex_capacity_bonus = floor(base_capacity * storehouse_bp / 10_000)` where `storehouse_bp = 15_500`.
- `WATCHTOWER`: `defense_effective = floor(defense_energy * watchtower_bp / 10_000)` where `watchtower_bp = 12_500`.

## State Additions (Proposed)

```text
Construction.BuildingNode {
  key area_id,
  hex_coordinate,
  owner_adventurer_id,
  building_type,
  tier,
  condition_bp,
  upkeep_reserve,
  last_upkeep_block,
  is_active
}

Construction.BuildProject {
  key project_id,
  adventurer_id,
  hex_coordinate,
  area_id,
  building_type,
  target_tier,
  start_block,
  completion_block,
  energy_staked,
  status
}

Construction.ProjectMaterialEscrow {
  key project_id,
  key item_id,
  quantity
}
```

## API Surface (Proposed)

```text
process_plant_material(adventurer_id, source_item_id, quantity, target_material) -> output_quantity
start_construction(adventurer_id, hex_coordinate, area_id, building_type) -> project_id
complete_construction(adventurer_id, project_id) -> bool
pay_building_upkeep(adventurer_id, hex_coordinate, area_id, amount) -> bool
repair_building(adventurer_id, hex_coordinate, area_id, amount) -> bool
upgrade_building(adventurer_id, hex_coordinate, area_id) -> bool
inspect_building(hex_coordinate, area_id) -> BuildingNode
```

## Transition Rules

### `start_construction`

Preconditions:

- adventurer alive and owned by caller
- adventurer is current controller for target hex
- `area_id` discovered and belongs to target hex
- no active project for target slot
- sufficient materials and energy stake

Effects:

- lock materials in `ProjectMaterialEscrow`
- lock energy stake
- set adventurer activity lock to `completion_block`
- create active `BuildProject`

### `complete_construction`

Preconditions:

- project active
- `now_block >= completion_block`
- ownership check still valid for caller/adventurer pair

Effects:

- create or upgrade `BuildingNode`
- initialize or refresh `condition_bp`
- clear project escrow and active project status
- unlock adventurer

### Upkeep and Deterioration

- upkeep is paid in energy into `upkeep_reserve`
- if reserve is insufficient at checkpoint, `condition_bp` decreases deterministically
- below disable threshold, building stays placed but `is_active=false`

## Claim/Defend and Death Interactions

- successful claim transfer updates building owner fields for all buildings in hex.
- active projects are not canceled by transfer; completion resolves to current controller.
- if builder dies during an active project, project is canceled and escrowed materials are burned in v1.

## Implementation Scope Proposal

### Phase 1 (ship first)

- Foundation models and project lifecycle
- `SMELTER`, `GREENHOUSE`, `WORKSHOP`
- `process_plant_material`
- upkeep + deterioration for active/inactive states

### Phase 2

- `SHORING_RIG`, `HERBAL_PRESS`, `STOREHOUSE`
- mining/harvest modifier plumbing and balancing

### Phase 3

- `WATCHTOWER`
- claim/defend modifier integration and anti-snowball tuning

## In Scope

- 7 building types and deterministic formulas
- ore + plant material recipes
- slot-based build model via `HexArea`
- project escrow/settlement, upkeep, deterioration, upgrade path
- ownership transfer coherence with claim/defend

## Out Of Scope (v1)

- freeform XY placement inside hexes
- player-authored custom building scripts/hooks
- NPC worker automation
- global market/orderbook mechanics for construction resources
- cross-hex aura stacking systems

## TDD Coverage

Unit:

- recipe checks and cost modifiers
- project timing and lock/unlock logic
- upkeep deterioration and reactivation
- per-building formula correctness

Integration:

- mine -> build `SMELTER` -> improved ore conversion
- harvest -> process plants -> build `GREENHOUSE` -> improved regrowth path
- build `WORKSHOP` -> discounted/faster second construction
- claim transfer with mixed active/inactive buildings

Property:

- deterministic replay of build outcomes
- escrow conservation and single-settlement guarantees
- no negative inventory/energy states under interleavings

## Success Criteria

1. Construction is a meaningful sink for both ore and plant resources.
2. Developed hexes have measurable strategic advantage but still require upkeep discipline.
3. Claim/defend remains coherent with no ownership drift.
4. The first release (Phase 1) is shippable without requiring all seven buildings at once.
