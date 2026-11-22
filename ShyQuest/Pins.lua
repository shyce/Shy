-- Pins on the world map and minimap: quest givers (!) and turn-ins (?), objective marks where the
-- game marks nothing, zones worth travelling to (numbered by quest count), and the route's next places
-- numbered in the card's order with lines between them. Marks.lua draws a pin; Ground.lua draws the
-- ground a quest is done on.
--
-- Taint: the world map's pin pools are for Blizzard's code (addon pins can block the map's protected
-- actions in combat), so these are our own frames on a layer over the map's canvas (Shy.Maps.MapLayer: the
-- game's, or ShyMaps' view while that draws the map), placed by
-- fraction and kept at one on-screen size as the map zooms.
--
-- Rules the layout keeps:
--   * A place has one number on every map, every zoom and the minimap.
--   * No pin overlaps another or a default quest marker: the less important one moves aside (Clear).
--     Route places never move.
--   * Nothing is shown twice: one pin per NPC, nearby marks of one kind merge, a quest giver covered
--     by a numbered step gets no pin.
--   * Route places that would overlap at the current zoom are one pin, and a line is drawn only where
--     there is room, so a continent map is an overview.
--   * A hover shows the ground of a pin's quests on its map; a left click keeps it on both maps (with a note
--     at the top of the world map) until clicked again; a right click heads there.
--   * A kept pin with quests to take has their page on the world map (Offer.lua: what each asks for and
--     gives), and a click on such a pin on the minimap opens the map there.
--   * The minimap shows the same route and numbers; the leading place waits at the rim when out of range.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Z, G, Tips = ns.Data, ns.World, ns.Log, ns.Route, ns.Zones, ns.Guide, ns.Tips
local UI = Shy.UI
local C = UI.colors

local UNITS = 10000
-- Pins and marks: their sizes, room and how many.
local PIN = {
	mapSize = 27,
	miniSize = 20,
	grow = 0.4,
	miniGrow = 0.3,  -- extra pin size at the closest zoom, linear from the widest
	edge = 0.86,  -- how far toward the minimap's rim a pin may sit
	waiting = 0.7,  -- alpha of the leading pin while it waits at the rim
	zones = 5,  -- zones numbered on the world map
	guide = 8,  -- guide steps looked ahead on the minimap and the card
	guideFar = 40,  -- and on the world map, at every zoom (a zone shows what its continent does)
	room = 0.92,  -- clearance a pin keeps, in pin sizes
	merge = 1.15,  -- route places nearer than this many pin sizes are one pin
	place = 60,  -- yards: guide steps nearer than this are one route place, on every map
	levels = 20,  -- pins with a frame level of their own, most important on top
	names = 3,  -- names listed in the note at the top of the map
	together = 0.8,  -- marks of one kind nearer than this many pin sizes merge
	same = 12,  -- yards: objectives nearer than this are one mark on a zone map
	goalNear = 600,  -- map units (of 10000): objectives of one quest nearer than this share a mark
	goalArrive = 60,  -- yards: a mark moves to another of its places once the player is this near it
}
-- zoomed: 0 at a map's widest zoom to 1 at its closest. most: its PIN.grow.
local function Grown(zoomed, most)
	-- A map with a single zoom level can give nil or NaN.
	if not zoomed or zoomed ~= zoomed then zoomed = 0 end
	return 1 + most * math.max(0, math.min(1, zoomed))
end
-- Size of a mark relative to a lit one, a turn-in or a zone. guide: a catch-up step off the route.
local WEIGHT = { pickup = 0.85, goal = 0.85, step = 0.9, guide = 0.85, sell = 0.85, train = 0.85, buy = 0.85,
	weapon = 0.85, aid = 0.85, flight = 0.85, home = 0.85, potion = 0.85, herb = 0.85, sail = 0.85,
	zeppelin = 0.85, bank = 0.85, mail = 0.85 }
-- The trail and the route's legs between pins.
local LEG = {
	rim = 0.56,  -- a line ends this far from a pin's middle, in pin sizes
	way = 0.5,  -- alpha of the live step's own path
	walkLine = 3,  -- thickness of a walker's way on the minimap, in screen pixels at the world map's size
	youRoom = 0.45,  -- the trail starts this far from the player, in pin sizes
	youEvery = 0.2,  -- seconds between position checks while the map is open
	-- Route lines, in screen pixels at the world map's size
	bow = 0.16,  -- a leg's bow to the right of its direction, as a share of its length
	flowWide = 9.4,
	flowFine = 2.4,  -- a leg's thickness at its start and end
	flowLater = 2.8,  -- start thickness of the last leg shown
	flowEnd = 0.7,  -- a leg's alpha at its end, relative to its start
	askEnd = 0.8,  -- the same for a leg of a hovered route
	flowFade = 0.25,  -- each leg moves this far toward the last leg's look
	flowRoom = 0.8,  -- a leg needs pins at least this many pin sizes apart
	reveal = 0.16,  -- seconds a hovered route takes to draw in and out
	miniLine = 0.65,  -- scale of lines on the minimap
	miniClear = 0.16,
	miniClearLow = 0,  -- a pin within this share of the minimap's range fades, to this much at its middle
	miniYou = 10,  -- the minimap trail starts this far from its middle, clear of the player arrow
	glide = 0.3,  -- seconds the leading pin takes to slide along the rim to where the trail now leaves
}
-- How a way over the ground is made smooth (Smoothed), for the whole way and (close) its beginning found up
-- close: wiggle: yards a way may stray from its points and leave them out (the ground's ways step along a
-- grid); round: yards either side of a turn that are rounded; steps: pieces a rounded turn is drawn in.
local TURN = { wiggle = 9, round = 45, closeWiggle = 1.5, closeRound = 8, steps = 8 }

-- Room for every pin

-- Offsets tried when a pin's place is taken, in pin sizes, nearest first.
local ASIDE = {
	{ 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, -1 }, { 1, 1 }, { -1, -1 }, { -1, 1 },
	{ 2, 0 }, { -2, 0 }, { 0, -2 }, { 0, 2 }, { 2, -1 }, { 2, 1 }, { -2, -1 }, { -2, 1 }, { 3, 0 },
}

local function Free(taken, x, y, room)
	for _, spot in ipairs(taken) do
		local dx, dy = x - spot[1], y - spot[2]
		if dx * dx + dy * dy < room * room then return false end
	end
	return true
end

