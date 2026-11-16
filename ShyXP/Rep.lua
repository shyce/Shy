-- Reputation: the faction you watch (the game's own watched faction, the one its reputation pane shows as
-- the experience bar), how far through its standing you are and how fast it climbs. At the top level it
-- takes the XP bar's place; below it, while you pick one to track. With nothing watched at the top level,
-- the next faction you gain with is watched.
--
--   Rep.On()          the bar shows reputation (S.Mode() == "rep")
--   Rep.Watched()     the game's watched faction (FactionData), or nil
--   Rep.Progress()    into, span (through this standing), the faction's data; nil with nothing watched
--   Rep.Standing(reaction)   its word and color; Rep.Next(reaction) the next one's word, nil at the top
--   Rep.Pace()        reputation an hour over the pace window, nil the first two minutes
--   Rep.TimeToNext()  seconds to the next standing at that pace
--   Rep.Session()     what this faction gained since you logged in or started tracking it
--   Rep.Record()      this character's record of it: { reaction, time, gains, gained, whole, past }
--   Rep.Average()     a gain on average; Rep.GainsToNext() kills or hand-ins to the next standing at it
--   Rep.Quests()      quests in your log that give it reputation: ready, all
--   Rep.Splits()      each standing behind: { reaction, time, whole }
--   Rep.Track(id)     id: watch that faction (and track it below the top); nil: back to XP; false: none
--   Rep.Menu(root)    the factions under their headers, for a context menu (UI.ContextMenu's writer)

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local Rep = {}
ns.Rep = Rep

local PACE_LEAST = 120          -- seconds of tracking before a pace is said
local gains = {}                -- { time, amount } for the watched faction
local last = {}                 -- the watched faction as last read: id, standing, reaction
local since = GetTime()         -- when its gains began to be counted
local gained = 0                -- this faction, since then
local seen = {}                 -- factionID -> standing, while the next gain is to be watched
local mode                      -- S.Mode() as last told

local function Char() return ns.char or {} end

function Rep.Watched()
	local data = C_Reputation.GetWatchedFactionData()
	if data and data.factionID ~= 0 then return data end
end

function Rep.On()
	if not Rep.Watched() then return false end
	if S.Active() then return ns.Place() == "box" and Char().track == "rep" end
	return T.db.repAtTop == true
end

-- The word for a standing, as the reputation pane says it, and its meaning color.
function Rep.Standing(reaction)
	local word = GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player"))
	local color = reaction <= 3 and C.bad or reaction == 4 and C.alert or C.good
	return word, color
end

function Rep.Next(reaction)
	if _G["FACTION_STANDING_LABEL" .. (reaction + 1)] == nil then return nil end
	return (Rep.Standing(reaction + 1))
end

function Rep.Progress()
	local data = Rep.Watched()
	if not data then return nil end
	local span = data.nextReactionThreshold - data.currentReactionThreshold
	local into = data.currentStanding - data.currentReactionThreshold
	if span <= 0 then span, into = 1, 1 end
	return math.min(into, span), span, data
end

local function Prune()
	local cutoff = GetTime() - T.db.paceWindow * 60
	while gains[1] and gains[1][1] < cutoff do table.remove(gains, 1) end
end

function Rep.Pace()
	Prune()
	local elapsed = math.min(GetTime() - since, T.db.paceWindow * 60)
	if elapsed < PACE_LEAST or #gains == 0 then return nil end
	local total = 0
	for _, g in ipairs(gains) do total = total + g[2] end
	return total / elapsed * 3600
end

function Rep.TimeToNext()
	local pace = Rep.Pace()
	local into, span, data = Rep.Progress()
	if not pace or pace <= 0 or not data or not Rep.Next(data.reaction) then return nil end
	return (span - into) / pace * 3600
end

function Rep.Session()
	return gained
end

-- The visible factions' standings, to find which one the next gain is with.
local function Look()
	wipe(seen)
	for index = 1, C_Reputation.GetNumFactions() do
		local data = C_Reputation.GetFactionDataByIndex(index)
		if data and data.factionID ~= 0 and (not data.isHeader or data.isHeaderWithRep) then
			seen[data.factionID] = data.currentStanding
		end
	end
end

-- char.stopped: you stopped tracking one yourself, so none is picked for you until you pick one.
local function Following()
	return T.db.repAtTop and not S.Active() and not Rep.Watched() and not Char().stopped
end

-- A faction gained with while nothing is watched at the top level: watched from now on (char.followed, given
-- back when reputation at max level is turned off: Rep.SetAtTop).
local function Follow()
	for index = 1, C_Reputation.GetNumFactions() do
		local data = C_Reputation.GetFactionDataByIndex(index)
		local before = data and seen[data.factionID]
		if before and data.currentStanding > before then
			C_Reputation.SetWatchedFactionByID(data.factionID)
			Char().followed = data.factionID
			return true
		end
	end
	Look()
	return false
end

-- The bar's mode changed: everything laid out again; else only the numbers.
local function Tell()
	-- What the bars show: the mode, and whether a faction has a bar of its own.
	local watched = Rep.Watched()
	local now = (S.Mode() or "none") .. (watched and ("+" .. watched.factionID) or "")
	if now ~= mode then
		mode = now
		ns.Refresh()
		Shy:Fire("SHY_XP_MODE")
	else
		ns.Soon()
	end
end

-- What this character has done with each faction it watched (ns.char.reps[factionID]): the standing it is in, the
-- time watched in it (`whole` once watched from its start), the gains in it and what they came to, and each
-- standing before as { time, whole } by its reaction.
local function Record(id)
	local char = ns.char
	if not char or not id then return nil end
	char.reps = char.reps or {}
	local rec = char.reps[id]
	if not rec then
		rec = { past = {}, time = 0, gains = 0, gained = 0 }
		char.reps[id] = rec
	end
	return rec
end

-- A standing begun: the one before kept with its time; the new one counted from nothing. `whole`: watched as it
-- began, so its time is all of it.
local function Begin(rec, reaction, whole)
	if rec.reaction and rec.time > 0 and reaction == rec.reaction + 1 then
		rec.past[rec.reaction] = { rec.time, rec.whole == true }
	end
	rec.reaction, rec.time, rec.gains, rec.gained, rec.whole = reaction, 0, 0, 0, whole or nil
end

local recent = {}   -- the watched faction's last gains, for what one is worth on average
local RECENT = 20

local function Read()
	local data = Rep.Watched()
	if not data then
		last.id = nil
	elseif data.factionID ~= last.id then
		last.id, last.standing, last.reaction = data.factionID, data.currentStanding, data.reaction
		wipe(gains)
		wipe(recent)
		since, gained = GetTime(), 0
		local rec = Record(data.factionID)
		if rec and rec.reaction ~= data.reaction then Begin(rec, data.reaction, false) end
	elseif data.currentStanding ~= last.standing then
		local delta = data.currentStanding - last.standing
		local rec = Record(data.factionID)
		if data.reaction ~= last.reaction and rec then Begin(rec, data.reaction, data.reaction > last.reaction) end
		if delta > 0 then
			gains[#gains + 1] = { GetTime(), delta }
			gained = gained + delta
			recent[#recent + 1] = delta
			if #recent > RECENT then table.remove(recent, 1) end
			-- (A gain that crossed into a new standing counts only what it brought past the threshold.)
			local mine = data.reaction ~= last.reaction and (data.currentStanding - data.currentReactionThreshold) or delta
			if rec then rec.gains, rec.gained = rec.gains + 1, rec.gained + math.min(delta, mine) end
		end
		last.standing, last.reaction = data.currentStanding, data.reaction
	end
end

-- The watched faction's record (Record), or nil.
function Rep.Record()
	local data = Rep.Watched()
	return data and Record(data.factionID) or nil
end

-- What a gain has come to on average (this session's last few, else this standing's), or nil before any.
function Rep.Average()
	if #recent > 0 then
		local total = 0
		for _, amount in ipairs(recent) do total = total + amount end
		return total / #recent
	end
	local rec = Rep.Record()
	if rec and rec.gains > 0 then return rec.gained / rec.gains end
end

-- Kills or hand-ins to the next standing at that average, or nil.
function Rep.GainsToNext()
	local average = Rep.Average()
	local into, span, data = Rep.Progress()
	if not average or average <= 0 or not data or not Rep.Next(data.reaction) then return nil end
	return math.ceil((span - into) / average)
end

-- The quests in your log that give the watched faction reputation: how many are ready to hand in, and how many in
-- all. (The client says whether a quest gives it, not how much.) Counted again after the log changes.
local quests = { stale = true, ready = 0, all = 0 }
function Rep.Quests()
	local data = Rep.Watched()
	if not data then return 0, 0 end
	if quests.stale or quests.id ~= data.factionID then
		quests.stale, quests.id, quests.ready, quests.all = false, data.factionID, 0, 0
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			local id = info and not info.isHeader and not info.isHidden and info.questID
			if id and not C_QuestLog.IsFailed(id) and C_QuestLog.DoesQuestAwardReputationWithFaction(id, data.factionID) then
				quests.all = quests.all + 1
				if C_QuestLog.IsComplete(id) or C_QuestLog.ReadyForTurnIn(id) then quests.ready = quests.ready + 1 end
			end
		end
	end
	return quests.ready, quests.all
end

-- Each standing behind, oldest first: { reaction, time, whole }.
function Rep.Splits()
	local rec = Rep.Record()
	local list = {}
	if not rec then return list end
	for reaction, entry in pairs(rec.past) do list[#list + 1] = { reaction = reaction, time = entry[1], whole = entry[2] } end
	table.sort(list, function(a, b) return a.reaction < b.reaction end)
	return list
end

local reading = false
local function Changed()
	if reading then return end
	reading = true
	if Following() then Follow() end
	Read()
	reading = false
	Tell()
end

-- In the stats window one bar shows: XP, or the faction you track in its place. On the quest window and under
-- the action bars the faction has a bar of its own beside your XP.
local function Swaps()
	return ns.Place() == "box" and S.Active()
end

function Rep.Track(id)
	local char = Char()
	if id then
		char.track = Swaps() and "rep" or nil
		char.stopped, char.followed = nil, nil
		C_Reputation.SetWatchedFactionByID(id)
	elseif id == false then
		char.track = nil
		char.stopped, char.followed = true, nil
		C_Reputation.SetWatchedFactionByIndex(0)
	else
		char.track = nil
	end
	Changed()
end

-- Reputation at max level on or off. Off, a faction it picked for you is no longer watched; on, the next
-- gain is followed again.
function Rep.SetAtTop(on)
	local char = Char()
	T.db.repAtTop = on and true or false
	local watched = Rep.Watched()
	if not on and char.followed and watched and watched.factionID == char.followed then
		C_Reputation.SetWatchedFactionByIndex(0)
	end
	char.stopped, char.followed = nil, nil
	if Following() then Look() end
	if ns.Refresh then ns.Refresh() end
	Changed()
end

-- Every faction under its header. Headers the reputation pane has folded are opened to be read and folded
-- again as they were.
local function Factions()
	local groups, group, opened = {}, nil, {}
	local index = 1
	while index <= C_Reputation.GetNumFactions() do
		local data = C_Reputation.GetFactionDataByIndex(index)
		if data and data.isHeader and data.isCollapsed then
			opened[#opened + 1] = data.name
			C_Reputation.ExpandFactionHeader(index)
			data = C_Reputation.GetFactionDataByIndex(index)
		end
		if data then
			if data.isHeader and not data.isChild then
				group = { name = data.name, list = {} }
				groups[#groups + 1] = group
			end
			if (not data.isHeader or data.isHeaderWithRep) and data.factionID ~= 0 then
				if not group then
					group = { name = REPUTATION, list = {} }
					groups[#groups + 1] = group
				end
				group.list[#group.list + 1] = { id = data.factionID, name = data.name, reaction = data.reaction }
			end
		end
		index = index + 1
	end
	for k = #opened, 1, -1 do
		for i = 1, C_Reputation.GetNumFactions() do
			local data = C_Reputation.GetFactionDataByIndex(i)
			if data and data.isHeader and data.name == opened[k] then
				C_Reputation.CollapseFactionHeader(i)
				break
			end
		end
	end
	return groups
end

function Rep.Menu(root)
	reading = true   -- opening folded headers tells of a change: not one of yours
	local groups = Factions()
	reading = false
	local watched = Rep.Watched()
	local swaps = Swaps()
	if swaps then
		root:CreateRadio("Experience", function() return not Rep.On() end, function() Rep.Track(nil) end)
	end
	for _, group in ipairs(groups) do
		if #group.list > 0 then
			local sub = root:CreateButton(group.name)
			for _, faction in ipairs(group.list) do
				local id = faction.id
				local entry = sub:CreateRadio(faction.name, function()
					local now = Rep.Watched()
					return (not Swaps() or Rep.On()) and now ~= nil and now.factionID == id
				end, function() Rep.Track(id) end)
				entry:SetDetail((Rep.Standing(faction.reaction)))
			end
		end
	end
	if watched and not swaps then
		root:CreateDivider()
		root:CreateButton("Stop tracking " .. watched.name, function() Rep.Track(false) end)
	end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" then
		quests.stale = true
	elseif event == "PLAYER_LEVEL_UP" then
		-- The top level reached: reputation takes over (the level is told before it shows in UnitLevel).
		C_Timer.After(0, function()
			if Following() then Look() end
			Tell()
		end)
	else
		Changed()
	end
end)

function Rep.Start()
	local watched = Rep.Watched()
	mode = (S.Mode() or "none") .. (watched and ("+" .. watched.factionID) or "")
	Read()
	if Following() then Look() end
	events:RegisterEvent("UPDATE_FACTION")
	events:RegisterEvent("PLAYER_LEVEL_UP")
	events:RegisterEvent("QUEST_LOG_UPDATE")
	-- The time in a standing: counted while it is watched.
	C_Timer.NewTicker(5, function()
		local rec = Rep.Record()
		if rec then rec.time = rec.time + 5 end
	end)
end
