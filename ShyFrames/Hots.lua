-- Healing to come: what your heals over time still have to heal (ShyHots), on a friend's health bar. One
-- segment a spell, in its school's color (gold for a holy spell, green for nature's), as long as what that
-- spell still has to heal is of the friend's whole health: the first on the health's own end, always, so no
-- gap ever stands between the health and it (after a heal on its way, that heal's pale bar would read as a
-- gap); each next on the one before, each starting with a dark line; a heal on
-- its way comes after the last (Plate:HangHeals).
-- Each is one of the plate's heal bars (Plate:NewHeal), so what has no room past the health's end stands back
-- over it: at full health a heal over time is that much of the bar's end, and as health is lost it comes out
-- past the fill, the health's end always inside it.
-- Health is secret in a fight, so the game does the measuring: a segment's most is the unit's most health and
-- its value the healing coming, which is ShyHots' own count and plain. A tick taken eases off.
-- The test party wears a sample of it, in your own healing's color.

local ADDON, ns = ...
local Theme = Shy.Theme
local Secret = ns.Units.Secret

local SOLID = "Interface\\Buttons\\WHITE8X8"
local SEGS = 3            -- segments a bar; more spells than that join the last
local ALPHA = 0.78        -- a segment, over the missing health or the health itself
local DEEP = 0.92         -- a segment's color is its school's, this much of it
local SEAM = 1            -- the dark line a segment starts with
local SEAM_ALPHA = 0.6
local HOLY, NATURE = 2, 8
local SAMPLE_SCHOOL = { DRUID = NATURE, SHAMAN = NATURE }   -- the test party's: your class's healing; holy otherwise

local function Build(self)
	local segs = {}
	for i = 1, SEGS do
		local seg = self:NewHeal(SOLID)
		for _, bar in ipairs({ seg, seg.back }) do
			-- On the fill's near side: the end toward the health for the one past it, the leading end in the fold.
			local seam = bar:CreateTexture(nil, "OVERLAY")
			seam:SetColorTexture(0, 0, 0, SEAM_ALPHA)
			seam:SetWidth(SEAM)
			seam:SetPoint("TOPLEFT", bar.fill, "TOPLEFT", 0, 0)
			seam:SetPoint("BOTTOMLEFT", bar.fill, "BOTTOMLEFT", 0, 0)
		end
		segs[i] = seg
	end
	self.mend = { segs = segs, used = 0 }
	return self.mend
end

-- `list`: { { school, coming }, ... } oldest first, or nil; `max`: the unit's most health, as the game gives it.
local function Draw(self, list, max)
	local mend = self.mend
	local used = list and math.min(#list, SEGS) or 0
	if not Secret(max) and (max == nil or max <= 0) then used = 0 end
	if used == 0 and not mend then return end
	mend = mend or Build(self)
	local after
	-- A segment that was showing eases to its new length; never from whoever was in the frame before.
	local known = self.memory.mend == true
	for i = 1, used do
		local seg = mend.segs[i]
		local coming = list[i].coming
		if i == used then
			for j = used + 1, #list do coming = coming + list[j].coming end
		end
		self:HangHeal(seg, after)
		local school = list[i].school
		if seg.school ~= school then
			seg.school = school
			local r, g, b = Theme.School(school)
			self:ToneHeal(seg, r * DEEP, g * DEEP, b * DEEP, ALPHA)
		end
		self:FillHeal(seg, coming, max, known and i <= mend.used)
		after = seg
	end
	for i = used + 1, mend.used do self:DropHeal(mend.segs[i]) end
	mend.used = used
	-- A heal on its way starts where the last of these ends.
	if self.healStart ~= after then
		self.healStart = after
		self:HangHeals()
	end
	self.memory.mend = true
end

-- The test party's: a sample member's `hots` are amounts; their color is your own healing's.
local sampled = {}
local function SampleList(s)
	if not s.hots then return nil end
	local school = SAMPLE_SCHOOL[UnitClassBase("player")] or HOLY
	for i, coming in ipairs(s.hots) do
		local entry = sampled[i] or {}
		sampled[i] = entry
		entry.school, entry.coming = school, coming
	end
	for i = #s.hots + 1, #sampled do sampled[i] = nil end
	return sampled
end

-- Shown while something is coming on a friend; the bars get the health raw.
local function UpdateMend(self)
	local unit = self.unit
	if not unit or not self.heals then return end
	local on = ns.T.db.mend
	local s = self.sample
	if s and not UnitExists(unit) then return Draw(self, on and SampleList(s) or nil, s.max) end
	local hots = Shy.addons.Hots
	local list
	if on and hots and hots:IsOn() and not UnitCanAttack("player", unit) then list = hots:BreakdownOn(unit) end
	if not list and not self.mend then return end
	Draw(self, list, UnitHealthMax(unit))
end

-- Woven into the plates' class once the first is made: sized with the plate, updated with its heals, worn
-- by a sample.
local woven = false
local function Weave(class)
	if woven then return end
	woven = true
	local arrange, updateHeals, sample = class.Arrange, class.UpdateHeals, class.Sample
	class.UpdateMend = UpdateMend
	function class:Arrange()
		arrange(self)
		if self.mend then
			for _, seg in ipairs(self.mend.segs) do self:SizeHeal(seg, self.rects.health) end
		end
	end
	function class:UpdateHeals()
		updateHeals(self)
		UpdateMend(self)
	end
	function class:Sample(s)
		sample(self, s)
		UpdateMend(self)
	end
end

local create = ns.Plate.Create
function ns.Plate.Create(owner, kind)
	local self = create(owner, kind)
	Weave(getmetatable(self))
	return self
end

-- Said for one friend at a time: only the frames showing them (or that can't be told apart) are drawn again.
Shy:On("SHY_HOTS", function(guid)
	local all = guid == nil or Secret(guid)
	for _, frame in ipairs(ns.Frames.list) do
		local plate = frame.plate
		if plate and plate.heals and plate.unit then
			if all then
				UpdateMend(plate)
			else
				local shows = UnitGUID(plate.unit)
				if Secret(shows) or shows == guid then UpdateMend(plate) end
			end
		end
	end
end)
