# Architecture

## Folder structure (Rojo)

```
default.project.json         Rojo tree: maps src/ into the DataModel, sets Lighting/Workspace properties
src/
  shared/   → ReplicatedStorage.Shared
    Config/    every tunable number, id and asset reference (pure data, no Roblox types)
    Logic/     pure game rules (no Roblox services), unit-tested under Lune
    Net.luau   remote contract: names, payload layouts, per-remote rate limits
    Util/      Signal (tiny event helper), YetiModel (code-built Yeti used by map and client)
  server/   → ServerScriptService.Server
    Main.server.luau     boots services in dependency order
    Data/                SessionStore (session-locked DataStore wrapper), ReceiptProcessor
    Services/            one service per system (Data, Economy, Zone, Stack, Order, Nibbler, ...)
    World/MapBuilder     builds the whole mountain from Parts at server start
  client/   → StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau     boots controllers
    Controllers/         state mirror, audio, lighting, effects, tower rendering, flip/serve input,
                         Great Yeti, Nibbler models and followers, egg reveal, prompts, input
    UI/                  Theme, Kit (camp-mug enamel components), Hud, Notifications, Onboarding,
                         Panels (one file per screen)
tests/      Lune runner, Roblox-style module loader, specs, pacing model, headless smoke test
tools/      dev scripts: pacing timeline and medians, compile check, built-place inspector
```

## Module boundaries

- **Config** never requires anything but other Config. **Logic** requires Config and Logic only.
  Neither touches Roblox services, so both run under Lune (`lune run tests/run`).
- **Services** are the only code that mutates profiles. Each exposes `Init()` (wire dependencies,
  no yielding) and `Start()` (connect events, spawn loops). Services find each other through the
  registry passed into `Init`. Boot order is the `ORDER` list in `Main.server.luau`.
- **Controllers** (client) only read state, predict and draw. They never decide outcomes.

## The hook: Flip & Stack

All stacking rules live in `Logic/Stack.luau`, shared by the server (decides every drop and serve),
the client (draws the sliding pancake, predicts drops) and the pacing model (plays the game).

- **The slider is a function of time.** A pancake appears at server time `start` and sweeps back
  and forth over the top of your stack: `A = topR + Overshoot × base`,
  `s = ((t − start) × speed) mod 4A`, `offset = −A + s` for `s < 2A`, else `3A − s`. Even layers
  slide along X, odd layers along Z. Every machine computes the same position from
  `workspace:GetServerTimeNow()`, so nothing per frame is replicated. Speed grows 1.2% per layer
  (capped at ×1.7) and is ×0.75 on a Snow Day.
