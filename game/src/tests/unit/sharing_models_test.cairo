#[cfg(test)]
mod tests {
    use dojo_starter::models::sharing::{
        PolicyScope, ResourceAccessGrant, ResourceKind, ResourcePolicy, ResourceShareRule, ShareRuleKind,
        derive_area_resource_key, derive_global_resource_key, derive_hex_resource_key,
        is_grant_effective, is_policy_effective, is_share_rule_effective, select_nearest_policy_scope,
    };

    fn base_policy() -> ResourcePolicy {
        ResourcePolicy {
            resource_key: 101_felt252,
            scope: PolicyScope::Area,
            scope_key: 202_felt252,
            resource_kind: ResourceKind::Mine,
            controller_adventurer_id: 303_felt252,
            policy_epoch: 3_u32,
            is_enabled: true,
            updated_block: 9_u64,
            last_mutation_block: 9_u64,
        }
    }

    #[test]
    fn sharing_models_resource_keys_are_deterministic_and_domain_separated() {
        let area_a = derive_area_resource_key(11_felt252, ResourceKind::Mine);
        let area_b = derive_area_resource_key(11_felt252, ResourceKind::Mine);
        let area_other = derive_area_resource_key(12_felt252, ResourceKind::Mine);
        let hex_key = derive_hex_resource_key(11_felt252, ResourceKind::Mine);
        let global_key = derive_global_resource_key(ResourceKind::Mine);

        assert(area_a == area_b, 'SHM_KEY_DET');
        assert(area_a != area_other, 'SHM_KEY_AREA');
        assert(area_a != hex_key, 'SHM_KEY_SCOPE');
        assert(hex_key != global_key, 'SHM_KEY_GLBL');
    }

    #[test]
    fn sharing_models_epoch_and_activation_guards_apply() {
        let policy = base_policy();
        assert(is_policy_effective(policy), 'SHM_POL_ON');
        assert(
            !is_policy_effective(ResourcePolicy { is_enabled: false, ..policy }),
            'SHM_POL_OFF',
        );
        assert(
            !is_policy_effective(ResourcePolicy { controller_adventurer_id: 0_felt252, ..policy }),
            'SHM_POL_CTRL0',
        );

        let grant = ResourceAccessGrant {
            resource_key: 101_felt252,
            grantee_adventurer_id: 404_felt252,
            permissions_mask: 3_u16,
            granted_by_adventurer_id: 303_felt252,
            grant_block: 10_u64,
            revoke_block: 0_u64,
            is_active: true,
            policy_epoch: 3_u32,
        };
        assert(is_grant_effective(grant, 3_u32), 'SHM_GRANT_ON');
        assert(!is_grant_effective(ResourceAccessGrant { is_active: false, ..grant }, 3_u32), 'SHM_GRANT_OFF');
        assert(
            !is_grant_effective(ResourceAccessGrant { policy_epoch: 2_u32, ..grant }, 3_u32),
            'SHM_GRANT_EPOCH',
        );

        let rule = ResourceShareRule {
            resource_key: 101_felt252,
            recipient_adventurer_id: 505_felt252,
            rule_kind: ShareRuleKind::OutputItem,
            share_bp: 2_500_u16,
            is_active: true,
            policy_epoch: 3_u32,
            updated_block: 11_u64,
        };
        assert(is_share_rule_effective(rule, 3_u32), 'SHM_RULE_ON');
        assert(!is_share_rule_effective(ResourceShareRule { is_active: false, ..rule }, 3_u32), 'SHM_RULE_OFF');
        assert(
            !is_share_rule_effective(ResourceShareRule { policy_epoch: 2_u32, ..rule }, 3_u32),
            'SHM_RULE_EPOCH',
        );
    }

    #[test]
    fn sharing_models_scope_resolution_prefers_area_then_hex_then_global() {
        let area_policy = base_policy();
        let hex_policy = ResourcePolicy { scope: PolicyScope::Hex, ..area_policy };
        let global_policy = ResourcePolicy { scope: PolicyScope::Global, ..area_policy };
        let none_policy = ResourcePolicy {
            scope: PolicyScope::None,
            is_enabled: false,
            controller_adventurer_id: 0_felt252,
            ..area_policy
        };

        let pick_area = select_nearest_policy_scope(area_policy, hex_policy, global_policy);
        let pick_hex = select_nearest_policy_scope(none_policy, hex_policy, global_policy);
        let pick_global = select_nearest_policy_scope(none_policy, none_policy, global_policy);
        let pick_none = select_nearest_policy_scope(none_policy, none_policy, none_policy);

        assert(pick_area == PolicyScope::Area, 'SHM_SCOPE_AREA');
        assert(pick_hex == PolicyScope::Hex, 'SHM_SCOPE_HEX');
        assert(pick_global == PolicyScope::Global, 'SHM_SCOPE_GLBL');
        assert(pick_none == PolicyScope::None, 'SHM_SCOPE_NONE');
    }
}
