--!strict
-- Zone ownership: buying zones, travel, and enforcing that nobody stands on (or serves in) a zone
-- they don't own, even if they remove the ice gate on their client. Also carries players who fall
-- into the clouds back to land, and tracks implausible movement (teleport/speed hacks) so
-- StackService can ignore serves from a character that just jumped across the map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Game = require(Shared.Config.Game)
local Progression = require(Shared.Logic.Progression)
local Economy = require(Shared.Logic.Economy)
local Validate = require(Shared.Logic.Validate)
local ZoneGeo = require(Shared.Logic.ZoneGeo)

local ZoneService = {}

local S: any
local lastTeleport: { [Player]: number } = {}
local playerZone: { [Player]: string? } = {}
type Track = { x: number, z: number, t: number, suspectUntil: number, graceUntil: number }
local tracks: { [Player]: Track } = {}

-- Movement allowance per check: (walkSpeed * SpeedTolerance + SpeedSlack) * dt + 2 studs.
local SPEED_TOLERANCE = 1.6
local SPEED_SLACK = 10
local SUSPECT_SECONDS = 2

function ZoneService:Init(services)
	S = services
end

function ZoneService:ZoneAt(pos: Vector3): string?
	return ZoneGeo.zoneAt(pos.X, pos.Y, pos.Z)
end

function ZoneService:PlayerZone(player: Player): string?
	return playerZone[player]
end

-- Number of players currently in each zone (used for the Great Yeti's Order).
function ZoneService:Population(): { [string]: number }
	local counts = {}
	for _, id in playerZone do
		if id then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

-- False for a couple of seconds after a character moved faster than it possibly could.
function ZoneService:IsHonest(player: Player): boolean
	local tr = tracks[player]
	return tr == nil or os.clock() >= tr.suspectUntil
end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function ZoneService:TeleportTo(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		-- StreamingEnabled: make sure the destination exists on the client before it lands.
		pcall(function()
			player:RequestStreamAroundAsync(cf.Position, 5)
		end)
		character:PivotTo(cf)
		-- A server teleport is not a speed hack.
		local tr = tracks[player]
		if tr then
			tr.x, tr.z, tr.t = cf.Position.X, cf.Position.Z, os.clock()
			tr.graceUntil = os.clock() + 1
		end
	end
end

-- Track movement and flag anything faster than the player's real speed allows.
local function checkMovement(player: Player, profile: any, pos: Vector3)
	local now = os.clock()
	local tr = tracks[player]
	if not tr then
		tracks[player] = { x = pos.X, z = pos.Z, t = now, suspectUntil = 0, graceUntil = 0 }
		return
	end
	local dt = math.max(now - tr.t, 1e-3)
	local moved = math.sqrt((pos.X - tr.x) ^ 2 + (pos.Z - tr.z) ^ 2)
	local allowed = (Economy.walkSpeed(profile) * SPEED_TOLERANCE + SPEED_SLACK) * dt + 2
	if moved > allowed and now >= tr.graceUntil then
		tr.suspectUntil = now + SUSPECT_SECONDS
	end
	tr.x, tr.z, tr.t = pos.X, pos.Z, now
end

function ZoneService:Start()
	S.Net:On("BuyZone", function(id)
		return Validate.key(id, Zones.ById)
	end, function(player, profile, id)
		local ok, why = Progression.unlockZone(profile, id)
		if not ok then
			S.Net:Notify(player, why or "Can't unlock", "error")
			return
		end
		S.Data:Changed(player, "maple", "zones")
		S.Data:DerivedChanged(player)
		local zone = Zones.ById[id]
		S.Net:Notify(player, "Unlocked " .. zone.name .. "!", "unlock")
		S.Net:FireAll("Announce", string.format("%s climbed up to %s!", player.DisplayName, zone.name), "zone")
		local spawn = S.World:ZoneSpawn(id)
		if spawn then
			self:TeleportTo(player, spawn)
		end
	end)

	S.Net:On("Teleport", function(id)
		return id == "BaseCamp" or Validate.key(id, Zones.ById)
	end, function(player, profile, id)
		local now = os.clock()
		if lastTeleport[player] and now - lastTeleport[player] < Game.TeleportCooldown then
			return
		end
		if id == "BaseCamp" then
			lastTeleport[player] = now
			self:TeleportTo(player, S.World:HubSpawn())
			return
		end
		if not profile.zones[id] then
			S.Net:Notify(player, "You haven't unlocked that zone yet", "error")
			return
		end
		lastTeleport[player] = now
		local spawn = S.World:ZoneSpawn(id)
		if spawn then
			self:TeleportTo(player, spawn)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastTeleport[p] = nil
		playerZone[p] = nil
		tracks[p] = nil
	end)

	-- 4 Hz: track the current zone and movement, bounce trespassers, rescue fallers.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local profile = S.Data:Get(player)
				local r = root(player)
				if not profile or not r then
					playerZone[player] = nil
					tracks[player] = nil
					continue
				end
				local pos = r.CFrame.Position
				checkMovement(player, profile, pos)
				if pos.Y < Zones.CloudKillY then
					-- Fell into the clouds: a friendly snow eagle carries you back to the last owned zone.
					local current = playerZone[player]
					local target = if current and profile.zones[current] then S.World:ZoneSpawn(current) else nil
					self:TeleportTo(player, target or S.World:HubSpawn())
					S.Net:Notify(player, "Whoosh! A snow eagle carried you back up 🦅", "info")
					continue
				end
				local id = self:ZoneAt(pos)
				if id and not profile.zones[id] then
					S.Net:Notify(player, "Unlock " .. Zones.ById[id].name .. " first!", "error")
					self:TeleportTo(player, S.World:HubSpawn())
					id = nil
				end
				playerZone[player] = id
			end
		end
	end)
end

return ZoneService
