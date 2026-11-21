-- Shy.Way, on foot: how long it takes to get somewhere over the ground itself, and the way there.
--
-- A straight line says little about how far a place is: a mountain, a river or a cliff may lie
-- between. The ground of each world is kept as nodes, one every 33.33 yards, each with the seconds it
-- takes to reach the eight round it: walked at a runner's pace, swum slower, a cliff come down but not
-- climbed, a wall no link at all (each world's in its own addon, ShyWay_Ground_<world>\Nodes.lua, below). Each node also says where it stands in its body
-- of ground (a continent, an island), so most places with no way between them are known at once.
-- Where a node's ground lies at more than one height (a bridge over a moat, a road over a valley, a city
-- inside the mountain over it) each height is a tier of its own, with its own place and links: to the
-- tiers round it it joins, and to the node's other tiers by a stair. Whoever stands somewhere is on the
-- tier of the floor under them. Where the quickest way between two places goes well round (down a ledge,
-- up a ravine), the points it bends by are kept with the link, and a way is drawn through them, not over
-- the cliff.
--
-- A way is searched from where it ends, toward whoever asks, and the search is kept: asked again from
-- a few yards on, as someone walking there does, it has the answer or is a little short of it. A long
-- search is spread over the frames that follow, never done in one.
--
--   Shy.Way.Has(world)                                     -- is there ground kept for this world
--   Shy.Way.Ask(world, north, west, toNorth, toWest)       -- how long from a place to another
--   Shy.Way.Ask(world, north, west, toNorth, toWest, level, up)   -- ... to the floor on that level, that high (AskWay)
--   Shy.Way.Ask(world, north, west, goals)                 -- ... or to the quickest reached of several
--        -> seconds, goal                 known; goal: which of the goals (1 for the only one)
--        -> nil, "working"                being worked out: SHY_TERRAIN is sent when it is known
--        -> nil, "far", seconds           too long a way to work out: at least that many seconds
--        -> nil                           not known
--        goals: { north, west, north, west, ... }, a table that is kept and not changed afterwards
--   Shy.Way.Ask(world, north, west, toNorth, toWest, level, up, done)   -- ... and where it is "working", done(...)
--        is called once with what asking again gives, as soon as that is anything but "working" (WAIT seconds
--        on at the most): no asking again each frame for it. One function waits once (pass the same one)
--   Shy.Way.AskWay(world, north, west, toNorth, toWest [, reach [, level]])   -- the way itself, as asked above
--   Shy.Way.AskWay(world, north, west, goals, nil [, reach [, level]])
--   Shy.Way.AskWay(world, north, west, toNorth, toWest, reach, level, lead, up [, done])
--        -> way, or nil until it is known (nil, "far": not within the search's reach, not that there is none);
--           then, while it is worked out anew from a few yards on, the
--           way as it was last known and "working"; led along (lead) where the floors are known but
--           nothing was found floor by floor from there, the way over nodes and "rough" (ask again on)
--        lead: the way the player is being led along now (the trail): never refused a search for want
--        of room, and never taken as too far for having been asked from many other places first; and,
--        asked for whole, begun floor by floor from where they stand (as far as a beginning was last
--        asked for), not from their node's place, which may be up a cliff they stand at the foot of
--        reach: only the first so many yards of it (way.cut is true where that stops short of the
--        goal): quick to make, for a minimap that shows no more and asks at every step
--        level: where the goal has floors on more than one level (a cave under a hill), the one to
--        lead to (T.UNDER, T.ABOVE); else the one reached the quickest. A floor beside that place
--        counts only when it stands about as high: the lake under a cliff is not the cliff
--        up: the height in yards the goal stands at, where that is known: of its floors over each other,
--        the one that high (the top of a tower, not the hall at its foot)
--        way = { seconds =, yards =, goal =, n = points, [1] = north, [2] = west, [3] = swum, ... }: three
--        numbers a point, from the first place to the last: one wherever the way turns, either side
--        of a shore, and where it goes under ground or up a level; swum is true where that point is
--        in water. way.look[point]: the level that point is on (T.GROUND, T.UNDER: under ground,
--        T.ABOVE: a level up: a bridge, an upper floor). way.up[point]: its height in yards, where known.
--        way.fine[point]: true where that point is on the floors' own way (found up close, or a bend of a
--        link round a cliff): to be drawn as closely as a way found up close (way.close) is
--   Shy.Way.Seconds(world, north, west, toNorth, toWest [, level, up])   -- as Ask, worked out on the spot
--   Shy.Way.Way(world, north, west, toNorth, toWest)       -- as AskWay, worked out on the spot
--        way.lift[point]: the stretch that ends at that point is a lift's ride
--        way.drop[point]: the stretch that ends at that point is a drop off a cliff, slowed by way.fall (a
--        spell); way.water: the spell water is walked on by, where the way crosses any
--   Shy.Way.Without(world, north, west, toNorth, toWest [, soon])   -- the seconds with no fall slowed and no water walked
--   Shy.Way.With(world, north, west, toNorth, toWest, fall, glide, water [, soon])   -- ... as though so (yards, yards, bool)
--        soon: as Ask (nil and "working" while it is worked out, a frame's share at a time); else on the spot
--   Shy.Way.Moves()                                        -- yards a drop may be now, its spell; water walked, its spell
--   Shy.Way.Paths(), Shy.Way.SetPaths(mode)                -- how this character's ways keep to the roads: "high" (as it
--                                                              -- comes: where what lives off them is 5 levels above them
--                                                              -- or more), "auto" (... is their level or higher), "always",
--                                                              -- "never" (the shortest); near the goal a way leaves them
--   Shy.Way.Roads()                                        -- false where ways don't keep to roads now, else the mode
--   Shy.Way.Up(world)                                      -- the height (yards) of the floor the player is on, as
--                                                              -- followed (T.Saw); nil while not known there
--   Shy.Way.Levels(world, north, west)                    -- the levels there are at a place
--        -> ground, under, above          true for each there is a floor on (nil: nothing is known there)
--   Shy.Way.Water(world, north, west)                      -- true where every floor at a place is swum, false
--                                                              -- where one is walked (a pier, a bridge); nil unknown
--   Shy.Way.Report()                                       -- what is kept and what it cost, as text
--
-- Bus: SHY_TERRAIN (why, world), when something that was being worked out is known, or what ways there are
-- changes: why "found" (ways worked out; world: theirs, where all were of one), "ground" (a world's ground came
-- in), "moves" (a fall slowed, water walked on, dead or alive), "roads" (kept to or not, a level gained),
-- "flights" (a flight point learned). world nil: any.
--
-- world: the game's own number for it (what C_Map.GetWorldPosFromMapPos gives first: 0 the Eastern
-- Kingdoms, 1 Kalimdor). north, west: yards, as that function's vector has them.
--
-- The ground is three-dimensional: the terrain and every building, bridge, tunnel and cave that stands
-- on it, and every tree, fence, tent and rock the game doesn't let anyone walk through. Where those are,
-- a spot has more than one floor (the street and the hall over it, the hill and the mine under it), each
-- with its own height and its own steps to the floors round it, and a way climbs a stair, goes down a
-- tunnel or round a fence as someone walking does.
--
-- nil means "not known", never "no way". A boat and a door that opens are not ground, so a caller falls
-- back on what it reckoned before (the straight line) rather than tell a player they can't get there.

local Shy = Shy
local T = Shy.Way
-- T.data.nodes[world] = { col, row, cols, rows, shared = {}, tiles = { [n] = text } } (Way.lua)

local TILE = 1600 / 3          -- yards a tile
local NODES = 16               -- nodes a tile, each way
local SIZE = TILE / NODES      -- yards a node
local CELL = SIZE / 8          -- yards a cell: a node's place is one of its 8 by 8
local TICK = 0.25              -- seconds a link is kept to
local RECORD = 14              -- bytes a node: its place, what it is, a link to each of the eight round it, its level, its height (two)
                               -- and which of its place's cell's floors it stands on
local NO_NODE = 255
T.GROUND, T.UNDER, T.ABOVE = 0, 1, 2   -- the level a place is on: the ground, under it, a level up
T.NOWHERE = 3                          -- ... or on no floor that is known (over the roof of what is): no way is known there
-- What a node is: in water; reached from its body's heart; the heart reached from it; the body's
-- number (up to 15) times BODY; and rough. A body is ground that hangs together (a continent, an
-- island), its heart the most of it, where anywhere is walked to from anywhere. Off the heart are the
-- heights a cliff lets down from and not back up, and the hollows dropped into and not left. Rough: some
-- of the node can't be walked (a rock face, a ledge's edge), so a way goes through it from its place to
-- the next node's and is never drawn straight across it.
local SWUM, REACHED, LEAVES, BODY, ROUGH = 1, 2, 4, 8, 128
local WALK = 7                 -- yards a second, the quickest anyone goes on foot
local MOST = 30000             -- nodes one search looks at for a place it is asked from before the way is too far to work out
local WORN = 4 * MOST          -- nodes a search looks at in all before a place it hasn't reached yet is too far as well
local HELD = 160000            -- nodes kept in all the searches together
local SEARCHES = 240           -- searches kept
local IDLE = 60                -- seconds a search is unasked before it may make room for another
local NOW = 1                  -- milliseconds a frame spent on answering at once what is asked in it
local BUDGET = 1.5             -- milliseconds a frame spent on what is left
local NEWS = 1                 -- seconds between two SHY_TERRAIN while more is being worked out (each has whoever listens work
                               -- everything out again)
local NEAR = 3                 -- nodes round a place with nowhere to stand in which one that has is looked for
local SLACK = 1.42             -- nodes: how much nearer two nodes' places can be than the nodes themselves (Guess)
-- The eight ways out of a node, north first and on round by east: rows grow southward, columns eastward.
local ROW = { -1, -1, 0, 1, 1, 1, 0, -1 }
local COL = { 0, 1, 1, 1, 0, -1, -1, -1 }
local BACK = { 5, 6, 7, 8, 1, 2, 3, 4 }
local LIFT = 9                 -- the way out of a node that is a lift's ride (search.via says where to)
local STRIDE = 4096            -- a node's number is its row * STRIDE + its column (a tier's: + its tier * Tier.SPAN)
local SPAN = 2 ^ 26            -- a heap's entry is a tier's rank * SPAN + its number
-- What is kept of a node in a search, as one number: the ticks from it to the goal * KEPT, the way out
-- of it that leads there * 2 (none at a goal), and 1 once it is done with.
local KEPT = 32
local PACE = SIZE / WALK / TICK * 0.97   -- ticks a node of straight line, a little under (Guess)
local SLOW = SIZE / WALK / TICK * 1.5    -- ticks a link to the next node takes at most where it is walked straight (Straight)

local byte, floor, ceil, sqrt, max = string.byte, math.floor, math.ceil, math.sqrt, math.max

local stats = { asked = 0, waited = 0, searches = 0, refused = 0, restarted = 0, nodes = 0, cells = 0, tiles = 0, ms = 0, broken = 0, unpackMs = 0, unpackMost = 0, closes = 0, closeMs = 0, closeMost = 0, shapeMost = 0, ins = 0, outs = 0,
	-- (Texts inflated; the longest single step of a search, and since the last mark.)
	inflates = 0, stepMost = 0, stepMark = 0,
	-- (Asks by kind, for the report: a time, a way, a time worked out on the spot, a time as though a fall were slowed.)
	by = { seconds = 0, ways = 0, now = 0, supposing = 0 } }

-- A tile's text as the bytes it stands for: base64 of the bytes deflated; or, after a "~", of runs
-- deflated (a byte and how many times it comes, up to 255, pair after pair), for a tile that is mostly
-- the same byte over and over (open sea, open plain): the game won't inflate what grows that much. nil
-- for one that doesn't unpack.
local char, rep, concat = string.char, string.rep, table.concat
local runs = {}
local function Unpacked(text)
	local inRuns = byte(text, 1) == 126
	local packed = C_EncodingUtil.DecodeBase64(inRuns and text:sub(2) or text)
	if not packed then return nil end
	local ok, out = pcall(C_EncodingUtil.DecompressString, packed, Enum.CompressionMethod.Deflate)
	if not ok or not out then
		stats.broken = stats.broken + 1
		return nil
	end
	if inRuns then
		wipe(runs)
		for at = 1, #out - 1, 2 do
			local value, times = byte(out, at, at + 1)
			runs[#runs + 1] = rep(char(value), times)
		end
		out = concat(runs)
	end
	stats.inflates = stats.inflates + 1
	return out
end

-- A tile's nodes as the string they are kept in, unpacked the first time it is asked for; false for a
-- tile with no ground. Then the tile's number (what the tables of tiles are keyed by). data.plain: the
-- tiles are kept unpacked already (a test's).
local function Tile(data, tileRow, tileCol)
	if tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return false end
	local index = tileRow * data.cols + tileCol + 1
	local open = data.open
	if not open then
		open = {}
		data.open = open
	end
	local tile = open[index]
	if tile == nil then
		local kept = data.tiles[index]
		-- A number is another tile's: many are the same (open sea).
		if type(kept) == "number" then kept = data.shared[kept] end
		if kept and not data.plain then kept = Unpacked(kept) end
		tile = (kept and #kept == NODES * NODES * RECORD) and kept or false
		open[index] = tile
		if tile then stats.tiles = stats.tiles + 1 end
	end
	return tile, index
end

-- The tile a node is in, where its record starts there, and the tile's number (nil for no ground).
local function Record(data, row, col)
	if row < 0 or col < 0 then return nil end
	local tile, index = Tile(data, floor(row / NODES), floor(col / NODES))
	if not tile then return nil end
	local at = ((row % NODES) * NODES + col % NODES) * RECORD
	if byte(tile, at + 1) == NO_NODE then return nil end
	return tile, at, index
end

-- The node a place is in: its row and column from the north-west corner of the world's first tile.
local function NodeAt(data, north, west)
	return floor((32 - data.row) * NODES - north / SIZE), floor((32 - data.col) * NODES - west / SIZE)
end

-- Where a node's place is, in yards north and west, and whether it is in water; then the level it is
-- on and its height in yards.
local function Place(data, row, col, tile, at)
	local place = byte(tile, at + 1)
	local swum = byte(tile, at + 2) % 2 == SWUM
	local north = (32 - data.row) * TILE - (row * 8 + floor(place / 8) + 0.5) * CELL
	local west = (32 - data.col) * TILE - (col * 8 + place % 8 + 0.5) * CELL
	return north, west, swum, byte(tile, at + 11), (byte(tile, at + 12) + byte(tile, at + 13) * 256 - 20000) / 2
end

-- Tiers ------------------------------------------------------------------------------------------
-- A node's ground at more than one height (a bridge over a moat, a road over a valley, a city inside the
-- mountain over it) is a tier for each height, each a place of its own with links of its own. A tier is
-- searched for by its key: its tier * Tier.SPAN + its node's number, so a node's tier 0 is the node's own
-- number, and ground of one tier a node (most of it) is searched as it always was. Tier 0 is the node's
-- record (RECORD) and its links to the tiers 0 round it; data.tiers, by tile: each node of more than one,
-- its number in the tile and how many, then ten bytes a tier (its place, what it is, its look, which floor
-- of its place's cell, its height, the low and the high of its span: two bytes each), then sixteen bytes,
-- the tier of each of its cells' floor 0 (two bits a cell, the first lowest); data.joins, by tile: every
-- other link, four bytes each (the node's number in the tile, its tier * data.tiered + the tier it leads
-- to, the way: 0 to 7 round by north, 8 its own node's other tier; the ticks); data.storeys, by tile: the
-- tiers of the floors over those floor 0s (Tier.Storeys). Ground kept without tiers is all tier 0.
-- (All on one table: the file's main chunk is at Lua's limit of 200 locals.)
local Tier = {
	SPAN = 2 ^ 24,             -- a tier's key: its tier * SPAN + its node's number
	JOIN = 11,                 -- the way out of a tier that is a link to another tier (search.via says where to)
	SLACK = 1.5,               -- yards: a floor this near a tier's span is on it
	BESIDE = 8,                -- yards: a floor this near one of the place's own is still that place (a step,
	                           -- a counter). The lake under a cliff is not
	UP_NEAR = 6,               -- yards: of a goal's floors, those this near the height it stands at are it
	-- A fall: down steeper than any slide (70 degrees, as the floors are made), or steeper than any stair
	-- (62) off an edge, from ground that isn't steep onto ground that isn't (a hillside is slid down
	-- unharmed). The same rule the ground's links were made by, where each yard of one costs a second. Up
	-- close, where the way is drawn and walked, each costs two (128ths): a narrow walkway's every step is
	-- dearer (TIGHT), and at one a second a way led down from Tyrande's balcony dropped 23 yards off the
	-- walkway's edge to save three seconds. Into deep water it costs nothing more (Stormwind's gryphon tower,
	-- into the canal).
	FALL_STRAIGHT = CELL * 1.8807, FALL_CORNER = CELL * 1.4142 * 1.8807, FALL_TICKS = 128,
	SLIDE_STRAIGHT = CELL * 2.7475, SLIDE_CORNER = CELL * 1.4142 * 2.7475,
	RECORD = 10,               -- bytes a tier of a node of more than one
	MAP = 16,                  -- bytes of a node's map of its cells' tiers
	floors = {},               -- (the floors at a place, as Tier.At finds them)
	into = {},                 -- (the links of a node, as Tier.Ins and Tier.Outs give them: read at once)
	intoToll = {},             -- (what each of those costs a search kept to the roads, Tier.Ins: by the link's second entry)
	empty = {},                -- (no tile read yet)
	QUARTERS = {},             -- (the bit of each quarter-cell in a floor's mask: 2 ^ (quarter), quarter 0 first)
}
for quarter = 0, 15 do Tier.QUARTERS[quarter + 1] = 2 ^ quarter end

-- A tile's tiers, read the first time: { text, [node's number in the tile] = where its count is }; false for
-- a tile with no node of more than one.
function Tier.Tile(data, tileRow, tileCol)
	local tiers = data.tiers
	if not tiers or tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return false end
	local index = tileRow * data.cols + tileCol + 1
	local opened = data.tiersOpen
	if not opened then
		opened = {}
		data.tiersOpen = opened
	end
	local open = opened[index]
	if open == nil then
		open = false
		local text = tiers[index]
		if text and not data.plain then text = Unpacked(text) end
		if text then
			open = { text = text }
			local at = 1
			while at < #text do
				local here, n = byte(text, at, at + 1)
				open[here] = at + 1
				at = at + 2 + n * Tier.RECORD + Tier.MAP
			end
		end
		opened[index] = open
	end
	return open
end

-- How many tiers a node has (0: no ground); for more than one, the tiers' text and where their count is.
function Tier.Of(data, row, col)
	if not Record(data, row, col) then return 0 end
	local open = Tier.Tile(data, floor(row / NODES), floor(col / NODES))
	local at = open and open[(row % NODES) * NODES + col % NODES]
	if not at then return 1 end
	return byte(open.text, at), open.text, at
end

-- A key's node, its row and column, and its tier.
function Tier.Node(key)
	local tier = floor(key / Tier.SPAN)
	local node = key - tier * Tier.SPAN
	return node, floor(node / STRIDE), node % STRIDE, tier
end

-- Where a key's place is: north, west, whether it is swum, its look, its height, and which floor of its
-- cell it is; then what it is (SWUM, REACHED, LEAVES, BODY, ROUGH). nil for no such tier.
function Tier.Place(data, key)
	local _, row, col, tier = Tier.Node(key)
	if tier == 0 then
		local tile, at = Record(data, row, col)
		if not tile then return nil end
		local north, west, swum, look, up = Place(data, row, col, tile, at)
		return north, west, swum, look, up, byte(tile, at + 14), byte(tile, at + 2)
	end
	local n, text, at = Tier.Of(data, row, col)
	if tier >= n then return nil end
	local from = at + 1 + tier * Tier.RECORD
	local place, what, look, which, low, high = byte(text, from, from + 5)
	return (32 - data.row) * TILE - (row * 8 + floor(place / 8) + 0.5) * CELL, (32 - data.col) * TILE - (col * 8 + place % 8 + 0.5) * CELL,
		what % 2 == SWUM, look, (low + high * 256 - 20000) / 2, which, what
end

-- What a key is: the byte of SWUM, REACHED, LEAVES, BODY and ROUGH (0 for no such tier).
function Tier.What(data, key)
	local _, row, col, tier = Tier.Node(key)
	if tier == 0 then
		local tile, at = Record(data, row, col)
		return tile and byte(tile, at + 2) or 0
	end
	local n, text, at = Tier.Of(data, row, col)
	if tier >= n then return 0 end
	return byte(text, at + 2 + tier * Tier.RECORD)
end

-- The tier a node of more than one has its cell's floor 0 on (cell: 0 to 63 in the node), by its map.
function Tier.Mapped(text, at, n, cell)
	local packed = byte(text, at + 1 + n * Tier.RECORD + floor(cell / 4))
	return floor(packed / 4 ^ (cell % 4)) % 4
end

-- A tile's tiers of the floors over its cells' floor 0s (data.storeys), read the first time: { text, [node's
-- number in the tile] = where its byte of floors is }; false for none. A node's is its number in the tile, a
-- byte with bit k - 1 set for each floor k some cell of it has, then sixteen bytes for each of those floors,
-- the lowest first: the tier of each cell's floor k, as the map has floor 0's.
function Tier.Storeys(data, tileRow, tileCol)
	local storeys = data.storeys
	if not storeys or tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return false end
	local index = tileRow * data.cols + tileCol + 1
	local opened = data.storeysOpen
	if not opened then
		opened = {}
		data.storeysOpen = opened
	end
	local open = opened[index]
	if open == nil then
		open = false
		local text = storeys[index]
		if text and not data.plain then text = Unpacked(text) end
		if text then
			open = { text = text }
			local at = 1
			while at < #text do
				local here, has = byte(text, at, at + 1)
				open[here] = at + 1
				local count = 0
				while has > 0 do
					count, has = count + has % 2, floor(has / 2)
				end
				at = at + 2 + count * Tier.MAP
			end
		end
		opened[index] = open
	end
	return open
end

-- The tier a node of more than one (row, col) has floor k (1 and up) of a cell (0 to 63 in the node) on, as
-- the ground tells it; nil where it tells none.
function Tier.Storey(data, row, col, k, cell)
	local open = Tier.Storeys(data, floor(row / NODES), floor(col / NODES))
	local at = open and open[(row % NODES) * NODES + col % NODES]
	if not at then return nil end
	local has = byte(open.text, at)
	if floor(has / 2 ^ (k - 1)) % 2 == 0 then return nil end
	local before = 0
	for bit = 0, k - 2 do before = before + floor(has / 2 ^ bit) % 2 end
	local packed = byte(open.text, at + 1 + before * Tier.MAP + floor(cell / 4))
	return floor(packed / 4 ^ (cell % 4)) % 4
end

-- The tier a node of more than one has a floor of `height` on, for ground that tells no floor's own
-- (Tier.Storey): the first whose span holds it (within SLACK), else the nearest (the first of those as near).
function Tier.Spanned(text, at, n, height)
	local best, gap
	for tier = 0, n - 1 do
		local from = at + 1 + tier * Tier.RECORD + 6
		local lowL, lowH, highL, highH = byte(text, from, from + 3)
		local low, high = (lowL + lowH * 256 - 20000) / 2, (highL + highH * 256 - 20000) / 2
		local off = max(low - height, height - high, 0)
		if off <= Tier.SLACK then return tier end
		if not gap or off < gap then best, gap = tier, off end
	end
	return best
end

-- A tile's links between tiers (data.joins), read the first time: { text, [node's number in the tile] = where
-- its records begin }; false for none. A record is four bytes: the node's number in the tile, its tier * many
-- + the tier it leads to, the way (0 to 7 round by north, 8 to another tier of the node), and the ticks. The
-- records are kept in the text they came in, in order of node: a node's are read where they lie. (What is
-- kept of a tile is its text and one number a node that has any, not a table a node.)
function Tier.Joins(data, tileRow, tileCol)
	local joins = data.joins
	if not joins or tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return false end
	local index = tileRow * data.cols + tileCol + 1
	local opened = data.joinsOpen
	if not opened then
		opened = {}
		data.joinsOpen = opened
	end
	local open = opened[index]
	if open == nil then
		open = false
		local text = joins[index]
		if text and not data.plain then text = Unpacked(text) end
		if text then
			open = { text = text }
			local last = -1
			local sorted = true
			for at = 1, #text - 3, 4 do
				local here = byte(text, at)
				if here < last then
					sorted = false
					break
				end
				if here ~= last then open[here] = at end
				last = here
			end
			if not sorted then
				-- (Not in order of node, as they are written: put in it.)
				local records = {}
				for at = 1, #text - 3, 4 do records[#records + 1] = text:sub(at, at + 3) end
				table.sort(records, function(a, b) return byte(a) < byte(b) end)
				text = table.concat(records)
				open = { text = text }
				last = -1
				for at = 1, #text - 3, 4 do
					local here = byte(text, at)
					if here ~= last then open[here] = at end
					last = here
				end
			end
			open.offs, open.ins = Tier.InsOf(data, text)
		end
		opened[index] = open
	end
	return open
end

