# Universal Hook-Based Permissions System

## Vision: Players as Economic Architects

Instead of hard-coding all social and economic rules, the game provides **injection points** where players can deploy custom smart contracts to control access, fees, profit-sharing, and complex business logic around any game object or action.

**Core Principle**: Game mechanics remain immutable, but **economic relationships** are completely programmable by players.

## Universal Hook Interface

```python
trait IUniversalHook:
    # Permission Control
    fn before_action(
        caller: felt252,
        target_id: felt252,    # vein_id, plant_id, facility_id, etc.
        action_type: felt252,  # "mine", "harvest", "craft", "enter", etc.
        action_params: Span<felt252>
    ) -> PermissionResult;

    fn after_action(
        caller: felt252,
        target_id: felt252,
        action_type: felt252,
        action_result: ActionResult
    ) -> ();

    # Value Flow Control
    fn before_value_transfer(
        from: felt252,
        to: felt252,
        value_type: felt252,    # gold, ore, items, energy
        amount: u64
    ) -> TransferResult;

    # Information Control
    fn before_information_access(
        caller: felt252,
        target_id: felt252,
        info_type: felt252      # vein_stability, plant_health, facility_queue
    ) -> InformationResult;

enum PermissionResult:
    Approved,
    Denied(felt252),                    # reason
    RequiresPayment(u64, felt252),     # amount, recipient
    RequiresStake(u64, felt252),       # amount, token_address
    RequiresMultiSig(Array<felt252>),  # required_signers
    Custom(felt252, Span<felt252>),    # custom_action, params

# Global registry system
storage object_controllers: LegacyMap<felt252, felt252>      # object_id → controller
storage object_hooks: LegacyMap<felt252, felt252>           # object_id → hook_contract
storage hook_chains: LegacyMap<felt252, Array<felt252>>     # object_id → [hook1, hook2, ...]
```

## Hook Integration Points Across All Systems

### 1. Mining System (Already Detailed)

- Vein access control
- Mining operation permissions
- Profit sharing and fee collection
- Risk management and insurance

### 2. Harvesting System Hooks

```python
# Harvesting areas can have custom access rules
fn harvest_plant(
    adventurer_id: felt252,
    plant_id: felt252,
    quantity: u32
) -> HarvestResult:
    let hook_address = object_hooks.read(plant_id);
    if hook_address != 0:
        let hook = IUniversalHookDispatcher(hook_address);
        let permission = hook.before_action(
            adventurer_id,
            plant_id,
            "harvest",
            array![quantity].span()
        );

        match permission:
            PermissionResult.RequiresPayment(fee, recipient) => {
                transfer_gold(adventurer_id, recipient, fee);
            },
            PermissionResult.Denied(reason) => return HarvestResult.AccessDenied(reason),
            _ => {}
        };
    }

    # Core harvesting logic...
    let harvested_items = perform_harvest(plant_id, quantity);

    # Notify hook of results
    if hook_address != 0:
        hook.after_action(adventurer_id, plant_id, "harvest",
                         ActionResult.Success(harvested_items.len()));
    }

# Example: Botanical Garden Contract
#[starknet::contract]
mod BotanicalGardenHook:
    #[storage]
    struct Storage:
        membership_nft: felt252,           # Required NFT to access
        daily_harvest_limits: LegacyMap<felt252, u32>,  # user → remaining_harvests
        rare_plant_auction_pool: u64,      # Pool for rare plant auctions
        conservation_fee_percentage: u8,   # Fee for replanting

    impl IUniversalHook:
        fn before_action(caller, plant_id, action_type, params) -> PermissionResult:
            # Check membership NFT
            if !has_membership_nft(caller):
                return PermissionResult.Denied("Membership required");

            # Check daily limits
            let remaining = self.daily_harvest_limits.read(caller);
            if remaining == 0:
                return PermissionResult.Denied("Daily limit exceeded");

            # Conservation fee for rare plants
            if is_rare_plant(plant_id):
                let fee = calculate_conservation_fee(plant_id);
                return PermissionResult.RequiresPayment(fee, get_conservation_fund());

            PermissionResult.Approved
```

### 3. City & Facility System Hooks

