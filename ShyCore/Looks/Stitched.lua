-- The stitched look: every housing a piece of leather, its Leather option the kind. Each is the fill dyed its own way
-- with its face laid over it (a relief: light where the leather catches it, dark where it falls away), a rolled edge
-- (the welt), the work round its edge, and its own line under a head:
--   Scaled  black hide, matte, its scales showing only where the light catches them; a neon line of your color just
--           inside its edge, venom veins creeping in from its corners, the two breathing slowly; the head's line a
--           scar sutured shut in your color
--   Tooled  saddle leather in your color, a band of carved scrollwork inside the edge on a piece big enough for it,
--           a saddle stitch of your color outside it; the head's line a flat braided lace of your color
--   Bound   polished leather dyed deep in your color, a gilt double rule pressed in round it; the head's line a gilt
--           rule, a lozenge at its middle
-- Its icons, their wells and the bars are the leather's too. Every region stands from the plate's edge it is
-- measured from; every run along a side is a whole number of stitches (or plaits, or turns of the vine).
local UI, Theme = Shy.UI, Shy.Theme
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend
local Breathe   -- Scaled's neon and veins breathing (below)
local floor, max, min = math.floor, math.max, math.min

-- The hide the fill leans to (by TONE) and how much darker the strap (the strip) is, from the forged make's color.
local HIDE, TONE, STRAP = { 0.17, 0.15, 0.135 }, 0.55, 0.45
local SLAB = UI.LookSlab
local WELT, WELT_SLICE = MEDIA .. "Welt", 8

-- Each leather: its face, the dye over the fill (a color, or your color steeped toward a base) at `dye`, the sheen's
-- strength, how far in the frame's inner face stands (UI.LookBorder: past the work round its edge), its icons' finish,
-- their well and the bars' fill.
local LEATHERS = {
	scaled = { face = MEDIA .. "LeatherScaled", dyed = { 0.01, 0.012, 0.01 }, dye = 0.82, faced = 0.28, sheen = 0.05, border = 5,
		slot = "neon", ground = "scales", bar = "scaled" },
	tooled = { face = MEDIA .. "LeatherTooled", steep = { 0.26, { 0.035, 0.018, 0.008 } }, dye = 0.62, sheen = 0.07, border = 6,
		slot = "saddle", ground = "hide", bar = "grain" },
	bound = { face = MEDIA .. "LeatherBound", steep = { 0.34, { 0.015, 0, 0.008 } }, dye = 0.72, sheen = 0.16, border = 7,
		slot = "gilt", ground = "bound", bar = "polished" },
}
local FACE_A = 0.9   -- the face's strength, unless the leather says its own (`faced`)

-- The work round the edge (units): Scaled's neon a nine slice (NEON_SLICE) at NEON_A, its veins VEINS a side at a
-- corner (half the piece's shorter side on a smaller one; none under VEINS_LEAST) at VEINS_A, the two breathing between
-- BREATH[1] and 1 of that every BREATH[2] seconds; Tooled's saddle stitch
-- a stitch SADDLE long, SADDLE_BAND tall, its middle SADDLE_AT in, and its carved band CARVE a turn, CARVE_BAND across,
-- CARVE_IN in (under a head, CARVE_HEAD below its line), on a piece at least CARVE_LEAST wide and tall; Bound's gilt
-- a nine slice, its margin GILT_SLICE. No lace or stitch on a piece under LEAST either way.
local E = {
	LEAST = 20, NEON_SLICE = 8, NEON_A = 0.85, VEINS = 56, VEINS_LEAST = 40, VEINS_A = 0.85, BREATH = { 0.62, 3.6 }, SADDLE = 3, SADDLE_BAND = 4, SADDLE_AT = 3.4,
	CARVE = 16, CARVE_BAND = 8, CARVE_IN = 6, CARVE_HEAD = 4, CARVE_LEAST = 64, CARVE_WIDE = 120, GILT_SLICE = 8,
	CARVE_CLEAR = 2, MARGIN = 5,   -- a window's content this far clear of the band; the family's own margin it adds to
}
-- A head's line: Scaled's scar SCAR long (it repeats no sooner), SCAR_BAND tall; Tooled's braid a plait BRAID long,
-- BRAID_BAND tall; Bound's rule RULE_BAND tall, its lozenge LOZENGE wide and tall, a unit clear of the rule each side,
-- its ends RULE_IN in from the line's (which stands 2 in from the piece's): on the gilt round the piece's inner rule.
local LINE = { SCAR = 128, SCAR_BAND = 8, BRAID = 4, BRAID_BAND = 6, RULE_BAND = 6, RULE_IN = 3.6, LOZENGE = { 12, 7 } }
-- A button's keyline (Bound's gilt, Tooled's carved groove): a nine slice, its margin KEY_SLICE.
local KEY_SLICE = 5
local KEYLINE = { bound = MEDIA .. "LeatherGiltKey", tooled = MEDIA .. "LeatherCarveKey" }

