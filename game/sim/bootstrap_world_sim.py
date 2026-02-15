#!/usr/bin/env python3
"""Bootstrap world economy scenario simulator.

This simulator is intentionally `code_exact`-first: it models current on-chain
energy semantics with simplified aggregate dynamics and exposes counterfactual
scenario controls for policy testing.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path
from statistics import mean
from typing import Iterable, List


class ModelMode(str, Enum):
    CODE_EXACT = "code_exact"
    DESIGN_INTENDED = "design_intended"


@dataclass(frozen=True)
class SimConfig:
    mode: ModelMode = ModelMode.CODE_EXACT
    blocks_per_epoch: int = 100
    epochs_per_week: int = 84
    initial_price_usdc_per_energy: float = 0.08
    initial_energy_supply: int = 12_000_000
    initial_active_adventurers: int = 10_000
    initial_controlled_hexes: int = 2_500
    initial_surplus_pool_energy: int = 250_000

    base_adventurer_price_usd: float = 6.0
    target_mints_per_epoch: int = 120

    demand_slope_bp: int = 30
    liquidity_slope_bp: int = 200
    min_demand_bp: int = 7_000
    max_demand_bp: int = 18_000
    min_liquidity_bp: int = 8_000
    max_liquidity_bp: int = 14_000

    max_discount_bp: int = 4_000
    surplus_discount_divisor: int = 8_000

    mint_sink_share_bp: int = 6_000
    mint_treasury_share_bp: int = 2_000
    mint_bond_share_bp: int = 2_000

    extraction_energy_per_adv_epoch: int = 11
    upkeep_energy_per_hex_epoch: int = 17
    roster_upkeep_per_adv_epoch: float = 0.33

    default_conversion_tax_bp: int = 3_000
    base_collapse_prob_bp: int = 20
    base_miner_share_bp: int = 2_200

    dca_price_pressure_divisor: int = 320
    supply_pressure_divisor: int = 25

    active_owner_count: int = 2_000

    target_final_inflation_pct: float = 10.0
    inflation_upper_band_bp: int = 900
    inflation_lower_band_bp: int = 700
    anti_inflation_gain_bp: int = 8_000
    anti_deflation_release_gain_bp: int = 2_000


@dataclass(frozen=True)
class Scenario:
    key: str
    label: str
    weeks: int
    demand_shock_bp: int
    supply_shock_bp: int
    conversion_tax_override_bp: int
    collapse_shock_prob_bp: int
    raider_share_bp: int
    dca_sell_pressure_bp: int
    initial_surplus_pool: int
    initial_price_usdc_per_energy: float
    initial_energy_supply: int
    initial_active_adventurers: int
    initial_controlled_hexes: int
    notes: str


@dataclass
class ScenarioSummary:
    key: str
    label: str
    mode: str
    epochs: int
    final_active_adventurers: int
    final_controlled_hexes: int
    final_energy_supply: int
    final_surplus_pool: int
    final_twap_usdc_per_energy: float
    total_new_hexes: int
    total_minted_adventurers: int
    total_deaths: int
    locked_capital_energy: int
    total_energy_sources: int
    total_energy_sinks: int
    sink_source_ratio: float
    net_inflation_pct: float


@dataclass
class ScenarioResult:
    scenario: Scenario
    summary: ScenarioSummary
    timeseries: List[dict]
    invariant_violations: List[str]


@dataclass
class _State:
    epoch: int
    block_number: int
    active_adventurers: int
    controlled_hexes: int
    energy_supply: int
    surplus_pool_energy: int
    treasury_energy: int
    locked_capital_energy: int
    twap_usdc_per_energy: float
    total_mints: int
    total_deaths: int
    total_new_hexes: int
    total_sources: int
    total_sinks: int


class ScenarioRunner:
    def __init__(self, config: SimConfig | None = None) -> None:
        self.config = config or SimConfig()

    def quote_adventurer_price_energy(
        self,
        *,
        mints_in_window: int,
        energy_surplus_band: int,
        owner_alive_count: int,
        surplus_pool_energy: int,
        twap_usdc_per_energy: float,
    ) -> int:
        cfg = self.config

        demand_bp = 10_000 + cfg.demand_slope_bp * (
            mints_in_window - cfg.target_mints_per_epoch
        )
        demand_bp = _clamp(demand_bp, cfg.min_demand_bp, cfg.max_demand_bp)

        liquidity_bp = 10_000 + cfg.liquidity_slope_bp * energy_surplus_band
        liquidity_bp = _clamp(liquidity_bp, cfg.min_liquidity_bp, cfg.max_liquidity_bp)

        owner_bp = _owner_scale_bp(owner_alive_count)
        twap = max(twap_usdc_per_energy, 1e-6)

        raw_energy = (cfg.base_adventurer_price_usd / twap) * demand_bp * liquidity_bp * owner_bp / 1e12

        max_discount = raw_energy * cfg.max_discount_bp / 10_000
        pool_discount = surplus_pool_energy / cfg.surplus_discount_divisor
        discount = min(max_discount, pool_discount)

        price = int(max(1.0, round(raw_energy - discount)))
        return price

    def run_scenario(self, scenario: Scenario) -> ScenarioResult:
        cfg = self.config
        epochs = max(1, scenario.weeks * cfg.epochs_per_week)

        state = _State(
            epoch=0,
            block_number=0,
            active_adventurers=max(1, scenario.initial_active_adventurers),
            controlled_hexes=max(1, scenario.initial_controlled_hexes),
            energy_supply=max(1, scenario.initial_energy_supply),
            surplus_pool_energy=max(0, scenario.initial_surplus_pool),
            treasury_energy=0,
            locked_capital_energy=0,
            twap_usdc_per_energy=max(0.0001, scenario.initial_price_usdc_per_energy),
            total_mints=0,
            total_deaths=0,
            total_new_hexes=0,
            total_sources=0,
            total_sinks=0,
        )

        baseline_energy = max(1, scenario.initial_energy_supply)
        timeseries: List[dict] = []
        violations: List[str] = []

        for epoch in range(1, epochs + 1):
            state.epoch = epoch
            state.block_number = epoch * cfg.blocks_per_epoch

            surplus_band = _energy_surplus_band(state.energy_supply, baseline_energy)
            adjusted_surplus_band = _clamp(
                surplus_band + int(round(scenario.supply_shock_bp / 2_000)), -8, 8
            )

            owner_alive_count = max(1, int(round(state.active_adventurers / cfg.active_owner_count)))
            demand_intent = int(
                round(
                    cfg.target_mints_per_epoch
                    * (1 + scenario.demand_shock_bp / 10_000)
                    * (1 + 0.25 * adjusted_surplus_band / 10)
                )
            )
            demand_intent = max(5, demand_intent)

            mint_price = self.quote_adventurer_price_energy(
                mints_in_window=demand_intent,
                energy_surplus_band=adjusted_surplus_band,
                owner_alive_count=owner_alive_count,
                surplus_pool_energy=state.surplus_pool_energy,
                twap_usdc_per_energy=state.twap_usdc_per_energy,
            )

            expansion_budget = int(
                state.energy_supply
                * (0.0007 + 0.0002 * max(0, adjusted_surplus_band))
            )
            affordable_mints = expansion_budget // max(1, mint_price)
            minted = max(0, min(demand_intent, affordable_mints))
            mint_spend = minted * mint_price

            sink_burn = mint_spend * cfg.mint_sink_share_bp // 10_000
            treasury_take = mint_spend * cfg.mint_treasury_share_bp // 10_000

            # Extraction output scales with headcount and discovery pressure.
            exploration_multiplier = 1.0 + min(0.4, minted / max(1, cfg.target_mints_per_epoch) * 0.25)
            extraction_source = int(
                round(
                    state.active_adventurers
                    * cfg.extraction_energy_per_adv_epoch
                    * exploration_multiplier
                )
            )

            conversion_tax_bp = (
                scenario.conversion_tax_override_bp
                if scenario.conversion_tax_override_bp > 0
                else _clamp(
                    cfg.default_conversion_tax_bp + max(0, adjusted_surplus_band) * 450,
                    200,
                    7_000,
                )
            )
            conversion_tax = extraction_source * conversion_tax_bp // 10_000
            player_extraction = extraction_source - conversion_tax

            # Upkeep pressure increases with footprint and roster scale.
            upkeep_sink = state.controlled_hexes * cfg.upkeep_energy_per_hex_epoch
            roster_sink = int(round(state.active_adventurers * cfg.roster_upkeep_per_adv_epoch))
            operational_sink = upkeep_sink + roster_sink
            stabilization_sink = int(
                round(state.energy_supply * max(0, adjusted_surplus_band) * 0.0027)
            )

            miner_share_bp = _clamp(
                cfg.base_miner_share_bp + scenario.raider_share_bp // 2,
                1_000,
                5_500,
            )
            collapse_prob_bp = _clamp(
                cfg.base_collapse_prob_bp
                + scenario.collapse_shock_prob_bp
                + max(0, adjusted_surplus_band) * 2,
                0,
                600,
            )
            deaths = (
                state.active_adventurers * miner_share_bp // 10_000 * collapse_prob_bp // 10_000
            )
            deaths = max(0, min(state.active_adventurers, deaths))

            bond_unit = max(1, mint_price * cfg.mint_bond_share_bp // 10_000)
            locked_from_deaths = deaths * bond_unit

            # Claim/decay churn: if energy is starved, lose more territory.
            decay_losses = max(0, int(round(state.controlled_hexes * max(0, -adjusted_surplus_band) * 0.0025)))
            new_hexes = int(
                round(
                    state.active_adventurers
                    * 0.008
                    * (1 + max(0, adjusted_surplus_band) * 0.03)
                )
            )
            controlled_delta = max(0, new_hexes // 7 - decay_losses)

            # Apply energy accounting.
            state.energy_supply += player_extraction
            state.energy_supply -= operational_sink
            state.energy_supply -= stabilization_sink
            state.energy_supply -= mint_spend
            state.energy_supply = max(0, state.energy_supply)

            state.surplus_pool_energy += conversion_tax
            state.surplus_pool_energy = max(0, state.surplus_pool_energy - int(mint_spend * 0.25))

            if adjusted_surplus_band < 0 and state.surplus_pool_energy > 0:
                rebound = min(
                    state.surplus_pool_energy,
                    int(round(abs(adjusted_surplus_band) * 1_200)),
                )
                state.energy_supply += rebound
                state.surplus_pool_energy -= rebound

            # Closed-loop policy control around a target inflation path.
            progress = epoch / max(1, epochs)
            target_supply = int(
                round(
                    baseline_energy
                    * (1 + (cfg.target_final_inflation_pct / 100.0) * progress)
                )
            )
            upper_bound = target_supply + (target_supply * cfg.inflation_upper_band_bp // 10_000)
            lower_bound = target_supply - (target_supply * cfg.inflation_lower_band_bp // 10_000)

            policy_stabilization_sink = 0
            policy_release = 0

            if state.energy_supply > upper_bound:
                overflow = state.energy_supply - upper_bound
                policy_stabilization_sink = overflow * cfg.anti_inflation_gain_bp // 10_000
                state.energy_supply -= policy_stabilization_sink

            if state.energy_supply < lower_bound and state.surplus_pool_energy > 0:
                deficit = lower_bound - state.energy_supply
                candidate_release = deficit * cfg.anti_deflation_release_gain_bp // 10_000
                policy_release = min(state.surplus_pool_energy, candidate_release)
                state.energy_supply += policy_release
                state.surplus_pool_energy -= policy_release

            state.treasury_energy += treasury_take
            state.locked_capital_energy += locked_from_deaths

            state.active_adventurers = max(0, state.active_adventurers + minted - deaths)
            state.controlled_hexes = max(0, state.controlled_hexes + controlled_delta)

            state.total_mints += minted
            state.total_deaths += deaths
            state.total_new_hexes += new_hexes
            state.total_sources += extraction_source
            state.total_sinks += (
                operational_sink
                + stabilization_sink
                + sink_burn
                + locked_from_deaths
                + policy_stabilization_sink
            )

            # TWAP evolution: sell pressure and oversupply push price down.
            mean_reversion_bp = int(
                round(
                    (
                        state.twap_usdc_per_energy
                        - scenario.initial_price_usdc_per_energy
                    )
                    / max(0.0001, scenario.initial_price_usdc_per_energy)
                    * 180
                )
            )
            price_shift_bp = (
                int(round(scenario.dca_sell_pressure_bp / cfg.dca_price_pressure_divisor))
                + int(round(adjusted_surplus_band * cfg.supply_pressure_divisor))
                - int(round(scenario.demand_shock_bp / 320))
                + mean_reversion_bp
            )
            price_shift_bp = _clamp(price_shift_bp, -350, 350)
            state.twap_usdc_per_energy *= max(0.90, 1 - price_shift_bp / 10_000)
            state.twap_usdc_per_energy = max(0.001, min(2.5, state.twap_usdc_per_energy))

            if state.energy_supply < 0:
                violations.append(f"epoch={epoch}: negative energy supply")
            if state.active_adventurers < 0:
                violations.append(f"epoch={epoch}: negative adventurer count")

            timeseries.append(
                {
                    "scenario": scenario.key,
                    "epoch": epoch,
                    "block_number": state.block_number,
                    "active_adventurers": state.active_adventurers,
                    "controlled_hexes": state.controlled_hexes,
                    "energy_supply": state.energy_supply,
                    "surplus_pool_energy": state.surplus_pool_energy,
                    "twap_usdc_per_energy": round(state.twap_usdc_per_energy, 6),
                    "mint_price_energy": mint_price,
                    "minted_adventurers": minted,
                    "deaths": deaths,
                    "new_hexes": new_hexes,
                    "extraction_source": extraction_source,
                    "operational_sink": operational_sink,
                    "stabilization_sink": stabilization_sink,
                    "policy_stabilization_sink": policy_stabilization_sink,
                    "policy_release": policy_release,
                    "sink_burn": sink_burn,
                    "locked_from_deaths": locked_from_deaths,
                    "conversion_tax_bp": conversion_tax_bp,
                }
            )

        sink_source_ratio = state.total_sinks / max(1, state.total_sources)
        net_inflation_pct = (
            (state.energy_supply - scenario.initial_energy_supply)
            / max(1, scenario.initial_energy_supply)
            * 100.0
        )

        summary = ScenarioSummary(
            key=scenario.key,
            label=scenario.label,
            mode=cfg.mode.value,
            epochs=epochs,
            final_active_adventurers=state.active_adventurers,
            final_controlled_hexes=state.controlled_hexes,
            final_energy_supply=state.energy_supply,
            final_surplus_pool=state.surplus_pool_energy,
            final_twap_usdc_per_energy=round(state.twap_usdc_per_energy, 6),
            total_new_hexes=state.total_new_hexes,
            total_minted_adventurers=state.total_mints,
            total_deaths=state.total_deaths,
            locked_capital_energy=state.locked_capital_energy,
            total_energy_sources=state.total_sources,
            total_energy_sinks=state.total_sinks,
            sink_source_ratio=round(sink_source_ratio, 6),
            net_inflation_pct=round(net_inflation_pct, 4),
        )

        return ScenarioResult(
            scenario=scenario,
            summary=summary,
            timeseries=timeseries,
            invariant_violations=violations,
        )

    def run_matrix(self, scenarios: Iterable[Scenario], out_dir: Path) -> List[ScenarioResult]:
        out_dir.mkdir(parents=True, exist_ok=True)
        results = [self.run_scenario(s) for s in scenarios]
        if not results:
            return []

        self._write_timeseries(out_dir / "timeseries.csv", results)
        self._write_comparison(out_dir / "scenario_comparison.csv", results)

        run_summary = {
            "mode": self.config.mode.value,
            "scenario_count": len(results),
            "avg_sink_source_ratio": round(mean(r.summary.sink_source_ratio for r in results), 6),
            "avg_net_inflation_pct": round(mean(r.summary.net_inflation_pct for r in results), 4),
            "best_exploration": max(results, key=lambda r: r.summary.total_new_hexes).summary.key,
            "worst_inflation": max(results, key=lambda r: r.summary.net_inflation_pct).summary.key,
            "scenarios": [asdict(r.summary) for r in results],
        }
        (out_dir / "run_summary.json").write_text(
            json.dumps(run_summary, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        invariant_report = {
            "mode": self.config.mode.value,
            "all_passed": all(len(r.invariant_violations) == 0 for r in results),
            "by_scenario": {
                r.scenario.key: {
                    "passed": len(r.invariant_violations) == 0,
                    "violation_count": len(r.invariant_violations),
                    "violations": r.invariant_violations,
                }
                for r in results
            },
        }
        (out_dir / "invariant_report.json").write_text(
            json.dumps(invariant_report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        return results

    @staticmethod
    def _write_timeseries(path: Path, results: List[ScenarioResult]) -> None:
        rows: List[dict] = []
        for result in results:
            rows.extend(result.timeseries)

        fieldnames = list(rows[0].keys())
        with path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    @staticmethod
    def _write_comparison(path: Path, results: List[ScenarioResult]) -> None:
        rows = [asdict(r.summary) for r in results]
        fieldnames = list(rows[0].keys())
        with path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)


def build_default_scenarios() -> List[Scenario]:
    cfg = SimConfig()
    base = {
        "weeks": 8,
        "initial_surplus_pool": cfg.initial_surplus_pool_energy,
        "initial_price_usdc_per_energy": cfg.initial_price_usdc_per_energy,
        "initial_energy_supply": cfg.initial_energy_supply,
        "initial_active_adventurers": cfg.initial_active_adventurers,
        "initial_controlled_hexes": cfg.initial_controlled_hexes,
    }

    return [
        Scenario(
            key="baseline_10k",
            label="Baseline 10k",
            demand_shock_bp=0,
            supply_shock_bp=0,
            conversion_tax_override_bp=0,
            collapse_shock_prob_bp=0,
            raider_share_bp=0,
            dca_sell_pressure_bp=450,
            notes="Reference run using default policy.",
            **base,
        ),
        Scenario(
            key="low_demand_surplus",
            label="Low Demand + Surplus",
            demand_shock_bp=-2_200,
            supply_shock_bp=1_400,
            conversion_tax_override_bp=500,
            collapse_shock_prob_bp=-5,
            raider_share_bp=-400,
            dca_sell_pressure_bp=550,
            notes="Stagnation pressure with high inventory overhang.",
            **base,
        ),
        Scenario(
            key="high_demand_tight_energy",
            label="High Demand + Tight Energy",
            demand_shock_bp=2_400,
            supply_shock_bp=-1_300,
            conversion_tax_override_bp=0,
            collapse_shock_prob_bp=40,
            raider_share_bp=600,
            dca_sell_pressure_bp=300,
            notes="Expansion race with tight liquidity.",
            **base,
        ),
        Scenario(
            key="high_demand_high_surplus",
            label="High Demand + High Surplus",
            demand_shock_bp=2_600,
            supply_shock_bp=1_600,
            conversion_tax_override_bp=900,
            collapse_shock_prob_bp=25,
            raider_share_bp=700,
            dca_sell_pressure_bp=500,
            notes="Mint rush risk phase.",
            **base,
        ),
        Scenario(
            key="deflationary_choke",
            label="Low Demand + Low Surplus",
            demand_shock_bp=-2_300,
            supply_shock_bp=-1_500,
            conversion_tax_override_bp=200,
            collapse_shock_prob_bp=0,
            raider_share_bp=-500,
            dca_sell_pressure_bp=250,
            notes="Contraction and retention risk.",
            **base,
        ),
        Scenario(
            key="whale_pressure",
            label="Whale Pressure",
            demand_shock_bp=1_500,
            supply_shock_bp=500,
            conversion_tax_override_bp=1_100,
            collapse_shock_prob_bp=10,
            raider_share_bp=1_200,
            dca_sell_pressure_bp=650,
            notes="Concentration and aggressive expansion.",
            **base,
        ),
        Scenario(
            key="cartel_mining",
            label="Cartel Mining",
            demand_shock_bp=900,
            supply_shock_bp=900,
            conversion_tax_override_bp=1_000,
            collapse_shock_prob_bp=80,
            raider_share_bp=1_400,
            dca_sell_pressure_bp=540,
            notes="Coordinated mining stress and collapse risk.",
            **base,
        ),
        Scenario(
            key="collapse_wave",
            label="Collapse Wave",
            demand_shock_bp=1_100,
            supply_shock_bp=200,
            conversion_tax_override_bp=950,
            collapse_shock_prob_bp=220,
            raider_share_bp=1_600,
            dca_sell_pressure_bp=680,
            notes="Systemic mine-collapse shock for capital-lock stress.",
            **base,
        ),
        Scenario(
            key="post_dca_dump",
            label="Post-DCA Dump",
            demand_shock_bp=-300,
            supply_shock_bp=1_100,
            conversion_tax_override_bp=1_200,
            collapse_shock_prob_bp=30,
            raider_share_bp=300,
            dca_sell_pressure_bp=1_300,
            notes="Secondary sell pressure after bootstrap sale.",
            **base,
        ),
        Scenario(
            key="anti_inflation_hard_mode",
            label="Anti-Inflation Hard Mode",
            demand_shock_bp=700,
            supply_shock_bp=1_700,
            conversion_tax_override_bp=1_700,
            collapse_shock_prob_bp=45,
            raider_share_bp=500,
            dca_sell_pressure_bp=600,
            notes="Policy-heavy sink regime.",
            **base,
        ),
        Scenario(
            key="growth_friendly_soft_mode",
            label="Growth-Friendly Soft Mode",
            demand_shock_bp=1_400,
            supply_shock_bp=-200,
            conversion_tax_override_bp=350,
            collapse_shock_prob_bp=5,
            raider_share_bp=200,
            dca_sell_pressure_bp=380,
            notes="Looser sink settings for world expansion.",
            **base,
        ),
        Scenario(
            key="regen_low_stress",
            label="Regen Low Stress",
            demand_shock_bp=-500,
            supply_shock_bp=-400,
            conversion_tax_override_bp=450,
            collapse_shock_prob_bp=-10,
            raider_share_bp=-300,
            dca_sell_pressure_bp=280,
            notes="Lower throughput, lower volatility lane.",
            **base,
        ),
    ]


def _owner_scale_bp(owner_alive_count: int) -> int:
    if owner_alive_count <= 2:
        return 10_000
    if owner_alive_count <= 5:
        return 10_500
    if owner_alive_count <= 10:
        return 11_000
    if owner_alive_count <= 20:
        return 11_500
    return 12_000


def _energy_surplus_band(current_supply: int, baseline_supply: int) -> int:
    ratio = (current_supply - baseline_supply) / max(1, baseline_supply)
    return _clamp(int(round(ratio * 10)), -8, 8)


def _clamp(value: int, min_value: int, max_value: int) -> int:
    return max(min_value, min(max_value, value))


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run bootstrap world scenario matrix simulation.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("game/sim/out/bootstrap-world"),
        help="Directory to write simulation artifacts.",
    )
    parser.add_argument(
        "--mode",
        choices=[m.value for m in ModelMode],
        default=ModelMode.CODE_EXACT.value,
        help="Simulation mode. Keep code_exact as baseline truth.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    config = SimConfig(mode=ModelMode(args.mode))
    runner = ScenarioRunner(config)
    results = runner.run_matrix(build_default_scenarios(), args.out_dir)

    print(f"mode={config.mode.value}")
    print(f"scenarios={len(results)}")
    print(f"out_dir={args.out_dir}")


if __name__ == "__main__":
    main()
