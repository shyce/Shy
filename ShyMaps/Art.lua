-- The map's art: the base tiles of each of its detail levels (the one for the zoom shown, eased in as the
-- zoom passes between them), the background beyond its edges, and every overlay of its zones: those
-- explored as the game has them, the rest from Data/Fog.lua (faded, as explored, or not drawn).
--
-- A zone is one piece of its continent: the continent's own drawn map lies under it, where the zone lies
-- on it, and the zone's art runs into it over a feathered edge (Media/Feather), so panning past the zone
-- shows the land round it. When the view turns into another map of the world (Steps.lua) the art it
-- leaves fades out over the new one coming in.
--
--   Art.New(canvas, level) -> painter   a painter lays art on a canvas of anyone's (the view's, the options' preview)
--   Art.Paint(painter, map, fog, bare, feather)   fog: "faded" | "clear" | "hidden"; bare: draw nothing
--                                        (the terrain look draws the map); feather: its edges run out
--   Art.Detail(painter, zoom)            the detail level for a zoom (times the whole map's size)
--   Art.Loaded()                         the view's tiles have all come in

local ADDON, ns = ...
local T, View = ns.T, ns.View

local Art = {}
ns.Art = Art

local FADED = { 0.66, 0.62, 0.55 }   -- an unexplored overlay: grey, a little warm, under the explored ones
local SMALLEST = 16                  -- the narrowest file a cut tile is drawn from
local UNDER = 0.8                    -- the continent under a zone: this bright, so the zone stands out
local ROUND = 0.92                   -- the zones round it: a little dimmer than it, brighter than the continent
local VIEW = 0.25                    -- the zones round it are those in the window and this share of it past its edges
-- The continent's art under a zone is a tenth of its detail: drawn more than UNDER_FADE.from times too large it is a
-- blur with its region names in giant letters, so by UNDER_FADE.to it has faded onto its wash (Media/Terrain/wash_<map>:
-- the same art blurred to its colour fields, no lettering), where no zone's art lies: land no map ever drew. Past the
-- continent's edge lies blank paper, the zones' own (PAPER).
local UNDER_FADE = { from = 2.5, to = 4 }
local PAPER = { 0.675, 0.549, 0.329 }
local WASH = "Interface\\AddOns\\ShyMaps\\Media\\Terrain\\wash_"
-- The painted land between the zones (ns.data.gapFills, Media/GapFill, where they ship): land no zone map covers,
-- painted in the zone maps' style, laid with the continent under a zone over every zone's blank paper and under every
-- zone's painting. Only those in the window (VIEW past its edges) are shown, each one's pictures set the first time
-- it is. With none, that land fades to its own colors.
local GAP = "Interface\\AddOns\\ShyMaps\\Media\\GapFill\\"
local TILE = 256
local MOST_ROUND = 12                -- ... the most in view this many
local CROSS = 0.2                    -- seconds the art of a map left takes to give way to the new one's
local FEATHER = "Interface\\AddOns\\ShyMaps\\Media\\Feather"

local function Texture(list, index, frame, layer, sub)
	local t = list[index]
	if not t then
		t = frame:CreateTexture(nil, layer, nil, sub)
		list[index] = t
	end
	t:SetDrawLayer(layer, sub)
	t:ClearAllPoints()
	t:Show()
	return t
end

-- over: the level its overlays are laid at (level + 1 unless told).
function Art.New(canvas, level, over)
	local p = { canvas = canvas, frames = {}, tiles = {}, bits = {}, levels = {}, masks = {} }
	p.root = CreateFrame("Frame", nil, canvas)
	p.root:SetAllPoints()
	p.root:SetFrameLevel(level)
	p.ground = p.root:CreateTexture(nil, "BACKGROUND", nil, -8)
	p.fog = CreateFrame("Frame", nil, p.root)
	p.fog:SetAllPoints()
	p.fog:SetFrameLevel(over or level + 1)
	p.level, p.over = level, over
	return p
end

-- The feather on one of the painter's frames (made the first time it is asked for).
local function Mask(p, frame)
	local mask = p.masks[frame]
	if not mask then
		mask = frame:CreateMaskTexture()
		mask:SetTexture(FEATHER, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(p.canvas)
		p.masks[frame] = mask
	end
	return mask
end

local function Feather(p, t, frame, on)
	if on == (t.shyFeathered == frame) then return end
	if t.shyFeathered then
		t:RemoveMaskTexture(Mask(p, t.shyFeathered))
		t.shyFeathered = nil
	end
	if on then
		t:AddMaskTexture(Mask(p, frame))
		t.shyFeathered = frame
	end
end

-- Detail levels as the game counts them: each art layer from its least to its deepest zoom, in steps.
local function Levels(p, art)
	wipe(p.levels)
	local last = 0
	for index, layer in ipairs(art) do
		local span = (layer.maxScale or 1) - (layer.minScale or 1)
		local steps = span > 0 and 2 + (layer.additionalZoomSteps or 0) or 1
		local step = span > 0 and span / (steps - 1) or 1
		for i = 0, steps - 1 do
			last = math.max((layer.minScale or 1) + step * i, last + 0.01)
			p.levels[#p.levels + 1] = { zoom = last, layer = index }
		end
	end
end

-- One overlay's tiles, as the game lays out an explored one: tiles of the layer's tile size from its top
-- left, the last column and row cut to what is left of it (drawn from the smallest file that holds them).
local function Overlay(p, used, width, height, x, y, files, first, columns, tw, th, sub, faded)
	local wide, tall = columns or math.ceil(width / tw), math.ceil(height / th)
	for j = 1, tall do
		local ph, fh = th, th
		if j == tall then
			ph = height % th
			if ph == 0 then ph = th end
			fh = SMALLEST
			while fh < ph do fh = fh * 2 end
		end
		for k = 1, wide do
			local pw, fw = tw, tw
			if k == wide then
				pw = width % tw
				if pw == 0 then pw = tw end
				fw = SMALLEST
				while fw < pw do fw = fw * 2 end
			end
			local file = files[first + (j - 1) * wide + (k - 1)]
			if file then
				used = used + 1
				local t = Texture(p.bits, used, p.fog, "ARTWORK", sub)
				t:SetSize(pw, ph)
				t:SetTexCoord(0, pw / fw, 0, ph / fh)
				t.shyX, t.shyY = x + tw * (k - 1), y + th * (j - 1)
				t:SetPoint("TOPLEFT", p.canvas, "TOPLEFT", t.shyX, -t.shyY)
				t:SetTexture(file, nil, nil, "TRILINEAR")
				t:SetDesaturated(faded)
				if faded then t:SetVertexColor(FADED[1], FADED[2], FADED[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
			end
		end
	end
	return used
end

function Art.Paint(p, id, fog, bare, feather)
	local art = C_Map.GetMapArtLayers(id)
	if not (art and art[1]) then return nil end
	local first = art[1]
	local width, height = first.layerWidth, first.layerHeight
	-- Laid as asked already (the map reopened, a step back onto the map just left): its pictures stay.
	local key = id .. ":" .. tostring(C_Map.GetMapArtID(id)) .. ":" .. tostring(fog) .. ":" .. tostring(bare) .. ":" .. tostring(feather)
	if p.key == key then return width, height end
	p.key = key
	p.map, p.fogMode, p.bare, p.feather = id, fog, bare, feather
	Levels(p, art)
	if bare then
		p.ground:Hide()
		for _, frame in ipairs(p.frames) do frame:Hide() end
		for _, t in ipairs(p.bits) do t:Hide() end
		return width, height
	end

	-- The background the game lays round its art (twice the art's size, centred); none under a feathered
	-- map, which has the land round it instead.
	local atlas = not feather and C_Map.GetMapArtBackgroundAtlas(id)
	if atlas then
		p.ground:SetAtlas(atlas, false)
		p.ground:SetSize(width * 2, height * 2)
		p.ground:ClearAllPoints()
		p.ground:SetPoint("CENTER", p.canvas, "CENTER")
		p.ground:Show()
	else
		p.ground:Hide()
	end

	-- Base tiles, a frame per detail layer so a layer fades as one.
	for index, layer in ipairs(art) do
		local frame = p.frames[index]
		if not frame then
			frame = CreateFrame("Frame", nil, p.root)
			frame:SetAllPoints()
			frame:SetFrameLevel(p.level)
			p.frames[index] = frame
			p.tiles[index] = {}
		end
		frame:Show()
		local list = p.tiles[index]
		local across = math.ceil(layer.layerWidth / layer.tileWidth)
		local down = math.ceil(layer.layerHeight / layer.tileHeight)
		local files = C_Map.GetMapArtLayerTextures(id, index) or {}
		local used = 0
		for row = 1, down do
			for col = 1, across do
				used = used + 1
				local t = Texture(list, used, frame, "BACKGROUND", math.min(7, -8 + index))
				-- A layer of finer art is drawn at the first layer's size.
				local kx, ky = width / layer.layerWidth, height / layer.layerHeight
				t:SetSize(layer.tileWidth * kx, layer.tileHeight * ky)
				t:SetPoint("TOPLEFT", frame, "TOPLEFT", (col - 1) * layer.tileWidth * kx, -(row - 1) * layer.tileHeight * ky)
				t:SetTexture(files[used], nil, nil, "TRILINEAR")
				t:SetVertexColor(1, 1, 1, 1)
				Feather(p, t, frame, feather)
			end
		end
		for i = used + 1, #list do list[i]:Hide() end
	end
	for index = #art + 1, #p.frames do p.frames[index]:Hide() end

	-- Overlays: explored ones from the game, the rest from the data.
	local tw, th = first.tileWidth, first.tileHeight
	local used, explored = 0, {}
	for _, piece in ipairs(C_MapExplorationInfo.GetExploredMapTextures(id) or {}) do
		local files = piece.fileDataIDs or {}
		if files[1] then explored[files[1]] = true end
		used = Overlay(p, used, piece.textureWidth, piece.textureHeight, piece.offsetX, piece.offsetY, files, 1, nil, tw, th,
			piece.isDrawOnTopLayer and 1 or 0, false)
	end
	local list = fog ~= "hidden" and ns.fog and ns.fog[C_Map.GetMapArtID(id)]
	if list then
		for _, o in ipairs(list) do
			if not explored[o[6]] then
				used = Overlay(p, used, o[1], o[2], o[3], o[4], o, 6, o[5], tw, th, -1, fog == "faded")
			end
		end
	end
	for i = 1, used do Feather(p, p.bits[i], p.fog, feather) end
	for i = used + 1, #p.bits do p.bits[i]:Hide() end
	p.used = used
	return width, height
end

-- The detail layer of the deepest level not past `zoom` shows; the next one in fades in towards its level.
function Art.Detail(p, zoom)
	local levels = p.levels
	if #levels == 0 then return end
	local at = 1
	for i, level in ipairs(levels) do
		if zoom + 1e-6 >= level.zoom then at = i else break end
	end
	local here, next = levels[at], levels[at + 1]
	local shown = here.layer
	local rising, rise = next and next.layer ~= shown and next.layer, 0
	if rising then rise = math.max(0, math.min(1, (zoom - here.zoom) / (next.zoom - here.zoom))) end
	for index, frame in ipairs(p.frames) do
		local a = index == shown and 1 or index == rising and rise or 0
		-- The first layer stays under any other: no gap shows while a finer one comes in.
		if index == 1 then a = 1 end
		frame:SetAlpha(a)
	end
end

local function Dim(p, k, overlays)
	for _, list in ipairs(p.tiles) do
		for _, t in ipairs(list) do t:SetVertexColor(k, k, k, 1) end
	end
	if not overlays then return end
	for i = 1, p.used or 0 do
		local t = p.bits[i]
		if t:IsDesaturated() then t:SetVertexColor(FADED[1] * k, FADED[2] * k, FADED[3] * k, 1) else t:SetVertexColor(k, k, k, 1) end
	end
end

-- A painter's art has all come in.
local function Ready(p)
	if not p or p.bare then return true end
	for index, list in ipairs(p.tiles) do
		if p.frames[index]:IsShown() then
			for _, t in ipairs(list) do
				if t:IsShown() and not t:IsObjectLoaded() then return false end
			end
		end
	end
	for i = 1, p.used or 0 do
		if not p.bits[i]:IsObjectLoaded() then return false end
	end
	return true
end

-- Seats a painter, with the art it holds, on another canvas at another level (the map left handed to the
-- sheet it fades out on, the painter that held that handed to the map coming in).
local function Seat(p, parent, level, over)
	p.canvas = parent
	p.root:SetParent(parent)
	p.root:ClearAllPoints()
	p.root:SetAllPoints(parent)
	p.level = level
	p.root:SetFrameLevel(level)
	for _, frame in ipairs(p.frames) do frame:SetFrameLevel(level) end
	p.fog:SetFrameLevel(over or level + 1)
	p.over = over
	for _, mask in pairs(p.masks) do
		mask:ClearAllPoints()
		mask:SetAllPoints(parent)
	end
	for i = 1, p.used or 0 do
		local t = p.bits[i]
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", parent, "TOPLEFT", t.shyX, -t.shyY)
	end
	p.ground:ClearAllPoints()
	p.ground:SetPoint("CENTER", parent, "CENTER")
end

-- The view's painters: the map's own, the continent under a zone, the zones round it (their own art, feathered,
-- so the land round a zone is as sharp as the zone, not its continent's art blown up), and the map just left,
-- fading. A step
-- between maps never shows a gap: the art left keeps its pictures (its painter moves to the fading sheet
-- whole), and the new art comes in only once its pictures have all loaded, the continent staying under it
-- until then.

local painter, under, ghost
local underSheet, ghostSheet
local LayFills                         -- (below: the painted land laid)
local wash                             -- the continent's wash under its art: { sheet, texture, map }
local fills = { of = {} }              -- the painted land: { sheet, of = { [continent] = { fill } }, map }
local base                             -- the port's own level
local fadeIn, fadeOut = 1, 0           -- the map's own art coming in, the art left going out
local waiting = false                  -- the new art's pictures are still loading
local dropUnder = false                -- the continent under goes once the new art has come in

function Art.Painter() return painter end
function Art.Sheets() return under, underSheet, ghost, ghostSheet end
function Art.Wash() return wash end
function Art.Fills() return fills end

function Art.Loaded() return Ready(painter) end

local function Info(id) return id and C_Map.GetMapInfo(id) end

-- The continent a zone (or a city) lies on, when the two share a world.
local function Continent(id)
	local info = Info(id)
	if not (info and info.mapType == Enum.UIMapType.Zone) then return nil end
	while info and info.mapType > Enum.UIMapType.Continent do
		info = info.parentMapID and info.parentMapID > 0 and Info(info.parentMapID) or nil
	end
	local continent = info and info.mapType == Enum.UIMapType.Continent and info.mapID
	if continent and View.World(continent) == View.World(id) then return continent end
	return nil
end

-- The zones round the one shown: { { sheet, painter } } a pool, `roundUsed` of them in use.
local round, roundUsed = {}, 0

local function Round(i)
	local r = round[i]
	if r then return r end
	local sheet = CreateFrame("Frame", nil, View.Port())
	sheet:SetFrameLevel(base + 2)
	sheet:Hide()
	-- (Their paper under the map's own; their painting, which covers their ground alone, over the map's paper and the
	-- painted land: the land round a zone is painted where the zone's own picture has only blank paper.)
	r = { sheet = sheet, painter = Art.New(sheet, base + 2, base + 5) }
	round[i] = r
	return r
end

-- The continent's zones (asked of the game once).
local zonesOf = {}
local function Zones(continent)
	local list = zonesOf[continent]
	if list then return list end
	list = {}
	for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone) or {}) do
		if child.mapType == Enum.UIMapType.Zone and C_Map.GetMapArtLayers(child.mapID) then list[#list + 1] = child.mapID end
	end
	zonesOf[continent] = list
	return list
end

-- The zones whose ground lies in the window (VIEW past its edges too) besides the map's own, those most in view
-- first: as the view pans or zooms out the land in it is theirs, never the continent's art blown up.
local function Near(map, continent)
	local world, n0, w0, n1, w1 = View.World(map)
	if not (world and continent) then return {} end
	local left, right, top, bottom = View.Shown()
	local vw1, vw2 = w0 + left * (w1 - w0), w0 + right * (w1 - w0)
	local vn1, vn2 = n0 + top * (n1 - n0), n0 + bottom * (n1 - n0)
	local nlo, nhi, wlo, whi = math.min(vn1, vn2), math.max(vn1, vn2), math.min(vw1, vw2), math.max(vw1, vw2)
	local mn, mw = (nhi - nlo) * VIEW, (whi - wlo) * VIEW
	nlo, nhi, wlo, whi = nlo - mn, nhi + mn, wlo - mw, whi + mw
	local found = {}
	for _, id in ipairs(Zones(continent)) do
		if id ~= map then
			local cw, cn0, cw0, cn1, cw1 = View.World(id)
			if cw == world then
				local over = math.max(0, math.min(nhi, math.max(cn0, cn1)) - math.max(nlo, math.min(cn0, cn1)))
					* math.max(0, math.min(whi, math.max(cw0, cw1)) - math.max(wlo, math.min(cw0, cw1)))
				if over > 0 then found[#found + 1] = { id = id, d = -over } end
			end
		end
	end
	table.sort(found, function(a, b) return a.d < b.d end)
	for i = MOST_ROUND + 1, #found do found[i] = nil end
	return found
end

-- Each zone keeps its painter while it stays in the set (its pictures in): only a zone come into view is painted.
local roundKey
local function LayRound(map, continent)
	local list = continent and Near(map, continent) or {}
	local key = map .. ":" .. tostring(T.db.fog)
	for _, near in ipairs(list) do key = key .. "," .. near.id end
	if key == roundKey then return end
	roundKey = key
	local want, free = {}, {}
	for _, near in ipairs(list) do want[near.id] = true end
	for i = 1, #round do
		local r = round[i]
		if not (r.painter.map and want[r.painter.map] and r.painter.fogMode == T.db.fog) then free[#free + 1] = r end
	end
	local held = {}
	for i = 1, #round do
		local r = round[i]
		if r.painter.map and want[r.painter.map] and r.painter.fogMode == T.db.fog then held[r.painter.map] = r end
	end
	roundUsed = 0
	local used = {}
	for _, near in ipairs(list) do
		local r = held[near.id]
		if not r then
			r = table.remove(free, 1) or Round(#round + 1)
			Art.Paint(r.painter, near.id, T.db.fog, false, true)
			Art.Detail(r.painter, 1)
			Dim(r.painter, ROUND, true)
		end
		used[r] = true
		r.sheet:Show()
		roundUsed = roundUsed + 1
	end
	-- (In use first in the list, the rest put away.)
	local order = {}
	for _, r in ipairs(round) do if used[r] then order[#order + 1] = r end end
	for _, r in ipairs(round) do
		if not used[r] then
			order[#order + 1] = r
			r.sheet:Hide()
		end
	end
	for i, r in ipairs(order) do round[i] = r end
end

-- The zones drawn round the one shown: their map IDs.
function Art.Round()
	local list = {}
	for i = 1, roundUsed do
		if round[i].sheet:IsShown() then list[#list + 1] = round[i].painter.map end
	end
	return list
end

-- How many times too large the continent's art under the zone shown is drawn (port units an art pixel of it).
local function Blown()
	local map = View.Map()
	local _, n0, w0, n1, w1 = View.World(map)
	local _, cn0, cw0, cn1, cw1 = View.World(under and under.map)
	if not (n0 and cn0) or w0 == w1 then return 0 end
	return View.Scale() * math.abs(cw1 - cw0) / math.abs(w1 - w0)
end

-- The paper under a zone's art where the continent's art has faded: nil where it doesn't lie.
function Art.Paper()
	return painter and painter.feather and not painter.bare and PAPER or nil
end

-- The painted land on `continent` ({ prefix, box = { left, top, right, bottom } in its shares, size, columns, tiles }),
-- those whose middle lies on it (asked of the game once).
local function FillsOf(continent)
	local list = fills.of[continent]
	if list then return list end
	list = {}
	fills.of[continent] = list
	local data = ns.data and ns.data.gapFills
	local l, r, t, b = C_Map.GetMapRectOnMap(continent, C_Map.GetFallbackWorldMapID())
	if not (data and l and r and t and b and r > l and b > t) then return list end
	for _, x in ipairs(data) do
		local box = x[2]
		local u0, v0 = (box[1] - l) / (r - l), (box[2] - t) / (b - t)
		local u1, v1 = (box[3] - l) / (r - l), (box[4] - t) / (b - t)
		local mu, mv = (u0 + u1) / 2, (v0 + v1) / 2
		if mu > 0 and mu < 1 and mv > 0 and mv < 1 then
			list[#list + 1] = { prefix = x[1], box = { u0, v0, u1, v1 }, w = x[3], h = x[4], cols = x[5], tiles = x[6] }
		end
	end
	return list
end

-- A fill's pictures on the sheet (its continent's art, `aw` by `ah` pixels), the last column and row cut.
local function Tiles(fill, aw, ah)
	local u0, v0, u1, v1 = unpack(fill.box)
	local sx, sy = (u1 - u0) * aw / fill.w, (v1 - v0) * ah / fill.h
	fill.textures = {}
	for _, i in ipairs(fill.tiles) do
		local col, row = (i - 1) % fill.cols, math.floor((i - 1) / fill.cols)
		local pw, ph = math.min(TILE, fill.w - col * TILE), math.min(TILE, fill.h - row * TILE)
		local t = fills.sheet:CreateTexture(nil, "ARTWORK")
		t:SetTexture(GAP .. fill.prefix .. "_" .. i)
		t:SetTexCoord(0, pw / TILE, 0, ph / TILE)
		t:SetPoint("TOPLEFT", fills.sheet, "TOPLEFT", u0 * aw + col * TILE * sx, -(v0 * ah + row * TILE * sy))
		t:SetSize(pw * sx, ph * sy)
		fill.textures[#fill.textures + 1] = t
	end
end

-- The painted land on the continent under the zone shown (nil: none), those in the window shown.
LayFills = function(continent)
	local list = continent and ns.data and ns.data.gapFills and FillsOf(continent)
	if not (list and #list > 0 and View.LaySheet(fills.sheet, continent)) then
		fills.sheet:Hide()
		return
	end
	local map = View.Map()
	local zx1, zx2, zy1, zy2 = C_Map.GetMapRectOnMap(map, continent)
	if not (zx1 and zx2 and zy1 and zy2) then
		fills.sheet:Hide()
		return
	end
	-- (The window in the continent's shares, VIEW past its edges.)
	local left, right, top, bottom = View.Shown()
	local x1, x2 = zx1 + left * (zx2 - zx1), zx1 + right * (zx2 - zx1)
	local y1, y2 = zy1 + top * (zy2 - zy1), zy1 + bottom * (zy2 - zy1)
	local mx, my = (x2 - x1) * VIEW, (y2 - y1) * VIEW
	x1, x2, y1, y2 = x1 - mx, x2 + mx, y1 - my, y2 + my
	local aw, ah = fills.sheet:GetWidth(), fills.sheet:GetHeight()
	for _, fill in ipairs(list) do
		local u0, v0, u1, v1 = unpack(fill.box)
		local seen = u1 > x1 and u0 < x2 and v1 > y1 and v0 < y2
		if seen and not fill.textures then Tiles(fill, aw, ah) end
		if fill.textures and fill.shown ~= seen then
			fill.shown = seen
			for _, t in ipairs(fill.textures) do t:SetShown(seen) end
		end
	end
	-- (Another continent's are put away.)
	if fills.map ~= continent then
		for id, other in pairs(fills.of) do
			if id ~= continent then
				for _, fill in ipairs(other) do
					if fill.textures and fill.shown then
						fill.shown = false
						for _, t in ipairs(fill.textures) do t:Hide() end
					end
				end
			end
		end
		fills.map = continent
	end
	fills.sheet:Show()
end

local function Sheets()
	if under and under.map and underSheet:IsShown() then
		local blown = Blown()
		underSheet:SetAlpha(math.max(0, math.min(1, (UNDER_FADE.to - blown) / (UNDER_FADE.to - UNDER_FADE.from))))
	end
	-- (The zones round follow what is in view: a pan or a zoom may bring others in.)
	if painter and painter.feather and View.Map() then LayRound(View.Map(), under and under.map) end
	if under and under.map and underSheet:IsShown() then
		if not View.LaySheet(underSheet, under.map) then underSheet:Hide() end
	end
	LayFills(under and under.map and underSheet:IsShown() and under.map or nil)
	-- (The wash lies under the continent's art wherever that lies, and only while it fades.)
	local washed = wash.map ~= nil and underSheet:IsShown() and underSheet:GetAlpha() < 1
	if washed and not View.LaySheet(wash.sheet, wash.map) then washed = false end
	wash.sheet:SetShown(washed)
	for i = 1, roundUsed do
		local r = round[i]
		if not View.LaySheet(r.sheet, r.painter.map) then r.sheet:Hide() end
	end
	if ghost and ghostSheet:IsShown() then
		if not (ghost.map and View.LaySheet(ghostSheet, ghost.map)) then ghostSheet:Hide() end
	end
end

-- keep: a step between maps is under way; the continent under stays until the new art has come in.
local function Repaint(keep)
	local map = View.Map()
	if not (painter and map) then return end
	local bare = ns.Terrain and ns.Terrain.Draws(map) or false
	local below = not bare and Continent(map)
	Art.Paint(painter, map, T.db.fog, bare, below and true or false)
	if not bare then Art.Detail(painter, View.Scale() / View.Fit()) end
	if below then
		if under.map ~= below or under.fogMode ~= T.db.fog then
			Art.Paint(under, below, T.db.fog, false, false)
			Art.Detail(under, 1)
			Dim(under, UNDER)
		end
		if wash.map ~= below then
			wash.map = ns.wash and ns.wash[below] and below or nil
			if wash.map then wash.texture:SetTexture(WASH .. below) end
		end
		underSheet:Show()
		dropUnder = false
	elseif keep and underSheet:IsShown() then
		dropUnder = true
	else
		underSheet:Hide()
		wash.sheet:Hide()
	end
	roundKey = nil
	LayRound(map, below)
	Sheets()
end

local function Build()
	-- The continent's wash (base - 1) under its art (base, its overlays base + 1); every zone's paper, the zones round
	-- (base + 2) under the map's own (base + 3); the painted land (base + 4); then every zone's painting, theirs
	-- (base + 5) under the map's (base + 6: the exploration level); the map left fading over all (base + 7, + 8).
	base = View.Level("PIN_FRAME_LEVEL_MAP_EXPLORATION") - 6
	painter = Art.New(View.Land(), base + 3, base + 6)
	local port = View.Port()
	underSheet = CreateFrame("Frame", nil, port)
	underSheet:SetFrameLevel(base)
	underSheet:Hide()
	under = Art.New(underSheet, base)
	-- (Under the continent's art, over the port's own ground.)
	wash = { sheet = CreateFrame("Frame", nil, port) }
	wash.sheet:SetFrameLevel(base - 1)
	wash.sheet:Hide()
	wash.texture = wash.sheet:CreateTexture(nil, "BACKGROUND")
	wash.texture:SetAllPoints()
	ghostSheet = CreateFrame("Frame", nil, port)
	ghostSheet:SetFrameLevel(base + 7)
	ghostSheet:Hide()
	ghost = Art.New(ghostSheet, base + 7)
	fills.sheet = CreateFrame("Frame", nil, port)
	fills.sheet:SetFrameLevel(base + 4)
	fills.sheet:Hide()
end

-- A step into another map of the world: the art left (with its pictures) goes to the fading sheet, the
-- painter that held what was there before takes the new map. Drawn only: terrain runs on unbroken.
local function Step(was, map)
	local drawn = not (ns.Terrain and (ns.Terrain.Draws(was) or ns.Terrain.Draws(map)))
	if not (drawn and was and View.World(was) and painter.map == was) then
		Repaint(false)
		return
	end
	local shown = painter.root:GetAlpha()
	painter, ghost = ghost, painter
	Seat(ghost, ghostSheet, base + 7)
	Seat(painter, View.Land(), base + 3, base + 6)
	ghost.root:SetAlpha(shown)
	ghostSheet:SetAlpha(1)
	ghostSheet:Show()
	-- The new art: unseen until all of it has come in (the continent under stays meanwhile).
	painter.root:SetAlpha(0)
	Repaint(true)
	waiting, fadeIn, fadeOut = true, 0, 1
end

ns.Layer({
	id = "art",
	Use = function(on)
		if on and not painter then Build() end
		if not on and ghostSheet then
			ghostSheet:Hide()
			underSheet:Hide()
			wash.sheet:Hide()
			fills.sheet:Hide()
			roundUsed = 0
			for _, r in ipairs(round) do r.sheet:Hide() end
		end
	end,
	Map = function()
		if View.rebased then
			Step(View.was, View.Map())
		else
			Repaint(false)
			ghostSheet:Hide()
			waiting, dropUnder = false, false
			fadeIn, fadeOut = 1, 0
			painter.root:SetAlpha(1)
		end
	end,
	Scale = function(s)
		if painter and View.Map() and not painter.bare then Art.Detail(painter, s / View.Fit()) end
		Sheets()
	end,
	Pan = Sheets,
	Close = function()
		if ghostSheet then ghostSheet:Hide() end
		waiting, dropUnder = false, false
		fadeIn, fadeOut = 1, 0
		if painter then painter.root:SetAlpha(1) end
	end,
	Tick = function(dt)
		if waiting then
			if not (Ready(painter) and (not underSheet:IsShown() or Ready(under))) then return end
			waiting = false
		end
		if fadeIn < 1 then
			fadeIn = math.min(1, fadeIn + dt / CROSS)
			painter.root:SetAlpha(fadeIn)
			return
		end
		if dropUnder then
			dropUnder = false
			underSheet:Hide()
			wash.sheet:Hide()
		end
		if fadeOut > 0 then
			fadeOut = math.max(0, fadeOut - dt / CROSS)
			ghostSheet:SetAlpha(fadeOut)
			if fadeOut == 0 then ghostSheet:Hide() end
		end
	end,
})

ns.OnApply(function()
	if not (painter and View.IsOpen()) then return end
	local map = View.Map()
	local bare = ns.Terrain and ns.Terrain.Draws(map) or false
	if painter.fogMode ~= T.db.fog or painter.bare ~= bare then Repaint(false) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("MAP_EXPLORATION_UPDATED")
events:SetScript("OnEvent", function()
	-- (What is explored changed: every painter lays its overlays again.)
	if painter then painter.key, under.key, ghost.key = nil, nil, nil end
	for _, r in ipairs(round) do r.painter.key, r.painter.map = nil, nil end
	if View.IsOpen() then Repaint(false) end
end)

