-- The default XP bar: restyled bar or quest XP bands over it, progress text, the stats card on hover, Shift-click
-- to share. There is one XP bar per Edit Mode status bar slot; all are hooked.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local bars = {}

local function ExpBars()
	local list = {}
	for _, container in ipairs(StatusTrackingBarManager.barContainers) do
		local bar = container.bars and container.bars[StatusTrackingBarInfo.BarsEnum.Experience]
		if bar then list[#list + 1] = bar end
	end
	return list
end

local GOLD = { 1, 0.82, 0 }   -- quest XP ready; not a theme color

-- The stats card for the stats box, the default bar and API callers, with the caller's hints (what its
-- clicks do). Under the level: how far through it, as a bar with what the quests ready to hand in would
-- add after it and what the rest of the log would after that; what is left to the next level; this level
-- so far; the levels before against the other run. A stat with nothing to say yet is left out. OnLeave is
-- hooked once per owner so it always hides.
local leaves = setmetatable({}, { __mode = "k" })

-- Where that much XP would put you: through this level, or into the next.
local function Reach(xp, max, level)
	if xp >= max then return "level " .. (level + 1) end
	return math.floor(xp / max * 100) .. "%"
end

local function Row(rows, text, right, rightColor)
	rows[#rows + 1] = { text = text, right = right, color = C.dim, rightColor = rightColor or C.text }
end

local function Under(rows, text)
	rows[#rows + 1] = { text = text, quiet = true, indent = 1 }
end

local function Leaves(owner)
	if not leaves[owner] then
		leaves[owner] = true
		owner:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	end
end

-- The reputation you track as a card: its standing and how far through it, what is left to the next, the
-- pace and what it has gained since you began.
function ns.ShowRepTooltip(owner, hints)
	Leaves(owner)
	local Rep = ns.Rep
	local into, span, data = Rep.Progress()
	if not data then return end
	local word, color = Rep.Standing(data.reaction)
	local next_ = Rep.Next(data.reaction)
	local body = { { bar = { have = into / span, gain = 0, more = 0 } } }

	-- To the next standing: the time at your pace, the pace, the kills or hand-ins at what one has come to, and the
	-- quests in your log that give it (the client says which, not how much).
	local ahead = {}
	if next_ then
		local eta = Rep.TimeToNext()
		if eta then Row(ahead, "Time", "~" .. S.Duration(eta)) end
		local pace = Rep.Pace()
		if pace then Row(ahead, "Reputation per hour", S.Number(pace)) end
		local count, average = Rep.GainsToNext(), Rep.Average()
		if count then
			Row(ahead, "Kills or quests", "~" .. S.Number(count))
			Under(ahead, ("+%s each, on average"):format(S.Number(average)))
		end
	end
	local ready, all = Rep.Quests()
	if all > 0 then
		Row(ahead, "Quests that raise it", ready > 0 and (ready .. " of " .. all .. " ready") or (all .. " in your log"), GOLD)
	end
	if #ahead > 0 then body[#body + 1] = { title = next_ and ("To " .. next_) or word, rows = ahead } end

	-- This standing: how long you have watched it in it, its gains and what they came to; this session's.
	local rec = Rep.Record()
	local now = {}
	if rec then
		Row(now, "Time", S.Duration(rec.time))
		if rec.gains > 0 then
			Row(now, "Kills or quests", S.Number(rec.gains))
			Row(now, "Reputation", "+" .. S.Number(rec.gained), C.good)
		end
		if not rec.whole then Under(now, "Since you began watching it") end
	end
	local got = Rep.Session()
	if got > 0 then Row(now, "This session", "+" .. S.Number(got), C.good) end
	if #now > 0 then body[#body + 1] = { title = "As " .. word, rows = now } end

	-- Each standing behind and how long it took (at least, where you began watching it partway).
	local splits = {}
	for _, split in ipairs(Rep.Splits()) do
		local was, wasColor = Rep.Standing(split.reaction)
		splits[#splits + 1] = { text = was, right = (split.whole and "" or "at least ") .. S.Duration(split.time),
			color = wasColor, rightColor = C.text }
	end
	if #splits > 0 then body[#body + 1] = { title = "Standings", rows = splits } end

	local key = { { text = ("%d%%"):format(math.floor(into / span * 100)), color = C.hot },
		{ text = "  \194\183  " .. word, color = color } }
	if next_ then key[3] = { text = "  \194\183  " .. S.Number(span - into) .. " to " .. next_, color = C.dim } end
	Shy.Hover.Show(owner, {
		card = true, title = data.name, hints = hints, body = body, least = 200, key = key,
	}, { keep = false })
end

function ns.ShowSummaryTooltip(owner, hints, source)
	if not T.db.tooltip then return end
	if (source or S.Mode()) == "rep" then return ns.ShowRepTooltip(owner, hints) end
	Leaves(owner)
	local on = T.db.lines
	local cur, max, level = S.Progress()
	local ready, quests = S.QuestXP()
	local whole, held = S.LogXP()
	local _, logColor = S.QuestColors()
	local body = { { bar = { have = cur / max, gain = on.quests and ready / max or 0,
		more = on.quests and (whole - ready) / max or 0, moreColor = logColor } } }

	local ahead = {}
	if on.eta then
		local eta = S.TimeToLevel()
		if eta then Row(ahead, "Time", "~" .. S.Duration(eta)) end
	end
	if on.pace then
		local pace = S.Pace()
		if pace then Row(ahead, "XP per hour", S.Number(pace)) end
	end
	if on.kills then
		local count = S.KillsToLevel()
		if count then Row(ahead, "Kills", "~" .. count) end
	end
	if on.bubbles then Row(ahead, "Bubbles", ("%.1f"):format(S.Bubbles())) end
	if on.quests and quests > 0 then
		Row(ahead, S.Count(quests, "quest") .. " to hand in", "+" .. S.Number(ready) .. " XP", GOLD)
		Under(ahead, "Puts you at " .. Reach(cur + ready, max, level))
	end
	-- The whole log, where it holds more than what is ready.
	if on.quests and held > quests and whole > ready then
		Row(ahead, S.Count(held, "quest") .. " in your log", "+" .. S.Number(whole) .. " XP", logColor)
		Under(ahead, "All done puts you at " .. Reach(cur + whole, max, level))
	end
	if on.rested then
		local rested, share, full = S.Rested()
		if rested > 0 then
			Row(ahead, "Rested", S.Number(rested) .. " XP", C.hot)
			Under(ahead, ("%d%% of a level"):format(math.floor(share * 100)) .. (full and (", full in ~" .. S.Duration(full)) or ""))
		end
	end
	if #ahead > 0 then body[#body + 1] = { title = "To level " .. (level + 1), rows = ahead } end

	local now = {}
	if on.level then
		local time, kills, done = S.ThisLevel()
		Row(now, "Time", S.Duration(time))
		Row(now, "Kills", tostring(kills))
		Row(now, "Quests", tostring(done))
	end
	local from = on.splits and ns.Splits and ns.Splits.SourceText(level)
	if from then Under(now, "XP from " .. from) end
	if #now > 0 then body[#body + 1] = { title = "This level", rows = now } end

	-- The levels behind, each against the other character's run where there is one.
	if on.splits and ns.Splits then
		local splits, against = ns.Splits.Rows(true)
		if splits then body[#body + 1] = { title = against and ("Splits against " .. against) or "Splits", rows = splits } end
	end

	Shy.Hover.Show(owner, {
		card = true, title = "Level " .. level, hints = hints, body = body, least = 200,
		key = { { text = ("%d%%"):format(math.floor(cur / max * 100)), color = C.hot },
			{ text = "  \194\183  " .. S.Number(max - cur) .. " XP to go", color = C.dim } },
	}, { keep = false })
end

-- Hovering the default bar: the stats card in the place of the game's tooltip, one card rather than the
-- game's lines with these under them.
local BAR_HINTS = { { "left", "Shift: share" }, { "right", "Track" } }

local function OnBar(owner)
	if not T.db.tooltip or not S.Active() then return end
	GameTooltip:Hide()
	ns.ShowSummaryTooltip(owner, BAR_HINTS, "xp")
end

-- A right click on either of the game's bars: what the bars track.
local function TrackMenu(owner, button)
	if button == "RightButton" and ns.Rep then UI.ContextMenu(owner, ns.Rep.Menu) end
end

local EXPERIENCE = StatusTrackingBarInfo.BarsEnum.Experience
local REPUTATION = StatusTrackingBarInfo.BarsEnum.Reputation
local hookedContainers = {}

local function RepShy()
	return T.db.barStyle == "shy" and ns.Rep ~= nil and ns.Rep.Watched() ~= nil
end

-- The border and dividers belong to the slot, which shows one bar at a time: faded only while the bar it
-- shows is restyled.
local function StyleContainer(container)
	local shown = container.shownBarIndex
	local hide = T.db.barStyle == "shy" and ((shown == EXPERIENCE and S.Active()) or (shown == REPUTATION and RepShy()))
	container.BarFrameTexture:SetAlpha(hide and 0 or 1)
	for divider in container.HorizontalDividersPool:EnumerateActive() do
		divider:SetAlpha(hide and 0 or 1)
	end
end

local function UpdateBar(bar)
	local extra = bars[bar]
	local cur, max, level = S.Progress()
	local active = S.Active()
	local shy = active and T.db.barStyle == "shy"
	local showText = active and (T.db.barText == "always" or (T.db.barText == "hover" and extra.hovered))

	-- Faded, not hidden: the default bar keeps its hover, tooltip and click.
	extra.shy:SetShown(shy)
	bar.StatusBar:SetAlpha(shy and 0 or 1)
	bar.ExhaustionLevelFillBar:SetAlpha(shy and 0 or 1)
	bar.ExhaustionTick:SetAlpha(shy and 0 or 1)
	bar.OverlayFrame.Text:SetAlpha((not shy and T.db.blizzText) and 1 or 0)
	StyleContainer(bar:GetParent())

	if shy then
		extra.shy:Update()
		extra.shy.text:SetText(ns.BarText("xp"))
		extra.shy.text:SetShown(showText)
		extra.log:Hide()
		extra.quest:Hide()
		extra.questEdge:Hide()
		extra.text:Hide()
		return
	end

	-- Default bar: the quest bands and text over it. The ready band lies over the log's, which shows past it.
	local ready, whole = (S.QuestXP()), (S.LogXP())
	local width = bar:GetWidth()
	local bands = active and T.db.questOverlay and width > 0
	local show = bands and ready > 0
	local c, l = S.QuestColors()
	extra.quest:SetShown(show)
	extra.questEdge:SetShown(show)
	if show then
		extra.quest:SetVertexColor(c[1], c[2], c[3], 0.45)
		extra.questEdge:SetVertexColor(c[1], c[2], c[3], 1)
		extra.quest:SetWidth(math.max(1, math.min(1, (cur + ready) / max) * width))
	end
	local rest = bands and whole > ready
	extra.log:SetShown(rest)
	if rest then
		extra.log:SetVertexColor(l[1], l[2], l[3], 0.4)
		extra.log:SetWidth(math.max(1, math.min(1, (cur + whole) / max) * width))
	end

	local text = ("%d%%"):format(math.floor(cur / max * 100))
	local eta = S.TimeToLevel()
	if eta then text = text .. "  \194\183  ~" .. S.Duration(eta) .. " to " .. (level + 1) end
	extra.text:SetText(text)
	extra.text:SetShown(showText)
	-- The goal (xp:SetGoal): a tick where it stands on this level.
	local goal = ns.goal
	local share = active and goal and goal.level == level and goal.xp > cur and goal.xp <= max and width > 0 and goal.xp / max or nil
	extra.goal:SetShown(share ~= nil)
	if share then
		extra.goal:ClearAllPoints()
		extra.goal:SetPoint("TOP", bar, "TOPLEFT", share * width, 0)
		extra.goal:SetPoint("BOTTOM", bar, "BOTTOMLEFT", share * width, 0)
	end
end

local function Hook(bar)
	if bars[bar] then return end
	local extra = {}
	bars[bar] = extra

	local container = bar:GetParent()
	if not hookedContainers[container] then
		hookedContainers[container] = true
		hooksecurefunc(container, "UpdateDividers", StyleContainer)
		hooksecurefunc(container, "ApplyPendingBarToShow", StyleContainer)
	end

	-- Above the slot's border and dividers; takes no mouse input.
	extra.shy = ns.CreateXPBar(bar)
	extra.shy.source = "xp"
	extra.shy:SetAllPoints()
	extra.shy:SetFrameStrata("MEDIUM")
	extra.shy:SetFrameLevel(container:GetFrameLevel() + 10)

	-- Sublevels 1 to 3: above the default rested fill, under the XP fill.
	extra.log = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	extra.log:SetColorTexture(1, 1, 1, 1)
	extra.log:SetPoint("TOPLEFT")
	extra.log:SetPoint("BOTTOMLEFT")
	extra.quest = bar:CreateTexture(nil, "ARTWORK", nil, 2)
	extra.quest:SetColorTexture(1, 1, 1, 1)
	extra.quest:SetPoint("TOPLEFT")
	extra.quest:SetPoint("BOTTOMLEFT")
	extra.questEdge = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	extra.questEdge:SetColorTexture(1, 1, 1, 1)
	extra.questEdge:SetWidth(2)
	extra.questEdge:SetPoint("TOPRIGHT", extra.quest)
	extra.questEdge:SetPoint("BOTTOMRIGHT", extra.quest)
	extra.goal = bar:CreateTexture(nil, "OVERLAY", nil, 3)
	extra.goal:SetColorTexture(1, 1, 1, 0.9)
	extra.goal:SetWidth(2)
	extra.goal:Hide()

	local layer = CreateFrame("Frame", nil, bar)
	layer:SetAllPoints()
	layer:SetFrameLevel(bar.StatusBar:GetFrameLevel() + 5)
	extra.text = layer:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	extra.text:SetPoint("RIGHT", -6, 1)

	bar:HookScript("OnEnter", function()
		extra.hovered = true
		UpdateBar(bar)
		OnBar(bar)
	end)
	bar:HookScript("OnLeave", function()
		extra.hovered = false
		UpdateBar(bar)
	end)
	bar.ExhaustionTick:HookScript("OnEnter", OnBar)
	bar:HookScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and IsShiftKeyDown() and S.Active() then ns.Share("xp") end
		TrackMenu(self, button)
	end)
	bar:HookScript("OnSizeChanged", function() UpdateBar(bar) end)
	UpdateBar(bar)
end

-- The game's reputation bar, restyled as the XP bar is: our bar over it with the progress text, the
-- reputation card on hover.
local repBars = {}

local function UpdateRepBar(bar)
	local extra = repBars[bar]
	local shy = RepShy()
	extra.shy:SetShown(shy)
	bar.StatusBar:SetAlpha(shy and 0 or 1)
	bar.OverlayFrame.Text:SetAlpha(shy and 0 or 1)
	StyleContainer(bar:GetParent())
	if not shy then return end
	extra.shy:Update()
	extra.shy.text:SetText(ns.BarText("rep"))
	extra.shy.text:SetShown(T.db.barText == "always" or (T.db.barText == "hover" and extra.hovered))
end

local function HookRep(bar)
	if repBars[bar] then return end
	local extra = {}
	repBars[bar] = extra
	local container = bar:GetParent()
	if not hookedContainers[container] then
		hookedContainers[container] = true
		hooksecurefunc(container, "UpdateDividers", StyleContainer)
		hooksecurefunc(container, "ApplyPendingBarToShow", StyleContainer)
	end
	extra.shy = ns.CreateXPBar(bar)
	extra.shy.source = "rep"
	extra.shy:SetAllPoints()
	extra.shy:SetFrameStrata("MEDIUM")
	extra.shy:SetFrameLevel(container:GetFrameLevel() + 10)
	bar:HookScript("OnEnter", function(self)
		extra.hovered = true
		UpdateRepBar(self)
		if T.db.tooltip and RepShy() then
			GameTooltip:Hide()
			ns.ShowRepTooltip(self, BAR_HINTS)
		end
	end)
	bar:HookScript("OnLeave", function(self)
		extra.hovered = false
		UpdateRepBar(self)
	end)
	bar:HookScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and IsShiftKeyDown() and RepShy() then ns.Share("rep") end
		TrackMenu(self, button)
	end)
	bar:HookScript("OnSizeChanged", function(self) UpdateRepBar(self) end)
	UpdateRepBar(bar)
end

local function RepBars()
	local list = {}
	for _, container in ipairs(StatusTrackingBarManager.barContainers) do
		local bar = container.bars and REPUTATION and container.bars[REPUTATION]
		if bar then list[#list + 1] = bar end
	end
	return list
end

-- Where the bars stand, and whose they are under the action bars: what the console keeps room by.
local stood
local function Stand()
	local place = ns.Place()
	return place == "under" and (place .. " " .. T.db.barStyle) or place
end

-- A setting changed: everything laid out and said again, the game's bars shown or stood down, and the
-- console told when the bars moved.
function ns.Refresh()
	if ns.Under then ns.Under.Place() end
	ns.ApplyBlizzardBar()
	for bar in pairs(bars) do UpdateBar(bar) end
	for bar in pairs(repBars) do UpdateRepBar(bar) end
	for card in pairs(ns.cards) do
		card:Layout()
		card:Refresh()
	end
	-- A bar someone else carries (the quest window's) is said again too.
	for bar in pairs(ns.bars) do
		if bar:IsVisible() then bar:Update() end
	end
	ns.UpdateBox()
	local stands = Stand()
	if stands ~= stood then
		stood = stands
		Shy:Fire("SHY_XP_PLACE")
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- What you have changed (XP, rested, quests ready, the time going by): the numbers said again, the layout
-- left as it stands.
function ns.Update()
	if ns.Under then ns.Under.Refresh() end
	for bar in pairs(bars) do UpdateBar(bar) end
	for bar in pairs(repBars) do UpdateRepBar(bar) end
	for card in pairs(ns.cards) do card:Refresh() end
	ns.UpdateBox()
end

-- Asked for many times in a frame (a kill: the XP, the quest log twice or more): done once, the frame after.
local soon = false
function ns.Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		ns.Update()
	end)
end

-- While docked (API.lua) the default bar's containers are hidden. UpdateBarsShown re-shows them,
-- so Show is post-hooked. The containers are not protected.

local hiddenByUs = {}

-- The game's own bars show only under the action bars with the default look picked (else ours stand there:
-- Under.lua).
local function WantBlizzardBar()
	return ns.Place() == "under" and T.db.barStyle == "blizzard"
end

function ns.ApplyBlizzardBar()
	local manager = StatusTrackingBarManager
	if not manager then return end
	for _, container in ipairs(manager.barContainers) do
		if not WantBlizzardBar() then
			if container:IsShown() then
				hiddenByUs[container] = true
				container:Hide()
			end
		elseif hiddenByUs[container] then
			hiddenByUs[container] = nil
			container:Show()
		end
	end
	-- Once restored, the manager decides which containers show.
	if WantBlizzardBar() and manager.UpdateBarsShown then manager:UpdateBarsShown() end
end

local function HookBlizzardBar()
	local manager = StatusTrackingBarManager
	if not manager then return end
	for _, container in ipairs(manager.barContainers) do
		hooksecurefunc(container, "Show", function(self)
			if not WantBlizzardBar() and self:IsShown() then
				hiddenByUs[self] = true
				self:Hide()
			end
		end)
	end
end

function ns.SetupBar()
	stood = Stand()
	for _, bar in ipairs(ExpBars()) do Hook(bar) end
	for _, bar in ipairs(RepBars()) do HookRep(bar) end
	HookBlizzardBar()
	ns.ApplyBlizzardBar()
	-- XP per hour and time to level change between XP gains.
	C_Timer.NewTicker(10, ns.Update)
end
