#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use dojo_starter::libs::construction_balance::{
        B_GREENHOUSE, B_STOREHOUSE, I_PLANT_FIBER,
    };
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::construction::ConstructionProject;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{derive_harvest_item_id, derive_plant_key};
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::world::{AreaType, Biome, Hex, HexArea, SizeCategory, derive_area_id};
    use dojo_starter::systems::construction_manager_contract::{
        IConstructionManagerDispatcher, IConstructionManagerDispatcherTrait,
    };
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
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
                TestResource::Model("ConversionRate"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("ConstructionProject"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Model("ConstructionMaterialEscrow"),
                TestResource::Model("PlantNode"),
                TestResource::Model("HarvestReservation"),
                TestResource::Event("HarvestingStarted"),
                TestResource::Event("HarvestingCompleted"),
                TestResource::Event("ConstructionPlantProcessed"),
                TestResource::Event("ConstructionStarted"),
                TestResource::Event("ConstructionCompleted"),
                TestResource::Event("ItemsConverted"),
                TestResource::Contract("harvesting_manager"),
                TestResource::Contract("construction_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"harvesting_manager")
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
                name: 'C5HARV'_felt252,
                energy: 800_u16,
                max_energy: 1_000_u16,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: 800_u16,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
        world.write_model_test(
            @Inventory {
                adventurer_id,
                current_weight: 0_u32,
                max_weight: 10_u32,
            },
        );
    }

    #[test]
    fn e2e_08_harvest_process_build_progression_applies_greenhouse_and_storehouse() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (harvest_address, _) = world.dns(@"harvesting_manager").unwrap();
        let harvesting = IHarvestingManagerDispatcher { contract_address: harvest_address };
        let (construction_address, _) = world.dns(@"construction_manager").unwrap();
        let construction = IConstructionManagerDispatcher { contract_address: construction_address };
        let (economic_address, _) = world.dns(@"economic_manager").unwrap();
        let economic = IEconomicManagerDispatcher { contract_address: economic_address };

        let adventurer_id = 9981_felt252;
        let hex_coordinate = 10_281_felt252;
        let plant_area_id = derive_area_id(hex_coordinate, 0_u8);
        let greenhouse_area_id = derive_area_id(hex_coordinate, 1_u8);
        let storehouse_area_id = derive_area_id(hex_coordinate, 2_u8);
        let plant_id = 1_u8;
        setup_actor(ref world, adventurer_id, caller, hex_coordinate);

        world.write_model_test(
            @Hex {
                coordinate: hex_coordinate,
                biome: Biome::Forest,
                is_discovered: true,
                discovery_block: 1_u64,
                discoverer: caller,
                area_count: 4_u8,
            },
        );
        world.write_model_test(
            @HexArea {
                area_id: plant_area_id,
                hex_coordinate,
                area_index: 0_u8,
                area_type: AreaType::PlantField,
                is_discovered: true,
                discoverer: caller,
                resource_quality: 70_u16,
                size_category: SizeCategory::Medium,
                plant_slot_count: 8_u8,
            },
        );

        let initialized = harvesting.init_harvesting(hex_coordinate, plant_area_id, plant_id);
        assert(initialized, 'C5_HPB_INIT');

        let first_started = harvesting.start_harvesting(
            adventurer_id, hex_coordinate, plant_area_id, plant_id, 12_u16,
        );
        assert(first_started, 'C5_HPB_FIRST_START');
        set_block_number(24_u64);
        let first_completed = harvesting.complete_harvesting(
            adventurer_id, hex_coordinate, plant_area_id, plant_id,
        );
        assert(first_completed == 12_u16, 'C5_HPB_FIRST_RET');

        let plant_key = derive_plant_key(hex_coordinate, plant_area_id, plant_id);
        let harvest_item_id = derive_harvest_item_id(plant_key);
        let first_item: BackpackItem = world.read_model((adventurer_id, harvest_item_id));
        let first_inventory: Inventory = world.read_model(adventurer_id);
        assert(first_item.quantity == 10_u32, 'C5_HPB_BASE_QTY');
        assert(first_inventory.current_weight == 10_u32, 'C5_HPB_BASE_CAP');

        let processed = construction.process_plant_material(
            adventurer_id, harvest_item_id, 2_u16, I_PLANT_FIBER,
        );
        assert(processed == 2_u16, 'C5_HPB_PROCESS');

        let converted_source = economic.convert_items_to_energy(adventurer_id, harvest_item_id, 8_u16);
        assert(converted_source > 0_u16, 'C5_HPB_CONV_SRC');
        let converted_fiber = economic.convert_items_to_energy(adventurer_id, I_PLANT_FIBER, 2_u16);
        assert(converted_fiber > 0_u16, 'C5_HPB_CONV_FIB');

        let inventory_after_clear: Inventory = world.read_model(adventurer_id);
        assert(inventory_after_clear.current_weight == 0_u32, 'C5_HPB_CLR');

        set_block_number(100_u64);
        let greenhouse_project_id = construction.start_construction(
            adventurer_id, hex_coordinate, greenhouse_area_id, B_GREENHOUSE,
        );
        assert(greenhouse_project_id != 0_felt252, 'C5_HPB_GH_PROJ');
        let greenhouse_project: ConstructionProject = world.read_model(greenhouse_project_id);
        set_block_number(greenhouse_project.completion_block);
        let greenhouse_done = construction.complete_construction(adventurer_id, greenhouse_project_id);
        assert(greenhouse_done, 'C5_HPB_GH_DONE');

        set_block_number(greenhouse_project.completion_block + 1_u64);
        let storehouse_project_id = construction.start_construction(
            adventurer_id, hex_coordinate, storehouse_area_id, B_STOREHOUSE,
        );
        assert(storehouse_project_id != 0_felt252, 'C5_HPB_SH_PROJ');
        let storehouse_project: ConstructionProject = world.read_model(storehouse_project_id);
        set_block_number(storehouse_project.completion_block);
        let storehouse_done = construction.complete_construction(adventurer_id, storehouse_project_id);
        assert(storehouse_done, 'C5_HPB_SH_DONE');

        set_block_number(320_u64);
        let second_started = harvesting.start_harvesting(
            adventurer_id, hex_coordinate, plant_area_id, plant_id, 10_u16,
        );
        assert(second_started, 'C5_HPB_SECOND_START');
        set_block_number(340_u64);
        let second_completed = harvesting.complete_harvesting(
            adventurer_id, hex_coordinate, plant_area_id, plant_id,
        );
        assert(second_completed == 10_u16, 'C5_HPB_SECOND_RET');

        let second_item: BackpackItem = world.read_model((adventurer_id, harvest_item_id));
        let second_inventory: Inventory = world.read_model(adventurer_id);
        assert(second_item.quantity > 10_u32, 'C5_HPB_BONUS_QTY');
        assert(second_inventory.current_weight > 10_u32, 'C5_HPB_BONUS_CAP');
    }
}
