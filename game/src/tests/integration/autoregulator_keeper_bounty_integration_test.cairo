#[cfg(test)]
mod tests {
    use core::traits::TryInto;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        set_block_number, spawn_test_world,
    };
    use dojo_starter::models::economics::{
        EconomyEpochSnapshot, RegulatorConfig, RegulatorPolicy, RegulatorState, RegulatorTreasury,
    };
    use dojo_starter::systems::autoregulator_manager::TickStatus;
    use dojo_starter::systems::autoregulator_manager_contract::{
        IAutoregulatorManagerDispatcher, IAutoregulatorManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("RegulatorState"),
                TestResource::Model("RegulatorPolicy"),
                TestResource::Model("RegulatorConfig"),
                TestResource::Model("RegulatorTreasury"),
                TestResource::Model("EconomyEpochSnapshot"),
                TestResource::Event("RegulatorTicked"),
                TestResource::Event("RegulatorPolicyUpdated"),
                TestResource::Event("BountyPaid"),
                TestResource::Contract("autoregulator_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"autoregulator_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn write_defaults(ref world: dojo::world::WorldStorage, pool: u64) {
        world.write_model_test(
            @RegulatorState {
                slot: 1_u8,
                has_ticked: false,
                last_tick_block: 0_u64,
                last_tick_epoch: 0_u32,
            },
        );
        world.write_model_test(
            @RegulatorPolicy {
                slot: 1_u8,
                policy_epoch: 0_u32,
                conversion_tax_bp: 300_u16,
                upkeep_bp: 10_000_u16,
                mint_discount_bp: 0_u16,
            },
        );
        world.write_model_test(
            @RegulatorConfig {
                slot: 1_u8,
                epoch_blocks: 100_u64,
                keeper_bounty_energy: 10_u16,
                keeper_bounty_max: 20_u16,
                bounty_funding_share_bp: 100_u16,
                inflation_target_pct: 10_u16,
                inflation_deadband_pct: 1_u16,
                policy_slew_limit_bp: 100_u16,
                min_conversion_tax_bp: 100_u16,
                max_conversion_tax_bp: 5000_u16,
            },
        );
        world.write_model_test(
            @RegulatorTreasury {
                slot: 1_u8,
                regulator_bounty_pool: pool,
                last_bounty_epoch: 0_u32,
                last_bounty_paid: 0_u16,
                last_bounty_caller: 0.try_into().unwrap(),
            },
        );
        world.write_model_test(
            @EconomyEpochSnapshot {
                epoch: 0_u32,
                total_sources: 0_u64,
                total_sinks: 0_u64,
                net_energy: 0_u64,
                new_hexes: 0_u32,
                deaths: 0_u32,
                mints: 0_u32,
                finalized_at_block: 0_u64,
                is_finalized: false,
            },
        );
    }

    #[test]
    fn tick_first_valid_call_applies_and_pays_bounty() {
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 100_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let outcome = manager.tick_autoregulator();
        assert(outcome.status == TickStatus::Applied, 'ARC_INT_APPLY');
        assert(outcome.bounty_paid == 10_u16, 'ARC_INT_BOUNTY');

        let state: RegulatorState = world.read_model(1_u8);
        let treasury: RegulatorTreasury = world.read_model(1_u8);
        assert(state.last_tick_epoch == 1_u32, 'ARC_INT_EPOCH');
        assert(treasury.regulator_bounty_pool == 90_u64, 'ARC_INT_POOL');
    }

    #[test]
    fn tick_second_call_same_epoch_noop_and_zero_bounty() {
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 100_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let _first = manager.tick_autoregulator();
        set_block_number(150_u64);
        let second = manager.tick_autoregulator();

        assert(second.status == TickStatus::NoOpAlreadyTicked, 'ARC_INT_REPLAY');
        assert(second.bounty_paid == 0_u16, 'ARC_INT_REPLAY_BOUNTY');

        let treasury: RegulatorTreasury = world.read_model(1_u8);
        assert(treasury.regulator_bounty_pool == 90_u64, 'ARC_INT_REPLAY_POOL');
    }

    #[test]
    fn tick_before_boundary_noop_and_zero_bounty() {
        set_block_number(50_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 100_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let outcome = manager.tick_autoregulator();

        assert(outcome.status == TickStatus::NoOpEarly, 'ARC_INT_EARLY');
        assert(outcome.bounty_paid == 0_u16, 'ARC_INT_EARLY_BOUNTY');

        let treasury: RegulatorTreasury = world.read_model(1_u8);
        assert(treasury.regulator_bounty_pool == 100_u64, 'ARC_INT_EARLY_POOL');
    }

    #[test]
    fn tick_low_bounty_pool_clips_payout_without_revert() {
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 4_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let outcome = manager.tick_autoregulator();

        assert(outcome.status == TickStatus::Applied, 'ARC_INT_CLIP_STATUS');
        assert(outcome.bounty_paid == 4_u16, 'ARC_INT_CLIP_BOUNTY');

        let treasury: RegulatorTreasury = world.read_model(1_u8);
        assert(treasury.regulator_bounty_pool == 0_u64, 'ARC_INT_CLIP_POOL');
    }

    #[test]
    fn bounty_pool_never_negative() {
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 0_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let outcome = manager.tick_autoregulator();

        assert(outcome.status == TickStatus::Applied, 'ARC_INT_ZERO_STATUS');
        assert(outcome.bounty_paid == 0_u16, 'ARC_INT_ZERO_BOUNTY');

        let treasury: RegulatorTreasury = world.read_model(1_u8);
        assert(treasury.regulator_bounty_pool == 0_u64, 'ARC_INT_ZERO_POOL');
    }

    #[test]
    fn policy_updates_even_if_bounty_zero() {
        set_block_number(100_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        write_defaults(ref world, 0_u64);

        let (contract_address, _) = world.dns(@"autoregulator_manager").unwrap();
        let manager = IAutoregulatorManagerDispatcher { contract_address };

        let outcome = manager.tick_autoregulator();

        assert(outcome.status == TickStatus::Applied, 'ARC_INT_POL_STATUS');
        assert(outcome.policy_changed, 'ARC_INT_POL_CHANGED');

        let policy: RegulatorPolicy = world.read_model(1_u8);
        assert(policy.policy_epoch == 1_u32, 'ARC_INT_POL_EPOCH');
    }
}
