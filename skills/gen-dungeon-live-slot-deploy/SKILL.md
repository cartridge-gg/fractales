---
name: gen-dungeon-live-slot-deploy
description: Deploy Infinite Hex Adventurers to Slot (Katana and Torii), publish operator release notes, and include a tested player how-to-play runbook using sozo.
---

# Gen Dungeon Live Slot Deploy

Run releases as `preflight -> provision katana -> migrate -> initialize -> provision torii -> verify -> play smoke -> publish`.

## Current Live Snapshot

As of `2026-02-13`, the current deployed Slot instance is:

- `SLOT_PROJECT`: `gen-dungeon-live-20260213b`
- `RPC`: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/katana`
- `Torii HTTP`: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/torii`
- `Torii GraphQL`: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/torii/graphql`
- `DOJO_WORLD_ADDRESS`: `0x00f3d3b78a41b212442a64218a7f7dbde331813ea09a07067c7ad12f93620c11`

## Collect Inputs

Require these inputs before running commands:

- `SLOT_PROJECT`: Slot project name.
- `SLOT_TEAM`: Slot team name (omit `--team` if using default team).
- `DEPLOY_TIER`: `basic`, `pro`, `epic`, or `legendary`.
- `RELEASE_TAG`: release label, for example `v0.1.0-live`.
- `GAME_DIR`: contracts directory, default `game`.
- `KATANA_CONFIG`: Katana config path, default `game/slot_katana.toml`.
- `TORII_CONFIG`: generated Torii config path, default `game/torii_slot_live.toml`.
- `KATANA_FORK_PROVIDER_URL` (optional): only required when using `--optimistic`.

If any required value is missing, stop and ask for it.

## Run Preflight

1. Verify tooling:
```bash
slot --version
sozo --version
scarb --version
```
2. Verify Slot auth:
```bash
slot auth info
```
3. Verify contracts build:
```bash
cd "$GAME_DIR"
sozo build
```
4. Verify target deployment state (if rotating existing project):
```bash
slot deployments describe "$SLOT_PROJECT" katana
slot deployments describe "$SLOT_PROJECT" torii
```

If live API calls fail due environment/network restrictions, stop and ask the user to run Slot API commands locally and paste results.

## Provision Slot Katana

Create Katana first.

```bash
# Minimal non-optimistic config is valid.
printf "# empty\n" > "$KATANA_CONFIG"

slot deployments create "$SLOT_PROJECT" katana \
  --team "$SLOT_TEAM" \
  --tier "$DEPLOY_TIER" \
  --config "$KATANA_CONFIG"
```

Use optimistic mode only when you have a healthy fork provider:

```bash
slot deployments create "$SLOT_PROJECT" katana \
  --team "$SLOT_TEAM" \
  --tier "$DEPLOY_TIER" \
  --optimistic \
  --fork-provider-url "$KATANA_FORK_PROVIDER_URL"
```

Capture Katana metadata:

```bash
slot deployments describe "$SLOT_PROJECT" katana
slot deployments logs "$SLOT_PROJECT" katana --limit 50
slot deployments accounts "$SLOT_PROJECT" katana
```

## Migrate World With Sozo

Export deploy environment:

```bash
export STARKNET_RPC_URL="<slot-katana-rpc-url>"
```

Run migration with explicit high gas bounds (required on current Slot Katana):

```bash
cd "$GAME_DIR"
sozo migrate \
  --rpc-url "$STARKNET_RPC_URL" \
  --katana-account katana0 \
  --l1-gas 2000000 \
  --l1-gas-price 100000000000 \
  --l1-data-gas 2000000 \
  --l1-data-gas-price 100000000000 \
  --l2-gas 15000000000 \
  --l2-gas-price 100000000000 \
  --wait
```

Capture world address:

```bash
export DOJO_WORLD_ADDRESS="$(jq -r '.world.address' manifest_dev.json)"
echo "$DOJO_WORLD_ADDRESS"
```

Initialize active world generation config:

```bash
sozo execute dojo_starter-world_gen_manager initialize_active_world_gen_config \
  0x574f524c445f47454e5f534545445f5631 2200 2200 2200 3 3 3 \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL" \
  --katana-account katana0 \
  --l1-gas 2000000 \
  --l1-gas-price 100000000000 \
  --l1-data-gas 2000000 \
  --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 \
  --l2-gas-price 100000000000 \
  --wait
```

## Provision Slot Torii

Generate Torii config using live RPC/world and deploy:

```bash
cat > "$TORII_CONFIG" <<EOF2
rpc = "$STARKNET_RPC_URL"
world_address = "$DOJO_WORLD_ADDRESS"

[indexing]
contracts = [
  "erc20:0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
  "erc20:0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
]

[sql]
historical = [
  "dojo_starter-HexDiscovered",
  "dojo_starter-AreaDiscovered",
  "dojo_starter-HarvestingStarted",
  "dojo_starter-WorldGenConfigInitialized",
]
EOF2

slot deployments create "$SLOT_PROJECT" torii \
  --team "$SLOT_TEAM" \
  --tier "$DEPLOY_TIER" \
  --config "$TORII_CONFIG"

