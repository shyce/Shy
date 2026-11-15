-- ShyXP integration: a level strip at the bottom of the card (standing in for ShyXP's stats box,
-- in ShyDock's deck too)
-- and XP figures on steps. Uses only ShyXP/API.lua; does nothing without ShyXP.
-- The strip's bar is ShyXP's: past your XP, a band for the quests ready to hand in, then one for the rest
-- of the log; under it each is said as a figure, after a swatch of its band's color.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local X = {}
ns.XP = X

local PAD = 10
local HEIGHT = 42
-- The strip's two lines, each laid on its middle: the level, the bar and the percent; under them the time left
-- and the bar's quest figures.
local STRIP = {
	top = -14, under = -30,   -- the two lines' middles, down from the strip's top
	bar = 10,                 -- the bar's height
	gap = 8,                  -- between the level, the bar and the percent; the least between the time left and the figures
	pip = 6, lead = 4,        -- a figure's swatch of its band's color, and how far its words stand past it
	apart = 12,               -- between two figures
}
local EVERY = 5              -- seconds between refreshes when nothing prompts one
local stale, refreshed = true, 0

-- ShyXP's addon object, when it is loaded.
local function Other()
	local xp = Shy.addons.XP
	if xp and xp.Stats and xp.CreateBar then return xp end
end

function X.Loaded()
	return Other() ~= nil
end

local function Levelling()
	local xp = Other()
	return xp ~= nil and xp.Stats.Active()
end

-- The card is the one place for the level, always while there is a level to gain (never at the top one):
-- ShyXP's own box steps aside while the card carries it (X.Apply).
local function Carried()
	return Levelling()
end

function X.StripWanted()
	return Carried()
end

function X.OnSteps()
	return T.db.xp.steps and Levelling()
end

-- Step text

function X.Worth(id)
	if not X.OnSteps() then return nil end
	local xp = GetQuestLogRewardXP(id)
	return xp and xp > 0 and xp or nil
end

-- "+1,250 XP", for the right of a turn-in's line (its own column: a line's words are cut short before it
-- is), or nil.
function X.WorthRight(id)
	local xp = X.Worth(id)
	return xp and ("+%s XP"):format(Other().Stats.Number(xp)) or nil
end

-- "  +1,250 XP", to follow a turn-in's line.
function X.WorthText(id)
	local xp = X.Worth(id)
	if not xp then return "" end
	return "  " .. UI.Wrap(C.alert, ("+%s XP"):format(Other().Stats.Number(xp)))
end

-- The level these turn-ins would reach, or nil if they fall short.
function X.LevelsTo(ids)
	if not X.OnSteps() then return nil end
	local total = 0
	for _, id in ipairs(ids) do total = total + (X.Worth(id) or 0) end
	local cur, max, level = Other().Stats.Progress()
	if total > 0 and cur + total >= max then return level + 1 end
end

-- For a guide's level gate ("14", "7+1140", "14-1200"): XP to go and time at ShyXP's pace.
-- Empty when the gate is more than one level away, since only this level's length is known.
function X.ToGo(spec)
	if not X.OnSteps() then return "" end
	local S = Other().Stats
	local level, offset = spec:match("(%d+)([%+%.%-]?%d*)")
	level, offset = tonumber(level), tonumber(offset) or 0
	if not level then return "" end
	local cur, max, mine = S.Progress()
	local left
	if offset < 0 and mine == level - 1 then
		left = max + offset - cur
	elseif offset >= 1 and mine == level then
		left = offset - cur
	elseif offset > 0 and offset < 1 and mine == level then
		left = max * offset - cur
	elseif offset == 0 and mine == level - 1 then
		left = max - cur
	end
	if not left or left <= 0 then return "" end
	local text = ("%s XP to go"):format(S.Number(left))
	local pace = S.Pace()
	if pace and pace > 0 then text = text .. ", about " .. S.Duration(left / pace * 3600) end
	return "  " .. UI.Wrap(C.dim, text)
end

