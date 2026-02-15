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
    use dojo_starter::events::economic_events::{
        ClaimExpired, ClaimInitiated, ClaimRefunded, HexBecameClaimable, HexDefended,
    };
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{
        AdventurerEconomics, ClaimEscrow, ClaimEscrowStatus, HexDecayState, derive_hex_claim_id,
    };
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
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexDecayState"),
                TestResource::Model("ClaimEscrow"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("ConstructionBuildingNode"),
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
                name: 'S6B'_felt252,
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
    fn e2e_02_neglect_claimable_claim_then_defend_within_grace() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let mut spy = spy_events();

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9901_felt252;
        let claimant_id = 9902_felt252;
        let hex_coordinate = 9950_felt252;
        setup_actor(ref world, owner_id, caller, 450_u16, hex_coordinate);
        setup_actor(ref world, claimant_id, caller, 500_u16, hex_coordinate);
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
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 79_u16,
                claimable_since_block: 0_u64,
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

        set_block_number(200_u64);
        let decay_level = manager.process_hex_decay(hex_coordinate);
        assert(decay_level >= 80_u16, 'S6_E2E2_DECAY');
        let state_claimable: HexDecayState = world.read_model(hex_coordinate);
        assert(state_claimable.claimable_since_block == 200_u64, 'S6_E2E2_CLAIMABLE');

        set_block_number(250_u64);
        let initiated = manager.initiate_hex_claim(claimant_id, hex_coordinate, 200_u16);
        assert(initiated, 'S6_E2E2_CLAIM');
        let claim_id = derive_hex_claim_id(hex_coordinate);
        let escrow_started: ClaimEscrow = world.read_model(claim_id);
        assert(escrow_started.status == ClaimEscrowStatus::Active, 'S6_E2E2_ESCROW');

        set_block_number(260_u64);
        let defended = manager.defend_hex_from_claim(owner_id, hex_coordinate, 200_u16);
        assert(defended, 'S6_E2E2_DEFEND');
        let escrow_done: ClaimEscrow = world.read_model(claim_id);
        let state_done: HexDecayState = world.read_model(hex_coordinate);
        let claimant_done: Adventurer = world.read_model(claimant_id);
        assert(escrow_done.status == ClaimEscrowStatus::Resolved, 'S6_E2E2_ESCROW_DONE');
        assert(state_done.owner_adventurer_id == owner_id, 'S6_E2E2_OWNER');
        assert(claimant_done.energy == 500_u16, 'S6_E2E2_REFUND');

        let row0: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 0_u8));
        let row1: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 1_u8));
        let row2: AreaOwnership = world.read_model(derive_area_id(hex_coordinate, 2_u8));
        assert(row0.owner_adventurer_id == owner_id, 'S6_E2E2_ROW0');
        assert(row1.owner_adventurer_id == owner_id, 'S6_E2E2_ROW1');
        assert(row2.owner_adventurer_id == owner_id, 'S6_E2E2_ROW2');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let claimable_selector = Event::<HexBecameClaimable>::selector(world.namespace_hash);
        let claim_selector = Event::<ClaimInitiated>::selector(world.namespace_hash);
        let refund_selector = Event::<ClaimRefunded>::selector(world.namespace_hash);
        let defend_selector = Event::<HexDefended>::selector(world.namespace_hash);
        let expired_selector = Event::<ClaimExpired>::selector(world.namespace_hash);
        let transferred_selector = Event::<OwnershipTransferred>::selector(world.namespace_hash);

        let mut claimable_count: usize = 0;
        let mut claim_count: usize = 0;
        let mut refund_count: usize = 0;
        let mut defend_count: usize = 0;
        let mut expired_count: usize = 0;
        let mut transferred_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @claimable_selector {
                    claimable_count += 1;
                } else if event.keys.at(1) == @claim_selector {
                    claim_count += 1;
                } else if event.keys.at(1) == @refund_selector {
                    refund_count += 1;
                } else if event.keys.at(1) == @defend_selector {
                    defend_count += 1;
                } else if event.keys.at(1) == @expired_selector {
                    expired_count += 1;
                } else if event.keys.at(1) == @transferred_selector {
                    transferred_count += 1;
                }
            }
            idx += 1;
        };

        assert(claimable_count == 1_usize, 'S6_E2E2_EVT_CLAIMABLE');
        assert(claim_count == 1_usize, 'S6_E2E2_EVT_CLAIM');
        assert(refund_count == 1_usize, 'S6_E2E2_EVT_REFUND');
        assert(defend_count == 1_usize, 'S6_E2E2_EVT_DEFEND');
        assert(expired_count == 0_usize, 'S6_E2E2_EVT_EXPIRED');
        assert(transferred_count == 0_usize, 'S6_E2E2_EVT_XFER');
    }

    #[test]
    fn e2e_06_decay_processing_idempotent_same_window() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"economic_manager").unwrap();
        let manager = IEconomicManagerDispatcher { contract_address };

        let owner_id = 9911_felt252;
        let hex_coordinate = 9960_felt252;
        setup_actor(ref world, owner_id, caller, 300_u16, hex_coordinate);
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
                current_energy_reserve: 50_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 0_u16,
                claimable_since_block: 0_u64,
            },
        );

        set_block_number(250_u64);
        let first = manager.process_hex_decay(hex_coordinate);
        let first_state: HexDecayState = world.read_model(hex_coordinate);
        let second = manager.process_hex_decay(hex_coordinate);
        let second_state: HexDecayState = world.read_model(hex_coordinate);

        assert(first == first_state.decay_level, 'S6_E2E6_FIRST_RET');
        assert(second == first_state.decay_level, 'S6_E2E6_SECOND_RET');
        assert(second_state.current_energy_reserve == first_state.current_energy_reserve, 'S6_E2E6_RESV');
        assert(
            second_state.last_decay_processed_block == first_state.last_decay_processed_block,
            'S6_E2E6_CKP',
        );
    }
}
