--!strict
-- Owns the ScreenGui, responsive scaling, the panel manager (one panel at a time, animated open/close,
-- gamepad selection), and routes server messages to toasts/banners/reward cards.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local Onboarding = require(script.Parent:WaitForChild("Onboarding"))
local RewardText = require(script.Parent:WaitForChild("RewardText"))
local Panels = script.Parent:WaitForChild("Panels")

local UIRoot = {}
UIRoot.Theme = Theme
UIRoot.Kit = Kit

local C: any
local screen: ScreenGui
local panelLayer: Frame
local backdrop: TextButton
local panels: { [string]: any } = {}
local openName: string? = nil

local PANEL_MODULES = {
	"Upgrades",
	"Nibblers",
	"Egg",
	"Travel",
	"Feast",
	"Store",
	"Daily",
	"Gifts",
	"Codes",
	"Settings",
}

local function computeScale(): number
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Theme.DesignSize
	local s = math.min(vp.X / Theme.DesignSize.X, vp.Y / Theme.DesignSize.Y)
	return math.clamp(s, Theme.MinScale, Theme.MaxScale)
end

function UIRoot:Init(controllers)
	C = controllers
	Kit.bind(controllers)
	screen = Kit.new("ScreenGui", {
		Name = "PeakUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	UIRoot.Screen = screen
	-- Everything is authored at 1280x720; one UIScale fits it to any screen.
	local scaler = Kit.new("Frame", {
		Name = "Scaled",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = screen,
	})
	local uiScale = Kit.new("UIScale", { Parent = scaler })
	local function rescale()
		local s = computeScale()
		uiScale.Scale = s
		-- Counter-size the scaled frame so its children still span the real screen.
		scaler.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	UIRoot.Layer = scaler

	Notifications.Init(C, Kit, Theme, scaler)
	Hud.Build(C, Kit, Theme, UIRoot, scaler)

	backdrop = Kit.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Theme.Colors.ink,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = scaler,
	})
	backdrop.Activated:Connect(function()
		UIRoot:Close()
	end)
	panelLayer =
		Kit.new("Frame", { Name = "Panels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = scaler })

	for _, name in PANEL_MODULES do
		local build = require(Panels:WaitForChild(name)) :: any
		local panel = build(C, Kit, Theme, UIRoot)
		panel.root.Parent = panelLayer
		-- Close button on every panel
		Kit.button({
			text = "✕",
			color = Theme.Colors.berry,
			textColor = Theme.Colors.white,
			size = UDim2.fromOffset(64, 64),
			position = UDim2.new(1, -40, 0, -24),
			parent = panel.root,
			onClick = function()
				UIRoot:Close()
			end,
		})
		panels[name] = panel
	end

	Onboarding.Build(C, Kit, Theme, UIRoot, scaler)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function UIRoot:Start()
	C.ClientNet:On("Notify", function(text, style)
		Notifications.Toast(text, style)
		if style == "unlock" or style == "rebirth" then
			C.Audio:Play("Unlock")
			C.Effects:Punch(0.5)
			C.LightingFX:Flash(0.5)
		end
	end)
	C.ClientNet:On("Announce", function(text, style)
		Notifications.Banner(text, style)
		if style == "order" then
			C.Audio:Play("Order", { volume = 0.6 })
		elseif style == "tower" or style == "legendary" or style == "mythic" or style == "shiny" then
			C.Audio:Play("Perfect", { volume = 0.5, pitch = 1.3 })
		end
	end)
	C.ClientNet:On("Reward", function(r)
		if r.results then
			local nibblers = {}
			for _, res in r.results do
				if res.kind == "Nibbler" then
					table.insert(nibblers, { uid = res.uid, id = res.nibbler, shiny = res.shiny })
				else
					Notifications.Toast(RewardText.result(res), "success")
				end
			end
			if #nibblers > 0 then
				C.EggReveal:Show(nil, nibblers, false)
			end
			C.Audio:Play("Purchase")
		end
		for _, p in panels do
			if p.onReward then
				p.onReward(r)
			end
		end
	end)
	C.State.Changed:Connect(function(keys)
		if keys.offline and C.State.data.offline then
			Notifications.Banner("Studio test: DataStores are off, progress won't save", "zone")
		end
		for name, p in panels do
			if p.refresh and (openName == name or p.alwaysRefresh) then
				p.refresh(keys)
			end
		end
	end)
end

function UIRoot:IsOpen(name: string): boolean
	return openName == name
end

function UIRoot:Open(name: string, args: any?)
	local panel = panels[name]
	if not panel then
		return
	end
	if openName and openName ~= name then
		local prev = panels[openName]
		prev.root.Visible = false
		if prev.onClose then
			prev.onClose()
		end
	end
	openName = name
	backdrop.Visible = true
	backdrop.BackgroundTransparency = 0.6
	panel.root.Visible = true
	panel.scale.Scale = 0.6
	Kit.springScale(panel.scale, 1, 24, 0.6)
	C.LightingFX:SetBlur(10)
	C.Audio:Play("PanelOpen")
	if panel.onOpen then
		panel.onOpen(args)
	end
	if panel.refresh then
		panel.refresh({ all = true })
	end
	if GuiService:IsTenFootInterface() or C.InputController:UsingGamepad() then
		GuiService.SelectedObject = panel.firstSelectable and panel.firstSelectable() or nil
	end
end

function UIRoot:Close()
	if not openName then
		return
	end
	local panel = panels[openName]
	openName = nil
	Kit.springScale(panel.scale, 0.5, 30, 1)
	task.delay(0.12, function()
		if openName == nil or panels[openName] ~= panel then
			panel.root.Visible = false
		end
	end)
	if panel.onClose then
		panel.onClose()
	end
	backdrop.Visible = false
	C.LightingFX:SetBlur(0)
	GuiService.SelectedObject = nil
end

function UIRoot:Toggle(name: string)
	if openName == name then
		self:Close()
	else
		self:Open(name)
	end
end

function UIRoot:Toast(text: string, style: string?)
	Notifications.Toast(text, style)
end

-- Pulse a HUD button (used by onboarding).
function UIRoot:Highlight(name: string)
	local b = Hud.Buttons[name]
	if not b then
		return
	end
	local s = b:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 1.25
		Kit.springScale(s, 1, 14, 0.3)
	end
end

UIRoot.Hud = Hud

return UIRoot
