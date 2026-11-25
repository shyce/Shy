-- The finder window, in two panes.
-- Left, what to find:
--   a zone's quests, by how they stand with you (Why.lua)
--   your friends online, as ShyMaps knows them
--   with ShyFarm, what to farm: the best farms for you and your favorites
--   the nearest of each town service: innkeeper, flight master, trainers, vendors, spirit healers ...
--     Each service has the game's own picture and a star that keeps it on the map.
-- Right, what was found, under a search box that looks everything up by name (a number is a quest's
-- ID). On the farm side it only searches what you could farm.
-- Click shows a result on the world map (ns.ShowOnMap). Right-click points the arrow at it. On the
-- farm side a click farms it. /shy quest find [name].

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Tips = ns.Data, ns.World, ns.Log, ns.Route, ns.Tips
local UI = Shy.UI
local C = UI.colors

local F = {}
ns.Find = F

local WIDTH, HEIGHT, PAD = 660, 620, 14   -- (tall enough for every row of the left pane: it never scrolls as made)
local HEADER = UI.HEAD.window.line + UI.LINE   -- the header, down to its line's foot
local ROW, SHOWN = 36, 40    -- row height; most rows listed for a search or a service
local HEAD, ZONE = 24, 30    -- a heading's height in the list, and the zone's
local SIDE = 196             -- the left pane: what to find
local SIDE_ROW, SIDE_HEAD = 24, 22   -- a category's row, and a section's heading over its rows
local TILE = 20              -- a category's picture
local STAR = 14              -- the star that keeps a service on the map
local SEARCH = 30            -- the search box's row, over the list
local MARK = 18              -- a row's mark
local RAIL = 17              -- the middle of the marks, from a row's left: a fold's caret stands there too
local NAMES = 34             -- where names begin, from a row's left
local EACH = 14              -- most results per kind when searching
local SPREAD = 4             -- a service that stands in more places than this is a row per place (spirit healers)
local STOP = 34              -- a stop of your route's row height
-- An item's picture in a result's row; a favorite's row (ShyFarm), its picture and its graph; a creature's sign.
local FAV = { ICON = 22, ROW = 64, BIG = 36, GRAPH_W = 132, GRAPH_H = 42, SIGN = 16 }
local KINDS = { "quests", "npcs", "objects", "items" }
local WORD = { quests = "Quest", npcs = "Creature", objects = "Object", items = "Item" }

-- Places, found by name before anything else: every zone and city and the continents (the map opens on one), every
-- dungeon and raid at its way in, and every flight point by its name. Read once, the first time a search asks.
local places
local function Places()
	if places then return places end
	places = {}
	local function Add(name, words, map, x, y, whole)
		if not (name and map) then return end
		places[#places + 1] = { name = name, lower = name:lower(), words = words, whole = whole,
			points = { { map = map, x = math.floor((x or 0.5) * 9999 + 0.5), y = math.floor((y or 0.5) * 9999 + 0.5) } } }
	end
	local world = C_Map.GetFallbackWorldMapID()
	for _, continent in ipairs(C_Map.GetMapChildrenInfo(world, Enum.UIMapType.Continent) or {}) do
		if continent.mapType == Enum.UIMapType.Continent then
			Add(continent.name, "Continent", continent.mapID, 0.5, 0.5, true)
			for _, zone in ipairs(C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone) or {}) do
				if zone.mapType == Enum.UIMapType.Zone then Add(zone.name, "Zone, " .. continent.name, zone.mapID, 0.5, 0.5, true) end
			end
		end
	end
	for _, one in ipairs(Shy.Instances and Shy.Instances.List() or {}) do
		local door = ns.Run and ns.Run.Door and ns.Run.Door(one.map)
		if door then
			local info = C_Map.GetMapInfo(door.map)
			local levels = Shy.Instances.Levels(one)
			Add(one.name, (one.kind == "raid" and "Raid" or "Dungeon") .. (levels and (", levels " .. levels) or "")
				.. (info and (", " .. info.name) or ""), door.map, door.x, door.y)
		end
	end
	for _, stop in ipairs(Shy.Way.Stops and Shy.Way.Stops() or {}) do
		if stop.by == "flight" and stop.map and stop.name then Add(stop.name, "Flight point", stop.map, stop.x, stop.y) end
	end
	return places
end

