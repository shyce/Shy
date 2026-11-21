-- As good as dead: what your damage over time still has to deal (ShyDots), on the target's, the focus's and
-- the target's target's health bar. From the fill's end back toward the bar's start, one segment a spell in
-- its school's color, as long as what that spell still has to deal; once they reach the start a check lights on
-- the bar's start, a mark on its edge: move on. The name never moves for it (whether it is lit may be the game's
-- secret, so making room for it would leave a gap while it is dark).
-- Health is secret in a fight, so the game does the comparing: each segment is a bar filled from the right
-- whose most is the unit's most health and whose value is the damage coming, the first hung on the fill's
-- end and each next on the one before it; the check rides the end of a long bar whose most is the health
-- left and whose value is the damage coming, in a window that shows only the bar's last few units, so it
-- comes into view only when the damage reaches the health.
-- Every piece is anchored to the fill's own corners and sized in whole units, so nothing lands between pixels.

local ADDON, ns = ...
local L = ns.Layout
local UI, Theme = Shy.UI, Shy.Theme
local Secret = ns.Units.Secret

local SOLID = "Interface\\Buttons\\WHITE8X8"
local CHECK = 10          -- the check's size
local REACH = 2000        -- the long bar the check rides
local SEGS = 4            -- segments a bar; more spells than that join the last
local ALPHA = 0.7         -- a segment over the fill
local DEEP = 0.88         -- a segment's color is its school's, this much of it, so the live fill stays the brightest
local SEAM = 1            -- the dark line at a segment's far end
local ENEMIES = { target = true, focus = true, targettarget = true }
local EDGE = -1           -- the check's middle from the bar's start: on the frame's edge, clear of the name

local function Build(self)
	local health = self.bars.health   -- clips its children already (incoming heals)
	local segs = {}
	for i = 1, SEGS do
		local seg = CreateFrame("StatusBar", nil, health)
		seg:SetStatusBarTexture(SOLID)
		seg:SetReverseFill(true)
		seg:SetFrameLevel(self.owner:GetFrameLevel() + ns.Plate.LEVELS.doom)   -- over the incoming heals, under the marks
		if i == 1 then
			seg:SetPoint("TOPRIGHT", health.fill, "TOPRIGHT", 0, 0)
			seg:SetPoint("BOTTOMRIGHT", health.fill, "BOTTOMRIGHT", 0, 0)
		else
			seg:SetPoint("TOPRIGHT", segs[i - 1].fill, "TOPLEFT", 0, 0)
			seg:SetPoint("BOTTOMRIGHT", segs[i - 1].fill, "BOTTOMLEFT", 0, 0)
		end
		seg:SetMinMaxValues(0, 1)
		seg:SetValue(0)
		seg.fill = seg:GetStatusBarTexture()
		seg.seam = seg:CreateTexture(nil, "OVERLAY")
		seg.seam:SetColorTexture(0, 0, 0, 0.6)
		seg.seam:SetWidth(SEAM)
		seg.seam:SetPoint("TOPLEFT", seg.fill, "TOPLEFT", 0, 0)
		seg.seam:SetPoint("BOTTOMLEFT", seg.fill, "BOTTOMLEFT", 0, 0)
		seg:Hide()
		segs[i] = seg
	end

	local gate = CreateFrame("Frame", nil, self.overlay)
	gate:SetSize(CHECK, CHECK)
	gate:SetPoint("CENTER", health, "LEFT", EDGE, 0)
	gate:SetClipsChildren(true)
	gate:Hide()
	local meter = CreateFrame("StatusBar", nil, gate)
	meter:SetSize(REACH, CHECK)
	meter:SetPoint("RIGHT", gate, "RIGHT", 0, 0)
	meter:SetStatusBarTexture(SOLID)
	meter:SetStatusBarColor(0, 0, 0, 0)
	meter:SetMinMaxValues(0, 1)
	meter:SetValue(0)
	local fill = meter:GetStatusBarTexture()
	local light = meter:CreateTexture(nil, "ARTWORK")
	light:SetTexture(Shy.Brand.GLOW)
	light:SetBlendMode("ADD")
	light:SetSize(CHECK * 2, CHECK * 2)
	light:SetPoint("CENTER", fill, "RIGHT", -CHECK / 2, 0)
	local check = meter:CreateTexture(nil, "OVERLAY")
	check:SetTexture(Shy.MEDIA .. "GlyphCheckS")   -- drawn for 12 units and under
	check:SetSize(CHECK, CHECK)
	check:SetPoint("RIGHT", fill, "RIGHT", 0, 0)
	self.doom = { segs = segs, gate = gate, meter = meter, check = check, light = light }

	local c = UI.colors.good
	check:SetVertexColor(c[1], c[2], c[3])
	light:SetVertexColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
