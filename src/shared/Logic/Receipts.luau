--!strict
-- Idempotency bookkeeping for ProcessReceipt. The profile keeps the last N PurchaseIds.
local Game = require(script.Parent.Parent.Config.Game)

local Receipts = {}

function Receipts.seen(profile: any, purchaseId: string): boolean
	for _, id in profile.receipts do
		if id == purchaseId then
			return true
		end
	end
	return false
end

function Receipts.record(profile: any, purchaseId: string)
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > Game.ReceiptHistorySize do
		table.remove(profile.receipts, 1)
	end
end

return Receipts
