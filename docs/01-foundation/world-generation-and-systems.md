# World Generation System

> Decision alignment note: this document contains exploratory pseudocode variants. For locked MVP rules (cube coordinate encoding, origin-centered API semantics, direct discovery model, and permadeath inclusion), use `docs/02-spec/mvp-functional-spec.md` and `docs/02-spec/design-decisions.md`.

## Core Philosophy: Hybrid Noise + RNG

The world uses a two-phase generation system:

1. **Noise Functions** → Determine biome types (predictable, coherent patterns)
2. **Random Number Generation** → Determine contents (unpredictable until discovered)

This creates logical biome clustering while preventing content scouting.

## Coordinate System

```python
# World bounds: u32 coordinate space
WORLD_CENTER = 2**31  # ~2.1 billion (spawn point)
MAX_COORD = 2**32 - 1
MIN_COORD = 0

# All players spawn at center
SPAWN_HEX = (WORLD_CENTER, WORLD_CENTER)
```

## Hex States & Discovery

```python
enum HexState:
    UNDISCOVERED  # Never visited, no content seed generated
    DISCOVERED    # Visited, content seed generated, deterministic from here
    MAPPED        # All sub-locations fully explored

struct WorldHex:
    coord: (u32, u32)
    state: HexState
    biome: BiomeType        # Determined by noise (always available)
    content_seed: bytes32   # Generated on discovery (RNG)
    discoverer: address     # First visitor
    discovery_block: u64    # When discovered
```

## Phase 1: Biome Generation (Noise-Based)

Biomes are determined by layered noise functions - predictable and coherent.

```python
module BiomeGeneration:
    # Noise layers for different biome aspects
    fn get_biome(coord: (u32, u32)) -> BiomeType:
        x, y = coord

        # Convert to floating point for noise sampling
        # Scale coordinates for appropriate noise frequency
        scale = 0.001  # Adjust for biome size
        nx = x * scale
        ny = y * scale

        # Layer multiple noise functions
        elevation = simplex_noise(nx, ny, seed=ELEVATION_SEED)
        temperature = simplex_noise(nx, ny, seed=TEMP_SEED)
        moisture = simplex_noise(nx, ny, seed=MOISTURE_SEED)

        # Determine biome based on noise values
        return classify_biome(elevation, temperature, moisture)

    fn classify_biome(elevation: f32, temperature: f32, moisture: f32) -> BiomeType:
        # High elevation
        if elevation > 0.6:
            if temperature < -0.3: return BiomeType.SNOW_PEAK
            else: return BiomeType.MOUNTAIN

        # Low elevation (water)
        if elevation < -0.4:
            if temperature < 0: return BiomeType.FROZEN_SEA
            else: return BiomeType.OCEAN

        # Medium elevation (land)
        if temperature > 0.4:
            if moisture < -0.2: return BiomeType.DESERT
            elif moisture > 0.3: return BiomeType.JUNGLE
            else: return BiomeType.SAVANNA
        elif temperature < -0.2:
            if moisture > 0.1: return BiomeType.TAIGA
            else: return BiomeType.TUNDRA
        else:
            if moisture > 0.2: return BiomeType.FOREST
            elif moisture < -0.3: return BiomeType.PLAINS
            else: return BiomeType.GRASSLAND

# Biome configuration
biome_configs = {
    BiomeType.FOREST: {
        "sub_location_types": ["grove", "river", "cave", "ruins"],
        "plant_table": {"berry": 40, "herb": 25, "oak": 20, "rare_flower": 5},
        "ore_table": {"iron": 30, "copper": 10},
        "hazard_table": {"bear": 5, "bandit": 3}
    },
    BiomeType.DESERT: {
        "sub_location_types": ["oasis", "dune", "cave", "temple"],
        "plant_table": {"cactus": 60, "desert_bloom": 15, "palm": 10},
        "ore_table": {"gold": 20, "copper": 15, "gems": 5},
        "hazard_table": {"sandstorm": 15, "scorpion": 8}
    }
    # ... more biomes
}
```

## Phase 2: Content Generation (RNG-Based)

Content is generated only when a hex is discovered, using blockchain randomness.

```python
module ContentGeneration:
    fn discover_hex(player_id: felt, coord: (u32, u32)) -> WorldHex:
        # Check if already discovered
        if coord in discovered_hexes:
            return discovered_hexes[coord]

        # Get predictable biome
        biome = BiomeGeneration.get_biome(coord)

        # Generate unpredictable content seed
        content_seed = hash(
            block_hash(),           # Blockchain randomness
            coord.x, coord.y,       # Coordinate uniqueness
            get_discovery_count(),  # Discovery order
            block_timestamp()       # Additional entropy
        )

        new_hex = WorldHex(
            coord=coord,
            state=HexState.DISCOVERED,
            biome=biome,
            content_seed=content_seed,
            discoverer=player_id,
            discovery_block=block_number()
        )

        discovered_hexes[coord] = new_hex
        emit HexDiscovered(coord, player_id, biome, content_seed)
        return new_hex

    fn generate_hex_contents(hex: WorldHex) -> HexContents:
        biome_config = biome_configs[hex.biome]

        # Use content seed for all RNG within this hex
        rng_state = init_rng(hex.content_seed)

        # Generate sub-locations
        num_locations = rng_range(rng_state, 2, 6)  # 2-5 locations per hex
        locations = []

        for i in range(num_locations):
            loc_type = weighted_choice(rng_state, biome_config.sub_location_types)
            loc_seed = derive_seed(hex.content_seed, f"location_{i}")
            locations.append(generate_location(loc_type, loc_seed, biome_config))

        return HexContents(
            biome=hex.biome,
            locations=locations,
            generated_from=hex.content_seed
        )
```

## Movement & Discovery Integration

```python
module WorldMovement:
    fn move_to_hex(player_id: felt, target_coord: (u32, u32)):
        current_pos = get_player_position(player_id)

        # Validate movement (adjacent hex only)
        assert is_adjacent_hex(current_pos, target_coord)

        # Calculate energy cost
        energy_cost = ENERGY_PER_HEX_MOVE
        spend_energy(player_id, energy_cost)

        # Always reveal biome (noise-based, no cost)
        biome = BiomeGeneration.get_biome(target_coord)

        # Discover content if first visit
        hex_data = ContentGeneration.discover_hex(player_id, target_coord)

        # Update player position
        set_player_position(player_id, target_coord)

        # Return movement result
        return MovementResult(
            new_position=target_coord,
            biome=biome,
            is_first_discovery=(hex_data.discoverer == player_id),
            content_preview=generate_hex_preview(hex_data)
        )
```

## Advantages of This System

1. **Biome Coherence**: Noise functions create realistic biome clustering
2. **Content Unpredictability**: RNG prevents scouting of valuable resources
3. **Deterministic After Discovery**: Once discovered, all clients generate identical content
4. **Efficient**: Biomes can be computed off-chain, content only generated when needed
5. **Scalable**: No global state required for undiscovered areas

## Next Steps

- [ ] Define complete biome classification system
- [ ] Implement noise function parameters and seeds
- [ ] Design sub-location generation within biomes
- [ ] Create resource/hazard distribution algorithms
- [ ] Define discovery rewards and mechanics

---

# Data Models & Module Discovery System

## Player Location & Movement System

```python
# Players exist at specific coordinates
struct PlayerState:
    coord: HexCoord
    energy: u32
    last_energy_refill: u64

# Global player registry
storage player_locations: LegacyMap<felt252, PlayerState>

fn get_adjacent_hexes(coord: HexCoord) -> Array<HexCoord>:
    # Hex grid adjacency - 6 neighbors
    let directions = array![
        (1, 0), (-1, 0),      # East, West
        (0, 1), (0, -1),      # North, South
        (1, -1), (-1, 1)      # NE, SW (offset for hex grid)
    ];

    let mut adjacent = array![];
    for direction in directions:
        adjacent.append(HexCoord(
            x: coord.x + direction.0,
            y: coord.y + direction.1
        ));
    adjacent
```

## Two-Phase Discovery System

### Phase 1: Hex Exploration (Core System)

Players can only explore adjacent hexes. This creates the discovery seed.

```python
# Lightweight hex registry - no assumptions about content
struct DiscoveredHex:
    coord: HexCoord
    biome: BiomeType           # Always available (noise-based)
    discovery_seed: bytes32    # Generated on first visit
    discoverer: felt252        # Who first visited
    discovery_block: u64       # When discovered
    total_visits: u32          # How many times visited

# Global hex registry
storage discovered_hexes: LegacyMap<felt252, DiscoveredHex>

fn explore_hex(player: felt252, target_coord: HexCoord) -> ExplorationResult:
    let player_state = player_locations.read(player);

    # Validate adjacency - can only explore neighboring hexes
    let adjacent_hexes = get_adjacent_hexes(player_state.coord);
    assert adjacent_hexes.contains(target_coord), "Can only explore adjacent hexes";

    # Check energy cost
    let energy_cost = ENERGY_PER_EXPLORATION;
    assert player_state.energy >= energy_cost, "Insufficient energy";

    # Spend energy and move player
    player_state.energy -= energy_cost;
    player_state.coord = target_coord;
    player_locations.write(player, player_state);

    let hex_key = target_coord.to_key();

    # Check if hex already discovered
    let existing_hex = discovered_hexes.read(hex_key);
    if existing_hex.discovery_seed != 0:
        # Already discovered, just update visit count
        existing_hex.total_visits += 1;
        discovered_hexes.write(hex_key, existing_hex);

        return ExplorationResult.AlreadyDiscovered(
            hex_data: existing_hex,
            available_modules: get_available_modules(hex_key)
        );

    # First discovery - generate biome and seed
    let biome = BiomeGeneration.get_biome(target_coord);
    let discovery_seed = hash(
        block_hash(),              # Blockchain randomness
        target_coord.x,
        target_coord.y,
        block_timestamp(),
        player                     # Who discovered it
    );

    let new_hex = DiscoveredHex(
        coord: target_coord,
        biome: biome,
        discovery_seed: discovery_seed,
        discoverer: player,
        discovery_block: block_number(),
        total_visits: 1
    );

    discovered_hexes.write(hex_key, new_hex);
    emit HexDiscovered(target_coord, biome, player, discovery_seed);

    return ExplorationResult.NewDiscovery(
        hex_data: new_hex,
        suggested_modules: get_suggested_modules_for_biome(biome)
    );
```

