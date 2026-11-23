--!strict
-- Global leaderboards (OrderedDataStore) shown on the Base Camp signboards.
-- Lifetime Maple can exceed int64, so it is stored on a log scale (see Config/Leaderboards).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)

local LeaderboardService = {}

local S: any

type Board = {
	title: string,
	store: string,
	value: (profile: any) -> number,
	decode: (stored: number) -> number,
	color: Color3,
	suffix: string,
}

-- How each stat is read from a profile and stored (OrderedDataStores hold integers only).
local STATS = {
	lifetimeMaple = {
		value = function(p)
			return math.floor(math.log10(p.lifetimeMaple + 1) * Config.LogScale)
		end,
		decode = function(v)
			return 10 ^ (v / Config.LogScale) - 1
		end,
	},
	rebirths = {
		value = function(p)
			return p.rebirths
		end,
	},
	tallest = {
		value = function(p)
			return p.stats.tallest
		end,
		suffix = " pancakes",
	},
}

local function identity(v: number): number
	return v
end

local BOARDS: { Board } = {}
for _, b in Config.Boards do
	local stat = STATS[b.stat]
	assert(stat, "unknown leaderboard stat " .. b.stat)
	table.insert(BOARDS, {
		title = b.title,
		store = b.store,
		value = stat.value,
		decode = (stat :: any).decode or identity,
		color = Color3.fromHex(b.color),
		suffix = (stat :: any).suffix or "",
	})
end

local names: { [number]: string } = {}

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Popper"
	return names[userId]
end

function LeaderboardService:Init(services)
	S = services
end

local function render(board: Board, rows: { { key: string, value: number } }?)
	local gui = S.World:Board(board.title)
	if not gui then
		return
	end
	local list = gui:FindFirstChild("List") :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not rows then
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 0.2)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = Color3.fromHex("#1D3557")
		l.Text = "Leaderboards appear on live servers"
		l.Parent = list
		return
	end
	for i, row in rows do
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.Size = UDim2.fromScale(1, 0.09)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = if i == 1 then board.color else Color3.fromHex("#1D3557")
		local userId = tonumber(string.match(row.key, "%d+")) or 0
		l.Text = string.format(
			"%d. %s  —  %s",
			i,
			nameFor(userId),
			Format.abbreviate(board.decode(row.value)) .. board.suffix
		)
		l.Parent = list
	end
end

function LeaderboardService:Start()
	local stores = {}
	for _, b in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.store)
		stores[b.title] = if ok then store else nil
	end

	-- Last value written per board and player, so unchanged stats don't spend DataStore budget.
	local pushed: { [string]: { [number]: number } } = {}
	for _, b in BOARDS do
		pushed[b.title] = {}
	end

	local function push(player: Player, profile: any)
		for _, b in BOARDS do
			local store = stores[b.title]
			local value = b.value(profile)
			if store and value > 0 and pushed[b.title][player.UserId] ~= value then
				if pcall(store.SetAsync, store, "u" .. player.UserId, value) then
					pushed[b.title][player.UserId] = value
				end
			end
		end
	end

	S.Data.Releasing:Connect(function(player, profile)
		push(player, profile)
		for _, b in BOARDS do
			pushed[b.title][player.UserId] = nil
		end
	end)

	while true do
		if S.Data.Offline then
			for _, b in BOARDS do
				render(b, nil)
			end
		else
			for player, profile in S.Data:Players() do
				push(player, profile)
				task.wait(0.1)
			end
			for _, b in BOARDS do
				local store = stores[b.title]
				local rows = nil
				if store then
					local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Top)
					if ok then
						rows = {}
						for _, entry in pages:GetCurrentPage() do
							table.insert(rows, { key = entry.key, value = entry.value })
						end
					end
				end
				render(b, rows)
			end
		end
		task.wait(Config.RefreshSeconds)
	end
end

return LeaderboardService
