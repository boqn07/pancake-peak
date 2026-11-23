# Human Tasks

Everything that needs a Roblox account, Studio, the Creator Dashboard or a human judgment call.
The code is complete without any of these; items marked **required** must be done before a public
launch. Rough total: 2–3 hours, most of it making icons and thumbnails.

## 1. Open and playtest (required, 20 min)

1. Open `PancakePeak.rbxl` in Studio (or install Rojo 7 and its Studio plugin, see `README.md`,
   and `rojo build -o PancakePeak.rbxl` / `rojo serve`).
2. **Play** solo. Check, in this order:
   - You spawn at Base Camp, a snowy plaza with cabins above a sea of clouds, carrying a wooden tray
     over your head. The yellow tip banner tells you to press **FLIP!**.
   - A pancake slides back and forth over your tray. Press **E**, click anywhere in the world, or
     the big FLIP button (bottom right): it drops. Over the center it says **PERFECT!** and keeps
     its size; off-center, the overhang is sliced off and falls away, so the next pancake is
     smaller. Each drop plays a note a little higher than the last.
   - Three perfects in a row say "PERFECT x3" and start growing the pancake back.
   - Drop way off the edge until the pancake gets tiny: the tower topples ("TOPPLE!", crumbs).
   - Walk up the trail to **Maple Meadow**. Each of the three Yetis has a sign with the height it
     craves right now ("Craving 7–11 tall"). Stand at a table and press **F** or SERVE: the
     pancakes fly into the Yeti's mouth and you get Maple. Serving inside the craving window says
     "CRAVING ×2!".
   - Buy **Fluffy Batter** from ⚡ Upgrades, walk to the frying pan with the speckled **Maple Egg**,
     press **R** and hatch it: the egg wobbles, cracks, and the Nibbler hops along behind you.
   - Open every menu on the HUD; each one opens with a spring and closes with ✕ (or Backspace /
     gamepad B).
3. **Test → Clients and Servers** with 2–3 players: everyone sees every tower (and how it leans as
   its owner runs), serving near another active chef gives them a small "tip", and each player's
   Nibblers follow them. In the Store use **Summon the Great Yeti** (or wait 3 minutes): a huge
   Yeti in a chef's hat thumps down in the busiest zone's plaza. Serve it together until the bar
   fills: everyone who helped gets a reward and the whole server gets a **Snow Day** (×2 Maple,
   slower pancakes, heavy snowfall).
4. **Device emulator** (Test tab → Device): try a small phone (e.g. iPhone SE) and a tablet. On
   touch screens FLIP and SERVE sit left of the jump button; check they don't overlap on your
   device, and that tapping the world also flips.
5. With a gamepad: R2 flips, X serves, Y uses the prompt you stand at (egg, gate), L1 Nibblers,
   R1 Yeti Feast, D-pad up/left/right/down for Upgrades / Travel / Store / Daily, B closes, and menu
   buttons are selectable with the stick.

Tip: set `StudioOwnsAllPasses = true` in `src/shared/Config/Game.luau` to try every game pass in
Studio (Auto Serve is the fun one to see). It never applies on live servers, but set it back to
`false` before publishing anyway.

## 2. Publish and enable data (required, 10 min)

1. **File → Publish to Roblox** as a new experience.
2. **Game Settings → Security → Enable Studio Access to API Services** (so Studio saves too).
   Without it the game runs in offline mode and shows a "progress won't save" banner.
3. **Game Settings → Places → Max Players:** 20 is recommended (zones feel best with 3–5 chefs,
   which is when tips and the Great Yeti shine).
4. Play once with API access on, serve a few towers, leave and rejoin: your Maple and Nibblers
   should still be there.

## 3. Create game passes and developer products (required for revenue, 30 min)

On the Creator Dashboard → your experience → **Monetization**. Create each item, then paste its
ID into `src/shared/Config/Monetization.luau` (replace the `id = 0`). An ID of 0 shows the item as
"isn't on sale yet" in the store and never errors, so you can launch with some items unset.

