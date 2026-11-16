-- Console geometry, pure: no frames touched. Housing.lua uses Wrap, Layout.lua uses Build.
-- UI units; x from the screen's middle, y up from its bottom edge.
--
-- Eight layouts: four classic (the bars on the floor), four by role (the bars and your frames round your
-- character). The console: chat, bars and meter joined along the bottom, the
-- side bars upright in racks at the wings' outer ends.
--
--   roof   ______ ___________ ____plate____|____plate____ ___________ ______
--         | rack |  chat     |  [][][][][][][][][][][]   |  meter    | rack |
--         |______|___________|__[][][][][][][][][][][]___|___________|______|  <- floor
--          ====================== experience bar ======================
--
-- The other three give the middle to the world: the bars stand alone, chat in
-- the bottom left corner and the meter in the bottom right, mirrors of each
-- other: the same width, both feet on the corner's inset, both tops on the
-- roof. They differ in where the side bars go:
--   flanks   upright racks a seam off the housing's sides, no taller than the bars and plates
--   open     a shelf of six at either end of the bars, at the bars' own size
--   stack    rows in the one housing, under the bottom bars
--
-- The four by role (C.ROLES; one table each in C.ROLE, from the design board "WoW UI Layouts") lift the
-- bars off the floor to just under your character's feet, with the side bars as racks beside them, the
-- pet bar and the experience bar under them, a slim cooldown manager over them (no health and power block:
-- your frame has them), your frame and your target's either side of your character, and chat and the meter
-- in the bottom corners at a fixed height:
--   center    DPS and levelling: your frame and your target's at about 290 either side, three bars
--   healer    the party or raid in the middle under your character, your frames out to the sides
--   tank      the threat meter a tall panel beside your target, your target's target over it
--   minimal   everything pulled in round your character and smaller; the main bar alone on the floor, bars 2 and 3
--             over it and the side bars beside them showing while you point there (Drawers.lua), the meter in a fight
-- Where each of their pieces stands is Parts.lua's (P.Role): one plan the game's layout, the live homes
-- (Arrange.lua, ShyFrames through Dock:UnitHomes) and every drawing read.
--
--    ________                ____plate____|____plate____               ________
--   |  chat  |       ______ |  [][][][][][][][][][][]   | ______       |  meter |
--   |        |      |[][][]||  [][][][][][][][][][][]   ||[][][]|      |        |
--   |________|      |______||__[][][][][][][][][][][]___||______|      |________|
--                    ========== experience bar ==========
--
-- The bottom corners hold nothing else. The bag bar and the micro menu are two
-- short rows under the minimap, with the objectives under them: the system
-- column at the screen's top right (Column). The raid frames hang from the top
-- left corner with the deck (the guide, the group status) under them, or from
-- the corner itself out of a raid: the group column (Raid, Arrange.lua); in the
-- layouts by role the group stands where its role wants it. Neither column is
-- part of the bottom band Build lays out.
--
-- With ShyFrames' plates on the housing, their top edge is the wings' roof (a
-- size's rise over it); without, the wings end STEP under the housing's top.
-- In the console the wings then come down to the racks' buttons and a lip over
-- and under them (the buttons' size moves in steps), so a rack's rim is the bars'.
-- A wing can't be lower than its window's smallest height and art: a console
-- of one or two rows then has open world over its plates up to the roof.
-- The XP bar goes under the floor: this client won't make it narrower than 596.
-- Wings respect the game's minimum chat and meter sizes. The meter's height only
-- moves in slider steps, so the roof is set from the meter and chat matches it.
-- On a narrow screen the wings shrink first, never the bars; a rack with no
-- room beside a minimum-width wing (a flank or shelf with none between the
-- bars and a corner piece) is left out. In the corner layouts the wings also
-- keep clear of ShyFrames' small frames beside the plates, which go up on the
-- wings' roofs (g.roofed) where even the least wing wouldn't fit beside them.

local ADDON, ns = ...
local UI = Shy.UI
local floor, max, min = math.floor, math.max, math.min

local C = {}
ns.Console = C

-- Housing reach past the bars at each side, and above the top row / below the bottom one: room for a row of
-- rivets clear of the buttons (UI.LookArt.RIVETED's sew), the same in every look.
C.PAD = 8
C.LIP = 8
C.RIM = C.LIP
C.STEP = 16                  -- wing top below the housing top when no plates stand on it
-- The one gap between any two pieces, the same in every look (a look never moves a thing).
C.SEAM = 4
C.CORNER = C.SEAM            -- inset of a corner piece from the screen's edges
-- Sizes: wing width (art included) and how far the roof rises over the plates' top edge.
C.SIZES = {
	compact = { wing = 290, rise = 0 },
	roomy = { wing = 380, rise = 40 },
	grand = { wing = 470, rise = 80 },
}
C.SIZE_ORDER = { "compact", "roomy", "grand" }
C.DEFAULT = "roomy"
-- Layouts (see the header). CORNERS: the ones with chat and the meter in the corners; RACKED: the ones with
-- upright racks a seam off the housing's sides; ROLES: the four by role. CLASSIC_ORDER and ROLE_ORDER are the
-- two rows they are offered in.
C.STYLES = { console = true, flanks = true, open = true, stack = true, center = true, healer = true, tank = true, minimal = true }
C.CLASSIC_ORDER = { "console", "flanks", "open", "stack" }
C.ROLE_ORDER = { "center", "healer", "tank", "minimal" }
C.STYLE_ORDER = { "console", "flanks", "open", "stack", "center", "healer", "tank", "minimal" }
C.CORNERS = { flanks = true, open = true, stack = true, center = true, healer = true, tank = true, minimal = true }
C.RACKED = { flanks = true, center = true, healer = true, tank = true, minimal = true }
C.ROLES = { center = true, healer = true, tank = true, minimal = true }
C.STYLE = "console"
-- The layouts by role, as the design board has them on a screen 1080 tall (offsets from the screen's middle, y up;
-- the board's offsets anchored to the middle grow with the screen, by its height over 1080, never under ROLE_LEAST):
--   bars      the housing's top edge (the bars hang under it, the pet bar and the experience bar under them)
--   unitX, unitY   your frame's and your target's centres (mirrors)
--   small     where your target's target and your focus stand: "beside" (outside them, level with them) or
--             "over" (over them, centred)
--   threat    the threat meter: under = the frame it hangs under ("targettarget" or "target"), its left edge on that
--             frame's; or beside = "target" (a seam outside it, its top on the target's target's); w its width;
--             rows the most it shows
--   group     the party and raid: { x, y, w, h } its centre and size, or { left = true, y, w, h } on the group
--             column's left edge (the screen's left, past the raid manager's tab), or { under = true, w, h } right
--             under your character, over the cooldown manager; party: "row" (four across) or "column" (stacked);
--             raid: the raid frames' grouping (Enum.RaidGroupDisplayType key); near: ShyFrames' party is a
--             column this wide beside your frames, whatever the group's place and width, which are the raid's
--             then (Parts.lua, out.partyAt). Every role with a column has it: one rule, one width.
--   chat      the corners' height (chat and the meter alike: mirrors)
--   combat    the meter shows only in a fight (the minimal layout)
--   order     the bars from the floor up, when it is to be another than C.ORDER
--   reveal    every bar but the main one shows only while you point at the bars (Drawers.lua): faded, never
--             hidden, so their keys work all the while
C.ROLE = {
	center = { bars = -249, unitX = 290, unitY = -150, small = "beside", chat = 190,
		threat = { under = "targettarget", w = 200, rows = 4 },
		group = { left = true, y = -40, w = 300, h = 280, near = 165, party = "column", raid = "SeparateGroupsHorizontal" } },
	healer = { bars = -345, unitX = 460, unitY = -150, small = "over", chat = 190,
		threat = { under = "target", w = 220, rows = 3 },
		group = { under = true, w = 640, h = 190, party = "row", raid = "SeparateGroupsVertical" } },
	tank = { bars = -264, unitX = 280, unitY = -140, small = "over", chat = 190,
		threat = { beside = "target", w = 220, rows = 8 },
		group = { left = true, y = -60, w = 300, h = 280, near = 165, party = "column", raid = "SeparateGroupsHorizontal" } },
	minimal = { bars = -244, unitX = 230, unitY = -170, small = "over", chat = 150,
		threat = { under = "target", w = 190, rows = 2 },
		group = { x = -470, y = -90, w = 200, h = 260, near = 165, party = "column", raid = "SeparateGroupsHorizontal" },
		combat = true, order = { "main", "bar2", "bar3" }, reveal = true },
}
C.ROLE_BASE, C.ROLE_LEAST = 1080, 0.85   -- the board's screen height; the least its middle offsets shrink to
-- How much the board's offsets anchored to the middle grow on a screen `height` tall.
function C.RoleScale(height)
	return max(C.ROLE_LEAST, (height or C.ROLE_BASE) / C.ROLE_BASE)
end
C.PET_BAR = 22.5               -- the pet bar's height (ten buttons at half size: Parts.lua draws it so)
C.SHELF = C.SEAM             -- between the floor and what lies under it
C.DECK = 270                 -- deck width
C.RACK_COLUMNS, C.RACK_ROWS = 2, 6
-- A rack's shapes (columns, rows), tried in this order: the one filling its room best wins (Shape).
C.RACK_SHAPES = { { 2, 6 }, { 3, 4 }, { 4, 3 }, { 6, 2 } }
C.SHELF_COLUMNS = 6          -- buttons across a shelf (the open layout's side bars)
C.BUTTONS = 12               -- across a bar
-- Bottom bars from the floor up: the main bar is the top row (the reverse of Blizzard's default stack).
C.ORDER = { "bar3", "bar2", "main" }
-- The stack: the side bars are rows too, under the bottom bars (the first side bar, for food and potions, lowest).
C.STACK_ORDER = { "right", "left", "bar3", "bar2", "main" }
-- Unscaled action button slot (ActionBarButtonContainerTemplate, Blizzard_ActionBar/Shared/ActionBarTemplate.xml).
C.BUTTON = 45
-- Bar settings used: 80% of 45 = 36; padding scales with the button, so 3 gives 2.4. Twelve across = 458.
C.ICON = 80
C.SPACING = 3
-- The group column: the raid frames five to a row from the top left corner, past the tab the raid
-- manager leaves at the screen's edge when it is folded away (222 wide, folded to 22 showing).
C.RAID_TAB = 22
C.RAID_CELLS = 5
C.RAID_H = { compact = 40, roomy = 44, grand = 48 }   -- a raid frame's height by size

local function Round(v) return floor(v + 0.5) end

-- A row under the minimap (the micro menu, the bag bar) at the largest size its slider has that fits
-- `room` across, never smaller than the slider's least: `natural` is the row at 100% ({ w, h }),
-- `limits` { min, max, step } in percent. Returns { w, h, percent }.
function C.RowFit(natural, room, limits)
	local step = limits[3] or 1
	local percent = floor(room / natural.w * 100 / step) * step
	percent = max(limits[1], min(limits[2], percent))
	return { w = natural.w * percent / 100, h = natural.h * percent / 100, percent = percent }
end

-- A drawer's pull (Shy.Drawer's): the menu's is the header of its tray, a console piece's (C.HEAD, top
-- edge to the line's foot), and tucked it is a piece folded away, the header alone (C.PULL: UI.FOLDED, as the
-- deck's quests folded); a rack's is a grip C.GRIP wide astride the seam beside it, which is exactly the gap
-- between the dock's buttons and the rack's (a pad, the seam, a pad).
C.HEAD = Shy.UI.HEAD_STRIP + Shy.UI.LINE
C.PULL = Shy.UI.FOLDED
C.GRIP = 2 * C.PAD + C.SEAM

-- The system column's rows, from `now`: the screen (screen, height), the minimap (map.width, map.height,
-- a seam in from the top right corner) and the rows (column.menu, column.bags: RowFit's, or nil for none).
-- The rows stand in a tray of the console's make as wide as the column, its right edge on the map's, each
-- row in its middle, a seam apart and a pad over its foot. `under`: what the tray hangs a seam under: the
-- map's foot (nil), or the guide's while the deck stands in the column (Arrange.lua, Parts.lua). Edit
-- Mode's sliders stop at 70 and 75%, so as the layout has them a row can be wider than the map, and the
-- tray with it; `fit`: Shy.HUD homes the game's frames (Arrange.lua) and can size them, so a row wider
-- than the map's room is made to fit it (`scale`, by row) and the tray is never wider than the column.
-- With the menu in a drawer (now.drawer) its `pull` is the tray's header (C.PULL), the rows a seam under
-- its line; and while the drawer is tucked (now.tucked) the column keeps only the pull's room: the tray
-- slides down out of it over what hangs below. Without one the rows stand a pad under the tray's top.
-- Returns rects as { left, bottom, right, top } (x from the screen's middle, y from its foot): `menu`,
-- `bags`, `tray` (under the pull), `pull`; `rows` (the room kept under `top`; 0 with nothing) and `foot`
-- (the bottom of that room, or `under`).
function C.Column(now, under, fit)
	local half, H = now.screen / 2, now.height
	local right, y = half - C.CORNER, under or (H - C.CORNER - now.map.height)
	local out = { right = right, top = y - C.SEAM, rows = 0, foot = y, scale = {} }
	local room = now.map.width - 2 * C.PAD
	local rows, wide = {}, 0
	for _, key in ipairs({ "menu", "bags" }) do
		local row = now.column and now.column[key]
		if row then
			local k = (fit and row.w > room) and room / row.w or 1
			rows[key] = { w = row.w * k, h = row.h * k }
			out.scale[key] = k
			wide = max(wide, row.w * k)
		end
	end
	if wide <= 0 then return out end
	local left = right - max(now.map.width, wide + 2 * C.PAD)
	y = out.top
	local top = y
	if now.drawer then
		out.pull = { left, y - C.PULL, right, y }
		top = y - C.PULL
		y = y - C.HEAD - C.SEAM
	else
		y = y - C.PAD
	end
	for _, key in ipairs({ "menu", "bags" }) do
		local row = rows[key]
		if row then
			local r = right - C.PAD - floor((right - left - 2 * C.PAD - row.w) / 2 + 0.5)
			out[key] = { r - row.w, y - row.h, r, y }
			y = y - row.h - C.SEAM
		end
	end
	out.tray = { left, y + C.SEAM - C.PAD, right, top }
	out.foot = (now.tucked and out.pull) and out.pull[2] or out.tray[2]
	out.rows = out.top - out.foot
	return out
end

-- What a rack stands beside, its host: the outermost piece of the console on that side. In the console
-- that is the wing (the meter at the right, chat at the left; the housing where a wing is missing); in
-- the corner layouts the racks stand at the housing's sides, so the housing (the dock). side 1 right,
-- -1 left. Returns { left, bottom, right, top }.
function C.Host(g, side)
	if not C.CORNERS[g.style] then
		if side > 0 and g.meter then return g.meter.art end
		if side < 0 and g.chat then return g.chat.art end
	end
	local h = g.housing
	return { h.left, h.bottom, h.right, h.top }
end

-- A rack's grip: the pull of its drawer, C.GRIP wide astride the seam between the rack and its host
-- (C.Host), as tall as the host. It belongs to the host: it shows while the mouse is on that piece
-- (Drawers.lua). nil with no rack there.
function C.Grip(g, side)
	local r = g.rack and g.rack.rects and g.rack.rects[side]
	if not r then return nil end
	local centre = (side > 0 and r[1] or r[3]) - side * C.SEAM / 2
	local host = C.Host(g, side)
	return { centre - C.GRIP / 2, host[2], centre + C.GRIP / 2, host[4] }
end

-- A raid frame's size for a console size: as wide as a fifth of the wing allows, in the slider's steps
-- of 2 from 72 to 144 (compact 72, roomy 76, grand 94), and the size's height.
function C.Raid(size)
	local def = C.SIZES[size] or C.SIZES[C.DEFAULT]
	local w = floor(def.wing / C.RAID_CELLS / 2) * 2
	return { w = max(72, min(144, w)), h = C.RAID_H[size] or C.RAID_H[C.DEFAULT] }
end

-- Frame rectangle in UIParent units as left, bottom, right, top. nil when off
-- screen, false when the rect is secret (it can be, when the anchoring is).
function C.Rect(frame)
	local visible = frame:IsVisible()
	if issecretvalue(visible) then return false end
	if not visible then return nil end
	local left, bottom, width, height = frame:GetScaledRect()
	if left == nil then return nil end
	if issecretvalue(left) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height) then return false end
	local originX, originY = UIParent:GetScaledRect()
	local scale = UIParent:GetEffectiveScale()
	left, bottom = (left - originX) / scale, (bottom - originY) / scale
	return left, bottom, left + width / scale, bottom + height / scale
end

-- Housing rect around a block of bars. `head` overrides the top lip (see Build).
function C.Wrap(left, bottom, right, top, head)
	return left - C.PAD, bottom - C.RIM, right + C.PAD, top + (head or C.LIP)
end

local function Reach(wing)
	if not wing then return 0, 0, 0, 0 end
	return wing[1] or 0, wing[2] or 0, wing[3] or 0, wing[4] or 0
end

local function Clamp(v, range) return max(range[1], min(range[2], Round(v))) end

-- A window's art rect from its own rect and its art's reach.
local function Art(left, bottom, width, height, reach)
	local l, t, r, b = Reach(reach)
	return { left - l, bottom - b, left + width + r, bottom + height + t }
end

-- An upright block of side-bar buttons in a housing: `columns` x `rows` at `percent`.
local function Upright(percent, columns, rows)
	local k = percent / 100
	local block = (rows * C.BUTTON + (rows - 1) * C.SPACING) * k
	local width = (columns * C.BUTTON + (columns - 1) * C.SPACING) * k + 2 * C.PAD
	return block, width
end

-- The largest slider step of button size whose `rows` fit `room`, at most `cap`.
local function Fit(room, rows, limits, cap)
	local step = limits.iconSize[3] or 1
	local percent = room / (rows * C.BUTTON + (rows - 1) * C.SPACING) * 100
	percent = floor(percent / step) * step
	return max(limits.iconSize[1], min(limits.iconSize[2], cap or limits.iconSize[2], percent))
end

-- The shape of a rack for `room` of height: of C.RACK_SHAPES, one that fits
-- before any that overflows; of those, the one whose rows fill the most of it
-- (a wing's worth of tiny buttons with bands of housing above and below is no
-- rack), fills within a twentieth counting as equal; then the bigger buttons,
-- then the earlier shape. Returns percent, columns, rows, block height, housing width.
local NEAR = 0.05
local function Shape(room, limits, cap)
	local best
	for _, shape in ipairs(C.RACK_SHAPES) do
		local percent = Fit(room, shape[2], limits, cap)
		local block, width = Upright(percent, shape[1], shape[2])
		local fits = block <= room + 0.001
		local fill = fits and block / max(room, 1) or room / block
		local better = not best
			or (fits and not best.fits)
			or (fits == best.fits and (fill > best.fill + NEAR or (fill > best.fill - NEAR and percent > best.percent)))
		if better then
			best = { fits = fits, fill = fill, percent = percent, columns = shape[1], rows = shape[2], block = block, width = width }
		end
	end
	return best.percent, best.columns, best.rows, best.block, best.width
end

-- How wide the side bars beside the housing are in a corner layout (a flank's or a shelf's housing, without
-- the seam to it); 0 where the layout has none beside it (the stack) or none is on.
local function Beside(want, g, style)
	if not (want.rackLeft or want.rackRight) then return 0 end
	if C.RACKED[style] then
		local _, _, _, _, width = Shape(g.housing.top + g.plates - g.floor - 2 * C.RIM, want.limits, C.ICON)
		return width
	end
	if style == "open" then return C.SHELF_COLUMNS * g.button + (C.SHELF_COLUMNS - 1) * g.gap + 2 * C.PAD end
	return 0
end

-- The corner layouts' chat and meter: mirrors of each other in the screen's bottom corners, each a seam
-- in from the edges, as wide as the size's wing, up to the roof (the meter's height in its slider's
-- steps, rounded up as Build rounds the roof, so both tops are on one line).
-- On a screen too narrow for that the wings give way, both alike, so each stays a seam clear of what stands
-- at the middle's side: the housing, its side bars and ShyFrames' small frames beside the plates (want.beside,
-- the wider side's). Never under the windows' least: when that doesn't fit beside the small frames they go
-- up on the wings' roofs, flush with their inner ends, as in the console (g.roofed), and the side bars stay
-- while a least wing fits beside them (as in the console: the wings shrink first, a side bar goes last).
local function Corners(want, g, size)
	local limits = want.limits
	local half = want.screen / 2
	local cl, ct, cr, cb = Reach(want.chat)
	local ml, mt, mr, mb = Reach(want.meter)
	local line = g.wingTop
	g.line = line
	local least = max(limits.chatWidth[1] + cl + cr, want.meter and limits.meterWidth[1] + ml + mr or 0)
	local core = g.housing.right
	local bars = Beside(want, g, g.style)
	local racks = bars > 0 and core + C.SEAM + bars or core
	local small = g.plates > 0 and want.beside and max(want.beside.left or 0, want.beside.right or 0) or 0
	local function Room(inner) return floor(half - C.CORNER - inner - C.SEAM) end
	local room = Room(max(racks, small > 0 and core + C.SEAM + small or core))
	if small > 0 and room < least then
		g.roofed = true
		room = Room(racks)
	end
	if room < least then room = Room(core) end
	local wing = min(size.wing, room)
	if want.meter then
		local step = limits.meterHeight[3] or 1
		local height = math.ceil((line - C.CORNER - mt - mb) / step - 0.001) * step
		local meterWidth = Clamp(wing - ml - mr, limits.meterWidth)
		g.meter = {
			width = meterWidth,
			height = min(max(height, limits.meterHeight[1]), limits.meterHeight[2]),
			left = half - C.CORNER - mr - meterWidth,
			bottom = C.CORNER + mb,
		}
		g.meter.art = Art(g.meter.left, g.meter.bottom, g.meter.width, g.meter.height, want.meter)
	end
	local width = Clamp(wing - cl - cr, limits.chatWidth)
	g.chat = {
		width = width,
		height = Clamp(line - C.CORNER - ct - cb, limits.chatHeight),
		right = -half + C.CORNER + cl + width,
		bottom = C.CORNER + cb,
	}
	g.chat.art = Art(g.chat.right - width, g.chat.bottom, width, g.chat.height, want.chat)
	g.wings = { left = g.chat.art[1], right = g.meter and g.meter.art[3] or g.housing.right }
end

-- Open: a shelf of six at either end of the housing, one row beside a single bar, two beside more.
local function Shelves(want, g)
	local half = want.screen / 2
	local h = g.housing
	local lines = g.shown > 1 and 2 or 1
	local shelf = C.SHELF_COLUMNS * g.button + (C.SHELF_COLUMNS - 1) * g.gap
	local rackWidth = shelf + 2 * C.PAD
	local bottom = g.floor + C.RIM + g.under
	local top = bottom + lines * g.button + (lines - 1) * g.gap + C.LIP
	-- A shelf needs room between the housing and what stands in the corner on its side.
	local leftOuter = h.left - C.SEAM - rackWidth
	local rightOuter = h.right + C.SEAM + rackWidth
	local rightLimit = g.meter and g.meter.art[1] or half - C.CORNER
	local left = want.rackLeft and leftOuter - C.SEAM >= g.chat.art[3] - 0.001 or false
	local right = want.rackRight and rightOuter + C.SEAM <= rightLimit + 0.001 or false
	g.rack = {
		kind = "shelf", flat = true, columns = C.SHELF_COLUMNS, rows = lines,
		percent = C.ICON, width = rackWidth, bottom = bottom,
		lines = lines, icons = C.SHELF_COLUMNS * lines,
		foot = h.bottom, top = top,
		left = left and true or false, right = right and true or false,
		-- Where each shelf's bar stands: its inner edge and its bottom.
		slots = { [1] = { h.right + C.SEAM + C.PAD, bottom }, [-1] = { h.left - C.SEAM - C.PAD, bottom } },
	}
	g.rack.rects = {
		[1] = right and { h.right + C.SEAM, h.bottom, rightOuter, top } or nil,
		[-1] = left and { leftOuter, h.bottom, h.left - C.SEAM, top } or nil,
	}
	g.left = left and leftOuter or h.left
	g.right = right and rightOuter or h.right
	g.deck = { left = g.chat.art[1], beside = false }
end

-- Stack: the side bars are rows of the housing (Build gave them rows), with no housing of their own.
local function Stacked(want, g)
	local h = g.housing
	g.rack = {
		kind = "row", flat = true, columns = C.BUTTONS, rows = 1,
		percent = C.ICON, width = h.right - h.left, bottom = g.floor + C.RIM,
		lines = 1, icons = C.BUTTONS,
		foot = h.bottom, top = h.top,
		left = want.rackLeft and true or false, right = want.rackRight and true or false,
		slots = { [1] = { -g.width / 2, g.rows.right }, [-1] = { g.width / 2, g.rows.left } },
		rects = {},
	}
	g.left, g.right = h.left, h.right
	g.deck = { left = g.chat.art[1], beside = false }
end

-- Flanks (and the racks of the layouts by role): upright racks a seam off the housing's sides, standing on the
-- floor like it (by role, the bars' raised floor), no taller than the bars and the plates on them, at most the
-- bars' size. A flank needs room between the housing and what stands in the corner on its side.
local function Flanks(want, g)
	local half = want.screen / 2
	local h = g.housing
	local plates = g.plates
	local room = h.top + plates - g.floor - 2 * C.RIM
	local percent, columns, rows, block, width = Shape(room, want.limits, C.ICON)
	local top = g.floor + block + 2 * C.RIM
	local leftOuter = h.left - C.SEAM - width
	local rightOuter = h.right + C.SEAM + width
	local rightLimit = g.meter and g.meter.art[1] or half - C.CORNER
	local left = want.rackLeft and leftOuter - C.SEAM >= g.chat.art[3] - 0.001 or false
	local right = want.rackRight and rightOuter + C.SEAM <= rightLimit + 0.001 or false
	g.rack = {
		kind = "flank", flat = rows < columns, columns = columns, rows = rows,
		percent = percent, width = width, bottom = g.floor + C.RIM,
		lines = rows < columns and rows or columns, icons = columns * rows,
		foot = g.floor, top = top,
		left = left and true or false, right = right and true or false,
		slots = { [1] = { h.right + C.SEAM + C.PAD, g.floor + C.RIM }, [-1] = { h.left - C.SEAM - C.PAD, g.floor + C.RIM } },
	}
	g.rack.rects = {
		[1] = right and { h.right + C.SEAM, g.floor, rightOuter, top } or nil,
		[-1] = left and { leftOuter, g.floor, h.left - C.SEAM, top } or nil,
	}
	g.left = left and leftOuter or h.left
	g.right = right and rightOuter or h.right
	g.deck = { left = g.chat.art[1], beside = false }
end

-- The whole console from `want`:
--   bar2, bar3        whether those bars are on
--   rackLeft/Right    whether the side bars are on
--   order             bars from the floor up, when it is to be another than the layout's
--   under             height of what lies under the floor (XP bar)
--   plates            ShyFrames plate height on the housing; 0 for none
--   chat, meter       wing art reach { left, top, right, bottom }; meter = false for none
--   beside            ShyFrames' small frames beside the plates: { left, right } widths (0 or nil: none)
--   screen            the screen's width
--   size              key of C.SIZES (C.DEFAULT when nil)
--   style             key of C.STYLES (C.STYLE when nil)
--   limits            chatWidth, chatHeight, meterWidth, meterHeight, iconSize = { min, max, step }
function C.Build(want)
	local limits = want.limits
	local size = C.SIZES[want.size] or C.SIZES[C.DEFAULT]
	local style = C.STYLES[want.style] and want.style or C.STYLE
	local role = C.ROLE[style]
	-- ShyFrames' plates stand on the housing in the classic layouts; by role they stand round your character.
	local plates = role and 0 or (want.plates or 0)
	local g = { style = style, plates = plates, role = role }
	g.scale = C.ICON / 100
	g.button = C.BUTTON * g.scale
	g.gap = C.SPACING * g.scale
	g.width = (C.BUTTONS * C.BUTTON + (C.BUTTONS - 1) * C.SPACING) * g.scale
	g.pitch = g.button + g.gap

	-- Bars that are on fill rows from the floor up; off bars get the rows above, where they land if turned on later.
	g.floor = (want.under or 0) + C.SHELF
	g.under = 0
	local on = { main = true, bar2 = want.bar2, bar3 = want.bar3 }
	local sequence = want.order or (role and role.order) or C.ORDER
	if style == "stack" then
		on.right, on.left = want.rackRight, want.rackLeft
		sequence = want.order or C.STACK_ORDER
	end
	local order = {}
	for _, bar in ipairs(sequence) do
		if on[bar] then order[#order + 1] = bar end
	end
	g.shown = #order
	g.stacked = {}   -- the rows in the housing, floor up
	for i, bar in ipairs(order) do g.stacked[i] = bar end
	for _, bar in ipairs(sequence) do
		if not on[bar] then order[#order + 1] = bar end
	end
	-- By role the bars hang from their top edge just under your character's feet (role.bars, from the screen's
	-- middle), the pet and stance row a seam under them (kept whether a pet is out or not, so nothing moves when
	-- one is) and the experience bar a seam under that; the floor is where that leaves the bottom row. Never so
	-- low the experience bar leaves the screen.
	if role then
		local height = want.height or C.ROLE_BASE
		g.k = C.RoleScale(height)
		local blockTall = g.shown * g.button + max(0, g.shown - 1) * g.gap
		g.floor = height / 2 + role.bars * g.k - C.LIP - blockTall - C.RIM
		local function Under() return g.floor - 2 * C.SEAM - C.PET_BAR - (want.under or 0) end
		if Under() < C.SHELF then g.floor = g.floor + C.SHELF - Under() end
		g.petBar = g.floor - C.SEAM - C.PET_BAR   -- the pet bar's foot
		g.xp = Under()                             -- the experience bar's foot (the second status bar stands on it)
	end
	g.rows = {}
	for i, bar in ipairs(order) do g.rows[bar] = g.floor + C.RIM + g.under + (i - 1) * g.pitch end

	local blockTop = g.floor + C.RIM + g.under + g.shown * g.button + (g.shown - 1) * g.gap
	local left, bottom, right, top = C.Wrap(-g.width / 2, g.floor + C.RIM, g.width / 2, blockTop)

	local cl, ct, cr, cb = Reach(want.chat)
	local ml, mt, mr, mb = Reach(want.meter)
	-- Roof: level with the plates' top edge, or a step under the housing's top.
	-- A wing `tall` high as the windows can stand: never under their smallest; a whole number, rounded up so the
	-- housing never drops onto its top row; the meter's a slider step, rounded up to one so both wings share the roof.
	local function Stand(tall)
		tall = max(tall, limits.chatHeight[1] + ct + cb)
		if want.meter then tall = max(tall, limits.meterHeight[1] + mt + mb) end
		tall = math.ceil(tall - 0.001)
		if want.meter then
			local step = limits.meterHeight[3] or 1
			local height = math.ceil((tall - mt - mb) / step - 0.001) * step
			tall = min(height, limits.meterHeight[2]) + mt + mb
		end
		return tall
	end
	local tall = Stand((plates > 0 and top + plates or top - C.STEP) + size.rise - g.floor)
	g.wingTop = g.floor + tall
	-- By role the bars stand off the floor: chat and the meter keep the corners at the role's height.
	if role then g.wingTop = C.CORNER + Stand(Round(role.chat * g.k)) end
	-- The housing is always snug: wings that must stand taller than the bars and plates (the windows'
	-- smallest heights, with their art) leave open world over the plates, never a blank housing under them.
	g.housing = { left = left, bottom = bottom, right = right, top = top }
	g.head = top - blockTop   -- housing reach over its top row
	if C.CORNERS[style] then
		Corners(want, g, size)
		if C.RACKED[style] then Flanks(want, g) elseif style == "open" then Shelves(want, g) else Stacked(want, g) end
		-- What lies under the floor spans what always stands across it: in a layout that reveals its side bars
		-- only while you point at them (the minimal one), the main bar's housing alone.
		if role and role.reveal then
			g.span = { left = g.housing.left, right = g.housing.right }
		else
			g.span = { left = g.left, right = g.right }
		end
		return g
	end

	-- Racks: the shape and button size that best fill the wing's height less two lips (Shape), at most the bars' size.
	local percent, columns, rows, block, rackWidth = Shape(tall - 2 * C.RIM, limits, C.ICON)
	-- The wings come down to the racks: the buttons with a lip over and under them, as round the bars, so the
	-- console is one make (the buttons' size moves in steps; the band it left over a rack's rows read as a
	-- thicker rim). Never taller than the roof asked for, nor under a window's smallest.
	tall = min(tall, Stand(block + 2 * C.RIM))
	g.wingTop = g.floor + tall

	-- Fit the screen: a rack's room (a seam plus its width) comes off both wings
	-- equally, so the console stays symmetric. A rack with no room beside a
	-- minimum-width wing isn't built.
	local half = want.screen / 2
	local past = C.SEAM + rackWidth
	local rackLeft = want.rackLeft and right + C.SEAM + limits.chatWidth[1] + cl + cr + past <= half + 0.001
	local rackRight = want.rackRight
		and right + (want.meter and C.SEAM + limits.meterWidth[1] + ml + mr or 0) + past <= half + 0.001
	local room = half - right - C.SEAM
	if rackLeft or (rackRight and want.meter) then room = room - past end
	local wing = min(size.wing, floor(room))

	g.chat = {
		width = Clamp(wing - cl - cr, limits.chatWidth),
		height = Clamp(tall - ct - cb, limits.chatHeight),
		right = left - C.SEAM - cr,   -- the frame's own corner, art excluded
		bottom = g.floor + cb,
	}
	g.chat.art = Art(g.chat.right - g.chat.width, g.chat.bottom, g.chat.width, g.chat.height, want.chat)
	g.left = g.chat.right + cr - (g.chat.width + cl + cr)
	g.right = right
	if want.meter then
		g.meter = {
			width = Clamp(wing - ml - mr, limits.meterWidth),
			height = Clamp(tall - mt - mb, limits.meterHeight),
			left = right + C.SEAM + ml,   -- the frame's own corner, art excluded
			bottom = g.floor + mb,
		}
		g.meter.art = Art(g.meter.left, g.meter.bottom, g.meter.width, g.meter.height, want.meter)
		g.right = g.meter.left - ml + (g.meter.width + ml + mr)
	end

	g.rack = {
		kind = "rack", flat = false, columns = columns, rows = rows,
		percent = percent,
		width = rackWidth,
		bottom = g.floor + (tall - block) / 2,                                      -- bar centred in the wing's height
		left = rackLeft and true or false, right = rackRight and true or false,
		lines = columns, icons = columns * rows,   -- upright: Edit Mode's "rows" are its columns
		foot = g.floor, top = g.wingTop,
	}
	g.wings = { left = g.left, right = g.right }   -- wings' outer ends; racks are a seam beyond
	g.rack.slots = {
		[1] = { g.wings.right + C.SEAM + C.PAD, g.rack.bottom },
		[-1] = { g.wings.left - C.SEAM - C.PAD, g.rack.bottom },
	}
	g.rack.rects = {
		[1] = g.rack.right and { g.wings.right + C.SEAM, g.floor, g.wings.right + C.SEAM + rackWidth, g.wingTop } or nil,
		[-1] = g.rack.left and { g.wings.left - C.SEAM - rackWidth, g.floor, g.wings.left - C.SEAM, g.wingTop } or nil,
	}
	if g.rack.left then g.left = g.left - C.SEAM - g.rack.width end
	if g.rack.right then g.right = g.right + C.SEAM + g.rack.width end

	-- Deck beside the console's left end when the screen is wide enough; else on the chat roof (Arrange.lua).
	g.deck = { left = g.left - C.SEAM - C.DECK, beside = g.left - C.SEAM - C.DECK >= -want.screen / 2 }
	g.span = { left = g.left, right = g.right }
	return g
end
