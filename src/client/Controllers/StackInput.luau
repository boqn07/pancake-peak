--!strict
-- How players flip and serve. FLIP drops the sliding pancake: the HUD FLIP button, a click or tap
-- anywhere in the world, E, or gamepad R2/A-less R2. SERVE hands your tower to the Yeti you're
-- standing at (or the Great Yeti): the HUD SERVE button, F, gamepad X, or the plate's prompt.
-- The client only sends "drop at server time t" (predicted locally for instant feel) and "serve";
-- the server checks timing, reach, ownership and pays.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Zones = require(Config:WaitForChild("Zones"))
local Cfg = require(Config:WaitForChild("Stack"))
local OrderCfg = require(Config:WaitForChild("Order"))
local Stack = require(Shared:WaitForChild("Logic"):WaitForChild("Stack"))
local ZoneGeo = require(Shared:WaitForChild("Logic"):WaitForChild("ZoneGeo"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local StackInput = {}
-- Fires (target) when the serve target changes: nil, or { zone, index ("great" or 1..3), lo, hi }.
StackInput.TargetChanged = Signal.new()
-- (result) after the server paid us (a serve, a tip from a nearby chef, or topple crumbs).
StackInput.Result = Signal.new()

export type Target = { zone: string, index: any, lo: number, hi: number }

local C: any
local me = Players.LocalPlayer
local lastDrop = 0
local lastServe = 0
local target: Target? = nil
local lastFullNote = 0

local function root(): BasePart?
	local c = me.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Same rules as StackService:ServeTarget, for the HUD (the server decides for real).
local function findTarget(): Target?
	local r = root()
	if not r then
		return nil
	end
	local pos = r.CFrame.Position
	local zoneId = C.WorldFX:CurrentZone()
	local zone = Zones.ById[zoneId]
	if not zone or not C.State:Owns(zoneId) then
		return nil
	end
	local o = C.State.order
	if o.active and o.zone == zoneId then
		local dx, dz = pos.X - o.x, pos.Z - o.z
		if dx * dx + dz * dz <= (OrderCfg.ServeReach - 1) ^ 2 then
			return { zone = zoneId, index = "great", lo = 0, hi = 0 }
		end
	end
	local y, d = ZoneGeo.nearestYeti(zoneId, pos.X, pos.Z)
	if d <= Cfg.ServeDistance - 1 then
		local lo, hi = Stack.craving(zone.order, y.index, workspace:GetServerTimeNow())
		return { zone = zoneId, index = y.index, lo = lo, hi = hi }
	end
	return nil
end

-- Drop the sliding pancake now.
function StackInput:Flip(): boolean
	local clock = os.clock()
	if clock - lastDrop < Cfg.MinDropInterval then
		return false
	end
	if not root() then
		return false
	end
	local count = C.StackRenderer:MyCount()
	if count >= (C.State.derived.tray or 15) then
		if clock - lastFullNote > 1.5 then
			lastFullNote = clock
			C.UIRoot:Toast("Your tray is full! Serve it to a Yeti 🍽️", "info")
		end
		return false
	end
	local t = workspace:GetServerTimeNow()
	local kind = C.StackRenderer:PredictDrop(t)
	if not kind then
		return false
	end
	lastDrop = clock
	C.ClientNet:Fire("Drop", t)
	return true
end

-- Serve the tower to the Yeti we're at.
function StackInput:Serve(): boolean
	local clock = os.clock()
	if clock - lastServe < Cfg.ServeCooldown then
		return false
	end
	if C.StackRenderer:MyCount() == 0 then
		C.UIRoot:Toast("Stack some pancakes first! Press FLIP 🥞", "info")
		return false
	end
	if not target then
		C.UIRoot:Toast("Walk up to a Yeti's table to serve 🍽️", "info")
		return false
	end
	lastServe = clock
	C.ClientNet:Fire("Serve")
	return true
end

function StackInput:Target(): Target?
	return target
end

-- Short HUD text for the current target, e.g. "Craving 12–16 · you have 9".
function StackInput:TargetText(): string
	local t = target
	if not t then
		return ""
	end
	local n = C.StackRenderer:MyCount()
	if t.index == "great" then
		return "The Great Yeti is hungry!"
	end
	if Stack.inCraving(n, t.lo, t.hi) then
		return string.format("Craving %d–%d · YUM! ×2", t.lo, t.hi)
	end
	return string.format("Craving %d–%d · you have %d", t.lo, t.hi, n)
end

function StackInput:Init(controllers)
	C = controllers
end

local function overGui(pos: Vector2): boolean
	local gui = me:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return false
	end
	for _, o in gui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if o.Visible and (o:IsA("GuiButton") or o.BackgroundTransparency < 1) then
			return true
		end
	end
	return false
end

function StackInput:Start()
	-- Click (mouse) and tap (touch) in the world flip.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not overGui(Vector2.new(input.Position.X, input.Position.Y)) then
				self:Flip()
			end
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(_pos, processed)
		if not processed then
			self:Flip()
		end
	end)

	ContextActionService:BindAction("PeakFlip", function(_, state)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			self:Flip()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("PeakServe", function(_, state)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			self:Serve()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	C.ClientNet:On("ServeResult", function(res)
		local r = root()
		local fallback = if r then r.CFrame.Position else Vector3.zero
		if res.topple then
			C.Effects:PopMaple(fallback + Vector3.new(0, 6, 0), res.amount, Color3.fromHex("#C9C2B5"), 0.8)
			C.Effects:Pop(fallback + Vector3.new(0, 9, 0), "crumbs...", Color3.fromHex("#FFFFFF"), 0.8)
		elseif res.tip then
			local pos = if r then fallback + Vector3.new(0, 7, 0) else Vector3.new(res.x, res.y + 6, res.z)
			C.Effects:PopMaple(pos, res.amount, Color3.fromHex("#BFEFFF"), 0.8)
			C.Effects:Pop(pos + Vector3.new(0, 2, 0), "Tip from " .. tostring(res.from), Color3.fromHex("#FFFFFF"), 0.7)
		else
			local pos = Vector3.new(res.x or fallback.X, (res.y or fallback.Y) + 10, res.z or fallback.Z)
			if res.auto then
				pos = fallback + Vector3.new(0, 8, 0)
			end
			local n = res.n or 1
			C.Effects:PopMaple(pos, res.amount, nil, math.min(1 + n / 30, 2.2))
			C.Audio:Play("Serve", { pitch = 1 + math.min(n, 30) * 0.01 })
			if res.craving then
				C.Effects:Pop(pos + Vector3.new(0, 3, 0), "CRAVING ×2!", Color3.fromHex("#FFE27A"), 1.4, 8)
				C.Audio:Play("Craving")
			end
			if n >= 15 then
				C.Effects:Word(pos + Vector3.new(0, 5, 0), math.min(1 + n / 40, 2))
				C.Effects:Punch(math.min(n / 50, 0.7))
			end
			if n >= 30 then
				C.LightingFX:Flash(0.35)
			end
		end
		StackInput.Result:Fire(res)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		local t = findTarget()
		local changed = (t == nil) ~= (target == nil)
			or (t and target and (t.index ~= target.index or t.zone ~= target.zone or t.lo ~= target.lo))
		target = t
		if changed then
			StackInput.TargetChanged:Fire(t)
		end
	end)
end

-- "🍁 1.2K" estimate for serving the current tower at the current target (HUD).
function StackInput:ValueText(): string
	local st = C.StackRenderer:MyState()
	if not st or #st.layers == 0 then
		return ""
	end
	local zoneId = if target then target.zone else C.WorldFX:CurrentZone()
	local zone = Zones.ById[zoneId] or Zones.List[1]
	local craving = target ~= nil and target.index ~= "great" and Stack.inCraving(#st.layers, target.lo, target.hi)
	local d = C.State.derived
	local mult = (d.mult and d.mult.total) or 1
	local v = Stack.value(st, zone.value, d.towerK or Cfg.TowerK, craving) * mult
	return "🍁 " .. Format.abbreviate(v)
end

return StackInput
