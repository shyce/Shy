-- Shy.Notices: the head of the column at the top's middle. One row: a steel circle at the left end of a
-- plate. The circle is the head's voice (your level by default, a guide's arrow while it points, and for a
-- moment whatever just happened); the plate says what that is; the notices live at the plate's right end,
-- the errors' alarm running into its point. It fits what it says: the plate glides wider or narrower and
-- its words stand on the same baselines whatever is written.
--
--   Shy.Notices.Post(id, {
--       order = 10,                         -- lower stands further left
--       icon = "Interface\\...\\Glyph",     -- white art, tinted with `color`
--       glyph = "note",                     -- or one of Shy.Hover.GLYPHS in its place
--       color = Shy.UI.colors.bad,          -- a palette table, { r, g, b } or a function
--       fill = { r, g, b },                 -- optional: an alarm. Its sign stands in a ring and its stretch of
--                                           -- the plate is the hatch in this color, running into its point
--       count = 3,                          -- or text = "Full": what stands after the sign
--       title = "Errors",                   -- the hover's head, and its heading in the list
--       says = "Click opens ...",           -- the hover's line: what a click and a right-click do (or a function)
--       note = "12 in all",                 -- optional: the hover's note (or a function)
--       sections = { { rows = { ... } } },  -- optional: Shy.Hover's sections under the line (or a function)
--       rows = { ... },                     -- optional: what it is about, one row each (or a function); a click
--                                           -- then opens the list (see "The list") unless `click` is given
--       click = function(button) end,       -- left click
--       menu = function(root) end,          -- right click: entries written as UI.ContextMenu's
--       hold = 12,                          -- optional: it stands this many seconds after it was last posted, then
--                                           -- slides up out of the plate and is cleared (the mouse on the head, or
--                                           -- its list open, keeps it meanwhile); without it, it stays until cleared
--       gone = function() end,              -- optional: it left by itself (its owner forgets what it counted)
--   })                                      -- posted again, it replaces the notice; a higher count lights it once
--   Shy.Notices.Clear(id)
--   Shy.Notices.Get(id)                     -- the notice as posted, or nil
--   Shy.Notices.List()                      -- ids, in the order they stand
--   Shy.Notices.Open(id) / Close() / IsOpen()   -- the list
--   Shy.Notices.Shown()                     -- the list as laid: { { id, label = text, rows = { row, ... } }, ... }
--
--   Shy.Notices.Voice(id, {                 -- the circle and the plate's words, while this is the voice up
--       priority = 10,                      -- the highest speaks (your level, the head's own, is 0)
--       hold = 3,                           -- optional: it speaks this many seconds, then goes by itself
--       seat = function(frame, over) end,   -- optional: draws its own in the circle, on a frame of the
--                                           -- circle's size made for it once (shown only while it speaks);
--                                           -- over: one of the same size above the ring and the level's arc,
--                                           -- for a mark that stands on the rim
--       icon = file, glyph = name | file,   -- or a picture (round) or a sign in the circle, in the arrow's
--                                           -- make: ring, weave, the light in its middle and the sign in the
--                                           -- voice's color's light. A head sign (Shy.Top.Make.SIGNS: news, go,
--                                           -- talk, full, level, alert, bug) fills the face; a hover glyph's
--                                           -- name or a file drawn for 24 units stands at that size
--       lamp = color,                       -- optional: the circle in this color's light instead
--       fill = color, share = 0.6,          -- optional: the plate is this color's weave, drained to `share`;
--                                           -- a bar, as long as its own words, never a line's said before it
--       pulse = true,                       -- optional: the circle's glow and the plate's light beat
--       color = { r, g, b },                -- the sign's, its glow's and the plate's light
--       count = "2",                        -- optional: small under the sign
--       arc = true,                         -- your level's progress round the circle while it speaks
--       title = "...", titleColor = color,  -- the plate's words (a function returning text is read each frame)
--       under = "...", underColor = color,
--       right = "38s",                      -- optional: at the end of the title's line, in its make (a time left)
--       busy = true,                        -- optional (or a function, read each frame): what it says is still being
--                                           -- worked out. A comet of its light runs round the circle's ring, a glow
--                                           -- breathes behind it, and what is in the circle and the line under the
--                                           -- title go quiet, as a guess. Once done, the whole ring flares and all
--                                           -- comes back. Done within a moment, nothing shows
--       click = function(button) end,       -- optional: a click on the circle or the plate
--       menu = function(root) end,          -- optional: its right click
--       hover = function(owner) end,        -- optional: its hover
--   })                                      -- posted again it is updated in place; nil puts it away
--   Shy.Notices.Speaking()                  -- the id of the voice up now
--   Shy.Notices.Plate()                     -- the head's plate (a frame), for what floats beside it
--   Shy.Notices.Fits(under)                 -- whether a line, as a voice's `under`, fits the plate's words
--                                           -- whole (past WIDEST the game cuts it short)
--   Shy.Notices.Headline(def)               -- { name, land, area, color, alpha, side }: a zone's name takes
--                                           -- the plate's words for a while (larger); nil gives them back
--
--   A row: { icon = file, glyph = name, tint = color (a glyph's), text, color (its words; an item's
--   quality), quality, right = "x2", rightColor, indent = 1, link = hyperlink, spell = spellID,
--   click = function(row) end }.
--   Hovered, a row with a link or a spell shows the game's own tooltip for it (the item's or spell's card);
--   Shift-click puts it in the chat line; right-click is its notice's menu; a click runs its `click`,
--   the list closing first.
--
-- Bus: SHY_NOTICES (how many) when a notice is posted or cleared; SHY_HEAD once the head is made (what
-- floats beside it, Shy.Top.Graveyard, is seated then).
--
-- The look is the column's own (Shy.Top.Make): the plaque on its soft shadow at the hovers' strength,
-- pointed at its right end and begun under the circle; a light along its top; the steel ring; the weave.
-- The box is as wide as the plate and the circle's half either side, so the plate stands on the axis and the
-- circle hangs off its left end. Every measure is a whole number of screen pixels at the box's size. In a
-- fight nothing glides or fades: the head is put as it should be at once.
--
-- The list: a click on a notice with rows opens them in the head's drawer (Shy.Top), cells of its tray as the
-- game's messages are, each notice's under a heading in its color. It goes with another click, or once the
-- mouse has been off it and the head LINGER seconds.

local Shy = Shy
local HUD, UI, B, Theme = Shy.HUD, Shy.UI, Shy.Brand, Shy.Theme
local C = UI.colors
local MEDIA = Shy.MEDIA

local N = {}
Shy.Notices = N

-- The head
local CIRCLE = 46           -- the circle across: the box's height
local FACE = 56             -- Dial's art, drawn 46 across in a 56 canvas
local TALL = 34             -- the plate, centred on the circle
local PLATE_Y = (CIRCLE - TALL) / 2
local R = CIRCLE / 2
local INSET = 10            -- from the circle's edge to the words
local LIGHT = 12            -- the light along the plate's top
local END = 12              -- from the last words or sign to the plate's end
local TITLE, UNDER, BIG = 14, 10, 17
local SMALL, LEADING = 12, 1.2  -- the words of a long line with nothing under them: their size, and a line's step as a share of it
local WIDEST = 300          -- the most room the plate's words take; longer are cut short
local LEAST = 120           -- the plate's words never narrower
-- Baselines. The game makes a line as tall as its size and puts the baseline at the font's ascender share
-- of it: Lilita One's 0.923 / (0.923 + 0.220), Nunito ExtraBold's 1.011 / (1.011 + 0.353). Capitals stand
-- about 0.7 of the size over the baseline. The two lines are a block centred on the plate.
local TITLE_SHARE = 0.923 / (0.923 + 0.220)
local NAME_SHARE = 1.011 / (1.011 + 0.353)
local CAPS = 0.70
local BETWEEN = 5           -- from the title's baseline to the top of the line under it
local BESIDE = 12           -- from the title to what stands at the end of its line, at the least
-- Notices at the right end
local GLYPH, SPACE, FONT = 12, 4, 12
local GAP = 14              -- between two notices
local SEP = 9               -- from the words to the hairline before the notices, and from it on
local RING, RING_FACE = 24, 29
-- The arc: SpinnerTrack (128 texels) at its own two texels a unit; its ring, 0.727 of it across, then lies
-- on the circle's steel ring, which lights along the share of your level done.
local ARC = 64
-- A sign in the circle is in the arrow's make, whatever it says (a word of news, an error, breath running
-- out), so the circle reads the same from one voice to the next: the head's own signs fill its face
-- (Shy.Top.Make.Sign: HeadSigns, drawn for 44 units), anything else stands at SIGN (Hover's large glyphs are
-- drawn for it). The light in its middle is the arrow's: BEAM of the circle across, at BEAM_ALPHA; a count
-- under an emblem stands on the ring, COUNT_AT right of and under the middle.
local SIGN = Shy.Top.Make.SIGN
local BEAM, BEAM_ALPHA = 0.8, 0.35
local COUNT_AT = 15
-- A picture in the circle fills its face (41 across, inside the ring's dark line), an icon's square frame
-- cut away on each side so its art fills the round.
local PICTURE, ZOOM = 40, 0.08
-- Motion
local GLIDE, FADE, SPEAK = 0.18, 0.15, 0.15
local FLARE = 0.7           -- seconds a new notice's light takes, up and down
local PULSE, SWELL = 1.1, 0.4   -- a beating voice: seconds a beat, and the share of it its swell takes
local REST, HOT = 0.7, 1    -- a light's alpha at rest and under the mouse
local EVERY = 0.25          -- seconds between reading where you are
-- A voice's `busy` in the circle: the spinner's comet at the arc's size, so it runs on the steel ring. Seconds
-- before it shows, to come and go, a turn, a breath of the glow behind it, and the flare once done; what is in the
-- circle and the line under the title meanwhile (their alpha). state: nil, "wait", "spin" or "flare"; at: when it
-- came to that; k: how far in it stands (0 to 1), as last put.
local BUSY = { wait = 0.3, fade = 0.3, turn = 1.4, breath = 2.2, flare = 0.7, inside = 0.55, guess = 0.5, at = 0, k = 0, lit = 0 }
-- A notice whose time is up: seconds its slide up out of the plate takes, how far it rises (the plate cuts it off
-- at its top), and how much longer the mouse on the head keeps it.
local LEAVE, RISE, GRACE = 0.3, 14, 2
local BUG = "bug"                               -- the errors' sign in the circle (a head sign)
local BUG_SMALL = MEDIA .. "GlyphBugSmall"      -- ... and as a notice (drawn for GLYPH)
local CRIMSON = Theme.COMBO[#Theme.COMBO]
local WHITE = { 1, 1, 1 }
-- The list: the least and the most its rows' words are given
local LIST_LEAST, LIST_MOST = 200, 300
local LINGER = 0.6
local OPEN = 0.12

local notices, order = {}, {}
local box, housing, plaque, strip, medal
local cells = {}             -- id -> its button
local voices = {}            -- id -> def
local speaking               -- the id of the voice up now
local glide = { from = 0, to = 0, at = 0, w = 0 }   -- the plate's width, gliding (see "The plate")
local headline               -- { name, land, area, color } while a zone's name has the plate's words
local list, opened
local laid = {}

local function Quiet() return InCombatLockdown() end

local function Sort()
	wipe(order)
	for id in pairs(notices) do order[#order + 1] = id end
	table.sort(order, function(a, b)
		local x, y = notices[a].order or 50, notices[b].order or 50
		if x ~= y then return x < y end
		return a < b
	end)
end

-- Screen pixels per box unit, and a measure put on whole pixels.
local function PerPixel()
	local _, high = GetPhysicalScreenSize()
	local scale = box and box:GetScale() or 1
	return high / UIParent:GetHeight() * scale
end

local function Px(v, ppu)
	return math.max(1, math.floor(v * ppu + 0.5)) / ppu
end

local function Value(v, ...)
	if type(v) == "function" then return v(...) end
	return v
end

local function Hue(color)
	if type(color) == "function" then return color() end
	return color[1], color[2], color[3]
end

local function Rows(def)
	local rows = def and Value(def.rows, def)
	if type(rows) ~= "table" or #rows == 0 then return nil end
	return rows
end

local function Words(parent, font)
	return UI.Words(parent, font, nil, { wrap = false })
end

-- A width the string needs, or `none` where the game keeps it secret.
local function Width(fs, none)
	local w = fs:GetStringWidth()
	if w == nil or issecretvalue(w) then return none end
	return w
end

-- The same words with every digit a 0 (pictures and atlases in them kept as they are), so a number that
-- changes as you walk ("56.6, 67.3") measures the same each time.
local function Zeroed(text)
	local keep = {}
	text = text:gsub("|[TA].-|[ta]", function(e)
		keep[#keep + 1] = e
		return "\001"
	end)
	text = text:gsub("%d", "0")
	local i = 0
	return (text:gsub("\001", function()
		i = i + 1
		return keep[i]
	end))
end

-- How wide the plate's words stand: measured with their digits as 0s, given FIT, then up to a whole STEP,
-- so the plate (and every row of the column laid at its width) stays put while a number in it counts.
-- FIT: the game cuts a line short with an ellipsis when its box is no wider than its own measure (the
-- shadow and the pixel grid take a little), so a line is always given this much past it.
local STEP, FIT = 8, 4
local function Steady(fs, none)
	local text = fs:GetText()
	if text == nil or issecretvalue(text) then return Width(fs, none) end
	fs.ruler = fs.ruler or fs:GetParent():CreateFontString(nil, "BACKGROUND")
	local ruler = fs.ruler
	ruler:Hide()
	ruler:SetFontObject(fs:GetFontObject())
	ruler:SetText(Zeroed(text))
	local w = Width(ruler, none)
	return w and math.ceil((w + FIT) / STEP) * STEP or w
end

-- Words that can't be compared (the game keeps them secret) are taken as new.
local function Same(a, b)
	if issecretvalue(a) or issecretvalue(b) then return false end
	return a == b
end

local Make = Shy.Top.Make
local Plaque, Shape, Look, Hatch, Ring = Make.Plaque, Make.Shape, Make.Look, Make.Hatch, Make.Ring

-- Puts a line of `size` so its baseline is `base` under the plate's top, starting `x` in from its left.
local function Seat(fs, size, share, x, base)
	fs:SetHeight(size)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", strip, "TOPLEFT", x, -(base - size * share))
end

-- The notices at the plate's right end

local Toggle

-- One notice's button: a sign (in a ring for an alarm), a count; its stretch of the light and of the hatch.
local function Cell(id)
	local b = CreateFrame("Button", nil, strip)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.light = strip:CreateTexture(nil, "ARTWORK")
	b.light:SetTexture(MEDIA .. "HoverLight")
	b.light:SetHeight(LIGHT)
	b.light:SetAlpha(REST)
	-- (Over the plate's own textures, its weave among them: its ring, sign and count stand on the weave.)
	b:SetFrameLevel(strip:GetFrameLevel() + 1)
	b.hatch = Hatch(strip, strip.mask, true)
	b.hatch:Hide()
	b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 2)
	b.glow:SetTexture(B.GLOW)
	b.glow:SetAlpha(0)
	b.ring = Ring(b)
	b.ring:SetSize(RING_FACE, RING_FACE)
	b.glyph = b:CreateTexture(nil, "OVERLAY")
	UI.Concentric(b.ring, b.glyph, b.glow)
	b.words = Words(b, UI.NameFont(FONT))
	b.id = id
	HUD.Manage(box, b, false)
	b:SetScript("OnClick", function(self, button)
		if HUD.WasDragged(box) then return end
		local def = notices[self.id]
		if not def then return end
		UI.TipHide(self, true)
		if button == "RightButton" then
			if def.menu then
				UI.ContextMenu(self, function(root)
					if def.title then root:CreateTitle(def.title) end
					def.menu(root)
				end)
			end
		elseif def.click then
			def.click(self)
		elseif Rows(def) then
			Toggle(self.id)
		end
	end)
	b:SetScript("OnEnter", function(self)
		local def = notices[self.id]
		if not def then return end
		self.hot = true
		self.light:SetAlpha(HOT)
		self.glow:SetAlpha(self.lit and self.glow:GetAlpha() or 0.3)
		-- (The list says it all while it is open; nothing pops up while the column is in hand.)
		if (list and list:IsShown()) or HUD.InHand() then return end
		UI.Tip(self, def.title or "", Value(def.says, def), { side = "BOTTOM", note = Value(def.note, def),
			sections = Value(def.sections, def) })
	end)
	b:SetScript("OnLeave", function(self)
		self.hot = false
		self.light:SetAlpha(self.open and HOT or REST)
		if not self.lit then self.glow:SetAlpha(0) end
		UI.TipHide(self)
	end)
	return b
end

-- How wide a notice stands: its sign (or ring) and the words after it.
local function Dress(b, def, ppu)
	local fill = def.fill
	local glyph = Px(GLYPH, ppu)
	if def.glyph then
		Shy.Hover.Glyph(b.glyph, def.glyph, glyph)
	else
		b.glyph:SetTexture(def.icon or BUG_SMALL)
		b.glyph:SetTexCoord(0, 1, 0, 1)
	end
	b.glyph:SetSize(glyph, glyph)
	UI.Tint(b.glyph, fill and C.text or def.color or C.text)
	UI.Tint(b.glow, def.color or C.text)
	UI.Tint(b.light, fill or def.color or C.text)
	-- (An alarm's count stands on its weave: white, as the alert's words are.)
	UI.Ink(b.words, fill and WHITE or C.text)
	b.ring:SetShown(fill ~= nil)
	b.hatch:SetShown(fill ~= nil)
	if fill then
		UI.Tint(b.ring, Theme.skin.metal)
		UI.Tint(b.hatch, fill, 0.85)
	end
	local words = def.count ~= nil and tostring(def.count) or def.text or ""
	b.words:SetText(words)
	local width = fill and Px(RING, ppu) or glyph
	if words ~= "" then width = width + Px(SPACE, ppu) + math.ceil(Width(b.words, 8) * ppu) / ppu end
	return width
end

-- The circle

-- The circle's own pieces: the steel ring, the level's arc, and what a voice puts in it.
local function Medal()
	local m = CreateFrame("Button", nil, box)
	m:SetSize(CIRCLE, CIRCLE)
	m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	m.glow = m:CreateTexture(nil, "BACKGROUND", nil, -6)
	m.glow:SetTexture(B.GLOW)
	m.glow:SetPoint("CENTER")
	m.glow:SetSize(CIRCLE * 1.6, CIRCLE * 1.6)
	m.glow:SetAlpha(0)
	m.face = m:CreateTexture(nil, "ARTWORK")
	m.face:SetTexture(MEDIA .. "Dial")
	m.face:SetSize(FACE, FACE)
	m.face:SetPoint("CENTER")
	UI.Tint(m.face, Theme.skin.metal)
	-- The level's arc: the spinner's faint ring as its track, and a paused swipe of it lit to the share done.
	m.track = m:CreateTexture(nil, "ARTWORK", nil, 1)
	m.track:SetTexture(MEDIA .. "SpinnerTrack")
	m.track:SetSize(ARC, ARC)
	m.track:SetPoint("CENTER")
	UI.Tint(m.track, Theme.skin.metal, 0.35)
	m.arc = CreateFrame("Cooldown", nil, m)
	m.arc:SetSize(ARC, ARC)
	m.arc:SetPoint("CENTER")
	m.arc:SetSwipeTexture(MEDIA .. "SpinnerTrack")
	m.arc:SetDrawEdge(false)
	m.arc:SetDrawBling(false)
	m.arc:SetHideCountdownNumbers(true)
	m.arc:SetReverse(true)
	-- What a voice puts in it: everything over the face, faded in together as a voice begins.
	m.inside = CreateFrame("Frame", nil, m)
	m.inside:SetAllPoints()
	m.inside:SetFrameLevel(m.arc:GetFrameLevel() + 2)
	-- (Its letters on the circle's middle: seated by Theme.Centre whenever they or what they wear change.)
	m.level = Words(m.inside, UI.TitleFont(19))
	m.level:SetPoint("CENTER", 0, 0)
	m.sign = m.inside:CreateTexture(nil, "OVERLAY")
	m.sign:SetPoint("CENTER")
	m.picture = m.inside:CreateTexture(nil, "ARTWORK", nil, 2)
	m.picture:SetSize(PICTURE, PICTURE)
	m.picture:SetPoint("CENTER")
	m.round = m.inside:CreateMaskTexture()
	m.round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	m.round:SetAllPoints(m.picture)
	m.picture:AddMaskTexture(m.round)
	-- Under a sign, the arrow's make: the bars' weave as a disc of the face's size (PICTURE) on the dark face,
	-- and a soft light in its middle.
	m.weave = m.inside:CreateTexture(nil, "ARTWORK", nil, 1)
	m.weave:SetTexture(MEDIA .. "HatchDisc" .. PICTURE)
	m.weave:SetAllPoints(m.picture)
	m.weave:Hide()
	m.beam = m.inside:CreateTexture(nil, "ARTWORK", nil, 2)
	m.beam:SetTexture(B.GLOW)
	m.beam:SetSize(CIRCLE * BEAM, CIRCLE * BEAM)
	m.beam:SetPoint("CENTER")
	m.beam:Hide()
	m.count = Words(m.inside, UI.NameFont(10))
	m.count:SetJustifyH("CENTER")
	UI.Concentric(m.glow, m.face, m.track, m.sign, m.picture, m.weave, m.beam)
	m.seats = {}
	-- The look's border round the circle, over whatever a voice seats in it (a seat draws its own rim).
	m.rim = CreateFrame("Frame", nil, m)
	m.rim:SetAllPoints()
	m.rim:SetFrameLevel(m.inside:GetFrameLevel() + 2)
	m.look = UI.LookRing(m.face, CIRCLE, m.rim)
	-- The level's arc runs along the circle's rim: over the look's ring where the look has one, so it still reads.
	local arcLevel = m.arc:GetFrameLevel()
	function m:Arc()
		local kind = UI.LOOK_KINDS[Theme.Look()]
		self.arc:SetFrameLevel((kind and kind.ring) and self.rim:GetFrameLevel() + 1 or arcLevel)
	end
	m:Arc()
	-- Over the rim and the arc both: what a seat stands on the ring (its `over`), faded in with the inside.
	m.over = CreateFrame("Frame", nil, m)
	m.over:SetAllPoints()
	m.over:SetFrameLevel(m.rim:GetFrameLevel() + 2)
	m.overs = {}
	-- A voice's busy (BUSY): a comet on the ring, over the look's rim as the arc is; the ring lit whole for the
	-- flare; a glow behind the circle.
	local b = CreateFrame("Frame", nil, m)
	b:SetAllPoints()
	b:SetFrameLevel(m.rim:GetFrameLevel() + 1)
	b.glow = m:CreateTexture(nil, "BACKGROUND", nil, -5)
	b.glow:SetTexture(B.GLOW)
	b.glow:SetPoint("CENTER")
	b.glow:SetSize(CIRCLE * 1.9, CIRCLE * 1.9)
	b.glow:SetAlpha(0)
	b.ring = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.ring:SetTexture(MEDIA .. "SpinnerTrack", nil, nil, "TRILINEAR")
	b.ring:SetSize(ARC, ARC)
	b.ring:SetPoint("CENTER")
	b.ring:SetBlendMode("ADD")
	b.comet = CreateFrame("Frame", nil, b)
	b.comet:SetAllPoints()
	local turning = {}
	for i, part in ipairs({ "Arc", "Head" }) do
		local t = b.comet:CreateTexture(nil, "ARTWORK", nil, i + 1)
		t:SetTexture(MEDIA .. "Spinner" .. part, nil, nil, "TRILINEAR")
		t:SetSize(ARC, ARC)
		t:SetPoint("CENTER")
		if part == "Head" then UI.Tint(t, Theme.light, 0.9) end
		b[part:lower()] = t
		local group = t:CreateAnimationGroup()
		local turn = group:CreateAnimation("Rotation")
		turn:SetDegrees(-360)
		turn:SetDuration(BUSY.turn)
		group:SetLooping("REPEAT")
		turning[i] = group
	end
	-- (Both started together, of one length: the spark stays on the head.)
	b:SetScript("OnShow", function()
		for _, group in ipairs(turning) do group:Play() end
	end)
	b:SetScript("OnHide", function()
		for _, group in ipairs(turning) do group:Stop() end
	end)
	b:Hide()
	m.busy = b
	return m
end

-- Your level's progress round the circle: a paused swipe lit to the share done (none at the top level).
local function Arc(on)
	local m = medal
	local max = UnitXPMax("player")
	local level, top = UnitLevel("player"), GetMaxLevelForPlayerExpansion()
	local share = (max and max > 0 and not issecretvalue(max)) and (UnitXP("player") / max) or nil
	local show = on and share ~= nil and level < top
	m.track:SetShown(show)
	m.arc:SetShown(show)
	if not show then return end
	m.arc:SetSwipeColor(Theme.Accent())
	-- (A swipe over a thousand seconds, the share of them gone, held there.)
	m.arc:SetCooldown(GetTime() - share * 1000, 1000)
	m.arc:Pause()
end

-- The voices

local function Current()
	local best, at = nil, -math.huge
	local now = GetTime()
	for id, def in pairs(voices) do
		if def.untilAt and now >= def.untilAt then
			voices[id] = nil
		elseif (def.priority or 0) > at then
			best, at = id, def.priority or 0
		end
	end
	return best
end

local Lay, Show

-- What the circle holds for this voice.
local function Fill(m, id, def)
	for sid, seat in pairs(m.seats) do seat:SetShown(sid == id) end
	for sid, over in pairs(m.overs) do over:SetShown(sid == id) end
	m.level:Hide()
	m.sign:Hide()
	m.picture:Hide()
	m.weave:Hide()
	m.beam:Hide()
	UI.Tint(m.face, Theme.skin.metal)
	m.look:Plain(true)
	strip.light:SetAlpha(1)
	-- The plate's weave: a voice's fill, drained to its share.
	strip.drain:SetShown(def.fill ~= nil)
	if def.fill then
		UI.Tint(strip.drain.fill, def.fill, 1)
		strip.drain:Share(def.share or 1)
	end
	m.count:SetShown(def.count ~= nil)
	m.count:SetText(def.count or "")
	m.count:ClearAllPoints()
	m.count:SetPoint("CENTER", 0, -11)
	if def.seat then
		local seat = m.seats[id]
		if not seat then
			seat = CreateFrame("Frame", nil, m.inside)
			seat:SetAllPoints()
			m.seats[id] = seat
			local over = CreateFrame("Frame", nil, m.over)
			over:SetAllPoints()
			m.overs[id] = over
			def.seat(seat, over)
		end
		seat:Show()
		m.overs[id]:Show()
	elseif def.level then
		m.level:SetText(def.level)
		Theme.Centre(m.level, m.inside)
		m.level:Show()
	elseif def.icon then
		m.picture:SetTexture(def.icon)
		m.picture:SetTexCoord(ZOOM, 1 - ZOOM, ZOOM, 1 - ZOOM)
		m.picture:Show()
	elseif def.glyph then
		-- Every sign in the arrow's make: the ring, the weave and the light in its middle in the voice's
		-- color's light (or the `lamp` it names), the sign in it too. One make for news, an error, an alarm.
		local light = Make.Light(def.lamp or def.color or Theme.Accent)
		local size = Make.Sign(m.sign, def.glyph)
		m.sign:SetSize(size, size)
		m.sign:ClearAllPoints()
		m.sign:SetPoint("CENTER", 0, (def.count and size == SIGN) and 6 or 0)
		UI.Tint(m.sign, light)
		m.sign:Show()
		UI.Tint(m.face, light)
		-- (A meaning's color is the rim's to carry: the look's ring stands down for it.)
		local meant = def.lamp or def.color
		m.look:Plain(meant == nil or meant == Theme.Accent or meant == C.hot)
		Shy.Skin.WeaveTint(m.weave, light)
		m.weave:Show()
		UI.Tint(m.beam, light, BEAM_ALPHA)
		m.beam:Show()
		-- (An emblem fills the face: the count stands on the ring at its lower right.)
		if size ~= SIGN then
			m.count:ClearAllPoints()
			m.count:SetPoint("CENTER", COUNT_AT, -COUNT_AT)
		end
	end
	UI.Tint(m.glow, def.color or Theme.Accent)
	m.glow:SetAlpha(def.icon and 0.45 or 0)
	Arc(def.arc == true)
end

-- The voice up now takes the circle and, unless a headline has them, the plate's words.
local function Speak(force)
	if not medal then return end
	local id = Current()
	local def = id and voices[id]
	if id ~= speaking or force then
		-- (Another voice: nothing of the last one's busy stays.)
		if id ~= speaking then
			BUSY.state = nil
			BUSY.Put(0, 0, GetTime())
		end
		speaking = id
		if def then Fill(medal, id, def) end
		medal.inside.at = Quiet() and nil or GetTime()
		medal.inside:SetAlpha(Quiet() and 1 or 0)
		medal.over:SetAlpha(Quiet() and 1 or 0)
		if Lay then Lay() end
	end
end

-- The plate's words now: a headline's, else the voice's (and what stands at the end of its title's line).
local function Said()
	if headline then
		local under = headline.land and headline.area and (headline.land .. "  ·  " .. headline.area) or headline.land or headline.area or ""
		return headline.name or "", under, C.text, C.head, headline.color, true, ""
	end
	local def = speaking and voices[speaking]
	if not def then return "", "", C.text, C.head, Theme.Accent, false, "" end
	return Value(def.title, def) or "", Value(def.under, def) or "", def.titleColor or C.text, def.underColor or C.head,
		def.color or Theme.Accent, false, def.right or ""
end

-- The plate

-- The plate's words and notices laid out, the box sized to them: the plate as wide as its words (never
-- under LEAST, never over WIDEST for the words) and its notices, on whole pixels, an even count of them so
-- its middle is on one. Everything in the plate is set from its left end (the words) or its right end (the
-- notices and the alarm), so it stands still while the width glides, and a plate laid wider than its own
-- words need (the column's width, cells in its drawer) keeps its notices together at its end.

local function Ease(u) return 1 - (1 - u) ^ 3 end

local function Settle()
	glide.w, glide.from = glide.to, glide.to
	strip:SetWidth(glide.w)
end

local function Aim(width)
	glide.from, glide.to, glide.at = glide.w, width, GetTime()
	if Quiet() or not box:IsShown() or glide.w <= 1 then Settle() end
end

-- The box sits where the column puts it, which is seldom on a pixel: the plate is set off a fraction so
-- its top and its middle are.
local function Snap()
	if not strip then return end
	local ppu = PerPixel()
	local top, middle = box:GetTop(), select(1, box:GetCenter())
	if not top or not middle then return end
	local dy = (math.floor(top * ppu + 0.5) - top * ppu) / ppu
	local dx = (math.floor(middle * ppu + 0.5) - middle * ppu) / ppu
	strip:ClearAllPoints()
	strip:SetPoint("TOP", box, "TOP", dx, dy - PLATE_Y)
end

function Lay()
	if not box then return end
	local ppu = PerPixel()
	local title, under, ink, underInk, light, big, right = Said()
	local size = big and BIG or TITLE
	UI.TitleFace(strip.title, size)
	strip.title:SetShadowOffset(1, -1)
	strip.title:SetShadowColor(0, 0, 0, 1)
	strip.title:SetText(title)
	strip.under:SetText(under)
	UI.Ink(strip.title, ink)
	UI.Ink(strip.under, underInk)
	strip.title:SetWordWrap(false)
	strip.title:SetJustifyV("TOP")
	strip.title:SetWidth(0)
	strip.under:SetWidth(0)
	-- What stands at the end of the title's line (a time left): in the title's make and ink, the title given
	-- the room before it.
	local beside, taken = right ~= "", 0
	strip.right:SetShown(beside)
	if beside then
		UI.TitleFace(strip.right, size)
		strip.right:SetShadowOffset(1, -1)
		strip.right:SetShadowColor(0, 0, 0, 1)
		strip.right:SetText(right)
		UI.Ink(strip.right, ink)
		taken = Px(BESIDE, ppu) + Steady(strip.right, 0)
	end
	local words = math.max(Steady(strip.title, WIDEST) + taken, Steady(strip.under, 0))
	-- Words too long for the plate with nothing under them (an error, a server's line) step down a size
	-- and, if still too long, stand on two lines: the game would cut them short with an ellipsis.
	local lines = 1
	if words > WIDEST and under == "" and not big and not beside then
		size = SMALL
		UI.TitleFace(strip.title, size)
		strip.title:SetWidth(0)
		words = Steady(strip.title, WIDEST)
		if words > WIDEST then
			lines = 2
			strip.title:SetWordWrap(true)
			words = math.min(WIDEST, math.max(LEAST, words * 0.6 + 16))
		end
	end
	words = math.ceil(math.min(WIDEST, math.max(LEAST, words)) * ppu) / ppu
	-- (Cut short past WIDEST: the game ends a line too long with an ellipsis.)
	strip.title:SetWidth(words - taken)
	strip.under:SetWidth(words)
	-- The two lines as a block centred on the plate, each on its baseline.
	local x = Px(R + INSET, ppu)
	local titleCaps, underCaps = CAPS * size + (lines - 1) * size * LEADING, (under ~= "") and CAPS * UNDER or 0
	local block = titleCaps + (under ~= "" and BETWEEN + underCaps or 0)
	local base = math.floor(((TALL - block) / 2 + CAPS * size) * ppu + 0.5) / ppu
	-- (An outlined title's letters begin its lead in from its left: set that much to the left, they begin where the
	-- plain line under them does.)
	Seat(strip.title, size, TITLE_SHARE, x - Theme.Lead(strip.title), base)
	if lines > 1 then strip.title:SetHeight(size * LEADING * lines + 2) end
	-- (On the title's baseline, ending where the words do: it stands still as it counts and as the plate glides.)
	if beside then
		strip.right:SetHeight(size)
		strip.right:ClearAllPoints()
		strip.right:SetPoint("TOPRIGHT", strip, "TOPLEFT", x + words, -(base - size * TITLE_SHARE))
	end
	Seat(strip.under, UNDER, NAME_SHARE, x, math.floor((base + BETWEEN + underCaps) * ppu + 0.5) / ppu)
	strip.under:SetShown(under ~= "")
	strip.light:ClearAllPoints()
	strip.light:SetPoint("TOPLEFT", strip, "TOPLEFT", Px(R, ppu), 0)
	strip.light:SetPoint("TOPRIGHT", strip, "TOPLEFT", x + words + Px(6, ppu), 0)
	UI.Tint(strip.light, light or Theme.Accent, 0.85)
	-- The notices at the plate's right end, a hairline before them; the alarm last, at its end.
	local gap, sep = Px(GAP, ppu), Px(SEP, ppu)
	local at = x + words
	local items, alarm = {}, nil
	for _, id in ipairs(order) do
		if notices[id].fill and not alarm then alarm = id else items[#items + 1] = id end
	end
	-- The notices stand at the plate's right end (before the alarm), set from that end as the alarm is: however wide
	-- the plate is laid (the column's width, what hangs in its drawer), they keep together there, the words at its
	-- left and the plate's own room between. How wide each stands is measured first; then each is put `off` in from
	-- the plate's right end, the last nearest it.
	local high = Px(TALL, ppu)
	local used, wide, run = {}, {}, 0
	for i, id in ipairs(items) do
		local b = cells[id] or Cell(id)
		cells[id] = b
		used[id] = true
		wide[i] = Dress(b, notices[id], ppu)
		run = run + wide[i] + (i < #items and gap or 0)
	end
	local alarmWide = 0
	if alarm then
		cells[alarm] = cells[alarm] or Cell(alarm)
		used[alarm] = true
		alarmWide = Dress(cells[alarm], notices[alarm], ppu)
	end
	-- (From the plate's right end to the last notice's: the end's room; with an alarm, which is the plate's end
	-- itself, its stretch and the room before it.)
	local tail = Px(END, ppu)
	if alarm then tail = alarmWide + 2 * Px(END, ppu) - Px(4, ppu) end
	strip.sep:SetShown(#items > 0)
	if #items > 0 then
		strip.sep:ClearAllPoints()
		strip.sep:SetPoint("TOPLEFT", strip, "TOPRIGHT", -(tail + run + sep), -Px(8, ppu))
		strip.sep:SetPoint("BOTTOMLEFT", strip, "BOTTOMRIGHT", -(tail + run + sep), Px(8, ppu))
		at = at + 2 * sep + run
	end
	local off = tail + run
	for i, id in ipairs(items) do
		local b, w = cells[id], wide[i]
		off = off - w
		b.off = off   -- (where it stands, for its slide up as it leaves)
		b:SetAlpha(1)
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -off, 0)
		b:SetSize(w, high)
		b.glyph:ClearAllPoints()
		b.glyph:SetPoint("LEFT", b, "LEFT", 0, 0)
		b.words:ClearAllPoints()
		b.words:SetPoint("LEFT", b.glyph, "RIGHT", Px(SPACE, ppu), 0)
		b.light:ClearAllPoints()
		b.light:SetPoint("TOPLEFT", strip, "TOPRIGHT", -(off + w + Px(3, ppu)), 0)
		b.light:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -(off - Px(3, ppu)), 0)
		local reach = Px(GLYPH * 2.4, ppu)
		b.glow:SetSize(reach, reach)
		b.glow:ClearAllPoints()
		b.glow:SetPoint("CENTER", b.glyph, "CENTER")
		b:Show()
		b.light:Show()
		b.hatch:Hide()
		off = off - (i < #items and gap or 0)
	end
	local width = at + Px(END, ppu)
	if alarm then
		local b, w = cells[alarm], alarmWide
		local start = width - Px(4, ppu)
		width = start + w + Px(END, ppu)
		local ring = Px(RING, ppu)
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -Px(END, ppu), 0)
		b:SetSize(w, high)
		b.ring:ClearAllPoints()
		b.ring:SetPoint("CENTER", b, "LEFT", ring / 2, 0)
		b.glyph:ClearAllPoints()
		b.glyph:SetPoint("CENTER", b.ring, "CENTER")
		b.words:ClearAllPoints()
		b.words:SetPoint("LEFT", b, "LEFT", ring + Px(SPACE, ppu), 0)
		-- The weave from behind the ring to the plate's end: the plate's end cap, inside the plate's own frame as
		-- every fill of a plaque is (Top.Make.FillIn: the frame stands round it whole, in every look), its light
		-- along its top inside the frame too.
		local i = Make.FillIn()
		b.hatch:ClearAllPoints()
		b.hatch:SetPoint("TOPLEFT", b, "TOPLEFT", ring / 2, -i)
		b.hatch:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -i, i)
		b.light:ClearAllPoints()
		b.light:SetPoint("TOPLEFT", b, "TOPLEFT", ring - Px(4, ppu), -i)
		b.light:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -i, -i)
		local reach = Px(GLYPH * 2.4, ppu)
		b.glow:SetSize(reach, reach)
		b.glow:ClearAllPoints()
		b.glow:SetPoint("CENTER", b.ring, "CENTER")
		b:Show()
		b.light:Show()
	end
	for id, b in pairs(cells) do
		if not used[id] then
			b:Hide()
			b.light:Hide()
			b.hatch:Hide()
		end
	end
	-- As wide as the column's widest plate (Shy.Top.Width), so every plate under it ends where it does; an
	-- even count of pixels, so the middle of the plate is on a pixel too. A voice with a weave (breath running
	-- out) is a bar, and a bar is as long as its own words: it takes neither a long line's width said just
	-- before it nor the column's, and asks the column for none, so it reads as a meter and not as a plate
	-- left over, never the length of the note said before it.
	-- With cells hanging in its drawer it is as wide as they need all the same: the drawer is the plate's.
	local voice = speaking and voices[speaking]
	local bar = voice ~= nil and voice.fill ~= nil and not headline and not Shy.Top.Hanging()
	local hung = list ~= nil and list:IsShown()
	local left, right, lip = Shy.Top.Bay()
	if hung then width = math.max(width, list.need + left + right) end
	Shy.Top.Want(box, bar and 0 or width)
	local own = width
	if not bar then width = math.max(width, Shy.Top.Width()) end
	width = math.ceil(width * ppu / 2) * 2 / ppu
	-- A voice with a weave (breath running out): what stands at the end of its line (the time left) hangs from the
	-- bar's right end, right-aligned, so it rides the end as the plate glides wider or narrower (the drawer under it)
	-- and a count growing shorter keeps its last digit where it was.
	if voice ~= nil and voice.fill ~= nil and beside then
		strip.right:ClearAllPoints()
		strip.right:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -(own - x - words), -(base - size * TITLE_SHARE))
	end
	Look(plaque)
	strip:SetHeight(high)
	-- (The box: the plate and the circle's half either side, so the plate stands on the axis.)
	HUD.Resize(box, width + 2 * Px(R, ppu), Px(CIRCLE, ppu))
	Aim(width)
	Snap()
	-- The list in the drawer's bay: from its inner face to its inner face under the plate, flowing with the plate.
	if hung then
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", left, -lip)
		list:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", -right, -lip)
	end
end

-- Shown while anything is posted or a voice speaks (your level always does); faded in as it comes.
function Show()
	if not box then return end
	HUD.Update(box)
	Lay()
end

-- A notice posted with `hold` leaves by itself: once its time is up it slides up out of the plate, fading, and is
-- cleared (at once in a fight); the rest close up to the plate's end.
local leaving = false        -- some notice is on its way out
local function Leave(now)
	leaving = false
	local done
	for id, def in pairs(notices) do
		if def.leaving then
			local u = Quiet() and 1 or math.min(1, (now - def.leaving) / LEAVE)
			local b = cells[id]
			if u >= 1 then
				done = done or {}
				done[#done + 1] = id
			else
				leaving = true
				if b and b.off then
					b:ClearAllPoints()
					b:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -b.off, RISE * u * u)
					b:SetAlpha(1 - u)
					b.light:SetAlpha(REST * (1 - u))
				end
			end
		end
	end
	for _, id in ipairs(done or {}) do
		local gone = notices[id].gone
		N.Clear(id)
		if gone then gone() end
	end
end

-- Whose time is up: it leaves, unless the mouse is on the head or the list is open, which keep it a little longer.
local function Expire(now)
	local held
	for _, def in pairs(notices) do
		if def.untilAt and not def.leaving and now >= def.untilAt then
			if held == nil then held = (list ~= nil and list:IsShown()) or strip:IsMouseOver() or medal:IsMouseOver() end
			if held then
				def.untilAt = now + GRACE
			else
				def.leaving = now
				leaving = true
			end
		end
	end
end

-- A voice's busy, each frame: read, then the circle as it stands. (Fields, not locals: the file's main chunk
-- keeps its locals few.)
function BUSY.Put(k, lit, now)
	local m = medal
	local b = m.busy
	if k > 0 or lit > 0 then
		if not b:IsShown() then b:Show() end
		b.comet:SetAlpha(k)
		-- (The glow behind breathes while it turns: its swell and its fall.)
		local breath = 0.5 + 0.5 * math.sin(2 * math.pi * now / BUSY.breath)
		b.glow:SetAlpha(k * (0.2 + 0.3 * breath) + lit * 0.8)
		b.ring:SetAlpha(lit)
	elseif b:IsShown() then
		b:Hide()
		b.glow:SetAlpha(0)
	end
	if k == BUSY.k then return end
	BUSY.k = k
	-- (The level's arc steps aside for the comet on the same ring.)
	m.track:SetAlpha(1 - k)
	m.arc:SetAlpha(1 - k)
	-- (After a new voice's fade, which sets these.)
	if not m.inside.at then
		m.inside:SetAlpha(1 - (1 - BUSY.inside) * k)
		strip.under:SetAlpha(1 - (1 - BUSY.guess) * k)
	end
end
function BUSY.Step(now, elapsed)
	local def = speaking and voices[speaking]
	local on = def ~= nil and def.busy ~= nil and not headline and Value(def.busy, def) and true or false
	local state = BUSY.state
	if on then
		if state == nil then
			BUSY.state, BUSY.at = "wait", now
		elseif state == "flare" then
			BUSY.state, BUSY.at = "spin", now
		end
		if BUSY.state == "wait" and now - BUSY.at >= BUSY.wait then
			BUSY.state, BUSY.at = "spin", now
			-- (In the voice's light, as its sign and the plate's light are.)
			local r, g, b = Hue(def.color or Theme.Accent)
			UI.Tint(medal.busy.arc, { r, g, b })
			UI.Tint(medal.busy.glow, { r, g, b })
			UI.Tint(medal.busy.ring, { Theme.Hot(r, g, b) })
		end
	elseif state == "wait" then
		BUSY.state = nil
	elseif state == "spin" then
		BUSY.state, BUSY.at = "flare", now
	end
	state = BUSY.state
	-- The comet comes in while it turns and goes as the ring flares; the flare swells and falls.
	local want = state == "spin" and 1 or 0
	local k = BUSY.k
	if Quiet() then
		k = want
	elseif k ~= want then
		k = want > k and math.min(1, k + elapsed / BUSY.fade) or math.max(0, k - elapsed / BUSY.fade)
	end
	local lit = 0
	if state == "flare" then
		local u = (now - BUSY.at) / BUSY.flare
		if u >= 1 then
			BUSY.state = nil
		elseif not Quiet() then
			lit = math.sin(math.pi * u)
		end
	end
	BUSY.Put(k, lit, now)
end

local clock = 0
local function Tick(_, elapsed)
	local now = GetTime()
	if leaving then Leave(now) end
	local u = GLIDE > 0 and math.min(1, (now - glide.at) / GLIDE) or 1
	local w = glide.from + (glide.to - glide.from) * Ease(u)
	-- (Set only while it glides.)
	if w ~= glide.w then
		glide.w = w
		strip:SetWidth(math.max(w, 1))
	end
	-- A new voice fades in; one whose time is up goes.
	local inside = medal.inside
	if inside.at then
		local a = math.min(1, (now - inside.at) / SPEAK)
		inside:SetAlpha(a)
		medal.over:SetAlpha(a)
		strip.title:SetAlpha(a)
		strip.under:SetAlpha(a)
		strip.right:SetAlpha(a)
		if a >= 1 then inside.at = nil end
	end
	BUSY.Step(now, elapsed)
	-- A voice that beats: its glow and light swell at the start of each beat.
	local voice = speaking and voices[speaking]
	if voice and voice.pulse then
		local u = (now % PULSE) / PULSE
		local b = u < SWELL and math.sin(math.pi * u / SWELL) or 0
		medal.glow:SetAlpha(0.35 + 0.65 * b)
		strip.light:SetAlpha(0.6 + 0.4 * b)
	end
	clock = clock + elapsed
	if clock >= EVERY then
		clock = 0
		Expire(now)
		if Current() ~= speaking then
			Speak()
		else
			local def = speaking and voices[speaking]
			-- Words that are read each time (where you are) are laid again only when they change.
			if def and not headline and (type(def.title) == "function" or type(def.under) == "function") then
				local title, under = Value(def.title, def) or "", Value(def.under, def) or ""
				local was = strip.under:GetText() or ""
				local sameTitle = Same(title, strip.title:GetText())
				if not (sameTitle and Same(under, was)) then
					-- Only a number under it changed (where you are, walking): the plate is as wide (Steady
					-- measures the words with every digit a 0), so only the words are set.
					if sameTitle and not issecretvalue(under) and not issecretvalue(was) and under ~= "" and was ~= ""
						and Zeroed(under) == Zeroed(was) then
						strip.under:SetText(under)
					else
						Lay()
					end
				end
			end
		end
	end
	for _, b in pairs(cells) do
		if b.lit then
			local t = (now - b.lit) / FLARE
			if t >= 1 then
				b.lit = nil
				b.glow:SetAlpha(b.hot and 0.3 or 0)
				b.light:SetAlpha(b.hot and HOT or REST)
			else
				local flare = math.sin(t * math.pi)
				b.glow:SetAlpha(0.6 * flare)
				b.light:SetAlpha(REST + (1 - REST) * flare)
			end
		end
	end
end

-- Your level, and where you are: the head's own voice. The area and the zone, no coordinates: the guide says
-- where to go.

local function Caps(text)
	if text == nil or issecretvalue(text) then return text end
	return text:upper()
end

local LEVEL = {
	priority = 0, arc = true,
	title = function()
		local area = GetMinimapZoneText()
		if area == nil or (not issecretvalue(area) and area == "") then return GetZoneText() end
		return area
	end,
	under = function()
		local zone, area = GetZoneText(), GetMinimapZoneText()
		-- (In a place with one name the zone's isn't said twice.)
		if not issecretvalue(zone) and not issecretvalue(area) and zone == area then return "" end
		return Caps(zone) or ""
	end,
}

local function Level()
	LEVEL.level = tostring(UnitLevel("player"))
	if speaking == "level" and medal then
		medal.level:SetText(LEVEL.level)
		Theme.Centre(medal.level, medal.inside)
		Arc(true)
	end
end

-- A picture of the head speaking one voice, for drawings of the screen and for pickers: the plate with
-- the voice's words on their baselines as Lay seats them, the light along its top in the voice's color,
-- and the circle at its left end with what the voice puts there. Nothing of it takes the mouse.
--   Shy.Notices.Picture(parent, { seat = function(frame, over) end,   -- draws the circle's inside (as Voice takes it);
--                                                               -- without it your level stands there
--       title, under, color, underColor, widest }) -> frame     -- widest: the most room the words take (WIDEST)
--   frame:Say(title, under, underColor)   -- the words again; the plate fits them (LEAST to widest)
--   frame.circle (the frame `seat` drew on), frame.title, frame.under
function N.Picture(parent, def)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(CIRCLE)
	f:EnableMouse(false)
	local widest = def.widest or WIDEST
	local p = Plaque(f, true)
	Shape(f, p, PLATE_Y, CIRCLE, true, TALL)
	Look(p)
	local light = f:CreateTexture(nil, "ARTWORK")
	light:SetTexture(MEDIA .. "HoverLight")
	light:SetHeight(LIGHT)
	UI.Tint(light, def.color or Theme.Accent, 0.85)
	f.title = Words(f, UI.TitleFont(TITLE))
	f.title:SetJustifyV("TOP")
	f.under = Words(f, UI.NameFont(UNDER))
	UI.Ink(f.title, def.titleColor or C.text)
	-- The circle: the steel ring on its face, and the voice's own drawing inside it.
	f.circle = CreateFrame("Frame", nil, f)
	f.circle:SetSize(CIRCLE, CIRCLE)
	f.circle:SetPoint("CENTER", f, "LEFT", CIRCLE, 0)
	f.circle:EnableMouse(false)
	local face = f.circle:CreateTexture(nil, "ARTWORK", nil, -1)
	face:SetTexture(MEDIA .. "Dial")
	face:SetSize(FACE, FACE)
	face:SetPoint("CENTER")
	UI.Tint(face, Theme.skin.metal)
	UI.Concentric(face)
	local rim = CreateFrame("Frame", nil, f.circle)
	rim:SetAllPoints()
	rim:SetFrameLevel(f.circle:GetFrameLevel() + 2)
	UI.LookRing(face, CIRCLE, rim)
	if def.seat then
		local over = CreateFrame("Frame", nil, f.circle)
		over:SetAllPoints()
		over:SetFrameLevel(rim:GetFrameLevel() + 2)
		def.seat(f.circle, over)
	else
		local level = Words(f.circle, UI.TitleFont(19))
		level:SetText(tostring(UnitLevel("player") or 1))
		UI.Ink(level, C.text)
		Theme.Centre(level, f.circle)
	end

	-- The words seated as Lay seats the head's: a block of the two lines centred on the plate, each on
	-- its baseline; the plate as wide as the longer, in whole STEPs so a counting number holds it still.
	local x = R + INSET
	function f:Say(title, under, underColor)
		under = under or ""
		self.title:SetWidth(0)
		self.under:SetWidth(0)
		self.title:SetText(title or "")
		self.under:SetText(under)
		UI.Ink(self.under, underColor or C.head)
		local words = math.max(Width(self.title, 0), Width(self.under, 0))
		words = math.min(widest, math.max(LEAST, math.ceil((words + FIT) / STEP) * STEP))
		self.title:SetWidth(words)
		self.under:SetWidth(words)
		local titleCaps, underCaps = CAPS * TITLE, (under ~= "") and CAPS * UNDER or 0
		local block = titleCaps + (under ~= "" and BETWEEN + underCaps or 0)
		local base = (TALL - block) / 2 + titleCaps
		self.title:SetHeight(TITLE)
		self.title:ClearAllPoints()
		self.title:SetPoint("TOPLEFT", self, "TOPLEFT", CIRCLE + x - Theme.Lead(self.title), -(PLATE_Y + base - TITLE * TITLE_SHARE))
		self.under:SetHeight(UNDER)
		self.under:ClearAllPoints()
		self.under:SetPoint("TOPLEFT", self, "TOPLEFT", CIRCLE + x, -(PLATE_Y + base + BETWEEN + underCaps - UNDER * NAME_SHARE))
		self.under:SetShown(under ~= "")
		light:ClearAllPoints()
		light:SetPoint("TOPLEFT", self, "TOPLEFT", CIRCLE + R, -PLATE_Y)
		light:SetPoint("TOPRIGHT", self, "TOPLEFT", CIRCLE + x + words + 6, -PLATE_Y)
		self:SetWidth(CIRCLE + x + words + END)
	end
	f:Say(def.title or "", def.under, def.underColor)
	return f
end

-- A picture of the head for drawings of the screen: your level and where you are.
local function Sample(parent)
	return N.Picture(parent, { title = GetZoneText() or "Your zone", under = "52.3, 41.8", color = C.good })
end

-- The list
-- It hangs in the head's drawer (Shy.Top): cells of the tray, from the drawer's inner face to its inner face, the
-- first under the plate's foot. The column lays the drawer round it and stands what else hangs there under it.

local rowPool, labelPool = {}, {}
local CELL = Make.CELL

-- A notice's heading: its sign and title in its color, a hairline fading out either side.
local function Label(i)
	local l = labelPool[i]
	if l then return l end
	l = Make.Heading(list)
	labelPool[i] = l
	return l
end

local function RowTip(r)
	local row = r.row
	if not row then return end
	if row.link or row.spell then
		GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
		if row.link then GameTooltip:SetHyperlink(row.link) else GameTooltip:SetSpellByID(row.spell) end
		GameTooltip:Show()
	end
end

-- A row: a cell of the tray (its picture in the tab's slot, or a sign on the tab), lit under the mouse.
local function Row(i)
	local r = rowPool[i]
	if r then return r end
	r = Make.Cell(list, "Button")
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetScript("OnEnter", function(self)
		self:Hot(true)
		RowTip(self)
	end)
	r:SetScript("OnLeave", function(self)
		self:Hot(false)
		if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
	end)
	r:SetScript("OnClick", function(self, button)
		local row, def = self.row, notices[self.id]
		if not row then return end
		if button == "RightButton" then
			if def and def.menu then
				UI.ContextMenu(self, function(root)
					if def.title then root:CreateTitle(def.title) end
					def.menu(root)
				end)
			end
		elseif IsModifiedClick("CHATLINK") then
			local link = row.link or (row.spell and C_Spell.GetSpellLink(row.spell))
			if link then ChatFrameUtil.InsertLink(link) end
		elseif row.click then
			N.Close()
			row.click(row)
		end
	end)
	rowPool[i] = r
	return r
end

-- Dresses a row for `row` of notice `def`; returns the width it needs.
local function DressRow(r, row, def)
	r.row = row
	r:Hot(false)
	local marked = row.icon ~= nil and row.quality and row.quality >= 2 and row.color
	return r:Set({ icon = row.icon, mark = marked and row.color or nil, sign = row.glyph or def.glyph or "note",
		color = row.tint or def.color or C.text, name = row.text or "", nameColor = row.color or C.text,
		right = row.right or "", rightColor = row.rightColor or C.head, indent = row.indent }) or LIST_MOST
end

-- Every notice with rows, its heading then its rows, one right on the next across the list's whole width (they
-- flow with it as the plate glides). list.need: the width its words need.
local function Lines()
	wipe(laid)
	local sections = {}
	for _, id in ipairs(order) do
		local def = notices[id]
		local rows = Rows(def)
		if rows then sections[#sections + 1] = { id = id, def = def, rows = rows } end
	end
	if #sections == 0 then return false end
	local need, y, nRow, nLabel = LIST_LEAST, 0, 0, 0
	local function Stand(f)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
		f:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
		f:Rule(true)
		f:Show()
		y = y + f.tall + CELL.RULE
	end
	for _, section in ipairs(sections) do
		local def = section.def
		nLabel = nLabel + 1
		local l = Label(nLabel)
		need = math.max(need, l:Set({ sign = def.glyph, file = not def.glyph and (def.icon or BUG_SMALL) or nil,
			title = def.title, color = def.color }) or 0)
		Stand(l)
		local entry = { id = section.id, label = (def.title or ""), rows = {} }
		for _, row in ipairs(section.rows) do
			nRow = nRow + 1
			local r = Row(nRow)
			r.id = section.id
			need = math.max(need, DressRow(r, row, def))
			Stand(r)
			entry.rows[#entry.rows + 1] = row
		end
		laid[#laid + 1] = entry
	end
	for i = nRow + 1, #rowPool do rowPool[i]:Hide() rowPool[i].row = nil end
	for i = nLabel + 1, #labelPool do labelPool[i]:Hide() end
	list.need = 2 * math.ceil(math.min(LIST_MOST, need) / 2)
	list:SetHeight(math.max(1, y - CELL.RULE))
	return true
end

-- The plate is laid for it (as wide as its rows need) and the column stood again: the drawer round it, what hangs
-- under it moved.
local function Hung()
	Lay()
	Shy.Top.Apply()
end

local function Close()
	if not list or not list:IsShown() then return end
	list:Hide()
	opened = nil
	wipe(laid)
	for _, b in pairs(cells) do
		b.open = nil
		if not b.hot and not b.lit then b.light:SetAlpha(REST) end
	end
	Hung()
end

local function Watch(self, elapsed)
	if self.shown < 1 then
		self.shown = math.min(1, self.shown + elapsed / OPEN)
		self:SetAlpha(self.shown)
	end
	if self:IsMouseOver() or strip:IsMouseOver() or medal:IsMouseOver() then
		self.away = 0
	else
		self.away = self.away + elapsed
		if self.away >= LINGER then Close() end
	end
end

local function Open(id)
	if not box or not notices[id] then return end
	if not list then
		list = CreateFrame("Frame", nil, box)
		list:SetHeight(1)
		list:SetScript("OnUpdate", Watch)
		list:Hide()
	end
	list:SetFrameLevel(strip:GetFrameLevel() + 20)
	if not Lines() then
		Close()
		return
	end
	opened = id
	for cid, b in pairs(cells) do
		b.open = cid == id or nil
		b.light:SetAlpha(b.open and HOT or REST)
	end
	for _, b in pairs(cells) do UI.TipHide(b, true) end
	if not list:IsShown() then
		list.shown = Quiet() and 1 or 0
		list:SetAlpha(list.shown)
	end
	list.away = 0
	list:Show()
	Hung()
end

function Toggle(id)
	if list and list:IsShown() and opened == id then Close() else Open(id) end
end

-- Posted or cleared while the list is open: it is laid again, or goes with the last of its rows.
local function Refresh()
	if not list or not list:IsShown() then return end
	if Lines() then Hung() else Close() end
end

-- The head's own mouse: the voice up now has the circle's and the words' click, menu and hover.
local function Mouse(frame)
	frame:EnableMouse(true)
	HUD.Manage(box, frame, false)
	frame:SetScript("OnMouseUp", function(self, button)
		if HUD.WasDragged(box) then return end
		local def = speaking and voices[speaking]
		if not def then return end
		if button == "RightButton" and def.menu then
			UI.ContextMenu(self, function(root) def.menu(root) end)
		elseif button == "LeftButton" and def.click then
			def.click(self)
		end
	end)
	frame:SetScript("OnEnter", function(self)
		local def = speaking and voices[speaking]
		if def and def.hover and not HUD.InHand() then def.hover(self) end
	end)
	frame:SetScript("OnLeave", function(self) UI.TipHide(self) end)
end

local function Build()
	if box then return end
	box = HUD.Create({
		id = "shy.notices", title = "Head",
		width = 200, height = CIRCLE,
		-- (In layout mode its mover lies over the whole column it leads: its name at its top, on the head.)
		label = "TOP",
		point = { "TOP", "TOP", 0, -4 },
		shown = function() return true end,
		grip = false,
		-- The column's head: what hangs under it hangs in its drawer, from its plate's foot (the circle's foot
		-- stands that much lower); its own list hangs there first.
		top = { order = 5, sample = Sample, wrap = true, head = true,
			foot = function() return box:GetHeight() - PLATE_Y - strip:GetHeight() end,
			hangs = function() return list end },
	})
	-- The plaque on a frame of its own, so its shadow is never cut; the words and notices on one that cuts
	-- what stands past its edges, so they come into sight as the plate glides wider.
	strip = CreateFrame("Frame", nil, box)
	strip:SetPoint("TOP", 0, -PLATE_Y)
	strip:SetSize(1, TALL)
	strip:SetClipsChildren(true)
	housing = CreateFrame("Frame", nil, box)
	housing:SetAllPoints(strip)
	housing:SetFrameLevel(strip:GetFrameLevel() - 1)
	plaque = Plaque(housing, true)
	Shape(housing, plaque, 0, 0, true, TALL)
	-- A voice's weave (`fill`): over the plaque, under the words (the drain's window is a level over it, so
	-- the words stand two over that: at one level the game drew either first).
	strip.drain = Make.Drain(housing, true)
	Make.Fill(plaque, strip.drain)
	strip.drain:SetFrameLevel(housing:GetFrameLevel() + 1)
	strip.drain:Hide()
	strip:SetFrameLevel(housing:GetFrameLevel() + 4)
	strip.mask = Make.PlateMask(strip, true)
	strip.mask:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
	strip.light = strip:CreateTexture(nil, "ARTWORK", nil, 1)
	strip.light:SetTexture(MEDIA .. "HoverLight")
	strip.light:SetHeight(LIGHT)
	strip.title = Words(strip, UI.TitleFont(TITLE))
	strip.under = Words(strip, UI.NameFont(UNDER))
	strip.right = Words(strip, UI.TitleFont(TITLE))
	strip.right:SetJustifyH("RIGHT")
	strip.right:Hide()
	strip.sep = strip:CreateTexture(nil, "ARTWORK")
	strip.sep:SetColorTexture(1, 1, 1, 1)
	strip.sep:SetWidth(1)
	UI.Tint(strip.sep, Theme.skin.metal, 0.35)
	Mouse(strip)
	medal = Medal()
	medal:SetPoint("CENTER", strip, "LEFT", 0, 0)
	medal:SetFrameLevel(strip:GetFrameLevel() + 6)
	Mouse(medal)
	strip:SetScript("OnUpdate", Shy.Clocked("notices: the head's frame", Tick))
	local snapping = false
	local function Again()
		if snapping then return end
		snapping = true
		Snap()
		snapping = false
	end
	hooksecurefunc(box, "SetPoint", Shy.Clocked("notices: the head moved", Again))
	local laidAt
	hooksecurefunc(box, "SetScale", function(_, scale)
		if scale == laidAt then return end
		laidAt = scale
		Lay()
	end)
	box:SetScript("OnShow", Snap)
	box:HookScript("OnHide", Close)
	-- Picked up (by the head or any piece of the column it leads): the hover it had up goes at once, and none
	-- comes while it is dragged (Mouse).
	Shy:On("SHY_HUD_MOVING", function(moving)
		if moving == box then UI.TipHide(nil, true) end
	end)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE",
		"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LEVEL_UP" or event == "PLAYER_XP_UPDATE" or event == "PLAYER_ENTERING_WORLD" then Level() end
		-- Experience (every kill) moves the circle's arc alone, which Level draws: the plate's words don't change.
		if event == "PLAYER_XP_UPDATE" then return end
		Lay()
	end)
	Shy:On("SHY_HUD_LAYOUT", function()
		Close()
		Show()
	end)
	Shy:On("SHY_THEME", function()
		medal:Arc()
		Speak(true)
		Refresh()
	end)
	-- The column's width changed (a row under the head wants more, or less): laid at it.
	Shy:On("SHY_TOP_WIDTH", function() Lay() end)
	-- Something hangs in the drawer, or nothing does any more: a bar is as wide as the drawer needs meanwhile.
	Shy:On("SHY_TOP_HUNG", function() Lay() end)
	-- The words changed font: measured again, the level's among them.
	Shy:On("SHY_FONT", function()
		if medal.level:IsShown() then Theme.Centre(medal.level, medal.inside) end
		Lay()
	end)
	Level()
	N.Voice("level", LEVEL)
	Show()
	-- (Up from the start: the column makes room for it now, not when something else moves it.)
	Shy.Top.Apply()
	Shy:Fire("SHY_HEAD")
end

function N.Post(id, def)
	local old = notices[id]
	local copy = {}
	for k, v in pairs(def) do copy[k] = v end
	-- (Posted again, its time begins again; one on its way out is back.)
	if copy.hold then copy.untilAt = GetTime() + copy.hold end
	notices[id] = copy
	Sort()
	Show()
	-- New, or more than there was: the notice lights once, out of a fight.
	local cell = cells[id]
	local more = old and type(def.count) == "number" and type(old.count) == "number" and def.count > old.count
	if cell and (not old or more) and not Quiet() then cell.lit = GetTime() end
	Refresh()
	Shy:Fire("SHY_NOTICES", #order)
end

function N.Clear(id)
	if not notices[id] then return end
	notices[id] = nil
	Sort()
	local cell = cells[id]
	if cell then UI.TipHide(cell, true) end
	Show()
	Refresh()
	Shy:Fire("SHY_NOTICES", #order)
end

function N.Get(id)
	return notices[id]
end

function N.List()
	return order
end

N.Open, N.Close = Open, Close

function N.Voice(id, def)
	if def then
		if def.hold then def.untilAt = GetTime() + def.hold end
		voices[id] = def
	else
		voices[id] = nil
	end
	if not medal then return end
	-- (The same voice posted again: its words and circle are laid afresh, with no fade.)
	if id == speaking and def then
		Fill(medal, id, def)
		Lay()
		return
	end
	Speak()
end

function N.Speaking()
	return speaking
end

-- Whether a line, as a voice's `under`, fits the plate's words whole: measured in the line's own font, on
-- a ruler of its own (the plate needn't be up), a little under WIDEST, as the game's measure and the
-- font's can differ by a hair.
local ruler
function N.Fits(under)
	if type(under) ~= "string" or issecretvalue(under) then return true end
	if not ruler then
		ruler = Words(UIParent, UI.NameFont(UNDER))
		ruler:Hide()
	end
	ruler:SetText(under)
	local w = Width(ruler, 0)
	return w <= WIDEST - 4
end

-- The head's plate (its frame, as wide as the plate glides to), for what floats beside it.
function N.Plate()
	return strip
end

-- The headline: def = { name, land, area, color, alpha, side } takes the plate's words (alpha: their
-- strength as it comes and goes); nil gives them back to the voice.
function N.Headline(def)
	if not def then
		if not headline then return end
		headline = nil
		strip.title:SetAlpha(1)
		strip.under:SetAlpha(1)
		Lay()
		return
	end
	local was = headline
	if not (was and Same(was.name, def.name) and Same(was.land, def.land) and Same(was.area, def.area) and was.color == def.color) then
		headline = { name = def.name, land = def.land, area = def.area, color = def.color }
		Close()
		Lay()
	end
	if strip then
		strip.title:SetAlpha(def.alpha or 1)
		strip.under:SetAlpha((def.alpha or 1) * (def.side or 1))
	end
end

function N.Headlined()
	return headline
end

function N.IsOpen()
	return list ~= nil and list:IsShown()
end

function N.Shown()
	return laid
end

-- The errors the bag caught and nobody has read yet: an alarm at the plate's point; a new one also takes
-- the circle for a moment, the bug and how many, its gist on the plate.
local told = 0
local function Gist(entry)
	local first = (entry.message or ""):match("^[^\n]*") or ""
	local file, line, rest = first:match("([%w_%-%.]+%.lua):(%d+):%s*(.*)")
	if file then return file .. ":" .. line .. "  " .. rest end
	return first
end

local function Errors()
	local E = Shy.Errors
	if not E then return end
	local fresh = E.Fresh()
	if fresh == 0 then
		told = 0
		N.Clear("errors")
		return
	end
	N.Post("errors", {
		order = 90, icon = BUG_SMALL, color = C.bad, fill = CRIMSON, count = fresh,
		title = fresh == 1 and "A new error" or (fresh .. " new errors"),
		says = "Click opens the errors. Right-click to copy or clear them.",
		note = function()
			local times = 0
			for _, entry in ipairs(E.List()) do times = times + entry.count end
			return times == 1 and "Once" or (times .. " times in all")
		end,
		click = function() E.Open() end,
		menu = function(root)
			root:CreateButton("Open the errors", function() E.Open() end)
			if E.CopyAll then root:CreateButton("Copy the report", function() E.CopyAll() end) end
			root:CreateButton("Clear the errors", function() E.Clear() end)
			root:CreateCheckbox("Show the game's error window", function() return E.Popup() end, function() E.SetPopup(not E.Popup()) end)
		end,
	})
	if fresh > told and not Quiet() then
		local newest = E.Sorted and E.Sorted()[1]
		N.Voice("error", {
			priority = 20, hold = 3, glyph = BUG, color = CRIMSON, count = tostring(fresh),
			title = newest and Gist(newest) or "A new error",
			under = newest and newest.addon and Caps(newest.addon) or "",
			click = function() E.Open() end,
		})
	end
	told = fresh
end

Shy:On("SHY_ERRORS", Errors)
Shy:On("SHY_LOGIN", function()
	Build()
	Errors()
end)
