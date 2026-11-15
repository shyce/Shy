-- The matrix look: every housing a dark screen. Digital rain falls behind what it holds (two layers of glyph
-- columns, each falling at its own speed; the Rain option stills it or puts it away), scanlines over it, a thin
-- line of phosphor round its edge with its glow; under a head a stream of small glyphs with a scan running along it.
-- Its icons sit in phosphor frames over wells with a little rain in them; its bars are lit phosphor. All of it in
-- your color, added to the dark: light on a screen.
local UI, Theme = Shy.UI, Shy.Theme
local MEDIA = Shy.MEDIA
local Blend = UI.LookBlend

-- The screen the fill leans to (by TONE), and how much further the strip leans (STRIP).
local SCREEN, TONE, STRIP = { 0.008, 0.022, 0.012 }, 0.9, 0.5
local SLAB = UI.LookSlab
-- The measures (units): the rain's tile W x TALL, its layers falling at SPEED units a second, each at LAYER of the
-- rain's strength (RAIN by the option); the scanlines a SCAN-texel tile a texel a pixel at SCAN_A; the edge a nine
-- slice (EDGE_SLICE) at EDGE_A; a head's line: the stream STREAM long, BAND tall, at STREAM_A, its scan BEAM long
-- running BEAM_SPEED units a second (a looping slide the game runs itself); a button's glow a nine slice
-- (KEY_SLICE), at KEY_REST at rest. The rain falls FPS times a second (the game can't scroll a texture itself),
-- only on a housing shown.
local M = {
	W = 96, TALL = 192, SPEED = { 6, 10 }, LAYER = { 1, 0.55 }, RAIN = { falling = 0.55, still = 0.55, off = 0 },
	SCAN = 64, SCAN_A = 0.22, EDGE_SLICE = 8, EDGE_A = 0.9,
	STREAM = 64, BAND = 6, STREAM_A = 0.75, BEAM = 32, BEAM_SPEED = 70,
	KEY_SLICE = 5, KEY_REST = 0.55, FPS = 24,
}

local function Option(x, key)
	return UI.LookOption(x, key, "matrix")
end

local function Rain(x)
	return M.RAIN[Option(x, "rain")] and Option(x, "rain") or "falling"
end

-- How far the rain and the scanlines follow the Background strength on screen; whole in a window.
local function Through(h)
	return h.solid and 1 or Theme.Strength() ^ 0.5
end

-- ------------------------------------------------------------------ the rain falling
local falling = setmetatable({}, { __mode = "k" })   -- housing -> true, while its rain falls
local clock = CreateFrame("Frame")
clock:Hide()
local since = 0

-- Where each layer has fallen to: its offset kept within one tile (the rain repeats, so it looks the same), as the
-- game refuses a texture coordinate far out of range.
local function LayRain(h, t)
	local w, tall, u = h.matrixW or 0, h.matrixTall or 0, h.matrixU or 0
	for i, region in ipairs(h.matrixRain) do
		local v = (h.matrixV[i] - (t and t * M.SPEED[i] / M.TALL or 0)) % 1
		local x = (u + i * 0.37) % 1
		region:SetTexCoord(x, x + w / M.W, v, v + tall / M.TALL)
	end
end

clock:SetScript("OnUpdate", Shy.Clocked("look: the matrix's rain", function(_, elapsed)
	since = since + elapsed
	if since < 1 / M.FPS then return end
	since = 0
	local t, any = GetTime(), false
	for h in pairs(falling) do
		-- (h.matrixFalls: what its dress read of the Rain option; a change of it dresses the housing again.)
		if h.look ~= "matrix" or not h.matrixFalls then
			falling[h] = nil
		else
			any = true
			if h.matrixRain[1]:IsVisible() then LayRain(h, t) end
		end
	end
	if not any then clock:Hide() end
end))

-- ------------------------------------------------------------------ built, dressed, fitted
local function Build(h, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel)
		return kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
	end
	h.matrixRain, h.matrixV = {}, {}
	for i = 1, 2 do
		local t = UI.LookWear(Tex("matrixRain" .. i, "BACKGROUND", -6 + i), MEDIA .. "MatrixRain" .. i, "REPEAT", "REPEAT")
		t:SetBlendMode("ADD")
		kit.Out(t, -1)
		h.matrixRain[i] = t
		h.matrixV[i] = select(i, UI.LookSeed(h, "rain"))
	end
	h.matrixU = UI.LookSeed(h, "rain+")
	UI.LookWear(Tex("matrixScan", "BACKGROUND", -3), MEDIA .. "MatrixScan", "REPEAT", "REPEAT")
	kit.Out(h.matrixScan, -1)
	UI.LookWear(Tex("matrixEdge", "BORDER", 2), MEDIA .. "MatrixEdge", nil, nil, M.EDGE_SLICE)
	h.matrixEdge:SetBlendMode("ADD")
	kit.Out(h.matrixEdge, 0)
end

local function Dress(h)
	local accent = UI.LookAccent(h)
	local rain = Rain(h)
	for i, t in ipairs(h.matrixRain) do
		Theme.Tint(t, function()
			local r, g, b = accent()
			return r, g, b, M.RAIN[rain] * M.LAYER[i] * Through(h)
		end)
		t:SetShown(rain ~= "off")
	end
	Theme.Tint(h.matrixScan, function() return 0, 0, 0, M.SCAN_A * Through(h) end)
	Theme.Tint(h.matrixEdge, accent, M.EDGE_A)
	h.matrixScan:Show()
	h.matrixEdge:Show()
	h.matrixFalls = rain == "falling"
	if h.matrixFalls then
		falling[h] = true
		clock:Show()
	else
		falling[h] = nil
	end
end

local function Fit(h, g)
	h.matrixW, h.matrixTall = g.w or 0, g.tall or 0
	LayRain(h, Rain(h) == "falling" and GetTime() or nil)
	-- Scanlines a texel a pixel: as many as the piece is pixels tall.
	local per = g.per or 1.22
	h.matrixScan:SetTexCoord(0, h.matrixW * per / M.SCAN, 0, h.matrixTall * per / M.SCAN)
	h.matrixEdge:SetShown(h.matrixW >= 2 * M.EDGE_SLICE and h.matrixTall >= 2 * M.EDGE_SLICE)
end

-- A head's line: the stream of glyphs along it, the scan sliding over it from before its start to past its end, over
-- and over (a slide the game runs: laid again only when the line changes width); the line itself put away.
local function Line(owner, line)
	local set = { owner = owner, line = line }
	set.stream = owner:CreateTexture(nil, "ARTWORK", nil, 0)
	UI.LookWear(set.stream, MEDIA .. "MatrixStream", "REPEAT", "CLAMP")
	set.stream:SetBlendMode("ADD")
	set.stream:SetPoint("TOPLEFT", line, "LEFT", 0, M.BAND / 2)
	set.stream:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -M.BAND / 2)
	set.beam = owner:CreateTexture(nil, "ARTWORK", nil, 1)
	UI.LookWear(set.beam, MEDIA .. "MatrixBeam")
	set.beam:SetBlendMode("ADD")
	set.beam:SetSize(M.BEAM, M.BAND)
	local accent = UI.LookAccent(owner)
	Theme.Tint(set.stream, accent, M.STREAM_A)
	Theme.Tint(set.beam, function()
		local r, g, b = accent()
		return r + (1 - r) * 0.4, g + (1 - g) * 0.4, b + (1 - b) * 0.4, 0.9
	end)
	set.beam:SetPoint("RIGHT", line, "LEFT", 0, 0)
	local run = set.beam:CreateAnimationGroup()
	run:SetLooping("REPEAT")
	local slide = run:CreateAnimation("Translation")
	local wide
	local function Lay()
		local w = line:GetWidth()
		if not w or issecretvalue(w) or w <= 0 or w == wide then return end
		wide = w
		set.stream:SetTexCoord(0, w / M.STREAM, 0, 1)
		slide:SetOffset(w + M.BEAM, 0)
		slide:SetDuration((w + M.BEAM) / M.BEAM_SPEED)
		run:Stop()
		run:Play()
	end
	if owner.HookScript and owner:HasScript("OnSizeChanged") then owner:HookScript("OnSizeChanged", Lay) end
	C_Timer.After(0, Lay)
	Lay()
	return { set.stream, set.beam }
