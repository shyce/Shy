-- Buying a commodity by the count: the game quotes the price, then a second press pays it. One purchase at a time, for
-- the Buy page and for other addons alike (T:Quote, T:Pay). Each from a click of its own: nothing is paid unasked.
--   ns.Purchase.Quote(item, count)   asks the price: true, or false while a payment is under way
--   ns.Purchase.Pay()                pays the quote that stands: true, or false with none
--   ns.Purchase.Quoted()             item, count, total, paying: the quote that stands (total nil while it is asked,
--                                    paying true once paid and not yet bought), or nil
--   ns.Purchase.Drop()               forgets the quote (never one being paid)
-- Bus SHY_AUCTION: "quote" (item, count, total), "bought" (item, count), "failed" (item).

local ADDON, ns = ...

local Purchase = {}
ns.Purchase = Purchase

local now   -- { item, count, total, paying }

function Purchase.Quote(item, count)
	if now and now.paying then return false end
	now = { item = item, count = count }
	ns.Note("StartCommoditiesPurchase", item, count)
	C_AuctionHouse.StartCommoditiesPurchase(item, count)
	return true
end

function Purchase.Pay()
	if not (now and now.total) or now.paying then return false end
	now.paying = true
	ns.Note("ConfirmCommoditiesPurchase", now.item, now.count)
	C_AuctionHouse.ConfirmCommoditiesPurchase(now.item, now.count)
	return true
end

function Purchase.Quoted()
	if now then return now.item, now.count, now.total, now.paying == true end
end

function Purchase.Drop()
	if now and not now.paying then now = nil end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "COMMODITY_PRICE_UPDATED", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_CLOSED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", Shy.Clocked("auction: purchase", function(_, event, ...)
	local was = now
	if not was then return end
	if event == "COMMODITY_PRICE_UPDATED" then
		local _, total = ...
		if was.paying or was.total or issecretvalue(total) then return end
		was.total = total
		ns.Fire("quote", was.item, was.count, total)
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
		now = nil
		ns.Fire("bought", was.item, was.count)
	elseif event == "COMMODITY_PURCHASE_FAILED" then
		now = nil
		ns.Fire("failed", was.item)
	else
		now = nil
	end
end))
