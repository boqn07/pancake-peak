--!strict
-- Feedback toolkit: floating numbers, crumb bursts, snow puffs, comic "FLIP!" words and a camera
-- punch. Everything is pooled.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets"))

local Effects = {}

local C: any
local hex = Color3.fromHex
local WHITE = hex("#FFFFFF")
local INK = hex("#24406B")
local MAPLE = hex("#FFC24A")

local folder: Folder
local popPool: { BillboardGui } = {}
local popActive = 0
local sprayPool: { Part } = {}
local foamPool: { Part } = {}
local MAX_POPS = 28
local MAX_SPRAYS = 24
local MAX_FOAMS = 10

-- Camera punch state
local shake = 0
local fovKick = 0
local baseFov = 70

local function anchorPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Parent = folder
	return p
end

local function newPop(): BillboardGui
	local anchor = anchorPart()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 56)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Adornee = anchor
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = label
	gui.Parent = folder
	return gui
end

-- Crumbs: little bits that fly out and fall.
local function newSpray(): Part
	local p = anchorPart()
	local e = Instance.new("ParticleEmitter")
	e.Name = "E"
	e.Enabled = false
	e.Texture = if Assets.Images.Crumb ~= ""
		then Assets.Images.Crumb
		else "rbxasset://textures/particles/sparkles_main.dds"
	e.LightEmission = 0.35
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(8, 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Drag = 2
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return p
end

-- Soft snow puffs (landings, stomps, the Great Yeti).
local function newFoam(): Part
	local p = anchorPart()
	local e = Instance.new("ParticleEmitter")
	e.Name = "E"
	e.Enabled = false
	e.Texture = if Assets.Images.Steam ~= ""
		then Assets.Images.Steam
		else "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(hex("#F7FAFF"))
	e.LightEmission = 0.1
	e.LightInfluence = 1
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(4, 10)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Drag = 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return p
end

function Effects:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace
	for _ = 1, MAX_POPS do
		table.insert(popPool, newPop())
	end
	for _ = 1, MAX_SPRAYS do
		table.insert(sprayPool, newSpray())
	end
	for _ = 1, MAX_FOAMS do
		table.insert(foamPool, newFoam())
	end
end

function Effects:Start()
	local camera = workspace.CurrentCamera
	baseFov = camera.FieldOfView
	RunService:BindToRenderStep("PeakCameraPunch", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake > 0.001 then
			local t = os.clock() * 40
			local a = shake * 0.02
			camera.CFrame *= CFrame.Angles(math.noise(t, 0.3) * a, math.noise(0.7, t) * a, math.noise(t, t) * a * 0.5)
			shake *= math.exp(-dt * 9)
		end
		if fovKick > 0.01 then
			camera.FieldOfView = baseFov + fovKick
			fovKick *= math.exp(-dt * 7)
		elseif fovKick ~= 0 then
			fovKick = 0
			camera.FieldOfView = baseFov
		end
	end)
end

-- Floating text at a world position. `rot` tilts it like a comic sound effect.
function Effects:Pop(position: Vector3, text: string, color: Color3?, size: number?, rot: number?)
	if popActive >= MAX_POPS then
		return
	end
	local gui = table.remove(popPool)
	if not gui then
		return
	end
	popActive += 1
	local anchor = gui.Adornee :: BasePart
	local label = gui:FindFirstChild("Text") :: TextLabel
	local scale = label:FindFirstChildOfClass("UIScale") :: UIScale
	local s = size or 1
	gui.Size = UDim2.fromOffset(math.floor(180 * s), math.floor(56 * s))
	anchor.CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 1.5, 1.5, (math.random() - 0.5) * 1.5))
	label.Text = text
	label.Rotation = rot or 0
	label.TextColor3 = color or WHITE
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.1
	scale.Scale = 0.3
	gui.Enabled = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(
		anchor,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }
	):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.1, function()
		gui.Enabled = false
		popActive -= 1
		table.insert(popPool, gui)
	end)
end

function Effects:PopMaple(position: Vector3, amount: number, color: Color3?, size: number?)
	self:Pop(position, "+" .. Format.abbreviate(amount) .. " 🍁", color or MAPLE, size)
end

-- Comic word for big moments.
local WORDS = { "YUM!", "NOM!", "FLIP!", "STACKED!", "TASTY!" }
function Effects:Word(position: Vector3, size: number?)
	local word = WORDS[math.random(1, #WORDS)]
	self:Pop(position, word, hex("#E5484D"), size, (math.random() - 0.5) * 24)
end

-- Burst of crumbs in a colour.
function Effects:Crumbs(position: Vector3, color: Color3, count: number?, scale: number?)
	local n = count or 10
	if C.State:Setting("performance") then
		n = math.ceil(n / 3)
	end
	local p = table.remove(sprayPool)
	if not p then
		return
	end
	local s = scale or 1
	p.CFrame = CFrame.new(position)
	local e = p:FindFirstChild("E") :: ParticleEmitter
	e.Color = ColorSequence.new(color, WHITE)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * s), NumberSequenceKeypoint.new(1, 0) })
	e.Speed = NumberRange.new(8 * s, 20 * s)
	e:Emit(n)
	task.delay(1, function()
		table.insert(sprayPool, p)
	end)
end

-- Snow puff; scale ~ the size of the thing that made it.
function Effects:Puff(position: Vector3, scale: number?, count: number?)
	local p = table.remove(foamPool)
	if not p then
		return
	end
	local s = scale or 1
	p.CFrame = CFrame.new(position)
	local e = p:FindFirstChild("E") :: ParticleEmitter
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, s * 4) })
	e.Speed = NumberRange.new(4 * s, 10 * s)
	local n = count or 12
	if C.State:Setting("performance") then
		n = math.ceil(n / 3)
	end
	e:Emit(n)
	task.delay(1.3, function()
		table.insert(foamPool, p)
	end)
end

-- Camera punch: small shake plus FOV kick. strength ~ 0..1.
function Effects:Punch(strength: number)
	shake = math.min(shake + strength, 1.5)
	fovKick = math.min(fovKick + strength * 6, 10)
end

function Effects:LocalRoot(): BasePart?
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

return Effects
