#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Inventory {
    #[key]
    pub adventurer_id: felt252,
    pub current_weight: u32,
    pub max_weight: u32,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct BackpackItem {
    #[key]
    pub adventurer_id: felt252,
    #[key]
    pub item_id: felt252,
    pub quantity: u32,
    pub quality: u16,
    pub weight_per_unit: u16,
}

pub fn total_item_weight(item: BackpackItem) -> u32 {
    let quantity_u64: u64 = item.quantity.into();
    let weight_u64: u64 = item.weight_per_unit.into();
    (quantity_u64 * weight_u64).try_into().unwrap()
}

pub fn can_add_weight(inventory: Inventory, additional_weight: u32) -> bool {
    let current_u64: u64 = inventory.current_weight.into();
    let additional_u64: u64 = additional_weight.into();
    let max_u64: u64 = inventory.max_weight.into();
    current_u64 + additional_u64 <= max_u64
}

pub fn add_weight(mut inventory: Inventory, additional_weight: u32) -> Option<Inventory> {
    if !can_add_weight(inventory, additional_weight) {
        return Option::None;
    }

    inventory.current_weight += additional_weight;
    Option::Some(inventory)
}

pub fn clear_inventory(mut inventory: Inventory) -> Inventory {
    inventory.current_weight = 0_u32;
    inventory
}
