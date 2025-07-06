# Adventurer System: Modular Character Progression

## Core Philosophy: Growth Through Experience

The adventurer system is built on **learning by doing** - characters improve at activities they perform, with a **modular trait system** that expands as new game modules are discovered.

## Core Adventurer Structure

```python
struct Adventurer:
    # Identity & Ownership
    id: felt252,
    owner: felt252,                    # Player who owns this adventurer
    name: felt252,                     # Custom name chosen by player
    creation_block: u64,               # When adventurer was created

    # Core Resources
    energy: u32,                       # Universal energy for all actions
    health: u32,                       # Current health (0-100)
    max_health: u32,                   # Maximum health capacity

    # Position & Movement
    current_hex: felt252,              # Current location in world
    movement_locked_until: u64,        # Block when movement becomes available

    # Activity State
    current_activity: ActivityState,   # What adventurer is currently doing
    activity_locked_until: u64,        # Block when activity completes

    # Base Traits (Always Present)
    base_traits: BaseTraits,

    # Modular Traits (Expandable)
    module_traits: LegacyMap<felt252, ModuleTrait>, # module_id → trait_data

    # Equipment & Inventory
    equipment: AdventurerEquipment,
    inventory: AdventurerInventory,

    # Experience & Progression
    total_experience: u64,             # Lifetime experience gained
    trait_experience: LegacyMap<felt252, u32>, # trait_id → experience points

# Core traits that every adventurer has
struct BaseTraits:
    # Physical Capabilities
    strength: u8,           # 1-100: Physical power, carrying capacity, mining efficiency
    endurance: u8,          # 1-100: Energy efficiency, health regeneration, work duration
    agility: u8,            # 1-100: Movement speed, crafting precision, harvest efficiency
    vitality: u8,           # 1-100: Maximum health, resistance to damage, recovery speed

    # Mental Capabilities
    intelligence: u8,       # 1-100: Learning speed, crafting success rates, research ability
    wisdom: u8,             # 1-100: Energy management, strategic planning, resource conservation
    charisma: u8,           # 1-100: Trading bonuses, social interactions, leadership

    # Specialized Skills
    survival: u8,           # 1-100: Efficiency in harsh environments, risk mitigation
    craftsmanship: u8,      # 1-100: Item creation quality, tool effectiveness, precision work
    leadership: u8,         # 1-100: Managing multiple adventurers, territorial coordination

# Modular traits that can be added by game modules
struct ModuleTrait:
    module_id: felt252,     # Which module owns this trait
    trait_name: felt252,    # Name of the trait
    current_level: u8,      # 1-100: Current proficiency level
    experience_points: u32, # Experience accumulated for this trait
    specializations: Array<felt252>, # Sub-specializations within this trait
    trait_bonuses: Array<TraitBonus>, # Active bonuses from this trait

struct TraitBonus:
    bonus_type: felt252,    # Type of bonus (efficiency, success_rate, cost_reduction, etc.)
    bonus_value: u32,       # Magnitude of the bonus
    conditions: Array<felt252>, # When this bonus applies
```

## Base Trait Functionality

### Core Trait Effects

```python
# Each base trait provides specific benefits across all game systems
trait_effects = {
    "strength": {
        "mining": "Increases ore extraction rate by 1% per point",
        "carrying_capacity": "Increases backpack weight limit by 100g per point",
        "construction": "Reduces building construction time by 0.5% per point",
        "combat": "Increases damage dealt by 1% per point"
    },

    "endurance": {
        "energy_efficiency": "Reduces energy costs by 0.5% per point",
        "health_regen": "Increases health regeneration by 0.1 per point per 100 blocks",
        "work_duration": "Extends maximum work time by 1% per point",
        "environmental_resistance": "Reduces damage from harsh environments"
    },

    "agility": {
        "movement_speed": "Reduces movement time between hexes by 0.5% per point",
        "crafting_precision": "Increases crafting success rates by 0.3% per point",
        "harvesting_efficiency": "Increases plant harvesting speed by 0.8% per point",
        "accident_avoidance": "Reduces chance of work accidents"
    },

    "vitality": {
        "max_health": "Increases maximum health by 0.5 per point",
        "damage_resistance": "Reduces all damage taken by 0.3% per point",
        "recovery_speed": "Increases healing rate from items by 0.5% per point",
        "disease_resistance": "Reduces chance of negative status effects"
    },

    "intelligence": {
        "learning_speed": "Increases trait experience gain by 0.8% per point",
        "crafting_innovation": "Unlocks advanced crafting combinations sooner",
        "research_ability": "Increases research success rates by 0.4% per point",
        "pattern_recognition": "Better at identifying valuable resource locations"
    },

    "wisdom": {
        "energy_management": "Improves energy regeneration efficiency by 0.3% per point",
        "resource_conservation": "Reduces resource waste in all activities by 0.2% per point",
        "strategic_planning": "Provides bonuses for coordinated multi-adventurer activities",
        "risk_assessment": "Better at avoiding dangerous situations"
    },

    "charisma": {
        "trading_bonuses": "Improves trade deal values by 0.4% per point",
        "social_coordination": "Reduces costs for multi-adventurer coordination",
        "leadership_capacity": "Can effectively manage more adventurers simultaneously",
        "reputation_building": "Gains reputation with NPCs/factions faster"
    },

    "survival": {
        "harsh_environment_efficiency": "Reduces penalties in difficult biomes by 0.6% per point",
        "danger_mitigation": "Reduces chance of accidents and negative events",
        "resource_finding": "Better at locating scarce resources",
        "emergency_response": "Faster recovery from dangerous situations"
    },

    "craftsmanship": {
        "item_quality": "Increases quality of created items by 0.3% per point",
        "tool_effectiveness": "Tools last longer and work better",
        "precision_work": "Unlocks advanced crafting techniques",
        "material_efficiency": "Reduces material waste in crafting"
    },

    "leadership": {
        "coordination_efficiency": "Reduces energy costs for managing multiple adventurers",
        "territorial_management": "Improves efficiency of territorial operations",
        "group_activities": "Provides bonuses when multiple adventurers work together",
        "strategic_coordination": "Enables complex multi-adventurer strategies"
    }
}
```

