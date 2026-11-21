-- The price book, by market. Each sighting of an item (a whole scan, or a search) gives its lowest buyout each, how
-- many are listed, in how many listings, and its going price: the price at which the cheapest K.GOING of what is
-- listed is gone, so one cheap or bait listing doesn't make it. Each day's price is the middle of that day's going
-- prices (entry.d, the last K.DAYS days), and the market is those days together: the recent ones count most (a day
-- K.HALF days old counts half), a day with more sightings more, and with three days or more, a day far off the rest
-- (K.FAR) is left out. So a scan the same day steadies today's price, and a scan on another day steadies the market.
-- Forever has no realms: one auction house serves a region, a ruleset and a side (Alliance, Horde, or a goblin house's
-- Neutral), so that is the key ("US-PvP-Alliance"); the realm's name is only a shard's, and only its ruleset counts.
-- Your own sightings are kept (T.db.markets) and packed as you log out for the companion app to send in (T.db.share).
-- Other players' come in Data/Shared.lua (ns.shared[key] = { at, items = "item:unit:quantity:listings:at:market,..." }),
-- read the first time a price is asked: newer than yours, their listing stands for now, and their market counts as one
-- more sighting on its day.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local B = {}
ns.Book = B

local K = {
	GOING = 0.15,        -- share of what is listed, cheapest first, whose last price is a sighting's going price
	DAYS = 14,           -- days of going prices kept an item
	SIGHTINGS = 9,       -- the newest day's last sightings kept, whose middle is its price
	HALF = 3,            -- days: a day this old counts half as much as today
	FAR = 2,             -- a day's price this many times over or under the middle of the days is left out (3 days on)
	DAY = 86400,         -- seconds in a day
	FORGET = 60 * 86400, -- seconds: your own sightings older than this are let go at login
	SEND = 14 * 86400,   -- ... and only those newer than this are packed to send in
	PACKED = "2",        -- the packing's version, first in what is sent
}
B.K = K

