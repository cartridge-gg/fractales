# Construction Module: Building Economic Infrastructure

## Vision: Infrastructure Development on Owned Territory

Players can construct **permanent buildings** on hexes they own, creating **economic infrastructure** that enhances their territories and generates new revenue streams. Buildings become **controllable assets** that integrate fully with the hook permission system.

**Core Principle**: **Territory ownership enables infrastructure development**, creating compounding value and strategic depth.

## Building System Integration

### Ownership Requirements

Only **area NFT holders** can construct buildings on their owned hexes:

```python
fn construct_building(
    builder_id: felt252,
    hex_coord: felt252,
    building_type: felt252,
    construction_materials: Array<felt252>,
    placement_location: HexLocation
) -> ConstructionResult:

    # Verify ownership of the hex
    let area_nft = get_area_nft_for_hex(hex_coord);
    assert area_nft.owner == get_adventurer_owner(builder_id), "Not hex owner";

    # Check available building slots
    let current_buildings = get_buildings_on_hex(hex_coord);
    let max_buildings = calculate_max_buildings(hex_coord, area_nft.area_type);
    assert current_buildings.len() < max_buildings, "Hex at building capacity";

    # Validate materials and blueprints
    let blueprint = get_building_blueprint(building_type);
    assert has_required_materials(builder_id, blueprint.materials), "Missing materials";
    assert has_required_skill(builder_id, blueprint.construction_skill), "Insufficient skill";

    # Start construction process
    let construction_time = calculate_construction_time(building_type, builder_id);
    let building_id = generate_building_id(hex_coord, placement_location);

    # Lock adventurer into construction activity
    lock_adventurer_into_activity(builder_id, ActivityState.CONSTRUCTING(
        building_id: building_id,
        completion_block: block_number() + construction_time,
        materials_consumed: construction_materials
    ));

    # Register building ownership under area NFT
    register_building_ownership(building_id, area_nft.token_id, builder_id);

    emit ConstructionStarted(building_id, hex_coord, building_type, construction_time);
    ConstructionResult.Success(building_id, construction_time)
```

## Building Categories & Functions

### 1. Resource Processing Facilities

**Smelters**: Convert raw ores to refined ingots with efficiency bonuses

```python
BuildingBlueprint.SMELTER = {
    construction_materials: ["iron_ingot": 20, "stone": 50, "coal": 10],
    construction_skill_required: ("engineering", 5),
    construction_time_blocks: 500,
    building_capacity: 3, # 3 concurrent smelting operations
    efficiency_bonus: 25, # 25% faster smelting than portable methods
    upkeep_cost_per_100_blocks: 5, # Coal consumption
}
```

**Mills**: Process harvested plants into refined crafting materials
**Workshops**: Advanced crafting stations for complex item combinations
**Refineries**: Purify and enhance material quality

### 2. Economic Infrastructure

**Trading Posts**: Facilitate commerce between players with automated systems

```python
BuildingBlueprint.TRADING_POST = {
    construction_materials: ["timber": 30, "iron_ingot": 10, "gold": 100],
    construction_skill_required: ("trading", 3),
    functions: [
        "automated_marketplace", # Players can list items for sale
        "bulk_trading", # Handle large quantity transactions
        "price_discovery", # Show market rates for different items
        "escrow_services" # Secure trading between untrusted parties
    ]
}
```

**Banks**: Store items and gold securely, provide lending services
**Warehouses**: Mass storage for territorial logistics
**Guild Halls**: Coordination centers for player organizations

### 3. Defensive Structures

**Watchtowers**: Provide early warning of approaching players/threats
**Barriers**: Slow down movement through hex (with owner permission)
**Guard Posts**: Hire NPC defenders for territorial protection

### 4. Utility Buildings

**Inns**: Provide energy regeneration bonuses for visiting adventurers
**Taverns**: Social hubs with information trading and reputation systems
**Laboratories**: Research new blueprints and optimize existing processes

## Building Placement & Hex Development

### Hex Capacity System

