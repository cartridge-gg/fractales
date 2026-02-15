# Infinite Hex Adventurers - Master Documentation

This file is the canonical entrypoint for the project documentation.

## 1. Canonical Scope

### MVP (authoritative)
The MVP is defined by:
- `docs/02-spec/mvp-functional-spec.md`

MVP includes:
- Adjacent hex exploration and area discovery
- Adventurer creation/movement/energy/activity locks/backpack basics with true permadeath
- Cube-coordinate world model with origin-centered API and codec-backed felt storage
- Harvesting initialization and time-locked harvest flow
- Item-to-energy conversion
- Territorial upkeep, decay, and claim/defend loops

MVP excludes (post-MVP):
- Mining/crafting/buildings
- AI agent service
- Complex hook ecosystems
- Full ERC-721 ownership contract (model parity only)

### Vision (long-term)
Long-term product vision and mechanics live in:
- `docs/01-foundation/game-design-v0.3.md`
- `docs/00-context/quick-overview.md`

## 2. Documentation Structure

### `docs/00-context/`
- `quick-overview.md`: Narrative, high-level pitch, and fast onboarding

### `docs/01-foundation/`
- `game-design-v0.3.md`: Full game design document (vision + major systems)
- `world-generation-and-systems.md`: Deep world/system pseudocode and mechanics

### `docs/02-spec/`
- `mvp-functional-spec.md`: TDD-ready functional MVP spec (authoritative for implementation)
- `design-decisions.md`: Locked design decisions used to align cross-document behavior

### `docs/03-architecture/`
- `contract-architecture.md`: Contract/system decomposition and interfaces
- `action-framework.md`: Universal action dispatch/module interface model
- `hooks-and-permissions.md`: Generalized hook/permission architecture
- `ownership-and-nfts.md`: Discovery ownership + NFT design
- `adventurer-system.md`: Adventurer trait/progression architecture
- `adventurer-hooks.md`: Adventurer behavior hooks/autonomy concepts
- `architecture-diagrams.md`: Mermaid architecture diagrams
- `architecture-review.md`: Architecture status review and change analysis

### `docs/04-economy/`
- `economic-stability.md`: Anti-inflation and territorial energy economics
- `economic-simulator-spec.md`: 10k-adventurer off-chain simulator spec for stress-testing the MVP economic loop
- `bootstrap-world-scenario-matrix-spec.md`: 8-week bootstrap scenario matrix, elastic adventurer pricing controls, and simulator implementation contract
- `autoregulator-prd-tdd.md`: Permissionless onchain autoregulator with keeper bounty and TDD implementation plan

### `docs/05-modules/`
- `mining.md`: Mining module design
- `construction.md`: Construction/infrastructure module design

### `docs/06-platform/`
- `ai-service-architecture.md`: Off-chain AI service architecture and APIs

### `docs/07-delivery/`
- `agent-handoff.md`: Agent operating contract (commands, PR rules, escalation, and parallel ownership boundaries)
- `dojo-mvp-prd.md`: Detailed build PRD (model-first implementation, system sequencing, contract tightness, and test strategy)
- `dojo-mvp-implementation-checklist.md`: File-by-file implementation checklist and stage exit gates
- `mvp-prioritized-implementation-plan.md`: Execution-priority plan (`P0/P1/P2`) with edge-case hardening order
- `deterministic-generation-plan.md`: Deterministic seed/noise rollout plan for hex -> area -> plant generation
- `mining-fractal-prd-tdd.md`: Post-MVP deterministic mining PRD with TDD milestones and collapse dilemma loop
- `construction-balance-scope.md`: 7-building construction balance envelope, thresholds, and simulator workflow
- `construction-prd-tdd.md`: Construction module implementation PRD/TDD slices mapped to game files
- `resource-sharing-permissions-prd-tdd.md`: Detailed PRD/TDD rollout for cross-module ACL + deterministic resource sharing
- `biome-20-expansion-checklist.md`: Execution checklist for 20-biome generation/profile rollout and guardrails
- `development-plan.md`: Phased implementation plan
- `dojo-setup-guide.md`: Dojo environment setup and patterns

### `docs/archive/`
- `game-summary-legacy.md`: Legacy summary retained for reference

## 3. Canonical Reading Order

1. `docs/02-spec/mvp-functional-spec.md`
2. `docs/02-spec/design-decisions.md`
3. `docs/01-foundation/game-design-v0.3.md`
4. `docs/01-foundation/world-generation-and-systems.md`
5. `docs/03-architecture/contract-architecture.md`
6. `docs/07-delivery/agent-handoff.md`
7. `docs/07-delivery/dojo-mvp-prd.md`
8. `docs/07-delivery/dojo-mvp-implementation-checklist.md`
9. `docs/07-delivery/mvp-prioritized-implementation-plan.md`
10. `docs/07-delivery/development-plan.md`

## 4. Duplication Policy

- The MVP functional spec is the implementation source of truth.
- Other docs can expand on vision and future design, but should not override MVP behavior unless explicitly updated in `docs/02-spec/mvp-functional-spec.md`.
- Major duplicated sections in world systems docs have been trimmed to a single retained version.
- Legacy summaries are moved to `docs/archive/` rather than duplicated in active sections.

## 5. Maintenance Rules

When adding or changing behavior:
1. Update `docs/02-spec/mvp-functional-spec.md` if it affects MVP behavior.
2. Update architecture docs under `docs/03-architecture/` if interfaces/models/systems change.
3. Update this file if navigation, canonical scope, or folder structure changes.