### Phase 2: Module Initialization (Extensible System)

After a hex is discovered, players can initialize specific modules.

```python
# Module instances are completely separate from hex discovery
struct ModuleInstance:
    hex_coord: HexCoord
    module_type: felt252       # "harvesting", "mining", "creatures", etc.
    instance_seed: bytes32     # Derived from hex discovery_seed + module_type
    initializer: felt252       # Who first initialized this module
    initialization_block: u64
    state: ModuleState         # Module-specific data

# Each module type has its own storage
storage harvesting_instances: LegacyMap<felt252, HarvestingInstance>
storage mining_instances: LegacyMap<felt252, MiningInstance>
storage creature_instances: LegacyMap<felt252, CreatureInstance>
# ... future modules

fn initialize_module(player: felt252, hex_coord: HexCoord, module_type: felt252) -> ModuleInitResult:
    # Validate player is at this hex
    let player_state = player_locations.read(player);
    assert player_state.coord == hex_coord, "Must be at hex to initialize modules";

    # Validate hex is discovered
    let hex_key = hex_coord.to_key();
    let hex = discovered_hexes.read(hex_key);
    assert hex.discovery_seed != 0, "Hex not yet discovered";

    # Check if module already initialized
    let module_key = hash(hex_key, module_type);
    if module_exists(module_key, module_type):
        return ModuleInitResult.AlreadyExists(get_existing_module(module_key, module_type));

    # Generate module-specific seed
    let module_seed = hash(hex.discovery_seed, module_type);

    # Get module handler and check if it can exist here
    let module_handler = get_module_handler(module_type);
    if !module_handler.can_exist_in_biome(hex.biome):
        return ModuleInitResult.NotPossible("Module incompatible with biome");

    if !module_handler.check_existence(hex_coord, hex.biome, module_seed):
        return ModuleInitResult.NotPresent("Module not present in this hex");

    # Initialize the module
    let instance = module_handler.initialize(hex_coord, module_seed, player);
    store_module_instance(module_key, module_type, instance);

    emit ModuleInitialized(hex_coord, module_type, player);
    return ModuleInitResult.Success(instance);
```

## Module Handler Interface

```python
# Generic interface that all modules implement
trait ModuleHandler:
    fn can_exist_in_biome(biome: BiomeType) -> bool
    fn check_existence(hex_coord: HexCoord, biome: BiomeType, seed: bytes32) -> bool
    fn initialize(hex_coord: HexCoord, seed: bytes32, initializer: felt252) -> ModuleInstance
    fn get_areas(instance: ModuleInstance) -> Array<AreaInfo>
    fn interact(instance: ModuleInstance, action: ModuleAction) -> ActionResult

# Registry of all available module handlers
storage module_handlers: LegacyMap<felt252, ModuleHandler>

fn register_module_handler(module_type: felt252, handler: ModuleHandler):
    # Only callable by governance/admin
    module_handlers.write(module_type, handler);

fn get_module_handler(module_type: felt252) -> ModuleHandler:
    let handler = module_handlers.read(module_type);
    assert handler != 0, "Unknown module type";
    handler
```

## Harvesting Module Implementation

```python
struct HarvestingInstance:
    hex_coord: HexCoord
    instance_seed: bytes32
    areas: Array<HarvestingAreaInfo>  # Area metadata only
    total_area_count: u32
    biome_modifiers: BiomeModifiers

struct HarvestingAreaInfo:
    area_id: u32
    area_type: felt252         # "grove", "clearing", etc.
    size: u32
    soil_quality: u32
    explored: bool             # Whether plants have been generated

# Plants are stored separately and generated lazily
struct PlantNode:
    hex_coord: HexCoord
    area_id: u32
    plant_id: u32
    species: felt252
    genetics_hash: felt252     # Compact representation of genetics
    current_yield: u32
    growth_stage: u8
    last_harvest: u64
    discoverer: felt252

storage plant_nodes: LegacyMap<felt252, PlantNode>  # Key: hash(hex, area_id, plant_id)

impl HarvestingHandler of ModuleHandler:
    fn can_exist_in_biome(biome: BiomeType) -> bool:
        match biome:
            BiomeType.FOREST | BiomeType.JUNGLE | BiomeType.GRASSLAND => true,
            BiomeType.DESERT => true,  # Cactus, desert plants
            BiomeType.OCEAN | BiomeType.FROZEN_SEA => false,
            _ => true  # Most biomes have some plants

    fn check_existence(hex_coord: HexCoord, biome: BiomeType, seed: bytes32) -> bool:
        let rng = init_rng(seed);
        let existence_chance = match biome:
            BiomeType.FOREST => 95,     # Almost always plants
            BiomeType.JUNGLE => 98,     # Dense vegetation
            BiomeType.DESERT => 60,     # Sparse but present
            BiomeType.TUNDRA => 40,     # Limited plant life
            BiomeType.MOUNTAIN => 30,   # High altitude challenges
            _ => 70
        };
        rng.range(0, 100) < existence_chance

    fn initialize(hex_coord: HexCoord, seed: bytes32, initializer: felt252) -> HarvestingInstance:
        let rng = init_rng(seed);
        let hex = discovered_hexes.read(hex_coord.to_key());

        # Generate area metadata (not plants yet)
        let area_count = get_area_count_for_biome(hex.biome, rng);
        let mut areas = array![];

        for i in 0..area_count:
            let area_seed = hash(seed, i);
            let area_rng = init_rng(area_seed);

            areas.append(HarvestingAreaInfo(
                area_id: i,
                area_type: get_area_type_for_biome(hex.biome, area_rng),
                size: area_rng.range(20, 100),
                soil_quality: area_rng.range(30, 95),
                explored: false
            ));

        HarvestingInstance(
            hex_coord: hex_coord,
            instance_seed: seed,
            areas: areas,
            total_area_count: area_count,
            biome_modifiers: get_biome_modifiers(hex.biome)
        )
```

## Player Actions Flow

```python
# 1. Player moves and explores adjacent hex
fn player_explore_adjacent(player: felt252, target_coord: HexCoord) -> ExplorationResult:
    explore_hex(player, target_coord)

# 2. Player initializes specific modules in discovered hex
fn player_init_harvesting(player: felt252, hex_coord: HexCoord) -> ModuleInitResult:
    initialize_module(player, hex_coord, "harvesting")

# 3. Player explores areas within initialized modules
fn player_explore_harvesting_area(player: felt252, hex_coord: HexCoord, area_id: u32) -> AreaResult:
    # Generate plants for the area if not already explored
    pass

# 4. Player starts time-locked harvesting
fn player_start_harvest(player: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32, amount: u32) -> HarvestStartResult:
    start_harvesting(player, hex_coord, area_id, plant_id, amount)

# 5. Player completes harvesting after time lock
fn player_complete_harvest(player: felt252) -> HarvestCompletionResult:
    complete_harvesting(player)

# 6. Player can inspect plant status
fn player_inspect_plant(player: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32) -> PlantStatus:
    let plant_key = hash(hex_coord.to_key(), area_id, plant_id);
    let plant = plant_nodes.read(plant_key);
    let updated_plant = update_plant_yield(plant, block_number());

    PlantStatus(
        species: updated_plant.species,
        current_yield: updated_plant.current_yield,
        max_yield: updated_plant.max_yield,
        health: updated_plant.health,
        stress_level: updated_plant.stress_level,
        regrowth_time_remaining: calculate_regrowth_time(updated_plant)
    )
```

## Player Activity System

Players can be locked into activities that prevent other actions:

```python
enum ActivityState:
    IDLE,                          # Can perform any action
    HARVESTING(HarvestingActivity), # Locked into harvesting
    MINING(MiningActivity),        # Locked into mining
    CRAFTING(CraftingActivity),    # Locked into crafting
    TRAVELING(TravelActivity)      # Locked into long-distance travel

struct HarvestingActivity:
    hex_coord: HexCoord
    area_id: u32
    plant_id: u32
    amount_requested: u32          # Total amount player wants to harvest
    amount_harvested: u32          # Amount completed so far
    start_block: u64               # When harvesting started
    estimated_completion: u64      # When it should finish
    energy_committed: u32          # Energy spent (non-refundable if cancelled)

struct PlayerState:
    coord: HexCoord
    energy: u32
    last_energy_refill: u64
    activity: ActivityState        # Current activity state
    activity_data: felt252         # Serialized activity data

storage player_states: LegacyMap<felt252, PlayerState>
```

## Plant Regrowth Mechanics

Plants have dynamic yield that regenerates over time:

```python
struct PlantNode:
    hex_coord: HexCoord
    area_id: u32
    plant_id: u32
    species: felt252
    genetics_hash: felt252         # Compact representation of genetics

    # Growth & Yield State
    current_yield: u32             # Currently harvestable amount
    max_yield: u32                 # Maximum possible yield (from genetics)
    last_harvest_block: u64        # When last harvested
    total_lifetime_harvested: u32  # Lifetime harvest count
    regrowth_rate: u32             # Yield recovered per block (from genetics)

    # Discovery
    discoverer: felt252            # Who first found this plant

    # Health State
    health: u8                     # 0-100, affects regrowth
    stress_level: u8               # Increases with over-harvesting

fn update_plant_yield(plant: PlantNode, current_block: u64) -> PlantNode:
    if plant.current_yield >= plant.max_yield:
        return plant  # Already at max yield

    let blocks_since_harvest = current_block - plant.last_harvest_block;
    let base_regrowth = blocks_since_harvest * plant.regrowth_rate;

    # Health affects regrowth efficiency
    let health_modifier = plant.health / 100;
    let actual_regrowth = (base_regrowth * health_modifier) / 100;

    # Stress slows regrowth
    let stress_penalty = plant.stress_level / 10; // 0-10% penalty
    let final_regrowth = actual_regrowth - (actual_regrowth * stress_penalty / 100);

    plant.current_yield = min(
        plant.max_yield,
        plant.current_yield + final_regrowth
    );

    # Gradually reduce stress over time
    if blocks_since_harvest > STRESS_RECOVERY_TIME:
        plant.stress_level = max(0, plant.stress_level - 1);

    plant
```

