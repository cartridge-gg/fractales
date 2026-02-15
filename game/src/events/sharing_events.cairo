use dojo_starter::models::sharing::{PolicyScope, ResourceKind, ShareRuleKind};

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourcePolicyUpserted {
    #[key]
    pub resource_key: felt252,
    pub scope: PolicyScope,
    pub scope_key: felt252,
    pub resource_kind: ResourceKind,
    pub controller_adventurer_id: felt252,
    pub policy_epoch: u32,
    pub is_enabled: bool,
    pub updated_block: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourceAccessGranted {
    #[key]
    pub resource_key: felt252,
    pub grantee_adventurer_id: felt252,
    pub granted_by_adventurer_id: felt252,
    pub permissions_mask: u16,
    pub policy_epoch: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourceAccessRevoked {
    #[key]
    pub resource_key: felt252,
    pub grantee_adventurer_id: felt252,
    pub revoked_by_adventurer_id: felt252,
    pub policy_epoch: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourceShareRuleSet {
    #[key]
    pub resource_key: felt252,
    pub recipient_adventurer_id: felt252,
    pub rule_kind: ShareRuleKind,
    pub share_bp: u16,
    pub policy_epoch: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourceShareRuleCleared {
    #[key]
    pub resource_key: felt252,
    pub recipient_adventurer_id: felt252,
    pub rule_kind: ShareRuleKind,
    pub policy_epoch: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ResourcePermissionRejected {
    #[key]
    pub adventurer_id: felt252,
    pub resource_key: felt252,
    pub action: felt252,
    pub reason: felt252,
}
