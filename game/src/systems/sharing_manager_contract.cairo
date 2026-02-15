#[starknet::interface]
pub trait ISharingManager<T> {
    fn upsert_resource_policy(
        ref self: T,
        controller_adventurer_id: felt252,
        resource_key: felt252,
        resource_kind: dojo_starter::models::sharing::ResourceKind,
        is_enabled: bool,
    ) -> bool;
    fn grant_resource_access(
        ref self: T,
        controller_adventurer_id: felt252,
        resource_key: felt252,
        grantee_adventurer_id: felt252,
        permissions_mask: u16,
    ) -> bool;
    fn revoke_resource_access(
        ref self: T, controller_adventurer_id: felt252, resource_key: felt252, grantee_adventurer_id: felt252,
    ) -> bool;
    fn set_resource_share_rule(
        ref self: T,
        controller_adventurer_id: felt252,
        resource_key: felt252,
        recipient_adventurer_id: felt252,
        rule_kind: dojo_starter::models::sharing::ShareRuleKind,
        share_bp: u16,
    ) -> bool;
    fn clear_resource_share_rule(
        ref self: T,
        controller_adventurer_id: felt252,
        resource_key: felt252,
        recipient_adventurer_id: felt252,
        rule_kind: dojo_starter::models::sharing::ShareRuleKind,
    ) -> bool;
    fn inspect_resource_permissions(self: @T, resource_key: felt252, adventurer_id: felt252) -> u16;
    fn inspect_resource_share(
        self: @T,
        resource_key: felt252,
        recipient_adventurer_id: felt252,
        rule_kind: dojo_starter::models::sharing::ShareRuleKind,
    ) -> u16;
}

