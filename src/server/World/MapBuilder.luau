--!strict
-- Builds the whole mountain from Parts at server start: the sea of clouds, Base Camp (spawn,
-- leaderboards, the Pancake Monument), five snowy zone plateaus with their Yeti tables, plazas,
-- Mystery Egg pans and props, the ramps with their ice gates, and Pancake Peak itself on the horizon.
-- Everything is placed from Config/Zones and Logic/ZoneGeo, so the server's gameplay geometry and
-- what players see always agree.
--
-- Art rules (docs/GDD.md §10): snow-globe storybook, round chunky shapes, warm wood and red roofs
-- against snow, ink blue instead of black, each zone one accent and its own pancake color.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Eggs = require(Shared.Config.Eggs)
local Leaderboards = require(Shared.Config.Leaderboards)
local StackCfg = require(Shared.Config.Stack)
local ZoneGeo = require(Shared.Logic.ZoneGeo)
local Format = require(Shared.Logic.Format)
local YetiModel = require(Shared.Util.YetiModel)

local MapBuilder = {}

export type Built = {
	hubSpawn: CFrame,
	zoneSpawns: { [string]: CFrame },
	eggs: { [string]: Vector3 },
	boards: { [string]: SurfaceGui },
}

local hex = Color3.fromHex
local INK = hex("#24406B")
local WHITE = hex("#FFFFFF")
local SNOW = hex("#F4F7FB")
local SNOW_SHADE = hex("#DCE6F2")
local ICE = hex("#9FDCF5")
local WOOD = hex("#A8703F")
local WOOD_LIGHT = hex("#D19A5E")
local ROOF = hex("#E5484D")
local PINE = hex("#4F8A5B")
local ROCK = hex("#8C93A8")
local CLOUD = hex("#FFFFFF")
local FONT = Enum.Font.FredokaOne
local CLOUD_Y = -24

local rng = Random.new(20261123)

---------------------------------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------------------------------
local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function block(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	return part(parent, {
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = collide ~= false,
	})
end

-- Upright cylinder whose base sits at `base`.
local function cyl(
	parent: Instance,
	radius: number,
	height: number,
	base: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = collide ~= false,
	})
end

