#[cfg(test)]
mod tests {
    use dojo_starter::models::deaths::{DeathRecord, build_death_record, derive_inventory_loss_hash};
    use starknet::ContractAddress;

    #[test]
    fn death_models_inventory_loss_hash_is_deterministic() {
        let adventurer_id: felt252 = 9001;
        let current_weight: u32 = 123_u32;
        let item_summary: felt252 = 'ITEMS'_felt252;
        let death_cause: felt252 = 'FALL'_felt252;
        let death_block: u64 = 777_u64;

        let a = derive_inventory_loss_hash(
            adventurer_id, current_weight, item_summary, death_cause, death_block,
        );
        let b = derive_inventory_loss_hash(
            adventurer_id, current_weight, item_summary, death_cause, death_block,
        );
        let changed = derive_inventory_loss_hash(
            adventurer_id, current_weight + 1_u32, item_summary, death_cause, death_block,
        );

        assert(a == b, 'DEATH_HASH_DETERMINISTIC');
        assert(a != changed, 'DEATH_HASH_INPUT_CHANGE');
    }

    #[test]
    fn death_models_build_record_payload() {
        let owner: ContractAddress = 12.try_into().unwrap();
        let record: DeathRecord = build_death_record(
            100_felt252, owner, 999_u64, 'TRAP'_felt252, 444_felt252,
        );

        assert(record.adventurer_id == 100_felt252, 'DEATH_RECORD_ID');
        assert(record.owner == owner, 'DEATH_RECORD_OWNER');
        assert(record.death_block == 999_u64, 'DEATH_RECORD_BLOCK');
        assert(record.death_cause == 'TRAP'_felt252, 'DEATH_RECORD_CAUSE');
        assert(record.inventory_lost_hash == 444_felt252, 'DEATH_RECORD_HASH');
    }
}
