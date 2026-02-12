#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{AdventurerEconomics, HexDecayState};
    use dojo_starter::models::harvesting::PlantNode;
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::world::{Biome, Hex, derive_area_id};
    use dojo_starter::systems::adventurer_manager_contract::{
        IAdventurerManagerDispatcher, IAdventurerManagerDispatcherTrait,
    };
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
    use dojo_starter::systems::harvesting_manager_contract::{
        IHarvestingManagerDispatcher, IHarvestingManagerDispatcherTrait,
    };
    use dojo_starter::systems::world_manager_contract::{
        IWorldManagerDispatcher, IWorldManagerDispatcherTrait,
    };
    use dojo_starter::models::harvesting::derive_plant_key;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Model("Inventory"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("Hex"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("HexDecayState"),
                TestResource::Model("PlantNode"),
                TestResource::Model("HarvestReservation"),
                TestResource::Model("ClaimEscrow"),
                TestResource::Model("DeathRecord"),
                TestResource::Model("ConversionRate"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("AdventurerDied"),
                TestResource::Contract("adventurer_manager"),
                TestResource::Contract("world_manager"),
                TestResource::Contract("harvesting_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"adventurer_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
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
                assert(1 == 0, 'S6_E2E4_ENC');
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
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'S6C'_felt252,
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
        world.write_model_test(
            @Inventory { adventurer_id, current_weight: 9_u32, max_weight: 100_u32 },
        );
        world.write_model_test(
            @BackpackItem {
                adventurer_id,
                item_id: 777_felt252,
                quantity: 5_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );
    }

    #[test]
    fn e2e_04_permadeath_blocks_all_state_changing_actions() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (adventurer_address, _) = world.dns(@"adventurer_manager").unwrap();
        let adventurer_manager = IAdventurerManagerDispatcher { contract_address: adventurer_address };
        let (world_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_address };
        let (harvest_address, _) = world.dns(@"harvesting_manager").unwrap();
        let harvesting_manager = IHarvestingManagerDispatcher { contract_address: harvest_address };
        let (economic_address, _) = world.dns(@"economic_manager").unwrap();
        let economic_manager = IEconomicManagerDispatcher { contract_address: economic_address };

        let adventurer_id = 9991_felt252;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_actor(ref world, adventurer_id, caller, 200_u16, origin);
        world.write_model_test(
            @Hex {
                coordinate: target,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 3_u8,
            },
        );
        world.write_model_test(
            @HexDecayState {
                hex_coordinate: target,
                owner_adventurer_id: adventurer_id,
                current_energy_reserve: 0_u32,
                last_energy_payment_block: 0_u64,
                last_decay_processed_block: 0_u64,
                decay_level: 85_u16,
                claimable_since_block: 1_u64,
            },
        );

        let area_id = derive_area_id(target, 0_u8);
        world_manager.discover_area(adventurer_id, target, 0_u8);
        let inited = harvesting_manager.init_harvesting(target, area_id, 1_u8);
        assert(inited, 'S6_E2E4_INIT');

        let killed = adventurer_manager.kill_adventurer(adventurer_id, 'TEST'_felt252);
        assert(killed, 'S6_E2E4_KILL');
        let dead: Adventurer = world.read_model(adventurer_id);
        let inv_after_kill: Inventory = world.read_model(adventurer_id);
        assert(!dead.is_alive, 'S6_E2E4_DEAD');
        assert(inv_after_kill.current_weight == 0_u32, 'S6_E2E4_INV_CLR');

        let consume_blocked = adventurer_manager.consume_energy(adventurer_id, 1_u16);
        assert(!consume_blocked, 'S6_E2E4_CONSUME_BLOCK');

        world_manager.move_adventurer(adventurer_id, target);
        world_manager.discover_hex(adventurer_id, target);
        let after_world: Adventurer = world.read_model(adventurer_id);
        assert(after_world.current_hex == origin, 'S6_E2E4_MOVE_BLOCK');

        let started = harvesting_manager.start_harvesting(adventurer_id, target, area_id, 1_u8, 2_u16);
        assert(!started, 'S6_E2E4_START_BLOCK');
        let plant_key = derive_plant_key(target, area_id, 1_u8);
        let plant: PlantNode = world.read_model(plant_key);
        assert(plant.reserved_yield == 0_u16, 'S6_E2E4_RESV_BLOCK');

        let converted = economic_manager.convert_items_to_energy(adventurer_id, 777_felt252, 1_u16);
        assert(converted == 0_u16, 'S6_E2E4_CONVERT_BLOCK');
        let paid = economic_manager.pay_hex_maintenance(adventurer_id, target, 20_u16);
        assert(!paid, 'S6_E2E4_PAY_BLOCK');
        let claimed = economic_manager.initiate_hex_claim(adventurer_id, target, 100_u16);
        assert(!claimed, 'S6_E2E4_CLAIM_BLOCK');
    }
}
