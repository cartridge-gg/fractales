#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::IWorldDispatcherTrait;
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};
    use dojo_starter::events::harvesting_events::{HarvestingCompleted, HarvestingStarted};
    use dojo_starter::events::ownership_events::AreaOwnershipAssigned;
    use dojo_starter::events::world_events::{
        AreaDiscovered, HexDiscovered, WorldGenConfigInitialized,
    };
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use dojo_starter::libs::world_gen::{
        derive_area_profile_with_config, derive_hex_profile_with_config, derive_plant_profile_with_config,
    };
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{PlantNode, derive_harvest_item_id, derive_plant_key};
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{Hex, HexArea, WorldGenConfig, derive_area_id};
    use dojo_starter::systems::harvesting_manager_contract::{
        IHarvestingManagerDispatcher, IHarvestingManagerDispatcherTrait,
    };
    use dojo_starter::systems::world_gen_manager_contract::{
        IWorldGenManagerDispatcher, IWorldGenManagerDispatcherTrait,
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
                TestResource::Model("Inventory"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("PlantNode"),
                TestResource::Model("HarvestReservation"),
                TestResource::Event("WorldGenConfigInitialized"),
                TestResource::Event("HexDiscovered"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("HarvestingStarted"),
                TestResource::Event("HarvestingCompleted"),
                TestResource::Contract("world_gen_manager"),
                TestResource::Contract("world_manager"),
                TestResource::Contract("harvesting_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_gen_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"world_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"harvesting_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn encoded_cube(coord: CubeCoord) -> felt252 {
        match encode_cube(coord) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'SMOKE_ENC_NONE');
                0
            },
        }
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        current_hex: felt252,
        energy: u16,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'SMOKE'_felt252,
                energy,
                max_energy: energy,
                current_hex,
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
        world.write_model_test(@Inventory { adventurer_id, current_weight: 0_u32, max_weight: 100_u32 });
    }

    #[test]
    fn smoke_generation_pipeline_config_driven_discovery_and_harvesting() {
        let caller = get_default_caller_address();
        set_block_number(10_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let mut spy = spy_events();

        let (world_gen_address, _) = world.dns(@"world_gen_manager").unwrap();
        let world_gen_manager = IWorldGenManagerDispatcher { contract_address: world_gen_address };
        let (world_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_address };
        let (harvest_address, _) = world.dns(@"harvesting_manager").unwrap();
        let harvesting_manager = IHarvestingManagerDispatcher { contract_address: harvest_address };

        IWorldDispatcherTrait::grant_owner(
            world.dispatcher, world.namespace_hash, caller,
        );
        let owner_ok = IWorldDispatcherTrait::is_owner(world.dispatcher, world.namespace_hash, caller);
        assert(owner_ok, 'SMOKE_OWNER');

        let initialized = world_gen_manager.initialize_active_world_gen_config(
            'SMOKE_SEED_G5'_felt252, 19000_u16, 17300_u16, 15000_u16, 8_u8, 7_u8, 6_u8,
        );
        assert(initialized, 'SMOKE_CFG_INIT');

        let config: WorldGenConfig = world_gen_manager.get_active_world_gen_config();
        assert(config.generation_version == 1_u16, 'SMOKE_CFG_VER');
        assert(config.global_seed == 'SMOKE_SEED_G5'_felt252, 'SMOKE_CFG_SEED');
        assert(config.biome_scale_bp == 19000_u16, 'SMOKE_CFG_B');
        assert(config.area_scale_bp == 17300_u16, 'SMOKE_CFG_A');
        assert(config.plant_scale_bp == 15000_u16, 'SMOKE_CFG_P');

        let adventurer_id = 9550_felt252;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_actor(ref world, adventurer_id, caller, origin, 200_u16);

        world_manager.discover_hex(adventurer_id, target);
        let expected_hex = derive_hex_profile_with_config(target, config);
        let discovered_hex: Hex = world.read_model(target);
        assert(discovered_hex.is_discovered, 'SMOKE_HEX_DISC');
        assert(discovered_hex.biome == expected_hex.biome, 'SMOKE_HEX_BIOME');
        assert(discovered_hex.area_count == expected_hex.area_count, 'SMOKE_HEX_AREAS');

        world_manager.discover_area(adventurer_id, target, 0_u8);
        world_manager.discover_area(adventurer_id, target, 1_u8);

        let area_id = derive_area_id(target, 1_u8);
        let expected_area = derive_area_profile_with_config(target, 1_u8, discovered_hex.biome, config);
        let area: HexArea = world.read_model(area_id);
        let ownership: AreaOwnership = world.read_model(area_id);
        assert(area.is_discovered, 'SMOKE_AREA_DISC');
        assert(area.area_type == expected_area.area_type, 'SMOKE_AREA_TYPE');
        assert(area.resource_quality == expected_area.resource_quality, 'SMOKE_AREA_QUAL');
        assert(area.size_category == expected_area.size_category, 'SMOKE_AREA_SIZE');
        assert(ownership.owner_adventurer_id == adventurer_id, 'SMOKE_AREA_OWNER');

        let plant_id = 2_u8;
        let inited = harvesting_manager.init_harvesting(target, area_id, plant_id);
        assert(inited, 'SMOKE_PLANT_INIT');

        let plant_key = derive_plant_key(target, area_id, plant_id);
        let plant: PlantNode = world.read_model(plant_key);
        let expected_plant = derive_plant_profile_with_config(
            target, area_id, plant_id, discovered_hex.biome, config,
        );
        assert(plant.species == expected_plant.species, 'SMOKE_PLANT_S');
        assert(plant.max_yield == expected_plant.max_yield, 'SMOKE_PLANT_Y');
        assert(plant.regrowth_rate == expected_plant.regrowth_rate, 'SMOKE_PLANT_R');
        assert(plant.genetics_hash == expected_plant.genetics_hash, 'SMOKE_PLANT_G');

        let started = harvesting_manager.start_harvesting(
            adventurer_id, target, area_id, plant_id, 2_u16,
        );
        assert(started, 'SMOKE_HARVEST_START');

        set_block_number(14_u64);
        let completed = harvesting_manager.complete_harvesting(adventurer_id, target, area_id, plant_id);
        assert(completed == 2_u16, 'SMOKE_HARVEST_DONE');

        let item_id = derive_harvest_item_id(plant_key);
        let item: BackpackItem = world.read_model((adventurer_id, item_id));
        let inventory: Inventory = world.read_model(adventurer_id);
        let actor: Adventurer = world.read_model(adventurer_id);
        assert(item.quantity == 2_u32, 'SMOKE_ITEM_Q');
        assert(inventory.current_weight == 2_u32, 'SMOKE_INV_W');
        assert(actor.energy == 157_u16, 'SMOKE_ACTOR_ENERGY');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let world_gen_selector = Event::<WorldGenConfigInitialized>::selector(world.namespace_hash);
        let hex_selector = Event::<HexDiscovered>::selector(world.namespace_hash);
        let area_selector = Event::<AreaDiscovered>::selector(world.namespace_hash);
        let owner_selector = Event::<AreaOwnershipAssigned>::selector(world.namespace_hash);
        let started_selector = Event::<HarvestingStarted>::selector(world.namespace_hash);
        let completed_selector = Event::<HarvestingCompleted>::selector(world.namespace_hash);

        let mut world_gen_count: usize = 0;
        let mut hex_count: usize = 0;
        let mut area_count: usize = 0;
        let mut owner_count: usize = 0;
        let mut started_count: usize = 0;
        let mut completed_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @world_gen_selector {
                    world_gen_count += 1;
                } else if event.keys.at(1) == @hex_selector {
                    hex_count += 1;
                } else if event.keys.at(1) == @area_selector {
                    area_count += 1;
                } else if event.keys.at(1) == @owner_selector {
                    owner_count += 1;
                } else if event.keys.at(1) == @started_selector {
                    started_count += 1;
                } else if event.keys.at(1) == @completed_selector {
                    completed_count += 1;
                }
            }
            idx += 1;
        };

        assert(world_gen_count == 1_usize, 'SMOKE_EVT_CFG');
        assert(hex_count == 1_usize, 'SMOKE_EVT_HEX');
        assert(area_count == 2_usize, 'SMOKE_EVT_AREA');
        assert(owner_count == 2_usize, 'SMOKE_EVT_OWNER');
        assert(started_count == 1_usize, 'SMOKE_EVT_START');
        assert(completed_count == 1_usize, 'SMOKE_EVT_DONE');
    }
}
