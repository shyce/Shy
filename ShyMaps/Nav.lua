-- Getting about: a click into the zone under the mouse, a right click out a step (zoomed in, to the whole
-- of the map shown; from the whole of it, to the map round it), a pin
-- dropped with Ctrl (or the game's pin button, or the bar's share button: Nav.PinNext), the zone under the
-- mouse lit with its name and levels,
-- and the breadcrumb, after the side switch (World | Dungeons, Sides.lua) that leads its row: the maps from the
-- world down to the one shown, each a split button (its words go
-- there, its caret lists the maps in it; on a map of floors, the last one lists the floors). The
-- game's own breadcrumb and floor list are faded under ours while the view is in use.

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local C = UI.colors

local Nav = {}
ns.Nav = Nav

local LOOK = 0.05           -- seconds between looks under the mouse
local LIT = 0.7             -- the hovered zone's light at its fullest
local LIGHT_SPEED = 14
local CRUMB_FONT = 11
local CRUMB_INSET = 7       -- a crumb's words from its left edge
local CRUMB_TALL = 20
local CRUMB_Y = -5          -- the crumbs' line against the middle of the game's breadcrumb
local CRUMB_CARET = 1
local SLASH = 10            -- room for the slash between two crumbs
local SLASH_X = 0.5         -- nudged right: a crumb's words begin CRUMB_INSET in from its edge but end 6 short of it
local LABEL_Y = -14         -- the hovered place's name, under the map's top edge

local highlight, hl         -- the lit zone's frame and texture
local label                 -- the name over the map
local litAlpha, litWant = 0, 0
local labelAlpha, labelWant = 0, 0
local lookIn = 0
local cursorPin = false

-- Placing a pin

local function PinButton()
	return WorldMapFrame and WorldMapFrame.WorldMapTrackingPinButton
end

