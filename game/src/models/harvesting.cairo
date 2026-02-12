use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct PlantNode {
    #[key]
    pub plant_key: felt252,
    pub hex_coordinate: felt252,
    pub area_id: felt252,
    pub plant_id: u8,
    pub species: felt252,
    pub current_yield: u16,
    pub reserved_yield: u16,
    pub max_yield: u16,
    pub regrowth_rate: u16,
    pub health: u16,
    pub stress_level: u16,
    pub genetics_hash: felt252,
    pub last_harvest_block: u64,
    pub discoverer: ContractAddress,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum HarvestReserveOutcome {
    #[default]
    InsufficientYield,
    InvalidAmount,
    InvalidState,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct PlantReserveResult {
    pub plant: PlantNode,
    pub outcome: HarvestReserveOutcome,
    pub reserved_amount: u16,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum HarvestReservationStatus {
    #[default]
    Inactive,
    Active,
    Completed,
    Canceled,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct HarvestReservation {
    #[key]
    pub reservation_id: felt252,
    pub adventurer_id: felt252,
    pub plant_key: felt252,
    pub reserved_amount: u16,
    pub created_block: u64,
    pub expiry_block: u64,
    pub status: HarvestReservationStatus,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum HarvestDeathSettleOutcome {
    #[default]
    Replay,
    NotActive,
    NotLinked,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct HarvestDeathSettleResult {
    pub plant: PlantNode,
    pub reservation: HarvestReservation,
    pub outcome: HarvestDeathSettleOutcome,
    pub released_amount: u16,
}

pub fn derive_plant_key(hex_coordinate: felt252, area_id: felt252, plant_id: u8) -> felt252 {
    let plant_felt: felt252 = plant_id.into();
    let (stage_one, _, _) = core::poseidon::hades_permutation(hex_coordinate, area_id, plant_felt);
    let (key, _, _) = core::poseidon::hades_permutation(stage_one, 'PLANT_KEY_V1'_felt252, 0_felt252);
    key
}

pub fn derive_harvest_reservation_id(adventurer_id: felt252, plant_key: felt252) -> felt252 {
    let (id, _, _) = core::poseidon::hades_permutation(
        adventurer_id, plant_key, 'HRESV_ID_V1'_felt252,
    );
    id
}

pub fn derive_harvest_item_id(plant_key: felt252) -> felt252 {
    let (id, _, _) = core::poseidon::hades_permutation(
        plant_key, 'HITEM_ID_V1'_felt252, 0_felt252,
    );
    id
}

pub fn available_yield(plant: PlantNode) -> Option<u16> {
    if plant.current_yield > plant.max_yield {
        return Option::None;
    }
    if plant.reserved_yield > plant.current_yield {
        return Option::None;
    }

    Option::Some(plant.current_yield - plant.reserved_yield)
}

pub fn reserve_yield_once_with_status(mut plant: PlantNode, amount: u16) -> PlantReserveResult {
    if amount == 0_u16 {
        return PlantReserveResult {
            plant, outcome: HarvestReserveOutcome::InvalidAmount, reserved_amount: 0_u16,
        };
    }

    let available = available_yield(plant);
    match available {
        Option::Some(found) => {
            if amount > found {
                return PlantReserveResult {
                    plant, outcome: HarvestReserveOutcome::InsufficientYield, reserved_amount: 0_u16,
                };
            }

            plant.reserved_yield += amount;
            PlantReserveResult {
                plant, outcome: HarvestReserveOutcome::Applied, reserved_amount: amount,
            }
        },
        Option::None => PlantReserveResult {
            plant, outcome: HarvestReserveOutcome::InvalidState, reserved_amount: 0_u16,
        },
    }
}

pub fn settle_harvest_reservation_on_death(
    mut plant: PlantNode, mut reservation: HarvestReservation, adventurer_id: felt252,
) -> HarvestDeathSettleResult {
    if reservation.status == HarvestReservationStatus::Canceled {
        return HarvestDeathSettleResult {
            plant,
            reservation,
            outcome: HarvestDeathSettleOutcome::Replay,
            released_amount: 0_u16,
        };
    }

    if reservation.status != HarvestReservationStatus::Active {
        return HarvestDeathSettleResult {
            plant,
            reservation,
            outcome: HarvestDeathSettleOutcome::NotActive,
            released_amount: 0_u16,
        };
    }

    if reservation.adventurer_id != adventurer_id || reservation.plant_key != plant.plant_key {
        return HarvestDeathSettleResult {
            plant,
            reservation,
            outcome: HarvestDeathSettleOutcome::NotLinked,
            released_amount: 0_u16,
        };
    }

    let released = if reservation.reserved_amount <= plant.reserved_yield {
        reservation.reserved_amount
    } else {
        plant.reserved_yield
    };
    plant.reserved_yield -= released;
    reservation.reserved_amount = 0_u16;
    reservation.status = HarvestReservationStatus::Canceled;

    HarvestDeathSettleResult {
        plant,
        reservation,
        outcome: HarvestDeathSettleOutcome::Applied,
        released_amount: released,
    }
}
