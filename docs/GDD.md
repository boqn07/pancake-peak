# Pancake Peak — Game Design Document

## 1. Title and theme

**Pancake Peak.** A snowy storybook mountain above a sea of clouds, where friendly Yetis are always
hungry for pancakes. You are a tiny **Chef** carrying a tray over your head. A fresh pancake slides
back and forth above your stack; tap **FLIP!** to drop it. Whatever hangs over the edge is sliced
off, so the next pancake is smaller. Line it up perfectly and it keeps its full size. Serve the
wobbling tower to a Yeti for **Maple** (the currency), buy upgrades, climb to new zones and hatch
**Mystery Eggs** in a giant frying pan to find **Nibblers**: snack-loving critters that hop along
behind you.

Mood: cozy, crisp, warm. A snow day with cocoa and breakfast. Never dark or scary.

## 2. Core loop

**One sentence:** Drop sliding pancakes onto your tray to build the tallest tower you dare, serve it
to a hungry Yeti for Maple, and spend Maple on upgrades, Nibblers and higher zones with tastier
pancakes.

```
A pancake slides over your stack ──► tap FLIP: perfect = full size, miss = sliced smaller
        ▲                                                │
        │                     taller = bigger tower bonus, faster slides, smaller pancakes
        │                                                ▼
 Upgrades / Nibblers / new zones ◄── Maple ◄── serve to a Yeti (×2 if it matches its craving)
        ▲
        └──── Yeti Feast: reset Maple and upgrades for Golden Spatulas and a permanent multiplier
```

## 3. The unique hook: Flip & Stack

- **The slide.** Every pancake slides along X then Z (alternating) across the top of your stack,
  overshooting the edge on both sides, and speeds up as the tower grows. Its position is a pure
  function of when it appeared and the shared server clock, so every player sees the same slide.
- **The drop.** Tap FLIP (button, click, tap in the world, E or gamepad R2). Within the **perfect
  window** (Steady Hands) the pancake lands dead center at full size: "PERFECT!", rising pitch, combo
  +1. From 3 perfects in a row each perfect also **regrows** the pancake a little. Otherwise the
  overhang is sliced off: two equal circles `d` apart overlap in a lens whose largest circle has
  radius `r − d/2`, so the new pancake is exactly that circle, halfway between. The sliced crescent
  tumbles off as crumbs.
- **Topple.** If a pancake would be smaller than 16% of your pan, the tower topples. You keep 25%
  of its value as crumbs, so a fall stings but never wipes out a session.
- **Push your luck.** Value per pancake is `(r / pan)²` (×1.5 perfect, ×5 for the rare 4% **Sprinkle**
  pancake). The tower bonus is `1 + 0.08 × (n − 1)^1.25`, so tall towers pay far more, but pancakes
  slide faster and shrink as you go. Serve now, or one more?
- **Cravings.** Each zone has three Yetis. Each craves a height window that changes every 2 minutes
  (low 5–12, mid 12–22, high 22–40; the window is shown on a sign over its table). Serving inside it
  pays **×2**. Your tray holds 15 pancakes at first (Tall Tray raises it), so the high Yeti is a goal.
- **Tips.** Other chefs who stacked recently and stand within 40 studs of a serve get a 15% tip, so
  cooking side by side pays.
- Server-authoritative: the client sends only "drop at server time t" and "serve". The server keeps
  every stack, accepts t only within the last 0.6 s, decides the slice, topple, value and payout.
  The client predicts its own drop with the same function so the slice is instant.

Why it's fun and different: a one-tap skill moment on every action, with a decision on top, and a
result you can see from across the map. It shares nothing with our earlier verbs (drawing loops,
rolling a ball, popping chains).

## 4. Progression layers

1. **Upgrades** (Maple): Fluffy Batter (Maple ×), Steady Hands (perfect window), Big Pan (bigger
   pancakes: more room for error), Tall Tray (more pancakes), Snow Boots (walk speed).
