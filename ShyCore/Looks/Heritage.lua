-- The heritage look: the frame the game's login dialog wears, its double line of bronze and the studs at its corners,
-- without its color and tinted in yours, over the dialog's dark veil. Nothing of it is ours: the game's own atlas, on
-- our regions.
local UI, Theme = Shy.UI, Shy.Theme
local max, min = math.max, math.min

local BORDER = "UI-DiamondDialogBox-Border"
-- The border at its own size: a side, the margins its slices keep, and its bar along the top (units down from its top
-- edge), whose middle stands under a header and over a typing row.
local SIDE, MARGIN, BAR_TOP, BAR_FOOT = 70, 26, 4, 13
-- It stands OUT units past the piece; its side bars' inner edge is INNER units in at its own size.
local OUT, INNER = 2, 12
-- Its size on our pieces (the Frame option); the added light on a placed content's rim (the buttons stay the star).
local SIZES = { fine = 0.5, bold = 0.75 }
local CALM = 0.55
-- The dialog's backdrop is black at 160 of 255: the fill is black at the Background strength times VEIL (that at the
-- default strength); the head a darker band of it.
local VEIL, HEAD = 1.15, 0.5
local WHITE = { 1, 1, 1 }
local BRONZE = { 0.86, 0.66, 0.40 }   -- the frame's own bronze, for a tail of our drawing beside it

-- An option as `x` wears it (a housing, or the owner of a line): its own (a card showing a preset), else the theme's.
local function Option(x, key)
	return UI.LookOption(x, key, "heritage")
end

local function Size(x)
	return SIZES[Option(x, "frame")] or SIZES.fine
end

-- The size on a piece: the option's, or smaller on a piece too small for the corners with ROOM between them. A bar's
-- housing (`slim`) keeps it while its corners fit at all: drawn much smaller, the frame's line is less than a pixel
-- of bronze and goes dark.
local ROOM = 8
local function Fitted(x, w, tall)
	local room = (x and x.slim) and 0 or ROOM
	return min(Size(x), (min(w, tall) + 2 * OUT - room) / (2 * MARGIN))
end

-- The light laid again, added, over the tinted metal (none in the game's own colors).
local function Shine(x)
	if Option(x, "color") == "game" then return 0 end
	return (Option(x, "shine") or 55) / 100
end

-- A texture of the border, without its color unless the game's own is worn, tinted in yours (`accent`: the housing's,
-- UI.LookAccent, which is Theme.Accent itself unless a card shows a preset's own, so a gradient reaches it).
local function Wear(x, t, a, accent)
	local game = Option(x, "color") == "game"
	t:SetDesaturated(not game)
	Theme.Tint(t, game and WHITE or accent, a)
end

-- The bar of the border's top side, its middle between the slices, on a texture of the border's file: the file worn
-- (UI.LookWear: set again whenever the housing is dressed), the place in it set again after.
local function Coords(t)
	local info = C_Texture.GetAtlasInfo(BORDER)
	if not info then return end
	local l, r, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	t:SetTexCoord(l + (r - l) * MARGIN / SIDE, r - (r - l) * MARGIN / SIDE, top + (bottom - top) * BAR_TOP / SIDE, top + (bottom - top) * BAR_FOOT / SIDE)
end

local function Bar(t)
	local info = C_Texture.GetAtlasInfo(BORDER)
	if not info then return end
	UI.LookWear(t, info.file or info.filename)
	Coords(t)
end

-- The border sliced by the engine, its sides stretched (one unbroken bar: tiled, as the dialog wears them, the grain
-- of a short strip repeats down a small piece); set again after its atlas is.
local function Stretch(t)
	t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

-- A header's line worn as the border's bar: the bar and its added light, as tall as the border's at its size.
local rails = setmetatable({}, { __mode = "k" })   -- bar -> { the line it lies on, whether it is the added light, its owner }

local function Rail(t, line, owner)
	local half = (BAR_FOOT - BAR_TOP) * Size(owner) / 2
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", line, "LEFT", 0, half)
	t:SetPoint("BOTTOMRIGHT", line, "RIGHT", 0, -half)
end

-- A line's bar and its light dressed again, as its owner wears the look now.
local function Relay(t, rail)
	local line, lit, owner = rail[1], rail[2], rail[3]
	Rail(t, line, owner)
	Coords(t)
	local shine = Shine(owner)
	Wear(owner, t, lit and shine or 1, UI.LookAccent(owner))
	if lit then t:SetAlpha(shine > 0 and 1 or 0) end
end

local function Line(owner, line)
	local bar = owner:CreateTexture(nil, "ARTWORK", nil, 0)
	local lit = owner:CreateTexture(nil, "ARTWORK", nil, 1)
	lit:SetBlendMode("ADD")
	for _, t in ipairs({ bar, lit }) do
		Bar(t)
		rails[t] = { line, t == lit, owner }
		Relay(t, rails[t])
	end
	return { bar, lit }
end

local function Build(_, kit)
	local owner = kit.owner
	local function Tex(name, layer, sublevel)
		return kit.Reg(name, owner:CreateTexture(nil, layer, nil, sublevel))
	end
	-- The border and its added light; the bar over a typing row's seam.
	local frame, lit = Tex("heritageFrame", "ARTWORK", 2), Tex("heritageLit", "ARTWORK", 3)
	lit:SetBlendMode("ADD")
	for _, t in ipairs({ frame, lit }) do
		UI.LookWear(t, { atlas = BORDER })
		Stretch(t)
	end
	local foot, footLit = Tex("heritageFoot", "ARTWORK", 0), Tex("heritageFootLit", "ARTWORK", 1)
	footLit:SetBlendMode("ADD")
	Bar(foot)
	Bar(footLit)
end

-- The bars on this housing's own line (its owner's), dressed with it.
local function Lines(h)
	for t, rail in pairs(rails) do
		if rail[3] == h.owner then Relay(t, rail) end
	end