Game passes (suggested prices; change them in the Dashboard and in the config's `price` field):

| Config key | Name | Price (R$) | What it does |
|---|---|---|---|
| `DoubleMaple` | 2x Maple | 299 | ×2 all Maple |
| `AutoServe` | Auto Serve | 299 | A full tray is served to your best zone's Yetis by itself |
| `SteadySpatula` | Steady Spatula | 199 | +50% PERFECT window |
| `ExtraPockets` | Extra Pockets | 349 | +3 Nibbler slots |
| `LuckyYolk` | Lucky Yolk | 249 | Better rare odds (shown in the egg window) |
| `TripleHatch` | Triple Hatch | 199 | Hatch 3 eggs at once |
| `FastHatch` | Fast Hatch | 99 | Faster egg reveal and cooldown |

Developer products:

| Config key | Name | Price (R$) | Grant |
|---|---|---|---|
| `MaplePouch` | Maple Pouch | 25 | 10 min of current income (min 500) |
| `MapleJar` | Maple Jar | 99 | 60 min of income (min 4K) |
| `MapleBarrel` | Maple Barrel | 349 | 300 min of income (min 25K) |
| `Boost2x` | 2x Maple (15 min) | 39 | Stacks up to 6 h |
| `BoostLucky` | Lucky Boost (15 min) | 39 | Stacks up to 6 h |
| `SummonYeti` | Summon the Great Yeti | 79 | Starts a Great Yeti's Order for the whole server |

Each item needs a **512×512 icon** (only for the Roblox purchase prompt and the Store tab of the
experience page; the in-game store draws its own icons).

After pasting IDs: rebuild, publish, and buy one product in Studio (Studio purchases are free test
purchases) to confirm the grant arrives.

## 4. Experience page (required, 45 min)

- **Icon** (512×512) and at least 3 **thumbnails** (1920×1080). Good shots: a chef with a
  wobbling 30-pancake tower leaning as they run past pine trees; a Yeti opening wide as a stream of
  pancakes flies into its mouth with "CRAVING ×2!"; a crowd around the Great Yeti in its chef's hat
  under falling snow. Hide the HUD for clean shots and keep Performance mode off.
- **Title:** "Pancake Peak". **Description** suggestion:
  "Flip pancakes onto a tray over your head and stack them sky-high! Drop each one right on top
  for a PERFECT, or the overhang gets sliced off. Feed your tower to hungry Yetis, hit their
  craving height for double Maple, climb five snowy zones, hatch Mystery Eggs for cute Nibbler
  buddies, and team up to feed the Great Yeti for a server-wide Snow Day!"
- **Genre:** Simulator. **Maturity questionnaire:** no violence, blood or real-value gambling;
  it should rate *Minimal*. Eggs are bought with in-game Maple only and their odds are shown;
  answer "paid random items: No".

## 5. Optional polish

- **Music:** upload or license two loops (a cozy cabin theme and a jingly Snow Day theme) and put
  their `rbxassetid://` ids in `Config/Assets.luau` → `Music`. Empty = no music.
- **Sounds:** the defaults are Roblox's built-in sounds. Replace entries in `Config/Assets.luau` →
  `Sounds` with Creator Store sounds. The biggest wins are a soft "plop" for `Drop` (it is pitched
  up with tower height, like a xylophone), a bright "ding" for `Perfect`, and a happy "nom" for
  `Chomp`.
- **Textures:** `Images.Snowflake`, `Images.Crumb` and `Images.Steam` in `Config/Assets.luau`
  replace the default sparkle and smoke textures.
- **Nibbler meshes:** add entries to `MESH_IDS` near the top of `Config/Nibblers.luau`
  (`Pip = "rbxassetid://…"`). Species without an entry keep the code-built look.
  Author meshes about 1 stud across; they're scaled by the species' `look.size`.
- **Codes:** edit `Config/Rewards.luau` → `Codes` before launch. `LAUNCH`, `FLIPFLIP` and `YETI`
  never expire; `SYRUP` expires 2028-01-01.

## 6. Launch checklist

- [ ] All monetization IDs set (or deliberately left at 0)
- [ ] `StudioOwnsAllPasses = false`
- [ ] API access enabled; rejoin keeps progress
- [ ] Icon, thumbnails, description, maturity questionnaire
- [ ] Multi-client and mobile emulator playtest done
- [ ] Bump `DataStoreName` in `Config/Game.luau` only if you want to wipe test progress before
      launch (`PancakePeak_Player_v1` → `_v2`). Never change it after launch.
