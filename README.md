# Pancake Peak

A cozy snowy-mountain stacking simulator for Roblox. You're a tiny chef with a tray over your
head. A pancake slides back and forth above it: **FLIP** to drop it. Land it right on top for a
**PERFECT**; miss and the overhang is sliced off, so the next one is smaller. Stack as high as you
dare, then **SERVE** the tower to a hungry Yeti: tall towers pay a growing bonus, and every Yeti
pays double for the height it's craving right now. Spend **Maple** on upgrades, climb five zones,
hatch **Mystery Eggs** for **Nibblers** (mountain critters that hop along behind you), and team up
to feed the **Great Yeti** for a server-wide Snow Day.

Everything is code: the mountain, lighting, towers, Yetis, critters, UI and effects are built at
runtime from config, so the project needs no uploaded assets to run.

## Quick start

1. Install [Rojo](https://rojo.space) 7.x (and the Rojo Studio plugin), or use Aftman/Rokit.
2. Build a place file and open it:
   ```
   rojo build -o PancakePeak.rbxl
   ```
   Or live-sync into an open Studio place: `rojo serve`, then Connect in the Rojo plugin.
3. Press **Play**. Without "Studio Access to API Services" the game runs in offline mode (a banner
   says progress isn't saved); everything else works.
4. Before publishing, follow [`docs/HUMAN_TASKS.md`](docs/HUMAN_TASKS.md).

## Developer tools

| Command | What it does |
|---|---|
| `lune run tests/run` | All tests (unit, pacing, data safety, headless end-to-end smoke test) |
| `lune run tests/run smoke` | Only specs whose file name contains `smoke` |
| `selene src` | Lint (`selene.toml`; run `selene generate-roblox-std` once first to create `roblox.yml`) |
| `stylua src tests tools` | Format (`stylua.toml`; StyLua must be built with Luau support) |
| `lune run tools/pacing 240` | Prints the progression timeline of a modelled player over 240 minutes |
| `lune run tools/pacing 240 DoubleMaple` | The same, for a player who owns the 2x Maple pass |
| `lune run tools/pacing-medians` | Median milestones over 8 seeds (what the pacing test checks) |
| `lune run tools/compile-check` | Compiles every source file with the Luau compiler |
| `lune run tools/inspect-place` | Prints the script tree of `build/PancakePeak.rbxl` (build it with `rojo build -o build/PancakePeak.rbxl` first) |

Tool versions used: Rojo 7.7, Lune 0.11, Selene 0.31, StyLua 2.6.

## Layout

```
default.project.json   Rojo tree + Lighting / Workspace / StarterPlayer properties
src/shared/            ReplicatedStorage.Shared
  Config/              every tunable number, id and asset reference
  Logic/               pure game rules (no Roblox services), unit-tested
  Net.luau             remote contract and per-remote rate limits
src/server/            ServerScriptService.Server: services, data layer, mountain builder
src/client/            StarterPlayerScripts.Client: controllers (rendering, input, effects) and UI
tests/                 Lune specs, pacing model, headless Roblox environment
tools/                 dev scripts
docs/                  design and handoff documents
```

## Documents

- [`docs/GDD.md`](docs/GDD.md): game design
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): structure, client/server split, remote contract, data safety
- [`docs/HUMAN_TASKS.md`](docs/HUMAN_TASKS.md): what you need to do in Studio / on the Creator Dashboard
- [`docs/BALANCING.md`](docs/BALANCING.md): how to tune the economy safely
- [`docs/LIVEOPS.md`](docs/LIVEOPS.md): codes, events and the update roadmap
- [`docs/PROGRESS.md`](docs/PROGRESS.md): build log, known limitations and deferred features
- [`docs/RESEARCH.md`](docs/RESEARCH.md): market research behind the design
