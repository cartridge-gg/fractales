const HARVEST_ENERGY_PER_UNIT: u16 = 10_u16;
const HARVEST_TIME_PER_UNIT: u16 = 2_u16;
const ENERGY_REGEN_PER_100_BLOCKS: u16 = 20_u16;
const WORLD_GEN_VERSION_ACTIVE: u16 = 1_u16;

#[starknet::interface]
pub trait IHarvestingManager<T> {
    fn init_harvesting(
        ref self: T,
        hex_coordinate: felt252,
        area_id: felt252,
        plant_id: u8,
    ) -> bool;
    fn start_harvesting(
        ref self: T,
        adventurer_id: felt252,
        hex_coordinate: felt252,
        area_id: felt252,
        plant_id: u8,
        amount: u16,
    ) -> bool;
    fn complete_harvesting(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
    ) -> u16;
    fn cancel_harvesting(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
    ) -> u16;
    fn inspect_plant(self: @T, hex_coordinate: felt252, area_id: felt252, plant_id: u8)
        -> dojo_starter::models::harvesting::PlantNode;
}

#[dojo::contract]
pub mod harvesting_manager {
    use super::{
        ENERGY_REGEN_PER_100_BLOCKS, HARVEST_ENERGY_PER_UNIT, HARVEST_TIME_PER_UNIT, IHarvestingManager,
        WORLD_GEN_VERSION_ACTIVE,
    };
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::harvesting_events::{
        HarvestingCancelled, HarvestingCompleted, HarvestingStarted,
    };
    use dojo_starter::libs::world_gen::derive_plant_profile_with_config;
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{
        HarvestReservation, PlantNode, derive_harvest_item_id, derive_harvest_reservation_id,
        derive_plant_key,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::world::{Hex, WorldGenConfig};
    use dojo_starter::systems::harvesting_manager::{
        CancelOutcome, CompleteOutcome, InitOutcome, StartOutcome, cancel_transition, complete_transition,
        init_transition, start_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    #[abi(embed_v0)]
    impl HarvestingManagerImpl of IHarvestingManager<ContractState> {
        fn init_harvesting(
            ref self: ContractState,
            hex_coordinate: felt252,
            area_id: felt252,
            plant_id: u8,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let hex: Hex = world.read_model(hex_coordinate);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let mut plant: PlantNode = world.read_model(plant_key);
            plant.plant_key = plant_key;
            plant.hex_coordinate = hex_coordinate;
            plant.area_id = area_id;
            plant.plant_id = plant_id;
            let world_gen_config: WorldGenConfig = world.read_model(WORLD_GEN_VERSION_ACTIVE);
            let generated = derive_plant_profile_with_config(
                hex_coordinate, area_id, plant_id, hex.biome, world_gen_config,
            );

            let initialized = init_transition(
                plant,
                caller,
                hex.is_discovered,
                generated.species,
                generated.max_yield,
                generated.regrowth_rate,
                generated.genetics_hash,
                block_number,
            );

            match initialized.outcome {
                InitOutcome::Applied => {
                    world.write_model(@initialized.plant);
                    true
                },
                _ => false,
            }
        }

        fn start_harvesting(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_id: felt252,
            plant_id: u8,
            amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let started = start_transition(
                adventurer,
                economics,
                caller,
                plant,
                reservation,
                amount,
                block_number,
                ENERGY_REGEN_PER_100_BLOCKS,
                HARVEST_ENERGY_PER_UNIT,
                HARVEST_TIME_PER_UNIT,
            );

            match started.outcome {
                StartOutcome::Applied => {
                    world.write_model(@started.adventurer);
                    world.write_model(@started.economics);
                    world.write_model(@started.plant);
                    world.write_model(@started.reservation);
                    world.emit_event(
                        @HarvestingStarted {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            amount,
                            eta: started.eta,
                        },
                    );
                    true
                },
                StartOutcome::InsufficientEnergy => {
                    world.write_model(@started.adventurer);
                    world.write_model(@started.economics);
                    false
                },
                _ => false,
            }
        }

        fn complete_harvesting(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let item_id = derive_harvest_item_id(plant_key);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let completed = complete_transition(
                adventurer, caller, plant, reservation, inventory, item, block_number,
            );
            match completed.outcome {
                CompleteOutcome::Applied => {
                    world.write_model(@completed.adventurer);
                    world.write_model(@completed.plant);
                    world.write_model(@completed.reservation);
                    world.write_model(@completed.inventory);
                    world.write_model(@completed.item);
                    world.emit_event(
                        @HarvestingCompleted {
                            adventurer_id,
                            hex: hex_coordinate,
                            area_id,
                            plant_id,
                            actual_yield: completed.actual_yield,
                        },
                    );
                    completed.actual_yield
                },
                _ => 0_u16,
            }
        }

        fn cancel_harvesting(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, area_id: felt252, plant_id: u8,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            let plant: PlantNode = world.read_model(plant_key);

            let reservation_id = derive_harvest_reservation_id(adventurer_id, plant_key);
            let mut reservation: HarvestReservation = world.read_model(reservation_id);
            reservation.reservation_id = reservation_id;
            reservation.plant_key = plant_key;

            let item_id = derive_harvest_item_id(plant_key);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let canceled = cancel_transition(
                adventurer, caller, plant, reservation, inventory, item, block_number,
            );
            match canceled.outcome {
                CancelOutcome::Applied => {
                    world.write_model(@canceled.adventurer);
                    world.write_model(@canceled.plant);
                    world.write_model(@canceled.reservation);
                    world.write_model(@canceled.inventory);
                    world.write_model(@canceled.item);
                    world.emit_event(
                        @HarvestingCancelled {
                            adventurer_id,
                            partial_yield: canceled.partial_yield,
                        },
                    );
                    canceled.partial_yield
                },
                _ => 0_u16,
            }
        }

        fn inspect_plant(self: @ContractState, hex_coordinate: felt252, area_id: felt252, plant_id: u8) -> PlantNode {
            let world = self.world_default();
            let plant_key = derive_plant_key(hex_coordinate, area_id, plant_id);
            world.read_model(plant_key)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
