-- A plate: everything drawn on one unit frame. The secure unit buttons and the options preview each carry one.
-- It never touches the host frame's position, size or visibility, so it is safe on a secure button in combat.
-- Nothing is measured: positions come from Layout.lua, and texts truncate through their anchors.
-- With secret values: combo blades are lit through a curve (no flash or gleam), the two incoming-heal
-- bars overlap instead of running end to end, and the mana spark is hidden.
-- P.LEVELS: the frame levels of a plate's pieces over its host frame, for whoever stands something among them.

local ADDON, ns = ...
local L, Texts, Units = ns.Layout, ns.Texts, ns.Units
local UI, Theme, Skin = Shy.UI, Shy.Theme, Shy.Skin
local Secret = Units.Secret

local P = {}
ns.Plate = P

local Plate = {}
Plate.__index = Plate

local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
-- Not referenced by Blizzard's code on this client; unverified in game.
local LOOTER_ICON = "Interface\\GroupFrame\\UI-Group-MasterLooter"
local SPEAKER, SPEAKING = "Interface\\Common\\VoiceChat-Speaker", "Interface\\Common\\VoiceChat-On"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

local READY_LINGER = 8.5   -- seconds the marks stay after a ready check ends
local MANA_REGEN = 5       -- the five second rule
local FLASH = 0.7          -- one pulse of the voice mark
local GLOW = 0.55          -- strength of a lit combo blade's glow
local GAIN = 0.35          -- seconds a blade flashes when its combo point arrives
local GLEAM = 2.4          -- seconds between gleams at full combo points
local POLL = 0.25          -- seconds between updates of a unit with no events (target's target)

local SILVER = { 0.86, 0.87, 0.90 }   -- edge color for a rare
local EMBER = { 0.96, 0.40, 0.22 }    -- edge color round a party member an enemy is on
-- A shield's bar: the game's own shield art (its nameplates' and raid frames'), a pale fill under slanted
-- stripes that tile every `tile` units.
local SHIELD = { fill = "Interface\\RaidFrame\\Shield-Fill", stripes = "Interface\\RaidFrame\\Shield-Overlay",
	tile = 20, alpha = 0.9, stripe = 0.85 }
-- A plate's pieces by frame level over the host frame, bottom to top: the bars; a heal on its way and healing
-- over time past the health's end; your own heal there, and a shield's fill over the health; the fold (healing
-- to come that has no room past the end, back over the health and a shield); a shield's stripes, and damage
-- to come on an enemy; the marks; the words.
local LEVELS = { heal = 2, own = 3, shield = 3, fold = 4, stripes = 5, doom = 5, marks = 6, texts = 7 }
P.LEVELS = LEVELS

-- Fonts: both are font families (UI.NameFont), so every alphabet renders.

local function Font(kind, size)
	if kind == "name" then
		return UI.NameFont(size, "OUTLINE", { roman = L.NAME_FONT, russian = Shy.FONT_ROUNDED }, "plate")
	end
	return UI.NameFont(size, "OUTLINE")
end

local function NewText(parent, def)
	local fs = UI.Words(parent, Font(def.font, def.size), nil, { world = true, justify = "CENTER" })
	fs:SetNonSpaceWrap(false)
	return fs
end

-- Bars

local function NewBar(owner)
	local bar = CreateFrame("StatusBar", nil, owner)
	Shy.Skin.HatchBar(bar)
	bar.fill = bar:GetStatusBarTexture()
	bar.trough = bar:CreateTexture(nil, "BACKGROUND")
	bar.trough:SetAllPoints()
	Shy.Skin.Hatch(bar.trough)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- value and max can be secret: they go straight to the bar, which does the division.
-- `glide`: the fill eases to the value instead of jumping (the game's own easing; it takes secrets too).
local function Fill(bar, value, max, glide)
	if not Secret(max) and max == 0 then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
	else
		bar:SetMinMaxValues(0, max)
		if glide then
			bar:SetValue(value, Enum.StatusBarInterpolation.ExponentialEaseOut)
		else
			bar:SetValue(value)
		end
	end
end

-- Building

local playerClass

function P.Create(owner, kind)
	local self = setmetatable({ owner = owner, kind = kind, memory = {}, present = {}, marks = {} }, Plate)
	local layout = L.Of(kind)
	self.layout, self.width = layout, (L.Size(kind))
	playerClass = playerClass or UnitClassBase("player")

	-- A static accent line instead of the panel's animated one: many plates are on screen at once.
	-- (The target's target, a small piece hanging off the target: the look's mini border.)
	UI.Panel(owner, { brackets = false, line = false, hud = true, mini = kind == "targettarget" })
	if layout.line ~= false then
		local line = owner:CreateTexture(nil, "BORDER", nil, 2)
		line:SetPoint("TOPLEFT", 2, -2)
		line:SetPoint("TOPRIGHT", -2, -2)
		line:SetHeight(2)
		UI.Paint(line, Theme.Accent)
		self.line = line
		-- Housing, like the panel: it goes with the HUD while the frame keeps watch.
		if owner.shyHousing then owner.shyHousing[#owner.shyHousing + 1] = line end
	end

	self.bars = {}
	for _, bar in ipairs(layout.bars) do
		if bar.id ~= "druid" or (kind == "player" and playerClass == "DRUID") then self.bars[bar.id] = NewBar(owner) end
	end
	local health, power = self.bars.health, self.bars.power
	-- Health takes its unit's color (UpdateTone).
	health.trough:SetVertexColor(0.05, 0.05, 0.055, 0.9)
	self:BuildChip()
	if power and layout.powerLine then
		-- A line in its kind's color (UpdatePower).
		power.trough:SetVertexColor(0.04, 0.04, 0.045, 0.9)
	elseif power then
		UI.Tint(power.fill, Theme.Accent)
		UI.Tint(power.trough, UI.colors.fill, 0.7)
	end
	if self.bars.druid then
		local r, g, b = Units.ManaColor()
		self.bars.druid.fill:SetVertexColor(r, g, b)
		self.bars.druid.trough:SetVertexColor(r * 0.3, g * 0.3, b * 0.3, 0.8)
	end
	health:SetClipsChildren(true)   -- an incoming heal stops at the bar's end
	local level = owner:GetFrameLevel()

	-- The fold: a window that is the health's own fill, for the twins of the bars of healing to come (NewHeal).
	local fold = CreateFrame("Frame", nil, health)
	fold:SetAllPoints(health.fill)
	fold:SetClipsChildren(true)
	fold:SetFrameLevel(level + LEVELS.fold)
	self.fold = fold

	-- Incoming heals in mint: others' first, then your own, each starting where the last ends.
	self.heals = {}
	for i, color in ipairs({ { 0.40, 1.00, 0.78, 0.40 }, { 0.40, 1.00, 0.78, 0.75 } }) do
		local heal = self:NewHeal()
		self:ToneHeal(heal, unpack(color))
		self.heals[i] = heal
	end
	self.heals[2]:SetFrameLevel(level + LEVELS.own)

	-- A shield (what will be absorbed before any health is lost: a Power Word: Shield, a ward): on the end of
	-- the health they have, wherever that is: its far edge is the fill's own, and it reaches back over the fill
	-- as far as the shield is of the unit's whole health, drawing in toward the fill's end as the shield is
	-- spent and going with that end as health comes and goes: at half health it ends where the life ends, never
	-- at the bar's far end, off in the missing part. In the game's
	-- own shield art, the pale fill and the slanted stripes its nameplates and raid frames wear, so it reads as
	-- a shield at once and as nothing else on the bar (a pale line along the top reads as trim, a golden bar as
	-- more health). Over the fill rather than past it, as the heals
	-- are: a shield is mostly worn at full health, where past the fill there is no room. The game may keep
	-- both numbers: the bar takes the shield unread and hangs from the fill's corners, which nothing reads; a
	-- bar of nothing draws nothing.
	local shield = CreateFrame("StatusBar", nil, health)
	shield:SetStatusBarTexture(SHIELD.fill)
	shield:SetReverseFill(true)
	shield:SetStatusBarColor(1, 1, 1, SHIELD.alpha)
	-- As wide as the health bar (Arrange), so a shield is to the same measure as the health under it; its far
	-- edge on the fill's. What reaches back past the bar's start is cut by the bar.
	shield:SetPoint("TOPRIGHT", health.fill, "TOPRIGHT", 0, 0)
	shield:SetPoint("BOTTOMRIGHT", health.fill, "BOTTOMRIGHT", 0, 0)
	shield:SetFrameLevel(level + LEVELS.shield)   -- over the fill and a heal on its way, under the fold, the marks and the words
	shield:SetMinMaxValues(0, 1)
	shield:SetValue(0)
	-- The stripes, and a line of light on the shield's leading edge: both drawn the whole bar's size (the
	-- stripes tile by it, Arrange) and seen through a window that is the shield's own extent, which can't be
	-- read. A shield of nothing is a window of no width.
	local window = CreateFrame("Frame", nil, shield)
	window:SetAllPoints(shield:GetStatusBarTexture())
	window:SetClipsChildren(true)
	window:SetFrameLevel(level + LEVELS.stripes)   -- over the fold: healing to come tints a shield, its stripes stay
	local stripes = window:CreateTexture(nil, "ARTWORK")
	stripes:SetTexture(SHIELD.stripes, true, true)
	stripes:SetAllPoints(health)
	stripes:SetAlpha(SHIELD.stripe)
	local lead = window:CreateTexture(nil, "OVERLAY")
	lead:SetPoint("TOPLEFT", shield:GetStatusBarTexture(), "TOPLEFT", 0, 0)
	lead:SetPoint("BOTTOMLEFT", shield:GetStatusBarTexture(), "BOTTOMLEFT", 0, 0)
	lead:SetWidth(2)
	lead:SetColorTexture(1, 1, 1, 0.9)
	shield.stripes = stripes
	self.shield = shield

	-- Marks and texts over everything on the bars (LEVELS).
	local marks = CreateFrame("Frame", nil, owner)
	marks:SetAllPoints()
	marks:SetFrameLevel(level + LEVELS.marks)
	self.markLayer = marks
	local overlay = CreateFrame("Frame", nil, owner)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(level + LEVELS.texts)
	self.overlay = overlay

	self.texts = {}
	for id, def in pairs(layout.texts) do
		if id == "health" then
			self.healthSegs = {}
			for i = 1, Texts.SEGMENTS do self.healthSegs[i] = NewText(overlay, def) end
		elseif id ~= "druid" or self.bars.druid then
			self.texts[id] = NewText(overlay, def)
		end
	end
	for _, id in ipairs({ "name", "class" }) do
		if self.texts[id] then
			self.texts[id]:SetWordWrap(false)
			self.texts[id]:SetJustifyH("LEFT")
		end
	end
	self.wants = {}   -- the marks this layout has a place for
	for _, mark in ipairs(layout.marks) do self.wants[mark.id] = true end
	if #layout.marks > 0 then self:BuildMarks() end
	if layout.signals then self:BuildSignals() end
	if layout.role then self:BuildRole() end
	if kind == "player" and playerClass ~= "WARRIOR" and playerClass ~= "ROGUE" then self:BuildSpark() end

	self.events = CreateFrame("Frame", nil, owner)
	self.events:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
	self:Arrange()
	return self
end

function Plate:BuildMarks()
	local layer, m = self.markLayer, self.marks
	local function Icon(file)
		local t = layer:CreateTexture(nil, "ARTWORK")
		if file then t:SetTexture(file) end
		t:Hide()
		return t
	end
	m.raidTarget = Icon(RAID_ICONS)
	m.leader = Icon(LEADER_ICON)
	m.leader:SetTexCoord(0.1, 0.84, 0.14, 0.88)
	m.masterLooter = Icon(LOOTER_ICON)
	m.masterLooter:SetTexCoord(0.15, 0.9, 0.15, 0.9)
	m.readyCheck = Icon()
	local voice = CreateFrame("Frame", nil, layer)
	voice:Hide()
	voice.base = voice:CreateTexture(nil, "ARTWORK")
	voice.base:SetAllPoints()
	voice.base:SetTexture(SPEAKER)
	voice.base:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	voice.noise = voice:CreateTexture(nil, "ARTWORK", nil, 1)
	voice.noise:SetAllPoints()
	voice.noise:SetTexture(SPEAKING)
	voice.noise:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	voice:SetScript("OnShow", function(f) f.elapsed = 0 end)
	voice:SetScript("OnUpdate", function(f, elapsed)
		f.elapsed = (f.elapsed or 0) + elapsed
		local alpha = (f.elapsed % FLASH) / (FLASH / 2)
		f.noise:SetAlpha(alpha > 1 and 2 - alpha or alpha)
	end)
	m.voice = voice
	self.combo = self:BuildCombo(layer)
end

-- A riser: a housing of the look's mini make standing on the plate's top edge, `rise` over it, rising from behind
-- the plate (a level under it, reaching under its edge by the look's border, so its foot is hidden).
local risers = {}   -- every riser made: { frame, owner, rise }, laid again on a change of look

local function Seat(riser)
	local frame = riser.frame
	-- (Asked of the look by name with the mini flag: a housing not yet dressed doesn't know its look.)
	local _, _, _, under = UI.LookBorder({ look = Theme.Look(), mini = true })
	under = math.max(1, under)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", riser.owner, "TOPLEFT", 0, -under)
	frame:SetPoint("BOTTOMRIGHT", riser.owner, "TOPRIGHT", 0, -under)
	frame:SetHeight(riser.rise + under)
end

local function Riser(frame, owner, rise)
	frame:SetFrameLevel(math.max(0, owner:GetFrameLevel() - 1))
	UI.Panel(frame, { hud = true, mini = true, brackets = false, line = false })
	local riser = { frame = frame, owner = owner, rise = rise }
	risers[#risers + 1] = riser
	Seat(riser)
end

Shy:On("SHY_THEME", function()
	for _, riser in ipairs(risers) do Seat(riser) end
end)

-- An empty blade's color: nearly black, with a trace of the lit color.
function P.ComboDull(i)
	local r, g, b = Theme.Combo(i, L.COMBO.count)
	return 0.04 + r * 0.24, 0.04 + g * 0.24, 0.04 + b * 0.24
end

-- Combo points: a plate-wide riser with five blades. Each blade is four textures:
-- well (always shown), fill and glow (lit by a point), and a white flash on top.
function Plate:BuildCombo(layer)
	local def = L.COMBO
	local combo = CreateFrame("Frame", nil, layer)
	combo:Hide()
	Riser(combo, self.owner, def.rise)
	combo.segs, combo.flashes, combo.gleam = {}, {}, 0
	local width = (self.width - def.inset * 2 - def.gap * (def.count - 1)) / def.count
	for i = 1, def.count do
		local r, g, b = Theme.Combo(i, def.count)
		local seg = {}
		seg.well = combo:CreateTexture(nil, "ARTWORK")
		seg.well:SetPoint("TOPLEFT", combo, "TOPLEFT", def.inset + (i - 1) * (width + def.gap), -def.top)
		seg.well:SetSize(width, def.height)
		seg.well:SetTexture(L.BLADE_WELL)
		seg.well:SetVertexColor(P.ComboDull(i))
		seg.glow = combo:CreateTexture(nil, "ARTWORK", nil, 1)
		seg.glow:SetPoint("TOPLEFT", seg.well, "TOPLEFT", -def.glow, def.glow)
		seg.glow:SetPoint("BOTTOMRIGHT", seg.well, "BOTTOMRIGHT", def.glow, -def.glow)
		seg.glow:SetTexture(L.BLADE_GLOW)
		seg.glow:SetBlendMode("ADD")
		seg.glow:SetVertexColor(r * GLOW, g * GLOW, b * GLOW)   -- ADD blend: darker means fainter
		seg.glow:SetAlpha(0)
		seg.fill = combo:CreateTexture(nil, "ARTWORK", nil, 2)
		seg.fill:SetAllPoints(seg.well)
		seg.fill:SetTexture(L.BLADE)
		seg.fill:SetVertexColor(r, g, b)
		seg.fill:SetAlpha(0)
		seg.flash = combo:CreateTexture(nil, "OVERLAY")
		seg.flash:SetAllPoints(seg.well)
		seg.flash:SetTexture(L.BLADE)
		seg.flash:SetBlendMode("ADD")
		seg.flash:SetAlpha(0)
		combo.segs[i] = seg
	end
	return combo
end

function Plate:BuildSpark()
	local spark = CreateFrame("Frame", nil, self.overlay)
	spark:Hide()
	local t = spark:CreateTexture(nil, "OVERLAY")
	t:SetAllPoints()
	t:SetTexture(SPARK)
	t:SetVertexColor(1, 1, 1, 0.6)
	t:SetBlendMode("ADD")
	spark:SetScript("OnUpdate", function() self:MoveSpark() end)
	self.spark, self.sparkCast, self.sparkStart = spark, 0, 0
	local mana = UnitPower("player", Enum.PowerType.Mana)
	self.sparkMana = not Secret(mana) and mana or 0
end

-- Layout

-- Which bars are shown now: the druid mana bar comes and goes with the form.
function Plate:Present()
	local present, bars = self.present, self.bars
	present.health = true
	present.power = bars.power ~= nil
	present.druid = bars.druid ~= nil and UnitPowerType("player") ~= Enum.PowerType.Mana
	return present
end

function Plate:Arrange()
	local layout, owner, bars, texts = L.Of(self.kind), self.owner, self.bars, self.texts
	-- A party cell is the row's or the healing grid's: the same pieces, at the other's measures and sizes.
	if layout ~= self.layout then
		self.layout = layout
		for id, def in pairs(layout.texts) do
			if id == "health" then
				for _, seg in ipairs(self.healthSegs) do seg:SetFontObject(Font(def.font, def.size)) end
			elseif texts[id] then
				texts[id]:SetFontObject(Font(def.font, def.size))
			end
		end
		wipe(self.memory)   -- what was written was cut to the other's room
		if self.role then self.role:Hide() end   -- seated and shown again by UpdateRole
	end
	self.width = (L.Size(self.kind))   -- a party cell's width follows the plates under it
	local trim = self:PetTrim()
	self.trimmed = trim ~= nil
	local rects = L.Bars(layout, self.width, self:Present(), trim)
	self.rects = rects
	for id, bar in pairs(bars) do
		local rect = rects[id]
		bar:SetShown(rect ~= nil)
		if rect then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", owner, "TOPLEFT", rect[1], -rect[2])
			bar:SetSize(rect[3], rect[4])
		end
	end
	for _, heal in ipairs(self.heals) do self:SizeHeal(heal, rects.health) end
	-- The shield is the bar's width, and its stripes tile by the bar's own size.
	self.shield:SetWidth(rects.health[3])
	self.shield.stripes:SetTexCoord(0, rects.health[3] / SHIELD.tile, 0, rects.health[4] / SHIELD.tile)

	-- The name is anchored to the health text, so it truncates where they meet.
	local segs = self.healthSegs
	segs[1]:ClearAllPoints()
	segs[1]:SetPoint("RIGHT", bars.health, "RIGHT", -L.TEXT_INSET, layout.lift or 0)
	for i = 2, #segs do
		segs[i]:ClearAllPoints()
		segs[i]:SetPoint("RIGHT", segs[i - 1], "LEFT", 0, 0)
	end
	self:ArrangeName()

	if texts.power then
		texts.power:ClearAllPoints()
		texts.power:SetPoint("RIGHT", bars.power, "RIGHT", -L.TEXT_INSET, 0)
	end
	if texts.class then
		texts.class:ClearAllPoints()
		texts.class:SetPoint("LEFT", bars.power, "LEFT", L.TEXT_INSET, 0)
		texts.class:SetPoint("RIGHT", texts.power, "LEFT", -L.TEXT_SPACING, 0)
	end
	if texts.druid then
		-- On the power row: the druid mana bar is too thin for text.
		texts.druid:SetShown(rects.druid ~= nil)
		texts.druid:ClearAllPoints()
		texts.druid:SetPoint("CENTER", bars.power, "CENTER", 0, 0)
	end
	self.markBits = nil   -- laid out again whatever shows
	self:ArrangeMarks()
end

local ON_COMBO = { raidTarget = L.COMBO.rise }   -- lifts the raid mark onto the combo riser
local MARK_BITS = { raidTarget = 1, leader = 2, masterLooter = 4, readyCheck = 8, voice = 16 }

-- Laid out only when the marks shown, the combo riser or the width changed since the last time.
function Plate:ArrangeMarks()
	local m, owner = self.marks, self.owner
	if not m.raidTarget then return end
	local combo = self.combo:IsShown()
	local bits = combo and 32 or 0
	for id, mark in pairs(m) do
		if mark:IsShown() then bits = bits + (MARK_BITS[id] or 64) end
	end
	if bits == self.markBits and self.width == self.markWidth then return end
	self.markBits, self.markWidth = bits, self.width
	local present = self.markPresent or {}
	self.markPresent = present
	wipe(present)
	for id, mark in pairs(m) do
		if mark:IsShown() then present[id] = mark.aspect or 1 end
	end
	local spots = L.Marks(self.layout, self.width, present, nil, combo and ON_COMBO or nil)
	for id, spot in pairs(spots) do
		local mark = m[id]
		mark:ClearAllPoints()
		mark:SetPoint("CENTER", owner, "TOPLEFT", spot[1], -spot[2])
		mark:SetSize(spot[3], spot[4])
	end
end

-- Showing a unit

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
	"UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_AURA",
	"UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_FLAGS", "INCOMING_RESURRECT_CHANGED",
}
-- For a layout with signals.
local SIGNAL_EVENTS = { "UNIT_THREAT_SITUATION_UPDATE", "UNIT_IN_RANGE_UPDATE" }
-- Events that can change who the frame shows, or its marks.
local WORLD_EVENTS = {
	"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "GROUP_ROSTER_UPDATE",
	"PARTY_LEADER_CHANGED", "PARTY_LOOT_METHOD_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ROLES_ASSIGNED",
	"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED",
}
-- The unit may be someone else after these: per-unit memory is cleared.
local NEW_UNIT = {
	PLAYER_ENTERING_WORLD = true, PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true, UNIT_PET = true,
	GROUP_ROSTER_UPDATE = true,
}
-- A new target or focus is someone else only on the frames that follow it; on the others only the
-- brackets round your target among the party can change.
local FOLLOWS = {
	PLAYER_TARGET_CHANGED = { target = true, targettarget = true },
	PLAYER_FOCUS_CHANGED = { focus = true },
	UNIT_TARGET = { targettarget = true },   -- your target turned to someone else
}

function Plate:SetUnit(unit)
	self.unit = unit
	local seat = unit:match("^party(%d)$")
	self.petUnit = seat and "partypet" .. seat or nil
	local events = self.events
	events:UnregisterAllEvents()
	for _, event in ipairs(UNIT_EVENTS) do events:RegisterUnitEvent(event, unit) end
	if self.layout.signals then
		for _, event in ipairs(SIGNAL_EVENTS) do events:RegisterUnitEvent(event, unit) end
	end
	for _, event in ipairs(WORLD_EVENTS) do events:RegisterEvent(event) end
	if unit == "target" then
		-- Combo points are the player's power, shown on the target.
		events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "target", "player")
		events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target", "player")   -- a druid entering or leaving cat form
	end
	if self.spark then events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player") end
	-- No unit events fire for "targettarget": its health is polled, as Blizzard's own frame does every frame.
	-- Who it is the game does say: UNIT_TARGET on your target draws the new one at once.
	if unit == "targettarget" then
		events:RegisterUnitEvent("UNIT_TARGET", "target")
		local since = 0
		events:SetScript("OnUpdate", function(_, elapsed)
			since = since + elapsed
			if since >= POLL then
				since = 0
				self:Update()
			end
		end)
	end
	self:Update(true)
end

local HANDLERS = {
	UNIT_HEALTH = "UpdateHealth", UNIT_MAXHEALTH = "UpdateHealth", UNIT_CONNECTION = "UpdateHealth",
	UNIT_FLAGS = "UpdateHealth", INCOMING_RESURRECT_CHANGED = "UpdateHealth",
	UNIT_HEAL_PREDICTION = "UpdateHeals", UNIT_ABSORB_AMOUNT_CHANGED = "UpdateShield",
	UNIT_THREAT_SITUATION_UPDATE = "UpdateEdge", UNIT_IN_RANGE_UPDATE = "UpdateReach",
	UNIT_POWER_UPDATE = "UpdatePower", UNIT_POWER_FREQUENT = "UpdatePower", UNIT_MAXPOWER = "UpdatePower",
	UNIT_NAME_UPDATE = "UpdateName",
	UNIT_LEVEL = "UpdateClass", UNIT_CLASSIFICATION_CHANGED = "UpdateClass",
}

function Plate:OnEvent(event, arg1, arg2, arg3)
	local unit = self.unit
	if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
		self:ReadReady()
		if UnitExists(unit) then self:UpdateMarks() end
	elseif event == "READY_CHECK_FINISHED" then
		C_Timer.After(READY_LINGER, function()
			self:ReadReady()
			if UnitExists(self.unit) then self:UpdateMarks() end
		end)
	elseif event == "VOICE_CHAT_CHANNEL_MEMBER_SPEAKING_STATE_CHANGED" then
		P.Heard(arg1, arg2, arg3)
		if UnitExists(unit) then self:UpdateMarks() end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		self.sparkCast = GetTime()
	elseif not UnitExists(unit) then
		-- Whoever held the seat left: the test party's member has it again.
		if self.sample then self:Sample(self.sample) end
		return
	elseif event == "UNIT_POWER_FREQUENT" and arg1 == "player" and unit == "target" then
		-- Your energy or mana moving changes nothing on the target: only a combo point does.
		if Secret(arg2) or arg2 == "COMBO_POINTS" then self:UpdateMarks() end
	elseif FOLLOWS[event] then
		if FOLLOWS[event][unit] then
			self:Update(true)
		elseif event == "PLAYER_TARGET_CHANGED" then
			self:UpdateBrackets()
		end
	elseif event == "RAID_TARGET_UPDATE" then
		self:UpdateMarks()
	elseif event == "PLAYER_LEVEL_UP" then
		self:UpdateClass()   -- your level, and so every level's color in the class line
	elseif HANDLERS[event] then
		self[HANDLERS[event]](self)
		if event == "UNIT_CLASSIFICATION_CHANGED" then self:UpdateEdge() end
		if self.spark and (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") then self:WatchMana() end
	elseif event == "UNIT_DISPLAYPOWER" then
		self:UpdateForm()
		self:UpdatePower()
		self:UpdateClass()
		if unit == "target" then self:UpdateMarks() end
	elseif event == "UNIT_FACTION" then
		self:Update()   -- friend or foe changed: colors, health text format
	elseif event == "UNIT_AURA" then
		self:Soon()
	else
		self:Update(NEW_UNIT[event])
	end
end

-- UNIT_AURA fires in bursts: read once, on the next frame. A druid's form is a buff.
-- The read is one function made once a plate: a fight brings a burst every frame.
function Plate:Soon()
	if self.soon or not self.texts.class then return end
	self.soon = true
	local read = self.soonRead
	if not read then
		read = function()
			self.soon = nil
			if UnitExists(self.unit) then self:UpdateClass() end
		end
		self.soonRead = read
	end
	C_Timer.After(0, read)
end

function Plate:Update(newUnit)
	local unit = self.unit
	if not unit or not UnitExists(unit) then return end
	if newUnit then
		wipe(self.memory)
		self:ReadReady()
		if self.combo then self.combo.points = nil end   -- so points already on a new target don't flash
	end
	self:UpdateForm()
	-- A pet's bar takes the end of its owner's health bar, or has given it back.
	if self.petUnit and (self:PetTrim() ~= nil) ~= (self.trimmed == true) then self:Arrange() end
	self:UpdateRole()
	self:UpdateName()
	self:UpdateHealth()
	self:UpdatePower()
	self:UpdateClass()
	self:UpdateEdge()
	self:UpdateReach()
	self:UpdateMarks()
end

function Plate:UpdateName()
	Texts.WriteName(self.texts.name, self.unit, self.layout.nameLimit, self.layout.first)
end

function Plate:UpdateHealth()
	local unit = self.unit
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	-- A layout may have health glide (`smooth`); never from whoever was in the frame before (`shown`: cleared
	-- with the plate's memory when the unit may be someone else).
	Fill(self.bars.health, hp, max, self.layout.smooth and self.memory.shown == true)
	self.memory.shown = true
	self:UpdateTone()
	self:Flash(hp, max)
	Texts.InkName(self.texts.name, unit)
	Texts.WriteHealth(self.healthSegs, unit, self.layout.short)
	self:UpdateHeals()
	self:UpdateShield()
end

function Plate:UpdatePower()
	local unit, bar = self.unit, self.bars.power
	if bar then
		Fill(bar, UnitPower(unit), UnitPowerMax(unit))
		if self.layout.powerLine then
			bar:SetStatusBarColor(Theme.Power(UnitPowerType(unit)))
		else
			Texts.WritePower(self.texts.power, unit)
		end
	end
	if self.rects.druid then
		Fill(self.bars.druid, UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana))
		Texts.WriteDruid(self.texts.druid)
	end
end

-- A druid changed form: lay out again if the mana bar came or went.
function Plate:UpdateForm()
	if self.bars.druid and self:Present().druid ~= (self.rects.druid ~= nil) then self:Arrange() end
end

function Plate:UpdateClass()
	if self.texts.class then Texts.WriteClass(self.texts.class, self.unit) end
end

-- Edge color: gold for an elite or boss, silver for a rare, and ember with a light crossing it
-- round a party member an enemy is on. The combo riser's edge matches.
function Plate:UpdateEdge()
	local kind = UnitClassification(self.unit)
	local color = Skin.colors.metal
	if kind == "worldboss" or kind == "elite" then
		color = UI.colors.alert
	elseif kind == "rare" or kind == "rareelite" then
		color = SILVER
	end
	if self.alarm then
		local hunted = self:Hunted()
		if hunted then color = EMBER end
		self.alarm:SetShown(hunted)
	end
	-- The palette's tables change in place with the theme, so the same table needs no second telling.
	if color == self.edgeColor then return end
	self.edgeColor = color
	UI.SetBorder(self.owner, color)
	if self.combo then UI.SetBorder(self.combo, color) end   -- the riser is the plate's: its edge too
end

-- Healing to come: a bar past the end of the health someone has, and its twin in the fold, told the same.
-- The fold is the room there isn't: what a bar has no room left for past the health's end is cut by the
-- bar's own end, and that much shows back over the health instead, from the bar's far end toward its start
-- (the fold's bars run the other way, in a window that is the health's own fill). So healing to come is
-- always as long as it is, wherever the health stands, and always on the health's end: at half health all
-- of it past the fill, at full health all of it back over the end of the health, and in between some of each,
-- to either side of that end. What is over the health is what would be wasted. The game may keep every
-- number: the bars take them unread.
-- `texture`: the bar's own (nil: the hatched one every bar here wears).

function Plate:NewHeal(texture)
	local level = self.owner:GetFrameLevel()
	local bar = CreateFrame("StatusBar", nil, self.bars.health)
	local back = CreateFrame("StatusBar", nil, self.fold)
	for _, b in ipairs({ bar, back }) do
		if texture then b:SetStatusBarTexture(texture) else Skin.HatchBar(b) end
		b.fill = b:GetStatusBarTexture()
		b:SetMinMaxValues(0, 1)
		b:SetValue(0)
		b:Hide()
	end
	back:SetReverseFill(true)
	bar:SetFrameLevel(level + LEVELS.heal)
	back:SetFrameLevel(level + LEVELS.fold)
	bar.back = back
	local rect = self.rects and self.rects.health
	if rect then self:SizeHeal(bar, rect) end
	return bar
end

function Plate:SizeHeal(bar, rect)
	bar:SetSize(rect[3], rect[4])
	bar.back:SetSize(rect[3], rect[4])
end

-- Where a bar starts: on the end of the one before it (`after`; nil: the health's own end). Its twin, from
-- the bar's far end or on the one before's twin. Told again only when that changes.
function Plate:HangHeal(bar, after)
	local was = bar.after
	if was == (after or false) then return end
	bar.after = after or false
	local health = self.bars.health
	bar:ClearAllPoints()
	bar:SetPoint("LEFT", after and after.fill or health.fill, "RIGHT", 0, 0)
	bar.back:ClearAllPoints()
	bar.back:SetPoint("RIGHT", after and after.back.fill or health, after and "LEFT" or "RIGHT", 0, 0)
end

-- `glide`: the bar eases to the value (the game's own easing; it takes secrets too).
function Plate:FillHeal(bar, value, max, glide)
	Fill(bar, value, max, glide)
	Fill(bar.back, value, max, glide)
	bar:Show()
	bar.back:Show()
end

function Plate:ToneHeal(bar, r, g, b, a)
	bar:SetStatusBarColor(r, g, b, a)
	bar.back:SetStatusBarColor(r, g, b, a)
end

function Plate:DropHeal(bar)
	bar:Hide()
	bar.back:Hide()
end

-- Incoming heals: others' in pale green, then your own in bright green, shifting to red by the share that
-- would overheal. They start where what stands before them ends (`healStart`: the last segment of healing
-- over time, Hots.lua, which always starts on the health's own end so nothing stands between the health and
-- it; nil: the health's own end). `healChain`: your own starts on the end of others' (else where theirs does).

function Plate:HangHeals()
	local others, mine = self.heals[1], self.heals[2]
	local start = self.healStart
	self:HangHeal(others, start)
	self:HangHeal(mine, self.healChain and others or start)
end

function Plate:UpdateHeals()
	local unit = self.unit
	local others, mine = self.heals[1], self.heals[2]
	local all, own = UnitGetIncomingHeals(unit), UnitGetIncomingHeals(unit, "player")
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	self.healChain = false
	if not Secret(all) and all == nil then
		self:DropHeal(others)
		self:DropHeal(mine)
		return
	end
	if Secret(all, own, hp, max) then
		-- Secret: no arithmetic. The total in pale green, your own part overlapping its start.
		self:HangHeals()
		self:FillHeal(others, all, max)
		if Secret(own) or own ~= nil then self:FillHeal(mine, own, max) else self:DropHeal(mine) end
		self:ToneHeal(mine, 0, 1, 0, 1)
		return
	end
	own = own or 0
	if all <= 0 or max <= 0 then
		self:DropHeal(others)
		self:DropHeal(mine)
		return
	end
	local rest = math.max(0, all - own)
	self.healChain = rest > 0
	self:HangHeals()
	if rest > 0 then self:FillHeal(others, rest, max) else self:DropHeal(others) end
	if own > 0 then
		self:FillHeal(mine, own, max)
		-- Green to red by the overheal share, then normalized to full brightness.
		local waste = math.max(0, math.min(1, (hp + rest + own - max) / own))
		local r, g, a = waste, 1 - waste, 1 - 0.35 * waste
		local high = math.max(r, g, 0.00001)
		self:ToneHeal(mine, r / high, g / high, 0, a)
	else
		self:DropHeal(mine)
	end
end

-- The shield left on them, against their whole health. Both numbers may be the game's to keep: they go to the
-- bar unread.
function Plate:UpdateShield()
	local unit, shield = self.unit, self.shield
	local absorb, max = UnitGetTotalAbsorbs(unit), UnitHealthMax(unit)
	if (not Secret(absorb) and absorb == nil) or (not Secret(max) and (max == nil or max <= 0)) then
		shield:SetMinMaxValues(0, 1)
		shield:SetValue(0)
		return
	end
	shield:SetMinMaxValues(0, max)
	shield:SetValue(absorb)
end

-- Five second rule: after a spell that cost mana, a spark crosses the mana bar until regen resumes.

function Plate:WatchMana()
	local mana = UnitPower("player", Enum.PowerType.Mana)
	if Secret(mana) then return end
	if mana < self.sparkMana and GetTime() - self.sparkCast < 0.5 then
		self.sparkStart, self.sparkCast = self.sparkCast, 0
		self.spark:Show()
	end
	self.sparkMana = mana
end

function Plate:MoveSpark()
	local spark = self.spark
	local id = self.rects.druid and "druid" or "power"
	local rect = self.rects[id]
	local mana, max = UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana)
	local since = GetTime() - self.sparkStart
	if since > MANA_REGEN or Secret(mana, max) or mana == max
		or (id == "power" and UnitPowerType("player") ~= Enum.PowerType.Mana) then
		spark:Hide()
		return
	end
	spark:SetSize(20, rect[4] * 2)
	spark:ClearAllPoints()
	spark:SetPoint("CENTER", self.bars[id], "LEFT", since / MANA_REGEN * (rect[3] - 1), 0)
end

-- Marks on the edges

local speaking = {}   -- GUID -> speaking in voice chat now

function P.Heard(member, channel, isSpeaking)
	if Secret(member, channel, isSpeaking) then return end
	local guid = C_VoiceChat.GetMemberGUID(member, channel)
	if not Secret(guid) and guid then speaking[guid] = isSpeaking or nil end
end

-- Ready check marks show only to a leader or assistant.
function Plate:ReadReady()
	self.ready = nil
	local leads, assists = UnitIsGroupLeader("player"), UnitIsGroupAssistant("player")
	if not Secret(leads, assists) and (leads or assists) then
		local status = GetReadyCheckStatus(self.unit)
		if not Secret(status) then self.ready = status end
	end
end

local READY_ART = { ready = READY_CHECK_READY_TEXTURE, notready = READY_CHECK_NOT_READY_TEXTURE, waiting = READY_CHECK_WAITING_TEXTURE }

-- 0 for you, 1-4 for party members, nil for anyone else (matches GetLootMethod's party index).
local function GroupSeat(unit)
	if unit == "player" then return 0 end
	return tonumber(unit:match("^party(%d)$"))
end

-- 0 below the i-th of five points, 1 from it on.
local comboCurves = {}
local function ComboCurve(i)
	if not comboCurves[i] then
		local curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		local at = (i - 0.5) / L.COMBO.count
		curve:AddPoint(0, 0)
		curve:AddPoint(at - 0.001, 0)
		curve:AddPoint(at, 1)
		curve:AddPoint(1, 1)
		comboCurves[i] = curve
	end
	return comboCurves[i]
end

-- OnUpdate while anything is animating: a fading flash on a new point, and a gleam crossing the row at full points.
local function ComboLight(combo, elapsed)
	local count = L.COMBO.count
	local full = combo.points == count
	local busy = full
	local at
	if full then
		combo.gleam = (combo.gleam + elapsed) % GLEAM
		at = combo.gleam / GLEAM * count * 3 - 1   -- crosses in the first third of the cycle
	end
	for i, seg in ipairs(combo.segs) do
		local light = 0
		local left = combo.flashes[i]
		if left then
			left = left - elapsed
			combo.flashes[i] = left > 0 and left or nil
			if left > 0 then
				light = 0.8 * left / GAIN
				busy = true
			end
		end
		if full then
			local off = (at - (i - 0.5)) / 0.7
			light = math.max(light, 0.5 * math.exp(-off * off))
		end
		seg.flash:SetAlpha(light)
	end
	if not busy then combo:SetScript("OnUpdate", nil) end
end

-- Shown with points on the target, or empty on any attackable target while your power is energy, or on any
-- target while ShyBuffs' icons stand on it (ns.Plinth). A secret count lights the blades through a curve.
function Plate:UpdateCombo(points, source)
	local combo = self.combo
	local secret = Secret(points)
	local ready = self.unit == "target" and (ns.Plinth()
		or UnitPowerType("player") == Enum.PowerType.Energy and UnitCanAttack("player", "target"))
	local up = (secret or points > 0 or ready) and true or false
	if up ~= combo.up then
		combo.up = up
		combo:SetShown(up)
	end
	for i, seg in ipairs(combo.segs) do
		-- Branch written out: `secret and x or y` would truth-test a secret percent.
		if secret then
			local lit = UnitPowerPercent(source, Enum.PowerType.ComboPoints, false, ComboCurve(i))
			seg.fill:SetAlpha(lit)
			seg.glow:SetAlpha(lit)
			seg.lit = nil
		else
			local lit = i <= points and 1 or 0
			if lit ~= seg.lit then
				seg.lit = lit
				seg.fill:SetAlpha(lit)
				seg.glow:SetAlpha(lit)
			end
		end
	end
	local was = combo.points
	combo.points = not secret and points or nil
	if secret then return end
	if was and points > was then
		for i = was + 1, points do combo.flashes[i] = GAIN end
	end
	if next(combo.flashes) or points == L.COMBO.count then
		combo:SetScript("OnUpdate", ComboLight)
	end
end

-- Your target among the party: brackets at its corners. The game may keep the answer and set the alpha itself.
function Plate:UpdateBrackets()
	local brackets = self.brackets
	if not brackets then return end
	local mine = UnitIsUnit(self.unit, "target")
	for _, bracket in ipairs(brackets) do
		if Secret(mine) then bracket:SetAlphaFromBoolean(mine, 1, 0) else bracket:SetAlpha(mine and 1 or 0) end
	end
end

function Plate:UpdateMarks()
	local m, unit = self.marks, self.unit
	if not m.raidTarget then return end
	local seat = GroupSeat(unit)

	local index = GetRaidTargetIndex(unit)
	local marked = Secret(index) or index ~= nil
	m.raidTarget:SetShown(marked)
	if marked then SetRaidTargetIconTexture(m.raidTarget, index) end

	self:UpdateBrackets()

	-- Leader and master looter: on your own frame and your party's. A party cell says who leads with the role's picture.
	local leads = self.wants.leader and seat ~= nil and IsInGroup() and UnitIsGroupLeader(unit)
	if Secret(leads) then
		m.leader:Show()
		m.leader:SetAlphaFromBoolean(leads)
	else
		m.leader:SetAlpha(1)
		m.leader:SetShown(leads and true or false)
	end
	local method, looter = C_PartyInfo.GetLootMethod()
	m.masterLooter:SetShown(seat ~= nil and method == Enum.LootMethod.Masterlooter and looter == seat)

	local art = READY_ART[self.ready]
	m.readyCheck:SetShown(art ~= nil)
	if art then m.readyCheck:SetAtlas(art) end

	local guid = UnitGUID(unit)
	m.voice:SetShown(not Secret(guid) and guid ~= nil and speaking[guid] == true)

	local source = UnitHasVehicleUI("player") and "vehicle" or "player"
	self:UpdateCombo(unit == "target" and GetComboPoints(source, "target") or 0, source)
	self:ArrangeMarks()
end

-- Health: who it is, and what was just lost

local MISSING = { 0.05, 0.05, 0.055 }   -- the missing part when the fill's color can't be worked on
local MISSING_ALPHA = 0.9
local CHIP, CHIP_LIGHT = 0.6, 0.85      -- seconds the part just lost stays lit, and how bright it starts

-- The fill in the unit's color, the missing part in the same hue, deep.
-- Your own frame's health wears the color picked for your health (Shy.Skin.HealthRGB), toned as every
-- health fill is; the cockpit's bar under your character wears the same (T:HealthFill).
function Plate:UpdateTone()
	local health = self.bars.health
	local r, g, b, mr, mg, mb
	if self.unit == "player" then
		r, g, b, mr, mg, mb = Units.Tone(Shy.Skin.HealthRGB())
	else
		r, g, b, mr, mg, mb = Units.BarColors(self.unit)
	end
	health:SetStatusBarColor(r, g, b)
	if mr then
		health.trough:SetVertexColor(mr, mg, mb, MISSING_ALPHA)
	else
		health.trough:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], MISSING_ALPHA)
	end
end

function Plate:BuildChip()
	local health = self.bars.health
	local chip = health:CreateTexture(nil, "ARTWORK", nil, 3)
	chip:SetColorTexture(1, 1, 1)
	chip:SetPoint("TOPLEFT", health.fill, "TOPRIGHT", 0, 0)
	chip:SetPoint("BOTTOMLEFT", health.fill, "BOTTOMRIGHT", 0, 0)
	chip:Hide()
	chip.fade = chip:CreateAnimationGroup()
	local alpha = chip.fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(CHIP_LIGHT)
	alpha:SetToAlpha(0)
	alpha:SetDuration(CHIP)
	alpha:SetSmoothing("OUT")
	chip.fade:SetScript("OnFinished", function() chip:Hide() end)
	self.chip = chip
end

-- A hit: the part just lost flashes before it is gone. Secret health can't be compared, so nothing flashes.
function Plate:Flash(hp, max)
	local memory = self.memory
	local was = memory.health
	if Secret(hp, max) then
		memory.health = nil
		return
	end
	memory.health = hp
	if not was or hp >= was or max <= 0 then return end
	local chip = self.chip
	chip:SetWidth(math.max(1, (was - hp) / max * self.rects.health[3]))
	chip:Show()
	chip.fade:Stop()
	chip.fade:Play()
end

-- A party member: reach, an enemy on them, your target, their role

local FAR = 0.42                     -- a member out of your reach
local CROSS, CROSS_WIDTH = 2.2, 60   -- seconds a light takes to cross the ember edge, and its width
local GLYPH = 10                     -- the role's picture
local GOLD = UI.colors.alert
local ROLE_ART = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

function Plate:BuildSignals()
	local owner = self.owner
	-- Your target: a bracket in your color at each corner.
	self.brackets = {}
	for i, def in ipairs(UI.BRACKETS) do
		local t = self.markLayer:CreateTexture(nil, "OVERLAY")
		t:SetTexture(UI.BRACKET)
		t:SetTexCoord(def[2], def[3], def[4], def[5])
		t:SetSize(UI.BRACKET_SIZE, UI.BRACKET_SIZE)
		t:SetPoint(def[1], owner, def[1], (def[2] == 0) and -2 or 2, (def[4] == 0) and 2 or -2)
		UI.Tint(t, Theme.Accent)
		t:SetAlpha(0)
		self.brackets[i] = t
	end
	-- An enemy on them: the edge turns ember and a light crosses its top.
	local alarm = CreateFrame("Frame", nil, owner)
	alarm:SetPoint("TOPLEFT", 1, 0)
	alarm:SetPoint("TOPRIGHT", -1, 0)
	alarm:SetHeight(2)
	alarm:SetFrameLevel(owner:GetFrameLevel() + 2)
	alarm:SetClipsChildren(true)
	alarm:Hide()
	local light = alarm:CreateTexture(nil, "OVERLAY")
	light:SetTexture(Shy.Brand.GLOW)
	light:SetBlendMode("ADD")
	light:SetVertexColor(1, 0.89, 0.77)
	light:SetSize(CROSS_WIDTH, 10)
	alarm.at = 0
	alarm:SetScript("OnUpdate", function(f, elapsed)
		f.at = (f.at + elapsed) % CROSS
		light:ClearAllPoints()
		light:SetPoint("CENTER", f, "LEFT", f.at / CROSS * (self.width + CROSS_WIDTH) - CROSS_WIDTH / 2, 0)
	end)
	self.alarm = alarm
end

function Plate:BuildRole()
	local glyph = self.overlay:CreateTexture(nil, "OVERLAY")
	glyph:SetSize(GLYPH, GLYPH)
	glyph:Hide()
	self.role = glyph
end

-- The name starts after the role's picture when there is one. Both stand on the texts' line (a layout's `lift`
-- over the health bar's middle).
function Plate:ArrangeName()
	local name, segs = self.texts.name, self.healthSegs
	local lift = self.layout.lift or 0
	if self.role then
		self.role:ClearAllPoints()
		self.role:SetPoint("LEFT", self.bars.health, "LEFT", L.TEXT_INSET, lift)
	end
	name:ClearAllPoints()
	if self.role and self.role:IsShown() then
		name:SetPoint("LEFT", self.role, "RIGHT", 3, 0)
	else
		name:SetPoint("LEFT", self.bars.health, "LEFT", L.TEXT_INSET, lift)
	end
	name:SetPoint("RIGHT", segs[#segs], "LEFT", -L.TEXT_SPACING, 0)
end

-- The role's picture, gold on whoever leads; a leader with no role wears the crown there.
function Plate:UpdateRole()
	local glyph = self.role
	if not glyph then return end
	local unit = self.unit
	local role, leads = UnitGroupRolesAssigned(unit), UnitIsGroupLeader(unit)
	if Secret(role) then role = nil end
	if Secret(leads) then leads = false end
	local art = role and ROLE_ART[role]
	-- A layout may keep the picture to some roles (`roles`): the rest, and a leader with none, wear nothing.
	local only = self.layout.roles
	if only then
		if not (role and only[role]) then art = nil end
		if not art then leads = false end
	end
	if art then
		glyph:SetAtlas(art)
		glyph:SetDesaturated(true)
		local ink = leads and GOLD or Texts.INK
		glyph:SetVertexColor(ink[1], ink[2], ink[3])
	elseif leads then
		glyph:SetTexture(LEADER_ICON)
		glyph:SetTexCoord(0.1, 0.84, 0.14, 0.88)
		glyph:SetDesaturated(false)
		glyph:SetVertexColor(1, 1, 1)
	end
	local shown = (art ~= nil or leads) and true or false
	if shown ~= glyph:IsShown() then
		glyph:SetShown(shown)
		self:ArrangeName()
	end
end

-- Faded while out of your reach. The game answers with a secret in a fight: it sets the alpha itself.
function Plate:UpdateReach()
	if not self.layout.signals then return end
	local owner = self.owner
	-- Your own cell in the grid: you are never out of your own reach (the game answers "not in range" for you).
	if self.unit == "player" then
		owner:SetAlpha(1)
		return
	end
	local near, checked = UnitInRange(self.unit)
	if Secret(near, checked) then
		owner:SetAlphaFromBoolean(near, 1, FAR)
	else
		owner:SetAlpha((checked and not near) and FAR or 1)
	end
end

-- An enemy is on them: the game's threat standing of 2 or 3.
function Plate:Hunted()
	if not self.alarm then return false end
	local threat = UnitThreatSituation(self.unit)
	return not Secret(threat) and threat ~= nil and threat >= 2
end

-- The test party: a seat nobody holds shows a sample member (`s`: Frames.lua's F.SAMPLES; nil ends it), drawn
-- with the plate's own pieces as a member would be, so a cell can be judged without a group. A seat someone
-- holds shows them. Only our own regions are told anything: safe at any time.
function Plate:Sample(s)
	self.sample = s
	if not s or UnitExists(self.unit) then return end
	local bars = self.bars
	Fill(bars.health, s.hp, s.max)
	local color = C_ClassColor.GetClassColor(s.class)
	local r, g, b, mr, mg, mb = Units.Tone(color.r, color.g, color.b)
	bars.health:SetStatusBarColor(r, g, b)
	bars.health.trough:SetVertexColor(mr, mg, mb, MISSING_ALPHA)
	if bars.power then
		Fill(bars.power, s.power, s.powerMax)
		bars.power:SetStatusBarColor(Theme.Power(s.powerType))
	end
	self.shield:SetMinMaxValues(0, s.max)
	self.shield:SetValue(s.shield or 0)
	if self.role and self.role:IsShown() then
		self.role:Hide()
		self:ArrangeName()
	end
	Texts.WriteSample(self.texts.name, self.healthSegs, s, self.layout.nameLimit)
	-- A heal on its way to them, as one would stand: others' (`heal`), then your own (`mine`).
	local others, mine = self.heals[1], self.heals[2]
	self.healChain = s.heal ~= nil
	self:HangHeals()
	if s.heal then self:FillHeal(others, s.heal, s.max) else self:DropHeal(others) end
	if s.mine then
		self:FillHeal(mine, s.mine, s.max)
		self:ToneHeal(mine, 0, 1, 0, 1)
	else
		self:DropHeal(mine)
	end
	-- Nothing of whoever was last in the seat: no marks, no alarm, in reach.
	self.chip:Hide()
	self.memory.health, self.memory.shown = nil, nil   -- whoever comes next starts afresh
	for _, mark in pairs(self.marks) do mark:Hide() end
	if self.alarm then self.alarm:Hide() end
	if self.edgeColor ~= Skin.colors.metal then
		self.edgeColor = Skin.colors.metal
		UI.SetBorder(self.owner, self.edgeColor)
	end
	if self.brackets then
		for _, bracket in ipairs(self.brackets) do bracket:SetAlpha(0) end
	end
	self.owner:SetAlpha(1)
end

-- Room at the health bar's end for a party member's pet.
function Plate:PetTrim()
	local pet = self.petUnit
	if pet and ns.T.db.units.partypet and UnitExists(pet) then
		local sliver = L.LAYOUTS.sliver
		return sliver.width + sliver.gap
	end
	return nil
end

-- A party member's pet: a bar of its health at the end of its owner's cell, and a button to target it.

local Sliver = {}
Sliver.__index = Sliver

local PET = { 0.2, 0.8, 0.15 }
local SOLID = "Interface\\Buttons\\WHITE8X8"

function P.CreateSliver(owner)
	local self = setmetatable({ owner = owner }, Sliver)
	local bar = CreateFrame("StatusBar", nil, owner)
	bar:SetAllPoints()
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture(SOLID)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local r, g, b, mr, mg, mb = Units.Tone(PET[1], PET[2], PET[3])
	bar:SetStatusBarColor(r, g, b)
	bar.trough = bar:CreateTexture(nil, "BACKGROUND")
	bar.trough:SetAllPoints()
	bar.trough:SetColorTexture(mr, mg, mb, MISSING_ALPHA)
	self.bar = bar
	self.events = CreateFrame("Frame", nil, owner)
	self.events:SetScript("OnEvent", function() self:Update() end)
	return self
end

function Sliver:SetUnit(unit)
	self.unit = unit
	local events = self.events
	events:UnregisterAllEvents()
	events:RegisterUnitEvent("UNIT_HEALTH", unit)
	events:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
	events:RegisterEvent("UNIT_PET")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:Update()
end

function Sliver:Update()
	local unit = self.unit
	if not unit or not UnitExists(unit) then return end
	Fill(self.bar, UnitHealth(unit), UnitHealthMax(unit))
end

function Sliver:Arrange()
end
