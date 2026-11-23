--!strict
-- Central audio. Every sound goes through here so settings, pitch variation and pooling apply.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Assets"))

local Audio = {}

local C: any
local pools: { [string]: { Sound } } = {}
local cursor: { [string]: number } = {}
local POOL = 6
local music: Sound?
local snowMusic: Sound?

-- Per-sound base tuning (volume, speed) so one shared rbxasset clip can play several roles.
local TUNING: { [string]: { volume: number, speed: number } } = {
	Drop = { volume = 0.4, speed = 0.9 },
	Perfect = { volume = 0.45, speed = 1.1 },
	Slice = { volume = 0.3, speed = 1.6 },
	Topple = { volume = 0.7, speed = 0.45 },
	Chomp = { volume = 0.4, speed = 0.7 },
	Serve = { volume = 0.55, speed = 0.9 },
	Craving = { volume = 0.6, speed = 1.3 },
	Click = { volume = 0.4, speed = 1.1 },
	Hover = { volume = 0.15, speed = 1.4 },
	Purchase = { volume = 0.5, speed = 0.9 },
	Error = { volume = 0.35, speed = 0.6 },
	PanelOpen = { volume = 0.25, speed = 1.5 },
	EggShake = { volume = 0.35, speed = 0.8 },
	EggCrack = { volume = 0.7, speed = 1.2 },
	Unlock = { volume = 0.6, speed = 0.9 },
	Order = { volume = 0.7, speed = 0.55 },
	Stomp = { volume = 0.6, speed = 0.5 },
}

function Audio:Init(controllers)
	C = controllers
	local group = Instance.new("SoundGroup")
	group.Name = "SFX"
	group.Parent = SoundService
	for name, id in Assets.Sounds do
		if id ~= "" then
			local list = {}
			for i = 1, POOL do
				local s = Instance.new("Sound")
				s.Name = name .. i
				s.SoundId = id
				s.SoundGroup = group
				s.Parent = SoundService
				table.insert(list, s)
			end
			pools[name] = list
			cursor[name] = 1
		end
	end
end

local function makeMusic(name: string, id: string): Sound?
	if id == "" then
		return nil
	end
	local m = Instance.new("Sound")
	m.Name = name
	m.SoundId = id
	m.Looped = true
	m.Volume = 0.3
	m.Parent = SoundService
	return m
end

function Audio:Start()
	music = makeMusic("Music", Assets.Music.Default)
	snowMusic = makeMusic("SnowDayMusic", Assets.Music.SnowDay)
	local function apply()
		local on = C.State:Setting("music")
		local snow = C.State:SnowDay() and snowMusic ~= nil
		for _, pair in { { music, on and not snow }, { snowMusic, on and snow } } do
			local s: Sound? = pair[1]
			if s then
				if pair[2] and not s.IsPlaying then
					s:Play()
				elseif not pair[2] and s.IsPlaying then
					s:Stop()
				end
			end
		end
	end
	C.State.Changed:Connect(function(keys)
		if keys.settings then
			apply()
		end
	end)
	C.State.OrderChanged:Connect(function()
		apply()
		local snowEnds = C.State.order.snowEndsAt or 0
		local left = snowEnds - workspace:GetServerTimeNow()
		if left > 0 then
			task.delay(left + 0.1, apply)
		end
	end)
	C.State:OnLoaded(apply)
end

-- Play a named sound. opts.pitch multiplies speed; opts.volume multiplies volume.
function Audio:Play(name: string, opts: { pitch: number?, volume: number? }?)
	if C.State.loaded and not C.State:Setting("sfx") then
		return
	end
	local list = pools[name]
	if not list then
		return
	end
	local i = cursor[name]
	cursor[name] = i % #list + 1
	local s = list[i]
	local tune = TUNING[name] or { volume = 0.5, speed = 1 }
	s.Volume = tune.volume * (opts and opts.volume or 1)
	s.PlaybackSpeed = tune.speed * (opts and opts.pitch or 1) * (1 + (math.random() - 0.5) * 0.06)
	s.TimePosition = 0
	s:Play()
end

-- Each pancake lands a little higher in pitch, like a xylophone climbing with the tower.
function Audio:PlayStep(step: number, name: string?, volume: number?)
	self:Play(name or "Drop", { pitch = 1 + math.min(step, 24) * 0.035, volume = volume })
end

return Audio
