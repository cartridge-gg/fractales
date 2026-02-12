#[cfg(test)]
mod tests {
    use dojo_starter::events::adventurer_events::{AdventurerCreated, AdventurerDied, AdventurerMoved};
    use starknet::ContractAddress;

    #[test]
    fn adventurer_events_created_payload_shape() {
        let owner: ContractAddress = 10.try_into().unwrap();
        let event = AdventurerCreated { adventurer_id: 101_felt252, owner };

        assert(event.adventurer_id == 101_felt252, 'ADV_CREATED_ID');
        assert(event.owner == owner, 'ADV_CREATED_OWNER');
    }

    #[test]
    fn adventurer_events_moved_payload_shape() {
        let event = AdventurerMoved {
            adventurer_id: 202_felt252,
            from: 500_felt252,
            to: 501_felt252,
        };

        assert(event.adventurer_id == 202_felt252, 'ADV_MOVED_ID');
        assert(event.from == 500_felt252, 'ADV_MOVED_FROM');
        assert(event.to == 501_felt252, 'ADV_MOVED_TO');
    }

    #[test]
    fn adventurer_events_died_payload_shape() {
        let owner: ContractAddress = 77.try_into().unwrap();
        let event = AdventurerDied {
            adventurer_id: 303_felt252,
            owner,
            cause: 'FALL'_felt252,
        };

        assert(event.adventurer_id == 303_felt252, 'ADV_DIED_ID');
        assert(event.owner == owner, 'ADV_DIED_OWNER');
        assert(event.cause == 'FALL'_felt252, 'ADV_DIED_CAUSE');
    }
}
