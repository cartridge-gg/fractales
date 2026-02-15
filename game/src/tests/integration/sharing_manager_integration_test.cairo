#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};
    use dojo_starter::events::sharing_events::{
        ResourceAccessGranted, ResourceAccessRevoked, ResourcePermissionRejected, ResourcePolicyUpserted,
        ResourceShareRuleCleared, ResourceShareRuleSet,
    };
    use dojo_starter::libs::sharing_math::{PERM_BUILD, PERM_EXTRACT, PERM_INSPECT, PERM_ALL};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::sharing::{
        ResourceAccessGrant, ResourceKind, ResourcePolicy, ResourceShareRule, ShareRuleKind,
    };
    use dojo_starter::systems::sharing_manager_contract::{
        ISharingManagerDispatcher, ISharingManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("ResourcePolicy"),
                TestResource::Model("ResourceAccessGrant"),
                TestResource::Model("ResourceShareRule"),
                TestResource::Model("ResourceShareRuleTally"),
                TestResource::Event("ResourcePolicyUpserted"),
                TestResource::Event("ResourceAccessGranted"),
                TestResource::Event("ResourceAccessRevoked"),
                TestResource::Event("ResourceShareRuleSet"),
                TestResource::Event("ResourceShareRuleCleared"),
                TestResource::Event("ResourcePermissionRejected"),
                TestResource::Contract("sharing_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"sharing_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        energy: u16,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'SHR'_felt252,
                energy,
                max_energy: energy,
                current_hex: 0_felt252,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
    }

    #[test]
    fn sharing_manager_integration_policy_grant_share_and_inspect() {
        let caller = get_default_caller_address();
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"sharing_manager").unwrap();
        let manager = ISharingManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let controller_id = 9101_felt252;
        let grantee_id = 9102_felt252;
        let recipient_id = 9103_felt252;
        let resource_key = 9201_felt252;

        setup_actor(ref world, controller_id, caller, 100_u16);
        setup_actor(ref world, grantee_id, caller, 100_u16);
        setup_actor(ref world, recipient_id, caller, 100_u16);

        let upserted = manager.upsert_resource_policy(
            controller_id, resource_key, ResourceKind::Mine, true,
        );
        assert(upserted, 'SH_INT_UPSERT');

        set_block_number(250_u64);
        let granted = manager.grant_resource_access(
            controller_id, resource_key, grantee_id, PERM_INSPECT + PERM_EXTRACT + PERM_BUILD,
        );
        assert(granted, 'SH_INT_GRANT');

        let inspected_mask = manager.inspect_resource_permissions(resource_key, grantee_id);
        assert(inspected_mask == PERM_INSPECT + PERM_EXTRACT + PERM_BUILD, 'SH_INT_MASK_GRANTEE');
        let controller_mask = manager.inspect_resource_permissions(resource_key, controller_id);
        assert(controller_mask == PERM_ALL, 'SH_INT_MASK_CTRL');

        set_block_number(400_u64);
        let set_rule = manager.set_resource_share_rule(
            controller_id, resource_key, recipient_id, ShareRuleKind::OutputItem, 2_500_u16,
        );
        assert(set_rule, 'SH_INT_RULE_SET');
        let inspected_share = manager.inspect_resource_share(
            resource_key, recipient_id, ShareRuleKind::OutputItem,
        );
        assert(inspected_share == 2_500_u16, 'SH_INT_SHARE_VAL');

        set_block_number(550_u64);
        let cleared = manager.clear_resource_share_rule(
            controller_id, resource_key, recipient_id, ShareRuleKind::OutputItem,
        );
        assert(cleared, 'SH_INT_RULE_CLR');
        let inspected_share_after = manager.inspect_resource_share(
            resource_key, recipient_id, ShareRuleKind::OutputItem,
        );
        assert(inspected_share_after == 0_u16, 'SH_INT_SHARE_ZERO');

        set_block_number(700_u64);
        let revoked = manager.revoke_resource_access(controller_id, resource_key, grantee_id);
        assert(revoked, 'SH_INT_REVOKE');
        let inspected_after_revoke = manager.inspect_resource_permissions(resource_key, grantee_id);
        assert(inspected_after_revoke == 0_u16, 'SH_INT_MASK_ZERO');

        let policy: ResourcePolicy = world.read_model(resource_key);
        assert(policy.resource_key == resource_key, 'SH_INT_ROW_KEY');
        assert(policy.controller_adventurer_id == controller_id, 'SH_INT_ROW_CTRL');
        assert(policy.is_enabled, 'SH_INT_ROW_ON');

        let grant: ResourceAccessGrant = world.read_model((resource_key, grantee_id));
        assert(!grant.is_active, 'SH_INT_GRANT_OFF');
        let rule: ResourceShareRule = world.read_model(
            (resource_key, recipient_id, ShareRuleKind::OutputItem),
        );
        assert(!rule.is_active, 'SH_INT_RULE_OFF');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let policy_selector = Event::<ResourcePolicyUpserted>::selector(world.namespace_hash);
        let grant_selector = Event::<ResourceAccessGranted>::selector(world.namespace_hash);
        let share_set_selector = Event::<ResourceShareRuleSet>::selector(world.namespace_hash);
        let share_clear_selector = Event::<ResourceShareRuleCleared>::selector(world.namespace_hash);
        let revoke_selector = Event::<ResourceAccessRevoked>::selector(world.namespace_hash);

        let mut policy_count: usize = 0;
        let mut grant_count: usize = 0;
        let mut set_count: usize = 0;
        let mut clear_count: usize = 0;
        let mut revoke_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };

            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted") {
                if event.keys.at(1) == @policy_selector {
                    policy_count += 1;
                } else if event.keys.at(1) == @grant_selector {
                    grant_count += 1;
                } else if event.keys.at(1) == @share_set_selector {
                    set_count += 1;
                } else if event.keys.at(1) == @share_clear_selector {
                    clear_count += 1;
                } else if event.keys.at(1) == @revoke_selector {
                    revoke_count += 1;
                }
            }
            idx += 1;
        };

        assert(policy_count == 1_usize, 'SH_INT_EVT_POLICY');
        assert(grant_count == 1_usize, 'SH_INT_EVT_GRANT');
        assert(set_count == 1_usize, 'SH_INT_EVT_SET');
        assert(clear_count == 1_usize, 'SH_INT_EVT_CLR');
        assert(revoke_count == 1_usize, 'SH_INT_EVT_REVOKE');
    }

    #[test]
    fn sharing_manager_integration_reject_paths_emit_rejections() {
        let caller = get_default_caller_address();
        set_block_number(200_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"sharing_manager").unwrap();
        let manager = ISharingManagerDispatcher { contract_address };
        let mut spy = spy_events();

        let controller_id = 9301_felt252;
        let rogue_id = 9302_felt252;
        let grantee_id = 9303_felt252;
        let resource_key = 9401_felt252;

        setup_actor(ref world, controller_id, caller, 100_u16);
        setup_actor(ref world, rogue_id, caller, 100_u16);
        setup_actor(ref world, grantee_id, caller, 100_u16);

        let upserted = manager.upsert_resource_policy(
            controller_id, resource_key, ResourceKind::Mine, true,
        );
        assert(upserted, 'SH_REJ_UPSERT');

        set_block_number(350_u64);
        let bad_controller = manager.grant_resource_access(
            rogue_id, resource_key, grantee_id, PERM_EXTRACT,
        );
        assert(!bad_controller, 'SH_REJ_CTRL');

        set_block_number(500_u64);
        let bad_mask = manager.grant_resource_access(
            controller_id, resource_key, grantee_id, 0_u16,
        );
        assert(!bad_mask, 'SH_REJ_MASK');

        let grant: ResourceAccessGrant = world.read_model((resource_key, grantee_id));
        assert(!grant.is_active, 'SH_REJ_GRANT_OFF');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let rejected_selector = Event::<ResourcePermissionRejected>::selector(world.namespace_hash);
        let mut rejected_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @rejected_selector {
                rejected_count += 1;
            }
            idx += 1;
        };

        assert(rejected_count == 2_usize, 'SH_REJ_EVT_2');
    }
}
