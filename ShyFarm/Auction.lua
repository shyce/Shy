-- The auction house, while you stand at it, only if you let it (T.db.auction) and only while the auction addon is
-- off (its scans price everything, and it keeps the book ShyFarm asks): every search you make there
-- leaves its lowest price in the book, and a click (or, set so, the auction house opening) looks up what you
-- farm, one item at a time as the game allows. An item you asked to check there (the card's "Auction house")
-- is looked up as soon as it opens.

local ADDON, ns = ...
local T = ns.T
local P = ns.Prices

local A = {}
ns.Auction = A

local K = {
	LOOK = 25,       -- results looked through for the lowest price
	WAIT = 6,        -- seconds a lookup may take before it is given up
}
local SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }

local open = false
local queue, asking, askedAt = {}, nil, 0
local remind = {}    -- items you asked to check at the auction house: [item] = true

function A.IsOpen() return open end
function A.Busy() return asking ~= nil or #queue > 0 end

-- To check at the auction house when you next open it.
function A.Remind(item) remind[item] = true end
function A.Reminded(item) return remind[item] == true end

-- What wants a price there: the item farmed, then what the session looted, then what you asked to check.
function A.Wanting()
	local out, seen = {}, {}
	local function Add(item)
		if item and not seen[item] and (remind[item] or P.Wanting(item)) then
			seen[item] = true
			out[#out + 1] = item
		end
	end
	local s = ns.Session.Current()
	if s and s.want then Add(s.want.item) end
	for item in pairs(remind) do Add(item) end
	if s then
		local looted = {}
		for item in pairs(s.items) do looted[#looted + 1] = item end
		table.sort(looted)
		for _, item in ipairs(looted) do Add(item) end
	end
	return out
end

-- The lowest price in what the game has for an item now: commodities by the unit, items by the buyout over
-- their count. nil when nobody sells one.
local function Lowest(item, key)
	local least
	local function Take(copper)
		if copper and not issecretvalue(copper) and copper > 0 and (not least or copper < least) then least = copper end
	end
	local n = C_AuctionHouse.GetNumCommoditySearchResults(item)
	for i = 1, math.min(n or 0, K.LOOK) do
		local result = C_AuctionHouse.GetCommoditySearchResultInfo(item, i)
		if result then Take(result.unitPrice) end
	end
	if key then
		n = C_AuctionHouse.GetNumItemSearchResults(key)
		for i = 1, math.min(n or 0, K.LOOK) do
			local result = C_AuctionHouse.GetItemSearchResultInfo(key, i)
			if result and result.buyoutAmount and result.quantity and result.quantity > 0 then
				Take(math.floor(result.buyoutAmount / result.quantity))
			end
		end
	end
	return least
end

local Next
local said = 0   -- lookups of this batch said in chat

-- What a lookup of ours found, in chat (T.db.tell): the item's link, the lowest price each and what it was before,
-- or that nobody sells one. A search of your own says nothing: you see its results.
local function Tell(item, least, was)
	said = said + 1
	if not T.db.tell then return end
	local link = select(2, C_Item.GetItemInfo(item)) or C_Item.GetItemNameByID(item) or ("item " .. item)
	if not least then
		T:Print(("%s: nobody is selling it."):format(link))
		return
	end
	local before = ""
	if was and was ~= least then before = (" (was %s)"):format(P.Text(was)) end
	T:Print(("%s: %s each at the auction house%s."):format(link, P.Text(least), before))
end

-- A lookup of ours answered (least nil: nobody sells one): kept, said, and the next one asked.
local function Answered(item, least)
	local was = P.Auction(item)
	P.SetAuction(item, least)
	remind[item] = nil
	asking = nil
	Tell(item, least, was)
	Next()
end

-- What the game said of an item: kept, and the next one asked.
local function Heard(item, key)
	if not T.db.auction then return end
	local least = Lowest(item, key)
	if asking == item then
		Answered(item, least)
	elseif least then
		P.SetAuction(item, least)
	end
end

function Next()
	if not open or asking then return end
	if not C_AuctionHouse.IsThrottledMessageSystemReady() then return end   -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY asks again
	local item = table.remove(queue, 1)
	if not item then
		-- (A batch of more than one ends with a word on how many.)
		if said > 1 and T.db.tell then T:Print(("checked %d prices."):format(said)) end
		said = 0
		ns.Changed("checked")
		return
	end
	asking, askedAt = item, GetTime()
	local at = askedAt
	C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(item), SORTS, false)
	-- Nobody answered in time: taken as nobody selling one, and the next one asked.
	C_Timer.After(K.WAIT, function()
		if asking == item and askedAt == at then Answered(item, nil) end
	end)
	ns.Changed("checking")
end

-- Looks up every item that wants a price (or those given), one after another.
function A.Check(items)
	if not open then return false end
	for _, item in ipairs(items or A.Wanting()) do
		local there = asking == item
		for _, queued in ipairs(queue) do
			if queued == item then there = true end
		end
		if not there then queue[#queue + 1] = item end
	end
	Next()
	return true
end

-- How the lookups stand: how many are left, counting the one asked.
function A.Left()
	return #queue + (asking and 1 or 0)
end

-- You stopped letting it read: what stood in line is dropped, and the one asked is forgotten (its answer would
-- go unheard, and count as nobody selling one).
function A.Rest()
	if T.db.auction then return end
	wipe(queue)
	asking, said = nil, 0
end

local events = CreateFrame("Frame")
local handlers = {
	AUCTION_HOUSE_SHOW = function()
		open = true
		if not T.db.auction then return end
		local now = {}
		for item in pairs(remind) do now[#now + 1] = item end
		if T.db.autoCheck then A.Check() elseif #now > 0 then A.Check(now) end
		ns.Changed("auction")
	end,
	AUCTION_HOUSE_CLOSED = function()
		open, asking, said = false, nil, 0
		wipe(queue)
		ns.Changed("auction")
	end,
	AUCTION_HOUSE_THROTTLED_SYSTEM_READY = function() Next() end,
	COMMODITY_SEARCH_RESULTS_UPDATED = function(item)
		if item and not issecretvalue(item) then Heard(item) end
	end,
	ITEM_SEARCH_RESULTS_UPDATED = function(key)
		local item = type(key) == "table" and key.itemID
		if item and not issecretvalue(item) then Heard(item, key) end
	end,
}

-- (With the auction addon on, the auction house is its own to read: it keeps the one price book.)
function A.Start()
	if Shy.addons.Auction then return end
	for event in pairs(handlers) do events:RegisterEvent(event) end
	events:SetScript("OnEvent", Shy.Clocked("farm: the auction house", function(_, event, ...)
		local ok, err = pcall(handlers[event], ...)
		if not ok then geterrorhandler()(err) end
	end))
end
