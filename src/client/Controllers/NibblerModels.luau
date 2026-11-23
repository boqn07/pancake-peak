--!strict
-- Builds Nibbler models from Parts using each species' `look` (Config/Nibblers): a soft round fluffy
-- body with stubby feet, big shiny eyes, rosy cheeks and its features (ears, antlers, a scarf, a
-- tiny chef hat...). One builder serves followers, the inventory previews and the egg reveal. If a
-- species has a meshId, its body is that mesh (a SpecialMesh, which scripts may set at runtime).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Nibblers = require(Config:WaitForChild("Nibblers"))
local Rarities = require(Config:WaitForChild("Rarities"))

local NibblerModels = {}

-- Viewports that slowly turn their Nibbler. Entries are dropped once their viewport is gone.
local spinners: { { vp: ViewportFrame, model: Model, angle: number, seen: boolean } } = {}
local spinAcc = 0
RunService.RenderStepped:Connect(function(dt)
	spinAcc += dt
	if spinAcc < 1 / 30 then
		return
	end
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		if s.vp:FindFirstAncestorWhichIsA("PlayerGui") then
			s.seen = true
			s.angle += 40 * spinAcc
			s.model:PivotTo(CFrame.Angles(0, math.rad(s.angle), 0))
		elseif s.seen then
			table.remove(spinners, i)
		end
	end
	spinAcc = 0
end)

local hex = Color3.fromHex
local INK = hex("#24406B")
local WHITE = hex("#FFFFFF")
local CHEEK = hex("#FF9FB8")
local BALL, BLOCK, CYL, WEDGE = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Wedge

type Ctx = { model: Model, body: BasePart, s: number, color: Color3, accent: Color3 }

