--!strict
-- A friendly code-built Yeti (used by the map for the table Yetis and by the client for the Great
-- Yeti). Round, fluffy, storybook: a big ball body, a lighter belly, a round head with a soft muzzle,
-- little horns, stubby arms, a wide mouth (opened by the client when it eats) and rosy cheeks.
-- Returns an anchored Model whose pivot sits on the ground under its feet, facing -Z.
local YetiModel = {}

local hex = Color3.fromHex
local INK = hex("#24406B")

local function ball(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- scale 1 = about 11 studs tall. fur/accent are hex strings.
function YetiModel.build(scale: number, fur: string?, accent: string?): Model
	local s = scale
	local model = Instance.new("Model")
	model.Name = "Yeti"
	local furC = hex(fur or "#F4F7FB")
	local accentC = hex(accent or "#9FD3F0")
	local skin = hex("#B9C8E8")
	local root = CFrame.new()
	local body =
		ball(model, "Body", Vector3.new(8.5, 8, 7.5) * s, root * CFrame.new(0, 4.4 * s, 0), furC, Enum.Material.Sand)
	ball(model, "Belly", Vector3.new(6, 5.6, 3) * s, root * CFrame.new(0, 3.9 * s, -2.6 * s), hex("#FFFFFF"))
	local headCf = root * CFrame.new(0, 9.2 * s, -0.4 * s)
	ball(model, "Head", Vector3.new(6, 5.4, 5.4) * s, headCf, furC, Enum.Material.Sand)
	ball(model, "Muzzle", Vector3.new(4, 2.6, 2.2) * s, headCf * CFrame.new(0, -0.8 * s, -2.2 * s), skin)
	for side = -1, 1, 2 do
		ball(
			model,
			if side < 0 then "EyeL" else "EyeR",
			Vector3.new(0.8, 1.1, 0.5) * s,
			headCf * CFrame.new(side * 1.1 * s, 0.7 * s, -2.55 * s),
			INK
		)
		ball(
			model,
			"Shine",
			Vector3.new(0.3, 0.3, 0.2) * s,
			headCf * CFrame.new(side * 1.0 * s, 0.95 * s, -2.8 * s),
			hex("#FFFFFF")
		)
		ball(
			model,
			"Cheek",
			Vector3.new(0.9, 0.5, 0.3) * s,
			headCf * CFrame.new(side * 1.9 * s, -0.5 * s, -2.35 * s),
			hex("#FF9FB2")
		)
		-- Little curled horns.
		ball(
			model,
			"Horn",
			Vector3.new(0.9, 2, 0.9) * s,
			headCf * CFrame.new(side * 2 * s, 2.5 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			accentC
		)
		-- Stubby arms resting on the table edge.
		local arm = ball(
			model,
			if side < 0 then "ArmL" else "ArmR",
			Vector3.new(2.4, 4.6, 2.4) * s,
			root * CFrame.new(side * 4.4 * s, 5 * s, -1.2 * s) * CFrame.Angles(math.rad(-40), 0, math.rad(side * 20)),
			furC,
			Enum.Material.Sand
		)
		arm:SetAttribute("Side", side)
		ball(model, "Foot", Vector3.new(2.8, 1.4, 3.4) * s, root * CFrame.new(side * 2.2 * s, 0.6 * s, -1.6 * s), skin)
	end
	local mouth =
		ball(model, "Mouth", Vector3.new(1.8, 0.5, 0.4) * s, headCf * CFrame.new(0, -1.3 * s, -3.2 * s), hex("#7A2E3A"))
	mouth:SetAttribute("BaseY", 0.5 * s)
	ball(model, "Nose", Vector3.new(1, 0.7, 0.6) * s, headCf * CFrame.new(0, -0.2 * s, -3.25 * s), INK)
	model.PrimaryPart = body
	-- Pivot on the ground under its feet.
	model.WorldPivot = root
	return model
end

return YetiModel