local box, input, scroll, empty, zoneButton
local side, rule             -- the left pane, and the hairline between the panes
local wide = WIDTH - SIDE - PAD   -- the list's share of the window's width (its rows are wide - PAD * 2 across): it flows (Lay)
local cats = {}              -- the left pane's rows, in order
local chosen = "quests"      -- the row lit: a category's key, or nil while a search is typed
local rows, heads = {}, {}   -- the list's rows, and its headings
local results = {}           -- what the list holds: results, and { head } / { fold } / { zone } entries
local open, heading = false, nil
local query = ""             -- the search box's text
local town                   -- the service listed, as its chip asked: { key }
local browsed, picked        -- the zone listed when nothing is asked; picked: by the player, not followed
local shownSig               -- what the zone list said when the rows were made (Why.Zone's sig)
local folded = { missed = true, done = true }   -- headings folded shut
-- Your route (Plan.lua) heads the list: its heading, then its stops. While you search it folds to the heading
-- alone; adding a stop, or a click on its heading, opens it.
local routeHead, stopRows, routeShut = nil, {}, false

-- Locations

-- A record's places as points: { { map, x, y }, ... }. Places inside a dungeon are skipped.
local function Points(places, out)
	for _, place in ipairs(places or {}) do
		if not place.dungeon then
			for i = 1, #place.points, 2 do
				out[#out + 1] = { map = place.map, x = place.points[i], y = place.points[i + 1] }
			end
		end
	end
	return out
end

local function ThingPoints(kind, ids)
	local out = {}
	for _, id in ipairs(ids) do
		local thing = D.Thing(kind == "objects" and "o" or "n", id)
		if thing then Points(thing.places, out) end
	end
	return out
end

local function ItemPoints(id)
	local out = {}
	local item = D.Item(id)
	for _, source in ipairs(item and item.sources or {}) do
		local thing = D.Thing(source.kind, source.id)
		if thing and (source.kind ~= "v" or L.Friendly(thing)) then Points(thing.places, out) end
	end
	return out
end

-- A quest's remaining objectives if it is in the log, else its turn-in or quest giver.
local function QuestPoints(id)
	if L.Has(id) and not L.entries[id].complete then return (R.Where(id)) end
	local quest = D.Quest(id)
	local out = {}
	for _, token in ipairs(quest and (L.Has(id) and quest.ends or quest.starts) or {}) do
		if token.kind == "n" or token.kind == "o" then
			local thing = D.Thing(token.kind, token.id)
			if thing and (token.kind == "o" or L.Friendly(thing)) then Points(thing.places, out) end
		end
	end
	return out
end

-- The nearest point and its distance (nil when none can be measured).
local function Nearest(points)
	local best, least
	for _, point in ipairs(points) do
		local yards = W.Distance(point.map, point.x, point.y)
		if not best or (yards and (not least or yards < least)) then best, least = point, yards or least end
	end
	return best, least
end

-- Results

-- A quest's state for this character, and its mark, when Why.lua isn't loaded (a new file waits for a
-- client restart).
local function Standing(id)
	local entry = L.entries[id]
	if entry then return entry.complete and "ready to turn in" or "in your log", entry.complete and "turnin" or "goal" end
	if L.Done(id) then return "done" end
	local quest = D.Quest(id)
	if quest and L.CanStart(quest) then return "available", "pickup" end
	return "not available yet"
end

-- "2 of 3 done", or "ready to turn in", for a quest in the log.
local function Progress(id)
	local entry = L.entries[id]
	if not entry or entry.complete then return "ready to turn in" end
	local done, all = 0, 0
	for _, goal in ipairs(entry.goals or {}) do
		all = all + 1
		if goal.finished then done = done + 1 end
	end
	return all > 0 and ("%d of %d done"):format(done, all) or "in your log"
end

-- A quest's detail line and mark. In a zone's list (result.browse) every row is a quest under a heading that
-- says how it stands, so the line says what that heading doesn't: who gives it, how far along it is, what
-- it waits on. A search says how it stands.
local function QuestDetail(result, quest)
	local Why = ns.Why
	local level = quest.level > 0 and (" " .. quest.level) or ""
	if not Why then
		local standing, mark = Standing(quest.id)
		result.mark = mark
		return ("%s%s, %s"):format(WORD.quests, level, standing)
	end
	local line, state = Why.Line(quest)
	result.state, result.mark = state, Why.MarkOf(quest, state)
	result.quiet = state == "done" or state == "missed" or state == "skip"
	if not result.browse then return ("%s%s, %s"):format(WORD.quests, level, line) end
	local words = line
	if state == "available" then
		local start = Why.Starts(quest)
		words = start and (start.item and ("from " .. start.name) or Why.StartsWords(start)) or line
	elseif state == "log" then
		words = Progress(quest.id)
	elseif state == "done" then
		words = nil
	end
	return (quest.level > 0 and ("Level " .. quest.level) or "Any level") .. (words and (", " .. words) or "")
end

-- A result is { kind, name, ids, detail, points, exact, mark }; points and detail are filled in when it is
-- first listed. A result that stands for one place of many (split) comes with its points.
local function Finish(result)
	if result.finished then return result end
	result.finished = true
	local kind, id = result.kind, result.ids[1]
	if kind == "places" then
		local place = result.place
		result.detail, result.points, result.exact = place.words, place.points, true
	elseif kind == "quests" then
		local quest = D.Quest(id)
		result.detail = QuestDetail(result, quest)
		result.points = QuestPoints(id)
	elseif kind == "items" then
		local item = D.Item(id)
		local first = item.sources[1]
		local from = first and D.Thing(first.kind, first.id)
		local how = first and (first.kind == "v" and "sold by " or first.kind == "o" and "in " or "from ") or ""
		result.detail = WORD[kind] .. (from and (", " .. how .. from.name .. (first.chance and (" " .. first.chance .. "%") or "")) or "")
		result.points = ItemPoints(id)
	else
		local thing = D.Thing(kind == "objects" and "o" or "n", id)
		local words = { result.word or WORD[kind] }
		if kind == "npcs" then
			if thing.title and not result.word then words[#words + 1] = thing.title end
			local level = D.LevelText(thing)
			if level and not result.split then words[#words + 1] = level end
		end
		result.points = result.points or ThingPoints(kind, result.ids)
		result.exact = result.split or #result.points <= 4
		result.detail = table.concat(words, ", ")
	end
	local nearest, yards = Nearest(result.points)
	-- A quest being worked on is gone to where its stop would stand: the heart of the best camp, not
	-- whichever spawn is nearest.
	if kind == "quests" and L.Has(id) and not L.entries[id].complete then
		local best = R.Best(id, nil, "find" .. id)
		if best then nearest, yards = best, best.yards end
	end
	result.nearest, result.yards = nearest, yards
	if nearest and not yards then result.detail = result.detail .. ", " .. (W.MapName(nearest.map) or "far away") end
	return result
end

-- Everything whose name contains `text`: prefix matches first, up to EACH per kind,
-- creatures and objects of one name merged. A number is a quest's ID ("#" before it or not).
function F.Search(text)
	local list = {}
	text = strtrim(text or ""):lower()
	local id = tonumber(text:match("^#?(%d+)$") or "")
	if id then
		local quest = D.Quest(id)
		if quest then list[1] = { kind = "quests", name = quest.name, ids = { id } } end
		return list
	end
	if #text < 2 then return list end
	-- (Places first: "Westfall" is the zone before anyone named for it.)
	local starts, has = {}, {}
	for _, place in ipairs(Places()) do
		local at = place.lower:find(text, 1, true)
		if at then
			local into = at == 1 and starts or has
			into[#into + 1] = { kind = "places", name = place.name, ids = { place.name }, place = place }
		end
	end
	local taken = 0
	for _, from in ipairs({ starts, has }) do
		for _, result in ipairs(from) do
			if taken < EACH and #list < SHOWN then
				taken = taken + 1
				list[#list + 1] = result
			end
		end
	end
	for _, kind in ipairs(KINDS) do
		local starts, has, by = {}, {}, {}
		for _, entry in ipairs(D.Names(kind)) do
			local at = entry[2]:find(text, 1, true)
			if at then
				local result = by[entry[2]]
				if result and kind ~= "quests" and kind ~= "items" then
					result.ids[#result.ids + 1] = entry[1]
				else
					result = { kind = kind, name = D.Name(kind, entry[1]), ids = { entry[1] } }
					by[entry[2]] = result
					local into = at == 1 and starts or has
					into[#into + 1] = result
				end
			end
		end
		local taken = 0
		for _, from in ipairs({ starts, has }) do
			for _, result in ipairs(from) do
				if taken < EACH and #list < SHOWN then
					taken = taken + 1
					list[#list + 1] = result
				end
			end
		end
	end
	return list
end

-- Where an item comes from, nearest first (no place known last): { kind = "npc" | "object" | "vendor", id, name,
-- chance, level, map, x, y (shares of the map), yards } each; nil for an item the data doesn't know.
local SOURCE_KIND = { n = "npc", o = "object", v = "vendor" }
function F.Sources(id)
	local item = D.Item(id)
	if not item then return nil end
	local out = {}
	for _, source in ipairs(item.sources) do
		local thing = SOURCE_KIND[source.kind] and not (source.kind == "n" and D.Dropless(source.id, id))
			and D.Thing(source.kind, source.id)
		if thing and (source.kind ~= "v" or L.Friendly(thing)) then
			local nearest, yards = Nearest(Points(thing.places, {}))
			out[#out + 1] = { kind = SOURCE_KIND[source.kind], id = source.id, name = thing.name, chance = source.chance,
				level = source.kind == "n" and D.LevelText(thing) or nil, map = nearest and nearest.map,
				x = nearest and nearest.x / 10000, y = nearest and nearest.y / 10000, yards = yards }
		end
	end
	table.sort(out, function(a, b)
		if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
		if a.yards and a.yards ~= b.yards then return a.yards < b.yards end
		if (a.map ~= nil) ~= (b.map ~= nil) then return a.map ~= nil end
		return a.id < b.id
	end)
	return out
end

-- The nearest town service of a kind the finder lists (D.Town's: "auction", "repair", "inn" ...): { name, map, x, y
-- (shares of the map), yards }, or nil with none on this continent.
function F.Nearest(kind)
	local first = F.Town(kind)[1]
	local at = first and first.nearest
	if not at then return nil end
	return { name = first.name, map = at.map, x = at.x / 10000, y = at.y / 10000, yards = first.yards }
end

-- Town services of `kind` (D.Town), the trainers titled `title`, or the trainers of `profession`: friendly
-- ones, nearest first. Someone who stands in many places (a spirit healer) is a row for each place.
function F.Town(kind, title, word, profession)
	local list = {}
	local ids = profession and D.ProfessionTrainers(profession) or D.Town(kind, title)
	local objects = kind == "mail" or kind == "stone"
	for _, id in ipairs(ids) do
		local thing = D.Thing(objects and "o" or "n", id)
		if thing and (objects or L.Friendly(thing)) then
			local kindOf = objects and "objects" or "npcs"
			local points = Points(thing.places, {})
			if #points > SPREAD then
				for _, point in ipairs(points) do
					local result = Finish({ kind = kindOf, name = thing.name, ids = { id }, word = word, points = { point }, split = true })
					if result.nearest then list[#list + 1] = result end
				end
			else
				local result = Finish({ kind = kindOf, name = thing.name, ids = { id }, word = word })
				if result.nearest then list[#list + 1] = result end
			end
		end
	end
	table.sort(list, function(a, b)
		if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
		if a.yards and a.yards ~= b.yards then return a.yards < b.yards end
		return a.ids[1] < b.ids[1]
	end)
	for i = #list, SHOWN + 1, -1 do list[i] = nil end
	return list
end

-- A zone's quests as the list shows them: the zone's own row, then a heading over each group that has any.
-- In your log and available now are always open; not yet, missed and done fold.
local GROUPS = {
	{ "log", "IN YOUR LOG" }, { "available", "AVAILABLE NOW" }, { "yet", "NOT YET" },
	{ "missed", "MISSED", true }, { "done", "DONE", true },
}
function F.Zone(map)
	-- (No map, as in the tram between cities: nothing to list, not even the zone's row.)
	if not map then return {} end
	local list = { { zone = map } }
	local Why = ns.Why
	if not Why then return list end
	local zone = Why.Zone(map)
	shownSig = zone.sig
	for _, group in ipairs(GROUPS) do
		local key, words, folds = group[1], group[2], group[3]
		local quests = zone[key]
		if #quests > 0 then
			local shut = folds and folded[key]
			list[#list + 1] = { head = words, key = key, count = #quests, fold = folds, shut = shut }
			if not shut then
				for _, each in ipairs(quests) do
					list[#list + 1] = { kind = "quests", name = each.quest.name, ids = { each.quest.id }, browse = true }
				end
			end
		end
	end
	return list
end

-- Your friends online, as ShyMaps knows them (Shy.addons.Maps:Friends()): those on the map first, the
-- nearest first; one the friends list alone places stands at the middle of their zone. Nothing without
-- ShyMaps.
function F.Friends()
	local list = {}
	local maps = Shy.addons.Maps
	for _, friend in ipairs(maps and maps.Friends and maps:Friends() or {}) do
		local points = friend.map and { { map = friend.map, x = friend.x, y = friend.y } } or {}
		local who = friend.level and friend.className and ("Level %d %s"):format(friend.level, friend.className) or "Friend"
		local where = friend.zone and ((friend.placed and ", " or ", somewhere in ") .. friend.zone) or ""
		local result = { kind = "friends", name = friend.name, ids = { friend.name }, detail = who .. where, points = points,
			exact = friend.placed == true, placed = friend.placed == true, class = friend.class, finished = true }
		result.nearest, result.yards = Nearest(points)
		list[#list + 1] = result
	end
	table.sort(list, function(a, b)
		if a.placed ~= b.placed then return a.placed end
		if (a.yards ~= nil) ~= (b.yards ~= nil) then return a.yards ~= nil end
		if a.yards and a.yards ~= b.yards then return a.yards < b.yards end
		return a.name < b.name
	end)
	return list
end

-- Clicks and hover

-- A result's spawn lists for the map to shade (Ground.lua). nil for a quest giver, for one place of many, or
-- when D.Ground isn't loaded: the map then uses the result's points.
local function Ground(result)
	local kind, lists = result.kind, {}
	if not D.Ground or result.split or kind == "places" then return nil end
	if kind == "quests" then
		local id = result.ids[1]
		if R.Ground and L.Has(id) and not L.entries[id].complete then return (R.Ground(id)) end
		return nil
	elseif kind == "items" then
		local item = D.Item(result.ids[1])
		for _, source in ipairs(item and item.sources or {}) do
			local thing = D.Thing(source.kind, source.id)
			if thing and (source.kind ~= "v" or L.Friendly(thing)) then lists[#lists + 1] = D.Ground(thing) end
		end
	else
		for _, id in ipairs(result.ids) do
			local thing = D.Thing(kind == "objects" and "o" or "n", id)
			if thing then lists[#lists + 1] = D.Ground(thing) end
		end
	end
	return #lists > 0 and lists or nil
end

local function Show(result)
	-- A zone or a continent: the map opens on it, whole.
	if result.kind == "places" and result.place.whole then
		local map = result.place.points[1].map
		local maps = Shy.addons.Maps
		if maps and maps.IsOn and maps:IsOn() then maps:Open(map) end
		Shy.Maps.Open(map)
		return
	end
	if #result.points == 0 then
		T:Print(("|cffffffff%s|r is in a dungeon or isn't on any map."):format(result.name))
		return
	end
	ns.ShowOnMap(result.name, result.points, result.exact, Ground(result))
end

-- A result as a stop of your route (Plan.lua): its nearest place, what it is.
local function Place(result)
	Finish(result)
	local nearest = result.nearest
	if not nearest then
		T:Print(("|cffffffff%s|r is in a dungeon or isn't on any map."):format(result.name))
		return nil
	end
	return { map = nearest.map, x = nearest.x, y = nearest.y, title = result.name, where = result.detail, mark = result.mark, from = "find" }
end

-- Puts a result on your route: on top, where you go next (Plan.lua's stack), or before its `at`th stop.
-- The route opens to show it.
local function Add(result, at)
	local place = Place(result)
	if not place then return end
	routeShut = false
	ns.Plan.Add(place, at)
end

-- A result's menu: go there next (on top of your route), or put it before one of its stops.
local function Route(owner, result)
	Shy.UI.DropMenu(owner, function(root)
		root:CreateTitle(result.name)
		root:CreateButton("Go here next", function() Add(result) end)
		local stops = ns.Plan.List()
		if #stops > 0 then
			local before = root:CreateButton("Add before")
			for i, stop in ipairs(stops) do
				before:CreateButton(("%d. %s"):format(i, stop.title), function() Add(result, i) end)
			end
		end
		root:CreateButton("Show on the map", function() Show(result) end)
		if ns.ShareMenu then ns.ShareMenu(root, function() return Place(result) end) end
		-- (An item can be farmed: ShyFarm's rows.)
		local farm = Shy.addons.Farm
		if result.kind == "items" and farm and farm.FarmMenu then farm:FarmMenu(root, result.ids[1]) end
	end)
end

-- (A place can go to someone as a route of theirs only while ShyWay is on: ns.ShareMenu.)
local SHARES = not Shy.Way.missing
local HINTS = { { "left", "See it on the map" }, { "right", SHARES and "Go here next, or share it" or "Go here next" } }

local function Tip(row)
	local result = row.result
	local id = result.ids[1]
	if result.kind == "quests" and not L.Has(id) and ns.Why then
		local content = ns.Why.Content(id, HINTS)
		if content then
			Shy.Hover.Show(row, content)
			return
		end
	end
	local lines = Tips.Lines()
	if result.kind == "quests" then
		local quest = D.Quest(id)
		if L.Has(id) then
			Tips.Quest(lines, id, true)
		else
			Tips.Offer(lines, quest)
			for _, token in ipairs(quest.starts) do
				local thing = token.kind == "i" and D.Item(token.id) or D.Thing(token.kind, token.id)
				if thing then Tips.Line(lines, "Starts with |cffffffff" .. thing.name .. "|r", C.alert) end
			end
			for _, before in ipairs(quest.preSingle or quest.preGroup or {}) do
				if not L.Done(before) then
					Tips.Line(lines, "First: " .. (D.Name("quests", before) or "another quest"), C.dim)
				end
			end
			Tips.Line(lines, ("You: %s"):format((Standing(id))), C.dim)
		end
	else
		Tips.Double(lines, result.name, W.Yards(result.yards), C.text, C.hot)
		Tips.Line(lines, result.detail, C.dim)
		if result.kind == "friends" then
			if not result.placed then Tips.Line(lines, "Not on the map. They don't use ShyMaps or don't share where they are", C.dim, true) end
		elseif result.kind == "items" then
			for i, source in ipairs(D.Item(id).sources) do
				local thing = i <= 6 and D.Thing(source.kind, source.id)
				if thing then
					local how = source.kind == "v" and "Sold by " or source.kind == "o" and "In " or ""
					Tips.Double(lines, how .. thing.name, source.chance and (source.chance .. "%") or "", C.text, C.hot, true)
				end
			end
			-- What it is worth to you and what you have looted of it yourself (ShyFarm).
			local farm = Shy.addons.Farm
			if farm and farm.ItemLines then
				farm:ItemLines(id, function(left, right) Tips.Double(lines, left, right, C.dim, C.alert, true) end)
			end
		elseif result.kind == "npcs" then
			local npc = D.Npc(id)
			for i, quest in ipairs(npc.gives or {}) do
				if i <= 5 then Tips.Line(lines, "Gives " .. (D.Name("quests", quest) or "a quest"), C.dim, true) end
			end
		end
		if #result.ids > 1 then Tips.Line(lines, ("%d with that name"):format(#result.ids), C.dim) end
	end
	Tips.Open(row, lines, { hints = HINTS })
end

-- The window

local Fill
local Light   -- the left pane's chosen row lit and its counts said (set below)

local FarmTip, FarmMenu, Pick   -- something to farm: its hover, its menu, and farming it (the farm side, below)

-- Farms an item (ShyFarm): the session is set up for it (it asks to start where it drops), to `goal` if given, and
-- the best camp to farm it (R.FarmSpot) is your active waypoint. (A favorite farmed again goes as any pick does: to
-- the picker, when the window was opened as one.)
local function FarmIt(result, goal)
	return Pick({ farm = { kind = "item", id = result.ids[1] } }, nil, goal)
end

-- Your favorites (ShyFarm's): a row each, taller than a result, with the item's picture, how your farming of it
-- went, and a graph of your sessions at the right (a click on it shows the other figure). A click farms it again,
-- to the goal you last farmed it to.
local favRows = {}

local function FavTip(row)
	local farm, entry = Shy.addons.Farm, row.entry
	if not (farm and entry) then return end
	UI.Tip(row, entry.name, nil, { sections = { { title = "Your farming", rows = farm:StatRows(entry.item) } },
		hints = { { "left", entry.goal and ("Farm " .. entry.goal .. " again") or "Farm it again" }, { "right", "More" } },
		at = UI.Beside(box, row) })
end

local function FavMenu(row)
	local farm, entry = Shy.addons.Farm, row.entry
	Shy.UI.DropMenu(row, function(root)
		root:CreateTitle(entry.name)
		root:CreateButton(entry.goal and ("Farm " .. entry.goal .. " again") or "Farm it again", function() FarmIt(entry, entry.goal) end)
		local count = root:CreateButton("Farm this many")
		for _, n in ipairs({ 5, 10, 20, 40 }) do count:CreateButton(tostring(n), function() FarmIt(entry, n) end) end
		root:CreateButton("Show on the map", function()
			Show({ kind = "items", name = entry.name, ids = entry.ids, points = entry.points, exact = entry.exact })
		end)
		root:CreateDivider()
		root:CreateButton("No longer a favorite", function() farm:Favorite(entry.item, false) end)
	end)
end

local function FavRow(i)
	local row = favRows[i]
	if row then return row end
	local farm = Shy.addons.Farm
	row = CreateFrame("Frame", nil, scroll.content)
	row:SetSize(wide - PAD * 2 - 14, FAV.ROW - 4)
	UI.Skin(row, C.row, C.rowEdge)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(FAV.BIG, FAV.BIG)
	row.icon:SetPoint("LEFT", 10, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = FAV.BIG, hover = false })
	row.name = UI.Text(row, "", 13, false, C.text)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 10 + FAV.BIG + 10, -7)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.line = UI.Text(row, "", 11, false, C.dim)
	row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
	row.line:SetJustifyH("LEFT")
	row.line:SetWordWrap(false)
	row.more = UI.Text(row, "", 11, false, C.dim)
	row.more:SetPoint("TOPLEFT", row.line, "BOTTOMLEFT", 0, -3)
	row.more:SetJustifyH("LEFT")
	row.more:SetWordWrap(false)
	row.graph = farm:Graph(row, FAV.GRAPH_W, FAV.GRAPH_H)
	row.graph:SetPoint("RIGHT", -10, -1)
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		FavTip(self)
	end)
	row:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.rowEdge)
		UI.TipHide(self)
	end)
	row:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then FavMenu(self) else FarmIt(self.entry, self.entry.goal) end
	end)
	favRows[i] = row
	return row
end

local function Each(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end

local function PaintFav(row, entry)
	row.entry = entry
	local st = entry.stats
	row.icon:SetTexture(C_Item.GetItemIconByID(entry.item))
	row.name:SetText(entry.name)
	local line = st.sessions > 0 and { Each(st.sessions, "session", "sessions"), st.looted .. " looted" } or { "Not farmed yet" }
	if st.odds then line[#line + 1] = st.odds end
	row.line:SetText(table.concat(line, "  \194\183  "))
	local more = {}
	if st.best > 0 then more[#more + 1] = ("best %d an hour"):format(math.floor(st.best + 0.5)) end
	if st.worth and st.worth > 0 then more[#more + 1] = UI.Money(st.worth, true, 11) .. " each" end
	if entry.goal then more[#more + 1] = "to " .. entry.goal end
	local yards = entry.yards and W.Yards(entry.yards)
	if yards and yards ~= "" then more[#more + 1] = yards end
	row.more:SetText(table.concat(more, "  \194\183  "))
	local room = row:GetWidth() - FAV.BIG - 30 - FAV.GRAPH_W - 14
	row.name:SetWidth(room)
	row.line:SetWidth(room)
	row.more:SetWidth(room)
	row.graph:Show(entry.item)
end

-- Your favorites as the list shows them, with the nearest place each drops.
function F.Favorites()
	local farm = Shy.addons.Farm
	local list = {}
	for _, fav in ipairs(farm and farm.Favorites and farm:Favorites() or {}) do
		local entry = { kind = "farm", item = fav.item, ids = { fav.item }, goal = fav.goal, stats = fav.stats, detail = "Item",
			name = fav.name or D.Name("items", fav.item) or ("Item " .. fav.item), finished = true, points = ItemPoints(fav.item) }
		entry.nearest, entry.yards = Nearest(entry.points)
		entry.exact = #entry.points <= 4
		list[#list + 1] = entry
	end
	return list
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, scroll.content)
	row:SetSize(wide - PAD * 2 - 14, ROW - 2)
	UI.Skin(row, C.row, C.rowEdge)
	row.mark = ns.CreateMark(row, MARK)
	row.mark:SetPoint("CENTER", row, "LEFT", RAIL, 0)
	-- (An item wears the game's own picture of it, in a slot, in the mark's place.)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(FAV.ICON, FAV.ICON)
	row.icon:SetPoint("CENTER", row, "LEFT", RAIL, 0)
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = FAV.ICON, hover = false })
	row.icon:Hide()
	row.slot:Empty(true)
	-- (A creature to farm wears the kill's sign in an empty slot.)
	row.sign = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.sign:SetSize(FAV.SIGN, FAV.SIGN)
	row.sign:SetPoint("CENTER", row, "LEFT", RAIL, 0)
	Shy.Hover.Glyph(row.sign, "kill", FAV.SIGN)
	row.sign:Hide()
	-- (A friend wears their class's dot, as on the map, in the mark's place.)
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetAtlas("WhiteCircle-RaidBlips")
	row.dot:SetSize(12, 12)
	row.dot:SetPoint("CENTER", row, "LEFT", RAIL, 0)
	row.dot:Hide()
	row.name = UI.Text(row, "", 13, false, C.text)
	row.name:SetPoint("TOPLEFT", NAMES, -4)
	row.name:SetWidth(wide - PAD * 2 - 120)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.detail = UI.Text(row, "", 11, false, C.dim)
	row.detail:SetPoint("TOPLEFT", NAMES, -19)
	row.detail:SetWidth(wide - PAD * 2 - 70)
	row.detail:SetJustifyH("LEFT")
	row.detail:SetWordWrap(false)
	row.far = UI.Text(row, "", 12, false, C.hot)
	row.far:SetPoint("TOPRIGHT", -10, -5)
	-- (Something to farm: its worth over it, what that is of and how far under it.)
	row.sub = UI.Text(row, "", 11, false, C.dim)
	row.sub:SetPoint("TOPRIGHT", -10, -19)
	row.sub:SetJustifyH("RIGHT")
	row.sub:Hide()
	-- Under the mouse the distance gives way to a + that adds the result to your route.
	row.add = CreateFrame("Button", nil, row)
	row.add:SetSize(20, 20)
	row.add:SetPoint("RIGHT", -8, 0)
	row.add.glyph = row.add:CreateTexture(nil, "ARTWORK")
	row.add.glyph:SetAllPoints()
	row.add.glyph:SetTexture(Shy.Skin.GLYPH.plus)
	UI.Tint(row.add.glyph, C.hot)
	row.add:Hide()
	row.add:SetScript("OnClick", function(self) Add(self:GetParent().result) end)
	row.add:SetScript("OnEnter", function(self)
		UI.Tint(self.glyph, C.text)
		UI.Tip(self, "Go here next", nil, { side = "CURSOR" })
	end)
	row.add:SetScript("OnLeave", function(self)
		UI.Tint(self.glyph, C.hot)
		UI.TipHide(self)
		if not self:GetParent():IsMouseOver() then self:GetParent():GetScript("OnLeave")(self:GetParent()) end
	end)
	-- An item's row also offers to farm it (ShyFarm): a coin left of the +, under the mouse alike. Farming it puts it
	-- on your route too, if it isn't there yet, so the way leads where it drops.
	row.farm = CreateFrame("Button", nil, row)
	row.farm:SetSize(20, 20)
	row.farm:SetPoint("RIGHT", row.add, "LEFT", -6, 0)
	row.farm.glyph = row.farm:CreateTexture(nil, "ARTWORK")
	row.farm.glyph:SetSize(16, 16)
	row.farm.glyph:SetPoint("CENTER")
	Shy.Hover.Glyph(row.farm.glyph, "coin", 16)
	UI.Tint(row.farm.glyph, C.alert)
	row.farm:Hide()
	row.farm:SetScript("OnClick", function(self)
		local result = self:GetParent().result
		if result and result.kind == "items" then FarmIt(result) end
	end)
	row.farm:SetScript("OnEnter", function(self)
		UI.Tint(self.glyph, C.text)
		UI.Tip(self, "Farm this", "Takes you to the best camp to farm it, then counts what you loot, what it's worth and how fast you get it.", { side = "CURSOR" })
	end)
	row.farm:SetScript("OnLeave", function(self)
		UI.Tint(self.glyph, C.alert)
		UI.TipHide(self)
		if not self:GetParent():IsMouseOver() then self:GetParent():GetScript("OnLeave")(self:GetParent()) end
	end)
	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(20, 20)
	row.star:SetPoint("RIGHT", row.farm, "LEFT", -4, 0)
	row.star.glyph = row.star:CreateTexture(nil, "ARTWORK")
	row.star.glyph:SetSize(STAR, STAR)
	row.star.glyph:SetPoint("CENTER")
	row.star.glyph:SetTexture(Shy.MEDIA .. "GlyphStar")
	row.star:Hide()
	local function Starred(self)
		local farm, result = Shy.addons.Farm, self:GetParent().result
		local on = farm and farm.IsFavorite and result and farm:IsFavorite(result.ids[1])
		UI.Tint(self.glyph, on and C.alert or C.dim, on and 1 or 0.6)
		return on
	end
	row.star:SetScript("OnClick", function(self)
		local farm, result = Shy.addons.Farm, self:GetParent().result
		if not (farm and farm.Favorite and result) then return end
		farm:Favorite(result.ids[1])
		Starred(self)
		Light()
	end)
	row.star:SetScript("OnEnter", function(self)
		UI.Tint(self.glyph, C.alert, 1)
		UI.Tip(self, Starred(self) and "A favorite" or "Keep as a favorite",
			"You'll find your favorites under Farm, with how each one went. Click one to farm it again.", { side = "CURSOR" })
	end)
	row.star:SetScript("OnLeave", function(self)
		Starred(self)
		UI.TipHide(self)
		if not self:GetParent():IsMouseOver() then self:GetParent():GetScript("OnLeave")(self:GetParent()) end
	end)
	row.star.Starred = Starred
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		local farm = Shy.addons.Farm
		-- (Something to farm is farmed with a click: only an item's star stands in for the figures.)
		if self.result and self.result.farm then
			self.star:ClearAllPoints()
			self.star:SetPoint("RIGHT", -8, 0)
			local item = self.result.farm.kind == "item" and farm ~= nil and farm.Favorite ~= nil
			self.star:SetShown(item)
			if item then
				self.star.Starred(self.star)
				self.far:Hide()
				self.sub:Hide()
			end
			FarmTip(self)
			return
		end
		self.star:ClearAllPoints()
		self.star:SetPoint("RIGHT", self.farm, "LEFT", -4, 0)
		self.add:Show()
		self.farm:SetShown(self.result ~= nil and self.result.kind == "items" and farm ~= nil and farm.Farm ~= nil)
		self.star:SetShown(self.farm:IsShown() and farm.Favorite ~= nil)
		if self.star:IsShown() then self.star.Starred(self.star) end
		self.far:Hide()
		Tip(self)
	end)
	row:SetScript("OnLeave", function(self)
		if self.add:IsMouseOver() or self.farm:IsMouseOver() or self.star:IsMouseOver() then return end
		UI.SetBorder(self, C.rowEdge)
		self.add:Hide()
		self.farm:Hide()
		self.star:Hide()
		self.far:Show()
		self.sub:SetShown(self.result ~= nil and self.result.farm ~= nil)
		Tips.Close(self)
	end)
	row:SetScript("OnMouseUp", function(self, button)
		if self.result and self.result.farm then
			if button == "RightButton" then FarmMenu(self, self.result) else Pick(self.result) end
			return
		end
		if button == "RightButton" then Route(self, self.result) else Show(self.result) end
	end)
	rows[i] = row
	return row
end

-- A heading in the list: what the rows under it are, and how many. One that folds has the caret on the
-- marks' rail and opens or shuts on a click.
local function Head(i)
	local head = heads[i]
	if head then return head end
	head = CreateFrame("Frame", nil, scroll.content)
	head:SetSize(wide - PAD * 2 - 14, HEAD)
	head.caret = head:CreateTexture(nil, "ARTWORK")
	head.caret:SetSize(13, 13)
	head.caret:SetPoint("CENTER", head, "LEFT", RAIL, -1)
	head.caret:SetTexture(Shy.Skin.GLYPH.caret)
	UI.Tint(head.caret, C.text, 0.85)
	head.text = UI.Text(head, "", 10, false, C.dim)
	head.text:SetPoint("BOTTOMLEFT", NAMES, 6)
	head.text:SetWordWrap(false)
	head.count = UI.Text(head, "", 11, false, C.dim)
	head.count:SetPoint("BOTTOMRIGHT", -10, 6)
	head:SetScript("OnEnter", function(self)
		UI.Ink(self.text, C.hot)
		UI.Tint(self.caret, C.hot)
	end)
	head:SetScript("OnLeave", function(self)
		UI.Ink(self.text, C.dim)
		UI.Tint(self.caret, C.text, 0.85)
	end)
	head:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or not self.entry or not self.entry.fold then return end
		folded[self.entry.key] = not folded[self.entry.key]
		results = F.Zone(browsed)
		Fill()
	end)
	heads[i] = head
	return head
end

local function PaintHead(head, entry)
	head.entry = entry
	head.text:SetText(entry.fold and ("%d %s"):format(entry.count, entry.head) or entry.head)
	head.count:SetText(entry.fold and "" or tostring(entry.count))
	head.caret:SetShown(entry.fold == true)
	head.caret:SetRotation(entry.shut and math.pi / 2 or math.pi)
	head:EnableMouse(entry.fold == true)
end

local PaintFarm   -- something to farm's row (below)

local function PaintRow(row, result)
	if result.farm and PaintFarm then return PaintFarm(row, result) end
	row.sign:Hide()
	row.sub:Hide()
	row.name:SetWidth(row:GetWidth() - 106)
	row.detail:SetWidth(row:GetWidth() - 56)
	Finish(result)
	row.result = result
	row.name:SetText(result.name)
	UI.Ink(row.name, result.quiet and C.dim or C.text)
	row.detail:SetText(result.detail)
	-- (One already in your route says so where its distance would be.)
	local nearest = result.nearest
	local routed = nearest and ns.Plan.Has(nearest.map, nearest.x, nearest.y)
	row.far:SetText(routed and ("Stop " .. routed) or result.quiet and "" or W.Yards(result.yards))
	UI.Ink(row.far, routed and C.good or C.hot)
	if result.kind == "friends" then
		local color = result.class and C_ClassColor.GetClassColor(result.class)
		local r, g, b = 1, 1, 1
		if color then r, g, b = color.r, color.g, color.b end
		row.dot:SetVertexColor(r, g, b, result.placed and 1 or 0.45)
		row.dot:Show()
		row.name:SetTextColor(r, g, b)
		row.mark:Hide()
		row.icon:Hide()
		row.slot:Empty(true)
		return
	end
	row.dot:Hide()
	local picture = result.kind == "items" and C_Item.GetItemIconByID(result.ids[1])
	row.icon:SetShown(picture ~= nil and picture ~= false)
	row.slot:Empty(not picture)
	if picture then
		row.icon:SetTexture(picture)
		row.mark:Hide()
		return
	end
	if result.mark then
		local id = result.kind == "quests" and result.ids[1]
		-- A quest in the log wears what it asks for next, as on the map.
		row.mark:Set(result.mark, nil, nil, id and result.mark == "goal" and ns.QuestKind(id) or nil)
		row.mark:Show()
	else
		row.mark:Hide()
	end
end

-- Your route

-- Minutes in a few letters: "4 min", "<1 min"; nothing where no way is known.
local function Minutes(seconds)
	if not seconds then return "" end
	if seconds < 60 then return "<1 min" end
	return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

-- The route's heading: its name, how many stops and how long, the newest-first switch and Clear. A
-- click on it (not on a button) folds the stops away or opens them.
local function RouteHead()
	if routeHead then return routeHead end
	local head = CreateFrame("Frame", nil, scroll.content)
	head:SetSize(wide - PAD * 2 - 14, HEAD + 6)
	head.caret = head:CreateTexture(nil, "ARTWORK")
	head.caret:SetSize(13, 13)
	head.caret:SetPoint("CENTER", head, "LEFT", RAIL, -1)
	head.caret:SetTexture(Shy.Skin.GLYPH.caret)
	UI.Tint(head.caret, C.text, 0.85)
	head.text = UI.Text(head, "YOUR ROUTE", 10, false, C.text)
	head.text:SetPoint("LEFT", NAMES, 0)
	head.count = UI.Text(head, "", 11, false, C.hot)
	head.count:SetPoint("LEFT", head.text, "RIGHT", 8, 0)
	head.clear = UI.Button(head, "Clear", 50, function() ns.Plan.Clear() end)
	head.clear:SetHeight(20)
	head.clear:SetPoint("RIGHT", -2, 0)
	head.quick = UI.Checkbox(head, "Newest first", function() return ns.Plan.Auto() end, function(on) ns.Plan.Auto(on) end,
		{ desc = "Takes you to what you added last, and to other stops as you pass them. When this is off, your stops stay in the order you set." })
	head.quick:SetPoint("RIGHT", head.clear, "LEFT", -10, 0)
	head:EnableMouse(true)
	head:SetScript("OnEnter", function(self)
		UI.Ink(self.text, C.hot)
		UI.Tint(self.caret, C.hot)
	end)
	head:SetScript("OnLeave", function(self)
		UI.Ink(self.text, C.text)
		UI.Tint(self.caret, C.text, 0.85)
	end)
	head:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then return end
		routeShut = not routeShut
		Fill()
	end)
	routeHead = head
	return head
end

-- What a stop's hover says: where it is, how long to get there and the rides on the way.
local function StopTip(row)
	local stop, leg = row.stop, row.leg
	local lines = Tips.Lines()
	Tips.Double(lines, stop.title, Minutes(leg and leg.seconds), C.text, C.hot)
	Tips.Line(lines, stop.where, C.dim)
	for _, ride in ipairs(leg and leg.rides or {}) do Tips.Line(lines, ride, C.text) end
	Tips.Open(row, lines, { hints = { { "left", "See it on the map, or drag to reorder" }, { "right", SHARES and "Remove, go here first or share it" or "Remove, go here first" } } })
end

-- A stop's menu.
local function StopMenu(row)
	local i = row.index
	Shy.UI.DropMenu(row, function(root)
		root:CreateTitle(row.stop.title)
		if i > 1 then root:CreateButton("Go here first", function() ns.Plan.Move(i, 1) end) end
		if i > 1 then root:CreateButton("Earlier", function() ns.Plan.Move(i, i - 1) end) end
		if i < #ns.Plan.List() then root:CreateButton("Later", function() ns.Plan.Move(i, i + 1) end) end
		root:CreateButton("Remove", function() ns.Plan.Remove(i) end)
		if ns.ShareMenu then ns.ShareMenu(root, row.stop) end
		root:CreateDivider()
		root:CreateButton("Clear my route", function() ns.Plan.Clear() end)
	end)
end

-- A stop of the route: its number on the route's mark, its name, where it is and the rides to it, the
-- minutes from the stop before. Dragged up or down it moves there.
local function StopRow(i)
	local row = stopRows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, scroll.content)
	row:SetSize(wide - PAD * 2 - 14, STOP - 2)
	UI.Skin(row, C.row, C.rowEdge)
	row.mark = ns.CreateMark(row, MARK)
	row.mark:SetPoint("CENTER", row, "LEFT", RAIL, 0)
	row.name = UI.Text(row, "", 13, false, C.text)
	row.name:SetPoint("TOPLEFT", NAMES, -4)
	row.name:SetWidth(wide - PAD * 2 - 120)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.detail = UI.Text(row, "", 11, false, C.dim)
	row.detail:SetPoint("TOPLEFT", NAMES, -19)
	row.detail:SetWidth(wide - PAD * 2 - 70)
	row.detail:SetJustifyH("LEFT")
	row.detail:SetWordWrap(false)
	row.far = UI.Text(row, "", 12, false, C.hot)
	row.far:SetPoint("TOPRIGHT", -10, -5)
	row:EnableMouse(true)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		StopTip(self)
	end)
	row:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.rowEdge)
		Tips.Close(self)
	end)
	row:SetScript("OnDragStart", function(self)
		self.dragged = true
		self:SetAlpha(0.6)
		Tips.Close(self)
	end)
	row:SetScript("OnDragStop", function(self)
		self:SetAlpha(1)
		-- Where it was let go: the stop row under the cursor, counted from the first.
		local first = stopRows[1]
		local _, cursor = GetCursorPosition()
		local top = first:GetTop() * first:GetEffectiveScale()
		local to = math.floor((top - cursor) / (STOP * first:GetEffectiveScale())) + 1
		ns.Plan.Move(self.index, math.max(1, math.min(to, #ns.Plan.List())))
	end)
	row:SetScript("OnMouseUp", function(self, button)
		if self.dragged then
			self.dragged = false
			return
		end
		if button == "RightButton" then
			StopMenu(self)
		else
			ns.ShowOnMap(self.stop.title, { { map = self.stop.map, x = self.stop.x, y = self.stop.y } }, true)
		end
	end)
	stopRows[i] = row
	return row
end

-- Lays your route at the list's head from `y`; returns where the list goes on.
local function LayRoute(y)
	if routeHead then routeHead:Hide() end
	for _, row in ipairs(stopRows) do row:Hide() end
	local stops = ns.Plan.List()
	if #stops == 0 then return y end
	local legs, total = ns.Plan.Legs()
	local head = RouteHead()
	head.count:SetText(("%d %s%s"):format(#stops, #stops == 1 and "stop" or "stops", total and ("  \194\183  " .. Minutes(total)) or ""))
	head.caret:SetRotation(routeShut and math.pi / 2 or math.pi)
	head.quick:Refresh()
	head:ClearAllPoints()
	head:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
	head:Show()
	y = y + HEAD + 6
	if not routeShut then
		for i, stop in ipairs(stops) do
			local row, leg = StopRow(i), legs[i]
			row.index, row.stop, row.leg = i, stop, leg
			row.mark:Set("way", nil, i)
			row.name:SetText(stop.title)
			-- (Where it is, and the rides there: "Orgrimmar  ·  Fly to Orgrimmar".)
			local rides = leg and #leg.rides > 0 and ("  \194\183  " .. table.concat(leg.rides, ", ")) or ""
			row.detail:SetText(stop.where .. rides)
			row.far:SetText(Minutes(leg and leg.seconds))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
			row:Show()
			y = y + STOP
		end
	end
	return y + 8
end

function Fill()
	if not box then return end
	local y, used, headsUsed, favUsed = LayRoute(0), 0, 0, 0
	local routed = y > 0
	zoneButton:Hide()
	for _, entry in ipairs(results) do
		if entry.zone then
			zoneButton:ClearAllPoints()
			zoneButton:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
			zoneButton:SetLabel(W.MapName(entry.zone) or "This zone")
			zoneButton:Show()
			y = y + ZONE
		elseif entry.head then
			headsUsed = headsUsed + 1
			local head = Head(headsUsed)
			PaintHead(head, entry)
			head:ClearAllPoints()
			head:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
			head:Show()
			y = y + HEAD
		elseif entry.kind == "farm" then
			favUsed = favUsed + 1
			local row = FavRow(favUsed)
			row:SetWidth(scroll.content:GetWidth())
			PaintFav(row, entry)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
			row:Show()
			y = y + FAV.ROW
		else
			used = used + 1
			local row = Row(used)
			PaintRow(row, entry)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -y)
			row:Show()
			y = y + ROW
		end
	end
	for i = used + 1, #rows do rows[i]:Hide() end
	for i = headsUsed + 1, #heads do heads[i]:Hide() end
	for i = favUsed + 1, #favRows do favRows[i]:Hide() end
	scroll.content:SetHeight(math.max(1, y))
	scroll:Update()
	-- (With your route at the list's head, a list of nothing says nothing under it.)
	if used > 0 or headsUsed > 0 or favUsed > 0 or routed then
		empty:Hide()
	else
		empty:SetText(heading or "Type part of a name, or pick what to find on the left.")
		empty:Show()
	end
end

-- The farm side (ShyFarm): picked under Farm on the left, the list is the best farms for you or your favorites, and
-- the search box looks only for what you could farm (Farmable.lua): creatures, then items, each with what it is
-- worth. A click farms it: an item, wherever it is best had; a creature, all it drops (its menu: one of them).
-- Opened by T:FindFarm as a picker, a pick goes to whoever asked and the window closes.
local farmSide = false
local picker               -- T:FindFarm's opts while the window is open for them
local SEP = "  \194\183  "

-- How often a kill gives something: "1 in 8", "35%", "1.4 a kill".
local function Per(per)
	if per >= 1 then return ("%.1f a kill"):format(per) end
	if per >= 0.1 then return ("%d%%"):format(math.floor(per * 100 + 0.5)) end
	return ("1 in %d"):format(math.floor(1 / per + 0.5))
end

local function ItemName(id)
	return D.Name("items", id) or C_Item.GetItemNameByID(id) or ("Item " .. id)
end

local function Capital(text)
	return text and (text:gsub("^%l", string.upper)) or nil
end

-- What is farmed now (ShyFarm's session): the creature, and the item counted.
local function Farming()
	local farm = Shy.addons.Farm
	local s = farm and farm.Session and farm:Session()
	return s and s.mob, s and s.want
end

local function FarmDetail(result)
	local f = result.farm
	if f.best then
		local b = f.best
		local words = { b.low and ((b.high and b.high ~= b.low) and ("Level %d-%d"):format(b.low, b.high) or ("Level %d"):format(b.low)) or nil }
		local info = b.camp and C_Map.GetMapInfo(b.camp.map)
		if info then words[#words + 1] = info.name end
		if b.going == "working" then
			words[#words + 1] = "finding the way there"
		elseif b.trip then
			words[#words + 1] = ("%d min away"):format(math.max(1, math.floor(b.trip / 60 + 0.5)))
		end
		return table.concat(words, SEP)
	end
	if f.kind == "creature" then
		local thing = D.Npc(f.id)
		local words = { Capital(thing and D.LevelText(thing)) or "Creature" }
		local farm = Shy.addons.Farm
		local best = farm and farm.KillWorth and select(2, farm:KillWorth(f.id))
		if best and best[1] then
			words[#words + 1] = "drops " .. ItemName(best[1].item) .. (best[2] and (", " .. ItemName(best[2].item)) or "")
		end
		return table.concat(words, SEP)
	end
	if not f.from then return "Item" end
	if f.node then return "Gathered from " .. f.from end
	return "From " .. f.from .. (f.chance and (SEP .. f.chance .. "%") or "")
end

-- Where it stands: the camp a best farm was weighed at; a creature's spawns; the spawns of the creatures you could
-- farm an item from and the nodes that hold it.
local function FarmFinish(result)
	if result.finished then return result end
	result.finished = true
	local f, out = result.farm, result.points
	if f.kind == "any" then
		result.points, result.detail = {}, "No need to pick anything. Everything you loot counts."
		return result
	end
	if not out then
		out = {}
		if f.kind == "creature" then
			out = ThingPoints("npcs", result.ids)
		else
			local item, Fa = D.Item(f.id), ns.Farmable
			for _, source in ipairs(item and item.sources or {}) do
				local ok = source.kind == "o" or (source.kind == "n" and Fa ~= nil and Fa.Creature(source.id))
				local thing = ok and D.Thing(source.kind, source.id)
				if thing then Points(thing.places, out) end
			end
		end
	end
	result.points, result.exact = out, f.best ~= nil or #out <= 4
	result.nearest, result.yards = Nearest(out)
	result.detail = FarmDetail(result)
	return result
end

-- The row's right: what it is worth (one, a kill, an hour there) over what that is of and how far; "farming now"
-- for what you farm.
local function FarmRight(row, result)
	local f, farm = result.farm, Shy.addons.Farm
	if f.kind == "any" then
		row.far:SetText("")
		row.sub:SetText("")
		row.name:SetWidth(row:GetWidth() - NAMES - 20)
		row.detail:SetWidth(row:GetWidth() - NAMES - 20)
		return
	end
	local copper, what
	if f.best then
		copper, what = f.best.net, "an hour"
	elseif f.kind == "creature" then
		copper, what = farm and farm.KillWorth and farm:KillWorth(f.id), "a kill"
	else
		copper, what = farm and farm.Worth and farm:Worth(f.id), "each"
	end
	local mob, want = Farming()
	local now = (f.kind == "creature" and mob == f.id) or (f.kind == "item" and want == f.id)
	local far = f.best and "" or W.Yards(result.yards)
	if copper and copper > 0 then
		row.far:SetText(UI.Money(math.floor(copper + 0.5), true, 12, row.far))
		UI.Ink(row.far, C.text)
		row.sub:SetText(now and "farming now" or (far ~= "" and (what .. SEP .. far) or what))
	else
		row.far:SetText(now and "" or far)
		UI.Ink(row.far, C.hot)
		row.sub:SetText(now and "farming now" or "")
	end
	UI.Ink(row.sub, now and C.good or C.dim)
	row.sub:Show()
	-- (The name and the line under it give way to the figures at the right.)
	local width = row:GetWidth() - NAMES
	row.name:SetWidth(math.max(40, width - row.far:GetStringWidth() - 20))
	row.detail:SetWidth(math.max(40, width - row.sub:GetStringWidth() - 20))
end

PaintFarm = function(row, result)
	FarmFinish(result)
	row.result = result
	local f = result.farm
	row.mark:Hide()
	row.dot:Hide()
	row.name:SetText(result.name)
	row.detail:SetText(result.detail)
	if f.kind == "item" then
		row.icon:SetTexture(C_Item.GetItemIconByID(f.id) or QUESTION_MARK_ICON)
		row.icon:Show()
		row.slot:Empty(false)
		row.sign:Hide()
		local quality = C_Item.GetItemQualityByID(f.id)
		if quality then
			row.name:SetTextColor(C_Item.GetItemQualityColor(quality))
		else
			UI.Ink(row.name, C.text)
		end
	else
		row.icon:Hide()
		row.slot:Empty(true)
		row.sign:Show()
		-- (Record everything wears the bag's sign, a creature the kill's. The best of the best farms in gold, as the
		-- auction house's farm page lights it.)
		Shy.Hover.Glyph(row.sign, f.kind == "any" and "bag" or "kill", FAV.SIGN)
		UI.Tint(row.sign, (f.rank == 1 or f.kind == "any") and C.alert or C.text, (f.rank == 1 or f.kind == "any") and 1 or 0.85)
		UI.Ink(row.name, C.text)
	end
	FarmRight(row, result)
end

-- Farms it (or tells the picker): a creature, all it drops or `item` of it; an item, `goal` of it.
Pick = function(result, item, goal)
	local f, farm = result.farm, Shy.addons.Farm
	local opts = picker
	if opts and (opts.pick or opts.close) then F.Toggle(false) end
	if opts and opts.pick then
		if item then opts.pick("item", item) else opts.pick(f.kind, f.id) end
		return
	end
	if not farm then return end
	if f.kind == "any" then
		if farm.FarmAnything then farm:FarmAnything() end
	elseif f.kind == "creature" then
		if farm.FarmMob then farm:FarmMob(f.id, item, goal) end
	elseif farm.Farm then
		farm:Farm(f.id, goal)
	end
end

FarmTip = function(row)
	local result = row.result
	local f, farm = result.farm, Shy.addons.Farm
	local lines = Tips.Lines()
	if f.kind == "any" then
		Tips.Line(lines, result.name, C.text)
		Tips.Line(lines, "The clock starts now. Everything you loot counts, wherever you go.", C.dim, true)
		Tips.Open(row, lines, { hints = { { "left", "Start recording" } } })
		return
	end
	Tips.Double(lines, result.name, W.Yards(result.yards), C.text, C.hot)
	if f.kind == "creature" then
		local thing = D.Npc(f.id)
		local level = thing and D.LevelText(thing)
		if level then Tips.Line(lines, Capital(level), C.dim) end
		if f.best then
			Tips.Double(lines, "Kills an hour", tostring(math.floor(f.best.kills + 0.5)), C.dim, C.text)
		end
		local copper, best
		if farm and farm.KillWorth then copper, best = farm:KillWorth(f.id) end
		if copper then Tips.Double(lines, "Each kill is worth", UI.Money(math.floor(copper + 0.5), true), C.dim, C.text) end
		for _, drop in ipairs(best or {}) do
			Tips.Double(lines, ItemName(drop.item), Per(drop.per), C.text, C.hot, true)
		end
	else
		local item, Fa = D.Item(f.id), ns.Farmable
		local n = 0
		for _, source in ipairs(item and item.sources or {}) do
			local ok = source.kind == "o" or (source.kind == "n" and Fa ~= nil and Fa.Creature(source.id))
			local thing = ok and n < 6 and D.Thing(source.kind, source.id)
			if thing then
				n = n + 1
				Tips.Double(lines, (source.kind == "o" and "In " or "") .. thing.name, source.chance and (source.chance .. "%") or "",
					C.text, C.hot, true)
			end
		end
		if farm and farm.ItemLines then
			farm:ItemLines(f.id, function(left, right) Tips.Double(lines, left, right, C.dim, C.alert, true) end)
		end
	end
	Tips.Open(row, lines, { hints = { { "left", picker and picker.pick and "Pick this" or "Farm it" }, { "right", "More" } } })
end

FarmMenu = function(row, result)
	local f, farm = result.farm, Shy.addons.Farm
	if f.kind == "any" then return Pick(result) end
	Shy.UI.DropMenu(row, function(root)
		root:CreateTitle(result.name)
		if picker and picker.pick then
			root:CreateButton("Pick this", function() Pick(result) end)
		elseif f.kind == "creature" then
			root:CreateButton("Farm it", function() Pick(result) end)
			local best = farm and farm.KillWorth and select(2, farm:KillWorth(f.id, 8))
			if best and #best > 0 then
				local one = root:CreateButton("Just one of its drops")
				for _, drop in ipairs(best) do
					one:CreateButton(ItemName(drop.item), function() Pick(result, drop.item) end):SetDetail(Per(drop.per))
				end
			end
		else
			root:CreateButton("Farm it", function() Pick(result) end)
			local count = root:CreateButton("Farm this many")
			for _, n in ipairs({ 5, 10, 20, 40 }) do count:CreateButton(tostring(n), function() Pick(result, nil, n) end) end
			if farm and farm.Favorite then
				root:CreateCheckbox("Favorite", function() return farm:IsFavorite(f.id) end, function()
					farm:Favorite(f.id)
					Light()
				end)
			end
		end
		root:CreateDivider()
		root:CreateButton("Show on the map", function() Show(result) end)
		root:CreateButton("Go here next", function() Add(result) end)
	end)
end

-- The best farms for you (ShyFarm's, weighed over a few frames the first time): a creature each, best first.
-- Second: "working" while they are weighed (ShyFarm says them once, settled). Once shown the list keeps its order
-- while it stays on screen, its rows said again in place; picked again, it is weighed again and its order taken anew.
local BEST = {}   -- order: { [npc] = place } as first shown
function F.BestFarms()
	local farm = Shy.addons.Farm
	if not (farm and farm.FarmsFor) then return {}, nil end
	local list, working = farm:FarmsFor(nil)
	if not list and not working then
		farm:RankFarms()
		list, working = farm:FarmsFor(nil)
	end
	if not list then return {}, "working" end
	if not BEST.order then
		BEST.order = {}
		for i, each in ipairs(list) do BEST.order[each.npc] = i end
	end
	local held = {}
	for _, each in ipairs(list) do held[#held + 1] = each end
	table.sort(held, function(a, b)
		local x, y = BEST.order[a.npc] or math.huge, BEST.order[b.npc] or math.huge
		if x ~= y then return x < y end
		return a.npc < b.npc
	end)
	list = held
	local out = {}
	for i, each in ipairs(list) do
		local camp = each.camp
		out[i] = { kind = "npcs", name = each.name, ids = { each.npc }, farm = { kind = "creature", id = each.npc, best = each, rank = i },
			points = camp and { { map = camp.map, x = math.floor(camp.x * 10000 + 0.5), y = math.floor(camp.y * 10000 + 0.5) } } or nil }
	end
	return out, working and "working" or nil
end

-- What you could farm by name, creatures first, each kind under its heading.
function F.FarmSearch(text)
	local out, under = {}, {}
	for _, each in ipairs(ns.Farmable and ns.Farmable.Search(text) or {}) do
		local kind = each.kind == "item" and "items" or "npcs"
		if not under[kind] then
			under[kind] = { head = kind == "items" and "ITEMS" or "CREATURES", count = 0 }
			out[#out + 1] = under[kind]
		end
		under[kind].count = under[kind].count + 1
		out[#out + 1] = { kind = kind, name = each.name, ids = each.ids, farm = each }
	end
	return out
end

local NO_FAVORITES = "No favorites yet. Find something you farm and click its star."

-- The list the farm side shows with nothing typed: your favorites, or the best farms.
local function FarmList()
	if chosen == "favorites" then
		results = F.Favorites()
		heading = NO_FAVORITES
		return
	end
	local state, farms
	farms, state = F.BestFarms()
	heading = state == "working" and "Finding the best farms for you..." or "Nothing to farm at your level yet."
	-- Record everything first (nothing in particular, all your loot counts), unless another window is picking one;
	-- the best farms under their heading, which says so while they are found.
	local farm = Shy.addons.Farm
	if (picker and picker.pick) or not (farm and farm.FarmAnything) then
		results = farms
		return
	end
	results = { { kind = "npcs", name = "Record everything", ids = { 0 }, farm = { kind = "any" } } }
	results[2] = { head = #farms > 0 and "BEST FARMS FOR YOU" or (state == "working" and "FINDING THE BEST FARMS FOR YOU..."
		or "NOTHING TO FARM AT YOUR LEVEL YET"), count = #farms > 0 and #farms or "" }
	for _, each in ipairs(farms) do results[#results + 1] = each end
end

-- Picks a Farm row on the left: its list, the search box looking only for what you could farm. (The best farms
-- picked again: weighed again, their order taken anew.)
local function FarmSide(key)
	if key == "best" then
		local farm = Shy.addons.Farm
		local _, working = farm and farm.FarmsFor and farm:FarmsFor(nil)
		if BEST.order and farm and farm.RankFarms and not working then farm:RankFarms() end
		BEST.order = nil
	end
	query = ""
	if not town then routeShut = true end
	farmSide, town, chosen = true, { key = key }, key
	if input then input:Refresh() end
	FarmList()
	Light()
	Fill()
end

-- Nothing asked: the zone's quests, the one you are in unless another was picked.
local function Browse()
	query, town, routeShut, chosen = "", nil, false, "quests"
	farmSide, picker = false, nil
	if input then input:Refresh() end
	if not picked or not browsed then browsed = W.map end
	results = F.Zone(browsed)
	heading = browsed and "No quests start here." or nil
	Light()
	Fill()
end

local function Look(text)
	if farmSide then
		query = text or ""
		local typed = strtrim(query)
		if typed == "" then
			FarmList()
		else
			results = F.FarmSearch(typed)
			heading = #typed >= 2 and "Nothing to farm by that name." or nil
		end
		Light()
		Fill()
		return
	end
	-- (A search begun folds your route to its heading: the results get the room.)
	if strtrim(query) == "" and not town then routeShut = true end
	query = text or ""
	if strtrim(query) == "" then
		Browse()
		return
	end
	town, chosen = nil, nil
	results = F.Search(query)
	heading = (#strtrim(query) >= 2 or tonumber(strtrim(query):match("^#?(%d+)$") or "")) and "No matches." or nil
	Light()
	Fill()
end

-- Lists a service (or, "friends", your friends online).
local function Nearby(key, kind, title, word, nothing, profession)
	query = ""
	farmSide, picker = false, nil
	if input then input:Refresh() end
	if not town then routeShut = true end
	town, chosen = { key = key }, key
	if key == "friends" then
		results = F.Friends()
		heading = Shy.addons.Maps and nothing or "Friends come with ShyMaps."
	else
		results = F.Town(kind, title, word, profession)
		heading = nothing
	end
	Light()
	Fill()
end

local NONE = "None of those on this continent."

local function ClassTrainer()
	local _, token = UnitClass("player")
	return token and (token:sub(1, 1) .. token:sub(2):lower() .. " Trainer") or nil
end
F.ClassTrainer = ClassTrainer

-- The professions' menu, and every trainer's, from the left pane's last two rows.
local function ProfessionMenu(root)
	root:CreateTitle("Profession trainers")
	root:CreateButton("Any profession", function() Nearby("profession", "profession", nil, nil, NONE) end)
	for _, name in ipairs(D.Professions()) do
		root:CreateButton(name, function() Nearby("p:" .. name, nil, nil, nil, NONE, name) end)
	end
end

local function TrainerMenu(root)
	root:CreateTitle("Trainers")
	for _, called in ipairs(D.TrainerTitles()) do
		root:CreateButton(called, function() Nearby("t:" .. called, nil, called, nil, NONE) end)
	end
end

-- What to find, down the left pane: { key, label, word (what a result is called) | title (the trainers
-- so titled) | menu, help }. A service's key is its D.Town kind and its picture is the game's own
-- (Pins.lua, ns.ServicePicture); the ones Pins.lua can keep on the map (ns.SERVICES) get the star.
local SECTIONS = {
	{ head = "FIND", rows = {
		{ key = "quests", label = "Quests", mark = "pickup", help = "Quests in your zone, or any zone you pick at the top of the list.",
			count = function() return W.map and #L.StartsOn(W.map) or 0 end },
		{ key = "friends", label = "Friends", glyph = Shy.MEDIA .. "GlyphPeople", help = "Where your friends online are, if they use ShyMaps.",
			count = function() return #F.Friends() end },
	} },
	{ head = "FARM", when = function() local farm = Shy.addons.Farm; return farm ~= nil and farm.Favorites ~= nil end, rows = {
		{ key = "best", label = "Best farms", sign = "coin",
			help = "Where you'd make the most gold an hour right now, travel time included. Search for any item or creature to farm.",
			count = function()
				local farm = Shy.addons.Farm
				local list = farm and farm.FarmsFor and farm:FarmsFor(nil)
				return list and #list or 0
			end },
		{ key = "favorites", label = "Favorites", glyph = Shy.MEDIA .. "GlyphStar",
			help = "The things you farm most, with how each one went and a graph of your sessions. Click one to farm it again.",
			count = function() local farm = Shy.addons.Farm; return farm and farm.Favorites and #farm:Favorites() or 0 end },
	} },
	{ head = "NEARBY", rows = {
		{ key = "inn", label = "Innkeeper", word = "Innkeeper" },
		{ key = "flight", label = "Flight master", word = "Flight master" },
		{ key = "repair", label = "Repairs", word = "Repair vendor" },
		{ key = "mail", label = "Mailbox", word = "Mailbox" },
		{ key = "bank", label = "Bank", word = "Banker" },
		{ key = "auction", label = "Auction house", word = "Auctioneer" },
		{ key = "stable", label = "Stable master", word = "Stable master" },
		{ key = "trainer", label = "Class trainer", title = ClassTrainer, nothing = "No trainer for your class on this continent." },
		{ key = "food", label = "Food and drink", word = "Sells food and drink" },
		{ key = "reagents", label = "Reagents", word = "Sells reagents" },
		{ key = "poisons", label = "Poisons", word = "Sells poisons" },
		{ key = "ammo", label = "Ammunition", word = "Sells ammunition" },
		{ key = "bags", label = "Bags", word = "Sells bags" },
		{ key = "trade", label = "Trade goods", word = "Sells trade goods" },
		{ key = "spirit", label = "Spirit healer", word = "Spirit healer" },
		{ key = "stone", label = "Meeting stone", word = "Meeting stone" },
		{ key = "profession", label = "Professions", menu = ProfessionMenu, help = "Profession trainers." },
		{ key = "trainers", label = "All trainers", menu = TrainerMenu, picture = "trainer", help = "Every kind of trainer, by title." },
	} },
}

-- Menu names of the services that can stay on the map (Pins.lua draws them).
local KEPT = { inn = "Innkeepers", flight = "Flight masters", repair = "Repair vendors", mail = "Mailboxes", bank = "Bankers",
	auction = "Auctioneers", stable = "Stable masters", trainer = "Trainers for your class", profession = "Profession trainers",
	spirit = "Spirit healers", stone = "Meeting stones", food = "Food and drink", reagents = "Reagent vendors",
	poisons = "Poison vendors", ammo = "Ammunition vendors", trade = "Trade goods" }
ns.KEPT = KEPT   -- the map's own menu lists them too (LogRows.lua)

local function Picture(kind)
	return ns.ServicePicture and ns.ServicePicture(kind) or ns.MEDIA .. "Dot"
end

-- Whether Pins.lua can keep a service on the map (ns.SERVICES).
local function CanKeep(key)
	for _, kind in ipairs(ns.SERVICES or {}) do
		if kind == key then return true end
	end
	return false
end

-- The zone picker's menu: where you are, then every zone with quests by continent, each with how many you
-- could take there now.
local function ZoneMenu(root)
	local Why = ns.Why
	if not Why then return end
	if W.map and browsed ~= W.map then
		root:CreateButton("Where you are", function()
			picked = false
			Browse()
		end):SetDetail(W.MapName(W.map) or "")
	end
	for _, group in ipairs(Why.Zones()) do
		local sub = root:CreateButton(group.name)
		sub:SetScrollMode(360)
		for _, each in ipairs(group.maps) do
			local map = each.map
			local entry = sub:CreateRadio(each.name, function() return browsed == map end, function()
				browsed, picked = map, true
				Browse()
			end)
			local now = #L.StartsOn(map)
			if now > 0 then entry:SetDetail(tostring(now)) end
		end
	end
end

-- The left pane

-- A row of what to find: its picture in a tile, its name, and at the right its count, its caret (a
-- menu) or the star that keeps the service on the map. Lit as a pressed row while it is what the list
-- shows, in the family's own look (UI.Press).
local function Category(spec, y)
	local row = CreateFrame("Button", nil, side.content)
	row:SetSize(SIDE - 14, SIDE_ROW)
	row:SetPoint("TOPLEFT", 0, -y)
	row.key, row.spec = spec.key, spec
	local tile = CreateFrame("Frame", nil, row)
	tile:SetSize(TILE, TILE)
	tile:SetPoint("LEFT", 8, 0)
	if spec.mark then
		row.mark = ns.CreateMark(tile, TILE - 2)
		row.mark:SetPoint("CENTER")
		row.mark:Set(spec.mark)
	else
		tile.icon = tile:CreateTexture(nil, "ARTWORK")
		tile.icon:SetAllPoints()
		if spec.glyph or spec.sign then
			if spec.sign then Shy.Hover.Glyph(tile.icon, spec.sign, TILE) else tile.icon:SetTexture(spec.glyph) end
			UI.Tint(tile.icon, C.hot, 1)
			tile.slot = Shy.Slot.New(tile, { size = TILE, well = false })
			tile.slot:Empty(true)
		else
			tile.icon:SetTexture(Picture(spec.picture or spec.key))
			tile.slot = Shy.Slot.New(tile, { icon = tile.icon, size = TILE })
		end
	end
	row.tile = tile
	row.label = UI.Text(row, spec.label, 13, false, C.text)
	row.label:SetPoint("LEFT", tile, "RIGHT", 10, 0)
	row.label:SetWidth(SIDE - 14 - 8 - TILE - 10 - 44)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.right = UI.Text(row, "", 11, false, C.hot)
	row.right:SetPoint("RIGHT", -10, 0)
	if spec.menu then
		row.caret = row:CreateTexture(nil, "ARTWORK")
		row.caret:SetSize(10, 10)
		row.caret:SetPoint("RIGHT", -10, 0)
		row.caret:SetTexture(Shy.Skin.GLYPH.caret)
		row.caret:SetRotation(math.pi / 2)
		UI.Tint(row.caret, C.text, 0.85)
	end
	if CanKeep(spec.key) then
		local star = CreateFrame("Button", nil, row)
		star:SetSize(STAR + 8, STAR + 8)
		star:SetPoint("RIGHT", -6, 0)
		star.glyph = star:CreateTexture(nil, "ARTWORK")
		star.glyph:SetSize(STAR, STAR)
		star.glyph:SetPoint("CENTER")
		star.glyph:SetTexture(Shy.MEDIA .. "GlyphStar")
		star:SetScript("OnClick", function()
			T.db.services[spec.key] = not T.db.services[spec.key] or nil
			ns.Apply()
			Light()
		end)
		star:SetScript("OnEnter", function(self)
			UI.Tint(self.glyph, C.alert, 1)
			UI.Tip(self, "Keep on the map", ("%s stay on the map no matter what you search for."):format(KEPT[spec.key] or spec.label), { side = "CURSOR" })
		end)
		star:SetScript("OnLeave", function(self)
			UI.TipHide(self)
			Light()
		end)
		row.star = star
	end
	UI.Press(row, { fill = C.row, bare = true, sink = { tile, row.label, row.right } })
	function row:OnLook(s)
		if s.on and not s.down then UI.Paint(self.shyBg, C.fill) end
	end
	row:SetOn(false)
	row:SetScript("OnClick", function(self)
		if spec.menu then
			Shy.UI.DropMenu(self, spec.menu)
		elseif spec.key == "quests" then
			Browse()
		elseif spec.key == "friends" then
			Nearby("friends", nil, nil, nil, "Nobody on your friends list is online.")
		elseif spec.key == "favorites" or spec.key == "best" then
			FarmSide(spec.key)
		else
			Nearby(spec.key, spec.title and nil or spec.key, spec.title and spec.title() or nil, spec.word, spec.nothing or NONE)
		end
	end)
	if spec.help then UI.Help(row, spec.label, spec.help, { side = "CURSOR" }) end
	cats[#cats + 1] = row
	return row
end

local function BuildSide()
	local y = 4
	for _, section in ipairs(SECTIONS) do
		-- (A section another addon answers for stands only with it: ShyFarm's favorites.)
		if not section.when or section.when() then
			local head = UI.Text(side.content, section.head, 10, false, C.dim)
			head:SetPoint("TOPLEFT", 8, -y - (SIDE_HEAD - 12))
			y = y + SIDE_HEAD
			for _, spec in ipairs(section.rows) do
				Category(spec, y)
				y = y + SIDE_ROW
			end
			y = y + 6
		end
	end
	side.content:SetHeight(y)
	side:Update()
end

-- The chosen row lit (the professions' and trainers' rows for any of theirs), every star as kept or not,
-- and the counts.
Light = function()
	for _, row in ipairs(cats) do
		local key, spec = row.key, row.spec
		local on = chosen == key
		if chosen and key == "profession" and chosen:sub(1, 2) == "p:" then on = true end
		if chosen and key == "trainers" and chosen:sub(1, 2) == "t:" then on = true end
		row:SetOn(on)
		if row.star then
			local kept = T.db.services[key] == true
			UI.Tint(row.star.glyph, kept and C.alert or C.dim, kept and 1 or 0.35)
		end
		if spec.count then
			local n = spec.count()
			row.right:SetText(n > 0 and tostring(n) or "")
		end
	end
end

-- For tests and other addons: the left pane's row for a category.
function F.Category(key)
	for _, row in ipairs(cats) do
		if row.key == key then return row end
	end
end

-- The window flows: wider, the list is (the left pane keeps its width); taller, both panes are.
local function Lay(_, width, height)
	wide = width - SIDE - PAD
	local listW = width - PAD * 3 - SIDE
	local tall = height - HEADER - PAD - 8
	side:SetSize(SIDE, tall)
	rule:SetHeight(tall)
	input:SetWidth(listW)
	scroll:SetSize(listW, height - HEADER - 10 - SEARCH - 10 - PAD)
	scroll.content:SetWidth(listW - 14)
	for _, row in ipairs(rows) do
		row:SetWidth(listW - 14)
		row.name:SetWidth(listW - 120)
		row.detail:SetWidth(listW - 70)
	end
	for _, head in ipairs(heads) do head:SetWidth(listW - 14) end
	if routeHead then routeHead:SetWidth(listW - 14) end
	for _, row in ipairs(stopRows) do
		row:SetWidth(listW - 14)
		row.name:SetWidth(listW - 120)
		row.detail:SetWidth(listW - 70)
	end
	zoneButton:SetWidth(listW - 14)
	zoneButton.text:SetWidth(listW - 14 - 31)
	empty:SetWidth(listW - 40)
	scroll:Update()
end

local function Create()
	box = UI.Window({
		id = "shyquest.find",
		name = "ShyQuestFinder",
		title = "ShyQuest finder",
		width = WIDTH,
		height = HEIGHT,
		point = { "CENTER", "CENTER", 260, 20 },
		shown = function() return open end,
		grip = { flow = Lay, max = { 640 } },
		strata = "HIGH",
		onClose = function() open = false end,
		close = function() F.Toggle(false) end,
		head = { size = "window", icon = T.mark, title = "Find" },
	})
	-- Open or shut, however it happened (its lens, Esc, its ×, a command): the quest card's lens stays lit with it.
	box:HookScript("OnShow", function() Shy:Fire("SHYQUEST_FINDER", true) end)
	box:HookScript("OnHide", function()
		-- (Shut, it was a picker for nobody any more.)
		picker = nil
		Shy:Fire("SHYQUEST_FINDER", false)
	end)

	local listW = WIDTH - PAD * 3 - SIDE
	local listX = PAD + SIDE + PAD
	-- Everything under the header stands on the body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)

	-- The left pane: what to find, with a hairline between it and the list.
	side = UI.ScrollArea(body, SIDE, HEIGHT - HEADER - PAD - 8)
	side:SetPoint("TOPLEFT", PAD, -HEADER - 8)
	rule = box:CreateTexture(nil, "ARTWORK")
	rule:SetWidth(1)
	rule:SetPoint("TOPLEFT", side, "TOPRIGHT", PAD / 2, 0)
	UI.Paint(rule, C.border)
	BuildSide()

	-- The right pane: the search box over the list.
	input = UI.Input(body, nil, function() return query end, function(text) Look(text) end,
		{ width = listW, live = true, maxLetters = 40,
		placeholder = function() return farmSide and "Search for an item or creature to farm" or "Quest, creature, object, item or friend" end })
	input:SetPoint("TOPLEFT", listX, -HEADER - 10)
	input:Refresh()
	scroll = UI.ScrollArea(body, listW, HEIGHT - HEADER - 10 - SEARCH - 10 - PAD)
	scroll:SetPoint("TOPLEFT", listX, -HEADER - 10 - SEARCH - 10)
	-- The zone the list is of, in the list's head: its caret picks another.
	zoneButton = UI.MenuButton(scroll.content, { write = ZoneMenu, width = listW - 14, height = ZONE - 6,
		font = UI.NameFont(13), caretY = 1, inset = NAMES, menu = { fit = true } })
	zoneButton:Hide()
	empty = UI.Text(body, "", 13, false, C.dim)
	empty:SetPoint("TOP", scroll, "TOP", 0, -40)
	empty:SetWidth(listW - 40)
	empty:SetJustifyH("CENTER")
	Lay(box, WIDTH, HEIGHT)
	Light()

	-- Your farming changed (ShyFarm): the farm side's list again (the best farms as they are weighed, the favorites
	-- with their stats, what you farm now), and the counts.
	Shy:On("SHY_FARM", function()
		if not open then return end
		if farmSide then
			if strtrim(query) == "" then FarmList() end
			Fill()
		end
		Light()
	end)

	-- Your route changed (here, on the card, on the map): it is laid again.
	ns.Plan.Watch(function()
		if open then Fill() end
	end)
	ns.OnRoute(function()
		if not open then return end
		Light()
		-- (Your route's times are from where you stand: they are said again as you go.)
		if #ns.Plan.List() > 0 then LayRoute(0) end
		-- The zone's list again when how its quests stand has changed, or you walked into another zone.
		if query == "" and not town and ns.Why then
			local map = picked and browsed or W.map
			if map ~= browsed or (map and ns.Why.Zone(map).sig ~= shownSig) then
				Browse()
				return
			end
			-- How far along a quest in the log is isn't in the list's sig: those rows are said again.
			for _, row in ipairs(rows) do
				local result = row:IsShown() and row.result
				if result and result.state == "log" then
					result.finished = nil
					PaintRow(row, result)
				end
			end
		end
		for _, row in ipairs(rows) do
			local result = row:IsShown() and row.result
			if result and result.points then
				result.nearest, result.yards = Nearest(result.points)
				if result.farm then
					FarmRight(row, result)
				else
					row.far:SetText(result.quiet and "" or W.Yards(result.yards))
				end
			end
		end
	end)
end

-- The window's frame, once made.
function F.Window()
	return box
end

-- Opens the window on a zone's quests: `map`'s, or (nil) the one you are in, followed as you go.
function F.Browse(map)
	if not box then Create() end
	browsed, picked = map, map ~= nil
	open = true
	Shy.HUD.Update(box)
	Browse()
	input:Refresh()
end

-- Opens the window on what you could farm (T:FindFarm): the best farms (opts.list "favorites": your favorites), the
-- search box ready for a name. opts.pick(kind, id) is told what was picked, in place of farming it.
function F.Farm(opts)
	if not box then Create() end
	open = true
	Shy.HUD.Update(box)
	picker = opts
	FarmSide(opts and opts.list == "favorites" and "favorites" or "best")
	input.box:SetFocus()
end

-- Opens or closes the window; with `text`, opens with that search. With nothing asked it lists the zone's
-- quests; `map` lists that zone's.
function F.Toggle(show, text, map)
	if not box then Create() end
	if show == nil then show = not open end
	open = show and true or false
	Shy.HUD.Update(box)
	if open then
		if map then browsed, picked = map, true end
		if text and text ~= "" then
			-- (A search asked for is of everything, whatever side the window was left on.)
			farmSide, picker = false, nil
			Look(text)
			input:Refresh()
		elseif map or (query == "" and not town) then
			Browse()
			input:Refresh()
		else
			Fill()
		end
	end
end