-- (Nav.PinNext: the next click on the map drops the pin, asked for from the bar's share button.)
local pinNext = false

-- (Nav.Next(fn): the next click on the map is fn(map, x, y)'s instead, a note put down.)
local nextClick

local function CanPin()
	if nextClick then return true end
	if C_GameRules.IsGameRuleActive(Enum.GameRule.WorldMapTrackingPinDisabled) then return false end
	local button = PinButton()
	return pinNext or (button and button.isActive == true) or IsControlKeyDown()
end

function Nav.Next(fn)
	nextClick = fn
end

function Nav.PinNext(on)
	pinNext = on ~= false and not C_GameRules.IsGameRuleActive(Enum.GameRule.WorldMapTrackingPinDisabled)
	return pinNext
end

-- Whether the next click on the map drops the pin (Nav.PinNext).
function Nav.Pinning() return pinNext end

local function DropPin(map, x, y)
	pinNext = false
	if C_Map.CanSetUserWaypointOnMap(map) then
		local button = PinButton()
		PlaySound((button and button.isActive) and SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE or SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK)
		Shy.Waypoint.Set(map, x, y, false)
	else
		UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA())
	end
end

-- Going somewhere

local ZOOMED = 1.15         -- times its whole size from which the map shown counts as zoomed in: a right click
                            -- then goes out to the whole of it, not yet to the map round it
local HOLD = 1.4            -- seconds the name of a map gone to stays up once there, the mouse kept still
local STILL = 6             -- screen pixels the mouse may move from where it clicked and still be kept still
local holdUntil = 0
local heldX, heldY = 0, 0   -- where the mouse clicked to go there

-- The name of a map gone to stands while it flies there, and a moment after while the mouse stays put;
-- moved, the hover answers at once.
local function Held()
	if View.Flying() then return true end
	if GetTime() >= holdUntil then return false end
	local x, y = GetCursorPosition()
	local still = STILL * UIParent:GetEffectiveScale()
	if (x - heldX) ^ 2 + (y - heldY) ^ 2 <= still * still then return true end
	holdUntil = 0
	return false
end
local hovered               -- the map under the mouse, inside the one shown

-- The map round one, as a right click goes out to it: a city's zone, a zone's continent, the world's map.
function Nav.Up(map)
	local up = ns.Steps and ns.Steps.Up(map)
	if up then return up end
	local info = C_Map.GetMapInfo(map)
	local parent = info and info.parentMapID
	return parent and parent > 0 and parent or nil
end

-- The map a click at x, y of `map` goes to (shares, past its edges too): one inside it as the game has it
-- (a zone on a continent, a continent on the world), a city on its zone's map (a city's map lies on the
-- continent, so the zone's doesn't hand it over), or, on a zone's or city's map, the zone or city its
-- continent has there (the land drawn round it). Also the map whose highlight art lights it, and x, y on
-- that map; nil for none.
--
-- (Over a zone's own art the game also names a zone beside it whose ground the art shows; its highlight
-- isn't the zone's to light, so that one is told from the continent like the land past the art's edge.)
local function Within(id, map)
	local info, guard = C_Map.GetMapInfo(id), 0
	while info and guard < 8 do
		local parent = info.parentMapID
		if parent == map then return true end
		info = parent and parent > 0 and C_Map.GetMapInfo(parent) or nil
		guard = guard + 1
	end
	return false
end

local function Inside(map, x, y)
	local on = x >= 0 and x <= 1 and y >= 0 and y <= 1
	if on then
		local info = C_Map.GetMapInfoAtPosition(map, x, y)
		local id = info and info.mapID
		if id and id ~= map and C_Map.MapHasArt(id) and Within(id, map) then return id, map, x, y end
	end
	local kind = C_Map.GetMapInfo(map)
	local world, n0, w0, n1, w1 = View.World(map)
	if not (world and ns.Steps and kind and kind.mapType == Enum.UIMapType.Zone) then return nil end
	if on then
		local north, west = n0 + y * (n1 - n0), w0 + x * (w1 - w0)
		for _, city in ipairs(ns.Steps.Cities(map)) do
			local there, c0, v0, c1, v1 = View.World(city)
			if there == world then
				local cx, cy = (west - v0) / (v1 - v0), (north - c0) / (c1 - c0)
				if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then return city end
			end
		end
	end
	local there, continent, cx, cy = ns.Steps.At(map, x, y)
	if not there or there == map or not C_Map.MapHasArt(there) then return nil end
	-- The continent's highlight is a zone's own; a city takes none.
	local drawn = C_Map.GetMapInfoAtPosition(continent, cx, cy)
	if drawn and drawn.mapID == there then return there, continent, cx, cy end
	return there
end

local Say, Levels, SayZone

-- Goes to the whole of map `target` in one move (View.Fly): within its world straight there, onto a map
-- lying on the one shown over where it lies, and out to the world's map round a continent drawn out from
-- where the continent lies on it. Its name stands over the map on the way and a moment after.
function Nav.Go(target)
	local map = View.Map()
	if not (map and target and C_Map.MapHasArt(target)) then return false end
	if target == map then return View.Fly(map) end
	local world = View.World(map)
	local same = world ~= nil and world == View.World(target)
	-- (The terrain look's world's map, its continents side by side, is stepped onto and off in place.)
	local out = ns.Terrain ~= nil and ns.Terrain.Joined(target) ~= nil
	local joined = out or (ns.Terrain ~= nil and ns.Terrain.Joined(map) ~= nil)
	local function Landed()
		holdUntil = GetTime() + HOLD
		if View.Map() == target then return end
		if (same or joined) and View.Rebase(target) then return end
		if not same then View.Show(target, "into") end
	end
	-- Out to the world's map: it takes over where the map left lies on it, and is flown out to the whole.
	if out then View.Rebase(target) end
	local gone = View.Fly(target, Landed)
	if not gone and View.Show(target, "out") then
		-- Out to the world's map, which lies in no world: shown where the map left lies on it, then flown
		-- out to the whole of it.
		gone = View.Fly(target, Landed)
	end
	-- (While it flies the hover waits on View.Flying(), and a moment more once it lands while the mouse
	-- stays where it clicked; a flight ended on the way, by a press or the wheel, hands the hover straight back.)
	if gone then
		local info = C_Map.GetMapInfo(target)
		heldX, heldY = GetCursorPosition()
		hovered = nil
		SayZone(target, info and info.name)
	end
	return gone
end

-- Clicks on bare map (the view hands them over)

function Nav.Click(button, x, y)
	local map = View.Map()
	if not map then return false end
	if button == "LeftButton" then
		if nextClick then
			if not x then return false end
			local fn = nextClick
			nextClick = nil
			fn(map, x, y)
			return true
		end
		if CanPin() then
			if not x then return false end
			DropPin(map, x, y)
			return true
		end
		-- Past the art's edge too: the land drawn round the map shown.
		if not x then x, y = View.Cursor(true) end
		if not x then return false end
		local inside = Inside(map, x, y)
		if inside then return Nav.Go(inside) end
	elseif button == "RightButton" then
		-- Out a step at a time: zoomed in on the map shown, to the whole of it first (the zone you stand in,
		-- zoomed in on you); from the whole of it, to the map round it.
		if View.Scale() > View.Fit() * ZOOMED then return Nav.Go(map) end
		local up = Nav.Up(map)
		if up then return Nav.Go(up) end
	end
	return false
end

-- The map under the mouse, inside the one shown (a zone on a continent); nil off one.
function Nav.Hovered() return hovered end

-- The place under the mouse

function Levels(map)
	local low, high = C_Map.GetMapLevels(map)
	return ns.Levels(low, high, true)
end

local function Build()
	local canvas, port = View.Canvas(), View.Port()
	highlight = CreateFrame("Frame", nil, canvas)
	highlight:SetAllPoints()
	highlight:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_MAP_HIGHLIGHT"))
	hl = highlight:CreateTexture(nil, "ARTWORK")
	hl:SetBlendMode("ADD")
	highlight:SetAlpha(0)

	label = CreateFrame("Frame", nil, View.Chrome())
	label:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 50)
	label:SetSize(400, 68)
	label:SetPoint("TOP", port, "TOP", 0, LABEL_Y)
	label.shade = label:CreateTexture(nil, "BACKGROUND")
	label.shade:SetTexture(Shy.MEDIA .. "Glow")
	label.shade:SetVertexColor(0, 0, 0, 0.55)
	label.name = label:CreateFontString(nil, "OVERLAY")
	UI.TitleFace(label.name, 20)
	label.name:SetPoint("TOP", 0, 0)
	label.levels = UI.Words(label, UI.TextFont(12))
	label.levels:SetPoint("TOP", label.name, "BOTTOM", 0, -2)
	label.fish = UI.Words(label, UI.TextFont(12))
	label:SetAlpha(0)
	label:EnableMouse(false)
