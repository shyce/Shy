-- Shy.HUD.Grip: a piece's bottom right corner bracket as its handle. Under the mouse the bracket
-- lights, three strokes fill its elbow and the cursor shows which way the drag goes. A drag resizes
-- the piece (its top left corner stays put), a click locks or unlocks it (a padlock stands in the
-- corner of a locked piece, which neither drags nor resizes, and shows for a moment when the piece
-- is pressed to drag it), a right click opens its menu.
--
-- Every box of ours whose panel wears brackets has one without asking: the panel on the box itself
-- or on a frame given to HUD.Manage. Its drag sets the box's scale: a sheet over the box says the size
-- against its own, and the drag holds at 100% when it comes near. A box that keeps sizes of its
-- own (ownSize) has none, and one built into another piece (still) doesn't answer.
--
-- Such a box is held all the way round as well: every corner and every side scales it, what lies
-- opposite the handle staying put (dragged by its left, the right edge stays; by its top, the foot;
-- otherwise the left edge and the top). A window's other corners are like its first. Any other piece
-- keeps its inside to itself: its other corners are small and bare, and a side is its border alone.
-- On a small piece an arm is no longer than its side can spare, and a side with no room is left out.
--
-- A game frame with a width and height of its own (`size`) is taken hold of all the way round: the
-- same handle on its bottom left and top left corners, each of its four sides (a side takes the
-- mouse on its border alone, with none of a corner's room to spare, and that border lights under
-- it), and a small corner where the top and right sides meet, with no strokes, since a piece keeps
-- its buttons there. Each sizes the piece from where it is, what lies
-- opposite staying put, so a piece is fitted without being moved first. A side has no lock of its
-- own: on a locked piece the sides are gone and the corners show the padlock.
--
-- A box of ours says how it is held where it is made, and needs no call here:
--   Shy.HUD.Create{ ... }                           -- nothing said: every corner and side scales it
--   Shy.HUD.Create{ ..., grip = false }             -- no handles
--   Shy.UI.Window{ ..., grip = { flow = true } }    -- it flows: a drag sets its width and height
--   grip = {
--       flow = true,                      -- its children hang from its edges and follow by themselves, or
--       flow = function(box, width, height) end,   -- lays its inside out at that size (own units): called on
--                                         -- every frame of a drag that changes it, when a kept size is put
--                                         -- on as it loads, and when "Reset size" gives the made size back
--       min = { 300, 200 },               -- the least it flows to (the size it was made at, unless told)
--       max = { 900, nil },               -- the most (the screen, either way, unless told)
--       corners = "full" | "slim" | "foot",   -- its other corners like its first, or small and bare (a window's
--                                         -- are full, any other piece's slim, unless told); "foot": the one
--                                         -- at its foot like the first, the top one bare (tools in its header)
--       points = { "BOTTOM", ... } | function() end,   -- only these handles (all, unless told); a function is
--                                         -- asked again whenever the grip looks (grip:Follow())
--       past = 5,                         -- how far past its edge a side takes the mouse (a hair, unless told)
--       over = frame,                     -- the frame of its own the handles stand on (the one that wears
--                                         -- the brackets, unless told)
--       hung = "TOP",                     -- it hangs from another piece by that point (a carried box its
--                                         -- owner anchors): it scales about that point and stays hung
--       core = 8, tip = "Drag to ...", menu = function(root) end,   -- as below
--   }
-- The grip does the rest of a flow: sizes the box, keeps what lies opposite the handle still, keeps the
-- size with the box's place and gives it up on "Reset size". The scale is left to the box's menu.
--
--   Shy.HUD.Grip(box, opts)               -- the same table, for a box made earlier
--   Shy.HUD.Grip(box, { over = frame })   -- a box of ours whose brackets are on another frame of its own
--   Shy.HUD.Grip(box, {                   -- an adopted game frame (the chat, the damage meter):
--       size = true,                      -- a drag sets its width and height (HUD.Sized) with the
--                                         -- engine's own sizing, so it redraws as Edit Mode's does
--       over = function() end,            -- the region whose corners it stands on now (nil: no grip)
--       shown = function() end,           -- optional: no grip while false
--       seen = function() end,            -- optional: the frame whose alpha says the piece is on screen (the
--                                         -- piece's own unless told: the chat's, faded under a page laid over it)
--       above = function(point) end,      -- optional: a frame of the game's lying over that part of the
--                                         -- piece on a layer of its own (the chat's edit box over its
--                                         -- foot, its tabs over its top); the handle stands over it.
--                                         -- point: "BOTTOMRIGHT", "TOPLEFT", "LEFT", "TOP" ...
--   })
--   Shy.HUD.Grip(box, {                   -- a box of ours that shapes itself (ShyBags' window): held all
--       over = frame,                     -- the way round, every corner and side, as a sized game frame is
--       shape = function(wider, taller, phase, point) end,   -- how much wider and taller the handle at
--                                         -- `point` asks the box to be, in its own units, since it was
--                                         -- pressed (a side asks one way: the other is nil); phase "start"
--                                         -- as the drag begins, "drag" as it moves, "stop" as it is let go.
--                                         -- The owner sizes the box (HUD.Resize) and holds its other edges
--                                         -- still with Shy.HUD.Hold. The box's scale is left to its menu.
--       tip = "Drag to ...",              -- optional: what the corner says in place of "Drag to resize."
--       core = 8,                         -- optional: a smaller square in the corner (16), where the box
--                                         -- keeps something of its own
--       menu = function(root) end,        -- optional: entries on top of the box's menu (as HUD.Manage's)
--       corners, points, past,            -- optional: as above (ShyQuest's card: held by its foot alone
--                                         -- while a deck carries it)
--   })
--   local hold = Shy.HUD.Hold(box, point) -- the edges a handle at `point` doesn't move, held where they
--                                         -- are: hold() after each resize, hold(true) after the last
--   Shy.HUD.GripFrame(frame, opts)        -- a game window that is no piece of the screen, which an addon
--                                         -- moves and keeps itself: every handle scales it (see there)
--   Shy.HUD.Grip(box)                     -- the box's grip (its bottom right handle), or nil;
--                                         -- grip.at[point] is each handle, grip:Follow() looks again now
--   Shy.HUD.GripReport()                  -- what the mouse is on and how every grip stands (/shy grip)
--   Shy.HUD.Made(box, width, height)      -- a flowing box's size is planned (a home's width, a setting's rows):
--                                         -- worn now unless the player kept one; "Reset size" gives it back
-- A box of ours folded away to its header (Shy.HUD.Folded) has no size to be dragged to: no handles while it is;
-- they come back as it opens.
--
-- The art is drawn for the bottom right corner (Grip.tga, GripLock.tga): the numbers below are its.
-- The other corners show the strokes mirrored; the padlock is never mirrored.

local Shy = Shy
local HUD, UI, Theme, B = Shy.HUD, Shy.UI, Shy.Theme, Shy.Brand
local Act = HUD.Act
local abs, floor, max, sqrt = math.abs, math.floor, math.max, math.sqrt

local GRIP, LOCK = Shy.MEDIA .. "Grip", Shy.MEDIA .. "GripLock"
local ART, LOCK_ART = 16, 8     -- the strokes' square from the corner, and the padlock's
local ELBOW = 3.2               -- where the art begins, clear of the bracket's arms
-- What takes the mouse is an L laid in the corner: a square as large as the game's own resize buttons,
-- and an arm along each edge beyond it, so the grip is found anywhere near the corner while what the
-- piece holds there stays free. All of it reaches OUT past the piece's edge.
local CORE, OUT = 16, 4         -- the square's side inside the corner, and the reach past the edges
local ARM, DEPTH = 14, 6        -- an arm's length beyond the square, and how far in from the edge it lies
-- A side takes the mouse on the border alone, with no room to spare as a corner has: the panel's
-- edge (BORDER wide) and a hair past it. Under the mouse that border is what lights.
local BORDER, PAST = 3, 2
local SMALL = 8                 -- the top right corner's square: short of the buttons a piece keeps there
local MIN_SIDE = 6              -- a side shorter than this between its corners is left out
local GLOW = 30
local DRAG_START = 6            -- pixels a press travels before it is a drag (as HUD's own)
local FADE, FLASH = 0.12, 0.4   -- seconds: the light coming up, and the gleam as a lock turns
local REST = 0.3                -- share of the hover rest (Shy.Hover.Rest) on the corner before it says what it does
local TELL = 0.9                -- seconds the padlock shows when a locked piece is pressed to drag it
local RISE = 40                 -- frame levels over the piece
local OVER = 10                 -- and over a frame lying on the piece (it is raised often: a small step)
local POLL = 0.25               -- seconds between looks at a game frame's piece

local BRACKET = { TOPLEFT = 1, TOPRIGHT = 2, BOTTOMLEFT = 3, BOTTOMRIGHT = 4 }   -- UI.BRACKETS
-- Each handle's cursor runs the way its drag goes. The game has one resize cursor, running down to the
-- right, and shows no cursor art but its own (a black square for any other file), so a handle puts the
-- game's cursor out of sight and draws that same gold arrow on the mouse, turned its own way.
-- Out of sight, as far as the game goes: it has no empty cursor (each of its cursor modes shows
-- something, "no cursor" the hand), so this is its emptiest, the one that carries an item. A small
-- gold corner of it stays at the mouse, on the arrow.
local BLANK = "Interface\\Cursor\\Item.crosshair"
local ARROW = "Interface\\Cursor\\UIResizeCursor2x"
local SHEET_W, SHEET_H = 512, 256
-- The arrow's squares on that sheet, small to large: left, top, side. It runs corner to corner of each.
local CELLS = { { 260, 66, 29 }, { 392, 0, 44 }, { 260, 0, 58 }, { 0, 130, 86 }, { 0, 0, 114 } }
local CURSOR_SIZE = { [0] = 32, 48, 64, 96, 128 }   -- screen pixels, by the cursorSizePreferred setting
local ARROW_PART = 0.72                             -- the arrow's side to a cursor's: under the game's own 0.9
local QUARTER = math.pi / 4
local TURN = {                                      -- counter-clockwise from the art's own diagonal
	BOTTOMRIGHT = 0, TOPLEFT = 0, BOTTOMLEFT = 2 * QUARTER, TOPRIGHT = 2 * QUARTER,
	LEFT = QUARTER, RIGHT = QUARTER, TOP = -QUARTER, BOTTOM = -QUARTER,
}
local HELD = 8001                                   -- a dragged handle's frame level, over the catcher's

local grips = {}                                    -- every grip (a piece's bottom right handle)
local byBox = setmetatable({}, { __mode = "k" })    -- box -> its grip
local handles = setmetatable({}, { __mode = "k" })  -- box -> frames given to HUD.Manage
local waiting = setmetatable({}, { __mode = "k" })  -- boxes looked at again when they show
local over, pressed, drag                           -- the handle under the mouse; a press; a drag
local pointed                                       -- the handle that set the cursor
local Follow, Layer, Fit
local driver = CreateFrame("Frame")
-- A scaled box hangs from this by its top left corner while it is dragged, so only its scale changes.
local pin = CreateFrame("Frame", nil, UIParent)
pin:SetSize(1, 1)

-- "size", "shape", "scale", or nil while the handle does nothing.
local function Mode(h)
	local box = h.box
	if box.retired or box.still or Act.Busy(box) or not Act.Active(box) then return nil end
	-- A game window that is no piece of the screen (HUD.GripFrame): it scales, or the engine sizes it as the
	-- game's own corner does. Locked, its sides are gone.
	-- One that shapes itself (ShySkin's spellbook, which flows): its owner is told how far the handle went.
	if box.loose then
		if h.opts.shape then return "shape" end
		return box.sizes and "size" or "scale"
	end
	if box.foreign then
		return h.opts.size and HUD.IsSized(box.foreign) and "size" or nil
	end
	-- Its sides are part of it and stay on it: locked, they answer nothing.
	if h.edge and Act.IsLocked(box) then return nil end
	-- The side a box hangs by doesn't move: nothing to drag there.
	if h.edge and h.opts.hung == h.point then return nil end
	if h.opts.shape then return "shape" end
	-- As tall as the window it is docked beside (`dock.tall`): its top and foot are that window's to move.
	if h.edge and (h.point == "TOP" or h.point == "BOTTOM") and h.opts.flow and HUD.DockTall(box) then return nil end
	if h.opts.flow then return "flow" end
	if Act.Scalable(box) and not box.ownSize then return "scale" end
	return nil
end

local function Held(h)
	return drag ~= nil and drag.grip == h
end

-- A handle is dragged (HUD.InHand asks).
function HUD.Sizing()
	return drag ~= nil
end

-- The light comes up and goes down; a gleam crosses as the lock turns.
local function Animate(h, elapsed)
	local level, target = h.level, h.target
	if level < target then
		level = math.min(target, level + elapsed / FADE)
	elseif level > target then
		level = max(target, level - elapsed / FADE)
	end
	h.level = level
	h.art:SetAlpha(level)
	if h.flash > 0 then
		h.flash = max(0, h.flash - elapsed / FLASH)
		h.spark:SetAlpha(h.flash)
	end
	if level == target and h.flash == 0 then h:SetScript("OnUpdate", nil) end
end

local function Fade(h, target)
	h.target = target
	if h.level ~= target or h.flash > 0 then h:SetScript("OnUpdate", Shy.Clocked("grip: a handle lighting", Animate)) end
end

-- What stands in a corner: the strokes on a piece that can be resized, the padlock on a locked one.
-- A side has its line and nothing else.
local function Dress(h)
	if h.edge then return end
	local locked = Act.IsLocked(h.box)
	Theme.Tint(h.lit, locked and UI.colors.dim or Theme.AccentSolid)
	h.lines:SetShown(not locked and not h.bare)
	h.glow:SetShown(not locked)
	h.lock:SetShown(locked and not h.bare)
end

-- The arrow: a texture kept on the mouse while a handle has the cursor.
local arrow = CreateFrame("Frame", nil, UIParent)
arrow:SetSize(1, 1)
arrow:SetFrameStrata("TOOLTIP")
arrow:SetFrameLevel(9000)
arrow:Hide()
arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
arrow.tex:SetTexture(ARROW)
arrow.tex:SetPoint("CENTER")
arrow.tex:SetSnapToPixelGrid(false)   -- it moves by less than a pixel
arrow.tex:SetTexelSnappingBias(0)

local function OnMouse(self)
	local x, y = GetCursorPosition()
	local ui = UIParent:GetEffectiveScale()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / ui, y / ui)
end
arrow:SetScript("OnUpdate", OnMouse)

-- As large as the game draws its own: the size the player chose, or by the screen where the game picks.
local function ShowArrow(point)
	local _, high = GetPhysicalScreenSize()
	local pixels = (CURSOR_SIZE[tonumber(C_CVar.GetCVar("cursorSizePreferred")) or -1] or (high >= 2000 and 48 or 32)) * ARROW_PART
	local cell = CELLS[#CELLS]
	for _, c in ipairs(CELLS) do
		if c[3] >= pixels * 1.5 then   -- drawn from a larger one where there is one, to turn cleanly
			cell = c
			break
		end
	end
	local side = pixels * UIParent:GetHeight() / high
	local tex = arrow.tex
	tex:SetTexCoord(cell[1] / SHEET_W, (cell[1] + cell[3]) / SHEET_W, cell[2] / SHEET_H, (cell[2] + cell[3]) / SHEET_H)
	tex:SetSize(side, side)
	tex:SetRotation(TURN[point])
	arrow.point = point
	OnMouse(arrow)
	arrow:Show()
end

-- While a handle sizes a box, a sheet lies over the box: a see-through dark, and in its middle what the box is
-- now, large, so you watch the box and not the mouse. Scaled, that is its size against its own (100%), with a
-- needle on a track under it: half at the left end, twice at the right, its own size on the notch. Near its own
-- size the drag holds there and the number lights. Flowing, it is its width and height. Shift held, nothing holds.
-- The sheet hangs from the box's corners, so the engine keeps it on the box: only a new number costs anything.
local SHEET = {
	SNAP = 0.03,           -- this close to its own size, it is its own size
	REACH = 8,             -- this near a line of the grid, a flowing box's dragged edge lands on it
	DARK = 0.45,           -- the dark over the box
	TRACK = 120,           -- the track's length
	GLEAM = 0.35,          -- seconds: the light as it holds at its own size
	LEVEL = HELD - 10,     -- over all the box holds, under the dragged handle
	TYPES = { 44, 32, 22, 15 },   -- the number's sizes: the largest that fits the box
	LOG2 = math.log(2),
	TIMES = " \195\151 ",
}

-- Built the first time a box is sized.
local function Sheet()
	local s = SHEET.frame
	if s then return s end
	s = CreateFrame("Frame", nil, UIParent)
	SHEET.frame = s
	s:SetFrameStrata("TOOLTIP")
	s:SetFrameLevel(SHEET.LEVEL)
	s:Hide()
	s.dark = s:CreateTexture(nil, "BACKGROUND")
	s.dark:SetAllPoints()
	Theme.Paint(s.dark, 0, 0, 0, SHEET.DARK)
	-- Deeper where the number stands, so it reads over a busy window.
	s.pool = s:CreateTexture(nil, "BORDER")
	s.pool:SetTexture(B.GLOW)
	s.pool:SetPoint("CENTER")
	Theme.Tint(s.pool, 0, 0, 0, 0.6)
	s.gleam = s:CreateTexture(nil, "ARTWORK")
	s.gleam:SetTexture(B.GLOW)
	s.gleam:SetBlendMode("ADD")
	s.gleam:SetPoint("CENTER")
	Theme.Tint(s.gleam, Theme.AccentSolid, 0.45)
	s.gleam:SetAlpha(0)
	s.size = UI.Words(s, UI.TitleFont(SHEET.TYPES[1]), UI.colors.text, { justify = "CENTER", wrap = false })
	s.track = s:CreateTexture(nil, "ARTWORK")
	s.track:SetSize(SHEET.TRACK, 1)
	Theme.Paint(s.track, UI.colors.dim, 0.8)
	s.notch = s:CreateTexture(nil, "ARTWORK", nil, 1)
	s.notch:SetSize(1, 7)
	s.notch:SetPoint("CENTER", s.track, "CENTER")
	s.needle = s:CreateTexture(nil, "OVERLAY")
	s.needle:SetSize(3, 13)
	s.hint = UI.Words(s, UI.TitleFont(12), UI.colors.dim, { justify = "CENTER", wrap = false })
	s.lit = 0
	s.fade = Shy.Clocked("grip: the size sheet gleaming", function(self, elapsed)
		self.lit = max(0, self.lit - elapsed / SHEET.GLEAM)
		self.gleam:SetAlpha(self.lit)
		if self.lit == 0 then self:SetScript("OnUpdate", nil) end
	end)
	return s
end

-- What Shift does, said under the number where there is room.
local function SayFree(free)
	local s = SHEET.frame
	if not s or s.free == free then return end
	s.free = free
	s.hint:SetText(free and "Any size" or "Hold Shift for any size")
	Theme.Ink(s.hint, free and Theme.AccentSolid or UI.colors.dim)
end

-- The sheet at `ratio` of the box's own size. Asked only when the size changed.
local function SayScale(ratio)
	local s = Sheet()
	local percent = floor(ratio * 100 + 0.5)
	if s.said ~= percent then
		s.said = percent
		s.size:SetText(percent .. "%")
	end
	local way = math.log(ratio) / SHEET.LOG2
	s.needle:SetPoint("CENTER", s.track, "CENTER", max(-1, math.min(1, way)) * SHEET.TRACK / 2, 0)
	local at = abs(ratio - 1) < 0.0005
	if s.at == at then return end
	s.at = at
	local ink = at and Theme.AccentSolid or UI.colors.text
	Theme.Ink(s.size, ink)
	Theme.Paint(s.needle, ink)
	Theme.Paint(s.notch, at and Theme.AccentSolid or UI.colors.dim)
	if at and s:IsShown() then
		s.lit = 1
		s.gleam:SetAlpha(1)
		s:SetScript("OnUpdate", s.fade)
	end
end

-- A flowing box: its width and height, in its own units.
local function SaySize(width, height)
	local s = Sheet()
	local said = floor(width + 0.5) .. SHEET.TIMES .. floor(height + 0.5)
	if s.said == said then return end
	s.said = said
	s.size:SetText(said)
end

-- Over the frame the handle stands on, its number as large as the box allows. `scaled`: with the track.
local function ShowSheet(h, scaled)
	local s = Sheet()
	local region = h.region or h.on or h.box
	s:ClearAllPoints()
	s:SetPoint("TOPLEFT", region, "TOPLEFT")
	s:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
	local _, _, width, height = Act.Rect(h.box)
	width, height = width or 200, height or 100
	local letters = scaled and 4 or 11
	local size = SHEET.TYPES[#SHEET.TYPES]
	for _, each in ipairs(SHEET.TYPES) do
		if each <= height * 0.36 and each * letters * 0.58 <= width * 0.85 then
			size = each
			break
		end
	end
	if s.type ~= size then
		s.type = size
		s.size:SetFontObject(UI.TitleFont(size))
	end
	local track = scaled and height >= size * 2.4 and width >= SHEET.TRACK + 24
	local hint = height >= size * 3.2 and width >= 150
	s.track:SetShown(track)
	s.notch:SetShown(track)
	s.needle:SetShown(track)
	s.hint:SetShown(hint)
	-- The number, its track and its words stand as one group in the box's middle.
	s.size:ClearAllPoints()
	s.size:SetPoint("CENTER", s, "CENTER", 0, (track and 10 or 0) + (hint and 9 or 0))
	s.track:ClearAllPoints()
	s.track:SetPoint("TOP", s.size, "BOTTOM", 0, -size * 0.3)
	s.hint:ClearAllPoints()
	s.hint:SetPoint("TOP", track and s.track or s.size, "BOTTOM", 0, track and -12 or -6)
	s.pool:SetSize(size * 5, size * 3)
	s.gleam:SetSize(size * 4, size * 2.2)
	s.said, s.at, s.free = nil, nil, nil
	Theme.Ink(s.size, UI.colors.text)
	SayFree(IsShiftKeyDown())
	s:Show()
	return s
end

local function HideSheet()
	local s = SHEET.frame
	if not s then return end
	s:Hide()
	s:SetScript("OnUpdate", nil)
	s.lit = 0
	s.gleam:SetAlpha(0)
end

-- While a handle is dragged the mouse can outrun it. This lies under the mouse everywhere else, taking
-- no clicks, so neither the world nor another frame puts a cursor of its own back.
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("TOOLTIP")
catcher:SetFrameLevel(HELD - 1)
catcher:EnableMouse(true)
catcher:SetMouseClickEnabled(false)
catcher:Hide()
catcher:SetScript("OnEnter", function()
	if pointed then SetCursor(BLANK) end
end)
catcher:SetScript("OnUpdate", function(self)
	if not drag then self:Hide() end
end)

local function Point(h, on)
	if on then
		pointed = h
		arrow.hid = SetCursor(BLANK)
		ShowArrow(h.point)
	elseif pointed == h then
		pointed = nil
		arrow:Hide()
		SetCursor(nil)
		ResetCursor()
	end
end

-- The handle whose cursor is drawn now and how far it is turned, or nil: the game's own cursor.
function HUD.GripCursor()
	if not arrow:IsShown() then return nil end
	return arrow.point, TURN[arrow.point]
end

-- A window's title drags it whatever its lock: there the lock holds its size alone. A side turns no lock.
local function Say(h)
	local box, locked = h.box, Act.IsLocked(h.box)
	local title = box.title
	if type(title) == "function" then title = title() end
	-- A game window that is no piece of the screen has no menu of ours.
	local more = not box.loose and { "right", "Options" } or nil
	-- (What the drag does may differ by where the piece stands: a function says it as it is asked.)
	local tip = h.opts.tip
	if type(tip) == "function" then tip = tip() end
	if h.edge then
		UI.Tip(h, title or "", tip or "Drag to resize.", { side = "CURSOR", hints = more and { more } or nil })
		return
	end
	UI.Tip(h, title or "", locked and (box.window and "Its size is locked." or "Locked in place.") or tip or "Drag to resize.",
		{ hints = { { "left", locked and "Unlock" or "Lock" }, more } })
end

-- A corner moves the two sides that meet in it, so they light with it: each side's border, whole.
local SIDES = {
	BOTTOMRIGHT = { "BOTTOM", "RIGHT" }, BOTTOMLEFT = { "BOTTOM", "LEFT" },
	TOPLEFT = { "TOP", "LEFT" }, TOPRIGHT = { "TOP", "RIGHT" },
}
local ENDS = {
	LEFT = { "TOPLEFT", "BOTTOMLEFT" }, RIGHT = { "TOPRIGHT", "BOTTOMRIGHT" },
	TOP = { "TOPLEFT", "TOPRIGHT" }, BOTTOM = { "BOTTOMLEFT", "BOTTOMRIGHT" },
}

-- Under the mouse or held, on a piece that allows it.
local function Lit(h)
	return Mode(h) ~= nil and (over == h or Held(h))
end

-- The handle's look. A side is lit by a corner at either end as well, unless the piece is locked.
local function Glow(h)
	local lit = Lit(h)
	if not lit and h.edge and not Act.IsLocked(h.box) then
		local g = byBox[h.box]
		for _, point in ipairs(ENDS[h.point]) do
			local corner = g and g.at[point]
			if corner and Lit(corner) then lit = true end
		end
	end
	if lit then Dress(h) end
	Fade(h, lit and 1 or 0)
end

-- The handle's look and the cursor, from where the mouse is and what the piece allows.
local function Refresh(h)
	Glow(h)
	if not h.edge then
		local g = byBox[h.box]
		for _, point in ipairs(SIDES[h.point]) do
			local side = g and g.at[point]
			if side then Glow(side) end
		end
	end
	if not drag then Point(h, Lit(h) and not Act.IsLocked(h.box)) end
end

local function Enter(h)
	over = h
	Refresh(h)
	if not Mode(h) then return end
	local rest = {}
	h.rest = rest
	C_Timer.After(Shy.Hover.Rest(REST), function()
		if h.rest == rest and over == h and not drag and not pressed then Say(h) end
	end)
end

local function Leave(h)
	if over == h then over = nil end
	h.rest = nil
	UI.TipHide(h)
	Refresh(h)
end

-- A game frame: the engine sizes it from the handle's place, as Edit Mode's own handle does from the
-- bottom right corner.
local function BeginSize(h)
	local box = h.box
	local frame = box.foreign
	drag = { grip = h, box = box, mode = "size", point = h.point, resizable = frame:IsResizable() }
	frame:SetResizable(true)   -- the damage meter is resizable in Edit Mode only
	if box.loose then
		if h.opts.held then h.opts.held(frame, true) end
	else
		Shy:Fire("SHY_HUD_MOVING", box)
	end
	frame:StartSizing(h.point)
end

local function EndSize()
	local box, point = drag.box, drag.point
	local frame = box.foreign
	frame:StopMovingOrSizing()
	-- A game window that is no piece of the screen: its owner keeps the size, as after the game's own corner.
	if box.loose then
		if not drag.resizable then frame:SetResizable(false) end
		local opts = drag.grip.opts
		if opts.held then opts.held(frame, false) end
		if opts.kept then opts.kept(frame) end
		return
	end
	frame:SetUserPlaced(false)   -- its place and size are kept here, not in the client's layout cache
	if not drag.resizable then frame:SetResizable(false) end
	local left, bottom, width, height = Act.Rect(box)
	if not left then
		Shy:Fire("SHY_HUD_MOVED", box)
		return
	end
	local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local saved = Act.Keep(box)
	saved.w, saved.h = floor(width / s + 0.5), floor(height / s + 0.5)
	-- The engine anchored the frame anew. Back on its own anchors at the new size; where those don't
	-- leave the edges the drag never moved where they were, it is kept there as a place the player set.
	box.placed = true
	HUD.Apply(box)
	local nowLeft, nowBottom, nowWidth, nowHeight = Act.Rect(box)
	if not nowLeft then
		Act.Place(box, left, bottom)
		Act.Remember(box)
		return
	end
	-- Dragged by its left, the right edge stays; by its top, the foot; otherwise the left edge and the top.
	local wantLeft = point:find("LEFT", 1, true) and (left + width - nowWidth) or left
	local wantBottom = point:find("TOP", 1, true) and bottom or (bottom + height - nowHeight)
	if abs(nowLeft - wantLeft) > 0.75 or abs(nowBottom - wantBottom) > 0.75 then
		Act.Place(box, wantLeft, wantBottom)
		Act.Remember(box)
	else
		Shy:Fire("SHY_HUD_MOVED", box)
	end
end

-- Where a point lies on a piece: 0 to 1 across, 0 to 1 up.
local function Share(point)
	local across = point:find("LEFT", 1, true) and 0 or point:find("RIGHT", 1, true) and 1 or 0.5
	local up = point:find("BOTTOM", 1, true) and 0 or point:find("TOP", 1, true) and 1 or 0.5
	return across, up
end

-- A box of ours: hung from the pin by the corner opposite the handle, its scale follows the mouse away
-- from there, along its diagonal from a corner and straight out from a side.
local function BeginScale(h, x, y)
	local box, point = h.box, h.point
	local left, bottom, width, height = Act.Rect(box)
	if not left or width <= 0 or height <= 0 then return end
	local ui = UIParent:GetEffectiveScale()
	-- Dragged by its left, the right edge stays; by its top, the foot; otherwise the left edge and the top.
	-- A box hung from another piece by one of its points (opts.hung) scales about that point instead.
	local byLeft, byTop = point:find("LEFT", 1, true) ~= nil, point:find("TOP", 1, true) ~= nil
	local to = h.opts.hung or ((byTop and "BOTTOM" or "TOP") .. (byLeft and "RIGHT" or "LEFT"))
	local fx, fy = Share(to)
	local px, py = Share(point)
	local ax, ay = left + fx * width, bottom + fy * height
	local ux, uy = (px - fx) * width, (py - fy) * height
	if point == "LEFT" or point == "RIGHT" then
		uy = 0
	elseif point == "TOP" or point == "BOTTOM" then
		ux = 0
	end
	local span = sqrt(ux * ux + uy * uy)
	if span < 1 then return end
	ux, uy = ux / span, uy / span
	local reach = (x / ui - ax) * ux + (y / ui - ay) * uy
	if reach < 1 then reach = span end
	drag = { grip = h, box = box, mode = "scale", ui = ui, ax = ax, ay = ay, ux = ux, uy = uy,
		reach = reach, from = box:GetScale(), base = Act.Base(box) }
	if box.loose then
		-- Its owner puts it back whenever it is anchored: told to let it be, and its anchors kept to go back to.
		drag.points = {}
		for i = 1, box:GetNumPoints() do drag.points[i] = { box:GetPoint(i) } end
		if h.opts.held then h.opts.held(box.foreign, true) end
	end
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ax, ay)
	HUD.Attach(box, pin, to, "CENTER", 0, 0)
	ShowSheet(h, true)
	SayScale(drag.from / drag.base)
	if not box.loose then Shy:Fire("SHY_HUD_MOVING", box) end
end

-- In thousandths: a window follows the mouse by less than a pixel. Near its own size it holds there.
local function StepScale()
	local x, y = GetCursorPosition()
	local along = (x / drag.ui - drag.ax) * drag.ux + (y / drag.ui - drag.ay) * drag.uy
	local scale, base = drag.from * max(along, 0) / drag.reach, drag.base
	local free = IsShiftKeyDown()
	SayFree(free)
	if not free and abs(scale / base - 1) < SHEET.SNAP then scale = base end
	scale = floor(scale * 1000 + 0.5) / 1000
	if scale ~= drag.asked then
		drag.asked = scale
		drag.now = Act.Rescale(drag.box, scale)
		SayScale(drag.now / base)
	end
end

-- A game window that is no piece of the screen: left on the screen by its bottom left corner at its new
-- size for its owner to keep, or back on the anchors it had when nothing came of the drag.
local function EndLoose(box, changed)
	local opts = drag.grip.opts
	local left, bottom = Act.Rect(box)
	local kept = changed and left ~= nil
	if kept then
		Act.Place(box, left, bottom)
	else
		Act.Rescale(box, drag.from)
		box:ClearAllPoints()
		for _, point in ipairs(drag.points) do box:SetPoint(unpack(point)) end
	end
	if opts.held then opts.held(box.foreign, false) end
	if kept and opts.kept then opts.kept(box.foreign) end
end

local function EndScale()
	local box = drag.box
	local changed = drag.now ~= nil and abs(drag.now - drag.from) > 0.001
	if box.loose then
		EndLoose(box, changed)
		return
	end
	local left, bottom = Act.Rect(box)
	-- A box another piece carries (a deck's) keeps its place there: only its size is kept.
	local carried = (box.carried or box.docked) and not HUD.IsPlaced(box)
	if not changed then
		HUD.Apply(box)   -- off the pin, where it was
		Shy:Fire("SHY_HUD_MOVED", box)
	elseif carried or not left then
		Act.Keep(box).scale = box:GetScale()
		HUD.Apply(box)
		Shy:Fire("SHY_HUD_RESIZED", box)
		Shy:Fire("SHY_HUD_MOVED", box)
	else
		Act.Place(box, left, bottom)
		Act.Remember(box)
	end
end

-- A box that shapes itself: its owner is told how far the corner has been dragged from where it was
-- pressed, right and down in the box's own units, and makes of that what it will.
-- How much wider and taller the handle asks the box to be: a left handle dragged left asks for wider,
-- a top one dragged up for taller. A side moves one way only, so the other is nil.
local function Travel()
	local x, y = GetCursorPosition()
	local s = drag.box:GetEffectiveScale()
	local dx, dy = (x - drag.x) / s, (drag.y - y) / s
	local point = drag.point
	local wider = (point:find("RIGHT", 1, true) and dx) or (point:find("LEFT", 1, true) and -dx) or nil
	local taller = (point:find("BOTTOM", 1, true) and dy) or (point:find("TOP", 1, true) and -dy) or nil
	return wider, taller
end

local function BeginShape(h, x, y)
	drag = { grip = h, box = h.box, mode = "shape", x = x, y = y, point = h.point, shape = h.opts.shape }
	Shy:Fire("SHY_HUD_MOVING", h.box)
	local wider, taller = Travel()
	drag.shape(wider and 0, taller and 0, "start", h.point)
end

local function StepShape()
	local wider, taller = Travel()
	if wider == drag.wider and taller == drag.taller then return end
	drag.wider, drag.taller = wider, taller
	drag.shape(wider, taller, "drag", drag.point)
end

local function EndShape()
	local wider, taller = Travel()
	drag.shape(wider, taller, "stop", drag.point)
	Shy:Fire("SHY_HUD_MOVED", drag.box)
end

-- The edges of a box that a handle at `point` doesn't move, held where they are now while the box is
-- resized: hold() after each new size, hold(true) after the last, which keeps the box's place.
function HUD.Hold(box, point)
	local left, bottom, width, height = Act.Rect(box)
	local byLeft, byTop = point:find("LEFT", 1, true) ~= nil, point:find("TOP", 1, true) ~= nil
	return function(done)
		-- A window docked beside another keeps to its side: it grows away from it, whichever handle.
		if Act.Docked and Act.Docked(box) then
			HUD.Apply(box)
			return
		end
		local nowLeft, nowBottom, nowWidth, nowHeight = Act.Rect(box)
		if left and nowLeft then
			-- Dragged by its left, the right edge stays; by its top, the foot; otherwise the left edge and the top.
			local wantLeft = byLeft and (left + width - nowWidth) or left
			local wantBottom = byTop and bottom or (bottom + height - nowHeight)
			if abs(nowLeft - wantLeft) > 0.01 or abs(nowBottom - wantBottom) > 0.01 then
				Act.Place(box, wantLeft, wantBottom)
			end
		end
		if not done then return end
		if box.hang and not byLeft and not byTop then
			HUD.Apply(box)   -- its top left corner never moved: back on its own anchor
		else
			Act.Remember(box)
		end
	end
end

-- A box that flows: the grip itself gives it the width and height the handle asks for, between its
-- least and its most, holds what lies opposite still and keeps the size (the box's entry, as w and h,
-- where a sized game frame's is kept, so the menu's "Reset size" gives it up). The owner only lays
-- the inside out, and not even that where its children hang from the box's edges.
-- A window with a body (UI.Body) is its body and its look's clearance round it: the sizes it is made at, kept at and
-- held between are its body's, and its flow is told its body's; the box is that much bigger, in every look.
-- (A piece on screen keeps the size the plan gives it: its body, where it has one, stands inside that.)
local function Clear(box)
	if not box.window then return 0, 0 end
	local l, t, r, b = UI.BodyIn(box)
	return l + r, t + b
end

local function Bounds(g)
	local box, opts = g.box, g.opts
	local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local cw, ch = Clear(box)
	local least, most = opts.min or g.made, opts.max or {}
	local minW, minH = least[1] + cw, least[2] + ch
	local mostW = most[1] and most[1] + cw or UIParent:GetWidth() / s
	local mostH = most[2] and most[2] + ch or UIParent:GetHeight() / s
	return minW, minH, max(minW, mostW), max(minH, mostH)
end

-- (width and height: the box's)
-- A window docked `tall` beside another is as tall as that one whatever is asked for (HUD.DockTall): every way a
-- grip sizes a flowing box comes through here (a drag, a kept size put on, the box placed again), so it stays so.
-- (Before a grip has hold of it, the same is asked where it is made: UI.Window, HUD.WearMade.)
local function Flow(g, width, height)
	local box = g.box
	local tall = HUD.DockTall(box)
	local minW, minH, maxW, maxH = Bounds(g)
	-- (Beside a host shorter than its least height, it is as tall as the host all the same: never past its foot.)
	width, height = max(minW, math.min(maxW, width)), tall or max(minH, math.min(maxH, height))
	if abs(box:GetWidth() - width) < 0.01 and abs(box:GetHeight() - height) < 0.01 then return false end
	HUD.Resize(box, width, height)
	local cw, ch = Clear(box)
	if type(g.opts.flow) == "function" then g.opts.flow(box, width - cw, height - ch) end
	return true
end

-- The size it keeps, or the one it was made at. Not while it is dragged: the mouse has it. True where that
-- changed its size.
local function Wear(g)
	if not g.made or (drag and drag.box == g.box) or Act.Busy(g.box) then return false end
	local saved = Shy.core.db.hud[g.box.id]
	local cw, ch = Clear(g.box)
	return Flow(g, (saved and saved.w or g.made[1]) + cw, (saved and saved.h or g.made[2]) + ch)
end

local function BeginFlow(h, x, y)
	local box = h.box
	drag = { grip = h, box = box, mode = "flow", x = x, y = y, point = h.point,
		w = box:GetWidth(), h = box:GetHeight(), hold = HUD.Hold(box, h.point) }
	local left, bottom, width, height = Act.Rect(box)
	if left and box:GetWidth() > 0 then
		drag.rect = { l = left, b = bottom, w = width, h = height, s = width / box:GetWidth() }
	end
	local cw, ch = Clear(box)
	ShowSheet(h, false)
	SaySize(drag.w - cw, drag.h - ch)
	Shy:Fire("SHY_HUD_MOVING", box)
end

-- The edges a handle moves land on the grid's lines when they come near (Grid.lua), each lit as a move's is.
-- Not while docked: a docked window's edges are its host's to place.
local function FlowSnap(wider, taller)
	local grid, r = Shy.Grid, drag.rect
	if not (grid and r and grid.Snaps()) or Act.Docked(drag.box) then
		HUD.ShowGuides(nil, nil)
		return wider, taller
	end
	local step, gx, gy = grid.Lines()
	local point, s = drag.point, r.s
	local lineX, lineY
	if wider then
		local right = point:find("RIGHT", 1, true) ~= nil
		local edge = right and r.l + (drag.w + wider) * s or r.l + r.w - (drag.w + wider) * s
		local x = gx + floor((edge - gx) / step + 0.5) * step
		if abs(x - edge) < SHEET.REACH then
			lineX = x
			wider = (right and x - r.l or r.l + r.w - x) / s - drag.w
		end
	end
	if taller then
		local top = point:find("TOP", 1, true) ~= nil
		local edge = top and r.b + (drag.h + taller) * s or r.b + r.h - (drag.h + taller) * s
		local y = gy + floor((edge - gy) / step + 0.5) * step
		if abs(y - edge) < SHEET.REACH then
			lineY = y
			taller = (top and y - r.b or r.b + r.h - y) / s - drag.h
		end
	end
	HUD.ShowGuides(lineX, lineY)
	return wider, taller
end

local function StepFlow()
	SayFree(IsShiftKeyDown())
	local wider, taller = Travel()
	if wider == drag.wider and taller == drag.taller then return end
	drag.wider, drag.taller = wider, taller
	wider, taller = FlowSnap(wider, taller)
	local box = drag.box
	if Flow(byBox[box], drag.w + (wider or 0), drag.h + (taller or 0)) then
		drag.hold()
		local cw, ch = Clear(box)
		SaySize(box:GetWidth() - cw, box:GetHeight() - ch)
	end
end

local function EndFlow()
	StepFlow()
	local box = drag.box
	local g = byBox[box]
	local width, height = floor(box:GetWidth() + 0.5), floor(box:GetHeight() + 0.5)
	local cw, ch = Clear(box)
	local saved = Shy.core.db.hud[box.id]
	-- (As tall as its host while docked beside it: the height it keeps is still the one of its own.)
	if HUD.DockTall(box) then height = (saved and saved.h or g.made[2]) + ch end
	if abs(width - cw - g.made[1]) < 0.5 and abs(height - ch - g.made[2]) < 0.5 then
		if saved then saved.w, saved.h = nil, nil end   -- as it was made: nothing to keep
	else
		saved = Act.Keep(box)
		saved.w, saved.h = width - cw, height - ch   -- (its body's: UI.Body)
	end
	Flow(g, width, height)
	drag.hold(true)
	Shy:Fire("SHY_HUD_MOVED", box)
end

local function Stop()
	driver:SetScript("OnUpdate", nil)
	driver:UnregisterEvent("GLOBAL_MOUSE_UP")
end

-- The mouse let go: a drag ends, or a press on a corner that never became one was a click and turns
-- the lock.
local function Release()
	local was, press = drag, pressed
	if not was and not press then return end
	pressed = nil
	Stop()
	if was then
		if was.mode == "size" then
			EndSize()
		elseif was.mode == "shape" then
			EndShape()
		elseif was.mode == "flow" then
			EndFlow()
		else
			EndScale()
		end
		drag = nil
		catcher:Hide()
		HideSheet()
		if Shy.Grid then
			Shy.Grid.Hide("drag")
			Shy.Grid.See(was.box.foreign or was.box, false)
			if was.mode == "flow" then HUD.ShowGuides(nil, nil) end
		end
		Layer(was.grip)
		Refresh(was.grip)
		return
	end
	local h = press.grip
	if h.edge or not Mode(h) then return end
	Act.Lock(h.box, not Act.IsLocked(h.box))
	h.flash = 1
	Refresh(h)
	if over == h then Say(h) end
	-- The sides go with the lock and come back with it.
	local g = byBox[h.box]
	if g and h.box.foreign then Follow(g) end
end

local function Watch()
	if drag then
		if drag.mode == "scale" then
			StepScale()
		elseif drag.mode == "shape" then
			StepShape()
		elseif drag.mode == "flow" then
			StepFlow()
		end
		return
	end
	if not pressed then
		Stop()
		return
	end
	local x, y = GetCursorPosition()
	if abs(x - pressed.x) + abs(y - pressed.y) < DRAG_START then return end
	local h, fromX, fromY = pressed.grip, pressed.x, pressed.y
	pressed = nil
	local mode = Mode(h)
	if not mode or Act.IsLocked(h.box) then
		Stop()
		return
	end
	if mode == "size" then
		BeginSize(h)
	elseif mode == "shape" then
		BeginShape(h, fromX, fromY)
	elseif mode == "flow" then
		BeginFlow(h, fromX, fromY)
	else
		BeginScale(h, fromX, fromY)
	end
	if not drag then
		Stop()
		return
	end
	Layer(h)
	catcher:Show()
	Refresh(h)
	Point(h, true)
	if Shy.Grid then
		Shy.Grid.Show("drag")
		Shy.Grid.See(h.box.foreign or h.box, true)
	end
end

driver:SetScript("OnEvent", function(_, event)
	if event == "GLOBAL_MOUSE_UP" then
		Release()   -- this client sometimes never delivers the mouse-up to the frame that was pressed
	elseif drag and (drag.box.secure or (drag.box.loose and drag.box.foreign:IsProtected())) then
		Release()   -- a fight begins: a secure box can't be sized in one, nor a protected window
	end
end)
driver:RegisterEvent("PLAYER_REGEN_DISABLED")

local function Down(h, button)
	if button ~= "LeftButton" or not Mode(h) then return end
	local x, y = GetCursorPosition()
	pressed = { grip = h, x = x, y = y }
	h.rest = nil
	UI.TipHide(h, true)
	driver:SetScript("OnUpdate", Shy.Clocked("grip: a handle pressed", Watch))
	driver:RegisterEvent("GLOBAL_MOUSE_UP")
end

local function Up(h, button)
	if button == "LeftButton" then
		Release()
	elseif button == "RightButton" and not drag and Mode(h) and not h.box.loose then
		h.rest = nil
		UI.TipHide(h, true)
		Act.Menu(h.box, h)
	end
end

-- Over the piece, and over what the piece says lies on that part of it (`above`: a frame far above the
-- piece's own layer would hide the handle and take its mouse); in layout mode over the piece's mover,
-- which covers it.
function Layer(h)
	local base = h.box.foreign or h.on
	local strata, level = base:GetFrameStrata(), base:GetFrameLevel() + RISE
	-- A game window draws its border on a frame of its own 500 levels over itself, its title and its x over
	-- that: a handle stands over the highest of them, or its light lies under the border until it is dragged.
	if h.box.loose and h.top then level = max(level, h.top + OVER) end
	local above = h.opts.above and h.opts.above(h.point)
	if above then strata, level = above:GetFrameStrata(), above:GetFrameLevel() + OVER end
	local mover = h.box.mover
	if mover and HUD.IsUnlocked() and mover:IsShown() then
		strata, level = mover:GetFrameStrata(), mover:GetFrameLevel() + RISE
	end
	if Held(h) then strata, level = "TOOLTIP", HELD end   -- over the catcher: it keeps the mouse it has
	if h.strata ~= strata then
		h.strata = strata
		h:SetFrameStrata(strata)
	end
	if h.layer ~= level then
		h.layer = level
		h:SetFrameLevel(level)
	end
end

local function Stand(h, region)
	if h.region == region then return end
	h.region = region
	h:ClearAllPoints()
	h.place(h, region)
end

-- On screen, as far as can be told: a game frame's visibility and alpha can be secret.
local function Seen(frame, region)
	local visible = region:IsVisible()
	if issecretvalue(visible) or visible ~= true then return false end
	local alpha = frame:GetEffectiveAlpha()
	return not issecretvalue(alpha) and alpha > 0.05
end

-- A handle the piece offers: every one, unless it names which (opts.points: a list, or a function giving one).
local function Offered(h)
	local points = h.opts.points
	if type(points) == "function" then points = points() end
	if not points then return true end
	for _, point in ipairs(points) do
		if point == h.point then return true end
	end
	return false
end

-- A game frame's handles are no children of it (unless it says so, opts.inside): they follow the piece by
-- looking. Edit Mode has a handle of its own for the frame while it is open. A locked piece keeps its
-- corners, to be unlocked by.
function Follow(g)
	local box = g.box
	if not box.foreign then
		Fit(g)   -- a box of ours wears its handles: only their fit to its size is looked at
		return
	end
	local held = drag ~= nil and drag.box == box
	local show, region = held, nil
	if not show and Mode(g) and not (box.editMode and EditModeManagerFrame:IsEditModeActive())
		and (not g.opts.shown or g.opts.shown()) then
		region = box.foreign
		if g.opts.over then region = g.opts.over() end
		show = region ~= nil and Seen(g.opts.seen and g.opts.seen() or box.foreign, region)
	end
	-- (Out of sight, with its handles put away at the last look: nothing more to do until it shows. Most game
	-- windows are closed most of the time, and every one of them is looked at each POLL.)
	if show then
		g.away = nil
	elseif g.away then
		return
	else
		g.away = true
	end
	local locked = Act.IsLocked(box)
	-- The highest of a game window's own frames, for its handles to stand over (Layer).
	-- (Looked for again only when the window's level or its count of frames changed: this runs every POLL.)
	local top
	if show and box.loose then
		local level, count = box.foreign:GetFrameLevel(), box.foreign:GetNumChildren()
		if g.topLevel ~= level or g.topCount ~= count then
			g.topLevel, g.topCount = level, count
			top = level
			for _, child in ipairs({ box.foreign:GetChildren() }) do
				if not child:IsForbidden() then top = max(top, child:GetFrameLevel()) end
			end
			g.top = top
		end
		top = g.top
	end
	for _, h in ipairs(g.all) do
		local on = show and not (h.edge and locked and not Held(h)) and (Held(h) or Offered(h))
		if on then
			if region then Stand(h, region) end
			if top then h.top = top end
			Layer(h)
		elseif over == h then
			Leave(h)
		end
		if h:IsShown() ~= on then h:SetShown(on) end
	end
end

local looker = CreateFrame("Frame")
looker:Hide()
looker.since = 0
looker:SetScript("OnUpdate", function(self, elapsed)
	self.since = self.since + elapsed
	if self.since < POLL then return end
	self.since = 0
	looker.Look()
end)
looker.Look = Shy.Clocked("grip: following game windows", function()
	for _, g in ipairs(grips) do
		if g.box.foreign then Follow(g) end
	end
end)

local function Everywhere()
	for _, g in ipairs(grips) do
		if g.box.foreign then
			Follow(g)
		else
			for _, h in ipairs(g.all) do Layer(h) end
		end
	end
end

-- The mouse on any part of a handle is on the handle; passing from one part to another is no leaving
-- (the part left says so first, the part entered in the same frame takes it back).
local function Hover(h)
	h.leaving = nil
	if over ~= h then Enter(h) end
end

local function Unhover(h)
	if h.leaving then return end
	h.leaving = true
	C_Timer.After(0, function()
		if not h.leaving then return end
		h.leaving = nil
		Leave(h)
	end)
end

-- Every part of a handle takes the mouse for it.
local function Mouse(h, parts)
	for _, part in ipairs(parts) do
		part:EnableMouse(true)
		part:SetScript("OnEnter", function() Hover(h) end)
		part:SetScript("OnLeave", function() Unhover(h) end)
		part:SetScript("OnMouseDown", function(_, button) Down(h, button) end)
		part:SetScript("OnMouseUp", function(_, button) Up(h, button) end)
	end
	-- Hidden with the mouse on it, no OnLeave comes.
	h:SetScript("OnHide", function(self)
		if pressed and pressed.grip == self then
			pressed = nil
			Stop()
		end
		self.leaving = nil
		if over == self then Leave(self) end
	end)
end

-- A corner's handle at `point` of its piece: the square, its two arms, and the art, laid from that
-- corner inward. `bare`: the square alone and no strokes or padlock (where a piece keeps its buttons).
local function Corner(parent, point, core, bare)
	local right, top = point:find("RIGHT", 1, true) ~= nil, point:find("TOP", 1, true) ~= nil
	local sx, sy = right and 1 or -1, top and 1 or -1   -- outward from the piece
	local h = CreateFrame("Frame", nil, parent)
	h:SetSize(core + OUT, core + OUT)
	h.point, h.core, h.bare = point, core, bare
	h.armX, h.armY = bare and 0 or ARM, bare and 0 or ARM   -- its arms' lengths: along the foot or top, up the side
	h.level, h.target, h.flash = 0, 0, 0
	h.place = function(self, region) self:SetPoint(point, region, point, sx * OUT, sy * OUT) end
	-- The art fades as one, on a frame of its own that takes no mouse.
	h.art = CreateFrame("Frame", nil, h)
	h.art:SetAllPoints()
	h.art:SetAlpha(0)
	local ix, iy = -sx * OUT, -sy * OUT                        -- the piece's corner, from the handle's
	local ex, ey = -sx * (OUT + ELBOW), -sy * (OUT + ELBOW)    -- the bracket's elbow
	local corner = UI.BRACKETS[BRACKET[point]]
	h.glow = h.art:CreateTexture(nil, "ARTWORK")
	h.glow:SetTexture(B.GLOW)
	h.glow:SetBlendMode("ADD")
	h.glow:SetSize(GLOW, GLOW)
	h.glow:SetPoint("CENTER", h, point, ex, ey)
	Theme.Tint(h.glow, Theme.AccentSolid, 0.35)
	h.lit = h.art:CreateTexture(nil, "OVERLAY")
	h.lit:SetTexture(UI.BRACKET)
	h.lit:SetTexCoord(corner[2], corner[3], corner[4], corner[5])
	h.lit:SetSize(UI.BRACKET_SIZE, UI.BRACKET_SIZE)
	h.lit:SetPoint(point, h, point, ix, iy)
	-- The strokes are drawn for the bottom right corner: mirrored for the others.
	h.lines = h.art:CreateTexture(nil, "OVERLAY", nil, 1)
	h.lines:SetTexture(GRIP)
	h.lines:SetTexCoord(right and 0 or 1, right and 1 or 0, top and 1 or 0, top and 0 or 1)
	h.lines:SetSize(ART, ART)
	h.lines:SetPoint(point, h, point, ix, iy)
	Theme.Tint(h.lines, Theme.AccentSolid)
	h.lock = h.art:CreateTexture(nil, "OVERLAY", nil, 1)
	h.lock:SetTexture(LOCK)
	h.lock:SetSize(LOCK_ART, LOCK_ART)
	h.lock:SetPoint(point, h, point, ex, ey)
	Theme.Tint(h.lock, UI.colors.text)
	h.lock:Hide()
	h.spark = h:CreateTexture(nil, "OVERLAY", nil, 2)
	h.spark:SetTexture(B.GLOW)
	h.spark:SetBlendMode("ADD")
	h.spark:SetSize(GLOW, GLOW)
	h.spark:SetPoint("CENTER", h, point, ex, ey)
	h.spark:SetAlpha(0)
	local parts = { h }
	if not bare then
		-- The arms: along the foot (or the top) beyond the square, and along the side beyond it.
		local across = (top and "TOP" or "BOTTOM") .. (right and "LEFT" or "RIGHT")
		local along = (top and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT")
		h.foot = CreateFrame("Frame", nil, h)
		h.foot:SetSize(ARM, DEPTH + OUT)
		h.foot:SetPoint(point, h, across)
		h.side = CreateFrame("Frame", nil, h)
		h.side:SetSize(DEPTH + OUT, ARM)
		h.side:SetPoint(point, h, along)
		parts[2], parts[3] = h.foot, h.side
	end
	Mouse(h, parts)
	return h
end

-- How far a corner's hold runs along the top or the foot (`across`), or up the side: its square and its arm.
local function Reach(corner, across)
	return corner.core + (across and corner.armX or corner.armY)
end

-- How far past its piece's edge a side takes the mouse: a hair, unless the piece says (opts.past: one with
-- nothing of its own to click beside it, held more easily).
local function Past(h)
	return h.opts and h.opts.past or PAST
end

-- A side's handle: the border itself between the corners' holds (BORDER in, PAST out, no more), and
-- that stretch of border lit under the mouse. `g` is the piece's grip, whose corners it runs between.
local function Edge(parent, point, g)
	local h = CreateFrame("Frame", nil, parent)
	h.point, h.edge = point, true
	h.level, h.target, h.flash = 0, 0, 0
	h.art = CreateFrame("Frame", nil, h)
	h.art:SetAllPoints()
	h.art:SetAlpha(0)
	-- The light lies on the border, from the piece's edge inward and as wide as the border. It runs the
	-- whole side, corner to corner, though the side takes the mouse only between the corners' holds.
	local line = h.art:CreateTexture(nil, "OVERLAY")
	Theme.Paint(line, Theme.AccentSolid)
	h.line = line
	local function Lay(region, from, to)
		line:ClearAllPoints()
		line:SetPoint(from, region, from)
		line:SetPoint(to, region, to)
	end
	if point == "LEFT" then
		line:SetWidth(BORDER)
		h.place = function(self, region)
			self:SetPoint("TOPLEFT", region, "TOPLEFT", -Past(self), -Reach(g.at.TOPLEFT))
			self:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", BORDER, Reach(g.at.BOTTOMLEFT))
			Lay(region, "TOPLEFT", "BOTTOMLEFT")
		end
	elseif point == "RIGHT" then
		line:SetWidth(BORDER)
		h.place = function(self, region)
			self:SetPoint("TOPLEFT", region, "TOPRIGHT", -BORDER, -Reach(g.at.TOPRIGHT))
			self:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", Past(self), Reach(g.at.BOTTOMRIGHT))
			Lay(region, "TOPRIGHT", "BOTTOMRIGHT")
		end
	elseif point == "TOP" then
		line:SetHeight(BORDER)
		h.place = function(self, region)
			self:SetPoint("TOPLEFT", region, "TOPLEFT", Reach(g.at.TOPLEFT, true), Past(self))
			self:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", -Reach(g.at.TOPRIGHT, true), -BORDER)
			Lay(region, "TOPLEFT", "TOPRIGHT")
		end
	else
		line:SetHeight(BORDER)
		h.place = function(self, region)
			self:SetPoint("TOPLEFT", region, "BOTTOMLEFT", Reach(g.at.BOTTOMLEFT, true), BORDER)
			self:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -Reach(g.at.BOTTOMRIGHT, true), -Past(self))
			Lay(region, "BOTTOMLEFT", "BOTTOMRIGHT")
		end
	end
	Mouse(h, { h })
	return h
end

-- The rest of a piece's hold: its other two corners, its sides, and the small corner where the top and
-- the right side meet.
-- A game frame's are children of the screen that follow it by looking (or of the frame itself: `into`);
-- a box of ours wears its own (`on`: the frame they stand on, `core`: its corners' square; `slim`: the
-- other corners small and bare as the top right one is, for a piece that keeps its inside to itself).
-- `corners`: "slim", those two small and bare; "foot", the top one alone (a piece that keeps its tools in its
-- header and is held by its foot); else both as its first.
local function Around(g, on, core, corners, into)
	local parent = on or into or UIParent
	local function Add(h)
		g.all[#g.all + 1] = h
		g.at[h.point] = h
		if on then
			h.on = on
		else
			h:Hide()   -- until its piece is seen
		end
	end
	local slim = corners == "slim"
	local bare = slim or corners == "foot"
	Add(Corner(parent, "BOTTOMLEFT", slim and SMALL or core or CORE, slim))
	Add(Corner(parent, "TOPLEFT", bare and SMALL or core or CORE, bare))
	Add(Corner(parent, "TOPRIGHT", SMALL, true))
	for _, point in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do Add(Edge(parent, point, g)) end
end

-- A box of ours can be small, and change its size: an arm is no longer than its side can spare between
-- the two corners, and a side is there only where they leave some of it.
function Fit(g)
	local on = g.on
	if not on or not g.at.LEFT or (g.box and g.box.folded) then return end
	local width, height = on:GetWidth(), on:GetHeight()
	for point, ends in pairs(ENDS) do
		local across = point == "TOP" or point == "BOTTOM"
		local arms, free = 0, across and width or height
		for _, name in ipairs(ends) do
			local corner = g.at[name]
			free = free - corner.core
			if not corner.bare then arms = arms + 1 end
		end
		local arm = arms > 0 and max(0, math.min(ARM, floor(free / arms))) or 0
		for _, name in ipairs(ends) do
			local corner = g.at[name]
			if not corner.bare then
				if across then
					corner.armX = arm
					corner.foot:SetWidth(max(arm, 1))
					corner.foot:SetShown(arm > 0)
				else
					corner.armY = arm
					corner.side:SetHeight(max(arm, 1))
					corner.side:SetShown(arm > 0)
				end
			end
		end
		-- A side hangs from the piece's corners and follows its size by itself: laid again only when an
		-- arm at its end changed (a box that is reshaped every frame comes through here every frame).
		local side = g.at[point]
		local none = free - arms * arm < MIN_SIDE
		if side.fit ~= arm or side.none ~= none or side.region ~= on then
			side.fit, side.none, side.region = arm, none, on
			side:ClearAllPoints()
			side.place(side, on)
			side:SetShown(not none)
		end
	end
	-- A piece may offer only some of its handles (opts.points), and not the same ones always: the rest are away.
	if g.opts and g.opts.points then
		for _, h in ipairs(g.all) do
			local shown = Offered(h) and not (h.edge and h.none)
			if h:IsShown() ~= shown then
				if not shown and over == h then Leave(h) end
				h:SetShown(shown)
			end
		end
	end
end

Shy:On("SHY_HUD_FOLDED", function(box)
	local g = byBox[box]
	if not g or box.foreign then return end
	local on = box.folded == true
	for _, h in ipairs(g.all) do
		if on and over == h then Leave(h) end
		h:SetShown(not on)
		h.fit = nil   -- laid again as it opens
	end
	if not on then Fit(g) end
end)

function HUD.Grip(box, opts)
	local g = byBox[box]
	if not opts then return g end
	local on = not box.foreign and (opts.over or box) or nil
	-- A game window's handles inside it, where it asks (one that closes when the mouse is pressed elsewhere).
	local into = box.loose and opts.inside and box.foreign or nil
	if not g then
		g = Corner(on or into or UIParent, "BOTTOMRIGHT", opts.core or CORE)
		g.all, g.at = { g }, { BOTTOMRIGHT = g }
		g.Follow = Follow
		byBox[box] = g
		grips[#grips + 1] = g
		if box.foreign then g:Hide() end   -- until its piece is seen
	end
	if box.foreign and (opts.size or box.loose) and not g.at.LEFT then Around(g, nil, nil, nil, into) end
	-- A box of ours is held all the way round too: a window, and a box that shapes itself, by corners like
	-- its first; any other piece by small bare ones, unless it says which.
	if on and not g.at.LEFT then
		Around(g, on, opts.core, opts.corners or ((box.window or opts.shape) and "full" or "slim"))
	end
	for _, h in ipairs(g.all) do h.box, h.opts = box, opts end
	if opts.menu then box.menu = opts.menu end
	if box.foreign then
		if opts.size and not box.loose then HUD.Sized(box.foreign) end
		looker:Show()
		Follow(g)
	else
		for _, h in ipairs(g.all) do
			h.on = on
			if h:GetParent() ~= on then h:SetParent(on) end
			Stand(h, on)
			Layer(h)
		end
		if g.fitted ~= on then
			g.fitted = on
			on:HookScript("OnSizeChanged", function()
				if g.on == on then Fit(g) end
			end)
		end
		Fit(g)
		-- A box that flows wears the size it kept; the one it has now is the one it was made at (a window's, its
		-- body's: the one it was made with, whatever look it has been in since).
		if opts.flow then
			local made, cw, ch = box.shyMade, Clear(box)
			g.made = g.made or (made and { made[1], made[2] }) or { box:GetWidth() - cw, box:GetHeight() - ch }
			Wear(g)
		else
			g.made = nil
		end
	end
	return g
end

-- A game window that is no piece of the screen (a window of the game's that an addon moves and keeps
-- itself: ShyTweaks' windows). Every corner and side scales it, as a window of ours. The grip only
-- sizes it; its owner keeps the place and the scale.
--   Shy.HUD.GripFrame(frame, {
--       title = "Character" | function() end,   -- what its corner calls it
--       id = "...",                             -- what its lock is kept under (unless the frame's name says)
--       size = true,                            -- the engine sizes it instead, as the game's own corner does
--                                               -- (a window the game lets the player resize), within its bounds
--       points = { "RIGHT", "BOTTOM", "BOTTOMRIGHT" } | function() end,   -- optional: only these handles
--                                               -- (a window hung from another by its other edges)
--       inside = true,                          -- its handles are its children (a window that closes when
--                                               -- the mouse is pressed anywhere but on it)
--       over = function() return region end,    -- optional: the region its handles stand on (the frame)
--       shown = function() return on end,       -- optional: no grip while false
--       held = function(frame, on) end,         -- a drag begins and ends: nothing may put it back meanwhile
--       kept = function(frame) end,             -- let go at a new size, anchored on the screen by its bottom
--                                               -- left corner: keep its place and scale (or, with `size`,
--                                               -- where the engine left it: keep its size)
--       shape = function(wider, taller, phase, point) end,   -- it shapes itself instead (a window that flows:
--                                               -- more of its inside, not a larger one): told how far the
--                                               -- handle went from where it was pressed, in its own units
--                                               -- (nil for a way that handle doesn't move), phase "start",
--                                               -- "drag" or "stop"; it sizes and keeps itself
--   })
--   Shy.HUD.ShapesItself(frame)   -- whether it does: whoever else would take hold of it to scale it leaves it be
local stand = setmetatable({}, { __mode = "k" })   -- frame -> its stand-in

function HUD.GripFrame(frame, opts)
	local box = stand[frame]
	if not box then
		-- A stand-in, as HUD.Adopt's: our fields on this table, the frame's methods forwarded.
		box = setmetatable({ id = opts.id or ("frame:" .. tostring(frame:GetName())), foreign = frame, loose = true, window = true, home = {} },
			{ __index = function(_, key)
				local value = frame[key]
				if type(value) ~= "function" then return value end
				return function(_, ...) return value(frame, ...) end
			end })
		stand[frame] = box
		HUD.Window(box)   -- what stands over the game's frames gives way under it, as under a window of ours
		-- Its handles come and go with it at once, not at the next look.
		local function Look()
			local g = byBox[box]
			if g then Follow(g) end
		end
		frame:HookScript("OnShow", Look)
		frame:HookScript("OnHide", Look)
	end
	box.title = opts.title
	box.sizes = opts.size and true or nil
	return HUD.Grip(box, opts)
end

function HUD.ShapesItself(frame)
	local box = stand[frame]
	local g = box and byBox[box]
	return g ~= nil and g.opts ~= nil and g.opts.shape ~= nil
end

-- A flowing box whose size is planned rather than fixed (a home's width, a setting's rows: ShyThreat's meter): the
-- size it is made at from now on. It wears it at once unless the player kept a size of their own, and goes back to
-- it on "Reset size" or when a setup forgets the kept one.
function HUD.Made(box, width, height)
	local g = byBox[box]
	if g and g.made then
		if abs(g.made[1] - width) < 0.5 and abs(g.made[2] - height) < 0.5 then return end
		g.made = { width, height }
		Wear(g)
		return
	end
	-- No grip yet (it is built as the box first shows, and takes the size it was made at then): the box wears the
	-- size now, unless the player kept one.
	box.shyMade = { width, height }
	if Act.HasSize(box) then return end
	HUD.WearMade(box)
end

-- A flowing box no grip has taken hold of yet: the size it was made at (box.shyMade, its body's), with its look's
-- clearance round it (UI.Body); docked `tall`, as tall as its host all the same.
function HUD.WearMade(box)
	local made = box.shyMade
	if not made then return end
	local cw, ch = Clear(box)
	HUD.Resize(box, made[1] + cw, HUD.DockTall(box) or made[2] + ch)
	local how = box.grip
	if how and type(how.flow) == "function" then how.flow(box, made[1], made[2]) end
end

-- A box that flows is put back at its kept size, or the one it was made at, whenever it is placed again
-- (a reset, another layout).
hooksecurefunc(HUD, "Apply", Shy.Clocked("grip: a box applied", function(box)
	local g = byBox[box]
	if g and g.made then Wear(g) end
end))

-- A window as tall as its host while docked (`dock.tall`), let go of away from it or freed from its menu: the
-- height of its own again at once, its top left corner where it is (else it would keep the host's until it was
-- next placed, and change then for no reason seen).
Shy:On("SHY_HUD_MOVED", function(box)
	if type(box) ~= "table" or not (box.dock and box.dock.tall) or Act.Docked(box) then return end
	local g = byBox[box]
	if not (g and g.made) then return end
	local hold = HUD.Hold(box, "BOTTOMRIGHT")
	if Wear(g) then hold(true) end
end)

-- A window's look keeps another clearance round its body (UI.Body): it wears its size again with that round it.
-- (A maximized one is laid out again by UI.Maximize's own.)
Shy:On("SHY_BODY", function(box)
	if type(box) ~= "table" or box.maxed then return end
	local g = byBox[box]
	if g and g.made then
		Wear(g)
	elseif box.shyMade and not Act.HasSize(box) then
		HUD.WearMade(box)
	end
end)

-- A locked piece was pressed to drag it: its corner shows the padlock for a moment, with a gleam.
function HUD.OnLocked(box)
	local g = byBox[box]
	if not g or not g:IsShown() or not Mode(g) then return end
	Dress(g)
	g.flash = 1
	Fade(g, 1)
	local told = {}
	g.told = told
	C_Timer.After(TELL, function()
		if g.told ~= told then return end
		g.told = nil
		Refresh(g)
	end)
end

-- Boxes of ours: the frame that wears the brackets, once it does. A look other than the forged one puts
-- them away, but the housing is still there to be held.

local function Bracketed(frame)
	local brackets = frame.shyBrackets
	if brackets == nil or brackets[4] == nil then return false end
	if brackets[4]:IsShown() then return true end
	local look = frame.shyLook
	return look ~= nil and look.look ~= nil and look.look ~= "forged"
end

local TRIES = 3   -- times a box with no brackets yet is looked at again as it shows
local soon, Soon

local function Scan()
	soon = nil
	HUD.Each(function(box)
		-- What the box was made with (`grip` in its definition): false for none, a table for how it is held.
		local how = box.grip
		if box.foreign or byBox[box] or how == false or (box.ownSize and not how) then return end
		local on = how and how.over or (Bracketed(box) and box) or nil
		for _, frame in ipairs(handles[box] or {}) do
			if not on and Bracketed(frame) then on = frame end
		end
		-- A box that says how it is held needs no brackets to be found by.
		if how and not on then on = box end
		if on then
			local opts = how or {}
			opts.over = on
			HUD.Grip(box, opts)
		elseif not waiting[box] then
			-- A panel built as the box first shows.
			waiting[box] = 0
			box:HookScript("OnShow", function(self)
				if byBox[self] or waiting[self] >= TRIES then return end
				waiting[self] = waiting[self] + 1
				Soon()
			end)
		end
	end)
end

function Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, Scan)
end

hooksecurefunc(HUD, "Create", Soon)
hooksecurefunc(HUD, "Manage", function(box, frame)
	if box.foreign or not frame or frame == box then return end
	handles[box] = handles[box] or {}
	table.insert(handles[box], frame)
	Soon()
end)

Shy:On("SHY_LOGIN", Soon)
Shy:On("SHY_HUD_LAYOUT", function()
	if drag then Release() end
	Everywhere()
end)
EventRegistry:RegisterCallback("EditMode.Enter", Everywhere, grips)
EventRegistry:RegisterCallback("EditMode.Exit", Everywhere, grips)

-- /shy grip: what the mouse is on and how every grip stands, to copy when a corner doesn't answer.
local function Named(frame)
	if not frame then return "nothing" end
	if frame:IsForbidden() then return "a forbidden frame" end
	return ("%s (%s %d)"):format(frame:GetDebugName() or "?", tostring(frame:GetFrameStrata()), frame:GetFrameLevel())
end

local function Whole(value)
	if type(value) ~= "number" or issecretvalue(value) then return "?" end
	return tostring(floor(value + 0.5))
end

function HUD.GripReport()
	local lines, under = {}, {}
	for _, frame in ipairs(GetMouseFoci()) do under[#under + 1] = Named(frame) end
	lines[1] = "under the mouse: " .. (#under > 0 and table.concat(under, ", ") or "the world")
	lines[2] = ("the corner takes the mouse %d in and %d out, its arms %d further and %d deep; a side its border, %d in and %d out; layout mode %s")
		:format(CORE, OUT, ARM, DEPTH, BORDER, PAST, HUD.IsUnlocked() and "open" or "closed")
	for _, g in ipairs(grips) do
		local box = g.box
		local piece = box.foreign or g.on
		lines[#lines + 1] = ("%s: %s%s, %s, grip %s %s, at %s %s, %s by %s at scale %.2f; piece %s"):format(
			tostring(box.id), Mode(g) or "off", Act.IsLocked(box) and " locked" or "",
			g:IsVisible() and "on screen" or (g:IsShown() and "shown, its parent hidden" or "hidden"),
			tostring(g:GetFrameStrata()), Whole(g:GetFrameLevel()), Whole(g:GetLeft()), Whole(g:GetBottom()),
			Whole(g:GetWidth()), Whole(g:GetHeight()), g:GetEffectiveScale(), Named(piece))
		-- The rest of a sized piece's hold, each with the layer it stands on.
		for i = 2, #g.all do
			local h = g.all[i]
			lines[#lines + 1] = ("   %s: %s, %s %s, at %s %s, %s by %s"):format(h.point,
				h:IsShown() and "shown" or "hidden", tostring(h:GetFrameStrata()), Whole(h:GetFrameLevel()),
				Whole(h:GetLeft()), Whole(h:GetBottom()), Whole(h:GetWidth()), Whole(h:GetHeight()))
		end
	end
	if #grips == 0 then lines[#lines + 1] = "no piece has a grip yet" end
	lines[#lines + 1] = ("cursor: %s; the game's put out of sight: %s; cursor size setting %s; arrow %s wide"):format(
		arrow:IsShown() and ("drawn for " .. tostring(arrow.point)) or "the game's own", BLANK .. " " .. tostring(arrow.hid),
		tostring(C_CVar.GetCVar("cursorSizePreferred")), Whole(arrow.tex:GetWidth()))
	return table.concat(lines, "\n")
end

-- A change of look repaints accent strokes; handles not under the mouse must stay dark (Repaint can leave
-- edge lines lit at full color while h.art still thinks it faded out, or the reverse).
Shy:On("SHY_THEME", function()
	for _, g in ipairs(grips) do
		for _, h in ipairs(g.all) do
			if Lit(h) then
				Dress(h)
				Refresh(h)
			else
				h.target, h.level = 0, 0
				h.art:SetAlpha(0)
				h:SetScript("OnUpdate", nil)
			end
		end
	end
end)

-- (For finding faults: what the corner grips are doing. Not listed.)
Shy.Command("grip", nil, function()
	UI.ShowCopyBox("Corner grips", HUD.GripReport())
end)
