--!strict
-- Equipped Nibblers hop along behind every player in a little parade.
-- Built locally from each player's "Nibblers" attribute; moved with smoothing and one BulkMoveTo
-- per frame. They hop while moving, squash-bob while idle and lean into turns. Far players are skipped.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Followers = {}

local C: any
local localPlayer = Players.LocalPlayer
local folder: Folder
local VISIBLE_RADIUS = 180

type Follower = {
	model: Model,
	body: BasePart,
	shiny: boolean,
	pos: Vector3,
	phase: number,
	base: Color3,
	bank: number,
	half: number,
	hop: number,
}
type Entry = { player: Player, key: string, list: { Follower } }

local entries: { [Player]: Entry } = {}

local function parse(attr: string): { { id: string, shiny: boolean } }
	local out = {}
	for item in string.gmatch(attr, "[^,]+") do
		local id, p = string.match(item, "^([%w_]+):([01])$")
		if id then
			table.insert(out, { id = id, shiny = p == "1" })
		end
	end
	return out
end

local function clear(entry: Entry)
	for _, f in entry.list do
		f.model:Destroy()
	end
	table.clear(entry.list)
end

local function rebuild(player: Player)
	local entry = entries[player]
	if not entry then
		entry = { player = player, key = "", list = {} }
		entries[player] = entry
	end
	local attr = player:GetAttribute("Nibblers")
	local key = if type(attr) == "string" then attr else ""
	local perf = C.State:Setting("performance")
	if player ~= localPlayer and perf then
		-- Performance mode: show at most two followers for other players.
		local items = parse(key)
		local trimmed = {}
		for i = 1, math.min(2, #items) do
			table.insert(trimmed, items[i].id .. ":" .. (if items[i].shiny then "1" else "0"))
		end
		key = table.concat(trimmed, ",")
	end
	if key == entry.key then
		return
	end
	entry.key = key
	clear(entry)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame.Position else Vector3.new(0, -500, 0)
	for _, item in parse(key) do
		local model = C.NibblerModels:Build(item.id, item.shiny)
		local body = model.PrimaryPart :: BasePart
		model.Parent = folder
		body.CFrame = CFrame.new(start)
		table.insert(entry.list, {
			model = model,
			body = body,
			shiny = item.shiny,
			pos = start,
			phase = math.random() * 6,
			base = body.Color,
			bank = 0,
			half = body.Size.Y / 2,
			hop = math.random() * 6,
		})
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Nibblers"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function Followers:Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = workspace
end

function Followers:Start()
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local e = entries[p]
		if e then
			clear(e)
			entries[p] = nil
		end
	end)
	C.State.Changed:Connect(function(keys)
		if keys.settings then
			for p in entries do
				entries[p].key = "\0" -- force rebuild with new performance setting
				rebuild(p)
			end
		end
	end)

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local camPos = cam.CFrame.Position
		local t = os.clock()
		local alpha = 1 - math.exp(-dt * 5)
		table.clear(parts)
		table.clear(cframes)
		local n = 0
		for player, entry in entries do
			local count = #entry.list
			if count == 0 then
				continue
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			if player ~= localPlayer and (root.CFrame.Position - camPos).Magnitude > VISIBLE_RADIUS then
				continue
			end
			local rootCf = root.CFrame
			-- Feet level: the root sits HipHeight + half its height above the ground.
			local hum = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
			local ground = rootCf.Position.Y - (if hum then hum.HipHeight else 2) - root.Size.Y / 2
			local moving = root.AssemblyLinearVelocity.Magnitude > 2
			-- A parade arc behind you; a second row for big teams.
			for i, f in entry.list do
				local ring = (i - 1) // 6
				local inRing = math.min(6, count - ring * 6)
				local col = (i - 1) % 6
				local angle = (col - (inRing - 1) / 2) * 0.55
				local dist = 5 + ring * 3.2
				local target = (rootCf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, dist)).Position
				if moving then
					f.hop += dt * 9
				end
				local lift = if moving then math.abs(math.sin(f.hop + f.phase)) * 1.4 else 0
				target = Vector3.new(target.X, ground + f.half + lift, target.Z)
				local prev = f.pos
				f.pos = prev:Lerp(target, alpha)
				local vel = f.pos - prev
				local flat = Vector3.new(vel.X, 0, vel.Z)
				local look = if flat.Magnitude > 0.02 then f.pos + flat else f.pos + rootCf.LookVector
				-- Bank into turns: sideways velocity relative to facing.
				local side = if flat.Magnitude > 0.02 then rootCf.RightVector:Dot(flat) / math.max(dt, 1e-3) else 0
				f.bank += (math.clamp(-side * 0.02, -0.5, 0.5) - f.bank) * alpha
				n += 1
				parts[n] = f.body
				local idle = if moving then 0 else math.sin(t * 2.2 + f.phase) * 0.06
				cframes[n] = CFrame.lookAt(f.pos, look) * CFrame.Angles(idle, 0, f.bank)
				if f.shiny then
					f.body.Color = C.NibblerModels:ShinyColor(f.base, t + f.phase)
				end
			end
		end
		if n > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Followers
