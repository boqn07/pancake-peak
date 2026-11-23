--!strict
-- Critically-damped-ish spring for UI and follower motion. Works on numbers; wrap per axis for vectors.
-- Pure math (no Roblox types) so it can be unit-tested.
local Spring = {}
Spring.__index = Spring

export type Spring = {
	position: number,
	velocity: number,
	target: number,
	speed: number, -- angular frequency
	damping: number, -- 1 = critical, < 1 bouncy
}

function Spring.new(initial: number, speed: number?, damping: number?): Spring
	return setmetatable({
		position = initial,
		velocity = 0,
		target = initial,
		speed = speed or 18,
		damping = damping or 0.7,
	}, Spring) :: any
end

-- Semi-implicit Euler with sub-steps for stability at low frame rates.
function Spring.step(s: Spring, dt: number): number
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	local w, z = s.speed, s.damping
	for _ = 1, steps do
		local accel = w * w * (s.target - s.position) - 2 * z * w * s.velocity
		s.velocity += accel * h
		s.position += s.velocity * h
	end
	return s.position
end

function Spring.impulse(s: Spring, v: number)
	s.velocity += v
end

function Spring.isResting(s: Spring, eps: number?): boolean
	local e = eps or 1e-3
	return math.abs(s.target - s.position) < e and math.abs(s.velocity) < e
end

return Spring
