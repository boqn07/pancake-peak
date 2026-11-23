--!strict
-- Global tunables that do not belong to a single system.
return {
	-- DataStore
	DataStoreName = "PancakePeak_Player_v1",
	AutosaveSeconds = 60,
	-- A session lock not refreshed for this long belongs to a dead server and may be taken over.
	SessionLockStaleSeconds = 60 * 4,
	LoadRetries = 6,
	LoadRetryDelay = 4,
	SaveRetries = 3,
	-- Remember this many purchase ids per player to make ProcessReceipt idempotent.
	ReceiptHistorySize = 100,

	-- Inventory
	InventoryCap = 150,
	BaseEquipSlots = 3,

	-- Hard ceiling on any currency value. Above ~1e300 doubles lose meaning for display and math.
	MaxCurrency = 1e300,

	-- Friends
	FriendBonusPerFriend = 0.10,
	FriendBonusMax = 0.50,

	-- How often the server pushes batched state (maple, stats...) to the owning client.
	StateFlushSeconds = 0.15,

	-- Teleport between owned zones from the Travel menu.
	TeleportCooldown = 3,

	-- Max distance from a Mystery Egg to hatch it.
	EggDistance = 26,

	-- In Studio, pretend the player owns every game pass (handy for testing). Never affects live servers.
	StudioOwnsAllPasses = false,
}
