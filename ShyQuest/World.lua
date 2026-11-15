-- Where the player is, and how far and which way everything else is.
-- A position is (map, x, y), x and y 0-9999 (Data.lua). Positions on different maps are
-- compared in continent yards via C_Map.GetWorldPosFromMapPos, whose vector reads (north, west).

local ADDON, ns = ...

local W = {}
ns.World = W

local UNITS = 10000
-- A map lies on its continent as a rectangle, north down its height and west across its width: its top left
-- corner and how far it runs each way ({ continent, north, west, north across, west across }, or false for one
-- with no world place), asked once a map and kept by the core (Shy.MapFrame).
local Frame = Shy.MapFrame

-- continent, north, west of a map position; nil for maps with no world place (instances, cosmic).
function W.ToWorld(map, x, y)
	local frame = map and Frame(map)
	if frame then return frame[1], frame[2] + frame[4] * y / UNITS, frame[3] + frame[5] * x / UNITS end
end

-- A world place as a position on a map (x, y in the map's units); nil for a map with no world place or one
-- on another continent. Outside the map's own rectangle the numbers run past 0 and 9999.
function W.ToMap(map, continent, north, west)
	local frame = map and Frame(map)
	if not frame or frame[1] ~= continent or frame[4] == 0 or frame[5] == 0 then return nil end
	return math.floor((west - frame[3]) / frame[5] * UNITS + 0.5), math.floor((north - frame[2]) / frame[4] * UNITS + 0.5)
end

-- False while the game won't say where you are (dungeons, loading screens). (Read as the core reads it,
-- Shy.Here: in plain numbers wherever those say the place, with no vector made.)
function W.Update()
	local continent, north, west = Shy.Here(true)
	local map, x, y = Shy.HereOn()
	W.map = map
	if not continent or not x then
		W.continent = nil
		return false
	end
	W.x, W.y = math.floor(x * UNITS + 0.5), math.floor(y * UNITS + 0.5)
	W.lastMap = map       -- with x and y, the last known position; kept while the game reports none
	W.continent = continent
	W.north, W.west = north, west
	return true
end

function W.Known()
	return W.continent ~= nil
end

-- In the air, or aboard
-- The route is worked out from where the flight or the ride lands (Shy.Way.Landing), so what leads is
-- what to do first on landing, and nothing reshuffles as it passes over things. W.FromLanding(fn) runs fn
-- with W saying the player stands there (on the zone map there; W.aloft true), and says where they really
-- are again after: everything else (the minimap, the arrow, the zone notices) goes by that. Out of the air
-- and not aboard, or where it lands is on no map known, fn runs as it is.
local landing = {}           -- where it lands: map, x, y, continent, north, west
local FIELDS = { "map", "x", "y", "lastMap", "continent", "north", "west" }
local real = {}              -- where the player is, while fn runs

local function Landing()
	local place = Shy.Way.Landing()
	if not (place and place.map) then return nil end
	landing.map, landing.lastMap = place.map, place.map
	landing.x, landing.y = math.floor(place.x * UNITS + 0.5), math.floor(place.y * UNITS + 0.5)
	landing.continent, landing.north, landing.west = place.world, place.north, place.west
	return landing
end

function W.FromLanding(fn)
	-- (In the tram the game says nowhere, and the far door is still where it lands.)
	local there = (W.continent or ns.Carried()) and Landing()
	if not there then return fn() end
	for _, field in ipairs(FIELDS) do real[field], W[field] = W[field], there[field] end
	W.aloft = true
	local ok, err = pcall(fn)
	for _, field in ipairs(FIELDS) do W[field] = real[field] end
	W.aloft = nil
	if not ok then error(err, 0) end
end

-- Yards between two world positions.
function W.Between(north1, west1, north2, west2)
	local dn, dw = north1 - north2, west1 - west2
	return math.sqrt(dn * dn + dw * dw)
end

-- Yards from the player to a map position; nil across continents or when the player is unknown.
function W.Distance(map, x, y)
	if not W.continent then return nil end
	local continent, north, west = W.ToWorld(map, x, y)
	if continent ~= W.continent then return nil end
	return W.Between(W.north, W.west, north, west)
