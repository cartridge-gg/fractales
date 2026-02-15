#[cfg(test)]
mod tests {
    use dojo_starter::libs::construction_balance::B_SMELTER;
    use dojo_starter::models::construction::{ConstructionBuildingNode, ConstructionProject, ConstructionProjectStatus};
    use dojo_starter::systems::construction_manager::{
        ConstructionCheckpointOutcome, ConstructionCompleteOutcome, ConstructionStartOutcome,
        checkpoint_building_transition, complete_project_transition, pay_building_upkeep_transition,
        repair_building_transition,
        start_project_transition,
    };

    #[test]
    fn construction_manager_start_applies_and_locks_energy() {
        let project = ConstructionProject {
            project_id: 0_felt252,
            adventurer_id: 0_felt252,
            hex_coordinate: 0_felt252,
            area_id: 0_felt252,
            building_type: 0_felt252,
            target_tier: 0_u8,
            start_block: 0_u64,
            completion_block: 0_u64,
            energy_staked: 0_u16,
            status: ConstructionProjectStatus::Inactive,
        };

        let started = start_project_transition(
            project,
            7_felt252,
            888_felt252,
            777_felt252,
            B_SMELTER,
            1_u8,
            100_u64,
            120_u64,
            40_u16,
            90_u16,
        );

        assert(started.outcome == ConstructionStartOutcome::Applied, 'CS_APPLY');
        assert(started.remaining_energy == 50_u16, 'CS_ENE');
        assert(started.project.status == ConstructionProjectStatus::Active, 'CS_STAT');
        assert(started.project.start_block == 100_u64, 'CS_STRT');
        assert(started.project.completion_block == 220_u64, 'CS_DONE');
        assert(started.project.energy_staked == 40_u16, 'CS_STKE');
    }

    #[test]
    fn construction_manager_start_rejects_active_and_insufficient_energy() {
        let active_project = ConstructionProject {
            project_id: 11_felt252,
            adventurer_id: 1_felt252,
            hex_coordinate: 2_felt252,
            area_id: 3_felt252,
            building_type: B_SMELTER,
            target_tier: 1_u8,
            start_block: 10_u64,
            completion_block: 20_u64,
            energy_staked: 40_u16,
            status: ConstructionProjectStatus::Active,
        };

        let blocked = start_project_transition(
            active_project,
            7_felt252,
            888_felt252,
            777_felt252,
            B_SMELTER,
            1_u8,
            100_u64,
            120_u64,
            40_u16,
            90_u16,
        );
        assert(blocked.outcome == ConstructionStartOutcome::AlreadyActive, 'CS_ACTV');

        let empty_project = ConstructionProject {
            status: ConstructionProjectStatus::Inactive,
            ..active_project
        };
        let no_energy = start_project_transition(
            empty_project,
            7_felt252,
            888_felt252,
            777_felt252,
            B_SMELTER,
            1_u8,
            100_u64,
            120_u64,
            40_u16,
            20_u16,
        );
        assert(no_energy.outcome == ConstructionStartOutcome::InsufficientEnergy, 'CS_LOW');
    }

    #[test]
    fn construction_manager_complete_requires_ready_block() {
        let active = ConstructionProject {
            project_id: 11_felt252,
            adventurer_id: 1_felt252,
            hex_coordinate: 2_felt252,
            area_id: 3_felt252,
            building_type: B_SMELTER,
            target_tier: 1_u8,
            start_block: 10_u64,
            completion_block: 50_u64,
            energy_staked: 40_u16,
            status: ConstructionProjectStatus::Active,
        };

        let early = complete_project_transition(active, 49_u64);
        assert(early.outcome == ConstructionCompleteOutcome::NotReady, 'CC_EAR');

        let done = complete_project_transition(active, 50_u64);
        assert(done.outcome == ConstructionCompleteOutcome::Applied, 'CC_OK');
        assert(done.project.status == ConstructionProjectStatus::Completed, 'CC_STAT');
    }

    #[test]
    fn construction_manager_upkeep_and_checkpoint_deterioration() {
        let building = ConstructionBuildingNode {
            area_id: 101_felt252,
            hex_coordinate: 202_felt252,
            owner_adventurer_id: 303_felt252,
            building_type: B_SMELTER,
            tier: 1_u8,
            condition_bp: 3400_u16,
            upkeep_reserve: 0_u32,
            last_upkeep_block: 0_u64,
            is_active: true,
        };

        let funded = pay_building_upkeep_transition(building, 30_u16, 12_u64);
        assert(funded.outcome == ConstructionCheckpointOutcome::Maintained, 'CU_PAY');
        assert(funded.building.upkeep_reserve == 30_u32, 'CU_RSV');

        let disabled = checkpoint_building_transition(funded.building, 100_u32, 900_u16, 3000_u16);
        assert(disabled.outcome == ConstructionCheckpointOutcome::Disabled, 'CU_DIS');
        assert(!disabled.building.is_active, 'CU_OFF');
    }

    #[test]
    fn construction_manager_repair_reactivates_and_caps_condition() {
        let inactive = ConstructionBuildingNode {
            area_id: 101_felt252,
            hex_coordinate: 202_felt252,
            owner_adventurer_id: 303_felt252,
            building_type: B_SMELTER,
            tier: 1_u8,
            condition_bp: 2_800_u16,
            upkeep_reserve: 0_u32,
            last_upkeep_block: 0_u64,
            is_active: false,
        };

        let reactivated = repair_building_transition(inactive, 2_u16, 200_u16, 3_000_u16);
        assert(reactivated.outcome == ConstructionCheckpointOutcome::Reactivated, 'CR_REAC');
        assert(reactivated.building.is_active, 'CR_ON');
        assert(reactivated.building.condition_bp == 3_200_u16, 'CR_BP');

        let near_cap = ConstructionBuildingNode { condition_bp: 9_950_u16, is_active: true, ..inactive };
        let capped = repair_building_transition(near_cap, 5_u16, 50_u16, 3_000_u16);
        assert(capped.outcome == ConstructionCheckpointOutcome::Repaired, 'CR_REP');
        assert(capped.building.condition_bp == 10_000_u16, 'CR_CAP');
    }

    #[test]
    fn construction_manager_repair_rejects_zero_amount() {
        let building = ConstructionBuildingNode {
            area_id: 101_felt252,
            hex_coordinate: 202_felt252,
            owner_adventurer_id: 303_felt252,
            building_type: B_SMELTER,
            tier: 1_u8,
            condition_bp: 2_800_u16,
            upkeep_reserve: 0_u32,
            last_upkeep_block: 0_u64,
            is_active: false,
        };

        let invalid = repair_building_transition(building, 0_u16, 200_u16, 3_000_u16);
        assert(invalid.outcome == ConstructionCheckpointOutcome::InvalidAmount, 'CR_INV');
        assert(invalid.building.condition_bp == 2_800_u16, 'CR_INV_BP');
        assert(!invalid.building.is_active, 'CR_INV_ON');
    }
}
