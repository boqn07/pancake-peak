--!strict
-- Daily streak logic on UTC days.
local Daily = {}

function Daily.dayIndex(unixTime: number): number
	return unixTime // 86400
end

-- Returns (canClaim, dayNumber 1..length, streakWouldReset)
function Daily.status(
	state: { streak: number, lastDay: number },
	now: number,
	length: number
): (boolean, number, boolean)
	local today = Daily.dayIndex(now)
	if state.lastDay == today then
		return false, ((state.streak - 1) % length) + 1, false
	end
	local continues = state.lastDay == today - 1
	local nextStreak = if continues then state.streak + 1 else 1
	return true, ((nextStreak - 1) % length) + 1, not continues and state.streak > 0
end

-- Mutates state. Returns the claimed day number (1..length) or nil if already claimed today.
function Daily.claim(state: { streak: number, lastDay: number }, now: number, length: number): number?
	local can, day = Daily.status(state, now, length)
	if not can then
		return nil
	end
	local today = Daily.dayIndex(now)
	state.streak = if state.lastDay == today - 1 then state.streak + 1 else 1
	state.lastDay = today
	return day
end

-- Seconds until the next UTC day starts.
function Daily.secondsUntilReset(now: number): number
	return 86400 - (now % 86400)
end

return Daily
