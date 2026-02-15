use core::traits::TryInto;
use dojo_starter::models::construction::{
    ConstructionBuildingNode, ConstructionProject, ConstructionProjectStatus,
    derive_construction_project_id,
};

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConstructionStartOutcome {
    #[default]
    AlreadyActive,
    InvalidStake,
    InsufficientEnergy,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConstructionCompleteOutcome {
    #[default]
    NotActive,
    NotReady,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConstructionCheckpointOutcome {
    #[default]
    Inactive,
    InvalidAmount,
    InvalidUpkeepDue,
    Maintained,
    Repaired,
    Reactivated,
    Deteriorated,
    Disabled,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ConstructionStartResult {
    pub project: ConstructionProject,
    pub remaining_energy: u16,
    pub outcome: ConstructionStartOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ConstructionCompleteResult {
    pub project: ConstructionProject,
    pub outcome: ConstructionCompleteOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ConstructionCheckpointResult {
    pub building: ConstructionBuildingNode,
    pub outcome: ConstructionCheckpointOutcome,
}

fn saturating_add_u32(lhs: u32, rhs: u32) -> u32 {
    let sum_u64: u64 = lhs.into() + rhs.into();
    if sum_u64 > 4_294_967_295_u64 {
        4_294_967_295_u32
    } else {
        sum_u64.try_into().unwrap()
    }
}

pub fn start_project_transition(
    mut project: ConstructionProject,
    adventurer_id: felt252,
    hex_coordinate: felt252,
    area_id: felt252,
    building_type: felt252,
    target_tier: u8,
    now_block: u64,
    build_time_blocks: u64,
    energy_stake: u16,
    available_energy: u16,
) -> ConstructionStartResult {
    if project.status == ConstructionProjectStatus::Active {
        return ConstructionStartResult {
            project, remaining_energy: available_energy, outcome: ConstructionStartOutcome::AlreadyActive,
        };
    }

    if energy_stake == 0_u16 {
        return ConstructionStartResult {
            project, remaining_energy: available_energy, outcome: ConstructionStartOutcome::InvalidStake,
        };
    }

    if available_energy < energy_stake {
        return ConstructionStartResult {
            project,
            remaining_energy: available_energy,
            outcome: ConstructionStartOutcome::InsufficientEnergy,
        };
    }

    let project_id = derive_construction_project_id(adventurer_id, area_id, building_type, target_tier);
    project.project_id = project_id;
    project.adventurer_id = adventurer_id;
    project.hex_coordinate = hex_coordinate;
    project.area_id = area_id;
    project.building_type = building_type;
    project.target_tier = target_tier;
    project.start_block = now_block;
    project.completion_block = now_block + build_time_blocks;
    project.energy_staked = energy_stake;
    project.status = ConstructionProjectStatus::Active;

    ConstructionStartResult {
        project,
        remaining_energy: available_energy - energy_stake,
        outcome: ConstructionStartOutcome::Applied,
    }
}

pub fn complete_project_transition(
    mut project: ConstructionProject, now_block: u64,
) -> ConstructionCompleteResult {
    if project.status != ConstructionProjectStatus::Active {
        return ConstructionCompleteResult { project, outcome: ConstructionCompleteOutcome::NotActive };
    }

    if now_block < project.completion_block {
        return ConstructionCompleteResult { project, outcome: ConstructionCompleteOutcome::NotReady };
    }

    project.status = ConstructionProjectStatus::Completed;
    ConstructionCompleteResult { project, outcome: ConstructionCompleteOutcome::Applied }
}

pub fn pay_building_upkeep_transition(
    mut building: ConstructionBuildingNode, amount: u16, now_block: u64,
) -> ConstructionCheckpointResult {
    if !building.is_active {
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::Inactive,
        };
    }

    if amount == 0_u16 {
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::InvalidAmount,
        };
    }

    building.upkeep_reserve = saturating_add_u32(building.upkeep_reserve, amount.into());
    building.last_upkeep_block = now_block;

    ConstructionCheckpointResult {
        building, outcome: ConstructionCheckpointOutcome::Maintained,
    }
}

pub fn checkpoint_building_transition(
    mut building: ConstructionBuildingNode,
    upkeep_due: u32,
    deterioration_bp: u16,
    disable_threshold_bp: u16,
) -> ConstructionCheckpointResult {
    if !building.is_active {
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::Inactive,
        };
    }

    if upkeep_due == 0_u32 {
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::InvalidUpkeepDue,
        };
    }

    if building.upkeep_reserve >= upkeep_due {
        building.upkeep_reserve -= upkeep_due;
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::Maintained,
        };
    }

    let deficit = upkeep_due - building.upkeep_reserve;
    building.upkeep_reserve = 0_u32;

    let deficit_u64: u64 = deficit.into();
    let upkeep_due_u64: u64 = upkeep_due.into();
    let deterioration_u64: u64 = deterioration_bp.into();
    let mut drop_u64 = (deficit_u64 * deterioration_u64) / upkeep_due_u64;
    if drop_u64 == 0_u64 {
        drop_u64 = 1_u64;
    }

    let drop = if drop_u64 > 65_535_u64 {
        65_535_u16
    } else {
        drop_u64.try_into().unwrap()
    };

    let current = building.condition_bp;
    building.condition_bp = if drop >= current { 0_u16 } else { current - drop };

    if building.condition_bp <= disable_threshold_bp {
        building.is_active = false;
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::Disabled,
        };
    }

    ConstructionCheckpointResult {
        building, outcome: ConstructionCheckpointOutcome::Deteriorated,
    }
}

pub fn repair_building_transition(
    mut building: ConstructionBuildingNode,
    amount: u16,
    repair_bp_per_energy: u16,
    disable_threshold_bp: u16,
) -> ConstructionCheckpointResult {
    if amount == 0_u16 || repair_bp_per_energy == 0_u16 {
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::InvalidAmount,
        };
    }

    let gain_u64: u64 = amount.into() * repair_bp_per_energy.into();
    let gain = if gain_u64 > 65_535_u64 {
        65_535_u16
    } else {
        gain_u64.try_into().unwrap()
    };

    let repaired_u32: u32 = building.condition_bp.into() + gain.into();
    building.condition_bp = if repaired_u32 > 10_000_u32 {
        10_000_u16
    } else {
        repaired_u32.try_into().unwrap()
    };

    if !building.is_active && building.condition_bp > disable_threshold_bp {
        building.is_active = true;
        return ConstructionCheckpointResult {
            building, outcome: ConstructionCheckpointOutcome::Reactivated,
        };
    }

    ConstructionCheckpointResult {
        building, outcome: ConstructionCheckpointOutcome::Repaired,
    }
}
