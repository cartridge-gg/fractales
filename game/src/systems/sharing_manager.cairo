use dojo_starter::libs::sharing_math::{
    PERM_ALL, POLICY_MUTATION_COOLDOWN_BLOCKS, POLICY_MUTATION_ENERGY_COST, SHARE_RECIPIENT_LIMIT,
    can_add_share, has_permissions, is_valid_permissions_mask,
};
use dojo_starter::models::sharing::{
    PolicyScope, ResourceAccessGrant, ResourceKind, ResourcePolicy, ResourceShareRule, ShareRuleKind,
    is_grant_effective, is_policy_effective, is_share_rule_effective, select_nearest_policy_scope,
};

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum PolicyUpsertOutcome {
    #[default]
    Dead,
    NotOwner,
    InvalidController,
    NotController,
    Cooldown,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AccessGrantOutcome {
    #[default]
    Dead,
    NotOwner,
    PolicyDisabled,
    NotController,
    Cooldown,
    InvalidPermissions,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AccessRevokeOutcome {
    #[default]
    Dead,
    NotOwner,
    PolicyDisabled,
    NotController,
    Cooldown,
    NotGranted,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ShareRuleSetOutcome {
    #[default]
    Dead,
    NotOwner,
    PolicyDisabled,
    NotController,
    Cooldown,
    InvalidRecipient,
    InvalidShare,
    ShareOverflow,
    RecipientLimit,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ShareRuleClearOutcome {
    #[default]
    Dead,
    NotOwner,
    PolicyDisabled,
    NotController,
    Cooldown,
    NotFound,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum PermissionResolutionOutcome {
    #[default]
    NoPolicy,
    Controller,
    Grant,
    Denied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ControllerTransferOutcome {
    #[default]
    InvalidController,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct PolicyUpsertResult {
    pub policy: ResourcePolicy,
    pub outcome: PolicyUpsertOutcome,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct AccessGrantResult {
    pub policy: ResourcePolicy,
    pub grant: ResourceAccessGrant,
    pub outcome: AccessGrantOutcome,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct AccessRevokeResult {
    pub policy: ResourcePolicy,
    pub grant: ResourceAccessGrant,
    pub outcome: AccessRevokeOutcome,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ShareRuleSetResult {
    pub policy: ResourcePolicy,
    pub rule: ResourceShareRule,
    pub outcome: ShareRuleSetOutcome,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ShareRuleClearResult {
    pub policy: ResourcePolicy,
    pub rule: ResourceShareRule,
    pub outcome: ShareRuleClearOutcome,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct PermissionResolutionResult {
    pub allowed: bool,
    pub scope: PolicyScope,
    pub granted_permissions_mask: u16,
    pub outcome: PermissionResolutionOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ControllerTransferResult {
    pub policy: ResourcePolicy,
    pub outcome: ControllerTransferOutcome,
}

fn cooldown_elapsed(last_mutation_block: u64, now_block: u64) -> bool {
    if last_mutation_block == 0_u64 {
        return true;
    }
    if now_block < last_mutation_block {
        return false;
    }
    (now_block - last_mutation_block) >= POLICY_MUTATION_COOLDOWN_BLOCKS
}

fn apply_mutation_meta(mut policy: ResourcePolicy, now_block: u64) -> ResourcePolicy {
    policy.updated_block = now_block;
    policy.last_mutation_block = now_block;
    policy
}

pub fn upsert_policy_transition(
    mut policy: ResourcePolicy,
    actor_adventurer_id: felt252,
    actor_alive: bool,
    actor_controls_adventurer: bool,
    controller_adventurer_id: felt252,
    resource_key: felt252,
    scope: PolicyScope,
    scope_key: felt252,
    resource_kind: ResourceKind,
    is_enabled: bool,
    now_block: u64,
) -> PolicyUpsertResult {
    if !actor_alive {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::Dead, energy_cost: 0_u16,
        };
    }
    if !actor_controls_adventurer {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::NotOwner, energy_cost: 0_u16,
        };
    }
    if controller_adventurer_id == 0_felt252 {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::InvalidController, energy_cost: 0_u16,
        };
    }
    if !cooldown_elapsed(policy.last_mutation_block, now_block) {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::Cooldown, energy_cost: 0_u16,
        };
    }
    if policy.controller_adventurer_id != 0_felt252 && actor_adventurer_id != policy.controller_adventurer_id {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::NotController, energy_cost: 0_u16,
        };
    }
    if actor_adventurer_id != controller_adventurer_id {
        return PolicyUpsertResult {
            policy, outcome: PolicyUpsertOutcome::NotController, energy_cost: 0_u16,
        };
    }

    policy.resource_key = resource_key;
    policy.scope = scope;
    policy.scope_key = scope_key;
    policy.resource_kind = resource_kind;
    policy.controller_adventurer_id = controller_adventurer_id;
    policy.policy_epoch = if policy.policy_epoch == 0_u32 { 1_u32 } else { policy.policy_epoch };
    policy.is_enabled = is_enabled;
    policy = apply_mutation_meta(policy, now_block);

    PolicyUpsertResult {
        policy,
        outcome: PolicyUpsertOutcome::Applied,
        energy_cost: POLICY_MUTATION_ENERGY_COST,
    }
}

pub fn grant_access_transition(
    mut policy: ResourcePolicy,
    mut grant: ResourceAccessGrant,
    actor_adventurer_id: felt252,
    actor_alive: bool,
    actor_controls_adventurer: bool,
    grantee_adventurer_id: felt252,
    permissions_mask: u16,
    now_block: u64,
) -> AccessGrantResult {
    if !actor_alive {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::Dead, energy_cost: 0_u16,
        };
    }
    if !actor_controls_adventurer {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::NotOwner, energy_cost: 0_u16,
        };
    }
    if !is_policy_effective(policy) {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::PolicyDisabled, energy_cost: 0_u16,
        };
    }
    if actor_adventurer_id != policy.controller_adventurer_id {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::NotController, energy_cost: 0_u16,
        };
    }
    if !cooldown_elapsed(policy.last_mutation_block, now_block) {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::Cooldown, energy_cost: 0_u16,
        };
    }
    if grantee_adventurer_id == 0_felt252 || !is_valid_permissions_mask(permissions_mask) {
        return AccessGrantResult {
            policy, grant, outcome: AccessGrantOutcome::InvalidPermissions, energy_cost: 0_u16,
        };
    }

    policy = apply_mutation_meta(policy, now_block);
    grant.resource_key = policy.resource_key;
    grant.grantee_adventurer_id = grantee_adventurer_id;
    grant.permissions_mask = permissions_mask;
    grant.granted_by_adventurer_id = actor_adventurer_id;
    grant.grant_block = now_block;
    grant.revoke_block = 0_u64;
    grant.is_active = true;
    grant.policy_epoch = policy.policy_epoch;

    AccessGrantResult {
        policy,
        grant,
        outcome: AccessGrantOutcome::Applied,
        energy_cost: POLICY_MUTATION_ENERGY_COST,
    }
}

pub fn revoke_access_transition(
    mut policy: ResourcePolicy,
    mut grant: ResourceAccessGrant,
    actor_adventurer_id: felt252,
    actor_alive: bool,
    actor_controls_adventurer: bool,
    now_block: u64,
) -> AccessRevokeResult {
    if !actor_alive {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::Dead, energy_cost: 0_u16,
        };
    }
    if !actor_controls_adventurer {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::NotOwner, energy_cost: 0_u16,
        };
    }
    if !is_policy_effective(policy) {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::PolicyDisabled, energy_cost: 0_u16,
        };
    }
    if actor_adventurer_id != policy.controller_adventurer_id {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::NotController, energy_cost: 0_u16,
        };
    }
    if !cooldown_elapsed(policy.last_mutation_block, now_block) {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::Cooldown, energy_cost: 0_u16,
        };
    }
    if !is_grant_effective(grant, policy.policy_epoch) {
        return AccessRevokeResult {
            policy, grant, outcome: AccessRevokeOutcome::NotGranted, energy_cost: 0_u16,
        };
    }

    policy = apply_mutation_meta(policy, now_block);
    grant.is_active = false;
    grant.revoke_block = now_block;

    AccessRevokeResult {
        policy,
        grant,
        outcome: AccessRevokeOutcome::Applied,
        energy_cost: POLICY_MUTATION_ENERGY_COST,
    }
}

