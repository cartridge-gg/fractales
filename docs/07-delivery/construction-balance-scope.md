# Construction Balance Scope (v1)

## Objective

Lock a practical first-pass balance envelope for the 7-building construction module and provide a deterministic simulator workflow for rapid tuning.

This scope does not finalize onchain constants. It defines:

- the balance table schema to maintain
- initial values to start from
- acceptance bands for payback and net benefit
- how to run and tune the simulator

## Canonical Simulator Artifacts

- Config: `04-economy/tools/construction_balance_config.v1.json`
- Simulator: `04-economy/tools/construction_balance_sim.py`
- Tests: `04-economy/tools/test_construction_balance_sim.py`

## Balance Table Schema

Each building row must define:

- `id`
- `recipe` (item id -> quantity)
- `energy_stake`
- `build_time_blocks`
- `upkeep_per_100_blocks`
- `effect` (deterministic formula parameters)

Each scenario row must define:

- `id`
- `ore_energy_base_per_100`
- `plant_energy_base_per_100`
- `collapse_risk_loss_energy_per_100`
- `construction_spend_energy_per_100`
- `build_delay_value_energy_per_100`
- `capacity_choke_energy_per_100`
- `claim_loss_energy_per_100`

## Initial v1 Building Inputs

| Building | Recipe (T1) | Stake | Build Time | Upkeep/100 |
|---|---|---:|---:|---:|
| `SMELTER` | `ORE_IRON:80`, `ORE_COAL:40`, `ORE_COPPER:20` | 40 | 120 | 9 |
| `SHORING_RIG` | `ORE_IRON:60`, `ORE_TIN:35`, `ORE_COBALT:18`, `PLANT_RESIN:28`, `ORE_COAL:15` | 45 | 130 | 11 |
| `GREENHOUSE` | `PLANT_FIBER:80`, `PLANT_COMPOUND:30`, `ORE_COPPER:20` | 35 | 110 | 7 |
| `HERBAL_PRESS` | `PLANT_COMPOUND:70`, `PLANT_RESIN:35`, `ORE_TIN:15` | 35 | 105 | 8 |
| `WORKSHOP` | `ORE_IRON:45`, `ORE_NICKEL:15`, `PLANT_FIBER:45` | 40 | 115 | 10 |
| `STOREHOUSE` | `ORE_IRON:45`, `ORE_COAL:40`, `PLANT_FIBER:90`, `ORE_COPPER:20` | 30 | 100 | 6 |
| `WATCHTOWER` | `ORE_IRON:55`, `ORE_COBALT:20`, `PLANT_RESIN:30`, `ORE_NICKEL:10` | 45 | 140 | 12 |

## Target Bands

Configured in `default_targets`:

- Payback floor: `450` blocks
- Payback ceiling: `1800` blocks
- Minimum net benefit: `40` energy / 100 blocks

These are working bands, not immutable design law. Tune bands only with explicit decision notes.

## Tuned Effect Knobs (Current)

- `SMELTER` `bp=11250`
- `SHORING_RIG` `bp=14000` with scenario capture coefficient `shoring_risk_capture=1.8`
- `GREENHOUSE` `bp=12000` with realization coefficient `greenhouse_realization=0.75`
- `HERBAL_PRESS` `bp=11500`
- `WORKSHOP` `discount_bp=1200`, `time_cut_bp=1800`
- `STOREHOUSE` `bp=15500`
- `WATCHTOWER` `bp=12500` with scenario capture coefficient `watchtower_loss_capture=2.2`

## Current Simulated Outcomes (v1 config)

Command:

```bash
python3 04-economy/tools/construction_balance_sim.py --check
```

Current results are within thresholds for `frontier`, `growth`, and `fortress` scenarios.

## Tuning Workflow

1. Edit `04-economy/tools/construction_balance_config.v1.json`:
- building recipes/stakes/upkeep
- effect coefficients
- scenario baselines
- target thresholds

2. Run full table:

```bash
python3 04-economy/tools/construction_balance_sim.py
```

3. Validate threshold gates:

```bash
python3 04-economy/tools/construction_balance_sim.py --check
```

4. Optional narrow view:

```bash
python3 04-economy/tools/construction_balance_sim.py --scenario frontier
```

5. Re-run tests:

```bash
python3 -m unittest 04-economy/tools/test_construction_balance_sim.py
```

## Scope Guardrails

In scope for this simulator:

- deterministic building economics at per-100-block granularity
- recipe capex, upkeep drag, benefit, and payback windows
- scenario-based comparative balancing

Out of scope for this simulator:

- agent behavior models across 10k populations
- stochastic combat or pathing simulations
- orderbook/market microstructure
- detailed claim-war game-theory trees

## Next Tightening Steps

1. Add per-biome modifier overlays to scenarios.
2. Add upgrade tiers (`T2`, `T3`) with marginal ROI checks.
3. Add anti-snowball checks (max aggregate bonus caps per hex).
4. Export sim output snapshots to committed markdown for release notes.
