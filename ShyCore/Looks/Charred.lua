-- The charred look: wood burnt the way shou sugi ban is, the char cracked into alligator checks and the fire still
-- alive deep in the cracks in your color. The char and the fire gather where fire takes hold (the plate's edge, its
-- corners, the seam under the head), plain burnt wood between; what is written stands on planed boards.
local UI, Theme = Shy.UI, Shy.Theme
local max, min, floor = math.max, math.min, math.floor

local M = Shy.MEDIA
local ART = {
	wood = M .. "CharWood", ember = M .. "CharEmber", core = M .. "CharCore", planed = M .. "CharPlaned",
	seam = M .. "CharSeam", groove = M .. "CharGroove", edge = M .. "CharEdge", well = M .. "CharWell", blot = M .. "CharBlot",
}
-- The art's measures, in units: the char, its fire and the planed grain tile TILE across (the grain PLANED down);
-- the seam is SEAM_H tall; the edge and the wells are nine slices of SLICE.
local TILE, PLANED, SEAM_H, SLICE = 256, 32, 8, 4

-- The look's measures:
--   char, tone       what the fill leans to (burnt wood, near black, a little warm), and how far
--   board, boardA    the planed board under what is written, and its opacity on screen (by the strength's root)
--   inset, shade     the fill set in under the edge; the shade under a piece on screen
--   wood, plain      the char's strength and the plain wood's grain (on screen by the strength's root)
--   head             how much darker the head plank is (the strip)
--   edge             how deep the char reaches in from the plate's edge, dying away (units)
--   headTop          how far down the head it reaches from its top (of the head's height)
--   seamUp           how far above the seam it rises from it (units)
--   corner           its blot round each corner (units, radius)
--   lip              what is left of it at a placed content's well (of its strength at the edge)
--   fire, core, hot  the embers' and their hot core's strength, and how far the core's tint goes toward white
--   seam, footSeam   the fire along the head's seam and along the foot band's; bareSeam along the line of a piece
--                    with no head (the bars: their fire is at their spots, the line only a burnt groove)
--   glow             the Glow setting the strengths above are drawn for
local CH = {
	char = { 0.050, 0.043, 0.038 }, tone = 0.85, board = { 0.072, 0.058, 0.048 }, boardA = 0.70,
	inset = 1, shade = 0.8, wood = 0.95, plain = 0.8, head = 0.30,
	edge = 9, headTop = 0.75, seamUp = 7, corner = 28, lip = 0.7,
	fire = 1.0, core = 0.9, hot = 0.55, seam = 1.0, footSeam = 0.55, bareSeam = 0.15, glow = 70,
}
-- Where the fire has taken hold, by the Embers setting: round a placed content (the bars), a corner (`corner`, its
-- reach) and a short stretch of the foot (`foot`: half its length and its height), each `spot` strong, and with
-- `far` a stretch of the top on the far side; `base` along the rest of the rim. A headed piece: `headBase` along
-- its head's top, a spot at the head's far end (`headSpot`), and with `low` one at a bottom corner.
local EMBERS = {
	few = { corner = 28, foot = { 40, 10 }, spot = 1.2, base = 0, headBase = 0.25, headSpot = 0.6 },
	many = { corner = 34, foot = { 56, 10 }, far = { 44, 10 }, spot = 1.3, base = 0.3, headBase = 0.4, headSpot = 0.8, low = 30 },
}
local IN = 3   -- the boards' inset from the plate's sides and foot (the zones' IN)

local function Glow()
	return Theme.LookOption("charred", "glow") / CH.glow
end

-- r, g, b of the color a housing (or a header's owner) wears: a sample's own, else yours.
local function Accent(x)
	local c = UI.LookAccent(x)
	if type(c) == "function" then return c() end
	return c[1], c[2], c[3]
end

-- r, g, b of the fire's core: that color toward white.
local function Hot(r, g, b)
	return UI.LookBlend(r, g, b, 1, 1, 1, CH.hot)
end

-- A texture tiling `file` over a rect in units in from the plate's top left ({ x0, y0, x1, y1 }), its texcoords
-- counted from the housing's own place on the sheet (u, v: the seed's, in tiles).
local function Place(h, t, x0, y0, x1, y1)
	local to, inset = h.to, h.inset
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", to, "TOPLEFT", inset[1] + x0, -inset[2] - y0)
	t:SetPoint("BOTTOMRIGHT", to, "TOPLEFT", inset[1] + x1, -inset[2] - y1)
end
local function Lay(h, t, x0, y0, x1, y1, u, v, across, down)
	Place(h, t, x0, y0, x1, y1)
	t:SetTexCoord(u + x0 / across, u + x1 / across, v + y0 / down, v + y1 / down)
	t:Show()
end

-- Rect a cut to rect b, or nil when nothing of it is left.
local function Cut(a, b)
	local x0, y0, x1, y1 = max(a[1], b[1]), max(a[2], b[2]), min(a[3], b[3]), min(a[4], b[4])
	if x1 - x0 < 0.5 or y1 - y0 < 0.5 then return nil end
	return x0, y0, x1, y1
end

-- A pool's texture, its art set when it is made: `file` tiling, `add` added, masked by `mask`.
local function Piece(pool, i, file, add, mask)
	local t = pool:Get(i)
	if not t.shyChar then
		t.shyChar = true
		UI.LookWear(t, file, "REPEAT", "REPEAT")
		if add then t:SetBlendMode("ADD") end
		if mask then t:AddMaskTexture(mask) end
	end
	return t
end

-- A ramp of alpha over a texture: a0 at its top (or left) to a1 at its foot (or right).
local function Ramp(t, r, g, b, a0, a1, across)
	if across then
		t:SetGradient("HORIZONTAL", CreateColor(r, g, b, a0), CreateColor(r, g, b, a1))
	else
		t:SetGradient("VERTICAL", CreateColor(r, g, b, a1), CreateColor(r, g, b, a0))
	end
end

local worn = setmetatable({}, { __mode = "k" })   -- housing -> true while it wears the look

local function Fit(h, g)
	worn[h] = true
	local line = h.line and h.line.shyKinds and h.line.shyKinds.charred
	if line and line[1].charTile then line[1].charTile() end
	local w, tall, head, foot = g.w, g.tall, g.head or 0, g.foot or 0
	local n = CH.inset
	local X0, Y0, X1, Y1 = n, n, w - n, tall - n
	local k = h.solid and 1 or Theme.Strength() ^ 0.5
	local u, v = UI.LookSeed(h, "char")
	-- The boards: the content's well (the core's), and under a foot band the foot's own.
	local wells = {}
	if g.well then wells[1] = { g.well[1], g.well[2], w - g.well[3], tall - g.well[4] } end
	local floored = foot > 0 and w > 2 * (IN + SLICE) and foot - 1 - IN > 2 * SLICE
	if floored and g.well then wells[2] = { IN, tall - foot + 1, w - IN, tall - IN } end
	-- The bands round them: plain burnt wood.
	local bands = {}
	if wells[1] then
		local first, last = wells[1], wells[#wells]
		bands[1] = { X0, Y0, X1, first[2] }
		bands[2] = { X0, last[4], X1, Y1 }
		bands[3] = { X0, first[2], first[1], last[4] }
		bands[4] = { first[3], first[2], X1, last[4] }
		if wells[2] then bands[5] = { first[1], first[4], first[3], wells[2][2] } end
	else
		bands[1] = { X0, Y0, X1, Y1 }
	end
	local plain = UI.LookPool(h, "charPlain", "BACKGROUND", -5)
	local used = 0
	for _, b in ipairs(bands) do
		if b[3] - b[1] >= 0.5 and b[4] - b[2] >= 0.5 then
			used = used + 1
			local t = Piece(plain, used, ART.planed)
			Lay(h, t, b[1], b[2], b[3], b[4], u, v, TILE, PLANED)
			t:SetVertexColor(1, 1, 1, CH.plain * k)
		end
	end
	plain:Done(used)
	-- The char, where the fire took hold: in from the edge (round a placed content, across the whole rim to its
	-- lip), down from the head's top, up from the seam, and a blot at each corner.
	local char = UI.LookPool(h, "charBand", "BACKGROUND", -4)
	local a = CH.wood * k
	used = 0
	local function Char(x0, y0, x1, y1, a0, a1, across)
		if x1 - x0 < 0.5 or y1 - y0 < 0.5 then return end
		used = used + 1
		local t = Piece(char, used, ART.wood)
		Lay(h, t, x0, y0, x1, y1, u, v, TILE, TILE)
		Ramp(t, 1, 1, 1, a * a0, a * a1, across)
	end
	local e = CH.edge
	local placed = g.content and wells[1]
	if placed then
		local wl = wells[1]
		Char(X0, Y0, X1, wl[2], 1, CH.lip)
		Char(X0, wl[4], X1, Y1, CH.lip, 1)
		Char(X0, wl[2], wl[1], wl[4], 1, CH.lip, true)
		Char(wl[3], wl[2], X1, wl[4], CH.lip, 1, true)
	else
		local reach = head > 0 and head * CH.headTop or e
		Char(X0, Y0, X1, Y0 + reach, 1, 0)
		Char(X0, Y1 - e, X1, Y1, 0, 1)
		local s0, s1 = Y0, Y1
		if wells[1] then s0, s1 = bands[3][2], bands[3][4] end
		Char(X0, s0, min(X0 + e, X1), s1, 1, max(0, 1 - (min(X0 + e, X1) - X0) / e), true)
		Char(max(X1 - e, X0), s0, X1, s1, max(0, 1 - (X1 - max(X1 - e, X0)) / e), 1, true)
		if head > 0 then Char(X0, head - 1 - CH.seamUp, X1, head - 1, 0, 1) end
	end
	char:Done(used)
	local c = CH.corner
	for i, at in ipairs({ { X0, Y0 }, { X1, Y0 }, { X0, Y1 }, { X1, Y1 } }) do
		local pool = UI.LookPool(h, "charCorner" .. i, "BACKGROUND", -4)
		local mask = h.charCorners[i]
		local square = { at[1] - c, at[2] - c, at[1] + c, at[2] + c }
		Place(h, mask, square[1], square[2], square[3], square[4])
		local laid = 0
		for _, b in ipairs(bands) do
			local x0, y0, x1, y1 = Cut(square, b)
			if x0 then
				laid = laid + 1
				local t = Piece(pool, laid, ART.wood, false, mask)
				Lay(h, t, x0, y0, x1, y1, u, v, TILE, TILE)
				t:SetVertexColor(1, 1, 1, a)
			end
		end
		pool:Done(laid)
	end
	-- The fire: in the char's cracks and the joints, added, your color; faint along the edge, strong where it has
	-- taken hold, never behind what is written.
	local embers = EMBERS[Theme.LookOption("charred", "embers")]
	local base = UI.LookPool(h, "charFire", "BORDER", -1)
	local baseCore = UI.LookPool(h, "charFireCore", "BORDER", 0)
	local fu, fv = UI.LookSeed(h, "fire")
	local glow = Glow()
	local r, gr, bl = Accent(h)
	local hr, hg, hb = Hot(r, gr, bl)
	used = 0
	local function Base(x0, y0, x1, y1, s0, s1, across)
		if x1 - x0 < 0.5 or y1 - y0 < 0.5 then return end
		used = used + 1
		local t = Piece(base, used, ART.ember, true)
		Lay(h, t, x0, y0, x1, y1, fu, fv, TILE, TILE)
		Ramp(t, r, gr, bl, CH.fire * glow * s0, CH.fire * glow * s1, across)
		t = Piece(baseCore, used, ART.core, true)
		Lay(h, t, x0, y0, x1, y1, fu, fv, TILE, TILE)
		Ramp(t, hr, hg, hb, CH.core * glow * s0, CH.core * glow * s1, across)
	end
	-- A spot: the fire through a soft round mask over `square` ({ x0, y0, x1, y1 }), in the bands it crosses.
	local spots = 0
	local function Spot(square, s, within)
		spots = spots + 1
		local mask = h.charSpots[spots]
		Place(h, mask, square[1], square[2], square[3], square[4])
		local fire = UI.LookPool(h, "charSpot" .. spots, "BORDER", -1)
		local hot = UI.LookPool(h, "charSpotCore" .. spots, "BORDER", 0)
		local m = 0
		for _, b in ipairs(within or bands) do
			local x0, y0, x1, y1 = Cut(square, b)
			if x0 then
				m = m + 1
				local t = Piece(fire, m, ART.ember, true, mask)
				Lay(h, t, x0, y0, x1, y1, fu, fv, TILE, TILE)
				t:SetVertexColor(r, gr, bl, min(1, CH.fire * glow * s))
				t = Piece(hot, m, ART.core, true, mask)
				Lay(h, t, x0, y0, x1, y1, fu, fv, TILE, TILE)
				t:SetVertexColor(hr, hg, hb, min(1, CH.core * glow * s))
			end
		end
		fire:Done(m)
		hot:Done(m)
	end
	if embers then
		local su, sv = UI.LookSeed(h, "hot")
		local corners = { { X0, Y1 }, { X1, Y1 }, { X0, Y0 }, { X1, Y0 } }
		if head > 0 then
			-- Along the head's top, and at its far end, away from the title.
			if embers.headBase > 0 then Base(X0, Y0, X1, Y0 + 4, embers.headBase, 0) end
			local q = embers.corner * 0.7
			Spot({ X1 - q, Y0 - q, X1 + q, Y0 + q }, embers.headSpot, { { X0, Y0, X1, head - 3 } })
			if embers.low then
				local q2 = embers.low
				Spot({ X0 - q2, Y1 - q2, X0 + q2, Y1 + q2 }, embers.headSpot)
			end
		else
			if placed and embers.base > 0 then
				local wl = wells[1]
				Base(X0, Y0, X1, wl[2], embers.base, 0)
				Base(X0, wl[4], X1, Y1, 0, embers.base)
				Base(X0, wl[2], wl[1], wl[4], embers.base, 0, true)
				Base(wl[3], wl[2], X1, wl[4], 0, embers.base, true)
			end
			-- A corner (the piece's own pick) and a short stretch of the foot away from it.
			local at = corners[floor(su * 4) % 4 + 1]
			local q = embers.corner
			Spot({ at[1] - q, at[2] - q, at[1] + q, at[2] + q }, embers.spot)
			local f = 0.3 + 0.25 * sv
			local fx = at[1] == X0 and X1 - (X1 - X0) * f or X0 + (X1 - X0) * f
			local hw, hh = embers.foot[1], embers.foot[2]
			Spot({ fx - hw, Y1 - hh, fx + hw, Y1 + hh }, embers.spot)
			if embers.far then
				local tx = at[1] == X0 and X1 - (X1 - X0) * (1 - f) or X0 + (X1 - X0) * (1 - f)
				hw, hh = embers.far[1], embers.far[2]
				Spot({ tx - hw, Y0 - hh, tx + hw, Y0 + hh }, embers.spot * 0.8)
			end
		end
	end
	base:Done(used)
	baseCore:Done(used)
	for i = spots + 1, #h.charSpots do
		UI.LookPool(h, "charSpot" .. i, "BORDER", -1):Done(0)
		UI.LookPool(h, "charSpotCore" .. i, "BORDER", 0):Done(0)
	end
	-- The foot band's seam: burnt in along its top, the fire along it, dimmer than the head's.
	local seam = UI.LookPool(h, "charFootSeam", "ARTWORK", -1)
	if foot > 0 and g.well then
		local y = tall - foot
		local groove = Piece(seam, 1, ART.groove)
		Lay(h, groove, X0 + 1, y - SEAM_H / 2, X1 - 1, y + SEAM_H / 2, u + 0.16, 0, TILE, SEAM_H)
		groove:SetVertexColor(1, 1, 1, 0.8)
		local fire = Piece(seam, 2, ART.seam, true)
		Lay(h, fire, X0 + 1, y - SEAM_H / 2, X1 - 1, y + SEAM_H / 2, u + 0.16, 0, TILE, SEAM_H)
		fire:SetVertexColor(r, gr, bl, min(1, CH.footSeam * glow))
		seam:Done(2)
	else
		seam:Done(0)
	end
	-- The boards' grain, over their fill.
	local boards = UI.LookPool(h, "charBoard", "BACKGROUND", -1)
	used = 0
	for _, wl in ipairs(wells) do
		used = used + 1
		local t = Piece(boards, used, ART.planed)
		Lay(h, t, wl[1], wl[2], wl[3], wl[4], u, v, TILE, PLANED)
		t:SetVertexColor(1, 1, 1, CH.plain * k)
	end
	boards:Done(used)
end

-- A header's line: a seam burnt in, a groove of char with the fire along it, tiling across from the piece's own
-- place on the sheet.
local function Seam(owner, line, strip)
	local groove = owner:CreateTexture(nil, "ARTWORK", nil, -1)
	local fire = owner:CreateTexture(nil, "ARTWORK", nil, -1)
	UI.LookWear(groove, ART.groove, "REPEAT", "CLAMP")
	UI.LookWear(fire, ART.seam, "REPEAT", "CLAMP")
	fire:SetBlendMode("ADD")
	local strength = strip and CH.seam or CH.bareSeam
	Theme.Tint(fire, function()
		local r, g, b = Accent(owner)
		return r, g, b, min(1, strength * Glow())
	end)
	local u = UI.LookSeed({ owner = owner }, "seam")
	for _, t in ipairs({ groove, fire }) do
		t:SetPoint("TOPLEFT", line, "LEFT", 0, SEAM_H / 2)
		t:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -SEAM_H / 2)
	end
	local function Tile()
		local wide = groove:GetWidth()
		if not wide or issecretvalue(wide) or wide <= 0 then return end
		for _, t in ipairs({ groove, fire }) do t:SetTexCoord(u, u + wide / TILE, 0, 1) end
	end
	groove.charTile = Tile   -- laid again with the housing (its art may have been given back since)
	-- (A game frame that is protected can't take a hook in a fight: its seam keeps the width it was laid at.)
	if owner.HookScript and owner:HasScript("OnSizeChanged") and not (InCombatLockdown() and owner:IsProtected()) then
		owner:HookScript("OnSizeChanged", Tile)
	end
	Tile()
	C_Timer.After(0, Tile)
	return { groove, fire }
end

Shy:On("SHY_THEME", function()
	for h in pairs(worn) do
		if h.look == "charred" then UI.LookFit(h, true) else worn[h] = nil end
	end
end)

-- A button: a burnt plank in the burnt edge, its face the planed board, calm at rest; under the mouse or held, an
-- ember along its foot (the fire and its core, dying away upward), in your color.
-- The primary is the plank scorched in your color, its ember lit at rest; the hover is the ember (no wash), with a
-- little light along the top.
local KEY_IN, KEY_EMBER, KEY_SMOULDER = 1.5, 5, 0.6   -- the face's inset; how far up the ember reaches; the primary's at rest
local function KeyLay(f)
	local s = f.charKey
	local w, tall = f:GetSize()
	if not (s and w and tall) or issecretvalue(w) or issecretvalue(tall) then return end
	local fw, ft = max(0, w - 2 * KEY_IN), max(0, tall - 2 * KEY_IN)
	s.grain:SetTexCoord(s.u, s.u + fw / TILE, s.v, s.v + ft / PLANED)
	for _, t in ipairs({ s.ember, s.core }) do t:SetTexCoord(s.u, s.u + fw / TILE, s.v, s.v + KEY_EMBER / TILE) end
end
local function KeyBuild(f)
	local s = {}
	f.charKey = s
	s.u, s.v = UI.LookSeed({ owner = f }, "key")
	s.grain = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	UI.LookWear(s.grain, ART.planed, "REPEAT", "REPEAT")
	s.grain:SetPoint("TOPLEFT", KEY_IN, -KEY_IN)
	s.grain:SetPoint("BOTTOMRIGHT", -KEY_IN, KEY_IN)
	s.ember = f:CreateTexture(nil, "ARTWORK", nil, 2)
	s.core = f:CreateTexture(nil, "ARTWORK", nil, 3)
	for t, file in pairs({ [s.ember] = ART.ember, [s.core] = ART.core }) do
		UI.LookWear(t, file, "REPEAT", "REPEAT")
		t:SetBlendMode("ADD")
		t:SetPoint("BOTTOMLEFT", KEY_IN, KEY_IN)
		t:SetPoint("BOTTOMRIGHT", -KEY_IN, KEY_IN)
		t:SetHeight(KEY_EMBER)
	end
	if not (InCombatLockdown() and f:IsProtected()) then f:HookScript("OnSizeChanged", KeyLay) end
	KeyLay(f)
	return { s.grain, s.ember, s.core }
end
local function KeyMark(f, lit, down, primary)
	local s = f.charKey
	if not s then return end
	s.grain:SetVertexColor(1, 1, 1, primary and 0.3 or CH.plain)
	-- The primary smoulders at rest, softer than under the mouse.
	local burning = (lit or down) and 1 or primary and KEY_SMOULDER or nil
	s.ember:SetShown(burning ~= nil)
	s.core:SetShown(burning ~= nil)
	if burning then
		local r, g, b = Accent(f)
		local glow = Glow() * burning
		Ramp(s.ember, r, g, b, 0, min(1, CH.fire * glow))
		local hr, hg, hb = Hot(r, g, b)
		Ramp(s.core, hr, hg, hb, 0, min(1, CH.core * glow))
	end
	KeyLay(f)
end
UI.KEY_MAKES.charred = { edge = { ART.edge, SLICE }, rim = "dark", hot = true, prime = "dye", dye = 0.4,
	hover = { lift = 0, light = 0.2 }, build = KeyBuild, mark = KeyMark }

UI.LookKind("charred", {
	name = "Charred",
	strength = 82,
	words = "Burnt wood with fire still glowing in your color in the cracks.",
	short = "Charred wood, still burning",
	zones = {
		well = { color = CH.board, alpha = CH.boardA, solid = 1, art = ART.well, slice = SLICE, IN = IN, GAP = 1 },
		footWell = { color = CH.board, alpha = CH.boardA, solid = 1, art = ART.well, slice = SLICE, IN = IN },
	},
	options = {
		{ key = "embers", label = "Embers", kind = "choice", default = "few",
			choices = { { value = "off", text = "Off" }, { value = "few", text = "Few" }, { value = "many", text = "Many" } },
			desc = "How much of the wood is still burning." },
		{ key = "glow", label = "Glow", kind = "slider", min = 0, max = 100, step = 5, default = CH.glow,
			desc = "How bright the fire in the wood burns." },
	},
	alpha = function(a) return 1 - (1 - a) ^ 2 end,
	fill = function(r, g, b, a)
		r, g, b = UI.LookBlend(r, g, b, CH.char[1], CH.char[2], CH.char[3], CH.tone)
		return r, g, b, a
	end,
	strip = function(_, _, _, a) return 0, 0, 0, a * CH.head, false end,
	toneFill = function(r, g, b) return UI.LookBlend(r, g, b, CH.char[1], CH.char[2], CH.char[3], CH.tone * 0.6) end,
	shade = CH.shade,
	surface = { file = ART.planed, alpha = CH.plain },   -- a plaque or a card: planed boards, as its buttons
	inset = CH.inset,
	border = 5,
	rims = false,
	-- The wood, its char and its fire lie across the whole face (round a content's boards, and the boards under it);
	-- only the burnt edge is the edge's.
	face = { "charPlain", "charBand", "charCorner1", "charCorner2", "charCorner3", "charCorner4", "charFire", "charFireCore",
		"charSpot1", "charSpot2", "charSpot3", "charSpotCore1", "charSpotCore2", "charSpotCore3", "charFootSeam", "charBoard" },
	edge = { "charEdge" },
	bar = "ember",   -- char, still burning in its cracks
	slot = "sunken",
	ground = "char",   -- char under the icons, fire still in its cracks
	build = function(h, kit)
		local edge = kit.Reg("charEdge", kit.owner:CreateTexture(nil, "BORDER"))
		UI.LookWear(edge, ART.edge, nil, nil, SLICE)
		kit.Out(edge, 0)
		-- The masks: a blot at each corner (the char) and at each spot the fire has taken hold of. What they cut lies
		-- over the face, so they go with it under a content the housing stands over (h.faceMasks, UI.LookFace).
		h.charCorners, h.charSpots = {}, {}
		h.faceMasks = h.faceMasks or {}
		for i = 1, 4 do
			h.charCorners[i] = UI.LookWear(kit.owner:CreateMaskTexture(), ART.blot, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			h.faceMasks[#h.faceMasks + 1] = h.charCorners[i]
		end
		for i = 1, 3 do
			h.charSpots[i] = UI.LookWear(kit.owner:CreateMaskTexture(), ART.blot, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			h.faceMasks[#h.faceMasks + 1] = h.charSpots[i]
		end
	end,
	dress = function(h)
		h.charEdge:Show()
	end,
	fit = Fit,
	line = Seam,
	lineAlpha = 0,
})
