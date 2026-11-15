-- The grove look: every housing grown round with a garden, the Garden option saying which:
--   Wild grove     vines braided along each side with leaves and blossoms; bouquets of great leaves, hibiscus and
--                  orchids at the top corners, mossy mounds with ferns and glowing mushrooms at the foot; pearls;
--                  a canopy of leaves behind the piece, shafts of light through it; fireflies
--   Deep woods     bark-covered branches and fallen sticks along the edges, ivy, shelf fungi, hanging moss; oak leaves
--                  and acorns, a cut log, red toadstools at the corners; trunks fading into the dark behind
--   Flower garden  a climbing rose along each side thick with roses, daisies, lavender and blossom; tulips and a
--                  spray of cherry blossom at the corners, butterflies; petals drifting down behind the piece
--   Gem cave       a ledge of dark fractured rock along each side, druses of crystals in your color grown out of it,
--                  their glow on the rock; raw gems broken through the rock in pockets, veins of gold and pyrite; at
--                  the corners a knot of rock the gem grows from, a boulder under it at the foot; the cave wall
--                  behind; glints of light
-- In every corner one of the game's gems grows as it does in nature (the Gem option: one you pick, or Assorted, a gem
-- of each window's own that it keeps, or Mixed, a gem of each corner's own), or crystals in your color.
-- Each garden has its own bar fill, icon frame and well. The game runs every movement itself (the light breathing,
-- a star now and then on a gem, the motes: the kit's UI.LookBreath, LookTwinkle and LookDrift): no Lua a frame, and
-- none on a housing not shown.
local UI, Theme = Shy.UI, Shy.Theme
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend
local floor, min = math.floor, math.min

local SLAB = UI.LookSlab
local WHITE = { 1, 1, 1 }
local TONE, STRIP = 0.84, 0.45   -- how far the fill leans to the garden's tone, and how much further the strip leans

-- The measures (units). A corner's art is CORNER a side (the sprig's SPRIG), the plate's corner PLATE of it in from
-- its outer edges; a corner is SHARE of the piece's shorter side (MOST at most), lush from LUSH_AT, a sprig under
-- it, none under LEAST; Trim keeps every corner a sprig, TRIM at most. A gem's specimen is SPEC of the corner (its art
-- 32 a side: the plate's corner TOP_AT in from a top one's outer edges, FOOT_AT from a foot one's outer side and
-- top). A side's run: a band OUT outside the edge and IN inside, VINE long (tiling). A head's line: LINE long,
-- LINE_BAND tall; at its middle, on a line WREATH_LEAST wide, a wreath (WREATH) and a gem (LINE_GEM, the line's
-- middle LINE_AT in it). The face: a tile FACE a side; its strength and the rays' the garden's own, both following
-- the Background strength on screen. The light breathes from 1 to BREATH[1] and back over BREATH[2] seconds (each
-- corner its own pace, BREATH_STEP apart); a gem's star shows for STAR[1] seconds, every STAR[2] to STAR[3]. Motes:
-- one for each MOTE_AREA square units of a piece (MOTES at most), each MOTE across, drifting MOTE_RISE over
-- MOTE_TIME[1] to MOTE_TIME[2] seconds, from a place MOTE_CLEAR clear of the edge.
local M = {
	CORNER = 96, SPRIG = 40, PLATE = 30 / 96, MOST = 88, SHARE = 0.57, LUSH_AT = 60, LEAST = 18, TRIM = 36,
	SPEC = 0.5, TOP_AT = 20 / 32, FOOT_AT = { 22 / 32, 24 / 32 },
	OUT = 12, IN = 8, VINE = 256,
	LINE = 128, LINE_BAND = 8, WREATH = { 30, 12 }, WREATH_LEAST = 120, LINE_GEM = { 16, 10 }, LINE_AT = { 8, 6 },
	FACE = 256,
	BREATH = { 0.6, 4.2 }, BREATH_STEP = 0.55, STAR = { 0.9, 3.5, 7.5 },
	MOTE_AREA = 7000, MOTES = 8, MOTE = 8, MOTE_RISE = 26, MOTE_TIME = { 5, 9 }, MOTE_CLEAR = 14, MOTE_LIFT = { fall = 0.5, rise = 0.45, glint = 0.45 },
	BORDER = 11, CLEAR = 4,   -- the frame's inner face from the edge: past the garland (IN) and a clear gap; a window's content this much further in
	-- The mini border (h.mini: a piece's simpler companion: a drawer, a card, a plaque, a meter): the garden's own
	-- border at K of its size, its art drawn for that size, with fewer accents. A side's run OUT outside the edge and
	-- IN inside (VINE long, as the border's), running JOIN on past each corner so two sides cross there (a small
	-- piece's corner); a corner the garden's sprig, CORNER a side (MOST; none on a piece with no room for it, LEAST,
	-- which keeps the crossing sides); the finer rim (RIM its slice); no rays, no motes; its frame's inner face BORDER
	-- in. A circle's border (the look's `ring`): the run bent round it, drawn for the circle sizes RINGS, the art
	-- RING_PAD past the circle all round.
	MINI = { K = 0.625, CORNER = 25, MOST = 25, LEAST = 16, OUT = 6.25, IN = 3.75, JOIN = 2.5, RIM = 6, BORDER = 4,
		RINGS = { 46, 33, 24 }, RING_PAD = 8 },
}
local CORNERS = { "TL", "TR", "BL", "BR" }
local SIDES = { "Top", "Foot", "Left", "Right" }
local lines = setmetatable({}, { __mode = "k" })   -- owner -> the sets of its lines (below)
-- The regions' names, written once (a fit names every one of them): each side's three runs, each corner's growth
-- (its own colors, yours, their light, a star: the files' endings beside) and its gem's three, and each mote's salt.
local NAMES = { side = {}, corner = {}, gem = {}, mote = {}, growth = { "", "Key", "Light", "Twinkle" } }
for _, side in ipairs(SIDES) do NAMES.side[side] = { "groveVine" .. side, "groveVineKey" .. side, "groveVineLight" .. side } end
for _, c in ipairs(CORNERS) do
	NAMES.corner[c] = { "groveCorner" .. c, "groveCornerKey" .. c, "groveCornerLight" .. c, "groveCornerStar" .. c }
	NAMES.gem[c] = { "groveGem" .. c, "groveGemKey" .. c, "groveGemLight" .. c }
end
for i = 1, M.MOTES do NAMES.mote[i] = "mote" .. i end

-- The gardens: each its files' name, the tone its fill leans to, its face's strength and its rays', how far its
-- light lifts your color toward white (the glow of its gems and mushrooms), how its motes move (rising fireflies,
-- falling petals, glints in place), the color its buttons warm to under the mouse, and its bars' fill, its icons'
-- frame and their well.
local WORLDS = {
	wild = { files = "Wild", tone = { 0.014, 0.034, 0.022 }, face = 0.5, rays = 0.16, glow = 0.55, motes = "rise",
		hover = { 0.70, 0.95, 0.70 }, bar = "gem", slot = "vine", ground = "moss" },
	woods = { files = "Woods", tone = { 0.022, 0.02, 0.013 }, face = 0.55, rays = 0.22, glow = 0.5, motes = "rise",
		hover = { 0.85, 0.78, 0.60 }, bar = "bark", slot = "vine", ground = "moss" },
	flowers = { files = "Flowers", tone = { 0.03, 0.024, 0.03 }, face = 0.45, rays = 0.14, glow = 0.6, motes = "fall",
		hover = { 1.0, 0.80, 0.88 }, bar = "gem", slot = "vine", ground = "moss" },
	cave = { files = "Cave", tone = { 0.012, 0.012, 0.022 }, face = 0.92, rays = 0, glow = 0.25, motes = "glint",
		hover = { 0.62, 0.74, 1.0 }, bar = "gem", slot = "gilt", ground = "obsidian" },
}

-- The game's gems (their item IDs: each choice shows its icon), each drawn as it grows in nature; "accent" crystals
-- in your color.
local GEMS = {
	{ key = "Malachite", text = "Malachite", item = 774 },
	{ key = "Tigerseye", text = "Tigerseye", item = 818 },
	{ key = "Shadowgem", text = "Shadowgem", item = 1210 },
	{ key = "MossAgate", text = "Moss Agate", item = 1206 },
	{ key = "Moonstone", text = "Lesser Moonstone", item = 1705 },
	{ key = "Jade", text = "Jade", item = 1529 },
	{ key = "Citrine", text = "Citrine", item = 3864 },
	{ key = "Aquamarine", text = "Aquamarine", item = 7909 },
	{ key = "StarRuby", text = "Star Ruby", item = 7910 },
	{ key = "Opal", text = "Large Opal", item = 12799 },
	{ key = "Sapphire", text = "Blue Sapphire", item = 12361 },
	{ key = "Diamond", text = "Azerothian Diamond", item = 12800 },
	{ key = "Emerald", text = "Huge Emerald", item = 12364 },
	{ key = "Arcane", text = "Arcane Crystal", item = 12363 },
	{ key = "BlackDiamond", text = "Black Diamond", item = 11754 },
	{ key = "Souldarite", text = "Souldarite", item = 19774 },
	{ key = "Fel", text = "Fel Crystal", item = 248819 },
	{ key = "Torbernite", text = "Torbernite", item = 248820 },
	{ key = "Pyrite", text = "Pyrite", item = 249391 },
	{ key = "Quartz", text = "Huge Quartz Gem", item = 272015 },
	{ key = "Corrupted", text = "Corrupted Gemstone", item = 277154 },
}
local GEM_KEY = { accent = "Key" }
local GEM_KEYS = {}   -- the gems' files' keys, in order: a piece's own pick is one of these
for _, gem in ipairs(GEMS) do
	GEM_KEY[gem.key] = gem.key
	GEM_KEYS[#GEM_KEYS + 1] = gem.key
end

local function Option(x, key)
	return UI.LookOption(x, key, "grove")
end

-- The garden a housing (or a line's owner, a button) is grown round with: its own (a card showing a preset), else
-- the theme's.
local function World(x)
	local key = Option(x, "garden")
	return WORLDS[key] or WORLDS.wild
end

-- The gem a housing (or a line's owner) grows in a corner: its files' key ("Key" for your color). Assorted: one gem
-- of the piece's own, the same every time (UI.LookPick: for good on a named window); Mixed: a gem of each corner's
-- own (the line's its top left's).
local function Gem(x, corner)
	local pick = Option(x, "gem")
	if pick == "assorted" then return UI.LookPick(x, GEM_KEYS, "gem") end
	if pick == "mixed" then return UI.LookPick(x, GEM_KEYS, "gem" .. (corner or "TL")) end
	return GEM_KEY[pick] or "Key"
end

-- How far the face's parts follow the Background strength on screen; whole in a window.
local function Through(h)
	return h.solid and 1 or Theme.Strength() ^ 0.5
end

-- Your color lifted toward white: the light the garden gives off.
local function Lifted(accent, k)
	return function()
		local r, g, b = accent()
		return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
	end
end

-- ------------------------------------------------------------------ the movement (the kit's: UI.LookBreath and kin)
local function Breath(t, period)
	UI.LookBreath(t, period, M.BREATH[1])
end
local Twinkle, Still = UI.LookTwinkle, UI.LookStill
local function Drift(t, rise, time)
	UI.LookDrift(t, 0, rise, time)
end

-- ------------------------------------------------------------------ built, dressed, fitted
local function Build(h, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel)
		return kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
	end
	-- The face: the garden behind the piece, the shafts of light.
	Tex("groveFace", "BACKGROUND", -5)
	kit.Out(h.groveFace, -1)
	UI.LookWear(Tex("groveRays", "BACKGROUND", -4), MEDIA .. "GroveRays")
	h.groveRays:SetBlendMode("ADD")
	kit.Out(h.groveRays, -1)
	-- The edge: its shade, then each side's run (its own colors, what is in your color, its light).
	UI.LookWear(Tex("groveRim", "BORDER", 0), MEDIA .. "GroveRim", nil, nil, 8)
	kit.Out(h.groveRim, 0)
	for _, side in ipairs(SIDES) do
		Tex("groveVine" .. side, "BORDER", 1)
		Tex("groveVineKey" .. side, "BORDER", 2)
		Tex("groveVineLight" .. side, "BORDER", 3):SetBlendMode("ADD")
	end
	-- Each corner: its growth (its own colors, what is in your color, their light, a star), and its gem.
	for _, c in ipairs(CORNERS) do
		Tex("groveCorner" .. c, "ARTWORK", 0)
		Tex("groveCornerKey" .. c, "ARTWORK", 1)
		Tex("groveCornerLight" .. c, "ARTWORK", 2):SetBlendMode("ADD")
		Tex("groveCornerStar" .. c, "ARTWORK", 3):SetBlendMode("ADD")
		Tex("groveGem" .. c, "OVERLAY", 0)
		Tex("groveGemKey" .. c, "OVERLAY", 1)
		Tex("groveGemLight" .. c, "OVERLAY", 2):SetBlendMode("ADD")
	end
end

-- The hands a housing's corners are drawn in (its top's, its foot's): its own, the same every time it is asked. Asked
-- by whichever comes first, its dress or its fit (a line laid while the housing is dressed can fit it first).
local function Hands(h)
	if not h.groveHands then
		local top, foot = UI.LookSeed(h, "hands")
		h.groveHands = { top < 0.5 and 1 or 2, foot < 0.5 and 1 or 2 }
	end
	return h.groveHands
end

-- A corner's files: its growth's (the garden's, the hand, left or right, the level) and its gem's.
local function CornerFiles(h, c, level)
	local foot = c:sub(1, 1) == "B"
	local side = c:sub(2, 2) == "R" and "R" or "L"
	local hand = Hands(h)[foot and 2 or 1]
	local growth = MEDIA .. "Grove" .. World(h).files .. (foot and "Foot" or "Top") .. hand .. side .. level
	local gem = Gem(h, c)
	if level == "Mini" then
		-- (The mini's corner is the sprig, one hand.)
		growth = MEDIA .. "Grove" .. World(h).files .. "Mini" .. (foot and "Foot" or "Top") .. side
		return growth, MEDIA .. "GroveGem" .. gem .. "Mini" .. (foot and "Foot" or "Top") .. side, gem ~= "Key"
	end
	return growth, MEDIA .. "GroveGem" .. gem .. (foot and "Foot" or "Top") .. side .. level, gem ~= "Key"
end

local function Dress(h)
	local world = World(h)
	local accent = UI.LookAccent(h)
	local glow = Lifted(accent, world.glow)
	local files = MEDIA .. "Grove" .. world.files
	local mini = h.mini == true
	UI.LookWear(h.groveFace, files .. "Face", "REPEAT", "REPEAT")
	Theme.Tint(h.groveFace, function() return 1, 1, 1, world.face * Through(h) end)
	Theme.Tint(h.groveRays, function()
		local r, g, b = glow()
		return r, g, b, world.rays * Through(h)
	end)
	Breath(h.groveRays, M.BREATH[2] * 2)
	h.groveFace:Show()
	h.groveRays:SetShown(world.rays > 0 and not mini)
	UI.LookWear(h.groveRim, MEDIA .. (mini and "GroveRimMini" or "GroveRim"), nil, nil, mini and M.MINI.RIM or 8)
	h.groveRim:Show()
	for i, side in ipairs(SIDES) do
		local across = i <= 2
		local wrapH, wrapV = across and "REPEAT" or "CLAMP", across and "CLAMP" or "REPEAT"
		local run = files .. (mini and "Mini" or "Vine") .. side
		UI.LookWear(h["groveVine" .. side], run, wrapH, wrapV)
		UI.LookWear(h["groveVineKey" .. side], run .. "Key", wrapH, wrapV)
		UI.LookWear(h["groveVineLight" .. side], run .. "Light", wrapH, wrapV)
		Theme.Tint(h["groveVine" .. side], WHITE, 1)
		Theme.Tint(h["groveVineKey" .. side], accent, 1)
		Theme.Tint(h["groveVineLight" .. side], glow, 1)
		Breath(h["groveVineLight" .. side], M.BREATH[2] + i * M.BREATH_STEP * 0.5)
	end
	for i, c in ipairs(CORNERS) do
		Theme.Tint(h["groveCorner" .. c], WHITE, 1)
		Theme.Tint(h["groveCornerKey" .. c], accent, 1)
		Theme.Tint(h["groveCornerLight" .. c], glow, 1)
		Theme.Tint(h["groveCornerStar" .. c], WHITE, 1)
		Theme.Tint(h["groveGem" .. c], WHITE, 1)
		Theme.Tint(h["groveGemKey" .. c], accent, 1)
		Theme.Tint(h["groveGemLight" .. c], Gem(h, c) ~= "Key" and WHITE or glow, 1)
		local pace = M.BREATH[2] + (i - 1) * M.BREATH_STEP
		Breath(h["groveCornerLight" .. c], pace)
		Breath(h["groveGemLight" .. c], pace + M.BREATH_STEP / 2)
		local u = UI.LookSeed(h, "star" .. c)
		Twinkle(h["groveCornerStar" .. c], M.STAR[2] + u * (M.STAR[3] - M.STAR[2]))
	end
	-- The lines on this housing's own owner, as it wears its garden and its gem now.
	for _, set in ipairs(lines[h.owner] or {}) do set.lay() end
end

-- A region hung from one corner of the plate: its `point` on the plate's `at`, x and y from there.
local function Hang(t, g, point, at, x, y)
	t:SetPoint(point, g.to, at, x, y)
end

-- The sides' runs laid along their edges, each a band OUT outside its edge and IN inside, running J on past each
-- corner: hung from the edge itself, so a piece of another size moves none of them.
local function Bands(h, g, OUT, IN, J)
	local i = g.inset
	for _, name in ipairs(NAMES.side.Top) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, "TOPLEFT", "TOPLEFT", i[1] - J, -i[2] + OUT)
		Hang(t, g, "BOTTOMRIGHT", "TOPRIGHT", -i[3] + J, -i[2] - IN)
	end
	for _, name in ipairs(NAMES.side.Foot) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, "TOPLEFT", "BOTTOMLEFT", i[1] - J, i[4] + IN)
		Hang(t, g, "BOTTOMRIGHT", "BOTTOMRIGHT", -i[3] + J, i[4] - OUT)
	end
	for _, name in ipairs(NAMES.side.Left) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, "TOPLEFT", "TOPLEFT", i[1] - OUT, -i[2] + J)
		Hang(t, g, "BOTTOMRIGHT", "BOTTOMLEFT", i[1] + IN, i[4] - J)
	end
	for _, name in ipairs(NAMES.side.Right) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, "TOPLEFT", "TOPRIGHT", -i[3] - IN, -i[2] + J)
		Hang(t, g, "BOTTOMRIGHT", "BOTTOMRIGHT", -i[3] + OUT, i[4] - J)
	end
end

-- One side's three runs: where along the tile they start, and how much of it they show.
local function Run(h, side, at, across, long)
	for _, name in ipairs(NAMES.side[side]) do
		if across then h[name]:SetTexCoord(at, at + long, 0, 1) else h[name]:SetTexCoord(0, 1, at, at + long) end
	end
end

-- A corner's growth D a side, the plate's corner p in from its outer edges, and its gem s a side where the art has
-- the plate's corner: each hung from its own corner of the plate.
local function Corner(h, g, c, D, p, s)
	local right, foot = c:sub(2, 2) == "R", c:sub(1, 1) == "B"
	local i = g.inset
	local point = (foot and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT")
	local x = right and -i[3] + p or i[1] - p
	local y = foot and i[4] - p or -i[2] + p
	for _, name in ipairs(NAMES.corner[c]) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, point, point, x, y)
		t:SetSize(D, D)
	end
	local ax = foot and M.FOOT_AT[1] * s or M.TOP_AT * s
	local ay = foot and M.FOOT_AT[2] * s or M.TOP_AT * s
	local top = right and "TOPRIGHT" or "TOPLEFT"
	local gx = right and -i[3] + ax or i[1] - ax
	local gy = foot and i[4] + ay or -i[2] + ay
	for _, name in ipairs(NAMES.gem[c]) do
		local t = h[name]
		t:ClearAllPoints()
		Hang(t, g, top, point, gx, gy)
		t:SetSize(s, s)
	end
end

local function Fit(h, g)
	local world = World(h)
	local w, tall = g.w or 0, g.tall or 0
	-- The face, a texel a unit, from a place of the piece's own; the rays over the whole of it.
	local u, v = UI.LookSeed(h, "canopy")
	h.groveFace:SetTexCoord(u, u + w / M.FACE, v, v + tall / M.FACE)
	-- The runs along the sides: each from a place of its own along the tile. (A mini's sides run J on past each
	-- corner, crossing there.) Hung once a dress; a fit lays only how much of the tile each shows.
	local a, b = UI.LookSeed(h, "garland")
	local mini = h.mini == true
	local OUT, IN, RUN, J = M.OUT, M.IN, M.VINE, 0
	if mini then OUT, IN, J = M.MINI.OUT, M.MINI.IN, M.MINI.JOIN end
	local dressed = h.dressed or 0   -- (0: fitted before its first dress, as a head's line laid while it is dressed can)
	local was = h.groveLaid
	if not was then
		was = {}
		h.groveLaid = was
	end
	if was.bands ~= dressed then
		was.bands, was.sides = dressed, nil
		Bands(h, g, OUT, IN, J)
	end
	local wide, high = (w + 2 * J) / RUN, (tall + 2 * J) / RUN
	Run(h, "Top", a, true, wide)
	Run(h, "Foot", (a + 0.37) % 1, true, wide)
	Run(h, "Left", b, false, high)
	Run(h, "Right", (b + 0.53) % 1, false, high)
	local shown = w >= 2 * IN and tall >= 2 * IN
	if was.sides ~= shown then
		was.sides = shown
		for _, side in ipairs(SIDES) do
			for _, name in ipairs(NAMES.side[side]) do h[name]:SetShown(shown) end
		end
	end
	-- The corners: as big as the piece has room for; the sprig on a small piece (or always, trimmed).
	local trim = Option(h, "growth") == "trim"
	local D = floor(min(trim and M.TRIM or M.MOST, min(w, tall) * M.SHARE))
	local lush = not trim and D >= M.LUSH_AT
	local level = lush and M.CORNER or M.SPRIG
	local grown = D >= M.LEAST
	if mini then
		-- The mini's corner: the sprig drawn for it, never larger than drawn; none on a piece too small for it.
		D, level = floor(min(M.MINI.MOST, min(w, tall) * M.SHARE)), "Mini"
		grown = D >= M.MINI.LEAST
	end
	-- A corner's art is the piece's for a dress and a level, its place for a dress and a size, and what of it shows
	-- for a dress and whether it has grown: each set when it is another (a piece gliding wider keeps all three).
	local owns = h.groveOwn or {}   -- corner -> its gem is one of the game's (no crystals of your color on it)
	h.groveOwn = owns
	if was.art ~= dressed or was.level ~= level then
		was.art, was.level = dressed, level
		for _, c in ipairs(CORNERS) do
			local growth, gem, own = CornerFiles(h, c, level)
			owns[c] = own
			for i, name in ipairs(NAMES.corner[c]) do UI.LookWear(h[name], growth .. NAMES.growth[i]) end
			UI.LookWear(h[NAMES.gem[c][1]], gem)
			UI.LookWear(h[NAMES.gem[c][2]], own and gem or gem .. "Key")
			UI.LookWear(h[NAMES.gem[c][3]], gem .. "Light")
		end
	end
	if was.corners ~= dressed or was.D ~= D then
		was.corners, was.D = dressed, D
		for _, c in ipairs(CORNERS) do Corner(h, g, c, D, D * M.PLATE, D * M.SPEC) end
	end
	if was.grown ~= dressed or was.grew ~= grown then
		was.grown, was.grew = dressed, grown
		for _, c in ipairs(CORNERS) do
			for _, name in ipairs(NAMES.corner[c]) do h[name]:SetShown(grown) end
			h[NAMES.gem[c][1]]:SetShown(grown)
			h[NAMES.gem[c][2]]:SetShown(grown and not owns[c])
			h[NAMES.gem[c][3]]:SetShown(grown)
		end
	end
	-- The motes over the face, as many as the piece is big, each from a place of its own: fireflies rising, petals
	-- falling, or glints coming and going where they are. A mote is dressed once a dress (its art, its light) and
	-- set moving once: a fit only puts it where the piece's size has it now.
	local pool = UI.LookPool(h, "groveMote", "BACKGROUND", -3, true)
	local count = 0
	if not mini and Option(h, "motes") ~= false and w > 2 * M.MOTE_CLEAR and tall > 2 * M.MOTE_CLEAR + M.MOTE_RISE then
		count = min(M.MOTES, floor(w * tall / M.MOTE_AREA))
	end
	local kind = world.motes
	local light
	for i = 1, count do
		local t = pool:Get(i)
		if t.groveDressed ~= h.dressed then
			t.groveDressed = h.dressed
			light = light or Lifted(UI.LookAccent(h), M.MOTE_LIFT[kind] or 0.45)
			UI.LookWear(t, MEDIA .. "Grove" .. world.files .. "Mote")
			t:SetBlendMode(kind == "fall" and "BLEND" or "ADD")
			Theme.Tint(t, light, 1)
			t:SetSize(M.MOTE, M.MOTE)
		end
		local fx, fy = UI.LookSeed(h, NAMES.mote[i])
		local mx = M.MOTE_CLEAR + fx * (w - 2 * M.MOTE_CLEAR)
		local my = M.MOTE_CLEAR + fy * (tall - 2 * M.MOTE_CLEAR - M.MOTE_RISE) + (kind == "fall" and 0 or M.MOTE_RISE)
		t:ClearAllPoints()
		t:SetPoint("CENTER", g.to, "TOPLEFT", g.inset[1] + mx, -g.inset[2] - my)
		t:Show()
		if t.groveMove ~= kind then
			Still(t)
			t.groveMove = kind
		end
		local time = M.MOTE_TIME[1] + fy * (M.MOTE_TIME[2] - M.MOTE_TIME[1])
		if kind == "rise" then
			Drift(t, M.MOTE_RISE * (0.7 + 0.3 * fx), time)
		elseif kind == "fall" then
			Drift(t, -M.MOTE_RISE * (0.7 + 0.3 * fx), time * 1.3)
		else
			Twinkle(t, time * 0.6, 1.6)
		end
	end
	for i = count + 1, #pool.list do
		local t = pool.list[i]
		if t.groveMove then
			Still(t)
			t.groveMove = nil
		end
	end
	pool:Done(count)
end

-- ------------------------------------------------------------------ a head's line
-- The garden's own run along it (from a place of the piece's own; what is in your color on a layer of its own), and
-- on a line wide enough a wreath at its middle with the piece's gem standing in it; the line itself put away. Laid again when the line changes width and when the
-- piece is dressed (its garden or its gem may have changed).
local function Line(owner, line)
	local set = { owner = owner, line = line }
	local function Tex(sublevel, blend)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, sublevel)
		if blend then t:SetBlendMode(blend) end
		return t
	end
	set.vine, set.vineKey = Tex(4), Tex(4)
	for _, t in ipairs({ set.vine, set.vineKey }) do
		t:SetPoint("TOPLEFT", line, "LEFT", 0, M.LINE_BAND / 2)
		t:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -M.LINE_BAND / 2)
	end
	set.wreath, set.wreathKey = Tex(5), Tex(5)
	for _, t in ipairs({ set.wreath, set.wreathKey }) do
		t:SetSize(M.WREATH[1], M.WREATH[2])
		t:SetPoint("CENTER", line, "CENTER")
	end
	set.gem, set.key, set.light = Tex(6), Tex(7), Tex(7, "ADD")
	for _, t in ipairs({ set.gem, set.key, set.light }) do
		t:SetSize(M.LINE_GEM[1], M.LINE_GEM[2])
		t:SetPoint("TOPLEFT", line, "CENTER", -M.LINE_AT[1], M.LINE_AT[2])
	end
	set.u = UI.LookSeed({ owner = owner }, "line")
	-- Dressed (its garden's art, its gem, their colors) when its piece is, and laid by its width; `sized`: only laid,
	-- and only at another width (its owner's size script runs at every step of a glide).
	function set.lay(sized)
		if sized ~= true then
			local world = World(owner)
			local gem = Gem(owner)
			local own = gem ~= "Key"
			local file = MEDIA .. "GroveGem" .. gem .. "Line"
			local accent = UI.LookAccent(owner)
			UI.LookWear(set.vine, MEDIA .. "Grove" .. world.files .. "Line", "REPEAT", "CLAMP")
			UI.LookWear(set.vineKey, MEDIA .. "Grove" .. world.files .. "LineKey", "REPEAT", "CLAMP")
			UI.LookWear(set.wreath, MEDIA .. "Grove" .. world.files .. "Wreath")
			UI.LookWear(set.wreathKey, MEDIA .. "Grove" .. world.files .. "WreathKey")
			UI.LookWear(set.gem, file)
			UI.LookWear(set.key, own and file or file .. "Key")
			UI.LookWear(set.light, file .. "Light")
			Theme.Tint(set.vine, WHITE, 1)
			Theme.Tint(set.vineKey, accent, 1)
			Theme.Tint(set.wreath, WHITE, 1)
			Theme.Tint(set.wreathKey, accent, 1)
			Theme.Tint(set.gem, WHITE, 1)
			Theme.Tint(set.key, accent, 1)
			Theme.Tint(set.light, own and WHITE or Lifted(accent, world.glow), 1)
			set.own, set.wide = own, nil
		end
		local w = line:GetWidth()
		if not w or issecretvalue(w) or w <= 0 or w == set.wide then return end
		set.wide = w
		local u, own = set.u, set.own
		set.vine:SetTexCoord(u, u + w / M.LINE, 0, 1)
		set.vineKey:SetTexCoord(u, u + w / M.LINE, 0, 1)
		local crowned = w >= M.WREATH_LEAST
		set.wreath:SetAlpha(crowned and 1 or 0)
		set.wreathKey:SetAlpha(crowned and 1 or 0)
		set.gem:SetAlpha(crowned and 1 or 0)
		set.key:SetAlpha((crowned and not own) and 1 or 0)
		set.light:SetAlpha(crowned and 1 or 0)
	end
	local function Sized() set.lay(true) end
	local mine = lines[owner] or {}
	lines[owner] = mine
	mine[#mine + 1] = set
	if owner.HookScript and owner:HasScript("OnSizeChanged") then owner:HookScript("OnSizeChanged", Sized) end
	C_Timer.After(0, Sized)
	set.lay()
	return { set.vine, set.vineKey, set.wreath, set.wreathKey, set.gem, set.key, set.light }
end

-- ------------------------------------------------------------------ buttons
-- A button: a slim vine round it for its edge, the garden's face over it, and your color's light inside the vine,
-- brighter under the mouse.
local function KeyBuild(f)
	local glow = f:CreateTexture(nil, "ARTWORK", nil, -1)
	UI.LookWear(glow, MEDIA .. "GroveKeyGlow", nil, nil, 6)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT")
	glow:SetPoint("BOTTOMRIGHT")
	f.groveKey = glow
	return { glow }
end

local function KeyMark(f, lit, _, primary)
	local glow = f.groveKey
	if not glow then return end
	Theme.Tint(glow, Lifted(UI.LookAccent(f), 0.3), (lit or primary) and 0.85 or 0.3)
	glow:SetShown(f.shyPlate ~= false or lit == true)
end

UI.KEY_MAKES.grove = { edge = { MEDIA .. "GroveKey", 6 }, rim = "white", grain = 0.5, face = function() return MEDIA .. "Grove" .. World().files .. "Face" end,
	hover = { color = { 0.70, 0.95, 0.70 }, lift = 0.08, light = 0.2 }, build = KeyBuild, mark = KeyMark }

-- ------------------------------------------------------------------ the kind
local EDGE = { "groveRim" }
for _, side in ipairs(SIDES) do
	for _, part in ipairs({ "groveVine", "groveVineKey", "groveVineLight" }) do EDGE[#EDGE + 1] = part .. side end
end
for _, c in ipairs(CORNERS) do
	for _, part in ipairs({ "groveCorner", "groveCornerKey", "groveCornerLight", "groveCornerStar", "groveGem", "groveGemKey", "groveGemLight" }) do
		EDGE[#EDGE + 1] = part .. c
	end
end

local GEM_CHOICES = { { value = "accent", text = "Your color" }, { value = "assorted", text = "Assorted" }, { value = "mixed", text = "Mixed" } }
for _, gem in ipairs(GEMS) do GEM_CHOICES[#GEM_CHOICES + 1] = { value = gem.key, text = gem.text, item = gem.item } end

local function Tone(r, g, b, k)
	local tone = World().tone
	return Blend(r, g, b, tone[1], tone[2], tone[3], k)
end

UI.LookKind("grove", {
	name = "Grove",
	strength = 72, wells = 100,
	words = "A garden grown round every piece, the game's gems growing in it.",
	short = "Garden",
	options = {
		{ key = "garden", label = "Garden", kind = "choice", default = "wild", desc = "The garden grown round your pieces.",
			choices = { { value = "wild", text = "Wild grove" }, { value = "woods", text = "Deep woods" }, { value = "flowers", text = "Flower garden" },
				{ value = "cave", text = "Gem cave" } } },
		{ key = "gem", label = "Gem", kind = "choice", default = "accent", choices = GEM_CHOICES,
			desc = "The gem growing in your corners: your color's crystals, one gem a window, one gem a corner, or a gem you pick." },
		{ key = "growth", label = "Growth", kind = "choice", default = "lush", desc = "How much the garden grows at the corners.",
			choices = { { value = "lush", text = "Lush" }, { value = "trim", text = "Trim" } } },
		{ key = "motes", label = "Motes", kind = "switch", default = true, desc = "Fireflies, petals or glints drifting behind your pieces." },
	},
	alpha = function(a) return 1 - (1 - a) ^ 1.6 end,
	fill = function(r, g, b, a)
		r, g, b = Tone(r, g, b, TONE)
		return r, g, b, a
	end,
	strip = function(r, g, b, a)
		r, g, b = Tone(r, g, b, TONE)
		r, g, b = Blend(r, g, b, SLAB[1], SLAB[2], SLAB[3], STRIP)
		return r, g, b, a, false
	end,
	toneFill = function(r, g, b) return Tone(r, g, b, 0.55) end,
	shade = 0.8,
	inset = 1,
	border = function(h) return h and h.mini and M.MINI.BORDER or M.BORDER end,
	-- (The garland grows past the piece's edge too: what stands against a piece from outside keeps clear of it.)
	out = function(h) return h and h.mini and M.MINI.OUT or M.OUT end,
	-- The mini border as files, for whoever lays it with no housing (a nameplate: nothing on it may be measured).
	miniArt = function()
		local files = MEDIA .. "Grove" .. World().files .. "Mini"
		return { rim = MEDIA .. "GroveRimMini", rimSlice = M.MINI.RIM, band = M.MINI.OUT + M.MINI.IN, out = M.MINI.OUT,
			run = M.VINE, join = M.MINI.JOIN,
			sides = { Top = files .. "Top", Foot = files .. "Foot", Left = files .. "Left", Right = files .. "Right" } }
	end,
	-- A circle's border: the art drawn for the circle nearest `size` across, laid `span` across on the circle's middle.
	ring = function(size)
		local best
		for _, drawn in ipairs(M.MINI.RINGS) do
			if not best or math.abs(drawn - size) < math.abs(best - size) then best = drawn end
		end
		local file = MEDIA .. "Grove" .. World().files .. "Ring" .. best
		return { file = file, key = file .. "Key", light = file .. "Light", span = (best + 2 * M.MINI.RING_PAD) * size / best,
			glow = World().glow }
	end,
	content = M.CLEAR,
	text = "shadow",   -- words are set off from the garden behind them while no text effect is picked
	face = { "groveFace", "groveRays", "groveMote" },
	edge = EDGE,
	bar = function() return World().bar end,
	slot = function() return World().slot end,
	ground = function() return World().ground end,
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line,
	lineAlpha = 0,
})
