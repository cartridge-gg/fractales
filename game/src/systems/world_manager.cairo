use dojo_starter::libs::adjacency::is_adjacent;
use dojo_starter::libs::coord_codec::CubeCoord;
use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by, spend_energy};
use dojo_starter::models::world::{
    AreaType, Biome, DiscoveryWriteStatus, Hex, HexArea, SizeCategory, discover_area_once_with_status,
    discover_hex_once_with_status, is_valid_area_identity, is_valid_area_index,
};
use starknet::ContractAddress;

const ENERGY_PER_HEX_MOVE: u16 = 15_u16;
const ENERGY_PER_EXPLORE: u16 = 25_u16;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum HexDiscoverOutcome {
    #[default]
    Replay,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AreaDiscoverOutcome {
    #[default]
    InvalidAreaIndex,
    InvalidAreaIdentity,
    Replay,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum MoveOutcome {
    #[default]
    NotAdjacent,
    Applied,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ActorSpendGuardOutcome {
    #[default]
    Dead,
    NotOwner,
    InsufficientEnergy,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct DiscoverHexResult {
    pub hex: Hex,
    pub outcome: HexDiscoverOutcome,
    pub energy_spent: u16,
    pub emit_event: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct DiscoverAreaResult {
    pub area: HexArea,
    pub outcome: AreaDiscoverOutcome,
    pub emit_event: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct MoveResult {
    pub from: CubeCoord,
    pub to: CubeCoord,
    pub outcome: MoveOutcome,
    pub energy_spent: u16,
    pub emit_event: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct ActorSpendGuardResult {
    pub adventurer: Adventurer,
    pub outcome: ActorSpendGuardOutcome,
}

pub fn discover_hex_transition(
    hex: Hex,
    discoverer: ContractAddress,
    discovery_block: u64,
    biome: Biome,
    area_count: u8,
    energy_per_explore: u16,
) -> DiscoverHexResult {
    let discovered = discover_hex_once_with_status(
        hex, discoverer, discovery_block, biome, area_count,
    );

    match discovered.status {
        DiscoveryWriteStatus::Applied => DiscoverHexResult {
            hex: discovered.value,
            outcome: HexDiscoverOutcome::Applied,
            energy_spent: energy_per_explore,
            emit_event: true,
        },
        DiscoveryWriteStatus::Replay => DiscoverHexResult {
            hex: discovered.value,
            outcome: HexDiscoverOutcome::Replay,
            energy_spent: 0_u16,
            emit_event: false,
        },
    }
}

pub fn discover_area_transition(
    area: HexArea,
    discoverer: ContractAddress,
    area_type: AreaType,
    resource_quality: u16,
    size_category: SizeCategory,
    plant_slot_count: u8,
    area_count: u8,
) -> DiscoverAreaResult {
    if !is_valid_area_index(area.area_index, area_count) {
        return DiscoverAreaResult {
            area,
            outcome: AreaDiscoverOutcome::InvalidAreaIndex,
            emit_event: false,
        };
    }
    if !is_valid_area_identity(area) {
        return DiscoverAreaResult {
            area,
            outcome: AreaDiscoverOutcome::InvalidAreaIdentity,
            emit_event: false,
        };
    }

    let discovered = discover_area_once_with_status(
        area, discoverer, area_type, resource_quality, size_category, plant_slot_count,
    );

    match discovered.status {
        DiscoveryWriteStatus::Applied => DiscoverAreaResult {
            area: discovered.value,
            outcome: AreaDiscoverOutcome::Applied,
            emit_event: true,
        },
        DiscoveryWriteStatus::Replay => DiscoverAreaResult {
            area: discovered.value,
            outcome: AreaDiscoverOutcome::Replay,
            emit_event: false,
        },
    }
}

pub fn move_transition(from: CubeCoord, to: CubeCoord, energy_per_hex_move: u16) -> MoveResult {
    if !is_adjacent(from, to) {
        return MoveResult {
            from,
            to,
            outcome: MoveOutcome::NotAdjacent,
            energy_spent: 0_u16,
            emit_event: false,
        };
    }

    MoveResult {
        from,
        to,
        outcome: MoveOutcome::Applied,
        energy_spent: energy_per_hex_move,
        emit_event: true,
    }
}

pub fn move_cost_if_adjacent(
    from: CubeCoord, to: CubeCoord, energy_per_hex_move: u16,
) -> Option<u16> {
    let transition = move_transition(from, to, energy_per_hex_move);
    if transition.outcome == MoveOutcome::Applied {
        return Option::Some(transition.energy_spent);
    }
    Option::None
}

pub fn guard_owner_alive_and_spend(
    adventurer: Adventurer, caller: ContractAddress, energy_cost: u16,
) -> ActorSpendGuardResult {
    if !adventurer.is_alive {
        return ActorSpendGuardResult { adventurer, outcome: ActorSpendGuardOutcome::Dead };
    }
    if !can_be_controlled_by(adventurer, caller) {
        return ActorSpendGuardResult { adventurer, outcome: ActorSpendGuardOutcome::NotOwner };
    }

    match spend_energy(adventurer, energy_cost) {
        Option::Some(updated) => {
            ActorSpendGuardResult { adventurer: updated, outcome: ActorSpendGuardOutcome::Applied }
        },
        Option::None => {
            ActorSpendGuardResult {
                adventurer,
                outcome: ActorSpendGuardOutcome::InsufficientEnergy,
            }
        },
    }
}
