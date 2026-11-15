-- The capitals' rooms and the caves on the terrain look: the minimap's own picture of each room (Data/Indoors.lua),
-- laid over the ground where its building stands, turned as the building is. A city you are inside of
-- (Ironforge's halls, the Undercity) shows its rooms under ground whenever it is in view; a cave (a mine, a den,
-- a barrow) once the view is close (CAVE: the same zoom for every cave, big or small), easing in over the hill. Indoors in any
-- building or cave, the rooms of your floor round you take over: the rest of its rooms go, and a house's roof
-- gives way to its rooms.
--
--   Rooms.Lay(p, id, world, kx, ky, n0, w0, westL, westR, northT, northB, near)   (from Terrain.Lay: near is
--                                    port units a yard)
--   Rooms.Clear(p)
--   Rooms.Look()                     where you are, looked at again (the map's layer does it while open)
--   Rooms.Here() -> building, shown  the building you are in and its rooms shown ({ [room] = true }), or nil

local ADDON, ns = ...
local View, Terrain = ns.View, ns.Terrain

local Rooms = {}
ns.Rooms = Rooms

local STEP = 128            -- yards a side of a room's block
local PIXELS = 2            -- a room picture's pixels a yard
local NEAR = 3              -- yards over or under a room's floors that are still on its floor
local TOUCH = 2             -- yards apart two rooms' boxes may be and still lead into each other
-- The game's pictures have no smaller sizes of their own, so ours stand in further out (Media/Rooms: a
-- quarter, then a sixteenth of each side): each is shown down to a quarter of a pixel a port unit.
local SIZES = { { near = 1, path = nil }, { near = 0.25, path = "_1" }, { near = 1 / 16, path = "_2" } }
local SHOW = 1 / 32         -- port units a yard from which rooms are laid at all
local SMALLER = "Interface\\AddOns\\ShyMaps\\Media\\Rooms\\"
local LOOK = 0.5            -- seconds between looks at where you are
local FADE = 0.3            -- seconds a room takes to come in or go as you go in or out
local MARGIN = 0.5          -- a building is laid while within this share of the view past its edges
local LAYER = "BORDER"      -- over the ground's pictures; a building's rooms by their floors' height, lowest first
local KIND = { building = 0, city = 1, cave = 2 }   -- what a building is (its 7th field)
-- A cave shows its rooms under ground once the view is this close (port units a yard: about twice a zone's whole
-- map), whatever its size: a one-room den comes in with a town-sized cavern, and neither covers its zone from afar.
local CAVE = { near = 0.2 }