-- The leather a housing (or a header's owner, a button) wears: its own (a card showing a preset), else the theme's.
local function Leather(x)
	local key = UI.LookOption(x, "leather", "stitched")
	return LEATHERS[key] and key or "tooled"
end

-- The dye over the fill: its color (from your color for a steeped one) and how far the fill shows under it.
local function Dye(key, accent)
	local L = LEATHERS[key]
	if L.dyed then return L.dyed[1], L.dyed[2], L.dyed[3] end
	local r, g, b = accent()
	local k, base = L.steep[1], L.steep[2]
	return r * k + base[1], g * k + base[2], b * k + base[3]
end

-- How far the face's and the dye's alpha follow the Background strength on screen (the world through a piece is
-- never speckled); whole in a window.
local function Through(h)
	return h.solid and 1 or Theme.Strength() ^ 0.5
end

-- A region `l`, `t`, `r`, `b` units in from the plate's left, top, right and foot.
local function Box(t, g, l, top, r, b)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", g.to, "TOPLEFT", g.inset[1] + l, -g.inset[2] - top)
	t:SetPoint("BOTTOMRIGHT", g.to, "BOTTOMRIGHT", -g.inset[3] - r, g.inset[4] + b)
end

-- Whole periods along a run `long` units: at least one.
local function Whole(long, period)
	return max(1, floor(long / period + 0.5))
end

-- A run's coordinates: across (a top) or down (a side), `n` periods, turned round for the foot and the right.
local function Along(t, n, across, turned)
	if across then
		if turned then t:SetTexCoord(n, 0, 1, 0) else t:SetTexCoord(0, n, 0, 1) end
	elseif turned then
		t:SetTexCoord(1, 0, n, 0)
	else
		t:SetTexCoord(0, 1, 0, n)
	end
end

local function Build(h, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel)
		return kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
	end
	-- Over the fill: the dye, the face, the sheen.
	Tex("leatherDye", "BACKGROUND", -6):SetColorTexture(1, 1, 1, 1)
	kit.Out(h.leatherDye, -1)
	UI.LookWear(Tex("leatherFace", "BACKGROUND", -5), LEATHERS.tooled.face, "REPEAT", "REPEAT", nil, true)
	kit.Out(h.leatherFace, -1)
	UI.LookWear(Tex("leatherSheen", "BACKGROUND", -4), MEDIA .. "LeatherSheen")
	kit.Out(h.leatherSheen, -2)
	-- The rolled edge.
	UI.LookWear(Tex("leatherWelt", "BORDER", 0), WELT, nil, nil, WELT_SLICE)
	kit.Out(h.leatherWelt, 0)
	-- Scaled's neon and its veins (added), Tooled's saddle stitch and carved band (its sides and corners), Bound's gilt.
	UI.LookWear(Tex("leatherNeon", "BORDER", 3), MEDIA .. "LeatherNeon", nil, nil, E.NEON_SLICE)
	h.leatherNeon:SetBlendMode("ADD")
	h.leatherNeon.shyFlat = true   -- (it breathes: one color of a ramp, Theme's)
	kit.Out(h.leatherNeon, 0)
	h.leatherVeins, h.leatherSaddle, h.leatherCarve, h.leatherCorners = {}, {}, {}, {}
	for i, side in ipairs({ "Top", "Foot", "Left", "Right" }) do
		local across = i <= 2
		-- A corner's veins, in a hand of the piece's own (made with the sides: four of each).
		local u = UI.LookSeed(h, "veins" .. i)
		h.leatherVeins[i] = UI.LookWear(Tex("leatherVeins" .. i, "BORDER", 1), MEDIA .. "LeatherVeins" .. (u < 0.5 and 1 or 2))
		h.leatherVeins[i]:SetBlendMode("ADD")
		h.leatherVeins[i].shyFlat = true
		h.leatherSaddle[i] = UI.LookWear(Tex("leatherSaddle" .. side, "BORDER", 2), MEDIA .. (across and "LeatherSaddle" or "LeatherSaddleV"),
			across and "REPEAT" or "CLAMP", across and "CLAMP" or "REPEAT")
		h.leatherCarve[i] = UI.LookWear(Tex("leatherCarve" .. side, "BORDER", 1), MEDIA .. (across and "LeatherCarve" or "LeatherCarveV"),
			across and "REPEAT" or "CLAMP", across and "CLAMP" or "REPEAT")
		h.leatherCorners[i] = UI.LookWear(Tex("leatherCorner" .. i, "BORDER", 1), MEDIA .. "LeatherCarveCorner")
	end
	UI.LookWear(Tex("leatherGilt", "BORDER", 2), MEDIA .. "LeatherGilt", nil, nil, E.GILT_SLICE)
	kit.Out(h.leatherGilt, 0)
end

-- ------------------------------------------------------------------ a head's line
-- Each line's regions (made once a line, all three leathers' on it, the ones not worn put away by their alpha: the
-- core shows every region of a line with it).
local lines = setmetatable({}, { __mode = "k" })   -- line -> { owner, scar, thread, braid, ruleLeft, ruleRight, lozenge }

local function LayLine(set)
	local line, owner = set.line, set.owner
	local w = line:GetWidth()
	local key = Leather(owner)
	local accent = UI.LookAccent(owner)
	set.scar:SetAlpha(key == "scaled" and 1 or 0)
	set.thread:SetAlpha(key == "scaled" and 1 or 0)
	set.braid:SetAlpha(key == "tooled" and 1 or 0)
	for _, t in ipairs({ set.ruleLeft, set.ruleRight, set.lozenge }) do t:SetAlpha(key == "bound" and 1 or 0) end
	Theme.Tint(set.thread, accent, 1)
	Theme.Tint(set.braid, accent, 1)
	if not w or issecretvalue(w) or w <= 0 then return end
	-- The scar starts at a place of the piece's own, so no two pieces wear the same wound.
	local u = UI.LookSeed({ owner = owner }, "scar") * LINE.SCAR
	local long = w / LINE.SCAR
	set.scar:SetTexCoord(u / LINE.SCAR, u / LINE.SCAR + long, 0, 1)
	set.thread:SetTexCoord(u / LINE.SCAR, u / LINE.SCAR + long, 0, 1)
	set.braid:SetTexCoord(0, Whole(w, LINE.BRAID), 0, 1)
end

local function Line(owner, line)
	local set = { owner = owner, line = line }
	local function Tex(file, sublevel, wrapH)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, sublevel)
		UI.LookWear(t, file, wrapH, wrapH and "CLAMP" or nil)
		return t
	end
	set.scar = Tex(MEDIA .. "LeatherScar", -1, "REPEAT")
	set.thread = Tex(MEDIA .. "LeatherScarThread", 0, "REPEAT")
	set.thread:SetBlendMode("ADD")
	set.braid = Tex(MEDIA .. "LeatherBraid", 0, "REPEAT")
	set.ruleLeft = Tex(MEDIA .. "LeatherRule", 0)
	set.ruleRight = Tex(MEDIA .. "LeatherRule", 0)
	set.lozenge = Tex(MEDIA .. "LeatherLozenge", 1)
	for _, key in ipairs({ "scar", "thread" }) do
		set[key]:SetPoint("TOPLEFT", line, "LEFT", 0, LINE.SCAR_BAND / 2)
		set[key]:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -LINE.SCAR_BAND / 2)
	end
	set.braid:SetPoint("TOPLEFT", line, "LEFT", 0, LINE.BRAID_BAND / 2)
	set.braid:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -LINE.BRAID_BAND / 2)
	local lw, lh = LINE.LOZENGE[1], LINE.LOZENGE[2]
	set.ruleLeft:SetPoint("TOPLEFT", line, "LEFT", LINE.RULE_IN, LINE.RULE_BAND / 2)
	set.ruleLeft:SetPoint("BOTTOMRIGHT", line, "CENTER", -lw / 2 - 1, -LINE.RULE_BAND / 2)
	set.ruleRight:SetPoint("TOPLEFT", line, "CENTER", lw / 2 + 1, LINE.RULE_BAND / 2)
	set.ruleRight:SetPoint("BOTTOMRIGHT", line, "RIGHT", -LINE.RULE_IN, -LINE.RULE_BAND / 2)
	set.lozenge:SetPoint("CENTER", line, "CENTER")
	set.lozenge:SetSize(lw, lh)
	lines[line] = set
	-- Laid again when the line has a width (a piece made before it is placed) and whenever it changes.
	if owner.HookScript and owner:HasScript("OnSizeChanged") then owner:HookScript("OnSizeChanged", function() LayLine(set) end) end
	C_Timer.After(0, function() LayLine(set) end)
	LayLine(set)
	return { set.scar, set.thread, set.braid, set.ruleLeft, set.ruleRight, set.lozenge }
