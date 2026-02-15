#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use dojo_starter::events::construction_events::{ConstructionRejected, ConstructionStarted};
    use dojo_starter::libs::construction_balance::{
        B_SMELTER, B_WORKSHOP, I_PLANT_FIBER, build_time_blocks_for_building,
        energy_stake_for_building, timed_params_for_building,
    };
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::construction::{ConstructionBuildingNode, ConstructionProject, ConstructionProjectStatus};
    use dojo_starter::models::inventory::BackpackItem;
    use dojo_starter::models::world::{Biome, Hex, derive_area_id};
    use dojo_starter::systems::construction_manager_contract::{
        IConstructionManagerDispatcher, IConstructionManagerDispatcherTrait,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("BackpackItem"),
                TestResource::Model("ConstructionProject"),
                TestResource::Model("ConstructionBuildingNode"),
                TestResource::Model("ConstructionMaterialEscrow"),
                TestResource::Model("Hex"),
                TestResource::Event("ConstructionStarted"),
                TestResource::Event("ConstructionCompleted"),
                TestResource::Event("ConstructionUpkeepPaid"),
                TestResource::Event("ConstructionRepaired"),
                TestResource::Event("ConstructionUpgradeQueued"),
                TestResource::Event("ConstructionPlantProcessed"),
                TestResource::Event("ConstructionRejected"),
                TestResource::Contract("construction_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"construction_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn seed_actor(
        ref world: dojo::world::WorldStorage, adventurer_id: felt252, owner: starknet::ContractAddress,
        energy: u16, current_hex: felt252,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'BUILDER'_felt252,
                energy,
                max_energy: 500_u16,
                current_hex,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
    }

    #[test]
    fn construction_manager_integration_start_complete_upkeep_repair_inspect() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"construction_manager").unwrap();
        let manager = IConstructionManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let adventurer_id = 8101_felt252;
        let hex_coordinate = 9101_felt252;
        let area_id = 9102_felt252;
        seed_actor(ref world, adventurer_id, caller, 220_u16, hex_coordinate);

        set_block_number(100_u64);
        let project_id = manager.start_construction(adventurer_id, hex_coordinate, area_id, B_SMELTER);
        assert(project_id != 0_felt252, 'C3_INT_START_PID');

        let project: ConstructionProject = world.read_model(project_id);
        let after_start: Adventurer = world.read_model(adventurer_id);
        assert(project.status == ConstructionProjectStatus::Active, 'C3_INT_START_STAT');
        assert(after_start.energy == 180_u16, 'C3_INT_START_ENE');
        assert(after_start.activity_locked_until == 220_u64, 'C3_INT_START_LOCK');

        set_block_number(220_u64);
        let completed = manager.complete_construction(adventurer_id, project_id);
        assert(completed, 'C3_INT_DONE_OK');

        let building: ConstructionBuildingNode = world.read_model(area_id);
        let after_done: Adventurer = world.read_model(adventurer_id);
        assert(building.area_id == area_id, 'C3_INT_DONE_AREA');
        assert(building.hex_coordinate == hex_coordinate, 'C3_INT_DONE_HEX');
        assert(building.building_type == B_SMELTER, 'C3_INT_DONE_BLD');
        assert(building.tier == 1_u8, 'C3_INT_DONE_TIER');
        assert(building.condition_bp == 10_000_u16, 'C3_INT_DONE_COND');
        assert(building.is_active, 'C3_INT_DONE_ACTIVE');
        assert(after_done.activity_locked_until == 220_u64, 'C3_INT_DONE_UNLOCK');

        let upkeep_ok = manager.pay_building_upkeep(adventurer_id, hex_coordinate, area_id, 9_u16);
        assert(upkeep_ok, 'C3_INT_PAY_OK');
        let after_upkeep: Adventurer = world.read_model(adventurer_id);
        let after_upkeep_building: ConstructionBuildingNode = world.read_model(area_id);
        assert(after_upkeep.energy == 171_u16, 'C3_INT_PAY_ENE');
        assert(after_upkeep_building.upkeep_reserve == 9_u32, 'C3_INT_PAY_RSV');

        let repair_ok = manager.repair_building(adventurer_id, hex_coordinate, area_id, 5_u16);
        assert(repair_ok, 'C3_INT_REPAIR_OK');
        let after_repair: Adventurer = world.read_model(adventurer_id);
        let inspected = manager.inspect_building(hex_coordinate, area_id);
        assert(after_repair.energy == 166_u16, 'C3_INT_REPAIR_ENE');
        assert(inspected.area_id == area_id, 'C3_INT_INSPECT_AREA');
        assert(inspected.building_type == B_SMELTER, 'C3_INT_INSPECT_BLD');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let started_selector = Event::<ConstructionStarted>::selector(world.namespace_hash);
        let mut started_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @started_selector {
                started_count += 1;
            }
            idx += 1;
        };
        assert(started_count == 1_usize, 'C3_INT_EVT_START1');
    }

    #[test]
    fn construction_manager_integration_workshop_discount_and_time_cut_apply() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"construction_manager").unwrap();
        let manager = IConstructionManagerDispatcher { contract_address };

        let adventurer_id = 8151_felt252;
        let hex_coordinate = 9151_felt252;
        let workshop_area_id = derive_area_id(hex_coordinate, 0_u8);
        let target_area_id = derive_area_id(hex_coordinate, 1_u8);
        seed_actor(ref world, adventurer_id, caller, 300_u16, hex_coordinate);
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
            @ConstructionBuildingNode {
                area_id: workshop_area_id,
                hex_coordinate,
                owner_adventurer_id: adventurer_id,
                building_type: B_WORKSHOP,
                tier: 1_u8,
                condition_bp: 10_000_u16,
                upkeep_reserve: 0_u32,
                last_upkeep_block: 0_u64,
                is_active: true,
            },
        );

        assert(energy_stake_for_building(B_SMELTER) == 40_u16, 'C4_WK_STAKE_BASE');
        assert(build_time_blocks_for_building(B_SMELTER) == 120_u64, 'C4_WK_TIME_BASE');
        let (discount_bp, time_cut_bp) = timed_params_for_building(B_WORKSHOP);
        assert(discount_bp == 1_200_u16, 'C4_WK_DISCOUNT_BP');
        assert(time_cut_bp == 1_800_u16, 'C4_WK_TIMECUT_BP');

        set_block_number(500_u64);
        let project_id = manager.start_construction(
            adventurer_id, hex_coordinate, target_area_id, B_SMELTER,
        );
        assert(project_id != 0_felt252, 'C4_WK_START_PID');

        let project: ConstructionProject = world.read_model(project_id);
        let after_start: Adventurer = world.read_model(adventurer_id);
        assert(project.energy_staked == 35_u16, 'C4_WK_STAKE_DISC');
        assert(project.start_block == 500_u64, 'C4_WK_START_BLOCK');
        assert(project.completion_block == 598_u64, 'C4_WK_TIME_DISC');
        assert(after_start.energy == 265_u16, 'C4_WK_ENERGY');
        assert(after_start.activity_locked_until == 598_u64, 'C4_WK_LOCK');
    }

    #[test]
    fn construction_manager_integration_process_plants_and_reject_wrong_owner() {
        let caller = get_default_caller_address();
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"construction_manager").unwrap();
        let manager = IConstructionManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let adventurer_id = 8201_felt252;
        let hex_coordinate = 9201_felt252;
        seed_actor(ref world, adventurer_id, caller, 120_u16, hex_coordinate);
        world.write_model_test(
            @BackpackItem {
                adventurer_id,
                item_id: 'HERB_RAW'_felt252,
                quantity: 25_u32,
                quality: 100_u16,
                weight_per_unit: 1_u16,
            },
        );

        let output = manager.process_plant_material(
            adventurer_id, 'HERB_RAW'_felt252, 15_u16, I_PLANT_FIBER,
        );
        assert(output == 15_u16, 'C3_INT_PROC_OUT');
        let source_after: BackpackItem = world.read_model((adventurer_id, 'HERB_RAW'_felt252));
        let target_after: BackpackItem = world.read_model((adventurer_id, I_PLANT_FIBER));
        assert(source_after.quantity == 10_u32, 'C3_INT_PROC_SRC');
        assert(target_after.quantity == 15_u32, 'C3_INT_PROC_TGT');

        let foreign_owner: starknet::ContractAddress = 0x999.try_into().unwrap();
        let foreign_id = 8202_felt252;
        seed_actor(ref world, foreign_id, foreign_owner, 200_u16, hex_coordinate);
        set_block_number(10_u64);
        let rejected_project = manager.start_construction(foreign_id, hex_coordinate, 9202_felt252, B_SMELTER);
        assert(rejected_project == 0_felt252, 'C3_INT_REJECT_RET');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let rejected_selector = Event::<ConstructionRejected>::selector(world.namespace_hash);
        let mut rejected_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @rejected_selector {
                rejected_count += 1;
            }
            idx += 1;
        };
        assert(rejected_count >= 1_usize, 'C3_INT_REJECT_EVT');
    }
}
