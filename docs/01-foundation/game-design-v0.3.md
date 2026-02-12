# Infinite‑Hex Adventurers – Game Design Document (v0.3)

> Decision alignment note: this is the vision document. For locked MVP behavior and implementation rules, use `docs/02-spec/mvp-functional-spec.md` and `docs/02-spec/design-decisions.md`.

## 1. Vision & Elevator Pitch

A headless, on‑chain roguelite MMO where players traverse an **infinite, deterministic hex grid**, harvest plants, mine ores, craft emergent items, and build revenue‑generating cities. All core rules live immutably in smart contracts; any front‑end (3‑D, pixel, text, Discord) can render the same state. Discovery, scarcity, and politics are 100 % player‑driven.

## 2. Design Pillars

| Pillar                         | Rationale                                                    |
| ------------------------------ | ------------------------------------------------------------ |
| **Headless & Client‑Agnostic** | Contracts expose pure verbs; UI is pluggable.                |
| **Immutable Procedural World** | No balance patches—scarcity is provable.                     |
| **Energy‑Gated Exploration**   | Turns time & distance into strategic decisions.              |
| **Private‑Until‑Reveal**       | Prevents map‑scraping; keeps exploration exciting.           |
| **Player Ownership & Economy** | Cities, facilities, and resources are true assets.           |
| **Permadeath & Legacy**        | High stakes; world map permanently expands with every death. |

## 3. World & Topology

```
Global Hex (∞)
 └─ Location (City, Cave, River, Desert, Wonder …)
      └─ Room / Sub‑area (for dungeons, markets, underworld)
           └─ Nested Room … (depth unbounded)
```

- Coordinates: ±2.3 × 10¹² range. Eternum core at (0,0).
- Deterministic functions (`hash(parent, idx)`) derive every node.

### Portals & Spatial Folds

- **Echo Portals**: rare anomalies that fold space‑time, linking distant hexes.

## 4. Core Systems

### 4.1 Energy & Movement

- `move(hex|subLoc)` burns ⚡ proportional to distance.
- Daily energy regen or via consumables.

### 4.2 Exploration & Discovery (Commit‑Reveal)

1. Player commits `hash(coord, salt)`.
2. Reveals to unlock sub‑locations & loot VRF.

### 4.3 Harvesting (Plants & Creatures)

- **Crop schema**: `growthRate`, `nutritionalValue`, `yield`, `mutationSeed`.
- Harvest burns energy; yield regrows per block unless depleted to 0 → permanent extinction.

### 4.4 Crafting & Mutation

```
craft(inputs[]) → newItem
newProps = f(props_A, props_B, …, XORseed)
```

- Any resources combinable; outputs inherit blended stats.
- Legendary roll if property product crosses threshold.

### 4.5 Mining & Metallurgy

- Fractal veins by depth; deeper → higher `grade`, `rarity`, hazards.
- Tool tiers gate `hardness`.
- Veins regen slowly; may **collapse** when over‑mined (no regen).
- Smelt → bars; Alloy → mutant metals feeding crafting loop.

### 4.6 Permadeath & Legacy Shards

- 0 HP/starvation → Adventurer NFT burned, **Map Shard** NFT minted (records explored path).
- Respawn at origin with new Adventurer.

### 4.7 Cities & Player Facilities

- Each City has 10 claimable **Vacant Lot** NFTs + a free Market Hall.
- Owners spend materials to build **Smithy, Crafter, Alchemist, Inn, Arcane Forge**, etc.
- Fees: flat + %; upgrade tiers improve efficiency; 30‑day upkeep.

### 4.8 Risk & Hazards

- Cave‑ins, sandstorms, monster ambushes trigger via VRF at higher depths/biomes.

## 5. Economy

| Loop          | Inputs        | Outputs           | Sink                           |
| ------------- | ------------- | ----------------- | ------------------------------ |
| Harvest       | Energy        | Crops             | Energy restore, crafting       |
| Mining        | Tools, Energy | Ores              | Tool durability, smelting fuel |
| Crafting      | Crops/Ores    | Consumables, Gear | Item burns in recipes          |
| City Services | Gold          | Repairs, recipes  | Facility fees, upkeep          |

Scarcity emerges from player decisions: over‑farm → extinct plants; vein collapse → ore shortage; facility monopolies → fee wars.

## 6. Player Progression

1. **Starter Kit** (basic tools, 100⚡).
2. **Frontier Explorer** (unlock mid‑tier recipes, tool crafting).
3. **Master Craftsman** (access Tier‑3 facilities, alloy forging).
4. **Realm Founder** (claim hex, settle via Shard + high‑tier items).

## 7. Social & Guild Dynamics

- Guilds pool Map Shards, operate city syndicates, control supply chains.
- PvE focus at MVP; PvP options (territory raids, fee sabotage) in later phases.

## 8. Procedural Generation Engine (Config‑Driven)

The entire universe is produced from **one global seed** plus a hierarchical set of JSON/YAML configs. Altering config values spawns different worlds without touching code.

