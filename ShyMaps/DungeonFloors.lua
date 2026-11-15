-- The journal's place: a dungeon's rooms as the game's own pictures of them (laid by file), and for the few
-- rooms the game never pictured (the Deadmines' cove and its ship) pictures of our own, drawn from the rooms
-- themselves (Media\Floors), laid the same way; north up, with a numbered mark where each boss stands and one
-- where you come in. The whole dungeon is always
-- there: the floor you are on bright, the others dim round and under it with their bosses small on them (a cave
-- that winds over itself comes apart into floors, and one floor alone looked cut off at every edge). Where the
-- floor you are on leads onto another (a doorway of the dungeon's own model between the two) stands a small
-- mark with an arrow, up or down: a click goes to that floor, as a click on a boss of another floor does. It is read
-- as the map is: the wheel zooms about the mouse, a drag pans, a right click goes out a step (to the whole floor,
-- then to whatever the owner says is out). The game says nothing of where you are inside a dungeon, so this is a
-- picture to read, not a map that follows you. A room a boss stands in that the game has no picture of is drawn
-- as a quiet plate that says so, never left as a mark over nothing.
-- A dungeon that lies out of doors is its ground from above, the game's own overhead pictures, cut to the
-- ground that is the dungeon's; what lies under that ground (a crypt, a barrow, a city's sewers) is further
-- floors, laid round each other and never under the ground's picture (which shows its roofs, not them): one
-- that is a small part of what lies under opens framed.
-- A dungeon in several places far apart (a raid in four groves) has each as a floor that stands alone, under
-- its zone's name: no other is laid round it.
-- A dungeon the game has no floor of shows its own picture instead, its bosses a strip of the same marks along
-- its foot in the order you meet them: never a mark on ground that isn't the dungeon's. On a floor, the bosses
-- nothing places (a dungeon only this game has) are that strip at its foot, until they are met: a boss you
-- looted stands where you stood, where the game says that in there, else in the part of the dungeon the game
-- named as you met it (Stalker's Thicket), which the floor writes on its ground with the other parts' names.
-- The game says nothing of where you stand in a dungeon, but it names the room you are in (the words over the
-- minimap): the floor knows which of its pictures are that room, and which ground a named part is, so the room
-- you are in glows in your color, its name said at the sheet's top (`room`, its owner's word).
-- A dungeon whose data has no way in (one only this game has) shows where you came in yourself (J.Door), on
-- the floor that holds it, the nearest by height.
-- Every dungeon has the way through it: from the way in boss to boss in the order they are met, walked over the
-- dungeon's own ground when the data was made, and drawn as the family draws a way on any map (Shy.Maps, a
-- journey's even line in your color): the ways out to the bosses off it finer and fainter, the legs to bosses
-- already down this run fainter too, and the stretches of it on the floors round the one shown fainter still.
-- Where it goes from one floor onto another is the way between them, the small mark with the arrow.
-- A floor laid dim round the one shown is a click away: under the mouse it comes up in its colors, and a click
-- on it turns the place to it (each floor says where it is painted, `hit`), so two floors are looked at in turn
-- without the floors' choice.
-- An instance the Group Finder lists as several dungeons (Scarlet Monastery's four) has each as a wing: its
-- floors go by the wing's name and lie round each other, never round another wing's.
--   Floors.Of(map)               { { w, h (yards), tiles, bosses = { { index, x, y } }, door = { x, y },
--                                bare = { { x, y, width, depth } }, ox, oy (where it lies in the box round
--                                every floor), ways = { { to (a floor), up, x, y } }, alone (a place of its
--                                own, laid with no other), name (its zone's), under (it lies beneath the
--                                ground the first shows) }, w, h (that box's) } or nil
--   Floors.FloorOf(map, boss)    the floor a boss (by its place in the order) stands on, or nil
--   Floors.RoomFloor(map, name)  the floor a room or a named part of the ground is on (the first that has it)
--   Floors.Spots(map)            { [floor] = { { index, x, y, met = "looted" | a part's name | nil } } }, { [boss]
--                                = true }: where every boss stands, by the data and by what was met in play
--   Floors.Door(map)             floor, x, y: where you came in yourself (J.Door), on the floor that holds it; nil
--                                where the data has a way in, or you never came in
--   Floors.Label(map, floor, short)  what a floor goes by: its place's or its wing's name ("Cathedral 2" where
--                                the wing has more floors than one), "Ground" and "Below 2" where some lie
--                                under the ground, else "Floor 2"; short: its number alone
--   Floors.Wings(map)            the dungeons an instance is listed as, or nil for one that is one: { { index,
--                                name, short (the game's short name), low, high, floors = { floor, ... },
--                                bosses = { boss, ... } (those that stand on its floors) } }
--   Floors.WingOf(map, boss)     the wing a boss stands in, or nil
--   Floors.Named(map)            whether its floors go by more than their numbers
--   Floors.Pane(parent) -> pane  pane:Open(map, floor, { picked = boss, onBoss = function(index) end,
--                                    onDoor = function() end (a click on the way in), door = "Westfall" (where it
--                                    leads out to), onOut = function() end (a right click on the whole floor),
--                                    clear = units kept clear at its foot for what its owner stands in its
--                                    corners: the whole floor is fitted over them, the strip stands over them,
--                                    tones = { [boss] = color } (a mark's color: what the boss has for you),
--                                    onHover = function(boss, on) end (the mouse on a boss's mark, or off it),
--                                    onFloor = function(floor) end (a click on a way onto another floor),
--                                    room = the name of the room you stand in (it glows, and is named),
--                                    others = { [room] = { name, ... } } (who of your group is in which room:
--                                    those rooms glow paler, in blue, and are named with who is in them),
--                                    done = { [boss] = true } (down this run: its mark faint, a tick on it),
--                                    next = boss (the next one standing: its mark in your color) })
--                                pane:Hover(boss): the boss under the mouse on its owner's list (its mark lit)
--                                pane:Lay(width, height): its size, the floor fitted inside
--                                pane:Zoom(factor, x, y): closer or further, the point x, y of the sheet held
--                                pane:Whole(): the whole floor again    pane:Focus(boss): zoomed in, to that boss
--                                pane.floor, pane.count: the floor shown, and how many there are
--                                pane.strip: it shows the dungeon's picture and the strip, having no floor

local ADDON, ns = ...
local J = ns.Dungeons
local UI = Shy.UI
local C = UI.colors

ns.Journal = ns.Journal or {}
local Floors = {}
ns.Journal.Floors = Floors

local L = {
	frame = 3,                 -- this much of the housing shows round the sheet, inside the look's border
	pad = 8,                   -- clear round the floor, inside the sheet
	mark = 22, picked = 28,    -- a boss's mark, and the one whose page is open
	door = 20,                 -- the way in
	number = 11,               -- the number on a mark
	apart = 24,                -- marks nearer than this stand apart (bosses on one deck are a yard from each other)
	sunk = 26, shadow = 0.55,  -- the sheet is sunk: a shadow this deep in from each edge, this dark at the edge
	away = 16,                 -- the mark of a boss on a floor that isn't the one shown
	way = 16, arrow = 8,       -- a way onto another floor, and the arrow on it
	faint = 0.6,               -- ... how solid it and that floor's pictureless rooms are
	dim = 0.42,                -- how bright the pictures of a floor that isn't the one shown are
	hover = 0.82,              -- ... and of such a floor under the mouse, in its colors: a click away
	cell = 8,                  -- yards a side of the cells a floor says its paint by (`hit`)
	ground = 0.8,              -- how solid the sheet's ground is over the look's own face
	bare = 6,                  -- a pictureless room's words, in from its plate's corner
	most = 2,                  -- a floor fitted whole is drawn no larger than this a yard: its pictures' own pixels
	deep = 4,                  -- the wheel goes this many times closer than the whole floor
	small = 1.5,               -- a floor under the ground that fits this many times larger alone than in the
	                           -- whole opens framed
	wheel = 1.3,               -- a notch of the wheel
	click = 16,                -- a press that moves less than this (units, squared) is a click
	band = 86,                 -- the strip's dark band at the picture's foot
	caption = 10,              -- its caption's font
	stride = 46,               -- from one mark of the strip to the next, at the most
	least = 30,                -- ... and at the least, before the strip takes another line
	line = 34,                 -- from one line of the strip to the next
	order = 54,                -- the room the strip takes at a floor's foot
	part = 9, under = 15,      -- the name of a part of the dungeon, on its ground, this far under its place
	clear = { 70, 16 },        -- ... and moved under a mark that stands this near its middle (across, down)
	route = 3.4, side = 2.2,   -- the way through, and a way out to a boss off it (the pen's pixels)
	quiet = 0.7, gone = 0.35,  -- how solid a side way is, and a leg to a boss already down this run
	far = 0.3,                 -- ... and a stretch of the way on a floor round the one shown
	pale = 0.75,               -- how far toward steel the way to the last boss is: the way pales as it goes on
	lead = 1.2,                -- on a run, the stretch to the next boss is this many times as wide
	piece = 5,                 -- a piece of the way's line is no shorter than this: shorter ones can't be joined
	                           -- at their corners, and the line thinned to nothing where the way turned
	tick = 10, down = 0.5,     -- the tick on a boss down this run, and how solid its mark is
	rare = 16,                 -- a creature that is not always there
	glow = 0.45, lit = 0.2,    -- how much of your color the room you are in takes, and a named part of a ground
	theirs = 0.7,              -- ... and how much of that a room someone of your group is in takes, in blue
	you = 10,                  -- the words that say which room you are in
}
local NONE = {}
local OURS = "Interface\\AddOns\\ShyMaps\\Media\\Floors\\"   -- our own pictures of the rooms the game has none of
local floors = {}            -- map -> its floors, read (false: none)

local function Numbers(text, sep)
	local out = {}
	for field in (text .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do out[#out + 1] = tonumber(field) end
	return out
end

function Floors.Of(map)
	local found = floors[map]
	if found ~= nil then return found or nil end
	local data = ns.data and ns.data.dungeonFloors and ns.data.dungeonFloors[map]
	if not data then
		floors[map] = false
		return nil
	end
	found = {}
	for i, raw in ipairs(data) do
		local floor = { w = raw.w, h = raw.h, tiles = {}, bosses = {}, bare = {},
			alone = raw.alone == 1, name = raw.name, under = raw.under == 1, wing = raw.wing }
		for part in (raw.bare or ""):gmatch("[^;]+") do
			local n = Numbers(part, ":")
			if #n == 4 then floor.bare[#floor.bare + 1] = n end
		end
		for part in (raw.tiles or ""):gmatch("[^;]+") do
			local n = Numbers(part, ":")
			if #n == 7 then floor.tiles[#floor.tiles + 1] = n end
		end
		-- (Our own pictures: a tile as any other, its file ours by name.)
		for part in (raw.ours or ""):gmatch("[^;]+") do
			local name, rest = part:match("^([^:]+):(.+)$")
			local n = name and Numbers(rest, ":") or NONE
			-- (white_...: ground one of the game's pictures left unpainted, laid over that picture.)
			if #n == 6 then
				floor.tiles[#floor.tiles + 1] = { OURS .. name, n[1], n[2], n[3], n[4], n[5], n[6], name:find("^white_") ~= nil }
			end
		end
		for part in (raw.bosses or ""):gmatch("[^;]+") do
			local n = Numbers(part, ":")
			if #n == 3 then floor.bosses[#floor.bosses + 1] = { index = n[1], x = n[2], y = n[3] } end
		end
		if raw.door then
			local n = Numbers(raw.door, ":")
			floor.door = { x = n[1], y = n[2] }
		end
		-- Where it lies in the world (a place noted in play is set on it by this), and its parts' names.
		local from = raw.from and Numbers(raw.from, ":") or NONE
		floor.north, floor.west, floor.up = from[1], from[2], from[3] or 0
		floor.names = {}
		for part in (raw.names or ""):gmatch("[^;]+") do
			local name, x, y = part:match("^(.-)|([%d.-]+)|([%d.-]+)$")
			if name then floor.names[#floor.names + 1] = { name = name, x = tonumber(x), y = tonumber(y) } end
		end
		-- Where it lies among the others: its north-west corner in the box round them all.
		local at = raw.at and Numbers(raw.at, ":") or NONE
		floor.ox, floor.oy = at[1] or 0, at[2] or 0
		-- Where it leads onto another: the floor, whether that is up, and the place.
		floor.ways = {}
		for part in (raw.ways or ""):gmatch("[^;]+") do
			local n = Numbers(part, ":")
			if #n == 4 then floor.ways[#floor.ways + 1] = { to = n[1], up = n[2] == 1, x = n[3], y = n[4] } end
		end
		-- Its other ways in, and the creatures in it that are not always there.
		floor.doors, floor.rares = {}, {}
		for part in (raw.doors or ""):gmatch("[^;]+") do
			local x, y, what = part:match("^([%d.-]+):([%d.-]+):(.*)$")
			if x then floor.doors[#floor.doors + 1] = { x = tonumber(x), y = tonumber(y), what = what ~= "" and what or nil } end
		end
		for part in (raw.rares or ""):gmatch("[^;]+") do
			local name, x, y = part:match("^(.-)|([%d.-]+)|([%d.-]+)$")
			if name then floor.rares[#floor.rares + 1] = { name = name, x = tonumber(x), y = tonumber(y) } end
		end
		-- What the game calls its rooms (each the pictures that are it), and a ground's named parts (boxes).
		floor.rooms, floor.parts = {}, {}
		for part in (raw.rooms or ""):gmatch("[^;]+") do
			local name, held = part:match("^(.-)=([%d,]+)$")
			if name then floor.rooms[name] = Numbers(held, ",") end
		end
		for part in (raw.parts or ""):gmatch("[^;]+") do
			local name, held = part:match("^(.-)=(.+)$")
			if name then
				floor.parts[name] = {}
				for box in held:gmatch("[^,]+") do
					local n = Numbers(box, ":")
					if #n == 4 then floor.parts[name][#floor.parts[name] + 1] = n end
				end
			end
		end
		-- Where it is painted, for the mouse: by row, the runs of cells that have paint.
		floor.hit = {}
		for row, runs in (raw.hit or ""):gmatch("(%d+)=([^;]+)") do
			local held = {}
			for first, count in runs:gmatch("(%d+):(%d+)") do held[#held + 1] = { tonumber(first), tonumber(count) } end
			floor.hit[tonumber(row)] = held
		end
		-- The way through, the stretches of it on this floor: the boss each leads to, then its points.
		floor.paths = {}
		for _, kind in ipairs({ "main", "side" }) do
			for path in (raw[kind] or ""):gmatch("[^;]+") do
				local to, rest = path:match("^(%d+)|(.*)$")
				local points = {}
				for x, y in (rest or path):gmatch("([%d.-]+):([%d.-]+)") do
					points[#points + 1] = tonumber(x)
					points[#points + 1] = tonumber(y)
				end
				to = to and tonumber(to) or 0
				floor.paths[#floor.paths + 1] = { main = kind == "main", to = to > 0 and to or nil, points = points }
			end
		end
		found[i] = floor
	end
	-- Floors are laid round each other in sets, each in the box round its own: a wing's with its wing's, what
	-- lies under the ground with what else lies under it, a floor that stands alone by itself. Where a floor
	-- lies (ox, oy) is from its set's corner.
	found.spans = {}
	for i, floor in ipairs(found) do
		floor.set = floor.alone and ("alone" .. i) or ((floor.wing or 0) .. (floor.under and "u" or ""))
		local span = found.spans[floor.set] or { x = floor.ox, y = floor.oy, w = 1, h = 1 }
		found.spans[floor.set] = span
		span.x, span.y = math.min(span.x, floor.ox), math.min(span.y, floor.oy)
	end
	for _, floor in ipairs(found) do
		local span = found.spans[floor.set]
		floor.ox, floor.oy = floor.ox - span.x, floor.oy - span.y
		span.w, span.h = math.max(span.w, floor.ox + floor.w), math.max(span.h, floor.oy + floor.h)
	end
	local first = found[1] and found.spans[found[1].set]
	found.w, found.h = first and first.w or 1, first and first.h or 1
	floors[map] = found
	return found
end

-- Whether a floor is painted at a place of it (yards from its north-west corner).
function Floors.Painted(floor, x, y)
	if x < 0 or y < 0 or x > floor.w or y > floor.h then return false end
	local col = math.floor(x / L.cell)
	for _, run in ipairs(floor.hit[math.floor(y / L.cell)] or NONE) do
		if col >= run[1] and col < run[1] + run[2] then return true end
	end
	return false
end

-- Whether two floors are laid round each other: they are of one set.
local function Beside(all, a, b)
	return all[a].set == all[b].set
end

function Floors.Wings(map)
	local raw = ns.data and ns.data.dungeonWings and ns.data.dungeonWings[map]
	local all = raw and Floors.Of(map)
	if not all then return nil end
	local wings = {}
	for part in raw:gmatch("[^;]+") do
		local name, short, low, high = part:match("^(.-)%^(.-)%^(%d+)%^(%d+)$")
		if name then
			wings[#wings + 1] = { index = #wings + 1, name = name, short = short, low = tonumber(low), high = tonumber(high),
				floors = {}, bosses = {} }
		end
	end
	local spots = Floors.Spots(map)
	for i, floor in ipairs(all) do
		local wing = floor.wing and wings[floor.wing]
		if wing then
			wing.floors[#wing.floors + 1] = i
			for _, spot in ipairs(spots[i]) do wing.bosses[#wing.bosses + 1] = spot.index end
		end
	end
	for _, wing in ipairs(wings) do table.sort(wing.bosses) end
	return wings
end

function Floors.WingOf(map, boss)
	local all, floor = Floors.Of(map), Floors.FloorOf(map, boss)
	return all and floor and all[floor].wing or nil
end

function Floors.Named(map)
	for _, floor in ipairs(Floors.Of(map) or NONE) do
		if floor.name or floor.under then return true end
	end
	return false
end

function Floors.Label(map, index, short)
	local all = Floors.Of(map)
	local floor = all and all[index]
	if not floor or short then return tostring(index) end
	if floor.name and floor.wing then
		-- (A wing with more floors than one: numbered within it.)
		local count, place = 0, 0
		for i, other in ipairs(all) do
			if other.wing == floor.wing then
				count = count + 1
				if i == index then place = count end
			end
		end
		return count > 1 and ("%s %d"):format(floor.name, place) or floor.name
	end
	if floor.name then return floor.name end
	local under, place = 0, 0
	for i, other in ipairs(all) do
		if other.under then
			under = under + 1
			if i == index then place = under end
		end
	end
	if floor.under then return under > 1 and ("Below %d"):format(place) or "Below" end
	if under > 0 then return "Ground" end
	return ("Floor %d"):format(index)
end

-- Where every boss stands: the data's word, and for one it has no place for, where it was met in play: the
-- place you looted it at on the floor that holds it (the nearest by height), else the middle of the part of the
-- dungeon it was met in, by that part's name.
function Floors.Spots(map)
	local all = Floors.Of(map)
	if not all then return nil end
	local spots, placed = {}, {}
	for i, floor in ipairs(all) do
		spots[i] = {}
		for _, spot in ipairs(floor.bosses) do
			spots[i][#spots[i] + 1] = spot
			placed[spot.index] = true
		end
	end
	local book = J.Book(map)
	for index = 1, book and #book.bosses or 0 do
		if not placed[index] then
			local at, part = J.Met(map, index)
			local best, x, y, far
			if at then
				for i, floor in ipairs(all) do
					local fx, fy = floor.west and floor.west - at[2], floor.north and floor.north - at[1]
					if fx and fx >= 0 and fy >= 0 and fx <= floor.w and fy <= floor.h then
						local off = math.abs(floor.up - (at[3] or 0))
						if not far or off < far then best, x, y, far = i, fx, fy, off end
					end
				end
			end
			local met = best and "looted" or nil
			if not best and part then
				for i, floor in ipairs(all) do
					for _, named in ipairs(floor.names) do
						if named.name == part then best, x, y, met = i, named.x, named.y, part end
					end
					-- (A room the game names, in a dungeon of rooms: the middle of its first picture.)
					local tile = not best and floor.rooms[part] and floor.tiles[floor.rooms[part][1]]
					if tile then
						best, met = i, part
						x = math.max(0, math.min(floor.w, (tile[4] + tile[6]) / 2))
						y = math.max(0, math.min(floor.h, (tile[5] + tile[7]) / 2))
					end
					if best then break end
				end
			end
			if best then
				spots[best][#spots[best] + 1] = { index = index, x = x, y = y, met = met }
				placed[index] = true
			end
		end
	end
	return spots, placed
end

function Floors.Door(map)
	local all = Floors.Of(map)
	local at = all and J.Door(map)
	if not at then return nil end
	for _, floor in ipairs(all) do
		if floor.door then return nil end
	end
	local best, x, y, far
	for i, floor in ipairs(all) do
		local fx, fy = floor.west and floor.west - at[2], floor.north and floor.north - at[1]
		if fx and fx >= 0 and fy >= 0 and fx <= floor.w and fy <= floor.h then
			local off = math.abs((floor.up or 0) - (at[3] or 0))
			if not far or off < far then best, x, y, far = i, fx, fy, off end
		end
	end
	if best then return best, x, y end
end

function Floors.RoomFloor(map, name)
	for i, floor in ipairs(name and Floors.Of(map) or NONE) do
		if floor.rooms[name] or floor.parts[name] then return i end
	end
end

function Floors.FloorOf(map, boss)
	for i, floor in ipairs(Floors.Spots(map) or NONE) do
		for _, spot in ipairs(floor) do
			if spot.index == boss then return i end
		end
	end
end

-- A boss's mark: the family's mark, as the dungeon's own on the world's map, its number on it: in the color of
-- what it has for you (its owner's word, `tones`), lit for the one whose page is open and the one under the
-- mouse, here or on its owner's list. The way in is one too, signed.
local STEEL, GRAPHITE = { 0.74, 0.74, 0.78 }, { 0.08, 0.08, 0.09 }
local SILVER = { 0.62, 0.76, 0.92 }   -- a creature that is not always there
Floors.STEEL, Floors.GRAPHITE = STEEL, GRAPHITE   -- a mark with nothing to say for itself, and the number on a lit one
local function Mark(pane)
	local mark = CreateFrame("Button", nil, pane.sheet)
	mark:SetFrameLevel(pane.sheet:GetFrameLevel() + 5)
	mark.badge = Shy.Maps.Mark(mark, L.mark)
	mark.badge:SetAllPoints()
	mark.text = mark.badge:CreateFontString(nil, "OVERLAY")
	mark.text:SetFont(Shy.FONT_ROUNDED, L.number, "")
	mark.text:SetPoint("CENTER", 0, 0)
	-- (A way onto another floor wears an arrow: the family's caret, drawn pointing down, turned for up.)
	mark.arrow = mark.badge:CreateTexture(nil, "OVERLAY")
	mark.arrow:SetSize(L.arrow, L.arrow)
	mark.arrow:SetPoint("CENTER")
	mark.arrow:SetTexture(Shy.Skin.GLYPH.caret)
	mark.arrow:Hide()
	-- (A boss down this run wears a tick where its number was.)
	mark.tick = mark.badge:CreateTexture(nil, "OVERLAY")
	mark.tick:SetSize(L.tick, L.tick)
	mark.tick:SetPoint("CENTER")
	mark.tick:SetTexture(Shy.Skin.GLYPH.tick)
	mark.tick:Hide()
	mark:SetScript("OnEnter", function(self)
		self.hover = true
		if self.index then
			pane.hot = self.index
			if pane.onHover then pane.onHover(self.index, true) end
		end
		pane:Paint()
		local hints
		if self.way then
			if pane.onFloor then hints = { { "left", "Go to that floor" } } end
		elseif self.index then
			if self.index ~= pane.picked then hints = { { "left", "Open its page" } } end
		elseif pane.onDoor and not self.rare then
			hints = { { "left", "Show it on the map" } }
		end
		UI.Tip(self, self.name, self.under, { side = "TOP", hints = hints })
	end)
	mark:SetScript("OnLeave", function(self)
		self.hover = false
		if self.index then
			if pane.hot == self.index then pane.hot = nil end
			if pane.onHover then pane.onHover(self.index, false) end
		end
		pane:Paint()
		UI.TipHide(self)
	end)
	mark:SetScript("OnClick", function(self)
		if self.way then
			if pane.onFloor then pane.onFloor(self.way) end
		elseif self.index then
			if pane.onBoss then pane.onBoss(self.index) end
		elseif pane.onDoor and not self.rare then
			pane.onDoor()
		end
	end)
	return mark
end

function Floors.Pane(parent)
	local pane = CreateFrame("Frame", nil, parent)
	UI.Panel(pane, { looks = true, brackets = false, line = false })
	local sheet = CreateFrame("Frame", nil, pane)
	sheet:SetFrameLevel(pane:GetFrameLevel() + 1)
	-- The sheet is sunk into the housing: no line round it, its ground the look's own face darkened (the theme's
	-- stone, wood or sky still there under it), a shadow in from each edge.
	sheet.ground = sheet:CreateTexture(nil, "BACKGROUND", nil, -8)
	sheet.ground:SetAllPoints()
	UI.Paint(sheet.ground, C.bg, L.ground)
	for _, side in ipairs({ { "TOP", "VERTICAL", false }, { "BOTTOM", "VERTICAL", true }, { "LEFT", "HORIZONTAL", true }, { "RIGHT", "HORIZONTAL", false } }) do
		local shadow = sheet:CreateTexture(nil, "BACKGROUND", nil, 2)
		shadow:SetColorTexture(1, 1, 1, 1)
		local across = side[2] == "VERTICAL"
		shadow:SetPoint(across and (side[1] .. "LEFT") or ("TOP" .. side[1]))
		shadow:SetPoint(across and (side[1] .. "RIGHT") or ("BOTTOM" .. side[1]))
		if across then shadow:SetHeight(L.sunk) else shadow:SetWidth(L.sunk) end
		-- (Dark at the sheet's edge: a gradient's first color is its foot, or its left.)
		local dark, clear = CreateColor(0, 0, 0, L.shadow), CreateColor(0, 0, 0, 0)
		shadow:SetGradient(side[2], side[3] and dark or clear, side[3] and clear or dark)
	end
	sheet:SetClipsChildren(true)
	sheet:EnableMouse(true)
	pane.sheet = sheet
	-- The floor's pictures lie on a frame of their own, laid for the zoom: a pan moves that one frame.
	local land = CreateFrame("Frame", nil, sheet)
	land:SetSize(1, 1)
	-- (It is the box round the floors laid, and cuts their pictures to it: a ground's pictures are whole blocks
	-- of the world, and run on past the ground that is the dungeon's.)
	land:SetClipsChildren(true)
	pane.land = land
	pane.tiles, pane.marks, pane.bare, pane.links, pane.parts, pane.strokes, pane.glows = {}, {}, {}, {}, {}, {}, {}
	-- (The names of a floor's parts: written on its ground, under every mark.)
	local written = CreateFrame("Frame", nil, sheet)
	written:SetAllPoints()
	written:SetFrameLevel(sheet:GetFrameLevel() + 2)
	pane.width, pane.height = 300, 300
	pane.zoom, pane.clear = 1, 0
	-- (The way through: the family's pen, on the frame the sheet clips, under every mark and name.)
	local pen = Shy.Maps.Pen(written, "TOPLEFT", sheet, true)
	pane.pen = pen

	-- With no floor: the dungeon's own picture, dark toward its foot where the strip stands under its caption.
	local art = sheet:CreateTexture(nil, "BACKGROUND")
	art:SetPoint("TOPLEFT", 1, -1)
	art:SetPoint("BOTTOMRIGHT", -1, 1)
	-- (The strip's band, caption and lines: on a frame over the land, since the strip stands over a floor too.)
	local over = CreateFrame("Frame", nil, sheet)
	over:SetAllPoints()
	over:SetFrameLevel(sheet:GetFrameLevel() + 3)
	local shade = over:CreateTexture(nil, "BORDER")
	shade:SetPoint("BOTTOMLEFT", 1, 1)
	shade:SetPoint("BOTTOMRIGHT", -1, 1)
	shade:SetColorTexture(1, 1, 1, 1)
	shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.92), CreateColor(0, 0, 0, 0))
	local caption = over:CreateFontString(nil, "OVERLAY")
	caption:SetFontObject(UI.NameFont(L.caption))
	caption:SetText("IN THE ORDER YOU MEET THEM")
	UI.Ink(caption, C.text)
	pane.art, pane.shade, pane.caption = art, shade, caption
	-- (Which room you are in, at the sheet's top: said where the floor shown has it.)
	local you = over:CreateFontString(nil, "OVERLAY")
	you:SetFontObject(UI.NameFont(L.you))
	you:SetPoint("TOP", sheet, "TOP", 0, -8)
	you:SetShadowColor(0, 0, 0, 0.9)
	you:SetShadowOffset(1, -1)
	you:Hide()
	pane.you = you
	-- (Who of your group is in which room, under it.)
	local them = over:CreateFontString(nil, "OVERLAY")
	them:SetFontObject(UI.NameFont(L.you - 1))
	them:SetShadowColor(0, 0, 0, 0.9)
	them:SetShadowOffset(1, -1)
	them:Hide()
	pane.them = them

	-- The sheet stands inside the look's border and a little of the housing, which is told where it stands.
	local function Frame()
		local rim = math.max(UI.LookBorder(pane.shyLook)) + L.frame
		if rim == pane.rim then return rim end
		pane.rim = rim
		sheet:ClearAllPoints()
		sheet:SetPoint("TOPLEFT", rim, -rim)
		sheet:SetPoint("BOTTOMRIGHT", -rim, rim)
		UI.LookContent(pane.shyLook, { rim, rim, rim, rim })
		return rim
	end

	-- The room the floor has inside the sheet.
	local function Room()
		local rim = Frame()
		-- (Its foot is kept for what stands in its corners, and for the strip where the bosses stand in one.)
		return math.max(1, pane.width - 2 * rim - 2 * L.pad),
			math.max(1, pane.height - 2 * rim - 2 * L.pad - pane.clear - (pane.unplaced and L.order or 0))
	end

	-- The box the floor shown lies in: the one round every floor, or its own where it stands alone.
	local function Span()
		local span = pane.all.spans[pane.shown.set]
		return span.w, span.h
	end

	function pane:Paint()
		for i = 1, self.shownMarks or 0 do
			local mark = self.marks[i]
			local index = mark.index
			-- (One on another floor: small and faint, until it is the one opened or under the mouse.)
			local lit = index ~= nil and (index == self.picked or index == self.hot) or (index == nil and mark.hover == true)
			local away = mark.floor ~= self.floor and not lit
			local size = (mark.way and L.way) or (mark.rare and L.rare) or (index and index == self.picked and L.picked)
				or (away and L.away) or (index and L.mark) or L.door
			mark:SetSize(size, size)
			mark:SetAlpha(away and L.faint or 1)
			mark.arrow:SetShown(mark.way ~= nil)
			mark.tick:Hide()
			if mark.way then
				-- A way onto another floor: your color, its arrow up or down.
				mark.badge:Set(nil, Shy.Theme.Accent, lit)
				mark.text:SetText("")
				mark.arrow:SetRotation(mark.up and math.pi or 0)
				if lit then UI.Tint(mark.arrow, GRAPHITE) else UI.Tint(mark.arrow, Shy.Theme.Accent) end
			elseif mark.rare then
				-- One that is not always there: small and silver, an R on it.
				mark.badge:Set(nil, SILVER, mark.hover == true)
				mark.text:SetFont(Shy.FONT_ROUNDED, L.number - 2, "")
				mark.text:SetText("R")
				UI.Ink(mark.text, mark.hover and GRAPHITE or SILVER)
			elseif index then
				-- (Down this run: faint, a tick for its number. The next one standing: in your color.)
				local down = self.done ~= nil and self.done[index] == true
				local color = (self.next == index and Shy.Theme.Accent) or (self.tones and self.tones[index]) or STEEL
				mark.badge:Set(nil, color, lit)
				mark.text:SetFont(Shy.FONT_ROUNDED, away and L.number - 2 or L.number, "")
				-- (Its number: which boss of the run it is.)
				mark.text:SetText(down and "" or J.Step(self.map, index))
				UI.Ink(mark.text, lit and GRAPHITE or color)
				mark.tick:SetShown(down)
				if down then
					UI.Tint(mark.tick, lit and GRAPHITE or color)
					if not lit then mark:SetAlpha(L.down) end
				end
			else
				mark.badge:Set("go", C.good, lit)
				mark.text:SetText("")
			end
		end
	end

	-- The boss under the mouse on its owner's list (nil: none): its mark lit here too.
	function pane:Hover(index)
		if self.hot == index then return end
		self.hot = index
		self:Paint()
	end

	local function Take(used)
		local mark = pane.marks[used]
		if not mark then
			mark = Mark(pane)
			pane.marks[used] = mark
		end
		mark.hover, mark.rare = false, nil
		mark:Show()
		return mark
	end

	-- Every floor's pictures, each where its corners are at `k` units a yard: its rect the box round all four,
	-- each corner moved from that box's own (a model may be turned any way). The land's units, y down from its
	-- top. The floor shown (`at`) is laid bright over the others, which are dim and without their color.
	-- A picture where its corners are at `k` units a yard on its floor: its rect the box round all four, each
	-- corner moved from that box's own.
	local function Corners(t, floor, tile, k)
		local ulx, uly = (floor.ox + tile[2]) * k, (floor.oy + tile[3]) * k
		local llx, lly = (floor.ox + tile[4]) * k, (floor.oy + tile[5]) * k
		local urx, ury = (floor.ox + tile[6]) * k, (floor.oy + tile[7]) * k
		local lrx, lry = urx + llx - ulx, ury + lly - uly
		local x1, x2 = math.min(ulx, llx, urx, lrx), math.max(ulx, llx, urx, lrx)
		local y1, y2 = math.min(uly, lly, ury, lry), math.max(uly, lly, ury, lry)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", land, "TOPLEFT", x1, -y1)
		t:SetSize(math.max(x2 - x1, 0.01), math.max(y2 - y1, 0.01))
		t:SetVertexOffset(UPPER_LEFT_VERTEX, ulx - x1, -(uly - y1))
		t:SetVertexOffset(LOWER_LEFT_VERTEX, llx - x1, y2 - lly)
		t:SetVertexOffset(UPPER_RIGHT_VERTEX, urx - x2, -(ury - y1))
		t:SetVertexOffset(LOWER_RIGHT_VERTEX, lrx - x2, y2 - lry)
		t:Show()
	end

	local function Tiles(all, at, k)
		if pane.laid == all and pane.laidAt == at and pane.laidK == k and pane.laidRoom == pane.room
			and pane.laidOthers == pane.othersKey and pane.laidOver == pane.over then return end
		pane.laid, pane.laidAt, pane.laidK, pane.laidRoom, pane.laidOthers = all, at, k, pane.room, pane.othersKey
		pane.laidOver = pane.over
		local spanW, spanH = Span()
		land:SetSize(math.max(spanW * k, 1), math.max(spanH * k, 1))
		local used = 0
		for index, floor in ipairs(all) do
			local here = index == at
			-- (A floor that stands alone is laid with no other, and round no other; a wing's with its wing's.)
			for _, tile in ipairs(Beside(all, index, at) and floor.tiles or NONE) do
				used = used + 1
				local t = pane.tiles[used]
				if not t then
					t = land:CreateTexture(nil, "ARTWORK")
					pane.tiles[used] = t
				end
				t:SetTexture(tile[1])
				-- (Ground laid over a picture lies over the pictures of its floor.)
				t:SetDrawLayer("ARTWORK", (here and 1 or 0) + (tile[8] and here and 1 or 0))
				-- (A floor under the mouse comes up in its colors: a click turns the place to it.)
				local hot = index == pane.over
				t:SetDesaturated(not here and not hot)
				local light = here and 1 or (hot and L.hover or L.dim)
				t:SetVertexColor(light, light, light, 1)
				Corners(t, floor, tile, k)
			end
		end
		for i = used + 1, #pane.tiles do pane.tiles[i]:Hide() end
		-- The room you stand in, on the floor shown: its own pictures again in your color, added to them (the
		-- room's shape, not a box round it); a named part of a ground, its boxes.
		local glows = 0
		local floor = all[at]
		local accent = { Shy.Theme.Accent() }
		local function Glow()
			glows = glows + 1
			local g = pane.glows[glows]
			if not g then
				g = land:CreateTexture(nil, "ARTWORK", nil, 3)
				g:SetBlendMode("ADD")
				pane.glows[glows] = g
			end
			return g
		end
		local function Light(room, color, share)
			for _, index in ipairs(room and floor.rooms[room] or NONE) do
				local tile = floor.tiles[index]
				if tile then
					local g = Glow()
					g:SetTexture(tile[1])
					g:SetDesaturated(true)
					g:SetVertexColor(color[1], color[2], color[3], L.glow * share)
					Corners(g, floor, tile, k)
				end
			end
			for _, box in ipairs(room and floor.parts[room] or NONE) do
				local g = Glow()
				g:SetColorTexture(1, 1, 1, 1)
				g:SetVertexColor(color[1], color[2], color[3], L.lit * share)
				Corners(g, floor, { nil, box[1], box[2], box[1], box[2] + box[4], box[1] + box[3], box[2] }, k)
			end
		end
		-- (Your group's rooms first, paler and blue; yours over them.)
		for room in pairs(pane.others or NONE) do
			if room ~= pane.room then Light(room, SILVER, L.theirs) end
		end
		Light(pane.room, accent, 1)
		for i = glows + 1, #pane.glows do pane.glows[i]:Hide() end
	end

	-- Stands the dungeon: every floor's pictures for the zoom, the middle held so it never leaves the sheet, then
	-- what stands on it at its own size (the pictureless rooms, the marks), the floor shown's before the others'.
	local function Stand()
		local all = pane.all
		local here = all[pane.floor]
		local roomW, roomH = Room()
		local spanW, spanH = Span()
		local fit = math.min(roomW / math.max(spanW, 1), roomH / math.max(spanH, 1), L.most)
		if pane.frame then
			-- Come to another floor: one under the ground that is a small part of the whole (a crypt under a
			-- wide ground) is opened framed, the whole a right click out; back from such a one, the whole again.
			-- (Floors of rooms alone are pieces of one place, and are read in the whole of it.)
			pane.frame = nil
			local own = math.min(roomW / math.max(here.w, 1), roomH / math.max(here.h, 1), L.most)
			if here.under and own / fit >= L.small then
				pane.zoom, pane.framed = math.min(L.deep, own / fit), true
				pane.cx, pane.cy = here.ox + here.w / 2, here.oy + here.h / 2
			elseif pane.framed then
				pane.zoom, pane.cx, pane.cy, pane.framed = 1, nil, nil, nil
			end
		end
		local k = fit * pane.zoom
		local function Hold(c, span, room)
			if span * k <= room then return span / 2 end
			local half = room / 2 / k
			return math.max(half, math.min(span - half, c or span / 2))
		end
		pane.cx, pane.cy = Hold(pane.cx, spanW, roomW), Hold(pane.cy, spanH, roomH)
		local ox, oy = L.pad + roomW / 2 - pane.cx * k, L.pad + roomH / 2 - pane.cy * k
		pane.k, pane.ox, pane.oy = k, ox, oy
		Tiles(all, pane.floor, k)
		local inRoom = pane.room ~= nil and (here.rooms[pane.room] ~= nil or here.parts[pane.room] ~= nil)
		you:SetShown(inRoom)
		if inRoom then
			you:SetText("YOU ARE IN  " .. pane.room:upper())
			UI.Ink(you, Shy.Theme.Accent)
		end
		-- Your group, by room: "Bob, Ann in The Grim Guzzler", the rooms in name order.
		local said = {}
		for room, names in pairs(pane.others or NONE) do
			said[#said + 1] = ("%s in %s"):format(table.concat(names, ", "), room)
		end
		table.sort(said)
		them:SetShown(#said > 0)
		if #said > 0 then
			them:SetText(table.concat(said, "   \194\183   "))
			UI.Ink(them, SILVER)
			them:ClearAllPoints()
			them:SetPoint("TOP", sheet, "TOP", 0, inRoom and -(8 + L.you + 4) or -8)
		end
		land:ClearAllPoints()
		land:SetPoint("TOPLEFT", sheet, "TOPLEFT", ox, -oy)
		-- The rooms without a picture: a plate where each is, saying so where it has the room to.
		local plates = 0
		for index, floor in ipairs(all) do
			for _, room in ipairs(Beside(all, index, pane.floor) and floor.bare or NONE) do
				plates = plates + 1
				local plate = pane.bare[plates]
				if not plate then
					-- (A soft plate, no line round it: ground that is there, and not drawn.)
					plate = CreateFrame("Frame", nil, sheet)
					plate.fill = plate:CreateTexture(nil, "BACKGROUND", nil, 3)
					plate.fill:SetAllPoints()
					UI.Paint(plate.fill, C.row, 0.55)
					plate.text = UI.Text(plate, "Not pictured", 10, false, C.dim)
					plate.text:SetPoint("BOTTOMLEFT", L.bare, L.bare - 1)
					pane.bare[plates] = plate
				end
				local wide, deep = math.max(room[3] * k, 1), math.max(room[4] * k, 1)
				plate:ClearAllPoints()
				plate:SetPoint("TOPLEFT", sheet, "TOPLEFT", ox + (floor.ox + room[1]) * k, -(oy + (floor.oy + room[2]) * k))
				plate:SetSize(wide, deep)
				plate:SetAlpha(index == pane.floor and 1 or L.faint)
				plate.text:SetShown(wide >= plate.text:GetStringWidth() + 2 * L.bare and deep >= 2 * L.mark)
				plate:Show()
			end
		end
		for i = plates + 1, #pane.bare do pane.bare[i]:Hide() end
		local used = 0
		local stood = {}         -- where marks stand so far, in sheet units
		local function Put(x, y)
			used = used + 1
			local mark = Take(used)
			-- Where it stands; moved off any mark it would lie on, a few times round until it has room.
			local px, py = ox + x * k, oy + y * k
			for _ = 1, 6 do
				local moved = false
				for _, other in ipairs(stood) do
					local dx, dy = px - other[1], py - other[2]
					local far = math.sqrt(dx * dx + dy * dy)
					if far < L.apart then
						if far < 0.01 then dx, dy, far = math.cos(used * 2.4), math.sin(used * 2.4), 1 end
						px, py = other[1] + dx / far * L.apart, other[2] + dy / far * L.apart
						moved = true
					end
				end
				if not moved then break end
			end
			stood[#stood + 1] = { px, py }
			mark:ClearAllPoints()
			mark:SetPoint("CENTER", sheet, "TOPLEFT", px, -py)
			return mark
		end
		local book = J.Book(pane.map)
		local cameFloor, cameX, cameY = Floors.Door(pane.map)
		local function Marks(index, floor)
			local wayIn = floor.door or (cameFloor == index and { x = cameX, y = cameY, came = true })
			if wayIn then
				local mark = Put(floor.ox + wayIn.x, floor.oy + wayIn.y)
				mark.index, mark.way, mark.floor, mark.name = nil, nil, index, "The way in"
				mark.under = pane.door and ("From " .. pane.door) or nil
				if wayIn.came then mark.under = (mark.under and (mark.under .. "\n") or "") .. "Where you came in" end
			end
			for _, door in ipairs(floor.doors) do
				local mark = Put(floor.ox + door.x, floor.oy + door.y)
				mark.index, mark.way, mark.floor = nil, nil, index
				mark.name = door.what and ("A way in: the " .. door.what) or "Another way in"
				mark.under = pane.door and ("From " .. pane.door) or nil
			end
			for _, rare in ipairs(index == pane.floor and floor.rares or NONE) do
				local mark = Put(floor.ox + rare.x, floor.oy + rare.y)
				mark.index, mark.way, mark.floor, mark.rare = nil, nil, index, true
				mark.name, mark.under = rare.name, "Rare: not always there"
			end
			for _, spot in ipairs(pane.spots[index]) do
				local mark = Put(floor.ox + spot.x, floor.oy + spot.y)
				local boss = book and book.bosses[spot.index]
				mark.index, mark.way, mark.floor, mark.name = spot.index, nil, index, boss and boss.name or ""
				mark.under = ("Boss %d of %d"):format(J.Step(pane.map, spot.index), book and #book.bosses or spot.index)
				if #all > 1 then
					mark.under = mark.under .. "  \194\183  " .. (Floors.Named(pane.map) and Floors.Label(pane.map, index)
						or ("floor %d"):format(index))
				end
				if pane.done and pane.done[spot.index] then
					mark.under = mark.under .. "\nDown this run"
				elseif pane.next == spot.index then
					mark.under = mark.under .. "\nNext"
				end
				-- (One the data has no place for: where you met it, and how well that is known.)
				if spot.met == "looted" then
					mark.under = mark.under .. "\nWhere you looted it"
				elseif spot.met then
					mark.under = mark.under .. "\nYou met it in " .. spot.met
				end
			end
		end
		-- The way through the floor, where one is known: from the way in boss to boss, as the family draws a
		-- way on a map (a journey's even line in its case, in your color). The ways out to the bosses off it
		-- first, finer and fainter, the way itself over them; a leg to a boss down this run fainter.
		local Maps = Shy.Maps
		local legs = 0
		-- A stretch's color says which step of the run it is. Off a run the way pales as it goes on, your color
		-- to the first boss and nearer steel to the last, so its order reads at a glance. On a run the stretch to
		-- the next boss is the one in your color, and wider; what is behind you is faint, what is ahead steel.
		local order = J.Order(pane.map)
		local accent = { Shy.Theme.Accent() }
		local tones = {}
		local function Tone(to)
			local step = to and J.Step(pane.map, to) or 1
			if pane.next then return to == pane.next and Shy.Theme.Accent or STEEL end
			if not tones[step] then
				local share = L.pale * (step - 1) / math.max(1, #order - 1)
				tones[step] = { accent[1] + (STEEL[1] - accent[1]) * share, accent[2] + (STEEL[2] - accent[2]) * share,
					accent[3] + (STEEL[3] - accent[3]) * share }
			end
			return tones[step]
		end
		Maps.Begin(pen, 1)
		-- (The floors round the one shown first, so its own way lies over theirs.)
		for _, own in ipairs({ false, true }) do
			for _, main in ipairs({ false, true }) do
				for index, floor in ipairs(all) do
					if (index == pane.floor) == own and Beside(all, index, pane.floor) then
						for _, path in ipairs(floor.paths) do
							if path.main == main then
								local points = path.points
								local gone = path.to ~= nil and pane.done ~= nil and pane.done[path.to] == true
								local wide = (main and own) and L.route or L.side
								if own and pane.next ~= nil and path.to == pane.next then wide = wide * L.lead end
								local alpha = (not own and L.far) or (gone and L.gone) or (main and 1 or L.quiet)
								local color = Tone(path.to)
								-- (From point to point, a point too near the last one left out: zoomed out, the
								-- way's points are closer than a piece can be drawn.)
								local ax, ay
								for j = 1, #points - 1, 2 do
									local bx, by = ox + (floor.ox + points[j]) * k, oy + (floor.oy + points[j + 1]) * k
									if not ax then
										ax, ay = bx, by
									elseif j == #points - 1 or (bx - ax) ^ 2 + (by - ay) ^ 2 >= L.piece ^ 2 then
										if own then legs = legs + 1 end
										Maps.Segment(pen, ax, ay, bx, by, wide, alpha, color, nil, Maps.JOURNEY)
										ax, ay = bx, by
									end
								end
							end
						end
					end
				end
			end
		end
		Maps.Finish(pen)
		pane.legs = legs
		-- (The floor shown first: where marks would lie on each other, its own keep their places.)
		Marks(pane.floor, here)
		-- Where it leads onto another floor: a small mark, an arrow on it, up or down.
		for _, way in ipairs(here.ways) do
			local mark = Put(here.ox + way.x, here.oy + way.y)
			mark.index, mark.way, mark.up, mark.floor = nil, way.to, way.up, pane.floor
			mark.name = Floors.Named(pane.map) and ((way.up and "Up to %s" or "Down to %s"):format(Floors.Label(pane.map, way.to)))
				or (way.up and "Up to floor %d" or "Down to floor %d"):format(way.to)
			mark.under = nil
		end
		for index, floor in ipairs(all) do
			if index ~= pane.floor and Beside(all, index, pane.floor) then Marks(index, floor) end
		end
		-- (Nothing says where its bosses stand: they are the strip along its foot, as with no floor.)
		if pane.unplaced then used = pane.Order(used, pane.unplaced) end
		-- The names of the floor's parts, on its ground, once its marks stand.
		local parts = 0
		for _, named in ipairs(here.names) do
			parts = parts + 1
			local text = pane.parts[parts]
			if not text then
				text = written:CreateFontString(nil, "OVERLAY")
				text:SetFontObject(UI.NameFont(L.part))
				text:SetShadowColor(0, 0, 0, 0.9)
				text:SetShadowOffset(1, -1)
				UI.Ink(text, C.text)
				pane.parts[parts] = text
			end
			text:SetText(named.name:upper())
			text:ClearAllPoints()
			-- (Under its place, so a boss met there stands over its name.)
			-- (Clear of a mark that stands on it: under that mark instead.)
			local px, py = ox + (here.ox + named.x) * k, oy + (here.oy + named.y) * k + L.under
			for _, mark in ipairs(stood) do
				if math.abs(px - mark[1]) < L.clear[1] and math.abs(py + L.part / 2 - mark[2]) < L.clear[2] then py = mark[2] + L.under end
			end
			text:SetPoint("TOP", sheet, "TOPLEFT", px, -py)
			text:Show()
		end
		for i = parts + 1, #pane.parts do pane.parts[i]:Hide() end
		for i = used + 1, #pane.marks do pane.marks[i]:Hide() end
		pane.shownMarks = used
		pane:Paint()
	end

	-- With no floor: the picture cut to the sheet's shape (its 2:1 cut cut again, a little above its middle, or
	-- about its middle across), and the bosses in order along its foot, a line of them or as many as they need.
	local function Strip()
		local book = J.Book(pane.map)
		local one = book and book.one
		local rim = Frame()
		local wide, tall = math.max(1, pane.width - 2 * rim), math.max(1, pane.height - 2 * rim)
		if one and one.file > 0 and one.cut then
			local l, t, r, b = one.cut[1], one.cut[2], one.cut[3], one.cut[4]
			local shape = wide / tall
			if shape >= 2 then
				local down = 2 / shape
				local top = t + (b - t) * (1 - down) * 0.4
				t, b = top, top + (b - t) * down
			else
				local across = shape / 2
				local left = l + (r - l) * (1 - across) / 2
				l, r = left, left + (r - l) * across
			end
			art:SetTexture(one.file)
			art:SetTexCoord(l, r, t, b)
			art:SetVertexColor(0.78, 0.78, 0.78, 1)
			art:Show()
		else
			-- (One this build has no picture of: the sheet's own ground, the strip alone on it.)
			art:Hide()
		end
		shade:SetShown(art:IsShown())
		local used = pane.Order(0)
		for i = used + 1, #pane.marks do pane.marks[i]:Hide() end
		pane.shownMarks = used
		pane:Paint()
	end

	-- The bosses in order along the sheet's foot under their caption, a line of them or as many as they need:
	-- with no floor all of them, and at a floor's foot those nothing places on it (`which`: their places in the
	-- order). Its marks are those after the `used` that stand already; how many stand now.
	function pane.Order(used, which)
		local book = J.Book(pane.map)
		local rim = Frame()
		local wide, tall = math.max(1, pane.width - 2 * rim), math.max(1, pane.height - 2 * rim)
		local every = book and #book.bosses or 0
		local count = which and #which or every
		caption:SetText(count == every and "IN THE ORDER YOU MEET THEM" or "NOT ON THE MAP YET")
		local room = wide - 2 * L.pad - L.picked
		local per = math.max(1, math.min(count, math.floor(room / L.least) + 1))
		local lines = math.max(1, math.ceil(count / per))
		per = math.ceil(count / lines)
		local stride = per > 1 and math.min(L.stride, room / (per - 1)) or 0
		local foot = 18 + pane.clear + (lines - 1) * L.line     -- the first line's middle, up from the sheet's foot
		shade:SetHeight(math.min(tall - 2, L.band + pane.clear + (lines - 1) * L.line))
		caption:ClearAllPoints()
		caption:SetPoint("BOTTOM", sheet, "BOTTOM", 0, foot + L.picked / 2 + 10)
		local order = J.Order(pane.map)
		for place = 1, count do
			local index = which and which[place] or order[place]
			used = used + 1
			local mark = Take(used)
			local line = math.floor((place - 1) / per)
			local inLine = math.min(per, count - line * per)
			local at = (place - 1) % per
			mark:ClearAllPoints()
			mark:SetPoint("CENTER", sheet, "BOTTOM", (at - (inLine - 1) / 2) * stride, foot - line * L.line)
			mark.index, mark.way, mark.floor, mark.name = index, nil, pane.floor, book.bosses[index].name
			mark.under = ("Boss %d of %d"):format(J.Step(pane.map, index), every)
			-- The line from the mark before it, on its own line of the strip.
			local link = pane.links[place]
			if not link then
				link = over:CreateTexture(nil, "ARTWORK")
				UI.Paint(link, C.border, 0.9)
				link:SetHeight(1)
				pane.links[place] = link
			end
			link:SetShown(at > 0)
			if at > 0 then
				link:ClearAllPoints()
				link:SetPoint("RIGHT", mark, "CENTER", -L.picked / 2 - 2, 0)
				link:SetWidth(math.max(1, stride - L.picked - 4))
			end
		end
		for i = count + 1, #pane.links do pane.links[i]:Hide() end
		return used
	end

	-- Lays what is shown into the sheet: the floor fitted (or as it was zoomed), or the picture and its strip.
	function pane:Lay(width, height)
		self.width, self.height = width or self.width, height or self.height
		self:SetSize(self.width, self.height)
		Frame()
		if self.shown then
			Stand()
		elseif self.strip then
			Strip()
		end
	end

	-- Closer or further by `factor`, the sheet's point x, y (units from its top left; its middle with none) held.
	function pane:Zoom(factor, x, y)
		if not (self.shown and self.k) then return end
		local zoom = math.max(1, math.min(L.deep, self.zoom * factor))
		if zoom == self.zoom then return end
		local roomW, roomH = Room()
		x, y = x or (L.pad + roomW / 2), y or (L.pad + roomH / 2)
		-- The yard under that point stays under it.
		local yardX, yardY = (x - self.ox) / self.k, (y - self.oy) / self.k
		local k = self.k / self.zoom * zoom
		self.zoom = zoom
		self.cx = yardX - (x - L.pad - roomW / 2) / k
		self.cy = yardY - (y - L.pad - roomH / 2) / k
		Stand()
	end

	function pane:Whole()
		if self.zoom == 1 then return end
		self.zoom, self.cx, self.cy, self.framed = 1, nil, nil, nil
		if self.shown then Stand() end
	end

	-- Zoomed in, a boss comes to the middle (the whole dungeon shows it already).
	function pane:Focus(boss)
		if not self.shown or self.zoom <= 1 then return end
		for index, floor in ipairs(self.all) do
			for _, spot in ipairs(self.spots[index]) do
				if spot.index == boss then
					self.cx, self.cy = floor.ox + spot.x, floor.oy + spot.y
					Stand()
					return
				end
			end
		end
	end

	function pane:Open(map, floor, opts)
		opts = opts or NONE
		local all = Floors.Of(map)
		local was, wasFloor = self.all, self.floor
		self.map, self.count, self.all = map, all and #all or 0, all
		self.floor = all and math.max(1, math.min(floor or 1, #all)) or nil
		self.shown = all and all[self.floor] or nil
		self.strip = self.shown == nil and J.Book(map) ~= nil
		self.picked, self.onBoss, self.onDoor, self.onOut, self.door = opts.picked, opts.onBoss, opts.onDoor, opts.onOut, opts.door
		self.clear = opts.clear or 0
		self.tones, self.onHover, self.hot = opts.tones, opts.onHover, nil
		self.done, self.next, self.room = opts.done, opts.next, opts.room
		-- (Who is where, and a word for it that changes when it does: what is laid is laid again then.)
		self.others = opts.others
		local key = {}
		for room, names in pairs(opts.others or NONE) do key[#key + 1] = room .. "=" .. table.concat(names, ",") end
		table.sort(key)
		self.othersKey = table.concat(key, ";")
		if not self.shown then
			you:Hide()
			them:Hide()
		end
		self.onFloor = opts.onFloor
		-- (Another dungeon is read from the whole of it; another floor of this one, from where it was left.)
		if all ~= was then self.zoom, self.cx, self.cy, self.framed = 1, nil, nil, nil end
		-- (Come to another floor, or another dungeon's: it is framed if it is a small part of the whole.)
		self.frame = self.shown ~= nil and (all ~= was or self.floor ~= wasFloor)
		-- Where its bosses stand, by the data and by what was met; those nothing places are a strip at its foot.
		local placed
		self.spots, placed = Floors.Spots(map)
		self.unplaced = nil
		local book = J.Book(map)
		if self.shown and book then
			local without = {}
			for _, index in ipairs(J.Order(map)) do
				if not placed[index] then without[#without + 1] = index end
			end
			if #without > 0 then self.unplaced = without end
		end
		self:SetShown(self.shown ~= nil or self.strip)
		land:SetShown(self.shown ~= nil)
		art:SetShown(self.strip)
		shade:SetShown(self.strip or self.unplaced ~= nil)
		caption:SetShown(self.strip or self.unplaced ~= nil)
		written:SetShown(self.shown ~= nil)
		sheet:EnableMouseWheel(self.shown ~= nil)
		if not self.shown then
			for _, plate in ipairs(self.bare) do plate:Hide() end
		end
		if not (self.strip or self.unplaced) then
			for _, link in ipairs(self.links) do link:Hide() end
		end
		if self.shown or self.strip then self:Lay() end
	end

	-- The mouse, in the sheet's units from its top left.
	local function Cursor()
		local x, y = GetCursorPosition()
		local s = sheet:GetEffectiveScale()
		return x / s - (sheet:GetLeft() or 0), (sheet:GetTop() or 0) - y / s
	end

	-- The floor laid round the one shown that is painted under a place of the sheet, where the one shown is
	-- not: its place among the floors, or nil.
	function pane.Under(x, y)
		local all = pane.all
		if not (pane.shown and pane.k and all) then return nil end
		local lx, ly = (x - pane.ox) / pane.k, (y - pane.oy) / pane.k
		local here = all[pane.floor]
		if Floors.Painted(here, lx - here.ox, ly - here.oy) then return nil end
		for index, floor in ipairs(all) do
			if index ~= pane.floor and Beside(all, index, pane.floor) and Floors.Painted(floor, lx - floor.ox, ly - floor.oy) then
				return index
			end
		end
		return nil
	end

	-- The mouse over a place of the sheet: the floor under it comes up, and says what a click does.
	function pane:Point(x, y)
		local over = x and pane.Under(x, y) or nil
		if over == self.over then return end
		self.over = over
		if self.shown then Stand() end
		if over then
			UI.Tip(sheet, Floors.Label(self.map, over), nil, { side = "TOP", hints = { { "left", "Show this floor" } } })
		else
			UI.TipHide(sheet)
		end
	end

	-- A click on a place of the sheet: the floor under it is turned to.
	function pane:Pick(x, y)
		local over = pane.Under(x, y)
		if not (over and self.onFloor) then return false end
		self:Point(nil)
		self.onFloor(over)
		return true
	end

	local drag
	local function Dragged()
		if not drag then
			-- (Not held: the mouse looks for a floor under it.)
			pane:Point(Cursor())
			return
		end
		local x, y = Cursor()
		local dx, dy = x - drag.x, y - drag.y
		if not drag.moved and dx * dx + dy * dy < L.click then return end
		drag.moved = true
		pane.cx, pane.cy = drag.cx - dx / pane.k, drag.cy - dy / pane.k
		Stand()
	end
	local function Let()
		drag = nil
		sheet:SetScript("OnUpdate", sheet:IsMouseOver() and Dragged or nil)
	end
	sheet:SetScript("OnEnter", function() sheet:SetScript("OnUpdate", Dragged) end)
	sheet:SetScript("OnLeave", function()
		if not drag then
			sheet:SetScript("OnUpdate", nil)
			pane:Point(nil)
		end
	end)
	sheet:SetScript("OnMouseWheel", function(_, delta)
		local x, y = Cursor()
		pane:Zoom(L.wheel ^ delta, x, y)
	end)
	sheet:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" or not (pane.shown and pane.k) then return end
		local x, y = Cursor()
		drag = { x = x, y = y, cx = pane.cx, cy = pane.cy, moved = false }
		sheet:SetScript("OnUpdate", Dragged)
	end)
	sheet:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			-- (A press that didn't move is a click: on a floor laid round the one shown, it turns to it.)
			local clicked = drag ~= nil and not drag.moved
			Let()
			if clicked then pane:Pick(Cursor()) end
		elseif button == "RightButton" then
			-- Out a step: zoomed in, to the whole floor; from the whole of it, to what its owner says is out.
			if pane.shown and pane.zoom > 1 then
				pane:Whole()
			elseif pane.onOut then
				pane.onOut()
			end
		end
	end)
	sheet:SetScript("OnHide", function()
		drag = nil
		sheet:SetScript("OnUpdate", nil)
		pane.over = nil
	end)

	Shy:On("SHY_THEME", function()
		pane.rim = nil
		if pane:IsShown() then pane:Lay() end
	end)
	return pane
end