end

-- Shown while something is coming on an enemy; the bars get the health raw.
local function UpdateDoom(self)
	local doom = self.doom
	if not doom then return end
	local unit, dots = self.unit, Shy.addons.Dots
	local list, total
	if unit and ns.T.db.doom and dots and dots:IsOn() and UnitCanAttack("player", unit) then list, total = dots:BreakdownOn(unit) end
	local shown = list ~= nil
	local was = doom.gate:IsShown()
	if shown ~= was then doom.gate:SetShown(shown) end
	local used = 0
	if shown then
		local max, hp = UnitHealthMax(unit), UnitHealth(unit)
		local dead = not Secret(max) and max == 0
		used = math.min(#list, SEGS)
		for i = 1, used do
			local coming = list[i].coming
			if i == used then
				for j = used + 1, #list do coming = coming + list[j].coming end
			end
			local seg = doom.segs[i]
			local r, g, b = Theme.School(list[i].school)
			seg:SetStatusBarColor(r * DEEP, g * DEEP, b * DEEP, ALPHA)
			if dead then
				seg:SetMinMaxValues(0, 1)
				seg:SetValue(0)
			else
				seg:SetMinMaxValues(0, max)
				seg:SetValue(coming)
			end
		end
		if dead then
			doom.meter:SetMinMaxValues(0, 1)
			doom.meter:SetValue(0)
		else
			doom.meter:SetMinMaxValues(0, hp)
			doom.meter:SetValue(total)
		end
	end
	-- Asked on every change of the unit's health: the segments are told only when how many show changes.
	if used ~= doom.used then
		doom.used = used
		for i, seg in ipairs(doom.segs) do seg:SetShown(i <= used) end
	end
end

-- Woven into the plates' class once the first is made: sized with the plate, updated with its health.
local woven = false
local function Weave(class)
	if woven then return end
	woven = true
	local arrange, updateHealth = class.Arrange, class.UpdateHealth
	class.UpdateDoom = UpdateDoom
	function class:Arrange()
		arrange(self)
		if self.doom then
			for _, seg in ipairs(self.doom.segs) do seg:SetWidth(self.rects.health[3]) end
		end
	end
	function class:UpdateHealth()
		updateHealth(self)
		UpdateDoom(self)
	end
end

local create = ns.Plate.Create
function ns.Plate.Create(owner, kind)
	local self = create(owner, kind)
	Weave(getmetatable(self))
	if ENEMIES[kind] then Build(self) end
	return self
end

-- Said for one mob at a time: only the frames showing it (or that can't be told apart) are drawn again.
local function Told(guid)
	local all = guid == nil or Secret(guid)
	for _, frame in ipairs(ns.Frames.list) do
		local plate = frame.plate
		if plate and plate.doom and plate.unit then
			if all then
				UpdateDoom(plate)
			else
				local shows = UnitGUID(plate.unit)
				if Secret(shows) or shows == guid then UpdateDoom(plate) end
			end
		end
	end
end
Shy:On("SHY_DOTS", Told)

-- The switch was flipped: every frame that can carry the marks reads again.
function ns.Doom()
	Told()
end