end

-- How far a place is over the ground
--
-- A straight line says little about how far a place is: a mountain or a river may lie between.
-- ShyWay keeps the ground (Shy.Way) and says how long the way round takes; here that is turned
-- into yards of running, to measure against everything else that is in yards. Where the ground isn't
-- known, or the way is still being worked out (SHY_TERRAIN says when it is), it is the straight line.
local RUN = 7                -- yards a second on foot
local CLOSE = 60             -- yards: nearer than this the straight line is all that is asked (a node of ground is 33)
local REACH = 4000           -- ... and farther than this too: that is a flight, or a walk reckoned as before
local ROUND = 0.94           -- a way over nodes of ground is this much of what it adds up to (it steps where one walks straight)
local SNAP = 25              -- ... less this many yards: both its ends are taken from the node they are in

-- Yards a way of so many seconds is worth: never under the straight line, and with no leap between
-- the two (a number that jumps as the player walks reads as broken).
local function Worth(straight, seconds)
	return math.max(straight, seconds * RUN * ROUND - SNAP)
end

-- Yards of running between two places on a continent, and whether the ground said so (false: it is
-- the straight line, for want of anything better).
-- A build's share of the ground (W.Budgeted): every errand and stop asks the ground how far it is, and a
-- place not asked before may begin a search and unpack its ground then and there. Past ASK_MS of that in
-- one build, the rest go by the straight line this time; the searches begun go on in the ground's own
-- frames, and the next build finds them answered.
W.ASK_MS = 6
W.ASK_NEAR = 1200   -- yards (straight): in a build, farther than this is reckoned by the straight line, never asked
function W.Spare(straight)
	if not W.asking then return true end
	if straight and straight > W.ASK_NEAR then return false end
	return debugprofilestop() < W.askUntil
end
function W.Budgeted(fn)
	W.asking, W.askUntil = true, debugprofilestop() + W.ASK_MS
	local ok, err = pcall(fn)
	W.asking, W.askUntil = nil, nil
	if not ok then error(err, 0) end
end

function W.Walked(continent, north, west, toNorth, toWest)
	local straight = W.Between(north, west, toNorth, toWest)
	if straight < CLOSE then return straight, true end
	if straight > REACH or not W.Spare(straight) then return straight, false end
	local seconds, state, least = Shy.Way.Ask(continent, north, west, toNorth, toWest)
	seconds = seconds or (state == "far" and least) or nil
	if not seconds then return straight, false end
	return Worth(straight, seconds), true
end

-- Yards of running from the player to a map position; nil as W.Distance.
function W.Walk(map, x, y)
	if not W.continent then return nil end
	local continent, north, west = W.ToWorld(map, x, y)
	if continent ~= W.continent then return nil end
	return (W.Walked(continent, W.north, W.west, north, west))
end

-- Yards of running from the player to a world position on their continent.
function W.WalkTo(north, west)
	return (W.Walked(W.continent, W.north, W.west, north, west))
end

-- The way to walk
-- The way over the ground from the player to a place: ShyWay's trail to it (Shy.Way.Trail), the one way
-- the world map, the minimap and the arrow all show, each what of it is in sight. Walking along it only
-- moves which of its points is next; another is found only where ShyWay says one is needed.
--   W.Way(continent, north, west [, level, up]) -> way, at: the way ({ seconds =, yards =, n = points,
--   [1] = north, [2] = west, [3] = swum, ... }, a point wherever it turns) and the point of it the player
--   walks toward. nil and "working" while the first is worked out; nil where the ground knows none.
--   level, up: where the place has floors on more than one level, the one to lead to (W.Prefer).
function W.Way(continent, north, west, level, up)
	if continent ~= W.continent then return nil end
	local fromNorth, fromWest = W.Here()
	return Shy.Way.Trail(continent, fromNorth, fromWest, north, west, level, up)
end

-- Which way to go now
-- An arrow points along the way the maps draw, not through what lies between: at the point LOOK yards
-- on along it from where the player is, so it comes round a bend as the bend comes near. Only the trail
-- already kept is read (Shy.Way.Trailed), so pointing asks the ground nothing.
local LOOK = 15              -- yards along the way an arrow points at
local GLIDE = 10             -- an arrow comes round to a new bearing at this share a second (a new way, a bend)
local here = {}               -- the lead's bearing as last worked out (W.Heading)

