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
    use dojo_starter::events::economic_events::{
        ClaimExpired, ClaimInitiated, ClaimRefunded, HexDefended, HexEnergyPaid, ItemsConverted,
    };
    use dojo_starter::libs::construction_balance::{B_SMELTER, B_WATCHTOWER, I_ORE_IRON};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::construction::ConstructionBuildingNode;
    use dojo_starter::models::economics::{
        AdventurerEconomics, ClaimEscrow, ClaimEscrowStatus, ConversionRate, HexDecayState,
        RegulatorConfig, RegulatorPolicy, derive_hex_claim_id,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::ownership::AreaOwnership;
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
                TestResource::Model("Inventory"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexDecayState"),
                TestResource::Model("ClaimEscrow"),
                TestResource::Model("ConversionRate"),
                TestResource::Model("RegulatorPolicy"),
                TestResource::Model("RegulatorConfig"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Event("ItemsConverted"),
                TestResource::Event("HexEnergyPaid"),
                TestResource::Event("HexBecameClaimable"),
                TestResource::Event("ClaimInitiated"),
                TestResource::Event("ClaimExpired"),
                TestResource::Event("ClaimRefunded"),
                TestResource::Event("HexDefended"),
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
                name: 'ECO'_felt252,
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

    fn seed_regulator_policy(
        ref world: dojo::world::WorldStorage,
        policy_epoch: u32,
        conversion_tax_bp: u16,
        upkeep_bp: u16,
        mint_discount_bp: u16,
    ) {
        world.write_model_test(
            @RegulatorConfig {
                slot: 1_u8,
                epoch_blocks: 100_u64,
                keeper_bounty_energy: 10_u16,
                keeper_bounty_max: 20_u16,
                bounty_funding_share_bp: 100_u16,
                inflation_target_pct: 10_u16,
                inflation_deadband_pct: 1_u16,
                policy_slew_limit_bp: 100_u16,
                min_conversion_tax_bp: 100_u16,
                max_conversion_tax_bp: 5_000_u16,
            },
        );
        world.write_model_test(
            @RegulatorPolicy {
                slot: 1_u8,
                policy_epoch,
                conversion_tax_bp,
                upkeep_bp,
                mint_discount_bp,
            },
        );
    }

    #[test]
    fn economic_manager_integration_conversion_tax_reads_regulator_policy() {
        let caller = get_default_caller_address();
        set_block_number(200_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let adventurer_id = 9801_felt252;
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'TAX'_felt252,
                energy: 100_u16,
                max_energy: 500_u16,
                current_hex: 0_felt252,
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
            @Inventory { adventurer_id, current_weight: 20_u32, max_weight: 100_u32 },
        );
        world.write_model_test(
            @BackpackItem {
                adventurer_id,
                item_id: 880_felt252,
                quantity: 20_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
        world.write_model_test(
            @ConversionRate {
                item_type: 880_felt252,
                current_rate: 10_u16,
                base_rate: 10_u16,
                last_update_block: 0_u64,
                units_converted_in_window: 0_u32,
            },
        );
        seed_regulator_policy(ref world, 1_u32, 2_000_u16, 10_000_u16, 0_u16);

        let gained = manager.convert_items_to_energy(adventurer_id, 880_felt252, 10_u16);
        assert(gained == 80_u16, 'S4_POL_TAX_GAIN');

        let after: Adventurer = world.read_model(adventurer_id);
        let econ_after: AdventurerEconomics = world.read_model(adventurer_id);
        assert(after.energy == 180_u16, 'S4_POL_TAX_ENERGY');
        assert(econ_after.energy_balance == 180_u16, 'S4_POL_TAX_BAL');
    }

    #[test]
    fn economic_manager_integration_upkeep_reads_regulator_policy() {
        let caller = get_default_caller_address();
        set_block_number(200_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9802_felt252;
        let hex_coordinate = 9803_felt252;
        setup_actor(ref world, owner_id, caller, 200_u16, hex_coordinate);
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 0_u8,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate,
                owner_adventurer_id: owner_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 80_u16,
                claimable_since_block: 10_u64,
            },
        );
        // 50% upkeep policy should increase effective recovery at fixed payment.
        seed_regulator_policy(ref world, 1_u32, 0_u16, 5_000_u16, 0_u16);

        let paid = manager.pay_hex_maintenance(owner_id, hex_coordinate, 100_u16);
        assert(paid, 'S4_POL_UPKEEP_PAY');

        let state_after: HexDecayState = world.read_model(hex_coordinate);
        assert(state_after.current_energy_reserve == 100_u32, 'S4_POL_UPKEEP_RESV');
        assert(state_after.decay_level == 60_u16, 'S4_POL_UPKEEP_DECAY');
    }

    #[test]
    fn economic_manager_integration_policy_changes_apply_next_epoch() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let adventurer_id = 9804_felt252;
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner: caller,
                name: 'NXT'_felt252,
                energy: 100_u16,
                max_energy: 500_u16,
                current_hex: 0_felt252,
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
            @Inventory { adventurer_id, current_weight: 20_u32, max_weight: 100_u32 },
        );
        world.write_model_test(
            @BackpackItem {
                adventurer_id,
                item_id: 881_felt252,
                quantity: 20_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
        world.write_model_test(
            @ConversionRate {
                item_type: 881_felt252,
                current_rate: 10_u16,
                base_rate: 10_u16,
                last_update_block: 0_u64,
                units_converted_in_window: 0_u32,
            },
        );
        // Policy epoch equals current epoch (1), so conversion tax must apply next epoch.
        seed_regulator_policy(ref world, 1_u32, 2_000_u16, 10_000_u16, 0_u16);

        let same_epoch = manager.convert_items_to_energy(adventurer_id, 881_felt252, 5_u16);
        assert(same_epoch == 50_u16, 'S4_POL_NEXT_EPOCH_WAIT');

        set_block_number(200_u64);
        let next_epoch = manager.convert_items_to_energy(adventurer_id, 881_felt252, 5_u16);
        assert(next_epoch == 40_u16, 'S4_POL_NEXT_EPOCH_APPLY');
    }

    #[test]
    fn economic_manager_integration_convert_pay_decay_claim_defend() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let owner_id = 9101_felt252;
        let claimant_id = 9102_felt252;
        let hex_coordinate = 9200_felt252;

        setup_actor(ref world, owner_id, caller, 400_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 500_u16, hex_coordinate);

        world.write_model_test(@Inventory { adventurer_id: claimant_id, current_weight: 20_u32, max_weight: 100_u32 });
        world.write_model_test(
            @BackpackItem {
                adventurer_id: claimant_id,
                item_id: 77_felt252,
                quantity: 20_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
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

        let gained = manager.convert_items_to_energy(claimant_id, 77_felt252, 5_u16);
        assert(gained == 50_u16, 'S4_INT_CONV_GAIN');
        let claimant_after_convert: Adventurer = world.read_model(claimant_id);
        let inv_after_convert: Inventory = world.read_model(claimant_id);
        let item_after_convert: BackpackItem = world.read_model((claimant_id, 77_felt252));
        let rate_after_convert: ConversionRate = world.read_model(77_felt252);
        assert(claimant_after_convert.energy == 500_u16, 'S4_INT_CONV_CAP');
        assert(inv_after_convert.current_weight == 15_u32, 'S4_INT_CONV_INV');
        assert(item_after_convert.quantity == 15_u32, 'S4_INT_CONV_QTY');
        assert(rate_after_convert.units_converted_in_window == 5_u32, 'S4_INT_CONV_RATE');

        let paid = manager.pay_hex_maintenance(owner_id, hex_coordinate, 40_u16);
        assert(paid, 'S4_INT_PAY');
        let owner_after_pay: Adventurer = world.read_model(owner_id);
        let state_after_pay: HexDecayState = world.read_model(hex_coordinate);
        assert(owner_after_pay.energy == 360_u16, 'S4_INT_PAY_ENE');
        assert(state_after_pay.current_energy_reserve == 40_u32, 'S4_INT_PAY_RESV');

        set_block_number(200_u64);
        let decay_level = manager.process_hex_decay(hex_coordinate);
        assert(decay_level <= 100_u16, 'S4_INT_DECAY_LEVEL');

        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 250_u16);
        assert(initiated, 'S4_INT_CLAIM_INIT');
        let claim_id = derive_hex_claim_id(hex_coordinate);
        let escrow_after_initiate: ClaimEscrow = world.read_model(claim_id);
        assert(escrow_after_initiate.status == ClaimEscrowStatus::Active, 'S4_INT_ESCROW_ACTIVE');
        assert(escrow_after_initiate.energy_locked == 250_u16, 'S4_INT_ESCROW_LOCK');

        let defended = manager.defend_hex_from_claim(owner_id, hex_coordinate, 250_u16);
        assert(defended, 'S4_INT_DEFEND');
        let escrow_after_defend: ClaimEscrow = world.read_model(claim_id);
        let state_after_defend: HexDecayState = world.read_model(hex_coordinate);
        let claimant_after_defend: Adventurer = world.read_model(claimant_id);
        assert(escrow_after_defend.status == ClaimEscrowStatus::Resolved, 'S4_INT_ESCROW_RES');
        assert(escrow_after_defend.energy_locked == 0_u16, 'S4_INT_ESCROW_ZERO');
        assert(state_after_defend.current_energy_reserve >= 250_u32, 'S4_INT_DEF_RESV');
        assert(claimant_after_defend.energy == 500_u16, 'S4_INT_DEF_REFUND');

        let quantity_felt: felt252 = 5_u16.into();
        let gained_felt: felt252 = 50_u16.into();
        let paid_amount_felt: felt252 = 40_u16.into();
        let locked_felt: felt252 = 250_u16.into();
        let expiry_felt: felt252 = 300_u64.into();
        let refund_felt: felt252 = 250_u16.into();
        let defend_felt: felt252 = 250_u16.into();
        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ItemsConverted>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [claimant_id].span(),
                                values: [77_felt252, quantity_felt, gained_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HexEnergyPaid>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [owner_id, paid_amount_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimInitiated>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate, claimant_id].span(),
                                values: [claim_id, locked_felt, expiry_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimRefunded>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [claim_id, claimant_id, refund_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<HexDefended>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [owner_id, defend_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let converted_selector = Event::<ItemsConverted>::selector(world.namespace_hash);
        let paid_selector = Event::<HexEnergyPaid>::selector(world.namespace_hash);
        let claim_selector = Event::<ClaimInitiated>::selector(world.namespace_hash);
        let refunded_selector = Event::<ClaimRefunded>::selector(world.namespace_hash);
        let defended_selector = Event::<HexDefended>::selector(world.namespace_hash);

        let mut converted_count: usize = 0;
        let mut paid_count: usize = 0;
        let mut claim_count: usize = 0;
        let mut refunded_count: usize = 0;
        let mut defended_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @converted_selector {
                    converted_count += 1;
                } else if event.keys.at(1) == @paid_selector {
                    paid_count += 1;
                } else if event.keys.at(1) == @claim_selector {
                    claim_count += 1;
                } else if event.keys.at(1) == @refunded_selector {
                    refunded_count += 1;
                } else if event.keys.at(1) == @defended_selector {
                    defended_count += 1;
                }
            }
            idx += 1;
        };

        assert(converted_count == 1_usize, 'S4_INT_EVT_CONV_CNT');
        assert(paid_count == 1_usize, 'S4_INT_EVT_PAY_CNT');
        assert(claim_count == 1_usize, 'S4_INT_EVT_CLAIM_CNT');
        assert(refunded_count == 1_usize, 'S4_INT_EVT_REFUND_CNT');
        assert(defended_count == 1_usize, 'S4_INT_EVT_DEFEND_CNT');
    }

    #[test]
    fn economic_manager_integration_expired_claim_refunded_then_reclaimable() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let owner_id = 9201_felt252;
        let claimant_a = 9202_felt252;
        let claimant_b = 9203_felt252;
        let hex_coordinate = 9300_felt252;

        setup_actor(ref world, owner_id, caller, 500_u16, hex_coordinate);
        setup_actor(ref world, claimant_a, caller, 300_u16, hex_coordinate);
        setup_actor(ref world, claimant_b, caller, 350_u16, hex_coordinate);

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

        let first = manager.initiate_hex_claim(claimant_a, hex_coordinate, 150_u16);
        assert(first, 'S4_INT_EXP_FIRST');
        let claim_id = derive_hex_claim_id(hex_coordinate);
        let after_first: ClaimEscrow = world.read_model(claim_id);
        assert(after_first.status == ClaimEscrowStatus::Active, 'S4_INT_EXP_FIRST_ST');
        assert(after_first.expiry_block == 200_u64, 'S4_INT_EXP_FIRST_EXP');

        set_block_number(201_u64);
        let second = manager.initiate_hex_claim(claimant_b, hex_coordinate, 160_u16);
        assert(second, 'S4_INT_EXP_SECOND');

        let claimant_a_after: Adventurer = world.read_model(claimant_a);
        let escrow_after_second: ClaimEscrow = world.read_model(claim_id);
        assert(claimant_a_after.energy == 300_u16, 'S4_INT_EXP_REFUNDED');
        assert(escrow_after_second.status == ClaimEscrowStatus::Active, 'S4_INT_EXP_REACTIVE');
        assert(escrow_after_second.claimant_adventurer_id == claimant_b, 'S4_INT_EXP_CLAIMANT');
        assert(escrow_after_second.energy_locked == 160_u16, 'S4_INT_EXP_LOCKED');

        let first_locked_felt: felt252 = 150_u16.into();
        let second_locked_felt: felt252 = 160_u16.into();
        let first_expiry_felt: felt252 = 200_u64.into();
        let second_expiry_felt: felt252 = 301_u64.into();
        let refunded_felt: felt252 = 150_u16.into();

        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimInitiated>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate, claimant_a].span(),
                                values: [claim_id, first_locked_felt, first_expiry_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimExpired>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [claim_id, claimant_a].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimRefunded>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [claim_id, claimant_a, refunded_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimInitiated>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate, claimant_b].span(),
                                values: [claim_id, second_locked_felt, second_expiry_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let initiated_selector = Event::<ClaimInitiated>::selector(world.namespace_hash);
        let expired_selector = Event::<ClaimExpired>::selector(world.namespace_hash);
        let refunded_selector = Event::<ClaimRefunded>::selector(world.namespace_hash);

        let mut initiated_count: usize = 0;
        let mut expired_count: usize = 0;
        let mut refunded_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @initiated_selector {
                    initiated_count += 1;
                } else if event.keys.at(1) == @expired_selector {
                    expired_count += 1;
                } else if event.keys.at(1) == @refunded_selector {
                    refunded_count += 1;
                }
            }
            idx += 1;
        };

        assert(initiated_count == 2_usize, 'S4_INT_EXP_EVT_INIT_CNT');
        assert(expired_count == 1_usize, 'S4_INT_EXP_EVT_EXP_CNT');
        assert(refunded_count == 1_usize, 'S4_INT_EXP_EVT_REF_CNT');
    }

    #[test]
    fn economic_manager_integration_defend_after_expiry_refunds_and_emits() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let owner_id = 9301_felt252;
        let claimant_id = 9302_felt252;
        let hex_coordinate = 9400_felt252;

        setup_actor(ref world, owner_id, caller, 500_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 350_u16, hex_coordinate);
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

        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 180_u16);
        assert(initiated, 'S4_INT_DEF_EXP_INIT');

        set_block_number(201_u64);
        let defended = manager.defend_hex_from_claim(owner_id, hex_coordinate, 180_u16);
        assert(!defended, 'S4_INT_DEF_EXP_FALSE');

        let claim_id = derive_hex_claim_id(hex_coordinate);
        let escrow_after: ClaimEscrow = world.read_model(claim_id);
        let claimant_after: Adventurer = world.read_model(claimant_id);
        assert(escrow_after.status == ClaimEscrowStatus::Expired, 'S4_INT_DEF_EXP_ST');
        assert(escrow_after.energy_locked == 0_u16, 'S4_INT_DEF_EXP_LOCK');
        assert(claimant_after.energy == 350_u16, 'S4_INT_DEF_EXP_REFUND');

        let locked_felt: felt252 = 180_u16.into();
        let expiry_felt: felt252 = 200_u64.into();
        let refunded_felt: felt252 = 180_u16.into();
        spy
            .assert_emitted(
                @array![
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimInitiated>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate, claimant_id].span(),
                                values: [claim_id, locked_felt, expiry_felt].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimExpired>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [claim_id, claimant_id].span(),
                            },
                        ),
                    ),
                    (
                        world.dispatcher.contract_address,
                        world::Event::EventEmitted(
                            world::EventEmitted {
                                selector: Event::<ClaimRefunded>::selector(world.namespace_hash),
                                system_address: contract_address,
                                keys: [hex_coordinate].span(),
                                values: [claim_id, claimant_id, refunded_felt].span(),
                            },
                        ),
                    ),
                ],
            );

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let initiated_selector = Event::<ClaimInitiated>::selector(world.namespace_hash);
        let expired_selector = Event::<ClaimExpired>::selector(world.namespace_hash);
        let refunded_selector = Event::<ClaimRefunded>::selector(world.namespace_hash);

        let mut initiated_count: usize = 0;
        let mut expired_count: usize = 0;
        let mut refunded_count: usize = 0;
        let mut defended_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @initiated_selector {
                    initiated_count += 1;
                } else if event.keys.at(1) == @expired_selector {
                    expired_count += 1;
                } else if event.keys.at(1) == @refunded_selector {
                    refunded_count += 1;
                } else if event.keys.at(1) == @Event::<HexDefended>::selector(world.namespace_hash) {
                    defended_count += 1;
                }
            }
            idx += 1;
        };

        assert(initiated_count == 1_usize, 'S4_INT_DEF_EXP_EVT_INIT');
        assert(expired_count == 1_usize, 'S4_INT_DEF_EXP_EVT_EXP');
        assert(refunded_count == 1_usize, 'S4_INT_DEF_EXP_EVT_REF');
        assert(defended_count == 0_usize, 'S4_INT_DEF_EXP_EVT_DEF');
    }

    #[test]
    fn economic_manager_integration_immediate_claim_transfers_all_area_rows() {
        let caller = get_default_caller_address();
        set_block_number(700_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9501_felt252;
        let claimant_id = 9502_felt252;
        let hex_coordinate = 9600_felt252;
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

        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 0_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 10_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 1_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 11_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 2_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 12_u64,
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
                area_id: derive_area_id(hex_coordinate, 2_u8),
                hex_coordinate,
                owner_adventurer_id: owner_id,
                building_type: B_WATCHTOWER,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );

        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 250_u16);
        assert(initiated, 'S5_INT_CLAIM_IMM');

        let state_after: HexDecayState = world.read_model(hex_coordinate);
        assert(state_after.owner_adventurer_id == claimant_id, 'S5_INT_STATE_OWNER');

        let own0: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let own1: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let own2: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(own0.owner_adventurer_id == claimant_id, 'S5_INT_ROW0');
        assert(own1.owner_adventurer_id == claimant_id, 'S5_INT_ROW1');
        assert(own2.owner_adventurer_id == claimant_id, 'S5_INT_ROW2');
        assert(own0.claim_block == 700_u64, 'S5_INT_ROW0_BLOCK');
        assert(own1.claim_block == 700_u64, 'S5_INT_ROW1_BLOCK');
        assert(own2.claim_block == 700_u64, 'S5_INT_ROW2_BLOCK');

        let b0: ConstructionBuildingNode = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let b2: ConstructionBuildingNode = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(b0.owner_adventurer_id == claimant_id, 'S5_INT_BLD0_OWNER');
        assert(b2.owner_adventurer_id == claimant_id, 'S5_INT_BLD2_OWNER');
    }

    #[test]
    fn economic_manager_integration_construction_bonuses_apply_for_convert_and_defend() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9591_felt252;
        let claimant_id = 9592_felt252;
        let hex_coordinate = 9690_felt252;
        setup_actor(ref world, owner_id, caller, 500_u16, hex_coordinate);
        world.write_model_test(
            @Adventurer {
                adventurer_id: claimant_id,
                owner: caller,
                name: 'C4BONUS'_felt252,
                energy: 200_u16,
                max_energy: 500_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id: claimant_id,
                energy_balance: 200_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
        world.write_model_test(
            @Inventory { adventurer_id: claimant_id, current_weight: 10_u32, max_weight: 100_u32 },
        );
        world.write_model_test(
            @BackpackItem {
                adventurer_id: claimant_id,
                item_id: I_ORE_IRON,
                quantity: 10_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
        world.write_model_test(
            @ConversionRate {
                item_type: I_ORE_IRON,
                base_rate: 10_u16,
                current_rate: 10_u16,
                last_update_block: 0_u64,
                units_converted_in_window: 0_u32,
            },
        );

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 2_u8,
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
                discovery_block: 10_u64,
                claim_block: 0_u64,
            },
        );
        world.write_model_test(
            @AreaOwnership {
                area_id: derive_area_id(hex_coordinate, 1_u8),
                owner_adventurer_id: owner_id,
                discoverer_adventurer_id: owner_id,
                discovery_block: 11_u64,
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
                building_type: B_WATCHTOWER,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );

        let gained = manager.convert_items_to_energy(claimant_id, I_ORE_IRON, 5_u16);
        assert(gained == 56_u16, 'S5_INT_BONUS_CONV');
        let claimant_after_convert: Adventurer = world.read_model(claimant_id);
        assert(claimant_after_convert.energy == 256_u16, 'S5_INT_BONUS_CONV_ENE');

        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 200_u16);
        assert(initiated, 'S5_INT_BONUS_CLAIM');

        let defended = manager.defend_hex_from_claim(owner_id, hex_coordinate, 180_u16);
        assert(defended, 'S5_INT_BONUS_DEFEND');

        let owner_after_defend: Adventurer = world.read_model(owner_id);
        let claimant_after_defend: Adventurer = world.read_model(claimant_id);
        let state_after_defend: HexDecayState = world.read_model(hex_coordinate);
        let escrow_after_defend: ClaimEscrow = world.read_model(derive_hex_claim_id(hex_coordinate));
        assert(owner_after_defend.energy == 320_u16, 'S5_INT_BONUS_DEF_ENE');
        assert(claimant_after_defend.energy == 256_u16, 'S5_INT_BONUS_REFUND');
        assert(state_after_defend.current_energy_reserve == 180_u32, 'S5_INT_BONUS_RESV');
        assert(escrow_after_defend.status == ClaimEscrowStatus::Resolved, 'S5_INT_BONUS_ESC');
    }

    #[test]
    fn economic_manager_integration_failure_branches_convert_pay_and_initiate() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9601_felt252;
        let claimant_id = 9602_felt252;
        let hex_coordinate = 9700_felt252;
        setup_actor(ref world, owner_id, caller, 5_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 200_u16, hex_coordinate);

        world.write_model_test(@Inventory { adventurer_id: claimant_id, current_weight: 5_u32, max_weight: 100_u32 });
        world.write_model_test(
            @BackpackItem {
                adventurer_id: claimant_id,
                item_id: 101_felt252,
                quantity: 5_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 1_u8,
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
                claimable_since_block: 1_u64,
            },
        );

        let convert_zero = manager.convert_items_to_energy(claimant_id, 101_felt252, 0_u16);
        assert(convert_zero == 0_u16, 'S4_INT_FAIL_CONVERT_0');

        let pay_insufficient = manager.pay_hex_maintenance(owner_id, hex_coordinate, 50_u16);
        assert(!pay_insufficient, 'S4_INT_FAIL_PAY_INSUFF');

        let pay_invalid = manager.pay_hex_maintenance(owner_id, hex_coordinate, 0_u16);
        assert(!pay_invalid, 'S4_INT_FAIL_PAY_INV');

        let pay_not_controller = manager.pay_hex_maintenance(claimant_id, hex_coordinate, 5_u16);
        assert(!pay_not_controller, 'S4_INT_FAIL_PAY_CTRL');

        let below_minimum = manager.initiate_hex_claim(claimant_id, hex_coordinate, 1_u16);
        assert(!below_minimum, 'S4_INT_FAIL_CLAIM_MIN');
    }

    #[test]
    fn economic_manager_integration_settle_expired_invalid_claimant_row() {
        let caller = get_default_caller_address();
        set_block_number(200_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9611_felt252;
        let claimant_id = 9612_felt252;
        let hex_coordinate = 9710_felt252;
        setup_actor(ref world, owner_id, caller, 300_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 300_u16, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 1_u8,
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
                claimable_since_block: 1_u64,
            },
        );

        let claim_id = derive_hex_claim_id(hex_coordinate);
        world.write_model_test(
            @ClaimEscrow {
                claim_id,
                hex_coordinate,
                claimant_adventurer_id: 0_felt252,
                energy_locked: 55_u16,
                created_block: 10_u64,
                expiry_block: 100_u64,
                status: ClaimEscrowStatus::Active,
            },
        );

        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 0_u16);
        assert(!initiated, 'S4_INT_FAIL_ESCROW_CALL');
        let escrow_after: ClaimEscrow = world.read_model(claim_id);
        assert(escrow_after.status == ClaimEscrowStatus::Expired, 'S4_INT_FAIL_ESCROW_EXP');
        assert(escrow_after.energy_locked == 0_u16, 'S4_INT_FAIL_ESCROW_ZERO');
    }

    #[test]
    fn economic_manager_integration_defend_insufficient_and_not_controller() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9621_felt252;
        let claimant_id = 9622_felt252;
        let outsider_id = 9623_felt252;
        let hex_coordinate = 9720_felt252;
        setup_actor(ref world, owner_id, caller, 10_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 300_u16, hex_coordinate);
        setup_actor(ref world, outsider_id, caller, 300_u16, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 1_u8,
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
                claimable_since_block: 1_u64,
            },
        );

        let claim_id = derive_hex_claim_id(hex_coordinate);
        world.write_model_test(
            @ClaimEscrow {
                claim_id,
                hex_coordinate,
                claimant_adventurer_id: claimant_id,
                energy_locked: 150_u16,
                created_block: 0_u64,
                expiry_block: 100_u64,
                status: ClaimEscrowStatus::Active,
            },
        );

        let insufficient = manager.defend_hex_from_claim(owner_id, hex_coordinate, 150_u16);
        assert(!insufficient, 'S4_INT_DEF_INSUFF_FALSE');
        let owner_after: Adventurer = world.read_model(owner_id);
        assert(owner_after.energy == 10_u16, 'S4_INT_DEF_INSUFF_KEEP');

        let not_controller = manager.defend_hex_from_claim(outsider_id, hex_coordinate, 10_u16);
        assert(!not_controller, 'S4_INT_DEF_NOT_CTRL_FALSE');

        world.write_model_test(
            @Adventurer {
                adventurer_id: owner_id,
                owner: caller,
                name: 'DEAD'_felt252,
                energy: 10_u16,
                max_energy: 10_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: false,
            },
        );
        let dead_defender = manager.defend_hex_from_claim(owner_id, hex_coordinate, 1_u16);
        assert(!dead_defender, 'S4_INT_DEF_DEAD_FALSE');
    }

    #[test]
    fn economic_manager_integration_regression_claim_lock_blocks_double_spend_across_hexes() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9631_felt252;
        let claimant_id = 9632_felt252;
        let hex_a = 9731_felt252;
        let hex_b = 9732_felt252;
        setup_actor(ref world, owner_id, caller, 500_u16, hex_a);
        setup_actor(ref world, claimant_id, caller, 300_u16, hex_a);

        world.write_model_test(
            @Hex {
                coordinate: hex_a,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 1_u8,
            },
        );
        world.write_model_test(
            @Hex {
                coordinate: hex_b,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 1_u8,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate: hex_a,
                owner_adventurer_id: owner_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 85_u16,
                claimable_since_block: 1_u64,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate: hex_b,
                owner_adventurer_id: owner_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 85_u16,
                claimable_since_block: 1_u64,
            },
        );

        let first_claim = manager.initiate_hex_claim(claimant_id, hex_a, 250_u16);
        assert(first_claim, 'S4_INT_LOCK_FIRST');

        let second_claim = manager.initiate_hex_claim(claimant_id, hex_b, 100_u16);
        assert(!second_claim, 'S4_INT_LOCK_SECOND');

        let claimant_after: Adventurer = world.read_model(claimant_id);
        assert(claimant_after.energy == 50_u16, 'S4_INT_LOCK_ENERGY');

        let claim_a = derive_hex_claim_id(hex_a);
        let claim_b = derive_hex_claim_id(hex_b);
        let escrow_a: ClaimEscrow = world.read_model(claim_a);
        let escrow_b: ClaimEscrow = world.read_model(claim_b);
        assert(escrow_a.status == ClaimEscrowStatus::Active, 'S4_INT_LOCK_A_ST');
        assert(escrow_a.energy_locked == 250_u16, 'S4_INT_LOCK_A_LOCK');
        assert(escrow_a.claimant_adventurer_id == claimant_id, 'S4_INT_LOCK_A_CLAIMANT');
        assert(escrow_b.status == ClaimEscrowStatus::Inactive, 'S4_INT_LOCK_B_ST');
        assert(escrow_b.energy_locked == 0_u16, 'S4_INT_LOCK_B_LOCK');
    }
}
