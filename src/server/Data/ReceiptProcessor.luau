--!strict
-- Idempotent developer-product receipts. Returns "Granted" or "NotProcessedYet".
-- Roblox retries any receipt that isn't granted, so the rules are:
--   1. No loaded profile yet -> NotProcessedYet (Roblox will retry when the player is back).
--   2. PurchaseId already recorded -> grant nothing; save, and return Granted once the save works.
--   3. Otherwise grant, record the PurchaseId, save, and return Granted only if the save worked.
--      If the save fails, the id is still in memory, so the retry hits rule 2 instead of granting twice,
--      and Roblox only stops retrying once the purchase is really stored.
local Receipts = require(game:GetService("ReplicatedStorage").Shared.Logic.Receipts)

export type Deps = {
	getSession: (userId: number) -> any?, -- loaded, active session or nil
	productKey: (productId: number) -> string?,
	grant: (userId: number, session: any, productKey: string) -> boolean,
	save: (session: any) -> boolean,
	log: (message: string) -> (),
}

local ReceiptProcessor = {}

function ReceiptProcessor.process(
	deps: Deps,
	receipt: { PlayerId: number, ProductId: number, PurchaseId: string }
): string
	local session = deps.getSession(receipt.PlayerId)
	if not session or not session.active then
		return "NotProcessedYet"
	end
	local profile = session.data
	if Receipts.seen(profile, receipt.PurchaseId) then
		return if deps.save(session) then "Granted" else "NotProcessedYet"
	end
	local key = deps.productKey(receipt.ProductId)
	if not key then
		deps.log("unknown product id " .. tostring(receipt.ProductId))
		return "NotProcessedYet"
	end
	local ok, granted = pcall(deps.grant, receipt.PlayerId, session, key)
	if not ok or not granted then
		deps.log("grant failed for " .. key .. ": " .. tostring(granted))
		return "NotProcessedYet"
	end
	Receipts.record(profile, receipt.PurchaseId)
	if deps.save(session) then
		return "Granted"
	end
	return "NotProcessedYet"
end

return ReceiptProcessor
