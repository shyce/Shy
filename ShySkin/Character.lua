-- The character window (CharacterFrame and its six pages) and the gear set icon picker.
-- No frame of Blizzard's is moved. One thing is sized: the six side tabs become ns.SIDE_TAB's size (42 by
-- 38, the spellbook's); their size is kept and restored. A few of its regions are placed (a tab's icon, a
-- row's name, the ammo slot's arrow): kept and restored too.
-- List rows are pooled, so each is skinned from ScrollBoxListMixin.Event.OnInitializedFrame,
-- which the game calls behind a taint barrier.
-- ColoredProgressBarTemplate bars are not status bars: Blizzard widens a texture, so our hatched
-- fill is anchored to that texture's right end, in the color of the atlas Blizzard picked.
-- Blizzard's unnamed art is found by its atlas, so our own textures are never matched.
-- The first page's ground (the race's painting and its light) is drawn on the window's own frame,
-- between its fill and its edge, so the edge and brackets stay over it; it shows with that page only.
-- It stands over the look's face (UI.LOOK_FACE: the riveted plate's brushing and sheen, the stitched
-- grain, the well's dark): the face is the ground of what has no art, never laid over the painting.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local Theme = Shy.Theme
local C = Skin.colors
local WIN = ns.WINDOW

local CHECK = Shy.MEDIA .. "GlyphCheck"
local ICON = { 0.08, 0.92, 0.08, 0.92 }   -- trims an icon's dark rim
local FACE = { 0.14, 0.86, 0.14, 0.86 }   -- trims a portrait's round edge
local DIM = 0.74                          -- alpha of a tab icon that isn't the open page
local WHITE = { 1, 1, 1 }
local WELL_SLICE = 12                     -- Skin.WELL's slice margin, as kit:Tile uses

local TAB = ns.SIDE_TAB   -- a side tab on the spine, as the spellbook's (40 pitch with Blizzard's 2 gap)
local TAB_ICON = TAB.slot  -- its icon and slot

local GROUND = "Interface\\AddOns\\ShySkin\\Media\\Ground"
local PANE = { x = 3, w = 395 }   -- the ground in the left pane: its top is the header's foot, its foot 3 over the window's
-- A race's painting is four of the client's files, 256 and 64 wide, 256 and 128 tall, of which 318 by 332 is painted.
local ART = { w = 318, h = 332, trim = 3, cut = 256, right = 64, low = 128 }
-- One tint a painting: its painted area's mean brightness brought down to 0.33, so a snowfield stands no brighter
-- behind the gear than a forest at night.
local HOME = { Human = 0.70, Orc = 1.00, Dwarf = 0.71, NightElf = 1.00, Scourge = 1.00, Tauren = 0.96, Gnome = 1.00, Troll = 0.94 }
local HOME_TINT = 0.85
-- Round lights in the pane, drawn with the brand's glow: x, y, half width, half height, alpha.
local BEHIND = { 197, 208, 315, 449, 0.10 }   -- behind the model, to lift it off the painting
local SHADOW = { 197, 392, 246, 35, 0.50 }
local POOL = { 197, 398, 352, 45, 0.20 }      -- the accent on the ground
-- The light drifting by the model's feet: two layers of the haze, each its tile's width, seconds a tile (minus: leftward), first tex coord, alpha.
local HAZE = { top = 242, h = 190, { 420, 90, 0, 0.17 }, { 640, -140, 0.3125, 0.12 } }
local SHED = { h = 48, alpha = 0.085 }       -- the header line's light down the window
-- A few texels of the painting's sky (in its first file), stretched over the head of the stats: x from, to, y from,
-- texels down per unit; two straight fades, one long and one short, that add up to one easing out: height, alpha.
local SKY = { 149, 169, 66, 3 / 130, { 190, 0.09 }, { 70, 0.07 } }
local CREST = { layers = 2, inset = { -6, 100, -6, -6 } }   -- the class crest, seen through a soft mask: left, top, right, bottom

local BAR_H = 13
-- From ColoredProgressBarMixin.SetFillTextureByColorType: the color is in the art, so it is mapped here.
local BAR_ART = {
	["common-stat-bar-red"] = { 0.80, 0.22, 0.17 },
	["common-stat-bar-green"] = { 0.25, 0.69, 0.29 },
	["common-stat-bar-blue"] = { 0.24, 0.50, 0.92 },
}

local RACE = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }
local MODEL_BUTTONS = { "zoomInButton", "zoomOutButton", "rotateLeftButton", "rotateRightButton", "resetButton" }
local PAGES = { "ReputationFrame", "SkillsFrame", "TokenFrame", "StatisticsFrame" }

local M   -- the module

local weak = { __mode = "k" }
local tiles = setmetatable({}, weak)    -- gear slot -> its slot
local art = setmetatable({}, weak)      -- tab -> our textures on it
local rows = setmetatable({}, weak)     -- list entry -> its "selected" and "at war" marks
local bars = setmetatable({}, weak)     -- progress bar -> our fill
local folds = setmetatable({}, weak)    -- Blizzard's plus / minus texture -> our glyph
local hooked = setmetatable({}, weak)   -- frames already hooked
local drift = setmetatable({}, weak)    -- a haze layer -> where it starts, how much it shows, seconds a tile, how far it has gone
local clock                             -- a frame of ours on the first page that scrolls the haze while the page shows
local sizes = {}                        -- side tab -> Blizzard's size
local own = {}                          -- the header icon, the pane button's glyph, the spine
local sky = {}                          -- the painting's light over the stats, as last painted
local ground = {}                       -- the first page's ground, as last painted

local function Once(key)
	if hooked[key] then return false end
	hooked[key] = true
	return true
end

-- Helpers

-- Calls fn for each texture on the frame showing this atlas.
local function EachAtlas(frame, atlas, fn)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and region:GetAtlas() == atlas then fn(region) end
	end
end

local function ByAtlas(frame, atlas)
	local found
	EachAtlas(frame, atlas, function(region) found = found or region end)
	return found
end

local function HideAtlas(kit, frame, atlas)
	EachAtlas(frame, atlas, function(region) kit:Hide(region) end)
end

-- A font object brings its own color: the string's is recorded first, then reapplied (or `color`).
local function Font(kit, text, object, color)
	if not text then return end
	local r, g, b, a = text:GetTextColor()
	kit:Text(text, color or { r, g, b })
	kit:FontObject(text, object)
	if color then r, g, b = color[1], color[2], color[3] end
	text:SetTextColor(r, g, b, a)