-- The guide's grind target (an `xp` line of a live step) as a tick on ShyXP's bars: where on this level it
-- stands; nothing where the gate is a level away or past (only this level's length is known).
function X.Goal()
	local xp = Other()
	if not (xp and xp.SetGoal) then return end
	local level, target
	if X.OnSteps() and ns.Guide then
		local S = xp.Stats
		for _, entry in ipairs(ns.Guide.active or {}) do
			for _, part in ipairs(entry.parts or {}) do
				local element = part.element
				if not level and element.command == "xp" and part.can and not part.done then
					local want, offset = (element.args or ""):match("(%d+)([%+%.%-]?%d*)")
					want, offset = tonumber(want), tonumber(offset) or 0
					local cur, max, mine = S.Progress()
					if want and offset < 0 and mine == want - 1 then
						level, target = mine, max + offset
					elseif want and offset >= 1 and mine == want then
						level, target = mine, offset
					elseif want and offset > 0 and offset < 1 and mine == want then
						level, target = mine, max * offset
					end
				end
			end
		end
	end
	xp:SetGoal(level, target)
end

-- The strip

local function CreateStrip(card)
	local xp = Other()
	local S = xp.Stats
	local strip = CreateFrame("Frame", nil, card)
	strip:SetHeight(HEIGHT)

	strip.rule = strip:CreateTexture(nil, "ARTWORK")
	strip.rule:SetHeight(1)
	strip.rule:SetPoint("TOPLEFT", PAD, 0)
	strip.rule:SetPoint("TOPRIGHT", -PAD, 0)
	UI.Paint(strip.rule, C.rowEdge, 0.8)

	-- The bar between the level and the percent, the same gap either side of it: each of the two is as wide
	-- as its words.
	strip.level = UI.Text(strip, "", 15, true)
	strip.level:SetPoint("LEFT", strip, "TOPLEFT", PAD, STRIP.top)
	strip.percent = UI.Text(strip, "", 12, true, C.hot)
	strip.percent:SetPoint("RIGHT", strip, "TOPRIGHT", -PAD, STRIP.top)

	strip.bar = xp:CreateBar(strip)
	strip.bar:SetHeight(STRIP.bar)
	strip.bar:SetPoint("LEFT", strip.level, "RIGHT", STRIP.gap, -1)
	strip.bar:SetPoint("RIGHT", strip.percent, "LEFT", -STRIP.gap, -1)

	-- Under the bar: what is left to the level at the left; at the right the bar's two quest bands as figures,
	-- each after a swatch of its band's color (the color stays in the bar and the swatches: the words are plain,
	-- a figure bright and what it is quiet).
	local function Figure(word)
		local figure = UI.Text(strip, "", 11, false, C.dim)
		figure.word = word
		figure.pip = strip:CreateTexture(nil, "ARTWORK")
		figure.pip:SetSize(STRIP.pip, STRIP.pip)
		figure.pip:SetPoint("RIGHT", figure, "LEFT", -STRIP.lead, 0)
		return figure
	end
	strip.ready, strip.log = Figure("ready"), Figure("in log")
	strip.eta = UI.Text(strip, "", 11, false, C.dim)
	strip.eta:SetWordWrap(false)

	-- A figure said and stood at the line's right end, or before the one already there (`after`); away while it
	-- has nothing to say. Returns the leftmost figure standing, and the room this one takes.
	local function Stand(figure, xp, color, after)
		local on = xp > 0
		figure:SetShown(on)
		figure.pip:SetShown(on)
		if not on then return after, 0 end
		figure:SetText(UI.Wrap(C.text, S.Short(xp)) .. " " .. figure.word)
		figure.pip:SetColorTexture(color[1], color[2], color[3], 1)
		if figure.after ~= (after or false) then
			figure.after = after or false
			figure:ClearAllPoints()
			if after then
				figure:SetPoint("RIGHT", after.pip, "LEFT", -STRIP.apart, 0)
			else
				figure:SetPoint("RIGHT", strip, "TOPRIGHT", -PAD, STRIP.under)
			end
		end
		return figure, figure:GetStringWidth() + STRIP.lead + STRIP.pip + (after and STRIP.apart or 0)
	end

	function strip:Refresh()
		local cur, max, level = S.Progress()
		self.level:SetText(tostring(level))
		self.percent:SetText(("%d%%"):format(math.floor(cur / max * 100)))
		self.bar:Update()

		-- What the whole log would add with every quest done (only where it holds more than what is ready), and
		-- before it what the quests ready to hand in would.
		local ready, whole = (S.QuestXP()), (S.LogXP())
		local readyColor, logColor = S.QuestColors()
		local first, logRoom = Stand(self.log, whole > ready and whole or 0, logColor, nil)
		local readyRoom
		first, readyRoom = Stand(self.ready, ready, readyColor, first)

		-- The time left at your pace, or the XP left without one, up to the figures: a time that has no room
		-- beside them goes without its words, and anything longer still is cut short, never written over them.
		if self.bound ~= (first or false) then
			self.bound = first or false
			self.eta:ClearAllPoints()
			self.eta:SetPoint("LEFT", self, "TOPLEFT", PAD, STRIP.under)
			if first then
				self.eta:SetPoint("RIGHT", first.pip, "LEFT", -STRIP.gap, 0)
			else
				self.eta:SetPoint("RIGHT", self, "TOPRIGHT", -PAD, STRIP.under)
			end
		end
		local eta = S.TimeToLevel()
		local left = UI.Wrap(C.text, eta and ("~" .. S.Duration(eta)) or S.Short(max - cur))
		self.eta:SetText(left .. " to go")
		local room = self:GetParent():GetWidth() - PAD * 2 - logRoom - readyRoom - (first and STRIP.gap or 0)
		if eta and self.eta:GetUnboundedStringWidth() > room then self.eta:SetText(left) end
	end

	strip:EnableMouse(true)
	strip:SetScript("OnEnter", function(self) xp:ShowTooltip(self) end)
	strip:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	return strip
