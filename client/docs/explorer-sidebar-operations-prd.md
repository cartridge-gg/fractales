# Gen Dungeon Explorer Sidebar Operations PRD

Status: Draft  
Last updated: 2026-02-17  
Owners: Client Platform + Game Infra

## 1. Purpose

Define a build-ready scope to make the right sidebar show the core game loop clearly:
- assign adventurers to area/mine work
- observe active mining/harvest work states
- see produced resources and recent production events

This PRD is focused on read-path + UI observability only (no writes/transactions).

## 2. Canonical Inputs

- `../../docs/02-spec/design-decisions.md`
- `../../docs/07-delivery/mining-fractal-prd-tdd.md`
- `./explorer-prd.md`
- `./explorer-tdd-plan.md`
- `./explorer-milestone-issue-backlog.md`
- `../typescript/models.gen.ts`

## 3. Problem Statement

Current inspect sidebar is a broad model dump. It is complete but not loop-oriented.
Operators can read raw rows, but cannot quickly answer:
1. Which adventurers are currently assigned to productive work?
2. Which areas/mine slots are active, blocked, collapsed, or idle?
3. What is being produced right now, by whom, and at what pace?

## 4. Goals and Non-Goals

### 4.1 Goals

- Show assignment and production state in one glance for selected hex.
- Preserve deterministic, typed data flow from indexer -> proxy -> UI.
- Keep compact mode optimized for gameplay operations; keep full mode for raw debugging.
- Support both harvest and mining loops in a single inspect contract.

### 4.2 Non-Goals

- No explorer-triggered onchain writes.
- No map renderer redesign.
- No historical replay/time scrubber.
- No economy balancing changes.

## 5. Users and Jobs

Primary users:
- Player/operator monitoring territory production.
- Spectator tracking live activity.
- Internal debugging of world state transitions.

Jobs to be done:
- "Show me who is working where in this hex."
- "Show me which slot is productive vs blocked/collapsed."
- "Show me output and most recent production events."

## 6. Sidebar Product Scope

### 6.1 Modes

- `compact` (default): loop-first operational cards.
- `full`: compact cards + raw field cards.

### 6.2 Compact Card Stack (Top to Bottom)

1. `Hex Hero`  
   Existing identity/status summary.

2. `Operations Summary`  
   Metrics:
   - adventurers present
   - active harvest reservations
   - active mining shifts
   - initialized mines
   - collapsed/depleted mine count
   - total unbanked ore in active shifts

3. `Area Slots`  
   One row per discovered area in hex:
   - `area_index`, `area_type`
   - `plant_slots_initialized / plant_slot_count`
   - `initialized_mines` (and optional total if available)
   - `active_workers` in area (harvest + mining)

4. `Mine Operations`  
   One row per `MineNode` in selected hex:
   - `mine_id`, `area_id`
   - status (`active`, `collapsed`, `depleted`, `idle`)
   - `active_miners`
   - `remaining_reserve`
   - `mine_stress / collapse_threshold`
   - `repair_energy_needed`

5. `Adventurer Assignments`  
   One row per adventurer relevant to selected hex:
   - `adventurer_id`
   - activity (`mining`, `harvesting`, `idle`)
   - assignment target (`mine_key` or `plant_key`)
   - energy and lock status
   - unbanked ore (if mining)

6. `Production Feed`  
   Recent relevant events for selected hex, prioritized to production and assignment:
   - `MiningStarted`, `MiningContinued`, `MiningExited`, `MineCollapsed`, `MineRepaired`
   - `HarvestingStarted`, `HarvestingCompleted`, `HarvestingCancelled`
   - `ItemsConverted`
   Sorted deterministically and rendered with stable position tuple.

### 6.3 Empty and Partial States

- No selected hex: existing empty-state shell.
- No mining rows: show explicit `No mine operations in this hex.`
- Unknown mine slot denominator: show `initialized only` without misleading total.

## 7. Data Contract Scope

## 7.1 `HexInspectPayload` Extensions

Add mining model families:
- `mineNodes: MineNode[]`
- `miningShifts: MiningShift[]`
- `mineAccessGrants: MineAccessGrant[]`
- `mineCollapseRecords: MineCollapseRecord[]`

Add optional computed summaries (proxy/runtime-derived):
- `areaOperationSummaries?: AreaOperationSummary[]`
- `assignmentSummaries?: AdventurerAssignmentSummary[]`

These computed fields are optional in v1; UI can derive from raw rows if absent.

## 7.2 Runtime/Proxy Query Scope

Live snapshot query must include:
- `dojoStarterMineNodeModels`
- `dojoStarterMiningShiftModels`
- `dojoStarterMineAccessGrantModels`
- `dojoStarterMineCollapseRecordModels`

Proxy `getHex` continues to merge event tail deterministically and returns enriched inspect payload.

## 7.3 Deterministic Sort Rules

All UI tables must sort before render:
- areas: `(area_index ASC, area_id ASC)`
- mines: `(mine_id ASC, mine_key ASC)`
- shifts: `(status_rank, start_block DESC, adventurer_id ASC)`
- events: `(block_number DESC, tx_index DESC, event_index DESC)`

## 8. Functional Requirements

- `FR-SID-01`: compact mode must include Operations Summary, Area Slots, Mine Operations, Adventurer Assignments, Production Feed.
- `FR-SID-02`: assignment rows must map each adventurer to at most one active operation target in compact view.
- `FR-SID-03`: mine status must be derived from canonical fields (`repair_energy_needed`, `is_depleted`, active shifts/count).
- `FR-SID-04`: production feed must be deterministic and include event position tuple.
- `FR-SID-05`: rendering must remain HTML-escaped for all dynamic values.
- `FR-SID-06`: existing cards in full mode must remain available for debugging.

## 9. Non-Functional Requirements

- `NFR-SID-01`: no additional route round-trips beyond existing `getHex` call for sidebar payload.
- `NFR-SID-02`: compact card rendering remains bounded (`MAX_ROWS_PER_SECTION`) with explicit truncation indicator when exceeded.
- `NFR-SID-03`: selected-hex inspect refresh must react to patches touching the selected hex for operation-relevant model changes.

## 10. Risks and Mitigations

1. Risk: mine slot denominator is not persisted in current world area model.  
   Mitigation: v1 shows initialized mine slots and active mine assignments; denominator remains optional until canonical source is available.

2. Risk: larger snapshot query may increase latency.  
   Mitigation: maintain query limits, row caps, and proxy cache TTL; add perf gate in TDD plan.

3. Risk: enum serialization drift for mining status.  
   Mitigation: RED tests pin status mapping and rendering semantics.

## 11. Rollout Plan

### Phase P1: Contract + Read Path

- Extend DTOs and runtime/proxy payload mapping.
- Add mining models to live snapshot query.
- Add contract tests.

### Phase P2: Sidebar UX

- Implement compact operations cards.
- Add deterministic sorting and truncation messaging.
- Keep full mode unchanged except additional raw mining cards.

### Phase P3: Hardening

- Verify refresh behavior under stream patches.
- Add performance/reliability checks for high-density hex payloads.

## 12. Acceptance Criteria

1. Selecting a mining-active hex shows non-empty Mine Operations and Adventurer Assignments cards.
2. Active shift counts in Operations Summary equal count of `MiningShift.status == Active` rows for relevant mines.
3. Production Feed renders deterministic order with no duplicate rows.
4. Compact mode remains readable and stable on both desktop and mobile harness layouts.
5. Full mode still exposes raw cards and existing inspect debugging behavior.