-- A building: { north, west, x's north, x's west, y's north, y's west, kind (KIND), room, room ... }, a room
-- { x low, y low, x high, y high, floor low, floor high, under, bx, by, width, height, file, ... } in the
-- building's own yards. Made ready once: its rooms, its pictures, its box in the world.
local function Ready(b)
	if b.rooms then return b end
	local rooms, pictures = {}, {}
	local nlo, nhi, wlo, whi = math.huge, -math.huge, math.huge, -math.huge
	for i = 8, #b do
		local r = b[i]
		rooms[#rooms + 1] = r
		for j = 8, #r, 5 do pictures[#pictures + 1] = { b = b, r = r, at = j } end
		for k = 1, 4 do
			local x, y = k <= 2 and r[1] or r[3], (k % 2 == 1) and r[2] or r[4]
			local north, west = b[1] + x * b[3] + y * b[5], b[2] + x * b[4] + y * b[6]
			nlo, nhi, wlo, whi = math.min(nlo, north), math.max(nhi, north), math.min(wlo, west), math.max(whi, west)
		end
	end
	-- (Lowest floor first: a room over another is laid over it.)
	local order = {}
	for i, r in ipairs(rooms) do order[i] = r end
	table.sort(order, function(a, c) return a[5] < c[5] end)
	for i, r in ipairs(order) do r.sub = math.min(7, -8 + math.floor((i - 1) * 16 / #order)) end
	b.det = b[3] * b[6] - b[5] * b[4]
	b.nlo, b.nhi, b.wlo, b.whi = nlo, nhi, wlo, whi
	b.pictures = pictures
	b.rooms = rooms
	return b
end

-- A world spot in a building's own yards.
local function Own(b, north, west)
	local dn, dw = north - b[1], west - b[2]
	return (b[6] * dn - b[5] * dw) / b.det, (b[3] * dw - b[4] * dn) / b.det
end

local function Holds(r, x, y)
	return x >= r[1] - TOUCH and x <= r[3] + TOUCH and y >= r[2] - TOUCH and y <= r[4] + TOUCH
end

local function OnFloor(r, up)
	return up == nil or (up >= r[5] - NEAR and up <= r[6] + NEAR)
end

-- The rooms whose boxes meet each room's, worked out the first time someone is inside.
local function Next(b)
	if b.next then return b.next end
	local rooms, out = b.rooms, {}
	for i = 1, #rooms do out[rooms[i]] = {} end
	for i = 1, #rooms do
		local a = rooms[i]
		for j = i + 1, #rooms do
			local c = rooms[j]
			if a[1] - TOUCH <= c[3] and c[1] - TOUCH <= a[3] and a[2] - TOUCH <= c[4] and c[2] - TOUCH <= a[4] then
				local an, cn = out[a], out[c]
				an[#an + 1], cn[#cn + 1] = c, a
			end
		end
	end
	b.next = out
	return out
end

-- Where you are -----------------------------------------------------------------------------------------

local here = { stamp = 0 }      -- b: the building you are in; shown: its rooms shown; stamp: up at each change
local spare, queue = {}, {}
local lookedAt

-- The rooms of `b` shown while you stand at its x, y on a floor `up` high (nil: not known), into `into`;
-- false where you are in none of its rooms. Not knowing the floor in a city you are inside of, the city
-- shows as from outside.
local function Floor(b, x, y, up, into)
	local n = 0
	for _, r in ipairs(b.rooms) do
		if Holds(r, x, y) and OnFloor(r, up) then
			n = n + 1
			queue[n] = r
			into[r] = true
		end
	end
	if n == 0 or (up == nil and b[7] == KIND.city) then
		for i = 1, n do queue[i] = nil end
		wipe(into)
		return false
	end
	local near = Next(b)
	local i = 1
	while i <= n do
		for _, c in ipairs(near[queue[i]]) do
			if not into[c] and OnFloor(c, up) then
				n = n + 1
				queue[n] = c
				into[c] = true
			end
		end
		i = i + 1
	end
	for k = 1, n do queue[k] = nil end
	return true
end

local function Same(a, c)
	if a == c then return true end
	if not (a and c) then return false end
	for r in pairs(a) do if not c[r] then return false end end
	for r in pairs(c) do if not a[r] then return false end end
	return true
end

function Rooms.Look()
	lookedAt = GetTime()
	local found, shown
	local list
	if IsIndoors() then
		local world, north, west = Shy.Here(true)
		list = world and ns.indoors and ns.indoors[world]
		if list then
			local up = Shy.Way.Up(world)
			wipe(spare)
			for _, b in ipairs(list) do
				Ready(b)
				if north >= b.nlo - TOUCH and north <= b.nhi + TOUCH and west >= b.wlo - TOUCH and west <= b.whi + TOUCH then
					local x, y = Own(b, north, west)
					if Floor(b, x, y, up, spare) then
						found, shown = b, spare
						break
					end
				end
			end
		end
	end
	if found == here.b and Same(shown, here.shown) then return false end
	-- (The two sets trade places: the one just made is kept, the old one is the next to fill.)
	local old = here.shown
	here.b, here.shown = found, shown
	spare = old or {}
	if not shown then wipe(spare) end
	here.stamp = here.stamp + 1
	return true
end

function Rooms.Here()
	return here.b, here.shown
end

-- near: a cave spans enough of the view to show what lies under its hill.
local function Wanted(b, r, near)
	if here.b == b then return here.shown[r] == true end
	if b[7] == KIND.city or (b[7] == KIND.cave and near) then return r[7] == true end
	return false
end

-- Laying -------------------------------------------------------------------------------------------------

local fading = {}           -- texture -> its painter, while it comes in or goes
local fader = CreateFrame("Frame")

local function Free(p, t)
	t:Hide()
	fading[t] = nil
	p.roomSpare[#p.roomSpare + 1] = t
end

local function Fade(dt)
	local step = dt / FADE
	for t, p in pairs(fading) do
		local a = t.want > t.alpha and math.min(t.want, t.alpha + step) or math.max(t.want, t.alpha - step)
		t.alpha = a
		t:SetAlpha(a)
		if a == t.want then
			fading[t] = nil
			if a == 0 then
				p.roomsLaid[t.picture] = nil
				Free(p, t)
			end
		end
	end
	if next(fading) == nil then fader:SetScript("OnUpdate", nil) end
end

local function Ease(p, t, want)
	t.want = want
	if t.alpha == want then
		fading[t] = nil
		return
	end
	fading[t] = p
	fader:SetScript("OnUpdate", function(_, dt) Fade(dt) end)
end

-- A picture where its corners are: its rect the box round all four (the game culls a region by its rect),
-- each corner moved from that box's own. Canvas units, y up.
local function Stand(p, t, kx, ky, n0, w0)
	local pic = t.picture
	local b, r, at = pic.b, pic.r, pic.at
	local left, bottom = r[1] + r[at] * STEP, r[2] + r[at + 1] * STEP
	local right, top = left + r[at + 2] / PIXELS, bottom + r[at + 3] / PIXELS
	local on, ow, xn, xw, yn, yw = b[1], b[2], b[3], b[4], b[5], b[6]
	-- The picture's corners: its top runs along the room's high y, its left along the low x.
	local ulx, uly = (w0 - (ow + left * xw + top * yw)) * kx, (on + left * xn + top * yn - n0) * ky
	local llx, lly = (w0 - (ow + left * xw + bottom * yw)) * kx, (on + left * xn + bottom * yn - n0) * ky
	local urx, ury = (w0 - (ow + right * xw + top * yw)) * kx, (on + right * xn + top * yn - n0) * ky
	local lrx, lry = urx + llx - ulx, ury + lly - uly
	local x1, x2 = math.min(ulx, llx, urx, lrx), math.max(ulx, llx, urx, lrx)
	local y1, y2 = math.min(uly, lly, ury, lry), math.max(uly, lly, ury, lry)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", p.canvas, "TOPLEFT", x1, y2)
	t:SetSize(math.max(x2 - x1, 0.01), math.max(y2 - y1, 0.01))
	t:SetVertexOffset(UPPER_LEFT_VERTEX, ulx - x1, uly - y2)
	t:SetVertexOffset(LOWER_LEFT_VERTEX, llx - x1, lly - y1)
	t:SetVertexOffset(UPPER_RIGHT_VERTEX, urx - x2, ury - y2)
	t:SetVertexOffset(LOWER_RIGHT_VERTEX, lrx - x2, lry - y1)
end

-- The size of a room's pictures for port units a yard: an index of SIZES, or nil where none is laid.
local function SizeFor(near)
	for i, size in ipairs(SIZES) do
		if near >= size.near then return i end
	end
	return near >= SHOW and #SIZES or nil
end

local function Paint(t, size)
	local file = t.picture.r[t.picture.at + 4]
	local path = SIZES[size].path
	t:SetTexture(path and (SMALLER .. file .. path) or file, nil, nil, "LINEAR")
end

local function Take(p, pic, size)
	local t = table.remove(p.roomSpare)
	if not t then
		t = p.frame:CreateTexture(nil, LAYER)
		t:SetSnapToPixelGrid(false)
		t:SetTexelSnappingBias(0)
	end
	t:SetDrawLayer(LAYER, pic.r.sub)
	t.picture = pic
	Paint(t, size)
	t:Show()
	return t
end

function Rooms.Clear(p)
	local laid = p.roomsLaid
	if not laid then return end
	for pic, t in pairs(laid) do
		laid[pic] = nil
		Free(p, t)
	end
	wipe(p.roomsSeen)
	p.roomsMap, p.roomsStamp = nil, nil
end

function Rooms.Lay(p, id, world, kx, ky, n0, w0, westL, westR, northT, northB, nearBy)
	local size = SizeFor(nearBy)
	local list = size and ns.indoors and ns.indoors[world]
	if not p.roomsLaid then
		p.roomsLaid, p.roomsSeen, p.roomSpare = {}, {}, {}
	end
	if not list then
		if next(p.roomsLaid) then Rooms.Clear(p) end
		return
	end
	if not lookedAt or GetTime() - lookedAt >= LOOK then Rooms.Look() end
	-- Laid again where they stand when the map changes (the canvas is the map's art), and what shows when
	-- where you are does; else only a building coming into view or going out of it is touched.
	local moved = p.roomsMap ~= id or p.roomsWorld ~= world
	local swapped = p.roomsStamp ~= here.stamp
	local soft = swapped and not moved and p.roomsStamp ~= nil
	local laid, seen = p.roomsLaid, p.roomsSeen
	if p.roomsSize ~= size then
		p.roomsSize = size
		for _, t in pairs(laid) do Paint(t, size) end
	end
	local wide, tall = (westL - westR) * MARGIN, (northT - northB) * MARGIN
	for _, b in ipairs(list) do
		Ready(b)
		local inView = b.nlo <= northT + tall and b.nhi >= northB - tall and b.wlo <= westL + wide and b.whi >= westR - wide
		-- (A cave in view is laid again as it comes close enough to show, and as it goes.)
		local close = inView and b[7] == KIND.cave and nearBy >= CAVE.near
		local state = inView and (close and 2 or 1) or false
		local was = seen[b] or false
		if moved or swapped or state ~= was then
			local eased = soft or (not moved and inView and was ~= false and b[7] == KIND.cave)
			seen[b] = state
			for _, pic in ipairs(b.pictures) do
				local t = laid[pic]
				if inView and Wanted(b, pic.r, close) then
					if not t then
						t = Take(p, pic, size)
						laid[pic] = t
						Stand(p, t, kx, ky, n0, w0)
						t.alpha = eased and 0 or 1
						t:SetAlpha(t.alpha)
					elseif moved then
						Stand(p, t, kx, ky, n0, w0)
					end
					Ease(p, t, 1)
				elseif t then
					if eased and inView then
						if moved then Stand(p, t, kx, ky, n0, w0) end
						Ease(p, t, 0)
					else
						laid[pic] = nil
						Free(p, t)
					end
				end
			end
		end
	end
	p.roomsMap, p.roomsWorld, p.roomsStamp = id, world, here.stamp
end

-- While the map is open, where you are is looked at every LOOK seconds; a change lays the rooms again.
local since, told = 0, 0
ns.Layer({
	id = "rooms",
	Tick = function(dt)
		since = since + dt
		if since < LOOK then return end
		since = 0
		Rooms.Look()
		if told ~= here.stamp then
			told = here.stamp
			if Terrain.Refresh then Terrain.Refresh() end
		end
	end,
})
