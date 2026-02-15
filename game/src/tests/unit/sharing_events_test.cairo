#[cfg(test)]
mod tests {
    use dojo_starter::events::sharing_events::{
        ResourceAccessGranted, ResourceAccessRevoked, ResourcePermissionRejected, ResourcePolicyUpserted,
        ResourceShareRuleCleared, ResourceShareRuleSet,
    };
    use dojo_starter::models::sharing::{PolicyScope, ResourceKind, ShareRuleKind};

    #[test]
    fn sharing_events_policy_and_access_payload_shape() {
        let policy = ResourcePolicyUpserted {
            resource_key: 8001_felt252,
            scope: PolicyScope::Area,
            scope_key: 8101_felt252,
            resource_kind: ResourceKind::Mine,
            controller_adventurer_id: 8201_felt252,
            policy_epoch: 2_u32,
            is_enabled: true,
            updated_block: 900_u64,
        };
        assert(policy.resource_key == 8001_felt252, 'SH_EVT_POL_KEY');
        assert(policy.scope == PolicyScope::Area, 'SH_EVT_POL_SCOPE');
        assert(policy.controller_adventurer_id == 8201_felt252, 'SH_EVT_POL_CTRL');
        assert(policy.policy_epoch == 2_u32, 'SH_EVT_POL_EPOCH');
        assert(policy.is_enabled, 'SH_EVT_POL_ON');

        let granted = ResourceAccessGranted {
            resource_key: 8001_felt252,
            grantee_adventurer_id: 8301_felt252,
            granted_by_adventurer_id: 8201_felt252,
            permissions_mask: 3_u16,
            policy_epoch: 2_u32,
        };
        assert(granted.grantee_adventurer_id == 8301_felt252, 'SH_EVT_GRANT_TO');
        assert(granted.permissions_mask == 3_u16, 'SH_EVT_GRANT_MASK');

        let revoked = ResourceAccessRevoked {
            resource_key: 8001_felt252,
            grantee_adventurer_id: 8301_felt252,
            revoked_by_adventurer_id: 8201_felt252,
            policy_epoch: 2_u32,
        };
        assert(revoked.revoked_by_adventurer_id == 8201_felt252, 'SH_EVT_REV_BY');
    }

    #[test]
    fn sharing_events_share_and_rejection_payload_shape() {
        let set_rule = ResourceShareRuleSet {
            resource_key: 8010_felt252,
            recipient_adventurer_id: 8401_felt252,
            rule_kind: ShareRuleKind::OutputItem,
            share_bp: 2_500_u16,
            policy_epoch: 5_u32,
        };
        assert(set_rule.rule_kind == ShareRuleKind::OutputItem, 'SH_EVT_RULE_KIND');
        assert(set_rule.share_bp == 2_500_u16, 'SH_EVT_RULE_BP');

        let cleared = ResourceShareRuleCleared {
            resource_key: 8010_felt252,
            recipient_adventurer_id: 8401_felt252,
            rule_kind: ShareRuleKind::OutputItem,
            policy_epoch: 5_u32,
        };
        assert(cleared.policy_epoch == 5_u32, 'SH_EVT_CLR_EPOCH');

        let rejected = ResourcePermissionRejected {
            adventurer_id: 8501_felt252,
            resource_key: 8010_felt252,
            action: 'GRANT'_felt252,
            reason: 'NOT_CTRL'_felt252,
        };
        assert(rejected.adventurer_id == 8501_felt252, 'SH_EVT_REJ_ADV');
        assert(rejected.action == 'GRANT'_felt252, 'SH_EVT_REJ_ACT');
    }
}
