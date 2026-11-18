-- The places that matter on a map, each kind with its own switch: flight points (those not yet found
-- faded, with whose they are; one you know says how long the flight there takes from the one nearest you, and
-- lights its way), dungeon entrances (the hover with the levels the Group Finder suggests and what
-- the dungeon journal has of it; a click goes in: the window turns to its dungeons, on that one). An entrance
-- is the game's own where its map has one; this client's maps have none, so every dungeon the journal has
-- stands at its door (Journal.Door: ShyQuest's word for it) as the family's mark, in its levels' color, lit
-- for one at your level, on its zone's map and on the continent's,
-- points of interest, and the ways to other maps (a click goes there).

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI

local POI = 18              -- a point of interest drawn from the minimap's icon sheet
local MOST = 30             -- no place's icon is drawn larger than this
local DIRECTIONS = 26       -- the place a guard pointed out
-- A dungeon's door: the game's own swirling way in (its dungeon and raid signs, the ones its newer maps wear),
-- turning slowly, quicker under the mouse; one away from your level stands paler.
local DOOR = { size = 30, turn = 14, quick = 3.5, pale = 0.62, sign = { dungeon = "Dungeon", raid = "Raid" } }
local ASKED = 3            -- seconds after picking a gossip choice that a place it marks opens the map

local pools = {}            -- kind -> pins
local shown = {}            -- kind -> how many are up

-- A flight point you know: the flight there from the one you know nearest you (ShyWay's flights), how long
-- it takes and how many stops it makes, the way it flies lit on the map. One not yet found says so.
local function Nearest(known)
	local continent, north, west = Shy.Here()
	if not continent then return nil end
	local best, least
	for _, stop in ipairs(Shy.Way.Stops()) do
		if stop.by == "flight" and stop.node and known[stop.node] and stop.world == continent then
			local d = (stop.north - north) ^ 2 + (stop.west - west) ^ 2
			if not least or d < least then best, least = stop, d end
		end
	end
	return best
end

local function Count(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

local function FlightTip(pin)
	local content = { title = pin.name or "" }
	local rows = {}
	local flight = Shy.Way.Flight
	if pin.text then
		rows[1] = { text = pin.text, quiet = true }
	elseif not Shy.Way.missing and flight and flight.Route then
		local known = Shy.Way.Flights()
		local from = Nearest(known)
		if from and from.node == pin.node then
			rows[1] = { glyph = "home", text = "Nearest to you" }
		elseif from then
			local hops = flight.Route(from.node, pin.node, known)
			if hops then
				local seconds, sure = flight.Seconds(from.node, pin.node, known, Count(known))
				rows[#rows + 1] = { glyph = "fly", text = "From " .. (from.name or "?"), name = true,
					right = seconds and ((sure and "" or "about ") .. flight.Clock(seconds)) or nil }
				rows[#rows + 1] = { glyph = "go", text = #hops <= 2 and "Direct" or (#hops - 2 == 1 and "1 stop" or ("%d stops"):format(#hops - 2)) }
				local line = flight.Path(hops)
				if line and ns.Travel then ns.Travel.Light(pin, Shy.Theme.TRAVEL.flight, { line }) end
			end
		end
	end
	if #rows > 0 then content.sections = { { rows = rows } } end
	Shy.Hover.Show(pin, content)
end

local function Leave(pin)
	Shy.Hover.Hide(pin)
	if ns.Travel then ns.Travel.Unlight(pin) end
end

local function Tip(pin)
	if pin.node then return FlightTip(pin) end
	local hints
	if pin.link then
		hints = { { "left", "Open this map" } }
	elseif pin.goal then
		hints = { { "left", "Lead me there" } }
	elseif pin.dungeon then
		hints = { { "left", "Go in" } }
	end
	local levels, color
	if pin.low then levels, color = ns.Levels(pin.low, pin.high, true) end
	if not levels and not pin.dungeon then
		UI.Tip(pin, pin.name or "", pin.text, { hints = hints })
		return
	end
	local lines = UI.Lines()
	lines:AddLine(pin.name or "")
	if levels then lines:AddLine(levels, color.r, color.g, color.b) end
	if pin.text then lines:AddLine(pin.text) end
	-- A dungeon the journal has: how much is in it, and what of it is yours.
	local book = pin.dungeon and ns.Dungeons.Book(pin.dungeon)
	if book then
		local C = UI.colors
		lines:AddLine(("%d bosses"):format(#book.bosses), C.text[1], C.text[2], C.text[3])
		local quest = Shy.addons.Quest
		local quests = quest and quest.DungeonQuests and quest:DungeonQuests(pin.dungeon)
		if quests and #quests > 0 then
			local done = 0
			for _, one in ipairs(quests) do
				if one.state == "done" then done = done + 1 end
			end
			lines:AddLine(("%d of %d quests handed in"):format(done, #quests), C.text[1], C.text[2], C.text[3])
		end
		local wanted = #ns.Dungeons.WantedIn(pin.dungeon)
		if wanted > 0 then
			lines:AddLine(wanted == 1 and "A drop you starred is in here" or ("%d drops you starred are in here"):format(wanted),
				C.alert[1], C.alert[2], C.alert[3])
		end
	end
	UI.Tip(pin, lines, { hints = hints })
end

-- The levels the Group Finder suggests for each dungeon, by its journal entry (the entrances name theirs)
-- and by name: { low, high }. Read once the finder has its activities.
local ranges
local function Ranges()
	if ranges then return ranges end
	local found, any = { journal = {}, name = {} }, false
	for _, category in ipairs(C_LFGList.GetAvailableCategories() or {}) do
		for _, id in ipairs(C_LFGList.GetAvailableActivities(category) or {}) do
			local info = C_LFGList.GetActivityInfoTable(id)
			if info and info.mapID and info.mapID > 0 and (info.maxLevelSuggestion or 0) > 0 then
				local low = (info.minLevelSuggestion or 0) > 0 and info.minLevelSuggestion or info.minLevel or 0
				local high = info.maxLevelSuggestion
				local journal = C_EncounterJournal.GetInstanceForGameMap(info.mapID)
				for _, where in ipairs({ { found.journal, journal }, { found.name, info.shortName }, { found.name, info.fullName } }) do
					local list, key = where[1], where[2]
					if key and key ~= "" then
						local have = list[key]
						if have then
							have[1], have[2] = math.min(have[1], low), math.max(have[2], high)
						else
							list[key] = { low, high }
						end
					end
				end
				any = true
			end
		end
	end
	if any then ranges = found end
	return found
end

local function DungeonLevels(door)
	local all = Ranges()
	local range = all.journal[door.journalInstanceID] or all.name[door.name]
	if range then return range[1], range[2] end
end

-- Puts the game's pin on a place and has its arrow lead there.
-- Where ShyQuest is loaded the place goes first in the route under its name and the arrow points the way
-- (ShyWay draws it); without it the game's own waypoint arrow leads.
local function Track(goal)
	if not C_Map.CanSetUserWaypointOnMap(goal.map) then
		UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA())
		return
	end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
	local quest = Shy.addons.Quest
	if quest and quest.Go and quest:Go(goal.map, goal.x, goal.y, goal.name) then return end
	Shy.Waypoint.Set(goal.map, goal.x, goal.y, true)
end

local function Click(pin, button)
	if button ~= "LeftButton" then return end
	if pin.link then
		View.Show(pin.link, "into")
	elseif pin.goal then
		Track(pin.goal)
	elseif pin.dungeon and ns.Sides and ns.Sides.Enter then
		-- In through the door: the window turns to its dungeons, on this one.
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ns.Sides.Enter(pin.dungeon, pin.x, pin.y)
	end
end

local function Take(kind, level)
	local pool = pools[kind]
	if not pool then
		pool = {}
		pools[kind] = pool
	end
	shown[kind] = (shown[kind] or 0) + 1
	local pin = pool[shown[kind]]
	if not pin then
		pin = View.Pin(level, 20, Tip, Click)
		pin:SetScript("OnLeave", Leave)
		pin.icon:ClearAllPoints()
		pin.icon:SetPoint("CENTER")
		pool[shown[kind]] = pin
	end
	pin.link, pin.goal, pin.text, pin.low, pin.high, pin.dungeon, pin.node = nil, nil, nil, nil, nil, nil, nil
	pin.icon:SetDesaturated(false)
	pin.icon:SetAlpha(1)
	pin.icon:SetTexCoord(0, 1, 0, 1)
	return pin
end

-- An atlas at its own size, kept within MOST.
local function Atlas(pin, name)
	local info = C_Texture.GetAtlasInfo(name)
	if not info then return false end
	pin.icon:SetAtlas(name)
	local w, h = info.width, info.height
	local k = math.min(1, MOST / math.max(w, h, 1))
	pin.icon:SetSize(w * k, h * k)
	pin:SetSize(w * k, h * k)
	return true
end

local function Put(pin, position, name)
	pin.name = name
	local x, y = position:GetXY()
	View.Stand(pin, x, y)
end

local function Flights(map)
	if not C_TaxiMap.ShouldMapShowTaxiNodes(map) then return end
	for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
		if ns.Ours(node) and node.atlasName then
			local pin = Take("flights", "PIN_FRAME_LEVEL_FLIGHT_POINT")
			local atlas = node.textureKit and (node.textureKit .. "-" .. node.atlasName) or node.atlasName
			if Atlas(pin, atlas) then
				if node.isUndiscovered then
					pin.icon:SetDesaturated(true)
					pin.icon:SetAlpha(0.65)
					pin.text = node.faction == Enum.FlightPathFaction.Neutral and UNDISCOVERED_NEUTRAL_FLIGHTPOINT
						or UNDISCOVERED_FACTION_FLIGHTPOINT:format(node.faction == Enum.FlightPathFaction.Horde and FACTION_HORDE or FACTION_ALLIANCE)
				end
				pin.node = node.nodeID
				Put(pin, node.position, node.name)
			end
		end
	end
end

-- Where a door (a map and its shares of it) lies on the map shown: its own map's, or through the world they
-- both lie in (a zone's door on its continent); nil off it.
local function Spot(map, door)
	if door.map == map then return door.x, door.y end
	local world, n0, w0, n1, w1 = View.World(door.map)
	if not world then return nil end
	local x, y = ns.OnMap(map, world, n0 + door.y * (n1 - n0), w0 + door.x * (w1 - w0))
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function Dungeons(map)
	local stood = {}        -- the dungeons the game's own entrances stand for
	for _, door in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(map) or {}) do
		local pin = Take("dungeons", "PIN_FRAME_LEVEL_AREA_POI")
		if door.atlasName and Atlas(pin, door.atlasName) then
			pin.text = door.description ~= "" and door.description or nil
			pin.low, pin.high = DungeonLevels(door)
			-- (The journal's dungeon of that name: a click goes in.)
			pin.dungeon = ns.Dungeons and ns.Dungeons.ByName and ns.Dungeons.ByName(door.name) or nil
			if pin.dungeon then stood[pin.dungeon] = true end
			if pin.dungeon and not pin.low then
				local one = Shy.Instances.ByMap(pin.dungeon)
				pin.low, pin.high = one.low, one.high
			end
			Put(pin, door.position, door.name)
		end
	end
	-- Every other dungeon the journal has, at its door: the game's swirling sign of a way in, a dungeon's or a
	-- raid's, bright for one at your level.
	local J, journal = ns.Dungeons, ns.Journal
	if not (J and journal and journal.Door) then return end
	local level = UnitLevel("player")
	for _, one in ipairs(J.List()) do
		local door = not stood[one.map] and journal.Door(one.map)
		local x, y
		if door then x, y = Spot(map, door) end
		if x then
			local pin = Take("doors", "PIN_FRAME_LEVEL_AREA_POI")
			if not pin.portal then
				-- (The swirl turns about its middle: slowly, and quicker while the mouse is on it.)
				pin.portal = pin.icon:CreateAnimationGroup()
				pin.portal:SetLooping("REPEAT")
				pin.portal.turn = pin.portal:CreateAnimation("Rotation")
				pin.portal.turn:SetDegrees(-360)
				pin.portal.turn:SetDuration(DOOR.turn)
				pin:HookScript("OnEnter", function(self)
					if self.portal then self.portal.turn:SetDuration(DOOR.quick) end
				end)
				pin:HookScript("OnLeave", function(self)
					if self.portal then self.portal.turn:SetDuration(DOOR.turn) end
				end)
			end
			pin.icon:SetAtlas(DOOR.sign[one.kind] or DOOR.sign.dungeon)
			pin.icon:SetSize(DOOR.size, DOOR.size)
			pin.icon:Show()
			pin:SetSize(DOOR.size, DOOR.size)
			pin.dungeon, pin.low, pin.high, pin.name = one.map, one.low, one.high, one.name
			local yours = level >= one.low and (one.high == 0 or level <= one.high)
			local light = yours and 1 or DOOR.pale
			pin.icon:SetVertexColor(light, light, light, 1)
			pin.icon:SetDesaturated(not yours)
			pin.portal:Play()
			View.Stand(pin, x, y)
		end
	end
end

local function Points(map)
	for _, id in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(map) or {}) do
		local info = C_AreaPoiInfo.GetAreaPOIInfo(map, id)
		if info then
			local pin = Take("places", "PIN_FRAME_LEVEL_AREA_POI")
			local drawn = false
			if info.atlasName then
				drawn = Atlas(pin, info.atlasName)
			elseif info.textureIndex then
				local x1, x2, y1, y2 = C_Minimap.GetPOITextureCoords(info.textureIndex)
				if x1 then
					pin.icon:SetTexture("Interface\\Minimap\\POIIcons")
					pin.icon:SetTexCoord(x1, x2, y1, y2)
					pin.icon:SetSize(POI, POI)
					pin:SetSize(POI, POI)
					drawn = true
				end
			end
			if drawn then
				pin.text = info.description ~= "" and info.description or nil
				pin.link = info.linkedUiMapID
				Put(pin, info.position, info.name)
			end
		end
	end
end

local function Links(map)
	for _, link in ipairs(C_Map.GetMapLinksForMap(map) or {}) do
		local pin = Take("links", "PIN_FRAME_LEVEL_MAP_LINK")
		if link.atlasName and Atlas(pin, link.atlasName) then
			pin.link = link.linkedUiMapID
			Put(pin, link.position, link.name)
		end
	end
end

-- Where a guard or a city's official pointed you: the one place the game marks for the map shown
-- (the answer to "What do you need directions to?"), drawn from the minimap's icon sheet.
local function Directions(map)
	local id = C_GossipInfo.GetPoiForUiMapID(map)
	local info = id and C_GossipInfo.GetPoiInfo(map, id)
	if not info then return end
	local x1, x2, y1, y2 = C_Minimap.GetPOITextureCoords(info.textureIndex)
	if not x1 then return end
	local pin = Take("directions", "PIN_FRAME_LEVEL_ACTIVE_QUEST")
	pin.icon:SetTexture("Interface\\Minimap\\POIIcons")
	pin.icon:SetTexCoord(x1, x2, y1, y2)
	pin.icon:SetSize(DIRECTIONS, DIRECTIONS)
	pin:SetSize(DIRECTIONS, DIRECTIONS)
	local x, y = info.position:GetXY()
	pin.goal = { map = map, x = x, y = y, name = info.name }
	Put(pin, info.position, info.name)
end

local KINDS = {
	{ key = "directions", fill = Directions },
	{ key = "flights", fill = Flights },
	{ key = "dungeons", fill = Dungeons },
	{ key = "places", fill = Points },
	{ key = "links", fill = Links },
}

local function Refresh()
	local map = View.Map()
	wipe(shown)
	if map and View.IsOpen() then
		local hideIcons = C_Map.GetMapDisplayInfo(map)
		if not hideIcons then
			for _, kind in ipairs(KINDS) do
				if T.db[kind.key] then
					local ok, err = pcall(kind.fill, map)
					if not ok then geterrorhandler()(err) end
				end
			end
		end
	end
	for kind, pool in pairs(pools) do
		for i = (shown[kind] or 0) + 1, #pool do pool[i]:Hide() end
	end
end

local function Restand()
	for kind, pool in pairs(pools) do
		for i = 1, shown[kind] or 0 do
			local pin = pool[i]
			if pin:IsShown() then View.Stand(pin, pin.x, pin.y) end
		end
	end
end

ns.Layer({
	id = "places",
	later = true,
	Map = Refresh,
	Scale = Restand,
	Use = function(on) if not on then Refresh() end end,
})

ns.OnApply(function()
	if View.IsOpen() then Refresh() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
events:RegisterEvent("AREA_POIS_UPDATED")
events:RegisterEvent("DYNAMIC_GOSSIP_POI_UPDATED")

-- A choice picked in a talk (the guard's list of places among them) is what a new marked place answers.
local askedAt = 0
local function Asked() askedAt = GetTime() end
hooksecurefunc(C_GossipInfo, "SelectOption", Asked)
hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", Asked)

-- The talk shows itself again after a choice and would cover the map. So the map waits on the talk's own
-- events: a marked place waits for the talk to come back (GOSSIP_SHOW), which ends it, and the map opens
-- once the talk is closed (GOSSIP_CLOSED).
local toOpen, toOpenAt
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("GOSSIP_CLOSED")
events:SetScript("OnEvent", function(_, event)
	if event == "GOSSIP_SHOW" or event == "GOSSIP_CLOSED" then
		local map = toOpen
		if map and GetTime() - toOpenAt > ASKED then
			toOpen = nil
			map = nil
		end
		if not map then return end
		if event == "GOSSIP_SHOW" then
			C_GossipInfo.CloseGossip()
		else
			toOpen = nil
			Shy.Maps.Open(map)
		end
		return
	end
	if event == "DYNAMIC_GOSSIP_POI_UPDATED" and T.db.directions and T.db.on
		and GetTime() - askedAt <= ASKED and not InCombatLockdown() then
		local map = C_Map.GetBestMapForUnit("player")
		local id = map and C_GossipInfo.GetPoiForUiMapID(map)
		local info = id and C_GossipInfo.GetPoiInfo(map, id)
		if info then
			askedAt = 0
			toOpen, toOpenAt = map, GetTime()
			-- Asking the way is going there: the arrow leads at once.
			local x, y = info.position:GetXY()
			Track({ map = map, x = x, y = y, name = info.name })
		end
	end
	if View.IsOpen() then Refresh() end
end)