end

local function Figure(kit, text, size, color)
	if not text then return end
	kit:Font(text, Shy.FONT_ROUNDED, size)
	if color then kit:Text(text, color) end
end

local function Faded(color, alpha)
	return { color[1], color[2], color[3], alpha }
end

local function Accent(alpha)
	local r, g, b = Theme.Accent()
	return { r, g, b, alpha }
end

-- Our own texture covering the whole frame.
local function Sheet(kit, owner, key, layer, sublevel)
	return ns.Own(kit, owner, key, function(o)
		local t = o:CreateTexture(nil, layer, nil, sublevel or 0)
		t:SetAllPoints(o)
		return t
	end)
end

-- A gradient fading out to the right.
local function Wash(texture, color, alpha)
	texture:SetColorTexture(1, 1, 1, 1)
	texture:SetGradient("HORIZONTAL", CreateColor(color[1], color[2], color[3], alpha), CreateColor(color[1], color[2], color[3], 0))
end

-- A short line fading out on each side of a section's name.
local function Flanks(kit, row)
	local c = UI.colors.border
	local clear, solid = CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], 1)
	local left = ns.Own(kit, row, "flankLeft", function(o)
		local t = o:CreateTexture(nil, "ARTWORK")
		t:SetSize(52, 1)
		t:SetPoint("LEFT", o, "LEFT", 2, 0)
		return t
	end)
	left:SetColorTexture(1, 1, 1, 1)
	left:SetGradient("HORIZONTAL", clear, solid)
	local right = ns.Own(kit, row, "flankRight", function(o)
		local t = o:CreateTexture(nil, "ARTWORK")
		t:SetSize(52, 1)
		t:SetPoint("RIGHT", o, "RIGHT", -2, 0)
		return t
	end)
	right:SetColorTexture(1, 1, 1, 1)
	right:SetGradient("HORIZONTAL", solid, clear)
end

-- Bars

local function InkBar(bar)
	local fill = bars[bar]
	if not fill then return end
	local base = BAR_ART[bar.Fill:GetAtlas()] or WHITE
	local r, g, b = bar.Fill:GetVertexColor()
	fill:SetVertexColor(base[1] * r, base[2] * g, base[3] * b)
end

local function FollowBar(self)
	if M.on then InkBar(self) end
end

local function ProgressBar(kit, bar)
	if not bar then return end
	HideAtlas(kit, bar, "common-stat-bar-BG")
	kit:Hide(bar.Fill)
	local rim = ns.Own(kit, bar, "rim", function(o)
		local t = o:CreateTexture(nil, "BACKGROUND", nil, 0)
		t:SetPoint("TOPLEFT", o, "LEFT", -1, BAR_H / 2 + 1)
		t:SetPoint("BOTTOMRIGHT", o, "RIGHT", 1, -BAR_H / 2 - 1)
		return t
	end)
	rim:SetColorTexture(0, 0, 0, 1)
	local track = ns.Own(kit, bar, "track", function(o)
		local t = o:CreateTexture(nil, "BACKGROUND", nil, 1)
		t:SetPoint("TOPLEFT", o, "LEFT", 0, BAR_H / 2)
		t:SetPoint("BOTTOMRIGHT", o, "RIGHT", 0, -BAR_H / 2)
		Skin.Hatch(t)
		return t
	end)
	track:SetVertexColor(C.well[1], C.well[2], C.well[3])
	-- Anchored to the right end of Blizzard's fill, which it sets a width on.
	bars[bar] = ns.Own(kit, bar, "fill", function(o)
		local t = o:CreateTexture(nil, "BORDER", nil, 1)
		t:SetPoint("TOPLEFT", o, "LEFT", 0, BAR_H / 2)
		t:SetPoint("BOTTOMRIGHT", o.Fill, "RIGHT", 0, -BAR_H / 2)
		Skin.Hatch(t)
		return t
	end)
	kit:Font(bar.Text, Shy.FONT_ROUNDED, 10, "OUTLINE")
	if Once(bar) then
		hooksecurefunc(bar, "SetFillTextureByColorType", FollowBar)
		if bar.UpdateBarColor then hooksecurefunc(bar, "UpdateBarColor", FollowBar) end
	end
	InkBar(bar)
end

-- The window

local function InkTitle()
	CharacterFrame.TitleContainer.TitleText:SetTextColor(C.text[1], C.text[2], C.text[3])
end

local function ShowFace()
	if not own.face then return end
	SetPortraitTexture(own.face, "player")
	own.face:SetTexCoord(unpack(FACE))
end

local function PaintWindow(kit)
	local frame = CharacterFrame
	local set = ns.Window(kit, frame, { portrait = "own" })
	local holder = frame.PortraitContainer
	-- The face stands where the window's icon does: inside the look's border (set.iconX), placed again each paint.
	local rim = ns.Own(kit, holder, "faceRim", function(o)
		local t = o:CreateTexture(nil, "OVERLAY", nil, 0)
		t:SetSize(WIN.icon + 2, WIN.icon + 2)
		return t
	end)
	rim:ClearAllPoints()
	rim:SetPoint("TOPLEFT", frame, "TOPLEFT", set.iconX - 1, set.iconY + 1)
	rim:SetColorTexture(0, 0, 0, 1)
	own.face = ns.Own(kit, holder, "face", function(o)
		local t = o:CreateTexture(nil, "OVERLAY", nil, 1)
		t:SetSize(WIN.icon, WIN.icon)
		return t
	end)
	own.face:ClearAllPoints()
	own.face:SetPoint("TOPLEFT", frame, "TOPLEFT", set.iconX, set.iconY)
	ShowFace()
end

-- The first page: the ground, the model, the panes, the pane button

local function PaneHeight()
	return CHARACTER_FRAME_HEIGHT - WIN.head - PANE.x
end

-- Places a region of ours in the pane: x, y from its top left, w by h.
local function InPane(t, x, y, w, h)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", CharacterFrame.LeftPaneHost, "TOPLEFT", PANE.x + x, -(WIN.head - 20) - y)   -- the pane starts 20 down
	t:SetSize(w, h)
end

-- A texture of ours on the window's frame, over its fill and under its edge. The ground's sublevels are -1 and
-- up, over the look's face (BACKGROUND -5 to -2).
local function Layer(kit, key, sublevel, blend)
	return ns.Own(kit, CharacterFrame, key, function(o)
		local t = o:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		if blend then t:SetBlendMode(blend) end
		return t
	end)
