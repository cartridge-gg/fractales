#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::deaths::DeathRecord;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::inventory::Inventory;
    use dojo_starter::systems::adventurer_manager::{
        ConsumeOutcome, CreateOutcome, KillOutcome, RegenOutcome, consume_transition, create_transition,
        kill_transition, regenerate_transition,
    };
    use starknet::ContractAddress;

    #[test]
    fn adventurer_manager_create_spawns_origin_energy_and_inventory() {
        let owner: ContractAddress = 11.try_into().unwrap();
        let result = create_transition(
            owner, 'HERO'_felt252, 100_u64, 100_u16, 750_u32,
        );

        assert(result.outcome == CreateOutcome::Applied, 'S2_CREATE_OK');
        assert(result.adventurer.owner == owner, 'S2_CREATE_OWN');
        assert(result.adventurer.energy == 100_u16, 'S2_CREATE_ENE');
        assert(result.adventurer.max_energy == 100_u16, 'S2_CREATE_MAX');
        assert(result.inventory.max_weight == 750_u32, 'S2_CREATE_WMAX');
        assert(result.inventory.current_weight == 0_u32, 'S2_CREATE_WZERO');
        assert(result.economics.last_regen_block == 100_u64, 'S2_CREATE_REGEN');
    }

    #[test]
    fn adventurer_manager_regen_is_delta_based_and_capped() {
        let owner: ContractAddress = 12.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 1200_felt252,
            owner,
            name: 'A'_felt252,
            energy: 20_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 1200_felt252,
            energy_balance: 20_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 100_u64,
        };

        let first = regenerate_transition(adventurer, economics, owner, 200_u64, 20_u16);
        assert(first.outcome == RegenOutcome::Applied, 'S2_REGEN_1_OK');
        assert(first.regen_gained == 20_u16, 'S2_REGEN_1_GAIN');
        assert(first.adventurer.energy == 40_u16, 'S2_REGEN_1_ENE');
        assert(first.economics.last_regen_block == 200_u64, 'S2_REGEN_1_B');

        let capped = regenerate_transition(
            first.adventurer, first.economics, owner, 2000_u64, 20_u16,
        );
        assert(capped.outcome == RegenOutcome::Applied, 'S2_REGEN_2_OK');
        assert(capped.adventurer.energy == 100_u16, 'S2_REGEN_CAP');
        assert(capped.economics.energy_balance == 100_u16, 'S2_REGEN_EB');
    }

    #[test]
    fn adventurer_manager_regen_preserves_block_remainder_when_gain_is_zero() {
        let owner: ContractAddress = 88.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 8800_felt252,
            owner,
            name: 'R'_felt252,
            energy: 10_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 8800_felt252,
            energy_balance: 10_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 100_u64,
        };

        let under_threshold = regenerate_transition(adventurer, economics, owner, 104_u64, 20_u16);
        assert(under_threshold.outcome == RegenOutcome::Applied, 'S2_REMAINDER_OK');
        assert(under_threshold.regen_gained == 0_u16, 'S2_REMAINDER_GAIN0');
        assert(under_threshold.adventurer.energy == 10_u16, 'S2_REMAINDER_ENE0');
        assert(under_threshold.economics.last_regen_block == 100_u64, 'S2_REMAINDER_BLOCK');

        let reaches_threshold = regenerate_transition(
            under_threshold.adventurer, under_threshold.economics, owner, 105_u64, 20_u16,
        );
        assert(reaches_threshold.regen_gained == 1_u16, 'S2_REMAINDER_GAIN1');
        assert(reaches_threshold.adventurer.energy == 11_u16, 'S2_REMAINDER_ENE1');
        assert(reaches_threshold.economics.last_regen_block == 105_u64, 'S2_REMAINDER_BLOCK1');
    }

    #[test]
    fn adventurer_manager_consume_applies_regen_then_spend_and_guards() {
        let owner: ContractAddress = 13.try_into().unwrap();
        let stranger: ContractAddress = 14.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 1300_felt252,
            owner,
            name: 'B'_felt252,
            energy: 10_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: 1300_felt252,
            energy_balance: 10_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };

        let applied = consume_transition(
            adventurer, economics, owner, 15_u16, 500_u64, 20_u16,
        );
        assert(applied.outcome == ConsumeOutcome::Applied, 'S2_CONSUME_OK');
        assert(applied.regen_gained == 90_u16, 'S2_CONSUME_GAIN');
        assert(applied.adventurer.energy == 85_u16, 'S2_CONSUME_ENE');
        assert(applied.economics.total_energy_spent == 15_u64, 'S2_CONSUME_SP');

        let wrong_owner = consume_transition(
            applied.adventurer, applied.economics, stranger, 1_u16, 600_u64, 20_u16,
        );
        assert(wrong_owner.outcome == ConsumeOutcome::NotOwner, 'S2_CONSUME_OWN');

        let dead = Adventurer { is_alive: false, ..applied.adventurer };
        let dead_result = consume_transition(dead, applied.economics, owner, 1_u16, 600_u64, 20_u16);
        assert(dead_result.outcome == ConsumeOutcome::Dead, 'S2_CONSUME_DEAD');
    }

    #[test]
    fn adventurer_manager_kill_clears_inventory_and_builds_record() {
        let owner: ContractAddress = 21.try_into().unwrap();
        let alive = Adventurer {
            adventurer_id: 2100_felt252,
            owner,
            name: 'C'_felt252,
            energy: 50_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 88_u64,
            is_alive: true,
        };
        let inventory = Inventory {
            adventurer_id: 2100_felt252,
            current_weight: 77_u32,
            max_weight: 500_u32,
        };

        let first = kill_transition(
            alive, inventory, owner, 777_u64, 'VOID'_felt252, 0_felt252,
        );
        assert(first.outcome == KillOutcome::Applied, 'S2_KILL_OK');
        assert(!first.adventurer.is_alive, 'S2_KILL_DEAD');
        assert(first.inventory.current_weight == 0_u32, 'S2_KILL_INV');
        let record: DeathRecord = first.death_record;
        assert(record.death_block == 777_u64, 'S2_KILL_BLOCK');
        assert(record.death_cause == 'VOID'_felt252, 'S2_KILL_CAUSE');

        let replay = kill_transition(
            first.adventurer, first.inventory, owner, 888_u64, 'ALT'_felt252, 0_felt252,
        );
        assert(replay.outcome == KillOutcome::Replay, 'S2_KILL_REPLAY');
    }
}
