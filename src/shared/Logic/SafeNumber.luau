--!strict
-- Guards every currency mutation against NaN, infinity, negatives and overflow.
local Game = require(script.Parent.Parent.Config.Game)

local SafeNumber = {}

function SafeNumber.isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Clamp a value into [0, MaxCurrency]; non-finite input becomes 0.
function SafeNumber.currency(n: any): number
	if not SafeNumber.isFinite(n) then
		return 0
	end
	if n < 0 then
		return 0
	end
	if n > Game.MaxCurrency then
		return Game.MaxCurrency
	end
	return n
end

-- Add a positive amount to a balance, saturating at MaxCurrency. Negative/NaN deltas add nothing.
function SafeNumber.add(balance: number, delta: number): number
	balance = SafeNumber.currency(balance)
	delta = SafeNumber.currency(delta)
	return SafeNumber.currency(balance + delta)
end

-- Returns (ok, newBalance). Never goes negative; refuses non-finite or negative prices.
function SafeNumber.trySpend(balance: number, price: number): (boolean, number)
	balance = SafeNumber.currency(balance)
	if not SafeNumber.isFinite(price) or price < 0 then
		return false, balance
	end
	if balance < price then
		return false, balance
	end
	return true, balance - price
end

return SafeNumber