end

-- The brand's glow stretched to 2 hw by 2 hh about x, y of the pane, cut by tex coords where the pane ends.
local function Round(t, spec, h)
	local x, y, hw, hh, alpha = unpack(spec)
	local left, right = math.max(0, x - hw), math.min(PANE.w, x + hw)
	local top, bottom = math.max(0, y - hh), math.min(h, y + hh)
	t:SetTexture(Shy.Brand.GLOW)
	t:SetTexCoord((left - x + hw) / (2 * hw), (right - x + hw) / (2 * hw), (top - y + hh) / (2 * hh), (bottom - y + hh) / (2 * hh))
	t:SetAlpha(alpha)
	InPane(t, left, top, right - left, bottom - top)
	return t
end

-- The race's painting cut to the pane's shape at one scale. Returns the path of its files.
local function Painting(kit, h)
	local _, race = UnitRace("player")
	if issecretvalue(race) or race == nil then return end
	local path = DressUpTexturePath(race)
	local tint = HOME[race] or HOME_TINT
	local scale = h / (ART.h - 2 * ART.trim)   -- units a texel
	local keep = PANE.w / scale                -- texels across
	local left, top = (ART.w - keep) / 2, ART.trim
	local right, bottom = left + keep, ART.h - ART.trim
	for i = 1, 4 do
		local wide, low = i % 2 == 0, i > 2
		local x0, x1 = wide and ART.cut or left, wide and right or ART.cut
		local y0, y1 = low and ART.cut or top, low and bottom or ART.cut
		local fx, fy = wide and ART.cut or 0, low and ART.cut or 0   -- where the file starts in the painting
		local fw, fh = wide and ART.right or ART.cut, low and ART.low or ART.cut
		local t = Layer(kit, "home" .. i, -1)
		t:SetTexture(path .. i)
		t:SetTexCoord((x0 - fx) / fw, (x1 - fx) / fw, (y0 - fy) / fh, (y1 - fy) / fh)
		t:SetVertexColor(tint, tint, tint)
		InPane(t, (x0 - left) * scale, (y0 - top) * scale, (x1 - x0) * scale, (y1 - y0) * scale)
		ground[#ground + 1] = t
	end
	return path
end

-- Wisps of light that scroll sideways, under the burn so they fade where the painting does.
local function Haze(kit)
	local light = Theme.light
	for i, spec in ipairs(HAZE) do
		local t = ns.Own(kit, CharacterFrame, "haze" .. i, function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, 0)
			t:SetTexture(GROUND .. "Haze", "REPEAT", "CLAMP")
			t:SetBlendMode("ADD")
			drift[t] = { gone = 0 }
			return t
		end)
		local width, seconds, from, alpha = unpack(spec)
		local d = drift[t]
		d.from, d.span, d.seconds = from, PANE.w / width, seconds
		t:SetTexCoord(from + d.gone, from + d.gone + d.span, 0, 1)
		t:SetVertexColor(light[1], light[2], light[3])
		t:SetAlpha(alpha)
		InPane(t, 0, HAZE.top, PANE.w, HAZE.h)
		ground[#ground + 1] = t
	end
end

local function Ground(kit)
	local h = PaneHeight()
	local path = Painting(kit, h)
	Haze(kit)
	local burn = Layer(kit, "burn", 1)
	burn:SetTexture(GROUND .. "Burn")
	burn:SetVertexColor(C.panel[1], C.panel[2], C.panel[3])
	InPane(burn, 0, 0, PANE.w, h)
	local light, r, g, b = Theme.light, Theme.Accent()
	local behind = Round(Layer(kit, "behind", 3, "ADD"), BEHIND, h)
	behind:SetVertexColor(light[1], light[2], light[3])
	local shadow = Round(Layer(kit, "shadow", 4), SHADOW, h)
	shadow:SetVertexColor(0, 0, 0)
	local pool = Round(Layer(kit, "pool", 5, "ADD"), POOL, h)
	pool:SetVertexColor(r, g, b)
	for _, t in ipairs({ burn, behind, shadow, pool }) do ground[#ground + 1] = t end
	if not path then return end
	-- The painting's light over the stats: the stretch of so few texels is the blur.
	for i = 5, #SKY do
		local fall, alpha = SKY[i][1], SKY[i][2]
		local t = Layer(kit, "sky" .. i, 2, "ADD")
		t:SetTexture(path .. 1)
		t:SetTexCoord(SKY[1] / ART.cut, SKY[2] / ART.cut, SKY[3] / ART.cut, (SKY[3] + SKY[4] * fall) / ART.cut)
		t:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, alpha))
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", CharacterFrame.LeftPaneHost, "TOPRIGHT", 1, -(WIN.head - 20))
		t:SetSize(CHARACTER_FRAME_WIDTH - CHARACTER_FRAME_COLLAPSED_WIDTH - 4, fall)
		sky[#sky + 1] = t
	end
end

-- Moves each haze layer along by its share of a tile; the file repeats across, so a whole tile looks the same.
local function Drift(_, elapsed)
	for t, d in pairs(drift) do
		if t:IsShown() then
			d.gone = (d.gone + elapsed / d.seconds) % 1
			local u = d.from + d.gone
			t:SetTexCoord(u, u + d.span, 0, 1)
		end
	end
end

-- The ground shows with the first page, the sky only beside the stats.
local function ShowGround()
	local page = M.on and PaperDollFrame:IsShown()
	for _, t in ipairs(ground) do t:SetShown(page) end
	local open = page and not CharacterFrame:IsRightPaneCollapsed()
	for _, t in ipairs(sky) do t:SetShown(open) end
end

-- The header line's light, falling down every page of the window.
local function Shed(kit)
	local t = ns.Own(kit, CharacterFrame, "shed", function(o)
		local t = o:CreateTexture(nil, "BACKGROUND", nil, 2)
		t:SetPoint("TOPLEFT", o, "TOPLEFT", PANE.x, -WIN.head)
		t:SetPoint("TOPRIGHT", o, "TOPRIGHT", -PANE.x, -WIN.head)
		t:SetHeight(SHED.h)
		t:SetBlendMode("ADD")
		return t
	end)
	local r, g, b = Theme.Accent()
	t:SetColorTexture(1, 1, 1, 1)
	t:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, SHED.alpha))
end

