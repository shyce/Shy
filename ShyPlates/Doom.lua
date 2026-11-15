-- As good as dead: what your damage over time still has to deal (ShyDots), drawn on the health bar.
-- From the fill's end back toward the bar's start, one segment a spell in its school's color, as long as
-- what that spell still has to deal; once they reach the start a check lights at the bar's start: move on.
-- Health is secret in a fight, so the game does the comparing: each segment is a bar filled from the right
-- whose most is the unit's most health and whose value is the damage coming, the first hung on the fill's
-- end and each next on the one before it; the check rides the end of a long bar whose most is the health
-- left and whose value is the damage coming, in a window that shows only the bar's last few units, so it
-- comes into view only when the damage reaches the health.
-- Every piece is anchored to the fill's own corners and sized in whole units, so nothing lands between pixels.

local ADDON, ns = ...
local L = ns.Layout
local UI, Theme = Shy.UI, Shy.Theme

local Doom = {}
ns.Doom = Doom

local SOLID = "Interface\\Buttons\\WHITE8X8"
local DEEP = 0.88   -- a segment's color is its school's, this much of it, so the live fill stays the brightest

function Doom.Build(plate)
	local health = plate.health
	health:SetClipsChildren(true)   -- the segments stop at the bar's start

	local segs = {}
	for i = 1, L.DOOM_SEGS do
		local seg = CreateFrame("StatusBar", nil, health)
		seg:SetStatusBarTexture(SOLID)
		seg:SetReverseFill(true)
		seg:SetFrameLevel(health:GetFrameLevel() + 1)
		-- The first on the fill's right end, each next on the far end of the one before.
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
		-- The seam at its far end.
		seg.seam = seg:CreateTexture(nil, "OVERLAY")
		seg.seam:SetColorTexture(0, 0, 0, 0.6)
		seg.seam:SetWidth(L.DOOM_SEAM)
		seg.seam:SetPoint("TOPLEFT", seg.fill, "TOPLEFT", 0, 0)
		seg.seam:SetPoint("BOTTOMLEFT", seg.fill, "BOTTOMLEFT", 0, 0)
		seg:Hide()
		segs[i] = seg
	end

	-- The window at the bar's start, the long bar in it, and the check on that bar's fill.
	local gate = CreateFrame("Frame", nil, plate.over)
	gate:SetSize(L.DOOM, L.DOOM)
	gate:SetPoint("LEFT", health, "LEFT", L.INSET, 0)
	gate:SetClipsChildren(true)
	gate:Hide()
	local meter = CreateFrame("StatusBar", nil, gate)
	meter:SetSize(L.DOOM_REACH, L.DOOM)
	meter:SetPoint("RIGHT", gate, "RIGHT", 0, 0)
	meter:SetStatusBarTexture(SOLID)
	meter:SetStatusBarColor(0, 0, 0, 0)
	meter:SetMinMaxValues(0, 1)
	meter:SetValue(0)
	local fill = meter:GetStatusBarTexture()
	local light = meter:CreateTexture(nil, "ARTWORK")
	light:SetTexture(Shy.Brand.GLOW)
	light:SetBlendMode("ADD")
	light:SetSize(L.DOOM * 2, L.DOOM * 2)
	light:SetPoint("CENTER", fill, "RIGHT", -L.DOOM / 2, 0)
	local check = meter:CreateTexture(nil, "OVERLAY")
	check:SetTexture(Shy.MEDIA .. "GlyphCheckS")   -- drawn for 12 units and under
	check:SetSize(L.DOOM, L.DOOM)
	check:SetPoint("RIGHT", fill, "RIGHT", 0, 0)
	plate.doom = { segs = segs, gate = gate, meter = meter, check = check, light = light }
	Doom.Paint(plate)
end

function Doom.Arrange(plate)
	for _, seg in ipairs(plate.doom.segs) do seg:SetWidth(L.Fill(plate.width)) end
end

function Doom.Paint(plate)
	local c = UI.colors.good
	plate.doom.check:SetVertexColor(c[1], c[2], c[3])
	plate.doom.light:SetVertexColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
end

-- Shown while something is coming on an enemy's full plate; the bars get the health raw.
function Doom.Update(plate)
	local R, unit, db, doom = plate.read, plate.unit, ns.T.db, plate.doom
	local list, total
	if unit and db.doom and plate.mode == "full" and R.CanAttack(unit) then list, total = R.Breakdown(unit) end
	local shown = list ~= nil
	-- Asked on every change of the unit's health: what shows is told only when it changes.
	if shown ~= doom.shown then
		doom.shown = shown
		doom.gate:SetShown(shown)
	end
	local used = 0
	if shown then
		used = R.FillDoom(doom, unit, list, total)
		for i = 1, used do
			local r, g, b = Theme.School(list[i].school)
			doom.segs[i]:SetStatusBarColor(r * DEEP, g * DEEP, b * DEEP, L.DOOM_ALPHA)
		end
	end
	if used ~= doom.used then
		doom.used = used
		for i, seg in ipairs(doom.segs) do seg:SetShown(i <= used) end
	end
end

function Doom.Clear(plate)
	-- Every plate let go of is cleared (each kill): only what shows is hidden.
	local doom = plate.doom
	if doom.shown ~= false then doom.gate:Hide() end
	if doom.used ~= 0 then
		for _, seg in ipairs(doom.segs) do seg:Hide() end
	end
	doom.shown, doom.used = false, 0
end