## Harvesting Process with Time Locks

```python
fn start_harvesting(player: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32, amount: u32) -> HarvestStartResult:
    let mut player_state = player_states.read(player);

    # Validate player state
    assert player_state.coord == hex_coord, "Must be at hex to harvest";
    assert player_state.activity == ActivityState.IDLE, "Already engaged in activity";
    assert player_state.energy > 0, "No energy to harvest";

    # Get and update plant state
    let plant_key = hash(hex_coord.to_key(), area_id, plant_id);
    let mut plant = plant_nodes.read(plant_key);
    plant = update_plant_yield(plant, block_number());

    # Validate harvest request
    assert amount > 0, "Must harvest something";
    assert amount <= plant.current_yield, "Not enough yield available";

    # Calculate harvesting parameters based on genetics
    let genetics = decode_genetics(plant.genetics_hash);
    let energy_per_unit = calculate_harvest_energy_cost(genetics, plant.stress_level);
    let time_per_unit = calculate_harvest_time(genetics, amount);

    let total_energy_cost = amount * energy_per_unit;
    let total_time_blocks = amount * time_per_unit;

    assert player_state.energy >= total_energy_cost, "Insufficient energy";

    # Commit energy (non-refundable)
    player_state.energy -= total_energy_cost;

    # Lock player into harvesting activity
    let harvesting_activity = HarvestingActivity(
        hex_coord: hex_coord,
        area_id: area_id,
        plant_id: plant_id,
        amount_requested: amount,
        amount_harvested: 0,
        start_block: block_number(),
        estimated_completion: block_number() + total_time_blocks,
        energy_committed: total_energy_cost
    );

    player_state.activity = ActivityState.HARVESTING(harvesting_activity);
    player_states.write(player, player_state);

    emit HarvestingStarted(player, hex_coord, area_id, plant_id, amount, total_time_blocks);
    return HarvestStartResult.Success(harvesting_activity);

fn check_harvesting_progress(player: felt252) -> HarvestProgressResult:
    let player_state = player_states.read(player);

    match player_state.activity:
        ActivityState.HARVESTING(activity) => {
            let current_block = block_number();
            let blocks_elapsed = current_block - activity.start_block;
            let total_blocks_needed = activity.estimated_completion - activity.start_block;

            if current_block >= activity.estimated_completion:
                # Harvesting complete!
                return HarvestProgressResult.Complete(activity);
            } else {
                # Calculate partial progress
                let progress_ratio = blocks_elapsed / total_blocks_needed;
                let current_harvest = (activity.amount_requested * progress_ratio) / 100;

                return HarvestProgressResult.InProgress(
                    blocks_remaining: activity.estimated_completion - current_block,
                    current_amount: current_harvest,
                    estimated_completion: activity.estimated_completion
                );
            }
        },
        _ => HarvestProgressResult.NotHarvesting
    }

fn complete_harvesting(player: felt252) -> HarvestCompletionResult:
    let mut player_state = player_states.read(player);

    match player_state.activity:
        ActivityState.HARVESTING(activity) => {
            assert block_number() >= activity.estimated_completion, "Harvesting not yet complete";

            # Get plant and update its state
            let plant_key = hash(activity.hex_coord.to_key(), activity.area_id, activity.plant_id);
            let mut plant = plant_nodes.read(plant_key);

            # Reduce plant yield
            plant.current_yield -= activity.amount_requested;
            plant.last_harvest_block = block_number();
            plant.total_lifetime_harvested += activity.amount_requested;

            # Increase stress from harvesting
            let stress_increase = calculate_harvest_stress(activity.amount_requested, plant.max_yield);
            plant.stress_level = min(100, plant.stress_level + stress_increase);

            # Health can be damaged by over-harvesting or high stress
            if plant.stress_level > 80:
                let damage_chance = plant.stress_level - 80; // 1-20% chance
                if random_percent(plant.genetics_hash, block_number()) < damage_chance:
                    plant.health = max(10, plant.health - random_range(5, 15));
                }
            }

            plant_nodes.write(plant_key, plant);

            # Calculate actual yield (genetics affect final output)
            let genetics = decode_genetics(plant.genetics_hash);
            let base_yield = activity.amount_requested;
            let quality_multiplier = genetics.potency / 100;
            let actual_yield = (base_yield * quality_multiplier) / 100;

            # Mint harvested resources
            mint_resource(player, plant.species, actual_yield, genetics.potency);

            # Free player from activity
            player_state.activity = ActivityState.IDLE;
            player_states.write(player, player_state);

            emit HarvestingCompleted(player, activity.hex_coord, activity.area_id, activity.plant_id, actual_yield);
            return HarvestCompletionResult.Success(actual_yield, genetics.potency);
        },
        _ => HarvestCompletionResult.NotHarvesting
    }

fn cancel_harvesting(player: felt252) -> CancelResult:
    let mut player_state = player_states.read(player);

    match player_state.activity:
        ActivityState.HARVESTING(activity) => {
            # Calculate partial progress
            let blocks_elapsed = block_number() - activity.start_block;
            let total_blocks = activity.estimated_completion - activity.start_block;
            let progress_ratio = min(100, (blocks_elapsed * 100) / total_blocks);

            # Get partial harvest based on progress
            let partial_amount = (activity.amount_requested * progress_ratio) / 100;

            if partial_amount > 0:
                # Update plant state with partial harvest
                let plant_key = hash(activity.hex_coord.to_key(), activity.area_id, activity.plant_id);
                let mut plant = plant_nodes.read(plant_key);
                plant.current_yield -= partial_amount;
                plant.last_harvest_block = block_number();
                plant_nodes.write(plant_key, plant);

                # Mint partial resources
                let genetics = decode_genetics(plant.genetics_hash);
                let actual_yield = (partial_amount * genetics.potency) / 100;
                mint_resource(player, plant.species, actual_yield, genetics.potency);
            }

            # Free player (energy is lost)
            player_state.activity = ActivityState.IDLE;
            player_states.write(player, player_state);

            emit HarvestingCancelled(player, partial_amount);
            return CancelResult.Success(partial_amount);
        },
        _ => CancelResult.NotHarvesting
    }
```

## Harvesting Economics & Balancing

```python
fn calculate_harvest_energy_cost(genetics: PlantGenetics, stress_level: u8) -> u32:
    let base_cost = 10; // Base energy per unit

    # Higher vigor plants are easier to harvest
    let vigor_modifier = max(50, 150 - genetics.vigor); // 50-100% cost

    # Stressed plants are harder to harvest
    let stress_modifier = 100 + stress_level; // 100-200% cost

    (base_cost * vigor_modifier * stress_modifier) / 10000

fn calculate_harvest_time(genetics: PlantGenetics, amount: u32) -> u32:
    let base_time_per_unit = 2; // 2 blocks per unit base

    # Larger harvests take longer per unit (diminishing returns)
    let batch_modifier = match amount:
        1..=5 => 100,     # Normal speed
        6..=15 => 120,    # 20% slower per unit
        16..=30 => 150,   # 50% slower per unit
        _ => 200          # 100% slower per unit
    };

    # Plant resilience affects harvest difficulty
    let resilience_modifier = max(50, 150 - genetics.resilience);

    (base_time_per_unit * batch_modifier * resilience_modifier) / 10000

fn calculate_harvest_stress(amount_harvested: u32, max_yield: u32) -> u8:
    let harvest_ratio = (amount_harvested * 100) / max_yield;

    match harvest_ratio:
        0..=25 => 5,      # Light harvesting, minimal stress
        26..=50 => 15,    # Moderate harvesting
        51..=75 => 30,    # Heavy harvesting
        76..=90 => 50,    # Very heavy harvesting
        _ => 80           # Near-complete harvesting, high stress
    }
```

## Player Action Commands

```python
# Start harvesting (commits energy and time)
fn player_start_harvest(player: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32, amount: u32) -> HarvestStartResult:
    start_harvesting(player, hex_coord, area_id, plant_id, amount)

# Check current harvesting progress
fn player_check_harvest_progress(player: felt252) -> HarvestProgressResult:
    check_harvesting_progress(player)

# Complete harvesting (when time is up)
fn player_complete_harvest(player: felt252) -> HarvestCompletionResult:
    complete_harvesting(player)

# Cancel harvesting early (lose energy, get partial yield)
fn player_cancel_harvest(player: felt252) -> CancelResult:
    cancel_harvesting(player)

# View plant status (yield, health, stress)
fn player_inspect_plant(player: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32) -> PlantStatus:
    let plant_key = hash(hex_coord.to_key(), area_id, plant_id);
    let plant = plant_nodes.read(plant_key);
    let updated_plant = update_plant_yield(plant, block_number());

    PlantStatus(
        species: updated_plant.species,
        current_yield: updated_plant.current_yield,
        max_yield: updated_plant.max_yield,
        health: updated_plant.health,
        stress_level: updated_plant.stress_level,
        regrowth_time_remaining: calculate_regrowth_time(updated_plant)
    )
```

## Benefits of This Two-Phase System

1. **True Adjacency-Based Exploration**: Can only discover neighboring hexes
2. **Clean Separation**: Hex discovery vs module initialization
3. **Extensibility**: Add new modules without touching core exploration
4. **Backward Compatibility**: New modules can be initialized in old hexes
5. **Memory Efficient**: Only store what's actually discovered/initialized
6. **Realistic Discovery**: "I wonder if there are plants here?" → init harvesting → find out

The flow feels much more natural:

```
Move to (2,1) → "Forest biome discovered!"
Init harvesting → "Plants found! 3 areas available"
Explore grove → "12 unique plants generated"
```

## Harvesting System Benefits

This time-locked harvesting system creates engaging gameplay mechanics:

1. **Strategic Time Management**: Players must commit time blocks to harvesting, creating opportunity costs
2. **Sustainable Resource Management**: Over-harvesting stresses plants and reduces future efficiency
3. **Plant Health Dynamics**: Stressed plants regrow slower and may suffer permanent damage
4. **Risk/Reward Decisions**: Cancel early for partial yield, or commit full time for full reward
5. **Genetics Matter**: High-vigor plants harvest faster, high-resilience plants handle stress better
6. **Economic Depth**: Energy is committed upfront (sunk cost), encouraging completion
7. **Natural Gameplay Loops**: Players balance immediate needs vs long-term plant health

