#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum MiningShiftStatus {
    #[default]
    Inactive,
    Active,
    Exited,
    Collapsed,
    Completed,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct MineNode {
    #[key]
    pub mine_key: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub mine_id: u8,
    pub ore_id: felt252,
    pub rarity_tier: u8,
    pub depth_tier: u8,
    pub richness_bp: u16,
    pub remaining_reserve: u32,
    pub base_stress_per_block: u16,
    pub collapse_threshold: u32,
    pub mine_stress: u32,
    pub safe_shift_blocks: u64,
    pub active_miners: u16,
    pub last_update_block: u64,
    pub collapsed_until_block: u64,
    pub repair_energy_needed: u32,
    pub is_depleted: bool,
    pub active_head_shift_id: felt252,
    pub active_tail_shift_id: felt252,
    pub biome_risk_bp: u16,
    pub rarity_risk_bp: u16,
    pub base_tick_energy: u16,
    pub ore_energy_weight: u16,
    pub conversion_energy_per_unit: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct MiningShift {
    #[key]
    pub shift_id: felt252,
    pub adventurer_id: felt252,
    pub mine_key: felt252,
    pub status: MiningShiftStatus,
    pub start_block: u64,
    pub last_settle_block: u64,
    pub accrued_ore_unbanked: u32,
    pub accrued_stabilization_work: u32,
    pub prev_active_shift_id: felt252,
    pub next_active_shift_id: felt252,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct MineAccessGrant {
    #[key]
    pub mine_key: felt252,
    #[key]
    pub grantee_adventurer_id: felt252,
    pub is_allowed: bool,
    pub granted_by_adventurer_id: felt252,
    pub grant_block: u64,
    pub revoked_block: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct MineCollapseRecord {
    #[key]
    pub mine_key: felt252,
    pub collapse_count: u32,
    pub last_collapse_block: u64,
    pub trigger_stress: u32,
    pub trigger_active_miners: u16,
}

pub fn derive_mine_key(hex_coordinate: felt252, area_id: felt252, mine_id: u8) -> felt252 {
    let (stage_one, _, _) = core::poseidon::hades_permutation(hex_coordinate, area_id, mine_id.into());
    let (key, _, _) = core::poseidon::hades_permutation(stage_one, 'MINE_KEY_V1'_felt252, 0_felt252);
    key
}

pub fn derive_mining_shift_id(adventurer_id: felt252, mine_key: felt252) -> felt252 {
    let (id, _, _) = core::poseidon::hades_permutation(adventurer_id, mine_key, 'MSHIFT_ID_V1'_felt252);
    id
}

pub fn derive_mining_item_id(ore_id: felt252) -> felt252 {
    ore_id
}
