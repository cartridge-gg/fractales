#[cfg(test)]
mod tests {
    use dojo_starter::libs::sharing_math::{
        PERM_BUILD, PERM_EXTRACT, PERM_INSPECT, PERM_UPKEEP, POLICY_MUTATION_COOLDOWN_BLOCKS,
        POLICY_MUTATION_ENERGY_COST, SHARE_RECIPIENT_LIMIT,
    };
    use dojo_starter::models::sharing::{
        PolicyScope, ResourceAccessGrant, ResourceKind, ResourcePolicy, ResourceShareRule, ShareRuleKind,
    };
    use dojo_starter::systems::sharing_manager::{
        AccessGrantOutcome, AccessRevokeOutcome, ControllerTransferOutcome, PermissionResolutionOutcome,
        PolicyUpsertOutcome, ShareRuleClearOutcome, ShareRuleSetOutcome, grant_access_transition,
        revoke_access_transition, resolve_permission_transition, set_share_rule_transition,
        clear_share_rule_transition, on_controller_transfer_transition, upsert_policy_transition,
    };

    fn base_policy() -> ResourcePolicy {
        ResourcePolicy {
            resource_key: 9001_felt252,
            scope: PolicyScope::Area,
            scope_key: 7001_felt252,
            resource_kind: ResourceKind::Mine,
            controller_adventurer_id: 111_felt252,
            policy_epoch: 4_u32,
            is_enabled: true,
            updated_block: 10_u64,
            last_mutation_block: 0_u64,
        }
    }

    fn empty_grant(resource_key: felt252, grantee: felt252) -> ResourceAccessGrant {
        ResourceAccessGrant {
            resource_key,
            grantee_adventurer_id: grantee,
            permissions_mask: 0_u16,
            granted_by_adventurer_id: 0_felt252,
            grant_block: 0_u64,
            revoke_block: 0_u64,
            is_active: false,
            policy_epoch: 0_u32,
        }
    }

    fn empty_rule(resource_key: felt252, recipient: felt252, rule_kind: ShareRuleKind) -> ResourceShareRule {
        ResourceShareRule {
            resource_key,
            recipient_adventurer_id: recipient,
            rule_kind,
            share_bp: 0_u16,
            is_active: false,
            policy_epoch: 0_u32,
            updated_block: 0_u64,
        }
    }

    fn no_policy() -> ResourcePolicy {
        let policy = base_policy();
        ResourcePolicy {
            scope: PolicyScope::None,
            scope_key: 0_felt252,
            resource_key: 0_felt252,
            controller_adventurer_id: 0_felt252,
            policy_epoch: 0_u32,
            is_enabled: false,
            updated_block: 0_u64,
            last_mutation_block: 0_u64,
            ..policy
        }
    }

    fn no_grant() -> ResourceAccessGrant {
        empty_grant(0_felt252, 0_felt252)
    }

    #[test]
    fn sharing_manager_policy_upsert_respects_controller_auth_and_mutation_cost() {
        let mut policy = base_policy();
        policy.controller_adventurer_id = 0_felt252;
        policy.policy_epoch = 0_u32;

        let applied = upsert_policy_transition(
            policy,
            111_felt252,
            true,
            true,
            111_felt252,
            9001_felt252,
            PolicyScope::Area,
            7001_felt252,
            ResourceKind::Mine,
            true,
            120_u64,
        );
        assert(applied.outcome == PolicyUpsertOutcome::Applied, 'SHMGR_UPSERT_OK');
        assert(applied.policy.policy_epoch == 1_u32, 'SHMGR_UPSERT_EPOCH');
        assert(applied.policy.last_mutation_block == 120_u64, 'SHMGR_UPSERT_MUT');
        assert(applied.energy_cost == POLICY_MUTATION_ENERGY_COST, 'SHMGR_UPSERT_COST');

        let denied = upsert_policy_transition(
            applied.policy,
            999_felt252,
            true,
            true,
            999_felt252,
            9001_felt252,
            PolicyScope::Area,
            7001_felt252,
            ResourceKind::Mine,
            true,
            300_u64,
        );
        assert(denied.outcome == PolicyUpsertOutcome::NotController, 'SHMGR_UPSERT_DENY');
    }

