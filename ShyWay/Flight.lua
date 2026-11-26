-- Shy.Way.Flight: the flight the character is on, for every addon, and what the maps show of it.
--
-- In the air the minimap and the world map show the flight's own line, from the character to where it
-- lands, in the travel color, and a mark where it lands (on the minimap, waiting at the rim while that
-- is out of range) with the time left under it. The mark's hover says where the flight goes and how long
-- it has to go. The line is the one the game flies: the points each path of the flight passes through
-- (Data\Flights.lua), hop after hop, as a smooth curve.
--
-- Each flight is timed take-off to landing and kept per account by its node chain (ShyWayDB.air.times:
-- "2>4>6" -> seconds). An untimed one is estimated from its paths' yards at AIR_SPEED, scaled by how
-- flights timed so far compare with their estimates; with no path data it counts up. An early landing
-- or a flight spanning a reload is not kept.
--
-- The account's Frequent Flier perk flies a fifth faster. Times are kept as a flight without it takes
-- (one flown with it is kept 1.2 times as long) and every time given out is for the character asking,
-- so characters with and without it each see their own. Times kept before this was known are taken to
-- be without it.
--
--   Shy.Way.Flight.Now() -> flight or nil      { to = name, key = "2>4>6", seconds = estimate or nil, sure = timed
--                                           before, started = GetTime(), early = landing early }
--   Shy.Way.Flight.Left() -> label, left, share, said   the countdown: "Flying to X", seconds left (or so far),
--                                           share of the flight left, and the time in words ("about 1:23");
--                                           nil when not in the air
--   Shy.Way.Flight.Line(continent, north, west) -> line, first, last   the line ({ continent, north = {}, west = {},
--                                           n }), the first of its points still ahead of the player at
--                                           (north, west), and its last; nil when unknown
--   Shy.Way.Flight.Landing() -> continent, north, west   where the flight lands; nil when unknown
--   Shy.Way.Flight.Seconds(from, to, known, stamp) -> seconds, timed   between two flight points by node, for a
--                                           flight not yet on the flight map: the quickest time kept, else the
--                                           shortest way over the paths through the nodes in `known` (node ->
--                                           true; `stamp` changes when it does); nil with no way
--   Shy.Way.Flight.Route(from, to, known) -> hops, yards   the shortest way between two flight points over the nodes in
--                                           `known` (to may be unknown): { from, ..., to } and its yards; nil with none
--   Shy.Way.Flight.Path(hops) -> line          the line flown along hops: { continent, north, west, ... }; nil unknown
--   Shy.Way.Flight.Adopt(air)                  times another addon kept before ShyWay did ({ times, timed, reckoned })
--   Shy.Way.Flight.Speed() -> yards a second   a flight's speed for the character (Frequent Flier counted)
--   Shy.Way.Flight.Perk() -> true              the character has Frequent Flier
--   Shy.Way.Flight.Offer(slot) -> seconds, timed   the flight to a slot of the flight master's map now open
--   Shy.Way.Flight.Clock(seconds) -> "1:23"
--
-- Bus: SHY_FLIGHT (flight or nil), at take-off, at landing and when an early landing is asked for.

local Maps = Shy.Maps

local Flight = {}
Shy.Way.Flight = Flight

local AIR_SPEED = 30         -- yards a second, without the perk
local FREQUENT_FLIER = 1225490   -- the perk's spell (the client's SpellName); its aura makes flights 20% faster
local PERK = 1.2
local RECKONED_AT = 32       -- yards a second estimates were reckoned at before air.speed was kept
local TAKE_OFF = 30          -- seconds from asking for a flight within which the character must be in the air
local SHORTEST = 5           -- seconds: less than this was no flight
local WATCH = 0.25           -- seconds between looks at whether the character is in the air
local BEND = 15              -- yards: the curve is drawn in pieces no longer than this
-- Following the player along the line: how much faster than its pace they may fly, yards ahead looked at on top,
-- and how near a point must be to be where they are.
local FASTEST, SLACK, NEAR = 1.5, 60, 60

local board                  -- the flight master's map as it last opened: [slot] = { to, key, yards }
local asked                  -- the point taken from it, and when: { offer, at }
local flight                 -- the flight being flown
local air                    -- ShyWayDB.air

local function Saved()
	local saved = Shy.Way.Saved()
	saved.flying = saved.flying or {}
	return saved.flying
end

-- Times

