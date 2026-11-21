-- The auction house: our own window in the game's place (Window.lua: Buy, Sell, Auctions and Farm, the scan bar along
-- its foot), and one price book for the family, filled by scans of the whole auction house (Scan.lua), by every search made
-- there, and by the prices other players on your market scanned (Data/Shared.lua, which the companion app brings). A market is
-- a region, a ruleset and a side: Forever has no realms. Book.lua keeps it.
--
-- Public (Shy.addons.Auction):
--   T:Price(item)           what the auction house asks for one, on your market: { unit (lowest buyout each, copper),
--                           quantity (how many are listed), listings, at (when seen), market (the going price over the
--                           last two weeks, recent days counting most: what to go by), going (the last sighting's),
--                           days (how many days of your own scans the market is from), shared (true: another player's
--                           scan is the newest) } or nil
--   T:Scan()                scans the whole auction house now, if it is open and the server allows it: true, or false and why
--   T:Scanning()            how a scan stands: nil, or { state ("asked" | "reading"), done, of }
--   T:Cut()                 the share of a sale the auction house keeps on your market (0.05 a faction's, 0.15 a goblin's)
--   T:Show(page)            at the auction house, its window on that page ("buy" | "sell" | "auctions" | "farm"):
--                           true, or false while the auction house isn't open or the window isn't ours
--   T:Find(item)            at the auction house, its window on Buy with that item (an item ID) picked and the
--                           auction house asked what is listed of it: true, or false as T:Show
--   T:Market()              your market's key ("US-PvP-Alliance") and when it was last scanned (by you or anyone)
--   T:CraftPlan(r)          what a recipe is worth to make here (Craft.lua has r and the answer): its worth, the cost of
--                           its reagents (a vendor's or the auction house's, the cheaper), the profit, what you lack and can afford,
--                           an unknown recipe's price and how many crafts pay it back
--   T:CraftUnit(item)       copper one costs you to get, and from where ("vendor" | "auction" | nil, "none")
--   T:CraftRank(plans)      plans, the best profit first, the unpriced last
-- Bus: SHY_AUCTION (why, ...): "scan" (count) as a scan ends, "price" (item) as a search sees one, "refused" (the
--      server didn't answer a scan), "shown" / "closed" with the auction house.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Auction",
	category = "items",
	icon = "Interface\\AddOns\\ShyAuction\\Media\\ShyAuction",
	smallIcon = "Interface\\AddOns\\ShyAuction\\Media\\ShyAuctionSmall",
	savedVariables = "ShyAuctionDB",
	defaults = {
		window = true,        -- our window in the game's auction house's place
		page = "buy",         -- the page it opens on (the last one open)
		autoScan = false,     -- scan the whole auction house as it opens, whenever the server allows (else only when you press Scan)
		spacePosts = true,    -- Space posts while the Sell page is up
		tooltip = true,       -- an item's price on its tooltip
		markets = {},         -- [market key] = { at (last whole scan), asked, items = { [item] = { u, q, n, at, p, d = "day:price:seen,..." } } }
		share = {},           -- [market key] = your own prices, packed for the companion app to send in
		trace = {},           -- the auction house's last messages and what we asked of it, for when something goes wrong
	},
	keep = { markets = true, share = true },
})
ns.T = T

-- Something changed that others show: said on the bus.
function ns.Fire(why, ...)
	Shy:Fire("SHY_AUCTION", why, ...)
end

-- The auction house's last messages, and what we asked of it (with whether it was ready), kept with your settings for when
-- something goes wrong.
local TRACE = 400
local function Shown(v)
	if issecretvalue(v) then return "?" end
	if type(v) ~= "table" then return tostring(v) end
	local out = {}
	for k, x in pairs(v) do
		if type(x) ~= "table" and #out < 8 then out[#out + 1] = tostring(k) .. "=" .. (issecretvalue(x) and "?" or tostring(x)) end
	end
	table.sort(out)
	return "{" .. table.concat(out, ",") .. "}"
