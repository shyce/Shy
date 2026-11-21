-- Getting about: where boats, zeppelins, airboats and the tram are boarded, each the family's mark with
-- where it goes and how long it takes (ShyWay's rides, Shy.Way.Rides), side by side where two would overlap,
-- the way it sails lit while pointed at; the routes
-- between the flight points you know, faint under them (the lines the flights fly, Shy.Way.data.flightWays); and on
-- a zone, where spirit healers stand (Data/Travel.lua), the nearest lit while you are dead (by the ground
-- where it is known).

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local Maps = Shy.Maps

local Travel = {}
ns.Travel = Travel

local MARK = 20             -- a dock's mark, units on screen
local GAP = 0.1             -- docks' marks that would overlap stand side by side this far apart, in marks
local PASSES = 8            -- times the docks are looked over for any still overlapping
local SPIRIT = 16           -- a spirit healer's picture: its height, units on screen
local SPIRIT_ATLAS = "poi-graveyard-neutral"
local ROUTE_THICK, ROUTE_ALPHA = 1.4, 0.42
local BEND = 1.2            -- art pixels a route's drawn line may stray from the flown one
-- The change in zoom (a share) after which the routes are laid again at their width: while the zoom is
-- under way only a large one (laying every line again in the middle of a zoom costs it frames), and once
-- it has come to rest the smallest.
local RELAY_MOVING, RELAY_REST = 0.45, 0.02
local LOOK = 1              -- seconds between looks at whether you are dead, and which healer is nearest
local TRAVEL = Shy.Theme.TRAVEL.flight   -- the flight routes' color
local SAIL = { thick = 2.2, alpha = 0.95 }   -- the way a dock's rides sail, lit while it is pointed at

-- What is boarded at a dock, and how each is called and drawn: ShyWay's (Shy.Way.RIDES).
local BOARDED = { boat = true, zeppelin = true, airboat = true, tram = true }
local KINDS = Shy.Way.RIDES
Travel.KINDS = KINDS

-- Docks

local boards                -- { kind, continent, north, west, to = { { town, continent, north, west } } }
local docks, usedDocks = {}, 0
local places = {}           -- where the docks shown stand: x, y, x, y, ... in shares of the art (Apart)

-- Marks `size` across (in the units of x * w) that would overlap are moved apart along the line between
-- them, about the middle they share, until they stand side by side; marks clear of all others stay where
-- they are. list: { x, y, x, y, ... } in shares of a w by h art, moved in place.
local function Apart(list, w, h, size)
	local need, n = size * (1 + GAP), #list / 2
	for _ = 1, PASSES do
		local moved = false
		for i = 1, n - 1 do
			for j = i + 1, n do
				local dx, dy = (list[2 * j - 1] - list[2 * i - 1]) * w, (list[2 * j] - list[2 * i]) * h
				local d = math.sqrt(dx * dx + dy * dy)
				if d < need * 0.999 then
					-- (Two on one spot stand side by side across it.)
					if d < 1e-6 then dx, dy, d = 1, 0, 1 end
					local push = (need - d) / 2 / d
					list[2 * i - 1], list[2 * i] = list[2 * i - 1] - dx * push / w, list[2 * i] - dy * push / h
					list[2 * j - 1], list[2 * j] = list[2 * j - 1] + dx * push / w, list[2 * j] + dy * push / h
					moved = true
				end
			end
		end
		if not moved then return end
	end
end
Travel.Apart = Apart

-- Where your side boards something (ShyWay's rides: Shy.Way.Rides): one per stop and kind, with
-- everywhere it goes.
function Travel.Boards()
	if boards then return boards end
	local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
	local list, by = {}, {}
	for _, ride in ipairs(Shy.Way.Rides()) do
		if BOARDED[ride.by] and (ride.whose == "" or ride.whose:find(mine, 1, true)) then
			local from, to = ride.from, ride.to
			local board = by[from] and by[from][ride.by]
			if not board then
				board = { kind = ride.by, continent = from.world, north = from.north, west = from.west, to = {} }
				by[from] = by[from] or {}
				by[from][ride.by] = board
				list[#list + 1] = board
			end
			board.to[#board.to + 1] = { town = to.name, continent = to.world, north = to.north, west = to.west, ride = ride }
		end
	end
	boards = list
	return list
end

-- The map a place is shown on when it is gone to: the zone it is in.
local function MapAt(continent, north, west)
	local id = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(north, west))
	while id and id > 0 do
		local info = C_Map.GetMapInfo(id)
		if not info then return nil end
		if info.mapType <= Enum.UIMapType.Zone then return C_Map.MapHasArt(id) and id or nil end
		id = info.parentMapID
	end
end

-- A way lit while what it leads from is pointed at (a dock's rides, a flight point's flight): each stretch of it
-- on the map's world, in its color. Travel.Light(owner, color, stretches), stretches as a ride's line is
-- ({ { world, north, west, north, west, ... }, ... }); Travel.Unlight(owner).
local lit                   -- { pen, owner, color, stretches }
local function LayLit()
	if not (lit and lit.pen) then return end
	local map, s = View.Map(), View.Scale()
	local w, h = View.Size()
	local world = map and View.World(map)
	Maps.Begin(lit.pen, 1 / s)
	if world and w and lit.owner then
		for _, stretch in ipairs(lit.stretches) do
			if stretch[1] == world then
				local flat = {}
				for i = 2, #stretch - 1, 2 do
					local x, y = ns.OnMap(map, world, stretch[i], stretch[i + 1])
					if x then flat[#flat + 1], flat[#flat + 2] = x * w, y * h end
				end
				flat = Travel.Thin(flat, BEND)
				for i = 1, #flat - 3, 2 do
					Maps.Segment(lit.pen, flat[i], flat[i + 1], flat[i + 2], flat[i + 3], SAIL.thick, SAIL.alpha, lit.color)
				end
			end
		end
	end
	Maps.Finish(lit.pen)
end

function Travel.Light(owner, color, stretches)
	if not lit then return end
	lit.owner, lit.color, lit.stretches = owner, color, stretches or {}
	LayLit()
end

function Travel.Unlight(owner)
	if not (lit and lit.owner == owner) then return end
	lit.owner, lit.stretches = nil, nil
	LayLit()
end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

local function DockTip(pin)
	local board = pin.board
	local kind = KINDS[board.kind]
	local rows = {}
	for _, to in ipairs(board.to) do
		local seconds, sure
		if to.ride and Shy.Way.RideSeconds then seconds, sure = Shy.Way.RideSeconds(to.ride) end
		rows[#rows + 1] = { glyph = "go", text = to.town, name = true,
			right = seconds and seconds > 0 and ((sure and "" or "about ") .. Clock(seconds)) or nil }
	end
	local content = { title = kind.word, sections = { { rows = rows } } }
	if pin.goes then content.hints = { { "left", "Show " .. board.to[1].town } } end
	Shy.Hover.Show(pin, content)
	local stretches = {}
	for _, to in ipairs(board.to) do
		for _, stretch in ipairs(to.ride and to.ride.line or {}) do stretches[#stretches + 1] = stretch end
	end
	Travel.Light(pin, kind.color, stretches)
end

local function DockClick(pin, button)
	if button == "LeftButton" and pin.goes then View.Show(pin.goes) end
end

local function DockLeave(pin)
	Shy.Hover.Hide(pin)
	Travel.Unlight(pin)
end

local function Dock(i)
	local pin = docks[i]
	if pin then return pin end
	pin = View.Pin("PIN_FRAME_LEVEL_TRAVEL", MARK, DockTip, DockClick)
	pin:SetScript("OnLeave", DockLeave)
	pin.icon:Hide()
	pin.mark = Maps.Mark(pin, MARK)
	pin.mark:SetPoint("CENTER")
	docks[i] = pin
	return pin
end

-- The docks shown, each where it is or, where marks would overlap at this zoom, moved aside.
local function StandDocks()
	local w, h = View.Size()
	wipe(places)
	for i = 1, usedDocks do places[2 * i - 1], places[2 * i] = docks[i].ax, docks[i].ay end
	if w then Apart(places, w, h, MARK * View.Grow() / View.Scale()) end
	for i = 1, usedDocks do View.Stand(docks[i], places[2 * i - 1], places[2 * i]) end
end

local function Docks(map)
	for _, board in ipairs(Travel.Boards()) do
		local x, y = ns.OnMap(map, board.continent, board.north, board.west)
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			usedDocks = usedDocks + 1
			local pin = Dock(usedDocks)
			pin.board = board
			pin.goes = nil
			if #board.to == 1 then
				local to = board.to[1]
				local there = MapAt(to.continent, to.north, to.west)
				if there ~= map then pin.goes = there end
			end
			pin.ax, pin.ay = x, y
			local kind = KINDS[board.kind]
			pin.mark:Set(kind.sign, kind.color)
		end
	end
	StandDocks()
end

-- Flight routes

local clip, sheet, pen
local routesFor = {}        -- map -> { { x, y, x, y, ... } }: the routes known there, in art pixels, thinned
local laid, laidAt          -- the routes laid, and at what zoom

-- Points that stray no more than `bend` from the line through the ones kept (Douglas-Peucker).
local function Thin(flat, bend)
	local n = #flat / 2
	if n <= 2 then return flat end
	local keep, stack = { [1] = true, [n] = true }, { 1, n }
	while #stack > 0 do
		local b = table.remove(stack)
		local a = table.remove(stack)
		local ax, ay = flat[2 * a - 1], flat[2 * a]
		local dx, dy = flat[2 * b - 1] - ax, flat[2 * b] - ay
		local length = math.sqrt(dx * dx + dy * dy)
		local far, at = 0, nil
		for i = a + 1, b - 1 do
			local px, py = flat[2 * i - 1] - ax, flat[2 * i] - ay
			local d = length > 1e-9 and math.abs(px * dy - py * dx) / length or math.sqrt(px * px + py * py)
			if d > far then far, at = d, i end
		end
		if at and far > bend then
			keep[at] = true
			stack[#stack + 1], stack[#stack + 2], stack[#stack + 3], stack[#stack + 4] = a, at, at, b
		end
	end
	local out = {}
	for i = 1, n do
		if keep[i] then out[#out + 1], out[#out + 2] = flat[2 * i - 1], flat[2 * i] end
	end
	return out
end
Travel.Thin = Thin

-- The flight points you know on the map's continent (the map itself where it lies on none).
local function Known(map)
	local top, id = map, map
	while id and id > 0 do
		local info = C_Map.GetMapInfo(id)
		if not info then break end
		if info.mapType == Enum.UIMapType.Continent then
			top = id
			break
		end
		id = info.parentMapID
	end
	local known = {}
	for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(top) or {}) do
		if ns.Ours(node) and not node.isUndiscovered then known[node.nodeID] = true end
	end
	return known
end

-- w, h: the map's art size.
function Travel.Routes(map, w, h)
	local found = routesFor[map]
	if found then return found end
	found = {}
	local ways = Shy.Way.data.flightWays
	local world = View.World(map)
	if ways and world and w and ns.OnMap(map, world, 0, 0) and C_TaxiMap.ShouldMapShowTaxiNodes(map) then
		local known = Known(map)
		for from, list in pairs(ways) do
			if known[from] then
				for to, way in pairs(list) do
					-- Each pair once: a route flown both ways is one line.
					local once = from < to or not (ways[to] and ways[to][from])
					if known[to] and once and way[1] == world then
						local flat, inside = {}, false
						for i = 2, #way - 1, 2 do
							local x, y = ns.OnMap(map, world, way[i], way[i + 1])
							flat[#flat + 1], flat[#flat + 2] = x * w, y * h
							if x >= 0 and x <= 1 and y >= 0 and y <= 1 then inside = true end
						end
						if inside and #flat >= 4 then found[#found + 1] = Thin(flat, BEND) end
					end
				end
			end
		end
	end
	routesFor[map] = found
	return found
end

local function Lay()
	local s = View.Scale()
	Maps.Begin(pen, 1 / s)
	for _, flat in ipairs(laid or {}) do
		for i = 1, #flat - 3, 2 do
			Maps.Segment(pen, flat[i], flat[i + 1], flat[i + 2], flat[i + 3], ROUTE_THICK, ROUTE_ALPHA, TRAVEL)
		end
	end
	Maps.Finish(pen)
	laidAt = s
end

-- Spirit healers

local spirits, usedSpirits = {}, 0
local nearest               -- the healer lit while you are dead: its place in ns.travel.spirits (its continent's)
local dead = false
local goals = {}            -- continent -> { flat = { north, west, ... }, at = { index, ... } } (kept: Terrain asks it)
local lookIn = 0

local function Goals(continent)
	local found = goals[continent]
	if found then return found end
	found = { flat = {}, at = {} }
	local list = ns.travel and ns.travel.spirits or {}
	for i = 1, #list - 2, 3 do
		if list[i] == continent then
			found.flat[#found.flat + 1], found.flat[#found.flat + 2] = list[i + 1], list[i + 2]
			found.at[#found.at + 1] = i
		end
	end
	goals[continent] = found
	return found
end

-- Where you are in the world.
local function Here()
	return Shy.Here(true)
end

-- The healer nearest you: by the ground where the ground is known, else as the crow flies.
function Travel.Nearest()
	local continent, north, west = Here()
	if not continent then return nil end
	local found = Goals(continent)
	if #found.at == 0 then return nil end
	if Shy.Way.Has(continent) then
		local seconds, goal = Shy.Way.Ask(continent, north, west, found.flat)
		if seconds and goal then return found.at[goal] end
	end
	local best, at = math.huge, nil
	for k = 1, #found.at do
		local dn, dw = found.flat[2 * k - 1] - north, found.flat[2 * k] - west
		local d = dn * dn + dw * dw
		if d < best then best, at = d, found.at[k] end
	end
	return at
end

local function SpiritTip(pin)
	UI.Tip(pin, "Spirit healer", pin.lit and "Nearest to you" or nil)
end

local function Spirit(i)
	local pin = spirits[i]
	if pin then return pin end
	pin = View.Pin("PIN_FRAME_LEVEL_SPIRIT_HEALER", SPIRIT, SpiritTip)
	local info = C_Texture.GetAtlasInfo(SPIRIT_ATLAS)
	local k = info and SPIRIT / math.max(info.height, 1) or 1
	pin.icon:SetAtlas(SPIRIT_ATLAS)
	pin.iw, pin.ih = info and info.width * k or SPIRIT, info and info.height * k or SPIRIT
	pin.icon:SetSize(pin.iw, pin.ih)
	pin:SetSize(math.max(pin.iw, SPIRIT * 0.75), SPIRIT)
	pin.icon:ClearAllPoints()
	pin.icon:SetPoint("CENTER")
	pin.light = pin:CreateTexture(nil, "BACKGROUND")
	pin.light:SetTexture(Shy.MEDIA .. "Glow")
	pin.light:SetPoint("CENTER")
	pin.light:SetSize(SPIRIT * 2.6, SPIRIT * 2.6)
	pin.light:Hide()
	spirits[i] = pin
	return pin
end

local function Light(pin, on)
	pin.lit = on
	pin.light:SetShown(on)
	if on then
		local light = Shy.Theme.light
		pin.light:SetVertexColor(light[1], light[2], light[3], 0.6)
	end
	local grow = on and 1.3 or 1
	pin.icon:SetSize(pin.iw * grow, pin.ih * grow)
end

local function Spirits(map)
	local info = C_Map.GetMapInfo(map)
	if not (info and info.mapType == Enum.UIMapType.Zone) then return end
	local list = ns.travel and ns.travel.spirits or {}
	for i = 1, #list - 2, 3 do
		local x, y = ns.OnMap(map, list[i], list[i + 1], list[i + 2])
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			usedSpirits = usedSpirits + 1
			local pin = Spirit(usedSpirits)
			pin.index = i
			Light(pin, dead and nearest == i)
			View.Stand(pin, x, y)
		end
	end
end

-- The map

local function Refresh()
	local map = View.Map()
	usedDocks, usedSpirits, laid = 0, 0, nil
	if map and View.IsOpen() and not C_Map.GetMapDisplayInfo(map) then
		if T.db.travel and not ns.Inside() then Docks(map) end
		if T.db.spirits then Spirits(map) end
		if T.db.routes then laid = Travel.Routes(map, View.Size()) end
	end
	for i = usedDocks + 1, #docks do docks[i]:Hide() end
	for i = usedSpirits + 1, #spirits do spirits[i]:Hide() end
	if pen then Lay() end
	if lit and lit.owner then
		lit.owner = nil
		LayLit()
	end
end

local function Relay()
	local off = laid and laidAt and math.abs(View.Scale() / laidAt - 1)
	if off and off > (View.Busy() and RELAY_MOVING or RELAY_REST) then Lay() end
end

local function Restand()
	StandDocks()
	if lit and lit.owner then LayLit() end
	for i = 1, usedSpirits do View.Stand(spirits[i], spirits[i].x, spirits[i].y) end
	Relay()
end

-- The pen a lit way is laid with.
function Travel.Lit() return lit and lit.pen end

-- What stands on the view now: { docks = { pin }, spirits = { pin }, routes = { flat } }.
function Travel.Shown()
	return { docks = { unpack(docks, 1, usedDocks) }, spirits = { unpack(spirits, 1, usedSpirits) }, routes = laid or {} }
end

-- While you are dead, which healer is nearest; lit as it changes.
local function Look(now)
	local was, lit = dead, nearest
	dead = UnitIsDeadOrGhost("player") == true
	nearest = dead and T.db.spirits and Travel.Nearest() or nil
	if now or was ~= dead or lit ~= nearest then
		for i = 1, usedSpirits do Light(spirits[i], dead and spirits[i].index == nearest) end
	end
end

local function Build()
	clip = CreateFrame("Frame", nil, View.Canvas())
	clip:SetAllPoints()
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_FLIGHT_ROUTES"))
	sheet = CreateFrame("Frame", nil, clip)
	sheet:SetAllPoints()
	sheet:SetFrameLevel(clip:GetFrameLevel())
	pen = Maps.Pen(sheet, "TOPLEFT", sheet, true)
	lit = { pen = Maps.Pen(sheet, "TOPLEFT", sheet, true, true) }
end

ns.Layer({
	id = "travel",
	Use = function(on)
		if on and not pen then Build() end
		if not on then Refresh() end
	end,
	later = true,
	Map = function()
		Look()
		Refresh()
	end,
	Scale = Restand,
	Tick = function(dt)
		lookIn = lookIn - dt
		if lookIn <= 0 then
			lookIn = LOOK
			Look()
		end
		-- (The zoom at rest: the routes at their width again.)
		if not View.Busy() then Relay() end
	end,
})

ns.OnApply(function()
	if View.IsOpen() then Refresh() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
events:SetScript("OnEvent", function()
	wipe(routesFor)
	if View.IsOpen() then Refresh() end
end)

Shy:On("SHY_TERRAIN", function()
	if dead and View.IsOpen() then Look(true) end
end)

-- What your side boards is worked out a while after you log in, out of a fight, not on the map's first opening.
Shy:On("SHY_LOGIN", function()
	C_Timer.After(5, function()
		if not InCombatLockdown() then Travel.Boards() end
	end)
end)
