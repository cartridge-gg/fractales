import tempfile
import unittest
from pathlib import Path

from game.sim.bootstrap_world_sim import (
    ModelMode,
    Scenario,
    ScenarioRunner,
    build_default_scenarios,
)


class BootstrapWorldSimTests(unittest.TestCase):
    def test_default_mode_is_code_exact(self) -> None:
        runner = ScenarioRunner()
        self.assertEqual(runner.config.mode, ModelMode.CODE_EXACT)

    def test_high_surplus_lowers_mint_price(self) -> None:
        runner = ScenarioRunner()
        scenario = Scenario(
            key="surplus_discount_check",
            label="Surplus Discount Check",
            weeks=1,
            demand_shock_bp=0,
            supply_shock_bp=0,
            conversion_tax_override_bp=0,
            collapse_shock_prob_bp=0,
            raider_share_bp=0,
            dca_sell_pressure_bp=0,
            initial_surplus_pool=200_000,
            initial_price_usdc_per_energy=runner.config.initial_price_usdc_per_energy,
            initial_energy_supply=runner.config.initial_energy_supply,
            initial_active_adventurers=runner.config.initial_active_adventurers,
            initial_controlled_hexes=runner.config.initial_controlled_hexes,
            notes="test",
        )
        base_price = runner.quote_adventurer_price_energy(
            mints_in_window=runner.config.target_mints_per_epoch,
            energy_surplus_band=0,
            owner_alive_count=5,
            surplus_pool_energy=0,
            twap_usdc_per_energy=runner.config.initial_price_usdc_per_energy,
        )
        discounted_price = runner.quote_adventurer_price_energy(
            mints_in_window=runner.config.target_mints_per_epoch,
            energy_surplus_band=0,
            owner_alive_count=5,
            surplus_pool_energy=scenario.initial_surplus_pool,
            twap_usdc_per_energy=runner.config.initial_price_usdc_per_energy,
        )
        self.assertLess(discounted_price, base_price)

    def test_high_demand_raises_mint_price(self) -> None:
        runner = ScenarioRunner()
        low = runner.quote_adventurer_price_energy(
            mints_in_window=runner.config.target_mints_per_epoch - 50,
            energy_surplus_band=0,
            owner_alive_count=3,
            surplus_pool_energy=0,
            twap_usdc_per_energy=runner.config.initial_price_usdc_per_energy,
        )
        high = runner.quote_adventurer_price_energy(
            mints_in_window=runner.config.target_mints_per_epoch + 80,
            energy_surplus_band=0,
            owner_alive_count=3,
            surplus_pool_energy=0,
            twap_usdc_per_energy=runner.config.initial_price_usdc_per_energy,
        )
        self.assertGreater(high, low)

    def test_collapse_scenario_locks_more_capital_than_baseline(self) -> None:
        runner = ScenarioRunner()
        scenarios = build_default_scenarios()
        by_key = {s.key: s for s in scenarios}
        baseline = runner.run_scenario(by_key["baseline_10k"])
        collapse = runner.run_scenario(by_key["collapse_wave"])
        self.assertGreater(collapse.summary.locked_capital_energy, baseline.summary.locked_capital_energy)

    def test_matrix_run_writes_required_artifacts(self) -> None:
        runner = ScenarioRunner()
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp)
            matrix = runner.run_matrix(build_default_scenarios(), out_dir)
            self.assertGreaterEqual(len(matrix), 8)
            self.assertTrue((out_dir / "scenario_comparison.csv").exists())
            self.assertTrue((out_dir / "run_summary.json").exists())
            self.assertTrue((out_dir / "timeseries.csv").exists())
            self.assertTrue((out_dir / "invariant_report.json").exists())

    def test_baseline_inflation_tuned_near_ten_percent(self) -> None:
        runner = ScenarioRunner()
        scenarios = build_default_scenarios()
        baseline = next(s for s in scenarios if s.key == "baseline_10k")
        result = runner.run_scenario(baseline)
        self.assertGreaterEqual(result.summary.net_inflation_pct, 9.0)
        self.assertLessEqual(result.summary.net_inflation_pct, 11.0)

    def test_matrix_inflation_band_is_bounded(self) -> None:
        runner = ScenarioRunner()
        summaries = [runner.run_scenario(s).summary for s in build_default_scenarios()]
        for summary in summaries:
            self.assertGreaterEqual(summary.net_inflation_pct, -5.0)
            self.assertLessEqual(summary.net_inflation_pct, 25.0)


if __name__ == "__main__":
    unittest.main()