## Modular Trait System

### Dynamic Trait Registration

```python
# Game modules can register new traits that adventurers can develop
trait ITraitModule:
    fn register_trait(trait_definition: TraitDefinition) -> RegistrationResult
    fn get_trait_bonuses(adventurer_id: felt252, trait_id: felt252) -> Array<TraitBonus>
    fn calculate_trait_experience_gain(action_type: felt252, action_result: felt252) -> u32
    fn get_trait_requirements(trait_id: felt252) -> Array<TraitRequirement>

struct TraitDefinition:
    trait_id: felt252,
    trait_name: felt252,
    module_id: felt252,
    description: felt252,
    max_level: u8,
    base_traits_required: Array<BaseTraitRequirement>, # Prerequisites
    unlock_conditions: Array<felt252>, # How to unlock this trait
    experience_sources: Array<felt252>, # What activities give experience
    level_bonuses: Array<LevelBonus>, # Bonuses at each level

# Example: Mining module registers mining-specific traits
mining_efficiency_trait = TraitDefinition {
    trait_id: 'mining_efficiency',
    trait_name: 'Mining Efficiency',
    module_id: 'mining_module',
    description: 'Expertise in extracting ore from veins',
    max_level: 20,
    base_traits_required: [
        BaseTraitRequirement { trait_id: 'strength', minimum_level: 5 },
        BaseTraitRequirement { trait_id: 'endurance', minimum_level: 3 }
    ],
    unlock_conditions: ['perform_mining_action'],
    experience_sources: ['mine_ore', 'discover_vein', 'process_ore'],
    level_bonuses: [
        LevelBonus { level: 5, bonus_type: 'ore_yield', bonus_value: 10, description: '+10% ore yield' },
        LevelBonus { level: 10, bonus_type: 'energy_efficiency', bonus_value: 15, description: '15% less energy for mining' },
        LevelBonus { level: 15, bonus_type: 'rare_ore_chance', bonus_value: 5, description: '5% chance for rare ore' },
        LevelBonus { level: 20, bonus_type: 'vein_mastery', bonus_value: 100, description: 'Master miner abilities' }
    ]
}
```

## Adventurer Creation & Archetypes

### Specialized Builds