pub fn set_share_rule_transition(
    mut policy: ResourcePolicy,
    mut rule: ResourceShareRule,
    actor_adventurer_id: felt252,
    actor_alive: bool,
    actor_controls_adventurer: bool,
    recipient_adventurer_id: felt252,
    rule_kind: ShareRuleKind,
    share_bp: u16,
    existing_total_bp: u16,
    active_recipient_count: u8,
    now_block: u64,
) -> ShareRuleSetResult {
    if !actor_alive {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::Dead, energy_cost: 0_u16,
        };
    }
    if !actor_controls_adventurer {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::NotOwner, energy_cost: 0_u16,
        };
    }
    if !is_policy_effective(policy) {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::PolicyDisabled, energy_cost: 0_u16,
        };
    }
    if actor_adventurer_id != policy.controller_adventurer_id {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::NotController, energy_cost: 0_u16,
        };
    }
    if !cooldown_elapsed(policy.last_mutation_block, now_block) {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::Cooldown, energy_cost: 0_u16,
        };
    }
    if recipient_adventurer_id == 0_felt252 {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::InvalidRecipient, energy_cost: 0_u16,
        };
    }
    if share_bp == 0_u16 || share_bp > 10_000_u16 {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::InvalidShare, energy_cost: 0_u16,
        };
    }

    let current_share = if is_share_rule_effective(rule, policy.policy_epoch) {
        rule.share_bp
    } else {
        0_u16
    };
    let base_total = if existing_total_bp >= current_share {
        existing_total_bp - current_share
    } else {
        0_u16
    };

    if !can_add_share(base_total, share_bp) {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::ShareOverflow, energy_cost: 0_u16,
        };
    }
    if current_share == 0_u16 && active_recipient_count >= SHARE_RECIPIENT_LIMIT {
        return ShareRuleSetResult {
            policy, rule, outcome: ShareRuleSetOutcome::RecipientLimit, energy_cost: 0_u16,
        };
    }

    policy = apply_mutation_meta(policy, now_block);
    rule.resource_key = policy.resource_key;
    rule.recipient_adventurer_id = recipient_adventurer_id;
    rule.rule_kind = rule_kind;
    rule.share_bp = share_bp;
    rule.is_active = true;
    rule.policy_epoch = policy.policy_epoch;
    rule.updated_block = now_block;

    ShareRuleSetResult {
        policy,
        rule,
        outcome: ShareRuleSetOutcome::Applied,
        energy_cost: POLICY_MUTATION_ENERGY_COST,
    }
}

