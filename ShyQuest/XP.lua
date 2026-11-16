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
local REP_ROW = 26           -- the reputation's row under the XP's: its bar on the first line, the faction under it
-- The strip's two lines, each laid on its middle: the level, the bar and the percent; under them the time left
-- and the bar's quest figures.
local STRIP = {
	top = -14, under = -30,   -- the two lines' middles, down from the strip's top
	bar = 10,                 -- the bar's height
	gap = 8,                  -- between the level, the bar and the percent; the least between the time left and the figures
	pip = 6, lead = 4,        -- a figure's swatch of its band's color, and how far its words stand past it
	apart = 12,               -- between two figures
	repTop = -4, repUnder = -17,   -- the reputation row's two lines' middles, down from its top
	repBar = 6,                    -- its bar's height
}
local EVERY = 5              -- seconds between refreshes when nothing prompts one
local STRIP_HINTS = { { "right", "Track" } }
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

-- The reputation ShyXP watches, a bar of its own beside your XP: { name, word, color, next, into, span, eta } or nil.
local function Watched()
	local xp = Other()
	return xp and xp.Reputation and xp:Reputation(true) or nil
end

-- ShyXP's bars go on this card (its setting: the quest window, under the action bars or its stats window).
local function Here()
	local xp = Other()
	return xp ~= nil and (not xp.IsOn or xp:IsOn())
end

-- The card carries your XP while there is a level to gain, and the reputation you watch at any level: one
-- bar each, the XP's first. ShyXP's own bars step aside while it does (X.Apply).
local function Carried()
	return Here() and (Levelling() or Watched() ~= nil)
end

