#[cfg(test)]
mod tests {
    use dojo_starter::events::construction_events::{
        ConstructionCompleted, ConstructionPlantProcessed, ConstructionRejected, ConstructionRepaired,
        ConstructionStarted, ConstructionUpkeepPaid, ConstructionUpgradeQueued,
    };

    #[test]
    fn construction_events_started_payload_shape() {
        let event = ConstructionStarted {
            project_id: 501_felt252,
            adventurer_id: 1001_felt252,
            hex_coordinate: 7001_felt252,
            area_id: 7002_felt252,
            building_type: 'SMELTER'_felt252,
            target_tier: 1_u8,
            completion_block: 999_u64,
        };

        assert(event.project_id == 501_felt252, 'C_EVT_STRT_PID');
        assert(event.adventurer_id == 1001_felt252, 'C_EVT_STRT_ADV');
        assert(event.hex_coordinate == 7001_felt252, 'C_EVT_STRT_HEX');
        assert(event.area_id == 7002_felt252, 'C_EVT_STRT_AREA');
        assert(event.building_type == 'SMELTER'_felt252, 'C_EVT_STRT_BLD');
        assert(event.target_tier == 1_u8, 'C_EVT_STRT_TIER');
        assert(event.completion_block == 999_u64, 'C_EVT_STRT_DONE');
    }

    #[test]
    fn construction_events_completed_payload_shape() {
        let event = ConstructionCompleted {
            project_id: 502_felt252,
            adventurer_id: 1002_felt252,
            hex_coordinate: 7003_felt252,
            area_id: 7004_felt252,
            building_type: 'GREENHOUSE'_felt252,
            resulting_tier: 2_u8,
        };

        assert(event.project_id == 502_felt252, 'C_EVT_DONE_PID');
        assert(event.adventurer_id == 1002_felt252, 'C_EVT_DONE_ADV');
        assert(event.hex_coordinate == 7003_felt252, 'C_EVT_DONE_HEX');
        assert(event.area_id == 7004_felt252, 'C_EVT_DONE_AREA');
        assert(event.building_type == 'GREENHOUSE'_felt252, 'C_EVT_DONE_BLD');
        assert(event.resulting_tier == 2_u8, 'C_EVT_DONE_TIER');
    }

    #[test]
    fn construction_events_upkeep_payload_shape() {
        let event = ConstructionUpkeepPaid {
            area_id: 7101_felt252,
            adventurer_id: 1101_felt252,
            amount: 12_u16,
            upkeep_reserve: 44_u32,
        };

        assert(event.area_id == 7101_felt252, 'C_EVT_PAY_AREA');
        assert(event.adventurer_id == 1101_felt252, 'C_EVT_PAY_ADV');
        assert(event.amount == 12_u16, 'C_EVT_PAY_AMT');
        assert(event.upkeep_reserve == 44_u32, 'C_EVT_PAY_RSV');
    }

    #[test]
    fn construction_events_repaired_payload_shape() {
        let event = ConstructionRepaired {
            area_id: 7201_felt252,
            adventurer_id: 1201_felt252,
            amount: 8_u16,
            condition_bp: 3300_u16,
            is_active: true,
        };

        assert(event.area_id == 7201_felt252, 'C_EVT_REP_AREA');
        assert(event.adventurer_id == 1201_felt252, 'C_EVT_REP_ADV');
        assert(event.amount == 8_u16, 'C_EVT_REP_AMT');
        assert(event.condition_bp == 3300_u16, 'C_EVT_REP_BP');
        assert(event.is_active, 'C_EVT_REP_ACT');
    }

    #[test]
    fn construction_events_processed_payload_shape() {
        let event = ConstructionPlantProcessed {
            adventurer_id: 1301_felt252,
            source_item_id: 'HERB_RAW'_felt252,
            target_material: 'PLANT_FIBER'_felt252,
            input_qty: 15_u16,
            output_qty: 15_u16,
        };

        assert(event.adventurer_id == 1301_felt252, 'C_EVT_PRC_ADV');
        assert(event.source_item_id == 'HERB_RAW'_felt252, 'C_EVT_PRC_SRC');
        assert(event.target_material == 'PLANT_FIBER'_felt252, 'C_EVT_PRC_TGT');
        assert(event.input_qty == 15_u16, 'C_EVT_PRC_IN');
        assert(event.output_qty == 15_u16, 'C_EVT_PRC_OUT');
    }

    #[test]
    fn construction_events_upgrade_and_rejected_payload_shape() {
        let queued = ConstructionUpgradeQueued {
            area_id: 7301_felt252,
            project_id: 7302_felt252,
            adventurer_id: 1401_felt252,
            target_tier: 3_u8,
        };
        assert(queued.area_id == 7301_felt252, 'C_EVT_UP_AREA');
        assert(queued.project_id == 7302_felt252, 'C_EVT_UP_PID');
        assert(queued.adventurer_id == 1401_felt252, 'C_EVT_UP_ADV');
        assert(queued.target_tier == 3_u8, 'C_EVT_UP_TIER');

        let rejected = ConstructionRejected {
            adventurer_id: 1401_felt252,
            area_id: 7301_felt252,
            action: 'START'_felt252,
            reason: 'LOW_ENERGY'_felt252,
        };
        assert(rejected.adventurer_id == 1401_felt252, 'C_EVT_REJ_ADV');
        assert(rejected.area_id == 7301_felt252, 'C_EVT_REJ_AREA');
        assert(rejected.action == 'START'_felt252, 'C_EVT_REJ_ACT');
        assert(rejected.reason == 'LOW_ENERGY'_felt252, 'C_EVT_REJ_RSN');
    }
}