#[dojo::contract]
pub mod sharing_manager {
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::sharing_events::{
        ResourceAccessGranted, ResourceAccessRevoked, ResourcePermissionRejected, ResourcePolicyUpserted,
        ResourceShareRuleCleared, ResourceShareRuleSet,
    };
    use dojo_starter::libs::sharing_math::PERM_ALL;
    use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by, spend_energy};
    use dojo_starter::models::sharing::{
        PolicyScope, ResourceAccessGrant, ResourceKind, ResourcePolicy, ResourceShareRule,
        ResourceShareRuleTally, ShareRuleKind, is_grant_effective, is_policy_effective,
        is_share_rule_effective,
    };
    use dojo_starter::systems::sharing_manager::{
        AccessGrantOutcome, AccessRevokeOutcome, PolicyUpsertOutcome, ShareRuleClearOutcome,
        ShareRuleSetOutcome, clear_share_rule_transition, grant_access_transition, revoke_access_transition,
        set_share_rule_transition, upsert_policy_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    use super::ISharingManager;

    const ACTION_POLICY: felt252 = 'SH_POLICY'_felt252;
    const ACTION_GRANT: felt252 = 'SH_GRANT'_felt252;
    const ACTION_REVOKE: felt252 = 'SH_REVOKE'_felt252;
    const ACTION_SHARE_SET: felt252 = 'SH_SET'_felt252;
    const ACTION_SHARE_CLEAR: felt252 = 'SH_CLEAR'_felt252;

    fn actor_flags(adventurer: Adventurer, actor_id: felt252, caller: starknet::ContractAddress) -> (bool, bool) {
        let alive = adventurer.adventurer_id == actor_id && adventurer.is_alive;
        let controls = alive && can_be_controlled_by(adventurer, caller);
        (alive, controls)
    }

    fn emit_rejection(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        resource_key: felt252,
        action: felt252,
        reason: felt252,
    ) {
        world.emit_event(@ResourcePermissionRejected { adventurer_id, resource_key, action, reason });
    }

    fn load_policy(ref world: dojo::world::WorldStorage, resource_key: felt252) -> ResourcePolicy {
        let mut policy: ResourcePolicy = world.read_model(resource_key);
        policy.resource_key = resource_key;
        policy
    }

    fn load_grant(
        ref world: dojo::world::WorldStorage, resource_key: felt252, grantee_adventurer_id: felt252,
    ) -> ResourceAccessGrant {
        let mut grant: ResourceAccessGrant = world.read_model((resource_key, grantee_adventurer_id));
        grant.resource_key = resource_key;
        grant.grantee_adventurer_id = grantee_adventurer_id;
        grant
    }

    fn load_share_rule(
        ref world: dojo::world::WorldStorage,
        resource_key: felt252,
        recipient_adventurer_id: felt252,
        rule_kind: ShareRuleKind,
    ) -> ResourceShareRule {
        let mut rule: ResourceShareRule = world.read_model((resource_key, recipient_adventurer_id, rule_kind));
        rule.resource_key = resource_key;
        rule.recipient_adventurer_id = recipient_adventurer_id;
        rule.rule_kind = rule_kind;
        rule
    }

    fn load_share_tally(
        ref world: dojo::world::WorldStorage, resource_key: felt252, rule_kind: ShareRuleKind,
    ) -> ResourceShareRuleTally {
        let mut tally: ResourceShareRuleTally = world.read_model((resource_key, rule_kind));
        tally.resource_key = resource_key;
        tally.rule_kind = rule_kind;
        tally
    }

    fn clear_tally_recipients(mut tally: ResourceShareRuleTally) -> ResourceShareRuleTally {
        tally.recipient_0 = 0_felt252;
        tally.recipient_1 = 0_felt252;
        tally.recipient_2 = 0_felt252;
        tally.recipient_3 = 0_felt252;
        tally.recipient_4 = 0_felt252;
        tally.recipient_5 = 0_felt252;
        tally.recipient_6 = 0_felt252;
        tally.recipient_7 = 0_felt252;
        tally
    }

    fn tally_has_recipient(tally: ResourceShareRuleTally, recipient_adventurer_id: felt252) -> bool {
        tally.recipient_0 == recipient_adventurer_id || tally.recipient_1 == recipient_adventurer_id
            || tally.recipient_2 == recipient_adventurer_id || tally.recipient_3 == recipient_adventurer_id
            || tally.recipient_4 == recipient_adventurer_id || tally.recipient_5 == recipient_adventurer_id
            || tally.recipient_6 == recipient_adventurer_id || tally.recipient_7 == recipient_adventurer_id
    }

    fn tally_insert_recipient(
        mut tally: ResourceShareRuleTally, recipient_adventurer_id: felt252,
    ) -> ResourceShareRuleTally {
        if recipient_adventurer_id == 0_felt252 || tally_has_recipient(tally, recipient_adventurer_id) {
            return tally;
        }

        if tally.recipient_0 == 0_felt252 {
            tally.recipient_0 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_1 == 0_felt252 {
            tally.recipient_1 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_2 == 0_felt252 {
            tally.recipient_2 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_3 == 0_felt252 {
            tally.recipient_3 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_4 == 0_felt252 {
            tally.recipient_4 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_5 == 0_felt252 {
            tally.recipient_5 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_6 == 0_felt252 {
            tally.recipient_6 = recipient_adventurer_id;
            return tally;
        }
        if tally.recipient_7 == 0_felt252 {
            tally.recipient_7 = recipient_adventurer_id;
            return tally;
        }
        tally
    }

    fn tally_remove_recipient(
        mut tally: ResourceShareRuleTally, recipient_adventurer_id: felt252,
    ) -> ResourceShareRuleTally {
        if tally.recipient_0 == recipient_adventurer_id {
            tally.recipient_0 = 0_felt252;
        }
        if tally.recipient_1 == recipient_adventurer_id {
            tally.recipient_1 = 0_felt252;
        }
        if tally.recipient_2 == recipient_adventurer_id {
            tally.recipient_2 = 0_felt252;
        }
        if tally.recipient_3 == recipient_adventurer_id {
            tally.recipient_3 = 0_felt252;
        }
        if tally.recipient_4 == recipient_adventurer_id {
            tally.recipient_4 = 0_felt252;
        }
        if tally.recipient_5 == recipient_adventurer_id {
            tally.recipient_5 = 0_felt252;
        }
        if tally.recipient_6 == recipient_adventurer_id {
            tally.recipient_6 = 0_felt252;
        }
        if tally.recipient_7 == recipient_adventurer_id {
            tally.recipient_7 = 0_felt252;
        }
        tally
    }

    fn spend_actor_energy_or_reject(
        ref world: dojo::world::WorldStorage,
        mut adventurer: Adventurer,
        energy_cost: u16,
        action: felt252,
        resource_key: felt252,
    ) -> Option<Adventurer> {
        match spend_energy(adventurer, energy_cost) {
            Option::Some(charged) => Option::Some(charged),
            Option::None => {
                emit_rejection(
                    ref world, adventurer.adventurer_id, resource_key, action, 'LOW_ENERGY'_felt252,
                );
                Option::None
            },
        }
    }

    fn upsert_reason(outcome: PolicyUpsertOutcome) -> felt252 {
        match outcome {
            PolicyUpsertOutcome::Dead => 'DEAD'_felt252,
            PolicyUpsertOutcome::NotOwner => 'NOT_OWNER'_felt252,
            PolicyUpsertOutcome::InvalidController => 'BAD_CTRL'_felt252,
            PolicyUpsertOutcome::NotController => 'NOT_CTRL'_felt252,
            PolicyUpsertOutcome::Cooldown => 'COOLDOWN'_felt252,
            PolicyUpsertOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn grant_reason(outcome: AccessGrantOutcome) -> felt252 {
        match outcome {
            AccessGrantOutcome::Dead => 'DEAD'_felt252,
            AccessGrantOutcome::NotOwner => 'NOT_OWNER'_felt252,
            AccessGrantOutcome::PolicyDisabled => 'POLICY_OFF'_felt252,
            AccessGrantOutcome::NotController => 'NOT_CTRL'_felt252,
            AccessGrantOutcome::Cooldown => 'COOLDOWN'_felt252,
            AccessGrantOutcome::InvalidPermissions => 'BAD_MASK'_felt252,
            AccessGrantOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn revoke_reason(outcome: AccessRevokeOutcome) -> felt252 {
        match outcome {
            AccessRevokeOutcome::Dead => 'DEAD'_felt252,
            AccessRevokeOutcome::NotOwner => 'NOT_OWNER'_felt252,
            AccessRevokeOutcome::PolicyDisabled => 'POLICY_OFF'_felt252,
            AccessRevokeOutcome::NotController => 'NOT_CTRL'_felt252,
            AccessRevokeOutcome::Cooldown => 'COOLDOWN'_felt252,
            AccessRevokeOutcome::NotGranted => 'NOT_GRANTED'_felt252,
            AccessRevokeOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn set_rule_reason(outcome: ShareRuleSetOutcome) -> felt252 {
        match outcome {
            ShareRuleSetOutcome::Dead => 'DEAD'_felt252,
            ShareRuleSetOutcome::NotOwner => 'NOT_OWNER'_felt252,
            ShareRuleSetOutcome::PolicyDisabled => 'POLICY_OFF'_felt252,
            ShareRuleSetOutcome::NotController => 'NOT_CTRL'_felt252,
            ShareRuleSetOutcome::Cooldown => 'COOLDOWN'_felt252,
            ShareRuleSetOutcome::InvalidRecipient => 'BAD_RECIP'_felt252,
            ShareRuleSetOutcome::InvalidShare => 'BAD_SHARE'_felt252,
            ShareRuleSetOutcome::ShareOverflow => 'OVERFLOW'_felt252,
            ShareRuleSetOutcome::RecipientLimit => 'RECIP_CAP'_felt252,
            ShareRuleSetOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    fn clear_rule_reason(outcome: ShareRuleClearOutcome) -> felt252 {
        match outcome {
            ShareRuleClearOutcome::Dead => 'DEAD'_felt252,
            ShareRuleClearOutcome::NotOwner => 'NOT_OWNER'_felt252,
            ShareRuleClearOutcome::PolicyDisabled => 'POLICY_OFF'_felt252,
            ShareRuleClearOutcome::NotController => 'NOT_CTRL'_felt252,
            ShareRuleClearOutcome::Cooldown => 'COOLDOWN'_felt252,
            ShareRuleClearOutcome::NotFound => 'NOT_FOUND'_felt252,
            ShareRuleClearOutcome::Applied => 'APPLIED'_felt252,
        }
    }

    #[abi(embed_v0)]
    impl SharingManagerImpl of ISharingManager<ContractState> {
        fn upsert_resource_policy(
            ref self: ContractState,
            controller_adventurer_id: felt252,
            resource_key: felt252,
            resource_kind: ResourceKind,
            is_enabled: bool,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let actor: Adventurer = world.read_model(controller_adventurer_id);
            let (actor_alive, actor_controls) = actor_flags(actor, controller_adventurer_id, caller);
            let policy = load_policy(ref world, resource_key);

            let transitioned = upsert_policy_transition(
                policy,
                controller_adventurer_id,
                actor_alive,
                actor_controls,
                controller_adventurer_id,
                resource_key,
                PolicyScope::Area,
                resource_key,
                resource_kind,
                is_enabled,
                now_block,
            );

            match transitioned.outcome {
                PolicyUpsertOutcome::Applied => {
                    let charged = spend_actor_energy_or_reject(
                        ref world, actor, transitioned.energy_cost, ACTION_POLICY, resource_key,
                    );
                    match charged {
                        Option::Some(charged_actor) => {
                            world.write_model(@charged_actor);
                            world.write_model(@transitioned.policy);
                            world.emit_event(
                                @ResourcePolicyUpserted {
                                    resource_key: transitioned.policy.resource_key,
                                    scope: transitioned.policy.scope,
                                    scope_key: transitioned.policy.scope_key,
                                    resource_kind: transitioned.policy.resource_kind,
                                    controller_adventurer_id: transitioned.policy.controller_adventurer_id,
                                    policy_epoch: transitioned.policy.policy_epoch,
                                    is_enabled: transitioned.policy.is_enabled,
                                    updated_block: transitioned.policy.updated_block,
                                },
                            );
                            true
                        },
                        Option::None => false,
                    }
                },
                _ => {
                    emit_rejection(
                        ref world,
                        controller_adventurer_id,
                        resource_key,
                        ACTION_POLICY,
                        upsert_reason(transitioned.outcome),
                    );
                    false
                },
            }
        }

        fn grant_resource_access(
            ref self: ContractState,
            controller_adventurer_id: felt252,
            resource_key: felt252,
            grantee_adventurer_id: felt252,
            permissions_mask: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let actor: Adventurer = world.read_model(controller_adventurer_id);
            let (actor_alive, actor_controls) = actor_flags(actor, controller_adventurer_id, caller);
            let policy = load_policy(ref world, resource_key);
            let grant = load_grant(ref world, resource_key, grantee_adventurer_id);

            let transitioned = grant_access_transition(
                policy,
                grant,
                controller_adventurer_id,
                actor_alive,
                actor_controls,
                grantee_adventurer_id,
                permissions_mask,
                now_block,
            );

            match transitioned.outcome {
                AccessGrantOutcome::Applied => {
                    let charged = spend_actor_energy_or_reject(
                        ref world, actor, transitioned.energy_cost, ACTION_GRANT, resource_key,
                    );
                    match charged {
                        Option::Some(charged_actor) => {
                            world.write_model(@charged_actor);
                            world.write_model(@transitioned.policy);
                            world.write_model(@transitioned.grant);
                            world.emit_event(
                                @ResourceAccessGranted {
                                    resource_key,
                                    grantee_adventurer_id,
                                    granted_by_adventurer_id: controller_adventurer_id,
                                    permissions_mask: transitioned.grant.permissions_mask,
                                    policy_epoch: transitioned.policy.policy_epoch,
                                },
                            );
                            true
                        },
                        Option::None => false,
                    }
                },
                _ => {
                    emit_rejection(
                        ref world,
                        controller_adventurer_id,
                        resource_key,
                        ACTION_GRANT,
                        grant_reason(transitioned.outcome),
                    );
                    false
                },
            }
        }

        fn revoke_resource_access(
            ref self: ContractState, controller_adventurer_id: felt252, resource_key: felt252, grantee_adventurer_id: felt252,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let actor: Adventurer = world.read_model(controller_adventurer_id);
            let (actor_alive, actor_controls) = actor_flags(actor, controller_adventurer_id, caller);
            let policy = load_policy(ref world, resource_key);
            let grant = load_grant(ref world, resource_key, grantee_adventurer_id);

            let transitioned = revoke_access_transition(
                policy, grant, controller_adventurer_id, actor_alive, actor_controls, now_block,
            );
            match transitioned.outcome {
                AccessRevokeOutcome::Applied => {
                    let charged = spend_actor_energy_or_reject(
                        ref world, actor, transitioned.energy_cost, ACTION_REVOKE, resource_key,
                    );
                    match charged {
                        Option::Some(charged_actor) => {
                            world.write_model(@charged_actor);
                            world.write_model(@transitioned.policy);
                            world.write_model(@transitioned.grant);
                            world.emit_event(
                                @ResourceAccessRevoked {
                                    resource_key,
                                    grantee_adventurer_id,
                                    revoked_by_adventurer_id: controller_adventurer_id,
                                    policy_epoch: transitioned.policy.policy_epoch,
                                },
                            );
                            true
                        },
                        Option::None => false,
                    }
                },
                _ => {
                    emit_rejection(
                        ref world,
                        controller_adventurer_id,
                        resource_key,
                        ACTION_REVOKE,
                        revoke_reason(transitioned.outcome),
                    );
                    false
                },
            }
        }

        fn set_resource_share_rule(
            ref self: ContractState,
            controller_adventurer_id: felt252,
            resource_key: felt252,
            recipient_adventurer_id: felt252,
            rule_kind: ShareRuleKind,
            share_bp: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let actor: Adventurer = world.read_model(controller_adventurer_id);
            let (actor_alive, actor_controls) = actor_flags(actor, controller_adventurer_id, caller);
            let policy = load_policy(ref world, resource_key);
            let mut tally = load_share_tally(ref world, resource_key, rule_kind);
            if tally.policy_epoch != policy.policy_epoch {
                tally.total_bp = 0_u16;
                tally.active_recipient_count = 0_u8;
                tally.policy_epoch = policy.policy_epoch;
                tally = clear_tally_recipients(tally);
            }

            let rule = load_share_rule(ref world, resource_key, recipient_adventurer_id, rule_kind);
            let prior_rule = rule;
            let transitioned = set_share_rule_transition(
                policy,
                rule,
                controller_adventurer_id,
                actor_alive,
                actor_controls,
                recipient_adventurer_id,
                rule_kind,
                share_bp,
                tally.total_bp,
                tally.active_recipient_count,
                now_block,
            );
            match transitioned.outcome {
                ShareRuleSetOutcome::Applied => {
                    let charged = spend_actor_energy_or_reject(
                        ref world, actor, transitioned.energy_cost, ACTION_SHARE_SET, resource_key,
                    );
                    match charged {
                        Option::Some(charged_actor) => {
                            let prior_share = if is_share_rule_effective(prior_rule, transitioned.policy.policy_epoch) {
                                prior_rule.share_bp
                            } else {
                                0_u16
                            };
                            let base_total = if tally.total_bp >= prior_share {
                                tally.total_bp - prior_share
                            } else {
                                0_u16
                            };
                            tally.total_bp = base_total + transitioned.rule.share_bp;
                            if prior_share == 0_u16 && tally.active_recipient_count < 255_u8 {
                                tally.active_recipient_count += 1_u8;
                            }
                            if prior_share == 0_u16 {
                                tally = tally_insert_recipient(tally, recipient_adventurer_id);
                            }
                            tally.policy_epoch = transitioned.policy.policy_epoch;
                            tally.updated_block = now_block;

                            world.write_model(@charged_actor);
                            world.write_model(@transitioned.policy);
                            world.write_model(@transitioned.rule);
                            world.write_model(@tally);
                            world.emit_event(
                                @ResourceShareRuleSet {
                                    resource_key,
                                    recipient_adventurer_id,
                                    rule_kind,
                                    share_bp: transitioned.rule.share_bp,
                                    policy_epoch: transitioned.policy.policy_epoch,
                                },
                            );
                            true
                        },
                        Option::None => false,
                    }
                },
                _ => {
                    emit_rejection(
                        ref world,
                        controller_adventurer_id,
                        resource_key,
                        ACTION_SHARE_SET,
                        set_rule_reason(transitioned.outcome),
                    );
                    false
                },
            }
        }

        fn clear_resource_share_rule(
            ref self: ContractState,
            controller_adventurer_id: felt252,
            resource_key: felt252,
            recipient_adventurer_id: felt252,
            rule_kind: ShareRuleKind,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let actor: Adventurer = world.read_model(controller_adventurer_id);
            let (actor_alive, actor_controls) = actor_flags(actor, controller_adventurer_id, caller);
            let policy = load_policy(ref world, resource_key);
            let mut tally = load_share_tally(ref world, resource_key, rule_kind);
            if tally.policy_epoch != policy.policy_epoch {
                tally.total_bp = 0_u16;
                tally.active_recipient_count = 0_u8;
                tally.policy_epoch = policy.policy_epoch;
                tally = clear_tally_recipients(tally);
            }

            let rule = load_share_rule(ref world, resource_key, recipient_adventurer_id, rule_kind);
            let prior_rule = rule;
            let transitioned = clear_share_rule_transition(
                policy, rule, controller_adventurer_id, actor_alive, actor_controls, now_block,
            );
            match transitioned.outcome {
                ShareRuleClearOutcome::Applied => {
                    let charged = spend_actor_energy_or_reject(
                        ref world, actor, transitioned.energy_cost, ACTION_SHARE_CLEAR, resource_key,
                    );
                    match charged {
                        Option::Some(charged_actor) => {
                            let prior_share = if is_share_rule_effective(prior_rule, transitioned.policy.policy_epoch) {
                                prior_rule.share_bp
                            } else {
                                0_u16
                            };
                            if prior_share > 0_u16 {
                                tally.total_bp = if tally.total_bp >= prior_share {
                                    tally.total_bp - prior_share
                                } else {
                                    0_u16
                                };
                                if tally.active_recipient_count > 0_u8 {
                                    tally.active_recipient_count -= 1_u8;
                                }
                                tally = tally_remove_recipient(tally, recipient_adventurer_id);
                            }
                            tally.policy_epoch = transitioned.policy.policy_epoch;
                            tally.updated_block = now_block;

                            world.write_model(@charged_actor);
                            world.write_model(@transitioned.policy);
                            world.write_model(@transitioned.rule);
                            world.write_model(@tally);
                            world.emit_event(
                                @ResourceShareRuleCleared {
                                    resource_key,
                                    recipient_adventurer_id,
                                    rule_kind,
                                    policy_epoch: transitioned.policy.policy_epoch,
                                },
                            );
                            true
                        },
                        Option::None => false,
                    }
                },
                _ => {
                    emit_rejection(
                        ref world,
                        controller_adventurer_id,
                        resource_key,
                        ACTION_SHARE_CLEAR,
                        clear_rule_reason(transitioned.outcome),
                    );
                    false
                },
            }
        }

        fn inspect_resource_permissions(self: @ContractState, resource_key: felt252, adventurer_id: felt252) -> u16 {
            let mut world = self.world_default();
            let policy = load_policy(ref world, resource_key);
            if !is_policy_effective(policy) {
                return 0_u16;
            }
            if adventurer_id == policy.controller_adventurer_id {
                return PERM_ALL;
            }
            let grant = load_grant(ref world, resource_key, adventurer_id);
            if is_grant_effective(grant, policy.policy_epoch) {
                grant.permissions_mask
            } else {
                0_u16
            }
        }

        fn inspect_resource_share(
            self: @ContractState,
            resource_key: felt252,
            recipient_adventurer_id: felt252,
            rule_kind: ShareRuleKind,
        ) -> u16 {
            let mut world = self.world_default();
            let policy = load_policy(ref world, resource_key);
            if !is_policy_effective(policy) {
                return 0_u16;
            }

            let rule = load_share_rule(ref world, resource_key, recipient_adventurer_id, rule_kind);
            if is_share_rule_effective(rule, policy.policy_epoch) {
                rule.share_bp
            } else {
                0_u16
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
