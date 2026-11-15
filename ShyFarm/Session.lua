-- A session: from when you start farming to when you stop. It is ready (set up, say from the finder, the clock not
-- started: you may not be there yet), running, or paused (by hand, or by a reload, which keeps everything). Only a
-- running session counts. What counts is what reaches your bags (a loot slot the game clears), the coin you loot,
-- the creatures you kill (the game's experience line) and the corpses you loot (one each, however often looted:
-- skinning one is no second kill), the fish you catch and the ones that get away. Its clock runs while you do
-- something and stops by itself after a while of nothing (T.db.idle), so a break costs your gold an hour nothing.
-- Looting what you farm while it isn't running asks you to start or go on (ns.Card.Nudge), so nothing goes uncounted
-- unawares.
--
--   ns.char.session = { state = "ready" | "running" | "paused", why ("hand" | "reload"), began, banked, since, last,
--                       map, items = { [item] = n }, coin, kills, corpses, catches, casts, escaped,
--                       mobs = { [creature] = { name, corpses, items = { [item] = n } } }, want = { item, goal, done },
--                       hidden, asked }
--   ns.char.history = { { began, seconds, value, coin, kills, corpses, catches, map, want, items }, ... } newest first
--   ns.char.ended = { [item] = true }: what you ended farming by hand, each until you farm it again

local ADDON, ns = ...
local T = ns.T
local P = ns.Prices

local S = {}
ns.Session = S

local K = {
	HISTORY = 20,     -- sessions kept
	CORPSES = 400,    -- corpses remembered as looted (a skinned one is no second kill)
	CAST = 40,        -- seconds a cast may stand before the catch it brought
	TICK = 5,         -- seconds between looks at the clock while a session goes on
	FEW = 3,          -- corpses before odds are said
}

-- Time

local function Now() return time() end

function S.Current() return ns.char and ns.char.session end

function S.Seconds(s)
	s = s or S.Current()
	if not s then return 0 end
	return s.banked + (s.since and math.max(0, Now() - s.since) or 0)
end

local function Counting(s) return s ~= nil and s.state == "running" end
S.Counting = Counting

-- Something done: the clock runs again if it had stopped by itself.
local function Touch(s)
	s.last = Now()
	if not s.since and s.state == "running" then s.since = s.last end
end

-- The clock's run so far banked, and stopped (at `at`, now unless told).
local function Bank(s, at)
	if s.since then s.banked = s.banked + math.max(0, (at or Now()) - s.since) end
	s.since = nil
end

-- Nothing done for a while: the clock stops at the last thing done.
local function Idle(s)
	local idle = (T.db.idle or 0) * 60
	if not s.since or idle <= 0 then return false end
	if Now() - s.last < idle then return false end
	Bank(s, s.last)
	return true
end

-- Whether its clock runs now (running, not stopped by a rest).
function S.Running(s)
	s = s or S.Current()
	return s ~= nil and s.since ~= nil
end

function S.State(s)
	s = s or S.Current()
	return s and s.state or nil
end

-- What it is: fishing once you have caught more than you looted from corpses.
function S.Kind(s)
	s = s or S.Current()
	if s and s.catches > 0 and s.catches >= s.corpses then return "fishing" end
	return "grind"
end

-- Kills: the experience lines, or the corpses looted where those are more (grey creatures give none).
function S.Kills(s)
	return math.max(s.kills, s.corpses)
end

-- Worth

-- Everything looted, at today's prices, and the coin: copper.
function S.Value(s)
	s = s or S.Current()
	if not s then return 0 end
	local total = s.coin
	for item, n in pairs(s.items) do
		total = total + n * (P.Value(item) or 0)
	end
	return total
end

function S.PerHour(s)
	local seconds = S.Seconds(s)
	if seconds < 60 then return nil end
	return S.Value(s) * 3600 / seconds
end

-- "1 in 3", or "60%" for what comes more often than every other time; nil with too few to say.
function S.Odds(drops, tries)
	if not tries or tries < K.FEW or not drops or drops <= 0 then return nil end
	local chance = drops / tries
	if chance >= 0.5 then return ("%d%%"):format(math.floor(chance * 100 + 0.5)) end
	return ("1 in %d"):format(math.floor(1 / chance + 0.5))
end

