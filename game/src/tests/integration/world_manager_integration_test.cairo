#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::world;
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, spawn_test_world,
    };
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use dojo_starter::events::world_events::WorldActionRejected;
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use dojo_starter::libs::world_gen::{derive_area_profile, derive_hex_profile};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{Hex, HexArea, derive_area_id};
    use dojo_starter::systems::world_manager_contract::{
        IWorldManagerDispatcher, IWorldManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("HexDecayState"),
                TestResource::Event("HexDiscovered"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("AdventurerMoved"),
                TestResource::Event("WorldActionRejected"),
                TestResource::Contract("world_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn encoded_cube(coord: CubeCoord) -> felt252 {
        match encode_cube(coord) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'ENCODE_NONE');
                0
            },
        }
    }

    fn setup_adventurer(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        current_hex: felt252,
        energy: u16,
    ) {
        let adventurer = Adventurer {
            adventurer_id,
            owner,
            name: 'TESTER'_felt252,
            energy,
            max_energy: 100_u16,
            current_hex,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        world.write_model_test(@adventurer);
    }

    #[test]
    fn world_manager_integration_move_spends_energy_and_updates_position() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7001;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };
        system.move_adventurer(adventurer_id, target);

        let updated: Adventurer = world.read_model(adventurer_id);
        assert(updated.current_hex == target, 'INT_MOVE_HEX');
        assert(updated.energy == 85_u16, 'INT_MOVE_ENERGY');
    }

    #[test]
    fn world_manager_integration_discover_paths_are_stateful_and_idempotent() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7002;
        let second_adventurer_id: felt252 = 7003;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);
        setup_adventurer(ref world, second_adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };

        let expected_hex = derive_hex_profile(target);
        system.discover_hex(adventurer_id, target);
        let first_hex: Hex = world.read_model(target);
        let first_actor: Adventurer = world.read_model(adventurer_id);

        assert(first_hex.is_discovered, 'INT_DISCOVER_HEX_DISC');
        assert(first_hex.discoverer == caller, 'INT_DISCOVER_HEX_OWNER');
        assert(first_hex.area_count == expected_hex.area_count, 'INT_DISCOVER_HEX_AREAS');
        assert(first_hex.biome == expected_hex.biome, 'INT_DISCOVER_HEX_BIOME');
        assert(first_actor.energy == 75_u16, 'INT_DISCOVER_HEX_ENERGY');

        system.discover_hex(adventurer_id, target);
        let replay_hex: Hex = world.read_model(target);
        let replay_actor: Adventurer = world.read_model(adventurer_id);

        assert(replay_hex.biome == expected_hex.biome, 'INT_REPLAY_HEX_BIOME');
        assert(replay_hex.area_count == expected_hex.area_count, 'INT_REPLAY_HEX_AREAS');
        assert(replay_actor.energy == 75_u16, 'INT_REPLAY_HEX_ENERGY');

        system.move_adventurer(adventurer_id, target);
        system.move_adventurer(second_adventurer_id, target);

        let expected_control = derive_area_profile(target, 0_u8, replay_hex.biome);
        system.discover_area(adventurer_id, target, 0_u8);
        let control_area_id = derive_area_id(target, 0_u8);
        let control_area: HexArea = world.read_model(control_area_id);
        let control_ownership: AreaOwnership = world.read_model(control_area_id);
        assert(control_area.is_discovered, 'INT_CTRL_DISC');
        assert(control_area.area_type == expected_control.area_type, 'INT_CTRL_TYPE');
        assert(control_area.resource_quality == expected_control.resource_quality, 'INT_CTRL_QUALITY');
        assert(control_area.size_category == expected_control.size_category, 'INT_CTRL_SIZE');
        assert(control_area.plant_slot_count == expected_control.plant_slot_count, 'INT_CTRL_SLOTS');
        assert(control_ownership.owner_adventurer_id == adventurer_id, 'INT_CTRL_OWNER');
        assert(control_ownership.discoverer_adventurer_id == adventurer_id, 'INT_CTRL_DISCOVERER');

        let expected_area = derive_area_profile(target, 1_u8, replay_hex.biome);
        system.discover_area(second_adventurer_id, target, 1_u8);
        let area_id = derive_area_id(target, 1_u8);
        let area: HexArea = world.read_model(area_id);
        let ownership: AreaOwnership = world.read_model(area_id);
        assert(area.is_discovered, 'INT_AREA_DISC');
        assert(area.discoverer == caller, 'INT_AREA_OWNER');
        assert(area.area_type == expected_area.area_type, 'INT_AREA_TYPE');
        assert(area.resource_quality == expected_area.resource_quality, 'INT_AREA_QUALITY');
        assert(area.size_category == expected_area.size_category, 'INT_AREA_SIZE');
        assert(area.plant_slot_count == expected_area.plant_slot_count, 'INT_AREA_SLOTS');
        assert(ownership.owner_adventurer_id == adventurer_id, 'INT_AREA_CTRL_OWNER');
        assert(ownership.discoverer_adventurer_id == second_adventurer_id, 'INT_AREA_DISC_ADV');

        system.discover_area(adventurer_id, target, 1_u8);
        let replay_area: HexArea = world.read_model(area_id);
        assert(replay_area.area_type == expected_area.area_type, 'INT_AREA_REPLAY_TYPE');
        assert(replay_area.resource_quality == expected_area.resource_quality, 'INT_AREA_REPLAY_QUALITY');
        assert(replay_area.size_category == expected_area.size_category, 'INT_AREA_REPLAY_SIZE');
        assert(replay_area.plant_slot_count == expected_area.plant_slot_count, 'INT_AREA_REPLAY_SLOTS');
    }

    #[test]
    fn world_manager_integration_emits_rejection_event_on_invalid_move() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7004;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let non_adjacent = encoded_cube(CubeCoord { x: 2, y: -2, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };
        let mut spy = spy_events();
        system.move_adventurer(adventurer_id, non_adjacent);

        let unchanged: Adventurer = world.read_model(adventurer_id);
        assert(unchanged.current_hex == origin, 'INT_REJECT_HEX');
        assert(unchanged.energy == 100_u16, 'INT_REJECT_ENERGY');

        spy.assert_emitted(
            @array![
                (
                    world.dispatcher.contract_address,
                    world::Event::EventEmitted(
                        world::EventEmitted {
                            selector: Event::<WorldActionRejected>::selector(world.namespace_hash),
                            system_address: contract_address,
                            keys: [adventurer_id].span(),
                            values: ['MOVE'_felt252, non_adjacent, 'NOT_ADJ'_felt252].span(),
                        },
                    ),
                ),
            ],
        );
    }

    #[test]
    fn world_manager_integration_discover_current_hex_after_move_rejects_not_adjacent() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7005;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };
        system.discover_hex(adventurer_id, target);
        system.move_adventurer(adventurer_id, target);

        let mut spy = spy_events();
        system.discover_hex(adventurer_id, target);

        let unchanged: Adventurer = world.read_model(adventurer_id);
        assert(unchanged.current_hex == target, 'INT_DISC_CURR_HEX');
        assert(unchanged.energy == 60_u16, 'INT_DISC_CURR_ENERGY');

        spy.assert_emitted(
            @array![
                (
                    world.dispatcher.contract_address,
                    world::Event::EventEmitted(
                        world::EventEmitted {
                            selector: Event::<WorldActionRejected>::selector(world.namespace_hash),
                            system_address: contract_address,
                            keys: [adventurer_id].span(),
                            values: ['DISC_HEX'_felt252, target, 'NOT_ADJ'_felt252].span(),
                        },
                    ),
                ),
            ],
        );
    }

    #[test]
    fn world_manager_integration_outward_discovery_after_move_targets_next_adjacent_hex() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7006;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let first = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        let second = encoded_cube(CubeCoord { x: 2, y: -2, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };

        system.discover_hex(adventurer_id, first);
        system.move_adventurer(adventurer_id, first);
        system.discover_hex(adventurer_id, second);

        let first_hex: Hex = world.read_model(first);
        let second_hex: Hex = world.read_model(second);
        let actor: Adventurer = world.read_model(adventurer_id);
        let expected_second = derive_hex_profile(second);

        assert(first_hex.is_discovered, 'INT_OUTWARD_FIRST');
        assert(second_hex.is_discovered, 'INT_OUTWARD_SECOND');
        assert(second_hex.biome == expected_second.biome, 'INT_OUTWARD_BIOME');
        assert(second_hex.area_count == expected_second.area_count, 'INT_OUTWARD_AREAS');
        assert(actor.current_hex == first, 'INT_OUTWARD_POS');
        assert(actor.energy == 35_u16, 'INT_OUTWARD_ENERGY');
    }

    #[test]
    fn world_manager_integration_discover_area_requires_actor_on_target_hex() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let adventurer_id: felt252 = 7007;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_adventurer(ref world, adventurer_id, caller, origin, 100_u16);

        let (contract_address, _) = world.dns(@"world_manager").unwrap();
        let system = IWorldManagerDispatcher { contract_address };

        system.discover_hex(adventurer_id, target);
        system.discover_area(adventurer_id, target, 0_u8);

        let control_area_id = derive_area_id(target, 0_u8);
        let control_area: HexArea = world.read_model(control_area_id);
        let control_ownership: AreaOwnership = world.read_model(control_area_id);

        assert(!control_area.is_discovered, 'INT_DISC_AREA_REQUIRES_ON_HEX');
        assert(control_ownership.owner_adventurer_id == 0_felt252, 'INT_DISC_AREA_NO_OWNER');
    }
}
