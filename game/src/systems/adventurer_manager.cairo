use core::traits::TryInto;
use dojo_starter::models::adventurer::{
    Adventurer, AdventurerWriteStatus, can_be_controlled_by, kill_once_with_status, origin_hex_coordinate,
    spend_energy,
};
use dojo_starter::models::deaths::{DeathRecord, build_death_record, derive_inventory_loss_hash};
use dojo_starter::models::economics::AdventurerEconomics;
use dojo_starter::models::inventory::{Inventory, clear_inventory};
use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum CreateOutcome {
    #[default]
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ConsumeOutcome {
    #[default]
    Dead,
    NotOwner,
    InsufficientEnergy,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum RegenOutcome {
    #[default]
    Dead,
    NotOwner,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum KillOutcome {
    #[default]
    Replay,
    NotOwner,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct CreateResult {
    pub adventurer: Adventurer,
    pub inventory: Inventory,
    pub economics: AdventurerEconomics,
    pub outcome: CreateOutcome,
    pub emit_created: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ConsumeResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub outcome: ConsumeOutcome,
    pub regen_gained: u16,
    pub energy_spent: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct RegenResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub outcome: RegenOutcome,
    pub regen_gained: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct KillResult {
    pub adventurer: Adventurer,
    pub inventory: Inventory,
    pub death_record: DeathRecord,
    pub outcome: KillOutcome,
    pub emit_died: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
struct RegenApplyResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub gained: u16,
}

pub fn derive_adventurer_id(owner: ContractAddress, name: felt252, seed_block: u64) -> felt252 {
    let owner_felt: felt252 = owner.into();
    let block_felt: felt252 = seed_block.into();
    let (stage_one, _, _) = core::poseidon::hades_permutation(owner_felt, name, block_felt);
    let (id, _, _) = core::poseidon::hades_permutation(stage_one, 'ADV_ID_V1'_felt252, 0_felt252);
    id
}

pub fn create_transition(
    owner: ContractAddress, name: felt252, seed_block: u64, max_energy: u16, max_weight: u32,
) -> CreateResult {
    let adventurer_id = derive_adventurer_id(owner, name, seed_block);
    let adventurer = Adventurer {
        adventurer_id,
        owner,
        name,
        energy: max_energy,
        max_energy,
        current_hex: origin_hex_coordinate(),
        activity_locked_until: 0_u64,
        is_alive: true,
    };
    let inventory = Inventory { adventurer_id, current_weight: 0_u32, max_weight };
    let economics = AdventurerEconomics {
        adventurer_id,
        energy_balance: max_energy,
        total_energy_spent: 0_u64,
        total_energy_earned: 0_u64,
        last_regen_block: seed_block,
    };

    CreateResult { adventurer, inventory, economics, outcome: CreateOutcome::Applied, emit_created: true }
}

fn apply_lazy_regen(
    mut adventurer: Adventurer,
    mut economics: AdventurerEconomics,
    now_block: u64,
    regen_per_100_blocks: u16,
) -> RegenApplyResult {
    let mut gained = 0_u16;

    if now_block > economics.last_regen_block && adventurer.energy < adventurer.max_energy {
        if regen_per_100_blocks == 0_u16 {
            economics.last_regen_block = now_block;
            economics.energy_balance = adventurer.energy;
            return RegenApplyResult { adventurer, economics, gained };
        }

        let block_delta = now_block - economics.last_regen_block;
        let raw_gain_u128: u128 = (block_delta.into() * regen_per_100_blocks.into()) / 100_u128;
        if raw_gain_u128 > 0_u128 {
            let max_gain = adventurer.max_energy - adventurer.energy;
            gained = if raw_gain_u128 > max_gain.into() {
                max_gain
            } else {
                raw_gain_u128.try_into().unwrap()
            };

            adventurer.energy += gained;
            economics.total_energy_earned += gained.into();

            if adventurer.energy == adventurer.max_energy {
                economics.last_regen_block = now_block;
            } else {
                let used_blocks_u128: u128 = (gained.into() * 100_u128) / regen_per_100_blocks.into();
                let used_blocks: u64 = used_blocks_u128.try_into().unwrap();
                economics.last_regen_block += used_blocks;
            }
        }
    } else if adventurer.energy == adventurer.max_energy && now_block > economics.last_regen_block {
        economics.last_regen_block = now_block;
    }
    economics.energy_balance = adventurer.energy;

    RegenApplyResult { adventurer, economics, gained }
}

pub fn consume_transition(
    adventurer: Adventurer,
    mut economics: AdventurerEconomics,
    caller: ContractAddress,
    amount: u16,
    now_block: u64,
    regen_per_100_blocks: u16,
) -> ConsumeResult {
    if !adventurer.is_alive {
        return ConsumeResult {
            adventurer,
            economics,
            outcome: ConsumeOutcome::Dead,
            regen_gained: 0_u16,
            energy_spent: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return ConsumeResult {
            adventurer,
            economics,
            outcome: ConsumeOutcome::NotOwner,
            regen_gained: 0_u16,
            energy_spent: 0_u16,
        };
    }

    economics.adventurer_id = adventurer.adventurer_id;
    let regen = apply_lazy_regen(adventurer, economics, now_block, regen_per_100_blocks);

    match spend_energy(regen.adventurer, amount) {
        Option::Some(updated) => {
            let mut next_economics = regen.economics;
            next_economics.energy_balance = updated.energy;
            next_economics.total_energy_spent += amount.into();
            ConsumeResult {
                adventurer: updated,
                economics: next_economics,
                outcome: ConsumeOutcome::Applied,
                regen_gained: regen.gained,
                energy_spent: amount,
            }
        },
        Option::None => ConsumeResult {
            adventurer: regen.adventurer,
            economics: regen.economics,
            outcome: ConsumeOutcome::InsufficientEnergy,
            regen_gained: regen.gained,
            energy_spent: 0_u16,
        },
    }
}

pub fn regenerate_transition(
    adventurer: Adventurer,
    mut economics: AdventurerEconomics,
    caller: ContractAddress,
    now_block: u64,
    regen_per_100_blocks: u16,
) -> RegenResult {
    if !adventurer.is_alive {
        return RegenResult {
            adventurer, economics, outcome: RegenOutcome::Dead, regen_gained: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return RegenResult {
            adventurer, economics, outcome: RegenOutcome::NotOwner, regen_gained: 0_u16,
        };
    }

    economics.adventurer_id = adventurer.adventurer_id;
    let regen = apply_lazy_regen(adventurer, economics, now_block, regen_per_100_blocks);
    RegenResult {
        adventurer: regen.adventurer,
        economics: regen.economics,
        outcome: RegenOutcome::Applied,
        regen_gained: regen.gained,
    }
}

pub fn kill_transition(
    adventurer: Adventurer,
    inventory: Inventory,
    caller: ContractAddress,
    death_block: u64,
    death_cause: felt252,
    item_summary: felt252,
) -> KillResult {
    if !can_be_controlled_by(adventurer, caller) {
        return KillResult {
            adventurer,
            inventory,
            death_record: build_death_record(
                adventurer.adventurer_id, adventurer.owner, death_block, death_cause, 0_felt252,
            ),
            outcome: KillOutcome::NotOwner,
            emit_died: false,
        };
    }

    let killed = kill_once_with_status(adventurer);
    match killed.status {
        AdventurerWriteStatus::Applied => {
            let inventory_lost_hash = derive_inventory_loss_hash(
                killed.value.adventurer_id,
                inventory.current_weight,
                item_summary,
                death_cause,
                death_block,
            );
            let death_record = build_death_record(
                killed.value.adventurer_id,
                killed.value.owner,
                death_block,
                death_cause,
                inventory_lost_hash,
            );

            KillResult {
                adventurer: killed.value,
                inventory: clear_inventory(inventory),
                death_record,
                outcome: KillOutcome::Applied,
                emit_died: true,
            }
        },
        AdventurerWriteStatus::Replay => KillResult {
            adventurer: killed.value,
            inventory,
            death_record: build_death_record(
                killed.value.adventurer_id, killed.value.owner, death_block, death_cause, 0_felt252,
            ),
            outcome: KillOutcome::Replay,
            emit_died: false,
        },
    }
}
