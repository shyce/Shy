-- The galaxy look: every housing a slab of glossy black glass with deep space inside it. The sky sinks toward the
-- edge, ringed by one rim in oil-slick iridescence (chrome-bright where the light falls, its glow falling inward, a
-- spark where the light catches the top left corner), the line under a head at the rim's weight (the Line option);
-- a glass reflection lies over the sky.
-- Your color is the light the slab gives off: a halo on what is behind it (breathing slowly), the glow under a
-- head's iridescent hairline, a tint in the thinner clouds. Stars twinkle over the sky and, now and then, a shooting
-- star crosses it. Its bars are black glass, its icons dark bezels over wells of deep space. The game runs every
-- movement itself (the kit's UI.LookBreath, LookTwinkle and LookDrift): no Lua a frame, none on a housing not shown.
local UI, Theme = Shy.UI, Shy.Theme
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend
local floor, min = math.floor, math.min

local SLAB = UI.LookSlab
local WHITE = { 1, 1, 1 }
-- The glass the fill leans to (by TONE), by the sky inside it (each its own: violet, a warm black, a deep blue), how much
-- further the strip leans (STRIP), and how much of the fill and the strip stands over the sky (FILL, STRIP_A): the sky
-- shows through a header's strip and through the body, so a different sky is a different window.
local GLASSES = { violet = { 0.012, 0.014, 0.035 }, ember = { 0.040, 0.012, 0.012 }, deep = { 0.004, 0.020, 0.048 } }
local TONE, STRIP, FILL, STRIP_A = 0.9, 0.5, 0.78, 0.5

-- The sky is one fixed sky in three layers, far to near, and each piece is a window onto it: what a piece shows is what
-- lies behind its place on the screen (move it and it shows another part), and the layers slide against each other as
-- you look about, the near ones furthest (parallax): with the cursor (the eye moves across the screen: CURSOR units of
-- shift at the edge, each layer by its own share) and with turning (a full turn of your character carries each layer
-- TURNS of its tiles round: whole tiles, so the sky meets itself). One clock reads both a PERIOD apart and lays only
-- what moved, only while a piece of the glass is shown.
-- The measures (units). The sky a tile SKY a side, at SKY_A by the Sky option; the clouds in your color at KEY_A; the
-- glass's reflection at GLASS_A. The depth a nine slice (DEPTH_SLICE) from the piece's edge (none on a piece too small
-- for its slices); the rim a nine slice (BEZEL_SLICE) at the Line option's weight; the halo a nine slice (HALO_SLICE) standing HALO past the piece,
-- at HALO_A, breathing to BREATH[1] over BREATH[2] seconds. A head's line: a hairline HAIR long (tiling), HAIR_BAND
-- tall. Stars: one twinkle for each GLINT_AREA square units (GLINTS at most), GLINT across, coming and going over
-- GLINT_LONG seconds every GLINT_WAIT[1] to [2], from GLINT_CLEAR clear of the edge. Shooting stars: one for each
-- STREAK_AREA square units (STREAKS at most), STREAK by STREAK_TALL, crossing STREAK_RUN units down and to the left
-- over STREAK_TIME seconds, then resting STREAK_REST.
local M = {
	SKY = 1024, SKY_A = { dim = 0.65, bright = 0.95 }, KEY_A = 0.45, GLASS_A = 0.9,
	LAYERS = { { name = "galaxyNeb", tile = 1024, cursor = 10, turns = 1 }, { name = "galaxyFar", tile = 192, cursor = 26, turns = 2 },
		{ name = "galaxyNear", tile = 256, cursor = 70, turns = 4 } },
	PERIOD = 1 / 30, EASE = 0.22, SETTLED = 0.0015,
	DEPTH_SLICE = 32, BEZEL_SLICE = 10, HALO_SLICE = 16, HALO = 16, HALO_A = 0.5, BREATH = { 0.7, 5.5 },
	HAIR = 128, HAIR_BAND = 6,
	GLINT = 16, GLINT_AREA = 2600, GLINTS = 24, GLINT_LONG = 1.4, GLINT_WAIT = { 2.5, 9 }, GLINT_CLEAR = 10,
	STREAK = 48, STREAK_TALL = 8, STREAK_AREA = 24000, STREAKS = 3, STREAK_RUN = 70, STREAK_TIME = { 1.2, 2.0 }, STREAK_REST = { 9, 22 },
	-- The rim's weights (the Line option): the files' name, and the frame's inner face from the edge (the line, its glow
	-- and a clear gap past them), so a header's icon and ×, and every control and line of content, stand clear of the
	-- rim; a window's content this much further in again (CLEAR). The head's line is drawn at the rim's weight.
	WEIGHTS = { fine = { "Fine", 5 }, medium = { "Medium", 6 }, bold = { "Bold", 7 } }, CLEAR = 2,
	-- The mini (h.mini: a plaque, a tooltip, a drawer, a nameplate): the rim a little finer (GalaxyBezelMini, a nine slice
	-- of MINI_SLICE), its frame's inner face MINI_BORDER in, no shooting stars. A circle's border (the look's `ring`): the
	-- mini rim bent round it, drawn for the circle sizes RINGS, the art RING_PAD past it all round.
	MINI_SLICE = 6, MINI_BORDER = 4, RINGS = { 46, 33, 24 }, RING_PAD = 8,
	PARTS = { "galaxyHalo", "galaxyNeb", "galaxySkyKey", "galaxyFar", "galaxyNear", "galaxyGlass", "galaxyDepth", "galaxyBezel" },
	GLINT_SALT = {}, STREAK_SALT = {},   -- each star's salt, written once (a fit asks every one)
}
for i = 1, M.GLINTS do M.GLINT_SALT[i] = "glint" .. i end
for i = 1, M.STREAKS do M.STREAK_SALT[i] = "streak" .. i end
local lines = setmetatable({}, { __mode = "k" })   -- owner -> the sets of its lines (below)
local SPACES = { violet = "Violet", ember = "Ember", deep = "Deep" }   -- the skies' files

local function Option(x, key)
	return UI.LookOption(x, key, "galaxy")
end

-- The weight of a housing's rim and its head's line (the Line option): { files' name, border }.
local function Weight(x)
	return M.WEIGHTS[Option(x, "edge")] or M.WEIGHTS.medium
end

-- The glass of the sky worn (the piece's own, a card showing a preset's, else the theme's).
local function Glass(x)
	return GLASSES[Option(x, "space")] or GLASSES.violet
end

-- How far the face's parts follow the Background strength: in a window as on screen, so a window's sky is never
-- brighter than the pieces round it, and the words over it read.
local function Through()
	return Theme.Strength() ^ 0.5
end

-- Your color lifted toward white: the light the glass gives off.
local function Lifted(accent, k)
	return function()
		local r, g, b = accent()
		return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
	end
end

-- ------------------------------------------------------------------ the sky laid, and the eye
-- Where you look, eased toward where it is asked (tx, ty, tspin), and where it was when the sky was last laid (lx,
-- ly, lspin): the sky is laid again only once the nearest layer has slid SHIFT units, so an eye at rest, or easing
-- its last hair's breadth, lays nothing.
local eye = { x = 0, y = 0, spin = 0, tx = 0, ty = 0, tspin = 0, lx = 0, ly = 0, lspin = 0, n = 0, last = nil }
local live = setmetatable({}, { __mode = "k" })    -- housing -> true, while it wears the glass
local seen = {}                                    -- the ones on screen at the last sweep, in a row
local clock = CreateFrame("Frame")
clock:Hide()
local since, sweep = 0, 0
local abs, pi = math.abs, math.pi
-- Its place is looked for every SWEEP periods (pieces move seldom; the eye moves all the time), and counts as
-- moved MOVED units on. The nearest layer's slide for the whole of the eye's range, each way.
local SWEEP, MOVED, SHIFT = 3, 0.4, 0.3
local NEAR = M.LAYERS[#M.LAYERS]
local NEAR_SPIN = NEAR.turns * NEAR.tile

-- Each layer's texture coordinates on a housing, from where it was last found (h.galaxyAt: its place on the screen
-- in UIParent's units, and its units in UIParent's): the screen behind it over the layer's tile, shifted by the eye.
local function Coords(h)
	local w, tall, at = h.galaxyW, h.galaxyH, h.galaxyAt
	if not (w and at) then return end
	local x, y, k = at[1], at[2], at[3]
	local ex, ey, spin = 0, 0, 0
	if h.galaxyParallax then ex, ey, spin = eye.x, eye.y, eye.spin end
	for i = 1, #M.LAYERS do
		local layer = M.LAYERS[i]
		local tile = layer.tile
		local u = ((x - ex * layer.cursor) / tile + spin * layer.turns) % 1
		local v = ((y - ey * layer.cursor) / tile) % 1
		h[layer.name]:SetTexCoord(u, u + w * k / tile, v, v + tall * k / tile)
	end
	h.galaxyEye = eye.n   -- the eye it was laid for: one shown again after the eye moved on is laid at the next sweep
end

-- A housing's place on the screen read, and whether it is another than the sky was laid for. One whose place can't
-- be told shows the sky from a place of its own.
local function Place(h, us, height)
	local owner = h.owner
	local os, left, top = owner:GetEffectiveScale(), owner:GetLeft(), owner:GetTop()
	local k = (us and os and us > 0 and not issecretvalue(us) and not issecretvalue(os)) and os / us or 1
	local x, y
	if left and top and height and not issecretvalue(left) and not issecretvalue(top) then
		x, y = left * k, height - top * k
	else
		x, y = UI.LookSeed(h, "sky")
		x, y = x * M.SKY, y * M.SKY
	end
	local at = h.galaxyAt
	if not at then
		at = {}
		h.galaxyAt = at
	elseif abs(x - at[1]) <= MOVED and abs(y - at[2]) <= MOVED and k == at[3] then
		return false
	end
	at[1], at[2], at[3] = x, y, k
	return true
end

-- The sky on a housing laid whole, where it was last found: each layer by the eye, the clouds in your color (which
-- stay where the piece is: no eye in them).
local function Whole(h)
	Coords(h)
	local at, w, tall = h.galaxyAt, h.galaxyW, h.galaxyH
	local ku, kv = (at[1] / M.SKY + 0.41) % 1, (at[2] / M.SKY + 0.23) % 1
	h.galaxySkyKey:SetTexCoord(ku, ku + w * at[3] / M.SKY, kv, kv + tall * at[3] / M.SKY)
end

-- ... its place read first (a fit: it has another size).
local function Lay(h)
	if not h.galaxyW then return end
	local us, height = UIParent:GetEffectiveScale(), UIParent:GetHeight()
	if issecretvalue(height) then height = nil end
	Place(h, us, height)
	Whole(h)
end

-- Where you look now: the cursor over the screen (-0.5 to 0.5 each way) and how far your character has turned, as a
-- whole number of turns' worth that never jumps at the turn's end (the shortest way round, summed).
local function Look()
	local cx, cy = GetCursorPosition()
	local scale, width, height = UIParent:GetEffectiveScale(), UIParent:GetWidth(), UIParent:GetHeight()
	if cx and scale and scale > 0 and width and width > 0 and height and height > 0 then
		eye.tx = math.max(-0.5, math.min(0.5, cx / scale / width - 0.5))
		eye.ty = math.max(-0.5, math.min(0.5, 0.5 - cy / scale / height))
	end
	local facing = GetPlayerFacing and GetPlayerFacing()
	if facing and not issecretvalue(facing) then
		if eye.last then
			local d = (facing - eye.last + pi) % (2 * pi) - pi
			eye.tspin = eye.tspin + d / (2 * pi)
		end
		eye.last = facing
	end
end

clock:SetScript("OnUpdate", Shy.Clocked("look: the galaxy's sky", function(_, elapsed)
	since = since + elapsed
	if since < M.PERIOD then return end
	since = 0
	Look()
	local settled = M.SETTLED / 4
	local d = eye.tx - eye.x
	if abs(d) > settled then eye.x = eye.x + d * M.EASE end
	d = eye.ty - eye.y
	if abs(d) > settled then eye.y = eye.y + d * M.EASE end
	d = eye.tspin - eye.spin
	if abs(d) > settled then eye.spin = eye.spin + d * M.EASE end
	local slid = abs(eye.x - eye.lx) * NEAR.cursor > SHIFT or abs(eye.y - eye.ly) * NEAR.cursor > SHIFT
		or abs(eye.spin - eye.lspin) * NEAR_SPIN > SHIFT
	if slid then eye.lx, eye.ly, eye.lspin, eye.n = eye.x, eye.y, eye.spin, eye.n + 1 end
	sweep = sweep + 1
	if sweep >= SWEEP then
		-- The sweep: who is on screen now, and where; one that moved is laid whole.
		sweep = 0
		local us, height = UIParent:GetEffectiveScale(), UIParent:GetHeight()
		if issecretvalue(height) then height = nil end
		local n, any = 0, false
		for h in pairs(live) do
			if h.look ~= "galaxy" then
				live[h] = nil
			else
				any = true
				if h.galaxyW and h.owner:IsVisible() then
					n = n + 1
					seen[n] = h
					if Place(h, us, height) then
						Whole(h)
					elseif h.galaxyParallax and h.galaxyEye ~= eye.n then
						Coords(h)
					end
				end
			end
		end
		for i = n + 1, #seen do seen[i] = nil end
		if not any then clock:Hide() end
	elseif slid then
		for i = 1, #seen do
			local h = seen[i]
			if h.look == "galaxy" and h.galaxyParallax then Coords(h) end
		end
	end
end))

-- ------------------------------------------------------------------ built, dressed, fitted
local function Build(h, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel)
		return kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
	end
	-- Behind the piece: its light on the world.
	UI.LookWear(Tex("galaxyHalo", "BACKGROUND", -7), MEDIA .. "GalaxyHalo", nil, nil, M.HALO_SLICE)
	h.galaxyHalo:SetBlendMode("ADD")
	kit.Out(h.galaxyHalo, M.HALO)
	-- The face: the sky under the fill (which stands over it by FILL), the clouds in your color, the glass over them.
	Tex("galaxyNeb", "BACKGROUND", -7)
	UI.LookWear(Tex("galaxySkyKey", "BACKGROUND", -5), MEDIA .. "GalaxySkyKey", "REPEAT", "REPEAT")
	UI.LookWear(Tex("galaxyFar", "BACKGROUND", -4), MEDIA .. "GalaxyStarsFar", "REPEAT", "REPEAT")
	UI.LookWear(Tex("galaxyNear", "BACKGROUND", -3), MEDIA .. "GalaxyStarsNear", "REPEAT", "REPEAT")
	for _, name in ipairs({ "galaxyNeb", "galaxySkyKey", "galaxyFar", "galaxyNear" }) do kit.Out(h[name], -1) end
	UI.LookWear(Tex("galaxyGlass", "BACKGROUND", -2), MEDIA .. "GalaxyGlass")
	h.galaxyGlass:SetBlendMode("ADD")
	kit.Out(h.galaxyGlass, -1)
	-- The edge: the sky sinking toward the bezel, then the bezel itself.
	UI.LookWear(Tex("galaxyDepth", "BORDER", 0), MEDIA .. "GalaxyDepth", nil, nil, M.DEPTH_SLICE)
	kit.Out(h.galaxyDepth, -1)
	Tex("galaxyBezel", "BORDER", 2)
	kit.Out(h.galaxyBezel, 0)
end

local function Dress(h)
	local accent = UI.LookAccent(h)
	local sky = M.SKY_A[Option(h, "sky")] or M.SKY_A.dim
	UI.LookWear(h.galaxyNeb, MEDIA .. "GalaxyNebula" .. (SPACES[Option(h, "space")] or "Violet"), "REPEAT", "REPEAT")
	Theme.Tint(h.galaxyNeb, function() return 1, 1, 1, sky * Through() end)
	Theme.Tint(h.galaxyFar, function() return 1, 1, 1, 0.85 * Through() end)
	Theme.Tint(h.galaxyNear, function() return 1, 1, 1, Through() end)
	Theme.Tint(h.galaxySkyKey, function()
		local r, g, b = accent()
		return r, g, b, M.KEY_A * Through()
	end)
	Theme.Tint(h.galaxyGlass, function() return 1, 1, 1, M.GLASS_A * Through() end)
	UI.LookWear(h.galaxyBezel, MEDIA .. "GalaxyBezel" .. (h.mini and "Mini" or "") .. Weight(h)[1], nil, nil,
		h.mini and M.MINI_SLICE or M.BEZEL_SLICE)
	Theme.Tint(h.galaxyDepth, WHITE, 1)
	Theme.Tint(h.galaxyBezel, WHITE, 1)
	Theme.Tint(h.galaxyHalo, function()
		local r, g, b = Lifted(accent, 0.2)()
		return r, g, b, M.HALO_A * Through()
	end)
	UI.LookBreath(h.galaxyHalo, M.BREATH[2], M.BREATH[1])
	for _, name in ipairs(M.PARTS) do h[name]:Show() end
	h.galaxyParallax = Option(h, "parallax") ~= false
	live[h] = true
	clock:Show()
	for _, set in ipairs(lines[h.owner] or {}) do set.lay() end
end

local function Fit(h, g)
	local w, tall = g.w or 0, g.tall or 0
	-- The sky behind its place on the screen, each layer by its own depth.
	h.galaxyW, h.galaxyH = w, tall
	Lay(h)
	local shown = w >= 2 * M.DEPTH_SLICE and tall >= 2 * M.DEPTH_SLICE
	h.galaxyDepth:SetShown(shown)
	local slice = h.mini and M.MINI_SLICE or M.BEZEL_SLICE
	h.galaxyBezel:SetShown(w >= 2 * slice and tall >= 2 * slice)
	-- Stars twinkling over the sky, each from a place and at a pace of its own. A star is dressed once a dress (its
	-- art, its light, its size) and left twinkling: a fit only puts it where the piece's size has it now.
	local glints = UI.LookPool(h, "galaxyGlint", "BACKGROUND", -2, true)
	local count = 0
	if w > 2 * M.GLINT_CLEAR and tall > 2 * M.GLINT_CLEAR then count = min(M.GLINTS, floor(w * tall / M.GLINT_AREA)) end
	local light
	for i = 1, count do
		local t = glints:Get(i)
		local fx, fy = UI.LookSeed(h, M.GLINT_SALT[i])
		if t.galaxyDressed ~= h.dressed then
			t.galaxyDressed = h.dressed
			light = light or Lifted(UI.LookAccent(h), 0.75)
			UI.LookWear(t, MEDIA .. "GalaxyGlint")
			t:SetBlendMode("ADD")
			Theme.Tint(t, light, 1)
			local size = M.GLINT * (0.5 + 0.7 * fx)
			t:SetSize(size, size)
		end
		t:ClearAllPoints()
		t:SetPoint("CENTER", g.to, "TOPLEFT", g.inset[1] + M.GLINT_CLEAR + fx * (w - 2 * M.GLINT_CLEAR), -g.inset[2] - M.GLINT_CLEAR - fy * (tall - 2 * M.GLINT_CLEAR))
		t:Show()
		t.galaxyMoves = true
		UI.LookTwinkle(t, M.GLINT_WAIT[1] + ((fx + fy) % 1) * (M.GLINT_WAIT[2] - M.GLINT_WAIT[1]), M.GLINT_LONG)
	end
	for i = count + 1, #glints.list do
		local t = glints.list[i]
		if t.galaxyMoves then
			UI.LookStill(t)
			t.galaxyMoves = nil
		end
	end
	glints:Done(count)
	-- Shooting stars: from the upper right, down and to the left, now and then.
	local streaks = UI.LookPool(h, "galaxyStreak", "BACKGROUND", -2, true)
	count = 0
	if not h.mini and Option(h, "streaks") ~= false and w > M.STREAK_RUN + M.STREAK and tall > M.STREAK_RUN * 0.55 + M.STREAK_TALL then
		count = min(M.STREAKS, floor(w * tall / M.STREAK_AREA))
	end
	light = nil
	for i = 1, count do
		local t = streaks:Get(i)
		local fx, fy = UI.LookSeed(h, M.STREAK_SALT[i])
		if t.galaxyDressed ~= h.dressed then
			t.galaxyDressed = h.dressed
			light = light or Lifted(UI.LookAccent(h), 0.6)
			UI.LookWear(t, MEDIA .. "GalaxyStreak")
			t:SetBlendMode("ADD")
			Theme.Tint(t, light, 1)
			t:SetSize(M.STREAK, M.STREAK_TALL)
			t:SetRotation(0.5)
		end
		t:ClearAllPoints()
		t:SetPoint("CENTER", g.to, "TOPLEFT", g.inset[1] + M.STREAK_RUN + M.STREAK / 2 + fx * (w - M.STREAK_RUN - M.STREAK), -g.inset[2] - M.STREAK_TALL - fy * (tall - M.STREAK_RUN * 0.55 - M.STREAK_TALL))
		t:Show()
		t.galaxyMoves = true
		UI.LookDrift(t, -M.STREAK_RUN, -M.STREAK_RUN * 0.55, M.STREAK_TIME[1] + fx * (M.STREAK_TIME[2] - M.STREAK_TIME[1]),
			M.STREAK_REST[1] + fy * (M.STREAK_REST[2] - M.STREAK_REST[1]))
	end
	for i = count + 1, #streaks.list do
		local t = streaks.list[i]
		if t.galaxyMoves then
			UI.LookStill(t)
			t.galaxyMoves = nil
		end
	end
	streaks:Done(count)
end

-- ------------------------------------------------------------------ a head's line
-- An iridescent hairline along it (from a place of the piece's own) with its glow in your color; the line itself
-- put away.
local function Line(owner, line)
	local set = { owner = owner, line = line }
	set.hair = owner:CreateTexture(nil, "ARTWORK", nil, 4)
	set.glow = owner:CreateTexture(nil, "ARTWORK", nil, 3)
	set.glow:SetBlendMode("ADD")
	for _, t in ipairs({ set.hair, set.glow }) do
		t:SetPoint("TOPLEFT", line, "LEFT", 0, M.HAIR_BAND / 2)
		t:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -M.HAIR_BAND / 2)
	end
	set.u = UI.LookSeed({ owner = owner }, "hair")
	-- Dressed (its weight's art, its colors) when its piece is, and laid by its width; `sized`: only laid, and only
	-- at another width (its owner's size script runs at every step of a glide).
	function set.lay(sized)
		if sized ~= true then
			local weight = Weight(owner)[1]
			UI.LookWear(set.hair, MEDIA .. "GalaxyHair" .. weight, "REPEAT", "CLAMP")
			UI.LookWear(set.glow, MEDIA .. "GalaxyHairKey" .. weight, "REPEAT", "CLAMP")
			Theme.Tint(set.hair, WHITE, 1)
			Theme.Tint(set.glow, Lifted(UI.LookAccent(owner), 0.2), 1)
			set.wide = nil
		end
		local w = line:GetWidth()
		if not w or issecretvalue(w) or w <= 0 or w == set.wide then return end
		set.wide = w
		local u = set.u
		set.hair:SetTexCoord(u, u + w / M.HAIR, 0, 1)
		set.glow:SetTexCoord(u, u + w / M.HAIR, 0, 1)
	end
	local function Sized() set.lay(true) end
	local mine = lines[owner] or {}
	lines[owner] = mine
	mine[#mine + 1] = set
	if owner.HookScript and owner:HasScript("OnSizeChanged") then owner:HookScript("OnSizeChanged", Sized) end
	C_Timer.After(0, Sized)
	set.lay()
	return { set.hair, set.glow }
end

-- ------------------------------------------------------------------ buttons
-- A button: black glass in a chrome hairline, the sky faint in its face, your color's light inside the rim,
-- brighter under the mouse.
local function KeyBuild(f)
	local glow = f:CreateTexture(nil, "ARTWORK", nil, -1)
	UI.LookWear(glow, MEDIA .. "GalaxyKeyGlow", nil, nil, 6)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT")
	glow:SetPoint("BOTTOMRIGHT")
	f.galaxyKey = glow
	return { glow }
end

local function KeyMark(f, lit, _, primary)
	local glow = f.galaxyKey
	if not glow then return end
	Theme.Tint(glow, Lifted(UI.LookAccent(f), 0.25), (lit or primary) and 0.8 or 0.25)
	glow:SetShown(f.shyPlate ~= false or lit == true)
end

UI.KEY_MAKES.galaxy = { edge = { MEDIA .. "GalaxyKey", 6 }, rim = "white", grain = 0.45, face = function() return MEDIA .. "GalaxyNebula" .. (SPACES[Option(nil, "space")] or "Violet") end,
	hover = { color = { 0.70, 0.80, 1.0 }, lift = 0.08, light = 0.3 }, build = KeyBuild, mark = KeyMark }

-- ------------------------------------------------------------------ the kind
UI.LookKind("galaxy", {
	name = "Galaxy",
	strength = 85, wells = 100,
	words = "Deep space inside glossy black glass, lit at its edge in oil-slick colors.",
	short = "Galaxy glass",
	options = {
		{ key = "space", label = "Space", kind = "choice", default = "violet", desc = "The sky inside the glass.",
			choices = { { value = "violet", text = "Violet nebula" }, { value = "ember", text = "Ember supernova" }, { value = "deep", text = "Deep spiral" } } },
		{ key = "edge", label = "Line", kind = "choice", default = "medium", desc = "How heavy the rim round each piece and the line under its title are.",
			choices = { { value = "fine", text = "Fine" }, { value = "medium", text = "Medium" }, { value = "bold", text = "Bold" } } },
		{ key = "parallax", label = "Parallax", kind = "switch", default = true,
			desc = "The sky shifts as you move the cursor and turn, as if you were looking into it." },
		{ key = "sky", label = "Sky", kind = "choice", default = "dim", desc = "How bright the sky shows behind what a piece holds.",
			choices = { { value = "dim", text = "Dim" }, { value = "bright", text = "Bright" } } },
		{ key = "streaks", label = "Shooting stars", kind = "switch", default = true, desc = "A shooting star across the sky now and then." },
	},
	alpha = function(a) return (1 - (1 - a) ^ 2) * FILL end,
	fill = function(r, g, b, a)
		local glass = Glass()
		r, g, b = Blend(r, g, b, glass[1], glass[2], glass[3], TONE)
		return r, g, b, a
	end,
	strip = function(r, g, b, a)
		local glass = Glass()
		r, g, b = Blend(r, g, b, glass[1], glass[2], glass[3], TONE)
		r, g, b = Blend(r, g, b, SLAB[1], SLAB[2], SLAB[3], STRIP)
		return r, g, b, a * STRIP_A, false
	end,
	toneFill = function(r, g, b)
		local glass = Glass()
		return Blend(r, g, b, glass[1], glass[2], glass[3], 0.6)
	end,
	shade = 0.9,
	inset = 1,
	border = function(h) return h and h.mini and M.MINI_BORDER or Weight(h)[2] end,
	-- A piece that can't wear a housing (a nameplate): the mini rim, and the sky laid in layers by the piece's own size
	-- (no place on the screen to look through, so each piece shows a part of its own; no parallax, no stars coming and
	-- going). Each layer: its file, its tile (units; none: stretched over the face), its alpha, `accent` (in your
	-- color), `add` (added), `at` (where it starts in the tile, beside the piece's own place).
	miniArt = function()
		local sky = M.SKY_A[Option(nil, "sky")] or M.SKY_A.dim
		return { rim = MEDIA .. "GalaxyBezelMini" .. Weight()[1], rimSlice = M.MINI_SLICE,
			face = {
				{ file = MEDIA .. "GalaxyNebula" .. (SPACES[Option(nil, "space")] or "Violet"), tile = M.SKY, alpha = sky },
				{ file = MEDIA .. "GalaxySkyKey", tile = M.SKY, alpha = M.KEY_A, accent = true, at = { 0.41, 0.23 } },
				-- (The stars drawn for a nameplate's density: a texel a unit.)
				{ file = MEDIA .. "GalaxyStarsFarPlate", tile = M.LAYERS[2].tile, alpha = 0.85 },
				{ file = MEDIA .. "GalaxyStarsNearPlate", tile = M.LAYERS[3].tile, alpha = 1 },
				{ file = MEDIA .. "GalaxyGlass", alpha = M.GLASS_A, add = true },
			} }
	end,
	-- A circle's border: the art drawn for the circle nearest `size` across, laid `span` across on its middle; `tpu` 1:
	-- the set drawn a texel a unit (a nameplate's).
	ring = function(size, tpu)
		local best
		for _, drawn in ipairs(M.RINGS) do
			if not best or math.abs(drawn - size) < math.abs(best - size) then best = drawn end
		end
		local file = MEDIA .. "GalaxyRing" .. best .. ((tpu and tpu < 2) and "Plate" or "")
		return { file = file, key = file .. "Key", light = file .. "Light", span = (best + 2 * M.RING_PAD) * size / best, glow = 0.5 }
	end,
	content = M.CLEAR,
	text = "shadow",   -- words are set off from the sky behind them while no text effect is picked
	face = { "galaxyNeb", "galaxySkyKey", "galaxyFar", "galaxyNear", "galaxyGlass", "galaxyGlint", "galaxyStreak" },
	edge = { "galaxyHalo", "galaxyDepth", "galaxyBezel" },
	behind = { "galaxyHalo" },
	bar = "galaxy",
	slot = "dark",
	ground = "galaxy",
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line,
	lineAlpha = 0,
})
