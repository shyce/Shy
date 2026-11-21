-- The terrain look: the world itself under a zone's or a continent's map, from overhead. Close in, the
-- minimap's own picture of each block (Data/Overhead.lua names its file); further out, coarser pictures of
-- our own stitched from the same (Media/Terrain, Data/Lod.lua: 128 pixels a block, then 32, then 8), always laid under
-- the close ones so nothing is ever missing; past the world's edge, its sea's color. Only what the view
-- can see is laid, from pools. The world is one piece: Steps.lua turns the map as the view moves on.
--
-- Out past the continents, the world's map lays each one's ground where it lays the continent, side by
-- side on the one sea, with nothing standing on it (View.SetBare): the look never changes on the way out.
--
--   Terrain.Covers(map)              the terrain look draws this map
--   Terrain.Joined(map)              the world's map, its continents' ground side by side: { { world,
--                                    continent } ... }, or nil
--   Terrain.Draws(map)               either: the map's own art isn't drawn
--   Terrain.New(canvas, level) -> p  Terrain.Lay(p, map, left, right, top, bottom, w, h, scale, world, most)
--                                    (shares of the map; w, h its art's size; scale: port units an art pixel;
--                                    world: the one whose ground is laid, the map's own if nil)
--   Terrain.Painter(world) -> p      the view's painter of that world's ground (the map shown's if nil)
--   Terrain.Sea(map) -> { r, g, b }  the sea round its world
--   Terrain.ZoneAt(map, x, y)        the zone at x, y of `map` (past its edges too) -> info
--   Terrain.Nearby()                 the zones the view shows, nearest its middle first
--   Terrain.Refresh()                lays the view's ground again as it is

local ADDON, ns = ...
local T, View = ns.T, ns.View

local Terrain = {}
ns.Terrain = Terrain

local BLOCK = 1600 / 3      -- yards a side of one block (one minimap picture)
local MARGIN = 1            -- blocks (or tiles) laid past what shows
local MOST = 400            -- no more close pictures than this at once
local NEW = 24              -- ... nor more new ones than this a frame
local SEAM = 0.6            -- canvas units each picture overlaps the next, so no hairline shows between
-- No picture is drawn much smaller than it is made: the minimap's own (512 pixels a block) have no smaller sizes,
-- and drawn several times smaller their fine detail (a farm's rows) shimmers as the map moves.
local CLOSE = 256           -- port units a block from which the minimap's own pictures are laid
local MID = 64              -- ... from which our level 0 (128 pixels a block) is
local FAR = 16              -- ... from which our level 1 (32 pixels a block) is, under that level 2
local FADE = 0.3            -- seconds a world's ground takes to come in or go, stepping onto or off the world's map
local REACH = 9             -- a world's share of the world's map runs this far past its art (shares)
local LOD = "Interface\\AddOns\\ShyMaps\\Media\\Terrain\\"

local covers = {}           -- map -> true / false, for the look it was asked under
local joined = {}           -- map -> its continents side by side / false
local coversLook

local function Fresh()
	if coversLook ~= T.db.style then
		wipe(covers)
		wipe(joined)
		coversLook = T.db.style
	end
end

function Terrain.Covers(id)
	if not id or T.db.style ~= "terrain" then return false end
	Fresh()
	local known = covers[id]
	if known == nil then
		local info = C_Map.GetMapInfo(id)
		local world = View.World(id)
		local kind = info and info.mapType
		known = (kind == Enum.UIMapType.Zone or kind == Enum.UIMapType.Continent) and world ~= nil and ns.overhead[world] ~= nil
		covers[id] = known
	end
	return known
end

-- Each world's share of the world's map: its side of a line through the sea between it and each other
-- world, across the way the two lie apart. (The coarse pictures are the sea's color past the ground, and
-- would lie over the next continent's coast.)
local function Split(list, id)
	for _, entry in ipairs(list) do
		local x1, x2, y1, y2 = View.Region(id, entry.world)
		entry.box = { x1 or 0, x2 or 1, y1 or 0, y2 or 1 }
		entry.clip = { -REACH, 1 + REACH, -REACH, 1 + REACH }
	end
	for _, a in ipairs(list) do
		for _, b in ipairs(list) do
			if a ~= b then
				local A, B, clip = a.box, b.box, a.clip
				local right, left = B[1] - A[2], A[1] - B[2]      -- b to the right of a, to its left
				local below, above = B[3] - A[4], A[3] - B[4]
				if math.max(right, left) >= math.max(below, above) then
					if right >= left then clip[2] = math.min(clip[2], (A[2] + B[1]) / 2) else clip[1] = math.max(clip[1], (B[2] + A[1]) / 2) end
				else
					if below >= above then clip[4] = math.min(clip[4], (A[4] + B[3]) / 2) else clip[3] = math.max(clip[3], (B[4] + A[3]) / 2) end
				end
			end
		end
	end
end

function Terrain.Joined(id)
	if not id or T.db.style ~= "terrain" then return nil end
	Fresh()
	local known = joined[id]
	if known == nil then
		known = false
		local info = C_Map.GetMapInfo(id)
		if info and info.mapType == Enum.UIMapType.World and C_Map.GetMapArtLayers(id) then
			local list, seen = {}, {}
			for _, child in ipairs(C_Map.GetMapChildrenInfo(id, Enum.UIMapType.Continent) or {}) do
				local world = child.mapType == Enum.UIMapType.Continent and Terrain.Covers(child.mapID) and View.World(child.mapID)
				if world and not seen[world] and View.Corners(id, world) then
					seen[world] = true
					list[#list + 1] = { world = world, continent = child.mapID }
				end
			end
			if #list > 0 then
				Split(list, id)
				known = list
			end
		end
		joined[id] = known
	end
	return known or nil
end

function Terrain.Draws(id)
	return Terrain.Covers(id) or Terrain.Joined(id) ~= nil
end

function Terrain.Sea(id)
	local world = View.World(id)
	local list = not world and Terrain.Joined(id)
	if list then world = list[1].world end
	local lod = world and ns.lod and ns.lod[world]
	return lod and lod.sea or nil
end

function Terrain.New(canvas, level)
	local frame = CreateFrame("Frame", nil, canvas)
	frame:SetAllPoints()
	frame:SetFrameLevel(level)
	return { frame = frame, canvas = canvas, laid = {}, far = {}, spare = {}, missing = {}, far2 = {} }
end

local function Free(p, t)
	t:Hide()
	p.spare[#p.spare + 1] = t
end

function Terrain.Clear(p)
	for key, t in pairs(p.laid) do
		p.laid[key] = nil
		Free(p, t)
	end
	for key, t in pairs(p.far) do
		p.far[key] = nil
		Free(p, t)
	end
	p.map, p.world, p.laidFor = nil, nil, nil
	if ns.Rooms then ns.Rooms.Clear(p) end
end

local function Take(p, sub)
	local t = table.remove(p.spare) or p.frame:CreateTexture(nil, "BACKGROUND")
	t:SetDrawLayer("BACKGROUND", sub)
	t:SetVertexColor(1, 1, 1, 1)
	t:Show()
	return t
end

-- Lays the pictures under the shares left..right, top..bottom of `id`'s art on the painter's canvas (the
-- canvas being that art's size, w by h), close ones only while a block takes CLOSE port units or more.
function Terrain.Lay(p, id, left, right, top, bottom, w, h, scale, world, most)
	local n0, w0, n1, w1
	if world then
		n0, w0, n1, w1 = View.Corners(id, world)
	else
		world, n0, w0, n1, w1 = View.World(id)
	end
	local blocks = world and n0 and ns.overhead[world]
	if not blocks then
		Terrain.Clear(p)
		return false
	end
	local kx, ky = w / (w0 - w1), h / (n0 - n1)    -- art pixels a yard
	local function Stand(t, x, y, span)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", p.canvas, "TOPLEFT", (w0 - (32 - x * span) * BLOCK) * kx - SEAM / 2, -((n0 - (32 - y * span) * BLOCK) * ky - SEAM / 2))
		t:SetSize(span * BLOCK * kx + SEAM, span * BLOCK * ky + SEAM)
	end
	-- A new map of the same world: the pictures laid stay, standing where they lie on it.
	if p.map ~= id then
		if p.world ~= world then
			Terrain.Clear(p)
		else
			for _, t in pairs(p.laid) do Stand(t, t.bx, t.by, 1) end
			for _, t in pairs(p.far) do Stand(t, t.tx, t.ty, t.span) end
		end
		p.map, p.world = id, world
	end
	local westL, westR = w0 - left * (w0 - w1), w0 - right * (w0 - w1)
	local northT, northB = n0 - top * (n0 - n1), n0 - bottom * (n0 - n1)
	local function Range(span)
		local size = span * BLOCK
		return math.max(0, math.floor((32 * BLOCK - westL) / size) - MARGIN), math.min(64 / span - 1, math.floor((32 * BLOCK - westR) / size) + MARGIN),
			math.max(0, math.floor((32 * BLOCK - northT) / size) - MARGIN), math.min(64 / span - 1, math.floor((32 * BLOCK - northB) / size) + MARGIN)
	end
	local each = scale and BLOCK * kx * scale or CLOSE    -- port units a block
	-- (The capitals' rooms over the ground, Indoors.lua: they follow where you are as well as the view.)
	if ns.Rooms then ns.Rooms.Lay(p, id, world, kx, ky, n0, w0, westL, westR, northT, northB, each / BLOCK) end

	-- Ours, under the rest: level 0, 1 or 2 by the zoom, always.
	local lod = ns.lod and ns.lod[world]
	local level = lod and ((each >= MID and lod[0] and 0) or (each >= FAR and lod[1] and 1) or (lod[2] and 2 or 1))

	-- A pan or a zoom that brings no other picture into the room (the canvas moves, the pictures with it):
	-- nothing to lay. What is laid goes by the level, the ranges of blocks and whether close ones are in.
	local fx1, fx2, fy1, fy2 = 0, -1, 0, -1
	if level and lod[level] then fx1, fx2, fy1, fy2 = Range(lod[level][2]) end
	local close = each >= CLOSE
	local cx1, cx2, cy1, cy2 = 0, -1, 0, -1
	if close then cx1, cx2, cy1, cy2 = Range(1) end
	local was = p.laidFor
	if was and not p.short and was.level == level and was.close == close and was.most == most
		and was[1] == fx1 and was[2] == fx2 and was[3] == fy1 and was[4] == fy2
		and was[5] == cx1 and was[6] == cx2 and was[7] == cy1 and was[8] == cy2 then
		return true
	end
	-- Ours too come in at most `most` a frame, those nearest the middle first: a zoom onto another level
	-- brings a whole sheet of them. Until the level is all in, the one it takes over from stays under it, so
	-- nothing goes missing meanwhile; then that one goes.
	local wantFar, farShort = {}, false
	if level and lod[level] then
		local span, tiles = lod[level][2], lod[level][3]
		local x1, x2, y1, y2 = Range(span)
		local missing, dist, n = p.farMissing or {}, p.farDist or {}, 0
		p.farMissing, p.farDist = missing, dist
		local mx = (32 * BLOCK - (westL + westR) / 2) / (span * BLOCK)
		local my = (32 * BLOCK - (northT + northB) / 2) / (span * BLOCK)
		for ty = y1, y2 do
			for tx = x1, x2 do
				local tile = ty * 64 + tx
				if tiles[tile] then
					local key = level * 4096 + tile
					wantFar[key] = true
					if not p.far[key] then
						n = n + 1
						missing[n] = key
						dist[key] = (tx + 0.5 - mx) ^ 2 + (ty + 0.5 - my) ^ 2
					end
				end
			end
		end
		for i = n + 1, #missing do missing[i] = nil end
		local budget = most or n
		if n > budget then
			table.sort(missing, function(a, b) return dist[a] < dist[b] end)
			farShort = true
		end
		for i = 1, math.min(n, budget) do
			local key = missing[i]
			local tile = key % 4096
			local tx, ty = tile % 64, math.floor(tile / 64)
			local t = Take(p, -3)
			t:SetTexture(LOD .. world .. "_" .. level .. "_" .. tx .. "_" .. ty, nil, nil, "LINEAR")
			t.tx, t.ty, t.span = tx, ty, span
			Stand(t, tx, ty, span)
			p.far[key] = t
		end
	end
	for key, t in pairs(p.far) do
		if not wantFar[key] and not (farShort and math.floor(key / 4096) ~= level) then
			p.far[key] = nil
			Free(p, t)
		end
	end

	-- The minimap's own, close in: at most `most` new ones (the view lays NEW a frame), those nearest the
	-- middle first (the coarse ones are under the rest meanwhile); p.short says some are still to come.
	local want = {}
	p.short = false
	if each >= CLOSE then
		local x1, x2, y1, y2 = Range(1)
		if (x2 - x1 + 1) * (y2 - y1 + 1) <= MOST then
			local missing = p.missing
			local n = 0
			local mx = (32 * BLOCK - (westL + westR) / 2) / BLOCK
			local my = (32 * BLOCK - (northT + northB) / 2) / BLOCK
			for by = y1, y2 do
				for bx = x1, x2 do
					local block = by * 64 + bx
					if blocks[block] then
						want[block] = true
						if not p.laid[block] then
							n = n + 1
							missing[n] = block
							p.far2[block] = (bx + 0.5 - mx) ^ 2 + (by + 0.5 - my) ^ 2
						end
					end
				end
			end
			for i = n + 1, #missing do missing[i] = nil end
			most = most or n
			if n > most then
				local far2 = p.far2
				table.sort(missing, function(a, b) return far2[a] < far2[b] end)
				p.short = true
			end
			for i = 1, math.min(n, most) do
				local block = missing[i]
				local bx, by = block % 64, math.floor(block / 64)
				local t = Take(p, -2)
				t:SetTexture(blocks[block], nil, nil, "TRILINEAR")
				t.bx, t.by = bx, by
				Stand(t, bx, by, 1)
				p.laid[block] = t
			end
		end
	end
	for block, t in pairs(p.laid) do
		if not want[block] then
			p.laid[block] = nil
			Free(p, t)
		end
	end
	-- (Ours still to come: laid on, a frame at a time, as the close ones are.)
	if farShort then p.short = true end
	local laid = p.laidFor or {}
	p.laidFor = laid
	laid.level, laid.close, laid.most = level, close, most
	laid[1], laid[2], laid[3], laid[4], laid[5], laid[6], laid[7], laid[8] = fx1, fx2, fy1, fy2, cx1, cx2, cy1, cy2
	return true
end

-- The zone that holds a point of `id` (shares, past its edges too).
function Terrain.ZoneAt(id, x, y)
	local world, n0, w0, n1, w1 = View.World(id)
	if not world then return nil end
	local found = C_Map.GetMapPosFromWorldPos(world, CreateVector2D(n0 + y * (n1 - n0), w0 + x * (w1 - w0)))
	local info = found and C_Map.GetMapInfo(found)
	while info and info.mapType > Enum.UIMapType.Zone do
		info = info.parentMapID and info.parentMapID > 0 and C_Map.GetMapInfo(info.parentMapID) or nil
	end
	if info and info.mapType == Enum.UIMapType.Zone then return info end
	return nil
end

-- Zones whose ground the view shows, the one under its middle first, then by how near their middle is.
function Terrain.Nearby()
	local id = View.Map()
	if not View.World(id) then return {} end
	local left, right, top, bottom = View.Shown()
	local cx, cy = View.Center()
	local seen, list = {}, {}
	for i = 0, 4 do
		for j = 0, 4 do
			local x, y = left + (right - left) * i / 4, top + (bottom - top) * j / 4
			local info = Terrain.ZoneAt(id, x, y)
			if info and not seen[info.mapID] then
				seen[info.mapID] = true
				local d = (x - cx) ^ 2 + (y - cy) ^ 2
				list[#list + 1] = { info = info, d = info.mapID == id and -1 or d }
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i, item in ipairs(list) do list[i] = item.info end
	return list
end

-- The view's painters, one a world: the map shown's own, and on the world's map one for each continent's
-- world. Stepping onto the world's map the other worlds come in, and stepping off it they go, over FADE;
-- while more than one shows, each is held to its share of the world's map.

local painters = {}         -- world -> painter
local split                 -- the world's map whose shares hold them

local function Painter(world)
	local p = painters[world]
	if p then return p end
	local land, level = View.Land(), View.Level("PIN_FRAME_LEVEL_MAP_EXPLORATION") - 1
	local box = CreateFrame("Frame", nil, land)
	box:SetAllPoints()
	box:SetFrameLevel(level)
	box:SetAlpha(0)
	p = Terrain.New(land, level)
	p.frame:SetParent(box)
	p.frame:SetAllPoints(box)
	p.frame:SetFrameLevel(level)
	p.box, p.home, p.alpha, p.want = box, world, 0, 0
	painters[world] = p
	return p
end

-- The painter of `world`'s ground, the map shown's world if nil.
function Terrain.Painter(world)
	world = world or View.World(View.Map())
	return world and painters[world] or nil
end

local function Gone(p)
	Terrain.Clear(p)
	p.alpha, p.want = 0, 0
	p.box:SetAlpha(0)
	p.box:Hide()
end

-- Holds a painter to its share of the world's map, carried onto the map shown; or lets it run free.
local function Hold(p, id, many)
	local box, land = p.box, View.Land()
	local a = many and p.clip and split and { View.Corners(split, p.home) }
	local b = a and a[1] and { View.Corners(id, p.home) }
	if not (b and b[1]) then
		box:SetClipsChildren(false)
		box:ClearAllPoints()
		box:SetAllPoints(land)
		return
	end
	local w, h = View.Size()
	local function X(x) return (a[2] + x * (a[4] - a[2]) - b[2]) / (b[4] - b[2]) * w end
	local function Y(y) return (a[1] + y * (a[3] - a[1]) - b[1]) / (b[3] - b[1]) * h end
	local clip = p.clip
	local x1, x2, y1, y2 = X(clip[1]), X(clip[2]), Y(clip[3]), Y(clip[4])
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", land, "TOPLEFT", math.min(x1, x2), -math.min(y1, y2))
	box:SetSize(math.abs(x2 - x1), math.abs(y2 - y1))
	box:SetClipsChildren(true)
end

local function Lay()
	local id = View.Map()
	local list = id and (Terrain.Joined(id) or (Terrain.Covers(id) and { { world = View.World(id) } }))
	if not list then
		for _, p in pairs(painters) do Gone(p) end
		-- (The drawn look on a zone: blank paper where no map's art lies, Art.lua.)
		View.Ground(ns.Art and ns.Art.Paper and ns.Art.Paper() or nil)
		return
	end
	View.Ground(Terrain.Sea(id))
	for _, p in pairs(painters) do p.want = 0 end
	for _, entry in ipairs(list) do
		local p = Painter(entry.world)
		p.want = 1
		if entry.clip then p.clip, split = entry.clip, id end
	end
	-- (Come to by a step, the ground eases in or out; shown at once, it is as it is now.)
	local stepped = View.rebased
	local many = 0
	for _, p in pairs(painters) do
		if not stepped then p.alpha = p.want end
		if p.want == 0 and p.alpha > 0 and not View.Corners(id, p.home) then p.alpha = 0 end
		if p.want > 0 or p.alpha > 0 then many = many + 1 end
	end
	local w, h = View.Size()
	local left, right, top, bottom = View.Shown()
	local scale = View.Scale()
	for _, p in pairs(painters) do
		if p.want > 0 or p.alpha > 0 then
			p.box:SetAlpha(p.alpha)
			p.box:Show()
			Hold(p, id, many > 1)
			Terrain.Lay(p, id, left, right, top, bottom, w, h, scale, p.home, NEW)
		elseif p.box:IsShown() then
			Gone(p)
		end
	end
end

-- Lays the view's ground again as it is (the rooms shown changed: you went in or out).
function Terrain.Refresh()
	if View.IsOpen() then Lay() end
end

local function Tick(dt)
	local gone, short = false, false
	for _, p in pairs(painters) do
		if p.short then short = true end
		if p.alpha ~= p.want then
			local step = dt / FADE
			p.alpha = p.want > p.alpha and math.min(p.want, p.alpha + step) or math.max(p.want, p.alpha - step)
			p.box:SetAlpha(p.alpha)
			if p.alpha == 0 then
				Gone(p)
				gone = true
			end
		end
	end
	-- (One fewer shows: the rest may run free again. Pictures still to come: the next of them.)
	if (gone or short) and View.Map() then Lay() end
end

ns.Layer({
	id = "terrain",
	Use = function(on)
		if on then return end
		for _, p in pairs(painters) do Gone(p) end
		View.Ground(nil)
	end,
	Map = Lay,
	Scale = Lay,
	Pan = Lay,
	Tick = Tick,
})

ns.OnApply(function()
	if View.IsOpen() then Lay() end
end)
