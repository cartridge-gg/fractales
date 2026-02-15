#[cfg(test)]
mod tests {
    use dojo_starter::libs::construction_balance::{B_GREENHOUSE, B_SMELTER};
    use dojo_starter::models::construction::{
        BUILDING_DISABLE_THRESHOLD_BP, ConstructionBuildingNode, ConstructionProject,
        ConstructionProjectStatus, can_complete_project, derive_construction_project_id,
        is_building_effective,
    };

    #[test]
    fn construction_models_project_id_is_deterministic_and_domain_separated() {
        let same_a = derive_construction_project_id(11_felt252, 22_felt252, B_SMELTER, 3_u8);
        let same_b = derive_construction_project_id(11_felt252, 22_felt252, B_SMELTER, 3_u8);
        let diff_area = derive_construction_project_id(11_felt252, 23_felt252, B_SMELTER, 3_u8);
        let diff_building = derive_construction_project_id(11_felt252, 22_felt252, B_GREENHOUSE, 3_u8);

        assert(same_a == same_b, 'CM_PID_DET');
        assert(same_a != diff_area, 'CM_PID_AREA');
        assert(same_a != diff_building, 'CM_PID_KIND');
    }

    #[test]
    fn construction_models_building_effective_requires_active_and_condition() {
        let base = ConstructionBuildingNode {
            area_id: 101_felt252,
            hex_coordinate: 202_felt252,
            owner_adventurer_id: 303_felt252,
            building_type: B_SMELTER,
            tier: 1_u8,
            condition_bp: BUILDING_DISABLE_THRESHOLD_BP + 1_u16,
            upkeep_reserve: 0_u32,
            last_upkeep_block: 0_u64,
            is_active: true,
        };

        assert(is_building_effective(base), 'CM_EFF_ON');
        assert(!is_building_effective(ConstructionBuildingNode { is_active: false, ..base }), 'CM_EFF_OFF');
        assert(
            !is_building_effective(
                ConstructionBuildingNode {
                    condition_bp: BUILDING_DISABLE_THRESHOLD_BP,
                    ..base
                },
            ),
            'CM_EFF_LOW',
        );
    }

    #[test]
    fn construction_models_can_complete_requires_active_and_time_gate() {
        let project = ConstructionProject {
            project_id: 999_felt252,
            adventurer_id: 1_felt252,
            hex_coordinate: 2_felt252,
            area_id: 3_felt252,
            building_type: B_SMELTER,
            target_tier: 1_u8,
            start_block: 50_u64,
            completion_block: 100_u64,
            energy_staked: 40_u16,
            status: ConstructionProjectStatus::Active,
        };

        assert(!can_complete_project(project, 99_u64), 'CM_CPL_EARLY');
        assert(can_complete_project(project, 100_u64), 'CM_CPL_OK');
        assert(
            !can_complete_project(
                ConstructionProject {
                    status: ConstructionProjectStatus::Canceled,
                    ..project
                },
                200_u64,
            ),
            'CM_CPL_STAT',
        );
    }
}
