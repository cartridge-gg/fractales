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

As of `2026-02-13`, the active public Slot deployment is:

- Slot project: `gen-dungeon-live-20260213b`
- Katana RPC: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/katana`
- Torii HTTP: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/torii`
- Torii GraphQL: `https://api.cartridge.gg/x/gen-dungeon-live-20260213b/torii/graphql`
- World address: `0x00f3d3b78a41b212442a64218a7f7dbde331813ea09a07067c7ad12f93620c11`

Live release and how-to-play runbook:
- `07-delivery/releases/2026-02-13-gen-dungeon-live-20260213b.md`

## Canonical Sources

- MVP source of truth: `02-spec/mvp-functional-spec.md`
- Locked behavior decisions: `02-spec/design-decisions.md`
- Vision and future systems: `01-foundation/game-design-v0.3.md`
- High-level overview: `00-context/quick-overview.md`

## Recommended Reading Order

1. `02-spec/mvp-functional-spec.md`
2. `02-spec/design-decisions.md`
3. `01-foundation/game-design-v0.3.md`
4. `01-foundation/world-generation-and-systems.md`
5. `03-architecture/contract-architecture.md`
6. `07-delivery/dojo-mvp-prd.md`
