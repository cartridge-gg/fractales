---
name: gen-dungeon-agent-play
description: Operate Infinite Hex Adventurers as an agent-first game client. Use when you need to read indexed Dojo/Torii state, compute legal/optimal actions, and execute World/Adventurer/Harvesting/Economic/Ownership function calls (prefer Cartridge controller-cli, fallback to sozo/RPC).
---

# Gen Dungeon Agent Play

Run every turn as `read -> compute -> act -> verify`.

## Use This Runtime Contract

- Read from indexer SQL first (fast path).
- Read `now_block` from RPC each turn.
- Compute derived values locally with integer math.
- Submit exactly one highest-value state-changing action per adventurer per turn.
- Verify success from model deltas and emitted events, not just tx inclusion.

## Use These Canonical Calls

- `adventurer_manager.create_adventurer(name)`
- `adventurer_manager.consume_energy(adventurer_id, amount)`
- `adventurer_manager.regenerate_energy(adventurer_id)`
- `adventurer_manager.kill_adventurer(adventurer_id, cause)`
- `world_manager.move_adventurer(adventurer_id, to_hex_coordinate)`
- `world_manager.discover_hex(adventurer_id, hex_coordinate, biome, area_count)`
- `world_manager.discover_area(adventurer_id, hex_coordinate, area_index, area_type, resource_quality, size_category)`
- `harvesting_manager.init_harvesting(hex_coordinate, area_id, plant_id, species, max_yield, regrowth_rate)`
- `harvesting_manager.start_harvesting(adventurer_id, hex_coordinate, area_id, plant_id, amount)`
- `harvesting_manager.complete_harvesting(adventurer_id, hex_coordinate, area_id, plant_id)`
- `harvesting_manager.cancel_harvesting(adventurer_id, hex_coordinate, area_id, plant_id)`
- `economic_manager.convert_items_to_energy(adventurer_id, item_id, quantity)`
- `economic_manager.pay_hex_maintenance(adventurer_id, hex_coordinate, amount)`
- `economic_manager.process_hex_decay(hex_coordinate)`
- `economic_manager.initiate_hex_claim(adventurer_id, hex_coordinate, energy_offered)`
- `economic_manager.defend_hex_from_claim(adventurer_id, hex_coordinate, defense_energy)`
- `ownership_manager.get_owner(area_id)`
- `ownership_manager.transfer_ownership(area_id, to_adventurer_id)`

## Mirror These Constants In The Client

- `ENERGY_PER_HEX_MOVE = 15`
- `ENERGY_PER_EXPLORE = 25`
- `ENERGY_REGEN_PER_100_BLOCKS = 20`
- `HARVEST_ENERGY_PER_UNIT = 10`
- `HARVEST_TIME_PER_UNIT = 2` blocks
- `CONVERSION_WINDOW_BLOCKS = 100`
- `DECAY_PERIOD_BLOCKS = 100`
- `CLAIM_TIMEOUT_BLOCKS = 100`
- `CLAIM_GRACE_BLOCKS = 500`
- `CLAIMABLE_DECAY_THRESHOLD = 80`

## Build These Read Views

Use indexer SQL tables and expose parameterized queries from your read client:

- `v_adventurer_state`
- `v_inventory_state`
- `v_backpack_items`
- `v_hex_state`
- `v_hex_area_state`
- `v_area_ownership`
- `v_plant_state`
- `v_harvest_reservation_state`
- `v_adventurer_economics_state`
- `v_hex_decay_state`
- `v_claim_escrow_state`
- `v_conversion_rate_state`
- `v_active_claims`
- `v_claimable_hexes`

Use `adventurer_id`, `hex_coordinate`, `area_id`, and `plant_id` as primary query params.

## Compute These Derived Values Client-Side

- `effective_energy_now` with lazy regen:
  - `regen = floor((now_block - last_regen_block) * 20 / 100)`
  - clamp at `max_energy`
- `available_yield = current_yield - reserved_yield` only when state is valid
- `harvest_energy_cost = amount * 10`
- `harvest_eta_block = now_block + amount * 2`
- `blocks_until_unlock = max(0, activity_locked_until - now_block)`
- conversion quote:
  - effective rate with 100-block window penalty
  - `raw_energy = quantity * rate`
  - `minted_energy = min(raw_energy, max_energy - current_energy)`
- decay quote:
  - elapsed periods from `last_decay_processed_block`
  - projected reserve and decay after period processing
- claim quote:
  - minimum energy with `min_claim_energy` logic
  - immediate claim only if `now_block - claimable_since_block >= 500`

## Follow This Action Priority

For each adventurer, evaluate in order:

1. If dead, emit `no-op`.
2. If defending owned hex is possible and active claim exists, defend.
3. If a high-value claimable hex is available and energy >= min claim, initiate claim.
4. If controlling decaying hex and maintenance has best ROI, pay maintenance.
5. If harvest is active and mature, complete harvest.
6. If harvest is active but low EV to wait, cancel harvest.
7. If inventory is overweight or conversion ROI is high, convert items.
8. If unlocked and enough energy, start harvest.
9. If expansion EV is high, move/discover hex and discover area.
10. Otherwise wait and re-evaluate next block window.

## Enforce These Guardrails

- Never issue actions for dead adventurers.
- Never trust stale indexer state; compare indexer head to RPC block and set a max lag.
- Never convert items while at energy cap unless intentional (items burn even if minted energy is zero).
- Never attempt second active claim with energy already locked in escrow.
- Always treat replay/no-op paths as expected outcomes for idempotent actions.

## Execute With Controller CLI

Use Cartridge controller CLI as the primary submit path.
Reference: `https://github.com/cartridge-gg/controller-cli`.

- Discover exact command syntax from the installed binary:
  - `controller-cli --help`
  - `controller-cli <subcommand> --help`
- Map each action into:
  - target contract address
  - entrypoint name
  - ordered calldata
- Wrap controller-cli calls behind your own adapter so policy code never depends on raw CLI flags.

If controller CLI is unavailable, fallback to `sozo execute` or direct Starknet RPC.

## Verify Every Action

After submission:

- Reload affected models from SQL/indexer.
- Confirm expected event emission:
  - world: `HexDiscovered`, `AreaDiscovered`, `AdventurerMoved`
  - harvesting: `HarvestingStarted`, `HarvestingCompleted`, `HarvestingCancelled`
  - economics: `ItemsConverted`, `HexEnergyPaid`, `HexBecameClaimable`, `ClaimInitiated`, `ClaimExpired`, `ClaimRefunded`, `HexDefended`
  - ownership: `AreaOwnershipAssigned`, `OwnershipTransferred`
- Record an action journal row:
  - `action_id`, `adventurer_id`, `inputs`, `pre_state_hash`, `post_state_hash`, `tx_hash`, `success`, `reason`

## Expose Human Observer Outputs

Serve these read-only outputs for dashboards:

- per-adventurer timeline and next legal actions
- per-hex decay risk and claimability windows
- active harvest and escrow timers
- ownership map and recent transfers
- live action feed with verification status
