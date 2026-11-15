-- The farm finder: every creature you could farm, ranked by gold an hour. A kill is worth its coin and everything it
-- drops at your prices (Worth.lua); a camp gives kills as fast as you fight, or as its spawns stand again (ShyQuest's
-- camps, from no one place); the way there, by the flights you know (ShyWay's journeys), is taken out of an hour.
-- Worked out over frames, a few creatures a frame.
--
--   F.Rank([item], [level])  weighs every farm again (only those that drop `item`, given); SHY_FARM ("farms") as it goes
--   F.List()           the farms, best first, and how the work stands: "working" | "done" | "missing" (no ShyQuest)
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
	budget = 3,      -- ms a frame the weighing takes
	fewest = 20,     -- kills your sessions must hold before their pace counts
	quickest = 12,   -- seconds a kill, at the quickest and slowest a pace is taken as
	slowest = 120,
}

local list, state, item = {}, nil, nil
local job                   -- the weighing under way: { i, keys, level, pace, farms }
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

-- The creatures that drop an item, and how many of it a kill gives: { [npc] = per }.
local function Droppers(want)
	local out = {}
	local loot = ns.loot
	local rolls = {}
	for id in pairs(loot.tables) do
		for _, drop in ipairs(W.Table(id)) do
			if drop.item == want then rolls[id] = drop.chance * drop.count end
		end
	end
	for _, npc in ipairs(Keys()) do
		local c = W.Creature(npc)
		local per = 0
		for _, drop in ipairs(c.drops) do
			if drop.item == want then per = per + drop.chance * drop.count end
		end
		for _, roll in ipairs(c.tables) do
			if rolls[roll.table] then per = per + roll.chance * roll.times * rolls[roll.table] end
		end
		if per > 0 then out[npc] = per end
	end
	return out
end

-- One creature as a farm, or nil: someone you can't or wouldn't farm, nowhere to stand, nothing to gain.
local function Weigh(quest, npc, level, pace, chance)
	local who = quest:Npc(npc)
	if not who or who.title or who.quests or (who.minLevel or 0) > level + K.above then return nil end
	if (who.maxLevel or 0) - (who.minLevel or 0) > K.spread then return nil end
	local camps = quest:CampsOf(npc)
	if not camps[1] then return nil end
	local worth = W.Worth(npc)
	if not worth or worth <= 0 then return nil end
	local c = W.Creature(npc)
	local farm = { npc = npc, name = who.name, low = who.minLevel, high = who.maxLevel, worth = worth, respawn = c.respawn,
		camps = camps, pace = pace, chance = chance }
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
		farm.trip = journey.seconds
		F.Camp(farm, farm.of[journey.goal] or farm.camp)
	end
end

-- Best first: by gold an hour, or for one item by how many of it an hour.
local function Order(a, b)
	if a.items and b.items and a.items ~= b.items then return a.items > b.items end
	if a.net ~= b.net then return a.net > b.net end
	return a.npc < b.npc
end

-- The weighing done: the best by gold an hour there are asked the way, and kept in order.
local function Finish(farms)
	table.sort(farms, Order)
	for i = #farms, K.ask + 1, -1 do farms[i] = nil end
	for _, farm in ipairs(farms) do Trip(farm) end
	table.sort(farms, Order)
	for i = #farms, K.show + 1, -1 do farms[i] = nil end
	list, state = farms, "done"
	ns.Changed("farms")
end

-- New ways came to light: the farms still worked out are asked again.
function F.Terrain()
	if state ~= "done" then return end
	local any = false
	for _, farm in ipairs(list) do
		if farm.going == "working" then
			Trip(farm)
			any = true
		end
	end
	if any then
		table.sort(list, Order)
		ns.Changed("farms")
	end
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

-- (A level gained: the farms you could farm are others. New ways: the trips worked out.)
Shy:On("SHY_TERRAIN", function() F.Terrain() end)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", Shy.Clocked("farm: a level gained", function(_, _, level)
	if state == "done" then F.Rank(item, level) end
end))
