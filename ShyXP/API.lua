-- Public API for other addons, as Shy.addons.XP (nil when ShyXP isn't loaded).
--   xp.Stats                   -- Active, Progress, Pace, TimeToLevel, Rested; Duration, Number, Short;
--                              -- QuestXP (the quests ready to hand in: XP, count), LogXP (every quest in the
--                              -- log, those among them: XP, count), QuestColors (the bar's color for each)
--   xp:CreateBar(parent)       -- the XP bar widget; call bar:Update() when XP changes
--   xp:ShowTooltip(owner, hints)   -- the stats tooltip beside `owner`; call from its OnEnter, it hides on leave;
--                              -- hints: what `owner`'s clicks do, as Shy.Hover takes them
--   xp:Share()                 -- puts your progress in the chat box
--   xp:SetDocked(by, docked)   -- `by` shows the level itself: hides the stats box and (hideWhenDocked) the default bar
--   xp:IsDocked(by)            -- `by` nil: anyone. "SHY_XP_DOCKED" fires on change
--   xp:IsOn()                  -- the stats box's switch; whoever shows the level in the box's place goes by it
--                              -- too. "SHY_XP_SWITCH" fires on change
--   xp:SetGoal(level, xp)      -- a tick on every bar at that XP of that level (a guide's grind target); nil clears it

local ADDON, ns = ...
local T, S = ns.T, ns.Stats

T.Stats = S

function T:IsOn()
	return T.db.box.shown and true or false
end

function T:CreateBar(parent)
	return ns.CreateXPBar(parent)
end

function T:ShowTooltip(owner, hints)
	ns.ShowSummaryTooltip(owner, hints)
end

function T:Share()
	ns.Share()
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