-- Measured seconds per estimated second.
local function Pace()
	if air.reckoned <= 0 then return 1 end
	return math.min(2, math.max(0.5, air.timed / air.reckoned))
end

-- How many times faster than a flight without the perk the character flies.
local function Fast()
	if C_SpellBook.IsSpellKnown(FREQUENT_FLIER, Enum.SpellBookSpellBank.Player) == true then return PERK end
	return 1
end

function Flight.Perk()
	return Fast() > 1
end

function Flight.Speed()
	if Fast() == 1 then return AIR_SPEED end
	return AIR_SPEED * Fast()
end

-- A time kept (as without the perk), for the character: as kept when it has no perk.
local function Theirs(seconds)
	local fast = Fast()
	if fast == 1 then return seconds end
	return seconds / fast
end

-- Returns seconds, timed; nil when unknown.
local function Known(offer)
	local timed = air.times[offer.key]
	if timed then return Theirs(timed), true end
	if offer.yards then return offer.yards / Flight.Speed() * Pace(), false end
end

local ends                   -- "from>to" -> seconds, from the times kept; made again after a landing
local ways, waysFor = {}, nil   -- "from>to" -> yards or false, for the nodes of `waysFor`

local function Timed(from, to)
	if not ends then
		ends = {}
		for key, seconds in pairs(air.times) do
			local first, last = key:match("^(%d+)>"), key:match(">(%d+)$")
			local pair = first and last and (first .. ">" .. last)
			if pair and (not ends[pair] or seconds < ends[pair]) then ends[pair] = seconds end
		end
	end
	return ends[from .. ">" .. to]
end

local function Way(from, to, known)
	local paths = Shy.Way.data.flightPaths
	if not paths then return nil end
	local best, done = { [from] = 0 }, {}
	while true do
		local at, least
		for node, yards in pairs(best) do
			if not done[node] and (not least or yards < least) then at, least = node, yards end
		end
		if not at then return nil end
		if at == to then return least end
		done[at] = true
		for on, run in pairs(paths[at] or {}) do
			if known[on] and not done[on] and (not best[on] or least + run < best[on]) then best[on] = least + run end
		end
	end
end

-- The hops of the shortest way between two flight points over the nodes in `known`: { from, ..., to }, and its yards.
function Flight.Route(from, to, known)
	local paths = Shy.Way.data.flightPaths
	if not (paths and from and to) then return nil end
	local best, back, done = { [from] = 0 }, {}, {}
	while true do
		local at, least
		for node, yards in pairs(best) do
			if not done[node] and (not least or yards < least) then at, least = node, yards end
		end
		if not at then return nil end
		if at == to then
			local hops = { to }
			while hops[1] ~= from do table.insert(hops, 1, back[hops[1]]) end
			return hops, least
		end
		done[at] = true
		for on, run in pairs(paths[at] or {}) do
			if (known[on] or on == to) and not done[on] and (not best[on] or least + run < best[on]) then
				best[on], back[on] = least + run, at
			end
		end
	end
end

function Flight.Seconds(from, to, known, stamp)
	if not air then return nil end
	local timed = Timed(from, to)
	if timed then return Theirs(timed), true end
	if waysFor ~= stamp then
		wipe(ways)
		waysFor = stamp
	end
	local key = from .. ">" .. to
	local yards = ways[key]
	if yards == nil then
		yards = Way(from, to, known) or false
		ways[key] = yards
	end
	if yards then return yards / Flight.Speed() * Pace(), false end
end

function Flight.Adopt(older)
	if not air or type(older) ~= "table" or type(older.times) ~= "table" then return end
	for key, seconds in pairs(older.times) do
		if not air.times[key] then air.times[key] = seconds end
	end
	-- (Reckoned at the speed estimates used then.)
	if air.reckoned <= 0 and (older.reckoned or 0) > 0 then
		air.timed, air.reckoned = older.timed or 0, older.reckoned * RECKONED_AT / AIR_SPEED
	end
	ends = nil
end

