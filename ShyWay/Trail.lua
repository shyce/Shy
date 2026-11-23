-- Shy.Way trails: the one way from the player to a place, for every addon that draws it or points along
-- it. The world map, the minimap and an arrow all show the same way; each shows what of it is in sight.
--
-- A trail is asked of the ground once and kept. Walking along it changes only which of its points is
-- next: what is behind is not drawn, and the line runs from the player to that point and on. It is asked
-- again only when it must be:
--   the player is STRAY yards off it (another way round, or carried off);
--   the stretch of it found floor by floor (its beginning: stairs, doors, the way round a counter) is
--   nearly walked: the way on is found floor by floor again, from where the player was then, so what lies
--   ahead stays as exact as what lay behind (a trail with no such stretch is kept as it is: asked again
--   every few steps, it would turn under the player's feet);
--   it ends short of the place (on the node the place is in, not on the place's floor) and its end is
--   near: the last yards are found floor by floor;
--   it is rough (nothing was found floor by floor where it was asked, where the floors are known: just off
--   a flight in a city, it ran through walls): asked again at every AGAIN yards until they are found;
--   it leads to another place, or to another level or height of it (another trail, kept beside it);
--   what is left of it is well longer than the way from where the player stands now (asked from
--   elsewhere and walked off at a shortcut, found while keeping to roads, a level since gained): looked
--   at every SHORTER_EVERY seconds, from AGAIN yards off where it was asked.
-- Never again within AGAIN yards of walking. While another is worked out the kept one is the answer, whole
-- and unchanged, and the new one takes its place only once it is found. However near the place, the ground
-- is asked: someone right under a tower's top is still a ramp away from it.
--
--   Shy.Way.Trail(world, north, west, toNorth, toWest [, level, up]) -> way, at, state
--        the way from (north, west), where the player stands now, to (toNorth, toWest), as AskWay's
--        (level, up: as AskWay's too), and `at`, the point of it they walk toward (2 or later).
--        nil, "working" while the first is worked out; nil where the ground knows no way (a straight line
--        is the answer then: on the place itself, or ground not known)
--   Shy.Way.Trailed(world, toNorth, toWest, north, west) -> way, at   the trail last asked for to that
--        place, nothing asked of the ground (whoever only reads it: an arrow); nil where none is kept or
--        the player at (north, west) is off it
--   Shy.Way.Trailing(world, toNorth, toWest) -> true while the first trail to that place is still being
--        found and there's no line to show yet. A trail being replaced has its old line, so it's false then.
--        Nothing is asked of the ground
--   Shy.Way.Along(way, at, north, west) -> at, off   which of a way's points someone walks toward, from
--        the one they walked toward before, and how many yards off the way they are

local T = Shy.Way

local STRAY = 60             -- yards off a trail before another is asked for
local FINE_LEFT = 40         -- yards of its floor-by-floor beginning still ahead, under which the way on is found again
local SHORT = 4              -- yards: a trail ending further than this from the place ends short of it ...
local SHORT_LEFT = 60        -- ... and is asked again once its end is nearer than this
local NEAR_END = 45          -- yards left on a way already found: not asked again. The place is in sight,
                             -- and asking the ground again every few steps hitches a walk around it.
local AGAIN = 20             -- yards from where a trail was asked for before it is asked again (but for straying)
local AHEAD = 4              -- stretches a player may get on in one look (a way has many short ones where the ground is tight)
local CUT = 2                -- yards nearer the next stretch than this one: the corner between them has been cut
local KEPT = 60              -- places trails are kept to
local FOLLOW = 8             -- yards past what was walked since the last look that a trail is looked along for the stretch walked on
-- A new way replaces the trail when it's quicker by both of these. The estimates drift up to 6 seconds
-- apart even when you're on the trail, so the seconds bar sits above that.
local SHORTER = 1.05         -- times as quick
local SHORTER_BY = 7         -- seconds quicker
local SHORTER_EVERY = 1      -- seconds between two looks for a shorter way
local places, count = {}, 0  -- by place: { [level and height] = trail, last = the trail asked for last }

-- Yards from a place to the stretch of a way that ends at its point `to`, and how far along that
-- stretch the place is (0 at its start, 1 at its end; under or over when before or past it).
local function Stretch(way, to, north, west)
	local an, aw = way[to * 3 - 5], way[to * 3 - 4]
	local dn, dw = way[to * 3 - 2] - an, way[to * 3 - 1] - aw
	local whole = dn * dn + dw * dw
	local share = whole > 0 and ((north - an) * dn + (west - aw) * dw) / whole or 1
	local held = math.max(0, math.min(1, share))
	return math.sqrt((north - an - dn * held) ^ 2 + (west - aw - dw * held) ^ 2), share
end

-- A way is walked from one end to the other: someone is on to the next stretch once past the end of this
-- one, or plainly on the next (a corner cut). Never by being near some later stretch, and never back to an
-- earlier one: a way that doubles back or winds up a tower passes over itself, and a place has no height
-- to tell its turns apart.
function T.Along(way, at, north, west)
	at = math.max(2, math.min(at, way.n))
	local off, share = Stretch(way, at, north, west)
	for _ = 1, AHEAD do
		if at >= way.n then break end
		local nextOff, nextShare = Stretch(way, at + 1, north, west)
		if not (share >= 1 or (nextShare > 0 and nextOff + CUT < off)) then break end
		at, off, share = at + 1, nextOff, nextShare
	end
	return at, off
end

-- Yards from a place at height `up` to the stretch of a way that ends at its point `to`: as Stretch, the
-- height along the stretch counted where its ends' heights are known.
local function Near(way, to, north, west, up)
	local off, share = Stretch(way, to, north, west)
	local ups = way.up
	local a, b = ups and ups[to - 1], ups and ups[to]
	if not (a or b) then return off end
	local held = math.max(0, math.min(1, share))
	local height = (a and b) and (a + (b - a) * held) or a or b
	return math.sqrt(off * off + (up - height) ^ 2)
end

-- Which of a kept trail's points the player at (north, west) walks toward, and how far off it they are: as
-- T.Along, and where the height of the floor they are on is known (Shy.Way.Up), on to the stretch nearest
-- them counting height among those no further along than they walked since the last look. A stair that
-- winds up a tower passes over itself: on the map its turns are one, in height they are yards apart, so
-- someone who climbed a turn between two looks is on the turn they climbed to, not led back down to the one
-- under it.
local function Follow(trail, world, north, west)
	local way = trail.way
	local at, off = T.Along(way, trail.at, north, west)
	local up = T.Up(world)
	-- (Asked every frame by every map: two tables, taken in turn.)
	local was, seen = trail.seen, trail.spare or {}
	trail.spare = was
	seen.north, seen.west, seen.up = north, west, up
	trail.seen = seen
	if not (up and was and was.up) then return at, off end
	-- (How far they came, the height climbed counted; a stair's turns are longer than the line across them,
	-- by half again at the most, so twice that is looked along.)
	local moved = math.sqrt((north - was.north) ^ 2 + (west - was.west) ^ 2 + (up - was.up) ^ 2)
	local best, nearest = at, Near(way, at, north, west, up)
	for to = at + 1, way.n do
		if trail.yards[to - 1] - trail.yards[at - 1] > 2 * moved + FOLLOW then break end
		local yards = Near(way, to, north, west, up)
		if yards + CUT < nearest then best, nearest = to, yards end
	end
	if best == at then return at, off end
	-- (On from it as Along goes on: at the end of the stretch found, toward the next point.)
	return T.Along(way, best, north, west)
end

-- A trail found: kept with the yards along it to each point; how much of its beginning was found floor by
-- floor (fine: its last point; "none", or "all" for a way found so all through); and how far its end is
-- from the place.
local function Keep(trail, way, north, west, toNorth, toWest)
	local yards = { [1] = 0 }
	for point = 2, way.n do
		yards[point] = yards[point - 1] + math.sqrt((way[point * 3 - 2] - way[point * 3 - 5]) ^ 2 + (way[point * 3 - 1] - way[point * 3 - 4]) ^ 2)
	end
	local fine = 1
	while way.fine and fine < way.n and way.fine[fine + 1] do fine = fine + 1 end
	trail.fine = fine >= way.n and "all" or fine < 2 and "none" or fine
	trail.short = math.sqrt((way[way.n * 3 - 2] - toNorth) ^ 2 + (way[way.n * 3 - 1] - toWest) ^ 2) > SHORT
	trail.way, trail.yards, trail.north, trail.west, trail.at = way, yards, north, west, 2
	trail.lookedNorth = nil   -- (another way: looked at for a shorter one afresh, Longer)
end

-- Yards along the trail from someone at (north, west) walking toward `at` to its point `to`.
local function Left(trail, at, north, west, to)
	if at > to then return 0 end
	local way = trail.way
	return trail.yards[to] - trail.yards[at] + math.sqrt((way[at * 3 - 2] - north) ^ 2 + (way[at * 3 - 1] - west) ^ 2)
end

-- Whether a kept trail, walked to `at`, is to be asked again (off it, or more of it to be found floor by floor).
local function Stale(trail, at, off, north, west)
	if off > STRAY then return true end
	if (north - trail.north) ^ 2 + (west - trail.west) ^ 2 < AGAIN * AGAIN then return false end
	-- (Rough: nothing was found floor by floor where it was asked, and it runs through walls. From a little
	-- further on the floors may well be found: asked again at every AGAIN yards until they are.)
	if trail.rough then return true end
	local left = Left(trail, at, north, west, trail.way.n)
	-- (But for one ending short of the place: its last yards are asked for once. A place the ground can't
	-- reach exactly ends short every time, and asking at every few steps moved the line under the player.)
	local shortOnce = trail.short and not trail.shortAsked
	if left < NEAR_END and off < NEAR_END and not shortOnce then return false end
	local fine = trail.fine
	if type(fine) == "number" and Left(trail, at, north, west, fine) < FINE_LEFT then return true end
	if shortOnce and left < SHORT_LEFT then
		trail.shortAsked = true
		return true
	end
	return false
end

-- Whether a kept trail, walked to `at`, takes well longer than the way from where the player stands now
-- (SHORTER, SHORTER_BY): asked of the ground's kept search, no oftener than SHORTER_EVERY seconds, and
-- never within AGAIN yards of where the trail was asked (it is the way from there).
local function Longer(trail, at, world, north, west, toNorth, toWest, level, up)
	local way = trail.way
	if not (way.seconds and way.yards and way.yards > 0) then return false end
	if (north - trail.north) ^ 2 + (west - trail.west) ^ 2 < AGAIN * AGAIN then return false end
	local now = GetTime()
	if trail.lookedAt and now - trail.lookedAt < SHORTER_EVERY then return false end
	-- (Looked at from this very spot, and answered: standing still, neither what is left of the trail nor the
	-- way from here changes until the ground has news, SHY_TERRAIN below. It was asked every second.)
	if trail.lookedNorth == north and trail.lookedWest == west then return false end
	trail.lookedAt = now
	local left = way.seconds * Left(trail, at, north, west, way.n) / way.yards
	local seconds = T.Ask(world, north, west, toNorth, toWest, level, up)
	if seconds ~= nil then trail.lookedNorth, trail.lookedWest = north, west else trail.lookedNorth = nil end
	return seconds ~= nil and left > seconds * SHORTER and left - seconds > SHORTER_BY
end

-- A place's key. Each caller keeps the last one it made, since the same place is asked about every frame.
local function KeyIn(kept, world, north, west)
	if kept.world == world and kept.north == north and kept.west == west then return kept.key end
	local key = ("%d:%d:%d"):format(world, math.floor(north * 10 + 0.5), math.floor(west * 10 + 0.5))
	kept.world, kept.north, kept.west, kept.key = world, north, west, key
	return key
end
local keyFor = {}
local function PlaceKey(world, north, west) return KeyIn(keyFor, world, north, west) end

-- The kind of a trail to no level or height in particular: kept to no road, or to them as Shy.Way.Roads() says.
local PLAIN, ROADS = "nil:nil", { high = "nil:nil:high", auto = "nil:nil:auto", always = "nil:nil:always" }

function T.Trail(world, north, west, toNorth, toWest, level, up)
	local key = PlaceKey(world, toNorth, toWest)
	local place = places[key]
	if not place then
		if count >= KEPT then
			wipe(places)
			count = 0
		end
		count = count + 1
		place = {}
		places[key] = place
	end
	-- (Kept to the roads or not, a trail of its own: one found otherwise isn't the way.)
	local roads = T.Roads()
	local kind
	if level == nil and up == nil then
		kind = roads and ROADS[roads] or PLAIN
	else
		kind = tostring(level) .. ":" .. tostring(up) .. (roads and ":" .. roads or "")
	end
	local trail = place[kind]
	if not trail then
		trail = {}
		place[kind] = trail
	end
	place.last = trail
	local way = trail.way
	if way then
		local at, off = Follow(trail, world, north, west)
		trail.at = at
		if not trail.asking and (Stale(trail, at, off, north, west) or Longer(trail, at, world, north, west, toNorth, toWest, level, up)) then
			trail.asking = { north = north, west = west }
		end
		if not trail.asking then return way, at end
	elseif not trail.asking then
		-- (Where none was found, not asked again until the player has walked a little.)
		local missed = trail.missed
		if missed and (north - missed.north) ^ 2 + (west - missed.west) ^ 2 < AGAIN * AGAIN then return nil end
		trail.asking = { north = north, west = west }
	end
	-- Asked from where the asking began, however the player moves meanwhile: the search up close goes on
	-- where it was rather than being begun again every step.
	local asking = trail.asking
	local found, state = T.AskWay(world, asking.north, asking.west, toNorth, toWest, nil, level, true, up)
	if state == "working" then
		if way then return way, trail.at end
		return nil, "working"
	end
	trail.asking = nil
	-- (A way of one point is no way: both its ends in one node of ground, and nothing found up close.)
	if found and found.n >= 2 then
		Keep(trail, found, asking.north, asking.west, toNorth, toWest)
		trail.missed, trail.rough = nil, state == "rough" or nil
		trail.at = T.Along(found, 2, north, west)
		return found, trail.at
	end
	-- None found: the one kept stays while the player is on it (asked again only after more walking); else none.
	if way and select(2, T.Along(way, trail.at, north, west)) <= STRAY then
		trail.north, trail.west = north, west
		return way, trail.at
	end
	trail.way, trail.missed = nil, { north = north, west = west }
	return nil
end

function T.Trailed(world, toNorth, toWest, north, west)
	local place = places[PlaceKey(world, toNorth, toWest)]
	local trail = place and place.last
	local way = trail and trail.way
	if not way then return nil end
	local at, off = T.Along(way, trail.at, north, west)
	if off > STRAY then return nil end
	return way, at
end

-- Read every frame while the head speaks, so it only looks at what's kept. Its own key cache keeps it from
-- making a new key each frame or knocking out the maps' cached one.
local keyTrailing = {}
function T.Trailing(world, toNorth, toWest)
	local place = places[KeyIn(keyTrailing, world, toNorth, toWest)]
	local trail = place and place.last
	return trail ~= nil and trail.way == nil and trail.asking ~= nil
end

-- Ways came to be known (SHY_TERRAIN): a trail that ended short of its place may reach it now, and is
-- asked for its last yards once more.
Shy:On("SHY_TERRAIN", function()
	for _, place in pairs(places) do
		for _, trail in pairs(place) do
			if type(trail) == "table" then trail.shortAsked, trail.lookedNorth = nil, nil end
		end
	end
end)
