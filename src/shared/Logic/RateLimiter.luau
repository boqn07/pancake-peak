--!strict
-- Token-bucket rate limiter keyed by (player key, action). Time source is injected so tests are exact.
export type Limiter = {
	allow: (self: Limiter, key: any, action: string) -> boolean,
	forget: (self: Limiter, key: any) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

-- rules: action -> { rate = tokens per second, burst = max tokens }
function RateLimiter.new(rules: { [string]: { rate: number, burst: number } }, now: () -> number)
	local self = setmetatable({}, RateLimiter)
	self._rules = rules
	self._now = now
	self._buckets = {} :: { [any]: { [string]: Bucket } }
	return self
end

function RateLimiter.allow(self: any, key: any, action: string): boolean
	local rule = self._rules[action] or self._rules.Default
	if not rule then
		return false
	end
	local t = self._now()
	local perKey = self._buckets[key]
	if not perKey then
		perKey = {}
		self._buckets[key] = perKey
	end
	local b = perKey[action]
	if not b then
		b = { tokens = rule.burst, last = t }
		perKey[action] = b
	end
	b.tokens = math.min(rule.burst, b.tokens + (t - b.last) * rule.rate)
	b.last = t
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

-- Drop all state for a key (call on PlayerRemoving so memory never grows).
function RateLimiter.forget(self: any, key: any)
	self._buckets[key] = nil
end

return RateLimiter
