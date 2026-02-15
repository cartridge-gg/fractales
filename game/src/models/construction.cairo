pub const BUILDING_DISABLE_THRESHOLD_BP: u16 = 3_000_u16;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConstructionProjectStatus {
    #[default]
    Inactive,
    Active,
    Completed,
    Canceled,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ConstructionBuildingNode {
    #[key]
    pub area_id: felt252,
    pub hex_coordinate: felt252,
    pub owner_adventurer_id: felt252,
    pub building_type: felt252,
    pub tier: u8,
    pub condition_bp: u16,
    pub upkeep_reserve: u32,
    pub last_upkeep_block: u64,
    pub is_active: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ConstructionProject {
    #[key]
    pub project_id: felt252,
    pub adventurer_id: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub building_type: felt252,
    pub target_tier: u8,
    pub start_block: u64,
    pub completion_block: u64,
    pub energy_staked: u16,
    pub status: ConstructionProjectStatus,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ConstructionMaterialEscrow {
    #[key]
    pub project_id: felt252,
    #[key]
    pub item_id: felt252,
    pub quantity: u32,
}

pub fn derive_construction_project_id(
    adventurer_id: felt252, area_id: felt252, building_type: felt252, target_tier: u8,
) -> felt252 {
    let (stage_one, _, _) = core::poseidon::hades_permutation(adventurer_id, area_id, building_type);
    let (project_id, _, _) = core::poseidon::hades_permutation(
        stage_one, target_tier.into(), 'CONST_PROJ_V1'_felt252,
    );
    project_id
}

pub fn is_building_effective(building: ConstructionBuildingNode) -> bool {
    building.is_active && building.condition_bp > BUILDING_DISABLE_THRESHOLD_BP
}

pub fn can_complete_project(project: ConstructionProject, now_block: u64) -> bool {
    project.status == ConstructionProjectStatus::Active && now_block >= project.completion_block
}
