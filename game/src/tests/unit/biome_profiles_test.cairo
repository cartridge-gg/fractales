#[cfg(test)]
mod tests {
    use dojo_starter::libs::biome_profiles::{
        plant_field_threshold_for_biome, profile_for_biome, species_for_biome_roll,
    };
    use dojo_starter::libs::decay_math::upkeep_for_biome;
    use dojo_starter::models::world::Biome;

    #[test]
    fn biome_profiles_match_decay_upkeep_for_representative_tiers() {
        let low = profile_for_biome(Biome::Plains);
        let mid = profile_for_biome(Biome::Highlands);
        let high = profile_for_biome(Biome::Volcanic);

        assert(low.upkeep_per_period == upkeep_for_biome(Biome::Plains), 'BIO_PROFILE_LOW_SYNC');
        assert(mid.upkeep_per_period == upkeep_for_biome(Biome::Highlands), 'BIO_PROFILE_MID_SYNC');
        assert(
            high.upkeep_per_period == upkeep_for_biome(Biome::Volcanic), 'BIO_PROFILE_HIGH_SYNC',
        );
        let low_lt_mid = low.upkeep_per_period < mid.upkeep_per_period;
        let mid_lt_high = mid.upkeep_per_period < high.upkeep_per_period;
        assert(low_lt_mid, 'BIO_PROFILE_LOW_MID');
        assert(mid_lt_high, 'BIO_PROFILE_MID_HIGH');
    }

    #[test]
    fn biome_profiles_surface_threshold_and_species_helpers() {
        let desert = profile_for_biome(Biome::Desert);

        assert(
            plant_field_threshold_for_biome(Biome::Desert) == desert.plant_field_threshold,
            'BIO_PROFILE_THRESH',
        );

        let primary = species_for_biome_roll(Biome::Desert, 10_u32);
        let secondary = species_for_biome_roll(Biome::Desert, 90_u32);

        assert(primary == desert.primary_species, 'BIO_PROFILE_PRIMARY');
        assert(secondary == desert.secondary_species, 'BIO_PROFILE_SECONDARY');
        assert(primary != secondary, 'BIO_PROFILE_VARIANT');
    }
}
