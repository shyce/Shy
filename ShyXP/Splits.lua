-- Levelling splits: how long each level took, where its experience came from (quests, kills, everything
-- else) and how many deaths it cost, kept for every character on the account (ShyXPDB.runs, by GUID), and
-- set against another character's run: the one picked (T.db.compare), else the one that got furthest.
-- Time counts as the stats' own does (ShyXP.lua): played time while experience can be had.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local Splits = {}
ns.Splits = Splits

local TICK = 5               -- seconds between counts of played time
local SHOWN = 5              -- finished levels listed in the hover

local run                    -- this character's record: { name, class, realm, levels = { [n] = { t, x, q, k, d } } }
local mine                   -- this character's GUID
local lastXP, lastMax, lastLevel

local function Level(n)
	local levels = run.levels
	local at = levels[n]
	if not at then
		at = { t = 0, x = 0, q = 0, k = 0, d = 0 }
		levels[n] = at
	end
	return at
end

-- Seconds a level took in a run, or nil where the run has no whole record of it (begun before it was kept).
local function Took(record, n)
	local at, after = record.levels[n], record.levels[n + 1]
	if not at or not after or not at.whole then return nil end
	return at.t
end

-- Played time from the first level both runs have whole to the end of level `n`, or nil.
local function Through(record, n, from)
	local sum = 0
	for level = from, n do
		local took = Took(record, level)
		if not took then return nil end
		sum = sum + took
	end
	return sum
end

