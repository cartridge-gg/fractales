use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct DeathRecord {
    #[key]
    pub adventurer_id: felt252,
    pub owner: ContractAddress,
    pub death_block: u64,
    pub death_cause: felt252,
    pub inventory_lost_hash: felt252,
}

pub fn derive_inventory_loss_hash(
    adventurer_id: felt252,
    current_weight: u32,
    item_summary: felt252,
    death_cause: felt252,
    death_block: u64,
) -> felt252 {
    let weight_felt: felt252 = current_weight.into();
    let block_felt: felt252 = death_block.into();
    let (stage_one, _, _) = core::poseidon::hades_permutation(adventurer_id, weight_felt, item_summary);
    let (stage_two, _, _) = core::poseidon::hades_permutation(stage_one, death_cause, block_felt);
    let (final_hash, _, _) = core::poseidon::hades_permutation(
        stage_two, 'DEATH_INV_V1'_felt252, 0_felt252,
    );
    final_hash
}

pub fn build_death_record(
    adventurer_id: felt252,
    owner: ContractAddress,
    death_block: u64,
    death_cause: felt252,
    inventory_lost_hash: felt252,
) -> DeathRecord {
    DeathRecord { adventurer_id, owner, death_block, death_cause, inventory_lost_hash }
}
