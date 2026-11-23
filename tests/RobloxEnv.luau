-- A headless Roblox-like environment for smoke tests. Loads the Rojo-built place with
-- @lune/roblox (real Instance classes with property validation, so a typo'd property name fails),
-- and fakes the behavioural services (signals, tweens, players, datastores).
-- It cannot simulate physics or networking; it proves that the code builds its world and UI
-- and boots every service without runtime errors.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxEnv = {}

---------------------------------------------------------------------------------------------------
-- Fake signals and engine extensions
---------------------------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	self.handlers[conn] = fn
	-- Remote events queue until the first listener connects, like the engine does.
	if self.queue then
		local queued = self.queue
		self.queue = nil
		for _, args in queued do
			RobloxEnv.spawn(fn, table.unpack(args, 1, args.n))
		end
	end
	function conn.Disconnect(c)
		c.Connected = false
		self.handlers[c] = nil
	end
	return conn
end
Signal.Once = Signal.Connect
function Signal:Wait()
	return coroutine.yield()
end
function Signal:Fire(...)
	if self.queueing and next(self.handlers) == nil then
		self.queue = self.queue or {}
		table.insert(self.queue, table.pack(...))
		return
	end
	for _, fn in self.handlers do
		RobloxEnv.spawn(fn, ...)
	end
end
RobloxEnv.Signal = Signal

local function signalProp()
	return Signal.new()
end
for _, cls in { "TextButton", "ImageButton" } do
	for _, ev in
		{
			"Activated",
			"MouseEnter",
			"MouseLeave",
			"MouseButton1Down",
			"MouseButton1Up",
			"MouseButton1Click",
			"SelectionGained",
			"SelectionLost",
			"InputBegan",
			"InputEnded",
		}
	do
		roblox.implementProperty(cls, ev, signalProp)
	end
end
roblox.implementProperty("Tween", "Completed", signalProp)
roblox.implementProperty("Player", "CharacterAdded", signalProp)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
	return Signal.new()
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function()
	return Signal.new()
end)
-- Lune frees a destroyed instance outright (any later access aborts the process), while the engine
-- keeps it readable with Parent locked to nil. Sources are loaded with :Destroy() rewritten to this.
roblox.implementMethod("Instance", "TestDestroy", function(self)
	self:SetAttribute("TestDestroyed", true)
	self.Parent = nil
end)
roblox.implementMethod("Instance", "TestClearAllChildren", function(self)
	for _, c in self:GetChildren() do
		c:TestDestroy()
	end
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild would hang: " .. self:GetFullName() .. "." .. tostring(name))
	return c
end)
-- The shared server clock follows the fake clock, so bubbles grow while tests step time.
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return 1.7e9 + RobloxEnv.clock
end)
-- No physics: raycasts hit nothing (PopInput falls back to its aim assist).
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)
roblox.implementMethod("Camera", "ViewportPointToRay", function(self)
	return { Origin = self.CFrame.Position, Direction = self.CFrame.LookVector }
end)
roblox.implementMethod("Player", "RequestStreamAroundAsync", function() end)
roblox.implementMethod("Workspace", "BulkMoveTo", function() end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	if self.PrimaryPart then
		self.PrimaryPart.CFrame = cf
	end
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	return if self.PrimaryPart then self.PrimaryPart.CFrame else roblox.CFrame.new()
end)
roblox.implementProperty("Instance", "DescendantAdded", signalProp)
roblox.implementMethod("Model", "GetExtentsSize", function()
	return roblox.Vector3.new(2, 2, 2)
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementMethod("ProximityPrompt", "InputHoldBegin", function() end)
roblox.implementMethod("ProximityPrompt", "InputHoldEnd", function() end)

---------------------------------------------------------------------------------------------------
-- Scheduler: spawned threads run until their first wait and are then parked forever,
-- so infinite service loops don't keep the test process alive.
---------------------------------------------------------------------------------------------------
local errors = {}
RobloxEnv.errors = errors
local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(errors, debug.traceback(co, tostring(err)))
	end
	return co
end
RobloxEnv.spawn = run

-- Fake clock: task.wait/task.delay park until RobloxEnv.step() advances time past them.
RobloxEnv.clock = 0
local parked: { { at: number, co: thread?, fn: any, args: any } } = {}
local fakeTask = {
	spawn = function(fn, ...)
		if type(fn) == "thread" then
			coroutine.resume(fn, ...)
			return fn
		end
		return run(fn, ...)
	end,
	defer = function(fn, ...)
		return run(fn, ...)
	end,
	delay = function(seconds, fn, ...)
		table.insert(parked, { at = RobloxEnv.clock + (seconds or 0), fn = fn, args = table.pack(...) })
	end,
	wait = function(seconds)
		if not coroutine.isyieldable() then
			return 0
		end
		local s = seconds or 0
		table.insert(parked, { at = RobloxEnv.clock + s, co = coroutine.running() })
		coroutine.yield()
		return s
	end,
	cancel = function() end,
}

-- Advance fake time, resuming every parked thread that becomes due, and fire one frame of
-- Heartbeat/RenderStepped per `frame` seconds.
function RobloxEnv.step(seconds: number, frame: number?)
	local target = RobloxEnv.clock + seconds
	local f = frame or seconds
	while RobloxEnv.clock < target - 1e-9 do
		local frameEnd = math.min(target, RobloxEnv.clock + f)
		for _ = 1, 10000 do
			local bestI, best = nil, nil
			for i, e in parked do
				if e.at <= frameEnd and (not best or e.at < best.at) then
					bestI, best = i, e
				end
			end
			if not best then
				break
			end
			table.remove(parked, bestI)
			RobloxEnv.clock = math.max(RobloxEnv.clock, best.at)
			if best.co then
				if coroutine.status(best.co) == "suspended" then
					local ok, err = coroutine.resume(best.co)
					if not ok then
						table.insert(errors, debug.traceback(best.co, tostring(err)))
					end
				end
			else
				run(best.fn, table.unpack(best.args, 1, best.args.n))
			end
		end
		local dt = frameEnd - RobloxEnv.clock
		RobloxEnv.clock = frameEnd
		if RobloxEnv.services then
			RobloxEnv.services.RunService.Heartbeat:Fire(math.max(dt, f))
			RobloxEnv.services.RunService.RenderStepped:Fire(math.max(dt, f))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Fake services
---------------------------------------------------------------------------------------------------
-- Per-instance fake signals (events that @lune/roblox doesn't implement).
local instSignals: { [string]: any } = {}
local function instSignal(inst, name: string)
	local key = inst:GetFullName() .. "#" .. name
	local sig = instSignals[key]
	if not sig then
		sig = Signal.new()
		sig.queueing = name == "client"
		instSignals[key] = sig
	end
	return sig
end

-- Remote calls are deep-copied like real network serialization, so client code can never
-- accidentally alias (and mutate) server tables in tests.
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in v do
		t[copy(k)] = copy(x)
	end
	return t
end
local function copyAll(...)
	local out = table.pack(...)
	for i = 1, out.n do
		out[i] = copy(out[i])
	end
	return table.unpack(out, 1, out.n)
end

RobloxEnv.currentPlayer = nil
roblox.implementProperty("RemoteEvent", "OnServerEvent", function(i)
	return instSignal(i, "server")
end)
roblox.implementProperty("RemoteEvent", "OnClientEvent", function(i)
	return instSignal(i, "client")
end)
roblox.implementMethod("RemoteEvent", "FireServer", function(i, ...)
	instSignal(i, "server"):Fire(RobloxEnv.currentPlayer, copyAll(...))
end)
roblox.implementMethod("RemoteEvent", "FireClient", function(i, player, ...)
	if player == RobloxEnv.currentPlayer then
		instSignal(i, "client"):Fire(copyAll(...))
	end
end)
roblox.implementMethod("RemoteEvent", "FireAllClients", function(i, ...)
	instSignal(i, "client"):Fire(copyAll(...))
end)

-- Players are real Player instances with the bits the engine would provide filled in.
-- (Reflected properties such as UserId cannot be overridden, only assigned.)
roblox.implementMethod("Player", "Kick", function(_, msg)
	table.insert(errors, "kicked: " .. tostring(msg))
end)
roblox.implementMethod("Player", "IsFriendsWith", function()
	return false
end)

local function playerMock(userId: number)
	local p = roblox.Instance.new("Player")
	p.Name = "Tester"
	p.UserId = userId
	p.DisplayName = "Tester"
	local gui = roblox.Instance.new("PlayerGui")
	gui.Parent = p
	return p
end

local function testSource(inst): string
	local src = string.gsub(inst.Source, ":Destroy%(%)", ":TestDestroy()")
	return (string.gsub(src, ":ClearAllChildren%(%)", ":TestClearAllChildren()"))
end

function RobloxEnv.new(placePath: string)
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local workspace = place:GetService("Workspace")
	if not workspace.CurrentCamera then
		local cam = roblox.Instance.new("Camera")
		cam.Parent = workspace
		workspace.CurrentCamera = cam
	end
	workspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1280, 720)
	local localPlayer = playerMock(1)
	localPlayer.Parent = place:GetService("Players")
	RobloxEnv.players = {}
	RobloxEnv.currentPlayer = localPlayer

	local memoryData = {}
	local services = {
		Players = {
			LocalPlayer = localPlayer,
			PlayerAdded = Signal.new(),
			PlayerRemoving = Signal.new(),
			GetPlayers = function()
				return RobloxEnv.players
			end,
			GetPlayerByUserId = function(_, id)
				for _, p in RobloxEnv.players do
					if p.UserId == id then
						return p
					end
				end
				return nil
			end,
			GetNameFromUserIdAsync = function()
				return "Someone"
			end,
		},
		RunService = {
			RenderStepped = Signal.new(),
			Heartbeat = Signal.new(),
			Stepped = Signal.new(),
			BindToRenderStep = function() end,
			IsStudio = function()
				return true
			end,
			IsServer = function()
				return true
			end,
		},
		TweenService = {
			Create = function(_, inst, _info, goal)
				-- Validate goal property names against the instance (catches typos).
				for k in goal do
					local _ = inst[k]
				end
				return { Play = function() end, Cancel = function() end, Completed = Signal.new() }
			end,
		},
		CollectionService = {
			AddTag = function(_, inst, tag)
				inst:AddTag(tag)
			end,
			GetTagged = function()
				return {}
			end,
			GetInstanceAddedSignal = function()
				return Signal.new()
			end,
		},
		UserInputService = {
			TouchEnabled = false,
			KeyboardEnabled = true,
			GamepadEnabled = false,
			MouseEnabled = true,
			LastInputTypeChanged = Signal.new(),
			InputBegan = Signal.new(),
			InputEnded = Signal.new(),
			TouchTapInWorld = Signal.new(),
			GetMouseLocation = function()
				return roblox.Vector2.new(640, 360)
			end,
			GetLastInputType = function()
				return roblox.Enum.UserInputType.MouseButton1
			end,
			GetFocusedTextBox = function()
				return nil
			end,
		},
		GuiService = {
			SelectedObject = nil,
			IsTenFootInterface = function()
				return false
			end,
		},
		ContextActionService = { BindAction = function() end },
		ProximityPromptService = {
			PromptShown = Signal.new(),
			PromptHidden = Signal.new(),
			PromptTriggered = Signal.new(),
		},
		MarketplaceService = {
			PromptGamePassPurchaseFinished = Signal.new(),
			UserOwnsGamePassAsync = function()
				return false
			end,
		},
		DataStoreService = {
			GetDataStore = function()
				return {
					GetAsync = function()
						error("StudioAccessToApisNotAllowed (fake)")
					end,
					UpdateAsync = function(_, key, fn)
						local r = fn(memoryData[key])
						if r ~= nil then
							memoryData[key] = r
						end
						return r
					end,
				}
			end,
			GetOrderedDataStore = function()
				error("no ordered stores in tests")
			end,
		},
	}

	RobloxEnv.services = services
	local game = setmetatable({
		JobId = "",
		GetService = function(_, name)
			return services[name] or place:GetService(name)
		end,
		BindToClose = function() end,
	}, {
		__index = function(_, k)
			return place[k]
		end,
	})

	local cache = {}
	local env
	local function requireInstance(inst)
		if type(inst) == "string" then
			return require(inst)
		end
		if cache[inst] ~= nil then
			return cache[inst]
		end
		assert(inst:IsA("ModuleScript"), "require of non-module " .. inst:GetFullName())
		local fn = luau.load(testSource(inst), { debugName = inst:GetFullName(), environment = env(inst) })
		local result = fn()
		cache[inst] = result
		return result
	end

	local globals = {
		game = game,
		workspace = workspace,
		task = fakeTask,
		require = requireInstance,
		warn = function(...)
			local parts = {}
			for _, v in { ... } do
				table.insert(parts, tostring(v))
			end
			RobloxEnv.warnings = RobloxEnv.warnings or {}
			table.insert(RobloxEnv.warnings, table.concat(parts, " "))
		end,
		os = setmetatable({
			clock = function()
				return RobloxEnv.clock
			end,
		}, { __index = os }),
		RaycastParams = {
			new = function()
				return { FilterType = nil, FilterDescendantsInstances = {} }
			end,
		},
		TweenInfo = {
			new = function(time, style, direction, repeatCount, reverses, delay)
				return {
					Time = time or 1,
					EasingStyle = style,
					EasingDirection = direction,
					RepeatCount = repeatCount or 0,
					Reverses = reverses or false,
					DelayTime = delay or 0,
				}
			end,
		},
		Random = {
			new = function()
				return {
					NextNumber = function(_, a, b)
						a, b = a or 0, b or 1
						return a + math.random() * (b - a)
					end,
					NextInteger = function(_, a, b)
						return math.random(a, b)
					end,
				}
			end,
		},
	}
	for k, v in roblox do
		if type(k) == "string" and string.match(k, "^%u") then
			globals[k] = v
		end
	end
	env = function(scriptInst)
		-- Lune copies the environment's own fields (it ignores metatables), so list every global.
		local e = { script = scriptInst }
		for k, v in globals do
			e[k] = v
		end
		return e
	end

	return {
		place = place,
		game = game,
		services = services,
		require = requireInstance,
		localPlayer = localPlayer,
		run = run,
		-- Run a Script's source (e.g. Main.server.luau) in this environment.
		runScript = function(inst)
			local fn = luau.load(testSource(inst), { debugName = inst:GetFullName(), environment = env(inst) })
			return run(fn)
		end,
	}
end

return RobloxEnv
