-- Your route: the places you send yourself to, in order, ahead of everything else the card would lead to.
-- Any place is a stop: a Find result or service (Find.lua), a spot set on the world map (the game's own
-- waypoint), a /way. The route leads the card as a guide does (Route.lua puts its stops first, kind "way",
-- with the rides on the way to each before it); both maps draw ShyWay's one trail to the stop that leads,
-- and the arrow follows it. A stop reached leaves the route and the next leads; with none left, what led
-- before leads again (the card's heading says your guide comes after your route).
--
--   Plan.List() -> { stop, ... }       { id, title, where, map, x, y (0-9999), from = "find" | "map" | "way", mark,
--                                      by, class (who suggested it, and their class: its trail's color),
--                                      farm (an item ShyFarm farms there: its ground is lit, and it stays
--                                      while you are there, until the farming ends: Plan.EndFarm) }
--   Plan.EndFarm([item])               the farming of an item (any, with none) ends: its stop goes
-- Bus: SHY_FARM_GROUND (item, on) as you step onto or off the ground where you farm an item (ShyFarm starts and
-- pauses on it).
--   Plan.Add(place [, at])             to the route's end, or before its `at`th stop; place as a stop
--   Plan.Go(place)                     first, leading now (a spot set on the map does this)
--   Plan.Remove(i), Plan.Move(from, to), Plan.Clear()
--   Plan.Quickest([on]) -> on          stops kept in their quickest order (ShyWay's journeys), or as put
--   Plan.Has(map, x, y) -> index       the stop at that place, if any
--   Plan.Stops() -> { route stop, ... }   for Route.lua: kind "way", numbered, the route's caption and menu;
--                                      a stop the player has reached leaves the route as it is asked
--   Plan.Watch(fn)                     fn() whenever the route changes (Find draws it)
-- Kept per character (ns.char.plan).

local ADDON, ns = ...
local W, R = ns.World, ns.Route

local Plan = {}
ns.Plan = Plan

local UNITS = 10000
local ARRIVE = 8             -- yards from a stop at which it is reached
local TRY_ALL = 7            -- stops put in their quickest order by trying every order; more, the nearest next each time
local SAME = 3               -- map units (of 10000): two stops this near on one map are the same place
local watchers = {}
-- Where you farm (ShyFarm): on its ground within `on` yards of a spawn of it, off it past `off` (the gap keeps the
-- edge from flickering); `was` by item, what was said last (bus SHY_FARM_GROUND (item, on) when it changes).
local FARM = { on = 40, off = 60, was = {} }

local function Saved()
	local plan = ns.char.plan
	if type(plan) ~= "table" or type(plan.stops) ~= "table" then
		plan = { stops = {}, next = 1 }
		ns.char.plan = plan
	end
	return plan
end

function Plan.List()
	return Saved().stops
end

function Plan.Watch(fn)
	watchers[#watchers + 1] = fn
end

local Order

local function Changed()
	if Saved().quickest then Order() end
	ns.Refresh()
	for _, fn in ipairs(watchers) do fn() end
end

-- Where a stop is, in words: the place's own, else its map's name and where on it.
local function Where(place)
	if place.where then return place.where end
	local name = W.MapName(place.map) or "Map"
	return ("%s %.1f, %.1f"):format(name, place.x / 100, place.y / 100)
end

function Plan.Has(map, x, y)
	for i, stop in ipairs(Plan.List()) do
		if stop.map == map and math.abs(stop.x - x) <= SAME and math.abs(stop.y - y) <= SAME then return i end
	end
end

-- "Share with", in any menu of a place: it goes to someone as a route they can take (Shy.Way.Share).
-- place: { map, x, y (0-9999), title }, or a function giving one as the row is clicked. No row while
-- ShyWay is off.
function ns.ShareMenu(root, place)
	local share = Shy.Way.Share
	if Shy.Way.missing or not (share and share.Write) then return nil end
	return share.Write(root, function()
		local at = type(place) == "function" and place() or place
		if not (at and at.map and at.x and at.y) then return nil end
		return { map = at.map, x = at.x / UNITS, y = at.y / UNITS, title = at.title }
	end)
end

-- The game's own waypoint, set by this addon to point somewhere (Route.lua), is no stop of the route.
local own = nil
function Plan.OwnWaypoint(map, x, y)
	own = map and { map = map, x = x, y = y } or nil
end

-- The game's waypoint goes when its stop leaves the route.
local clearing = false
local function ClearMapWaypoint()
	if Shy.Waypoint.Has() then
		clearing = true
		Shy.Waypoint.Clear()
		clearing = false
	end
end

function Plan.Add(place, at)
	if not (place and place.map and place.x and place.y) then return end
	local plan = Saved()
	local stops = plan.stops
	local was = Plan.Has(place.map, place.x, place.y)
	if was then table.remove(stops, was) end
	-- (The world map holds one waypoint: setting another moves its stop.)
	if place.from == "map" then
		for i = #stops, 1, -1 do
			if stops[i].from == "map" then table.remove(stops, i) end
		end
	end
	local stop = { id = plan.next or 1, title = place.title or "Waypoint", where = Where(place), map = place.map,
		x = math.floor(place.x + 0.5), y = math.floor(place.y + 0.5), from = place.from or "find", mark = place.mark,
		by = place.by, class = place.class, farm = place.farm }
	plan.next = stop.id + 1
	table.insert(stops, math.max(1, math.min(at or #stops + 1, #stops + 1)), stop)
	Changed()
	return stop
end

function Plan.Go(place)
	local stop = Plan.Add(place, 1)
	-- (Going there now is going there first, whatever order the rest would be quickest in.)
	if stop and Saved().quickest then
		local stops = Plan.List()
		for i, each in ipairs(stops) do
			if each == stop then table.remove(stops, i) break end
		end
		table.insert(stops, 1, stop)
		Saved().quickest = false
		Changed()
	end
	return stop
end

function Plan.Remove(i)
	local stops = Plan.List()
	local stop = stops[i]
	if not stop then return end
	table.remove(stops, i)
	if stop.from == "map" then ClearMapWaypoint() end
	Changed()
end

function Plan.Move(from, to)
	local stops = Plan.List()
	local stop = stops[from]
	if not stop or from == to then return end
	table.remove(stops, from)
	table.insert(stops, math.max(1, math.min(to, #stops + 1)), stop)
	Saved().quickest = false
	Changed()
end

function Plan.Clear()
	local had = false
	for _, stop in ipairs(Plan.List()) do
		if stop.from == "map" then had = true end
	end
	wipe(Plan.List())
	if had then ClearMapWaypoint() end
	Changed()
end

function Plan.Quickest(on)
	if on ~= nil then
		Saved().quickest = on and true or nil
		Changed()
	end
	return Saved().quickest == true
end

-- A stop in the world: its continent, north, west (nil where its map isn't on one).
local function Placed(stop)
	local continent, north, west = W.ToWorld(stop.map, stop.x, stop.y)
	return continent, north, west
end

-- Seconds from one place to another as ShyWay would go (on foot, the rides there are); far where unknown.
local FAR = 1e7
local function Seconds(fromContinent, fromNorth, fromWest, stop)
	local continent, north, west = Placed(stop)
	if not (continent and fromContinent) then return FAR end
	local journey = Shy.Way.Journey(Shy.Way.Place(fromContinent, fromNorth, fromWest), Shy.Way.Place(continent, north, west))
	return journey and journey.seconds or FAR
end

-- How each stop is got to from the one before it (the first from where the player stands), as ShyWay goes:
-- { seconds (nil where no way is known), rides = { "Fly to Orgrimmar", "Zeppelin to Grom'gol", ... } } a
-- stop, and the seconds of them all.
function Plan.Legs()
	local out, total = {}, 0
	local continent, north, west = W.continent, W.north, W.west
	for i, stop in ipairs(Plan.List()) do
		local leg = { rides = {} }
		local to, toNorth, toWest = Placed(stop)
		local journey = continent and to and Shy.Way.Journey(Shy.Way.Place(continent, north, west), Shy.Way.Place(to, toNorth, toWest))
		if journey then
			leg.seconds = journey.seconds
			total = total + journey.seconds
			for k = 1, journey.n do
				local part = journey[k]
				if part.by ~= "walk" then
					local look = Shy.Way.RIDES[part.by]
					local where = (part.to.name or ""):match("^[^,]+") or ""
					leg.rides[#leg.rides + 1] = (part.by == "flight" and "Fly" or look and look.word or "Ride") .. " to " .. where
				end
			end
		else
			total = nil
		end
		out[i] = leg
		continent, north, west = to, toNorth, toWest
	end
	return out, total
end

-- The stops in their quickest order from where the player stands: every order tried where they are few,
-- else the quickest next stop each time.
function Order()
	local stops = Plan.List()
	if #stops < 2 or not W.continent then return end
	local n = #stops
	local from = {}            -- from[i][j]: seconds from stop i to stop j (0: from the player)
	for i = 0, n do
		from[i] = {}
		local continent, north, west
		if i == 0 then
			continent, north, west = W.continent, W.north, W.west
		else
			continent, north, west = Placed(stops[i])
		end
		for j = 1, n do
			if j ~= i then from[i][j] = Seconds(continent, north, west, stops[j]) end
		end
	end
	local best, bestCost = nil, math.huge
	if n <= TRY_ALL then
		local order, used = {}, {}
		local function Try(depth, at, cost)
			if cost >= bestCost then return end
			if depth > n then
				best, bestCost = { unpack(order) }, cost
				return
			end
			for j = 1, n do
				if not used[j] then
					used[j], order[depth] = true, j
					Try(depth + 1, j, cost + from[at][j])
					used[j] = false
				end
			end
		end
		Try(1, 0, 0)
	else
		best = {}
		local used, at = {}, 0
		for depth = 1, n do
			local pick, least = nil, math.huge
			for j = 1, n do
				if not used[j] and from[at][j] < least then pick, least = j, from[at][j] end
			end
			used[pick], best[depth], at = true, pick, pick
		end
	end
	local was = { unpack(stops) }
	for depth, j in ipairs(best) do stops[depth] = was[j] end
end

-- The route's stops for Route.lua. A stop the player stands at leaves the route first (and the game's
-- waypoint with it, where it was one).
function Plan.Stops()
	local stops = Plan.List()
	local lead = stops[1]
	-- (Where you farm stays while you are there: it goes when the farming ends.)
	if lead and not lead.farm and W.Known() then
		local continent, north, west = Placed(lead)
		if continent == W.continent and W.Between(W.north, W.west, north, west) <= ARRIVE then
			table.remove(stops, 1)
			if lead.from == "map" then ClearMapWaypoint() end
			for _, fn in ipairs(watchers) do fn() end
		end
	end
	local out, count = {}, #stops
	for i, each in ipairs(stops) do
		local continent, north, west = Placed(each)
		-- (Its key is its own: the maps keep what they gathered for a stop by it, so two stops never share one.)
		local stop = {
			key = "way" .. each.id .. (each.farm and (":farm" .. each.farm) or ""),
			kind = "way", way = each, number = i, title = each.title, lines = { each.where }, map = each.map, x = each.x, y = each.y,
			continent = continent, north = north, west = west, mark = "go", actions = {},
			caption = ("YOUR ROUTE  \194\183  %d OF %d"):format(i, count),
		}
		-- A place someone suggested: the route says whose it is, and its trail wears their class's color.
		if each.by then
			stop.by = each.by
			stop.color = Shy.Way.Share and Shy.Way.Share.Color(each.class) or nil
			stop.caption = ("SHARED WITH YOU  \194\183  %d OF %d"):format(i, count)
			stop.lines = { each.where, "From " .. each.by }
		end
		stop.yards = continent and continent == W.continent and W.WalkTo(north, west) or nil
		stop.click = function() ns.ShowOnMap(each.title, { { map = each.map, x = each.x, y = each.y } }, true) end
		-- Where you farm an item (ShyFarm): the ground of what you farm it from, lit in the finder's color, the stop
		-- at the heart of the camp chosen in it; a click shows it all on the map.
		if each.farm and R.FarmGround then
			local ground = R.FarmGround(each.farm)
			if #ground > 0 then
				-- (Marked as an objective of the farm's kind: the loot's bag in its turquoise. Standing on its ground,
				-- the work is where you are, as a quest's camp: the minimap shows the creatures as dots, the arrow
				-- leads nowhere.)
				stop.ground, stop.who, stop.farm, stop.tone = ground, each.title, each.farm, "farm"
				-- On its ground: what is found here is what you farm (the arrow's and the card's emblem and words,
				-- as a quest's camp), and the one judge of it tells ShyFarm, which starts or pauses on it.
				local yards = R.FarmGroundYards and R.FarmGroundYards(each.farm)
				local was = FARM.was[each.farm]
				local on = yards ~= nil and (yards <= FARM.on or (was == true and yards <= FARM.off))
				if on ~= was then
					FARM.was[each.farm] = on
					Shy:Fire("SHY_FARM_GROUND", each.farm, on)
				end
				local item = ns.Data.Item(each.farm)
				stop.among = on and "farm" or nil
				stop.found = ("Farm %s here"):format(item and item.name or "it")
				stop.caption = ("WHERE YOU FARM  \194\183  %d OF %d"):format(i, count)
				stop.click = function()
					ns.ShowOnMap(each.title, { { map = each.map, x = each.x, y = each.y } }, false, ground)
				end
			end
		end
		stop.menu = function(root)
			root:CreateButton("Remove from my route", function() Plan.Remove(i) end)
			if i > 1 then root:CreateButton("Go here first", function() Plan.Move(i, 1) end) end
			if ns.Find then root:CreateButton("Plan my route", function() ns.Find.Toggle(true) end) end
			root:CreateButton("Clear my route", function() Plan.Clear() end)
		end
		stop.menuHint = "Route"
		out[i] = stop
	end
	return out
end

function Plan.EndFarm(item)
	if item then FARM.was[item] = nil else wipe(FARM.was) end
	local stops = Saved().stops
	local gone = false
	for i = #stops, 1, -1 do
		local stop = stops[i]
		if stop.farm and (item == nil or stop.farm == item) then
			table.remove(stops, i)
			gone = true
			if stop.from == "map" then ClearMapWaypoint() end
		end
	end
	if gone then Changed() end
end

-- The game's own waypoint: set on the world map (or by /way) it leads now; cleared, its stop goes.
local events = CreateFrame("Frame")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:SetScript("OnEvent", function()
	-- (A pin borrowed for its chat link is no waypoint of the player's.)
	if clearing or Shy.UI.PinBorrowed() or not ns.char then return end
	local point = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()
	-- (A pin set from a chat link has a plain { x, y } position, not a vector: read the fields.)
	local x, y = point and point.position and point.position.x, point and point.position and point.position.y
	if point and point.uiMapID and x and y then
		x, y = x * UNITS, y * UNITS
		if own and own.map == point.uiMapID and math.abs(own.x - x) <= SAME and math.abs(own.y - y) <= SAME then return end
		Plan.Go({ map = point.uiMapID, x = x, y = y, title = "Waypoint", from = "map" })
		return
	end
	-- Cleared: its stop goes.
	local stops = Plan.List()
	for i = #stops, 1, -1 do
		if stops[i].from == "map" then
			table.remove(stops, i)
			Changed()
		end
	end
end)
