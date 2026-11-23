--!strict
-- Draws every player's pancake tower. Each player carries a wooden tray over their head; the
-- server's Stack events (Net.StackKinds) arrive here and are mirrored as plain Logic/Stack states,
-- so the sliding pancake is computed every frame from the shared server clock exactly like the
-- server does: nothing per-frame is replicated.
--
-- The local player's drops are predicted instantly with the same Stack.drop the server runs, then
-- corrected when the server's answer arrives (a prediction the server never confirms expires).
-- Towers lean with their owner's movement through one spring per player, sliced overhangs fall off
-- as debris, a topple scatters the whole tower, and a serve flies the pancakes into a Yeti's mouth.
-- Far towers are hidden; mid-range (or other players' towers in performance mode) draw as a single
-- column. Everything is pooled and moved with one BulkMoveTo per frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Zones = require(Shared:WaitForChild("Config"):WaitForChild("Zones"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Stack"))
local Stack = require(Shared:WaitForChild("Logic"):WaitForChild("Stack"))
local ZoneGeo = require(Shared:WaitForChild("Logic"):WaitForChild("ZoneGeo"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local StackRenderer = {}
-- (kind: "perfect" | "good" | "topple", count, combo) after each local drop (predicted).
StackRenderer.Dropped = Signal.new()
-- Fires whenever the local tower's height changes (count).
StackRenderer.HeightChanged = Signal.new()

local K = Net.StackKinds
local C: any
local hex = Color3.fromHex
local me = Players.LocalPlayer
local H = Cfg.LayerHeight
local TRAY_UP = 3.4 -- tray height above the root part
local FULL_RADIUS = 75 -- full detail within this distance
local VISIBLE_RADIUS = 170
local PREDICT_TTL = 0.9

local WHITE = hex("#FFFFFF")
local BUTTER = hex("#FFE27A")
local SPRINKLE = hex("#FF9FB8")
local WOOD = hex("#C98B55")

type Pending = { t: number, at: number }
type Tower = {
	userId: number,
	auth: Stack.State?, -- what the server last told us
	view: Stack.State?, -- auth + local predictions (local player) or auth (others)
	pending: { Pending },
	model: Model,
	tray: Part,
	slider: Part,
	butter: Part,
	column: Part,
	parts: { Part }, -- one per layer, pooled
	leanX: number,
	leanZ: number,
	velX: number,
	velZ: number,
	lastPos: Vector3?,
	mode: string, -- "full" | "column" | "hidden"
	flying: boolean,
}

local towers: { [number]: Tower } = {}
local pool: { Part } = {}
local folder: Folder
local window = 0.16
local slide = 1

local function flavorColors(flavor: number): (Color3, Color3)
	local z = Zones.List[flavor] or Zones.List[1]
	return hex(z.batter), hex(z.crust)
end

local function newPart(name: string, shape: Enum.PartType, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function takeLayerPart(): Part
	local p = table.remove(pool)
	if p then
		return p
	end
	return newPart("Pancake", Enum.PartType.Cylinder, WHITE, Enum.Material.SmoothPlastic)
end

local function styleLayer(p: Part, l: Stack.Layer)
	local batter, crust = flavorColors(l.flavor)
	-- Perfect pancakes come out golden; sprinkle pancakes are pink and sparkly.
	p.Color = if l.sprinkle then SPRINKLE elseif l.perfect then batter:Lerp(BUTTER, 0.35) else batter:Lerp(crust, 0.25)
	p.Material = if l.sprinkle then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Size = Vector3.new(H, l.r * 2, l.r * 2)
end

local function cloneState(st: Stack.State): Stack.State
	local layers = table.clone(st.layers)
	local c = table.clone(st)
	c.layers = layers
	return c
end

local function fromWire(w: any): Stack.State
	local st = Stack.new(w.base)
	for _, l in w.layers do
		local layer: Stack.Layer = {
			x = l[1],
			z = l[2],
			r = l[3],
			perfect = l[4] == 1,
			sprinkle = l[5] == 1,
			fluff = Stack.fluffOf(l[3], w.base, l[4] == 1, l[5] == 1),
			flavor = l[6],
		}
		table.insert(st.layers, layer)
		st.topX, st.topZ, st.topR = layer.x, layer.z, layer.r
	end
	st.combo = w.combo or 0
	Stack.arm(st, w.st, w.sp, w.sk == true)
	return st
end

local function currentFlavor(): number
	local id = C.WorldFX:CurrentZone()
	local z = Zones.ById[id]
	if z then
		return z.order
	end
	local best = 1
	for _, zone in Zones.List do
		if C.State:Owns(zone.id) then
			best = math.max(best, zone.order)
		end
	end
	return best
end

local function getTower(userId: number): Tower
	local t = towers[userId]
	if t then
		return t
	end
	local model = Instance.new("Model")
	model.Name = "Stack_" .. userId
	local tray = newPart("Tray", Enum.PartType.Cylinder, WOOD, Enum.Material.WoodPlanks)
	tray.Parent = model
	local slider = newPart("Slider", Enum.PartType.Cylinder, WHITE)
	slider.Parent = model
	local butter = newPart("Butter", Enum.PartType.Block, BUTTER)
	butter.Size = Vector3.new(0.5, 0.18, 0.5)
	butter.Parent = model
	local column = newPart("Column", Enum.PartType.Cylinder, hex("#F7C873"))
	column.Parent = model
	model.Parent = folder
	t = {
		userId = userId,
		auth = nil,
		view = nil,
		pending = {},
		model = model,
		tray = tray,
		slider = slider,
		butter = butter,
		column = column,
		parts = {},
		leanX = 0,
		leanZ = 0,
		velX = 0,
		velZ = 0,
		lastPos = nil,
		mode = "hidden",
		flying = false,
	}
	towers[userId] = t
	return t
end

local function releaseLayers(t: Tower)
	for _, p in t.parts do
		p.Parent = nil
		table.insert(pool, p)
	end
	table.clear(t.parts)
end

-- Rebuild the visible layer parts to match t.view (cheap: only restyles what changed).
local function syncParts(t: Tower)
	local st = t.view
	local n = if st then #st.layers else 0
	while #t.parts > n do
		local p = table.remove(t.parts) :: Part
		p.Parent = nil
		table.insert(pool, p)
	end
	if not st then
		return
	end
	for i = 1, n do
		local p = t.parts[i]
		if not p then
			p = takeLayerPart()
			t.parts[i] = p
		end
		styleLayer(p, st.layers[i])
		if t.mode == "full" then
			p.Parent = t.model
		end
	end
	t.column.Size = Vector3.new(math.max(n, 1) * H, st.baseR * 1.6, st.baseR * 1.6)
	t.tray.Size = Vector3.new(0.3, st.baseR * 2 + 0.8, st.baseR * 2 + 0.8)
	if t.userId == me.UserId then
		StackRenderer.HeightChanged:Fire(n)
	end
end

-- Recompute the local player's predicted view from the server state plus pending drops.
local function rebuildView(t: Tower)
	local auth = t.auth
	if not auth then
		t.view = nil
		syncParts(t)
		return
	end
	if #t.pending == 0 then
		t.view = auth
		syncParts(t)
		return
	end
	local v = cloneState(auth)
	for _, p in t.pending do
		local r = Stack.drop(v, p.t, window, currentFlavor())
		if r.kind == "topple" then
			-- The server will send the topple; until then show the tower as it was.
			v = cloneState(auth)
			break
		end
		Stack.arm(v, p.t + Cfg.NextDelay, Stack.speedFor(#v.layers, slide), false)
	end
	t.view = v
	syncParts(t)
end

local function trayFrame(_t: Tower, root: BasePart): CFrame
	-- The tray stays world-aligned (it doesn't spin with the character) so the slide axes are
	-- always the world's X and Z: easier to read from any camera angle.
	return CFrame.new(root.CFrame.Position + Vector3.new(0, TRAY_UP, 0))
end

-- World CFrame of layer height h (studs above the tray) at tray position x, z with the tower lean.
local function layerCFrame(t: Tower, tray: CFrame, x: number, z: number, h: number): CFrame
	-- Lean grows with the square of height, so tall towers wobble from the top.
	local k = h * h * 0.004
	return tray * CFrame.new(x + t.leanX * k, h, z + t.leanZ * k) * CFrame.Angles(0, 0, math.rad(90))
end

local function rootOf(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------------------------------
local function nearMe(pos: Vector3, radius: number): boolean
	local root = C.Effects:LocalRoot()
	return root ~= nil and (root.CFrame.Position - pos).Magnitude < radius
end

-- A sliced-off crescent: a thin piece falls off the side it overhung and fades.
local function debris(t: Tower, offset: number, cut: number, n: number, flavor: number)
	if t.mode ~= "full" or cut <= 0.02 then
		return
	end
	local root = rootOf(t.userId)
	local st = t.view
	if not root or not st then
		return
	end
	local ax, az = Stack.axis(n - 1)
	local tray = trayFrame(t, root)
	local layer = st.layers[n]
	if not layer then
		return
	end
	local side = if offset >= 0 then 1 else -1
	local edge = layer.r + cut / 2
	local cf = layerCFrame(t, tray, layer.x + ax * side * edge, layer.z + az * side * edge, (n - 0.5) * H)
	local batter = flavorColors(flavor)
	local p = newPart("Slice", Enum.PartType.Block, batter)
	p.Size = Vector3.new(cut * (if ax ~= 0 then 1 else 1.6), H, cut * (if az ~= 0 then 1 else 1.6))
		+ Vector3.new(0.05, 0, 0.05)
	p.CFrame = CFrame.new(cf.Position)
	p.Parent = workspace
	local fall = p.CFrame.Position + Vector3.new(ax * side * 3, -TRAY_UP - n * H - 1, az * side * 3)
	TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(fall) * CFrame.Angles(math.rad(side * 120), 0, math.rad(side * 80)),
		Transparency = 1,
	}):Play()
	task.delay(0.75, function()
		p:Destroy()
	end)
end

-- The whole tower tumbles off the tray in every direction.
local function scatter(t: Tower)
	local root = rootOf(t.userId)
	if not root or t.mode == "hidden" then
		return
	end
	local pos = root.CFrame.Position
	local near = nearMe(pos, 120)
	for i, p in t.parts do
		local piece = p:Clone()
		piece.Parent = workspace
		local a = math.random() * math.pi * 2
		local d = 4 + math.random() * 6 + i * 0.1
		local target = Vector3.new(pos.X + math.cos(a) * d, pos.Y - 2.5, pos.Z + math.sin(a) * d)
		TweenService
			:Create(piece, TweenInfo.new(0.6 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3),
			})
			:Play()
		task.delay(1.2, function()
			TweenService:Create(piece, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		task.delay(1.75, function()
			piece:Destroy()
		end)
	end
	if near then
		C.Effects:Puff(pos + Vector3.new(0, 2, 0), 1.5, 14)
	end
end

-- Pancakes leap one by one from the tray into the Yeti's mouth.
local function flyToYeti(t: Tower, x: number, z: number, great: boolean)
	local root = rootOf(t.userId)
	if not root or t.mode == "hidden" then
		return
	end
	local target: Vector3
	local mouth = if great then C.OrderRenderer:MouthPosition() else nil
	if mouth then
		target = mouth
	else
		local zone = ZoneGeo.zoneAt(x, root.CFrame.Position.Y, z)
		local y = if zone then Zones.ById[zone].center.y else root.CFrame.Position.Y - 3
		target = Vector3.new(x, y + 8, z)
	end
	local pieces = {}
	for _, p in t.parts do
		local piece = p:Clone()
		piece.Parent = workspace
		table.insert(pieces, piece)
	end
	local isMe = t.userId == me.UserId
	t.flying = true
	task.spawn(function()
		local gap = math.clamp(0.9 / math.max(#pieces, 1), 0.02, 0.08)
		for i = #pieces, 1, -1 do
			local piece = pieces[i]
			local from = piece.CFrame.Position
			local mid = from:Lerp(target, 0.5) + Vector3.new(0, 6, 0)
			task.spawn(function()
				for k = 1, 10 do
					local a = k / 10
					local p1 = from:Lerp(mid, a)
					local p2 = mid:Lerp(target, a)
					piece.CFrame = CFrame.new(p1:Lerp(p2, a)) * CFrame.Angles(0, 0, math.rad(90) + a * 6)
					piece.Size = piece.Size * 0.97
					task.wait(1 / 30)
				end
				piece:Destroy()
				if isMe and i % 3 == 1 then
					C.Audio:Play("Chomp", { pitch = 0.9 + math.random() * 0.3, volume = 0.6 })
				end
			end)
			task.wait(gap)
		end
		t.flying = false
	end)
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local function onEvent(userId: number, ev: any)
	local t = getTower(userId)
	local isMe = userId == me.UserId
	if ev.k == K.Reset then
		if ev.gone then
			releaseLayers(t)
			t.model:Destroy()
			towers[userId] = nil
			return
		end
		t.auth = fromWire(ev)
		table.clear(t.pending)
		rebuildView(t)
	elseif ev.k == K.Drop then
		local auth = t.auth
		if not auth then
			return
		end
		local l = ev.l
		local layer: Stack.Layer = {
			x = l[1],
			z = l[2],
			r = l[3],
			perfect = l[4] == 1,
			sprinkle = l[5] == 1,
			fluff = Stack.fluffOf(l[3], auth.baseR, l[4] == 1, l[5] == 1),
			flavor = l[6],
		}
		-- Trust the server's count: overwrite (or append) layer n.
		while #auth.layers >= ev.n do
			table.remove(auth.layers)
		end
		table.insert(auth.layers, layer)
		auth.topX, auth.topZ, auth.topR = layer.x, layer.z, layer.r
		auth.combo = ev.combo
		Stack.arm(auth, ev.st, ev.sp, ev.sk == true)
		if isMe then
			-- One prediction confirmed.
			table.remove(t.pending, 1)
			rebuildView(t)
		else
			t.view = auth
			syncParts(t)
			if t.mode == "full" then
				local root = rootOf(userId)
				if root and nearMe(root.CFrame.Position, 60) then
					C.Audio:PlayStep(ev.n, if layer.perfect then "Perfect" else "Drop", 0.35)
				end
				debris(t, ev.off, ev.cut, ev.n, layer.flavor)
			end
		end
	elseif ev.k == K.Topple then
		scatter(t)
		table.clear(t.pending)
		if isMe then
			C.Audio:Play("Topple")
			C.Effects:Punch(0.6)
			local root = C.Effects:LocalRoot()
			if root then
				C.Effects:Pop(root.CFrame.Position + Vector3.new(0, TRAY_UP + 2, 0), "TOPPLE!", hex("#E5484D"), 1.6, -8)
			end
			StackRenderer.Dropped:Fire("topple", 0, 0)
		end
		if t.auth then
			table.clear((t.auth :: Stack.State).layers)
		end
		t.view = t.auth
		syncParts(t)
	elseif ev.k == K.Served then
		flyToYeti(t, ev.x, ev.z, ev.great == true)
		table.clear(t.pending)
		if t.auth then
			table.clear((t.auth :: Stack.State).layers)
		end
		t.view = t.auth
		syncParts(t)
	end
end

---------------------------------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------------------------------
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function setMode(t: Tower, mode: string)
	if t.mode == mode then
		return
	end
	t.mode = mode
	local full = mode == "full"
	for _, p in t.parts do
		p.Parent = if full then t.model else nil
	end
	t.slider.Parent = if full then t.model else nil
	t.butter.Parent = if full then t.model else nil
	t.column.Parent = if mode == "column" then t.model else nil
	t.tray.Parent = if mode ~= "hidden" then t.model else nil
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local camPos = camera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local perf = C.State:Setting("performance")
	local clock = os.clock()
	table.clear(bulkParts)
	table.clear(bulkCFrames)
	local n = 0
	local function put(p: BasePart, cf: CFrame)
		n += 1
		bulkParts[n] = p
		bulkCFrames[n] = cf
	end
	for userId, t in towers do
		local root = rootOf(userId)
		local st = t.view
		if not root or not st then
			setMode(t, "hidden")
			continue
		end
		local isMe = userId == me.UserId
		-- Expire predictions the server never answered (e.g. it rejected a too-fast drop).
		if isMe and #t.pending > 0 and clock - t.pending[1].at > PREDICT_TTL then
			table.clear(t.pending)
			rebuildView(t)
			st = t.view :: Stack.State
		end
		local pos = root.CFrame.Position
		local dist = (pos - camPos).Magnitude
		local mode = if dist > VISIBLE_RADIUS
			then "hidden"
			elseif not isMe and (dist > FULL_RADIUS or perf) then "column"
			else "full"
		setMode(t, mode)
		if mode == "hidden" then
			t.lastPos = nil
			continue
		end
		-- Lean spring: the tower trails behind horizontal movement, then wobbles back upright.
		local vx, vz = 0, 0
		if t.lastPos and dt > 0 then
			local d = pos - t.lastPos
			vx, vz = d.X / dt, d.Z / dt
		end
		t.lastPos = pos
		local tx, tz = math.clamp(-vx * 0.06, -1.2, 1.2), math.clamp(-vz * 0.06, -1.2, 1.2)
		local stiffness, damping = 60, 7
		t.velX += ((tx - t.leanX) * stiffness - t.velX * damping) * dt
		t.velZ += ((tz - t.leanZ) * stiffness - t.velZ * damping) * dt
		t.leanX += t.velX * dt
		t.leanZ += t.velZ * dt
		local tray = trayFrame(t, root)
		put(t.tray, tray * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local count = #st.layers
		if mode == "column" then
			put(t.column, layerCFrame(t, tray, 0, 0, math.max(count, 1) * H / 2))
			continue
		end
		for i, p in t.parts do
			local l = st.layers[i]
			if l then
				put(p, layerCFrame(t, tray, l.x, l.z, (i - 0.5) * H))
			end
		end
		-- Butter pat on the top pancake.
		if count > 0 then
			local top = st.layers[count]
			put(
				t.butter,
				layerCFrame(t, tray, top.x, top.z, count * H + 0.09)
					* CFrame.Angles(0, 0, math.rad(-90))
					* CFrame.Angles(0, math.rad(35), 0)
			)
		else
			put(t.butter, CFrame.new(0, -500, 0))
		end
		-- The sliding pancake (hidden until it appears, while serving, or when the tray is full).
		local trayMax = C.State.derived.tray or 15
		local showSlider = now >= st.start and not t.flying and (not isMe or count < trayMax)
		if showSlider then
			local sx, sz = Stack.sliderPos(st, now)
			local batter =
				flavorColors(if isMe then currentFlavor() else (if count > 0 then st.layers[count].flavor else 1))
			t.slider.Color = if st.sprinkle then SPRINKLE else batter
			t.slider.Material = if st.sprinkle then Enum.Material.Neon else Enum.Material.SmoothPlastic
			t.slider.Size = Vector3.new(H, st.topR * 2, st.topR * 2)
			put(t.slider, layerCFrame(t, tray, sx, sz, (count + 0.5) * H + 0.05))
		else
			put(t.slider, CFrame.new(0, -500, 0))
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function StackRenderer:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "Stacks"
	folder.Parent = workspace
end

function StackRenderer:Start()
	C.ClientNet:On("Stack", onEvent)
	C.ClientNet:On("StackSnapshot", function(all)
		for key, w in all do
			local id = tonumber(key)
			if id then
				onEvent(id, w)
			end
		end
	end)
	C.State.Changed:Connect(function(keys)
		if keys.derived then
			local d = C.State.derived
			window = d.window or window
			slide = d.slide or slide
		end
	end)
	-- Late joiners: everyone else's towers.
	C.State:OnLoaded(function()
		C.ClientNet:Fire("StackSnapshot")
	end)
	Players.PlayerRemoving:Connect(function(p)
		local t = towers[p.UserId]
		if t then
			releaseLayers(t)
			t.model:Destroy()
			towers[p.UserId] = nil
		end
	end)
	RunService.RenderStepped:Connect(update)
end

-- The local player's tower height (predicted).
function StackRenderer:MyCount(): number
	local t = towers[me.UserId]
	local st = t and t.view
	return if st then #st.layers else 0
end

-- The local player's predicted stack state (read-only), or nil.
function StackRenderer:MyState(): Stack.State?
	local t = towers[me.UserId]
	return t and t.view
end

-- Predict a local drop at server time `t`. Returns the predicted kind, or nil if no drop is
-- possible right now (nothing sliding yet, tray full, no stack).
function StackRenderer:PredictDrop(t: number): string?
	local tower = towers[me.UserId]
	local st = tower and tower.view
	if not tower or not st then
		return nil
	end
	if t < st.start or #st.layers >= (C.State.derived.tray or 15) then
		return nil
	end
	local probe = cloneState(st)
	local flavor = currentFlavor()
	local r = Stack.drop(probe, t, window, flavor)
	table.insert(tower.pending, { t = t, at = os.clock() })
	rebuildView(tower)
	local count = #probe.layers
	local root = C.Effects:LocalRoot()
	local top = if root then root.CFrame.Position + Vector3.new(0, TRAY_UP + count * H + 1, 0) else nil
	if r.kind == "perfect" then
		C.Audio:PlayStep(count, "Perfect")
		if top and probe.combo >= 3 then
			C.Effects:Pop(top, "PERFECT x" .. probe.combo, BUTTER, 1 + math.min(probe.combo, 10) * 0.05, -6)
		elseif top then
			C.Effects:Pop(top, "PERFECT!", BUTTER, 1, -6)
		end
		if top and probe.combo % 5 == 0 then
			C.Effects:Crumbs(top, BUTTER, 16)
			C.LightingFX:Flash(0.25)
		end
	elseif r.kind == "good" then
		C.Audio:PlayStep(count, "Drop")
		C.Audio:Play("Slice", { volume = 0.5 })
		debris(tower, r.offset, r.cut, count, flavor)
	end
	StackRenderer.Dropped:Fire(r.kind, count, probe.combo)
	return r.kind
end

return StackRenderer