The harvesting experience feels realistic and engaging:

```
Inspect plant → "Berry Bush: 47/80 yield, healthy, low stress"
Start harvest(20) → "Locked in for 45 blocks, 200 energy committed"
Check progress → "73% complete, 12 blocks remaining"
Complete → "Harvested 18 berries (quality: 85%), plant now stressed"
Wait for regrowth → "Bush recovering, stress reducing over time"
```

This creates a natural farming simulation where players must:

- Choose which plants to harvest based on current yield and health
- Manage their time commitments across multiple activities
- Balance short-term resource needs with long-term plant sustainability
- Develop expertise in plant genetics to optimize harvesting strategies

---

# Adventurer & Inventory System

## Adventurer Management

Players don't directly control characters - they manage multiple **Adventurers** who act as autonomous agents:

````python
struct Adventurer:
    id: felt252                    # Unique adventurer ID
    owner: felt252                 # Player who owns this adventurer
    name: felt252                  # Custom name

    # Location & Status
    coord: HexCoord                # Current position
    activity: ActivityState        # Current activity (harvesting, etc.)
    health: u32                    # Current health points
    max_health: u32                # Maximum health
    energy: u32                    # Current energy
    max_energy: u32                # Maximum energy

    # Inventory System
    backpack: Backpack             # Inventory container

    # Core Stats (module-agnostic)
    level: u32                     # Overall adventurer level
    total_experience: u64          # Lifetime experience points

    # Creation
    creation_block: u64            # When this adventurer was created
    is_alive: bool                 # False = permanently dead

storage adventurers: LegacyMap<felt252, Adventurer>
storage player_adventurer_lists: LegacyMap<felt252, Array<felt252>>  # Player → [adventurer_ids]

## Modular Skill System

Each module manages its own skills independently:

```python
# Generic skill storage - any module can use this
struct AdventurerSkill:
    adventurer_id: felt252
    skill_type: felt252            # "harvesting", "mining", "exploration", etc.
    level: u32                     # Skill level
    experience: u64                # Experience points in this skill
    last_used: u64                 # When skill was last used

storage adventurer_skills: LegacyMap<felt252, AdventurerSkill>  # Key: hash(adventurer_id, skill_type)

# Skill registration for modules
struct SkillDefinition:
    skill_type: felt252            # "harvesting"
    max_level: u32                 # Maximum skill level
    experience_curve: Array<u64>   # Experience needed for each level
    module_owner: felt252          # Which module owns this skill

storage skill_definitions: LegacyMap<felt252, SkillDefinition>

# Skill management functions
fn register_skill(skill_type: felt252, max_level: u32, experience_curve: Array<u64>, module_owner: felt252):
    let definition = SkillDefinition(
        skill_type: skill_type,
        max_level: max_level,
        experience_curve: experience_curve,
        module_owner: module_owner
    );
    skill_definitions.write(skill_type, definition);

fn add_skill_experience(adventurer_id: felt252, skill_type: felt252, exp_gain: u64):
    let skill_key = hash(adventurer_id, skill_type);
    let mut skill = adventurer_skills.read(skill_key);

    # Initialize skill if it doesn't exist
    if skill.adventurer_id == 0:
        skill = AdventurerSkill(
            adventurer_id: adventurer_id,
            skill_type: skill_type,
            level: 1,
            experience: 0,
            last_used: block_number()
        );
    }

    skill.experience += exp_gain;
    skill.last_used = block_number();

    # Check for level up
    let definition = skill_definitions.read(skill_type);
    while skill.level < definition.max_level &&
          skill.experience >= definition.experience_curve[skill.level]:
        skill.level += 1;

    adventurer_skills.write(skill_key, skill);
    emit SkillLevelUp(adventurer_id, skill_type, skill.level);

fn get_adventurer_skill(adventurer_id: felt252, skill_type: felt252) -> AdventurerSkill:
    let skill_key = hash(adventurer_id, skill_type);
    adventurer_skills.read(skill_key)

# Register harvesting skill when module is initialized
fn init_harvesting_skills():
    let exp_curve = array![
        0, 100, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000  # Levels 1-10
    ];
    register_skill("harvesting", 10, exp_curve, "harvesting_module");
````

## Backpack & Inventory System

Each adventurer has a weight-limited backpack:

```python
struct Backpack:
    max_weight: u32                # Maximum carry capacity (grams)
    current_weight: u32            # Current total weight
    max_slots: u32                 # Maximum number of item stacks
    current_slots: u32             # Current number of occupied slots
    items: Array<InventoryItem>    # Items in backpack

struct InventoryItem:
    item_id: felt252               # Type of item (species for plants)
    quantity: u32                  # How many of this item
    quality: u8                    # Item quality (0-100)
    weight_per_unit: u32           # Weight in grams per unit
    total_weight: u32              # Total weight of this stack
    metadata: felt252              # Extra data (genetics hash for plants, etc.)

# Item definitions with base weights
struct ItemDefinition:
    item_id: felt252               # Item identifier
    base_weight: u32               # Base weight in grams
    max_stack_size: u32            # Maximum items per stack
    item_type: ItemType            # Plant, Ore, Crafted, etc.

enum ItemType:
    PLANT,                         # Harvested plants
    ORE,                           # Mined ores
    CRAFTED,                       # Crafted items
    TOOL,                          # Tools and equipment
    CONSUMABLE                     # Food, potions, etc.

# Global item registry
storage item_definitions: LegacyMap<felt252, ItemDefinition>
```

## Weight & Capacity Mechanics

```python
fn calculate_item_weight(item: InventoryItem) -> u32:
    # Base weight modified by quality (higher quality = denser/heavier)
    let quality_modifier = 80 + (item.quality / 5);  # 80-100% of base weight
    (item.weight_per_unit * item.quantity * quality_modifier) / 100

fn can_add_item(backpack: Backpack, item_id: felt252, quantity: u32, quality: u8) -> bool:
    let item_def = item_definitions.read(item_id);
    let weight_per_unit = (item_def.base_weight * (80 + quality / 5)) / 100;
    let total_weight = weight_per_unit * quantity;

    # Check weight limit
    if backpack.current_weight + total_weight > backpack.max_weight:
        return false;

    # Check if can stack with existing item
    for existing_item in backpack.items:
        if existing_item.item_id == item_id && existing_item.quality == quality:
            if existing_item.quantity + quantity <= item_def.max_stack_size:
                return true;  # Can stack
        }

    # Check slot limit for new stack
    if backpack.current_slots >= backpack.max_slots:
        return false;

    true

fn add_item_to_backpack(adventurer_id: felt252, item_id: felt252, quantity: u32, quality: u8, metadata: felt252) -> AddItemResult:
    let mut adventurer = adventurers.read(adventurer_id);

    if !can_add_item(adventurer.backpack, item_id, quantity, quality):
        return AddItemResult.BackpackFull;

    let item_def = item_definitions.read(item_id);
    let weight_per_unit = (item_def.base_weight * (80 + quality / 5)) / 100;

    # Try to stack with existing item
    for i in 0..adventurer.backpack.items.len():
        let mut existing = adventurer.backpack.items[i];
        if existing.item_id == item_id && existing.quality == quality && existing.metadata == metadata:
            let can_add = min(quantity, item_def.max_stack_size - existing.quantity);

            existing.quantity += can_add;
            existing.total_weight = existing.quantity * weight_per_unit;
            adventurer.backpack.items[i] = existing;
            adventurer.backpack.current_weight += can_add * weight_per_unit;

            if can_add == quantity:
                adventurers.write(adventurer_id, adventurer);
                return AddItemResult.Success(can_add);
            }

            quantity -= can_add;
        }

    # Create new stack for remaining items
    if quantity > 0:
        let new_item = InventoryItem(
            item_id: item_id,
            quantity: quantity,
            quality: quality,
            weight_per_unit: weight_per_unit,
            total_weight: quantity * weight_per_unit,
            metadata: metadata
        );

        adventurer.backpack.items.append(new_item);
        adventurer.backpack.current_slots += 1;
        adventurer.backpack.current_weight += new_item.total_weight;
    }

    adventurers.write(adventurer_id, adventurer);
    AddItemResult.Success(quantity)
```

## Item Weight Categories

```python
# Example item weights (in grams)
fn register_base_items():
    # Plants (light but bulky)
    register_item("berry", 50, 20, ItemType.PLANT);           # 50g each, max 20 per stack
    register_item("herb", 30, 30, ItemType.PLANT);            # 30g each, max 30 per stack
    register_item("mushroom", 80, 15, ItemType.PLANT);        # 80g each, max 15 per stack
    register_item("rare_flower", 20, 5, ItemType.PLANT);      # 20g each, max 5 per stack

    # Ores (heavy)
    register_item("iron_ore", 500, 10, ItemType.ORE);         # 500g each, max 10 per stack
    register_item("copper_ore", 400, 12, ItemType.ORE);       # 400g each, max 12 per stack
    register_item("gold_ore", 800, 5, ItemType.ORE);          # 800g each, max 5 per stack

    # Crafted items
    register_item("iron_bar", 1000, 5, ItemType.CRAFTED);     # 1kg each, max 5 per stack
    register_item("health_potion", 200, 10, ItemType.CONSUMABLE);  # 200g each, max 10 per stack

    # Tools (heavy, single items)
    register_item("iron_pickaxe", 2000, 1, ItemType.TOOL);    # 2kg each, no stacking
    register_item("steel_axe", 2500, 1, ItemType.TOOL);       # 2.5kg each, no stacking

fn register_item(id: felt252, weight: u32, stack_size: u32, item_type: ItemType):
    let definition = ItemDefinition(
        item_id: id,
        base_weight: weight,
        max_stack_size: stack_size,
        item_type: item_type
    );
    item_definitions.write(id, definition);
