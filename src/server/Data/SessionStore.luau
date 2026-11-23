--!strict
-- Session-locked player storage on top of a DataStore (the ProfileService/ProfileStore pattern).
--
-- Stored record shape:  { data = <profile>, lock = { jobId = string, session = string, time = number }? }
--
-- Guarantees:
--   * Only one server owns a profile at a time (lock written atomically with UpdateAsync).
--   * A live server's lock is never stolen; a lock older than `lockStale` (dead server) is taken over.
--   * Every save re-checks the lock; if another server (or a newer session for the same player on
--     this server) took it over, this session stops saving, so two sessions can never overwrite
--     each other and duplicate items.
--   * A profile that failed to load is never saved, so outages can't wipe real data.
-- All engine access is injected so the whole thing runs in unit tests with a failing mock store.

export type Deps = {
	store: any, -- object with :UpdateAsync(key, transform)
	jobId: string,
	now: () -> number,
	wait: (seconds: number) -> (),
	log: (message: string) -> (),
	migrate: (data: any) -> (any, boolean, string?),
}

export type Options = {
	lockStale: number,
	loadRetries: number,
	retryDelay: number,
	saveRetries: number,
}

export type Session = {
	key: string,
	data: any,
	active: boolean,
	stolen: boolean,
	lastSave: number,
	token: string,
}

local SessionStore = {}
SessionStore.__index = SessionStore

function SessionStore.new(deps: Deps, opts: Options)
	return setmetatable({ _deps = deps, _opts = opts, _count = 0 }, SessionStore)
end

-- Returns (session, nil) or (nil, reason). reason is "locked", "error" or a migration error.
function SessionStore.load(self: any, key: string): (Session?, string?)
	local deps, opts = self._deps, self._opts
	local lastReason = "error"
	self._count += 1
	local token = deps.jobId .. "#" .. tostring(self._count)
	for attempt = 1, opts.loadRetries do
		local status, loaded, migrateErr = "error", nil, nil
		local ok, err = pcall(function()
			deps.store:UpdateAsync(key, function(old: any)
				local now = deps.now()
				local lock = if type(old) == "table" then old.lock else nil
				if lock and lock.jobId ~= deps.jobId and now - (tonumber(lock.time) or 0) < opts.lockStale then
					status = "locked"
					return nil -- cancel the write, keep their lock
				end
				local profile, good, why = deps.migrate(if type(old) == "table" then old.data else nil)
				if not good then
					status, migrateErr = "bad", why
					return nil
				end
				status, loaded = "ok", profile
				return { data = profile, lock = { jobId = deps.jobId, session = token, time = now } }
			end)
		end)
		if ok and status == "ok" then
			return { key = key, data = loaded, active = true, stolen = false, lastSave = deps.now(), token = token },
				nil
		end
		if ok and status == "bad" then
			deps.log(string.format("profile %s refused: %s", key, tostring(migrateErr)))
			return nil, migrateErr or "bad data"
		end
		if not ok then
			deps.log(string.format("load %s attempt %d failed: %s", key, attempt, tostring(err)))
			lastReason = "error"
		else
			lastReason = status
		end
		if attempt < opts.loadRetries then
			deps.wait(opts.retryDelay * attempt)
		end
	end
	return nil, lastReason
end

-- Save the session. With release = true the lock is dropped and the session ends.
-- Returns true when the data is safely stored.
function SessionStore.save(self: any, session: Session, release: boolean): boolean
	local deps, opts = self._deps, self._opts
	if not session.active then
		return false
	end
	for attempt = 1, opts.saveRetries do
		if not session.active then
			return false -- released by another save while this one was retrying
		end
		local status = "error"
		local ok, err = pcall(function()
			deps.store:UpdateAsync(session.key, function(old: any)
				local lock = if type(old) == "table" then old.lock else nil
				if not lock or lock.jobId ~= deps.jobId or lock.session ~= session.token then
					status = "stolen"
					return nil
				end
				status = "ok"
				return {
					data = session.data,
					lock = if release then nil else { jobId = deps.jobId, session = session.token, time = deps.now() },
				}
			end)
		end)
		if ok and status == "ok" then
			session.lastSave = deps.now()
			if release then
				session.active = false
			end
			return true
		end
		if ok and status == "stolen" then
			deps.log(string.format("session %s was taken over by another server; no longer saving", session.key))
			session.active = false
			session.stolen = true
			return false
		end
		deps.log(string.format("save %s attempt %d failed: %s", session.key, attempt, tostring(err)))
		if attempt < opts.saveRetries then
			deps.wait(opts.retryDelay * attempt)
		end
	end
	return false
end

return SessionStore
