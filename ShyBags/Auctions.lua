-- Owned auctions: what is listed, and what has sold but is not yet paid.
--   character.auctions = { at = time, { id, item, n, bid, buyout, exp, sold, soldAt }, ... }
-- A sale only marks the auction sold; Mail.lua books the gold and drops the auction when the invoice arrives.

local ADDON, ns = ...
local Store = ns.Store

local Auctions = {}
ns.Auctions = Auctions

local STALE = 3 * 86400   -- drop sold auctions older than this

local open = false
local wanted = false   -- a query is pending

local function Ask()
	if not (open and wanted) then return end
	-- The auction house window asks for them itself: its answer is read here (OWNED_AUCTIONS_UPDATED).
	if Shy.addons.Auction then
		wanted = false
		return
	end
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then return end   -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY asks again
	wanted = false
	C_AuctionHouse.QueryOwnedAuctions({})
end

local function Read()
	local c = Store.Me()
	if not c or not open then return end
	local now = ns.Now()
	local list = {}
	for index = 1, C_AuctionHouse.GetNumOwnedAuctions() do
		local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
		if info then
			local id = info.itemKey.itemID
			Store.Note(id)
			list[#list + 1] = {
				id = info.auctionID,
				item = info.itemLink and Store.ItemString(info.itemLink) or tostring(id),
				n = info.quantity,
				bid = info.bidAmount,
				buyout = info.buyoutAmount,
				exp = info.timeLeftSeconds and (now + info.timeLeftSeconds) or nil,
				sold = (info.status == Enum.AuctionStatus.Sold) and true or nil,
				soldAt = (info.status == Enum.AuctionStatus.Sold) and now or nil,
			}
		end
	end
	c.auctions = list
	Store.Touch("auctions")
end

local function Sold(id)
	local c = Store.Me()
	if not c then return end
	c.auctions = c.auctions or {}
	for _, auction in ipairs(c.auctions) do
		if auction.id == id then
			auction.sold, auction.soldAt = true, auction.soldAt or ns.Now()
			Store.Touch("auctions")
			return
		end
	end
end

function Auctions.IsOpen() return open end

-- An invoice for this item at this price is in the mailbox.
function Auctions.Paid(c, name, price)
	local list = c.auctions
	if not list then return end
	local byName
	for index, auction in ipairs(list) do
		if auction.sold then
			local _, _, _, plain = Store.Fact(Store.ItemID(auction.item) or 0)
			if plain == name then
				if (auction.buyout or auction.bid) == price then
					table.remove(list, index)
					return
				end
				byName = byName or index
			end
		end
	end
	if byName then table.remove(list, byName) end
end

function Auctions.Init()
	local now = ns.Now()
	for _, entry in ipairs(Store.List()) do
		local list = entry.char.auctions
		for index = #(list or {}), 1, -1 do
			local auction = list[index]
			if auction.sold and now - (auction.soldAt or 0) > STALE then table.remove(list, index) end
		end
	end

	local events = CreateFrame("Frame")
	events:RegisterEvent("AUCTION_HOUSE_SHOW")
	events:RegisterEvent("AUCTION_HOUSE_CLOSED")
	events:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
	events:RegisterEvent("OWNED_AUCTIONS_UPDATED")
	events:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
	events:RegisterEvent("AUCTION_CANCELED")
	events:RegisterEvent("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION")
	events:SetScript("OnEvent", function(_, event, a, _, auctionID)
		if event == "AUCTION_HOUSE_SHOW" then
			open, wanted = true, true
			Ask()
		elseif event == "AUCTION_HOUSE_CLOSED" then
			open = false
		elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
			Ask()
		elseif event == "OWNED_AUCTIONS_UPDATED" then
			ns.Guard(Read)
		elseif event == "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION" then
			if a == Enum.AuctionHouseNotification.AuctionSold and auctionID then Sold(auctionID) end
		else
			wanted = true
			Ask()
		end
	end)
end
