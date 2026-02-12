#[cfg(test)]
mod tests {
    use dojo_starter::models::inventory::{
        BackpackItem, Inventory, add_weight, can_add_weight, clear_inventory, total_item_weight,
    };

    #[test]
    fn inventory_models_weight_capacity_guards() {
        let inventory = Inventory { adventurer_id: 77, current_weight: 40_u32, max_weight: 100_u32 };

        assert(can_add_weight(inventory, 60_u32), 'INV_CAN_ADD_EDGE');
        assert(!can_add_weight(inventory, 61_u32), 'INV_BLOCK_OVER');

        let exact_fit = add_weight(inventory, 60_u32);
        match exact_fit {
            Option::Some(updated) => assert(updated.current_weight == 100_u32, 'INV_ADD_EXACT'),
            Option::None => assert(1 == 0, 'INV_ADD_EXACT_NONE'),
        }

        let overflow = add_weight(inventory, 61_u32);
        assert(overflow.is_none(), 'INV_ADD_OVER_NONE');
    }

    #[test]
    fn inventory_models_backpack_item_weight_and_clear() {
        let item = BackpackItem {
            adventurer_id: 88,
            item_id: 'HERB'_felt252,
            quantity: 4_u32,
            quality: 55_u16,
            weight_per_unit: 7_u16,
        };

        assert(total_item_weight(item) == 28_u32, 'ITEM_WEIGHT_TOTAL');

        let inventory = Inventory { adventurer_id: 88, current_weight: 28_u32, max_weight: 200_u32 };
        let cleared = clear_inventory(inventory);
        assert(cleared.current_weight == 0_u32, 'INV_CLEAR_WEIGHT');
        assert(cleared.max_weight == 200_u32, 'INV_CLEAR_MAX');
    }
}