    #[test]
    fn sharing_manager_grant_and_revoke_lifecycle_applies_with_epoch_binding() {
        let policy = base_policy();
        let grant = empty_grant(policy.resource_key, 222_felt252);

        let granted = grant_access_transition(
            policy,
            grant,
            111_felt252,
            true,
            true,
            222_felt252,
            PERM_INSPECT + PERM_EXTRACT,
            150_u64,
        );
        assert(granted.outcome == AccessGrantOutcome::Applied, 'SHMGR_GRANT_OK');
        assert(granted.grant.is_active, 'SHMGR_GRANT_ACTIVE');
        assert(granted.grant.policy_epoch == policy.policy_epoch, 'SHMGR_GRANT_EPOCH');
        assert(granted.grant.permissions_mask == PERM_INSPECT + PERM_EXTRACT, 'SHMGR_GRANT_MASK');
        assert(granted.policy.last_mutation_block == 150_u64, 'SHMGR_GRANT_MUT');
        assert(granted.energy_cost == POLICY_MUTATION_ENERGY_COST, 'SHMGR_GRANT_COST');

        let revoked = revoke_access_transition(
            granted.policy,
            granted.grant,
            111_felt252,
            true,
            true,
            300_u64,
        );
        assert(revoked.outcome == AccessRevokeOutcome::Applied, 'SHMGR_REVOKE_OK');
        assert(!revoked.grant.is_active, 'SHMGR_REVOKE_OFF');
        assert(revoked.grant.revoke_block == 300_u64, 'SHMGR_REVOKE_BLOCK');
        assert(revoked.policy.last_mutation_block == 300_u64, 'SHMGR_REVOKE_MUT');
    }

    #[test]
    fn sharing_manager_share_rule_upsert_and_clear_lifecycle() {
        let policy = base_policy();
        let rule = empty_rule(policy.resource_key, 333_felt252, ShareRuleKind::OutputItem);

        let set_rule = set_share_rule_transition(
            policy,
            rule,
            111_felt252,
            true,
            true,
            333_felt252,
            ShareRuleKind::OutputItem,
            2_500_u16,
            0_u16,
            0_u8,
            500_u64,
        );
        assert(set_rule.outcome == ShareRuleSetOutcome::Applied, 'SHMGR_SHARE_SET');
        assert(set_rule.rule.is_active, 'SHMGR_SHARE_ON');
        assert(set_rule.rule.share_bp == 2_500_u16, 'SHMGR_SHARE_BP');
        assert(set_rule.rule.policy_epoch == policy.policy_epoch, 'SHMGR_SHARE_EPOCH');
        assert(set_rule.policy.last_mutation_block == 500_u64, 'SHMGR_SHARE_MUT');

        let cleared = clear_share_rule_transition(
            set_rule.policy,
            set_rule.rule,
            111_felt252,
            true,
            true,
            620_u64,
        );
        assert(cleared.outcome == ShareRuleClearOutcome::Applied, 'SHMGR_SHARE_CLEAR');
        assert(!cleared.rule.is_active, 'SHMGR_SHARE_OFF');
        assert(cleared.rule.share_bp == 0_u16, 'SHMGR_SHARE_ZERO');
    }

    #[test]
    fn sharing_manager_permission_resolution_uses_nearest_scope_override() {
        let area_policy = base_policy();
        let area_grant = empty_grant(area_policy.resource_key, 444_felt252);

        let hex_policy = ResourcePolicy {
            scope: PolicyScope::Hex,
            scope_key: 9002_felt252,
            controller_adventurer_id: 777_felt252,
            resource_key: 9102_felt252,
            ..area_policy
        };
        let hex_grant = ResourceAccessGrant {
            resource_key: hex_policy.resource_key,
            grantee_adventurer_id: 444_felt252,
            permissions_mask: PERM_EXTRACT + PERM_BUILD,
            granted_by_adventurer_id: 777_felt252,
            grant_block: 1_u64,
            revoke_block: 0_u64,
            is_active: true,
            policy_epoch: hex_policy.policy_epoch,
        };

        let global_policy = ResourcePolicy {
            scope: PolicyScope::Global,
            scope_key: 123_felt252,
            controller_adventurer_id: 888_felt252,
            resource_key: 9103_felt252,
            ..area_policy
        };
        let global_grant = ResourceAccessGrant {
            resource_key: global_policy.resource_key,
            grantee_adventurer_id: 444_felt252,
            permissions_mask: PERM_EXTRACT + PERM_UPKEEP,
            granted_by_adventurer_id: 888_felt252,
            grant_block: 1_u64,
            revoke_block: 0_u64,
            is_active: true,
            policy_epoch: global_policy.policy_epoch,
        };

        let denied_by_area = resolve_permission_transition(
            444_felt252,
            PERM_EXTRACT,
            area_policy,
            area_grant,
            hex_policy,
            hex_grant,
            global_policy,
            global_grant,
        );
        assert(!denied_by_area.allowed, 'SHMGR_SCOPE_DENY');
        assert(denied_by_area.outcome == PermissionResolutionOutcome::Denied, 'SHMGR_SCOPE_DENY_OUT');

        let no_area = ResourcePolicy { is_enabled: false, ..area_policy };
        let allow_hex = resolve_permission_transition(
            444_felt252,
            PERM_BUILD,
            no_area,
            area_grant,
            hex_policy,
            hex_grant,
            global_policy,
            global_grant,
        );
        assert(allow_hex.allowed, 'SHMGR_SCOPE_HEX_OK');
        assert(allow_hex.outcome == PermissionResolutionOutcome::Grant, 'SHMGR_SCOPE_HEX_GRANT');

        let no_hex = ResourcePolicy { is_enabled: false, ..hex_policy };
        let allow_global = resolve_permission_transition(
            444_felt252,
            PERM_UPKEEP,
            no_area,
            area_grant,
            no_hex,
            hex_grant,
            global_policy,
            global_grant,
        );
        assert(allow_global.allowed, 'SHMGR_SCOPE_G_OK');
        assert(allow_global.outcome == PermissionResolutionOutcome::Grant, 'SHMGR_SCOPE_G_GRANT');
    }