end
function ns.Note(what, ...)
	local log = T.db and T.db.trace
	if not log then return end
	local parts = { ("%.2f"):format(GetTime()), what, C_AuctionHouse.IsThrottledMessageSystemReady() and "ready" or "busy" }
	for i = 1, select("#", ...) do parts[#parts + 1] = Shown((select(i, ...))) end
	log[#log + 1] = table.concat(parts, " ")
	while #log > TRACE do table.remove(log, 1) end
end
do
	local heard = CreateFrame("Frame")
	for _, event in ipairs({ "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_AUCTIONS_EXPIRED",
		"AUCTION_HOUSE_BROWSE_FAILURE", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
		"AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_DISABLED", "AUCTION_HOUSE_NEW_RESULTS_RECEIVED", "AUCTION_HOUSE_POST_ERROR",
		"AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SCRIPT_DEPRECATED", "AUCTION_HOUSE_SHOW",
		"AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", "AUCTION_HOUSE_SHOW_NOTIFICATION",
		"AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
		"AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED", "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
		"AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "AUCTION_MULTISELL_FAILURE", "AUCTION_MULTISELL_START", "AUCTION_MULTISELL_UPDATE",
		"COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PRICE_UPDATED", "COMMODITY_PURCHASE_FAILED", "COMMODITY_PURCHASE_SUCCEEDED",
		"COMMODITY_SEARCH_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_RECEIVED", "COMMODITY_SEARCH_RESULTS_UPDATED",
		"ITEM_SEARCH_RESULTS_ADDED", "ITEM_SEARCH_RESULTS_UPDATED", "OWNED_AUCTIONS_UPDATED", "ADDON_ACTION_BLOCKED",
		"UI_ERROR_MESSAGE" }) do
		pcall(heard.RegisterEvent, heard, event)
	end
	heard:SetScript("OnEvent", function(_, event, ...) ns.Note(event, ...) end)
end

-- The orders the game's own window asks the auction house for, by what is asked (an empty list: the auction house's own order).
local function Sort(...)
	local out = {}
	for i, order in ipairs({ ... }) do out[i] = { sortOrder = order, reverseSort = false } end
	return out
end
local O = Enum.AuctionHouseSortOrder
ns.SORTS = { browse = Sort(O.Price, O.Name), items = Sort(O.Buyout, O.Bid), commodities = {}, owned = Sort(O.Name, O.Price) }

-- The auction house takes one message at a time. One asked for while it is busy waits, the newest of each kind (key), and goes
-- as soon as the auction house says it is ready, reads ready (looked at four times a second), or after LONGEST at most: the
-- game queues what it can't send yet, and its word that it is ready doesn't always come.
local LONGEST, LOOK = 3, 0.25
local waiting, watching, looking, asked = {}, {}, false, 0
local function Ready() return C_AuctionHouse.IsThrottledMessageSystemReady() end

-- One a pass, the first asked first: once one is sent the auction house is busy again. What only watches for the auction house being
-- ready (a page drawn again) is told all at once and sends nothing.
local function Send(late)
	if Ready() and next(watching) then
		local told = watching
		watching = {}
		for _, fn in pairs(told) do fn() end
	end
	local key, first
	for k, w in pairs(waiting) do
		if not first or w.n < first.n then key, first = k, w end
	end
	if not first or not (late or Ready() or GetTime() - first.at >= LONGEST) then return end
	waiting[key] = nil
	first.fn()
end

local function Look()
	looking = false
	Send()
	if next(waiting) or next(watching) then
		looking = true
		C_Timer.After(LOOK, Look)
	end
end
local function Keep()
	if looking then return end
	looking = true
	C_Timer.After(LOOK, Look)
end

-- fn now if the auction house is ready, else when it is (or after a while anyway).
function ns.WhenReady(key, fn)
	if Ready() and not next(waiting) then
		waiting[key] = nil
		return fn()
	end
	local was = waiting[key]
	asked = asked + 1
	waiting[key] = { fn = fn, at = was and was.at or GetTime(), n = was and was.n or asked }
	Keep()
end

-- fn once the auction house reads ready (it sends nothing itself).
function ns.OnReady(key, fn)
	watching[key] = fn
	Keep()
end

-- What is listed of an item, cheapest first, asked as the game's own window asks it (once the auction house is ready).
function ns.Search(key)
	local info = C_AuctionHouse.GetItemKeyInfo(key)
	local sorts = (info and info.isCommodity) and ns.SORTS.commodities or ns.SORTS.items
	ns.WhenReady("search", function()
		ns.Note("SendSearchQuery", key, info and info.isCommodity)
		C_AuctionHouse.SendSearchQuery(key, sorts, false)
	end)
end

-- Your auctions, asked once the auction house is ready.
function ns.Owned()
	ns.WhenReady("owned", function()
		ns.Note("QueryOwnedAuctions")
		C_AuctionHouse.QueryOwnedAuctions(ns.SORTS.owned)
	end)
end

-- Something asked for no longer wanted (the auction house closed, another item picked).
function ns.Forget(key)
	if key then waiting[key] = nil else wipe(waiting) end
end

function ns.Waiting(key) return waiting[key] ~= nil end

do
	local events = CreateFrame("Frame")
	events:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
	events:RegisterEvent("AUCTION_HOUSE_CLOSED")
	events:SetScript("OnEvent", function(_, event)
		if event == "AUCTION_HOUSE_CLOSED" then
			wipe(watching)
			return ns.Forget()
		end
		Send(true)
	end)
end

-- Public

function T:Price(item)
	return ns.Book.Price(item)
end

function T:Scan()
	return ns.Scan.Full()
end

function T:Cut() return ns.Book.Cut() end

function T:Show(page)
	if not (ns.Scan.IsOpen() and ns.Window.IsUp()) then return false end
	ns.Window.Open(page)
	return true
end

function T:Find(item)
	if type(item) ~= "number" or not self:Show("buy") then return false end
	ns.BuyPage.Pick(item)
	return true
end

function T:Scanning()
	return ns.Scan.State()
end

function T:Market()
	return ns.Book.Key(), ns.Book.ScannedAt()
end

function T:CraftPlan(r) return ns.Craft.Plan(r) end
function T:CraftUnit(item) return ns.Craft.Unit(item) end
function T:CraftRank(plans) return ns.Craft.Rank(plans) end

function T:OnLogin()
	ns.Book.Start()
	ns.Scan.Start()
	ns.Window.Start()
	ns.Tooltip.Init()
end

T:Command("scan", "scan the whole auction house (it has to be open)", function()
	local ok, why = ns.Scan.Full()
	if not ok then T:Print(why) end
end)

T:Command("price", "what an item sells for here: shift-click it or give its ID", function(rest)
	local item = tonumber(rest:match("item:(%d+)") or rest:match("^#?(%d+)$") or "")
	local price = item and ns.Book.Price(item)
	if not item then
		T:Print("which item? Shift-click it, or give its ID.")
	elseif not price then
		T:Print("no price for it on this market yet.")
	else
		T:Print(("%s each, from %s. %d listed, seen %s."):format(ns.Book.Text(price.market), ns.Book.Basis(price), price.quantity, ns.Book.Age(price.at)))
	end
end)