### 8.1 Config Overview

```yaml
world:
  globalSeed: 0xDEADBEEF
  hexBiomeWeights: { desert: 8, forest: 15, tundra: 6, ocean: 5, city: 1 }

biomes:
  forest:
    subLocations: ["grove", "river", "cave", "ancient_ruins"]
    cropTable: { berry: 40, herb: 25, oak: 20, rare_flower: 5 }
    oreTable: { iron: 30, copper: 10 }
    hazardWeights: { bear: 5, bandit: 3 }

facilities:
  smithy:
    buildCost: { iron_bar: 50, timber: 20 }
    tiers:
      1: { efficiency: 1.0 }
      2: { efficiency: 1.1, upgradeCost: { steel_bar: 100 } }
```

### 8.2 Deterministic RNG Utility (pseudocode)

```python
# Uses keccak256 as deterministic PRNG

def rng(seed: bytes, salt: str) -> int:
    return int.from_bytes(keccak256(seed + salt.encode()), "big")
```

### 8.3 Hex Generation

```python
function generateHex(coord):
    seed = keccak256(globalSeed, coord)
    biome = pickWeighted(cfg.hexBiomeWeights, rng(seed, "biome"))
    return Hex(
        coord=coord,
        biome=biome,
        subLocations=generateLocations(seed, biome)
    )
```

### 8.4 Sub‑Location Generation

```python
def generateLocations(parentSeed, biome):
    locations = []
    for i in range(cfg.biomes[biome].numSubLocs):
        locSeed = rng(parentSeed, f"loc{i}")
        locType = pick(cfg.biomes[biome].subLocations, locSeed)
        locations.append(Location(id=i, type=locType, seed=locSeed))
    return locations
```

### 8.5 Resource Node Generation (Plants & Ores)

```python
def generatePlantNode(locSeed):
    crop = pickWeighted(cfg.biomes[biome].cropTable, rng(locSeed, "crop"))
    growth = rng(locSeed, "growth") % 20 + 5    # 5‑24 % per block
    nutrition = rng(locSeed, "nutri") % 10 + 1  # 1‑10 ⚡
    return Plant(type=crop, growthRate=growth, nutritionalValue=nutrition,
                 yield=100, mutationSeed=rng(locSeed, "mut") )
```

### 8.6 Ore Vein Generation

```python
def generateOreVein(locSeed):
    ore = pickWeighted(cfg.biomes[biome].oreTable, rng(locSeed, "ore"))
    grade = rng(locSeed, "grade") % 60 + 20  # 20‑79 % purity
    hardness = grade // 20                    # 1‑4
    regen = max(1, 5‑hardness) * 0.1          # slower for hard ores
    return Vein(type=ore, grade=grade, hardness=hardness,
                regenRate=regen, yield=100, mutationSeed=rng(locSeed, "mut"))
```

### 8.7 Facility Plot Generation

```python
function generateCity(coord):
    citySeed = keccak256(globalSeed, coord)
    plots = [VacantLot(id=i, fee=0) for i in range(10)]
    return City(coord=coord, plots=plots, marketHall=True,
                seed=citySeed)
```

### 8.8 Crafting Mutation Function

```python
function mutateProps(propsA, propsB, seed):
    mix = (propsA + propsB) / 2
    noise = rng(seed, "mix") % 10 ‑ 5
    return clamp(mix + noise, minVal, maxVal)
```

## 9. Technology Stack

| Layer               | Detail                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| **Contracts**       | `World`, `Movement`, `Harvest`, `Mine`, `Craft`, `CityRegistry`, `PlotNFT`, `FacilityLogic`, `Death` |
| **Privacy**         | Poseidon commit‑reveal + Starknet/Cairo proofs                                                       |
| **Randomness**      | Chainlink/Starknet VRF for loot rolls & hazards                                                      |
| **Client SDK**      | Emits JSON events; reference Discord/CLI client                                                      |
| **Immutable Proof** | Store bytecode hash of procedural algo at deploy                                                     |

## 10. DRY Modular Pseudocode Architecture (Config‑First)

> _Goal — a minimal, composable codebase where \***\*every rule lives in external config\*\***, and each on‑chain module is only responsible for a single concern. Replace configs to reskin the universe; never touch code._

### 10.1 Directory Layout

```
contracts/
  core/
    ConfigStore         # single source of truth (JSON blob ↔ struct)
    UtilsRng            # deterministic RNG helpers
    UtilsHash           # keccak / poseidon wrappers
    EnergyLib           # energy math + refill
  world/
    WorldView           # pure view fns: hex → biome, loc list
    LocationCache       # optional on‑chain cache (gas trade‑off)
  actors/
    AdventurerState     # position, energy, hp, inventory root
    Death               # permadeath + Map Shard mint
  resources/
    ResourceLib         # plant & ore property helpers
    GatherSystem        # generic harvest/mine via strategy pattern
    CraftSystem         # mutation + mint
  city/
    PlotNFT             # ERC‑721 vacant lots
    FacilityBase        # fee + upkeep hooks
    Smithy / Crafter / Alchemist / Inn / Forge (inherit Base)
  economy/
    GoldToken           # ERC‑20 soft currency
    FeeLib              # flat + basis‑point calc
```

