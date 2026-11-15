-- The player, the quest log, and which quests are available. The game doesn't report available
-- quests, so they are derived from the data's rules (level, faction, class, prerequisites,
-- exclusions, professions, reputation). A quest whose rule can't be checked isn't offered.

local ADDON, ns = ...
local T = ns.T
local D = ns.Data

local L = {}
ns.Log = L

L.entries = {}     -- by quest ID: { id, title, level, complete, failed, header (its zone heading),
                   --   ends, time (timed quests: deadline by GetTime, and the total allowed) }
L.order = {}       -- the same entries, in quest log order

local me = { level = 1, side = "", race = 0, class = 0, trivial = 0, maps = {} }
local MEAGRE = 0.4   -- a quest giving less than this share of its XP (L.Share) is outgrown
local starts = {}  -- map -> available quests there (cache)
local known        -- level and log contents when the cache was built

-- Incremented when available quests may have changed (Zones.lua caches on it).
L.version = 0
-- Incremented on every log scan (Index.lua caches on it).
L.stamp = 0

-- The player

-- Bit `index` (from 1) of a mask.
local function HasBit(mask, index)
	return math.floor(mask / 2 ^ (index - 1)) % 2 == 1
end

function L.ReadPlayer()
	me.level = UnitLevel("player")
	local faction = UnitFactionGroup("player")
	me.side = faction == "Alliance" and "A" or faction == "Horde" and "H" or ""
	local _, _, race = UnitRace("player")
	local _, _, class = UnitClass("player")
	me.race, me.class = race or 0, class or 0
	me.trivial = UnitQuestTrivialLevelRange("player") or 0
	-- (Who the character is came to be known, or changed: what a map may ever offer them is read again.)
	local who = me.side .. ":" .. me.race .. ":" .. me.class
	if who ~= me.who then
		me.who = who
		wipe(me.maps)
	end
end

function L.Level() return me.level end
function L.Side() return me.side end

-- Whether an NPC is friendly to the player's faction. Neutral NPCs have no side in the data.
function L.Friendly(npc)
	return npc.side == "" or me.side == "" or npc.side:find(me.side, 1, true) ~= nil
end

-- The quest log

-- Each scan is compared with the previous one and watchers are called as
-- fn(kind, entry, goal, index), kind "progress" (a count went up), "objective" (one finished)
-- or "ready" (quest can be turned in). Not for QUIET seconds after the first scan: the game
-- fills objective counts in gradually at login.
local QUIET = 5
local before, firstRead
local watchers = {}

-- Restarts the quiet period (after a loading screen).
function L.Hush()
	firstRead = nil
end

