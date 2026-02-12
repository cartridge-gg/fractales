# Mining System: Prisoner's Dilemma Resources

## Overview

The mining system creates **social coordination challenges** through shared, limited-capacity veins that can collapse if overused. Unlike harvesting (individual plants), mining requires **cooperation** to avoid mutual destruction.

**NEW: Custom Permission Hooks** - Players can deploy their own contracts to control access, fees, and profit-sharing for any mining vein they discover or control.

## Hook-Based Permissions Architecture

The core game mechanics remain immutable, but players can inject **custom business logic** through a flexible hook system:

```python
# Core game contract calls permission hooks at key decision points
trait IPermissionHook:
    fn before_mining_start(
        caller: felt252,
        vein_id: felt252,
        target_amount: u32,
        duration: u64
    ) -> PermissionResult;

    fn after_mining_complete(
        miner: felt252,
        vein_id: felt252,
        ore_extracted: u32,
        ore_value: u64
    ) -> ();

    fn before_vein_access(
        caller: felt252,
        vein_id: felt252
    ) -> AccessResult;

# Permission system registry
storage vein_permission_hooks: LegacyMap<felt252, felt252>  # vein_id → hook_contract_address
storage vein_controllers: LegacyMap<felt252, felt252>      # vein_id → controller_address

# Core mining function with hooks
fn start_mining_operation(
    adventurer_id: felt252,
    vein_id: felt252,
    duration_blocks: u64,
    target_ore_amount: u32
) -> MiningStartResult:

    # Check if vein has custom permission hook
    let hook_address = vein_permission_hooks.read(vein_id);
    if hook_address != 0:
        let hook = IPermissionHookDispatcher(hook_address);
        let permission_result = hook.before_mining_start(
            adventurer_id, vein_id, target_ore_amount, duration_blocks
        );

        match permission_result:
            PermissionResult.Denied(reason) => return MiningStartResult.AccessDenied(reason),
            PermissionResult.RequiresPayment(amount, recipient) => {
                # Handle payment to vein controller
                transfer_gold(adventurer_id, recipient, amount);
            },
            PermissionResult.Approved => {}, # Continue normally
        };
    }

    # ... rest of core mining logic (unchanged)
    # ... vein stability checks, energy costs, etc.

    # After successful mining setup, notify hook
    if hook_address != 0:
        let hook = IPermissionHookDispatcher(hook_address);
        # Hook can track mining participants, adjust internal accounting, etc.
    }

    MiningStartResult.Success(mining_activity, stability_status)
```

## Player-Deployed Permission Contracts

Players can create sophisticated business models by deploying their own permission contracts:

### Example 1: Simple Fee-Based Access

```python
#[starknet::contract]
mod SimpleFeeContract:
    use super::IPermissionHook;

    #[storage]
    struct Storage:
        owner: felt252,
        access_fee: u64,
        revenue_share_percentage: u8,  # 0-100%

    #[external(v0)]
    impl PermissionHookImpl of IPermissionHook:
        fn before_mining_start(
            caller: felt252,
            vein_id: felt252,
            target_amount: u32,
            duration: u64
        ) -> PermissionResult:
            let fee = self.access_fee.read() * target_amount;  # Fee per ore
            PermissionResult.RequiresPayment(fee, self.owner.read())

        fn after_mining_complete(
            miner: felt252,
            vein_id: felt252,
            ore_extracted: u32,
            ore_value: u64
        ) -> ():
            # Calculate revenue share
            let share = (ore_value * self.revenue_share_percentage.read()) / 100;
            # Could automatically transfer share to owner
            # Or track for later distribution
```

### Example 2: Whitelist + Staking Model

