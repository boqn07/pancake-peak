# Progress Log

Resume point for anyone continuing the build. Newest phase at the bottom.

## Phase 1 – Research ✅
- `docs/RESEARCH.md`: live web check (2026-11-23): Steal An Egg, Throw Food For Animals, the "+1"
  incremental wave, Sell Fries!, Grow a Garden, Pet Simulator 99, Fish It!, Bee Swarm.
- Hard constraint: clearly different from Lumen Lasso (dusk islands, light-ribbon lasso), Tiny
  Tumble (giant house, growing ball) and Pop Lagoon (tropical chain-pop bubbles). Pancake Peak is a
  snowy storybook mountain with a timing-and-stacking verb.

## Phase 2 – GDD ✅
- `docs/GDD.md`: **Pancake Peak**. Hook = Flip & Stack (a sliding pancake you drop on a tray over
  your head; overhang is sliced off; perfect drops keep the size; serve the tower to Yetis).
- Pacing tuned with a bot that has human timing error on the real stack rules
  (`tests/PacingSim.luau`, `tools/pacing-medians.luau`).

## Phase 3 – Architecture and core systems ✅
- Infrastructure carried over from the earlier games and re-themed: session-locked
  `SessionStore`, idempotent `ReceiptProcessor`, `NetService` (rate limit, validation, pcall),
  schema migrations, daily/codes/boosts logic.
- New: `Logic/Stack` (time-based slider, lens-rule slicing, perfect window, regrow, topples,
  sprinkles, tower value, deterministic cravings, drop-time clamp), `Logic/ZoneGeo`,
  `StackService` (server-owned stacks, compact events, serving, tips, Auto Serve), `ZoneService`
  (ownership, travel, movement check, snow-eagle rescue, trespass bounce), `OrderService` (Great
  Yeti's Order + Snow Day), Nibblers and Mystery Eggs, Yeti Feast, Spatula Shop.

## Phase 4 – World, visuals, UI and onboarding ✅
- `World/MapBuilder`: sea of clouds with a distant pancake-shaped mountain, Base Camp hub (cabins,
  monument, signboard leaderboards), five plateau zones with their own palette and props, three
  Yeti tables each with craving signs, Mystery Eggs in giant frying pans, plank ramps and ice gates.
- Client: `StackRenderer` (pooled towers for every player, slider from shared time, local drop
  prediction with server correction, lean spring, slice debris, topple scatter, serve flight into
  a Yeti's mouth, column LOD), `StackInput` (FLIP via button / click / tap / E / R2, SERVE via
  button / F / X / prompt, serve target and value), `OrderRenderer` (the Great Yeti stomps in,
  chomps, celebrates or wanders off), `NibblerModels` (30 code-built mountain critters),
  `Followers` (hopping parade), `EggReveal`, per-zone `LightingFX` with a white-gold Snow Day,
  `WorldFX` (gates, live craving signs, breathing Yetis, wobbling eggs, snowfall).
- UI in a new "camp-mug enamel" style (cream enamel panels with ink-blue rims and speckles, red
  gingham headers, FredokaOne lettering, a code-built maple-syrup coin): HUD with FLIP and SERVE,
  tower meter, craving and value labels, 10 panels, notifications, a 5-step onboarding with a
  guide beam.

## Phase 5 – Monetization ✅
- 7 passes and 6 products with placeholder ids (0 = "not on sale yet", never errors). Products are
  sized in minutes of income. Egg odds are shown from the same function that rolls them. Eggs cost
  Maple only.

## Phase 6 – Performance and security ✅
- No server Instances per pancake; one small event per drop; client towers pooled, one BulkMoveTo
  per frame, column LOD for far towers, hidden beyond 170 studs. Pooled effects. Performance mode.
- Every remote validated and rate limited; the client only sends a drop timestamp (clamped to the
  last 0.6 s) and "serve"; serving needs ownership, reach, cooldown and honest movement.

## Phase 7 – Testing ✅
- 103 tests pass (`lune run tests/run`): stack/economy/progression, config integrity and geometry,
  profile/schema, session store, receipts, format, pacing (median of 8 seeds), and the headless
  smoke test that boots the built place and plays a full session: predicted perfect flips, slices,
  a topple, forged drops, serving and a craving, purchases, an egg and a full Great Yeti's Order.
- StyLua clean. Selene: 0 errors, 0 warnings (run with a minimal Roblox globals file because the
  API dump can't be downloaded in the build environment).

## Phase 8 – Handoff ✅
- `README.md`, `docs/ARCHITECTURE.md`, `docs/HUMAN_TASKS.md`, `docs/BALANCING.md`,
  `docs/LIVEOPS.md`. Built place: `build/PancakePeak.rbxl` (not committed; `rojo build` recreates it).

## Known limitations
- Not yet played in Roblox Studio: the smoke test can't check physics, rendering, real networking
  or how it looks. `docs/HUMAN_TASKS.md` §1 is the playtest script.
- The client reports its drop time, which the server clamps to the last 0.6 s for lag fairness.
  A modified client could therefore always report the perfect moment within that window. Income is
  still bounded by the drop interval, tray size and serve rules, so the most it gains is "plays
  like a very skilled player".
- Towers stay world-aligned over the head (they don't turn with the character) so the slide
  direction always reads the same on screen; playtest whether that feels right.
- Sounds use Roblox's built-in clips (pitched per role); no music until tracks are uploaded.
- On touch devices FLIP and SERVE sit left of the default jump button; very small or unusual
  screens may need a nudge (`Hud.luau`, `buildActionButtons`).
- Selene needs `selene generate-roblox-std` once on a machine with internet access.
