-- Reading the auction house. A whole scan asks the server for every listing at once (ReplicateItems) and reads them a
-- few hundred a frame into each item's lowest buyout each, how many, in how many listings and its going price (the
-- price book says what that is); the server allows one
-- now and then (K.EVERY), and one it doesn't answer is given up (K.WAIT). Every search made there (ours or the game's)
-- is noted too. Only while the auction house is open.

local ADDON, ns = ...
local T = ns.T

local S = {}
ns.Scan = S

local K = {
	EVERY = 15 * 60,     -- seconds between two whole scans the server allows
	WAIT = 60,           -- seconds a whole scan may take to begin answering before it is given up
	STILL = 1,           -- seconds the count of listings must hold still before they are read
	BUDGET = 4,          -- ms a frame the reading takes
	LOOK = 50,           -- a search's results looked through for its lowest price
	SOON = 1.5,          -- seconds after the auction house opens before a scan of it begins by itself
}
S.K = K

-- Whether this client has the scan of the whole auction house: documented, but no game code here calls it, and a documented call
-- has been missing before. Without it, prices come from searches and other players' scans.
S.CAN = C_AuctionHouse.ReplicateItems ~= nil and C_AuctionHouse.GetNumReplicateItems ~= nil and C_AuctionHouse.GetReplicateItemInfo ~= nil

local open = false
local scan                   -- { state = "asked" | "reading", at, count, still, i, n, results }
local driver = CreateFrame("Frame")
driver:Hide()

function S.IsOpen() return open end

-- How a scan stands: { state ("asked" | "reading"), done, of (listings), found (items so far), cheaper (of them, under
-- the price the book had), left (seconds, once reading) }, or nil.
local view = {}
function S.State()
	if not scan then return nil end
	view.state, view.done, view.of, view.found, view.cheaper = scan.state, scan.i or 0, scan.n or 0, scan.found or 0, scan.cheaper or 0
	view.left = nil
	if scan.state == "reading" and scan.i and scan.i > 0 then
		view.left = (GetTime() - scan.began) / scan.i * (scan.n - scan.i)
	end
	return view
end

-- What the last whole scan found: { count (items priced), new (to the book), deals (under the market), at }, or nil.
function S.Last() return S.last end

-- Seconds until the server allows the next whole scan (0: now).
function S.Wait()
	local market = ns.Book.Market()
	local last = math.max(market and market.asked or 0, market and market.at or 0)
	return math.max(0, last + K.EVERY - time())
end

function S.Full()
	if not S.CAN then return false, "this game can't scan the whole auction house. Prices come from your searches." end
	if not open then return false, "open the auction house first." end
	if scan then return false, "a scan is already under way." end
	local wait = S.Wait()
	if wait > 0 then return false, ("the server allows the next scan in %d min."):format(math.ceil(wait / 60)) end
	local market = ns.Book.Market(true)
	if not market then return false, "the game hasn't said which market this is yet." end
	scan = { state = "asked", at = GetTime(), count = -1, still = GetTime(), was = market.asked }
	market.asked = time()
	S.refused = nil
	ns.Note("ReplicateItems")
	C_AuctionHouse.ReplicateItems()
	driver:Show()
	ns.Fire("scanning")
	return true
end

local function Stop(why)
	scan = nil
	driver:Hide()
	if why then ns.Fire(why) end
end

-- Stops a scan under way (what it read so far is let go; once all of it is read, it goes into the book first).
local Noted
function S.Stop()
	if not scan then return end
	if scan.noting ~= nil then Noted() else Stop("stopped") end
end

-- One listing into the results: its item, its buyout over how many it is (a whole scan's buyout is the listing's whole;
-- no buyout: a bid only, left out), kept with the item's other listings for its going price.
local function Read(results, index)
	-- (Counted as each item is first met: how many so far, and how many under what the book had.)
	local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, item = C_AuctionHouse.GetReplicateItemInfo(index)
	if not item or not buyout or not count then return end
	if issecretvalue(item) or issecretvalue(buyout) or issecretvalue(count) then return end
	if buyout <= 0 or count <= 0 then return end
	local unit = math.floor(buyout / count + 0.5)
	local r = results[item]
	if not r then
		results[item] = { u = unit, q = count, n = 1, l = { ns.Book.Listing(unit, count) } }
		scan.found = (scan.found or 0) + 1
		local was = ns.Book.Price(item)
		if not was then scan.fresh = (scan.fresh or 0) + 1
		elseif unit < was.market then scan.cheaper = (scan.cheaper or 0) + 1 end
	else
		if unit < r.u then r.u = unit end
		r.q, r.n = r.q + count, r.n + 1
		r.l[r.n] = ns.Book.Listing(unit, count)
	end
end

-- Each item's going price from its listings, a few hundred items a frame: true once every one has its own.
local function Priced(started)
	local results = scan.results
	local item, r = next(results, scan.priced)
	while item do
		r.p, r.l = ns.Book.Going(r.l), nil
		scan.priced = item
		if debugprofilestop() - started > K.BUDGET then return false end
		item, r = next(results, item)
	end
	return true
end

