#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineInitialized {
    #[key]
    pub mine_key: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub mine_id: u8,
    pub ore_id: felt252,
    pub rarity_tier: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineAccessGranted {
    #[key]
    pub mine_key: felt252,
    pub grantee_adventurer_id: felt252,
    pub granted_by_adventurer_id: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineAccessRevoked {
    #[key]
    pub mine_key: felt252,
    pub grantee_adventurer_id: felt252,
    pub revoked_by_adventurer_id: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MiningStarted {
    #[key]
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub start_block: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MiningContinued {
    #[key]
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub mined_ore: u32,
    pub energy_spent: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineStabilized {
    #[key]
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub stress_reduced: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MiningExited {
    #[key]
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub banked_ore: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineCollapsed {
    #[key]
    pub mine_key: felt252,
    pub killed_miners: u16,
    pub collapse_count: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MineRepaired {
    #[key]
    pub mine_key: felt252,
    pub adventurer_id: felt252,
    pub energy_contributed: u16,
    pub repair_energy_remaining: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MiningRejected {
    #[key]
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub action: felt252,
    pub reason: felt252,
}