- **Dropping.** `|offset| ≤ perfect window` (Steady Hands + Nibblers' steady + Steady Spatula pass)
  is PERFECT: same size, combo + 1, and from 3 in a row the pancake regrows 5% of base. Otherwise
  the overhang is sliced: two equal circles `d` apart overlap in a lens whose largest circle has
  radius `r − d/2`, centered halfway, so that circle is the new pancake. Below `0.16 × base` the
  tower topples and pays 25% of its value as crumbs.
- **Value.** `fluff = (r / base)²` (×1.5 perfect, ×5 sprinkle, a 4% roll per pancake);
  `serve = zone value × Σ fluff × (1 + towerK × (n − 1)^1.25) × (×2 if the Yeti craves n) × multipliers`.
  Tall towers pay superlinearly, so the decision is *how far to push* before the tray fills
  (Tall Tray) or the pancakes get too small.
- **Cravings.** Each zone has 3 Yetis craving bands 5–12, 12–22 and 22–40. The current 4-tall
  window is a hash of `floor(t / 120)`, zone and Yeti index (`Stack.craving`), so server, clients
  and tests agree without replication; the client paints it on each Yeti's sign.
- **Server authority** (`StackService`). The client sends only `Drop(clientServerTime)` and
  `Serve()`. A drop is accepted if the profile is loaded, the character is alive, 0.22 s passed
  since the last one, the tray isn't full and the pancake has appeared; the time is clamped to the
  last `MaxLag` (0.6 s) and never before `start`. A serve needs honest movement, a Yeti table of a
  zone you own within 20 studs (or the Great Yeti within 30), and a 0.8 s cooldown. The server
  broadcasts every change as a compact `Stack` event (`Net.StackKinds`: Reset, Drop, Topple, Served).
- **Prediction** (client). `StackRenderer:PredictDrop` runs `Stack.drop` on a copy of the mirrored
  state at once (sound, slice debris, PERFECT text) and keeps the drop pending; the server's Drop
  event replaces it with the authoritative layer. Unconfirmed predictions expire after 0.9 s.
- **Tips.** Serving pays 15% (with their own multipliers) to other chefs who dropped a pancake in
  the last 30 s and stand within 40 studs.
- **Auto Serve** (pass) pays a full tray to the best zone's first Yeti after 0.6 s (setting toggle).

## Zones and the world

`World/MapBuilder` builds the sea of clouds, Base Camp (hub, leaderboards, cabins), five plateau
zones with snow, cliffs, props, a plaza, three Yeti tables each and a Mystery Egg in a frying pan,
and plank ramps with ice gates, all from `Config/Zones` and `Logic/ZoneGeo` (ramps, landmarks,
Yeti ring). The server's gameplay geometry and the map can therefore never disagree, and
`tests/config.spec.luau` checks slopes, spacing and overlaps.

`ZoneService` (4 Hz) tracks which zone each player is in, flags implausible movement (faster than
`walkSpeed × 1.6 + slack`) for 2 seconds, has a snow eagle carry fallers back up, and bounces
trespassers on unowned zones back to Base Camp, whatever their client does to the ice gate.

## The Great Yeti's Order and Snow Day

`OrderService` sends the Great Yeti into the busiest zone's plaza every 8 minutes (first after 3,
or when someone buys **Summon the Great Yeti**, which adds 30 s if one is already up). The order is
45 pancakes, +60% per extra player in that zone, within 120 s. Pancakes served to it count toward
the order (and still pay normally). If it fills, every contributor with ≥ 5% gets 3 minutes of
income and the whole server gets a 90 s **Snow Day**: ×2 Maple and pancakes slide at ×0.75 speed.

## Client / server split

| Concern | Server | Client |
|---|---|---|
| Maple, upgrades, zones, Yeti Feast, Spatulas | Owns and validates everything | Sends requests, mirrors state |
| Stacks | Owns every stack, decides drops / topples / serves, pays | Draws every tower from shared time, predicts own drops, lean spring, debris, serve flight |
| Cravings | Computes from the clock when paying | Paints the same numbers on signs and the HUD |
| Nibblers | Rolls eggs, inventory, publishes the equipped list as the `Nibblers` attribute | Builds and hops follower models for every player |
| Ice gates | Bounces trespassers, refuses serves on unowned zones | Hides owned gates, makes locked gates solid for its own character |
| Great Yeti | Picks the zone, counts pancakes, pays out, Snow Day | Stomp-in, chomps, bar, jump for joy or wander off, snowy grade |
| Purchases | Owns ProcessReceipt and pass ownership | Prompts purchases |

## Remote contract

All remotes live in `ReplicatedStorage.Remotes` and are declared in `src/shared/Net.luau`.
Every client→server remote is registered with `NetService:On(name, validate, handler)`, which:
1. drops the call if the player's profile isn't loaded,
2. applies the per-remote token-bucket rate limit from `Net.luau`,
3. runs the argument validator (type, range, known config key) inside `pcall`,
4. runs the handler inside `pcall` so one bad call can't break the service.

Client → server (RemoteEvent):

| Remote | Args | Server checks |
|---|---|---|
| `Drop` | t: finite number | alive, drop interval, tray not full, pancake appeared; t clamped to the last 0.6 s |
| `Serve` | – | tray not empty, cooldown, honest movement, at a Yeti of an owned zone or the Great Yeti |
| `BuyUpgrade` | upgradeId: string | known id, not maxed, affordable |
| `BuyZone` | zoneId: string | known id, previous zone owned, affordable |
| `BuyPerk` | perkId: string | known id, not maxed, enough Golden Spatulas |
| `HatchEgg` | eggId: string, count: 1\|3 | known id, zone owned, within `EggDistance`, Triple Hatch pass for 3, bag space, cooldown, affordable |
| `Equip` / `Unequip` / `Release` | uid: string | owned uid, slot count |
| `EquipBest` | – | – |
| `Rebirth` | – | Cocoa Cliffs owned, affordable |
| `ClaimDaily` | – | not claimed today (UTC) |
| `ClaimPlaytime` | index: int | in range, unlocked by session time, not claimed this session |
| `RedeemCode` | code: string ≤ 24 chars | exists, not expired, not used |
| `SetSetting` | key: string, value: boolean | known key |
| `Teleport` | "BaseCamp" or zoneId | owned, cooldown |
| `SkipTutorial` | – | – |
| `StackSnapshot` | – | rate limit (late-join tower sync) |