```python
# Players can choose from predefined archetypes or create custom builds
adventurer_archetypes = {
    "miner": {
        strength: 20,      # High ore extraction
        endurance: 18,     # Long work periods
        agility: 8,        # Basic precision
        vitality: 15,      # Survive harsh conditions
        intelligence: 10,  # Standard learning
        wisdom: 12,        # Resource management
        charisma: 5,       # Low social skills
        survival: 15,      # Handle dangerous environments
        craftsmanship: 12, # Basic tool use
        leadership: 5,     # Individual worker
        description: "Specialized in resource extraction and surviving harsh mining conditions"
    },

    "merchant": {
        strength: 8,       # Low physical demands
        endurance: 12,     # Moderate work capacity
        agility: 10,       # Basic efficiency
        vitality: 10,      # Average health
        intelligence: 15,  # Market analysis
        wisdom: 18,        # Strategic thinking
        charisma: 20,      # Trading expertise
        survival: 8,       # Relies on infrastructure
        craftsmanship: 5,  # Minimal creation skills
        leadership: 14,    # Coordinate trade networks
        description: "Master of commerce and territorial economic development"
    },

    "explorer": {
        strength: 12,      # Moderate physical ability
        endurance: 18,     # Long journeys
        agility: 15,       # Quick movement
        vitality: 16,      # Survive dangers
        intelligence: 12,  # Learn from discoveries
        wisdom: 15,        # Navigate wisely
        charisma: 8,       # Solitary nature
        survival: 20,      # Master of harsh environments
        craftsmanship: 9,  # Basic repairs
        leadership: 5,     # Independent operator
        description: "Specialized in discovering new territories and surviving in unknown regions"
    },

    "craftsman": {
        strength: 10,      # Moderate physical work
        endurance: 15,     # Long crafting sessions
        agility: 20,       # Precision work
        vitality: 12,      # Standard health
        intelligence: 18,  # Innovation and design
        wisdom: 15,        # Material efficiency
        charisma: 10,      # Standard social skills
        survival: 8,       # Workshop-based
        craftsmanship: 20, # Master creator
        leadership: 7,     # Individual artisan
        description: "Master of item creation and technological innovation"
    },

    "leader": {
        strength: 12,      # Lead by example
        endurance: 15,     # Manage long operations
        agility: 10,       # Standard efficiency
        vitality: 14,      # Healthy leadership
        intelligence: 16,  # Strategic planning
        wisdom: 18,        # Wise decision making
        charisma: 18,      # Inspire others
        survival: 10,      # Rely on others
        craftsmanship: 7,  # Delegate creation
        leadership: 20,    # Master coordinator
        description: "Specialized in managing multiple adventurers and territorial operations"
    }
}
```

## Trait Progression & Synergies

### Experience-Based Learning

```python
# Adventurers gain experience and improve traits through use
fn gain_trait_experience(
    adventurer_id: felt252,
    trait_id: felt252,
    experience_amount: u32,
    activity_context: felt252
) -> ProgressionResult:

    let mut adventurer = adventurers.read(adventurer_id);

    # Intelligence affects learning speed
    let intelligence_bonus = adventurer.base_traits.intelligence;
    let adjusted_experience = (experience_amount * (100 + intelligence_bonus)) / 100;

    # Add experience and check for level ups
    let current_exp = adventurer.trait_experience.read(trait_id);
    let new_exp = current_exp + adjusted_experience;
    adventurer.trait_experience.write(trait_id, new_exp);

    # Check if trait level increases
    let current_level = get_trait_level(adventurer_id, trait_id);
    let new_level = calculate_trait_level_from_experience(new_exp);

    if new_level > current_level:
        apply_trait_level_increase(adventurer_id, trait_id, new_level);
        emit TraitLevelUp(adventurer_id, trait_id, new_level);
    }

    adventurer.total_experience += adjusted_experience;
    adventurers.write(adventurer_id, adventurer);

    ProgressionResult.ExperienceGained(adjusted_experience, new_level)

# Trait synergies provide powerful combinations
fn calculate_trait_synergy_bonuses(adventurer_id: felt252, action_type: felt252) -> u32:
    let adventurer = adventurers.read(adventurer_id);
    let mut synergy_bonus = 0;

    # High craftsmanship + intelligence = innovation bonus
    if adventurer.base_traits.craftsmanship >= 15 && adventurer.base_traits.intelligence >= 15:
        if action_type == 'crafting':
            synergy_bonus += 25; # +25% crafting innovation
        }
    }

    # High leadership + charisma = coordination mastery
    if adventurer.base_traits.leadership >= 12 && adventurer.base_traits.charisma >= 12:
        if action_type == 'territorial_management':
            synergy_bonus += 20; # +20% territorial management
        }
    }

    # Survival + endurance = extreme environment mastery
    if adventurer.base_traits.survival >= 18 && adventurer.base_traits.endurance >= 18:
        if action_type == 'harsh_environment_activity':
            synergy_bonus += 40; # +40% harsh environment efficiency
        }
    }

    synergy_bonus
```

## Integration Benefits

**🎯 Learning by Doing**: Characters naturally improve at activities they perform  
**🔧 Modular Expansion**: New modules can add traits without changing core system  
**⚖️ Balanced Specialization**: Multiple viable character builds and progressions  
**🎮 Strategic Depth**: Trait synergies create complex optimization opportunities  
**📈 Long-term Progression**: Meaningful advancement over extended play periods  
**🏗️ System Integration**: Traits meaningfully affect all game systems

This creates a **rich character progression system** that grows with your game while maintaining strategic depth and meaningful player choice! 🎯⚡🏆