```python
#[starknet::contract]
mod StakingGuildContract:
    use super::IPermissionHook;

    #[storage]
    struct Storage:
        guild_token: felt252,              # ERC20 token address
        minimum_stake: u64,                # Required stake to mine
        member_list: LegacyMap<felt252, bool>,
        member_stakes: LegacyMap<felt252, u64>,
        profit_pool: u64,                  # Accumulated profits
        last_distribution: u64,            # Block of last profit distribution

    impl PermissionHookImpl of IPermissionHook:
        fn before_mining_start(
            caller: felt252,
            vein_id: felt252,
            target_amount: u32,
            duration: u64
        ) -> PermissionResult:
            # Check if caller is guild member
            if !self.member_list.read(caller):
                return PermissionResult.Denied("Not a guild member");

            # Check stake requirement
            let stake = self.member_stakes.read(caller);
            if stake < self.minimum_stake.read():
                return PermissionResult.Denied("Insufficient stake");

            PermissionResult.Approved

        fn after_mining_complete(
            miner: felt252,
            vein_id: felt252,
            ore_extracted: u32,
            ore_value: u64
        ) -> ():
            # Add 20% of mining value to profit pool
            let guild_share = ore_value / 5;
            self.profit_pool.write(self.profit_pool.read() + guild_share);

    # Guild-specific functions
    #[external(v0)]
    fn join_guild(stake_amount: u64):
        # Transfer tokens to contract
        # Add to member list
        # Record stake amount

    #[external(v0)]
    fn distribute_profits():
        # Distribute profit pool based on stake percentages
        # Reset profit pool
```

### Example 3: Auction-Based Time Slots

```python
#[starknet::contract]
mod AuctionSlotContract:
    #[storage]
    struct Storage:
        time_slots: LegacyMap<u64, SlotInfo>,  # start_block → slot details
        current_auction: LegacyMap<u64, AuctionInfo>,
        slot_duration: u64,                     # blocks per slot

    #[derive(Drop, Serde, starknet::Store)]
    struct SlotInfo:
        winner: felt252,
        winning_bid: u64,
        start_block: u64,
        end_block: u64,

    impl PermissionHookImpl of IPermissionHook:
        fn before_mining_start(
            caller: felt252,
            vein_id: felt252,
            target_amount: u32,
            duration: u64
        ) -> PermissionResult:
            let current_block = starknet::get_block_info().block_number;
            let slot_start = (current_block / self.slot_duration.read()) * self.slot_duration.read();

            let slot = self.time_slots.read(slot_start);
            if slot.winner != caller:
                return PermissionResult.Denied("Not slot winner");

            if current_block > slot.end_block:
                return PermissionResult.Denied("Slot expired");

            PermissionResult.Approved

    #[external(v0)]
    fn bid_on_slot(slot_start: u64, bid_amount: u64):
        # Auction logic for time-based mining slots
```

## Composable Hook Chains

Multiple hooks can be chained together for complex logic:

```python
#[starknet::contract]
mod CompoundHookContract:
    #[storage]
    struct Storage:
        hook_chain: Array<felt252>,  # Ordered list of hook contracts

    impl PermissionHookImpl of IPermissionHook:
        fn before_mining_start(
            caller: felt252,
            vein_id: felt252,
            target_amount: u32,
            duration: u64
        ) -> PermissionResult:
            let hooks = self.hook_chain.read();

            for hook_address in hooks:
                let hook = IPermissionHookDispatcher(hook_address);
                let result = hook.before_mining_start(caller, vein_id, target_amount, duration);

                match result:
                    PermissionResult.Denied(reason) => return result,
                    PermissionResult.RequiresPayment(amount, recipient) => {
                        # Accumulate all payment requirements
                        # Could handle multiple payments or combine them
                    },
                    PermissionResult.Approved => continue,
                };

            PermissionResult.Approved

# Example chain: Insurance Contract → Guild Membership → Fee Collection → Safety Certification
```

## Hook Registration & Vein Control

```python
# Anyone who discovers a vein first becomes its controller
fn discover_mining_vein(hex_coord: felt252, area_idx: u32) -> VeinDiscoveryResult:
    let vein_id = calculate_vein_id(hex_coord, area_idx);

    # Check if vein already discovered
    if mining_veins.read(vein_id).discovery_block != 0:
        return VeinDiscoveryResult.AlreadyDiscovered;

    # Generate vein with RNG
    let vein = generate_vein_from_seed(vein_id);
    mining_veins.write(vein_id, vein);

    # Discoverer becomes controller
    vein_controllers.write(vein_id, caller_address());

    emit VeinDiscovered(vein_id, caller_address(), vein);
    VeinDiscoveryResult.Success(vein_id)

# Controller can set permission hooks
#[external(v0)]
fn set_vein_permission_hook(vein_id: felt252, hook_contract: felt252):
    assert vein_controllers.read(vein_id) == caller_address(), "Not vein controller";
    vein_permission_hooks.write(vein_id, hook_contract);

# Controllers can transfer/sell vein control
#[external(v0)]
fn transfer_vein_control(vein_id: felt252, new_controller: felt252):
    assert vein_controllers.read(vein_id) == caller_address(), "Not vein controller";
    vein_controllers.write(vein_id, new_controller);
```

