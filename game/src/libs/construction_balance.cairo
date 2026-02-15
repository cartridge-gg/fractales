pub const B_SMELTER: felt252 = 'SMELTER'_felt252;
pub const B_SHORING_RIG: felt252 = 'SHORING_RIG'_felt252;
pub const B_GREENHOUSE: felt252 = 'GREENHOUSE'_felt252;
pub const B_HERBAL_PRESS: felt252 = 'HERBAL_PRESS'_felt252;
pub const B_WORKSHOP: felt252 = 'WORKSHOP'_felt252;
pub const B_STOREHOUSE: felt252 = 'STOREHOUSE'_felt252;
pub const B_WATCHTOWER: felt252 = 'WATCHTOWER'_felt252;

pub const I_ORE_IRON: felt252 = 'ORE_IRON'_felt252;
pub const I_ORE_COAL: felt252 = 'ORE_COAL'_felt252;
pub const I_ORE_COPPER: felt252 = 'ORE_COPPER'_felt252;
pub const I_ORE_TIN: felt252 = 'ORE_TIN'_felt252;
pub const I_ORE_NICKEL: felt252 = 'ORE_NICKEL'_felt252;
pub const I_ORE_COBALT: felt252 = 'ORE_COBALT'_felt252;
pub const I_PLANT_FIBER: felt252 = 'PLANT_FIBER'_felt252;
pub const I_PLANT_RESIN: felt252 = 'PLANT_RESIN'_felt252;
pub const I_PLANT_COMPOUND: felt252 = 'PLANT_COMPOUND'_felt252;

pub fn resource_energy_value(item_id: felt252) -> u16 {
    if item_id == I_ORE_IRON {
        8_u16
    } else if item_id == I_ORE_COAL {
        12_u16
    } else if item_id == I_ORE_COPPER {
        9_u16
    } else if item_id == I_ORE_TIN {
        10_u16
    } else if item_id == I_ORE_NICKEL {
        18_u16
    } else if item_id == I_ORE_COBALT {
        22_u16
    } else if item_id == I_PLANT_FIBER {
        7_u16
    } else if item_id == I_PLANT_RESIN {
        11_u16
    } else if item_id == I_PLANT_COMPOUND {
        13_u16
    } else {
        0_u16
    }
}

pub fn recipe_qty(building_id: felt252, item_id: felt252) -> u16 {
    if building_id == B_SMELTER {
        if item_id == I_ORE_IRON {
            80_u16
        } else if item_id == I_ORE_COAL {
            40_u16
        } else if item_id == I_ORE_COPPER {
            20_u16
        } else {
            0_u16
        }
    } else if building_id == B_SHORING_RIG {
        if item_id == I_ORE_IRON {
            60_u16
        } else if item_id == I_ORE_TIN {
            35_u16
        } else if item_id == I_ORE_COBALT {
            18_u16
        } else if item_id == I_PLANT_RESIN {
            28_u16
        } else if item_id == I_ORE_COAL {
            15_u16
        } else {
            0_u16
        }
    } else if building_id == B_GREENHOUSE {
        if item_id == I_PLANT_FIBER {
            80_u16
        } else if item_id == I_PLANT_COMPOUND {
            30_u16
        } else if item_id == I_ORE_COPPER {
            20_u16
        } else {
            0_u16
        }
    } else if building_id == B_HERBAL_PRESS {
        if item_id == I_PLANT_COMPOUND {
            70_u16
        } else if item_id == I_PLANT_RESIN {
            35_u16
        } else if item_id == I_ORE_TIN {
            15_u16
        } else {
            0_u16
        }
    } else if building_id == B_WORKSHOP {
        if item_id == I_ORE_IRON {
            45_u16
        } else if item_id == I_ORE_NICKEL {
            15_u16
        } else if item_id == I_PLANT_FIBER {
            45_u16
        } else {
            0_u16
        }
    } else if building_id == B_STOREHOUSE {
        if item_id == I_ORE_IRON {
            45_u16
        } else if item_id == I_ORE_COAL {
            40_u16
        } else if item_id == I_PLANT_FIBER {
            90_u16
        } else if item_id == I_ORE_COPPER {
            20_u16
        } else {
            0_u16
        }
    } else if building_id == B_WATCHTOWER {
        if item_id == I_ORE_IRON {
            55_u16
        } else if item_id == I_ORE_COBALT {
            20_u16
        } else if item_id == I_PLANT_RESIN {
            30_u16
        } else if item_id == I_ORE_NICKEL {
            10_u16
        } else {
            0_u16
        }
    } else {
        0_u16
    }
}

