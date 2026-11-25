-- ShyTip: default tooltips placed at the cursor, hidden instantly, recolored, and unit tooltips colored by class or reaction.
-- Only NineSlice center and border colors are set. Blizzard resets them on hide and in
-- SharedTooltip_SetBackdropStyle, so they are re-applied there. Wing.lua shows the content in a hover card instead.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyTip\\Media\\"
local UI, Skin = Shy.UI, Shy.Skin

local T = Shy:NewAddon(ADDON, {
	suffix = "Tip",
	category = "interface",
	icon = MEDIA .. "ShyTip",
	smallIcon = MEDIA .. "ShyTipSmall",
	savedVariables = "ShyTipDB",
	defaults = {
		-- position
		enabled = true,          -- anchor default tooltips to the cursor
		follow = true,           -- keep tracking the cursor while shown
		point = "BOTTOMLEFT",    -- which corner of the tooltip sits at the cursor
		x = 16,
		y = 8,
		scale = 1,
		-- hiding
		instantHide = true,      -- no fade out when the mouse leaves a unit
		hideInCombat = false,
		hideOnTarget = true,     -- none over the unit you have targeted
		-- look
		replace = true,          -- hover cards replace default tooltips (Wing.lua)
		emotes = true,           -- thank, wave and the other emotes in a unit frame's right-click menu (Unit.lua)
		strip = false,           -- pings and raid markers for your target, with Shift held (Strip.lua): yours to find and turn on
		shyLook = true,          -- graphite background and steel border on default tooltips
		customBg = false,        -- custom background color
		font = "default",
		-- unit colors
		theme = true,
		colorBy = "smart",       -- smart | reaction | class
		colorBorder = true,
		colorName = true,
		colorHealth = true,
		bgTint = 0.15,
		specialBorder = true,    -- elites, rares and bosses get their own border
		grayTapped = true,
		danger = true,           -- mark dangerous mobs
		colors = {
			hostile   = { 1.00, 0.27, 0.27 },
			neutral   = { 1.00, 0.85, 0.25 },
			friendly  = { 0.35, 1.00, 0.40 },
			tapped    = { 0.55, 0.55, 0.55 },
			elite     = { 1.00, 0.78, 0.20 },
			rare      = { 0.78, 0.84, 0.95 },
			rareelite = { 0.72, 0.45, 1.00 },
			worldboss = { 1.00, 0.45, 0.10 },
			background = { 0, 0, 0 },
		},
	},
})
ns.T = T

