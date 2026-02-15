pub mod systems;
pub mod models;
pub mod events;
pub mod libs {
    pub mod coord_codec;
    pub mod math_bp;
    pub mod adjacency;
    pub mod biome_profiles;
    pub mod world_rng;
    pub mod world_noise;
    pub mod world_gen;
    pub mod mining_rng;
    pub mod mining_gen;
    pub mod mining_math;
    pub mod conversion_math;
    pub mod decay_math;
    pub mod construction_balance;
    pub mod sharing_math;
    pub mod autoregulator_math;
}

pub mod tests {
    mod test_p0_edges;
    mod unit {
        mod coord_codec_test;
        mod math_bp_test;
        mod adjacency_test;
        mod biome_profiles_test;
        mod world_rng_test;
        mod world_noise_test;
        mod world_gen_test;
        mod mining_gen_test;
        mod mining_math_test;
        mod mining_manager_test;
        mod conversion_math_test;
        mod decay_math_test;
        mod construction_balance_test;
        mod sharing_math_test;
        mod autoregulator_math_test;
        mod autoregulator_manager_test;
        mod sharing_manager_test;
        mod construction_events_test;
        mod sharing_events_test;
        mod construction_models_test;
        mod sharing_models_test;
        mod construction_manager_test;
        mod world_models_test;
        mod world_events_test;
        mod adventurer_events_test;
        mod harvesting_events_test;
        mod world_manager_test;
        mod adventurer_models_test;
        mod inventory_models_test;
        mod death_models_test;
        mod adventurer_manager_test;
        mod harvesting_manager_test;
        mod economics_models_test;
        mod economic_manager_test;
        mod ownership_manager_test;
        mod world_gen_manager_test;
    }
    mod integration {
        mod world_manager_integration_test;
        mod adventurer_manager_integration_test;
        mod harvesting_manager_integration_test;
        mod economic_manager_integration_test;
        mod ownership_manager_integration_test;
        mod ownership_events_integration_test;
        mod e2e_discover_harvest_convert_maintain;
        mod e2e_decay_claim_defend;
        mod e2e_permadeath_lockout;
        mod e2e_mine_build_convert;
        mod e2e_harvest_process_build;
        mod e2e_claim_transfer_buildings;
        mod world_gen_manager_integration_test;
        mod smoke_generation_pipeline_integration_test;
        mod world_economy_bridge_integration_test;
        mod mining_manager_integration_test;
        mod construction_manager_integration_test;
        mod sharing_manager_integration_test;
        mod autoregulator_keeper_bounty_integration_test;
    }
}
