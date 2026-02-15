#[cfg(test)]
mod tests {
    use dojo_starter::libs::construction_balance::{
        B_GREENHOUSE, B_HERBAL_PRESS, B_SHORING_RIG, B_SMELTER, B_STOREHOUSE, B_WATCHTOWER,
        B_WORKSHOP, I_ORE_COAL, I_ORE_COBALT, I_ORE_COPPER, I_ORE_IRON, I_ORE_NICKEL, I_ORE_TIN,
        I_PLANT_COMPOUND, I_PLANT_FIBER, I_PLANT_RESIN, capex_energy_equivalent,
        effect_bp_for_building, recipe_qty, resource_energy_value, timed_params_for_building,
        upkeep_per_100_blocks,
    };

    #[test]
    fn construction_balance_resource_energy_values_match_tuned_table() {
        assert(resource_energy_value(I_ORE_IRON) == 8_u16, 'CB_RES_IRON');
        assert(resource_energy_value(I_ORE_COAL) == 12_u16, 'CB_RES_COAL');
        assert(resource_energy_value(I_ORE_COPPER) == 9_u16, 'CB_RES_COPR');
        assert(resource_energy_value(I_ORE_TIN) == 10_u16, 'CB_RES_TIN');
        assert(resource_energy_value(I_ORE_NICKEL) == 18_u16, 'CB_RES_NICK');
        assert(resource_energy_value(I_ORE_COBALT) == 22_u16, 'CB_RES_COBL');
        assert(resource_energy_value(I_PLANT_FIBER) == 7_u16, 'CB_RES_FIBR');
        assert(resource_energy_value(I_PLANT_RESIN) == 11_u16, 'CB_RES_RESI');
        assert(resource_energy_value(I_PLANT_COMPOUND) == 13_u16, 'CB_RES_COMP');
    }

    #[test]
    fn construction_balance_recipe_quantities_match_tuned_table() {
        assert(recipe_qty(B_SMELTER, I_ORE_IRON) == 80_u16, 'CB_R_SM_I');
        assert(recipe_qty(B_SMELTER, I_ORE_COAL) == 40_u16, 'CB_R_SM_C');
        assert(recipe_qty(B_SMELTER, I_ORE_COPPER) == 20_u16, 'CB_R_SM_P');

        assert(recipe_qty(B_SHORING_RIG, I_ORE_IRON) == 60_u16, 'CB_R_SR_I');
        assert(recipe_qty(B_SHORING_RIG, I_ORE_TIN) == 35_u16, 'CB_R_SR_T');
        assert(recipe_qty(B_SHORING_RIG, I_ORE_COBALT) == 18_u16, 'CB_R_SR_B');
        assert(recipe_qty(B_SHORING_RIG, I_PLANT_RESIN) == 28_u16, 'CB_R_SR_R');
        assert(recipe_qty(B_SHORING_RIG, I_ORE_COAL) == 15_u16, 'CB_R_SR_C');

        assert(recipe_qty(B_GREENHOUSE, I_PLANT_FIBER) == 80_u16, 'CB_R_GH_F');
        assert(recipe_qty(B_GREENHOUSE, I_PLANT_COMPOUND) == 30_u16, 'CB_R_GH_M');
        assert(recipe_qty(B_GREENHOUSE, I_ORE_COPPER) == 20_u16, 'CB_R_GH_P');

        assert(recipe_qty(B_HERBAL_PRESS, I_PLANT_COMPOUND) == 70_u16, 'CB_R_HP_M');
        assert(recipe_qty(B_HERBAL_PRESS, I_PLANT_RESIN) == 35_u16, 'CB_R_HP_R');
        assert(recipe_qty(B_HERBAL_PRESS, I_ORE_TIN) == 15_u16, 'CB_R_HP_T');

        assert(recipe_qty(B_WORKSHOP, I_ORE_IRON) == 45_u16, 'CB_R_WS_I');
        assert(recipe_qty(B_WORKSHOP, I_ORE_NICKEL) == 15_u16, 'CB_R_WS_N');
        assert(recipe_qty(B_WORKSHOP, I_PLANT_FIBER) == 45_u16, 'CB_R_WS_F');

        assert(recipe_qty(B_STOREHOUSE, I_ORE_IRON) == 45_u16, 'CB_R_SH_I');
        assert(recipe_qty(B_STOREHOUSE, I_ORE_COAL) == 40_u16, 'CB_R_SH_C');
        assert(recipe_qty(B_STOREHOUSE, I_PLANT_FIBER) == 90_u16, 'CB_R_SH_F');
        assert(recipe_qty(B_STOREHOUSE, I_ORE_COPPER) == 20_u16, 'CB_R_SH_P');

        assert(recipe_qty(B_WATCHTOWER, I_ORE_IRON) == 55_u16, 'CB_R_WT_I');
        assert(recipe_qty(B_WATCHTOWER, I_ORE_COBALT) == 20_u16, 'CB_R_WT_B');
        assert(recipe_qty(B_WATCHTOWER, I_PLANT_RESIN) == 30_u16, 'CB_R_WT_R');
        assert(recipe_qty(B_WATCHTOWER, I_ORE_NICKEL) == 10_u16, 'CB_R_WT_N');
    }