-- A second, slimmer row for the reputation, under the XP's.
local function Both()
	return Levelling() and Watched() ~= nil
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
	-- The strip's figures, short: 2,635 is "2.6k" (the card is narrow; the hover has them whole).
	local function Short(n)
		if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
		if n >= 1000 then return ("%.1fk"):format(n / 1e3) end
		return S.Number(n)
	end

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
		figure:SetText(UI.Wrap(C.text, Short(xp)) .. " " .. figure.word)
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

	-- The reputation you track: its standing in its color, how far through it; under the bar the faction and
	-- what is left to the next standing.
	local function Reputation(self, rep)
		self.level:SetText(UI.Wrap(rep.color, rep.word))
		self.percent:SetText(("%d%%"):format(math.floor(rep.into / rep.span * 100)))
		self.bar:Update()
		Stand(self.log, 0)
		Stand(self.ready, 0)
		if self.bound ~= false then
			self.bound = false
			self.eta:ClearAllPoints()
			self.eta:SetPoint("LEFT", self, "TOPLEFT", PAD, STRIP.under)
			self.eta:SetPoint("RIGHT", self, "TOPRIGHT", -PAD, STRIP.under)
		end
		local left = ""
		if rep.next then
			left = (rep.eta and ("~" .. S.Duration(rep.eta)) or Short(rep.span - rep.into)) .. " to " .. rep.next
		end
		self.eta:SetText(UI.Wrap(C.text, rep.name) .. (left ~= "" and ("  " .. left) or ""))
	end

	-- The reputation's own row under the XP's: its bar under the XP bar, edge to edge, and its percent under the
	-- XP's; under them the faction with its standing, and what is left to the next.
	local function Second(self, rep)
		local row = self.second
		if not row then
			row = CreateFrame("Frame", nil, self)
			row:SetPoint("TOPLEFT", 0, -HEIGHT)
			row:SetPoint("TOPRIGHT", 0, -HEIGHT)
			row:SetHeight(REP_ROW)
			row.percent = UI.Text(row, "", 11, true, C.hot)
			row.percent:SetPoint("RIGHT", row, "TOPRIGHT", -PAD, STRIP.repTop)
			row.bar = xp:CreateBar(row, "rep")
			row.bar:SetHeight(STRIP.repBar)
			-- (Under the XP bar, its edges the XP bar's: from the XP bar's foot down to the row's first line.)
			local drop = (HEIGHT - STRIP.repTop - STRIP.repBar / 2) - (1 - STRIP.top + STRIP.bar / 2)
			row.bar:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -drop)
			row.bar:SetPoint("TOPRIGHT", self.bar, "BOTTOMRIGHT", 0, -drop)
			row.left = UI.Text(row, "", 11, false, C.dim)
			row.left:SetPoint("RIGHT", row, "TOPRIGHT", -PAD, STRIP.repUnder)
			row.name = UI.Text(row, "", 11, false, C.text)
			row.name:SetWordWrap(false)
			row.name:SetPoint("LEFT", row, "TOPLEFT", PAD, STRIP.repUnder)
			row.name:SetPoint("RIGHT", row.left, "LEFT", -STRIP.gap, 0)
			row:EnableMouse(true)
			row:SetScript("OnEnter", function(r) xp:ShowTooltip(r, STRIP_HINTS, "rep") end)
			row:SetScript("OnLeave", function(r) UI.TipHide(r) end)
			row:SetScript("OnMouseUp", function(r, button)
				if button == "RightButton" then xp:TrackMenu(r) end
			end)
			self.second = row
		end
		row.percent:SetText(("%d%%"):format(math.floor(rep.into / rep.span * 100)))
		row.bar:Update()
		-- The faction, and its standing in its color: what the bar is of.
		row.name:SetText(rep.name .. "  " .. UI.Wrap(rep.color, rep.word))
		local left = ""
		if rep.next then
			left = UI.Wrap(C.text, rep.eta and ("~" .. S.Duration(rep.eta)) or Short(rep.span - rep.into)) .. " to " .. rep.next
		end
		row.left:SetText(left)
		-- A long name and its standing that don't fit beside what is left: the name alone (what is left names the
		-- next standing, so the one you're in goes without saying).
		local room = row:GetWidth() - PAD * 2 - row.left:GetStringWidth() - STRIP.gap
		if room > 0 and row.name:GetUnboundedStringWidth() > room then row.name:SetText(rep.name) end
		row:Show()
	end

	function strip:Refresh()
		local levelling = S.Active()
		self.bar.source = levelling and "xp" or "rep"
		local rep = Watched()
		self:SetHeight(X.Height())
		if not levelling then
			if self.second then self.second:Hide() end
			if rep then Reputation(self, rep) end
			return
		end
		if rep then Second(self, rep) elseif self.second then self.second:Hide() end
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

		-- The time left at your pace, or the XP left without one, up to the figures: one that has no room
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
		local left = UI.Wrap(C.text, eta and ("~" .. S.Duration(eta)) or Short(max - cur))
		self.eta:SetText(left .. " to go")
		local room = self:GetParent():GetWidth() - PAD * 2 - logRoom - readyRoom - (first and STRIP.gap or 0)
		-- (Before the card has a width there is nothing to measure against.)
		if room > 0 and self.eta:GetUnboundedStringWidth() > room then self.eta:SetText(left) end
	end

	strip:EnableMouse(true)
	strip:SetScript("OnEnter", function(self) xp:ShowTooltip(self, xp.TrackMenu and STRIP_HINTS or nil, self.bar.source) end)
	strip:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	strip:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and xp.TrackMenu then xp:TrackMenu(self) end
	end)
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

-- The strip's height: the XP's block, and the reputation's row under it while both show.
function X.Height()
	return HEIGHT + (Both() and REP_ROW or 0)
end

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
	-- Where ShyXP's bars go changed: the card takes them or gives them back.
	Shy:On("SHY_XP_SWITCH", function()
		X.Apply()
		ns.ApplyCard()
	end)
	-- The bars went from XP to a reputation or back, or to nothing at the top level.
	Shy:On("SHY_XP_MODE", function()
		X.Apply()
		ns.ApplyCard()
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "UPDATE_FACTION" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		stale = true
		if event == "UPDATE_FACTION" then return end
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
