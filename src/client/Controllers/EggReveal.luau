--!strict
-- The egg reveal: the Mystery Egg wobbles harder in its sizzling frying pan and glows in the color
-- of the best result, cracks with a flash and a shower of crumbs, then each Nibbler pops in with its
-- rarity. Fast Hatch shortens it.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Eggs = require(Shared:WaitForChild("Config"):WaitForChild("Eggs"))
local Nibblers = require(Shared.Config:WaitForChild("Nibblers"))
local Rarities = require(Shared.Config:WaitForChild("Rarities"))
local Format = require(Shared:WaitForChild("Logic"):WaitForChild("Format"))
local Economy = require(Shared.Logic:WaitForChild("Economy"))

local EggReveal = {}

local C: any
local hex = Color3.fromHex
local gui: ScreenGui
local busy = false
local pendingUntil = 0
local last: { eggId: string, count: number }? = nil

function EggReveal:Init(controllers)
	C = controllers
	gui = Instance.new("ScreenGui")
	gui.Name = "EggReveal"
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function EggReveal:Start()
	C.ClientNet:On("EggResult", function(r)
		pendingUntil = 0
		C.UIRoot:Close()
		self:Show(r.eggId, r.results, r.fast)
	end)
end

-- Ask the server to hatch an egg. The reveal plays when the result arrives.
function EggReveal:Request(eggId: string, count: number)
	if busy or os.clock() < pendingUntil then
		return
	end
	pendingUntil = os.clock() + 2
	last = { eggId = eggId, count = count }
	C.ClientNet:Fire("HatchEgg", eggId, count)
end

local function bestRarity(results: { any }): (string, boolean)
	local best, rank, prism = "Common", 0, false
	for _, r in results do
		local def = Nibblers.ById[r.id]
		local rr = def and Rarities.ById[def.rarity]
		if rr and rr.rank > rank then
			best, rank = rr.id, rr.rank
		end
		if r.shiny then
			prism = true
		end
	end
	return best, prism
end

-- A Mystery Egg in a frying pan: a dark pan with a handle, a speckled egg sitting in it.
local function eggViewport(color: Color3): (ViewportFrame, Model, BasePart, BasePart)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = hex("#DCEBFA")
	vp.LightColor = hex("#FFFFFF")
	local model = Instance.new("Model")
	local function part(shape: Enum.PartType, size: Vector3, cf: CFrame, c: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = model
		return p
	end
	local CYL = Enum.PartType.Cylinder
	local pan = part(
		CYL,
		Vector3.new(1.2, 9, 9),
		CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		hex("#3B4356"),
		Enum.Material.Metal
	)
	part(Enum.PartType.Block, Vector3.new(0.8, 0.6, 6), CFrame.new(0, -1.8, 7), hex("#C98B55"), Enum.Material.Wood)
	local egg = part(Enum.PartType.Ball, Vector3.new(5, 6.4, 5), CFrame.new(0, 1.4, 0), hex("#FFF6E6"))
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local spot = part(
			Enum.PartType.Ball,
			Vector3.one * 0.9,
			CFrame.new(math.cos(a) * 2.3, 1.4 + (k % 3 - 1) * 1.3, math.sin(a) * 2.3),
			color
		)
		local w = Instance.new("WeldConstraint")
		w.Part0 = egg
		w.Part1 = spot
		w.Parent = spot
		spot:SetAttribute("Spot", true)
	end
	model.PrimaryPart = pan
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 6, -16), Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp, model, egg, pan
end

