#[cfg(test)]
mod tests {
    use dojo_starter::events::harvesting_events::{
        HarvestingCancelled, HarvestingCompleted, HarvestingStarted,
    };

    #[test]
    fn harvesting_events_started_payload_shape() {
        let event = HarvestingStarted {
            adventurer_id: 1001_felt252,
            hex: 500_felt252,
            area_id: 501_felt252,
            plant_id: 2_u8,
            amount: 7_u16,
            eta: 999_u64,
        };

        assert(event.adventurer_id == 1001_felt252, 'H_EVT_START_ID');
        assert(event.hex == 500_felt252, 'H_EVT_START_HEX');
        assert(event.area_id == 501_felt252, 'H_EVT_START_AREA');
        assert(event.plant_id == 2_u8, 'H_EVT_START_PLANT');
        assert(event.amount == 7_u16, 'H_EVT_START_AMT');
        assert(event.eta == 999_u64, 'H_EVT_START_ETA');
    }

    #[test]
    fn harvesting_events_completed_payload_shape() {
        let event = HarvestingCompleted {
            adventurer_id: 1002_felt252,
            hex: 700_felt252,
            area_id: 701_felt252,
            plant_id: 3_u8,
            actual_yield: 9_u16,
        };

        assert(event.adventurer_id == 1002_felt252, 'H_EVT_COMP_ID');
        assert(event.hex == 700_felt252, 'H_EVT_COMP_HEX');
        assert(event.area_id == 701_felt252, 'H_EVT_COMP_AREA');
        assert(event.plant_id == 3_u8, 'H_EVT_COMP_PLANT');
        assert(event.actual_yield == 9_u16, 'H_EVT_COMP_YIELD');
    }

    #[test]
    fn harvesting_events_cancelled_payload_shape() {
        let event = HarvestingCancelled {
            adventurer_id: 1003_felt252,
            partial_yield: 4_u16,
        };

        assert(event.adventurer_id == 1003_felt252, 'H_EVT_CANCEL_ID');
        assert(event.partial_yield == 4_u16, 'H_EVT_CANCEL_PART');
    }
}
