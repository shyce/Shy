-- The route: an ordered list of stops (R.stops) that the card, arrow and map pins all read.
-- A stop is a turn-in, a pickup or the nearest place to work on a quest, ordered nearest-first.
-- A singled-out quest leads; a followed guide's live steps lead as kind "guide"; other kinds are
-- "zone" (suggestions when little is in reach), "fly" (a ride on the way: a flight, a boat, a zeppelin, the
-- tram or a portal, WithJourneys)
-- and "errand" (R.AddErrand).
-- Positions of quests in the log come from the client where it knows them; the data fills in the rest.

local ADDON, ns = ...
local T = ns.T
local D, W, L, Z, G = ns.Data, ns.World, ns.Log, ns.Zones, ns.Guide

local R = {}
ns.Route = R

R.stops = {}
R.offered = {}               -- catch-up steps that are off the way: stops, but not on the route (GuideStops)
-- Why an earlier guide step is offered again (Guide.lua, Catchup), for the card and tooltips.
ns.CATCH_WHY = {
	carried = "Optional: you passed this one earlier.",
	ahead = "Optional: a later step needs it.",
	easy = "Optional: close by and worth it.",
	dungeon = "For a dungeon you can run now.",
}
local UNITS = 10000
-- What goes before the guide's own step, and when the order holds (yards, unless said).
local RULES = {
	atHand = 4,  -- with fewer steps than this in reach, suggest zones
	handInReach = 1500,  -- yards: a turn-in this near goes before a guide's grind
	handInNear = 600,  -- ... and this near before a guide step with no position
	workReach = 200,  -- an objective this near goes before the guide's step
	ownReach = 150,  -- a class quest this near is picked up before the guide's step
	onTheWay = 300,  -- yards a stop may add to the walk to the guide's step and still be on the way
	inPassing = 60,  -- ... and an objective the guide has a step for among its next few: only in passing
	stay = 1.3,  -- a stop that led stays first until it is this much farther than the nearest
	atWork = 90,  -- yards: within this of the objective being worked on, it keeps the lead (stops flip-flopping between mixed mobs)
	buyNear = 1000,  -- yards: a vendor this near is where a quest item is bought
	grindReach = 3000,  -- instead of a grind: a quest to pick up, work on or turn in this near
	untangle = 14,  -- stops from the head of the route whose order is straightened out
	ownHere = 40,  -- yards: an errand this near is done before your own route's first stop (YourWay)
	ownWay = 60,  -- ... and one that adds no more than this to the walk to it
	above = 2,  -- ... when it is no more than this many levels above the player
}

-- The singled-out quest

-- The client super-tracks every newly accepted quest on its own, and keeps that across a reload,
-- so the player's choice is stored when made (ns.char.singled) and never read off the arrow.
local AUTO = 1               -- seconds within which super-tracking after an accept counts as the client's
local took, pointed = {}, {} -- quest -> when it was accepted, and when it was last super-tracked
local ours = {}              -- quest -> when we restored super-tracking to it (R.Repoint)
local quiet                  -- quest super-tracked only to show the way (R.Go): not a choice
local lost, lostAt           -- the choice in force when super-tracking was last cleared, and when

function R.Heard(event, id)
	if event == "QUEST_ACCEPTED" then
		took[id] = GetTime()
		-- SUPER_TRACKING_CHANGED can arrive before QUEST_ACCEPTED.
		if ns.char.singled == id and pointed[id] and took[id] - pointed[id] <= AUTO then ns.char.singled = nil end
	elseif event == "QUEST_REMOVED" then
		took[id], pointed[id], ours[id] = nil, nil, nil
		if quiet == id then quiet = nil end
		if ns.char.singled == id then ns.char.singled = nil end
	elseif event == "SUPER_TRACKING_CHANGED" then
		local quest = C_SuperTrack.GetSuperTrackedQuestID() or 0
		if quest ~= quiet then quiet = nil end
		if quest ~= 0 and ours[quest] and GetTime() - ours[quest] <= AUTO then
			-- Our own restore (R.Repoint): no choice changed.
			ours[quest] = nil
		elseif quest == 0 then
			lost, lostAt = ns.char.singled, GetTime()
			ns.char.singled = nil
		elseif quest == quiet then
			ns.char.singled = nil
		else
			pointed[quest] = GetTime()
			local auto = took[quest] ~= nil and pointed[quest] - took[quest] <= AUTO
			ns.char.singled = not auto and quest or nil
		end
	end
end

-- The quest the player chose to super-track, or 0.
function R.Singled()
	local id = Shy.Waypoint.QuestID()
	if quiet and id ~= quiet then quiet = nil end
	if id ~= 0 and id == ns.char.singled then return id end
	return 0
end

-- A choice made on the card or the map.
local function Choose(id)
	quiet = nil
	ns.char.singled = id
	Shy.Waypoint.Quest(id)
end

-- Restores super-tracking after the watch list was reordered, keeping any choice on it.
function R.Repoint(id)
	if lost == id and GetTime() - lostAt <= AUTO then ns.char.singled = id end
	-- (Marked ours as it is set: in a fight with the map open that waits, Shy.Waypoint.)
	Shy.Waypoint.Quest(id, function() ours[id] = GetTime() end)
end

-- Finding places

-- The nearest usable quest giver or ender.
local function NearestGiver(tokens)
	local best
	for _, token in ipairs(tokens) do
		if token.kind == "n" or token.kind == "o" then
			local thing = D.Thing(token.kind, token.id)
			if thing and (token.kind == "o" or L.Friendly(thing)) then
				-- A patrolling NPC has several places: the key keeps the chosen one steady.
				local map, x, y, yards, dungeon = W.Nearest(thing.places, "who" .. token.kind .. token.id)
				if map and (not best or (yards or math.huge) < (best.yards or math.huge)) then
					best = { thing = thing, kind = token.kind, map = map, x = x, y = y, yards = yards, dungeon = dungeon }
				end
			end
		end
	end
	return best
end

