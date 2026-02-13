#[cfg(test)]
mod tests {
    use dojo_starter::libs::mining_math::{
        compute_stress_delta, compute_tick_energy_cost, compute_tick_yield, swarm_energy_surcharge,
        will_collapse,
    };

    #[test]
    fn mining_math_swarm_surcharge_matches_locked_formula() {
        assert(swarm_energy_surcharge(1_u16, 2_u16) == 0_u16, 'MMATH_SWARM_1');
        assert(swarm_energy_surcharge(2_u16, 2_u16) == 2_u16, 'MMATH_SWARM_2');
        assert(swarm_energy_surcharge(3_u16, 2_u16) == 8_u16, 'MMATH_SWARM_3');
        assert(swarm_energy_surcharge(4_u16, 2_u16) == 18_u16, 'MMATH_SWARM_4');
    }

    #[test]
    fn mining_math_tick_energy_cost_is_monotone_with_swarm() {
        let e1 = compute_tick_energy_cost(3_u16, 2_u16, 1_u8, 1_u16, 2_u16);
        let e3 = compute_tick_energy_cost(3_u16, 2_u16, 1_u8, 3_u16, 2_u16);
        let e5 = compute_tick_energy_cost(3_u16, 2_u16, 1_u8, 5_u16, 2_u16);
        assert(e1 < e3, 'MMATH_ENE_MONO_13');
        assert(e3 < e5, 'MMATH_ENE_MONO_35');
    }

    #[test]
    fn mining_math_stress_delta_grows_with_density_and_risk() {
        let low = compute_stress_delta(
            10_u64, 20_u16, 1_u16, 5_u64, 8_u64, 10_000_u16, 10_000_u16, 120_u16, 500_u16,
        );
        let high_density = compute_stress_delta(
            10_u64, 20_u16, 4_u16, 5_u64, 8_u64, 10_000_u16, 10_000_u16, 120_u16, 500_u16,
        );
        let high_risk = compute_stress_delta(
            10_u64, 20_u16, 4_u16, 5_u64, 8_u64, 12_000_u16, 13_000_u16, 120_u16, 500_u16,
        );
        assert(low > 0_u32, 'MMATH_STRESS_POS');
        assert(high_density > low, 'MMATH_STRESS_DENSITY');
        assert(high_risk > high_density, 'MMATH_STRESS_RISK');
    }

    #[test]
    fn mining_math_collapse_and_yield_helpers_behave() {
        assert(!will_collapse(90_u32, 100_u32), 'MMATH_COLL_FALSE');
        assert(will_collapse(100_u32, 100_u32), 'MMATH_COLL_TRUE');
        let y0 = compute_tick_yield(20_u16, 0_u32, 100_u32, 8_500_u16, 4_u64);
        let y1 = compute_tick_yield(20_u16, 90_u32, 100_u32, 8_500_u16, 4_u64);
        assert(y0 > y1, 'MMATH_YIELD_STRESS_DROP');
    }
}