pub fn clear_share_rule_transition(
    mut policy: ResourcePolicy,
    mut rule: ResourceShareRule,
    actor_adventurer_id: felt252,
    actor_alive: bool,
    actor_controls_adventurer: bool,
    now_block: u64,
) -> ShareRuleClearResult {
    if !actor_alive {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::Dead, energy_cost: 0_u16,
        };
    }
    if !actor_controls_adventurer {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::NotOwner, energy_cost: 0_u16,
        };
    }
    if !is_policy_effective(policy) {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::PolicyDisabled, energy_cost: 0_u16,
        };
    }
    if actor_adventurer_id != policy.controller_adventurer_id {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::NotController, energy_cost: 0_u16,
        };
    }
    if !cooldown_elapsed(policy.last_mutation_block, now_block) {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::Cooldown, energy_cost: 0_u16,
        };
    }
    if !is_share_rule_effective(rule, policy.policy_epoch) {
        return ShareRuleClearResult {
            policy, rule, outcome: ShareRuleClearOutcome::NotFound, energy_cost: 0_u16,
        };
    }

    policy = apply_mutation_meta(policy, now_block);
    rule.is_active = false;
    rule.share_bp = 0_u16;
    rule.updated_block = now_block;

    ShareRuleClearResult {
        policy,
        rule,
        outcome: ShareRuleClearOutcome::Applied,
        energy_cost: POLICY_MUTATION_ENERGY_COST,
    }
}

