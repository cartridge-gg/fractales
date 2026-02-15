#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};
    use dojo_starter::events::ownership_events::{AreaOwnershipAssigned, OwnershipTransferred};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{AdventurerEconomics, HexDecayState};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{Biome, Hex, derive_area_id};
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
    use dojo_starter::systems::world_manager_contract::{
        IWorldManagerDispatcher, IWorldManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("HexDecayState"),
                TestResource::Model("ClaimEscrow"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("WorldActionRejected"),
                TestResource::Event("ClaimInitiated"),
                TestResource::Event("OwnershipTransferred"),
                TestResource::Contract("world_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"economic_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        energy: u16,
        hex_coordinate: felt252,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'OWNE'_felt252,
                energy,
                max_energy: energy,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: energy,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
    }

    #[test]
    fn ownership_events_integration_discover_then_claim_has_exact_cardinality() {
        let caller = get_default_caller_address();
        set_block_number(700_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (world_manager_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_manager_address };
        let (economic_manager_address, _) = world.dns(@"economic_manager").unwrap();
        let economic_manager = IEconomicManagerDispatcher { contract_address: economic_manager_address };
        let mut spy = spy_events();

        let owner_id = 9701_felt252;
        let claimant_id = 9702_felt252;
        let hex_coordinate = 9800_felt252;
        setup_actor(ref world, owner_id, caller, 500_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 400_u16, hex_coordinate);
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 3_u8,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate,
                owner_adventurer_id: owner_id,
                current_energy_reserve: 20_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 90_u16,
                claimable_since_block: 100_u64,
            },
        );

        world_manager.discover_area(owner_id, hex_coordinate, 0_u8);
        world_manager.discover_area(claimant_id, hex_coordinate, 1_u8);
        world_manager.discover_area(claimant_id, hex_coordinate, 2_u8);

        let before0: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let before1: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let before2: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(before0.owner_adventurer_id == owner_id, 'OWN_EVT_BEFORE_0');
        assert(before1.owner_adventurer_id == owner_id, 'OWN_EVT_BEFORE_1');
        assert(before2.owner_adventurer_id == owner_id, 'OWN_EVT_BEFORE_2');

        let claimed = economic_manager.initiate_hex_claim(claimant_id, hex_coordinate, 250_u16);
        assert(claimed, 'OWN_EVT_CLAIM');

        let after0: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let after1: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let after2: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(after0.owner_adventurer_id == claimant_id, 'OWN_EVT_AFTER_0');
        assert(after1.owner_adventurer_id == claimant_id, 'OWN_EVT_AFTER_1');
        assert(after2.owner_adventurer_id == claimant_id, 'OWN_EVT_AFTER_2');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let assigned_selector = Event::<AreaOwnershipAssigned>::selector(world.namespace_hash);
        let transferred_selector = Event::<OwnershipTransferred>::selector(world.namespace_hash);

        let mut assigned_count: usize = 0;
        let mut transferred_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @assigned_selector {
                    assigned_count += 1;
                } else if event.keys.at(1) == @transferred_selector {
                    transferred_count += 1;
                }
            }
            idx += 1;
        };

        assert(assigned_count == 3_usize, 'OWN_EVT_ASSIGNED_CNT');
        assert(transferred_count == 3_usize, 'OWN_EVT_TRANSFER_CNT');
    }
}
