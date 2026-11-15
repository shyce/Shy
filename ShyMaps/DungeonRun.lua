-- The run you are on: which of the dungeon's bosses are down, which is next, and how long it has taken. It
-- begins as you walk into a dungeon the journal has and is kept on the account, so a reload or a corpse run
-- picks it up where it was; walking in again after its last boss, or after it has lain for IDLE, begins another.
-- So does a reset: the dungeon you walk into is then another copy of it, and the first creature you see there
-- (targeted, pointed at, or its nameplate) carries that copy's number. Who reset it is also told so by the game,
-- and their run ends then and there.
-- A boss is down when the game says its fight was won (ENCOUNTER_END, BOSS_KILL), or as you loot it.
-- Runs that came to something are kept, the newest first, for the journal's page of them.
--   Run.Of(map)             the run on that dungeon, while it is the one you are on: { map, name, copy, began,
--                           last, kills, ended } or nil
--   Run.Killed(map, boss)   whether that boss (its place in the order) is down this run
--   Run.Next(map)           the first boss in the order still standing, or nil (no run there, or all down)
--   Run.Wing(map)           in an instance that is several dungeons (Scarlet Monastery's four), the one the run
--                           is in: by the room you stand in, else by the boss last downed; nil before either
--   Run.Bosses(map)         the bosses a run there is of, by their places in the order: every one, or those of
--                           the dungeon of the instance it is in (all of them until that is known)
--   Run.Clock(map)          seconds the run has taken: so far, or in all once its last boss is down
--   Run.Time(seconds)       that as words: "12:34", "1:02:03"
--   Run.History(map)        its kept runs, newest first: { { map, at, took, killed, of } }
--   Run.Best(map)           the least seconds a run that downed every boss took, or nil
--   Run.Kill(map, boss)     a boss downed (the events call it; DungeonSeen.lua as its corpse is looted)
-- Bus: SHY_MAPS_RUN (map) as a run begins, a boss goes down or it ends.

local ADDON, ns = ...
local T = ns.T

local Run = {}
ns.DungeonRun = Run

local IDLE = 2 * 3600        -- seconds a run may lie before walking in again is another run
local KEPT = 60              -- runs kept, over every dungeon

local function Book(map)
	return map and ns.Dungeons and ns.Dungeons.Book(map) or nil
end

function Run.Of(map)
	local run = T.db and T.db.run
	if run and run.map == map and (run.ended or time() - run.last <= IDLE) then return run end
	return nil
end

function Run.Killed(map, boss)
	local run = Run.Of(map)
	return run ~= nil and run.kills[boss] ~= nil
end

local function Floors()
	return ns.Journal and ns.Journal.Floors or nil
end

function Run.Wing(map)
	local floors = Floors()
	local wings = floors and floors.Wings(map)
	if not wings then return nil end
	local all = floors.Of(map)
	local room = ns.Journal.Room and ns.Journal.Room(map)
	local floor = room and floors.RoomFloor(map, room)
	if floor and all[floor].wing then return all[floor].wing end
	local run = Run.Of(map)
	local last, at
	for boss, when in pairs(run and run.kills or {}) do
		if not at or when > at then last, at = boss, when end
	end
	return last and floors.WingOf(map, last) or nil
end

function Run.Bosses(map)
	local book = Book(map)
	local floors = Floors()
	local wings = book and floors and floors.Wings(map)
	local wing = wings and Run.Wing(map)
	-- (In the order they are met: the number each wears.)
	local J = ns.Dungeons
	local out = {}
	if wing then
		for _, index in ipairs(wings[wing].bosses) do out[#out + 1] = index end
		table.sort(out, function(a, b) return J.Step(map, a) < J.Step(map, b) end)
		return out
	end
	for step, index in ipairs(book and J.Order(map) or {}) do out[step] = index end
	return out
end

function Run.Next(map)
	local run, book = Run.Of(map), Book(map)
	if not (run and book) or run.ended then return nil end
	-- (In an instance that is several dungeons nothing says which is next until you are known to be in one.)
	local floors = Floors()
	if floors and floors.Wings(map) and not Run.Wing(map) then return nil end
	for _, index in ipairs(Run.Bosses(map)) do
		if not run.kills[index] then return index end
	end
	return nil
end

function Run.Clock(map)
	local run = Run.Of(map)
	if not run then return nil end
	return (run.ended and run.last or time()) - run.began
end

function Run.Time(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds >= 3600 then
		return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
	end
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function Run.History(map)
	local out = {}
	for _, kept in ipairs(T.db and T.db.runs or {}) do
		if kept.map == map then out[#out + 1] = kept end
	end
	return out
end

function Run.Best(map)
	local best
	for _, kept in ipairs(Run.History(map)) do
		if kept.killed >= kept.of and (not best or kept.took < best) then best = kept.took end
	end
	return best
end

-- A run that came to something, onto the kept ones.
local function Keep(run)
	local killed = 0
	for _ in pairs(run.kills) do killed = killed + 1 end
	local book = Book(run.map)
	if killed == 0 or not book then return end
	table.insert(T.db.runs, 1, { map = run.map, at = run.began, took = run.last - run.began, killed = killed,
		of = #Run.Bosses(run.map) })
	for i = #T.db.runs, KEPT + 1, -1 do T.db.runs[i] = nil end
end

-- This visit to the run's dungeon: whether its copy is known to be the run's (sure), when you walked in, and
-- when the run had last moved before that (what it came to, should this be another copy).
local visit = { sure = false }

-- name: the dungeon's as the game says it (a reset is told by it). copy: the copy's number, where known.
-- began: when it began, if before now (walked in before the copy was known).
local function Begin(map, name, copy, began)
	local old = T.db.run
	-- (One left unfinished is kept as far as it got; a finished one was kept as it ended.)
	if old and not old.ended then Keep(old) end
	local now = time()
	T.db.run = { map = map, name = name, copy = copy, began = began or now, last = now, kills = {} }
	visit.sure, visit.came, visit.before = copy ~= nil, now, nil
	Shy:Fire("SHY_MAPS_RUN", map)
end

-- The dungeon you stand in, if the journal has it, and its name.
local function Here()
	local name, kind, _, _, _, _, _, map = GetInstanceInfo()
	if (kind == "party" or kind == "raid") and Book(map) then return map, name end
	return nil
end

function Run.Kill(map, boss)
	local book = Book(map)
	if not (T.db and book and book.bosses[boss]) then return end
	local run = T.db.run
	if not run or run.map ~= map or run.ended or time() - run.last > IDLE then
		local here, name = Here()
		Begin(map, here == map and name or nil)
		run = T.db.run
	end
	if run.kills[boss] then return end
	local now = time()
	run.kills[boss], run.last = now - run.began, now
	-- (Over when every boss it is of is down: all of them, or those of the dungeon of the instance it is in.)
	local left = false
	for _, index in ipairs(Run.Bosses(map)) do
		if not run.kills[index] then left = true end
	end
	if not left then
		run.ended = true
		Keep(run)
	end
	Shy:Fire("SHY_MAPS_RUN", map)
end

-- The copy of the dungeon `map` a unit stands in, by its GUID (Creature-0-server-map-copy-creature-spawn), or nil:
-- no creature, one of another place, or the game withholds who it is.
local function Copy(unit, map)
	local guid = UnitGUID(unit)
	if not guid or issecretvalue(guid) then return nil end
	local kind, at, copy = guid:match("^(%a+)%-%d+%-%d+%-(%d+)%-(%d+)%-")
	if (kind ~= "Creature" and kind ~= "Vehicle") or tonumber(at) ~= map then return nil end
	return copy
end

-- Looked for only while this visit's copy is not yet known (Watch).
local looking = CreateFrame("Frame")
local LOOK = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }
local function Watch(on)
	for _, event in ipairs(LOOK) do
		if on then looking:RegisterEvent(event) else looking:UnregisterEvent(event) end
	end
end

-- A creature seen: in the run's copy, the run goes on; in another (the dungeon was reset), the run so far is
-- kept as it stood when you walked out, and another begins from when you walked in.
local function Seen(unit)
	local run, map, name = T.db and T.db.run, Here()
	if not (run and map and run.map == map) or run.ended or visit.sure then return Watch(false) end
	local copy = Copy(unit, map)
	if not copy then return end
	Watch(false)
	if run.copy and run.copy ~= copy then
		if visit.before then run.last = visit.before end
		Begin(map, name, copy, visit.came)
		return
	end
	run.copy, run.name, visit.sure, visit.before = copy, run.name or name, true, nil
end
looking:SetScript("OnEvent", function(_, event, unit)
	local ok, err = pcall(Seen, event == "PLAYER_TARGET_CHANGED" and "target" or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or unit)
	if not ok then geterrorhandler()(err) end
end)

-- Walked in (or the game drawn again inside): the run there goes on until a creature says it is another copy,
-- or another begins.
local function Entered()
	if not T.db then return end
	local map, name = Here()
	if not map then return Watch(false) end
	local run = T.db.run
	if not run or run.map ~= map or run.ended or time() - run.last > IDLE then
		Begin(map, name)
	else
		visit.sure, visit.came, visit.before = false, time(), run.last
		run.last = visit.came
	end
	Watch(not visit.sure)
end

-- "<dungeon> has been reset.": told to whoever reset it, outside. Their run there is over, kept as far as it got.
local function Reset(message)
	local run = T.db and T.db.run
	if not run or run.ended or not run.name or not message or issecretvalue(message) then return end
	if message ~= INSTANCE_RESET_SUCCESS:format(run.name) then return end
	Keep(run)
	T.db.run = false
	Shy:Fire("SHY_MAPS_RUN", run.map)
end

-- A fight the game says was won: the boss it was, by the encounter's number.
local function Won(encounter)
	if not T.db or encounter == nil or issecretvalue(encounter) then return end
	local map = Here()
	local book = Book(map)
	for index, boss in ipairs(book and book.bosses or {}) do
		if boss.encounter == encounter then
			Run.Kill(map, index)
			return
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("BOSS_KILL")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent", function(_, event, encounter, _, _, _, success)
	local ok, err
	if event == "PLAYER_ENTERING_WORLD" then
		ok, err = pcall(Entered)
	elseif event == "CHAT_MSG_SYSTEM" then
		ok, err = pcall(Reset, encounter)
	elseif event == "BOSS_KILL" then
		ok, err = pcall(Won, encounter)
	elseif success ~= nil and not issecretvalue(success) and success == 1 then
		ok, err = pcall(Won, encounter)
	else
		ok = true
	end
	if not ok then geterrorhandler()(err) end
end)
Run.events = events   -- (for a test to send it an event)
