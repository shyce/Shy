-- Tracks the levelling stats (XP per hour, time to level, quest XP, kills, rested). Bar.lua and Box.lua show them.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "XP",
	category = "leveling",
	icon = "Interface\\AddOns\\ShyXP\\Media\\ShyXP",
	smallIcon = "Interface\\AddOns\\ShyXP\\Media\\ShyXPSmall",
	savedVariables = "ShyXPDB",
	keep = { runs = true },                -- every character's levels belong to the account (Splits.lua)
	defaults = {
		runs = {},                         -- by character GUID: name, class, realm, levels
		compare = "auto",                  -- the run splits are set against: auto (the furthest) | off | a GUID
		barStyle = "shy",                  -- shy (our bar over the default one) | blizzard
		place = "quest",                -- where the bars go: quest (the quest window, with ShyQuest) | under (the
		                                   -- game's own bars under the action bars, restyled) | box (the stats window)
		bubbles = true,
		blizzText = false,                 -- the default "XP: 1234 / 5000" text (blizzard style only)
		questOverlay = true,
		questColor = { 1, 0.78, 0.25 },    -- the band for quests ready to hand in
		logColor = { 0.82, 0.46, 0.22 },   -- the band for every quest in the log
		barText = "hover",                 -- hover | always | off
		tooltip = true,
		lines = { pace = true, eta = true, bubbles = true, quests = true, kills = true, rested = true, level = true, splits = true },
		paceWindow = 20,                   -- minutes
		levelSummary = true,
		repAtTop = true,                   -- at the top level the bar shows the reputation you watch (Rep.lua)
		box = {
			style = "card",                -- card | compact
			hideInCombat = false,
			tiles = { eta = true, bubbles = true, pace = true, quests = true, log = true, kills = true, rested = true, level = true },
			repTiles = { eta = true, pace = true, count = true, session = true, quests = true, time = true },
		},
	},
})
ns.T = T

-- The stats as they came before every one was on (T:OnLoad tells them from ones you switched).
local FIRST_TILES = { eta = true, bubbles = false, pace = true, quests = true, log = false, kills = true, rested = false, level = false }

local S = {}
ns.Stats = S

local char                 -- per-character: time, kills and quests on this level
local gains = {}           -- { time, amount }
local kills = {}           -- XP of the last 10 kills
local lastXP, lastMax, lastLevel
local sessionStart = GetTime()
local questXP, questCount = 0, 0   -- the quests ready to hand in
local logXP, logCount = 0, 0       -- every quest in the log, those among them

function S.Duration(seconds)
	if not seconds or seconds ~= seconds or seconds == math.huge then return "?" end
	seconds = math.floor(seconds)
	if seconds < 60 then return "<1m" end
	local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
	if h == 0 then return m .. "m" end
	if h >= 48 then return math.floor(h / 24) .. "d " .. h % 24 .. "h" end
	return h .. "h " .. m .. "m"
end

-- 950 -> "950", 12400 -> "12.4k", 1250000 -> "1.3m"
function S.Short(n)
	if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
	if n >= 1e4 then return ("%.1fk"):format(n / 1e3) end
	return S.Number(n)
end

