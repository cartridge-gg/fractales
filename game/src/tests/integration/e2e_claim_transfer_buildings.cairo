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
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::libs::construction_balance::{
        B_GREENHOUSE, B_SMELTER, B_STOREHOUSE,
    };
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::HexDecayState;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::construction::ConstructionBuildingNode;
    use dojo_starter::models::world::{Biome, Hex, derive_area_id};
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexDecayState"),
                TestResource::Model("ClaimEscrow"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Event("ClaimInitiated"),
                TestResource::Event("OwnershipTransferred"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
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
                name: 'C5CLM'_felt252,
                energy,
                max_energy: energy,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @dojo_starter::models::economics::AdventurerEconomics {
                adventurer_id,
                energy_balance: energy,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
    }

    #[test]
    fn e2e_09_claim_transfer_keeps_building_ownership_coherent() {
        let caller = get_default_caller_address();
        set_block_number(700_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let mut spy = spy_events();

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let economic = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9991_felt252;
        let claimant_id = 9992_felt252;
        let hex_coordinate = 10_391_felt252;
        setup_actor(ref world, owner_id, caller, 400_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 500_u16, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 4_u8,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate,
                owner_adventurer_id: owner_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 85_u16,
                claimable_since_block: 100_u64,
            },
        );

        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 0_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 1_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 1_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 1_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 2_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 1_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 3_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 1_u64,
                claim_block: 0_u64,
            },
        );

        world.write_model_test(
            @ConstructionBuildingNode {
                area_id: derive_area_id(hex_coordinate, 0_u8),
                hex_coordinate,
                owner_adventurer_id: owner_id,
                building_type: B_SMELTER,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );
        world.write_model_test(
            @ConstructionBuildingNode {
                area_id: derive_area_id(hex_coordinate, 1_u8),
                hex_coordinate,
                owner_adventurer_id: owner_id,
                building_type: B_GREENHOUSE,
                tier: 1_u8,
                condition_bp: 2_500_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: false,
            },
        );
        world.write_model_test(
            @ConstructionBuildingNode {
                area_id: derive_area_id(hex_coordinate, 2_u8),
                hex_coordinate,
                owner_adventurer_id: owner_id,
                building_type: B_STOREHOUSE,
                tier: 2_u8,
                condition_bp: 9_000_u16,
                upkeep_reserve: 10_u32,
                last_upkeep_block: 20_u64,
                is_active: true,
            },
        );

        let initiated = economic.initiate_hex_claim(claimant_id, hex_coordinate, 250_u16);
        assert(initiated, 'C5_CLAIM_INIT');

        let state_after: HexDecayState = world.read_model(hex_coordinate);
        assert(state_after.owner_adventurer_id == claimant_id, 'C5_CLAIM_OWNER');

        let own0: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let own1: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let own2: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        let own3: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 3_u8));
        assert(own0.owner_adventurer_id == claimant_id, 'C5_CLAIM_ROW0');
        assert(own1.owner_adventurer_id == claimant_id, 'C5_CLAIM_ROW1');
        assert(own2.owner_adventurer_id == claimant_id, 'C5_CLAIM_ROW2');
        assert(own3.owner_adventurer_id == claimant_id, 'C5_CLAIM_ROW3');

        let b0: ConstructionBuildingNode = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let b1: ConstructionBuildingNode = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let b2: ConstructionBuildingNode = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(b0.owner_adventurer_id == claimant_id, 'C5_CLAIM_B0');
        assert(b1.owner_adventurer_id == claimant_id, 'C5_CLAIM_B1');
        assert(b2.owner_adventurer_id == claimant_id, 'C5_CLAIM_B2');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let transferred_selector = Event::<OwnershipTransferred>::selector(world.namespace_hash);
        let mut transferred_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @transferred_selector {
                transferred_count += 1;
            }
            idx += 1;
        };
        assert(transferred_count == 4_usize, 'C5_CLAIM_EVT4');
    }
}
