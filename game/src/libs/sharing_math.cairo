use core::traits::TryInto;

pub const BP_ONE: u16 = 10_000_u16;
pub const PERM_INSPECT: u16 = 1_u16;
pub const PERM_EXTRACT: u16 = 2_u16;
pub const PERM_BUILD: u16 = 4_u16;
pub const PERM_UPKEEP: u16 = 8_u16;
pub const PERM_ALL: u16 = 15_u16;

pub const SHARE_RECIPIENT_LIMIT: u8 = 8_u8;
pub const POLICY_MUTATION_COOLDOWN_BLOCKS: u64 = 100_u64;
pub const POLICY_MUTATION_ENERGY_COST: u16 = 5_u16;

pub const SCOPE_NONE: u8 = 0_u8;
pub const SCOPE_GLOBAL: u8 = 1_u8;
pub const SCOPE_HEX: u8 = 2_u8;
pub const SCOPE_AREA: u8 = 3_u8;

fn contains_permission_bit(mask: u16, bit: u16) -> bool {
    if bit == 0_u16 {
        return false;
    }

    let mask_u32: u32 = mask.into();
    let bit_u32: u32 = bit.into();
    ((mask_u32 / bit_u32) % 2_u32) == 1_u32
}

pub fn is_valid_permissions_mask(mask: u16) -> bool {
    mask > 0_u16 && mask <= PERM_ALL
}

pub fn has_permissions(mask: u16, required_mask: u16) -> bool {
    if !is_valid_permissions_mask(required_mask) {
        return false;
    }
    if !is_valid_permissions_mask(mask) {
        return false;
    }

    let inspect_ok = if contains_permission_bit(required_mask, PERM_INSPECT) {
        contains_permission_bit(mask, PERM_INSPECT)
    } else {
        true
    };
    let extract_ok = if contains_permission_bit(required_mask, PERM_EXTRACT) {
        contains_permission_bit(mask, PERM_EXTRACT)
    } else {
        true
    };
    let build_ok = if contains_permission_bit(required_mask, PERM_BUILD) {
        contains_permission_bit(mask, PERM_BUILD)
    } else {
        true
    };
    let upkeep_ok = if contains_permission_bit(required_mask, PERM_UPKEEP) {
        contains_permission_bit(mask, PERM_UPKEEP)
    } else {
        true
    };

    inspect_ok && extract_ok && build_ok && upkeep_ok
}

pub fn alloc_from_bp_floor_u32(gross: u32, bp: u16) -> u32 {
    if gross == 0_u32 || bp == 0_u16 {
        return 0_u32;
    }
    let scaled_u128: u128 = gross.into() * bp.into() / BP_ONE.into();
    if scaled_u128 > 4_294_967_295_u128 {
        4_294_967_295_u32
    } else {
        scaled_u128.try_into().unwrap()
    }
}

pub fn residual_after_allocations(gross: u32, distributed: u32) -> u32 {
    if distributed >= gross {
        0_u32
    } else {
        gross - distributed
    }
}

pub fn can_set_share_total(total_bp: u16) -> bool {
    total_bp <= BP_ONE
}

pub fn can_add_share(existing_total_bp: u16, new_share_bp: u16) -> bool {
    let next_total: u32 = existing_total_bp.into() + new_share_bp.into();
    next_total <= BP_ONE.into()
}

pub fn is_epoch_active(row_epoch: u32, policy_epoch: u32) -> bool {
    row_epoch == policy_epoch
}

pub fn nearest_scope_level(area_active: bool, hex_active: bool, global_active: bool) -> u8 {
    if area_active {
        SCOPE_AREA
    } else if hex_active {
        SCOPE_HEX
    } else if global_active {
        SCOPE_GLOBAL
    } else {
        SCOPE_NONE
    }
}