local function ball(parent: Instance, d: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A cylinder between two points (trunks, roots, rails).
local function rod(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	radius: number,
	color: Color3,
	material: Enum.Material?
): Part
	local len = (b - a).Magnitude
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(len, radius * 2, radius * 2),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function nocollide(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function billboard(adornee: BasePart, text: string, offset: Vector3, size: Vector2, color: Color3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 300
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	l.Parent = gui
	gui.Parent = adornee
	return gui
end

local function prompt(parent: BasePart, kind: string, action: string, object: string, distance: number): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = distance
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.R
	pp.GamepadKeyCode = Enum.KeyCode.ButtonY
	pp:SetAttribute("Kind", kind)
	pp.Parent = parent
	return pp
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function onDisc(cx: number, cz: number, radius: number): (number, number)
	local a = rng:NextNumber(0, math.pi * 2)
	local d = math.sqrt(rng:NextNumber()) * radius
	return cx + math.cos(a) * d, cz + math.sin(a) * d
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

---------------------------------------------------------------------------------------------------
-- Shared props
---------------------------------------------------------------------------------------------------
-- A storybook pine: stacked, shrinking discs with snow on each tier.
local function pine(parent: Instance, x: number, y: number, z: number, height: number, color: Color3?)
	local f = folder(parent, "Pine")
	local green = color or PINE
	cyl(f, height * 0.05, height * 0.25, CFrame.new(x, y, z), WOOD, Enum.Material.Wood)
	local tiers = 4
	for i = 0, tiers - 1 do
		local t = i / tiers
		local r = height * (0.34 - t * 0.22)
		local ty = y + height * (0.2 + t * 0.62)
		nocollide(cyl(f, r, height * 0.16, CFrame.new(x, ty, z), green:Lerp(INK, i * 0.03), Enum.Material.Grass))
		nocollide(cyl(f, r * 0.75, height * 0.03, CFrame.new(x, ty + height * 0.16, z), SNOW, Enum.Material.Snow))
	end
	nocollide(ball(f, height * 0.12, Vector3.new(x, y + height * 1.02, z), SNOW, Enum.Material.Snow))
end

-- A maple tree: a thick trunk and a cloud of amber/red leaf balls dusted with snow.
local function maple(parent: Instance, x: number, y: number, z: number, height: number)
	local f = folder(parent, "Maple")
	rod(f, Vector3.new(x, y, z), Vector3.new(x, y + height * 0.55, z), height * 0.06, WOOD, Enum.Material.Wood)
	local colors = { hex("#F2A33A"), hex("#E5484D"), hex("#F7C873"), hex("#D9622B") }
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		local d = height * 0.22
		local p =
			Vector3.new(x + math.cos(a) * d, y + height * (0.62 + rng:NextNumber(-0.06, 0.1)), z + math.sin(a) * d)
		nocollide(ball(f, height * rng:NextNumber(0.32, 0.42), p, colors[(k % #colors) + 1], Enum.Material.Grass))
	end
	nocollide(ball(f, height * 0.48, Vector3.new(x, y + height * 0.78, z), colors[1], Enum.Material.Grass))
	nocollide(ball(f, height * 0.3, Vector3.new(x, y + height * 0.98, z), SNOW, Enum.Material.Snow))
end

-- A chalet: wooden walls, a steep red roof with snow on top, warm glowing windows and a chimney.
local function chalet(
	parent: Instance,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number,
	s: number,
	roof: Color3?
)
	local f = folder(parent, "Chalet")
	local look = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(faceX, y, faceZ))
	local w, d, h = 14 * s, 12 * s, 9 * s
	block(f, Vector3.new(w, h, d), look * CFrame.new(0, h / 2, 0), WOOD_LIGHT, Enum.Material.WoodPlanks)
	local roofC = roof or ROOF
	for side = -1, 1, 2 do
		wedge(
			f,
			Vector3.new(w + 2 * s, 6 * s, d / 2 + 1.5 * s),
			look
				* CFrame.new(0, h + 3 * s, side * (d / 4 + 0.75 * s))
				* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			roofC,
			Enum.Material.SmoothPlastic
		)
	end
	block(
		f,
		Vector3.new(w + 2.4 * s, 0.8 * s, 2 * s),
		look * CFrame.new(0, h + 6.1 * s, 0),
		SNOW,
		Enum.Material.Snow,
		false
	)
	for side = -1, 1, 2 do
		local win = block(
			f,
			Vector3.new(2.6 * s, 2.6 * s, 0.3),
			look * CFrame.new(side * 3.6 * s, h * 0.55, -d / 2 - 0.1),
			hex("#FFD36B"),
			Enum.Material.Neon,
			false
		)
		win.Name = "Window"
	end
	block(
		f,
		Vector3.new(3 * s, 5 * s, 0.3),
		look * CFrame.new(0, 2.5 * s, -d / 2 - 0.1),
		hex("#7A4A2A"),
		Enum.Material.Wood,
		false
	)
	block(
		f,
		Vector3.new(2 * s, 5 * s, 2 * s),
		look * CFrame.new(w * 0.28, h + 5 * s, d * 0.15),
		hex("#9AA3B5"),
		Enum.Material.Slate
	)
end

local function snowman(parent: Instance, x: number, y: number, z: number, s: number)
	local f = folder(parent, "Snowman")
	ball(f, 4 * s, Vector3.new(x, y + 1.8 * s, z), SNOW, Enum.Material.Snow)
	ball(f, 3 * s, Vector3.new(x, y + 4.6 * s, z), SNOW, Enum.Material.Snow)
	ball(f, 2.2 * s, Vector3.new(x, y + 6.8 * s, z), SNOW, Enum.Material.Snow)
	nocollide(cyl(f, 1.2 * s, 0.4 * s, CFrame.new(x, y + 5.7 * s, z), ROOF, Enum.Material.Fabric))
	local nose = part(f, {
		Size = Vector3.new(0.4, 0.4, 1.4) * s,
		CFrame = CFrame.new(x, y + 6.8 * s, z - 1.3 * s),
		Color = hex("#FF8A3C"),
		CanCollide = false,
	})
	nose.Name = "Nose"
end

local function rock(parent: Instance, x: number, y: number, z: number, s: number, color: Color3?)
	local p = part(parent, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s * rng:NextNumber(1.1, 1.6), s * rng:NextNumber(0.7, 1), s * rng:NextNumber(1.1, 1.5)),
		CFrame = CFrame.new(x, y + s * 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Color = color or ROCK,
		Material = Enum.Material.Slate,
	})
	p.Name = "Rock"
	nocollide(ball(parent, s * 0.9, Vector3.new(x, y + s * 0.62, z), SNOW, Enum.Material.Snow))
end

local function crystal(parent: Instance, x: number, y: number, z: number, s: number, color: Color3)
	local f = folder(parent, "Crystal")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local p = block(
			f,
			Vector3.new(1.4 * s, (4 + k * 1.5) * s, 1.4 * s),
			CFrame.new(x + math.cos(a) * 0.8 * s, y + (2 + k * 0.75) * s, z + math.sin(a) * 0.8 * s)
				* CFrame.Angles(math.rad(12 * math.cos(a)), a, math.rad(12 * math.sin(a))),
			color,
			Enum.Material.Ice,
			false
		)
		p.Transparency = 0.15
		p.Reflectance = 0.2
	end
end

local function lantern(parent: Instance, x: number, y: number, z: number)
	local f = folder(parent, "Lantern")
	cyl(f, 0.3, 7, CFrame.new(x, y, z), INK, Enum.Material.Metal)
	local glow = ball(f, 1.6, Vector3.new(x, y + 7.4, z), hex("#FFD36B"), Enum.Material.Neon)
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = hex("#FFC870")
	light.Range = 14
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = glow
end

-- A stack of pancakes used as decoration (and the Base Camp monument).
local function pancakeTower(
	parent: Instance,
	x: number,
	y: number,
	z: number,
	r: number,
	n: number,
	batter: Color3,
	crust: Color3
)
	local f = folder(parent, "PancakeTower")
	local h = r * 0.22
	for i = 0, n - 1 do
		local jitter = rng:NextNumber(-0.06, 0.06) * r
		local rr = r * (1 - i * 0.012)
		cyl(f, rr, h * 0.25, CFrame.new(x + jitter, y + i * h, z - jitter), crust, Enum.Material.SmoothPlastic)
		cyl(
			f,
			rr * 0.97,
			h * 0.6,
			CFrame.new(x + jitter, y + i * h + h * 0.2, z - jitter),
			batter,
			Enum.Material.SmoothPlastic
		)
	end
	local top = y + n * h
	cyl(f, r * 0.85, h * 0.25, CFrame.new(x, top, z), hex("#C9822F"), Enum.Material.Glass, false).Transparency = 0.2
	block(
		f,
		Vector3.new(r * 0.45, r * 0.3, r * 0.45),
		CFrame.new(x, top + r * 0.2, z),
		hex("#FFE89A"),
		Enum.Material.SmoothPlastic
	)
	-- Syrup drips down the side.
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		nocollide(
			rod(
				f,
				Vector3.new(x + math.cos(a) * r * 0.95, top, z + math.sin(a) * r * 0.95),
				Vector3.new(x + math.cos(a) * r * 0.98, top - h * rng:NextNumber(2, 5), z + math.sin(a) * r * 0.98),
				h * 0.18,
				hex("#C9822F"),
				Enum.Material.Glass
			)
		)
	end
	return top
end

---------------------------------------------------------------------------------------------------
-- Yeti tables and Mystery Eggs
---------------------------------------------------------------------------------------------------
local function buildYetiTable(parent: Instance, zone: Zones.Zone, y: ZoneGeo.Yeti)
	local f = folder(parent, "Yeti_" .. y.index)
	f:SetAttribute("ZoneOrder", zone.order)
	f:SetAttribute("YetiIndex", y.index)
	local pos = Vector3.new(y.x, zone.center.y, y.z)
	local look = CFrame.lookAt(pos, pos + Vector3.new(y.faceX, 0, y.faceZ))
	-- The Yeti sits behind its table, looking toward the plaza (where chefs come from).
	local accent = hex(zone.accent)
	local rug = cyl(f, 12, 0.2, look, hex("#E5484D"), Enum.Material.Fabric, false)
	rug.CastShadow = false
	for k = -2, 2 do
		block(f, Vector3.new(24, 0.22, 1.2), look * CFrame.new(0, 0.05, k * 4), WHITE, Enum.Material.Fabric, false).CastShadow =
			false
	end
	local tableTop =
		block(f, Vector3.new(14, 1, 7), look * CFrame.new(0, 3.6, -3), WOOD_LIGHT, Enum.Material.WoodPlanks)
	tableTop.Name = "Table"
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			block(f, Vector3.new(1, 3.2, 1), look * CFrame.new(sx * 6, 1.6, -3 + sz * 2.8), WOOD, Enum.Material.Wood)
		end
	end
	-- Gingham tablecloth strip and a big empty plate.
	block(f, Vector3.new(14.2, 0.1, 3), look * CFrame.new(0, 4.15, -3), ROOF, Enum.Material.Fabric, false)
	local plate = cyl(f, 3, 0.3, look * CFrame.new(0, 4.1, -4.2), WHITE, Enum.Material.SmoothPlastic, false)
	plate.Name = "Plate"
	local yeti = YetiModel.build(0.85, "#F4F7FB", zone.accent)
	yeti:PivotTo(look * CFrame.new(0, 0, 3))
	yeti.Parent = f
	-- Craving sign: the client fills in the live height window from the shared clock.
	local signPost = cyl(f, 0.4, 16, look * CFrame.new(-8, 0, 2), WOOD, Enum.Material.Wood)
	local sign = billboard(signPost, "Craving", Vector3.new(0, 11, 0), Vector2.new(240, 96), accent)
	sign.Name = "CravingSign"
	sign.MaxDistance = 140
	local pp = prompt(plate, "Serve", "Serve", "Yeti", StackCfg.ServeDistance - 2)
	pp:SetAttribute("ZoneId", zone.id)
	pp:SetAttribute("YetiIndex", y.index)
end

-- A giant frying pan with a speckled Mystery Egg in it.
local function buildEgg(
	parent: Instance,
	eggId: string,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number
): Vector3
	local egg = Eggs.ById[eggId]
	local f = folder(parent, "MysteryEgg")
	local color = hex(egg.color)
	local look = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(faceX, y, faceZ))
	-- Campfire stones under the pan.
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		ball(
			f,
			2,
			(look * CFrame.new(math.cos(a) * 8, 0.6, math.sin(a) * 8)).Position,
			hex("#9AA3B5"),
			Enum.Material.Slate
		).CanCollide =
			false
	end
	local pan = cyl(f, 9, 1.4, look * CFrame.new(0, 2, 0), hex("#3B4356"), Enum.Material.Metal)
	pan.Name = "Pan"
	cyl(f, 8.2, 0.3, look * CFrame.new(0, 3.3, 0), hex("#55607A"), Enum.Material.Metal, false)
	rod(
		f,
		(look * CFrame.new(0, 3, 9)).Position,
		(look * CFrame.new(0, 3.8, 19)).Position,
		0.8,
		hex("#3B4356"),
		Enum.Material.Metal
	)
	rod(
		f,
		(look * CFrame.new(0, 3.8, 15)).Position,
		(look * CFrame.new(0, 4.2, 19.5)).Position,
		1,
		WOOD,
		Enum.Material.Wood
	)
	local shell = part(f, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 9, 7),
		CFrame = look * CFrame.new(0, 8, 0),
		Color = hex("#FFF6E6"),
		CanCollide = false,
	})
	shell.Name = "Egg"
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local hgt = (k % 3 - 1) * 1.8
		nocollide(ball(f, 1.2, (look * CFrame.new(math.cos(a) * 3.3, 8 + hgt, math.sin(a) * 3.3)).Position, color))
	end
	local pp = prompt(pan, "Egg", "Hatch", egg.name .. "  ·  🍁 " .. Format.abbreviate(egg.cost), 18)
	pp:SetAttribute("EggId", eggId)
	billboard(pan, egg.name, Vector3.new(0, 15, 0), Vector2.new(300, 64), color)
	return Vector3.new(x, y + 3, z)
end

---------------------------------------------------------------------------------------------------
-- Ramps and ice gates
---------------------------------------------------------------------------------------------------
local function buildRamp(parent: Instance, gates: Instance, zone: Zones.Zone)
	local f = folder(parent, "Ramp_" .. zone.id)
	local r = ZoneGeo.ramp(zone.id)
	local a = Vector3.new(r.ax, r.ay, r.az)
	local b = Vector3.new(r.bx, r.by, r.bz)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local w = Zones.RampWidth
	-- Snowy wooden planks in short segments so the ramp climbs smoothly.
	local n = math.ceil(r.length / 6)
	for i = 0, n - 1 do
		local p0, p1 = a:Lerp(b, i / n), a:Lerp(b, (i + 1) / n)
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, mid + (p1 - p0))
		local plank = block(
			f,
			Vector3.new(w, 1, (p1 - p0).Magnitude + 0.1),
			cf * CFrame.new(0, -0.5, 0),
			WOOD:Lerp(WOOD_LIGHT, (i % 3) * 0.3),
			Enum.Material.WoodPlanks
		)
		plank.Name = "Plank"
		local snow = block(
			f,
			Vector3.new(w - 6, 0.2, (p1 - p0).Magnitude + 0.1),
			cf * CFrame.new(0, 0.02, 0),
			SNOW,
			Enum.Material.Snow,
			false
		)
		snow.CastShadow = false
	end
	-- Posts with rope rails, and lanterns every few posts.
	local posts = math.ceil(r.length / 12)
	local prevL, prevR
	for i = 0, posts do
		local p = a:Lerp(b, i / posts)
		local pl, pr = p + side * (w / 2 - 0.6), p - side * (w / 2 - 0.6)
		rod(f, pl - Vector3.new(0, 30, 0), pl + Vector3.new(0, 3.5, 0), 0.6, WOOD, Enum.Material.Wood)
		rod(f, pr - Vector3.new(0, 30, 0), pr + Vector3.new(0, 3.5, 0), 0.6, WOOD, Enum.Material.Wood)
		nocollide(ball(f, 1.4, pl + Vector3.new(0, 3.8, 0), SNOW, Enum.Material.Snow))
		nocollide(ball(f, 1.4, pr + Vector3.new(0, 3.8, 0), SNOW, Enum.Material.Snow))
		local topL, topR = pl + Vector3.new(0, 3, 0), pr + Vector3.new(0, 3, 0)
		if prevL then
			nocollide(rod(f, prevL, topL, 0.22, hex("#E5484D"), Enum.Material.Fabric))
			nocollide(rod(f, prevR, topR, 0.22, hex("#E5484D"), Enum.Material.Fabric))
		end
		prevL, prevR = topL, topR
		if i % 3 == 1 then
			lantern(f, pl.X + side.X * 1.5, pl.Y, pl.Z + side.Z * 1.5)
		end
	end
	if zone.order == 1 then
		return
	end
	-- Ice gate: an arch with a wall of ice that only shows (and blocks you) until the zone is yours.
	-- The server bounces trespassers regardless of what the client draws.
	local g = folder(gates, zone.id)
	g:SetAttribute("ZoneId", zone.id)
	local gp = a:Lerp(b, 0.93)
	local gcf = CFrame.lookAt(gp, gp + flat)
	local accent = hex(zone.accent)
	for s = -1, 1, 2 do
		local post = cyl(g, 1.4, 17, gcf * CFrame.new(s * (w / 2 + 0.6), 0, 0), accent)
		post.Name = "Post"
		nocollide(ball(g, 3.2, (gcf * CFrame.new(s * (w / 2 + 0.6), 17.4, 0)).Position, SNOW, Enum.Material.Snow))
	end
	local beam = block(g, Vector3.new(w + 4, 2.4, 2.4), gcf * CFrame.new(0, 16, 0), accent)
	beam.Name = "Beam"
	local sheet = block(g, Vector3.new(w, 15, 1.2), gcf * CFrame.new(0, 7.5, 0), ICE, Enum.Material.Ice, false)
	sheet.Name = "Sheet"
	sheet.Transparency = 0.3
	sheet.CastShadow = false
	local pp = prompt(sheet, "Gate", "Unlock", zone.name .. "  ·  🍁 " .. Format.abbreviate(zone.unlockCost), 20)
	pp:SetAttribute("ZoneId", zone.id)
	local sign = billboard(
		beam,
		zone.name .. "\n🍁 " .. Format.abbreviate(zone.unlockCost),
		Vector3.new(0, 8, 0),
		Vector2.new(360, 110),
		accent
	)
	sign.Name = "Sign"
end

---------------------------------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------------------------------
-- A random spot on the zone away from the plaza, the Yetis, the egg and the entrance path.
local function propSpot(zone: Zones.Zone, minR: number?, maxR: number?): (number?, number?)
	local lm = ZoneGeo.landmarks(zone.id)
	local yetis = ZoneGeo.yetis(zone.id)
	local ux, uz = ZoneGeo.towardHub(zone.id)
	for _ = 1, 25 do
		local x, z = onDisc(zone.center.x, zone.center.z, zone.radius - 8)
		local dc = math.sqrt((x - zone.center.x) ^ 2 + (z - zone.center.z) ^ 2)
		local ok = dc > (minR or Zones.PlazaRadius + 10) and dc < (maxR or zone.radius - 8)
		for _, y in yetis do
			if (x - y.x) ^ 2 + (z - y.z) ^ 2 < 24 ^ 2 then
				ok = false
			end
		end
		if (x - lm.egg.x) ^ 2 + (z - lm.egg.z) ^ 2 < 26 ^ 2 then
			ok = false
		end
		-- Keep the entrance lane (center -> entrance) clear.
		local rx, rz = x - zone.center.x, z - zone.center.z
		local along = rx * ux + rz * uz
		local across = math.abs(rx * uz - rz * ux)
		if along > 0 and across < 16 then
			ok = false
		end
		if ok then
			return x, z
		end
	end
	return nil, nil
end

local DECOR: { [string]: (Instance, Zones.Zone) -> () } = {}

DECOR.MapleMeadow = function(f, zone)
	local y = zone.center.y
	for _ = 1, 12 do
		local x, z = propSpot(zone)
		if x and z then
			maple(f, x, y, z, rng:NextNumber(16, 24))
		end
	end
	for _ = 1, 4 do
		local x, z = propSpot(zone)
		if x and z then
			snowman(f, x, y, z, rng:NextNumber(0.9, 1.3))
		end
	end
	-- A sugar shack with a maple sap bucket.
	local x, z = propSpot(zone, zone.radius * 0.7)
	if x and z then
		chalet(f, x, y, z, zone.center.x, zone.center.z, 1, hex("#F2A33A"))
	end
end

DECOR.PineconeVillage = function(f, zone)
	local y = zone.center.y
	for _ = 1, 4 do
		local x, z = propSpot(zone, zone.radius * 0.62)
		if x and z then
			chalet(f, x, y, z, zone.center.x, zone.center.z, rng:NextNumber(0.9, 1.2))
		end
	end
	for _ = 1, 16 do
		local x, z = propSpot(zone)
		if x and z then
			pine(f, x, y, z, rng:NextNumber(18, 30))
		end
	end
	for _ = 1, 6 do
		local x, z = propSpot(zone)
		if x and z then
			lantern(f, x, y, z)
		end
	end
end

DECOR.FrostyFalls = function(f, zone)
	local y = zone.center.y
	-- A frozen waterfall at the back of the zone, pouring off an ice cliff.
	local ux, uz = ZoneGeo.towardHub(zone.id)
	local bx, bz = zone.center.x - ux * (zone.radius - 10), zone.center.z - uz * (zone.radius - 10)
	local look = CFrame.lookAt(Vector3.new(bx, y, bz), Vector3.new(zone.center.x, y, zone.center.z))
	block(f, Vector3.new(60, 40, 14), look * CFrame.new(0, 20, 6), ROCK:Lerp(ICE, 0.3), Enum.Material.Glacier)
	for k = -3, 3 do
		local fall = block(
			f,
			Vector3.new(5, 38, 3),
			look * CFrame.new(k * 6, 19, -2),
			ICE:Lerp(WHITE, (k % 2) * 0.3),
			Enum.Material.Ice,
			false
		)
		fall.Transparency = 0.2
		fall.Name = "Icefall"
	end
	local pool = cyl(f, 18, 0.4, look * CFrame.new(0, 0, -16), ICE, Enum.Material.Ice)
	pool.Name = "FrozenPool"
	for _ = 1, 10 do
		local x, z = propSpot(zone)
		if x and z then
			pine(f, x, y, z, rng:NextNumber(16, 26), hex("#5E9C8A"))
		end
	end
	for _ = 1, 10 do
		local x, z = propSpot(zone)
		if x and z then
			crystal(f, x, y, z, rng:NextNumber(0.8, 1.5), ICE)
		end
	end
end

DECOR.CocoaCliffs = function(f, zone)
	local y = zone.center.y
	for _ = 1, 4 do
		local x, z = propSpot(zone, Zones.PlazaRadius + 14)
		if x and z then
			-- A steaming cocoa spring: a ring of red rocks around a hot chocolate pool.
			local r = rng:NextNumber(6, 9)
			local spring = cyl(f, r, 0.6, CFrame.new(x, y, z), hex("#6B3F26"), Enum.Material.Glass, false)
			spring.Name = "CocoaSpring"
			spring.Transparency = 0.05
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				rock(f, x + math.cos(a) * (r + 1), y, z + math.sin(a) * (r + 1), 2.2, hex("#B5653A"))
			end
			cyl(f, r * 0.4, 0.7, CFrame.new(x + r * 0.2, y, z), hex("#FFF6EA"), Enum.Material.SmoothPlastic, false)
		end
	end
	for _ = 1, 10 do
		local x, z = propSpot(zone)
		if x and z then
			rock(f, x, y, z, rng:NextNumber(3, 7), hex("#B5653A"))
		end
	end
	for _ = 1, 6 do
		local x, z = propSpot(zone)
		if x and z then
			pine(f, x, y, z, rng:NextNumber(14, 22), hex("#3F7A55"))
		end
	end
end

DECOR.AuroraSummit = function(f, zone)
	local y = zone.center.y
	for _ = 1, 16 do
		local x, z = propSpot(zone)
		if x and z then
			crystal(
				f,
				x,
				y,
				z,
				rng:NextNumber(1, 2.2),
				if rng:NextNumber() < 0.5 then hex("#BFF3E6") else hex("#C9B8FF")
			)
		end
	end
	for _ = 1, 8 do
		local x, z = propSpot(zone)
		if x and z then
			pine(f, x, y, z, rng:NextNumber(16, 24), hex("#4A6FA5"))
		end
	end
	for _ = 1, 6 do
		local x, z = propSpot(zone)
		if x and z then
			lantern(f, x, y, z)
		end
	end
end

local function plateau(f: Instance, cx: number, cz: number, radius: number, top: number, ground: Color3, cliff: Color3)
	-- A rock column down into the clouds, with a snow cap and a wavy snow rim.
	local body = cyl(f, radius + 3, top - CLOUD_Y + 20, CFrame.new(cx, CLOUD_Y - 20, cz), cliff, Enum.Material.Slate)
	body.Name = "Cliff"
	local lower =
		cyl(f, radius * 0.8, 30, CFrame.new(cx, CLOUD_Y - 40, cz), cliff:Lerp(INK, 0.15), Enum.Material.Slate, false)
	lower.CastShadow = false
	local g = cyl(f, radius, 1, CFrame.new(cx, top - 1, cz), ground, Enum.Material.Snow)
	g.Name = "Ground"
	local n = math.floor(radius / 3.5)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		nocollide(
			ball(
				f,
				rng:NextNumber(5, 8),
				Vector3.new(cx + math.cos(a) * (radius + 1.5), top - 1.2, cz + math.sin(a) * (radius + 1.5)),
				SNOW:Lerp(SNOW_SHADE, rng:NextNumber(0, 0.6)),
				Enum.Material.Snow
			)
		).CastShadow =
			false
	end
end

local function buildZone(map: Instance, gates: Instance, zone: Zones.Zone, built: Built)
	local f = folder(map, zone.id)
	local c = zone.center
	local accent = hex(zone.accent)
	local cliffColor = if zone.id == "CocoaCliffs"
		then hex("#B5653A")
		elseif zone.id == "AuroraSummit" then hex("#6E6A9E")
		elseif zone.id == "FrostyFalls" then hex("#8FB3C9")
		else ROCK
	plateau(f, c.x, c.z, zone.radius, c.y, hex(zone.ground), cliffColor)

	-- The plaza: a round wooden deck with a giant empty plate (where the Great Yeti sits).
	local lm = ZoneGeo.landmarks(zone.id)
	local pr = Zones.PlazaRadius
	local deck = cyl(f, pr + 2, 0.5, CFrame.new(lm.plaza.x, c.y, lm.plaza.z), WOOD_LIGHT, Enum.Material.WoodPlanks)
	deck.Name = "Plaza"
	local plate =
		cyl(f, pr - 4, 0.4, CFrame.new(lm.plaza.x, c.y + 0.5, lm.plaza.z), WHITE, Enum.Material.SmoothPlastic, false)
	plate.Name = "GreatPlate"
	cyl(
		f,
		pr - 6,
		0.42,
		CFrame.new(lm.plaza.x, c.y + 0.5, lm.plaza.z),
		hex(zone.batter):Lerp(WHITE, 0.6),
		Enum.Material.SmoothPlastic,
		false
	)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.2
		lantern(f, lm.plaza.x + math.cos(a) * (pr + 4), c.y, lm.plaza.z + math.sin(a) * (pr + 4))
	end

	-- Yeti tables.
	local yetis = folder(f, "Yetis")
	for _, y in ZoneGeo.yetis(zone.id) do
		buildYetiTable(yetis, zone, y)
	end

	-- Mystery Egg beside the entrance, facing the arrival path.
	built.eggs[zone.egg] = buildEgg(f, zone.egg, lm.egg.x, c.y, lm.egg.z, lm.entrance.x, lm.entrance.z)

	-- Welcome sign at the top of the ramp, with a decorative pancake stack in the zone's flavor.
	local signPost =
		cyl(f, 0.6, 10, CFrame.new(lm.entrance.x, c.y, lm.entrance.z) * CFrame.new(-15, 0, 0), WOOD, Enum.Material.Wood)
	billboard(signPost, zone.name, Vector3.new(0, 8, 0), Vector2.new(320, 70), accent)
	pancakeTower(f, lm.entrance.x + 15, c.y, lm.entrance.z, 3, 8, hex(zone.batter), hex(zone.crust))

	local decor = DECOR[zone.id]
	if decor then
		decor(f, zone)
	end

	buildRamp(map, gates, zone)
	built.zoneSpawns[zone.id] =
		CFrame.lookAt(Vector3.new(lm.spawn.x, c.y + 3, lm.spawn.z), Vector3.new(c.x, c.y + 3, c.z))
end

---------------------------------------------------------------------------------------------------
-- Base Camp
---------------------------------------------------------------------------------------------------
local function buildHub(map: Instance, built: Built)
	local f = folder(map, "BaseCamp")
	local hub = Zones.Hub
	local y = hub.center.y
	plateau(f, 0, 0, hub.radius, y, SNOW, ROCK)
	-- A compass of colored paths pointing at each zone's ramp.
	for _, zone in Zones.List do
		local ux, uz = ZoneGeo.towardHub(zone.id)
		local p = Vector3.new(-ux * 22, y + 0.03, -uz * 22)
		local tile = cyl(f, 5, 0.1, CFrame.new(p), hex(zone.accent), Enum.Material.SmoothPlastic, false)
		tile.CastShadow = false
		local arrow = block(
			f,
			Vector3.new(3, 0.12, 10),
			CFrame.lookAt(Vector3.new(p.X * 1.6, y + 0.08, p.Z * 1.6), Vector3.new(p.X * 3, y + 0.08, p.Z * 3)),
			hex(zone.accent),
			Enum.Material.SmoothPlastic,
			false
		)
		arrow.CastShadow = false
	end
	-- The Pancake Monument in the middle.
	local top = pancakeTower(f, 0, y, 0, 6, 14, hex("#F7C873"), hex("#C9822F"))
	local anchor = block(f, Vector3.new(1, 1, 1), CFrame.new(0, top + 2, 0), WHITE, Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	billboard(anchor, "PANCAKE PEAK", Vector3.new(0, 8, 0), Vector2.new(460, 100), hex("#F2A33A"))

	-- Chalets and pines around the edge, clear of the ramps.
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + 0.25
		local d = hub.radius - 9
		local x, z = math.cos(a) * d, math.sin(a) * d
		local nearRamp = false
		for _, zone in Zones.List do
			local ux, uz = ZoneGeo.towardHub(zone.id)
			local ra = math.atan2(-uz, -ux)
			local diff = math.abs((a - ra + math.pi) % (2 * math.pi) - math.pi)
			if diff < 0.4 then
				nearRamp = true
			end
		end
		local nearSpawn = z < -10 and math.abs(x) < 20
		if not nearRamp and not nearSpawn then
			if k % 3 == 0 then
				chalet(f, x, y, z, 0, 0, 0.8)
			else
				pine(f, x, y, z, rng:NextNumber(18, 26))
			end
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, y + 0.1, -26)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = f
	-- Spawn facing Maple Meadow (to the north), so the first Yetis are straight ahead.
	built.hubSpawn = CFrame.lookAt(Vector3.new(0, y + 3, -26), Vector3.new(0, y + 3, -230))

	-- Leaderboards: three wooden signboards with snowy roofs on the south side, facing the center.
	for i, b in Leaderboards.Boards do
		local a = math.rad(60 + (i - 1) * 30)
		local pos = Vector3.new(math.cos(a) * (hub.radius - 14), y, math.sin(a) * (hub.radius - 14))
		local look = CFrame.lookAt(pos, Vector3.new(0, y, 0))
		local color = hex(b.color)
		for s = -1, 1, 2 do
			cyl(f, 0.6, 26, look * CFrame.new(s * 8, 0, 0.6), WOOD, Enum.Material.Wood)
		end
		block(f, Vector3.new(16, 24, 1), look * CFrame.new(0, 14, 0.6), WOOD_LIGHT, Enum.Material.WoodPlanks)
		block(f, Vector3.new(18, 1.2, 3), look * CFrame.new(0, 26.4, 0.6), color)
		block(f, Vector3.new(18.4, 0.6, 3.4), look * CFrame.new(0, 27.2, 0.6), SNOW, Enum.Material.Snow, false)
		local canvas = block(
			f,
			Vector3.new(14, 22, 0.3),
			look * CFrame.new(0, 14, 0),
			hex("#FFF8EC"),
			Enum.Material.SmoothPlastic,
			false
		)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 26
		gui.LightInfluence = 0.3
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.14)
		title.BackgroundTransparency = 1
		title.Font = FONT
		title.TextScaled = true
		title.Text = b.title
		title.TextColor3 = color
		title.TextStrokeColor3 = INK
		title.TextStrokeTransparency = 0
		title.Parent = gui
		local list = Instance.new("Frame")
		list.Name = "List"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromScale(0.06, 0.16)
		list.Size = UDim2.fromScale(0.88, 0.82)
		list.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		gui.Parent = canvas
		built.boards[b.title] = gui
	end
