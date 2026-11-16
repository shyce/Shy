-- Shy.Hover: the tooltip every addon uses for its own content (GameTooltip is left for what the game describes).
--
-- A hover is a cut-corner housing with a soft shadow and the accent as light in its top edge. Docked
-- (opts.dock) it opens from that frame's edge and stays put while the mouse moves between rows;
-- otherwise it is placed beside its owner. Its height follows its content. The foot (lines not needed at a
-- glance) slides down after the mouse has rested (the Hover delay setting in the /shy window, a second by
-- default; everything that waits for a rest waits a share of it). A click on a hover that asks for it
-- (opts.keep = true) keeps it up, while Hover.pinning is on (it is off); another closes it. What the mouse does is never said: clicking, pinning and the menus are plain to anyone using
-- the UI, so `hints` are taken and not shown, and a hover with nothing more to say has no foot.
--
--   Shy.Hover.Show(owner, content, opts)   -- returns the frame
--   Shy.Hover.Rest(share)          -- seconds of rest before a hover shows more, or that share of it
--   Shy.Hover.Hide(owner)          -- after a short grace, and not while the mouse is on the hover
--   Shy.Hover.Owner()              -- current owner, or nil
--   Shy.Hover.Away()               -- the hover was closed because the mouse left the game's window, and hasn't moved since
--   Shy.Hover.Close(frame)         -- at once (no frame: the one under the mouse)
--   Shy.Hover.Refill(frame, content)   -- new content for a kept hover (nil closes it)
--   Shy.Hover.Keep(owner)          -- keep the current hover of `owner` up, as a click on it does
--   Shy.Hover.Kept()               -- the kept hover, if any (.key is what it is about)
--   Shy.Hover.Each(fn)             -- fn(frame) for every hover frame made, shown or not
--   Shy.Hover.Restack()            -- after a menu opens or closes: the hovers it doesn't own go under it, or back
--
--   content = {
--     strip = "Guide step",  note = "1-8 TELDRASSIL",     -- header, and text at the header's right
--     title = "Webwood Spider",                           -- without one there is no head
--     sub = "Step 12 of 56",  subHot = true,              -- under the title: dim capitals, or (subHot) accent light
--     seat = { key =, set = function(seat) end },         -- the caller's own mark before the title: see "Seats"
--     dial = { yards = number | function, turn = function() return radians end },
--                                   -- turn: counter-clockwise rotation of an up arrow to point at the thing, or nil
--                                   -- arrow = file, says = function() return "38 yd" end: the dial as ShyQuest's
--                                   -- window draws it, that arrow turning in the ring and the distance in words
--                                   -- at the title's right
--                                   -- seated = true: the ring alone, with `seat` standing in it
--     text = "A sentence or two.",
--     textColor = { r, g, b },
--     sections = { {
--       title = "To do",
--       rows = { { glyph = "kill", text = "Kill Webwood Spiders", right = "0/10", count = { 0, 10 } }, ... },
--       story = "Words that may run long",   -- in place of rows: shown up to CARD.story tall (or most = px),
--                                            -- then they scroll there (wheel, accent thumb, shades); at = 0..1
--                                            -- opens them scrolled to that share of the way down (a match)
--       words = "Webwood Spider", more = "Teldrassil, to the north",   -- under the rows
--       bar = { have = 0.9, gain = 0.07 },
--     }, ... },
--   }
--   A row starts with one of: glyph (a name from Hover.GLYPHS, or "check"), icon (a texture, shown in a Shy.Slot),
--   seat, or nothing. Also: lit = true (current), done = true (ticked, dim), quiet = true, indent = 1,
--   tint (glyph color), color (text color), rightColor, count = { have, need } (pips, up to 12),
--   wrap = false (one line, truncated), name = true (its words are a name: one too long for its line keeps
--   its last word and the initials of the rest, UI.ShortName, and stays on one line).
--
--   opts = { dock = frame, side = "LEFT" | "RIGHT" | "TOP" | "BOTTOM" (default: where there is room)
--            | "CURSOR" (goes with the cursor, on whichever side of it has room),
--            outside = frame (placed beside that frame, never over it: what the mouse points into, a minimap),
--            gap = 5, width = 262, keep = true (a click keeps it up; otherwise it can't be),
--            keep = false (nor does it take the mouse: no lingering on it, no scrolling it),
--            key = anything (a kept hover with the same key is not shown twice),
--            onKeep = function(frame, kept) end,
--            at = { point, frame, relativePoint, x, y } (explicit position), scale = 1 }
--
--   Meaning colors:
--     titleColor = { r, g, b }
--     light = { r, g, b }, pulse = 2   -- top light in this color, pulsing once per that many seconds
--     edge = { r, g, b }               -- the housing's edge in this color (an item's quality)
--     wash = { r, g, b, 0.15 }         -- a color over the background
--     bar = { have =, color = }        -- with gain = (what would follow it, in gold) and more =, moreColor =
--                                      -- (what could follow that, in a color of the caller's): shares of the bar
--     bar = { live = function() return value end, color = }   -- 0 to 1, called every frame and passed straight
--                                      -- to a StatusBar, so it may be a secret number (health)
--
--   Shy.Hover.Beside(n, content, opts)   -- a second hover beside the current one (n = 1 or 2): comparisons.
--                                        -- opts.width, opts.count, opts.of = a Stay frame. nil content closes it
--   Shy.Hover.Frame(n)                   -- the current hover's frame (n: the n-th beside it)
--   Shy.Hover.Stay(id, content, opts)    -- stays at opts.at until closed (nil content); opts.onClose adds an x.
--                                        -- It holds its place: a hover placed beside its owner whose spot
--                                        -- it covers slots in under it (over it, with no room under)
--   Shy.Hover.Staying(id)                -- that frame
--
--   Every hover is drawn as the card (see "The card"); the content above is said in it (Said): the strip
--   and note are the quiet word at the head's right, sub the line under the title, a dial's way the arrow
--   and distance there, each section its heading, rows, words and bar. With no title the strip is the name.
--   content.card = true     card content as it is drawn: see "The card"
--   content.plate = { }     a unit: level ring, name plaque that is the health bar, drop-down card: see "The plate"
--
--   Shy.Hover.Tip(owner, title, text, opts)     -- a title and a sentence; opts.hints, opts.side, opts.at, opts.sections
--   Shy.Hover.Attach(frame, title, text, opts)  -- the same on enter / leave; title and text may be functions
--   (Addons call these as Shy.UI.Tip / Shy.UI.TipHide / Shy.UI.Help.)
--
--   local lines = Shy.Hover.Lines()             -- GameTooltip-style building:
--   lines:AddLine(text, r, g, b, wrap)          --    first line is the title; a line of one space starts a section,
--                                               --    and Shy.Hover.Heading(text) after it is that section's heading
--   lines:AddDoubleLine(left, right, r, g, b, r2, g2, b2)   -- three leading spaces indent a line;
--                                               --    a count in a line ("Wolf Meat: 3/8") is drawn as pips (Hover.Tally)
--   Shy.Hover.ShowLines(owner, lines, opts)     -- opts.strip, opts.hints
--
--   Seats: seat.set(frame) is given a square frame, cached by seat.key and size, and is called on every fill;
--   keep what it creates on the frame and reuse it.
--
--   Shy.Hover.Glyph(texture, name, size)   -- one of Hover.GLYPHS on the caller's texture; size (units) picks
--                                            -- the drawing made for it: SMALL_GLYPH and under, the small one;
--                                            -- LARGE_GLYPH and over, the large one

local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors

local Hover = {}
Shy.Hover = Hover

-- Pinning (a click keeping a hover up) is off for now: hovers that ask for it (keep = true) still say
-- so, and turn it back on with this.
Hover.pinning = false

-- Cells of HoverGlyphs.tga, eight across, in sheet order.
Hover.GLYPHS = { "kill", "loot", "talk", "go", "book", "bag", "up", "use", "fly", "home", "left", "right", "coin", "star", "clock", "note" }
local CELL = {}
for index, name in ipairs(Hover.GLYPHS) do CELL[name] = index - 1 end

local MEDIA = Shy.MEDIA
local WIDTH, TIP_WIDTH = 262, 224   -- the widest a hover with a title and one without may grow
local WAY = 18               -- a card's arrow, the size ShyQuest's card draws its own
local PICTURE = 224          -- the width a card with a picture asks for
local PIPS, PIP_W, PIP_H = 12, 4, 8
local BAR = 9                -- bar height: a rim around five units of hatch
local FOOT_IN = 10           -- left inset of the foot's content
local SLIDE = 0.16           -- seconds the foot's slide takes
-- Seconds of rest before the foot slides down (and the blocks marked more with it): the Hover delay setting,
-- read as it is needed so a change applies at once. With `share`, that part of it.
function Hover.Rest(share) return Shy.core.db.rest * (share or 1) end
local LIGHT = 12             -- height of the top light; its second row sits on the rim
local GAP = 5                -- default distance from the owner when not docked
local FADE = 0.08            -- fade-in seconds
local GRACE = 0.08           -- seconds a hover outlives its owner, so the mouse can reach the next row or the hover
local DRAG_START = 6         -- screen pixels a press must move to become a drag of the hover
local ICE = { 0.47, 0.84, 1.00 }
local WHITE = { 1, 1, 1 }

-- Each picture is drawn three times, two texels a unit: for 12 units (24px cells), for 16 (32px) and for
-- 24 (48px: the sign in the head's circle). The game keeps no smaller copies of our art, so one shown well
-- under its size loses strokes, and one shown well over it softens.
local SMALL_GLYPH, LARGE_GLYPH = 13, 20

function Hover.Glyph(texture, name, size)
	local small = size and size <= SMALL_GLYPH
	local large = size and size >= LARGE_GLYPH
	if name == "check" then
		texture:SetTexture(MEDIA .. (small and "GlyphCheckS" or "GlyphCheck"))
		texture:SetTexCoord(0, 1, 0, 1)
		return
	end
	local cell = CELL[name] or CELL.note
	local col, row = cell % 8, math.floor(cell / 8)
	texture:SetTexture(MEDIA .. (small and "HoverGlyphsSmall" or large and "HoverGlyphsLarge" or "HoverGlyphs"))
	texture:SetTexCoord(col / 8, (col + 1) / 8, row / 2, (row + 1) / 2)
end

-- The same glyph written into a line of text, in a color. At the head of a hover's line it leads the
-- row (Hover.Lead); on the game's own tooltip it stands before the words.
function Hover.GlyphText(name, color, size)
	local cell = CELL[name] or CELL.note
	local col, row = cell % 8, math.floor(cell / 8)
	size = size or 12
	local px = size <= SMALL_GLYPH and 24 or 32
	return ("|T%s%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(MEDIA, px == 24 and "HoverGlyphsSmall" or "HoverGlyphs",
		size, size, px * 8, px * 2, col * px, (col + 1) * px, row * px, (row + 1) * px,
		math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

-- A count written into a row's words ("Tough Wolf Meat: 3/8", "3/8 Tough Wolf Meat") or standing alone
-- at its right ("3/8") becomes the row's count: pips, the numbers at the right, the name alone as its
-- words. What stood at the right before (a drop chance) follows the name.
function Hover.Tally(row)
	local text, right = row.text or "", row.right
	local name, have, need
	if right and right ~= "" then have, need = right:match("^(%d+)/(%d+)$") end
	local moved = not have
	if moved then
		name, have, need = text:match("^(.-)%s*:%s*(%d+)/(%d+)$")
		if not name then have, need, name = text:match("^(%d+)/(%d+)%s+(.+)$") end
	end
	have, need = tonumber(have), tonumber(need)
	if not need or need <= 0 or name == "" then return row end
	if moved then
		if right and right ~= "" then name = name .. "  " .. UI.Wrap(row.rightColor or C.dim, right) end
		row.text, row.rightColor = name, nil
	end
	row.right, row.count = have .. "/" .. need, { have, need }
	return row
end

-- Upper-cases a to z only: string.upper works on bytes and breaks UTF-8 names. Text with escape
-- codes is left alone.
local function Caps(text)
	if text:find("|", 1, true) then return text end
	return (text:gsub("[a-z]+", string.upper))
end

-- The current hover, the kept one, and a spare frame for reuse.
local wing, kept, spare
local owner, generation = nil, 0
local beside = {}            -- Hover.Beside frames
local built = {}             -- every hover frame made, for Hover.Each

-- The mouse gone from the game's window
-- Leaving the window, the mouse fires no OnLeave for what it was on: the game keeps the cursor where
-- it last saw it, so a hover raised on the way out would stay up. A cursor resting on a thing by the
-- screen's edge stands just as still, so the two are told apart by how the cursor stopped: a mouse
-- that left was cut off in its stride, and another step like its last would have taken it off the
-- screen; one that came to rest slowed down first. A hover under the mouse (not a kept one) is closed
-- once a cursor that stopped that way has stood still for OUT_REST seconds, and comes back if the
-- mouse then moves on the same thing, which as the game sees it was never left.
local OUT_REST = 0.5         -- seconds
local OUT_REACH = 2          -- steps like its last the cursor is carried on: a mouse may be speeding up as it leaves
local OUT_RIM = 2            -- screen pixels from the edge that count as off it
local mouse = { still = 0, stepX = 0, stepY = 0 }   -- the cursor: x, y, its last step, seconds at rest
local away                   -- while the mouse is taken to be gone: by, content, opts, at bring the closed hover back

-- Every frame, hover or none: the hover of a mouse on its way out is raised after its last step.
local cursor = CreateFrame("Frame")
cursor:SetScript("OnUpdate", Shy.Clocked("hover: the cursor", function(_, elapsed)
	local x, y = GetCursorPosition()
	if x == mouse.x and y == mouse.y then
		mouse.still = mouse.still + elapsed
		return
	end
	if mouse.x then mouse.stepX, mouse.stepY = x - mouse.x, y - mouse.y end
	mouse.x, mouse.y, mouse.still = x, y, 0
	local back = away
	away = nil
	-- The mouse moved and nothing was shown meanwhile: still on the thing, its hover is up again.
	if back and back.at == generation and back.by:IsVisible() and back.by:IsMouseOver() then Hover.Show(back.by, back.content, back.opts) end
end))

-- The cursor stopped as a mouse that left the window does.
local function Left()
	if not mouse.x or mouse.still < OUT_REST then return false end
	local scale = UIParent:GetEffectiveScale()
	local wide, tall = (UIParent:GetWidth() or 0) * scale, (UIParent:GetHeight() or 0) * scale
	if wide <= 0 then return false end
	local x, y = mouse.x + OUT_REACH * mouse.stepX, mouse.y + OUT_REACH * mouse.stepY
	return x <= OUT_RIM or y <= OUT_RIM or x >= wide - OUT_RIM or y >= tall - OUT_RIM
end

-- True when hover f was closed for it.
local function Gone(f)
	if not Left() then return false end
	local by, content, opts = f.owner, f.content, f.opts
	Hover.Close(f)
	away = { by = by, content = content, opts = opts, at = generation }
	return true
end

-- The mouse is taken to have left the game's window: true from a hover closed for it until the mouse next moves.
function Hover.Away()
	return away ~= nil
end

-- Pieces

-- One frame per seat key and size on each holder.
local function Seat(holder, seat, size, point, to, toPoint, x, y)
	for _, frame in pairs(holder.seats) do frame:Hide() end
	if not seat then return nil end
	local key = seat.key .. ":" .. size
	local frame = holder.seats[key]
	if not frame then
		frame = CreateFrame("Frame", nil, holder)
		holder.seats[key] = frame
	end
	frame:SetSize(size, size)
	frame:ClearAllPoints()
	frame:SetPoint(point, to, toPoint, x, y)
	frame:Show()
	seat.set(frame)
	return frame
end

-- A picture written at the head of a line of text (an inline texture or atlas) is drawn as the row's
-- lead instead: at a lead's place and size, and whole where its addon gave a seat for it.
--   Shy.Hover.Mark(prefix, seat)   lines starting with `prefix` are led by `seat`
local leads = {}

function Hover.Mark(prefix, seat)
	leads[prefix] = seat
end

-- A heading over the lines an addon adds to the game's tooltip (after a blank line): a card that shows the tooltip
-- draws it as a section's heading over those lines, and lines built with Hover.Lines take it the same way.
--   tip:AddLine(Shy.Hover.Heading("You also have"), r, g, b)   -- returns the words
--   Shy.Hover.Headed(text)                                     -- a line written so
local headings = {}

function Hover.Heading(text)
	headings[text] = true
	return text
end

function Hover.Headed(text)
	return headings[text] == true
end

-- A seat that draws an inline picture as it was written. A size above a lead's own is kept (seat.lead).
local function Inline(code, size, set)
	size = tonumber(size) or 0
	return { key = "hover-inline", sig = code, lead = size > 12 and math.min(size, 16) or nil, set = function(seat)
		if not seat.picture then
			seat.picture = seat:CreateTexture(nil, "ARTWORK")
			seat.picture:SetAllPoints()
		end
		set(seat.picture)
	end }
end

-- The lead for a line that starts with a picture, and the line without it. nil when it starts with none.
function Hover.Lead(text)
	for prefix, seat in pairs(leads) do
		if text:sub(1, #prefix) == prefix then return seat, text:sub(#prefix + 1) end
	end
	local code, rest = text:match("^(|T.-|t) ?(.+)$")
	local atlas = not code
	if atlas then code, rest = text:match("^(|A.-|a) ?(.+)$") end
	if not code then return nil end
	local f = {}
	for part in (code:sub(3, -3) .. ":"):gmatch("(.-):") do f[#f + 1] = part end
	if atlas then
		-- "|A:atlas:height:width|a"
		return Inline(code, f[3], function(picture)
			picture:SetAtlas(f[2])
			picture:SetVertexColor(1, 1, 1)
		end), rest
	end
	-- "|Tfile:height:width:x:y:sheetWidth:sheetHeight:left:right:top:bottom:r:g:b|t"
	local n = {}
	for i = 6, 14 do n[i] = tonumber(f[i]) end
	return Inline(code, f[2], function(picture)
		picture:SetTexture(tonumber(f[1]) or f[1])
		if n[6] and n[7] and n[8] and n[9] and n[10] and n[11] then
			picture:SetTexCoord(n[8] / n[6], n[9] / n[6], n[10] / n[7], n[11] / n[7])
		else
			picture:SetTexCoord(0, 1, 0, 1)
		end
		if n[12] and n[13] and n[14] then picture:SetVertexColor(n[12] / 255, n[13] / 255, n[14] / 255) else picture:SetVertexColor(1, 1, 1) end
	end), rest
end

-- Content is often player or quest text in any alphabet, so font families are used, never one file.
local function Words(parent, size, color, named)
	return UI.Words(parent, named and UI.TitleFont(size) or UI.TextFont(size), color)
end

local function Sliced(owner, layer, sublevel, file, side, top, foot)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(MEDIA .. file)
	t:SetTextureSliceMargins(side, top or side, side, foot or side)
	return t
end

local function NewBar(parent)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(BAR)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	UI.Paint(bar.bg, C.bg)
	bar.have = bar:CreateTexture(nil, "ARTWORK")
	Shy.Skin.Hatch(bar.have)
	bar.have:SetPoint("TOPLEFT", 2, -2)
	bar.have:SetPoint("BOTTOMLEFT", 2, 2)
	bar.gain = bar:CreateTexture(nil, "ARTWORK")
	Shy.Skin.Hatch(bar.gain)
	bar.gain:SetPoint("TOPLEFT", bar.have, "TOPRIGHT")
	bar.gain:SetPoint("BOTTOMLEFT", bar.have, "BOTTOMRIGHT")
	bar.more = bar:CreateTexture(nil, "ARTWORK")
	Shy.Skin.Hatch(bar.more)
	bar.more:SetPoint("TOPLEFT", bar.gain, "TOPRIGHT")
	bar.more:SetPoint("BOTTOMLEFT", bar.gain, "BOTTOMRIGHT")
	bar.more:Hide()
	UI.Tint(bar.have, C.fill)
	UI.Tint(bar.gain, C.alert)
	bar.rim = Sliced(bar, "OVERLAY", 0, "HoverRim", 4)
	bar.rim:SetAllPoints()
	bar:SetScript("OnUpdate", function(self)
		if self.live then self.status:SetValue(self.live()) end
	end)
	return bar
end

-- bar.live: a StatusBar fed the caller's value untouched, so the value may be secret (unit health).
local function Live(bar, live, color)
	if not bar.status then
		local status = CreateFrame("StatusBar", nil, bar)
		status:SetPoint("TOPLEFT", 2, -2)
		status:SetPoint("BOTTOMRIGHT", -2, 2)
		Shy.Skin.HatchBar(status)
		status:SetMinMaxValues(0, 1)
		bar.status = status
	end
	bar.live = live
	bar.status:SetShown(live ~= nil)
	bar.have:SetShown(live == nil)
	if not live then return end
	bar.gain:Hide()
	bar.more:Hide()
	UI.Tint(bar.status:GetStatusBarTexture(), color or C.fill)
	bar.status:SetValue(live())
end

-- The hover frame

local Keep                   -- defined below
local CardTick               -- defined below
local AtCursor               -- defined below

-- Height: content (f.tall) plus the part of the foot that has slid down (f.footNow of f.footTall).
local function Stand(f)
	local down = math.min(f.footNow or 0, f.footTall or 0)
	f.foot:SetShown(down > 0)
	f.foot:SetHeight(math.max(1, down))
	f:SetHeight((f.tall or 1) + down)
end

local PLATE   -- (a unit's plate's measures and the housing's: set where the plate is made, below)

local function Build()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetClampedToScreen(true)
	f:Hide()
	f.seats = {}
	built[#built + 1] = f

	-- The housing: the look's mini border (its own smaller, simpler make of the look's frame, `mini`), at the hovers'
	-- strength, dressed again whenever the look changes; a meaning's wash over its face and the accent as light in its
	-- top edge. No brackets, and the foot is part of the housing, not a separate piece.
	-- It stands PLATE.house past the hover's own rect all round, in every look, so its frame keeps clear of the words
	-- (the forged make's edge too, in the hovers' own cut-corner art).
	local grow = { -PLATE.house, -PLATE.house, -PLATE.house, -PLATE.house }
	UI.Panel(f, { hud = true, mini = true, brackets = false, line = false, fill = C.tip, looks = { to = f, inset = grow, fill = grow } })
	f.shyEdge:SetTexture(MEDIA .. "HoverEdge")
	f.shyEdge:SetTextureSliceMargins(8, 8, 8, 8)
	f.shyEdge:ClearAllPoints()
	f.shyEdge:SetPoint("TOPLEFT", -PLATE.house, PLATE.house)
	f.shyEdge:SetPoint("BOTTOMRIGHT", PLATE.house, -PLATE.house)
	f.wash = f:CreateTexture(nil, "BACKGROUND", nil, -3)
	f.wash:SetPoint("TOPLEFT", 2, -2)
	f.wash:SetPoint("BOTTOMRIGHT", -2, 2)
	f.wash:Hide()
	f.light = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.light:SetTexture(MEDIA .. "HoverLight")
	f.light:SetPoint("TOPLEFT", 4, 0)
	f.light:SetPoint("TOPRIGHT", -4, 0)
	f.light:SetHeight(LIGHT)

	-- The foot holds the extra lines. It is hidden at first and slides down after REST seconds, the
	-- housing growing by it. `foot` is a clipping window as tall as has slid down so far; `foot.all`
	-- is the full content, anchored to the window's bottom so it emerges from under the body.
	local foot = CreateFrame("Frame", nil, f)
	foot:SetPoint("BOTTOMLEFT", 2, 2)
	foot:SetPoint("BOTTOMRIGHT", -2, 2)
	foot:SetClipsChildren(true)
	foot:Hide()
	local all = CreateFrame("Frame", nil, foot)
	all:SetPoint("BOTTOMLEFT")
	all:SetPoint("BOTTOMRIGHT")
	foot.all = all
	foot.floor = all:CreateTexture(nil, "BACKGROUND")
	foot.floor:SetAllPoints()
	foot.floor:SetColorTexture(0, 0, 0, 0.30)
	foot.groove = all:CreateTexture(nil, "BORDER")
	foot.groove:SetHeight(1)
	foot.groove:SetPoint("TOPLEFT")
	foot.groove:SetPoint("TOPRIGHT")
	foot.groove:SetColorTexture(0, 0, 0, 0.85)
	foot.lip = all:CreateTexture(nil, "BORDER")
	foot.lip:SetHeight(1)
	foot.lip:SetPoint("TOPLEFT", 0, -1)
	foot.lip:SetPoint("TOPRIGHT", 0, -1)
	foot.lip:SetColorTexture(1, 1, 1, 0.07)
	foot.lines = {}              -- content.extras, made as needed
	f.foot = foot

	-- A click keeps the hover, or lets a kept one go. A press that moves is a drag: the hover is kept
	-- and stays where it is dropped (f.placed) until it is let go.
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or not self.pins then return end
		self.pressX, self.pressY = GetCursorPosition()
		self.dragging = false
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" then return end
		local dragged = self.dragging
		self.pressX, self.dragging = nil, false
		if not dragged then
			Keep(self)
			return
		end
		self:StopMovingOrSizing()
		-- Hung from its top left corner, so it grows downward from where it was put.
		local left, top = self:GetLeft(), self:GetTop()
		if left and top then
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
	end)

	f:SetScript("OnUpdate", Shy.Clocked("hover: a hover up (with a card's way)", function(self, elapsed)
		if self.rising then
			self.rising = self.rising + elapsed
			self:SetAlpha(math.min(1, self.rising / FADE))
			if self.rising >= FADE then self.rising = nil end
		end
		if self.pressX and not self.dragging then
			local x, y = GetCursorPosition()
			if math.abs(x - self.pressX) + math.abs(y - self.pressY) > DRAG_START then
				self.dragging = true
				if not self.kept then Keep(self) end
				self.placed, self.under = true, nil
				self:StartMoving()
			end
		end
		-- An owner hidden under the mouse fires no OnLeave, so close when it stops being visible.
		if not self.kept and self.owner and not self.owner:IsVisible() then
			Hover.Close(self)
			return
		end
		-- Nor does the mouse leaving the game's window.
		if self == wing and not self.kept and self.owner and Gone(self) then return end
		if self.side == "CURSOR" and not (self.kept or self.placed) then AtCursor(self) end
		local beat = self.content and self.content.pulse
		if beat then self.light:SetAlpha(0.6 + 0.4 * math.cos(GetTime() % beat / beat * 2 * math.pi)) end
		if self.said and (self.opened or 1) < 1 then CardTick(self, elapsed) end
		-- The owner was left with the mouse on the hover: close once the mouse leaves the hover too.
		if self.lingering and not self.kept then
			local held = self:IsMouseOver() or (self.owner and self.owner:IsVisible() and self.owner:IsMouseOver())
			self.away = held and 0 or (self.away or 0) + elapsed
			if self.away > GRACE then
				Hover.Close(self)
				return
			end
		end
		-- The foot slides down after the rest; a kept hover shows it at once.
		local want = self.footTall or 0
		if not self.kept then
			self.rest = (self.rest or 0) + elapsed
			if self.rest < Hover.Rest() then want = 0 end
		end
		local down = self.footNow or 0
		if down < want then
			self.footNow = math.min(want, down + want * elapsed / SLIDE)
			Stand(self)
		end
		-- A card's way: the arrow every frame, the distance five times a second.
		local way = self.said and self.said.title and self.said.way
		if way and self.card then
			local turn = way.turn and way.turn()
			self.card.way:SetShown(turn ~= nil and way.arrow ~= nil)
			if turn then self.card.way:SetRotation(turn) end
			self.wayClock = (self.wayClock or 0) + elapsed
			if way.says and self.wayClock >= 0.2 then
				self.wayClock = 0
				self.card.word:SetText(Caps(way.says() or ""))
				self.card.word:Show()
			end
		end
	end))
	return f
end

local Card                  -- defined below (content.card)
local PlateOff               -- defined below (content.plate)

-- The foot: extra lines (content.extras, a string or { text =, color = } each). Laid out in full here; Stand
-- decides how much of it shows. (No mouse hints and no pin hint: what the mouse does is plain.)
local function Foot(f, content, width)
	local foot = f.foot
	local extras = content.extras or {}
	local left = FOOT_IN - 2       -- the foot is inside the housing's edge
	local room = width - 4 - left
	local over = 0
	for i = 1, math.max(#extras, #foot.lines) do
		local about, line = extras[i], foot.lines[i]
		if about and not line then
			line = Words(foot.all, 10, C.dim)
			line:SetJustifyV("TOP")
			line:SetWordWrap(true)
			foot.lines[i] = line
		end
		if line then line:SetShown(about ~= nil) end
		if about then
			if type(about) == "string" then about = { text = about } end
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", left, -(6 + over))
			line:SetWidth(math.max(40, room - left))
			line:SetText(about.text or "")
			UI.Ink(line, about.color or C.dim)
			over = over + math.max(11, math.ceil(line:GetStringHeight())) + 2
		end
	end
	local tall = over
	if tall > 0 then tall = tall + 9 end
	foot.all:SetHeight(math.max(1, tall))
	f.footTall = tall
	-- Already down (carried over from the previous owner) or kept: show all of it.
	if (f.footNow or 0) > 0 or f.kept then f.footNow = tall end
end

-- The housing as content asks for it: no plate under it, the top light (the accent, content.light, or
-- white on a kept or staying hover; content.pulse animates it in OnUpdate), the edge and the wash.
local function Dress(f, content)
	if f.plateOn then PlateOff(f) end
	UI.Tint(f.light, (f.kept or f.stays) and WHITE or content.light or Theme.Accent)
	f.light:SetAlpha(1)
	-- A meaning's edge (an item's quality): the frame in it, a fifth of the way back to white so its art still reads;
	-- else the look's own.
	local edge = content.edge
	if edge then
		UI.SetBorder(f, { edge[1] + (1 - edge[1]) * 0.2, edge[2] + (1 - edge[2]) * 0.2, edge[3] + (1 - edge[3]) * 0.2 })
	else
		UI.SetBorder(f, Theme.skin.metal)
	end
	local wash = content.wash
	f.wash:SetShown(wash ~= nil)
	if wash then f.wash:SetColorTexture(wash[1], wash[2], wash[3], wash[4] or 0.15) end
end

-- The card (content.card): the form every hover is drawn in.
--
-- A chip shows at once (icon in a slot, title, one key line, as wide as its text). With open = "rest"
-- the body opens out of the chip after the mouse has rested on the same thing, or while Shift is held;
-- moving along a bar of buttons never opens anything.
-- Without open = "rest" the whole body shows at once, except blocks marked more = true: they drop down
-- under it with the foot after a rest, or at once while Shift is held, and stay down for the next thing.
--
--   content = {
--     card = true,
--     about = anything,                 -- identity: a different `about` starts as a chip again
--     title =, titleColor =, seat =,
--     kind = "Spell",                   -- dim word at the head's right (shown once open)
--     way = { arrow = file, turn = function() return radians end, says = function() return "240 yd" end },
--                                       -- the way to it: that arrow turning at the head's right, the
--                                       -- distance (the kind word) before it, said again five times a second
--     key = "words" | { { text =, color =, arrow = "up" | "down" }, ... },   -- the line under the title
--     open = "rest",                    -- chip first; without it the body shows at once
--     least = 170,                      -- the narrowest the card may be, so a short one doesn't squeeze its rows
--     body = { block, ... },            -- top to bottom, each one of:
--       { text = "What it does.", color = }
--       { rows = { row, ... } }         -- text, color, right, rightColor, indent, done, glyph, tint, icon, seat, count
--                                       -- title = "To do": a heading over them
--       { band = { lead = "Replaces", seat =, title =, titleColor =, rows = { ... },
--                  others = { { seat =, title =, titleColor = }, ... } } }   -- more things it stands for, named the same way
--       { bar = { live =, color = } }
--       { model = { creature =, display =, file =, icon =, art =, color = } }   -- what a thing is got from,
--                                       -- turning on a stage under the head (one per card): see NewStage
--       { picture = { file =, caption = } }   -- a square picture the card's width (PICTURE at the least), its
--                                       -- caption under it (one per card): a tricky spot as the map art shows it
--       { foot = { left =, bar = 0 to 1, right = } }
--       any block: more = true          -- not needed at a glance: drops down after a rest (the last blocks)
--     extras = { "words", { text =, color = }, ... },   -- lines not needed at a glance: in the sliding foot
--     hints = { ... },                                  -- what the mouse does: taken, never shown (it is plain)
--     light =, pulse =, wash =,
--   }
-- The whole card is laid out on a clipping frame; the housing starts chip-sized and grows to full size.

local CARD = {
	side = 7, top = 5,             -- padding
	slot = 22, gap = 7, right = 9, -- head: icon size, gap after it, gap after the title
	name = 12, key = 10, small = 8, text = 11,   -- font sizes
	line = 13.5,                   -- body line pitch
	lead = 12,                     -- size of a line's leading tick, glyph or icon
	most = 240,                    -- maximum width
	rest = 0.35, open = 0.16,      -- share of the rest (Hover.Rest) before a chip opens, and seconds the opening takes
	story = 150,                   -- tallest a block of words stands before it scrolls (block.story)
	page = 6,                      -- how far a story's page reaches past its words
	-- A story's page: the hover's own color, solid (a function, so it follows the theme as it changes).
	ground = function() return C.tip[1], C.tip[2], C.tip[3], 1 end,
	lane = 10,                     -- what scrolling words leave their thumb at the right
}
-- The theme's own colors (Lit leaves them as they are).
CARD.palette = { [WHITE] = true }
for _, list in ipairs({ UI.colors, Theme.skin }) do
	for _, c in pairs(list) do
		if type(c) == "table" then CARD.palette[c] = true end
	end
end
local BLACK = { 0, 0, 0 }

local function Face(size, face)
	if face == "lined" then return UI.TextFont(size, "OUTLINE") end   -- for text drawn over the world
	return face == "title" and UI.TitleFont(size) or face == "bold" and UI.NameFont(size) or UI.TextFont(size)
end

-- Object pools per kind; pool.n is reset at each fill.
local function Pooled(card, kind, make)
	local pool = card.pools[kind]
	if not pool then
		pool = { n = 0 }
		card.pools[kind] = pool
	end
	pool.n = pool.n + 1
	local thing = pool[pool.n]
	if not thing then
		thing = make(card)
		pool[pool.n] = thing
	end
	thing:ClearAllPoints()
	thing:Show()
	return thing
end

-- A content's own color (an item's quality, a line the game colored) kept its color where it reads on the hover's fill
-- in the look worn, made vivid just far enough where it doesn't (Theme.Vivid): r, g, b. The theme's own colors (the
-- palette's tables, the accent) are worn as they are: they read already, and follow the theme. nil: as it is.
local function Lit(color)
	if type(color) ~= "table" or CARD.palette[color] then return nil end
	local tip = C.tip
	local gr, gg, gb = UI.LookFill(Theme.Look(), tip[1], tip[2], tip[3], 1)
	return Theme.Vivid(color[1], color[2], color[3], gr, gg, gb, Theme.LC_LABEL)
end

-- A font string inked in `color` (Lit: a content's color made to read).
local function InkLit(fs, color)
	local r, g, b = Lit(color)
	if r then UI.Ink(fs, r, g, b) else UI.Ink(fs, color) end
end

local function Text(card, size, face, color)
	local fs = Pooled(card, "text" .. (face or "") .. size, function(c)
		local made = c:CreateFontString(nil, "OVERLAY")
		made:SetFontObject(Face(size, face))
		UI.Follow(made)   -- a title keeps up with the theme's font
		made:SetShadowOffset(1, -1)
		made:SetShadowColor(0, 0, 0, 1)
		made:SetJustifyV("TOP")
		return made
	end)
	fs:SetJustifyH("LEFT")
	fs:SetWidth(0)
	fs:SetWordWrap(false)
	fs:SetSpacing(0)
	InkLit(fs, color or C.text)
	return fs
end

local function Flat(card, layer, color, alpha, x, y, wide, tall)
	local t = Pooled(card, "flat" .. layer, function(c) return c:CreateTexture(nil, layer) end)
	UI.Paint(t, color, alpha)
	t:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	t:SetSize(wide, tall)
	return t
end

-- Unwrapped text width in a face, through a hidden ruler font string.
local function Measure(card, size, face, text)
	if not text or text == "" then return 0 end
	local key = (face or "") .. size
	local ruler = card.rulers[key]
	if not ruler then
		ruler = card:CreateFontString(nil, "BACKGROUND")
		ruler:SetFontObject(Face(size, face))
		ruler:SetPoint("TOPLEFT")
		ruler:SetAlpha(0)
		card.rulers[key] = ruler
	end
	ruler:SetText(text)
	return ruler:GetStringWidth()
end

local function Arrow(card, way, color, size, x, y)
	local arrow = Pooled(card, "arrow", function(c)
		local made = c:CreateTexture(nil, "OVERLAY")
		made:SetTexture(Shy.Skin.GLYPH.caret)
		return made
	end)
	arrow:SetSize(size, size)
	arrow:SetRotation(way == "up" and math.pi or 0)
	UI.Tint(arrow, color or C.text)
	arrow:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
end

-- Colored parts side by side, truncated at `room`. Returns the width used.
-- Parts with nothing drawn between them (no arrow) are one string, each color written in it: an outlined face pads
-- every string's ends, so strings laid side by side would space a "Human · Guild" unevenly at their seams.
local JOINED = { { text = "" } }
local JOINED_WORDS = {}

local function Joined(parts)
	if #parts < 2 then return parts end
	local base = parts[1].color
	for _, part in ipairs(parts) do
		if part.arrow or (part.color ~= nil and type(part.color) ~= "table") then return parts end
	end
	local words = JOINED_WORDS
	for i, part in ipairs(parts) do
		local text = part.text or ""
		words[i] = (part.color and part.color ~= base) and UI.Wrap(part.color, text) or text
	end
	for i = #parts + 1, #words do words[i] = nil end
	local one = JOINED[1]
	one.text, one.color = table.concat(words), base
	return JOINED
end

local function Phrase(card, parts, size, x, y, room, face)
	if type(parts) == "string" then parts = { { text = parts } } end
	parts = Joined(parts)
	local at = x
	for _, part in ipairs(parts) do
		if part.arrow then
			Arrow(card, part.arrow, part.color, size * 0.7, at + 3, y + size * 0.25)
			at = at + size * 0.7 + 5
		end
		local fs = Text(card, size, face, part.color)
		fs:SetText(part.text or "")
		fs:SetPoint("TOPLEFT", card, "TOPLEFT", at, -y)
		local wide = fs:GetStringWidth()
		if at + wide > x + room then
			wide = math.max(10, x + room - at)
			fs:SetWidth(wide)
		end
		at = at + wide
	end
	return at - x
end

local function Led(row)
	return row.done or row.glyph or row.icon or row.seat
end

-- The size of a row's lead, 0 with none. A seat may ask for more than the usual (seat.lead).
local function LeadSize(row)
	if not Led(row) then return 0 end
	return (not row.done and row.seat and row.seat.lead) or CARD.lead
end

local function Lead(card, about, x, y)
	local lead = Pooled(card, "lead", function(c)
		local made = CreateFrame("Frame", nil, c)
		made:SetSize(CARD.lead, CARD.lead)
		made.seats = {}
		made.glyph = made:CreateTexture(nil, "ARTWORK")
		made.glyph:SetAllPoints()
		made.icon = CreateFrame("Frame", nil, made)
		made.icon:SetAllPoints()
		made.icon.picture = made.icon:CreateTexture(nil, "ARTWORK")
		made.icon.picture:SetAllPoints()
		made.icon.slot = Shy.Slot.New(made.icon, { icon = made.icon.picture, size = CARD.lead, hover = false })
		return made
	end)
	lead:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	lead.glyph:Hide()
	lead.icon:Hide()
	if Seat(lead, not about.done and about.seat or nil, LeadSize(about), "LEFT", lead, "LEFT", 0, 0) then
		return lead   -- drawn by the caller
	elseif about.done then
		Hover.Glyph(lead.glyph, "check", CARD.lead)
		UI.Tint(lead.glyph, C.good)
		lead.glyph:Show()
	elseif about.icon then
		lead.icon.picture:SetTexture(about.icon)
		lead.icon:Show()
	elseif about.glyph then
		Hover.Glyph(lead.glyph, about.glyph, CARD.lead)
		UI.Tint(lead.glyph, about.tint or (about.quiet and C.dim) or C.text)
		lead.glyph:Show()
	end
	return lead
end

-- A body row with wrapping text and optional right text. Returns its height.
-- Rows set in under a row with a lead start under that row's words, not under its lead. Returns this
-- row's extra inset and the one for the rows after it.
local function Hang(row, under)
	if (row.indent or 0) > 0 then return under, under end
	return 0, Led(row) and LeadSize(row) + 4 - 8 or 0
end

-- How many pips a row's count is drawn with (none past PIPS), and how wide that many stand.
local function Pips(row)
	local need = row.count and row.count[2] or 0
	return need > 0 and need <= PIPS and need or 0
end

local function PipSpan(pips)
	return pips * (PIP_W + 1.5) - 1.5
end

-- A name in the room its line has (row.name): whole where it fits, else its last word and the initials of the
-- rest (UI.ShortName). A single word has no shorter form: the line cuts it.
local function Named(card, name, wide)
	if not name:find(" ") or name:find("|", 1, true) or Measure(card, CARD.text, nil, name) <= wide then return name end
	return UI.ShortName(name, UI.Letters(name) - 1)
end

-- lit: the current one, on a faint wash of the accent with its edge lit; wrap = false: one line, cut short;
-- name: one line, shortened as a name is.
local function Line(card, about, x, y, room, inset)
	local top = y
	local at = x + (about.indent or 0) * 8 + (inset or 0)
	-- A larger lead makes the row taller by what it adds, its words centered on it.
	local size = LeadSize(about)
	local more = math.max(0, size - CARD.lead)
	y = y + more / 2
	if size > 0 then
		Lead(card, about, at, y)
		at = at + size + 4
	end
	local taken = 0
	if about.right and about.right ~= "" then
		local right = Text(card, CARD.text, nil, about.rightColor or (about.done and C.dim) or C.text)
		right:SetJustifyH("RIGHT")
		right:SetText(UI.MoneyFit(about.right, right))
		right:SetPoint("TOPRIGHT", card, "TOPLEFT", x + room, -y)
		taken = math.ceil(right:GetStringWidth()) + 10
	end
	-- A count's pips stand before its numbers, as on a step's row.
	local pips = Pips(about)
	if pips > 0 then
		local have = about.count[1] or 0
		local from = x + room - (taken > 0 and taken - 5 or 0) - PipSpan(pips)
		for i = 1, pips do
			Flat(card, "ARTWORK", i <= have and ICE or WHITE, i <= have and 1 or 0.12, from + (i - 1) * (PIP_W + 1.5), y + 2, PIP_W, PIP_H)
		end
		taken = (taken > 0 and taken - 5 or 0) + PipSpan(pips) + 8
	end
	local text = Text(card, CARD.text, nil, about.color or ((about.quiet or about.done) and C.dim) or C.text)
	text:SetPoint("TOPLEFT", card, "TOPLEFT", at, -y)
	local wide = math.max(40, x + room - at - taken)
	local single = about.wrap == false or about.name
	text:SetWidth(wide)
	text:SetWordWrap(not single)
	text:SetSpacing(1.5)
	local words = about.text or ""
	if about.name then words = Named(card, words, wide) end
	text:SetText(UI.MoneyFit(words, text))   -- (spaced lines raise a coin: set for this one)
	local tall = (single and CARD.line or math.max(CARD.line, math.ceil(text:GetStringHeight()) + 2.5)) + more
	if about.lit then
		Flat(card, "BACKGROUND", C.hot, 0.10, 0, top - 2, x + room + CARD.side, tall)
		Flat(card, "ARTWORK", C.hot, 1, 0, top - 2, 2, tall)
	end
	return tall
end

-- A block's preferred width.
local function Natural(card, block)
	local sides = CARD.side * 2
	if block.picture then
		return PICTURE + sides
	elseif block.text or block.story then
		return Measure(card, CARD.text, nil, block.text or block.story) + sides
	elseif block.rows or block.band then
		local band = block.band
		-- A band's label stands over its picture and name.
		local widest = band and Measure(card, CARD.small, nil, Caps(band.lead or ""))
			or (block.title and Measure(card, CARD.small, nil, Caps(block.title)) + 20) or 0
		if band then
			for _, named in ipairs({ band, unpack(band.others or {}) }) do
				widest = math.max(widest, (named.seat and CARD.lead + 5 or 0) + Measure(card, CARD.key, "title", named.title))
			end
		end
		local under = 0
		for _, row in ipairs(block.rows or band.rows or {}) do
			local inset
			inset, under = Hang(row, under)
			local wide = (row.indent or 0) * 8 + inset + (Led(row) and LeadSize(row) + 4 or 0) + Measure(card, CARD.text, nil, row.text)
			if row.right and row.right ~= "" then wide = wide + Measure(card, CARD.text, nil, row.right) + 12 end
			if Pips(row) > 0 then wide = wide + PipSpan(Pips(row)) + 8 end
			widest = math.max(widest, wide)
		end
		return widest + sides
	elseif block.foot then
		local foot = block.foot
		return Measure(card, CARD.key, nil, foot.left) + (foot.bar and 46 or 0) + Measure(card, CARD.key, nil, foot.right) + 14 + sides
	end
	return 0
end

-- The stage (block.model): what a thing is got from, as the game draws it, turning slowly on a dark well,
-- the whole of it in view, in the middle of the well and as large as the well allows (Shy.Model, which
-- measures what it draws and stands the camera to fit); a soft light of the caller's color behind it. A
-- creature is asked for by the display it wears where the caller knows it (drawn at once out of the game's
-- own files), else as itself (drawn once the game has met one); an object, which has no creature, by its
-- model file. Until the model is in, and for what has none, the picture the caller gives: an item's icon in
-- a slot, or a mark of its own ({ file, coords, color }). One per card, reused.
--   model = { creature = id, display = id, file = id, icon = file, art = { file, coords = { l, r, t, b }, color },
--             color = { r, g, b } }
local STAGE = { tall = 104, turn = 0.45, icon = 40 }
-- Words that may run long (block.story: a quest's own text): as tall as they are up to CARD.story (or
-- block.most), then they scroll in place, the wheel gliding, a thumb in the accent and the hover's own
-- surface thickening at the edge there is more past. One per card; a click on it is still a click on the hover.
local function NewStory(card)
	-- (Where it was asked to open, `pending`, is gone to once the game has measured the words: the range it can
	-- scroll is the game's to know, a moment after the words are set.)
	local area = UI.ScrollArea(card, 100, 100, { smooth = true, shades = C.tip, quiet = true, onScroll = function(self)
		local goal = self.pending
		if goal and self:Range() >= goal - 0.5 then
			self.pending = nil
			self:SetVerticalScroll(goal)
			self:Update()
		end
	end })
	-- The page under the words: the hover's own color, solid, its edge a hairline, so no look's art (a galaxy, a comic's
	-- dots, a bright metal) runs under a paragraph. Shown with the words.
	local page = CreateFrame("Frame", nil, card)
	page:SetFrameLevel(math.max(0, area:GetFrameLevel() - 1))
	page.fill = page:CreateTexture(nil, "BACKGROUND")
	page.fill:SetAllPoints()
	for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local edge = page:CreateTexture(nil, "BORDER")
		edge:SetPoint(side[1])
		edge:SetPoint(side[2])
		if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
		edge:SetColorTexture(1, 1, 1, i == 1 and 0.07 or 0.04)
	end
	page:Hide()
	area:HookScript("OnShow", function() page:Show() end)
	area:HookScript("OnHide", function() page:Hide() end)
	area.page = page
	local words = area.content:CreateFontString(nil, "OVERLAY")
	words:SetFontObject(Face(CARD.text))
	UI.Follow(words)
	words:SetShadowOffset(1, -1)
	words:SetShadowColor(0, 0, 0, 1)
	words:SetJustifyH("LEFT")
	words:SetJustifyV("TOP")
	words:SetWordWrap(true)
	words:SetSpacing(2)
	words:SetPoint("TOPLEFT")
	area.words = words
	return area
end

-- Lays the words at x, y on the card, `room` wide; returns how tall they stand.
local function Story(area, block, card, x, y, room)
	local words = area.words
	words:SetText(block.story)
	-- Words to read at length: the theme's own text color (the quiet grey is for asides, too faint for a paragraph), on
	-- their page and inked for it (UI.FaceInk), so they read in every theme and look.
	UI.Paint(area.page.fill, CARD.ground)
	UI.FaceInk(words, area.page, CARD.ground, block.color or C.text)
	-- Their whole width while they fit; narrower by the thumb's lane once they scroll.
	words:SetWidth(room)
	local most = block.most or CARD.story
	local tall = math.ceil(words:GetStringHeight())
	if tall > most then
		words:SetWidth(room - CARD.lane)
		tall = math.ceil(words:GetStringHeight())
	end
	local view = math.min(tall, most)
	-- The page reaches a little past the words all round; the words stand that far into it.
	local pad = CARD.page
	area.page:ClearAllPoints()
	area.page:SetPoint("TOPLEFT", card, "TOPLEFT", x - pad, -y)
	area.page:SetSize(room + 2 * pad, view + 2 * pad)
	y = y + pad
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	area:SetSize(room, view)
	area.content:SetSize(room, math.max(1, tall))
	-- Other words start at their top, or where they were asked to open (block.at: a match, a third of the way
	-- down the view); the same words again keep their place.
	if area.said ~= block.story then
		area.said = block.story
		area:SetVerticalScroll(0)
		area.pending = block.at and tall > view and math.max(0, math.min(tall - view, block.at * tall - view / 3)) or nil
	end
	area:Show()
	area.page:Show()
	area:Update()
	return view + 2 * pad
end

local function NewStage(parent)
	local stage = CreateFrame("Frame", nil, parent)
	stage:SetHeight(STAGE.tall)
	stage.well = stage:CreateTexture(nil, "BACKGROUND")
	stage.well:SetAllPoints()
	UI.Paint(stage.well, BLACK, 0.32)
	stage.halo = stage:CreateTexture(nil, "BORDER")
	stage.halo:SetTexture(Shy.Brand.GLOW)
	stage.halo:SetSize(STAGE.tall * 1.3, STAGE.tall * 1.1)
	stage.halo:SetPoint("CENTER", 0, -4)
	stage.rule = stage:CreateTexture(nil, "BORDER", nil, 1)
	stage.rule:SetPoint("BOTTOMLEFT")
	stage.rule:SetPoint("BOTTOMRIGHT")
	stage.rule:SetHeight(1)
	UI.Paint(stage.rule, C.border, 0.7)
	stage.icon = CreateFrame("Frame", nil, stage)
	stage.icon:SetSize(STAGE.icon, STAGE.icon)
	stage.icon:SetPoint("CENTER")
	stage.icon.picture = stage.icon:CreateTexture(nil, "ARTWORK")
	stage.icon.picture:SetAllPoints()
	stage.icon.slot = Shy.Slot.New(stage.icon, { icon = stage.icon.picture, hover = false })
	stage.art = stage:CreateTexture(nil, "ARTWORK")
	stage.art:SetSize(STAGE.icon + 8, STAGE.icon + 8)
	stage.art:SetPoint("CENTER")
	stage.view = Shy.Model.New(stage)
	stage.view:SetPoint("TOPLEFT", 1, -1)
	stage.view:SetPoint("BOTTOMRIGHT", -1, 1)
	stage.view.turn = STAGE.turn
	-- (The model in: the picture that stood for it goes.)
	stage.view.onDrawn = function()
		stage.icon:Hide()
		stage.art:Hide()
	end
	return stage
end

local function Stage(stage, at)
	UI.Tint(stage.halo, at.color or C.hot, 0.22)
	-- The picture first, until the model is in.
	stage.icon:SetShown(at.icon ~= nil)
	if at.icon then stage.icon.picture:SetTexture(at.icon) end
	stage.art:SetShown(at.icon == nil and at.art ~= nil)
	if at.art and not at.icon then
		stage.art:SetTexture(at.art[1])
		stage.art:SetTexCoord(unpack(at.art.coords or { 0, 1, 0, 1 }))
		UI.Tint(stage.art, at.art.color or WHITE)
	end
	-- What is asked for (the same again keeps what is up): already in, it stands in for the picture at once.
	stage.view:Set(at)
	if stage.view:Drawn() then
		stage.icon:Hide()
		stage.art:Hide()
	end
end

-- Lays the body out from y down. Returns the y it ends at, and the y where the blocks marked more
-- begin (nil with none), padded as the end of the body is.
local function Blocks(card, blocks, y, wide)
	local x, room = CARD.side, wide - CARD.side * 2
	local last, split
	local staged, pictured, storied = false, false, false
	for _, block in ipairs(blocks) do
		if block.more and not split then split = last and (y + (last.band and 0 or 7)) or y end
		if block.model then
			-- The stage (NewStage): one per card, across the card's whole width under the head.
			local stage = card.stage or NewStage(card)
			card.stage = stage
			if not staged then
				staged = true
				y = y + ((last and last.rows) and 7 or 1)
				stage:ClearAllPoints()
				stage:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
				stage:SetWidth(wide)
				Stage(stage, block.model)
				stage:Show()
				y = y + STAGE.tall
			end
		elseif block.picture then
			-- A picture (block.picture: { file, caption }): a square the card's width, with its caption under it. One per card.
			local picture = card.picture
			if not picture then
				picture = card:CreateTexture(nil, "ARTWORK")
				card.picture = picture
			end
			if not pictured then
				pictured = true
				y = y + 6
				local wide = room
				picture:ClearAllPoints()
				picture:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
				picture:SetSize(wide, wide)
				picture:SetTexture(block.picture.file)
				picture:Show()
				y = y + wide
				if block.picture.caption then
					y = y + 4
					local caption = Text(card, CARD.text, nil, C.dim)
					caption:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
					caption:SetWidth(room)
					caption:SetWordWrap(true)
					caption:SetText(block.picture.caption)
					y = y + math.max(CARD.text, math.ceil(caption:GetStringHeight()))
				end
			end
		elseif block.text then
			y = y + 6
			local text = Text(card, CARD.text, nil, block.color)
			text:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
			text:SetWidth(room)
			text:SetWordWrap(true)
			text:SetSpacing(2)
			text:SetText(UI.MoneyFit(block.text, text))
			y = y + math.max(CARD.text, math.ceil(text:GetStringHeight()))
		elseif block.story then
			-- Words that may run long: under a heading as rows have, scrolling past CARD.story. One per card.
			local area = card.story or NewStory(card)
			card.story = area
			if not storied then
				storied = true
				y = y + ((last and (last.rows or last.story)) and 6 or 4)
				if block.title then
					local heading = Text(card, CARD.small, nil, C.dim)
					heading:SetText(Caps(block.title))
					heading:SetPoint("TOPLEFT", card, "TOPLEFT", x, -(y + 1))
					local after = math.ceil(heading:GetStringWidth()) + 6
					if after < room then Flat(card, "BORDER", C.border, 0.6, x + after, y + 5, room - after, 1) end
					y = y + CARD.small + 6
				end
				y = y + Story(area, block, card, x, y, room)
			end
		elseif block.rows then
			y = y + ((last and last.rows) and 6 or 4)
			-- A heading over its rows: dim capitals, and a hairline running on to the right.
			if block.title then
				local heading = Text(card, CARD.small, nil, C.dim)
				heading:SetText(Caps(block.title))
				heading:SetPoint("TOPLEFT", card, "TOPLEFT", x, -(y + 1))
				local after = math.ceil(heading:GetStringWidth()) + 6
				if after < room then Flat(card, "BORDER", C.border, 0.6, x + after, y + 5, room - after, 1) end
				y = y + CARD.small + 6
			end
			local under = 0
			for _, row in ipairs(block.rows) do
				local inset
				inset, under = Hang(row, under)
				y = y + Line(card, row, x, y, room, inset)
			end
		elseif block.band then
			-- A darker band across the full width, for the thing being compared against.
			local band = block.band
			y = y + 7
			local top = y
			local shade = Flat(card, "BACKGROUND", BLACK, 0.22, 0, y, wide, 1)
			Flat(card, "BORDER", C.border, 0.7, 0, y, wide, 1)
			-- Its label on a line of its own, then the thing's picture and its whole name, which wraps
			-- under itself rather than being cut short.
			y = y + 6
			local lead = Text(card, CARD.small, nil, C.dim)
			lead:SetText(Caps(band.lead or ""))
			lead:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
			y = y + CARD.small + 4
			-- The thing, then each other thing it stands for (both hands), on a line of its own the same way.
			for _, named in ipairs({ band, unpack(band.others or {}) }) do
				local at = x
				if named.seat then
					Lead(card, named, at, y - 1)
					at = at + CARD.lead + 5
				end
				local title = Text(card, CARD.key, "title", named.titleColor)
				title:SetPoint("TOPLEFT", card, "TOPLEFT", at, -y)
				title:SetWidth(math.max(20, x + room - at))
				title:SetWordWrap(true)
				title:SetSpacing(1.5)
				title:SetText(named.title or "")
				y = y + math.max(CARD.lead, math.ceil(title:GetStringHeight())) + 3
			end
			for _, row in ipairs(band.rows or {}) do y = y + Line(card, row, x, y, room) end
			y = y + 5
			shade:SetHeight(y - top)
		elseif block.bar then
			y = y + 5
			local bar = Pooled(card, "bar", function(c) return NewBar(c) end)
			bar:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
			bar:SetWidth(room)
			Live(bar, block.bar.live, block.bar.color)
			if not block.bar.live then
				-- What it has, what it would gain after it, and what more could follow that.
				local have = math.max(0, math.min(1, block.bar.have or 0))
				local gain = math.max(0, math.min(1 - have, block.bar.gain or 0))
				local more = math.max(0, math.min(1 - have - gain, block.bar.more or 0))
				bar.have:SetWidth(math.max(0.01, (room - 2) * have))
				bar.gain:SetWidth(math.max(0.01, (room - 2) * gain))
				bar.gain:SetShown(gain > 0)
				bar.more:SetWidth(math.max(0.01, (room - 2) * more))
				bar.more:SetShown(more > 0)
				UI.Tint(bar.have, block.bar.color or C.fill)
				UI.Tint(bar.more, block.bar.moreColor or C.dim)
			end
			y = y + BAR
		elseif block.foot then
			local foot = block.foot
			y = y + ((last and last.band) and 0 or 6)
			if not (last and last.band) then Flat(card, "BORDER", C.border, 0.7, x, y, room, 1) end
			y = y + 4
			local left = Text(card, CARD.key, nil, C.dim)
			left:SetText(foot.left or "")
			left:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
			if foot.bar then
				local at = x + left:GetStringWidth() + 6
				Flat(card, "BACKGROUND", C.border, 1, at - 1, y + 3, 40, 5)
				Flat(card, "BORDER", BLACK, 1, at, y + 4, 38, 3)
				local have = math.max(0, math.min(1, foot.bar))
				if have > 0 then Flat(card, "ARTWORK", C.dim, 1, at, y + 4, 38 * have, 3) end
			end
			local right = Text(card, CARD.key, nil, C.dim)
			right:SetJustifyH("RIGHT")
			right:SetText(foot.right or "")
			right:SetPoint("TOPRIGHT", card, "TOPLEFT", x + room, -y)
			y = y + 12
		end
		last = block
	end
	if card.picture and not pictured then card.picture:Hide() end
	if card.story and not storied then card.story:Hide() end
	if card.stage and not staged then
		card.stage:Hide()
		card.stage.view:Set(nil)
	end
	-- A band or a stage last runs the card's whole width to its end: no padding under it, and the stage's
	-- rule is the housing's own edge there.
	if card.stage and staged then card.stage.rule:SetShown(not (last and last.model)) end
	if last and not (last.band or last.model) then y = y + 7 end
	return y, split
end

local function NewCard(f)
	local card = CreateFrame("Frame", nil, f)
	card:SetPoint("TOPLEFT", 2, -2)
	card:SetPoint("BOTTOMRIGHT", -2, 2)
	card:SetClipsChildren(true)
	card.seats, card.pools, card.rulers = {}, {}, {}
	card.name = card:CreateFontString(nil, "OVERLAY")
	UI.TitleFace(card.name, CARD.name)
	card.name:SetJustifyH("LEFT")
	card.name:SetWordWrap(false)
	card.word = UI.Words(card, UI.TextFont(CARD.small), C.dim, { justify = "RIGHT" })
	-- content.way: the way to the thing, turning at the head's right with the distance before it.
	card.way = card:CreateTexture(nil, "OVERLAY")
	card.way:SetSize(WAY, WAY)
	card.way:Hide()
	-- The head's band: a wash of the card's color behind icon and name, a line of it under them that
	-- fades out at both ends, and a soft shadow falling from that line onto the body.
	card.band = card:CreateTexture(nil, "BACKGROUND", nil, 1)
	card.rise = card:CreateTexture(nil, "BORDER", nil, 2)
	card.fall = card:CreateTexture(nil, "BORDER", nil, 2)
	card.drop = card:CreateTexture(nil, "BORDER", nil, 1)
	for _, t in ipairs({ card.band, card.rise, card.fall, card.drop }) do t:SetColorTexture(1, 1, 1) end
	f.card = card
	return card
end

local BAND = { top = 0.20, foot = 0.06, line = 0.9, shadow = 0.55, fall = 6, after = 3 }

-- Lays the head's band down to `head` in `color`, or puts it away (nil). Returns the room it adds under the head.
local function Band(card, wide, head, color)
	local parts = { card.band, card.rise, card.fall, card.drop }
	if not color then
		for _, t in ipairs(parts) do t:Hide() end
		return 0
	end
	local r, g, b = color[1], color[2], color[3]
	card.band:ClearAllPoints()
	card.band:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	card.band:SetSize(wide, head)
	card.band:SetGradient("VERTICAL", CreateColor(r, g, b, BAND.foot), CreateColor(r, g, b, BAND.top))
	local lr, lg, lb = r + (1 - r) * 0.25, g + (1 - g) * 0.25, b + (1 - b) * 0.25
	local faint, lit = CreateColor(lr, lg, lb, 0), CreateColor(lr, lg, lb, BAND.line)
	card.rise:ClearAllPoints()
	card.rise:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -head)
	card.rise:SetSize(wide / 2, 1)
	card.rise:SetGradient("HORIZONTAL", faint, lit)
	card.fall:ClearAllPoints()
	card.fall:SetPoint("TOPLEFT", card, "TOPLEFT", wide / 2, -head)
	card.fall:SetSize(wide / 2, 1)
	card.fall:SetGradient("HORIZONTAL", lit, faint)
	card.drop:ClearAllPoints()
	card.drop:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -(head + 1))
	card.drop:SetSize(wide, BAND.fall)
	card.drop:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, BAND.shadow))
	for _, t in ipairs(parts) do t:Show() end
	return BAND.after
end

-- The plate (content.plate): a unit, with no housing until it opens.
--
-- Shown at once: the level in a ring and the name on a plaque. The plaque is the health bar (the theme's own bar
-- in the unit's color, a shade over it under the name), and a narrow card (a card body, as above) hangs from under it. With
-- open = "rest" the card waits for a rest or Shift and one line of text sits under the plate until then.
-- extras are in the card's foot, as for any card.
--
--   content = { card = true, about =, open = "rest", body = { ... },
--     plate = {
--       title = "Deep Juices",  level = "6",  levelColor =,
--       titleColor = { r, g, b },                       -- the name's ink (white when none: an enemy player's is red),
--                                                       -- lightened as far as it must to read on the shaded fill
--       crest = "Alliance" | "Horde" | "FFA",           -- before the name: a PvP flag's crest (UI.PvPCrest)
--       rank = "elite" | "rare" | "rareelite" | "boss",  -- its dragon round the level's ring (UI.RankDragon)
--       dead = true,                                    -- dead: grey, the bar empty, "Dead" where the percent was
--       health = { live = function() return 0 to 1 end, color = { r, g, b } },   -- may be secret, as bar.live; the fill
--                                                       -- is the theme's bar in the color itself, under a shade of
--                                                       -- its own hue that lifts along it (PlateShade), so the name reads
--       percent = function() return 0 to 100 end,       -- may be secret; written with SetFormattedText
--       hurt = function() return 0 or 1 end,            -- the percent's alpha: 0 at full health (UI.HurtCurve), may be secret
--       power = function() return now, most, kind end,  -- a thin line in its kind's color (Theme.POWER) along the
--                                                       -- bar's foot; now and most may be secret, kind (Enum.PowerType) not
--       line = "words" | { parts, as a card's key },
--       seat =,                                         -- a mark before that line
--       marks = { seat, ... },                          -- pictures past the plaque's point; a seat's
--                                                       -- live(frame) is asked again while the plate is up
--                                                       -- and hides the mark by returning false
--       danger = { color =, tab = "+3" },               -- ring and level in that color, plus a tab on the ring
--       lit = true,                                     -- kept: white ring
--     } }
-- The hover frame is the dropping card; the plate is drawn above and left of it, and Place positions
-- by the plate.

PLATE = {
	ring = 33, face = 40,          -- ring size, and its art's size (DialPlate, drawn for it)
	tall = 20, top = 6.5, point = 8,   -- plaque: height, offset below the ring's top, pointed end
	power = 2, groove = 1, sheen = 0.4,   -- the resource line along the bar's foot: its height, the dark line over it, its sheen
	reads = 78, far = 50,          -- the contrast white words keep on the fill under its shade: where the name starts, and
	                               -- at the bar's far end (PlateShade)
	capital = 0.7,                 -- capitals' height for a font's size: the percent stands on the name's baseline
	name = 13, level = 15, percent = 9, line = 10,   -- font sizes
	crest = 16,                    -- a PvP flag's crest before the name: its height
	mark = 16, gap = 4, check = 0.2,   -- marks: size, gap between them, seconds between asking `live` again
	said = 6,                      -- the percent's right end, in from the bar's
	caption = 9,                   -- the line under the plate, in small capitals
	from = 29, short = 12,         -- the card starts this far in from the plate's left and ends this far short of its point
	hang = 13,                     -- the card's top is this far below the plate's (behind the plaque)
	body = 18,                     -- where the card's content starts (the plate and its frame cover what is above)
	shut = 6,                      -- card height before it drops, hidden behind the plaque
	rim = 1,                       -- the frame's body reaches this far in over its edge: the bar starts there
	house = 3,                     -- the hover's housing stands this far past its content all round
	least = 110, most = 264,
	mask = 256,                    -- the health bar's mask, in units (longer than any plate)
}
local GOLD = { 1, 0.88, 0.29 }
local DIAL_GLASS = { 0.16, 0.16, 0.19 }   -- the level's dial under the look's own ring (its steel rim would be a second ring)
local DEAD_INK = { 0.55, 0.55, 0.58 }     -- a dead unit's name, level and word (the plate's `dead`)
local LINE_INK = { 0.78, 0.78, 0.82 }     -- the caption under the plate
local CAPTION_CLEAR = 6                   -- the caption's end stays this far short of the plate's point

-- The housing's share of itself: none while a plate's card hasn't dropped, all of it once it has. Each region keeps
-- its own alpha under that share (a look's fainter parts: the frosted pane's band of light, a halo at rest, a shade;
-- a texture's tint and its alpha are one value), so none of them comes back at full. Whoever writes a region's alpha
-- meanwhile (a theme change, a look dressed) is followed, as a drawer's frames are; a write of the alpha it stands at
-- is its color laid again on what was read there, and changes nothing.
local Veil = { share = setmetatable({}, { __mode = "k" }), own = setmetatable({}, { __mode = "k" }),
	stands = setmetatable({}, { __mode = "k" }), writing = false }
function Veil.Write(region, share)
	local a = Veil.own[region] * share
	Veil.stands[region] = a
	Veil.writing = true
	region:SetAlpha(a)
	Veil.writing = false
end
-- `a`: the alpha the call named; a call that names none may have left it or set it, so it is read.
function Veil.Followed(region, a)
	local share = Veil.share[region]
	if Veil.writing or not share then return end
	local secret = issecretvalue(a)
	if not secret and a == nil then
		a = region:GetAlpha()
		secret = issecretvalue(a)
	end
	if secret or type(a) ~= "number" or math.abs(a - Veil.stands[region]) < 0.001 then return end
	Veil.own[region] = a
	Veil.Write(region, share)
end
function Veil.Alpha(region, a) Veil.Followed(region, a) end
function Veil.Color(region, _, _, _, a) Veil.Followed(region, a) end
function Veil.Blend(region) Veil.Followed(region) end
function Veil.Region(region, share)
	local was = Veil.share[region]
	if share >= 1 then
		if was then
			Veil.share[region] = nil
			Veil.Write(region, 1)
		end
		return
	end
	if was == share then return end
	if not was then
		if Veil.own[region] == nil then
			hooksecurefunc(region, "SetAlpha", Veil.Alpha)
			if region.SetVertexColor then hooksecurefunc(region, "SetVertexColor", Veil.Color) end
			if region.SetGradient then hooksecurefunc(region, "SetGradient", Veil.Blend) end
		end
		local a = region:GetAlpha()
		Veil.own[region] = (issecretvalue(a) or type(a) ~= "number") and 1 or a
	end
	Veil.share[region] = share
	Veil.Write(region, share)
end
local function House(f, share)
	for _, region in ipairs(f.shyHousing) do Veil.Region(region, share) end
	Veil.Region(f.wash, share)
end

function PlateOff(f)
	f.plateOn, f.plateBox = false, nil
	if f.plate then f.plate:Hide() end
	House(f, 1)
	f:SetClampRectInsets(-PLATE.house, PLATE.house, PLATE.house, -PLATE.house)
end

-- Stands the marks that are showing side by side in a compartment at the plaque's end: its frame runs on past the
-- bar to hold them, a seam between. Returns the width they take.
local function PlateMarks(plate)
	local x = 0
	for _, slot in ipairs(plate.slots) do
		local seat = slot.seat
		local frame = seat and slot.seats[seat.key .. ":" .. PLATE.mark]
		local shown = frame ~= nil
		if shown and seat.live then
			-- Under pcall: once the unit is gone its getters error, and the mark stays as it was.
			local ok, there = pcall(seat.live, frame)
			if ok then slot.there = there ~= false end
			shown = slot.there == true
		end
		slot:SetShown(shown)
		if shown then
			x = x + PLATE.gap
			slot:ClearAllPoints()
			slot:SetPoint("LEFT", plate.tip, "RIGHT", x, 0)
			-- (What a seat lays beside its mark, a count, is its `after`: room in the compartment.)
			x = x + PLATE.mark + (frame.after or 0)
		end
	end
	if x > 0 then x = x + PLATE.gap end   -- (as far from the frame's end as the first is from the seam)
	if x ~= plate.held then
		plate.held = x
		plate.area:SetPoint("BOTTOMRIGHT", plate.bar, "BOTTOMRIGHT", PLATE.rim + x, -PLATE.rim)
		plate.groove:SetShown(x > 0)
		plate.seam:SetShown(x > 0)
	end
	plate.reach:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", x, 0)
	return x
end

-- A plate's bar fed each frame (under pcall: once the unit is gone the getters error).
local function FeedValue(bar) bar:SetValue(bar.live()) end
local function FeedPercent(bar) bar.said:SetFormattedText("%.0f%%", bar.percent()) end
local function FeedHurt(bar) bar.said:SetAlpha(bar.hurt()) end   -- (gone at full health; a secret alpha set unread)

-- The resource line: its values set unread; recolored only when its kind changes (a druid taking a form).
local function FeedPower(power, of)
	local now, most, kind = of()
	power:SetMinMaxValues(0, most)
	power:SetValue(now)
	if kind ~= power.kind and not issecretvalue(kind) then
		power.kind = kind
		power:GetStatusBarTexture():SetVertexColor(Theme.Power(kind))
	end
end

-- The fill is the theme's own bar in the unit's own color, as every bar of the family is: nothing of the look is
-- drawn over or recolored. White words read on it by one shade laid over the fill: a near-black of the color's own
-- hue (SHADE.ink of its deep shade, Theme.Deep at SHADE.sink: a yellow's is amber, so the gold under it never goes
-- olive), deepest at the bar's start where the name stands (white reads there at PLATE.reads) and lifting evenly to
-- the far end (PLATE.far), where the bar is nearest its plain self. Each end is only as deep as that color needs
-- (Theme.Veil): a shaman's blue takes next to none, a priest's white the most. The shade spans the whole bar and
-- shows through a window that ends at the fill's own texture, so the health (which may be secret) cuts it unread and
-- the shade under the name stays put as the health falls. Worked out when the color changes, never by the frame.
-- A color the game keeps to itself can't be weighed: its shade is black, SHADE.blind deep at the start.
local SHADE = { ink = 0.55, sink = 100, blind = 0.45, blindFar = 0.25 }

local function PlateShade(plate, color)
	local fill, shade, of = plate.bar:GetStatusBarTexture(), plate.shade, plate.shaded
	local r, g, b
	if type(color) == "function" then r, g, b = color() else r, g, b = color[1], color[2], color[3] end
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or type(r) ~= "number" then
		plate.fr = nil
		UI.Tint(fill, color)
		shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, SHADE.blind), CreateColor(0, 0, 0, SHADE.blindFar))
		shade:Show()
		return
	end
	if r == plate.fr and g == plate.fg and b == plate.fb then return end
	plate.fr, plate.fg, plate.fb = r, g, b
	UI.Tint(fill, color)
	local ir, ig, ib = Theme.Deep(r, g, b, SHADE.sink)
	ir, ig, ib = ir * SHADE.ink, ig * SHADE.ink, ib * SHADE.ink
	of[1], of[2], of[3] = ir, ig, ib
	of.near, of.far = Theme.Veil(r, g, b, ir, ig, ib, PLATE.reads), Theme.Veil(r, g, b, ir, ig, ib, PLATE.far)
	shade:SetShown(of.near > 0)
	shade:SetGradient("HORIZONTAL", CreateColor(ir, ig, ib, of.near), CreateColor(ir, ig, ib, of.far))
end

-- The fill's color as it stands under its shade `t` of the way along the bar (0 its start, 1 its far end); nil for
-- a color the game keeps to itself.
local function PlateGround(plate, t)
	local r, g, b, of = plate.fr, plate.fg, plate.fb, plate.shaded
	if not r then return nil end
	local a = of.near + (of.far - of.near) * math.max(0, math.min(1, t))
	return r + (of[1] - r) * a, g + (of[2] - g) * a, b + (of[3] - b) * a
end

local function NewPlate(f)
	local plate = CreateFrame("Frame", nil, f)
	plate:SetFrameLevel(f:GetFrameLevel() + 6)
	-- The plate with its marks, for anything that opens beside it (the pin's menu).
	plate.slots = {}
	plate.reach = CreateFrame("Frame", nil, plate)
	plate.reach:SetPoint("TOPLEFT")
	plate.reach:SetPoint("BOTTOMRIGHT")
	plate:SetScript("OnUpdate", function(self, elapsed)
		self.since = (self.since or 0) + elapsed
		if self.since < PLATE.check then return end
		self.since = 0
		PlateMarks(self)
	end)
	plate.tip = plate:CreateTexture(nil, "BACKGROUND")
	plate.tip:SetTexture(MEDIA .. "HoverPlaqueEnd")
	plate.tip:SetSize(PLATE.point, PLATE.tall)
	plate.tip:SetPoint("TOPRIGHT", 0, -PLATE.top)
	plate.mid = plate:CreateTexture(nil, "BACKGROUND")
	plate.mid:SetTexture(MEDIA .. "HoverPlaqueMid")
	plate.mid:SetPoint("TOPLEFT", PLATE.ring / 2, -PLATE.top)
	plate.mid:SetPoint("BOTTOMRIGHT", plate.tip, "BOTTOMLEFT")
	-- The plate: the look's mini border where it stands, square, the circle at its left end (the plaque's own art
	-- stays only as where things are placed from).
	plate.mid:SetAlpha(0)
	plate.tip:SetAlpha(0)
	-- Health: a StatusBar (the value may be secret and is passed through unread), the plate's whole height.
	local bar = CreateFrame("StatusBar", nil, plate)
	bar:SetPoint("TOPLEFT", PLATE.ring / 2, -PLATE.top)
	bar:SetPoint("BOTTOMRIGHT", plate, "TOPRIGHT", 0, -(PLATE.top + PLATE.tall))
	Shy.Skin.HatchBar(bar)
	bar:SetMinMaxValues(0, 1)
	-- Its frame: the look's mini border flush round the bar (its body lies PLATE.rim in over its own edge, so nothing
	-- dark shows between the two), under the bar.
	local area = CreateFrame("Frame", nil, plate)
	area:SetPoint("TOPLEFT", bar, "TOPLEFT", -PLATE.rim, PLATE.rim)
	area:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", PLATE.rim, -PLATE.rim)
	area:SetFrameLevel(plate:GetFrameLevel())
	bar:SetFrameLevel(area:GetFrameLevel() + 1)
	UI.Panel(area, { hud = true, mini = true, brackets = false, line = false, fill = C.tip })
	plate.area = area
	-- The seam at the bar's end, where the frame runs on to hold the marks (PlateMarks): a dark groove and a line of
	-- the frame's steel, as a nameplate's tag compartment has.
	local seams = CreateFrame("Frame", nil, plate)
	seams:SetAllPoints(bar)
	seams:SetFrameLevel(bar:GetFrameLevel() + 1)
	plate.groove = seams:CreateTexture(nil, "OVERLAY")
	plate.groove:SetColorTexture(0, 0, 0, 0.6)
	plate.groove:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
	plate.groove:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, 0)
	plate.seam = seams:CreateTexture(nil, "OVERLAY", nil, 1)
	plate.seam:SetColorTexture(1, 1, 1, 1)
	plate.seam:SetPoint("TOPLEFT", plate.groove, "TOPRIGHT")
	plate.seam:SetPoint("BOTTOMRIGHT", plate.groove, "BOTTOMRIGHT", 1, 0)
	plate.groove:Hide()
	plate.seam:Hide()
	bar.mask = bar:CreateMaskTexture()
	bar.mask:SetTexture(MEDIA .. "HoverPlaqueMid", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")   -- (square)
	bar.mask:SetSize(PLATE.mask, PLATE.tall)
	bar.mask:SetPoint("RIGHT", bar, "RIGHT")
	bar:GetStatusBarTexture():AddMaskTexture(bar.mask)
	plate.bar = bar
	-- The fill's shade (PlateShade): one gradient the bar's whole length, seen through a window that ends where the
	-- fill's own texture does (and, over a resource line, where that line starts: Plate).
	local window = CreateFrame("Frame", nil, bar)
	window:EnableMouse(false)
	window:SetClipsChildren(true)
	window:SetPoint("TOPLEFT", bar, "TOPLEFT")
	window:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
	plate.shade = window:CreateTexture(nil, "ARTWORK")
	plate.shade:SetPoint("TOPLEFT", bar, "TOPLEFT")
	plate.shade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	plate.shade:SetColorTexture(1, 1, 1, 1)
	plate.shade:Hide()
	plate.window, plate.shaded, plate.ink = window, { 0, 0, 0, near = 0, far = 0 }, {}
	-- The resource: a thin line along the bar's foot in its kind's color, a rod by its sheen, a dark line over it.
	local power = CreateFrame("StatusBar", nil, bar)
	power:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	power:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	power:SetHeight(PLATE.power)
	power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	power:SetMinMaxValues(0, 1)
	local groove = power:CreateTexture(nil, "BACKGROUND")
	groove:SetAllPoints()
	groove:SetColorTexture(0, 0, 0, 0.85)
	local hairline = power:CreateTexture(nil, "OVERLAY")
	hairline:SetPoint("BOTTOMLEFT", power, "TOPLEFT")
	hairline:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT")
	hairline:SetHeight(PLATE.groove)
	hairline:SetColorTexture(0, 0, 0, 0.85)
	local sheen = power:CreateTexture(nil, "ARTWORK", nil, 1)
	sheen:SetPoint("TOPLEFT", power:GetStatusBarTexture(), "TOPLEFT")
	sheen:SetPoint("BOTTOMRIGHT", power:GetStatusBarTexture(), "RIGHT")
	sheen:SetColorTexture(1, 1, 1, 1)
	sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, PLATE.sheen))
	power:Hide()
	plate.power = power
	local top = CreateFrame("Frame", nil, plate)
	top:SetAllPoints()
	top:SetFrameLevel(bar:GetFrameLevel() + 2)
	plate.ring = top:CreateTexture(nil, "ARTWORK")
	plate.ring:SetTexture(MEDIA .. "DialPlate")
	plate.ring:SetSize(PLATE.face, PLATE.face)
	plate.ring:SetPoint("CENTER", plate, "TOPLEFT", PLATE.ring / 2, -PLATE.ring / 2)
	plate.look = UI.LookRing(plate.ring, PLATE.ring)   -- the look's border round the level's circle
	-- A rank's dragon curled round the ring (over the look's border, under the level).
	plate.dragon = top:CreateTexture(nil, "ARTWORK", nil, 6)
	plate.dragon:SetPoint("CENTER", plate.ring, "CENTER")
	plate.dragon:Hide()
	plate.level = Words(top, PLATE.level, GOLD, true)
	plate.level:SetJustifyH("CENTER")
	plate.level:SetPoint("CENTER", plate.ring, "CENTER", 0, 0)
	plate.name = Words(top, PLATE.name, WHITE, true)
	plate.name:SetWordWrap(false)
	plate.crest = top:CreateTexture(nil, "ARTWORK", nil, 2)
	plate.crest:SetPoint("LEFT", plate, "TOPLEFT", PLATE.ring + 6, -(PLATE.top + PLATE.tall / 2))
	plate.crest:Hide()
	bar.said = UI.Words(top, UI.NameFont(PLATE.percent), WHITE)
	-- Centred on the bar by its digits' ink (as the name is by its capitals'), PLATE.said in from the bar's end.
	bar.said:SetPoint("RIGHT", bar, "RIGHT", -PLATE.said, UI.NameLift(PLATE.percent))
	-- Under pcall: once the unit is gone the getters error, and the last values stay.
	bar.Feed = function(self)
		if self.live then pcall(FeedValue, self) end
		if self.percent then pcall(FeedPercent, self) end
		if self.hurt then pcall(FeedHurt, self) end
		if self.powerOf then pcall(FeedPower, plate.power, self.powerOf) end
	end
	bar:SetScript("OnUpdate", Shy.Clocked("hover: a unit's health", bar.Feed))
	-- danger.tab: a small tab on the ring's lower right.
	plate.tabEdge = top:CreateTexture(nil, "OVERLAY", nil, 1)
	plate.tabEdge:SetColorTexture(0.02, 0.02, 0.02, 1)
	plate.tab = top:CreateTexture(nil, "OVERLAY", nil, 2)
	plate.tabText = top:CreateFontString(nil, "OVERLAY", nil, 3)
	plate.tabText:SetFontObject(UI.NameFont(PLATE.percent))
	plate.tabText:SetTextColor(1, 1, 1)
	plate.tabText:SetPoint("BOTTOMLEFT", plate, "TOPLEFT", PLATE.ring - 9, -(PLATE.ring + 1))
	plate.tab:SetPoint("TOPLEFT", plate.tabText, "TOPLEFT", -2.5, 1)
	plate.tab:SetPoint("BOTTOMRIGHT", plate.tabText, "BOTTOMRIGHT", 2.5, -1)
	plate.tabEdge:SetPoint("TOPLEFT", plate.tab, "TOPLEFT", -1, 1)
	plate.tabEdge:SetPoint("BOTTOMRIGHT", plate.tab, "BOTTOMRIGHT", 1, -1)
	-- The line under the plate; it fades out as the card drops.
	plate.under = CreateFrame("Frame", nil, plate)
	plate.under:SetAllPoints()
	plate.under.pools, plate.under.rulers = {}, {}
	f.plate = plate
	return plate