```python
fn calculate_max_buildings(hex_coord: felt252, area_type: felt252) -> u32:
    let base_capacity = match area_type:
        'plains' => 8,      # Open land, easy to build
        'forest' => 5,      # Trees limit construction
        'mountain' => 6,    # Rocky terrain, moderate capacity
        'desert' => 4,      # Harsh conditions, limited space
        'swamp' => 3,       # Unstable ground, very limited
        'coastal' => 10,    # Prime real estate, maximum capacity
        _ => 5
    };

    # Capacity can be increased through infrastructure development
    let infrastructure_bonus = get_infrastructure_development_bonus(hex_coord);
    base_capacity + infrastructure_bonus
```

### Strategic Placement

Buildings have **placement effects** that create strategic decisions:

```python
enum PlacementLocation:
    HEX_CENTER,     # Maximum accessibility, higher construction cost
    HEX_EDGE,       # Cheaper to build, easier for travelers to access
    RESOURCE_NODE,  # Next to specific mines/plants, processing bonuses
    DEFENSIVE_POINT, # Strategic chokepoints, military advantages
    TRANSPORT_HUB   # Near roads/portals, trade bonuses
```

## Buildings as Controllable Assets

### Integration with Hook System

Each building becomes a **controllable object** in the permission system:

```python
# Building owners can set access rules just like area owners
fn set_building_access_hook(
    building_id: felt252,
    hook_contract: felt252
) -> ():
    # Verify caller owns the building (through area NFT ownership)
    let building = buildings.read(building_id);
    let area_nft_owner = get_area_nft_owner(building.hex_coord);
    assert caller_address() == area_nft_owner, "Not building owner";

    # Set hook for building access
    object_hooks.write(building_id, array![hook_contract]);

# Example: Trading Post with membership tiers
#[starknet::contract]
mod TradingPostHook:
    impl IUniversalHook:
        fn before_action(
            caller: felt252,
            target_id: felt252, # building_id
            action_type: felt252, # "list_item", "buy_item", "bulk_trade"
            action_params: Span<felt252>
        ) -> PermissionResult:
            match action_type:
                'list_item' => {
                    # Free for basic listings, fee for premium placement
                    if is_premium_listing(action_params):
                        PermissionResult.RequiresPayment(50, building_owner())
                    } else {
                        PermissionResult.Approved
                    }
                },
                'bulk_trade' => {
                    # Only guild members can access bulk trading
                    if is_guild_member(caller):
                        PermissionResult.Approved
                    } else {
                        PermissionResult.RequiresPayment(200, building_owner())
                    }
                },
                _ => PermissionResult.Approved
            }
```

## Construction Economics

### Material Requirements & Supply Chains

Buildings require **processed materials**, creating demand for the resource processing pipeline:

```python
building_material_chains = {
    "basic_timber": {
        source: "forest_trees",
        processing: "lumber_mill",
        volume_multiplier: 0.5  # 2 logs = 1 timber
    },

    "iron_ingot": {
        source: "iron_ore",
        processing: "smelter",
        fuel_required: "coal",
        volume_multiplier: 0.3  # 3 ore + 1 coal = 1 ingot
    },

    "reinforced_stone": {
        source: "stone_quarry",
        processing: "mason_workshop",
        additives: ["mortar", "iron_fragments"],
        volume_multiplier: 0.8
    }
}
```

### Construction Skill Development

```python
# Construction develops specialized skills
construction_skills = {
    "engineering": {
        affects: ["smelter", "mill", "refinery"],
        bonuses: ["construction_speed", "efficiency_bonus", "upkeep_reduction"]
    },

    "architecture": {
        affects: ["trading_post", "bank", "guild_hall"],
        bonuses: ["building_capacity", "aesthetic_value", "social_functions"]
    },

    "fortification": {
        affects: ["watchtower", "barrier", "guard_post"],
        bonuses: ["defensive_effectiveness", "range", "durability"]
    }
}
```

## Economic Impact & Strategy

### Territory Development Progression

