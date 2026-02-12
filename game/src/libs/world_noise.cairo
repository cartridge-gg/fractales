use cubit::f64::procgen::rand::u64_between;
use dojo_starter::libs::world_rng::{bounded_u32, derive_with_domain};

const MAX_SCALE_BP: u16 = 20_000_u16;
const MAX_OCTAVES: u8 = 8_u8;
const DEFAULT_SCALE_BP: u16 = 2_200_u16;
const DEFAULT_OCTAVES: u8 = 3_u8;

pub fn sanitize_scale_bp(scale_bp: u16, fallback: u16) -> u16 {
    if scale_bp == 0_u16 {
        return fallback;
    }
    if scale_bp > MAX_SCALE_BP {
        return MAX_SCALE_BP;
    }
    scale_bp
}

pub fn sanitize_octaves(octaves: u8, fallback: u8) -> u8 {
    if octaves == 0_u8 {
        return fallback;
    }
    if octaves > MAX_OCTAVES {
        return MAX_OCTAVES;
    }
    octaves
}

pub fn noise_percentile_roll(seed: felt252, entropy: felt252, scale_bp: u16, octaves: u8) -> u32 {
    let active_scale_bp = sanitize_scale_bp(scale_bp, DEFAULT_SCALE_BP);
    let active_octaves = sanitize_octaves(octaves, DEFAULT_OCTAVES);

    let scale_entropy = derive_with_domain(
        entropy, active_scale_bp.into(), 'NOISE_SCALE_V1'_felt252,
    );
    let octave_entropy = derive_with_domain(
        scale_entropy, active_octaves.into(), 'NOISE_OCT_V1'_felt252,
    );
    let sample_seed = derive_with_domain(seed, octave_entropy, 'NOISE_SAMPLE_V1'_felt252);
    let sampled = u64_between(sample_seed, 0_u64, 101_u64);
    match bounded_u32(sampled.into(), 0_u32, 101_u32) {
        Option::Some(value) => value,
        Option::None => 0_u32,
    }
}
