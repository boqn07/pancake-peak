--!strict
-- Type checks for remote arguments. Every remote handler runs its arguments through these.
local Validate = {}

function Validate.string(v: any, maxLen: number): boolean
	return type(v) == "string" and #v > 0 and #v <= maxLen and utf8.len(v) ~= nil
end

function Validate.int(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v == math.floor(v) and v >= min and v <= max
end

function Validate.bool(v: any): boolean
	return type(v) == "boolean"
end

-- True when `v` is a string key of `t` (used for config ids such as upgrade or zone ids).
function Validate.key(v: any, t: { [string]: any }): boolean
	return type(v) == "string" and #v <= 64 and t[v] ~= nil
end

return Validate
