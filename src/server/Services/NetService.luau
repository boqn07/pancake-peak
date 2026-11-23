--!strict
-- Creates the remotes declared in Shared/Net and guards every client -> server call:
-- loaded-profile check, per-player rate limit, argument validation, and pcall isolation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(ReplicatedStorage.Shared.Logic.RateLimiter)

local NetService = {}

local folder: Folder
local remotes: { [string]: RemoteEvent } = {}
local limiter
local S: any

function NetService:Init(services)
	S = services
	folder = Instance.new("Folder")
	folder.Name = Net.FolderName
	for name in Net.ClientToServer do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		remotes[name] = r
	end
	for _, name in Net.ServerToClient do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		remotes[name] = r
	end
	folder.Parent = ReplicatedStorage
	limiter = RateLimiter.new(Net.ClientToServer, os.clock)
end

function NetService:Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

-- Register a handler. `validate(...)` must return true for the call to proceed.
-- Handlers receive (player, profile, ...args).
function NetService:On(name: string, validate: (...any) -> boolean, handler: (Player, any, ...any) -> ())
	local remote = remotes[name]
	assert(remote and Net.ClientToServer[name], "unknown client remote " .. name)
	remote.OnServerEvent:Connect(function(player: Player, ...)
		local profile = S.Data:Get(player)
		if not profile then
			return
		end
		if not limiter:allow(player, name) then
			return
		end
		local okArgs, valid = pcall(validate, ...)
		if not okArgs or not valid then
			return
		end
		local ok, err = pcall(handler, player, profile, ...)
		if not ok then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(err)))
		end
	end)
end

function NetService:Fire(name: string, player: Player, ...: any)
	remotes[name]:FireClient(player, ...)
end

function NetService:FireAll(name: string, ...: any)
	remotes[name]:FireAllClients(...)
end

-- Fire to every player whose character is within `radius` studs of `position`.
function NetService:FireNear(name: string, position: Vector3, radius: number, ...: any)
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.CFrame.Position - position).Magnitude <= radius then
			remotes[name]:FireClient(p, ...)
		end
	end
end

function NetService:Notify(player: Player, text: string, style: string?)
	remotes.Notify:FireClient(player, text, style or "info")
end

return NetService