end

---------------------------------------------------------------------------------------------------
-- The sea of clouds and Pancake Peak
---------------------------------------------------------------------------------------------------
local function buildSky(map: Instance)
	local f = folder(map, "Clouds")
	local floor =
		block(f, Vector3.new(2048, 2, 2048), CFrame.new(0, CLOUD_Y - 1, 0), CLOUD, Enum.Material.SmoothPlastic, false)
	floor.Name = "CloudSea"
	floor.Transparency = 0.15
	floor.CastShadow = false
	floor.CanQuery = false
	-- Puffy cloud mounds on the cloud sea.
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(80, 700)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if not ZoneGeo.onLand(x, z) then
			local s = rng:NextNumber(14, 34)
			local puff = ball(f, s, Vector3.new(x, CLOUD_Y + s * 0.15, z), CLOUD, Enum.Material.SmoothPlastic)
			puff.CanCollide = false
			puff.CastShadow = false
			puff.Transparency = 0.05
		end
	end
	-- Pancake Peak: a huge snowy mountain behind Maple Meadow, with a syrup-gold summit.
	local peak = folder(map, "PancakePeak")
	local px, pz = -40, -620
	local tiers = 9
	for i = 0, tiers - 1 do
		local t = i / tiers
		local r = 260 * (1 - t) ^ 1.15 + 18
		local h = 40
		local color = if t > 0.55 then SNOW else ROCK:Lerp(SNOW, t * 0.8)
		local tier = cyl(
			peak,
			r,
			h,
			CFrame.new(px, CLOUD_Y - 20 + i * h, pz),
			color,
			if t > 0.55 then Enum.Material.Snow else Enum.Material.Slate,
			false
		)
		tier.CastShadow = false
	end
	nocollide(ball(peak, 60, Vector3.new(px, CLOUD_Y - 20 + tiers * 40, pz), SNOW, Enum.Material.Snow))
	-- A ring of smaller distant peaks on the horizon.
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + 0.3
		local d = rng:NextNumber(780, 900)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local r = rng:NextNumber(80, 140)
		for i = 0, 4 do
			local t = i / 5
			local tier = cyl(
				f,
				r * (1 - t) + 8,
				30,
				CFrame.new(x, CLOUD_Y - 10 + i * 30, z),
				if t > 0.5 then SNOW else ROCK:Lerp(SNOW, t),
				Enum.Material.Snow,
				false
			)
			tier.CastShadow = false
		end
	end
end

function MapBuilder.Build(): Built
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	local gates = folder(map, "Gates")
	local built: Built = {
		hubSpawn = CFrame.new(0, 7, -26),
		zoneSpawns = {},
		eggs = {},
		boards = {},
	}
	buildSky(map)
	buildHub(map, built)
	for _, zone in Zones.List do
		buildZone(map, gates, zone, built)
	end
	map.Parent = workspace
	return built
end

return MapBuilder
