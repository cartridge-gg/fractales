#[starknet::interface]
pub trait IAutoregulatorManager<T> {
    fn tick_autoregulator(ref self: T) -> dojo_starter::systems::autoregulator_manager::TickOutcome;
    fn get_regulator_policy(self: @T) -> dojo_starter::models::economics::RegulatorPolicy;
    fn get_latest_snapshot(self: @T) -> dojo_starter::models::economics::EconomyEpochSnapshot;
}

#[dojo::contract]
pub mod autoregulator_manager {
    use super::IAutoregulatorManager;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::economic_events::{
        BountyPaid, RegulatorPolicyUpdated, RegulatorTicked,
    };
    use dojo_starter::models::economics::{
        EconomyEpochSnapshot, RegulatorConfig, RegulatorPolicy, RegulatorState, RegulatorTreasury,
    };
    use dojo_starter::systems::autoregulator_manager::{
        TickOutcome, TickStatus, tick_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    const REGULATOR_SLOT: u8 = 1_u8;

    fn tick_status_code(status: TickStatus) -> u8 {
        match status {
            TickStatus::NoOpEarly => 0_u8,
            TickStatus::NoOpAlreadyTicked => 1_u8,
            TickStatus::Applied => 2_u8,
        }
    }

    #[abi(embed_v0)]
    impl AutoregulatorManagerImpl of IAutoregulatorManager<ContractState> {
        fn tick_autoregulator(ref self: ContractState) -> TickOutcome {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let mut state: RegulatorState = world.read_model(REGULATOR_SLOT);
            state.slot = REGULATOR_SLOT;

            let mut policy: RegulatorPolicy = world.read_model(REGULATOR_SLOT);
            policy.slot = REGULATOR_SLOT;

            let mut config: RegulatorConfig = world.read_model(REGULATOR_SLOT);
            config.slot = REGULATOR_SLOT;

            let mut treasury: RegulatorTreasury = world.read_model(REGULATOR_SLOT);
            treasury.slot = REGULATOR_SLOT;

            let ticked = tick_transition(state, policy, config, treasury, now_block, caller);

            match ticked.outcome.status {
                TickStatus::Applied => {
                    world.write_model(@ticked.state);
                    world.write_model(@ticked.policy);
                    world.write_model(@ticked.config);
                    world.write_model(@ticked.treasury);

                    world.emit_event(
                        @RegulatorTicked {
                            epoch: ticked.outcome.epoch,
                            caller,
                            bounty_paid: ticked.outcome.bounty_paid,
                            status: tick_status_code(ticked.outcome.status),
                        },
                    );
                    world.emit_event(
                        @RegulatorPolicyUpdated {
                            epoch: ticked.outcome.epoch,
                            conversion_tax_bp: ticked.policy.conversion_tax_bp,
                            upkeep_bp: ticked.policy.upkeep_bp,
                            mint_discount_bp: ticked.policy.mint_discount_bp,
                        },
                    );

                    if ticked.outcome.bounty_paid > 0_u16 {
                        world.emit_event(
                            @BountyPaid {
                                epoch: ticked.outcome.epoch,
                                caller,
                                amount: ticked.outcome.bounty_paid,
                            },
                        );
                    }
                },
                _ => {},
            }

            ticked.outcome
        }

        fn get_regulator_policy(self: @ContractState) -> RegulatorPolicy {
            let world = self.world_default();
            let mut policy: RegulatorPolicy = world.read_model(REGULATOR_SLOT);
            policy.slot = REGULATOR_SLOT;
            policy
        }

        fn get_latest_snapshot(self: @ContractState) -> EconomyEpochSnapshot {
            let world = self.world_default();
            let mut state: RegulatorState = world.read_model(REGULATOR_SLOT);
            state.slot = REGULATOR_SLOT;

            let mut snapshot: EconomyEpochSnapshot = world.read_model(state.last_tick_epoch);
            snapshot.epoch = state.last_tick_epoch;
            snapshot
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
