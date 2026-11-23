-- Compiles every .luau file under src/, tests/ and tools/ to catch syntax errors.
-- Usage: lune run tools/compile-check
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local count = 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("FAIL " .. path .. "\n  " .. tostring(err))
			end
		end
	end
end
for _, d in { "src", "tests", "tools" } do
	walk(d)
end
print(string.format("%d files compiled, %d failed", count, failures))
process.exit(if failures > 0 then 1 else 0)