```python
# Hex development creates compounding value
hex_development_stages = {
    "undeveloped": {
        building_capacity: "base",
        property_value_multiplier: 1.0,
        attractiveness_to_visitors: 0.5
    },

    "basic_infrastructure": {
        requirements: ["1+ resource_processing", "1+ utility"],
        building_capacity: "base + 2",
        property_value_multiplier: 1.5,
        attractiveness_to_visitors: 1.0
    },

    "economic_hub": {
        requirements: ["3+ buildings", "1+ trading_post", "road_connection"],
        building_capacity: "base + 4",
        property_value_multiplier: 2.5,
        attractiveness_to_visitors: 2.0,
        special_bonuses: ["bulk_trading", "faster_travel_through_hex"]
    },

    "territorial_capital": {
        requirements: ["6+ buildings", "defensive_structures", "guild_hall"],
        building_capacity: "base + 8",
        property_value_multiplier: 5.0,
        attractiveness_to_visitors: 3.0,
        special_bonuses: ["territorial_administration", "diplomatic_immunity"]
    }
}
```

### Building Synergies

Buildings create **synergy bonuses** when built in combination:

```python
building_synergies = {
    ("smelter", "mine"): {
        bonus: "processing_efficiency_+20%",
        description: "Direct ore pipeline reduces transport costs"
    },

    ("trading_post", "warehouse", "inn"): {
        bonus: "commercial_district_+50%_trade_volume",
        description: "Complete commercial infrastructure attracts more traders"
    },

    ("watchtower", "guard_post", "barrier"): {
        bonus: "defensive_network_+100%_security",
        description: "Coordinated defenses provide maximum protection"
    }
}
```

## Building Maintenance & Lifecycle

### Upkeep Requirements

```python
fn process_building_upkeep(building_id: felt252) -> UpkeepResult:
    let building = buildings.read(building_id);
    let blocks_since_upkeep = block_number() - building.last_upkeep_block;

    if blocks_since_upkeep >= UPKEEP_INTERVAL:
        let upkeep_cost = calculate_upkeep_cost(building.building_type, building.tier);
        let owner = get_building_owner(building_id);

        if can_pay_upkeep(owner, upkeep_cost):
            charge_upkeep(owner, upkeep_cost);
            building.last_upkeep_block = block_number();
            UpkeepResult.Maintained
        } else {
            # Building begins deteriorating
            building.condition -= DETERIORATION_RATE;
            if building.condition <= 0:
                return UpkeepResult.Abandoned;
            }
            UpkeepResult.Deteriorating
        }
    }

    UpkeepResult.NoUpkeepNeeded
```

### Building Upgrades

```python
# Buildings can be upgraded for enhanced functionality
fn upgrade_building(
    building_id: felt252,
    upgrade_materials: Array<felt252>,
    target_tier: u32
) -> UpgradeResult:
    let building = buildings.read(building_id);
    let upgrade_blueprint = get_upgrade_blueprint(building.building_type, target_tier);

    assert has_required_materials(caller(), upgrade_blueprint.materials), "Missing upgrade materials";
    assert building.tier + 1 == target_tier, "Can only upgrade one tier at a time";

    # Upgrade process locks building temporarily
    lock_building_for_upgrade(building_id, upgrade_blueprint.upgrade_time);

    UpgradeResult.Success(upgrade_blueprint.upgrade_time)
```

## Strategic Implications

### Territorial Specialization

**🏭 Industrial Hubs**: Focus on resource processing and manufacturing  
**🏪 Commercial Centers**: Maximize trading and economic activity  
**🏰 Fortress Territories**: Emphasize defense and territorial control  
**🔬 Research Complexes**: Innovation and blueprint development

### Economic Warfare Through Infrastructure

**🎯 Infrastructure Targeting**: Disrupt competitor supply chains by blocking access to key buildings  
**💰 Economic Blockades**: Control critical trading posts and transportation hubs  
**🏗️ Development Racing**: Rush to build key infrastructure before competitors  
**🤝 Infrastructure Alliances**: Share building access through diplomatic agreements

Building construction transforms the game from simple resource extraction to **comprehensive territorial development**, where players become **urban planners and economic architects** building the infrastructure that drives the entire game economy.
