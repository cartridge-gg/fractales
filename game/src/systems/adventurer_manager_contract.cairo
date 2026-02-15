const DEFAULT_MAX_ENERGY: u16 = 100_u16;
const DEFAULT_MAX_WEIGHT: u32 = 750_u32;
const ENERGY_REGEN_PER_100_BLOCKS: u16 = 20_u16;
const BASE_ADVENTURER_MINT_COST: u16 = 100_u16;
const BP_ONE: u16 = 10_000_u16;
const REGULATOR_SLOT: u8 = 1_u8;

#[starknet::interface]
pub trait IAdventurerManager<T> {
    fn create_adventurer(ref self: T, name: felt252) -> felt252;
    fn quote_create_adventurer_cost(self: @T) -> u16;
    fn consume_energy(ref self: T, adventurer_id: felt252, amount: u16) -> bool;
    fn regenerate_energy(ref self: T, adventurer_id: felt252) -> u16;
    fn kill_adventurer(ref self: T, adventurer_id: felt252, cause: felt252) -> bool;
}

#[dojo::contract]
pub mod adventurer_manager {
    use super::{
        BASE_ADVENTURER_MINT_COST, BP_ONE, DEFAULT_MAX_ENERGY, DEFAULT_MAX_WEIGHT,
        ENERGY_REGEN_PER_100_BLOCKS, IAdventurerManager, REGULATOR_SLOT,
    };
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::adventurer_events::{AdventurerCreated, AdventurerDied};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{AdventurerEconomics, RegulatorConfig, RegulatorPolicy};
    use dojo_starter::models::inventory::Inventory;
    use dojo_starter::systems::autoregulator_manager::normalize_config;
    use dojo_starter::systems::adventurer_manager::{
        ConsumeOutcome, KillOutcome, RegenOutcome, consume_transition, create_transition, kill_transition,
        regenerate_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    fn current_epoch_from_block(now_block: u64, epoch_blocks: u64) -> u32 {
        let blocks = if epoch_blocks == 0_u64 { 1_u64 } else { epoch_blocks };
        let epoch_u64 = now_block / blocks;
        let epoch_u128: u128 = epoch_u64.into();
        if epoch_u128 > 4_294_967_295_u128 {
            4_294_967_295_u32
        } else {
            epoch_u128.try_into().unwrap()
        }
    }

    fn apply_bp_floor_u16(value: u16, bp: u16) -> u16 {
        if value == 0_u16 || bp == 0_u16 {
            return 0_u16;
        }

        let scaled_u128: u128 = value.into() * bp.into() / BP_ONE.into();
        if scaled_u128 > 65_535_u128 {
            65_535_u16
        } else {
            scaled_u128.try_into().unwrap()
        }
    }

    fn effective_mint_discount_bp(ref world: dojo::world::WorldStorage, now_block: u64) -> u16 {
        let mut policy: RegulatorPolicy = world.read_model(REGULATOR_SLOT);
        policy.slot = REGULATOR_SLOT;

        let mut config: RegulatorConfig = world.read_model(REGULATOR_SLOT);
        config.slot = REGULATOR_SLOT;
        let normalized = normalize_config(config);
        let current_epoch = current_epoch_from_block(now_block, normalized.epoch_blocks);

        if policy.policy_epoch == 0_u32 || policy.policy_epoch >= current_epoch {
            return 0_u16;
        }

        if policy.mint_discount_bp > BP_ONE {
            BP_ONE
        } else {
            policy.mint_discount_bp
        }
    }

    #[abi(embed_v0)]
    impl AdventurerManagerImpl of IAdventurerManager<ContractState> {
        fn create_adventurer(ref self: ContractState, name: felt252) -> felt252 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;
            let created = create_transition(
                caller, name, block_number, DEFAULT_MAX_ENERGY, DEFAULT_MAX_WEIGHT,
            );

            world.write_model(@created.adventurer);
            world.write_model(@created.inventory);
            world.write_model(@created.economics);
            world.emit_event(
                @AdventurerCreated {
                    adventurer_id: created.adventurer.adventurer_id,
                    owner: created.adventurer.owner,
                },
            );

            created.adventurer.adventurer_id
        }

        fn quote_create_adventurer_cost(self: @ContractState) -> u16 {
            let mut world = self.world_default();
            let now_block = get_block_info().unbox().block_number;
            let discount_bp = effective_mint_discount_bp(ref world, now_block);
            let discount = apply_bp_floor_u16(BASE_ADVENTURER_MINT_COST, discount_bp);
            if discount >= BASE_ADVENTURER_MINT_COST {
                0_u16
            } else {
                BASE_ADVENTURER_MINT_COST - discount
            }
        }

        fn consume_energy(ref self: ContractState, adventurer_id: felt252, amount: u16) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;
            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);

            let consumed = consume_transition(
                adventurer, economics, caller, amount, block_number, ENERGY_REGEN_PER_100_BLOCKS,
            );

            match consumed.outcome {
                ConsumeOutcome::Applied => {
                    world.write_model(@consumed.adventurer);
                    world.write_model(@consumed.economics);
                    true
                },
                ConsumeOutcome::InsufficientEnergy => {
                    world.write_model(@consumed.adventurer);
                    world.write_model(@consumed.economics);
                    false
                },
                _ => false,
            }
        }

        fn regenerate_energy(ref self: ContractState, adventurer_id: felt252) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;
            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);

            let regenerated = regenerate_transition(
                adventurer, economics, caller, block_number, ENERGY_REGEN_PER_100_BLOCKS,
            );

            match regenerated.outcome {
                RegenOutcome::Applied => {
                    world.write_model(@regenerated.adventurer);
                    world.write_model(@regenerated.economics);
                    regenerated.adventurer.energy
                },
                _ => adventurer.energy,
            }
        }

        fn kill_adventurer(ref self: ContractState, adventurer_id: felt252, cause: felt252) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;
            let adventurer: Adventurer = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);

            let killed = kill_transition(
                adventurer, inventory, caller, block_number, cause, 0_felt252,
            );

            match killed.outcome {
                KillOutcome::Applied => {
                    world.write_model(@killed.adventurer);
                    world.write_model(@killed.inventory);
                    world.write_model(@killed.death_record);
                    world.emit_event(
                        @AdventurerDied {
                            adventurer_id: killed.adventurer.adventurer_id,
                            owner: killed.adventurer.owner,
                            cause,
                        },
                    );
                    true
                },
                _ => false,
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
