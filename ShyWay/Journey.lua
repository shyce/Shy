-- Shy.Way journeys: the quickest way from one place to another by every way there is. On foot over
-- the ground itself (Ground.lua: stairs, lifts, drops, the floor that high), and by every ride the game
-- has: a flight between flight points the character knows, a boat, a zeppelin, the Skyborne's airboat, the
-- tram, a portal. One question, one answer, the same for every addon: the card, the arrow, the maps and
-- the guides never disagree about the way.
--
--   local T = Shy.Way
--   T.Place(world, north, west [, opts]) -> place      a place: { world, north, west, up, level, name }
--        opts.up: the height the place stands at (the top of a tower, not the hall at its foot);
--        opts.level: T.GROUND, T.UNDER or T.ABOVE; opts.name: what it is called. Make a place once and
--        ask with it as often as wanted.
--   T.OnMap(map, x, y [, opts]) -> place or nil        the same from a map position (x, y: 0 to 1)
--   T.Here() -> place or nil                           where the player stands; aboard a flight, a boat, a
--                                                      zeppelin or the tram, where it lands (place.aboard: how)
--   T.Journey(from, to [, opts]) -> journey, state
--   T.Journey(from, { place, place, ... } [, opts])    to the quickest reached of several (journey.goal)
--        journey = { seconds =, goal =, key =, n =, [1..n] = leg }
--        leg = { by = "walk" | "flight" | "boat" | "zeppelin" | "airboat" | "tram" | "portal",
--                from = place, to = place, seconds = the whole leg (a ride's wait and talk in it),
--                aboard = seconds riding, wait = seconds waited on average, every = seconds between two
--                departures, sure = the time was kept from riding it (not reckoned), ride = its key,
--                far = a walk too long to work out, reckoned at least this long }
--        A ride's ends are stops: places with by, name, whose ("A", "H", "" anyone's) and, for a flight
--        point, node.
--        state: nil, known. "working": being worked out; journey is the quickest found so far (or nil),
--        and SHY_TERRAIN is sent when there is more. "far": a walk on it is too long to work out. A nil
--        journey with a nil state: no way at all is known (a place the ground doesn't reach).
--        opts.lead: the journey being followed; it is kept until another is clearly quicker (STAY)
--        opts.by: { flight = false, boat = false, ... }: ways not to take
--        opts.now: worked out on the spot (a test, a generator), never "working"
--   T.Follow(journey), T.Following() -> journey        the journey the player follows now, as whoever leads them
--                                                      says (one at a time; nil: none)
--   T.Flights() -> { [node] = true }                   the flight points the character knows
--   T.KnowsFlight(name) -> bool                        ... one by its name or a part of it ("Crossroads")
--   T.Learn(node [, quiet])                            ... one more (the flight master's map teaches them);
--                                                      quiet: no SHY_TERRAIN (many at once)
--   T.Kept(ride, seconds [, aboard])                   a ride timed from its stop to where it lands (aboard: from
--                                                      setting off); each the mean of the last few (Ride.lua times them)
--   T.Rides(), T.Stops()                               every ride ({ from, to, by, aboard, wait, whose, key, line })
--                                                      and every stop
--   T.RideSeconds(ride [, aboard]) -> seconds, sure    a ride as the character takes it, its wait in it (aboard: none)
--
-- How: the stops (every flight point, dock, zeppelin tower, airboat landing, tram door and portal) are a
-- graph, shipped (Data\Transit.lua): the rides between them, and the seconds on foot between two stops of
-- one ground, worked out over its floors when the ground was made. A journey adds the place it starts from
-- and the places it may end at, joined to every stop by the straight line at a runner's best pace, which
-- no walk beats. The quickest way over that graph is found; each straight line on it is then asked of the
-- ground (Ground.lua), and the way is found again, until the quickest is walked all over ground known:
-- it is then the quickest there is, and only the few walks that could have been quicker were asked. A
-- walk from where someone stands to a stop is searched from the stop, and a walk to the goal from the
-- goal, so each search is kept however the player moves, and shared by every journey to that goal.

local T = Shy.Way
local Flight = T.Flight

local PACE = 7               -- yards a second: a runner's pace
local RUN = PACE * 1.05      -- yards a second no walk is quicker than (a runner's pace and a little: a lower bound)
local TALK = 10              -- seconds at a flight master before a flight
local STAY = 1.2             -- the journey being followed is kept until another takes less than its time over this
local LEAD_NEAR = 40         -- yards: ... while it ends this near the place asked for (a camp's middle moves a little)
local GAIN = 0.9             -- a ride is taken where it takes no more than this share of the walk ...
local SPARE = 45             -- ... and spares this many seconds of it
local LONGEST = 1800         -- seconds: a ride timed longer than this was something else
local RUNS = 5               -- rides a kept time is the mean of
local BIG = 1e12

local SIDE = { Alliance = "A", Horde = "H" }

-- Places ------------------------------------------------------------------------------------------

function T.Place(world, north, west, opts)
	local place = { world = world, north = north, west = west }
	if opts then place.up, place.level, place.name = opts.up, opts.level, opts.name end
	return place
end

function T.OnMap(map, x, y, opts)
	local world, spot = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
	if not world or not spot then return nil end
	local north, west = spot:GetXY()
	local place = T.Place(world, north, west, opts)
	place.map, place.x, place.y = map, x, y
	return place
end

function T.Here()
	-- (Aboard a boat, a zeppelin or the tram: where it lands, Ride.lua.)
	local ride = T.Riding and T.Riding()
	if ride then
		if not ride.to then return nil end
		local place = T.Place(ride.to.world, ride.to.north, ride.to.west, { up = ride.to.up, name = ride.to.name })
		place.map, place.x, place.y, place.aboard = ride.to.map, ride.to.x, ride.to.y, ride.by
		return place
	end
	if UnitOnTaxi("player") and Flight then
		local world, north, west = Flight.Landing()
		if world then
			local place = T.Place(world, north, west)
			place.aboard = "flight"
			return place
		end
		return nil
	end
	local world, north, west = Shy.Here(true)
	if not world then return nil end
	return T.Place(world, north, west)
end

local function Straight(a, b)
	return math.sqrt((a.north - b.north) ^ 2 + (a.west - b.west) ^ 2)
end

-- The stops ---------------------------------------------------------------------------------------
-- Shy.Way.data.transit (Data\Transit.lua): stops { by, world, north, west, up, whose, name, id, node, map, x, y }
-- (x, y in hundredths of a percent; a stop's place has them 0 to 1, as T.OnMap's), rides { from,
-- to, by, seconds aboard, seconds waited, whose }, walks [stop] = { stop, seconds, ... }. A ride's key (its
-- kept time) is by its stops' ids, the same from one build to the next.

local made                   -- the stops and rides as places, made from Shy.Way.data.transit once
local version = 0            -- what is known has changed: flight points learned, a ride timed

local function Made()
	local data = T.data.transit
	if not data then return nil end
	if made and made.data == data then return made end
	made = { data = data, stops = {}, rides = {}, out = {}, byWorld = {}, flights = {}, byNode = {}, byKey = {} }
	for index, raw in ipairs(data.stops) do
		local stop = T.Place(raw[2], raw[3], raw[4], { up = raw[5] ~= false and raw[5] or nil, name = raw[7] })
		stop.by, stop.whose, stop.id, stop.index = raw[1], raw[6] or "", raw[8] or tostring(index), index
		stop.node = raw[9] ~= false and raw[9] or nil
		if raw[10] then stop.map, stop.x, stop.y = raw[10], raw[11] / 10000, raw[12] / 10000 end
		made.stops[index] = stop
		made.out[index] = {}
		local here = made.byWorld[stop.world] or {}
		made.byWorld[stop.world] = here
		here[#here + 1] = stop
		if stop.by == "flight" and stop.node then
			made.flights[#made.flights + 1] = stop
			made.byNode[stop.node] = stop
		end
	end
	for index, raw in ipairs(data.rides) do
		local from, to = made.stops[raw[1]], made.stops[raw[2]]
		local ride = { from = from, to = to, by = raw[3], aboard = raw[4], wait = raw[5] or 0, whose = raw[6] or "",
			key = raw[3] .. ":" .. from.id .. ">" .. to.id, line = data.lines and data.lines[index] or nil }
		made.rides[#made.rides + 1] = ride
		made.byKey[ride.key] = ride
		local out = made.out[raw[1]]
		out[#out + 1] = ride
	end
	return made
end

-- What the character has: their side, the flight points they know.
local function Side()
	return SIDE[UnitFactionGroup("player") or ""] or ""
end

local function Mine(whose, side)
	return whose == "" or side == "" or whose:find(side, 1, true) ~= nil
end

-- The flight points this character knows (ShyWayDB.flightPoints, by character: [node] = true).
local function Known()
	local saved = T.Saved()
	saved.flightPoints = saved.flightPoints or {}
	local who = UnitGUID("player") or "?"
	local known = saved.flightPoints[who]
	if not known then
		known = {}
		saved.flightPoints[who] = known
	end
	return known
end

function T.Flights()
	return Known()
end

-- Whether the character knows a flight point by its name or a part of it, any case ("Crossroads" is
-- "The Crossroads, The Barrens").
function T.KnowsFlight(name)
	local m = Made()
	if not (m and name and name:find("%w")) then return false end
	local known, wanted = Known(), name:upper()
	for _, stop in ipairs(m.flights) do
		if known[stop.node] and stop.name and stop.name:upper():find(wanted, 1, true) then return true end
	end
	return false
end

-- Every ride there is: { from, to (stops), by, aboard, wait, whose, key, line }; and every stop.
function T.Rides()
	local m = Made()
	return m and m.rides or {}
end

function T.Stops()
	local m = Made()
	return m and m.stops or {}
end

function T.Learn(node, quiet)
	local known = Known()
	if node and not known[node] then
		known[node] = true
		version = version + 1
		if not quiet then Shy:Fire("SHY_TERRAIN", "flights") end
	end
end

-- The rides timed on this account (ShyWayDB.air.rides: [ride's key] = { s = seconds from its stop to where it
-- lands, the wait in them, n = runs; a = seconds aboard, from setting off, an = runs }).
local function Timed()
	local saved = T.Saved()
	saved.air = saved.air or {}
	saved.air.rides = saved.air.rides or {}
	return saved.air.rides
end

-- No ride takes less than this share of its line at a transport's speed (ride.aboard): a time under it was
-- no ride's (a ride joined short of its end), and is neither kept nor used.
local SHORTEST = 0.4
local function Plausible(ride, seconds)
	return seconds ~= nil and seconds >= (ride.aboard or 0) * SHORTEST
end

-- A ride's seconds, its wait in them (aboard: from setting off), and whether that was timed.
local function RideSeconds(ride, aboard)
	local kept = Timed()[ride.key]
	if kept and kept.a and not Plausible(ride, kept.a) then kept.a, kept.an = nil, nil end
	if kept and kept.s and not Plausible(ride, kept.s) then kept.s, kept.n = nil, nil end
	if aboard then
		if kept and kept.a and (kept.an or 0) > 0 then return kept.a, true end
		return ride.aboard, false
	end
	if kept and kept.s and (kept.n or 0) > 0 then return kept.s, true end
	return ride.aboard + ride.wait, false
end

function T.Kept(ride, seconds, aboard)
	if not ride or not ride.key or not seconds or seconds <= 0 or seconds > LONGEST or not Plausible(ride, seconds) then return end
	local all = Timed()
	local kept = all[ride.key] or {}
	local s, n = aboard and "a" or "s", aboard and "an" or "n"
	local runs = math.min(kept[n] or 0, RUNS - 1)
	kept[s], kept[n] = ((kept[s] or 0) * runs + seconds) / (runs + 1), runs + 1
	all[ride.key] = kept
	version = version + 1
end

-- A ride's seconds as the character will take it (kept, else reckoned with the wait; aboard: from setting off,
-- no wait), and whether timed.
function T.RideSeconds(ride, aboard)
	return RideSeconds(ride, aboard)
end

-- The graph ---------------------------------------------------------------------------------------
-- Made again when what is known changes (side, flight points, kept times, what may be ridden): the links
-- out of each stop, { to, seconds, kind, ride } where kind is "walk", "ride" or "flight".

local graph

local function Graph(by)
	local m = Made()
	if not m then return nil end
	local side, known = Side(), Known()
	local count = 0
	for _ in pairs(known) do count = count + 1 end
	local stamp = side .. version .. ":" .. count .. (by and ((by.flight == false and "f" or "") .. (by.boat == false and "b" or "")
		.. (by.zeppelin == false and "z" or "") .. (by.airboat == false and "a" or "") .. (by.tram == false and "t" or "")
		.. (by.portal == false and "p" or "")) or "")
	if graph and graph.m == m and graph.stamp == stamp then return graph end
	graph = { m = m, stamp = stamp, links = {} }
	local links = graph.links
	for index = 1, #m.stops do links[index] = {} end
	local walks = m.data.walks or {}
	for index, list in pairs(walks) do
		local from = m.stops[index]
		if from and Mine(from.whose, side) then
			for at = 1, #list, 2 do
				local to = m.stops[list[at]]
				if to and Mine(to.whose, side) then
					local out = links[index]
					out[#out + 1] = { from = from, to = to, seconds = list[at + 1], kind = "walk", exact = true }
				end
			end
		end
	end
	for _, ride in ipairs(m.rides) do
		if Mine(ride.whose, side) and not (by and by[ride.by] == false) then
			local seconds, sure = RideSeconds(ride)
			local out = links[ride.from.index]
			out[#out + 1] = { from = ride.from, to = ride.to, seconds = seconds, kind = "ride", ride = ride, sure = sure }
		end
	end
	-- Flights: from any flight point of the character's side (they learn it there, talking to its master)
	-- to every one they know.
	if Flight and not (by and by.flight == false) then
		for _, from in ipairs(m.flights) do
			if Mine(from.whose, side) then
				for _, to in ipairs(m.flights) do
					if to ~= from and known[to.node] and Mine(to.whose, side) and to.world == from.world then
						local seconds, sure = Flight.Seconds(from.node, to.node, known, stamp)
						if seconds then
							local out = links[from.index]
							out[#out + 1] = { from = from, to = to, seconds = seconds + TALK, aboard = seconds, kind = "flight", sure = sure }
						end
					end
				end
			end
		end
	end
	return graph
end

-- A heap of { seconds, node } pairs kept in two arrays.
local heapS, heapN, heapCount = {}, {}, 0
local function Push(seconds, node)
	heapCount = heapCount + 1
	local at = heapCount
	while at > 1 do
		local up = math.floor(at / 2)
		if heapS[up] <= seconds then break end
		heapS[at], heapN[at] = heapS[up], heapN[up]
		at = up
	end
	heapS[at], heapN[at] = seconds, node
end
local function Pop()
	local seconds, node = heapS[1], heapN[1]
	local lastS, lastN = heapS[heapCount], heapN[heapCount]
	heapS[heapCount], heapN[heapCount] = nil, nil
	heapCount = heapCount - 1
	local at, count = 1, heapCount
	while true do
		local child = at * 2
		if child > count then break end
		if child < count and heapS[child + 1] < heapS[child] then child = child + 1 end
		if heapS[child] >= lastS then break end
		heapS[at], heapN[at] = heapS[child], heapN[child]
		at = child
	end
	if count > 0 then heapS[at], heapN[at] = lastS, lastN end
	return seconds, node
end

-- Walks asked of the ground ---------------------------------------------------------------------------

-- Seconds on foot from one place to another: seconds; or nil and "working"; or the least it can be and
-- "far"; or nil (no way).
local function Walk(from, to, now)
	if from.world ~= to.world then return nil end
	local ask = now and T.Seconds or T.Ask
	local seconds, state, least = ask(from.world, from.north, from.west, to.north, to.west, to.level, to.up)
	if seconds then return seconds end
	if state == "far" then return least or Straight(from, to) / RUN, "far" end
	if state == "working" then return nil, "working" end
	-- No ground kept for that world: the straight line at a runner's pace, as anyone would reckon it.
	if not T.Has(from.world) then return Straight(from, to) / PACE end
	return nil
end

-- The journey ---------------------------------------------------------------------------------------

-- The ends' links: from the start to every stop of its world, and from every stop of a goal's world to that
-- goal, and from the start to each goal of its world: { kind = "walk", from, to, seconds, exact, state }.
-- Found over the graph with every walk not yet asked at its least; each walk on the quickest way is asked;
-- again, until the quickest is all known (or what is left on it is being worked out).
-- The links out of a start and into a goal are kept, on the graph they were made on: a route asks a journey to
-- each of its stops at once, all from where the player stands, and the same journeys again at every build, so
-- each walk on them is asked of the ground once, and nothing is made again for every stop or every build. A
-- walk the ground knows (its seconds, or that it is too far to work out) stays as it was told until the ground
-- says what ways there are changed (SHY_TERRAIN for anything but ways found); one it knew nothing of is asked
-- again in the next frame (link.at: it may only have had no room for the search). STARTS and ENDS places are
-- kept at the most: someone walking asks from a new place at every look.
local linked = { starts = {}, ends = {}, nStarts = 0, nEnds = 0, STARTS = 96, ENDS = 384 }
local function Linked(g)
	if linked.graph ~= g or linked.stale then
		linked.graph, linked.stale, linked.nStarts, linked.nEnds = g, nil, 0, 0
		wipe(linked.starts)
		wipe(linked.ends)
	end
	if linked.nStarts > linked.STARTS then
		linked.nStarts = 0
		wipe(linked.starts)
	end
	if linked.nEnds > linked.ENDS then
		linked.nEnds = 0
		wipe(linked.ends)
	end
	return linked
end
Shy:On("SHY_TERRAIN", function(why)
	if why ~= "found" then linked.stale = true end
end)

-- (One search at a time: what it reached, by what link and from where, in tables kept for it.)
local best, via, back = {}, {}, {}
local NONE = {}

-- A walk kept from an earlier frame that the ground knew nothing of then: to be asked again, at its least.
local function Fresh(link, frame)
	if link.exact and not link.seconds and link.at ~= frame then
		link.exact, link.state, link.seconds = nil, nil, Straight(link.from, link.to) / RUN
	end
	return link
end

local function Solve(from, goals, opts)
	local g = Graph(opts and opts.by)
	local now = opts and opts.now
	local stops = g and g.m.byWorld[from.world] or {}
	local kept = Linked(g)
	local frame, turn = GetTime(), T.worked or 0
	local ends = {}              -- [goal] = { links into it, by stop: false for a stop of another world }
	local fromKey = from.world .. ":" .. from.north .. ":" .. from.west
	-- The links out of the start, by stop, and into each goal: each made when a search first takes it (a hop
	-- between two places near each other takes few of them, and a journey is asked for every place of a way).
	local starts = kept.starts[fromKey]
	if not starts then
		starts = { least = {}, direct = {} }   -- least: the straight line to each stop, in seconds, kept for the ones not taken
		kept.starts[fromKey] = starts
		kept.nStarts = kept.nStarts + 1
	end
	local least = starts.least
	local direct, directTo = {}, {}   -- links out of the start straight to a goal, and which goal each leads to
	for index, goal in ipairs(goals) do
		local goalKey = goal.world .. ":" .. goal.north .. ":" .. goal.west .. ":" .. tostring(goal.level) .. ":" .. tostring(goal.up)
			.. ":" .. tostring(goal.name)
		if goal.world == from.world then
			local link = starts.direct[goalKey]
			if not link then
				link = { from = from, to = goal, seconds = Straight(from, goal) / RUN, kind = "walk" }
				starts.direct[goalKey] = link
			end
			direct[#direct + 1], directTo[#direct + 1] = Fresh(link, frame), index
		end
		local into = kept.ends[goalKey]
		if not into then
			into = {}
			kept.ends[goalKey] = into
			kept.nEnds = kept.nEnds + 1
		end
		ends[index] = into
	end
	local links = g and g.links or {}
	local all = g and g.m.stops or {}
	local count = #all
	-- Node numbers: stops 1..count; the same stops count + 1..2 * count as landed at by a flight (from which
	-- no flight leads on: the flight there would have flown on through it, with no landing and no word with
	-- the flight master between); and 2 * count + 1..3 * count as walked to from the start with no ride yet
	-- (from which no walk leads to a goal: a walk there and a walk on is no quicker than the walk straight to
	-- the goal, and each would be a search of its own over the ground); the start 3 * count + 1; goal i
	-- 3 * count + 1 + i.
	local START = 3 * count + 1
	local WALKED = 2 * count
	local working, far = false, false
	for _ = 1, 64 do
		wipe(best)
		wipe(via)
		wipe(back)
		heapCount = 0
		best[START] = 0
		Push(0, START)
		local reached
		while heapCount > 0 do
			local seconds, node = Pop()
			if seconds <= (best[node] or BIG) then
				if node > START and node <= START + #goals then
					reached = node
					break
				end
				local stop = count > 0 and (node - 1) % count + 1 or node
				local walked = node > WALKED
				if node == START then
					-- From the start: straight to each goal, and to every stop nearer than the nearest of them (a
					-- way by a stop no nearer than a goal is no quicker than the straight line to that goal).
					local bound = BIG
					for at, link in ipairs(direct) do
						if link.seconds then
							if link.seconds < bound then bound = link.seconds end
							local to = START + directTo[at]
							if link.seconds < (best[to] or BIG) then
								best[to], via[to], back[to] = link.seconds, link, node
								Push(link.seconds, to)
							end
						end
					end
					for _, at in ipairs(stops) do
						local link = starts[at.index]
						local walk
						if link then
							walk = Fresh(link, frame).seconds
						else
							walk = least[at.index]
							if not walk then
								walk = Straight(from, at) / RUN
								least[at.index] = walk
							end
							if walk < bound then
								link = { from = from, to = at, seconds = walk, kind = "walk" }
								starts[at.index] = link
							end
						end
						local to = WALKED + at.index
						if link and walk and walk < bound and walk < (best[to] or BIG) then
							best[to], via[to], back[to] = walk, link, node
							Push(walk, to)
						end
					end
				else
					for _, link in ipairs(links[stop]) do
						if link.seconds and not (node > count and not walked and link.kind == "flight") then
							local to = link.to.index + (link.kind == "flight" and count or (walked and link.kind == "walk") and WALKED or 0)
							local total = seconds + link.seconds
							if total < (best[to] or BIG) then
								best[to], via[to], back[to] = total, link, node
								Push(total, to)
							end
						end
					end
					for index, into in pairs(walked and NONE or ends) do
						local link = into[stop]
						if link == nil then
							local at, goal = all[stop], goals[index]
							link = at.world == goal.world and { from = at, to = goal, seconds = Straight(at, goal) / RUN, kind = "walk" } or false
							into[stop] = link
						end
						if link and Fresh(link, frame).seconds then
							local to, total = START + index, seconds + link.seconds
							if total < (best[to] or BIG) then
								best[to], via[to], back[to] = total, link, node
								Push(total, to)
							end
						end
					end
				end
			end
		end
		if not reached then return nil end
		-- The walks on it not yet asked of the ground: ask them; found again when any was longer.
		local asked, open = false, false
		local node = reached
		while node ~= START do
			local link = via[node]
			if link.kind == "walk" and not link.exact then
				local seconds, state
				-- (Being worked out when last asked, in this frame and with no work done on the ground since:
				-- still so. A route's journeys cross the same few walks dozens of times a build.)
				if link.open == frame and link.turn == turn then
					state = "working"
				else
					seconds, state = Walk(link.from, link.to, now)
				end
				if state == "working" then
					open = true
					link.open, link.turn = frame, turn
				else
					link.exact, link.state, link.seconds, link.at = true, state, seconds, frame
					asked = true
				end
			end
			node = back[node]
		end
		if not asked then
			-- All known but what is still being worked out: this is the quickest found so far.
			working = open
			local path = {}
			node = reached
			while node ~= START do
				local link = via[node]
				table.insert(path, 1, link)
				if link.state == "far" then far = true end
				node = back[node]
			end
			return path, best[reached], reached - START, working, far
		end
	end
	return nil
end

-- The seconds a path of links takes, and a key that says which way it is.
local function Keyed(path)
	local parts = {}
	for _, link in ipairs(path) do
		if link.kind ~= "walk" then
			parts[#parts + 1] = (link.ride and link.ride.key) or ("flight:" .. link.from.node .. ">" .. link.to.node)
		end
	end
	return #parts == 0 and "walk" or table.concat(parts, ",")
end

local function Legs(path, seconds, goal)
	local journey = { seconds = seconds, goal = goal, key = Keyed(path), n = #path }
	for index, link in ipairs(path) do
		local leg = { from = link.from, to = link.to, seconds = link.seconds }
		if link.kind == "walk" then
			leg.by = "walk"
			if link.state == "far" then leg.far = true end
		elseif link.kind == "flight" then
			leg.by, leg.aboard, leg.wait, leg.sure = "flight", link.aboard, 0, link.sure
		else
			local ride = link.ride
			leg.by, leg.ride, leg.sure = ride.by, ride.key, link.sure
			leg.wait = link.sure and nil or ride.wait
			leg.aboard = link.sure and link.seconds or ride.aboard
			leg.every = ride.wait > 0 and ride.wait * 2 or nil
		end
		journey[index] = leg
	end
	return journey
end

-- A journey as it is now from `from` to `goal`: the same legs, each timed again (its first walk from here,
-- its last to the goal as it stands now, a ride as it is now kept); nil where it ended elsewhere (the place
-- moved: LEAD_NEAR), or one of its legs is gone, not known now, or no longer to be taken (another side's, or
-- a way left out).
local function Again(from, goal, journey, opts)
	local last = journey[journey.n]
	if not goal or not last or last.to.world ~= goal.world or Straight(last.to, goal) > LEAD_NEAR then return nil end
	local m = Made()
	local known, side, by = Known(), Side(), opts and opts.by
	local out = { goal = journey.goal, key = journey.key, n = journey.n, seconds = 0 }
	for index = 1, journey.n do
		local leg = {}
		for key, value in pairs(journey[index]) do leg[key] = value end
		if leg.by == "walk" then
			if index == 1 then leg.from = from end
			if index == journey.n then leg.to = goal end
			if index == 1 or index == journey.n then
				local seconds, state = Walk(leg.from, leg.to, opts and opts.now)
				if not seconds then return nil end
				leg.seconds, leg.far = seconds, state == "far" or nil
			end
		elseif leg.by == "flight" then
			if not (Flight and leg.from.node and known[leg.to.node]) or (by and by.flight == false)
				or not Mine(leg.from.whose, side) or not Mine(leg.to.whose, side) then
				return nil
			end
			local aboard, sure = Flight.Seconds(leg.from.node, leg.to.node, known, graph and graph.stamp)
			if not aboard then return nil end
			leg.seconds, leg.aboard, leg.sure = aboard + TALK, aboard, sure
		else
			local ride = m and m.byKey[leg.ride]
			if not ride or not Mine(ride.whose, side) or (by and by[ride.by] == false) then return nil end
			local seconds, sure = RideSeconds(ride)
			leg.seconds, leg.sure = seconds, sure
			leg.wait = not sure and ride.wait or nil
			leg.aboard = sure and seconds or ride.aboard
		end
		out[index] = leg
		out.seconds = out.seconds + leg.seconds
	end
	return out
end

-- A path that takes a ride, against walking all the way: the walk wins unless the ride is clearly quicker.
local function Ridden(path)
	for _, link in ipairs(path) do
		if link.kind ~= "walk" then return true end
	end
	return false
end

function T.Journey(from, to, opts)
	if not from or not to then return nil end
	local goals = to.world and { to } or to
	local path, seconds, goal, working, far = Solve(from, goals, opts)
	if not path then return nil, working and "working" or nil end
	-- Walking all the way, where that is known and the ride spares too little of it.
	if Ridden(path) then
		local walked, which
		-- (Only a walk that could win is asked of the ground: one whose straight line, at a pace no walk beats,
		-- already takes too long would be a search across the continent for nothing.)
		local worth = math.max(seconds / GAIN, seconds + SPARE)
		for index, place in ipairs(goals) do
			if place.world == from.world and Straight(from, place) / RUN < worth then
				local s, state = Walk(from, place, opts and opts.now)
				if state == "working" then working = true end
				if s and not state and (not walked or s < walked) then walked, which = s, index end
			end
		end
		if walked and (seconds > walked * GAIN or walked - seconds < SPARE) then
			path = { { from = from, to = goals[which], seconds = walked, kind = "walk", exact = true } }
			seconds, goal, far = walked, which, false
		end
	end
	local journey = Legs(path, seconds, goal)
	-- The journey being followed, while it is about as quick.
	local lead = opts and opts.lead
	if lead and lead.key ~= journey.key and lead.n and lead.n > 0 then
		local held = Again(from, goals[lead.goal or 1], lead, opts)
		if held and held.seconds <= journey.seconds * STAY then journey = held end
	end
	local state = (working and "working") or (far and "far") or nil
	return journey, state
end

-- The journey the player follows now, as whoever leads them says (ShyQuest's lead stop): which way a ride
-- with no other sign of it goes (the tram, gone into with no door seen: Ride.lua).
local followed

function T.Follow(journey)
	followed = journey
end

function T.Following()
	return followed
end

-- Flight points learned: every one the flight master's map shows that can be flown to; and the one beside
-- the player (HERE yards) when that map opens (it opens only at a flight master, whose point talking to
-- them gives, whatever the map calls it) or the game says a flight path was found.
local HERE = 150
local function LearnBeside()
	local here, m = T.Here(), Made()
	for _, stop in ipairs(here and m and m.flights or {}) do
		if stop.world == here.world and Straight(stop, here) <= HERE then T.Learn(stop.node) end
	end
end
local events = CreateFrame("Frame")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("UI_INFO_MESSAGE")
events:SetScript("OnEvent", function(_, event, _, message)
	if event == "TAXIMAP_OPENED" then
		local nodes = C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())
		for _, node in ipairs(nodes or {}) do
			if node.nodeID and node.state ~= Enum.FlightPathState.Unreachable then T.Learn(node.nodeID) end
		end
		LearnBeside()
		return
	end
	if issecretvalue(message) or message ~= ERR_NEWTAXIPATH then return end
	LearnBeside()
end)