-- The flight master's map: destination, node chain and yards per reachable slot; and every flight point's
-- name on it by node (names), for where a flight lands when it is asked to land early.
local names = {}
local function Board()
	local nodes = C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())
	board = {}
	local ids, here = {}, 0
	for _, node in ipairs(nodes) do
		ids[node.slotIndex] = node.nodeID
		if node.nodeID and node.name then names[node.nodeID] = node.name:match("^[^,]+") end
		if node.state == Enum.FlightPathState.Current then here = node.nodeID or 0 end
	end
	local paths = Shy.Way.data.flightPaths
	for _, node in ipairs(nodes) do
		if node.state == Enum.FlightPathState.Reachable and node.name then
			local slot = node.slotIndex
			local key, yards = { here }, paths and 0 or nil
			for hop = 1, GetNumRoutes(slot) do
				local from, to = ids[TaxiGetNodeSlot(slot, hop, true)], ids[TaxiGetNodeSlot(slot, hop, false)]
				local run = yards and from and to and paths[from] and paths[from][to]
				yards = run and yards + run or nil
				key[#key + 1] = to or 0
			end
			-- No hops reported: key by the two ends, no estimate.
			if #key == 1 then key[2], yards = node.nodeID or 0, nil end
			board[slot] = { to = node.name:match("^[^,]+"), key = table.concat(key, ">"), yards = yards }
		end
	end
end

-- The line

-- A line (Shy.Maps.Smooth) with: flight, key, continent, ends (each hop's last point), hops (the node each
-- hop lands at), before (yards flown on another map before it), at (the point the player was last at) and
-- seen (when).
local line

-- The line of a flight by its node chain ("2>4>6"); nil when a path of it is unknown.
local function Lined(key)
	local all = Shy.Way.data.flightWays
	if not all then return nil end
	local hops, points, last, continent, before = {}, {}, {}, nil, 0
	for node in key:gmatch("%d+") do hops[#hops + 1] = tonumber(node) end
	for i = 2, #hops do
		local way = all[hops[i - 1]] and all[hops[i - 1]][hops[i]]
		if not way then return nil end
		-- (A path onto another map: what comes after it is what is flown there. The yards flown before it are kept.)
		if continent and continent ~= way[1] then
			for j = 3, #points - 1, 2 do
				before = before + math.sqrt((points[j] - points[j - 2]) ^ 2 + (points[j + 1] - points[j - 1]) ^ 2)
			end
			wipe(points)
			wipe(last)
		end
		continent = way[1]
		local from, count = 2, #points
		-- (A hop sets out where the last one ended.)
		if count > 0 and (points[count - 1] - way[2]) ^ 2 + (points[count] - way[3]) ^ 2 < 25 then from = 4 end
		for j = from, #way do points[#points + 1] = way[j] end
		last[#last + 1] = #points / 2
	end
	local made = Maps.Smooth(points, BEND)
	if not made then return nil end
	made.key, made.continent, made.ends, made.hops, made.before = key, continent, {}, {}, before
	for hop, point in ipairs(last) do made.ends[hop] = made.point[point] end
	-- (A path onto another map drops the hops before it.)
	for i = #hops - #last + 1, #hops do made.hops[#made.hops + 1] = hops[i] end
	return made
end

-- The line flown along those hops: { continent, north, west, north, west, ... } on the map it lands on, or nil.
function Flight.Path(hops)
	local made = hops and #hops > 1 and Lined(table.concat(hops, ">"))
	if not (made and made.n) then return nil end
	local flat = { made.continent }
	for i = 1, made.n do flat[#flat + 1], flat[#flat + 2] = made.north[i], made.west[i] end
	return flat
end

local function Lines()
	if not flight then return nil end
	if not line or line.flight ~= flight then
		line = (line and line.key == flight.key and line.n) and line or Lined(flight.key) or { key = flight.key }
		line.flight, line.at = flight, nil
	end
	return line.n and line or nil
end

-- The last point of the line the flight will fly: the end of the hop it was on when asked to land early.
local function Last()
	return flight.stopAt or line.n
end

-- Seconds a yard of the line takes: the flight's own time over its length where that is known (on another
-- map first, those yards too), else a flight's speed at the pace flights have kept.
local function Rate()
	if flight.seconds and line and line.n and line.along[line.n] > 0 then
		return flight.seconds / (line.along[line.n] + (line.before or 0))
	end
	return Pace() / Flight.Speed()
end

-- The passes of the line from point `from` that come within NEAR yards of the player (a line that loops, or
-- flies into a town and out the way it came, passes the same ground twice). Of these, the closest point of
-- the one nearest `expect` yards along it; nil with none.
local function Pass(north, west, from, expect)
	local near, best, off = NEAR * NEAR, nil, math.huge
	local i = from
	while i <= line.n do
		if (line.north[i] - north) ^ 2 + (line.west[i] - west) ^ 2 <= near then
			local close, least = i, (line.north[i] - north) ^ 2 + (line.west[i] - west) ^ 2
			while i < line.n do
				local away = (line.north[i + 1] - north) ^ 2 + (line.west[i + 1] - west) ^ 2
				if away > near then break end
				i = i + 1
				if away < least then close, least = i, away end
			end
			local by = math.abs(line.along[close] - expect)
			if by < off then best, off = close, by end
		end
		i = i + 1
	end
	return best
end

-- The point of the line the player at (north, west) is at, only ever onward. It looks only as far ahead as the
-- flight can have flown since the last look, so a loop's later pass close by is never taken for it. Far from all
-- of that (a jump, the first look, the line come in from another map), the pass near them that is nearest where
-- the clock puts them; with none, the nearest point at first and where it was after.
local function Passed(north, west)
	local now, at = GetTime(), line.at
	local best
	if at then
		local gone = (now - line.seen) / Rate()
		local reach = line.along[at] + gone * FASTEST + SLACK
		local to = at
		while to < line.n and line.along[to + 1] <= reach do to = to + 1 end
		local away
		best, away = Maps.Nearest(line, north, west, at, math.min(line.n, to + 1))
		if away > NEAR then best = Pass(north, west, at, line.along[at] + gone) or best end
	else
		local expect = (now - flight.started) / Rate() - (line.before or 0)
		best = Pass(north, west, 1, expect) or Maps.Nearest(line, north, west, 1, line.n)
	end
	line.at, line.seen = best, now
	return best
end

-- The same, for where the player is now; nil when the game won't say or the line isn't known.
local function Here()
	if not Lines() then return nil end
	local continent, north, west = Shy.Here(true)
	if not north or continent ~= line.continent then return line.at end
	return Passed(north, west)
end

function Flight.Line(continent, north, west)
	if not north or not UnitOnTaxi("player") or not Lines() or line.continent ~= continent then return nil end
	local at, last = Passed(north, west), Last()
	return line, math.min(at + 1, last), last
end

function Flight.Landing()
	if not Lines() then return nil end
	local last = Last()
	return line.continent, line.north[last], line.west[last]
end

-- Taking off and landing

local Redraw, trip           -- the maps' (below)

local function Tell()
	if Redraw then Redraw() end
	Shy:Fire("SHY_FLIGHT", flight)
end

-- flight.names: the names of the flight points it goes by, by node (as the flight master's map had them).
local function TakeOff(offer, started, rough)
	local seconds, sure = Known(offer)
	local named = offer.names or {}
	for text in offer.key:gmatch("%d+") do
		local node = tonumber(text)
		named[node] = named[node] or names[node]
	end
	flight = { to = offer.to, key = offer.key, yards = offer.yards, seconds = seconds, sure = sure, started = started, rough = rough, names = named }
	Tell()
end

-- Asked to land early: the flight lands where the hop it is on ends. It is now a flight there, counted down
-- from how far that is along the line (flight.stopAt: the line's point there; earlyLeft: the seconds it
-- had to go when asked). With the line unknown, where it lands isn't known either.
local function Early()
	flight.early = true
	local at = Here()
	if not at then return end
	for hop, last in ipairs(line.ends) do
		if last >= at then
			local node = line.hops[hop]
			flight.stopAt = last
			flight.to = flight.names[node] or (hop == #line.ends and flight.to) or "the next flight point"
			flight.earlyLeft, flight.earlyAt = (line.along[last] - line.along[at]) * Rate(), GetTime()
			return
		end
	end
end

local function Land()
	local took = GetTime() - flight.started
	if not flight.rough and not flight.early and took >= SHORTEST then
		-- Kept as long as it takes without the perk.
		took = took * Fast()
		-- Feed the pace once per route.
		if flight.yards and not air.times[flight.key] then
			air.timed, air.reckoned = air.timed + took, air.reckoned + flight.yards / AIR_SPEED
		end
		air.times[flight.key] = math.floor(took * 10 + 0.5) / 10
		ends = nil
	end
	flight = nil
	Saved()[Shy.Profiles.Character()] = nil
	Tell()
end

local function Watch()
	local now = GetTime()
	if asked and now - asked.at > TAKE_OFF then asked = nil end
	if UnitOnTaxi("player") then
		if not flight and asked then
			TakeOff(asked.offer, now)
			Saved()[Shy.Profiles.Character()] = { to = flight.to, key = flight.key, yards = flight.yards, at = time(), names = flight.names }
			asked = nil
		end
	elseif flight then
		Land()
	end
	-- (In the air with the minimap's line not up: the minimap wasn't ready when it took off.)
	if flight and trip and not trip.mini.frame:IsShown() then trip:Update() end
end

-- After a reload mid-flight: count down again, but don't keep the time.
local function Resume()
	local saved = Saved()[Shy.Profiles.Character()]
	if saved and saved.key and saved.at and UnitOnTaxi("player") then
		TakeOff(saved, GetTime() - (time() - saved.at), true)
	else
		Saved()[Shy.Profiles.Character()] = nil
	end
end

function Flight.Now()
	return flight
end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

function Flight.Left()
	if not flight then return nil end
	if flight.early then
		-- (Where it now lands, unknown: nothing to count.)
		if not flight.earlyLeft then return nil end
		local label, at = "Flying to " .. flight.to, Here()
		local left = at and (line.along[flight.stopAt] - line.along[at]) * Rate() or flight.earlyLeft - (GetTime() - flight.earlyAt)
		if left <= 0 or flight.earlyLeft <= 0 then return label, 0, 0, "landing" end
		return label, left, math.min(1, left / flight.earlyLeft), "about " .. Clock(left)
	end
	local label, gone = "Flying to " .. flight.to, GetTime() - flight.started
	local left = flight.seconds and flight.seconds - gone
	if left and left > 0 then return label, left, left / flight.seconds, (flight.sure and "" or "about ") .. Clock(left) end
	-- Past the known time, or no estimate: count up.
	if flight.sure then return label, 0, 0, "landing" end
	return label, gone, 0, Clock(gone) .. " so far"
end

-- What the maps show: the flight as a trip (Shy.Maps.Trip), in the travel color under the flight's wing.

Redraw = function()
	if trip then trip:Update() end
end

-- The flight to a slot of the flight master's map now open (Aloft.lua says it in its hover).
function Flight.Offer(slot)
	local offer = air and board and board[slot]
	if offer then return Known(offer) end
end

Flight.Clock = Clock

Shy:On("SHY_LOGIN", function()
	local saved = Shy.Way.Saved().air or {}
	saved.times, saved.timed, saved.reckoned = saved.times or {}, saved.timed or 0, saved.reckoned or 0
	-- The pace compares times with estimates at one speed: those reckoned at another are made over.
	if saved.speed ~= AIR_SPEED then
		saved.reckoned = saved.reckoned * (saved.speed or RECKONED_AT) / AIR_SPEED
		saved.speed = AIR_SPEED
	end
	Shy.Way.Saved().air = saved
	air = saved
	hooksecurefunc("TakeTaxiNode", function(slot)
		local offer = board and board[slot]
		asked = offer and { offer = offer, at = GetTime() } or nil
	end)
	hooksecurefunc("TaxiRequestEarlyLanding", function()
		if flight and not flight.early then
			Early()
			Tell()
		end
	end)
	trip = Maps.Trip({ color = Shy.Theme.TRAVEL.flight, sign = "flight", strip = "Flight", Line = Flight.Line, Left = Flight.Left,
		To = function() return flight and flight.to end, unknown = { "Next flight point", "Landing early" }, aboard = true })
	-- Looked at only from asking for a flight until it lands: the game says when control of the character is
	-- taken and given back (a flight's take-off and landing, as its own action bars go by), and between them
	-- a look every WATCH seconds keeps the countdown and the minimap's line, and notices a landing it didn't say.
	local looking = false
	local Look
	Look = Shy.Clocked("flight: a look", function()
		looking = false
		Watch()
		if (flight or asked) and not looking then
			looking = true
			C_Timer.After(WATCH, Look)
		end
	end)
	local function Wake()
		if not looking then Look() end
	end
	hooksecurefunc("TakeTaxiNode", Wake)
	local events = CreateFrame("Frame")
	events:RegisterEvent("TAXIMAP_OPENED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_CONTROL_LOST")
	events:RegisterEvent("PLAYER_CONTROL_GAINED")
	events:SetScript("OnEvent", function(_, event, login, reload)
		if event == "TAXIMAP_OPENED" then
			Board()
		elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
			Wake()
		else
			if reload then
				Resume()
			elseif login then
				Saved()[Shy.Profiles.Character()] = nil
			end
			Wake()
		end
	end)
end)
