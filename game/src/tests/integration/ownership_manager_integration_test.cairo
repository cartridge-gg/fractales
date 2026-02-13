#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::world;
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::systems::ownership_manager_contract::{
        IOwnershipManagerDispatcher, IOwnershipManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AreaOwnership"),
                TestResource::Event("OwnershipTransferred"),
                TestResource::Contract("ownership_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"ownership_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_adventurer(
        ref world: dojo::world::WorldStorage, adventurer_id: felt252, owner: starknet::ContractAddress,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'OWNI'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: 0_felt252,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
    }

    #[test]
    fn ownership_manager_integration_get_owner_and_transfer() {
        let caller = get_default_caller_address();
        set_block_number(150_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"ownership_manager").unwrap();
        let manager = IOwnershipManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let area_id = 9901_felt252;
        setup_adventurer(ref world, 9401_felt252, caller);
        setup_adventurer(ref world, 9402_felt252, caller);
        world.write_model_test(
            @AreaOwnership {
                area_id,
                owner_adventurer_id: 9401_felt252,
                discoverer_adventurer_id: 9300_felt252,
                discovery_block: 10_u64,
                claim_block: 0_u64,
            },
        );

        let before = manager.get_owner(area_id);
        assert(before == 9401_felt252, 'OWN_INT_GET0');

        let transferred = manager.transfer_ownership(area_id, 9402_felt252);
        assert(transferred, 'OWN_INT_TR');

        let after = manager.get_owner(area_id);
        let row: AreaOwnership = world.read_model(area_id);
        assert(after == 9402_felt252, 'OWN_INT_GET1');
        assert(row.owner_adventurer_id == 9402_felt252, 'OWN_INT_ROW_OWNER');
        assert(row.claim_block == 150_u64, 'OWN_INT_ROW_BLOCK');

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<OwnershipTransferred>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [area_id].span(),
                                values: [9401_felt252, 9402_felt252, 150_u64.into()].span(),
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn ownership_manager_integration_transfer_rejects_same_owner() {
        let caller = get_default_caller_address();
        set_block_number(151_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"ownership_manager").unwrap();
        let manager = IOwnershipManagerDispatcher { contract_address };

        let area_id = 9902_felt252;
        setup_adventurer(ref world, 9501_felt252, caller);
        world.write_model_test(
            @AreaOwnership {
                area_id,
                owner_adventurer_id: 9501_felt252,
                discoverer_adventurer_id: 9501_felt252,
                discovery_block: 20_u64,
                claim_block: 0_u64,
            },
        );

        let rejected = manager.transfer_ownership(area_id, 9501_felt252);
        assert(!rejected, 'OWN_INT_REJECT_SAME');

        let row: AreaOwnership = world.read_model(area_id);
        assert(row.owner_adventurer_id == 9501_felt252, 'OWN_INT_KEEP_OWNER');
        assert(row.claim_block == 0_u64, 'OWN_INT_KEEP_BLOCK');
    }

    #[test]
    fn ownership_manager_integration_transfer_rejects_dead_target() {
        let caller = get_default_caller_address();
        set_block_number(152_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"ownership_manager").unwrap();
        let manager = IOwnershipManagerDispatcher { contract_address };

        let area_id = 9903_felt252;
        setup_adventurer(ref world, 9601_felt252, caller);
        world.write_model_test(
            @Adventurer {
                adventurer_id: 9602_felt252,
                owner: caller,
                name: 'DEAD'_felt252,
                energy: 0_u16,
                max_energy: 100_u16,
                current_hex: 0_felt252,
                activity_locked_until: 0_u64,
                is_alive: false,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id,
                owner_adventurer_id: 9601_felt252,
                discoverer_adventurer_id: 9601_felt252,
                discovery_block: 20_u64,
                claim_block: 0_u64,
            },
        );

        let transferred = manager.transfer_ownership(area_id, 9602_felt252);
        assert(!transferred, 'OWN_INT_REJECT_DEAD_TARGET');

        let row: AreaOwnership = world.read_model(area_id);
        assert(row.owner_adventurer_id == 9601_felt252, 'OWN_INT_DEAD_TARGET_KEEP');
        assert(row.claim_block == 0_u64, 'OWN_INT_DEAD_TARGET_BLOCK');
    }
}
