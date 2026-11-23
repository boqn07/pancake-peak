--!strict
-- Keyboard shortcuts and gamepad navigation for menus. (Flip and serve keys live in StackInput.)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local InputController = {}

local C: any

function InputController:Init(controllers)
	C = controllers
end

function InputController:UsingGamepad(): boolean
	local t = UserInputService:GetLastInputType()
	return t.Name:sub(1, 7) == "Gamepad"
end

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.U] = "Upgrades",
	[Enum.KeyCode.G] = "Nibblers",
	[Enum.KeyCode.T] = "Travel",
	[Enum.KeyCode.Y] = "Feast",
	[Enum.KeyCode.B] = "Store",
	-- Gamepad: R2 is FLIP and X is SERVE (StackInput); Y is the proximity-prompt key (eggs, gates).
	[Enum.KeyCode.ButtonL1] = "Nibblers",
	[Enum.KeyCode.ButtonR1] = "Feast",
	[Enum.KeyCode.DPadUp] = "Upgrades",
	[Enum.KeyCode.DPadLeft] = "Travel",
	[Enum.KeyCode.DPadRight] = "Store",
	[Enum.KeyCode.DPadDown] = "Daily",
}

function InputController:Start()
	local keys = {}
	for k in KEYS do
		table.insert(keys, k)
	end
	ContextActionService:BindAction("PeakMenus", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		local panel = KEYS[input.KeyCode]
		if panel then
			C.UIRoot:Toggle(panel)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))

	-- B / Backspace closes the open panel.
	ContextActionService:BindAction("PeakClose", function(_, state)
		if
			state == Enum.UserInputState.Begin and GuiService.SelectedObject ~= nil
			or state == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil
		then
			C.UIRoot:Close()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
end

return InputController