```

## Backpack Tiers & Upgrades

```python
enum BackpackTier:
    BASIC,      # 10kg capacity, 8 slots
    IMPROVED,   # 15kg capacity, 12 slots
    ADVANCED,   # 20kg capacity, 16 slots
    MASTER      # 30kg capacity, 20 slots

fn create_backpack(tier: BackpackTier) -> Backpack:
    let (max_weight, max_slots) = match tier:
        BackpackTier.BASIC => (10000, 8),     # 10kg, 8 slots
        BackpackTier.IMPROVED => (15000, 12), # 15kg, 12 slots
        BackpackTier.ADVANCED => (20000, 16), # 20kg, 16 slots
        BackpackTier.MASTER => (30000, 20)    # 30kg, 20 slots
    };

    Backpack(
        max_weight: max_weight,
        current_weight: 0,
        max_slots: max_slots,
        current_slots: 0,
        items: array![]
    )
```

## Integration with Harvesting System

```python
fn complete_harvesting_for_adventurer(adventurer_id: felt252) -> HarvestCompletionResult:
    let mut adventurer = adventurers.read(adventurer_id);

    match adventurer.activity:
        ActivityState.HARVESTING(activity) => {
            assert block_number() >= activity.estimated_completion, "Harvesting not yet complete";

            # Get plant and update its state (same as before)
            let plant_key = hash(activity.hex_coord.to_key(), activity.area_id, activity.plant_id);
            let mut plant = plant_nodes.read(plant_key);

            plant.current_yield -= activity.amount_requested;
            plant.last_harvest_block = block_number();
            plant.total_lifetime_harvested += activity.amount_requested;

            # Calculate stress and health effects
            let stress_increase = calculate_harvest_stress(activity.amount_requested, plant.max_yield);
            plant.stress_level = min(100, plant.stress_level + stress_increase);

            plant_nodes.write(plant_key, plant);

            # Calculate actual yield with genetics
            let genetics = decode_genetics(plant.genetics_hash);
            let actual_yield = (activity.amount_requested * genetics.potency) / 100;
            let final_quality = genetics.potency;

            # Try to add to adventurer's backpack
            let add_result = add_item_to_backpack(
                adventurer_id,
                plant.species,
                actual_yield,
                final_quality,
                plant.genetics_hash  # Store genetics as metadata
            );

            match add_result:
                                 AddItemResult.Success(amount_added) => {
                     # Free adventurer from activity
                     adventurer.activity = ActivityState.IDLE;

                     # Gain harvesting experience through modular skill system
                     let exp_gain = calculate_harvest_experience(activity.amount_requested, genetics.rarity);
                     add_skill_experience(adventurer_id, "harvesting", exp_gain);

                     adventurers.write(adventurer_id, adventurer);

                     emit HarvestingCompleted(adventurer_id, activity.hex_coord, activity.area_id, activity.plant_id, amount_added);

                     if amount_added < actual_yield:
                         return HarvestCompletionResult.PartialSuccess(amount_added, "Backpack full - some items lost");
                     } else {
                         return HarvestCompletionResult.Success(amount_added, final_quality);
                     }
                 },
                AddItemResult.BackpackFull => {
                    # Still free from activity but lose all items
                    adventurer.activity = ActivityState.IDLE;
                    adventurers.write(adventurer_id, adventurer);

                    emit HarvestingCompleted(adventurer_id, activity.hex_coord, activity.area_id, activity.plant_id, 0);
                    return HarvestCompletionResult.Failed("Backpack full - all items lost");
                }
            }
        },
        _ => HarvestCompletionResult.NotHarvesting
    }
```

## Player Management Commands

```python
# Create new adventurer
fn create_adventurer(player: felt252, name: felt252) -> felt252:
    let adventurer_id = generate_unique_id();
    let starting_coord = HexCoord(WORLD_CENTER, WORLD_CENTER);  # All start at center

    let new_adventurer = Adventurer(
        id: adventurer_id,
        owner: player,
        name: name,
        coord: starting_coord,
        activity: ActivityState.IDLE,
        health: 100,
        max_health: 100,
        energy: 100,
        max_energy: 100,
        backpack: create_backpack(BackpackTier.BASIC),
        level: 1,
        total_experience: 0,
        creation_block: block_number(),
        is_alive: True
    );

    adventurers.write(adventurer_id, new_adventurer);

    # Add to player's adventurer list
    let mut player_list = player_adventurer_lists.read(player);
    player_list.append(adventurer_id);
    player_adventurer_lists.write(player, player_list);

    emit AdventurerCreated(player, adventurer_id, name);
    adventurer_id

# Send adventurer on harvest quest
fn send_adventurer_harvest(player: felt252, adventurer_id: felt252, hex_coord: HexCoord, area_id: u32, plant_id: u32, amount: u32) -> CommandResult:
    let adventurer = adventurers.read(adventurer_id);
    assert adventurer.owner == player, "Not your adventurer";

    # Use existing harvesting system but for specific adventurer
    start_harvesting_for_adventurer(adventurer_id, hex_coord, area_id, plant_id, amount)

# View adventurer status
fn get_adventurer_status(adventurer_id: felt252) -> AdventurerStatus:
    let adventurer = adventurers.read(adventurer_id);

    # Get all skills for this adventurer
    let harvesting_skill = get_adventurer_skill(adventurer_id, "harvesting");
    let exploration_skill = get_adventurer_skill(adventurer_id, "exploration");
    let mining_skill = get_adventurer_skill(adventurer_id, "mining");

    AdventurerStatus(
        id: adventurer.id,
        name: adventurer.name,
        coord: adventurer.coord,
        activity: adventurer.activity,
        health: adventurer.health,
        energy: adventurer.energy,
        is_alive: adventurer.is_alive,
        backpack_weight: f"{adventurer.backpack.current_weight}/{adventurer.backpack.max_weight}g",
        backpack_slots: f"{adventurer.backpack.current_slots}/{adventurer.backpack.max_slots}",
        level: adventurer.level,
        total_experience: adventurer.total_experience,
        skills: build_skill_summary(adventurer_id)  # Dynamic skill list
    )

fn build_skill_summary(adventurer_id: felt252) -> Array<SkillSummary>:
    # Query all registered skill types and return adventurer's levels
    let mut skills = array![];

    # This would iterate through all registered skill types
    # For now, manually check common skills
    let skill_types = array!["harvesting", "exploration", "mining", "crafting"];

    for skill_type in skill_types:
        let skill = get_adventurer_skill(adventurer_id, skill_type);
        if skill.adventurer_id != 0:  # Skill exists
            skills.append(SkillSummary(
                skill_type: skill_type,
                level: skill.level,
                experience: skill.experience
            ));
        }
    }

    skills

struct SkillSummary:
    skill_type: felt252
    level: u32
    experience: u64

# View adventurer inventory
fn get_adventurer_inventory(adventurer_id: felt252) -> Array<InventoryItem>:
    let adventurer = adventurers.read(adventurer_id);
    adventurer.backpack.items

# Transfer items between adventurers (if at same location)
fn transfer_item(player: felt252, from_adventurer: felt252, to_adventurer: felt252, item_id: felt252, quantity: u32) -> TransferResult:
    let from_adv = adventurers.read(from_adventurer);
    let to_adv = adventurers.read(to_adventurer);

    assert from_adv.owner == player && to_adv.owner == player, "Not your adventurers";
    assert from_adv.coord == to_adv.coord, "Adventurers must be at same location";

    # Remove from source, add to destination
    # Implementation details...
```

## True Permadeath System

```python
fn adventurer_death(adventurer_id: felt252, death_cause: DeathCause) -> DeathResult:
    let mut adventurer = adventurers.read(adventurer_id);
    assert adventurer.is_alive, "Adventurer already dead";

    # All items in backpack are lost forever
    let lost_items = adventurer.backpack.items.clone();

    # Mark adventurer as permanently dead
    adventurer.is_alive = False;
    adventurer.activity = ActivityState.IDLE;
    adventurer.backpack = create_empty_backpack();  # Clear inventory

    adventurers.write(adventurer_id, adventurer);

    # Remove from player's active adventurer list
    let mut player_list = player_adventurer_lists.read(adventurer.owner);
    player_list = remove_adventurer_from_list(player_list, adventurer_id);
    player_adventurer_lists.write(adventurer.owner, player_list);

    emit AdventurerDeath(adventurer_id, death_cause, lost_items);
    DeathResult.PermanentDeath(lost_items)

# Players must recruit new adventurers to replace dead ones
fn recruit_new_adventurer(player: felt252, name: felt252) -> felt252:
    # Same as create_adventurer but emphasizes the recruitment aspect
    create_adventurer(player, name)
```

This system creates strategic depth where players must:

- **Manage multiple expeditions** simultaneously
- **Balance risk vs reward** - send experienced adventurers on dangerous missions?
- **Optimize backpack space** - what items are worth carrying back?
- **Plan supply chains** - use some adventurers as "mules" to ferry items
- **Accept permenant loss** - death means losing everything they were carrying

The weight system adds realistic constraints and forces interesting decisions about what to bring back vs what to leave behind.

## Benefits of the Modular Adventurer System

This redesigned system achieves maximum composability and creates brutal but engaging gameplay:

### 🔥 True Permadeath Stakes

- **No revival**: Dead adventurers are gone forever
- **Total loss**: All carried items disappear permanently
- **Constant recruitment**: Players must continuously recruit new adventurers
- **High tension**: Every expedition carries real risk

### 🧩 Maximum Extensibility

- **Module-agnostic skills**: Core adventurer struct never needs updates
- **Easy skill addition**: New modules just register their skill types
- **No breaking changes**: Adding mining/crafting/etc. doesn't touch existing code
- **Future-proof**: System scales to unlimited module types

### 📈 Dynamic Skill Development

```python
// Each module manages its own progression
register_skill("harvesting", max_level=10, exp_curve=[...])
register_skill("mining", max_level=15, exp_curve=[...])
register_skill("beast_taming", max_level=8, exp_curve=[...])  // Future module