end

function Say(name, levels, color, fish, fishColor)
	if not label then return end
	if not name then
		labelWant = 0
		return
	end
	labelWant = 1
	label.name:SetText(name)
	Shy.Theme.Ink(label.name, C.head)
	label.levels:SetText(levels or "")
	if color then label.levels:SetTextColor(color.r, color.g, color.b) end
	label.fish:SetText(fish or "")
	if fishColor then label.fish:SetTextColor(fishColor[1], fishColor[2], fishColor[3]) end
	label.fish:ClearAllPoints()
	label.fish:SetPoint("TOP", levels and label.levels or label.name, "BOTTOM", 0, -2)
	local wide = math.max(label.name:GetStringWidth(), label.levels:GetStringWidth(), label.fish:GetStringWidth())
	local under = (levels and 1 or 0) + (fish and 1 or 0)
	label.shade:ClearAllPoints()
	label.shade:SetPoint("CENTER", label.name, "BOTTOM", 0, -4 * under)
	label.shade:SetSize(wide + 120, 50 + 20 * under)
end

-- A zone's name over the map, with its levels and its waters for you.
function SayZone(map, name)
	if not (map and name) then return Say(name) end
	local levels, color = Levels(map)
	Say(name, levels, color, ns.Fishing(map))
end

-- Lights the zone at x, y of map `on` as the game does (its highlight art, carried to the canvas's size);
-- a zone round the map shown is lit from its continent, carried onto the map shown.
local function Light(on, x, y)
	local file, atlas, px, py, tx, ty, sx, sy = C_Map.GetMapHighlightInfoAtPosition(on, x, y)
	if not (file or atlas) or (file == 0 and not atlas) then
		litWant = 0
		return
	end
	local map = View.Map()
	local foreign = on ~= map
	if foreign then
		local _, n0, w0, n1, w1 = View.World(map)
		local _, N0, W0, N1, W1 = View.World(on)
		if not (n0 and N0) then
			litWant = 0
			return
		end
		local kx, ky = (W1 - W0) / (w1 - w0), (N1 - N0) / (n1 - n0)
		sx, sy = (W0 - w0) / (w1 - w0) + sx * kx, (N0 - n0) / (n1 - n0) + sy * ky
		tx, ty = tx * kx, ty * ky
	end
	local w, h = View.Size()
	hl:ClearAllPoints()
	hl:SetTexCoord(0, px, 0, py)
	if atlas and foreign then
		hl:SetAtlas(atlas, false, "TRILINEAR")
		hl:SetSize(tx * w, ty * h)
		hl:SetPoint("TOPLEFT", highlight, "TOPLEFT", sx * w, -sy * h)
	elseif atlas then
		hl:SetAtlas(atlas, true, "TRILINEAR")
		hl:SetPoint("CENTER", highlight, "CENTER", ((sx + 0.5 * tx) - 0.5) * w, -((sy + 0.5 * ty) - 0.5) * h)
	else
		hl:SetTexture(file, nil, nil, "TRILINEAR")
		hl:SetSize(tx * w, ty * h)
		hl:SetPoint("TOPLEFT", highlight, "TOPLEFT", sx * w, -sy * h)
	end
	local light = Shy.Theme.light
	hl:SetVertexColor(0.55 + light[1] * 0.45, 0.55 + light[2] * 0.45, 0.55 + light[3] * 0.45, 1)
	litWant = LIT
end

-- A zone seen from afar (on a continent's map, or the world's) has a card by the mouse: its name, its levels
-- and what you have to do there, as ShyQuest tells it (its ZoneSummary: the route's stops in that zone and
-- the quests waiting there). A zone with nothing to do has none: the name over the map says it as ever.
-- card.zone: the zone last asked about (asked once, not at every look); card.up: its card is up.
local card = { up = false }
local function Card(zone)
	if zone == card.zone then return card.up end
	card.zone = zone
	local port = View.Port()
	local quest = zone and Shy.addons.Quest
	local rows = quest and quest.ZoneSummary and quest:ZoneSummary(zone)
	local info = rows and #rows > 0 and C_Map.GetMapInfo(zone)
	if not info then
		-- (At once: a card left up would stand over the map being flown to.)
		if card.up then Shy.Hover.Hide(port, true) end
		card.up = false
		return false
	end
	card.up = true
	local fish, fishColor = ns.Fishing(zone)
	if fish then
		local all = { unpack(rows) }
		all[#all + 1] = { text = fish, color = fishColor }
		rows = all
	end
	Shy.Hover.Show(port, { title = info.name, sub = Levels(zone), sections = { { rows = rows } } }, { side = "CURSOR", keep = false })
	return true
end

-- A continent's map, or the world's: where a zone is one of many.
local function Far(map)
	local info = C_Map.GetMapInfo(map)
	return info ~= nil and info.mapType <= Enum.UIMapType.Continent
end

local function Look()
	local map = View.Map()
	local port = View.Port()
	local bare = port:IsMouseMotionFocus()
	local x, y
	if bare and not View.Busy() then x, y = View.Cursor(true) end
	local onArt = x and x >= 0 and x <= 1 and y >= 0 and y <= 1
	-- The game's pin cursor while a click would drop a pin.
	local pinning = bare and CanPin() or false
	if pinning ~= cursorPin then
		cursorPin = pinning
		if pinning then SetCursor("MAP_PIN_CURSOR") else ResetCursor() end
	end
	-- On the way somewhere, and a moment after: its name stays, the zone clicked stays lit.
	if Held() then
		Card(nil)
		return
	end
	hovered = nil
	if not (map and x) then
		Card(nil)
		if not bare or not View.Busy() then
			litWant = 0
			Say(nil)
		end
		return
	end
	local inside, on, lx, ly = Inside(map, x, y)
	if inside then
		hovered = inside
		if on then Light(on, lx, ly) else litWant = 0 end
		-- From afar its card says its name; a zone named on the map lights its own name; the name over the
		-- map is for the rest.
		if Card(Far(map) and inside or nil) or (ns.Labels and ns.Labels.Has(inside)) then
			Say(nil)
		else
			local info = C_Map.GetMapInfo(inside)
			SayZone(inside, info and info.name)
		end
		return
	end
	Card(nil)
	litWant = 0
	if not onArt then
		-- Past the zone's edge on the terrain look: the zone the ground there is in.
		local zone = ns.Terrain and ns.Terrain.Covers(map) and ns.Terrain.ZoneAt(map, x, y)
		SayZone(zone and zone.mapID, zone and zone.name)
		return
	end
	local areas = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(map, CreateVector2D(x, y))
	local name = areas and areas[1] and C_Map.GetAreaInfo(areas[1])
	Say(name ~= "" and name or nil)
end

local function Ease(now, goal, dt)
	if math.abs(now - goal) < 0.01 then return goal end
	return goal + (now - goal) * math.exp(-dt * LIGHT_SPEED)
end

-- The breadcrumb

local row, more           -- our breadcrumb over the game's, and its overflow button
local sides               -- the side switch at the row's left (Sides.lua)
local SIDES_GAP = 6       -- from it to the first crumb
local crumbs = {}         -- pooled split buttons
local slashes = {}
local floorShield         -- over the game's floor list while it shows and ours stands in for it

local function Kids(map)
	local list = {}
	for _, child in ipairs(C_Map.GetMapChildrenInfo(map) or {}) do
		if C_Map.IsMapValidForNavBarDropdown(child.mapID) then list[#list + 1] = child end
	end
	-- A zone's cities, whose maps the game keeps on the continent.
	local info = C_Map.GetMapInfo(map)
	if ns.Steps and info and info.mapType == Enum.UIMapType.Zone then
		for _, city in ipairs(ns.Steps.Cities(map)) do
			local kid = C_Map.GetMapInfo(city)
			if kid then list[#list + 1] = kid end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local function Floors(map)
	local group = C_Map.GetMapGroupID(map)
	return group and C_Map.GetMapGroupMembersInfo(group) or nil
end

-- The maps from the top (the world) down to `map`, each the one a right click goes out to (a city's is
-- its zone).
local function Chain(map)
	local chain, id = {}, map
	while id and id > 0 and #chain < 8 do
		local info = C_Map.GetMapInfo(id)
		if not info then break end
		table.insert(chain, 1, info)
		if info.mapType <= Enum.UIMapType.World then break end
		id = Nav.Up(id)
	end
	return chain
end

-- A crumb measured again (its face loaded after it was first laid, or another chosen) grows or shrinks: the row is
-- laid again on the next frame, once however many did, so none stands over the next.
local Lay
local laying = false
local function LaySoon()
	if laying then return end
	laying = true
	C_Timer.After(0, function()
		laying = false
		if Lay then Lay() end
	end)
end

local function Crumb(i)
	local b = crumbs[i]
	if b then return b end
	b = UI.SplitButton(row, { font = UI.NameFont(CRUMB_FONT), height = CRUMB_TALL, inset = CRUMB_INSET, caretY = CRUMB_CARET,
		write = function(root) if b.write then b.write(root) end end })
	-- Its words: the map shown bright, those above it dim, the hover color while a click on them would go there.
	local look = b.OnLook
	function b:OnLook(s)
		look(self, s)
		local color = self.rest or C.dim
		if s.on then
			color = C.text
		elseif s.over and not (s.tail and self.act) then
			color = C.hot
		end
		UI.Ink(self.text, color)
		if self.icon then UI.Tint(self.icon, color) end
	end
	b:HookScript("OnSizeChanged", LaySoon)
	crumbs[i] = b
	return b
end

local function Slash(i)
	local text = slashes[i]
	if not text then
		text = UI.Words(row, UI.NameFont(CRUMB_FONT), Shy.Skin.colors.idle)
		text:SetText("/")
		slashes[i] = text
	end
	return text
end

-- The terrain look: the middle of the view off the zone's own ground.
local function Astray()
	local cx, cy = View.Center()
	return ns.Terrain and ns.Terrain.Covers(View.Map()) and (cx < 0 or cx > 1 or cy < 0 or cy > 1) or false
end

local function Fill(b, info, here, map)
	local kids = Kids(info.mapID)
	local floors = here and Floors(map)
	local terrain = here and ns.Terrain and ns.Terrain.Covers(map)
	b.rest = here and C.text or C.dim
	if terrain then
		-- The world goes on: the zones in view, to snap to one.
		b.write = function(root)
			root:CreateTitle("Snap to")
			for _, zone in ipairs(ns.Terrain.Nearby()) do
				root:CreateRadio(zone.name, function() return View.Map() == zone.mapID and not Astray() end, function()
					Nav.Go(zone.mapID)
				end)
			end
		end
	elseif floors and #floors > 1 then
		b.write = function(root)
			for _, floor in ipairs(floors) do
				root:CreateRadio(floor.name, function() return View.Map() == floor.mapID end, function() View.Show(floor.mapID) end)
			end
		end
	else
		b.write = function(root)
			local shown = View.Map()
			for _, kid in ipairs(kids) do
				root:CreateRadio(kid.name, function() return shown == kid.mapID end, function() Nav.Go(kid.mapID) end)
			end
		end
	end
	b:SetAction(not here and function() Nav.Go(info.mapID) end or nil)
	b:SetChoices(terrain or (floors and #floors > 1) or #kids > 0)
	-- The world's crumb wears the globe before its words.
	-- (Where the side switch leads the row, its globe stands just before these words already.)
	b:SetIcon(not (sides and sides:IsShown()) and info.mapType <= Enum.UIMapType.World and Shy.MEDIA .. "GlyphGlobeS" or nil)
	local name = info.name
	if terrain and Astray() then name = "Near " .. name end
	if here and floors and #floors > 1 then
		for _, floor in ipairs(floors) do
			if floor.mapID == map then name = info.name ~= floor.name and (info.name .. ": " .. floor.name) or floor.name end
		end
	end
	b:SetLabel(name)
	b:OnLook(b.shyPress)
end

function Lay()
	if not row then return end
	for _, b in ipairs(crumbs) do b:Hide() end
	for _, text in ipairs(slashes) do text:Hide() end
	more:Hide()
	local map = View.Map()
	if not map then return end
	local chain = Chain(map)
	for i, info in ipairs(chain) do
		local b = Crumb(i)
		Fill(b, info, i == #chain, map)
	end
	-- The crumbs that don't fit go into the overflow ("..."), in this order, the first way that fits: those just
	-- over the map shown, one by one on toward the continent ("Azeroth / Eastern Kingdoms / ... / Stormwind City",
	-- the city's zone in the overflow); then the world too ("... / Eastern Kingdoms / Stormwind City": where you
	-- are on which continent reads before the world's name); then the continent, the world kept; then all but the
	-- map shown. The overflow stands where the first crumb it holds would. (They begin after the side switch.)
	local lead = sides and sides:IsShown() and sides:GetWidth() + SIDES_GAP or 0
	local room = row:GetWidth() - lead
	local n = #chain
	local function Fold(list)
		local folded = {}
		for _, i in ipairs(list) do folded[i] = true end
		return folded
	end
	local function Range(a, b, also)
		local list = { also }
		for i = a, b do list[#list + 1] = i end
		return list
	end
	local ways = { {} }
	for from = n - 1, 3, -1 do ways[#ways + 1] = Range(from, n - 1) end
	if n > 2 then ways[#ways + 1] = Range(3, n - 1, 1) end
	ways[#ways + 1] = Range(2, n - 1)
	ways[#ways + 1] = Range(1, n - 1)
	-- What stands in the row for a way: the crumbs and the overflow, in order.
	local function Row(folded)
		local list, holding = {}, false
		for i = 1, n do
			if folded[i] then
				if not holding then list[#list + 1] = more end
				holding = true
			else
				list[#list + 1] = crumbs[i]
			end
		end
		return list
	end
	local folded, shown
	for _, way in ipairs(ways) do
		folded = Fold(way)
		shown = Row(folded)
		local total = 0
		for index, frame in ipairs(shown) do total = total + (index > 1 and SLASH or 0) + frame:GetWidth() end
		if total <= room then break end
	end
	local x, slash = lead, 0
	local function Put(frame)
		if x > lead then
			slash = slash + 1
			local text = Slash(slash)
			text:ClearAllPoints()
			text:SetPoint("CENTER", row, "LEFT", x + SLASH / 2 + SLASH_X, CRUMB_Y)
			text:Show()
			x = x + SLASH
		end
		frame:ClearAllPoints()
		frame:SetPoint("LEFT", row, "LEFT", x, CRUMB_Y)
		frame:Show()
		x = x + frame:GetWidth()
	end
	more.hidden = nil
	for i = 1, n do
		if folded[i] then
			more.hidden = more.hidden or {}
			more.hidden[#more.hidden + 1] = chain[i]
		end
	end
	for _, frame in ipairs(shown) do Put(frame) end
end

-- A button added to the bar (Controls.lua): the breadcrumb stops short of it.
function ns.BarRoomChanged()
	if not row then return end
	row:SetPoint("BOTTOMRIGHT", View.Strip(), "BOTTOMRIGHT", -ns.BarRoom(), 0)
end

-- The view moved into our window or back: the crumbs go with it, to the strip of the window holding it. (In ours
-- the side switch stands down: the journal turns over the game's window alone.)
View.OnHost(function(ours)
	if not row then return end
	local window = View.Window()
	row:SetParent(window)
	row:SetFrameStrata(window:GetFrameStrata())
	row:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", View.Strip(), "TOPLEFT", 0, 0)
	row:SetPoint("BOTTOMRIGHT", View.Strip(), "BOTTOMRIGHT", -ns.BarRoom(), 0)
	if sides then sides:SetShown(not ours) end
	Lay()
end)

local function BuildRow()
	local bar = WorldMapFrame.NavBar
	row = CreateFrame("Frame", nil, WorldMapFrame)
	-- Over the game's bar, short of the look switch and the buttons before it at its right end (Controls.lua).
	row:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	row:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -ns.BarRoom(), 0)
	row:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	row:EnableMouse(true)
	more = UI.MenuButton(row, { font = UI.NameFont(CRUMB_FONT), height = CRUMB_TALL, inset = CRUMB_INSET, caretY = CRUMB_CARET,
		write = function(root)
			for _, info in ipairs(more.hidden or {}) do
				root:CreateButton(info.name, function() Nav.Go(info.mapID) end)
			end
		end })
	more:SetLabel("...", C.dim)
	more:HookScript("OnSizeChanged", LaySoon)
	-- The side switch (World | Dungeons) leads the row, where the journal's own stands on its bar (Sides.lua).
	if ns.Sides and ns.Sides.Switch then
		sides = ns.Sides.Switch(row, "world")
		sides:SetPoint("LEFT", row, "LEFT", 0, CRUMB_Y)
	end
	row:SetScript("OnSizeChanged", Lay)

	-- The game's floor list (one of its map's overlay buttons) stands for its own map, not ours: faded,
	-- and covered while it shows so its menu never opens.
	for _, frame in ipairs(WorldMapFrame.overlayFrames or {}) do
		if frame.ShouldShowTrackingIconOnFloor then
			floorShield = CreateFrame("Frame", nil, WorldMapFrame)
			floorShield:SetFrameStrata(frame:GetFrameStrata())
			floorShield:SetFrameLevel(frame:GetFrameLevel() + 10)
			floorShield:SetAllPoints(frame)
			floorShield:EnableMouse(true)
			floorShield.of = frame
			local function Cover() floorShield:SetShown(View.InUse() and frame:IsShown()) end
			frame:HookScript("OnShow", Cover)
			frame:HookScript("OnHide", Cover)
			floorShield.Cover = Cover
			Cover()
		end
	end
end

local function Use(on)
	if on and not row then
		Build()
		BuildRow()
	end
	if not row then return end
	WorldMapFrame.NavBar:SetAlpha(on and 0 or 1)
	row:SetShown(on)
	if floorShield then
		floorShield.of:SetAlpha(on and 0 or 1)
		floorShield.Cover()
	end
	if not on and cursorPin then
		cursorPin = false
		ResetCursor()
	end
end

local astray = false

ns.Layer({
	id = "nav",
	Use = Use,
	Map = function()
		astray = Astray()
		Lay()
		hovered = nil
		litWant = 0
		Card(nil)
		-- (A map gone to keeps its name up as it arrives.)
		if not Held() then labelWant = 0 end
	end,
	Pan = function()
		local now = Astray()
		if now ~= astray then
			astray = now
			Lay()
		end
	end,
	Close = function()
		litWant, labelWant, litAlpha, labelAlpha = 0, 0, 0, 0
		holdUntil, hovered = 0, nil
		pinNext, nextClick = false, nil
		Card(nil)
		if highlight then
			highlight:SetAlpha(0)
			label:SetAlpha(0)
		end
		if cursorPin then
			cursorPin = false
			ResetCursor()
		end
	end,
	Tick = function(dt)
		lookIn = lookIn - dt
		if lookIn <= 0 then
			lookIn = LOOK
			Look()
		end
		if litAlpha ~= litWant then
			litAlpha = Ease(litAlpha, litWant, dt)
			highlight:SetAlpha(litAlpha)
		end
		if labelAlpha ~= labelWant then
			labelAlpha = Ease(labelAlpha, labelWant, dt)
			label:SetAlpha(labelAlpha)
		end
	end,
})
