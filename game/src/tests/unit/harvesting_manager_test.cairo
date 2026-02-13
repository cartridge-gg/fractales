#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{
        HarvestDeathSettleOutcome, HarvestReservation, HarvestReservationStatus, PlantNode,
        settle_harvest_reservation_on_death, derive_harvest_item_id,
        derive_harvest_reservation_id, derive_plant_key,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::systems::harvesting_manager::{
        CompleteOutcome, InitOutcome, StartOutcome, CancelOutcome,
        complete_transition, init_transition, start_transition, cancel_transition,
    };
    use starknet::ContractAddress;

    fn setup_actor() -> (Adventurer, AdventurerEconomics, Inventory, ContractAddress) {
        let owner: ContractAddress = 77.try_into().unwrap();
        let adventurer = Adventurer {
            adventurer_id: 7700_felt252,
            owner,
            name: 'HARV'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 500_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let economics = AdventurerEconomics {
            adventurer_id: adventurer.adventurer_id,
            energy_balance: 100_u16,
            total_energy_spent: 0_u64,
            total_energy_earned: 0_u64,
            last_regen_block: 0_u64,
        };
        let inventory = Inventory {
            adventurer_id: adventurer.adventurer_id,
            current_weight: 0_u32,
            max_weight: 100_u32,
        };
        (adventurer, economics, inventory, owner)
    }

    #[test]
    fn harvesting_manager_init_requires_discovered_hex() {
        let owner: ContractAddress = 11.try_into().unwrap();
        let plant = PlantNode {
            plant_key: derive_plant_key(500_felt252, 501_felt252, 1_u8),
            hex_coordinate: 500_felt252,
            area_id: 501_felt252,
            plant_id: 1_u8,
            species: 0_felt252,
            current_yield: 0_u16,
            reserved_yield: 0_u16,
            max_yield: 0_u16,
            regrowth_rate: 0_u16,
            health: 0_u16,
            stress_level: 0_u16,
            genetics_hash: 0_felt252,
            last_harvest_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
        };

        let blocked = init_transition(
            plant, owner, false, true, true, true, 'ROOT'_felt252, 40_u16, 2_u16, 444_felt252, 100_u64,
        );
        assert(blocked.outcome == InitOutcome::HexUndiscovered, 'H_INIT_BLOCK');

        let area_blocked = init_transition(
            blocked.plant,
            owner,
            true,
            false,
            true,
            true,
            'ROOT'_felt252,
            40_u16,
            2_u16,
            444_felt252,
            100_u64,
        );
        assert(area_blocked.outcome == InitOutcome::AreaUndiscovered, 'H_INIT_AREA_BLOCK');

        let type_blocked = init_transition(
            area_blocked.plant,
            owner,
            true,
            true,
            false,
            true,
            'ROOT'_felt252,
            40_u16,
            2_u16,
            444_felt252,
            100_u64,
        );
        assert(type_blocked.outcome == InitOutcome::AreaNotPlantField, 'H_INIT_TYPE_BLOCK');

        let initialized = init_transition(
            type_blocked.plant,
            owner,
            true,
            true,
            true,
            true,
            'ROOT'_felt252,
            40_u16,
            2_u16,
            444_felt252,
            100_u64,
        );
        assert(initialized.outcome == InitOutcome::Applied, 'H_INIT_OK');
        assert(initialized.plant.current_yield == 40_u16, 'H_INIT_YIELD');
        assert(initialized.plant.health == 100_u16, 'H_INIT_HEALTH');
        assert(initialized.plant.genetics_hash == 444_felt252, 'H_INIT_GENE');
        assert(initialized.plant.discoverer == owner, 'H_INIT_DISC');
    }

    #[test]
    fn harvesting_manager_init_rejects_out_of_range_plant_id() {
        let owner: ContractAddress = 12.try_into().unwrap();
        let plant = PlantNode {
            plant_key: derive_plant_key(510_felt252, 511_felt252, 250_u8),
            hex_coordinate: 510_felt252,
            area_id: 511_felt252,
            plant_id: 250_u8,
            species: 0_felt252,
            current_yield: 0_u16,
            reserved_yield: 0_u16,
            max_yield: 0_u16,
            regrowth_rate: 0_u16,
            health: 0_u16,
            stress_level: 0_u16,
            genetics_hash: 0_felt252,
            last_harvest_block: 0_u64,
            discoverer: 0.try_into().unwrap(),
        };

        let rejected = init_transition(
            plant,
            owner,
            true,
            true,
            true,
            false,
            'ROOT'_felt252,
            40_u16,
            2_u16,
            444_felt252,
            100_u64,
        );
        assert(rejected.outcome == InitOutcome::PlantIdOutOfRange, 'H_INIT_PLANT_RANGE');
    }

    #[test]
    fn harvesting_manager_start_checks_preconditions_and_spends_energy() {
        let (adventurer, economics, _inventory, owner) = setup_actor();
        let plant_key = derive_plant_key(500_felt252, 501_felt252, 1_u8);
        let plant = PlantNode {
            plant_key,
            hex_coordinate: 500_felt252,
            area_id: 501_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 12_u16,
            reserved_yield: 0_u16,
            max_yield: 12_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 1_felt252,
            last_harvest_block: 0_u64,
            discoverer: owner,
        };
        let reservation = HarvestReservation {
            reservation_id: derive_harvest_reservation_id(adventurer.adventurer_id, plant_key),
            adventurer_id: 0_felt252,
            plant_key,
            reserved_amount: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: HarvestReservationStatus::Inactive,
        };

        let success = start_transition(
            adventurer, economics, owner, plant, reservation, 3_u16, 100_u64, 20_u16, 10_u16, 2_u16,
        );
        assert(success.outcome == StartOutcome::Applied, 'H_START_OK');
        assert(success.plant.reserved_yield == 3_u16, 'H_START_RESERVED');
        assert(success.adventurer.energy == 70_u16, 'H_START_ENERGY');
        assert(success.adventurer.activity_locked_until == 106_u64, 'H_START_LOCK');
        assert(success.reservation.status == HarvestReservationStatus::Active, 'H_START_STATUS');

        let replay = start_transition(
            success.adventurer,
            success.economics,
            owner,
            success.plant,
            success.reservation,
            1_u16,
            101_u64,
            20_u16,
            10_u16,
            2_u16,
        );
        assert(replay.outcome == StartOutcome::AlreadyActive, 'H_START_ACTIVE');
    }

    #[test]
    fn harvesting_manager_complete_and_cancel_settle_lifecycle() {
        let (adventurer, economics, inventory, owner) = setup_actor();
        let plant_key = derive_plant_key(500_felt252, 501_felt252, 1_u8);
        let base_item = BackpackItem {
            adventurer_id: adventurer.adventurer_id,
            item_id: derive_harvest_item_id(plant_key),
            quantity: 0_u32,
            quality: 0_u16,
            weight_per_unit: 0_u16,
        };
        let plant = PlantNode {
            plant_key,
            hex_coordinate: 500_felt252,
            area_id: 501_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 20_u16,
            reserved_yield: 0_u16,
            max_yield: 20_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 1_felt252,
            last_harvest_block: 0_u64,
            discoverer: owner,
        };
        let reservation = HarvestReservation {
            reservation_id: derive_harvest_reservation_id(adventurer.adventurer_id, plant_key),
            adventurer_id: 0_felt252,
            plant_key,
            reserved_amount: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: HarvestReservationStatus::Inactive,
        };

        let started = start_transition(
            adventurer, economics, owner, plant, reservation, 4_u16, 100_u64, 20_u16, 10_u16, 2_u16,
        );
        let early = complete_transition(
            started.adventurer,
            owner,
            started.plant,
            started.reservation,
            inventory,
            base_item,
            105_u64,
        );
        assert(early.outcome == CompleteOutcome::TooEarly, 'H_COMPLETE_EARLY');

        let completed = complete_transition(
            early.adventurer, owner, early.plant, early.reservation, early.inventory, early.item, 108_u64,
        );
        assert(completed.outcome == CompleteOutcome::Applied, 'H_COMPLETE_OK');
        assert(completed.actual_yield == 4_u16, 'H_COMPLETE_YIELD');
        assert(completed.plant.current_yield == 16_u16, 'H_COMPLETE_CURR');
        assert(completed.plant.reserved_yield == 0_u16, 'H_COMPLETE_RESV');
        assert(completed.reservation.status == HarvestReservationStatus::Completed, 'H_COMPLETE_ST');
        assert(completed.inventory.current_weight == 4_u32, 'H_COMPLETE_INV');

        let restart = start_transition(
            completed.adventurer,
            started.economics,
            owner,
            completed.plant,
            completed.reservation,
            6_u16,
            200_u64,
            20_u16,
            10_u16,
            2_u16,
        );
        let canceled = cancel_transition(
            restart.adventurer,
            owner,
            restart.plant,
            restart.reservation,
            completed.inventory,
            completed.item,
            206_u64,
        );
        assert(canceled.outcome == CancelOutcome::Applied, 'H_CANCEL_OK');
        assert(canceled.partial_yield == 3_u16, 'H_CANCEL_PART');
        assert(canceled.reservation.status == HarvestReservationStatus::Canceled, 'H_CANCEL_ST');
        assert(canceled.plant.reserved_yield == 0_u16, 'H_CANCEL_RESV');
    }

    #[test]
    fn harvesting_manager_start_reports_reserve_failures() {
        let (adventurer, economics, _inventory, owner) = setup_actor();
        let aligned_actor = Adventurer { current_hex: 510_felt252, ..adventurer };
        let plant_key = derive_plant_key(510_felt252, 511_felt252, 1_u8);
        let reservation = HarvestReservation {
            reservation_id: derive_harvest_reservation_id(aligned_actor.adventurer_id, plant_key),
            adventurer_id: 0_felt252,
            plant_key,
            reserved_amount: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: HarvestReservationStatus::Inactive,
        };
        let base_plant = PlantNode {
            plant_key,
            hex_coordinate: 510_felt252,
            area_id: 511_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 2_u16,
            reserved_yield: 0_u16,
            max_yield: 10_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 1_felt252,
            last_harvest_block: 0_u64,
            discoverer: owner,
        };

        let insufficient = start_transition(
            aligned_actor,
            economics,
            owner,
            base_plant,
            reservation,
            5_u16,
            0_u64,
            20_u16,
            10_u16,
            2_u16,
        );
        assert(insufficient.outcome == StartOutcome::InsufficientYield, 'H_START_INSUFF_YIELD');

        let invalid_plant = PlantNode { reserved_yield: 3_u16, ..base_plant };
        let invalid_state = start_transition(
            aligned_actor,
            economics,
            owner,
            invalid_plant,
            reservation,
            1_u16,
            0_u64,
            20_u16,
            10_u16,
            2_u16,
        );
        assert(invalid_state.outcome == StartOutcome::InvalidPlantState, 'H_START_BAD_STATE');
    }

    #[test]
    fn harvesting_manager_requires_actor_on_plant_hex_for_start_and_complete() {
        let (adventurer, economics, inventory, owner) = setup_actor();
        let plant_key = derive_plant_key(530_felt252, 531_felt252, 1_u8);
        let plant = PlantNode {
            plant_key,
            hex_coordinate: 530_felt252,
            area_id: 531_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 10_u16,
            reserved_yield: 0_u16,
            max_yield: 10_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 1_felt252,
            last_harvest_block: 0_u64,
            discoverer: owner,
        };
        let reservation = HarvestReservation {
            reservation_id: derive_harvest_reservation_id(adventurer.adventurer_id, plant_key),
            adventurer_id: 0_felt252,
            plant_key,
            reserved_amount: 0_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: HarvestReservationStatus::Inactive,
        };

        let aligned_actor = Adventurer { current_hex: 530_felt252, ..adventurer };
        let wrong_hex_actor = Adventurer { current_hex: 777_felt252, ..aligned_actor };
        let wrong_hex_start = start_transition(
            wrong_hex_actor,
            economics,
            owner,
            plant,
            reservation,
            2_u16,
            100_u64,
            20_u16,
            10_u16,
            2_u16,
        );
        assert(wrong_hex_start.outcome == StartOutcome::WrongHex, 'H_START_WRONG_HEX');

        let started = start_transition(
            aligned_actor, economics, owner, plant, reservation, 2_u16, 100_u64, 20_u16, 10_u16, 2_u16,
        );
        assert(started.outcome == StartOutcome::Applied, 'H_START_APPLY_FOR_COMPLETE');
        let relocated = Adventurer { current_hex: 999_felt252, ..started.adventurer };
        let base_item = BackpackItem {
            adventurer_id: started.adventurer.adventurer_id,
            item_id: derive_harvest_item_id(plant_key),
            quantity: 0_u32,
            quality: 0_u16,
            weight_per_unit: 0_u16,
        };

        let wrong_hex_complete = complete_transition(
            relocated, owner, started.plant, started.reservation, inventory, base_item, 104_u64,
        );
        assert(wrong_hex_complete.outcome == CompleteOutcome::WrongHex, 'H_COMPLETE_WRONG_HEX');
    }

    #[test]
    fn harvesting_models_settle_death_clamps_release_to_reserved_yield() {
        let (_adventurer, _economics, _inventory, owner) = setup_actor();
        let plant_key = derive_plant_key(520_felt252, 521_felt252, 1_u8);
        let plant = PlantNode {
            plant_key,
            hex_coordinate: 520_felt252,
            area_id: 521_felt252,
            plant_id: 1_u8,
            species: 'ROOT'_felt252,
            current_yield: 10_u16,
            reserved_yield: 2_u16,
            max_yield: 10_u16,
            regrowth_rate: 1_u16,
            health: 100_u16,
            stress_level: 0_u16,
            genetics_hash: 1_felt252,
            last_harvest_block: 0_u64,
            discoverer: owner,
        };
        let reservation = HarvestReservation {
            reservation_id: derive_harvest_reservation_id(7700_felt252, plant_key),
            adventurer_id: 7700_felt252,
            plant_key,
            reserved_amount: 5_u16,
            created_block: 0_u64,
            expiry_block: 0_u64,
            status: HarvestReservationStatus::Active,
        };

        let settled = settle_harvest_reservation_on_death(plant, reservation, 7700_felt252);
        assert(settled.outcome == HarvestDeathSettleOutcome::Applied, 'H_DEATH_SETTLE_APPLIED');
        assert(settled.released_amount == 2_u16, 'H_DEATH_SETTLE_CLAMP');
        assert(settled.plant.reserved_yield == 0_u16, 'H_DEATH_SETTLE_PLANT');
        assert(settled.reservation.reserved_amount == 0_u16, 'H_DEATH_SETTLE_RESV');
        assert(settled.reservation.status == HarvestReservationStatus::Canceled, 'H_DEATH_SETTLE_ST');
    }
}