```python
# City plots and facilities can have sophisticated ownership models
fn use_facility(
    adventurer_id: felt252,
    facility_id: felt252,
    service_type: felt252,
    items: Array<felt252>
) -> FacilityResult:
    let hook_address = object_hooks.read(facility_id);
    if hook_address != 0:
        let permission = hook.before_action(
            adventurer_id, facility_id, service_type, items.span()
        );
        # ... handle permission results
    }

# Example: Luxury Crafting Workshop
#[starknet::contract]
mod LuxuryCraftingWorkshop:
    #[storage]
    struct Storage:
        vip_members: LegacyMap<felt252, VIPTier>,
        queue_system: Array<QueueEntry>,
        premium_slots: u32,
        revenue_sharing: LegacyMap<felt252, u32>,  # investor → percentage

    enum VIPTier:
        None,
        Silver,  # 10% discount, priority queue
        Gold,    # 20% discount, instant access
        Diamond, # 30% discount, exclusive recipes

    impl IUniversalHook:
        fn before_action(caller, facility_id, action_type, params) -> PermissionResult:
            let vip_tier = self.vip_members.read(caller);

            match vip_tier:
                VIPTier.Diamond => PermissionResult.Approved,  # Instant access
                VIPTier.Gold => {
                    if premium_slots_available():
                        PermissionResult.Approved
                    } else {
                        PermissionResult.Denied("Premium slots full")
                    }
                },
                VIPTier.Silver => {
                    # Add to priority queue
                    PermissionResult.Custom("queue_priority", array![get_queue_position()])
                },
                VIPTier.None => {
                    # Regular queue + full price
                    let base_fee = calculate_base_fee(action_type, params);
                    PermissionResult.RequiresPayment(base_fee, facility_owner())
                }
            }
```

### 4. Trade & Transportation Hooks

```python
# Trade routes and transportation can have custom toll systems
fn transport_goods(
    adventurer_id: felt252,
    from_hex: felt252,
    to_hex: felt252,
    goods: Array<felt252>
) -> TransportResult:
    # Check each hex along the route for toll hooks
    let route = calculate_route(from_hex, to_hex);
    let mut total_tolls = 0;

    for hex in route:
        let hook_address = object_hooks.read(hex);
        if hook_address != 0:
            let permission = hook.before_action(
                adventurer_id, hex, "pass_through", goods.span()
            );

            match permission:
                PermissionResult.RequiresPayment(toll, collector) => {
                    total_tolls += toll;
                },
                PermissionResult.Denied(reason) => {
                    return TransportResult.RouteBlocked(hex, reason);
                },
                _ => {}
            };
        }
    }

# Example: Trade Route Consortium
#[starknet::contract]
mod TradeRouteConsortium:
    #[storage]
    struct Storage:
        route_shareholders: LegacyMap<felt252, u32>,     # address → shares
        toll_rates: LegacyMap<felt252, u32>,            # item_type → rate_per_unit
        route_maintenance_fund: u64,
        security_escort_available: bool,
        caravan_insurance_pool: u64,

    impl IUniversalHook:
        fn before_action(caller, hex_id, action_type, params) -> PermissionResult:
            if action_type == "pass_through":
                let goods_value = calculate_goods_value(params);
                let toll = (goods_value * self.toll_rate()) / 1000;  # 0.1% toll

                # Offer optional services
                if self.security_escort_available.read():
                    let escort_fee = toll / 2;  # 50% extra for armed escort
                    return PermissionResult.Custom(
                        "escort_option",
                        array![toll, escort_fee]
                    );
                }

                PermissionResult.RequiresPayment(toll, contract_address())
            } else {
                PermissionResult.Approved
            }
```

### 5. Information & Intelligence Hooks

```python
# Control access to strategic information
fn get_vein_stability(caller: felt252, vein_id: felt252) -> StabilityInfo:
    let hook_address = object_hooks.read(vein_id);
    if hook_address != 0:
        let info_permission = hook.before_information_access(
            caller, vein_id, "stability_info"
        );

        match info_permission:
            InformationResult.Denied => return StabilityInfo.Unknown,
            InformationResult.RequiresPayment(fee, recipient) => {
                transfer_gold(caller, recipient, fee);
            },
            InformationResult.Obfuscated(accuracy) => {
                # Return partially accurate information
                return add_noise_to_stability(vein_id, accuracy);
            },
            _ => {}
        };
    }

    # Return actual stability information
    read_vein_stability(vein_id)

# Example: Intelligence Broker Network
#[starknet::contract]
mod IntelligenceBroker:
    #[storage]
    struct Storage:
        subscription_tiers: LegacyMap<felt252, SubscriptionTier>,
        information_prices: LegacyMap<felt252, u64>,  # info_type → price
        exclusive_intel: LegacyMap<felt252, Array<felt252>>,  # subscriber → exclusive_info_ids

    enum SubscriptionTier:
        None,
        Basic,      # 90% accuracy
        Premium,    # 95% accuracy
        Enterprise, # 99% accuracy + exclusive intel

    impl IUniversalHook:
        fn before_information_access(caller, target_id, info_type) -> InformationResult:
            let tier = self.subscription_tiers.read(caller);
            let price = self.information_prices.read(info_type);

            match tier:
                SubscriptionTier.Enterprise => InformationResult.FullAccess,
                SubscriptionTier.Premium => InformationResult.Obfuscated(95),
                SubscriptionTier.Basic => InformationResult.Obfuscated(90),
                SubscriptionTier.None => {
                    InformationResult.RequiresPayment(price, contract_address())
                }
            }
```

