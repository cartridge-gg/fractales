use core::traits::TryInto;
use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by};
use dojo_starter::models::economics::AdventurerEconomics;
use dojo_starter::models::harvesting::{
    HarvestReservation, HarvestReservationStatus, HarvestReserveOutcome, PlantNode, available_yield,
    reserve_yield_once_with_status,
};
use dojo_starter::models::inventory::{BackpackItem, Inventory};
use dojo_starter::systems::adventurer_manager::{ConsumeOutcome, consume_transition};
use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum InitOutcome {
    #[default]
    HexUndiscovered,
    AreaUndiscovered,
    AreaNotPlantField,
    PlantIdOutOfRange,
    AlreadyInitialized,
    InvalidConfig,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum StartOutcome {
    #[default]
    Dead,
    NotOwner,
    WrongHex,
    Locked,
    NotInitialized,
    AlreadyActive,
    InvalidAmount,
    InvalidPlantState,
    InsufficientYield,
    InsufficientEnergy,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum CompleteOutcome {
    #[default]
    Dead,
    NotOwner,
    WrongHex,
    NoActiveReservation,
    NotLinked,
    TooEarly,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum CancelOutcome {
    #[default]
    Dead,
    NotOwner,
    WrongHex,
    NoActiveReservation,
    NotLinked,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct InitResult {
    pub plant: PlantNode,
    pub outcome: InitOutcome,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct StartResult {
    pub adventurer: Adventurer,
    pub economics: AdventurerEconomics,
    pub plant: PlantNode,
    pub reservation: HarvestReservation,
    pub outcome: StartOutcome,
    pub eta: u64,
    pub energy_cost: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct CompleteResult {
    pub adventurer: Adventurer,
    pub plant: PlantNode,
    pub reservation: HarvestReservation,
    pub inventory: Inventory,
    pub item: BackpackItem,
    pub outcome: CompleteOutcome,
    pub actual_yield: u16,
    pub minted_yield: u16,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct CancelResult {
    pub adventurer: Adventurer,
    pub plant: PlantNode,
    pub reservation: HarvestReservation,
    pub inventory: Inventory,
    pub item: BackpackItem,
    pub outcome: CancelOutcome,
    pub partial_yield: u16,
    pub minted_yield: u16,
}

pub fn init_transition(
    mut plant: PlantNode,
    discoverer: ContractAddress,
    is_hex_discovered: bool,
    is_area_discovered: bool,
    is_area_plant_field: bool,
    is_plant_id_in_range: bool,
    species: felt252,
    max_yield: u16,
    regrowth_rate: u16,
    genetics_hash: felt252,
    now_block: u64,
) -> InitResult {
    if !is_hex_discovered {
        return InitResult { plant, outcome: InitOutcome::HexUndiscovered };
    }
    if !is_area_discovered {
        return InitResult { plant, outcome: InitOutcome::AreaUndiscovered };
    }
    if !is_area_plant_field {
        return InitResult { plant, outcome: InitOutcome::AreaNotPlantField };
    }
    if !is_plant_id_in_range {
        return InitResult { plant, outcome: InitOutcome::PlantIdOutOfRange };
    }
    if plant.max_yield > 0_u16 {
        return InitResult { plant, outcome: InitOutcome::AlreadyInitialized };
    }
    if max_yield == 0_u16 || regrowth_rate == 0_u16 {
        return InitResult { plant, outcome: InitOutcome::InvalidConfig };
    }

    plant.species = species;
    plant.current_yield = max_yield;
    plant.reserved_yield = 0_u16;
    plant.max_yield = max_yield;
    plant.regrowth_rate = regrowth_rate;
    plant.health = 100_u16;
    plant.stress_level = 0_u16;
    plant.genetics_hash = genetics_hash;
    plant.last_harvest_block = now_block;
    plant.discoverer = discoverer;

    InitResult { plant, outcome: InitOutcome::Applied }
}

pub fn start_transition(
    adventurer: Adventurer,
    economics: AdventurerEconomics,
    caller: ContractAddress,
    plant: PlantNode,
    mut reservation: HarvestReservation,
    amount: u16,
    now_block: u64,
    regen_per_100_blocks: u16,
    energy_per_unit: u16,
    time_per_unit: u16,
) -> StartResult {
    if !adventurer.is_alive {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::Dead,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::NotOwner,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if adventurer.current_hex != plant.hex_coordinate {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::WrongHex,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if reservation.status == HarvestReservationStatus::Active {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::AlreadyActive,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if adventurer.activity_locked_until > now_block {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::Locked,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if plant.max_yield == 0_u16 {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::NotInitialized,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    if amount == 0_u16 {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::InvalidAmount,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }

    let available = available_yield(plant);
    match available {
        Option::None => {
            return StartResult {
                adventurer,
                economics,
                plant,
                reservation,
                outcome: StartOutcome::InvalidPlantState,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
        Option::Some(found) => {
            if amount > found {
                return StartResult {
                    adventurer,
                    economics,
                    plant,
                    reservation,
                    outcome: StartOutcome::InsufficientYield,
                    eta: 0_u64,
                    energy_cost: 0_u16,
                };
            }
        },
    }

    let energy_cost_u128: u128 = amount.into() * energy_per_unit.into();
    if energy_cost_u128 > 65535_u128 {
        return StartResult {
            adventurer,
            economics,
            plant,
            reservation,
            outcome: StartOutcome::InvalidAmount,
            eta: 0_u64,
            energy_cost: 0_u16,
        };
    }
    let energy_cost: u16 = energy_cost_u128.try_into().unwrap();

    let consumed = consume_transition(
        adventurer, economics, caller, energy_cost, now_block, regen_per_100_blocks,
    );
    match consumed.outcome {
        ConsumeOutcome::Applied => {},
        ConsumeOutcome::InsufficientEnergy => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant,
                reservation,
                outcome: StartOutcome::InsufficientEnergy,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
        ConsumeOutcome::Dead => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant,
                reservation,
                outcome: StartOutcome::Dead,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
        ConsumeOutcome::NotOwner => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant,
                reservation,
                outcome: StartOutcome::NotOwner,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
    }

    let reserved = reserve_yield_once_with_status(plant, amount);
    match reserved.outcome {
        HarvestReserveOutcome::Applied => {},
        HarvestReserveOutcome::InsufficientYield => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant: reserved.plant,
                reservation,
                outcome: StartOutcome::InsufficientYield,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
        HarvestReserveOutcome::InvalidState => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant: reserved.plant,
                reservation,
                outcome: StartOutcome::InvalidPlantState,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
        HarvestReserveOutcome::InvalidAmount => {
            return StartResult {
                adventurer: consumed.adventurer,
                economics: consumed.economics,
                plant: reserved.plant,
                reservation,
                outcome: StartOutcome::InvalidAmount,
                eta: 0_u64,
                energy_cost: 0_u16,
            };
        },
    }

    let mut next_adventurer = consumed.adventurer;
    let eta = now_block + (amount.into() * time_per_unit.into());
    next_adventurer.activity_locked_until = eta;

    reservation.adventurer_id = next_adventurer.adventurer_id;
    reservation.plant_key = reserved.plant.plant_key;
    reservation.reserved_amount = amount;
    reservation.created_block = now_block;
    reservation.expiry_block = eta;
    reservation.status = HarvestReservationStatus::Active;

    StartResult {
        adventurer: next_adventurer,
        economics: consumed.economics,
        plant: reserved.plant,
        reservation,
        outcome: StartOutcome::Applied,
        eta,
        energy_cost,
    }
}

fn mint_harvest_item(
    mut inventory: Inventory,
    mut item: BackpackItem,
    quantity: u16,
    quality: u16,
) -> (Inventory, BackpackItem, u16) {
    if quantity == 0_u16 {
        return (inventory, item, 0_u16);
    }

    let capacity = if inventory.max_weight > inventory.current_weight {
        inventory.max_weight - inventory.current_weight
    } else {
        0_u32
    };
    let desired_u32: u32 = quantity.into();
    let minted_u32 = if desired_u32 > capacity { capacity } else { desired_u32 };

    if minted_u32 > 0_u32 {
        inventory.current_weight += minted_u32;
        item.quantity += minted_u32;
        item.quality = quality;
        item.weight_per_unit = 1_u16;
    }

    (inventory, item, minted_u32.try_into().unwrap())
}

fn apply_plant_harvest_effects(
    mut plant: PlantNode, consumed: u16, released_reserved: u16, now_block: u64,
) -> PlantNode {
    if consumed > 0_u16 {
        plant.current_yield -= consumed;
    }
    if released_reserved > 0_u16 {
        plant.reserved_yield -= released_reserved;
    }

    let stress_headroom = if plant.stress_level < 100_u16 { 100_u16 - plant.stress_level } else { 0_u16 };
    let stress_add = if consumed > stress_headroom { stress_headroom } else { consumed };
    plant.stress_level += stress_add;

    let health_drop = consumed / 2_u16;
    if health_drop >= plant.health {
        plant.health = 0_u16;
    } else {
        plant.health -= health_drop;
    }
    plant.last_harvest_block = now_block;
    plant
}

pub fn complete_transition(
    mut adventurer: Adventurer,
    caller: ContractAddress,
    plant: PlantNode,
    mut reservation: HarvestReservation,
    inventory: Inventory,
    item: BackpackItem,
    now_block: u64,
) -> CompleteResult {
    if !adventurer.is_alive {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::Dead,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::NotOwner,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if adventurer.current_hex != plant.hex_coordinate {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::WrongHex,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if reservation.status != HarvestReservationStatus::Active {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::NoActiveReservation,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if reservation.adventurer_id != adventurer.adventurer_id || reservation.plant_key != plant.plant_key {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::NotLinked,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if now_block < reservation.expiry_block {
        return CompleteResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CompleteOutcome::TooEarly,
            actual_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }

    let reserved_amount = reservation.reserved_amount;
    let consumed = if reserved_amount <= plant.current_yield { reserved_amount } else { plant.current_yield };
    let released_reserved = if reserved_amount <= plant.reserved_yield {
        reserved_amount
    } else {
        plant.reserved_yield
    };
    let next_plant = apply_plant_harvest_effects(plant, consumed, released_reserved, now_block);

    reservation.status = HarvestReservationStatus::Completed;
    reservation.reserved_amount = 0_u16;
    adventurer.activity_locked_until = 0_u64;

    let (next_inventory, next_item, minted) = mint_harvest_item(
        inventory, item, consumed, next_plant.health,
    );

    CompleteResult {
        adventurer,
        plant: next_plant,
        reservation,
        inventory: next_inventory,
        item: next_item,
        outcome: CompleteOutcome::Applied,
        actual_yield: consumed,
        minted_yield: minted,
    }
}

pub fn cancel_transition(
    mut adventurer: Adventurer,
    caller: ContractAddress,
    plant: PlantNode,
    mut reservation: HarvestReservation,
    inventory: Inventory,
    item: BackpackItem,
    now_block: u64,
) -> CancelResult {
    if !adventurer.is_alive {
        return CancelResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CancelOutcome::Dead,
            partial_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return CancelResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CancelOutcome::NotOwner,
            partial_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if adventurer.current_hex != plant.hex_coordinate {
        return CancelResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CancelOutcome::WrongHex,
            partial_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if reservation.status != HarvestReservationStatus::Active {
        return CancelResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CancelOutcome::NoActiveReservation,
            partial_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }
    if reservation.adventurer_id != adventurer.adventurer_id || reservation.plant_key != plant.plant_key {
        return CancelResult {
            adventurer,
            plant,
            reservation,
            inventory,
            item,
            outcome: CancelOutcome::NotLinked,
            partial_yield: 0_u16,
            minted_yield: 0_u16,
        };
    }

    let duration = if reservation.expiry_block > reservation.created_block {
        reservation.expiry_block - reservation.created_block
    } else {
        0_u64
    };
    let elapsed = if now_block > reservation.created_block {
        let raw_elapsed = now_block - reservation.created_block;
        if raw_elapsed > duration { duration } else { raw_elapsed }
    } else {
        0_u64
    };

    let partial_target = if duration == 0_u64 {
        reservation.reserved_amount
    } else {
        let partial_u128: u128 = (reservation.reserved_amount.into() * elapsed.into()) / duration.into();
        partial_u128.try_into().unwrap()
    };
    let consumed = if partial_target <= plant.current_yield { partial_target } else { plant.current_yield };
    let released_reserved = if reservation.reserved_amount <= plant.reserved_yield {
        reservation.reserved_amount
    } else {
        plant.reserved_yield
    };
    let next_plant = apply_plant_harvest_effects(plant, consumed, released_reserved, now_block);

    reservation.status = HarvestReservationStatus::Canceled;
    reservation.reserved_amount = 0_u16;
    adventurer.activity_locked_until = 0_u64;

    let (next_inventory, next_item, minted) = mint_harvest_item(
        inventory, item, consumed, next_plant.health,
    );

    CancelResult {
        adventurer,
        plant: next_plant,
        reservation,
        inventory: next_inventory,
        item: next_item,
        outcome: CancelOutcome::Applied,
        partial_yield: consumed,
        minted_yield: minted,
    }
}