end

-- ------------------------------------------------------------------ the breath
-- Scaled's neon and veins breathe slowly: each a looping fade the game runs itself (no Lua a frame), from whole to
-- BREATH[1] and back every BREATH[2] seconds, only while the leather is worn (a hidden region's animation costs
-- nothing). Each piece breathes on its own, started as it is dressed.
local function Breath(t, on)
	local group = t.shyBreath
	if on then
		if not group then
			group = t:CreateAnimationGroup()
			group:SetLooping("BOUNCE")
			local fade = group:CreateAnimation("Alpha")
			fade:SetFromAlpha(1)
			fade:SetToAlpha(E.BREATH[1])
			fade:SetDuration(E.BREATH[2] / 2)
			fade:SetSmoothing("IN_OUT")
			t.shyBreath = group
		end
		if not group:IsPlaying() then group:Play() end
	elseif group then
		group:Stop()
		t:SetAlpha(1)
	end
end

function Breathe(h, on)   -- (the local declared above)
	Breath(h.leatherNeon, on)
	for _, t in ipairs(h.leatherVeins) do Breath(t, on) end
end

-- ------------------------------------------------------------------ dressed and fitted
local function Dress(h)
	local key = Leather(h)
	local L = LEATHERS[key]
	local accent = UI.LookAccent(h)
	UI.LookWear(h.leatherFace, L.face, "REPEAT", "REPEAT", nil, true)
	Theme.Tint(h.leatherDye, function()
		local r, g, b = Dye(key, accent)
		return r, g, b, L.dye * Through(h)
	end)
	Theme.Tint(h.leatherFace, function() return 1, 1, 1, (L.faced or FACE_A) * Through(h) end)
	Theme.Tint(h.leatherSheen, function() return 1, 1, 1, L.sheen * Through(h) end)
	Theme.Tint(h.leatherNeon, accent, E.NEON_A)
	for _, t in ipairs(h.leatherVeins) do Theme.Tint(t, accent, E.VEINS_A) end
	Breathe(h, key == "scaled")
	for _, t in ipairs(h.leatherSaddle) do Theme.Tint(t, accent, 1) end
	h.leatherWelt:Show()
	h.leatherDye:Show()
	h.leatherFace:Show()
	h.leatherSheen:Show()
	-- The lines on this housing's own owner, as it wears its leather now.
	for _, set in pairs(lines) do
		if set.owner == h.owner then LayLine(set) end
	end
