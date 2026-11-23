--!strict
-- The "camp-mug enamel" UI style: cream enamel panels with a chunky ink-blue rim and little
-- speckles, red gingham headers, warm wooden buttons and round, friendly FredokaOne lettering,
-- like the tin mugs and picnic cloths at a mountain cabin. Everything reads colors and sizes from here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rarities"))

local hex = Color3.fromHex

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
-- Body text (descriptions, small print) uses a clean, easy-to-read face.
Theme.BodyFont = Enum.Font.GothamBold

Theme.Colors = {
	paper = hex("#FFF8EC"), -- enamel panel body (cream)
	paperDark = hex("#F1E3CB"), -- insets, bar backs
	white = hex("#FFFFFF"),
	snow = hex("#F4F7FB"),
	ink = hex("#24406B"), -- text, rims, shadows (never pure black)
	muted = hex("#6B7B95"), -- secondary text on panels
	ice = hex("#5CC8F0"), -- primary action / info
	navy = hex("#2F5C9A"),
	berry = hex("#E5484D"), -- gingham red, warnings, prices you can't afford
	maple = hex("#F2A33A"), -- currency, highlights
	butter = hex("#FFD66B"),
	pine = hex("#4F8A5B"), -- confirm / buy
	cocoa = hex("#7A4F33"),
	wood = hex("#C98B55"),
	aurora = hex("#8C7BE8"),
	cheek = hex("#FF9FB8"),
	locked = hex("#C9C2B5"),
}

Theme.Rarity = {} :: { [string]: Color3 }
for _, r in Rarities.List do
	Theme.Rarity[r.id] = hex(r.color)
end
Theme.ShinyGradient = {} :: { Color3 }
for _, c in Rarities.Shiny.gradient do
	table.insert(Theme.ShinyGradient, hex(c))
end

-- Design resolution: layouts are authored for 1280x720 and scaled by UIScale.
Theme.DesignSize = Vector2.new(1280, 720)
Theme.MinScale = 0.55
Theme.MaxScale = 1.35
Theme.Corner = UDim.new(0, 20)
Theme.StrokeThickness = 3
Theme.StickerBorder = 5 -- the ink-blue enamel rim
-- Minimum touch target at design resolution (≈ 48 px after phone scaling).
Theme.TouchTarget = 84

return Theme
