--!strict
-- Owns every player profile: load with session lock, autosave, save on leave and shutdown,
-- batched state replication to the owning client.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Game = require(Shared.Config.Game)
local Schema = require(Shared.Logic.Schema)
local Signal = require(Shared.Util.Signal)
local SessionStore = require(script.Parent.Parent.Data.SessionStore)

local DataService = {}
DataService.Loaded = Signal.new() -- (player, profile)
DataService.Releasing = Signal.new() -- (player, profile) fired just before the final save
DataService.Offline = false -- true in Studio without API access: nothing is saved

local S: any
local store: any
local sessions: { [Player]: any } = {}
local releasing: { [number]: boolean } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local derivedDirty: { [Player]: boolean } = {}
local shuttingDown = false

-- In-memory store used only in Studio when DataStores are unavailable.
local function memoryStore()
	local data = {}
	return {
		UpdateAsync = function(_, key, fn)
			local result = fn(data[key])
			if result ~= nil then
				data[key] = result
			end
			return result
		end,
	}
end

local function pickStore()
	local ok, real = pcall(function()
		return DataStoreService:GetDataStore(Game.DataStoreName)
	end)
	if ok and RunService:IsStudio() then
		local probeOk = pcall(function()
			real:GetAsync("__probe")
		end)
		if not probeOk then
			ok = false
		end
	end
	if not ok then
		if RunService:IsStudio() then
			warn(
				"[Data] DataStores unavailable in Studio (enable 'Studio Access to API Services'). Progress will NOT be saved."
			)
			DataService.Offline = true
			return memoryStore()
		end
		-- On live servers keep the real store; individual loads will retry and kick on failure.
		return DataStoreService:GetDataStore(Game.DataStoreName)
	end
	return real
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

function DataService:Init(services)
	S = services
	store = pickStore()
	self._store = SessionStore.new({
		store = store,
		jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1, 1e9)),
		now = os.time,
		wait = function(s)
			task.wait(s)
		end,
		log = function(msg)
			warn("[Data] " .. msg)
		end,
		migrate = Schema.migrate,
	}, {
		lockStale = Game.SessionLockStaleSeconds,
		loadRetries = Game.LoadRetries,
		retryDelay = Game.LoadRetryDelay,
		saveRetries = Game.SaveRetries,
	})
end

local function onPlayerAdded(player: Player)
	-- Rejoined this same server before the previous session finished releasing: wait for it.
	local waited = 0
	while releasing[player.UserId] and waited < 30 do
		waited += task.wait(0.5)
	end
	local session, reason = DataService._store:load(keyFor(player))
	if not session then
		if player.Parent then
			player:Kick(
				if reason == "locked"
					then "Your progress is still saving on another server. Please rejoin in a moment."
					else "We couldn't load your progress (Roblox data servers are busy). Please rejoin — your data is safe."
			)
		end
		return
	end
	if not player.Parent then
		-- Left while loading: release the lock right away.
		DataService._store:save(session, true)
		return
	end
	local profile = session.data
	if profile.firstJoin == 0 then
		profile.firstJoin = os.time()
	end
	sessions[player] = session
	DataService.Loaded:Fire(player, profile)
	DataService:SendFull(player)
end

local function release(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	dirty[player] = nil
	derivedDirty[player] = nil
	releasing[player.UserId] = true
	DataService.Releasing:Fire(player, session.data)
	task.wait() -- let Releasing handlers run (they may write final stats) before the save
	DataService._store:save(session, true)
	releasing[player.UserId] = nil
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(release)

	game:BindToClose(function()
		shuttingDown = true
		for _, p in Players:GetPlayers() do
			task.spawn(release, p)
		end
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			if next(sessions) == nil and next(releasing) == nil then
				break
			end
			task.wait(0.25)
		end
	end)

	-- Autosave (also refreshes the session lock). Staggered so saves don't all land at once.
	task.spawn(function()
		while not shuttingDown do
			task.wait(Game.AutosaveSeconds)
			-- Snapshot first: players join and leave while this loop is yielding.
			local batch = {}
			for player, session in sessions do
				table.insert(batch, { player, session })
			end
			for _, entry in batch do
				local player, session = entry[1], entry[2]
				if shuttingDown then
					break
				end
				if sessions[player] ~= session then
					continue -- left (and was saved on release) since the snapshot
				end
				task.spawn(function()
					local ok = self._store:save(session, false)
					if not ok and session.stolen and player.Parent then
						sessions[player] = nil
						player:Kick("Your profile was opened on another server.")
					end
				end)
				task.wait(0.2)
			end
		end
	end)

	-- Batched state replication.
	task.spawn(function()
		while true do
			task.wait(Game.StateFlushSeconds)
			for player, keys in dirty do
				local session = sessions[player]
				if session then
					local payload = {}
					for k in keys do
						payload[k] = session.data[k]
					end
					if derivedDirty[player] then
						payload.derived = S.Economy:Derived(player)
						derivedDirty[player] = nil
					end
					S.Net:Fire("State", player, payload)
				end
			end
			table.clear(dirty)
			for player in derivedDirty do
				if sessions[player] then
					S.Net:Fire("State", player, { derived = S.Economy:Derived(player) })
				end
			end
			table.clear(derivedDirty)
		end
	end)
end

-- The live profile table, or nil if not loaded. Mutate it only from services.
function DataService:Get(player: Player): any?
	local s = sessions[player]
	return s and s.data
end

function DataService:GetSessionByUserId(userId: number): any?
	local player = Players:GetPlayerByUserId(userId)
	return player and sessions[player]
end

function DataService:IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- Mark top-level profile keys as changed; they are sent to the client on the next flush.
function DataService:Changed(player: Player, ...: string)
	if not sessions[player] then
		return
	end
	local set = dirty[player]
	if not set then
		set = {}
		dirty[player] = set
	end
	for _, k in { ... } do
		set[k] = true
	end
end

-- Derived values (multipliers, ball size, slots...) need recomputing for this player.
function DataService:DerivedChanged(player: Player)
	if sessions[player] then
		derivedDirty[player] = true
	end
end

function DataService:SendFull(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local payload = table.clone(session.data)
	payload.receipts = nil
	payload.derived = S.Economy:Derived(player)
	payload.offline = DataService.Offline
	S.Net:Fire("State", player, payload)
end

-- Immediate save (used after purchases). Returns true when stored.
function DataService:SaveNow(session: any): boolean
	return self._store:save(session, false)
end

function DataService:Players(): { [Player]: any }
	local out = {}
	for p, s in sessions do
		out[p] = s.data
	end
	return out
end

return DataService
