#[starknet::interface]
pub trait IOwnershipManager<T> {
    fn get_owner(self: @T, area_id: felt252) -> felt252;
    fn transfer_ownership(ref self: T, area_id: felt252, to_adventurer_id: felt252) -> bool;
}

#[dojo::contract]
pub mod ownership_manager {
    use super::IOwnershipManager;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::systems::ownership_manager::{
        OwnershipTransferOutcome, get_owner_transition, transfer_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    #[abi(embed_v0)]
    impl OwnershipManagerImpl of IOwnershipManager<ContractState> {
        fn get_owner(self: @ContractState, area_id: felt252) -> felt252 {
            let world = self.world_default();
            let mut ownership: AreaOwnership = world.read_model(area_id);
            ownership.area_id = area_id;
            get_owner_transition(ownership)
        }

        fn transfer_ownership(ref self: ContractState, area_id: felt252, to_adventurer_id: felt252) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let mut ownership: AreaOwnership = world.read_model(area_id);
            ownership.area_id = area_id;
            let from_adventurer_id = ownership.owner_adventurer_id;
            let owner: Adventurer = world.read_model(from_adventurer_id);

            let transferred = transfer_transition(
                ownership, owner, caller, to_adventurer_id, block_number,
            );
            match transferred.outcome {
                OwnershipTransferOutcome::Applied => {
                    world.write_model(@transferred.ownership);
                    world.emit_event(
                        @OwnershipTransferred {
                            area_id,
                            from_adventurer_id,
                            to_adventurer_id,
                            claim_block: block_number,
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
