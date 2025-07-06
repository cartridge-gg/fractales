# Development Plan: Infinite Hex Adventurers (Dojo Framework)

## Overview

This development plan follows a **foundation-first methodology** to build Infinite Hex Adventurers systematically using the **Dojo framework**. We start with Dojo world setup and core contracts, building up to a complete harvesting module as our first playable feature.

## Phase 1: Foundation Layer (Tasks 1-2)

### 1. Dojo Setup & Core Data Types

**Why First**: Everything depends on the Dojo world and shared data structures.

**Dojo Setup**:

- Initialize new Dojo project with `dojo init infinite-hex-adventurers`
- Configure `Scarb.toml` with proper dependencies
- Set up world configuration in `dojo_dev.toml`
- Create project structure following Dojo conventions

**Key Components**:

- **Dojo Models**: Shared data structures (HexCoordinate, AdventurerStats, etc.)
- **Core Traits**: `IUniversalHook<T>` and `IActionModule` interfaces
- **Base Systems**: Common functionality for all game systems
- **Events**: Standardized event emissions for indexing

**File Structure**:

```
src/
  models/        # Dojo models for persistent state
  systems/       # Game logic systems
  interfaces/    # Shared traits and interfaces
  events/        # Event definitions
  tests/         # Test suites
```

**Success Criteria**:

- Dojo world compiles successfully
- All models can be deployed and queried
- Shared traits can be imported by systems

### 2. GameRegistry System

**Why Second**: Central coordination hub that all other systems register with.

**Key Features**:

- System registration and versioning (Dojo systems)
- Module discovery and validation
- Access control and permissions
- World state coordination

**Dojo Integration**:

- Implements Dojo system pattern
- Uses world context for cross-system communication
- Leverages Dojo's built-in access control

**Success Criteria**: Can register systems, enforce permissions, and coordinate world state.

## Phase 2: Core Game Systems (Tasks 3-6)

### 3. WorldManager System

**Why Third**: Establishes the world coordinate system and hex discovery mechanics.

**Core Features**:

- Hex coordinate system using Dojo models
- Territory discovery mechanics
- Biome generation with deterministic RNG
- World state management through Dojo storage

**Dojo Patterns**:

- Uses `World` model for global state
- Hex data stored as Dojo models
- Emits discovery events for indexing

**Success Criteria**: Players can discover new hexes and query world state through Dojo.

### 4. AdventurerManager System

**Why Fourth**: Creates the player characters that interact with the world.

**Core Features**:

- Adventurer creation as Dojo entities
- 10 core traits system with progressive updates
- Trait progression through action execution
- Adventurer ownership and transfers

**Dojo Integration**:

- Each adventurer is a Dojo entity with models
- Trait updates use Dojo's efficient storage patterns
- Integrates with Dojo's event system

**Success Criteria**: Players can create adventurers with traits that improve through actions.

### 5. EconomicManager System

**Why Fifth**: Establishes the energy economy that drives all territorial mechanics.

**Core Features**:

- Energy currency using Dojo models
- Territorial maintenance cost calculations
- Universal energy conversion mechanics
- Anti-inflation price floor systems

**Dojo Patterns**:

- Energy balances stored as Dojo models
- Conversion rates updated through system calls
- Economic events emitted for analytics

**Success Criteria**: Energy economy functions with conversion rates and territorial costs.

### 6. AreaOwnership System

**Why Sixth**: Implements the core property rights system.

**Core Features**:

- Territory ownership using Dojo models (similar to ERC-721)
- Revenue tracking and distribution
- Hook system integration
- Ownership transfers and inheritance

**Dojo Implementation**:

- Uses Dojo's entity-component system for ownership
- Revenue streams calculated in system logic
- Integrates with hook system through world calls

**Success Criteria**: Players can own territories, receive revenue, and deploy hooks.

## Phase 3: First Playable Module (Tasks 7-8)

### 7. Harvesting System

**Why Harvesting First**:

- Simplest gameplay loop (discover → claim → harvest → profit)
- Tests all core systems integration
- Provides immediate player value

**Key Features**:

- Plant growth simulation with time-locked mechanics
- Yield calculations using Dojo's deterministic RNG
- Seasonal variations in productivity
- Integration with territorial ownership and energy costs

**Dojo Implementation**:

- Plant states stored as Dojo models
- Growth timers using block timestamps
- Harvesting actions as system calls
- Events for growth stages and harvests

**Game Loop**:

1. Adventurer discovers hex with harvestable plants (WorldManager call)
2. Player claims ownership through AreaOwnership system
3. Deploy harvesting through Harvesting system
4. Plants grow over time (model state updates)
5. Harvest mature plants via system calls
6. Pay territorial energy maintenance (EconomicManager)
7. Profit from continuous operations

