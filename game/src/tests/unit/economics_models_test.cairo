#[cfg(test)]
mod tests {
    use dojo_starter::models::economics::{
        EconomyAccumulator, EconomyEpochSnapshot, EpochFinalizeOutcome, finalize_epoch_once_with_status,
        snapshot_fields_non_negative,
    };

    #[test]
    fn epoch_finalize_once() {
        let accumulator = EconomyAccumulator {
            epoch: 7_u32,
            total_sources: 500_u64,
            total_sinks: 300_u64,
            new_hexes: 9_u32,
            deaths: 2_u32,
            mints: 4_u32,
        };
        let snapshot = EconomyEpochSnapshot {
            epoch: 7_u32,
            total_sources: 0_u64,
            total_sinks: 0_u64,
            net_energy: 0_u64,
            new_hexes: 0_u32,
            deaths: 0_u32,
            mints: 0_u32,
            finalized_at_block: 0_u64,
            is_finalized: false,
        };

        let first = finalize_epoch_once_with_status(accumulator, snapshot, 700_u64);
        assert(first.outcome == EpochFinalizeOutcome::Applied, 'ECO_FIN_APPLY');
        assert(first.snapshot.is_finalized, 'ECO_FIN_FLAG');
        assert(first.snapshot.epoch == 7_u32, 'ECO_FIN_EPOCH');
        assert(first.snapshot.total_sources == 500_u64, 'ECO_FIN_SRC');
        assert(first.snapshot.total_sinks == 300_u64, 'ECO_FIN_SINK');

        let replay = finalize_epoch_once_with_status(accumulator, first.snapshot, 701_u64);
        assert(replay.outcome == EpochFinalizeOutcome::AlreadyFinalized, 'ECO_FIN_REPLAY');
        assert(replay.snapshot.finalized_at_block == 700_u64, 'ECO_FIN_REPLAY_BLK');
    }

    #[test]
    fn accumulator_reset_after_finalize() {
        let accumulator = EconomyAccumulator {
            epoch: 12_u32,
            total_sources: 111_u64,
            total_sinks: 99_u64,
            new_hexes: 5_u32,
            deaths: 1_u32,
            mints: 2_u32,
        };
        let snapshot = EconomyEpochSnapshot {
            epoch: 12_u32,
            total_sources: 0_u64,
            total_sinks: 0_u64,
            net_energy: 0_u64,
            new_hexes: 0_u32,
            deaths: 0_u32,
            mints: 0_u32,
            finalized_at_block: 0_u64,
            is_finalized: false,
        };

        let finalized = finalize_epoch_once_with_status(accumulator, snapshot, 1200_u64);
        assert(finalized.outcome == EpochFinalizeOutcome::Applied, 'ECO_RST_APPLY');
        assert(finalized.accumulator.epoch == 13_u32, 'ECO_RST_EPOCH');
        assert(finalized.accumulator.total_sources == 0_u64, 'ECO_RST_SRC');
        assert(finalized.accumulator.total_sinks == 0_u64, 'ECO_RST_SINK');
        assert(finalized.accumulator.new_hexes == 0_u32, 'ECO_RST_HEX');
        assert(finalized.accumulator.deaths == 0_u32, 'ECO_RST_DEATH');
        assert(finalized.accumulator.mints == 0_u32, 'ECO_RST_MINT');
    }

    #[test]
    fn snapshot_non_negative_fields() {
        let accumulator = EconomyAccumulator {
            epoch: 3_u32,
            total_sources: 25_u64,
            total_sinks: 40_u64,
            new_hexes: 1_u32,
            deaths: 8_u32,
            mints: 2_u32,
        };
        let snapshot = EconomyEpochSnapshot {
            epoch: 3_u32,
            total_sources: 0_u64,
            total_sinks: 0_u64,
            net_energy: 0_u64,
            new_hexes: 0_u32,
            deaths: 0_u32,
            mints: 0_u32,
            finalized_at_block: 0_u64,
            is_finalized: false,
        };

        let finalized = finalize_epoch_once_with_status(accumulator, snapshot, 300_u64);
        assert(finalized.outcome == EpochFinalizeOutcome::Applied, 'ECO_NONNEG_APPLY');
        assert(finalized.snapshot.net_energy == 0_u64, 'ECO_NONNEG_NET');
        assert(snapshot_fields_non_negative(finalized.snapshot), 'ECO_NONNEG_FIELDS');
    }
}
