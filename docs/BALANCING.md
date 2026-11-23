# Balancing Guide

Every gameplay number lives in `src/shared/Config/`. No service or UI file contains a tunable, so
balancing never needs code changes. After any change, run:

```
lune run tools/pacing 240                 # prints the modelled timeline (minutes)
lune run tools/pacing 240 DoubleMaple    # the same with a game pass
lune run tests/run pacing                 # fails if the median timeline leaves the GDD targets
lune run tests/run                        # everything (config sanity checks included)
```

## The formulas

```
slider amplitude A = top radius + 0.75 × base             base = pan radius (Big Pan)
slider offset      = triangle wave of (t − start) × speed over 4A
speed              = 4.4 × min(1 + 0.012 × layers, 1.7)  (× 0.75 on a Snow Day)
PERFECT            = |offset| ≤ window                    window = Steady Hands + Σ Nibbler steady (× 1.5 Steady Spatula)
sliced pancake     = radius r − |offset| / 2, centered halfway (lens rule)
topple             = new radius < 0.16 × base             pays 25% of the tower as crumbs
regrow             = from 3 perfects in a row, + 0.05 × base per perfect (max base)
fluff              = (r / base)² × 1.5 if perfect × 5 if sprinkle (4% chance)
tower bonus        = 1 + towerK × (n − 1)^1.25            towerK = 0.08 × (1 + Tower Sense)
serve reward       = zone value × Σ fluff × tower bonus × (2 if craving) × totalMultiplier
totalMultiplier    = Batter × Nibblers × Feasts × Golden Syrup × Friends × 2x pass × 2x boost × Snow Day
Nibblers           = 1 + Σ power of equipped Nibblers (Sparkly × 2.5)
Yeti Feast         = 1 + 0.25 × Feasts
```

The core decision is **how far to push a tower**. The tower bonus makes 20 pancakes worth about
3.4× as much per pancake as 2, but every miss shrinks the next pancake, a topple refunds only a
quarter, the tray caps the height (Tall Tray), and each Yeti only pays double for its current
4-tall craving window. Fluffy Batter is the income upgrade; Steady Hands, Big Pan and Tall Tray are
skill-support upgrades that let a player stack higher with fewer topples.

The pacing model (`tests/PacingSim.luau`) is a bot on the real rules: it drops with human timing
error (`TIMING_SD` 0.075 s, plus occasional hesitation), serves when its next pancake would get
risky or the tray is full (walking and serving overhead included), buys the cheapest useful thing,
hatches eggs, unlocks zones and takes Yeti Feast. Egg luck moves a single run a lot, so the tests
use the median of 8 seeds. It is a model: use it to **compare** changes and confirm the feel in
playtests and with analytics.

## Where each knob lives

| File | Knobs | Effect |
|---|---|---|
| `Zones.luau` | `unlockCost`, `value`, positions, radius, colors | Zone pacing and income per zone |
| `Stack.luau` | layer height, overshoot, slide speed and ramp, perfect regrow, min radius, sprinkle chance, `TowerK`/`TowerExp`, topple refund, drop clamp, serve distance, craving bands/period/multiplier, tips | The feel of the hook |
| `Upgrades.luau` | `baseCost`, `growth`, `maxLevel`, `base` + `perLevel` | Batter is income, Steady is the perfect window, Pan is pancake size, Tray is max height, Boots is speed |
| `Eggs.luau` | `cost`, rarity odds, Sparkly chance, luck, reveal/cooldown times | Nibbler pace and rarity feel |
| `Nibblers.luau` | `RARITY_POWER`, `EGG_FACTOR`, per-species `steady` | How much companions matter |
| `Rebirth.luau` | `RequiredZone`, `BaseCost`, `CostGrowth`, `PerRebirth`, Spatulas, `BonusSlotsAt` | Prestige loop length and reward |
| `Perks.luau` | per-level effect, max level, Spatula cost | Long-term goals |
| `Order.luau` | interval, duration, order size, reach, rewards, Snow Day strength | Server event strength |
| `Rewards.luau` | daily, playtime gifts, codes | Retention rewards (sized in minutes of income) |
| `Monetization.luau` | pass effects, product grants (minutes of income), boost cap | Paid value |
| `Game.luau` | inventory cap, equip slots, friend bonus, egg distance, save timings | Limits and safety |

## Current tuning (model output, median of 8 seeds, no purchases)

| Milestone | Model | Target (tested) |
|---|---|---|
| First serve | 6 s | < 30 s |
| First upgrade | 18 s | < 60 s |
| First egg | 1.5 min | < 130 s |
| Pinecone Village | 14.5 min | 8–17 min |
| Frosty Falls | 30.7 min | 15–40 min |
| Cocoa Cliffs | 54.9 min | 35–90 min |
| First Yeti Feast | 77.6 min | 60–125 min |
| Aurora Summit | about 2 h | long-term goal |

Individual seeds range from about 47 to 116 minutes for the first Feast (lucky early Legendary
Nibblers shorten it), and the test requires every seed to stay within 40–160 minutes.

With the **2x Maple** pass the median first Feast comes at about 42 minutes (the bonus compounds
through upgrades); the test keeps it above 25 minutes and at least 10 minutes faster than free
play, so the pass speeds the game up without skipping it. **Auto Serve + Steady Spatula** gives
about 48 minutes, tested to stay between 25 minutes and the free median.

## Rules of thumb

- **Zones:** each zone's `value` is 5× the previous one; its unlock cost is roughly 10–25 minutes
  of income at the previous zone. Keep `unlockCost` growing faster than `value`.
- **The hook:** if players topple too often, raise `Overshoot` less or lower `SlideSpeed` before
  touching the perfect window; if towers feel trivial, raise `SpeedPerLayer`. A good human
  should average roughly half perfects at the starting window. `TowerK` is the main lever for how
  much tall towers are worth.
- **Cravings:** bands should overlap the tray sizes players actually have: the first band (5–12)
  is reachable from the start, the third (22–40) needs Tall Tray. Wider windows make cravings
  common and less exciting.
- **Upgrades:** `growth` between 1.3 and 1.5 keeps each level feeling earned. If early pacing is
  off, change Batter before touching zones.
- **Eggs:** the first egg should cost about 1–2 minutes of play so every new player gets a Nibbler
  early. Later eggs cost a few minutes of income in their zone.
- **Odds:** odds shown in-game come from the same function that rolls them (`Logic/Hatch`), so
  changing `Eggs.luau` updates the display automatically. Keep Mythic ≤ 0.1% so it stays news.
- **The Great Yeti:** a solo player must be able to fill a 45-pancake order in 120 s (at about
  12 pancakes per 26 s stack-and-serve cycle), checked in `tests/config.spec.luau`; groups fill it
  much faster.
  If players ignore it, raise `RewardMinutes`.
- **Rewards and products** are sized in *minutes of the player's income*, so they stay relevant at
  every stage. Each has a `min` floor so brand-new players still get something.
- **Currency cap:** `MaxCurrency` (1e300) protects against overflow.

## Safe-change checklist

1. Change numbers only in `Config/`.
2. Run the pacing tool and the full test suite.
3. Never rename an id (`Batter`, `MapleMeadow`, `Pip`, product keys…) after launch: saved
   profiles reference them. Add new ids instead, plus a `Schema` migration if a rename is unavoidable.
4. Lowering costs is always safe. Raising a cost players already paid is fine, but announce it.
5. Prefer small steps (10–20%) and compare analytics before and after.