    #[test]
    fn sharing_manager_reject_paths_cover_dead_not_controller_invalid_and_overflow() {
        let policy = base_policy();
        let grant = empty_grant(policy.resource_key, 555_felt252);

        let dead = grant_access_transition(
            policy,
            grant,
            111_felt252,
            false,
            true,
            555_felt252,
            PERM_EXTRACT,
            100_u64,
        );
        assert(dead.outcome == AccessGrantOutcome::Dead, 'SHMGR_REJ_DEAD');

        let not_owner = grant_access_transition(
            policy,
            grant,
            111_felt252,
            true,
            false,
            555_felt252,
            PERM_EXTRACT,
            100_u64,
        );
        assert(not_owner.outcome == AccessGrantOutcome::NotOwner, 'SHMGR_REJ_OWNER');

        let not_controller = grant_access_transition(
            policy,
            grant,
            999_felt252,
            true,
            true,
            555_felt252,
            PERM_EXTRACT,
            100_u64,
        );
        assert(not_controller.outcome == AccessGrantOutcome::NotController, 'SHMGR_REJ_CTRL');

        let bad_mask = grant_access_transition(
            policy,
            grant,
            111_felt252,
            true,
            true,
            555_felt252,
            0_u16,
            100_u64,
        );
        assert(bad_mask.outcome == AccessGrantOutcome::InvalidPermissions, 'SHMGR_REJ_MASK');

        let share_rule = empty_rule(policy.resource_key, 556_felt252, ShareRuleKind::OutputEnergy);
        let overflow = set_share_rule_transition(
            policy,
            share_rule,
            111_felt252,
            true,
            true,
            556_felt252,
            ShareRuleKind::OutputEnergy,
            2_000_u16,
            9_000_u16,
            1_u8,
            200_u64,
        );
        assert(overflow.outcome == ShareRuleSetOutcome::ShareOverflow, 'SHMGR_REJ_OVER');
    }

    #[test]
    fn sharing_manager_enforces_recipient_cap_cooldown_and_transfer_epoch_bump() {
        let policy = base_policy();
        let rule = empty_rule(policy.resource_key, 666_felt252, ShareRuleKind::FeeOnly);

        let cap_hit = set_share_rule_transition(
            policy,
            rule,
            111_felt252,
            true,
            true,
            666_felt252,
            ShareRuleKind::FeeOnly,
            100_u16,
            0_u16,
            SHARE_RECIPIENT_LIMIT,
            500_u64,
        );
        assert(cap_hit.outcome == ShareRuleSetOutcome::RecipientLimit, 'SHMGR_CAP');

        let granted = grant_access_transition(
            policy,
            empty_grant(policy.resource_key, 667_felt252),
            111_felt252,
            true,
            true,
            667_felt252,
            PERM_EXTRACT,
            700_u64,
        );
        let cooldown_revoke = revoke_access_transition(
            granted.policy,
            granted.grant,
            111_felt252,
            true,
            true,
            700_u64 + POLICY_MUTATION_COOLDOWN_BLOCKS - 1_u64,
        );
        assert(cooldown_revoke.outcome == AccessRevokeOutcome::Cooldown, 'SHMGR_COOLDOWN');

        let transferred = on_controller_transfer_transition(granted.policy, 999_felt252, 900_u64);
        assert(transferred.outcome == ControllerTransferOutcome::Applied, 'SHMGR_XFER');
        assert(
            transferred.policy.policy_epoch == granted.policy.policy_epoch + 1_u32,
            'SHMGR_XFER_EPOCH',
        );

        let stale_resolve = resolve_permission_transition(
            667_felt252,
            PERM_EXTRACT,
            transferred.policy,
            granted.grant,
            no_policy(),
            no_grant(),
            no_policy(),
            no_grant(),
        );
        assert(!stale_resolve.allowed, 'SHMGR_STALE_DENY');
    }
}