-- The class crest Blizzard keeps behind the stats, in the light of the accent, seen through a soft mask.
local function Crest(kit)
	local pane = CharacterStatsPaneScrollBox
	local atlas = pane.ClassBackground:GetAtlas()
	if not atlas then return end
	local mask = ns.Own(kit, pane, "crestMask", function(o)
		local m = o:CreateMaskTexture()
		m:SetTexture(GROUND .. "Feather", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		return m
	end)
	local r, g, b = Theme.Ramp(1)
	local first
	for i = 1, CREST.layers do   -- one over the other, for strength
		local t = ns.Own(kit, pane, "crest" .. i, function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, i)
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 5)   -- where Blizzard stands its own
			t:SetBlendMode("ADD")
			t:AddMaskTexture(mask)
			return t
		end)
		t:SetAtlas(atlas, true)
		t:SetDesaturated(true)
		t:SetVertexColor(r, g, b)
		first = first or t
	end
	local inset = CREST.inset
	mask:ClearAllPoints()
	mask:SetPoint("TOPLEFT", first, "TOPLEFT", inset[1], -inset[2])
	mask:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", -inset[3], inset[4])
end

-- The caret points right while the stats pane is collapsed.
local function PointToggle()
	if own.caret then own.caret:Turn(CharacterFrame:IsRightPaneCollapsed() and math.pi / 2 or -math.pi / 2) end
end

local function PaintDoll(m, kit)
	local frame = CharacterFrame
	local left, right = frame.LeftPaneHost, frame.RightPaneHost
	HideAtlas(kit, left, "UI-Character-Info-General-BG")
	HideAtlas(kit, right, "UI-Character-Info-Stat-BG")
	kit:Hide(right.StoneBg)
	for _, child in ipairs({ right:GetChildren() }) do HideAtlas(kit, child, "common-framedivider") end
	local divider = ns.Hairline(kit, right, "divider")
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(WIN.head - 20))   -- the pane starts 20 down
	divider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 2)
	divider:SetWidth(1)

	local strip = PaperDollFrame.TopBackgroundStripHost
	kit:Hide(strip.TopBackgroundStrip)
	kit:Hide(strip.TopBackgroundStripBottomEdge)

	-- Blizzard's own race painting is greyed (PaperDollBgDesaturate) and stretched unevenly: ours stands in for it.
	local scene = CharacterModelScene
	for _, key in ipairs(RACE) do kit:Fade(scene[key], 0) end
	kit:Hide(scene.BackgroundOverlay)
	wipe(ground)
	wipe(sky)
	if m.opt.home then
		Ground(kit)
	else
		local well = ns.Own(kit, scene, "well", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, -8)
			t:SetTexture(Skin.WELL)
			t:SetTextureSliceMargins(WELL_SLICE, WELL_SLICE, WELL_SLICE, WELL_SLICE)
			t:SetPoint("TOPLEFT", left, "TOPLEFT", 5, -(WIN.head + 2 - 20))
			t:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -3, 5)
			return t
		end)
		well:SetVertexColor(C.well[1], C.well[2], C.well[3])
	end
	for _, key in ipairs(MODEL_BUTTONS) do
		local button = scene.ControlFrame[key]
		kit:Hide(button:GetNormalTexture())
		kit:Hide(button:GetPushedTexture())
		kit:Key(button, { inset = { 5, 5, 5, 5 } })
		kit:Tint(button.Icon, C.glyph)
	end

	Font(kit, CharacterLevelText, UI.TextFont(12), C.text)
	Font(kit, PetCharacterLevelText, UI.TextFont(12), C.text)
	ProgressBar(kit, PetPaperDollFrameExpBar)

	local toggle = frame.RightPaneToggleButton
	kit:Hide(toggle:GetNormalTexture())     -- Blizzard swaps the files but leaves the alpha
	kit:Hide(toggle:GetPushedTexture())
	kit:Hide(toggle:GetHighlightTexture())
	own.caret = kit:Key(toggle, { inset = { 4, 4, 4, 4 }, icon = Skin.GLYPH.caret })
	PointToggle()
end

-- Gear

local AMMO_ARROW = { air = 2 }   -- from each slot's edge to the arrow's art (which keeps a little room of its own round the arrow)

