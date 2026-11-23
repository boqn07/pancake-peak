-- Tiny test framework: describe / it / expect.
local T = { passed = 0, failed = 0, failures = {} }

local current = ""

function T.describe(name: string, fn: () -> ())
	local prev = current
	current = if prev == "" then name else prev .. " > " .. name
	fn()
	current = prev
end

function T.it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		T.passed += 1
	else
		T.failed += 1
		table.insert(T.failures, current .. " > " .. name .. "\n    " .. tostring(err))
	end
end

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function T.expect(actual: any)
	local e = {}
	function e.toBe(expected: any)
		if actual ~= expected then
			error(string.format("expected %s, got %s", fmt(expected), fmt(actual)), 2)
		end
	end
	function e.toBeNear(expected: number, eps: number?)
		if type(actual) ~= "number" or math.abs(actual - expected) > (eps or 1e-6) then
			error(string.format("expected ~%s, got %s", fmt(expected), fmt(actual)), 2)
		end
	end
	function e.toBeTruthy()
		if not actual then
			error("expected truthy, got " .. fmt(actual), 2)
		end
	end
	function e.toBeFalsy()
		if actual then
			error("expected falsy, got " .. fmt(actual), 2)
		end
	end
	function e.toBeGreaterThan(n: number)
		if not (actual > n) then
			error(string.format("expected > %s, got %s", fmt(n), fmt(actual)), 2)
		end
	end
	function e.toBeLessThan(n: number)
		if not (actual < n) then
			error(string.format("expected < %s, got %s", fmt(n), fmt(actual)), 2)
		end
	end
	function e.toBeBetween(a: number, b: number)
		if not (actual >= a and actual <= b) then
			error(string.format("expected between %s and %s, got %s", fmt(a), fmt(b), fmt(actual)), 2)
		end
	end
	return e
end

-- Deterministic RNG (LCG) for reproducible tests.
function T.rng(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return T
