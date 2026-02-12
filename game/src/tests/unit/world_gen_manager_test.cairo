#[cfg(test)]
mod tests {
    use dojo_starter::libs::world_gen::default_world_gen_config;
    use dojo_starter::models::world::WorldGenConfig;
    use dojo_starter::systems::world_gen_manager::{
        WorldGenConfigInitOutcome, initialize_active_world_gen_config_transition,
    };

    fn candidate_config() -> WorldGenConfig {
        WorldGenConfig {
            generation_version: 1_u16,
            global_seed: 'G5_CFG_SEED'_felt252,
            biome_scale_bp: 0_u16,
            area_scale_bp: 27_500_u16,
            plant_scale_bp: 6_500_u16,
            biome_octaves: 0_u8,
            area_octaves: 99_u8,
            plant_octaves: 6_u8,
        }
    }

    #[test]
    fn world_gen_manager_init_requires_namespace_owner() {
        let existing = WorldGenConfig {
            generation_version: 0_u16,
            global_seed: 0_felt252,
            biome_scale_bp: 0_u16,
            area_scale_bp: 0_u16,
            plant_scale_bp: 0_u16,
            biome_octaves: 0_u8,
            area_octaves: 0_u8,
            plant_octaves: 0_u8,
        };

        let result = initialize_active_world_gen_config_transition(existing, candidate_config(), false);
        assert(
            result.outcome == WorldGenConfigInitOutcome::NotNamespaceOwner, 'GEN_CFG_OWNER_GUARD',
        );
        assert(result.config.generation_version == 0_u16, 'GEN_CFG_OWNER_VERSION');
    }

    #[test]
    fn world_gen_manager_init_normalizes_and_applies_once() {
        let existing = WorldGenConfig {
            generation_version: 0_u16,
            global_seed: 0_felt252,
            biome_scale_bp: 0_u16,
            area_scale_bp: 0_u16,
            plant_scale_bp: 0_u16,
            biome_octaves: 0_u8,
            area_octaves: 0_u8,
            plant_octaves: 0_u8,
        };

        let result = initialize_active_world_gen_config_transition(existing, candidate_config(), true);
        assert(result.outcome == WorldGenConfigInitOutcome::Applied, 'GEN_CFG_APPLIED');
        assert(result.config.generation_version == 1_u16, 'GEN_CFG_VERSION');
        assert(result.config.global_seed == 'G5_CFG_SEED'_felt252, 'GEN_CFG_SEED');
        assert(result.config.biome_scale_bp > 0_u16, 'GEN_CFG_BIOME_SCALE_NONZERO');
        assert(result.config.area_scale_bp <= 20_000_u16, 'GEN_CFG_AREA_SCALE_CLAMP');
        assert(result.config.biome_octaves > 0_u8, 'GEN_CFG_BIOME_OCT_NONZERO');
        assert(result.config.area_octaves <= 8_u8, 'GEN_CFG_AREA_OCT_CLAMP');

        let replay = initialize_active_world_gen_config_transition(result.config, default_world_gen_config(), true);
        assert(replay.outcome == WorldGenConfigInitOutcome::AlreadyInitialized, 'GEN_CFG_REPLAY');
        assert(replay.config.global_seed == 'G5_CFG_SEED'_felt252, 'GEN_CFG_REPLAY_IMMUTABLE');
    }
}
