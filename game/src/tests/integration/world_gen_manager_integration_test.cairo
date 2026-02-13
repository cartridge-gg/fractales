#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::ModelStorage;
    use dojo::world::IWorldDispatcherTrait;
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, spawn_test_world,
    };
    use dojo_starter::models::world::WorldGenConfig;
    use dojo_starter::events::world_events::WorldGenConfigInitialized;
    use dojo_starter::systems::world_gen_manager_contract::{
        IWorldGenManagerDispatcher, IWorldGenManagerDispatcherTrait,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("WorldGenConfig"),
                TestResource::Event("WorldGenConfigInitialized"),
                TestResource::Contract("world_gen_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_gen_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    #[test]
    fn world_gen_manager_integration_initializes_active_config_once() {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let (contract_address, _) = world.dns(@"world_gen_manager").unwrap();
        let manager = IWorldGenManagerDispatcher { contract_address };

        let mut spy = spy_events();
        let caller = get_default_caller_address();
        IWorldDispatcherTrait::grant_owner(
            world.dispatcher, world.namespace_hash, caller,
        );
        let owner_ok = IWorldDispatcherTrait::is_owner(world.dispatcher, world.namespace_hash, caller);
        assert(owner_ok, 'GEN_CFG_TEST_OWNER');

        let first_ok = manager.initialize_active_world_gen_config(
            'G5_INIT_SEED'_felt252, 3500_u16, 4200_u16, 6000_u16, 4_u8, 5_u8, 6_u8,
        );
        assert(first_ok, 'GEN_CFG_INIT_FIRST');

        let stored: WorldGenConfig = world.read_model(2_u16);
        assert(stored.generation_version == 2_u16, 'GEN_CFG_STORED_VERSION');
        assert(stored.global_seed == 'G5_INIT_SEED'_felt252, 'GEN_CFG_STORED_SEED');
        assert(stored.biome_scale_bp == 3500_u16, 'GEN_CFG_STORED_BIOME_SCALE');

        let second_ok = manager.initialize_active_world_gen_config(
            'DIFF_SEED'_felt252, 9000_u16, 9000_u16, 9000_u16, 8_u8, 8_u8, 8_u8,
        );
        assert(!second_ok, 'GEN_CFG_INIT_REPLAY_FALSE');

        let replayed: WorldGenConfig = world.read_model(2_u16);
        assert(replayed.global_seed == 'G5_INIT_SEED'_felt252, 'GEN_CFG_REPLAY_IMMUTABLE_SEED');

        let current = manager.get_active_world_gen_config();
        assert(current.global_seed == 'G5_INIT_SEED'_felt252, 'GEN_CFG_GET_ACTIVE');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let initialized_selector = Event::<WorldGenConfigInitialized>::selector(world.namespace_hash);
        let mut initialized_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @initialized_selector {
                initialized_count += 1;
            }
            idx += 1;
        };
        assert(initialized_count == 1_usize, 'GEN_CFG_INIT_EVENT_ONCE');
    }
}