local function Slots()
	local list = {}
	for _, slot in ipairs(PaperDollItemsFrame.EquipmentSlots) do list[#list + 1] = slot end
	for _, slot in ipairs(PaperDollItemsFrame.WeaponSlots) do list[#list + 1] = slot end
	list[#list + 1] = CharacterAmmoSlot
	return list
end

local function SlotEmpty(slot)
	local picture = GetInventoryItemTexture("player", slot:GetID())
	return not issecretvalue(picture) and picture == nil
end

-- An empty slot's placeholder icon is dimmed and desaturated.
local function ShowSlot(slot)
	local tile = tiles[slot]
	if not (tile and M.on) then return end
	local empty = SlotEmpty(slot)
	M.kit:Fade(slot.icon, empty and 0.35 or 1)
	if empty then slot.icon:SetDesaturated(true) end   -- Blizzard desaturates a filled slot itself while it is locked
	tile:Empty(empty)
	-- The slot shows the quality; Blizzard's square IconBorder is hidden.
	M.kit:Hide(slot.IconBorder)
	tile:Quality(not empty and GetInventoryItemQuality("player", slot:GetID()) or nil)
end

local function PaintSlots(kit)
	for _, slot in ipairs(Slots()) do
		kit:Hide(slot.BorderFrame)          -- nil on the ammo slot
		-- Getters, not keys: the ammo slot's XML defines its textures without the item button's keys.
		kit:Hide(slot:GetNormalTexture())
		kit:Hide(slot:GetHighlightTexture())
		tiles[slot] = kit:Tile(slot, { icon = slot.icon })
		ns.Lit(kit, slot:GetPushedTexture(), slot, C.lit)
		ns.Number(kit, slot.Count)
		if slot.popoutButton then kit:Button(slot.popoutButton, C.metal, C.lit, C.hover) end
		ShowSlot(slot)
	end
	local ammo = CharacterAmmoSlot
	HideAtlas(kit, ammo, "UI-Character-Info-GearSlotSmall")
	-- Its count. The game sets it at a full slot's size, where three digits are as wide as this small slot and run out
	-- of it: it takes the size the family's slots give a count at this width, and their seat in the slot's corner.
	local inX, upY = Shy.Slot.CountSeat()
	kit:Font(ammo.Count, Shy.FONT_ROUNDED, Shy.Slot.CountSize(ammo:GetWidth()), "OUTLINE")
	kit:Place(ammo.Count, nil, nil, { "BOTTOMRIGHT", ammo, "BOTTOMRIGHT", -inX, upY })
	-- The arrow to the ammo slot. The game draws it to lie on its stone seats: longer than the room between the ranged
	-- slot and the ammo slot, it would stand over both tiles and the ammo's count. It is fitted to that room instead
	-- (as wide as the ammo slot's own anchor sets it from the ranged slot), AMMO_ARROW.air clear of each slot, on the
	-- room's middle, its art's shape kept.
	local _, _, _, room = ammo:GetPoint(1)
	local fits = type(room) == "number" and not issecretvalue(room) and room > 2 * AMMO_ARROW.air
	for _, child in ipairs({ ammo:GetChildren() }) do
		EachAtlas(child, "UI-Character-Info-GearSlot-Arrow", function(arrow)
			kit:Tint(arrow, C.metal)
			local wide, tall = arrow:GetSize()
			if fits and wide > 0 then
				local across = room - 2 * AMMO_ARROW.air
				kit:Place(arrow, across, across * tall / wide, { "CENTER", ammo, "LEFT", -room / 2, 0 })
			end
		end)
	end
end

-- The small tabs over the stats

local function SideTabs()
	return { PaperDollSidebarTab1, PaperDollSidebarTab2, PaperDollSidebarTab3, PaperDollSidebarTab4 }
end

local function SyncSideTabs()
	if not M.on then return end
	for _, tab in ipairs(SideTabs()) do
		local a = art[tab]
		if a then
			local open = tab:GetChecked() == true
			a.tile:Steel(open and C.hover or nil)
			a.line:SetShown(open)
			local v = open and 1 or DIM
			tab.Icon:SetVertexColor(v, v, v)
		end
	end
end

local function PaintSideTabs(kit)
	for i, tab in ipairs(SideTabs()) do
		HideAtlas(kit, tab, "UI-Character-Info-StatTab")
		kit:Hide(tab:GetCheckedTexture())
		local tile = kit:Tile(tab, { x = 4, y = 4 })
		kit:Place(tab.Icon, 32, 32, { "CENTER", tab, "CENTER", 0, 0 })
		if i == 1 then kit:Crop(tab.Icon, unpack(FACE)) end
		kit:Tint(tab.Icon, WHITE, true)
		local line = ns.Own(kit, tab, "line", function(o)
			local t = o:CreateTexture(nil, "ARTWORK")
			t:SetPoint("TOPLEFT", o, "BOTTOMLEFT", 8, 0)
			t:SetPoint("TOPRIGHT", o, "BOTTOMRIGHT", -8, 0)
			t:SetHeight(2)
			return t
		end)
		line:SetColorTexture(Theme.light[1], Theme.light[2], Theme.light[3], 1)
		art[tab] = { tile = tile, line = line }
	end
	local rule = ns.Hairline(kit, PaperDollSidebarTabs, "rule")
	rule:ClearAllPoints()
	rule:SetPoint("TOPLEFT", CharacterFrame.RightPaneHost.StoneBg, "BOTTOMLEFT", 1, 0)
	rule:SetSize(230, 1)
	SyncSideTabs()
end

-- Stats, titles, gear sets

local function Pane(kit, pane)
	kit:Hide(pane.Border)
	HideAtlas(kit, pane, "UI-Character-Info-ScrollLine")
	ns.ScrollBar(kit, pane.ScrollBar)
end

-- A reused row keeps its skin (Blizzard's initializers undo nothing here), so a row the kit
-- already has is skipped: the stats are rebuilt on every aura change.
local function StatRow(kit, row)
	if kit:Has(row.Background) then return end
	if row.Title then
		kit:Hide(row.Background)
		Font(kit, row.Title, UI.TitleFont(12), UI.colors.head)
		Flanks(kit, row)
		return
	end
	-- Blizzard shows this on every other row; only its art changes.
	kit:Art(row.Background, Faded(UI.colors.row, 0.78), { fit = row, x = 3 })
	Font(kit, row.Label, UI.TextFont(11), UI.colors.dim)
	Figure(kit, row.Value, 11, C.text)
end

local function TitleRow(kit, row)
	if kit:Has(row.Stripe) then return end
	kit:Art(row.Stripe, Faded(UI.colors.row, 0.78), { fit = row })
	kit:Art(row.Check, CHECK, { color = C.on })
	kit:Fade(row.SelectedBar, 1)
	kit:Art(row.SelectedBar, Accent(0.24), { blend = "BLEND" })
	kit:Art(row:GetHighlightTexture(), Faded(C.hover, 0.14), { blend = "BLEND" })
	Font(kit, row.text, UI.TextFont(11), C.text)
end

local function SetRow(kit, row)
	kit:Art(ByAtlas(row, "UI-Character-Info-OutfitCard"), Faded(UI.colors.row, 0.78))
	kit:Art(row.HighlightBar, Faded(C.hover, 0.14))
	kit:Art(row.SelectedBar, Accent(0.24))
	kit:Art(row.Check, CHECK, { color = C.on })
	HideAtlas(kit, row, "UI-Character-Info-OutfitIcon-Frame")
	kit:Tile(row, { to = row.icon, icon = row.icon })
	kit:Crop(row.icon, unpack(ICON))
	kit:Tint(row.DeleteButton.texture, C.glyph)
	kit:Tint(row.EditButton.texture, C.glyph)
	-- Blizzard colors the name gold, or red while set pieces are missing: the color is left alone.
	Font(kit, row.text, UI.TextFont(12))
	local r, g, b = row.text:GetTextColor()
	local gold = NORMAL_FONT_COLOR
	if math.abs(r - gold.r) < 0.01 and math.abs(g - gold.g) < 0.01 and math.abs(b - gold.b) < 0.01 then
		row.text:SetTextColor(C.text[1], C.text[2], C.text[3])
	end
end

local function PaintSets(kit)
	local pane = PaperDollFrame.EquipmentManagerPane
	Pane(kit, pane)
	ns.Button(kit, pane.EquipSet, { 2, 3, 2, 3 })
	ns.Button(kit, pane.SaveSet, { 2, 3, 2, 3 })
	local new = pane.NewSet
	kit:Hide(new.StateTexture)   -- its atlas is reset on every state change
	kit:Key(new, { inset = { 2, 3, 2, 3 } })
	kit:Art(ByAtlas(new, "UI-Character-Info-Icon-Add"), Skin.GLYPH.plus, { color = UI.colors.good })
	for _, region in ipairs({ new:GetRegions() }) do
		if region:IsObjectType("FontString") then Font(kit, region, UI.TextFont(12), UI.colors.good) end
	end
	ns.IconPicker(kit, GearManagerPopupFrame)
end

-- The detail panes (CharacterFrameSidePaneTemplate)

local function PaneRows(kit, pane)
	for _, row in ipairs({ pane.Content:GetChildren() }) do
		if row.Background then
			kit:Hide(row.Background)
			Font(kit, row.Label, UI.TitleFont(12), UI.colors.head)
			Flanks(kit, row)
		elseif row.IconSlot then
			kit:Hide(row.IconSlot)
			kit:Tile(row, { to = row.Icon, icon = row.Icon })
			Font(kit, row.Label, UI.TextFont(12))
		else
			Font(kit, row.Label, UI.TextFont(12))
			Figure(kit, row.Value, 12)
		end
	end
end

-- The pane's title in the window's text color; the reputation pane's standing in its bar's color.
local function InkPane(pane)
	-- Blizzard colors the title through SetVertexColor: reset to white so the text color below is the whole color.
	pane.Title:SetVertexColor(1, 1, 1)
	pane.Title:SetTextColor(C.text[1], C.text[2], C.text[3])
	local fill = pane.StandingBar and bars[pane.StandingBar]
	if fill then pane.Subtitle:SetTextColor(fill:GetVertexColor()) end
end

local function PaintPane(kit, pane)
	Font(kit, pane.Title, UI.TitleFont(15), C.text)
	Font(kit, pane.Subtitle, UI.NameFont(11))
	Font(kit, pane.EmptyText, UI.TextFont(12), UI.colors.dim)
	Font(kit, pane.Description.ScrollBox.FontStringContainer.FontString, UI.TextFont(11))
	ns.ScrollBar(kit, pane.DescriptionScrollBar)
	kit:Hide(pane.Divider)
	-- On the footer, which Blizzard shows and hides together with the divider.
	local rule = ns.Hairline(kit, pane.Footer, "rule")
	rule:ClearAllPoints()
	rule:SetPoint("LEFT", pane.Divider, "CENTER", -98, 0)
	rule:SetPoint("RIGHT", pane.Divider, "CENTER", 98, 0)
	rule:SetHeight(1)
	PaneRows(kit, pane)
	InkPane(pane)
end

local function Checkbox(kit, check, color)
	ns.Check(kit, check, { color = color })
	Font(kit, check.Label, UI.TextFont(11))
end

local function PaintPanes(kit)
	for _, pane in ipairs(CharacterFrame.SidePanes) do PaintPane(kit, pane) end

	local faction = ReputationFrame.ReputationDetailFrame
	ProgressBar(kit, faction.StandingBar)
	Checkbox(kit, faction.AtWarCheckbox, UI.colors.bad)
	Checkbox(kit, faction.MakeInactiveCheckbox)
	Checkbox(kit, faction.WatchFactionCheckbox)
	ns.Button(kit, faction.ViewRenownButton)
	InkPane(faction)

	ProgressBar(kit, SkillsFrame.SkillDetailFrame.RankBar)

	local currency = TokenFrame.DetailFrame
	Checkbox(kit, currency.InactiveCheckbox)
	Checkbox(kit, currency.BackpackCheckbox)
	ns.Button(kit, currency.CurrencyTransferToggleButton)
end

-- The list pages

local function ShowFold(source, atlas)
	local glyph = folds[source]
	if not glyph then return end
	local shut = atlas == "common-button-list-plus" or atlas == "campaign_headericon_closed"
	glyph:SetTexture(shut and Skin.GLYPH.plus or Skin.GLYPH.minus)
end

-- Blizzard's collapse icon is faded; our plus or minus follows the atlas Blizzard sets on it.
local function Fold(kit, owner, source, x)
	kit:Hide(source)
	local glyph = ns.Own(kit, owner, "fold", function(o)
		local t = o:CreateTexture(nil, "ARTWORK")
		t:SetSize(10, 10)
		t:SetPoint("LEFT", o, "LEFT", x, 0)
		return t
	end)
	glyph:SetVertexColor(C.glyph[1], C.glyph[2], C.glyph[3], 0.8)
	folds[source] = glyph
	if Once(source) then hooksecurefunc(source, "SetAtlas", ShowFold) end
	ShowFold(source, source:GetAtlas())
end

local function Header(kit, row)
	HideAtlas(kit, row, "common-button-list-collapseExpand")   -- the bar and its hover glow
	Fold(kit, row, row.StateIcon, 3)
	Font(kit, row.Name, UI.TitleFont(12), UI.colors.head)
	kit:Place(row.Name, nil, nil, { "LEFT", row, "LEFT", 20, 0 })
	local rule = ns.Hairline(kit, row, "rule")
	rule:ClearAllPoints()
	rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	rule:SetHeight(1)
	Sheet(kit, row, "hot", "HIGHLIGHT"):SetColorTexture(C.hover[1], C.hover[2], C.hover[3], 0.08)
end

-- Runs after Blizzard sets an entry's highlight: shows our mark for selected or at war.
local function SyncRow(row)
	local marks = rows[row]
	if not marks then return end
	local picked = M.on and row:IsSelected() == true
	marks.wash:SetShown(picked)
	marks.line:SetShown(picked)
	marks.war:SetShown(M.on and not picked and row.IsAtWar ~= nil and row:IsAtWar() == true)
end

local function Entry(kit, row, content)
	local glow = content.BackgroundHighlight
	if glow then
		for _, region in ipairs(glow.TextureRegions) do kit:Hide(region) end
	end
	Sheet(kit, row, "hot", "HIGHLIGHT"):SetColorTexture(UI.colors.row[1], UI.colors.row[2], UI.colors.row[3], 0.8)
	if row.IsSelected then
		local wash = Sheet(kit, row, "wash", "BACKGROUND", 1)
		Wash(wash, { Theme.Accent() }, 0.3)
		local war = Sheet(kit, row, "war", "BACKGROUND", 0)
		Wash(war, UI.colors.bad, 0.22)
		local line = ns.Own(kit, row, "line", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, 2)
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
			t:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
			t:SetWidth(2)
			return t
		end)
		line:SetColorTexture(Theme.light[1], Theme.light[2], Theme.light[3], 1)
		rows[row] = { wash = wash, war = war, line = line }
		if Once(row) then hooksecurefunc(row, "RefreshBackgroundHighlightOpacity", SyncRow) end
		SyncRow(row)
	end
	-- Blizzard greys a currency you have none of: its color stays.
	Font(kit, content.Name, UI.TextFont(12), (not row.RefreshTextColor) and C.text or nil)
	Figure(kit, content.Value, 11)
	Figure(kit, content.Count, 11)
	ProgressBar(kit, content.ReputationBar)
	ProgressBar(kit, content.SkillsBar)
	kit:Art(content.WatchedCurrencyCheck, CHECK, { color = C.on })
	kit:Crop(content.CurrencyIcon, unpack(ICON))
end

-- Once per row. A header is initialized again between mouse down and up, while Blizzard has its
-- name nudged: re-placing the name then would leave it a unit off permanently.
local function ListRow(kit, row)
	if row.StateIcon then
		if not kit:Has(row.StateIcon) then Header(kit, row) end
		return
	end
	local toggle = row.ToggleCollapseButton
	if toggle and not kit:Has(toggle:GetNormalTexture()) then
		kit:Hide(toggle:GetPushedTexture())
		kit:Hide(toggle:GetHighlightTexture())
		Fold(kit, toggle, toggle:GetNormalTexture(), 5)
	end
	if row.Content then
		if not kit:Has(row.Content.Name) then Entry(kit, row, row.Content) end
	elseif row.Text then
		Font(kit, row.Text, UI.TitleFont(11))   -- a currency list's second-level header
	end
end

local function PaintLists(kit)
	for _, name in ipairs(PAGES) do
		local page = _G[name]
		for _, child in ipairs({ page.ScrollBox:GetChildren() }) do HideAtlas(kit, child, "UI-Character-Info-ScrollLine-Long") end
		ns.ScrollBar(kit, page.ScrollBar)
	end
	ns.Dropdown(kit, ReputationFrame.filterDropdown, { ours = true })
end

-- The PvP page

local function PaintPvP(kit)
	local page = PVPRankFrame
	Font(kit, page.SeasonTimerField, UI.TextFont(12), UI.colors.dim)
	local info = page.MainInfoFrame
	Font(kit, info.CurrentSeasonField, UI.TitleFont(13), UI.colors.head)
	Font(kit, info.CurrentRankField, UI.TitleFont(16), C.text)
	Font(kit, info.CurrentRankProgressField, UI.TextFont(12), UI.colors.dim)
	kit:Hide(info.Line)   -- a gold band behind the rank's name
	local rule = ns.Hairline(kit, info, "rule")
	rule:ClearAllPoints()
	rule:SetPoint("TOP", info.CurrentRankField, "BOTTOM", 0, -8)
	rule:SetSize(220, 1)
	-- The rank medal and its progress arc stay; the gold halo and rings are hidden.
	local medal = info.RankProgressBarDisplay
	HideAtlas(kit, medal, "UI-Character-Info-Honor-Bar-BG-Glow")
	kit:Hide(medal.Bar)
	local reward = medal.NextRewardLevel
	kit:Hide(reward.RingBorder)
	kit:Font(reward.LevelLabel, Shy.FONT_ROUNDED, 14, "OUTLINE")
	kit:Text(reward.LevelLabel, C.text)
end

-- The window's side tabs

local function Tabs()
	return CharacterFrame.ModeTabs.Tabs
end

-- Blizzard resets the icon's size and tex coords whenever a tab is checked (UpdateIconInterior).
local function FitIcon(tab, i)
	tab.Icon:SetSize(TAB_ICON, TAB_ICON)
	tab.Icon:SetTexCoord(unpack(i == 1 and FACE or ICON))   -- the first tab is your portrait
end

-- Updates the open tab's highlight, the spine's length and the dividers.
local function SyncTabs()
	if not M.on then return end
	local last
	for _, tab in ipairs(Tabs()) do
		if tab:IsShown() then last = tab end
	end
	for _, tab in ipairs(Tabs()) do
		local a = art[tab]
		if a then
			local open = tab.SelectedTexture:IsShown()
			a.tile:Steel(open and C.hover or nil)
			a.wash:SetShown(open)
			a.line:SetShown(open)
			a.rule:SetShown(tab ~= last)
			local v = (open or a.over) and 1 or DIM
			tab.Icon:SetVertexColor(v, v, v)
		end
	end
	if own.spine then own.spine:Fit(last) end
end

-- The only Blizzard frames this module sizes.
local function SizeTabs()
	local function Size()
		for _, tab in ipairs(Tabs()) do
			if M.on then
				if not sizes[tab] then sizes[tab] = { tab:GetSize() } end
				tab:SetSize(TAB.w, TAB.h)
			elseif sizes[tab] then
				tab:SetSize(sizes[tab][1], sizes[tab][2])
				sizes[tab] = nil
			end
		end
	end
	if Tabs()[1]:IsProtected() then ns.AfterCombat("character:tabs", Size) else Size() end
end

local function PaintTabs(kit)
	SizeTabs()
	-- The spine behind the tabs (Widgets.lua), as the spellbook's.
	own.spine = ns.Spine(kit, CharacterFrame, "spine")
	local accent = { Theme.Accent() }
	for i, tab in ipairs(Tabs()) do
		kit:Hide(tab.Background)
		kit:Hide(tab.SelectedTexture)    -- SyncTabs reads its shown state for the open tab
		kit:Hide(tab.HighlightTexture)
		-- Blizzard pulses TabGlow for attention.
		-- Where the slot stands (TAB.left in from the window's edge): the tile and the pulse are fitted to it,
		-- so a press nudges only the picture.
		local seat = ns.Own(kit, tab, "seat", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND")
			t:SetSize(TAB_ICON, TAB_ICON)
			t:SetPoint("CENTER", o, "CENTER", TAB.x, 0)
			return t
		end)
		kit:Lit(tab.TabGlow, seat, accent)
		local tile = kit:Tile(tab, { to = seat })
		kit:Place(tab.Icon, TAB_ICON, TAB_ICON, { "CENTER", tab, "CENTER", TAB.x, 0 })
		kit:Unmask(tab.Icon, tab.Mask)
		kit:Crop(tab.Icon, unpack(ICON))
		kit:Tint(tab.Icon, WHITE, true)
		FitIcon(tab, i)

		-- A cell is the tab plus the 2 gap under it.
		local wash = ns.Own(kit, tab, "wash", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, -7)
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 1)
			t:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, -1)
			return t
		end)
		Wash(wash, accent, 0.3)
		local hot = ns.Own(kit, tab, "hot", function(o)
			local t = o:CreateTexture(nil, "HIGHLIGHT")
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 1)
			t:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, -1)
			return t
		end)
		Wash(hot, C.hover, 0.16)
		local line = ns.Own(kit, tab, "line", function(o)
			local t = o:CreateTexture(nil, "ARTWORK")
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
			t:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, 0)
			t:SetWidth(2)
			return t
		end)
		line:SetColorTexture(1, 1, 1, 1)
		line:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
		local rule = ns.Hairline(kit, tab, "rule")
		rule:ClearAllPoints()
		rule:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 5, 0)
		rule:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", -5, 0)
		rule:SetHeight(1)
		art[tab] = { tile = tile, wash = wash, line = line, rule = rule, over = art[tab] and art[tab].over }
	end
	SyncTabs()
