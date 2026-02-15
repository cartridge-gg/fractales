---
name: gen-dungeon-agent-play
description: Operate Infinite Hex Adventurers as an agent-first game client. Use when you need to read indexed Dojo/Torii state, compute legal/optimal actions, and execute World/Adventurer/Harvesting/Economic/Ownership/Mining/Construction/Sharing function calls (prefer Cartridge controller-cli, fallback to sozo/RPC).
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
- `world_manager.discover_hex(adventurer_id, hex_coordinate)`
- `world_manager.discover_area(adventurer_id, hex_coordinate, area_index)`
- `harvesting_manager.init_harvesting(hex_coordinate, area_id, plant_id)`
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
- `mining_manager.init_mining(hex_coordinate, area_id, mine_id)`
- `mining_manager.grant_mine_access(controller_adventurer_id, mine_key, grantee_adventurer_id)`
- `mining_manager.revoke_mine_access(controller_adventurer_id, mine_key, grantee_adventurer_id)`
- `mining_manager.start_mining(adventurer_id, hex_coordinate, area_id, mine_id)`
- `mining_manager.continue_mining(adventurer_id, mine_key)`
- `mining_manager.stabilize_mine(adventurer_id, mine_key)`
- `mining_manager.exit_mining(adventurer_id, mine_key)`
- `mining_manager.repair_mine(adventurer_id, mine_key, energy_amount)`
- `construction_manager.process_plant_material(adventurer_id, source_item_id, quantity, target_material)`
- `construction_manager.start_construction(adventurer_id, hex_coordinate, area_id, building_type)`
- `construction_manager.complete_construction(adventurer_id, project_id)`
- `construction_manager.pay_building_upkeep(adventurer_id, hex_coordinate, area_id, amount)`
- `construction_manager.repair_building(adventurer_id, hex_coordinate, area_id, amount)`
- `construction_manager.upgrade_building(adventurer_id, hex_coordinate, area_id)`
- `sharing_manager.upsert_resource_policy(controller_adventurer_id, resource_key, resource_kind, is_enabled)`
- `sharing_manager.grant_resource_access(controller_adventurer_id, resource_key, grantee_adventurer_id, permissions_mask)`
- `sharing_manager.revoke_resource_access(controller_adventurer_id, resource_key, grantee_adventurer_id)`
- `sharing_manager.set_resource_share_rule(controller_adventurer_id, resource_key, recipient_adventurer_id, rule_kind, share_bp)`
- `sharing_manager.clear_resource_share_rule(controller_adventurer_id, resource_key, recipient_adventurer_id, rule_kind)`

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
- `v_mine_state`
- `v_mining_shift_state`
- `v_mine_access_state`
- `v_construction_project_state`
- `v_building_state`
- `v_resource_policy_state`
- `v_resource_access_grant_state`
- `v_resource_share_rule_state`

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
- mining quote:
  - current `mine_stress` vs `collapse_threshold`
  - `continue` vs `stabilize` expected value with collapse risk
- construction quote:
  - `completion_block - now_block` for active projects
  - upkeep due estimate from `upkeep_per_100_blocks` and elapsed blocks

## Follow This Action Priority

For each adventurer, evaluate in order:

1. If dead, emit `no-op`.
2. If defending owned hex is possible and active claim exists, defend.
3. If a high-value claimable hex is available and energy >= min claim, initiate claim.
4. If controlling decaying hex and maintenance has best ROI, pay maintenance.
5. If harvest is active and mature, complete harvest.
6. If harvest is active but low EV to wait, cancel harvest.
7. If mining shift is active, choose `continue`, `stabilize`, `exit`, or `repair`.
8. If construction project is mature, complete construction.
9. If inventory is overweight or conversion ROI is high, convert items.
10. If unlocked and enough energy, start harvest or start construction.
11. If expansion EV is high, move/discover hex and discover area.
12. Otherwise wait and re-evaluate next block window.

## Enforce These Guardrails

- Never issue actions for dead adventurers.
- Never trust stale indexer state; compare indexer head to RPC block and set a max lag.
- Never convert items while at energy cap unless intentional (items burn even if minted energy is zero).
- Never attempt second active claim with energy already locked in escrow.
- Never pass caller-defined generation payloads for discovery/harvest init; world and plant profiles are deterministic onchain.
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
  - mining: `MineInitialized`, `MineAccessGranted`, `MiningStarted`, `MiningContinued`, `MineStabilized`, `MiningExited`, `MineCollapsed`
  - construction: `ConstructionStarted`, `ConstructionCompleted`, `ConstructionUpkeepPaid`, `ConstructionRepaired`, `ConstructionUpgradeQueued`, `ConstructionPlantProcessed`
  - sharing: `ResourcePolicyUpserted`, `ResourceAccessGranted`, `ResourceAccessRevoked`, `ResourceShareRuleSet`, `ResourceShareRuleCleared`
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