2. **Zones** up the mountain: Maple Meadow → Pinecone Village → Frosty Falls → Cocoa Cliffs →
   Aurora Summit. Each costs Maple, pays 5× more per pancake, has its own flavor color, Yetis, egg,
   props and light.
3. **Nibblers** from Mystery Eggs: they multiply Maple, and some widen the perfect window.
4. **Yeti Feast** (rebirth, needs Cocoa Cliffs): resets Maple and upgrades; keeps zones and Nibblers;
   gives +25% Maple forever per Feast and **Golden Spatulas**.
5. **Spatula Shop**: Golden Syrup (+Maple), Swift Skis (+speed), Lucky Yolk (+egg luck), Extra
   Pocket (+slot), Tower Sense (+tower bonus).

## 5. Collectibles: Nibblers

Thirty critters, six per egg: a chick, a mouse, a waffle-spotted pup, a syrup fox, a chef penguin, a
maple stag; squirrels, owls, a lumberjack bear, a pine moose; puffins, a snowy owl, a walrus, a frost
dragon; a red panda, an ibex, a cocoa yak, a lavaling; a star fox, a reindeer, a narwhal and a
Mythic Aurora Yeti. They hop behind you, squash on landing and look up at your tower. **Sparkly**
variant: 1 in 60 (1 in 30 with luck), ×2.5 power.

| Rarity | Maple Egg odds |
|---|---|
| Common | 55% |
| Uncommon | 28% |
| Rare | 12% |
| Epic | 4% |
| Legendary | 0.9% |
| Mythic | 0.1% |

Later eggs shift odds slightly toward rarer tiers. The egg window shows the player's real odds
(computed by the same function the server rolls with). Eggs cost Maple only; nothing random is sold
for Robux. Equip slots: 3 base, +1 at Feast 1, 3 and 6, +1 per Extra Pocket (max 2), +3 with the
Extra Pockets pass. Inventory cap 150.

## 6. Economy and pacing

- **Maple**: earned by serving (plus tips, Orders and rewards).
  Serve = zone value × Σ fluff × tower bonus × craving × multipliers.
- **Golden Spatulas**: earned at a Feast (3, +1 per extra power of ten of Maple banked, max +5).

Pacing is checked by `tests/pacing.spec.luau`: a bot plays the real stacking rules with a human
timing error (σ 75 ms), hesitation, distraction and craving choice, over 8 seeds:

| Milestone | Target | Model (median of 8 seeds) | Why |
|---|---|---|---|
| First serve | < 30 s | ~7 s | A Yeti stands right by the spawn |
| First upgrade | < 1 min | ~20 s | Fluffy Batter costs 10 Maple: one short stack |
| First egg | ~1–2 min | ~90 s | First Nibbler early, so a follower appears quickly |
| Pinecone Village | 8–17 min | ~14 min | Standard "new world" beat |
| Frosty Falls | 15–40 min | ~31 min | |
| Cocoa Cliffs | 35–90 min | ~55 min | Feast gate |
| First Yeti Feast | 60–125 min | ~78 min | |
| Aurora Summit | long-term | ~2 h | |

Egg luck moves one player's timeline by roughly ±40%.

## 7. Social and multiplayer

- **The Great Yeti's Order** (server event: first after 3 min, then every 8 min, or bought by anyone
  for everyone): the Great Yeti stomps into the plaza of the busiest zone with a giant empty plate.
  Every pancake served to it fills the order (it still pays you normally). The target scales with
  the crowd. Filling it pays every contributor ~3 minutes of income and starts a **Snow Day** for
  the whole server: ×2 Maple and pancakes slide 25% slower for 90 s.
- **Towers are visible to everyone**: other players' stacks wobble over their heads, so a 40-high
  tower is a status symbol. Big towers (40+) are announced server-wide.
- Tips: 15% of every serve goes to other active chefs within 40 studs.
- Friends bonus: +10% Maple per friend in the server (max +50%).
- Announcements for 40+ towers, Legendary/Mythic/Sparkly hatches, new zones and Feasts.
- Global leaderboards at Base Camp: Most Maple, Yeti Feasts, Tallest Stack.

