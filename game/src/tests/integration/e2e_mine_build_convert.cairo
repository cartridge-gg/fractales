#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use dojo_starter::libs::construction_balance::{B_SMELTER, I_ORE_IRON};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::construction::ConstructionProject;
    use dojo_starter::models::economics::{AdventurerEconomics, ConversionRate};
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::mining::{MineNode, MiningShift, derive_mine_key, derive_mining_shift_id};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{AreaType, Biome, Hex, HexArea, SizeCategory, derive_area_id};
    use dojo_starter::systems::construction_manager_contract::{
        IConstructionManagerDispatcher, IConstructionManagerDispatcherTrait,
    };
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
    use dojo_starter::systems::mining_manager_contract::{
        IMiningManagerDispatcher, IMiningManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Model("Inventory"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("ConversionRate"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("MineNode"),
                TestResource::Model("MiningShift"),
                TestResource::Model("MineAccessGrant"),
                TestResource::Model("MineCollapseRecord"),
                TestResource::Model("ConstructionProject"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Model("ConstructionMaterialEscrow"),
                TestResource::Event("MineInitialized"),
                TestResource::Event("MiningStarted"),
                TestResource::Event("MiningExited"),
                TestResource::Event("ConstructionStarted"),
                TestResource::Event("ConstructionCompleted"),
                TestResource::Event("ItemsConverted"),
                TestResource::Contract("mining_manager"),
                TestResource::Contract("construction_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"mining_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"construction_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"economic_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        hex_coordinate: felt252,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'C5MINE'_felt252,
                energy: 500_u16,
                max_energy: 1_000_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: 500_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
        world.write_model_test(
            @Inventory {
                adventurer_id,
                current_weight: 0_u32,
                max_weight: 100_u32,
            },
        );
    }

    #[test]
    fn e2e_07_mine_build_convert_progression_applies_smelter_bonus() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (mining_address, _) = world.dns(@"mining_manager").unwrap();
        let mining = IMiningManagerDispatcher { contract_address: mining_address };
        let (construction_address, _) = world.dns(@"construction_manager").unwrap();
        let construction = IConstructionManagerDispatcher { contract_address: construction_address };
        let (economic_address, _) = world.dns(@"economic_manager").unwrap();
        let economic = IEconomicManagerDispatcher { contract_address: economic_address };

        let adventurer_id = 9971_felt252;
        let hex_coordinate = 10_171_felt252;
        let mine_area_id = derive_area_id(hex_coordinate, 0_u8);
        let smelter_area_id = derive_area_id(hex_coordinate, 1_u8);
        let mine_id = 0_u8;
        let mine_key = derive_mine_key(hex_coordinate, mine_area_id, mine_id);
        let shift_id = derive_mining_shift_id(adventurer_id, mine_key);
        setup_actor(ref world, adventurer_id, caller, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Mountain,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 3_u8,
            },
        );
        world.write_model_test(
            @HexArea {
                area_id: mine_area_id,
                hex_coordinate,
                area_index: 0_u8,
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
                area_id: mine_area_id,
                owner_adventurer_id: adventurer_id,
                discoverer_adventurer_id: adventurer_id,
                discovery_block: 1_u64,
                claim_block: 1_u64,
            },
        );

        let initialized = mining.init_mining(hex_coordinate, mine_area_id, mine_id);
        assert(initialized, 'C5_MBC_INIT');

        let seeded_mine: MineNode = world.read_model(mine_key);
        world.write_model_test(
            @MineNode {
                ore_id: I_ORE_IRON,
                conversion_energy_per_unit: 8_u16,
                ..seeded_mine
            },
        );

        let started = mining.start_mining(adventurer_id, hex_coordinate, mine_area_id, mine_id);
        assert(started, 'C5_MBC_START');
        let seeded_shift: MiningShift = world.read_model(shift_id);
        world.write_model_test(@MiningShift { accrued_ore_unbanked: 10_u32, ..seeded_shift });

        let minted = mining.exit_mining(adventurer_id, mine_key);
        assert(minted == 10_u16, 'C5_MBC_EXIT');
        let mined_item: BackpackItem = world.read_model((adventurer_id, I_ORE_IRON));
        assert(mined_item.quantity == 10_u32, 'C5_MBC_QTY10');

        world.write_model_test(
            @ConversionRate {
                item_type: I_ORE_IRON,
                base_rate: 8_u16,
                current_rate: 8_u16,
                last_update_block: 0_u64,
                units_converted_in_window: 0_u32,
            },
        );
        set_block_number(50_u64);
        let pre_build_gain = economic.convert_items_to_energy(adventurer_id, I_ORE_IRON, 1_u16);
        assert(pre_build_gain == 8_u16, 'C5_MBC_BASE_GAIN');

        set_block_number(60_u64);
        let project_id = construction.start_construction(
            adventurer_id, hex_coordinate, smelter_area_id, B_SMELTER,
        );
        assert(project_id != 0_felt252, 'C5_MBC_PROJ');

        let project: ConstructionProject = world.read_model(project_id);
        set_block_number(project.completion_block);
        let completed = construction.complete_construction(adventurer_id, project_id);
        assert(completed, 'C5_MBC_DONE');

        world.write_model_test(
            @ConversionRate {
                item_type: I_ORE_IRON,
                base_rate: 8_u16,
                current_rate: 8_u16,
                last_update_block: 0_u64,
                units_converted_in_window: 0_u32,
            },
        );
        set_block_number(300_u64);
        let post_build_gain = economic.convert_items_to_energy(adventurer_id, I_ORE_IRON, 1_u16);
        assert(post_build_gain > pre_build_gain, 'C5_MBC_BONUS');
    }
}