-- The item farmed: how many this session, the creatures that gave it and how often (corpses of those that ever
-- dropped it for you, or your catches when fishing), how fast it comes, how many you hold and want.
function S.Wanted(s)
	s = s or S.Current()
	local want = s and s.want
	if not want then return nil end
	local item = want.item
	local got = s.items[item] or 0
	local drops, tries = 0, 0
	local seen = T.db.seen
	for creature, mob in pairs(s.mobs) do
		local ever = seen[creature]
		if (mob.items[item] or 0) > 0 or (ever and ever.i[item]) then
			drops, tries = drops + (mob.items[item] or 0), tries + mob.corpses
		end
	end
	if tries == 0 and s.catches > 0 then drops, tries = got, s.catches end
	local seconds = S.Seconds(s)
	local rate = seconds >= 60 and got * 3600 / seconds or nil
	local have = C_Item.GetItemCount(item, false)
	local left = want.goal and math.max(0, want.goal - have) or nil
	return { item = item, got = got, have = have, goal = want.goal, left = left, rate = rate,
		odds = S.Odds(drops, tries), eta = (left and left > 0 and rate and rate > 0) and left * 3600 / rate or nil }
end

-- What you have looted of an item yourself, by creature, most corpses first.
function S.Drops(item)
	local out = {}
	for creature, mob in pairs(T.db.seen) do
		local n = mob.i[item]
		if n then out[#out + 1] = { creature = creature, name = mob.name, drops = n, corpses = mob.n } end
	end
	table.sort(out, function(a, b)
		if a.corpses ~= b.corpses then return a.corpses > b.corpses end
		return a.creature < b.creature
	end)
	return out
end

-- An item looted this session by its name (the slash command's farm), or nil.
function S.Named(text)
	text = text:lower()
	local s = S.Current()
	for item in pairs(s and s.items or {}) do
		local name = C_Item.GetItemNameByID(item)
		if name and name:lower() == text then return item end
	end
end

-- Starting and stopping

local function New(state)
	local now = Now()
	return { state = state, began = now, banked = 0, since = state == "running" and now or nil, last = now,
		map = C_Map.GetBestMapForUnit("player"), items = {}, coin = 0, kills = 0, corpses = 0, catches = 0, casts = 0,
		escaped = 0, mobs = {} }
end

local counted = {}   -- corpse GUIDs looted lately, in order (bounded by K.CORPSES): each is one corpse, once

-- Starts now: a new session running, or the one set up (ready or paused) running.
function S.Begin()
	local s = S.Current()
	if s then
		S.Go()
		return s
	end
	ns.char.session = New("running")
	ns.Changed("start")
	return ns.char.session
end

-- Running again (or for the first time): its clock goes on from here.
function S.Go()
	local s = S.Current()
	if not s or s.state == "running" then return end
	local first = s.state == "ready"
	s.state, s.why, s.ask = "running", nil, nil
	if first then s.began, s.map = Now(), C_Map.GetBestMapForUnit("player") or s.map end
	Touch(s)
	ns.Changed(first and "start" or "go")
end

-- Farm an item: a session set up for it if none goes on (ready: its clock starts when you do, or as you reach where
-- it drops), else the one going on wants it; goal: how many you want to hold.
function S.Want(item, goal)
	local s = S.Current()
	if not s then
		s = New("ready")
		ns.char.session = s
	end
	s.want = item and { item = item, goal = goal } or nil
	if item then ns.char.ended[item] = nil end
	s.hidden, s.asked = nil, nil   -- (farming something brings the window back, and asks again where it drops)
	if item then
		P.Facts(item)
		if ns.Stats then ns.Stats.Farmed(item, goal) end
	end
	ns.Changed("want")
end

-- Paused (on), or running again; nil turns it. why: "hand" (by default), or "left" (you left where you farm it:
-- it goes on as you come back).
function S.Pause(on, why)
	local s = S.Current()
	if not s then return end
	if on == nil then on = s.state == "running" end
	if on and s.state == "running" then
		Bank(s)
		s.state, s.why = "paused", why or "hand"
		ns.Changed("pause")
	elseif not on then
		S.Go()
	end
end

-- Ends it: kept in the history at today's prices, and said in a notice that stands a while.
function S.Stop()
	local s = S.Current()
	if not s then return end
	Idle(s)
	Bank(s)
	local seconds, value = S.Seconds(s), S.Value(s)
	local kept = { began = s.began, seconds = seconds, value = value, coin = s.coin, kills = S.Kills(s), corpses = s.corpses,
		catches = s.catches, map = s.map, want = s.want and s.want.item, kind = S.Kind(s), items = s.items }
	ns.char.session = nil
	-- (Ended by hand: you're done with it. Looting it starts nothing until you farm it again, however many others
	-- you farm and end meanwhile: Looted.)
	if s.want then ns.char.ended[s.want.item] = true end
	ns.char.last = nil
	if next(s.items) or s.coin > 0 then
		table.insert(ns.char.history, 1, kept)
		for i = #ns.char.history, K.HISTORY + 1, -1 do ns.char.history[i] = nil end
		if ns.Card and ns.Card.Summary then ns.Card.Summary(kept) end
	end
	ns.Changed("stop")
end

function S.History() return ns.char.history end

-- Something worth counting happened while the session doesn't count: you are asked to start, or to go on.
local function Nudge(s)
	if not s or Counting(s) then return end
	if ns.Card and ns.Card.Nudge then ns.Card.Nudge(s.state) end
end

-- Looting

local loot = { open = false, slots = {}, fishing = false, money = 0, credited = false }

-- The corpse being looted: your dead target, the dead creature under the mouse, or the one the interact key
-- points at. Its GUID and creature ID, or nil (a node, a chest, a fishing hole; or the game won't say).
local CORPSE_UNITS = { "target", "mouseover", "softinteract" }
local function Corpse()
	for _, unit in ipairs(CORPSE_UNITS) do
		local guid = UnitGUID(unit)
		if guid and not issecretvalue(guid) then
			local dead = UnitIsDead(unit)
			if not issecretvalue(dead) and dead then
				local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
				if kind == "Creature" then
					local name = UnitName(unit)
					if issecretvalue(name) then name = nil end
					return guid, tonumber(id), name
				end
			end
		end
	end
end

-- A corpse looted for the first time: a corpse more for its kind in your book (session or not), and in the
-- session if it counts. Looted again (skinned), it is no new corpse.
local function NewCorpse(s, guid, creature, name)
	for _, seen in ipairs(counted) do
		if seen == guid then return false end
	end
	counted[#counted + 1] = guid
	if #counted > K.CORPSES then table.remove(counted, 1) end
	local book = T.db.seen[creature]
	if not book then
		book = { name = name, n = 0, i = {} }
		T.db.seen[creature] = book
	end
	book.n = book.n + 1
	book.name = book.name or name
	if not Counting(s) then return true end
	s.corpses = s.corpses + 1
	local mob = s.mobs[creature]
	if not mob then
		mob = { name = name, corpses = 0, items = {} }
		s.mobs[creature] = mob
	end
	mob.corpses = mob.corpses + 1
	mob.name = mob.name or name
	return true
end

-- The fishing spell, learned from the cast whose loot was a catch.
local lastCast
local function Learn()
	if lastCast and Now() - lastCast.at <= K.CAST then T.db.fishSpells[lastCast.spell] = true end
end

-- Fishing is a choice made with a cast: no session starts one running; one set up (ready) starts.
local function Fishing()
	local s = S.Current()
	if not s then
		if T.db.fishing then S.Begin() end
	elseif s.state == "ready" then
		S.Go()
	end
	return S.Current()
end

-- With no session, looting a favorite starts farming it, running, so this very loot counts (T.db.loot); the head says
-- so. Never what you ended: that waits until you farm it again.
local function Looted()
	if not T.db.loot then return end
	for _, slot in pairs(loot.slots) do
		local item = slot.item
		local fav = T.db.favorites[item]
		if fav and not ns.char.ended[item] then
			S.Want(item, fav and fav.goal or nil)
			S.Go()
			if ns.Card and ns.Card.Started then ns.Card.Started(item) end
			return
		end
	end
end

-- The loot window has what it has: each item slot noted, to be counted when the game clears it (it reached your
-- bags). LOOT_READY may come twice for one window.
local function Ready()
	wipe(loot.slots)
	loot.open = true
	loot.money = GetMoney()
	loot.fishing = IsFishingLoot() == true
	loot.guid, loot.creature, loot.name = nil, nil, nil
	if loot.fishing then
		Learn()
		Fishing()
	else
		loot.guid, loot.creature, loot.name = Corpse()
	end
	for slot = 1, GetNumLootItems() do
		if GetLootSlotType(slot) == Enum.LootSlotType.Item then
			local link = GetLootSlotLink(slot)
			if link and not issecretvalue(link) then
				local item = tonumber(link:match("item:(%d+)"))
				local _, _, quantity = GetLootSlotInfo(slot)
				if item then loot.slots[slot] = { item = item, n = (not issecretvalue(quantity) and quantity) or 1 } end
			end
		end
	end
	if loot.credited then return end
	loot.credited = true
	if not S.Current() then Looted() end
	local s = S.Current()
	if loot.guid then NewCorpse(s, loot.guid, loot.creature, loot.name) end
	if not s then return end
	if not Counting(s) then
		-- (What you farm in the window while it doesn't count: you are asked.)
		local want = s.want and s.want.item
		for _, slot in pairs(loot.slots) do
			if slot.item == want then Nudge(s) end
		end
		return
	end
	Touch(s)
	if loot.fishing then s.catches = s.catches + 1 end
	ns.Changed("loot")
end

-- A slot cleared: what was in it is yours.
local function Cleared(slot)
	local taken = loot.slots[slot]
	if not taken then return end
	loot.slots[slot] = nil
	local item, n = taken.item, taken.n
	-- (Your own drops are kept whether a session counts or not: the finder says them.)
	if loot.creature then
		local book = T.db.seen[loot.creature]
		if book then book.i[item] = (book.i[item] or 0) + n end
	end
	local s = S.Current()
	if not Counting(s) then return end
	s.items[item] = (s.items[item] or 0) + n
	ns.lastLoot = item
	if loot.creature then
		local mob = s.mobs[loot.creature]
		if mob then mob.items[item] = (mob.items[item] or 0) + n end
	end
	P.Facts(item)
	Touch(s)
	ns.Changed("loot")
end

-- Your bags changed: the item farmed may have reached its goal (said once, while it runs).
local function Bags()
	local s = S.Current()
	local want = s and s.want
	if not (want and want.goal) or want.done or not Counting(s) then return end
	if C_Item.GetItemCount(want.item, false) >= want.goal then
		want.done = true
		if ns.Card and ns.Card.Reached then ns.Card.Reached(want.item, want.goal) end
		ns.Changed("goal")
	end
end
S.Bags = Bags

local function Closed()
	loot.open, loot.credited = false, false
	wipe(loot.slots)
end

-- Coin: what the loot window put in your bags (group shares included).
local function Money()
	local now = GetMoney()
	local gained = now - loot.money
	loot.money = now
	local s = S.Current()
	if not (loot.open and Counting(s)) or gained <= 0 then return end
	s.coin = s.coin + gained
	ns.Changed("coin")
end

-- A kill's experience line: "Coyote dies, you gain 45 experience."
local KILL = COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.$", "")
	:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	:gsub("%%%%s", "(.-)")
	:gsub("%%%%d", "%%d+")

function S.KillName(text)
	if type(text) ~= "string" or issecretvalue(text) then return nil end
	return text:match(KILL)
end

local ESCAPED = { [ERR_FISH_ESCAPED] = true, [ERR_FISH_NOT_HOOKED] = true }

local events = CreateFrame("Frame")
local handlers = {
	LOOT_READY = Ready,
	LOOT_SLOT_CLEARED = Cleared,
	LOOT_CLOSED = Closed,
	PLAYER_MONEY = Money,
	BAG_UPDATE_DELAYED = Bags,
	CHAT_MSG_COMBAT_XP_GAIN = function(text)
		local s = S.Current()
		if Counting(s) and S.KillName(text) then
			s.kills = s.kills + 1
			Touch(s)
			ns.Changed("kill")
		end
	end,
	UNIT_SPELLCAST_CHANNEL_START = function(_, _, spell)
		if not spell or issecretvalue(spell) then return end
		lastCast = { spell = spell, at = Now() }
		if not T.db.fishSpells[spell] then return end
		local s = Fishing()
		if Counting(s) then
			s.casts = s.casts + 1
			Touch(s)
			ns.Changed("cast")
		end
	end,
	UI_ERROR_MESSAGE = function(_, message)
		local s = S.Current()
		if not Counting(s) or not message or issecretvalue(message) or not ESCAPED[message] then return end
		s.escaped = s.escaped + 1
		Touch(s)
		ns.Changed("escaped")
	end,
	PLAYER_REGEN_DISABLED = function()
		local s = S.Current()
		if Counting(s) then Touch(s) end
	end,
}

local idler
local Look = Shy.Clocked("farm: the clock's rest", function()
	local current = S.Current()
	if current and Idle(current) then ns.Changed("idle") end
end)
function S.Wake()
	local need = S.Current() ~= nil
	if need and not idler then
		idler = C_Timer.NewTicker(K.TICK, Look) or true
	elseif not need and idler then
		if type(idler) == "table" and idler.Cancel then idler:Cancel() end
		idler = nil
	end
end

function S.Start()
	for event in pairs(handlers) do
		if event == "UNIT_SPELLCAST_CHANNEL_START" then events:RegisterUnitEvent(event, "player") else events:RegisterEvent(event) end
	end
	events:SetScript("OnEvent", Shy.Clocked("farm: loot, kills and catches", function(_, event, ...)
		local ok, err = pcall(handlers[event], ...)
		if not ok then geterrorhandler()(err) end
	end))
	loot.money = GetMoney()
	-- A session kept over a reload or a logout keeps everything; one that was running comes back paused, its clock
	-- stopped at the last thing done, and says so until you go on.
	local s = S.Current()
	if s then
		s.mobs, s.items = s.mobs or {}, s.items or {}
		s.state = s.state or (s.paused and "paused" or "running")
		s.paused = nil
		if s.state == "running" then
			Bank(s, math.min(Now(), s.last))
			s.state, s.why = "paused", "reload"
		end
	end
	-- The clock stops by itself after a while of nothing: looked at only while a session is there.
	table.insert(ns.appliers, S.Wake)
	S.Wake()
end

S.K = K
