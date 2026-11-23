--!strict
-- Thin wrapper over the remotes declared in Shared/Net.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ClientNet = {}

local folder: Instance

function ClientNet:Init()
	folder = ReplicatedStorage:WaitForChild(Net.FolderName)
end

function ClientNet:Fire(name: string, ...: any)
	local r = folder:WaitForChild(name, 10) :: RemoteEvent?
	if r then
		r:FireServer(...)
	end
end

function ClientNet:On(name: string, fn: (...any) -> ()): RBXScriptConnection
	local r = folder:WaitForChild(name) :: RemoteEvent
	return r.OnClientEvent:Connect(fn)
end

return ClientNet