local function piece(
	c: Ctx,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size * c.s
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = false
	p.Massless = true
	p.CFrame = c.body.CFrame * CFrame.new(offset.Position * c.s) * offset.Rotation
	local w = Instance.new("WeldConstraint")
	w.Part0 = c.body
	w.Part1 = p
	w.Parent = p
	p.Parent = c.model
	return p
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end
local R90 = math.rad(90)

-- Features. Front of the body is -Z; s = 1 is the body diameter.
local FEATURES: { [string]: (Ctx) -> () } = {
	Ears = function(c)
		-- Pointy fox/cat ears.
		for side = -1, 1, 2 do
			piece(c, WEDGE, v(0.08, 0.3, 0.22), at(side * 0.24, 0.52, 0.02, 0, 0, side * -0.25), c.color:Lerp(INK, 0.1))
			piece(c, WEDGE, v(0.04, 0.18, 0.12), at(side * 0.24, 0.5, -0.03, 0, 0, side * -0.25), CHEEK)
		end
	end,
	LongEars = function(c)
		-- Floppy bunny ears.
		for side = -1, 1, 2 do
			piece(c, BALL, v(0.16, 0.62, 0.12), at(side * 0.18, 0.68, 0.05, 0.15, 0, side * -0.25), c.color)
			piece(c, BALL, v(0.08, 0.44, 0.04), at(side * 0.18, 0.66, -0.01, 0.15, 0, side * -0.25), CHEEK)
		end
	end,
	RoundEars = function(c)
		for side = -1, 1, 2 do
			piece(c, CYL, v(0.08, 0.26, 0.26), at(side * 0.32, 0.4, 0.02, 0, R90, 0), c.color:Lerp(INK, 0.15))
			piece(c, CYL, v(0.03, 0.16, 0.16), at(side * 0.32, 0.4, -0.03, 0, R90, 0), CHEEK)
		end
	end,
	Tail = function(c)
		piece(c, CYL, v(0.5, 0.12, 0.12), at(0, -0.05, 0.6, R90 * 0.6, 0, R90) * CFrame.Angles(0, R90, 0), c.color)
		piece(c, BALL, v(0.18, 0.18, 0.18), at(0, 0.18, 0.78), c.accent)
	end,
	FluffyTail = function(c)
		-- Big curled squirrel tail.
		piece(c, BALL, v(0.4, 0.7, 0.36), at(0, 0.2, 0.6, 0.3, 0, 0), c.accent)
		piece(c, BALL, v(0.3, 0.3, 0.3), at(0, 0.6, 0.48), c.accent:Lerp(WHITE, 0.3))
	end,
	Beak = function(c)
		piece(c, WEDGE, v(0.2, 0.12, 0.22), at(0, -0.02, -0.56, 0, math.pi, 0), hex("#F2A33A"))
	end,
	Wings = function(c)
		for side = -1, 1, 2 do
			piece(c, BALL, v(0.14, 0.5, 0.36), at(side * 0.5, 0, 0.08, 0, 0, side * -0.35), c.accent)
		end
	end,
	Antlers = function(c)
		for side = -1, 1, 2 do
			piece(c, CYL, v(0.42, 0.06, 0.06), at(side * 0.22, 0.66, 0, 0, 0, R90 - side * 0.35), hex("#9A6A43"))
			piece(c, CYL, v(0.22, 0.05, 0.05), at(side * 0.34, 0.8, -0.04, 0, 0, R90 - side * 1.0), hex("#9A6A43"))
			piece(c, CYL, v(0.2, 0.05, 0.05), at(side * 0.18, 0.86, 0.02, 0, 0, R90 + side * 0.2), hex("#9A6A43"))
		end
	end,
	Horns = function(c)
		-- Little curly goat horns.
		for side = -1, 1, 2 do
			piece(c, CYL, v(0.24, 0.1, 0.1), at(side * 0.22, 0.52, 0.04, 0, 0, R90 - side * 0.6), hex("#E8DCC6"))
			piece(c, BALL, v(0.12, 0.12, 0.12), at(side * 0.32, 0.6, 0.1), hex("#E8DCC6"))
		end
	end,
	Tusks = function(c)
		for side = -1, 1, 2 do
			piece(c, CYL, v(0.22, 0.06, 0.06), at(side * 0.12, -0.2, -0.48, 0, 0, R90 + side * 0.4), WHITE)
		end
	end,
	Horn = function(c)
		piece(
			c,
			CYL,
			v(0.4, 0.1, 0.1),
			at(0, 0.62, -0.18, 0, 0, R90) * CFrame.Angles(0, 0, -0.4),
			hex("#FFE27A"),
			Enum.Material.Neon
		)
	end,
	ChefHat = function(c)
		piece(c, CYL, v(0.18, 0.42, 0.42), at(0, 0.52, 0.02, 0, 0, R90), WHITE)
		for i = 0, 2 do
			piece(c, BALL, v(0.26, 0.24, 0.26), at((i - 1) * 0.12, 0.72, 0.02), WHITE)
		end
	end,
	Scarf = function(c)
		piece(c, CYL, v(0.14, 0.86, 0.86), at(0, -0.22, 0, 0, 0, R90), hex("#E5484D"), Enum.Material.Fabric)
		piece(c, BLOCK, v(0.14, 0.34, 0.04), at(0.2, -0.38, -0.42, 0, 0, 0.2), hex("#E5484D"), Enum.Material.Fabric)
	end,
	Mask = function(c)
		-- Raccoon bandit mask.
		piece(c, BLOCK, v(0.62, 0.14, 0.1), at(0, 0.14, -0.41), INK:Lerp(c.color, 0.25))
	end,
	Stripes = function(c)
		for i = -1, 1, 2 do
			piece(c, CYL, v(0.06, 1.01, 1.01), at(0, 0, i * 0.18) * CFrame.Angles(0, R90, 0), c.accent)
		end
	end,
	Spots = function(c)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2 + 0.4
			local dir = Vector3.new(math.cos(a) * 0.7, 0.35 + (i % 2) * 0.25, math.sin(a) * 0.5 + 0.25).Unit
			piece(c, CYL, v(0.04, 0.16, 0.16), CFrame.lookAt(dir * 0.49, dir) * CFrame.Angles(0, R90, 0), c.accent)
		end
	end,
	Crest = function(c)
		for i = 0, 2 do
			piece(c, BLOCK, v(0.06, 0.3 - i * 0.05, 0.14), at(0, 0.55 - i * 0.04, -0.05 + i * 0.13, -0.3), c.accent)
		end
	end,
	Glow = function(c)
		local light = Instance.new("PointLight")
		light.Color = c.accent
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = c.body
		piece(c, BALL, v(0.12, 0.12, 0.12), at(0, 0.54, -0.2), c.accent, Enum.Material.Neon)
	end,
}

export type Options = { anchoredAll: boolean? }

-- Builds a Nibbler with its body center as the pivot.
-- Model.PrimaryPart is the anchored body; move it with CFrame (welded parts follow).
function NibblerModels:Build(nibblerId: string, shiny: boolean, opts: Options?): Model
	local def = Nibblers.ById[nibblerId] or Nibblers.List[1]
	local look = def.look
	local s = 1.6 * look.size
	local model = Instance.new("Model")
	model.Name = def.id
	local hasMesh = def.meshId ~= nil and def.meshId ~= ""
	local body = Instance.new("Part")
	if hasMesh then
		body.Size = Vector3.one * s
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = def.meshId :: string
		mesh.Scale = Vector3.one * s
		mesh.Parent = body
	else
		body.Shape = BALL
		body.Size = Vector3.one * s
	end
	body.Name = "Body"
	body.Color = hex(look.body)
	body.Material = Enum.Material.Fabric
	body.Reflectance = 0
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.CFrame = CFrame.identity
	body.Parent = model
	model.PrimaryPart = body

	local c: Ctx = { model = model, body = body, s = s, color = hex(look.body), accent = hex(look.accent) }
	if not hasMesh then
		-- Pale belly, stubby feet, big glossy eyes with highlights, cheeks, a little smile.
		piece(c, BALL, v(0.7, 0.6, 0.3), at(0, -0.12, -0.36), c.color:Lerp(WHITE, 0.55))
		for side = -1, 1, 2 do
			piece(c, BALL, v(0.26, 0.14, 0.32), at(side * 0.22, -0.46, -0.12), c.color:Lerp(INK, 0.2))
		end
		for side = -1, 1, 2 do
			piece(c, BALL, v(0.2, 0.24, 0.12), at(side * 0.18, 0.14, -0.44), INK)
			piece(c, BALL, v(0.07, 0.07, 0.04), at(side * 0.15, 0.2, -0.5), WHITE, Enum.Material.Neon)
			piece(c, CYL, v(0.02, 0.14, 0.14), at(side * 0.3, -0.04, -0.41, 0, R90 - side * 0.5, 0), CHEEK)
		end
		piece(c, BLOCK, v(0.12, 0.03, 0.02), at(0, -0.06, -0.5), INK)
		for _, f in look.features do
			local fn = FEATURES[f]
			if fn then
				fn(c)
			end
		end
	end

	if shiny then
		model:SetAttribute("Shiny", true)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 6
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		local g = Rarities.Shiny.gradient
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex(g[1])),
			ColorSequenceKeypoint.new(0.5, hex(g[3])),
			ColorSequenceKeypoint.new(1, hex(g[5])),
		})
		e.Parent = body
	end

	if opts and opts.anchoredAll then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	return model
end

-- Frosty-gold shimmer for Sparkly bodies at time t.
function NibblerModels:ShinyColor(base: Color3, t: number): Color3
	return base:Lerp(Color3.fromHSV(0.12 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.5)), 0.3, 1), 0.4)
end

-- Rarity color helper shared with UI.
function NibblerModels:RarityColor(rarityId: string): Color3
	local r = Rarities.ById[rarityId]
	return if r then hex(r.color) else INK
end

-- A ViewportFrame showing a Nibbler, slowly turning if `spin` is true.
function NibblerModels:Viewport(nibblerId: string, shiny: boolean, spin: boolean?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = hex("#DCEBFA")
	vp.LightColor = WHITE
	vp.LightDirection = Vector3.new(-1, -1, -1)
	local model = self:Build(nibblerId, shiny, { anchoredAll = true })
	model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
	model.Parent = vp
	local cam = Instance.new("Camera")
	local size = model:GetExtentsSize().Magnitude
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, size * 0.25, -size * 1.6), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	if spin then
		table.insert(spinners, { vp = vp, model = model, angle = 200, seen = false })
	end
	return vp
end

return NibblerModels