pub fn energy_stake_for_building(building_id: felt252) -> u16 {
    if building_id == B_SMELTER {
        40_u16
    } else if building_id == B_SHORING_RIG {
        45_u16
    } else if building_id == B_GREENHOUSE {
        35_u16
    } else if building_id == B_HERBAL_PRESS {
        35_u16
    } else if building_id == B_WORKSHOP {
        40_u16
    } else if building_id == B_STOREHOUSE {
        30_u16
    } else if building_id == B_WATCHTOWER {
        45_u16
    } else {
        0_u16
    }
}

pub fn build_time_blocks_for_building(building_id: felt252) -> u64 {
    if building_id == B_SMELTER {
        120_u64
    } else if building_id == B_SHORING_RIG {
        130_u64
    } else if building_id == B_GREENHOUSE {
        110_u64
    } else if building_id == B_HERBAL_PRESS {
        105_u64
    } else if building_id == B_WORKSHOP {
        115_u64
    } else if building_id == B_STOREHOUSE {
        100_u64
    } else if building_id == B_WATCHTOWER {
        140_u64
    } else {
        0_u64
    }
}

pub fn upkeep_per_100_blocks(building_id: felt252) -> u16 {
    if building_id == B_SMELTER {
        9_u16
    } else if building_id == B_SHORING_RIG {
        11_u16
    } else if building_id == B_GREENHOUSE {
        7_u16
    } else if building_id == B_HERBAL_PRESS {
        8_u16
    } else if building_id == B_WORKSHOP {
        10_u16
    } else if building_id == B_STOREHOUSE {
        6_u16
    } else if building_id == B_WATCHTOWER {
        12_u16
    } else {
        0_u16
    }
}

pub fn effect_bp_for_building(building_id: felt252) -> u16 {
    if building_id == B_SMELTER {
        11_250_u16
    } else if building_id == B_SHORING_RIG {
        14_000_u16
    } else if building_id == B_GREENHOUSE {
        12_000_u16
    } else if building_id == B_HERBAL_PRESS {
        11_500_u16
    } else if building_id == B_STOREHOUSE {
        15_500_u16
    } else if building_id == B_WATCHTOWER {
        12_500_u16
    } else {
        0_u16
    }
}

pub fn timed_params_for_building(building_id: felt252) -> (u16, u16) {
    if building_id == B_WORKSHOP {
        (1_200_u16, 1_800_u16)
    } else {
        (0_u16, 0_u16)
    }
}

fn multiply_qty_energy(qty: u16, energy_per_unit: u16) -> u32 {
    let q: u32 = qty.into();
    let e: u32 = energy_per_unit.into();
    q * e
}

pub fn capex_energy_equivalent(building_id: felt252) -> u32 {
    let mut total = 0_u32;

    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_IRON), resource_energy_value(I_ORE_IRON));
    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_COAL), resource_energy_value(I_ORE_COAL));
    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_COPPER), resource_energy_value(I_ORE_COPPER));
    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_TIN), resource_energy_value(I_ORE_TIN));
    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_NICKEL), resource_energy_value(I_ORE_NICKEL));
    total += multiply_qty_energy(recipe_qty(building_id, I_ORE_COBALT), resource_energy_value(I_ORE_COBALT));
    total += multiply_qty_energy(recipe_qty(building_id, I_PLANT_FIBER), resource_energy_value(I_PLANT_FIBER));
    total += multiply_qty_energy(recipe_qty(building_id, I_PLANT_RESIN), resource_energy_value(I_PLANT_RESIN));
    total += multiply_qty_energy(
        recipe_qty(building_id, I_PLANT_COMPOUND), resource_energy_value(I_PLANT_COMPOUND),
    );

    total + energy_stake_for_building(building_id).into()
}