-- The spot nearest (x, y) that is `room` clear of everything in `taken`, added to `taken`. With none
-- free it stays at (x, y).
local function Clear(taken, x, y, room)
	local px, py = x, y
	if not Free(taken, x, y, room) then
		for _, step in ipairs(ASIDE) do
			local tx, ty = x + step[1] * room, y + step[2] * room
			if Free(taken, tx, ty, room) then
				px, py = tx, ty
				break
			end
		end
	end
	taken[#taken + 1] = { px, py }
	return px, py
end

-- Quest givers and turn-ins on a map

-- Every quest giver and turn-in NPC on `map` as a stop: { who, thing, kind, map, x, y, actions }.
-- covered: actions the numbered steps already show ("turnin12"); those get no pin.
local function StopsOn(map, covered)
	local stops, at = {}, {}

	-- One pin per NPC or object, at the nearest of its places on this map (a patrol has several).
	-- Returns whether the action went onto a pin.
	local function Add(token, action)
		if covered[action.kind .. action.id] then return false end
		if token.kind ~= "n" and token.kind ~= "o" then return false end
		local thing = D.Thing(token.kind, token.id)
		if not thing or (token.kind == "n" and not L.Friendly(thing)) then return false end
		local key = token.kind .. token.id
		local stop = at[key]
		if stop == nil then
			-- W.Steady keeps the chosen place, so a patrolling NPC's pin doesn't jump.
			local name = "on" .. map .. ":" .. key
			local hold = W.Kept(name)
			local best, was
			for _, place in ipairs(thing.places) do
				if place.map == map then
					for i = 1, #place.points, 2 do
						local x, y = place.points[i], place.points[i + 1]
						local yards = W.Distance(map, x, y)
						if not best or (yards and (not best.yards or yards < best.yards)) then
							best = { map = map, x = x, y = y, yards = yards, dungeon = place.dungeon }
						end
						if hold and yards and hold.x == x and hold.y == y then
							was = { map = map, x = x, y = y, yards = yards, dungeon = place.dungeon }
						end
					end
				end
			end
			best = W.Steady(name, best, was)
			stop = false
			if best then
				stop = { who = thing.name, thing = thing, kind = action.kind, map = map, x = best.x, y = best.y, key = key,
					dungeon = best.dungeon, actions = {}, yards = best.yards }
				stop.continent, stop.north, stop.west = W.ToWorld(map, best.x, best.y)
				stops[#stops + 1] = stop
			end
			at[key] = stop
		end
		if not stop then return false end
		stop.actions[#stop.actions + 1] = action
		if action.kind == "turnin" then stop.kind = "turnin" end
		return true
	end

	for _, entry in ipairs(L.order) do
		local quest = entry.complete and D.Quest(entry.id)
		if quest then
			local action = { kind = "turnin", id = entry.id, title = entry.title, level = entry.level }
			for _, token in ipairs(quest.ends) do Add(token, action) end
		end
	end
	if ns.Pickups() then
		for _, quest in ipairs(L.StartsOn(map)) do
			local action = { kind = "pickup", id = quest.id, title = quest.name, level = quest.level }
			local offered = false
			for _, token in ipairs(quest.starts) do
				if Add(token, action) then offered = true end
			end
			-- Started by an item: one pin at the nearest source (drop, container, vendor) on this map.
			if not offered then
				local best
				for _, token in ipairs(quest.starts) do
					local start = token.kind == "i" and D.StartItem(token.id)
					for _, source in ipairs(start and start.sources or {}) do
						local thing = D.Thing(source.kind, source.id)
						for _, place in ipairs(thing and (source.kind ~= "v" or L.Friendly(thing)) and thing.places or {}) do
							if place.map == map and not place.dungeon then
								for i = 1, #place.points, 2 do
									local x, y = place.points[i], place.points[i + 1]
									local yards = W.Distance(map, x, y)
									if not best or (yards or math.huge) < (best.yards or math.huge) then
										best = { thing = thing, x = x, y = y, yards = yards, item = token.id, from = source.kind, chance = source.chance }
									end
								end
							end
						end
					end
				end
				local key = best and ("d" .. best.from .. best.thing.id)
				if best and not covered["pickup" .. quest.id] then
					local stop = at[key]
					if not stop then
						stop = { who = best.thing.name, thing = best.thing, kind = "pickup", map = map, x = best.x, y = best.y, key = key,
							actions = {}, yards = best.yards }
						stop.continent, stop.north, stop.west = W.ToWorld(map, best.x, best.y)
						at[key] = stop
						stops[#stops + 1] = stop
					end
					stop.actions[#stop.actions + 1] = { kind = "pickup", id = quest.id, title = quest.name, level = quest.level,
						item = best.item, from = best.from, chance = best.chance }
				end
			end
		end
	end
	return stops
end

-- Objective marks for log quests the game doesn't mark on `map` but the data places there: one per
-- open objective, where its stop would stand (R.Best: at the heart of the best camp of what is killed,
-- looted or gathered, not on a lone spawn that happens to be near), or at its nearest place on a map
-- the player isn't on. Objectives of one quest within PIN.goalNear share a mark.
--   marked: quests the game marks on this map. covered: as for StopsOn.
--   pass: what has been chosen for the map shown (MapPass): each objective's best camp is chosen once for
--   all the maps a gather draws (a continent asks it of every zone on it), and each map's spot kept until
--   the route is built again; the minimap shares its zone's. With none, it is all chosen afresh.
local function GoalsOn(map, marked, covered, pass)
	local stops = {}
	-- Where objective `index` of a quest (or the quest as a whole) is marked on this map: { x, y, yards },
	-- or nil.
	local function Spot(id, index)
		-- The choice is kept (R.Best's key, W.Steady) until another is clearly better, or the player
		-- arrives at another, so the mark doesn't hop between spawns as the player moves. The best camp is
		-- one for every map (the zone's, its continent's and the minimap show the same); a spot of its own
		-- on a map without that camp is that map's.
		local key = "pin:" .. id .. ":" .. (index or 0)
		local best
		if pass then
			best = pass.bests[key]
			if best == nil then
				best = R.Aimed(id, index) or R.Best(id, index, key) or false
				pass.bests[key] = best
			end
			best = best or nil
		else
			best = R.Aimed(id, index) or R.Best(id, index, key)
		end
		if best and best.map == map then return best end
		key = "pin" .. map .. ":" .. id .. ":" .. (index or 0)
		local hold, was = W.Kept(key), nil
		local least
		best = nil
		for _, point in ipairs(R.WhereOn(id, index, map)) do
			local yards = W.Distance(map, point.x, point.y)
			if not best or (yards and (not least or yards < least)) then best, least = point, yards or least end
			if hold and yards and hold.x == point.x and hold.y == point.y then was = { map = map, x = point.x, y = point.y, yards = yards } end
		end
		if not best then return nil end
		return W.Steady(key, { map = map, x = best.x, y = best.y, yards = least }, was, PIN.goalArrive)
	end
	-- The pin for objective `index` of a quest, or for the quest as a whole. own: the quest's pins so far.
	local function Pin(action, index, own)
		local best
		if pass then
			local key = map .. ":" .. action.id .. ":" .. (index or 0)
			best = pass.spots[key]
			if best == nil then
				best = Spot(action.id, index) or false
				pass.spots[key] = best
			end
		else
			best = Spot(action.id, index)
		end
		if not best then return false end
		local least = best.yards
		for _, stop in ipairs(own) do
			if (stop.x - best.x) ^ 2 + (stop.y - best.y) ^ 2 < PIN.goalNear ^ 2 then
				stop.objective = nil
				return true
			end
		end
		local stop = { kind = "goal", map = map, x = best.x, y = best.y, yards = least, actions = { action },
			objective = index, key = "goal" .. action.id .. ":" .. (index or 0) }
		stop.continent, stop.north, stop.west = W.ToWorld(map, best.x, best.y)
		stops[#stops + 1] = stop
		own[#own + 1] = stop
		return true
	end
	for _, entry in ipairs(L.order) do
		local id = entry.id
		if not entry.complete and not entry.failed and not marked[id] and not covered["goal" .. id] then
			local action = { kind = "goal", id = id, title = entry.title, level = entry.level }
			local own = {}
			for index, goal in ipairs(L.Goals(id)) do
				if not goal.finished and #goal.tokens > 0 then Pin(action, index, own) end
			end
			-- No objective on this map: try the quest's own places.
			if #own == 0 then Pin(action, nil, own) end
		end
	end
	return stops
end

-- Pin frames

-- Hover and click behave the same on both maps, and the clicked pin is shared between them.
local Pick, Over   -- a pin was clicked; the mouse entered or left one
-- .pin: the pin under the mouse. .mini: it is a minimap pin. .hushed: its light was just clicked off
-- and stays off until the mouse leaves.
local over = {}
-- Spawn lights as each map last laid them out (LayMap, DrawMini):
--   map, mini: the clicked pin's stop on that map.
--   headed, miniHeaded: the leading stop there, lit unasked.
--   rest, width, height: the world map's other lights, and its layer's size.
local look = {}

local function Hints(pin)
	local stop = pin.stop
	local first = { "left", pin.picked and "Hide where to look" or "Show where to look" }
	-- (With quests to take, the click is their page too: Offer.lua.)
	if stop.kind ~= "zone" and ns.Offer and #ns.Offer.Quests(stop) > 0 then
		first[2] = pin.picked and "Hide the details" or "Show the details"
	end
	if stop.kind == "zone" then
		first[2] = pin.picked and "Hide quest givers" or "Show quest givers"
		return { first, { "right", stop.chosen and "Let the route choose" or "Head there" } }
	end
	if stop.kind == "errand" or stop.kind == "way" then return { { "right", "Point the way" } } end
	if stop.party then return { first } end
	if stop.kind == "guide" or stop.kind == "fly" then return { first, { "right", "Point the way" } } end
	return { first, { "right", stop.chosen and "Remove from my route" or "Go here next" } }
end

-- mini: a minimap pin. Only the world map draws the route to a hovered pin.
local function NewPin(parent, size, mini)
	local pin = ns.CreateMark(parent, size, nil, true)
	pin:SetMouseMotionEnabled(true)
	pin:SetMouseClickEnabled(true)
	pin:SetScript("OnEnter", function(self)
		if not self.stop then return end
		self:SetHovered(true)
		Tips.ShowStop(self, self.stop, "RIGHT", Hints(self), mini)
		Over(self, mini)
		if not mini then ns.RevealWay(self.stop) end
	end)
	pin:SetScript("OnLeave", function(self)
		self:SetHovered(false)
		Tips.Close(self)
		if over.pin == self then Over(nil, mini) end
		if not mini then ns.RevealWay(nil) end
	end)
	pin.minimap = mini
	pin:SetScript("OnMouseUp", function(self, button)
		if not self.stop then return end
		if button == "LeftButton" then
			local on = Pick(self)
			-- Kept with its light: the hover stays and says the whole of it, with what to do about it (CardHover.lua).
			if ns.CardHover and ns.CardHover.KeepPin then ns.CardHover.KeepPin(self, on) end
		elseif button == "RightButton" and not self.stop.party then
			-- As Hints says: the arrow for a guide step, flight or errand; the route for a quest or zone.
			local kind = self.stop.kind
			if kind == "guide" or kind == "fly" or kind == "errand" or kind == "way" then ns.PointTheWay(self.stop) else R.Go(self.stop) end
		end
		if over.pin == self and self.stop then
			Tips.ShowStop(self, self.stop, "RIGHT", Hints(self), mini)
		end
	end)
	return pin
end

-- A pin pool. Pins are taken in order of importance; the first is on top.
-- A frame's pictures, and its children's, off the screen's pixel grid: on the sliding plate a snapped one
-- moves a whole pixel at a time, where the trail beside it (Shy.Maps lines) glides.
function ns.Unsnap(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.SetSnapToPixelGrid then
			region:SetSnapToPixelGrid(false)
			region:SetTexelSnappingBias(0)
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do ns.Unsnap(child) end
end
local function Pool(parent, size, mini)
	local pool = { used = 0 }
	function pool:Next()
		self.used = self.used + 1
		local pin = self[self.used]
		if not pin then
			pin = NewPin(parent, size, mini)
			ns.Unsnap(pin)
			pin.level = parent:GetFrameLevel() + 1 + math.max(0, PIN.levels - self.used)
			pin:SetFrameLevel(pin.level)
			self[self.used] = pin
		end
		return pin
	end
	function pool:Done()
		for i = self.used + 1, #self do
			self[i]:Hide()
			self[i].stop = nil
			if over.pin == self[i] then over.pin = nil end
		end
		self.used = 0
	end
	return pool
end

-- Town services kept on the map
-- Each kind switched on in T.db.services gets a small mark (the minimap tracking icon) at every such
-- NPC or object on the shown map. No click; they move aside for quest pins.

-- kind -> its minimap tracking type, the label under the name, and the game's own picture for it where the
-- tracking list has none (file); objects: the kind is objects, not people.
local SERVICES = {
	inn = { "Innkeeper", "Innkeeper" }, flight = { "TaxiNode", "Flight master" }, repair = { "Repair", "Repairs" },
	mail = { "Mailbox", "Mailbox", objects = true }, bank = { "Banker", "Banker" }, auction = { "Auctioneer", "Auctioneer" },
	stable = { "Stablemaster", "Stable master" }, trainer = { "TrainerClass", "Class trainer" },
	profession = { "TrainerProfession", "Profession trainer", file = "Interface\\Minimap\\Tracking\\Profession" },
	spirit = { nil, "Spirit healer", file = "Interface\\Icons\\Spell_Holy_GuardianSpirit" },
	stone = { nil, "Meeting stone", file = "Interface\\Icons\\Spell_Nature_AstralRecalGroup", objects = true },
	food = { "VenderFood", "Food and drink", file = "Interface\\Minimap\\Tracking\\Food" },
	reagents = { "VendorReagent", "Reagents", file = "Interface\\Minimap\\Tracking\\Reagents" },
	poisons = { "VendorPoison", "Poisons", file = "Interface\\Minimap\\Tracking\\Poisons" },
	ammo = { "VendorAmmo", "Ammunition", file = "Interface\\Minimap\\Tracking\\Ammunition" },
	trade = { nil, "Trade goods", file = "Interface\\Icons\\INV_Fabric_Linen_01" },
	-- (The finder's alone: not one to keep on the map.)
	bags = { nil, "Bags", file = "Interface\\Icons\\INV_Misc_Bag_08" },
}
ns.SERVICES = { "inn", "flight", "repair", "mail", "bank", "auction", "stable", "trainer", "profession", "spirit", "stone",
	"food", "reagents", "poisons", "ammo", "trade" }
local SERVICE = {
	size = 16,
	most = 80,  -- marks on one map at most
}

local servicePins = { used = 0 }
local services = {}          -- on the shown map: { kind, thing, x, y }
local pictures               -- kind -> tracking icon

local function Picture(kind)
	if not pictures then
		pictures = {}
		local byFilter = {}
		for index = 1, C_Minimap.GetNumTrackingTypes() do
			local info, filter = C_Minimap.GetTrackingInfo(index), C_Minimap.GetTrackingFilter(index)
			if info and filter and filter.filterID then byFilter[filter.filterID] = info.texture end
		end
		for name, service in pairs(SERVICES) do
			pictures[name] = service[1] and byFilter[Enum.MinimapTrackingFilter[service[1]]] or service.file
		end
	end
	return pictures[kind]
end
ns.ServicePicture = Picture

-- Every NPC or object of the enabled kinds on `map` that is friendly to the player.
local function ServicesOn(map)
	local list = {}
	local on = T.db.services
	for _, kind in ipairs(ns.SERVICES) do
		if on and on[kind] then
			local ids
			if kind == "trainer" then
				local title = ns.Find and ns.Find.ClassTrainer and ns.Find.ClassTrainer()
				ids = title and D.Town(nil, title) or {}
			else
				ids = D.Town(kind)
			end
			local objects = SERVICES[kind].objects
			for _, id in ipairs(ids) do
				local thing = D.Thing(objects and "o" or "n", id)
				if thing and (objects or L.Friendly(thing)) then
					for _, place in ipairs(thing.places) do
						if place.map == map and not place.dungeon then
							for i = 1, #place.points, 2 do
								if #list < SERVICE.most then
									list[#list + 1] = { kind = kind, thing = thing, x = place.points[i], y = place.points[i + 1] }
								end
							end
						end
					end
				end
			end
		end
	end
	return list
end

local function ServicePin(parent)
	servicePins.used = servicePins.used + 1
	local pin = servicePins[servicePins.used]
	if not pin then
		pin = CreateFrame("Frame", nil, parent)
		pin:SetSize(SERVICE.size, SERVICE.size)
		pin:SetFrameLevel(parent:GetFrameLevel())
		pin.picture = pin:CreateTexture(nil, "ARTWORK")
		pin.picture:SetAllPoints()
		pin:SetMouseMotionEnabled(true)
		pin:SetMouseClickEnabled(false)
		pin:SetScript("OnEnter", function(self)
			local service = self.service
			if not service then return end
			UI.Tip(self, service.thing.name, service.thing.title or SERVICES[service.kind][2],
				{ side = "RIGHT", note = W.Yards(W.Distance(service.map, service.x, service.y)) })
		end)
		pin:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		servicePins[servicePins.used] = pin
	end
	return pin
end

-- World map

local layer, mapPins, note
local lines = { used = 0 }   -- dashed path lines, in pairs: a dark line under a light one
-- Contents of the shown map: gathered when the map or route changes (DrawMap), laid out on each zoom (LayMap).
local shownMap
local steps = {}             -- the route ahead (Ahead): { stop } or { view }
local wayPlaces, wayWalk = {}, {}   -- its numbered places with their (x, y) on this map, and the legs between them (TheWay)
local others = {}            -- quest givers, turn-ins and zones: { stop, x, y, kind, count }
local theirs = {}            -- positions of the default quest markers: { x, y }
local theirMarks = {}        -- quests the game marks here, by ID
local picked                 -- key of the clicked pin
local found                  -- a search result shown in place of a pin's stop (ns.ShowOnMap)

-- A world position on the shown map (a continent, or an overlapping zone), as fractions; nil for one on
-- another continent, whose yards would land anywhere on this one. loose: past the map's edges too (a
-- route place beyond a zone, which its legs in and out still reach).
local function WorldOnMap(map, continent, north, west, loose)
	if not continent then return nil end
	local here = W.ToWorld(map, UNITS / 2, UNITS / 2)
	if here and here ~= continent then return nil end
	local _, position = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(north, west), map)
	if not position then return nil end
	local x, y = position:GetXY()
	if loose or (x > 0.02 and x < 0.98 and y > 0.02 and y < 0.98) then return x, y end
end

local function OnMap(map, zone)
	return WorldOnMap(map, W.ToWorld(zone.map, zone.hub.x, zone.hub.y))
end

-- A continent, world or cosmic map.
local function Wide(map)
	local info = C_Map.GetMapInfo(map)
	local kind = info and info.mapType
	return kind == Enum.UIMapType.Continent or kind == Enum.UIMapType.World or kind == Enum.UIMapType.Cosmic
end

-- A pair of regions from a pool, created on demand.
local function Pair(pool, make)
	pool.used = pool.used + 1
	local pair = pool[pool.used]
	if not pair then
		pair = { make(0), make(1) }
		pool[pool.used] = pair
	end
	pair[1]:Show()
	pair[2]:Show()
	return pair[1], pair[2]
end

-- Hide what a pool no longer uses. pool.shown: how many of its entries were in use the last time, so
-- a pool laid again every frame hides only what was showing.
local function HideRest(pool)
	for i = pool.used + 1, pool.shown or #pool do
		for _, region in ipairs(pool[i]) do region:Hide() end
	end
	pool.shown = pool.used
end

-- A dashed line between two points in canvas units: Media\Dash (soft edges and ends) tiled by the
-- line's on-screen length, in the trail's light (or `color`) over a dark shadow. strength: 1 down to LEG.way,
-- thinner and fainter as it falls.
local DASHES = {
	art = ns.MEDIA .. "Dash",
	period = 14,  -- screen pixels per dash and gap
}
local function Draw(shadow, light, ax, ay, bx, by, canvas, strength, color)
	local tiles = math.max(1, math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) * canvas / DASHES.period)
	for _, line in ipairs({ shadow, light }) do
		line:SetStartPoint("TOPLEFT", layer, ax, -ay)
		line:SetEndPoint("TOPLEFT", layer, bx, -by)
		line:SetTexture(DASHES.art, "REPEAT", "CLAMP")
		line:SetTexCoord(0, tiles, 0, 1)
	end
	shadow:SetVertexColor(0, 0, 0, 0.30 + 0.35 * strength)
	shadow:SetThickness((4 + 3 * strength) / canvas)
	UI.Tint(light, color or Shy.Maps.LIGHT, 0.45 + 0.55 * strength)
	light:SetThickness((2 + 1.5 * strength) / canvas)
end

-- pool: the lines it is one of (default: `lines`).
local function Stroke(ax, ay, bx, by, canvas, strength, pool, color)
	local shadow, light = Pair(pool or lines, function(sub) return layer:CreateLine(nil, "ARTWORK", nil, sub) end)
	Draw(shadow, light, ax, ay, bx, by, canvas, strength, color)
end

-- Route lines
-- A leg is one stroke bowed to the right of its direction (so out-and-back legs never share a line),
-- wide and bright at its start, fine at its end. Both maps draw the trail from the player to the leading
-- place: a ribbon along the way to walk, in the theme's accent in a crisp dark case, with a comet running
-- along it. The world map draws the route's next few legs (LEGS.ahead), quiet, later ones finer and
-- fainter; the minimap only a lead from each place. Hovering a pin or a card row, or clicking a pin, lights
-- the whole route to that place on the world map: its legs broader and glowing, never as bright as the trail.
--
-- The pens, strokes, ribbon and gleam are ShyCore's (Shy.Maps), as every addon that draws on the maps
-- has them. (Missing until the game is restarted after ShyCore gained them: ns.SetupPins draws nothing.)
local Maps = Shy.Maps or {}
local Pen, Begin, Finish, Segment = Maps.Pen, Maps.Begin, Maps.Finish, Maps.Segment

-- The legs' look and their ways over the ground (Legs over the ground, below). On the addon's table, as
-- ns.VOYAGE: this file has no local to spare.
-- A leg is a fine line in the color of what it leads to, on a soft shadow, even from end to end and with
-- no glow round it; lit (its route hovered or clicked), broader, full strength and glowing, a little
-- finer where it arrives. The trail outshines both.
--   near, far: a standing leg's alpha at its start, the next leg's and the last's.
--   wide, later: a standing leg's thickness, and how much finer the last is.
--   lit: a lit leg's extra thickness; fine: its thickness where it arrives, less that; glow: its halo,
--   times a plain stroke's.
--   stub: screen pixels; a point of a leg's way this near either of its ends is left out (LEGS.Draw).
--   bend: screen pixels; a leg's way is drawn with as few points as keep it within this of itself, so
--   a map zoomed out has few lines to carry when it pans.
--   close: yards; places nearer than this are joined by a bow.
--   reach: screen pixels; a line is under the mouse this near its edge.
--   round: screen pixels; a way's turn is rounded off this far either side of it. arc: radians; the most
--   of a turn one piece of its curve takes.
--   loose: how many times too broad or too fine on screen the map's lines may be while a zoom moves, the
--   pins hanging from their places meanwhile (LayMap); settle: seconds a zoom is still before all is laid as it should be.
--   budget: milliseconds of a frame spent laying legs; the rest are laid in the frames after (LayLegs).
--   again: seconds before a leg not found within reach is asked again (Path).
--   ahead: the legs that stand on the world map, the route's first with a line on it. (A leg is hundreds
--   of pieces for the game to show at every opening and to draw at every frame: a long route's were most
--   of both.)
ns.LEGS = { reach = 6, near = 0.92, far = 0.62, wide = 3.6, fine = 2.4, later = 1.2, lit = 1.2, glow = 1.8, bend = 0.8, close = 30,
	round = 8, arc = 0.2, loose = 2, settle = 0.5, budget = 4, ahead = 3, stub = 2, again = 3,
	-- (afar: on a continent's map a zone's ground is lit only while the zone is at least this share of the
	-- window across: Near, Shade.)
	afar = 0.45,
	ways = { n = 0 }, x = {}, y = {}, depth = {}, keep = {}, stack = {}, line = { x = {}, y = {}, depth = {} },
	pens = {} }

-- A leg's color: that of what the place it leads to is for (ns.StopColor), so the route reads as the kinds
-- of thing done along it; the explorer's ice blue where it only goes somewhere.
function ns.LEGS.Color(stop)
	return stop and ns.StopColor(stop) or ns.ToneColor(nil)
end

-- A leg from a to b: a quadratic curve built from short straight pieces, tapering from `wide` to `fine`.
--   strength: alpha at the start. upto: share of the leg drawn (a lead is its start only).
--   fade: alpha at the end, relative to the start. color: the trail's light for none.
local function Flow(pen, ax, ay, bx, by, strength, wide, fine, upto, fade, color)
	local dx, dy = bx - ax, by - ay
	local turn = pen.down and 1 or -1
	local cx, cy = (ax + bx) / 2 - dy * LEG.bow * turn, (ay + by) / 2 + dx * LEG.bow * turn
	local pieces = math.max(4, math.min(16, math.ceil(math.sqrt(dx * dx + dy * dy) * upto / (9 * pen.unit))))
	local function At(i)
		local t = i / pieces * upto
		local u = 1 - t
		return u * u * ax + 2 * u * t * cx + t * t * bx, u * u * ay + 2 * u * t * cy + t * t * by
	end
	-- (Each piece starts where the last ended: Shy.Maps.Segment joins them.)
	local lx, ly = ax, ay
	for i = 1, pieces do
		local x, y = At(i)
		local along = (i - 0.5) / pieces
		Segment(pen, lx, ly, x, y, wide + (fine - wide) * along, strength * (1 + (fade - 1) * along), color)
		lx, ly = x, y
	end
end

-- The trail
-- From the player to the leading place, on both maps: one ribbon, wide and bright where the player
-- stands and fine where it ends, with a gleam running along it toward the place. It follows the way
-- over the ground where that is known (W.Way: round the mountain, by the ford), and is straight
-- where it isn't.

-- A way's points made smooth (path.north[i], path.west[i], path.n of them), kept for as long as the
-- way is the same one. The way has a point wherever it turns, and turns at every step of the ground's
-- grid: first the points it keeps within TURN.wiggle yards of without are left out (Douglas-Peucker; never
-- one where its level, its water or a drop begins or ends), then each turn left is rounded, by no more
-- than TURN.round yards of either stretch that meets there, so the ribbon stays on the way and curves as
-- someone walking it does. path.first[i]: the first of them that belongs to the way's point i (a point
-- left out: those of the next one kept). path.depth[i]: the level each is on (Segment's
-- depth): -1 under ground, 1 a level up, 0 on the ground. path.fall[i], path.water[i]: how much of the
-- stretch ending at each is a slowed fall off a cliff or walked on water (Shy.Maps.Ribbon's xs.fall,
-- xs.water), from the way's drops and, while water is walked on, its swum points.
local function Smoothed(path, way, toNorth, toWest)
	if path.way == way then return path end
	path.way = way
	path.first = path.first or {}
	path.depth = path.depth or {}
	path.fall, path.water = path.fall or {}, path.water or {}
	local levels, depth, fall, water = way.look, path.depth, path.fall, path.water
	local function Depth(point)
		local level = levels and levels[point]
		return level == 1 and -1 or level == 2 and 1 or 0
	end
	local function Wet(point)
		local swum = way[point * 3]
		return swum ~= nil and swum ~= false and swum ~= 0
	end
	-- The way's stretch ending at its point i: (fall, water).
	local function Air(i)
		if i < 2 or i > way.n then return 0, 0 end
		local wet = 0
		if way.water then wet = (Wet(i - 1) and Wet(i)) and 1 or (Wet(i - 1) or Wet(i)) and 0.5 or 0 end
		return (way.drop and way.drop[i]) and 1 or 0, wet
	end
	fall[1], water[1] = 0, 0
	local count, n = way.n, 1
	-- (Only the beginning of the way: it ends where that does.)
	if way.cut then toNorth, toWest = way[count * 3 - 2], way[count * 3 - 1] end
	-- (A way found up close runs where the feet go: it is straightened and rounded only a little.)
	local wiggle = way.close and TURN.closeWiggle or TURN.wiggle
	local turn = way.close and TURN.closeRound or TURN.round
	-- Point i of the way. (It ends at the place itself, not at the node of ground the place is in.)
	local function At(i)
		if i == count then return toNorth, toWest end
		return way[i * 3 - 2], way[i * 3 - 1]
	end
	-- Which points stay: both ends, either side of where the level or the water changes or a drop is,
	-- then whichever the way strays from most between two that stay, until none strays `wiggle` yards.
	local keep = path.keep or {}
	local stack = path.stack or {}
	path.keep, path.stack = keep, stack
	for i = 1, count do keep[i] = i == 1 or i == count or (way.drop ~= nil and way.drop[i] ~= nil) end
	for i = 2, count do
		if Depth(i) ~= Depth(i - 1) or Wet(i) ~= Wet(i - 1) or keep[i] and way.drop and way.drop[i] then
			keep[i - 1], keep[i] = true, true
		end
	end
	local top, last = 0, 1
	for i = 2, count do
		if keep[i] then
			stack[top + 1], stack[top + 2] = last, i
			top, last = top + 2, i
		end
	end
	-- (A point on the floors' own way, way.fine: a bend round a cliff, the beginning found up close. It is
	-- kept to as closely as a way found up close is.)
	local fine = way.fine
	local most, fineMost = wiggle * wiggle, TURN.closeWiggle * TURN.closeWiggle
	while top > 0 do
		local a, b = stack[top - 1], stack[top]
		top = top - 2
		local an, aw = At(a)
		local bn, bw = At(b)
		local dn, dw = bn - an, bw - aw
		local span = dn * dn + dw * dw
		local far, at = 0, nil
		for i = a + 1, b - 1 do
			local pn, pw = way[i * 3 - 2] - an, way[i * 3 - 1] - aw
			local off = span > 0 and (pn * dw - pw * dn) ^ 2 / span or pn * pn + pw * pw
			off = off - (fine and fine[i] and fineMost or most)
			if off > far then far, at = off, i end
		end
		if at then
			keep[at] = true
			stack[top + 1], stack[top + 2], stack[top + 3], stack[top + 4] = a, at, at, b
			top = top + 4
		end
	end
	path.north[1], path.west[1] = way[1], way[2]
	path.first[1] = 1
	depth[1] = Depth(1)
	local steps, prior = TURN.steps, 1
	for i = 2, count - 1 do
		path.first[i] = n + 1
		if keep[i] then
			local beyond = i + 1
			while not keep[beyond] do beyond = beyond + 1 end
			local fromNorth, fromWest = At(prior)
			local north, west = At(i)
			local toN, toW = At(beyond)
			prior = i
			local before = math.sqrt((fromNorth - north) ^ 2 + (fromWest - west) ^ 2)
			local after = math.sqrt((toN - north) ^ 2 + (toW - west) ^ 2)
			if before > 0 and after > 0 then
				local round = (fine and fine[i]) and TURN.closeRound or turn
				local a, b = math.min(0.5, round / before), math.min(0.5, round / after)
				local an, aw = north + (fromNorth - north) * a, west + (fromWest - west) * a
				local bn, bw = north + (toN - north) * b, west + (toW - west) * b
				-- (The turn's pieces go from the stretch into the point to the one out of it. A stretch
				-- between two points kept is all of one air: where that changes, both are kept.)
				local inFall, inWater = Air(i)
				local outFall, outWater = Air(i + 1)
				for step = 0, steps do
					local t = step / steps
					local u = 1 - t
					n = n + 1
					path.north[n], path.west[n] = u * u * an + 2 * u * t * north + t * t * bn, u * u * aw + 2 * u * t * west + t * t * bw
					depth[n] = Depth(i)
					local share = step == 0 and 0 or (step - 0.5) / steps
					fall[n], water[n] = inFall + (outFall - inFall) * share, inWater + (outWater - inWater) * share
				end
			end
		end
	end
	n = n + 1
	path.north[n], path.west[n] = toNorth, toWest
	depth[n] = Depth(count)
	fall[n], water[n] = Air(count)
	path.first[count] = n
	-- (What a longer way before it left in the same tables goes: Onward reads past the last point's first.)
	for i = n + 1, #path.north do path.north[i], path.west[i], depth[i], fall[i], water[i] = nil, nil, nil, nil, nil end
	for i = count + 1, #path.first do path.first[i] = nil end
	path.n = n
	return path
end

-- The first of a path's points still ahead of a player who is walking toward the way's point `at`
-- (W.Way). That point's turn begins a little before it: of the points up to the turn's middle, those
-- the player has already passed (along the stretch they are on) are left out. Nothing beyond is ever
-- left out: where a way doubles back, what comes after the turn lies "behind" by any other measure,
-- and the turn would be drawn as a line straight across it.
local function Onward(path, at, north, west)
	local way = path.way
	local index = path.first[at] or path.n
	local dn, dw = way[at * 3 - 2] - way[at * 3 - 5], way[at * 3 - 1] - way[at * 3 - 4]
	local middle = math.min(index + 2, (path.first[at + 1] or path.n) - 1, path.n)
	while index < middle and (path.north[index] - north) * dn + (path.west[index] - west) * dw < 0 do
		index = index + 1
	end
	return index
end

-- A trail's points on the screen, in its pen's units: filled anew for each trail laid. xs.depth[i]: the
-- level point i is on (Segment's depth; none: the ground).
local xs, ys = { depth = {}, fall = {}, water = {} }, {}

-- Cuts `head` off the start of the trail's first `count` points and `tail` off its end (Shy.Maps.Trim).
local function Trim(count, head, tail)
	return Maps.Trim(xs, ys, count, head, tail)
end

-- The ribbon through the trail's first `count` points (Shy.Maps.Ribbon), with its gleam (Shine).
local function Ribbon(pen, count, color)
	Maps.Ribbon(pen, xs, ys, count, color)
end
local Shine = Maps.Shine

-- Legs over the ground
-- On the world map a leg follows the way over the ground between its two places, as the trail does:
-- round the hill, over the bridge. A route's places stand still, so each leg's way is asked of the
-- ground once and kept (smoothed as the trail's is, and where it lies on the shown map); only the trail
-- moves with the player. Until the ground knows the way (or where it knows none) the leg is a bow.
-- ns.LEGS.ways: by leg, { path (Smoothed), map, x = {}, y = {} (fractions of it) }, or false: none known.

-- The legs as last laid, in route order, for the map's status (Ways.lua): { n, [i] = { stop, number,
-- state } }, state "working" (its way being worked out: a bow meanwhile), "ground" (along it) or "none"
-- (the ground knows none: a bow). LEGS.leg: the one being laid, which Path tells its state.
ns.LEGS.status = { n = 0 }

-- The kept way from place a to place b ({ continent, north, west }), nil while unknown. Sets
-- ways.waiting while one is worked out (SHY_TERRAIN lays the map again).
-- The legs standing on the map ahead (the first LEGS.ahead of the route) are asked as the way led along, as the
-- trail is (Shy.Way's `lead`): your route's next places are walked next, and a search everyone else's asking has
-- worn out is begun anew for them rather than answered "far". A leg not found within reach is no leg without a
-- way: it is kept as unknown for LEGS.again seconds and asked again then (Retry), the map laid again for it.
function ns.LEGS.Path(a, b)
	local LEGS, terrain = ns.LEGS, Shy.Way
	if not (a.north and b.north and a.continent and a.continent == b.continent) then return nil end
	if W.Between(a.north, a.west, b.north, b.west) < LEGS.close then return nil end
	local ways = LEGS.ways
	local floor = math.floor
	local key = ("%d:%d:%d>%d:%d"):format(a.continent, floor(a.north), floor(a.west), floor(b.north), floor(b.west))
	local kept = ways[key]
	local leg = LEGS.leg
	if type(kept) == "number" then
		if GetTime() < kept then
			if leg then leg.state = "working" end
			return nil
		end
		ways[key], kept = nil, nil
	end
	if kept == nil then
		local lead = LEGS.status.n < LEGS.ahead or nil
		local way, state = terrain.AskWay(a.continent, a.north, a.west, b.north, b.west, nil, nil, lead)
		if state == "working" then
			ways.waiting = true
			if leg then leg.state = "working" end
			return nil
		end
		if not way and state == "far" then
			ways[key] = GetTime() + LEGS.again
			if leg then leg.state = "working" end
			LEGS.Retry()
			return nil
		end
		if ways.n >= 80 then
			wipe(ways)
			ways.n = 0
		end
		kept = way and way.n >= 2 and { path = Smoothed({ north = {}, west = {} }, way, b.north, b.west), x = {}, y = {} } or false
		-- (A leg is drawn from its smoothed points and their levels alone: the ground's way and what only a
		-- trail walked along reads are let go.)
		if kept then kept.path.way, kept.path.first, kept.path.fall, kept.path.water = nil, nil, nil, nil end
		ways[key], ways.n = kept, ways.n + 1
	end
	if leg then leg.state = kept and "ground" or "none" end
	if not kept then return nil end
	if kept.map ~= shownMap then
		kept.map = shownMap
		local path = kept.path
		Maps.LineToMap(shownMap, a.continent, path.north, path.west, path.n, kept.x, kept.y)
	end
	return kept
end

-- A leg kept as unknown for now (Path): the map is laid again once LEGS.again seconds have passed, once however
-- many legs wait, while it is open.
function ns.LEGS.Retry()
	local LEGS = ns.LEGS
	if LEGS.retrying then return end
	LEGS.retrying = true
	C_Timer.After(LEGS.again, function()
		LEGS.retrying = false
		if layer and layer:IsVisible() and ns.ApplyPins then ns.ApplyPins(true) end
	end)
end

-- Which of the first `count` points (LEGS.x, LEGS.y) a line keeps to stay within `tolerance` of them all
-- (Douglas-Peucker): LEGS.keep[i] true for those. Its ends and every change of level are always kept.
function ns.LEGS.Simplify(count, tolerance)
	local LEGS = ns.LEGS
	local xs, ys, depths, keep, stack = LEGS.x, LEGS.y, LEGS.depth, LEGS.keep, LEGS.stack
	for i = 1, count do keep[i] = i == 1 or i == count or depths[i] ~= depths[i - 1] end
	local most = tolerance * tolerance
	local top = 2
	stack[1], stack[2] = 1, count
	while top > 0 do
		local first, last = stack[top - 1], stack[top]
		top = top - 2
		local ax, ay = xs[first], ys[first]
		local dx, dy = xs[last] - ax, ys[last] - ay
		local span = dx * dx + dy * dy
		local far, at = most, nil
		for i = first + 1, last - 1 do
			local px, py = xs[i] - ax, ys[i] - ay
			-- (Squared distance from the chord, or from its start where the chord is a point.)
			local off = span > 0 and (px * dy - py * dx) ^ 2 / span or px * px + py * py
			if off > far then far, at = off, i end
		end
		if at then
			keep[at] = true
			stack[top + 1], stack[top + 2], stack[top + 3], stack[top + 4] = first, at, at, last
			top = top + 4
		end
	end
end

-- A leg from place `a` to place `b`, drawn from (ax, ay) to (bx, by) in canvas units (their pins): along
-- the ground where its way is known, else bowed (Flow). glow: its halo, times a plain stroke's. The rest
-- as Flow's.
function ns.LEGS.Draw(pen, a, b, ax, ay, bx, by, strength, wide, fine, fade, color, glow)
	local LEGS = ns.LEGS
	local kept = LEGS.Path(a, b)
	if not kept then return Flow(pen, ax, ay, bx, by, strength, wide, fine, 1, fade, color) end
	local xs, ys, depths = LEGS.x, LEGS.y, LEGS.depth
	local width, height = layer:GetWidth(), layer:GetHeight()
	local path = kept.path
	local count = 1
	xs[1], ys[1], depths[1] = ax, ay, path.depth[1] or 0
	for i = 1, path.n do
		if kept.x[i] then
			count = count + 1
			xs[count], ys[count], depths[count] = kept.x[i] * width, kept.y[i] * height, path.depth[i] or 0
		end
	end
	count = count + 1
	xs[count], ys[count], depths[count] = bx, by, path.depth[path.n] or 0
	LEGS.Simplify(count, LEGS.bend * pen.unit)
	-- The kept points in turn (in LEGS.stack, Simplify's no longer), then the line drawn through them
	-- (LEGS.line): each turn rounded off on a curve `round` pixels either side of it (less where a stretch
	-- is short), in pieces of no more than `arc` of the turn. A point on a curve is on its turn's level.
	-- (Not one within LEGS.stub of either end: the way's own end beside the pin's place makes a piece too
	-- short to turn in, and the stroke beside it is drawn down to a point.)
	local order, kepts = LEGS.stack, 0
	local stub = (LEGS.stub * pen.unit) ^ 2
	for i = 1, count do
		if LEGS.keep[i] and (i == 1 or i == count
			or ((xs[i] - ax) ^ 2 + (ys[i] - ay) ^ 2 > stub and (xs[i] - bx) ^ 2 + (ys[i] - by) ^ 2 > stub)) then
			kepts = kepts + 1
			order[kepts] = i
		end
	end
	local line = LEGS.line
	local lx, ly, ld = line.x, line.y, line.depth
	local n = 1
	lx[1], ly[1], ld[1] = xs[order[1]], ys[order[1]], depths[order[1]]
	local round = LEGS.round * pen.unit
	for k = 2, kepts - 1 do
		local p, q = order[k], order[k + 1]
		local px, py = xs[p], ys[p]
		local ux, uy = xs[order[k - 1]] - px, ys[order[k - 1]] - py
		local vx, vy = xs[q] - px, ys[q] - py
		local lu, lv = math.sqrt(ux * ux + uy * uy), math.sqrt(vx * vx + vy * vy)
		local r = math.min(round, lu * 0.45, lv * 0.45)
		local cos = r > 0 and -(ux * vx + uy * vy) / (lu * lv) or 1
		if cos > 0.9999 then
			n = n + 1
			lx[n], ly[n], ld[n] = px, py, depths[p]
		else
			local sx, sy = px + ux / lu * r, py + uy / lu * r
			local ex, ey = px + vx / lv * r, py + vy / lv * r
			local steps = math.max(2, math.ceil(math.acos(math.max(-1, cos)) / LEGS.arc))
			for s = 0, steps do
				local t = s / steps
				local u = 1 - t
				n = n + 1
				lx[n], ly[n], ld[n] = u * u * sx + 2 * u * t * px + t * t * ex, u * u * sy + 2 * u * t * py + t * t * ey, depths[p]
			end
		end
	end
	n = n + 1
	lx[n], ly[n], ld[n] = xs[order[kepts]], ys[order[kepts]], depths[order[kepts]]
	local whole = 0
	for k = 2, n do whole = whole + math.sqrt((lx[k] - lx[k - 1]) ^ 2 + (ly[k] - ly[k - 1]) ^ 2) end
	if whole <= 0 then return end
	-- (Each piece starts where the last ended: Shy.Maps.Segment joins them.)
	local sofar = 0
	for k = 2, n do
		local length = math.sqrt((lx[k] - lx[k - 1]) ^ 2 + (ly[k] - ly[k - 1]) ^ 2)
		if length > 0 then
			local along = (sofar + length / 2) / whole
			Segment(pen, lx[k - 1], ly[k - 1], lx[k], ly[k], wide + (fine - wide) * along, strength * (1 + (fade - 1) * along),
				color, (ld[k - 1] + ld[k]) / 2, nil, glow)
			sofar = sofar + length
		end
	end
end

-- Where a leg from route pin `from` sets out walking: where its flight or crossing lands, else its place.
function ns.LEGS.Setout(from)
	return from.stop and from.stop.land or from
end

-- The world map's pens (SetupMap): the player's trail and a hovered route. Each leg has a pen of its own
-- (LEGS.pens, LayLegs).
local youPen, askPen

-- The trail on the world map. It moves with the player, so it is re-laid on a timer while the map is
-- open (SetupMap), not only on a route rebuild.
--   you.to: its end in canvas units, with .rim (how far short of the pin it stops), .from (how far
--   from the player it starts) and .stop (the stop the pin is, for the way to it).
--   you.path: the way to it, smoothed (Smoothed), with where each of its points is on the shown map
--   (fx, fy; false off it), kept for as long as the way and the map are the same.
--   you.to.off: the place isn't on the shown map (a city's, with the way leading out of its gate): the
--   ribbon runs along the way to where it leaves the map, and ends there.
local you = { path = { north = {}, west = {}, fx = {}, fy = {}, rx = {}, ry = {} } }
-- The trail cut short of you and of the pin, and drawn if any is left.
local function Cut(count, head, tail)
	count = Trim(count, head, tail)
	if count > 1 then Ribbon(youPen, count, you.color) end
end

-- Whether the player stands on the lit ground (Ground.Standing), on foot.
function you.Home()
	local ground = ns.Ground
	return not ns.Carried() and ground ~= nil and ground.Standing() or false
end

local function LayYou()
	-- Carried (a flight, a ride): no way to walk. Its own line is drawn (Shy.Way.Flight, Shy.Way.Riding).
	-- you.aloft: it was, when last laid (so the trail comes back on landing).
	you.aloft = ns.Carried()
	-- Already on the lit ground: the area is the direction, as on the minimap, and a line to a spot of it
	-- says nothing. you.home: it was, when last laid (so the trail comes back on leaving it).
	you.home = you.Home()
	you.laid = nil
	-- (Where the trail leads is said for a map that looks ahead along it: Shy.Maps.Lead.)
	local led = not you.aloft and not you.home and you.to and you.to.stop
	if led and led.north then Maps.Lead(you, led.continent, led.north, led.west) else Maps.Lead(you) end
	-- (A place someone suggested: the trail to it wears their class's color. Else the theme's.)
	you.color = you.to and you.to.stop and you.to.stop.color or nil
	if you.aloft or you.home then
		Begin(youPen, 1)
		Finish(youPen)
		you.road = nil
		if you.roadPen then
			Begin(you.roadPen, 1)
			Finish(you.roadPen)
		end
		return
	end
	local to = you.to
	local position = to and shownMap and C_Map.GetPlayerMapPosition(shownMap, "player")
	Begin(youPen, to and to.unit or 1)
	-- (Only the piece into the road is drawn flat, at the road's own start: below.)
	youPen.flat = nil
	-- (Its strokes are found under the mouse: ns.LEGS.Hit.)
	Maps.Tag(youPen, "you")
	local x, y
	if position then x, y = position:GetXY() end
	-- GetPlayerMapPosition gives 0, 0 for a map the player isn't on.
	if x and (x > 0 or y > 0) then
		local width, height = layer:GetWidth(), layer:GetHeight()
		local count, depth = 1, xs.depth
		xs[1], ys[1] = x * width, y * height
		local stop = to.stop
		local way, at
		-- (Into the cave a stop is in, not onto the hill over it: W.Prefer.)
		if stop and stop.north and W.Known() then way, at = W.Way(stop.continent, stop.north, stop.west, W.Prefer(stop)) end
		local path = you.path
		if way and (path.way ~= way or path.shown ~= shownMap) then
			Smoothed(path, way, stop.north, stop.west)
			path.shown = shownMap
			-- Where it is on this map: as fractions wherever that falls (rx, ry), and only on it (fx, fy).
			Maps.LineToMap(shownMap, stop.continent, path.north, path.west, path.n, path.rx, path.ry)
			for i = 1, path.n do
				local fx, fy = path.rx[i], path.ry[i]
				path.fx[i], path.fy[i] = (fx and fx > 0.02 and fx < 0.98 and fy > 0.02 and fy < 0.98) and fx or false, fy
			end
		end
		if to.off then
			-- To where the way leaves the map: each stretch in turn, the one that crosses the map's edge
			-- cut there. With no way known, straight toward the place.
			local lx, ly, edge = x, y, Maps.DEPTH.edge
			local first, final = 1, 0
			if way then
				first, final = Onward(path, at, W.Here()), path.n
			elseif at ~= "working" and stop and stop.north then
				local _, spot = C_Map.GetMapPosFromWorldPos(stop.continent, CreateVector2D(stop.north, stop.west), shownMap)
				if spot then
					-- (The place itself, kept before the path's first point.)
					path.rx[0], path.ry[0] = spot:GetXY()
					first, final = 0, 0
				end
			end
			for i = first, final do
				local fx, fy = path.rx[i], path.ry[i]
				if not fx then break end
				local share = 1
				if fx < edge then share = math.min(share, (edge - lx) / (fx - lx)) elseif fx > 1 - edge then share = math.min(share, (1 - edge - lx) / (fx - lx)) end
				if fy < edge then share = math.min(share, (edge - ly) / (fy - ly)) elseif fy > 1 - edge then share = math.min(share, (1 - edge - ly) / (fy - ly)) end
				share = math.max(0, share)
				count = count + 1
				xs[count], ys[count], depth[count] = (lx + (fx - lx) * share) * width, (ly + (fy - ly) * share) * height, way and path.depth[i] or 0
				xs.fall[count], xs.water[count] = way and path.fall[i] or 0, way and path.water[i] or 0
				if share < 1 then break end
				lx, ly = fx, fy
			end
			depth[1] = depth[2] or 0
			if count > 1 then Cut(count, to.from, 0) end
		else
			-- The way over the ground is drawn once, in map space. Walking changes only the piece from
			-- the player to where that line begins. It is drawn again when the next point of it is the
			-- one ahead, or the map moves.
			local onward = way and at ~= "working" and Onward(path, at, W.Here()) or nil
			local join = onward and path.rx[onward]
			local road = you.road
			if join and you.roadPen and road and road.way == way and road.shown == shownMap and road.onward == onward
				and road.w == width and road.h == height then
				xs[1], ys[1], depth[1] = x * width, y * height, 0
				xs[2], ys[2], depth[2] = road.jx, road.jy, path.depth[onward] or 0
				xs.fall[1], xs.fall[2], xs.water[1], xs.water[2] = 0, path.fall[onward] or 0, 0, path.water[onward] or 0
				youPen.flat = true
				Cut(2, to.from, 0)
			elseif join and you.roadPen then
				local n = 0
				for i = onward, path.n - 1 do
					if path.rx[i] then
						n = n + 1
						xs[n], ys[n], depth[n] = path.rx[i] * width, path.ry[i] * height, path.depth[i]
						xs.fall[n], xs.water[n] = path.fall[i], path.water[i]
					end
				end
				n = n + 1
				xs[n], ys[n], depth[n] = to.x, to.y, path.depth[path.n] or 0
				xs.fall[n], xs.water[n] = path.fall[path.n] or 0, path.water[path.n] or 0
				Begin(you.roadPen, to.unit)
				Maps.Tag(you.roadPen, "you")
				if n > 1 then
					n = Trim(n, 0, to.rim)
					if n > 1 then Ribbon(you.roadPen, n, you.color) end
				end
				Finish(you.roadPen)
				you.road = { way = way, shown = shownMap, onward = onward, w = width, h = height, jx = join * width, jy = path.ry[onward] * height }
				xs[1], ys[1], depth[1] = x * width, y * height, 0
				xs[2], ys[2], depth[2] = you.road.jx, you.road.jy, 0
				xs.fall[1], xs.fall[2], xs.water[1], xs.water[2] = 0, 0, 0, 0
				youPen.flat = true
				Cut(2, to.from, 0)
			else
				you.road = nil
				if you.roadPen then
					Begin(you.roadPen, 1)
					Finish(you.roadPen)
				end
				if way then
					-- All but its last point: the ribbon ends at the pin, which may have made room for another.
					-- Past the map's edge too, toward a place beyond it (the edge of the map clips it).
					for i = Onward(path, at, W.Here()), path.n - 1 do
						if path.rx[i] then
							count = count + 1
							xs[count], ys[count], depth[count] = path.rx[i] * width, path.ry[i] * height, path.depth[i]
							xs.fall[count], xs.water[count] = path.fall[i], path.water[i]
						end
					end
				end
				-- (While the first way there is being worked out, nothing: not a line through whatever is between.)
				if at ~= "working" then
					count = count + 1
					xs[count], ys[count], depth[count] = to.x, to.y, way and path.depth[path.n] or 0
					xs.fall[count], xs.water[count] = way and path.fall[path.n] or 0, way and path.water[path.n] or 0
					depth[1] = depth[2] or 0
					Cut(count, to.from, to.rim)
				end
			end
		end
		-- What it was laid for (you.Still).
		you.laid = { x = x, y = y, to = to, way = way, at = at }
	else
		-- Not on the map shown, or led nowhere: no trail on it, its road included (laid on another map, it would
		-- stand where that one's road ran).
		you.road = nil
		if you.roadPen then
			Begin(you.roadPen, 1)
			Finish(you.roadPen)
		end
	end
	Finish(youPen)
end

-- Whether the trail stands as it was laid: the player where they were, the same place led to and the same
-- way there. (Asked on the map's timer, which would otherwise lay it all again five times a second.)
function you.Still()
	-- (Onto the lit ground or off it: laid again. On it there is none, and nothing more to ask.)
	local home = you.Home()
	if home ~= you.home then return false end
	if home then return true end
	local laid, to = you.laid, you.to
	if not laid or laid.to ~= to or ns.Carried() then return false end
	local position = shownMap and C_Map.GetPlayerMapPosition(shownMap, "player")
	local x, y
	if position then x, y = position:GetXY() end
	if x ~= laid.x or y ~= laid.y then return false end
	local stop = to.stop
	local way, at
	if stop and stop.north and W.Known() then way, at = W.Way(stop.continent, stop.north, stop.west, W.Prefer(stop)) end
	return way == laid.way and at == laid.at
end

-- A place (a stop, or one of a guide step's places) on a map, as fractions. loose: as WorldOnMap.
local function Spot(map, at, loose)
	if at.map == map and at.x then return at.x / UNITS, at.y / UNITS end
	return WorldOnMap(map, at.continent, at.north, at.west, loose)
end

local function PlaceOnMap(at, loose)
	return Spot(shownMap, at, loose)
end

-- A line of points of map `from` (map units, x then y) as fractions of the shown map, past its edges too
-- (false where a point has no place on it): a walker's way or a step's trail on its zone's continent.
-- Worked out once for each line and map.
local Carried
do
	local carried = setmetatable({}, { __mode = "k" })
	function Carried(points, from)
		local kept = carried[points]
		if kept and kept.map == shownMap then return kept end
		kept = { map = shownMap }
		for i = 1, #points, 2 do
			local x, y
			if from == shownMap then
				x, y = points[i] / UNITS, points[i + 1] / UNITS
			else
				local continent, north, west = W.ToWorld(from, points[i], points[i + 1])
				x, y = WorldOnMap(shownMap, continent, north, west, true)
			end
			kept[i], kept[i + 1] = x or false, y or false
		end
		carried[points] = kept
		return kept
	end
end

-- A crossing on the world map (a flight, a boat, a zeppelin): one solid arc in its sign's color (a
-- flight's teal, Marks.lua's ERRAND.travel, where it has none) from where it leaves to where it lands,
-- rising over the map, even in width where the walks taper; the walk on from where it lands is a leg as
-- any other.
-- (On the addon's table: this file has no local to spare.)
--   bow: the arc's rise as a share of its length; wide, fine: its thickness at either end; alpha, fade:
--   its alpha at its start and, relative to that, at its end; least: no arc shorter than this, in pin sizes.
ns.VOYAGE = { bow = 0.24, wide = 4.6, fine = 3.4, alpha = 0.95, fade = 0.8, least = 0.6 }

-- The arc from a to b, in the pen's units. strength: alpha, as a leg's. color: the crossing's (the
-- flight's teal for none).
function ns.VOYAGE.Arc(pen, ax, ay, bx, by, strength, color)
	local look = ns.VOYAGE
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	if length < PIN.mapSize * look.least * pen.unit then return end
	-- Its normal that points up the screen, so every crossing rises (y grows downward on a pen that is `down`).
	local nx, ny = -dy / length, dx / length
	if (ny > 0) == (pen.down == true) then nx, ny = -nx, -ny end
	local cx, cy = (ax + bx) / 2 + nx * look.bow * length, (ay + by) / 2 + ny * look.bow * length
	local pieces = math.max(6, math.min(24, math.ceil(length / (8 * pen.unit))))
	color = color or ns.ERRAND and ns.ERRAND.travel
	local function At(i)
		local t = i / pieces
		local u = 1 - t
		return u * u * ax + 2 * u * t * cx + t * t * bx, u * u * ay + 2 * u * t * cy + t * t * by
	end
	-- (Each piece starts where the last ended: Shy.Maps.Segment joins them.)
	local lx, ly = ax, ay
	for i = 1, pieces do
		local x, y = At(i)
		local along = (i - 0.5) / pieces
		Segment(pen, lx, ly, x, y, look.wide + (look.fine - look.wide) * along, (strength or 1) * look.alpha * (1 + (look.fade - 1) * along), color)
		lx, ly = x, y
	end
end

-- For the leg between two of the route's pins (Shown): where a flight or a crossing from the first one
-- lands on the shown map, in canvas units ({ x, y }; nil off it), and whether the two are on different
-- continents (a guide's own boat step, and the step across the sea after it).
function ns.VOYAGE.Ends(from, to)
	local land = from.stop and from.stop.land
	local spot
	if land then
		local x, y = PlaceOnMap(land)
		if x then spot = { x * layer:GetWidth(), y * layer:GetHeight() } end
	end
	return spot, land ~= nil, to ~= nil and from.continent ~= nil and to.continent ~= nil and from.continent ~= to.continent
end

-- A leg drawn as the route has it: a flight or a crossing as its arc and the walk on from where it lands
-- (flow(ax, ay, bx, by): the walk, in canvas units), two places across the sea as one arc, else the walk.
-- a, b: the two pins' places in canvas units (b nil when off the map).
function ns.VOYAGE.Leg(pen, from, to, a, b, strength, flow)
	local land, lands, crosses = ns.VOYAGE.Ends(from, to)
	local color = from.stop and from.stop.mark and ns.SignColor(from.stop.mark)
	if land then
		ns.VOYAGE.Arc(pen, a[1], a[2], land[1], land[2], strength, color)
		a = land
	elseif lands or crosses then
		-- (Where it lands is off this map: the walk after it is too, wherever the next pin is.)
		if crosses and b then ns.VOYAGE.Arc(pen, a[1], a[2], b[1], b[2], strength, color) end
		return
	end
	if b then flow(a[1], a[2], b[1], b[2]) end
end

-- The live step's own path under the numbered route: its remaining waypoints (view.path) as a faint
-- line, and any paths the guide draws on this map (view.trails). (No mark at a waypoint: the trail
-- and the pins already show where the step goes.)
local function DrawWay(view, width, height, canvas)
	local last
	for _, at in ipairs(view.path or {}) do
		local x, y = PlaceOnMap(at)
		if x then
			local px, py = x * width, y * height
			if last then Stroke(last[1], last[2], px, py, canvas, LEG.way) end
			last = { px, py }
		else
			last = nil
		end
	end
	for _, trail in ipairs(view.trails or {}) do
		local points = Carried(trail.points, trail.map)
		local lx, ly
		for i = 1, #points, 2 do
			local px, py = points[i] and points[i] * width, points[i + 1] and points[i + 1] * height
			if lx and px then Stroke(lx, ly, px, py, canvas, LEG.way) end
			lx, ly = px, py
		end
	end
end

-- Walking paths
-- Someone who walks (a trader on the road between two towns) is seldom at their pin, so the way they
-- walk is drawn for every pin that stands for them: a dashed line on a zone's map, a fine one on the
-- minimap, bright for the lit pin's. It has the color of what they are there for, as the ground has:
-- someone to talk to, or something to kill.

-- Adds the walkers a stop is about to `into`: a list of NPCs, by NPC whether a lit pin has them, and
-- in into.kill those that are there to be killed. An escort to accept or to walk is a walker too: the
-- way it goes (Escort.lua, if loaded), in into.escort.
local function Walkers(stop, lit, into)
	local function Add(npc, kill)
		if npc and npc.walk then
			if into[npc] == nil then into[#into + 1] = npc end
			into[npc] = into[npc] or lit or false
			if kill then
				into.kill = into.kill or {}
				into.kill[npc] = true
			end
		end
	end
	local function Tokens(tokens)
		for _, token in ipairs(tokens or {}) do
			if token.kind == "n" then Add(D.Npc(token.id)) end
		end
	end
	local function Escorted(id)
		local way = id and ns.Escort and ns.Escort.Walker(id)
		if way then
			Add(way)
			into.escort = into.escort or {}
			into.escort[way] = true
		end
	end
	for _, each in ipairs(stop.members or { stop }) do
		Add(each.thing)
		-- A quest's objective: whoever walks among those it is got from (ns.WalkersOf).
		for _, action in ipairs(each.actions or {}) do
			if action.kind == "goal" then
				for index, goal in ipairs(L.Goals(action.id)) do
					if not goal.finished and (not each.objective or each.objective == index) then
						for _, token in ipairs(L.Asked(goal)) do
							for _, walker in ipairs(ns.WalkersOf(token)) do Add(walker.npc, walker.kill) end
						end
					end
				end
			end
		end
		for _, action in ipairs(each.actions or {}) do
			if action.kind ~= "turnin" then Escorted(action.id) end
		end
	end
	for _, view in ipairs(stop.views or { stop.view }) do
		for _, target in ipairs(view.targets or {}) do
			if target.npc then Add(D.Npc(target.npc), target.kind == "mob") end
		end
		for _, id in ipairs(view.sells or {}) do Add(D.Npc(id)) end
		for _, id in ipairs(view.buys or {}) do Add(D.Npc(id)) end
		for _, line in ipairs(view.lines or {}) do
			local quest = line.id and not line.done and (line.command == "accept" or line.command == "turnin") and D.Quest(line.id)
			if quest then Tokens(line.command == "accept" and quest.starts or quest.ends) end
			if line.id and not line.done and (line.command == "accept" or line.command == "complete") then Escorted(line.id) end
		end
	end
end

-- Those who walk among whom an objective's thing is got from: { { npc, kill }, ... }. A creature to kill; for an item,
-- each creature that drops it (the Defias Messenger and his message) or hands it over (kill false). Most have
-- none: kept by thing, as an item may have hundreds of droppers. (On the addon's table: this file has no local
-- to spare.)
do
local walkersOf = { c = {}, i = {}, none = {} }
function ns.WalkersOf(token)
	local kind = (token.kind == "s" or token.kind == "i") and "i" or token.kind == "c" and "c" or nil
	if not kind or not token.id then return walkersOf.none end
	local known = walkersOf[kind][token.id]
	if known then return known end
	known = {}
	if kind == "c" then
		local npc = D.Npc(token.id)
		if npc and npc.walk then known[1] = { npc = npc, kill = true } end
	else
		local item = D.Item(token.id)
		for _, source in ipairs(item and item.sources or {}) do
			local npc = source.kind == "n" and D.Npc(source.id)
			if npc and npc.walk then known[#known + 1] = { npc = npc, kill = source.chance ~= nil or not (npc.gives or npc.takes) } end
		end
	end
	walkersOf[kind][token.id] = known
	return known
end
end

-- A walker's color among `walkers` (Walkers): the ground's for its kind.
local function WalkColor(walkers, npc)
	local kinds = ns.Ground and ns.Ground.KIND
	if not kinds then return nil end
	if walkers.escort and walkers.escort[npc] and kinds.escort then return kinds.escort.color end
	return (walkers.kill and walkers.kill[npc] and kinds.kill or kinds.talk).color
end

-- The world map's: every stretch of the walkers' ways that is on the shown map.
local walkLines = { used = 0 }
local function LayWalks(walkers, width, height, canvas)
	walkLines.used = 0
	for _, npc in ipairs(walkers) do
		local color = WalkColor(walkers, npc)
		for _, stretch in ipairs(D.Path(npc)) do
			local points = Carried(stretch.points, stretch.map)
			for i = 3, #points, 2 do
				if points[i - 2] and points[i] then
					Stroke(points[i - 2] * width, points[i - 1] * height, points[i] * width, points[i + 1] * height,
						canvas, walkers[npc] and 1 or LEG.way, walkLines, color)
				end
			end
		end
	end
	HideRest(walkLines)
end

-- Spawn lights

-- Light a stop's ground on the shown map (Ground.Map; arguments as there). stop may be nil. kept: the
-- stop was clicked, so its light is kept. Returns how many of the stop's spawns are on this map, and the
-- names of what is there.
local Ground = ns.Ground

-- Whether the map shown (a continent's, `width` across in the layer's units) is seen from about as close
-- as the zone a stop's ground is in would be on its own map: the zone at least `afar` of the window
-- across. So panned a little past the zone's edge, or zoomed out a tad, the ground is still there; with
-- the zone a small part of the window it is not.
function ns.LEGS.Near(stop, width)
	local canvas = Maps.Canvas()
	local room, whole = canvas:GetCanvasContainer():GetWidth(), Shy.MapFrame(shownMap)
	local on = width * canvas:GetCanvasScale()
	if not (whole and room > 0 and on > 0) then return false end
	-- (The zone: the stop's own map, or the zone that map lies in, a cave or a keep's floor.)
	local map = stop.map or (stop.places and stop.places[1] and stop.places[1].map)
	for _ = 1, 3 do
		local info = map and C_Map.GetMapInfo(map)
		if not info or info.mapType <= Enum.UIMapType.Zone then break end
		map = info.parentMapID
	end
	local zone = map and map > 0 and Shy.MapFrame(map)
	if not zone then return false end
	-- (Yards of the world across the window, and of the zone.)
	return math.abs(zone[5]) >= math.abs(whole[5]) * room / on * ns.LEGS.afar
end

-- shade: the ground is one objective's of a quest of several, pointed at: drawn in its shade (Marks.lua).
local function Shade(stop, live, rest, width, height, kept, shade)
	if not Ground then return 0, {} end
	-- Ground is for a zone's own map, or as near: on a continent's map (or the world's) none is lit and no
	-- spawn pointed at unless the view is about as close as the zone's own map would be (ns.LEGS.Near). From
	-- further off it is too small to read and in the way of the zones; the marks and the route say where.
	if stop and shownMap and Wide(shownMap) and not ns.LEGS.Near(stop, width) then stop = nil end
	return Ground.Map(stop, live, rest, shownMap, width, height, Maps.Canvas():GetCanvasScale(), kept, shade)
end

-- The stop lit unasked.
--   lit: the lit pin's stop, if the map has one. A guide place is used as it is; otherwise the route's
--   first stop is (a merged mark may hold two quests, and only one leads). Ground.Working then
--   moves on from a stop with nothing to look for.
local function Headed(lit)
	local lead = R.stops[1]
	-- While something that can't wait leads (a ghost's way back to its body) no ground is lit: its mark
	-- is all the maps show of it, and the quests' ground waits.
	if lead and lead.urgent then return nil end
	local stop = lit
	if not (lit and lit.view) then
		if lead and lead.kind ~= "zone" and lead.kind ~= "fly" and lead.kind ~= "errand" then stop = lead end
	end
	if Ground then return Ground.Working(stop) end
	return stop
end

-- Lets go of what is kept lit (a clicked pin, a search result, a quest of the map's log), on both maps.
function ns.LetGo()
	picked, found = nil, nil
	-- (A pin's kept hover goes with its light.)
	if ns.CardHover and ns.CardHover.LetGoPin then ns.CardHover.LetGoPin() end
	ns.ApplyPins()
end

-- The note at the top of the map naming what is lit. A click clears it.
local function Note(text)
	if not text then
		if note then note:Hide() end
		return
	end
	if not note then
		-- (Over the window of whatever draws the map, and moved when that changes: Shy.Maps.Over.)
		note = CreateFrame("Frame", nil, Maps.Canvas():GetCanvasContainer())
		note:SetFrameStrata("HIGH")
		note:SetHeight(24)
		Maps.Over(note, "TOP", 0, -10)
		-- (The ways' status stands under it while it shows: Ways.lua.)
		ns.MapNote = note
		UI.Panel(note, { brackets = false })
		note.text = UI.Text(note, "", 12, false, C.text)
		note.text:SetPoint("LEFT", 10, 0)
		note.close = UI.Text(note, "x", 12, true, C.dim)
		note.close:SetPoint("RIGHT", -9, 0)
		note:EnableMouse(true)
		note:SetScript("OnMouseUp", function() ns.LetGo() end)
		note:SetScript("OnEnter", function(self) UI.Ink(self.close, C.hot) end)
		note:SetScript("OnLeave", function(self) UI.Ink(self.close, C.dim) end)
	end
	note.text:SetText(text)
	note:SetWidth(note.text:GetStringWidth() + 42)
	note:Show()
end

local function NoteFor(stop, drawn, names)
	local who = stop.who or (stop.actions[1] and stop.actions[1].title) or "this step"
	if stop.kind == "zone" then
		return drawn > 0 and ("%s: %d quest giver%s"):format(stop.who, drawn, drawn == 1 and "" or "s")
			or ("%s: open its map to see quest givers"):format(stop.who)
	end
	if drawn == 0 then
		-- A search result names its map.
		local elsewhere = stop.places and stop.places[1] and W.MapName(stop.places[1].map)
		if elsewhere then return ("%s is in %s. Open that map"):format(stop.who, UI.Wrap(C.hot, elsewhere)) end
		if #names > 0 then return ("%s: not on this map"):format(names[1]) end
		return ("Nothing to look for at %s"):format(who)
	end
	local listed = {}
	for i = 1, math.min(PIN.names, #names) do listed[i] = names[i] end
	local text = table.concat(listed, ", ")
	if #names > PIN.names then text = ("%s and %d more"):format(text, #names - PIN.names) end
	return "Where to look: " .. UI.Wrap(C.hot, text)
end

-- The route ahead
-- Worked out once for both maps, so a place has the same number on each.

-- The route in the card's order: first what comes before the guide's step (R.Before) as { stop = },
-- then the guide's steps, live one first, as { view = }. A live step the route aimed elsewhere
-- (NearerPlace, Here, R.Aim in Route.lua) is placed where the route has it, and a "here" step leads.
local function Ahead(most)
	local way = {}
	for _, stop in ipairs(R.Before()) do way[#way + 1] = { stop = stop } end
	local lead = R.stops[1]
	local ahead = G.Upcoming(most)
	local aimed = {}
	for _, stop in ipairs(R.stops) do
		if stop.kind == "guide" and stop.north and (stop.nearer or stop.here or stop.aimed) then aimed[stop.view.step.index] = stop end
	end
	if lead and lead.kind == "guide" and lead.here then
		for i = #ahead, 1, -1 do
			if ahead[i].step.index == lead.view.step.index then table.remove(ahead, i) end
		end
		table.insert(ahead, 1, lead.view)
	end
	for _, view in ipairs(ahead) do
		local stop = aimed[view.step.index]
		if stop then
			view = setmetatable({ map = stop.map, x = stop.x, y = stop.y, continent = stop.continent, north = stop.north, west = stop.west },
				{ __index = view })
		end
		if view.north then way[#way + 1] = { view = view } end
	end
	return way
end

-- Actions the route's places already show ("turnin12"): they get no other pin. The leading stop's
-- actions are left out when it has no number, so it keeps its own lit pin.
local function Covers(way)
	local covered, heading, lead = {}, {}, R.stops[1]
	if lead and lead.kind ~= "guide" and lead.kind ~= "zone" and not (way[1] and way[1].stop == lead) then
		for _, action in ipairs(lead.actions) do heading[action.kind .. action.id] = true end
	end
	for _, step in ipairs(way) do
		if step.stop then
			for _, action in ipairs(step.stop.actions) do covered[action.kind .. action.id] = true end
			if step.stop.errand then covered["errand" .. step.stop.errand] = true end
		else
			for _, action in ipairs(step.view.actions) do
				if not action.done and not heading[action.kind .. action.id] then covered[action.kind .. action.id] = true end
			end
		end
	end
	return covered
end

-- The route's places. Guide steps within PIN.place yards of each other are one place, whatever the map or
-- zoom, so a place's number (its first turn on the route) is the same everywhere; 1 is where the card
-- is heading. A place the guide returns to keeps its pin and number and lists all its steps. A stop
-- from before the guide's step is always a place of its own. `walk` is the order the places are visited.
local function Places(way)
	local places, walk = {}, {}
	for _, step in ipairs(way) do
		local at, home = step.view or step.stop, nil
		for i = #places, 1, -1 do
			local place = places[i]
			if step.view and not place.stop and place.continent == at.continent
				and W.Between(place.north, place.west, at.north, at.west) < PIN.place then
				home = i
				break
			end
		end
		if home then
			local views = places[home].views
			views[#views + 1] = step.view
		else
			places[#places + 1] = { number = #places + 1, views = { step.view }, stop = step.stop,
				continent = at.continent, north = at.north, west = at.west }
			home = #places
		end
		if walk[#walk] ~= home then walk[#walk + 1] = home end
	end
	return places, walk
end

-- The route as one map shows it: places that would overlap there (near(pin, place)) become one pin
-- with the first one's number and position, all their steps, and lit if any is. Stops from before the
-- guide's step never merge. Returns the pins and the walk from pin to pin.
local function Shown(places, walk, near)
	local pins, of = {}, {}
	for order, place in ipairs(places) do
		local home
		if not place.stop then
			for i = #pins, 1, -1 do
				local pin = pins[i]
				if not pin.stop and pin.continent == place.continent and near(pin, place) then
					home = i
					break
				end
			end
		end
		if home then
			local pin = pins[home]
			for _, view in ipairs(place.views) do pin.views[#pin.views + 1] = view end
			pin.lit = pin.lit or place.lit
		else
			local views = {}
			for i, view in ipairs(place.views) do views[i] = view end
			pins[#pins + 1] = { number = place.number, lit = place.lit, x = place.x, y = place.y, views = views, stop = place.stop,
				continent = place.continent, north = place.north, west = place.west }
			home = #pins
		end
		of[order] = home
	end
	local turns = {}
	for _, order in ipairs(walk) do
		if turns[#turns] ~= of[order] then turns[#turns + 1] = of[order] end
	end
	return pins, turns
end

-- The live guide step's index.
local function Live()
	local live = G.active[1] and not G.active[1].side and G.active[1].step.index
	-- Or the "here" step the card leads with.
	local first = R.stops[1]
	if first and first.kind == "guide" and first.here then live = first.view.step.index end
	return live
end

-- The stop behind a place's pin: the route's own stop, or one built from the guide steps done there. The
-- one built is kept for as long as the route (standing, by the place's first step; how far it is was asked
-- of the ground): the map lays every place's pin again at every zoom and every route built.
local standing = setmetatable({}, { __mode = "k" })
local function Stands(place)
	local stop = place.stop
	if stop then
		-- (A stop of your route keeps the key Plan gave it, its own: two of them never share what the maps keep.)
		if not (stop.kind == "way" and stop.key) then
			stop.key = "way" .. stop.kind .. (stop.actions[1] and stop.actions[1].id or stop.fly or stop.errand or "")
		end
		return stop
	end
	local view = place.views[1]
	local kept = standing[view]
	if kept and kept.route == R.stops and kept.count == #place.views then return kept.stop end
	stop = { kind = "guide", view = view, views = place.views, who = view.who, actions = {},
		map = view.map, x = view.x, y = view.y, continent = view.continent, north = view.north, west = view.west,
		key = "step" .. view.step.index }
	for _, each in ipairs(place.views) do
		for _, action in ipairs(each.actions) do stop.actions[#stop.actions + 1] = action end
	end
	if view.continent == W.continent and W.Known() then
		stop.yards = W.WalkTo(view.north, view.west)
	end
	standing[view] = { stop = stop, route = R.stops, count = #place.views }
	return stop
end

-- Whether place `order` is the lit one: the first place when it is a route stop; else the live step's
-- place, unless something leads before it (leading: see Leading).
local function Lit(places, order, stop, live, leading)
	local place = places[order]
	-- While something that can't wait leads (a ghost's body), no numbered place is lit: its own mark is.
	local lead = R.stops[1]
	if lead and lead.urgent then return false end
	if place.stop then return order == 1 end
	if leading then return leading(stop) end
	return place.views[1].step.index == live and not places[1].stop
end

-- Map layout

-- When the route's first stop is not a guide step and not already a numbered place of `way`, returns
-- a test for whether a pin's stop is that stop, so its pin is the lit one. nil otherwise.
local function Leading(way)
	local lead = R.stops[1]
	-- What can't wait is the one lit thing, under its own mark.
	if lead and lead.urgent then return function(stop) return stop == lead end end
	if not lead or lead.kind == "guide" or lead.kind == "zone" or lead.kind == "fly" or lead.kind == "errand" or lead.kind == "way" then return nil end
	for _, step in ipairs(way) do
		if step.stop == lead then return nil end
	end
	local asked = {}
	for _, action in ipairs(lead.actions) do asked[action.kind .. action.id] = true end
	return function(stop)
		-- The same NPC where the route's stop has one, else a shared action.
		if lead.thing and stop.thing and lead.thing ~= stop.thing then return false end
		for _, action in ipairs(stop.actions) do
			if asked[action.kind .. action.id] then return true end
		end
		return false
	end
end

-- Whether a stop, or one of a merged stop's members, has this key.
local function Holds(stop, key)
	if not key then return false end
	if stop.key == key then return true end
	for _, member in ipairs(stop.members or {}) do
		if member.key == key then return true end
	end
	return false
end

-- A merged stop: the first (most important) of `stops` with the rest as .members and all their actions.
local function Together(stops)
	local all = { members = stops, actions = {} }
	for _, stop in ipairs(stops) do
		for _, action in ipairs(stop.actions) do all.actions[#all.actions + 1] = action end
		if stop.chosen then all.chosen = true end
	end
	return setmetatable(all, { __index = stops[1] })
end

-- The route for a map to draw: places (numbered, .lit set), the walk, the steps, and Leading's test.
-- Worked out once per route for each `most`: the card, the minimap and the world map all ask.
local wayFor, ways
local function TheWay(most)
	if wayFor ~= R.stops then wayFor, ways = R.stops, {} end
	local kept = ways[most]
	if not kept then
		local way = Ahead(most)
		local places, walk = Places(way)
		local live, leading = Live(), Leading(way)
		for order, place in ipairs(places) do
			-- (A guide place's stop is built only where something leads before the guide: Lit asks it of that.)
			place.lit = Lit(places, order, (place.stop or leading) and Stands(place), live, leading) or false
		end
		kept = { places, walk, way, leading }
		ways[most] = kept
	end
	return kept[1], kept[2], kept[3], kept[4]
end

-- The same places for the card's rail, so a stop there wears the number its pin has on the map:
-- { number, lit, stop (Stands), own (the route's stop, when the place is one), views }. Worked out
-- once per route.
local railFor, rail
function ns.RoutePlaces()
	if railFor ~= R.stops then
		railFor, rail = R.stops, {}
		for order, place in ipairs((TheWay(PIN.guide))) do
			rail[order] = { number = place.number, lit = place.lit, stop = Stands(place), own = place.stop, views = place.views }
		end
	end
	return rail
end

-- Whether a route's place is only objectives: a quest's own stop for them, or a guide's step whose lines
-- still to do are objectives and items to collect (no quest to take or hand in, no hearth, no flight).
local OBJECTIVE = { complete = true, collect = true }
local NOT_OBJECTIVE = { accept = true, turnin = true, home = true, hs = true, fly = true, xp = true }
local function Objective(stop)
	if stop.kind == "goal" then return true end
	if stop.kind ~= "guide" or not stop.view then return false end
	local any = false
	for _, line in ipairs(stop.view.lines or {}) do
		if not line.done then
			if NOT_OBJECTIVE[line.command] then return false end
			if OBJECTIVE[line.command] then any = true end
		end
	end
	return any
end

-- The quests the game marks on a map, and its markers' positions ({ x, y }). Empty while the world
-- map's "Show Quest Objectives" filter (questPOI) is off: there is then nothing to avoid.
local function Theirs(map)
	local marked, spots = {}, {}
	if map and C_CVar.GetCVarBool("questPOI") then
		for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
			spots[#spots + 1] = { poi.x, poi.y }
			marked[poi.questID] = true
		end
	end
	return marked, spots
end

-- Everything on a zone map besides the route, for both maps: { stop, x, y, kind }, x and y as fractions.
--   covered: from Covers; what is found here is added. marked: from Theirs. mini: for the minimap.
--   within: one zone of the continent shown (its catch-up steps are the continent's own).
--   pass: the world map's gather (MapPass), for GoalsOn.
-- Quest givers, turn-ins and objectives the other quest addon marks on that map with its own setting on are left
-- to it (Yield.lua); the route, errands and catch-up steps stay.
local function Others(map, covered, marked, mini, within, pass)
	local list = {}
	local function Given(kind)
		return ns.Yield ~= nil and ns.Yield.To("map", kind, mini)
	end
	-- Optional catch-up steps off the route (R.offered): the guide's mark with no number and no line.
	for _, stop in ipairs(within and {} or R.offered) do
		for _, action in ipairs(stop.actions) do covered[action.kind .. action.id] = true end
		local x, y = Spot(map, stop)
		if x then
			stop.key = "catch" .. stop.view.step.index
			list[#list + 1] = { stop = stop, x = x, y = y, kind = "guide" }
		end
	end
	-- Errand NPCs (vendor, trainer) without a route number, under their own sign.
	for _, stop in ipairs(R.stops) do
		if stop.kind == "errand" and stop.mark and stop.map == map and stop.x and not covered["errand" .. stop.errand] then
			stop.key = "errand" .. stop.errand
			list[#list + 1] = { stop = stop, x = stop.x / UNITS, y = stop.y / UNITS, kind = ns.StopMark(stop) }
		end
	end
	for _, stop in ipairs(StopsOn(map, covered)) do
		-- Guide only (Route.lua, WithoutExtras): quests the guide skips get no pin, except failed
		-- quests, ones whose starting item is held, and class quests (G.Uses).
		local skipped = R.offGuide and stop.kind == "pickup"
		for _, action in ipairs(stop.actions) do
			local quest = D.Quest(action.id)
			if action.failed or action.held or (quest and quest.classes) then skipped = false end
		end
		-- (Skipped while a guide was followed: gone, its marks with it. Route.lua, R.Skip.)
		local kept = R.Unskipped(stop, "gone")
		if kept then stop = kept else skipped = true end
		if not skipped and not Given(stop.kind) then
			list[#list + 1] = { stop = stop, x = stop.x / UNITS, y = stop.y / UNITS, kind = stop.kind }
		end
	end
	if T.db.goals and not Given("goal") then
		for _, stop in ipairs(GoalsOn(map, marked, covered, pass)) do
			list[#list + 1] = { stop = stop, x = stop.x / UNITS, y = stop.y / UNITS, kind = "goal" }
		end
	end
	-- What the party's members are on (Party.lua).
	if T.db.goals and ns.Party and ns.Party.Marks and not Given("party") then
		for _, other in ipairs(ns.Party.Marks(map)) do list[#list + 1] = other end
	end
	return list
end

-- Merge marks of one kind that would overlap (near(a, b) of two Others entries). Zones and catch-up
-- steps never merge. Each group: { kind, at (its first entry), stop (merged), lit }.
local function Grouped(list, leading, near)
	local groups = {}
	for _, other in ipairs(list) do
		local lit = other.stop.chosen or (leading ~= nil and other.kind ~= "zone" and leading(other.stop)) or false
		local home
		if other.kind ~= "zone" and not other.stop.offered then
			for _, group in ipairs(groups) do
				-- (A party member's objective merges only with another of theirs.)
				if group.kind == other.kind and not group.at.stop.party == not other.stop.party and near(group.at, other) then
					home = group
					break
				end
			end
		end
		if home then
			home.stops[#home.stops + 1] = other.stop
			home.lit = home.lit or lit
		else
			groups[#groups + 1] = { kind = other.kind, at = other, stops = { other.stop }, lit = lit }
		end
	end
	for _, group in ipairs(groups) do
		group.stop = #group.stops == 1 and group.stops[1] or Together(group.stops)
	end
	return groups
end

-- The lit route: every leg up to one place, while the mouse is on its pin or its card row, or while its
-- pin is clicked.
local laid = {}                        -- the last layout: shown, walk, spots, scale, unit, and the map and its places' count (LayMap)
local ask = { alpha = 0, want = 0 }    -- .stop: the stop lit (.hovered, else .kept: the clicked); current and target alpha
local askLayer                         -- holds its lines, so they fade together

-- Whether route pin `pin` (from Shown) is where `stop` is: the same route stop, a guide step done
-- there, or an action one of its steps has.
local function Asked(pin, stop)
	if pin.stop then return pin.stop == stop or (stop.key ~= nil and pin.stop.key == stop.key) end
	local index = stop.view and stop.view.step and stop.view.step.index
	local wanted = {}
	for _, action in ipairs(not index and stop.actions or {}) do wanted[action.kind .. action.id] = true end
	for _, view in ipairs(pin.views) do
		if view.step.index == index then return true end
		for _, action in ipairs(view.actions) do
			if wanted[action.kind .. action.id] then return true end
		end
	end
	return false
end

local function LayAsk()
	Begin(askPen, laid.unit or 1)
	local goal, last
	if ask.stop and laid.shown then
		for index, pin in ipairs(laid.shown) do
			if Asked(pin, ask.stop) then
				goal = index
				break
			end
		end
		-- Up to its first visit.
		for turn, index in ipairs(laid.walk) do
			if index == goal then
				last = turn
				break
			end
		end
	end
	-- Drawn over the standing legs at full strength, each leg a little finer than the one before. A line
	-- under the mouse (ask.leg) is lit alone, at the broadest.
	local first = 2
	if ask.stop and ask.leg and laid.walk and laid.walk[ask.leg] then first, last = ask.leg, ask.leg end
	for turn = first, last or 1 do
		local from, to = laid.walk[turn - 1], laid.walk[turn]
		local a, b = laid.spots[from], laid.spots[to]
		if a then
			local later, scale = first == last and 0 or (turn - 2) / (last - 1), laid.scale
			local room = PIN.mapSize * LEG.flowRoom * scale
			local start, goal = laid.shown[from], laid.shown[to]
			ns.VOYAGE.Leg(askPen, start, goal, { a[1] * scale, a[2] * scale }, b and { b[1] * scale, b[2] * scale }, 1,
				function(ax, ay, bx, by)
					if (bx - ax) ^ 2 + (by - ay) ^ 2 >= room ^ 2 then
						local LEGS = ns.LEGS
						LEGS.Draw(askPen, LEGS.Setout(start), goal, ax, ay, bx, by, 1, LEGS.wide + LEGS.lit - LEGS.later * later, LEGS.fine + LEGS.lit,
							LEG.askEnd, LEGS.Color(goal.stands or Stands(goal)), LEGS.glow)
					end
				end)
		end
	end
	Finish(askPen)
end

-- Light the route to a hovered stop on the world map (nil: the mouse left it), else to the clicked one's
-- (ns.KeepWay); with neither, fade it out. leg: the hovered stop is the end of the line under the mouse,
-- the walk's turn `leg`: that line alone is lit.
function ns.RevealWay(hovered, leg)
	ask.hovered = hovered
	-- (With nothing left to light, the line fades out as it was.)
	if hovered or ask.kept then ask.leg = hovered and leg or nil end
	if not askPen then return end
	local stop = hovered or ask.kept
	if stop then
		ask.stop, ask.want = stop, 1
		if layer:IsVisible() then LayAsk() end
	else
		ask.want = 0
		-- Nothing showed yet, so there is nothing to fade.
		if ask.alpha == 0 and ask.stop then
			ask.stop = nil
			LayAsk()
		end
	end
end

-- The clicked pin's stop (nil: none), whose route stays lit.
function ns.KeepWay(stop)
	-- (Laid again for every route built: a stop kept from one to the next is the same table.)
	if ask.kept == stop and ask.keptFor == R.built then return end
	ask.kept, ask.keptFor = stop, R.built
	ns.RevealWay(ask.hovered, ask.leg)
end

-- Lines under the mouse
-- A line takes no mouse, so the world map looks for the one under it (GroundOnMap, ten times a second):
-- the trail ("you") or a leg (its turn in the walk). The line under the mouse is lit alone (RevealWay's
-- leg), and so is the pin it leads to; its hover says where it goes and why (Says). On the addon's table:
-- this file has no local to spare.
--   LEGS.hovered: the line lit. LEGS.hoveredPin: the pin it leads to, lit as if hovered.
--   LEGS.BY: how a leg goes, by the sign of the place it sets out from (a walk where it has none).
ns.LEGS.BY = { flight = "Fly from %s", fly = "Fly from %s", zeppelin = "Fly from %s", sail = "Sail from %s",
	tram = "Ride from %s" }

-- The line at (x, y) of the map's layer, the edge of it within `reach` (both in canvas units).
function ns.LEGS.Hit(x, y, reach)
	if not youPen then return nil end
	local hit = Maps.Hit(youPen, x, y, reach) or you.roadPen and Maps.Hit(you.roadPen, x, y, reach)
	local pens = ns.LEGS.pens
	for turn = 2, pens.most or 0 do
		if hit then return hit end
		local pen = pens[turn]
		if pen and pen.sigCount then hit = Maps.Hit(pen, x, y, reach) end
	end
	return hit
end

-- The stop a line leads to and the pin it ends at; for a leg also the two route places (laid.shown's) it
-- runs between. Nothing for a line no longer laid.
function ns.LEGS.End(key)
	if key == "you" then
		local to = you.to
		return to and not to.off and to.stop or nil, to and to.pin
	end
	local walk = laid.walk
	if not (key and walk and walk[key] and walk[key - 1]) then return nil end
	local from, to = laid.shown[walk[key - 1]], laid.shown[walk[key]]
	if not (from and to) then return nil end
	local spot = laid.spots[walk[key]]
	return to.stands or Stands(to), spot and spot.pin, from, to
end

-- Yards walked from place a to place b: along the way over the ground where that is known.
function ns.LEGS.Yards(a, b)
	if not (a.north and b.north and a.continent == b.continent) then return nil end
	local kept = ns.LEGS.Path(a, b)
	if not kept then return W.Between(a.north, a.west, b.north, b.west) end
	local path, yards = kept.path, 0
	for i = 2, path.n do yards = yards + W.Between(path.north[i - 1], path.west[i - 1], path.north[i], path.west[i]) end
	return yards
end

-- Light the line `key` (nil: none), and the pin it ends at. Asked again after the map is laid again, as
-- the pins are taken anew: the one it ends at may be another.
function ns.LEGS.Light(key)
	local LEGS = ns.LEGS
	local stop, pin = LEGS.End(key)
	if not stop then key, pin = nil, nil end
	local before = LEGS.hovered
	if key == before and pin == LEGS.hoveredPin then return end
	if LEGS.hoveredPin ~= pin then
		if LEGS.hoveredPin and LEGS.hoveredPin ~= over.pin then LEGS.hoveredPin:SetHovered(false) end
		if pin then pin:SetHovered(true) end
	end
	LEGS.hovered, LEGS.hoveredPin = key, pin
	if key == before then return end
	if type(key) == "number" then
		ns.RevealWay(stop, key)
	elseif type(before) == "number" and ask.leg == before then
		-- (Only the light the line put up: a pin's own, taken since, stays.)
		ns.RevealWay(nil)
	end
end

-- What the line `key` says: the hover of the pin it leads to, with how it gets there and how far it runs
-- (CardHover.Leg). Returns content, width; nil for none.
function ns.LEGS.Says(key)
	local LEGS = ns.LEGS
	local stop, _, from, to = LEGS.End(key)
	if not (stop and ns.CardHover and ns.CardHover.Leg) then return nil end
	if key == "you" then return ns.CardHover.Leg(stop, "From here", stop.yards and W.Far(stop), { Maps.TrailColor() }) end
	local start = from.stop
	local by = start and start.land and start.mark and LEGS.BY[start.mark]
	local how = (by or "Walk from %s"):format(from.number or "here")
	-- (Carried: how far is the crossing's, not the walk's.)
	local far = not by and W.Yards(LEGS.Yards(LEGS.Setout(from), to)) or nil
	return ns.CardHover.Leg(stop, how, far ~= "" and far or nil, LEGS.Color(stop))
end

-- LayMap is split into several functions because Lua 5.1 (the game's) allows a function at most
-- 60 upvalues. Keep it split: adding upvalues to LayMap can stop the file from loading.

-- The route's legs on the world map: one per distinct pair of pins in walk order, over the ground,
-- each quiet in the color of what it leads to, later ones finer and fainter. Only pins that almost
-- touch (LEG.flowRoom) get none. Only the first LEGS.ahead of them with a line on this map stand; the
-- rest of the route is lit by its pin (LayAsk).
--   shown, walk: from Shown. spots: each pin's position in pin units. scale, unit: LayMap's.
-- Each leg has a pen of its own (LEGS.pens, by its turn) and is laid again only when what it is drawn from
-- changes: the map, the zoom, its turn (how strong it is), where its two pins stand, a flight's landing and
-- sign, its color, and the way over the ground known for it. The route is built again every few steps the
-- player takes and seldom changes a leg; a leg is many pieces, each told where its corners are, so one laid
-- again for nothing was most of the map's work, and most of what it left to collect.
-- (LEGS.leg is the leg's entry in the map's status: asking for its way tells it the way's state.)
function ns.LEGS.Kept(pen, turn, start, goal, a, b, scale, unit)
	local LEGS = ns.LEGS
	local sig, was, n = pen.sigNext, pen.sig, 0
	local function Put(value)
		n = n + 1
		sig[n] = value
	end
	local stop = start.stop
	local land = stop and stop.land
	Put(shownMap)
	Put(scale)
	Put(unit)
	Put(turn)
	Put(a[1])
	Put(a[2])
	Put(b and b[1] or false)
	Put(b and b[2] or false)
	Put(b and b[4] or false)
	Put(stop and stop.mark or false)
	Put(land and land.north or false)
	Put(land and land.west or false)
	Put(start.continent or false)
	Put(goal.continent or false)
	Put(LEGS.Path(LEGS.Setout(start), goal) or false)
	if b then
		local color = LEGS.Color(goal.stands or Stands(goal))
		Put(color[1])
		Put(color[2])
		Put(color[3])
	end
	local same = n == pen.sigCount
	for i = 1, same and n or 0 do
		if sig[i] ~= was[i] then
			same = false
			break
		end
	end
	pen.sig, pen.sigNext, pen.sigCount = sig, was, n
	return same
end

-- A leg's pen with nothing on it. (sigCount: nil once cleared; false for a leg still to be laid, which may
-- show what it was.)
function ns.LEGS.Clear(pen, unit)
	if pen.sigCount == nil then return end
	Begin(pen, unit)
	Finish(pen)
	pen.sigCount = nil
end

-- Legs to lay are laid in their turn, the nearest first, until LEGS.budget milliseconds of the frame are
-- spent; the rest come in over the next frames (LEGS.more), each kept as it was meanwhile, or hidden if it
-- was laid on another map. Every leg is new on another map: laid at once, a turn of the map stuttered.
local function LayLegs(shown, walk, spots, scale, unit, began)
	local LEGS = ns.LEGS
	LEGS.ways.waiting = false
	local status, pens = LEGS.status, LEGS.pens
	status.n = 0
	local done = {}
	local coming = 0
	began = began or debugprofilestop()
	-- (Legs that stand so far, those looked at for it, and the last turn looked at.)
	local standing, looked, last = 0, 0, 1
	for turn = 2, #walk do
		if standing >= LEGS.ahead or looked >= LEGS.ahead * 2 then break end
		last = turn
		local from, to = walk[turn - 1], walk[turn]
		local a, b = spots[from], spots[to]
		local pen = pens[turn]
		if not pen then
			pen = Pen(layer, "TOPLEFT", layer, true)
			-- (A standing leg has no glow round it: that is a lit one's, LayAsk.)
			pen.quiet = true
			pen.sig, pen.sigNext, pen.leg = {}, {}, {}
			pens[turn] = pen
			pens.most = math.max(pens.most or 0, turn)
		end
		if a and not done[from * 1000 + to] then
			done[from * 1000 + to] = true
			looked = looked + 1
			local start, goal = shown[from], shown[to]
			-- (Told its state as its way is asked for: a leg with none to ask, a flight's, isn't listed.)
			local leg = pen.leg
			leg.stop, leg.number, leg.state = goal.stands or Stands(goal), goal.number, nil
			LEGS.leg = leg
			if LEGS.Kept(pen, turn, start, goal, a, b, scale, unit) then
				-- (As it was laid.)
			elseif debugprofilestop() - began > LEGS.budget then
				-- Its turn comes in a later frame: told it differs, so it is laid then.
				if pen.map ~= shownMap then LEGS.Clear(pen, unit) end
				pen.sigCount = false
				coming = coming + 1
			else
				pen.map = shownMap
				local later = math.min(1, (turn - 2) * LEG.flowFade)
				local strength, room = LEGS.near + (LEGS.far - LEGS.near) * later, PIN.mapSize * LEG.flowRoom * scale
				Begin(pen, unit)
				-- (Its strokes are its turn's, found under the mouse: ns.LEGS.Hit.)
				Maps.Tag(pen, turn)
				-- A flight or a crossing is its arc, then the walk on from where it lands (ns.VOYAGE).
				ns.VOYAGE.Leg(pen, start, goal, { a[1] * scale, a[2] * scale }, b and { b[1] * scale, b[2] * scale }, strength,
					function(ax, ay, bx, by)
						-- (No line between two pins too near each other for one.)
						if (bx - ax) ^ 2 + (by - ay) ^ 2 >= room ^ 2 then
							local thick = LEGS.wide - LEGS.later * later
							LEGS.Draw(pen, LEGS.Setout(start), goal, ax, ay, bx, by, strength, thick, thick, LEG.flowEnd,
								LEGS.Color(goal.stands or Stands(goal)))
						end
					end)
				Maps.Tag(pen, nil)
				Finish(pen)
			end
			LEGS.leg = nil
			-- (One with no line, its pins too near for one, is not one of the few: the next is looked at,
			-- twice as many at most.)
			if pen.sigCount == false or pen.lines.used > 0 then standing = standing + 1 end
			if leg.state then
				status.n = status.n + 1
				status[status.n] = leg
			end
		else
			-- (No leg on this turn now: a pair already drawn, or a pin off the map.)
			LEGS.Clear(pen, unit)
		end
	end
	for turn = last + 1, pens.most or 0 do
		if pens[turn] then LEGS.Clear(pens[turn], unit) end
	end
	-- (The rest from the next frame on, from this layout: LEGS.more is this frame's time, GetTime the frame's own.)
	LEGS.more = coming > 0 and GetTime() or nil
	if ns.Ways then ns.Ways.Update(status) end
	laid.shown, laid.walk, laid.spots, laid.scale, laid.unit = shown, walk, spots, scale, unit
	-- The pins have been laid again: a lit line's pin is lit anew (or its line is gone).
	LEGS.Light(LEGS.hovered)
	LayAsk()
end

-- Town service marks (ServicesOn), each kept clear of everything in `taken`.
-- A pin hung at cx, cy of the layer (its units, from its top left, y down), `weight` of a pin's size: from a point
-- on the layer, so the zoom carries it there, on the pin layer at laid.size (a pin's size on screen against the
-- map's window). Its hook is a region of the layer's own, made once a pin.
function laid.Hang(pin, cx, cy, weight)
	local at = pin.at
	if not at then
		at = layer:CreateTexture()
		at:SetSize(1, 1)
		pin.at = at
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", at, "CENTER")
	end
	at:ClearAllPoints()
	at:SetPoint("CENTER", layer, "TOPLEFT", cx, -cy)
	pin.cx, pin.cy, pin.weight = cx, cy, weight
end

local function LayServices(taken, width, height, scale)
	servicePins.used = 0
	local small = SERVICE.size * PIN.room
	for _, service in ipairs(services) do
		local picture = Picture(service.kind)
		local pin = ServicePin(layer)
		pin.service = service
		if picture then
			pin.picture:SetTexture(picture)
			pin.picture:SetVertexColor(1, 1, 1)
		else
			-- No tracking icon for it: a steel dot.
			local steel = ns.MARK.steel
			pin.picture:SetTexture(ns.MEDIA .. "Dot")
			pin.picture:SetVertexColor(steel[1], steel[2], steel[3])
		end
		local px, py = Clear(taken, service.x / UNITS * width / scale, service.y / UNITS * height / scale, small)
		pin:SetScale(laid.size)
		laid.Hang(pin, px * scale, py * scale, 1)
		pin:Show()
	end
	for i = servicePins.used + 1, #servicePins do
		servicePins[i]:Hide()
		servicePins[i].service = nil
	end
end

-- The hovered pin's stop on one of the maps, if its light is wanted and the pin is still shown.
local function Asking(mini)
	local pin = over.pin
	if pin and not over.hushed and (over.mini or false) == mini and pin:IsShown() then return pin.stop end
	-- A quest under the mouse in the map's quest log lights the world map as a pin does (ns.LightQuest).
	if not mini then return over.log end
end

-- The ground on the world map, for the layout LayMap left: the clicked pin's quests (with the note),
-- or a search result; over that the hovered pin's (no note); with neither, the leading stop's.
-- Nothing is drawn for the other quests (look.rest is kept for Ground.Map, which no longer reads it).
local function LightMap()
	if not layer or not layer:IsVisible() or not look.width then return end
	local rest, width, height = look.rest, look.width, look.height
	local kept = look.map or found
	if kept then
		Note(NoteFor(kept, Shade(kept, false, rest, width, height, true)))
	else
		Note(nil)
	end
	local asked = Asking(false)
	if asked and asked ~= kept then
		-- An objective of a quest of several, pointed at (its mark, its row on the card or in the key): its
		-- own ground alone, in its shade.
		-- (Only what lights that objective alone has a key: Ground.Of.)
		local action = asked.objective and asked.key and asked.actions and asked.actions[1]
		local one = action and ns.Objective and ns.Objective(action.id, asked.objective)
		Shade(asked, false, rest, width, height, nil, one and one.shade)
	elseif not kept then
		Shade(look.headed, true, rest, width, height)
	end
end

-- Each piece of the world map's work on the clock (the task manager): the time since `from`, under
-- `name`; the time now, for the next piece.
-- With the Lua memory it left (ns.lapHeap: where the last piece ended; ns.LapStart begins a run of them).
local function Lap(name, from)
	local now, heap = debugprofilestop(), collectgarbage("count")
	Shy.Clock(name):Lap(now - from, heap - (ns.lapHeap or heap))
	ns.lapHeap = heap
	return now
end
function ns.LapStart()
	ns.lapHeap = collectgarbage("count")
	return debugprofilestop()
end

-- Whether a stop stands where a stop of the route does whose ground the player is on (stop.among,
-- Route.lua). That spot is only the nearest of the ground's, so the minimap shows no pin and no way
-- there: it shows the ground, and its spawns as dots (Ground.ChooseMini).
local function Inside(stop)
	if not (stop and stop.north) then return false end
	for _, each in ipairs(R.stops) do
		if each.among and not each.urgent and (each.kind == "goal" or each.kind == "guide" or each.farm)
			and each.north == stop.north and each.west == stop.west then
			return true
		end
	end
	return false
end

-- zooming: told by a step of a zoom. All the map lays (which pins merge, the legs, the trail, the lit
-- ground: thousands of pieces, each told where its corners are) laid anew at every step, a zoom stuttered
-- and left megabytes to collect. A step lays nothing while the lines' width on screen is within LEGS.loose
-- times what it should be: the pins hang from their places (laid.Hang), so the zoom carries them, at their
-- size on screen. All of it is laid as it should be once the zoom has been still LEGS.settle seconds
-- (LEGS.relay), the pins' growth with the zoom too.
local function LayMap(zooming)
	if not layer or not layer:IsVisible() or not shownMap then return end
	local lap = ns.LapStart()
	local width, height = layer:GetWidth(), layer:GetHeight()
	-- (The canvas of whatever draws the map: the game's, or ShyMaps' view.)
	local canvas = Maps.Canvas():GetCanvasScale()
	-- The map is shown before it has a size (and Lua 5.1 errors on a division by zero); LayMap runs
	-- again when the size is set.
	if width <= 0 or height <= 0 or canvas <= 0 then return end
	-- Undo the canvas scale so pins keep their on-screen size, plus PIN.grow as the map zooms in.
	-- Positions below are in pin units.
	local grow = Grown(Maps.Canvas():GetCanvasZoomPercent(), PIN.grow)
	local scale = T.db.pinSize * grow / canvas
	local unit = grow / canvas   -- one line pixel in canvas units; lines grow with the pins
	local LEGS = ns.LEGS
	if zooming and laid.map == shownMap and laid.width == width and laid.height == height and laid.unit
		and unit / laid.unit < LEGS.loose and laid.unit / unit < LEGS.loose then
		LEGS.relay = GetTime() + LEGS.settle
		return
	end
	laid.width, laid.height = width, height
	-- (The pins' layer isn't zoomed: their scale there is the pins' own, with the zoom's growth as it now stands.)
	laid.size = scale * layer:GetEffectiveScale() / laid.pins:GetEffectiveScale()
	local start = lap
	local taken, room = {}, PIN.mapSize * PIN.room
	for i, spot in ipairs(theirs) do
		taken[i] = { spot[1] * width / scale, spot[2] * height / scale }
	end
	local among = {}       -- positions of the route's own pins
	local pickedStop
	local heading, led     -- position of the leading pin, and the stop it is
	local wide = Wide(shownMap)
	local walkers = {}     -- who the pins stand for that walks (Walkers)

	-- Place the next pin for `stop` at (x, y) of the map. A lit pin is full size, others by WEIGHT.
	-- Returns { x, y, weight, rim }; rim is how far from its middle a line to it stops.
	-- On a zone map a pin is always exactly on its place: making room there moved pins with the zoom.
	-- Only continent maps use Clear. way: a route place, which only avoids other route places.
	local function Place(stop, x, y, kind, lit, count, way)
		local weight = lit and 1 or WEIGHT[kind] or 1
		local pin = mapPins:Next()
		-- The game's own picture of the body stands over every pin: the body's mark goes over that.
		local level = stop.urgent and Maps.PinLevel("PIN_FRAME_LEVEL_CORPSE") + 1 or pin.level
		if pin:GetFrameLevel() ~= level then pin:SetFrameLevel(level) end
		-- Scale before Set: a mark picks its sheet by on-screen size.
		pin:SetScale(laid.size * weight)
		-- A party member's objective stands back from our own.
		pin:SetAlpha(stop.party and 0.75 or 1)
		-- A quest stop at a vendor wears the buy sign (stop.mark).
		pin:Set(kind == "goal" and stop.mark == "buy" and "buy" or kind, lit, count, ns.StopTone(stop))
		pin:SetMood(ns.StopMood(stop))
		pin:SetLetter(ns.StopLetter(stop, kind))
		local px, py = x * width / scale, y * height / scale
		if wide then
			px, py = Clear(way and among or taken, px, py, room * (1 + weight) / 2)
			if way then taken[#taken + 1] = among[#among] end
		else
			taken[#taken + 1] = { px, py }
		end
		pin.stop, pin.picked = stop, Holds(stop, picked)
		pin:SetPicked(pin.picked)
		if pin.picked then pickedStop = stop end
		Walkers(stop, lit, walkers)
		laid.Hang(pin, px * scale, py * scale, weight)
		pin:Show()
		local pointed = kind == "step" or kind == "zone"
		return { px, py, weight, pointed and 0 or PIN.mapSize * LEG.rim * weight, pin = pin }
	end

	-- The route's places as this map shows them (Shown). A zone map never merges them; a continent
	-- map merges those within a pin's reach in yards, which also works for places off the map.
	local reach
	local c1, n1, w1 = W.ToWorld(shownMap, 0, 5000)
	local c2, n2, w2 = W.ToWorld(shownMap, UNITS, 5000)
	if c1 and c2 then reach = PIN.mapSize * PIN.merge * scale / width * W.Between(n1, w1, n2, w2) end
	local shown, walk = Shown(wayPlaces, wayWalk, function(pin, place)
		if not wide then return false end
		if reach then return W.Between(pin.north, pin.west, place.north, place.west) < reach end
		-- A map with no world size (the world map): by map position.
		return pin.x ~= nil and place.x ~= nil
			and ((place.x - pin.x) * width / scale) ^ 2 + ((place.y - pin.y) * height / scale) ^ 2 < (PIN.mapSize * PIN.merge) ^ 2
	end)
	local live = Live()
	local leading = Leading(steps)
	lap = Lap("world map laid: the route's places merged", lap)
	lines.used = 0
	-- The live step's own path, on every map.
	for _, step in ipairs(steps) do
		-- canvas / grow: its lines grow with the pins.
		if step.view and step.view.step.index == live then DrawWay(step.view, width, height, canvas / grow) end
	end
	lap = Lap("world map laid: the live step's path", lap)
	local spots = {}             -- each route pin's position (nil for a place off this map)
	local headed                 -- the leading stop, whose spawns are lit
	local away                   -- the lit place, where it is off this map: the trail still leads toward it
	for index, pin in ipairs(shown) do
		if pin.x then
			local stop = Stands(pin)
			-- (Kept for the legs' colors.)
			pin.stands = stop
			if not T.db.goals and not pin.lit and Objective(stop) then
				-- Objectives switched off (the map's filter): the route's places that are only objectives go,
				-- all but the one led to, which the trail and the arrow still point at.
				spots[index] = nil
			elseif Inside(stop) then
				-- On the ground of this place: its outline and its spawns are the picture, as on the minimap, and
				-- no pin stands on it nor a line runs to or from it.
				if pin.lit and not headed then headed = stop end
			else
				spots[index] = Place(stop, pin.x, pin.y, "step", pin.lit, pin.number, true)
				if pin.lit and not heading then heading, headed, led = spots[index], stop, stop end
			end
		elseif pin.lit and not away then
			away = Stands(pin)
		end
	end
	lap = Lap("world map laid: the route's pins", lap)
	LEGS.relay = nil
	HideRest(lines)
	-- (The frame's share counts from where the map's laying began: the pins may have had it all.)
	LayLegs(shown, walk, spots, scale, unit, start)
	laid.map = shownMap
	lap = Lap("world map laid: the legs", lap)

	-- Everything else, overlapping marks of one kind merged (Grouped). On a zone map objectives merge
	-- only within PIN.same yards, so marks don't come and go with the zoom.
	local groups = Grouped(others, leading, function(a, b)
		if a.kind == "goal" and not wide and a.stop.north and b.stop.north then
			return a.stop.continent == b.stop.continent and W.Between(a.stop.north, a.stop.west, b.stop.north, b.stop.west) < PIN.same
		end
		return ((a.x - b.x) * width / scale) ^ 2 + ((a.y - b.y) * height / scale) ^ 2 < (PIN.mapSize * PIN.together) ^ 2
	end)
	for _, group in ipairs(groups) do
		if Inside(group.stop) then
			if group.lit and not headed then headed = group.stop end
		else
			local spot = Place(group.stop, group.at.x, group.at.y, group.kind, group.lit, group.at.count)
			-- A chosen stop leads whatever else is lit.
			if group.lit and (not heading or group.stop.chosen) then heading, headed, led = spot, group.stop, group.stop end
		end
	end
	-- The leading stop always has a pin: if nothing above covers it, it gets its own lit mark, or
	-- the trail runs to the game's marker for that quest (where the stop is on it: one that stands on
	-- the nearest ground of its own, lead.stands, is somewhere else).
	if not heading then
		local lead = R.stops[1]
		local x, y
		if lead and lead.kind ~= "zone" and lead.north and not Inside(lead) then x, y = PlaceOnMap(lead) end
		led = x and lead or nil
		if x and lead.kind == "goal" and theirMarks[lead.actions[1].id] and not lead.stands then
			heading = { x * width / scale, y * height / scale, 1, PIN.mapSize * LEG.rim }
		elseif x then
			lead.key = lead.key or ("lead" .. lead.kind .. (lead.actions[1] and lead.actions[1].id or ""))
			heading = Place(lead, x, y, ns.StopMark(lead), true)
		end
	end
	-- With no lit pin here the leading stop's spawns may still be on this map.
	headed = Headed(headed)
	mapPins:Done()
	lap = Lap("world map laid: the other pins", lap)
	-- canvas / grow: as the step's own path.
	LayWalks(walkers, width, height, canvas / grow)
	lap = Lap("world map laid: who walks", lap)

	you.to = heading and { x = heading[1] * scale, y = heading[2] * scale, rim = heading[4] * scale,
		from = PIN.mapSize * LEG.youRoom * scale, unit = unit, stop = led, pin = heading.pin } or nil
	-- Nothing on this map leads: the place that does is somewhere else (the player in a city, the next
	-- step outside its gate). The trail runs to where the way there leaves the map.
	if not you.to then
		local lead = R.stops[1]
		if not (away and away.north) and lead and lead.kind ~= "zone" and lead.kind ~= "fly" and lead.kind ~= "errand" and lead.north
			and not Inside(lead) then
			away = lead
		end
		if away and away.north and away.continent == W.continent then
			you.to = { off = true, from = PIN.mapSize * LEG.youRoom * scale, unit = unit, stop = away }
		end
	end
	LayYou()
	lap = Lap("world map laid: the trail", lap)

	-- A clicked pin on neither map any more is dropped; one the minimap still has stays.
	look.map = pickedStop
	if not pickedStop and not look.mini then picked = nil end
	ns.KeepWay(pickedStop)
	look.headed, look.rest, look.width, look.height = headed, T.db.goals, width, height
	-- The frame's share spent on the pins: the lit ground is laid in the next frame (look.late; the map's
	-- frame lays it), out of sight meanwhile where it lies on another map.
	if debugprofilestop() - start > LEGS.budget then
		if look.litOn ~= shownMap and Ground and Ground.Away then Ground.Away() end
		look.late = true
	else
		look.late, look.litOn = nil, shownMap
		LightMap()
	end
	lap = Lap("world map laid: the lit ground", lap)

	-- Last, so service marks avoid the pins.
	LayServices(taken, width, height, scale)
	Lap("world map laid: the services", lap)
end

-- What the maps' gathers chose, good until the route is built again (ns.ApplyPins): by the map shown,
-- { map, bests = R.Best's choice by its key (one for every map), spots = { x, y, yards } or false by map
-- and objective }. A map opened again, or turned to and back, chooses nothing twice; a continent chooses
-- nothing its zone's map has.
local passes, bests = {}, {}
local function MapPass(map)
	local pass = passes[map]
	if not pass then
		pass = { map = map, bests = bests, spots = {} }
		passes[map] = pass
	end
	return pass
end

-- A continent's zones' own marks, where they lie on it: every giver, turn-in and objective of some twenty
-- zones, which gathered at once held the frame the map turned to the continent. They are gathered a few
-- zones a frame (LEGS.budget milliseconds; the map's frame goes on with it, look.zoning) and stand on the
-- map once all are in. True when they are (pass.zones).
-- One mark per giver, source or objective: one whose places run over a zone border is in both zones'
-- marks. The nearer is kept, with the other's actions added.
function look.Zones(pass)
	local z = pass.zoning
	if not z then return pass.zones ~= nil end
	local function Join(kept, other)
		local has = {}
		for _, action in ipairs(kept.actions) do has[action.kind .. action.id] = true end
		for _, action in ipairs(other.actions) do
			if not has[action.kind .. action.id] then kept.actions[#kept.actions + 1] = action end
		end
	end
	local from, seen, zones = debugprofilestop(), z.seen, z.list
	while z.children[z.at] do
		local zone = z.children[z.at]
		z.at = z.at + 1
		for _, other in ipairs(Others(zone.mapID, z.covered, z.marked, nil, true, pass)) do
			local x, y = Spot(z.map, other.stop)
			local key = other.stop.key
			local twin = key and other.stop.actions and seen[key]
			if x and twin then
				local stop = other.stop
				if (stop.yards or math.huge) < (twin.stop.yards or math.huge) then
					Join(stop, twin.stop)
					twin.stop, twin.x, twin.y = stop, x, y
				else
					Join(twin.stop, stop)
				end
			elseif x then
				local moved = {}
				for k, v in pairs(other) do moved[k] = v end
				moved.x, moved.y = x, y
				zones[#zones + 1] = moved
				if key and other.stop.actions then seen[key] = moved end
			end
		end
		if z.children[z.at] and debugprofilestop() - from >= ns.LEGS.budget then return false end
	end
	pass.zones, pass.zoning = zones, nil
	return true
end

-- Gather what belongs on the shown map.
local function DrawMap()
	if not layer or not layer:IsVisible() then return end
	local from = ns.LapStart()
	look.zoning = nil
	local map = Maps.ShownMap()
	shownMap = map
	wipe(steps)
	wipe(others)
	wipe(theirs)
	wipe(services)
	if map and not Wide(map) then
		for _, service in ipairs(ServicesOn(map)) do
			service.map = map
			services[#services + 1] = service
		end
	end
	wayPlaces, wayWalk, theirMarks = {}, {}, {}
	local lap = Lap("world map gathered: the services", from)
	if T.db.mapPins and map then
		local marked, spots = Theirs(map)
		for i, spot in ipairs(spots) do theirs[i] = spot end
		theirMarks = marked
		lap = Lap("world map gathered: the game's marks", lap)
		-- Every place ahead is kept, on this map or not: numbers count the whole route.
		local places, walk, way = TheWay(PIN.guideFar)
		lap = Lap("world map gathered: the way ahead", lap)
		local covered, guided = Covers(way), false
		for _, step in ipairs(way) do
			if step.view then guided = true end
			steps[#steps + 1] = step
		end
		-- Past this map's edges too: zoomed in onto a zone, the route still comes in and goes on out.
		for _, place in ipairs(places) do
			if place.stop then
				place.x, place.y = PlaceOnMap(place.stop, true)
			else
				place.x, place.y = WorldOnMap(map, place.continent, place.north, place.west, true)
			end
		end
		wayPlaces, wayWalk = places, walk
		lap = Lap("world map gathered: the way's places on the map", lap)
		local pass = MapPass(map)
		for _, other in ipairs(Others(map, covered, marked, nil, nil, pass)) do others[#others + 1] = other end
		lap = Lap("world map gathered: givers and objectives", lap)
		-- On a continent: each of its zones' own marks, where they lie on it. The same marks at every zoom,
		-- only smaller (where they would overlap, LayMap merges them).
		-- (Gathered once for as long as the route, a few zones a frame from the next frame on: look.Zones.)
		local info = C_Map.GetMapInfo(map)
		if info and info.mapType == Enum.UIMapType.Continent then
			if not pass.zones and not pass.zoning then
				pass.zoning = { map = map, at = 1, seen = {}, list = {}, covered = covered, marked = marked,
					children = C_Map.GetMapChildrenInfo(map, Enum.UIMapType.Zone) or {} }
			end
			-- (look.zonesAt: where they stand among the others, for when they come in.)
			look.zoning, look.zonesAt = not pass.zones and pass or nil, #others + 1
			for _, moved in ipairs(pass.zones or {}) do others[#others + 1] = moved end
			lap = Lap("world map gathered: the continent's zones", lap)
		end
		-- No zone suggestions while a guide leads: its numbers would compete with them.
		if T.db.zones ~= "never" and not guided then
			local best = Z.Best(PIN.zones)
			-- The player's own zone too, when seen from another map.
			local here = W.map and Z.Get(W.map)
			if here then table.insert(best, 1, here) end
			for _, zone in ipairs(best) do
				local x, y = nil, nil
				if zone.map ~= map then x, y = OnMap(map, zone) end
				if x then
					local stop = R.ZoneStop(zone)
					stop.chosen = R.pinnedZone == zone.map
					stop.key = "zone" .. zone.map
					others[#others + 1] = { stop = stop, x = x, y = y, kind = "zone", count = #zone.quests }
				end
			end
			Lap("world map gathered: zones to go to", lap)
		end
	end
	LayMap()
	Shy.Clock("world map, gathered and laid"):Lap(debugprofilestop() - from)
end

-- Show a search result on the world map: its places lit and its name in the note, until the note is
-- clicked or a pin is picked. Opens the map at the nearest place (not in combat).
--   places: { { map, x, y }, ... }. exact: single spots, not areas.
--   ground: its spawns as place lists (D.Ground), if the caller has them.
function ns.ShowOnMap(name, places, exact, ground)
	local best, least
	for _, place in ipairs(places) do
		local yards = W.Distance(place.map, place.x, place.y)
		if not best or (yards and (not least or yards < least)) then best, least = place, yards or least end
	end
	if not best then return false end
	found = { kind = "found", who = name, places = places, exact = exact, ground = ground, actions = {} }
	picked = nil
	Shy.Maps.Open(best.map)
	ns.ApplyPins()
	return true
end

-- A quest of the map's quest log (LogRows.lua), as a stop with a key and `log` set.
--   ns.LightQuest(stop)   the one under the mouse there: its ground on the world map, as a hovered
--                         pin's. nil when the mouse has left.
--   ns.KeepQuest(stop)    a clicked one: kept as a search result is, with the note, until the note or a
--                         pin is clicked. nil lets go of it (and of nothing else).
--   ns.KeptQuest()        the kept one's key, or nil.
function ns.LightQuest(stop)
	-- The kept quest under the mouse stays as it is kept.
	if stop and found and found.key == stop.key then stop = found end
	if over.log == stop then return end
	over.log = stop
	LightMap()
end

function ns.KeepQuest(stop)
	if stop then
		found, picked = stop, nil
	elseif found and found.log then
		found = nil
	else
		return
	end
	ns.ApplyPins()
end

-- The search result shown on the map and kept (ns.ShowOnMap), or nil (ns.LetGo lets go of it).
function ns.FoundShown() return found end

function ns.KeptQuest()
	return found and found.log and found.key or nil
end

-- An objective under the mouse on the card: its own ground on the world map, as its
-- mark's hover lights it (in its shade, for a quest of several). nil when the mouse has left.
function ns.LightObjective(id, index)
	local entry = id and L.entries[id]
	if not entry then return ns.LightQuest(nil) end
	ns.LightQuest({ log = id, kind = "goal", key = "objective" .. id .. ":" .. index, objective = index,
		actions = { { kind = "goal", id = id, title = entry.title, level = entry.level } } })
end

-- The lit ground under the mouse
-- Lit ground says what it asks for while the mouse is on it and on nothing else of the map's (a pin
-- has its own hover), on the world map and on the minimap: the quest and what is done there
-- (CardHover.Ground), every ground the point is on where they lie over one another; on a spawn's dot or
-- pointer, who or what stands there (CardHover.Spawn). On the world map the hover goes with the cursor;
-- on the minimap it stands beside the minimap (CardHover.Minimap). Looked for ten times a second.
--   lit.anchor: the frame the hover is shown for. lit.shown: what it shows (nil: nothing).
--   lit.on: the map it is shown for ("map", "mini"). lit.map, lit.mini: seconds since each last looked.
local lit = { map = 0, mini = 0 }

-- on: the map asking. hits: Ground.Under's for the point under the mouse; nil when the mouse is on
-- none of that map's ground, which takes down the hover that map put up (never the other map's).
-- line: a line of the route under the mouse instead (ns.LEGS.Hit's), which says where it goes.
-- spawn: a spawn's dot or pointer under the mouse instead (Ground.SpawnAt's), which says who stands there.
local function SayGround(on, hits, line, spawn)
	local Hover = Shy.Hover
	-- (Something else took the hover meanwhile: nothing of ours is up.)
	if lit.shown and Hover.Owner() ~= lit.anchor then lit.shown = nil end
	local what = (hits or line or spawn) and on or nil
	if spawn then
		-- (Another spawn says how far it is again.)
		what = what .. "spawn" .. tostring(spawn.thing) .. #spawn.whats .. tostring(spawn.north) .. tostring(spawn.west)
	elseif line then
		-- (The stop it leads to: another, with a route worked out again, is said again.)
		local stop = ns.LEGS.End(line)
		what = what .. "line" .. tostring(line) .. tostring(stop)
	end
	for _, hit in ipairs(not line and hits or {}) do
		-- (The rows are the lit ground's own: others come with a route worked out again, and are said again.)
		what = what .. hit.kind .. tostring(hit.rows[1]) .. #hit.rows
	end
	if what == lit.shown or (not what and lit.on ~= on) then return end
	local content, wide
	if spawn then
		content, wide = ns.CardHover.Spawn(spawn)
	elseif line then
		content, wide = ns.LEGS.Says(line)
	elseif hits then
		content, wide = ns.CardHover.Ground(hits)
	end
	if not content then
		if lit.shown then Hover.Hide(lit.anchor) end
		lit.shown = nil
		return
	end
	if not lit.anchor then
		lit.anchor = CreateFrame("Frame", nil, UIParent)
		lit.anchor:SetSize(1, 1)
		lit.anchor:SetPoint("BOTTOMLEFT")
	end
	lit.shown, lit.on = what, on
	local opts = { side = "CURSOR", keep = false, width = wide }
	if on == "mini" then ns.CardHover.Minimap(opts) end
	Hover.Show(lit.anchor, content, opts)
end

-- Each frame, for the map whose hover is up: whether it is time to look under the mouse again.
local function FollowGround(on, elapsed)
	lit[on] = lit[on] + elapsed
	if lit[on] < 0.1 then return false end
	lit[on] = 0
	return true
end

local function GroundOnMap(elapsed)
	local x, y = GetCursorPosition()
	if not FollowGround("map", elapsed) then return end
	local hits
	-- On the bare map: what has the mouse is the map's own container, or a sheet of the game's laid over
	-- the whole canvas (its quest areas, its zone highlights). A pin or a marker is neither. (The map is the
	-- game's or ShyMaps' view: Shy.Maps.Canvas. A forbidden frame of the game's is never asked anything.)
	local container, focus = Maps.Canvas():GetCanvasContainer(), GetMouseFoci()[1]
	local bare = focus == container
		or (focus ~= nil and not focus:IsForbidden() and focus:GetParent() == Maps.Canvas():GetCanvas() and focus:GetWidth() >= layer:GetWidth() * 0.9)
	-- A spawn's picture under the mouse comes before a line of the route, and that before the ground.
	local line, spawn
	if ns.CardHover and not over.pin and bare and container:IsMouseOver() then
		local scale, left, top = layer:GetEffectiveScale(), layer:GetLeft(), layer:GetTop()
		if left and top then
			local px, py = x / scale - left, top - y / scale
			spawn = Ground and Ground.SpawnAt(px, py)
			if not spawn then line = ns.LEGS.Hit(px, py, ns.LEGS.reach / scale) end
			if not (spawn or line) and Ground then hits = Ground.Under(px, py) end
		end
	end
	ns.LEGS.Light(line)
	SayGround("map", hits, line, spawn)
end

local function GroundOnMini(elapsed)
	local x, y = GetCursorPosition()
	if not FollowGround("mini", elapsed) then return end
	local hits, spawn
	if Ground and ns.CardHover and not over.pin and Minimap:IsMouseOver() and GetMouseFoci()[1] == Minimap then
		local scale, radius = Minimap:GetEffectiveScale(), Minimap:GetWidth() / 2
		local middleX, middleY = Minimap:GetCenter()
		if middleX and radius > 0 then
			-- From the minimap's middle, as shares of its range. (Past a round one's rim nothing is drawn.)
			local fx, fy = (x / scale - middleX) / radius, (y / scale - middleY) / radius
			if Shy.MinimapShape() == "SQUARE" or fx * fx + fy * fy <= 1 then
				spawn = Ground.SpawnAtMini(fx, fy)
				if not spawn then hits = Ground.UnderMini(fx, fy) end
			end
		end
	end
	SayGround("mini", hits, nil, spawn)
end

local function SetupMap()
	-- At the level of the active-quest pins: over quest areas and quest givers, under the player. On the
	-- game's canvas or ShyMaps' view, whichever draws the map (Shy.Maps moves it between them).
	layer = Maps.MapLayer(0)
	-- The pins stand on a layer the zoom never scales, each hung from its place on this one (laid.Hang): a zoom
	-- carries them to their places, at their size on screen, and no pin is told anything of its steps.
	laid.pins = Maps.PinLayer(0)
	ns.pinLayer = laid.pins
	mapPins = Pool(laid.pins, PIN.mapSize, false)
	laid.pools = { mapPins, servicePins }
	if Ground then Ground.SetupMap(layer) end
	-- The hovered route has a frame of its own, so it fades as one.
	askLayer = CreateFrame("Frame", nil, layer)
	askLayer:SetAllPoints()
	askLayer:SetFrameLevel(layer:GetFrameLevel())
	askLayer:SetAlpha(0)
	youPen = Pen(layer, "TOPLEFT", layer, true, true)
	you.roadPen = Pen(layer, "TOPLEFT", layer, true, true)
	askPen = Pen(askLayer, "TOPLEFT", layer, true)
	-- Another map, or another canvas (ShyMaps' view taken into use or given up): gather again. Its zoom or
	-- size: lay again. (Shy.Maps tells a new map now and again next frame: its size and zoom come after.)
	Maps.OnMap(function(why)
		if why == "scale" then LayMap(true) elseif why == "size" then LayMap() else DrawMap() end
	end)
	layer:SetScript("OnShow", DrawMap)
	-- The layer takes the canvas's size a moment after the map opens.
	layer:SetScript("OnSizeChanged", function() LayMap() end)
	-- While open: re-lay the trail as the player moves, run its gleam, fade the hovered route.
	local since = 0
	-- (The map closed with the mouse on its ground: that hover goes with it.)
	layer:HookScript("OnHide", function()
		ns.LEGS.Light(nil)
		SayGround("map", nil)
	end)
	layer:SetScript("OnUpdate", Shy.Clocked("frame: map layer", function(_, elapsed)
		GroundOnMap(elapsed)
		-- A zoom has been still a moment: the route's lines laid as they should be (LayMap). Legs still to
		-- come after a frame's share (LayLegs): the next share, on the layout they were laid for.
		local LEGS = ns.LEGS
		local zoning = look.zoning
		if look.late then
			-- (The lit ground the map's laying had no share of the frame for.)
			look.late, look.litOn = nil, shownMap
			LightMap()
		elseif zoning then
			-- (A continent's zones still to gather: the next few; once all are in they join what was gathered,
			-- where they would have stood, and the map is laid with them.)
			if passes[shownMap] ~= zoning then
				look.zoning = nil
			elseif look.Zones(zoning) then
				look.zoning = nil
				for i, moved in ipairs(zoning.zones) do table.insert(others, look.zonesAt + i - 1, moved) end
				LayMap()
			end
		elseif LEGS.relay and GetTime() >= LEGS.relay then
			LayMap()
		elseif LEGS.more and GetTime() > LEGS.more and laid.shown then
			LayLegs(laid.shown, laid.walk, laid.spots, laid.scale, laid.unit)
		end
		since = since + elapsed
		if since >= LEG.youEvery then
			since = 0
			if (you.to or you.aloft or ns.Carried()) and not you.Still() then LayYou() end
		end
		Shine(youPen, GetTime())
		if you.roadPen then Shine(you.roadPen, GetTime()) end
		if ask.alpha ~= ask.want then
			local step = elapsed / LEG.reveal
			ask.alpha = ask.want > ask.alpha and math.min(1, ask.alpha + step) or math.max(0, ask.alpha - step)
			askLayer:SetAlpha(ask.alpha)
			if ask.alpha == 0 then
				ask.stop = nil
				LayAsk()
			end
		end
	end))
end

-- Minimap
-- The same route, numbers and lit pin as the world map, with the trail to the leading pin and the
-- walkers' ways. Everything that stands in the world is laid once on a plate (the ground's, or the
-- minimap's own while there is none: miniAt.Carry) and slides with it as the player walks, as the game's
-- own drawn minimap slides one canvas: it is laid again only for a new drawing of the plate (a zoom, a
-- turn, a long walk) or when what it shows changes. Frame by frame only the trail's start (Shy.Maps.Start)
-- and the leading pin waiting at the rim follow the player. A mask cuts the trail and the walks at the rim.

local miniPins, miniDriver
local miniYou                    -- the trail from the player, over the pins' ground
local miniHeading                -- the leading pin
local walkPen                    -- draws the walkers' ways on the minimap
local miniWalks = {}             -- their stretches on this continent: { north = {}, west = {}, lit, color }
local miniView                   -- the minimap's range in yards when its pins were last chosen
local miniScale, miniGrow = 1, 1 -- pin scale (the setting times miniGrow), and growth with zoom (PIN.miniGrow)
local miniAt = { stale = true }  -- what the minimap was last laid for; .stale: chosen again since
local ChooseMini
-- AHEAD: the trail is laid this many times the minimap's reach (its middle to its furthest corner) along the
-- way ahead of the player, however the way winds, so its end is always well out of sight; AGAIN: once less
-- than this many times the reach is left ahead of them as they walk, it is laid again from where they are,
-- back to AHEAD, before its end can come into sight. (Measured along the way: a way through a city's
-- streets that left a circle round the player and came back into sight was cut where it first left it.)
-- A way that doubles back is long along itself and still close by: the trail is laid on past AHEAD while its
-- end would stand within AGAIN times the reach of the player, and laid again when its end comes within the
-- reach all the same. It never stops short where it can be seen to while more of the way lies ahead.
-- STRAY: pixels the player may stray from it before it is laid again from where they are. KEEP: yards
-- walked before the minimap's own plate is drawn again (the ground's keeps its own). GLIDING: pixels the
-- pin at the rim may be short of where it is going and be there. WAY_ASKS: times a second the way is asked
-- for again while the player stands still.
miniAt.AHEAD, miniAt.AGAIN, miniAt.STRAY, miniAt.KEEP, miniAt.GLIDING, miniAt.WAY_ASKS = 2, 1.1, 4, 250, 0.1, 5

-- The minimap's reach, in its units: from its middle to its furthest corner (a square one's corner).
function miniAt.Reach(radius, square)
	return radius * Maps.RIM * (square and math.sqrt(2) or 1)
end
miniAt.view, miniAt.own = {}, { gen = 0 }

-- A place on the plate drawn at `shot`: from the plate's middle, in the minimap's units, y up.
function miniAt.On(shot, north, west)
	local east, up = -(west - shot.west) / shot.reach, (north - shot.north) / shot.reach
	return (east * shot.cos + up * shot.sin) * shot.radius, (-east * shot.sin + up * shot.cos) * shot.radius
end

-- The plate everything rides for the view `v` (Shy.Maps.Mini's fields), slid to where the player is.
-- Laid out as the ground's is drawn (Ground.Carry: its own drawing, or one held while it has none), so the
-- two slide as one; else as the minimap's own. The plate itself is ours (SetupMini): a region slides with
-- the frame it is anchored to only within its own frame's tree. Returns the shot and the plate.
function miniAt.Carry(v)
	local shot = Ground and Ground.Carry(v)
	if not shot then
		shot = miniAt.own
		local same = shot.ok and shot.reach == v.reach and shot.radius == v.radius and shot.continent == v.continent
			and shot.square == v.square and math.abs(shot.sin - v.sin) < 0.004 and math.abs(shot.cos - v.cos) < 0.004
			and (v.north - shot.north) ^ 2 + (v.west - shot.west) ^ 2 < miniAt.KEEP ^ 2
		if not same then
			shot.ok, shot.gen = true, shot.gen + 1
			shot.north, shot.west, shot.reach, shot.radius = v.north, v.west, v.reach, v.radius
			shot.sin, shot.cos, shot.square, shot.continent = v.sin, v.cos, v.square, v.continent
		end
	end
	local plate = miniAt.plate
	local x, y = miniAt.On(shot, v.north, v.west)
	if x ~= plate.x or y ~= plate.y then
		plate.x, plate.y = x, y
		plate:SetPoint("CENTER", Minimap, "CENTER", -x, -y)
	end
	return shot, plate
end

-- The mask the trail and the walks are cut by: the minimap's rim, round or square, where they melt away
-- (Shy.Maps.RimMask).
function miniAt.Mask(radius, square)
	Maps.RimMask(miniAt.mask, radius, square)
end

-- A pin put on `parent` at (x, y) of its own units, unless it stands there.
function miniAt.Hold(pin, parent, x, y)
	if pin.hold ~= parent or math.abs(pin.hx - x) > 0.01 or math.abs(pin.hy - y) > 0.01 then
		pin.hold, pin.hx, pin.hy = parent, x, y
		pin:SetPoint("CENTER", parent, "CENTER", x, y)
	end
end

-- The trail's points (xs, ys) on the plate drawn at `shot`, from the player at (north, west) to the leading
-- pin `to`: along the way over the ground where that is known (W.Way, the trail the world map draws too,
-- from the point walked toward on), straight where it isn't. To the place itself, or AHEAD times the
-- minimap's reach along the way, whichever comes first; clear of the player's arrow at one end and of the
-- pin at the other.
-- Returns how many there are. miniAt.short: it stops short of the place.
local miniPath = { north = {}, west = {} }
function miniAt.Trail(to, shot, north, west)
	local stop = to.stop
	local way, at
	if stop.north then way, at = W.Way(stop.continent, stop.north, stop.west, W.Prefer(stop)) end
	-- (What it was laid along: a frame where nothing moved lays it again only when the way is another, PlaceMiniPins.)
	miniAt.way, miniAt.wayAt, miniAt.wayTo = way, at, stop
	miniAt.short, miniAt.wayCut = false, false
	-- (While the first way there is being worked out, nothing: not a line through whatever is between.)
	if at == "working" then return 0 end
	local depth, fall, water = xs.depth, xs.fall, xs.water
	local px, py = miniAt.On(shot, north, west)
	xs[1], ys[1], depth[1], fall[1], water[1] = px, py, 0, 0, 0
	local count = 1
	-- As far along the way as AHEAD times the minimap's reach, however it winds; and on from there while its
	-- end would be in sight (within AGAIN times the reach of the player: a way that doubles back).
	local left = miniAt.AHEAD * miniAt.Reach(shot.radius, shot.square)
	local sight = (miniAt.AGAIN * miniAt.Reach(shot.radius, shot.square)) ^ 2
	-- The next point, the way cut short where it has run as far as it is laid. Whether it was.
	local function Add(x, y, level, falling, wet)
		local dx, dy = x - xs[count], y - ys[count]
		local length = math.sqrt(dx * dx + dy * dy)
		if length <= 0 then return false end
		local cut = length > left
		if cut then
			local cx, cy = xs[count] + dx * left / length, ys[count] + dy * left / length
			if (cx - px) ^ 2 + (cy - py) ^ 2 < sight then
				-- (In sight there: this stretch whole, and the next is looked at.)
				cut = false
			elseif left <= 0 then
				-- (Out of sight where the last stretch ended: it ends there.)
				return true
			else
				x, y = cx, cy
			end
		end
		left = math.max(0, left - length)
		count = count + 1
		xs[count], ys[count], depth[count], fall[count], water[count] = x, y, level, falling, wet
		return cut
	end
	local short = false
	if way then
		local path = Smoothed(miniPath, way, stop.north, stop.west)
		for i = Onward(path, at, north, west), path.n do
			local x, y = miniAt.On(shot, path.north[i], path.west[i])
			if Add(x, y, path.depth[i], path.fall[i], path.water[i]) then
				short = true
				break
			end
		end
		-- (Only the beginning of the way: it ends where that does, short of the place.)
		if way.cut then
			short, miniAt.wayCut = true, true
		elseif not short then
			-- On to the place itself, as the world map's trail goes: the ground's way may end short of it
			-- (on the nearest floor it knows), and the line is to lead to the pin, not stop on the way there.
			local x, y = miniAt.On(shot, stop.north, stop.west)
			short = Add(x, y, path.depth[path.n], path.fall[path.n], path.water[path.n])
		end
	else
		local x, y = miniAt.On(shot, stop.north, stop.west)
		short = Add(x, y, 0, 0, 0)
	end
	-- (The player is on the level the way sets out on.)
	depth[1] = depth[2] or 0
	miniAt.short = short
	-- (Shy.Maps.Start keeps it clear of the arrow as the player walks on.)
	return Trim(count, LEG.miniYou, short and 0 or to.rim)
end

-- (A minimap line's unit: LEG.miniLine of the world map's, growing as the minimap is zoomed and with a minimap
-- made larger, never finer on screen for one made smaller: a line a pixel or two across is a jagged one.)
function ns.MiniUnit()
	return LEG.miniLine * miniGrow * math.max(1, UIParent:GetEffectiveScale() / Minimap:GetEffectiveScale())
end
-- The trail to the leading pin `to`, laid on the plate (shot, plate) for the player at (north, west).
-- (Carried: no way to walk. The flight's or the crossing's own line is drawn.)
local function LayMiniLines(to, shot, plate, north, west)
	Begin(miniYou, ns.MiniUnit())
	miniYou.anchor = plate
	miniAt.short = false
	if to and to.stop and to.on and not ns.Carried() and not (Ground and Ground.Standing()) then
		local count = miniAt.Trail(to, shot, north, west)
		if count > 1 then Ribbon(miniYou, count, to.stop.color) end
	end
	Finish(miniYou)
end

-- Where the leading pin waits at the rim, as shares of the minimap's range: where the trail leaves the
-- minimap (at its rim, brought in to PIN.edge), or out along where it ends; with no trail, out along (fx, fy).
-- (px, py): the player on the plate. The way to walk is the one the ribbon shows.
function miniAt.Rim(fx, fy, px, py, radius, square)
	local path = miniYou.trail
	local x, y = fx, fy
	if path and path.n > 1 then
		local from = math.max(2, miniYou.seek or 2)
		local lx, ly = (path.x[from - 1] - px) / radius, (path.y[from - 1] - py) / radius
		x, y = (path.x[path.n] - px) / radius, (path.y[path.n] - py) / radius
		for i = from, path.n do
			local nx, ny = (path.x[i] - px) / radius, (path.y[i] - py) / radius
			local _, _, bx, by, cut = Maps.Within(lx, ly, nx, ny, square, Maps.RIM)
			if bx and cut then
				x, y = bx, by
				break
			end
			lx, ly = nx, ny
		end
	end
	local out = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
	if out > 0 then x, y = x * PIN.edge / out, y * PIN.edge / out end
	return x, y
end

-- The leading pin, waiting at the rim. It glides there: where the trail leaves the minimap shifts when
-- another way is found, and a pin that leapt with it would never hold still.
function miniAt.Wait(pin, px, py, radius, square, scale)
	local stop = pin.stop
	local x, y = miniAt.Rim(pin.fx, pin.fy, px, py, radius, square)
	local now = GetTime()
	if pin.glided == stop and pin.glidedFor == R.built and pin.gx then
		local share = math.min(1, (now - pin.glidedAt) / LEG.glide)
		local tx, ty = x, y
		x, y = pin.gx + (tx - pin.gx) * share, pin.gy + (ty - pin.gy) * share
		-- (Not there yet: placed again next frame, though nothing else has moved.)
		if math.max(math.abs(x - tx), math.abs(y - ty)) * radius > miniAt.GLIDING then miniAt.gliding = true end
	end
	pin.glided, pin.glidedFor, pin.glidedAt, pin.gx, pin.gy = stop, R.built, now, x, y
	pin.fx, pin.fy = x, y
	miniAt.Hold(pin, Minimap, x * radius / scale, y * radius / scale)
end

-- The walkers' ways on the minimap (miniWalks), whole, on the plate drawn at `shot` (the mask cuts them
-- at the rim). With no shot, none.
-- A walker's way is dotted: a small square dot every DOT_EVERY screen pixels along it, in its color,
-- the spacing carried on from one stretch to the next (dotAt: how far into a gap the last one ended).
-- The dots are plain textures of their own (walkDots), laid where the pen lays: one texture a dot, no
-- stroke under them.
miniAt.DOT_EVERY, miniAt.DOT_SIZE = 7, 3
miniAt.walkDots = { used = 0, shown = 0 }
function miniAt.Dots(ax, ay, bx, by, alpha, color)
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	if not (length > 0) then return end
	local unit = walkPen.unit or 1
	local step, size = miniAt.DOT_EVERY * unit, miniAt.DOT_SIZE * unit
	if not (step > 0) then return end
	local pool = miniAt.walkDots
	-- (A walker of no kind of its own: the trail's color, as a stroke would be.)
	local r, g, b
	if color then r, g, b = color[1], color[2], color[3] else r, g, b = Maps.TrailColor() end
	local start = miniAt.dotAt or 0
	local s = (step - start % step) % step
	-- (Each dot by where it is, a whole step after the last: never more than 400 a stretch.)
	for _ = 1, 400 do
		if s > length then break end
		local used = pool.used + 1
		pool.used = used
		local dot = pool[used]
		if not dot then
			dot = walkPen.owner:CreateTexture(nil, "ARTWORK")
			dot:SetSnapToPixelGrid(false)
			dot:SetTexelSnappingBias(0)
			dot:SetColorTexture(1, 1, 1, 1)
			if walkPen.mask then dot:AddMaskTexture(walkPen.mask) end
			pool[used] = dot
		end
		dot:SetSize(size, size)
		dot:SetPoint("CENTER", walkPen.anchor, "CENTER", ax + dx * s / length, ay + dy * s / length)
		dot:SetVertexColor(r, g, b, alpha)
		if used > pool.shown then
			pool.shown = used
			dot:Show()
		end
		s = s + step
	end
	miniAt.dotAt = start + length
end
local function LayMiniWalks(shot, plate)
	Begin(walkPen, ns.MiniUnit())
	walkPen.anchor = plate or Minimap
	miniAt.walkDots.used = 0
	for _, walk in ipairs(shot and miniWalks or {}) do
		local lx, ly
		miniAt.dotAt = 0
		local alpha = walk.lit and 1 or LEG.way
		for i = 1, #walk.north do
			local x, y = miniAt.On(shot, walk.north[i], walk.west[i])
			if lx then miniAt.Dots(lx, ly, x, y, alpha, walk.color) end
			lx, ly = x, y
		end
	end
	Finish(walkPen)
	-- (The dots not laid this time put away.)
	local pool = miniAt.walkDots
	for i = pool.used + 1, pool.shown do pool[i]:Hide() end
	pool.shown = pool.used
end

-- Every frame while anything shows. Standing still with nothing new, only the gleams run on. Walking, the
-- plate slides and the trail's start and the pin at the rim follow; the rest is laid again only for a new
-- drawing of the plate, or when what it shows changes (miniAt.stale).
local function PlaceMiniPins()
	local reach = C_Minimap.GetViewRadius()
	local radius = Minimap:GetWidth() / 2
	-- (Where the player is this frame, asked of the game once for everyone who draws by it: the card's arrow,
	-- the waypoint arrow, this. Each ask hands over new tables.)
	local north, west = W.Here()
	local continent = W.continent
	if not (north and continent and W.map) or not reach or reach <= 0 or radius <= 0 then
		for _, pin in ipairs(miniPins) do
			pin.shownAs = false
			pin:Hide()
		end
		Begin(miniYou, LEG.miniLine)
		Finish(miniYou)
		LayMiniWalks()
		miniAt.stale = true
		if Ground then Ground.PlaceMini() end
		return
	end
	-- The zoom changed: which marks merge has changed too.
	if reach ~= miniView then return ChooseMini() end
	local facing = C_CVar.GetCVarBool("rotateMinimap") and GetPlayerFacing() or 0
	local square = Shy.MinimapShape() == "SQUARE"
	local sin, cos = math.sin(facing), math.cos(facing)
	-- Already on the lit ground: the area is the direction. No ribbon is asked for, and none is kept.
	-- Carried: no way to walk.
	local home = Ground and Ground.Standing() or false
	local carried = ns.Carried() and true or false
	if home ~= miniAt.home or carried ~= miniAt.carried then miniAt.home, miniAt.carried, miniAt.stale = home, carried, true end
	if home then miniAt.way, miniAt.wayAt, miniAt.wayTo = nil, nil, nil end
	-- (A way found, or found anew, while the player stands still is laid at once: ShyWay says nothing of it,
	-- whoever draws the way asks for it again at every frame.)
	-- (Standing where they stood, with a way laid: asked WAY_ASKS times a second, not at every frame.)
	local trailTo = miniAt.wayTo
	if not home and not miniAt.stale and trailTo and miniHeading and miniHeading.stop == trailTo and trailTo.north then
		local now = GetTime()
		local still = north == miniAt.north and west == miniAt.west and miniAt.wayAt ~= "working"
		if not still or now - (miniAt.wayAsked or 0) >= 1 / miniAt.WAY_ASKS then
			miniAt.wayAsked = now
			local way, at = W.Way(trailTo.continent, trailTo.north, trailTo.west, W.Prefer(trailTo))
			-- Another way table, or the first answer after "working": not which point they walk toward (that
			-- moves on as they walk; Shy.Maps.Start follows them along the trail laid).
			if way ~= miniAt.way or (miniAt.wayAt == "working" and at ~= "working") then miniAt.stale = true end
		end
	end
	if Ground then Ground.PlaceMini(continent, north, west, reach, radius, sin, cos, square) end
	local v = miniAt.view
	v.north, v.west, v.reach, v.radius, v.continent, v.sin, v.cos, v.square = north, west, reach, radius, continent, sin, cos, square
	local shot, plate = miniAt.Carry(v)
	local drawn = shot ~= miniAt.shot or shot.gen ~= miniAt.gen
	-- Standing still with nothing new: the plate has not moved, nor anything on it.
	if not (drawn or miniAt.stale or miniAt.gliding) and north == miniAt.north and west == miniAt.west then
		Shine(miniYou, GetTime())
		return
	end
	miniAt.north, miniAt.west = north, west
	miniAt.Mask(radius, square)
	local px, py = miniAt.On(shot, north, west)
	-- SetPoint offsets are in the pin's own scale.
	local scale = miniScale
	-- Pins are exactly on their places and never make room (as on a zone map). One in range stands on the
	-- plate, put there again only for a new drawing of it; out of range only the leading pin shows,
	-- waiting at the rim (miniAt.Wait, once the trail is where it is this frame).
	local waiter
	for _, pin in ipairs(miniPins) do
		local stop = pin.stop
		if stop then
			-- (A pin on the spot of ground the player is on shows nothing, and no line runs to or from it.)
			local here = stop.continent == continent and not pin.inside and not (home and pin == miniHeading)
			local x, y, out = 0, 0, 0
			if here then
				-- From the player, as shares of the minimap's range.
				x, y = miniAt.On(shot, stop.north, stop.west)
				local lx, ly = (x - px) / radius, (y - py) / radius
				out = square and math.max(math.abs(lx), math.abs(ly)) or math.sqrt(lx * lx + ly * ly)
				pin.fx, pin.fy = lx, ly
			end
			local waiting = out >= PIN.edge
			local shown = here and (not waiting or pin.next)
			pin.on, pin.near = shown, here and not waiting
			if shown ~= pin.shownAs then
				pin.shownAs = shown
				pin:SetShown(shown)
			end
			if shown then
				-- (A pin over the player's arrow fades with its nearness, so the arrow shows through.)
				local clear = out < LEG.miniClear and (LEG.miniClearLow + (1 - LEG.miniClearLow) * out / LEG.miniClear) or 1
				local alpha = math.floor((waiting and PIN.waiting or (stop.party and 0.75 or 1) * clear) * 255 + 0.5) / 255
				if alpha ~= pin.alphaAs then
					pin.alphaAs = alpha
					pin:SetAlpha(alpha)
				end
				if waiting then
					waiter = pin
				else
					pin.glided = nil
					miniAt.Hold(pin, plate, x / scale, y / scale)
				end
			end
		end
	end
	-- The trail: laid again for a new drawing of the plate, for what it leads to or its way changing, once
	-- the player strays from it, or walks far enough toward the end of one that stops short to see it.
	-- Else only its start follows them.
	local to = miniHeading
	local relay = drawn or miniAt.stale or (to and to.on or false) ~= miniAt.trailOn
	if not relay then
		local stray = Maps.Start(miniYou, px, py, LEG.miniYou)
		relay = stray ~= nil and stray > miniAt.STRAY
		-- Laid short of the place (AHEAD of the reach along the way): laid again from here, back to AHEAD,
		-- once less than AGAIN of the reach is left ahead of the player, before its end comes into sight.
		local path = miniYou.trail
		if not relay and miniAt.short and path and path.n > 1 then
			local reach = miniAt.Reach(radius, square)
			relay = path.along[path.n] - (path.from or 0) < miniAt.AGAIN * reach
			-- ... or once its end comes within the reach all the same: the way doubled back toward the player.
			-- (Not where the way itself is only known that far: laying it again would end at the same place.)
			if not relay and not miniAt.wayCut then
				relay = (path.x[path.n] - px) ^ 2 + (path.y[path.n] - py) ^ 2 < reach * reach
			end
		end
	end
	if relay then
		miniAt.trailOn = to and to.on or false
		LayMiniLines(to, shot, plate, north, west)
		Maps.Start(miniYou, px, py, LEG.miniYou)
	end
	-- The walks: laid again for a new drawing of the plate, or walks chosen anew (DrawMini).
	if drawn or not miniAt.walksLaid then
		miniAt.walksLaid = true
		LayMiniWalks(shot, plate)
	end
	miniAt.stale, miniAt.shot, miniAt.gen, miniAt.gliding = false, shot, shot.gen, false
	if waiter then miniAt.Wait(waiter, px, py, radius, square, scale) end
	Shine(miniYou, GetTime())
end

-- Spawn lights on the minimap, as LightMap: the hovered or clicked pin's quests, else the leading stop's.
local function LightMini()
	if not Ground then return end
	local on = T.db.minimapPins
	local asked = on and (Asking(true) or look.mini) or nil
	if asked then
		Ground.ChooseMini(asked, T.db.goals, miniView, true, asked == look.mini)
	else
		Ground.ChooseMini(on and look.miniHeaded or nil, on and T.db.goals, miniView, nil, nil, on and Inside(look.miniHeaded))
	end
end

-- Choose the minimap's pins: the route's places with the world map's numbers and lit state, and the
-- same Others list the current zone's map shows.
local function DrawMini()
	wipe(miniWalks)
	miniAt.walksLaid = nil   -- (the walks are chosen anew: laid again at the next placement)
	miniHeading = nil
	miniAt.stale = true
	-- (The minimap's own plate is drawn again where the player is: what is chosen anew is laid from there.)
	miniAt.own.ok = false
	miniView = C_Minimap.GetViewRadius()
	local levels = Minimap:GetZoomLevels() or 0
	miniGrow = Grown(levels > 1 and Minimap:GetZoom() / (levels - 1), PIN.miniGrow)
	miniScale = T.db.pinSize * miniGrow
	local pickedStop           -- the clicked pin's stop, if the minimap has it
	if T.db.minimapPins then
		-- All one size. A line to a pin ends at its rim, or at its point for a numbered place.
		local walkers = {}
		local function Pin(stop, kind, lit, count)
			Walkers(stop, lit, walkers)
			local pin = miniPins:Next()
			pin.stop, pin.next, pin.rim = stop, false, count and 0 or PIN.miniSize * LEG.rim * miniScale
			pin.inside = Inside(stop)
			-- (Shown, faded and placed afresh at the next placement: PlaceMiniPins sets only what changed.)
			pin.shownAs, pin.alphaAs, pin.hold = nil, nil, nil
			pin:SetScale(miniScale)
			pin:Set(kind == "goal" and stop.mark == "buy" and "buy" or kind, lit, count, ns.StopTone(stop))
			pin:SetMood(ns.StopMood(stop))
			pin:SetLetter(ns.StopLetter(stop, kind))
			pin.picked = Holds(stop, picked)
			pin:SetPicked(pin.picked)
			if pin.picked then pickedStop = stop end
			return pin
		end
		local lap = ns.LapStart()
		local places, _, way, leading = TheWay(PIN.guide)
		lap = Lap("minimap chosen: the way ahead", lap)
		local pins = {}
		for order, place in ipairs(places) do
			pins[order] = Pin(Stands(place), "step", place.lit, place.number)
			if place.lit and not miniHeading then miniHeading = pins[order] end
		end
		-- Everything else on the current zone's map, merged within a pin's reach in yards at this zoom
		-- (objectives within PIN.same, as on the zone map).
		local radius = Minimap:GetWidth() / 2
		local reach = (miniView and miniView > 0 and radius > 0) and PIN.miniSize * PIN.together * miniScale / radius * miniView or 0
		local list = {}
		-- (What the zone's map chose is the minimap's too, until the route is built again: MapPass.)
		for _, other in ipairs(W.map and Others(W.map, Covers(way), (Theirs(W.map)), true, nil, MapPass(W.map)) or {}) do
			if other.stop.north then list[#list + 1] = other end
		end
		lap = Lap("minimap chosen: givers and objectives", lap)
		local groups = Grouped(list, leading, function(a, b)
			return a.stop.continent == b.stop.continent
				and W.Between(a.stop.north, a.stop.west, b.stop.north, b.stop.west) < (a.kind == "goal" and PIN.same or reach)
		end)
		for _, group in ipairs(groups) do
			local pin = Pin(group.stop, group.kind, group.lit)
			-- A chosen stop leads whatever else is lit.
			if group.lit and (not miniHeading or group.stop.chosen) then miniHeading = pin end
		end
		-- The leading stop always has a pin: its own mark if nothing above covers it.
		local lead = R.stops[1]
		if not miniHeading and lead and lead.kind ~= "zone" and lead.north then
			lead.key = lead.key or ("lead" .. lead.kind .. (lead.actions[1] and lead.actions[1].id or ""))
			miniHeading = Pin(lead, ns.StopMark(lead), true)
		end
		-- .next: it waits at the rim while out of range.
		if miniHeading then miniHeading.next = true end
		-- The walkers' ways in world yards, for LayMiniWalks.
		for _, npc in ipairs(walkers) do
			for _, stretch in ipairs(D.Path(npc)) do
				local path = { north = {}, west = {}, lit = walkers[npc], color = WalkColor(walkers, npc) }
				for i = 1, #stretch.points, 2 do
					local continent, north, west = W.ToWorld(stretch.map, stretch.points[i], stretch.points[i + 1])
					if continent == W.continent and north then
						path.north[#path.north + 1], path.west[#path.west + 1] = north, west
					end
				end
				if #path.north > 1 then miniWalks[#miniWalks + 1] = path end
			end
		end
	end
	local pins = miniPins.used
	miniPins:Done()
	-- A clicked pin gone from the minimap is dropped, unless the open world map still has it.
	local had = look.mini
	look.mini = pickedStop
	if had and not pickedStop and not (layer and layer:IsVisible() and look.map) then picked = nil end
	look.miniHeaded = T.db.minimapPins and Headed(miniHeading and miniHeading.stop) or nil
	LightMini()
	local any = pins > 0 or (Ground ~= nil and Ground.OnMini()) or false
	miniDriver:SetShown(any)
	if any then PlaceMiniPins() elseif Ground then Ground.PlaceMini() end
end
ChooseMini = DrawMini

-- A click on a pin toggles its lights, on both maps. Returns whether it is lit now.
function Pick(pin)
	local off = Holds(pin.stop, picked)
	picked = not off and pin.stop.key or nil
	-- Clicked off: its light goes at once, though the mouse is still on the pin.
	over.hushed = off
	found = nil
	-- Order matters: the pin's own map first, so the other doesn't drop a pick it has no pin for.
	if pin.minimap then
		DrawMini()
		LayMap()
	else
		LayMap()
		DrawMini()
	end
	return picked ~= nil
end

-- The mouse entered a pin (mini: on the minimap), or left it (pin nil).
function Over(pin, mini)
	over.pin, over.mini, over.hushed = pin, mini, false
	if mini then LightMini() else LightMap() end
end

local function SetupMini()
	if Ground then Ground.SetupMini() end
	miniPins = Pool(Minimap, PIN.miniSize, true)
	-- Holds the lines and drives the per-frame placement.
	miniDriver = CreateFrame("Frame", nil, Minimap)
	miniDriver:SetAllPoints()
	-- The plate carries more than the minimap shows (the trail past the rim, the walks whole): the frame
	-- cuts it to the minimap, and the mask (miniAt.Mask) to its rim.
	miniDriver:SetClipsChildren(true)
	miniDriver:Hide()
	miniAt.mask = miniDriver:CreateMaskTexture()
	miniAt.mask:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	-- The minimap's own plate, while the ground has none to lend (miniAt.Carry).
	miniAt.plate = CreateFrame("Frame", nil, miniDriver)
	miniAt.plate:SetSize(1, 1)
	miniAt.plate:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	miniYou = Pen(miniDriver, "CENTER", Minimap, false, true)
	miniYou.mask = miniAt.mask
	walkPen = Pen(miniDriver, "CENTER", Minimap, false)
	walkPen.mask = miniAt.mask
	miniDriver:SetScript("OnUpdate", function(_, elapsed)
		-- Time only. Counting the heap here ran three times a frame whenever the minimap showed anything.
		local from = debugprofilestop()
		PlaceMiniPins()
		local placed = debugprofilestop()
		GroundOnMini(elapsed or 0)
		Shy.Clock("minimap, a frame"):Lap(debugprofilestop() - from)
		Shy.Clock("minimap, placing pins"):Lap(placed - from)
	end)
	miniDriver:HookScript("OnHide", function() SayGround("mini", nil) end)
end

-- Draw both maps again. What the ground gathered is forgotten here and nowhere else: it is good for as
-- long as the route and the log are, so opening the map or changing the map shown gathers nothing twice.
--   fresh: the route was just built, so what TheWay kept for it stands (the card has asked already).
function ns.ApplyPins(fresh)
	if not layer then return end
	if not fresh then wayFor = nil end
	-- (What the marks off the route were drawn from: a build that changes only this draws them again.)
	look.read = look.Read()
	if Ground then Ground.Forget() end
	wipe(passes)
	wipe(bests)
	DrawMap()
	DrawMini()
	-- The map's quest log wears the route's numbers and lights (LogRows.lua).
	if ns.LogRows then ns.LogRows.Paint() end
end

-- What the marks off the route read besides it, as one text: which quests are on offer (L.version: a quest
-- taken, handed in or abandoned, a level, a standing) and the log's quests, each ready, failed or open with
-- which of its objectives are done. Givers, turn-ins and objective marks come from these, not the route.
look.Read = function()
	local out = { L.version }
	-- (A quest skipped, or included again, is drawn so: Route.lua, R.Skip.)
	for id, how in pairs(type(ns.char and ns.char.aside) == "table" and ns.char.aside or {}) do out[#out + 1] = id .. how end
	for _, entry in ipairs(L.order) do
		out[#out + 1] = entry.id .. (entry.complete and "c" or entry.failed and "f" or "o")
		for _, goal in ipairs(entry.goals or {}) do out[#out + 1] = goal.finished and "1" or "0" end
	end
	return table.concat(out, " ")
end

function ns.SetupPins()
	-- (ShyCore's map drawing comes with a restart of the game, not a reload: until then, no pins.)
	if not Shy.Maps then return end
	SetupMap()
	SetupMini()
	ns.OnRoute(function(rebuilt, changes)
		if not rebuilt then return end
		-- The stops and order stand, and so does what the other marks read: only yards and trails may have
		-- changed (terrain, a remeasure). A giver whose quest was just taken is no stop of the route's, and
		-- would stay on both maps if only the route were asked.
		if changes and changes.same and look.Read() == look.read then
			miniAt.stale = true
			return
		end
		ns.ApplyPins(true)
	end, true)
	-- A leg's way over the ground came to be known: the legs follow it now.
	Shy:On("SHY_TERRAIN", function()
		if ns.LEGS.ways.waiting and layer:IsVisible() then LayMap() end
	end)
	-- The finder's lens on the map's bar too (ShyMaps), as on the card: opened from the map, it lists the
	-- quests of the zone the map shows (a continent or the world: of the zone you are in).
	local maps = Shy.addons.Maps
	if maps and maps.BarButton and ns.Find then
		maps:BarButton("find", {
			art = "Interface\\Common\\UI-Searchbox-Icon", size = 11,
			-- (No hover: a lens is plain to anyone.)
			click = function()
				local map = Shy.Maps.ShownMap()
				local info = map and C_Map.GetMapInfo(map)
				ns.Find.Toggle(nil, nil, (info and info.mapType >= Enum.UIMapType.Zone) and map or nil)
			end,
		})
	end
end
