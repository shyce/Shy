-- Public API for other addons, as Shy.addons.XP (nil when ShyXP isn't loaded).
--   xp.Stats                   -- Active, Progress, Pace, TimeToLevel, Rested; Duration, Number, Short;
--                              -- QuestXP (the quests ready to hand in: XP, count), LogXP (every quest in the
--                              -- log, those among them: XP, count), QuestColors (the bar's color for each)
--   xp:CreateBar(parent, source)   -- the bar widget; call bar:Update() when XP changes; source "xp" or "rep"
--                              -- holds it to one, nil follows what the bars show
--   xp:ShowTooltip(owner, hints, source)   -- the stats tooltip beside `owner`; call from its OnEnter, it hides on
--                              -- leave; hints: what `owner`'s clicks do, as Shy.Hover takes them; source "xp" or "rep"
--   xp:Share()                 -- puts your progress in the chat box
--   xp:SetDocked(by, docked)   -- `by` shows the bars itself: the game's bars stand down
--   xp:IsDocked(by)            -- `by` nil: anyone. "SHY_XP_DOCKED" fires on change
--   xp:IsOn()                  -- the bars go on the quest window (the setting; ShyQuest carries them there and
--                              -- docks). "SHY_XP_SWITCH" fires on change
--   xp:SetGoal(level, xp)      -- a tick on every bar at that XP of that level (a guide's grind target); nil clears it
--   xp.Stats.Mode()            -- what the bars show: "xp", "rep" (the reputation tracked) or nil (nothing).
--                              -- "SHY_XP_MODE" fires on change
--   xp:Reputation(any)         -- the reputation the bar shows (any: the one watched, a bar of its own beside
--                              -- XP): { name, word, color, next, into, span, eta } or nil
--   xp:UnderRoom()             -- the height the console keeps under its floor for the bars there, nil when they
--                              -- aren't there (ShyDock's layout reads it; the bars stand at its UnderSpan).
--                              -- "SHY_XP_PLACE" fires when you move the bars
--   xp:TrackMenu(owner)        -- the menu of what to track (XP, or a faction), opened at `owner`
--   The bars (CreateBar), the tooltip (ShowTooltip) and Share follow the mode.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats

T.Stats = S

function T:IsOn()
	return ns.Place() == "quest"
end

-- source: "xp" or "rep" holds the bar to one; nil follows what the bars show.
function T:CreateBar(parent, source)
	local bar = ns.CreateXPBar(parent)
	bar.source = source
	return bar
end

-- source: "xp" or "rep"; nil: what the bars show.
function T:ShowTooltip(owner, hints, source)
	ns.ShowSummaryTooltip(owner, hints, source)
end

function T:Share()
	ns.Share()
end

-- any: the faction watched, whatever the stats window's bar shows.
function T:Reputation(any)
	local Rep = ns.Rep
	if not (Rep and (Rep.On() or (any and Rep.Watched()))) then return nil end
	local into, span, data = Rep.Progress()
	local word, color = Rep.Standing(data.reaction)
	return { name = data.name, word = word, color = color, next = Rep.Next(data.reaction),
		into = into, span = span, eta = Rep.TimeToNext() }
end

function T:UnderRoom()
	return ns.Under and ns.Under.Room() or nil
end

function T:TrackMenu(owner)
	if ns.Rep then Shy.UI.ContextMenu(owner, ns.Rep.Menu) end
end

local docks = {}   -- by -> true

function T:SetDocked(by, docked)
	docked = docked and true or nil
	if docks[by] == docked then return end
	docks[by] = docked
	ns.dockedBy = next(docks)
	ns.UpdateBox()
	if ns.ApplyBlizzardBar then ns.ApplyBlizzardBar() end
	Shy:Fire("SHY_XP_DOCKED")
end

function T:IsDocked(by)
	if by then return docks[by] == true end
	return ns.dockedBy ~= nil
end

function T:SetGoal(level, xp)
	local goal = level and xp and { level = level, xp = xp } or nil
	if goal == nil and ns.goal == nil then return end
	if goal and ns.goal and goal.level == ns.goal.level and goal.xp == ns.goal.xp then return end
	ns.goal = goal
	for bar in pairs(ns.bars) do bar:Update() end
	if ns.Update then ns.Update() end
end
