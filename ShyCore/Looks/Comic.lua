-- The comic look: every housing a panel inked by hand. A bold black line wanders a little off true and swells and
-- thins as a brush does, heavier on the shadow sides (the foot, the right), its ends lifting to a point a little
-- past the corners; a printed shadow falls down and right, a screen of dots. The head is the dark panel, a swipe of a
-- loaded brush in your color across its foot, running dry; its title (the words its owner names, UI.LookTitle)
-- stands in a caption box of your color sized to the words, inked round and lettered in the ink that reads on it.
-- Whatever else stands on a head (tabs, toggles, counts, a subtitle) stays on the dark, where its own colors read. A
-- placed content (the console's buttons) keeps a calm rim. Buttons are inked and keylined off the page; icons are
-- inked round by hand (the Inked finish); a scroll bar is a column of dots with an inked thumb.
-- The foot band (chat's typing row) is a speech balloon lettered by hand, its make by what you're saying: Say and a
-- channel plain, a yell a burst, a whisper drawn dashed, an emote a narration caption; its keyline takes the color of
-- what you're saying, eased toward newsprint.
-- Every region stands from the plate's edge it is measured from, so it is right however the piece is sized.
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend
local floor, max, min = math.floor, math.max, math.min

-- The ink: runs tiling along a side (INK_H across, INK_V down), a row a weight, and their lifting ends (INK_CAP). A
-- run is TILE units long, BAND tall, its wobble in SEGMENTS (the art's: each starts and ends on the line's true
-- middle, so whole segments from any one meet the caps); a cap is CAP units long.
local INK_H, INK_V, INK_CAP = MEDIA .. "ComicInkH", MEDIA .. "ComicInkV", MEDIA .. "ComicInkCap"
local TILE, BAND, CAP = 512, 8, 8
local INK_SEGMENTS = { 58, 91, 44, 77, 103, 39, 66, 34 }
local ROWS = 6
-- The weights' rows (lit side, shadow side) for a panel's ink and a detail's (a caption, the head's rule, the ink
-- round a placed content), by the Ink option.
local WEIGHT = { bold = { panel = { 1, 2 }, detail = { 3, 4 } }, fine = { panel = { 3, 4 }, detail = { 5, 6 } } }
-- A stroke's middle in from the plate's edge (a panel's, a detail box's); how far a stroke runs past a corner, least
-- and most (each the piece's own).
local EDGE, DETAIL_EDGE, OVER = 1.9, 1.2, { 0.5, 3.5 }
-- The halftone, a texel a screen pixel: TONE gathering into a corner (TONE_W x TONE_H pixels), DOTS an even screen
-- tiling (DOTS_N pixels a side).
local TONE, TONE_W, TONE_H = MEDIA .. "ComicTone", 200, 120
local DOTS, DOTS_N = MEDIA .. "ComicDots", 48
local SOLID = MEDIA .. "ComicSolid"   -- the printed shadow's solid band (the halftone off), tinted
-- The caption round a title: PAD_X beside the words, PAD_Y over and under them. The printed shadow's offset and
-- strength (solid with the halftone off; a screen of dots, stronger, with it on).
local PAD_X, PAD_Y, DROP, DROP_SOLID, DROP_DOTS = 6, 2.5, 3, 0.5, 0.85
-- How much halftone (the Halftone option): light, the printed shadow only; heavy, a caption's own printed shadow of
-- dots in its color and dots in a colored rim's corner as well. Never over a piece's content or behind words: no
-- piece says where its content leaves room, and dots under a title swamp it.
local HALFTONE = { off = 0, light = 1, heavy = 2 }
-- The caption's shadow is set off mostly to the right (CAPTION_DROP: right, down): a subtitle may stand just under it.
local CAPTION_DOTS, CAPTION_DROP, RIM_DOTS = 0.9, { 4, 1.5 }, 0.4
-- The line under a head: a swipe of a loaded brush in your color, running dry toward its right (the art's SWIPES
-- rows, SWIPE_BAND units tall: one stroke stretched, nothing tiled), from the panel's left ink to a place of the
-- piece's own (REACH: of the head's width, least and most); thinner with the fine ink.
local SWIPE, SWIPES, SWIPE_BAND, SWIPE_FINE = MEDIA .. "ComicSwipe", 4, 8, 0.7
local REACH = { 0.62, 0.9 }
-- The panel and a dark caption (the Caption option's other pick); the ink.
local NIGHT, DARK_CAPTION, INK = { 0.07, 0.072, 0.09 }, { 0.025, 0.025, 0.03 }, { 0.015, 0.015, 0.022 }
local NIGHT_TONE = 0.8

-- The balloon (the art's): a left end, a middle tiling across in whole segments, a right end, each in three pictures
-- (its ink, its keyline, its inside); B_TALL with its margin; the ends B_END wide; the tail rising from its top.
local B_TILE, B_PAD, B_END, B_TALL = 256, 3, 14, 26
local B_SEGMENTS = { 41, 63, 29, 52, 71 }
local TAIL_W, TAIL_H, TAIL_X, TAIL_RISE = 19, 13, 3, 7.5
local BALLOON, PAPER = { 0.11, 0.11, 0.135 }, { 0.94, 0.91, 0.82 }
local KEY_TONE, KEY_A, INSIDE_TONE, INSIDE_A, IDLE = 0.6, 0.9, 0.06, 0.96, 0.35
local KINDS = { yell = "Yell", whisper = "Whisper" }   -- a voice's balloon; any other is Say's
local B_LEAST = 8                                      -- no balloon in a band shorter than this (it is gliding)
-- The balloon framed round the words (the foot's field, UI.LookFoot): its field's middle FIELD_MID down from the
-- art's top, its ink's inner edges INNER_L and INNER_R in from the art's ends (every voice's alike, the art's own
-- measure), the words PAD clear of the ink each side. Without a field told: where chat's typing row has its words.
local FIELD_MID, INNER_L, INNER_R, PAD = 12.8, 5, 5.5, 4
local FIELD = { left = 11.5, right = 11.5, mid = 10 }

local function Option(key)
	return Theme.LookOption("comic", key)
end

local function Weights(which)
	return WEIGHT[Option("ink")][which] or WEIGHT.bold[which]
end

local function Level()
	return HALFTONE[Option("halftone")] or 1
end

local function StripAlpha(h)
	return h.solid and 1 or UI.LookAlpha("comic", C.hudStrip[4])
end

-- Where things stand: units in from the plate, each from the edge it names: x from the left ("L") or the right
-- ("R"), y from the top ("T") or the foot ("B"). Fwd moves one `d` units on (rightward, downward).
local SIDE = { L = "LEFT", R = "RIGHT", T = "TOP", B = "BOTTOM" }
local NEAR = { L = true, T = true }
local function Fwd(v, e, d) return NEAR[e] and v + d or v - d end
local function Corner(g, x, ex, y, ey)
	return SIDE[ey] .. SIDE[ex], NEAR[ex] and g.inset[1] + x or -g.inset[3] - x, NEAR[ey] and -g.inset[2] - y or g.inset[4] + y
end
-- A region from its top left corner to its foot right one.
local function Rect(t, g, x0, ex0, y0, ey0, x1, ex1, y1, ey1)
	t:ClearAllPoints()
	local p, x, y = Corner(g, x0, ex0, y0, ey0)
	t:SetPoint("TOPLEFT", g.to, p, x, y)
	p, x, y = Corner(g, x1, ex1, y1, ey1)
	t:SetPoint("BOTTOMRIGHT", g.to, p, x, y)
end
-- A coordinate from the left (or top), with the plate's size `size` (its measure as last known: only lengths use it).
local function From(v, e, size) return NEAR[e] and v or size - v end

-- Whole segments of a run's wobble from the one the piece picks (`u` 0..1), as many as come nearest `long` units:
-- the texture's left and right along its tile.
local function Segments(list, tile, long, u)
	local first = floor(u * #list) % #list + 1
	local start = 0
	for i = 1, first - 1 do start = start + list[i] end
	local got, i = 0, first
	while true do
		local nxt = got + list[(i - 1) % #list + 1]
		if got > 0 and math.abs(nxt - long) > math.abs(got - long) then break end
		got, i = nxt, i + 1
	end
	return start / tile, (start + got) / tile
end
UI.ComicSegments = Segments   -- (tests)

-- One side's ink: a run from `a` to `b` (each from its edge) along the line `at`, across (a top or a foot) or down (a
-- side), its ends lifting past the corners by the piece's own overshoot. `row` is the weight's row in the art.
local function Stroke(h, g, n, a, ea, b, eb, at, eat, across, row, salt)
	local runs, caps = UI.LookPool(h, "comicRun", "ARTWORK", 1), UI.LookPool(h, "comicCap", "ARTWORK", 1)
	local _, v = UI.LookSeed(h, salt)
	local u2, v2 = UI.LookSeed(h, salt .. "+")
	local size = across and g.w or g.tall
	local s0 = Fwd(a, ea, -(OVER[1] + (OVER[2] - OVER[1]) * v))
	local s1 = Fwd(b, eb, OVER[1] + (OVER[2] - OVER[1]) * v2)
	local long = From(s1, eb, size) - From(s0, ea, size)
	local cap = max(0.5, min(CAP, long / 2))
	local c0, c1 = Fwd(s0, ea, cap), Fwd(s1, eb, -cap)
	local lo, hi = Fwd(at, eat, -BAND / 2), Fwd(at, eat, BAND / 2)
	local v0, v1 = (row - 1) / ROWS, row / ROWS
	local run = runs:Get(n.run + 1)
	local first, last = caps:Get(n.cap + 1), caps:Get(n.cap + 2)
	n.run, n.cap = n.run + 1, n.cap + 2
	local l, r = Segments(INK_SEGMENTS, TILE, max(1, long - 2 * cap), u2)
	UI.LookWear(first, INK_CAP)
	UI.LookWear(last, INK_CAP)
	local c = cap / CAP   -- a short stroke shows its caps' joins only
	if across then
		UI.LookWear(run, INK_H, "REPEAT", "CLAMP")
		run:SetTexCoord(l, r, v0, v1)
		Rect(run, g, c0, ea, lo, eat, c1, eb, hi, eat)
		Rect(first, g, s0, ea, lo, eat, c0, ea, hi, eat)
		first:SetTexCoord(1 - c, 1, v0, v1)
		Rect(last, g, c1, eb, lo, eat, s1, eb, hi, eat)
		last:SetTexCoord(1, 1 - c, v0, v1)
	else
		UI.LookWear(run, INK_V, "CLAMP", "REPEAT")
		run:SetTexCoord(v0, v1, l, r)
		Rect(run, g, lo, eat, c0, ea, hi, eat, c1, eb)
		-- A cap turned to stand up its side: the tip at the top (the first) or at the foot (the last).
		Rect(first, g, lo, eat, s0, ea, hi, eat, c0, ea)
		first:SetTexCoord(1 - c, v0, 1, v0, 1 - c, v1, 1, v1)
		Rect(last, g, lo, eat, c1, eb, hi, eat, s1, eb)
		last:SetTexCoord(1, v0, 1 - c, v0, 1, v1, 1 - c, v1)
	end
	for _, t in ipairs({ run, first, last }) do t:SetVertexColor(1, 1, 1, 1); t:Show() end
end

-- An inked box round a rect (its corners each from their edges), its lines `e` in: the lit sides (top, left) light,
-- the shadow sides (foot, right) heavy.
local function Box(h, g, n, x0, ex0, y0, ey0, x1, ex1, y1, ey1, e, which, salt)
	local w = Weights(which)
	local left, top, right, foot = Fwd(x0, ex0, e), Fwd(y0, ey0, e), Fwd(x1, ex1, -e), Fwd(y1, ey1, -e)
	Stroke(h, g, n, left, ex0, right, ex1, top, ey0, true, w[1], salt .. "t")
	Stroke(h, g, n, top, ey0, foot, ey1, left, ex0, false, w[1], salt .. "l")
	Stroke(h, g, n, left, ex0, right, ex1, foot, ey1, true, w[2], salt .. "b")
	Stroke(h, g, n, top, ey0, foot, ey1, right, ex1, false, w[2], salt .. "r")
end

-- The halftone gathering into a corner of a rect `wide` x `tall` units, that corner at (x, ex), (y, ey): laid on
-- whole pixels from it and cut to the rect; nothing without a pixel size.
local function Dots(t, g, x, ex, y, ey, wide, tall)
	local per = g.per
	if not per then t:Hide() return false end
	local w, ht = min(TONE_W, floor(wide * per)), min(TONE_H, floor(tall * per))
	if w < 8 or ht < 8 then t:Hide() return false end
	local p, px, py = Corner(g, floor(x * per + 0.5) / per, ex, floor(y * per + 0.5) / per, ey)
	t:ClearAllPoints()
	t:SetPoint("BOTTOMRIGHT", g.to, p, px, py)
	t:SetSize(w / per, ht / per)
	t:SetTexCoord(1 - w / TONE_W, 1, 1 - ht / TONE_H, 1)
	t:Show()
	return true
end

-- What stands in the foot band (UI.LookFoot's info, from its owner: chat's typing row), or a plain Say.
local SAY = { 1, 1, 1 }
local function Voice(h)
	local info = h.footInfo
	return info and info.voice or "say", info and info.color or SAY, info and info.idle
end

-- The balloon along the foot band: its keyline, inside and ink, each in three pieces across, and its tail.
local function Balloon(h, g)
	local B = h.comicBalloon
	local voice, color, idle = Voice(h)
	local foot = g.foot or 0
	local shown = foot >= B_LEAST
	local emote = voice == "emote"
	for _, list in ipairs({ B.key, B.inside, B.ink, B.tail }) do
		for _, t in ipairs(list) do t:SetShown(shown and not emote) end
	end
	B.box:SetShown(shown and emote)
	B.boxKey:SetShown(shown and emote)
	if not shown then return end
	-- Fading in as the band opens; idle, the inside fades and the ink stays.
	local open = min(1, foot / B_TALL)
	local r, gr, b = color[1], color[2], color[3]
	local kr, kg, kb = Blend(PAPER[1], PAPER[2], PAPER[3], r, gr, b, KEY_TONE)
	local ir, ig, ib = Blend(BALLOON[1], BALLOON[2], BALLOON[3], r, gr, b, INSIDE_TONE)
	local inside = INSIDE_A * (idle and IDLE or 1) * open
	-- Framed round the words: their middle on the field's, their start and end PAD clear of the ink.
	local field = h.footInfo and h.footInfo.field or FIELD
	local words = foot - field.mid                               -- the words' middle, up from the plate's foot
	local x0, x1 = field.left - g.inset[1] - PAD - INNER_L, field.right - g.inset[3] - PAD - INNER_R
	local top = words + FIELD_MID                                -- the art's top, up from the plate's foot
	if emote then
		-- A narration caption: square, round the words as the balloon is, its keyline round its ink.
		local half = (B_TALL - 2 * B_PAD) / 2
		local cx0, cx1 = field.left - g.inset[1] - PAD - DETAIL_EDGE, field.right - g.inset[3] - PAD - DETAIL_EDGE
		Rect(B.boxKey, g, cx0 - 1.1, "L", words + half + 1.1, "B", cx1 - 1.1, "R", words - half - 1.1, "B")
		B.boxKey:SetColorTexture(kr, kg, kb, KEY_A * open)
		Rect(B.box, g, cx0, "L", words + half, "B", cx1, "R", words - half, "B")
		B.box:SetColorTexture(ir, ig, ib, inside)
		Box(h, g, h.comicN, cx0, "L", words + half, "B", cx1, "R", words - half, "B", DETAIL_EDGE, "detail", "emote")
		return
	end
	local name = "ComicBalloon" .. (KINDS[voice] or "Say")
	local u = UI.LookSeed(h, "balloon")
	local l, rr = Segments(B_SEGMENTS, B_TILE, max(1, g.w - x0 - x1 - 2 * B_END), u)
	for _, part in ipairs({ "key", "inside", "ink" }) do
		local list, suffix = B[part], (part == "key" and "Key") or (part == "inside" and "Fill") or ""
		local left, mid, right = list[1], list[2], list[3]
		UI.LookWear(left, MEDIA .. name .. suffix .. "L")
		UI.LookWear(mid, MEDIA .. name .. suffix .. "M", "REPEAT", "CLAMP")
		UI.LookWear(right, MEDIA .. name .. suffix .. "R")
		Rect(left, g, x0, "L", top, "B", x0 + B_END, "L", top - B_TALL, "B")
		Rect(mid, g, x0 + B_END, "L", top, "B", x1 + B_END, "R", top - B_TALL, "B")
		mid:SetTexCoord(l, rr, 0, 1)
		Rect(right, g, x1 + B_END, "R", top, "B", x1, "R", top - B_TALL, "B")
		for _, t in ipairs(list) do
			if part == "key" then t:SetVertexColor(kr, kg, kb, KEY_A * open)
			elseif part == "inside" then t:SetVertexColor(ir, ig, ib, inside)
			else t:SetVertexColor(1, 1, 1, open) end
		end
	end
	-- The tail rising from the balloon's top at the left: its keyline under the balloon's inside, its own inside over
	-- the balloon's ink where they join, its ink (dashed for a whisper).
	local key, fill, ink = B.tail[1], B.tail[2], B.tail[3]
	UI.LookWear(key, MEDIA .. "ComicTailKey")
	UI.LookWear(fill, MEDIA .. "ComicTailFill")
	UI.LookWear(ink, MEDIA .. (voice == "whisper" and "ComicTailDash" or "ComicTail"))
	for _, t in ipairs(B.tail) do
		Rect(t, g, x0 + TAIL_X, "L", top + TAIL_RISE, "B", x0 + TAIL_X + TAIL_W, "L", top + TAIL_RISE - TAIL_H, "B")
	end
	key:SetVertexColor(kr, kg, kb, KEY_A * open)
	fill:SetVertexColor(ir, ig, ib, inside)
	ink:SetVertexColor(1, 1, 1, open)
end

-- The rim round a placed content (Bar rim: dark, the plate; your color, a flat band of it, dots of ink in its corner
-- with heavy halftone), and the content's own ink.
local function Rim(h, g)
	local keep = g.content
	local bands, dots = h.comicRims, h.comicRimDots
	if not (keep and g.head == 0) then
		for _, t in ipairs(bands) do t:Hide() end
		dots:Hide()
		return
	end
	local l, t, r, b = keep[1] - 1, keep[2] - 1, keep[3] - 1, keep[4] - 1
	local colored = Option("rim") == "color"
	Rect(bands[1], g, 2, "L", 2, "T", 2, "R", t, "T")
	Rect(bands[2], g, 2, "L", b, "B", 2, "R", 2, "B")
	Rect(bands[3], g, 2, "L", t, "T", l, "L", b, "B")
	Rect(bands[4], g, r, "R", t, "T", 2, "R", b, "B")
	for _, band in ipairs(bands) do band:SetShown(colored) end
	if not (colored and Level() >= HALFTONE.heavy and Dots(dots, g, 2, "R", 2, "B", g.w - 4, g.tall - 4)) then dots:Hide() end
	Box(h, g, h.comicN, l - DETAIL_EDGE, "L", t - DETAIL_EDGE, "T", r - DETAIL_EDGE, "R", b - DETAIL_EDGE, "B", DETAIL_EDGE, "detail", "content")
end

-- The caption's color: yours (a sample's own, UI.LookAccent), or dark (the Caption option). Words stand on it, so
-- yours is held where its ink reads (Theme.FaceFor: itself while an ink reads on it, else lighter or darker
-- just far enough, its hue kept): a warrior's tan holds neither white nor black at a title's contrast.
local function CaptionColor(h)
	if Option("caption") == "dark" then return DARK_CAPTION[1], DARK_CAPTION[2], DARK_CAPTION[3] end
	return Theme.FaceFor(UI.LookAccent(h)())
end

-- Whether a head names title words (shown, not empty): a caption may stand behind them.
local function Titled(g)
	local fs = g.title
	if not (fs and fs:IsShown()) then return false end
	local text = fs:GetText()
	return text ~= nil and not issecretvalue(text) and text ~= ""
end
-- How wide the words are drawn (all of them, in the font they wear now: measured after they are lettered), and their
-- size; nil while it can't be told.
local function Width(fs)
	local sw = fs:GetUnboundedStringWidth()
	if not sw or issecretvalue(sw) or sw <= 0 then return end
	local _, size = fs:GetFont()
	if not size or issecretvalue(size) then size = 12 end
	return sw, size
end
-- Where the caption stands on its words, by how they are justified: its point on theirs, and how far out.
local JUSTIFY = { LEFT = { "LEFT", -1 }, CENTER = { "CENTER", 0 }, RIGHT = { "RIGHT", 1 } }
-- The ink round a caption: a nine slice, its lines CAPTION_IN in from its edges (so it stands that far out round the
-- caption), its corners CAPTION_SLICE.
local CAPTION_INK, CAPTION_IN, CAPTION_SLICE = MEDIA .. "ComicCaption", 4, 8

-- The title words a caption stands behind, lettered for it (Theme.Letter: the ink that reads on the caption, the
-- theme's text effect against that ink); our own words only: a game window's title is inked by its kit through
-- UI.TitleInk. Given back when no caption stands behind them.
local captioned = setmetatable({}, { __mode = "k" })   -- font string -> the housing whose caption it stands on
local function Letter(fs, h)
	Theme.Letter(fs, { ground = function() return CaptionColor(h) end })
end
local function Unletter(fs)
	captioned[fs] = nil
	Theme.Letter(fs, { ground = false })
	Theme.Ink(fs, C.head)
end

-- The head's line: one swipe of the brush across its foot, its row and how far it reaches the piece's own.
local function Swipe(h, g)
	local t, head = h.comicRule, g.head or 0
	if head <= 0 then t:Hide() return end
	local u, v = UI.LookSeed(h, "swipe")
	local row = floor(u * SWIPES) % SWIPES
	local half = SWIPE_BAND * (Option("ink") == "fine" and SWIPE_FINE or 1) / 2
	local at = head - UI.LINE / 2
	local short = (1 - (REACH[1] + (REACH[2] - REACH[1]) * v)) * max(0, (g.w or 0) - 2 * EDGE)
	Rect(t, g, EDGE, "L", at - half, "T", EDGE + short, "R", at + half, "T")
	t:SetTexCoord(0, 1, row / SWIPES, (row + 1) / SWIPES)
	t:Show()
end

-- The caption box behind a head's title: standing on the words themselves (wherever their owner lays them, whenever
-- the game lays them out), as wide as they are and a pad, its ink round it and (heavy halftone) a printed shadow of
-- dots in its own color down and right of it, never behind the words; the head's swipe below.
local captions = setmetatable({}, { __mode = "k" })   -- housings with a caption up: fitted again when the font changes
Shy:On("SHY_FONT", function()
	for h in pairs(captions) do UI.LookFit(h, true) end
end)
local function Caption(h, g)
	local head = g.head or 0
	local cap, dots, ink = h.comicCaption, h.comicCaptionDots, h.comicCaptionInk
	local titled = head > 0 and Titled(g)
	local fs, was = g.title, h.comicLettered   -- the words now, and the ones it lettered last
	if was and (was ~= fs or not titled) and captioned[was] == h then Unletter(was) end
	h.comicLettered = nil
	-- Lettered first, so the words are measured in the font they wear on the caption.
	if titled and g.titleOwn then
		captioned[fs] = h
		h.comicLettered = fs
		Letter(fs, h)
	end
	local sw, size
	if titled then sw, size = Width(fs) end
	captions[h] = sw and true or nil
	if sw then
		local w, ht = sw + 2 * PAD_X, size + 2 * PAD_Y
		local at = JUSTIFY[fs:GetJustifyH()] or JUSTIFY.LEFT
		cap:ClearAllPoints()
		cap:SetPoint(at[1], fs, at[1], at[2] * PAD_X, 0)
		cap:SetSize(w, ht)
		cap:Show()
		ink:ClearAllPoints()
		ink:SetPoint("TOPLEFT", cap, "TOPLEFT", -CAPTION_IN, CAPTION_IN)
		ink:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", CAPTION_IN, -CAPTION_IN)
		ink:Show()
		-- Its printed shadow: the caption's own shape set down and right under it, a screen of dots a texel a pixel.
		if Level() >= HALFTONE.heavy and g.per then
			dots:ClearAllPoints()
			dots:SetPoint("TOPLEFT", cap, "TOPLEFT", CAPTION_DROP[1], -CAPTION_DROP[2])
			dots:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", CAPTION_DROP[1], -CAPTION_DROP[2])
			dots:SetTexCoord(0, w * g.per / DOTS_N, 0, ht * g.per / DOTS_N)
			dots:Show()
		else
			dots:Hide()
		end
	else
		cap:Hide()
		dots:Hide()
		ink:Hide()
	end
	-- The head's line, where the accent line stands in the other looks.
	Swipe(h, g)
end

-- A button (UI.KEY_MAKES): its edge inked by hand as the panels are, light along the top and the left, heavy down
-- the shadow sides, on a matte face, and kept off the dark page by a keyline as a balloon is (ComicKeyPlate: thin
-- along the top and the left, heavier down the shadow sides, as a print a little off register): newsprint touched
-- with your color at rest, your color under the mouse and on the primary. Under the mouse a little white ink lifts
-- the face too (no light: paper isn't lit); the primary takes your color flat, as a caption does. A bare piece at
-- rest shows none of it.
local KEY_PLATE, KEY_REACH, KEY_SLICE = MEDIA .. "ComicKeyPlate", 2, 8
local PLATE_TONE, PLATE_REST = 0.2, 0.85   -- how far the keyline at rest leans to your color; its strength then
local function KeyBuild(f)
	local plate = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	UI.LookWear(plate, KEY_PLATE, nil, nil, KEY_SLICE)
	plate:SetPoint("TOPLEFT", -KEY_REACH, KEY_REACH)
	plate:SetPoint("BOTTOMRIGHT", KEY_REACH, -KEY_REACH)
	f.comicKey = plate
	return { plate }
end
local function KeyMark(f, lit, _, primary)
	local plate = f.comicKey
	if not plate then return end
	local accent = UI.LookAccent(f)
	local hot = lit or primary
	Theme.Tint(plate, function()
		local r, g, b = accent()
		if hot then return r, g, b, 1 end
		r, g, b = Blend(PAPER[1], PAPER[2], PAPER[3], r, g, b, PLATE_TONE)
		return r, g, b, PLATE_REST
	end)
	plate:SetShown(f.shyPlate ~= false or lit == true)
end
UI.KEY_MAKES.comic = { edge = { MEDIA .. "ComicKey", 6 }, rim = "dark", hover = { color = { 1, 1, 1 }, lift = 0.1, light = 0 },
	build = KeyBuild, mark = KeyMark }

-- A scroll bar (UI.LookKind's `scroll`): its track a column of dots in your color, a printed screen; its thumb inked
-- round. Each follows the core's track and thumb (shown as they are, as wide and as long).
local SCROLL_DOTS, SCROLL_W, SCROLL_INK = 0.55, 4, 1   -- the dots' strength, their column's width; the ink round the thumb
local function ScrollLay(s)
	local area = s.area
	local on = s.on
	s.dots:SetShown(on and s.track:IsShown())
	s.ink:SetShown(on and s.thumb:IsShown())
	if not on then return end
	local _, tall = s.track:GetSize()
	local scale = area:GetEffectiveScale()
	if issecretvalue(tall) or issecretvalue(scale) or not (tall and scale and scale > 0) then return end
	local per = scale / PixelUtil.GetPixelToUIUnitFactor()
	s.dots:SetTexCoord(0, SCROLL_W * per / DOTS_N, 0, tall * per / DOTS_N)
end
local function Scroll(area, thumb, track, on)
	local s = area.comicScroll
	if not s then
		if not on then return end
		s = { area = area, thumb = thumb, track = track }
		area.comicScroll = s
		s.dots = area:CreateTexture(nil, "BACKGROUND", nil, 1)
		UI.LookWear(s.dots, DOTS, "REPEAT", "REPEAT")
		s.dots:SetPoint("TOPRIGHT", track, "TOPRIGHT")
		s.dots:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT")
		s.dots:SetWidth(SCROLL_W)
		s.ink = area:CreateTexture(nil, "ARTWORK", nil, -1)
		s.ink:SetPoint("TOPLEFT", thumb, "TOPLEFT", -SCROLL_INK, SCROLL_INK)
		s.ink:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", SCROLL_INK, -SCROLL_INK)
		s.ink:SetColorTexture(1, 1, 1, 1)
		local function Follow() ScrollLay(s) end
		for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
			hooksecurefunc(thumb, method, Follow)
			hooksecurefunc(track, method, Follow)
		end
		area:HookScript("OnSizeChanged", Follow)
	end
	s.on = on
	track:SetAlpha(on and 0 or 1)
	if on then
		local accent = UI.LookAccent(area)
		Theme.Tint(s.dots, accent, SCROLL_DOTS)
		Theme.Tint(s.ink, INK, 1)
	end
	ScrollLay(s)
end

UI.LookKind("comic", {
	name = "Comic",
	strength = 92, wells = 100,
	words = "Hand-inked panels with caption boxes in your color.",
	short = "Inked comic panels",
	options = {
		{ key = "halftone", label = "Halftone", kind = "choice", default = "light",
			choices = { { value = "off", text = "Off" }, { value = "light", text = "Light" }, { value = "heavy", text = "Heavy" } },
			desc = "How much dot shading your panels show." },
		{ key = "ink", label = "Ink", kind = "choice", default = "bold",
			choices = { { value = "bold", text = "Bold" }, { value = "fine", text = "Fine" } },
			desc = "How heavy the hand-inked outlines are." },
		{ key = "caption", label = "Caption", kind = "choice", default = "color",
			choices = { { value = "color", text = "Your color" }, { value = "dark", text = "Dark" } },
			desc = "The color of the boxes behind titles." },
		{ key = "rim", label = "Bar rim", kind = "choice", default = "dark",
			choices = { { value = "dark", text = "Dark" }, { value = "color", text = "Your color" } },
			desc = "The frame around your action bars." },
	},
	alpha = function(a) return 1 - (1 - a) ^ 2 end,
	fill = function(r, g, b, a)
		r, g, b = Blend(r, g, b, NIGHT[1], NIGHT[2], NIGHT[3], NIGHT_TONE)
		return r, g, b, a
	end,
	-- The strip is put away: a head is the dark panel, its title set off in a caption of the look's own.
	strip = function(r, g, b) return r, g, b, 0, false end,
	toneFill = function(r, g, b) return Blend(r, g, b, NIGHT[1], NIGHT[2], NIGHT[3], 0.5) end,
	toneBorder = function(r, g, b) return Blend(r, g, b, INK[1], INK[2], INK[3], 0.5) end,
	shade = false,
	inset = 1,
	border = 4,
	rims = false,
	-- Ink round the panel, its printed shadow, the caption and the swipe in the head, the balloon in the foot:
	-- nothing across the face.
	-- A chat bubble's tail (UI.LookTail): the panel's ink at its weight, brushed on round it.
	tail = function() return "Comic" .. (Option("ink") == "fine" and "Fine" or "Bold"), { { layer = "Ink", color = { 1, 1, 1 } } } end,
	edge = { "comicRun", "comicCap", "comicDropRight", "comicDropFoot", "comicRimTop", "comicRimBottom", "comicRimLeft",
		"comicRimRight", "comicRimDots", "comicCaption", "comicCaptionDots", "comicCaptionInk", "comicCaptionKey", "comicRule",
		"comicCaptionInside", "comicBallooninkL", "comicBallooninkM", "comicBallooninkR", "comicBallooninsideL",
		"comicBallooninsideM", "comicBallooninsideR", "comicBalloonkeyL", "comicBalloonkeyM", "comicBalloonkeyR",
		"comicTailInk", "comicTailFill", "comicTailKey" },
	ownsFoot = true,
	bar = "inked",   -- the bars brushed by hand: ink along the top and the foot, a dry brush dragged out of it
	slot = "inked",   -- icons inked round by hand, as the panels are
	ground = "ink",   -- their wells brushed as the bars are: the frame's shadow cut by hand, a dry glint
	lineAlpha = 0,   -- the head's line is a brush swipe
	scroll = Scroll,
	text = "outline",   -- lettered as comics are, while no text effect is picked

	build = function(h, kit)
		local owner = kit.owner
		-- The printed shadow: a band along the right and one along the foot, offset down and right.
		h.comicDrop = { kit.Reg("comicDropRight", owner:CreateTexture(nil, "BACKGROUND", nil, -7)),
			kit.Reg("comicDropFoot", owner:CreateTexture(nil, "BACKGROUND", nil, -7)) }
		kit.Reg("comicCaption", owner:CreateTexture(nil, "BORDER", nil, 1))
		-- The caption's printed shadow, under it; the head's swipe, under the caption.
		UI.LookWear(kit.Reg("comicCaptionDots", owner:CreateTexture(nil, "BORDER", nil, 0)), DOTS, "REPEAT", "REPEAT")
		UI.LookWear(kit.Reg("comicRule", owner:CreateTexture(nil, "BORDER", nil, -1)), SWIPE)
		UI.LookWear(kit.Reg("comicCaptionInk", owner:CreateTexture(nil, "ARTWORK", nil, 1)), CAPTION_INK, nil, nil, CAPTION_SLICE)
		h.comicRims = {}
		for i, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
			h.comicRims[i] = kit.Reg("comicRim" .. side, owner:CreateTexture(nil, "BORDER", nil, 0))
			h.comicRims[i]:SetColorTexture(1, 1, 1, 1)
		end
		h.comicRimDots = kit.Reg("comicRimDots", owner:CreateTexture(nil, "BORDER", nil, 2))
		UI.LookWear(h.comicRimDots, TONE)
		-- The balloon: keyline, inside, ink (three across each), the tail's three, and an emote's square caption.
		local B = { key = {}, inside = {}, ink = {}, tail = {} }
		for i, part in ipairs({ "key", "inside", "ink" }) do
			for j, end_ in ipairs({ "L", "M", "R" }) do
				B[part][j] = kit.Reg("comicBalloon" .. part .. end_, owner:CreateTexture(nil, "ARTWORK", nil, 2 + i))
			end
		end
		for i, part in ipairs({ "Key", "Fill", "Ink" }) do
			B.tail[i] = kit.Reg("comicTail" .. part, owner:CreateTexture(nil, "ARTWORK", nil, i == 1 and 2 or 4 + i))
		end
		-- An emote's caption: under the ink (the detail box is drawn with the panel's, ARTWORK 1).
		B.boxKey = kit.Reg("comicCaptionKey", owner:CreateTexture(nil, "ARTWORK", nil, -1))
		B.box = kit.Reg("comicCaptionInside", owner:CreateTexture(nil, "ARTWORK", nil, 0))
		h.comicBalloon = B
	end,

	dress = function(h)
		local accent = UI.LookAccent(h)
		-- The printed shadow follows the Background strength (its dots or its solid band are fit's).
		for _, t in ipairs(h.comicDrop) do
			Theme.Tint(t, function() return INK[1], INK[2], INK[3], (Level() > 0 and DROP_DOTS or DROP_SOLID) * Theme.Strength() ^ 0.5 end)
		end
		Theme.Paint(h.comicCaption, function()
			local r, g, b = CaptionColor(h)
			return r, g, b, min(1, StripAlpha(h) + 0.15)
		end)
		Theme.Tint(h.comicCaptionDots, function()
			local r, g, b = CaptionColor(h)
			return r, g, b, CAPTION_DOTS
		end)
		Theme.Tint(h.comicRule, accent, 1)
		Theme.Tint(h.comicCaptionInk, INK, 1)
		for _, band in ipairs(h.comicRims) do
			Theme.Paint(band, function()
				local r, g, b = accent()
				return r, g, b, StripAlpha(h)
			end)
		end
		Theme.Tint(h.comicRimDots, function() return INK[1], INK[2], INK[3], RIM_DOTS end)
	end,

	fit = function(h, g)
		local n = { run = 0, cap = 0 }
		h.comicN = n
		-- The printed shadow (none under a window: it may stand over its content): a screen of dots with the halftone
		-- on, else solid.
		local right, below = h.comicDrop[1], h.comicDrop[2]
		Rect(right, g, 0, "R", DROP, "T", -DROP, "R", -DROP, "B")
		Rect(below, g, DROP, "L", 0, "B", 0, "R", -DROP, "B")
		local dotted = Level() > 0 and g.per ~= nil
		for i, t in ipairs(h.comicDrop) do
			if dotted then
				local across = i == 2
				local long = (across and g.w or g.tall) * g.per / DOTS_N
				local thick = DROP * g.per / DOTS_N
				UI.LookWear(t, DOTS, "REPEAT", "REPEAT")
				t:SetTexCoord(0, across and long or thick, 0, across and thick or long)
			else
				UI.LookWear(t, SOLID)
				t:SetTexCoord(0, 1, 0, 1)
			end
			t:SetShown(not h.solid)
		end
		Caption(h, g)
		Rim(h, g)
		Balloon(h, g)
		-- The panel's own ink, last: over everything else of the look's.
		Box(h, g, n, 0, "L", 0, "T", 0, "R", 0, "B", EDGE, "panel", "panel")
		UI.LookPool(h, "comicRun"):Done(n.run)
		UI.LookPool(h, "comicCap"):Done(n.cap)
	end,

	-- The core letters every title of its own in the look: only the ones a caption stands behind are Comic's to ink.
	title = function(fs, on)
		if not on then
			if captioned[fs] then Theme.Letter(fs, { ground = false }) end
			captioned[fs] = nil
			return
		end
		local h = captioned[fs]
		if h then Letter(fs, h) end
	end,
	-- A game window's title words on a caption (kit:Head): the ink that reads on it.
	titleInk = function() return Theme.OnColor(CaptionColor()) end,
})
