# LiveOps Plan

How to keep Pancake Peak fresh after launch with what the code already supports, plus a roadmap of
deferred features.

## Levers that need only a config change

| Lever | Where | Notes |
|---|---|---|
| **Codes** | `Config/Rewards.luau` → `Codes` | Case-insensitive, once per player, optional `expires` (Unix UTC). Rewards are sized in minutes of income, so one code works for every player. |
| **Great Yeti frequency/strength** | `Config/Order.luau` | e.g. a "Yeti weekend": `IntervalSeconds` 480 → 240, `SnowSeconds` 90 → 180. |
| **Sprinkle pancakes** | `Config/Stack.luau` → `SprinkleChance`, `SprinkleMult` | "Sprinkle hour": 4% → 12% (every tower gets a few ×5 pancakes). |
| **Tower festival** | `Config/Stack.luau` → `TowerK`, `CravingMult` | Small changes make tall towers or cravings pay more; check `tools/pacing` first. |
| **Easy-flip day** | `Config/Stack.luau` → `SlideSpeed`, `Overshoot` | Slower or shorter swings for a relaxed weekend (or faster for a "Hard Mode" leaderboard week). |
| **Daily and playtime rewards** | `Config/Rewards.luau` | Raise for launch week; add a Nibbler to day 7 of a holiday week. |
| **Odds events** | `Config/Eggs.luau` | "Sparkly weekend": `ShinyChance` 1/60 → 1/40. Odds shown in-game update automatically. |
| **Leaderboard seasons** | `Config/Leaderboards.luau` | Bump a board's `store` suffix (`_v1` → `_v2`) to start a fresh season ("Tallest Stack of the week"). |
| **Product prices** | Creator Dashboard + `price` in `Config/Monetization.luau` | The config price is only for display; keep both equal. |

Code ideas for the first month: launch day (`LAUNCH`, live), first 1K visits, first 100 likes,
each update, and a weekly code on your social links. `FLIPFLIP` and `YETI` never expire; `SYRUP`
expires 2028-01-01.

## Suggested cadence

| When | What |
|---|---|
| Week 1 | Watch analytics daily: time to first egg, time to Pinecone Village, D1 retention, store conversion. Fix pacing with config only. |
| Every Friday | Event weekend via config (Yeti weekend, Sprinkle hour, Sparkly weekend). |
| Every 2 weeks | A content update from the roadmap + a new code. |
| Monthly | Leaderboard season + a limited Nibbler (new species in an existing egg for a month). |

## Metrics to watch

- **Onboarding:** % of new players who finish the 5 tutorial steps (drop, perfect, serve, upgrade,
  egg). The step is saved in the profile (`tutorial.step`), so funnel analytics can track it.
- **Pacing:** session minutes at the Pinecone Village / Frosty Falls unlock; first Yeti Feast.
  Compare with `docs/BALANCING.md`.
- **Hook health:** perfect rate (`stats.perfects / stats.pancakes`), average serve height
  (`stats.pancakes / stats.serves`), topple rate and craving hits, all saved. If players mostly
  serve 3–4 pancake towers, the tower bonus isn't landing (or the tutorial isn't); if topples are
  more than ~1 per 5 serves, the swing is too fast.
- **Social:** Great Yeti orders filled per hour, players per order, tips paid.
- **Retention:** D1 / D7, daily streak length.
- **Monetization:** payer conversion and ARPPU per item. If one pass sells far better than the
  rest, check it doesn't feel mandatory (Auto Serve and Steady Spatula are the ones to watch).

## Roadmap of deferred features

Ordered by impact for effort. Each fits the current architecture.

1. **More zones** (1 day each: Gingerbread Gorge, Blueberry Glacier, Honey Hive Heights). Add a
   `Zones.luau` entry (center, colors, value), an egg, 6 Nibblers and a `DECOR` builder in
   `World/MapBuilder.luau`. Yetis, gates, ramps, travel and the pacing model are data driven;
   `tests/config.spec.luau` checks the new zone doesn't overlap anything.
2. **Toppings** (1–2 days): syrup, berries or whipped cream layers that pay a bonus and change the
   next swing (sticky = slower). Add a field to the layer wire format and a branch in `Stack.drop`.
3. **Quests** (2–3 days): "serve a 30-tall tower", "20 perfects in a row", "help 3 Great Yeti
   orders". Add a `quests` field to `Logic/Schema` with a migration, hook the counters in
   `profile.stats`, and a panel.
4. **Tray and pan skins** (2 days): cosmetic trays, pancake shapes and drop words from a Spatula or
   event shop. Towers are drawn on clients, so a `TraySkin` attribute is all other clients need.
5. **Seasonal events** (3–5 days each): a themed zone (Halloween pumpkin pancakes, a winter cocoa
   festival) with event flavors and an event egg. Zones and eggs already support it.
6. **Duel stacks** (3 days): two players race to the tallest perfect tower on a shared timer;
   uses the same server-decided drops.
7. **Trading** (1 week, highest risk): two-sided confirm with server-held offers, both profiles
   locked during the swap, a trade log. Only when player count justifies the moderation work.
8. **Group rewards** once you have a Roblox group (`Player:IsInGroup`).

## Updating safely

- Ship config tweaks with **Publish** and let servers update naturally; use "Restart servers for
  updates" only for fixes. Saves flush on shutdown (`BindToClose`), and the session lock prevents
  two servers from saving the same player.
- Changes to the profile shape need a version bump and a migration in `Logic/Schema`, plus a test
  in `tests/profile.spec.luau`. Profiles from a newer version are refused, never downgraded.
- Never rename ids or the `DataStoreName` after launch.
