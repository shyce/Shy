-- On a continent, each zone's name over its middle with its levels under it, the levels in the color
-- they are against yours; on the terrain look, the seas' and the continents' names too. Names never sit on one another: where two would touch at this zoom, the larger
-- zone's stands (yours before any) and the other waits, fading in once the zoom makes room. The zone
-- under the mouse lights its own name and the rest dim. Labels take no mouse: a click still goes into
-- the zone.

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local C = UI.colors

local Labels = {}
ns.Labels = Labels

local WIDE, TALL = 150, 30
local NAME, LEVELS = 12, 10     -- font sizes
local ROOM = 4                  -- port units kept clear round each name
local HALO_W, HALO_H = 34, 20   -- the dark halo past the words
local HALO = 0.5
local REST = 0.92               -- a name's light at rest
local DIM = 0.4                 -- ... while another zone is under the mouse
local SPEED = 10

local labels = {}
local shown = 0
local lit                       -- the zone whose name is lit

local function Label(i)
	local label = labels[i]
	if label then return label end
	label = CreateFrame("Frame", nil, View.Canvas())
	label:SetSize(WIDE, TALL)
	label:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_ZONE_NAMES"))
	label:EnableMouse(false)
	label.halo = label:CreateTexture(nil, "BACKGROUND")
	label.halo:SetTexture(Shy.MEDIA .. "Glow")
	label.halo:SetVertexColor(0, 0, 0, HALO)
	label.name = UI.Words(label, UI.NameFont(NAME))
	label.name:SetPoint("BOTTOM", label, "CENTER", 0, 0)
	label.levels = UI.Words(label, UI.TextFont(LEVELS))
	label.levels:SetPoint("TOP", label.name, "BOTTOM", 0, -1)
	label.alpha, label.want = 0, 0
	label:SetAlpha(0)
	label:Hide()
	labels[i] = label
	return label
end

-- The zones of a continent: { mapID, name, x, y (its middle, shares), area (shares), low, high }.
local zones = {}
function Labels.Zones(map)
	local known = zones[map]
	if known then return known end
	known = {}
	local info = C_Map.GetMapInfo(map)
	if info and info.mapType == Enum.UIMapType.Continent then
		for _, child in ipairs(C_Map.GetMapChildrenInfo(map, Enum.UIMapType.Zone) or {}) do
			local x1, x2, y1, y2 = C_Map.GetMapRectOnMap(child.mapID, map)
			if x1 and x2 and y1 and y2 and x2 > x1 and y2 > y1 then
				local low, high = C_Map.GetMapLevels(child.mapID)
				known[#known + 1] = { mapID = child.mapID, name = child.name, x = (x1 + x2) / 2, y = (y1 + y2) / 2,
					area = (x2 - x1) * (y2 - y1), low = low, high = high }
			end
		end
	end
	zones[map] = known
	return known
end

-- The zone of the map shown that you are in (a city counts as itself), or nil.
local function Yours(list)
	local id, guard = C_Map.GetBestMapForUnit("player"), 0
	while id and id > 0 and guard < 8 do
		for _, zone in ipairs(list) do if zone.mapID == id then return id end end
		local info = C_Map.GetMapInfo(id)
		id, guard = info and info.parentMapID, guard + 1
	end
	return nil
end

-- A zone of the map shown has its name on it.
function Labels.Has(id)
	for i = 1, shown do if labels[i].mapID == id then return true end end
	return false
end

-- Which names have room at this zoom: in order (yours, then the larger zones), each that touches none
-- already standing.
local boxes = {}
local function Room()
	local grow = View.Grow()
	local n = 0
	for i = 1, shown do
		local label = labels[i]
		local px, py = View.ToPort(label.x, label.y)
		local half = (label.wide / 2) * grow + ROOM
		local top, bottom = py - (NAME + 2) * grow - ROOM, py + (label.leveled and LEVELS + 2 or 0) * grow + ROOM
		local free = true
		for j = 1, n, 4 do
			if px - half < boxes[j + 1] and px + half > boxes[j] and top < boxes[j + 3] and bottom > boxes[j + 2] then
				free = false
				break
			end
		end
		label.want = free and 1 or 0
		if free then
			boxes[n + 1], boxes[n + 2], boxes[n + 3], boxes[n + 4] = px - half, px + half, top, bottom
			n = n + 4
		end
	end
end

