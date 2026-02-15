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
    use dojo_starter::events::mining_events::{
        MineAccessGranted, MineAccessRevoked, MineCollapsed, MineInitialized, MineRepaired,
        MiningExited, MiningRejected, MiningStarted,
    };
    use dojo_starter::libs::construction_balance::{B_SHORING_RIG, B_STOREHOUSE, effect_bp_for_building};
    use dojo_starter::libs::mining_math::compute_stress_delta;
    use dojo_starter::models::construction::ConstructionBuildingNode;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::deaths::DeathRecord;
    use dojo_starter::models::economics::ConversionRate;
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::mining::{
        MineAccessGrant, MineCollapseRecord, MineNode, MiningShift, MiningShiftStatus,
        derive_mine_key, derive_mining_item_id, derive_mining_shift_id,
    };
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{AreaType, Biome, Hex, HexArea, SizeCategory, derive_area_id};
    use dojo_starter::systems::mining_manager_contract::{
        IMiningManagerDispatcher, IMiningManagerDispatcherTrait,
    };
    use dojo_starter::systems::mining_manager::apply_shoring_stress_delta;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("Inventory"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("ConversionRate"),
                TestResource::Model("DeathRecord"),
                TestResource::Model("Hex"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("MineNode"),
                TestResource::Model("MiningShift"),
                TestResource::Model("MineAccessGrant"),
                TestResource::Model("MineCollapseRecord"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Event("MineInitialized"),
                TestResource::Event("MineAccessGranted"),
                TestResource::Event("MineAccessRevoked"),
                TestResource::Event("MiningStarted"),
                TestResource::Event("MiningContinued"),
                TestResource::Event("MineStabilized"),
                TestResource::Event("MiningExited"),
                TestResource::Event("MineCollapsed"),
                TestResource::Event("MineRepaired"),
                TestResource::Event("MiningRejected"),
                TestResource::Contract("mining_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"mining_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        hex_coordinate: felt252,
        energy: u16,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'MINE'_felt252,
                energy,
                max_energy: energy,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(@Inventory { adventurer_id, current_weight: 0_u32, max_weight: 5_000_u32 });
    }

    fn setup_discovered_minefield(
        ref world: dojo::world::WorldStorage,
        caller: starknet::ContractAddress,
        controller_adventurer_id: felt252,
        hex_coordinate: felt252,
        area_id: felt252,
    ) {
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Mountain,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 6_u8,
            },
        );
        world.write_model_test(
            @HexArea {
                area_id,
                hex_coordinate,
                area_index: 2_u8,
                area_type: AreaType::MineField,
                is_discovered: true,
                discoverer: caller,
                resource_quality: 80_u16,
                size_category: SizeCategory::Large,
                plant_slot_count: 0_u8,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id,
                owner_adventurer_id: controller_adventurer_id,
                discoverer_adventurer_id: controller_adventurer_id,
                discovery_block: 1_u64,
                claim_block: 1_u64,
            },
        );
    }

    #[test]
    fn mining_manager_integration_acl_revoke_and_rejections_emit_expected_events() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);

        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"mining_manager").unwrap();
        let manager = IMiningManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let controller_id = 7101_felt252;
        let grantee_id = 7102_felt252;
        let rogue_id = 7103_felt252;
        let hex_coordinate = 8101_felt252;
        let area_id = 8102_felt252;
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);

        setup_actor(ref world, controller_id, caller, hex_coordinate, 1_000_u16);
        setup_actor(ref world, grantee_id, caller, hex_coordinate, 1_000_u16);
        setup_actor(ref world, rogue_id, caller, hex_coordinate, 1_000_u16);
        setup_discovered_minefield(ref world, caller, controller_id, hex_coordinate, area_id);

        let initialized = manager.init_mining(hex_coordinate, area_id, mine_id);
        assert(initialized, 'MINT_ACL_INIT');

        let unauthorized_grant = manager.grant_mine_access(rogue_id, mine_key, grantee_id);
        assert(!unauthorized_grant, 'MINT_ACL_BAD_GRANT');

        let granted = manager.grant_mine_access(controller_id, mine_key, grantee_id);
        assert(granted, 'MINT_ACL_GRANT_OK');
        let grant_row: MineAccessGrant = world.read_model((mine_key, grantee_id));
        assert(grant_row.is_allowed, 'MINT_ACL_GRANT_FLAG');

        let started = manager.start_mining(grantee_id, hex_coordinate, area_id, mine_id);
        assert(started, 'MINT_ACL_START_OK');

        let start_again = manager.start_mining(grantee_id, hex_coordinate, area_id, mine_id);
        assert(!start_again, 'MINT_ACL_START_DUP_REJ');

        let revoked = manager.revoke_mine_access(controller_id, mine_key, grantee_id);
        assert(revoked, 'MINT_ACL_REVOKE_OK');
        let revoked_row: MineAccessGrant = world.read_model((mine_key, grantee_id));
        assert(!revoked_row.is_allowed, 'MINT_ACL_REVOKE_FLAG');

        let banked = manager.exit_mining(grantee_id, mine_key);
        assert(banked == 0_u16, 'MINT_ACL_EXIT_ZERO');

        let restart_blocked = manager.start_mining(grantee_id, hex_coordinate, area_id, mine_id);
        assert(!restart_blocked, 'MINT_ACL_RESTART_REJ');

        let shift_id = derive_mining_shift_id(grantee_id, mine_key);
        let shift: MiningShift = world.read_model(shift_id);
        assert(shift.status == MiningShiftStatus::Exited, 'MINT_ACL_SHIFT_EXITED');

        let mine = manager.inspect_mine(hex_coordinate, area_id, mine_id);
        let mine_id_felt: felt252 = mine_id.into();
        let rarity_felt: felt252 = mine.rarity_tier.into();
        let start_block_felt: felt252 = 100_u64.into();
        let zero_banked_felt: felt252 = 0_u32.into();

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MineInitialized>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [mine_key].span(),
                                values: [
                                    hex_coordinate, area_id, mine_id_felt, mine.ore_id,
                                    rarity_felt,
                                ]
                                    .span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningRejected>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [rogue_id].span(),
                                values: [mine_key, 'MINE_GRANT'_felt252, 'NOT_CTRL'_felt252].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MineAccessGranted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [mine_key].span(),
                                values: [grantee_id, controller_id].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningStarted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [grantee_id].span(),
                                values: [mine_key, start_block_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningRejected>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [grantee_id].span(),
                                values: [
                                    mine_key, 'MINE_START'_felt252, 'SHIFT_ACTIVE'_felt252,
                                ]
                                    .span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MineAccessRevoked>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [mine_key].span(),
                                values: [grantee_id, controller_id].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningExited>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [grantee_id].span(),
                                values: [mine_key, zero_banked_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningRejected>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [grantee_id].span(),
                                values: [mine_key, 'MINE_START'_felt252, 'NO_ACCESS'_felt252].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let granted_selector = Event::<MineAccessGranted>::selector(world.namespace_hash);
        let revoked_selector = Event::<MineAccessRevoked>::selector(world.namespace_hash);
        let started_selector = Event::<MiningStarted>::selector(world.namespace_hash);
        let exited_selector = Event::<MiningExited>::selector(world.namespace_hash);
        let rejected_selector = Event::<MiningRejected>::selector(world.namespace_hash);

        let mut granted_count: usize = 0;
        let mut revoked_count: usize = 0;
        let mut started_count: usize = 0;
        let mut exited_count: usize = 0;
        let mut rejected_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @granted_selector {
                    granted_count += 1;
                } else if event.keys.at(1) == @revoked_selector {
                    revoked_count += 1;
                } else if event.keys.at(1) == @started_selector {
                    started_count += 1;
                } else if event.keys.at(1) == @exited_selector {
                    exited_count += 1;
                } else if event.keys.at(1) == @rejected_selector {
                    rejected_count += 1;
                }
            }
            idx += 1;
        };

        assert(granted_count == 1_usize, 'MINT_ACL_EVT_GRANT_CNT');
        assert(revoked_count == 1_usize, 'MINT_ACL_EVT_REVOKE_CNT');
        assert(started_count == 1_usize, 'MINT_ACL_EVT_START_CNT');
        assert(exited_count == 1_usize, 'MINT_ACL_EVT_EXIT_CNT');
        assert(rejected_count == 3_usize, 'MINT_ACL_EVT_REJ_CNT');
    }

    #[test]
    fn mining_manager_integration_continue_stabilize_exit_banks_ore_and_rate() {
        let caller = get_default_caller_address();
        set_block_number(200_u64);

        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"mining_manager").unwrap();
        let manager = IMiningManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let actor_id = 7201_felt252;
        let hex_coordinate = 8201_felt252;
        let area_id = 8202_felt252;
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
        let shift_id = derive_mining_shift_id(actor_id, mine_key);

        setup_actor(ref world, actor_id, caller, hex_coordinate, 2_000_u16);
        setup_discovered_minefield(ref world, caller, actor_id, hex_coordinate, area_id);

        let initialized = manager.init_mining(hex_coordinate, area_id, mine_id);
        assert(initialized, 'MINT_LIFE_INIT');

        let started = manager.start_mining(actor_id, hex_coordinate, area_id, mine_id);
        assert(started, 'MINT_LIFE_START');

        set_block_number(205_u64);
        let tick_one = manager.continue_mining(actor_id, mine_key);
        assert(tick_one > 0_u16, 'MINT_LIFE_TICK1');

        let shift_after_tick_one: MiningShift = world.read_model(shift_id);
        let tick_one_u32: u32 = tick_one.into();
        assert(shift_after_tick_one.accrued_ore_unbanked == tick_one_u32, 'MINT_LIFE_UNBANK1');

        let actor_after_tick_one: Adventurer = world.read_model(actor_id);
        assert(actor_after_tick_one.energy < 2_000_u16, 'MINT_LIFE_ENERGY_DROP1');

        set_block_number(206_u64);
        let stress_reduced = manager.stabilize_mine(actor_id, mine_key);
        assert(stress_reduced > 0_u32, 'MINT_LIFE_STAB');

        set_block_number(211_u64);
        let tick_two = manager.continue_mining(actor_id, mine_key);
        assert(tick_two > 0_u16, 'MINT_LIFE_TICK2');

        let shift_before_exit: MiningShift = world.read_model(shift_id);
        assert(shift_before_exit.accrued_ore_unbanked > 0_u32, 'MINT_LIFE_UNBANK2');

        let minted = manager.exit_mining(actor_id, mine_key);
        assert(minted > 0_u16, 'MINT_LIFE_EXIT_MINT');

        let shift_after_exit: MiningShift = world.read_model(shift_id);
        assert(shift_after_exit.status == MiningShiftStatus::Exited, 'MINT_LIFE_EXIT_STATUS');
        assert(shift_after_exit.accrued_ore_unbanked == 0_u32, 'MINT_LIFE_EXIT_ZERO');

        let actor_after_exit: Adventurer = world.read_model(actor_id);
        assert(actor_after_exit.activity_locked_until == 0_u64, 'MINT_LIFE_UNLOCK');

        let mine = manager.inspect_mine(hex_coordinate, area_id, mine_id);
        let item_id = derive_mining_item_id(mine.ore_id);
        let minted_u32: u32 = minted.into();

        let inventory: Inventory = world.read_model(actor_id);
        assert(inventory.current_weight == minted_u32, 'MINT_LIFE_INV');

        let item: BackpackItem = world.read_model((actor_id, item_id));
        assert(item.quantity == minted_u32, 'MINT_LIFE_ITEM_QTY');
        assert(item.quality == 100_u16, 'MINT_LIFE_ITEM_QUALITY');

        let rate: ConversionRate = world.read_model(item_id);
        assert(rate.item_type == item_id, 'MINT_LIFE_RATE_ITEM');
        assert(rate.base_rate == mine.conversion_energy_per_unit, 'MINT_LIFE_RATE_BASE');
        assert(rate.current_rate == mine.conversion_energy_per_unit, 'MINT_LIFE_RATE_CURR');

        let start_block_felt: felt252 = 200_u64.into();
        let minted_felt: felt252 = minted_u32.into();

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningStarted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [actor_id].span(),
                                values: [mine_key, start_block_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MiningExited>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [actor_id].span(),
                                values: [mine_key, minted_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let started_selector = Event::<MiningStarted>::selector(world.namespace_hash);
        let continued_selector = Event::<dojo_starter::events::mining_events::MiningContinued>::selector(
            world.namespace_hash,
        );
        let stabilized_selector = Event::<dojo_starter::events::mining_events::MineStabilized>::selector(
            world.namespace_hash,
        );
        let exited_selector = Event::<MiningExited>::selector(world.namespace_hash);
        let collapsed_selector = Event::<MineCollapsed>::selector(world.namespace_hash);
        let rejected_selector = Event::<MiningRejected>::selector(world.namespace_hash);

        let mut started_count: usize = 0;
        let mut continued_count: usize = 0;
        let mut stabilized_count: usize = 0;
        let mut exited_count: usize = 0;
        let mut collapsed_count: usize = 0;
        let mut rejected_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @started_selector {
                    started_count += 1;
                } else if event.keys.at(1) == @continued_selector {
                    continued_count += 1;
                } else if event.keys.at(1) == @stabilized_selector {
                    stabilized_count += 1;
                } else if event.keys.at(1) == @exited_selector {
                    exited_count += 1;
                } else if event.keys.at(1) == @collapsed_selector {
                    collapsed_count += 1;
                } else if event.keys.at(1) == @rejected_selector {
                    rejected_count += 1;
                }
            }
            idx += 1;
        };

        assert(started_count == 1_usize, 'MINT_LIFE_EVT_START');
        assert(continued_count == 2_usize, 'MINT_LIFE_EVT_CONT');
        assert(stabilized_count == 1_usize, 'MINT_LIFE_EVT_STAB');
        assert(exited_count == 1_usize, 'MINT_LIFE_EVT_EXIT');
        assert(collapsed_count == 0_usize, 'MINT_LIFE_EVT_COLL_0');
        assert(rejected_count == 0_usize, 'MINT_LIFE_EVT_REJ_0');
    }

    #[test]
    fn mining_manager_integration_storehouse_increases_exit_capacity() {
        let caller = get_default_caller_address();
        set_block_number(420_u64);

        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"mining_manager").unwrap();
        let manager = IMiningManagerDispatcher { contract_address };

        let actor_id = 7261_felt252;
        let hex_coordinate = 8261_felt252;
        let area_id = derive_area_id(hex_coordinate, 2_u8);
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
        let shift_id = derive_mining_shift_id(actor_id, mine_key);

        setup_actor(ref world, actor_id, caller, hex_coordinate, 2_000_u16);
        world.write_model_test(@Inventory { adventurer_id: actor_id, current_weight: 0_u32, max_weight: 3_u32 });
        setup_discovered_minefield(ref world, caller, actor_id, hex_coordinate, area_id);
        world.write_model_test(
            @ConstructionBuildingNode {
                area_id: derive_area_id(hex_coordinate, 0_u8),
                hex_coordinate,
                owner_adventurer_id: actor_id,
                building_type: B_STOREHOUSE,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );

        let initialized = manager.init_mining(hex_coordinate, area_id, mine_id);
        assert(initialized, 'MINT_STORE_INIT');
        let started = manager.start_mining(actor_id, hex_coordinate, area_id, mine_id);
        assert(started, 'MINT_STORE_START');

        let seed_shift: MiningShift = world.read_model(shift_id);
        world.write_model_test(@MiningShift { accrued_ore_unbanked: 5_u32, ..seed_shift });

        let minted = manager.exit_mining(actor_id, mine_key);
        assert(minted == 4_u16, 'MINT_STORE_EXIT');

        let mine_after: MineNode = world.read_model(mine_key);
        let item_id = derive_mining_item_id(mine_after.ore_id);
        let item: BackpackItem = world.read_model((actor_id, item_id));
        let inventory: Inventory = world.read_model(actor_id);
        let shift_after: MiningShift = world.read_model(shift_id);
        assert(inventory.current_weight == 4_u32, 'MINT_STORE_INV');
        assert(item.quantity == 4_u32, 'MINT_STORE_ITEM');
        assert(shift_after.status == MiningShiftStatus::Exited, 'MINT_STORE_SHIFT');
    }

    #[test]
    fn mining_manager_integration_shoring_rig_reduces_stress_delta() {
        let caller = get_default_caller_address();
        set_block_number(400_u64);

        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"mining_manager").unwrap();
        let manager = IMiningManagerDispatcher { contract_address };

        let actor_id = 7251_felt252;
        let hex_coordinate = 8251_felt252;
        let area_id = derive_area_id(hex_coordinate, 2_u8);
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);
        let shift_id = derive_mining_shift_id(actor_id, mine_key);

        setup_actor(ref world, actor_id, caller, hex_coordinate, 2_000_u16);
        setup_discovered_minefield(ref world, caller, actor_id, hex_coordinate, area_id);
        world.write_model_test(
            @ConstructionBuildingNode {
                area_id,
                hex_coordinate,
                owner_adventurer_id: actor_id,
                building_type: B_SHORING_RIG,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );

        let initialized = manager.init_mining(hex_coordinate, area_id, mine_id);
        assert(initialized, 'MINT_SHORE_INIT');
        let started = manager.start_mining(actor_id, hex_coordinate, area_id, mine_id);
        assert(started, 'MINT_SHORE_START');

        set_block_number(405_u64);
        let mine_before: MineNode = world.read_model(mine_key);
        let shift_before: MiningShift = world.read_model(shift_id);
        let dt_blocks = 405_u64 - shift_before.last_settle_block;
        let shift_elapsed_blocks = 405_u64 - shift_before.start_block;
        let base_stress_delta = compute_stress_delta(
            dt_blocks,
            mine_before.base_stress_per_block,
            mine_before.active_miners,
            shift_elapsed_blocks,
            mine_before.safe_shift_blocks,
            mine_before.biome_risk_bp,
            mine_before.rarity_risk_bp,
            120_u16,
            2_u16,
        );
        let expected_stress_delta = apply_shoring_stress_delta(
            base_stress_delta, effect_bp_for_building(B_SHORING_RIG),
        );
        assert(base_stress_delta >= expected_stress_delta, 'MINT_SHORE_MONO');

        let mined = manager.continue_mining(actor_id, mine_key);
        assert(mined > 0_u16, 'MINT_SHORE_CONT');

        let mine_after: MineNode = world.read_model(mine_key);
        assert(mine_after.mine_stress == expected_stress_delta, 'MINT_SHORE_STRESS');
    }

    #[test]
    fn mining_manager_integration_collapse_kills_and_repair_reopens() {
        let caller = get_default_caller_address();
        set_block_number(300_u64);

        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"mining_manager").unwrap();
        let manager = IMiningManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let controller_id = 7301_felt252;
        let miner_a_id = 7302_felt252;
        let miner_b_id = 7303_felt252;
        let repairer_id = 7304_felt252;
        let hex_coordinate = 8301_felt252;
        let area_id = 8302_felt252;
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, area_id, mine_id);

        setup_actor(ref world, controller_id, caller, hex_coordinate, 12_000_u16);
        setup_actor(ref world, miner_a_id, caller, hex_coordinate, 12_000_u16);
        setup_actor(ref world, miner_b_id, caller, hex_coordinate, 12_000_u16);
        setup_actor(ref world, repairer_id, caller, hex_coordinate, 12_000_u16);
        setup_discovered_minefield(ref world, caller, controller_id, hex_coordinate, area_id);

        // Ensure collapse path proves inventory wipe semantics on death.
        world.write_model_test(
            @Inventory { adventurer_id: miner_a_id, current_weight: 17_u32, max_weight: 5_000_u32 },
        );
        world.write_model_test(
            @Inventory { adventurer_id: miner_b_id, current_weight: 19_u32, max_weight: 5_000_u32 },
        );

        let initialized = manager.init_mining(hex_coordinate, area_id, mine_id);
        assert(initialized, 'MINT_COLL_INIT');

        let grant_a = manager.grant_mine_access(controller_id, mine_key, miner_a_id);
        let grant_b = manager.grant_mine_access(controller_id, mine_key, miner_b_id);
        assert(grant_a, 'MINT_COLL_GRANT_A');
        assert(grant_b, 'MINT_COLL_GRANT_B');

        let started_a = manager.start_mining(miner_a_id, hex_coordinate, area_id, mine_id);
        let started_b = manager.start_mining(miner_b_id, hex_coordinate, area_id, mine_id);
        assert(started_a, 'MINT_COLL_START_A');
        assert(started_b, 'MINT_COLL_START_B');

        let seeded_mine: MineNode = world.read_model(mine_key);
        let forced_stress = if seeded_mine.collapse_threshold > 0_u32 {
            seeded_mine.collapse_threshold - 1_u32
        } else {
            0_u32
        };
        world.write_model_test(@MineNode { mine_stress: forced_stress, ..seeded_mine });

        set_block_number(301_u64);
        let collapse_tick = manager.continue_mining(miner_a_id, mine_key);
        assert(collapse_tick == 0_u16, 'MINT_COLL_CONT_ZERO');

        let mine_after_collapse: MineNode = world.read_model(mine_key);
        assert(mine_after_collapse.repair_energy_needed > 0_u32, 'MINT_COLL_REPAIR_NEED');
        assert(mine_after_collapse.active_miners == 0_u16, 'MINT_COLL_ACTIVE_ZERO');
        assert(mine_after_collapse.active_head_shift_id == 0_felt252, 'MINT_COLL_HEAD_ZERO');
        assert(mine_after_collapse.active_tail_shift_id == 0_felt252, 'MINT_COLL_TAIL_ZERO');

        let shift_a_id = derive_mining_shift_id(miner_a_id, mine_key);
        let shift_b_id = derive_mining_shift_id(miner_b_id, mine_key);
        let shift_a: MiningShift = world.read_model(shift_a_id);
        let shift_b: MiningShift = world.read_model(shift_b_id);
        assert(shift_a.status == MiningShiftStatus::Collapsed, 'MINT_COLL_SHIFT_A');
        assert(shift_b.status == MiningShiftStatus::Collapsed, 'MINT_COLL_SHIFT_B');
        assert(shift_a.accrued_ore_unbanked == 0_u32, 'MINT_COLL_A_UNBANK0');
        assert(shift_b.accrued_ore_unbanked == 0_u32, 'MINT_COLL_B_UNBANK0');

        let miner_a_after: Adventurer = world.read_model(miner_a_id);
        let miner_b_after: Adventurer = world.read_model(miner_b_id);
        assert(!miner_a_after.is_alive, 'MINT_COLL_A_DEAD');
        assert(!miner_b_after.is_alive, 'MINT_COLL_B_DEAD');
        assert(miner_a_after.activity_locked_until == 0_u64, 'MINT_COLL_A_UNLOCK');
        assert(miner_b_after.activity_locked_until == 0_u64, 'MINT_COLL_B_UNLOCK');

        let inv_a_after: Inventory = world.read_model(miner_a_id);
        let inv_b_after: Inventory = world.read_model(miner_b_id);
        assert(inv_a_after.current_weight == 0_u32, 'MINT_COLL_INV_A_CLR');
        assert(inv_b_after.current_weight == 0_u32, 'MINT_COLL_INV_B_CLR');

        let death_a: DeathRecord = world.read_model(miner_a_id);
        let death_b: DeathRecord = world.read_model(miner_b_id);
        assert(death_a.death_cause == 'MINE_COLLAPSE'_felt252, 'MINT_COLL_CAUSE_A');
        assert(death_b.death_cause == 'MINE_COLLAPSE'_felt252, 'MINT_COLL_CAUSE_B');
        assert(death_a.death_block == 301_u64, 'MINT_COLL_BLOCK_A');
        assert(death_b.death_block == 301_u64, 'MINT_COLL_BLOCK_B');

        let collapse_record: MineCollapseRecord = world.read_model(mine_key);
        assert(collapse_record.collapse_count == 1_u32, 'MINT_COLL_COUNT');
        assert(collapse_record.trigger_active_miners == 2_u16, 'MINT_COLL_ACTIVE_TRIG');

        set_block_number(302_u64);
        let expected_repair_spend = mine_after_collapse.repair_energy_needed;
        let repair_remaining = manager.repair_mine(repairer_id, mine_key, 10_000_u16);
        assert(repair_remaining == 0_u32, 'MINT_COLL_REPAIR_DONE');

        let mine_after_repair: MineNode = world.read_model(mine_key);
        assert(mine_after_repair.repair_energy_needed == 0_u32, 'MINT_COLL_REPAIR_ZERO');
        assert(mine_after_repair.collapsed_until_block == 0_u64, 'MINT_COLL_RESET_COLL_BLOCK');

        let grant_repairer = manager.grant_mine_access(controller_id, mine_key, repairer_id);
        assert(grant_repairer, 'MINT_COLL_GRANT_REPAIRER');

        let restarted = manager.start_mining(repairer_id, hex_coordinate, area_id, mine_id);
        assert(restarted, 'MINT_COLL_RESTART_OK');

        let shift_repairer_id = derive_mining_shift_id(repairer_id, mine_key);
        let shift_repairer: MiningShift = world.read_model(shift_repairer_id);
        assert(shift_repairer.status == MiningShiftStatus::Active, 'MINT_COLL_REPAIRER_ACTIVE');

        let killed_miners_felt: felt252 = 2_u16.into();
        let collapse_count_felt: felt252 = 1_u32.into();
        let repair_spent_felt: felt252 = expected_repair_spend.into();
        let repair_remaining_felt: felt252 = 0_u32.into();

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MineCollapsed>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [mine_key].span(),
                                values: [killed_miners_felt, collapse_count_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<MineRepaired>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [mine_key].span(),
                                values: [repairer_id, repair_spent_felt, repair_remaining_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let granted_selector = Event::<MineAccessGranted>::selector(world.namespace_hash);
        let started_selector = Event::<MiningStarted>::selector(world.namespace_hash);
        let collapsed_selector = Event::<MineCollapsed>::selector(world.namespace_hash);
        let repaired_selector = Event::<MineRepaired>::selector(world.namespace_hash);
        let rejected_selector = Event::<MiningRejected>::selector(world.namespace_hash);

        let mut granted_count: usize = 0;
        let mut started_count: usize = 0;
        let mut collapsed_count: usize = 0;
        let mut repaired_count: usize = 0;
        let mut rejected_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @granted_selector {
                    granted_count += 1;
                } else if event.keys.at(1) == @started_selector {
                    started_count += 1;
                } else if event.keys.at(1) == @collapsed_selector {
                    collapsed_count += 1;
                } else if event.keys.at(1) == @repaired_selector {
                    repaired_count += 1;
                } else if event.keys.at(1) == @rejected_selector {
                    rejected_count += 1;
                }
            }
            idx += 1;
        };

        assert(granted_count == 3_usize, 'MINT_COLL_EVT_GRANTS');
        assert(started_count == 3_usize, 'MINT_COLL_EVT_STARTS');
        assert(collapsed_count == 1_usize, 'MINT_COLL_EVT_COLL');
        assert(repaired_count == 1_usize, 'MINT_COLL_EVT_REPAIR');
        assert(rejected_count == 0_usize, 'MINT_COLL_EVT_REJ_0');
    }
}
