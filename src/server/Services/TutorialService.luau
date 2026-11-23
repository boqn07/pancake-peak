--!strict
-- Server-driven onboarding. The client only shows hints for the current step; progress comes
-- from real actions, so the tutorial can't desync or be skipped by accident.
local TutorialService = {}

-- Step n is complete when this event happens while on step n - 1.
local STEPS = { "drop", "perfect", "serve", "upgrade", "egg" }
TutorialService.Steps = STEPS

local S: any

function TutorialService:Init(services)
	S = services
end

function TutorialService:Start()
	S.Net:On("SkipTutorial", function()
		return true
	end, function(player, profile)
		profile.tutorial.done = true
		profile.tutorial.step = #STEPS
		S.Data:Changed(player, "tutorial")
	end)
end

function TutorialService:Event(player: Player, event: string)
	local profile = S.Data:Get(player)
	if not profile or profile.tutorial.done then
		return
	end
	local idx = table.find(STEPS, event)
	if idx and idx == profile.tutorial.step + 1 then
		profile.tutorial.step = idx
		if idx >= #STEPS then
			profile.tutorial.done = true
		end
		S.Data:Changed(player, "tutorial")
	end
end

return TutorialService