local function confetti(parent: Instance, colors: { Color3 }, count: number)
	for _ = 1, count do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.45)
		f.Size = UDim2.fromOffset(math.random(8, 16), math.random(8, 16))
		f.BackgroundColor3 = colors[math.random(1, #colors)]
		f.BorderSizePixel = 0
		f.Rotation = math.random(0, 360)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = parent
		local a = math.random() * math.pi * 2
		local d = math.random(180, 420)
		TweenService:Create(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.floor(math.cos(a) * d), 0.45, math.floor(math.sin(a) * d)),
			Rotation = f.Rotation + math.random(-360, 360),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(1, function()
			f:Destroy()
		end)
	end
end

-- Plays the reveal. eggId nil = a reward Nibbler (no egg wobble).
function EggReveal:Show(eggId: string?, results: { any }, fast: boolean?)
	if busy then
		return
	end
	busy = true
	local T = C.UIRoot.Theme
	local Kit = C.UIRoot.Kit
	gui:ClearAllChildren()
	gui.Enabled = true
	local best, anyShiny = bestRarity(results)
	local bestColor = T.Rarity[best]

	local backdrop = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.Colors.ink,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.25 }):Play()
	local glow = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 520),
		BackgroundColor3 = bestColor,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Parent = glow,
	})
	local scaleRoot = Kit.new("UIScale", { Parent = glow })
	local _ = scaleRoot

	-- 1) Wobble, then the egg cracks
	if eggId then
		local egg = Eggs.ById[eggId]
		local vp, model, shell = eggViewport(hex(egg.color))
		vp.AnchorPoint = Vector2.new(0.5, 0.5)
		vp.Position = UDim2.fromScale(0.5, 0.45)
		vp.Size = UDim2.fromOffset(360, 360)
		vp.Parent = gui
		local spots = {}
		for _, d in model:GetChildren() do
			if d:GetAttribute("Spot") then
				table.insert(
					spots,
					{ part = d :: BasePart, offset = shell.CFrame:ToObjectSpace((d :: BasePart).CFrame) }
				)
			end
		end
		local base = shell.CFrame
		local function place(cf: CFrame)
			shell.CFrame = cf
			for _, sp in spots do
				sp.part.CFrame = cf * sp.offset
			end
		end
		local total = if fast then Eggs.RevealSecondsFast else Eggs.RevealSeconds
		local shakes = if fast then 3 else 6
		for i = 1, shakes do
			local intensity = i / shakes
			glow.BackgroundTransparency = 1 - 0.7 * intensity
			C.Audio:Play("EggShake", { pitch = 0.8 + intensity * 0.8 })
			local angle = math.rad(5 + 14 * intensity) * (if i % 2 == 0 then 1 else -1)
			-- The egg hops a little higher on each wobble.
			place(base * CFrame.new(0, intensity * 0.8, 0) * CFrame.Angles(0, 0, angle))
			task.wait(total / shakes * 0.5)
			place(base)
			task.wait(total / shakes * 0.5)
		end
		-- Crack: the shell squashes and pops.
		for k = 1, 4 do
			place(base * CFrame.new(0, -0.2 * k, 0))
			shell.Size = Vector3.new(5 + k * 0.4, 6.4 - k * 0.5, 5 + k * 0.4)
			task.wait(0.03)
		end
		vp:Destroy()
	end

	-- 2) Burst
	C.Audio:Play("EggCrack")
	C.LightingFX:Flash(0.7)
	local flash = Kit.new(
		"Frame",
		{ BackgroundColor3 = T.Colors.white, BackgroundTransparency = 0.1, Size = UDim2.fromScale(1, 1), Parent = gui }
	)
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	local colors = { bestColor, T.Colors.white, T.Colors.maple, T.Colors.butter }
	if anyShiny then
		colors = T.ShinyGradient
	end
	confetti(gui, colors, if Rarities.ById[best].rank >= 5 or anyShiny then 60 else 24)
	glow.BackgroundTransparency = 0.35

	-- 3) Cards
	local row = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(#results * 300, 380),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Kit.list(row, 16, true)
	local uiScale = Kit.new("UIScale", { Parent = row })
	-- Fit small screens.
	local vpSize = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vpSize.X / (#results * 320), vpSize.Y / 520), 0.45, 1.2)
	for i, r in results do
		local def = Nibblers.ById[r.id]
		local rc = T.Rarity[def.rarity]
		local card = Kit.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(280, 380),
			BackgroundColor3 = T.Colors.paper,
			Rotation = (i % 2 * 2 - 1) * 2,
			Parent = row,
		}, { Kit.corner(UDim.new(0, 24)), Kit.stroke(if r.shiny then T.Colors.butter else rc, 6) })
		local s = Kit.new("UIScale", { Scale = 0.2, Parent = card })
		local vp = C.NibblerModels:Viewport(r.id, r.shiny, true)
		vp.Size = UDim2.new(1, -20, 0, 230)
		vp.Position = UDim2.fromOffset(10, 10)
		vp.Parent = card
		Kit.label({
			Text = def.name,
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.fromOffset(10, 244),
			MaxTextSize = 34,
			Parent = card,
		})
		local rarityLabel = Kit.label({
			Text = if r.shiny then "SPARKLY " .. def.rarity else def.rarity,
			TextColor3 = rc,
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.fromOffset(10, 286),
			MaxTextSize = 28,
			Parent = card,
		})
		if r.shiny then
			local g = {}
			for k, c in T.ShinyGradient do
				table.insert(g, ColorSequenceKeypoint.new((k - 1) / (#T.ShinyGradient - 1), c))
			end
			Kit.new("UIGradient", { Color = ColorSequence.new(g), Parent = rarityLabel })
			rarityLabel.TextColor3 = Color3.new(1, 1, 1)
		end
		local power = Economy.nibblerPower({ id = r.id, shiny = r.shiny })
		Kit.label({
			Text = "+" .. Format.abbreviate(math.floor(power * 100)) .. "% Maple",
			TextColor3 = T.Colors.berry,
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.fromOffset(10, 322),
			MaxTextSize = 24,
			Parent = card,
		})
		task.delay((i - 1) * 0.12, function()
			Kit.springScale(s, 1, 18, 0.5)
		end)
	end

	-- 4) Buttons
	local buttons = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(600, 84),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Kit.list(buttons, 16, true)
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function()
			gui.Enabled = false
			gui:ClearAllChildren()
			busy = false
		end)
	end
	local doneButton = Kit.button({
		text = "Done",
		color = T.Colors.white,
		textColor = T.Colors.ink,
		size = UDim2.fromOffset(240, 76),
		layoutOrder = 2,
		parent = buttons,
		onClick = finish,
	})
	if eggId and last and last.eggId == eggId then
		local again = last
		Kit.button({
			text = "Hatch again",
			color = T.Colors.pine,
			textColor = T.Colors.white,
			size = UDim2.fromOffset(280, 76),
			layoutOrder = 1,
			parent = buttons,
			onClick = function()
				finish()
				task.delay(0.25, function()
					self:Request(again.eggId, again.count)
				end)
			end,
		})
	end
	backdrop.Activated:Connect(finish)
	if C.InputController:UsingGamepad() then
		game:GetService("GuiService").SelectedObject = doneButton
	end
	task.delay(if fast then 3 else 5, finish)
end

return EggReveal
