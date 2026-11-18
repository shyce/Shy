-- Your route: the places you send yourself to, ahead of everything else the card would lead to. It is a
-- stack: what you added last is where you are taken first, but a stop on the way to it or right by it is
-- taken in passing (Order), unless you put them in an order of your own. Any place is a stop: a Find result
-- or service (Find.lua), a spot set on the world map (the game's own waypoint), a /way, and a quest picked on
-- the card or a map (Route.lua, R.Go), which goes wherever its quest's work is until it is done. The route
-- leads the card as a guide does (Route.lua puts its stops first: a place as kind "way", a quest as its own
-- stop, picked; with the rides on the way to each before it); both maps draw ShyWay's one trail to the stop
-- that leads, and the arrow follows it. A stop reached leaves the route and the next leads; with none left,
-- what led before leads again (the card's heading says your guide comes after your route).
--
--   Plan.List() -> { stop, ... }       { id, title, where, map, x, y (0-9999), from = "find" | "map" | "way" | "quest",
--                                      mark, by, class (who suggested it, and their class: its trail's color),
--                                      farm (an item ShyFarm farms there: its ground is lit, and it stays
--                                      while you are there, until the farming ends: Plan.EndFarm),
--                                      quest, pickup (a quest picked: its ID; picked to take it: it goes once
--                                      accepted, else once the quest leaves the log),
--                                      along (taken in passing: { how = "way" | "near", of = the title of
--                                      the stop it is on the way to, or right by }) }
--   Plan.EndFarm([item])               the farming of an item (any, with none) ends: its stop goes
-- Bus: SHY_FARM_GROUND (item, on) as you step onto or off the ground where you farm an item (ShyFarm starts and
-- pauses on it).
--   Plan.Add(place [, at])             onto the route, on top (where it leads), or before its `at`th stop
--   Plan.Go(place)                     the same: what you added last leads (a spot set on the map does this)
--   Plan.Pick(quest, place [, pickup]) a quest onto the route (place: where its stop is now); Plan.Unpick(quest)
--   Plan.Picked(quest) -> index        the quest's stop on the route, if picked
--   Plan.Remove(i), Plan.Move(from, to), Plan.Clear(), Plan.IndexOf(entry) -> i
--   Plan.Auto([on]) -> on              the route keeps its own order (newest first, stops on the way in
--                                      passing; the default), or the one you put it in by hand
--   Plan.Has(map, x, y) -> index       the stop at that place, if any
--   Plan.Stops(live) -> { route stop, ... }   for Route.lua: a place as kind "way", numbered, the route's caption
--                                      and menu; a quest as live(entry) gives its stop now (none: left out this
--                                      time); a place the player has reached leaves the route as it is asked
--   Plan.Watch(fn)                     fn() whenever the route changes (Find draws it)
-- Kept per character (ns.char.plan).

local ADDON, ns = ...
local W, R = ns.World, ns.Route

local Plan = {}
ns.Plan = Plan

local UNITS = 10000
local ARRIVE = 8             -- yards from a stop at which it is reached
-- Yards (straight): a stop that adds no more than `detour` to the walk to the one ahead is on the way to it,
-- and one within `near` of it is right by it (Order).
local WAY = { detour = 150, near = 60 }
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
	if Plan.Auto() then
		Order()
	else
		-- (In your own order nothing is taken in passing.)
		for _, each in ipairs(Saved().stops) do each.along = nil end
	end
	ns.Refresh()
	for _, fn in ipairs(watchers) do fn() end
end

-- Where a stop is, in words: the place's own, else its map's name and where on it.
local function Where(place)
	if place.where then return place.where end
	local name = W.MapName(place.map) or "Map"
	return ("%s %.1f, %.1f"):format(name, place.x / 100, place.y / 100)
end

-- (A quest's stop moves with its work: it is no place of the route's.)
function Plan.Has(map, x, y)
	for i, stop in ipairs(Plan.List()) do
		if not stop.quest and stop.map == map and math.abs(stop.x - x) <= SAME and math.abs(stop.y - y) <= SAME then return i end
	end
end

function Plan.Picked(quest)
	for i, stop in ipairs(Plan.List()) do
		if stop.quest == quest then return i end
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
-- (Kept with the route: the game keeps its waypoint across a reload and a login, and says so then.)
function Plan.OwnWaypoint(map, x, y)
	if not ns.char then return end
	Saved().own = map and { map = map, x = x, y = y } or nil
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

-- The stop a place makes, put into the route at `at` (none: on top, where it leads), without telling anyone yet.
local function Put(place, at)
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
		by = place.by, class = place.class, farm = place.farm, quest = place.quest, pickup = place.pickup }
	plan.next = stop.id + 1
	table.insert(stops, math.max(1, math.min(at or 1, #stops + 1)), stop)
	return stop
end

function Plan.Add(place, at)
	if not (place and place.map and place.x and place.y) then return end
	-- (Put before a stop of your choosing: the order is yours from then on.)
	if at then Saved().byHand = true end
	local stop = Put(place, at)
	Changed()
	return stop
end

-- (The newest leads: going there now is putting it on the route. Kept apart for what the callers mean.)
function Plan.Go(place)
	return Plan.Add(place)
end

function Plan.Pick(quest, place, pickup)
	if not (quest and place and place.map and place.x and place.y) then return end
	local was = Plan.Picked(quest)
	if was then return Plan.List()[was] end
	local stop = Put({ map = place.map, x = place.x, y = place.y, title = place.title, where = place.where,
		from = "quest", quest = quest, pickup = pickup or nil })
	Changed()
	return stop
end

function Plan.Unpick(quest)
	local i = Plan.Picked(quest)
	if i then Plan.Remove(i) end
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
	Saved().byHand = true
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

function Plan.Auto(on)
	if on ~= nil then
		Saved().byHand = not on or nil
		Changed()
	end
	return not Saved().byHand
end

-- A stop in the world: its continent, north, west (nil where its map isn't on one).
local function Placed(stop)
	local continent, north, west = W.ToWorld(stop.map, stop.x, stop.y)
	return continent, north, west
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

-- The stops in the order you go to them: the newest first, as a stack (the last place you sent yourself to is
-- where you are taken first), unless you put them in an order of your own (Plan.Move, Plan.Add's `at`). In
-- that, a stop on the way to the one ahead (it adds little to the walk there) is taken in passing before it,
-- and one right by it just after it: entry.along says so ({ how = "way" | "near", of = the other's title }),
-- and the card with it.
function Order()
	local stops = Plan.List()
	for _, each in ipairs(stops) do each.along = nil end
	if #stops < 2 then return end
	-- (The newest first: ids are given in the order stops are put on the route.)
	local left = { unpack(stops) }
	table.sort(left, function(a, b) return (a.id or 0) > (b.id or 0) end)
	local at = {}
	for _, each in ipairs(left) do at[each] = { Placed(each) } end
	-- Yards between two stops (or from where you stand: `from` a { continent, north, west }), nil across the sea.
	local function Apart(from, to)
		if not (from[1] and from[1] == to[1]) then return nil end
		return W.Between(from[2], from[3], to[2], to[3])
	end
	local out = {}
	local here = { W.continent, W.north, W.west }
	while #left > 0 do
		local target = left[1]
		local to = at[target]
		-- On the way: the one the walk to the target bends least for, within WAY.detour; nearest you first.
		local pick, least
		local straight = Apart(here, to)
		for i = 2, #left do
			local by = at[left[i]]
			local there, on = Apart(here, by), Apart(by, to)
			if straight and there and on and on > WAY.near and there + on - straight <= WAY.detour and (not least or there < least) then
				pick, least = i, there
			end
		end
		if pick then
			local stop = table.remove(left, pick)
			stop.along = { how = "way", of = target.title }
			out[#out + 1] = stop
			here = at[stop]
		else
			table.remove(left, 1)
			out[#out + 1] = target
			here = to
			-- Right by it: taken while you are there, nearest first.
			local near = {}
			for i = #left, 1, -1 do
				local yards = Apart(to, at[left[i]])
				if yards and yards <= WAY.near then
					local stop = table.remove(left, i)
					stop.along = { how = "near", of = target.title }
					near[#near + 1] = { stop = stop, yards = yards }
				end
			end
			table.sort(near, function(a, b) return a.yards < b.yards end)
			for _, each in ipairs(near) do
				out[#out + 1] = each.stop
				here = at[each.stop]
			end
		end
	end
	for i, stop in ipairs(out) do stops[i] = stop end
end

-- The route's stops for Route.lua. A stop the player stands at leaves the route first (and the game's
-- waypoint with it, where it was one).
function Plan.Stops(live)
	local stops = Plan.List()
	local lead = stops[1]
	-- (Where you farm stays while you are there: it goes when the farming ends. A quest goes when it is done,
	-- unless the route has no stop for it, when it is the place it was picked at: reached, it goes.)
	if lead and not lead.farm and not (lead.quest and live and live(lead)) and W.Known() then
		local continent, north, west = Placed(lead)
		if continent == W.continent and W.Between(W.north, W.west, north, west) <= ARRIVE then
			table.remove(stops, 1)
			if lead.from == "map" then ClearMapWaypoint() end
			for _, fn in ipairs(watchers) do fn() end
		end
	end
	local out, given = {}, {}
	for _, each in ipairs(stops) do
		-- A quest: its stop as the route has it now, wherever its work has gone (where it is kept for the order).
		local stop = each.quest and live and live(each)
		if stop and not given[stop] then
			given[stop] = true
			stop.chosen, stop.picked = true, each
			if stop.map and stop.x then each.map, each.x, each.y = stop.map, stop.x, stop.y end
			out[#out + 1] = stop
		elseif not stop then
			-- (A place, or a quest the route has no stop for: one it leaves out, too high or gray, not on your guide's
			-- way, or one your guide's step has. It is the place it was picked at, under its name.)
			out[#out + 1] = each
		end
	end
	local count = #out
	for i, each in ipairs(out) do
		if each.picked then
			-- (A picked quest is said to be yours as a place of your route is; its own words are the quest's.)
			each.number, each.caption, each.along = i, Plan.Caption(each.picked, i, count), Plan.Along(each.picked)
		else
			out[i] = Plan.Place(each, i, count)
		end
	end
	return out
end

-- What the card says of a stop of your route, the `i`th of `count`: its caption ("YOUR ROUTE  ·  2 OF 3"; one
-- taken in passing, "ON YOUR WAY" or "WHILE YOU'RE THERE"), and the line that says why, or nil.
local ALONG = {
	way = { caption = "ON YOUR WAY", line = "On your way to %s" },
	near = { caption = "WHILE YOU'RE THERE", line = "Right by %s" },
}
function Plan.Caption(entry, i, count)
	local along = entry.along and ALONG[entry.along.how]
	return ("%s  \194\183  %d OF %d"):format(along and along.caption or "YOUR ROUTE", i, count)
end
function Plan.Along(entry)
	local along = entry.along and ALONG[entry.along.how]
	return along and along.line:format(entry.along.of or "your next stop") or nil
end

-- A place of the route as Route.lua's stop: the `i`th of `count`.
function Plan.Place(each, i, count)
	local continent, north, west = Placed(each)
	-- (Its key is its own: the maps keep what they gathered for a stop by it, so two stops never share one.)
	local stop = {
		key = "way" .. each.id .. (each.farm and (":farm" .. each.farm) or ""),
		kind = "way", way = each, number = i, title = each.title, lines = { each.where }, map = each.map, x = each.x, y = each.y,
		continent = continent, north = north, west = west, mark = "go", actions = {},
		caption = Plan.Caption(each, i, count), along = Plan.Along(each),
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
	-- Where you farm (ShyFarm): an item, the ground of what you farm it from; a creature ("n" and its ID), its own.
	-- Lit in the finder's color, the stop at the heart of the camp chosen in it; a click shows it all on the map.
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
			local npc = R.FarmCreature and R.FarmCreature(each.farm)
			local thing = npc and ns.Data.Npc(npc) or (type(each.farm) == "number" and ns.Data.Item(each.farm))
			stop.among = on and "farm" or nil
			stop.found = ("Farm %s here"):format(thing and thing.name or "it")
			stop.caption = ("WHERE YOU FARM  \194\183  %d OF %d"):format(i, count)
			stop.click = function()
				ns.ShowOnMap(each.title, { { map = each.map, x = each.x, y = each.y } }, false, ground)
			end
		end
	end
	-- (By the route's own place for it: a quest with no stop now is left out of the numbers.)
	stop.menu = function(root)
		root:CreateButton("Remove from my route", function() Plan.Remove(Plan.IndexOf(each)) end)
		if i > 1 then root:CreateButton("Go here first", function() Plan.Move(Plan.IndexOf(each), 1) end) end
		if ns.Find then root:CreateButton("Plan my route", function() ns.Find.Toggle(true) end) end
		root:CreateButton("Clear my route", function() Plan.Clear() end)
	end
	stop.menuHint = "Route"
	return stop
end

function Plan.IndexOf(entry)
	for i, each in ipairs(Plan.List()) do
		if each == entry then return i end
	end
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
-- A quest picked goes once it is done with: taken, where it was picked to be taken; else gone from the log
-- (handed in or abandoned).
local events = CreateFrame("Frame")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:SetScript("OnEvent", function(_, event, quest)
	if not ns.char then return end
	if event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
		local i = quest and Plan.Picked(quest)
		if i and (event == "QUEST_REMOVED" or Plan.List()[i].pickup) then Plan.Remove(i) end
		return
	end
	-- (A pin borrowed for its chat link is no waypoint of the player's.)
	if clearing or Shy.UI.PinBorrowed() then return end
	local point = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()
	-- (A pin set from a chat link has a plain { x, y } position, not a vector: read the fields.)
	local x, y = point and point.position and point.position.x, point and point.position and point.position.y
	if point and point.uiMapID and x and y then
		x, y = x * UNITS, y * UNITS
		local own = Saved().own
		if own and own.map == point.uiMapID and math.abs(own.x - x) <= SAME and math.abs(own.y - y) <= SAME then return end
		-- (Already a stop: the same pin said again, as the game does at login or when a borrowed pin is put back.)
		if Plan.Has(point.uiMapID, x, y) then return end
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