## Economic Models Players Can Build

This system enables unlimited business model innovation:

**🏛️ Mining Cooperatives**:

- Members pool resources and share profits proportionally
- Democratic voting on operational decisions
- Insurance pools for collapse protection

**🎯 Subscription Services**:

- Monthly fees for unlimited mining access
- Tiered membership (basic/premium/platinum)
- Family plans and bulk discounts

**📈 Investment Vehicles**:

- Players buy shares in profitable veins
- Automated dividend distribution
- Secondary markets for vein shares

**🛡️ Insurance Contracts**:

- Charge premiums to cover collapse losses
- Risk assessment based on vein stability
- Mutual insurance pools across multiple veins

**⚖️ Arbitration Services**:

- Resolve disputes between miners
- Enforce custom mining agreements
- Reputation and bonding systems

**🎰 Gambling Mechanisms**:

- Lottery systems for premium vein access
- Risk-sharing pools for dangerous veins
- Betting on vein discovery outcomes

## Dynamic Economic Emergent Gameplay

This creates a **living economy** where players build the economic infrastructure:

1. **Early Game**: Simple fee structures, basic access control
2. **Mid Game**: Complex guilds, insurance systems, specialized services
3. **Late Game**: Sophisticated financial instruments, cross-vein portfolios, economic warfare

Players become **economic architects**, designing and deploying their own business models while the core game mechanics remain stable and immutable.

The most successful players won't just be good at mining - they'll be innovative contract designers who create value for the entire ecosystem.

---

## Ore Categories & Traits

Like plants, ores have categories and traits that determine their crafting properties:

```python
enum OreCategory:
    BASE_METAL,      # Iron, copper - common, reliable
    PRECIOUS_METAL,  # Gold, silver - valuable, conductive
    RARE_EARTH,      # Lithium, cobalt - high-tech properties
    GEMSTONE,        # Diamonds, rubies - enhancement crystals
    FUEL_MINERAL,    # Coal, oil shale - energy sources
    CRYSTAL,         # Quartz, obsidian - magical properties

struct OreTraits:
    hardness: u8         # 0-100: Difficulty to extract
    purity: u8           # 0-100: Quality of refined ingots
    durability: u8       # 0-100: Tools/items last longer
    conductivity: u8     # 0-100: Energy/heat transfer
    resonance: u8        # 0-100: Magical/enhancement properties

# Example ore trait ranges by category
ore_category_tendencies = {
    OreCategory.BASE_METAL: {
        hardness: (40, 70),      # Moderate difficulty
        purity: (50, 80),        # Decent refinement
        durability: (70, 95),    # Very durable items
        conductivity: (30, 60),  # Some conductivity
        resonance: (10, 30)      # Low magical properties
    },

    OreCategory.PRECIOUS_METAL: {
        hardness: (20, 50),      # Softer, easier to work
        purity: (80, 95),        # High refinement quality
        durability: (40, 70),    # Moderate durability
        conductivity: (80, 98),  # Excellent conductivity
        resonance: (60, 85)      # Good enhancement potential
    },

    OreCategory.GEMSTONE: {
        hardness: (80, 98),      # Very hard to extract
        purity: (70, 95),        # Brilliant when refined
        durability: (90, 100),   # Extremely durable
        conductivity: (5, 25),   # Poor conductivity
        resonance: (85, 100)     # Maximum magical properties
    }
    # ... more categories
}
```

## Mine Stability & Prisoner's Dilemma

Each mining vein has **limited capacity** and **stability mechanics**:

