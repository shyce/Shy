-- One plate: everything drawn for one unit, on its nameplate (Driver.lua).
--
--          [ 8 ][ 6 ][11 ]        auras                         (Auras.lua)
--        14 Defias Pillager       level, name, rank glyph
--    [==========    62%][<> 5]   ( )   housing (health), tag cell, raid mark
--      \ / / / / /       /             keel: combo points
--      \[#][==Fireball 1.4]/           keel: cast row           (Cast.lua)
--       `----------------'
--
-- Modes: "full" (above), "name" (name only, plus the line under it: an NPC's title, a player's <guild>).
-- A player's level stands before their name as a creature's does: an enemy's by difficulty, a friend's in the
-- quiet ink of an NPC's title. Their guild is green, in your color when it is yours too.
-- A player's pet (totem, guardian) is quieter than whoever it belongs to: as a name a size smaller, a friend's in a
-- soft green with whose it is under it, quieter still; yours in your color with nothing under it.
-- A name-only plate whose tag is a lead gets a plaque:  (?)= Innkeeper Farley =>
-- A lead is name only whatever it is to you (friend, wary, enemy) until it is targeted or fights.
--
-- Nameplate regions are restricted: measuring one (GetWidth, GetPoint, GetTextColor...) errors. So every
-- offset is a number from Layout.lua, pieces that follow the name are anchored to it, and colors are set
-- directly instead of through the theme helpers (which read colors back), then repainted on SHY_THEME.
-- Secret values (Units.lua) are passed straight to setters; where no setter takes one, the piece is left out.

local ADDON, ns = ...
local L, U = ns.Layout, ns.Units
local UI, Theme, Skin = Shy.UI, Shy.Theme, Shy.Skin
local Secret = ns.Secret
local C = L.COLORS

local P = {}
ns.Plate = P

local Plate = {}
Plate.__index = Plate

P.all = setmetatable({}, { __mode = "k" })   -- every plate, the spares too
-- The plates a change of target or focus can change (your target, your focus, or a secret answer), and those
-- under the mouse: kept as each plate learns it, so Driver.lua walks these alone.
P.aimed = setmetatable({}, { __mode = "k" })
P.hovered = setmetatable({}, { __mode = "k" })

local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
-- The plate's states, in its own colors and art (no light laid round it: that washes the art out). Under the mouse
-- its colors lift part way (Theme.Lift) and its art shines (UI.Shine: the art added over itself); your target's or
-- focus's plate, marked by "lift", all the way and brighter, its edge in your color (gold for your focus).
local HOVER_LIFT, HOVER_SHINE = 0.55, 0.25
local ACTIVE_LIFT, ACTIVE_SHINE = 1, 0.45
local ACTIVE = {}           -- the edge's color while the plate is marked (UpdateEdge)
local LOCK = 0.3            -- seconds the target mark flashes on a new target
local GAIN = 0.35           -- seconds a pip flashes when its combo point arrives
local GLEAM = 2.4           -- seconds between gleams at full combo points
local SHINE = 0.16          -- white added to every lit pip
local GLIDE = 0.3           -- seconds the bar takes to move between threat colors
local HOLD = 0.6            -- seconds the bar lights when threat becomes secure
local HOLD_LIGHT = 0.4      -- how bright
local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut

local FONTS = {
	shy = nil,   -- UI.NameFont's default
	game = { roman = "Fonts\\FRIZQT__.TTF", russian = "Fonts\\FRIZQT___CYR.TTF" },
}

-- A font family, so Cyrillic, Korean and Chinese names render.
function P.Font(size)
	local look = ns.T.db.font
	return UI.NameFont(math.floor(size + 0.5), "OUTLINE", FONTS[look], look == "game" and "game" or nil)
end

-- A digit's width at the count's size, read off a font string of our own (a nameplate's can't be measured): the widest
-- of the ten, to the quarter unit, into L.TAG_DIGIT for the tag's compartment.
local digits, measured
function P.MeasureDigit()
	-- Once a font: every plate the pool makes asks.
	local font = P.Font(L.TEXT)
	if font == measured then return end
	measured = font
	if not digits then
		digits = UIParent:CreateFontString(nil, "OVERLAY")
		digits:Hide()
	end
	digits:SetFontObject(font)
	local most = 0
	for d = 0, 9 do
		digits:SetText(tostring(d))
		local w = digits:GetUnboundedStringWidth()
		if w and not issecretvalue(w) and w > most then most = w end
	end
	if most > 0 then L.TAG_DIGIT = math.ceil(most * 4) / 4 end
end

local function Text(parent, size, justify)
	return UI.Words(parent, P.Font(size), nil, { world = true, wrap = false, justify = justify or "CENTER" })
end
P.Text = Text

local function Sliced(owner, layer, sublevel, file, margin)
	local t = owner:CreateTexture(nil, layer, nil, sublevel or 0)
	t:SetTexture(file)
	t:SetTextureSliceMargins(margin, margin, margin, margin)
	return t
end
P.Sliced = Sliced

local MINI_SIDES = { "Top", "Foot", "Left", "Right" }
local FACE_LAYERS = 5       -- the most layers a look's face lays (its miniArt's `face`)

-- A look's face in layers (miniArt's `face`) on `owner`, from sublevel `sub` up, hidden.
local function FaceSet(owner, sub)
	local set = {}
	for i = 1, FACE_LAYERS do
		local t = owner:CreateTexture(nil, "BACKGROUND", nil, sub + i - 1)
		t:Hide()
		set[i] = t
	end
	return set
end

local function Glyph(owner, name, size)
	local t = owner:CreateTexture(nil, "OVERLAY")
	t:SetTexture(L.GLYPHS)
	t:SetTexCoord(L.GlyphCoords(name))
	t:SetSize(size, size)
	return t
end
P.Glyph = Glyph

-- A hatched status bar with a dark track.
local function Bar(owner)
	local bar = CreateFrame("StatusBar", nil, owner)
	Skin.HatchBar(bar)
	bar.fill = bar:GetStatusBarTexture()
	Skin.Hatch(bar.fill)
	bar.trough = bar:CreateTexture(nil, "BACKGROUND")
	bar.trough:SetAllPoints()
	Skin.Hatch(bar.trough)
	bar.trough:SetVertexColor(0, 0, 0, 0.45)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end
P.Bar = Bar

-- Target mark color: the accent, 35% toward its light shade.
local function MarkColor()
	local r, g, b = Theme.Accent()
	local hot = UI.colors.hot
	return r + (hot[1] - r) * 0.35, g + (hot[2] - g) * 0.35, b + (hot[3] - b) * 0.35
end

-- Building

local playerClass

-- reader: what the plate reads its unit through (Units.lua unless given).
function P.Create(parent, reader)
	local self = setmetatable({ parent = parent, read = reader or U, mode = "full", casting = false, shines = {} }, Plate)
	P.all[self] = true
	playerClass = playerClass or UnitClassBase("player")

	-- The root has the housing's position and size; the housing fills it.
	local root = CreateFrame("Frame", nil, parent)
	self.root = root
	local house = CreateFrame("Frame", nil, root)
	house:SetAllPoints()
	self.house = house

	self.shade = Sliced(root, "BACKGROUND", -8, L.SHADE, L.SHADE_SLICE)

	self.bg = house:CreateTexture(nil, "BACKGROUND")
	self.bg:SetAllPoints()
	-- The look's material over the fill, inside the edge: it shows through the bar's empty part.
	self.surface = UI.LookSurface(house, "BACKGROUND", 1)
	self.surface:SetPoint("TOPLEFT", L.INSET, -L.INSET)
	self.surface:SetPoint("BOTTOMRIGHT", -L.INSET, L.INSET)
	-- A look whose face is its own (a sky) lays it in layers instead (LayMini), from a place of the plate's own: the
	-- layers are made when a look first lays one (Plate:Sky).
	self.seed = { math.random(), math.random() }

	local health = Bar(house)
	health:SetPoint("TOPLEFT", L.INSET, -L.INSET)
	health:SetHeight(L.HEALTH - 2 * L.INSET)
	self.health = health
	-- Faint fill color on the empty part of the bar.
	health.wash = health:CreateTexture(nil, "BACKGROUND", nil, 1)
	health.wash:SetAllPoints()
	-- Lights up once when threat becomes secure (UpdateColor).
	health.light = health:CreateTexture(nil, "OVERLAY")
	health.light:SetAllPoints()
	health.light:SetColorTexture(1, 1, 1, 1)
	health.light:SetBlendMode("ADD")
	health.light:SetAlpha(0)
	health.light:Hide()
	self.execute = health:CreateTexture(nil, "OVERLAY", nil, 1)
	self.execute:SetColorTexture(1, 1, 1, 0.55)
	self.execute:SetWidth(1)
	self.execute:Hide()

	-- Edge above the bars, text above the edge.
	local rim = CreateFrame("Frame", nil, house)
	rim:SetAllPoints()
	rim:SetFrameLevel(house:GetFrameLevel() + 3)
	self.rim = rim
	self.edge = Sliced(rim, "BORDER", 0, L.EDGE, L.EDGE_SLICE)
	self.edge:SetAllPoints()
	self:Shiny(self.edge, rim, "BORDER", 1)
	-- A look's mini border as files (its miniArt), laid by the plate's own numbers (LayMini): nothing on a nameplate
	-- may be measured, so no housing of the look's. Each side's run stands round the bar itself, on the root (under
	-- the bar, which cuts it clean at its own edge, and under the name over the plate): nothing dark between the two.
	-- A look whose mini border is its rim alone (a bezel: no runs) lays it round the plate, over the bar. Either is
	-- made when a look first lays it (Runs, Plate:LookRim): most looks have neither.
	self.mini = {}
	local over = CreateFrame("Frame", nil, house)
	over:SetAllPoints()
	over:SetFrameLevel(house:GetFrameLevel() + 4)
	self.over = over
	-- The target mark's pieces.
	local marks = CreateFrame("Frame", nil, root)
	marks:SetAllPoints()
	marks:SetFrameLevel(house:GetFrameLevel() + 4)
	self.marks = marks
	self.healthText = Text(over, L.TEXT, "RIGHT")
	self.healthText:SetPoint("RIGHT", health, "RIGHT", -L.TEXT_INSET, 0)

	-- The name has a single anchor so it sizes to its text; neighbors anchor to its ends.
	self.name = Text(root, ns.T.db.nameSize)
	-- A PvP flag's crest before a player's name (UpdateName): flagged is seen at a glance.
	self.crest = root:CreateTexture(nil, "OVERLAY")
	self.crest:SetPoint("RIGHT", self.name, "LEFT", -L.CREST_GAP, 0)
	self.crest:Hide()
	self.rank = Glyph(root, "wings", L.RANK)
	self.rank:SetPoint("LEFT", self.name, "RIGHT", 1, 0)
	self.rank:Hide()
	self.title = Text(root, L.TITLE)
	self.title:SetPoint("TOP", self.name, "BOTTOM", 0, -L.TITLE_GAP)
	self.title:Hide()

	self.mark = root:CreateTexture(nil, "OVERLAY")
	self.mark:SetTexture(RAID_ICONS)
	self.mark:SetSize(L.MARK, L.MARK)
	self.mark:Hide()

	-- The nameplate's click area, and the room it keeps among other nameplates (Driver.lua).
	self.bounds = CreateFrame("Frame", nil, root)
	self.berth = CreateFrame("Frame", nil, root)

	self:BuildTag()
	self:BuildSeal()
	self:BuildTarget()
	self:BuildKeel()
	ns.Cast.Build(self)
	ns.Auras.Build(self)
	if ns.Doom then ns.Doom.Build(self) end

	-- Runs flashes and the gleam; its OnUpdate is set only while one is active.
	self.lights = CreateFrame("Frame", nil, root)
	self.events = CreateFrame("Frame", nil, root)
	self.events:SetScript("OnEvent", function(_, event) self:OnEvent(event) end)
	self:Arrange()
	self:Paint()
	return self
end

-- The tag cell (icon, optional `back` and `face` textures under it and `over` over it, optional count) and
-- the "seat" (the same icon left of a name-only plate's name). A lead's plaque and its ring: BuildPlaque.
function Plate:BuildTag()
	local tag = CreateFrame("Frame", nil, self.root)
	tag:SetPoint("TOPLEFT", self.root, "TOPRIGHT", L.CELL_GAP, 0)
	tag:SetHeight(L.HEALTH)
	tag:Hide()
	tag.art = self:Shiny(tag:CreateTexture(nil, "ARTWORK"), tag, "ARTWORK", 1)
	tag.art:SetPoint("LEFT", L.INSET, 0)   -- inside the edge, like the bar
	tag.art:SetSize(L.TAG - 2 * L.INSET, L.TAG - 2 * L.INSET)
	tag.back = tag:CreateTexture(nil, "BORDER")
	tag.back:SetAllPoints(tag.art)
	tag.back:Hide()
	tag.face = self:Shiny(tag:CreateTexture(nil, "BORDER", nil, 1), tag, "BORDER", 2)
	tag.face:SetAllPoints(tag.art)
	tag.face:Hide()
	tag.over = self:Shiny(tag:CreateTexture(nil, "OVERLAY", nil, 1), tag, "OVERLAY", 2)
	tag.over:SetAllPoints(tag.art)
	tag.over:Hide()
	tag.count = Text(tag, L.TEXT, "LEFT")   -- placed in ArrangeMode
	-- On a full plate the tag is a compartment of the housing, which runs on past the bar to hold it: no fill or edge
	-- of its own, only a seam where the bar's end was (its edge's room), a dark groove and a line of the edge's color,
	-- inside the housing's edge top and foot.
	tag.groove = tag:CreateTexture(nil, "BORDER")
	tag.groove:SetColorTexture(0, 0, 0, 0.6)
	tag.groove:SetSnapToPixelGrid(true)   -- (a unit is not a whole pixel on a plate: kept to whole ones, it never smears)
	tag.groove:SetTexelSnappingBias(0)
	tag.groove:SetPoint("TOPLEFT", self.root, "TOPRIGHT", -L.INSET, -L.INSET)
	tag.groove:SetPoint("BOTTOMRIGHT", self.root, "BOTTOMRIGHT", -L.INSET + 1, L.INSET)
	tag.seam = self:Shiny(tag:CreateTexture(nil, "BORDER", nil, 1), tag, "BORDER", 2)
	tag.seam:SetColorTexture(1, 1, 1, 1)
	tag.seam:SetSnapToPixelGrid(true)
	tag.seam:SetTexelSnappingBias(0)
	tag.seam:SetPoint("TOPLEFT", tag.groove, "TOPRIGHT")
	tag.seam:SetPoint("BOTTOMRIGHT", tag.groove, "BOTTOMRIGHT", 1, 0)
	tag.groove:Hide()
	tag.seam:Hide()
	self.tag = tag
	self.seat = self.root:CreateTexture(nil, "OVERLAY")
	self.seat:SetSize(L.SEAT, L.SEAT)
	self.seat:SetPoint("RIGHT", self.name, "LEFT", -L.SEAT_GAP, 0)
	self.seat:Hide()
	self.seatBack = self.root:CreateTexture(nil, "OVERLAY", nil, -2)
	self.seatBack:SetAllPoints(self.seat)
	self.seatBack:Hide()
	self.seatFace = self.root:CreateTexture(nil, "OVERLAY", nil, -1)
	self.seatFace:SetAllPoints(self.seat)
	self.seatFace:Hide()
	self.seatOver = self.root:CreateTexture(nil, "OVERLAY", nil, 1)
	self.seatOver:SetAllPoints(self.seat)
	self.seatOver:Hide()
end

-- What few plates ever wear is made the first time one does, not with every plate: a plate is built in the middle of
-- a pull, a frame apiece, and a pull's plates are plain housings. Each maker reads nothing off the plate (it may be
-- on a nameplate by then) and leaves its pieces hidden, as the plate's own are until they are shown.

-- A mini border's eight runs (each side's, and what of it is in your color) for a look that has them as files, on
-- the root: `set` is the housing's (self.mini) or the plaque's (plaque.mini).
local function Runs(self, set)
	if not set.sides then
		local root = self.root
		set.sides, set.keys = {}, {}
		for _, side in ipairs(MINI_SIDES) do
			set.sides[side] = self:Shiny(root:CreateTexture(nil, "BORDER", nil, 0), root, "BORDER", 2)
			set.keys[side] = self:Shiny(root:CreateTexture(nil, "BORDER", nil, 1), root, "BORDER", 3)
			set.sides[side]:Hide()
			set.keys[side]:Hide()
		end
	end
	return set
end

-- A look's rim alone (a bezel: no runs) round the plate, over the bar.
function Plate:LookRim()
	local t = self.lookRim
	if not t then
		t = self:Shiny(self.rim:CreateTexture(nil, "BORDER", nil, 2), self.rim, "BORDER", 3)
		t:SetAllPoints()
		t:Hide()
		self.lookRim = t
	end
	return t
end

-- A plaque's piece: from the ring's middle to past the name's right end, `inset` in from the plaque's edge (anchored
-- to the name's two ends, so it spans the name without measuring it).
local function OnPlaque(self, t, inset)
	local def = L.PLAQUE
	local tall = ns.T.db.nameSize + def.rise
	local rank = self.rank:IsShown() and L.RANK + 1 or 0
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", self.tag, "CENTER", 0, tall / 2 - inset)
	t:SetPoint("BOTTOMRIGHT", self.name, "RIGHT", def.reach + rank - inset, -tall / 2 + inset)
end

-- The plaque (self.plaque: nil until a plate is a lead's name on one) is a housing as the plate's is, in the look
-- worn: its fill, the look's face over it and the look's edge round it (a look's mini rim, where it has one as
-- files), square in every look, and the ring its mark stands in. On the root, under the name; laid in ArrangeMode,
-- on the ring's middle and the name's right end, so it is never measured. Made in the colors and the look the plate
-- wears now (PaintPlaque).
function Plate:BuildPlaque()
	local plaque, def, root, tag = { mini = {} }, L.PLAQUE, self.root, self.tag
	plaque.fill = root:CreateTexture(nil, "BACKGROUND", nil, -7)
	plaque.surface = UI.LookSurface(root, "BACKGROUND", -6)
	plaque.strip = self:Shiny(Sliced(root, "BORDER", -4, L.EDGE, L.EDGE_SLICE), root, "BORDER", -3)
	plaque.rim = self:Shiny(root:CreateTexture(nil, "BORDER", nil, -2), root, "BORDER", -1)
	plaque.fill:Hide()
	plaque.strip:Hide()
	plaque.rim:Hide()
	tag.ring = self:Shiny(tag:CreateTexture(nil, "BACKGROUND", nil, -2), tag, "BACKGROUND", -1)
	tag.ring:SetTexture(def.ring)
	tag.ring:SetAllPoints()
	tag.ring:Hide()
	-- The look's own ring over the steel one's rim, where the look has one (UI.LookKind's `ring`: as UI.LookRing lays
	-- it, but colored directly).
	tag.look = {}
	for i, name in ipairs({ "base", "key", "light" }) do
		local t = tag:CreateTexture(nil, "BACKGROUND", nil, i)
		-- (Its light is added already: the base and the key shine over all three.)
		if name ~= "light" then self:Shiny(t, tag, "BACKGROUND", 3 + i) end
		t:SetPoint("CENTER")
		if name == "light" then t:SetBlendMode("ADD") end
		t:Hide()
		tag.look[name] = t
	end
	-- A lead's rank: its dragon round the ring.
	tag.dragon = tag:CreateTexture(nil, "BACKGROUND", nil, 7)
	tag.dragon:SetPoint("CENTER")
	tag.dragon:Hide()
	-- The ring's shadow is on the root at the lowest sublevel, so it never covers the name.
	plaque.shade = root:CreateTexture(nil, "BACKGROUND", nil, -8)
	plaque.shade:SetTexture(def.shade)
	plaque.shade:SetPoint("TOPLEFT", tag, "TOPLEFT", -def.shadow, def.shadow - 1)
	plaque.shade:SetPoint("BOTTOMRIGHT", tag, "BOTTOMRIGHT", def.shadow, -def.shadow - 1)
	plaque.shade:Hide()
	plaque.surface:SetShown(false)
	plaque.surface:Dress(1)
	self.plaque = plaque
	-- (A plate that shines already: what is made now shines with it.)
	local shine = self.shine or 0
	if shine > 0 then
		for _, t in ipairs(self.shines) do UI.SetShine(t, shine) end
	end
	self:PaintPlaque()
	local art = self.miniArt
	if art then
		plaque.rim:SetTexture(art.rim)
		plaque.rim:SetTextureSliceMargins(art.rimSlice, art.rimSlice, art.rimSlice, art.rimSlice)
		plaque.rim:SetVertexColor(1, 1, 1, 1)
	end
	return plaque
end

-- The plaque's theme colors and its edge's art, as the housing's (Paint); its edge in the color the housing's wears.
function Plate:PaintPlaque()
	local plaque = self.plaque
	local panel = UI.colors.panel
	plaque.fill:SetColorTexture(panel[1], panel[2], panel[3], 1)
	if self.edgeFile then
		plaque.strip:SetTexture(self.edgeFile)
		plaque.strip:SetTextureSliceMargins(self.edgeSlice, self.edgeSlice, self.edgeSlice, self.edgeSlice)
	end
	local c = self.ringColor
	if c then plaque.strip:SetVertexColor(c[1], c[2], c[3]) end
end

-- The housing's sky, and the plaque's: a look's own face in layers.
function Plate:Sky()
	local sky = self.sky
	if not sky then
		sky = FaceSet(self.house, 3)
		for _, t in ipairs(sky) do
			t:SetPoint("TOPLEFT", L.INSET, -L.INSET)
			t:SetPoint("BOTTOMRIGHT", -L.INSET, L.INSET)
		end
		self.sky = sky
	end
	return sky
end
function Plate:PlaqueSky()
	local plaque = self.plaque
	local sky = plaque.sky
	if not sky then
		sky = FaceSet(self.root, -4)
		for _, t in ipairs(sky) do OnPlaque(self, t, L.INSET) end
		plaque.sky = sky
	end
	return sky
end

-- A rank's seal (L.SEAL): on a frame over the housing, a ring with the level in it and the rank's dragon round it.
-- Its frame with every plate (its level is the housing's, read while the plate is no nameplate's); what stands in
-- it the first time a ranked unit has the plate (Plate:Sealed).
-- The face under the rim wears the level's color (UpdateSeal) and the level is white on it. Face, rim, dragon and
-- skull share one middle (UI.Concentric: snapped to the pixel grid each by its own size, they can stand a pixel
-- apart). The level has no drop shadow, which lifts the digits off the middle, and stands L.SEAL_NUDGE right of it,
-- where the game's centring would put it left.
function Plate:BuildSeal()
	local seal = CreateFrame("Frame", nil, self.root)
	seal:SetFrameLevel(self.house:GetFrameLevel() + 5)
	seal:SetSize(L.SEAL, L.SEAL)
	seal:SetPoint("CENTER", self.root, "LEFT", L.SEAL_AT, 0)
	seal:Hide()
	self.seal = seal
end
function Plate:Sealed()
	local seal = self.seal
	if not seal.ring then
		seal.face = seal:CreateTexture(nil, "BACKGROUND")
		seal.face:SetTexture(L.SEAL_FACE)
		seal.face:SetAllPoints()
		seal.ring = seal:CreateTexture(nil, "BORDER")
		seal.ring:SetTexture(L.SEAL_RIM)
		seal.ring:SetAllPoints()
		seal.dragon = seal:CreateTexture(nil, "ARTWORK")
		seal.dragon:SetPoint("CENTER")
		seal.level = Text(seal, L.SEAL_TEXT, "CENTER")
		seal.level:SetShadowOffset(0, 0)
		seal.level:SetShadowColor(0, 0, 0, 0)
		seal.level:SetTextColor(C.name[1], C.name[2], C.name[3])
		seal.level:SetPoint("CENTER", L.SEAL_NUDGE, 0)
		seal.skull = Glyph(seal, "skull", L.RANK)
		seal.skull:SetPoint("CENTER")
		UI.Concentric(seal.face, seal.ring, seal.dragon, seal.skull)
		local e = self.ringColor or Skin.colors.metal
		seal.ring:SetVertexColor(e[1], e[2], e[3])
	end
	return seal
end

-- The rank's dragon on a texture round a circle `size` across, at a nameplate's density; hides it for no rank.
local function Dragon(t, rank, size)
	local art = UI.RankDragon(rank, size, 1)
	t:SetShown(art ~= nil)
	if not art then return end
	t:SetTexture(art.file)
	t:SetSize(art.span, art.span)
end

-- Target mark pieces: four corner brackets and the three parts of the top line (db.target picks which).
function Plate:BuildTarget()
	local corner, line, over = L.CORNER, L.LINE, self.marks
	self.corners, self.line, self.pieces = {}, {}, {}
	for i = 1, 4 do   -- top left, top right, bottom left, bottom right
		local t = over:CreateTexture(nil, "ARTWORK")
		t:SetTexture(i <= 2 and corner.top or corner.bottom)
		if i % 2 == 0 then t:SetTexCoord(1, 0, 0, 1) end   -- right side: mirrored
		t:SetSize(corner.size, corner.size)
		t:Hide()
		self.corners[i] = t
		self.pieces[#self.pieces + 1] = t
	end
	for i, key in ipairs({ "left", "right", "mid" }) do
		local t = over:CreateTexture(nil, "ARTWORK")
		t:SetTexture(key == "mid" and line.mid or line.ending)
		if key == "right" then t:SetTexCoord(1, 0, 0, 1) end
		if key ~= "mid" then t:SetSize(line.w, line.h) end
		t:Hide()
		self.line[key] = t
		self.pieces[#self.pieces + 1] = t
	end
	self.line.mid:SetPoint("TOPLEFT", self.line.left, "TOPRIGHT")
	self.line.mid:SetPoint("BOTTOMRIGHT", self.line.right, "BOTTOMLEFT")
end

-- The mark (db.target): the same in every look.
local function MarkStyle()
	return ns.T.db.target
end

-- The keel and its combo pips. Each pip is four textures: well (always shown), fill and glow (lit by a
-- point), and an additive white flash. Colors come from Theme.Combo. Stack sets the keel's height.
function Plate:BuildKeel()
	local K, def = L.KEEL, L.COMBO
	local keel = CreateFrame("Frame", nil, self.house)
	keel:SetPoint("TOP", self.root, "BOTTOM", 0, 1)   -- overlaps the housing's edge by 1 so they share it (under the bar)
	keel:SetSize(K.width, K.foot)
	keel:Hide()
	keel.art = keel:CreateTexture(nil, "BACKGROUND")
	keel.art:SetAllPoints()
	keel.art:SetTexture(K.art)
	keel.art:SetTextureSliceMargins(K.slice, K.top, K.slice, K.slice)
	-- On the root, so the keel's shadow lies under the housing too.
	keel.shade = Sliced(self.root, "BACKGROUND", -8, L.SHADE, L.SHADE_SLICE)
	keel.shade:SetPoint("TOPLEFT", keel, "TOPLEFT", -L.SHADE_REACH, L.SHADE_REACH - 1)
	keel.shade:SetPoint("BOTTOMRIGHT", keel, "BOTTOMRIGHT", L.SHADE_REACH, -L.SHADE_REACH - 1)
	keel.shade:Hide()
	self.keel = keel

	local combo = CreateFrame("Frame", nil, keel)
	combo:SetPoint("TOPLEFT")
	combo:SetPoint("TOPRIGHT")
	combo:SetHeight(def.row)
	combo:Hide()
	combo.pips, combo.flashes, combo.gleam = {}, {}, 0
	local first = (K.width - (def.count * def.w + (def.count - 1) * def.gap)) / 2
	for i = 1, def.count do
		local r, g, b = Theme.Combo(i, def.count)
		local pip = {}
		pip.well = combo:CreateTexture(nil, "ARTWORK")
		pip.well:SetPoint("TOPLEFT", first + (i - 1) * (def.w + def.gap), -def.top)
		pip.well:SetSize(def.w, def.h)
		pip.well:SetTexture(def.well)
		pip.well:SetVertexColor(0.05 + r * 0.26, 0.05 + g * 0.26, 0.05 + b * 0.26)
		pip.glow = combo:CreateTexture(nil, "ARTWORK", nil, 1)
		pip.glow:SetPoint("TOPLEFT", pip.well, "TOPLEFT", -def.glow, def.glow)
		pip.glow:SetPoint("BOTTOMRIGHT", pip.well, "BOTTOMRIGHT", def.glow, -def.glow)
		pip.glow:SetTexture(def.light)
		pip.glow:SetBlendMode("ADD")
		pip.glow:SetVertexColor(r * 0.6, g * 0.6, b * 0.6)   -- additive blend: darker means fainter
		pip.glow:SetAlpha(0)
		pip.fill = combo:CreateTexture(nil, "ARTWORK", nil, 2)
		pip.fill:SetAllPoints(pip.well)
		pip.fill:SetTexture(def.pip)
		pip.fill:SetVertexColor(r, g, b)
		pip.fill:SetAlpha(0)
		pip.flash = combo:CreateTexture(nil, "OVERLAY")
		pip.flash:SetAllPoints(pip.well)
		pip.flash:SetTexture(def.pip)
		pip.flash:SetBlendMode("ADD")
		pip.flash:SetAlpha(0)
		combo.pips[i] = pip
	end
	self.combo = combo
end

-- Layout and theme colors

-- Applies every setting that affects size, position or font.
function Plate:Arrange()
	local db = ns.T.db
	local root, health = self.root, self.health
	local width = db.width
	self.width = width
	root:SetScale(db.scale)
	root:SetSize(width, L.HEALTH)
	health:SetWidth(L.Fill(width))
	self:LayMini()

	self.name:SetFontObject(P.Font(db.nameSize))
	self.nameSized = db.nameSize   -- (a pet's name is smaller: UpdateName)
	self.title:SetFontObject(P.Font(L.TITLE))
	self.healthText:SetFontObject(P.Font(L.TEXT))
	self.tag.count:SetFontObject(P.Font(L.TEXT))
	P.MeasureDigit()

	self.execute:ClearAllPoints()
	self.execute:SetPoint("TOP", health, "TOPLEFT", L.Fill(width) * L.EXECUTE, 0)
	self.execute:SetPoint("BOTTOM", health, "BOTTOMLEFT", L.Fill(width) * L.EXECUTE, 0)

	ns.Cast.Arrange(self)
	ns.Auras.Arrange(self)
	if ns.Doom then ns.Doom.Arrange(self) end
	self.shape = nil   -- laid out again whatever it shows
	self:ArrangeMode()
	ns.Cast.Paint(self)   -- db.casts may have changed
end

-- Sizes the keel to its rows: combo points, plus the cast row scaled by self.castGrow (Cast.lua). Hidden when empty.
-- Only what changed is told: every plate is stacked again on a target change and each frame of a cast's reveal.
function Plate:Stack()
	local keel = self.keel
	local up = self.combo.up == true
	local holding = (up or self.casting) and true or false
	local rows = up and L.COMBO.row or 0
	if self.casting then rows = rows + L.CAST * (self.castGrow or 1) end
	local shade = holding and self.mode == "full"
	local height = rows + L.KEEL.foot
	if holding ~= self.keelHolds then
		self.keelHolds = holding
		keel:SetShown(holding)
	end
	if shade ~= self.keelShades then
		self.keelShades = shade
		keel.shade:SetShown(shade)
	end
	if height ~= self.keelHeight then
		self.keelHeight = height
		keel:SetHeight(height)
	end
end

-- Whether a tag is drawn in its square form (info.flat): in the compartment of a full plate's housing, where it has
-- one. A ring and a plain name keep the round mark.
local function Boxed(self, info)
	return info.flat ~= nil and self.mode == "full"
end

-- Layout that depends on the mode and the tag: name, tag, plaque, raid mark, bounds, shadow, target marks.
-- What ArrangeMode lays out goes by these alone: a plate given a unit like the last one's (every plate a pull
-- brings) keeps its layout. Arrange forgets it.
local function Shape(self, info, db)
	local shape = self.shape or {}
	self.shape = shape
	-- (A tag's shape: its width, and which of its pieces it has. -1: no tag.)
	local wide = info and L.TagWidth(info.count) or -1
	local lead, back = info ~= nil and info.lead == true, info ~= nil and info.back ~= nil
	local face, over = info ~= nil and info.face ~= nil, info ~= nil and info.over ~= nil
	local rank, title = self.rank:IsShown() and true or false, self.title:IsShown() and true or false
	local same = shape.mode == self.mode and shape.wide == wide and shape.lead == lead and shape.back == back
		and shape.face == face and shape.over == over and shape.rank == rank and shape.title == title
		and shape.size == db.nameSize and shape.width == self.width
	shape.mode, shape.wide, shape.lead, shape.back, shape.face, shape.over = self.mode, wide, lead, back, face, over
	shape.rank, shape.title, shape.size, shape.width = rank, title, db.nameSize, self.width
	return same
end

-- The room the plate keeps among other nameplates, for the game's stacking. Steady: it goes by the settings and
-- by what the unit is, never by what shows this moment, so a cast, a debuff or a new target moves no plate.
-- A full plate's is all of it (db.room "all"): the row of debuffs over the name where the unit gets one (a plate
-- with no unit yet is taken for an enemy's, as most are) and the cast row under the housing; or its name and
-- bar alone ("bar"), as the click area. A name's is its click area. Told only when it changes.
function Plate:Berth()
	local db, pad, berth = ns.T.db, L.BERTH, self.berth
	local kept = self.berthAt
	if not kept then
		kept = {}
		self.berthAt = kept
	end
	if self.mode ~= "full" then
		if kept.full == false then return end
		kept.full = false
		berth:ClearAllPoints()
		berth:SetAllPoints(self.bounds)
		return
	end
	local top, foot = L.NAME_GAP + db.nameSize + pad.air, pad.foot
	if db.room == "all" then
		if (db.auras or db.control or db.steal) and not (self.unit ~= nil and self:IsFriend()) then
			top = top + L.AURA_RISE + L.AURA_H * (db.control and L.CONTROL or 1) * db.auraSize
		end
		if db.casts then foot = L.CAST + L.KEEL.foot - 1 + pad.air end
	end
	local right = self.reach or 0
	local more = (self.width + 2 * pad.side + right) * (pad.wide - 1) / 2
	local left = pad.side + more
	right = right + pad.side + more
	if kept.full and kept[1] == left and kept[2] == right and kept[3] == top and kept[4] == foot then return end
	kept.full, kept[1], kept[2], kept[3], kept[4] = true, left, right, top, foot
	berth:ClearAllPoints()
	berth:SetPoint("TOPLEFT", self.root, "TOPLEFT", -left, top)
	berth:SetPoint("BOTTOMRIGHT", self.root, "BOTTOMRIGHT", right, -foot)
end

function Plate:ArrangeMode()
	local db = ns.T.db
	local root, house = self.root, self.house
	local full = self.mode == "full"
	local info = self.tagInfo
	if Shape(self, info, db) then
		self:Berth()
		self:Stack()
		return
	end
	local plaqued = not full and info ~= nil and info.lead == true
	self.plaqued = plaqued
	if plaqued and not self.plaque then self:BuildPlaque() end
	house:SetShown(full)
	self.shade:SetShown(full or plaqued)
	self:ShowMini()

	-- Plaque height comes from the name's font size: the text's height can't be measured.
	local plaque, def = self.plaque, L.PLAQUE
	local tall = db.nameSize + def.rise
	local round = tall + def.round
	self.round = round
	self:LayPlaque()

	-- The tag is a cell on a full plate, the ring on a plaque, and only the seat icon on a plain name.
	local tag, seat = self.tag, self.seat
	local celled = info ~= nil and (full or plaqued)
	self.celled = celled
	-- (Square in a compartment, round in a ring: painted again where the mode changed which.)
	if info ~= nil and Boxed(self, info) ~= self.boxed then self:PaintTag() else self:TintTag() end
	tag:SetShown(celled)
	tag.groove:SetShown(not plaqued)
	tag.seam:SetShown(not plaqued)
	tag.count:SetShown(not plaqued)
	if tag.ring then tag.ring:SetShown(plaqued) end
	seat:SetShown(info ~= nil and not celled)
	self.seatBack:SetShown(info ~= nil and not celled and info.back ~= nil)
	self.seatFace:SetShown(info ~= nil and not celled and info.face ~= nil)
	self.seatOver:SetShown(info ~= nil and not celled and info.over ~= nil)
	local right = 0
	tag:ClearAllPoints()
	tag.art:ClearAllPoints()
	if plaqued then
		tag:SetPoint("CENTER", self.name, "LEFT", -(def.gap + round / 2), 0)
		tag:SetSize(round, round)
		tag.art:SetPoint("CENTER")
		local across = info.back and def.face or def.art   -- a two-texture icon fills the ring
		tag.art:SetSize(across, across)
		-- From the ring's middle to past the name's right end.
		OnPlaque(self, plaque.fill, 0)
		OnPlaque(self, plaque.strip, 0)
		OnPlaque(self, plaque.rim, 0)
		OnPlaque(self, plaque.surface, L.INSET)
		if plaque.sky then
			for _, t in ipairs(plaque.sky) do OnPlaque(self, t, L.INSET) end
		end
	else
		local art = L.TAG - 2 * L.INSET
		local width = L.TagWidth(info and info.count)
		-- The compartment: from the bar's end, the tag's width and the housing's edge past it.
		tag:SetPoint("TOPLEFT", root, "TOPRIGHT", 0, 0)
		tag:SetSize(width + L.CELL_GAP, L.HEALTH)
		tag.art:SetPoint("LEFT", L.TAG_GAP, 0)   -- a gap past the seam
		tag.art:SetSize(art, art)
		if info and full then right = width + L.CELL_GAP end
		-- Centered in the space right of the icon.
		tag.count:ClearAllPoints()
		tag.count:SetPoint("LEFT", tag.art, "RIGHT", L.TAG_GAP, L.COUNT_LIFT)
	end

	-- The housing runs on past the bar to hold a tag (its compartment); laid again only when that changes.
	if right ~= self.reach then
		self.reach = right
		house:ClearAllPoints()
		house:SetPoint("TOPLEFT", root, "TOPLEFT")
		house:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", right, 0)
		self:LayHousing()
	end

	local corner, line = L.CORNER, L.LINE
	local out = corner.gap + corner.t   -- a bracket's outer edge, measured from the plate

	self.name:ClearAllPoints()
	self.mark:ClearAllPoints()
	self.bounds:ClearAllPoints()
	if full then
		self.name:SetPoint("BOTTOM", root, "TOP", 0, L.NAME_GAP)
		-- The raid mark leaves room for a bracket, so it doesn't move when the unit is targeted.
		self.mark:SetPoint("LEFT", root, "RIGHT", right + out + L.MARK_GAP, 0)
		self.bounds:SetPoint("TOPLEFT", root, "TOPLEFT", -4, L.NAME_GAP + db.nameSize + 2)
		self.bounds:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 4 + right, -3)
	else
		-- Name only: the name sits low, raised by the title line when there is one.
		local over = plaqued and math.ceil(def.rise / 2) or 0   -- plaque overhang above and below the name
		-- The ring reaches lower than the strip, and a title wider than the name must clear it.
		local foot = plaqued and math.ceil((def.rise + def.round) / 2) or 0
		local rise = self.title:IsShown() and (L.TITLE + L.TITLE_GAP + foot) or 0
		self.name:SetPoint("BOTTOM", root, "BOTTOM", 0, L.NAME_LIFT - L.LIFT + rise)
		self.title:ClearAllPoints()
		self.title:SetPoint("TOP", self.name, "BOTTOM", 0, -L.TITLE_GAP - foot)
		self.mark:SetPoint("BOTTOM", self.name, "TOP", 0, 2 + over)
		-- The name's width can't be measured, so the click area is a fixed size: the name, and the line under it.
		self.bounds:SetPoint("BOTTOM", root, "BOTTOM", 0, L.NAME_LIFT - L.LIFT - 2)
		self.bounds:SetSize(math.min(self.width, 96), db.nameSize + 6 + rise)
	end

	local reach = L.SHADE_REACH
	self.shade:ClearAllPoints()
	if plaqued then
		-- Under the strip only; the ring has its own shadow.
		local rank = self.rank:IsShown() and L.RANK + 1 or 0
		self.shade:SetPoint("TOPLEFT", tag, "RIGHT", -reach, tall / 2 + reach - 1)
		self.shade:SetPoint("BOTTOMRIGHT", self.name, "RIGHT", def.reach + rank + reach, -tall / 2 - reach - 1)
	else
		self.shade:SetPoint("TOPLEFT", root, "TOPLEFT", -reach, reach - 1)
		self.shade:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", right + reach, -reach - 1)
	end

	local corners = self.corners
	for _, t in ipairs(corners) do t:ClearAllPoints() end
	corners[1]:SetPoint("TOPLEFT", root, "TOPLEFT", -out, out)
	corners[2]:SetPoint("TOPRIGHT", root, "TOPRIGHT", right + out, out)
	corners[3]:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", -out, -out)
	corners[4]:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", right + out, -out)
	self.line.left:ClearAllPoints()
	self.line.right:ClearAllPoints()
	self.line.left:SetPoint("BOTTOMLEFT", root, "TOPLEFT", line.inset, -1)
	self.line.right:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", right - line.inset, -1)

	self:Berth()
	self:Stack()
end

-- Sets every theme color; called again on SHY_THEME.
function Plate:Paint()
	-- The palette's tables changed in place: what was told last is told again.
	self.edgeColor, self.keelColor, self.markShown = nil, nil, nil
	local panel = UI.colors.panel
	self.bg:SetColorTexture(panel[1], panel[2], panel[3], 1)
	-- The look: its face over the fill (nameplates stay solid), its share of the shadow, and its border: its mini
	-- border where it has one as files (LayMini; the plate's own steel edge is then kept for a meaning's color), else
	-- its buttons' frame (drawn for small pieces; nothing on a nameplate may be measured, so no housing that lays
	-- itself out by its size).
	-- (The face is worn once: the core dresses every face again itself when the theme changes.)
	if not self.faced then
		self.faced = true
		self.surface:Dress(1)
	end
	local look = Theme.Look()
	local kind = UI.LOOK_KINDS[look]
	local file, slice = L.EDGE, L.EDGE_SLICE
	if look ~= "forged" and not (kind and kind.miniArt) then
		local edge = UI.KeyMake(look).edge
		file, slice = edge[1], math.min(edge[2], L.EDGE_MOST)
	end
	-- (Only for another edge: every plate is painted again at each change of the theme.)
	if file ~= self.edgeFile or slice ~= self.edgeSlice then
		self.edgeFile, self.edgeSlice = file, slice
		self.edge:SetTexture(file)
		self.edge:SetTextureSliceMargins(slice, slice, slice, slice)
	end
	if self.plaque then self:PaintPlaque() end
	self.shade:SetAlpha(UI.LookMaterial(look).shade)
	self:LayMini()
	-- The line under the name, in the ink it was last given (UpdateName): an NPC's title's until then.
	local ink = self.titleInk or UI.colors.head
	self.titleInk = ink
	self.title:SetTextColor(ink[1], ink[2], ink[3])
	-- (A friendly player's level is written into the name in that ink, and your pet's name is in your color: written
	-- again.)
	if (self.quiet or self.minion == "mine") and self.unit and self.read.Exists(self.unit) then self:UpdateName() end
	self:PaintTag()
	ns.Cast.Paint(self)
	ns.Auras.Paint(self)
	if ns.Doom then ns.Doom.Paint(self) end
	if self.unit then
		self:UpdateEdge()
		self:UpdateTarget()
	end
end

-- Tags (Shy.addons.Plates:Tag)

-- A tag's texture: its file and cell (PaintTag), and its color, lifted with the plate (TintTag).
local function Picture(art, file, coords)
	art:SetTexture(file)
	if coords then art:SetTexCoord(unpack(coords)) else art:SetTexCoord(0, 1, 0, 1) end
end
local function Tint(art, color, lift)
	art:SetVertexColor(Theme.Lift(color[1], color[2], color[3], lift))
end

-- The look's mini border, when it has one as files: each side's run round the bar (the band's outer part, its edge's
-- line on the bar's own edge, INSET in from the plate's: the plate's dark backing then lies under the bar alone),
-- running `join` on past each corner so two sides cross there; laid by the plate's width and HEALTH (never measured),
-- what is in your color tinted (set straight, as every color on a plate). The plate's own steel edge then shows only
-- in a meaning's color (a rank's, the mouse's: UpdateEdge). A look with none wears its buttons' edge (Paint).
-- One side's run (or what of it is in your color) round `box`.
local function LaySide(t, file, side, box, wide, tall, inset, join, out, share, run)
	t:ClearAllPoints()
	if side == "Top" then
		t:SetTexture(file, "REPEAT", "CLAMP")
		t:SetPoint("BOTTOMLEFT", box, "TOPLEFT", inset - join, -inset)
		t:SetSize(wide, out)
		t:SetTexCoord(0, wide / run, 0, share)
	elseif side == "Foot" then
		t:SetTexture(file, "REPEAT", "CLAMP")
		t:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset - join, inset)
		t:SetSize(wide, out)
		t:SetTexCoord(0, wide / run, 1 - share, 1)
	elseif side == "Left" then
		t:SetTexture(file, "CLAMP", "REPEAT")
		t:SetPoint("TOPRIGHT", box, "TOPLEFT", inset, join - inset)
		t:SetSize(out, tall)
		t:SetTexCoord(0, share, 0, tall / run)
	else
		t:SetTexture(file, "CLAMP", "REPEAT")
		t:SetPoint("TOPLEFT", box, "TOPRIGHT", -inset, join - inset)
		t:SetSize(out, tall)
		t:SetTexCoord(1 - share, 1, 0, tall / run)
	end
end

-- One mini border round `box` (a region), `wide` by `tall` (numbers: never measured): each side's run, its edge's
-- line `inset` in from the box's edge, running `join` on past each corner. (What is in your color: TintAccent.)
local function LaySides(self, set, art, box, wide, tall, inset)
	if not art.sides then return end
	Runs(self, set)
	local band, out, join = art.band, art.out, art.join or 0
	local share = out / band                                   -- the band's part outside the edge's line
	wide = wide - 2 * inset + 2 * join
	tall = tall - 2 * inset + 2 * join
	for _, side in ipairs(MINI_SIDES) do
		local file = art.sides[side]
		LaySide(set.sides[side], file, side, box, wide, tall, inset, join, out, share, art.run)
		LaySide(set.keys[side], file .. "Key", side, box, wide, tall, inset, join, out, share, art.run)
	end
end

-- A look's face (miniArt's `face`) on a set of layers `wide` by `tall` (numbers): each layer's tile from a place of the
-- plate's own (and the layer's own `at`), a layer with no tile stretched over it; what is in your color: TintAccent.
local function LayFace(set, face, wide, tall, seed)
	for i, t in ipairs(set) do
		local layer = face[i]
		if layer then
			local tile = layer.tile
			t:SetTexture(layer.file, tile and "REPEAT" or "CLAMP", tile and "REPEAT" or "CLAMP")
			t:SetBlendMode(layer.add and "ADD" or "BLEND")
			if tile then
				local at = layer.at
				local u, v = (seed[1] + (at and at[1] or 0)) % 1, (seed[2] + (at and at[2] or 0)) % 1
				t:SetTexCoord(u, u + wide / tile, v, v + tall / tile)
			else
				t:SetTexCoord(0, 1, 0, 1)
			end
			if not layer.accent then t:SetVertexColor(1, 1, 1, layer.alpha or 1) end
		end
	end
end

-- What of the look goes by the housing's width (its runs, its face's tiles), laid again when a tag's compartment
-- comes or goes; the rest of the look stays as LayMini dressed it.
function Plate:LayHousing()
	local art = self.miniArt
	if not art then return end
	local span = (self.width or ns.T.db.width) + (self.reach or 0)
	if art.face then LayFace(self:Sky(), art.face, span - 2 * L.INSET, L.HEALTH - 2 * L.INSET, self.seed) end
	LaySides(self, self.mini, art, self.house, span, L.HEALTH, L.INSET)
end

-- The look's rim on one of the plate's rims (the housing's, the plaque's).
local function WearRim(t, art)
	t:SetTexture(art.rim)
	t:SetTextureSliceMargins(art.rimSlice, art.rimSlice, art.rimSlice, art.rimSlice)
	t:SetVertexColor(1, 1, 1, 1)
end

function Plate:LayMini()
	local kind = UI.LOOK_KINDS[Theme.Look()]
	local art = kind and kind.miniArt and kind.miniArt()
	self.miniArt = art
	local plaque = self.plaque
	if art then
		if plaque then WearRim(plaque.rim, art) end
		if not art.sides then WearRim(self:LookRim(), art) end
	end
	-- A look that lays its own face wears it in place of its material's.
	local face = art and art.face
	local plain = face == nil
	if plain ~= self.plain then
		self.plain = plain
		self.surface:SetShown(plain)
	end
	if plaque then
		plaque.surface:SetShown(face == nil and self.plaqued == true)
		plaque.on = self.plaqued == true
	end
	local span = (self.width or ns.T.db.width) + (self.reach or 0)   -- the housing, a tag's compartment and all
	if face then LayFace(self:Sky(), face, span - 2 * L.INSET, L.HEALTH - 2 * L.INSET, self.seed) end
	if art then LaySides(self, self.mini, art, self.house, span, L.HEALTH, L.INSET) end
	self:ShowMini()
	local inset = art and L.INSET or 0
	if inset ~= self.bgInset then
		self.bgInset = inset
		self.bg:ClearAllPoints()
		self.bg:SetPoint("TOPLEFT", inset, -inset)
		self.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
	end
	self:LayPlaque()
	self:TintAccent()
	self.edgeColor = nil
	if self.unit then self:UpdateEdge() end
end

-- The plaque's mini border, laid by its length: the name's width, read off a font string of our own (a nameplate's
-- can't be measured), and the ring's and the end's room. A secret name has no width: then the rim alone.
local ruler
function Plate:LayPlaque()
	local plaque, art = self.plaque, self.miniArt
	if not plaque then return end   -- (never a lead's yet)
	plaque.wide = nil
	if self.plaqued and art then
		local def = L.PLAQUE
		local tall = ns.T.db.nameSize + def.rise
		if self.nameText then
			if not ruler then
				ruler = UIParent:CreateFontString(nil, "OVERLAY")
				ruler:Hide()
			end
			ruler:SetFontObject(P.Font(ns.T.db.nameSize))
			ruler:SetText(self.nameText)
			local rank = self.rank:IsShown() and L.RANK + 1 or 0
			plaque.wide = (self.round or tall + def.round) / 2 + def.gap + ruler:GetUnboundedStringWidth() + rank + def.reach
			LaySides(self, plaque.mini, art, plaque.fill, plaque.wide, tall, L.INSET)
		end
		-- (A secret name's length isn't known: its face is laid for a name of a usual length.)
		if art.face then
			LayFace(self:PlaqueSky(), art.face, (plaque.wide or def.usual) - 2 * L.INSET, tall - 2 * L.INSET, self.seed)
		end
	end
	self:ShowPlaque()
end

-- The plate's own steel edge: whole in a look with no mini border of its own; in one, only to carry a meaning (a
-- rank's gold or silver, your color on your target: a fine line along the look's border).
function Plate:ShowEdge()
	local shown = self.miniArt == nil or (self.rimColor ~= nil and self.rimColor ~= Skin.colors.metal)
	if shown ~= self.edgeShown then
		self.edgeShown = shown
		self.edge:SetShown(shown)
	end
end

-- The mini's pieces seen with the housing they frame (a name-only plate has none). Only what changed is told: every
-- plate is asked at each change of its mode and its tag.
function Plate:ShowMini()
	local mini, art = self.mini, self.miniArt
	local full = art ~= nil and self.mode == "full"
	local runs = full and art.sides ~= nil
	if runs ~= mini.runs then
		mini.runs = runs
		if runs then Runs(self, mini) end
		if mini.sides then
			for _, side in ipairs(MINI_SIDES) do
				mini.sides[side]:SetShown(runs)
				mini.keys[side]:SetShown(runs)
			end
		end
	end
	local rim = full and not runs
	if rim ~= mini.rim then
		mini.rim = rim
		local t = rim and self:LookRim() or self.lookRim
		if t then t:SetShown(rim) end
	end
	local face = art and art.face or nil
	if face ~= mini.face then
		mini.face = face
		local sky = face and self:Sky() or self.sky
		if sky then
			for i, t in ipairs(sky) do t:SetShown(face ~= nil and face[i] ~= nil) end
		end
	end
	self:ShowEdge()
end

-- The plaque's pieces, seen while the plate is a lead's name on it: in a look's mini border its rim, the plate's own
-- steel edge then only to carry a meaning (as ShowMini); the look's ring on the steel one unless that wears a rank's
-- color.
function Plate:ShowPlaque()
	local plaque, on = self.plaque, self.plaqued == true
	-- (None yet, or put away already: every plate asks at each change of its edge and its shape, and few are a lead's.)
	if not plaque or (not on and plaque.shows == false) then return end
	local came = on and plaque.shows ~= true
	plaque.shows = on
	local art = on and self.miniArt or nil
	local mini = art ~= nil
	local plain = self.rimColor == nil or self.rimColor == Skin.colors.metal
	plaque.fill:SetShown(on)
	if plaque.on ~= on then
		plaque.on = on
		plaque.surface:SetShown(on and not (self.miniArt and self.miniArt.face))
	end
	plaque.rim:SetShown(mini)
	local face = art and art.face or nil
	local sky = face and self:PlaqueSky() or plaque.sky
	if sky then
		for i, t in ipairs(sky) do t:SetShown(face ~= nil and face[i] ~= nil) end
	end
	local runs = mini and plaque.wide ~= nil and art.sides ~= nil
	local set = plaque.mini
	if set.sides then
		for _, side in ipairs(MINI_SIDES) do
			set.sides[side]:SetShown(runs)
			set.keys[side]:SetShown(runs)
		end
	end
	plaque.strip:SetShown(on and (not mini or not plain))
	plaque.shade:SetShown(on)
	self:DressRing(on and (plain or self.rimColor == ACTIVE))
	-- (What is in your color on it was left as it was while it was put away.)
	if came then self:TintAccent() end
end

-- The look's ring over the plaque's (UI.LookKind's `ring`), colored directly: its key in your color, its light a
-- lift of it. None in a look without one, or while the ring carries a meaning's color.
function Plate:DressRing(on)
	local tag = self.tag
	local parts = tag.look
	local kind = UI.LOOK_KINDS[Theme.Look()]
	-- (A nameplate is shown at about a pixel a unit: the look's ring drawn a texel a unit, where it has one.)
	local art = on and self.round and kind and kind.ring and kind.ring(self.round, 1) or nil
	local worn = art ~= nil
	if worn ~= tag.lookOn then
		tag.lookOn = worn
		for _, t in pairs(parts) do t:SetShown(worn) end
	end
	-- The plaque's own steel ring under a look's: dark glass, so the look's is the one ring that shows.
	tag.ringDark = worn
	self:TintRing()
	if not art then return end
	if tag.lookFile ~= art.file then
		tag.lookFile = art.file
		parts.base:SetTexture(art.file)
		parts.key:SetTexture(art.key)
		parts.light:SetTexture(art.light)
	end
	tag.lookGlow = art.glow or 0.5
	if tag.lookSpan ~= art.span then
		tag.lookSpan = art.span
		for _, t in pairs(parts) do t:SetSize(art.span, art.span) end
	end
	self:TintAccent()
end

-- The plaque's steel ring: the edge's color, or the dark of glass under a look's own ring (DressRing). A seal's ring
-- wears the edge's color too.
local RING_GLASS = { 0.10, 0.10, 0.12 }
function Plate:TintRing()
	local tag, e = self.tag, self.ringColor or Skin.colors.metal
	if tag.ring then
		local c = tag.ringDark and RING_GLASS or e
		tag.ring:SetVertexColor(c[1], c[2], c[3])
	end
	local ring = self.seal.ring
	if ring then ring:SetVertexColor(e[1], e[2], e[3]) end
end

-- What is in your color in the look's art (the mini border's keys, the ring's key and its light), lifted with the
-- plate (UpdateLift): the look's gems and leaves come up in color under the mouse and on your target. Only what the
-- look worn lays is told (a look with no border of its own: nothing), and the plaque's only while the plate is on
-- one: it is told when it comes (ShowPlaque).
function Plate:TintAccent()
	local art, tag = self.miniArt, self.tag
	if not (art or tag.lookOn) then return end
	local ar, ag, ab = Theme.Accent()
	local r, g, b = Theme.Lift(ar, ag, ab, self.lift)
	if art then
		local plaque = self.plaqued == true and self.plaque or nil
		if art.sides then
			local keys, theirs = self.mini.keys, plaque and plaque.mini.keys
			if keys then
				for _, t in pairs(keys) do t:SetVertexColor(r, g, b, 1) end
			end
			if theirs then
				for _, t in pairs(theirs) do t:SetVertexColor(r, g, b, 1) end
			end
		end
		local face = art.face
		if face then
			local sky, over = self.sky, plaque and plaque.sky or nil
			for i, layer in ipairs(face) do
				if layer.accent then
					local a = layer.alpha or 1
					if sky then sky[i]:SetVertexColor(r, g, b, a) end
					if over then over[i]:SetVertexColor(r, g, b, a) end
				end
			end
		end
	end
	if tag.lookOn then
		local parts, glow = tag.look, tag.lookGlow or 0.5
		parts.key:SetVertexColor(r, g, b, 1)
		parts.light:SetVertexColor(r + (1 - r) * glow, g + (1 - g) * glow, b + (1 - b) * glow, 1)
	end
end

-- A tag's textures besides its picture, and the seat's texture for each.
local LAYERED = { back = "seatBack", face = "seatFace", over = "seatOver" }

-- A tag's pictures; their colors with them (TintTag). In a full plate's compartment a tag with a square form
-- (info.flat) is that picture alone: nothing under it, nothing over it.
function Plate:PaintTag()
	local info = self.tagInfo
	if not info then return end
	local flat = Boxed(self, info) and info.flat or nil
	self.boxed = flat ~= nil
	if flat then
		Picture(self.tag.art, flat.texture or info.texture, flat.coords)
	else
		Picture(self.tag.art, info.texture, info.coords)
	end
	Picture(self.seat, info.texture, info.coords)
	for key, seat in pairs(LAYERED) do
		local layer = info[key]
		self.tag[key]:SetShown(layer ~= nil and not flat)
		if layer then
			Picture(self.tag[key], layer.texture or info.texture, layer.coords)
			Picture(self[seat], layer.texture or info.texture, layer.coords)
		end
	end
	self.tag.count:SetText(info.count and tostring(info.count) or "")
	self:TintTag()
end

-- A tag's colors, lifted with the plate: all that a change of the plate's state changes of it. Only the pictures
-- that show are told, the cell's or the seat's (self.celled: ArrangeMode, which tells them again as it changes).
function Plate:TintTag()
	local info = self.tagInfo
	if not info then return end
	local hot, lift = UI.colors.hot, self.lift   -- (hot: for want of a color of its own)
	local flat = self.boxed and info.flat or nil
	if flat then
		Tint(self.tag.art, flat.color or info.color or hot, lift)
		return
	end
	local celled = self.celled
	Tint(celled and self.tag.art or self.seat, info.color or hot, lift)
	for key, seat in pairs(LAYERED) do
		local layer = info[key]
		if layer then Tint(celled and self.tag[key] or self[seat], layer.color or hot, lift) end
	end
end

-- Whether two tags draw the same: the same pictures, cells, colors, count, lead and mark. Whoever tags the plates
-- gives every plate its tag again at each change of anything (a quest's count, a route built), a new list each time.
local function SameLayer(a, b)
	if a == b then return true end
	if not (a and b) or a.texture ~= b.texture then return false end
	local c, d = a.coords, b.coords
	if c ~= d and not (c and d and c[1] == d[1] and c[2] == d[2] and c[3] == d[3] and c[4] == d[4]) then return false end
	c, d = a.color, b.color
	return c == d or (c ~= nil and d ~= nil and c[1] == d[1] and c[2] == d[2] and c[3] == d[3])
end
local function SameTag(a, b)
	return a ~= nil and b ~= nil and a.count == b.count and (a.lead == true) == (b.lead == true) and a.mark == b.mark
		and SameLayer(a, b) and SameLayer(a.back, b.back) and SameLayer(a.face, b.face) and SameLayer(a.over, b.over)
		and SameLayer(a.flat, b.flat)
end

-- The parts of a tag that affect layout or which pieces show; a change here needs ArrangeMode.
local function TagShape(info)
	if not info then return "" end
	return L.TagWidth(info.count) .. (info.lead and " lead" or "") .. (info.back and " back" or "") .. (info.face and " face" or "")
		.. (info.over and " over" or "")
end

-- info: { texture =, coords = { l, r, t, b }, color = { r, g, b }, count = n }, or nil to clear. Optional:
-- back = { coords =, color =, texture = } drawn under the icon; face = the same, over back; over = the same,
-- drawn over the icon; flat = the same: the icon's square form, drawn alone in a full plate's compartment in place
-- of the icon and its layers (a round mark gives its picture without its disc);
-- lead = true makes the plate a name on its plaque until the unit is targeted or fights; mark = the raid
-- mark index the icon stands for, so that raid mark isn't shown twice.
function Plate:SetTag(info)
	local was = self.tagInfo
	self.tagInfo = info
	if was == info or SameTag(was, info) then return end
	self:PaintTag()
	local led = (was ~= nil and was.lead == true) ~= (info ~= nil and info.lead == true)
	local mode = self.mode
	if led and self.unit then self:UpdateTarget() end   -- a lead picks the mode; the marks follow it
	if self.mode == mode and TagShape(was) ~= TagShape(info) then
		self:ArrangeMode()
		if led and self.unit then self:UpdateName() end   -- a plaque's name has no level, and a title
	end
	if self.unit and ((was and was.mark) or (info and info.mark)) then self:UpdateMark() end
end

-- Showing a unit

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED",
	"UNIT_FACTION", "UNIT_FLAGS", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_TARGET",
}
local HANDLERS = {
	UNIT_HEALTH = "UpdateHealth", UNIT_MAXHEALTH = "UpdateHealth",
	UNIT_NAME_UPDATE = "UpdateName", UNIT_LEVEL = "UpdateName",
	UNIT_THREAT_LIST_UPDATE = "UpdateColor", UNIT_THREAT_SITUATION_UPDATE = "UpdateColor", UNIT_TARGET = "UpdateColor",
}

function Plate:SetUnit(unit)
	self.unit = unit
	self.guid = self.read.Guid(unit)
	self.fresh = true   -- first update: no smoothing, no flashes
	local events = self.events
	events:UnregisterAllEvents()
	if self.read == U then
		for _, event in ipairs(UNIT_EVENTS) do events:RegisterUnitEvent(event, unit) end
	end
	self.locked, self.lock = nil, nil
	self.tone, self.glide, self.hold, self.margin = nil, nil, nil, nil
	self.guild, self.guildLine, self.guildKin = nil, nil, nil
	self.minion, self.kin = nil, nil
	self.health.light:Hide()
	self.combo.points = nil
	wipe(self.combo.flashes)
	self:SetTargetMark(false)
	self:ArrangeMode()   -- clears the last unit's tag layout
	self.root:Show()
	ns.Cast.Attach(self)
	self:Update()
	self.fresh = false
end

function Plate:Clear()
	self.unit = nil
	self.guid = nil
	self.tagInfo = nil
	self.aimed, self.hovered = nil, nil
	P.aimed[self], P.hovered[self] = nil, nil
	self.locked, self.lock = nil, nil
	self.tone, self.glide, self.hold, self.margin = nil, nil, nil, nil
	self.guild, self.guildLine, self.guildKin = nil, nil, nil
	self.minion, self.kin = nil, nil
	self.seal.said = nil   -- (the next unit's level is written whatever this one's was)
	self.events:UnregisterAllEvents()
	self.lights:SetScript("OnUpdate", nil)
	ns.Cast.Detach(self)
	ns.Auras.Detach(self)
	if ns.Doom then ns.Doom.Clear(self) end
	self.root:Hide()
end

function Plate:OnEvent(event)
	local unit = self.unit
	if not unit or not self.read.Exists(unit) then return end
	local handler = HANDLERS[event]
	if event == "UNIT_NAME_UPDATE" then self.kin = nil end   -- (a pet's owner the game couldn't name yet: asked again)
	if handler then
		self[handler](self)
	elseif event == "UNIT_CLASSIFICATION_CHANGED" then
		self:UpdateName()
		self:UpdateEdge()
	else
		self:UpdateStance()   -- UNIT_FACTION, UNIT_FLAGS
	end
end

-- A fight begun or ended, tapped, attackable, another reaction: these fire for every mob a pull wakes. What
-- they decide is the mode, the name, the bar and its color, and what follows the mode; not the unit's rank,
-- raid mark, hover, or whether it is your target or focus.
function Plate:UpdateStance()
	local mode = self.mode
	self:UpdateMode()
	self:UpdateName()
	self:UpdateHealth()
	self:UpdateColor()
	if self.mode ~= mode then self:UpdateTarget() end   -- the target's mark needs a housing
	ns.Auras.Attach(self)
	self:Berth()   -- a friend has no row of debuffs to keep room for
end

function Plate:Update()
	local unit = self.unit
	if not unit or not self.read.Exists(unit) then return end
	self:UpdateMode()
	self:UpdateName()
	self:UpdateEdge()
	self:UpdateHealth()
	self:UpdateColor()
	self:UpdateMark()
	self:UpdateTarget()
	self:UpdateHover()
	ns.Auras.Attach(self)
end

function Plate:IsFriend()
	local R, unit = self.read, self.unit
	return R.Stance(unit) == "friendly" and not R.CanAttack(unit)
end

-- Picks "full" or "name". A secret IsTarget keeps the plate full.
function Plate:UpdateMode()
	local R, unit, db = self.read, self.unit, ns.T.db
	local mode = "full"
	local isTarget, secret = R.IsTarget(unit)
	if not secret and not isTarget then
		local info = self.tagInfo
		if info and info.lead and not R.Fighting(unit) then
			-- The one being headed for is a name on its plaque, whatever it is to you.
			mode = "name"
		elseif self:IsFriend() then
			if db.friendNames then mode = "name" end
		elseif db.calm and not R.Fighting(unit) then
			mode = "name"
		end
	end
	if mode ~= self.mode then
		self.mode = mode
		if mode == "name" then ns.Cast.Stop(self) else ns.Cast.Read(self) end
		self:ArrangeMode()
		self:UpdateName()   -- name color and position depend on the mode
		ns.Auras.Attach(self)
		if ns.Doom then ns.Doom.Update(self) end
	end
end

local function Hex(r, g, b)
	return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- A level's colored pattern ("|cff..14|r %s"). By difficulty for what you can attack, kept until your own level
-- moves its color; `quiet`, for a player you can't, in the ink of an NPC's title, kept until the theme changes it.
local LEVELS = { hard = {}, at = nil, quiet = {}, ink = {} }
local function LevelPattern(R, level, quiet)
	if quiet then
		local ink, was = UI.colors.head, LEVELS.ink
		if ink[1] ~= was[1] or ink[2] ~= was[2] or ink[3] ~= was[3] then
			LEVELS.quiet = {}
			was[1], was[2], was[3] = ink[1], ink[2], ink[3]
		end
		local pattern = LEVELS.quiet[level]
		if not pattern then
			pattern = "|cff" .. Hex(ink[1], ink[2], ink[3]) .. level .. "|r %s"
			LEVELS.quiet[level] = pattern
		end
		return pattern
	end
	local mine = UnitLevel("player")
	if mine ~= LEVELS.at then
		LEVELS.hard, LEVELS.at = {}, mine
	end
	local pattern = LEVELS.hard[level]
	if not pattern then
		pattern = "|cff" .. Hex(R.LevelColor(level)) .. level .. "|r %s"
		LEVELS.hard[level] = pattern
	end
	return pattern
end

-- A player's guild as the line under their name says it: `"<Guild>", yours`. A secret answer is never read: the
-- last plain one this unit gave stands, so the line doesn't come and go with a fight.
function Plate:Guild()
	local guild, yours, secret = self.read.Guild(self.unit)
	if secret then return self.guildLine, self.guildKin end
	if guild ~= self.guild then
		self.guild = guild
		self.guildLine = guild and ("<" .. guild .. ">") or nil
	end
	self.guildKin = yours
	return self.guildLine, yours
end

-- Whose a minion is, as the line under its name says it. Asked once a unit (the game builds a tooltip's lines to
-- answer), and again when the unit's name is told anew; a secret answer is never read, and is asked again.
function Plate:Kin()
	if self.kin == nil then
		local line, secret = self.read.Owner(self.unit)
		if secret then return nil end
		self.kin = line or false
	end
	return self.kin or nil
end

function Plate:UpdateName()
	local R, unit, db = self.read, self.unit, ns.T.db
	local name = R.Name(unit)
	local full = self.mode == "full"
	local attackable = R.CanAttack(unit)
	local player = R.IsPlayer(unit)
	local rank = R.Rank(unit)
	-- A player's pet, totem or guardian: "mine", "theirs", or nil for anything else.
	local minion = not player and R.Minion(unit) or nil
	self.minion = minion
	-- As a name it is a size smaller than a player's: it is someone's, and quieter than they are. (Not on a plaque,
	-- whose length goes by the name's size, nor where the game draws a minion's nameplate smaller already.)
	local size = db.nameSize
	if minion and not full and not self.plaqued and not R.Simplified() then
		size = math.max(math.min(size, L.PET.least), size - L.PET.step)
	end
	if size ~= self.nameSized then
		self.nameSized = size
		self.name:SetFontObject(P.Font(size))
	end
	-- A ranked unit's full plate wears its seal: its level in it, its dragon round it.
	local sealed = full and rank ~= nil
	-- A plaque says who, and what they do: the level comes with the plate. A player's level is said whoever
	-- they are to you: a friend's quietly, an enemy's by difficulty as a creature's.
	local level = (attackable or player) and db.level and not self.plaqued and not sealed and R.Level(unit) or nil
	local quiet = (level and level > 0 and not attackable) and true or false
	self.quiet = quiet or nil

	if level and level > 0 then
		-- The level goes into the format pattern because the name may be secret (no concatenation).
		self.name:SetFormattedText(LevelPattern(R, level, quiet), name)
	else
		self.name:SetText(name)
	end
	-- (Only what you can attack has a level the game may hide: no skull after a friend's name.)
	if not attackable then level = nil end
	-- The plain name, for the plaque's length (LayPlaque); a secret one is never read.
	local text = (not Secret(name) and type(name) == "string") and name or nil
	if text ~= self.nameText then
		self.nameText = text
		if self.plaqued then self:LayPlaque() end
	end

	-- White above a health bar; without a bar the name takes the color the bar would have had. A player you can
	-- attack is named in the enemy's red whatever else is set: who they are is in their bar's class color, that they
	-- are an enemy is in their name, at a glance.
	local r, g, b = C.name[1], C.name[2], C.name[3]
	if R.Tapped(unit) then
		r, g, b = C.tapped[1], C.tapped[2], C.tapped[3]
	elseif R.IsPlayer(unit) and attackable then
		r, g, b = C.hostile[1], C.hostile[2], C.hostile[3]
	elseif R.IsPlayer(unit) and db.classColors then
		local cr, cg, cb = R.ClassColor(unit)
		if Secret(cr) or cr then r, g, b = cr, cg, cb end
	elseif not full then
		-- Your own pet in your color; a friend's in a quieter green than the friend's own; anything else by what it
		-- is to you.
		local stance = R.Stance(unit)
		local c = C[stance]
		if minion == "mine" then
			c = UI.colors.hot
		elseif minion and stance == "friendly" then
			c = C.pet
		end
		r, g, b = c[1], c[2], c[3]
	end
	self.name:SetTextColor(r, g, b)

	-- Their PvP flag's crest.
	local crest = R.Crest and R.Crest(unit) or nil
	if crest ~= self.crestShown then
		self.crestShown = crest
		UI.Crest(self.crest, crest, L.CREST, 1)
	end

	self:UpdateSeal(sealed and rank or nil)
	local leadRank = self.plaqued and rank or nil
	if leadRank ~= self.leadRank or (leadRank and self.round ~= self.leadRound) then
		self.leadRank, self.leadRound = leadRank, self.round
		-- (A lead's rank is a plaque's: no plaque yet, no dragon to put away.)
		local dragon = self.tag.dragon
		if dragon then Dragon(dragon, leadRank, self.round or L.TAG) end
	end

	-- Rank glyph: skull for a boss or hidden level, wings for an elite, star for a rare; none where a dragon says it
	-- (a seal, a lead's ring).
	local glyph, color
	if sealed or (self.plaqued and rank ~= nil) then
		glyph = nil
	elseif rank == "boss" or (level and level == 0) then
		glyph, color = "skull", C.unknown
	elseif rank == "elite" then
		glyph, color = "wings", UI.colors.alert
	elseif rank == "rareelite" then
		glyph, color = "wings", C.silver
	elseif rank == "rare" then
		glyph, color = "star", C.silver
	end
	local ranked = self.rank:IsShown()
	self.rank:SetShown(glyph ~= nil)
	if glyph then
		self.rank:SetTexCoord(L.GlyphCoords(glyph))
		self.rank:SetVertexColor(color[1], color[2], color[3])
	end

	-- The line under a name: a player's guild (green, in your color when it is yours too), what an NPC does, whose
	-- a pet is (yours needs no saying).
	local title, ink = nil, UI.colors.head
	if not full then
		if player then
			if db.guild then
				local yours
				title, yours = self:Guild()
				ink = yours and UI.colors.hot or C.guild
			end
		elseif minion then
			-- (Quieter than the name over it: a pet's name is soft already, and an NPC's title's ink would outshine it.)
			if db.titles and minion == "theirs" and (self.plaqued or self:IsFriend()) then title, ink = self:Kin(), C.kin end
		elseif db.titles and (self.plaqued or self:IsFriend()) then
			title = R.Title(unit, name)
		end
	end
	local had = self.title:IsShown()
	self.title:SetShown(title ~= nil)
	if title and title ~= self.titleText then
		self.titleText = title
		self.title:SetText(title)
	end
	if title and ink ~= self.titleInk then
		self.titleInk = ink
		self.title:SetTextColor(ink[1], ink[2], ink[3])
	end
	-- A title moves the name; a rank glyph widens a plaque.
	if not full and (had ~= (title ~= nil) or (self.plaqued and ranked ~= (glyph ~= nil))) then self:ArrangeMode() end
end

-- A seal's face for a level's color: a deep shade of it that white digits read on. Kept by color: the game has a
-- handful.
LEVELS.faces = {}
function LEVELS.Face(r, g, b)
	local key = math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
	local face = LEVELS.faces[key]
	if not face then
		face = { Theme.Deep(r, g, b, L.SEAL_DEEP) }
		LEVELS.faces[key] = face
	end
	return face
end

-- The seal for a rank (nil: none): the level in it (a skull for one the game hides), its dragon round it, its face
-- in the level's color.
function Plate:UpdateSeal(rank)
	local seal = self.seal
	if rank ~= self.sealRank then
		self.sealRank = rank
		seal:SetShown(rank ~= nil)
		if rank then self:Sealed() end
		if seal.dragon then Dragon(seal.dragon, rank, L.SEAL) end
		-- (How far its dragon reaches past the seal's middle, for the room the plate takes: Room.)
		local art = UI.RankDragon(rank, L.SEAL, 1)
		self.sealReach = rank and (art and art.span / 2 or L.SEAL / 2) or nil
		seal.said = nil
	end
	if not rank then return end
	-- (The level again only when it is another: the name is told again at every change of the unit's stance.)
	local level = self.read.Level(self.unit)
	local said = (not level or level <= 0) and 0 or level
	if said == seal.said then return end
	seal.said = said
	local hidden = said == 0
	seal.skull:SetShown(hidden)
	seal.level:SetShown(not hidden)
	local face
	if hidden then
		face = LEVELS.Face(C.unknown[1], C.unknown[2], C.unknown[3])
	else
		seal.level:SetText(level)
		face = LEVELS.Face(self.read.LevelColor(level))
	end
	seal.face:SetVertexColor(face[1], face[2], face[3])
end

-- Edge color for the housing, tag, plaque and keel: your color while the plate is marked (gold for your focus), else
-- gold for elite or boss, silver for rare; lifted with the plate.
function Plate:UpdateEdge()
	local rank = self.read.Rank(self.unit)
	local color = Skin.colors.metal
	if self.marking then
		color = ACTIVE
	elseif rank == "elite" or rank == "boss" then
		color = UI.colors.alert
	elseif rank == "rare" or rank == "rareelite" then
		color = C.silver
	end
	self.rimColor = color
	if color ~= self.edgeColor then
		self.edgeColor = color
		-- Plain steel is the look's rim (ink in a comic, the dark of a screen); a rank's stays.
		local r, g, b
		if color == ACTIVE then
			if self.marking == "focus" then
				local gold = UI.colors.alert
				r, g, b = gold[1], gold[2], gold[3]
			else
				r, g, b = MarkColor()
			end
		else
			r, g, b = color[1], color[2], color[3]
		end
		if color == Skin.colors.metal then
			local rr, rg, rb = UI.LookRim()
			r, g, b = r * rr, g * rg, b * rb
		end
		r, g, b = Theme.Lift(r, g, b, self.lift)
		self.edge:SetVertexColor(r, g, b)
		self.tag.seam:SetVertexColor(r, g, b, 0.3)
		-- In a look's mini border the plate's own edge shows only to carry a meaning (a rank's gold or silver, your
		-- color on your target: a fine line along the look's border): plain, the look's rim is its edge.
		self:ShowEdge()
		local ring = self.ringColor or {}
		self.ringColor = ring
		ring[1], ring[2], ring[3] = r, g, b
		self:TintRing()
		if self.plaque then self.plaque.strip:SetVertexColor(r, g, b) end
		self:ShowPlaque()
	end
	self:PaintKeel()
end

function Plate:UpdateHealth()
	local R, unit, db = self.read, self.unit, ns.T.db
	R.FillHealth(self.health, unit, not self.fresh and SMOOTH or nil)
	self:WriteHealth(self.healthText)
	local execute = (db.execute and L.FINISHERS[playerClass] == true and R.CanAttack(unit)) and true or false
	if execute ~= self.executeShown then
		self.executeShown = execute
		self.execute:SetShown(execute)
	end
	if ns.Doom then ns.Doom.Update(self) end
end

-- Writes the health text per db.health.
function Plate:WriteHealth(text)
	local R, unit, mode = self.read, self.unit, ns.T.db.health
	-- Every health event: the shown state and a plain alpha are told only when they change.
	local shown = mode ~= "off"
	if text.shyShown ~= shown then
		text.shyShown = shown
		text:SetShown(shown)
	end
	if mode == "value" then
		text:SetText(R.HealthValue(unit))
		if text.shyAlpha ~= 1 then
			text.shyAlpha = 1
			text:SetAlpha(1)
		end
	elseif mode ~= "off" then
		text:SetFormattedText("%.0f%%", R.HealthThrough(unit))
		-- "hurt": the curve gives alpha 0 at full health. The result may be secret: pass it on, never test it.
		if mode == "hurt" then
			text.shyAlpha = nil
			text:SetAlpha(R.HealthThrough(unit, ns.Curves().hurt))
		elseif text.shyAlpha ~= 1 then
			text.shyAlpha = 1
			text:SetAlpha(1)
		end
	end
end

-- The bar's color. A plain color is kept (self.tone) so the next one is glided to; a secret one (a class
-- color, a threat the game answers only as a boolean) goes straight to the setters.
function Plate:SetTone(r, g, b)
	if Secret(r) or Secret(g) or Secret(b) then
		self.tone = nil
		self.health:SetStatusBarColor(r, g, b)
		self.health.wash:SetColorTexture(r, g, b, 0.10)
		return
	end
	self.tone = self.tone or {}
	self.tone[1], self.tone[2], self.tone[3] = r, g, b
	r, g, b = Theme.Lift(r, g, b, self.lift)
	self.health:SetStatusBarColor(r, g, b)
	self.health.wash:SetColorTexture(r, g, b, 0.10)
end

local function Close(a, b)
	return math.abs(a - b) < 1 / 255
end

function Plate:UpdateColor()
	local r, g, b, margin = U.Color(self.unit, ns.T.db, self.read)
	local was = self.margin
	self.margin = margin
	local tone = self.tone
	if self.fresh or not tone or Secret(r) or Secret(g) or Secret(b) then
		self.glide = nil
		self:SetTone(r, g, b)
		return
	end
	if Close(tone[1], r) and Close(tone[2], g) and Close(tone[3], b) then return end
	-- Threat moves along its run; anything else (a tap, a fight begun) is a change of state and jumps.
	if type(margin) ~= "number" or type(was) ~= "number" then
		self.glide = nil
		self:SetTone(r, g, b)
		return
	end
	self.glide = { tone[1], tone[2], tone[3], r, g, b, at = 0 }
	-- Threat becoming secure is good news: the bar lights once.
	if margin == 1 and was < 1 then self.hold = HOLD end
	self:Animate()
end

function Plate:UpdateMark()
	local index, there = self.read.RaidMark(self.unit)
	-- Skip the raid mark when the tag already shows it.
	local info = self.tagInfo
	if there and info and info.mark and not Secret(index) and index == info.mark then there = false end
	self.marked = there == true
	self.mark:SetShown(there)
	if there then SetRaidTargetIconTexture(self.mark, index) end
end

-- For addons that draw beside a plate (ShyHits). Returns `full, left, right, top, half, lift, tall`:
-- whether there is a housing; how far the plate's pieces reach past the housing's left end, right end
-- and top (for a name-only plate, the name's top relative to the housing's position; may be negative);
-- then the housing's half width, its height above the nameplate's bottom, and its height.
-- In UI units at db.scale. Computed, not measured, so the game's distance scaling isn't included.
function Plate:Room()
	local db = ns.T.db
	local s, full = db.scale, self.mode == "full"
	local out = L.CORNER.gap + L.CORNER.t
	local right = out
	if self.tagInfo then right = right + L.TagWidth(self.tagInfo.count) + L.CELL_GAP end
	if self.marked then right = right + L.MARK_GAP + L.MARK end
	local top
	if full then
		top = L.NAME_GAP + db.nameSize + 2
		if db.auras or db.control or db.steal then top = top + L.AURA_RISE + L.AURA_H * L.CONTROL * db.auraSize end
	else
		top = L.NAME_LIFT - L.LIFT + db.nameSize + 2 - L.HEALTH
		-- (The line under a name raises it: over a plaque's ring by the ring's foot as well. ArrangeMode.)
		if self.title:IsShown() then
			top = top + L.TITLE + L.TITLE_GAP
			if self.plaqued then top = top + math.ceil((L.PLAQUE.rise + L.PLAQUE.round) / 2) end
		end
		if self.plaqued then top = top + math.ceil(L.PLAQUE.rise / 2) end
		if self.marked then top = top + L.MARK + 2 end
	end
	-- (A seal's dragon reaches past the housing's left end.)
	local left = out
	if self.sealReach then left = math.max(left, -L.SEAL_AT + self.sealReach) end
	return full, left * s, right * s, top * s, self.width * s / 2, L.LIFT * s, L.HEALTH * s
end

-- Target

-- Every plate is told on every target change: one already showing what it is asked to show is left alone.
-- (A flash in progress ends on the mark's own color; a mark whose alpha the game picked is always told again.)
function Plate:SetTargetMark(shown, r, g, b)
	local style = MarkStyle()
	shown = shown and true or false
	if shown == self.markShown and (not shown or (style == self.markStyle and r == self.markR and g == self.markG and b == self.markB)) then
		return
	end
	self.markShown, self.markStyle, self.markR, self.markG, self.markB = shown, style, r, g, b
	local corners, line = shown and style == "corners", shown and style == "line"
	for _, t in ipairs(self.corners) do t:SetShown(corners) end
	for _, t in pairs(self.line) do t:SetShown(line) end
	if shown then
		for _, t in ipairs(self.pieces) do
			t:SetVertexColor(r, g, b)
			t:SetAlpha(1)
		end
	end
end

-- Marks the target (accent) or the focus (gold), and dims the others.
function Plate:UpdateTarget()
	local R, unit, db = self.read, self.unit, ns.T.db
	self:UpdateMode()   -- the target is never name only
	local isTarget, secret = R.IsTarget(unit)
	local dim = R.Exists("target") and db.dim or 1
	local full = self.mode == "full"   -- has a housing to mark
	local was = self.locked

	if secret then
		-- IsTarget is secret: show the mark on every plate and let SetAlphaFromBoolean pick the target's.
		self.aimed = true   -- not known: the next change of target or focus tells it again (Driver.lua)
		P.aimed[self] = true
		self.locked = nil
		self.marking = nil   -- (no color can be picked by a secret: the alpha alone tells it)
		self:UpdateLift()
		self:SetTargetMark(full, MarkColor())
		for _, t in ipairs(self.pieces) do t:SetAlphaFromBoolean(isTarget, 1, 0) end
		self.markShown = nil   -- the pieces' alpha is the game's now: the next mark is told whole
		local alphas = self.alphas or {}
		self.alphas = alphas
		alphas[1], alphas[2], alphas.secret = dim, isTarget, true
		self:Fade()
		self:UpdateCombo(false)
		return
	end

	local isFocus, focusSecret = R.IsFocus(unit)
	local focused = not focusSecret and isFocus and not isTarget
	-- Your target, your focus, or not known: the plates a change of target or focus can change (Driver.lua).
	self.aimed = (isTarget or focusSecret or isFocus) and true or nil
	P.aimed[self] = self.aimed
	self.locked = isTarget or nil
	if not isTarget then self.lock = nil end   -- cancel a flash in progress
	self.marking = MarkStyle() == "lift" and (isTarget and "target" or focused and "focus") or nil
	self:UpdateLift()
	if focused then
		local gold = UI.colors.alert
		self:SetTargetMark(full, gold[1], gold[2], gold[3])
	else
		self:SetTargetMark(full and isTarget, MarkColor())
	end
	local alphas = self.alphas or {}
	self.alphas = alphas
	alphas[1], alphas[2], alphas.secret = isTarget and 1 or dim, nil, nil
	self:Fade()
	self:UpdateCombo(isTarget)
	-- Newly targeted: the mark flashes white, then settles to the accent.
	if isTarget and not was and not self.fresh and full and db.target ~= "none" then
		self.lock = LOCK
		self:Animate()
	end
end

-- A target came or went and this plate is neither (Driver.lua): only its alpha changes. One whose last answer
-- was secret, or never given, is told whole.
function Plate:Redim(dim)
	local alphas = self.alphas
	if not alphas or alphas.secret or self.aimed then
		self:UpdateTarget()
		return
	end
	alphas[1] = dim
	self:Fade()
end

-- The plate's alpha: dimmed beside a target, and quieted while a dialog has the screen (ns.quiet, 0 to 1).
-- alphas = { alpha, isTarget }: a target known only as a secret (isTarget given) picks full or alpha itself.
function Plate:Fade()
	local shade, quiet = self.alphas, ns.quiet or 1
	if not shade then return end
	if shade.secret then
		self.faded = nil
		self.root:SetAlphaFromBoolean(shade[2], quiet, shade[1] * quiet)
	else
		local alpha = shade[1] * quiet
		if alpha == self.faded then return end
		self.faded = alpha
		self.root:SetAlpha(alpha)
	end
end

-- Mouseover highlight on the bar and edge. Returns whether the unit is hovered.
function Plate:UpdateHover()
	local over, secret = self.read.IsMouseover(self.unit)
	local hovered = not secret and over
	P.hovered[self] = hovered or nil
	if hovered == self.hovered then return hovered end
	self.hovered = hovered
	self:UpdateLift()
	return hovered
end

-- A texture of the plate's art that shines with its state (UI.Shine), its shine made in `layer` at `sub`.
function Plate:Shiny(texture, owner, layer, sub)
	UI.Shine(texture, owner, layer, sub)
	self.shines[#self.shines + 1] = texture
	return texture
end

-- The plate's state (see HOVER_LIFT): marked, under the mouse, or at rest. Every color that is ours is told again; a
-- secret one (a class color) is left as it is.
function Plate:UpdateLift()
	local k, shine = 0, 0
	if self.marking then
		k, shine = ACTIVE_LIFT, ACTIVE_SHINE
	elseif self.hovered then
		k, shine = HOVER_LIFT, HOVER_SHINE
	end
	local edge = self.marking ~= self.edgeMarked
	local lifted, shone = k ~= (self.lift or 0), shine ~= (self.shine or 0)
	if not (lifted or shone or edge) then return end
	self.lift, self.shine, self.edgeMarked = k, shine, self.marking
	if shone then
		for _, t in ipairs(self.shines) do UI.SetShine(t, shine) end
	end
	self.edgeColor = nil
	if self.unit then self:UpdateEdge() end
	-- (Its colors only where they are lifted another way: a target under the mouse keeps the target's.)
	if lifted then
		local tone = self.tone
		if tone then self:SetTone(tone[1], tone[2], tone[3]) end
		self:TintAccent()
		self:TintTag()
	end
end

-- Combo points

-- The keel takes the housing's edge color, or gold at full combo points. A palette table changes in place
-- with the theme, so Paint forgets the one told last.
function Plate:PaintKeel()
	local color = self.rimColor or Skin.colors.metal
	if self.combo.points == L.COMBO.count or (color == ACTIVE and self.marking == "focus") then
		color = UI.colors.alert
	end
	local r, g, b
	if color == ACTIVE then r, g, b = MarkColor() else r, g, b = color[1], color[2], color[3] end
	r, g, b = Theme.Lift(r, g, b, self.lift)
	-- (Told only in another color: it is asked at every combo point and every change of the edge.)
	local was = self.keelColor
	if was and was[1] == r and was[2] == g and was[3] == b then return end
	was = was or {}
	self.keelColor = was
	was[1], was[2], was[3] = r, g, b
	self.keel.art:SetVertexColor(r, g, b)
end

-- Shown on the target while there are points, or empty when R.BuildsCombo. A secret count lights the
-- pips through a curve (R.ComboLit) and skips the flashes.
function Plate:UpdateCombo(isTarget)
	local R, combo, def = self.read, self.combo, L.COMBO
	if isTarget == nil then
		local secret
		isTarget, secret = R.IsTarget(self.unit)
		if secret then isTarget = false end
	end
	if not isTarget or not ns.T.db.combo or self.mode ~= "full" then
		if combo.up ~= false then
			combo.up = false
			combo:Hide()
		end
		combo.points = nil
		self:Stack()
		return
	end
	local points, source = R.Combo()
	local secret = Secret(points)
	local up = (secret or points > 0 or R.BuildsCombo(self.unit)) and true or false
	if up ~= combo.up then
		combo.up = up
		combo:SetShown(up)
	end
	self:Stack()
	for i, pip in ipairs(combo.pips) do
		if secret then
			local lit = R.ComboLit(source, i, def.count)
			pip.fill:SetAlpha(lit)
			pip.glow:SetAlpha(lit)
			pip.lit = nil
		else
			local lit = i <= points and 1 or 0
			if lit ~= pip.lit then
				pip.lit = lit
				pip.fill:SetAlpha(lit)
				pip.glow:SetAlpha(lit)
			end
		end
	end
	local was = combo.points
	combo.points = not secret and points or nil
	self:PaintKeel()
	if secret then
		for _, pip in ipairs(combo.pips) do pip.flash:SetAlpha(0) end
		return
	end
	if was and points > was and not self.fresh then
		for i = was + 1, points do combo.flashes[i] = GAIN end
	end
	self:Animate()
end

-- Animation: the target flash, pip flashes and the full-combo gleam

local function Lights(self, elapsed)
	local busy = false

	local glide = self.glide
	if glide then
		glide.at = glide.at + elapsed
		local t = glide.at / GLIDE
		if t >= 1 then
			self.glide = nil
			self:SetTone(glide[4], glide[5], glide[6])
		else
			t = t * (2 - t)   -- eases out
			self:SetTone(glide[1] + (glide[4] - glide[1]) * t, glide[2] + (glide[5] - glide[2]) * t, glide[3] + (glide[6] - glide[3]) * t)
			busy = true
		end
	end

	local hold = self.hold
	if hold then
		hold = hold - elapsed
		local light = self.health.light
		if hold <= 0 then
			self.hold = nil
			light:Hide()
		else
			self.hold = hold
			light:SetAlpha(HOLD_LIGHT * hold / HOLD)
			light:Show()
			busy = true
		end
	end

	if self.lock then
		local left = self.lock - elapsed
		self.lock = left > 0 and left or nil
		local t = left > 0 and left / LOCK or 0
		local r, g, b = MarkColor()
		r, g, b = r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
		for _, piece in ipairs(self.pieces) do piece:SetVertexColor(r, g, b) end
		busy = busy or left > 0
	end

	local combo, count = self.combo, L.COMBO.count
	local points = combo.points
	if points and combo:IsShown() then
		local full = points == count
		local at
		if full then
			combo.gleam = (combo.gleam + elapsed) % GLEAM
			at = combo.gleam / GLEAM * count * 3 - 1   -- crosses the pips in the first third of the cycle
			busy = true
		end
		for i, pip in ipairs(combo.pips) do
			local light = i <= points and SHINE or 0
			local left = combo.flashes[i]
			if left then
				left = left - elapsed
				combo.flashes[i] = left > 0 and left or nil
				if left > 0 then
					light = math.max(light, 0.85 * left / GAIN)
					busy = true
				end
			end
			if full then
				local off = (at - (i - 0.5)) / 0.7
				light = math.max(light, 0.55 * math.exp(-off * off))
			end
			pip.flash:SetAlpha(light)
		end
	end

	if not busy then self.lights:SetScript("OnUpdate", nil) end
end

function Plate:Animate()
	Lights(self, 0)
	if self.lock or self.glide or self.hold or next(self.combo.flashes) or self.combo.points == L.COMBO.count then
		self.lights:SetScript("OnUpdate", function(_, elapsed) Lights(self, elapsed) end)
	end
end
