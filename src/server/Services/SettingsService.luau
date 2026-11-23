--!strict
local SettingsService = {}

local ALLOWED = { music = true, sfx = true, performance = true, autoEquip = true, autoServe = true }

local S: any

function SettingsService:Init(services)
	S = services
end

function SettingsService:Start()
	S.Net:On("SetSetting", function(key, value)
		return type(key) == "string" and ALLOWED[key] == true and type(value) == "boolean"
	end, function(player, profile, key, value)
		profile.settings[key] = value
		S.Data:Changed(player, "settings")
	end)
end

return SettingsService
