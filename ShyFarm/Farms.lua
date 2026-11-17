-- The farm finder: every creature you could farm, ranked by gold an hour. A kill is worth its coin and everything it
-- drops at your prices (Worth.lua); a camp gives kills as fast as you fight, or as its spawns stand again (ShyQuest's
-- camps, from no one place); the way there, by the flights you know (ShyWay's journeys), is taken out of an hour.
-- A creature is weighed at its camps on your continent; one with none there only if a way there is known (never a
-- farm across the sea you couldn't be led to), and a way not yet known on your continent is reckoned as a run there.
-- Worked out over frames, a few creatures a frame.
--
--   F.Rank([item], [level])  weighs every farm again (only those that drop `item`, given); SHY_FARM ("farms") as it goes
--   F.List()           the farms, best first, and how the work stands: "working" | "done" | "missing" (no ShyQuest)
--   F.For([item])      the farms last weighed for `item` (nil: for gold), or nil; and whether a weighing is under way.
--                      Each weighing's answer is kept apart, so the finder and the auction house never undo the other
--     farm = { npc, name, low, high (levels), worth (copper a kill), kills (an hour), gross (copper an hour there),
--              net (copper an hour with the way there), trip (seconds there, or nil), going ("working" while the way
--              is worked out), camp = { map, x, y, continent, north, west, supply }, chance (how many of `item` a kill),
--              items (how many of `item` an hour with the way there) }; for one item, best by how many of it an hour
--   F.Pace()           seconds a kill takes you: your sessions' own, else ShyQuest's; and whether it is your own

local ADDON, ns = ...
local T = ns.T
local W = ns.Worth

local F = {}
ns.Farms = F

local K = {
	above = 3,       -- levels over yours a creature may be (ShyQuest's own farm rule)
	spread = 5,      -- levels a creature's range may span: wider is one that grows with the zone, its loot a high one's
	fight = 45,      -- seconds a kill takes when your sessions don't say (ShyQuest's FIGHT)
	session = 3600,  -- seconds of farming the way there is spread over
	ask = 25,        -- the best this many by gold an hour there are asked the way to
	show = 15,       -- ... and this many kept
	near = 0.5,      -- camps at least this share as thick as the thickest are asked the way to
	rare = 0.01,     -- for one item: creatures giving under this share of what its best dropper gives are left out
	viable = 0.1,    -- of an item, the least its best dropper gives a kill for creatures to be a way to get it
	budget = 3,      -- ms a frame the weighing takes
	settle = 12,     -- seconds the list waits for the ways there before it is said
	run = 7,         -- yards a second you run, for a way there that isn't known
	detour = 1.4,    -- ... and how much longer than a straight line the way round is taken to be
	fewest = 20,     -- kills your sessions must hold before their pace counts
	quickest = 12,   -- seconds a kill, at the quickest and slowest a pace is taken as
	slowest = 120,
}

local list, state, item = {}, nil, nil
local job                   -- the weighing under way: { i, keys, level, pace, farms }
local weighed = {}          -- [item, or 0 for gold] = the farms that weighing found
local GOLD = 0
local driver = CreateFrame("Frame")
driver:Hide()

local keys                  -- every creature the data has, by ID
local function Keys()
	if not keys then
		keys = {}
		for id in pairs(ns.loot and ns.loot.creatures or {}) do keys[#keys + 1] = id end
		table.sort(keys)
	end
	return keys
end

function F.Pace()
	local seconds, kills = 0, 0
	for _, s in ipairs(ns.char and ns.char.history or {}) do
		local n = math.max(s.kills or 0, s.corpses or 0)
		if n > 0 and (s.catches or 0) == 0 then seconds, kills = seconds + (s.seconds or 0), kills + n end
	end
	if kills < K.fewest then return K.fight, false end
	return math.min(K.slowest, math.max(K.quickest, seconds / kills)), true
end

-- Asking which creatures drop an item reads the data's text, never every record whole: a plain search finds the few
-- that name it, and its chance is read out of just those (Data/Loot.lua's format: Worth.lua reads the same).
local SCALE = 10000                 -- the data's chances are in hundredths of a percent
local DROPS = "^[^^]*%^[^^]*%^([^^]*)"
local ROLLS = "^[^^]*%^[^^]*%^[^^]*%^([^^]*)"

-- How many of `id` one go of a list gives ("id:chance[:count]" entries; whole: a count as it is, else in tenths).
local function Rate(list, id, whole)
	if not list or list == "" then return 0 end
	local chance, count = ("," .. list):match("," .. id .. ":(%d+):?(%d*)")
	if not chance then return 0 end
	local n = tonumber(count)
	return tonumber(chance) / SCALE * (n and (whole and n or n / 10) or 1)
end

-- Which creatures roll each shared table: { [table] = { npc, ... } }, read once.
local rollers
local function Rollers()
	if rollers then return rollers end
	rollers = {}
	for npc, text in pairs(ns.loot.creatures) do
		local rolls = text:match(ROLLS)
		if rolls and rolls ~= "" then
			for text in rolls:gmatch("(%d+):%d+") do
				local id = tonumber(text)
				local who = rollers[id]
				if not who then
					who = {}
					rollers[id] = who
				end
				who[#who + 1] = npc
			end
		end
	end
	return rollers
end

-- The creatures that drop an item, and how many of it a kill gives: { [npc] = per }.
local function Droppers(want)
	local out = {}
	local loot = ns.loot
	local first, after, opens = want .. ":", "," .. want .. ":", "^" .. want .. ":"
	-- Its own drop: a creature whose drops name it.
	for npc, text in pairs(loot.creatures) do
		if text:find(after, 1, true) or text:find(opens, 1, true) then
			local per = Rate(text:match(DROPS), want)
			if per > 0 then out[npc] = per end
		end
	end
	-- Through a shared table that holds it: every creature that rolls it.
	for id, text in pairs(loot.tables) do
		if text:find(after, 1, true) or text:sub(1, #first) == first then
			local each = Rate(text, want)
			for _, npc in ipairs(each > 0 and Rollers()[id] or {}) do
				local roll = Rate(loot.creatures[npc]:match(ROLLS), id, true)
				if roll > 0 then out[npc] = (out[npc] or 0) + roll * each end
			end
		end
	end
	return out
end

-- The most of an item one kill gives, of every creature that drops it (0: none does). Kept by item.
local most = {}
function F.Most(want)
	local kept = most[want]
	if kept then return kept end
	kept = 0
	if ns.loot then
		for _, per in pairs(Droppers(want)) do kept = math.max(kept, per) end
	end
	most[want] = kept
	return kept
end

-- Whether creatures are a way to get an item: one of them drops it at least once in ten kills.
function F.Farmable(want)
	return F.Most(want) >= K.viable
end

-- The camps you'd farm a creature at: those on your continent (ShyQuest's straight yards say which: nil off it),
-- thickest first, each with how far it is; else every camp, and the farm is away (another continent). Second: away.
local function Home(quest, camps)
	local home = {}
	for _, camp in ipairs(camps) do
		local yards = quest.Yards and quest:Yards(camp.map, camp.x, camp.y)
		if yards then
			camp.yards = yards
			home[#home + 1] = camp
		end
	end
	if #home > 0 then return home, false end
	return camps, true
end

-- One creature as a farm, or nil: someone you can't or wouldn't farm, nowhere to stand, nothing to gain.
local function Weigh(quest, npc, level, pace, chance)
	local who = quest:Npc(npc)
	if not who or who.title or who.quests or (who.minLevel or 0) > level + K.above then return nil end
	if (who.maxLevel or 0) - (who.minLevel or 0) > K.spread then return nil end
	local all = quest:CampsOf(npc)
	if not all[1] then return nil end
	local worth = W.Worth(npc)
	if not worth or worth <= 0 then return nil end
	local camps, away = Home(quest, all)
	local c = W.Creature(npc)
	local farm = { npc = npc, name = who.name, low = who.minLevel, high = who.maxLevel, worth = worth, respawn = c.respawn,
		camps = camps, away = away, pace = pace, chance = chance }
	F.Camp(farm, camps[1])
	return farm
end

-- A farm at one of its camps: kills an hour as fast as you fight or as its spawns stand again, whichever is slower.
function F.Camp(farm, camp)
	farm.camp = camp
	farm.kills = 3600 / math.max(farm.pace, farm.respawn / math.max(1, camp.supply))
	farm.gross = farm.kills * farm.worth
	local share = K.session / (K.session + (farm.trip or 0))
	farm.net = farm.gross * share
	if farm.chance then farm.items = farm.kills * farm.chance * share end
end

-- The way to a farm's thicker camps by every ride you know: the quickest of them, its time taken out of an hour.
local function Trip(farm)
	local Way = Shy.Way
	if Way.missing then return end
	local here = Way.Here()
	if not here then return end
	if not farm.places then
		farm.places, farm.of = {}, {}
		local least = farm.camps[1].supply * K.near
		for _, camp in ipairs(farm.camps) do
			if camp.supply >= least then
				local place = Way.Place(camp.continent, camp.north, camp.west)
				farm.places[#farm.places + 1] = place
				farm.of[place] = camp
			end
		end
	end
	local journey, going = Way.Journey(here, farm.places)
	farm.going = going
	if journey then
		farm.trip, farm.known = journey.seconds, true
		F.Camp(farm, farm.of[journey.goal] or farm.camp)
	end
end

-- A farm whose way there isn't known once the wait is up: on your continent, a run there in a straight line with
-- room for the way round (K.detour) at K.run yards a second; on another continent, nowhere you could be sent (nil).
local function Reckon(farm)
	if farm.known then return farm end
	if farm.away then return nil end
	local camp = farm.camps[1]
	if not camp.yards then return nil end
	farm.trip = camp.yards * K.detour / K.run
	F.Camp(farm, camp)
	return farm
end

-- Best first: by gold an hour, or for one item by how many of it an hour.
local function Order(a, b)
	if a.items and b.items and a.items ~= b.items then return a.items > b.items end
	if a.net ~= b.net then return a.net > b.net end
	return a.npc < b.npc
end

-- The ways there come back one by one, each moving a farm's gold an hour and its place. Nothing is shown of them
-- until they are in, or K.settle seconds have gone (a way not known by then is reckoned, Reckon): the list is said
-- once, whole and in order, and then holds until it is weighed again.
local settling   -- { farms, since } while the ways there come in

local function Publish()
	local farms = settling and settling.farms
	if not farms then return end
	settling = nil
	local kept = {}
	for _, farm in ipairs(farms) do
		if farm.going == "working" then farm.going = nil end
		if Reckon(farm) then kept[#kept + 1] = farm end
	end
	farms = kept
	table.sort(farms, Order)
	for i = #farms, K.show + 1, -1 do farms[i] = nil end
	list, state = farms, "done"
	weighed[item or GOLD] = farms
	ns.Changed("farms")
end

-- Whether every way is in; asked again as new ways come to light, and once more when the wait is up.
local function Settle()
	local farms = settling and settling.farms
	if not farms then return end
	local waiting = false
	for _, farm in ipairs(farms) do
		if farm.going == "working" then
			Trip(farm)
			if farm.going == "working" then waiting = true end
		end
	end
	if not waiting or GetTime() - settling.since >= K.settle then Publish() end
end

-- The weighing done: the best by gold an hour there are asked the way, and said once the ways are in.
local function Finish(farms)
	-- (Those on your continent asked the way first: one elsewhere fills the list only where they don't.)
	table.sort(farms, function(a, b)
		if a.away ~= b.away then return not a.away end
		return Order(a, b)
	end)
	for i = #farms, K.ask + 1, -1 do farms[i] = nil end
	for _, farm in ipairs(farms) do Trip(farm) end
	local mine = { farms = farms, since = GetTime() }
	settling = mine
	Settle()
	if settling == mine then
		C_Timer.After(K.settle, function() if settling == mine then Publish() end end)
	end
end

-- New ways came to light: the farms still waiting for theirs are asked again.
function F.Terrain()
	Settle()
end

driver:SetScript("OnUpdate", Shy.Clocked("farm: farms weighed", function()
	local quest = Shy.addons.Quest
	if not job or not quest then
		driver:Hide()
		return
	end
	local started = debugprofilestop()
	local keys = job.keys
	while job.i <= #keys do
		local npc = keys[job.i]
		job.i = job.i + 1
		local farm = Weigh(quest, npc, job.level, job.pace, job.droppers and job.droppers[npc])
		if farm then job.farms[#job.farms + 1] = farm end
		if debugprofilestop() - started > K.budget then return end
	end
	local farms = job.farms
	job = nil
	driver:Hide()
	Finish(farms)
end))

function F.Rank(want, level)
	if not (Shy.addons.Quest and Shy.addons.Quest.CampsOf) then
		list, state = {}, "missing"
		ns.Changed("farms")
		return
	end
	item = want
	settling = nil   -- (a weighing begun again: the old one's ways no longer matter)
	W.Stale()
	local droppers = want and Droppers(want)
	local pick = Keys()
	if droppers then
		local most = 0
		for _, per in pairs(droppers) do most = math.max(most, per) end
		pick = {}
		for npc, per in pairs(droppers) do
			if per >= most * K.rare then pick[#pick + 1] = npc end
		end
		table.sort(pick)
	end
	job = { i = 1, keys = pick, level = level or UnitLevel("player"), pace = F.Pace(), farms = {}, droppers = droppers }
	state = "working"
	driver:Show()
	ns.Changed("farms")
end

function F.List()
	return list, state, item
end

function F.For(want)
	return weighed[want or GOLD], state == "working"
end

-- (A level gained: the farms you could farm are others, every answer kept is old. New ways: the trips worked out.)
Shy:On("SHY_TERRAIN", function() F.Terrain() end)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", Shy.Clocked("farm: a level gained", function(_, _, level)
	wipe(weighed)
	if state == "done" then F.Rank(item, level) end
end))
