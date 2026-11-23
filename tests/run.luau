-- Runs every tests/*.spec.luau file. Usage (from the project root): lune run tests/run
local fs = require("@lune/fs")
local process = require("@lune/process")
local T = require("./T")

local filter = process.args[1]
local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") and (not filter or string.find(name, filter, 1, true)) then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	local before = T.passed + T.failed
	local spec = require("./" .. string.gsub(name, "%.luau$", ""))
	local ok, err = pcall(spec, T)
	if not ok then
		T.failed += 1
		table.insert(T.failures, name .. " crashed:\n    " .. tostring(err))
	end
	print(string.format("  %-28s %d tests", name, T.passed + T.failed - before))
end

print(string.format("\n%d passed, %d failed", T.passed, T.failed))
for _, f in T.failures do
	print("FAIL " .. f)
end
process.exit(if T.failed > 0 then 1 else 0)