end

local function Fit(h, g)
	local key = Leather(h)
	local w, tall, head = g.w or 0, g.tall or 0, g.head or 0
	-- The face: a texel a unit, tiled from a place of the piece's own.
	local u, v = UI.LookSeed(h, "face")
	local fw = w / 128
	h.leatherFace:SetTexCoord(u, u + fw, v, v + tall / 128)
	-- Scaled: the neon round the edge, and the veins creeping in from each corner (turned to it), as big as the
	-- corner has room for.
	local menace = key == "scaled" and w >= E.LEAST and tall >= E.LEAST
	h.leatherNeon:SetShown(menace)
	local side = floor(min(E.VEINS, min(w, tall) / 2))
	local veined = menace and min(w, tall) >= E.VEINS_LEAST
	if veined then
		local v = h.leatherVeins
		Box(v[1], g, 0, 0, w - side, tall - side)
		v[1]:SetTexCoord(0, 1, 0, 1)
		Box(v[2], g, w - side, 0, 0, tall - side)
		v[2]:SetTexCoord(1, 0, 0, 1)
		Box(v[3], g, 0, tall - side, w - side, 0)
		v[3]:SetTexCoord(0, 1, 1, 0)
		Box(v[4], g, w - side, tall - side, 0, 0)
		v[4]:SetTexCoord(1, 0, 1, 0)
	end
	for _, t in ipairs(h.leatherVeins) do t:SetShown(veined) end
	-- Tooled: the saddle stitch round the edge; the carved band inside it on a piece big enough.
	local AT, SB = E.SADDLE_AT, E.SADDLE_BAND / 2
	local stitched = key == "tooled" and w >= E.LEAST and tall >= E.LEAST
	if stitched then
		local top, foot, left, right = h.leatherSaddle[1], h.leatherSaddle[2], h.leatherSaddle[3], h.leatherSaddle[4]
		local across, down = Whole(w - 2 * AT, E.SADDLE), Whole(tall - 2 * AT, E.SADDLE)
		Box(top, g, AT, AT - SB, AT, tall - AT - SB)
		Along(top, across, true, false)
		Box(foot, g, AT, tall - AT - SB, AT, AT - SB)
		Along(foot, across, true, true)
		Box(left, g, AT - SB, AT, w - AT - SB, AT)
		Along(left, down, false, false)
		Box(right, g, w - AT - SB, AT, AT - SB, AT)
		Along(right, down, false, true)
	end
	for _, t in ipairs(h.leatherSaddle) do t:SetShown(stitched) end
	local CI, CB = E.CARVE_IN, E.CARVE_BAND
	local ctop = head > 0 and head + E.CARVE_HEAD or CI
	local carved = key == "tooled" and w >= E.CARVE_WIDE and tall - ctop - CI >= E.CARVE_LEAST
	if carved then
		local top, foot, left, right = h.leatherCarve[1], h.leatherCarve[2], h.leatherCarve[3], h.leatherCarve[4]
		local across, down = Whole(w - 2 * CI - 2 * CB, E.CARVE), Whole(tall - ctop - CI - 2 * CB, E.CARVE)
		Box(top, g, CI + CB, ctop, CI + CB, tall - ctop - CB)
		Along(top, across, true, false)
		Box(foot, g, CI + CB, tall - CI - CB, CI + CB, CI)
		Along(foot, across, true, true)
		Box(left, g, CI, ctop + CB, w - CI - CB, CI + CB)
		Along(left, down, false, false)
		Box(right, g, w - CI - CB, ctop + CB, CI, CI + CB)
		Along(right, down, false, true)
		local c = h.leatherCorners
		Box(c[1], g, CI, ctop, w - CI - CB, tall - ctop - CB)
		c[1]:SetTexCoord(0, 1, 0, 1)
		Box(c[2], g, w - CI - CB, ctop, CI, tall - ctop - CB)
		c[2]:SetTexCoord(1, 0, 0, 1)
		Box(c[3], g, CI, tall - CI - CB, w - CI - CB, CI)
		c[3]:SetTexCoord(0, 1, 1, 0)
		Box(c[4], g, w - CI - CB, tall - CI - CB, CI, CI)
		c[4]:SetTexCoord(1, 0, 1, 0)
	end
	for _, t in ipairs(h.leatherCarve) do t:SetShown(carved) end
	for _, t in ipairs(h.leatherCorners) do t:SetShown(carved) end
	-- Bound: the gilt round it.
	h.leatherGilt:SetShown(key == "bound" and w >= 2 * E.GILT_SLICE and tall >= 2 * E.GILT_SLICE)
