-- Session locking, failure handling and receipt idempotency against a mock DataStore that can fail.
local L = require("./Loader")
return function(T)
	local SessionStore = L.get("Server/Data/SessionStore")
	local ReceiptProcessor = L.get("Server/Data/ReceiptProcessor")
	local Schema = L.get("Shared/Logic/Schema")

	-- Deep copy simulates serialization: nothing in the store aliases live tables.
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		local t = {}
		for k, x in v do
			t[k] = copy(x)
		end
		return t
	end

	local function mockStore()
		local store = { data = {}, failures = 0, calls = 0 }
		function store:UpdateAsync(key, fn)
			self.calls += 1
			if self.failures > 0 then
				self.failures -= 1
				error("502: DataStore request failed (mock)")
			end
			local result = fn(copy(self.data[key]))
			if result ~= nil then
				self.data[key] = copy(result)
			end
			return result
		end
		return store
	end

	local clock = 1000
	local function newServer(store, jobId)
		return SessionStore.new({
			store = store,
			jobId = jobId,
			now = function()
				return clock
			end,
			wait = function(s)
				clock += s
			end,
			log = function() end,
			migrate = Schema.migrate,
		}, { lockStale = 240, loadRetries = 3, retryDelay = 1, saveRetries = 3 })
	end

	T.describe("SessionStore", function()
		T.it("creates, saves and reloads a profile", function()
			local store = mockStore()
			local a = newServer(store, "A")
			local s = a:load("u1")
			T.expect(s ~= nil).toBeTruthy()
			s.data.maple = 123
			T.expect(a:save(s, true)).toBeTruthy()
			T.expect(s.active).toBeFalsy()
			local s2 = a:load("u1")
			T.expect(s2.data.maple).toBe(123)
		end)

		T.it("refuses to load while another live server holds the lock", function()
			local store = mockStore()
			local a, b = newServer(store, "A"), newServer(store, "B")
			local sa = a:load("u2")
			T.expect(sa ~= nil).toBeTruthy()
			local sb, why = b:load("u2")
			T.expect(sb).toBe(nil)
			T.expect(why).toBe("locked")
		end)

		T.it("loads once the other server releases", function()
			local store = mockStore()
			local a, b = newServer(store, "A"), newServer(store, "B")
			local sa = a:load("u3")
			sa.data.maple = 50
			a:save(sa, true)
			local sb = b:load("u3")
			T.expect(sb ~= nil).toBeTruthy()
			T.expect(sb.data.maple).toBe(50)
		end)

		T.it("takes over a stale lock from a crashed server, and the crashed server can't overwrite", function()
			local store = mockStore()
			local a, b = newServer(store, "A"), newServer(store, "B")
			local sa = a:load("u4")
			sa.data.maple = 10
			a:save(sa, false)
			clock += 10_000 -- server A stops refreshing (crashed / frozen)
			local sb = b:load("u4")
			T.expect(sb ~= nil).toBeTruthy()
			sb.data.maple = 999
			b:save(sb, false)
			-- A wakes up and tries to save old data: must be refused.
			sa.data.maple = 1
			T.expect(a:save(sa, false)).toBeFalsy()
			T.expect(sa.stolen).toBeTruthy()
			T.expect(store.data.u4.data.maple).toBe(999)
		end)

		T.it("an older session on the same server can't overwrite a newer one", function()
			local store = mockStore()
			local a = newServer(store, "A")
			local old = a:load("u9")
			old.data.maple = 5
			T.expect(a:save(old, true)).toBeTruthy()
			-- The player rejoins this server; a delayed save from the old session must be refused.
			local new = a:load("u9")
			new.data.maple = 500
			T.expect(a:save(new, false)).toBeTruthy()
			old.active = true -- simulate an autosave that started before the release finished
			old.data.maple = 1
			T.expect(a:save(old, false)).toBeFalsy()
			T.expect(store.data.u9.data.maple).toBe(500)
			T.expect(store.data.u9.lock.session).toBe(new.token)
		end)

		T.it("survives transient DataStore failures on load and save", function()
			local store = mockStore()
			local a = newServer(store, "A")
			store.failures = 2
			local s = a:load("u5")
			T.expect(s ~= nil).toBeTruthy()
			s.data.maple = 77
			store.failures = 2
			T.expect(a:save(s, false)).toBeTruthy()
			T.expect(store.data.u5.data.maple).toBe(77)
		end)

		T.it("a total outage fails the load (player is kicked) and never writes defaults", function()
			local store = mockStore()
			store.data.u6 =
				{ data = (function()
					local p = Schema.default()
					p.maple = 5000
					return p
				end)() }
			local a = newServer(store, "A")
			store.failures = 100
			local s, why = a:load("u6")
			T.expect(s).toBe(nil)
			T.expect(why).toBe("error")
			store.failures = 0
			T.expect(store.data.u6.data.maple).toBe(5000)
		end)

		T.it("a failed save keeps data in memory for the next attempt", function()
			local store = mockStore()
			local a = newServer(store, "A")
			local s = a:load("u7")
			s.data.maple = 42
			store.failures = 100
			T.expect(a:save(s, false)).toBeFalsy()
			T.expect(s.active).toBeTruthy()
			store.failures = 0
			T.expect(a:save(s, true)).toBeTruthy()
			T.expect(store.data.u7.data.maple).toBe(42)
		end)

		T.it("refuses profiles from a newer game version without overwriting them", function()
			local store = mockStore()
			store.data.u8 = { data = { version = 99, maple = 1 } }
			local a = newServer(store, "A")
			local s = a:load("u8")
			T.expect(s).toBe(nil)
			T.expect(store.data.u8.data.version).toBe(99)
		end)

		T.it("saves after release are ignored", function()
			local store = mockStore()
			local a = newServer(store, "A")
			local s = a:load("u9")
			a:save(s, true)
			T.expect(a:save(s, false)).toBeFalsy()
		end)
	end)

	T.describe("ReceiptProcessor", function()
		local function setup()
			local store = mockStore()
			local server = newServer(store, "A")
			local session = server:load("p1")
			local grants = 0
			local deps = {
				getSession = function(uid)
					return if uid == 1 then session else nil
				end,
				productKey = function(id)
					return if id == 55 then "MaplePouch" else nil
				end,
				grant = function(_, s, _key)
					grants += 1
					s.data.maple += 500
					return true
				end,
				save = function(s)
					return server:save(s, false)
				end,
				log = function() end,
			}
			return deps, store, session, function()
				return grants
			end
		end

		T.it("grants exactly once for repeated receipts", function()
			local deps, store, session, grants = setup()
			local r = { PlayerId = 1, ProductId = 55, PurchaseId = "abc" }
			T.expect(ReceiptProcessor.process(deps, r)).toBe("Granted")
			T.expect(ReceiptProcessor.process(deps, r)).toBe("Granted")
			T.expect(grants()).toBe(1)
			T.expect(session.data.maple).toBe(500)
			T.expect(store.data.p1.data.maple).toBe(500)
		end)

		T.it("defers when the player isn't loaded or the product is unknown", function()
			local deps = setup()
			T.expect(ReceiptProcessor.process(deps, { PlayerId = 2, ProductId = 55, PurchaseId = "x" }))
				.toBe("NotProcessedYet")
			T.expect(ReceiptProcessor.process(deps, { PlayerId = 1, ProductId = 9, PurchaseId = "y" }))
				.toBe("NotProcessedYet")
		end)

		T.it("a failed save defers, and the retry does not double-grant", function()
			local deps, store, session, grants = setup()
			local r = { PlayerId = 1, ProductId = 55, PurchaseId = "zzz" }
			store.failures = 100
			T.expect(ReceiptProcessor.process(deps, r)).toBe("NotProcessedYet")
			-- Still failing: the retry must not claim success before the purchase is stored.
			T.expect(ReceiptProcessor.process(deps, r)).toBe("NotProcessedYet")
			store.failures = 0
			T.expect(ReceiptProcessor.process(deps, r)).toBe("Granted")
			T.expect(grants()).toBe(1)
			T.expect(session.data.maple).toBe(500)
			T.expect(store.data.p1.data.maple).toBe(500)
		end)

		T.it("a throwing grant defers without recording the purchase", function()
			local deps, _, session = setup()
			deps.grant = function()
				error("boom")
			end
			local r = { PlayerId = 1, ProductId = 55, PurchaseId = "q" }
			T.expect(ReceiptProcessor.process(deps, r)).toBe("NotProcessedYet")
			T.expect(#session.data.receipts).toBe(0)
		end)
	end)
end