-- A tile's links turned round, for Tier.Ins: by the tier each leads into (a slot: the tier's node's row and
-- column in the tile, -1 to NODES for the ring of nodes round it, times the tiers a node), two texts. offs:
-- two bytes a slot (and one past the last), where the slot's links begin in ins, counted in links; ins: two
-- bytes a link, the tier it leaves from * 16 + the way in (0 to 7 round by north, 8 the node's own other
-- tier: where it leaves from follows from those) and its ticks, each slot's as the records lie. Some 3 KB a
-- tile and 2 bytes a link, against the scan of nine nodes' records for every node looked at, which was a
-- third of what a search cost (a search's nodes mostly have links in: 8 a node where the ground is tiered).
-- (The order of a tier's links in changes nothing a search finds: each leads from a tier of its own, and the
-- heap gives them back by rank and key, however they went in. A city's tile has 6,000 links: two passes
-- over them, and no more.)
Tier.WINDOW = NODES + 2
do
	local counts, cursor, parts, slotOf = {}, {}, {}, {}
	-- (The slot of the tier 0 a record's link leads into, by its node and its way: node * 16 + way. Worked out
	-- once for the number of tiers a node may have: read a record a time, it was most of reading a tile.)
	local into, intoFor = {}, nil
	function Tier.InsOf(data, text)
		local many, window = data.tiered or 4, Tier.WINDOW
		if intoFor ~= many then
			intoFor = many
			for here = 0, NODES * NODES - 1 do
				for way = 0, 15 do
					local toRow, toCol = floor(here / NODES) + 1, here % NODES + 1
					if way < 8 then toRow, toCol = toRow + ROW[way + 1], toCol + COL[way + 1] end
					into[here * 16 + way] = (toRow * window + toCol) * many + 1
				end
			end
		end
		local slots = window * window * many
		for slot = 1, slots do counts[slot] = 0 end
		local size = #text
		local records = 0
		for at = 1, size - 3, 4 do
			local here, tiers, way = byte(text, at, at + 2)
			local slot = into[here * 16 + way] + tiers % many
			counts[slot] = counts[slot] + 1
			records = records + 1
			slotOf[records] = slot
		end
		local run = 0
		for slot = 1, slots + 1 do
			parts[slot * 2 - 1], parts[slot * 2] = run % 256, (run - run % 256) / 256
			cursor[slot] = run
			run = run + (slot <= slots and counts[slot] or 0)
		end
		local offs = char(unpack(parts, 1, (slots + 1) * 2))
		-- (Each link into its slot, as the records lie.)
		local record = 0
		for at = 2, size - 2, 4 do
			local tiers, way, ticks = byte(text, at, at + 2)
			record = record + 1
			local slot = slotOf[record]
			local place = cursor[slot]
			cursor[slot] = place + 1
			parts[place * 2 + 1], parts[place * 2 + 2] = (tiers - tiers % many) / many * 16 + way, ticks
		end
		-- (string.char takes so many at a time.)
		local pieces, n = {}, run * 2
		for from = 1, n, 4000 do pieces[#pieces + 1] = char(unpack(parts, from, from + 3999 < n and from + 3999 or n)) end
		return offs, concat(pieces)
	end
end

-- The links out of a node (a key), into `list` as { to key, ticks, ... }: how many entries.
function Tier.Outs(data, key, list)
	local _, row, col, tier = Tier.Node(key)
	local tileRow, tileCol = floor(row / NODES), floor(col / NODES)
	local joins = Tier.Joins(data, tileRow, tileCol)
	local n = 0
	local at = joins and joins[(row - tileRow * NODES) * NODES + col - tileCol * NODES]
	if at then
		local text, here, many, span = joins.text, byte(joins.text, at), data.tiered or 4, Tier.SPAN
		local size = #text
		while at + 3 <= size do
			local this, tiers, way, ticks = byte(text, at, at + 3)
			if this ~= here then break end
			if floor(tiers / many) == tier then
				n = n + 2
				list[n - 1] = tiers % many * span + (way == 8 and row * STRIDE + col or (row + ROW[way + 1]) * STRIDE + col + COL[way + 1])
				list[n] = ticks
			end
			at = at + 4
		end
	end
	return n
end

-- The links into a node (a key), into `list` as { from key, ticks, ... }: how many entries. They are kept
-- with the node they leave from: this one (to another of its tiers) or one of the eight round it.
-- search, tolls, tollList: for a search kept to the roads (its tiles of tolls, Tier.Tolls), what a step off
-- each link's tier costs (1 or Tier.ROAD_OFF) into tollList[n], beside the link's ticks.
function Tier.Ins(data, key, list, search, tolls, tollList)
	local tier = floor(key / Tier.SPAN)
	local node = key - tier * Tier.SPAN
	local row, col = floor(node / STRIDE), node % STRIDE
	local many, span = data.tiered or 4, Tier.SPAN
	-- (The links in are kept with the node they leave from: this one or one of the eight round it, in this
	-- tile or, at a tile's edge, one beside it.)
	local firstRow, lastRow = floor((row - 1) / NODES), floor((row + 1) / NODES)
	local firstCol, lastCol = floor((col - 1) / NODES), floor((col + 1) / NODES)
	local window = Tier.WINDOW
	local free = search and search.free
	local n = 0
	for tileRow = firstRow, lastRow do
		for tileCol = firstCol, lastCol do
			local joins = Tier.Joins(data, tileRow, tileCol)
			if joins then
				-- (The tier's slot in the tile's turned-round links: Tier.InsOf.)
				local slot = ((row - tileRow * NODES + 1) * window + col - tileCol * NODES + 1) * many + tier
				local a, b, c, d = byte(joins.offs, slot * 2 + 1, slot * 2 + 4)
				local ins = joins.ins
				local first, last = (a + b * 256) * 2 + 1, (c + d * 256) * 2
				local tollTile
				if search and last >= first then
					local index = tileRow * data.cols + tileCol + 1
					tollTile = tolls[index] or Tier.TollTile(search, index)
				end
				for at = first, last, 2 do
					local from, ticks = byte(ins, at, at + 1)
					local way = from % 16
					local fromRow, fromCol = row, col
					if way < 8 then fromRow, fromCol = row - ROW[way + 1], col - COL[way + 1] end
					local fromNode, fromTier = fromRow * STRIDE + fromCol, floor(from / 16)
					n = n + 2
					list[n - 1] = fromTier * span + fromNode
					list[n] = ticks
					if tollTile then
						-- (The link leaves from a node of this tile: its byte of tolls, as Tier.TollOf reads it.)
						local bits = byte(tollTile, (fromRow - tileRow * NODES) * NODES + fromCol - tileCol * NODES + 1)
						tollList[n] = (free[fromNode] or (fromTier == 0 and bits % 2 == 1) or (fromTier > 0 and (floor(bits / 2) % 2 == 1
							or floor(bits / 2 ^ (1 + fromTier)) % 2 == 1))) and 1 or Tier.ROAD_OFF
					end
				end
			end
		end
	end
	return n
end

-- What a key is, apart from wet: its body's number (0 for a pocket of ground too small for one), whether
-- it is reached from that body's heart, and whether the heart is reached from it.
local function What(data, key)
	local what = Tier.What(data, key)
	return floor(what / BODY) % 16, floor(what / REACHED) % 2 == 1, floor(what / LEAVES) % 2 == 1
end

-- What a key is, as one number for the rule below: its body's number * 4, + 2 where it is reached from
-- the heart, + 1 where the heart is reached from it.
local function Kind(data, key)
	local body, reached, leaves = What(data, key)
	return body * 4 + (reached and 2 or 0) + (leaves and 1 or 0)
end

-- Whether the ground itself lets there be a way from a node of one kind to a node of another.
local function Walks(kind, toKind)
	local body = floor(kind / 4)
	if body ~= floor(toKind / 4) then return false end
	if body == 0 then return true end
	local reached, leaves = floor(kind / 2) % 2 == 1, kind % 2 == 1
	local toReached, toLeaves = floor(toKind / 2) % 2 == 1, toKind % 2 == 1
	-- Down to the heart, across it and off its far edge: a way for sure.
	if leaves and toReached then return true end
	-- A height nothing climbs to, from somewhere that isn't one; or out of a hollow nothing leaves.
	if reached and not toReached then return false end
	if toLeaves and not leaves then return false end
	return true
end

-- Whether there can be a way from one node to another: false where the ground itself says there is none,
-- and no lift leads round that (data.liftKinds: the kinds of each lift's two ends, a pair after pair; a
-- lift joins a mesa to the plain under it). What a kind gets to by walking and riding is worked out once
-- (data.liftReach[kind]: the kinds got to).
local function Joined(data, key, toKey)
	local kind, toKind = Kind(data, key), Kind(data, toKey)
	if Walks(kind, toKind) then return true end
	local ends = data.liftKinds
	if not ends then return false end
	local reach = data.liftReach[kind]
	if not reach then
		reach = { [kind] = true }
		local grew = true
		while grew do
			grew = false
			for index = 1, #ends - 1, 2 do
				local a, b = ends[index], ends[index + 1]
				for got in pairs(reach) do
					if not reach[b] and Walks(got, a) then reach[b], grew = true, true end
					if not reach[a] and Walks(got, b) then reach[a], grew = true, true end
				end
			end
		end
		data.liftReach[kind] = reach
	end
	for got in pairs(reach) do
		if Walks(got, toKind) then return true end
	end
	return false
end

-- The node to start or end at for a place: its own, or the nearest round it with somewhere to stand.
local function Stand(data, north, west)
	local row, col = NodeAt(data, north, west)
	if Record(data, row, col) then return row, col end
	local best, bestRow, bestCol
	for reach = 1, NEAR do
		for dr = -reach, reach do
			for dc = -reach, reach do
				if max(dr < 0 and -dr or dr, dc < 0 and -dc or dc) == reach then
					local tile, at = Record(data, row + dr, col + dc)
					if tile then
						local n, w = Place(data, row + dr, col + dc, tile, at)
						local far = (n - north) ^ 2 + (w - west) ^ 2
						if not best or far < best then best, bestRow, bestCol = far, row + dr, col + dc end
					end
				end
			end
		end
		if best then return bestRow, bestCol end
	end
end
Tier.Stand = Stand

-- Lifts --------------------------------------------------------------------------------------------
-- A lift is no ground: it is a thing that moves, and the game's files don't say where one stands. The
-- mesa over the plain and the city under the ruins are walked between by riding one. A lift is known
-- where someone rode it: on this account (noticed as it happens, "Riding a lift" below, and kept in
-- ShyWayDB.lifts) or by whoever rode it before the ground shipped (Data\Lifts.lua). Each joins the node
-- at its foot to the node at its head, both ways, in the seconds a ride took with the wait for it.
-- T.data.lifts[world] = { footNorth, footWest, headNorth, headWest, seconds, ... }

local liftsKnown = 0           -- how many lifts have been learned: a world's are worked out again when it grows

-- A world's lifts as links: data.liftsAt[key] = { key, ticks, key, ticks, ... }; and the kinds of tier
-- each joins (data.liftKinds, for Joined: the ground alone no longer says two places aren't). A lift's
-- foot is on the tier of the lowest floor there, its head on the highest's.
local function Lifts(world, data)
	local learned = T.Saved().lifts
	local shipped = T.data.lifts[world]
	local version = liftsKnown + (learned and #learned or 0) + (shipped and #shipped or 0) * 1000
	if data.liftsFor == version then return end
	data.liftsFor = version
	local at, any, kinds = {}, false, {}
	local ground = Tier.GroundOf(world, data)
	local function Join(footNorth, footWest, headNorth, headWest, seconds)
		local footRow, footCol = Stand(data, footNorth, footWest)
		local headRow, headCol = Stand(data, headNorth, headWest)
		if not footRow or not headRow then return end
		local foot = Tier.At(data, ground, footRow, footCol, footNorth, footWest, "low")
		local head = Tier.At(data, ground, headRow, headCol, headNorth, headWest, "high")
		if foot == head then return end
		kinds[#kinds + 1], kinds[#kinds + 2] = Kind(data, foot), Kind(data, head)
		local ticks = max(1, floor(seconds / TICK + 0.5))
		at[foot], at[head] = at[foot] or {}, at[head] or {}
		local down, up = at[foot], at[head]
		down[#down + 1], down[#down + 2] = head, ticks
		up[#up + 1], up[#up + 2] = foot, ticks
		any = true
	end
	if shipped then
		for index = 1, #shipped - 4, 5 do Join(shipped[index], shipped[index + 1], shipped[index + 2], shipped[index + 3], shipped[index + 4]) end
	end
	for _, lift in ipairs(learned or {}) do
		if lift[1] == world then Join(lift[2], lift[3], lift[4], lift[5], lift[6]) end
	end
	data.liftsAt, data.liftKinds, data.liftReach = any and at or nil, any and kinds or nil, {}
end

-- Slowed falls -----------------------------------------------------------------------------------
-- A mage's Slow Fall, a priest's Levitate, the Skyborne's Walk on Air: who can fall slowly is a glide away
-- from what lies far below a cliff. Data\Falls.lua has the spells as the client does (each: the spell, the
-- seconds it lasts, the level it is learned at, its reagent, its cooldown, and the spells that do away
-- with the reagent); each world's data.drops the drops, kept with their landings' tiles (five bytes a
-- drop: the landing node in its tile, the way back to where it is fallen from + 128 each way, how far down
-- in twos of yards, the ticks it takes). A drop is gone by only as deep as a fall that can be slowed now
-- is safe: `speed` yards a second while it lasts (FALL_MARGIN of it), and `safe` yards after.
-- (T.data.falls: Way.lua's until Data\Falls.lua loads.)
local FALL = 10                -- the way out of a node that is a drop (search.via says where to)
local FALL_MARGIN = 0.9
local fallDeep, fallSpell, fallSet = 0, nil, nil   -- yards a drop may be now (0: none) and by which spell; set: as T.SetFall says
-- A glide steered on the way down (the Skyborne's Walk on Air; a spell row's seventh field) comes down where
-- a fall that isn't steered can't: nearly straight under the cliff, or bent round what is in the straight
-- line's way. Such a drop (+128 on its depth) is gone by only as deep as a glide can be had now.
local glideDeep, glideSpell, glideSet = 0, nil, nil
-- And who can walk on water (a shaman's Water Walking, a priest's Levitate: T.data.falls.water) swims
-- nowhere: water is walked at a runner's pace, so a lake is crossed where the way round it is longer.
local waterOn, waterSpell, waterSet = false, nil, nil
local WATER = 4.7222 / 7       -- what a swum link takes, walked on the water: a swimmer's pace over a runner's

-- Whether a spell that slows a fall can be cast now: known, its reagent in the bags or done away with,
-- and off its cooldown (a global cooldown is none). cooldown: its own, in seconds (the data's); a spell
-- with none is never kept back. In a fight the game keeps a cooldown's length secret: what it says
-- outright (on the global cooldown or not) is taken, and where it says nothing the last answer stands.
-- A change here drops every search kept, so it must not turn with each spell cast.
local Usable
do
	local last = {}          -- spell -> the last answer, for when the game says nothing
	function Usable(spell, reagent, waivers, cooldown)
		if not C_SpellBook.IsSpellKnown(spell) then return false end
		if reagent > 0 and C_Item.GetItemCount(reagent) == 0 then
			local waived = false
			for _, waiver in ipairs(waivers) do
				local aura = C_UnitAuras.GetPlayerAuraBySpellID(waiver)
				if C_SpellBook.IsSpellKnown(waiver) or (not issecretvalue(aura) and aura ~= nil) then
					waived = true
					break
				end
			end
			if not waived then return false end
		end
		if cooldown == 0 then return true end
		local info = C_Spell.GetSpellCooldown(spell)
		local usable = true
		if info and info.isActive and not info.isOnGCD then
			if not issecretvalue(info.duration) then
				usable = info.duration <= 1.5
				-- (Looked at again when it is over: the game says so of no spell in particular, at times.)
				if not usable and not issecretvalue(info.startTime) then
					local over = info.startTime + info.duration
					if not Tier.wake or over < Tier.wake then Tier.wake = over end
				end
			elseif info.isOnGCD == nil then
				usable = last[spell] ~= false
			else
				usable = false
			end
		end
		last[spell] = usable
		return usable
	end
end

-- How deep a drop may be now, and by which spell: the deepest of the slowed falls that can be had; then
-- the same of those that are steered.
local function FallDeep()
	local falls, deepest, by, glide, glider = T.data.falls, 0, nil, 0, nil
	-- (Whether a fall may be slowed at all, now or as reagents and cooldowns come and go: the searches note
	-- every drop they look at only then, Step.)
	Tier.mayFall = fallSet ~= nil or glideSet ~= nil
	for _, each in ipairs(falls.spells) do
		local spell, seconds, reagent, waivers, steered = each[1], each[2], each[4], each[6], each[7] == 1
		if C_SpellBook.IsSpellKnown(spell) then Tier.mayFall = true end
		if Usable(spell, reagent, waivers, each[5]) then
			local deep = floor(falls.speed * seconds * FALL_MARGIN + falls.safe)
			if deep > deepest then deepest, by = deep, spell end
			if steered and deep > glide then glide, glider = deep, spell end
		end
	end
	if fallSet then deepest, by = fallSet, nil end
	if glideSet then glide, glider = glideSet, nil end
	return deepest, by, glide, glider
end

-- Whether water can be walked on now, and by which spell.
local function WaterWalk()
	if waterSet ~= nil then return waterSet, nil end
	for _, each in ipairs(T.data.falls.water or {}) do
		if Usable(each[1], each[4], each[6], each[5]) then return true, each[1] end
	end
	return false, nil
end

-- The drops that land at a key, as entries first to last of a list: { from key, yards down, ticks, steered,
-- ... }; a tile's are read the first time one of its nodes is asked for, into one list for the tile, each
-- landing's together ([landing] = where its run begins * 65536 + where it ends). data.falls: six bytes a
-- drop, kept with its landing's tile (the landing node in its tile, the tier fallen from * data.tiered +
-- the tier landed on, the way back to where it is fallen from, rows and columns + 128, how far down, the
-- ticks); ground kept without tiers has data.drops, the same but for the tiers (all 0).
-- (index: the key's tile's number, where the caller has it from Record.)
local function DropsTo(data, key, index)
	local falls = data.falls or data.drops
	if not falls then return nil end
	local DROP_RUN = 1048576
	data.dropsOpen = data.dropsOpen or {}
	local open = index and data.dropsOpen[index]
	if open == nil then
		local width = data.falls and 6 or 5
		local _, row, col = Tier.Node(key)
		local tileRow, tileCol = floor(row / NODES), floor(col / NODES)
		if tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return nil end
		index = tileRow * data.cols + tileCol + 1
		open = data.dropsOpen[index]
		if open == nil then
			open = false
			local text = falls[index]
			if text and not data.plain then text = Unpacked(text) end
			if text then
				-- (Two passes: how many land at each, then each into its landing's run, as they come.)
				local many, span = data.tiered or 4, Tier.SPAN
				open = {}
				local list, n = {}, 0
				for pass = 1, 2 do
					for at = 1, #text - width + 1, width do
						local here, tiers, dr, dc, deep, ticks
						if width == 6 then
							here, tiers, dr, dc, deep, ticks = byte(text, at, at + 5)
						else
							here, dr, dc, deep, ticks = byte(text, at, at + 4)
							tiers = 0
						end
						local spot = (tileRow * NODES + floor(here / NODES)) * STRIDE + tileCol * NODES + here % NODES
						local landing = tiers % many * span + spot
						if pass == 1 then
							open[landing] = (open[landing] or 0) + 4
						else
							local where = open[landing]
							local put = where % DROP_RUN
							list[put], list[put + 1], list[put + 2], list[put + 3] = floor(tiers / many) * span + spot + (dr - 128) * STRIDE + dc - 128,
								deep % 128 * 4, ticks, deep >= 128
							open[landing] = where + 4
						end
					end
					if pass == 1 then
						-- (Each landing's run: where it begins * DROP_RUN + where its next entry goes.)
						for landing, entries in pairs(open) do
							open[landing] = (n + 1) * DROP_RUN + n + 1
							n = n + entries
						end
					end
				end
				-- (Now where each run begins * DROP_RUN + where its last entry begins.)
				for landing, where in pairs(open) do open[landing] = where - 4 end
				open.list = list
			end
			data.dropsOpen[index] = open
			stats.drops = (stats.drops or 0) + 1
		end
	end
	local at = open and open[key]
	if not at then return nil end
	local last = at % DROP_RUN
	return open.list, (at - last) / DROP_RUN, last
end

-- Whether a search holds as it is where a fall may now be slowed `deep` yards (and steered `glide`): every
-- drop it looked at would be gone down, or not, as it was. It noted the deepest gone down and the shallowest
-- not, of each kind (search.uPass, uSkip; gPass, gSkip for those steered), where a fall could be slowed at
-- all when it began (search.noted); else it is begun again.
function Tier.Deep(search, deep, glide)
	if not search.noted then return false end
	local dropping = deep > 0 or glide > 0
	local function Holds(pass, skip, limit)
		if pass and not (dropping and pass <= limit) then return false end
		return not (skip and dropping and skip <= limit)
	end
	return Holds(search.uPass, search.uSkip, deep) and Holds(search.gPass, search.gSkip, glide)
end

-- The search --------------------------------------------------------------------------------------
-- A* from the goals backward over the links that lead to them, steered toward the node that asks. A
-- search is kept with all it has found (search.cost), so it answers for any node it is done with, and
-- is steered anew and carried on for one it isn't.

-- The least ticks there can be between two nodes: the straight line walked. A node's place may be
-- anywhere in it, so two nodes' places are up to SLACK nodes nearer than the nodes are; and a link is
-- kept to the tick, which may be half of one under. Guessing over would find a way that is not the
-- quickest.
local function Guess(row, col, toRow, toCol)
	local far = sqrt((row - toRow) ^ 2 + (col - toCol) ^ 2) - SLACK
	return far > 0 and floor(far * PACE) or 0
end

-- The heap: a plain array of entries, the least first; heap.n of them. (Popped where it is searched, Step and
-- CloseStep, in place.)
local function Push(heap, entry)
	local at = heap.n + 1
	heap.n = at
	while at > 1 do
		local up = floor(at / 2)
		local above = heap[up]
		if above <= entry then break end
		heap[at] = above
		at = up
	end
	heap[at] = entry
end

-- The ticks from a node to the search's goal, once the search is done with that node.
local function Known(search, node)
	local have = search.cost[node]
	if have and have % 2 == 1 then return floor(have / KEPT) end
end

-- Whether a search has more to do for the tier it is steered toward.
local function Wanted(search)
	return not search.done and not search.far and not Known(search, search.toKey)
end

-- Looks at up to `nodes` tiers more. (A tier is looked at by its key: a node's tier 0 by its number.)
-- (The heap is popped and pushed here in place, heap.n kept in `hn` meanwhile; what is kept of a tier,
-- ticks * KEPT + the rest, is taken apart by arithmetic, not floor: in the game a call costs far more than
-- a sum. A link is looked at only where it could make a way quicker: its ticks are the least it can come
-- to, but on the water, where it is at least 1, and the toll of the roads only adds.)
local function Step(search, nodes)
	local data, cost, heap = search.data, search.cost, search.heap
	local toRow, toCol = search.toRow, search.toCol
	local target = search.toKey
	local tierSpan, join, joined, window, many = Tier.SPAN, Tier.JOIN, data.joins ~= nil, Tier.WINDOW, data.tiered or 4
	local roads, free, roadOff = search.roads, search.free, Tier.ROAD_OFF
	-- (Kept to the roads: what a step onto a tier 0 costs, a byte a node by tile, Tier.TollTile.)
	local tolls = roads and Tier.Tolls(search)
	local deep, glide = search.fall, search.glide
	local dropping = (deep > 0 or glide > 0) and (data.falls or data.drops) ~= nil
	-- (The drops looked at: those a fall may go down now, and, where one may be slowed at all, every one,
	-- noted: Tier.Deep.)
	local hasDrops, dropsOpen = (data.falls or data.drops) ~= nil and (dropping or search.noted == true), data.dropsOpen
	local water, via = search.water, search.via
	local byte, sqrt, max, Record, TollTile, What = byte, sqrt, max, Record, Tier.TollTile, Tier.What
	local ROW, COL, BACK, KEPT, SPAN, STRIDE, SLACK, PACE = ROW, COL, BACK, KEPT, SPAN, STRIDE, SLACK, PACE
	local hn = heap.n
	local looked = 0
	while looked < nodes do
		if hn == 0 then
			search.done = true
			break
		end
		-- (Pop: the least, and the last sunk from the top.)
		local top, last = heap[1], heap[hn]
		heap[hn] = nil
		hn = hn - 1
		if hn > 0 then
			local at = 1
			while true do
				local down = at + at
				if down > hn then break end
				local child = heap[down]
				if down < hn then
					local right = heap[down + 1]
					if right < child then down, child = down + 1, right end
				end
				if child >= last then break end
				heap[at] = child
				at = down
			end
			heap[at] = last
		end
		local node = top % SPAN
		local have = cost[node]
		if have % 2 == 0 then
			cost[node] = have + 1
			looked = looked + 1
			local sofar = (have - have % KEPT) / KEPT
			local base = node % tierSpan
			local col = base % STRIDE
			local row = (base - col) / STRIDE
			-- (The node's own tile: its eight neighbours are mostly in it, read from its text with no lookup.)
			local tile0, at0, index0 = Record(data, row, col)
			-- (Walking on water: whether this tier is swum, for the links into it that are.)
			local wet = false
			if water then wet = What(data, node) % 2 == SWUM end
			-- (Kept to the roads: what a step onto or off this tier costs, Tier.Toll.)
			local toll, tollTile0
			if roads then
				if tile0 then
					-- (Its tile's byte of tolls: bit 1 its tier 0, bit 2 safe, bit 2 ^ (1 + k) its tier k a level up.)
					tollTile0 = tolls[index0] or TollTile(search, index0)
					local tier, bits = (node - base) / tierSpan, byte(tollTile0, at0 / RECORD + 1)
					toll = (free[base] or (tier == 0 and bits % 2 == 1) or (tier > 0 and (floor(bits / 2) % 2 == 1 or floor(bits / 2 ^ (1 + tier)) % 2 == 1)))
						and 1 or roadOff
				else
					toll = Tier.Toll(search, node)
				end
			end
			-- The links from the tiers 0 round it, into a tier 0.
			if node == base then
				local inRow, inCol = row % NODES, col % NODES
				for way = 1, 8 do
					local nr, nc = row + ROW[way], col + COL[way]
					local tile, at, index
					local lr, lc = inRow + ROW[way], inCol + COL[way]
					if tile0 and lr >= 0 and lr < NODES and lc >= 0 and lc < NODES then
						tile, at, index = tile0, (lr * NODES + lc) * RECORD, index0
					else
						tile, at, index = Record(data, nr, nc)
					end
					if tile then
						-- The link that leads here from there.
						local back = BACK[way]
						local link = byte(tile, at + 2 + back)
						if link > 0 then
							local next = nr * STRIDE + nc
							local had = cost[next]
							-- A tier done with is looked at again when a quicker way from it turns up: the
							-- guess can run ahead of the links between two nodes whose places lie close.
							if not had or (sofar + (water and 1 or link) + 1) * KEPT <= had then
								if tile == tile0 and byte(tile0, at + 1) == NO_NODE then link = 0 end
								-- Walked on the water: a swum link at a runner's pace (half of it where one end is the shore).
								if water and link > 0 then
									local wetThere = byte(tile, at + 2) % 2 == SWUM
									if wet or wetThere then link = max(1, floor(link * ((wet and wetThere) and WATER or (1 + WATER) / 2) + 0.5)) end
								end
								-- (Tier.Toll of the tier there: its tile's byte.)
								if roads and link > 0 then
									local there = (free[next] or byte(index == index0 and tollTile0 or tolls[index] or TollTile(search, index), at / RECORD + 1) % 2 == 1)
										and 1 or roadOff
									link = link * (toll + there) / 2 + 0.5
									link = link - link % 1
									if link < 1 then link = 1 end
								end
								local reached = sofar + link
								if link > 0 and (not had or (reached + 1) * KEPT <= had) then
									cost[next] = reached * KEPT + back * 2
									local dr, dc = nr - toRow, nc - toCol
									local far = sqrt(dr * dr + dc * dc) - SLACK
									if far > 0 then
										far = far * PACE
										reached = reached + far - far % 1
									end
									-- (Push: risen from the end.)
									local entry, up = reached * SPAN + next, hn + 1
									hn = up
									while up > 1 do
										local parent = (up - up % 2) / 2
										local above = heap[parent]
										if above <= entry then break end
										heap[up] = above
										up = parent
									end
									heap[up] = entry
								end
							end
						end
					end
				end
			end
			-- Every other link into it (from another tier, or to one): kept with the tiles of the node it leads
			-- from, this one or one round it. The way out of there is JOIN, and where it leads is in search.via.
			if joined then
				local into, intoToll = Tier.into, Tier.intoToll
				-- (A node inside its tile, the tile's links read: its links in are the tile's own, read here where
				-- they lie, as Tier.Ins reads them, with no call and no tile looked up; and each one's toll from the
				-- same tile's bytes. Else Tier.Ins lists them, with their tolls.)
				local first, last, ins, listed = 1, 0, nil, false
				local inRow, inCol = row % NODES, col % NODES
				if tile0 and inRow > 0 and inRow < NODES - 1 and inCol > 0 and inCol < NODES - 1 then
					local opened = data.joinsOpen
					local joins = opened and opened[index0]
					if joins then
						local slot = ((inRow + 1) * window + inCol + 1) * many + (node - base) / tierSpan
						local a, b, c, d = byte(joins.offs, slot * 2 + 1, slot * 2 + 4)
						ins, first, last = joins.ins, (a + b * 256) * 2 + 1, (c + d * 256) * 2
					elseif joins == nil then
						listed, last = true, Tier.Ins(data, node, into, roads and search, tolls, intoToll)
					end
				else
					listed, last = true, Tier.Ins(data, node, into, roads and search, tolls, intoToll)
				end
				for index = first, last, 2 do
					local next, link, fromRow, fromCol, tier
					if listed then
						next, link = into[index], into[index + 1]
					else
						local from
						from, link = byte(ins, index, index + 1)
						local way = from % 16
						fromRow, fromCol = row, col
						if way < 8 then fromRow, fromCol = row - ROW[way + 1], col - COL[way + 1] end
						tier = (from - way) / 16
						next = tier * tierSpan + fromRow * STRIDE + fromCol
					end
					local had = cost[next]
					if not had or (sofar + ((water and link > 0) and 1 or link) + 1) * KEPT <= had then
						if water then
							local wetThere = What(data, next) % 2 == SWUM
							if wet or wetThere then link = max(1, floor(link * ((wet and wetThere) and WATER or (1 + WATER) / 2) + 0.5)) end
						end
						if roads then
							local there
							if listed then
								there = intoToll[index + 1]
							else
								local bits = byte(tollTile0, (fromRow - row + inRow) * NODES + fromCol - col + inCol + 1)
								there = (free[next % tierSpan] or (tier == 0 and bits % 2 == 1) or (tier > 0 and (floor(bits / 2) % 2 == 1
									or floor(bits / 2 ^ (1 + tier)) % 2 == 1))) and 1 or roadOff
							end
							link = link * (toll + there) / 2 + 0.5
							link = link - link % 1
							if link < 1 then link = 1 end
						end
						local reached = sofar + link
						if not had or (reached + 1) * KEPT <= had then
							cost[next] = reached * KEPT + join * 2
							via[next] = node
							local from = next % tierSpan
							local fromCol = from % STRIDE
							local dr, dc = (from - fromCol) / STRIDE - toRow, fromCol - toCol
							local far = sqrt(dr * dr + dc * dc) - SLACK
							if far > 0 then
								far = far * PACE
								reached = reached + far - far % 1
							end
							local entry, up = reached * SPAN + next, hn + 1
							hn = up
							while up > 1 do
								local parent = (up - up % 2) / 2
								local above = heap[parent]
								if above <= entry then break end
								heap[up] = above
								up = parent
							end
							heap[up] = entry
						end
					end
				end
			end
			-- A lift that leads here from another tier (lifts go both ways): the way out of there is
			-- LIFT, and where it leads is kept in search.via.
			local ride = search.lifts and search.lifts[node]
			if ride then
				heap.n = hn
				for index = 1, #ride, 2 do
					local next = ride[index]
					local reached = sofar + ride[index + 1]
					local had = cost[next]
					if not had or reached < floor(had / KEPT) then
						cost[next] = reached * KEPT + LIFT * 2
						via[next] = node
						local from = next % tierSpan
						Push(heap, (reached + Guess(floor(from / STRIDE), from % STRIDE, toRow, toCol)) * SPAN + next)
					end
				end
				hn = heap.n
			end
			-- A drop that lands here from over a cliff, no deeper than a fall can be slowed now: the way out
			-- of there is FALL, and where it leads is kept in search.via. (Every drop looked at is noted, gone
			-- down or not, the deepest and the shallowest of each: Tier.Deep. Most nodes have none: their tile's
			-- drops are looked up here, with no call.)
			local drops = hasDrops and dropsOpen and index0 and dropsOpen[index0]
			if hasDrops and (drops == nil or (drops and drops[node])) then
				local falls, first, last = DropsTo(data, node, index0)
				dropsOpen = data.dropsOpen
				if falls then
					heap.n = hn
					for index = first, last, 4 do
						local steered, depth = falls[index + 3], falls[index + 1]
						local gone = dropping and depth <= (steered and glide or deep)
						if steered then
							if gone then
								if not search.gPass or depth > search.gPass then search.gPass = depth end
							elseif not search.gSkip or depth < search.gSkip then
								search.gSkip = depth
							end
						elseif gone then
							if not search.uPass or depth > search.uPass then search.uPass = depth end
						elseif not search.uSkip or depth < search.uSkip then
							search.uSkip = depth
						end
						if gone then
							local next = falls[index]
							local reached = sofar + falls[index + 2]
							local had = cost[next]
							if not had or reached < floor(had / KEPT) then
								cost[next] = reached * KEPT + FALL * 2
								via[next] = node
								search.steered[next] = steered or nil
								local from = next % tierSpan
								Push(heap, (reached + Guess(floor(from / STRIDE), from % STRIDE, toRow, toCol)) * SPAN + next)
							end
						end
					end
					hn = heap.n
				end
			end
			if node == target then break end
			if search.spent + looked >= MOST then
				search.far = true
				search.farFrom[target] = true
				break
			end
		end
	end
	heap.n = hn
	search.looked = search.looked + looked
	search.spent = search.spent + looked
	stats.nodes = stats.nodes + looked
end

-- Steers a search toward another tier: what is still to look at is ranked anew by how near it is.
-- A search is asked from many places (the player, the stop before, a flight master), and each has MOST
-- tiers of its own to be found in: one too far to work out leaves the next as free as the first. Only
-- once the search has looked at WORN in all is a place it hasn't reached too far as well.
-- (The heap is ranked anew where it stands: no new table for every place asked. A place too far is looked
-- at no more, and the heap stays ranked for the place it was, search.ranked, which toRow and toCol name.)
local seen = {}
local function Steer(search, key)
	if search.toKey == key then return end
	search.toKey = key
	search.spent = 0
	search.far = search.farFrom[key] or search.looked >= WORN
	if search.far or search.ranked == key then return end
	search.ranked = key
	local _, row, col = Tier.Node(key)
	search.toRow, search.toCol = row, col
	local cost, heap, tierSpan = search.cost, search.heap, Tier.SPAN
	wipe(seen)
	local n = 0
	for index = 1, heap.n do
		local node = heap[index] % SPAN
		local have = cost[node]
		if have % 2 == 0 and not seen[node] then
			seen[node] = true
			n = n + 1
			local base = node % tierSpan
			heap[n] = (floor(have / KEPT) + Guess(floor(base / STRIDE), base % STRIDE, row, col)) * SPAN + node
		end
	end
	Tier.Heapify(heap, n)
end

-- A heap's first n entries put in heap order, the rest let go: from the last parent up, each sinks below the
-- lesser of its children.
function Tier.Heapify(heap, n)
	for index = n + 1, heap.n do heap[index] = nil end
	heap.n = n
	for start = floor(n / 2), 1, -1 do
		local at, entry = start, heap[start]
		while true do
			local down = at * 2
			if down > n then break end
			local child = heap[down]
			if down < n and heap[down + 1] < child then
				down = down + 1
				child = heap[down]
			end
			if entry <= child then break end
			heap[at] = child
			at = down
		end
		heap[at] = entry
	end
end

-- The searches kept: by their goal (one goal: a number; several: a text), and by a caller's goals table.
local searches, count = {}, 0
local byGoals = setmetatable({}, { __mode = "k" })
local pending = {}             -- [search] = true: has more to do for whoever asked last
local closePending = {}        -- [job] = true: a search up close (below) with more to do for whoever asked last
local CloseStep                -- (below)
-- Places the nodes don't stand for (below): their ways in and out, found floor by floor.
--   ROUND: nodes round a place in which they are looked for. SPARE: 64ths of a second past the nearest
--   that another is still taken. WAYS: the most taken. MOST: floors looked at before giving up.
local Pocket = { ROUND = 6, SPARE = 10 * 64, WAYS = 6, MOST = 20000, ins = {}, kept = 0, pending = {}, places = {}, fixed = {}, fine = {},
	rode = {} }
local driver = CreateFrame("Frame")
driver:Hide()

local function Drop(search)
	searches[search.key] = nil
	pending[search] = nil
	if search.job then closePending[search.job] = nil end
	search.dropped = true
	count = count - 1
	-- (Whoever waited on it is asked again: Tier.Wait.)
	if next(Tier.waiting) ~= nil then
		Tier.settled = true
		driver:Show()
	end
end

-- Makes room for one more search; false when everything kept was asked for a moment ago. lead: for the
-- way someone is being led along now, which is never refused: the least lately asked makes room.
local function Room(lead)
	local held = 0
	for _, search in pairs(searches) do held = held + search.looked end
	while count >= SEARCHES or held >= HELD do
		local oldest
		for _, search in pairs(searches) do
			if not oldest or Tier.Sooner(oldest, search, true) then oldest = search end
		end
		if not oldest or (not lead and GetTime() - oldest.asked < IDLE) then
			stats.refused = stats.refused + 1
			return false
		end
		held = held - oldest.looked
		Drop(oldest)
	end
	return true
end

-- The search for a world's goals: { north, west, ... }. nil for no ground under any of them. Each goal is
-- reached on any tier of its node a floor round it is on (Tier.Goals).
-- level: the goals are on that level and their nodes on another (a cave under the hill its node stands
-- for, too small a one to be a tier of its own: Pocket.Split): each is gone into by its ways in on that
-- level, as a pocket is, not to its node. on: only the tiers of that look count (Tier.Levelled).
local nowhere = {}             -- [key] = true: goals with no ground under them
local function Begin(data, key, goals, lead, level, world, on, up)
	if nowhere[key] then return nil end
	-- (Room first: a search refused builds nothing to throw away, and one is asked again every pulse.)
	if not Room(lead) then return nil end
	local search = { data = data, key = key, cost = {}, heap = { n = 0 }, goalAt = {}, looked = 0, spent = 0, farFrom = {}, asked = GetTime(),
		toRow = -1, toCol = -1, lifts = data.liftsAt, via = {}, fall = fallDeep, glide = glideDeep, steered = {}, water = waterOn, level = level,
		noted = Tier.mayFall == true }
	-- (Kept to the roads: Tier.Toll.)
	local kept = Tier.Kept()
	local roads = kept and Tier.RoadsOf(world, data)
	-- (Only where it's dangerous: by what lives round each place, for the character's side. A world that tells
	-- nothing of it: everywhere for whoever asked to be kept to them there ("auto"), nowhere as it comes ("high":
	-- nothing is known to be too high).)
	local lives = roads and kept ~= "always" and roads.levels and roads.levels[UnitFactionGroup("player") or ""]
	if lives and next(lives) == nil then lives = nil end
	if roads and (lives or kept ~= "high") then
		search.roads, search.free, search.real, search.realFor = roads, Tier.Free(data, goals), {}, {}
		-- (search.me: the level from which what lives there is a danger: the character's own, or as it comes
		-- ROAD_ABOVE over it.)
		if lives then search.lives, search.me = lives, (UnitLevel("player") or 1) + (kept == "high" and Tier.ROAD_ABOVE or 0) end
	end
	local ground = world and Tier.GroundOf(world, data)
	for index = 1, #goals, 2 do
		local row, col = Stand(data, goals[index], goals[index + 1])
		if row and level then
			local off = search.off or {}
			search.off = off
			off[#off + 1], off[#off + 2], off[#off + 3], off[#off + 4], off[#off + 5] = (index + 1) / 2, goals[index], goals[index + 1], row, col
		elseif row then
			local keys, reached = Tier.Goals(data, ground, row, col, goals[index], goals[index + 1], on, up), false
			for _, node in ipairs(keys) do
				if not search.goalAt[node] then
					search.goalAt[node] = (index + 1) / 2
					search.cost[node] = 0
					Push(search.heap, node)
				end
				reached = reached or select(2, What(data, node))
			end
			-- (A place whose tiers the heart doesn't reach: a cave under a hill, a pocket. Its ways in: Pocket.)
			if not reached then
				local off = search.off or {}
				search.off = off
				off[#off + 1], off[#off + 2], off[#off + 3], off[#off + 4], off[#off + 5] = (index + 1) / 2, goals[index], goals[index + 1], row, col
			end
		end
	end
	if search.heap.n == 0 and not search.off then
		nowhere[key] = true
		return nil
	end
	searches[key] = search
	count = count + 1
	stats.searches = stats.searches + 1
	-- (Which was begun when: of searches asked for at the same moment, T.Work serves the latest begun first.)
	Tier.begun = (Tier.begun or 0) + 1
	search.serial = Tier.begun
	return search
end

local one = {}
-- level: the level a single goal is to be reached on, where it has floors on more than one. up: the height
-- it stands at, where that is known (the top of a tower, of the floors over each other there).
local function SearchFor(world, a, b, lead, level, up)
	local data = T.data.nodes[world]
	if not data then return nil end
	-- A lift learned since, or a fall slowed deeper or less deep (a spell learned, a reagent bought or used
	-- up, a cooldown begun or done), or the roads kept to or no longer: what was searched otherwise is out of date.
	local had, hadFall, hadDeep = data.liftsFor, data.fallFor, data.deepFor
	Lifts(world, data)
	data.fallFor = (waterOn and 1 or 0) * 1024 + select(2, Tier.Kept())
	data.deepFor = fallDeep * 1024 + glideDeep
	if (had and had ~= data.liftsFor) or (hadFall and hadFall ~= data.fallFor) then
		for _, search in pairs(searches) do
			if search.data == data then Drop(search) end
		end
		wipe(nowhere)
	elseif hadDeep and hadDeep ~= data.deepFor then
		-- (Only how deep a fall may be: a search every drop of whose was gone down, or not, as it would be now
		-- (none, mostly: a loot of a feather where no cliff was) goes on as it was. Tier.Deep.)
		for _, search in pairs(searches) do
			if search.data == data and not search.supposed then
				if Tier.Deep(search, fallDeep, glideDeep) then
					if search.uPass or search.gPass then search.near, search.whole = nil, nil end
					search.fall, search.glide, search.joinedNode = fallDeep, glideDeep, nil
				else
					Drop(search)
				end
			end
		end
		wipe(nowhere)
	end
	if type(a) == "table" then
		local search = byGoals[a]
		if search and not search.dropped then return search end
		local nodes = {}
		for index = 1, #a, 2 do
			local row, col = NodeAt(data, a[index], a[index + 1])
			nodes[#nodes + 1] = row * STRIDE + col
		end
		local key = world .. ":" .. table.concat(nodes, ",")
		search = searches[key] or Begin(data, key, a, lead, nil, world)
		if search then search.world = world end
		byGoals[a] = search
		return search
	end
	local row, col = NodeAt(data, a, b)
	local key = world * SPAN + row * STRIDE + col
	-- (On a level its node isn't on: a search of its own, that goes in on that level. On a level only some
	-- of its tiers are on: a search of its own, to those.)
	local split = level ~= nil and Pocket.Split(world, data, a, b, level)
	-- (At a height on none of its node's tiers: gone into as a pocket on that floor's level.)
	if not split and up then
		local look = Pocket.SplitUp(world, data, a, b, up)
		if look then split, level = true, look end
	end
	-- On the level asked for even when every tier shares that look: two of them can still be a cliff and
	-- the lake under it, and only the floors of that look, standing about as high, are the place.
	local on = nil
	if level ~= nil and not split then on = level end
	if split or on ~= nil then key = key .. "/" .. level end
	if up then
		up = floor(up + 0.5)
		key = key .. "^" .. up
	end
	one[1], one[2] = a, b
	local search = searches[key] or Begin(data, key, one, lead, split and level or nil, world, on, up)
	-- (The place itself, for the way's last yards up close: NearWay.)
	if search then search.world, search.north, search.west, search.up = world, a, b, up end
	return search
end

-- The node and the tier asked from: the same place is asked from many times a frame. (The tier: of the
-- floor stood on there, Tier.At.)
local fromData, fromNorth, fromWest, fromRow, fromCol, fromKey, fromStood
local function From(data, north, west, world)
	local ground = world and Tier.GroundOf(world, data)
	local stood_ = ground and Tier.stood[ground]
	if fromData ~= data or fromNorth ~= north or fromWest ~= west or fromStood ~= stood_ then
		fromData, fromNorth, fromWest, fromStood = data, north, west, stood_
		fromRow, fromCol = Stand(data, north, west)
		fromKey = fromRow and Tier.At(data, ground, fromRow, fromCol, north, west)
	end
	return fromRow, fromCol, fromKey
end

-- The tier a way goes on to from a tier, by the way out of it (a lift's, a drop's or a link to another
-- tier's: where search.via says).
local function Onward(search, node, way)
	if way == LIFT or way == FALL or way == Tier.JOIN then return search.via[node] end
	return node + ROW[way] * STRIDE + COL[way]
end

-- Which goal a node's way ends at.
local function GoalFrom(search, node)
	if search.goalNode ~= node then
		local cost, at = search.cost, node
		while true do
			local way = floor(cost[at] / 2) % 16
			if way == 0 then break end
			at = Onward(search, at, way)
		end
		search.goalNode, search.goal = node, search.goalAt[at]
	end
	return search.goal
end

local frame, spent
-- seconds and the goal; or nil and "working", or "far" and the least seconds it can be; or nil. Then
-- the search and the tier asked from, for the way. wait: worked out here and now. key: the tier asked from,
-- where it is known (the place of one: a pocket's way out ends there).
local function Answer(search, north, west, wait, key)
	local data = search.data
	local row, col, node = From(data, north, west, search.world)
	if key then row, col, node = floor(key % Tier.SPAN / STRIDE), key % STRIDE, key end
	if not row then return nil end
	-- (From someone on one of several floors, not yet known which: from whichever is the quickest, once each is
	-- known.)
	local unsure = not key and search.world and Tier.Unsure(data, search.world, north, west)
	if unsure then
		local best, working
		for index = 1, #unsure do
			local answer = { Answer(search, north, west, wait, unsure[index]) }
			if answer[1] and (not best or answer[1] < best[1]) then best = answer end
			if not answer[1] and answer[2] == "working" then working = true end
		end
		if working then return nil, "working" end
		if best then return unpack(best, 1, 5) end
	end
	search.asked = GetTime()
	local ticks = Known(search, node)
	if not ticks then
		if search.joinedNode ~= node then
			-- (A drop off a cliff joins what the ground alone doesn't: with a fall to slow, nothing is ruled out.)
			search.joinedNode, search.joined = node, (search.fall > 0 or search.glide > 0) and (data.falls or data.drops) ~= nil
			for goal in pairs(search.goalAt) do
				if search.joined then break end
				if Joined(data, node, goal) then
					search.joined = true
					break
				end
			end
		end
		-- Nothing leads there from here; or everything that does has been looked at. A place the nodes don't
		-- stand for is gone into floor by floor (once), and someone standing in one is led out (Pocket).
		if not search.joined or search.done then
			local entered = Pocket.Enter(search, wait)
			if entered == "working" then return nil, entered end
			if entered then return Answer(search, north, west, wait, key) end
			return Pocket.Out(search, north, west, row, col, wait, node)
		end
		Steer(search, node)
		if wait then
			while Wanted(search) do Step(search, 256) end
		else
			-- What a frame can spare, shared by all that is asked in it.
			local now = GetTime()
			if now ~= frame then frame, spent = now, 0 end
			while spent < NOW and Wanted(search) do
				local began = debugprofilestop()
				Step(search, 32)
				local took = debugprofilestop() - began
				spent = spent + took
				stats.ms = stats.ms + took
				if took > stats.stepMost then stats.stepMost = took end
				if took > stats.stepMark then stats.stepMark = took end
			end
		end
		ticks = Known(search, node)
		if not ticks then
			-- (Not reached at all: into a pocket by its ways in. Too far, or not reached, from a pocket: by its way out.)
			if search.done then
				local entered = Pocket.Enter(search, wait)
				if entered == "working" then return nil, entered end
				if entered then return Answer(search, north, west, wait, key) end
			end
			if search.far or search.done then
				local seconds, state, more, at, out = Pocket.Out(search, north, west, row, col, wait, node)
				if seconds or state == "working" then return seconds, state, more, at, out end
			end
			if search.far then
				local least = search.heap[1]
				if least then return nil, "far", floor(least / SPAN) * TICK / (search.roads and Tier.ROAD_OFF or 1) end
				return nil
			end
			if search.done then return nil end
			pending[search] = true
			driver:Show()
			-- Asked from a step further on than it is known from, as someone walking does: by way of the
			-- tier beside this one that it is known from, which is within a step of the quickest. (No
			-- SHY_TERRAIN for the little that is left to work out: the next asking has it.)
			local least, by
			if node < Tier.SPAN then
				local tile, at = Record(data, row, col)
				for way = 1, 8 do
					local link = byte(tile, at + 2 + way)
					local beside = node + ROW[way] * STRIDE + COL[way]
					local known = link > 0 and Known(search, beside)
					if known and (not least or known + link < least) then least, by = known + link, beside end
				end
			end
			local out = Tier.into
			for index = 1, Tier.Outs(data, node, out), 2 do
				local known = Known(search, out[index])
				if known and (not least or known + out[index + 1] < least) then least, by = known + out[index + 1], out[index] end
			end
			if least then
				if search.roads then least = least - Known(search, by) + Tier.Real(search, by) end
				return least * TICK, GoalFrom(search, by), search, by
			end
			search.waited = true
			stats.waited = stats.waited + 1
			return nil, "working"
		end
	end
	return Tier.Seconds(search, node), GoalFrom(search, node), search, node
end

-- What is left, a little a frame: each search with more to do gets SLICE nodes in turn, the way being led
-- along first, then those asked for most lately, round after round while the frame has time, so a few long
-- searches never starve the rest (served in no order, one of 64 nodes stood still for a minute behind two
-- of 20,000). A search nobody has asked for in STALE seconds stops costing frames; asked again, it goes on
-- from where it was.
local news, told = false, 0
T.STALE = 15
T.SLICE = 64
-- (On the Tier table: the file's main chunk is at Lua's limit of 200 locals.)
Tier.queue = {}
-- Whether a is to be served before b; asked: by when they were asked alone (and begun), not by the lead.
function Tier.Sooner(a, b, asked)
	if not asked and (a.lead or false) ~= (b.lead or false) then return a.lead == true end
	if a.asked ~= b.asked then return a.asked > b.asked end
	return (a.serial or 0) > (b.serial or 0)
end
-- (A search done that someone waited on: news, for its world.)
function Tier.Told(search)
	search.waited = nil
	news = true
	Tier.newsFrom[search.world or search.data] = true
	Tier.settled = true
end
Tier.newsFrom = {}
function T.Work(ms)
	local began = debugprofilestop()
	local now, n, queue, Sooner = GetTime(), 0, Tier.queue, Tier.Sooner
	-- (Someone waits to be told: nothing they may wait on is let rest.)
	local resting = next(Tier.waiting) == nil
	for search in pairs(pending) do
		if not Wanted(search) then
			pending[search] = nil
			if search.waited then Tier.Told(search) end
		elseif resting and now - search.asked > T.STALE then
			pending[search] = nil
		else
			n = n + 1
			queue[n] = search
		end
	end
	if n > 1 then table.sort(queue, Sooner) end
	local left, at = n, began
	while left > 0 do
		at = debugprofilestop()
		if at - began >= ms then break end
		for index = 1, n do
			local search = queue[index]
			if search then
				Step(search, T.SLICE)
				-- (The one read of the clock a slice: it ends this one, begins the next, and says if the frame's time is out.)
				local clock = debugprofilestop()
				local took = clock - at
				at = clock
				if took > stats.stepMost then stats.stepMost = took end
				if took > stats.stepMark then stats.stepMark = took end
				if not Wanted(search) then
					pending[search] = nil
					queue[index] = false
					left = left - 1
					if search.waited then Tier.Told(search) end
				end
				if at - began >= ms then break end
			end
		end
	end
	for index = 1, n do queue[index] = nil end
	T.worked = (T.worked or 0) + 1
	-- The searches up close still going, for the goal each was asked for last. (No SHY_TERRAIN when one is
	-- done: it changes no seconds, only the line drawn, and whoever draws it asks again at the next frame.
	-- Each SHY_TERRAIN has every listener work its route out anew.)
	for job in pairs(closePending) do
		local left = ms - (debugprofilestop() - began)
		if left <= 0 then break end
		if job.search.job == job and not job.found and not job.done then CloseStep(job, left) end
		if job.search.job ~= job or job.found or job.done then
			closePending[job] = nil
			Tier.settled = true
		end
	end
	-- Ways into and out of pockets (each changes seconds: SHY_TERRAIN when one is done).
	if next(Pocket.pending) ~= nil and Pocket.Work(ms - (debugprofilestop() - began)) then
		news = true
		Tier.settled = true
	end
	stats.ms = stats.ms + (debugprofilestop() - began)
	-- Whoever waits to be told is told what is known now (asked again: Tier.Wait); and so with nothing left
	-- going (what they waited on was let go to make room).
	local more = next(pending) ~= nil or next(closePending) ~= nil or next(Pocket.pending) ~= nil
	-- (Within the frame's budget, and a little past it for the first one told: the rest are told next frame,
	-- Tier.unfinished keeping the driver on for them.)
	if next(Tier.waiting) ~= nil and (Tier.settled or Tier.unfinished or not more or now - Tier.oldest > Tier.WAIT) then
		Tier.Tell(began + ms)
		Tier.unfinished = Tier.settled or nil
		more = next(pending) ~= nil or next(closePending) ~= nil or next(Pocket.pending) ~= nil
	end
	Tier.settled = nil
	if Tier.unfinished then more = true end
	if not more then driver:Hide() end
	-- Not for every search that ends while others go on: whoever listens works the lot out again.
	if news and (not more or GetTime() - told >= NEWS) then
		news, told = false, GetTime()
		-- (The world the searches done were of, where they were all of one.)
		local world, worlds = nil, 0
		for each in pairs(Tier.newsFrom) do
			worlds = worlds + 1
			world = type(each) == "number" and each or nil
		end
		wipe(Tier.newsFrom)
		Tier.News("found", worlds == 1 and world or nil)
	end
end

-- SHY_TERRAIN (why, world): what changed, and the world it is of (nil: any, or every). why: "found" (ways
-- being worked out are known), "ground" (a world's ground came in), "moves" (a fall that can be slowed, water
-- walked on, being dead), "roads" (keeping to them, or a level gained while that depends on it), "flights" (a
-- flight point learned). Whoever waits to be told (Tier.Wait) is asked again too.
function Tier.News(why, world)
	Tier.settled = true
	if next(Tier.waiting) ~= nil then driver:Show() end
	Shy:Fire("SHY_TERRAIN", why, world)
end
T.News = Tier.News

-- Told when known: Shy.Way.Ask's and AskWay's `done`. A call that answers "working" with one is made again
-- whenever something it may wait on has settled (a search done, a way up close found, a way into a cut-off
-- spot, SHY_TERRAIN), and done gets what that call gives, once it is anything but "working" (or WAIT seconds
-- on, whatever it is then). A function waits once: given again while it waits, it waits for the latest call.
Tier.waiting, Tier.WAIT, Tier.oldest = {}, 60, 0
function Tier.Wait(done, again)
	local entry = Tier.waiting[done]
	if not entry then
		if next(Tier.waiting) == nil then Tier.oldest = GetTime() end
		entry = { since = GetTime() }
		Tier.waiting[done] = entry
	end
	entry.again = again
	driver:Show()
end
do
	local told = {}
	-- stop: debugprofilestop() past which the rest wait for the next frame (they stay waiting, and are
	-- asked again then): each one asked may go on with a search, and a frame has only its budget.
	function Tier.Tell(stop)
		if Tier.settling then return end
		Tier.settling, Tier.settled = true, nil
		local now = GetTime()
		for done, entry in pairs(Tier.waiting) do told[#told + 1], told[#told + 2] = done, entry end
		for index = 1, #told - 1, 2 do
			local done, entry = told[index], told[index + 1]
			if stop and index > 1 and debugprofilestop() > stop then
				-- (Not reached this frame: still waiting, asked at the next. Settled again so it is.)
				Tier.settled = true
			elseif Tier.waiting[done] == entry then
				local ok, a, b, c, d = pcall(entry.again)
				if not ok then
					Tier.waiting[done] = nil
					geterrorhandler()(a)
				elseif b ~= "working" or now - entry.since > Tier.WAIT then
					Tier.waiting[done] = nil
					local fine, err = pcall(done, a, b, c, d)
					if not fine then geterrorhandler()(err) end
				end
			end
			told[index], told[index + 1] = nil, nil
		end
		Tier.oldest = now
		for _, entry in pairs(Tier.waiting) do
			if entry.since < Tier.oldest then Tier.oldest = entry.since end
		end
		Tier.settling = nil
	end
end
-- The searches with more to do, for the report and the tests: { { key, looked, asked, lead, pending }, ... },
-- those being worked (pending) and those paused unasked (T.STALE), by their goal.
function T.Pending()
	local out = {}
	for _, search in pairs(searches) do
		if not search.done and not search.far and search.toKey and not Known(search, search.toKey) then
			out[#out + 1] = { key = search.key, looked = search.looked, asked = search.asked, lead = search.lead == true, pending = pending[search] == true,
				north = search.north, west = search.west }
		end
	end
	return out
end

-- A frame's milliseconds on the ground in all, whatever they go to (what is asked at once, the searches up
-- close, what is left): NOW + BUDGET, shared in the order they come.
driver:SetScript("OnUpdate", Shy.Clocked("ground: a frame's work", function()
	local now = GetTime()
	if now ~= frame then frame, spent = now, 0 end
	-- (In a fight, half: the way can wait for the fight, the frame can't.)
	local budget = InCombatLockdown() and BUDGET * 0.5 or BUDGET
	local ms = math.min(budget, NOW + budget - spent)
	if ms <= 0 then return end
	local began = debugprofilestop()
	T.Work(ms)
	spent = spent + debugprofilestop() - began
end))
Shy.Clock("ground: a frame's work").idle = true   -- (standing still, nothing should be worked out)

function T.Has(world)
	return T.data.nodes[world] ~= nil
end

-- Shy.Way.Mark(into) -> into: what the ground has cost so far, for a caller timing a piece of work of its
-- own by what it took between two marks: into.tiles (tiles read), .inflates (texts unpacked), .floorMs (floor
-- tiles unpacked, ms), .step (the longest single step of a search since the last mark, ms).
function T.Mark(into)
	into.tiles, into.inflates, into.floorMs = stats.tiles, stats.inflates, stats.unpackMs
	into.step, stats.stepMark = stats.stepMark, 0
	return into
end

function T.Ask(world, north, west, a, b, level, up, done)
	if level == T.NOWHERE then return nil end
	if type(a) == "table" then level, up = nil, nil else level = Tier.Asked(world, a, b, level, up) end
	local search = SearchFor(world, a, b, nil, level, up)
	if not search then return nil end
	stats.asked = stats.asked + 1
	stats.by.seconds = stats.by.seconds + 1
	local seconds, goal, least = Answer(search, north, west)
	if seconds then return seconds, goal end
	if done and goal == "working" then
		Tier.Wait(done, function() return T.Ask(world, north, west, a, b, level, up) end)
	end
	return nil, goal, least
end

-- Whether the straight line between two places can be walked as it is drawn: every node it crosses is
-- ground all over (none of it rough) and leads on to the next (so no wall, and no cliff climbed) in
-- about the time the step takes. wet: it may cross water.
local WAY = { [-1] = { [-1] = 8, [0] = 1, [1] = 2 }, [0] = { [-1] = 7, [1] = 3 }, [1] = { [-1] = 6, [0] = 5, [1] = 4 } }
local function Straight(data, north, west, toNorth, toWest, wet)
	local steps = ceil(sqrt((toNorth - north) ^ 2 + (toWest - west) ^ 2) / (SIZE / 2))
	local row, col = NodeAt(data, north, west)
	local tile, at = Record(data, row, col)
	if not tile or byte(tile, at + 2) >= ROUGH then return false end
	local slow = wet and SLOW * 1.5 or SLOW
	for step = 1, steps do
		local along = step / steps
		local nr, nc = NodeAt(data, north + (toNorth - north) * along, west + (toWest - west) * along)
		if nr ~= row or nc ~= col then
			local dr, dc = nr - row, nc - col
			if dr < -1 or dr > 1 or dc < -1 or dc > 1 then return false end
			local link = byte(tile, at + 2 + WAY[dr][dc])
			if link == 0 or link > ((dr ~= 0 and dc ~= 0) and slow * 1.42 or slow) then return false end
			tile, at = Record(data, nr, nc)
			local what = tile and byte(tile, at + 2) or ROUGH
			if what >= ROUGH or (not wet and what % 2 == SWUM) then return false end
			row, col = nr, nc
		end
	end
	return true
end

-- Where a link's way bends: the points it goes by over the floors between the two places, kept where it
-- strays from the straight line between them (round a cliff's foot, up a ravine to the top). data.bent: by
-- tile, the links from its nodes that bend: the node's number in the tile, the way (0 to 7 round by north,
-- 8 to another tier of the node), its tier * data.tiered + the tier it leads to, how many points, then
-- three bytes a point: its cell's row and column in the tile, counted from data.bendEdge cells north and
-- west of it, and what it is (1 swum, + 2 * its level). Ground kept without tiers has data.bends: the
-- node's number, the way * 32 + how many, then the points, counted from Bend.EDGE cells off. The tile's
-- bytes, where the link's points begin and how many; nil for a link walked straight. (Bend.Begun, below,
-- is the way led along begun floor by floor.)
local Bend = {
	EDGE = 8,                  -- cells round a tile the bends of ground kept without tiers may stray into
	LEAD = 4000,               -- yards (as the crow flies) of a way led along that are found floor by floor: all of a walk, near
	                           -- enough (a way over nodes goes by node places tens of yards off the floors' own way; so led
	                           -- along it turns under the walker where the floors take over). Through the lane of nodes it goes
	                           -- by (Pocket.Lane) it costs some 13 floors a yard
	MOST = 80000,              -- floors the search up close for such a way looks at before it gives up (Close.MOST's 16 times:
	                           -- down Teldrassil's winding ramps it takes some 40,000)
	NEAR = 150,                -- yards of it found floor by floor where that gives up (Bend.Begun)
}
function Bend.At(data, from, to, step)
	local tiered = data.bent ~= nil
	local bends = data.bent or data.bends
	if not bends or not to or step == LIFT or step == FALL then return nil end
	local _, row, col, tier = Tier.Node(from)
	local _, toRow, toCol, toTier = Tier.Node(to)
	local dr, dc = toRow - row, toCol - col
	local way = (dr == 0 and dc == 0) and 8 or (WAY[dr] and WAY[dr][dc] and WAY[dr][dc] - 1)
	if not way or (not tiered and (way == 8 or tier > 0 or toTier > 0)) then return nil end
	local tileRow, tileCol = floor(row / NODES), floor(col / NODES)
	if tileRow < 0 or tileCol < 0 or tileRow >= data.rows or tileCol >= data.cols then return nil end
	local index = tileRow * data.cols + tileCol + 1
	local opened = data.bendsOpen
	if not opened then
		opened = {}
		data.bendsOpen = opened
	end
	local open = opened[index]
	if open == nil then
		open = false
		local text = bends[index]
		if text and not data.plain then text = Unpacked(text) end
		if text then
			open = { text = text }
			local at = 1
			while at < #text do
				if tiered then
					local here, out, tiers, count = byte(text, at, at + 3)
					open[(here * 9 + out) * 16 + tiers] = at + 4
					at = at + 4 + count * 3
				else
					local here, told = byte(text, at, at + 1)
					open[here * 8 + floor(told / 32)] = at + 2
					at = at + 2 + told % 32 * 3
				end
			end
		end
		opened[index] = open
	end
	if not open then return nil end
	local here = (row % NODES) * NODES + col % NODES
	local at = open[tiered and (here * 9 + way) * 16 + tier * (data.tiered or 4) + toTier or here * 8 + way]
	if not at then return nil end
	local text = open.text
	return text, at, tiered and byte(text, at - 1) or byte(text, at - 1) % 32, data.bendEdge or Bend.EDGE
end

-- The way from a node a search is done with, to its goal: its nodes' places, with every stretch that
-- is walked straight as quickly made one (a way over nodes steps like a staircase, which nobody
-- walks), and between two places the points a link bends by (Bend.At). A point is kept wherever it turns,
-- and where it enters or leaves water. way.fine[point]: it is on the floors' own way (a bend, and the
-- places either side of one), which a map rounds as little as a way found up close.
--   reach: only its first so many yards (way.cut: it stops short of the goal), for whoever shows no more
--   and asks often. Each kind is kept apart, for the node it was last asked from.
local norths, wests, swims, looks, ups, fell, steeredAt = {}, {}, {}, {}, {}, {}, {}
local function WayOf(search, node, reach)
	local kept = reach and search.near or search.whole
	if not kept then
		kept = {}
		search[reach and "near" or "whole"] = kept
	end
	if kept.node ~= node or kept.reach ~= reach then
		local data, cost = search.data, search.cost
		local last, at, gone, cut, bent = 0, node, 0, false, false
		-- (fixed: a point of a way in's floors, or of a link's bends, kept as it is. fine: on the floors' way.)
		local fixed, fine = Pocket.fixed, Pocket.fine
		-- (Kept to the roads: by each road's own cells, not the node's place yards off it, and never
		-- straightened off it.)
		local roads = search.roads
		while true do
			local _, row, col, tier = Tier.Node(at)
			last = last + 1
			norths[last], wests[last], swims[last], looks[last], ups[last] = Tier.Place(data, at)
			fixed[last], fine[last] = false, bent
			local onRoad = roads and tier == 0 and looks[last] == T.GROUND and Tier.RoadNode(roads, row, col)
			if onRoad then
				norths[last] = (32 - data.row) * TILE - (row * 8 + floor(onRoad / 8) + 0.5) * CELL
				wests[last] = (32 - data.col) * TILE - (col * 8 + onRoad % 8 + 0.5) * CELL
				fixed[last] = true
			end
			if last > 1 then gone = gone + sqrt((norths[last] - norths[last - 1]) ^ 2 + (wests[last] - wests[last - 1]) ^ 2) end
			local step = floor(cost[at] / 2) % 16
			fell[last] = step == FALL
			Pocket.rode[last] = step == LIFT
			steeredAt[last] = step == FALL and search.steered[at] or false
			if step == 0 then
				-- A way in to a place the nodes don't stand for: on along its floors to the place itself.
				local inside = search.inside and search.inside[at]
				if inside then
					for point = 2, inside.n do
						last = last + 1
						norths[last], wests[last], swims[last] = inside[point * 3 - 2], inside[point * 3 - 1], inside[point * 3]
						looks[last], ups[last], fell[last], steeredAt[last], fixed[last], fine[last] = inside.look[point], inside.up[point], false, false, true, false
						Pocket.rode[last] = false
					end
				end
				break
			end
			if reach and gone >= reach then
				cut = true
				break
			end
			-- (The link's bends, between this place and the next: where its way strays from the straight line.)
			local next = Onward(search, at, step)
			local text, first, count, edge = Bend.At(data, at, next, step)
			bent = text ~= nil
			if text then
				fine[last] = true
				local cellRow, cellCol = floor(row / NODES) * NODES * 8 - edge, floor(col / NODES) * NODES * 8 - edge
				for point = first, first + (count - 1) * 3, 3 do
					local r, c, what = byte(text, point, point + 2)
					last = last + 1
					norths[last] = (32 - data.row) * TILE - (cellRow + r + 0.5) * CELL
					wests[last] = (32 - data.col) * TILE - (cellCol + c + 0.5) * CELL
					swims[last], looks[last], ups[last] = what % 2 == 1, floor(what / 2) % 4, nil
					fell[last], steeredAt[last], fixed[last], fine[last] = false, false, true, true
					Pocket.rode[last] = false
					gone = gone + sqrt((norths[last] - norths[last - 1]) ^ 2 + (wests[last] - wests[last - 1]) ^ 2)
				end
			end
			at = next
		end
		local way = { seconds = Tier.Seconds(search, node), yards = 0, n = 0, goal = GoalFrom(search, node), cut = cut, look = {}, up = {} }
		local from = 1
		for index = 1, last do
			-- Kept: the first and the last, the two either side of a shore or of a change of level or of a
			-- drop, and the one before the first that can't be walked to straight from the last kept.
			local rode = Pocket.rode
			local keep = index == 1 or index == last or fixed[index] or fixed[index + 1] or swims[index] ~= swims[index - 1] or swims[index] ~= swims[index + 1]
				or looks[index] ~= looks[index - 1] or looks[index] ~= looks[index + 1] or fell[index] or fell[index - 1]
				or rode[index] or rode[index - 1]
			if not keep and not Straight(data, norths[from], wests[from], norths[index + 1], wests[index + 1], swims[from]) then keep = true end
			if keep then
				local spot = way.n * 3
				way[spot + 1], way[spot + 2], way[spot + 3] = norths[index], wests[index], swims[index]
				way.n = way.n + 1
				way.look[way.n], way.up[way.n] = looks[index], ups[index]
				if fine[index] then
					way.fine = way.fine or {}
					way.fine[way.n] = true
				end
				-- (way.drop[point]: the stretch that ends at that point is a drop off a cliff, a fall slowed by
				-- way.fall, the spell.)
				if index > 1 and fell[index - 1] then
					way.drop = way.drop or {}
					way.drop[way.n] = true
					-- (Steered there: the glide's spell, and way.steer; else the slowed fall's.)
					way.fall = steeredAt[index - 1] and glideSpell or fallSpell
					way.steer = way.steer or steeredAt[index - 1] or nil
				end
				-- (way.lift[point]: the stretch that ends at that point is a lift's ride.)
				if index > 1 and rode[index - 1] then
					way.lift = way.lift or {}
					way.lift[way.n] = true
				end
				-- (way.water: the spell it walks on water by, where it crosses any.)
				if search.water and swims[index] then way.water = waterSpell end
				if index > 1 then way.yards = way.yards + sqrt((norths[index] - norths[from]) ^ 2 + (wests[index] - wests[from]) ^ 2) end
				from = index
			end
		end
		kept.node, kept.reach, kept.way = node, reach, way
	end
	return kept.way
end

-- The ground up close ---------------------------------------------------------------------------
-- A node is 33 yards of ground: a way over nodes says which side of the mountain, not where to put
-- one's feet. For the stretch just ahead of someone (what a minimap shows) the ground is also kept cell
-- by cell, a cell 4.17 yards, and floor by floor (ShyWay_Ground_<world>\Floors.lua, T.data.floors[world], tiles as the
-- nodes' are). Most cells are one floor. Where a building, a bridge or a cave stands a cell has several:
-- the street and the room over it, either side of a wall. Each floor knows which of the eight ways a
-- step leads from it and onto which floor of the next cell, whether it is swum, the level it is on,
-- its height, and which quarter-cells of its cell are it. The beginning of a way is searched over
-- those, from the floor the player stands on to where the way over nodes is `reach` yards on: up a
-- winding stair a floor at a time, through the door and not the wall.
-- T.data.floors[world] = { col, row, cols, rows, tiles = { [n] = text, or 1 (open ground), or 2 (open water) } }

local CELLS = 128              -- cells a tile, each way
local CSTRIDE = 32768          -- a cell's number is its row * CSTRIDE + its column
-- The search up close, measured (what its inner steps read stays a local of its own, below).
local Close = {
	LAYOUT = 2,                -- how a tile's floors are kept (Unpack): a world's ground kept otherwise isn't read
	PLAIN = CELLS * CELLS + CELLS * CELLS / 8,   -- bytes a tile of one floor a cell
	MOST = 5000,               -- floors one search up close looks at before it gives up (each is some hundredths of a millisecond)
	NOW = 2.5,                 -- milliseconds a frame spent at once on the searches up close asked in it, with what else was
	                           -- asked at once in it (Answer's `spent`: one frame's share of the ground in all is NOW +
	                           -- BUDGET); most are done in less, the rest go on over the frames that follow
	JOBS = 6,                  -- searches up close kept, for the goals asked last
	GOAL = 250,                -- yards: a goal nearer than this is searched for up close all the way
	FLOOR_ONLY = 600,          -- ... and one the nodes know no way to, nearer than this (a bridge they miss)
	FAILED_AGAIN = 6,          -- cells a search up close that found nothing is not tried again within, for the same goal
	GOAL_ROUND = 2,            -- cells round a goal with no floor under it in which the nearest with one is looked for
	LEVEL_ROUND = 6,           -- cells round a goal asked for on a level no floor there is on in which the nearest on it
	                           -- are looked for (25 yards: as far as a place's level is told by what stands round it)
	OPENED = 32,               -- tiles of cells kept unpacked (a search up close crosses more than 16: each came back
	                           -- unpacked anew, three times over, and what that threw away was most of the ground's)
}

-- A world's ground up close, where it is kept the way it is read and lines up with its nodes.
local function GroundOf(world, data)
	local ground = T.data.floors[world]
	if data and ground and ground.layout == Close.LAYOUT and ground.col == data.col and ground.row == data.row then return ground end
end
local FSTRIDE = 2 ^ 28         -- a floor's number is which of its cell's it is * FSTRIDE + its cell's
local CSPAN = 2 ^ 31           -- a heap's entry is a floor's rank * CSPAN + its number
local CKEPT = 256              -- what is kept of a floor in the search up close: 64ths of a second to the goal * CKEPT, the floor
                               -- the way leads to * 32, the way out * 2, and 1 once it is done with
local STEP, SLANT = 38, 54     -- what a step to the next cell takes at a walk, straight and cornerwise: 64ths of a second
local WADE = 1.48              -- ... times this in water
local TIGHT = 1.25             -- ... and times this from a floor that hasn't every step open: a way keeps clear of an edge where it
                               -- can. (Under WADE: a bridge is all edge, and is still taken before the river is swum.)
Close.EAGER = 1.35             -- how much more the search up close makes of what is left than of what is behind it
Close.AHEAD = STEP * Close.EAGER   -- ... so a cell of straight line still to go counts this many 64ths (Least)
local SUB = 4                  -- quarter-cells a cell, each way: what a floor says it is of its cell
local BIT = { 1, 2, 4, 8, 16, 32, 64, 128 }

-- Roads -------------------------------------------------------------------------------------------
-- Whoever keeps to the roads (Shy.Way.SetPaths) is led along them: to a search every step off a road takes
-- ROAD_OFF times as long, so a way leaves a road only where going round by it takes that much longer, or
-- within ROAD_FREE yards of where it goes (the quest is off the road). A level up (a bridge, an upper
-- floor) is never off one. Kept to them only where it's dangerous, a step off a road costs that only where
-- something that would attack the character lives within reach (Tier.Safe), elsewhere the way is the shortest:
-- as it comes ("high") something ROAD_ABOVE levels over them or more, land they have no business crossing;
-- asked for ("auto"), something of their level or higher. The seconds a way is said to
-- take are those it takes (Tier.Real). T.data.roads[world] (ShyWay_Ground_<world>\Roads.lua): { col, row,
-- cols, rows, tiles = { [n] = text }, levels = { Alliance = { [n] = text }, Horde = ... } }, tiles numbered as
-- the nodes'; a road tile a bit a cell, row after row from the north-west, the lowest bit of a byte first;
-- a levels tile a byte a node, row after row: the highest level of what attacks that side within reach
-- (0: nothing; a tile left out: nothing anywhere in it).
Tier.ROAD_OFF = 2.5
Tier.ROAD_ABOVE = 5            -- levels over the character: what is this far above them or more is a danger as it comes ("high")
Tier.ROAD_FREE = 250           -- yards round a goal (Close.GOAL's: what is that near is gone to floor by floor)
Tier.ROAD_LEAST = 4            -- road cells of a node's 64, at the least, for a road to run through it
Tier.chain = {}                -- (the keys of a way, Tier.Real)

-- A world's roads, where they ship and line up with its nodes.
function Tier.RoadsOf(world, data)
	local roads = world and T.data.roads[world]
	if roads and data and roads.col == data.col and roads.row == data.row and roads.cols == data.cols then return roads end
end

-- A tile's road cells (CELLS * CELLS / 8 bytes), unpacked the first time; false for a tile with none.
function Tier.RoadTile(roads, tileRow, tileCol)
	if tileRow < 0 or tileCol < 0 or tileRow >= roads.rows or tileCol >= roads.cols then return false end
	local index = tileRow * roads.cols + tileCol + 1
	local open = roads.open
	if not open then
		open = {}
		roads.open = open
	end
	local tile = open[index]
	if tile == nil then
		local kept = roads.tiles[index]
		if kept and not roads.plain then kept = Unpacked(kept) end
		tile = (kept and #kept == CELLS * CELLS / 8) and kept or false
		open[index] = tile
	end
	return tile
end

-- Whether a cell is road.
function Tier.OnRoad(roads, row, col)
	if row < 0 or col < 0 then return false end
	local tile = Tier.RoadTile(roads, floor(row / CELLS), floor(col / CELLS))
	if not tile then return false end
	local at = (row % CELLS) * CELLS + col % CELLS
	return floor(byte(tile, floor(at / 8) + 1) / BIT[at % 8 + 1]) % 2 == 1
end

-- A tile's nodes a road runs through, read the first time: [the node's number in the tile] = its road cell
-- nearest the middle of the road's cells in it (0 to 63, as a node's place), where the way is drawn by; false
-- for a tile with none. (A node's row of 8 cells is one byte of its tile's.)
function Tier.RoadNodes(roads, tileRow, tileCol)
	local index = tileRow * roads.cols + tileCol + 1
	roads.nodesOpen = roads.nodesOpen or {}
	local nodes = roads.nodesOpen[index]
	if nodes == nil then
		nodes = false
		local tile = Tier.RoadTile(roads, tileRow, tileCol)
		if tile then
			nodes = {}
			for n = 0, NODES * NODES - 1 do
				local nodeRow, nodeCol = floor(n / NODES), n % NODES
				local count, rows, cols = 0, 0, 0
				-- (Most nodes have no road cell: their eight bytes are read before any bit is.)
				local first = nodeRow * 8 * (CELLS / 8) + nodeCol + 1
				local b0, b1, b2, b3, b4, b5, b6, b7 = byte(tile, first), byte(tile, first + CELLS / 8), byte(tile, first + 2 * (CELLS / 8)),
					byte(tile, first + 3 * (CELLS / 8)), byte(tile, first + 4 * (CELLS / 8)), byte(tile, first + 5 * (CELLS / 8)),
					byte(tile, first + 6 * (CELLS / 8)), byte(tile, first + 7 * (CELLS / 8))
				if b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7 > 0 then
					for r = 0, 7 do
						local bits = byte(tile, (nodeRow * 8 + r) * (CELLS / 8) + nodeCol + 1)
						for c = 0, 7 do
							if bits % 2 == 1 then count, rows, cols = count + 1, rows + r, cols + c end
							bits = floor(bits / 2)
						end
					end
				end
				if count >= Tier.ROAD_LEAST then
					local midRow, midCol, best, least = rows / count, cols / count, nil, nil
					for r = 0, 7 do
						local bits = byte(tile, (nodeRow * 8 + r) * (CELLS / 8) + nodeCol + 1)
						for c = 0, 7 do
							local far = (r - midRow) ^ 2 + (c - midCol) ^ 2
							if bits % 2 == 1 and (not least or far < least) then best, least = r * 8 + c, far end
							bits = floor(bits / 2)
						end
					end
					nodes[n] = best
				end
			end
		end
		roads.nodesOpen[index] = nodes
	end
	return nodes
end

-- The road cell a node is drawn by (0 to 63), where a road runs through it; else nil.
function Tier.RoadNode(roads, row, col)
	if row < 0 or col < 0 then return nil end
	local nodes = Tier.RoadNodes(roads, floor(row / NODES), floor(col / NODES))
	return nodes and nodes[(row % NODES) * NODES + col % NODES] or nil
end

-- The nodes within ROAD_FREE of any of a search's goals ({ north, west, ... }), as free[node] = true.
function Tier.Free(data, goals)
	local free, reach = {}, ceil(Tier.ROAD_FREE / SIZE)
	for index = 1, #goals - 1, 2 do
		local row, col = NodeAt(data, goals[index], goals[index + 1])
		for dr = -reach, reach do
			for dc = -reach, reach do
				if dr * dr + dc * dc <= reach * reach then free[(row + dr) * STRIDE + col + dc] = true end
			end
		end
	end
	return free
end

-- Whether a node is no danger to a search kept to the roads only where it's dangerous (search.lives: the
-- levels tiles of the character's side; search.me: the level a danger begins at): nothing there that attacks
-- them is that level or higher. Kept to the roads everywhere (no search.lives), never.
function Tier.Safe(search, row, col)
	local lives = search.lives
	if not lives then return false end
	if row < 0 or col < 0 then return true end
	local tileRow, tileCol = floor(row / NODES), floor(col / NODES)
	local roads = search.roads
	if tileRow >= roads.rows or tileCol >= roads.cols then return true end
	local index = tileRow * roads.cols + tileCol + 1
	local open = lives.open
	if not open then
		open = {}
		lives.open = open
	end
	local tile = open[index]
	if tile == nil then
		local kept = lives[index]
		if kept and not roads.plain then kept = Unpacked(kept) end
		tile = (kept and #kept == NODES * NODES) and kept or false
		open[index] = tile
	end
	return not tile or byte(tile, (row % NODES) * NODES + col % NODES + 1) < search.me
end

-- What a step onto or off a tier costs, as a share of its time: 1 on a road, a level up, near a goal or
-- where it's safe; else ROAD_OFF. (A node's other tiers by their look alone: the tunnel under a road is no road.)
function Tier.Toll(search, key)
	return Tier.TollOf(search, Tier.Tolls(search), key)
end

-- The same, with the tiles of tolls at hand (Tier.Tolls): a key's toll is its node's byte of them (Tier.TollTile).
function Tier.TollOf(search, tolls, key)
	local tierSpan = Tier.SPAN
	local tier = floor(key / tierSpan)
	local node = key - tier * tierSpan
	if search.free[node] then return 1 end
	local row, col = floor(node / STRIDE), node % STRIDE
	local data = search.data
	local tileRow, tileCol = floor(row / NODES), floor(col / NODES)
	if row < 0 or col < 0 or tileRow >= data.rows or tileCol >= data.cols then
		-- (Off the world's ground: no record, no tiers.)
		if Tier.Safe(search, row, col) then return 1 end
		return (tier == 0 and Tier.RoadNode(search.roads, row, col)) and 1 or Tier.ROAD_OFF
	end
	local index = tileRow * data.cols + tileCol + 1
	local bits = byte(tolls[index] or Tier.TollTile(search, index), (row - tileRow * NODES) * NODES + col - tileCol * NODES + 1)
	if tier == 0 then return bits % 2 == 1 and 1 or Tier.ROAD_OFF end
	return (floor(bits / 2) % 2 == 1 or floor(bits / 2 ^ (1 + tier)) % 2 == 1) and 1 or Tier.ROAD_OFF
end

-- The tiles of tolls a search kept to the roads reads (roads.tollOpen): for the character's side and level
-- (roads.tollLives, roads.tollMe; a change of either starts them again). Searches share them: every search
-- going at a time is for the one character.
function Tier.Tolls(search)
	local roads = search.roads
	local open = roads.tollOpen
	if not open or roads.tollLives ~= search.lives or roads.tollMe ~= search.me then
		open = {}
		roads.tollOpen, roads.tollLives, roads.tollMe = open, search.lives, search.me
	end
	return open
end

-- A tile's nodes as a search kept to the roads sees them, a byte a node (as the tile's records lie): 1 where
-- a step onto its tier 0 costs nothing more (a road runs through it, it is a level up, or nothing there is a
-- danger to the character: Tier.Safe); 2 where nothing there is a danger; 2 ^ (1 + k) where its tier k (1 and
-- up) is a level up. Made once a tile (256 nodes) and read a byte a step, in place of three lookups and a
-- division a neighbour; search.free (the goal's surroundings) is looked at beside it. index: the tile's
-- number, as Record gives it.
do
	local bytes = {}
	function Tier.TollTile(search, index)
		local roads, data = search.roads, search.data
		local open = Tier.Tolls(search)
		local tile = open[index]
		if tile then return tile end
		local tileRow, tileCol = floor((index - 1) / data.cols), (index - 1) % data.cols
		local nodes = Tier.RoadTile(roads, tileRow, tileCol) and Tier.RoadNodes(roads, tileRow, tileCol)
		local text = Tile(data, tileRow, tileCol)
		local tiers = Tier.Tile(data, tileRow, tileCol)
		for n = 0, NODES * NODES - 1 do
			local row, col = tileRow * NODES + floor(n / NODES), tileCol * NODES + n % NODES
			local safe = Tier.Safe(search, row, col)
			local bits = safe and 2 or 0
			if (nodes and nodes[n] ~= nil) or (text and byte(text, n * RECORD + 11) == T.ABOVE) or safe then bits = bits + 1 end
			local at = tiers and tiers[n]
			if at then
				-- (Its tiers' looks, as Tier.Place reads them: the third byte of each tier's record.)
				local count, tiersText = byte(tiers.text, at), tiers.text
				for tier = 1, count - 1 do
					if byte(tiersText, at + 1 + tier * Tier.RECORD + 2) == T.ABOVE then bits = bits + 2 ^ (1 + tier) end
				end
			end
			bytes[n + 1] = bits
		end
		tile = char(unpack(bytes, 1, NODES * NODES))
		open[index] = tile
		return tile
	end
end

-- Whether a floor up close (its cell and level) is off a road where that counts, for a search up close kept
-- to them (a job: its roads, free, lives and me, as its search's).
-- (Asked for every step up close: Tier.OnRoad read here, and each floor by arithmetic, with no call.)
function Tier.Off(job, row, col, level)
	if level == T.ABOVE then return false end
	local nodeRow, nodeCol = (row - row % 8) / 8, (col - col % 8) / 8
	if job.free[nodeRow * STRIDE + nodeCol] then return false end
	if row >= 0 and col >= 0 then
		local tile = Tier.RoadTile(job.roads, (row - row % CELLS) / CELLS, (col - col % CELLS) / CELLS)
		if tile then
			local at = (row % CELLS) * CELLS + col % CELLS
			local bit = BIT[at % 8 + 1]
			if byte(tile, (at - at % 8) / 8 + 1) % (bit + bit) >= bit then return false end
		end
	end
	return not Tier.Safe(job, nodeRow, nodeCol)
end

-- What a step onto or off a floor up close costs, as Tier.Toll.
function Tier.CellToll(job, row, col, level)
	return Tier.Off(job, row, col, level) and Tier.ROAD_OFF or 1
end

-- How this character's ways keep to the roads now: false (they don't, or they are dead), "always", or "high" or
-- "auto" (where it's dangerous, Tier.Safe: what is too high for them, or their level and higher); then a number
-- that changes with it (and with their level, where that counts).
function Tier.Kept()
	local mode = T.Paths()
	if mode == "never" or Tier.dead then return false, 0 end
	if mode == "always" then return "always", 1 end
	return mode, (mode == "high" and 3 or 2) + (UnitLevel("player") or 0) * 4
end

-- The ticks a way from a key to the goal takes, where its search keeps to roads and so knows only what its
-- steps cost: each step's over its toll, along the way, a goal's own as it was seeded (a way into a
-- pocket). Kept for each key gone by, for as long as what the search holds of it is the same.
function Tier.Real(search, key)
	local cost, real, held, chain = search.cost, search.real, search.realFor, Tier.chain
	local n, at, after = 0, key, nil
	while true do
		local have = cost[at]
		if not have then
			after = 0
			break
		end
		if held[at] == have then
			after = real[at]
			break
		end
		n = n + 1
		chain[n] = at
		local way = floor(have / 2) % 16
		if way == 0 then break end
		at = Onward(search, at, way)
	end
	for index = n, 1, -1 do
		local each = chain[index]
		local have = cost[each]
		local ticks
		if not after then
			ticks = floor(have / KEPT)
		else
			local onto = chain[index + 1] or at
			local step = floor(have / KEPT) - floor((cost[onto] or 0) / KEPT)
			local way = floor(have / 2) % 16
			if way ~= LIFT and way ~= FALL then step = step * 2 / (Tier.Toll(search, each) + Tier.Toll(search, onto)) end
			ticks = after + step
		end
		real[each], held[each], after = ticks, have, ticks
	end
	return after
end

-- The seconds from a key a search is done with to its goal.
function Tier.Seconds(search, key)
	if search.roads then return Tier.Real(search, key) * TICK end
	return floor(search.cost[key] / KEPT) * TICK
end

-- A tile as it is kept unpacked: a text for one of one floor a cell (the steps from each cell, then
-- which are swum), or for one with more to say a table that reads its floors from the text where they
-- lie, nothing copied out: .s the text; .told[cell] where the cell's floors are told (the first's number *
-- 16 + how many: a cell's are together, floor 0 first), .records where they begin and .n how many there
-- are; .leads[cell] where the steps to floors other than 0 from the cell's floors are (the first's number
-- * 1024 + how many), .steps where they begin and .m how many. Floors and steps are kept field by field
-- (every one's first byte, then every one's second...): a field's bytes are much alike, and pack small.
-- false for one that doesn't unpack.
-- Where each cell's entries begin in a list of `count` kept field by field from `at` (the cells' low bytes
-- first, then their high bytes), into[cell] = the first's number * scale + how many. (Read a few hundred
-- bytes a call: a call a byte is most of what unpacking a city's tile costs; read into two tables kept for
-- it, not a new pair each time: a tile is unpacked again whenever it comes back into use, and the pairs were
-- most of what the ground threw away.)
local Index
do
	local lows, highs = {}, {}
	function Index(kept, at, count, into, scale)
		local last
		for first = 1, count, 16 do
			local final = first + 15 < count and first + 15 or count
			local a, b = at + first, at + count + first
			lows[1], lows[2], lows[3], lows[4], lows[5], lows[6], lows[7], lows[8], lows[9], lows[10], lows[11], lows[12], lows[13],
				lows[14], lows[15], lows[16] = byte(kept, a, a + final - first)
			highs[1], highs[2], highs[3], highs[4], highs[5], highs[6], highs[7], highs[8], highs[9], highs[10], highs[11], highs[12],
				highs[13], highs[14], highs[15], highs[16] = byte(kept, b, b + final - first)
			for index = first, final do
				local cell = lows[index - first + 1] + highs[index - first + 1] * 256
				if cell == last then
					into[cell] = into[cell] + 1
				else
					-- (A list not in the order of its cells: none is read a row at a time from then on, Close.Peek.)
					if last and cell < last then Close.whole = true end
					into[cell], last = (index - 1) * scale + 1, cell
				end
			end
		end
	end
end

-- A list looked into a row of cells at a time. Most tiles are unpacked for a place or two (where a way is asked
-- from, where it leads: a few cells of a tile of sixteen thousand), and a town's list is tens of thousands long:
-- read whole for one cell, it was most of what asking the ground of a new place cost. A list is in the order of
-- its cells (as the ground is made; Index says where one isn't), so a row's entries are found by halving and
-- read when a cell of that row is first asked of; past PEEKS rows (a search up close is crossing the tile) the
-- rest is read at once and the table is a plain one again, as quick to read as it ever was.
Close.PEEKS = 24               -- rows of a list read one at a time before the whole of it is
Close.PEEK_LEAST = 512         -- a list shorter than this is read whole at once
Close.peeks = setmetatable({}, { __mode = "k" })   -- [told or leads] = { s, at, count, scale, rows = {}, n }
Close.lazy = { __index = function(into, cell)
	local peek = Close.peeks[into]
	if not peek or type(cell) ~= "number" then return nil end
	local row = floor(cell / CELLS)
	if peek.rows[row] then return nil end
	local kept, at, count, scale = peek.s, peek.at, peek.count, peek.scale
	if peek.n >= Close.PEEKS or Close.whole then
		Close.peeks[into] = nil
		setmetatable(into, nil)
		Index(kept, at, count, into, scale)
		return into[cell]
	end
	peek.rows[row], peek.n = true, peek.n + 1
	-- The first entry of the row's first cell, or of the first cell after it that has any.
	local from, low, high = row * CELLS, 1, count + 1
	while low < high do
		local mid = floor((low + high) / 2)
		if byte(kept, at + mid) + byte(kept, at + count + mid) * 256 < from then low = mid + 1 else high = mid end
	end
	local last
	for index = low, count do
		local each = byte(kept, at + index) + byte(kept, at + count + index) * 256
		if each >= from + CELLS then break end
		if each == last then
			into[each] = into[each] + 1
		else
			into[each], last = (index - 1) * scale + 1, each
		end
	end
	return rawget(into, cell)
end }
function Close.Peek(kept, at, count, into, scale)
	if count < Close.PEEK_LEAST or Close.whole then return Index(kept, at, count, into, scale) end
	Close.peeks[into] = { s = kept, at = at, count = count, scale = scale, rows = {}, n = 0 }
	setmetatable(into, Close.lazy)
end
Tier.Close = Close   -- (for a test of how a tile's lists are read)

local function Unpack(kept)
	local plain = Close.PLAIN
	if not kept or #kept < plain then return false end
	if #kept == plain then return kept end
	local at = plain
	if #kept < at + 3 then return false end
	local floors = byte(kept, at + 1) + byte(kept, at + 2) * 256 + byte(kept, at + 3) * 65536
	at = at + 3
	if #kept < at + floors * 9 + 3 then return false end
	local told, leads = {}, {}
	local tile = { s = kept, told = told, leads = leads, records = at, n = floors }
	Close.Peek(kept, at, floors, told, 16)
	at = at + floors * 9
	local steps = byte(kept, at + 1) + byte(kept, at + 2) * 256 + byte(kept, at + 3) * 65536
	at = at + 3
	if #kept < at + steps * 4 then return false end
	tile.steps, tile.m = at, steps
	Close.Peek(kept, at, steps, leads, 1024)
	return tile
end

-- A tile that made room for another is kept a while as it was unpacked (ground.older, the OLDER let go of
-- last, each with when it was last used), until a rinse: a way led along goes back and forth over more tiles
-- than are kept, and each unpacked again was a few milliseconds and as much thrown away.
Tier.OLDER = 16
function Tier.Older(ground, index, tile, stamp)
	if type(tile) ~= "table" and type(tile) ~= "string" then return end
	local older, used = ground.older, ground.olderUsed
	if not older then
		older, used = {}, {}
		ground.older, ground.olderUsed = older, used
	end
	local n, oldest, least = 0, nil, nil
	for other, at in pairs(used) do
		n = n + 1
		if not least or at < least then oldest, least = other, at end
	end
	if n >= Tier.OLDER then older[oldest], used[oldest] = nil, nil end
	older[index], used[index] = tile, stamp
end

-- A tile's cells; 1 or 2 for one that is open all over; false for none. The Close.OPENED a player was last
-- near are kept unpacked; the one asked for longest ago makes room for another.
local clock = 0
local function CellTile(ground, tileRow, tileCol)
	if tileRow < 0 or tileCol < 0 or tileRow >= ground.rows or tileCol >= ground.cols then return false end
	local index = tileRow * ground.cols + tileCol + 1
	local open = ground.open
	if not open then
		open = {}
		ground.open, ground.opened, ground.used = open, 0, {}
	end
	local tile = open[index]
	if tile == nil then
		-- (Let go of lately: back as it was, not unpacked again.)
		local older = ground.older
		if older and older[index] ~= nil then
			tile, older[index], ground.olderUsed[index] = older[index], nil, nil
		else
			local kept = ground.tiles[index]
			if type(kept) == "string" then
				local began = debugprofilestop()
				if not ground.plain then kept = Unpacked(kept) end
				kept = Unpack(kept)
				local took = debugprofilestop() - began
				stats.unpackMs = stats.unpackMs + took
				if took > stats.unpackMost then stats.unpackMost = took end
			end
			tile = kept or false
			stats.tiles = stats.tiles + 1
		end
		if ground.opened >= Close.OPENED then
			local oldest, stamp
			for other, used in pairs(ground.used) do
				if not stamp or used < stamp then oldest, stamp = other, used end
			end
			Tier.Older(ground, oldest, open[oldest], stamp)
			open[oldest], ground.used[oldest] = nil, nil
			ground.opened = ground.opened - 1
		end
		open[index] = tile
		ground.opened = ground.opened + 1
	end
	clock = clock + 1
	ground.used[index] = clock
	return tile
end

-- The tile a cell is in and its number there (false for no ground).
local function CellIn(ground, row, col)
	if row < 0 or col < 0 then return false end
	local tile = CellTile(ground, floor(row / CELLS), floor(col / CELLS))
	return tile, (row % CELLS) * CELLS + col % CELLS
end

-- How many floors a cell has.
local function Floors(tile, at)
	if not tile then return 0 end
	if tile == 1 or tile == 2 then return 1 end
	local text = tile
	if type(tile) == "table" then
		local told = tile.told[at]
		if told then return told % 16 end
		text = tile.s
	end
	return byte(text, at + 1) > 0 and 1 or 0
end

-- A floor of a cell: the steps from it to the next cells' floor 0 (a byte: BIT[way] where that way can
-- be stepped), whether it is swum, whether a step leads every way, the level it is on, and where they
-- are told: its height, which quarter-cells of the cell are it, whether it is water deep enough to fall
-- into unharmed, and whether it is steep ground (slid down).
local function Floor(tile, at, k)
	if tile == 1 then return 255, false, true, 0 end
	if tile == 2 then return 255, true, true, 0 end
	local text = tile
	if type(tile) == "table" then
		text = tile.s
		local told = tile.told[at]
		if told then
			if k >= told % 16 then return 0, false, false, 0 end
			local n = tile.n
			local from = tile.records + floor(told / 16) + k + 1
			local steps, what = byte(text, from + 3 * n), byte(text, from + 4 * n)
			local mask = byte(text, from + 5 * n) + byte(text, from + 6 * n) * 256
			return steps, what % 2 == 1, floor(what / 8) % 2 == 1, floor(what / 2) % 4,
				(byte(text, from + 7 * n) + byte(text, from + 8 * n) * 256 - 20000) / 2, mask, floor(what / 16) % 2 == 1,
				floor(what / 32) % 2 == 1
		end
	end
	if k > 0 or not text then return 0, false, false, 0 end
	local steps = byte(text, at + 1)
	return steps, floor(byte(text, CELLS * CELLS + floor(at / 8) + 1) / BIT[at % 8 + 1]) % 2 == 1, steps == 255, 0
end

-- The floors of the next cell a step leads to, that way from a floor whose steps to floor 0 are
-- `steps`: 2 ^ floor for each (0: none).
local function Leads(tile, at, k, way, steps)
	local onto = floor(steps / BIT[way]) % 2
	if type(tile) == "table" then
		local leads = tile.leads[at]
		if leads then
			local text, want, m = tile.s, k * 8 + way - 1, tile.m
			local from = tile.steps + floor(leads / 1024) + 1
			for spot = from, from + leads % 1024 - 1 do
				if byte(text, spot + 2 * m) == want then onto = onto + 2 ^ byte(text, spot + 3 * m) end
			end
		end
	end
	return onto
end

-- The cell a place is in, and where a cell's middle is.
local function CellAt(data, north, west)
	return floor(((32 - data.row) * TILE - north) / CELL), floor(((32 - data.col) * TILE - west) / CELL)
end
local function CellPlace(data, row, col)
	return (32 - data.row) * TILE - (row + 0.5) * CELL, (32 - data.col) * TILE - (col + 0.5) * CELL
end

-- Where a floor is: the middle of the quarter-cells that are it (its cell's middle where they aren't told).
local function FloorPlace(data, ground, row, col, k)
	local north, west = CellPlace(data, row, col)
	local tile, at = CellIn(ground, row, col)
	if type(tile) ~= "table" then return north, west end
	local _, _, _, _, _, mask = Floor(tile, at, k)
	if not mask or mask == 0 or mask == 65535 then return north, west end
	local rows, cols, count = 0, 0, 0
	for bit = 0, 15 do
		if mask % 2 == 1 then
			rows, cols, count = rows + floor(bit / 4), cols + bit % 4, count + 1
		end
		mask = floor(mask / 2)
	end
	return north + (1.5 - rows / count) * CELL / 4, west + (1.5 - cols / count) * CELL / 4
end

-- The floors a place may be on, as their numbers in `into`: those of its cell whose quarter-cell it is
-- in, else all of its cell's. Returns how many.
local function FloorsAt(data, ground, north, west, into)
	local row, col = CellAt(data, north, west)
	local tile, at = CellIn(ground, row, col)
	local count = Floors(tile, at)
	if count == 0 then return 0 end
	local cell = row * CSTRIDE + col
	if type(tile) ~= "table" or not tile.told[at] then
		into[1] = cell
		return 1
	end
	local quarter = floor(((32 - data.row) * TILE - north) / (CELL / 4)) % 4 * 4 + floor(((32 - data.col) * TILE - west) / (CELL / 4)) % 4
	local found = 0
	for k = 0, count - 1 do
		local _, _, _, _, _, mask = Floor(tile, at, k)
		if mask and floor(mask / 2 ^ quarter) % 2 == 1 then
			found = found + 1
			into[found] = k * FSTRIDE + cell
		end
	end
	if found == 0 then
		for k = 0, count - 1 do into[k + 1] = k * FSTRIDE + cell end
		found = count
	end
	return found
end

-- The search up close: as the one over nodes, from the floors the way leads to back toward the floors
-- asked from. It is kept for its goals as a job (job.near: what it found, as search.cost; job.heap), so
-- asked again from a few steps on, where it has been already, it has the answer there and then; and where
-- it hasn't, it is steered there and goes on. What a frame can't spare is done over the frames that follow.
local jobs = {}                -- the jobs kept, the one asked for longest ago first

-- What is left from a cell to the cell aimed at, at the least: the straight line; weighed over what it is
-- (Close.EAGER), so the search heads for the player and finds a way within a little of the quickest after looking
-- at far less. (The line, not the steps a cell at a time, cornerwise then straight: of the many ways of as
-- many steps over open ground, that led along the one furthest from the line, an elbow nobody walks; by the
-- line the way found keeps beside it, and what turns it is what stands in the way.)
local function Least(r, c, row, col)
	local dr, dc = r - row, c - col
	return (dr * dr + dc * dc) ^ 0.5 * Close.AHEAD
end

-- A job for a search's goals (goals[1 .. goalCount]; costs: the 64ths of a second from each to the place, none
-- for 0): the Close.JOBS asked for last are kept. (The one that makes room gives the new one its floors and heap,
-- emptied: a search up close for a way led along holds tens of thousands of floors, and each thrown away was
-- most of what the ground threw away. Nothing holds a job once it has made room. Tier.spare is let go at a rinse.)
Tier.spare = {}
local function CloseBegin(search, ground, key, goals, goalCount, costs)
	if #jobs >= Close.JOBS then
		local oldest = table.remove(jobs, 1)
		closePending[oldest] = nil
		if oldest.search.job == oldest then oldest.search.job = nil end
		local spare = Tier.spare
		if #spare < 2 then
			local heap = oldest.heap
			for index = 1, heap.n do heap[index] = nil end
			heap.n = 0
			wipe(oldest.near)
			spare[#spare + 1] = { near = oldest.near, heap = heap }
		end
		oldest.near, oldest.heap = nil, nil
	end
	local reuse = table.remove(Tier.spare)
	local job = { search = search, ground = ground, key = key, near = reuse and reuse.near or {}, heap = reuse and reuse.heap or { n = 0 }, wanted = {},
		looked = 0, most = Close.MOST, wade = search.water and 1 or WADE, roads = search.roads, free = search.free, lives = search.lives, me = search.me }
	for index = 1, goalCount do
		local cost = costs and costs[index] or 0
		job.near[goals[index]] = cost * CKEPT
		Push(job.heap, cost * CSPAN + goals[index])
	end
	jobs[#jobs + 1] = job
	search.job = job
	return job
end

-- The floor asked from (starts[1 .. startCount]) that a job is done with already, the quickest; nil for none.
local function CloseKnown(job, starts, startCount)
	local near, best, least = job.near, nil, nil
	for index = 1, startCount do
		local have = near[starts[index]]
		if have and have % 2 == 1 and (not least or have < least) then best, least = starts[index], have end
	end
	return best
end

-- Aims a job at the floors asked from: what it has still to look at is ranked anew by how near it is to
-- them (they are a cell of each other: the first is aimed at).
local function CloseAim(job, starts, startCount)
	local wanted = job.wanted
	wipe(wanted)
	for index = 1, startCount do wanted[starts[index]] = true end
	job.found = nil
	local aim = starts[1] % FSTRIDE
	local row, col = floor(aim / CSTRIDE), aim % CSTRIDE
	if job.row == row and job.col == col then return end
	local steer = job.row ~= nil
	job.row, job.col = row, col
	if not steer then return end
	-- (Ranked anew where it stands, as Steer does: no new heap each time someone takes a step.)
	local near, heap = job.near, job.heap
	wipe(seen)
	local n = 0
	for index = 1, heap.n do
		local id = heap[index] % CSPAN
		local have = near[id]
		if have % 2 == 0 and not seen[id] then
			seen[id] = true
			n = n + 1
			local cell = id % FSTRIDE
			heap[n] = floor(floor(have / CKEPT) + Least(floor(cell / CSTRIDE), cell % CSTRIDE, row, col)) * CSPAN + id
		end
	end
	Tier.Heapify(heap, n)
end

-- Looks at floors for up to `ms` milliseconds (or until it finds one asked from: job.found; or has nothing
-- more to look at, or has looked at as many as it may: job.done).
function CloseStep(job, ms)
	local ground, near, heap, wanted, row, col, wade = job.ground, job.near, job.heap, job.wanted, job.row, job.col, job.wade
	-- (Aimed at the floors asked from; or, lean 0, nearest first all round: Pocket's ways in.)
	local ahead = Close.AHEAD * (job.lean or 1)
	-- (Only through the nodes job.corridor has, where it has any: a way led along, the way over nodes and round it.)
	local corridor = job.corridor
	-- (Kept to the roads: Tier.CellToll.)
	local roads = job.roads
	local began = debugprofilestop()
	-- The tile the last cell looked round was in: most of a cell's neighbours are in it too.
	local lastRow, lastCol, lastTile = -1, -1, false
	local looked, most = job.looked, job.most
	-- (As Step: the heap popped and pushed in place, Least worked out here, and a step looked at only where it
	-- could make a way quicker: no step is quicker than a walk on open ground, STEP or SLANT.)
	local byte, floor, Floor, Leads, CellTile, CellToll = byte, floor, Floor, Leads, CellTile, Tier.CellToll
	local ROW, COL, BACK, BIT, CKEPT, CSPAN, FSTRIDE, CSTRIDE = ROW, COL, BACK, BIT, CKEPT, CSPAN, FSTRIDE, CSTRIDE
	local hn = heap.n
	while true do
		if hn == 0 or looked >= most then
			job.done = true
			break
		end
		-- (The stopwatch every so many floors: looking at it costs too.)
		if looked % 32 == 0 and debugprofilestop() - began >= ms then break end
		local top, last = heap[1], heap[hn]
		heap[hn] = nil
		hn = hn - 1
		if hn > 0 then
			local at = 1
			while true do
				local down = at + at
				if down > hn then break end
				local child = heap[down]
				if down < hn then
					local right = heap[down + 1]
					if right < child then down, child = down + 1, right end
				end
				if child >= last then break end
				heap[at] = child
				at = down
			end
			heap[at] = last
		end
		local id = top % CSPAN
		local have = near[id]
		if have % 2 == 0 then
			near[id] = have + 1
			looked = looked + 1
			if wanted[id] then
				job.found = id
				break
			end
			local sofar = (have - have % CKEPT) / CKEPT
			local cell = id % FSTRIDE
			local k = (id - cell) / FSTRIDE
			local c = cell % CSTRIDE
			local r = (cell - c) / CSTRIDE
			local here = 2 ^ k
			local _, wet, _, levelHere, upHere, _, deep, steepHere = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, k)
			local toll = roads and CellToll(job, r, c, levelHere)
			for way = 1, 8 do
				local nr, nc = r + ROW[way], c + COL[way]
				if nr >= 0 and nc >= 0 and (not corridor or corridor[floor(nr / 8) * STRIDE + floor(nc / 8)]) then
					local tileRow, tileCol = floor(nr / CELLS), floor(nc / CELLS)
					if tileRow ~= lastRow or tileCol ~= lastCol then
						lastRow, lastCol, lastTile = tileRow, tileCol, CellTile(ground, tileRow, tileCol)
					end
					local tile = lastTile
					if tile then
						local at = (nr % CELLS) * CELLS + nc % CELLS
						local back = BACK[way]
						local walk = way % 2 == 1 and STEP or SLANT
						local cellId = nr * CSTRIDE + nc
						-- How many floors there are, and for a cell of one floor (the most), the step from it here.
						local floors, steps, swum, open
						if tile == 1 or tile == 2 then
							floors, steps, swum, open = 1, 255, tile == 2, true
						elseif type(tile) == "string" or not tile.told[at] then
							local text = type(tile) == "string" and tile or tile.s
							steps = byte(text, at + 1)
							floors, open = steps > 0 and 1 or 0, steps == 255
							if floors == 1 then
								local had = near[cellId]
								if had and (sofar + walk + 1) * CKEPT > had then
									floors = 0
								else
									swum = floor(byte(text, CELLS * CELLS + floor(at / 8) + 1) / BIT[at % 8 + 1]) % 2 == 1
								end
							end
						else
							floors = tile.told[at] % 16
						end
						for from = 0, floors - 1 do
							local next = from * FSTRIDE + cellId
							local had = near[next]
							if not had or (sofar + walk + 1) * CKEPT <= had then
								local leads, upThere, steepThere, levelThere
								if steps then
									-- (One floor, and no step from it but to floor 0s: Leads's own answer, quicker.)
									leads = (k == 0 and floor(steps / BIT[back]) % 2 == 1) and 1 or 0
									if type(tile) == "table" then leads = Leads(tile, at, from, back, steps) end
								else
									steps, swum, open, levelThere, upThere, _, _, steepThere = Floor(tile, at, from)
									leads = Leads(tile, at, from, back, steps)
									steps = nil
								end
								-- The step that leads here from there.
								if floor(leads / here) % 2 == 1 then
									local step = walk * ((wet and wade or 1) + (swum and wade or 1)) / 2
									if not open then step = step * TIGHT end
									if roads then step = step * (toll + CellToll(job, nr, nc, levelThere or T.GROUND)) / 2 end
									-- (Heights are told where a cell has floors over each other, and at either end of a fall.
									-- Into water deeper than a character is tall, a fall does no harm.)
									if upThere and upHere and not deep then
										local fall, straight = upThere - upHere, way % 2 == 1
										if fall > (straight and Tier.SLIDE_STRAIGHT or Tier.SLIDE_CORNER)
											or (not steepHere and not steepThere and fall > (straight and Tier.FALL_STRAIGHT or Tier.FALL_CORNER)) then
											step = step + fall * Tier.FALL_TICKS
										end
									end
									local reached = sofar + floor(step + 0.5)
									if not had or (reached + 1) * CKEPT <= had then
										near[next] = reached * CKEPT + k * 32 + back * 2
										-- (Least, then the push.)
										local dr, dc = nr - row, nc - col
										local entry = floor(reached + (dr * dr + dc * dc) ^ 0.5 * ahead) * CSPAN + next
										local up = hn + 1
										hn = up
										while up > 1 do
											local parent = (up - up % 2) / 2
											local above = heap[parent]
											if above <= entry then break end
											heap[up] = above
											up = parent
										end
										heap[up] = entry
									end
								end
							end
						end
					end
				end
			end
		end
	end
	heap.n = hn
	stats.cells = stats.cells + looked - job.looked
	job.looked = looked
end

-- The floor a player is taken to be on, of those a place may be on: the one a few steps lead to from the
-- floor they were last seen on (Tier.rider: T.Saw follows them every second), so that a balcony walked up
-- to isn't left for the hall under it; else the one walked onto from where the last way began (a step off
-- it, or the same), so that a bridge isn't left for the road under it by crossing it. Just off a flight
-- (Tier.landed), the topmost: a flight lands in the open, on the tower's top and never in the hall under
-- it. Where that says nothing (a first look, a lift), all of them.
local stood = {}               -- [ground] = the floor the last way began on
local function Standing(ground, starts, count)
	if count > 1 and Tier.landed then
		local best, high
		for index = 1, count do
			local cell = starts[index] % FSTRIDE
			local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
			local height = select(5, Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(starts[index] / FSTRIDE)))
			if height and (not high or height > high) then best, high = index, height end
		end
		if best then
			starts[1] = starts[best]
			return 1
		end
	end
	local rider = Tier.rider
	-- (First seen and not yet known which: of those indoors or not, as the game says they are. T.Saw.)
	if count > 1 and rider and rider.ground == ground and not rider.floor and rider.choices then
		local kept = 0
		for index = 1, count do
			if rider.choices[starts[index]] then
				kept = kept + 1
				starts[index], starts[kept] = starts[kept], starts[index]
			end
		end
		if kept > 0 then count = kept end
	end
	-- (A floor of the same cell they are known to stand on, though the spot's quarter isn't of it.)
	if count > 0 and rider and rider.ground == ground and rider.floor and rider.floor % FSTRIDE == starts[1] % FSTRIDE then
		local among = false
		for index = 1, count do among = among or starts[index] == rider.floor end
		if not among then
			starts[1] = rider.floor
			return 1
		end
	end
	if count > 1 and rider and rider.ground == ground and rider.floor then
		local reach = Tier.Reach(ground, rider.floor)
		-- (Nearest in steps first: of a ramp's turns over each other, the one they are on.)
		local best, least
		for index = 1, count do
			local steps = reach[starts[index]]
			if steps and (not least or steps < least) then best, least = starts[index], steps end
		end
		if best then
			starts[1] = best
			return 1
		end
	end
	local was = stood[ground]
	if count < 2 or not was then return count end
	local wasK, wasCell = floor(was / FSTRIDE), was % FSTRIDE
	local wasRow, wasCol = floor(wasCell / CSTRIDE), wasCell % CSTRIDE
	local tile, at = CellIn(ground, wasRow, wasCol)
	local kept = 0
	for index = 1, count do
		local id = starts[index]
		local cell = id % FSTRIDE
		local dr, dc = floor(cell / CSTRIDE) - wasRow, cell % CSTRIDE - wasCol
		local on = id == was
		if not on and tile and dr >= -1 and dr <= 1 and dc >= -1 and dc <= 1 and (dr ~= 0 or dc ~= 0) then
			on = floor(Leads(tile, at, wasK, WAY[dr][dc], (Floor(tile, at, wasK))) / 2 ^ floor(id / FSTRIDE)) % 2 == 1
		end
		if on then
			kept = kept + 1
			starts[kept] = id
		end
	end
	return kept > 0 and kept or count
end

-- Which tier a place is on (Tiers, above) -------------------------------------------------------------
Tier.GroundOf, Tier.stood = GroundOf, stood

-- The tier node (row, col) of `n` tiers (text, at: Tier.Of's) has floor `id` on: floor 0's by the node's
-- map, another's as the ground tells it (Tier.Storey), else by its height (a cell of one floor keeps none).
function Tier.OfFloor(data, ground, row, col, n, text, at, id)
	local k, cell = floor(id / FSTRIDE), id % FSTRIDE
	local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
	if k > 0 then
		local told = Tier.Storey(data, row, col, k, (r % 8) * 8 + c % 8)
		if told then return told end
		local _, _, _, _, height = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, k)
		if height then return Tier.Spanned(text, at, n, height) end
	end
	return Tier.Mapped(text, at, n, (r % 8) * 8 + c % 8)
end

-- The key of whoever is at a place, on node (row, col): the tier of the floor they stand on, of those there
-- (FloorsAt; the one walked onto from where they last stood: Standing), else of the first there. pick:
-- "low" the lowest floor there (a lift's foot), "high" the highest (its head). Tier 0 for a node of one
-- tier, a place off the node (no node where it is: the nearest's), or ground up close not kept.
function Tier.At(data, ground, row, col, north, west, pick)
	local node = row * STRIDE + col
	local n, text, at = Tier.Of(data, row, col)
	if n <= 1 or not ground then return node end
	local cellRow, cellCol = CellAt(data, north, west)
	if floor(cellRow / 8) ~= row or floor(cellCol / 8) ~= col then return node end
	local floors = Tier.floors
	local count = FloorsAt(data, ground, north, west, floors)
	if count == 0 then return node end
	local id = floors[1]
	if pick == "high" then
		id = floors[count]
	elseif not pick then
		Standing(ground, floors, count)
		id = floors[1]
	end
	return Tier.OfFloor(data, ground, row, col, n, text, at, id) * Tier.SPAN + node
end

-- Someone first seen where there are several floors (a login, a hearthstone: Ironforge's halls under the
-- mountain's top, a camp in a cave under a mesa) stands on one nothing says yet (Tier.rider.floor nil). Asked
-- from there (within Tier.SAME yards), the keys of the tiers of those floors, when more than one: the way is
-- worked out from each and the quickest taken (Answer); nil otherwise.
Tier.SAME, Tier.here = 3, {}
Tier.LED = 12                  -- yards from where someone was last seen within which a way found is the way they are led along
Tier.BACK = 3                  -- floors of that way behind the one they were on that they may still be taken to have gone back to
function Tier.Unsure(data, world, north, west)
	local rider = Tier.rider
	if rider.floor or rider.world ~= world or not rider.north
		or (north - rider.north) ^ 2 + (west - rider.west) ^ 2 > Tier.SAME * Tier.SAME then
		return nil
	end
	local ground = GroundOf(world, data)
	if not ground or rider.ground ~= ground then return nil end
	local row, col = Stand(data, north, west)
	if not row then return nil end
	local n, text, at = Tier.Of(data, row, col)
	local cellRow, cellCol = CellAt(data, north, west)
	if n <= 1 or floor(cellRow / 8) ~= row or floor(cellCol / 8) ~= col then return nil end
	local floors = Tier.here
	local count = Standing(ground, floors, FloorsAt(data, ground, north, west, floors))
	local keys, seen_ = {}, {}
	for index = 1, count do
		local key = Tier.OfFloor(data, ground, row, col, n, text, at, floors[index]) * Tier.SPAN + row * STRIDE + col
		if not seen_[key] then
			seen_[key] = true
			keys[#keys + 1] = key
		end
	end
	return #keys > 1 and keys or nil
end

-- The floors of a key's node that are on its tier, into into[1 ...]: how many.
function Tier.FloorsOf(data, ground, key, into)
	local _, row, col, tier = Tier.Node(key)
	local n, text, at = Tier.Of(data, row, col)
	local count = 0
	for r = row * 8, row * 8 + 7 do
		for c = col * 8, col * 8 + 7 do
			local tile, cell = CellIn(ground, r, c)
			for k = 0, Floors(tile, cell) - 1 do
				local id = k * FSTRIDE + r * CSTRIDE + c
				if (n > 1 and Tier.OfFloor(data, ground, row, col, n, text, at, id) or 0) == tier then
					count = count + 1
					into[count] = id
				end
			end
		end
	end
	return count
end

-- A way found from floor `id`: where it isn't known which floor someone stands on, and `id` is one of those at
-- their place, it is the one.
function Tier.Settle(data, ground, id)
	local rider = Tier.rider
	if rider.floor or rider.ground ~= ground or not rider.north then return end
	local floors = Tier.here
	for index = 1, FloorsAt(data, ground, rider.north, rider.west, floors) do
		if floors[index] == id then
			rider.floor, rider.choices = id, nil
			return
		end
	end
end

-- The floors on `level` nearest a cell that has none on it, into into[1 ...]: those of the nearest ring of
-- cells round it that has any which lead anywhere, Close.LEVEL_ROUND cells off at the most. How many (0 for
-- none that near). The last answer is kept: a way being worked out asks it again in every frame.
Pocket.levelled, Pocket.levelFor = {}, {}
function Pocket.Level(ground, row, col, level, into)
	local kept = Pocket.levelFor
	if kept.ground == ground and kept.row == row and kept.col == col and kept.level == level then
		for index = 1, kept.n do into[index] = kept[index] end
		return kept.n
	end
	local count = 0
	for ring = 1, Close.LEVEL_ROUND do
		for r = row - ring, row + ring do
			-- (A ring's cells: all of its top and bottom rows, the two ends of those between.)
			local edge = r == row - ring or r == row + ring
			for c = col - ring, col + ring, edge and 1 or 2 * ring do
				local tile, cell = CellIn(ground, r, c)
				for k = 0, Floors(tile, cell) - 1 do
					local _, _, _, look = Floor(tile, cell, k)
					if look == level and Pocket.Leads(tile, cell, k) then
						count = count + 1
						into[count] = k * FSTRIDE + r * CSTRIDE + c
					end
				end
			end
		end
		if count > 0 then break end
	end
	kept.ground, kept.row, kept.col, kept.level, kept.n = ground, row, col, level, count
	for index = 1, count do kept[index] = into[index] end
	return count
end

-- The keys a goal at a place is reached on: the tiers of every floor of its cell and of the cells round it,
-- whichever node they are in (a place has no height, and whoever stands there may be a yard from a wall,
-- or behind a counter that is spoken to over); else every tier of its node (row, col: Stand's). on: of
-- those, the ones of that look where there are any. A floor of a cell round it counts only when it stands
-- about as high as one of the place's own (Tier.BESIDE): the water at the foot of a cliff is not a way of
-- arriving on the cliff. up: the height the goal stands at, where it is known; of the place's own floors,
-- only those that near it (Tier.UP_NEAR) where there are any: the top of a tower, not the hall at its foot.
function Tier.Goals(data, ground, row, col, north, west, on, up)
	local keys, seen = {}, {}
	if ground then
		local cellRow, cellCol = CellAt(data, north, west)
		local heights, land, wet
		local aimed = up ~= nil and Tier.Near(ground, cellRow, cellCol, up)
		-- (None of the place's own floors that high, but one of a cell round it: someone behind a counter,
		-- spoken to from the floor in front of it; someone in a shop the floors don't know, two cells from the
		-- hall's. Of all those cells, as far out as the nearest that has one (Tier.NearRound, as Pocket.Floors
		-- looks), only the floors that high are the place.)
		local round_ = up ~= nil and not aimed and Tier.NearRound(ground, cellRow, cellCol, up)
		local span = round_ or 1
		-- The place's own cell first, so a floor round it is kept only beside one of those.
		for pass = 1, 2 do
			for r = cellRow - span, cellRow + span do
				for c = cellCol - span, cellCol + span do
					local own = r == cellRow and c == cellCol
					if (pass == 1) == own then
						local nodeRow, nodeCol = floor(r / 8), floor(c / 8)
						local n, text, at = Tier.Of(data, nodeRow, nodeCol)
						if n > 0 then
							local tile, cell = CellIn(ground, r, c)
							for k = 0, Floors(tile, cell) - 1 do
								local _, swum, _, look, height = Floor(tile, cell, k)
								local high = height and up and math.abs(height - up) <= Tier.UP_NEAR
								local off = (aimed and own and not high) or (round_ and not high)
								if not (on ~= nil and look ~= on) and not off then
									local beside = true
									if not own and heights and #heights > 0 then
										local near = false
										if height then
											for _, each in ipairs(heights) do
												if each and math.abs(each - height) <= Tier.BESIDE then near = true end
											end
										end
										-- Water under a cliff often keeps no height of its own. It is not the
										-- place when the place itself is on land.
										if swum and land and not wet then beside = near
										elseif height then beside = near end
									end
									if beside then
										if own then
											if height then
												heights = heights or {}
												heights[#heights + 1] = height
											end
											if swum then wet = true else land = true end
										end
										local tier = n > 1 and Tier.OfFloor(data, ground, nodeRow, nodeCol, n, text, at, k * FSTRIDE + r * CSTRIDE + c) or 0
										local key = tier * Tier.SPAN + nodeRow * STRIDE + nodeCol
										if not seen[key] then
											seen[key] = true
											keys[#keys + 1] = key
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	-- A level asked for that no floor of the place or round it is on: what stands there is on that level in
	-- something the floors don't know (a room off a hall inside a mountain, whose cells have only the
	-- mountain's top). It is reached from the nearest floors on that level (Pocket.Level), on their tiers:
	-- never by the mountain's top for want of a hall floor under it.
	if #keys == 0 and ground and on ~= nil and on ~= T.ABOVE then
		local floors = Pocket.levelled
		local cellRow, cellCol = CellAt(data, north, west)
		for index = 1, Pocket.Level(ground, cellRow, cellCol, on, floors) do
			local id = floors[index]
			local cell = id % FSTRIDE
			local nodeRow, nodeCol = floor(floor(cell / CSTRIDE) / 8), floor(cell % CSTRIDE / 8)
			local n, text, at = Tier.Of(data, nodeRow, nodeCol)
			if n > 0 then
				local key = (n > 1 and Tier.OfFloor(data, ground, nodeRow, nodeCol, n, text, at, id) or 0) * Tier.SPAN + nodeRow * STRIDE + nodeCol
				if not seen[key] then
					seen[key] = true
					keys[#keys + 1] = key
				end
			end
		end
		if #keys > 0 then return keys end
	end
	-- (The tiers of the place's own floors on that level are the place, whatever level each tier's own place
	-- is on: a street's tier may have its place on a ramp over it, and a tier told by that was left out for
	-- another whose place was on the level asked: a roof, the terrain left lying under the street. Only where
	-- no floor says, every tier of the node, are those told apart by their places.)
	if #keys > 0 then return keys end
	for tier = 0, max(1, (Tier.Of(data, row, col))) - 1 do keys[tier + 1] = tier * Tier.SPAN + row * STRIDE + col end
	if on then
		local kept = {}
		for _, key in ipairs(keys) do
			if select(4, Tier.Place(data, key)) == on then kept[#kept + 1] = key end
		end
		if #kept > 0 then return kept end
	end
	return keys
end

-- Whether a cell has a floor within Tier.UP_NEAR yards of the height `up`.
function Tier.Near(ground, row, col, up)
	local tile, cell = CellIn(ground, row, col)
	for k = 0, Floors(tile, cell) - 1 do
		local height = select(5, Floor(tile, cell, k))
		if height and math.abs(height - up) <= Tier.UP_NEAR then return true end
	end
	return false
end

-- ... or one of the cells round it, Close.GOAL_ROUND cells off at the most (as far as Pocket.Floors looks for
-- the floors a way ends on: the tiers a goal is reached on and the floors its way ends on are the same
-- ones): how many cells off the nearest is, false for none.
function Tier.NearRound(ground, row, col, up)
	for ring = 1, Close.GOAL_ROUND do
		for r = row - ring, row + ring do
			for c = col - ring, col + ring do
				local off = max(r < row and row - r or r - row, c < col and col - c or c - col)
				if off == ring and Tier.Near(ground, r, c, up) then return ring end
			end
		end
	end
	return false
end

-- Whether a goal asked for on `level` is reached on only some of its node's tiers: those of that look, a
-- search of their own (a cave under a hill big enough to be a tier of its own).
function Tier.Levelled(world, data, north, west, level)
	local row, col = Stand(data, north, west)
	if not row or Tier.Of(data, row, col) <= 1 then return false end
	local with, without = false, false
	for _, key in ipairs(Tier.Goals(data, GroundOf(world, data), row, col, north, west)) do
		if select(4, Tier.Place(data, key)) == level then with = true else without = true end
	end
	return with and without
end

-- The floors of the way found up close that Pocket.Trace (below) goes along: each one's cell, which of its
-- cell's floors it is, whether it is swum, and its level.
local rows, cols, floorsOf, wets, levels = {}, {}, {}, {}, {}

-- Where in its cell a floor is, as shares of the cell (down its rows, along its columns): the middle of the
-- quarter-cells that are it (the cell's middle where they aren't told). As FloorPlace.
function Pocket.Spot(tile, at, k)
	if type(tile) ~= "table" then return 0.5, 0.5 end
	local _, _, _, _, _, mask = Floor(tile, at, k)
	if not mask or mask == 0 or mask == 65535 then return 0.5, 0.5 end
	local down, across, count = 0, 0, 0
	for bit = 0, 15 do
		if mask % 2 == 1 then
			down, across, count = down + (bit - bit % 4) / 4, across + bit % 4, count + 1
			mask = mask - 1
		end
		mask = mask / 2
	end
	return (down / count + 0.5) / 4, (across / count + 0.5) / 4
end

-- Whether the straight line from a spot on one floor to a spot on another can be walked, and what walking it
-- takes: each floor it crosses steps on to one floor of the next cell and no other, in water only where
-- `wet`, and it ends on the floor it is drawn to. The spots: (row, col) and (toRow, toCol), in cells and
-- shares of one (Pocket.Spot). Returns the 64ths of a second it takes as the search up close counts them
-- (CloseStep: from a floor that hasn't every step open TIGHT times as long, in water `wade` times, off a road
-- ROAD_OFF times, each yard of a fall FALL_TICKS), or nil where it can't be walked; then, for a job kept to
-- the roads (`kept`), how many cells of it are off one where that counts (Tier.Off).
-- (A stretch of it is counted from the middle of its run over one floor to the middle of its run over the
-- next, the line's own ends for the first and the last, at what a step from the first of the two takes: so a
-- line that runs as the way found does takes what that took, and one that cuts across is held to the same.)
function Pocket.Straight(ground, row, col, k, toRow, toCol, toK, wet, wade, kept)
	-- (Looked at a quarter-cell at a time: in a tunnel two yards wide a line between two cells' middles
	-- may cross rock in a cell that steps on to the next.)
	-- (Every place on the line is past 0, so x - x % 1 is its floor, with no call; a quarter's bit is read from
	-- Tier.QUARTERS.)
	local dr, dc = toRow - row, toCol - col
	local steps = ceil(max(dr < 0 and -dr or dr, dc < 0 and -dc or dc) * SUB * 2)
	local r, c = row - row % 1, col - col % 1
	if steps == 0 then return k == toK and 0 or nil, 0 end
	local tile, at = CellIn(ground, r, c)
	local here, _, open, level, up, mask, _, steep = Floor(tile, at, k)
	local quarters = Tier.QUARTERS
	local tight, toll = open and 1 or TIGHT, 1
	local away = kept and Tier.Off(kept, r, c, level) and 1 or 0
	if away == 1 then toll = Tier.ROAD_OFF end
	-- (rate: what the stretch into the floor the line is over takes, a step; share: how much of it is off a
	-- road; from: where that stretch began; entered: where the line came over this floor. In steps along it.)
	local cost, falls, off, rate, share, from, entered = 0, 0, 0, nil, 0, 0, 0
	for step = 1, steps do
		local along = step / steps
		local fr, fc = row + dr * along, col + dc * along
		local nr, nc = fr - fr % 1, fc - fc % 1
		if nr ~= r or nc ~= c then
			local onto = Leads(tile, at, k, WAY[nr - r][nc - c], here)
			-- One floor and no other: 2 ^ its number.
			local next = onto == 1 and 0 or onto == 2 and 1 or onto == 4 and 2 or onto == 8 and 3
				or onto == 16 and 4 or onto == 32 and 5 or onto == 64 and 6 or onto == 128 and 7
			if not next then return nil end
			tile, at = CellIn(ground, nr, nc)
			local wasUp, wasSteep = up, steep
			local swum, deep
			here, swum, open, level, up, mask, deep, steep = Floor(tile, at, next)
			if swum ~= wet then return nil end
			-- (A fall, as the search counts one.)
			if up and wasUp and not deep then
				local fall, straight = wasUp - up, nr == r or nc == c
				if fall > (straight and Tier.SLIDE_STRAIGHT or Tier.SLIDE_CORNER)
					or (not steep and not wasSteep and fall > (straight and Tier.FALL_STRAIGHT or Tier.FALL_CORNER)) then
					falls = falls + fall * Tier.FALL_TICKS
				end
			end
			local middle = rate and (entered + step) / 2 or 0
			if rate then cost, off = cost + rate * (middle - from), off + share * (middle - from) end
			local awayThere = kept and Tier.Off(kept, nr, nc, level) and 1 or 0
			local tollThere = awayThere == 1 and Tier.ROAD_OFF or 1
			rate, share, from, entered = tight * (toll + tollThere) / 2, (away + awayThere) / 2, middle, step
			tight, toll, away = open and 1 or TIGHT, tollThere, awayThere
			r, c, k = nr, nc, next
		end
		-- The quarter-cell the line is in must be the floor's, where the floor says which are.
		if mask and mask ~= 65535 then
			local qr, qc = (fr - nr) * SUB, (fc - nc) * SUB
			local bit = quarters[(qr - qr % 1) * SUB + qc - qc % 1 + 1]
			if mask % (bit + bit) < bit then return nil end
		end
	end
	if k ~= toK then return nil end
	if rate then cost, off = cost + rate * (steps - from), off + share * (steps - from) end
	local cells = sqrt(dr * dr + dc * dc) / steps
	return cost * cells * STEP * (wet and wade or 1) + falls, off * cells
end

-- The floors of a way found up close (a search's `near`), from floor `id` on to where it ends, as the
-- points of `way` (way.n of them, three numbers a point; way.look, way.up, way.yards; way.water where it
-- is swum and `water` is walked on): a point wherever it turns, and one either side of a shore and of a
-- change of level. Returns the floor it ends on. led: a table each floor it goes by is set in, to its turn
-- along it (1, 2 ...: Tier.led). kept: the job it was found by, where that keeps to the roads.
--
-- The search steps from a cell to one of the eight round it, so the way it finds runs along the grid and
-- cornerwise across it, which nobody walks. Between two of its floors the straight line is taken wherever it
-- can be walked (Pocket.Straight) and takes no longer than the way found did between them, by the search's
-- own count: past an edge only where that is still the quicker, over a fall never (it was found keeping
-- clear of both), and for a job kept to the roads off one no further than the way found went. The whole of a
-- stretch is tried first; where that can't be, it is parted at the floor furthest off the line (where what
-- stands in the way turns it) and each part tried; then every turn left is dropped that the floors either
-- side of it don't need. (Tried whole, a stretch of open ground is looked along once: looked along anew from
-- its start at every floor, it cost its length squared, and was cut every so many floors at a floor of the
-- way found, off the line, to bound that.)
Pocket.took, Pocket.away, Pocket.spotRow, Pocket.spotCol, Pocket.turns, Pocket.parts = {}, {}, {}, {}, {}, {}
Pocket.PASSES = 3              -- times the turns of a way are gone over for one that isn't needed
function Pocket.Trace(data, ground, near, id, way, water, led, kept)
	-- (took: the 64ths from each floor to the end, as the search has them. away: the cells off a road so far.)
	local took, away, spotRow, spotCol, turns, parts = Pocket.took, Pocket.away, Pocket.spotRow, Pocket.spotCol, Pocket.turns, Pocket.parts
	local Straight = Pocket.Straight
	local last, off, wasOff = 0, 0, 0
	while true do
		local k, cell = floor(id / FSTRIDE), id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		local tile, at = CellIn(ground, r, c)
		local _, swum, _, level = Floor(tile, at, k)
		local down, across = Pocket.Spot(tile, at, k)
		local have = near[id]
		if led then led[id] = last + 1 end
		last = last + 1
		rows[last], cols[last], floorsOf[last], wets[last], levels[last] = r, c, k, swum, level
		took[last], spotRow[last], spotCol[last] = (have - have % CKEPT) / CKEPT, r + down, c + across
		if kept then
			-- (A step's cells off a road: its length, by how many of its two floors are off one.)
			local isOff = Tier.Off(kept, r, c, level) and 0.5 or 0
			if last > 1 then
				off = off + (isOff + wasOff) * ((rows[last - 1] ~= r and cols[last - 1] ~= c) and 1.4142 or 1)
			end
			wasOff, away[last] = isOff, off
		end
		local step = floor(have / 2) % 16
		if step == 0 then break end
		id = floor(have / 32) % 8 * FSTRIDE + (r + ROW[step]) * CSTRIDE + c + COL[step]
	end
	local wade = water and 1 or WADE
	-- Whether the straight line from the way's floor a to its floor b is taken for the way between them.
	-- (Half a 64th a step: what the search rounds each step's time by.)
	local function Fits(a, b)
		local cost, cut = Straight(ground, spotRow[a], spotCol[a], floorsOf[a], spotRow[b], spotCol[b], floorsOf[b], wets[a], wade, kept)
		return cost ~= nil and cost <= took[a] - took[b] + (b - a) * 0.5 + 0.001 and (not kept or cut <= away[b] - away[a] + 0.001)
	end
	-- The floors that stay whatever is straight (2): the first and the last, and either side of a shore and of
	-- a change of level. The stretches between them, to be tried (parts: two floors each).
	local top, before = 0, 1
	for index = 1, last do
		local stays = index == 1 or index == last or wets[index] ~= wets[index - 1] or wets[index] ~= wets[index + 1]
			or levels[index] ~= levels[index - 1] or levels[index] ~= levels[index + 1]
		turns[index] = stays and 2 or false
		if stays then
			if index - before > 1 then
				parts[top + 1], parts[top + 2] = before, index
				top = top + 2
			end
			before = index
		end
	end
	while top > 0 do
		local a, b = parts[top - 1], parts[top]
		top = top - 2
		if not Fits(a, b) then
			-- (The floor furthest off the line; a stretch that runs along it and still can't be taken, its middle.)
			local fromRow, fromCol = spotRow[a], spotCol[a]
			local dr, dc = spotRow[b] - fromRow, spotCol[b] - fromCol
			local far, at = 0.01, floor((a + b) / 2)
			for index = a + 1, b - 1 do
				local aside = (spotRow[index] - fromRow) * dc - (spotCol[index] - fromCol) * dr
				if aside < 0 then aside = -aside end
				if aside > far then far, at = aside, index end
			end
			turns[at] = 1
			if at - a > 1 then
				parts[top + 1], parts[top + 2] = a, at
				top = top + 2
			end
			if b - at > 1 then
				parts[top + 1], parts[top + 2] = at, b
				top = top + 2
			end
		end
	end
	-- The turns, in their order; each that the way does without (from the turn before it straight to the one
	-- after) is dropped, until none is.
	local count = 0
	for index = 1, last do
		if turns[index] then
			count = count + 1
			parts[count] = index
		end
	end
	for _ = 1, Pocket.PASSES do
		local held = 1
		for turn = 2, count - 1 do
			local index = parts[turn]
			if turns[index] == 1 and Fits(parts[held], parts[turn + 1]) then
				turns[index] = false
			else
				held = held + 1
				parts[held] = index
			end
		end
		if count > 1 then
			held = held + 1
			parts[held] = parts[count]
		end
		if held == count then break end
		count = held
	end
	local from = 1
	for turn = 1, count do
		local index = parts[turn]
		local spot = way.n * 3
		way[spot + 1], way[spot + 2] = FloorPlace(data, ground, rows[index], cols[index], floorsOf[index])
		way[spot + 3] = wets[index]
		if water and wets[index] then way.water = waterSpell end
		way.n = way.n + 1
		-- (A floor that tells no height has none here: its node's is yards off, past a porch's edge.)
		local _, _, _, _, up = Floor(CellIn(ground, rows[index], cols[index]), (rows[index] % CELLS) * CELLS + cols[index] % CELLS, floorsOf[index])
		way.look[way.n], way.up[way.n] = levels[index], up
		if index > 1 then way.yards = way.yards + sqrt((spotRow[index] - spotRow[from]) ^ 2 + (spotCol[index] - spotCol[from]) ^ 2) * CELL end
		from = index
	end
	return id
end

-- The beginning of the way from a node a search is done with: `reach` yards of it, from the very floor
-- that (north, west) is on, floor by floor. nil where the ground up close isn't kept or leads nowhere:
-- the way over nodes does then. node nil: the way over nodes knows none, and the goal is near enough
-- (Close.FLOOR_ONLY) to be looked for floor by floor all the way, as far again as a search up close may look
-- four times over (a rope bridge whose nodes stand on the valley floor under it, a ledge).
local starts, goals = {}, {}
-- A floor's height in yards: its own where it is told, else that of the node it is in.
local function FloorHeight(data, ground, id)
	local k, cell = floor(id / FSTRIDE), id % FSTRIDE
	local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
	local _, _, _, _, up = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, k)
	if up then return up end
	local north, west = CellPlace(data, r, c)
	local row, col = NodeAt(data, north, west)
	local tile, at = Record(data, row, col)
	if tile then return select(5, Place(data, row, col, tile, at)) end
end

-- A node a way over nodes goes by, and the eight round it, as lane[row * STRIDE + col] = true.
function Pocket.Lane(lane, key)
	local _, row, col = Tier.Node(key)
	for dr = -1, 1 do
		for dc = -1, 1 do lane[(row + dr) * STRIDE + col + dc] = true end
	end
end

-- A search up close for `goal` (its first floor) that gave up, asked from a floor (its cell, its height):
-- not tried again from there (Tier.GaveUp), each goal kept apart (a way led along tries far, then near).
function Pocket.GaveUp(search, goal, cell, up)
	search.gaveUp = search.gaveUp or {}
	search.gaveUp[goal] = { cell = cell, up = up }
end

-- Whether a search's way over nodes from `node` rides a lift or drops off a cliff anywhere on to its goal;
-- here: right there, its first step.
function Pocket.Rides(search, node, here)
	local cost, at = search.cost, node
	for _ = 1, here and 1 or 4096 do
		local have = cost[at]
		local step = have and floor(have / 2) % 16 or 0
		if step == 0 then return false end
		if step == LIFT or step == FALL then return true end
		at = Onward(search, at, step)
	end
	return false
end

-- Whether a floor asked from (its cell, its height) is where a search up close already gave up (`from`: the
-- cell and height that search was aimed from): within Close.FAILED_AGAIN cells of it and about as high (BESIDE). A
-- floor well over or under it is another place, of which that search said nothing (the ruins over a city's
-- halls).
function Tier.GaveUp(from, cell, up)
	return from ~= nil and math.abs(floor(from.cell / CSTRIDE) - floor(cell / CSTRIDE)) < Close.FAILED_AGAIN
		and math.abs(from.cell % CSTRIDE - cell % CSTRIDE) < Close.FAILED_AGAIN
		and (from.up == nil) == (up == nil) and (up == nil or math.abs(from.up - up) <= Tier.BESIDE)
end

local function NearWay(search, node, north, west, reach, level)
	local data = search.data
	local ground = GroundOf(search.world, data)
	if not ground then return nil end
	-- Where the way over nodes is `reach` yards from here as the crow flies (so that it runs off whatever
	-- shows so much, however it winds; or three times that long): the node, and whether that is short of
	-- the goal.
	local cost = search.cost
	local at, gone, cut, far = node, 0, false, false
	local lastNorth, lastWest, lastFloor
	-- (A goal this near is gone to floor by floor all the way: in a city the way over nodes would only
	-- lead the search up close to a place on the way, and to another a few steps on.)
	local direct = not node or (search.north and (search.north - north) ^ 2 + (search.west - west) ^ 2 <= Close.GOAL * Close.GOAL)
	-- (Nor where the way over nodes rides a lift or drops off a cliff on the way: the floors know neither, and
	-- would lead the long way round. Up close to where it does, then on over nodes.)
	if direct and node and Pocket.Rides(search, node) then direct = false end
	-- (A way led along is looked for floor by floor only through the nodes the way over nodes goes by and those
	-- round them, Pocket.Lane: in a forest or a city, a search all round looks at tens of thousands of floors.)
	local lane = not direct and reach > Close.GOAL and {} or nil
	while not direct do
		if lane then Pocket.Lane(lane, at) end
		local placeNorth, placeWest, _, _, _, which = Tier.Place(data, at)
		if lastNorth then gone = gone + sqrt((placeNorth - lastNorth) ^ 2 + (placeWest - lastWest) ^ 2) end
		lastNorth, lastWest, lastFloor = placeNorth, placeWest, which
		local step = floor(cost[at] / 2) % 16
		if step == 0 then break end
		if (placeNorth - north) ^ 2 + (placeWest - west) ^ 2 >= reach * reach or gone >= reach * 3 then
			cut, far = true, true
			break
		end
		-- (A lift or a drop is no way up close: the way there is, and the way over nodes shows the rest. Right
		-- at one, the way over nodes alone.)
		if step == LIFT or step == FALL then
			if at == node then return nil end
			cut = true
			break
		end
		at = Onward(search, at, step)
	end
	-- The floors it ends on: the goal's own where the way gets that far (whichever of them is reached
	-- the quickest: the place itself doesn't say which it is on), else the node's place.
	local goalCount = 0
	local costs, own
	if not cut and search.north then
		goalCount = Pocket.Floors(data, ground, search.north, search.west, goals, level, search.up)
		own = goalCount
		-- (And every floor round them from where they are within reach: Pocket.Reach.)
		if goalCount > 0 then
			goalCount = Pocket.Reach(data, ground, search.north, search.west, goals, goalCount, level, search.up)
			costs = Pocket.costs
		end
	end
	if goalCount == 0 then
		if direct then return nil end
		-- (Cut where it has gone far enough: at whichever floor of that node's tier the way over the floors comes
		-- into it, not bent off to the node's place, which may be tens of yards to one side; the way over nodes
		-- goes on from the node after it, Pocket.Then. Each such floor costs the steps from it to the node's place,
		-- so none is come to by a way the place itself wouldn't be (a drop off a balcony onto the tier's floor
		-- under it). Cut at a lift or a drop: at its place, where it is ridden.)
		if far then
			goalCount = Tier.FloorsOf(data, ground, at, goals)
			local row, col = CellAt(data, lastNorth, lastWest)
			costs = Pocket.costs
			for index = 1, goalCount do
				local cell = goals[index] % FSTRIDE
				local dr, dc = math.abs(floor(cell / CSTRIDE) - row), math.abs(cell % CSTRIDE - col)
				costs[index] = dr < dc and dr * SLANT + (dc - dr) * STEP or dc * SLANT + (dr - dc) * STEP
			end
		end
		if goalCount == 0 then
			local row, col = CellAt(data, lastNorth, lastWest)
			goals[1] = lastFloor * FSTRIDE + row * CSTRIDE + col
			goalCount = 1
		end
	end
	-- The floors it starts on: the player's, or those of a cell beside theirs.
	local startCount = FloorsAt(data, ground, north, west, starts)
	if startCount == 0 then
		for way = 1, 8 do
			if startCount == 0 then startCount = FloorsAt(data, ground, north - ROW[way] * CELL, west - COL[way] * CELL, starts) end
		end
		if startCount == 0 then return nil end
	end
	startCount = Standing(ground, starts, startCount)
	-- A search up close that found nothing is the most it costs: not asked again for the same goal
	-- until the player is somewhere else (Tier.GaveUp).
	local startCell = starts[1] % FSTRIDE
	local startUp = FloorHeight(data, ground, starts[1])
	local failed = search.gaveUp and search.gaveUp[goals[1]]
	if failed and Tier.GaveUp(failed, startCell, startUp) then
		return nil, nil, true
	end
	-- The job for these goals: where it has been already, the way from there is known; else it is aimed
	-- here and goes on for what the frame can spare. One that gave up after going on from another place
	-- is begun anew from here.
	local key = goalCount == 1 and goals[1] or table.concat(goals, ",", 1, goalCount)
	local job = search.job
	if job and (job.key ~= key or job.ground ~= ground) then job = nil end
	local id = job and CloseKnown(job, starts, startCount)
	if not id then
		if job and job.done then
			-- (One begun from here that gave up is a way not found; from elsewhere, it is begun anew.)
			if job.fresh and Tier.GaveUp(job.from, startCell, startUp) then
				Pocket.GaveUp(search, goals[1], startCell, startUp)
				return nil, nil, true
			end
			job = nil
		end
		if not job then
			job = CloseBegin(search, ground, key, goals, goalCount, costs)
			job.fresh, job.from = true, { cell = startCell, up = startUp }
			-- (Floor by floor all the way, or to one floor of several at the place: a balcony up a hall's
			-- winding walkway is found by going all round it. As far as a way led along is, Bend.MOST: a search
			-- that gives up short of a long winding way is asked again, and again, from each place on it, each
			-- costing as much, where one that goes on finds it once.)
			if reach > Close.GOAL then
				job.most = Bend.MOST
			elseif not node or search.up then
				job.most = Close.MOST * 4
			end
			job.corridor = lane
			stats.closes = stats.closes + 1
		elseif job.found then
			-- (Going on from another place: as far again as one begun here may look, along this way too.)
			job.fresh, job.most = false, job.looked + (reach > Close.GOAL and Bend.MOST or search.up and Close.MOST * 4 or Close.MOST)
			if job.corridor and lane then
				for each in pairs(lane) do job.corridor[each] = true end
			end
		end
		CloseAim(job, starts, startCount)
		local now = GetTime()
		if now ~= frame then frame, spent = now, 0 end
		if spent < Close.NOW then
			local began = debugprofilestop()
			CloseStep(job, Close.NOW - spent)
			local took = debugprofilestop() - began
			spent = spent + took
			stats.closeMs = stats.closeMs + took
			if took > stats.closeMost then stats.closeMost = took end
		end
		id = job.found
		if not id then
			if job.done then
				closePending[job] = nil
				if job.fresh then Pocket.GaveUp(search, goals[1], startCell, startUp) end
				return nil, nil, true
			end
			closePending[job] = true
			driver:Show()
			return nil, true
		end
		closePending[job] = nil
	end
	stood[ground] = id
	Tier.landed = nil
	-- (Whoever it isn't yet known which floor they stand on, of several, stands on the one their way begins on.)
	Tier.Settle(data, ground, id)
	local began = debugprofilestop()
	-- (Its seconds are the way over nodes'; with none, the floors' own: 64ths of a second.)
	local seconds = node and Tier.Seconds(search, node) or floor(job.near[id] / CKEPT) / 64
	-- (way.node: where it is cut, the node at whose place it ends.)
	local way = { seconds = seconds, yards = 0, n = 0, goal = node and GoalFrom(search, node) or 1, cut = cut, close = true, look = {}, up = {},
		node = cut and at or nil }
	-- (Found from where someone stands: its floors are the ones they will be on, Tier.led, for T.Saw.)
	local rider, led = Tier.rider, nil
	if rider.ground == ground and rider.north and (north - rider.north) ^ 2 + (west - rider.west) ^ 2 <= Tier.LED * Tier.LED then
		led = {}
		Tier.led = led
	end
	local last = Pocket.Trace(data, ground, job.near, id, way, search.water, led, job.roads and job)
	-- (On a floor within reach of the place, not its own: at its spot nearest the place.)
	local reached = false
	for index = 1, costs and goalCount or 0 do
		if goals[index] == last then reached = costs[index] > 0 end
	end
	if reached and way.n >= 2 then
		local cell = last % FSTRIDE
		local spotNorth, spotWest = Pocket.Nearest(data, ground, floor(cell / CSTRIDE), cell % CSTRIDE, floor(last / FSTRIDE), search.north, search.west)
		local spot = way.n * 3
		local fromNorth, fromWest = way[spot - 5], way[spot - 4]
		way.yards = way.yards - sqrt((way[spot - 2] - fromNorth) ^ 2 + (way[spot - 1] - fromWest) ^ 2) + sqrt((spotNorth - fromNorth) ^ 2 + (spotWest - fromWest) ^ 2)
		way[spot - 2], way[spot - 1] = spotNorth, spotWest
	end
	-- (On the place's own floor, one that tells no height (the one floor of open ground): the place's.)
	if search.up ~= nil and way.n >= 1 and way.up[way.n] == nil then
		for index = 1, own or 0 do
			if goals[index] == last then way.up[way.n] = search.up end
		end
	end
	local took = debugprofilestop() - began
	if took > stats.shapeMost then stats.shapeMost = took end
	return way
end

-- Places the nodes don't stand for -----------------------------------------------------------------
-- A node is one place, the most of its ground: in the cells over a cave its place is the hill, so a cave
-- deep under one is a pocket of nodes no link leads into or out of (a mine, a hollow under a cliff), and
-- the way over nodes knows none to anything in it. Where the ground up close is kept, the way in is found
-- floor by floor, once for each search: from the place (on the level its node is on) out to the nearest
-- places of the nodes round it that the heart reaches, its ways in. The search over nodes goes on to
-- those, each with the seconds from it to the place and its floors there (search.inside: WayOf goes on
-- along them). Someone standing in a pocket is led out the same way: from where they are to the nearest
-- place of a node round them that leads to the heart (Pocket.Exit), and on from there as anyone else.

-- The floors a place may be on, as FloorsAt; where none is under it (a crate, a counter), those of the
-- nearest cell round it that has any, Close.GOAL_ROUND cells off at the most. Of floors on more than one level,
-- those on `level` where there are any; of those, the ones near the height `up` where there are any.
function Pocket.Floors(data, ground, north, west, into, level, up)
	local count = FloorsAt(data, ground, north, west, into)
	for ring = 1, Close.GOAL_ROUND do
		if count > 0 then break end
		for dr = -ring, ring do
			for dc = -ring, ring do
				if count == 0 and max(dr < 0 and -dr or dr, dc < 0 and -dc or dc) == ring then
					count = FloorsAt(data, ground, north - dr * CELL, west - dc * CELL, into)
				end
			end
		end
	end
	if level ~= nil and count > 0 then
		-- The spot's own quarter can be the lake under a cliff while the place stands on another floor of
		-- the same cell. A level asked for keeps that floor, not the water.
		local function OnLevel(n)
			local kept = 0
			for index = 1, n do
				local id = into[index]
				local cell = id % FSTRIDE
				local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
				local _, _, _, on = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE))
				if on == level then
					kept = kept + 1
					into[kept] = id
				end
			end
			return kept
		end
		local kept = OnLevel(count)
		if kept == 0 then
			local id = into[1]
			local cell = id % FSTRIDE
			local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
			local tile, at = CellIn(ground, r, c)
			local n = Floors(tile, at)
			for k = 0, n - 1 do into[k + 1] = k * FSTRIDE + r * CSTRIDE + c end
			kept = OnLevel(n)
			-- (None of its cell's on that level: what stands there is in something the floors don't know, and
			-- is come to on the nearest floors on that level, as Tier.Goals has its tiers. A level up is a word
			-- the floors don't use of a tower's top: not looked for.)
			if kept == 0 and level ~= T.ABOVE then
				kept = Pocket.Level(ground, r, c, level, into)
				if kept == 0 then
					for k = 0, n - 1 do into[k + 1] = k * FSTRIDE + r * CSTRIDE + c end
				end
			end
		end
		if kept > 0 then count = kept end
	end
	if up ~= nil and count > 0 then
		-- (True near that height, false away from it, nil for a floor that tells no height of its own: the one
		-- floor of open ground, which may well be at it.)
		local function High(id)
			local cell = id % FSTRIDE
			local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
			local height = select(5, Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE)))
			if height == nil then return nil end
			return math.abs(height - up) <= Tier.UP_NEAR
		end
		local kept = 0
		for index = 1, count do
			local id = into[index]
			if High(id) then
				kept = kept + 1
				into[index], into[kept] = into[kept], id
			end
		end
		-- None that high, and some tell no height: those, before looking round for a counter.
		if kept == 0 then
			for index = 1, count do
				local id = into[index]
				if High(id) == nil then
					kept = kept + 1
					into[index], into[kept] = into[kept], id
				end
			end
		end
		-- None that high: someone behind a counter. The floors that high in the cells round theirs, where
		-- they are spoken to from.
		if kept == 0 then
			local round_ = Pocket.round
			for ring = 1, Close.GOAL_ROUND do
				for dr = -ring, ring do
					for dc = -ring, ring do
						if max(dr < 0 and -dr or dr, dc < 0 and -dc or dc) == ring then
							for index = 1, FloorsAt(data, ground, north - dr * CELL, west - dc * CELL, round_) do
								if High(round_[index]) then
									kept = kept + 1
									into[kept] = round_[index]
								end
							end
						end
					end
				end
				if kept > 0 then break end
			end
		end
		if kept > 0 then count = kept end
	end
	return count
end
Pocket.round = {}

-- The spot of a floor (cell r, c; floor k) nearest a place: the place itself where it is on the floor, else the
-- middle of the floor's quarter-cell nearest it; then how many yards the place is from the floor's edge.
function Pocket.Nearest(data, ground, r, c, k, north, west)
	local cellNorth, cellWest = CellPlace(data, r, c)
	local tile, at = CellIn(ground, r, c)
	local mask = type(tile) == "table" and select(6, Floor(tile, at, k)) or nil
	if not mask or mask == 0 then mask = 65535 end
	local quarter, best, bestNorth, bestWest = CELL / 4, nil, nil, nil
	for bit = 0, 15 do
		if mask % 2 == 1 then
			local spotNorth, spotWest = cellNorth + (1.5 - floor(bit / 4)) * quarter, cellWest + (1.5 - bit % 4) * quarter
			local offNorth, offWest = max(math.abs(spotNorth - north) - quarter / 2, 0), max(math.abs(spotWest - west) - quarter / 2, 0)
			local far = sqrt(offNorth * offNorth + offWest * offWest)
			if not best or far < best then
				best, bestNorth, bestWest = far, spotNorth, spotWest
				if far == 0 then bestNorth, bestWest = north, west end
			end
		end
		mask = floor(mask / 2)
	end
	return bestNorth, bestWest, best
end

-- Whether a floor steps anywhere at all (a floor inside a wall, under the balcony it holds up, is nowhere).
function Pocket.Leads(tile, at, k)
	local steps = Floor(tile, at, k)
	for way = 1, 8 do
		if Leads(tile, at, k, way, steps) > 0 then return true end
	end
	return false
end

-- Where someone at a place is spoken to from, besides the floors they stand on (into[1 .. count], Pocket.Floors's):
-- the other floors of their cell and of the cells round it (Close.GOAL_ROUND) within Pocket.REACH yards of them, on `level`
-- where it is asked for, never water under a place on land. The yards are from the floor's edge (Pocket.Nearest)
-- and up or down to the height they stand at (`up`; with none, the nearest of their cell's floors that lead
-- anywhere: a place has no height). An auctioneer behind an invisible wall, a banker over a counter, someone in
-- a cave whose spot's own floor is the hilltop over it: the way ends within reach of them, on whichever such floor
-- it comes to first. Each is added after the others, and costs[index] is what the steps from it to the place
-- would take along an edge (64ths of a second; 0 for their own), so a floor of theirs that is walked to is the
-- end. Returns the new count.
Pocket.REACH = 5.5             -- yards: the game's reach for speaking to someone (five yards between the two, and their size)
Pocket.costs, Pocket.had, Pocket.heights = {}, {}, {}
function Pocket.Reach(data, ground, north, west, into, count, level, up)
	local costs, had, heights = Pocket.costs, Pocket.had, Pocket.heights
	wipe(had)
	wipe(heights)
	local land = false
	for index = 1, count do
		local id = into[index]
		costs[index], had[id] = 0, true
		local cell = id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		land = land or not select(2, Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE)))
	end
	local row, col = CellAt(data, north, west)
	-- (With no height asked for, a floor that tells none of its own stands at its node's: FloorHeight.)
	if up ~= nil then
		heights[1] = up
	else
		local own, ownAt = CellIn(ground, row, col)
		for k = 0, Floors(own, ownAt) - 1 do
			local height = Pocket.Leads(own, ownAt, k) and FloorHeight(data, ground, k * FSTRIDE + row * CSTRIDE + col)
			if height then heights[#heights + 1] = height end
		end
	end
	local reach = Pocket.REACH
	local round = Close.GOAL_ROUND
	for r = row - round, row + round do
		for c = col - round, col + round do
			local tile, at = CellIn(ground, r, c)
			for k = 0, Floors(tile, at) - 1 do
				local id = k * FSTRIDE + r * CSTRIDE + c
				local _, swum, _, look = Floor(tile, at, k)
				local edge = select(3, Pocket.Nearest(data, ground, r, c, k, north, west))
				local ok = not had[id] and edge <= reach and (level == nil or look == level) and not (swum and land) and Pocket.Leads(tile, at, k)
				if ok and #heights > 0 then
					-- (At a height asked for, only a floor that tells its own, as Pocket.Floors.)
					local height, rise = up == nil and FloorHeight(data, ground, id) or select(5, Floor(tile, at, k)), nil
					for _, each in ipairs(heights) do
						if height and (not rise or math.abs(each - height) < rise) then rise = math.abs(each - height) end
					end
					ok = rise ~= nil and edge * edge + rise * rise <= reach * reach
				end
				if ok then
					-- (No less than the steps from it to their cell, past an edge: a floor of theirs that is walked to
					-- is never left for one round it.)
					local dr, dc = math.abs(r - row), math.abs(c - col)
					local steps = (dr == 0 and dc == 0) and STEP or (dr < dc and dr * SLANT + (dc - dr) * STEP or dc * SLANT + (dr - dc) * STEP)
					count = count + 1
					into[count], costs[count], had[id] = id, floor(steps * TIGHT + 0.5), true
				end
			end
		end
	end
	return count
end

-- Whether a place asked for on `level` is gone into as a pocket (Begin): it has a floor on that level,
-- and the node it stands at is on another, with no tier on it (a cave under the hill its node stands for,
-- too small to be a tier of its own). Kept by place.
Pocket.splits, Pocket.splitCount, Pocket.splitFloors = {}, 0, {}
function Pocket.Split(world, data, north, west, level)
	local splits = Pocket.splits
	local key = world .. ":" .. floor(north) .. ":" .. floor(west) .. ":" .. level
	local split = splits[key]
	if split ~= nil then return split end
	local ground = GroundOf(world, data)
	if not ground then return false end
	split = false
	local row, col = Stand(data, north, west)
	local tile, at = Record(data, row or -1, col or -1)
	local tiered = false
	if tile and Tier.Of(data, row, col) > 1 then
		for _, each in ipairs(Tier.Goals(data, ground, row, col, north, west)) do
			if select(4, Tier.Place(data, each)) == level then tiered = true end
		end
	end
	if tile and not tiered and byte(tile, at + 11) ~= level then
		local into = Pocket.splitFloors
		local count = FloorsAt(data, ground, north, west, into)
		for index = 1, count do
			local id = into[index]
			local cell = id % FSTRIDE
			local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
			local _, _, _, on = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE))
			if on == level then
				split = true
				break
			end
		end
	end
	if Pocket.splitCount > 200 then
		wipe(splits)
		Pocket.splitCount = 0
	end
	splits[key], Pocket.splitCount = split, Pocket.splitCount + 1
	return split
end

-- Whether a place asked for at the height `up` is gone into as a pocket (Begin): its floor that high is on
-- none of its node's tiers (a throne room under a city's moat, too small a part of its node to be a tier of
-- its own). Returns the look of that floor, for the pocket's level; false for no pocket. Kept by place.
Tier.SPLIT_UP = 12             -- yards a floor may be from a tier of one floor's place height and still be on it
function Pocket.SplitUp(world, data, north, west, up)
	local splits = Pocket.splits
	local key = world .. ":" .. floor(north) .. ":" .. floor(west) .. "^" .. floor(up + 0.5)
	local split = splits[key]
	if split ~= nil then return split end
	split = false
	local ground = GroundOf(world, data)
	local into = Pocket.splitFloors
	local count = ground and Pocket.Floors(data, ground, north, west, into, nil, up) or 0
	for index = 1, count do
		local id = into[index]
		local cell = id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		local _, _, _, look, height = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE))
		if height and math.abs(height - up) <= Tier.UP_NEAR then
			-- (Its own node: someone behind a counter may be spoken to from the node beside theirs.)
			local row, col = floor(r / 8), floor(c / 8)
			local n, text, at = Tier.Of(data, row, col)
			local on = false
			if n > 1 then
				for tier = 0, n - 1 do
					local from = at + 1 + tier * Tier.RECORD + 6
					local lowL, lowH, highL, highH = byte(text, from, from + 3)
					local low, high = (lowL + lowH * 256 - 20000) / 2, (highL + highH * 256 - 20000) / 2
					if max(low - height, height - high, 0) <= Tier.SLACK then on = true end
				end
			elseif n == 1 then
				local placeUp = select(5, Tier.Place(data, row * STRIDE + col))
				on = placeUp ~= nil and math.abs(placeUp - height) <= Tier.SPLIT_UP
			end
			if not on then split = look end
			break
		end
	end
	if Pocket.splitCount > 200 then
		wipe(splits)
		Pocket.splitCount = 0
	end
	splits[key], Pocket.splitCount = split, Pocket.splitCount + 1
	return split
end

-- The level a place is asked for on, held to the height it is asked for at. A height is where something
-- stands, to the yard; a level is a word about the floors, and whoever tells it may have read it off the
-- wrong one: someone in a shop the floors don't know has only the mountain's top in their cell, 130 yards
-- over the hall they stand in (Ironforge), and asked for "on the ground" at the hall's height the way went
-- out of the gate and round over the mountain. So where the place has floors that high (its own, or the
-- nearest round it: Tier.Near, Tier.NearRound, as Tier.Goals reaches them), none of them on `level`, and no
-- floor of its own on `level` that may be that high (one that tells no height stands about at its node's:
-- within Tier.FAR_UP, a node being 33 yards of hillside), the level is theirs.
-- Asked by every map in every frame: kept by place, level and height as one number (no text is made), a
-- table a world; what is asked with no level or no height costs two comparisons.
Tier.FAR_UP = 40               -- yards a floor that tells no height of its own may stand from its node's
Tier.asked, Tier.askedCount = {}, 0
function Tier.Asked(world, north, west, level, up)
	if level == nil or up == nil then return level end
	local kept = Tier.asked[world]
	local key = (((floor(north) + 32768) * 65536 + floor(west) + 32768) * 16384 + floor(up + 0.5) + 4096) * 4 + level
	local asked = kept and kept[key]
	if asked ~= nil then return asked end
	local data = T.data.nodes[world]
	local ground = data and GroundOf(world, data)
	if not ground then return level end
	asked = level
	local row, col = CellAt(data, north, west)
	local ring = Tier.Near(ground, row, col, up) and 0 or Tier.NearRound(ground, row, col, up)
	if ring then
		local mine, theirs = false, nil
		local own, ownAt = CellIn(ground, row, col)
		for k = 0, Floors(own, ownAt) - 1 do
			local _, _, _, look, height = Floor(own, ownAt, k)
			if look == level then
				local slack = Tier.UP_NEAR
				if height == nil then height, slack = FloorHeight(data, ground, k * FSTRIDE + row * CSTRIDE + col), Tier.FAR_UP end
				if height == nil or math.abs(height - up) <= slack then mine = true end
			end
		end
		for r = row - ring, mine and row - ring - 1 or row + ring do
			for c = col - ring, col + ring do
				if max(r < row and row - r or r - row, c < col and col - c or c - col) == ring then
					local tile, cell = CellIn(ground, r, c)
					for k = 0, Floors(tile, cell) - 1 do
						local _, _, _, look, height = Floor(tile, cell, k)
						if height and math.abs(height - up) <= Tier.UP_NEAR then
							if look == level then mine = true else theirs = theirs or look end
						end
					end
				end
			end
		end
		if not mine and theirs ~= nil then asked = theirs end
	end
	if Tier.askedCount > 400 then
		wipe(Tier.asked)
		Tier.askedCount, kept = 0, nil
	end
	if not kept then
		kept = {}
		Tier.asked[world] = kept
	end
	kept[key], Tier.askedCount = asked, Tier.askedCount + 1
	return asked
end

-- The places of a node's tiers (none for no node): for each, the floor its place is on, its key, whether
-- the heart reaches it, and whether it leads to the heart, as Pocket.places' n-th four.
Pocket.found = {}
function Pocket.Places(data, row, col)
	local found, count = Pocket.found, 0
	for tier = 0, Tier.Of(data, row, col) - 1 do
		local key = tier * Tier.SPAN + row * STRIDE + col
		local north, west, _, _, _, which, what = Tier.Place(data, key)
		if north then
			local cellRow, cellCol = CellAt(data, north, west)
			found[count * 4 + 1], found[count * 4 + 2] = which * FSTRIDE + cellRow * CSTRIDE + cellCol, key
			found[count * 4 + 3], found[count * 4 + 4] = floor(what / REACHED) % 2 == 1, floor(what / LEAVES) % 2 == 1
			count = count + 1
		end
	end
	return count
end

-- The search up close for a search's ways in: from the floors of each of its places the heart doesn't
-- reach (search.off), nearest first all round, toward the places of the nodes round them that it does.
-- From the floors on the level asked for (search.level), else on the level of each place's node; any: from
-- all of them (a hilltop nothing climbs to over the cave the place is in). nil where there is nothing to
-- look from or for.
function Pocket.InJob(search, ground, any)
	local data, off, into, round = search.data, search.off, Pocket.places, Pocket.ROUND
	local job = { key = search.key, data = data, ground = ground, water = search.water, near = {}, heap = { n = 0 }, wanted = {}, looked = 0,
		most = Pocket.MOST, wade = search.water and 1 or WADE, lean = 0, row = 0, col = 0, goalOf = {}, ways = {}, nodes = {}, any = any }
	for index = 1, #off, 5 do
		local row, col = off[index + 3], off[index + 4]
		local tile, at = Record(data, row, col)
		local level = search.level or byte(tile, at + 11)
		local count = Pocket.Floors(data, ground, off[index + 1], off[index + 2], into, not any and level or nil, not any and search.up or nil)
		if count > 0 then job.had = true end
		for k = 1, count do
			local id = into[k]
			if not job.near[id] then
				job.near[id], job.goalOf[id] = 0, off[index]
				Push(job.heap, id)
			end
		end
		local found = Pocket.found
		for dr = -round, round do
			for dc = -round, round do
				for n = 0, Pocket.Places(data, row + dr, col + dc) - 1 do
					if found[n * 4 + 3] then job.wanted[found[n * 4 + 1]] = found[n * 4 + 2] end
				end
			end
		end
	end
	if job.heap.n == 0 or next(job.wanted) == nil then return nil end
	stats.closes = stats.closes + 1
	return job
end

-- Goes on with a search for ways in for up to `ms` milliseconds: each floor it comes to that it looks for
-- is a way in (job.ways; its node job.nodes), until there are WAYS of them, or what is left to look at is
-- SPARE further than the first, or there is nothing more (job.finished).
function Pocket.Run(job, ms)
	local began = debugprofilestop()
	while not job.finished do
		local left = ms - (debugprofilestop() - began)
		if left <= 0 then break end
		job.found = nil
		CloseStep(job, left)
		local id, ways = job.found, job.ways
		if id then
			local n = #ways + 1
			ways[n], job.nodes[n] = id, job.wanted[id]
			job.wanted[id] = nil
			if n == 1 then job.limit = floor(job.near[id] / CKEPT) + Pocket.SPARE end
		end
		local top = job.heap[1]
		if job.done or #ways >= Pocket.WAYS or (job.limit and (not top or floor(top / CSPAN) > job.limit)) then job.finished = true end
	end
	local took = debugprofilestop() - began
	stats.closeMs = stats.closeMs + took
	if took > stats.closeMost then stats.closeMost = took end
end

-- A finished search's ways in, kept for its goals (Pocket.ins[key]): { node, ticks, goal, way (its
-- floors, from the node's place to the goal's) }, or false for none.
function Pocket.Done(job)
	if job.kept ~= nil then return job.kept end
	local kept = false
	for index, id in ipairs(job.ways) do
		local way = { n = 0, yards = 0, look = {}, up = {} }
		local last = Pocket.Trace(job.data, job.ground, job.near, id, way, job.water)
		kept = kept or {}
		kept[#kept + 1] = { node = job.nodes[index], ticks = max(1, floor(floor(job.near[id] / CKEPT) / 64 / TICK + 0.5)), goal = job.goalOf[last] or 1, way = way }
	end
	job.kept = kept
	if Pocket.kept >= 200 then
		wipe(Pocket.ins)
		Pocket.kept = 0
	end
	Pocket.ins[job.key], Pocket.kept = kept, Pocket.kept + 1
	return kept
end

-- A search's ways in, once: true when it was given some now (to be asked again), "working" while they are
-- found, nil for none. wait: found here and now.
function Pocket.Enter(search, wait)
	if search.entered or not search.off then return nil end
	local data = search.data
	local ground = search.world and GroundOf(search.world, data)
	if not ground then return nil end
	local kept = Pocket.ins[search.key]
	if kept == nil then
		local job = search.entering
		if not job then
			job = Pocket.InJob(search, ground)
			if not job then
				search.entered = true
				return nil
			end
			search.entering = job
		end
		if not job.finished then
			if wait then
				Pocket.Run(job, math.huge)
			else
				local now = GetTime()
				if now ~= frame then frame, spent = now, 0 end
				if spent < Close.NOW then
					local began = debugprofilestop()
					Pocket.Run(job, Close.NOW - spent)
					spent = spent + debugprofilestop() - began
				end
			end
		end
		if not job.finished then
			Pocket.pending[job] = true
			driver:Show()
			return "working"
		end
		Pocket.pending[job] = nil
		-- (None from the floors on its node's level: from all of the place's.)
		-- Don't try the other floors when this level had some and none of them led out: the other floor
		-- of a cliff is the lake under it, and that way in is a swim to a wall.
		if #job.ways == 0 and not job.any and not job.had then
			search.entering = Pocket.InJob(search, ground, true)
			if search.entering then return Pocket.Enter(search, wait) end
		end
		kept = Pocket.Done(job)
	end
	search.entered, search.entering = true, nil
	if not kept then return nil end
	local cost, inside = search.cost, search.inside or {}
	search.inside = inside
	for _, entry in ipairs(kept) do
		local node, ticks = entry.node, entry.ticks
		local had = cost[node]
		if not had or ticks < floor(had / KEPT) then
			cost[node] = ticks * KEPT
			search.goalAt[node], inside[node] = entry.goal, entry.way
			local base = node % Tier.SPAN
			Push(search.heap, (ticks + Guess(floor(base / STRIDE), base % STRIDE, search.toRow, search.toCol)) * SPAN + node)
		end
	end
	stats.ins = stats.ins + 1
	search.done, search.joinedNode, search.goalNode = false, nil, nil
	return true
end

-- The way out for someone standing at north, west in a pocket node (row, col): from the floor they are on
-- to the nearest place round them of a node that leads to the heart. { seconds, north, west (that node's
-- place), and the floors as a way's points } (kept for that floor); "working" while it is found; nil for
-- none. One search is kept, for the node last asked from.
function Pocket.Exit(data, ground, world, north, west, row, col, wait)
	local starts = Pocket.places
	local count = Pocket.Floors(data, ground, north, west, starts)
	if count == 0 then return nil end
	local key = world * SPAN + row * STRIDE + col
	local job = Pocket.exit
	if not job or job.key ~= key or job.ground ~= ground then
		if job then Pocket.pending[job] = nil end
		job = { key = key, data = data, ground = ground, near = {}, heap = { n = 0 }, wanted = {}, looked = 0, most = Pocket.MOST,
			wade = waterOn and 1 or WADE, lean = 1, nodeOf = {}, outs = {} }
		local round, found = Pocket.ROUND, Pocket.found
		for dr = -round, round do
			for dc = -round, round do
				for n = 0, Pocket.Places(data, row + dr, col + dc) - 1 do
					local id = found[n * 4 + 1]
					if found[n * 4 + 4] and not job.near[id] then
						job.near[id], job.nodeOf[id] = 0, found[n * 4 + 2]
						Push(job.heap, id)
					end
				end
			end
		end
		-- (Nothing round them leads to the heart: no way out.)
		job.none = job.heap.n == 0
		Pocket.exit = job
		stats.closes = stats.closes + 1
	end
	if job.none then return nil end
	local id = CloseKnown(job, starts, count)
	if not id then
		if job.done then return nil end
		CloseAim(job, starts, count)
		if wait then
			while not job.found and not job.done do CloseStep(job, math.huge) end
		else
			local now = GetTime()
			if now ~= frame then frame, spent = now, 0 end
			if spent < Close.NOW then
				local began = debugprofilestop()
				CloseStep(job, Close.NOW - spent)
				spent = spent + debugprofilestop() - began
			end
		end
		id = job.found
		if not id then
			if job.done then return nil end
			Pocket.pending[job] = true
			driver:Show()
			return "working"
		end
	end
	local out = job.outs[id]
	if not out then
		out = { n = 0, yards = 0, look = {}, up = {}, leds = setmetatable({}, { __mode = "k" }) }
		local node = job.nodeOf[Pocket.Trace(data, ground, job.near, id, out, waterOn)]
		out.seconds = floor(job.near[id] / CKEPT) / 64
		out.north, out.west = Tier.Place(data, node)
		out.key = node
		job.outs[id] = out
		stats.outs = stats.outs + 1
	end
	return out
end

-- How long from someone standing in a pocket of nodes to a search's goals: by their way out, then as from
-- where it leads. As Answer, with the way out last (for Pocket.Lead); nil where they aren't in one, or no
-- way out is known.
function Pocket.Out(search, north, west, row, col, wait, key)
	local data = search.data
	if select(3, What(data, key or row * STRIDE + col)) then return nil end
	local ground = search.world and GroundOf(search.world, data)
	if not ground then return nil end
	local out = Pocket.Exit(data, ground, search.world, north, west, row, col, wait)
	if out == "working" then return nil, "working" end
	if not out then return nil end
	local seconds, goal, more, node = Answer(search, out.north, out.west, wait, out.key)
	if seconds then return seconds + out.seconds, goal, more, node, out end
	if goal == "far" then return nil, goal, more + out.seconds end
	return nil, goal
end

-- A way found floor by floor (`first`: a way out, a beginning), then a way over nodes on from the place it
-- ends at, as one way taking `seconds`. first's points are way.fine: on the floors' own way.
function Pocket.Then(first, way, seconds)
	local led = { seconds = seconds, yards = first.yards + way.yards, goal = way.goal, cut = way.cut, close = way.close,
		n = 0, look = {}, up = {}, fine = {}, fall = way.fall, steer = way.steer, water = way.water or first.water }
	local function Add(from, point)
		local spot = led.n * 3
		led[spot + 1], led[spot + 2], led[spot + 3] = from[point * 3 - 2], from[point * 3 - 1], from[point * 3]
		led.n = led.n + 1
		led.look[led.n], led.up[led.n] = from.look[point], from.up[point]
	end
	for point = 1, first.n do
		Add(first, point)
		led.fine[led.n] = true
	end
	-- (The way over nodes begins at the place the first ends at.)
	for point = 2, way.n do
		Add(way, point)
		if way.drop and way.drop[point] then
			led.drop = led.drop or {}
			led.drop[led.n] = true
		end
		if way.lift and way.lift[point] then
			led.lift = led.lift or {}
			led.lift[led.n] = true
		end
		if way.fine and way.fine[point] then led.fine[led.n] = true end
	end
	return led
end

-- A way over nodes led on from a way out (Pocket.Exit): one way, from where they stand; kept while the way
-- is the same. way as it is without one.
function Pocket.Lead(out, way)
	if not out or not way then return way end
	local led = out.leds[way]
	if led then return led end
	led = Pocket.Then(out, way, way.seconds + out.seconds)
	out.leds[way] = led
	return led
end

-- What is left of the searches for ways in and out, for up to `ms` milliseconds (T.Work). True when one
-- is done that was waited for.
function Pocket.Work(ms)
	local began, any = debugprofilestop(), false
	for job in pairs(Pocket.pending) do
		local left = ms - (debugprofilestop() - began)
		if left <= 0 then break end
		if job.outs then
			CloseStep(job, left)
			if job.found or job.done then Pocket.pending[job] = nil end
		else
			Pocket.Run(job, left)
			if job.finished then
				-- (Kept for its goals, but none from its node's level only: Enter looks again from all floors.)
				if #job.ways > 0 or job.any then Pocket.Done(job) end
				Pocket.pending[job] = nil
			end
		end
		if not Pocket.pending[job] then any = true end
	end
	return any
end

-- The levels there are floors on at a place: ground, under, above (true each); nil where nothing is kept.
function T.Levels(world, north, west)
	local data = T.data.nodes[world]
	local ground = GroundOf(world, data)
	if not ground then return nil end
	local count = FloorsAt(data, ground, north, west, goals)
	if count == 0 then return nil end
	local onGround, under, above = false, false, false
	for index = 1, count do
		local id = goals[index]
		local cell = id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		local _, _, _, level = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE))
		if level == T.UNDER then under = true elseif level == T.ABOVE then above = true else onGround = true end
	end
	return onGround, under, above
end

-- Whether a place is water: true where every floor there is swum (the open sea, a lake), false where any
-- floor there is walked (a shore, a bridge over a river, a pier); nil where nothing is kept.
function T.Water(world, north, west)
	local data = T.data.nodes[world]
	local ground = GroundOf(world, data)
	if not ground then return nil end
	local count = FloorsAt(data, ground, north, west, goals)
	if count == 0 then return nil end
	for index = 1, count do
		local id = goals[index]
		local cell = id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		local _, swum = Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE))
		if not swum then return false end
	end
	return true
end

-- Riding a lift ---------------------------------------------------------------------------------
-- A ride is noticed as it happens: someone stands still (waiting for the lift and riding it: Ridden.STILL_FOR
-- seconds within Ridden.STILL yards), then steps off onto a floor a few yards away (Ridden.OFF) that no few steps
-- lead to from the floor they stood on, Ridden.RISE yards or more above it. Down is the same lift, so only a ride
-- up is noticed: a fall off a cliff is never one. Not on a flight, nor dead (a spirit goes anywhere).
-- What is noticed is kept (ShyWayDB.lifts: { world, foot north, foot west, head north, head west,
-- seconds }) and found ways go by it at once. (Data\Lifts.lua holds those ridden before it shipped.)
local NEAR_STEPS = 6
local Ridden = { STILL = 1.5, STILL_FOR = 5, OFF = 15, RISE = 12, MOST = 90 }   -- yards, seconds, yards, yards, seconds kept at most
local rider = {}               -- where someone was last seen: world, ground, floor, north, west, since (when they came to stand there),
                               -- seen (when they were last looked at)
local seen, near, todo = {}, {}, {}
Tier.rider, Tier.NEAR_STEPS = rider, NEAR_STEPS
Tier.PEAK = 60                 -- yards a floor out of doors is over one under ground at the same spot from which the game's
                               -- "out of doors" doesn't say which of the two someone first seen there is on
Tier.JUMP = 40                 -- yards: further than a few steps lead (NEAR_STEPS) ...
Tier.FASTEST = 80              -- ... and quicker than this many yards a second is no walk or ride but a jump (Ride.lua's)

-- The floors a few steps lead to from a floor: near[floor] = true.
-- walking: only steps that are walked, none that falls off an edge (steeper than any stair: Tier.FALL_*).
local function NearFloors(ground, from, steps, walking)
	wipe(near)
	wipe(todo)
	near[from], todo[1] = 0, from
	local first, last = 1, 1
	while first <= last do
		local id = todo[first]
		first = first + 1
		local depth = near[id]
		if depth < steps then
			local k, cell = floor(id / FSTRIDE), id % FSTRIDE
			local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
			local tile, at = CellIn(ground, r, c)
			local leads, _, _, _, here = Floor(tile, at, k)
			for way = 1, 8 do
				local onto = Leads(tile, at, k, way, leads)
				local floorOf = 0
				local thereTile, thereAt
				if walking and here then thereTile, thereAt = CellIn(ground, r + ROW[way], c + COL[way]) end
				while onto > 0 do
					if onto % 2 == 1 then
						local next = floorOf * FSTRIDE + (r + ROW[way]) * CSTRIDE + c + COL[way]
						if not near[next] and thereTile then
							local there = select(5, Floor(thereTile, thereAt, floorOf))
							if there and here - there > (way % 2 == 1 and Tier.FALL_STRAIGHT or Tier.FALL_CORNER) then next = nil end
						end
						if next and not near[next] then
							near[next] = depth + 1
							last = last + 1
							todo[last] = next
						end
					end
					onto, floorOf = floor(onto / 2), floorOf + 1
				end
			end
		end
	end
	return near
end
Tier.NearFloors = NearFloors
-- The floors a few steps lead to from the floor the player stands on, kept while they stand on it: whichever
-- floor a way begins on is asked at every place a build asks the ground from, in a town a dozen times a build,
-- and each was a look round a hundred floors.
Tier.reached = { map = {} }
function Tier.Reach(ground, from)
	local kept = Tier.reached
	if kept.ground ~= ground or kept.from ~= from then
		local map = kept.map
		wipe(map)
		for id, depth in pairs(NearFloors(ground, from, NEAR_STEPS)) do map[id] = depth end
		kept.ground, kept.from = ground, from
	end
	return kept.map
end

-- A lift ridden between two places: kept, and the ways go by it. Two of the same lift are one.
function T.Rode(world, footNorth, footWest, headNorth, headWest, seconds)
	local saved = T.Saved()
	saved.lifts = saved.lifts or {}
	for _, lift in ipairs(saved.lifts) do
		if lift[1] == world and (lift[2] - footNorth) ^ 2 + (lift[3] - footWest) ^ 2 < Ridden.OFF * Ridden.OFF
			and (lift[4] - headNorth) ^ 2 + (lift[5] - headWest) ^ 2 < Ridden.OFF * Ridden.OFF then
			return
		end
	end
	local lifts = saved.lifts
	lifts[#lifts + 1] = { world, floor(footNorth * 10 + 0.5) / 10, floor(footWest * 10 + 0.5) / 10,
		floor(headNorth * 10 + 0.5) / 10, floor(headWest * 10 + 0.5) / 10, floor(math.min(Ridden.MOST, seconds) + 0.5) }
	liftsKnown = liftsKnown + 1
end

-- Of the floors at a place (into[1 .. count]), those someone indoors (or not) may be on: a floor under ground is
-- indoors (Ironforge's halls under the mountain's top, the city under the ruins), any other is not; all of them
-- where none is. Returns how many.
function Tier.Indoors(ground, into, count, indoors)
	local kept = 0
	for index = 1, count do
		local id = into[index]
		local cell = id % FSTRIDE
		local r, c = floor(cell / CSTRIDE), cell % CSTRIDE
		local look = select(4, Floor(CellIn(ground, r, c), (r % CELLS) * CELLS + c % CELLS, floor(id / FSTRIDE)))
		if (look == T.UNDER) == indoors then
			kept = kept + 1
			into[index], into[kept] = into[kept], id
		end
	end
	return kept > 0 and kept or count
end

-- Shy.Way.SetGuess(fn): fn(world, north, west) -> a height someone may stand at there, or nil. Asked when
-- the floor someone is on isn't known and several are there (T.Saw).
function T.SetGuess(fn)
	Tier.guess = fn
end

-- Where someone is now (world, north, west) at a time (seconds): a lift is noticed here. up: the height they
-- stand at, where it is known (the game tells none: a test's walker does).
function T.Saw(world, north, west, now, up)
	local data = T.data.nodes[world]
	local ground = GroundOf(world, data)
	if not ground then
		rider.floor = nil
		return
	end
	local count = FloorsAt(data, ground, north, west, seen)
	if count == 0 then return end
	-- (Somewhere else all at once, quicker than anyone goes: a hearthstone, a portal. The floor they stood on
	-- says nothing of the one they are on now: as though first seen.)
	local last, gone = rider.seen, rider.north and sqrt((north - rider.north) ^ 2 + (west - rider.west) ^ 2) or 0
	rider.seen = now
	local jumped = last and now and gone > Tier.JUMP and gone > (now - last) * Tier.FASTEST
	local fresh = rider.world ~= world or rider.ground ~= ground or jumped
	if fresh or not rider.floor or up then
		-- First seen, or not yet known on which floor: where there is one, that; at a height told, the floor
		-- nearest it; off a flight, the top floor where it landed; once a way has been found from here, the floor
		-- it began on (Standing). Else of those indoors or not, as the game says they are (Tier.Indoors), the one;
		-- of several, it isn't known (nil, rider.choices): a way asked from here begins on whichever of them is
		-- the quickest (Answer), and that is the one.
		local first, best
		if up then
			-- (Of the floors at the spot itself, else of its cell's: a floor whose part of the cell isn't the spot.)
			for index = 1, count do
				local height = FloorHeight(data, ground, seen[index])
				if height and math.abs(height - up) <= Tier.UP_NEAR and (not best or math.abs(height - up) < best) then
					best, first = math.abs(height - up), seen[index]
				end
			end
			local cellRow, cellCol = CellAt(data, north, west)
			for k = 0, first and -1 or Floors(CellIn(ground, cellRow, cellCol)) - 1 do
				local id = k * FSTRIDE + cellRow * CSTRIDE + cellCol
				local height = FloorHeight(data, ground, id)
				if height and (not best or math.abs(height - up) < best) then best, first = math.abs(height - up), id end
			end
		elseif count == 1 then
			first = seen[1]
		elseif Tier.landed then
			for index = 1, count do
				local height = FloorHeight(data, ground, seen[index])
				if height and (not best or height > best) then best, first = height, seen[index] end
			end
		elseif not fresh and stood[ground] then
			local reach = NearFloors(ground, stood[ground], NEAR_STEPS)
			for index = 1, count do
				if not first and reach[seen[index]] then first = seen[index] end
			end
		end
		-- (Still not known, of several: the height of what stands round them, where someone knows it
		-- (T.SetGuess). The game's indoors is no word in a city it lets you ride in.)
		local guess = not first and not up and Tier.guess and Tier.guess(world, north, west) or nil
		if guess then
			best = nil
			for index = 1, count do
				local height = FloorHeight(data, ground, seen[index])
				if height and (not best or math.abs(height - guess) < best) then best, first = math.abs(height - guess), seen[index] end
			end
		end
		local choices = nil
		if not first then
			local indoors = IsIndoors()
			local kept = Tier.Indoors(ground, seen, count, indoors)
			-- (Out of doors by the game's word, on the one floor that isn't under ground, with another Tier.PEAK
			-- yards or more under it: the game calls a city inside a mountain out of doors, and its word is none
			-- between a hall and the peak a hundred yards over it. Not known: the way asked from here begins on
			-- whichever is the quickest. A hill over a mine is no such height over it, and stays the hill.)
			if kept == 1 and not indoors and count > 1 then
				local top = FloorHeight(data, ground, seen[1])
				for index = 2, count do
					local under = FloorHeight(data, ground, seen[index])
					if top and under and top - under >= Tier.PEAK then kept = count end
				end
			end
			if kept == 1 then
				first = seen[1]
			else
				choices = {}
				for index = 1, kept do choices[seen[index]] = true end
			end
		end
		rider.world, rider.ground, rider.floor, rider.north, rider.west, rider.since, rider.choices = world, ground, first, north, west, now, choices
		return
	end
	if (north - rider.north) ^ 2 + (west - rider.west) ^ 2 <= Ridden.STILL * Ridden.STILL then return end
	-- The floor they are on now: one a few steps walked lead to from the one they stood on, the fewest (of a
	-- ramp's turns over each other, the one they walk up, not the turn under it a step off its edge falls to),
	-- of any floor of the cell they are in (someone on a bridge a yard off its edge's quarter-cells is on the
	-- bridge, not in the river under it), one of the spot's own before another as near. Else one a few steps
	-- lead to, a fall off an edge too (they jumped down), of the spot's own.
	-- (Of those, one the way they are led along goes by first, Tier.led, and not one it went by well before the
	-- floor they were on (Tier.BACK turns): off a ramp's side the floor beside it is as few steps away as the
	-- ramp on, and a way winding up goes by the turn under it too.)
	local onto, least
	local reach = NearFloors(ground, rider.floor, NEAR_STEPS, true)
	local cellRow, cellCol = CellAt(data, north, west)
	local led = Tier.led or Tier.empty
	local turn = led[rider.floor]
	local function Weigh(id, pass)
		local steps = reach[id]
		if not steps or (pass == 1 and not (led[id] and (not turn or led[id] >= turn - Tier.BACK))) then return end
		if not least or steps < least then onto, least = id, steps end
	end
	for pass = 1, 2 do
		for index = 1, count do Weigh(seen[index], pass) end
		for k = 0, Floors(CellIn(ground, cellRow, cellCol)) - 1 do Weigh(k * FSTRIDE + cellRow * CSTRIDE + cellCol, pass) end
		if onto then break end
	end
	if not onto then
		reach = NearFloors(ground, rider.floor, NEAR_STEPS)
		for index = 1, count do
			local steps = reach[seen[index]]
			if steps and (not least or steps < least) then onto, least = seen[index], steps end
		end
	end
	if not onto then
		-- None a few steps lead to. Off a lift (they stood waiting, and one is well above): the highest.
		-- Else the one nearest the height they were at: someone walking under Ironforge's mountain is
		-- still in its halls, not on the peak over them.
		local high, highest, near, nearest
		local low = FloorHeight(data, ground, rider.floor)
		for index = 1, count do
			local up = FloorHeight(data, ground, seen[index])
			if up then
				if not high or up > high then high, highest = up, seen[index] end
				if low and (not near or math.abs(up - low) < near) then near, nearest = math.abs(up - low), seen[index] end
			end
		end
		if high and low and high - low >= Ridden.RISE and now - rider.since >= Ridden.STILL_FOR
			and (north - rider.north) ^ 2 + (west - rider.west) ^ 2 <= Ridden.OFF * Ridden.OFF then
			T.Rode(world, rider.north, rider.west, north, west, now - rider.since)
			onto = highest
		else
			onto = nearest or highest
		end
	end
	rider.floor, rider.north, rider.west, rider.since = onto or seen[1], north, west, now
end

function T.Up(world)
	if rider.world ~= world or not rider.floor then return nil end
	return FloorHeight(T.data.nodes[world], rider.ground, rider.floor)
end

-- Each world's ground ------------------------------------------------------------------------------
-- A world's ground is some megabytes: it ships in an addon of its own (ShyWay_Ground_<world>), loaded
-- when someone first comes into that world, so only what is walked on is held. Until it is, nothing is
-- known there (callers keep the straight line), and SHY_TERRAIN says when it is.
local GROUND_ADDON = "ShyWay_Ground_"
local function LoadGround()
	local world = select(8, GetInstanceInfo())
	if not world or T.data.nodes[world] then return end
	local name = GROUND_ADDON .. world
	if not C_AddOns.DoesAddOnExist(name) or C_AddOns.IsAddOnLoaded(name) then return end
	if C_AddOns.LoadAddOn(name) and T.data.nodes[world] then
		if Shy.Memory then Shy.Memory.Keeps(("ground: world %d"):format(world), T.data.nodes[world]) end
		Tier.News("ground", world)
	end
end
local arrivals = CreateFrame("Frame")
arrivals:RegisterEvent("PLAYER_ENTERING_WORLD")
arrivals:SetScript("OnEvent", LoadGround)

-- What the player can do now to come down a cliff or cross water (Slowed falls, above): worked out again
-- whenever a spell, a reagent or a cooldown may have changed, and SHY_TERRAIN sent when the ways change.
-- (A ghost runs over water as on land, with no spell: Tier.dead. And keeps to no road: nothing attacks it.)
local function Moves()
	Tier.wake = nil
	local deep, by, glide, glider = FallDeep()
	-- (A spell kept back by its cooldown: looked at again as it ends, once.)
	local wake = Tier.wake
	if wake and wake ~= Tier.woken and wake > GetTime() then
		Tier.woken = wake
		C_Timer.After(wake - GetTime() + 0.05, Moves)
	end
	local water, on = WaterWalk()
	local dead = UnitIsDeadOrGhost("player") == true
	if dead then water, on = true, nil end
	fallSpell, glideSpell, waterSpell = by, glider, on
	if deep ~= fallDeep or glide ~= glideDeep or water ~= waterOn or dead ~= (Tier.dead == true) then
		fallDeep, glideDeep, waterOn, Tier.dead = deep, glide, water, dead
		Tier.News("moves")
	end
end
local moves = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "PLAYER_LEVEL_UP",
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
	moves:RegisterEvent(event)
end
-- (A cooldown the game says is another spell's changes nothing here: in a fight that is every cast. It names
-- none, or a secret one, when it may be any. The spells with a cooldown of their own: Tier.Cooled.)
function Tier.Cooled(spell)
	local falls = T.data.falls
	if Tier.cooledFor ~= falls then
		Tier.cooledFor, Tier.cooled = falls, {}
		for _, list in ipairs({ falls.spells or {}, falls.water or {} }) do
			for _, each in ipairs(list) do
				if (each[5] or 0) > 0 then Tier.cooled[each[1]] = true end
			end
		end
	end
	return Tier.cooled[spell] == true
end
local movesSoon
moves:SetScript("OnEvent", function(_, event, spell, base)
	if event == "BAG_UPDATE_DELAYED" then
		-- A loot. Whether a reagent came or went can wait a frame, off the loot itself.
		if movesSoon then return end
		movesSoon = true
		C_Timer.After(0, function()
			movesSoon = nil
			Moves()
		end)
		return
	end
	if event == "SPELL_UPDATE_COOLDOWN" and spell ~= nil and not issecretvalue(spell) and not Tier.Cooled(spell)
		and (base == nil or (not issecretvalue(base) and not Tier.Cooled(base))) then
		return
	end
	Moves()
end)

-- Shy.Way.Moves() -> the yards a drop may be now (0: none) and the spell that slows the fall; whether
-- water is walked on and by which spell; the yards a steered glide may come down and its spell.
-- Shy.Way.SetFall(yards, glideYards), Shy.Way.SetWater(on): say so instead (nil: as the spells say).
function T.Moves() return fallDeep, fallSpell, waterOn, waterSpell, glideDeep, glideSpell end
function T.SetFall(yards, glide)
	fallSet, glideSet = yards, glide
	Moves()
end
function T.SetWater(on)
	waterSet = on
	Moves()
end

-- Shy.Way.Paths() -> how this character's ways keep to the roads (Roads, above): "high" (as it comes: where
-- what lives off them is too high for the character, the shortest elsewhere), "auto" (where it is their level
-- or higher), "always" or "never" (the shortest everywhere). Shy.Way.SetPaths(mode): so (ShyWayDB.roads, by
-- character; nothing kept for as it comes). Shy.Way.Roads() -> false where they don't now, else "high", "auto"
-- or "always". SHY_TERRAIN when it changes, and at a level gained while it goes by their level. Setup puts it
-- back to as it comes.
function T.Paths()
	local kept, guid = T.Saved().roads, UnitGUID("player")
	local mode = type(kept) == "table" and guid ~= nil and kept[guid] or nil
	if mode == true then return "always" end
	return (mode == "always" or mode == "auto" or mode == "never") and mode or "high"
end
function T.SetPaths(mode)
	if mode ~= "always" and mode ~= "auto" and mode ~= "never" then mode = "high" end
	if mode == T.Paths() then return end
	local saved, guid = T.Saved(), UnitGUID("player")
	if not guid then return end
	if type(saved.roads) ~= "table" then saved.roads = {} end
	saved.roads[guid] = mode ~= "high" and mode or nil
	Tier.News("roads")
end
-- (A step of setup with no page of its own: run, the character is led as it comes.)
if Shy.Setup then
	Shy.Setup.Step({ id = "paths", order = 90, title = "Paths", Run = function() T.SetPaths("high") end })
end
function T.Roads()
	return (Tier.Kept())
end
Tier.levelled = CreateFrame("Frame")
Tier.levelled:RegisterEvent("PLAYER_LEVEL_UP")
Tier.levelled:SetScript("OnEvent", function()
	-- (A moment on: the level the game says is the new one by then.)
	local mode = T.Paths()
	if mode == "auto" or mode == "high" then C_Timer.After(1, function() Tier.News("roads") end) end
end)

-- Every second: where the player is, unless on a flight or dead. (The game tells no move of a place: a lift
-- and a boat carry someone standing still. A second's ticker, not a frame's look at the clock; nothing while
-- no world's ground is held.)
local lastLook = 0
Tier.Look = Shy.Clocked("ground: which floor you stand on", function(now)
	if UnitOnTaxi("player") or UnitIsDeadOrGhost("player") then
		rider.floor = nil
		Tier.flying = UnitOnTaxi("player") or nil
		return
	end
	-- (Off a flight: on the landing's top floor until a way begins from there: Standing.)
	if Tier.flying then Tier.flying, Tier.landed = nil, true end
	local world, north, west = Shy.Here(true)
	if world then T.Saw(world, north, west, now) end
end)
C_Timer.NewTicker(1, function()
	local now = GetTime()
	if now - lastLook < 0.95 or next(T.data.floors) == nil then return end
	lastLook = now
	Tier.Look(now)
end)

-- A way over nodes as it is from where someone stands: its first point is the place of the node they
-- are in, which may be behind them. Where they are already nearer the second point than the first is,
-- the way begins at them instead (a copy: the way kept is the search's).
local function Ahead(way, north, west)
	if not way or way.n < 3 then return way end
	local dn, dw = way[4] - way[1], way[5] - way[2]
	if (north - way[4]) ^ 2 + (west - way[5]) ^ 2 >= dn * dn + dw * dw then return way end
	local copy = { seconds = way.seconds, goal = way.goal, cut = way.cut, close = way.close, yards = way.yards, n = way.n, look = {}, up = {},
		drop = way.drop, lift = way.lift, fall = way.fall, steer = way.steer, water = way.water, fine = way.fine }
	copy[1], copy[2], copy[3], copy.look[1], copy.up[1] = north, west, way[3], way.look[1], way.up[1]
	for point = 2, way.n do
		local spot = (point - 1) * 3
		copy[spot + 1], copy[spot + 2], copy[spot + 3] = way[spot + 1], way[spot + 2], way[spot + 3]
		copy.look[point], copy.up[point] = way.look[point], way.up[point]
	end
	return copy
end

-- The whole way for whoever is led along it: its beginning floor by floor, Bend.LEAD yards of it (or as far
-- as a beginning asked for went, where that was further); then on over nodes from the place it ends at. A
-- node's place may be on a ledge up a cliff it stands by, which the way over nodes goes by and nobody
-- standing at the foot should be led at. As NearWay: nil where nothing is found up close, and true while it
-- is worked out.
function Bend.Begun(search, node, north, west, level)
	-- (Where the floors give up short of that, Bend.NEAR yards of it from then on: the floors may not join
	-- where the way over nodes does, and the beginning, through a door, is still worth finding exactly.)
	local reach = search.leadNear and Bend.NEAR or max(search.nearReach or 0, Bend.LEAD)
	local near, working, gave = NearWay(search, node, north, west, reach, level)
	if gave and reach > Bend.NEAR then
		search.leadNear = true
		near, working = NearWay(search, node, north, west, Bend.NEAR, level)
	end
	if not near or not near.node then return near, working end
	return Pocket.Then(near, WayOf(search, near.node), near.seconds)
end

-- way; or, while it is being worked out from where it is asked, the way from where it was last known
-- (a step or two back) and "working"; or nil. split: the level the goal is gone into on, where its node
-- is on another (SearchFor).
function Pocket.AskWay(world, north, west, a, b, reach, level, lead, split, up)
	-- split is the level when the goal is gone into as a pocket; otherwise the level asked for.
	local asked = split or level
	local search = SearchFor(world, a, b, lead, asked, up)
	if not search then return nil end
	-- The way someone is led along now, from a place a search worn out by everyone else's asking hasn't
	-- reached: that search is begun anew, so it is worked out rather than taken as too far.
	if lead and search.looked >= WORN then
		local _, _, node = From(search.data, north, west, world)
		if node and not Known(search, node) and not search.farFrom[node] then
			Drop(search)
			stats.restarted = stats.restarted + 1
			search = SearchFor(world, a, b, lead, asked, up)
			if not search then return nil end
		end
	end
	stats.asked = stats.asked + 1
	stats.by.ways = stats.by.ways + 1
	-- (The way being led along: served first of what is left to work out, T.Work.)
	if lead then search.lead = true end
	local seconds, state, _, node, out = Answer(search, north, west)
	if seconds and reach then
		search.nearReach = reach
		local way, working = NearWay(search, node, north, west, reach, level)
		-- (Up close to a lift or a drop, and on over nodes from there: the ride or the fall is in sight.)
		if way and way.node and Pocket.Rides(search, way.node, true) then return Pocket.Then(way, WayOf(search, way.node, reach), way.seconds) end
		if way then return way end
		-- (While the way up close is worked out, the way over nodes, for whoever shows something meanwhile.)
		if working then return out and Pocket.Lead(out, WayOf(search, node, reach)) or Ahead(WayOf(search, node, reach), north, west), "working" end
	end
	-- The whole way someone is led along: its beginning floor by floor (Bend.Begun).
	if seconds and lead and not reach and not out then
		local way, working = Bend.Begun(search, node, north, west, level)
		if way then return way end
		if working then return Ahead(WayOf(search, node), north, west), "working" end
		-- Nothing found floor by floor from here where the floors are known (just off a flight in a city,
		-- the search up close gave up): the way over nodes, which runs through whatever stands between,
		-- told as "rough". Whoever leads someone along it asks again from a little further on (Trail.lua).
		if GroundOf(world, search.data) then return Ahead(WayOf(search, node), north, west), "rough" end
	end
	-- (From a pocket: its way out, then the way over nodes from where that leads.)
	if seconds then return out and Pocket.Lead(out, WayOf(search, node, reach)) or Ahead(WayOf(search, node, reach), north, west) end
	-- No way over nodes to a place this near: floor by floor all the way, where the nodes miss one
	-- (a board up a cliff the nodes' links never climb). The way someone is led takes the same search
	-- when it was asked whole.
	local floorReach = reach or lead and Close.FLOOR_ONLY
	if state ~= "working" and floorReach and search.north and GroundOf(world, search.data)
		and (search.north - north) ^ 2 + (search.west - west) ^ 2 <= Close.FLOOR_ONLY * Close.FLOOR_ONLY then
		local way, working = NearWay(search, nil, north, west, floorReach, level)
		if way then return way end
		if working then return nil, "working" end
	end
	if state == "working" then
		local kept = reach and search.near or search.whole
		return kept and kept.way, state
	end
	-- (Not found within the search's reach, which everyone else's asking may have worn out: "far", so whoever
	-- asks can tell it from no way at all, and ask again as the way led along, which begins it anew.)
	return nil, state == "far" and "far" or nil
end

-- On the level asked for, into a cave under the hill the goal's node stands for; where there is no way in
-- on it, as the node has it.
function T.AskWay(world, north, west, a, b, reach, level, lead, up, done)
	-- (On no floor that is known: not known. A level that the height asked for gainsays is the height's
	-- floor's: Tier.Asked.)
	if level == T.NOWHERE then return nil end
	if type(a) == "table" then up = nil else level = Tier.Asked(world, a, b, level, up) end
	local way, state
	local data = level and type(a) ~= "table" and T.data.nodes[world]
	if data and Pocket.Split(world, data, a, b, level) then
		way, state = Pocket.AskWay(world, north, west, a, b, reach, level, lead, level, up)
	end
	if not way and not state then way, state = Pocket.AskWay(world, north, west, a, b, reach, level, lead, nil, up) end
	if done and state == "working" then
		Tier.Wait(done, function() return T.AskWay(world, north, west, a, b, reach, level, lead, up) end)
	end
	return way, state
end

-- How long a way takes as though a fall could be slowed `fall` yards deep (and steered `glide` yards) and
-- water were walked on or not, whatever the player can do now: for whoever says what those save, or would.
-- nil: not known, or no way at all so (a mesa only a drop comes off).
-- soon: as Ask, out of a frame's share (nil and "working" until it is known); else worked out on the spot.
local function Supposing(world, north, west, toNorth, toWest, fall, glide, water, soon)
	local data = T.data.nodes[world]
	if not data then return nil end
	SearchFor(world, toNorth, toWest)
	local row, col = NodeAt(data, toNorth, toWest)
	-- (Kept to the roads as the ways are: what a spell saves is of the way the character is led.)
	local key = ("as %d %d %d %d "):format(fall, glide, water and 1 or 0, select(2, Tier.Kept())) .. (world * SPAN + row * STRIDE + col)
	one[1], one[2] = toNorth, toWest
	local search = searches[key] or Begin(data, key, one, nil, nil, Tier.RoadsOf(world, data) and world or nil)
	if not search then return nil end
	search.world, search.fall, search.glide, search.water, search.supposed = world, fall, glide, water, true
	stats.by.supposing = stats.by.supposing + 1
	local seconds, state = Answer(search, north, west, not soon)
	return seconds, state
end

-- With no fall slowed and no water walked on.
function T.Without(world, north, west, toNorth, toWest, soon)
	return Supposing(world, north, west, toNorth, toWest, 0, 0, false, soon)
end

-- As though a fall could be slowed `fall` yards deep, steered `glide` yards, and water walked on (`water`).
function T.With(world, north, west, toNorth, toWest, fall, glide, water, soon)
	return Supposing(world, north, west, toNorth, toWest, fall or 0, glide or 0, water and true or false, soon)
end

function T.Seconds(world, north, west, toNorth, toWest, level, up)
	if level == T.NOWHERE then return nil end
	level = Tier.Asked(world, toNorth, toWest, level, up)
	local search = SearchFor(world, toNorth, toWest, nil, level, up)
	if not search then return nil end
	stats.asked = stats.asked + 1
	stats.by.now = stats.by.now + 1
	local seconds, state, least = Answer(search, north, west, true)
	if seconds then return seconds end
	return nil, state, least
end

function T.Way(world, north, west, toNorth, toWest)
	local search = SearchFor(world, toNorth, toWest)
	if not search then return nil end
	stats.by.now = stats.by.now + 1
	local seconds, _, _, node, out = Answer(search, north, west, true)
	return seconds and Pocket.Lead(out, WayOf(search, node)) or nil
end

-- What finding ways over the ground has cost, as numbers: the counters, with what is kept now worked out
-- (searches kept, nodes held, searches still going, tiles of ground by world). For the task manager's
-- counters below, and the tests.
function T.Stats()
	local held, working = 0, 0
	for _, search in pairs(searches) do held = held + search.looked end
	for _ in pairs(pending) do working = working + 1 end
	stats.kept, stats.held, stats.working = count, held, working
	stats.ground = stats.ground or {}
	for world in pairs(stats.ground) do stats.ground[world] = nil end
	for world, data in pairs(T.data.nodes) do
		local tiles = 0
		for _ in pairs(data.tiles) do tiles = tiles + 1 end
		stats.ground[world] = tiles
	end
	return stats
end

if Shy.Counters then
local ROADS = { high = "kept to where mobs off them are " .. Tier.ROAD_ABOVE .. " levels above you or more",
	auto = "kept to where mobs off them are your level or higher", always = "kept to", never = "not kept to" }
local groundLabels = {}
Shy.Counters("Ground", function(row)
	local s = T.Stats()
	-- (Standing still, nothing marked idle should move.)
	row("Ways asked", s.asked, "idle")
	row("Not answered right away", s.waited)
	row("Asked for a time", s.by.seconds)
	row("Asked for a way", s.by.ways)
	row("Answered on the spot", s.by.now)
	row("Assuming Slow Fall", s.by.supposing)
	row("Searches begun", s.searches, "idle")
	row("Searches kept", s.kept, "of", SEARCHES)
	row("Nodes held", s.held, "of", HELD)
	row("Still going", s.working, "idle")
	row("Refused, no room", s.refused)
	row("Restarted for the trail", s.restarted)
	row("Nodes searched", s.nodes, "idle")
	row("Searching, ms", s.ms, "idle")
	row("Node tiles read again", s.tiles, "idle")
	row("Drop tiles read again", s.drops or 0, "idle")
	row("Tiles that wouldn't unpack", s.broken)
	row("Up close: searches", s.closes, "idle")
	row("Up close: floors looked at", s.cells)
	row("Up close: ms", s.closeMs)
	row("Up close: longest in a frame, ms", s.closeMost)
	row("Unpacking floors, ms", s.unpackMs)
	row("Unpacking, longest, ms", s.unpackMost)
	row("Texts inflated", s.inflates, "idle")
	row("A search's longest step, ms", s.stepMost)
	row("Drawing a way, longest, ms", s.shapeMost)
	row("Ways into cut-off spots", s.ins)
	row("Ways out of cut-off spots", s.outs)
	local lifts = T.Saved().lifts
	row("Lifts ridden on this account", lifts and #lifts or 0)
	row("Drops off a cliff", fallDeep > 0 and ("up to %d yards (spell %s)"):format(fallDeep, tostring(fallSpell)) or "none now")
	row("Water", waterOn and ("walked on (spell %s)"):format(tostring(waterSpell)) or "swum")
	row("Roads", Tier.dead and "not kept to while dead" or ROADS[T.Paths()])
	for world, tiles in pairs(s.ground) do
		local label = groundLabels[world]
		if not label then
			label = ("Tiles of ground kept, world %d"):format(world)
			groundLabels[world] = label
		end
		row(label, tiles)
	end
end, { idle = true, reset = function()
	for key, value in pairs(stats) do
		if type(value) == "number" then stats[key] = 0 end
	end
	for key in pairs(stats.by) do stats.by[key] = 0 end
end })
end

-- Where the game says the player is, as text: what an addon is told here (some places, an instance
-- among them, tell it nothing), and whether the minimap is there to be drawn on.
local function Said(value)
	if value == nil then return "nothing" end
	if issecretvalue and issecretvalue(value) then return "hidden" end
	return type(value) == "number" and ("%.1f"):format(value) or tostring(value)
end
if Shy.Counters then Shy.Counters("Where", function(row)
	local name, kind, _, _, _, _, _, world = GetInstanceInfo()
	row("Instance", ("%s (%s), map %s"):format(Said(name), Said(kind), Said(world)))
	local map = C_Map.GetBestMapForUnit("player")
	local info = map and C_Map.GetMapInfo(map)
	row("Map", ("%s (%s)"):format(Said(map), info and info.name or "no name"))
	local position = map and C_Map.GetPlayerMapPosition(map, "player")
	if position then
		local x, y = position:GetXY()
		row("On the map", ("%s, %s"):format(Said(x), Said(y)))
		local continent, spot = C_Map.GetWorldPosFromMapPos(map, position)
		if spot then
			local north, west = spot:GetXY()
			row("In the world", ("%s, north %s, west %s"):format(Said(continent), Said(north), Said(west)))
		else
			row("In the world", "nothing")
		end
	else
		row("On the map", "nothing")
	end
	local px, py, pz, pmap = UnitPosition("player")
	row("Unit position", ("%s, %s, %s on map %s"):format(Said(px), Said(py), Said(pz), Said(pmap)))
	row("Minimap", ("%s, %s yards across"):format(Minimap:IsShown() and "shown" or "hidden", Said(C_Minimap.GetViewRadius() * 2)))
	row("Ground for this world", world and T.data.nodes[world] and "loaded" or "none")
end) end

-- The tiles read from the ground's text are kept in two generations: those used within the last RINSE
-- seconds, and those used the RINSE before. A tile in the older one that is asked for moves to the newer;
-- the rest are let go at the next rinse. So what is kept is the ground in use, not all that was ever near.
T.Tier = Tier   -- (for a test of how tiles are kept)
T.RINSE = 30
T.OPEN_KEPT = { "open", "tiersOpen", "joinsOpen", "dropsOpen", "bendsOpen", "storeysOpen" }
T.ROADS_KEPT = { "open", "nodesOpen", "tollOpen" }   -- (a world's roads: its road cells, the nodes they run through, the tolls)
function Tier.Generation(holder, field)
	local older = holder[field]
	if not older then return end
	setmetatable(older, nil)
	holder[field] = setmetatable({}, { __index = function(newer, index)
		local tile = older[index]
		if tile ~= nil then rawset(newer, index, tile) end
		return tile
	end })
end
function T.Rinse()
	wipe(Tier.spare)
	for _, ground in pairs(T.data.floors) do ground.older, ground.olderUsed = nil, nil end
	for _, data in pairs(T.data.nodes) do
		for _, field in ipairs(T.OPEN_KEPT) do Tier.Generation(data, field) end
	end
	for _, roads in pairs(T.data.roads or {}) do
		for _, field in ipairs(T.ROADS_KEPT) do Tier.Generation(roads, field) end
		for _, lives in pairs(roads.levels or {}) do Tier.Generation(lives, "open") end
	end
	-- Searches grow as they are asked from farther on, past what was held when each was begun: over HELD
	-- nodes in all, those asked longest ago go, as long as none of them was asked since the last rinse.
	local held, now = 0, GetTime()
	for _, search in pairs(searches) do held = held + search.looked end
	while held > HELD do
		local oldest
		for _, search in pairs(searches) do
			if not pending[search] and (not oldest or Tier.Sooner(oldest, search, true)) then oldest = search end
		end
		if not oldest or now - oldest.asked < T.RINSE then break end
		held = held - oldest.looked
		Drop(oldest)
	end
end
-- Whether anything has been read or grown since the last rinse: a tile read anew or used again (it is in the
-- newer generation), searches over HELD, a job's tables kept to give again. Standing about with nothing
-- asked, nothing is: the ground in use is kept as it is, and not read again cold when the next way is asked.
function Tier.Grown()
	if next(Tier.spare) ~= nil then return true end
	local held = 0
	for _, search in pairs(searches) do held = held + search.looked end
	if held > HELD then return true end
	for _, data in pairs(T.data.nodes) do
		for _, field in ipairs(T.OPEN_KEPT) do
			if data[field] and next(data[field]) ~= nil then return true end
		end
	end
	for _, roads in pairs(T.data.roads or {}) do
		for _, field in ipairs(T.ROADS_KEPT) do
			if roads[field] and next(roads[field]) ~= nil then return true end
		end
		for _, lives in pairs(roads.levels or {}) do
			if lives.open and next(lives.open) ~= nil then return true end
		end
	end
	for _, ground in pairs(T.data.floors) do
		if ground.older and next(ground.older) ~= nil then return true end
	end
	return false
end
Tier.Rinse = Shy.Clocked("ground: a rinse", T.Rinse)
C_Timer.NewTicker(T.RINSE, function()
	if Tier.Grown() then Tier.Rinse() end
end)

-- The task manager: what the ground keeps, each cache with how to empty it and how big it is now, and what
-- the searches hold as counters. (A fight is time to let go of the tiles not used lately, and of what the
-- searches made that no one asks for.)
if Shy.Memory and Shy.Counters then
Shy.Memory.OnTidy(T.Rinse)
local function OpenTiles(grounds)
	local tiles = 0
	for _, ground in pairs(grounds) do
		if ground.open then for _ in pairs(ground.open) do tiles = tiles + 1 end end
	end
	return tiles
end
Shy.Memory.Cache("Terrain: tiles read (tiers, links, drops, bends, roads)", function()
	for _, data in pairs(T.data.nodes) do
		data.tiersOpen, data.joinsOpen, data.dropsOpen, data.bendsOpen, data.storeysOpen = nil, nil, nil, nil, nil
	end
	for _, roads in pairs(T.data.roads or {}) do
		roads.open, roads.nodesOpen, roads.tollOpen = nil, nil, nil
		for _, lives in pairs(roads.levels or {}) do lives.open = nil end
	end
end, function()
	local n = 0
	for _, data in pairs(T.data.nodes) do
		for _, field in ipairs(T.OPEN_KEPT) do
			if data[field] then for _ in pairs(data[field]) do n = n + 1 end end
		end
	end
	return n
end)
Shy.Memory.Cache("Terrain: searches over nodes", function()
	for _, search in pairs(searches) do Drop(search) end
	wipe(nowhere)
end, function() return count end)
Shy.Memory.Cache("Terrain: searches up close", function()
	wipe(jobs)
	wipe(closePending)
	wipe(Tier.spare)
	for _, search in pairs(searches) do search.job = nil end
end, function() return #jobs end)
Shy.Memory.Cache("Terrain: ways in", function()
	wipe(Pocket.ins)
	Pocket.kept = 0
end, function() return Pocket.kept end)
Shy.Memory.Cache("Terrain: unpacked node tiles", function()
	for _, data in pairs(T.data.nodes) do data.open = nil end
end, function() return OpenTiles(T.data.nodes) end)
Shy.Memory.Cache("Terrain: unpacked floor tiles", function()
	for _, ground in pairs(T.data.floors) do ground.open, ground.older, ground.olderUsed = nil, nil, nil end
end, function() return OpenTiles(T.data.floors) end)
Shy.Counters("Searches", function(row)
	local costs, heaps, goals, vias, kept = 0, 0, 0, 0, 0
	for _, search in pairs(searches) do
		kept = kept + 1
		heaps = heaps + search.heap.n
		for _ in pairs(search.cost) do costs = costs + 1 end
		for _ in pairs(search.via) do vias = vias + 1 end
		for _ in pairs(search.goalAt) do goals = goals + 1 end
	end
	row("Searches", kept)
	row("Their costs", costs)
	row("Their heaps", heaps)
	row("Their vias", vias)
	row("Their goals", goals)
	local near, wide = 0, 0
	for _, job in ipairs(jobs) do
		for _ in pairs(job.near) do near = near + 1 end
		wide = wide + job.heap.n
	end
	row("Searches up close", #jobs)
	row("Their floors", near)
	row("Their heaps", wide)
	local nowhereCount = 0
	for _ in pairs(nowhere) do nowhereCount = nowhereCount + 1 end
	row("Goals with no ground", nowhereCount)
end)
end
