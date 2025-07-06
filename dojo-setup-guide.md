# Dojo Setup Guide: Infinite Hex Adventurers

## Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Dojo
curl -L https://install.dojoengine.org | bash
dojoup

# Verify installation
dojo --version
```

## Project Initialization

```bash
# Create new Dojo project
dojo init infinite-hex-adventurers
cd infinite-hex-adventurers

# Project structure will be:
# infinite-hex-adventurers/
#   Scarb.toml
#   dojo_dev.toml
#   src/
#     lib.cairo
#   scripts/
#   README.md
```

## Project Structure Setup

Create the recommended directory structure:

```bash
mkdir -p src/{models,systems,interfaces,events,tests}
```

### Final Structure:

```
src/
  lib.cairo                 # Main module declarations
  models/                   # Dojo models for persistent state
    mod.cairo              # Model module declarations
    hex.cairo              # Hex coordinate and world data
    adventurer.cairo       # Adventurer stats and state
    ownership.cairo        # Territory ownership data
    economic.cairo         # Energy and economic data
    harvesting.cairo       # Plant and harvesting state
  systems/                  # Game logic systems
    mod.cairo              # System module declarations
    game_registry.cairo    # Central coordination system
    world_manager.cairo    # World discovery and management
    adventurer_manager.cairo # Adventurer creation and progression
    economic_manager.cairo # Energy and economic systems
    area_ownership.cairo   # Territory ownership system
    harvesting.cairo       # Harvesting gameplay system
  interfaces/               # Shared traits and interfaces
    mod.cairo              # Interface module declarations
    universal_hook.cairo   # IUniversalHook trait
    action_module.cairo    # IActionModule trait
    common_types.cairo     # Shared data types
  events/                   # Event definitions
    mod.cairo              # Event module declarations
    discovery.cairo        # World discovery events
    ownership.cairo        # Ownership change events
    economic.cairo         # Economic transaction events
    harvesting.cairo       # Harvesting action events
  tests/                    # Test suites
    mod.cairo              # Test module declarations
    integration/           # Cross-system integration tests
    unit/                  # Individual system unit tests
```

## Configuration Files

### `Scarb.toml`

```toml
[package]
name = "infinite-hex-adventurers"
version = "0.1.0"
edition = "2023_11"

[dependencies]
dojo = { git = "https://github.com/dojoengine/dojo" }

[[target.dojo]]

[tool.dojo]
world = "infinite_hex_adventurers"

[tool.dojo.env]
rpc_url = "http://localhost:5050/"
account_address = "0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca"
private_key = "0x2bbf4f9fd0bbb2e60b0316c1fe0b76cf7a4d0198bd493ced9b8df2a3a24d68a"
```

### `dojo_dev.toml`

```toml
[world]
name = "infinite_hex_adventurers"
description = "An infinite procedurally-generated hex grid game with discovery-based property rights"
cover_uri = "file://assets/cover.png"
icon_uri = "file://assets/icon.png"
website = "https://infinite-hex-adventurers.com"
socials.x = "https://twitter.com/infinitehexadv"

[environment]
katana_rpc_url = "http://localhost:5050"
katana_account_address = "0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca"
katana_private_key = "0x2bbf4f9fd0bbb2e60b0316c1fe0b76cf7a4d0198bd493ced9b8df2a3a24d68a"

torii_rpc_url = "http://localhost:8080"
torii_graphql_url = "http://localhost:8080/graphql"
torii_grpc_url = "http://localhost:8080/grpc"
```

## Basic Development Workflow

### 1. Start Local Development Environment

```bash
# Terminal 1: Start Katana (local Starknet node)
katana --dev

# Terminal 2: Build and migrate world
dojo build
dojo migrate --world 0x... # Use world address from katana output

# Terminal 3: Start Torii indexer
torii --world 0x... --rpc http://localhost:5050 --start-block 0
```

### 2. Development Commands

```bash
# Build the project
dojo build

# Run tests
dojo test

# Deploy to local Katana
dojo migrate

# Deploy to testnet (Sepolia)
dojo migrate --network sepolia

# Execute system call
dojo execute --world 0x... --system GameRegistry --call register_system
```

## Initial File Setup

### `src/lib.cairo`

```cairo
mod models {
    mod hex;
    mod adventurer;
    mod ownership;
    mod economic;
    mod harvesting;
}

mod systems {
    mod game_registry;
    mod world_manager;
    mod adventurer_manager;
    mod economic_manager;
    mod area_ownership;
    mod harvesting;
}

mod interfaces {
    mod universal_hook;
    mod action_module;
    mod common_types;
}

mod events {
    mod discovery;
    mod ownership;
    mod economic;
    mod harvesting;
}

#[cfg(test)]
mod tests {
    mod integration;
    mod unit;
}
```

### `src/models/mod.cairo`

```cairo
mod hex;
mod adventurer;
mod ownership;
mod economic;
mod harvesting;

use hex::Hex;
use adventurer::Adventurer;
use ownership::AreaOwnership;
use economic::EconomicData;
use harvesting::Plant;
```

### `src/systems/mod.cairo`

```cairo
mod game_registry;
mod world_manager;
mod adventurer_manager;
mod economic_manager;
mod area_ownership;
mod harvesting;

use game_registry::GameRegistry;
use world_manager::WorldManager;
use adventurer_manager::AdventurerManager;
use economic_manager::EconomicManager;
use area_ownership::AreaOwnership;
use harvesting::Harvesting;
```

## Testing Setup

### Basic Test Structure

```cairo
#[cfg(test)]
mod tests {
    use super::{GameRegistry, WorldManager, AdventurerManager};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    #[test]
    fn test_basic_world_setup() {
        let world = spawn_test_world(array![]);

        // Deploy systems
        let game_registry = deploy_contract(world, GameRegistry::TEST_CLASS_HASH);
        let world_manager = deploy_contract(world, WorldManager::TEST_CLASS_HASH);

        // Test basic functionality
        assert(world.is_deployed(), 'World should be deployed');
    }
}
```

## Development Best Practices

### 1. Model Design

- Keep models simple and focused
- Use efficient storage patterns
- Consider query patterns for Torii indexing

### 2. System Design

- Each system should have a single responsibility
- Use world context for cross-system communication
- Emit events for important state changes

### 3. Testing Strategy

- Write unit tests for individual systems
- Integration tests for cross-system workflows
- Performance tests for scalability

### 4. Event Design

- Emit events for all significant state changes
- Include all necessary data for frontend indexing
- Use consistent event naming conventions

## Common Dojo Patterns

### Entity-Component Pattern

```cairo
// Define entity
let entity_id = world.uuid();

// Set components
set!(world, (
    Adventurer {
        entity_id,
        name: 'Alice',
        strength: 10
    },
    Position {
        entity_id,
        x: 0,
        y: 0
    }
));

// Query components
let adventurer = get!(world, entity_id, Adventurer);
let position = get!(world, entity_id, Position);
```

### System Communication

```cairo
// System A calls System B through world context
let world = self.world_dispatcher.read();
let system_b = ISystemBDispatcher { contract_address: world.contract_address };
system_b.do_something(param1, param2);
```

### Event Emission

```cairo
emit!(
    world,
    HexDiscovered {
        player: get_caller_address(),
        hex_coordinate: coord,
        biome: biome_type,
        discovery_block: get_block_number()
    }
);
```

This setup provides a solid foundation for building Infinite Hex Adventurers on Dojo, leveraging the framework's strengths for game development while maintaining clean architecture and extensibility.
