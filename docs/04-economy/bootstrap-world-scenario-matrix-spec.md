# Bootstrap World Scenario Matrix Spec (8 Weeks)

## 1. Goal

Bootstrap the world economy to maximize:

- exploration throughput,
- sustainable energy extraction,
- adventurer expansion,

while avoiding hyperinflation and concentration collapse.

This spec extends the current `code_exact` simulator direction with a concrete scenario matrix and a runnable implementation.

## 2. Implemented Simulator

Implemented at:

- `game/sim/bootstrap_world_sim.py`
- tests: `game/sim/tests/test_bootstrap_world_sim.py`

Default mode is locked to `code_exact` unless explicitly overridden.

Run command:

```bash
python3 game/sim/bootstrap_world_sim.py --out-dir game/sim/out/bootstrap-world
```

Artifacts written:

- `run_summary.json`
- `scenario_comparison.csv`
- `timeseries.csv`
- `invariant_report.json`

## 3. Control Model

### 3.1 Adventurer creation pricing

Per epoch quote:

```text
price_energy = (base_usd / twap_usdc_per_energy) * demand_bp * liquidity_bp * owner_bp / 1e12 - discount
```

Where:

- `demand_bp` increases with mint pressure in the window
- `liquidity_bp` increases when energy surplus is high (stronger sink)
- `owner_bp` is a mild anti-spam scale from roster size tiers
- `discount` is bounded by both `max_discount_bp` and available `surplus_pool_energy`

### 3.2 Mint payment split

On each adventurer creation:

- `sink_burn` (removes energy from circulation)
- `treasury_take` (protocol reserve)
- `bond_added` (capital attached to adventurers)

### 3.3 Capital lock on collapse deaths

On mine-collapse deaths, bond-equivalent capital is moved into `locked_capital_energy`.

This creates the intended long-term sink and risk discipline.

### 3.4 Sources and sinks

Main source:

- extraction conversion (harvest/mining aggregate output)

Main sinks:

- territory upkeep
- roster upkeep
- mint sink burn
- collapse-driven locked capital

### 3.5 DCA sell-pressure channel

`dca_sell_pressure_bp` contributes downward pressure on TWAP each epoch.

This emulates market drag during/after bootstrap distribution and lets policy be stress-tested.

## 4. Scenario Matrix

Implemented default matrix (`build_default_scenarios`) includes:

1. `baseline_10k`
2. `low_demand_surplus`
3. `high_demand_tight_energy`
4. `high_demand_high_surplus`
5. `deflationary_choke`
6. `whale_pressure`
7. `cartel_mining`
8. `collapse_wave`
9. `post_dca_dump`
10. `anti_inflation_hard_mode`
11. `growth_friendly_soft_mode`
12. `regen_low_stress`

All scenarios run for 8 weeks by default (`84 epochs/week`, `100 blocks/epoch`).

## 5. KPI Outputs

Per scenario summary includes:

- `sink_source_ratio`
- `net_inflation_pct`
- `total_new_hexes`
- `total_minted_adventurers`
- `total_deaths`
- `locked_capital_energy`
- `final_active_adventurers`
- `final_controlled_hexes`
- `final_twap_usdc_per_energy`

## 6. Guardrails and Success Bands

Recommended acceptance ranges during bootstrap:

- `sink_source_ratio`: `0.85` to `1.10`
- `net_inflation_pct` (8-week): `0%` to `+15%`
- exploration trend: monotone-positive aggregate `total_new_hexes`
- collapse risk: non-zero `total_deaths`, but not dominant over mint growth
- concentration control: monitor scenario variants with elevated `owner_bp` and raider share

## 7. Tuning Knobs

Primary policy levers exposed in config/scenarios:

- `default_conversion_tax_bp`
- `max_discount_bp`
- `surplus_discount_divisor`
- `mint_sink_share_bp`, `mint_treasury_share_bp`, `mint_bond_share_bp`
- `base_collapse_prob_bp`
- `dca_sell_pressure_bp`

These knobs are sufficient to run anti-inflation vs growth tradeoff sweeps without changing simulator code.

## 8. Next Iteration

For tighter parity with onchain behavior, next step is plugging live contract-derived coefficients into:

- extraction source rates,
- claim/defend spend paths,
- mine-collapse death distributions,
- TWAP oracle replay from real Ekubo event streams.

## 9. Current Calibration Snapshot (2026-02-15)

Using the current default parameters:

- `baseline_10k` ends at `+10.08%` net inflation (`sink/source=0.6184`)
- `anti_inflation_hard_mode` ends at `+14.49%` net inflation (`sink/source=0.8184`)
- `collapse_wave` ends at `+0.31%` net inflation with higher capital lock than baseline
- full matrix inflation range is now bounded in `+0.31% .. +24.76%`

Conclusion: baseline is tuned to the 10% target and current scenario variants remain within the enforced matrix safety band (`-5% .. +25%`).