local side                   -- the side of the auction house open now (nil: your own faction's)
local shared, sharedKey      -- other players' prices on that market: [item] = { u, q, n, at, m }
local views, stamp = {}, 0   -- T:Price's answers, kept until anything changes (stamp)

-- Your ruleset (Shy.Ruleset): Hardcore by the game's rules, else as your shard's name says it ("... Realm 4 PvP").
function B.Ruleset()
	return Shy.Ruleset() or "Normal"
end

-- The market you trade in now: region, ruleset and the side of the auction house open (your faction's while none is).
function B.Key()
	local region = GetCurrentRegionName()
	local s = side or UnitFactionGroup("player")
	if not region or region == "" or not s then return nil end
	return region .. "-" .. B.Ruleset() .. "-" .. s
end

-- The share of a sale the auction house keeps on this market: a goblin's house 15%, a faction's 5%.
function B.Cut()
	local key = B.Key() or ""
	return key:match("%-Neutral$") and 0.15 or 0.05
end

-- The auction house opened is this auctioneer's side: a faction's, or a goblin's (Neutral). nil: none open.
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

local function Today(at) return math.floor((at or time()) / K.DAY) end

-- A sighting's going price, from its listings (each a B.Listing, sorted here, cheapest first): the price at
-- which the cheapest K.GOING of what is listed is gone. nil: no listings.
-- A listing as one number, its price and how many packed together (B.Listing): a whole scan reads tens of thousands,
-- and a table each was most of its memory. Packed so, they sort by price as they are.
B.PACK = 1048576   -- 2^20: the most a listing may hold, kept under it
function B.Listing(unit, count)
	return unit * B.PACK + math.min(count, B.PACK - 1)
end
function B.Going(listings)
	local n, pack = #listings, B.PACK
	if n == 0 then return nil end
	table.sort(listings)
	local total = 0
	for i = 1, n do total = total + listings[i] % pack end
	local reach, gone = math.max(1, total * K.GOING), 0
	for i = 1, n do
		gone = gone + listings[i] % pack
		if gone >= reach then return math.floor(listings[i] / pack) end
	end
	return math.floor(listings[n] / pack)
end

-- An item's days, oldest first, only the last K.DAYS: four lists (the day, its price, how many sightings it had, the
-- sightings kept). Written "day:sightings:price,...": the newest day keeps its last few sightings ("p/p/p") and its
-- price is their middle; an older day keeps only that middle.
local function Days(d, today)
	local days, prices, counts, kept = {}, {}, {}, {}
	for written, count, list in (d or ""):gmatch("(%d+):(%d+):([%d/]+)") do
		local day = tonumber(written)
		if day > today - K.DAYS then
			local seen = {}
			for p in list:gmatch("%d+") do seen[#seen + 1] = tonumber(p) end
			local i = #days + 1
			days[i], prices[i], counts[i], kept[i] = day, Middle(seen), tonumber(count), seen
		end
	end
	return days, prices, counts, kept
end

-- One more sighting at `price` on `day`: among that day's, or a day of its own in its place.
local function Add(days, prices, counts, kept, day, price)
	for i = #days, 1, -1 do
		if days[i] == day then
			local seen = kept[i]
			seen[#seen + 1] = price
			while #seen > K.SIGHTINGS do table.remove(seen, 1) end
			prices[i], counts[i] = Middle(seen), counts[i] + 1
			return
		elseif days[i] < day then
			table.insert(days, i + 1, day)
			table.insert(prices, i + 1, price)
			table.insert(counts, i + 1, 1)
			table.insert(kept, i + 1, { price })
			return
		end
	end
	table.insert(days, 1, day)
	table.insert(prices, 1, price)
	table.insert(counts, 1, 1)
	table.insert(kept, 1, { price })
end

-- (Written with %.0f: copper past what %d holds stays whole.)
local function Join(days, prices, counts, kept)
	local parts, n = {}, #days
	for i = 1, n do
		local list
		if i == n then
			local s = {}
			for j, p in ipairs(kept[i]) do s[j] = ("%.0f"):format(p) end
			list = table.concat(s, "/")
		else
			list = ("%.0f"):format(prices[i])
		end
		parts[i] = ("%.0f:%.0f:%s"):format(days[i], counts[i], list)
	end
	return table.concat(parts, ",")
end

-- The days with one more sighting, written as Days, Add and Join would write them, by changing only their end: a
-- sighting on the newest day joins it, one on a later day closes it to its middle and opens its own, and days that
-- fell out of the window go from the front. nil: anything else (an earlier day, writing not of this shape), for the
-- whole way. (A scan notes every item: read and written whole, a book of thousands holds the game a moment.)
local function Appended(d, today, price)
	if not d then return nil end
	-- The newest day (after the last comma) and the days before it (from `from` to the comma, kept as written).
	local cut = d:find(",[^,]*$")
	local written, count, list = d:match("^(%d+):(%d+):([%d/]+)$", cut and cut + 1 or 1)
	local day = tonumber(written)
	if not day or day > today or day <= today - K.DAYS then return nil end
	-- Written as Join writes: the days before the newest one price each (nothing but digits, colons and commas in
	-- them), and no number led by a nought.
	local odd = d:find("[^%d:,]")
	if (cut and odd and odd < cut) or d:find("%f[%d]0%d") then return nil end
	-- Days out of the window, oldest first.
	local from = 1
	while cut and from < cut do
		local first = tonumber(d:match("^(%d+):%d+:%d+,", from))
		if not first then return nil end
		if first > today - K.DAYS then break end
		from = d:find(",", from, true) + 1
	end
	local head = (cut and from < cut) and d:sub(from, cut - 1) or ""
	local seen = {}
	for p in list:gmatch("%d+") do seen[#seen + 1] = tonumber(p) end
	local tail
	if day == today then
		seen[#seen + 1] = price
		while #seen > K.SIGHTINGS do table.remove(seen, 1) end
		for j, p in ipairs(seen) do seen[j] = ("%.0f"):format(p) end
		tail = ("%.0f:%.0f:%s"):format(day, tonumber(count) + 1, table.concat(seen, "/"))
	else
		tail = ("%.0f:%.0f:%s,%.0f:%.0f:%s"):format(day, tonumber(count), ("%.0f"):format(Middle(seen)), today, 1,
			("%.0f"):format(price))
	end
	return head ~= "" and (head .. "," .. tail) or tail
end

-- Days' days, prices and sightings, without the sightings kept: an older day's one price is its middle as it is.
local function Prices(d, today)
	local days, prices, counts, n = {}, {}, {}, 0
	for written, count, list in (d or ""):gmatch("(%d+):(%d+):([%d/]+)") do
		local day = tonumber(written)
		if day > today - K.DAYS then
			local price
			if list:find("/", 1, true) then
				local seen = {}
				for p in list:gmatch("%d+") do seen[#seen + 1] = tonumber(p) end
				price = Middle(seen)
			else
				price = tonumber(list)
			end
			n = n + 1
			days[n], prices[n], counts[n] = day, price, tonumber(count)
		end
	end
	return days, prices, counts
end

-- The market from the days: recent days and days seen more often count most; a day far off the rest is left out.
local function Worth(days, prices, counts, today)
	local n = #days
	if n == 0 then return nil end
	local low, high = 0, math.huge
	if n >= 3 then
		local middle = Middle(prices)
		low, high = middle / K.FAR, middle * K.FAR
	end
	local sum, weight = 0, 0
	for i = 1, n do
		local p = prices[i]
		if p >= low and p <= high then
			local w = 0.5 ^ (math.max(0, today - days[i]) / K.HALF) * (1 - 0.5 ^ counts[i])
			sum, weight = sum + p * w, weight + w
		end
	end
	return math.floor(sum / weight + 0.5)
end

-- One sighting of an item: its lowest unit price (nil: nobody lists one), how many, in how many listings, its going
-- price (the lowest unless told), when.
local function Note(items, item, unit, quantity, listings, going, at)
	local entry = items[item]
	if not entry then
		entry = {}
		items[item] = entry
	end
	entry.q, entry.n = quantity or 0, listings or 0
	if unit then
		going = going or unit
		entry.u, entry.p = unit, going
		local today = Today(at)
		local d = Appended(entry.d, today, going)
		if not d then
			local days, prices, counts, kept = Days(entry.d, today)
			Add(days, prices, counts, kept, today, going)
			d = Join(days, prices, counts, kept)
		end
		entry.d = d
	end
	entry.at = at
end

function B.Seen(item, unit, quantity, listings, going)
	local market = Market(true)
	if not market then return end
	Note(market.items, item, unit, quantity, listings, going, time())
	Changed()
	ns.Fire("price", item)
end

-- When the whole auction house was last scanned on your market, by you or anyone whose prices came.
function B.ScannedAt()
	local market = Market()
	local own = market and market.at
	local block = B.Key() and ns.shared and ns.shared[B.Key()]
	local theirs = block and block.at
	if own and theirs then return math.max(own, theirs) end
	return own or theirs
end

-- An entry's market and how many of your own days it is from, worked out again only when its days, the day or the
-- other player's sighting folded in change (prices change a search at a time; the rest stand).
local worked = setmetatable({}, { __mode = "k" })
local function Worked(own, newer, today)
	local w = worked[own]
	local at = newer and newer.at or 0
	if w and w.d == own.d and w.today == today and w.at == at then return w.market, w.days end
	-- (After a scan every item is read again here, for the deals: the sightings kept only when another's is added.)
	local days, prices, counts, kept
	if newer and newer.m then
		days, prices, counts, kept = Days(own.d, today)
	else
		days, prices, counts = Prices(own.d, today)
	end
	local mine = #days
	if newer and newer.m then Add(days, prices, counts, kept, Today(newer.at), newer.m) end
	local market = Worth(days, prices, counts, today) or own.p or own.u
	worked[own] = { d = own.d, today = today, at = at, market = market, days = mine }
	return market, mine
end

-- A whole scan: results[item] = { u, q, n, p (going) }. Whatever the book had that the scan didn't find is listed by
-- nobody now. Noted a few hundred items a frame (Scan.lua): B.Scanning(results, at) begins it on the market open now
-- (nil: none), and B.Noting(job, started, budget) notes on until `budget` ms past `started` (none: to the end),
-- giving the count of items once every one is in. Each item's market is worked out as it is noted, so the deals,
-- which read every item after a scan, find them ready.
function B.Scanning(results, at)
	local market = Market(true)
	if not market then return nil end
	return { results = results, at = at or time(), market = market, count = 0 }
end

function B.Noting(job, started, budget)
	local items, at, today = job.market.items, job.at, Today(job.at)
	local item, r = next(job.results, job.last)
	while item do
		Note(items, item, r.u, r.q, r.n, r.p, at)
		local entry = items[item]
		if entry.u then Worked(entry, nil, today) end
		job.count, job.last = job.count + 1, item
		if budget and debugprofilestop() - started > budget then return nil end
		item, r = next(job.results, item)
	end
	for each, entry in pairs(items) do
		if not job.results[each] then entry.q, entry.n, entry.at = 0, 0, at end
	end
	job.market.at = at
	Changed()
	return job.count
end

-- A whole scan into the book at once.
function B.Scanned(results, at)
	local job = B.Scanning(results, at)
	return job and B.Noting(job) or 0
end

function B.Price(item)
	local key = B.Key()
	local view = views[item]
	if view and view.stamp == stamp and view.key == key then return view.price end
	local market = Market()
	local own = market and market.items[item]
	local their = Shared()[item]
	local price
	if own and own.u then
		-- Theirs newer: their listing for now, their market one more sighting on its day.
		local newer = their and their.at > (own.at or 0) and their or nil
		local worth, days = Worked(own, newer, Today())
		local now = newer or own
		price = { unit = now.u, quantity = now.q or 0, listings = now.n or 0, at = now.at, market = worth,
			going = own.p or own.u, days = days, shared = newer ~= nil }
	elseif their then
		price = { unit = their.u, quantity = their.q, listings = their.n, at = their.at, market = their.m, days = 0, shared = true }
	end
	views[item] = { stamp = stamp, key = key, price = price }
	return price
end

-- What a price is from, in a few words: "6 days of scans", "one day of scans", "other players' scans".
function B.Basis(price)
	if not price then return nil end
	local days = price.days or 0
	if days == 0 then return "other players' scans" end
	if days == 1 then return "one day of scans" end
	return ("%d days of scans"):format(days)
end

-- An item's going price day by day on your market (each day's middle), oldest first, or nil.
function B.History(item)
	local market = Market()
	local entry = market and market.items[item]
	if not (entry and entry.d) then return nil end
	local _, prices = Days(entry.d, Today())
	return #prices > 0 and prices or nil
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

-- Your own prices to send in: "2|item:unit:quantity:listings:at:going,..." (only numbers), newest of each.
function B.Pack(k)
	local market = T.db.markets[k]
	if not market then return nil end
	local since, parts = time() - K.SEND, {}
	for item, entry in pairs(market.items) do
		if entry.u and entry.at and entry.at >= since then
			parts[#parts + 1] = ("%d:%.0f:%d:%d:%d:%.0f"):format(item, entry.u, entry.q or 0, entry.n or 0, entry.at, entry.p or entry.u)
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

-- At login: what is old is let go, and a book from before days were kept takes its last few prices' middle as the
-- day it was last seen. As you log out: your prices packed for the companion app.
function B.Start()
	local since = time() - K.FORGET
	for _, market in pairs(T.db.markets) do
		for item, entry in pairs(market.items or {}) do
			if not entry.at or entry.at < since then
				market.items[item] = nil
			elseif entry.h then
				local middle = Middle(entry.h)
				if middle and not entry.d then entry.d = Join({ Today(entry.at) }, { middle }, { #entry.h }, { entry.h }) end
				entry.p, entry.h = entry.p or entry.u, nil
			end
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
