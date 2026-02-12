#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::adventurer::{AdventurerWriteStatus, kill_once_with_status};
    use dojo_starter::models::economics::{
        ClaimEscrow, ClaimEscrowExpireOutcome, ClaimEscrowInitOutcome, ClaimEscrowStatus,
        DecayProcessOutcome, HexDecayState, expire_claim_escrow_once_with_status,
        initiate_claim_escrow_once_with_status, process_hex_decay_once_with_status,
    };
    use dojo_starter::models::harvesting::{
        HarvestDeathSettleOutcome, HarvestReservation, HarvestReservationStatus,
        HarvestReserveOutcome, PlantNode, reserve_yield_once_with_status,
        settle_harvest_reservation_on_death,
    };
    use dojo_starter::models::world::{Biome, Hex};
    use dojo_starter::systems::world_manager::{
        DiscoverHexResult, HexDiscoverOutcome, discover_hex_transition,
    };
    use starknet::ContractAddress;

    fn red_fail(reason: felt252) {
        assert(1 == 0, reason);
    }

    #[test]
    fn p04_red_duplicate_discovery_replay_behavior() {
        // DD-010:
        // - First discover mutates state and spends energy.
        // - Replay call returns existing record without mutation, spend, or event.
        let undiscovered = Hex {
            coordinate: 5050_felt252,
            biome: Biome::Plains,
            is_discovered: false,
            discovery_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
            area_count: 0_u8,
        };
        let first_discoverer: ContractAddress = 71.try_into().unwrap();
        let replay_discoverer: ContractAddress = 99.try_into().unwrap();

        let first: DiscoverHexResult = discover_hex_transition(
            undiscovered, first_discoverer, 123_u64, Biome::Forest, 6_u8, 25_u16,
        );
        let replay: DiscoverHexResult = discover_hex_transition(
            first.hex, replay_discoverer, 555_u64, Biome::Desert, 3_u8, 25_u16,
        );

        assert(first.outcome == HexDiscoverOutcome::Applied, 'P04_DISCOVER_FIRST_OUTCOME');
        assert(first.energy_spent == 25_u16, 'P04_DISCOVER_FIRST_ENERGY');
        assert(first.emit_event, 'P04_DISCOVER_FIRST_EVENT');

        assert(replay.outcome == HexDiscoverOutcome::Replay, 'P04_DISCOVER_REPLAY_OUTCOME');
        assert(replay.energy_spent == 0_u16, 'P04_DISCOVER_REPLAY_ENERGY');
        assert(!replay.emit_event, 'P04_DISCOVER_REPLAY_EVENT');
        assert(replay.hex.discoverer == first_discoverer, 'P04_DISCOVER_REPLAY_DISCOVERER');
        assert(replay.hex.discovery_block == 123_u64, 'P04_DISCOVER_REPLAY_BLOCK');
    }

    #[test]
    fn p04_red_concurrent_harvest_reservation() {
        // DD-016:
        // - Reserve at start_harvesting, using available_yield = current_yield - reserved_yield.
        // - A second start on the same plant cannot reserve above remaining availability.
        let plant = PlantNode {
            plant_key: 9001_felt252,
            hex_coordinate: 500_felt252,
            area_id: 501_felt252,
            plant_id: 1_u8,
            species: 'MOSS'_felt252,
            current_yield: 10_u16,
            reserved_yield: 0_u16,
            max_yield: 10_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 777_felt252,
            last_harvest_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
        };

        let first = reserve_yield_once_with_status(plant, 8_u16);
        let second = reserve_yield_once_with_status(first.plant, 5_u16);

        assert(first.outcome == HarvestReserveOutcome::Applied, 'P04_HARVEST_FIRST_OK');
        assert(first.plant.reserved_yield == 8_u16, 'P04_HARVEST_FIRST_RESERVED');
        assert(second.outcome == HarvestReserveOutcome::InsufficientYield, 'P04_HARVEST_SECOND_BLOCK');
        assert(second.plant.current_yield == 10_u16, 'P04_HARVEST_SECOND_CURR_SAME');
        assert(second.plant.reserved_yield == 8_u16, 'P04_HARVEST_RESV_SAME');
    }

    #[test]
    fn p04_red_claim_escrow_single_use_energy() {
        // DD-017:
        // - Claim energy is deducted and locked on initiate.
        // - A second claim attempt cannot reuse already locked balance.
        let claimant = Adventurer {
            adventurer_id: 7001_felt252,
            owner: 77.try_into().unwrap(),
            name: 'CLAIMER'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 500_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };

        let first_escrow = ClaimEscrow {
            claim_id: 9001_felt252,
            hex_coordinate: 500_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };
        let first = initiate_claim_escrow_once_with_status(
            claimant, first_escrow, 70_u16, 100_u64, 100_u64,
        );

        assert(first.outcome == ClaimEscrowInitOutcome::Applied, 'P04_ESCROW_FIRST_OK');
        assert(first.adventurer.energy == 30_u16, 'P04_ESCROW_ENERGY_LOCK');
        assert(first.escrow.status == ClaimEscrowStatus::Active, 'P04_ESCROW_STATUS');
        assert(first.escrow.energy_locked == 70_u16, 'P04_ESCROW_LOCKED');
        assert(first.escrow.expiry_block == 200_u64, 'P04_ESCROW_EXPIRY');

        let second_escrow = ClaimEscrow {
            claim_id: 9002_felt252,
            hex_coordinate: 501_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };
        let second = initiate_claim_escrow_once_with_status(
            first.adventurer, second_escrow, 70_u16, 101_u64, 100_u64,
        );

        assert(
            second.outcome == ClaimEscrowInitOutcome::InsufficientEnergy,
            'P04_ESCROW_SECOND_BLOCK',
        );
        assert(second.adventurer.energy == 30_u16, 'P04_ESCROW_ENERGY_SAME');
        assert(second.escrow.status == ClaimEscrowStatus::Inactive, 'P04_ESCROW_STATUS_SAME');
        assert(second.escrow.energy_locked == 0_u16, 'P04_ESCROW_LOCK_ZERO');
    }

    #[test]
    fn p04_red_claim_deadline_expiry_refund() {
        // DD-018:
        // - ACTIVE escrow expires only when now > expiry_block.
        // - Expiry refunds locked energy exactly once.
        let claimant = Adventurer {
            adventurer_id: 8001_felt252,
            owner: 88.try_into().unwrap(),
            name: 'EXPIRE'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 600_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let escrow = ClaimEscrow {
            claim_id: 9101_felt252,
            hex_coordinate: 600_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };

        let started = initiate_claim_escrow_once_with_status(
            claimant, escrow, 40_u16, 10_u64, 100_u64,
        );
        assert(started.outcome == ClaimEscrowInitOutcome::Applied, 'P04_EXP_START_OK');
        assert(started.adventurer.energy == 60_u16, 'P04_EXP_START_ENE');
        assert(started.escrow.status == ClaimEscrowStatus::Active, 'P04_EXP_START_ST');
        assert(started.escrow.expiry_block == 110_u64, 'P04_EXP_DEADLINE');

        let at_deadline = expire_claim_escrow_once_with_status(
            started.adventurer, started.escrow, 110_u64,
        );
        assert(at_deadline.outcome == ClaimEscrowExpireOutcome::NotExpired, 'P04_EXP_NOOP_OUT');
        assert(at_deadline.adventurer.energy == 60_u16, 'P04_EXP_NOOP_ENE');
        assert(at_deadline.escrow.status == ClaimEscrowStatus::Active, 'P04_EXP_NOOP_ST');
        assert(at_deadline.escrow.energy_locked == 40_u16, 'P04_EXP_NOOP_LOCK');

        let expired = expire_claim_escrow_once_with_status(
            at_deadline.adventurer, at_deadline.escrow, 111_u64,
        );
        assert(expired.outcome == ClaimEscrowExpireOutcome::Applied, 'P04_EXP_APPLY_OUT');
        assert(expired.adventurer.energy == 100_u16, 'P04_EXP_APPLY_ENE');
        assert(expired.escrow.status == ClaimEscrowStatus::Expired, 'P04_EXP_APPLY_ST');
        assert(expired.escrow.energy_locked == 0_u16, 'P04_EXP_APPLY_LOCK');

        let replay = expire_claim_escrow_once_with_status(
            expired.adventurer, expired.escrow, 500_u64,
        );
        assert(replay.outcome == ClaimEscrowExpireOutcome::Replay, 'P04_EXP_REPLAY_OUT');
        assert(replay.adventurer.energy == 100_u16, 'P04_EXP_REPLAY_ENE');
        assert(replay.escrow.status == ClaimEscrowStatus::Expired, 'P04_EXP_REPLAY_ST');
    }

    #[test]
    fn p04_red_decay_checkpoint_idempotency() {
        // DD-019:
        // - process_hex_decay only charges newly elapsed windows.
        // - Re-running with no new elapsed period is a no-op.
        let state = HexDecayState {
            hex_coordinate: 700_felt252,
            owner_adventurer_id: 900_felt252,
            current_energy_reserve: 50_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 0_u16,
            claimable_since_block: 0_u64,
        };

        // Two full 100-block windows elapsed by block 250.
        let first = process_hex_decay_once_with_status(state, 250_u64, 100_u64, 10_u32, 80_u16);
        assert(first.outcome == DecayProcessOutcome::Applied, 'P04_DECAY_APPLY');
        assert(first.periods_processed == 2_u64, 'P04_DECAY_PERS');
        assert(first.state.current_energy_reserve == 30_u32, 'P04_DECAY_RESV');
        assert(first.state.last_decay_processed_block == 200_u64, 'P04_DECAY_CKP');

        // Same block: no newly elapsed full window, so no-op.
        let replay = process_hex_decay_once_with_status(
            first.state, 250_u64, 100_u64, 10_u32, 80_u16,
        );
        assert(replay.outcome == DecayProcessOutcome::NoElapsedPeriods, 'P04_DECAY_NOOP');
        assert(replay.periods_processed == 0_u64, 'P04_DECAY_NOOP_P');
        assert(replay.state.current_energy_reserve == 30_u32, 'P04_DECAY_NOOP_R');
        assert(replay.state.last_decay_processed_block == 200_u64, 'P04_DECAY_NOOP_C');
    }

    #[test]
    fn p04_red_death_during_active_harvest_lock() {
        // DD-020:
        // - Death cancels active harvest reservation and releases reserved yield.
        // - Active claim escrow is expired and refunded.
        // - Dead adventurer is blocked from new state-changing claim initiation.
        let alive = Adventurer {
            adventurer_id: 9901_felt252,
            owner: 42.try_into().unwrap(),
            name: 'MORTAL'_felt252,
            energy: 70_u16,
            max_energy: 100_u16,
            current_hex: 700_felt252,
            activity_locked_until: 777_u64,
            is_alive: true,
        };

        let killed = kill_once_with_status(alive);
        assert(killed.status == AdventurerWriteStatus::Applied, 'P04_DIE_APPLIED');
        assert(!killed.value.is_alive, 'P04_DIE_ALIVE');
        assert(killed.value.activity_locked_until == 0_u64, 'P04_DIE_UNLOCK');

        let plant = PlantNode {
            plant_key: 999_felt252,
            hex_coordinate: 700_felt252,
            area_id: 701_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 40_u16,
            reserved_yield: 20_u16,
            max_yield: 40_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 555_felt252,
            last_harvest_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
        };
        let reservation = HarvestReservation {
            reservation_id: 8801_felt252,
            adventurer_id: killed.value.adventurer_id,
            plant_key: 999_felt252,
            reserved_amount: 20_u16,
            created_block: 10_u64,
            expiry_block: 110_u64,
            status: HarvestReservationStatus::Active,
        };

        let settled = settle_harvest_reservation_on_death(
            plant, reservation, killed.value.adventurer_id,
        );
        assert(settled.outcome == HarvestDeathSettleOutcome::Applied, 'P04_DIE_HARVEST_APPLY');
        assert(settled.plant.reserved_yield == 0_u16, 'P04_DIE_HARVEST_RELEASE');
        assert(
            settled.reservation.status == HarvestReservationStatus::Canceled,
            'P04_DIE_HARVEST_CANCEL',
        );
        assert(settled.reservation.reserved_amount == 0_u16, 'P04_DIE_HARVEST_ZERO');

        let active_escrow = ClaimEscrow {
            claim_id: 7701_felt252,
            hex_coordinate: 700_felt252,
            claimant_adventurer_id: killed.value.adventurer_id,
            energy_locked: 30_u16,
            created_block: 20_u64,
            expiry_block: 120_u64,
            status: ClaimEscrowStatus::Active,
        };
        let expired = expire_claim_escrow_once_with_status(killed.value, active_escrow, 200_u64);
        assert(expired.outcome == ClaimEscrowExpireOutcome::Applied, 'P04_DIE_ESCROW_EXP');
        assert(expired.adventurer.energy == 100_u16, 'P04_DIE_ESCROW_REFUND');
        assert(expired.escrow.status == ClaimEscrowStatus::Expired, 'P04_DIE_ESCROW_ST');
        assert(expired.escrow.energy_locked == 0_u16, 'P04_DIE_ESCROW_ZERO');

        let new_escrow = ClaimEscrow {
            claim_id: 7702_felt252,
            hex_coordinate: 701_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };
        let blocked = initiate_claim_escrow_once_with_status(
            expired.adventurer, new_escrow, 10_u16, 201_u64, 100_u64,
        );
        assert(blocked.outcome == ClaimEscrowInitOutcome::Dead, 'P04_DIE_BLOCK_OUT');
        assert(blocked.adventurer.energy == 100_u16, 'P04_DIE_BLOCK_ENE');
        assert(blocked.escrow.status == ClaimEscrowStatus::Inactive, 'P04_DIE_BLOCK_ST');
    }
}
