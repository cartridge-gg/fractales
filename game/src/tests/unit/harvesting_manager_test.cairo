#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::AdventurerEconomics;
    use dojo_starter::models::harvesting::{
        HarvestReservation, HarvestReservationStatus, PlantNode, derive_harvest_item_id,
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
            plant, owner, false, 'ROOT'_felt252, 40_u16, 2_u16, 100_u64,
        );
        assert(blocked.outcome == InitOutcome::HexUndiscovered, 'H_INIT_BLOCK');

        let initialized = init_transition(
            blocked.plant, owner, true, 'ROOT'_felt252, 40_u16, 2_u16, 100_u64,
        );
        assert(initialized.outcome == InitOutcome::Applied, 'H_INIT_OK');
        assert(initialized.plant.current_yield == 40_u16, 'H_INIT_YIELD');
        assert(initialized.plant.health == 100_u16, 'H_INIT_HEALTH');
        assert(initialized.plant.discoverer == owner, 'H_INIT_DISC');
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
}