// Skills develop through actual use
harvest_plant() → gain "harvesting" experience
discover_hex() → gain "exploration" experience
craft_item() → gain "crafting" experience
```

### ⚖️ Strategic Resource Management

- **Expendable assets**: Adventurers become valuable but replaceable resources
- **Risk calculation**: "Is this rare plant worth risking my level 8 harvester?"
- **Portfolio management**: Balance experienced vs rookie adventurers
- **Supply chain optimization**: Coordinate multiple adventurers for complex operations

### 🎯 Emergent Gameplay Patterns

```
Scenario 1: "The Veteran's Last Run"
→ High-skill adventurer with rare gear
→ Goes for valuable distant resource
→ Dies to unexpected hazard
→ Player loses months of investment

Scenario 2: "The Rookie Swarm"
→ Send multiple low-skill adventurers
→ Accept high casualty rate
→ Numbers compensate for individual weakness

Scenario 3: "The Specialists"
→ Different adventurers for different tasks
→ Never risk specialists outside their domain
→ Careful coordination between specialists
```

This creates a brutal but fair world where every decision matters and players must constantly balance ambition against the very real possibility of catastrophic loss.

---

# Trait-Based Crafting System

## Plant Trait Framework

Every plant (and crafted food) has 5 core traits that define its properties:

```python
struct FoodTraits:
    nutritional: u8      # 0-100: Hunger restoration power
    medicinal: u8        # 0-100: Health restoration power
    energizing: u8       # 0-100: Energy restoration power
    potency: u8          # 0-100: Multiplier for all effects
    harmony: u8          # 0-100: How well it combines with others

struct CraftableItem:
    item_id: felt252             # Unique identifier
    name: felt252                # Display name
    traits: FoodTraits           # Core properties
    source_genetics: felt252     # Original plant genetics (if applicable)
    recipe_hash: felt252         # Hash of ingredients used to create this
    crafted_by: felt252          # Adventurer who crafted this
    creation_block: u64          # When it was crafted
    base_weight: u32             # Weight in grams
    item_tier: u8                # 1=basic plant, 2=1-combo, 3=2-combo, etc.

# Examples of base plants with their traits
plant_trait_definitions = {
    "apple": FoodTraits(nutritional: 60, medicinal: 40, energizing: 20, potency: 50, harmony: 80),
    "cinnamon": FoodTraits(nutritional: 30, medicinal: 15, energizing: 70, potency: 75, harmony: 90),
    "berry": FoodTraits(nutritional: 40, medicinal: 25, energizing: 35, potency: 40, harmony: 70),
    "mushroom": FoodTraits(nutritional: 80, medicinal: 60, energizing: 10, potency: 65, harmony: 45),
    "herb": FoodTraits(nutritional: 20, medicinal: 85, energizing: 25, potency: 80, harmony: 60),
    "rare_flower": FoodTraits(nutritional: 10, medicinal: 95, energizing: 80, potency: 90, harmony: 30)
}
```

## Universal Crafting Algorithm

Any two items can be combined using this trait-blending system:

```python
fn craft_food_combination(
    adventurer_id: felt252,
    ingredient_1: CraftableItem,
    ingredient_2: CraftableItem,
    craft_method: CraftingMethod
) -> CraftingResult:

    # Validate adventurer has crafting skill and ingredients
    let adventurer = adventurers.read(adventurer_id);
    assert adventurer.is_alive, "Dead adventurers cannot craft";

    let crafting_skill = get_adventurer_skill(adventurer_id, "crafting");

    # Calculate crafting success chance based on skill
    let base_success_chance = 60 + (crafting_skill.level * 4);  # 60-100% success rate
    let harmony_bonus = (ingredient_1.traits.harmony + ingredient_2.traits.harmony) / 10;
    let total_success_chance = min(95, base_success_chance + harmony_bonus);

    # Determine if crafting succeeds
    let craft_seed = hash(adventurer_id, ingredient_1.item_id, ingredient_2.item_id, block_number());
    let success_roll = (craft_seed % 100);

    if success_roll >= total_success_chance:
        return CraftingResult.Failure("Crafting attempt failed - ingredients wasted");

    # Blend traits using weighted average + method bonuses
    let new_traits = blend_traits(ingredient_1.traits, ingredient_2.traits, craft_method, craft_seed);

    # Generate new item
    let recipe_hash = hash(ingredient_1.item_id, ingredient_2.item_id, craft_method);
    let new_item_id = hash(recipe_hash, block_number());
    let new_name = generate_combination_name(ingredient_1.name, ingredient_2.name, craft_method);

    let crafted_item = CraftableItem(
        item_id: new_item_id,
        name: new_name,
        traits: new_traits,
        source_genetics: hash(ingredient_1.source_genetics, ingredient_2.source_genetics),
        recipe_hash: recipe_hash,
        crafted_by: adventurer_id,
        creation_block: block_number(),
        base_weight: (ingredient_1.base_weight + ingredient_2.base_weight) / 2,
        item_tier: max(ingredient_1.item_tier, ingredient_2.item_tier) + 1
    );

    # Add crafting experience
    let exp_gain = calculate_crafting_experience(ingredient_1.item_tier, ingredient_2.item_tier);
    add_skill_experience(adventurer_id, "crafting", exp_gain);

    # Consume ingredients and add crafted item to backpack
    remove_from_backpack(adventurer_id, ingredient_1.item_id, 1);
    remove_from_backpack(adventurer_id, ingredient_2.item_id, 1);
    add_item_to_backpack(adventurer_id, new_item_id, 1, new_traits.potency, recipe_hash);

    emit FoodCrafted(adventurer_id, new_item_id, new_name, new_traits);
    CraftingResult.Success(crafted_item)

enum CraftingMethod:
    MIXING,          # Simple combination - average traits
    BOILING,         # Enhances medicinal, reduces harmony
    FERMENTING,      # Enhances potency, takes time
    GRINDING,        # Enhances energizing, reduces nutritional
    SMOKING          # Enhances preservation, reduces medicinal
```

## Trait Blending Algorithm

```python
fn blend_traits(
    traits_1: FoodTraits,
    traits_2: FoodTraits,
    method: CraftingMethod,
    seed: felt252
) -> FoodTraits:

    let rng = init_rng(seed);

    # Base blending: weighted average with slight randomness
    let base_nutritional = ((traits_1.nutritional + traits_2.nutritional) / 2) + rng.range(-5, 5);
    let base_medicinal = ((traits_1.medicinal + traits_2.medicinal) / 2) + rng.range(-5, 5);
    let base_energizing = ((traits_1.energizing + traits_2.energizing) / 2) + rng.range(-5, 5);
    let base_potency = ((traits_1.potency + traits_2.potency) / 2) + rng.range(-3, 7);  # Slight upward bias
    let base_harmony = ((traits_1.harmony + traits_2.harmony) / 2) + rng.range(-8, 3);  # Slight downward bias

    # Apply crafting method modifiers
    let (nutritional, medicinal, energizing, potency, harmony) = match method:
        CraftingMethod.MIXING => {
            # Pure combination - no bonuses or penalties
            (base_nutritional, base_medicinal, base_energizing, base_potency, base_harmony)
        },
        CraftingMethod.BOILING => {
            # Enhances medicinal properties, reduces harmony
            (base_nutritional, base_medicinal + 10, base_energizing, base_potency + 5, base_harmony - 15)
        },
        CraftingMethod.FERMENTING => {
            # Greatly enhances potency, slightly reduces others
            (base_nutritional - 5, base_medicinal - 5, base_energizing - 5, base_potency + 20, base_harmony)
        },
        CraftingMethod.GRINDING => {
            # Enhances energizing, reduces nutritional
            (base_nutritional - 10, base_medicinal, base_energizing + 15, base_potency, base_harmony)
        },
        CraftingMethod.SMOKING => {
            # Preserves well but reduces medicinal
            (base_nutritional + 5, base_medicinal - 10, base_energizing, base_potency, base_harmony + 10)
        }
    };

    # Clamp all values to 0-100 range
    FoodTraits(
        nutritional: clamp(nutritional, 0, 100),
        medicinal: clamp(medicinal, 0, 100),
        energizing: clamp(energizing, 0, 100),
        potency: clamp(potency, 0, 100),
        harmony: clamp(harmony, 0, 100)
    )

fn generate_combination_name(name_1: felt252, name_2: felt252, method: CraftingMethod) -> felt252:
    # Generate descriptive names based on method and ingredients
    match method:
        CraftingMethod.MIXING => hash("mixed", name_1, name_2),      # "Mixed Apple Cinnamon"
        CraftingMethod.BOILING => hash("stewed", name_1, name_2),    # "Stewed Apple Cinnamon"
        CraftingMethod.FERMENTING => hash("fermented", name_1, name_2), # "Fermented Apple Cinnamon"
        CraftingMethod.GRINDING => hash("ground", name_1, name_2),   # "Ground Apple Cinnamon"
        CraftingMethod.SMOKING => hash("smoked", name_1, name_2)     # "Smoked Apple Cinnamon"
    }
```

## Consumption & Effects

```python
fn consume_food(adventurer_id: felt252, food_item: CraftableItem, quantity: u32) -> ConsumptionResult:
    let mut adventurer = adventurers.read(adventurer_id);
    assert adventurer.is_alive, "Dead adventurers cannot eat";

    # Calculate effects based on traits and potency
    let potency_multiplier = (food_item.traits.potency + 50) / 100;  # 0.5x to 1.5x multiplier

    let hunger_restored = (food_item.traits.nutritional * potency_multiplier * quantity) / 100;
    let health_restored = (food_item.traits.medicinal * potency_multiplier * quantity) / 100;
    let energy_restored = (food_item.traits.energizing * potency_multiplier * quantity) / 100;

    # Apply effects
    adventurer.health = min(adventurer.max_health, adventurer.health + health_restored);
    adventurer.energy = min(adventurer.max_energy, adventurer.energy + energy_restored);
    # Note: Hunger would be tracked separately if we add that system

    # Remove consumed items from backpack
    remove_from_backpack(adventurer_id, food_item.item_id, quantity);

    adventurers.write(adventurer_id, adventurer);

    emit FoodConsumed(adventurer_id, food_item.item_id, quantity, hunger_restored, health_restored, energy_restored);
    ConsumptionResult.Success(hunger_restored, health_restored, energy_restored)
```

## Advanced Crafting Combinations

```python
# Example combinations and their emergent properties:

