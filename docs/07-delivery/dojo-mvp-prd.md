# Dojo MVP PRD - Infinite Hex Adventurers

## 1. Document Purpose

This PRD defines a build-ready plan to implement the locked MVP in Dojo using a model-first approach, then focused systems, while keeping contracts small, testable, and maintainable.

Canonical references:
- `docs/02-spec/mvp-functional-spec.md`
- `docs/02-spec/design-decisions.md`

## 2. Product Goals (MVP)

Primary goals:
- Deliver the complete MVP gameplay loop:
  discover hex -> discover area -> initialize harvest -> start/complete harvest -> convert items to energy -> maintain hex -> decay -> claim/defend.
- Enforce true permadeath in MVP.
- Use cube-coordinate world model with deterministic felt codec.
- Keep contracts modular and tight to avoid oversized class artifacts and brittle code paths.
- Achieve high confidence via tight unit testing plus focused integration tests.

Success criteria:
- All acceptance criteria in `docs/02-spec/mvp-functional-spec.md` pass.
- Each system has isolated unit tests for core invariants and edge cases.
- End-to-end flows pass under local Dojo test environment.

## 3. Scope

In scope:
- World discovery and movement (adjacent only)
- Adventurer lifecycle (create, energy, activity lock, permadeath)
- Harvesting core (init/start/progress/complete/cancel/inspect)
- Economy core (conversion, maintenance, decay)
- Ownership core (model parity, claim/defend transfer logic)
- Events required for Torii indexing

Out of scope (post-MVP):
- Mining, crafting, construction
- AI play agent service
- Advanced hook ecosystems
- Full ERC-721 ownership contract

## 4. Non-Functional Requirements

### 4.1 Contract Size and Cohesion

Requirements:
- One clear domain per system contract.
- Prefer pure library functions for formulas and codecs.
- Limit public/external entrypoints to domain essentials only.
- Avoid "god contracts" that mix world, adventurer, harvesting, and economics logic.

Operational guardrails:
- If a contract grows beyond maintainable cohesion, split by domain behavior (not by random utility grouping).
- If an entrypoint requires many unrelated writes, move part of the workflow to a domain helper and keep orchestration explicit.
- Keep event schemas domain-local and predictable.

### 4.2 Determinism and Safety

Requirements:
- Deterministic generation for biome views and module-seeded content.
- Deterministic coordinate codec for cube<->felt conversion.
- No negative balances, no overflows, no duplicate discovery state.
- Irreversible death semantics.

### 4.3 Testing Quality Bar

Requirements:
- Unit tests for each model-writing path and each formula path.
- Property/fuzz style tests for arithmetic monotonicity and bounds.
- Integration tests for canonical loops and failure paths.

## 5. Target Dojo Project Structure

```text
game/
  src/
    lib.cairo
    models/
      world.cairo
      adventurer.cairo
      inventory.cairo
      harvesting.cairo
      economics.cairo
      ownership.cairo
      deaths.cairo
      mod.cairo
    systems/
      world_manager.cairo
      adventurer_manager.cairo
      harvesting_manager.cairo
      economic_manager.cairo
      ownership_manager.cairo
      mod.cairo
    libs/
      coord_codec.cairo
      math_bp.cairo
      adjacency.cairo
      harvesting_math.cairo
      decay_math.cairo
      conversion_math.cairo
      mod.cairo
    events/
      world_events.cairo
      adventurer_events.cairo
      harvesting_events.cairo
      economic_events.cairo
      ownership_events.cairo
      mod.cairo
    tests/
      unit/
      integration/
      fixtures/
```

Notes:
- Keep formulas in `libs/` so they can be unit-tested independently.
- Keep models lean and normalized; avoid redundant denormalized fields unless required for query performance.

## 6. Model-First Delivery Plan

## Stage M0 - Shared Types and Codecs

Deliverables:
- Shared domain type aliases (`AdventurerId`, `AreaId`, `HexCoordinate`).
- Cube coordinate struct and felt codec library.
- Basis-point math helpers (`1e4`, floor rounding).

Acceptance criteria:
- Round-trip codec tests pass for representative coordinate ranges.
- Adjacency utility tests pass for cube neighbors.

## Stage M1 - World and Discovery Models

Models:
- `World.Hex`
- `World.HexArea`

Rules:
- Hex uniqueness by encoded coordinate key.
- Area uniqueness by deterministic area id strategy.

Acceptance criteria:
- Duplicate discovery attempts do not duplicate state.
- Discoverer and block metadata remain immutable after first write.

## Stage M2 - Adventurer and Death Models

Models:
- `Adventurer.Adventurer`
- `Adventurer.Inventory`
- `Adventurer.BackpackItem`
- `Adventurer.DeathRecord`

Rules:
- Alive/dead state is monotonic (alive -> dead only).
- Dead adventurers cannot be reused.

Acceptance criteria:
- Permadeath tests prove irreversibility.
- Inventory clear/loss path is deterministic on death.

## Stage M3 - Harvesting Models

Models:
- `Harvesting.PlantNode`

Rules:
- Yield bounded `[0, max_yield]`.
- Stress/health bounded in expected ranges.

Acceptance criteria:
- Regrowth/update functions satisfy bounds and monotonic expectations.
- Harvest start/complete model transitions are valid.

## Stage M4 - Economics and Ownership Models

Models:
- `Economics.AdventurerEconomics`
- `Economics.ConversionRate`
- `Economics.HexDecayState`
- `Ownership.AreaOwnership`

