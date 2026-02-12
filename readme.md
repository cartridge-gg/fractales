# Infinite Hex Adventurers

## FRACTALES

```text
███████╗██████╗  █████╗  ██████╗████████╗ █████╗ ██╗     ███████╗███████╗
██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██║     ██╔════╝██╔════╝
█████╗  ██████╔╝███████║██║        ██║   ███████║██║     █████╗  ███████╗
██╔══╝  ██╔══██╗██╔══██║██║        ██║   ██╔══██║██║     ██╔══╝  ╚════██║
██║     ██║  ██║██║  ██║╚██████╗   ██║   ██║  ██║███████╗███████╗███████║
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
```

## Docs Summary

Infinite Hex Adventurers is a headless, on-chain game set in an infinite deterministic hex world where discovery drives ownership and economy.

- Canonical MVP source of truth is `docs/02-spec/mvp-functional-spec.md` plus `docs/02-spec/design-decisions.md` (locked decisions dated 2026-02-11).
- MVP core loop is: discover hex -> discover area -> initialize/start/complete harvesting -> convert items to energy -> pay territorial maintenance -> process decay -> claim/defend territory.
- MVP rules include adjacent-only movement, cube coordinates with felt codec storage, deterministic energy regen/spend, weight-based backpack limits, reservation-based harvesting, escrowed claims with timeout/refund lifecycle, and irreversible permadeath.
- MVP explicitly excludes mining, crafting, construction/buildings, advanced hooks, AI agent services, and full ERC-721 ownership contracts (these are documented as post-MVP design).
- Architecture direction is modular Dojo systems (`WorldManager`, `AdventurerManager`, `HarvestingManager`, `EconomicManager`, `OwnershipManager`) with strict domain boundaries, shared libs/codecs, and event-first indexing patterns.
- Delivery docs define a model-first implementation path (`M0`-`M4`, then `S1`-`S5`) with TDD gates, invariant/property tests, and a prioritized `P0`/`P1`/`P2` hardening plan.

Documentation is organized under `docs/`.

Start here:
- `docs/MASTER_DOC.md`

Authoritative MVP implementation scope:
- `docs/02-spec/mvp-functional-spec.md`