**Success Criteria**: Complete discover → own → harvest → profit loop works end-to-end.

### 8. Integration Testing

**Why Critical**: Ensures all Dojo systems work together reliably.

**Test Coverage**:

- Multi-adventurer scenarios using Dojo test framework
- Economic edge cases with model state validation
- Territorial ownership conflicts
- Hook system integration across systems
- Performance optimization for Dojo world calls

**Dojo Testing**:

- Use `dojo test` for comprehensive system testing
- Test model state consistency across system calls
- Validate event emissions and indexing
- Performance testing for world scaling

**Success Criteria**: All harvesting workflows tested and optimized in Dojo environment.

## Phase 4: User Interface (Tasks 9-10)

### 9. Frontend Foundation

**Core Features**:

- **Torii Integration**: Connect to Dojo's GraphQL indexer
- Hex grid visualization using Dojo state
- Wallet connection (Starknet wallets)
- Real-time updates via Torii subscriptions

**Dojo Integration**:

- Use Dojo.js SDK for frontend integration
- Subscribe to model updates through Torii
- Execute system calls through Dojo client
- Handle Starknet transaction flows

### 10. Harvesting UI

**Key Features**:

- Interactive hex grid with discovery mechanics
- Territory ownership visualization from Dojo state
- Harvesting interface with real-time plant growth
- Economic dashboard (energy, revenue, costs)

**Dojo Frontend Patterns**:

- Real-time plant growth via Torii subscriptions
- State management using Dojo client
- Optimistic updates for better UX
- Event-driven UI updates

## Phase 5: Launch Preparation (Tasks 11-12)

### 11. Testing & Polish

- End-to-end testing using Dojo development tools
- Performance optimization for Katana (Dojo's local testnet)
- Security review of system permissions
- Dojo world migration testing

### 12. Deployment Setup

- Katana local development setup
- Testnet deployment using Dojo tooling
- Torii indexer configuration for production
- World migration and upgrade strategies

## Technical Methodology

### 1. Dojo-First Development

- All game logic in Dojo systems
- Frontend uses Torii for state queries
- Leverages Dojo's entity-component architecture
- Ensures provable, on-chain game state

### 2. System-Driven Design

- Each major feature is a Dojo system
- Systems communicate through world context
- Models define the data layer
- Events enable rich indexing and analytics

### 3. Modular Architecture

- Each system is self-contained
- Systems interact through world calls
- New features added as new systems
- Leverages Dojo's upgrade mechanisms

### 4. Test-Driven Development

- Comprehensive test suite using `dojo test`
- Integration tests across multiple systems
- Model state validation and consistency checks
- Performance testing for world scaling

## Dojo-Specific Advantages

### World State Management

- **Provable Game State**: All state is on-chain and verifiable
- **Efficient Storage**: Dojo's optimized storage patterns
- **Event Indexing**: Rich analytics via Torii indexer
- **Upgrade Mechanisms**: Built-in world upgrade pathways

### Developer Experience

- **Hot Reloading**: Fast iteration with Katana
- **GraphQL API**: Powerful queries via Torii
- **Type Safety**: Cairo's strong typing system
- **Testing Framework**: Comprehensive testing tools

### Player Experience

- **Real-time Updates**: Live state changes via subscriptions
- **Composability**: Other developers can build on our world
- **Transparency**: All game mechanics are open and verifiable
- **Performance**: Optimized for game-specific use cases

## Success Metrics for MVP

### Player Engagement

- Players can discover at least 10 different harvestable territories
- Average session includes full discovery → harvest cycle
- Players return to check on growing plants
- Real-time plant growth creates engagement

### Economic Viability

- Energy economy maintains stable conversion rates
- Territorial ownership generates positive ROI
- Anti-inflation mechanisms keep prices reasonable
- Revenue distribution works automatically

### Technical Performance

- All transactions complete efficiently on Starknet
- Frontend updates in real-time via Torii
- No critical bugs in core harvesting loop
- World state remains consistent across systems

## Future Module Pipeline

After harvesting MVP is complete, the Dojo foundation will support rapid development of:

1. **Mining System** - Resource extraction with geological surveys
2. **Crafting System** - Item creation and economic production chains
3. **Construction System** - Building infrastructure on owned territories
4. **Combat System** - Territorial disputes and adventurer battles
5. **Trading System** - Advanced marketplace with autonomous agents

This Dojo-native approach ensures each system is built on solid foundations, leveraging the framework's strengths for game development while maintaining the modularity and extensibility that will support infinite game expansion.