```python
struct MiningVein:
    vein_id: felt252
    ore_type: felt252
    ore_category: OreCategory
    ore_traits: OreTraits

    # Capacity & Stability
    max_safe_miners: u32         # 2-8 adventurers can mine safely
    current_miners: u32          # How many are currently mining
    stability: u32               # 0-100, decreases with over-mining
    collapse_threshold: u32      # When stability hits this, vein collapses

    # Resource State
    total_ore_remaining: u32     # Finite resource
    extraction_rate: u32         # Ore per block per miner
    discovery_block: u64         # When vein was found

    # Danger Indicators
    last_stability_check: u64    # When stability was last calculated
    warning_issued: bool         # Has collapse warning been sent

storage mining_veins: LegacyMap<felt252, MiningVein>
storage vein_miners: LegacyMap<felt252, Array<felt252>>  # vein_id → [adventurer_ids]

fn check_vein_stability(vein_id: felt252) -> StabilityStatus:
    let mut vein = mining_veins.read(vein_id);
    let blocks_since_check = block_number() - vein.last_stability_check;

    # Calculate stability loss from over-mining
    if vein.current_miners > vein.max_safe_miners:
        let overcrowd_factor = vein.current_miners - vein.max_safe_miners;
        let stability_loss = overcrowd_factor * blocks_since_check * 2;  # Exponential danger
        vein.stability = max(0, vein.stability - stability_loss);
    } else {
        # Gradual recovery when under capacity
        let recovery = min(5, blocks_since_check);
        vein.stability = min(100, vein.stability + recovery);
    }

    vein.last_stability_check = block_number();
    mining_veins.write(vein_id, vein);

    # Return status with warnings
    if vein.stability <= vein.collapse_threshold:
        return StabilityStatus.CRITICAL_COLLAPSE_IMMINENT;
    } else if vein.stability <= vein.collapse_threshold + 20:
        return StabilityStatus.DANGEROUS_WARNING_ISSUED;
    } else if vein.current_miners > vein.max_safe_miners:
        return StabilityStatus.OVERCROWDED_UNSTABLE;
    } else {
        return StabilityStatus.STABLE_SAFE;
    }

fn attempt_vein_collapse(vein_id: felt252) -> CollapseResult:
    let vein = mining_veins.read(vein_id);
    let miners = vein_miners.read(vein_id);

    # All miners in the vein when it collapses face consequences
    let mut casualties = array![];
    let mut survivors = array![];

    for miner_id in miners:
        let survival_chance = 30 + get_adventurer_skill(miner_id, "mining").level * 5;  # 30-80% survival
        let survival_roll = hash(vein_id, miner_id, block_number()) % 100;

        if survival_roll < survival_chance:
            # Survived but lost all equipment and ore
            clear_adventurer_mining_equipment(miner_id);
            survivors.append(miner_id);
        } else {
            # Didn't make it out
            adventurer_death(miner_id, DeathCause.MINING_COLLAPSE);
            casualties.append(miner_id);
        }
    }

    # Vein is permanently destroyed
    mining_veins.write(vein_id, create_collapsed_vein(vein_id));
    vein_miners.write(vein_id, array![]);

    emit VeinCollapsed(vein_id, casualties, survivors);
    CollapseResult.Destroyed(casualties, survivors)
```

## Mining Operations & Time Locks

```python
fn start_mining_operation(
    adventurer_id: felt252,
    vein_id: felt252,
    duration_blocks: u64,
    target_ore_amount: u32
) -> MiningStartResult:

    let adventurer = adventurers.read(adventurer_id);
    assert adventurer.is_alive && adventurer.activity == ActivityState.IDLE;

    let mut vein = mining_veins.read(vein_id);
    let current_miners = vein_miners.read(vein_id);

    # Check if vein can handle another miner
    if current_miners.len() >= vein.max_safe_miners + 2:  # Allow some overcrowding
        return MiningStartResult.VeinAtCapacity;
    }

    # Calculate mining efficiency based on skill and equipment
    let mining_skill = get_adventurer_skill(adventurer_id, "mining");
    let equipment_bonus = get_mining_equipment_bonus(adventurer_id);
    let efficiency = (mining_skill.level * 10 + equipment_bonus) / 100;  # 0.1 to 2.0x efficiency

    # Estimate extraction based on ore hardness and efficiency
    let extraction_difficulty = vein.ore_traits.hardness;
    let base_extraction_rate = max(1, (100 - extraction_difficulty) / 10);  # 1-10 ore per block
    let actual_rate = (base_extraction_rate * efficiency) / 100;

    let energy_cost = calculate_mining_energy_cost(target_ore_amount, extraction_difficulty, duration_blocks);
    assert adventurer.energy >= energy_cost;

    # Commit to mining operation
    let mining_activity = MiningActivity(
        vein_id: vein_id,
        target_amount: target_ore_amount,
        start_block: block_number(),
        end_block: block_number() + duration_blocks,
        energy_committed: energy_cost,
        estimated_extraction_rate: actual_rate
    );

    # Add to vein miners list
    let mut updated_miners = current_miners;
    updated_miners.append(adventurer_id);
    vein_miners.write(vein_id, updated_miners);
    vein.current_miners += 1;
    mining_veins.write(vein_id, vein);

    # Lock adventurer into mining
    let mut updated_adventurer = adventurer;
    updated_adventurer.activity = ActivityState.MINING(mining_activity);
    updated_adventurer.energy -= energy_cost;
    adventurers.write(adventurer_id, updated_adventurer);

    # Issue stability warning if needed
    let stability_status = check_vein_stability(vein_id);
    emit MiningStarted(adventurer_id, vein_id, target_ore_amount, duration_blocks, stability_status);

    MiningStartResult.Success(mining_activity, stability_status)
```

