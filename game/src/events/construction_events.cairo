#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionStarted {
    #[key]
    pub project_id: felt252,
    pub adventurer_id: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub building_type: felt252,
    pub target_tier: u8,
    pub completion_block: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionCompleted {
    #[key]
    pub project_id: felt252,
    pub adventurer_id: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub building_type: felt252,
    pub resulting_tier: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionUpkeepPaid {
    #[key]
    pub area_id: felt252,
    pub adventurer_id: felt252,
    pub amount: u16,
    pub upkeep_reserve: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionRepaired {
    #[key]
    pub area_id: felt252,
    pub adventurer_id: felt252,
    pub amount: u16,
    pub condition_bp: u16,
    pub is_active: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionUpgradeQueued {
    #[key]
    pub area_id: felt252,
    pub project_id: felt252,
    pub adventurer_id: felt252,
    pub target_tier: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionPlantProcessed {
    #[key]
    pub adventurer_id: felt252,
    pub source_item_id: felt252,
    pub target_material: felt252,
    pub input_qty: u16,
    pub output_qty: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ConstructionRejected {
    #[key]
    pub adventurer_id: felt252,
    pub area_id: felt252,
    pub action: felt252,
    pub reason: felt252,
}
