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
    use dojo_starter::models::deaths::DeathRecord;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::inventory::Inventory;
    use dojo_starter::systems::adventurer_manager_contract::{
        IAdventurerManagerDispatcher, IAdventurerManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("Inventory"),
                TestResource::Model("DeathRecord"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Event("AdventurerCreated"),
                TestResource::Event("AdventurerDied"),
                TestResource::Contract("adventurer_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"adventurer_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn encoded_origin() -> felt252 {
        match encode_cube(CubeCoord { x: 0, y: 0, z: 0 }) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'S2_ORIGIN_NONE');
                0
            },
        }
    }

    fn seed_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        energy: u16,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'SEED'_felt252,
                energy,
                max_energy: 100_u16,
                current_hex: encoded_origin(),
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
            @Inventory { adventurer_id, current_weight: 0_u32, max_weight: 750_u32 },
        );
    }

    #[test]
    fn adventurer_manager_integration_create_regen_consume_and_kill() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"adventurer_manager").unwrap();
        let manager = IAdventurerManagerDispatcher { contract_address };

        let adventurer_id = manager.create_adventurer('HERO'_felt252);
        let created: Adventurer = world.read_model(adventurer_id);
        let inventory: Inventory = world.read_model(adventurer_id);
        let economics: AdventurerEconomics = world.read_model(adventurer_id);

        assert(created.owner == caller, 'S2_INT_OWNER');
        assert(created.energy == 100_u16, 'S2_INT_ENE');
        assert(created.current_hex == encoded_origin(), 'S2_INT_ORIGIN');
        assert(inventory.current_weight == 0_u32, 'S2_INT_INV0');
        assert(economics.last_regen_block == 100_u64, 'S2_INT_REGEN_B0');

        let consumed = manager.consume_energy(adventurer_id, 30_u16);
        assert(consumed, 'S2_INT_CONSUME_OK');
        let after_consume: Adventurer = world.read_model(adventurer_id);
        assert(after_consume.energy == 70_u16, 'S2_INT_CONSUME_ENE');

        set_block_number(200_u64);
        let regen_energy = manager.regenerate_energy(adventurer_id);
        assert(regen_energy == 90_u16, 'S2_INT_REGEN_RET');
        let after_regen: Adventurer = world.read_model(adventurer_id);
        assert(after_regen.energy == 90_u16, 'S2_INT_REGEN_ENE');

        world.write_model_test(
            @Inventory { adventurer_id, current_weight: 55_u32, max_weight: 750_u32 },
        );
        let killed = manager.kill_adventurer(adventurer_id, 'FALL'_felt252);
        assert(killed, 'S2_INT_KILL_OK');

        let dead: Adventurer = world.read_model(adventurer_id);
        let post_inventory: Inventory = world.read_model(adventurer_id);
        let record: DeathRecord = world.read_model(adventurer_id);
        assert(!dead.is_alive, 'S2_INT_DEAD');
        assert(post_inventory.current_weight == 0_u32, 'S2_INT_INV_CLR');
        assert(record.death_cause == 'FALL'_felt252, 'S2_INT_DEATH_CAUSE');

        let blocked = manager.consume_energy(adventurer_id, 1_u16);
        assert(!blocked, 'S2_INT_DEAD_BLOCK');
    }

    #[test]
    fn adventurer_manager_integration_consume_insufficient_and_kill_replay_returns_false() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"adventurer_manager").unwrap();
        let manager = IAdventurerManagerDispatcher { contract_address };

        let adventurer_id = 29001_felt252;
        seed_actor(ref world, adventurer_id, caller, 5_u16);

        let insufficient = manager.consume_energy(adventurer_id, 50_u16);
        assert(!insufficient, 'S2_INT_INSUFF_FALSE');
        let after_insufficient: Adventurer = world.read_model(adventurer_id);
        let econ_after_insufficient: AdventurerEconomics = world.read_model(adventurer_id);
        assert(after_insufficient.energy == 5_u16, 'S2_INT_INSUFF_ENE');
        assert(econ_after_insufficient.energy_balance == 5_u16, 'S2_INT_INSUFF_BAL');

        let killed_once = manager.kill_adventurer(adventurer_id, 'REPLAY'_felt252);
        assert(killed_once, 'S2_INT_KILL_ONCE');
        let killed_twice = manager.kill_adventurer(adventurer_id, 'REPLAY'_felt252);
        assert(!killed_twice, 'S2_INT_KILL_REPLAY_FALSE');

        let foreign_owner: starknet::ContractAddress = 0x999.try_into().unwrap();
        let foreign_id = 29002_felt252;
        seed_actor(ref world, foreign_id, foreign_owner, 50_u16);

        let not_owner_consume = manager.consume_energy(foreign_id, 1_u16);
        assert(!not_owner_consume, 'S2_INT_NOT_OWNER_CONSUME');

        let not_owner_kill = manager.kill_adventurer(foreign_id, 'DENY'_felt252);
        assert(!not_owner_kill, 'S2_INT_NOT_OWNER_KILL');
    }
}