# Apple (nutritional:60, medicinal:40, energizing:20, potency:50, harmony:80)
# + Cinnamon (nutritional:30, medicinal:15, energizing:70, potency:75, harmony:90)
# = Cinnamon Apple (nutritional:45, medicinal:28, energizing:45, potency:63, harmony:85)
#   → Balanced food with good energy boost

# Mushroom (nutritional:80, medicinal:60, energizing:10, potency:65, harmony:45)
# + Herb (nutritional:20, medicinal:85, energizing:25, potency:80, harmony:60)
# = Herbal Mushroom (nutritional:50, medicinal:73, energizing:18, potency:73, harmony:53)
#   → Powerful healing food

# Rare Flower (nutritional:10, medicinal:95, energizing:80, potency:90, harmony:30)
# + Berry (nutritional:40, medicinal:25, energizing:35, potency:40, harmony:70)
# = Flower Berry (nutritional:25, medicinal:60, energizing:58, potency:65, harmony:50)
#   → Potent energy + healing combo

# Then craft combinations of combinations:
# Cinnamon Apple + Herbal Mushroom = "Spiced Mushroom Medley"
# → Even more complex trait blending
```

## Crafting Skill Registration

```python
fn init_crafting_skills():
    let exp_curve = array![
        0, 200, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000  # Levels 1-10
    ];
    register_skill("crafting", 10, exp_curve, "crafting_module");

fn calculate_crafting_experience(tier_1: u8, tier_2: u8) -> u64:
    # More experience for crafting higher-tier items
    let base_exp = 50;
    let tier_bonus = (tier_1 + tier_2) * 25;
    base_exp + tier_bonus
```

This system creates infinite crafting possibilities where every combination is meaningful and emergent properties arise naturally from the trait blending.

---

# Plant Categories & Biome Distribution

## Plant Categories with Natural Trait Tendencies

Each category has inherent trait patterns that influence what grows where:

```python
enum PlantCategory:
    FRUIT,        # Sweet, nutritional, harmonious
    VEGETABLE,    # Balanced nutrition, filling
    HERB,         # Medicinal focus, moderate harmony
    SPICE,        # Potency amplifiers, very high harmony
    MUSHROOM,     # Unique properties, variable harmony
    FLOWER,       # Medicinal + energizing, often exotic
    ROOT,         # Grounding nutrition, reliable
    SEED_NUT      # Concentrated energy, portable

struct CategoryTraitTendencies:
    base_nutritional: (u8, u8)    # (min, max) range for this category
    base_medicinal: (u8, u8)
    base_energizing: (u8, u8)
    base_potency: (u8, u8)
    base_harmony: (u8, u8)
    rarity_modifier: i8           # -10 to +10, affects spawn rates

# Natural trait ranges for each category
category_tendencies = {
    PlantCategory.FRUIT: CategoryTraitTendencies(
        base_nutritional: (50, 80),    # Fruits are filling
        base_medicinal: (20, 50),      # Some healing properties
        base_energizing: (15, 40),     # Natural sugars provide energy
        base_potency: (40, 60),        # Moderate potency
        base_harmony: (70, 95),        # Fruits mix well with everything
        rarity_modifier: 0             # Common
    ),

    PlantCategory.VEGETABLE: CategoryTraitTendencies(
        base_nutritional: (60, 90),    # Very filling
        base_medicinal: (10, 40),      # Basic nutrition
        base_energizing: (20, 45),     # Steady energy
        base_potency: (35, 55),        # Moderate potency
        base_harmony: (60, 80),        # Good base for combinations
        rarity_modifier: +2            # Slightly common
    ),

    PlantCategory.HERB: CategoryTraitTendencies(
        base_nutritional: (10, 30),    # Not very filling
        base_medicinal: (60, 95),      # High healing properties
        base_energizing: (15, 35),     # Mild energy
        base_potency: (50, 85),        # High potency
        base_harmony: (45, 75),        # Moderate mixing
        rarity_modifier: -2            # Slightly rare
    ),

    PlantCategory.SPICE: CategoryTraitTendencies(
        base_nutritional: (5, 25),     # Minimal nutrition
        base_medicinal: (20, 50),      # Some therapeutic effects
        base_energizing: (40, 80),     # Stimulating
        base_potency: (70, 95),        # Very high potency multiplier
        base_harmony: (85, 98),        # Excellent for combinations
        rarity_modifier: -5            # Rare and valuable
    ),

    PlantCategory.MUSHROOM: CategoryTraitTendencies(
        base_nutritional: (70, 95),    # Very filling
        base_medicinal: (30, 70),      # Variable healing
        base_energizing: (5, 25),      # Low energy
        base_potency: (50, 80),        # High potency
        base_harmony: (20, 60),        # Unpredictable mixing
        rarity_modifier: -3            # Somewhat rare
    ),

    PlantCategory.FLOWER: CategoryTraitTendencies(
        base_nutritional: (5, 20),     # Not nutritious
        base_medicinal: (70, 98),      # Very high healing
        base_energizing: (60, 90),     # High energy (nectar)
        base_potency: (80, 95),        # Very potent
        base_harmony: (15, 45),        # Difficult to combine
        rarity_modifier: -8            # Very rare
    ),

    PlantCategory.ROOT: CategoryTraitTendencies(
        base_nutritional: (65, 85),    # Solid nutrition
        base_medicinal: (25, 55),      # Grounding effects
        base_energizing: (30, 50),     # Steady energy
        base_potency: (45, 65),        # Reliable potency
        base_harmony: (70, 85),        # Stable base for combinations
        rarity_modifier: +1            # Common and reliable
    ),

    PlantCategory.SEED_NUT: CategoryTraitTendencies(
        base_nutritional: (40, 60),    # Concentrated nutrition
        base_medicinal: (15, 35),      # Minimal healing
        base_energizing: (60, 85),     # High energy density
        base_potency: (55, 75),        # Good potency
        base_harmony: (50, 70),        # Decent mixing
        rarity_modifier: -1            # Slightly uncommon
    )
}
```

## Biome-Category Distribution

Different biomes naturally favor different plant categories:

```python
struct BiomePlantDistribution:
    category_weights: Map<PlantCategory, u32>  # Relative spawn weights
    unique_variants: Array<felt252>            # Biome-specific plant names
    trait_modifiers: BiomeTraitModifiers       # How biome affects traits

struct BiomeTraitModifiers:
    nutritional_mod: i8    # -10 to +10 modifier to nutritional traits
    medicinal_mod: i8      # -10 to +10 modifier to medicinal traits
    energizing_mod: i8     # -10 to +10 modifier to energizing traits
    potency_mod: i8        # -10 to +10 modifier to potency
    harmony_mod: i8        # -10 to +10 modifier to harmony

biome_distributions = {
    BiomeType.FOREST: BiomePlantDistribution(
        category_weights: {
            PlantCategory.FRUIT: 35,        # Berries, tree fruits
            PlantCategory.MUSHROOM: 25,     # Forest fungi
            PlantCategory.HERB: 20,         # Forest herbs
            PlantCategory.ROOT: 15,         # Tree roots, tubers
            PlantCategory.SEED_NUT: 5       # Nuts from trees
        },
        unique_variants: ["oak_acorn", "pine_needle", "forest_berry", "woodland_mushroom"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: +3,    # Rich forest soil
            medicinal_mod: +5,      # Diverse plant medicine
            energizing_mod: 0,      # Neutral
            potency_mod: +2,        # Natural concentration
            harmony_mod: +3         # Balanced ecosystem
        )
    ),

    BiomeType.JUNGLE: BiomePlantDistribution(
        category_weights: {
            PlantCategory.SPICE: 30,        # Tropical spices
            PlantCategory.FLOWER: 25,       # Exotic flowers
            PlantCategory.FRUIT: 25,        # Tropical fruits
            PlantCategory.HERB: 15,         # Medicinal plants
            PlantCategory.ROOT: 5           # Jungle roots
        },
        unique_variants: ["jungle_pepper", "orchid", "passion_fruit", "healing_vine"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: +2,    # Rich biodiversity
            medicinal_mod: +8,      # Many medicinal plants
            energizing_mod: +5,     # Stimulating environment
            potency_mod: +6,        # Concentrated effects
            harmony_mod: -3         # Complex interactions
        )
    ),

    BiomeType.DESERT: BiomePlantDistribution(
        category_weights: {
            PlantCategory.SPICE: 40,        # Desert spices
            PlantCategory.ROOT: 30,         # Hardy roots
            PlantCategory.HERB: 20,         # Survival herbs
            PlantCategory.FLOWER: 10        # Rare desert blooms
        },
        unique_variants: ["desert_sage", "cactus_fruit", "sand_root", "mirage_flower"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: -2,    # Harsh conditions
            medicinal_mod: +3,      # Survival adaptations
            energizing_mod: +4,     # Concentrated energy
            potency_mod: +8,        # Extreme concentration
            harmony_mod: -2         # Harsh combinations
        )
    ),

    BiomeType.GRASSLAND: BiomePlantDistribution(
        category_weights: {
            PlantCategory.VEGETABLE: 40,    # Grasses, grains
            PlantCategory.HERB: 25,         # Common herbs
            PlantCategory.ROOT: 20,         # Ground vegetables
            PlantCategory.SEED_NUT: 15      # Grass seeds
        },
        unique_variants: ["wild_grain", "prairie_herb", "tuber", "grass_seed"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: +5,    # Fertile plains
            medicinal_mod: +1,      # Basic herbs
            energizing_mod: +2,     # Sustained energy
            potency_mod: -1,        # Mild effects
            harmony_mod: +4         # Balanced growth
        )
    ),

    BiomeType.MOUNTAIN: BiomePlantDistribution(
        category_weights: {
            PlantCategory.HERB: 35,         # Mountain herbs
            PlantCategory.ROOT: 30,         # Hardy roots
            PlantCategory.FLOWER: 20,       # Alpine flowers
            PlantCategory.MUSHROOM: 15      # Mountain fungi
        },
        unique_variants: ["alpine_herb", "mountain_root", "snow_blossom", "stone_mushroom"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: -1,    # Harsh growing conditions
            medicinal_mod: +6,      # Pure mountain air
            energizing_mod: +3,     # High altitude effects
            potency_mod: +4,        # Concentrated growth
            harmony_mod: +1         # Clean environment
        )
    ),

    BiomeType.SWAMP: BiomePlantDistribution(
        category_weights: {
            PlantCategory.MUSHROOM: 45,     # Swamp fungi
            PlantCategory.HERB: 30,         # Bog herbs
            PlantCategory.ROOT: 15,         # Swamp roots
            PlantCategory.FLOWER: 10        # Mysterious blooms
        },
        unique_variants: ["bog_mushroom", "swamp_moss", "mire_root", "will_o_wisp_flower"],
        trait_modifiers: BiomeTraitModifiers(
            nutritional_mod: +1,    # Rich organic matter
            medicinal_mod: +7,      # Many healing bog plants
            energizing_mod: -2,     # Sluggish environment
            potency_mod: +5,        # Concentrated bog effects
            harmony_mod: -4         # Unpredictable interactions
        )
    )
}
```

## Dynamic Plant Generation with Categories

```python
fn generate_plant_with_category(
    species_base: felt252,
    category: PlantCategory,
    biome: BiomeType,
    genetics_seed: felt252,
    soil_quality: u32
) -> PlantNode:

    let category_tendency = category_tendencies[category];
    let biome_distribution = biome_distributions[biome];
    let rng = init_rng(genetics_seed);

    # Generate base traits within category ranges
    let base_nutritional = rng.range(category_tendency.base_nutritional.0, category_tendency.base_nutritional.1);
    let base_medicinal = rng.range(category_tendency.base_medicinal.0, category_tendency.base_medicinal.1);
    let base_energizing = rng.range(category_tendency.base_energizing.0, category_tendency.base_energizing.1);
    let base_potency = rng.range(category_tendency.base_potency.0, category_tendency.base_potency.1);
    let base_harmony = rng.range(category_tendency.base_harmony.0, category_tendency.base_harmony.1);

    # Apply biome modifiers
    let nutritional = clamp(base_nutritional + biome_distribution.trait_modifiers.nutritional_mod, 1, 100);
    let medicinal = clamp(base_medicinal + biome_distribution.trait_modifiers.medicinal_mod, 1, 100);
    let energizing = clamp(base_energizing + biome_distribution.trait_modifiers.energizing_mod, 1, 100);
    let potency = clamp(base_potency + biome_distribution.trait_modifiers.potency_mod, 1, 100);
    let harmony = clamp(base_harmony + biome_distribution.trait_modifiers.harmony_mod, 1, 100);

    # Apply soil quality influence (better soil = better traits)
    let soil_bonus = (soil_quality - 50) / 10;  # -5 to +5 bonus

    let final_traits = FoodTraits(
        nutritional: clamp(nutritional + soil_bonus, 1, 100),
        medicinal: clamp(medicinal + soil_bonus, 1, 100),
        energizing: clamp(energizing + soil_bonus, 1, 100),
        potency: clamp(potency + soil_bonus, 1, 100),
        harmony: clamp(harmony + soil_bonus, 1, 100)
    );

    # Generate genetics and create plant
    let genetics = encode_genetics_with_traits(final_traits, category, genetics_seed);

    PlantNode(
        species: species_base,
        category: category,
        traits: final_traits,
        genetics_hash: genetics,
        # ... other plant properties
    )

