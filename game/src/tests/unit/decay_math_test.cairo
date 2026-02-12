#[cfg(test)]
mod tests {
    use dojo_starter::libs::decay_math::{maintenance_decay_recovery, min_claim_energy};

    #[test]
    fn decay_math_recovery_is_monotone_with_payment_and_bounded() {
        let upkeep = 35_u32;
        let recovery_bp = 20_u16;

        let mut payment: u16 = 0_u16;
        let mut prev_recovery: u16 = 0_u16;
        loop {
            if payment > 1000_u16 {
                break;
            };

            let recovery = maintenance_decay_recovery(payment, upkeep, recovery_bp);
            assert(recovery >= prev_recovery, 'DECAY_REC_MONO');
            assert(recovery <= 100_u16, 'DECAY_REC_CAP');
            prev_recovery = recovery;
            payment += 1_u16;
        };
    }

    #[test]
    fn decay_math_min_claim_energy_is_bounded_and_decay_monotone() {
        let upkeep = 35_u32;
        let threshold = 80_u16;

        let mut decay: u16 = 0_u16;
        let mut prev_required = min_claim_energy(upkeep, 0_u16, threshold);
        loop {
            if decay > 200_u16 {
                break;
            };

            let required = min_claim_energy(upkeep, decay, threshold);
            assert(required >= prev_required, 'DECAY_MIN_MONO');
            assert(required >= 1_u16, 'DECAY_MIN_FLOOR');
            assert(required <= 65535_u16, 'DECAY_MIN_CAP');
            prev_required = required;
            decay += 1_u16;
        };

        assert(min_claim_energy(0_u32, 0_u16, threshold) == 1_u16, 'DECAY_MIN_ONE');
        assert(min_claim_energy(4_294_967_295_u32, 100_u16, threshold) == 65535_u16, 'DECAY_MIN_SAT');
    }
}