Rules:
- Decay progression is monotone under deficit.
- Ownership transfer only through allowed paths.

Acceptance criteria:
- Conversion and decay math tests pass edge/boundary cases.
- Claim/defend ownership transitions are validated.

## 7. System Implementation Plan (After Models)

## Stage S1 - WorldManager

Responsibilities:
- Adjacent movement validation
- Hex discovery
- Area discovery
- Biome deterministic view

Must not include:
- Harvest yield logic
- Economics conversion/decay
- Death handling beyond guard checks

Key entrypoints:
- `discover_hex`
- `discover_area`
- `move_adventurer`

Unit test focus:
- adjacency checks
- idempotency
- first-discoverer invariants

## Stage S2 - AdventurerManager

Responsibilities:
- Adventurer create/read lifecycle
- Energy spend/regen
- Activity lock management
- Permadeath execution

Must not include:
- Discovery generation
- Claim/defend resolution
- Harvesting formulas

Key entrypoints:
- `create_adventurer`
- `consume_energy`
- `regenerate_energy`
- `kill_adventurer`

Unit test focus:
- lock exclusivity
- energy bounds
- death finality and action rejection for dead actors

## Stage S3 - HarvestingManager

Responsibilities:
- Harvest module init
- Harvest start/progress/complete/cancel
- Plant inspection/status updates

Must not include:
- Conversion market logic
- Ownership transfer

Key entrypoints:
- `init_harvesting`
- `start_harvesting`
- `complete_harvesting`
- `inspect_plant`

Unit test focus:
- start preconditions
- yield/stress/health transitions
- partial cancel semantics

## Stage S4 - EconomicManager

Responsibilities:
- Item-to-energy conversion
- Maintenance payments
- Decay progression
- Claim/defend resolution hooks

Must not include:
- Movement/discovery
- Harvest process details

Key entrypoints:
- `convert_items_to_energy`
- `pay_hex_maintenance`
- `process_hex_decay`
- `initiate_hex_claim`
- `defend_hex_from_claim`

Unit test focus:
- conversion math (including penalties)
- decay thresholds
- claimability and grace-window behavior

## Stage S5 - OwnershipManager

Responsibilities:
- ownership queries
- ownership transfer logic for MVP claim/defend outcomes

Must not include:
- full ERC-721 semantics
- unrelated economics

Key entrypoints:
- `get_owner`
- `transfer_ownership` (restricted in MVP)

Unit test focus:
- ownership integrity
- authorized transfer paths only

## 8. Contract Tightness Strategy

Patterns to enforce:
- Domain services over shared mutable mega-structs.
- Pure libs for math/codec and minimal wrappers in systems.
- Narrow interfaces with explicit args and return types.
- No hidden cross-domain writes; every cross-domain dependency is explicit.

Refactor triggers:
- System has too many unrelated entrypoints.
- System tests require large fixture setup across multiple domains.
- Multiple bugs originate from mixed responsibilities in a single file.

## 9. Test Strategy (Tight Unit First)

## 9.1 Unit Tests

Per-domain suites:
- `unit/coord_codec_test.cairo`
- `unit/world_manager_test.cairo`
- `unit/adventurer_manager_test.cairo`
- `unit/harvesting_manager_test.cairo`
- `unit/economic_manager_test.cairo`
- `unit/ownership_manager_test.cairo`
- `unit/math_bp_test.cairo`

Required test types:
- happy path
- precondition failure
- boundary conditions
- invariant preservation after state transitions

## 9.2 Property/Fuzz-Oriented Tests

Focus areas:
- conversion monotonicity under bounded penalties
- no-negative balance invariants
- regrowth/yield bounds
- codec round-trip stability

## 9.3 Integration Tests

Canonical flows:
- Discover -> Area -> Harvest -> Convert -> Maintain
- Neglect -> Decay -> Claimable -> Claim/Defend
- Death during progression blocks all further actions

## 9.4 Exit Gates

No stage advances unless:
- unit tests for that stage pass
- required invariants are asserted in tests
- event payload snapshots are stable

## 10. Work Breakdown (Implementation Tickets)

Epic A: Foundation and Model Layer
- A1: Shared types + cube codec + bp math libs
- A2: World/area models
- A3: Adventurer/inventory/death models
- A4: Harvesting/economics/ownership models

Epic B: Core Systems
- B1: WorldManager
- B2: AdventurerManager
- B3: HarvestingManager
- B4: EconomicManager
- B5: OwnershipManager

Epic C: Integration and Hardening
- C1: Event indexing validation
- C2: Integration test suite
- C3: Performance profiling and optimization
- C4: Documentation lock and acceptance review

## 11. Risks and Mitigations

Risk: Contract bloat from cross-domain logic.
- Mitigation: strict domain boundaries and refactor triggers.

Risk: Arithmetic bugs from percentage math.
- Mitigation: basis-point standard + centralized math lib tests.

Risk: Inconsistent coordinate behavior.
- Mitigation: single cube codec lib + mandatory round-trip tests.

Risk: Death semantics bypassed in one path.
- Mitigation: centralized alive-guard helper + death regression tests.

## 12. Definition of Done (MVP)

MVP is done when:
- All acceptance criteria in `docs/02-spec/mvp-functional-spec.md` pass.
- Decision-locked rules in `docs/02-spec/design-decisions.md` are reflected in code and tests.
- System contracts remain cohesive and domain-focused.
- Unit and integration suites are green in local Dojo CI workflow.