fn select_plant_category_for_biome(biome: BiomeType, selection_seed: felt252) -> PlantCategory:
    let distribution = biome_distributions[biome];
    weighted_choice(selection_seed, distribution.category_weights)
```

## Trade & Specialization Opportunities

This system creates natural economic drivers:

```python
# Jungle Specialization:
# - Rare spices (high potency, harmony)
# - Exotic flowers (medicinal + energizing)
# → Export: Concentrated healing/energy items
# → Import: Filling foods, balanced nutrition

# Forest Specialization:
# - Abundant fruits (nutritional, harmony)
# - Mushrooms (filling, variable effects)
# → Export: Reliable food sources, versatile ingredients
# → Import: Medicinal herbs, energy boosters

# Desert Specialization:
# - Potent spices (extreme potency)
# - Hardy survival herbs
# → Export: Amplifier ingredients, survival foods
# → Import: Basic nutrition, harmonious mixers

# Example Trade Routes:
# Jungle Pepper (potency:90, harmony:95) + Forest Berry (nutritional:65, harmony:85)
# = Spiced Berry Medley → Perfect adventurer ration
```

This creates a world where each biome has distinct character and value, encouraging exploration, trade, and specialization while maintaining the infinite combination crafting system.

## Nested Location Hierarchy

The plant system follows a fractal structure with multiple levels of discovery:

```python
# Hierarchy: Biome → Hex → Harvesting Areas → Individual Plants

1. BIOME LEVEL (Noise-determined)
   ├── Determines category probabilities (forest = fruits+mushrooms, jungle = spices+flowers)
   ├── Applies biome trait modifiers (+medicinal, +potency, etc.)
   └── Sets the "character" of what can grow here

2. HEX LEVEL (Player-discovered)
   ├── Contains 2-5 harvesting areas when harvesting module initialized
   ├── Each area has random type, size, soil quality
   └── Areas not explored until player specifically enters them

3. AREA LEVEL (Player-explored)
   ├── Area types: "grove", "clearing", "undergrowth", "stream_bank", etc.
   ├── Size (20-100): affects plant density/count
   ├── Soil quality (30-95): affects individual plant trait bonuses
   └── Contains 5-30 individual plants (generated on first exploration)

4. PLANT LEVEL (Harvestable resources)
   ├── Species selected from biome's category weights
   ├── Category determines base trait ranges
   ├── Biome modifiers adjust traits
   ├── Soil quality provides final bonus
   └── Unique genetics per plant with growth/yield mechanics

# Example walkthrough:
Forest Biome → Hex(12,15) → Grove Area → 18 individual plants:
  - 6x Forest Berry (fruit category, nutritional focus)
  - 4x Woodland Mushroom (mushroom category, filling but unpredictable)
  - 3x Pine Needle (herb category, medicinal focus)
  - 2x Oak Acorn (seed/nut category, energy dense)
  - 2x Wild Herb (herb category, healing)
  - 1x Rare Forest Flower (flower category, potent but hard to combine)
```

## Area Generation Within Biomes

```python
fn generate_harvesting_areas_for_biome(biome: BiomeType, hex_seed: bytes32) -> Array<HarvestingAreaInfo>:
    let biome_config = biome_distributions[biome];
    let rng = init_rng(hex_seed);

    # Number of areas based on biome richness
    let area_count = match biome:
        BiomeType.JUNGLE => rng.range(3, 6),    # Rich biodiversity = more areas
        BiomeType.FOREST => rng.range(2, 5),    # Moderate diversity
        BiomeType.DESERT => rng.range(1, 3),    # Harsh = fewer areas
        BiomeType.GRASSLAND => rng.range(2, 4), # Consistent but limited
        _ => rng.range(2, 4)                    # Default range
    };

    let mut areas = array![];
    for i in 0..area_count:
        let area_seed = hash(hex_seed, i);
        let area_rng = init_rng(area_seed);

        # Select area type based on biome
        let area_type = weighted_choice(area_rng, get_area_types_for_biome(biome));

        areas.append(HarvestingAreaInfo(
            area_id: i,
            area_type: area_type,
            size: area_rng.range(20, 100),           # Affects plant count
            soil_quality: area_rng.range(30, 95),    # Affects plant traits
            explored: false
        ));

    areas

# Biome-specific area types
fn get_area_types_for_biome(biome: BiomeType) -> Map<felt252, u32>:
    match biome:
        BiomeType.FOREST => {
            "grove": 35,         # Dense fruit/nut clusters
            "clearing": 25,      # Scattered rare plants
            "undergrowth": 20,   # Common herbs
            "stream_bank": 20    # Water-loving plants
        },
        BiomeType.JUNGLE => {
            "canopy": 30,        # High-growing fruits/flowers
            "jungle_floor": 25,  # Mushrooms and ground plants
            "vine_wall": 25,     # Climbing spice plants
            "water_edge": 20     # Bog-like plants
        },
        BiomeType.DESERT => {
            "oasis": 40,         # Rare but rich plant life
            "rocky_outcrop": 35, # Hardy herbs and roots
            "sand_dune": 25      # Sparse but adapted plants
        }
        # ... more biomes
    }
```

## Plant Density & Distribution Per Area

```python
fn generate_plants_for_area(
    area: HarvestingAreaInfo,
    biome: BiomeType,
    area_seed: bytes32
) -> Array<PlantNode>:

    let rng = init_rng(area_seed);
    let biome_config = biome_distributions[biome];

    # Calculate plant count based on area size and soil quality
    let base_density = area.size / 5;  # 4-20 base plants
    let soil_bonus = (area.soil_quality - 50) / 25;  # -2 to +2 plants
    let plant_count = clamp(base_density + soil_bonus + rng.range(-2, 3), 3, 30);

    let mut plants = array![];
    for i in 0..plant_count:
        let plant_seed = hash(area_seed, i);

        # Select category based on biome weights
        let category = weighted_choice(plant_seed, biome_config.category_weights);

        # Select specific species within category
        let species = select_species_for_category_and_area(category, area.area_type, plant_seed);

        # Generate plant with full trait calculation
        let plant = generate_plant_with_category(
            species,
            category,
            biome,
            plant_seed,
            area.soil_quality
        );

        plants.append(plant);

    plants

# Example: Forest Grove with size=60, soil_quality=75
# → base_density = 12, soil_bonus = 1, random = +1
# → 14 plants total:
#   - 5 fruits (35% weight)
#   - 4 mushrooms (25% weight)
#   - 3 herbs (20% weight)
#   - 2 roots (15% weight)
```

This creates natural exploration progression:

1. **Discover hex** → "Forest biome found!"
2. **Initialize harvesting** → "3 areas available: Grove, Clearing, Stream Bank"
3. **Explore grove** → "14 plants discovered, mostly fruits and mushrooms"
4. **Explore clearing** → "8 plants discovered, including rare flowers"
5. **Individual harvesting** → Target specific plants with desired traits

The nested structure means players can choose their level of exploration depth - they might focus on one rich area or survey multiple areas to find the best plants for their crafting needs.

---