local function Done(count)
	local fresh, cheaper = scan.fresh or 0, scan.cheaper or 0
	S.last = { count = count, new = fresh, deals = cheaper, at = time() }
	Stop()
	ns.Fire("scan", count)
	if Shy.Notices and Shy.Notices.Post then
		Shy.Notices.Post("shyauction-scan", {
			order = 40, glyph = "coin", color = Shy.UI.colors.good, text = tostring(count),
			title = "Auction house scanned", says = ("Prices for %d items on this market."):format(count), hold = 8,
		})
	end
end

-- Read and priced: into the price book a few hundred items a frame (Book.lua's B.Noting); with no budget, all that is
-- left at once. Begun, it is always finished, even as the auction house closes or the scan is stopped: all of it was read,
-- and the book never holds half a scan. True once it is in.
function Noted(started, budget)
	if scan.noting == nil then scan.noting = ns.Book.Scanning(scan.results, time()) or false end
	local count = 0
	if scan.noting then
		count = ns.Book.Noting(scan.noting, started, budget)
		if not count then return false end
	end
	Done(count)
	return true
end

-- (The listings come in as the server sends them: read once their count has held still a moment.)
driver:SetScript("OnUpdate", Shy.Clocked("auction: scan", function()
	if not scan then
		driver:Hide()
		return
	end
	if not open then
		if scan.noting ~= nil then Noted() else Stop("closed") end
		return
	end
	local now = GetTime()
	if scan.state == "asked" then
		local n = C_AuctionHouse.GetNumReplicateItems() or 0
		if n ~= scan.count then scan.count, scan.still = n, now end
		if n > 0 and now - scan.still >= K.STILL then
			scan.state, scan.i, scan.n, scan.results, scan.began = "reading", 0, n, {}, now
		elseif n == 0 and now - scan.at > K.WAIT then
			-- (Unanswered: it doesn't count against the server's interval, and the bar says so for a while.)
			local market = ns.Book.Market()
			if market then market.asked = scan.was end
			S.refused = time()
			return Stop("refused")
		end
		return
	end
	local started = debugprofilestop()
	while scan.i < scan.n do
		Read(scan.results, scan.i)
		scan.i = scan.i + 1
		if scan.i % 50 == 0 and debugprofilestop() - started > K.BUDGET then return end
	end
	if scan.noting == nil and not Priced(started) then return end
	Noted(started, K.BUDGET)
end))

-- A search's results: the lowest each, how many, in how many listings, and their going price (commodities by the
-- unit, items by their buyout, which is the price each however many a listing holds).
local function Searched(item, key)
	local least, quantity, listings, all = nil, 0, 0, {}
	local function Take(unit, n)
		if not unit or issecretvalue(unit) or unit <= 0 then return end
		n = n or 1
		if not least or unit < least then least = unit end
		quantity, listings = quantity + n, listings + 1
		all[listings] = ns.Book.Listing(unit, n)
	end
	if key then
		local n = C_AuctionHouse.GetNumItemSearchResults(key) or 0
		for i = 1, math.min(n, K.LOOK) do
			local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
			if r and r.buyoutAmount and r.quantity and not issecretvalue(r.quantity) and r.quantity > 0 then
				Take(r.buyoutAmount, r.quantity)
			end
		end
	else
		local n = C_AuctionHouse.GetNumCommoditySearchResults(item) or 0
		for i = 1, math.min(n, K.LOOK) do
			local r = C_AuctionHouse.GetCommoditySearchResultInfo(item, i)
			if r and not issecretvalue(r.quantity) then Take(r.unitPrice, r.quantity) end
		end
	end
	ns.Book.Seen(item, least, quantity, listings, ns.Book.Going(all))
end

local handlers = {
	AUCTION_HOUSE_SHOW = function()
		open = true
		ns.Book.House(true, UnitFactionGroup("npc"))
		ns.Fire("shown")
		if T.db.autoScan and S.CAN and S.Wait() == 0 then
			C_Timer.After(K.SOON, function()
				if open and not scan and S.Wait() == 0 then S.Full() end
			end)
		end
	end,
	AUCTION_HOUSE_CLOSED = function()
		open = false
		ns.Book.House(false)
		if scan then
			if scan.noting ~= nil then Noted() else Stop() end
		end
		ns.Fire("closed")
	end,
	COMMODITY_SEARCH_RESULTS_UPDATED = function(item)
		if item and not issecretvalue(item) then Searched(item) end
	end,
	ITEM_SEARCH_RESULTS_UPDATED = function(key)
		local item = type(key) == "table" and key.itemID
		if item and not issecretvalue(item) then Searched(item, key) end
	end,
}

-- The game's word that the listings are in: they are read once their count holds still.
handlers.REPLICATE_ITEM_LIST_UPDATE = function()
	if scan and scan.state == "asked" then scan.heard = true end
end

function S.Start()
	local events = CreateFrame("Frame")
	for event in pairs(handlers) do
		-- (No game code here registers the scan's own event: one refused is gone without, as the count is watched too.)
		if event == "REPLICATE_ITEM_LIST_UPDATE" then pcall(events.RegisterEvent, events, event) else events:RegisterEvent(event) end
	end
	events:SetScript("OnEvent", Shy.Clocked("auction: events", function(_, event, ...)
		local ok, err = pcall(handlers[event], ...)
		if not ok then geterrorhandler()(err) end
	end))
end