-- Every other character's run: { { guid, record, top } }, furthest first.
function Splits.Others()
	local out = {}
	for guid, record in pairs(T.db.runs) do
		if guid ~= mine and type(record) == "table" and record.levels then
			local top = 0
			for n in pairs(record.levels) do
				if Took(record, n) and n > top then top = n end
			end
			if top > 0 then out[#out + 1] = { guid = guid, record = record, top = top } end
		end
	end
	table.sort(out, function(a, b)
		if a.top ~= b.top then return a.top > b.top end
		return (a.record.name or "") < (b.record.name or "")
	end)
	return out
end

-- The run this one is set against: the one picked, else the furthest. nil for none.
function Splits.Against()
	local pick = T.db.compare
	if pick == "off" then return nil end
	local others = Splits.Others()
	for _, other in ipairs(others) do
		if other.guid == pick then return other.record end
	end
	return others[1] and others[1].record or nil
end

local function Short(seconds)
	return S.Duration(math.abs(seconds))
end

-- " · 4m faster than Brianna" for a level just finished, or "".
function Splits.Versus(n)
	if not run then return "" end
	local other, took = Splits.Against(), Took(run, n)
	local theirs = other and Took(other, n)
	if not took or not theirs then return "" end
	local gap = theirs - took
	if math.abs(gap) < 60 then return (" \194\183 as fast as %s"):format(other.name or "?") end
	return (" \194\183 %s %s than %s"):format(Short(gap), gap > 0 and "faster" or "slower", other.name or "?")
end

-- Where a level's experience came from, as shares: quests, kills, the rest.
function Splits.Sources(n)
	local at = run and run.levels[n]
	if not at or at.x <= 0 then return nil end
	local q, k = math.min(at.q, at.x), math.min(at.k, at.x)
	if q + k > at.x then k = at.x - q end
	return q / at.x, k / at.x, (at.x - q - k) / at.x
end

local function Percent(share)
	return math.floor(share * 100 + 0.5) .. "%"
end

-- "quests 62% · kills 31%" for a level.
function Splits.SourceText(n)
	local q, k, o = Splits.Sources(n)
	if not q then return nil end
	local parts = {}
	if q > 0 then parts[#parts + 1] = "quests " .. Percent(q) end
	if k > 0 then parts[#parts + 1] = "kills " .. Percent(k) end
	if o >= 0.05 then parts[#parts + 1] = "other " .. Percent(o) end
	return table.concat(parts, " \194\183 ")
end

-- A colored difference, "-4m" in mint (faster) or "+6m" in soft red, or "".
local function Gap(mineTook, theirs)
	if not mineTook or not theirs then return "" end
	local gap = mineTook - theirs
	if math.abs(gap) < 60 then return "" end
	return "  " .. Shy.Theme.Wrap(gap < 0 and C.good or C.bad, (gap < 0 and "-" or "+") .. Short(gap))
end

-- The hover's rows: the level under way, then the last SHOWN finished, each with its time and, against the
-- other run, the difference. And the total since both runs were kept, when there is one.
-- finished: the finished levels only (the hover says the level under way in its own section).
function Splits.Rows(finished)
	if not run then return nil end
	local _, _, level = S.Progress()
	local other = Splits.Against()
	local rows = {}
	local now = run.levels[level]
	if now and now.t > 0 and not finished then
		rows[#rows + 1] = { text = ("Level %d so far"):format(level), right = S.Duration(now.t), color = C.dim, rightColor = C.text }
		local from = Splits.SourceText(level)
		if from then rows[#rows + 1] = { text = from, quiet = true, indent = 2, color = C.dim } end
	end
	local first
	for n = level - 1, math.max(1, level - SHOWN), -1 do
		local took = Took(run, n)
		if took then
			first = n
			local theirs = other and Took(other, n)
			rows[#rows + 1] = { text = ("Level %d"):format(n), right = S.Duration(took) .. Gap(took, theirs), color = C.dim, rightColor = C.text }
		end
	end
	if other and first then
		local from = first
		for n = first - 1, 1, -1 do
			if Took(run, n) and Took(other, n) then from = n else break end
		end
		local ours, theirs = Through(run, level - 1, from), Through(other, level - 1, from)
		if ours and theirs then
			rows[#rows + 1] = { text = ("Levels %d to %d"):format(from, level - 1), right = S.Duration(ours) .. Gap(ours, theirs),
				color = C.dim, rightColor = C.text }
		end
	end
	if #rows == 0 then return nil end
	return rows, other and other.name
end

-- The last finished level as one line of the stats: "Level 11 took", "38m · 4m faster than Brianna". nil before one.
function Splits.Last()
	if not run then return nil end
	local _, _, level = S.Progress()
	local took = Took(run, level - 1)
	if not took then return nil end
	return ("Level %d took"):format(level - 1), S.Duration(took) .. Splits.Versus(level - 1)
end

-- Every level, as text: for the copy box.
function Splits.Report()
	if not run then return "No levels recorded yet." end
	local other = Splits.Against()
	local lines = { ("%s's levels%s"):format(run.name or "?", other and (", against " .. (other.name or "?")) or "") }
	local levels = {}
	for n in pairs(run.levels) do levels[#levels + 1] = n end
	table.sort(levels)
	for _, n in ipairs(levels) do
		local at, took = run.levels[n], Took(run, n)
		local theirs = other and Took(other, n)
		lines[#lines + 1] = ("%2d  %-8s %-10s %s  deaths %d%s"):format(n, took and S.Duration(took) or (S.Duration(at.t) .. "*"),
			theirs and ("vs " .. S.Duration(theirs)) or "", Splits.SourceText(n) or "", at.d,
			at.whole and "" or "  (started partway in)")
	end
	return table.concat(lines, "\n")
end

-- Counting

local function OnXP()
	local cur, max, level = S.Progress()
	if lastXP and level >= lastLevel then
		if level > lastLevel then
			Level(lastLevel).x = Level(lastLevel).x + math.max(0, lastMax - lastXP)
			-- A level begun now is kept whole from its first moment.
			Level(level).whole = true
			Level(level).x = Level(level).x + cur
		else
			Level(level).x = Level(level).x + math.max(0, cur - lastXP)
		end
	end
	lastXP, lastMax, lastLevel = cur, max, level
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, a, b)
	if not run then return end
	local _, _, level = S.Progress()
	if event == "PLAYER_XP_UPDATE" then
		OnXP()
	elseif event == "QUEST_TURNED_IN" then
		Level(level).q = Level(level).q + (b or 0)
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		local xp = S.KillXP(a)
		if xp then Level(level).k = Level(level).k + xp end
	elseif event == "PLAYER_DEAD" then
		Level(level).d = Level(level).d + 1
	end
end)

-- Starts counting for this character (ShyXP.lua's OnLogin).
function Splits.Start()
	local guid = UnitGUID("player")
	if guid == nil or issecretvalue(guid) then return end
	mine = guid
	run = T.db.runs[guid] or { levels = {} }
	T.db.runs[guid] = run
	local _, class = UnitClass("player")
	run.name, run.class, run.realm = UnitName("player"), class, GetRealmName()
	lastXP, lastMax, lastLevel = S.Progress()
	-- A level met with no record began before the run was kept, its time partial: unless nothing of it is had yet.
	if not run.levels[lastLevel] then Level(lastLevel).whole = lastXP == 0 or nil end
	for _, event in ipairs({ "PLAYER_XP_UPDATE", "QUEST_TURNED_IN", "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_DEAD" }) do
		events:RegisterEvent(event)
	end
	C_Timer.NewTicker(TICK, function()
		if S.Active() then
			local _, _, level = S.Progress()
			Level(level).t = Level(level).t + TICK
		end
	end)
end