The client never sends positions, amounts, sizes or layer data.

Server → client: `State` (changed profile keys + derived values: multipliers, perfect window, pan,
tray, towerK, slide, speed, slots, passes, income), `Stack` (everyone: one tower event),
`StackSnapshot`, `ServeResult` (server, tips, crumbs), `EggResult`, `Reward`, `Notify` (one player),
`Announce` (server-wide: tall towers, rare Nibblers, zones, Feasts, the Great Yeti) and `Order`.

## Data

- `Data/SessionStore` implements the ProfileService/ProfileStore pattern on plain DataStores:
  `UpdateAsync` session locks with job id + per-session token + timestamp, refusal to load while
  another live server holds the lock, stale-lock takeover, autosave that refreshes the lock,
  release on leave, `BindToClose` flush, retry with backoff, and a hard rule that a profile that
  failed to load is never saved (so a DataStore outage can't overwrite real data with defaults).
- The DataStore is injected, so the store is unit-tested in Lune against a mock that can fail on
  demand (`tests/sessionstore.spec.luau`).
- `Logic/Schema` versions the profile, migrates old shapes forward, repairs wrongly typed fields
  and refuses data from a newer version rather than downgrading it. Stacks are not saved (a
  rejoin starts with an empty tray).

## Purchases

`Data/ReceiptProcessor` (unit-tested): profile not loaded → `NotProcessedYet`; PurchaseId already
recorded → `PurchaseGranted` only once that record is saved; otherwise grant, record the id, force
a save, and return `PurchaseGranted` only if the save succeeded. A retry after a failed save finds
the id in memory and does not grant twice.

## Performance

- StreamingEnabled. The map is static Parts built once. The client adapts to streaming: gates,
  signs, Yetis and eggs are (re)applied as parts stream in.
- Towers: no server Instances. Each player's tower is pooled Parts on the client, moved with one
  `workspace:BulkMoveTo` per frame. Full detail within 75 studs; other players' towers beyond that
  (or always, in performance mode) are one column Part; beyond 170 studs they are hidden.
- Followers move with one `BulkMoveTo` per frame; far players are skipped.
- Effects (floating numbers, crumbs, puffs) are pooled. Performance mode turns off sun rays,
  shadows, snowfall, Yeti/egg idle animation, extra followers of other players and most particles.
- Late joiners get a full tower snapshot, the current Order and every player's Nibblers from
  attributes.

## Testing

- `lune run tests/run [filter]` runs every spec. Pure Config/Logic modules and the server's
  `SessionStore` / `ReceiptProcessor` are tested directly. `tests/stack.spec.luau` covers the
  slider, perfect and sliced drops (lens rule), regrow, topples, sprinkles, the drop-time clamp,
  tower value, cravings, economy and progression. `tests/pacing.spec.luau` runs a modelled player
  (`tests/PacingSim.luau`, a bot with human timing error that stacks, serves and shops with the
  real rules) on several seeds and checks the median milestones.
- `tests/smoke.spec.luau` builds the place with Rojo, loads it with `@lune/roblox` (real Instance
  classes, so an invalid property name or type fails), fakes the engine services in
  `tests/RobloxEnv.luau` (with the server clock following the fake clock), and plays a session end
  to end: server boot and map build, join and client boot, perfect flips predicted and confirmed,
  sliced drops and a topple, forged / too-fast drops, serving at a Yeti (and a craving), purchases,
  a trespass bounce, malicious remote arguments, a Mystery Egg, a full Great Yeti's Order with Snow
  Day, every UI panel, the egg reveal, and leaving. It can't simulate physics, rendering or real
  networking; those need a Studio playtest (see `docs/HUMAN_TASKS.md`).
