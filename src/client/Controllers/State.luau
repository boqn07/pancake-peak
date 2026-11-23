--!strict
-- Read-only mirror of the player's profile plus server-derived values.
-- State.Changed fires with a set of changed keys; UI subscribes and redraws what it needs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local State = {}
State.data = {} :: any
State.derived = {} :: any
State.loaded = false
State.Changed = Signal.new() -- ({ [key]: true })
State.Loaded = Signal.new()
-- The current Great Yeti's Order as the server last described it ({ active = false } when none).
State.order = { active = false, snowEndsAt = 0 } :: any
State.OrderChanged = Signal.new()

local C: any

function State:Init(controllers)
	C = controllers
end

function State:Start()
	C.ClientNet:On("State", function(payload)
		local keys = {}
		for k, v in payload do
			if k == "derived" then
				State.derived = v
			else
				State.data[k] = v
			end
			keys[k] = true
		end
		if not State.loaded and payload.version then
			State.loaded = true
			State.Loaded:Fire()
		end
		State.Changed:Fire(keys)
	end)
	C.ClientNet:On("Order", function(order)
		State.order = order
		State.OrderChanged:Fire(order)
	end)
end

-- Run `fn` now if loaded, otherwise once loaded.
function State:OnLoaded(fn: () -> ())
	if State.loaded then
		task.spawn(fn)
	else
		State.Loaded:Once(fn)
	end
end

function State:Setting(key: string): boolean
	local s = State.data.settings
	if not s then
		return key ~= "performance"
	end
	return s[key] == true
end

-- True while the whole server has a Snow Day (after a filled Great Yeti's Order).
function State:SnowDay(): boolean
	return workspace:GetServerTimeNow() < (State.order.snowEndsAt or 0)
end

-- Does the player own this zone?
function State:Owns(zoneId: string): boolean
	local zones = State.data.zones
	return zones ~= nil and zones[zoneId] == true
end

return State