end

-- Lays the plate out over a card `wide` across; returns the width the card should take.
local function Plate(f, about, wide)
	local plate = f.plate or NewPlate(f)

	local bar = plate.bar
	f.plateOn = true
	plate:Show()
	f.light:SetAlpha(0)
	-- As long as the name needs, and never shorter than the card under it.
	local after = (about.percent and 30 or 6) + PLATE.point + 2
	-- A PvP flag's crest stands before the name, which moves along for it.
	local lead = PLATE.ring + 8
	local crest = about.crest
	local cw, ch = UI.Crest(plate.crest, crest, PLATE.crest, UI.TexelsFor(plate))
	if crest then lead = PLATE.ring + 6 + cw + 3 end
	local dead = about.dead == true
	-- The words stand on the bar's middle, or on the middle of the room over a resource line when there is one.
	local powered = not dead and about.power ~= nil
	local foot = powered and (PLATE.groove + PLATE.power) or 0
	local middle = -(PLATE.top + (PLATE.tall - foot) / 2)
	-- The crest stands on the same middle as the name's capitals (not the plaque's, which a resource line moves
	-- the words off), its corner on a screen pixel so its edges stay sharp.
	if crest then
		local scale = plate:GetEffectiveScale()
		local per = scale and not issecretvalue(scale) and scale > 0 and scale / PixelUtil.GetPixelToUIUnitFactor() or 1
		local floor = math.floor
		plate.crest:ClearAllPoints()
		plate.crest:SetPoint("TOPLEFT", plate, "TOPLEFT", floor((PLATE.ring + 6) * per + 0.5) / per,
			floor((middle + ch / 2) * per + 0.5) / per)
	end
	plate.name:ClearAllPoints()
	-- On the bar's middle by its capitals (the face worn: UI.TitleLift).
	plate.name:SetPoint("LEFT", plate, "TOPLEFT", lead, middle + UI.TitleLift(PLATE.name))
	plate.name:SetWidth(0)
	plate.name:SetText(about.title or "")
	-- The percent, smaller, stands on the name's baseline: its capitals' middle that much lower than the name's.
	bar.said:ClearAllPoints()
	bar.said:SetPoint("RIGHT", plate, "TOPRIGHT", -PLATE.said,
		middle - (PLATE.name - PLATE.percent) * PLATE.capital / 2 + UI.NameLift(PLATE.percent))
	-- The line under the plate: a caption in small capitals, under the start of the name (a player's class keeps its
	-- color). Laid first: the plate runs on past its end (a short name over a long owner's or guild's name), up to the
	-- plate's longest, where the caption is cut short instead.
	local under = plate.under
	for _, pool in pairs(under.pools) do
		for i = 1, #pool do pool[i]:Hide() end
		pool.n = 0
	end
	local x = PLATE.ring + 5
	if about.seat then
		Lead(under, about, x, PLATE.ring - 4)
		x = x + CARD.lead + 3
	end
	local reach = 0   -- where the caption ends, from the plate's left
	if about.line then
		local parts = type(about.line) == "string" and { { text = about.line } } or about.line
		local caps = plate.caps or {}
		plate.caps = caps
		for i, part in ipairs(parts) do
			local cap = caps[i] or {}
			caps[i] = cap
			cap.text, cap.color, cap.arrow = (part.text or ""):upper(), part.color or LINE_INK, part.arrow
		end
		for i = #parts + 1, #caps do caps[i] = nil end
		local from = about.seat and x or lead
		reach = from + Phrase(under, caps, PLATE.caption, from, PLATE.ring - 2, PLATE.most - PLATE.point - CAPTION_CLEAR - from, "lined")
	end
	local named = plate.name:GetStringWidth()
	local long = math.max(lead + named + after, reach + PLATE.point + CAPTION_CLEAR)
	long = math.max(PLATE.least, math.min(PLATE.most, math.ceil(long)), wide + 4 + PLATE.from + PLATE.short)
	plate.name:SetWidth(long - lead - after)
	plate:SetSize(long, PLATE.ring)
	plate:ClearAllPoints()
	plate:SetPoint("TOPLEFT", f, "TOPLEFT", -PLATE.from, PLATE.hang)
	local health = about.health or {}
	-- Dead: the bar empty and the word where the percent was.
	bar.live, bar.percent = (not dead) and health.live or nil, (not dead) and about.percent or nil
	bar.hurt = (not dead) and about.hurt or nil
	if not bar.hurt then bar.said:SetAlpha(1) end
	bar.powerOf = powered and about.power or nil
	plate.power.kind = nil
	plate.power:SetShown(powered)
	-- The shade ends at the bar's foot, or on the resource line: that line keeps its own color.
	if plate.powered ~= powered then
		plate.powered = powered
		plate.window:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, powered and (PLATE.power + PLATE.groove) or 0)
	end
	PlateShade(plate, health.color or C.good)
	-- The name: white, on the shaded fill and on the bar's dark past it alike. A color of its own (an enemy player's
	-- red) is kept as far as it reads where the shade is lightest under it, the name's own end, and goes toward the
	-- white the bar is shaded for.
	local ink = dead and DEAD_INK or about.titleColor or WHITE
	if ink ~= WHITE and ink ~= DEAD_INK and type(ink) == "table" and plate.fr then
		local start = PLATE.ring / 2
		local ends = lead + math.min(named, long - lead - after)
		local gr, gg, gb = PlateGround(plate, (ends - start) / (long - start))
		local own = plate.ink
		own[1], own[2], own[3] = Theme.Readable(ink[1], ink[2], ink[3], gr, gg, gb, Theme.LC_LARGE, 1, 1, 1)
		ink = own
	end
	UI.Ink(plate.name, ink)
	if dead then bar:SetValue(0) elseif not health.live then bar:SetValue(1) end
	bar.said:SetShown(bar.percent ~= nil or dead)
	if dead then
		bar.said:SetText(DEAD)
		bar.said:SetTextColor(DEAD_INK[1], DEAD_INK[2], DEAD_INK[3])
	else
		bar.said:SetText("")   -- (the percent is written by the feed: nothing of a death left until it is)
		bar.said:SetTextColor(1, 1, 1)
	end
	bar:Feed()
	local danger = about.danger
	plate.look:Plain(not (about.lit or danger))   -- (a danger's color, or the light of a pin, is the rim's to carry)
	-- Under the look's own ring the dial's steel rim is glass: one ring shows.
	UI.Tint(plate.ring, about.lit and WHITE or (danger and danger.color) or (plate.look:Worn() and DIAL_GLASS) or Theme.skin.metal)
	UI.Tint(plate.seam, Theme.skin.metal, 0.55)
	local dragon = UI.RankDragon(about.rank, PLATE.ring, UI.TexelsFor(plate))
	plate.dragon:SetShown(dragon ~= nil)
	if dragon then
		plate.dragon:SetTexture(dragon.file)
		plate.dragon:SetSize(dragon.span, dragon.span)
	end
	plate.level:SetText(about.level or "")
	UI.Ink(plate.level, (dead and DEAD_INK) or (danger and danger.color) or about.levelColor or GOLD)
	-- (Its letters on the ring's middle, as they are worn in that ink: Theme.Centre.)
	Theme.Centre(plate.level, plate.ring, 0, UI.TitleLift(PLATE.level))
	local tab = danger and danger.tab
	plate.tab:SetShown(tab ~= nil)
	plate.tabEdge:SetShown(tab ~= nil)
	plate.tabText:SetShown(tab ~= nil)
	if tab then
		plate.tabText:SetText(tab)
		plate.tab:SetColorTexture(danger.color[1], danger.color[2], danger.color[3], 1)
		UI.FaceInk(plate.tabText, plate, danger.color, WHITE)
	end
	local marks = about.marks or {}
	for index = 1, math.max(#marks, #plate.slots) do
		local slot = plate.slots[index]
		if not slot then
			slot = CreateFrame("Frame", nil, plate)
			slot:SetSize(PLATE.mark, PLATE.mark)
			slot.seats = {}
			plate.slots[index] = slot
		end
		slot.seat, slot.there = marks[index], nil
		Seat(slot, marks[index], PLATE.mark, "CENTER", slot, "CENTER", 0, 0)
	end
	local past = PlateMarks(plate)
	-- Place positions and clamps by the plate's box, not the card's.
	local card = long - PLATE.from - PLATE.short
	f.plateBox = { wide = long + past, tall = PLATE.ring + ((about.line or about.seat) and 11 or 0) }
	f:SetClampRectInsets(-PLATE.from, math.max(PLATE.house, PLATE.short + past), PLATE.hang, -PLATE.house)
	return card - 4
end

-- Sizes the housing between chip and full size by f.opened (0 to 1, eased).
local function CardStand(f)
	local shut = 1 - (f.opened or 1)
	local open = 1 - shut * shut * shut
	f.tall = f.chipTall + (f.fullTall - f.chipTall) * open + 4
	f:SetWidth(f.chipWide + (f.fullWide - f.chipWide) * open + 4)
	Stand(f)   -- the height, with as much of the foot as has slid down
	-- Under a plate the housing fades in as the card drops, and the line under the plate fades out.
	local plate = f.plateOn and f.plate
	if plate then
		local out = f.dropped and math.min(1, (f.opened or 1) * 4) or 0
		House(f, out)
		plate.under:SetAlpha(1 - out)
	end
end

function CardTick(f, elapsed)
	f.rested = (f.rested or 0) + elapsed
	-- Blocks marked more drop with the foot: on the foot's rest, or at once on a kept hover.
	local ready = f.drops and (f.kept or (f.rest or 0) >= Hover.Rest()) or (not f.drops and f.rested >= Hover.Rest(CARD.rest))
	if not (f.opening or ready or IsShiftKeyDown()) then return end
	f.opening = true
	f.opened = math.min(1, f.opened + elapsed / CARD.open)
	CardStand(f)
end

-- asked: the content as the caller gave it, when `content` is it said as a card (Said); f.content is what
-- was asked, f.said what is drawn.
function Card(f, content, width, asked)
	local fresh = not f:IsShown()
	local card = f.card or NewCard(f)
	Dress(f, content)
	f.content, f.said = asked or content, content
	local most = content.most or CARD.most
	card:Show()
	for _, pool in pairs(card.pools) do
		for i = 1, #pool do pool[i]:Hide() end
		pool.n = 0
	end

	-- The head: icon, title, key line.
	local blocks = content.body or {}
	local x = CARD.side
	local keyed = content.key ~= nil and content.key ~= ""
	local seat = Seat(card, content.seat, CARD.slot, "TOPLEFT", card, "TOPLEFT", CARD.top, -CARD.top)
	if seat then x = CARD.top + CARD.slot + CARD.gap end
	local head, wide, nameTop = 0, 0, 0
	local way = content.title and content.way or nil
	card.name:SetShown(content.title ~= nil)
	card.word:SetShown(content.title ~= nil and content.kind ~= nil)
	card.way:Hide()          -- shown by the hover's tick, once it has a way to turn to
	if content.title then
		head = (seat or keyed) and (CARD.top * 2 + CARD.slot) or 23
		local kind = content.kind and Caps(content.kind) or ""
		local kindWide = kind ~= "" and (Measure(card, CARD.small, nil, kind) + 10) or 0
		if way then kindWide = kindWide + WAY + 4 end
		if f.stays then kindWide = kindWide + 13 end   -- room for the close button
		local room = most - x - CARD.right
		card.name:SetWidth(0)
		card.name:SetText(content.title)
		InkLit(card.name, content.titleColor or WHITE)
		local name = math.min(card.name:GetStringWidth(), room - kindWide)
		card.name:SetWidth(name)
		card.name:ClearAllPoints()
		nameTop = keyed and 3.5 or (head - CARD.name - 2) / 2
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", x, -nameTop)
		local key = keyed and Phrase(card, content.key, CARD.key, x, 18.5, room) or 0
		wide = x + math.max(name, key) + CARD.right
		f.chipWide = wide
		wide = math.max(wide, x + name + kindWide + CARD.right)
		card.word:SetText(kind)
	else
		f.chipWide = 0
	end

	for _, block in ipairs(blocks) do wide = math.max(wide, Natural(card, block)) end
	-- (Extra lines wrap; they don't widen the card.)
	wide = math.min(most, math.ceil(wide))
	if content.least then wide = math.max(wide, math.min(most, content.least)) end
	-- With a plate, the title is the plate's and the card takes the width the plate allows.
	local plate = content.plate
	if plate then
		wide = math.max(wide, Plate(f, plate, wide))
		head = PLATE.body
	end
	f.chipWide = math.min(f.chipWide, wide)
	local right = wide - CARD.side - (f.stays and 13 or 0)
	if way then
		card.way:SetTexture(way.arrow)
		UI.Tint(card.way, C.hot)
		card.way:ClearAllPoints()
		card.way:SetPoint("TOPRIGHT", card, "TOPLEFT", right, -math.floor((head - WAY) / 2))
		right = right - WAY - 4
	end
	-- The kind word stands on the name's line, its middle on the name's.
	card.word:ClearAllPoints()
	card.word:SetPoint("RIGHT", card, "TOPLEFT", right, -(nameTop + (CARD.name + 2) / 2))
	-- A head over a body stands on its band, in the card's light.
	local banded = content.title ~= nil and not plate and #blocks > 0
	local tint = banded and (content.light or { Theme.Accent() }) or nil
	-- Always laid out, even with no blocks: that is what puts away the stage, the story and the
	-- picture the previous content left on the card, which would otherwise show through the foot.
	local tall, split = Blocks(card, blocks, head + Band(card, wide, head, tint), wide)
	f.fullWide, f.fullTall = wide, tall
	f.width = wide + 4

	-- Refilling for the same `about` (a cooldown counting down) keeps the open state. Blocks marked more
	-- that were down for the thing before stay down, as the foot does. Content said as a card has no
	-- `about` and leaves the frame's alone (a caller may keep its own there).
	local same = not fresh and (asked ~= nil or f.about == content.about)
	local down = not fresh and f.drops and (f.opened or 0) >= 1
	if not asked then f.about = content.about end
	f.drops = false
	if plate then
		-- Shut, the card is a sliver behind the plaque; with no body it stays one.
		f.dropped = #blocks > 0
		f.chipWide, f.chipTall = wide, PLATE.shut
		if not f.dropped then
			f.opened, f.fullTall = 1, PLATE.shut
		elseif content.open ~= "rest" then
			f.opened = 1
		elseif not same then
			f.opened, f.opening, f.rested = IsShiftKeyDown() and 1 or 0, false, 0
		end
	elseif split and content.open ~= "rest" then
		-- All of it at once, as wide as it will be, but what is marked more.
		f.drops, f.chipWide, f.chipTall = true, wide, split
		if not same then f.opened, f.opening = (down or IsShiftKeyDown()) and 1 or 0, false end
	elseif content.open ~= "rest" or #blocks == 0 or not content.title then
		f.opened, f.chipWide, f.chipTall = 1, wide, tall
	else
		f.chipTall = head
		if not same then f.opened, f.opening, f.rested = IsShiftKeyDown() and 1 or 0, false, 0 end
	end
	-- The foot: the extra lines, sliding down after a rest on this thing. A plate with no card has none.
	Foot(f, (plate and not f.dropped) and {} or content, wide + 4)
	if not same and (f.footNow or 0) == 0 then f.rest = 0 end
	CardStand(f)
	return f.tall
end

-- A name longer than this many letters is said as words under no head, not cut short in one.
local NAME_MOST = 40

-- Content in the standard form said as a card, the one form every hover is drawn in: the strip (and the
-- note) is the quiet word at the head's right, the sub the line under the title, a dial's way the arrow
-- and the distance at the head's right; the text, then each section's rows under its heading, its
-- words and its bar. With no title the strip is the name. `width` is the widest it may grow.
local function Said(content, width)
	local said = { card = true, seat = content.seat, light = content.light, pulse = content.pulse, edge = content.edge, wash = content.wash,
		hints = content.hints, extras = content.extras, most = math.max(CARD.most, (width or WIDTH) - 4), body = {} }
	local body = said.body
	local strip = content.strip ~= "" and content.strip or nil
	local note = content.note ~= "" and content.note or nil
	if content.title then
		said.title, said.titleColor = content.title, content.titleColor
		said.kind = strip and note and (strip .. "  \194\183  " .. note) or strip or note
		if content.sub and content.sub ~= "" then said.key = { { text = content.sub, color = content.subHot and C.hot or C.dim } } end
		local dial = content.dial
		if dial and not dial.seated then
			local says = dial.says
			if not says and dial.yards then
				says = function()
					local yards = type(dial.yards) == "function" and dial.yards() or dial.yards
					return yards and (yards >= 1000 and ("%.1fk yd"):format(yards / 1000) or ("%d yd"):format(math.floor(yards + 0.5))) or nil
				end
			end
			said.way = { arrow = dial.arrow, turn = dial.turn, says = says }
		end
	elseif strip and #UI.PlainText(strip) <= NAME_MOST then
		said.title, said.titleColor, said.kind = strip, content.color, note
	elseif strip then
		body[#body + 1] = { text = strip, color = content.color }
	end
	if content.text and content.text ~= "" then body[#body + 1] = { text = content.text, color = content.textColor } end
	for _, section in ipairs(content.sections or {}) do
		if section.story then
			body[#body + 1] = { title = section.title, story = section.story, most = section.most, at = section.at }
		elseif section.title or (section.rows and #section.rows > 0) then
			body[#body + 1] = { title = section.title, rows = section.rows or {} }
		end
		if section.words and section.words ~= "" then body[#body + 1] = { text = section.words } end
		if section.more and section.more ~= "" then body[#body + 1] = { text = section.more, color = C.dim } end
		if section.bar then body[#body + 1] = { bar = section.bar } end
	end
	return said
end

-- Lays the content out as a card; returns its height.
local function Fill(f, content, width)
	if content.card then return Card(f, content, width) end
	return Card(f, Said(content, width), width, content)
end

-- Placement

-- A hover by the cursor stands off its tip up and to the right; near the screen's right edge it turns to
-- the left, near the top it hangs below, so being kept on the screen never lays it over the cursor and
-- what the cursor is on. It goes with the cursor (the hover's OnUpdate) and is set only when it moved.
local OFF = 14               -- from the cursor's tip
local UNDER = 30             -- down past the cursor's picture, which hangs below and right of its tip
function AtCursor(f)
	local scale = f:GetEffectiveScale()
	local x, y = GetCursorPosition()
	x, y = x / scale, y / scale
	local screen = UIParent:GetEffectiveScale() / scale
	local right = x + OFF + f:GetWidth() <= (UIParent:GetWidth() or 0) * screen
	local up = y + OFF + f:GetHeight() <= (UIParent:GetHeight() or 0) * screen
	local point = (up and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT")
	x = right and x + OFF or x - OFF
	y = up and y + OFF or y - (right and UNDER or OFF)
	if f.cursorAt == point and f.cursorX == x and f.cursorY == y then return end
	f.cursorAt, f.cursorX, f.cursorY = point, x, y
	f:ClearAllPoints()
	f:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
end

-- Cards that stay (Stay) hold their place: a hover whose spot one of them covers slots in beside it, under
-- it (over it when there is no room under, or when it was to stand over its owner), keeping the edge it
-- would have lined up with. Measured in UIParent's units.
local staying = {}           -- by id

local function Rect(frame)
	local l, b, w, h = frame:GetRect()
	if not (l and b and w and h) or issecretvalue(l) or issecretvalue(b) or issecretvalue(w) or issecretvalue(h) then return nil end
	local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * s, b * s, (l + w) * s, (b + h) * s
end

local function Slot(f, side, ratio, l, b, r, t)
	local tall, room = t - b, UIParent:GetHeight() or 0
	for _ = 1, 4 do   -- a few cards may stand in a row
		local s, sl, sb, sr, st
		for _, card in pairs(staying) do
			if card ~= f and card:IsShown() then
				local cl, cb, cr, ct = Rect(card)
				if cl and l < cr and cl < r and b < ct and cb < t then
					s, sl, sb, sr, st = card, cl, cb, cr, ct
					break
				end
			end
		end
		if not s then return end
		local gap = GAP * ratio
		local over = side == "TOP" or sb - gap - tall < 0
		if over and st + gap + tall > room then over = false end   -- room neither way: under, kept on the screen
		local edge, dx = "", (l + r) / 2 - (sl + sr) / 2
		if side == "LEFT" then
			edge, dx = "RIGHT", r - sr
		elseif side == "RIGHT" then
			edge, dx = "LEFT", l - sl
		end
		f:ClearAllPoints()
		if over then
			f:SetPoint("BOTTOM" .. edge, s, "TOP" .. edge, dx / ratio, GAP)
			b, t = st + gap, st + gap + tall
		else
			f:SetPoint("TOP" .. edge, s, "BOTTOM" .. edge, dx / ratio, -GAP)
			b, t = sb - gap - tall, sb - gap
		end
	end
end

local function Place(f, to, opts, width)
	local dock = opts.dock
	-- Docked, the hover takes the dock's scale; otherwise it ignores its owner's scale (a zoomed map pin).
	local unit = to:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local ratio = dock and unit or opts.scale or 1
	f:SetScale(ratio)
	f:ClearAllPoints()
	f.under, f.cursorAt = nil, nil
	-- A kept hover on the same dock: stack under it, unless it was dragged off somewhere.
	if dock and kept and kept ~= f and kept:IsShown() and kept.dock == dock and not kept.placed then
		f:SetPoint(kept.side == "LEFT" and "TOPRIGHT" or "TOPLEFT", kept, kept.side == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -2)
		f.side = kept.side
		f.under = kept   -- anchored to that frame: see Keep
		return
	end
	-- opts.at: explicit anchor. Nothing is measured, since the target may be a restricted region.
	local at = opts.at
	if at then
		f.side = nil
		local box = f.plateBox
		if box then
			-- The plate goes at the point; the frame (the dropping card) hangs from the plate's top.
			local point = at[1]
			local x = point:find("LEFT", 1, true) and 0 or point:find("RIGHT", 1, true) and -box.wide or -box.wide / 2
			local y = point:find("TOP", 1, true) and 0 or point:find("BOTTOM", 1, true) and box.tall or box.tall / 2
			f:SetPoint("TOPLEFT", at[2], at[3] or point, (at[4] or 0) + x + PLATE.from, (at[5] or 0) + y - PLATE.hang)
			return
		end
		f:SetPoint(at[1], at[2], at[3] or at[1], at[4] or 0, at[5] or 0)
		return
	end
	local side = opts.side
	local left, right = (to:GetLeft() or 0) * unit, (to:GetRight() or 0) * unit
	local need = (width + GAP) * ratio
	local roomLeft, roomRight = left, (UIParent:GetWidth() or 0) - right
	if not side and opts.outside and roomLeft < need and roomRight < need then
		-- Beside it there is no room: under it or over it, whichever has more.
		side = (to:GetBottom() or 0) * unit >= (UIParent:GetHeight() or 0) - (to:GetTop() or 0) * unit and "BOTTOM" or "TOP"
	elseif not side then
		side = (dock and roomLeft >= need) and "LEFT" or (roomRight >= need or roomLeft < need) and "RIGHT" or "LEFT"
	elseif side == "RIGHT" and roomRight < need and roomLeft >= need then
		side = "LEFT"
	elseif side == "LEFT" and roomLeft < need and roomRight >= need then
		side = "RIGHT"
	elseif side == "TOP" or side == "BOTTOM" then
		-- Flip when there is no room: clamped to the screen it would cover its owner.
		local tall = (f:GetHeight() + GAP) * ratio
		local over, under = (UIParent:GetHeight() or 0) - (to:GetTop() or 0) * unit, (to:GetBottom() or 0) * unit
		if side == "TOP" and over < tall and under >= tall then
			side = "BOTTOM"
		elseif side == "BOTTOM" and under < tall and over >= tall then
			side = "TOP"
		end
	end
	f.side = side
	local gap = dock and -1 or opts.gap or GAP
	if side == "CURSOR" then
		AtCursor(f)
	elseif side == "LEFT" then
		f:SetPoint("TOPRIGHT", to, "TOPLEFT", -gap, 0)
	elseif side == "TOP" then
		f:SetPoint("BOTTOM", to, "TOP", 0, GAP)
	elseif side == "BOTTOM" then
		f:SetPoint("TOP", to, "BOTTOM", 0, -GAP)
	else
		f:SetPoint("TOPLEFT", to, "TOPRIGHT", gap, 0)
	end
	if side == "CURSOR" or not next(staying) then return end
	-- Where it stands now, to see whether a card that stays is there.
	local top, bottom = (to:GetTop() or 0) * unit, (to:GetBottom() or 0) * unit
	local wide, tall = width * ratio, f:GetHeight() * ratio
	local l, t
	if side == "LEFT" then
		l, t = left - gap * ratio - wide, top
	elseif side == "TOP" then
		l, t = (left + right) / 2 - wide / 2, top + GAP * ratio + tall
	elseif side == "BOTTOM" then
		l, t = (left + right) / 2 - wide / 2, bottom - GAP * ratio
	else
		l, t = right + gap * ratio, top
	end
	Slot(f, side, ratio, l, t - tall, l + wide, t)
end

-- Over the menu or under it
-- An open menu stands over every hover but its own rows': one kept up, or about something beside the menu,
-- slips a layer under it while it is open, and comes back up when it closes (UI.Menu and UI.CloseMenu).

local function Stack(f)
	local by = f.owner or (f.of and f.of.owner)
	local want = (UI.MenuOwner() and not UI.InMenu(by)) and "FULLSCREEN" or "TOOLTIP"
	if f:GetFrameStrata() ~= want then f:SetFrameStrata(want) end
end

function Hover.Restack()
	for _, f in ipairs(built) do Stack(f) end
end

-- Showing, hiding, keeping

function Hover.Owner()
	return wing and wing:IsShown() and owner or nil
end

-- Every hover frame there is, shown or not: the one under the mouse, kept, beside and staying.
function Hover.Each(fn)
	for _, f in ipairs(built) do fn(f) end
end

function Hover.Frame(index)
	if index then
		local f = beside[index]
		return f and f:IsShown() and f or nil
	end
	return wing and wing:IsShown() and wing or nil
end

-- Hides the Beside frames attached to f.
local function Alone(f)
	for _, other in pairs(beside) do
		if other.of == f then
			other:Hide()
			other.content, other.of = nil, nil
		end
	end
end

function Hover.Show(by, content, opts)
	opts = opts or {}
	-- A kept hover with the same key is already showing this.
	if kept and kept:IsShown() and kept.key ~= nil and kept.key == opts.key then return kept end
	wing = wing or spare or Build()
	if wing == spare then spare = nil end
	generation = generation + 1
	local fresh = not wing:IsShown()
	-- A foot that is already down stays down across owners; the rest timer restarts.
	if fresh then wing.footNow = 0 end
	if fresh or owner ~= by then wing.rest = 0 end
	if owner ~= by then Alone(wing) end
	owner = by
	local width = opts.width or (content.title and WIDTH or TIP_WIDTH)
	wing.owner, wing.dock, wing.opts, wing.key = by, opts.dock, opts, opts.key
	wing.keeps = opts.keep ~= false and content.title ~= nil
	-- A click keeps it up only where that was asked for, and while pinning is on.
	wing.pins = Hover.pinning and opts.keep == true and wing.keeps
	wing.kept, wing.lingering, wing.away = false, false, 0
	wing.placed, wing.pressX, wing.dragging = nil, nil, false
	-- A hover that can't be kept takes no mouse: it may cover the next thing to click.
	wing:EnableMouse(wing.keeps)
	wing:SetWidth(width)
	Fill(wing, content, width)
	Stand(wing)
	Place(wing, opts.dock or opts.outside or by, opts, width)
	Stack(wing)
	if fresh then
		wing.rising = 0
		wing:SetAlpha(0)
	end
	wing:Show()
	return wing
end

function Hover.Close(f)
	f = f or wing
	if not f then return end
	local was = f.kept
	f:Hide()
	Alone(f)
	f.content, f.kept, f.lingering = nil, false, false
	if f == wing then
		generation = generation + 1
		owner = nil
	elseif f == kept then
		kept = nil
		if not spare then spare = f end
	end
	if was and f.opts and f.opts.onKeep then f.opts.onKeep(f, false) end
end

-- now: skip the grace period.
function Hover.Hide(by, now)
	if not wing or (by and by ~= owner) then return end
	if now then
		Hover.Close(wing)
		return
	end
	local asked = generation
	C_Timer.After(GRACE, function()
		if asked ~= generation or not wing then return end   -- shown again since
		-- The mouse moved onto the hover itself: it stays while the mouse is there.
		if wing.keeps and wing:IsMouseOver() then
			wing.lingering, wing.away = true, 0
		else
			Hover.Close(wing)
		end
	end)
end

-- A click on the hover: keep it, or close it if it is kept.
function Keep(f)
	if f.kept then
		Hover.Close(f)
		return
	end
	if not f.pins then return end
	if kept and kept ~= f then Hover.Close(kept) end
	kept, wing, owner = f, nil, nil
	generation = generation + 1
	f.kept, f.lingering = true, false
	Fill(f, f.content, f.width)
	Stand(f)
	-- It was anchored under the previously kept frame, which is now the spare and will be anchored under
	-- this one when it next opens. Re-place it on its own, or the two would anchor to each other (an error).
	if f.under then Place(f, f.dock or f.owner, f.opts or {}, f.width) end
	if f.opts and f.opts.onKeep then f.opts.onKeep(f, true) end
end

function Hover.Refill(f, content)
	if not f or not f:IsShown() then return end
	if not content then
		Hover.Close(f)
		return
	end
	-- A card sizes itself, as wide as the hover was opened to be at most.
	Fill(f, content, (f.opts and f.opts.width) or (content.title and WIDTH or TIP_WIDTH))
	Stand(f)
end

function Hover.Kept()
	return kept and kept:IsShown() and kept or nil
end

-- True when the hover was kept.
function Hover.Keep(by)
	if not (wing and wing:IsShown() and owner == by and wing.pins) then return false end
	Keep(wing)
	return true
end

-- Beside and Stay: display-only frames (no foot, no keeping) that the caller shows and hides, for
-- comparison tooltips and for links clicked in chat. (`staying` is with Place: hovers slot round them.)

local function Picture(f, content, opts)
	local width = opts.width or (content.title and WIDTH or TIP_WIDTH)
	f.owner, f.dock, f.opts, f.key = nil, nil, opts, nil
	f.keeps, f.pins, f.kept, f.lingering, f.footNow = false, false, false, false, 0
	f:EnableMouse(false)
	f:SetWidth(width)
	Fill(f, content, width)
	Stand(f)
	return width
end

-- The side with room; "RIGHT" when the frame can't be measured (restricted or secret).
local function Roomy(of, need)
	local ok, left, right = pcall(function() return of:GetLeft(), of:GetRight() end)
	if not ok or issecretvalue(left) or issecretvalue(right) or not left or not right then return "RIGHT" end
	local unit = of:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local roomLeft, roomRight = left * unit, (UIParent:GetWidth() or 0) - right * unit
	return (roomRight >= need or roomRight >= roomLeft) and "RIGHT" or "LEFT"
end

function Hover.Beside(index, content, opts)
	opts = opts or {}
	local f = beside[index]
	local of = opts.of or wing
	if not content or not (of and of:IsShown()) then
		if f then
			f:Hide()
			f.content, f.of = nil, nil
		end
		return nil
	end
	if not f then
		f = Build()
		beside[index] = f
	end
	local width = Picture(f, content, opts)
	local scale = of:GetScale()
	f.of = of
	f:SetScale(scale)
	f:ClearAllPoints()
	-- The second goes past the first; the first on the side with room for all of them.
	local first, to = beside[1], of
	if first and first ~= f and first:IsShown() and first.of == of then
		to, f.side = first, first.side
	else
		f.side = Roomy(of, (width + 2) * (opts.count or 1) * scale)
	end
	if f.side == "LEFT" then
		f:SetPoint("TOPRIGHT", to, "TOPLEFT", -2, 0)
	else
		f:SetPoint("TOPLEFT", to, "TOPRIGHT", 2, 0)
	end
	f.rising = of.rising   -- fades in with its host
	f:SetAlpha(of.rising and of:GetAlpha() or 1)
	Stack(f)
	f:Show()
	return f
end

-- Takes no clicks except on its close button.
function Hover.Stay(id, content, opts)
	local f = staying[id]
	if not content then
		if f and f:IsShown() then
			Alone(f)
			f:Hide()
			f.content = nil
		end
		return nil
	end
	opts = opts or {}
	if not f then
		f = Build()
		f.stays = true
		staying[id] = f
		local x = CreateFrame("Button", nil, f)
		x:SetSize(16, 16)
		x:SetPoint("TOPRIGHT", -4, -3)
		x.text = Words(x, 15, C.dim, true)
		x.text:SetPoint("CENTER", 0, 0)
		x.text:SetText("\195\151")
		x:SetScript("OnEnter", function(self) UI.Ink(self.text, C.hot) end)
		x:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
		x:SetScript("OnClick", function()
			local close = f.opts and f.opts.onClose
			if close then close(f) end
		end)
		f.x = x
	end
	local fresh = not f:IsShown()
	local width = Picture(f, content, opts)
	f.x:SetShown(opts.onClose ~= nil)
	if opts.at then
		Place(f, UIParent, opts, width)
	else
		f:SetScale(opts.scale or 1)
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER")
	end
	if fresh then
		f.rising = 0
		f:SetAlpha(0)
	end
	Stack(f)
	f:Show()
	return f
end

function Hover.Staying(id)
	local f = staying[id]
	return f and f:IsShown() and f or nil
end

-- Tip, Attach and Lines

function Hover.Tip(by, title, text, opts)
	opts = opts or {}
	return Hover.Show(by, { strip = title, color = opts.color, note = opts.note, text = text, sections = opts.sections, hints = opts.hints },
		{ side = opts.side, at = opts.at, gap = opts.gap, width = opts.width, keep = false })
end

function Hover.Attach(frame, title, text, opts)
	frame:HookScript("OnEnter", function(self)
		local name, says = title, text
		if type(name) == "function" then name = name(self) end
		if type(says) == "function" then says = says(self) end
		if not name then return end
		Hover.Tip(self, name, says, opts)
	end)
	frame:HookScript("OnLeave", function(self) Hover.Hide(self) end)
end

local LinesMixin = {}
LinesMixin.__index = LinesMixin

function LinesMixin:AddLine(text, r, g, b, wrap)
	self[#self + 1] = { text = text or "", color = r and { r, g, b } or nil, wrap = wrap }
end

function LinesMixin:AddDoubleLine(left, right, r, g, b, r2, g2, b2)
	self[#self + 1] = { text = left or "", right = right, color = r and { r, g, b } or nil, rightColor = r2 and { r2, g2, b2 } or nil }
end

-- GameTooltip-compatible.
function LinesMixin:SetText(text, r, g, b)
	self:AddLine(text, r, g, b)
end

function LinesMixin:NumLines() return #self end
function LinesMixin:Show() end

function Hover.Lines()
	return setmetatable({}, LinesMixin)
end

-- First line: strip (its right text: the note). A blank line starts a section, a heading (Hover.Heading) one with
-- that title. Three leading spaces: one indent.
function Hover.FromLines(lines, opts)
	opts = opts or {}
	local content = { strip = opts.strip, note = opts.note, hints = opts.hints, sections = {} }
	local section
	for index, line in ipairs(lines) do
		local text = line.text
		if index == 1 and not content.strip then
			content.strip = UI.PlainText and UI.PlainText(text) or text
			content.note = content.note or (line.right ~= "" and line.right or nil)
		elseif text == " " or text == "" then
			section = nil
		elseif not line.right and Hover.Headed(text) then
			section = { title = text, rows = {} }
			content.sections[#content.sections + 1] = section
		else
			if not section then
				section = { rows = {} }
				content.sections[#content.sections + 1] = section
			end
			local blanks = #text:match("^ *")
			local words = text:sub(blanks + 1)
			local seat, rest = Hover.Lead(words)
			section.rows[#section.rows + 1] = Hover.Tally({ text = rest or words, seat = seat, indent = math.floor(blanks / 3), color = line.color,
				right = line.right, rightColor = line.rightColor })
		end
	end
	return content
end

function Hover.ShowLines(by, lines, opts)
	opts = opts or {}
	local content = Hover.FromLines(lines, opts)
	content.color = opts.color
	return Hover.Show(by, content, { side = opts.side, gap = opts.gap, dock = opts.dock, width = opts.width or WIDTH, keep = false })
end