## Ore Refinement Pipeline

### Stage 1: Raw Ore → Ingots (Smelting)

```python
fn smelt_ore_to_ingots(
    adventurer_id: felt252,
    raw_ore_type: felt252,
    ore_amount: u32,
    fuel_amount: u32,
    smelting_method: SmeltingMethod
) -> SmeltingResult:

    let adventurer = adventurers.read(adventurer_id);
    let smelting_skill = get_adventurer_skill(adventurer_id, "smelting");

    # Get ore properties
    let ore_traits = get_ore_traits(raw_ore_type);

    # Calculate smelting efficiency
    let skill_efficiency = 50 + (smelting_skill.level * 5);  # 50-100% efficiency
    let method_bonus = match smelting_method:
        SmeltingMethod.BASIC_FURNACE => 0,      # No bonus
        SmeltingMethod.BLAST_FURNACE => 15,     # +15% efficiency, requires more fuel
        SmeltingMethod.ARCANE_FORGE => 25       # +25% efficiency, requires magic fuel
    };

    let total_efficiency = min(95, skill_efficiency + method_bonus);

    # Calculate ingot yield
    let base_yield = (ore_amount * ore_traits.purity) / 100;  # Higher purity = more ingots
    let actual_yield = (base_yield * total_efficiency) / 100;

    # Calculate fuel requirements
    let fuel_needed = calculate_fuel_requirements(ore_amount, ore_traits.hardness, smelting_method);
    assert fuel_amount >= fuel_needed, "Insufficient fuel";

    # Time lock for smelting process
    let smelting_time = calculate_smelting_time(ore_amount, smelting_method);
    lock_adventurer_into_activity(adventurer_id, ActivityState.SMELTING(smelting_time));

    # Generate ingot traits (inherit and enhance ore traits)
    let ingot_traits = enhance_traits_through_smelting(ore_traits, smelting_method, total_efficiency);

    # Create ingots after time lock completes
    schedule_ingot_creation(adventurer_id, raw_ore_type, actual_yield, ingot_traits, smelting_time);

    emit SmeltingStarted(adventurer_id, raw_ore_type, ore_amount, actual_yield, smelting_time);
    SmeltingResult.Success(actual_yield, smelting_time)

enum SmeltingMethod:
    BASIC_FURNACE,    # Standard smelting, moderate efficiency
    BLAST_FURNACE,    # High heat, better efficiency, more fuel
    ARCANE_FORGE      # Magical enhancement, best efficiency, special fuel
```

### Stage 2: Ingots → Crafted Items (Smithing)

```python
fn craft_item_from_ingots(
    adventurer_id: felt252,
    ingot_type: felt252,
    ingot_amount: u32,
    item_blueprint: ItemBlueprint,
    smithing_method: SmithingMethod
) -> SmithingResult:

    let smithing_skill = get_adventurer_skill(adventurer_id, "smithing");
    let ingot_traits = get_ingot_traits(ingot_type);

    # Calculate crafting success chance
    let base_success = 60 + (smithing_skill.level * 4);
    let blueprint_complexity = item_blueprint.complexity_rating;  # 1-10
    let success_chance = max(20, base_success - (blueprint_complexity * 5));

    # Determine crafting outcome
    let craft_seed = hash(adventurer_id, ingot_type, item_blueprint.id, block_number());
    let success_roll = craft_seed % 100;

    if success_roll >= success_chance:
        return SmithingResult.Failure("Crafting failed - ingots wasted");
    }

    # Calculate item stats based on ingot traits
    let item_stats = calculate_item_stats(ingot_traits, item_blueprint, smithing_method);

    # Create finished item
    let crafted_item = CraftedEquipment(
        item_type: item_blueprint.item_type,
        base_stats: item_stats,
        ingot_source: ingot_type,
        crafted_by: adventurer_id,
        smithing_method: smithing_method,
        creation_block: block_number()
    );

    # Time lock for smithing
    let smithing_time = calculate_smithing_time(item_blueprint.complexity_rating, smithing_method);
    lock_adventurer_into_activity(adventurer_id, ActivityState.SMITHING(smithing_time));

    add_skill_experience(adventurer_id, "smithing", blueprint_complexity * 25);

    emit ItemCrafted(adventurer_id, crafted_item);
    SmithingResult.Success(crafted_item)

# Equipment types and their stat focuses
equipment_blueprints = {
    "iron_pickaxe": ItemBlueprint(
        item_type: "mining_tool",
        complexity_rating: 3,
        stat_focus: "hardness_penetration",    # Inherits ingot durability + hardness
        base_stats: { mining_efficiency: 150, durability: 1000 }
    ),

    "steel_sword": ItemBlueprint(
        item_type: "weapon",
        complexity_rating: 5,
        stat_focus: "sharpness_durability",
        base_stats: { attack_power: 200, durability: 800 }
    ),

    "gold_conductor": ItemBlueprint(
        item_type: "crafting_tool",
        complexity_rating: 4,
        stat_focus: "conductivity_resonance",  # Inherits conductivity + resonance
        base_stats: { crafting_efficiency: 120, magic_amplification: 180 }
    )
}
```