end

local function Dress(h)
	h.heritageFrame:Show()
	Stretch(h.heritageFrame)
	Stretch(h.heritageLit)
	local accent = UI.LookAccent(h)
	Wear(h, h.heritageFrame, 1, accent)
	Wear(h, h.heritageFoot, 1, accent)
	Lines(h)
end

local function Fit(h, g)
	local s = max(0.1, Fitted(h, g.w, g.tall))
	local to, inset = g.to, g.inset
	for _, t in ipairs({ h.heritageFrame, h.heritageLit }) do
		Stretch(t)
		t:SetScale(s)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", to, "TOPLEFT", (inset[1] - OUT) / s, (-inset[2] + OUT) / s)
		t:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", (-inset[3] + OUT) / s, (inset[4] - OUT) / s)
	end
	-- A placed content's rim (the bars) less lit than a piece with a head.
	local accent = UI.LookAccent(h)
	local shine = Shine(h) * ((g.content and (g.head or 0) == 0) and CALM or 1)
	Wear(h, h.heritageLit, shine, accent)
	h.heritageLit:SetShown(shine > 0)
	-- The bar over a typing row's seam, between the border's side bars.
	local foot = g.foot or 0
	local floored = foot > 0
	if floored then
		local inner, half = INNER * s - OUT, (BAR_FOOT - BAR_TOP) * s / 2
		for _, t in ipairs({ h.heritageFoot, h.heritageFootLit }) do
			Coords(t)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", to, "BOTTOMLEFT", inset[1] + inner, inset[4] + foot + half)
			t:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", -inset[3] - inner, inset[4] + foot - half)
		end
		Wear(h, h.heritageFootLit, shine, accent)
	end
	h.heritageFoot:SetShown(floored)
	h.heritageFootLit:SetShown(floored and shine > 0)
end

UI.LookKind("heritage", {
	name = "Heritage",
	strength = 95,
	words = "The game's own bronze frame, in your color.",
	short = "The game's frame, recolored",
	options = {
		{ key = "color", label = "Color", kind = "choice", default = "yours", desc = "The frame in your color, or in the game's own bronze.",
			choices = { { value = "yours", text = "Your color" }, { value = "game", text = "The game's" } } },
		{ key = "shine", label = "Shine", kind = "slider", min = 0, max = 100, step = 5, default = 55,
			desc = "How brightly the metal catches the light." },
		{ key = "frame", label = "Frame", kind = "choice", default = "fine", desc = "How heavy the frame is.",
			choices = { { value = "fine", text = "Fine" }, { value = "bold", text = "Bold" } } },
	},
	alpha = function(a) return min(1, a * VEIL) end,
	fill = function(_, _, _, a) return 0, 0, 0, a end,
	strip = function(_, _, _, a) return 0, 0, 0, a * HEAD, false end,
	toneFill = function(r, g, b) return UI.LookBlend(r, g, b, 0, 0, 0, 0.5) end,
	shade = 0.7,
	inset = 2,
	border = function(h)
		local owner = h and h.owner
		if not owner then return 4 end
		local w, tall = owner:GetWidth(), owner:GetHeight()
		if not w or w <= 0 or issecretvalue(w) then return 4 end
		return max(2, INNER * max(0.1, Fitted(h, w, tall)) - OUT)
	end,
	rims = false,
	-- The dialog's border and its lit rim, and the foot's: nothing across the face.
	-- A chat bubble's tail (UI.LookTail): the frame's outer line running on round it (a double line of our own
	-- drawing: the frame itself is the game's), in your color, or the game's bronze.
	tail = function(h)
		local size = Option(h, "frame") == "bold" and "Bold" or "Fine"
		return "Heritage" .. size, { { layer = "Frame", color = Option(h, "color") == "game" and BRONZE or UI.LookAccent(h) } }
	end,
	edge = { "heritageFrame", "heritageLit", "heritageFoot", "heritageFootLit" },
	bar = "classic",   -- the game's own kind of rounded bar
	slot = "band",
	ground = "bronze",   -- hammered bronze under the icons
	build = Build,
	dress = Dress,
	fit = Fit,
	line = Line,
	lineAlpha = 0,
})