    #[test]
    fn construction_balance_capex_matches_tuned_sim_values() {
        assert(capex_energy_equivalent(B_SMELTER) == 1340_u32, 'CB_CAP_SM');
        assert(capex_energy_equivalent(B_SHORING_RIG) == 1759_u32, 'CB_CAP_SR');
        assert(capex_energy_equivalent(B_GREENHOUSE) == 1165_u32, 'CB_CAP_GH');
        assert(capex_energy_equivalent(B_HERBAL_PRESS) == 1480_u32, 'CB_CAP_HP');
        assert(capex_energy_equivalent(B_WORKSHOP) == 985_u32, 'CB_CAP_WS');
        assert(capex_energy_equivalent(B_STOREHOUSE) == 1680_u32, 'CB_CAP_SH');
        assert(capex_energy_equivalent(B_WATCHTOWER) == 1435_u32, 'CB_CAP_WT');
    }

    #[test]
    fn construction_balance_effect_and_timing_params_match_tuned_table() {
        assert(effect_bp_for_building(B_SMELTER) == 11_250_u16, 'CB_BP_SM');
        assert(effect_bp_for_building(B_SHORING_RIG) == 14_000_u16, 'CB_BP_SR');
        assert(effect_bp_for_building(B_GREENHOUSE) == 12_000_u16, 'CB_BP_GH');
        assert(effect_bp_for_building(B_HERBAL_PRESS) == 11_500_u16, 'CB_BP_HP');
        assert(effect_bp_for_building(B_STOREHOUSE) == 15_500_u16, 'CB_BP_SH');
        assert(effect_bp_for_building(B_WATCHTOWER) == 12_500_u16, 'CB_BP_WT');

        let (ws_discount, ws_time_cut) = timed_params_for_building(B_WORKSHOP);
        assert(ws_discount == 1_200_u16, 'CB_WS_DISC');
        assert(ws_time_cut == 1_800_u16, 'CB_WS_TIME');

        assert(upkeep_per_100_blocks(B_SMELTER) == 9_u16, 'CB_UP_SM');
        assert(upkeep_per_100_blocks(B_SHORING_RIG) == 11_u16, 'CB_UP_SR');
        assert(upkeep_per_100_blocks(B_GREENHOUSE) == 7_u16, 'CB_UP_GH');
        assert(upkeep_per_100_blocks(B_HERBAL_PRESS) == 8_u16, 'CB_UP_HP');
        assert(upkeep_per_100_blocks(B_WORKSHOP) == 10_u16, 'CB_UP_WS');
        assert(upkeep_per_100_blocks(B_STOREHOUSE) == 6_u16, 'CB_UP_SH');
        assert(upkeep_per_100_blocks(B_WATCHTOWER) == 12_u16, 'CB_UP_WT');
    }
}