## Mining Biome Distribution

```python
biome_mining_distributions = {
    BiomeType.MOUNTAIN: {
        ore_weights: {
            OreCategory.BASE_METAL: 40,      # Iron, copper in mountain veins
            OreCategory.GEMSTONE: 30,        # Precious gems in hard rock
            OreCategory.RARE_EARTH: 20,      # Rare minerals in peaks
            OreCategory.CRYSTAL: 10          # Magical crystals at high altitudes
        },
        vein_stability_bonus: +20,           # Mountain veins are more stable
        max_safe_miners_range: (3, 6)       # Larger, more stable operations
    },

    BiomeType.DESERT: {
        ore_weights: {
            OreCategory.PRECIOUS_METAL: 50,  # Gold in desert sands
            OreCategory.CRYSTAL: 30,         # Desert crystals
            OreCategory.BASE_METAL: 20       # Some iron deposits
        },
        vein_stability_bonus: -10,           # Sandy, unstable veins
        max_safe_miners_range: (1, 3)       # Small, dangerous operations
    },

    BiomeType.SWAMP: {
        ore_weights: {
            OreCategory.FUEL_MINERAL: 60,    # Coal, peat in wetlands
            OreCategory.BASE_METAL: 25,      # Bog iron
            OreCategory.RARE_EARTH: 15       # Unique swamp minerals
        },
        vein_stability_bonus: -20,           # Very unstable, waterlogged
        max_safe_miners_range: (1, 2)       # Extremely dangerous solo operations
    }
}
```

## Social Dynamics & Strategy

### The Prisoner's Dilemma

**🤝 Cooperation**: Stay within safe limits

- **Mutual benefit**: Everyone mines safely and profits
- **Stable income**: Predictable, sustainable extraction
- **Reputation building**: Known as trustworthy mining partner

**🗡️ Defection**: Add extra miners for short-term gain

- **Individual benefit**: More ore in the short term
- **Collective risk**: Increases collapse probability for everyone
- **Retaliation risk**: Others may overcrowd in response

### Emergent Social Structures

**Mining Guilds**:

- Coordinate access to prevent overcrowding
- Pool resources for advanced smelting equipment
- Establish mining schedules and quotas
- Provide insurance against collapse losses

**Economic Warfare**:

- Sabotage rival operations by overcrowding their veins
- Corner valuable ore markets through territorial control
- Form cartels to manipulate ore prices

**Reputation Systems**:

- Track players who honor vs violate mining agreements
- Premium access to stable veins for trusted partners
- Social punishment for known "vein breakers"

### Strategic Considerations

**Risk vs Reward Calculation**:

- Mountain iron: Safe, predictable, moderate value
- Desert gold: Risky, valuable, requires coordination
- Swamp coal: Extremely dangerous, essential for smelting

**Portfolio Management**:

- Balance safe operations with high-risk/high-reward ventures
- Maintain relationships across multiple mining territories
- Diversify across different ore types and biomes

**Timing Strategy**:

- Early discovery advantage vs late entry safety
- Seasonal coordination for major mining operations
- Exit timing before vein exhaustion or instability

This system transforms mining from a solo activity into a **complex social and economic game** where cooperation, reputation, and strategic thinking determine success.
