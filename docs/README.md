# Infinite Hex Adventurers Docs

This folder contains the design, spec, and delivery docs for **Infinite Hex Adventurers**.

## What The Game Is

Infinite Hex Adventurers is a headless, on-chain game built on an infinite, deterministic hex world.

- Players create adventurers at origin `(0,0,0)`.
- The world is revealed through exploration and discovery.
- Discovery creates control and economic rights (modeled as ownership in MVP).
- The economy is energy-driven: actions consume energy, and territory control requires ongoing upkeep.
- Death is permanent for an adventurer in MVP, including inventory loss.

The long-term vision includes mining, crafting, facilities, and deeper player-built economies, but MVP is intentionally focused on the core loop below.

## Core Gameplay Loop (MVP)

1. Create adventurer and spawn at origin with starting energy.
2. Move to adjacent hexes and discover them (deterministic world materialization).
3. Discover areas inside a hex (control area establishes current hex controller).
4. Initialize plant nodes, then start and complete time-locked harvesting.
5. Convert harvested items into energy.
6. Pay hex maintenance from energy reserves.
7. Manage decay: neglected hexes become claimable at `decay >= 80`.
8. Defend your hex with energy or lose control to claimants.
9. Repeat by expanding, sustaining, and optimizing controlled territory.

Economic tension in MVP is simple and intentional: push expansion too hard and you cannot maintain territory; play too safely and growth stalls.

## Current Live Slot Deployment

As of `2026-02-17`, the active public Slot deployment is:

- Slot project: `gen-dungeon-live-20260215a`
- Katana RPC: `https://api.cartridge.gg/x/gen-dungeon-live-20260215a/katana`
- Torii HTTP: `https://api.cartridge.gg/x/gen-dungeon-live-20260215a/torii`
- Torii GraphQL: `https://api.cartridge.gg/x/gen-dungeon-live-20260215a/torii/graphql`
- World address: `0x00f3d3b78a41b212442a64218a7f7dbde331813ea09a07067c7ad12f93620c11`
- Katana config: `block_time = 1000`, `no_mining = false`

Latest redeploy verification (`2026-02-17`):

- `initialize_active_world_gen_config` tx: `0x071f43dd9db05546190f14d0d09de7841048ad0b8af5703acb65564e314bc65a`
- Smoke `create_adventurer` tx: `0x01545d3dcdcd60fe71bce35e37039c1afefc04874b4c21ea2a945aa3d7a51c8a`
- Runtime cadence check (`starkli block-number`, sampled `2026-02-17 22:12:42 UTC` through `22:12:52 UTC`): idle block number stayed constant (`102`), then moved to `103` only after the smoke tx at `23:23:38 UTC`.

## Agent Join Quickstart (Live Slot)

Use this when another agent needs to join the live world quickly.

1. Authenticate and verify access:

```bash
slot auth info
```

2. Pull the prefunded Katana accounts for this project:

```bash
slot deployments accounts gen-dungeon-live-20260215a katana
```

3. Export live environment variables:

```bash
export SLOT_PROJECT=gen-dungeon-live-20260215a
export KATANA_RPC=https://api.cartridge.gg/x/gen-dungeon-live-20260215a/katana
export TORII_HTTP=https://api.cartridge.gg/x/gen-dungeon-live-20260215a/torii
export TORII_GQL=https://api.cartridge.gg/x/gen-dungeon-live-20260215a/torii/graphql
export WORLD_ADDRESS=0x00f3d3b78a41b212442a64218a7f7dbde331813ea09a07067c7ad12f93620c11
```

4. Verify reads (RPC + Torii):

```bash
sozo model get dojo_starter-WorldGenConfig 2 --world $WORLD_ADDRESS --rpc-url $KATANA_RPC
curl -sS -X POST "$TORII_GQL" \
  -H 'content-type: application/json' \
  --data '{"query":"{ __typename }"}'
```

5. Send a smoke write tx:

```bash
sozo execute dojo_starter-adventurer_manager create_adventurer \
  0x414456454e5455524552 \
  --world $WORLD_ADDRESS \
  --rpc-url $KATANA_RPC \
  --katana-account katana1 \
  --wait
```

Core gameplay loop on live:

`create -> discover hex -> move -> discover area -> init/start/complete harvest -> convert -> maintain -> defend/claim`

## Canonical Sources

- MVP source of truth: `02-spec/mvp-functional-spec.md`
- Locked behavior decisions: `02-spec/design-decisions.md`
- Vision and future systems: `01-foundation/game-design-v0.3.md`
- High-level overview: `00-context/quick-overview.md`

## Post-MVP Loop Designs

- Mining loop PRD: `07-delivery/mining-fractal-prd-tdd.md`
- Construction loop (ore + plant, 7-building scope): `05-modules/construction.md`
- Construction balance scope + simulator workflow: `07-delivery/construction-balance-scope.md`
- Construction implementation PRD/TDD plan: `07-delivery/construction-prd-tdd.md`
- Resource-sharing permissions PRD/TDD plan: `07-delivery/resource-sharing-permissions-prd-tdd.md`

## Recommended Reading Order

1. `02-spec/mvp-functional-spec.md`
2. `02-spec/design-decisions.md`
3. `01-foundation/game-design-v0.3.md`
4. `01-foundation/world-generation-and-systems.md`
5. `03-architecture/contract-architecture.md`
6. `07-delivery/dojo-mvp-prd.md`