fn resolve_against_policy(
    adventurer_id: felt252,
    required_mask: u16,
    policy: ResourcePolicy,
    grant: ResourceAccessGrant,
    scope: PolicyScope,
) -> PermissionResolutionResult {
    if adventurer_id == policy.controller_adventurer_id {
        return PermissionResolutionResult {
            allowed: true,
            scope,
            granted_permissions_mask: PERM_ALL,
            outcome: PermissionResolutionOutcome::Controller,
        };
    }
    if !is_valid_permissions_mask(required_mask) {
        return PermissionResolutionResult {
            allowed: false,
            scope,
            granted_permissions_mask: 0_u16,
            outcome: PermissionResolutionOutcome::Denied,
        };
    }
    if grant.grantee_adventurer_id == adventurer_id && is_grant_effective(grant, policy.policy_epoch)
        && has_permissions(grant.permissions_mask, required_mask) {
        return PermissionResolutionResult {
            allowed: true,
            scope,
            granted_permissions_mask: grant.permissions_mask,
            outcome: PermissionResolutionOutcome::Grant,
        };
    }
    PermissionResolutionResult {
        allowed: false,
        scope,
        granted_permissions_mask: 0_u16,
        outcome: PermissionResolutionOutcome::Denied,
    }
}

pub fn resolve_permission_transition(
    adventurer_id: felt252,
    required_mask: u16,
    area_policy: ResourcePolicy,
    area_grant: ResourceAccessGrant,
    hex_policy: ResourcePolicy,
    hex_grant: ResourceAccessGrant,
    global_policy: ResourcePolicy,
    global_grant: ResourceAccessGrant,
) -> PermissionResolutionResult {
    let scope = select_nearest_policy_scope(area_policy, hex_policy, global_policy);
    match scope {
        PolicyScope::Area => {
            resolve_against_policy(adventurer_id, required_mask, area_policy, area_grant, PolicyScope::Area)
        },
        PolicyScope::Hex => {
            resolve_against_policy(adventurer_id, required_mask, hex_policy, hex_grant, PolicyScope::Hex)
        },
        PolicyScope::Global => {
            resolve_against_policy(
                adventurer_id, required_mask, global_policy, global_grant, PolicyScope::Global,
            )
        },
        PolicyScope::None => {
            PermissionResolutionResult {
                allowed: false,
                scope: PolicyScope::None,
                granted_permissions_mask: 0_u16,
                outcome: PermissionResolutionOutcome::NoPolicy,
            }
        },
    }
}

pub fn on_controller_transfer_transition(
    mut policy: ResourcePolicy, new_controller_adventurer_id: felt252, now_block: u64,
) -> ControllerTransferResult {
    if new_controller_adventurer_id == 0_felt252 {
        return ControllerTransferResult {
            policy, outcome: ControllerTransferOutcome::InvalidController,
        };
    }

    policy.controller_adventurer_id = new_controller_adventurer_id;
    policy.policy_epoch = if policy.policy_epoch == 4_294_967_295_u32 {
        4_294_967_295_u32
    } else {
        policy.policy_epoch + 1_u32
    };
    policy.is_enabled = true;
    policy = apply_mutation_meta(policy, now_block);

    ControllerTransferResult { policy, outcome: ControllerTransferOutcome::Applied }
}
