# Discovery-Based Ownership & NFT System

## Vision: Exploration Creates Property Rights

When players discover new areas, they receive **ownership NFTs** that grant exclusive rights to:

- Set permission hooks on discovered objects
- Control access and pricing
- Transfer/sell ownership rights
- Collect revenue from object usage

**Core Principle**: **First discovery = ownership rights**, creating strong incentives for exploration and risk-taking.

## Discovery & Ownership Flow

```python
# Discovery triggers NFT minting and ownership establishment
fn discover_area(
    adventurer_id: felt252,
    hex_coord: felt252,
    area_type: felt252  # "mining_vein", "harvest_area", "ruins", etc.
) -> DiscoveryResult:

    # Generate deterministic area_id
    let area_id = hash(hex_coord, area_type, discovery_salt());

    # Check if already discovered
    let existing_owner = object_controllers.read(area_id);
    if existing_owner != 0:
        return DiscoveryResult.AlreadyDiscovered(existing_owner);

    # Validate discoverer is actually present at location
    let adventurer = adventurers.read(adventurer_id);
    assert adventurer.current_hex == hex_coord, "Not at discovery location";

    # Energy cost for discovery
    let discovery_cost = calculate_discovery_cost(area_type, hex_coord);
    assert adventurer.energy >= discovery_cost, "Insufficient energy";

    # Generate the discoverable object(s)
    let discovered_objects = generate_objects_for_area(area_id, area_type, hex_coord);

    # Mint ownership NFT
    let ownership_nft = mint_area_ownership_nft(
        adventurer_id,
        area_id,
        area_type,
        discovered_objects,
        block_number()
    );

    # Register ownership in action dispatcher
    object_controllers.write(area_id, adventurer.owner_address);

    # Initialize default permissions (no hooks = public access)
    object_hooks.write(area_id, array![]);

    emit AreaDiscovered(
        area_id,
        adventurer.owner_address,
        area_type,
        discovered_objects,
        ownership_nft.token_id
    );

    DiscoveryResult.Success(area_id, ownership_nft, discovered_objects)

# Different discovery types yield different objects
fn generate_objects_for_area(
    area_id: felt252,
    area_type: felt252,
    hex_coord: felt252
) -> Array<DiscoveredObject>:
    let seed = hash(area_id, block_number());

    match area_type:
        'mining_area' => {
            # Generate 1-3 mining veins
            let vein_count = (seed % 3) + 1;
            let mut veins = array![];

            for i in 0..vein_count:
                let vein = generate_mining_vein(hash(seed, i));
                veins.append(DiscoveredObject.MiningVein(vein));

            veins
        },
        'harvest_area' => {
            # Generate plant clusters
            let plant_areas = generate_plant_areas(seed, hex_coord);
            let mut objects = array![];

            for area in plant_areas:
                objects.append(DiscoveredObject.PlantCluster(area));

            objects
        },
        'ancient_ruins' => {
            # Special discovery - unique facilities or artifacts
            array![DiscoveredObject.AncientFacility(generate_ruin(seed))]
        },
        'resource_cache' => {
            # One-time resource extraction
            array![DiscoveredObject.ResourceCache(generate_cache(seed))]
        },
        _ => array![]
    }
```

## Area Ownership NFT Contract

