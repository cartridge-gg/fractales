#[cfg(test)]
mod tests {
    use dojo_starter::libs::sharing_math::{
        BP_ONE, PERM_ALL, PERM_BUILD, PERM_EXTRACT, PERM_INSPECT, PERM_UPKEEP,
        POLICY_MUTATION_COOLDOWN_BLOCKS, POLICY_MUTATION_ENERGY_COST, SCOPE_AREA, SCOPE_GLOBAL,
        SCOPE_HEX, SCOPE_NONE, SHARE_RECIPIENT_LIMIT, alloc_from_bp_floor_u32, can_add_share,
        can_set_share_total, has_permissions, is_epoch_active, is_valid_permissions_mask,
        nearest_scope_level, residual_after_allocations,
    };

    #[test]
    fn sharing_math_permission_masks_validate_and_enforce_required_bits() {
        assert(is_valid_permissions_mask(PERM_INSPECT), 'SHMATH_MASK_1');
        assert(is_valid_permissions_mask(PERM_EXTRACT + PERM_UPKEEP), 'SHMATH_MASK_COMBO');
        assert(is_valid_permissions_mask(PERM_ALL), 'SHMATH_MASK_ALL');
        assert(!is_valid_permissions_mask(0_u16), 'SHMATH_MASK_ZERO');
        assert(!is_valid_permissions_mask(16_u16), 'SHMATH_MASK_HIGH');

        let actor_mask = PERM_INSPECT + PERM_EXTRACT + PERM_BUILD;
        assert(has_permissions(actor_mask, PERM_EXTRACT), 'SHMATH_REQ_OK');
        assert(has_permissions(actor_mask, PERM_INSPECT + PERM_BUILD), 'SHMATH_REQ_MULTI');
        assert(!has_permissions(actor_mask, PERM_UPKEEP), 'SHMATH_REQ_MISS');
    }

    #[test]
    fn sharing_math_split_floor_and_residual_are_conservative() {
        let gross = 11_u32;
        let split_a = alloc_from_bp_floor_u32(gross, 2_500_u16);
        let split_b = alloc_from_bp_floor_u32(gross, 3_333_u16);
        let distributed = split_a + split_b;
        let residual = residual_after_allocations(gross, distributed);

        assert(split_a == 2_u32, 'SHMATH_SPLIT_A');
        assert(split_b == 3_u32, 'SHMATH_SPLIT_B');
        assert(distributed + residual == gross, 'SHMATH_CONSERVE');
        assert(residual_after_allocations(gross, gross + 1_u32) == 0_u32, 'SHMATH_RES_FLOOR');
    }

    #[test]
    fn sharing_math_share_caps_and_limits_hold() {
        assert(can_set_share_total(BP_ONE), 'SHMATH_CAP_EQ');
        assert(!can_set_share_total(BP_ONE + 1_u16), 'SHMATH_CAP_GT');
        assert(can_add_share(7_500_u16, 2_500_u16), 'SHMATH_ADD_EQ');
        assert(!can_add_share(7_501_u16, 2_500_u16), 'SHMATH_ADD_GT');
        assert(SHARE_RECIPIENT_LIMIT == 8_u8, 'SHMATH_LIMIT8');
    }

    #[test]
    fn sharing_math_epoch_and_scope_precedence_match_locked_rules() {
        assert(is_epoch_active(7_u32, 7_u32), 'SHMATH_EPOCH_ON');
        assert(!is_epoch_active(6_u32, 7_u32), 'SHMATH_EPOCH_OFF');

        assert(nearest_scope_level(true, true, true) == SCOPE_AREA, 'SHMATH_SCOPE_A');
        assert(nearest_scope_level(false, true, true) == SCOPE_HEX, 'SHMATH_SCOPE_H');
        assert(nearest_scope_level(false, false, true) == SCOPE_GLOBAL, 'SHMATH_SCOPE_G');
        assert(nearest_scope_level(false, false, false) == SCOPE_NONE, 'SHMATH_SCOPE_N');
    }

    #[test]
    fn sharing_math_mutation_friction_constants_are_locked() {
        assert(POLICY_MUTATION_COOLDOWN_BLOCKS == 100_u64, 'SHMATH_COOLDOWN');
        assert(POLICY_MUTATION_ENERGY_COST == 5_u16, 'SHMATH_MUT_COST');
    }
}