## 8. Daily and return incentives

7-day login streak (Maple, boosts, a Rare+ Nibbler on day 7), 7 playtime gifts per session
(2–60 min), codes (LAUNCH, FLIPFLIP, YETI, SYRUP), boosts that tick only while online.

## 9. Monetization

Convenience and speed, never walls. Placeholder IDs in `Config/Monetization.luau`.

Game passes: **2× Maple**, **Auto Serve** (a full tray is served to your best zone by itself, no
walking, no craving bonus), **Steady Spatula** (+50% perfect window), **Extra Pockets** (+3 slots),
**Lucky Yolk** (egg luck), **Triple Hatch**, **Fast Hatch**.

Developer products: Maple Pouch / Jar / Barrel (scale with progress), 2× Maple 15 min, Lucky 15 min,
**Summon the Great Yeti** (for the whole server). All receipts are idempotent.

## 10. Art direction

- **Light:** crisp late morning (ClockTime 10.5), low warm sun, soft blue shadows, light haze, gentle
  bloom; snow drifting everywhere. Each zone tints the light: golden at Maple Meadow, cool blue at
  Frosty Falls, warm red at Cocoa Cliffs, violet twilight with green aurora at the summit. Snow Day
  brightens everything with golden sparkles.
- **Palette:** snow `#F4F7FB`, ice blue `#5CC8F0`, pine `#4F8A5B`, maple amber `#F2A33A`, berry red
  `#E5484D`, cocoa `#7A4F33`, cream `#FFF8EC`, ink blue `#24406B` (text and outlines, never pure
  black). Each zone has its own pancake color and one accent.
- **Shapes:** round, chunky, storybook: fat cylinders, balls, wedge roofs. Pine trees are stacked
  cones of balls; chalets have red roofs and warm windows. No sharp spikes, no dark caves.
- **Materials:** Snow for the ground, Ice and Glacier for frozen falls, WoodPlanks for tables, tables
  and chalets, Slate and Sandstone for cliffs, SmoothPlastic for pancakes and props, Neon only for
  windows, aurora and the Great Yeti's eyes.
- **UI: "camp-mug enamel".** Cream enamel panels with thick ink-blue rims and little speckles, red
  gingham ribbon headers, round wooden HUD buttons, maple-syrup drips on the currency pill, Fredoka
  One lettering for headlines and Gotham for body text. (Lumen Lasso used night glass, Tiny Tumble
  paper stickers, Pop Lagoon glossy inflatables; this is enamel and gingham.)
- **Motion:** stacks lean and spring back as you walk; pancakes squash on landing; crumbs tumble;
  Yetis breathe, bob and gulp pancakes one by one; Nibblers hop and squash.

## 11. Launch content scope

- Base Camp hub + 5 zones, each with 3 Yeti tables, a plaza, a Mystery Egg pan and its own props.
- 30 Nibblers, 6 rarities + Sparkly.
- 5 upgrades, 5 Spatula perks, Yeti Feast, the Great Yeti's Order + Snow Day.
- 10 UI panels, onboarding, daily, playtime, codes, settings, store.
- 7 passes, 6 products.

## Open questions (defaults chosen)

- Group/community rewards need a Roblox group id: default off, see `docs/HUMAN_TASKS.md`.
- Music needs licensed tracks: silent by default, built-in SFX ship with the game.

## Controls

- **FLIP!** button (bottom right), **click / tap** anywhere in the world, **E** or gamepad **R2**:
  drop the sliding pancake.
- **SERVE** button (appears next to a Yeti), **F**, gamepad **X**, or the Yeti's prompt: serve.
- Prompts: Mystery Eggs, ice gates.
- Keyboard: U Upgrades, G Nibblers, T Zones, H Feast, B Store, Backspace closes.
- Gamepad: Y Upgrades, L1 Nibblers, R1 Feast, D-pad Zones / Store / Daily / Gifts, B closes.