slot deployments describe "$SLOT_PROJECT" torii
slot deployments logs "$SLOT_PROJECT" torii --limit 50
```

## Verify Release

Run minimum onchain checks:

```bash
cd "$GAME_DIR"
sozo model get dojo_starter-WorldGenConfig 2 \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL"

sozo call dojo_starter-world_gen_manager get_active_world_gen_config \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL"
```

Optional smoke write check:

```bash
sozo execute dojo_starter-adventurer_manager create_adventurer sstr:'SCOUT' \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL" \
  --katana-account katana0 \
  --l1-gas 2000000 \
  --l1-gas-price 100000000000 \
  --l1-data-gas 2000000 \
  --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 \
  --l2-gas-price 100000000000 \
  --wait
```

## Play Live Loop With Sozo

Use this exact command flow when publishing player instructions. This flow has been executed live on Slot and verified with onchain reads.

```bash
# Required env
export STARKNET_RPC_URL="https://api.cartridge.gg/x/<project>/katana"
export DOJO_WORLD_ADDRESS="<world-address>"

# Recommended pre-encoded adjacent hex from origin (cube 1,-1,0)
export TARGET_HEX="0x400005fffff00000"

# 1) Create adventurer (choose one account, e.g. katana2)
sozo execute dojo_starter-adventurer_manager create_adventurer sstr:'BOT2' \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL" \
  --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 \
  --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 \
  --wait

# 2) Read the latest block and extract adventurer_id from events in that block.
LATEST_BLOCK=$(sozo starknet block-number --rpc-url "$STARKNET_RPC_URL" | jq -r '.block_number')
sozo events \
  --world "$DOJO_WORLD_ADDRESS" \
  --rpc-url "$STARKNET_RPC_URL" \
  --from-block "$LATEST_BLOCK" \
  --to-block "$LATEST_BLOCK"

# 3) Discover adjacent hex, move there, discover area index 0 then 1.
sozo execute dojo_starter-world_manager discover_hex <ADVENTURER_ID> "$TARGET_HEX" \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-world_manager move_adventurer <ADVENTURER_ID> "$TARGET_HEX" \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-world_manager discover_area <ADVENTURER_ID> "$TARGET_HEX" 0 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-world_manager discover_area <ADVENTURER_ID> "$TARGET_HEX" 1 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

# 4) Read events for area_type and area_id; continue with the first PlantField area.
# In the live deployment, index 1 is a PlantField and emits a concrete area_id.

# 5) Init/start/complete harvesting for plant_id 0 and amount 1.
sozo execute dojo_starter-harvesting_manager init_harvesting "$TARGET_HEX" <PLANTFIELD_AREA_ID> 0 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-harvesting_manager start_harvesting <ADVENTURER_ID> "$TARGET_HEX" <PLANTFIELD_AREA_ID> 0 1 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

# Optionally trigger one cheap state write to advance block before completion.
sozo execute dojo_starter-adventurer_manager regenerate_energy <ADVENTURER_ID> \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-harvesting_manager complete_harvesting <ADVENTURER_ID> "$TARGET_HEX" <PLANTFIELD_AREA_ID> 0 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

# 6) Read BackpackItem from completion events to get item_id, then convert and pay maintenance.
sozo execute dojo_starter-economic_manager convert_items_to_energy <ADVENTURER_ID> <ITEM_ID> 1 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait

sozo execute dojo_starter-economic_manager pay_hex_maintenance <ADVENTURER_ID> "$TARGET_HEX" 5 \
  --world "$DOJO_WORLD_ADDRESS" --rpc-url "$STARKNET_RPC_URL" --katana-account katana2 \
  --l1-gas 2000000 --l1-gas-price 100000000000 --l1-data-gas 2000000 --l1-data-gas-price 100000000000 \
  --l2-gas 5000000000 --l2-gas-price 100000000000 --wait
```

## Publish Release Artifact

Create a release markdown file with these required fields:

- release tag and timestamp
- Slot project and service tier
- Katana RPC URL
- Torii endpoints
- world address
- deployer account address (never private key)
- exact commands run
- known limitations
- player how-to-play section

Use `references/release-and-play-template.md` as the default output template.

## Publish How To Play

Write player instructions for the MVP loop in plain language:

1. Create an adventurer.
2. Move to an adjacent hex and discover it.
3. Discover an area in that hex.
4. Initialize harvesting and complete one harvest.
5. Convert harvested items to energy.
6. Pay maintenance to avoid decay.
7. Defend territory or claim decayed territory.

Always include real endpoints (`RPC`, `Torii`, and `world address`) so players can connect immediately.

## Guardrails

- Do not publish private keys.
- Do not claim success from tx submission alone; include at least one state read verification.
- Do not hardcode world generation version assumptions; verify live config from chain (`WorldGenConfig` key `2`).
- Do not skip player instructions in release notes.
- If you hit `code=63` with `Missing latest block number`, avoid broken optimistic providers and create fresh Katana with `--config`.
- If you hit `InsufficientResourcesForValidate` or `Insufficient max L2Gas`, increase `--l2-gas` and retry.