### 10.2 Config Schema (Excerpt)

```jsonc
{
  "globalSeed": "0xDEADBEEF",
  "biomes": {
    "forest": {
      "weight": 15,
      "subLocations": ["grove", "river", "cave", "ruins"],
      "crops": { "berry": 40, "herb": 25, "oak": 20, "rare_flower": 5 },
      "ores": { "iron": 30, "copper": 10 },
      "hazards": { "bear": 5, "bandit": 3 }
    }
  },
  "facilities": {
    "smithy": {
      "buildCost": { "iron_bar": 50, "timber": 20 },
      "tiers": {
        "1": { "efficiency": 1.0 },
        "2": { "efficiency": 1.1, "upgradeCost": { "steel_bar": 100 } }
      }
    }
  }
}
```

### 10.3 Core Utilities (Pseudocode)

```python
module UtilsHash:
    fn hash(*vals) -> felt:
        return keccak256(concat(vals))

module UtilsRng:
    fn rng(seed, salt) -> felt:
        return UtilsHash.hash(seed, salt)  # deterministic
    fn weight_pick(table, seed) -> key:
        roll = rng(seed, "roll") % sum(table.values())
        acc = 0
        for k, w in table.items():
            acc += w
            if roll < acc: return k
```

### 10.4 WorldView – Pure Generation

```python
module WorldView:
    fn biome(coord):
        seed = UtilsHash.hash(Config.globalSeed, coord)
        return UtilsRng.weight_pick(Config.hexBiomeWeights, seed)

    fn locations(coord):
        b = biome(coord)
        subs = []
        for i in range(Config.biomes[b].subLocations.len):
            subs.append(gen_location(coord, i, b))
        return subs

    fn gen_location(coord, idx, biome):
        loc_seed = UtilsHash.hash(coord, idx)
        loc_type = UtilsRng.weight_pick(Config.biomes[biome].subLocations, loc_seed)
        return { id: idx, type: loc_type, seed: loc_seed }
```

_These remain **`view`** calls; no gas if executed off‑chain._

### 10.5 Actor & Energy

```python
module AdventurerState:
    struct Adv { pos, energy, last_refill, hp, inv_root }

module EnergyLib:
    fn spend(id, amt):
        assert Adv[id].energy >= amt
        Adv[id].energy -= amt

    fn refill(id):
        if now() - Adv[id].last_refill > DAY:
            Adv[id].energy = CAP
            Adv[id].last_refill = now()
```

### 10.6 Generic Gather System (Harvest / Mine)

```python
interface IGatherStrategy:
    fn cost(props, amount) -> felt
    fn on_deplete(node)

module GatherSystem:
    fn gather(id, node_key, amount, strat: IGatherStrategy):
        node = Node[node_key]
        EnergyLib.spend(id, strat.cost(node.props, amount))
        assert node.yield >= amount
        node.yield -= amount
        if node.yield == 0: strat.on_deplete(node)
        Node[node_key] = node
        mint(id, node.props.token, amount)
```

_`PlantStrategy`_\* and **`OreStrategy`** implement **`IGatherStrategy`**, achieving DRY reuse.\*

### 10.7 Crafting Mutator

```python
module CraftSystem:
    fn craft(id, inputs[]):
        burn_batch(id, inputs)
        seed = xor_all(inputs)
        out_props = mutate(inputs.props, seed)
        new_id = UtilsHash.hash(seed, block())
        mint(id, new_id, 1, out_props)
```

### 10.8 Facilities via Inheritance

```python
abstract class FacilityBase:
    storage Plot { owner, tier, fee_flat, fee_bp, last_upkeep }

    fn charge(user, value):
        fee = Plot.fee_flat + value * Plot.fee_bp / 10_000
        Gold.transfer(user, Plot.owner, fee)

class Smithy(FacilityBase):
    fn smelt(user, ore, fuel):
        charge(user, PRICE_SMELT)
        # convert ore → bar w/ tier bonus
```

### 10.9 Death & Respawn

```python
module Death:
    fn kill(id):
        burn_adv(id)
        mint_shard(id.explored_root)
        spawn_new(id.owner)
```

### 10.10 Config Upgrades (Governance)

```python
module ConfigStore:
    storage root

    fn update_root(new_root) onlyGovernance():
        root = new_root
```

_Balance changes = publish new JSON + root; contracts remain untouched._

---

This refactor removes duplication via **strategies, utilities, and base classes**, ensuring the codebase stays elegant and purely data‑driven.

## 11. Roadmap & MVP Scope. Open Questions & Tuning Knobs

- Optimal energy regen rate vs. travel cost?
- Vein collapse probability curve?
- Fee caps or pure free‑market?
- Map Shard utility beyond bragging rights?
- PvP timing & safe‑zone rules?
