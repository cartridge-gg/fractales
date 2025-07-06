# Contract Architecture: Infinite Hex Adventurers

## Design Principles

**🎯 DRY (Don't Repeat Yourself)**: Shared data models, common interfaces, reusable components  
**🔧 Modular**: Core systems separated from game modules for infinite extensibility  
**🪝 Hook-Driven**: Universal permission system works across all game objects  
**⚡ Gas Efficient**: Optimized storage patterns and batch operations  
**🔒 Secure**: Access control, validation, and state consistency

## Core Data Models

### Universal Types & Shared Structures

```python
# shared/types.cairo
# Core types used across all contracts

# Universal identifiers
type AdventurerId = felt252;
type HexCoordinate = felt252;  # Encoded (x,y) coordinates
type ItemId = felt252;
type ContractId = felt252;

# Shared enums
enum ActionResult:
    Success: (),
    Failed: felt252,      # Error message
    Pending: u64,        # Block when action completes

enum PermissionResult:
    Approved: (),
    Denied: felt252,     # Reason for denial
    RequiresPayment: (u32, ContractAddress), # Amount, recipient

# Universal time-based structures
struct TimeLockedAction:
    action_type: felt252,
    start_block: u64,
    completion_block: u64,
    parameters: Array<felt252>,
    can_cancel: bool,

# Universal item representation
struct ItemStack:
    item_type: felt252,
    quantity: u32,
    condition: u8,       # 0-100 condition percentage
    traits: LegacyMap<felt252, u32>, # trait_name → trait_value

# Universal position and movement
struct Position:
    hex_coordinate: HexCoordinate,
    area_id: felt252,    # Specific area within hex
    last_movement_block: u64,

# Economic data structures
struct EconomicMetrics:
    revenue_per_100_blocks: u64,
    resource_output_rate: u64,
    energy_consumption_rate: u32,
    activity_level: u32,
    last_update_block: u64,
```

### Core Game State

```python
# core/world_state.cairo
# Central world state management

struct WorldState:
    spawn_hex: HexCoordinate,
    current_block: u64,
    total_hexes_discovered: u64,
    total_adventurers_created: u64,

# Hex discovery and basic info
struct HexInfo:
    coordinate: HexCoordinate,
    biome_type: felt252,     # Generated deterministically
    discovered: bool,
    discovery_block: u64,
    discoverer_adventurer_id: AdventurerId,
    areas: Array<AreaInfo>,  # Discovered areas within hex

struct AreaInfo:
    area_id: felt252,
    area_type: felt252,      # Generated when discovered
    discovery_block: u64,
    discoverer_adventurer_id: AdventurerId,
    current_condition: u8,   # Health/stability 0-100

# NFT ownership data
struct AreaOwnershipNFT:
    token_id: u256,
    area_id: felt252,
    owner: ContractAddress,
    mint_block: u64,
    revenue_collected: u64,
    hook_contract: ContractAddress, # Custom business logic
```

### Adventurer System

```python
# core/adventurer.cairo
# Complete adventurer state and progression

struct Adventurer:
    id: AdventurerId,
    owner: ContractAddress,
    name: felt252,
    creation_block: u64,

    # Resources
    energy: u32,
    health: u32,
    max_health: u32,

    # Position and activity
    position: Position,
    current_activity: TimeLockedAction,

    # Character progression
    base_traits: BaseTraits,
    modular_traits: LegacyMap<felt252, ModuleTraitData>,
    total_experience: u64,
    trait_experience: LegacyMap<felt252, u32>,

    # Social and economic
    reputation_scores: LegacyMap<AdventurerId, ReputationData>,
    behavior_hook: ContractAddress, # Autonomous behavior contract

    # Inventory and equipment
    inventory: InventoryData,
    equipment: EquipmentData,

struct BaseTraits:
    strength: u8,      # 1-100
    endurance: u8,
    agility: u8,
    vitality: u8,
    intelligence: u8,
    wisdom: u8,
    charisma: u8,
    survival: u8,
    craftsmanship: u8,
    leadership: u8,

struct ModuleTraitData:
    trait_id: felt252,
    current_level: u8,
    experience_points: u32,
    specializations: Array<felt252>,
    unlock_conditions_met: Array<felt252>,

struct InventoryData:
    items: LegacyMap<felt252, ItemStack>, # item_type → stack
    max_weight_capacity: u32,            # Based on strength + equipment
    current_weight: u32,
    reserved_slots: LegacyMap<felt252, u32>, # Reserved for ongoing activities

struct EquipmentData:
    backpack_tier: u8,        # Affects weight capacity
    tools: LegacyMap<felt252, ItemStack>, # tool_type → equipped tool
    protective_gear: LegacyMap<felt252, ItemStack>,
    efficiency_bonuses: LegacyMap<felt252, u32>, # activity_type → bonus
```

### Territorial Economics

```python
# economic/territorial.cairo
# Energy economics and territorial decay

struct TerritorialEconomics:
    hex_decay_states: LegacyMap<HexCoordinate, HexDecayState>,
    claimable_hexes: LegacyMap<HexCoordinate, ClaimableHexState>,
    energy_conversion_rates: LegacyMap<felt252, ConversionRate>,
    economic_metrics: LegacyMap<HexCoordinate, EconomicMetrics>,

struct HexDecayState:
    hex_coordinate: HexCoordinate,
    owner_nft_id: u256,
    energy_consumption_per_100_blocks: u32,
    last_energy_payment_block: u64,
    current_energy_reserve: u32,
    decay_level: u8,                    # 0-100
    productivity_metrics: ProductivityMetrics,

struct ProductivityMetrics:
    total_revenue_per_100_blocks: u64,
    resource_production_rate: u64,
    building_complexity_score: u32,
    activity_level: u32,
    infrastructure_network_value: u32,

struct ClaimableHexState:
    hex_coordinate: HexCoordinate,
    original_owner_nft_id: u256,
    claimable_since_block: u64,
    minimum_energy_to_claim: u32,
    grace_period_remaining: u32,
    pending_claims: Array<ClaimingAttempt>,

struct ClaimingAttempt:
    claimant_adventurer_id: AdventurerId,
    energy_offered: u32,
    claim_initiated_block: u64,
    terms: ClaimTerms,
```

## Core Contract Structure

### 1. Registry Contract (Central Hub)

```python
# core/registry.cairo
# Central registry managing all contracts and modules

#[starknet::contract]
mod GameRegistry:
    use super::{WorldState, ModuleRegistration, ContractInfo};

    #[storage]
    struct Storage:
        # Core state
        world_state: WorldState,

        # Contract registry
        core_contracts: LegacyMap<felt252, ContractAddress>, # contract_name → address
        game_modules: LegacyMap<felt252, ModuleInfo>,        # module_id → module_info
        hook_contracts: LegacyMap<ContractAddress, HookInfo>, # Hook validation

        # Access control
        admin: ContractAddress,
        module_deployers: LegacyMap<ContractAddress, bool>,

        # Protocol settings
        protocol_parameters: LegacyMap<felt252, u32>,        # Global configuration

    #[external(v0)]
    impl GameRegistryImpl:
        # Module management
        fn register_core_contract(name: felt252, address: ContractAddress) -> bool
        fn register_game_module(module_info: ModuleInfo) -> bool
        fn validate_hook_contract(hook_address: ContractAddress) -> bool

        # Contract discovery
        fn get_core_contract(name: felt252) -> ContractAddress
        fn get_module_contract(module_id: felt252) -> ContractAddress
        fn list_available_modules() -> Array<felt252>

        # Global state access
        fn get_world_state() -> WorldState
        fn update_world_state(new_state: WorldState) -> bool

struct ModuleInfo:
    module_id: felt252,
    module_name: felt252,
    contract_address: ContractAddress,
    version: u32,
    dependencies: Array<felt252>,        # Required modules
    provided_traits: Array<felt252>,    # New traits this module adds
    provided_actions: Array<felt252>,   # New actions this module handles
```

### 2. World State Contract

```python
# core/world.cairo
# Manages hex discovery, areas, and basic world state

#[starknet::contract]
mod WorldManager:
    use super::{HexInfo, AreaInfo, Position};

    #[storage]
    struct Storage:
        # Hex and area data
        hexes: LegacyMap<HexCoordinate, HexInfo>,
        areas: LegacyMap<felt252, AreaInfo>,        # area_id → area_info
        hex_areas: LegacyMap<HexCoordinate, Array<felt252>>, # hex → area_ids

        # Discovery tracking
        next_area_id: felt252,
        discovery_rewards: LegacyMap<felt252, Array<ItemStack>>, # biome → rewards

        # World generation
        biome_generation_seed: felt252,
        world_parameters: WorldGenerationParams,

    #[external(v0)]
    impl WorldManagerImpl:
        # Discovery
        fn discover_hex(adventurer_id: AdventurerId, hex: HexCoordinate) -> DiscoveryResult
        fn discover_area(adventurer_id: AdventurerId, hex: HexCoordinate) -> AreaDiscoveryResult

        # World queries
        fn get_hex_info(hex: HexCoordinate) -> HexInfo
        fn get_area_info(area_id: felt252) -> AreaInfo
        fn get_adjacent_hexes(hex: HexCoordinate) -> Array<HexCoordinate>
        fn calculate_movement_cost(from: HexCoordinate, to: HexCoordinate) -> u32

        # Biome generation (deterministic)
        fn generate_biome_type(hex: HexCoordinate) -> felt252
        fn generate_area_potential(hex: HexCoordinate, area_index: u8) -> AreaPotential
```

### 3. Adventurer Manager Contract

```python
# core/adventurer_manager.cairo
# Manages all adventurer state and progression

#[starknet::contract]
mod AdventurerManager:
    use super::{Adventurer, BaseTraits, TimeLockedAction};

    #[storage]
    struct Storage:
        # Adventurer data
        adventurers: LegacyMap<AdventurerId, Adventurer>,
        next_adventurer_id: AdventurerId,

        # Progression and traits
        trait_definitions: LegacyMap<felt252, TraitDefinition>,
        experience_gain_rates: LegacyMap<felt252, u32>, # activity → exp_rate

        # Activity management
        active_actions: LegacyMap<AdventurerId, TimeLockedAction>,
        energy_regeneration_rate: u32,

        # Social systems
        global_reputation: LegacyMap<AdventurerId, GlobalReputation>,

    #[external(v0)]
    impl AdventurerManagerImpl:
        # Adventurer lifecycle
        fn create_adventurer(owner: ContractAddress, name: felt252, traits: BaseTraits) -> AdventurerId
        fn get_adventurer(adventurer_id: AdventurerId) -> Adventurer
        fn update_adventurer_position(adventurer_id: AdventurerId, new_position: Position) -> bool

        # Progression system
        fn gain_trait_experience(adventurer_id: AdventurerId, trait_id: felt252, amount: u32) -> bool
        fn unlock_modular_trait(adventurer_id: AdventurerId, trait_id: felt252) -> bool
        fn get_effective_trait_level(adventurer_id: AdventurerId, trait_id: felt252) -> u32

        # Activity management
        fn start_time_locked_action(adventurer_id: AdventurerId, action: TimeLockedAction) -> bool
        fn complete_time_locked_action(adventurer_id: AdventurerId) -> ActionResult
        fn cancel_time_locked_action(adventurer_id: AdventurerId) -> bool

        # Resource management
        fn consume_energy(adventurer_id: AdventurerId, amount: u32) -> bool
        fn regenerate_energy(adventurer_id: AdventurerId) -> u32
        fn update_health(adventurer_id: AdventurerId, health_change: i32) -> bool
```

### 4. Economic Systems Contract

```python
# economic/economic_manager.cairo
# Manages territorial economics, energy systems, and inflation control

#[starknet::contract]
mod EconomicManager:
    use super::{HexDecayState, ProductivityMetrics, EconomicMetrics};

    #[storage]
    struct Storage:
        # Territorial economics
        hex_decay_states: LegacyMap<HexCoordinate, HexDecayState>,
        claimable_hexes: LegacyMap<HexCoordinate, ClaimableHexState>,

        # Energy economics
        universal_conversion_rates: LegacyMap<felt252, u32>, # item_type → energy_rate
        conversion_facilities: LegacyMap<ContractAddress, ConversionFacility>,
        energy_market_data: LegacyMap<felt252, MarketData>,

        # Anti-inflation systems
        total_economic_supply: u64,
        inflation_metrics: InflationMetrics,
        stabilization_parameters: StabilizationParams,

    #[external(v0)]
    impl EconomicManagerImpl:
        # Territorial management
        fn calculate_hex_energy_consumption(hex: HexCoordinate) -> u32
        fn pay_hex_maintenance(adventurer_id: AdventurerId, hex: HexCoordinate, energy: u32) -> bool
        fn process_hex_decay(hex: HexCoordinate) -> DecayResult
        fn mark_hex_claimable(hex: HexCoordinate) -> bool

        # Territorial claiming
        fn initiate_hex_claim(adventurer_id: AdventurerId, hex: HexCoordinate, energy: u32) -> ClaimResult
        fn defend_hex_from_claim(adventurer_id: AdventurerId, hex: HexCoordinate, energy: u32) -> DefenseResult
        fn resolve_hex_claims(hex: HexCoordinate) -> ClaimResolutionResult

        # Energy conversion
        fn convert_items_to_energy(adventurer_id: AdventurerId, items: Array<ItemStack>) -> ConversionResult
        fn get_conversion_rate(item_type: felt252) -> u32
        fn update_market_rates() -> bool

        # Economic monitoring
        fn calculate_inflation_rate() -> i32
        fn get_economic_metrics() -> EconomicMetrics
        fn apply_stabilization_measures() -> Array<StabilizationAction>
```

### 5. NFT Ownership Contract

```python
# nft/area_ownership.cairo
# ERC-721 implementation for area ownership with revenue tracking

#[starknet::contract]
mod AreaOwnershipNFT:
    use openzeppelin::token::erc721::ERC721Component;
    use super::{AreaOwnershipNFT, RevenueData};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[storage]
    struct Storage:
        #[substorage(v0)]
        erc721: ERC721Component::Storage,

        # NFT-specific data
        area_nfts: LegacyMap<u256, AreaOwnershipNFT>, # token_id → nft_data
        area_to_token: LegacyMap<felt252, u256>,      # area_id → token_id
        next_token_id: u256,

        # Revenue tracking
        revenue_data: LegacyMap<u256, RevenueData>,   # token_id → revenue_info
        pending_revenue: LegacyMap<u256, u64>,        # Uncollected revenue

        # Hook integration
        nft_hooks: LegacyMap<u256, ContractAddress>,  # Custom business logic per NFT

    #[external(v0)]
    impl AreaOwnershipNFTImpl:
        # NFT lifecycle
        fn mint_area_nft(area_id: felt252, to: ContractAddress) -> u256
        fn get_nft_data(token_id: u256) -> AreaOwnershipNFT
        fn set_nft_hook(token_id: u256, hook_address: ContractAddress) -> bool

        # Revenue management
        fn record_revenue(token_id: u256, amount: u64) -> bool
        fn collect_revenue(token_id: u256) -> u64
        fn get_revenue_data(token_id: u256) -> RevenueData

        # Ownership queries
        fn get_area_owner(area_id: felt252) -> ContractAddress
        fn get_owned_areas(owner: ContractAddress) -> Array<felt252>
```

## Universal Interface System

### Hook Interface Standards

```python
# interfaces/hooks.cairo
# Universal hook interfaces that work across all systems

trait IUniversalHook<T>:
    fn before_action(
        caller: ContractAddress,
        target_id: T,
        action_type: felt252,
        action_params: Span<felt252>
    ) -> PermissionResult

    fn after_action(
        caller: ContractAddress,
        target_id: T,
        action_type: felt252,
        action_result: ActionResult
    ) -> ()

    fn calculate_fees(
        caller: ContractAddress,
        target_id: T,
        action_type: felt252,
        action_params: Span<felt252>
    ) -> FeeCalculation

# Specific hook interfaces
trait IAreaHook = IUniversalHook<felt252>;        # area_id
trait IAdventurerHook = IUniversalHook<AdventurerId>; # adventurer_id
trait IBuildingHook = IUniversalHook<felt252>;    # building_id

# Hook validation and registration
trait IHookRegistry:
    fn register_hook(hook_address: ContractAddress, hook_type: felt252) -> bool
    fn validate_hook_implementation(hook_address: ContractAddress) -> bool
    fn get_hooks_for_target(target_id: felt252, target_type: felt252) -> Array<ContractAddress>
```

### Action Framework Interface

```python
# interfaces/actions.cairo
# Universal action system that all modules implement

trait IActionModule:
    fn handle_action(
        caller: ContractAddress,
        action_request: ActionRequest
    ) -> ActionResult

    fn get_supported_actions() -> Array<ActionType>
    fn get_action_requirements(action_type: felt252) -> ActionRequirements
    fn calculate_action_cost(action_request: ActionRequest) -> ActionCost

struct ActionRequest:
    action_type: felt252,
    actor_adventurer_id: AdventurerId,
    target_id: felt252,           # Context-dependent (area_id, building_id, etc.)
    parameters: Array<felt252>,
    energy_budget: u32,
    time_budget: u64,

struct ActionRequirements:
    minimum_traits: Array<TraitRequirement>,
    required_items: Array<ItemStack>,
    energy_cost: u32,
    time_cost: u64,
    location_requirements: Array<LocationRequirement>,

# Central action dispatcher
trait IActionDispatcher:
    fn dispatch_action(action_request: ActionRequest) -> ActionResult
    fn get_module_for_action(action_type: felt252) -> ContractAddress
    fn register_action_module(module_address: ContractAddress) -> bool
```

## Game Module Contracts

### Mining Module Example

```python
# modules/mining.cairo
# Complete mining system implementation

#[starknet::contract]
mod MiningModule:
    use super::{IActionModule, IUniversalHook, MiningVein, MiningOperation};

    #[storage]
    struct Storage:
        # Mining-specific data
        mining_veins: LegacyMap<felt252, MiningVein>,     # area_id → vein_data
        active_operations: LegacyMap<felt252, Array<MiningOperation>>, # vein_id → operations
        mining_history: LegacyMap<felt252, MiningHistory>, # Statistics and records

        # Module configuration
        ore_types: LegacyMap<felt252, OreTypeData>,       # ore_type → properties
        mining_difficulty: LegacyMap<felt252, u32>,       # biome_type → difficulty
        instability_parameters: InstabilityParams,

    #[external(v0)]
    impl MiningModuleImpl of IActionModule:
        fn handle_action(caller: ContractAddress, action_request: ActionRequest) -> ActionResult:
            match action_request.action_type:
                'start_mining' => self.start_mining_operation(action_request),
                'continue_mining' => self.continue_mining_operation(action_request),
                'stop_mining' => self.stop_mining_operation(action_request),
                'assess_vein' => self.assess_vein_stability(action_request),
                _ => ActionResult.Failed('Unsupported action')
            }

        fn get_supported_actions() -> Array<ActionType>:
            array!['start_mining', 'continue_mining', 'stop_mining', 'assess_vein']

        fn calculate_action_cost(action_request: ActionRequest) -> ActionCost:
            # Calculate based on vein difficulty, adventurer traits, etc.

    #[external(v0)]
    impl MiningOperationsImpl:
        # Mining-specific operations
        fn create_mining_vein(area_id: felt252, vein_data: MiningVein) -> bool
        fn get_vein_stability(area_id: felt252) -> u32
        fn calculate_mining_yield(adventurer_id: AdventurerId, vein_id: felt252) -> u32
        fn process_vein_instability(vein_id: felt252) -> InstabilityResult

struct MiningVein:
    area_id: felt252,
    ore_type: felt252,
    ore_quantity: u32,
    base_stability: u32,          # 0-100
    current_stability: u32,
    max_safe_miners: u8,
    current_miners: Array<MiningOperation>,
    discovery_block: u64,
    total_extracted: u32,

struct MiningOperation:
    adventurer_id: AdventurerId,
    start_block: u64,
    planned_duration: u64,
    energy_committed: u32,
    tools_used: Array<ItemStack>,
    safety_precautions: Array<felt252>,
```

## Contract Deployment & Initialization

### Deployment Script Structure

```python
# deploy/deployment_manager.cairo
# Manages ordered deployment and initialization

deployment_sequence = [
    # 1. Core infrastructure
    {contract: "GameRegistry", dependencies: []},
    {contract: "WorldManager", dependencies: ["GameRegistry"]},
    {contract: "AdventurerManager", dependencies: ["GameRegistry", "WorldManager"]},
    {contract: "EconomicManager", dependencies: ["GameRegistry", "AdventurerManager"]},
    {contract: "AreaOwnershipNFT", dependencies: ["GameRegistry", "WorldManager"]},

    # 2. Interface contracts
    {contract: "ActionDispatcher", dependencies: ["GameRegistry", "AdventurerManager"]},
    {contract: "HookRegistry", dependencies: ["GameRegistry"]},

    # 3. Game modules (order-independent)
    {contract: "MiningModule", dependencies: ["ActionDispatcher", "HookRegistry"]},
    {contract: "HarvestingModule", dependencies: ["ActionDispatcher", "HookRegistry"]},
    {contract: "CraftingModule", dependencies: ["ActionDispatcher", "HookRegistry"]},
    {contract: "ConstructionModule", dependencies: ["ActionDispatcher", "HookRegistry"]},

    # 4. Hook examples (optional)
    {contract: "BasicAreaHook", dependencies: ["HookRegistry"]},
    {contract: "TradingBotHook", dependencies: ["HookRegistry", "AdventurerManager"]},
]

fn deploy_game_system() -> DeploymentResult:
    let mut deployed_contracts: LegacyMap<felt252, ContractAddress> = LegacyMapTrait::new();

    for deployment in deployment_sequence:
        # Verify dependencies are deployed
        for dep in deployment.dependencies:
            assert deployed_contracts.read(dep) != 0, "Missing dependency";
        }

        # Deploy contract with proper initialization
        let address = deploy_contract(deployment.contract, get_init_params(deployment));
        deployed_contracts.write(deployment.contract, address);

        # Register with central registry
        let registry = deployed_contracts.read("GameRegistry");
        IGameRegistry(registry).register_core_contract(deployment.contract, address);
    }

    # Initialize cross-contract relationships
    initialize_module_connections(deployed_contracts);
    setup_default_configurations(deployed_contracts);

    DeploymentResult.Success(deployed_contracts)
```

## Benefits of This Architecture

**🎯 DRY Compliance**: Shared data models, common interfaces, reusable components  
**🔧 Infinite Extensibility**: New modules plug into existing framework seamlessly  
**⚡ Gas Efficiency**: Optimized storage patterns, batch operations, minimal cross-contract calls  
**🪝 Universal Hooks**: Same permission system works for territories, adventurers, buildings, etc.  
**🔒 Security**: Clear access control, validation at all layers, state consistency  
**📊 Modularity**: Core systems separate from game content, easy to upgrade/extend  
**🎮 Developer Experience**: Clear interfaces, predictable patterns, extensive documentation

This architecture creates a **truly extensible game platform** where new features integrate seamlessly while maintaining the DRY principle and optimal performance! 🏗️⚡🎯
