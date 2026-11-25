-- Quest ground: where what a quest asks for is found, on the world map and the minimap.
--
-- One thing is lit at a time: what the leading stop needs now, or a hovered or clicked pin's quests.
-- Nothing is drawn for the other quests beyond their marks.
--
-- What there is to do has a color of its own (KIND): kill, loot, gather, talk, go. The ground of a kind
-- is a region: one outline round everything within reach of a spawn, spawns near one another sharing
-- it. It is filled flat and faint in the color (thin rows of plain lines across it, each cut where the
-- outline is), its edge is one
-- textured line (Media\Edge: a hairline in the color on a deep case of it, a soft shadow falling
-- outward) and on that edge a second, wider one (Media\Glow: empty on its outward half, on its inward
-- half a hug of the color fading in). Two kinds on one spot overlap, and the overlap is where both
-- are done. A thing with
-- only a few spawns far apart is found by its exact places: a pointer (Media\Spots) at each, at any
-- zoom; a camp or a crowd is its ground alone. An object (a pine cone, a chest, a totem) stands where
-- it is: a pointer at each of its places, however many, and never ground; what is gathered or used has
-- the gather mark's green cog for its pointer, not the pin. What a search found at its
-- exact places is those pointers and nothing else: no ground round someone who stands in one spot. Nor round an objective
-- found only at exact places (three valves, a wardrobe, a creature with a name): its pointers, and
-- neither a ground of its own nor the game's area for the quest.
-- A dot or a pointer under the mouse says who or what stands there (Ground.SpawnAt); the map has no key
-- of its own for it (the card, the hovers and the quest log say what is done to what).
-- It is for a zone's own map, or a view about as close: on a continent's map with the zone a small part of
-- the window none of it is drawn, too small there to read and in the way of the zones (Pins.lua's Near).
-- A clicked ground keeps its light, and a gleam runs along its edge.
-- Where the game itself has an area for a quest (the server sends polygons for many quests), a
-- QuestPOIFrame of ours draws that instead of the spawn outline, with the same edge and glow baked
-- into a strip per kind (Media\Blob<Kind>), since such a frame tints nothing. Of an area in pieces,
-- only those holding spawns of what is still to do are kept: a camp whose work is done goes from the
-- maps and from the route.
-- The minimap draws the same ground in lighter weights, clipped at its rim, turned with the map; where
-- a ground runs on past the rim, its outline carries on along the rim, so what shows of it is closed.
-- Nothing is added to the map as light, so no amount of ground can white it out.
--
-- What it costs: an outline is traced once and kept by what it is of, a large one as a job spread over
-- frames, as is asking the game for an area (Work that waits); the minimap's lines are laid again only
-- when something moved. The task manager says what each piece of work took.

local ADDON, ns = ...
local D, W, L, R = ns.Data, ns.World, ns.Log, ns.Route
local UI = Shy.UI
local C = UI.colors

local Ground = {}
ns.Ground = Ground

local UNITS = 10000
-- A ground's shape: how far it reaches from its spawns, and how finely it is drawn.
local SHAPE = {
	radius = 40,  -- yards: how far from a spawn its ground reaches (its wander, and room to pull it)
	floor = 13,  -- and on the world map at least this much on screen
	step = 1.3,  -- the reach grows from SHAPE.radius in steps of this, so a zoom seldom redraws
	reach = 1.5,  -- the grid is told how near a spawn is out to this many radii
	fine = 3,  -- grid cells to a radius
	hole = 14,  -- a gap inside a region smaller than this many square radii is closed
	slack = 0.03,  -- an outline's kept points are within this of it, in radii
	most = 1500,  -- spawns taken for the world map
	few = 12,  -- a thing with no more spawns than this, nearly every one a place of its own, is
	-- found by its exact places
}
SHAPE.level = 1 - 1 / SHAPE.reach  -- its value one radius from the nearest spawn: where the outline runs
-- How grounds, pointers and dots are drawn on the world map and the minimap.
local DRAW = {
	miniMost = 70,  -- pointers on the minimap
	miniDots = 160,  -- spawns shown as dots on the minimap while the player stands on their ground
	miniDot = 16,  -- a spawn's picture cell on the minimap (Spawns: 32 texel cells, its picture ten units of it)
	dotLight = 0.45,
	dotDeep = 0.32,  -- a spawn's face: this far toward white; its case: this much of the color
	miniFar = 80,  -- yards past the minimap's corner still chosen, for the steps until the next choice
	miniNear = 25,  -- yards: a pointer this near the player fades, so the arrow stays clear
	miniNearAlpha = 0,
	-- A pointer's picture: the pin in it is half as high, with its point on the picture's middle.
	spot = 22,
	miniSpot = 22,
	mapDot = 14,
	mapDots = 400,  -- a spawn's picture cell on the world map, and the most shown
	-- The edge line's thickness in screen pixels (the hairline runs along its middle, the shadow on the
	-- outward half) and the glow line's (centred on the edge too, its outward half empty); the media builder
	-- draws the strips for these. The minimap's are the same strips thinner.
	edge = 8,
	glow = 28,
	miniEdge = 6,
	miniGlow = 16,
	widthSlack = 0.03,  -- a zoom tells the outlines their width again once it is this share off (under a pixel)
	-- The fill: rows about DRAW.fillRow screen pixels high, each from the outline to the outline, so its steps
	-- are hidden under the edge. Its lines are plain and whole; the frame they are on is faint.
	fillAlpha = 0.16,
	miniFillAlpha = 0.14,
	fillRow = 3,
	miniFillRow = 6,  -- (the minimap's rows: a third fewer to lay than at 4, and as smooth at its size)
	fillMost = 600,  -- rows at most down one ground, however far the map is zoomed in
	breath = 2.4,
	breathLow = 0.78,  -- the glow's slow pulse: seconds, lowest alpha
	gleamLength = 90,
	gleamSpeed = 190,  -- a clicked ground's gleam: screen pixels long, screen pixels a second
	gleamWide = 2.6,  -- its line's thickness in screen pixels
	apart = 100,  -- map units: an object's spawns spanning this much count as spread out
	names = 2,  -- names in a row of the key
}
-- Spawns.tga: a cell a kind across (the case on its top row, the face under it), 8 by 2.
local SPAWN_CELL = { kill = 0, loot = 1, gather = 2, talk = 3, go = 4, find = 5, escort = 6, body = 7, farm = 1 }
local SOLID = "Interface\\Buttons\\WHITE8X8"
local MEDIA = ns.MEDIA
local EDGE_ART, GLOW_ART, ART, DASH = MEDIA .. "Edge", MEDIA .. "Glow", MEDIA .. "Spots", MEDIA .. "Dash"
local DOT_ART = ns.MEDIA .. "Spawns"
local STRIPE = { 0.25, 0.5 } -- the solid stretch of the dash's picture
-- The game's own areas (QuestPOIFrame): the frame draws only the game's own pictures (a file of ours, TGA or
-- BLP, is its solid green), so it is asked where its area is instead:
-- UpdateMouseOverTooltip(x, y) says whether a point of the map lies in it, and a grid of such points
-- (BLOB.sample across the map's width, as many down as its height is to its width) becomes the area's own
-- ground, drawn with the same lines as a spawn's. Only where that gives nothing does the frame itself
-- draw, with the game's white border and no fill.
local BLOB = {
	sample = 160,
	fill = 0,
	border = 255,
	scalar = 1.0,
	spline = 12,
	reach = 1.15,  -- a sample's ground reaches this many cells, so the outline hugs the samples
	near = 2,  -- cells: a spawn this near a piece of the game's area is of that piece
}
local BLIZZARD_BORDER_WHITE = "Interface\\WorldMap\\UI-QuestBlob-Outside-white"
local BLIZZARD_FILL = "Interface\\WorldMap\\UI-QuestBlob-Inside"

-- The game lays a line's picture along it from start to end with the picture's top on the LEFT of the
-- way. The loops run with the ground on their left with y down, which is on their right on the screen,
-- so a line laid from a piece's start to its end has the strip's top outward: the edge's shadow and the
-- glow's full end, as they should be.

-- The kinds and their colors are the marks' (Marks.lua): an objective's mark, its ground and the
-- pointers on that ground are one color.
local KIND = ns.KIND
Ground.KIND = KIND
local ORDER = { "kill", "loot", "gather", "talk", "buy", "go", "escort", "farm", "find" }
-- How a place serves a quest (Route.lua's GoalPlaces, and "start", "go", "find" here) to its kind,
-- and the word for it where the kind's own doesn't say it.
local HOW = ns.HOW
local WORD = { use = "Use", sells = "Buy", start = "Quest" }
local FOUND = { how = "find" }
-- What is done to an object (a pine cone, a chest, a totem): it stands where it is, so it is found at
-- its places, a pointer at each, never ground. Ground is for what wanders round where it stands.
local STILL = { use = true, holds = true }
local function Still(what)
	return what ~= nil and (STILL[what.how] or what.object) == true
end
-- Ground is only for a crowd of enemies, to show how far a pull reaches. Everything else (a vendor, a
-- person to talk to, a thing to gather, a lone enemy) is a pointer at its place. (A search's crowd is one
-- too: what it looked for is mostly creatures.)
local ENEMY = { kill = true, drops = true, find = true, farm = true }

-- Work that waits

-- Two things take longer than a frame has to spare: tracing the outline of a large ground, and asking
-- the game where a quest's area is. They run as jobs, a few milliseconds a frame, and the maps are
-- drawn again when one is done. A job calls Breathe() as it goes, which hands the rest of the frame
-- back once the jobs' share of it is spent.
local SHARE = 2              -- milliseconds of a frame the jobs may take
local jobs = {}              -- oldest first: { run (a coroutine), name, took, fail }
local working = false        -- a job is running now
local sliceFrom = 0          -- when this frame's share began
local stepping = false       -- the next step is on its way
local failed, failedTold     -- the last job's error, for the timing report; said once in chat

local function Breathe()
	if working and debugprofilestop() - sliceFrom >= SHARE then coroutine.yield() end
end

local Step
local function StepSoon()
	if stepping then return end
	stepping = true
	C_Timer.After(0, Step)
end

-- One frame's share: the oldest job runs until it is done, has had the share, or asks for the next
-- frame (it yields "frame").
function Step()
	stepping = false
	sliceFrom = debugprofilestop()
	local finished, broke = false, nil
	repeat
		local job = jobs[1]
		local from = debugprofilestop()
		working = true
		local ok, wish = coroutine.resume(job.run)
		working = false
		job.took = job.took + debugprofilestop() - from
		if not ok or coroutine.status(job.run) == "dead" then
			table.remove(jobs, 1)
			Shy.Clock(job.name):Lap(job.took)
			if ok then
				finished = true
			else
				broke = tostring(wish)
				if job.fail then job.fail() end
			end
		end
	until not jobs[1] or wish == "frame" or debugprofilestop() - sliceFrom >= SHARE
	Shy.Clock("jobs, a frame's share"):Lap(debugprofilestop() - sliceFrom)
	if jobs[1] then StepSoon() end
	if finished and ns.ApplyPins then ns.ApplyPins() end
	if broke then
		-- The game shows no errors here: said once in chat, and handed to the error bag.
		failed = broke
		if not failedTold then
			failedTold = true
			ns.T:Print("a quest area couldn't be drawn. |cff888888/shy errors|r has the error.")
		end
		geterrorhandler()(broke)
	end
end

-- Run fn as a job. fail: called if it errors, to leave things as they were.
local function Later(name, fn, fail)
	jobs[#jobs + 1] = { run = coroutine.create(fn), name = name, took = 0, fail = fail }
	StepSoon()
end

-- Outlines are kept by what they are of (a key the caller makes): the route is rebuilt far more often
-- than the ground changes. A ground of more than SOON points is traced as a job when the caller can
-- `wait`: nil comes back until it is done.
local SOON = 150
local MOST_TRACED = 60
local traced, tracedCount = {}, 0   -- by key: the loops (Ground.Loops), or false while they are being traced
local tracedAt = { clock = 0 }      -- by key: when it was last asked for
local function Traced(key, xs, ys, n, radius, wait)
	local loops = traced[key]
	tracedAt.clock = tracedAt.clock + 1
	if loops then
		tracedAt[key] = tracedAt.clock
		return loops
	end
	if loops == false and wait then return nil end
	if loops == nil then
		-- Full: the one asked for longest ago goes (never one being traced). All of them at once, a route
		-- with more than MOST_TRACED to draw traced every one again, over and over, standing still.
		if tracedCount >= MOST_TRACED then
			local oldest, stamp
			for k, at in pairs(tracedAt) do
				if k ~= "clock" and traced[k] and (not stamp or at < stamp) then oldest, stamp = k, at end
			end
			if oldest then
				traced[oldest], tracedAt[oldest] = nil, nil
				tracedCount = tracedCount - 1
			end
		end
		tracedAt[key] = tracedAt.clock
		tracedCount = tracedCount + 1
		if wait and n > SOON then
			-- The caller's lists are its own to use again: the job has copies.
			local px, py = {}, {}
			for i = 1, n do px[i], py[i] = xs[i], ys[i] end
			traced[key] = false
			-- (Broken off, it is asked for again: left as being traced, that ground was never drawn at that zoom.)
			Later("outline, as a job", function() traced[key] = Ground.Loops(px, py, n, radius) end, function()
				traced[key], tracedAt[key] = nil, nil
				tracedCount = tracedCount - 1
			end)
			return nil
		end
	end
	local from = debugprofilestop()
	loops = Ground.Loops(xs, ys, n, radius)
	Shy.Clock("outline, at once"):Lap(debugprofilestop() - from)
	traced[key] = loops
	return loops
end

-- What a stop is about

-- { map, x, y } points to a list of { map, points = { x, y, x, y, ... } }.
local function AsPlaces(points)
	local places, by = {}, {}
	for _, point in ipairs(points) do
		local place = by[point.map]
		if not place then
			place = { map = point.map, points = {} }
			by[point.map] = place
			places[#places + 1] = place
		end
		place.points[#place.points + 1] = point.x
		place.points[#place.points + 1] = point.y
	end
	return places
end

-- The place lists a stop's quests cover ({ map, dungeon, points } records), the names of what is
-- there, and what each list is ({ how, name, quest, objective }, by the list's index). A zone stop gives
-- its quest givers.
--   live: only what is needed now (a guide step's objectives and kill targets, an objective pin), for a
--   stop lit unasked. Not quests a step only accepts or turns in, and no NPCs to talk to.
function Ground.Of(stop, live)
	-- From a search: places already known.
	if not stop.ground and stop.places then stop.ground = { AsPlaces(stop.places) } end
	if stop.ground then
		local whats = {}
		-- (Where you farm is its own kind, in its own color: ShyFarm's farm stop.)
		local how = stop.farm and "farm" or "find"
		for i = 1, #stop.ground do whats[i] = { how = how, name = stop.who } end
		return stop.ground, { stop.who }, whats
	end
	local lists, names, whats, seen, named = {}, {}, {}, {}, {}
	-- what: one { how, name } for all of `more`, or one for each of them by index.
	local function Take(more, called, what)
		for i, places in ipairs(more) do
			if not seen[places] then
				seen[places] = true
				lists[#lists + 1] = places
				whats[#lists] = what and (what.how and what or what[i]) or FOUND
			end
		end
		for _, name in ipairs(called or {}) do
			if not named[name] then
				named[name] = true
				names[#names + 1] = name
			end
		end
	end
	if stop.kind == "zone" then
		if live then return lists, names, whats end
		for _, quest in ipairs(stop.zone.quests) do
			for _, token in ipairs(quest.starts) do
				local thing = (token.kind == "n" or token.kind == "o") and D.Thing(token.kind, token.id)
				if thing and (token.kind == "o" or L.Friendly(thing)) then
					local found = {}
					for _, place in ipairs(thing.places) do
						if place.map == stop.zone.map and not place.dungeon and place.points[1] then
							found[#found + 1] = { map = place.map, points = { place.points[1], place.points[2] } }
						end
					end
					Take({ found }, { thing.name }, { how = "start", name = thing.name, object = token.kind == "o" })
				end
			end
		end
		return lists, names, whats
	end
	local asked = {}
	local function Quest(id, objective)
		local key = id .. ":" .. (objective or 0)
		if asked[key] then return end
		asked[key] = true
		Take(R.Ground(id, objective))
	end
	-- A quest started by an object with spread-out spawns: it is at one of them, so all are shown, live
	-- or not. An NPC or a fixed object has its pin only. One started by an item: wherever the item is
	-- had (who drops it, what holds it, who sells it), as an objective's item is.
	local function Starter(id)
		local quest = D.Quest(id)
		for _, token in ipairs(quest and quest.starts or {}) do
			if token.kind == "i" then Take(R.GroundOf(token)) end
			local object = token.kind == "o" and D.Object(token.id)
			local ground = object and D.Ground(object)
			local map, left, right, top, bottom, apart
			for _, place in ipairs(ground or {}) do
				if not place.dungeon and place.points[1] then
					apart = apart or (map ~= nil and map ~= place.map)
					map = place.map
					for i = 1, #place.points, 2 do
						local x, y = place.points[i], place.points[i + 1]
						left, right = math.min(left or x, x), math.max(right or x, x)
						top, bottom = math.min(top or y, y), math.max(bottom or y, y)
					end
				end
			end
			if apart or (map and (right - left > DRAW.apart or bottom - top > DRAW.apart)) then
				Take({ ground }, { object.name }, { how = "start", name = object.name, quest = id, object = true })
			end
		end
	end
	local views = stop.views or { stop.view }
	if live then views = { stop.view } end
	for _, view in ipairs(views) do
		for _, line in ipairs(view.lines) do
			-- A "complete" line shows its one objective; accept and turnin lines the whole quest. Lit unasked,
			-- a step's objectives and items show though the step says to do another first ("then"): its pin
			-- stands for all of them, as its hover lists them.
			local objective = line.command == "complete" or line.command == "collect"
			if line.id and not line.done and (not live or line.can or objective) then
				if line.command == "complete" then
					Quest(line.id, line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1)
				elseif line.command == "accept" then
					if not live then Quest(line.id) end
					Starter(line.id)
				elseif line.command == "collect" then
					-- (Lit unasked or hovered alike: a step that gathers an item before an objective that needs
					-- it lit only the objective's ground under the mouse, the forge without the diggers.)
					Take(R.GroundOf({ kind = "i", id = line.id }))
				elseif not live and line.command == "turnin" then
					Quest(line.id)
				end
			end
		end
		for _, target in ipairs(view.targets or {}) do
			local npc = target.kind == "mob" and target.npc and D.Npc(target.npc)
			if npc then Take({ D.Ground(npc) }, { npc.name }, { how = "kill", name = npc.name, id = npc.id }) end
		end
	end
	if not stop.view then
		-- An objective pin shows that objective, any other the whole quest; a merged pin, each member's.
		for _, each in ipairs(stop.members or { stop }) do
			for _, action in ipairs(each.actions or {}) do
				-- (Standing on its ground, the route's own stop for a quest of several lights all of them, each
				-- spawn in its objective's shade: the camp is where they are told apart. An objective's mark, or
				-- one pointed at, has a key and lights its own alone.)
				local several = each.among and not each.key and action.kind == "goal" and ns.Objectives(action.id) ~= nil
				if not live or action.kind == "goal" then Quest(action.id, not several and each.objective or nil) end
				if action.kind == "pickup" then Starter(action.id) end
			end
		end
	end
	return lists, names, whats
end

-- The stop to light unasked: `stop` if it has spawns to look for, else the next of the first AHEAD
-- stops that has (a turn-in on the way doesn't dim the objectives still being worked on).
local AHEAD = 4
function Ground.Working(stop)
	local function Looks(each)
		for _, places in ipairs((Ground.Of(each, true))) do
			for _, place in ipairs(places) do
				if not place.dungeon and place.points[1] then return true end
			end
		end
		return false
	end
	if stop and Looks(stop) then return stop end
	for i = 1, math.min(#R.stops, AHEAD) do
		local each = R.stops[i]
		if each ~= stop and each.kind ~= "zone" and each.kind ~= "fly" and each.kind ~= "errand" and Looks(each) then return each end
	end
	return stop
end

-- Map to world

-- A zone map is an affine piece of the world: three corners are asked of the game once, and each
-- spawn's world position is then computed.
local frames = {}
local function Frame(map)
	local frame = frames[map]
	if not frame then
		local c, n0, w0 = W.ToWorld(map, 0, 0)
		local cx, nx, wx = W.ToWorld(map, UNITS, 0)
		local cy, ny, wy = W.ToWorld(map, 0, UNITS)
		if not c or cx ~= c or cy ~= c then return nil end
		frame = { continent = c, n0 = n0, w0 = w0, nx = (nx - n0) / UNITS, wx = (wx - w0) / UNITS,
			ny = (ny - n0) / UNITS, wy = (wy - w0) / UNITS, yards = math.sqrt((nx - n0) ^ 2 + (wx - w0) ^ 2) }
		frame.tall = math.sqrt((ny - n0) ^ 2 + (wy - w0) ^ 2)
		if frame.yards <= 0 then return nil end
		frames[map] = frame
		-- (Counted: a set gathered before a map was placed is made again once it is.)
		frames.n = (frames.n or 0) + 1
	end
	return frame
end

-- The world position of a point of a map (map units).
local function ToWorld(frame, x, y)
	return frame.n0 + frame.nx * x + frame.ny * y, frame.w0 + frame.wx * x + frame.wy * y
end

-- Outlines

-- The ground is everything within a radius of a spawn: a circle round each, and where circles meet
-- one outline round them all. Nothing is added up: a thick camp reaches no farther past its spawns
-- than a lone one. Each grid node holds how near its nearest spawn is (1 on it, SHAPE.level a radius off,
-- 0 at SHAPE.reach radii and past), so the outline is traced where that is SHAPE.level.

-- A square of the grid cut by the outline: the edges it enters and leaves by (1 top, 2 right,
-- 3 bottom, 4 left), by which corners are inside (top left 1, top right 2, bottom right 4, bottom
-- left 8), what is inside on the left of the way. Two opposite corners: SADDLE, apart or joined.
local SEGMENTS = {
	{ 4, 1 }, { 1, 2 }, { 4, 2 }, { 2, 3 }, false, { 1, 3 }, { 4, 3 }, { 3, 4 }, { 3, 1 }, false, { 3, 2 }, { 2, 4 }, { 2, 1 }, { 1, 4 },
}
local SADDLE = { [5] = { { 4, 1, 2, 3 }, { 4, 3, 2, 1 } }, [10] = { { 1, 2, 3, 4 }, { 1, 4, 3, 2 } } }

-- Where the outline crosses edge `edge` of the square at column i, row j: the edge's key (the squares
-- either side of it agree on it), and the point, in cells. a, b, c, d: the square's corners, as above.
local function Crossing(edge, i, j, cols, a, b, c, d)
	local node = j * cols + i
	if edge == 1 then return node * 2, i + (SHAPE.level - a) / (b - a), j end
	if edge == 2 then return (node + 1) * 2 + 1, i + 1, j + (SHAPE.level - b) / (c - b) end
	if edge == 3 then return (node + cols) * 2, i + (SHAPE.level - d) / (c - d), j + 1 end
	return node * 2 + 1, i, j + (SHAPE.level - a) / (d - a)
end

-- A closed line of `count` points (x, y, x, y, ...) without those within `slack` of the line between
-- the points kept either side of them. Returns the kept points, with .n.
local function Thin(loop, count, slack)
	local out, n = { loop[1], loop[2] }, 1
	local held, h = {}, 0
	for i = 2, count + 1 do
		local at = (i - 1) % count + 1
		local ax, ay = out[n * 2 - 1], out[n * 2]
		local dx, dy = loop[at * 2 - 1] - ax, loop[at * 2] - ay
		local reach = math.sqrt(dx * dx + dy * dy) * slack
		local straight = reach > 0
		if straight then
			for k = 1, h do
				local off = (loop[held[k] * 2 - 1] - ax) * dy - (loop[held[k] * 2] - ay) * dx
				if off > reach or off < -reach then
					straight = false
					break
				end
			end
		end
		if not straight and h > 0 then
			n = n + 1
			out[n * 2 - 1], out[n * 2] = loop[held[h] * 2 - 1], loop[held[h] * 2]
			h = 0
		end
		h = h + 1
		held[h] = at
	end
	out.n = n
	return out
end

-- The outlines' pieces by the band of the ground they cross (bands a cell high, from .top down to
-- .bottom): loops.bands[band] = { ax, ay, bx, by, ... }. A row across the ground then looks only at the
-- pieces near it (Cross).
local function Band(loops)
	local cell, top, bottom = loops.cell, math.huge, -math.huge
	for _, loop in ipairs(loops) do
		for i = 1, loop.n do
			local y = loop[i * 2]
			if y < top then top = y end
			if y > bottom then bottom = y end
		end
	end
	local bands = {}
	for _, loop in ipairs(loops) do
		local n = loop.n
		for i = 1, n do
			local k = i % n + 1
			local ax, ay, bx, by = loop[i * 2 - 1], loop[i * 2], loop[k * 2 - 1], loop[k * 2]
			if ay ~= by then
				for band = math.floor((math.min(ay, by) - top) / cell), math.floor((math.max(ay, by) - top) / cell) do
					local list = bands[band]
					if not list then
						list = {}
						bands[band] = list
					end
					local m = #list
					list[m + 1], list[m + 2], list[m + 3], list[m + 4] = ax, ay, bx, by
				end
			end
		end
	end
	loops.top, loops.bottom, loops.bands = top, bottom, bands
end

-- Where the row at `y` crosses a traced ground's outlines, into `out` from left to right; returns how
-- many. The ground lies between the first and the second, the third and the fourth, and so on.
local function Cross(loops, y, out)
	local list = loops.bands and loops.bands[math.floor((y - loops.top) / loops.cell)]
	if not list then return 0 end
	local n = 0
	for e = 1, #list, 4 do
		local ay, by = list[e + 1], list[e + 3]
		if (ay <= y) ~= (by <= y) then
			local x = list[e] + (y - ay) / (by - ay) * (list[e + 2] - list[e])
			local at = n
			while at >= 1 and out[at] > x do
				out[at + 1] = out[at]
				at = at - 1
			end
			out[at + 1] = x
			n = n + 1
		end
	end
	return n
end
local cuts = {}              -- a row's crossings, used again for each row

-- The outlines round everything within `radius` of the n points (xs, ys), in the points' unit: a list
-- of closed lines, each x, y, x, y, ... with .n points, the ground on the left of the way (y down),
-- .hole for the edge of a gap inside it, .depth for how far in its middle is. The list also carries
-- what a row across the ground is cut by (Band; .cell: a SHAPE.fine share of the radius).
function Ground.Loops(xs, ys, n, radius)
	local loops = { cell = radius / SHAPE.fine }
	if n == 0 then return loops end
	local cell, reach = radius / SHAPE.fine, radius * SHAPE.reach
	local left, right, top, bottom = xs[1], xs[1], ys[1], ys[1]
	for i = 2, n do
		local x, y = xs[i], ys[i]
		if x < left then left = x elseif x > right then right = x end
		if y < top then top = y elseif y > bottom then bottom = y end
	end
	-- A grid over the points with room round it for the reach, so every outline closes.
	local far = reach / cell
	local room = math.ceil(far) + 1
	local ox, oy = left - room * cell, top - room * cell
	local cols = math.ceil((right - left) / cell) + room * 2 + 1
	local rows = math.ceil((bottom - top) / cell) + room * 2 + 1
	local grid, first, last = {}, {}, {}   -- how near the nearest point is at each node; each row's first and last node with any
	local share = 1 / reach
	for p = 1, n do
		local gx, gy = (xs[p] - ox) / cell, (ys[p] - oy) / cell
		local i0, i1 = math.ceil(gx - far), math.floor(gx + far)
		for j = math.ceil(gy - far), math.floor(gy + far) do
			local dy = (j - gy) * cell
			local row = j * cols
			for i = i0, i1 do
				local dx = (i - gx) * cell
				local near = 1 - math.sqrt(dx * dx + dy * dy) * share
				if near > (grid[row + i] or 0) then grid[row + i] = near end
			end
			if not first[j] or i0 < first[j] then first[j] = i0 end
			if not last[j] or i1 > last[j] then last[j] = i1 end
		end
		-- A large ground is traced as a job: the frame gets its turn.
		if p % 16 == 0 then Breathe() end
	end
	-- Each cut square's piece of outline, from the edge it enters by to the one it leaves by.
	local onward, px, py = {}, {}, {}
	for j = 0, rows - 2 do
		local from, to = first[j], last[j]
		if first[j + 1] and (not from or first[j + 1] < from) then from = first[j + 1] end
		if last[j + 1] and (not to or last[j + 1] > to) then to = last[j + 1] end
		if from then
			local row, under = j * cols, (j + 1) * cols
			for i = from - 1, to do
				local a, b, c, d = grid[row + i] or 0, grid[row + i + 1] or 0, grid[under + i + 1] or 0, grid[under + i] or 0
				local cut = (a >= SHAPE.level and 1 or 0) + (b >= SHAPE.level and 2 or 0) + (c >= SHAPE.level and 4 or 0) + (d >= SHAPE.level and 8 or 0)
				if cut ~= 0 and cut ~= 15 then
					local pieces = SEGMENTS[cut] or SADDLE[cut][(a + b + c + d) / 4 >= SHAPE.level and 2 or 1]
					for piece = 1, #pieces, 2 do
						local key, x, y = Crossing(pieces[piece], i, j, cols, a, b, c, d)
						onward[key], px[key], py[key] = Crossing(pieces[piece + 1], i, j, cols, a, b, c, d), x, y
					end
				end
			end
		end
	end
	-- Followed round, each piece to the next.
	for start in pairs(onward) do
		if onward[start] then
			local loop, count, key = {}, 0, start
			repeat
				local after = onward[key]
				onward[key] = nil
				count = count + 1
				loop[count * 2 - 1], loop[count * 2] = px[key] * cell + ox, py[key] * cell + oy
				key = after
			until not onward[key]
			local area, edge = 0, 0
			for i = 1, count do
				local k = i % count + 1
				local ax, ay, bx, by = loop[i * 2 - 1], loop[i * 2], loop[k * 2 - 1], loop[k * 2]
				area = area + ax * by - bx * ay
				edge = edge + math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
			end
			-- With the ground on the left and y down, an outer line turns one way and a gap's the other.
			local hole = area > 0
			if count >= 3 and edge > 0 and (not hole or area / 2 > SHAPE.hole * radius * radius) then
				local kept = Thin(loop, count, SHAPE.slack * radius)
				if kept.n >= 3 then
					kept.hole, kept.depth = hole, math.abs(area) / 2 / edge
					loops[#loops + 1] = kept
				end
			end
		end
	end
	Band(loops)
	return loops
end

-- What is on a map

-- Collect the spawns of `lists` on `map`, as fractions of it, into set.groups[kind] (.n, .x, .y) and,
-- for a thing with only a few far apart, its exact places into set.spots. At most `room` spawns,
-- thinned evenly. With `away`, spawns on other maps (a zone seen from its continent) follow the map's
-- own. Returns the count taken.
local function Gather(set, lists, whats, map, room, away)
	local own, far = 0, 0
	for _, places in ipairs(lists) do
		for _, place in ipairs(places) do
			if not place.dungeon then
				if place.map == map then own = own + #place.points / 2 elseif away then far = far + #place.points / 2 end
			end
		end
	end
	local taken = 0
	local groups, spots = set.groups, set.spots
	local frame = Frame(map)
	for pass = 1, 2 do
		local count = pass == 1 and own or far
		local left = room - taken
		if count > 0 and left > 0 then
			local every, turn = math.max(1, math.ceil(count / left)), 0
			for index, places in ipairs(lists) do
				local what = whats[index] or FOUND
				local kind = HOW[what.how] or "find"
				local here = false
				local mine = { n = 0, x = {}, y = {}, north = {}, west = {} }   -- this list's spawns on the map
				for _, place in ipairs(places) do
					if not place.dungeon and (place.map == map) == (pass == 1) then
						local points = place.points
						local from = pass == 2 and Frame(place.map)
						-- (Another continent's spawns have yards of their own: carried onto this map they
						-- would land anywhere, the sea among it.)
						if from and frame and from.continent ~= frame.continent then from = nil end
						for i = 1, (pass == 1 or from) and #points or 0, 2 do
							turn = turn + 1
							if turn % every == 0 and taken < room then
								local x, y, north, west
								if pass == 1 then
									x, y = points[i] / UNITS, points[i + 1] / UNITS
									if frame then north, west = ToWorld(frame, points[i], points[i + 1]) end
								else
									local px, py = points[i], points[i + 1]
									north, west = ToWorld(from, px, py)
									local _, at = C_Map.GetMapPosFromWorldPos(from.continent, CreateVector2D(north, west), map)
									if at then
										x, y = at:GetXY()
										if x < 0.02 or x > 0.98 or y < 0.02 or y > 0.98 then x = nil end
									end
								end
								if x then
									taken = taken + 1
									mine.n = mine.n + 1
									mine.x[mine.n], mine.y[mine.n], mine.north[mine.n], mine.west[mine.n] = x, y, north, west
									here = true
								end
							end
						end
					end
				end
				if here then
					-- A few spawns nearly every one a place of its own at the yard radius: pointers.
					local places_ = 0
					if mine.n <= SHAPE.few and mine.north[1] then
						places_ = mine.n <= 2 and mine.n or #Ground.Loops(mine.north, mine.west, mine.n, SHAPE.radius)
					end
					local spread = what.pinned or mine.n <= 2 or (mine.n <= SHAPE.few and places_ >= mine.n - 1)
					-- A row of the key for this list's objective (or, where the list came without one, its
					-- quest and kind), naming what is there.
					local key = (what.quest or "") .. ":" .. (what.objective or kind)
					local row = set.rowsBy[key]
					if not row then
						-- (An objective of a quest of several wears its letter and its shade: Marks.lua.)
						local one = what.quest and what.objective and ns.Objective(what.quest, what.objective)
						row = { kind = kind, how = what.how, names = {}, places = 0, lists = 0, spread = 0, quest = what.quest,
							objective = what.objective, letter = one, shade = one and one.shade }
						set.rowsBy[key] = row
						set.rows[#set.rows + 1] = row
					end
					-- A pointer only where the exact place is the answer: an object, what a search found, an
					-- objective found only at such (what.pinned: Route.lua). A rare among a camp is its ground, as
					-- the camp is: the stop's one mark says where to go.
					local point = Still(what) or not ENEMY[what.how] or spread
					if point then
						-- (Each pointer knows its row: what it says under the mouse.)
						for i = 1, mine.n do
							local n = spots.n + 1
							spots.n = n
							spots.x[n], spots.y[n], spots.kind[n], spots.north[n], spots.west[n] = mine.x[i], mine.y[i], kind, mine.north[i], mine.west[i]
							spots.row[n], spots.what[n] = row, what
						end
					else
						-- A camp's or a crowd's spawns, each a dot while the player stands on its ground (PlaceMini).
						local dots = set.dots
						for i = 1, dots and mine.n or 0 do
							if mine.north[i] then
								local n = dots.n + 1
								dots.n = n
								dots.north[n], dots.west[n], dots.kind[n] = mine.north[i], mine.west[i], kind
								dots.x[n], dots.y[n], dots.shade[n], dots.what[n] = mine.x[i], mine.y[i], row.shade or false, what
							end
						end
					end
					-- Its spawns join their kind's ground. Not what has pointers: that is its pointers alone.
					if not point then
						local group = groups[kind]
						if not group then
							group = { n = 0, x = {}, y = {}, pointed = 0 }
							groups[kind] = group
						end
						for i = 1, mine.n do
							group.n = group.n + 1
							group.x[group.n], group.y[group.n] = mine.x[i], mine.y[i]
						end
					end
					if what.name and what.name ~= "" and not row.names[what.name] then
						row.names[what.name] = true
						row.names[#row.names + 1] = what.name
					end
					row.lists = row.lists + 1
					if spread then
						row.spread = row.spread + 1
						row.places = row.places + math.max(places_, 1)
					end
				end
			end
		end
	end
	return taken
end

-- Whether the game itself has an area for a quest (the server sends polygons for many quests, Forever's
-- own among them).
local function HasBlob(id)
	local counted = rawget(_G, "GetQuestPOIBlobCount")
	if not counted or not id then return false end
	local ok, count = pcall(counted, id)
	return ok and type(count) == "number" and count > 0
end

-- The game's area for a quest on a map, as the points of a grid that lie in it (fractions of the map;
-- .n of them), sampled once out of a QuestPOIFrame of ours; false when the frame gives nothing.
-- Asking is a job (thousands of questions of the game): the area is known a few frames after it is
-- first wanted. A miss is asked again after MISS.wait seconds, then after twice as long each time, up
-- to MISS.most: the server may send an area late, and one for another map never comes. On a cold login
-- it comes late: the log has the quest at once, the area's shape follows with QUEST_POI_UPDATE (a
-- /reload finds it already there). So that event forgets every miss, and the maps asking again at the
-- rebuild it brings find it; and the first MISS.timed misses are asked again when their wait is out,
-- by a timer of their own, for an area the game could not draw yet when the event was heard.
-- An area found is asked again too: on a cold login the server sends a quest's areas a piece at a time,
-- and what was found after the first piece is only part of it. The event makes every area found due
-- again (kept and drawn meanwhile), and an answer the same as before is asked again MISS.timed times
-- more, after MISS.wait seconds and then twice as long each time, for pieces the game draws late.
local sampled = {}           -- by map, by quest: the points (.due, .again: being asked again, .checks), { miss, wait, misses },
                             -- or { asking = true, ... } meanwhile
local sampler
local MISS = {
	wait = 2,
	most = 60,
	timed = 3,
}
local heard = 0              -- QUEST_POI_UPDATEs heard: an answer asked for before the latest is no miss
local function Sampler()
	if sampler == nil then
		-- A frame of its own in the shape of a zone's map, on the screen (off it, the game's hit test
		-- knows only the sliver that is on), under everything and invisible: it is asked, never seen.
		local ok, frame = pcall(CreateFrame, "QuestPOIFrame", nil, UIParent)
		sampler = ok and frame or false
		if sampler then
			sampler:SetSize(1002, 668)
			sampler:SetPoint("CENTER")
			sampler:SetFrameStrata("BACKGROUND")
			sampler:SetFrameLevel(0)
			sampler:SetAlpha(0)
			pcall(sampler.SetFillTexture, sampler, BLIZZARD_FILL)
			pcall(sampler.SetBorderTexture, sampler, BLIZZARD_BORDER_WHITE)
			pcall(sampler.SetFillAlpha, sampler, 0)
			pcall(sampler.SetBorderAlpha, sampler, 0)
		end
	end
	return sampler
end

-- The job: the quest's area is drawn in the frame, and from the next frame on (the game builds it
-- then) the grid's points are asked a row at a time. Returns the points inside.
local function Ask(id, map)
	local frame = sampler
	local points = { n = 0, x = {}, y = {} }
	local ok = pcall(function()
		frame:SetMapID(map)
		frame:DrawNone()
		frame:DrawBlob(id, true)
	end)
	if not ok then return points end
	coroutine.yield("frame")
	local rows = math.floor(BLOB.sample * 2 / 3 + 0.5)
	local step, drop = 1 / BLOB.sample, 1 / rows
	local test = frame.UpdateMouseOverTooltip
	for j = 0, rows - 1 do
		local y = (j + 0.5) * drop
		for i = 0, BLOB.sample - 1 do
			local x = (i + 0.5) * step
			local inside, hit = pcall(test, frame, x, y)
			if inside and hit then
				points.n = points.n + 1
				points.x[points.n], points.y[points.n] = x, y
			end
		end
		Breathe()
	end
	pcall(frame.DrawNone, frame)
	return points
end

-- Whether two answers are the same points.
local function Same(a, b)
	if a.n ~= b.n then return false end
	for i = 1, a.n do
		if a.x[i] ~= b.x[i] or a.y[i] ~= b.y[i] then return false end
	end
	return true
end

-- An area found and asked again that came out as before (or as nothing, which leaves it as it was):
-- asked once more after a while, MISS.timed times at most since the game last said it had new areas.
local function Settled(onMap, id, found, since)
	found.again = nil
	found.due = heard ~= since or nil
	if found.due or (found.checks or 0) >= MISS.timed then return end
	found.checks = (found.checks or 0) + 1
	C_Timer.After(MISS.wait * 2 ^ (found.checks - 1) + 0.05, function()
		if onMap[id] == found and not found.again then
			found.due = true
			if ns.ApplyPins then ns.ApplyPins() end
		end
	end)
end

-- Second result: true while the game is being asked for the first time (nothing is known yet).
function Ground.Sampled(id, map)
	local onMap = sampled[map]
	if not onMap then
		onMap = {}
		sampled[map] = onMap
	end
	local found = onMap[id]
	if found then
		-- (Found, and being asked again or not due to be: drawn as it is.)
		if found.n and (found.again or not found.due) then return found end
		if found.asking then return false, found.miss == nil end
		if not found.n and not found.due and GetTime() - found.miss < found.wait then return false end
	end
	local hit = found and found.n and found or false
	local frame = Sampler()
	-- No frame to ask: nothing is kept, so it is asked again when there is one.
	if not frame or type(frame.UpdateMouseOverTooltip) ~= "function" then return hit end
	-- Not asked yet, or a miss due to be asked again (which stays a miss meanwhile), or an area found
	-- that is due to be asked again (which is drawn meanwhile).
	local was = found
	local since = heard
	if hit then
		hit.again = true
	else
		onMap[id] = { asking = true, miss = was and was.miss, wait = was and was.wait, misses = was and was.misses }
	end
	Later("area asked of the game", function()
		local points = Ask(id, map)
		if hit and (points.n == 0 or Same(hit, points)) then
			Settled(onMap, id, hit, since)
		elseif points.n > 0 then
			points.checks = hit and hit.checks or nil
			onMap[id] = points
			-- (More of it came while this was asked: asked again.)
			points.due = heard ~= since or nil
			-- The route stands its stop on this ground (Ground.Known): it is worked out again.
			ns.Refresh()
		else
			local miss = { miss = GetTime(), wait = was and math.min(MISS.most, was.wait * 2) or MISS.wait,
				misses = (was and was.misses or 0) + 1 }
			-- The game said it had new areas while this was asked: what it said wasn't in the answer.
			miss.due = heard ~= since
			onMap[id] = miss
			-- (The maps are drawn again as the job ends, which asks again at once if it is due.)
			if not miss.due and miss.misses <= MISS.timed then
				C_Timer.After(miss.wait + 0.05, function()
					if onMap[id] == miss and ns.ApplyPins then ns.ApplyPins() end
				end)
			end
		end
	end, function()
		if hit then
			hit.again, hit.due = nil, nil
		else
			onMap[id] = { miss = GetTime(), wait = MISS.most, misses = (was and was.misses or 0) + 1 }
		end
	end)
	return hit, was == nil
end

-- The game has new quest areas (QUEST_POI_UPDATE): every miss is due to be asked again, and every area
-- found (more of it may have come). ShyQuest rebuilds the route on the same event, and the maps it
-- draws again ask.
function Ground.AreasSent()
	heard = heard + 1
	for _, onMap in pairs(sampled) do
		for _, found in pairs(onMap) do
			if found.n and not found.again then
				found.due, found.checks = true, 0
			elseif found.miss and not found.asking then
				found.due = true
			end
		end
	end
end
do
	local listen = CreateFrame("Frame")
	listen:RegisterEvent("QUEST_POI_UPDATE")
	listen:SetScript("OnEvent", function() Ground.AreasSent() end)
end

-- What of the game's area for a quest is still worked: its pieces (samples touching, side or corner)
-- that hold a spawn of an objective not yet done. The game's area is the whole quest's, so a camp of
-- objectives finished would stay lit and keep the player "on the work" there. Where the data knows
-- no spawn in any piece (Forever's own quests), all of it. Kept on the answer by the log's progress.
local function Live(id, map, found)
	local progress = {}
	for i, goal in ipairs(L.Has(id) and L.Goals(id) or {}) do progress[i] = goal.finished and "1" or "0" end
	local key = table.concat(progress)
	found.live = found.live or {}
	local kept = found.live[key]
	if kept then return kept end
	kept = found
	local rows = math.floor(BLOB.sample * 2 / 3 + 0.5)
	local cell = {}
	for k = 1, found.n do cell[math.floor(found.y[k] * rows) * BLOB.sample + math.floor(found.x[k] * BLOB.sample)] = k end
	local piece, pieces = {}, 0
	for k = 1, found.n do
		if not piece[k] then
			pieces = pieces + 1
			piece[k] = pieces
			local stack = { k }
			while #stack > 0 do
				local at = table.remove(stack)
				local i, j = math.floor(found.x[at] * BLOB.sample), math.floor(found.y[at] * rows)
				for dj = -1, 1 do
					for di = -1, 1 do
						local other = i + di >= 0 and i + di < BLOB.sample and cell[(j + dj) * BLOB.sample + i + di]
						if other and not piece[other] then
							piece[other] = pieces
							stack[#stack + 1] = other
						end
					end
				end
			end
		end
	end
	if pieces > 1 then
		local lit, any = {}, false
		local lists, _, whats = R.Ground(id)
		for index, places in ipairs(lists) do
			local what = whats[index]
			if not (what and (what.how == "sells" or what.pinned)) then
				for _, place in ipairs(places) do
					local points = not place.dungeon and place.map == map and place.points or {}
					for p = 1, #points, 2 do
						local i, j = math.floor(points[p] / UNITS * BLOB.sample), math.floor(points[p + 1] / UNITS * rows)
						for dj = -BLOB.near, BLOB.near do
							for di = -BLOB.near, BLOB.near do
								local k = i + di >= 0 and i + di < BLOB.sample and cell[(j + dj) * BLOB.sample + i + di]
								if k then lit[piece[k]], any = true, true end
							end
						end
					end
				end
			end
		end
		local all = true
		for p = 1, pieces do
			if not lit[p] then all = false end
		end
		if any and not all then
			kept = { n = 0, x = {}, y = {} }
			for k = 1, found.n do
				if lit[piece[k]] then
					kept.n = kept.n + 1
					kept.x[kept.n], kept.y[kept.n] = found.x[k], found.y[k]
				end
			end
		end
	end
	found.live[key] = kept
	return kept
end

-- The game's area for a quest on a map as a thing's spawns are kept ({ { map, points } }; .radius: how
-- far one of its points reaches, in yards), where it has been asked for and found: the pieces still
-- worked (Live). It never asks: the route reads this on every rebuild (Route.lua, "Areas"). A very
-- large area is every few points of it.
local KNOWN_MOST = 2000
function Ground.Known(id, map)
	local found = sampled[map] and sampled[map][id]
	if not (found and found.n and found.n > 0) then return nil end
	found = Live(id, map, found)
	if not found.places then
		local frame = Frame(map)
		if not frame then return nil end
		local rows = math.floor(BLOB.sample * 2 / 3 + 0.5)
		local every = math.ceil(math.sqrt(found.n / KNOWN_MOST))
		local points = {}
		for i = 1, found.n do
			if math.floor(found.x[i] * BLOB.sample) % every == 0 and math.floor(found.y[i] * rows) % every == 0 then
				points[#points + 1] = math.floor(found.x[i] * UNITS + 0.5)
				points[#points + 1] = math.floor(found.y[i] * UNITS + 0.5)
			end
		end
		found.places = { { map = map, points = points }, radius = frame.yards / BLOB.sample * BLOB.reach * every }
	end
	return found.places
end

-- Everything Ground.Map needs of one request: the groups, the pointers (.spots), the key's rows, the
-- quests the game draws itself (.blobs, with their kinds, or false for one drawn as sampled ground;
-- the samples in .areas by kind) and what tells one set's ground from another's (.sig).
-- A set is made from what Ground.Of gives for the stop and from what the game says of the quests' own
-- areas: it is kept by a print of those (made), so the maps lay a ground that hasn't changed without
-- gathering and tracing it again, however often the route is built. The game is asked of each area just as
-- the set's making would ask it (Ground.Sampled), so an area due again is asked again all the same.
-- Ground.Forget lets go of the sets not asked for since the one before.
local made = { sets = {}, used = {}, n = 0, MOST = 48 }
function made.Blobs(lists, whats, map)
	local states = {}
	for i, places in ipairs(lists) do
		local what = whats[i] or FOUND
		local id = what.quest
		local spawned = false
		for _, place in ipairs(places) do
			if not place.dungeon and place.points and #place.points >= 2 then spawned = true end
		end
		local has = id and ENEMY[what.how] and not what.pinned and not what.needs and not spawned and HasBlob(id)
		local state = { has = has or false }
		if has then state.found, state.asking = Ground.Sampled(id, map) end
		states[i] = state
	end
	return states
end
function made.Print(lists, names, whats, states, map, live, own)
	local out = { map, live and "live" or "all", own and "own" or "", frames.n or 0, #lists }
	for i, places in ipairs(lists) do
		out[#out + 1] = tostring(places)
		for k, v in pairs(whats[i] or FOUND) do out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
		local state = states[i]
		if state.has then
			out[#out + 1] = tostring(state.found) .. tostring(state.asking)
			local id = (whats[i] or FOUND).quest
			for _, goal in ipairs(L.Has(id) and L.Goals(id) or {}) do out[#out + 1] = (goal.finished and "!" or "") .. tostring(goal.text) end
			out[#out + 1] = L.entries[id] and L.entries[id].title or ""
		end
	end
	for _, name in ipairs(names) do out[#out + 1] = name end
	return table.concat(out, "|")
end


local function Prepare(stop, live, map, own)
	if not stop then return made.Make(nil, live, map, own) end
	local lists, names, whats = Ground.Of(stop, live)
	local states = made.Blobs(lists, whats, map)
	local print_ = made.Print(lists, names, whats, states, map, live, own)
	local set = made.sets[print_]
	if not set then
		set = made.Make(stop, live, map, own, lists, names, whats, states)
		if made.n >= made.MOST then
			wipe(made.sets)
			wipe(made.used)
			made.n = 0
		end
		made.sets[print_] = set
		made.n = made.n + 1
	end
	made.used[print_] = true
	return set
end

function made.Make(stop, live, map, own, lists, names, whats, states)
	local set = { own = 0, hidden = 0, names = {}, groups = {}, areas = {}, rows = {}, rowsBy = {}, blobs = {},
		spots = { n = 0, x = {}, y = {}, kind = {}, north = {}, west = {}, row = {}, what = {} },
		dots = { n = 0, x = {}, y = {}, north = {}, west = {}, kind = {}, shade = {}, what = {} } }
	if stop then
		set.names = names
		-- Spawns kept on other maps are carried onto this one (a zone seen on its continent), on the world map
		-- always: ShyMaps' view hands over between a zone and its continent as it is panned, and the ground
		-- lit there went with the zone. The minimap, on the player's own zone, keeps a live stop's to it.
		local away = not live or not own
		-- A quest the game has an area for is drawn by that area, sampled out of the game's frame: its
		-- spawn ground is left out, its pointers and its row of the key kept. (With `own`, the minimap's,
		-- the spawn ground stands in where the area can't be sampled.) While the game is still being asked,
		-- the quest has no ground yet: the maps are drawn again when the answer is in.
		-- An objective found only at exact places (what.pinned) has those and no area: an area round three
		-- valves says they are in it, and not where.
		-- Nor while the quest waits for an item it can't be done without (what.needs): the game's area is
		-- where the objective is done, and the route stands the player on where the item is had. Nor for
		-- a thing the data has spawns of: those are the ground, and the game's area is a rough shape round
		-- them, often far wider than where anything stands (Route.lua's Spawned).
		local kept, keptWhats = {}, {}
		local inArea = {}            -- a quest's area is taken once for each kind of thing it asks for
		for i, places in ipairs(lists) do
			local what = whats[i] or FOUND
			local id = what.quest
			local has, found, asking = states[i].has, states[i].found, states[i].asking
			if has and (found or asking or not own) then
				local kind = HOW[what.how] or ns.QuestKind(id) or "go"
				if not asking and set.blobs[id] == nil then
					set.blobs[#set.blobs + 1] = id
					set.blobs[id] = not found and kind   -- false: drawn as ground, not by the frame
				end
				if found and not inArea[id .. kind] then
					inArea[id .. kind] = true
					found = Live(id, map, found)
					local area = set.areas[kind]
					if not area then
						area = { n = 0, x = {}, y = {} }
						set.areas[kind] = area
					end
					for k = 1, found.n do
						area.n = area.n + 1
						area.x[area.n], area.y[area.n] = found.x[k], found.y[k]
					end
				end
				-- Its spawns still gather for the key, the pointers and the dots, into groups that are thrown away.
				local shadow = { groups = {}, spots = set.spots, dots = set.dots, rows = set.rows, rowsBy = set.rowsBy }
				local before = set.spots.n
				local took = Gather(shadow, { places }, { what }, map, SHAPE.most, away)
				set.own = set.own + took
				set.hidden = set.hidden + took - (set.spots.n - before)
			else
				kept[#kept + 1] = places
				keptWhats[#kept] = what
			end
		end
		set.own = set.own + Gather(set, kept, keptWhats, map, SHAPE.most - set.own, away)
	end
	local sig = {}
	for _, kind in ipairs(ORDER) do
		for which, groups in ipairs({ set.groups, set.areas }) do
			local group = groups[kind]
			if group then
				local sx, sy = 0, 0
				for i = 1, group.n do sx, sy = sx + group.x[i], sy + group.y[i] end
				-- Each group's own, too: its outline is kept by it (Traced).
				group.sig = ("%s%s%d:%.5f:%.5f"):format(which == 2 and "area " or "", kind, group.n, sx, sy)
				sig[#sig + 1] = group.sig
			end
		end
	end
	-- A quest with an area and nothing in the spawn data (Forever's own) still gets its row.
	for _, id in ipairs(set.blobs) do
		local kind = set.blobs[id] or (set.areas and ns.QuestKind(id)) or "go"
		if not set.rowsBy[id .. ":area"] then
			local named = false
			for _, row in ipairs(set.rows) do
				if row.quest == id then named = true end
			end
			if not named then
				local names = {}
				for _, goal in ipairs(L.Has(id) and L.Goals(id) or {}) do
					local text = goal.text and goal.text:match("^(.-):%s*%d") or goal.text
					if text and text ~= "" and not goal.finished then names[#names + 1] = text end
				end
				if #names == 0 then names[1] = L.entries[id] and L.entries[id].title or D.Name("quests", id) or "" end
				local row = { kind = kind, how = kind, names = names, places = 0, lists = 1, spread = 0, quest = id }
				set.rowsBy[id .. ":area"] = row
				set.rows[#set.rows + 1] = row
			end
		end
	end
	set.sig = table.concat(sig, "|")
	for _, row in ipairs(set.rows) do
		local names = row.names
		local text = table.concat(names, ", ", 1, math.min(DRAW.names, #names))
		if #names > DRAW.names then text = ("%s +%d"):format(text, #names - DRAW.names) end
		row.text, row.word = text, WORD[row.how] or KIND[row.kind].word
	end
	return set
end

-- The outlines of a set's ground on a map `width` by `height`, by kind, kept by what they are of: the
-- route is rebuilt far more often than the ground changes. An area's outline is the same at every
-- zoom, so it is kept apart from the spawns', which grow with `radius`.
--   wait: a large ground may be traced as a job (Traced). What comes back then has only what is traced
--   so far, and isn't kept: the maps are drawn again when the rest is done.
local shaped, shapes = {}, 0
local function Shapes(set, width, height, radius, wait)
	local key = ("%s|%s|%s|%s"):format(set.sig, width, height, radius)
	local made = shaped[key]
	if not made then
		made = { fills = {} }
		local whole = true
		local xs, ys = {}, {}
		local function Add(kind, loops)
			if not loops then
				whole = false
				return
			end
			local into = made[kind] or {}
			for _, loop in ipairs(loops) do into[#into + 1] = loop end
			made[kind] = into
			local fills = made.fills[kind] or {}
			fills[#fills + 1] = loops
			made.fills[kind] = fills
		end
		for kind, group in pairs(set.groups) do
			for i = 1, group.n do xs[i], ys[i] = group.x[i] * width, group.y[i] * height end
			Add(kind, Traced(("%s|%s|%s|%s"):format(group.sig or kind, width, height, radius), xs, ys, group.n, radius, wait))
		end
		for kind, area in pairs(set.areas) do
			for i = 1, area.n do xs[i], ys[i] = area.x[i] * width, area.y[i] * height end
			Add(kind, Traced(("%s|%s|%s"):format(area.sig or kind, width, height), xs, ys, area.n, width / BLOB.sample * BLOB.reach, wait))
		end
		if not whole then return made, false end
		if shapes >= 24 then
			wipe(shaped)
			shapes = 0
		end
		shaped[key] = made
		shapes = shapes + 1
	end
	return made, true
end

-- Pointers

-- A frame holding one map's ground: a record per pointer in the frame itself (.used of them in use, .on
-- while shown; .point its picture), the count of the lit spawns that have no pointer (.quiet: a camp
-- or a crowd is its ground alone), and its lines (SetupMap, SetupMini).
local function Sheet(parent, frameLevel)
	local sheet = CreateFrame("Frame", nil, parent)
	sheet:SetAllPoints()
	sheet:SetFrameLevel(frameLevel)
	sheet.used, sheet.kind, sheet.quiet = 0, 1, 0
	return sheet
end

-- The sheet's next pointer: .point its picture, .on while it is part of the ground shown.
local function Light(sheet)
	sheet.used = sheet.used + 1
	local light = sheet[sheet.used]
	if not light then
		light = { point = sheet:CreateTexture(nil, "ARTWORK") }
		light.point:SetSnapToPixelGrid(false)
		light.point:SetTexelSnappingBias(0)
		sheet[sheet.used] = light
	end
	light.on = true
	return light
end

-- Put out a sheet's pointers beyond `used`.
local function Douse(sheet)
	for i = sheet.used + 1, #sheet do
		local light = sheet[i]
		if light.on ~= false then
			light.point:Hide()
			light.on, light.shown = false, nil
		end
	end
end

-- A pointer's picture by kind: the pin (Media\Spots), its point on the place and its head PIN_LIFT over it;
-- something to gather or use, the gather mark's own cog (Marks.lua's emblem), its middle on the place.
local PIN = { art = ART, coords = { 0, 1, 0, 1 }, lift = true }
local POINTER = { gather = { art = ns.MARKS_SMALL, coords = ns.MarkPicture("gather"), lift = false },
	buy = { art = ns.MARKS_SMALL, coords = ns.MarkPicture("buy"), lift = false } }
function Ground.Pointer(kind)
	return POINTER[kind] or PIN
end

-- Show a place's pointer in its kind's color (an objective of a quest of several: its shade), on the
-- place. The dark rim (the pin's) or the shadow (the cog's) is in the picture.
local function Spot(light, parent, anchor, x, y, kind, size, alpha, shade)
	local point = light.point
	local look = Ground.Pointer(kind)
	if light.look ~= look then
		light.look = look
		point:SetTexture(look.art)
		point:SetTexCoord(unpack(look.coords))
	end
	-- (Laid every frame the player moves on the minimap: only what changed is set.)
	local color = shade or KIND[kind].color
	if light.color ~= color or light.alpha ~= alpha then
		light.color, light.alpha = color, alpha
		point:SetVertexColor(color[1], color[2], color[3], alpha)
	end
	if light.size ~= size then
		light.size = size
		point:SetSize(size, size)
	end
	if light.x ~= x or light.y ~= y or light.parent ~= parent or light.anchor ~= anchor then
		light.x, light.y, light.parent, light.anchor = x, y, parent, anchor
		point:SetPoint("CENTER", parent, anchor, x, y)
	end
	if not light.shown then
		light.shown = true
		point:Show()
	end
end

-- The next of a sheet's dots (`dots`: { used, sheet }) at x, y from the minimap's middle. Its ground's
-- fill is its own hue, so hue can't tell it from the fill: value does, as on the ground's edge (a lit
-- hairline on a deep case). A light tint of the kind's color in a case of its deep shade, a little larger.
-- shade: the color of the objective it is for, in a quest of several (Marks.lua), in place of the kind's.
local function Dot(dots, x, y, kind, alpha, parent, anchor, size, shade)
	size = size or DRAW.miniDot
	dots.used = dots.used + 1
	local dot = dots[dots.used]
	if not dot then
		dot = { rim = dots.sheet:CreateTexture(nil, "ARTWORK", nil, -2), face = dots.sheet:CreateTexture(nil, "ARTWORK", nil, -1) }
		dot.rim:SetTexture(DOT_ART)
		dot.face:SetTexture(DOT_ART)
		dots[dots.used] = dot
	end
	shade = shade or nil
	if dot.kind ~= kind or dot.shade ~= shade then
		dot.kind, dot.shade = kind, shade
		local cell = SPAWN_CELL[kind] or SPAWN_CELL.go
		dot.rim:SetTexCoord(cell / 8, (cell + 1) / 8, 0, 0.5)
		dot.face:SetTexCoord(cell / 8, (cell + 1) / 8, 0.5, 1)
		local r, g, b = unpack(shade or KIND[kind].color)
		dot.face:SetVertexColor(r + (1 - r) * DRAW.dotLight, g + (1 - g) * DRAW.dotLight, b + (1 - b) * DRAW.dotLight)
		dot.rim:SetVertexColor(r * DRAW.dotDeep, g * DRAW.dotDeep, b * DRAW.dotDeep)
	end
	-- (Laid every frame the player moves on the minimap: only what changed is set.)
	if dot.alpha ~= alpha then
		dot.alpha = alpha
		dot.face:SetAlpha(alpha)
		dot.rim:SetAlpha(alpha)
	end
	if dot.size ~= size then
		dot.size = size
		dot.rim:SetSize(size, size)
		dot.face:SetSize(size, size)
	end
	parent, anchor = parent or Minimap, anchor or "CENTER"
	if dot.x ~= x or dot.y ~= y or dot.parent ~= parent or dot.anchor ~= anchor then
		dot.x, dot.y, dot.parent, dot.anchor = x, y, parent, anchor
		dot.rim:SetPoint("CENTER", parent, anchor, x, y)
		dot.face:SetPoint("CENTER", parent, anchor, x, y)
	end
	if not dot.on then
		dot.rim:Show()
		dot.face:Show()
		dot.on = true
	end
end

-- Put out the dots beyond `used`.
local function DouseDots(dots)
	for i = dots.used + 1, #dots do
		local dot = dots[i]
		if dot.on then
			dot.rim:Hide()
			dot.face:Hide()
			dot.on = false
		end
	end
end

-- A pointer is a small thing to hit: a point is on one within PIN_REACH of the middle of its pin, which
-- stands PIN_LIFT over its place (shares of the picture's size); a cog's middle is on its place.
local PIN_LIFT, PIN_REACH = 0.23, 0.45
local function Lift(kind)
	return Ground.Pointer(kind).lift and PIN_LIFT or 0
end

-- The pointers or dots a map shows now, for what is under the mouse: .n of them at .x, .y (their places,
-- in the units the mouse is asked in), each of .kind for the key's .row, with its list's .what, its .shade
-- and its place in the world (.north, .west); their picture .size across.
local function Shown()
	return { n = 0, x = {}, y = {}, kind = {}, row = {}, what = {}, shade = {}, north = {}, west = {}, size = 0 }
end

-- Add the picture of `from`'s spawn i, drawn at x, y, to `shown`.
local function Put(shown, x, y, from, i)
	local n = shown.n + 1
	shown.n = n
	local row = from.row and from.row[i] or false
	shown.x[n], shown.y[n], shown.kind[n], shown.row[n] = x, y, from.kind[i], row
	shown.what[n] = from.what and from.what[i] or false
	shown.shade[n] = (from.shade and from.shade[i]) or (row and row.shade) or false
	shown.north[n], shown.west[n] = from.north[i], from.west[i]
end

-- The key's rows of the pointers of `kind` a point is on, the nearest first; nil when it is on none.
--   up: which way is up in y (1 or -1).
local function Pointed(shown, kind, x, y, up)
	local reach, lift = (shown.size * PIN_REACH) ^ 2, shown.size * Lift(kind) * up
	local rows, nearest
	for i = 1, shown.n do
		local row = shown.row[i]
		if row and shown.kind[i] == kind then
			local far = (x - shown.x[i]) ^ 2 + (y - shown.y[i] - lift) ^ 2
			if far <= reach then
				rows = rows or {}
				local known = false
				for k = 1, #rows do known = known or rows[k] == row end
				if not known then table.insert(rows, (nearest and far < nearest) and 1 or #rows + 1, row) end
				nearest = math.min(nearest or far, far)
			end
		end
	end
	return rows
end

-- A point is on a dot within DOT_REACH of the middle of its picture's cell: on the picture itself, so
-- the ground between the dots of a camp still has its own hover.
local DOT_REACH = 0.35
-- How a list serves a quest (GoalPlaces' how) to what its id is of: an NPC or an object.
local THING = { kill = "n", drops = "n", gives = "n", sells = "n", use = "o", holds = "o" }

-- The spawn a point is on, of the pointers (`spots`, whose pins stand PIN_LIFT over their places; `up`
-- the way up in y) and the dots a map shows: the nearest whose picture it is on, as { thing, of (its
-- kind: "n" or "o"), kind, shade, north, west, continent, whats }, whats being every list drawn of that
-- thing (one for each objective it is for), in the quest's order. nil when it is on none, or on a place
-- that is no one thing's (a place to go to).
local function SpawnIn(spots, dots, x, y, up, continent)
	local best, from, far
	for _, shown in ipairs({ spots, dots }) do
		local pin = shown == spots
		local reach = (shown.size * (pin and PIN_REACH or DOT_REACH)) ^ 2
		for i = 1, shown.n do
			local what = shown.what[i]
			if what and what.id and THING[what.how] then
				local lift = pin and shown.size * Lift(shown.kind[i]) * up or 0
				local d = (x - shown.x[i]) ^ 2 + (y - shown.y[i] - lift) ^ 2
				if d <= reach and (not far or d < far) then best, from, far = i, shown, d end
			end
		end
	end
	if not best then return nil end
	local what = from.what[best]
	local of = THING[what.how]
	local thing = D.Thing(of, what.id)
	if not thing then return nil end
	local spawn = { thing = thing, of = of, kind = from.kind[best], shade = from.shade[best] or nil, north = from.north[best],
		west = from.west[best], continent = continent, whats = {} }
	local seen = {}
	for _, shown in ipairs({ spots, dots }) do
		for i = 1, shown.n do
			local each = shown.what[i]
			if each and not seen[each] and each.id == what.id and THING[each.how] == of then
				seen[each] = true
				spawn.whats[#spawn.whats + 1] = each
			end
		end
	end
	table.sort(spawn.whats, function(a, b)
		if (a.quest or 0) ~= (b.quest or 0) then return (a.quest or 0) < (b.quest or 0) end
		return (a.objective or 0) < (b.objective or 0)
	end)
	return spawn
end

-- Lines

-- Lines of one sort on a frame, created on demand, each with the strip `art` across it. The first
-- .used are in use, the first .shown showing.
-- clip: the minimap. A Line is not cut by the frame that clips its parent, so a long edge runs on
-- across the game. Those strokes are textures, which the frame does clip.
local function Lines(owner, layer, sub, art, clip)
	return { used = 0, shown = 0, owner = owner, layer = layer, sub = sub, art = art, clip = clip }
end

-- The next line of a pool, from a to b (the owner's top left, y down when `down`), `thick` across, in
-- `color` (a table that stays the same one) at `alpha`. A strip's outward side follows the way the line
-- runs. A line is told its width and color, and to show, only when they change: the
-- minimap's lines are laid again every frame the player moves.
local function Stroke(pool, anchor, point, down, ax, ay, bx, by, thick, color, alpha)
	local used = pool.used + 1
	pool.used = used
	local line = pool[used]
	if not line then
		line = pool.clip and pool.owner:CreateTexture(nil, pool.layer, nil, pool.sub) or pool.owner:CreateLine(nil, pool.layer, nil, pool.sub)
		-- (Off the pixel grid: on the sliding plate a snapped one steps a pixel at a time.)
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		line:SetTexture(pool.art)
		if pool.art == DASH then line:SetTexCoord(STRIPE[1], STRIPE[2], 0, 1) end
		-- A plain line is laid over the map, never in place of it.
		if pool.art == SOLID then line:SetBlendMode("BLEND") end
		pool[used] = line
	end
	local sign = down and -1 or 1
	ay, by = ay * sign, by * sign
	-- Laid again for the same place: the picture is already there. A turn or a new drawing is what moves it.
	if line.ax ~= ax or line.ay ~= ay or line.bx ~= bx or line.by ~= by or line.anchor ~= anchor or line.wide ~= thick then
		line.ax, line.ay, line.bx, line.by, line.anchor, line.wide = ax, ay, bx, by, anchor, thick
		if pool.clip then
			-- A strip: the picture's top along the left of the way, its rect the whole of it, so the
			-- clipping frame cuts it and no corner falls outside its own rect.
			local dx, dy = bx - ax, by - ay
			local length = math.sqrt(dx * dx + dy * dy)
			local nx, ny = 0, 1
			if length > 0 then nx, ny = -dy / length, dx / length end
			local h = thick / 2
			local lx, ly, rx, ry = ax + nx * h, ay + ny * h, ax - nx * h, ay - ny * h
			local ex, ey, fx, fy = bx + nx * h, by + ny * h, bx - nx * h, by - ny * h
			local left, right = math.min(lx, rx, ex, fx), math.max(lx, rx, ex, fx)
			local bottom, top = math.min(ly, ry, ey, fy), math.max(ly, ry, ey, fy)
			if right - left < 1 then left, right = (left + right) / 2 - 0.5, (left + right) / 2 + 0.5 end
			if top - bottom < 1 then bottom, top = (bottom + top) / 2 - 0.5, (bottom + top) / 2 + 0.5 end
			line:SetSize(right - left, top - bottom)
			line:SetPoint("CENTER", anchor, point, (left + right) / 2, (bottom + top) / 2)
			-- (A strip square to the screen, as every row is on a minimap that doesn't turn, has its corners
			-- on its rect's: no offsets, and none told again to a picture that already has none.)
			local ulx, uly, llx, lly = lx - left, ly - top, rx - left, ry - bottom
			local urx, ury, lrx, lry = ex - right, ey - top, fx - right, fy - bottom
			local square = math.abs(ulx) + math.abs(uly) + math.abs(llx) + math.abs(lly) + math.abs(urx) + math.abs(ury)
				+ math.abs(lrx) + math.abs(lry) < 0.01
			if not (square and line.square) then
				line:SetVertexOffset(UPPER_LEFT_VERTEX, ulx, uly)
				line:SetVertexOffset(LOWER_LEFT_VERTEX, llx, lly)
				line:SetVertexOffset(UPPER_RIGHT_VERTEX, urx, ury)
				line:SetVertexOffset(LOWER_RIGHT_VERTEX, lrx, lry)
			end
			line.square = square
		else
			line:SetStartPoint(point, anchor, ax, ay)
			line:SetEndPoint(point, anchor, bx, by)
		end
	end
	if not pool.clip and line.thick ~= thick then
		line.thick = thick
		line:SetThickness(thick)
	end
	if line.tint ~= color or line.tintAlpha ~= alpha then
		line.tint, line.tintAlpha = color, alpha
		line:SetVertexColor(color[1], color[2], color[3], alpha)
		line.gleamed = nil   -- (its alpha is another: Gleam gives it its own again)
	end
	if used > pool.shown then
		pool.shown = used
		line:Show()
	end
	return line
end

local function HideRest(pool)
	for i = pool.used + 1, pool.shown do pool[i]:Hide() end
	pool.shown = pool.used
end

local function Begin(...)
	for i = 1, select("#", ...) do
		local pool = select(i, ...)
		if pool then pool.used = 0 end
	end
end

local function Finish(...)
	for i = 1, select("#", ...) do
		local pool = select(i, ...)
		if pool then HideRest(pool) end
	end
end

-- A region's outline from the sheet's pools: the glow (its strip empty outward) and the edge, both
-- centred on each piece, and the gleam's lines when `gleam`.
local WHITE = { 1, 1, 1 }
local function Region(sheet, anchor, point, down, loop, color, edge, glow, unit, gleam)
	local n = loop.n
	local run = 0
	for i = 1, n do
		local k = i % n + 1
		local ax, ay, bx, by = loop[i * 2 - 1], loop[i * 2], loop[k * 2 - 1], loop[k * 2]
		Stroke(sheet.glow, anchor, point, down, ax, ay, bx, by, glow * unit, color, 1)
		Stroke(sheet.edge, anchor, point, down, ax, ay, bx, by, edge * unit, color, 1)
		if gleam then
			local line = Stroke(sheet.gleam, anchor, point, down, ax, ay, bx, by, DRAW.gleamWide * unit, WHITE, 0)
			line:SetAlpha(0)   -- dark until the gleam reaches it (Gleam)
			line.gleamed = 0
			line.run, line.total = run + math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / 2, false
			run = run + math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		end
	end
	if gleam then
		for i = sheet.gleam.used - n + 1, sheet.gleam.used do sheet.gleam[i].total = run end
	end
end

-- A region's fill: plain lines in the color, a row `pitch` high after another down the ground, each
-- from where the outline is crossed to where it is crossed again. The frame they are on makes them faint.
local function Fill(sheet, anchor, point, down, loops, color, pitch)
	if not loops.bands then return end
	pitch = math.max(pitch, (loops.bottom - loops.top) / DRAW.fillMost)
	for row = math.floor(loops.top / pitch), math.floor(loops.bottom / pitch) do
		local y = (row + 0.5) * pitch
		local n = Cross(loops, y, cuts)
		for i = 1, n - 1, 2 do
			Stroke(sheet.fill, anchor, point, down, cuts[i], y, cuts[i + 1], y, pitch, color, 1)
		end
	end
end

-- The gleam along a clicked ground's edges: each gleam line's alpha by where the light is now, set only on the
-- lines it has changed on (in the screen's own steps of alpha): the light is on a few of an outline's pieces at
-- a time, and the rest stay dark.
local function Gleam(sheet, now, unit)
	local pool = sheet.gleam
	if not pool then return end
	local half = DRAW.gleamLength * unit / 2
	for i = 1, pool.used do
		local line = pool[i]
		local total = line.total
		if total and total > 0 then
			local at = (now * DRAW.gleamSpeed * unit) % total
			local along = (line.run - at + total / 2) % total - total / 2
			local strength = math.max(0, 1 - math.abs(along) / half)
			local alpha = math.floor(strength * strength * 0.9 * 255 + 0.5) / 255
			if line.gleamed ~= alpha then
				line.gleamed = alpha
				line:SetAlpha(alpha)
			end
		end
	end
end

-- World map

local mapLayer
local mapSheet
local prepared = {}          -- gathered sets for the shown map, by request key (Ground.Forget)
local drawn = {}             -- what the map shows now: .set, .shapes, .canvas, .kept
local mapShown = Shown()     -- its pointers, in the layer's units from its top left, y down
local mapDots = Shown()      -- and its dots
local blobs = {}             -- QuestPOIFrames of ours on the map layer, one per lit quest the game has an area for

-- How high a row of the fill is at a zoom, in the layer's units: DRAW.fillRow on screen or a little less,
-- taken in steps so the fill is laid again only now and then as the map zooms.
local function Grain(canvas)
	return SHAPE.step ^ math.floor(math.log(DRAW.fillRow / canvas) / math.log(SHAPE.step))
end

-- Draw the regions. unit: one screen pixel, in the layer's units. grain: Grain's for the zoom.
-- shade: one objective's ground of a quest of several, pointed at: drawn in its shade (Marks.lua).
local function Regions(made, unit, kept, grain, shade)
	Begin(mapSheet.fill, mapSheet.edge, mapSheet.glow, mapSheet.gleam)
	for _, kind in ipairs(ORDER) do
		for _, loops in ipairs(made.fills[kind] or {}) do
			Fill(mapSheet, mapLayer, "TOPLEFT", true, loops, shade or KIND[kind].color, grain)
		end
		for _, loop in ipairs(made[kind] or {}) do
			Region(mapSheet, mapLayer, "TOPLEFT", true, loop, shade or KIND[kind].color, DRAW.edge, DRAW.glow, unit, kept)
		end
	end
	Finish(mapSheet.fill, mapSheet.edge, mapSheet.glow, mapSheet.gleam)
end

-- The same regions at another zoom: the lines keep their width on screen (the fill's rows are the
-- map's own units and zoom with it, until the zoom wants another grain).
local function Rescale(unit)
	for _, pool in ipairs({ mapSheet.edge, mapSheet.glow, mapSheet.gleam }) do
		local thick = (pool == mapSheet.edge and DRAW.edge or pool == mapSheet.glow and DRAW.glow or DRAW.gleamWide) * unit
		for i = 1, pool.used do
			pool[i].thick = thick
			pool[i]:SetThickness(thick)
		end
	end
end

-- The game's own areas for the lit quests: a QuestPOIFrame per quest, drawn with the kind's strip.
local function Blobs(set, map)
	local used = 0
	for _, id in ipairs(set.blobs) do
		if not set.blobs[id] then
			-- Drawn as ground from its samples.
		else
		used = used + 1
		local frame = blobs[used]
		if not frame then
			local ok, made = pcall(CreateFrame, "QuestPOIFrame", nil, mapLayer)
			if not ok or not made then break end
			frame = made
			frame:SetAllPoints(mapLayer)
			frame:SetFrameLevel(math.max(1, mapLayer:GetFrameLevel() - 2))
			blobs[used] = frame
		end
		pcall(frame.SetMapID, frame, map)
		pcall(frame.SetFillTexture, frame, BLIZZARD_FILL)
		pcall(frame.SetBorderTexture, frame, BLIZZARD_BORDER_WHITE)
		pcall(frame.SetFillAlpha, frame, BLOB.fill)
		pcall(frame.SetBorderAlpha, frame, BLOB.border)
		pcall(frame.SetBorderScalar, frame, BLOB.scalar)
		pcall(frame.EnableSmoothing, frame, true)
		pcall(frame.SetNumSplinePoints, frame, BLOB.spline)
		pcall(frame.EnableMerging, frame, true)
		pcall(frame.DrawNone, frame)
		pcall(frame.DrawBlob, frame, id, true)
		frame:Show()
		end
	end
	for i = used + 1, #blobs do
		pcall(blobs[i].DrawNone, blobs[i])
		blobs[i]:Hide()
	end
end

-- How far a spawn's ground reaches on the shown map, in the layer's units: SHAPE.radius yards, or SHAPE.floor on
-- screen where that is more, taken in steps so the outlines are worked out again only now and then.
local function Reach(map, width, canvas)
	local frame = Frame(map)
	local base = frame and SHAPE.radius / frame.yards * width or width / 250
	local steps = math.max(0, math.ceil(math.log(SHAPE.floor / canvas / base) / math.log(SHAPE.step) - 0.001))
	return base * SHAPE.step ^ steps
end

-- Show the ground on the world map for `stop` (may be nil). live: as Ground.Of. map, width, height,
-- canvas: the shown map, the layer's size, the canvas scale. kept: the stop was clicked, so its light
-- is kept and the gleam runs. (rest is no longer used: nothing is drawn for the other quests.)
-- shade: the stop is one objective of a quest of several, pointed at: its ground is drawn in its shade.
-- Returns how many of the stop's own spawns are on the map, and the names of what is there.
function Ground.Map(stop, live, rest, map, width, height, canvas, kept, shade)
	if not mapLayer then return 0, {} end
	local request = (stop and (stop.key or tostring(stop)) or "-") .. (live and "|live|" or "|all|") .. map
	local set = prepared[request]
	if not set then
		set = Prepare(stop, live, map)
		prepared[request] = set
	end
	local radius = Reach(map, width, canvas)
	local made, whole = Shapes(set, width, height, radius, true)
	-- A zoom that asks for a ground still being traced keeps what is drawn of the same ground till then.
	if not whole and drawn.shapes and drawn.sig == set.sig and drawn.width == width then made = drawn.shapes end
	local unit = 1 / canvas
	local grain = Grain(canvas)
	kept = kept and true or false
	shade = shade or false
	if drawn.shapes ~= made or drawn.kept ~= kept or drawn.grain ~= grain or drawn.shade ~= shade then
		drawn.shade = shade
		Regions(made, unit, kept, grain, shade or nil)
		drawn.unit = unit
	elseif drawn.canvas ~= canvas and math.abs(unit / drawn.unit - 1) > DRAW.widthSlack then
		-- (A zoom moves every frame: the outlines are told their width again only once it is off by more
		-- than a hair on screen.)
		Rescale(unit)
		drawn.unit = unit
	end
	-- (A zoom only sizes the pointers and dots, which stand where they stood on the canvas: they are laid
	-- again only once their size on screen is off by more than a hair, as the outlines' widths are.)
	if drawn.set ~= set or drawn.width ~= width or not drawn.dotUnit or math.abs(unit / drawn.dotUnit - 1) > DRAW.widthSlack then
		drawn.dotUnit = unit
		-- A pointer for each of a few far apart; the other spawns are lit as their ground, and counted.
		local spots = set.spots
		mapSheet.used = 0
		mapShown.n, mapShown.size = 0, DRAW.spot * unit
		for i = 1, spots.n do
			local x, y = spots.x[i] * width, spots.y[i] * height
			Spot(Light(mapSheet), mapLayer, "TOPLEFT", x, -y, spots.kind[i], DRAW.spot * unit, 1, spots.row[i] and spots.row[i].shade)
			Put(mapShown, x, y, spots, i)
		end
		local quiet = set.hidden
		for _, kind in ipairs(ORDER) do
			local group = set.groups[kind]
			if group then quiet = quiet + group.n - group.pointed end
		end
		mapSheet.quiet = quiet
		Douse(mapSheet)
		-- Every spawn of what is lit, as the minimap's picture of its kind at one size on screen at any
		-- zoom; a crowd of more than DRAW.mapDots is thinned evenly.
		local dots, sheet = set.dots, mapSheet.dots
		sheet.used = 0
		mapDots.n, mapDots.size = 0, DRAW.mapDot * unit
		local every = math.max(1, math.ceil(dots.n / DRAW.mapDots))
		for i = 1, dots.n, every do
			if dots.x[i] then
				local x, y = dots.x[i] * width, dots.y[i] * height
				Dot(sheet, x, -y, dots.kind[i], 1, mapLayer, "TOPLEFT", DRAW.mapDot * unit, dots.shade[i])
				Put(mapDots, x, y, dots, i)
			end
		end
		DouseDots(sheet)
	end
	if drawn.set ~= set then
		Blobs(set, map)
	end
	local frame = Frame(map)
	drawn.continent = frame and frame.continent
	drawn.set, drawn.sig, drawn.shapes, drawn.canvas, drawn.width, drawn.kept = set, set.sig, made, canvas, width, kept
	drawn.grain = grain
	return set.own, set.names
end

-- Whether a point lies on a traced ground (Ground.Loops' result): inside its outlines.
local function Covers(loops, x, y)
	local n = Cross(loops, y, cuts)
	for i = 1, n - 1, 2 do
		if x >= cuts[i] and x <= cuts[i + 1] then return true end
	end
	return false
end

-- Every kind of ground a point is on, the one drawn on top first: { { kind, rows }, ... }, each with the
-- key's rows of its kind ({ kind, word, text, quest, objective }); nil when it is on none. Where grounds
-- lie over one another (kills in the middle of a wide patch of loot) all of them are there. A pointer
-- with no ground round it is a hit as well, with its own rows alone.
--   on(kind): true where the point is on that kind's ground; the rows of that kind's pointers it is on
--   where it is on those alone (Pointed); else nil.
local function Kinds(rows, on)
	local hits
	for at = #ORDER, 1, -1 do
		local kind = ORDER[at]
		local mine = on(kind)
		if mine then
			if mine == true then
				mine = {}
				for _, row in ipairs(rows) do
					if row.kind == kind then mine[#mine + 1] = row end
				end
			end
			hits = hits or {}
			hits[#hits + 1] = { kind = kind, rows = mine }
		end
	end
	return hits
end

-- What the lit ground at a point of the world map is for (Kinds). x, y: in the layer's own units from
-- its top left, y down.
function Ground.Under(x, y)
	local made, set = drawn.shapes, drawn.set
	if not (made and set) then return nil end
	return Kinds(set.rows, function(kind)
		for _, loops in ipairs(made.fills[kind] or {}) do
			if Covers(loops, x, y) then return true end
		end
		return Pointed(mapShown, kind, x, y, -1)
	end)
end

-- The spawn under a point of the world map (SpawnIn), x, y as for Ground.Under.
function Ground.SpawnAt(x, y)
	if not drawn.set then return nil end
	return SpawnIn(mapShown, mapDots, x, y, -1, drawn.continent)
end

-- Call when the shown map, the route or the log changes.
function Ground.Forget()
	wipe(prepared)
	for print_ in pairs(made.sets) do
		if not made.used[print_] then
			made.sets[print_] = nil
			made.n = made.n - 1
		end
	end
	wipe(made.used)
end

-- What is there

-- The names of what a stop needs now on `map` (the words of its hover's "Where").
function Ground.Names(stop, map)
	local request = (stop.key or tostring(stop)) .. "|live|" .. map
	local set = prepared[request]
	if not set then
		set = Prepare(stop, true, map)
		prepared[request] = set
	end
	return set.names
end

-- The world map's ground out of sight (the map closed, or turned to another map with the ground still to
-- lay there): its frames come back one a frame from the next (SetupMap).
function Ground.Away()
	if not mapSheet then return end
	mapSheet:Hide()
	mapSheet.tint:Hide()
	mapSheet.wash:Hide()
	mapSheet.coming = 1
end

-- layer: the pins' frame over the world map's canvas. The glow lies under the edge, on a frame of its own
-- that breathes; the gleam over both.
function Ground.SetupMap(layer)
	mapLayer = layer
	local level = math.max(2, layer:GetFrameLevel() - 1)
	mapSheet = Sheet(layer, level)
	mapSheet.dots = { used = 0, sheet = mapSheet }
	mapSheet.edge = Lines(mapSheet, "BORDER", 1, EDGE_ART)
	mapSheet.gleam = Lines(mapSheet, "BORDER", 2, DASH)
	-- The fill's frame is what is faint: its lines are whole, so no line of them can come out solid.
	local tint = CreateFrame("Frame", nil, layer)
	tint:SetAllPoints()
	tint:SetFrameLevel(math.max(0, level - 2))
	tint:SetAlpha(DRAW.fillAlpha)
	mapSheet.fill = Lines(tint, "BACKGROUND", -1, SOLID)
	local wash = CreateFrame("Frame", nil, layer)
	wash:SetAllPoints()
	wash:SetFrameLevel(level - 1)
	mapSheet.glow = Lines(wash, "BACKGROUND", 0, GLOW_ART)
	local breath = wash:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local fade = breath:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(DRAW.breathLow)
	fade:SetDuration(DRAW.breath)
	fade:SetSmoothing("IN_OUT")
	breath:Play()
	-- The ground is hundreds of lines for the game to show as the map opens: its three frames go out of
	-- sight with the map and come back one a frame after it (mapSheet.coming: the next), each timed, so
	-- the opening's frame shows the pins alone. On a frame of the ground's own: the layer's frame script is
	-- the pins' to set.
	local coming = {
		Shy.Clocked("ground: its edges into sight", function() mapSheet:Show() end),
		Shy.Clocked("ground: its fill into sight", function() tint:Show() end),
		Shy.Clocked("ground: its glow into sight", function() wash:Show() end),
	}
	mapSheet.tint, mapSheet.wash = tint, wash
	local driver = CreateFrame("Frame", nil, layer)
	driver:SetScript("OnHide", Ground.Away)
	driver:SetScript("OnUpdate", Shy.Clocked("frame: ground layer", function()
		local next = mapSheet.coming
		if next then
			coming[next]()
			mapSheet.coming = coming[next + 1] and next + 1 or nil
		end
		if drawn.kept then Gleam(mapSheet, GetTime(), drawn.canvas and 1 / drawn.canvas or 1) end
	end))
end

-- Minimap

local miniSheet
-- .fresh: chosen again since it was last placed (PlaceMini).
local mini = { n = 0, north = {}, west = {}, kind = {}, row = {}, what = {}, loops = {}, fills = {}, fresh = true,
	dots = { n = 0, north = {}, west = {}, kind = {}, shade = {}, what = {} } }
local miniShown = Shown()    -- the pointers placed on it, from its middle as shares of its range, y up
local miniDots = Shown()     -- and the dots
local miniContinent
local miniKept = false

-- The player is already on the lit ground: the minimap is showing where the work is, so nothing
-- should draw a line toward a point of it (Ground.Standing()). Just outside it, within NEAR yards, is
-- `beside` (Ground.Standing(true): on it, or beside it): a turn-in beside the area is no reason to choose
-- every stop again while the work is underfoot, but the line to what leads is drawn there as anywhere off
-- the ground. World yards, the same ones the fills were traced in.
-- (Defined after the minimap's ground it reads: above it, `mini` named a global.)
-- The minimap asks at every frame, and each answer walks every outline of the lit ground, up to nine times
-- over: both answers for where the player stood at the last pulse are kept while they stand there and the
-- ground chosen is the same (mini.chosen), KEPT seconds at most (an outline still being traced comes in under it).
mini.chosen, mini.stood = 0, { KEPT = 0.5, NEAR = 40 }
-- Whether the player is on it, and whether on it or beside it.
function mini.Stands()
	local north, west, beside, near = W.north, W.west, false, mini.stood.NEAR
	for _, fill in ipairs(mini.fills) do
		local loops = fill.loops
		if Covers(loops, north, west) then return true, true end
		if loops.top and west >= loops.top - near and west <= loops.bottom + near then beside = true end
	end
	-- Beside the work, not in it: just outside one of its areas. Far from every area, it is neither.
	if not beside then return false, false end
	for step = 0, 7 do
		local turn = step * math.pi / 4
		local n, w = north + math.cos(turn) * near, west + math.sin(turn) * near
		for _, fill in ipairs(mini.fills) do
			if Covers(fill.loops, n, w) then return false, true end
		end
	end
	return false, false
end
function Ground.Standing(beside)
	if not (W.north and W.continent == miniContinent) then return false end
	local stood, now = mini.stood, GetTime()
	if not (stood.north == W.north and stood.west == W.west and stood.chosen == mini.chosen and stood.at and now - stood.at < stood.KEPT) then
		stood.north, stood.west, stood.chosen, stood.at = W.north, W.west, mini.chosen, now
		stood.on, stood.near = mini.Stands()
	end
	if beside then return stood.near end
	return stood.on
end

-- Choose the minimap's ground: the lit stop's regions in world yards, and the pointers of a few within
-- a little over the minimap's range. Called again on each route rebuild, so the outlines are kept by
-- what they are of (Traced): a rebuild that leaves the ground as it was traces nothing. (rest is no
-- longer used.)
--   asked: the stop is a hovered or clicked pin's, so all its quests count, not only what is live.
--   kept: the stop was clicked.
--   here: the player stands on the stop's ground: the spawns round them are dots, so they see where
--   the creatures and things are instead of being led to one spot of it.
-- What the minimap was last given to lay: a choice the same in all it draws isn't laid again (a route built
-- again for nothing new on the minimap, as a fight beginning with an errand on it).
local laid = { continent = false, kept = false, loops = {}, fills = {}, n = 0, north = {}, west = {}, kind = {}, shade = {},
	dots = { n = 0, north = {}, west = {}, kind = {}, shade = {} } }
laid.POINTER, laid.DOT = { "north", "west", "kind" }, { "north", "west", "kind", "shade" }
-- `into` made the same as `from` in its first n of each field; whether it was already.
function laid.Keep(into, from, n, fields)
	local same = into.n == n
	for _, field in ipairs(fields) do
		local a, b = into[field], from[field]
		for i = 1, n do
			if a[i] ~= b[i] then
				same = false
				a[i] = b[i]
			end
		end
	end
	into.n = n
	return same
end
-- Whether the choice just made draws anything other than the one last laid (and it is kept as that).
function laid.Changed()
	local same = laid.continent == miniContinent and laid.kept == miniKept
	laid.continent, laid.kept = miniContinent, miniKept
	-- (The traced loops are kept by what they are of: the same ground is the same tables.)
	local loops, fills = laid.loops, laid.fills
	if #loops ~= #mini.loops or #fills ~= #mini.fills * 2 then same = false end
	for i, loop in ipairs(mini.loops) do
		if loops[i] ~= loop then same, loops[i] = false, loop end
	end
	for i = #loops, #mini.loops + 1, -1 do loops[i] = nil end
	for i, fill in ipairs(mini.fills) do
		if fills[i * 2 - 1] ~= fill.loops or fills[i * 2] ~= fill.kind then
			same, fills[i * 2 - 1], fills[i * 2] = false, fill.loops, fill.kind
		end
	end
	for i = #fills, #mini.fills * 2 + 1, -1 do fills[i] = nil end
	-- A pointer is drawn in its row's shade.
	for i = 1, mini.n do
		local shade = mini.row[i] and mini.row[i].shade or false
		if laid.shade[i] ~= shade then same, laid.shade[i] = false, shade end
	end
	if not laid.Keep(laid, mini, mini.n, laid.POINTER) then same = false end
	if not laid.Keep(laid.dots, mini.dots, mini.dots.n, laid.DOT) then same = false end
	return not same
end

function Ground.ChooseMini(...)
	local waiting = mini.fresh
	laid.Choose(...)
	mini.fresh = laid.Changed() or waiting
end

-- A group's loops on the minimap, in yards, kept by what they are of (Traced); nil while being traced.
function laid.Loops(map, frame, kind, group, radius)
	local name = ("%s|mini|%s"):format(group.sig or kind, map)
	local loops = traced[name]
	if loops == nil then
		local xs, ys = {}, {}
		for i = 1, group.n do xs[i], ys[i] = ToWorld(frame, group.x[i] * UNITS, group.y[i] * UNITS) end
		loops = Traced(name, xs, ys, group.n, radius, true)
	end
	return loops
end

-- What the minimap would light for `stop` worked out now, as its next choice will ask for it: the set and
-- its loops, kept by what they are of, so a route that comes to light it finds them made (a guess that
-- doesn't come is let go of as anything not asked for is).
function Ground.Warm(stop)
	local frame = W.Known() and W.map and Frame(W.map)
	if not (stop and miniSheet and frame and frame.continent == W.continent) then return end
	local set = Prepare(stop, true, W.map, true)
	for _, kind in ipairs(ORDER) do
		if set.groups[kind] then laid.Loops(W.map, frame, kind, set.groups[kind], SHAPE.radius) end
		if set.areas[kind] then laid.Loops(W.map, frame, kind, set.areas[kind], frame.yards / BLOB.sample * BLOB.reach) end
	end
end

function laid.Choose(stop, rest, reach, asked, kept, here)
	mini.n, mini.dots.n = 0, 0
	mini.rows = nil
	wipe(mini.loops)
	wipe(mini.fills)
	mini.chosen = mini.chosen + 1   -- (another choice: what Standing kept was of the last one's fills)
	miniContinent = W.continent
	miniKept = kept and true or false
	-- Why it has nothing, for the report.
	mini.why = not miniSheet and "not set up" or not W.Known() and "your position isn't known yet"
		or not (reach and reach > 0) and "the minimap's range isn't known yet" or not stop and "nothing is lit"
		or not W.map and "no map for where you are" or nil
	if mini.why then return end
	local frame = Frame(W.map)
	if not frame or frame.continent ~= W.continent then
		mini.why = "the map isn't placed in the world yet"
		return
	end
	local map = W.map
	local set = Prepare(stop, not asked, map, true)
	mini.rows = set.rows         -- what each kind of this ground is for (Ground.UnderMini)
	-- The regions, in yards: the loops of each kind's spawns at the yard radius, and of the game's
	-- areas hugging their samples. One still being traced is left out until it is done.
	local function Take(kind, group, radius)
		local loops = laid.Loops(map, frame, kind, group, radius)
		if not loops then return end
		for _, loop in ipairs(loops) do
			loop.kind = kind
			mini.loops[#mini.loops + 1] = loop
		end
		mini.fills[#mini.fills + 1] = { loops = loops, kind = kind }
	end
	for _, kind in ipairs(ORDER) do
		if set.groups[kind] then Take(kind, set.groups[kind], SHAPE.radius) end
		if set.areas[kind] then Take(kind, set.areas[kind], frame.yards / BLOB.sample * BLOB.reach) end
	end
	-- The pointers: the nearest of a few.
	local near = (reach * 1.45 + DRAW.miniFar) ^ 2
	local found = {}
	local spots = set.spots
	for i = 1, spots.n do
		local north, west = spots.north[i], spots.west[i]
		if north then
			local far = (north - W.north) ^ 2 + (west - W.west) ^ 2
			if far < near then found[#found + 1] = { far, north, west, spots.kind[i], spots.row[i], spots.what[i] } end
		end
	end
	if #found > DRAW.miniMost then table.sort(found, function(a, b) return a[1] < b[1] end) end
	local n = math.min(#found, DRAW.miniMost)
	for i = 1, n do
		mini.north[i], mini.west[i], mini.kind[i], mini.row[i] = found[i][2], found[i][3], found[i][4], found[i][5]
		mini.what[i] = found[i][6]
	end
	mini.n = n
	-- The dots: the nearest of every spawn on the ground stood on, the few that have pointers elsewhere
	-- among them: here one mark is one spawn, all alike. An object keeps its pointer: it has no ground.
	if not here then return end
	local still = 0
	for i = 1, n do
		if Still(mini.what[i]) then
			still = still + 1
			mini.north[still], mini.west[still], mini.kind[still] = mini.north[i], mini.west[i], mini.kind[i]
			mini.row[still], mini.what[still] = mini.row[i], mini.what[i]
		end
	end
	mini.n = still
	wipe(found)
	for _, dots in ipairs({ set.dots, spots }) do
		for i = 1, dots.n do
			local north, west = dots.north[i], dots.west[i]
			if north and not (dots == spots and Still(spots.what[i])) then
				local far = (north - W.north) ^ 2 + (west - W.west) ^ 2
				if far < near then
					local shade = dots.shade and dots.shade[i] or (dots.row and dots.row[i] and dots.row[i].shade)
					found[#found + 1] = { far, north, west, dots.kind[i], shade or false, dots.what[i] }
				end
			end
		end
	end
	if #found > DRAW.miniDots then table.sort(found, function(a, b) return a[1] < b[1] end) end
	local into = mini.dots
	into.n = math.min(#found, DRAW.miniDots)
	for i = 1, into.n do
		into.north[i], into.west[i], into.kind[i], into.shade[i] = found[i][2], found[i][3], found[i][4], found[i][5]
		into.what[i] = found[i][6]
	end
end

-- The part of the segment from a to b inside the minimap's edge, by its shape; points are fractions
-- of its range. nil when none of it is inside.
local MINI_EDGE_AT = 0.98
local function Within(ax, ay, bx, by, square)
	local dx, dy = bx - ax, by - ay
	local from, to = 0, 1
	if square then
		for side = 1, 4 do
			local p = side == 1 and -dx or side == 2 and dx or side == 3 and -dy or dy
			local q = side == 1 and ax + MINI_EDGE_AT or side == 2 and MINI_EDGE_AT - ax or side == 3 and ay + MINI_EDGE_AT or MINI_EDGE_AT - ay
			if p == 0 then
				if q < 0 then return nil end
			elseif p < 0 then
				from = math.max(from, q / p)
			else
				to = math.min(to, q / p)
			end
		end
	else
		local a = dx * dx + dy * dy
		local b = 2 * (ax * dx + ay * dy)
		local crossed = b * b - 4 * a * (ax * ax + ay * ay - MINI_EDGE_AT * MINI_EDGE_AT)
		if a == 0 or crossed <= 0 then return nil end
		local root = math.sqrt(crossed)
		from, to = math.max(from, (-b - root) / (2 * a)), math.min(to, (-b + root) / (2 * a))
	end
	if from >= to then return nil end
	return ax + dx * from, ay + dy * from, ax + dx * to, ay + dy * to
end

-- The rim: where a lit ground runs on past the minimap's edge, its outline carries on along the edge,
-- so what shows of it is closed. Each arc runs along the very edge the outline is cut at, from one
-- crossing of the outline to the next, in the outline's own strokes. Where two grounds both run past
-- one stretch, the smaller one's arc keeps the edge (it meets its own outline) and the larger one's
-- steps out RIM.step to stand beside it, easing out over RIM.ramp around the smaller one's crossings;
-- at its own crossings it is on the edge again.
local RIM = {
	step = 3.5,  -- units: a ground's arc stands this far outside the arc of a smaller one
	ramp = 10,  -- units along the edge: the step out is eased over this
	join = 0.6,  -- units: an arc reaches this far past each crossing, under the outline's line end
	arc = 1 / 60,  -- a round edge is laid in pieces of this share of it
	most = 3,  -- grounds with an arc at most
}
local rimLines = {}          -- the arcs as last laid, for the report and tests: { kind, level, ax, ay, bx, by }

-- The net size of a traced ground (its outer lines less its gaps), kept on it.
local function Size(loops)
	if loops.size then return loops.size end
	local sum = 0
	for _, loop in ipairs(loops) do
		local n = loop.n
		for i = 1, n do
			local k = i % n + 1
			sum = sum + loop[i * 2 - 1] * loop[k * 2] - loop[k * 2 - 1] * loop[i * 2]
		end
	end
	loops.size = math.abs(sum) / 2
	return loops.size
end

-- Inside the edge the lines are cut at; x, y in shares of the range.
local function Inner(x, y, square)
	if square then return math.max(math.abs(x), math.abs(y)) < MINI_EDGE_AT end
	return x * x + y * y < MINI_EDGE_AT * MINI_EDGE_AT
end

-- The share of the edge, clockwise from the top's middle, at a point on it.
local function EdgeShare(x, y, square)
	if not square then return (math.atan2(x, y) / (2 * math.pi)) % 1 end
	x, y = x / MINI_EDGE_AT, y / MINI_EDGE_AT
	if math.abs(y) >= math.abs(x) then
		if y > 0 then return (x >= 0 and x or 8 + x) / 8 end
		return (4 - x) / 8
	end
	if x > 0 then return (2 - y) / 8 end
	return (6 + y) / 8
end

-- The point of the edge at share s, `out` shares of the range outside it.
local function EdgeAt(s, out, square)
	s = s % 1
	local reach = MINI_EDGE_AT + out
	if not square then
		local t = s * 2 * math.pi
		return math.sin(t) * reach, math.cos(t) * reach
	end
	local run = s * 8
	local x, y
	if run < 1 then
		x, y = run, 1
	elseif run < 3 then
		x, y = 1, 2 - run
	elseif run < 5 then
		x, y = 4 - run, -1
	elseif run < 7 then
		x, y = -1, run - 6
	else
		x, y = run - 8, 1
	end
	return x * reach, y * reach
end

-- The arcs of the minimap's edge for `fills` ({ { kind, loops }, ... } in world yards), the player at
-- (north, west), the minimap showing `reach` yards to its edge, turned by (sin, cos), round or square:
-- { { kind, color, arcs = { a, b, ... }, size }, ... }, the smallest ground first, each arc clockwise from
-- a to b in shares of the edge (b may pass 1; 0, 1 is the whole edge). The crossings are where the
-- outline's own pieces are cut (Within), so an arc begins exactly where the outline's line ends.
function Ground.Rims(fills, north, west, reach, sin, cos, square)
	local function At(north_, west_)
		local east, up = -(west_ - west) / reach, (north_ - north) / reach
		return east * cos + up * sin, -east * sin + up * cos
	end
	local kinds, order = {}, {}
	for _, fill in ipairs(fills) do
		local kind = kinds[fill.kind]
		if not kind then
			kind = { kind = fill.kind, lists = {}, crossed = {}, size = 0 }
			kinds[fill.kind] = kind
			order[#order + 1] = kind
		end
		kind.lists[#kind.lists + 1] = fill.loops
		kind.size = kind.size + Size(fill.loops)
		for _, loop in ipairs(fill.loops) do
			local n = loop.n
			local fx, fy = At(loop[1], loop[2])
			local ax, ay, inA = fx, fy, Inner(fx, fy, square)
			for i = 1, n do
				local bx, by, inB
				if i == n then
					bx, by = fx, fy
				else
					bx, by = At(loop[i * 2 + 1], loop[i * 2 + 2])
				end
				inB = Inner(bx, by, square)
				if not (inA and inB) then
					local x1, y1, x2, y2 = Within(ax, ay, bx, by, square)
					if x1 then
						if not inA then kind.crossed[#kind.crossed + 1] = EdgeShare(x1, y1, square) end
						if not inB then kind.crossed[#kind.crossed + 1] = EdgeShare(x2, y2, square) end
					end
				end
				ax, ay, inA = bx, by, inB
			end
		end
	end
	local bands = {}
	for _, kind in ipairs(order) do
		local function On(s)
			local x, y = EdgeAt(s, 0, square)
			local east, up = x * cos - y * sin, x * sin + y * cos
			local n, w = north + up * reach, west - east * reach
			for _, loops in ipairs(kind.lists) do
				if Covers(loops, n, w) then return true end
			end
			return false
		end
		local arcs = {}
		local crossed = kind.crossed
		if #crossed == 0 then
			-- The whole view is inside the ground. The edge is the outline's, all the way round.
			if On(0) then arcs[1], arcs[2] = 0, 1 end
		else
			table.sort(crossed)
			for i = 1, #crossed do
				local a, b = crossed[i], crossed[i + 1] or crossed[1] + 1
				if b - a > 1e-6 and On((a + b) / 2) then
					arcs[#arcs + 1], arcs[#arcs + 2] = a, b
				end
			end
		end
		if #arcs > 0 then bands[#bands + 1] = { kind = kind.kind, color = KIND[kind.kind].color, arcs = arcs, size = kind.size } end
	end
	table.sort(bands, function(a, b) return a.size < b.size end)
	for i = #bands, RIM.most + 1, -1 do bands[i] = nil end
	return bands
end

-- How far into the arcs of `band` share s lies, 0 outside to 1 inside, eased over RIM.ramp (in shares)
-- about each end.
local function Into(band, s, ramp)
	local arcs, most = band.arcs, 0
	for i = 1, #arcs - 1, 2 do
		local a, b = arcs[i], arcs[i + 1]
		if b - a >= 1 then return 1 end
		local ds = (s - a) % 1
		local d = ds <= b - a and math.min(ds, b - a - ds) or -math.min(ds - (b - a), 1 - ds)
		local u = math.max(0, math.min(1, 0.5 + d / ramp))
		u = u * u * (3 - 2 * u)
		if u > most then most = u end
	end
	return most
end

-- Lay the bands' arcs (Ground.Rims) on the minimap with the outline's strokes, `radius` units to its edge.
function Ground.LayRims(bands, radius, square)
	wipe(rimLines)
	-- Tests lay arcs before the minimap exists: they only read RimLines, and draw nothing.
	local edge = miniSheet and miniSheet.rimEdge or nil
	local glow = miniSheet and miniSheet.rimGlow or nil
	local length = (square and 8 or 2 * math.pi) * MINI_EDGE_AT * radius
	local ramp, join, step = RIM.ramp / length, RIM.join / length, RIM.step / radius
	local points = {}
	for level, band in ipairs(bands) do
		local color = band.color
		-- How far out at s: a step for each smaller ground whose arc is there.
		local function Out(s)
			local out = 0
			for j = 1, level - 1 do out = out + Into(bands[j], s, ramp) end
			return out * step
		end
		local arcs = band.arcs
		for i = 1, #arcs - 1, 2 do
			local a, b = arcs[i], arcs[i + 1]
			if b - a < 1 then a, b = a - join, b + join end
			wipe(points)
			points[1], points[2] = a, b
			-- Pieces: the round edge every RIM.arc, the square's corners, and finely where a step eases out.
			if square then
				for c = math.floor(a * 4 - 0.5), math.ceil(b * 4) do
					local corner = (c + 0.5) / 4
					if corner > a and corner < b then points[#points + 1] = corner end
				end
			else
				for s = math.ceil(a / RIM.arc) * RIM.arc, b, RIM.arc do points[#points + 1] = s end
			end
			for j = 1, level - 1 do
				local inner = bands[j].arcs
				for e = 1, #inner do
					for wrap = -1, 1 do
						local at = inner[e] + wrap
						for k = -3, 3 do
							local s = at + k * ramp / 6
							if s > a and s < b then points[#points + 1] = s end
						end
					end
				end
			end
			table.sort(points)
			local px, py
			for k = 1, #points do
				local s = points[k]
				if k == 1 or s - points[k - 1] > 1e-7 then
					local x, y = EdgeAt(s, Out(s), square)
					x, y = x * radius, y * radius
					if px then
						-- Clockwise, so a strip's outward side lies outside the edge, as the outline's does.
						if glow then Stroke(glow, Minimap, "CENTER", false, px, py, x, y, DRAW.miniGlow, color, 1) end
						if edge then Stroke(edge, Minimap, "CENTER", false, px, py, x, y, DRAW.miniEdge, color, 1) end
						rimLines[#rimLines + 1] = { kind = band.kind, level = level, ax = px, ay = py, bx = x, by = y }
					end
					px, py = x, y
				end
			end
		end
	end
end

-- The arcs as last laid: { { kind, level, ax, ay, bx, by }, ... } in units from the minimap's middle.
function Ground.RimLines()
	return rimLines
end

-- Place the chosen ground, every frame: the player at (north, west) on `continent`, the minimap showing
-- `reach` yards over `radius` units, rotated by (sin, cos), round or `square`. A pointer fades out at
-- the rim and near the player.
-- The lines are drawn once on a plate, in the world. A step moves the plate. They are drawn again when
-- the ground, the zoom or the facing changes. The plate is clipped to the minimap.
local mx, my = {}, {}
-- plate, clip: the frame the ground is drawn on, and the minimap-sized frame that clips it.
-- shot: the player, zoom and facing the lines were drawn for. keep: yards of fill drawn around them.
local placed = { shot = {}, keep = 500, cover = 250 }
-- The fill as triangles: an outline of n points is n - 2 of them, laid once for the whole outline,
-- where rows were one for every few pixels of its height. Only for an area with no hole in it (rows fill
-- by crossings, so a hole is left out for nothing; triangles would cover it) and of no more than
-- TRI_MOST points a loop. Each loop's triangles are worked out once and kept on it (false: rows).
placed.TRI_MOST = 120
function placed.TriInside(px, py, ax, ay, bx, by, cx, cy)
	local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
	local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
	local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
	return not (((d1 < 0) or (d2 < 0) or (d3 < 0)) and ((d1 > 0) or (d2 > 0) or (d3 > 0)))
end
function placed.Tris(loop)
	if loop.tris ~= nil then return loop.tris end
	local n = loop.n or 0
	loop.tris = false
	if n < 3 or n > placed.TRI_MOST then return false end
	local area = 0
	for i = 1, n do
		local k = i % n + 1
		area = area + loop[i * 2 - 1] * loop[k * 2] - loop[k * 2 - 1] * loop[i * 2]
	end
	local turn = area > 0 and 1 or -1
	local left, out = {}, {}
	for i = 1, n do left[i] = i end
	local guard = n * n
	while #left > 3 and guard > 0 do
		guard = guard - 1
		local m, cut = #left, false
		for j = 1, m do
			local a, b, c = left[(j - 2) % m + 1], left[j], left[j % m + 1]
			local ax, ay, bx, by, cx, cy = loop[a * 2 - 1], loop[a * 2], loop[b * 2 - 1], loop[b * 2], loop[c * 2 - 1], loop[c * 2]
			local cross = ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) * turn
			if cross >= 0 then
				local ear = true
				if cross > 0 then
					for _, p in ipairs(left) do
						if p ~= a and p ~= b and p ~= c and placed.TriInside(loop[p * 2 - 1], loop[p * 2], ax, ay, bx, by, cx, cy) then
							ear = false
							break
						end
					end
				end
				if ear then
					if cross > 0 then out[#out + 1], out[#out + 2], out[#out + 3] = a, b, c end
					table.remove(left, j)
					cut = true
					break
				end
			end
		end
		if not cut then return false end   -- (not a simple outline: rows)
	end
	if #left == 3 then out[#out + 1], out[#out + 2], out[#out + 3] = left[1], left[2], left[3] end
	loop.tris = out
	return out
end
-- Whether an area's loops hold a hole: one loop's first point inside another loop.
function placed.Holed(loops)
	if loops.holed ~= nil then return loops.holed end
	local holed = false
	for i, outer in ipairs(loops) do
		for j, inner in ipairs(loops) do
			if i ~= j and inner.n and inner.n > 0 and outer.n and outer.n > 2 then
				local px, py, inside = inner[1], inner[2], false
				local k = outer.n
				for q = 1, outer.n do
					local xi, yi, xk, yk = outer[q * 2 - 1], outer[q * 2], outer[k * 2 - 1], outer[k * 2]
					if (yi > py) ~= (yk > py) and px < (xk - xi) * (py - yi) / (yk - yi) + xi then inside = not inside end
					k = q
				end
				if inside then holed = true end
			end
		end
	end
	loops.holed = holed
	return holed
end
-- One fill triangle (a, b, c) from the pool: a texture of the box round it, its corners moved onto the
-- three points (the fourth onto the third). The pool's row cache is told it holds no row now.
function placed.Tri(pool, anchor, ax, ay, bx, by, cx, cy, color)
	local used = pool.used + 1
	pool.used = used
	local t = pool[used]
	if not t then
		t = pool.owner:CreateTexture(nil, pool.layer, nil, pool.sub)
		t:SetSnapToPixelGrid(false)
		t:SetTexelSnappingBias(0)
		t:SetTexture(pool.art)
		if pool.art == SOLID then t:SetBlendMode("BLEND") end
		pool[used] = t
	end
	local left, right = math.min(ax, bx, cx), math.max(ax, bx, cx)
	local bottom, top = math.min(ay, by, cy), math.max(ay, by, cy)
	if right - left < 1 then right = left + 1 end
	if top - bottom < 1 then top = bottom + 1 end
	t:SetSize(right - left, top - bottom)
	t:SetPoint("CENTER", anchor, "CENTER", (left + right) / 2, (bottom + top) / 2)
	t:SetVertexOffset(UPPER_LEFT_VERTEX, ax - left, ay - top)
	t:SetVertexOffset(LOWER_LEFT_VERTEX, bx - left, by - bottom)
	t:SetVertexOffset(UPPER_RIGHT_VERTEX, cx - right, cy - top)
	t:SetVertexOffset(LOWER_RIGHT_VERTEX, cx - right, cy - bottom)
	t.ax, t.square = nil, false
	if t.tint ~= color or t.tintAlpha ~= 1 then
		t.tint, t.tintAlpha = color, 1
		t:SetVertexColor(color[1], color[2], color[3], 1)
	end
	if used > pool.shown then
		pool.shown = used
		t:Show()
	end
end
-- An area's triangles, loop by loop, or false where it is to be filled by rows.
function placed.AreaTris(loops)
	if placed.Holed(loops) then return false end
	for _, loop in ipairs(loops) do
		if not placed.Tris(loop) then return false end
	end
	return true
end
function placed.TriCount(loops)
	if loops.triCount then return loops.triCount end
	local count = 0
	for _, loop in ipairs(loops) do count = count + (loop.tris and #loop.tris / 3 or 0) end
	loops.triCount = count
	return count
end
function placed.Slid(shown, dx, dy)
	local base = shown.base
	if base then
		for i = 1, shown.n do
			shown.x[i], shown.y[i] = base.x[i] + dx, base.y[i] + dy
		end
	end
end
-- The pointers and dots where the plate's last slide left them, for what is under the mouse (Slide).
function placed.Hit()
	if not placed.unslid then return end
	placed.unslid = nil
	placed.Slid(miniShown, placed.dx, placed.dy)
	placed.Slid(miniDots, placed.dx, placed.dy)
end
local function Slide(north, west)
	local shot = placed.shot
	local reach, radius, sin, cos = shot.reach, shot.radius, shot.sin, shot.cos
	-- (Standing still, with the same shot and the same pieces on it: where it was put, it still is.)
	local s = placed.slid
	if s and s.north == north and s.west == west and s.sn == shot.north and s.sw == shot.west and s.sin == sin and s.cos == cos
		and s.reach == reach and s.radius == radius and s.shown == miniShown.base and s.dots == miniDots.base
		and s.n == miniShown.n and s.dn == miniDots.n then
		return
	end
	if not s then
		s = {}
		placed.slid = s
	end
	s.north, s.west, s.sn, s.sw, s.sin, s.cos, s.reach, s.radius = north, west, shot.north, shot.west, sin, cos, reach, radius
	s.shown, s.dots, s.n, s.dn = miniShown.base, miniDots.base, miniShown.n, miniDots.n
	local dx = ((west - shot.west) * cos + (shot.north - north) * sin) / reach
	local dy = (-(west - shot.west) * sin + (shot.north - north) * cos) / reach
	placed.plate:SetPoint("CENTER", placed.clip, "CENTER", dx * radius, dy * radius)
	-- (Where each pointer and dot now stands is read only for what is under the mouse: worked out when that is
	-- asked, placed.Hit, not for every one of them at every step of a walk.)
	placed.dx, placed.dy, placed.unslid = dx, dy, true
	-- The rim arcs are of the minimap's edge, not of the ground. A step hides the frame they are on.
	-- Left up, they stay on the chrome and follow the player while the ground slides away.
	-- (placed.rimUp: whether it was last shown, kept here: asking the frame is a call at every step.)
	if placed.rimUp and dx * dx + dy * dy > 1e-4 then
		placed.rimUp = false
		placed.rimFrame:Hide()
	end
end
-- Let a flight, a boat or a crossing ride the plate. The view is the minimap's now (Maps.Mini).
-- While the quest ground is up, that shot is the one that moves. While it is not, a shot is held
-- here so the journey has a plate of its own. Returns the shot and the plate, or nothing when this
-- view cannot ride (no plate yet, or the ground's shot is for another zoom or facing).
function Ground.Carry(v)
	local plate, shot = placed.plate, placed.shot
	if not (plate and v and v.north and v.reach and v.reach > 0 and v.radius and v.radius > 0) then return nil end
	local match = shot.ok and shot.reach == v.reach and shot.radius == v.radius and shot.continent == v.continent
		and shot.square == v.square and math.abs((shot.sin or 0) - v.sin) < 0.004 and math.abs((shot.cos or 1) - v.cos) < 0.004
	local near = (v.north - (shot.north or v.north)) ^ 2 + (v.west - (shot.west or v.west)) ^ 2 < (placed.keep * 0.5) ^ 2
	if placed.on and shot.ok then
		if not match or not near then return nil end
		Slide(v.north, v.west)
		placed.north, placed.west = v.north, v.west
		return shot, plate
	end
	if shot.held and match and near then
		Slide(v.north, v.west)
		placed.north, placed.west = v.north, v.west
		return shot, plate
	end
	shot.ok, shot.held = true, true
	shot.gen = (shot.gen or 0) + 1
	shot.north, shot.west, shot.reach, shot.radius = v.north, v.west, v.reach, v.radius
	shot.sin, shot.cos, shot.square, shot.continent = v.sin, v.cos, v.square, v.continent
	plate:SetPoint("CENTER", placed.clip, "CENTER", 0, 0)
	placed.north, placed.west = v.north, v.west
	return shot, plate
end
-- Give back a shot that a journey was holding. The quest ground's shot is left as it is.
function Ground.Drop()
	local shot = placed.shot
	if placed.on or not shot.held then return end
	shot.ok, shot.held = false, nil
	if placed.plate and placed.clip then placed.plate:SetPoint("CENTER", placed.clip, "CENTER", 0, 0) end
end
if Shy.Maps then
	Shy.Maps.Carry = Ground.Carry
	Shy.Maps.Drop = Ground.Drop
end
-- The minimap's fill, laid a few pieces a frame (placed.job, made by PlaceMini): each area's triangles
-- where they are fewer than its rows (all at once: they are few), else its rows, MINI_JOB a frame. The
-- pool was emptied as the job began, so the area comes in over a frame or three; a new drawing begins a
-- new job.
placed.MINI_JOB = 120
function placed.RunJob()
	local j = placed.job
	if not j then return end
	local pool, drawn, most = miniSheet.fill, 0, placed.MINI_JOB
	local At, pitch, cover, west, n0, n1, radius, hold = j.At, j.pitch, j.cover, j.west, j.n0, j.n1, j.radius, j.hold
	while j.fi <= #j.fills do
		local fill = j.fills[j.fi]
		local loops = fill.loops
		local color = KIND[fill.kind].color
		if not loops.bands then
			j.fi = j.fi + 1
		elseif not j.row then
			local from = math.max(math.floor((west - cover) / pitch), math.floor(loops.top / pitch))
			local to = math.min(math.floor((west + cover) / pitch), math.floor(loops.bottom / pitch))
			-- (Triangles where they are fewer than the rows this view needs: a fine outline over a small
			-- area is more triangles than rows.)
			if placed.AreaTris(loops) and placed.TriCount(loops) < to - from + 1 then
				for _, loop in ipairs(loops) do
					local tris = loop.tris
					for i = 1, #tris, 3 do
						local a, b, c = tris[i], tris[i + 1], tris[i + 2]
						local ax, ay = At(loop[a * 2 - 1], loop[a * 2])
						local bx, by = At(loop[b * 2 - 1], loop[b * 2])
						local cx, cy = At(loop[c * 2 - 1], loop[c * 2])
						placed.Tri(pool, hold, ax * radius, ay * radius, bx * radius, by * radius, cx * radius, cy * radius, color)
						drawn = drawn + 1
					end
				end
				j.fi = j.fi + 1
			else
				j.row, j.to = from, to
			end
		else
			while j.row <= j.to and drawn < most do
				local y = (j.row + 0.5) * pitch
				local n = Cross(loops, y, cuts)
				for i = 1, n - 1, 2 do
					local a, b = cuts[i], cuts[i + 1]
					if b >= n0 and a <= n1 then
						if a < n0 then a = n0 end
						if b > n1 then b = n1 end
						local ax, ay = At(a, y)
						local bx, by = At(b, y)
						Stroke(pool, hold, "CENTER", false, ax * radius, ay * radius, bx * radius, by * radius, DRAW.miniFillRow, color, 1)
						drawn = drawn + 1
					end
				end
				j.row = j.row + 1
			end
			if j.row > j.to then
				j.row, j.to = nil, nil
				j.fi = j.fi + 1
			end
		end
		if drawn >= most then return end
	end
	placed.job = nil
end
function Ground.PlaceMini(continent, north, west, reach, radius, sin, cos, square)
	if not miniSheet then return end
	local on = continent == miniContinent and reach ~= nil and reach > 0 and (mini.n > 0 or mini.dots.n > 0 or #mini.loops > 0)
	local rim = ns.T.db.minimapRim ~= false
	local shot = placed.shot
	local same = on and shot.ok and not mini.fresh and shot.reach == reach and shot.radius == radius
		and shot.square == square and shot.rim == rim and shot.continent == continent
		and math.abs(shot.sin - sin) < 0.004 and math.abs(shot.cos - cos) < 0.004
		and (north - shot.north) ^ 2 + (west - shot.west) ^ 2 < placed.cover ^ 2
	if same then
		Slide(north, west)
		if placed.job then placed.RunJob() end
		placed.on, placed.north, placed.west, placed.reach = true, north, west, reach
		placed.sin, placed.cos, placed.radius = sin, cos, radius
		if miniKept then Gleam(miniSheet, GetTime(), 1) end
		return
	end
	if not mini.fresh and placed.on == on and not on then return end
	-- A new choice of ground: the rim's arcs are of that ground, so the kept ones are dropped.
	if mini.fresh then placed.rimKey, placed.rimBands = nil, nil end
	mini.fresh = false
	placed.on, placed.north, placed.west, placed.reach, placed.radius = on, north, west, reach, radius
	placed.sin, placed.cos, placed.square, placed.rim = sin, cos, square, rim
	shot.ok = on and true or false
	shot.held = nil
	shot.gen = (shot.gen or 0) + 1
	shot.north, shot.west, shot.reach, shot.radius = north, west, reach, radius
	shot.sin, shot.cos, shot.square, shot.rim, shot.continent = sin, cos, square, rim, continent
	if placed.plate then placed.plate:SetPoint("CENTER", placed.clip, "CENTER", 0, 0) end
	wipe(rimLines)
	miniSheet.used, miniSheet.dots.used = 0, 0
	miniShown.n, miniShown.size = 0, on and radius > 0 and DRAW.miniSpot / radius or 0
	miniDots.n, miniDots.size = 0, on and radius > 0 and DRAW.miniDot / radius or 0
	-- (The fill: what it was is put away now; the new one is laid over the next frames, below.)
	Begin(miniSheet.fill)
	Finish(miniSheet.fill)
	placed.job = nil
	Begin(miniSheet.edge, miniSheet.glow, miniSheet.gleam, miniSheet.rimEdge, miniSheet.rimGlow)
	if on then
		local per = radius / reach
		-- To the minimap's units: east and up of the player as fractions of its range, turned with it.
		local function At(north_, west_)
			local east, up = -(west_ - west) / reach, (north_ - north) / reach
			return east * cos + up * sin, -east * sin + up * cos
		end
		-- The fill: the rows of the ground (a row runs north to south at one `west`, DRAW.miniFillRow high
		-- on screen), each from outline to outline. Drawn for the view plus a short walk past it: the
		-- plate carries that, and it is drawn again once the walk is used up. A whole zone's worth of
		-- rows is what made a turn hitch.
		local pitch = DRAW.miniFillRow / per
		local cover = reach + placed.cover
		local hold = placed.plate
		local n0, n1 = north - cover, north + cover
		-- The fill is laid over the next frames, MINI_JOB pieces a frame (placed.RunJob): one frame
		-- laying every row of a new area was the hitch as the lead changed. The outline is laid now.
		local fills = {}
		for i, fill in ipairs(mini.fills) do fills[i] = fill end
		placed.job = { fills = fills, fi = 1, At = At, pitch = pitch, cover = cover, west = west, n0 = n0, n1 = n1,
			radius = radius, hold = hold }
		placed.RunJob()
		local reach2 = cover * cover
		for _, loop in ipairs(mini.loops) do
			local n = loop.n
			local color = KIND[loop.kind].color
			for i = 1, n do mx[i], my[i] = At(loop[i * 2 - 1], loop[i * 2]) end
			local run = 0
			for i = 1, n do
				local k = i % n + 1
				local nA, wA, nB, wB = loop[i * 2 - 1], loop[i * 2], loop[k * 2 - 1], loop[k * 2]
				local dn, dw = nB - nA, wB - wA
				local len = dn * dn + dw * dw
				local t = len > 0 and ((north - nA) * dn + (west - wA) * dw) / len or 0
				if t < 0 then t = 0 elseif t > 1 then t = 1 end
				local cn, cw = nA + dn * t, wA + dw * t
				if (cn - north) ^ 2 + (cw - west) ^ 2 <= reach2 then
					local ax, ay, bx, by_ = mx[i], my[i], mx[k], my[k]
					local length = math.sqrt((bx - ax) ^ 2 + (by_ - ay) ^ 2)
					-- (No glow under the edge on the minimap: a stroke fewer for each piece of every outline.)
					Stroke(miniSheet.edge, placed.plate, "CENTER", false, ax * radius, ay * radius, bx * radius, by_ * radius, DRAW.miniEdge, color, 1)
					if miniKept then
						local line = Stroke(miniSheet.gleam, placed.plate, "CENTER", false, ax * radius, ay * radius, bx * radius, by_ * radius,
							DRAW.gleamWide * 0.8, WHITE, 0)
						line.run = (run + length / 2) * radius
					end
					run = run + length
				end
			end
			if miniKept then
				for i = 1, miniSheet.gleam.used do
					if not miniSheet.gleam[i].total then miniSheet.gleam[i].total = run * radius end
				end
			end
		end
		if rim and #mini.fills > 0 and miniSheet.rimEdge then
			local started = debugprofilestop()
			local qn = math.floor(north * 4 + 0.5)
			local qw = math.floor(west * 4 + 0.5)
			local qr = math.floor(reach * 2 + 0.5)
			local qs = math.floor(sin * 200 + 0.5)
			local qc = math.floor(cos * 200 + 0.5)
			local rimKey = qn .. ":" .. qw .. ":" .. qr .. ":" .. qs .. ":" .. qc .. ":" .. (square and 1 or 0)
			if placed.rimKey ~= rimKey or not placed.rimBands then
				placed.rimKey, placed.rimBands = rimKey, Ground.Rims(mini.fills, north, west, reach, sin, cos, square)
			end
			Ground.LayRims(placed.rimBands, radius, square)
			placed.rimUp = #rimLines > 0
			placed.rimFrame:SetShown(placed.rimUp)
			Shy.Clock("minimap rim"):Lap(debugprofilestop() - started)
		elseif placed.rimFrame then
			placed.rimUp = false
			placed.rimFrame:Hide()
		end
		-- The dots, under the pointers, fading out at the rim as they do.
		local dots = mini.dots
		for i = 1, dots.n do
			local x, y = At(dots.north[i], dots.west[i])
			local out = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
			local show = math.max(0, math.min(1, (0.96 - out) / 0.08))
			if show > 0 then
				Dot(miniSheet.dots, x * radius, y * radius, dots.kind[i], show, placed.plate, "CENTER", nil, dots.shade[i])
				Put(miniDots, x, y, dots, i)
			end
		end
		for i = 1, mini.n do
			local east, up = -(mini.west[i] - west) / reach, (mini.north[i] - north) / reach
			local x, y = east * cos + up * sin, -east * sin + up * cos
			local out = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
			local show = math.max(0, math.min(1, (0.96 - out) / 0.08))
			if show > 0 then
				local yards = math.sqrt(x * x + y * y) * reach
				local fade = yards < DRAW.miniNear and (DRAW.miniNearAlpha + (1 - DRAW.miniNearAlpha) * yards / DRAW.miniNear) or 1
				Spot(Light(miniSheet), placed.plate, "CENTER", x * radius, y * radius, mini.kind[i], DRAW.miniSpot, show * fade, mini.row[i] and mini.row[i].shade)
				Put(miniShown, x, y, mini, i)
			end
		end
		if miniKept then
			for i = 1, miniSheet.gleam.used do miniSheet.gleam[i].total = miniSheet.gleam[i].total or 0 end
			Gleam(miniSheet, GetTime(), 1)
		end
		local function KeepBase(shown)
			local base = shown.base or { x = {}, y = {} }
			shown.base = base
			for i = 1, shown.n do base.x[i], base.y[i] = shown.x[i], shown.y[i] end
		end
		KeepBase(miniShown)
		KeepBase(miniDots)
		-- (Drawn again: the next slide is made, whatever it was made for before.)
		placed.slid, placed.unslid = nil, nil
	elseif placed.rimFrame then
		placed.rimUp = false
		placed.rimFrame:Hide()
	end
	Finish(miniSheet.edge, miniSheet.glow, miniSheet.gleam, miniSheet.rimEdge, miniSheet.rimGlow)
	Douse(miniSheet)
	DouseDots(miniSheet.dots)
end

function Ground.OnMini()
	return mini.n > 0 or mini.dots.n > 0 or #mini.loops > 0
end

-- What the minimap's ground at a point of the minimap is for (Kinds, as Ground.Under). x, y: from the
-- minimap's middle as shares of its range, y up, as the ground was last placed there (PlaceMini).
function Ground.UnderMini(x, y)
	if not placed.on or not mini.rows then return nil end
	placed.Hit()
	-- Back from the minimap to the world: PlaceMini's turn undone.
	local east, up = x * placed.cos - y * placed.sin, x * placed.sin + y * placed.cos
	local north, west = placed.north + up * placed.reach, placed.west - east * placed.reach
	return Kinds(mini.rows, function(kind)
		for _, fill in ipairs(mini.fills) do
			if fill.kind == kind and Covers(fill.loops, north, west) then return true end
		end
		return Pointed(miniShown, kind, x, y, 1)
	end)
end

-- The spawn under a point of the minimap (SpawnIn), x, y as for Ground.UnderMini.
function Ground.SpawnAtMini(x, y)
	if not placed.on then return nil end
	placed.Hit()
	return SpawnIn(miniShown, miniDots, x, y, 1, miniContinent)
end

-- The ground is drawn once, in world yards, on placed.plate. Walking moves the plate; the minimap clips it.
-- It is drawn again when the ground, the zoom or the facing changes, not when the player steps.
function Ground.SetupMini()
	local level = Minimap:GetFrameLevel() + 1
	local clip = CreateFrame("Frame", nil, Minimap)
	placed.clip = clip
	clip:SetAllPoints()
	clip:SetFrameLevel(level)
	clip:SetClipsChildren(true)
	local plate = CreateFrame("Frame", nil, clip)
	placed.plate = plate
	plate:SetSize(1, 1)
	plate:SetPoint("CENTER")
	plate:SetFrameLevel(level)
	-- The fill's frame is what is faint, as on the world map.
	local tint = CreateFrame("Frame", nil, clip)
	tint:SetAllPoints()
	tint:SetFrameLevel(level)
	tint:SetAlpha(DRAW.miniFillAlpha)
	miniSheet = Sheet(clip, level)
	miniSheet.fill = Lines(tint, "BACKGROUND", -1, SOLID, true)
	miniSheet.glow = Lines(miniSheet, "BACKGROUND", 0, GLOW_ART, true)
	miniSheet.edge = Lines(miniSheet, "BORDER", 1, EDGE_ART, true)
	miniSheet.gleam = Lines(miniSheet, "BORDER", 2, DASH, true)
	-- The rim is its own frame on the minimap, not on the sliding plate. Hiding the frame takes every
	-- arc with it the moment the player steps (Slide).
	local rim = CreateFrame("Frame", nil, clip)
	placed.rimFrame = rim
	placed.rimUp = rim:IsShown()
	rim:SetAllPoints()
	rim:SetFrameLevel(level)
	rim:Hide()
	miniSheet.rimGlow = Lines(rim, "BACKGROUND", 0, GLOW_ART, true)
	miniSheet.rimEdge = Lines(rim, "BORDER", 1, EDGE_ART, true)
	miniSheet.dots = { used = 0, sheet = miniSheet }
end

-- What the game itself knows of the log's quest areas, as text: the game's own area data per quest,
-- its area pin on the world map, and whether a frame of ours can draw such an area.
local function Try(fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil, "error: " .. tostring(a)
end

function Ground.Report()
	local out = {}
	local function Say(line, ...)
		out[#out + 1] = select("#", ...) > 0 and line:format(...) or line
	end
	local map = W.map
	Say("Quest areas the game knows of  (map %s, %s)", tostring(map), date("%Y-%m-%d %H:%M"))
	Say("questPOI: %s   super-tracked quest: %s   quest POI map: %s   blob border %s", tostring(C_CVar.GetCVarBool("questPOI")),
		tostring(C_SuperTrack.GetSuperTrackedQuestID()), tostring(C_QuestLog.GetMapForQuestPOIs()), tostring(BLOB.scalar))
	Say("areas sampled %d across; the frame itself only where sampling fails", BLOB.sample)
	local counted = rawget(_G, "GetQuestPOIBlobCount")
	Say("GetQuestPOIBlobCount: %s", counted and "exists" or "missing")
	local onMap = {}
	for _, each in ipairs(map and C_QuestLog.GetQuestsOnMap(map) or {}) do
		if each.questID then onMap[each.questID] = each end
	end
	Say("")
	Say("Log (%d quests): id, blobs, inside, waypoint, on this map", #L.order)
	for _, entry in ipairs(L.order) do
		local id = entry.id
		local count = counted and Try(counted, id)
		local inside = Try(C_Minimap.IsInsideQuestBlob, id)
		local wmap, wx, wy = Try(C_QuestLog.GetNextWaypoint, id)
		local here = onMap[id]
		local asked = map and sampled[map] and sampled[map][id]
		local state = "-"
		if asked and asked.n then
			state = asked.n .. " points"
		elseif asked and asked.asking then
			state = "being asked"
		elseif asked and asked.miss then
			state = ("missed %d times, %s"):format(asked.misses or 1, asked.due and "asked again at the next draw"
				or ("asked again in %d s"):format(math.max(0, math.ceil(asked.wait - (GetTime() - asked.miss)))))
		elseif count and type(count) == "number" and count > 0 then
			state = "not asked yet"
		end
		Say("  %d %s: blobs %s, sampled %s, inside %s, waypoint %s, here %s", id, entry.title or "?", tostring(count), state, tostring(inside),
			wmap and ("%s %.3f %.3f"):format(tostring(wmap), tonumber(wx) or -1, tonumber(wy) or -1) or tostring(wx or "none"),
			here and ("%.3f %.3f obj %s%s"):format(here.x or -1, here.y or -1, tostring(here.numObjectives), here.inProgress and " in progress" or "") or "no")
	end
	Say("")
	local kinds = {}
	for _, fill in ipairs(mini.fills) do kinds[#kinds + 1] = fill.kind end
	Say("Minimap: %d grounds%s, %d pointers%s", #mini.fills, #kinds > 0 and (" (" .. table.concat(kinds, ", ") .. ")") or "", mini.n,
		mini.why and (", nothing drawn: " .. mini.why) or "")
	Say("")
	local pins = 0
	if WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate then
		for pin in WorldMapFrame:EnumeratePinsByTemplate("QuestBlobPinTemplate") do
			pins = pins + 1
			Say("The game's area pin: shown %s, quest %s, blobs allowed on this map %s", tostring(pin:IsShown()), tostring(pin.questID),
				tostring(pin.mapAllowsBlobs))
		end
	end
	if pins == 0 then Say("The game's area pin: none on the world map (open it once and run this again)") end
	Say("Our area frames: %d made, %d shown", #blobs, (function()
		local shown = 0
		for _, frame in ipairs(blobs) do
			if frame:IsShown() then shown = shown + 1 end
		end
		return shown
	end)())
	return table.concat(out, "\n")
end

-- The task manager: what emptying each of the ground's caches frees (each fills again as it is used) and
-- how big each is; the jobs waiting and the last that failed, as counters.
if Shy.Memory and Shy.Counters then
Shy.Memory.Cache("Quest ground: outlines traced", function()
	if jobs[1] then return end
	wipe(traced)
	wipe(tracedAt)
	tracedAt.clock, tracedCount = 0, 0
end, function() return tracedCount end)
Shy.Memory.Cache("Quest ground: shapes", function()
	wipe(shaped)
	shapes = 0
end, function() return shapes end)
Shy.Memory.Cache("Quest ground: areas read off the game's map", function() wipe(sampled) end, function()
	local n = 0
	for _ in pairs(sampled) do n = n + 1 end
	return n
end)
Shy.Counters("Ground jobs", function(row)
	row("Jobs waiting", #jobs, "idle")
	row("Outlines kept", tracedCount, "of", MOST_TRACED)
	row("Last job error", failed or "none")
end, { idle = true, reset = function() failed = nil end })
end