## Advanced Hook Patterns

### Multi-Signature Governance

```python
#[starknet::contract]
mod DAOGovernanceHook:
    #[storage]
    struct Storage:
        dao_members: LegacyMap<felt252, bool>,
        proposals: LegacyMap<felt252, Proposal>,
        voting_power: LegacyMap<felt252, u64>,
        execution_threshold: u64,

    impl IUniversalHook:
        fn before_action(caller, target_id, action_type, params) -> PermissionResult:
            # Major decisions require DAO vote
            if is_major_decision(action_type, params):
                let proposal_id = create_proposal(caller, target_id, action_type, params);
                return PermissionResult.RequiresMultiSig(get_dao_members());

            PermissionResult.Approved
```

### Dynamic Pricing Based on Supply/Demand

```python
#[starknet::contract]
mod DynamicPricingHook:
    #[storage]
    struct Storage:
        usage_history: LegacyMap<u64, u32>,        # block → usage_count
        base_price: u64,
        demand_multiplier: u32,                    # 100 = 1.0x
        price_update_frequency: u64,               # blocks between price updates

    impl IUniversalHook:
        fn before_action(caller, target_id, action_type, params) -> PermissionResult:
            let current_demand = calculate_current_demand();
            let dynamic_price = self.base_price.read() * current_demand / 100;

            update_usage_statistics();

            PermissionResult.RequiresPayment(dynamic_price, contract_address())
```

### Cross-Game Integration Hooks

```python
#[starknet::contract]
mod CrossGameIntegrationHook:
    #[storage]
    struct Storage:
        external_game_contracts: LegacyMap<felt252, felt252>,  # game_id → contract_address
        reputation_requirements: LegacyMap<felt252, u32>,     # action → min_reputation

    impl IUniversalHook:
        fn before_action(caller, target_id, action_type, params) -> PermissionResult:
            # Check reputation in external game
            let external_contract = self.external_game_contracts.read("loot_realms");
            let reputation = IExternalGameDispatcher(external_contract).get_reputation(caller);

            let required_rep = self.reputation_requirements.read(action_type);
            if reputation < required_rep:
                return PermissionResult.Denied("Insufficient cross-game reputation");

            PermissionResult.Approved
```

## Economic Innovation Examples

Players can create entirely new business models:

**🏦 Decentralized Banking**:

- Lending protocols backed by in-game assets
- Interest rates based on risk assessment
- Automated liquidation of defaulted loans

**⚡ Energy Trading Markets**:

- Buy/sell energy futures contracts
- Energy derivatives and options
- Cross-hex energy transportation services

**🎭 Entertainment Complexes**:

- Gambling houses with custom games
- Tournament organizers with prize pools
- Social clubs with membership benefits

**🏭 Industrial Cartels**:

- Price-fixing agreements between facility owners
- Production quotas and market allocation
- Anti-competitive practices and corporate espionage

**🛡️ Protection Rackets**:

- "Insurance" for safe passage through dangerous areas
- Mercenary services for hire
- Conflict resolution and arbitration

## System Evolution

As the game evolves, the hook system allows for unlimited expansion:

1. **Phase 1**: Basic fee collection and access control
2. **Phase 2**: Complex financial instruments and derivatives
3. **Phase 3**: Cross-chain integration and external data oracles
4. **Phase 4**: AI-powered autonomous economic agents
5. **Phase 5**: Full economic simulation with emergent macroeconomics

The game becomes a **living laboratory** for economic experimentation, where the most innovative business models and governance structures emerge organically from player creativity.

Players don't just play the game - they **program the economy**.