end

-- ------------------------------------------------------------------ buttons
-- A button: the hide's welt for its edge, the leather's face over it, and its keyline (Bound's gilt, Tooled's carved
-- groove; Scaled's face is enough). The keyline at rest as under the mouse: it is pressed into the leather.
local function KeyBuild(f)
	local line = f:CreateTexture(nil, "ARTWORK", nil, -1)
	line:SetPoint("TOPLEFT")
	line:SetPoint("BOTTOMRIGHT")
	f.leatherKey = line
	return { line }
end

local function KeyMark(f)
	local line = f.leatherKey
	if not line then return end
	local file = KEYLINE[Leather(f)]
	if file then UI.LookWear(line, file, nil, nil, KEY_SLICE) end
	line:SetShown(file ~= nil and f.shyPlate ~= false)
end

UI.KEY_MAKES.stitched = { edge = { WELT, WELT_SLICE }, rim = "white", grain = 0.85, face = function() return LEATHERS[Leather()].face end,
	prime = "dye", dye = 0.55, hover = { color = { 0.55, 0.46, 0.38 }, lift = 0.12, light = 0.25 }, build = KeyBuild, mark = KeyMark }

local EDGE = { "leatherWelt", "leatherGilt", "leatherNeon" }
for i, side in ipairs({ "Top", "Foot", "Left", "Right" }) do
	EDGE[#EDGE + 1] = "leatherVeins" .. i
	EDGE[#EDGE + 1] = "leatherSaddle" .. side
	EDGE[#EDGE + 1] = "leatherCarve" .. side
end
for i = 1, 4 do EDGE[#EDGE + 1] = "leatherCorner" .. i end

UI.LookKind("stitched", {
	name = "Stitched",
	strength = 85,
	words = "Leather worked three ways: scaled, tooled or bound.",
	short = "Worked leather",
	options = {
		{ key = "leather", label = "Leather", kind = "choice", default = "tooled", desc = "The leather your pieces are made of.",
			choices = { { value = "tooled", text = "Tooled" }, { value = "scaled", text = "Scaled" }, { value = "bound", text = "Bound" } } },
	},
	alpha = function(a) return 1 - (1 - a) ^ 1.5 end,
	fill = function(r, g, b, a)
		r, g, b = Blend(r, g, b, HIDE[1], HIDE[2], HIDE[3], TONE)
		return r, g, b, a
	end,
	-- The strip a strap of darker hide, matte.
	strip = function(r, g, b, a)
		r, g, b = Blend(r, g, b, HIDE[1], HIDE[2], HIDE[3], TONE)
		r, g, b = Blend(r, g, b, SLAB[1], SLAB[2], SLAB[3], STRAP)
		return r, g, b, a, false
	end,
	toneFill = function(r, g, b) return Blend(r, g, b, HIDE[1], HIDE[2], HIDE[3], TONE * 0.6) end,
	shade = 0.85,
	inset = 1,
	border = function(h) return LEATHERS[Leather(h)].border end,
	-- A window's content stands clear of the carved band (Tooled's): past it at the sides and the foot, and past it
	-- under the head.
	content = function(h)
		if Leather(h) ~= "tooled" then return 0 end
		local side = E.CARVE_IN + E.CARVE_BAND + E.CARVE_CLEAR - E.MARGIN
		return { side, E.CARVE_HEAD + E.CARVE_BAND + E.CARVE_CLEAR, side, side }
	end,
	face = { "leatherDye", "leatherFace", "leatherSheen" },
	edge = EDGE,
	bar = function() return LEATHERS[Leather()].bar end,
	slot = function() return LEATHERS[Leather()].slot end,
	ground = function() return LEATHERS[Leather()].ground end,
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line,
	lineAlpha = 0,
})
