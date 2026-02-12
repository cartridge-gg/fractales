const DEFAULT_MAX_ENERGY: u16 = 100_u16;
const DEFAULT_MAX_WEIGHT: u32 = 750_u32;
const ENERGY_REGEN_PER_100_BLOCKS: u16 = 20_u16;

#[starknet::interface]
pub trait IAdventurerManager<T> {
    fn create_adventurer(ref self: T, name: felt252) -> felt252;
    fn consume_energy(ref self: T, adventurer_id: felt252, amount: u16) -> bool;
    fn regenerate_energy(ref self: T, adventurer_id: felt252) -> u16;
    fn kill_adventurer(ref self: T, adventurer_id: felt252, cause: felt252) -> bool;
}

#[dojo::contract]
pub mod adventurer_manager {
    use super::{
        DEFAULT_MAX_ENERGY, DEFAULT_MAX_WEIGHT, ENERGY_REGEN_PER_100_BLOCKS, IAdventurerManager,
    };
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::adventurer_events::{AdventurerCreated, AdventurerDied};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::inventory::Inventory;
    use dojo_starter::systems::adventurer_manager::{
        ConsumeOutcome, KillOutcome, RegenOutcome, consume_transition, create_transition, kill_transition,
        regenerate_transition,
    };
    use starknet::{get_block_info, get_caller_address};

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