```python
#[starknet::contract]
mod AreaOwnershipNFT:
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[storage]
    struct Storage:
        #[substorage(v0)]
        erc721: ERC721Component::Storage,

        # NFT-specific data
        token_area_data: LegacyMap<u256, AreaOwnershipData>,
        area_to_token: LegacyMap<felt252, u256>,  # area_id → token_id
        next_token_id: u256,

        # Revenue tracking
        area_revenue: LegacyMap<felt252, u64>,    # area_id → total_revenue
        owner_earnings: LegacyMap<felt252, u64>,  # owner → pending_earnings

    #[derive(Drop, Serde, starknet::Store)]
    struct AreaOwnershipData:
        area_id: felt252,
        area_type: felt252,
        discovery_block: u64,
        discovered_objects: Array<felt252>,      # Object IDs in this area
        discovery_hex: felt252,
        total_revenue_generated: u64,

    #[external(v0)]
    fn mint_ownership_nft(
        to: felt252,
        area_id: felt252,
        area_type: felt252,
        discovered_objects: Array<felt252>,
        discovery_block: u64
    ) -> u256:
        # Only game contracts can mint
        assert is_authorized_minter(caller_address()), "Not authorized";

        let token_id = self.next_token_id.read();
        self.next_token_id.write(token_id + 1);

        # Store area data
        self.token_area_data.write(token_id, AreaOwnershipData(
            area_id: area_id,
            area_type: area_type,
            discovery_block: discovery_block,
            discovered_objects: discovered_objects,
            discovery_hex: get_hex_from_area_id(area_id),
            total_revenue_generated: 0
        ));

        self.area_to_token.write(area_id, token_id);

        # Mint the NFT
        self.erc721.mint(to, token_id);

        token_id

    #[view]
    fn get_area_data(token_id: u256) -> AreaOwnershipData:
        self.token_area_data.read(token_id)

    #[view]
    fn get_token_for_area(area_id: felt252) -> u256:
        self.area_to_token.read(area_id)

    # Revenue sharing with NFT holders
    #[external(v0)]
    fn distribute_revenue(area_id: felt252, amount: u64):
        # Only authorized revenue distributors (hook contracts) can call
        assert is_authorized_distributor(caller_address()), "Not authorized";

        let token_id = self.area_to_token.read(area_id);
        let owner = self.erc721.owner_of(token_id);

        # Add to owner's pending earnings
        let current_earnings = self.owner_earnings.read(owner);
        self.owner_earnings.write(owner, current_earnings + amount);

        # Track total area revenue
        let current_revenue = self.area_revenue.read(area_id);
        self.area_revenue.write(area_id, current_revenue + amount);

        # Update NFT metadata
        let mut area_data = self.token_area_data.read(token_id);
        area_data.total_revenue_generated += amount;
        self.token_area_data.write(token_id, area_data);

        emit RevenueDistributed(area_id, owner, amount);

    #[external(v0)]
    fn claim_earnings():
        let caller = caller_address();
        let earnings = self.owner_earnings.read(caller);
        assert earnings > 0, "No earnings to claim";

        self.owner_earnings.write(caller, 0);

        # Transfer earnings (implementation depends on token type)
        transfer_earnings_to_owner(caller, earnings);

        emit EarningsClaimed(caller, earnings);
```

## Hook Permission System Integration

```python
# Modify ActionDispatcher to check NFT ownership for hook permissions
#[starknet::contract]
mod ActionDispatcher:
    #[storage]
    struct Storage:
        # ... existing storage ...
        area_ownership_nft: felt252,  # Address of ownership NFT contract

    #[external(v0)]
    fn set_object_hook(
        object_id: felt252,
        hook_contract: felt252
    ):
        # Verify caller owns the area NFT for this object
        assert can_set_hooks(caller_address(), object_id), "Not authorized to set hooks";

        # Validate hook contract
        assert is_valid_hook_contract(hook_contract), "Invalid hook contract";

        # Set the hook
        object_hooks.write(object_id, array![hook_contract]);

        emit HookSet(object_id, hook_contract, caller_address());

    #[external(v0)]
    fn add_hook_to_chain(
        object_id: felt252,
        hook_contract: felt252,
        position: u32  # Where in hook chain to insert
    ):
        assert can_set_hooks(caller_address(), object_id), "Not authorized";

        let mut current_hooks = object_hooks.read(object_id);
        current_hooks.insert(position, hook_contract);
        object_hooks.write(object_id, current_hooks);

    #[external(v0)]
    fn remove_hook(
        object_id: felt252,
        hook_contract: felt252
    ):
        assert can_set_hooks(caller_address(), object_id), "Not authorized";

        let mut current_hooks = object_hooks.read(object_id);
        # Remove hook from array
        let updated_hooks = remove_from_array(current_hooks, hook_contract);
        object_hooks.write(object_id, updated_hooks);

    fn can_set_hooks(caller: felt252, object_id: felt252) -> bool:
        # Check if caller owns the area NFT containing this object
        let area_id = get_area_for_object(object_id);
        let nft_contract = IAreaOwnershipNFTDispatcher(self.area_ownership_nft.read());
        let token_id = nft_contract.get_token_for_area(area_id);

        if token_id == 0:
            return false;  # No NFT exists for this area
        }

        let nft_owner = nft_contract.owner_of(token_id);
        caller == nft_owner
```

## Revenue Integration with Hooks