function S.Count(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

function S.Number(n)
	return BreakUpLargeNumbers(math.floor(n + 0.5))
end

function S.Active()
	return not GameRulesUtil.IsPlayerAtEffectiveMaxLevel() and not IsXPUserDisabled()
end

-- Where the bars go (T.db.place). The quest window is offered only with ShyQuest loaded; without it the
-- bars go under the action bars.
function ns.Place()
	if T.db.place == "quest" and not Shy.addons.Quest then return "under" end
	return T.db.place
end

function ns.Places()
	local list = {}
	if Shy.addons.Quest then list[#list + 1] = { value = "quest", text = "On the quest window" } end
	list[#list + 1] = { value = "under", text = "Under the action bars" }
	list[#list + 1] = { value = "box", text = "Stats window" }
	return list
end

function ns.SetPlace(place)
	local moved = T.db.place ~= place
	T.db.place = place
	ns.Refresh()
	if ns.ApplyBlizzardBar then ns.ApplyBlizzardBar() end
	if moved then Shy:Fire("SHY_XP_PLACE") end
end

-- What the bar shows: "rep" (the faction you track, Rep.lua), "xp", or nil (nothing: the top level with
-- no reputation watched).
function S.Mode()
	if ns.Rep and ns.Rep.On() then return "rep" end
	if S.Active() then return "xp" end
	return nil
end

-- While zoning the client can briefly report 0 max XP or level 0; reuse the last good reading.
local lastGood = { 0, 1, 1 }

function S.Progress()
	local cur, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
	if max <= 0 or level <= 0 then
		return lastGood[1], lastGood[2], lastGood[3]
	end
	lastGood[1], lastGood[2], lastGood[3] = cur, max, level
	return cur, max, level
end

local function Prune()
	local cutoff = GetTime() - T.db.paceWindow * 60
	while gains[1] and gains[1][1] < cutoff do table.remove(gains, 1) end
end

-- XP per hour over the last paceWindow minutes; nil for the first two minutes of a session.
function S.Pace()
	Prune()
	local elapsed = math.min(GetTime() - sessionStart, T.db.paceWindow * 60)
	if elapsed < 120 or #gains == 0 then return nil end
	local total = 0
	for _, g in ipairs(gains) do total = total + g[2] end
	return total / elapsed * 3600
end

function S.TimeToLevel()
	local pace = S.Pace()
	if not pace or pace <= 0 then return nil end
	local cur, max = S.Progress()
	return (max - cur) / pace * 3600
end

-- 20 bubbles a level, 5% each.
function S.Bubbles()
	local cur, max = S.Progress()
	return (max - cur) / max * 20
end

-- What the quests ready to hand in are worth, and how many they are.
function S.QuestXP()
	return questXP, questCount
end

-- What the whole log would be worth with every quest in it done (the ready ones among them), and how many.
function S.LogXP()
	return logXP, logCount
end

-- The two quest bands' colors: ready to hand in, the whole log.
function S.QuestColors()
	return T.db.questColor, T.db.logColor
end

function S.KillsToLevel()
	if #kills == 0 then return nil end
	local total = 0
	for _, xp in ipairs(kills) do total = total + xp end
	local average = total / #kills
	local cur, max = S.Progress()
	return math.ceil((max - cur) / average), average
end

-- Returns rested XP, its share of a level, and seconds until full while resting (5% per 8 hours, cap 1.5 levels).
function S.Rested()
	local rested = GetXPExhaustion() or 0
	local _, max = S.Progress()
	local full
	if IsResting() then
		local cap = max * 1.5
		if rested < cap then full = (cap - rested) / (max * 0.05 / 8) * 3600 end
	end
	return rested, rested / max, full
end

function S.ThisLevel()
	return char.time, char.kills, char.quests
end

function S.ResetLevel()
	char.level, char.time, char.kills, char.quests = select(3, S.Progress()), 0, 0, 0
end

-- "Level 23 at 64% · ~1h 12m to 24 · 3 quests ready (+2,350 XP)"
function S.ShareText()
	local cur, max, level = S.Progress()
	local parts = { ("Level %d at %d%%"):format(level, math.floor(cur / max * 100)) }
	local eta = S.TimeToLevel()
	if eta then parts[#parts + 1] = ("~%s to %d"):format(S.Duration(eta), level + 1) end
	local q, n = S.QuestXP()
	if n > 0 then parts[#parts + 1] = ("%d quest%s ready (+%s XP)"):format(n, n == 1 and "" or "s", S.Number(q)) end
	return table.concat(parts, " \194\183 ")
end

-- Only the quests the log shows you count: none the game keeps out of sight, and none that failed.
local function ScanQuests()
	questXP, questCount, logXP, logCount = 0, 0, 0, 0
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		local id = info and not info.isHeader and not info.isHidden and not info.isTask and not info.isBounty and info.questID
		if id and not C_QuestLog.IsFailed(id) then
			local xp = GetQuestLogRewardXP(id) or 0
			logXP, logCount = logXP + xp, logCount + 1
			if C_QuestLog.IsComplete(id) or C_QuestLog.ReadyForTurnIn(id) then
				questXP, questCount = questXP + xp, questCount + 1
			end
		end
	end
end

-- Matches "Kobold Vermin dies, you gain 45 experience."; unanchored at the end because a rested bonus may follow.
local KILL_PATTERN = "^" .. COMBATLOG_XPGAIN_FIRSTPERSON
	:gsub("%.$", "")
	:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	:gsub("%%%%s", ".-")
	:gsub("%%%%d", "(%%d+)")

-- The experience a kill's chat line names, or nil for any other line (Splits.lua reads it too).
function S.KillXP(text)
	if type(text) ~= "string" or issecretvalue(text) then return nil end
	return tonumber(text:match(KILL_PATTERN))
end

local function OnXPUpdate()
	local cur, max, level = S.Progress()
	if lastXP then
		local gained = level > lastLevel and (lastMax - lastXP) + cur or cur - lastXP
		if gained > 0 then table.insert(gains, { GetTime(), gained }) end
	end
	lastXP, lastMax, lastLevel = cur, max, level
	ns.Soon()
end

-- The quest log tells of a change many times over (a kill, a loot): read once, the frame after.
local scanning = false
local function QuestsChanged()
	if scanning then return end
	scanning = true
	C_Timer.After(0, function()
		scanning = false
		ScanQuests()
		ns.Update()
	end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		if event == "PLAYER_XP_UPDATE" then OnXPUpdate() else ns.Soon() end
	elseif event == "QUEST_LOG_UPDATE" then
		QuestsChanged()
	elseif event == "QUEST_TURNED_IN" then
		char.quests = char.quests + 1
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		local xp = S.KillXP(...)
		if xp then
			char.kills = char.kills + 1
			table.insert(kills, xp)
			if #kills > 10 then table.remove(kills, 1) end
		end
	elseif event == "PLAYER_LEVEL_UP" then
		local newLevel = ...
		if T.db.levelSummary then
			local versus = ns.Splits and ns.Splits.Versus(newLevel - 1) or ""
			T:Print(("reached |cffffd200level %d|r. Level %d took %s \194\183 %s \194\183 %s%s"):format(
				newLevel, newLevel - 1, S.Duration(char.time), S.Count(char.kills, "kill"), S.Count(char.quests, "quest"), versus))
		end
		S.ResetLevel()
		char.level = newLevel
		wipe(kills)
		QuestsChanged()   -- a quest pays by your level: what the log is worth has changed
	end
end)

-- Settings saved before the bars had a place (box.full unset), carried over once. fresh: nothing was saved.
--   The stats window turned off, or the game's bar kept beside the quest window: the bars go under the
--   action bars (shown and hideWhenDocked are read here alone).
--   Stats never switched from how they came: every one on, the card has room for them all now.
function ns.CarryOver(db, fresh)
	local box = db.box
	if box.full then return end
	if not fresh then
		if box.shown == false or db.hideWhenDocked == false then db.place = "under" end
		local untouched = true
		for key, was in pairs(FIRST_TILES) do
			if box.tiles[key] ~= was then untouched = false end
		end
		if untouched then
			for key in pairs(box.tiles) do box.tiles[key] = true end
		end
	end
	box.shown, db.hideWhenDocked = nil, nil
	box.full = true
end

function T:OnLoad()
	ShyXPCharDB = ShyXPCharDB or {}
	char = ShyXPCharDB
	ns.char = char
	ns.CarryOver(self.db, self.isNew)
	-- A reputation stat new since the switches were saved starts on.
	local box = self.db.box
	box.repTiles = box.repTiles or {}
	for _, def in ipairs(ns.REP_TILES or {}) do
		if box.repTiles[def.key] == nil then box.repTiles[def.key] = true end
	end
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	-- Levelled while the addon was off: this level's counts are stale.
	if char.level ~= select(3, S.Progress()) or not char.time then S.ResetLevel() end
	lastXP, lastMax, lastLevel = S.Progress()
	ScanQuests()
	for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "QUEST_LOG_UPDATE",
		"QUEST_TURNED_IN", "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_LEVEL_UP" }) do
		events:RegisterEvent(event)
	end
	C_Timer.NewTicker(5, function() if S.Active() then char.time = char.time + 5 end end)
	if ns.Rep then ns.Rep.Start() end
	ns.SetupBar()
	ns.SetupBox()
	if ns.Under then ns.Under.Start() end
	if ns.Splits then ns.Splits.Start() end
end

-- source: "xp" or "rep"; else what the bar shows.
function ns.Share(source)
	local text = (source or S.Mode()) == "rep" and ns.BarText("rep") or S.ShareText()
	local editBox = ChatFrameUtil.GetActiveWindow()
	if editBox then editBox:Insert(text) else ChatFrameUtil.OpenChat(text) end
end

SLASH_SHYXP1 = "/shyxp"
SlashCmdList.SHYXP = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "share" then
		ns.Share()
	elseif cmd == "reset" then
		S.ResetLevel()
		T:Print("this level's time, kills and quests were reset.")
	elseif cmd == "splits" and ns.Splits then
		Shy.UI.ShowCopyBox("ShyXP: levels", ns.Splits.Report())
	elseif cmd == "" then
		T:OpenOptions()
	else
		T:Print("commands:")
		print("  /shyxp  - open options")
		print("  /shyxp share  - put your progress in the chat box")
		print("  /shyxp reset  - reset this level's time, kills and quests")
		print("  /shyxp splits  - every level's time, against another character")
	end
end