function L.OnProgress(fn)
	watchers[#watchers + 1] = fn
end

local function Tell(kind, entry, goal, index)
	for _, fn in ipairs(watchers) do fn(kind, entry, goal, index) end
end

-- Sets entry.goals = { { text, have, need, finished }, ... } and reports changes.
local function Compare()
	local now = {}
	for _, entry in ipairs(L.order) do
		local goals = {}
		for i, objective in ipairs(C_QuestLog.GetQuestObjectives(entry.id) or {}) do
			goals[i] = { text = objective.text, have = objective.numFulfilled or 0, need = objective.numRequired or 0,
				finished = objective.finished and true or false }
		end
		entry.goals = goals
		now[entry.id] = entry
	end
	-- What this scan changed, for a loot that only moves a count or finishes a drop: the route can keep
	-- the other quests' stops. none: the log said nothing new. counts: a count went up, nothing finished.
	-- ready: one or more quests can be turned in, and nothing else about the log changed. changed: the
	-- log's quests came or went, or an objective finished while the quest still has work.
	local delta = "changed"
	local ready
	if before then
		delta = "none"
		local same = true
		for id in pairs(now) do if not before[id] then same = false end end
		for id in pairs(before) do if not now[id] then same = false end end
		if not same then
			delta = "changed"
		else
			for id, entry in pairs(now) do
				local old = before[id]
				if entry.failed ~= old.failed then
					delta = "changed"
				elseif entry.complete ~= old.complete then
					if entry.complete and not old.complete then
						ready = ready or {}
						ready[#ready + 1] = id
						if delta ~= "changed" then delta = "ready" end
					else
						delta = "changed"
					end
				end
				local oldGoals = old.goals or {}
				if #entry.goals ~= #oldGoals then
					delta = "changed"
				else
					for i, goal in ipairs(entry.goals) do
						local was = oldGoals[i]
						if not was then
							delta = "changed"
						elseif goal.finished and not was.finished then
							if not entry.complete then delta = "changed" end
						elseif goal.have ~= was.have and delta == "none" then
							delta = "counts"
						end
					end
				end
			end
		end
	end
	L.delta = { kind = delta, ready = ready }
	firstRead = firstRead or GetTime()
	if before and GetTime() - firstRead >= QUIET then
		for id, entry in pairs(now) do
			local old = before[id]
			if old then
				for i, goal in ipairs(entry.goals) do
					local was = old.goals[i]
					if was and goal.finished and not was.finished then
						Tell("objective", entry, goal, i)
					elseif was and not goal.finished and goal.have > was.have then
						Tell("progress", entry, goal, i)
					end
				end
				if entry.complete and not old.complete then Tell("ready", entry) end
			end
		end
	end
	before = now
end

-- A running timed quest's deadline (by GetTime) and total time allowed.
local function Deadline(id)
	local total, elapsed = C_QuestLog.GetTimeAllowed(id)
	if total and elapsed and total > 0 and elapsed < total then return GetTime() + total - elapsed, total end
end

function L.Scan()
	L.stamp = L.stamp + 1
	wipe(L.entries)
	wipe(L.order)
	local header
	for index = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(index)
		if info and info.isHeader then
			header = info.title
		elseif info and not info.isHidden and not info.isTask and not info.isBounty then
			local id = info.questID
			local entry = {
				id = id,
				title = info.title,
				level = info.level,
				complete = (C_QuestLog.IsComplete(id) or C_QuestLog.ReadyForTurnIn(id)) and true or false,
				failed = C_QuestLog.IsFailed(id) and true or false,
				header = header,
			}
			if not entry.failed then entry.ends, entry.time = Deadline(id) end
			L.entries[id] = entry
			L.order[#L.order + 1] = entry
		end
	end
	-- Quests held (including hidden ones the game counts) and the log's capacity.
	local _, held = C_QuestLog.GetNumQuestLogEntries()
	L.held, L.most = held or #L.order, C_QuestLog.GetMaxNumQuestsCanAccept()
	-- Available quests only change when the log's contents or the level do.
	local ids = {}
	for i, entry in ipairs(L.order) do ids[i] = entry.id end
	table.sort(ids)
	local now = me.level .. ":" .. table.concat(ids, ",")
	if now ~= known then
		known = now
		L.ForgetOffers()
	end
	Compare()
end

function L.Full()
	return L.most ~= nil and (L.held or 0) >= L.most
end

-- Unfinished quests best dropped, most droppable first: { entry, why }. Failed, outgrown, or
-- not wanted by the guide (wanted(id)); between equals, one with no progress goes first.
function L.Spare(wanted)
	local list = {}
	for _, entry in ipairs(L.order) do
		if not entry.complete then
			local score, why = 0, nil
			if entry.failed then
				score, why = 4, "failed"
			elseif L.Share(entry.level or 0) < MEAGRE then
				score, why = 3, ("pays %d%%"):format(math.floor(L.Share(entry.level or 0) * 100 + 0.5))
			end
			if wanted and not wanted(entry.id) then
				score = score + 2
				why = why or "not in your guide"
			end
			if score > 0 then
				local begun = false
				for _, goal in ipairs(entry.goals or {}) do
					if goal.finished or goal.have > 0 then begun = true end
				end
				list[#list + 1] = { entry = entry, why = why, score = score + (begun and 0 or 0.5) }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.entry.id < b.entry.id
	end)
	return list
end

function L.Has(id) return L.entries[id] ~= nil end

-- A failed quest stays in the log until it is abandoned and accepted again.
function L.Failed(id)
	local entry = L.entries[id]
	return entry ~= nil and entry.failed
end

-- In the log and not failed.
function L.Holds(id)
	local entry = L.entries[id]
	return entry ~= nil and not entry.failed
end

-- A running timed quest: seconds left and total. nil otherwise.
function L.Clock(id)
	local entry = L.entries[id]
	local left = entry and entry.ends and entry.ends - GetTime()
	if left and left > 0 then return left, entry.time end
end

-- Abandons a quest with the same calls as Blizzard's quest log (QuestMapFrame.lua).
function L.Abandon(id)
	local was = C_QuestLog.GetSelectedQuest()
	C_QuestLog.SetSelectedQuest(id)
	C_QuestLog.SetAbandonQuest()
	C_QuestLog.AbandonQuest()
	if was and was ~= 0 and was ~= id then C_QuestLog.SetSelectedQuest(was) end
	PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
end

-- Abandons a failed quest (a click on the card's line). Failure is re-checked with the game at
-- the click, so a stale line can't abandon a healthy quest.
function L.AbandonFailed(id)
	if not L.Has(id) or not C_QuestLog.IsFailed(id) or not C_QuestLog.CanAbandonQuest(id) then return false end
	local title = L.entries[id].title or C_QuestLog.GetTitleForQuestID(id) or "the quest"
	L.Abandon(id)
	T:Print(("abandoned the failed quest |cffffffff%s|r. You can accept it again."):format(title))
	return true
end
-- Asked hundreds of times while a route is built, of a few hundred quests: while one is (L.Building), the
-- game's answer for each is asked once and kept to the end of that build; at any other time it is asked.
local done = {}
function L.Done(id)
	if not done.on then return C_QuestLog.IsQuestFlaggedCompleted(id) end
	local known = done[id]
	if known == nil then
		known = C_QuestLog.IsQuestFlaggedCompleted(id) or false
		done[id] = known
	end
	return known
end
function L.Building(on)
	wipe(done)
	done.on = on or nil
end

-- Abandoned quests are remembered per character (ns.char.dropped) until accepted again; the
-- game keeps no record. Index.lua uses it to tell leftover quest items (I.Quests).
-- QUEST_TURNED_IN and QUEST_REMOVED come in no fixed order: both orders give the same result.
local handed = {}   -- quests turned in this session

-- The items a quest in the log needs and doesn't count that the bags have held since it was taken
-- (ns.char.had: [item] = true). One of those gone again was used (a key in its lock, a candle that
-- called its ghost), and nobody is sent for another. The game keeps no record of it.
local function Had()
	local had = ns.char.had
	if not had then
		had = {}
		ns.char.had = had
	end
	return had
end

function L.Had(item) return Had()[item] == true end

-- Had and gone, and never more than one of it carried: it was used. Something that stacks is used one
-- at a time (a pick broken for each tool, a feather laid in each nest): with none left, more are needed.
local function UsedUp(item)
	return L.Had(item) and (C_Item.GetItemMaxStackSizeByID(item) or 1) <= 1
end

-- A quest come into the log or gone from it: what it needs has not been had (yet, or any more).
local function Unhad(id)
	local quest = D.Quest(id)
	for _, token in ipairs(quest and quest.goals or {}) do
		if token.kind == "s" then Had()[token.id] = nil end
	end
end

function L.Left(id, handedIn)
	local dropped = ns.char.dropped
	if handedIn then
		handed[id], dropped[id] = true, nil
	elseif not handed[id] and not L.Done(id) then
		dropped[id] = true
	end
	Unhad(id)
end

function L.Taken(id)
	handed[id], ns.char.dropped[id] = nil, nil
	Unhad(id)
end

function L.Dropped(id) return ns.char.dropped[id] == true end

-- Whether the data says where an item is had: something out in the world drops, holds or sells it.
local function Sourced(id)
	local item = D.Item(id)
	for _, source in ipairs(item and item.sources or {}) do
		local thing = D.Thing(source.kind, source.id)
		if thing and #thing.places > 0 and (source.kind ~= "v" or L.Friendly(thing)) then return true end
	end
	for _, npc in ipairs(item and item.more or {}) do
		local thing = D.Npc(npc)
		if thing and #thing.places > 0 then return true end
	end
	return false
end

-- An objective's line past the dash and the count the game may lead it with: the game's own strings
-- put the count first ("- 3/8 Goretusk Liver", "3/15 Defias Trapper slain"), the quest log after.
local function Unled(text)
	return (text:gsub("^[%s%-]+", ""):gsub("^%d+/%d+%s+", ""))
end

-- Whether an objective's line is about this thing: it starts with its name, then the count
-- ("Dewy Lasher Frond: 0/6") or " slain" ("Webwood Spider slain: 3/10"). Containing the name is not
-- being about it: "Night Web Spider" is in "Young Night Web Spider slain", "Kobold" in "Kobold Worker slain".
local function Names(text, name)
	if type(text) ~= "string" or type(name) ~= "string" or name == "" then return false end
	text = Unled(text)
	if text:sub(1, #name) ~= name then return false end
	local after = text:sub(#name + 1, #name + 1)
	return after == "" or after == ":" or text:sub(#name + 1, #name + 6) == " slain"
end
L.Names = Names

-- Whether the line starts with the name and goes on in other words ("Cauldron used: 0/1"), never
-- with more of a longer name.
local function Starts(text, name)
	if type(text) ~= "string" or type(name) ~= "string" or name == "" then return false end
	text = Unled(text)
	if text:sub(1, #name) ~= name then return false end
	return text:sub(#name + 1, #name + 1):match("%a") == nil
end

-- Whether the line ends with the name, after words of its own and before any count ("Shut off Main
-- Control Valve: 0/1"), never as the tail of a longer name.
local function Ends(text, name)
	if type(text) ~= "string" or type(name) ~= "string" or name == "" then return false end
	local line = (text:gsub(":%s*%d+%s*/%s*%d+%s*$", ""))
	if #line <= #name or line:sub(-#name) ~= name then return false end
	return line:sub(-#name - 1, -#name - 1):match("%a") == nil
end

local function NameOf(token)
	local thing = token.kind == "i" and D.Item(token.id) or D.Thing(token.kind, token.id)
	return thing and thing.name or ""
end

-- A quest's objectives with the data's goal tokens attached:
-- { text, finished, type, have, need, tokens, lacks }. A token goes to the objective whose line is about
-- it (Names), else to an unclaimed one that starts with its name, else to an unclaimed one that ends
-- with it (Ends), else to the first unclaimed objective of its type.
-- lacks: the items the quest can't be done without that the bags don't hold, that were not used
-- up already (UsedUp), and that the data says where to get (a key off a jailor, a stone out of a
-- crate): they come first (L.Asked).
-- Cached per log scan (L.stamp); callers must not modify the result.
local goalsOf, goalsAt = {}, -1
local needed = {}            -- item -> whether the bags held it when the goals were last worked out
local function Goals(id)
	local goals = {}
	for i, objective in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
		goals[i] = { text = objective.text, finished = objective.finished, type = objective.type,
			have = objective.numFulfilled, need = objective.numRequired, tokens = {} }
	end
	local quest = D.Quest(id)
	if not quest then return goals end

	local loose, lacks = {}, nil
	for _, token in ipairs(quest.goals) do
		local home
		if token.kind ~= "s" and token.kind ~= "k" then
			local name = NameOf(token)
			for _, goal in ipairs(goals) do
				if Names(goal.text, name) then
					home = goal
					break
				end
			end
		end
		if home then
			home.tokens[#home.tokens + 1] = token
		else
			loose[#loose + 1] = token
		end
	end
	for _, token in ipairs(loose) do
		if token.kind == "s" then
			-- An item needed but not counted (a vial, a key): attach it to the first
			-- unfinished objective while the player has none, unless it was used up.
			local held = C_Item.GetItemCount(token.id) > 0
			needed[token.id] = held
			if held then Had()[token.id] = true end
			if not held and not UsedUp(token.id) then
				for _, goal in ipairs(goals) do
					if not goal.finished then
						goal.tokens[#goal.tokens + 1] = token
						if Sourced(token.id) then
							lacks = lacks or {}
							lacks[#lacks + 1] = token
						end
						break
					end
				end
			end
		else
			local want = token.kind == "i" and "item" or (token.kind == "o" and "object" or "monster")
			local home
			if token.kind ~= "k" then
				local name = NameOf(token)
				for _, goal in ipairs(goals) do
					if #goal.tokens == 0 and Starts(goal.text, name) then
						home = goal
						break
					end
				end
				for _, goal in ipairs(home and {} or goals) do
					if #goal.tokens == 0 and Ends(goal.text, name) then
						home = goal
						break
					end
				end
			end
			for _, goal in ipairs(home and {} or goals) do
				if goal.type == want and #goal.tokens == 0 then
					home = goal
					break
				end
			end
			-- The game and the data may disagree on the type: fall back to any unclaimed objective.
			if not home then
				for _, goal in ipairs(goals) do
					if #goal.tokens == 0 then
						home = goal
						break
					end
				end
			end
			if home then home.tokens[1] = token end
		end
	end
	-- (The data doesn't say which objective an item is for: every open one waits for it.)
	for _, goal in ipairs(lacks and goals or {}) do
		if not goal.finished then goal.lacks = lacks end
	end
	return goals
end

-- The quest log's own words for a quest in it: { story, goal } (its description, and the line that sums up its
-- objectives), by its place in the log, as the game's tooltip and quest log search read them. Kept until the log
-- changes; nil for a quest not in the log, or one the game has no words for yet (asked again next time).
local texts, textsOf = {}, nil
function L.Text(id)
	if textsOf ~= L.version then
		textsOf = L.version
		wipe(texts)
	end
	local got = texts[id]
	if got then return got end
	local index = id and L.Has(id) and C_QuestLog.GetLogIndexForQuestID(id)
	if not index or index <= 0 then return nil end
	local story, goal = GetQuestLogQuestText(index)
	story = type(story) == "string" and story:find("%S") and story or nil
	goal = type(goal) == "string" and goal:find("%S") and goal or nil
	if not (story or goal) then return nil end
	got = { story = story, goal = goal }
	texts[id] = got
	return got
end

function L.Goals(id)
	if goalsAt ~= L.stamp then
		wipe(goalsOf)
		wipe(needed)
		goalsAt = L.stamp
	end
	local goals = goalsOf[id]
	if not goals then
		goals = Goals(id)
		goalsOf[id] = goals
	end
	return goals
end

-- What an objective is worked on through now: while its quest lacks an item it can't be done
-- without, that item alone (the altar is no place to go without the stone); else everything it asks for.
function L.Asked(goal)
	return goal.lacks or goal.tokens
end

-- The index of the objective that counts this thing (kind "i" item, "c" creature, "o" object):
-- the one whose line is about it (Names). nil if none.
function L.GoalOf(id, kind, thing)
	local record
	if kind == "i" then record = D.Item(thing) else record = D.Thing(kind, thing) end
	local name = record and record.name
	if not name or name == "" then return nil end
	for index, goal in ipairs(L.Goals(id)) do
		if Names(goal.text, name) then return index end
	end
	return nil
end

-- Available quests

local function Skill(id)
	local info = C_SkillInfo.GetSkillLineInfoByID(id)
	return info and info.rank or 0
end

local function Standing(faction)
	local info = C_Reputation.GetFactionDataByID(faction)
	return info and info.currentStanding or nil
end

local function Started(id) return L.Has(id) or L.Done(id) end

-- The share of its XP a quest gives at the player's level: all of it until five levels below,
-- then 20% less per level, down to 10%.
function L.Share(level)
	if level <= 0 then return 1 end
	return math.max(1, math.min(10, 2 * (level - me.level) + 20)) / 10
end

function L.Pays(quest)
	return quest.xp and math.floor(quest.xp * L.Share(quest.level) + 0.5) or nil
end

-- The worthwhile quest this one unlocks (directly or up to three links on), if any. Worthwhile means it pays
-- its full XP: one that pays less is behind you too, its fights worth little or nothing, and no reason to go.
function L.Opens(quest, depth)
	for _, id in ipairs(quest.opens or {}) do
		local after = D.Quest(id)
		if after and not after.flags:find("h", 1, true) and not L.Has(id) and not L.Done(id)
			and (after.side == "" or after.side == me.side or ("/" .. after.side .. "/"):find("/" .. me.race .. "/", 1, true) ~= nil)
			and (L.Share(after.level) >= 1 or ((depth or 1) < 3 and L.Opens(after, (depth or 1) + 1))) then
			return after
		end
	end
end

function L.Outgrown(quest)
	return L.Share(quest.level) < MEAGRE and not L.Opens(quest)
end

-- Gray: below the game's trivial level range.
function L.Trivial(level)
	return level > 0 and me.level - level > me.trivial
end

-- A quest zone mode leaves out: gray, not done, and the setting that brings such quests back is off. A finished
-- one is still shown, to be handed in. (`quest` is an ID.)
function L.Ignored(quest)
	if ns.T.db.track ~= "zone" or ns.T.db.grayZone then return false end
	local entry = L.entries[quest]
	return entry ~= nil and L.Trivial(entry.level or 0) and not C_QuestLog.IsComplete(quest)
end

-- Gray, and the giver lists none such: the game filters out trivial quests (its default) until the
-- player tracks them.
function L.Hidden(quest)
	return L.Trivial(quest.level) and C_Minimap.IsFilteredOut(Enum.MinimapTrackingFilter.TrivialQuests)
end

-- A preGroup prerequisite not turned in. Unless strict, a done quest that excludes it satisfies it.
local function Unmet(quest, before)
	if L.Done(before) then return false end
	local other = not (quest.strict and quest.strict[before]) and D.Quest(before)
	for _, alternative in ipairs(other and other.exclusive or {}) do
		if L.Done(alternative) then return false end
	end
	return true
end
L.Unmet = Unmet

-- Whether none of preSingle (any one will do) is done.
local function NoneOf(quest)
	if not quest.preSingle then return false end
	for _, before in ipairs(quest.preSingle) do
		if L.Done(before) then return false end
	end
	return true
end

-- The ID of an unmet prerequisite, or nil. preSingle needs any one done, preGroup all.
function L.Before(quest)
	if NoneOf(quest) then return quest.preSingle[1] end
	for _, before in ipairs(quest.preGroup or {}) do
		if Unmet(quest, before) then return before end
	end
end

-- A rule the quest fails, added to `out` (L.Missing): true to go on to the next rule. Without `out`
-- (L.CanStart) it is false, and the first rule failed ends the walk.
local function Miss(out, what, id, value)
	if not out then return false end
	out[#out + 1] = { what = what, id = id, value = value }
	return true
end

-- A state that makes every other rule moot (in the log, done, never offered): the walk ends.
local function Stop(out, what)
	if out then out[#out + 1] = { what = what } end
	return false
end

-- The side, race and class rules. With `out`, each one failed is added to it.
local function Mine(quest, out)
	local fits = true
	local side = quest.side
	if side == "A" or side == "H" then
		if side ~= me.side then
			fits = false
			if not Miss(out, "side", nil, side) then return false end
		end
	elseif side ~= "" then
		-- Race IDs: "1/3/95".
		if not ("/" .. side .. "/"):find("/" .. me.race .. "/", 1, true) then
			fits = false
			if not Miss(out, "race", nil, side) then return false end
		end
	end
	if quest.classes and (me.class < 1 or not HasBit(quest.classes, me.class)) then
		fits = false
		if not Miss(out, "class", nil, quest.classes) then return false end
	end
	return fits
end

function L.ForMe(quest)
	return Mine(quest)
end

-- The spell a class quest teaches when the character knows it already, or nil: such a quest is no longer to be
-- had (Pets.lua sets it: a hunter who can tame has no taming quest left at any race's trainer). nil: none known.
L.Taught = nil

-- Quests a quest giver was seen not to offer (see "What a quest giver offers" below):
-- [quest] = the giver, as "n240".
local function Unoffered()
	local marks = ns.char.unoffered
	if not marks then
		marks = {}
		ns.char.unoffered = marks
	end
	return marks
end

-- The player's word that a giver doesn't offer a quest, kept as a giver's own list is (L.Heard): for a
-- window the game never opened, as an object with nothing to give opens none, so nothing was heard.
function L.NotOffered(id, giver)
	Unoffered()[id] = giver
	L.ForgetOffers()
end

-- Every item in the bags and on the keyring, as a set: one walk over the slots each time the bags
-- change (L.BagsChanged), however many items the data watches, and a rule asked of many quests
-- then asks the game nothing.
-- (One table, emptied and filled again: no garbage for each loot.)
local holding, stale = {}, true
local function Walk(bag)
	local GetItemID = C_Container.GetContainerItemID
	for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
		local id = GetItemID(bag, slot)
		if id and not issecretvalue(id) then holding[id] = true end
	end
end
local function Holding()
	if stale then
		stale = false
		wipe(holding)
		for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do Walk(bag) end
		Walk(Enum.BagIndex.Keyring)
	end
	return holding
end

-- The giver offers it only to someone carrying one of its `needs` (a book for the librarians), and
-- nothing of those is in the bags.
function L.Lacks(quest)
	local needs = quest.needs
	if not needs then return false end
	local held = Holding()
	for _, item in ipairs(needs) do
		if held[item] then return false end
	end
	return true
end

-- Every rule a quest is offered by. `out` nil: false at the first one failed (L.CanStart). A table:
-- each one failed is added to it as { what, id, value } and the walk goes on (L.Missing).
local function Rules(quest, inHand, byData, out)
	local flags, id = quest.flags, quest.id
	if flags:find("h", 1, true) then return Stop(out, "never") end
	if flags:find("g", 1, true) then return Stop(out, "raid") end
	if L.Has(id) then return Stop(out, "log") end
	if flags:find("r", 1, true) then
		if not T.db.repeatable and not Miss(out, "repeatable") then return false end
	elseif L.Done(id) then
		return Stop(out, "done")
	end
	if ns.char.hidden[id] and not Miss(out, "hidden") then return false end
	if not byData and Unoffered()[id] and not Miss(out, "unoffered", nil, Unoffered()[id]) then return false end

	if me.level < quest.minLevel and not Miss(out, "level", nil, quest.minLevel) then return false end
	if quest.maxLevel and me.level > quest.maxLevel and not Miss(out, "maxLevel", nil, quest.maxLevel) then return false end
	if not T.db.lowLevel and L.Outgrown(quest) and not Miss(out, "outgrown") then return false end

	if not Mine(quest, out) and not out then return false end
	-- What a class quest teaches is known already (L.Taught).
	if quest.classes and L.Taught then
		local spell = L.Taught(quest)
		if spell and not Miss(out, "learned", nil, spell) then return false end
	end

	if NoneOf(quest) and not Miss(out, "oneOf", nil, quest.preSingle) then return false end
	for _, before in ipairs(quest.preGroup or {}) do
		if Unmet(quest, before) and not Miss(out, "before", before) then return false end
	end
	for _, other in ipairs(quest.exclusive or {}) do
		if Started(other) and not Miss(out, "instead", other) then return false end
	end
	if quest.next and Started(quest.next) and not Miss(out, "past", quest.next) then return false end
	if quest.breadcrumbFor and Started(quest.breadcrumbFor) and not Miss(out, "led", quest.breadcrumbFor) then return false end
	-- A breadcrumb to this quest is in the log: it is turned in first.
	for _, crumb in ipairs(quest.breadcrumbs or {}) do
		if L.Has(crumb) and not Miss(out, "crumb", crumb) then return false end
	end
	if quest.parent and not L.Has(quest.parent) and not Miss(out, "parent", quest.parent) then return false end
	if quest.untilDone and L.Done(quest.untilDone) and not Miss(out, "until", quest.untilDone) then return false end
	if quest.disabledBy and L.Has(quest.disabledBy) and not Miss(out, "disabled", quest.disabledBy) then return false end
	-- Needs a profession specialty, which isn't checked.
	if quest.spec and not Miss(out, "spec", quest.spec) then return false end

	-- It needs a giver this character can use: an object, a friendly NPC, or a start item.
	local offered = inHand or false
	for _, token in ipairs(quest.starts) do
		if offered then break end
		if token.kind == "o" then
			offered = true
		elseif token.kind == "n" then
			local npc = D.Npc(token.id)
			offered = npc ~= nil and L.Friendly(npc)
		elseif token.kind == "i" then
			-- A start item counts until the player has one (then L.Carried covers it).
			offered = D.StartItem(token.id) ~= nil and C_Item.GetItemCount(token.id) == 0
		end
	end
	if not offered and not Miss(out, "giver") then return false end
	if L.Lacks(quest) and not Miss(out, "carry", nil, quest.needs) then return false end

	local skill = quest.skill
	if skill and Skill(skill.id) < math.max(1, skill.value) and not Miss(out, "skill", skill.id, math.max(1, skill.value)) then
		return false
	end
	if quest.minRep then
		local standing = Standing(quest.minRep.id)
		if (not standing or standing < quest.minRep.value) and not Miss(out, "rep", quest.minRep.id, quest.minRep.value) then
			return false
		end
	end
	if quest.maxRep then
		local standing = Standing(quest.maxRep.id)
		if (not standing or standing >= quest.maxRep.value) and not Miss(out, "repMax", quest.maxRep.id, quest.maxRep.value) then
			return false
		end
	end
	return true
end

-- inHand: the quest starts from an item the player holds, so no giver is needed.
-- byData: the data's rules only, ignoring what a giver was seen to offer.
function L.CanStart(quest, inHand, byData)
	return Rules(quest, inHand, byData)
end

-- Why a quest isn't offered: every rule it fails, as { what, id, value }, by the same walk as
-- L.CanStart (empty when it is offered). A start item in the bags counts as its giver.
--   never, raid, log, done   the walk ended there        repeatable, hidden, outgrown   a setting or your pick
--   unoffered (value: the giver who didn't list it)       level, maxLevel (value)        side, race, class (value)
--   oneOf (value: the quests, any one), before, instead, past, led, crumb, parent, until, disabled (id: a quest)
--   spec, giver                                           skill, rep, repMax (id, value)
--   carry (value: the items, any one)                     learned (value: the spell it teaches, known already)
function L.Missing(quest)
	local out, held = {}, false
	for _, token in ipairs(quest.starts) do
		if token.kind == "i" and C_Item.GetItemCount(token.id) > 0 then held = true end
	end
	Rules(quest, held, false, out)
	return out
end

-- Chains
-- A quest is lost to this character when a rule it fails won't change by playing on, or the game keeps it from
-- the giver's list (gray, L.Hidden; a giver seen not to list it, until a turn-in there). Whatever comes after a
-- lost quest in its chain is lost with it: all of preGroup are needed, one of preSingle.
--   L.Lost(id, gray)   the quest its chain breaks at (itself, or one before it), or nil. `gray`: gray and outgrown
--                      don't count for the quest itself (a dungeon run asks for its quests either way)
--   L.Owed(id)         the quests still to take and hand in before it, by the way with the fewest, earliest first;
--                      none in the log ({} when it is open, or lost)
-- Only what play brings loses a quest (FOR_GOOD). Who a quest is for (side, race, class, never offered) is the
-- asker's to say: a guide's step has its own conditions, and the data is wrong about some of this game's quests.
-- A raid's quest is no loss either: it can be done, only not by the route.
-- Worked out once for each change of availability (L.version), level or the game's gray filter.
local CHAIN_DEEP = 25        -- links followed back: no chain is longer
local FOR_GOOD = { maxLevel = true, instead = true, past = true, led = true, ["until"] = true, hidden = true,
	outgrown = true, unoffered = true, learned = true }
local chains = { key = nil, lost = {}, kept = {}, links = {}, owed = {} }
local NO_LINKS = {}

local function Chains()
	local key = L.version .. ":" .. me.level .. ":" .. tostring(C_Minimap.IsFilteredOut(Enum.MinimapTrackingFilter.TrivialQuests))
	if chains.key ~= key then
		chains.key = key
		wipe(chains.lost)
		wipe(chains.kept)
		wipe(chains.links)
		wipe(chains.owed)
	end
	return chains
end

-- Whether the quest itself can't be had, for good. (`gray`: as for L.Lost.)
local function Barred(quest, gray)
	if not gray and L.Hidden(quest) then return true end
	for _, miss in ipairs(L.Missing(quest)) do
		if FOR_GOOD[miss.what] and not (gray and miss.what == "outgrown") then return true end
	end
	return false
end

local Link   -- below

-- The quest the chain before `quest` breaks at, or nil. `depth`: links followed back so far.
local function Before(quest, depth)
	if depth >= CHAIN_DEEP then return nil end
	for _, before in ipairs(quest.preGroup or NO_LINKS) do
		local at = Unmet(quest, before) and Link(before, depth + 1)
		if at then return at end
	end
	if not NoneOf(quest) then return nil end
	local found
	for _, before in ipairs(quest.preSingle) do
		local at = Link(before, depth + 1)
		if not at then return nil end
		found = found or at
	end
	return found
end

-- A link before the quest asked about: lost by any rule for good, or by its own chain.
function Link(id, depth)
	if L.Has(id) or L.Done(id) then return nil end
	local quest = D.Quest(id)
	if not quest then return nil end
	local memo = Chains().links
	local known = memo[id]
	if known ~= nil then return known or nil end
	-- (Seen again further down its own chain: the data loops. Not lost by that.)
	memo[id] = false
	local found = Barred(quest, false) and id or Before(quest, depth)
	memo[id] = found or false
	return found
end

-- What the chains were worked out for: what is kept of them elsewhere is kept by it.
function L.ChainsKey() return Chains().key end

function L.Lost(id, gray)
	if L.Has(id) or L.Done(id) then return nil end
	local quest = D.Quest(id)
	if not quest then return nil end
	local memo = gray and Chains().kept or Chains().lost
	local known = memo[id]
	if known == nil then
		known = Barred(quest, gray) and id or Before(quest, 0) or false
		memo[id] = known
	end
	return known or nil
end

local function Owed(id, depth, into, seen)
	if seen[id] or depth > CHAIN_DEEP then return end
	seen[id] = true
	local quest = D.Quest(id)
	if not quest then return end
	local function Add(before)
		if not L.Has(before) and not L.Done(before) and D.Quest(before) then
			Owed(before, depth + 1, into, seen)
			if not into[before] then
				into[before] = true
				into[#into + 1] = before
			end
		end
	end
	for _, before in ipairs(quest.preGroup or NO_LINKS) do
		if Unmet(quest, before) then Add(before) end
	end
	if NoneOf(quest) then
		-- One of them: the one that holds with the fewest to do first.
		local best, fewest
		for _, before in ipairs(quest.preSingle) do
			if not Link(before, 1) then
				local count = #L.Owed(before)
				if not fewest or count < fewest then best, fewest = before, count end
			end
		end
		if best then Add(best) end
	end
end

function L.Owed(id)
	local memo = Chains().owed
	local list = memo[id]
	if not list then
		-- (Kept before the walk: a chain that loops back here finds it, empty, and ends.)
		list = {}
		memo[id] = list
		if not L.Has(id) and not L.Done(id) and not L.Lost(id) then
			-- (Marked as had: a loop never owes the quest to itself.)
			local into = { [id] = true }
			Owed(id, 0, into, {})
			for i, before in ipairs(into) do list[i] = before end
		end
	end
	return list
end

-- (me.maps: a map's quests this character may ever be offered: of its side, race and class, none a raid's or
-- never offered. The same all session, so what is on offer is asked again, at every change, of those alone.)
function L.StartsOn(map)
	local list = starts[map]
	if not list then
		local all = me.maps[map]
		if not all then
			all = {}
			for _, id in ipairs(D.StartsOnMap(map)) do
				local quest = D.Quest(id)
				if quest and Mine(quest) and not quest.flags:find("[hg]") then all[#all + 1] = quest end
			end
			me.maps[map] = all
		end
		list = {}
		for _, quest in ipairs(all) do
			if L.CanStart(quest) then list[#list + 1] = quest end
		end
		starts[map] = list
	end
	return list
end

-- Clears the availability cache (level, reputation, profession or setting changed).
function L.ForgetOffers()
	wipe(starts)
	L.version = L.version + 1
end

-- Items in the bags that start an available quest: { { item, quest }, ... }.
-- Recomputed when the bags change (L.BagsChanged).
local carried, carrying
function L.Carried()
	if not carried then
		carried = {}
		for _, id in ipairs(D.StartItems()) do
			if C_Item.GetItemCount(id) > 0 then
				for _, quest in ipairs(D.StartItem(id).quests) do
					local record = D.Quest(quest)
					if record and L.CanStart(record, true) then carried[#carried + 1] = { item = id, quest = record } end
				end
			end
		end
	end
	return carried
end

-- What a quest giver offers
-- The data's prerequisites are incomplete, so a quest giver's own list corrects them: a quest
-- the data says this giver has for the character but the list lacks is marked unavailable
-- (ns.char.unoffered) everywhere, guide steps included, until the giver lists it or a quest is
-- turned in to that giver. A list holding a finished quest is ignored (the turn-in may unlock
-- more), and so is a quest with more than one giver.

local NONE = {}

function L.Unoffered(id)
	return Unoffered()[id] ~= nil
end

-- The giver lists the quest: clear its mark.
function L.Offered(id)
	local marks = Unoffered()
	if marks[id] then
		marks[id] = nil
		L.ForgetOffers()
	end
end

local function OneGiver(quest)
	local givers = 0
	for _, token in ipairs(quest.starts) do
		if token.kind == "o" then
			givers = givers + 1
		elseif token.kind == "n" then
			local npc = D.Npc(token.id)
			if npc and L.Friendly(npc) then givers = givers + 1 end
		end
	end
	return givers == 1
end

-- Quest IDs as ranges: "7,33,91741-91745".
local function Ranges(ids)
	table.sort(ids)
	local out, from, to = {}, nil, nil
	local function Put() out[#out + 1] = from == to and tostring(from) or (from .. "-" .. to) end
	for _, id in ipairs(ids) do
		if from and id == to + 1 then
			to = id
		else
			if from then Put() end
			from, to = id, id
		end
	end
	if from then Put() end
	return table.concat(out, ",")
end

-- What a giver's list taught (ShyQuestDB.offers, account-wide): a quest of theirs the data called on offer
-- that they didn't list, and one they listed, each with every quest the character had done at the time,
-- so that what a quest waits on can be read off what was handed in between the two. Only surprises are
-- kept: a "no" the data has no word on, and a "yes" after a "no" or against the data's word. The latest
-- "no" and the earliest "yes" of each character, as the fewest quests lie between them.
local function Record(kind, thing, offered)
	local offers = T.db.dev and T.db.offers
	if not offers then return end
	local mine = {}
	for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs()) do
		if not issecretvalue(id) then mine[#mine + 1] = id end
	end
	local count, snapshot, who, giver = #mine, nil, UnitName("player") .. "-" .. GetRealmName(), kind .. thing.id
	for _, id in ipairs(thing.gives or NONE) do
		local quest = D.Quest(id)
		if quest and not L.Has(id) and not L.Done(id) then
			local yes, byData = offered[id] == true, L.CanStart(quest, false, true)
			local known = offers[id] and offers[id][giver] and offers[id][giver][who]
			if (yes and (byData == false or (known and known.no))) or (not yes and byData) then
				snapshot = snapshot or Ranges(mine)
				local by = offers[id]
				if not by then by = {} offers[id] = by end
				local at = by[giver]
				if not at then at = {} by[giver] = at end
				known = at[who]
				if not known then known = {} at[who] = known end
				local key = yes and "yes" or "no"
				if (yes and (not known.yes or count < known.yesCount)) or (not yes and (not known.no or count >= known.noCount)) then
					known[key], known[key .. "Count"], known.level = snapshot, count, UnitLevel("player")
					known.race, known.class = me.race, me.class
				end
			end
		end
	end
end

-- The player is talking to `thing` (kind "n" NPC or "o" object), which lists `offered`:
-- { [quest] = true }.
--   pending   the list holds a finished quest to turn in
--   asked     { [quest] = true }: quests the guide's current steps accept here, checked
--             regardless of the rules
-- Returns the quests newly marked unavailable, if any.
function L.Heard(kind, thing, offered, pending, asked)
	local marks, changed, gone = Unoffered(), false, nil
	for id in pairs(offered) do
		if marks[id] then marks[id], changed = nil, true end
	end
	if not pending then
		Record(kind, thing, offered)
		local giver = kind .. thing.id
		local function Look(id)
			if offered[id] or marks[id] or L.Has(id) or L.Done(id) then return end
			local quest = D.Quest(id)
			-- (A gray one is left out of the list by the game, not by the giver.)
			if quest and not L.Hidden(quest) and OneGiver(quest) and ((asked ~= nil and asked[id]) or L.CanStart(quest, false, true)) then
				marks[id], changed = giver, true
				gone = gone or {}
				gone[#gone + 1] = quest
			end
		end
		for _, id in ipairs(thing.gives or NONE) do Look(id) end
		for id in pairs(asked or NONE) do Look(id) end
	end
	if changed then L.ForgetOffers() end
	return gone
end

-- A quest was turned in: clear the marks set at the NPC that took it.
function L.HandedIn(id)
	local quest, marks, changed = D.Quest(id), Unoffered(), false
	for _, token in ipairs(quest and quest.ends or NONE) do
		local giver = token.kind .. token.id
		for other, by in pairs(marks) do
			if by == giver then marks[other], changed = nil, true end
		end
	end
	if changed then L.ForgetOffers() end
end

-- The bags changed: only a quest-starting item coming or going affects availability. Returns whether
-- anything the quests or the guide read of the bags changed: a quest-starting item, an item a quest waits
-- for, or a count of an item the guide's live steps count (G.ItemsNow); anything else in the bags is the
-- errands' alone (the route is built again, the guide left as it is).
local counted = {}           -- item -> its count as last seen, of those the guide's live steps count
function L.BagsChanged()
	-- The bags walked once (Holding); then each watched item is a lookup.
	stale = true
	local held, now = Holding(), {}
	for _, id in ipairs(D.StartItems()) do
		if held[id] then now[#now + 1] = id end
	end
	-- And an item a giver waits to see before offering a quest (L.Lacks).
	now[#now + 1] = "/"
	for _, id in ipairs(D.OfferedWith()) do
		if held[id] then now[#now + 1] = id end
	end
	now = table.concat(now, ",")
	local quests = false
	if now ~= carrying then
		carrying, carried = now, nil
		L.ForgetOffers()
		quests = true
	end
	-- An item a quest waits for came into the bags or left them: no word of that comes from the
	-- quest log, so what is kept by its stamp is worked out again.
	local changed = false
	for id, held in pairs(needed) do
		local has = C_Item.GetItemCount(id) > 0
		if has then Had()[id] = true end
		if has ~= held then changed = true end
	end
	if changed then L.stamp = L.stamp + 1 end
	local items = ns.Guide and ns.Guide.ItemsNow and ns.Guide.ItemsNow({}) or {}
	for id, need in pairs(items) do
		local count = C_Item.GetItemCount(id)
		local was = counted[id]
		if was ~= count then
			-- (A count a step needs reached, or no longer: the guide is asked again. Short of it either
			-- way, a loot is the errands' alone: the card's count comes with the quest log.)
			if type(need) ~= "number" or was == nil or (was >= need) ~= (count >= need) then quests = true end
		end
		counted[id] = count
	end
	for id in pairs(counted) do
		if not items[id] then counted[id] = nil end
	end
	return quests or changed
end
