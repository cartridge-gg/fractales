#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{
        AdventurerEconomics, ClaimEscrow, ClaimEscrowStatus, ConversionRate, HexDecayState,
        derive_hex_claim_id,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::world::Biome;
    use dojo_starter::systems::economic_manager::{
        ClaimInitOutcome, DecayOutcome, DefendOutcome, PayOutcome, ConvertOutcome,
        convert_transition, defend_claim_transition, initiate_claim_transition, pay_maintenance_transition,
        process_decay_transition,
    };

    #[test]
    fn economic_manager_convert_burns_items_and_mints_energy() {
        let owner = 0x111.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 5001_felt252,
            owner,
            name: 'CONV'_felt252,
            energy: 20_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 5001_felt252,
            energy_balance: 20_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let inventory = Inventory { adventurer_id: 5001_felt252, current_weight: 20_u32, max_weight: 100_u32 };
        let item = BackpackItem {
            adventurer_id: 5001_felt252,
            item_id: 77_felt252,
            quantity: 20_u32,
            quality: 100_u16,
            weight_per_unit: 1_u16,
        };
        let rate = ConversionRate {
            item_type: 77_felt252,
            current_rate: 10_u16,
            base_rate: 10_u16,
            last_update_block: 0_u64,
            units_converted_in_window: 0_u32,
        };

        let converted = convert_transition(
            adventurer, economics, owner, inventory, item, rate, 5_u16, 10_u64, 100_u64,
        );

        assert(converted.outcome == ConvertOutcome::Applied, 'S4_CONV_OUT');
        assert(converted.energy_gained == 50_u16, 'S4_CONV_GAIN');
        assert(converted.adventurer.energy == 70_u16, 'S4_CONV_ENE');
        assert(converted.economics.energy_balance == 70_u16, 'S4_CONV_BAL');
        assert(converted.item.quantity == 15_u32, 'S4_CONV_QTY');
        assert(converted.inventory.current_weight == 15_u32, 'S4_CONV_WT');
        assert(converted.rate.units_converted_in_window == 5_u32, 'S4_CONV_WIN');
    }

    #[test]
    fn economic_manager_pay_maintenance_requires_controller_and_spends_energy() {
        let owner = 0x222.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 6001_felt252,
            owner,
            name: 'KEEP'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 900_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 6001_felt252,
            energy_balance: 100_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let state = HexDecayState {
            hex_coordinate: 900_felt252,
            owner_adventurer_id: 6001_felt252,
            current_energy_reserve: 0_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 85_u16,
            claimable_since_block: 10_u64,
        };

        let paid = pay_maintenance_transition(
            adventurer, economics, owner, state, 70_u16, 35_u32, 100_u64, 20_u16, 80_u16,
        );

        assert(paid.outcome == PayOutcome::Applied, 'S4_PAY_OUT');
        assert(paid.adventurer.energy == 30_u16, 'S4_PAY_ENE');
        assert(paid.economics.energy_balance == 30_u16, 'S4_PAY_BAL');
        assert(paid.state.current_energy_reserve == 70_u32, 'S4_PAY_RESV');
        assert(paid.state.decay_level == 77_u16, 'S4_PAY_DECAY');
        assert(paid.state.claimable_since_block == 0_u64, 'S4_PAY_CLAIM_CLR');
    }

    #[test]
    fn economic_manager_process_decay_sets_claimable_checkpoint() {
        let state = HexDecayState {
            hex_coordinate: 901_felt252,
            owner_adventurer_id: 7001_felt252,
            current_energy_reserve: 0_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 79_u16,
            claimable_since_block: 0_u64,
        };

        let processed = process_decay_transition(state, Biome::Desert, 200_u64, 100_u64, 80_u16);

        assert(processed.outcome == DecayOutcome::Applied, 'S4_DECAY_OUT');
        assert(processed.periods_processed == 2_u64, 'S4_DECAY_PERIODS');
        assert(processed.became_claimable, 'S4_DECAY_CLAIMABLE');
        assert(processed.state.claimable_since_block == 200_u64, 'S4_DECAY_CLAIM_SINCE');
        assert(processed.min_energy_to_claim > 0_u16, 'S4_DECAY_MIN');
    }

    #[test]
    fn economic_manager_claim_pending_then_defend_refunds_claimant() {
        let claimant_owner = 0x333.try_into().unwrap();
        let defender_owner = 0x444.try_into().unwrap();

        let claimant = Adventurer {
            adventurer_id: 8001_felt252,
            owner: claimant_owner,
            name: 'CLM'_felt252,
            energy: 500_u16,
            max_energy: 500_u16,
            current_hex: 902_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let claimant_econ = AdventurerEconomics {
            adventurer_id: 8001_felt252,
            energy_balance: 500_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };

        let defender = Adventurer {
            adventurer_id: 8002_felt252,
            owner: defender_owner,
            name: 'DEF'_felt252,
            energy: 400_u16,
            max_energy: 400_u16,
            current_hex: 902_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let defender_econ = AdventurerEconomics {
            adventurer_id: 8002_felt252,
            energy_balance: 400_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };

        let state = HexDecayState {
            hex_coordinate: 902_felt252,
            owner_adventurer_id: 8002_felt252,
            current_energy_reserve: 0_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 85_u16,
            claimable_since_block: 100_u64,
        };
        let claim_id = derive_hex_claim_id(902_felt252);
        let escrow = ClaimEscrow {
            claim_id,
            hex_coordinate: 902_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };

        let initiated = initiate_claim_transition(
            claimant,
            claimant_econ,
            claimant_owner,
            state,
            escrow,
            300_u16,
            200_u64,
            100_u64,
            500_u64,
            35_u32,
            20_u16,
            80_u16,
        );

        assert(initiated.outcome == ClaimInitOutcome::AppliedPending, 'S4_CLAIM_PENDING');
        assert(initiated.claimant.energy == 200_u16, 'S4_CLAIM_LOCK');
        assert(initiated.escrow.status == ClaimEscrowStatus::Active, 'S4_CLAIM_ESCROW');
        assert(initiated.escrow.energy_locked == 300_u16, 'S4_CLAIM_LOCKED');
        assert(initiated.escrow.expiry_block == 300_u64, 'S4_CLAIM_EXP');

        let defended = defend_claim_transition(
            defender,
            defender_econ,
            defender_owner,
            initiated.state,
            initiated.escrow,
            initiated.claimant,
            initiated.claimant_economics,
            300_u16,
            250_u64,
            35_u32,
            20_u16,
            80_u16,
        );

        assert(defended.outcome == DefendOutcome::Applied, 'S4_DEF_OUT');
        assert(defended.defender.energy == 100_u16, 'S4_DEF_ENE');
        assert(defended.claimant.energy == 500_u16, 'S4_DEF_REFUND');
        assert(defended.state.current_energy_reserve == 300_u32, 'S4_DEF_RESV');
        assert(defended.escrow.status == ClaimEscrowStatus::Resolved, 'S4_DEF_ESCROW');
        assert(defended.escrow.energy_locked == 0_u16, 'S4_DEF_LOCK_ZERO');
    }

    #[test]
    fn economic_manager_claim_immediate_resolves_escrow_and_transfers_control() {
        let claimant_owner = 0x555.try_into().unwrap();
        let claimant = Adventurer {
            adventurer_id: 8101_felt252,
            owner: claimant_owner,
            name: 'IMM'_felt252,
            energy: 500_u16,
            max_energy: 500_u16,
            current_hex: 903_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let claimant_econ = AdventurerEconomics {
            adventurer_id: 8101_felt252,
            energy_balance: 500_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let state = HexDecayState {
            hex_coordinate: 903_felt252,
            owner_adventurer_id: 8102_felt252,
            current_energy_reserve: 5_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 90_u16,
            claimable_since_block: 100_u64,
        };
        let escrow = ClaimEscrow {
            claim_id: derive_hex_claim_id(903_felt252),
            hex_coordinate: 903_felt252,
            claimant_adventurer_id: 0_felt252,
            energy_locked: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: ClaimEscrowStatus::Inactive,
        };

        let initiated = initiate_claim_transition(
            claimant,
            claimant_econ,
            claimant_owner,
            state,
            escrow,
            300_u16,
            700_u64,
            100_u64,
            500_u64,
            35_u32,
            20_u16,
            80_u16,
        );

        assert(initiated.outcome == ClaimInitOutcome::AppliedImmediate, 'S4_CLAIM_IMM_OUT');
        assert(initiated.claimant.energy == 200_u16, 'S4_CLAIM_IMM_ENE');
        assert(initiated.state.owner_adventurer_id == 8101_felt252, 'S4_CLAIM_IMM_OWNER');
        assert(initiated.state.current_energy_reserve == 305_u32, 'S4_CLAIM_IMM_RESV');
        assert(initiated.state.decay_level == 0_u16, 'S4_CLAIM_IMM_DECAY');
        assert(initiated.state.claimable_since_block == 0_u64, 'S4_CLAIM_IMM_CLAIM');
        assert(initiated.escrow.status == ClaimEscrowStatus::Resolved, 'S4_CLAIM_IMM_ESCROW');
        assert(initiated.escrow.energy_locked == 0_u16, 'S4_CLAIM_IMM_LOCK');
    }

    #[test]
    fn economic_manager_defend_expired_claim_marks_expired_and_refunds() {
        let defender_owner = 0x666.try_into().unwrap();
        let defender = Adventurer {
            adventurer_id: 8201_felt252,
            owner: defender_owner,
            name: 'D_EX'_felt252,
            energy: 400_u16,
            max_energy: 400_u16,
            current_hex: 904_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let defender_econ = AdventurerEconomics {
            adventurer_id: 8201_felt252,
            energy_balance: 400_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let claimant = Adventurer {
            adventurer_id: 8202_felt252,
            owner: 0x667.try_into().unwrap(),
            name: 'C_EX'_felt252,
            energy: 100_u16,
            max_energy: 300_u16,
            current_hex: 904_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let claimant_econ = AdventurerEconomics {
            adventurer_id: 8202_felt252,
            energy_balance: 100_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let state = HexDecayState {
            hex_coordinate: 904_felt252,
            owner_adventurer_id: 8201_felt252,
            current_energy_reserve: 10_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 90_u16,
            claimable_since_block: 100_u64,
        };
        let escrow = ClaimEscrow {
            claim_id: derive_hex_claim_id(904_felt252),
            hex_coordinate: 904_felt252,
            claimant_adventurer_id: 8202_felt252,
            energy_locked: 220_u16,
            created_block: 100_u64,
            expiry_block: 200_u64,
            status: ClaimEscrowStatus::Active,
        };

        let defended = defend_claim_transition(
            defender,
            defender_econ,
            defender_owner,
            state,
            escrow,
            claimant,
            claimant_econ,
            220_u16,
            201_u64,
            35_u32,
            20_u16,
            80_u16,
        );

        assert(defended.outcome == DefendOutcome::ClaimExpired, 'S4_DEF_EXP_OUT');
        assert(defended.defender.energy == 400_u16, 'S4_DEF_EXP_DEF_ENE');
        assert(defended.claimant.energy == 320_u16, 'S4_DEF_EXP_REFUND');
        assert(defended.claimant_economics.energy_balance == 320_u16, 'S4_DEF_EXP_BAL');
        assert(defended.escrow.status == ClaimEscrowStatus::Expired, 'S4_DEF_EXP_ST');
        assert(defended.escrow.energy_locked == 0_u16, 'S4_DEF_EXP_LOCK');
    }

    #[test]
    fn economic_manager_convert_saturates_window_counter() {
        let owner = 0x777.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 8301_felt252,
            owner,
            name: 'SAT'_felt252,
            energy: 10_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 8301_felt252,
            energy_balance: 10_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let inventory = Inventory { adventurer_id: 8301_felt252, current_weight: 30_u32, max_weight: 200_u32 };
        let item = BackpackItem {
            adventurer_id: 8301_felt252,
            item_id: 88_felt252,
            quantity: 30_u32,
            quality: 100_u16,
            weight_per_unit: 1_u16,
        };
        let rate = ConversionRate {
            item_type: 88_felt252,
            current_rate: 10_u16,
            base_rate: 10_u16,
            last_update_block: 100_u64,
            units_converted_in_window: 4_294_967_290_u32,
        };

        let converted = convert_transition(
            adventurer, economics, owner, inventory, item, rate, 20_u16, 150_u64, 100_u64,
        );

        assert(converted.outcome == ConvertOutcome::Applied, 'S4_CONV_SAT_OUT');
        assert(converted.rate.units_converted_in_window == 4_294_967_295_u32, 'S4_CONV_SAT_WIN');
    }

    #[test]
    fn economic_manager_pay_saturates_hex_reserve() {
        let owner = 0x778.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 8302_felt252,
            owner,
            name: 'PSAT'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 905_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 8302_felt252,
            energy_balance: 100_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let state = HexDecayState {
            hex_coordinate: 905_felt252,
            owner_adventurer_id: 8302_felt252,
            current_energy_reserve: 4_294_967_290_u32,
            last_energy_payment_block: 0_u64,
            last_decay_processed_block: 0_u64,
            decay_level: 85_u16,
            claimable_since_block: 1_u64,
        };

        let paid = pay_maintenance_transition(
            adventurer, economics, owner, state, 20_u16, 35_u32, 200_u64, 20_u16, 80_u16,
        );

        assert(paid.outcome == PayOutcome::Applied, 'S4_PAY_SAT_OUT');
        assert(paid.state.current_energy_reserve == 4_294_967_295_u32, 'S4_PAY_SAT_RESV');
    }
}
