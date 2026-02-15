#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ResourceKind {
    #[default]
    Unknown,
    Mine,
    PlantArea,
    ConstructionArea,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum PolicyScope {
    #[default]
    None,
    Global,
    Hex,
    Area,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ShareRuleKind {
    #[default]
    OutputItem,
    OutputEnergy,
    FeeOnly,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ResourcePolicy {
    #[key]
    pub resource_key: felt252,
    pub scope: PolicyScope,
    pub scope_key: felt252,
    pub resource_kind: ResourceKind,
    pub controller_adventurer_id: felt252,
    pub policy_epoch: u32,
    pub is_enabled: bool,
    pub updated_block: u64,
    pub last_mutation_block: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ResourceAccessGrant {
    #[key]
    pub resource_key: felt252,
    #[key]
    pub grantee_adventurer_id: felt252,
    pub permissions_mask: u16,
    pub granted_by_adventurer_id: felt252,
    pub grant_block: u64,
    pub revoke_block: u64,
    pub is_active: bool,
    pub policy_epoch: u32,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ResourceShareRule {
    #[key]
    pub resource_key: felt252,
    #[key]
    pub recipient_adventurer_id: felt252,
    #[key]
    pub rule_kind: ShareRuleKind,
    pub share_bp: u16,
    pub is_active: bool,
    pub policy_epoch: u32,
    pub updated_block: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ResourceShareRuleTally {
    #[key]
    pub resource_key: felt252,
    #[key]
    pub rule_kind: ShareRuleKind,
    pub total_bp: u16,
    pub active_recipient_count: u8,
    pub policy_epoch: u32,
    pub recipient_0: felt252,
    pub recipient_1: felt252,
    pub recipient_2: felt252,
    pub recipient_3: felt252,
    pub recipient_4: felt252,
    pub recipient_5: felt252,
    pub recipient_6: felt252,
    pub recipient_7: felt252,
    pub updated_block: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct ResourceDistributionNonce {
    #[key]
    pub resource_key: felt252,
    pub last_nonce: u64,
}

fn kind_tag(kind: ResourceKind) -> felt252 {
    match kind {
        ResourceKind::Mine => 'RK_MINE'_felt252,
        ResourceKind::PlantArea => 'RK_PLANT'_felt252,
        ResourceKind::ConstructionArea => 'RK_CONST'_felt252,
        ResourceKind::Unknown => 'RK_UNK'_felt252,
    }
}

pub fn derive_area_resource_key(area_id: felt252, kind: ResourceKind) -> felt252 {
    let (key, _, _) = core::poseidon::hades_permutation(area_id, kind_tag(kind), 'SHARE_AREA_V1'_felt252);
    key
}

pub fn derive_hex_resource_key(hex_coordinate: felt252, kind: ResourceKind) -> felt252 {
    let (key, _, _) = core::poseidon::hades_permutation(
        hex_coordinate, kind_tag(kind), 'SHARE_HEX_V1'_felt252,
    );
    key
}

pub fn derive_global_resource_key(kind: ResourceKind) -> felt252 {
    let (key, _, _) = core::poseidon::hades_permutation(
        kind_tag(kind), 'SHARE_GLOBAL_V1'_felt252, 0_felt252,
    );
    key
}

pub fn is_policy_effective(policy: ResourcePolicy) -> bool {
    policy.is_enabled && policy.controller_adventurer_id != 0_felt252
}

pub fn is_grant_effective(grant: ResourceAccessGrant, policy_epoch: u32) -> bool {
    grant.is_active && grant.policy_epoch == policy_epoch && grant.permissions_mask > 0_u16
}

pub fn is_share_rule_effective(rule: ResourceShareRule, policy_epoch: u32) -> bool {
    rule.is_active && rule.policy_epoch == policy_epoch && rule.share_bp > 0_u16
}

pub fn select_nearest_policy_scope(
    area_policy: ResourcePolicy, hex_policy: ResourcePolicy, global_policy: ResourcePolicy,
) -> PolicyScope {
    if is_policy_effective(area_policy) {
        return PolicyScope::Area;
    }
    if is_policy_effective(hex_policy) {
        return PolicyScope::Hex;
    }
    if is_policy_effective(global_policy) {
        return PolicyScope::Global;
    }
    PolicyScope::None
}