end

-- Every pooled list and the function that skins one of its rows.
local function Lists()
	local doll = PaperDollFrame
	return {
		{ CharacterStatsPaneScrollBox.ScrollBox, StatRow },
		{ CharacterStatsPanePetScrollBox.ScrollBox, StatRow },
		{ doll.TitleManagerPane.ScrollBox, TitleRow },
		{ doll.EquipmentManagerPane.ScrollBox, SetRow },
		{ ReputationFrame.ScrollBox, ListRow },
		{ SkillsFrame.ScrollBox, ListRow },
		{ TokenFrame.ScrollBox, ListRow },
		{ StatisticsFrame.ScrollBox, ListRow },
	}
end

local function HookTabs()
	for i, tab in ipairs(Tabs()) do
		hooksecurefunc(tab, "SetChecked", function(self)
			if not M.on then return end
			FitIcon(self, i)
			SyncTabs()
		end)
		-- Blizzard nudges the icon on mouse down from its own anchor; ours stands on its seat, so nudge from there.
		tab:HookScript("OnMouseDown", function(self, button)
			if M.on and button == "LeftButton" then self.Icon:SetPoint("CENTER", self, "CENTER", TAB.x + 1, -1) end
		end)
		tab:HookScript("OnMouseUp", function(self, button)
			if M.on and button == "LeftButton" then self.Icon:SetPoint("CENTER", self, "CENTER", TAB.x, 0) end
		end)
		tab:HookScript("OnEnter", function(self)
			if art[self] then art[self].over = true end
			SyncTabs()
		end)
		tab:HookScript("OnLeave", function(self)
			if art[self] then art[self].over = false end
			SyncTabs()
		end)
	end
