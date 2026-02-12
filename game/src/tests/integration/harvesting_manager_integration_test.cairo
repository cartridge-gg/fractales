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
    use snforge_std::{
        EventSpyAssertionsTrait, EventSpyTrait, EventsFilterTrait, spy_events,
    };
    use dojo_starter::events::harvesting_events::{
        HarvestingCancelled, HarvestingCompleted, HarvestingRejected, HarvestingStarted,
    };
    use dojo_starter::libs::world_gen::derive_plant_profile;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{
        HarvestReservation, HarvestReservationStatus, PlantNode, derive_harvest_reservation_id,
        derive_plant_key,
    };
    use dojo_starter::models::inventory::Inventory;
    use dojo_starter::models::world::{Biome, Hex};
    use dojo_starter::systems::harvesting_manager_contract::{
        IHarvestingManagerDispatcher, IHarvestingManagerDispatcherTrait,
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
                TestResource::Model("PlantNode"),
                TestResource::Model("HarvestReservation"),
                TestResource::Event("HarvestingStarted"),
                TestResource::Event("HarvestingCompleted"),
                TestResource::Event("HarvestingCancelled"),
                TestResource::Event("HarvestingRejected"),
                TestResource::Contract("harvesting_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"harvesting_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_actor_and_hex(
        ref world: dojo::world::WorldStorage, adventurer_id: felt252, owner: starknet::ContractAddress,
        hex_coordinate: felt252,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'HARV'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: 100_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
        world.write_model_test(@Inventory { adventurer_id, current_weight: 0_u32, max_weight: 100_u32 });
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: owner,
                area_count: 6_u8,
            },
        );
    }

    #[test]
    fn harvesting_manager_integration_init_start_complete_cancel() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"harvesting_manager").unwrap();
        let manager = IHarvestingManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let adventurer_id = 8800_felt252;
        let hex_coordinate = 900_felt252;
        let area_id = 901_felt252;
        let plant_id = 1_u8;
        let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
        setup_actor_and_hex(ref world, adventurer_id, caller, hex_coordinate);

        let inited = manager.init_harvesting(hex_coordinate, area_id, plant_id);
        assert(inited, 'H_INT_INIT');
        let expected_profile = derive_plant_profile(hex_coordinate, area_id, plant_id, Biome::Forest);
        let inited_plant: PlantNode = world.read_model(plant_key);
        assert(inited_plant.species == expected_profile.species, 'H_INT_INIT_SPECIES');
        assert(inited_plant.max_yield == expected_profile.max_yield, 'H_INT_INIT_MAX');
        assert(inited_plant.regrowth_rate == expected_profile.regrowth_rate, 'H_INT_INIT_REGROW');
        assert(inited_plant.genetics_hash == expected_profile.genetics_hash, 'H_INT_INIT_GENE');

        let started = manager.start_harvesting(adventurer_id, hex_coordinate, area_id, plant_id, 3_u16);
        assert(started, 'H_INT_START');
        let after_start: PlantNode = world.read_model(plant_key);
        let actor_after_start: Adventurer = world.read_model(adventurer_id);
        assert(after_start.reserved_yield == 3_u16, 'H_INT_START_RESV');
        assert(actor_after_start.energy == 70_u16, 'H_INT_START_ENE');
        assert(actor_after_start.activity_locked_until == 106_u64, 'H_INT_START_LOCK');

        set_block_number(106_u64);
        let completed_yield = manager.complete_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(completed_yield == 3_u16, 'H_INT_COMPLETE_YIELD');
        let after_complete: PlantNode = world.read_model(plant_key);
        let inv_after_complete: Inventory = world.read_model(adventurer_id);
        let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
        let res_after_complete: HarvestReservation = world.read_model(reservation_id);
        assert(after_complete.current_yield == expected_profile.max_yield - 3_u16, 'H_INT_COMPLETE_CURR');
        assert(after_complete.reserved_yield == 0_u16, 'H_INT_COMPLETE_RESV');
        assert(inv_after_complete.current_weight == 3_u32, 'H_INT_COMPLETE_INV');
        assert(res_after_complete.status == HarvestReservationStatus::Completed, 'H_INT_COMPLETE_ST');

        set_block_number(250_u64);
        let restarted = manager.start_harvesting(adventurer_id, hex_coordinate, area_id, plant_id, 10_u16);
        assert(restarted, 'H_INT_RESTART');
        set_block_number(260_u64);
        let partial = manager.cancel_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(partial == 5_u16, 'H_INT_CANCEL_PART');
        let after_cancel: PlantNode = world.read_model(plant_key);
        let inv_after_cancel: Inventory = world.read_model(adventurer_id);
        let res_after_cancel: HarvestReservation = world.read_model(reservation_id);
        assert(after_cancel.reserved_yield == 0_u16, 'H_INT_CANCEL_RESV');
        assert(after_cancel.current_yield == expected_profile.max_yield - 8_u16, 'H_INT_CANCEL_CURR');
        assert(inv_after_cancel.current_weight == 8_u32, 'H_INT_CANCEL_INV');
        assert(res_after_cancel.status == HarvestReservationStatus::Canceled, 'H_INT_CANCEL_ST');

        let plant_id_felt: felt252 = plant_id.into();
        let start_eta: felt252 = 106_u64.into();
        let restart_eta: felt252 = 270_u64.into();
        let start_amount: felt252 = 3_u16.into();
        let restart_amount: felt252 = 10_u16.into();
        let completed_yield_felt: felt252 = 3_u16.into();
        let canceled_partial_felt: felt252 = 5_u16.into();

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HarvestingStarted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [adventurer_id].span(),
                                values: [
                                    hex_coordinate, area_id, plant_id_felt, start_amount, start_eta,
                                ]
                                    .span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HarvestingCompleted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [adventurer_id].span(),
                                values: [
                                    hex_coordinate, area_id, plant_id_felt, completed_yield_felt,
                                ]
                                    .span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HarvestingStarted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [adventurer_id].span(),
                                values: [
                                    hex_coordinate, area_id, plant_id_felt, restart_amount,
                                    restart_eta,
                                ]
                                    .span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HarvestingCancelled>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [adventurer_id].span(),
                                values: [canceled_partial_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let started_selector = Event::<HarvestingStarted>::selector(world.namespace_hash);
        let completed_selector = Event::<HarvestingCompleted>::selector(world.namespace_hash);
        let cancelled_selector = Event::<HarvestingCancelled>::selector(world.namespace_hash);

        let mut started_count: usize = 0;
        let mut completed_count: usize = 0;
        let mut cancelled_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @started_selector {
                    started_count += 1;
                } else if event.keys.at(1) == @completed_selector {
                    completed_count += 1;
                } else if event.keys.at(1) == @cancelled_selector {
                    cancelled_count += 1;
                }
            }
            idx += 1;
        };

        assert(started_count == 2_usize, 'H_INT_EVT_START_CNT');
        assert(completed_count == 1_usize, 'H_INT_EVT_COMPLETE_CNT');
        assert(cancelled_count == 1_usize, 'H_INT_EVT_CANCEL_CNT');
    }

    #[test]
    fn harvesting_manager_integration_failure_paths_and_inspect() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"harvesting_manager").unwrap();
        let manager = IHarvestingManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let adventurer_id = 8810_felt252;
        let hex_coordinate = 910_felt252;
        let area_id = 911_felt252;
        let plant_id = 2_u8;
        setup_actor_and_hex(ref world, adventurer_id, caller, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: false,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 6_u8,
            },
        );
        let init_blocked = manager.init_harvesting(hex_coordinate, area_id, plant_id);
        assert(!init_blocked, 'H_INT_INIT_BLOCK');

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 6_u8,
            },
        );
        let init_ok = manager.init_harvesting(hex_coordinate, area_id, plant_id);
        assert(init_ok, 'H_INT_INIT_OK2');

        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'LOWE'_felt252,
                energy: 5_u16,
                max_energy: 100_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: 5_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );

        let start_insufficient = manager.start_harvesting(
            adventurer_id, hex_coordinate, area_id, plant_id, 1_u16,
        );
        assert(!start_insufficient, 'H_INT_START_INSUFF');
        let start_invalid_amount = manager.start_harvesting(
            adventurer_id, hex_coordinate, area_id, plant_id, 0_u16,
        );
        assert(!start_invalid_amount, 'H_INT_START_ZERO');

        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'FULL'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: 100_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );

        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'AWAY'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: 9999_felt252,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        let start_wrong_hex = manager.start_harvesting(
            adventurer_id, hex_coordinate, area_id, plant_id, 2_u16,
        );
        assert(!start_wrong_hex, 'H_INT_START_WRONG_HEX');
        spy.assert_emitted(
            @array![
                (
                    world.dispatcher.contract_address,
                    world::Event::EventEmitted(
                        world::EventEmitted {
                            selector: Event::<HarvestingRejected>::selector(world.namespace_hash),
                            system_address: contract_address,
                            keys: [adventurer_id].span(),
                            values: [
                                hex_coordinate,
                                area_id,
                                plant_id.into(),
                                'START'_felt252,
                                'WRONG_HEX'_felt252,
                            ]
                                .span(),
                        },
                    ),
                ),
            ],
        );

        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'FULL'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        let started = manager.start_harvesting(adventurer_id, hex_coordinate, area_id, plant_id, 2_u16);
        assert(started, 'H_INT_START_OK2');
        let too_early = manager.complete_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(too_early == 0_u16, 'H_INT_COMPLETE_EARLY_0');

        set_block_number(4_u64);
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'AWAY'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: 9999_felt252,
                activity_locked_until: 4_u64,
                is_alive: true,
            },
        );
        let wrong_hex_complete = manager.complete_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(wrong_hex_complete == 0_u16, 'H_INT_COMPLETE_WRONG_HEX');
        let wrong_hex_cancel = manager.cancel_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(wrong_hex_cancel == 0_u16, 'H_INT_CANCEL_WRONG_HEX');

        let foreign_owner: starknet::ContractAddress = 0x1234.try_into().unwrap();
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: foreign_owner,
                name: 'FORE'_felt252,
                energy: 100_u16,
                max_energy: 100_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        let not_owner_complete = manager.complete_harvesting(
            adventurer_id, hex_coordinate, area_id, plant_id,
        );
        assert(not_owner_complete == 0_u16, 'H_INT_COMPLETE_NOT_OWNER');
        let not_owner_cancel = manager.cancel_harvesting(adventurer_id, hex_coordinate, area_id, plant_id);
        assert(not_owner_cancel == 0_u16, 'H_INT_CANCEL_NOT_OWNER');

        let other_adventurer_id = 8811_felt252;
        setup_actor_and_hex(ref world, other_adventurer_id, caller, hex_coordinate);
        let cancel_no_active = manager.cancel_harvesting(
            other_adventurer_id, hex_coordinate, area_id, plant_id,
        );
        assert(cancel_no_active == 0_u16, 'H_INT_CANCEL_NO_ACTIVE');

        let inspected = manager.inspect_plant(hex_coordinate, area_id, plant_id);
        let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
        assert(inspected.plant_key == plant_key, 'H_INT_INSPECT_KEY');
        assert(inspected.hex_coordinate == hex_coordinate, 'H_INT_INSPECT_HEX');
    }

    #[test]
    fn harvesting_manager_integration_regression_prevents_cross_actor_overcommit() {
        let caller = get_default_caller_address();
        set_block_number(10_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"harvesting_manager").unwrap();
        let manager = IHarvestingManagerDispatcher { contract_address };

        let actor_a = 8821_felt252;
        let actor_b = 8822_felt252;
        let hex_coordinate = 920_felt252;
        let area_id = 921_felt252;
        let plant_id = 3_u8;
        setup_actor_and_hex(ref world, actor_a, caller, hex_coordinate);
        setup_actor_and_hex(ref world, actor_b, caller, hex_coordinate);

        let initialized = manager.init_harvesting(hex_coordinate, area_id, plant_id);
        assert(initialized, 'H_INT_OVER_INIT');
        let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
        let seeded_plant: PlantNode = world.read_model(plant_key);
        world.write_model_test(
            @PlantNode {
                current_yield: 10_u16,
                max_yield: 10_u16,
                ..seeded_plant
            },
        );

        let first_start = manager.start_harvesting(actor_a, hex_coordinate, area_id, plant_id, 8_u16);
        assert(first_start, 'H_INT_OVER_A_START');

        let second_start = manager.start_harvesting(actor_b, hex_coordinate, area_id, plant_id, 5_u16);
        assert(!second_start, 'H_INT_OVER_B_BLOCK');

        set_block_number(26_u64);
        let a_yield = manager.complete_harvesting(actor_a, hex_coordinate, area_id, plant_id);
        let b_yield = manager.complete_harvesting(actor_b, hex_coordinate, area_id, plant_id);
        assert(a_yield == 8_u16, 'H_INT_OVER_A_YIELD');
        assert(b_yield == 0_u16, 'H_INT_OVER_B_ZERO');

        let plant: PlantNode = world.read_model(plant_key);
        assert(plant.current_yield == 2_u16, 'H_INT_OVER_PLANT_CURR');
        assert(plant.reserved_yield == 0_u16, 'H_INT_OVER_PLANT_RESV');

        let reservation_a_id = derive_harvest_reservation_id(actor_a, plant_key);
        let reservation_b_id = derive_harvest_reservation_id(actor_b, plant_key);
        let reservation_a: HarvestReservation = world.read_model(reservation_a_id);
        let reservation_b: HarvestReservation = world.read_model(reservation_b_id);
        assert(reservation_a.status == HarvestReservationStatus::Completed, 'H_INT_OVER_A_ST');
        assert(reservation_b.status == HarvestReservationStatus::Inactive, 'H_INT_OVER_B_ST');
    }
}
