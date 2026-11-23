--!strict
-- Themed proximity prompts (Custom style) that work with keyboard, gamepad and touch.
-- An Egg prompt opens the egg window, a Gate prompt the travel window on that zone, and a Serve
-- prompt (on every Yeti's plate) serves your tower.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Prompts = {}

local C: any
local shown: { [ProximityPrompt]: BillboardGui } = {}

local function keyText(prompt: ProximityPrompt): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "TAP"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Y"
	end
	return prompt.KeyboardKeyCode.Name
end

local function show(prompt: ProximityPrompt)
	if shown[prompt] then
		return
	end
	local T = C.UIRoot.Theme
	local gui = Instance.new("BillboardGui")
	gui.Name = "PeakPrompt"
	gui.Adornee = prompt.Parent :: any
	gui.Size = UDim2.fromOffset(250, 64)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = T.Colors.paper
	button.BackgroundTransparency = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Name = "Button"
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = T.Colors.ink
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Size = UDim2.new(0, 52, 1, -12)
	key.Position = UDim2.fromOffset(6, 6)
	key.BackgroundColor3 = T.Colors.berry
	key.Text = keyText(prompt)
	key.TextScaled = true
	key.Font = T.Font
	key.TextColor3 = T.Colors.white
	key.Parent = button
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0, 12)
	kc.Parent = key
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -70, 1, -12)
	label.Position = UDim2.fromOffset(64, 6)
	label.BackgroundTransparency = 1
	label.Text = prompt.ActionText .. "  ·  " .. prompt.ObjectText
	label.TextScaled = true
	label.Font = T.Font
	label.TextColor3 = T.Colors.ink
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = button
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = button
	button.Activated:Connect(function()
		prompt:InputHoldBegin()
		task.wait()
		prompt:InputHoldEnd()
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	shown[prompt] = gui
end

local function hide(prompt: ProximityPrompt)
	local gui = shown[prompt]
	if gui then
		shown[prompt] = nil
		gui:Destroy()
	end
end

function Prompts:Init(controllers)
	C = controllers
end

function Prompts:Start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(hide)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Kind")
		C.Audio:Play("Click")
		if kind == "Egg" then
			C.UIRoot:Open("Egg", { eggId = prompt:GetAttribute("EggId") })
		elseif kind == "Gate" then
			C.UIRoot:Open("Travel", { focus = prompt:GetAttribute("ZoneId") })
		elseif kind == "Serve" then
			C.StackInput:Serve()
		end
	end)
	-- Keep the touch/gamepad hint right if the player switches input mid-session.
	UserInputService.LastInputTypeChanged:Connect(function()
		for prompt, gui in shown do
			local button = gui:FindFirstChild("Button")
			local key = button and button:FindFirstChild("Key") :: TextLabel?
			if key then
				key.Text = keyText(prompt)
			end
		end
	end)
end

return Prompts
