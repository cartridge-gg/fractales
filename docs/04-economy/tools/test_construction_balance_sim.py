import pathlib
import sys
import unittest

TOOLS_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

import construction_balance_sim as sim  # noqa: E402


class ConstructionBalanceSimTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = {
            "resource_energy_values": {
                "ORE_IRON": 8,
                "ORE_COAL": 12,
                "ORE_COPPER": 9,
                "PLANT_FIBER": 7,
                "PLANT_RESIN": 11,
                "PLANT_COMPOUND": 13,
            },
            "default_targets": {
                "payback_min_blocks": 400,
                "payback_max_blocks": 1600,
                "min_net_benefit_per_100": 6.0,
            },
            "effect_coefficients": {
                "greenhouse_realization": 0.65,
                "shoring_risk_capture": 0.75,
            },
            "buildings": [
                {
                    "id": "SMELTER",
                    "recipe": {"ORE_IRON": 80, "ORE_COAL": 40, "ORE_COPPER": 20},
                    "energy_stake": 40,
                    "build_time_blocks": 120,
                    "upkeep_per_100_blocks": 9,
                    "effect": {"kind": "ore_conversion_multiplier", "bp": 11500},
                },
                {
                    "id": "GREENHOUSE",
                    "recipe": {"PLANT_FIBER": 120, "PLANT_COMPOUND": 40, "ORE_COPPER": 25},
                    "energy_stake": 35,
                    "build_time_blocks": 110,
                    "upkeep_per_100_blocks": 7,
                    "effect": {"kind": "plant_regrowth_multiplier", "bp": 11000},
                },
            ],
            "scenarios": [
                {
                    "id": "frontier",
                    "ore_energy_base_per_100": 300,
                    "plant_energy_base_per_100": 180,
                    "collapse_risk_loss_energy_per_100": 50,
                    "construction_spend_energy_per_100": 120,
                    "build_delay_value_energy_per_100": 40,
                    "capacity_choke_energy_per_100": 70,
                    "claim_loss_energy_per_100": 55,
                }
            ],
        }

    def test_capex_energy_equivalent_includes_recipe_and_stake(self) -> None:
        smelter = self.config["buildings"][0]
        capex = sim.capex_energy_equivalent(smelter, self.config["resource_energy_values"])
        expected_recipe = (80 * 8) + (40 * 12) + (20 * 9)
        self.assertEqual(capex, expected_recipe + 40)

    def test_simulate_returns_positive_smelter_net_in_frontier(self) -> None:
        rows = sim.simulate(self.config)
        smelter = [r for r in rows if r["building_id"] == "SMELTER" and r["scenario_id"] == "frontier"][0]
        self.assertGreater(smelter["net_benefit_per_100"], 0)
        self.assertIsNotNone(smelter["payback_blocks"])

    def test_assess_thresholds_flags_out_of_band_payback(self) -> None:
        rows = [
            {
                "building_id": "WATCHTOWER",
                "scenario_id": "frontier",
                "net_benefit_per_100": 5.0,
                "payback_blocks": 3000,
            }
        ]
        violations = sim.assess_thresholds(rows, self.config["default_targets"])
        self.assertEqual(len(violations), 1)
        self.assertIn("payback", violations[0]["reason"])


if __name__ == "__main__":
    unittest.main()
