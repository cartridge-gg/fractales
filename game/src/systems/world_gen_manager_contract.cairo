const WORLD_GEN_VERSION_ACTIVE: u16 = 1_u16;

#[starknet::interface]
pub trait IWorldGenManager<T> {
    fn initialize_active_world_gen_config(
        ref self: T,
        global_seed: felt252,
        biome_scale_bp: u16,
        area_scale_bp: u16,
        plant_scale_bp: u16,
        biome_octaves: u8,
        area_octaves: u8,
        plant_octaves: u8,
    ) -> bool;
    fn get_active_world_gen_config(self: @T) -> dojo_starter::models::world::WorldGenConfig;
}

#[dojo::contract]
pub mod world_gen_manager {
    use super::{IWorldGenManager, WORLD_GEN_VERSION_ACTIVE};
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo::world::IWorldDispatcherTrait;
    use dojo_starter::events::world_events::WorldGenConfigInitialized;
    use dojo_starter::models::world::WorldGenConfig;
    use dojo_starter::systems::world_gen_manager::{
        WorldGenConfigInitOutcome, initialize_active_world_gen_config_transition,
    };
    use starknet::get_caller_address;

    #[abi(embed_v0)]
    impl WorldGenManagerImpl of IWorldGenManager<ContractState> {
        fn initialize_active_world_gen_config(
            ref self: ContractState,
            global_seed: felt252,
            biome_scale_bp: u16,
            area_scale_bp: u16,
            plant_scale_bp: u16,
            biome_octaves: u8,
            area_octaves: u8,
            plant_octaves: u8,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let is_namespace_owner = IWorldDispatcherTrait::is_owner(
                world.dispatcher, world.namespace_hash, caller,
            );
            let existing: WorldGenConfig = world.read_model(WORLD_GEN_VERSION_ACTIVE);
            let requested = WorldGenConfig {
                generation_version: WORLD_GEN_VERSION_ACTIVE,
                global_seed,
                biome_scale_bp,
                area_scale_bp,
                plant_scale_bp,
                biome_octaves,
                area_octaves,
                plant_octaves,
            };

            let initialized = initialize_active_world_gen_config_transition(
                existing, requested, is_namespace_owner,
            );
            match initialized.outcome {
                WorldGenConfigInitOutcome::Applied => {
                    world.write_model(@initialized.config);
                    world.emit_event(
                        @WorldGenConfigInitialized {
                            generation_version: initialized.config.generation_version,
                            global_seed: initialized.config.global_seed,
                            biome_scale_bp: initialized.config.biome_scale_bp,
                            area_scale_bp: initialized.config.area_scale_bp,
                            plant_scale_bp: initialized.config.plant_scale_bp,
                            biome_octaves: initialized.config.biome_octaves,
                            area_octaves: initialized.config.area_octaves,
                            plant_octaves: initialized.config.plant_octaves,
                        },
                    );
                    true
                },
                _ => false,
            }
        }

        fn get_active_world_gen_config(self: @ContractState) -> WorldGenConfig {
            let world = self.world_default();
            world.read_model(WORLD_GEN_VERSION_ACTIVE)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
