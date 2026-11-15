-- One world: the map shown follows the zoom and the place in the middle. Zoomed out past a city it
-- becomes the zone the city stands in, then the continent; zoomed in over a zone or a city it becomes that
-- one once it would fill the window; panned off a zone, it becomes the zone now in the middle. Each step is
-- View.Rebase, so nothing on screen moves. Out past a continent, on the terrain look, the world's map takes
-- over the same way (its continents' ground side by side, Terrain.Joined) and gives way to the continent
-- under the middle as that comes to fill the window; on the drawn look the wheel opens the world's map. A
-- flight (a click into a zone, a right click out) passes through the same maps on its way.
--
-- A city's zone is not its map's parent (Orgrimmar's is Kalimdor): it is the zone most of the ground just
-- round the city belongs to. Maps of one world are "free": the view pans past their edges into the world.

local ADDON, ns = ...
local T, View = ns.T, ns.View

local Steps = {}
ns.Steps = Steps

local CLIMB = 0.6           -- a map gives way to the one round it below this share of its whole size
local DIVE = 1.0            -- one inside it takes over from this share of its own whole size
-- On the drawn look a continent's own art is coarse (a whole continent in 1002 pixels): drawn past DRAWN.DIVE times its
-- size it blurs, so a zone on it takes over sooner (its own art, its neighbours' round it: Art.lua), and gives way back
-- to it only once the continent would be drawn under DRAWN.CLIMB times its size (apart, so the two never flicker).
local DRAWN = { DIVE = 1.5, CLIMB = 1.1 }
local CROSS = 0.15          -- seconds between looks at what the middle is in
local RING = 0.85           -- how far out a city's ground is sampled, in its half sizes past its middle
local BIGGER = 4            -- the zone round a city is at least this many times its ground
local AROUND = 5            -- ... has at least this many of the eight samples round it (a zone's neighbours share them)

local ZONE, CONTINENT = Enum.UIMapType.Zone, Enum.UIMapType.Continent

local yards = {}            -- map -> { width, height } in yards (false: lies in no world)
local ups = {}              -- map -> the map round it (false: none)
local fits = {}             -- map -> port units a yard with the whole map in the window, for fitsFor
local fitsFor

local function Yards(id)
	local known = yards[id]
	if known == nil then
		local world, n0, w0, n1, w1 = View.World(id)
		known = world and { w0 - w1, n0 - n1 } or false
		yards[id] = known
	end
	return known or nil
end

-- A map's own facts don't change in a session: asked once a map (the view asks every frame while open).
local infos = {}
local function Info(id)
	if not id then return nil end
	local info = infos[id]
	if not info then
		info = C_Map.GetMapInfo(id)
		infos[id] = info
	end
	return info
end

local function Continent(id)
	local info = Info(id)
	while info and info.mapType > CONTINENT do
		info = info.parentMapID and info.parentMapID > 0 and Info(info.parentMapID) or nil
	end
	return info and info.mapType == CONTINENT and info.mapID or nil
end

-- The zone a world point is in, as the continent's own map has it (where a click on it would go), out of
-- any cave or building; nil off its zones (the sea).
local function At(continent, north, west)
	local _, n0, w0, n1, w1 = View.World(continent)
	if not n0 then return nil end
	local x, y = (west - w0) / (w1 - w0), (north - n0) / (n1 - n0)
	if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	local info = C_Map.GetMapInfoAtPosition(continent, x, y)
	while info and info.mapType > ZONE do
		info = info.parentMapID and info.parentMapID > 0 and Info(info.parentMapID) or nil
	end
	return info and info.mapType == ZONE and info.mapID or nil
end

-- The map round one: a city's zone (the one most of the ground round it is in, much larger than it), a
-- zone's continent; nil for a continent or a map in no world.
function Steps.Up(id)
	local known = ups[id]
	if known ~= nil then return known or nil end
	known = false
	local info = Info(id)
	local size = Yards(id)
	local continent = Continent(id)
	if info and size and info.mapType >= ZONE and continent then
		local _, n0, w0, n1, w1 = View.World(id)
		local votes, best, most = {}, nil, 0
		local mine = size[1] * size[2]
		local north, west = (n0 + n1) / 2, (w0 + w1) / 2
		for i = 0, 7 do
			local a = i * math.pi / 4
			local x, y = 0.5 + RING * math.cos(a), 0.5 + RING * math.sin(a)
			local found = At(continent, n0 + y * (n1 - n0), w0 + x * (w1 - w0))
			local around = found and found ~= id and Yards(found)
			if around and around[1] * around[2] >= mine * BIGGER then
				votes[found] = (votes[found] or 0) + 1
				if votes[found] > most then best, most = found, votes[found] end
			end
		end
		-- The zone round a city has it all round and holds its middle.
		if best and most >= AROUND then
			local _, b0, v0, b1, v1 = View.World(best)
			local x, y = (west - v0) / (v1 - v0), (north - b0) / (b1 - b0)
			if x < 0 or x > 1 or y < 0 or y > 1 then best = nil end
		else
			best = nil
		end
		known = best or continent
		if known == id then known = false end
	end
	ups[id] = known
	return known or nil
end

-- Port units a yard: with the whole of a map in the window, and now.
local function FitK(id)
	local port = View.Port()
	local pw, ph = port:GetWidth(), port:GetHeight()
	local key = pw .. "x" .. ph
	if fitsFor ~= key then
		wipe(fits)
		fitsFor = key
	end
	local known = fits[id]
	if known == nil then
		local art = C_Map.GetMapArtLayers(id)
		local size = Yards(id)
		known = false
		if art and art[1] and size then
			local aw, ah = art[1].layerWidth, art[1].layerHeight
			known = math.min(pw / aw, ph / ah) * aw / size[1]
		end
		fits[id] = known
	end
	return known or nil
end

-- Port units a yard where a map's art is drawn at its own size.
local artKs = {}
local function ArtK(id)
	local known = artKs[id]
	if known == nil then
		local art = C_Map.GetMapArtLayers(id)
		local size = Yards(id)
		known = art and art[1] and size and art[1].layerWidth / size[1] or false
		artKs[id] = known
	end
	return known or nil
end

-- A zone on a continent drawn on the drawn look: the continent's ArtK, by which DRAWN goes; nil otherwise.
local function Coarse(zone, continent)
	if not (zone and continent) or (ns.Terrain and (ns.Terrain.Draws(continent) or ns.Terrain.Draws(zone))) then return nil end
	local a, b = Info(zone), Info(continent)
	if not (a and b and a.mapType == ZONE and b.mapType == CONTINENT) then return nil end
	return ArtK(continent)
end

-- The zoom (port units a yard) below which map `id` gives way to `up`, the map round it.
local function ClimbAt(id, up, fit)
	local coarse = Coarse(id, up)
	return coarse and math.min(CLIMB * fit, DRAWN.CLIMB * coarse) or CLIMB * fit
end

-- ... and above which map `id`, inside `over`, takes over from it.
local function DiveAt(id, over, fit)
	local coarse = Coarse(id, over)
	return coarse and math.min(DIVE * fit, DRAWN.DIVE * coarse) or DIVE * fit
end

local function Now()
	local map = View.Map()
	local size = map and Yards(map)
	if not size then return nil end
	local w = View.Size()
	return View.Scale() * w / size[1]
end

-- The terrain look's world's map: its continents side by side.
local function Joined(id)
	return ns.Terrain ~= nil and ns.Terrain.Joined(id) ~= nil
end

-- The world's map round a continent, where it lays the continent's ground beside the others.
local function Beside(id)
	local info = Info(id)
	if not (info and info.mapType == CONTINENT and ns.Terrain and ns.Terrain.Covers(id)) then return nil end
	local parent = info.parentMapID
	if parent and parent > 0 and Joined(parent) then return parent end
	return nil
end

-- Port units a yard of `world` now, on the map shown (the world's map lays each world at its own scale).
local function NowIn(world)
	local n0, w0, n1, w1 = View.Corners(View.Map(), world)
	if not n0 then return nil end
	local w = View.Size()
	return View.Scale() * w / (w0 - w1)
end

-- The cities of a zone: the continent's zones whose zone it is.
local cities = {}
local function Cities(zone)
	local known = cities[zone]
	if known then return known end
	known = {}
	local continent = Continent(zone)
	for _, child in ipairs(continent and C_Map.GetMapChildrenInfo(continent, ZONE) or {}) do
		if child.mapID ~= zone and child.mapType == ZONE and Steps.Up(child.mapID) == zone then known[#known + 1] = child.mapID end
	end
	cities[zone] = known
	return known
end
Steps.Cities = Cities

-- The maps a world point is in, the most detailed first: its zone (or a city of the zone whose ground
-- holds it), then each map round that.
local function Chain(continent, north, west)
	local chain, id, guard = {}, At(continent, north, west), 0
	if id then
		for _, city in ipairs(Cities(id)) do
			local _, n0, w0, n1, w1 = View.World(city)
			local x, y = (west - w0) / (w1 - w0), (north - n0) / (n1 - n0)
			if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				id = city
				break
			end
		end
	end
	while id and guard < 6 do
		chain[#chain + 1] = id
		id = Steps.Up(id)
		guard = guard + 1
	end
	return chain
end

-- The most detailed map at x, y of map `id` (shares, past its edges too): the zone there, or a city of
-- it, as its continent has it; also the continent and the point in its shares. nil off its zones.
function Steps.At(id, x, y)
	local continent = Continent(id)
	if not continent then return nil end
	local world, n0, w0, n1, w1 = View.World(id)
	local there, c0, v0, c1, v1 = View.World(continent)
	if not (world and there == world) then return nil end
	local north, west = n0 + y * (n1 - n0), w0 + x * (w1 - w0)
	local found = Chain(continent, north, west)[1]
	if not found then return nil end
	return found, continent, (west - v0) / (v1 - v0), (north - c0) / (c1 - c0)
end

-- The continent of the map shown, and the world point the map shown goes by: the one in the view's middle.
-- While the view looks ahead of you (View.Leaning: led somewhere, it keeps you back from its middle) that
-- is where you are: its middle may lie over a map you aren't on yet, and the map shown is yours until you are.
local function Middle()
	local map = View.Map()
	local continent = Continent(map)
	local world, n0, w0, n1, w1 = View.World(map)
	if not (world and continent) then return nil end
	if View.Leaning() then
		local here, north, west = Shy.Here()
		if here == world and north then return continent, north, west end
	end
	local cx, cy = View.Center()
	return continent, n0 + cy * (n1 - n0), w0 + cx * (w1 - w0)
end

-- What the zoom and the middle ask for now; nil to stay.
local function Wanted(crossing)
	local map = View.Map()
	local k, fitHere = Now(), map and FitK(map)
	if not (k and fitHere) then return nil end
	-- Zoomed out past a continent the world's map lays beside the others: that map, whatever the middle is over.
	if k < CLIMB * fitHere then
		local up = Beside(map)
		if up then return up end
	end
	local continent, north, west = Middle()
	if not continent then return nil end
	local chain = Chain(continent, north, west)
	-- Nothing known in the middle (the sea): the map stays as it is.
	if #chain == 0 then return nil end
	local here
	for i, id in ipairs(chain) do if id == map then here = i end end
	if not here then
		-- Off this map's ground: on a look round, the most detailed map there the zoom allows.
		if not crossing then return nil end
		for _, id in ipairs(chain) do
			local fit = FitK(id)
			if fit and k >= ClimbAt(id, Steps.Up(id), fit) then return id ~= map and id or nil end
		end
		return chain[#chain] ~= map and chain[#chain] or nil
	end
	-- Zoomed out past this map: the one round it.
	local up = Steps.Up(map)
	if up and k < ClimbAt(map, up, fitHere) then return up end
	-- Zoomed in on one inside it, as far as its whole size (never on the way out: a step out of a city
	-- starts with the zone at the city's size).
	if View.Outward() then return nil end
	for i = 1, here - 1 do
		local fit = FitK(chain[i])
		if fit and k >= DiveAt(chain[i], chain[i + 1], fit) then return chain[i] end
	end
	return nil
end

local crossIn = 0
local zoomed = false        -- the zoom moved: look again on the next frame (not from inside the view's telling)

local function Step(crossing)
	local want = Wanted(crossing)
	if want and want ~= View.Map() then View.Rebase(want) end
end

-- The view's rules for each map.
local function Free(id)
	if Joined(id) then return true end
	local info = Info(id)
	if not (info and Yards(id)) then return false end
	if info.mapType == ZONE then return true end
	return info.mapType == CONTINENT and ns.Terrain ~= nil and ns.Terrain.Covers(id)
end
-- (Asked twice a frame while the map is open; a map's answer changes only with the look.)
local freeOf, freeLook = {}, nil
View.SetFree(function(id)
	local look = ns.T.db.style
	if freeLook ~= look then
		wipe(freeOf)
		freeLook = look
	end
	local known = freeOf[id]
	if known == nil then
		known = Free(id) and true or false
		freeOf[id] = known
	end
	return known
end)
View.SetFloor(function(id)
	-- With a map round it the zoom runs on down; this file steps out to that map first.
	if Steps.Up(id) or Beside(id) then return 0.05 end
	return nil
end)
-- The world's map with its continents side by side is the ground alone: nothing stands on it.
View.SetBare(Joined)
-- As deep as the maps inside one take over: a continent's zones and cities, a zone's cities. On the
-- terrain look, as close as the minimap's own pictures of the ground bear (NEAR port units a yard).
local NEAR = 1.25
local inner = {}            -- map -> its deepest zoom, times its whole size (false: its art's own)
local function Inner(id)
	local known = inner[id]
	if known ~= nil then return known or nil end
	known = false
	local info, size = Info(id), Yards(id)
	if info and size and (info.mapType == CONTINENT or info.mapType == ZONE) then
		local continent = info.mapType == CONTINENT and id or Continent(id)
		local most = 0
		for _, child in ipairs(continent and C_Map.GetMapChildrenInfo(continent, ZONE) or {}) do
			local each = child.mapID ~= id and Yards(child.mapID)
			if each and (info.mapType == CONTINENT or Steps.Up(child.mapID) == id) then
				most = math.max(most, size[1] / each[1])
			end
		end
		if most > 0 then known = most * 1.15 end
	end
	inner[id] = known
	return known or nil
end
View.SetCeiling(function(id)
	local most = Inner(id)
	local fit = ns.Terrain and ns.Terrain.Covers(id) and FitK(id)
	if fit then most = math.max(most or 0, NEAR / fit) end
	return most
end)

View.SetBeyond(function()
	local map = View.Map()
	local info = Info(map)
	local parent = info and info.parentMapID
	if parent and parent > 0 and C_Map.MapHasArt(parent) and View.Show(parent, "out") then View.Fly(parent) end
end)

-- Over the world's own map, a continent takes over as it comes to fill the window. With the continents
-- side by side, in place, and only while the middle is over that continent's piece of the world's map
-- (over the sea between, the world's map stays); `crossing`: only then, on a look round as the view pans.
local function IntoContinent(crossing)
	local map = View.Map()
	local info = Info(map)
	if not (info and info.mapType < CONTINENT) or View.Outward() then return end
	local x, y = View.Center()
	local joined = ns.Terrain and ns.Terrain.Joined(map)
	if joined then
		local world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
		for _, entry in ipairs(joined) do
			if world and entry.world == world then
				local k, fit = NowIn(world), FitK(entry.continent)
				if k and fit and k >= DIVE * fit then View.Rebase(entry.continent) end
			end
		end
		return
	end
	if crossing then return end
	local under = C_Map.GetMapInfoAtPosition(map, x, y)
	if not (under and under.mapType == CONTINENT) then return end
	local x1, x2 = C_Map.GetMapRectOnMap(under.mapID, map)
	local art = C_Map.GetMapArtLayers(under.mapID)
	if not (x1 and art and art[1]) then return end
	local w = View.Size()
	local port = View.Port()
	local shown = (x2 - x1) * w * View.Scale()
	local whole = math.min(port:GetWidth() / art[1].layerWidth, port:GetHeight() / art[1].layerHeight) * art[1].layerWidth
	if shown >= whole * DIVE then View.Show(under.mapID, "into") end
end

-- A flight to `target` (View.Fly) passes through the maps between, as the wheel would: in, each map on the
-- way down to it as the zoom reaches its whole size; out, the map round the one shown as the zoom passes
-- below its share of it. What the middle passes over on the way is not asked.
local function Fly(target)
	local map, k = View.Map(), Now()
	if map ~= target and Joined(map) then
		k = NowIn(View.World(target))
	end
	if not k or map == target then return end
	local id, guard = target, 0
	while id and guard < 6 do
		local up = Steps.Up(id) or Beside(id)
		if up == map then
			local fit = FitK(id)
			if fit and k >= DIVE * fit * 0.98 then View.Rebase(id) end
			return
		end
		id, guard = up, guard + 1
	end
	local fit, up = FitK(map), Steps.Up(map)
	if fit and up and k < CLIMB * fit then View.Rebase(up) end
end

ns.Layer({
	id = "steps",
	Map = function() zoomed = true end,
	Scale = function() zoomed = true end,
	Tick = function(dt)
		-- (One thing looked at alone: the map stays the map it is.)
		if View.Focused() then
			zoomed = false
			return
		end
		local flying = View.Flying()
		if flying then
			zoomed = false
			Fly(flying)
			return
		end
		-- (On its way of its own, the view is not where the player went: no look round.)
		if View.Moving() then
			if zoomed then
				zoomed = false
				Step(false)
				IntoContinent()
			end
			return
		end
		if zoomed then
			zoomed = false
			Step(false)
			IntoContinent()
		end
		crossIn = crossIn - dt
		if crossIn > 0 then return end
		crossIn = CROSS
		Step(true)
		IntoContinent(true)
	end,
	Use = function()
		wipe(yards)
		wipe(ups)
		wipe(fits)
		wipe(artKs)
		wipe(inner)
		wipe(cities)
	end,
})

ns.OnApply(function()
	-- A look that changes what is free changes the floors too, and how deep the zoom goes.
	fitsFor = nil
	if View.IsOpen() then View.Relimit() end
end)
