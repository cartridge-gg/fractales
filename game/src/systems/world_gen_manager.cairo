use dojo_starter::libs::world_gen::normalize_world_gen_config;
use dojo_starter::models::world::WorldGenConfig;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum WorldGenConfigInitOutcome {
    #[default]
    AlreadyInitialized,
    NotNamespaceOwner,
    InvalidVersion,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct WorldGenConfigInitResult {
    pub config: WorldGenConfig,
    pub outcome: WorldGenConfigInitOutcome,
}

fn is_initialized(config: WorldGenConfig) -> bool {
    config.global_seed != 0_felt252 || config.biome_scale_bp != 0_u16 || config.area_scale_bp != 0_u16
        || config.plant_scale_bp != 0_u16 || config.biome_octaves != 0_u8
        || config.area_octaves != 0_u8 || config.plant_octaves != 0_u8
}

pub fn initialize_active_world_gen_config_transition(
    existing: WorldGenConfig, requested: WorldGenConfig, is_namespace_owner: bool,
) -> WorldGenConfigInitResult {
    if !is_namespace_owner {
        return WorldGenConfigInitResult {
            config: existing, outcome: WorldGenConfigInitOutcome::NotNamespaceOwner,
        };
    }

    if requested.generation_version == 0_u16 {
        return WorldGenConfigInitResult {
            config: existing, outcome: WorldGenConfigInitOutcome::InvalidVersion,
        };
    }

    if is_initialized(existing) {
        return WorldGenConfigInitResult {
            config: existing, outcome: WorldGenConfigInitOutcome::AlreadyInitialized,
        };
    }

    let normalized = normalize_world_gen_config(requested);
    if normalized.generation_version == 0_u16 {
        return WorldGenConfigInitResult {
            config: existing, outcome: WorldGenConfigInitOutcome::InvalidVersion,
        };
    }

    WorldGenConfigInitResult { config: normalized, outcome: WorldGenConfigInitOutcome::Applied }
}
