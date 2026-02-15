#!/usr/bin/env python3
"""Construction balance simulator for post-MVP 7-building loop.

Usage:
  python3 04-economy/tools/construction_balance_sim.py
  python3 04-economy/tools/construction_balance_sim.py --check
  python3 04-economy/tools/construction_balance_sim.py --format json --scenario growth
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from collections import defaultdict
from typing import Any

DEFAULT_CONFIG_PATH = pathlib.Path(__file__).with_name("construction_balance_config.v1.json")


def load_config(path: str | pathlib.Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def delta_from_bp(bp: float) -> float:
    return (bp - 10_000.0) / 10_000.0


def capex_energy_equivalent(building: dict[str, Any], resource_energy_values: dict[str, float]) -> float:
    total = 0.0
    for item_id, qty in building.get("recipe", {}).items():
        if item_id not in resource_energy_values:
            raise KeyError(f"Missing resource energy value for {item_id}")
        total += float(resource_energy_values[item_id]) * float(qty)
    total += float(building.get("energy_stake", 0.0))
    return total


def gross_benefit_per_100(
    building: dict[str, Any],
    scenario: dict[str, Any],
    effect_coefficients: dict[str, float],
) -> float:
    effect = building["effect"]
    kind = effect["kind"]

    if kind == "ore_conversion_multiplier":
        return float(scenario["ore_energy_base_per_100"]) * delta_from_bp(float(effect["bp"]))

    if kind == "plant_conversion_multiplier":
        return float(scenario["plant_energy_base_per_100"]) * delta_from_bp(float(effect["bp"]))

    if kind == "plant_regrowth_multiplier":
        realization = float(effect_coefficients.get("greenhouse_realization", 1.0))
        base = float(scenario["plant_energy_base_per_100"]) * realization
        return base * delta_from_bp(float(effect["bp"]))

    if kind == "mining_stress_reduction":
        capture = float(effect_coefficients.get("shoring_risk_capture", 1.0))
        base = float(scenario["collapse_risk_loss_energy_per_100"])
        return base * capture * delta_from_bp(float(effect["bp"]))

    if kind == "construction_efficiency":
        spend_gain = float(scenario["construction_spend_energy_per_100"]) * float(effect["discount_bp"]) / 10_000.0
        delay_gain = float(scenario["build_delay_value_energy_per_100"]) * float(effect["time_cut_bp"]) / 10_000.0
        return spend_gain + delay_gain

    if kind == "logistics_capacity":
        base = float(scenario["capacity_choke_energy_per_100"])
        return base * delta_from_bp(float(effect["bp"]))

    if kind == "defense_efficiency":
        capture = float(effect_coefficients.get("watchtower_loss_capture", 1.0))
        base = float(scenario["claim_loss_energy_per_100"])
        return base * capture * delta_from_bp(float(effect["bp"]))

    raise ValueError(f"Unsupported effect kind: {kind}")


def simulate(config: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    resource_values: dict[str, float] = config["resource_energy_values"]
    effect_coeffs: dict[str, float] = config.get("effect_coefficients", {})

    for scenario in config["scenarios"]:
        scenario_id = scenario["id"]
        for building in config["buildings"]:
            building_id = building["id"]
            capex = capex_energy_equivalent(building, resource_values)
            gross = gross_benefit_per_100(building, scenario, effect_coeffs)
            upkeep = float(building.get("upkeep_per_100_blocks", 0.0))
            net = gross - upkeep

            payback_blocks = None
            if net > 0:
                payback_blocks = float(building.get("build_time_blocks", 0.0)) + (capex / net) * 100.0

            rows.append(
                {
                    "scenario_id": scenario_id,
                    "building_id": building_id,
                    "capex_energy_equivalent": capex,
                    "gross_benefit_per_100": gross,
                    "upkeep_per_100": upkeep,
                    "net_benefit_per_100": net,
                    "payback_blocks": payback_blocks,
                }
            )

    return rows


def assess_thresholds(rows: list[dict[str, Any]], targets: dict[str, Any]) -> list[dict[str, Any]]:
    violations: list[dict[str, Any]] = []
    payback_min = targets.get("payback_min_blocks")
    payback_max = targets.get("payback_max_blocks")
    min_net = targets.get("min_net_benefit_per_100")

    for row in rows:
        reasons: list[str] = []
        if min_net is not None and row["net_benefit_per_100"] < float(min_net):
            reasons.append(
                f"net below target ({row['net_benefit_per_100']:.2f} < {float(min_net):.2f})"
            )

        payback = row["payback_blocks"]
        if payback is None:
            reasons.append("payback undefined (non-positive net)")
        else:
            if payback_min is not None and payback < float(payback_min):
                reasons.append(f"payback below floor ({payback:.2f} < {float(payback_min):.2f})")
            if payback_max is not None and payback > float(payback_max):
                reasons.append(f"payback above ceiling ({payback:.2f} > {float(payback_max):.2f})")

        if reasons:
            violations.append(
                {
                    "scenario_id": row["scenario_id"],
                    "building_id": row["building_id"],
                    "reason": "; ".join(reasons),
                    "row": row,
                }
            )

    return violations


def filter_rows(rows: list[dict[str, Any]], scenario_ids: set[str]) -> list[dict[str, Any]]:
    if not scenario_ids:
        return rows
    return [row for row in rows if row["scenario_id"] in scenario_ids]


def render_markdown(rows: list[dict[str, Any]], precision: int = 2) -> str:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[row["scenario_id"]].append(row)

    lines: list[str] = []
    for scenario_id in sorted(grouped):
        lines.append(f"## Scenario: {scenario_id}")
        lines.append(
            "| Building | Capex (E) | Gross/100 | Upkeep/100 | Net/100 | Payback (blocks) |"
        )
        lines.append("|---|---:|---:|---:|---:|---:|")

        for row in sorted(grouped[scenario_id], key=lambda item: item["building_id"]):
            payback = "n/a" if row["payback_blocks"] is None else f"{row['payback_blocks']:.{precision}f}"
            lines.append(
                "| {building} | {capex:.{p}f} | {gross:.{p}f} | {upkeep:.{p}f} | {net:.{p}f} | {payback} |".format(
                    building=row["building_id"],
                    capex=row["capex_energy_equivalent"],
                    gross=row["gross_benefit_per_100"],
                    upkeep=row["upkeep_per_100"],
                    net=row["net_benefit_per_100"],
                    payback=payback,
                    p=precision,
                )
            )
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run construction balance simulations")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="Path to JSON config")
    parser.add_argument("--scenario", action="append", default=[], help="Scenario id filter (repeatable)")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--round", type=int, default=2, dest="precision")
    parser.add_argument("--check", action="store_true", help="Exit non-zero if thresholds are violated")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    config = load_config(args.config)

    rows = simulate(config)
    rows = filter_rows(rows, set(args.scenario))

    if args.format == "json":
        print(json.dumps(rows, indent=2))
    else:
        print(render_markdown(rows, precision=args.precision))

    if args.check:
        violations = assess_thresholds(rows, config.get("default_targets", {}))
        if violations:
            print("Threshold violations:", file=sys.stderr)
            for violation in violations:
                print(
                    f"- {violation['scenario_id']}::{violation['building_id']}: {violation['reason']}",
                    file=sys.stderr,
                )
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
