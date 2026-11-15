-- The price book, by market: each item's lowest buyout each, how many are listed, in how many listings, when, and the
-- last few lowest prices, whose middle (market) is what to go by: one cheap listing doesn't make the price. Forever has
-- no realms: one auction house serves a region, a ruleset and a side (Alliance, Horde, or a goblin house's Neutral), so
-- that is the key ("US-PvP-Alliance"); the realm's name is only a shard's, and only its ruleset counts. Your own
-- sightings are kept (T.db.markets) and packed as you log out for the companion app to send in (T.db.share). Other players'
-- come in Data/Shared.lua (ns.shared[key] = { at, items = "item:unit:quantity:listings:at:market,..." }), read the
-- first time a price is asked. Item by item, the newer sighting wins.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local B = {}
ns.Book = B

local K = {
	KEEP = 5,            -- prices whose middle is the market
	APART = 1800,        -- seconds: a sighting this soon after the last one takes its place among them
	FORGET = 60 * 86400, -- seconds: your own sightings older than this are let go at login
	SEND = 14 * 86400,   -- ... and only those newer than this are packed to send in
	PACKED = "1",        -- the packing's version, first in what is sent
}
B.K = K

local side                   -- the side of the auction house open now (nil: your own faction's)
local shared, sharedKey      -- other players' prices on that market: [item] = { u, q, n, at, m }
local views, stamp = {}, 0   -- T:Price's answers, kept until anything changes (stamp)

-- Your ruleset: Hardcore by the game's rules, else as your shard's name says it ("... Realm 4 PvP").
function B.Ruleset()
	if C_GameRules.IsHardcoreActive() then return "Hardcore" end
	local realm = (GetRealmName() or ""):lower()
	if realm:find("pvp", 1, true) then return "PvP" end
	if realm:find("%f[%a]rp%f[%A]") then return "RP" end
	return "Normal"
end

-- The market you trade in now: region, ruleset and the side of the house open (your faction's while none is).
function B.Key()
	local region = GetCurrentRegionName()
	local s = side or UnitFactionGroup("player")
	if not region or region == "" or not s then return nil end
	return region .. "-" .. B.Ruleset() .. "-" .. s
end

-- The share of a sale the house keeps on this market: a goblin's house 15%, a faction's 5%.
function B.Cut()
	local key = B.Key() or ""
	return key:match("%-Neutral$") and 0.15 or 0.05
end

-- The house opened is this auctioneer's side: a faction's, or a goblin's (Neutral). nil: none open.
function B.House(open, faction)
	if not open then side = nil
	elseif faction == "Alliance" or faction == "Horde" then side = faction
	else side = "Neutral" end
end

-- Your market's own record ({ at, asked, items }); made when asked to.
local function Market(make)
	local k = B.Key()
	if not k then return nil end
	local market = T.db.markets[k]
	if not market and make then
		market = { items = {} }
		T.db.markets[k] = market
	end
	return market
end
B.Market = Market

-- Other players' prices on your market, read once.
local function Shared()
	local k = B.Key()
	if sharedKey == k and shared then return shared end
	shared, sharedKey = {}, k
	local block = k and ns.shared and ns.shared[k]
	for item, u, q, n, at, m in ((block and block.items) or ""):gmatch("(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)") do
		shared[tonumber(item)] = { u = tonumber(u), q = tonumber(q), n = tonumber(n), at = tonumber(at), m = tonumber(m) }
	end
	return shared
end

local function Middle(list)
	local sorted = {}
	for i, v in ipairs(list) do sorted[i] = v end
	table.sort(sorted)
	local n = #sorted
	if n == 0 then return nil end
	if n % 2 == 1 then return sorted[(n + 1) / 2] end
	return math.floor((sorted[n / 2] + sorted[n / 2 + 1]) / 2 + 0.5)
end

local function Changed()
	stamp = stamp + 1
end

-- How many times prices have changed: what others keep is good while this holds still.
function B.Stamp() return stamp end

-- One sighting of an item: its lowest unit price (nil: nobody lists one), how many, in how many listings, when.
local function Note(items, item, unit, quantity, listings, at)
	local entry = items[item]
	if not entry then
		entry = { h = {} }
		items[item] = entry
	end
	entry.q, entry.n = quantity or 0, listings or 0
	if unit then
		entry.u = unit
		local h = entry.h
		if #h > 0 and entry.at and at - entry.at < K.APART then
			h[#h] = unit
		else
			h[#h + 1] = unit
			while #h > K.KEEP do table.remove(h, 1) end
		end
	end
	entry.at = at
end

function B.Seen(item, unit, quantity, listings)
	local market = Market(true)
	if not market then return end
	Note(market.items, item, unit, quantity, listings, time())
	Changed()
	ns.Fire("price", item)
end

-- A whole scan: results[item] = { u, q, n }. Whatever the book had that the scan didn't find is listed by nobody now.
function B.Scanned(results, at)
	local market = Market(true)
	if not market then return 0 end
	at = at or time()
	local count = 0
	for item, r in pairs(results) do
		Note(market.items, item, r.u, r.q, r.n, at)
		count = count + 1
	end
	for item, entry in pairs(market.items) do
		if not results[item] then entry.q, entry.n, entry.at = 0, 0, at end
	end
	market.at = at
	Changed()
	return count
end

-- When the whole house was last scanned on your market, by you or anyone whose prices came.
function B.ScannedAt()
	local market = Market()
	local own = market and market.at
	local block = B.Key() and ns.shared and ns.shared[B.Key()]
	local theirs = block and block.at
	if own and theirs then return math.max(own, theirs) end
	return own or theirs
end

function B.Price(item)
	local key = B.Key()
	local view = views[item]
	if view and view.stamp == stamp and view.key == key then return view.price end
	local market = Market()
	local own = market and market.items[item]
	local their = Shared()[item]
	local price
	if own and own.u and not (their and their.at > (own.at or 0)) then
		price = { unit = own.u, quantity = own.q or 0, listings = own.n or 0, at = own.at, market = Middle(own.h) or own.u, shared = false }
	elseif their then
		price = { unit = their.u, quantity = their.q, listings = their.n, at = their.at, market = their.m, shared = true }
	end
	views[item] = { stamp = stamp, key = key, price = price }
	return price
end

-- Your last few lowest prices for an item on your market, oldest first (the market is their middle), or nil.
function B.History(item)
	local market = Market()
	local entry = market and market.items[item]
	return entry and entry.h and #entry.h > 0 and entry.h or nil
end

-- What is listed under its market now on your market, the best first: { { item, unit, market, quantity, off } }
-- (off: the share under the market), at most `most`, none less than `least` under (0.1 unless told).
local dealsKept = {}
function B.Deals(most, least)
	least = least or 0.1
	local k = B.Key()
	if dealsKept.stamp == stamp and dealsKept.key == k and dealsKept.most == most and dealsKept.least == least then return dealsKept.list end
	local out = {}
	local market = Market()
	for item, entry in pairs(market and market.items or {}) do
		local price = entry.u and (entry.q or 0) > 0 and B.Price(item)
		if price and not price.shared and price.market > 0 then
			local off = 1 - price.unit / price.market
			if off >= least then
				out[#out + 1] = { item = item, unit = price.unit, market = price.market, quantity = price.quantity, off = off }
			end
		end
	end
	table.sort(out, function(a, b)
		if a.off ~= b.off then return a.off > b.off end
		return a.item < b.item
	end)
	for i = #out, (most or 50) + 1, -1 do out[i] = nil end
	dealsKept = { stamp = stamp, key = k, most = most, least = least, list = out }
	return out
end

-- How many items the book has a price for on your market.
local counted = {}
function B.Count()
	local k = B.Key()
	if counted.stamp == stamp and counted.key == k then return counted.n end
	local seen = {}
	local market = Market()
	for item, entry in pairs(market and market.items or {}) do
		if entry.u then seen[item] = true end
	end
	for item in pairs(Shared()) do seen[item] = true end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	counted = { stamp = stamp, key = k, n = n }
	return n
end

-- Your own prices to send in: "1|item:unit:quantity:listings:at,..." (only numbers), newest of each.
function B.Pack(k)
	local market = T.db.markets[k]
	if not market then return nil end
	local since, parts = time() - K.SEND, {}
	for item, entry in pairs(market.items) do
		if entry.u and entry.at and entry.at >= since then
			parts[#parts + 1] = ("%d:%d:%d:%d:%d"):format(item, entry.u, entry.q or 0, entry.n or 0, entry.at)
		end
	end
	if #parts == 0 then return nil end
	table.sort(parts)
	return K.PACKED .. "|" .. table.concat(parts, ",")
end

function B.Text(copper)
	copper = math.floor((copper or 0) + 0.5)
	if copper >= COPPER_PER_GOLD then copper = copper - copper % COPPER_PER_SILVER end
	return UI.Money(copper, true)
end

B.Age = UI.Ago

-- At login: what is old is let go. As you log out: your prices packed for the companion app.
function B.Start()
	local since = time() - K.FORGET
	for _, market in pairs(T.db.markets) do
		for item, entry in pairs(market.items or {}) do
			if not entry.at or entry.at < since then market.items[item] = nil end
		end
	end
	Changed()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
	wipe(T.db.share)
	for k in pairs(T.db.markets) do T.db.share[k] = B.Pack(k) end
end)
