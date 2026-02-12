#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::systems::ownership_manager::{
        OwnershipTransferOutcome, get_owner_transition, transfer_transition,
    };

    #[test]
    fn ownership_manager_get_owner_returns_area_controller() {
        let ownership = AreaOwnership {
            area_id: 700_felt252,
            owner_adventurer_id: 8001_felt252,
            discoverer_adventurer_id: 8000_felt252,
            discovery_block: 10_u64,
            claim_block: 20_u64,
        };

        let owner_id = get_owner_transition(ownership);
        assert(owner_id == 8001_felt252, 'OWN_GET_OWNER');
    }

    #[test]
    fn ownership_manager_transfer_updates_owner_and_claim_block() {
        let caller = 0x311.try_into().unwrap();
        let owner = Adventurer {
            adventurer_id: 8101_felt252,
            owner: caller,
            name: 'OWN'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let ownership = AreaOwnership {
            area_id: 701_felt252,
            owner_adventurer_id: 8101_felt252,
            discoverer_adventurer_id: 8000_felt252,
            discovery_block: 10_u64,
            claim_block: 0_u64,
        };

        let transferred = transfer_transition(ownership, owner, caller, 8102_felt252, 200_u64);
        assert(transferred.outcome == OwnershipTransferOutcome::Applied, 'OWN_TR_OUT');
        assert(transferred.ownership.owner_adventurer_id == 8102_felt252, 'OWN_TR_OWNER');
        assert(transferred.ownership.claim_block == 200_u64, 'OWN_TR_BLOCK');
        assert(transferred.ownership.discoverer_adventurer_id == 8000_felt252, 'OWN_TR_DISC');
    }

    #[test]
    fn ownership_manager_transfer_rejects_wrong_owner_or_invalid_target() {
        let owner_addr = 0x322.try_into().unwrap();
        let wrong_addr = 0x323.try_into().unwrap();
        let owner = Adventurer {
            adventurer_id: 8201_felt252,
            owner: owner_addr,
            name: 'OWN2'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: 0_felt252,
            activity_locked_until: 0_u64,
            is_alive: true,
        };
        let ownership = AreaOwnership {
            area_id: 702_felt252,
            owner_adventurer_id: 8201_felt252,
            discoverer_adventurer_id: 8200_felt252,
            discovery_block: 10_u64,
            claim_block: 0_u64,
        };

        let wrong_caller = transfer_transition(ownership, owner, wrong_addr, 8202_felt252, 201_u64);
        assert(wrong_caller.outcome == OwnershipTransferOutcome::NotOwner, 'OWN_TR_NOT_OWNER');
        assert(wrong_caller.ownership.owner_adventurer_id == 8201_felt252, 'OWN_TR_NOT_OWNER_KEEP');

        let invalid_target = transfer_transition(ownership, owner, owner_addr, 0_felt252, 201_u64);
        assert(
            invalid_target.outcome == OwnershipTransferOutcome::InvalidTarget,
            'OWN_TR_BAD_TARGET',
        );
        assert(
            invalid_target.ownership.owner_adventurer_id == 8201_felt252,
            'OWN_TR_BAD_TARGET_KEEP',
        );
    }
}