-- Which of a quest's givers or takers (`tokens`) this character goes to: the nearest it can use, else the
-- first it can use (where the nearest can't be told), else the first of any kind (a start item). A quest
-- both sides have lists each side's own person: the other side's is never the one.
function R.Usable(tokens)
	if not tokens then return nil end
	local near = NearestGiver(tokens)
	for _, token in ipairs(tokens) do
		if near and token.kind == near.kind and token.id == near.thing.id then return token end
	end
	for _, token in ipairs(tokens) do
		if token.kind == "o" or token.kind == "n" then
			local thing = D.Thing(token.kind, token.id)
			if thing and (token.kind == "o" or L.Friendly(thing)) then return token end
		end
	end
	for _, token in ipairs(tokens) do
		if token.kind ~= "n" and token.kind ~= "o" then return token end
	end
end

-- Nearest source of an item that starts a quest: { thing, from = "n" drops | "o" holds | "v" sells,
-- item, chance, map, x, y, yards, dungeon }. Only sources that can be counted on (D.Sure): a long-shot
-- drop or a rare spawn is no trip to make, so an item with nothing better is no stop until it drops
-- (L.Carried), and the creature's hover says what it may drop meanwhile.
local function NearestSource(quest)
	local best
	for _, token in ipairs(quest.starts) do
		local start = token.kind == "i" and D.StartItem(token.id)
		local least = start and D.Least(start.sources)
		for _, source in ipairs(start and start.sources or {}) do
			local thing = D.Thing(source.kind, source.id)
			if thing and (source.kind ~= "v" or L.Friendly(thing)) and D.Sure(source, least) then
				local map, x, y, yards, dungeon = W.Nearest(thing.places)
				if map and (not best or (yards or math.huge) < (best.yards or math.huge)) then
					best = { thing = thing, from = source.kind, item = token.id, chance = source.chance,
						map = map, x = x, y = y, yards = yards, dungeon = dungeon }
				end
			end
		end
	end
	return best
end
R.NearestSource = NearestSource

-- Is a quest worth the walk
-- An available quest is a stop only if it isn't far above the player and its XP beats grinding
-- for the time its trip (giver, each objective, ender) takes. Others keep their map pin.

local TRIP = {
	hard = 3,  -- a quest more than this many levels above the player is left for later
	walk = 420,  -- yards a minute, on foot
	long = 5000,  -- yards: too far for a quest of unknown XP
}
local trips = {}             -- quest .. giver -> yards, or false for one that leaves the continent

-- Nearest of `lists` of places to a world point: yards, north, west.
local function From(lists, continent, north, west)
	local least, n, w
	for _, places in ipairs(lists) do
		for _, place in ipairs(places) do
			for i = 1, #place.points, 2 do
				local c, pn, pw = W.ToWorld(place.map, place.points[i], place.points[i + 1])
				if c == continent and pn then
					local yards = W.Between(north, west, pn, pw)
					if not least or yards < least then least, n, w = yards, pn, pw end
				end
			end
		end
	end
	return least, n, w
end

-- Yards a quest takes from its giver; nil when part of it is on another continent.
local GoalPlaces   -- below
local function Trip(quest, giver)
	local key = quest.id .. giver.kind .. giver.thing.id
	local trip = trips[key]
	if trip == nil then
		local continent, north, west = W.ToWorld(giver.map, giver.x, giver.y)
		trip = 0
		for _, token in ipairs(quest.goals) do
			local lists = {}
			GoalPlaces(token, lists)
			if #lists > 0 and trip then
				local yards, n, w = From(lists, continent, north, west)
				if yards then trip, north, west = trip + yards, n, w else trip = false end
			end
		end
		if trip then
			local lists = {}
			for _, token in ipairs(quest.ends) do
				local thing = D.Thing(token.kind, token.id)
				if thing and (token.kind == "o" or L.Friendly(thing)) then lists[#lists + 1] = thing.places end
			end
			local yards = #lists > 0 and From(lists, continent, north, west)
			if #lists > 0 then trip = yards and trip + yards or false end
		end
		trips[key] = trip
	end
	return trip or nil
end

-- XP a minute from grinding, estimated conservatively.
local function Fighting()
	return 45 + 5 * L.Level()
end

-- Returns true, or false, reason, and "level" when the reason is the quest's level.
function R.Worth(quest, giver)
	if quest.level > L.Level() + TRIP.hard then return false, "Level " .. quest.level .. ": too high for now", "level" end
	if not giver then return true end
	local trip = Trip(quest, giver)
	if not trip then return false, "Part of it is on another continent" end
	local pays = L.Pays(quest)
	if not pays then
		if trip > TRIP.long then return false, ("About %s of travel"):format(W.Yards(trip)) end
		return true
	end
	-- A quest that unlocks others is worth it regardless.
	if pays < trip / TRIP.walk * Fighting() and not L.Opens(quest) then
		return false, ("About %s of travel for %d XP"):format(W.Yards(trip), pays)
	end
	return true
end

function R.WorthOffer(quest)
	return R.Worth(quest, NearestGiver(quest.starts))
end

-- Catching up a chain: a quest whose earlier quests aren't done (L.Owed) is worth going back for when those and
-- the quest itself pay at least what fighting would in the time they take. Only a chain that reaches back below
-- the player's level is weighed: one that pays its full XP is the guide's own way on.
local CATCH_MINUTES = 2      -- each quest's talk, fights and hand-in, besides its walk
local catching = { key = nil }

-- XP and minutes a quest takes; nil XP when the data doesn't say.
local function Takes(quest)
	local giver = NearestGiver(quest.starts)
	local trip = giver and Trip(quest, giver) or 0
	return L.Pays(quest), trip / TRIP.walk + CATCH_MINUTES
end

function R.Catching(quest)
	local key = L.ChainsKey()
	if catching.key ~= key then
		catching = { key = key }
	end
	local known = catching[quest.id]
	if known ~= nil then return known end
	local owed, low = L.Owed(quest.id), false
	for _, id in ipairs(owed) do
		local before = D.Quest(id)
		if before and L.Share(before.level) < 1 then low = true end
	end
	local worth = true
	if low then
		local pays, minutes = Takes(quest)
		for _, id in ipairs(owed) do
			local before = D.Quest(id)
			local xp, more = Takes(before)
			if xp == nil or pays == nil then
				pays = nil
				break
			end
			pays, minutes = pays + xp, minutes + more
		end
		-- (XP the data doesn't give: not judged.)
		worth = pays == nil or pays >= minutes * Fighting()
	end
	catching[quest.id] = worth
	return worth
end

-- Appends to `out` each list of places a goal can be worked on. `ground`: actual spawn points
-- (D.Ground) instead, for shading the map. `from`: filled with from[n] = { name, id,
-- how = "kill" | "use" | "sells" | "holds" | "drops" | "gives", quest } for out[n].
-- A creature listed with no drop chance that gives or takes quests hands the item over (a quest's
-- reward, or a word with them): "gives", never something to kill. Where the item is had only as the
-- reward of a quest they take (item.given), `quest` is that quest.
-- `needs`: the list is of an item the quest needs and doesn't count, by its name.
local function RewardOf(item, npc)
	if not item.given then return nil end
	for _, quest in ipairs(item.given) do
		local data = D.Quest(quest)
		if data then
			for _, ender in ipairs(data.ends) do
				if ender.kind == "n" and ender.id == npc then return quest end
			end
		end
	end
	return nil
end

function GoalPlaces(token, out, ground, from)
	local needs
	-- chance: the percent of kills an item drops from, where the data says.
	local function Add(thing, how, chance, quest)
		out[#out + 1] = ground and D.Ground(thing) or thing.places
		if from then from[#out] = { name = thing.name, how = how, id = thing.id, chance = chance, needs = needs, quest = quest } end
	end
	if token.kind == "c" or token.kind == "o" then
		local thing = D.Thing(token.kind, token.id)
		if thing then Add(thing, token.kind == "c" and "kill" or "use") end
	elseif token.kind == "k" then
		for _, id in ipairs(token.ids) do
			local npc = D.Npc(id)
			if npc then Add(npc, "kill") end
		end
	else
		local item = D.Item(token.id)
		if item then
			if token.kind == "s" then needs = item.name end
			-- A dropper the data gives no chance for, where others of the item have one, is taken to drop it as
			-- seldom as the least of those: a guess must not make it the quickest way to the item.
			local least
			for _, source in ipairs(item.sources) do
				if source.chance and (not least or source.chance < least) then least = source.chance end
			end
			-- Every source, not only the best dropper: the nearest one is where to go.
			for _, source in ipairs(item.sources) do
				local thing = D.Thing(source.kind, source.id)
				if thing and (source.kind ~= "v" or L.Friendly(thing)) and not (source.kind == "n" and D.Dropless(source.id, item.id)) then
					local gives = source.kind == "n" and not source.chance and (thing.gives or thing.takes) ~= nil
					local how = source.kind == "v" and "sells" or source.kind == "o" and "holds" or gives and "gives" or "drops"
					Add(thing, how, source.chance or (how == "drops" and least) or nil, gives and RewardOf(item, source.id) or nil)
				end
			end
			for _, id in ipairs(item.more or {}) do
				local npc = not D.Dropless(id, item.id) and D.Npc(id)
				if npc then Add(npc, "drops", least) end
			end
		end
	end
end

-- Areas
-- A thing's spawns stand in areas, as the map circles them: spawns within AREA.link yards of one
-- another are one area. Kills, loot and gathering are done anywhere in an area, so the stop for
-- them stands at the heart of the best camp, not on one spawn picked out of the lot:
--   * a camp is where the spawns are thick (Camps): its heart the spawn with the most others round
--     it, and no two hearts of an area nearer than AREA.camp. A long area (spawns strung along a road)
--     has several, a lone spawn is one of its own. On the game's own area, the camps are of the data's
--     spawns on it, or its middle where it has none;
--   * the best camp is the one where what is asked is had soonest (Takes): the walk there, and where
--     it has fewer than are asked, the wait for them to stand again (beyond what the thickest camp of
--     the same would take: each of a step's tasks is done in the end, so the one quick to do is no
--     reason to go to it first). A lone spawn by the quest giver loses to a camp down the road; one
--     kill left, it wins;
--   * standing on an area's ground (as the map draws it), the work is done there (`among`: the card
--     and the arrow then show that instead of a way), with the thickest of its camps near (AREA.stay)
--     reckoned as where the player is; unless a camp of the same elsewhere costs under half of
--     staying (AREA.leave): one spawn underfoot is no place to wait for ten;
--   * walking from one camp to another, the first is kept until the player is past halfway
--     (AREA.better), so the way does not flip between two that are about as good.
-- Where the game has an area of its own for a quest, that is the ground (Ground.Known).
-- Not everything asked for is ground: an objective found only at exact places (Exact, Pinned: three
-- valves round a console, a wardrobe, a creature with a name) is a spot to be led to, to the yard,
-- like someone to talk to. Its stop never says the thing is "here" and puts the arrow away, and the
-- game's area doesn't stand in for it.
local AREA = { link = 300,   -- yards: spawns this near one another are one area
	radius = 40,             -- yards: a spawn's ground reaches this far round it (Ground.lua's RADIUS)
	better = 0.85,           -- another camp wins once it saves (1 - this) of the way to the kept one
	heart = 120,             -- yards: the spawns this near one count toward how thick the work is round it
	camp = 150,              -- yards: a camp is worked this far round its heart, and hearts stand this far apart
	respawn = 300,           -- seconds before a spawn killed or picked stands again
	stride = 7,              -- yards a second on foot: what a second's work is worth in walking
	stay = 450,              -- yards: standing on an area's ground, its camps this near are where the player is
	leave = 0.5,             -- ... and a camp of the same elsewhere leads once it costs under this share of staying
	walked = 3 }             -- the cheapest camps whose way over the ground is asked for (W.Walked)
-- (Seconds a kill takes, and a thing used, picked up or bought; kills an item is reckoned at, at most.
-- What work takes, below, reckons with the same.)
-- What a goal costs: seconds, and how many of a thing.
local EFFORT = {
	fight = 45,
	handle = 20,
	most = 40,
	-- What work takes
	-- Seconds to do what an objective asks, for whoever weighs time ahead (Hearth.lua): how many are
	-- still needed; a kill at EFFORT.fight seconds, a thing used or picked up at EFFORT.handle; the way from one
	-- to the next, which is how far apart the spawns stand, EFFORT.crowd times as long because others are
	-- after the same ones; and for an item that drops, as many kills as its chance asks for, EFFORT.most
	-- at most (EFFORT.fight, EFFORT.handle and EFFORT.most stand with the areas, above). The quickest of an objective's
	-- sources is the one reckoned with.
	crowd = 1.5,  -- times as long to find the next one, with other players about
	asked = 8,  -- how many a quest not in the log is taken to ask of each (one of a creature that stands alone)
	stride = 7,  -- yards a second on foot
	apart = 300,  -- yards from one spawn to the next, at most: farther is another place
}

-- What getting `left` of what a list's spawns give asks for: { need = how many of them, each = seconds
-- a one }. As many as are left; for an item that drops, as many kills as its chance asks for.
local function Asks(how, chance, left)
	local need = math.max(1, left or 1)
	if how == "drops" then need = math.min(EFFORT.most, need / (math.max(1, chance or 100) / 100)) end
	return { need = need, each = (how == "kill" or how == "drops" or how == "loot") and EFFORT.fight or EFFORT.handle }
end

-- Seconds to get `need` from a camp of `supply` spawns at `each` seconds a one: the camp once over,
-- then each as it stands again, or as fast as they fall where that is slower.
local function Takes(supply, need, each)
	supply = math.max(1, supply)
	if need <= supply then return need * each end
	return supply * each + (need - supply) * math.max(each, AREA.respawn / supply)
end
local areaSets = setmetatable({}, { __mode = "k" })   -- a thing's spawns -> their areas, on areasOn
local areasOn                -- the continent those are on
local stood, standing = {}, 0   -- by key: the choice kept ({ ground, area, spot }), and how many

-- A thing's spawns on the player's continent, in areas: .n of them (north, west, map, x, y), .area[i]
-- the area spawn i is in, .areas how many areas, .radius how far a spawn's ground reaches.
--   on: a continent to build them on instead (kept by no one: R.CampsOf).
local function Areas(ground, on)
	if not on then
		if areasOn ~= W.continent then
			wipe(areaSets)
			areasOn = W.continent
		end
		local set = areaSets[ground]
		if set then return set end
	end
	local set = { n = 0, north = {}, west = {}, map = {}, x = {}, y = {}, area = {}, areas = 0, radius = ground.radius or AREA.radius }
	for _, place in ipairs(ground) do
		local points = place.points
		for i = 1, place.dungeon and 0 or #points, 2 do
			local continent, north, west = W.ToWorld(place.map, points[i], points[i + 1])
			if north and continent == (on or areasOn) then
				local n = set.n + 1
				set.n = n
				set.north[n], set.west[n], set.map[n], set.x[n], set.y[n] = north, west, place.map, points[i], points[i + 1]
			end
		end
	end
	-- Joined through squares a link wide: a spawn looks at its own square and the eight round it.
	local link = math.max(AREA.link, set.radius * 3)
	local parent, squares = {}, {}
	local function Root(i)
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	for i = 1, set.n do
		parent[i] = i
		local north, west = set.north[i], set.west[i]
		local column, row = math.floor(north / link), math.floor(west / link)
		for c = column - 1, column + 1 do
			for r = row - 1, row + 1 do
				local square = squares[c * 100000 + r]
				for k = 1, square and #square or 0 do
					local other = square[k]
					if (set.north[other] - north) ^ 2 + (set.west[other] - west) ^ 2 <= link * link then parent[Root(other)] = Root(i) end
				end
			end
		end
		local own = squares[column * 100000 + row]
		if not own then
			own = {}
			squares[column * 100000 + row] = own
		end
		own[#own + 1] = i
	end
	local named = {}
	for i = 1, set.n do
		local root = Root(i)
		if not named[root] then
			set.areas = set.areas + 1
			named[root] = set.areas
		end
		set.area[i] = named[root]
	end
	if not on then areaSets[ground] = set end
	return set
end

-- Whether the data has spawns of a thing on the player's continent. Where it has, they are the ground:
-- the game's own area for a quest is a rough shape round them, often far wider than where anything
-- stands, and stands in only for what the data knows no spawns of (Ground.lua's Prepare does the same).
local function Spawned(ground)
	return ground ~= nil and Areas(ground).n > 0
end

-- Whether a place is on an area's ground: within a radius of one of its spawns, as the map's outline
-- runs (Ground.lua, "Outlines").
local function OnGround(set, area, north, west)
	local reach = set.radius ^ 2
	for i = 1, set.n do
		if set.area[i] == area and (set.north[i] - north) ^ 2 + (set.west[i] - west) ^ 2 <= reach then return true end
	end
	return false
end

-- The area of `set` whose ground a place is on (that of its nearest spawn within a radius), or nil.
-- Looks only at the spawns in reach, through squares a radius wide (set.squares, made once).
local function AreaAt(set, north, west)
	local reach = set.radius
	local squares = set.squares
	if not squares then
		squares = {}
		for i = 1, set.n do
			local cell = math.floor(set.north[i] / reach) * 100000 + math.floor(set.west[i] / reach)
			local list = squares[cell]
			if not list then
				list = {}
				squares[cell] = list
			end
			list[#list + 1] = i
		end
		set.squares = squares
	end
	local column, row = math.floor(north / reach), math.floor(west / reach)
	local least, best = reach * reach, nil
	for c = column - 1, column + 1 do
		for r = row - 1, row + 1 do
			for _, i in ipairs(squares[c * 100000 + r] or {}) do
				local apart = (set.north[i] - north) ^ 2 + (set.west[i] - west) ^ 2
				if apart <= least then least, best = apart, set.area[i] end
			end
		end
	end
	return best
end

-- Where the work is thick on a set's ground: its camps, a list of { map, x, y, north, west, area, dense,
-- supply, members, middle }, with camps.Count(area, north, west): how many of its spawns stand within
-- AREA.camp of a place. A camp's heart is its spawn with the most others round it (dense: each within
-- AREA.heart yards counting less the farther it is; alone, 1), taken densest first, and none within
-- AREA.camp of another of its area's; supply is how many stand within AREA.camp of the heart, members
-- the set's spawns that are the camp's ground (those within AREA.camp; on the game's own area, all of it).
--   inner: other spawn lists that say where on the ground the work is (on the game's own area, the
--   data's spawns of what it asks for): the camps are then of those on the area, and an area with
--   none of them on it has its middle for its one camp, as thin as one spawn.
-- Worked out once for each set and inner.
local function Camps(set, inner)
	local key = ""
	for _, ground in ipairs(inner or {}) do key = key .. tostring(ground) end
	set.camps = set.camps or {}
	local made = set.camps[key]
	if made then return made end
	-- The candidates, each with the area it is on.
	local c = { n = 0, north = {}, west = {}, map = {}, x = {}, y = {}, area = {} }
	local function Take(from, i, area)
		local n = c.n + 1
		c.n = n
		c.north[n], c.west[n], c.map[n], c.x[n], c.y[n], c.area[n] = from.north[i], from.west[i], from.map[i], from.x[i], from.y[i], area
	end
	if key ~= "" then
		for _, ground in ipairs(inner) do
			local from = Areas(ground)
			for i = 1, from.n do
				local area = AreaAt(set, from.north[i], from.west[i])
				if area then Take(from, i, area) end
			end
		end
	else
		for i = 1, set.n do Take(set, i, set.area[i]) end
	end
	-- The candidates through squares `reach` wide; Round calls back with each of an area's within reach.
	local function Squares(reach)
		local squares = {}
		for i = 1, c.n do
			local cell = math.floor(c.north[i] / reach) * 100000 + math.floor(c.west[i] / reach)
			local list = squares[cell]
			if not list then
				list = {}
				squares[cell] = list
			end
			list[#list + 1] = i
		end
		return squares
	end
	local function Round(squares, reach, area, north, west, Each)
		local column, row = math.floor(north / reach), math.floor(west / reach)
		for cc = column - 1, column + 1 do
			for r = row - 1, row + 1 do
				for _, k in ipairs(squares[cc * 100000 + r] or {}) do
					local apart = (c.north[k] - north) ^ 2 + (c.west[k] - west) ^ 2
					if c.area[k] == area and apart <= reach * reach then Each(k, apart) end
				end
			end
		end
	end
	-- How dense each is: its neighbours on the same area.
	local heart = AREA.heart
	local near = Squares(heart)
	local dense, order = {}, {}
	for i = 1, c.n do
		local thick = 0
		Round(near, heart, c.area[i], c.north[i], c.west[i], function(_, apart) thick = thick + (1 - apart / (heart * heart)) ^ 2 end)
		dense[i], order[i] = thick, i
	end
	-- The hearts, densest first: each one a camp unless a camp of its area already stands that near.
	table.sort(order, function(a, b)
		if dense[a] ~= dense[b] then return dense[a] > dense[b] end
		return a < b
	end)
	local camp = AREA.camp
	local wide = Squares(camp)
	local taken = {}             -- by candidate: a camp's heart stands within AREA.camp of it
	made = {}
	for _, i in ipairs(order) do
		if not taken[i] then
			local one = { map = c.map[i], x = c.x[i], y = c.y[i], north = c.north[i], west = c.west[i], area = c.area[i], dense = dense[i],
				supply = 0, members = {} }
			Round(wide, camp, one.area, one.north, one.west, function(k)
				taken[k] = true
				one.supply = one.supply + 1
				one.members[#one.members + 1] = k
			end)
			made[#made + 1] = one
		end
	end
	if key ~= "" then
		-- On the game's own area its whole ground is each camp's, and an area with nothing on it has
		-- the spawn of its own nearest its middle.
		local whole, has = {}, {}
		for _, one in ipairs(made) do has[one.area] = true end
		local sumN, sumW = {}, {}
		for i = 1, set.n do
			local area = set.area[i]
			whole[area] = whole[area] or {}
			whole[area][#whole[area] + 1] = i
			sumN[area], sumW[area] = (sumN[area] or 0) + set.north[i], (sumW[area] or 0) + set.west[i]
		end
		for _, one in ipairs(made) do one.members = whole[one.area] end
		for area = 1, set.areas do
			if not has[area] and whole[area] then
				local count = #whole[area]
				local best, least
				for _, i in ipairs(whole[area]) do
					local apart = (set.north[i] - sumN[area] / count) ^ 2 + (set.west[i] - sumW[area] / count) ^ 2
					if not least or apart < least then best, least = i, apart end
				end
				made[#made + 1] = { map = set.map[best], x = set.x[best], y = set.y[best], north = set.north[best], west = set.west[best],
					area = area, dense = 1, supply = 1, members = whole[area], middle = true }
			end
		end
	end
	made.most = 1                -- the most any camp of the set has
	for _, one in ipairs(made) do made.most = math.max(made.most, one.supply) end
	function made.Count(area, north, west)
		local count = 0
		Round(wide, camp, area, north, west, function() count = count + 1 end)
		return count
	end
	set.camps[key] = made
	return made
end

-- How many of a set's spawns are worked from a place on its ground: those round it, or the thickest
-- of its camps near it (AREA.stay: all one ground, gone about without being led). 0 off its ground.
--   area: the area whose ground it is, where known.
local function Supply(set, camps, north, west, area)
	area = area or AreaAt(set, north, west)
	if not area then return 0 end
	local most = camps.Count(area, north, west)
	for _, camp in ipairs(camps) do
		if camp.area == area and (camp.north - north) ^ 2 + (camp.west - west) ^ 2 <= AREA.stay ^ 2 then most = math.max(most, camp.supply) end
	end
	return most
end

-- How long what a list's spawns give takes at its thickest camp (Takes), in seconds: nil with none of its
-- spawns on this continent. Several lists that give one thing (creatures that drop one item) are weighed by
-- it against one another: a common creature dropping it 1 in 20 beats a nearer one dropping it 1 in 100,
-- and a lone rare (one camp of one, the wait for it to stand again each time) beats a camp only when it
-- really is quicker.
--   Yields(lists, solid, inner, asks, groups): by list, the yards (as walking) its work takes over the best
--   of its group's (groups: by list, what it gives; lists with none, and anything not ground, are 0).
local function Base(ground, inner, ask)
	local set = Areas(ground)
	if set.n == 0 then return nil end
	ask = ask or Asks()
	return Takes(Camps(set, inner).most, ask.need, ask.each)
end
local function Yields(lists, solid, inner, asks, groups)
	local extra = {}
	if not groups then return extra end
	local bases, best = {}, {}
	for index, ground in ipairs(lists) do
		local group = groups[index]
		if group ~= nil and solid[index] then
			local base = Base(ground, inner and inner[index], asks and asks[index])
			bases[index] = base
			if base and (not best[group] or base < best[group]) then best[group] = base end
		end
	end
	for index, base in pairs(bases) do extra[index] = (base - best[groups[index]]) * AREA.stride end
	return extra
end

-- Where to stand a stop for what is found at any of `lists` (each a thing's spawns, as D.Ground has
-- them): { map, x, y, yards, list = which of them, among = the work is done where the player stands,
-- on = the player stands on the ground of the area it is in, areas = how many areas there are to
-- choose from, set, area }. nil with none of them on this continent.
-- Ground is stood on at the best camp's heart (Camps, Takes); someone or somewhere at the nearest spot.
--   key: what the choice is kept under.
--   solid: by list, true where its spawns are ground to stand on (kills, loot, gathering). The others
--   are people and places: a spot each, never stood "in", and gone to once nearer than any ground.
--   inner: by list, the spawn lists that say where on that ground the work is (Camps), if any.
--   asks: by list, what getting the rest of it asks for (Asks); one of them where it doesn't say.
--   groups: by list, what it gives (an objective): lists that give one thing are weighed by how long each
--   takes (Yields), not by the walk alone; others are each done in the end, so only the walk counts.
-- (Every camp of every list is weighed at each build, some hundreds for a full log: each is written into a
-- table kept for it, AREA.weighed, not a new one. Nothing of one outlasts the call but what Stand copies out.)
AREA.weighed, AREA.spare = {}, {}
local function Stand(lists, key, solid, inner, asks, groups)
	if not W.Known() then return nil end
	local north, west = W.north, W.west
	local hold = stood[key]
	local extra = Yields(lists, solid, inner, asks, groups)
	local all = AREA.weighed     -- of the ground: each camp as it would be gone to, and what it costs
	local spare = AREA.spare
	for index = #all, 1, -1 do
		spare[#spare + 1], all[index] = all[index], nil
	end
	local near, kept, here       -- the best camp, the kept one, and working where the player stands
	local point, wasPoint        -- the nearest spot of the others, and whether a spot was the choice kept
	local areas = 0
	local on = {}                -- the lists with ground the player stands on, by list and in order
	local priced = {}            -- by list of ground: what working at a place costs over its thickest camp, in yards
	for index, ground in ipairs(lists) do
		local set = Areas(ground)
		local reach = set.radius ^ 2  -- (on an area's ground: within this of its nearest spawn)
		local spot, far, apart = {}, {}, {}
		for i = 1, set.n do
			local area = set.area[i]
			apart[i] = (set.north[i] - north) ^ 2 + (set.west[i] - west) ^ 2
			if not far[area] or apart[i] < far[area] then spot[area], far[area] = i, apart[i] end
		end
		local camps = solid[index] and Camps(set, inner and inner[index])
		if camps then
			-- What a camp costs over the best of them: the time its work takes beyond what the thickest
			-- camp's would, as yards of walking. Each of a step's tasks is done somewhere in the end, so
			-- the one quick to do is no reason to go to it first: only the walk and the waiting are.
			local ask = asks and asks[index] or Asks()
			local base = Takes(camps.most, ask.need, ask.each)
			local function Over(supply) return (Takes(supply, ask.need, ask.each) - base) * AREA.stride end
			priced[index] = function(at, atWest) return Over(Supply(set, camps, at, atWest)) end
			local best = {}          -- by area: its cheapest camp
			areas = areas + set.areas
			for _, camp in ipairs(camps) do
				-- The stop stands at the heart; how far it is is how far its ground is (the camp's nearest
				-- spawn), where the work begins.
				local first
				for _, i in ipairs(camp.members) do
					if not first or apart[i] < apart[first] then first = i end
				end
				local area = camp.area
				local each = spare[#spare] or { solid = true }
				spare[#spare] = nil
				each.list, each.ground, each.set, each.area, each.camp = index, ground, set, area, camp
				each.map, each.x, each.y, each.yards = camp.map, camp.x, camp.y, math.sqrt(apart[first])
				each.entryNorth, each.entryWest, each.on = set.north[first], set.west[first], far[area] <= reach
				each.cost = each.yards + Over(camp.supply) + (extra[index] or 0)
				all[#all + 1] = each
				if not best[area] or each.cost < best[area].cost then best[area] = each end
				if hold and hold.ground == ground and hold.camp == camp then kept = each end
			end
			-- Working where the player stands, with no walk: on the thickest camp of the ground stood on
			-- that is near (AREA.stay: it is all one ground, gone about without being led), or on what is
			-- round them. A camp far along a long area is somewhere to be led to. The area the kept camp
			-- is in before any other.
			local at = {}            -- by area: the thickest camp the player is at
			for _, each in ipairs(all) do
				local camp = each.camp
				if each.list == index and each.on and (camp.north - north) ^ 2 + (camp.west - west) ^ 2 <= AREA.stay ^ 2
					and (not at[each.area] or camp.supply > at[each.area].camp.supply) then
					at[each.area] = each
				end
			end
			for area = 1, set.areas do
				if best[area] and best[area].on then
					if not on[index] then
						on[index] = true
						on[#on + 1] = index
					end
					local cost = Over(Supply(set, camps, north, west, area)) + (extra[index] or 0)
					local mine = kept ~= nil and kept.ground == ground and kept.area == area
					if not here or (mine and not here.mine) or (mine == here.mine and cost < here.cost) then
						here = { at = (mine and kept) or at[area] or best[area], cost = cost, mine = mine, yards = math.sqrt(far[area]),
							entry = { north = set.north[spot[area]], west = set.west[spot[area]] } }
					end
				end
			end
		else
			for area = 1, set.areas do
				local i = spot[area]
				local each = { list = index, ground = ground, set = set, area = area, map = set.map[i], x = set.x[i], y = set.y[i],
					yards = math.sqrt(far[area]) }
				if not point or each.yards < point.yards then point = each end
				wasPoint = wasPoint or (hold ~= nil and hold.ground == ground and hold.area == area and not hold.camp)
			end
		end
	end
	-- The best camp, the cheapest first: the way over the ground is asked for the few cheapest (a
	-- straight line says little in hills), and each of those costs the more for the way round. One
	-- that costs more than the best already does, even as the crow flies, is not looked at.
	-- (Only the walked + 1 cheapest can be the best: past the first whose way isn't asked for, none costs
	-- less than the best so far. They are picked out in one look over the lot, cheapest first; the whole
	-- lot is never sorted.)
	local take, cheap = AREA.walked + 1, {}
	for _, each in ipairs(all) do
		local cost, n = each.cost, #cheap
		if n < take or cost < cheap[n].cost then
			local at = n < take and n + 1 or n
			while at > 1 and cheap[at - 1].cost > cost do
				cheap[at] = cheap[at - 1]
				at = at - 1
			end
			cheap[at] = each
		end
	end
	for i, each in ipairs(cheap) do
		if near and each.cost >= near.cost then break end
		if i <= AREA.walked and #all > 1 then
			local camp = each.camp
			local straight = W.Between(north, west, camp.north, camp.west)
			each.cost = each.cost + math.max(0, W.Walked(W.continent, north, west, camp.north, camp.west) - straight)
		end
		if not near or each.cost < near.cost then near = each end
	end
	-- Standing on ground, it is left only for a camp of the same that has the work done in a share of
	-- the time; never for another task's, which is quick to do but is to be done anyway.
	local same
	for _, each in ipairs(here and all or {}) do
		-- (Of the same: any list that gives what the one stood on gives, groups.)
		local alike = each.list == here.at.list or (groups ~= nil and groups[each.list] ~= nil and groups[each.list] == groups[here.at.list])
		if alike and (not same or each.cost < same.cost) then same = each end
	end
	local pick = near
	if here and same.cost >= here.cost * AREA.leave * (here.mine and AREA.better or 1) then
		-- The work is done here: the stop says so, at the heart of the camp of the ground stood on.
		-- (Leaving it for a camp elsewhere asks a little more of that camp than coming back does.)
		local at = here.at
		pick = { list = at.list, ground = at.ground, set = at.set, area = at.area, camp = at.camp, solid = true,
			map = at.map, x = at.x, y = at.y, yards = here.yards, entry = here.entry, on = true, among = true, cost = here.cost }
	elseif kept and near.cost >= kept.cost - (1 - AREA.better) * kept.yards then
		-- (Another wins once it saves a share of the way to the kept one: halfway, between two alike.)
		pick = kept
	end
	-- Someone or somewhere nearer than the ground is where to go (kept, as a camp is).
	if point and (not pick or point.yards * (wasPoint and AREA.better or 1) < pick.yards * (wasPoint and 1 or AREA.better)) then pick = point end
	if not pick then return nil end
	if not hold then
		if standing > 400 then
			wipe(stood)
			standing = 0
		end
		standing = standing + 1
	end
	stood[key] = { ground = pick.ground, area = pick.area, camp = pick.camp }
	-- also: the other lists whose ground the player stands on as well (grounds lie over one another).
	local also = {}
	for _, index in ipairs(pick.among and on or {}) do
		if index ~= pick.list then also[#also + 1] = index end
	end
	-- cost: what the choice costs, as Price has it. Price(north, west, yards): what working at another
	-- place `yards` off costs, by the same reckoning (the walk, and the waiting it asks where few stand).
	local over, onGround = priced[pick.list], pick.solid
	-- (Where a camp's ground begins: a table of its own, for the stop to keep.)
	local entry = pick.entry or (pick.entryNorth and { north = pick.entryNorth, west = pick.entryWest }) or nil
	return { map = pick.map, x = pick.x, y = pick.y, yards = pick.yards, list = pick.list, among = pick.among or false, on = pick.on or false,
		areas = areas, solid = pick.solid, set = pick.set, area = pick.area, also = also, entry = entry, cost = pick.cost or pick.yards,
		supply = pick.camp and pick.camp.supply,
		Price = function(at, atWest, yards) return yards + (onGround and over(at, atWest) or 0) end }
end

-- A stop as the route weighs it: one at the heart of ground (Stand) is reached where its ground begins,
-- at the area's nearest spawn, so it is that far and there; any other is as it is.
local function Entered(stop)
	local at = stop and stop.stands
	if not (at and at.entry and at.x == stop.x and at.y == stop.y and at.map == stop.map) then return stop end
	return setmetatable({ north = at.entry.north, west = at.entry.west, yards = at.yards }, { __index = stop })
end

-- Whether a kind of mark (Marks.lua's KIND) is of ground to stand on: kills, loot and gathering are
-- done anywhere on it.
local function Solid(kind)
	return kind == "kill" or kind == "loot" or kind == "gather"
end

-- Whether a thing is found at its exact places: one or two spawns, or a few nearly every one a place
-- of its own (the map stands a pointer on each: Ground.lua). A valve, a wardrobe, a creature with a
-- name: somewhere to be led to, never ground to be "in".
local FEW = 12
local function Exact(ground)
	local set = Areas(ground)
	return set.n > 0 and (set.n <= 2 or (set.n <= FEW and set.areas >= set.n - 1))
end

-- Whether everything lists[first..last] has is found at its exact places (vendors aside, who are
-- someone to go to anyway): what they are for is then pinned to those places, and neither their
-- kind nor the game's own area for the quest makes ground of it. from: what each list is.
local function Pinned(lists, from, first, last)
	local any = false
	for i = first, last do
		local what = from[i]
		if not (what and what.how == "sells") then
			if (what and what.game) or not Exact(lists[i]) then return false end
			any = true
		end
	end
	return any
end

-- What is found on the ground a stop stands on (Stand), as its mark's kind, while the player is on it:
-- "kill", "loot" or "gather". nil off it, and for a person or a place, which are one spot to go to.
--   game: the ground is the game's own area for the quest, which the data may know nothing of ("go").
local function Among(spot, kind, game)
	if not (spot and spot.among) then return nil end
	return Solid(kind) and kind or (game and not kind and "go") or nil
end

-- The game's own area for a quest on the player's map, where it is known (Ground.lua; never asked for here).
local function GameArea(id)
	return ns.Ground and W.map and ns.Ground.Known(id, W.map) or nil
end

-- Whether the stop the route leads with wants choosing again before the player has walked far enough
-- for a rebuild: they stepped onto the ground of the area it stands in, or off it.
-- Whether the player stands on the ground of the area the leading stop is in: what there is to do is here,
-- and only stepping off it (R.Wandered) changes what leads.
function R.OnLead()
	local lead = R.Lead()
	local at = lead and lead.stands
	return at ~= nil and at.solid == true and at.on == true and W.Known() and W.continent == areasOn
end

function R.Wandered()
	local lead = R.Lead()
	local at = lead and lead.stands
	if not (at and at.solid) or not W.Known() or W.continent ~= areasOn then return false end
	return OnGround(at.set, at.area, W.north, W.west) ~= (at.on == true)
end

-- The objective at hand among several on one ground (NearestGoal): by quest, the one that led last; another
-- takes over once its nearest spawn is this share of the kept one's distance.
local HAND = { kept = {}, swap = 0.7 }

-- Nearest known place for a quest's unfinished objectives, with `objective` (which one it is for)
-- and `source` so the stop names the right thing. Out in the world that is the nearest area of what
-- they ask for (Stand), with `stands` and, standing in it, `among`; `game`: the area is the game's own.
local function NearestGoal(id, quest)
	local lists, whose, sources, grounds = {}, {}, {}, {}
	local lacking = false        -- an objective waits for an item it can't be done without
	local pinned = {}            -- by objective: found only at exact places (Pinned)
	local loose = false          -- something of the quest's is not: the game's area is where that is
	for index, goal in ipairs(L.Goals(id)) do
		if not goal.finished then
			local from = #lists
			if goal.lacks then lacking = true end
			for _, token in ipairs(L.Asked(goal)) do
				GoalPlaces(token, lists, nil, sources)
				GoalPlaces(token, grounds, true)
			end
			for i = from + 1, #lists do whose[i] = index end
			pinned[index] = Pinned(grounds, sources, from + 1, #lists)
			if not pinned[index] then loose = true end
		end
	end
	if quest and #quest.trigger > 0 then
		lists[#lists + 1] = quest.trigger
		grounds[#lists] = quest.trigger
		loose = true
	end
	-- Held steady (W.Steady): the nearest spawn in a camp changes every few yards.
	local key = "goal" .. id
	local hold = W.Kept(key)
	local found, sold = {}, {}       -- sold: by objective, yards to the nearest vendor of it
	for i, places in ipairs(lists) do
		local map, x, y, yards, dungeon = W.Nearest(places, key .. ":" .. i)
		if map then
			local each = { map = map, x = x, y = y, yards = yards, dungeon = dungeon, objective = whose[i], source = sources[i] }
			found[#found + 1] = each
			if whose[i] and sources[i] and sources[i].how == "sells" and yards and (not sold[whose[i]] or yards < sold[whose[i]]) then
				sold[whose[i]] = yards
			end
		end
	end
	local best, was
	for _, each in ipairs(found) do
		-- With a vendor near, other sources of that objective are ignored.
		local near = each.objective and sold[each.objective]
		if not (near and near <= RULES.buyNear and each.source and each.source.how ~= "sells") then
			if not best or (each.yards or math.huge) < (best.yards or math.huge) then best = each end
			if hold and hold.map == each.map and hold.x == each.x and hold.y == each.y then was = was or each end
		end
	end
	best = W.Steady(key, best, was, nil, RULES.atWork)
	-- Out in the world: the nearest area of the same things. The game's own area for the quest stands
	-- in for everything of the quest's that isn't someone who sells it; not while an objective waits
	-- for an item (the game's area is where that objective is done, not where the item is had).
	-- Nor for an objective found at its exact places, which stay the places to go to: an area round
	-- three valves says they are in it, and not where. Nor for one the data has spawns of (Spawned):
	-- the area stands in only while some objective has none.
	local spawned, bare = {}, false   -- by objective: some of what it asks for has spawns here
	for i, ground in ipairs(grounds) do
		if whose[i] and not (sources[i] and sources[i].how == "sells") and Spawned(ground) then spawned[whose[i]] = true end
	end
	for index, goal in ipairs(L.Goals(id)) do
		if not goal.finished and not pinned[index] and not spawned[index] then bare = true end
	end
	local game = not lacking and loose and bare and GameArea(id)
	local open, which, solid = {}, {}, {}   -- which: the list each one is
	local within = {}            -- the data's spawns of what the game's area stands in for: where on it the work is
	local asks, most = {}, nil   -- by list, what the rest of its objective asks of it (Asks); most: of those within
	local goals = L.Goals(id)
	for i, ground in ipairs(grounds) do
		local near = whose[i] and sold[whose[i]]
		local sells = sources[i] ~= nil and sources[i].how == "sells"
		local exact = not sells and whose[i] ~= nil and pinned[whose[i]] == true
		local goal = whose[i] and goals[whose[i]]
		local ask = sources[i] and Asks(sources[i].how, sources[i].chance, goal and (goal.need or 1) - (goal.have or 0))
		if (sells or exact or not game or (whose[i] and spawned[whose[i]])) and not (near and near <= RULES.buyNear and not sells) then
			open[#open + 1] = ground
			which[#open], solid[#open], asks[#open] = i, sources[i] ~= nil and not exact and Solid(ns.HOW[sources[i].how]), ask
		elseif game and not sells and not exact and sources[i] and Solid(ns.HOW[sources[i].how]) then
			within[#within + 1] = ground
			if ask and (not most or ask.need * ask.each > most.need * most.each) then most = ask end
		end
	end
	local inner = {}
	if game then
		open[#open + 1] = game
		solid[#open], inner[#open], asks[#open] = true, within, most
	end
	-- (The sources of one objective are weighed by how long each takes: Stand's groups.)
	local groups = {}
	for k in ipairs(open) do groups[k] = which[k] and whose[which[k]] or nil end
	local spot = Stand(open, key, solid, inner, asks, groups)
	-- (A way into a dungeon that is nearer than any of it stays the place.)
	if not spot or (best and best.dungeon and best.yards and best.yards < spot.yards) then return best end
	local i = which[spot.list]
	local goal = { map = spot.map, x = spot.x, y = spot.y, yards = spot.yards, objective = i and whose[i], source = i and sources[i],
		stands = spot, game = i == nil, pinned = pinned }
	if i then goal.among = Among(spot, sources[i] and ns.HOW[sources[i].how]) end
	-- What else of the quest's the player stands on the ground of ({ kind, name }).
	goal.also = {}
	for _, index in ipairs(spot.also) do
		local source = which[index] and sources[which[index]]
		local kind = source and ns.HOW[source.how]
		if Solid(kind) then goal.also[#goal.also + 1] = { kind = kind, name = source.name, objective = whose[which[index]] } end
	end
	-- Standing where several of its objectives are done at once, the one that leads is the one at hand: its
	-- own nearest spawn is the nearest (on the game's own area, of every objective it stands in for), held
	-- until another's is clearly nearer (HAND.swap), so the card, the arrow and the lit ground name the
	-- thing in front of the player rather than whichever list the camp came from.
	if spot.among then
		local candidates = {}
		if goal.game then
			for i in ipairs(grounds) do
				local source = sources[i]
				if whose[i] and source and source.how ~= "sells" and not pinned[whose[i]] and Solid(ns.HOW[source.how]) then
					candidates[#candidates + 1] = i
				end
			end
		else
			candidates[1] = which[spot.list]
			for _, index in ipairs(spot.also) do candidates[#candidates + 1] = which[index] end
		end
		local near, north, west = {}, W.north, W.west
		-- Of each objective, only what the card names it from (R.Objectives: the source quickest to have it
		-- from), so the card, the arrow and its portrait name one creature; any of it where none of that is
		-- underfoot.
		local named = R.Objectives(id)
		local function Named(i)
			local want = named[whose[i]] and named[whose[i]].source
			return not want or not sources[i] or sources[i].id == want.id
		end
		local chosen = {}
		for _, i in ipairs(candidates) do
			if whose[i] and Named(i) then chosen[#chosen + 1] = i end
		end
		if #chosen > 0 then candidates = chosen end
		for _, i in ipairs(candidates) do
			local set = whose[i] and Areas(grounds[i])
			for k = 1, set and set.n or 0 do
				local d = (set.north[k] - north) ^ 2 + (set.west[k] - west) ^ 2
				local was = near[whose[i]]
				if not was or d < was.d then near[whose[i]] = { d = d, i = i } end
			end
		end
		local best
		for _, each in pairs(near) do
			if not best or each.d < best.d then best = each end
		end
		local kept = near[HAND.kept[id] or 0]
		if best and kept and best.d >= HAND.swap * HAND.swap * kept.d then best = kept end
		if best then
			HAND.kept[id] = whose[best.i]
			goal.hand = { objective = whose[best.i], source = sources[best.i] }
		end
	end
	return goal
end

-- The line under a stop's name while the player stands on the ground where what it asks for is found
-- (the card and the arrow): what is here, by name, never how many things are.
--   * What it is got from: "From Bael'dun Digger"; got from more than one kind on this ground (stop.also,
--     the same objective's other grounds under the player), each once, "From Bael'dun Digger or
--     Appraiser" (words the names share at either end said once: "Adult or Elder Plainstrider"); kills
--     "Kill Defias Thug or Smuggler". A name the objective's own words already say (the arrow names the
--     objective in a quest of several: "Bael'dun Digger slain") is not said again; with nothing to
--     name, "Found around here".
--   * Another quest whose ground lies over this one (stop.amongAll, Build: the leading stop alone knows
--     them): after the lead's own words, with its kind's mark, "The Zhevra here too". More than one, or
--     one the line has no room to name: their kinds' marks and "also here" (the card names them).
-- One line, fitted to the head's plate (Fits): past its room the other quests are their marks and "also
-- here", then the marks alone, then what it is got from is counted past the first name ("or 2 more").
-- Whether a line fits the head's plate: measured there, in its own font, said in capitals as the head says
-- it (Shy.Notices.Fits); LINE letters (a mark two) where there is no head to ask.
local LINE = 47
local function Plain(text) return (text:gsub("|T.-|t", "xx"):gsub("·", "-")) end
local function Fits(line)
	if Shy.Notices and Shy.Notices.Fits and ns.Upper then return Shy.Notices.Fits(ns.Upper(line)) end
	return #Plain(line) <= LINE
end

-- Words every name shares at its start or its end are said once, so long as each keeps a word of its own:
-- "Bael'dun Digger or Appraiser", "Adult or Elder Plainstrider".
local function Shorten(names)
	local words = {}
	for i, name in ipairs(names) do
		words[i] = {}
		for word in name:gmatch("%S+") do words[i][#words[i] + 1] = word end
	end
	local function Shared(from)
		local n = 0
		while true do
			local word
			for i, list in ipairs(words) do
				local at = from > 0 and n + 1 or #list - n
				if at < 1 or at > #list then return n end
				if i == 1 then word = list[at] elseif list[at] ~= word then return n end
			end
			n = n + 1
		end
	end
	local head, tail = Shared(1), Shared(-1)
	local out = {}
	for i, list in ipairs(words) do
		-- The first keeps the shared start, the last the shared end; each keeps a word of its own.
		local from = i == 1 and 1 or 1 + math.min(head, #list - 1)
		local to = #list - (i == #names and 0 or math.min(tail, #list - from))
		out[i] = table.concat(list, " ", from, to)
	end
	return out
end

local function Listed(names, last)
	if #names == 1 then return names[1] end
	return table.concat(names, ", ", 1, #names - 1) .. " " .. last .. " " .. names[#names]
end

-- Names as one of them is meant: "Blackrock Grunt or Outrunner" (the card's count, for who it is got from).
function R.Either(names) return Listed(Shorten(names), "or") end

function R.Found(stop)
	-- (An errand says it in its own words.)
	if stop.found then return stop.found end
	-- What it is got from here: the stop's own source and its objective's other grounds under the player.
	local names, seen, kill = {}, {}, true
	local function Add(kind, name)
		if not name or name == "" or seen[name] then return end
		seen[name] = true
		if kind ~= "kill" then kill = false end
		names[#names + 1] = name
	end
	if stop.source and stop.source.how ~= "sells" then Add(stop.among, stop.source.name) end
	for _, each in ipairs(stop.also or {}) do
		if each.objective == nil or stop.objective == nil or each.objective == stop.objective then Add(each.kind, each.name) end
	end
	local action = stop.actions and stop.actions[1]
	if #names == 1 and action and stop.objective and ns.Objective(action.id, stop.objective) then
		local goal = L.Goals(action.id)[stop.objective]
		if goal and L.Names(goal.text, names[1]) then names = {} end
	end
	local verb = kill and "Kill" or "From"
	local own = #names > 0 and (verb .. " " .. Listed(Shorten(names), "or")) or "Found around here"
	-- The other quests found here.
	local quests, kinds, marks = {}, {}, ""
	for _, each in ipairs(stop.amongAll or {}) do
		if each.quest and each.name and not seen[each.name] then
			seen[each.name] = true
			quests[#quests + 1] = ns.MarkText("goal", 12, each.kind) .. " " .. each.name
			if not kinds[each.kind] then
				kinds[each.kind] = true
				marks = marks .. ns.MarkText("goal", 12, each.kind)
			end
		end
	end
	if #quests == 0 then return own end
	local line = own .. "  ·  " .. quests[1] .. " here too"
	if #quests > 1 or not Fits(line) then line = own .. "  ·  " .. marks .. " also here" end
	-- (The names before the words: the marks alone, then the names counted past the first.)
	if not Fits(line) then line = own .. "  ·  " .. marks end
	if #names > 1 and not Fits(line) then
		line = verb .. " " .. names[1] .. " or " .. (#names - 1) .. " more  ·  " .. marks .. " also here"
	end
	return line
end

-- Which objective a client-marked quest position is for (the nearest within SAME_PLACE), and its source.
--   skip: by objective, the ones it can't be for (those found at exact places are no part of an area).
local SAME_PLACE = 250       -- yards
local function ObjectiveAt(id, stop, skip)
	if not stop.north then return nil end
	local best, least, what
	for index, goal in ipairs(L.Goals(id)) do
		if not goal.finished and not (skip and skip[index]) then
			local lists, sources = {}, {}
			for _, token in ipairs(L.Asked(goal)) do GoalPlaces(token, lists, nil, sources) end
			for n, places in ipairs(lists) do
				-- Vendors are skipped: the client marks kill and gather areas.
				for _, place in ipairs(sources[n] and sources[n].how == "sells" and {} or places) do
					for i = 1, #place.points, 2 do
						local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
						if continent == stop.continent and north then
							local yards = W.Between(stop.north, stop.west, north, west)
							if not least or yards < least then best, least, what = index, yards, sources[n] end
						end
					end
				end
			end
		end
	end
	if least and least <= SAME_PLACE then return best, what end
end

local function GoalNames(token, out)
	if token.kind == "k" then
		for _, id in ipairs(token.ids) do
			local npc = D.Npc(id)
			if npc and npc.name ~= "" then out[#out + 1] = npc.name end
		end
	else
		local thing
		if token.kind == "c" or token.kind == "o" then thing = D.Thing(token.kind, token.id) else thing = D.Item(token.id) end
		if thing and thing.name and thing.name ~= "" then out[#out + 1] = thing.name end
	end
end

-- Place lists and names for a quest's objectives: what is left for a quest in the log (or only
-- `objective`), everything for one not yet accepted. R.Where flattens them to points and drops
-- dungeon places; R.Ground returns the raw spawn lists ({ map, dungeon, points }) for shading.
local function Whereabouts(id, objective, ground)
	local lists, names = {}, {}
	local from = ground and {} or nil
	local quest = D.Quest(id)
	if L.Has(id) then
		for index, goal in ipairs(L.Goals(id)) do
			if not goal.finished and (not objective or objective == index) then
				local before = #lists
				for _, token in ipairs(L.Asked(goal)) do
					GoalPlaces(token, lists, ground, from)
					GoalNames(token, names)
				end
				-- Each list knows its quest and objective (Ground.lua keys a row of its key by them), and
				-- whether the objective is found only at exact places (pinned: the map then stands a
				-- pointer on each and draws no ground round them).
				local pinned = from and Pinned(lists, from, before + 1, #lists) or nil
				for i = before + 1, from and #lists or 0 do
					from[i].quest, from[i].objective, from[i].pinned = id, index, pinned
				end
			end
		end
	elseif quest then
		for _, token in ipairs(quest.goals) do
			local before = #lists
			GoalPlaces(token, lists, ground, from)
			GoalNames(token, names)
			local pinned = from and Pinned(lists, from, before + 1, #lists) or nil
			for i = before + 1, from and #lists or 0 do from[i].quest, from[i].pinned = id, pinned end
		end
	end
	if quest and #quest.trigger > 0 and not L.Done(id) then
		lists[#lists + 1] = quest.trigger
		-- A place to go to, or to walk someone to.
		if from then from[#lists] = { name = quest.name, how = D.Escort(id) and "escort" or "go", quest = id } end
	end
	return lists, names, from
end

-- Third result: what each list is (GoalPlaces' `from`; a place the quest sends you to is how = "go").
function R.Ground(id, objective)
	return Whereabouts(id, objective, true)
end

-- For one goal token ({ kind, id }): the lists, no names, and what each list is.
function R.GroundOf(token)
	local lists, from = {}, {}
	GoalPlaces(token, lists, true, from)
	local pinned = Pinned(lists, from, 1, #lists) or nil
	for i = 1, #lists do from[i].pinned = pinned end
	return lists, {}, from
end

-- The best place on the player's continent to work on what `lists` hold (each a thing's spawns, `from`
-- what each is, as R.Ground and R.GroundOf give them), as a stop for it stands: at the heart of the
-- best camp of what is killed, looted or gathered (Stand), at the nearest spot of anything else.
-- { map, x, y, yards, among = the work is done where the player stands }, or nil with none of it on
-- this continent.
--   key: what the choice is kept under, so it holds still as the player walks.
--   left: how many are still wanted, of all of it or by list (one where it doesn't say).
function R.BestOf(lists, from, key, left)
	if #lists == 0 then return nil end
	-- groups: what each list gives (its objective; one thing for a goal token's own lists, which carry no quest).
	local solid, asks, groups = {}, {}, {}
	for i, what in ipairs(from) do
		solid[i] = not what.pinned and Solid(ns.HOW[what.how])
		asks[i] = Asks(what.how, what.chance, type(left) == "table" and left[i] or left)
		groups[i] = what.objective or (what.quest == nil and 0) or nil
	end
	local spot = Stand(lists, key, solid, nil, asks, groups)
	return spot and { map = spot.map, x = spot.x, y = spot.y, yards = spot.yards, among = spot.among, source = from[spot.list],
		supply = spot.supply } or nil
end

-- Where to farm an item (ShyFarm): R.BestOf over what you can farm it from. Creatures that drop it first: no one with
-- a title or quests (a town's people), none more than FARM.above levels over yours, and no elite, rare or boss while
-- a plain one drops it too; things that hold it (herbs, ore, crates) only where no creature you could farm drops
-- it; never a vendor (buying). The best camp is where the rest of it (left) is had soonest: its spawns, how often
-- they drop it, the walk there over the ground, the camp you stand in first. { map, x, y (shares of the map),
-- yards, among, name, chance, id, how ("drops" | "holds"), supply (the camp's spawns) }, or nil with nowhere on this
-- continent.
-- (Farming is many of it: asked for fewer than `least`, a lone spawn nearby would win, the way one quest kill left
-- goes to the nearest. The camp's thickness weighs once the wait for one spawn to stand again does.)
local FARM = { above = 3, least = 25, hard = { [1] = true, [2] = true, [3] = true, [4] = true } }
-- What you could farm an item from, at a pass: 1 plain creatures, 2 hard ones too, 3 things that hold it. Its
-- spawn lists and what each is (as R.GroundOf gives them).
local function Farmables(item, pass)
	local lists, _, from = R.GroundOf({ kind = "i", id = item })
	local level = L.Level()
	local keep, kept = {}, {}
	for i, what in ipairs(from) do
		local ok
		if what.how == "holds" then
			ok = pass == 3
		elseif what.how == "drops" and pass < 3 then
			local npc = D.Npc(what.id)
			ok = npc ~= nil and not npc.title and not (npc.gives and #npc.gives > 0) and not (npc.takes and #npc.takes > 0)
				and npc.minLevel <= level + FARM.above and (pass == 2 or not FARM.hard[npc.rank])
		end
		if ok then keep[#keep + 1], kept[#kept + 1] = lists[i], what end
	end
	return keep, kept
end

-- What is farmed, as a key: an item's ID (anywhere it is had), or "n" and a creature's ID (that creature, all it
-- drops). R.FarmCreature reads the creature's back out of a key, or nil for an item's.
function R.FarmKey(item, npc)
	if npc then return "n" .. npc end
	return item
end
function R.FarmCreature(key)
	return type(key) == "string" and tonumber(key:match("^n(%d+)$")) or nil
end

-- The ground you farm on: an item's, the spawns of what R.FarmSpot chooses among (the first pass that has any); a
-- creature's, its own spawns. As the maps shade it (ShyFarm's farm stop, lit in the finder's color). Kept by key
-- and level: the route asks it at every build.
local farmGround = {}
function R.FarmGround(key)
	local kept = farmGround[key]
	if kept and kept.level == L.Level() then return kept.lists end
	local lists = {}
	local npc = R.FarmCreature(key)
	if npc then
		lists = R.GroundOf({ kind = "c", id = npc })
	elseif type(key) == "number" then
		for pass = 1, 3 do
			lists = Farmables(key, pass)
			if #lists > 0 then break end
		end
	end
	farmGround[key] = { level = L.Level(), lists = lists }
	return lists
end

-- How far you are from the nearest spawn of that ground, in yards (straight), or nil off its continent or where the
-- game won't say. The spawns' places in the world are worked out once (by item, continent and level), so asking is
-- a look over plain numbers.
local farmWorld = {}
function R.FarmGroundYards(key)
	if not W.Update() then return nil end
	local kept = farmWorld[key]
	if not (kept and kept.continent == W.continent and kept.level == L.Level()) then
		kept = { continent = W.continent, level = L.Level(), north = {}, west = {} }
		for _, list in ipairs(R.FarmGround(key)) do
			for _, place in ipairs(list) do
				if not place.dungeon then
					for i = 1, #place.points, 2 do
						local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
						if continent == W.continent and north then
							kept.north[#kept.north + 1], kept.west[#kept.west + 1] = north, west
						end
					end
				end
			end
		end
		farmWorld[key] = kept
	end
	local least
	local n, w = W.north, W.west
	for i = 1, #kept.north do
		local d = (kept.north[i] - n) ^ 2 + (kept.west[i] - w) ^ 2
		if not least or d < least then least = d end
	end
	return least and math.sqrt(least) or nil
end

-- Every camp of a creature on every continent, weighed from nowhere in particular (ShyFarm's farm finder ranks the
-- world's farms, then asks the way to the best): { map, x, y (shares of the map), continent, north, west, supply (its
-- spawns there), spawns (all of the creature's on that continent) } each, thickest first. Kept by creature.
FARM.camps = {}
function R.CampsOf(npc)
	local kept = FARM.camps[npc]
	if kept then return kept end
	kept = {}
	local thing = D.Npc(npc)
	local ground = thing and D.Ground(thing)
	local seen = {}
	for _, place in ipairs(ground or {}) do
		local continent = not place.dungeon and W.ToWorld(place.map, 0, 0)
		if continent and not seen[continent] then
			seen[continent] = true
			local set = Areas(ground, continent)
			for _, camp in ipairs(set.n > 0 and Camps(set) or {}) do
				kept[#kept + 1] = { map = camp.map, x = camp.x / UNITS, y = camp.y / UNITS, continent = continent, north = camp.north,
					west = camp.west, supply = camp.supply, spawns = set.n }
			end
		end
	end
	table.sort(kept, function(a, b)
		if a.supply ~= b.supply then return a.supply > b.supply end
		return a.spawns > b.spawns
	end)
	FARM.camps[npc] = kept
	return kept
end

-- npc: farm that creature (all it drops, or `item` of it): its best camp, by the same weighing as a quest's kills.
function R.FarmSpot(item, left, npc)
	left = math.max(left or 0, FARM.least)
	if npc then
		local lists, _, from = R.GroundOf({ kind = "c", id = npc })
		local spot = R.BestOf(lists, from, "farm:n" .. npc, left)
		if not spot then return nil end
		local chance
		for _, source in ipairs(item and D.Item(item) and D.Item(item).sources or {}) do
			if source.kind == "n" and source.id == npc then chance = source.chance end
		end
		return { map = spot.map, x = spot.x / 10000, y = spot.y / 10000, yards = spot.yards, among = spot.among,
			name = spot.source and spot.source.name, chance = chance, id = npc, how = "drops", supply = spot.supply }
	end
	for pass = 1, 3 do
		local keep, kept = Farmables(item, pass)
		local spot = #keep > 0 and R.BestOf(keep, kept, "farm:" .. item, left)
		if spot then
			return { map = spot.map, x = spot.x / 10000, y = spot.y / 10000, yards = spot.yards, among = spot.among,
				name = spot.source and spot.source.name, chance = spot.source and spot.source.chance,
				id = spot.source and spot.source.id, how = spot.source and spot.source.how, supply = spot.supply }
		end
	end
	return nil
end

-- R.BestOf for a quest's open objectives, or one of them, with as many left of each as the log says.
-- (The maps ask it for every objective each time they gather, the card and the route as they are built: worked
-- out once for where you stand, in each build, with what the log says.)
local bested = { built = -1 }
function R.Best(id, objective, key)
	if bested.built ~= R.built or bested.north ~= W.north or bested.west ~= W.west or bested.stamp ~= L.stamp then
		bested = { built = R.built, north = W.north, west = W.west, stamp = L.stamp }
	end
	local asked = id .. ":" .. tostring(objective) .. ":" .. tostring(key)
	local best = bested[asked]
	if best == nil then
		best = R.Choose(id, objective, key) or false
		bested[asked] = best
	end
	return best or nil
end
function R.Choose(id, objective, key)
	local lists, _, from = Whereabouts(id, objective, true)
	local goals, left = L.Has(id) and L.Goals(id) or {}, {}
	for i, what in ipairs(from) do
		local goal = goals[what.objective or objective or 0]
		left[i] = goal and (goal.need or 1) - (goal.have or 0) or 1
	end
	return R.BestOf(lists, from, key, left)
end

-- Each open objective of a quest in the log, as the card's rows say it: by objective index, { here (the
-- player stands on its ground), yards and way (to its best camp, as the maps mark it: "S", "NE"), source
-- (what it is got from there: GoalPlaces' { name, how, id }) }. Worked out once a route build, where the maps
-- choose their objective marks (the same keys, so all of them agree).
local COMPASS = { "N", "NW", "W", "SW", "S", "SE", "E", "NE" }
local objectivesOf, objectivesAt = {}, nil
function R.Objectives(id)
	if objectivesAt ~= R.built then
		wipe(objectivesOf)
		objectivesAt = R.built
	end
	local kept = objectivesOf[id]
	if kept then return kept end
	kept = {}
	objectivesOf[id] = kept
	local started = debugprofilestop()
	for index, goal in ipairs(L.Has(id) and L.Goals(id) or {}) do
		if not goal.finished and #goal.tokens > 0 then
			local key = "pin:" .. id .. ":" .. index
			local best = R.Best(id, index, key)
			local place = R.Aimed(id, index) or best
			local each = { source = best and best.source, here = place ~= nil and place.among == true }
			if place and not each.here then
				each.yards = place.yards
				local continent, north, west = W.ToWorld(place.map, place.x, place.y)
				if north and W.Known() and continent == W.continent then
					each.yards = each.yards or W.Between(W.north, W.west, north, west)
					local turn = math.atan2(west - W.west, north - W.north)
					each.way = COMPASS[math.floor(turn / (math.pi / 4) + 0.5) % 8 + 1]
				end
			end
			kept[index] = each
		end
	end
	Shy.Clock("card: objectives"):Lap(debugprofilestop() - started)
	return kept
end

-- What an objective is got from, quickest first: by source id, its rank, by Stand's own measure (the time
-- its thickest camp takes, as yards, and the walk to its nearest spawn). For a hover's list.
function R.SourceRanks(id, index)
	local lists, _, from = Whereabouts(id, index, true)
	local goal = L.Has(id) and L.Goals(id)[index]
	local left = goal and (goal.need or 1) - (goal.have or 0) or 1
	local costs = {}
	for i, ground in ipairs(lists) do
		local what = from[i]
		local base = what and what.id and Base(ground, nil, Asks(what.how, what.chance, left))
		if base then
			local set, least = Areas(ground), math.huge
			for k = 1, set.n do least = math.min(least, (set.north[k] - W.north) ^ 2 + (set.west[k] - W.west) ^ 2) end
			local cost = base * AREA.stride + (W.Known() and math.sqrt(least) or 0)
			if not costs[what.id] or cost < costs[what.id] then costs[what.id] = cost end
		end
	end
	local order = {}
	for each in pairs(costs) do order[#order + 1] = each end
	table.sort(order, function(a, b) return costs[a] < costs[b] end)
	local ranks = {}
	for rank, each in ipairs(order) do ranks[each] = rank end
	return ranks
end

-- Where the guide's live step already stands for objective `index` of quest `id` (NearerPlace's choice
-- of camp), as R.Best gives it, or nil. The maps mark this spot, so the card, the arrow and every map
-- agree on one place; the choice is made once, here, and read by the rest.
function R.Aimed(id, index)
	for _, stop in ipairs(R.stops or {}) do
		local at = stop.kind == "guide" and stop.nearer and stop.stands
		if at and stop.map and stop.x and at.number and not stop.aimed then
			for _, line in ipairs(stop.view.lines) do
				if line.number == at.number and line.id == id and (not index or not line.objective or line.objective == index) then
					return { map = stop.map, x = stop.x, y = stop.y, yards = stop.yards, among = stop.among }
				end
			end
		end
	end
	return nil
end

function R.Where(id, objective)
	local lists, names = Whereabouts(id, objective)
	local points = {}
	for _, places in ipairs(lists) do
		for _, place in ipairs(places) do
			if not place.dungeon then
				for i = 1, #place.points, 2 do
					points[#points + 1] = { map = place.map, x = place.points[i], y = place.points[i + 1] }
				end
			end
		end
	end
	return points, names
end

-- R.Where's points on one map ({ x, y } each), kept while the log and the bags say the same of the quest
-- (L.version, L.stamp) and nothing new is known of who drops what (D.dropsVersion): the maps ask it for
-- every objective each time they gather, and it is the same.
local whereOn = { version = -1, stamp = -1, drops = -1 }
function R.WhereOn(id, objective, map)
	if whereOn.version ~= L.version or whereOn.stamp ~= L.stamp or whereOn.drops ~= D.dropsVersion then
		whereOn = { version = L.version, stamp = L.stamp, drops = D.dropsVersion }
	end
	local of = id .. ":" .. (objective or 0)
	local key = of .. ":" .. map
	local kept = whereOn[key]
	if not kept then
		kept = {}
		-- (Its places worked out once for every map asked of.)
		local lists = whereOn[of]
		if not lists then
			lists = Whereabouts(id, objective)
			whereOn[of] = lists
		end
		for _, places in ipairs(lists) do
			for _, place in ipairs(places) do
				if not place.dungeon and place.map == map then
					for i = 1, #place.points, 2 do kept[#kept + 1] = { x = place.points[i], y = place.points[i + 1] } end
				end
			end
		end
		whereOn[key] = kept
	end
	return kept
end

-- Building the stops

local function Place(stop, map, x, y, yards, dungeon)
	stop.map, stop.x, stop.y, stop.yards, stop.dungeon = map, x, y, yards, dungeon
	if map then stop.continent, stop.north, stop.west = W.ToWorld(map, x, y) end
	return stop
end

-- The client's distance to a quest that has no known position.
local function GameYards(id)
	local squared, onContinent = C_QuestLog.GetDistanceSqToQuest(id)
	if squared and onContinent then return math.sqrt(squared) end
end

local goalStops = {}   -- quest id -> the goal stop last built, while its objectives are the same ones
local function Build()
	local stops, at = {}, {}

	-- One stop per NPC, shared by all its quests.
	local function Add(key, action, make)
		local stop = key and at[key]
		if not stop then
			stop = make()
			stop.actions = {}
			stop.kind = action.kind
			-- (What it is from one build to the next: the NPC its quests are at, or its one quest.)
			stop.ident = key and ("at " .. key) or (action.kind .. " " .. action.id)
			stops[#stops + 1] = stop
			if key then at[key] = stop end
		end
		stop.actions[#stop.actions + 1] = action
		if action.kind == "turnin" then stop.kind = "turnin" end
		return stop
	end

	-- The client's position for a quest: on the player's map, else on the quest's own map.
	local marks = {}             -- map -> quest -> the client's POI for it there
	local function Mark(map, id)
		local list = marks[map]
		if not list then
			list = {}
			for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do list[poi.questID] = poi end
			marks[map] = list
		end
		return list[id]
	end
	local function FromGame(stop, id)
		local map = W.map
		local poi = map and Mark(map, id)
		if not poi then
			map = GetQuestUiMapID(id, true)
			poi = map and map ~= 0 and Mark(map, id) or nil
		end
		if poi then
			local x, y = math.floor(poi.x * UNITS + 0.5), math.floor(poi.y * UNITS + 0.5)
			return Place(stop, map, x, y, W.Walk(map, x, y))
		end
		stop.yards = GameYards(id)
		return stop
	end

	local zoneMode = not ns.Following()
	for _, entry in ipairs(L.order) do
		local id = entry.id
		local quest = D.Quest(id)
		-- Which objectives are finished, not the counts: a drop that is not the last one leaves the camp
		-- where it was. The last one makes the quest ready, and that stop is chosen again (the turn-in).
		local shape
		if not entry.complete and not entry.failed then
			local goals = entry.goals or {}
			local parts = {}
			for i, goal in ipairs(goals) do parts[i] = goal.finished and "1" or "0" end
			shape = table.concat(parts, "")
		end
		local kept = shape and R.reuse and goalStops[id]
		-- (Not one sent for an item first, R.Needs: the loot may be that item, and the stop goes on. Nor one
		-- that says what else is found on its ground, stop.also: that may be another quest's, gone since.)
		if kept and (kept.needs or (kept.source and kept.source.needs) or (kept.also and #kept.also > 0)) then kept = nil end
		-- (Zone mode leaves a dungeon quest's work to a guide or a dungeon run: only its hand-in is a stop. So does
		-- any mode for a dungeon that is put off, ns.PutOff.)
		local away = not entry.complete and ((zoneMode and quest ~= nil and quest.flags:find("d", 1, true) ~= nil) or ns.PutOff(id))
		if away then
			-- left out
		elseif kept and kept.shape == shape then
			stops[#stops + 1] = kept
		elseif entry.complete then
			local action = { kind = "turnin", id = id, title = entry.title, level = entry.level }
			local giver = quest and NearestGiver(quest.ends)
			if giver then
				Add(giver.kind .. giver.thing.id, action, function()
					return Place({ who = giver.thing.name, thing = giver.thing }, giver.map, giver.x, giver.y, giver.yards, giver.dungeon)
				end)
			else
				Add(nil, action, function() return FromGame({}, id) end)
			end
		elseif not entry.failed then
			local action = { kind = "goal", id = id, title = entry.title, level = entry.level }
			Add(nil, action, function()
				local stop = FromGame({}, id)
				if stop.map then stop.objective, stop.source = ObjectiveAt(id, stop) end
				-- The data's nearest area (NearestGoal) where the client has no place, where its place
				-- is one of the data's own (the nearest of those is as good, and nearer), where the game
				-- has an area for the quest, or where what is left is bought from a vendor (the client
				-- never marks vendors).
				-- ... or where it is an item the quest can't go on without (the client marks where the
				-- objective is done, never where that is had).
				local goal = NearestGoal(id, quest)
				if goal and (goal.yards or not stop.map)
					and (not stop.map or stop.objective or goal.game
						or (goal.source and (goal.source.how == "sells" or goal.source.needs ~= nil))) then
					Place(stop, goal.map, goal.x, goal.y, goal.yards or stop.yards, goal.dungeon)
					stop.objective, stop.source, stop.stands, stop.among = goal.objective, goal.source, goal.stands, goal.among
					stop.also = goal.also
					if goal.game then
						stop.objective, stop.source = ObjectiveAt(id, stop, goal.pinned)
						stop.among = Among(goal.stands, stop.source and ns.HOW[stop.source.how] or ns.QuestKind(id, stop.objective), true)
					end
					-- Standing where several are done: the one at hand (NearestGoal).
					if goal.hand then
						stop.objective, stop.source = goal.hand.objective, goal.hand.source
						stop.among = Among(goal.stands, ns.HOW[stop.source.how], goal.game)
					end
				end
				-- A vendor stop gets the "buy" mark (Marks.lua); `seller` is the vendor's id (Plates.lua).
				if stop.source and stop.source.how == "sells" then stop.mark, stop.seller = "buy", stop.source.id end
				stop.shape = shape
				return stop
			end)
		else
			-- A failed quest must be abandoned and picked up again from its giver, unless the guide's
			-- live step already says how (Guide.lua: line.failed on the accept step).
			local giver = quest and NearestGiver(quest.starts)
			local guided
			local retakeSkipped = false
			if ns.Following() and G.current then
				local guide, saved = G.current, G.lib.Saved(G.current)
				for index = 1, #guide.raw do
					local step = G.lib.Step(guide, index)
					for _, element in ipairs(step.elements) do
						if element.command == "accept" and G.lib.Ids(element)[1] == id and saved.done[index] == "skip" then
							retakeSkipped = true
						end
					end
				end
				for _, live in ipairs(G.active) do
					local own = live.guide or guide
					if G.lib.Saved(own).done[live.step.index] ~= "skip" then
						local view = G.Describe(own, live.step, live.parts)
						for _, line in ipairs(view.lines or {}) do
							if line.failed == id then guided = true end
						end
					end
				end
			end
			if giver and (not guided or retakeSkipped) then
				Add(giver.kind .. giver.thing.id, { kind = "pickup", id = id, title = entry.title, level = entry.level, failed = true }, function()
					return Place({ who = giver.thing.name, thing = giver.thing }, giver.map, giver.x, giver.y, giver.yards, giver.dungeon)
				end)
			end
		end
	end

	if ns.Pickups() and W.map then
		for _, quest in ipairs(L.StartsOn(W.map)) do
			local giver = NearestGiver(quest.starts)
			-- Only reachable ones that are worth the walk (R.Worth). Class quests (`own`) always count.
			local own = quest.classes ~= nil or nil
			-- (Zone mode leaves out the gray quests to pick up too, but a class quest.)
			local gray = not own and T.db.track == "zone" and not T.db.grayZone and L.Trivial(quest.level)
			-- (Zone mode offers no dungeon quest: those are for a guide or a dungeon run. Nor is one of a dungeon
			-- that is put off offered.)
			local dungeon = (zoneMode and quest.flags:find("d", 1, true) ~= nil) or ns.PutOff(quest.id)
			if dungeon then
				-- left out
			elseif giver and giver.yards and not gray and (own or R.Worth(quest, giver)) then
				local action = { kind = "pickup", id = quest.id, title = quest.name, level = quest.level, own = own }
				Add(giver.kind .. giver.thing.id, action, function()
					return Place({ who = giver.thing.name, thing = giver.thing }, giver.map, giver.x, giver.y, giver.yards, giver.dungeon)
				end)
			elseif not giver then
				-- Starts from an item: go to its nearest source.
				local source = NearestSource(quest)
				if source and source.yards then
					local action = { kind = "pickup", id = quest.id, title = quest.name, level = quest.level,
						item = source.item, from = source.from, chance = source.chance }
					Add("d" .. source.from .. source.thing.id, action, function()
						return Place({ who = source.thing.name, thing = source.thing }, source.map, source.x, source.y, source.yards, source.dungeon)
					end)
				end
			end
		end
	end
	-- A quest-starting item already in the bags: a stop with no position.
	if ns.Pickups() then
		for _, held in ipairs(L.Carried()) do
			local quest = held.quest
			local name = C_Item.GetItemNameByID(held.item) or (D.Item(held.item) or {}).name or "An item you carry"
			Add("h" .. held.item, { kind = "pickup", id = quest.id, title = quest.name, level = quest.level, item = held.item, held = true },
				function() return { who = name } end)
		end
	end
	return stops
end

-- Ordering

local function Involves(stop, id)
	for _, action in ipairs(stop.actions) do
		if action.id == id then return true end
	end
	return false
end

-- Timed quests go before nearer stops and before the guide's order. Returns the title, seconds
-- left and fraction left of the stop's soonest-ending timed quest, or nil.
function R.Clock(stop)
	local title, least, share
	for _, action in ipairs(stop.view and stop.view.actions or stop.actions) do
		if action.kind ~= "pickup" and not action.done then
			local left, time = L.Clock(action.id)
			if left and (not least or left < least) then title, least, share = action.title, left, left / time end
		end
	end
	return title, least, share
end

-- led: quests of the guide's live steps; singling one of those out changes nothing.
local working                -- quest whose objective led last time (RULES.atWork)
local LEAD = {
	turned = 150,  -- yards the player may drift from the stop that leads before it is let go
	handIn = 0.5,  -- a hand-in this share of the way to the lead (or less) goes first
}
local holding = {}           -- the stop that led last time: .key, and .least (the nearest the player came)

local function LeadKey(stop)
	local action = stop.actions and stop.actions[1]
	return stop.kind .. (action and action.id or "") .. (stop.thing and tostring(stop.thing) or "")
end

local function Order(stops, led)
	local route, near, far = {}, {}, {}
	for _, stop in ipairs(stops) do
		if stop.north and stop.continent == W.continent then
			near[#near + 1] = stop
		else
			far[#far + 1] = stop
		end
	end

	local first = R.Singled()
	if first ~= 0 and not led[first] then
		for _, list in ipairs({ near, far }) do
			for i, stop in ipairs(list) do
				if Involves(stop, first) then
					stop.chosen = true
					route[1] = table.remove(list, i)
					break
				end
			end
			if route[1] then break end
		end
	end

	-- Nearest neighbour from here on.
	local north, west = W.north, W.west
	if route[1] and route[1].north then north, west = route[1].north, route[1].west end
	-- Timed stops first, least time left first.
	local timed = {}
	for i = #near, 1, -1 do
		local _, left = R.Clock(near[i])
		if left then
			near[i].clock = left
			timed[#timed + 1] = table.remove(near, i)
		end
	end
	table.sort(timed, function(a, b) return a.clock < b.clock end)
	for _, stop in ipairs(timed) do
		route[#route + 1] = stop
		north, west = stop.north, stop.west
	end
	local head = #route
	while #near > 0 do
		local pick, least
		for i, stop in ipairs(near) do
			local at = Entered(stop)
			local yards = W.Between(north, west, at.north, at.west)
			if not least or yards < least then pick, least = i, yards end
		end
		-- The stop that led keeps the lead while the player is on the way to it. It is let go only for a
		-- reason: it is done or gone, the player has turned away from it, or a hand-in is right here.
		if #route == 0 then
			-- A new zone is a new start: nothing is held across it.
			if holding.map ~= W.map then holding.key, holding.least, holding.map = nil, nil, W.map end
			local at, own
			for i, stop in ipairs(near) do
				if LeadKey(stop) == holding.key then at, own = i, stop end
			end
			if at then
				local yards = Entered(own).yards
				if yards then
					if not holding.least or yards < holding.least then holding.least = yards end
					local turned = yards > holding.least + LEAD.turned
					local handIn = near[pick].kind == "turnin" and own.kind ~= "turnin" and near[pick].yards
						and near[pick].yards < yards * LEAD.handIn
					-- Standing at another stop's work is reason enough: it is where the player is.
					local here = yards > RULES.atWork and (near[pick].among or (Entered(near[pick]).yards or math.huge) <= RULES.atWork)
					turned = turned or (here and near[pick].kind == "goal") == true
					-- Once there (RULES.atWork), the nearest goes first as before: the hold is for the way.
					turned = turned or yards <= RULES.atWork
					if at ~= pick and not turned and not handIn then
						pick = at
					elseif at ~= pick then
						if yards > RULES.atWork then near[pick].switched = handIn and "handin" or "turned" end
						holding.least = nil
					end
				end
			else
				holding.least = nil
			end
			holding.key = LeadKey(near[pick])
		end
		-- On the ground of an objective still to do, a turn-in just outside it does not take the lead.
		-- The pin stays. The way there is walked once the work is done, not every step around the area.
		if #route == 0 and near[pick].kind == "turnin" then
			local keep
			for i, stop in ipairs(near) do
				if stop.kind == "goal" and stop.among and (not keep or stop.actions[1].id == working) then keep = i end
			end
			if keep then pick = keep end
		end
		-- The objective that led keeps the lead while within RULES.atWork; a turn-in or pickup can still go first.
		if #route == 0 and near[pick].kind == "goal" then
			for i, stop in ipairs(near) do
				local at = Entered(stop)
				if stop.kind == "goal" and stop.actions[1].id == working and (stop.among or (at.yards and at.yards <= RULES.atWork)) then pick = i end
			end
			working = near[pick].actions[1].id
		end
		local stop = table.remove(near, pick)
		route[#route + 1] = stop
		north, west = stop.north, stop.west
	end

	-- 2-opt pass over the head of the route; the first stop stays first.
	local last = math.min(#route, head + RULES.untangle)
	local function Apart(a, b) return W.Between(a.north, a.west, b.north, b.west) end
	local turned, passes = true, 0
	while turned and passes < 4 do
		turned, passes = false, passes + 1
		for i = head + 2, last - 1 do
			for j = i + 1, last do
				local after = route[j + 1]
				local was = Apart(route[i - 1], route[i]) + (after and Apart(route[j], after) or 0)
				local now = Apart(route[i - 1], route[j]) + (after and Apart(route[i], after) or 0)
				if now + 1 < was then
					local a, b = i, j
					while a < b do
						route[a], route[b] = route[b], route[a]
						a, b = a + 1, b - 1
					end
					turned = true
				end
			end
		end
	end

	-- Unreachable stops: by the client's distance, then by quest id.
	table.sort(far, function(a, b)
		if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
		if a.yards and b.yards and a.yards ~= b.yards then return a.yards < b.yards end
		return a.actions[1].id < b.actions[1].id
	end)
	for _, stop in ipairs(far) do route[#route + 1] = stop end
	return route
end

local function ZoneStop(zone)
	local stop = { kind = "zone", who = zone.name, zone = zone, actions = {} }
	return Place(stop, zone.map, zone.hub.x, zone.hub.y, W.Walk(zone.map, zone.hub.x, zone.hub.y))
end
R.ZoneStop = ZoneStop

-- Zone suggestions after the real stops. A zone the player chose leads until they arrive.
local function AddZones(route)
	local reach = 0
	for _, stop in ipairs(route) do
		if stop.north and stop.continent == W.continent then reach = reach + 1 end
	end
	-- None while the position is unknown (in a dungeon) or a guide leads.
	local want = 0
	local guided = false
	for _, stop in ipairs(route) do
		if stop.kind == "guide" and not stop.side then guided = true end
	end
	if not W.Known() or not ns.Levelling() or (guided and T.db.zones ~= "always") then
		want = 0
	elseif T.db.zones == "always" then
		want = 2
	elseif T.db.zones == "short" and reach < RULES.atHand then
		want = reach == 0 and 3 or 2
	end
	-- The last guide is finished.
	if G.finished and W.Known() and T.db.zones ~= "never" and want < 2 then want = 2 end

	if R.pinnedZone == W.map or R.Singled() ~= 0 then R.pinnedZone = nil end
	local chosen = R.pinnedZone and Z.Get(R.pinnedZone)
	if chosen then
		local stop = ZoneStop(chosen)
		stop.chosen = true
		table.insert(route, 1, stop)
	else
		R.pinnedZone = nil
	end
	if want > 0 then
		local added = chosen and 1 or 0
		for _, zone in ipairs(Z.Best(want + 1)) do
			if added < want and zone ~= chosen then
				route[#route + 1] = ZoneStop(zone)
				added = added + 1
			end
		end
	end
	return route
end

-- When all a guide step still needs is kills, loot or gathering, its stop stands on the best camp
-- of what it asks for (Stand) instead of the guide's own spot: while the player is on that camp's
-- ground, or once it is the better of the two, the guide's spot weighed as the ground it is (the
-- walk to it, and the waiting where few stand round it). The choice is held (AIM.keep) so the pin
-- doesn't jump back and forth.
local AIM = {
	reach = 1500,  -- yards: an area farther off than this is left to the guide's spot
	keep = 1.4,  -- slack for a step already redirected
}
local aimedNear = {}         -- steps redirected last time, by step index

-- An accept that waits for the item starting the quest, none in the bags: nothing to do for it yet.
local function Unstarted(line)
	if line.command ~= "accept" or not line.id then return false end
	local quest = D.Quest(line.id)
	if not (quest and quest.starts[1]) then return false end
	for _, token in ipairs(quest.starts) do
		if token.kind ~= "i" or C_Item.GetItemCount(token.id) > 0 then return false end
	end
	return true
end

-- Where a step's open kills, loot and gathering can be done: lists of places, the step task each
-- is for, and whether a task was left out for naming an NPC (a vendor to buy from). Nothing when
-- the step asks for anything else.
--   ground: every spawn instead of the places gathered from them, the game's own area for a quest
--   where it is known, and a fourth result: what each list is to its task (GoalPlaces' `from`; an
--   area of the game's has the quest's `kind` instead of a `how`).
local function Work(view, ground)
	local lists, whose, tied = {}, {}, false
	local from = ground and {} or nil
	local person = {}
	for _, named in ipairs(view.names or {}) do
		if named.kind == "target" and named.task then person[named.task] = true end
	end
	for _, line in ipairs(view.lines) do
		if line.can and not line.done and not Unstarted(line) then
			if person[line.number] then
				tied = true
			else
				local before = #lists
				local left           -- how many the line still wants, where it says
				if line.command == "complete" and line.id and L.Has(line.id) then
					local index = line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1
					local goal = L.Goals(line.id)[index]
					left = goal and (goal.need or 1) - (goal.have or 0)
					for _, token in ipairs(goal and not goal.finished and L.Asked(goal) or {}) do GoalPlaces(token, lists, ground, from) end
					-- The game's area stands in for them where the data has no spawns of them (Spawned). (Not
					-- waiting for an item the objective can't be done without: it is where that is had. Nor for
					-- what is found at its exact places.)
					local spawned = false
					for i = before + 1, ground and #lists or 0 do
						if from[i].how ~= "sells" and Spawned(lists[i]) then spawned = true end
					end
					local game = ground and goal and not goal.finished and not goal.lacks and not spawned and GameArea(line.id)
					if game and not Pinned(lists, from, before + 1, #lists) then
						-- (Their spawns still say where on the area the work is: Hearts.)
						-- (And what the rest asks: of the source that asks the most.)
						local inner, most = {}, nil
						for i = #lists, before + 1, -1 do
							if from[i].how ~= "sells" and Solid(ns.HOW[from[i].how]) then
								inner[#inner + 1] = lists[i]
								local ask = Asks(from[i].how, from[i].chance, left)
								if not most or ask.need * ask.each > most.need * most.each then most = ask end
							end
							lists[i], from[i] = nil, nil
						end
						lists[#lists + 1] = game
						from[#lists] = { kind = ns.QuestKind(line.id, index), game = true, inner = inner, asks = most }
					end
				elseif line.command == "collect" and line.id then
					GoalPlaces({ kind = "i", id = line.id }, lists, ground, from)
					left = (tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")) or 1) - C_Item.GetItemCount(line.id)
				elseif line.command ~= "goto" then
					return nil
				end
				for i = before + 1, #lists do
					whose[i] = line.number
					if from then from[i].left = left end
				end
			end
		end
	end
	return lists, whose, tied, from
end

-- yards: how far the guide's own spot for the step is. only: nothing but an item a task waits for
-- moves the step (the "nearest area" setting is off).
local function NearerPlace(view, yards, only)
	-- A task that names an NPC is never redirected.
	local lists, whose, _, from = Work(view, true)
	if not lists then return nil end
	local kinds, solid, exact = {}, {}, {}
	-- A task found only at exact places (Pinned) is somewhere to go to, whatever its kind.
	local head = 1
	while head <= #lists do
		local last = head
		while last < #lists and whose[last + 1] == whose[head] do last = last + 1 end
		local pinned = Pinned(lists, from, head, last)
		for i = head, last do exact[i] = pinned and from[i].how ~= "sells" end
		head = last + 1
	end
	local asks = {}              -- by list, what the rest of its task asks of it (Asks)
	for i in ipairs(lists) do
		kinds[i] = from[i].kind or ns.HOW[from[i].how]
		-- (An area of the game's is ground whatever the data makes of the quest.)
		solid[i] = (Solid(kinds[i]) and not exact[i]) or from[i].game == true
		asks[i] = from[i].asks or Asks(from[i].how, from[i].chance, from[i].left)
	end
	-- The task the guide's own spot is for waits for an item it can't be done without (L.Asked): the
	-- step stands where that is had, however far. The guide's spot is no place to go without it.
	local wanting, which, firm, once = {}, {}, {}, {}
	for i, places in ipairs(lists) do
		if from[i].needs and (view.led == nil or whose[i] == view.led) then
			wanting[#wanting + 1] = places
			which[#wanting], firm[#wanting], once[#wanting] = i, solid[i], Asks(from[i].how, from[i].chance, 1)
		end
	end
	local first = #wanting > 0 and Stand(wanting, "need" .. view.step.index, firm, nil, once)
	if first then
		local i = which[first.list]
		first.number, first.needs, first.others = whose[i], from[i], {}
		first.found = Among(first, kinds[i])
		return first
	end
	if only then return nil end
	local inner = {}
	for i in ipairs(lists) do inner[i] = from[i].inner end
	local spot = Stand(lists, "aim" .. view.step.index, solid, inner, asks)
	if not spot then return nil end
	spot.number = whose[spot.list]
	spot.found = Among(spot, kinds[spot.list], from[spot.list].game)
	-- What else of the step's the player stands on the ground of ({ kind, name }).
	spot.others = {}
	for _, index in ipairs(spot.also) do
		if Solid(kinds[index]) then spot.others[#spot.others + 1] = { kind = kinds[index], name = from[index].name } end
	end
	-- An exact place beside the guide's own spot is that spot said better, however near the guide's is:
	-- three valves round a console have one spot in the guide, and each has its own here.
	if exact[spot.list] and view.north and view.continent == W.continent then
		local _, north, west = W.ToWorld(spot.map, spot.x, spot.y)
		if north and W.Between(view.north, view.west, north, west) <= RULES.atWork then
			spot.beside = true
			return spot
		end
	end
	local ease = aimedNear[view.step.index] and AIM.keep or 1
	-- The guide's own spot is weighed as the ground it is (Price): a spot by one spawn, where ten
	-- kills are a long wait for it to stand again, loses to a camp down the road.
	local own = yards
	if yards and spot.solid and view.north and view.continent == W.continent then own = spot.Price(view.north, view.west, yards) end
	if spot.found or (spot.yards <= AIM.reach * ease and (not own or spot.cost < own * AREA.better * ease)) then return spot end
	-- Left at the guide's spot: the area is still watched for the player stepping onto it (R.Wandered).
	return nil, spot
end

-- The highest quest level of a stop when it is STEEP or more above the player, else nil.
local STEEP = 3
local function TooHigh(stop)
	local high
	for _, action in ipairs(stop.actions) do
		local level = action.level or 0
		if action.kind ~= "pickup" and level >= L.Level() + STEEP and (not high or level > high) then high = level end
	end
	return high
end

-- The guide's live steps as stops. With `offered`: the off-route catch-up steps (R.offered),
-- which the map marks but the route doesn't lead to.
local aim                    -- { step, number }: the step task the player asked the way to (R.Aim)

local function GuideStops(offered)
	local stops = {}
	local kept = false       -- the aimed task is still to do
	local near = {}          -- steps redirected this time (NearerPlace)
	for _, entry in ipairs(offered and G.offered or G.active) do
		local view = G.Describe(entry.guide or G.current, entry.step, entry.parts, nil, entry.ghosts)
		local stop = { kind = "guide", view = view, who = view.who, side = entry.side, manual = entry.manual, first = entry.first,
			needed = entry.needed, catch = entry.catch, offered = offered or nil, actions = {} }
		for _, action in ipairs(view.actions) do
			if not action.done then stop.actions[#stop.actions + 1] = action end
		end
		stop.map, stop.x, stop.y = view.map, view.x, view.y
		stop.continent, stop.north, stop.west = view.continent, view.north, view.west
		local task = not offered and aim and aim.step == entry.step.index and aim.number
		for _, line in ipairs(task and view.lines or {}) do
			if line.number == task and line.at and line.can and not line.done then
				local at = line.at
				stop.map, stop.x, stop.y = at.map, at.x, at.y
				stop.continent, stop.north, stop.west = at.continent, at.north, at.west
				stop.aimed = task
				stop.led, stop.who = task, G.Who(view, task)
			end
		end
		if task then kept = kept or stop.aimed ~= nil end
		if stop.north and stop.continent == W.continent and W.Known() then
			stop.yards = W.WalkTo(stop.north, stop.west)
		end
		if W.Known() and not offered and not stop.aimed then
			local nearer, watched = NearerPlace(view, stop.yards, T.db.guide.nearby == false)
			stop.stands = watched
			if nearer then
				Place(stop, nearer.map, nearer.x, nearer.y, nearer.yards)
				stop.nearer, stop.stands, stop.among, stop.also = true, nearer, nearer.found, nearer.others
				-- beside: it is the guide's own spot still, said to the yard (the card has nothing to say of it).
				stop.beside = nearer.beside
				-- needs: what it is sent for first ({ needs = the item, name, how }; R.Needs says it).
				stop.needs = nearer.needs
				if nearer.number then stop.led, stop.who = nearer.number, G.Who(view, nearer.number) end
				near[entry.step.index] = true
			end
		end
		stop.high = TooHigh(stop)
		stops[#stops + 1] = stop
	end
	if not offered then aimedNear = near end
	if not offered and not kept then aim = nil end
	return stops
end

-- Points the route at one task of a multi-task step until it is done; again to clear.
function R.Aim(stop, number)
	local index = stop.view.step.index
	if aim and aim.step == index and aim.number == number then aim = nil else aim = { step = index, number = number } end
	ns.Refresh()
end

-- Removes from the nearby stops what the guide's live steps already cover.
local function WithoutGuided(stops, guided)
	local covered = {}
	for _, stop in ipairs(guided) do
		for _, action in ipairs(stop.actions) do covered[action.kind .. action.id] = true end
	end
	local kept = {}
	for _, stop in ipairs(stops) do
		for i = #stop.actions, 1, -1 do
			local action = stop.actions[i]
			if covered[action.kind .. action.id] then table.remove(stop.actions, i) end
		end
		if #stop.actions > 0 then
			stop.kind = stop.actions[1].kind
			for _, action in ipairs(stop.actions) do
				if action.kind == "turnin" then stop.kind = "turnin" end
			end
			kept[#kept + 1] = stop
		end
	end
	return kept
end

-- True when all the step still needs is XP.
local function OnlyGrind(stop)
	local asks = false
	for _, line in ipairs(stop.view.lines) do
		if line.can and not line.done then
			if line.command ~= "xp" then return false end
			asks = true
		end
	end
	return asks
end

-- Detours: a nearby stop that goes before the guide's lead step (Detour, below).
--   * a turn-in nearer than the step or hardly off the way, and an objective the player is standing in;
--   * not a turn-in the guide itself makes later, unless the extra walk is small (nearer isn't on the way);
--   * with guide.nearby off, only a turn-in before a grind;
--   * when the step is only a grind, any turn-in, objective or worthwhile pickup within RULES.grindReach.
local detoured = {}          -- stops that detoured last time: kind .. quest

-- A pickup worth doing instead of a grind: not a dungeon quest, and doable at this level.
local function WorthTaking(stop)
	for _, action in ipairs(stop.actions) do
		local quest = action.kind == "pickup" and D.Quest(action.id)
		if quest and not quest.flags:find("d", 1, true)
			and (quest.level == 0 or (quest.level <= L.Level() + RULES.above and not L.Outgrown(quest))) then
			return true
		end
	end
	return false
end

local ledStep                -- index of the guide step that led last time

-- True when the step has kills or gathering left.
local function AtWork(stop)
	for _, line in ipairs(stop.view.lines) do
		if line.can and not line.done and (line.command == "complete" or line.command == "collect") then return true end
	end
	return false
end

-- Looking ahead
-- The guide's order is planned from where its steps stand, but kills and loot end wherever the
-- player found them. An objective the guide gets to within its next FORWARD.steps steps goes first when
-- the walk through those steps is shorter that way from where the player is.
-- Bringing a later step's objective forward.
local FORWARD = {
	steps = 6,  -- guide steps looked at
	reach = 800,  -- yards: an objective farther off is never brought forward
	gain = 120,  -- yards the walk has to get shorter by
	aside = 0.5,  -- ... for no more than this share of the way to the guide's step added to it
	back = 20,  -- guide steps searched for one that comes back to the place (G.ComesBack)
	camp = 300,  -- yards within which the rest of the quest has to be doable (Camped)
}
local spots = setmetatable({}, { __mode = "k" })   -- a record's places -> { north, west, ... } on spotsOn
local spotsOn                -- the continent those are on

local function Spots(places)
	if spotsOn ~= W.continent then
		wipe(spots)
		spotsOn = W.continent
	end
	local list = spots[places]
	if not list then
		list = {}
		for _, place in ipairs(places) do
			for i = 1, place.dungeon and 0 or #place.points, 2 do
				local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
				if north and continent == spotsOn then
					list[#list + 1] = north
					list[#list + 1] = west
				end
			end
		end
		spots[places] = list
	end
	return list
end

local hops = setmetatable({}, { __mode = "k" })   -- a record's spawns -> yards from one to its nearest neighbour, on average

local function Hop(places)
	local hop = hops[places]
	if not hop then
		local list = Spots(places)
		local all = #list / 2
		local count, total = math.min(all, 40), 0
		for i = 1, count do
			local least
			for j = 1, all do
				if j ~= i then
					local yards = W.Between(list[i * 2 - 1], list[i * 2], list[j * 2 - 1], list[j * 2])
					if not least or yards < least then least = yards end
				end
			end
			total = total + math.min(least or 0, EFFORT.apart)
		end
		hop = count > 0 and total / count or 0
		hops[places] = hop
	end
	return hop
end

local Owed   -- below

-- Seconds for `count` of what a goal token asks, whether its creature stands alone, and the
-- fights that takes. A thing had as another quest's reward costs that quest, where it isn't done yet
-- (`inner`: this is that quest's own cost, and a reward it needs in turn is not followed).
local function Effort(token, count, inner)
	local lists, from = {}, {}
	GoalPlaces(token, lists, true, from)
	local best, alone, fights
	for i, places in ipairs(lists) do
		local how, chance, quest = from[i].how, from[i].chance, from[i].quest
		local seconds, units = EFFORT.handle, 0
		if how ~= "sells" and how ~= "gives" then
			units = count
			if how == "drops" then units = math.min(EFFORT.most, count / (math.max(1, chance or 100) / 100)) end
			seconds = units * (((how == "kill" or how == "drops") and EFFORT.fight or EFFORT.handle) + Hop(places) / EFFORT.stride * EFFORT.crowd)
			if how ~= "kill" and how ~= "drops" then units = 0 end
		elseif quest and not inner and not L.Done(quest) then
			local data = D.Quest(quest)
			for index = 1, data and #data.goals or 0 do
				local more, few = Owed(quest, index, true)
				seconds, units = seconds + more, units + few
			end
		end
		if not best or seconds < best then best, alone, fights = seconds, #Spots(places) <= 2, units end
	end
	return best or count * EFFORT.handle, alone == true, fights or 0
end

-- Seconds and fights for objective `index` of a quest: what is left of it for one in the log, all of
-- it for one not taken (EFFORT.asked of each, one of a creature that stands alone). `inner`: as Effort's.
function Owed(id, index, inner)
	if L.Has(id) then
		local goal = L.Goals(id)[index]
		if not goal or goal.finished then return 0, 0 end
		local left = math.max(1, (goal.need or 1) - (goal.have or 0))
		local least, fights
		for _, token in ipairs(goal.tokens) do
			local seconds, _, units = Effort(token, left, inner)
			if not least or seconds < least then least, fights = seconds, units end
		end
		return least or left * EFFORT.handle, fights or 0
	end
	local quest = D.Quest(id)
	local token = quest and quest.goals[index]
	if not token or token.kind == "s" then return 0, 0 end
	local seconds, alone, fights = Effort(token, EFFORT.asked, inner)
	if alone then
		local one, _, few = Effort(token, 1, inner)
		seconds, fights = one, few
	end
	return seconds, fights
end

function R.Effort(id, index)
	return (Owed(id, index))
end

-- Fights the objective still asks for: kills, and kills for what drops.
function R.Fights(id, index)
	return select(2, Owed(id, index))
end

-- For `count` of an item, whatever quest it is for.
function R.EffortOf(item, count)
	return (Effort({ kind = "i", id = item }, count or 1))
end

function R.FightsOf(item, count)
	return select(3, Effort({ kind = "i", id = item }, count or 1))
end

-- The guide's next steps, live one first, as a walk sees them: { index, north, west, lists =
-- where its work can be done when that is all it asks (Work), whose = the step task each of
-- those is for }. `of`: the first of them with an open action, by kind .. quest ("goal933");
-- `all`: every one of them with it. Lazy, reset on every build.
local ahead
local function Ahead()
	if not ahead then
		ahead = { of = {}, all = {} }
		for _, view in ipairs(G.Upcoming(FORWARD.steps)) do
			local step = { index = view.step.index }
			if view.continent == W.continent then step.north, step.west = view.north, view.west end
			local lists, whose, tied = Work(view)
			if lists and #lists > 0 and not tied then step.lists, step.whose = lists, whose end
			-- carried: it ends in a flight or the hearthstone, so the way to the next step is not walked.
			for _, line in ipairs(view.lines) do
				if (line.command == "fly" or line.command == "hs") and not line.done then step.carried = true end
			end
			ahead[#ahead + 1] = step
			for _, action in ipairs(view.actions) do
				local key = action.kind .. action.id
				if not action.done then
					ahead.of[key] = ahead.of[key] or #ahead
					ahead.all[key] = ahead.all[key] or {}
					table.insert(ahead.all[key], #ahead)
				end
			end
		end
	end
	return ahead
end

-- Yards from the player through those steps in order, each piece of work at the place that
-- lengthens the way from the step before to the step after least. `first`: a stop gone to
-- before them; `without`: the step done there.
local function Through(lead, first, without)
	local steps = Ahead()
	local total, north, west = 0, W.north, W.west
	local carried = false        -- the step before flew or hearthed
	if first then
		total = W.Between(north, west, first.north, first.west)
		north, west = first.north, first.west
	end
	for i, step in ipairs(steps) do
		local n, w = step.north, step.west
		if i == without then
			n = nil
		elseif i == 1 then
			n, w = lead.north, lead.west
		elseif step.lists then
			-- Where the walk goes next: the following step that has a place.
			local on
			for later = i + 1, #steps do
				if later ~= without and steps[later].north then
					on = steps[later]
					break
				end
			end
			local least
			for _, places in ipairs(step.lists) do
				local list = Spots(places)
				for p = 1, #list, 2 do
					local yards = (carried and 0 or W.Between(north, west, list[p], list[p + 1]))
						+ (on and W.Between(list[p], list[p + 1], on.north, on.west) or 0)
					if not least or yards < least then least, n, w = yards, list[p], list[p + 1] end
				end
			end
		end
		if n then
			if not carried then total = total + W.Between(north, west, n, w) end
			north, west, carried = n, w, false
		end
		if i ~= without and step.carried then carried = true end
	end
	return total
end

-- True when working on a stop's objective now, instead of at the guide's step for it (`at`),
-- shortens the walk through the guide's next steps.
local function Shorter(stop, lead, at, hold)
	if at < 2 or Ahead()[1].index ~= lead.view.step.index then return false end
	return Through(lead) - Through(lead, stop, at) >= FORWARD.gain / hold
end

-- The guide's step among its next few that a stop for a quest's objective stands in for: the
-- first with that quest's work whose every task can be done within FORWARD.camp yards of the stop,
-- so that one visit there sees the step through. nil when there is none. (A step for creatures
-- spread over a zone is not done where the first of them stands, nor is one for another of the
-- quest's objectives somewhere else.)
local function Camped(stop)
	local steps = Ahead()
	for _, at in ipairs(steps.all["goal" .. stop.actions[1].id] or {}) do
		local step, fits = steps[at], true
		if not step.lists then
			fits = step.north ~= nil and W.Between(stop.north, stop.west, step.north, step.west) <= FORWARD.camp
		else
			local near = {}              -- by task: one of its places is this near
			for i, places in ipairs(step.lists) do
				local task = step.whose[i] or 0
				near[task] = near[task] or false
				local list = Spots(places)
				for p = 1, near[task] and 0 or #list, 2 do
					if W.Between(stop.north, stop.west, list[p], list[p + 1]) <= FORWARD.camp then near[task] = true end
				end
			end
			for _, found in pairs(near) do fits = fits and found end
		end
		if fits then return at end
	end
end

-- The steps the walk above reckons with, by index (for G.ComesBack: the steps after them).
local function Reckoned()
	local seen = {}
	for _, step in ipairs(Ahead()) do seen[step.index] = true end
	return seen
end

local function Detour(stop, lead, grind)
	stop, lead = Entered(stop), Entered(lead)
	local strict = T.db.guide.nearby == false
	if grind and not strict and stop.kind == "pickup" and stop.actions[1].held then return true end   -- in the bags already
	if not stop.yards or not stop.north then return false end
	-- Timed quests always detour (R.Clock).
	if stop.clock then return true, "clock" end
	-- So does re-taking a failed quest that the lead step needs.
	for _, action in ipairs(stop.actions) do
		for _, asked in ipairs(action.failed and lead.view.actions or {}) do
			if asked.id == action.id and not asked.done then return true, "failed" end
		end
	end
	if strict and not (grind and stop.kind == "turnin") then return false end
	-- Quests to take a short walk off go before work on one already taken, its creatures maybe the very ones
	-- a quest there wants too; something done in a moment (a well to fill) still goes in passing.
	if stop.kind == "goal" and not grind and lead.yards and lead.yards <= RULES.onTheWay then
		local takes, works = false, false
		for _, line in ipairs(lead.view.lines) do
			if line.can and not line.done then
				if line.command == "accept" then takes = true end
				if line.command == "complete" or line.command == "collect" then works = true end
			end
		end
		if takes and not works then
			-- (Once begun a quest is seen through: what all of it still asks.)
			local id, seconds = stop.actions[1].id, 0
			for index in ipairs(L.Goals(id)) do seconds = seconds + R.Effort(id, index) end
			if seconds > 2 * EFFORT.handle then return false end
		end
	end
	-- Hysteresis (RULES.atWork): a detoured objective keeps the lead while the player is at it, and
	-- none takes it while the player is working on the guide's own step.
	if stop.kind == "goal" and not grind then
		if detoured["goal" .. stop.actions[1].id] then
			if stop.among or stop.yards <= RULES.atWork then return true end
		elseif ledStep == lead.view.step.index and (lead.among or (lead.yards and lead.yards <= RULES.atWork)) and AtWork(lead) then
			return false
		end
	end
	local hold = detoured[stop.kind .. stop.actions[1].id] and RULES.stay or 1
	-- A class quest right here or hardly off the way is picked up in passing.
	if stop.kind == "pickup" and not strict then
		local own = false
		for _, action in ipairs(stop.actions) do own = own or action.own == true end
		if own then
			if stop.yards <= RULES.ownReach * hold then return true, "class" end
			if lead.yards and lead.north and stop.yards <= lead.yards * hold
				and stop.yards + W.Between(stop.north, stop.west, lead.north, lead.west) - lead.yards <= RULES.onTheWay * hold then
				return true, "class"
			end
		end
	end
	if grind and not strict then
		if stop.kind == "pickup" then
			if not WorthTaking(stop) then return false end
		elseif stop.kind ~= "turnin" and stop.kind ~= "goal" then
			return false
		end
		return stop.yards <= RULES.grindReach * hold
	end
	local placed = lead.yards ~= nil and lead.north ~= nil
	local apart = placed and W.Between(stop.north, stop.west, lead.north, lead.west) or nil
	local extra = placed and stop.yards + apart - lead.yards or nil
	local reach
	-- sooner: the guide has a step for the objective among its next few, and the walk through
	-- them is shorter with the objective first (Shorter). Not one too high for now. It begins only
	-- with an objective nearer than the guide's step and not far off the way to it, and not where
	-- the guide comes again for a quest still to take; once begun the quest is seen through.
	local soon, sooner
	if stop.kind == "turnin" then
		reach = (grind or placed) and RULES.handInReach or RULES.handInNear
	elseif stop.kind == "goal" then
		reach = RULES.workReach
		if placed and not grind then
			local begun = detoured["goal" .. stop.actions[1].id]
			local fair = stop.yards <= FORWARD.reach * hold and (begun or (stop.yards <= lead.yards and extra <= lead.yards * FORWARD.aside))
			-- (The guide's next steps are read only where they can matter.)
			if fair or stop.yards <= reach * hold then soon = Ahead().of["goal" .. stop.actions[1].id] end
			-- The step the stop stands in for; once begun, the quest's first step ahead will do.
			local at = soon ~= nil and fair and not TooHigh(stop) and (Camped(stop) or (begun and soon)) or nil
			sooner = at ~= nil and Shorter(stop, lead, at, hold)
				and (begun or not G.ComesBack(stop.north, stop.west, RULES.onTheWay, FORWARD.back, Reckoned()))
		end
	else
		return false
	end
	if stop.yards > reach * hold then return sooner == true end
	if grind or not placed then return true end
	if stop.kind == "goal" then
		-- The guide's step goes first when it is nearer and the objective is in reach from it.
		-- An objective the guide has a step for soon only detours in passing, or as the shorter walk.
		local behind = lead.yards * hold < stop.yards and apart <= reach
		if soon then return sooner or (not behind and extra <= RULES.inPassing * hold) end
		if behind then return false end
	elseif stop.kind == "turnin" and lead.yards <= RULES.atWork and lead.yards * hold < stop.yards then
		-- With the guide's step right here, a turn-in the guide makes later waits.
		local guides = true
		for _, action in ipairs(stop.actions) do
			if action.kind == "turnin" and not G.HandsIn(action.id) then guides = false end
		end
		if guides then return false end
	end
	if extra <= RULES.onTheWay * hold then return true end
	if stop.yards > lead.yards * hold then return false end
	-- Nearer but off the way: a turn-in the guide makes later detours only if it no more than
	-- doubles the walk to the guide's step.
	if stop.kind == "turnin" and extra > lead.yards * hold then
		for _, action in ipairs(stop.actions) do
			if action.kind == "turnin" and not G.HandsIn(action.id) then return true end
		end
		return false
	end
	return true
end

-- A side step ("along the way") leads while the player is where it is done: right there, or
-- nearer than the main step and hardly off the way. The card reads `stop.here`.
local wasHere = {}           -- step indexes that led this way last time

local function Here(stop, lead)
	if not stop.side or not stop.yards or not stop.north or T.db.guide.nearby == false then return false end
	local hold = wasHere[stop.view.step.index] and RULES.stay or 1
	if not lead or not lead.yards or not lead.north then return stop.yards <= RULES.workReach * hold end
	if stop.yards > lead.yards * hold then return false end
	if stop.yards <= RULES.workReach * hold then return true end
	local extra = stop.yards + W.Between(stop.north, stop.west, lead.north, lead.west) - lead.yards
	return extra <= RULES.onTheWay * hold
end

-- Orders the live steps: side steps that are here (nearest first), then the rest.
local function HereFirst(guided)
	local lead = guided[1]
	local first, rest, now = {}, {}, {}
	for i, stop in ipairs(guided) do
		if i > 1 and Here(stop, lead) then
			stop.here = true
			now[stop.view.step.index] = true
			first[#first + 1] = stop
		else
			rest[#rest + 1] = stop
		end
	end
	wasHere = now
	table.sort(first, function(a, b) return a.yards < b.yards end)
	for _, stop in ipairs(rest) do first[#first + 1] = stop end
	return first
end

-- Guide-only mode: removes pickups the guide doesn't use from the route (their pins fade,
-- Pins.lua). Failed quests, items already in the bags and class quests stay.
local function WithoutExtras(stops)
	local kept = {}
	for _, stop in ipairs(stops) do
		for i = #stop.actions, 1, -1 do
			local action = stop.actions[i]
			if action.kind == "pickup" and not action.failed and not action.held and not action.own then table.remove(stop.actions, i) end
		end
		if #stop.actions > 0 then
			stop.kind = stop.actions[1].kind
			for _, action in ipairs(stop.actions) do
				if action.kind == "turnin" then stop.kind = "turnin" end
			end
			kept[#kept + 1] = stop
		end
	end
	return kept
end

-- True when the player chose to also quest in this zone (ns.char.zones, asked by Notice.lua).
function R.Extras(map)
	return ns.char.zones[map or W.map or 0] == true
end

-- Quests in the log the guide doesn't use, less those kept (ns.char.kept), in a chosen zone, or complete.
function R.Strays()
	local list = {}
	if not ns.Following() or not G.current or G.finished then return list end
	local chosen = {}
	for map, on in pairs(ns.char.zones) do
		if on then chosen[W.MapName(map) or ""] = true end
	end
	for _, entry in ipairs(L.order) do
		if not entry.complete and not ns.char.kept[entry.id] and not chosen[entry.header or ""] and not G.Uses(entry.id)
			and C_QuestLog.CanAbandonQuest(entry.id) then
			list[#list + 1] = entry
		end
	end
	return list
end

-- True when the route currently has a pickup for this quest.
function R.Takes(id)
	for _, list in ipairs({ R.stops, R.offered }) do
		for _, stop in ipairs(list) do
			for _, action in ipairs(stop.view and stop.view.actions or stop.actions) do
				if action.kind == "pickup" and action.id == id then return true end
			end
		end
	end
	return false
end

-- Journeys
-- Where the way to the next stop rides (a flight, a boat, a zeppelin, the Skyborne's airboat, the tram, a
-- portal), each ride comes before it as a stop of kind "fly": the flight master, the dock or the tower, the
-- tram's door, the portal; `ferry` says which for any but a flight, and `land` where it lands. The way is
-- ShyWay's (Shy.Way.Journey: on foot over the ground, and by every ride there is), the one the arrow
-- and the maps show. Only from the player to the lead stop or the guide's step, and on from where its rides
-- land; rides between guide steps are the guide's. The journey to a stop is kept while it is about as quick
-- as any other (Journey's lead), so the card doesn't turn from one way to another and back.
local FLIGHT = {
	walkSpeed = 7,  -- yards a second, where no way over the ground is known
	masterReach = 150,  -- yards from a flight point within which its flight master is looked for
}
local Way = Shy.Way

local points, pointsFor, pointsFrom   -- flight points of the player's faction, which faction, and of what stops

-- The flight points (ShyWay's stops, Shy.Way.Stops): { name, town, key, continent, north, west, node }.
local function Points()
	local side, stops = L.Side(), Way.Stops()
	if pointsFor ~= side or pointsFrom ~= stops then
		points, pointsFor, pointsFrom = {}, side, stops
		for _, stop in ipairs(stops) do
			if stop.by == "flight" and (side == "" or stop.whose == "" or stop.whose:find(side, 1, true)) then
				points[#points + 1] = { name = stop.name, town = stop.name:match("^[^,]+"), key = stop.name:upper(),
					continent = stop.world, north = stop.north, west = stop.west, node = stop.node }
			end
		end
	end
	return points
end

-- The flight master at a flight point: { npc, map, x, y }.
local function Master(point)
	if point.master == nil then
		point.master = false
		local least
		for _, id in ipairs(D.Town("flight")) do
			local npc = D.Npc(id)
			for _, place in ipairs(npc and L.Friendly(npc) and npc.places or {}) do
				for i = 1, #place.points, 2 do
					local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
					local yards = continent == point.continent and W.Between(point.north, point.west, north, west)
					if yards and yards <= FLIGHT.masterReach and (not least or yards < least) then
						least = yards
						point.master = { npc = npc, map = place.map, x = place.points[i], y = place.points[i + 1] }
					end
				end
			end
		end
	end
	return point.master or nil
end
-- (For whoever sends the character to a flight master: Flights.lua.)
R.FlightPoints, R.FlightMaster = Points, Master

-- Seconds from one place to another: the quickest way there is (on foot, flying, sailing), as ShyWay
-- finds it; the walk over the ground (W.Walked) while that is still being worked out.
-- Then whether that is final: the journey is known (not still being worked out, nor the walk reckoned instead).
-- And whether it is settled: nothing more is being worked out for it (a walk too long to work out, or no way
-- known at all, stays as it is reckoned), so asking again gives the same.
function R.Travel(continent, north, west, toNorth, toWest)
	local journey, state = Way.Journey(Way.Place(continent, north, west), Way.Place(continent, toNorth, toWest))
	if journey then return journey.seconds, state == nil, state ~= "working" end
	return W.Walked(continent, north, west, toNorth, toWest) / FLIGHT.walkSpeed, false, state ~= "working"
end

-- How a ride's stop reads on the card: where it is boarded, its heading and its strip. What each is called
-- and its sign are ShyWay's (Shy.Way.RIDES).
local RIDE = {
	-- (An airboat: the Skyborne's airship, to and from their isle; players call it an airship.)
	places = { boat = "Dock", zeppelin = "Zeppelin tower", airboat = "Airship landing", tram = "Deeprun Tram", portal = "Portal" },
	headings = { boat = "SAIL THERE", zeppelin = "FLY THERE", airboat = "FLY THERE", tram = "RIDE THERE", portal = "STEP THROUGH" },
	strips = { boat = "Sail there", zeppelin = "Fly there", airboat = "Fly there", tram = "Ride there", portal = "Step through" },
}
local journeys = {}          -- the journey to each stop on the last route, by the stop's key (Key)

-- What a ride is called ("Boat") and its sign ("sail": Marks.lua; nil for one with none of its own).
local function RideLook(by)
	local look = Way.RIDES[by]
	return look and look.word or "Boat", look and look.sign ~= "flight" and look.sign or nil
end

-- What a stop of ShyWay's is called on the card: a flight point by its town, a portal by the map it is on.
local function Town(stop)
	if stop.by == "flight" then return (stop.name or ""):match("^[^,]+") end
	if stop.by == "portal" and stop.map then return W.MapName(stop.map) end
	return stop.name
end

-- The flight point of a flight master stop, for its master.
local function PointOf(stop)
	for _, point in ipairs(Points()) do
		if point.node == stop.node then return point end
	end
end

-- A place of ShyWay's (a stop of a journey) as a stop's place: map, x, y in UNITS, and where it is.
local function Spot(stop, place)
	stop.continent, stop.north, stop.west = place.world, place.north, place.west
	if place.map then stop.map, stop.x, stop.y = place.map, math.floor(place.x * UNITS + 0.5), math.floor(place.y * UNITS + 0.5) end
	return stop
end

-- The stop of kind "fly" for a ride of a journey (leg): the flight master to talk to, the dock, the tower,
-- the tram's door or the portal. aloft, timed: its seconds (a crossing's with the wait), and whether they
-- were kept from riding it. land: where it lands.
local function RideStop(leg)
	local from, to = leg.from, leg.to
	local stop = Spot({ kind = "fly", actions = {}, fly = Town(to), from = Town(from), timed = leg.sure }, from)
	stop.land = Spot({ town = Town(to) }, to)
	if leg.by == "flight" then
		local point = PointOf(from)
		local master = point and Master(point)
		stop.who, stop.thing = master and master.npc.name, master and master.npc
		stop.leg, stop.aloft = "flight" .. from.node .. ">" .. to.node, leg.aboard
		if master then Place(stop, master.map, master.x, master.y) end
	else
		-- (Half a round is the wait on average: a boat leaves each dock once a round.)
		local every = leg.every and math.max(1, math.floor(leg.every / 60 + 0.5)) or nil
		stop.ferry, stop.leg, stop.crossing, stop.aloft = leg.by, "ferry" .. leg.ride, leg.ride, leg.seconds
		stop.heading, stop.strip, stop.mark = RIDE.headings[leg.by], RIDE.strips[leg.by], select(2, RideLook(leg.by))
		stop.note = every and ("Leaves about every %d min"):format(every) or nil
	end
	-- (A ride after a crossing leaves from another continent: no distance to it from here.)
	stop.yards = stop.continent == W.continent and W.WalkTo(stop.north, stop.west) or nil
	return stop
end

-- What a stop is from one route to the next: its kind and its quest, the guide's step, or the zone.
local function Key(stop)
	local first = stop.actions and stop.actions[1]
	return stop.kind .. ":" .. tostring((stop.way and stop.way.id) or (first and first.id) or (stop.view and stop.view.step and stop.view.step.index)
		or (stop.zone and stop.zone.name) or "")
end

R.ERRAND_FLY = 800   -- yards (straight): a leading errand farther than this is given a journey (a flight)
R.journeyKept = {}   -- by stop (Key): { journey, the place it is to, its level and height, where it was from }
R.JOURNEY_SLACK = 100 -- yards farther from the stop than when its journey was worked out before it is again
local function WithJourneys(route)
	if not W.Known() or UnitOnTaxi("player") then
		journeys = {}
		return route
	end
	local guided = false
	for _, stop in ipairs(route) do
		if stop.kind == "guide" and not stop.side then guided = true end
	end
	local out, now = {}, {}
	-- (The quests you picked still ahead: the way goes on through each of them, and stops after the last.)
	local picks = 0
	for _, stop in ipairs(route) do
		if stop.picked then picks = picks + 1 end
	end
	local here = Way.Place(W.continent, W.north, W.west)
	local on, last = true, nil   -- still before the lead; and the kind of the previous stop
	local origin                 -- the stop the way on starts from (its ident); nil: where the character stands
	for _, stop in ipairs(route) do
		-- Not to an unchosen zone, an errand, or a second guide step in a row. (But an errand that leads,
		-- nothing before it: a trainer a city away is flown to like anything else, not run to.)
		-- (Only one a good way off: working a journey out asks the ground of every flight point near, and
		-- an errand near enough to walk to is walked to.)
		local leadingErrand = stop.kind == "errand" and #out == 0 and stop.north
			and W.Between(W.north, W.west, stop.north, stop.west) > R.ERRAND_FLY
		if on and stop.north and (stop.kind ~= "zone" or stop.chosen) and (stop.kind ~= "errand" or leadingErrand)
			and not (stop.kind == "guide" and last == "guide") then
			local from = debugprofilestop()
			local level, up = W.Prefer(stop)
			local key = Key(stop)
			-- Whether to fly or walk is worked out once for a stop and kept (R.journeyKept): the same stop to the
			-- same place is the same journey however you walk, until the route leads somewhere else, or a flight
			-- point is learned or what you can do changes (SHY_TERRAIN, below).
			local fromN, fromW = here.north or W.north, here.west or W.west
			local kept = R.journeyKept[key]
			local journey
			-- (Walking along it only brings you nearer; farther from the stop than when it was worked out, you
			-- were carried off or went the other way, and it is worked out again.)
			local away = W.Between(fromN, fromW, stop.north, stop.west)
			-- (Kept only through a walk: a route chosen again for anything else, a quest or a setting, works it
			-- out again; those are seldom, a walk's every few dozen yards.)
			-- (And only from the same start: a journey from here is not the one from where an errand before it
			-- leaves the character, a bank or where the hearthstone lands.)
			if R.held and kept and kept.toN == stop.north and kept.toW == stop.west and kept.level == level and kept.up == up
				and kept.origin == origin and away <= (kept.away or 0) + R.JOURNEY_SLACK then
				journey = kept.journey
			else
				journey = Way.Journey(here, Way.Place(stop.continent, stop.north, stop.west, { level = level, up = up }),
					{ lead = journeys[key] })
				R.journeyKept[key] = { journey = journey, toN = stop.north, toW = stop.west, level = level, up = up,
					fromN = fromN, fromW = fromW, away = away, origin = origin }
			end
			Shy.Clock("route: journeys"):Lap(debugprofilestop() - from)
			if journey then
				now[key] = journey
				for i = 1, journey.n do
					if journey[i].by ~= "walk" then
						local ride = RideStop(journey[i])
						-- (A ride on the way to a stop of your own route says whose way it is.)
						if stop.kind == "way" or stop.picked then ride.heading = "YOUR ROUTE  \194\183  " .. (ride.heading or "FLY THERE") end
						-- (... and wears its trail's color: a place someone suggested.)
						ride.color = stop.color
						-- (Whose ride it is: R.RefitErrands keeps it with that stop.)
						ride.toward = R.Ident(stop)
						out[#out + 1] = ride
					end
				end
			end
		end
		out[#out + 1] = stop
		if stop.north then
			here, origin = Way.Place(stop.continent, stop.north, stop.west), R.Ident(stop)
		elseif stop.away and stop.lands then
			-- (Carried off: the way on is from where it sets the character down, so no flight from here follows
			-- the hearthstone to the same place.)
			here, origin = Way.Place(stop.lands.continent, stop.lands.north, stop.lands.west), R.Ident(stop)
		end
		last = stop.kind
		-- No more after the guide's step, or without a guide after the lead stop. (Your route's stops are
		-- each gone to in turn: the rides between them too.)
		if stop.picked then picks = picks - 1 end
		if stop.kind ~= "errand" and stop.kind ~= "way" and not (stop.picked and picks > 0) and ((stop.kind == "guide" and not stop.side) or not guided or (stop.kind == "zone" and not stop.chosen)) then
			on = false
		end
	end
	journeys = now
	return out
end

-- The flight points the character knew before ShyWay kept them (ns.char.flights, by name): ShyWay's now,
-- once, and this addon's list let go. (Kept while ShyWay is off: there is no one to hand it to.)
Shy:On("SHY_LOGIN", function()
	if Way.missing or not (ns.char and ns.char.flights) then return end
	for _, point in ipairs(Points()) do
		if point.node and ns.char.flights[point.key] then Way.Learn(point.node, true) end
	end
	ns.char.flights = nil
end)

-- Errands
-- Stops that aren't quests (trainer, vendor, talents), found at run time by Train.lua, Bags.lua
-- and Spec.lua. An errand never blocks the guide and can't be singled out.
--
--   R.AddErrand(id, find)    find(lead) runs on every build and returns a stop or nil:
--         title         row title, one line
--         lines         lines under it when it leads the card: { text, ... }
--         caption       card heading when it leads
--         rows()        the same lines laid out, for the card when it leads: Card.lua's entries ({ text,
--                       color, right, rightColor, icon }), in place of `lines` there
--         map, x, y     position (none: nothing to walk to)
--         thing, who    the NPC, for the map
--         with          other NPCs to speak to at the same place: { npc, ... }, marked and targeted too
--         mark          the NPC's sign (Marks.lua SIGN: "sell", "train"), also on their nameplate
--         first         goes before the guide's step (see R.Passing, which says when a place is
--                       worth going to now); otherwise after it
--         away          it carries the character off (the hearthstone): among those that go first it is
--                       the last, after everything there is to do on this side of it
--         lands         where it sets the character down ({ continent, north, west }): the rides to what
--                       comes after it are worked out from there
--         urgent        leads the whole route, before a singled-out stop, a flight or a zone, and has
--                       the lit mark and the trail on the maps, where no ground is lit meanwhile
--                       (Death.lua: nothing else can be done)
--         tone          a kind of its own to show (Marks.lua KIND) in place of a sign: its mark's
--                       emblem and color; among: that kind while the player stands where it is done,
--                       and found: what the card and the arrow say then
--         strip         its hover's heading, in place of "On your way"
--         tip(tip), menu(root), click()    tooltip extras, menu extras, row click (default: point the way)
--       lead: the stop that would lead otherwise.
--     name: what it is called where it can be turned back on ("Class trainer"); one with no name (getting
--       back to life) can't be put away.
local ERRAND_NEAR = 120      -- yards: an errand this near is done now
local errands, errandIds, errandNames = {}, {}, {}
local ranFirst = {}          -- errand ids that went first last time
local errandsFound = false   -- the last build had an errand: a fight can hold it back or take it off

function R.AddErrand(id, find, name)
	if not errands[id] then errandIds[#errandIds + 1] = id end
	errands[id], errandNames[id] = find, name
end

-- Errands put away from a row's menu with one click: off for this character, across reloads, until
-- turned back on in the card's menu (Errands). ns.char.hushed: id -> true.
function R.Hushed(id)
	local hushed = ns.char and ns.char.hushed
	return hushed ~= nil and hushed[id] == true
end

function R.CanHush(id)
	return id ~= nil and errandNames[id] ~= nil
end

function R.Hush(id, hushed)
	if not ns.char or not errandNames[id] then return end
	ns.char.hushed = ns.char.hushed or {}
	ns.char.hushed[id] = hushed and true or nil
	ns.Refresh()
end

-- Errands that serve the quests you have, or getting back to life: kept without levelling help (ns.Levelling).
local ALWAYS = { death = true, bank = true, mailbox = true }

ns.CardSwitch("errands", function(root)
	local any = false
	local levelling = ns.Levelling()
	for _, id in ipairs(errandIds) do
		if R.Hushed(id) and errandNames[id] and (levelling or ALWAYS[id]) then
			if not any then
				root:CreateTitle("Turned off")
				any = true
			end
			root:CreateCheckbox(errandNames[id], function() return not R.Hushed(id) end, function() R.Hush(id, not R.Hushed(id)) end)
		end
	end
	if any then root:CreateDivider() end
end, true)

-- Whether a fight can change the route as last built. A fight only ever holds an errand back (a finder's
-- `busy`) or takes it off (none in a fight); nothing else in a build asks about one.
function R.FightMatters()
	return errandsFound
end

-- Asked for
-- An errand the player asked to be taken to (the card's "Take me to" menu) counts as on the way
-- however far it is, so it leads until its finder has nothing left or the player says stop.
--   R.AddOffer(id, list)   list() returns what can be asked of errand `id` now: { { text, what }, ... }
--                          (what: a detail its finder understands, such as a weapon's name; none: true)
--   R.Ask(id, what)        ask for it; nil takes the asking back
--   R.Asked(id)            what was asked of it, or nil
local offers, offerIds = {}, {}

function R.AddOffer(id, list)
	if not offers[id] then offerIds[#offerIds + 1] = id end
	offers[id] = list
end

function R.Asked(id)
	local asked = ns.char and ns.char.asked
	return asked and asked[id] or nil
end

function R.Ask(id, what)
	if not ns.char then return end
	ns.char.asked = ns.char.asked or {}
	ns.char.asked[id] = what
	ns.Refresh()
end

ns.CardSwitch("offers", function(root)
	local menu
	for _, id in ipairs(offerIds) do
		-- pcall: one list's error must not break the menu.
		local ok, found = pcall(offers[id])
		for _, offer in ipairs(ok and found or {}) do
			local what = offer.what or true
			if not menu then
				menu = root:CreateButton("Take me to")
				-- (A test's stand-in root gives back a bare list.)
				if menu.SetSub then menu:SetSub("A trainer, vendor or flight point") end
				if menu.SetIcon then menu:SetIcon(Shy.UI.MenuGlyph("route")) end
			end
			menu:CreateCheckbox(offer.text, function() return R.Asked(id) == what end, function()
				R.Ask(id, R.Asked(id) ~= what and what or nil)
			end)
		end
	end
end)

-- The way soon
-- An errand off the way is weighed against the guide's way ahead: the walk it adds now, against
-- the least it adds between two of the guide's next places. Looked at as far as WAIT.soon yards on,
-- and no farther than a step that flies or hearths (the way after it is not walked). Kept while
-- the guide's place stays where it is, for WAIT.again seconds at most, as Hearth.lua keeps its own.
local WAIT = {
	soon = 1500,  -- yards of the guide's way that count as soon
	steps = 12,  -- its places looked at, at most
	nearer = 2 / 3,  -- a place ahead is waited for when it adds no more than this share of the walk added now
	again = 30,
}
local soon = {}

local function Soon()
	local main = G.active and G.active[1]
	local key = main and (tostring(G.current) .. ":" .. main.step.index) or nil
	if not key then return nil end
	if soon.key ~= key or GetTime() - soon.at > WAIT.again then soon = { key = key, at = GetTime(), places = G.Places(WAIT.steps) } end
	return soon.places
end

-- The least walk a place adds anywhere on that way, in a straight line, or nil when the way does
-- not come by. `strong`: only before the guide's next fight (what makes the character stronger
-- is not put off past one).
local function Least(continent, north, west, strong)
	local least
	local places, walked = Soon() or {}, 0
	for i = 1, #places - 1 do
		local from, to = places[i], places[i + 1]
		if (strong and #from.tasks > 0) or from.carried or from.continent ~= continent or to.continent ~= continent then break end
		local leg = W.Between(from.north, from.west, to.north, to.west)
		if walked > WAIT.soon or leg > WAIT.soon then break end
		local extra = W.Between(from.north, from.west, north, west) + W.Between(north, west, to.north, to.west) - leg
		if not least or extra < least then least = extra end
		walked = walked + leg
	end
	return least
end

-- True when a place is to be gone to now, with RULES.stay hysteresis; also returns the distance.
--   Within `reach` yards (default ERRAND_NEAR), or nearer than the lead and within RULES.onTheWay of
--   the path to it: in passing.
--   `worth`: yards of walk the errand may add when it is not in passing. It goes when the walk it
--   adds now is within that and the guide's way soon (Least) does not come a good deal nearer
--   (WAIT.nearer); `strong` as there. Without `worth` an errand only ever goes in passing, so one that
--   matters has to say what it is worth: a trainer 400 yards off every way was never led to.
-- An errand that was asked for is always on the way.
function R.Passing(id, map, x, y, lead, reach, worth, strong)
	if not map or not W.Known() then return false end
	local yards = W.Walk(map, x, y)
	if not yards then return false end
	if R.Asked(id) then return true, yards end
	local hold = ranFirst[id] and RULES.stay or 1
	if yards <= (reach or ERRAND_NEAR) * hold then return true, yards end
	local continent, north, west = W.ToWorld(map, x, y)
	if not north or continent ~= W.continent then return false, yards end
	local placed = lead and lead.north and lead.yards and lead.continent == continent
	-- The walk it adds: there and on to what leads, less the way to that. With nowhere to go on to, the walk there.
	local extra = placed and yards + W.Walked(continent, north, west, lead.north, lead.west) - lead.yards or yards
	if placed and yards <= lead.yards * hold and extra <= RULES.onTheWay * hold then return true, yards end
	if worth and extra <= worth * hold then
		local least = Least(continent, north, west, strong)
		if not least then return true, yards end
		-- (Straight lines against a straight line: the way ahead is not asked of the ground.)
		local flat = W.Between(W.north, W.west, north, west)
		if placed then flat = flat + W.Between(north, west, lead.north, lead.west) - W.Between(W.north, W.west, lead.north, lead.west) end
		if least * hold > flat * WAIT.nearer then return true, yards end
	end
	return false, yards
end

-- Returns the errands that go first (nearest first), the rest, and those that lead everything.
-- R.held: the route is chosen again only for a walk (ShyQuest.lua). Then an errand goes first just as it
-- did the last time, and the one that led still leads: two near ones would trade the lead at every step.
-- Without levelling help only the ALWAYS errands are asked for.
local function Errands(lead)
	local first, rest, now, urgent = {}, {}, {}, {}
	local was, held = ranFirst, R.held and ranFirst ~= nil
	local levelling = ns.Levelling()
	for _, id in ipairs(errandIds) do
		-- pcall: one finder's error must not break the route. (Each timed on its own: /shymon names the slow one.)
		local tick = debugprofilestop()
		local ok, stop = true, nil
		if not R.Hushed(id) and not R.errandAside[tostring(id)] and (levelling or ALWAYS[id]) then ok, stop = pcall(errands[id], lead) end
		Shy.Clock("errand: " .. tostring(id)):Lap(debugprofilestop() - tick)
		if not ok then
			geterrorhandler()(stop)
		elseif not stop then
			-- What was asked for and is no longer on offer is done with. (No stop alone says little: in a
			-- fight, on a flight or across the sea there is none for a while.)
			local asked, still = R.Asked(id), false
			local known, found = pcall(offers[id] or function() return {} end)
			for _, offer in ipairs(asked and known and found or {}) do
				if (offer.what or true) == asked then still = true end
			end
			if asked and not still then ns.char.asked[id] = nil end
		else
			errandsFound = true
			stop.kind, stop.errand, stop.actions = "errand", id, {}
			if R.Asked(id) then
				local menu = stop.menu
				stop.menu = function(root)
					root:CreateButton("Stop taking me there", function() R.Ask(id, nil) end)
					if menu then menu(root) end
				end
			end
			if stop.map then
				Place(stop, stop.map, stop.x, stop.y, W.Known() and W.Walk(stop.map, stop.x, stop.y) or nil)
			end
			local goesFirst = stop.first
			if held then goesFirst = was[id] == true end
			-- (The errand that leads waits for nothing: it stays first, whatever builds the route again, until
			-- it is done or no longer offered. The rest wait their turn behind it.)
			if R.errandLed == id then goesFirst = true end
			if stop.urgent then
				urgent[#urgent + 1] = stop
			elseif goesFirst then
				now[id] = true
				first[#first + 1] = stop
			else
				rest[#rest + 1] = stop
			end
		end
	end
	ranFirst = now
	local led = R.errandLed
	table.sort(first, function(a, b)
		-- (What carries the character off waits for every other errand that goes first: they are on this
		-- side of it, and gone or a journey back once it is used. Not even one that led stays ahead of them.)
		if (a.away == true) ~= (b.away == true) then return b.away == true end
		if led and (a.errand == led) ~= (b.errand == led) then return a.errand == led end
		return (a.yards or 0) < (b.yards or 0)
	end)
	R.errandLed = first[1] and first[1].errand or nil
	return first, rest, urgent
end

-- The first stop that isn't a flight or an errand.
function R.Lead()
	for i, stop in ipairs(R.stops) do
		if stop.kind ~= "fly" and stop.kind ~= "errand" then return stop, i end
	end
end

-- Where the route takes you now: its first stop that isn't a ride on the way (an errand that goes first is it).
function R.Heading()
	for _, stop in ipairs(R.stops) do
		if stop.kind ~= "fly" then return stop end
	end
end

-- Positioned stops before the guide's step, for the map to number (Pins.lua). Without a guide:
-- only when a flight or an errand comes before the lead stop.
function R.Before()
	local list, guided = {}, false
	for _, stop in ipairs(R.stops) do
		if stop.kind == "guide" then guided = true end
	end
	for _, stop in ipairs(R.stops) do
		if stop.kind == "guide" or stop.kind == "zone" then break end
		-- (An urgent stop is no numbered place: it has the lit mark.)
		if stop.north and not stop.urgent then list[#list + 1] = stop end
		if not guided and stop.kind ~= "fly" and stop.kind ~= "errand" and stop.kind ~= "way" and not stop.picked then break end
	end
	-- (Your route's stops are numbered always, the quests you picked with them: the map's numbers are its order.)
	local first = list[1]
	if not guided and not (first and (first.kind == "fly" or first.kind == "errand" or first.kind == "way" or first.picked)) then return {} end
	return list
end

-- Keeping stops
-- A stop that is the same stop from one build to the next keeps its table: the build's fresh one is
-- poured into it, so whoever holds it sees it as it now is and knows it for the same. What it is (its
-- ident): the NPC or quest a quest stop is for, the guide's step, the errand, the ride, the zone, your
-- route's place. What it shows (its version) is a print of what the build wrote into it and of the log's
-- word on its quests: it changes exactly when one of those does. R.changes says what came, went, changed
-- and whether the order moved: { built, added, removed, changed, moved, same }.
local keep = { stops = {}, offered = {}, MOST = 600 }
R.changes = { built = 0, added = {}, removed = {}, changed = {}, moved = false, same = false }

function R.Ident(stop)
	if stop.ident then return stop.ident end
	local kind = stop.kind
	if kind == "guide" and stop.view then
		return ("guide %d%s"):format(stop.view.step.index, stop.side and " side" or "")
	elseif kind == "errand" then
		return "errand " .. tostring(stop.errand)
	elseif kind == "zone" then
		return "zone " .. tostring(stop.zone and (stop.zone.map or stop.zone.name) or stop.who)
	elseif kind == "fly" then
		return "ride " .. tostring(stop.leg or ((stop.from or "") .. ">" .. (stop.fly or "")))
	elseif kind == "way" then
		return "way " .. tostring(stop.way and stop.way.id or stop.number)
	end
	return Key(stop)
end

-- Fields a stop is kept by, not what it shows; and tables that are the data's, known by themselves.
keep.SKIP = { yards = true, ident = true, version = true, index = true, key = true, aside = true, unfolded = true }
keep.SAME = { guide = true, step = true, parts = true, thing = true, npc = true, zone = true, places = true, ground = true,
	points = true, way = true, ghosts = true, entry = true, quest = true, members = true }
-- Where the route stood a stop (Stand's spot, with what it cost from here): its place is the stop's own.
keep.THERE = { stands = true }

-- What a value says, into `out`, at most keep.MOST words in all (past that, a table is itself: a stop
-- that says that much is taken to have changed).
function keep.Put(out, value, depth, name)
	local kind = type(value)
	if kind == "function" then return end
	if kind ~= "table" then
		out[#out + 1] = tostring(value)
		return
	end
	if name and keep.THERE[name] then
		out[#out + 1] = "+"
		return
	end
	if (name and keep.SAME[name]) or depth > 3 or #out > keep.MOST then
		out[#out + 1] = tostring(value)
		return
	end
	out[#out + 1] = "{"
	for k, v in pairs(value) do
		if type(v) ~= "function" and not (depth == 0 and keep.SKIP[k]) then
			out[#out + 1] = tostring(k)
			keep.Put(out, v, depth + 1, k)
		end
	end
	out[#out + 1] = "}"
end

-- The log's word on a quest a stop is about: its counts and whether it is done.
function keep.Log(out, id)
	local entry = id and L.entries[id]
	if not entry then return end
	out[#out + 1] = entry.complete and "c" or entry.failed and "f" or "o"
	for _, goal in ipairs(entry.goals or {}) do
		out[#out + 1] = ("%s/%s%s"):format(tostring(goal.have), tostring(goal.need), goal.finished and "!" or "")
	end
end

function R.Version(stop)
	local out = {}
	keep.Put(out, stop, 0)
	for _, action in ipairs(stop.actions or {}) do keep.Log(out, action.id) end
	for _, line in ipairs(stop.view and stop.view.lines or {}) do keep.Log(out, line.id) end
	return table.concat(out, " ")
end

-- Pours `fresh` into `kept`: nothing of the old is left, all of the new is there.
local function Pour(kept, fresh)
	for k in pairs(kept) do kept[k] = nil end
	for k, v in pairs(fresh) do kept[k] = v end
end

-- The list made by this build, with each stop that was there last time in the table it had; `was`: the
-- last build's by ident, made over to this one's. Returns what came, went and changed, and whether the
-- order of what stayed moved.
local function Keep(list, was)
	local now, seen, added, changed, order = {}, {}, {}, {}, {}
	local why
	for i, stop in ipairs(list) do
		local ident = R.Ident(stop)
		seen[ident] = (seen[ident] or 0) + 1
		if seen[ident] > 1 then ident = ident .. " #" .. seen[ident] end
		local version = R.Version(stop)
		local old = was[ident]
		if old then
			local same, at = old.version == version, old.index
			if old ~= stop then
				Pour(old, stop)
				list[i], stop = old, old
			end
			if not same then
				changed[#changed + 1] = stop
				-- (Where the first one to change first differs, for the timing's note: what a walk changes.)
				if not why then
					local was, now_ = old.version or "", version
					local at_ = 1
					while at_ <= #was and at_ <= #now_ and was:byte(at_) == now_:byte(at_) do at_ = at_ + 1 end
					why = ("%s: %s -> %s"):format(ident, was:sub(math.max(1, at_ - 24), at_ + 24), now_:sub(math.max(1, at_ - 24), at_ + 24))
				end
			end
			order[#order + 1] = at or i
		else
			added[#added + 1] = stop
		end
		stop.ident, stop.version, stop.index = ident, version, i
		now[ident] = stop
	end
	local removed = {}
	for ident, stop in pairs(was) do
		if now[ident] == nil then removed[#removed + 1] = stop end
	end
	local moved = false
	for i = 2, #order do
		if order[i] < order[i - 1] then moved = true end
	end
	for k in pairs(was) do was[k] = nil end
	for k, v in pairs(now) do was[k] = v end
	return added, removed, changed, moved, why
end

-- Looking ahead of a change
-- What a likely next route needs is worked out in quiet frames (ns.Idle), so the route that comes finds it
-- made: the minimap's ground for the stops after the lead (what it lights once the lead is done), the way to
-- where a quest a count short of done is handed in, and the way to the guide's next place. Only ever warmed,
-- never a route of its own: a wrong guess is let go of with everything else not asked for.
keep.SHORT = 1               -- counts short of done
function keep.Short(id)
	local entry = L.entries[id]
	if not entry or entry.complete then return false end
	local left = 0
	for _, goal in ipairs(entry.goals or {}) do
		if not goal.finished then left = left + math.max(1, (goal.need or 1) - (goal.have or 0)) end
	end
	return left > 0 and left <= keep.SHORT
end
function keep.Ahead()
	if not ns.Idle then return end
	ns.Idle(nil)
	if ns.warmOff then return end
	local Ground = ns.Ground
	for i = 1, math.min(#R.stops, 4) do
		local stop = R.stops[i]
		if stop.kind ~= "zone" and stop.kind ~= "fly" and stop.kind ~= "errand" then
			if i > 1 and Ground and Ground.Warm then ns.Idle(function() Ground.Warm(stop) end) end
			for _, action in ipairs(stop.actions or {}) do
				local quest = action.kind == "goal" and keep.Short(action.id) and D.Quest(action.id)
				-- (Each of its givers asked of the ground, as the route will ask once it is done.)
				if quest then ns.Idle(function() NearestGiver(quest.ends) end) end
			end
		end
	end
	-- (What the route already worked out of the guide's next steps: nothing more is asked of the guide.)
	local next_ = ahead and ahead[2]
	if next_ and next_.north then ns.Idle(function() W.WalkTo(next_.north, next_.west) end) end
end

-- Skipped (a kept hover's Skip, CardHover.lua). A quest's stop is left out of the route: in zone mode it is set
-- aside, its mark resting in a look of its own on the maps (Marks.lua's "aside") and its hover offering it back
-- (R.Include); following a guide it is gone, its marks with it. Kept for the character (ns.char.aside: quest ID ->
-- "aside" | "gone"). Picked onto your route again (R.Go), a quest comes back. An errand waits until a reload.
R.errandAside = {}           -- errand id -> true
local function SetAside()
	ns.char.aside = type(ns.char.aside) == "table" and ns.char.aside or {}
	return ns.char.aside
end
function R.Skip(stop)
	if stop.kind == "errand" then
		R.errandAside[tostring(stop.errand)] = true
	else
		local aside, how = SetAside(), ns.Following() and "gone" or "aside"
		for _, action in ipairs(stop.actions or {}) do
			if action.id then
				aside[action.id] = how
				if ns.Plan then ns.Plan.Unpick(action.id) end
			end
		end
	end
	ns.Refresh()
end
function R.Include(stop)
	local aside = SetAside()
	for _, action in ipairs(stop.actions or {}) do
		if action.id then aside[action.id] = nil end
	end
	ns.Refresh()
end
-- How a quest was skipped: "aside", "gone", or nil.
function R.Aside(id)
	local aside = ns.char and ns.char.aside
	return type(aside) == "table" and aside[id] or nil
end

-- A stop without its skipped quests (R.Skip): itself where none is, a copy with the rest, or nil where all are.
-- `how`: only those skipped so ("gone"); nil: any.
function R.Unskipped(stop, how)
	local keep, dropped = {}, false
	for _, action in ipairs(stop.actions or {}) do
		local aside = R.Aside(action.id)
		if aside and (not how or aside == how) then dropped = true else keep[#keep + 1] = action end
	end
	if not dropped then return stop end
	if #keep == 0 then return nil end
	local copy = {}
	for k, v in pairs(stop) do copy[k] = v end
	copy.actions = keep
	return copy
end

-- Errands that go first (`now`, nearest first), split for your own route, whose first stop is `lead`: those
-- you stand at (RULES.ownHere) or pass on the way to it (adding no more than RULES.ownWay to the walk), which go
-- before your route, and the rest, which wait for it. What carries you off (the hearthstone) always waits: your
-- route is on this side of it. Returns the rest, then those first.
local function YourWay(now, lead)
	local rest, first = {}, {}
	local placed = lead.north and lead.yards and lead.continent == W.continent
	for _, stop in ipairs(now) do
		local yards = not stop.away and stop.north and stop.continent == W.continent and stop.yards or nil
		local mine = false
		if yards then
			mine = yards <= RULES.ownHere
			if not mine and placed and yards <= lead.yards then
				local extra = yards + (W.Walked(W.continent, stop.north, stop.west, lead.north, lead.west) or math.huge) - lead.yards
				mine = extra <= RULES.ownWay
			end
		end
		-- (Said on the card: what it is done on the way to.)
		if mine then
			stop.along = ("On your way to %s"):format(lead.title or lead.who or "your next stop")
			first[#first + 1] = stop
		else
			rest[#rest + 1] = stop
		end
	end
	return rest, first
end

-- The stops of the quests you picked (Plan.lua), taken out of `stops`: by quest, the nearest stop for it (a
-- stop for two picked quests stands for both).
local function Picks(stops)
	local out = {}
	if not ns.Plan then return out end
	for _, entry in ipairs(ns.Plan.List and ns.Plan.List() or {}) do
		local id = entry.quest
		if id and not out[id] then
			local best, at
			for i, stop in ipairs(stops) do
				if Involves(stop, id) and (not best or (stop.yards or math.huge) < (best.yards or math.huge)) then best, at = stop, i end
			end
			if best then
				table.remove(stops, at)
				for _, action in ipairs(best.actions) do out[action.id] = out[action.id] or best end
			end
		end
	end
	return out
end

-- A dungeon run leads (Run.lua): the route is its steps alone.
function R.Running()
	local G = ns.Guide
	return G.current ~= nil and G.current.run ~= nil and ns.Following()
end

function R.Build()
	-- (Counted: what is worked out once a build, R.Objectives, knows when it is stale.)
	R.built = (R.built or 0) + 1
	errandsFound = false
	local tick = debugprofilestop()
	local guided = GuideStops()
	Shy.Clock("route: guide stops"):Lap(debugprofilestop() - tick)
	-- Quests of the live steps: super-tracking one must not add a second stop above the step.
	local led = {}
	for _, stop in ipairs(guided) do
		for _, action in ipairs(stop.view.actions) do led[action.id] = true end
	end
	tick = debugprofilestop()
	-- A dungeon run (Run.lua) is a mode of its own: its steps alone, and what can't wait (the way back to your
	-- body, a flight under way, the legs of a journey). No quest nearby, errand, place of your own or zone joins it.
	local run = R.Running()
	local nearby = run and {} or WithoutGuided(Build(), guided)
	-- The quests you picked (Plan.lua) go with your route, in its order: their stops leave the rest's.
	local picks = Picks(nearby)
	-- (What you set aside is left out until a reload: R.Skip.)
	for i = #nearby, 1, -1 do
		local kept = R.Unskipped(nearby[i])
		if kept then nearby[i] = kept else table.remove(nearby, i) end
	end
	-- R.offGuide: guide-only mode is in force. R.skipped: available quests on this map left out by it.
	R.offGuide, R.skipped = nil, 0
	local leading = guided[1]
	if not run and leading and not leading.side and not OnlyGrind(leading) and ns.Pickups() and not R.Extras() then
		R.offGuide = true
		for _, quest in ipairs(W.map and L.StartsOn(W.map) or {}) do
			if not led[quest.id] and not G.Uses(quest.id) then R.skipped = R.skipped + 1 end
		end
		nearby = WithoutExtras(nearby)
	end
	local route = Order(nearby, led)
	Shy.Clock("route: nearby stops"):Lap(debugprofilestop() - tick)
	-- The guide leads, after a singled-out stop and any detours.
	tick = debugprofilestop()
	local at = (route[1] and route[1].chosen) and 2 or 1
	local lead = guided[1]
	local went = {}
	ahead = nil
	if lead and not lead.side then
		local grind = OnlyGrind(lead)
		local first, rest = {}, {}
		for i = at, #route do
			local stop = route[i]
			local goes, why = Detour(stop, lead, grind)
			if goes then
				-- The reason, for the card's heading: "clock", "failed", "class", "grind", or true (on the way).
				stop.detour = why or (grind and "grind") or true
				went[stop.kind .. stop.actions[1].id] = true
				first[#first + 1] = stop
			else
				rest[#rest + 1] = stop
			end
		end
		for i = #route, at, -1 do route[i] = nil end
		for _, stop in ipairs(first) do route[#route + 1] = stop end
		at = #route + 1
		for _, stop in ipairs(rest) do route[#route + 1] = stop end
	end
	detoured = went
	-- With only side steps live, timed stops still go before them.
	if not (lead and not lead.side) then
		while route[at] and route[at].clock do at = at + 1 end
	end
	local steps = HereFirst(guided)
	for i, stop in ipairs(steps) do table.insert(route, at + i - 1, stop) end
	ledStep = route[1] and route[1].kind == "guide" and route[1].view.step.index or nil
	Shy.Clock("route: the guide's detours"):Lap(debugprofilestop() - tick)
	-- Errands on the way go right after a singled-out stop; the rest after the guide's steps,
	-- or without a guide after the lead stop.
	local head = (route[1] and route[1].chosen) and 2 or 1
	tick = debugprofilestop()
	local now, later, urgent = Errands(route[head])
	if run then now, later = {}, {} end
	Shy.Clock("route: errands"):Lap(debugprofilestop() - tick)
	-- (After the guide's steps, wherever they stand now. Kept so a fight or a loot can put the errands
	-- back without building the route again: only they come and go then.)
	local after = math.min(#route + 1, head + 1)
	for i, stop in ipairs(#steps > 0 and route or {}) do
		if stop.kind == "guide" then after = i + 1 end
	end
	keep.errandHead = route[head] and R.Ident(route[head]) or false
	keep.errandAfter = after > 1 and route[after - 1] and R.Ident(route[after - 1]) or false
	-- Your own route (Plan.lua) leads everything but what can't wait: the places you sent yourself to. The errands
	-- were weighed against what the guide or the nearest stop would lead to; ahead of your route goes only one
	-- you stand at or pass on the way to its first stop (YourWay), the rest after it.
	tick = debugprofilestop()
	local own = not run and ns.Plan and ns.Plan.Stops(function(entry) return picks[entry.quest] end) or {}
	local ahead = {}
	if own[1] then now, ahead = YourWay(now, own[1]) end
	for i, stop in ipairs(later) do table.insert(route, after + i - 1, stop) end
	for i, stop in ipairs(now) do table.insert(route, head + i - 1, stop) end
	for i, stop in ipairs(own) do table.insert(route, i, stop) end
	for i, stop in ipairs(ahead) do table.insert(route, i, stop) end
	Shy.Clock("route: your plan"):Lap(debugprofilestop() - tick)
	tick = debugprofilestop()
	local zoned = run and route or AddZones(route)
	Shy.Clock("route: zones"):Lap(debugprofilestop() - tick)
	R.stops = WithJourneys(zoned)
	-- What can't wait leads everything: a singled-out stop, a flight, a zone to go to.
	for i, stop in ipairs(urgent) do table.insert(R.stops, i, stop) end
	tick = debugprofilestop()
	R.offered = GuideStops(true)
	Shy.Clock("route: offered steps"):Lap(debugprofilestop() - tick)
	-- Standing on more than one ground at once (one lies inside another): the leading stop knows what
	-- else is found here (R.Found names it, the card's caption says the kinds): its own ({ kind, name =
	-- what it is got from }), then each other quest's stop ({ kind, name = the quest, quest = true }).
	-- (A stop is the table it was last build: what was found with it then is not what is found now.)
	for _, stop in ipairs(R.stops) do stop.amongAll = nil end
	tick = debugprofilestop()
	local lead = R.Lead()
	if lead and lead.among then
		local all, seen = { { kind = lead.among, name = lead.source and lead.source.name } }, {}
		local function Add(kind, name, quest)
			local key = kind .. (name or "")
			if not seen[key] then
				seen[key] = true
				all[#all + 1] = { kind = kind, name = name, quest = quest }
			end
		end
		for _, each in ipairs(lead.also or {}) do Add(each.kind, each.name) end
		for _, stop in ipairs(R.stops) do
			if stop ~= lead and stop.among and stop.kind ~= "errand" then
				Add(stop.among, stop.actions[1] and stop.actions[1].title, true)
				for _, each in ipairs(stop.also or {}) do Add(each.kind, stop.actions[1] and stop.actions[1].title, true) end
			end
		end
		if #all > 1 then lead.amongAll = all end
	end
	Shy.Clock("route: what is found with the lead"):Lap(debugprofilestop() - tick)
	-- (Last: every stop kept is the table it was, holding what this build made of it.)
	tick = debugprofilestop()
	local added, removed, changed, moved, why = Keep(R.stops, keep.stops)
	-- (The catch-up steps are drawn on both maps too: one that came, went or changed is a change.)
	local offeredAdded, offeredRemoved, offeredChanged, offeredMoved = Keep(R.offered, keep.offered)
	local offeredSame = #offeredAdded == 0 and #offeredRemoved == 0 and #offeredChanged == 0 and not offeredMoved
	Shy.Clock("route: keeping stops"):Lap(debugprofilestop() - tick)
	R.changes = { built = R.built, added = added, removed = removed, changed = changed, moved = moved, why = why,
		same = #added == 0 and #removed == 0 and #changed == 0 and not moved and offeredSame }
	tick = debugprofilestop()
	if not R.changes.same then keep.Ahead() end
	Shy.Clock("route: ahead"):Lap(debugprofilestop() - tick)
	wipe(goalStops)
	for _, stop in ipairs(R.stops) do
		local action = stop.actions and stop.actions[1]
		if stop.shape and action and action.kind == "goal" then goalStops[action.id] = stop end
	end
	return R.stops
end

-- The errand that leads a list of stops, by its ident: the first one before any stop that is neither an
-- errand nor a ride. nil: none does.
function keep.Leading(stops)
	for _, stop in ipairs(stops) do
		if stop.kind == "errand" then return R.Ident(stop) end
		if stop.kind ~= "fly" then return nil end
	end
end

-- Errands only, on the route as it stands: a fight holds them back, and a loot may bring one on.
-- The stops beside them are not chosen again, and the rides stay as they were worked out: an errand that
-- goes first goes before the rides to what it goes ahead of (it is done on this side of them), and a ride
-- to an errand stays with its errand, or goes with it.
function R.RefitErrands()
	local tick = debugprofilestop()
	local route, at, rides = {}, {}, {}
	for _, stop in ipairs(R.stops) do
		local toward = stop.kind == "fly" and stop.toward
		if toward and toward:find("^errand ") then
			rides[toward] = rides[toward] or {}
			table.insert(rides[toward], stop)
		elseif stop.kind ~= "errand" then
			route[#route + 1] = stop
			at[R.Ident(stop)] = #route
		end
	end
	-- (Your own route's stops, which lead: errands come after the last of them, as R.Build puts them.)
	local ownFirst, ownLast
	for i, stop in ipairs(route) do
		if stop.kind == "way" or stop.picked then
			ownFirst, ownLast = ownFirst or i, i
		end
	end
	local head = keep.errandHead and at[keep.errandHead] or 1
	if not head or head < 1 then head = 1 end
	if ownLast and head <= ownLast then head = ownLast + 1 end
	local after = keep.errandAfter and at[keep.errandAfter]
	after = after and after + 1 or math.min(#route + 1, head + 1)
	if ownLast and after <= ownLast then after = ownLast + 1 end
	errandsFound = false
	local now, later, urgent = Errands(route[head])
	if R.Running() then now, later = {}, {} end
	local ahead = {}
	if ownFirst then now, ahead = YourWay(now, route[ownFirst]) end
	for i, stop in ipairs(later) do table.insert(route, after + i - 1, stop) end
	local nowAt = head + ((after <= head) and #later or 0)
	while nowAt > (ownLast or 0) + 1 and route[nowAt - 1].kind == "fly" do nowAt = nowAt - 1 end
	for _, stop in ipairs(now) do
		for _, ride in ipairs(rides[R.Ident(stop)] or {}) do
			table.insert(route, nowAt, ride)
			nowAt = nowAt + 1
		end
		table.insert(route, nowAt, stop)
		nowAt = nowAt + 1
	end
	-- One you stand at, or pass on the way to your route's first stop: before it, and before the rides to it.
	if #ahead > 0 then
		local spot = ownFirst
		while spot > 1 and route[spot - 1].kind == "fly" do spot = spot - 1 end
		for _, stop in ipairs(ahead) do
			for _, ride in ipairs(rides[R.Ident(stop)] or {}) do
				table.insert(route, spot, ride)
				spot = spot + 1
			end
			table.insert(route, spot, stop)
			spot = spot + 1
		end
	end
	for i, stop in ipairs(urgent) do table.insert(route, i, stop) end
	-- The rides were worked out for what led then. Another errand at the head (or none now) where there are
	-- rides, or one far enough to be flown to: the whole route is built again on the next pulse, and they
	-- with it. Seldom: an errand come or gone from the lead, not every fight.
	local led, leads = keep.Leading(R.stops), keep.Leading(route)
	if led ~= leads then
		local ridden = next(rides) ~= nil
		for _, stop in ipairs(route) do
			if stop.kind == "fly" then ridden = true end
		end
		local first = now[1]
		local far = first and first.north and first.continent == W.continent
			and W.Between(W.north, W.west, first.north, first.west) > R.ERRAND_FLY
		if (ridden or far) and ns.RefreshRoute then ns.RefreshRoute() end
	end
	R.stops = route
	R.built = (R.built or 0) + 1
	local added, removed, changed, moved = Keep(R.stops, keep.stops)
	R.changes = { built = R.built, added = added, removed = removed, changed = changed, moved = moved,
		same = #added == 0 and #removed == 0 and #changed == 0 and not moved }
	Shy.Clock("route: errands only"):Lap(debugprofilestop() - tick)
	return R.stops
end

-- Refreshes distances only; the order changes on the next Build. Each stop is a way asked of the ground,
-- so a walk measures them a few at a time: `from` (the first stop, counting the route's then the offered
-- ones) and `count` of them. Returns where the next slice begins, or nil once all are measured. With
-- neither, all at once.
local function MeasureOne(stop)
	if stop.kind == "guide" or stop.kind == "fly" then
		if stop.north and stop.continent == W.continent and W.Known() then
			stop.yards = W.WalkTo(stop.north, stop.west)
		end
	elseif stop.map then
		local yards = W.Walk(stop.map, stop.x, stop.y)
		if yards or W.Known() then stop.yards = yards end
	end
end
-- most: only the first `most` of the route's stops (a walk: only those that may come to lead are asked;
-- the rest, and the offered ones, are measured when the route is built).
function R.Measure(from, count, most)
	from = from or 1
	local last = count and from + count - 1 or math.huge
	local stops, offered = R.stops, R.offered
	local route = #stops
	local whole = most and math.min(route, most) or route + #offered
	for index = from, math.min(last, whole) do
		MeasureOne(index <= route and stops[index] or offered[index - route])
	end
	if last < whole then return last + 1 end
	return nil
end

-- Describing a stop

local VERBS = { turnin = "Turn in", pickup = "Pick up" }
-- Where an objective's item comes from, when the objective text doesn't name it.
local FROM = { sells = "Sold by %s", holds = "Found in %s", drops = "Dropped by %s", gives = "From %s",
	reward = "%s gives it for %s" }
-- A source as text ("Sold by Narret Shadowgrove"; "Grimbooze Thunderbrew gives it for Thunderbrew"), or nil.
function FROM.Text(source)
	if not source or source.name == "" or not FROM[source.how] then return nil end
	local quest = source.quest and D.Quest(source.quest)
	if quest then return FROM.reward:format(source.name, quest.name) end
	return FROM[source.how]:format(source.name)
end

-- The nearest source of an objective as text ("Sold by Narret Shadowgrove"), or nil. A vendor in reach wins.
function R.From(id, index)
	local goal = L.Goals(id)[index]
	if not goal or goal.finished then return nil end
	local lists, sources = {}, {}
	for _, token in ipairs(L.Asked(goal)) do GoalPlaces(token, lists, nil, sources) end
	local best, least, sells
	for i, places in ipairs(lists) do
		local source = sources[i]
		local map, _, _, yards = W.Nearest(places)
		if map and source and source.name ~= "" and FROM[source.how] then
			yards = yards or math.huge
			local seller = source.how == "sells" and yards <= RULES.buyNear
			if not best or (seller and not sells) or (seller == sells and yards < least) then best, least, sells = source, yards, seller end
		end
	end
	return FROM.Text(best)
end

-- What a stop is sent for before its own task, and where that is had ("Needs Flawed Power Stone",
-- "Found in Flawed Power Stones"): a guide's step moved there (stop.needs), or a quest's own stop
-- standing on it. nil for a stop that waits for nothing.
function R.Needs(stop)
	local source = stop.needs or (stop.source and stop.source.needs and stop.source) or nil
	if not source then return nil end
	return "Needs " .. source.needs, FROM.Text(source)
end

-- Text of the first unfinished objective, preferring `index`.
local function NextObjective(id, index)
	local objectives = C_QuestLog.GetQuestObjectives(id) or {}
	local own = index and objectives[index]
	if own and not own.finished and own.text and own.text ~= "" then return own.text end
	for _, objective in ipairs(objectives) do
		if not objective.finished and objective.text and objective.text ~= "" then return objective.text end
	end
end

-- Returns title, lines, and a place name when the stop isn't simply a distance away.
function R.Describe(stop)
	if stop.kind == "guide" then
		-- Title: the step's NPC, else the first open line of the task its position is for.
		local view, lines, title, own = stop.view, {}, nil, nil
		local led = stop.led or view.led
		for _, line in ipairs(view.lines) do
			if not line.done then
				lines[#lines + 1] = Shy.UI.PlainText(line.text)
				title = title or lines[#lines]
				if led and line.of == led then own = own or lines[#lines] end
			end
		end
		if #lines == 0 then lines[1] = "Step " .. view.step.index end
		local who = view.who
		if stop.led then who = stop.who end
		return who or own or title or lines[1], lines
	end
	if stop.kind == "zone" then
		local zone = stop.zone
		return zone.name, { Z.Summary(zone), "Start with " .. zone.hub.thing.name },
			not stop.yards and "On another continent" or nil
	end
	if stop.kind == "fly" and stop.ferry then
		-- "Zeppelin to Undercity": where it leaves from, and how long it takes with the wait.
		local lines = { ("%s, %s"):format(RIDE.places[stop.ferry] or RIDE.places.boat, stop.from) }
		if stop.aloft then
			local minutes = math.max(1, math.floor(stop.aloft / 60 + 0.5))
			lines[2] = (stop.timed and "%d min with the wait" or "About %d min with the wait"):format(minutes)
		end
		local where = not stop.yards and stop.continent ~= W.continent and W.MapName(stop.map) or nil
		return (RideLook(stop.ferry)) .. " to " .. stop.fly, lines, where
	end
	if stop.kind == "fly" then
		-- (How long it is in the air is the flight's own to show, once aboard.)
		return "Fly to " .. stop.fly, { stop.who and ("%s, %s"):format(stop.who, stop.from) or ("Flight master in " .. stop.from) }
	end
	if stop.kind == "errand" or stop.kind == "way" then
		return stop.title or stop.who or "Something to do", stop.lines or {}
	end
	local first = stop.actions[1]
	local title = stop.who or first.title
	local lines = {}
	for _, action in ipairs(stop.actions) do
		if action.kind == "goal" then
			lines[#lines + 1] = NextObjective(action.id, stop.objective) or "Continue this quest"
			local from = FROM.Text(stop.source)
			if from and #stop.actions == 1 then
				if stop.source.needs then lines[#lines + 1] = "Needs " .. stop.source.needs end
				lines[#lines + 1] = from
			end
		elseif action.failed then
			lines[#lines + 1] = "Failed: abandon and retake " .. action.title
		elseif action.held then
			lines[#lines + 1] = "Start " .. action.title .. " from your bags"
		elseif action.item then
			local item = C_Item.GetItemNameByID(action.item) or (D.Item(action.item) or {}).name or "an item"
			local how = action.from == "o" and "Holds " or action.from == "v" and "Sells " or "Drops "
			lines[#lines + 1] = ("%s%s%s: starts %s"):format(how, item,
				action.chance and (" (" .. action.chance .. "%)") or "", action.title)
		elseif stop.who then
			lines[#lines + 1] = VERBS[action.kind] .. " " .. action.title
		else
			lines[#lines + 1] = "Ready to turn in"
		end
	end
	local where
	if stop.dungeon then
		where = "inside " .. (D.DungeonName(stop.dungeon) or "a dungeon")
	elseif stop.map and stop.map ~= W.map and not stop.yards then
		where = W.MapName(stop.map)
	end
	return title, lines, where
end

-- Pointing at a stop

-- The arrow points at a stop (Arrow.lua). The game's own map pin is not set: it would stand over the stop's mark
-- and take its clicks (a click on the game's pin clears it), and the route's numbered places, its trail and the
-- arrow say all it would. Your own pin, set on the map, is yours (Plan.lua).
local function Waypoint(stop)
	if stop.map and ns.Arrow and ns.Arrow.ToStop then ns.Arrow.ToStop(stop) end
end

-- The quest a stop puts on your route (R.Go): its first that isn't one to pick up, else its first. nil: none.
function R.PickOf(stop)
	local actions = stop and stop.actions or {}
	for _, action in ipairs(actions) do
		if action.kind ~= "pickup" then return action end
	end
	return actions[1]
end

-- A click on a quest's stop puts it on your route, on top (Plan.lua); a second click takes it off. The lead
-- stop, guide steps, flights and errands are never put there: a click only points the way or runs them.
function R.Go(stop)
	-- (Your own pick: the errand that led lets it go first; an errand picked is the one that leads now.)
	R.errandLed = stop.kind == "errand" and stop.errand or nil
	if stop.kind == "guide" then
		local tracked = false
		for _, action in ipairs(stop.actions) do
			if action.kind ~= "pickup" and L.Has(action.id) then
				-- `quiet`: shows the way without counting as a choice.
				if ns.char.singled ~= action.id then quiet = action.id end
				Shy.Waypoint.Quest(action.id)
				tracked = true
				break
			end
		end
		if not tracked and stop.x then Waypoint(stop) end
		return
	end
	if stop.kind == "fly" then
		if stop.map then Waypoint(stop) end
		return
	end
	if stop.kind == "errand" or stop.kind == "way" then
		if stop.click then stop.click() elseif stop.map then Waypoint(stop) end
		return
	end
	if stop.kind == "zone" then
		if stop.chosen then
			R.pinnedZone = nil
		else
			R.pinnedZone = stop.zone.map
			Shy.Waypoint.Quest(0)
			Waypoint(stop)
		end
		ns.Refresh()
		return
	end
	R.pinnedZone = nil
	local action = R.PickOf(stop)
	if not action then return end
	-- (The arrow shows the way there without counting as a choice.)
	local function Point()
		if action.kind ~= "pickup" then
			quiet = action.id
			Shy.Waypoint.Quest(action.id)
		else
			Waypoint(stop)
		end
	end
	-- (Only the stop you are taken to now is pointed at alone: one behind an errand that goes first is put on
	-- your route, and so goes before that errand.)
	-- (On your route already, as its own stop or as the place it was picked at: a click takes it off.)
	local picked = ns.Plan and ns.Plan.Picked(action.id)
	if stop == R.Heading() and not stop.chosen and not picked then
		Point()
		return
	end
	if stop.chosen or picked then
		-- Off your route (a quest you picked), or no longer the one the game's arrow was turned to.
		if ns.Plan then
			ns.Plan.Unpick(action.id)
			if stop.picked then ns.Plan.Unpick(stop.picked.quest) end
		end
		ns.char.singled = nil
		Shy.Waypoint.Quest(0)
	elseif ns.Plan and stop.map and stop.x then
		if R.Aside(action.id) then SetAside()[action.id] = nil end
		-- Onto your route, on top: what you picked last leads, unless it is taken in passing (Plan.lua). The
		-- arrow points there where it goes first.
		-- (Named for the quest, its giver or where it is under it: where the route has no stop for it, that is the
		-- stop you see.)
		local where = stop.who and W.MapName(stop.map) and (stop.who .. ", " .. W.MapName(stop.map)) or stop.who
		ns.Plan.Pick(action.id, { map = stop.map, x = stop.x, y = stop.y, title = action.title or R.Describe(stop), where = where },
			action.kind == "pickup")
		local first = ns.Plan.List()[1]
		if first and first.quest == action.id then Point() end
	else
		-- (Nowhere on a map, inside a dungeon: the one quest heads the rest.)
		Choose(action.id)
	end
	ns.Refresh()
end

-- A journey kept (R.journeyKept) is of the flights known and what the character can do: a flight point
-- learned, a fall that can be slowed or water walked on, or the roads kept to make it another one.
Shy:On("SHY_TERRAIN", function(why)
	if why == "flights" or why == "moves" or why == "roads" then R.Forget() end
end)
-- ... and of where you are: a loading screen, or somewhere else at once (the stone, a portal: R.LEAP yards
-- between two looks) makes every kept journey and nearest place another one. Walking on into the next zone
-- along the line is no reason: what was worked out for it still stands.
R.LEAP = 500
R.forgotten = 0   -- counts R.Forget: what others keep of where you were (Hearth.lua) says which it was of
function R.Forget()
	R.forgotten = R.forgotten + 1
	wipe(R.journeyKept)
	if W.ForgetNearest then W.ForgetNearest() end
end
do
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:SetScript("OnEvent", R.Forget)
	local lastN, lastW, lastC
	C_Timer.NewTicker(1, function()
		local n, w, c = W.north, W.west, W.continent
		if n and lastN and (c ~= lastC or W.Between(n, w, lastN, lastW) > R.LEAP) then R.Forget() end
		lastN, lastW, lastC = n, w, c
	end)
end
