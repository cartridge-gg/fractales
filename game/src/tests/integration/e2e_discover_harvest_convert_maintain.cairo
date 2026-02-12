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
    use dojo_starter::events::economic_events::{HexEnergyPaid, ItemsConverted};
    use dojo_starter::events::harvesting_events::{HarvestingCompleted, HarvestingStarted};
    use dojo_starter::events::ownership_events::AreaOwnershipAssigned;
    use dojo_starter::events::world_events::{AreaDiscovered, HexDiscovered};
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{AdventurerEconomics, HexDecayState};
    use dojo_starter::models::harvesting::{PlantNode, derive_harvest_item_id, derive_plant_key};
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::world::{Biome, Hex, derive_area_id};
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
    use dojo_starter::systems::harvesting_manager_contract::{
        IHarvestingManagerDispatcher, IHarvestingManagerDispatcherTrait,
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
                TestResource::Model("HexDecayState"),
                TestResource::Model("PlantNode"),
                TestResource::Model("HarvestReservation"),
                TestResource::Model("ConversionRate"),
                TestResource::Event("HexDiscovered"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("HarvestingStarted"),
                TestResource::Event("HarvestingCompleted"),
                TestResource::Event("ItemsConverted"),
                TestResource::Event("HexEnergyPaid"),
                TestResource::Contract("world_manager"),
                TestResource::Contract("harvesting_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"harvesting_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"economic_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn encoded_cube(coord: CubeCoord) -> felt252 {
        match encode_cube(coord) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'S6_E2E1_ENC');
                0
            },
        }
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        energy: u16,
        current_hex: felt252,
        max_weight: u32,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'S6A'_felt252,
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
        world.write_model_test(@Inventory { adventurer_id, current_weight: 0_u32, max_weight });
    }

    fn setup_hex(ref world: dojo::world::WorldStorage, hex_coordinate: felt252, owner: starknet::ContractAddress) {
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Unknown,
                is_discovered: false,
                discovery_block: 0_u64,
                discoverer: owner,
                area_count: 0_u8,
            },
        );
    }

    #[test]
    fn e2e_01_discover_harvest_convert_maintain() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let mut spy = spy_events();

        let (world_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_address };
        let (harvest_address, _) = world.dns(@"harvesting_manager").unwrap();
        let harvesting_manager = IHarvestingManagerDispatcher { contract_address: harvest_address };
        let (economic_address, _) = world.dns(@"economic_manager").unwrap();
        let economic_manager = IEconomicManagerDispatcher { contract_address: economic_address };

        let adventurer_id = 9801_felt252;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_actor(ref world, adventurer_id, caller, 200_u16, origin, 100_u32);
        setup_hex(ref world, target, caller);
        world.write_model_test(
            @HexDecayState {
                hex_coordinate: target,
                owner_adventurer_id: adventurer_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 85_u16,
                claimable_since_block: 0_u64,
            },
        );

        world_manager.discover_hex(adventurer_id, target);
        let area_id = derive_area_id(target, 0_u8);
        world_manager.discover_area(adventurer_id, target, 0_u8);

        let inited = harvesting_manager.init_harvesting(target, area_id, 1_u8);
        assert(inited, 'S6_E2E1_INIT');

        let started = harvesting_manager.start_harvesting(adventurer_id, target, area_id, 1_u8, 3_u16);
        assert(started, 'S6_E2E1_START');

        set_block_number(6_u64);
        let completed = harvesting_manager.complete_harvesting(adventurer_id, target, area_id, 1_u8);
        assert(completed == 3_u16, 'S6_E2E1_COMPLETE');

        let plant_key = derive_plant_key(target, area_id, 1_u8);
        let item_id = derive_harvest_item_id(plant_key);
        let gained = economic_manager.convert_items_to_energy(adventurer_id, item_id, 3_u16);
        assert(gained == 30_u16, 'S6_E2E1_CONVERT');

        let paid = economic_manager.pay_hex_maintenance(adventurer_id, target, 25_u16);
        assert(paid, 'S6_E2E1_PAY');

        let actor: Adventurer = world.read_model(adventurer_id);
        let inv: Inventory = world.read_model(adventurer_id);
        let item: BackpackItem = world.read_model((adventurer_id, item_id));
        let state: HexDecayState = world.read_model(target);
        assert(actor.energy == 151_u16, 'S6_E2E1_ENERGY');
        assert(inv.current_weight == 0_u32, 'S6_E2E1_INV');
        assert(item.quantity == 0_u32, 'S6_E2E1_ITEM0');
        assert(state.current_energy_reserve == 25_u32, 'S6_E2E1_RESV');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let discovered_selector = Event::<HexDiscovered>::selector(world.namespace_hash);
        let area_selector = Event::<AreaDiscovered>::selector(world.namespace_hash);
        let owner_assign_selector = Event::<AreaOwnershipAssigned>::selector(world.namespace_hash);
        let harvest_start_selector = Event::<HarvestingStarted>::selector(world.namespace_hash);
        let harvest_complete_selector = Event::<HarvestingCompleted>::selector(world.namespace_hash);
        let converted_selector = Event::<ItemsConverted>::selector(world.namespace_hash);
        let paid_selector = Event::<HexEnergyPaid>::selector(world.namespace_hash);

        let mut discovered_count: usize = 0;
        let mut area_count: usize = 0;
        let mut assign_count: usize = 0;
        let mut start_count: usize = 0;
        let mut complete_count: usize = 0;
        let mut converted_count: usize = 0;
        let mut paid_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @discovered_selector {
                    discovered_count += 1;
                } else if event.keys.at(1) == @area_selector {
                    area_count += 1;
                } else if event.keys.at(1) == @owner_assign_selector {
                    assign_count += 1;
                } else if event.keys.at(1) == @harvest_start_selector {
                    start_count += 1;
                } else if event.keys.at(1) == @harvest_complete_selector {
                    complete_count += 1;
                } else if event.keys.at(1) == @converted_selector {
                    converted_count += 1;
                } else if event.keys.at(1) == @paid_selector {
                    paid_count += 1;
                }
            }
            idx += 1;
        };

        assert(discovered_count == 1_usize, 'S6_E2E1_EVT_HEX');
        assert(area_count == 1_usize, 'S6_E2E1_EVT_AREA');
        assert(assign_count == 1_usize, 'S6_E2E1_EVT_ASSIGN');
        assert(start_count == 1_usize, 'S6_E2E1_EVT_START');
        assert(complete_count == 1_usize, 'S6_E2E1_EVT_DONE');
        assert(converted_count == 1_usize, 'S6_E2E1_EVT_CONV');
        assert(paid_count == 1_usize, 'S6_E2E1_EVT_PAY');
    }

    #[test]
    fn e2e_03_backpack_capacity_caps_harvest_mint() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (world_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_address };
        let (harvest_address, _) = world.dns(@"harvesting_manager").unwrap();
        let harvesting_manager = IHarvestingManagerDispatcher { contract_address: harvest_address };

        let adventurer_id = 9802_felt252;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_actor(ref world, adventurer_id, caller, 200_u16, origin, 2_u32);
        setup_hex(ref world, target, caller);

        world_manager.discover_hex(adventurer_id, target);
        let area_id = derive_area_id(target, 0_u8);
        world_manager.discover_area(adventurer_id, target, 0_u8);

        let inited = harvesting_manager.init_harvesting(target, area_id, 1_u8);
        assert(inited, 'S6_E2E3_INIT');
        let started = harvesting_manager.start_harvesting(adventurer_id, target, area_id, 1_u8, 5_u16);
        assert(started, 'S6_E2E3_START');
        set_block_number(10_u64);
        let completed = harvesting_manager.complete_harvesting(adventurer_id, target, area_id, 1_u8);
        assert(completed == 5_u16, 'S6_E2E3_YIELD');

        let plant_key = derive_plant_key(target, area_id, 1_u8);
        let plant: PlantNode = world.read_model(plant_key);
        let item_id = derive_harvest_item_id(plant_key);
        let item: BackpackItem = world.read_model((adventurer_id, item_id));
        let inv: Inventory = world.read_model(adventurer_id);
        assert(plant.current_yield == plant.max_yield - 5_u16, 'S6_E2E3_PLANT');
        assert(inv.current_weight == 2_u32, 'S6_E2E3_CAP');
        assert(item.quantity == 2_u32, 'S6_E2E3_MINT');
    }
}
