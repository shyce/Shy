-- The XP bar widget: used in the stats window, under the action bars and on the quest window.
-- Layers: rested XP, what the whole quest log would add, what the quests ready to hand in add, the fill,
-- bubble dividers, a spark on each gain. The two quest bands start at the fill's end: the ready one reaches
-- where handing in would put you, the log's goes on from there to where every quest done would.
-- It shows what the bar is on (S.Mode): XP, or the reputation you track (the fill alone, through the
-- standing). bar.source = "xp" or "rep" holds it to one (over the game's own bar of that kind).

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local B, UI, Theme = Shy.Brand, Shy.UI, Shy.Theme

local BUBBLES = 20
local BAND = { rested = 0.3, ready = 0.6, log = 0.55 }   -- how solid each band is

ns.bars = setmetatable({}, { __mode = "k" })   -- every bar made, for the goal to reach them all

local function Rested() return B.Ramp(1) end

-- bare: no edge or ground of its own, the fill to its very edges (a frame round it draws them: Under.lua).
function ns.CreateXPBar(parent, bare)
	local bar = CreateFrame("Frame", nil, parent)
	local inset = bare and 0 or 1
	if not bare then UI.Skin(bar) end

	local function Band(sublevel)
		local t = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
		t:SetPoint("TOPLEFT", inset, -inset)
		t:SetPoint("BOTTOMLEFT", inset, inset)
		t:SetWidth(1)
		return t
	end
	bar.rested = Band(0)
	UI.Paint(bar.rested, Rested, BAND.rested)
	bar.log = Band(1)     -- colored in Update from logColor
	bar.log:Hide()
	bar.quest = Band(2)   -- colored in Update from questColor
	bar.quest:Hide()
	bar.fill = Band(3)
	Shy.Skin.Hatch(bar.fill)   -- the bars' fill of the theme's look, or the one picked, kept current by the kit
	UI.Tint(bar.fill, Theme.Accent)
	bar.tint = Theme.Accent   -- the fill's color: the accent for XP, a reputation's standing for it

	bar.gloss = bar:CreateTexture(nil, "ARTWORK", nil, 4)
	bar.gloss:SetTexture(UI.GLOSS)
	bar.gloss:SetAllPoints(bar.fill)

	bar.spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	bar.spark:SetAtlas("honorsystem-bar-spark")
	bar.spark:SetBlendMode("ADD")
	bar.spark:SetPoint("CENTER", bar.fill, "RIGHT")
	bar.spark:SetAlpha(0)

	bar.text = bar:CreateFontString(nil, "OVERLAY")
	UI.TitleFace(bar.text, 11, "OUTLINE")
	bar.text:SetPoint("CENTER", 0, 1)
	bar.text:Hide()

	-- The goal (ns.goal, xp:SetGoal: a guide's grind target): a tick where it stands on this level.
	bar.goal = bar:CreateTexture(nil, "OVERLAY", nil, 3)
	bar.goal:SetColorTexture(1, 1, 1, 0.9)
	bar.goal:SetWidth(2)
	bar.goal:Hide()
	ns.bars[bar] = true

	bar.bubbles = {}
	-- Laid out again only when the bar's size or the bubbles setting has changed.
	local laid = {}
	local function LayoutBubbles()
		local w, h = bar:GetWidth(), bar:GetHeight()
		if laid.w == w and laid.h == h and laid.on == T.db.bubbles then return end
		laid.w, laid.h, laid.on = w, h, T.db.bubbles
		bar.spark:SetSize(math.max(10, h * 1.4), h * 2.2)
		for i = 1, BUBBLES - 1 do
			local line = bar.bubbles[i]
			if not line then
				line = bar:CreateTexture(nil, "OVERLAY", nil, 1)
				line:SetColorTexture(0, 0, 0, 0.6)
				line:SetWidth(1)
				bar.bubbles[i] = line
			end
			line:ClearAllPoints()
			line:SetPoint("TOP", bar, "TOPLEFT", w * i / BUBBLES, -inset)
			line:SetPoint("BOTTOM", bar, "BOTTOMLEFT", w * i / BUBBLES, inset)
			line:SetShown(T.db.bubbles)
		end
	end
	-- The fill eases toward its targets on the bar's OnUpdate, which runs only while something moves
	-- (the fill, a gain's spark, a level's surge of color): a bar at rest costs nothing a frame.
	local Step
	function bar:Wake()
		self:SetScript("OnUpdate", Step)
	end
	bar:SetScript("OnSizeChanged", function(self)
		LayoutBubbles()
		self:Wake()
	end)

	-- Sets targets; OnUpdate eases the fill toward them.
	function bar:Update()
		if (self.source or S.Mode()) == "rep" then
			local into, span, data = ns.Rep.Progress()
			if not data then return end
			local _, color = ns.Rep.Standing(data.reaction)
			if self.tint ~= color then
				self.tint = color
				if not self.surge then UI.Tint(self.fill, color) end
			end
			self.target = into / span
			self.restedTarget, self.questTarget, self.logTarget = self.target, self.target, self.target
			self.goalShare = nil
			-- A standing gained: the fill starts again from empty, in a surge of color.
			if self.lastReaction and self.lastFaction == data.factionID and data.reaction > self.lastReaction then
				self.shown = 0
				self.surge = 2.5
				self.pulse = 1
			elseif self.lastStanding and self.lastFaction == data.factionID and data.currentStanding > self.lastStanding then
				self.pulse = 1
			elseif self.lastFaction ~= data.factionID then
				self.shown = nil
			end
			self.lastFaction, self.lastReaction, self.lastStanding = data.factionID, data.reaction, data.currentStanding
			self.lastXP, self.lastLevel = nil, nil
			LayoutBubbles()
			self:Wake()
			return
		end
		self.lastFaction, self.lastReaction, self.lastStanding = nil, nil, nil
		if self.tint ~= Theme.Accent then
			self.tint = Theme.Accent
			if not self.surge then UI.Tint(self.fill, Theme.Accent) end
		end
		local cur, max, level = S.Progress()
		local rested = GetXPExhaustion() or 0
		local ready, whole = (S.QuestXP()), (S.LogXP())
		self.target = cur / max
		self.restedTarget = math.min(1, (cur + rested) / max)
		self.questTarget = math.min(1, (cur + ready) / max)
		self.logTarget = math.min(1, (cur + whole) / max)
		local c, l = S.QuestColors()
		self.quest:SetColorTexture(c[1], c[2], c[3], BAND.ready)
		self.log:SetColorTexture(l[1], l[2], l[3], BAND.log)
		if self.lastLevel and level > self.lastLevel then
			self.shown = 0
			self.surge = 2.5
			self.pulse = 1
		elseif self.lastXP and cur > self.lastXP then
			self.pulse = 1
		end
		self.lastXP, self.lastLevel = cur, level
		local goal = ns.goal
		self.goalShare = goal and goal.level == level and goal.xp > cur and goal.xp <= max and goal.xp / max or nil
		LayoutBubbles()
		self:Wake()
	end

	function Step(self, dt)
		if not self.target then
			self:SetScript("OnUpdate", nil)
			return
		end
		self.shown = self.shown or self.target
		self.shown = self.shown + (self.target - self.shown) * math.min(1, dt * 6)
		-- Within a ten-thousandth of the way it is there (under a pixel on any bar).
		if math.abs(self.target - self.shown) < 0.0001 then self.shown = self.target end
		local width = self:GetWidth() - 2 * inset
		if width <= 0 then
			self:SetScript("OnUpdate", nil)
			return
		end
		self.fill:SetWidth(math.max(1, self.shown * width))
		self.rested:SetWidth(math.max(1, self.restedTarget * width))
		self.rested:SetShown(self.restedTarget > self.target)
		-- The ready band lies over the log's, so the log's shows only past it: what is still to be done.
		local bands = T.db.questOverlay
		self.quest:SetWidth(math.max(1, self.questTarget * width))
		self.quest:SetShown(bands and self.questTarget > self.target)
		self.log:SetWidth(math.max(1, self.logTarget * width))
		self.log:SetShown(bands and self.logTarget > self.questTarget)
		if self.goalShare then
			self.goal:ClearAllPoints()
			self.goal:SetPoint("TOP", self, "TOPLEFT", inset + self.goalShare * width, -inset)
			self.goal:SetPoint("BOTTOM", self, "BOTTOMLEFT", inset + self.goalShare * width, inset)
			self.goal:Show()
		else
			self.goal:Hide()
		end
		if self.pulse then
			self.pulse = self.pulse - dt * 1.5
			self.spark:SetAlpha(math.max(0, self.pulse))
			if self.pulse <= 0 then self.pulse = nil end
		end
		if self.surge then
			self.surge = self.surge - dt
			if self.surge > 0 then
				self.fill:SetVertexColor(B.Cycle(GetTime() * 1.6))
			else
				self.surge = nil
				UI.Tint(self.fill, self.tint)   -- re-bind to its color after the direct SetVertexColor
			end
		end
		if self.shown == self.target and not self.pulse and not self.surge then self:SetScript("OnUpdate", nil) end
	end
	bar:Wake()

	return bar
end

-- A bar's words in two parts, for its two ends: what it is, and how far along. "Level 23" | "64.2% · ~1h 12m to 24";
-- "Stormwind Honored" | "45.0% · 6,600 to Revered".
function ns.BarParts(source)
	local dot = "  \194\183  "
	if source == "rep" then
		local into, span, data = ns.Rep.Progress()
		if not data then return "", "" end
		local word, color = ns.Rep.Standing(data.reaction)
		local right = ("%.1f%%"):format(into / span * 100)
		local next_ = ns.Rep.Next(data.reaction)
		local eta = ns.Rep.TimeToNext()
		if next_ then right = right .. dot .. (eta and ("~" .. S.Duration(eta)) or S.Number(span - into)) .. " to " .. next_ end
		return data.name .. "  " .. UI.Wrap(color, word), right
	end
	local cur, max, level = S.Progress()
	local eta = S.TimeToLevel()
	local right = ("%.1f%%"):format(cur / max * 100) .. dot
		.. (eta and ("~" .. S.Duration(eta) .. " to " .. (level + 1)) or (S.Number(max - cur) .. " to go"))
	return "Level " .. level, right
end

-- "Level 23 · 64.2% · 7.2 bubbles to go · ~1h 12m"; "Stormwind · Honored 45.0% · 6,600 to Revered · ~2h"
function ns.BarText(source)
	if (source or S.Mode()) == "rep" then
		local into, span, data = ns.Rep.Progress()
		if not data then return "" end
		local parts = { data.name, ("%s %.1f%%"):format((ns.Rep.Standing(data.reaction)), into / span * 100) }
		local next_ = ns.Rep.Next(data.reaction)
		if next_ then parts[#parts + 1] = S.Number(span - into) .. " to " .. next_ end
		local eta = ns.Rep.TimeToNext()
		if eta then parts[#parts + 1] = "~" .. S.Duration(eta) end
		return table.concat(parts, "  \194\183  ")
	end
	local cur, max, level = S.Progress()
	local parts = { "Level " .. level, ("%.1f%%"):format(cur / max * 100) }
	if T.db.bubbles then parts[#parts + 1] = ("%.1f bubbles to go"):format(S.Bubbles()) end
	local eta = S.TimeToLevel()
	if eta then parts[#parts + 1] = "~" .. S.Duration(eta) end
	return table.concat(parts, "  \194\183  ")
end