end

-- ------------------------------------------------------------------ buttons
-- A button: a dark keyline (its make's edge) with the phosphor round it glowing, brighter under the mouse.
local function KeyBuild(f)
	local glow = f:CreateTexture(nil, "ARTWORK", nil, -1)
	UI.LookWear(glow, MEDIA .. "MatrixKey", nil, nil, M.KEY_SLICE)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT")
	glow:SetPoint("BOTTOMRIGHT")
	f.matrixKey = glow
	return { glow }
end

local function KeyMark(f, lit, _, primary)
	local glow = f.matrixKey
	if not glow then return end
	Theme.Tint(glow, UI.LookAccent(f), (lit or primary) and 1 or M.KEY_REST)
	glow:SetShown(f.shyPlate ~= false or lit == true)
end

UI.KEY_MAKES.matrix = { edge = { MEDIA .. "MatrixKey", M.KEY_SLICE }, rim = "dark",
	hover = { color = { 0.55, 1, 0.65 }, lift = 0.06, light = 0 }, build = KeyBuild, mark = KeyMark }

UI.LookKind("matrix", {
	name = "Matrix",
	strength = 80, wells = 100,
	words = "Digital rain falling on a phosphor screen.",
	short = "Digital rain",
	options = {
		{ key = "rain", label = "Rain", kind = "choice", default = "falling", desc = "The digital rain behind your pieces.",
			choices = { { value = "falling", text = "Falling" }, { value = "still", text = "Still" }, { value = "off", text = "Off" } } },
	},
	alpha = function(a) return 1 - (1 - a) ^ 2 end,
	fill = function(r, g, b, a)
		r, g, b = Blend(r, g, b, SCREEN[1], SCREEN[2], SCREEN[3], TONE)
		return r, g, b, a
	end,
	strip = function(r, g, b, a)
		r, g, b = Blend(r, g, b, SCREEN[1], SCREEN[2], SCREEN[3], TONE)
		r, g, b = Blend(r, g, b, SLAB[1], SLAB[2], SLAB[3], STRIP)
		return r, g, b, a, false
	end,
	toneFill = function(r, g, b) return Blend(r, g, b, SCREEN[1], SCREEN[2], SCREEN[3], 0.5) end,
	shade = 0.8,
	surface = { file = MEDIA .. "MatrixScan", alpha = M.SCAN_A, color = { 0, 0, 0 } },   -- a plaque or a card: the scanlines
	inset = 1,
	border = 3,
	face = { "matrixRain1", "matrixRain2", "matrixScan" },
	edge = { "matrixEdge" },
	bar = "phosphor",
	slot = "phosphor",
	ground = "rain",
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line,
	lineAlpha = 0,
})
