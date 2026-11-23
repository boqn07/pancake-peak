--!strict
-- Every uploaded-asset dependency lives here. Empty strings fall back to code-built visuals or silence.
-- The defaults use sounds that ship inside every Roblox client (rbxasset://), so the game has
-- audio out of the box. Replace them with your own uploads (see docs/HUMAN_TASKS.md).
return {
	Sounds = {
		Drop = "rbxasset://sounds/clickfast.wav", -- a pancake lands (pitched up with height)
		Perfect = "rbxasset://sounds/electronicpingshort.wav", -- perfect drop (pitched up with combo)
		Slice = "rbxasset://sounds/swoosh.wav", -- overhang sliced off
		Topple = "rbxasset://sounds/swoosh.wav",
		Chomp = "rbxasset://sounds/clickfast.wav", -- a Yeti eats one pancake
		Serve = "rbxasset://sounds/electronicpingshort.wav",
		Craving = "rbxasset://sounds/swoosh.wav",
		Click = "rbxasset://sounds/button.wav",
		Hover = "rbxasset://sounds/clickfast.wav",
		Purchase = "rbxasset://sounds/electronicpingshort.wav",
		Error = "rbxasset://sounds/clickfast.wav",
		PanelOpen = "rbxasset://sounds/swoosh.wav",
		EggShake = "rbxasset://sounds/clickfast.wav",
		EggCrack = "rbxasset://sounds/swoosh.wav",
		Unlock = "rbxasset://sounds/swoosh.wav",
		Order = "rbxasset://sounds/swoosh.wav",
		Stomp = "rbxasset://sounds/button.wav",
	},
	-- Background music. Empty = no music (Roblox requires you to own or license tracks).
	Music = {
		Default = "",
		SnowDay = "",
	},
	-- Optional images.
	Images = {
		Snowflake = "", -- snowfall / sparkle texture; empty uses Roblox's built-in sparkle texture
		Crumb = "", -- crumb bursts; empty uses Roblox's built-in sparkle texture
		Steam = "", -- cocoa steam; empty uses Roblox's built-in smoke texture
	},
}
