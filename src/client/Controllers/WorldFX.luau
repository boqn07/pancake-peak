--!strict
-- Living-world touches on top of the server-built map: ice gates melt away for zones you own (and
-- are solid for your character while locked), every Yeti's craving sign shows the live height
-- window (deterministic from the shared server clock, so no replication is needed), Yetis breathe
-- and wave, Mystery Eggs wobble in their pans, snow drifts around the camera, and ZoneChanged fires
-- as you walk into a new zone (the HUD shows a banner).
-- Works with StreamingEnabled: everything is (re)applied as map parts stream in.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local ZoneGeo = require(Shared:WaitForChild("Logic"):WaitForChild("ZoneGeo"))
local Stack = require(Shared:WaitForChild("Logic"):WaitForChild("Stack"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets"))

local WorldFX = {}
WorldFX.ZoneChanged = Signal.new() -- (zoneId or "BaseCamp")

local C: any
local hex = Color3.fromHex
local me = Players.LocalPlayer
local HUB = "BaseCamp"

type Sign = { folder: Instance, label: TextLabel?, order: number, index: number, lastText: string }
type Yeti = { model: Model, base: CFrame, phase: number }
type Egg = { part: BasePart, base: CFrame, phase: number }

local signs: { Sign } = {}
local yetis: { [Model]: Yeti } = {}
local eggs: { [BasePart]: Egg } = {}
local snow: ParticleEmitter
local snowAnchor: Part
local current = ""
local snowDay = false

-- Show or hide one gate folder's parts for the local player.
local function refreshGate(gate: Instance)
	local zoneId = gate:GetAttribute("ZoneId")
	if type(zoneId) ~= "string" then
		return
	end
	local open = C.State:Owns(zoneId)
	for _, d in gate:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Sheet" then
				d.Transparency = if open then 1 else 0.3
				-- Solid for your own character while locked (the server enforces it anyway).
				d.CanCollide = not open
			else
				d.Transparency = if open then 1 else 0
				d.CanCollide = if open then false else d.CanCollide
			end
		elseif d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d.Enabled = not open
		end
	end
end

local function refreshAllGates()
	local map = workspace:FindFirstChild("Map")
	local gates = map and map:FindFirstChild("Gates")
	if gates then
		for _, g in gates:GetChildren() do
			refreshGate(g)
		end
	end
end

local function addSign(folder: Instance)
	for _, s in signs do
		if s.folder == folder then
			return
		end
	end
	local order = folder:GetAttribute("ZoneOrder")
	local index = folder:GetAttribute("YetiIndex")
	if type(order) ~= "number" or type(index) ~= "number" then
		return
	end
	table.insert(signs, { folder = folder, label = nil, order = order, index = index, lastText = "" })
end

local function onMapPart(d: Instance)
	if d:IsA("Folder") and d.Name:sub(1, 5) == "Yeti_" then
		addSign(d)
	elseif d:IsA("Model") and d.Name == "Yeti" then
		yetis[d] = { model = d, base = d:GetPivot(), phase = math.random() * 6 }
	elseif d.Name == "Egg" and d:IsA("BasePart") then
		eggs[d] = { part = d, base = d.CFrame, phase = math.random() * 6 }
	end
	-- A gate part streamed in: re-apply its state.
	local gate = d:FindFirstAncestorWhichIsA("Folder")
	if gate and gate:GetAttribute("ZoneId") ~= nil and gate.Parent and gate.Parent.Name == "Gates" then
		refreshGate(gate)
	end
end

-- The tray height the local player is carrying (0 when the renderer is not up yet).
local function myHeight(): number
	local r = C.StackRenderer
	return if r and r.MyCount then r:MyCount() else 0
end

local function updateSigns(now: number)
	local mine = myHeight()
	local left = Stack.cravingEndsAt(now) - now
	for i = #signs, 1, -1 do
		local s = signs[i]
		if not s.folder.Parent then
			table.remove(signs, i)
			continue
		end
		if not s.label or not s.label.Parent then
			local gui = s.folder:FindFirstChild("CravingSign", true)
			s.label = gui and gui:FindFirstChild("Text", true) :: TextLabel?
			if not s.label then
				continue
			end
		end
		local lo, hi = Stack.craving(s.order, s.index, now)
		local happy = Stack.inCraving(mine, lo, hi)
		local text = string.format("Craving %d–%d tall\n×2 Maple · %s", lo, hi, Format.clock(left))
		if happy then
			text = "YUM! Your stack fits!\n" .. string.format("%d–%d tall · ×2", lo, hi)
		end
		if text ~= s.lastText then
			s.lastText = text
			local label = s.label :: TextLabel
			label.Text = text
			label.TextColor3 = if happy then hex("#FFE27A") else hex("#FFFFFF")
		end
	end
end

local function animate(t: number)
	for m, y in yetis do
		if not m.Parent then
			yetis[m] = nil
			continue
		end
		local breathe = math.sin(t * 1.6 + y.phase)
		m:PivotTo(y.base * CFrame.new(0, breathe * 0.12, 0) * CFrame.Angles(0, math.sin(t * 0.4 + y.phase) * 0.06, 0))
	end
	for p, e in eggs do
		if not p.Parent then
			eggs[p] = nil
			continue
		end
		local wob = math.sin(t * 2.2 + e.phase)
		-- Every few seconds the egg gives a little hop, as if something inside is impatient.
		local hop = math.max(0, math.sin(t * 0.9 + e.phase) - 0.92) * 6
		p.CFrame = e.base * CFrame.new(0, hop, 0) * CFrame.Angles(wob * 0.06, 0, wob * 0.08)
	end
end

function WorldFX:Init(controllers)
	C = controllers
	-- Light snowfall that follows the camera (heavier on a Snow Day).
	snowAnchor = Instance.new("Part")
	snowAnchor.Name = "Snowfall"
	snowAnchor.Anchored = true
	snowAnchor.CanCollide = false
	snowAnchor.CanQuery = false
	snowAnchor.CanTouch = false
	snowAnchor.Transparency = 1
	snowAnchor.Size = Vector3.new(120, 0.2, 120)
	local e = Instance.new("ParticleEmitter")
	e.Texture = if Assets.Images.Snowflake ~= ""
		then Assets.Images.Snowflake
		else "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(hex("#FFFFFF"))
	e.LightEmission = 0.4
	e.LightInfluence = 0.6
	e.Rate = 25
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(4, 6)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(1.5, 0, 0.5)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = snowAnchor
	snow = e
	snowAnchor.Parent = workspace
end

local function refreshSnow()
	snow.Enabled = not C.State:Setting("performance")
	snow.Rate = if snowDay then 90 else 25
end

function WorldFX:Start()
	local map = workspace:WaitForChild("Map")
	map.DescendantAdded:Connect(onMapPart)
	for _, d in map:GetDescendants() do
		onMapPart(d)
	end
	C.State.Changed:Connect(function(keys)
		if keys.zones then
			refreshAllGates()
		end
		if keys.settings then
			refreshSnow()
		end
	end)
	C.State:OnLoaded(function()
		refreshAllGates()
		refreshSnow()
	end)
	C.State.OrderChanged:Connect(function()
		local s = C.State:SnowDay()
		if s ~= snowDay then
			snowDay = s
			refreshSnow()
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local performance = C.State:Setting("performance")
		if not performance then
			animate(os.clock())
		end
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local s = C.State:SnowDay()
		if s ~= snowDay then
			snowDay = s
			refreshSnow()
		end
		updateSigns(workspace:GetServerTimeNow())
		local c = me.Character
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		local p = if root then root.CFrame.Position elseif camera then camera.CFrame.Position else Vector3.zero
		snowAnchor.CFrame = CFrame.new(p.X, p.Y + 40, p.Z)
		if root then
			local id = ZoneGeo.zoneAt(p.X, p.Y, p.Z) or HUB
			if id ~= current then
				current = id
				WorldFX.ZoneChanged:Fire(id)
			end
		end
	end)
end

-- The zone the local player is in ("BaseCamp" anywhere else).
function WorldFX:CurrentZone(): string
	return if current == "" then HUB else current
end

-- Display name for a zone id or "BaseCamp".
function WorldFX:ZoneName(id: string): string
	local r = Zones.ById[id]
	return if r then r.name else "Base Camp"
end

return WorldFX
