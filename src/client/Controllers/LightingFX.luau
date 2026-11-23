--!strict
-- Crisp alpine morning: pale blue haze over the sea of clouds, soft bloom on snow highlights and
-- gently saturated storybook color. Each zone nudges the grade (warm maple meadow, cool icefalls,
-- cocoa-brown dusk on the cliffs, violet sky up at the Aurora Summit), and a Snow Day brightens
-- everything to a sparkly white-gold for its duration. Performance mode turns off the expensive parts.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LightingFX = {}

local C: any
local hex = Color3.fromHex

local fx: { [string]: Instance } = {}
type Look = { tint: Color3, atmosphere: Color3, decay: Color3, bloom: number, saturation: number, density: number }
local function look(
	tint: string,
	atmosphere: string,
	decay: string,
	bloom: number,
	saturation: number,
	density: number
): Look
	return {
		tint = hex(tint),
		atmosphere = hex(atmosphere),
		decay = hex(decay),
		bloom = bloom,
		saturation = saturation,
		density = density,
	}
end
local LOOKS: { [string]: Look } = {
	BaseCamp = look("#FFFBF4", "#DCEBFA", "#9CC3EA", 0.35, 0.16, 0.28),
	MapleMeadow = look("#FFF4E2", "#F3E4CF", "#E3B27A", 0.35, 0.2, 0.27),
	PineconeVillage = look("#F8FFF6", "#D9EEDC", "#8FBF9A", 0.32, 0.18, 0.3),
	FrostyFalls = look("#F1FAFF", "#D2F0FF", "#7FCBEF", 0.45, 0.14, 0.32),
	CocoaCliffs = look("#FFEFE4", "#EBD3C2", "#B9806A", 0.38, 0.2, 0.3),
	AuroraSummit = look("#F5EEFF", "#D8D0FF", "#8C7BE8", 0.55, 0.24, 0.26),
}
local SNOW_DAY = look("#FFFDF0", "#FFFFFF", "#FFE7A8", 0.85, 0.24, 0.36)
local snowDay = false
local zone = "BaseCamp"

function LightingFX:Init(controllers)
	C = controllers
	-- Remove anything a default place ships with so our look is the only look.
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = LOOKS.BaseCamp.density
	atmosphere.Offset = 0.1
	atmosphere.Color = LOOKS.BaseCamp.atmosphere
	atmosphere.Decay = LOOKS.BaseCamp.decay
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	fx.atmosphere = atmosphere

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.StarCount = 0
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = LOOKS.BaseCamp.bloom
	bloom.Size = 24
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	fx.bloom = bloom

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = LOOKS.BaseCamp.saturation
	cc.Contrast = 0.08
	cc.Brightness = 0.03
	cc.TintColor = LOOKS.BaseCamp.tint
	cc.Parent = Lighting
	fx.cc = cc

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	fx.rays = rays

	-- Used by panels to softly blur the world behind them.
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	fx.blur = blur
end

local function applyPerformance()
	local perf = C.State:Setting("performance")
	local rays = fx.rays :: SunRaysEffect
	rays.Enabled = not perf
	Lighting.GlobalShadows = not perf
end

local function tweenTo(l: Look, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(fx.cc, info, { TintColor = l.tint, Saturation = l.saturation }):Play()
	TweenService:Create(fx.atmosphere, info, { Color = l.atmosphere, Decay = l.decay, Density = l.density }):Play()
	TweenService:Create(fx.bloom, info, { Intensity = l.bloom }):Play()
end

local function refresh(seconds: number)
	tweenTo(if snowDay then SNOW_DAY else (LOOKS[zone] or LOOKS.BaseCamp), seconds)
end

function LightingFX:Start()
	C.State.Changed:Connect(function(keys)
		if keys.settings then
			applyPerformance()
		end
	end)
	C.State:OnLoaded(applyPerformance)
	C.WorldFX.ZoneChanged:Connect(function(id: string)
		zone = id
		refresh(2)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local s = C.State:SnowDay()
		if s ~= snowDay then
			snowDay = s
			refresh(1.5)
		end
	end)
end

-- Blur the world behind an open panel (0 = off).
function LightingFX:SetBlur(size: number)
	TweenService:Create(fx.blur, TweenInfo.new(0.25), { Size = size }):Play()
end

-- Brief full-scene flash (perfect streaks, egg reveal, the Great Yeti's Order).
function LightingFX:Flash(strength: number)
	local cc = fx.cc :: ColorCorrectionEffect
	cc.Brightness = 0.03 + 0.2 * strength
	TweenService:Create(cc, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.03 })
		:Play()
end

return LightingFX
