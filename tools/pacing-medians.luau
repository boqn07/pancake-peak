-- Prints median milestones (minutes) over 8 seeds. Usage: lune run tools/pacing-medians [pass,pass]
local process = require("@lune/process")
local Sim = require("../tests/PacingSim")
local passes = {}
for p in string.gmatch(process.args[1] or "", "[^,]+") do
	passes[p] = true
end
local keys = {
	"firstServe",
	"firstUpgrade",
	"firstEgg",
	"PineconeVillage",
	"FrostyFalls",
	"CocoaCliffs",
	"AuroraSummit",
	"feast",
}
local acc = {}
for _, k in keys do
	acc[k] = {}
end
for seed = 1, 8 do
	local m = Sim.run(180 * 60, { seed = seed, passes = passes })
	table.insert(acc.firstServe, (m.firstServe or math.huge) / 60)
	table.insert(acc.firstUpgrade, (m.firstUpgrade or math.huge) / 60)
	table.insert(acc.firstEgg, (m.firstEgg or math.huge) / 60)
	for _, z in { "PineconeVillage", "FrostyFalls", "CocoaCliffs", "AuroraSummit" } do
		table.insert(acc[z], (m.zones[z] or math.huge) / 60)
	end
	table.insert(acc.feast, (m.rebirths[1] or math.huge) / 60)
end
for _, k in keys do
	local l = acc[k]
	table.sort(l)
	local parts = {}
	for _, v in l do
		table.insert(parts, string.format("%.1f", v))
	end
	print(string.format("%-16s median %6.1f   [%s]", k, (l[4] + l[5]) / 2, table.concat(parts, " ")))
end