local function Refresh()
	local map = View.Map()
	for i = 1, #labels do
		labels[i]:Hide()
		labels[i].alpha, labels[i].mapID = 0, nil
	end
	shown = 0
	if not (map and View.IsOpen() and T.db.zones) then return end
	local list = {}
	for _, zone in ipairs(Labels.Zones(map)) do list[#list + 1] = zone end
	local yours = Yours(list)
	table.sort(list, function(a, b)
		if (a.mapID == yours) ~= (b.mapID == yours) then return a.mapID == yours end
		return a.area > b.area
	end)
	for _, zone in ipairs(list) do
		shown = shown + 1
		local label = Label(shown)
		label.mapID = zone.mapID
		label.name:SetText(zone.name)
		UI.Ink(label.name, C.text)
		local levels, color = ns.Levels(zone.low, zone.high)
		label.levels:SetText(levels or "")
		if color then label.levels:SetTextColor(color.r, color.g, color.b) end
		local wide = math.max(label.name:GetStringWidth(), label.levels:GetStringWidth())
		-- (Measured once here: Room asks it at every step of a zoom.)
		label.wide, label.leveled = wide, levels ~= nil
		label.halo:ClearAllPoints()
		label.halo:SetPoint("CENTER", label, "CENTER", 0, levels and -2 or NAME / 2)
		label.halo:SetSize(wide + HALO_W, (levels and NAME + LEVELS + 2 or NAME) + HALO_H)
		label:SetAlpha(0)
		View.Stand(label, zone.x, zone.y)
	end
	lit = nil
	Room()
end

-- The open water's names on the terrain look, whose ground has no lettering of its own: on a continent each sea
-- off it (Data/Seas.lua: where it is furthest from land, nearest its own coast), on the world's map each continent
-- over its middle. A continent's name stands on the ground's own frame, which stays while the bare world fades
-- everything else.
local WATER = { sea = 13, continent = 20, alpha = 0.85 }
local waters, wet = {}, 0

local function Water(i)
	local label = waters[i]
	if label then return label end
	label = CreateFrame("Frame", nil, View.Canvas())
	label:SetSize(WIDE, TALL)
	label:EnableMouse(false)
	label.halo = label:CreateTexture(nil, "BACKGROUND")
	label.halo:SetTexture(Shy.MEDIA .. "Glow")
	label.halo:SetVertexColor(0, 0, 0, HALO)
	label.halo:SetPoint("CENTER")
	label.name = label:CreateFontString(nil, "OVERLAY")
	label.name:SetShadowOffset(1, -1)
	label.name:SetShadowColor(0, 0, 0, 1)
	label.name:SetPoint("CENTER")
	waters[i] = label
	return label
end

local function PutWater(text, x, y, continent)
	if not (text and x and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
	wet = wet + 1
	local label = Water(wet)
	label:SetParent(continent and View.Land() or View.Canvas())
	label:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_ZONE_NAMES"))
	label.name:SetFontObject(UI.NameFont(continent and WATER.continent or WATER.sea))
	Shy.Theme.Wear(label.name)   -- (a font object brings its own shadow: the text effect again)
	label.name:SetText(text)
	UI.Ink(label.name, continent and C.text or C.dim)
	label.halo:SetSize(label.name:GetStringWidth() + HALO_W, (continent and WATER.continent or WATER.sea) + HALO_H)
	label:SetAlpha(WATER.alpha)
	View.Stand(label, x, y)
end

local function Waters()
	for i = 1, wet do waters[i]:Hide() end
	wet = 0
	local map = View.Map()
	if not (map and View.IsOpen() and T.db.zones and ns.Terrain and ns.Terrain.Draws(map)) then return end
	local joined = ns.Terrain.Joined(map)
	if joined then
		for _, entry in ipairs(joined) do
			local info = C_Map.GetMapInfo(entry.continent)
			local x1, x2, y1, y2 = C_Map.GetMapRectOnMap(entry.continent, map)
			if info and x1 and x2 and y1 and y2 then PutWater(info.name, (x1 + x2) / 2, (y1 + y2) / 2, true) end
		end
		return
	end
	local info = C_Map.GetMapInfo(map)
	local world = View.World(map)
	if not (info and info.mapType == Enum.UIMapType.Continent and world and ns.seas and ns.seas[world]) then return end
	for _, sea in ipairs(ns.seas[world]) do
		PutWater(sea[1], ns.OnMap(map, world, sea[2], sea[3]))
	end
end

-- The open water's names standing: their frames.
function Labels.Waters()
	local list = {}
	for i = 1, wet do list[i] = waters[i] end
	return list
end

local function Restand()
	for i = 1, shown do
		local label = labels[i]
		View.Stand(label, label.x, label.y)
		label:SetShown(label.alpha > 0.005)
	end
	for i = 1, wet do View.Stand(waters[i], waters[i].x, waters[i].y) end
	Room()
end

local function Ease(now, goal, dt)
	if math.abs(now - goal) < 0.005 then return goal end
	return goal + (now - goal) * math.exp(-dt * SPEED)
end

local function Tick(dt)
	if shown == 0 then return end
	local hovered = ns.Nav and ns.Nav.Hovered and ns.Nav.Hovered() or nil
	if hovered ~= lit then
		lit = hovered
		for i = 1, shown do UI.Ink(labels[i].name, labels[i].mapID == lit and C.head or C.text) end
	end
	for i = 1, shown do
		local label = labels[i]
		local goal = label.want * REST
		if lit then goal = label.mapID == lit and 1 or goal * DIM end
		if label.alpha ~= goal then
			label.alpha = Ease(label.alpha, goal, dt)
			label:SetAlpha(label.alpha)
			label:SetShown(label.alpha > 0.005)
		end
	end
end

local function Lay()
	Refresh()
	Waters()
end

ns.Layer({
	id = "zones",
	later = true,
	Map = Lay,
	Scale = Restand,
	Tick = Tick,
	Use = function(on) if not on then Lay() end end,
})

ns.OnApply(function()
	if View.IsOpen() then Lay() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function()
	-- (The level comes with the event; the colors are read from the unit a moment later.)
	C_Timer.After(0.2, function() if View.IsOpen() then Refresh() end end)
end)