end

-- The card's strip, created on first use; nil when it isn't wanted.
function X.Strip(card)
	if not X.StripWanted() then
		if card.strip then card.strip:Hide() end
		return nil
	end
	if not card.strip then
		card.strip = CreateStrip(card)
		if X.onStrip then X.onStrip(card, card.strip) end
	end
	return card.strip
end

X.HEIGHT = HEIGHT

-- Hides ShyXP's own box while the card carries the level.
function X.Apply()
	local xp = Other()
	if xp then xp:SetDocked("ShyQuest", T.db.card.shown and Carried() or false) end
	stale = true
end

function X.Share()
	local xp = Other()
	if xp then xp:Share() end
end

function X.Setup()
	if not Other() then return end
	X.Apply()
	Shy:On("SHY_XP_DOCKED", function()
		X.Apply()
		ns.ApplyCard()
	end)
	Shy:On("SHY_XP_SWITCH", function()
		stale = true
		ns.ApplyCard()
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		stale = true
		-- Step text (turn-in XP, grind to go) depends on XP too. A kill's XP rewrites the card's rows (a
		-- hand-in's worth, whether it dings) and nothing else: the guide asks again itself while a step waits
		-- on XP (Guide.lua). Only a level gained builds the route again (what is too high or gray moves).
		if event ~= "UPDATE_EXHAUSTION" and event ~= "PLAYER_UPDATE_RESTING" then
			if event == "PLAYER_LEVEL_UP" then ns.Refresh() end
			X.Goal()
			-- (Only a hand-in's row says what it is worth: no hand-in on the route, nothing to write again.)
			local handIn = false
			for _, stop in ipairs(ns.Route and ns.Route.stops or {}) do
				if stop.kind == "turnin" then
					handIn = true
					break
				end
			end
			if handIn and ns.Recount then ns.Recount() end
		end
	end)
	if ns.Guide and ns.Guide.OnLive then ns.Guide.OnLive(X.Goal) end

	-- Time to level changes even without events.
	ns.OnRoute(function(rebuilt)
		local now = GetTime()
		if not (stale or rebuilt or now - refreshed >= EVERY) then return end
		stale, refreshed = false, now
		for card in pairs(ns.cards) do
			if card.strip and card.strip:IsShown() then card.strip:Refresh() end
		end
	end)
end
