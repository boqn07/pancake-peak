-- Prints the modelled progression timeline. Usage: lune run tools/pacing [minutes] [pass,pass] [traceSeconds] [seed]
local process = require("@lune/process")
local Sim = require("../tests/PacingSim")
local L = require("../tests/Loader")
local Format = L.get("Shared/Logic/Format")
local Economy = L.get("Shared/Logic/Economy")

local minutes = tonumber(process.args[1]) or 240
local passes = {}
for p in string.gmatch(process.args[2] or "", "[^,]+") do
	passes[p] = true
end
local m, profile, log, stats =
	Sim.run(minutes * 60, { passes = passes, trace = tonumber(process.args[3]), seed = tonumber(process.args[4]) })
print(
	string.format(
		"first drop: %ss   first serve: %ss   first upgrade: %ss   first egg: %ss",
		tostring(m.firstDrop),
		tostring(m.firstServe),
		tostring(m.firstUpgrade),
		tostring(m.firstEgg)
	)
)
for _, line in log do
	print(line)
end
local ctx = { passes = passes, friends = 0, snowDay = false }
print(
	string.format(
		"after %d min: %s Maple, %d feasts, x%s multiplier, %d serves, avg height %.1f, %d%% perfect, %d topples, %d cravings",
		minutes,
		Format.abbreviate(profile.maple),
		profile.rebirths,
		Format.abbreviate(Economy.multipliers(profile, ctx).total),
		stats.serves,
		stats.avgHeight,
		math.floor(100 * stats.perfects / math.max(1, stats.pancakes)),
		stats.topples,
		stats.cravings
	)
)
local lv = {}
for k, v in profile.upgrades do
	table.insert(lv, k .. "=" .. v)
end
print("upgrades: " .. table.concat(lv, " "))
