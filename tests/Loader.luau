-- Loads Roblox-style ModuleScripts from the Rojo source tree under Lune, so pure modules can be
-- tested unchanged. It fakes just enough of the Instance tree: `script`, `.Parent`, child indexing,
-- FindFirstChild/WaitForChild, and `require(instance)`.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Loader = {}

local ROOTS = {
	Shared = "src/shared",
	Server = "src/server",
	Client = "src/client",
}

-- Read the whole source tree up front: Lune's fs calls can yield, and yielding is not allowed
-- inside the __index metamethods used below.
local files: { [string]: string } = {}
local dirs: { [string]: boolean } = {}
local function scan(dir: string)
	dirs[dir] = true
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		elseif string.match(name, "%.luau?$") then
			files[path] = fs.readFile(path)
		end
	end
end
for _, path in ROOTS do
	scan(path)
end

local cache: { [string]: any } = {}
local loading: { [string]: boolean } = {}
local nodes: { [string]: any } = {}

local makeNode

local function childOf(node: any, name: string): any?
	local base = rawget(node, "__path")
	for _, ext in { ".luau", ".lua" } do
		local file = base .. "/" .. name .. ext
		if files[file] then
			return makeNode(file, name, node, false)
		end
	end
	local dir = base .. "/" .. name
	if dirs[dir] then
		return makeNode(dir, name, node, true)
	end
	return nil
end

local NodeMeta = {}
NodeMeta.__index = function(node, key)
	if key == "Parent" then
		return rawget(node, "__parent")
	elseif key == "Name" then
		return rawget(node, "__name")
	elseif key == "FindFirstChild" or key == "WaitForChild" then
		return function(self, name)
			return childOf(self, name)
		end
	end
	if rawget(node, "__isDir") then
		local child = childOf(node, key)
		if child then
			return child
		end
	end
	error(string.format("%s is not a valid member of %s", tostring(key), rawget(node, "__path")), 2)
end
NodeMeta.__tostring = function(node)
	return rawget(node, "__path")
end

function makeNode(path: string, name: string, parent: any, isDir: boolean)
	if nodes[path] then
		return nodes[path]
	end
	local node = setmetatable({ __path = path, __name = name, __parent = parent, __isDir = isDir }, NodeMeta)
	nodes[path] = node
	return node
end

local function moduleFile(node: any): string
	local path = rawget(node, "__path")
	if rawget(node, "__isDir") then
		for _, f in { "/init.luau", "/init.lua" } do
			if files[path .. f] then
				return path .. f
			end
		end
		error("folder is not a module: " .. path)
	end
	return path
end

local function requireNode(node: any): any
	if type(node) == "string" then
		return require(node)
	end
	local file = moduleFile(node)
	if cache[file] ~= nil then
		return cache[file]
	end
	if loading[file] then
		error("cyclic require: " .. file)
	end
	loading[file] = true
	local source = files[file]
	-- selene: allow(global_usage)
	local env = setmetatable({ script = node, require = requireNode, game = Loader.game }, { __index = _G })
	local fn = luau.load(source, { debugName = file, environment = env })
	local result = fn()
	loading[file] = nil
	cache[file] = result
	return result
end

-- A virtual "game" root: Loader.root.Shared.Logic.Format etc.
local game = setmetatable({ __path = ".", __name = "game", __isDir = false }, NodeMeta)
Loader.root = {}
for name, path in ROOTS do
	Loader.root[name] = makeNode(path, name, game, true)
end

Loader.require = requireNode

-- Minimal `game` so modules can call game:GetService("ReplicatedStorage").Shared etc.
local SERVICES = { ReplicatedStorage = "Shared", ServerScriptService = "Server", StarterPlayerScripts = "Client" }
Loader.game = {
	GetService = function(_, name: string)
		local rootName = SERVICES[name]
		if not rootName then
			error("service not available in tests: " .. name)
		end
		return { [rootName] = Loader.root[rootName] }
	end,
}

-- Convenience: Loader.get("Shared/Logic/Format")
function Loader.get(path: string): any
	local parts = string.split(path, "/")
	local node = Loader.root[parts[1]]
	for i = 2, #parts do
		node = node[parts[i]]
	end
	return requireNode(node)
end

return Loader
