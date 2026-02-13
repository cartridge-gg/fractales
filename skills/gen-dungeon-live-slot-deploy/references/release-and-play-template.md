# Infinite Hex Adventurers Live Release

## Release Metadata

- Release tag: `<RELEASE_TAG>`
- Date (UTC): `<YYYY-MM-DD HH:MM UTC>`
- Slot project: `<SLOT_PROJECT>`
- Tier: `<DEPLOY_TIER>`

## Live Endpoints

- Katana RPC: `<RPC_URL>`
- Torii HTTP: `<TORII_HTTP_URL>`
- Torii GraphQL: `<TORII_GRAPHQL_URL>`
- World address: `<DOJO_WORLD_ADDRESS>`

## Operator Notes

- Deployer account: `<DOJO_ACCOUNT_ADDRESS or katana0>`
- World deploy tx hash: `<TX_HASH>`
- World gen init tx hash: `<TX_HASH>`
- Verification command result: `WorldGenConfig key=2 readable`

## Commands Run

```bash
slot deployments create <SLOT_PROJECT> katana --config <KATANA_CONFIG>
sozo migrate --rpc-url <RPC_URL> --katana-account katana0 ... --wait
sozo execute dojo_starter-world_gen_manager initialize_active_world_gen_config ... --world <WORLD> --rpc-url <RPC_URL> --katana-account katana0 ... --wait
slot deployments create <SLOT_PROJECT> torii --config <TORII_CONFIG>
sozo model get dojo_starter-WorldGenConfig 2 --world <WORLD> --rpc-url <RPC_URL>
```

## Sozo Playthrough Tx Hashes

- Create adventurer: `<TX_HASH>`
- Discover hex: `<TX_HASH>`
- Move adventurer: `<TX_HASH>`
- Discover area: `<TX_HASH>`
- Init harvesting: `<TX_HASH>`
- Start harvesting: `<TX_HASH>`
- Complete harvesting: `<TX_HASH>`
- Convert items: `<TX_HASH>`
- Pay maintenance: `<TX_HASH>`

## How To Play (MVP)

1. Connect using the RPC + world address above.
2. Create your adventurer at origin `(0,0,0)`.
3. Move one hex away and discover that hex.
4. Discover an area in the hex to establish control context.
5. Initialize harvesting, then start and complete a harvest action.
6. Convert harvested items into energy.
7. Pay hex maintenance to keep territory healthy.
8. Watch decay levels; defend your hex or claim decayed hexes.

## Gameplay Loop Summary

`explore -> discover -> harvest -> convert -> maintain -> defend/claim -> repeat`

## Known Limitations

- MVP scope excludes advanced modules like mining/crafting/buildings for public gameplay loop docs.
- Actions are adjacency-gated and energy-gated.
- Permadeath is active for adventurers.

## Troubleshooting

- If transactions fail, confirm signer setup (`--katana-account` or account/private key pair) and RPC endpoint match.
- If reads fail, confirm `DOJO_WORLD_ADDRESS` is from the latest migration manifest.
- If Slot APIs fail, check `slot auth info` and team access permissions.
