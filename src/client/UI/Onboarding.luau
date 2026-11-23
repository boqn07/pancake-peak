--!strict
-- First-time tips that teach the loop in about a minute: flip a pancake → land a perfect → serve a
-- Yeti → buy Batter → hatch the Maple Egg. One short line at a time plus a sparkly guide beam and a
-- ring of little snowballs around the target.
-- Progress comes from the server (real actions), so tips never get out of sync.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Eggs = require(Shared.Config:WaitForChild("Eggs"))
local UpgradeMath = require(Shared:WaitForChild("Logic"):WaitForChild("UpgradeMath"))
local ZoneGeo = require(Shared.Logic:WaitForChild("ZoneGeo"))

local Onboarding = {}

local C: any, Kit: any, Theme: any, Root: any
local banner: Frame
local bannerText: TextLabel
local bannerScale: UIScale
local guideFolder: Folder
local beam: Beam
local targetAttachment: Attachment
local targetPart: Part
local ring: { Part } = {}

local TIPS = {
	[0] = "Press FLIP! to drop the sliding pancake on your tray 🥞",
	[1] = "Drop it right on top of the last one for a PERFECT (no slicing!)",
	[2] = "Walk up to a Yeti's table and press SERVE 🍽️",
	[3] = "Tap ⚡ Upgrades and buy Batter (more Maple per pancake)",
	[4] = "Hatch the Maple Egg to get a Nibbler buddy",
}

local function setTip(text: string?)
	if not text then
		if banner.Visible then
			Kit.springScale(bannerScale, 0, 30, 1)
			task.delay(0.2, function()
				banner.Visible = false
			end)
		end
		return
	end
	if bannerText.Text ~= text or not banner.Visible then
		bannerText.Text = text
		banner.Visible = true
		bannerScale.Scale = 0.5
		Kit.springScale(bannerScale, 1)
	end
end

local FIRST = Zones.List[1]

local function landmark(kind: string): Vector3
	local lm = (ZoneGeo.landmarks(FIRST.id) :: any)[kind]
	return Vector3.new(lm.x, FIRST.center.y + 1, lm.z)
end

-- The nearest Yeti table in the first zone.
local function nearestYeti(from: Vector3): Vector3
	local y = ZoneGeo.nearestYeti(FIRST.id, from.X, from.Z)
	return Vector3.new(y.x, FIRST.center.y + 2, y.z)
end

function Onboarding.Build(controllers, kit, theme, root, screen: Frame)
	C, Kit, Theme, Root = controllers, kit, theme, root
	banner = Kit.new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.fromOffset(560, 64),
		BackgroundColor3 = Theme.Colors.butter,
		Visible = false,
		Parent = screen,
	}, {
		Kit.corner(UDim.new(0, 18)),
		Kit.stroke(Theme.Colors.ink, 4),
	})
	bannerScale = Kit.new("UIScale", { Parent = banner })
	bannerText = Kit.label({
		Text = "",
		TextColor3 = Theme.Colors.ink,
		Size = UDim2.new(1, -120, 1, -14),
		Position = UDim2.fromOffset(16, 7),
		MaxTextSize = 30,
		Parent = banner,
	})
	Kit.button({
		text = "Skip",
		color = Theme.Colors.white,
		textColor = Theme.Colors.ink,
		size = UDim2.fromOffset(90, 48),
		position = UDim2.new(1, -98, 0.5, -24),
		parent = banner,
		onClick = function()
			C.ClientNet:Fire("SkipTutorial")
		end,
	})

	-- World guide: a sparkly beam from the player to the target and a bobbing ring of snowballs.
	guideFolder = Instance.new("Folder")
	guideFolder.Name = "Guide"
	guideFolder.Parent = workspace
	targetPart = Instance.new("Part")
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = guideFolder
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart
	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Width0 = 0.6
	beam.Width1 = 1.2
	beam.CurveSize0 = 6
	beam.CurveSize1 = -2
	beam.FaceCamera = true
	beam.LightEmission = 0.3
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 3
	beam.TextureSpeed = 1.5
	beam.Segments = 20
	beam.Color = ColorSequence.new(Theme.Colors.white, Theme.Colors.butter)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	beam.Enabled = false
	beam.Parent = targetPart
	for _ = 1, 14 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Theme.Colors.snow
		p.Material = Enum.Material.Snow
		p.Transparency = 0
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 1.1
		p.CastShadow = false
		p.CFrame = CFrame.new(0, -10000, 0)
		p.Parent = guideFolder
		table.insert(ring, p)
	end

	local function update()
		local data = C.State.data
		if not data.tutorial or data.tutorial.done then
			setTip(nil)
			beam.Enabled = false
			for _, p in ring do
				p.CFrame = CFrame.new(0, -10000, 0)
			end
			return nil
		end
		local step = data.tutorial.step
		local root = C.Effects:LocalRoot()
		local target: Vector3? = nil
		local showRing = false
		local p = root and root.CFrame.Position
		local count = C.StackRenderer:MyCount()
		if step == 0 then
			setTip(TIPS[0])
			Root:Highlight("Flip")
		elseif step == 1 then
			setTip(TIPS[1])
		elseif step == 2 then
			if count == 0 then
				setTip("Stack a few pancakes first, then serve them to a Yeti")
			else
				local inFirst = p ~= nil and ZoneGeo.zoneAt(p.X, p.Y, p.Z) == FIRST.id
				setTip(if inFirst then TIPS[2] else "Take the trail to Maple Meadow, the Yetis are hungry!")
				if p then
					target = if inFirst then nearestYeti(p) else landmark("entrance")
				end
				showRing = inFirst
				if C.StackInput:Target() then
					Root:Highlight("Serve")
				end
			end
		elseif step == 3 then
			local cost = UpgradeMath.cost("Batter", (data.upgrades and data.upgrades.Batter) or 0)
			if (data.maple or 0) >= cost then
				setTip(TIPS[3])
				Root:Highlight("Upgrades")
			else
				setTip(string.format("Serve pancakes for %d Maple, then buy Batter", cost))
			end
		elseif step == 4 then
			local egg = Eggs.List[1]
			if (data.maple or 0) >= egg.cost then
				setTip(TIPS[4])
				target = landmark("egg")
				showRing = true
			else
				setTip(string.format("Serve pancakes for %d Maple to hatch the Maple Egg", egg.cost))
			end
		end
		return target, showRing
	end

	local currentTarget: Vector3? = nil
	local ringOn = false
	task.spawn(function()
		while true do
			local t, r = update()
			currentTarget, ringOn = t, r == true
			task.wait(0.4)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local root = C.Effects:LocalRoot()
		if currentTarget and root then
			local att = root:FindFirstChild("GuideAttachment") :: Attachment?
			if not att then
				att = Instance.new("Attachment")
				att.Name = "GuideAttachment"
				att.Position = Vector3.new(0, -1.5, 0)
				att.Parent = root
			end
			beam.Attachment0 = att
			targetPart.CFrame = CFrame.new(currentTarget)
			beam.Enabled = (currentTarget - root.CFrame.Position).Magnitude > 6
		else
			beam.Enabled = false
		end
		if ringOn and currentTarget then
			local t = os.clock()
			for i, p in ring do
				local a = t * 1.5 + i / #ring * math.pi * 2
				p.CFrame = CFrame.new(
					currentTarget
						+ Vector3.new(math.cos(a) * 5, -0.6 + math.abs(math.sin(t * 4 + i)) * 0.8, math.sin(a) * 5)
				)
			end
		else
			for _, p in ring do
				p.CFrame = CFrame.new(0, -10000, 0)
			end
		end
	end)
end

return Onboarding
