#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HarvestingStarted {
    #[key]
    pub adventurer_id: felt252,
    pub hex: felt252,
    pub area_id: felt252,
    pub plant_id: u8,
    pub amount: u16,
    pub eta: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HarvestingCompleted {
    #[key]
    pub adventurer_id: felt252,
    pub hex: felt252,
    pub area_id: felt252,
    pub plant_id: u8,
    pub actual_yield: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HarvestingCancelled {
    #[key]
    pub adventurer_id: felt252,
    pub partial_yield: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HarvestingRejected {
    #[key]
    pub adventurer_id: felt252,
    pub hex: felt252,
    pub area_id: felt252,
    pub plant_id: u8,
    pub phase: felt252,
    pub reason: felt252,
}
