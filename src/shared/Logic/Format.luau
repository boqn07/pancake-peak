--!strict
-- Number and time formatting for UI. Pure: safe to use on server, client and in tests.
local Format = {}

local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
	"Sxd",
	"Spd",
	"Ocd",
	"Nod",
	"Vg",
}

-- 1234 -> "1.23K", 15300000 -> "15.3M". Keeps 3 significant digits. Falls back to scientific notation.
function Format.abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s
		if n == math.floor(n) then
			s = tostring(math.floor(n))
		else
			s = string.format("%.1f", math.floor(n * 10) / 10)
			s = string.gsub(s, "%.0$", "")
		end
		return (negative and "-" or "") .. s
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		return (negative and "-" or "") .. string.format("%.2e", n)
	end
	-- Tiny upward nudge so values like 4.56e33 don't floor to 4.55 from float error.
	local scaled = n / 10 ^ (tier * 3) * (1 + 1e-12)
	-- Floor (never round up) so "999.99K" never shows as "1000K".
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	text = string.gsub(text, "%.?0+$", "")
	return (negative and "-" or "") .. text .. SUFFIXES[tier + 1]
end

-- 1234567 -> "1,234,567" (for numbers below 1e15; larger values fall back to abbreviate)
function Format.commas(n: number): string
	if n ~= n or math.abs(n) >= 1e15 then
		return Format.abbreviate(n)
	end
	local s = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	out = string.gsub(out, "^,", "")
	return (n < 0 and "-" or "") .. out
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 0.25 -> "x1.25" style multiplier label.
function Format.mult(m: number): string
	return "x" .. Format.abbreviate(math.floor(m * 100 + 0.5) / 100)
end

-- Odds as readable percent: 0.001 -> "0.1%", 0.55 -> "55%"
function Format.percent(p: number): string
	local pct = p * 100
	if pct >= 10 then
		return string.format("%.0f%%", pct)
	elseif pct >= 1 then
		return (string.gsub(string.format("%.1f", pct), "%.0$", "")) .. "%"
	elseif pct >= 0.01 then
		return (string.gsub(string.format("%.2f", pct), "0+$", "")) .. "%"
	end
	return string.format("1 in %s", Format.commas(math.floor(1 / p + 0.5)))
end

return Format