-- The player's world position this frame (W.north and W.west are the last pulse's): the core's reading
-- (Shy.Here), which the minimap, the card and the arrows share. Off the pulse's continent (a landing the route
-- is being worked out from, a continent just left) it is the pulse's.
function W.Here()
	local continent, north, west = Shy.Here()
	if north and continent == W.continent then return north, west end
	return W.north, W.west
end

-- The point `yards` on along a way from where someone at north, west stands by it (the nearest point
-- of the stretch that ends at its point `at`): north, west, the way's point it lies before, and whether
-- the way ran out first (then it is the way's last point).
function W.Ahead(way, at, north, west, yards)
	at = math.max(2, math.min(at, way.n))
	local an, aw = way[at * 3 - 5], way[at * 3 - 4]
	local dn, dw = way[at * 3 - 2] - an, way[at * 3 - 1] - aw
	local whole = dn * dn + dw * dw
	local share = whole > 0 and math.max(0, math.min(1, ((north - an) * dn + (west - aw) * dw) / whole)) or 1
	local fromNorth, fromWest = an + dn * share, aw + dw * share
	local left, point = yards, at
	while true do
		local toNorth, toWest = way[point * 3 - 2], way[point * 3 - 1]
		local length = math.sqrt((toNorth - fromNorth) ^ 2 + (toWest - fromWest) ^ 2)
		if length >= left then
			local t = length > 0 and left / length or 0
			return fromNorth + (toNorth - fromNorth) * t, fromWest + (toWest - fromWest) * t, point, false
		end
		if point >= way.n then return toNorth, toWest, point, true end
		left = left - length
		fromNorth, fromWest = toNorth, toWest
		point = point + 1
	end
end

-- How to turn an up-pointing arrow (radians, as W.Turn) for a world position: along the way kept to it,
-- then straight at it; nil when the player's whereabouts or facing aren't known, or it is on another
-- continent. With no way kept the two are the same.
--   keep: a table the caller keeps for one arrow, so it comes round to a new bearing instead of leaping.
--   elapsed: seconds since that arrow was last turned.
function W.Heading(continent, north, west, keep, elapsed)
	local facing = GetPlayerFacing()
	if not (facing and north and W.continent and continent == W.continent) then return nil end
	local fromNorth, fromWest = W.Here()
	-- (The card's arrow, the head's and the arrow's own point at the one lead: its bearing from where the player
	-- is this frame is worked out for the first of them, and the same for the rest.)
	local now = GetTime()
	local straight, bearing
	if here.aimAt == now and here.aimNorth == north and here.aimWest == west and here.aimFromNorth == fromNorth and here.aimFromWest == fromWest then
		straight, bearing = here.aimStraight, here.aimBearing
	else
		straight = math.atan2(west - fromWest, north - fromNorth)
		bearing = straight
		local way, at = Shy.Way.Trailed(continent, north, west, fromNorth, fromWest)
		if way then
			local toNorth, toWest, _, ended = W.Ahead(way, at, fromNorth, fromWest, LOOK)
			-- (The end of a whole way is the place itself: straight at it from there.)
			if not ended or way.cut then bearing = math.atan2(toWest - fromWest, toNorth - fromNorth) end
		end
		here.aimAt, here.aimNorth, here.aimWest, here.aimFromNorth, here.aimFromWest = now, north, west, fromNorth, fromWest
		here.aimStraight, here.aimBearing = straight, bearing
	end
	if keep then
		if keep.bearing and keep.north == north and keep.west == west and elapsed then
			local turn = (bearing - keep.bearing + math.pi) % (2 * math.pi) - math.pi
			bearing = keep.bearing + turn * math.min(1, elapsed * GLIDE)
		end
		keep.bearing, keep.north, keep.west = bearing, north, west
	end
	return bearing - facing, straight - facing
end

-- A record's places as the ground is asked for them: every point on the player's continent, with the
-- place and the point each is.
local goalsOf = setmetatable({}, { __mode = "k" })
local function Goals(places)
	local kept = goalsOf[places]
	if not kept or kept.continent ~= W.continent then
		kept = { continent = W.continent, goals = {}, places = {}, at = {} }
		local count = 0
		for _, place in ipairs(places) do
			local points = place.points
			for i = 1, #points, 2 do
				local continent, north, west = W.ToWorld(place.map, points[i], points[i + 1])
				if continent == W.continent then
					count = count + 1
					kept.goals[count * 2 - 1], kept.goals[count * 2] = north, west
					kept.places[count], kept.at[count] = place, i
				end
			end
		end
		goalsOf[places] = kept
	end
	return kept
end

-- Hysteresis for "nearest place": a choice is kept per key until another is clearly nearer,
-- so pins and lines don't flip between two places that are about as far away.
local STEADY = 0.6           -- another place wins once it is under this fraction of the kept one's distance
local kept, keeping = {}, 0

-- The place kept under `key`: { map, x, y, ... }, or nil.
function W.Kept(key)
	return kept[key]
end

-- Picks `best` (nearest now) or `was` (the kept place, re-measured; nil if gone) and keeps the pick.
--   arrive: yards; the kept place holds until the player is this close to another one.
--   keep: yards; the kept place holds while the player is within this of it.
function W.Steady(key, best, was, arrive, keep)
	if best and was and best.yards and was.yards then
		if keep and was.yards <= keep then
			best = was
		elseif arrive then
			if best.yards > arrive then best = was end
		elseif best.yards >= was.yards * STEADY then
			best = was
		end
	end
	if best then
		if not kept[key] then
			if keeping > 2000 then
				wipe(kept)
				keeping = 0
			end
			keeping = keeping + 1
		end
		kept[key] = best
	end
	return best
end

-- The closest of a record's places: map, x, y, yards, dungeon. Falls back to the first place, no distance.
-- Closest over the ground where that is known (above): the quickest reached, in yards of running.
--   key: optional W.Steady key, for a choice that is made repeatedly.
function W.Nearest(places, key)
	local hold = key and kept[key]
	local bestMap, bestX, bestY, bestYards, bestDungeon
	local wasYards, wasDungeon
	-- (Over the points as they lie on this continent, worked out once a record, Goals: every errand and every
	-- objective's every spawn is weighed at each build, and a point's place asked of its map each time was most
	-- of that.)
	local all = W.continent and Goals(places)
	if all then
		local goals, north, west = all.goals, W.north, W.west
		local least, nearest
		for at = 1, #all.places do
			local dn, dw = goals[at * 2 - 1] - north, goals[at * 2] - west
			local apart = dn * dn + dw * dw
			if not least or apart < least then least, nearest = apart, at end
			if hold then
				local place, i = all.places[at], all.at[at]
				if hold.map == place.map and hold.x == place.points[i] and hold.y == place.points[i + 1] then
					wasYards, wasDungeon = math.sqrt(apart), place.dungeon
				end
			end
		end
		if nearest then
			local place, i = all.places[nearest], all.at[nearest]
			bestMap, bestX, bestY, bestYards, bestDungeon = place.map, place.points[i], place.points[i + 1], math.sqrt(least), place.dungeon
		end
	end
	if bestYards and bestYards >= CLOSE and bestYards <= REACH and W.Spare(bestYards) then
		local seconds, goal, least = Shy.Way.Ask(W.continent, W.north, W.west, all.goals)
		if seconds then
			local place, i = all.places[goal], all.at[goal]
			bestMap, bestX, bestY, bestDungeon = place.map, place.points[i], place.points[i + 1], place.dungeon
			bestYards = Worth(W.Distance(bestMap, bestX, bestY), seconds)
		elseif goal == "far" then
			bestYards = math.max(bestYards, least * RUN)
		end
		-- The kept place is held against it by the same measure.
		if wasYards then
			local same = hold.map == bestMap and hold.x == bestX and hold.y == bestY
			wasYards = same and bestYards or W.Walk(hold.map, hold.x, hold.y)
		end
	end
	if key and bestMap then
		local chosen = W.Steady(key, { map = bestMap, x = bestX, y = bestY, yards = bestYards, dungeon = bestDungeon },
			wasYards and { map = hold.map, x = hold.x, y = hold.y, yards = wasYards, dungeon = wasDungeon })
		return chosen.map, chosen.x, chosen.y, chosen.yards, chosen.dungeon
	end
	if not bestMap then
		for _, place in ipairs(places) do
			if place.points[1] then
				return place.map, place.points[1], place.points[2], nil, place.dungeon
			end
		end
	end
	return bestMap, bestX, bestY, bestYards, bestDungeon
end

-- Rotation (radians, CCW, as Texture:SetRotation takes) for an up-pointing arrow to aim at a world position.
function W.Turn(north, west)
	local facing = GetPlayerFacing()
	if not facing or not W.continent then return nil end
	-- Facing is 0 looking north and grows turning left, like this bearing.
	return math.atan2(west - W.west, north - W.north) - facing
end

-- "240 yd", "1.2k yd".
function W.Yards(yards)
	if not yards then return "" end
	if yards >= 1000 then return ("%.1fk yd"):format(yards / 1000) end
	return ("%d yd"):format(math.floor(yards + 0.5))
end

-- The level a place is on
-- The ground has floors (Shy.Way): a mine under a hill, a hall's upper storey. A stop that isn't
-- simply on the ground says so beside its distance, and its trail shows it (Pins.lua).
local NEAR_LEVEL = 800       -- yards: farther off than this a stop's level isn't asked (its ground isn't unpacked for a word)
local KNOWN_NEAR = 25        -- yards: a stop is on the floor of the nearest place known to stand on one, this near
local SQUARE = 64            -- yards: the known places are kept by squares this size
local levels, levelCount = {}, 0
local known = {}             -- [world] = { [square] = { north, west, level, ... } }, or false for none

-- The places known to stand on one floor of several (Data/Levels.lua: exact heights, held against the
-- floors), by square, read on first use.
local function KnownOf(world)
	local squares = known[world]
	if squares == nil then
		local text = ns.data and ns.data.levels and ns.data.levels[world]
		squares = false
		if text then
			squares = {}
			for at = 1, #text - 10, 11 do
				local north, west = tonumber(text:sub(at, at + 4)) - 20000, tonumber(text:sub(at + 5, at + 9)) - 20000
				local square = math.floor(north / SQUARE) * 1024 + math.floor(west / SQUARE)
				local list = squares[square] or {}
				squares[square] = list
				list[#list + 1], list[#list + 2], list[#list + 3] = north, west, tonumber(text:sub(at + 10, at + 10))
			end
		end
		known[world] = squares
	end
	return squares
end

-- The heights known in a world (Data/Levels.lua's heights), by square, read on first use: four numbers a
-- point (north, west, the height, the level of the floor that high); false for none.
local tall = {}
local function Heights(world)
	local squares = tall[world]
	if squares == nil then
		local text = ns.data and ns.data.heights and ns.data.heights[world]
		squares = false
		if text then
			squares = {}
			for at = 1, #text - 15, 16 do
				local north, west = tonumber(text:sub(at, at + 4)) - 20000, tonumber(text:sub(at + 5, at + 9)) - 20000
				local square = math.floor(north / SQUARE) * 1024 + math.floor(west / SQUARE)
				local list = squares[square] or {}
				squares[square] = list
				local n = #list
				list[n + 1], list[n + 2], list[n + 3], list[n + 4] = north, west, tonumber(text:sub(at + 10, at + 14)) - 20000, tonumber(text:sub(at + 15, at + 15))
			end
		end
		tall[world] = squares
	end
	return squares
end

-- The height a stop stands at, where floors stand over each other there (the top of a tower, not the hall
-- at its foot); nil where none is known within HEIGHT_NEAR yards (or `reach`). Then the level of the floor
-- that high (0 the ground, 1 under it, 2 a level up: Shy.Way's own numbers), and how far off it was told
-- (yards, squared). on: only the heights of floors on that level.
local HEIGHT_NEAR = 6
function W.Height(stop, reach, on)
	if not stop.north or not stop.continent then return nil end
	local squares = Heights(stop.continent)
	if not squares then return nil end
	local north, west = stop.north, stop.west
	local row, col = math.floor(north / SQUARE), math.floor(west / SQUARE)
	local near = reach or HEIGHT_NEAR
	local best, look, least = nil, nil, near * near
	for dr = -1, 1 do
		for dc = -1, 1 do
			local list = squares[(row + dr) * 1024 + col + dc]
			for at = 1, list and #list or 0, 4 do
				local far = (list[at] - north) ^ 2 + (list[at + 1] - west) ^ 2
				if far <= least and (on == nil or list[at + 3] == on) then best, look, least = list[at + 2], list[at + 3], far end
			end
		end
	end
	return best, look, least
end

-- For the ground, when it first sees someone where floors stand over each other and the game says nothing
-- of which they are on: the height most of what is known to stand round them stands at (within GUESS_SAME
-- yards of each other; of two as many, the nearer). In Tinker Town that is the halls', not the peak's over
-- them (the game calls Ironforge outdoors). The most, not the nearest: where the halls have fifty spawns,
-- one thing on the mountain's top a few yards off on the map put whoever logged in under it on the peak.
local GUESS_NEAR = 60        -- yards (the squares searched reach some 64)
local GUESS_SAME = 15        -- yards of height: known heights this near each other are one floor's
local guessed = {}
if Shy.Way.SetGuess then
	Shy.Way.SetGuess(function(world, north, west)
		local squares = Heights(world)
		if not squares then return nil end
		local row, col = math.floor(north / SQUARE), math.floor(west / SQUARE)
		local n = 0
		for dr = -1, 1 do
			for dc = -1, 1 do
				local list = squares[(row + dr) * 1024 + col + dc]
				for at = 1, list and #list or 0, 4 do
					local far = (list[at] - north) ^ 2 + (list[at + 1] - west) ^ 2
					if far <= GUESS_NEAR * GUESS_NEAR then
						guessed[n + 1], guessed[n + 2] = list[at + 2], far
						n = n + 2
					end
				end
			end
		end
		local best, most, least
		for i = 1, n, 2 do
			local height, count = guessed[i], 0
			for j = 1, n, 2 do
				if math.abs(guessed[j] - height) <= GUESS_SAME then count = count + 1 end
			end
			if not best or count > most or (count == most and guessed[i + 1] < least) then
				best, most, least = height, count, guessed[i + 1]
			end
		end
		return best
	end)
end

-- What you said of a place (W.Learn): kept for the account (ShyQuestDB.floors, by world: north, west and
-- the level, three numbers a place), by square, read on first use. A stop within SAID_NEAR yards of one
-- stands as you said, whatever the data or the floors say: the nearest.
local SAID_NEAR = 10
local said
local function Said(stop)
	local db = ns.T and ns.T.db
	local floors = db and db.floors
	if not floors or not stop.north or not stop.continent then return nil end
	if not said then
		said = {}
		for world, list in pairs(floors) do
			local squares = {}
			said[world] = squares
			for at = 1, #list - 2, 3 do
				local square = math.floor(list[at] / SQUARE) * 1024 + math.floor(list[at + 1] / SQUARE)
				local into = squares[square] or {}
				squares[square] = into
				local n = #into
				into[n + 1], into[n + 2], into[n + 3] = list[at], list[at + 1], list[at + 2]
			end
		end
	end
	local squares = said[stop.continent]
	if not squares then return nil end
	local north, west = stop.north, stop.west
	local row, col = math.floor(north / SQUARE), math.floor(west / SQUARE)
	local best, least = nil, SAID_NEAR * SAID_NEAR
	for dr = -1, 1 do
		for dc = -1, 1 do
			local list = squares[(row + dr) * 1024 + col + dc]
			for at = 1, list and #list or 0, 3 do
				local far = (list[at] - north) ^ 2 + (list[at + 1] - west) ^ 2
				if far <= least then best, least = list[at + 2], far end
			end
		end
	end
	return best
end

-- The floor what is at a stop is known to stand on: "ground", "under" or "above", as the nearest known
-- place within KNOWN_NEAR yards has it; nil where none is known, or the nearest are as near and differ.
-- The nearest, not the most: each spawn is known where it stands (Data/Levels.lua), and the trainers in a
-- cave are no word on the scorpids on the hill over it. Then how far off it was told (yards, squared).
-- ("none": it stands on no floor that is known, over the roof of what is. The way there is not known.)
local KNOWN_WORDS = { [0] = "ground", "under", "above", "none" }
local KNOWN_LOOKS = { ground = 0, under = 1, above = 2, none = 3 }
local function Known(stop)
	local squares = KnownOf(stop.continent)
	if not squares then return nil end
	local north, west = stop.north, stop.west
	local row, col = math.floor(north / SQUARE), math.floor(west / SQUARE)
	local best, least, tied = nil, KNOWN_NEAR * KNOWN_NEAR, false
	for dr = -1, 1 do
		for dc = -1, 1 do
			local list = squares[(row + dr) * 1024 + col + dc]
			for at = 1, list and #list or 0, 3 do
				local far = (list[at] - north) ^ 2 + (list[at + 1] - west) ^ 2
				if far < least then
					best, least, tied = list[at + 2], far, false
				elseif far == least and best ~= nil and list[at + 2] ~= best then
					tied = true
				end
			end
		end
	end
	if tied or not best then return nil end
	return KNOWN_WORDS[best], least
end

-- What is kept of a stop's level: "ground", "under" or "above" where it is known; "under?" where the
-- floors have ground over a cave; "under", "above" or false as the floors alone have it; nil not asked.
-- any: the floors are asked however far the stop is. The way there is asked for (W.Prefer), and that
-- unpacks its ground anyway: a far stop with no known level would be led to the quickest floor (the top
-- of Ironforge's mountain for its gryphon master) until the player came near enough to ask.
local function LevelOf(stop, any)
	if not stop.north or not stop.continent then return nil end
	local key = stop.continent .. ":" .. math.floor(stop.north) .. ":" .. math.floor(stop.west)
	local level = levels[key]
	if level == nil then
		-- (What you said of it first; then what is known to stand there.)
		level = KNOWN_WORDS[Said(stop) or -1] or Known(stop)
		if not level then
			local far = not stop.yards or stop.yards > NEAR_LEVEL
			if far and not any then return nil end
			-- (Far, and that world's ground not held yet: nothing to say, and nothing kept, so it is asked again.)
			if far and not Shy.Way.Has(stop.continent) then return nil end
			local onGround, under, above = Shy.Way.Levels(stop.continent, stop.north, stop.west)
			level = under and (onGround and "under?" or "under") or (above and not onGround) and "above" or false
		end
		if levelCount > 300 then
			wipe(levels)
			levelCount = 0
		end
		levels[key] = level
		levelCount = levelCount + 1
	end
	return level
end

-- "under" (under ground) or "above" (a level up) for a stop that isn't on the ground, nil for one that
-- is or whose ground isn't known. Then true where it may as well be on the ground: a place has no
-- height, and there is ground over a mine, and nothing there is known to stand on one or the other.
function W.Level(stop, any)
	local level = LevelOf(stop, any)
	-- (A dungeon's way in with ground over it is the one under it: the hall or the deep stair, never
	-- the hillside on top.)
	if level == "under?" then return "under", not stop.dungeon end
	if level == "ground" then return nil end
	return level or nil
end

-- A stop's distance: "240 yd". (Its level, under ground or up a level, is said in words where there is room for
-- them: W.LevelWords, on its hover. A mark before the distance read as a way to go.)
function W.Far(stop)
	return W.Yards(stop.yards)
end

-- The level to lead to at a stop that has floors on more than one: the one what is there is known to
-- stand on; under ground for what is fought or gathered where there is a cave under the spot (a camp keeps
-- to its cave), and for anything that is only under ground; a level up where that is all there is; else
-- nil, the quickest. Then the height it stands at, where that is known (W.Height): the way's `up`.
-- Kept PREFER_KEPT seconds for a stop where it stands: the minimap, the map and the arrow each ask it of the
-- stop that leads at every frame, and it is read off the data's squares each time.
-- A level and a height are each told by the nearest thing known, and those may be two things on two floors
-- (someone in a hall, and something on the mountain over it a few yards off on the map): a height whose
-- floor is on another level than the stop is known to stand on is the stop's only where it was told nearer
-- than the level was, and then the level is that floor's. What you said of a stop (W.Learn) is its level,
-- and a height counts only on that level.
local preferred = setmetatable({}, { __mode = "k" })   -- stop -> { at, north, west, level, up }
local PREFER_KEPT = 1
local function Preferred(stop)
	local ground = Shy.Way
	local mine = Said(stop)
	if mine then return mine, (W.Height(stop, nil, mine)) end
	local up, look, far = W.Height(stop)
	if up and look then
		local told, toldFar = Known(stop)
		if told and KNOWN_LOOKS[told] ~= look then
			-- (The level was told nearer: the nearest height on that level, if any is as near as a height counts.)
			if toldFar <= far then up = W.Height(stop, nil, KNOWN_LOOKS[told]) else return look, up end
		end
	end
	local level, maybe = W.Level(stop, true)
	-- (On no floor that is known: the ground is told so, and knows no way there. The straight line leads.)
	if level == "none" then return KNOWN_LOOKS.none, nil end
	if not level then return LevelOf(stop, true) == "ground" and ground.GROUND or nil, up end
	if level == "under" and (not maybe or stop.kind == "goal") then return ground.UNDER, up end
	if level == "above" then return ground.ABOVE, up end
	return nil, up
end
function W.Prefer(stop)
	local kept, now = preferred[stop], GetTime()
	if kept and now - kept.at < PREFER_KEPT and kept.north == stop.north and kept.west == stop.west and kept.kind == stop.kind then
		return kept.level, kept.up
	end
	if not kept then
		kept = {}
		preferred[stop] = kept
	end
	kept.at, kept.north, kept.west, kept.kind = now, stop.north, stop.west, stop.kind
	kept.level, kept.up = Preferred(stop)
	return kept.level, kept.up
end

-- The same in words, for where there is room: "underground", "maybe underground", "up a level".
function W.LevelWords(stop)
	local level, maybe = W.Level(stop)
	if level == "under" then return maybe and "maybe underground" or "underground" end
	if level == "above" then return "up a level" end
end

-- Which floor a stop is led to, for whoever shows it and lets it be put right (the card's menu):
--   W.Floor(stop) -> look, how   look: 0 the ground, 1 under it, 2 a level up, nil for whichever is reached
--        the quickest; how: "said" (you said so), "known" (what stands there is known to), "guess" (the
--        floors there are on more than one level, or over each other, and nothing says which); nil, nil
--        where there is one floor and no question
--   W.Learn(stop, look)          from now on what is at that place (within SAID_NEAR yards) stands on that
--        level; nil: forget what you said there. Kept for the account, and the way is found again.
function W.Floor(stop)
	if not stop.north or not stop.continent then return nil end
	local mine = Said(stop)
	if mine then return mine, "said" end
	local level, up = W.Prefer(stop)
	if Known(stop) then return level, "known" end
	if level ~= nil or up ~= nil or LevelOf(stop, true) then return level, "guess" end
	return nil
end

function W.Learn(stop, look)
	local db = ns.T and ns.T.db
	if not db or not stop.north or not stop.continent then return end
	db.floors = db.floors or {}
	local kept = {}
	local list = db.floors[stop.continent] or kept
	for at = 1, #list - 2, 3 do
		if (list[at] - stop.north) ^ 2 + (list[at + 1] - stop.west) ^ 2 > SAID_NEAR * SAID_NEAR then
			local n = #kept
			kept[n + 1], kept[n + 2], kept[n + 3] = list[at], list[at + 1], list[at + 2]
		end
	end
	if look then
		local n = #kept
		kept[n + 1], kept[n + 2], kept[n + 3] = math.floor(stop.north * 10 + 0.5) / 10, math.floor(stop.west * 10 + 0.5) / 10, look
	end
	db.floors[stop.continent] = #kept > 0 and kept or nil
	-- (Everything worked out from the old answer is worked out again.)
	said = nil
	wipe(levels)
	levelCount = 0
	wipe(preferred)
	if ns.Refresh then ns.Refresh() end
end

function W.MapName(map)
	local info = map and C_Map.GetMapInfo(map)
	return info and info.name or nil
end