end

M = ns.Module({
	id = "character",
	title = "Character",
	desc = "Restyles the character window and all its tabs: a dark panel, gear in quality-colored slots, plain stat rows and square tabs down the right edge.",
	options = {
		{ key = "home", label = "Your race's home", default = true,
			desc = "Shows the painting of your race's home behind your character, or a plain dark background when off." },
	},

	Ready = function()
		return CharacterFrame ~= nil and PaperDollFrame ~= nil and ReputationFrame ~= nil and SkillsFrame ~= nil
			and PVPRankFrame ~= nil and TokenFrame ~= nil and StatisticsFrame ~= nil
	end,

	Hook = function(m)
		local frame = CharacterFrame
		hooksecurefunc(frame, "SetTitleColor", function()
			if m.on then InkTitle() end
		end)
		hooksecurefunc(frame, "UpdatePortrait", function()
			if m.on then ShowFace() end
		end)
		hooksecurefunc(frame, "UpdateRightPaneToggleButton", function()
			if m.on then
				PointToggle()
				ShowGround()
			end
		end)
		clock = CreateFrame("Frame", nil, PaperDollFrame)   -- runs only while the first page shows
		clock:SetScript("OnUpdate", Drift)
		PaperDollFrame:HookScript("OnShow", ShowGround)
		PaperDollFrame:HookScript("OnHide", ShowGround)
		hooksecurefunc(frame, "UpdateCharacterModeTabPortrait", function()
			if m.on then FitIcon(Tabs()[1], 1) end
		end)
		hooksecurefunc(frame, "UpdateTabLayout", SyncTabs)
		HookTabs()
		hooksecurefunc("PaperDollItemSlotButton_Update", ShowSlot)
		hooksecurefunc("PaperDollItemSlotButton_UpdateLock", ShowSlot)
		hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", SyncSideTabs)
		for _, list in ipairs(Lists()) do
			local dress = list[2]
			list[1]:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row)
				if m.on then dress(m.kit, row) end
			end, m)
		end
		for _, pane in ipairs(frame.SidePanes) do
			hooksecurefunc(pane, "LayoutRows", function(self)
				if m.on then PaneRows(m.kit, self) end
			end)
			hooksecurefunc(pane, "SetPaneTitleColor", function(self)
				if m.on then InkPane(self) end
			end)
		end
	end,

	-- Restores what the kit doesn't track. With the module still on, Paint follows.
	Clear = function(m)
		if m.on then return end
		SizeTabs()
		-- The title color Blizzard's UpdateTitle would set for the open page.
		local info = characterFrameDisplayInfo[CharacterFrame.activeSubframe] or characterFrameDisplayInfo.Default
		CharacterFrame.TitleContainer.TitleText:SetTextColor(info.titleColor:GetRGBA())
		for _, slot in ipairs(Slots()) do
			if SlotEmpty(slot) then slot.icon:SetDesaturated(false) end
		end
	end,

	Paint = function(m, kit)
		PaintWindow(kit)
		PaintDoll(m, kit)
		PaintSlots(kit)
		PaintSideTabs(kit)
		Pane(kit, CharacterStatsPaneScrollBox)
		kit:Hide(CharacterStatsPaneScrollBox.ClassBackground)
		Pane(kit, CharacterStatsPanePetScrollBox)
		Pane(kit, PaperDollFrame.TitleManagerPane)
		PaintSets(kit)
		PaintLists(kit)
		PaintPvP(kit)
		for _, list in ipairs(Lists()) do
			local dress = list[2]
			list[1]:ForEachFrame(function(row) dress(kit, row) end)
		end
		PaintPanes(kit)   -- after the lists: the reputation pane reads its bar's color
		PaintTabs(kit)
		Shed(kit)
		Crest(kit)
		ShowGround()
	end,
})