```python
# Hooks can automatically send revenue to area owners
#[starknet::contract]
mod RevenueGeneratingHook:
    #[storage]
    struct Storage:
        owner_share_percentage: u8,  # 0-100%
        base_access_fee: u64,
        area_ownership_nft: felt252,

    impl IUniversalHook:
        fn before_action(
            caller: felt252,
            target_id: felt252,
            action_type: felt252,
            action_params: Span<felt252>
        ) -> PermissionResult:
            let access_fee = self.base_access_fee.read();

            # Calculate owner's share
            let owner_share = (access_fee * self.owner_share_percentage.read()) / 100;

            # Send revenue to area owner via NFT contract
            let nft_contract = IAreaOwnershipNFTDispatcher(self.area_ownership_nft.read());
            let area_id = get_area_for_object(target_id);
            nft_contract.distribute_revenue(area_id, owner_share);

            PermissionResult.RequiresPayment(access_fee, contract_address())

        fn after_action(
            caller: felt252,
            target_id: felt252,
            action_type: felt252,
            action_result: ActionResult
        ) -> ():
            # Could implement usage-based revenue sharing
            if action_result.success:
                let usage_bonus = calculate_usage_bonus(action_result);
                let area_id = get_area_for_object(target_id);

                let nft_contract = IAreaOwnershipNFTDispatcher(self.area_ownership_nft.read());
                nft_contract.distribute_revenue(area_id, usage_bonus);
            }
```

## Discovery Incentive Economics

```python
# Discovery becomes increasingly valuable as areas are found
fn calculate_discovery_cost(area_type: felt252, hex_coord: felt252) -> u32:
    let base_cost = match area_type:
        'mining_area' => 100,
        'harvest_area' => 50,
        'ancient_ruins' => 200,
        'resource_cache' => 75,
        _ => 100
    };

    # Cost increases with distance from spawn
    let distance_from_spawn = calculate_distance_from_spawn(hex_coord);
    let distance_multiplier = 1 + (distance_from_spawn / 1000);  # 0.1% per hex

    # Cost increases with area density (more competition)
    let nearby_areas = count_discovered_areas_in_radius(hex_coord, 10);
    let density_multiplier = 1 + (nearby_areas / 20);  # 5% per nearby area

    base_cost * distance_multiplier * density_multiplier

# Revenue potential increases with rarity and quality
fn calculate_area_value_multiplier(area_data: AreaOwnershipData) -> u32:
    let mut multiplier = 100;  # Base 1.0x

    # Rare area types are more valuable
    match area_data.area_type:
        'ancient_ruins' => multiplier *= 5,     # 5x multiplier
        'legendary_vein' => multiplier *= 3,    # 3x multiplier
        'sacred_grove' => multiplier *= 3,      # 3x multiplier
        'mining_area' => multiplier *= 1,       # 1x multiplier
        _ => {}
    };

    # Early discoveries are more valuable
    let discovery_bonus = max(200, 300 - (area_data.discovery_block / 1000));  # 2-3x for early

    # Distance from spawn increases value
    let distance_bonus = 100 + calculate_distance_from_spawn(area_data.discovery_hex) / 100;

    (multiplier * discovery_bonus * distance_bonus) / 10000
```

## NFT Marketplace Integration

```python
# Areas can be bought/sold on secondary markets
#[external(v0)]
fn transfer_area_ownership(
    token_id: u256,
    new_owner: felt252,
    price: u64
):
    # Standard ERC721 transfer with additional logic
    let current_owner = self.erc721.owner_of(token_id);
    assert caller_address() == current_owner, "Not token owner";

    # Handle payment
    if price > 0:
        transfer_payment(new_owner, current_owner, price);
    }

    # Transfer NFT
    self.erc721.transfer_from(current_owner, new_owner, token_id);

    # Update permission system
    let area_data = self.token_area_data.read(token_id);
    update_object_controller(area_data.area_id, new_owner);

    emit AreaSold(token_id, current_owner, new_owner, price);

# Fractional ownership for expensive areas
#[starknet::contract]
mod FractionalAreaOwnership:
    # Allow multiple investors to own shares of valuable areas
    # Distribute hook setting rights and revenue proportionally
```

## Benefits of This System

**🎯 Exploration Incentives**: Discovery creates immediate, tradeable value  
**💰 Revenue Generation**: Area owners earn from all activity in their territory  
**📈 Appreciation**: Successful areas become more valuable over time  
**🏪 Marketplace**: Natural trading economy for prime locations  
**⚖️ Property Rights**: Clear ownership enables complex business models  
**🔧 Hook Control**: Only owners can set access rules and pricing

## Emergent Gameplay

**🗺️ Territory Building**: Players focus on discovering and developing regions  
**💎 Premium Locations**: Rare discoveries become highly contested assets  
**🏛️ Land Barons**: Successful explorers build empires of owned areas  
**📊 Investment**: Players buy ownership stakes in promising undeveloped areas  
**⚔️ Economic Warfare**: Competitors try to disrupt profitable territories

This creates a **living property market** where exploration skill, business acumen, and strategic thinking all contribute to success!
