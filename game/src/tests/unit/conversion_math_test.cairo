#[cfg(test)]
mod tests {
    use dojo_starter::libs::conversion_math::{
        MAX_VOLUME_PENALTY_BP, effective_rate_for_window, penalty_bp_for_units, quote_energy,
    };

    #[test]
    fn conversion_math_penalty_is_monotone_and_capped() {
        let mut units: u32 = 0_u32;
        let mut prev_penalty: u16 = 0_u16;
        loop {
            if units > 2000_u32 {
                break;
            };

            let penalty = penalty_bp_for_units(units);
            assert(penalty >= prev_penalty, 'CONV_PEN_MONO');
            assert(penalty <= MAX_VOLUME_PENALTY_BP, 'CONV_PEN_CAP');
            prev_penalty = penalty;
            units += 1_u32;
        };
    }

    #[test]
    fn conversion_math_effective_rate_is_nonincreasing_with_volume() {
        let base_rate = 200_u16;
        let mut units: u32 = 0_u32;
        let mut prev_rate = effective_rate_for_window(base_rate, 0_u32);
        loop {
            if units > 2000_u32 {
                break;
            };

            let current = effective_rate_for_window(base_rate, units);
            assert(current <= prev_rate, 'CONV_RATE_MONO');
            assert(current >= 100_u16, 'CONV_RATE_FLOOR');
            prev_rate = current;
            units += 1_u32;
        };

        // Floor guard: positive base rate never rounds down to zero.
        assert(effective_rate_for_window(1_u16, 1_000_000_u32) == 1_u16, 'CONV_RATE_ONE');
    }

    #[test]
    fn conversion_math_quote_energy_is_monotone_and_saturating() {
        let rate = 123_u16;
        let mut quantity: u16 = 0_u16;
        let mut prev_energy: u16 = 0_u16;
        loop {
            if quantity > 1000_u16 {
                break;
            };

            let energy = quote_energy(quantity, rate);
            assert(energy >= prev_energy, 'CONV_Q_MONO');
            assert(energy <= 65535_u16, 'CONV_Q_CAP');
            prev_energy = energy;
            quantity += 1_u16;
        };

        assert(quote_energy(65535_u16, 65535_u16) == 65535_u16, 'CONV_Q_SAT');
    }
}