ns.POINTS = {
	"TOPLEFT", "TOP", "TOPRIGHT",
	"LEFT", "CENTER", "RIGHT",
	"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}
ns.OFFSET = 100   -- the furthest a tooltip stands from the cursor, either way

-- font: the Latin file. cyrillic: the file for Cyrillic names, where the font has a cut for them.
ns.FONTS = {
	{ value = "default",  text = "Game default" },
	{ value = "shy",      text = "Lilita One",       font = Shy.FONT, cyrillic = Shy.FONT_ROUNDED },
	{ value = "friz",     text = "Friz Quadrata",    font = "Fonts\\FRIZQT__.TTF", cyrillic = "Fonts\\FRIZQT___CYR.TTF" },
	{ value = "arialn",   text = "Arial Narrow",     font = "Fonts\\ARIALN.TTF", cyrillic = "Fonts\\ARIALN.TTF" },
	{ value = "morpheus", text = "Morpheus",         font = "Fonts\\MORPHEUS.TTF", cyrillic = "Fonts\\MORPHEUS_CYR.ttf" },
	{ value = "skurri",   text = "Skurri",           font = "Fonts\\SKURRI.TTF" },
}

-- Restyled from load. Any other tooltip is picked up the first time the game styles it (Adopt).
local DRESSED = {
	"GameTooltip", "ItemRefTooltip",
	"ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
}

local db
local defaultAnchored = setmetatable({}, { __mode = "k" })  -- tooltips placed by GameTooltip_SetDefaultAnchor
local hooked = {}
-- tooltip -> { center, border = Blizzard's colors; dressed = ours are on; unit = unit colors on; health = unit bar color }
local looks = setmetatable({}, { __mode = "k" })

-- Position

-- Placed again each frame it follows the mouse, but only moved when the mouse (or the setting) has:
-- a tooltip over a mob you stand still at is left where it is. `again`: the game has just placed it.
local placed = setmetatable({}, { __mode = "k" })   -- tooltip -> { x, y, scale, point, dx, dy } it was put at

local function PlaceAtCursor(tip, again)
	local x, y = GetCursorPosition()
	local scale = tip:GetEffectiveScale()
	local at = placed[tip]
	if not again and at and at[1] == x and at[2] == y and at[3] == scale and at[4] == db.point and at[5] == db.x and at[6] == db.y then
		return
	end
	if not at then
		at = {}
		placed[tip] = at
	end
	at[1], at[2], at[3], at[4], at[5], at[6] = x, y, scale, db.point, db.x, db.y
	tip:ClearAllPoints()
	tip:SetPoint(db.point, UIParent, "BOTTOMLEFT", x / scale + db.x, y / scale + db.y)
end

-- Look: border, background, name and health bar colors

local function SetBorder(tip, r, g, b, a)
	tip.NineSlice:SetBorderColor(r, g, b, a or 1)
end

local function SetCenter(tip, r, g, b, a)
	tip.NineSlice:SetCenterColor(r, g, b, a or 1)
end

-- Captures Blizzard's colors on first use so they can be restored.
local function Look(tip)
	local l = looks[tip]
	if not l then
		local nine = tip.NineSlice
		l = { center = { nine:GetCenterColor() }, border = { nine:GetBorderColor() } }
		looks[tip] = l
	end
	return l
end

-- Custom color or graphite; opacity comes from Theme.TipStrength, darker than panels because tooltips sit over text.
local function BaseColor()
	return (db.customBg and db.colors.background) or (db.shyLook and UI.colors.panel) or nil
end

local function BaseCenter(l)
	local c = BaseColor()
	if c then return c[1], c[2], c[3], Shy.Theme.TipStrength() end
	return unpack(l.center)
end

-- UI.Frost texture inside the border, under the tooltip's own center piece.
local FROST_INSET = 4

local function Frost(tip, l)
	local c = BaseColor()
	if not c then
		if l.frost then l.frost:Hide() end
		return
	end
	if not l.frost then
		l.frost = tip:CreateTexture(nil, "BACKGROUND", nil, -8)
		l.frost:SetPoint("TOPLEFT", FROST_INSET, -FROST_INSET)
		l.frost:SetPoint("BOTTOMRIGHT", -FROST_INSET, FROST_INSET)
	end
	UI.Frost(l.frost, { c[1], c[2], c[3] })
	l.frost:Show()
end

-- The border art is light grey, so it is tinted with Skin.colors.metal.
local function BaseBorder(l)
	if db.shyLook then
		local c = Skin.colors.metal
		return c[1], c[2], c[3], 1
	end
	return unpack(l.border)
end

-- Back to the base look. A tooltip never restyled is left untouched.
local function ResetLook(tip)
	local l = Look(tip)
	l.unit, l.health, l.class = nil, nil, nil
	l.edge, l.wash, l.danger = nil, nil, nil   -- read by Wing.lua through ns.LookOf
	if l.mark then l.mark:Hide() end
	local ours = db.shyLook or db.customBg
	if ours or l.dressed then
		SetBorder(tip, BaseBorder(l))
		SetCenter(tip, BaseCenter(l))
		Frost(tip, l)
		l.dressed = ours or nil
	end
end

local function Color(key)
	local c = db.colors[key]
	return c[1], c[2], c[3]
end

local function ReactionColor(unit)
	local reaction = UnitReaction(unit, "player")
	if not reaction then return end
	if reaction <= 3 then return Color("hostile") end
	if reaction == 4 then return Color("neutral") end
	return Color("friendly")
end

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then return color:GetRGB() end
end

-- r, g, b, and true when that is their class's color.
local function UnitColor(unit)
	if db.grayTapped and UnitIsTapDenied(unit) then return Color("tapped") end
	local isPlayer = UnitIsPlayer(unit)
	if db.colorBy == "reaction" then return ReactionColor(unit) end
	if isPlayer then
		local r, g, b = ClassColor(unit)
		if r then return r, g, b, true end
	end
	if db.colorBy == "smart" then return ReactionColor(unit) end
end

local SPECIAL = { elite = true, rare = true, rareelite = true, worldboss = true }

local function StyleUnit(tip, unit)
	local l = Look(tip)  -- capture before recoloring
	l.unit = true
	local r, g, b, classed = UnitColor(unit)
	-- Their class's color, for the card's plate: an ally's name wears it there (Unit.lua).
	l.class = classed and { r, g, b } or nil

	local br, bg, bb
	if db.colorBorder then br, bg, bb = r, g, b end
	local class = UnitClassification(unit)
	if db.specialBorder and SPECIAL[class] then br, bg, bb = Color(class) end
	if br then
		SetBorder(tip, br, bg, bb, 1)
		l.dressed = true
		l.edge = { br, bg, bb }
	end

	if not r then return end
	if db.colorName then tip.TextLeft1:SetTextColor(r, g, b) end
	if db.bgTint > 0 then
		local cr, cg, cb, ca = BaseCenter(l)
		local t = db.bgTint
		SetCenter(tip, cr + (r - cr) * t, cg + (g - cg) * t, cb + (b - cb) * t, ca)
		l.dressed = true
		l.wash = { r, g, b, t }
	end
	if db.colorHealth then
		l.health = { r, g, b }
		tip.StatusBar:SetStatusBarColor(r, g, b)
	end
end

-- Danger mark: corner brackets and a light crossing the top edge of a dangerous mob's tooltip,
-- plus its level recolored with the level gap beside it. The colors are fixed, not options.

local STEEP, DIRE, OUTGROWN = 3, 5, 5   -- levels above you for grade 1 and grade 2; levels below you where nothing is marked
local CAUTION, DANGER = { 1.00, 0.54, 0.24 }, { 1.00, 0.23, 0.18 }
local PACE = { { 3.4, 1.9 }, { 2.0, 1.1 }, { 1.5, 0.8 } }   -- by grade: seconds per cycle, seconds per crossing
-- The tooltip border is a 1-unit line 2 units in from the frame; the mark sits just outside it.
local BRACKET, THICK, INSET = 9, 1.6, 0.4   -- bracket arm length, thickness, inset from the corner
local LIGHT_W = 40
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local SKULL = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:0|t"

-- Returns grade 1 to 3 (nil for none), level, and levels above you (nil for a skull level). Unit values can be secret.
local function Danger(unit)
	local can, dead = UnitCanAttack("player", unit), UnitIsDead(unit)
	if issecretvalue(can) or issecretvalue(dead) or not can or dead then return end
	local level, class = UnitLevel(unit), UnitClassification(unit)
	if issecretvalue(level) or issecretvalue(class) or type(level) ~= "number" then return end
	if level <= 0 or class == "worldboss" then return 3, level end
	local above = level - UnitLevel("player")
	if above <= -OUTGROWN then return end
	local special = SPECIAL[class]
	if above >= DIRE or (special and above >= STEEP) then return 2, level, above end
	if above >= STEEP or special then return 1, level, above end
end

local function Lit(c, white)
	return c[1] + (1 - c[1]) * white, c[2] + (1 - c[2]) * white, c[3] + (1 - c[3]) * white
end

-- Moves the light across the top edge, then parks it off the clip until the next cycle.
local function Run(self)
	local t = (GetTime() - self.since) % self.cycle
	local span = self.clip:GetWidth() + LIGHT_W
	self.light:SetPoint("LEFT", self.clip, "LEFT", math.min(t / self.crossing, 1) * span - LIGHT_W, 0)
end

-- The bars' thickness in whole pixels at the tooltip's scale, so they stay crisp.
local function Thick(m, tip)
	local scale = tip:GetEffectiveScale()
	if m.scale == scale then return end
	m.scale = scale
	local thick = PixelUtil.GetNearestPixelSize(THICK, scale, 1)
	for i, bar in ipairs(m.brackets) do
		if i % 2 == 1 then bar:SetSize(BRACKET, thick) else bar:SetSize(thick, BRACKET) end
	end
	m.clip:SetHeight(thick)
	m.light:SetSize(LIGHT_W, thick)
end

-- Builds the mark once per tooltip: two bars per corner and a clipped strip for the light.
local function Mark(tip)
	local l = Look(tip)
	if l.mark then return l.mark end
	local m = CreateFrame("Frame", nil, tip)
	m:SetAllPoints()
	m.scale = tip:GetEffectiveScale()
	local thick = PixelUtil.GetNearestPixelSize(THICK, m.scale, 1)   -- whole pixels, so the bars stay crisp
	m.brackets = {}
	for i, corner in ipairs(CORNERS) do
		local x, y = i % 2 == 1 and INSET or -INSET, i <= 2 and -INSET or INSET
		local across, down = m:CreateTexture(nil, "OVERLAY"), m:CreateTexture(nil, "OVERLAY")
		across:SetSize(BRACKET, thick)
		down:SetSize(thick, BRACKET)
		across:SetPoint(corner, x, y)
		down:SetPoint(corner, x, y)
		m.brackets[#m.brackets + 1] = across
		m.brackets[#m.brackets + 1] = down
	end
	m.clip = CreateFrame("Frame", nil, m)
	m.clip:SetPoint("TOPLEFT", BRACKET + INSET, -INSET)
	m.clip:SetPoint("TOPRIGHT", -BRACKET - INSET, -INSET)
	m.clip:SetHeight(thick)
	m.clip:SetClipsChildren(true)
	m.light = CreateFrame("Frame", nil, m.clip)
	m.light:SetSize(LIGHT_W, thick)
	m.light:SetPoint("LEFT", m.clip, "LEFT", -LIGHT_W, 0)   -- off the clip; Run moves it
	m.rise, m.fall = m.light:CreateTexture(nil, "OVERLAY"), m.light:CreateTexture(nil, "OVERLAY")
	m.rise:SetPoint("TOPLEFT")
	m.rise:SetPoint("BOTTOMRIGHT", m.light, "BOTTOM")
	m.fall:SetPoint("TOPLEFT", m.light, "TOP")
	m.fall:SetPoint("BOTTOMRIGHT")
	for _, t in ipairs({ m.rise, m.fall }) do
		t:SetColorTexture(1, 1, 1)
		t:SetBlendMode("ADD")
	end
	m.hid = -1
	m:Hide()
	m:SetScript("OnHide", function(self) self.hid = GetTime() end)
	m:SetScript("OnUpdate", Run)
	l.mark = m
	return m
end

-- Shows the mark in the grade's color and returns that color.
local function Arm(tip, grade)
	local m = Mark(tip)
	local c = grade == 1 and CAUTION or DANGER
	Thick(m, tip)
	-- A unit tooltip is written again while hovered: its colors are only set when the grade changes.
	if m.grade ~= grade then
		m.grade = grade
		local r, g, b = Lit(c, 0.3)
		for _, t in ipairs(m.brackets) do t:SetColorTexture(r, g, b) end
		r, g, b = Lit(c, 0.6)
		local faint, lit = CreateColor(c[1], c[2], c[3], 0), CreateColor(r, g, b, 1)
		m.rise:SetGradient("HORIZONTAL", faint, lit)
		m.fall:SetGradient("HORIZONTAL", lit, faint)
	end
	m.cycle, m.crossing = PACE[grade][1], PACE[grade][2]
	-- A unit tooltip is rebuilt while hovered: only restart the light for a newly opened one.
	if not m:IsShown() and GetTime() - m.hid > 0.1 then m.since = GetTime() end
	m:Show()
	return c
end

-- Recolors the level in the level line and puts the gap ("+5") or a skull at its right.
local function LevelLine(tip, level, above, color)
	local name = tip:GetName()
	local text = level > 0 and tostring(level) or "??"
	local find = TOOLTIP_UNIT_LEVEL:format(text)
	for i = 2, tip:NumLines() do
		local left = _G[name .. "TextLeft" .. i]
		local said = left and left:GetText()
		if not issecretvalue(said) and said then
			local from, to = said:find(find, 1, true)
			if from then
				left:SetText(said:sub(1, from - 1) .. TOOLTIP_UNIT_LEVEL:format(UI.Wrap(color, text)) .. said:sub(to + 1))
				local gap = (level <= 0 and SKULL) or (above and above > 0 and ("+" .. above))
				local right = gap and _G[name .. "TextRight" .. i]
				if right then
					right:SetText(gap)
					right:SetTextColor(color[1], color[2], color[3])
					right:Show()
				end
				return
			end
		end
	end
end

local function Warn(tip, unit)
	local grade, level, above = Danger(unit)
	if not grade then return end
	local l = Look(tip)
	l.unit = true
	local color = Arm(tip, grade)
	l.danger = { color = { Lit(color, 0.3) }, pace = PACE[grade][1], base = color, above = above }
	LevelLine(tip, level, above, color)
end

-- For Wing.lua: a tooltip's unit colors (edge, wash, health, danger), and whether it is hidden in combat.
function ns.LookOf(tip)
	return looks[tip]
end

-- The world tooltip of the unit under the mouse when that unit is your target. The target frame's own
-- tooltip is another unit token and still shows; a secret answer shows it too.
local function OverTarget(tip)
	if not db.hideOnTarget then return false end
	local _, unit = tip:GetUnit()
	if issecretvalue(unit) or unit ~= "mouseover" then return false end
	local same = UnitIsUnit("mouseover", "target")
	return not issecretvalue(same) and same == true
end

function ns.Hushed(tip)
	if db == nil or defaultAnchored[tip] ~= true then return false end
	return (db.hideInCombat and InCombatLockdown()) or OverTarget(tip)
end

-- What another addon says of the unit in a tooltip, for its plate (Unit.lua). Forgotten when the
-- tooltip is cleared.
--   about = { tag = { ... } }   the mark its nameplate carries, in ShyPlates' tag form
local glances = setmetatable({}, { __mode = "k" })

function ns.GlanceOf(tip)
	return glances[tip]
end

-- MarksDanger: ShyQuest skips its own danger warning while this is on. Compares: an item's card shows what it would
-- replace, each stat's change and its worth (Compare.lua): ShyGear's line then says only its verdict.
Shy.Tip = {
	MarksDanger = function() return db ~= nil and db.danger == true end,
	Compares = function() return db ~= nil and db.replace == true and ns.Compare ~= nil end,
	Glance = function(tip, about) glances[tip] = about end,
}

local function OnTooltipUnit(tip)
	if tip ~= GameTooltip or not db or not (db.theme or db.danger) then return end
	local _, unit = tip:GetUnit()
	-- The unit can be secret; unit functions can also error on a readable one, hence the pcall.
	if issecretvalue(unit) or not unit then return end
	if db.theme then pcall(StyleUnit, tip, unit) end
	if db.danger then pcall(Warn, tip, unit) end
end

-- Fonts and scale

-- The tooltip's font objects are families: one file per alphabet, so a name in Cyrillic, Korean or
-- Chinese draws beside Latin text. Setting one file on them would drop the other alphabets, so a
-- chosen font is a family too: its Latin file, its Cyrillic cut (or the game's) and the game's
-- Korean and Chinese files. The game's own font object is kept as a copy for "Game default".
local FONT_OBJECTS = { "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }
local CYRILLIC = "Fonts\\FRIZQT___CYR.TTF"
local kept = {}

local function Family(choice, original)
	local _, height, flags = original:GetFont()
	local files = { roman = choice.font, russian = choice.cyrillic or CYRILLIC }
	return UI.NameFont(math.floor(height + 0.5), flags, files, "tip_" .. choice.value)
end

-- The font you picked, on the game's tooltip text.
function ns.Fonts()
	local choice
	for _, f in ipairs(ns.FONTS) do
		if f.value == db.font then choice = f end
	end
	for _, name in ipairs(FONT_OBJECTS) do
		local fo = _G[name]
		if fo then
			if not kept[name] then
				kept[name] = CreateFont("ShyTipKept" .. name)
				kept[name]:CopyFontObject(fo)
			end
			if choice and choice.font then
				-- A font object brings its own alignment and color: put the tooltip's back.
				local justify = fo:GetJustifyH()
				local r, g, b, a = fo:GetTextColor()
				fo:SetFontObject(Family(choice, kept[name]))
				fo:SetJustifyH(justify)
				fo:SetTextColor(r, g, b, a)
			else
				fo:CopyFontObject(kept[name])
			end
		end
	end
end

-- Every tooltip back to its base look. A unit's colors come again with its next tooltip.
function ns.Looks()
	for tip in pairs(looks) do ResetLook(tip) end
	-- Wing.lua may be missing until the client restarts.
	if ns.Wing then ns.Wing.Apply() end
end

function T:Apply()
	ns.Fonts()
	GameTooltip:SetScale(db.scale)
	ns.Looks()
	if ns.Strip then ns.Strip.Apply() end
end

-- Every setting as it shipped. (stripFound stays, or the next login would turn pings and markers off again.)
function ns.Reset()
	T:ResetDB()
	db.stripFound = true
	T:Apply()
end

-- Accent changed: recolor open tooltips, except a unit's, which is rebuilt on the next hover.
Shy:On("SHY_THEME", function()
	if not db then return end
	for tip, l in pairs(looks) do
		if not l.unit then ResetLook(tip) end
	end
end)

-- Hooks

local function HookTooltip(tip)
	if hooked[tip] then return end
	hooked[tip] = true
	-- Any later SetOwner means someone else chose an anchor.
	hooksecurefunc(tip, "SetOwner", function(self) defaultAnchored[self] = nil end)
	tip:HookScript("OnUpdate", function(self)
		if not defaultAnchored[self] then return end
		-- (Targeted while the mouse rests on it.)
		if OverTarget(self) then
			self:Hide()
			return
		end
		if db.enabled and db.follow then PlaceAtCursor(self) end
		if db.instantHide then
			-- The unit is secret in instances and combat; the default fade is kept then.
			local _, unit = self:GetUnit()
			if not issecretvalue(unit) and unit == "mouseover" then
				local exists = UnitExists("mouseover")
				if not issecretvalue(exists) and not exists then self:Hide() end
			end
		end
	end)
	tip:HookScript("OnShow", function(self)
		if ns.Hushed(self) then self:Hide() end
	end)
	tip:HookScript("OnHide", function(self) defaultAnchored[self] = nil end)
end

-- The default anchor calls SetOwner(parent, "ANCHOR_NONE") first, so this post-hook re-anchors after it.
hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip)
	if not db then return end
	HookTooltip(tip)
	defaultAnchored[tip] = true
	if db.enabled then PlaceAtCursor(tip, true) end
end)

function T:OnLoad()
	db = self.db
	-- Pings and markers start off, yours to find: a profile that kept them on from before they did is turned off
	-- once (stripFound); after that, on or off is yours.
	if not db.stripFound then
		db.strip = false
		db.stripFound = true
	end

	local function Adopt(tip)
		Look(tip)  -- capture Blizzard's colors first
		-- Blizzard may have reset the colors while hidden.
		tip:HookScript("OnShow", function(self)
			if not looks[self].unit then ResetLook(self) end
		end)
	end
	for _, name in ipairs(DRESSED) do Adopt(_G[name]) end
	-- Blizzard restores its colors here on every hide and style change. Other tooltips are adopted here
	-- too, unless forbidden or embedded (an embedded tooltip has no border).
	hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tip, _, embedded)
		if not looks[tip] then
			if tip:IsForbidden() or embedded or tip.IsEmbedded or not tip.NineSlice then return end
			Adopt(tip)
		end
		ResetLook(tip)
	end)

	Shy.OnTip(Enum.TooltipDataType.Unit, "a unit", OnTooltipUnit)
	GameTooltip:HookScript("OnTooltipCleared", ResetLook)
	GameTooltip:HookScript("OnTooltipCleared", function(tip) glances[tip] = nil end)
	-- Blizzard recolors the health bar as it updates; keep ours.
	GameTooltip.StatusBar:HookScript("OnValueChanged", function(bar)
		local c = looks[GameTooltip].health
		if c then bar:SetStatusBarColor(c[1], c[2], c[3]) end
	end)
	hooksecurefunc(GameTooltip, "FadeOut", function(self)
		if db.instantHide then self:Hide() end
	end)

	if ns.Wing then ns.Wing.Start() end
	if ns.Unit then ns.Unit.Start() end
	if ns.Strip then ns.Strip.Start() end
	self:Apply()
end

-- The danger mark is made as you log in, not on the hover of the first mob that needs it.
function T:OnLogin()
	if db.danger then pcall(Mark, GameTooltip) end
end

-- Commands: /shy tip <word>. Each tells the settings, so a row on show follows.

local CORNER = {}
for _, p in ipairs(ns.POINTS) do CORNER[p] = true end

local function OnOff(v) return v and "|cff40ff40on|r" or "|cffff4040off|r" end

-- Flips a switch, or sets it to `to`, and says so. after: what shows the change at once.
local function Switch(key, name, after, to)
	if to == nil then to = not db[key] end
	db[key] = to
	if after then after() end
	T:Print(name .. " " .. OnOff(to))
	Shy.Settings.Refresh()
end

local function Reach(v)
	return math.max(-ns.OFFSET, math.min(ns.OFFSET, math.floor(v + 0.5)))
end

T:Command("on", "tooltips show at your cursor", function() Switch("enabled", "cursor tooltips", nil, true) end)
T:Command("off", "tooltips show in the screen corner", function() Switch("enabled", "cursor tooltips", nil, false) end)
T:Command("toggle", nil, function() Switch("enabled", "cursor tooltips") end)
T:Command("follow", "the tooltip follows your cursor, or stays put", function() Switch("follow", "follow cursor") end)
T:Command("fade", "tooltips go at once, or fade out", function() Switch("instantHide", "instant hide") end)
T:Command("replace", "cards, or the default tooltips", function() Switch("replace", "cards", ns.Looks) end)
T:Command("look", "dark default tooltips, on or off", function() Switch("shyLook", "dark tooltips", ns.Looks) end)
T:Command("theme", "unit colors, on or off", function() Switch("theme", "unit colors", ns.Looks) end)
T:Command("danger", "the mark on dangerous mobs, on or off", function() Switch("danger", "danger mark", ns.Looks) end)
T:Command("anchor", "the corner that sits on your cursor, like: anchor topleft", function(rest)
	local point = rest:upper()
	if not CORNER[point] then
		T:Print("corners: " .. table.concat(ns.POINTS, ", "):lower())
		return
	end
	db.point = point
	T:Print("anchor set to " .. point:lower())
	Shy.Settings.Refresh()
end)
T:Command("offset", "how far from your cursor, across and up, like: offset 16 8", function(rest)
	local x, y = rest:match("^(%S+)%s+(%S+)$")
	x, y = tonumber(x), tonumber(y)
	if not (x and y) then
		T:Print("give two numbers, across and up: /shy tip offset 16 8")
		return
	end
	db.x, db.y = Reach(x), Reach(y)
	T:Print(("offset set to %d, %d"):format(db.x, db.y))
	Shy.Settings.Refresh()
end)
T:Command("reset", "every tooltip setting back to default", function()
	ns.Reset()
	T:Print("settings reset.")
	Shy.Settings.Refresh()
end)
