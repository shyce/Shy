-- Where else there are quests for you: every start map weighed by quests worth doing now,
-- less for distance and sea crossings, each with its busiest quest giver as the place to start.
-- Weighing is a few thousand rule checks, so it only runs when Log.version changes;
-- distances are cheap and measured fresh.

local ADDON, ns = ...
local T = ns.T
local D, W, L = ns.Data, ns.World, ns.Log

local Z = {}
ns.Zones = Z

local ABOVE = 3            -- quests more than this many levels above you don't count
local WORTH = 3            -- a map needs this many quests to be worth the trip
local EASY = 2             -- quests more than this many levels below you count for less...
local EASY_WORTH = 0.6     -- ...this much of a quest
local FAR = 1500           -- yards, as the crow flies, that cost as much as one quest
local OVERSEAS = 0.4       -- how much a zone on another continent counts for

local zones = {}           -- map -> { map, name, quests, low, high, hub }, or false
local weighed              -- Log's version when they were last weighed

-- The giver on `map` with the most of these quests: thing, x, y, how many.
local function Hub(map, quests)
	local best
	local tally = {}
	for _, quest in ipairs(quests) do
		for _, token in ipairs(quest.starts) do
			if token.kind == "n" or token.kind == "o" then
				local thing = D.Thing(token.kind, token.id)
				if thing and (token.kind == "o" or L.Friendly(thing)) then
					for _, place in ipairs(thing.places) do
						if place.map == map and not place.dungeon and place.points[1] then
							local key = token.kind .. token.id
							local entry = tally[key]
							if not entry then
								entry = { thing = thing, x = place.points[1], y = place.points[2], count = 0 }
								tally[key] = entry
							end
							entry.count = entry.count + 1
							if not best or entry.count > best.count
								or (entry.count == best.count and thing.id < best.thing.id) then
								best = entry
							end
							break
						end
					end
				end
			end
		end
	end
	return best
end

local function Weigh(map)
	local level = L.Level()
	local quests, low, high, worth = {}, nil, nil, 0
	for _, quest in ipairs(L.StartsOn(map)) do
		-- (Zone mode leaves out the gray ones: a zone is worth the trip for what is not.)
		local gray = T.db.track == "zone" and not T.db.grayZone and L.Trivial(quest.level)
		if quest.level <= level + ABOVE and not gray and not quest.flags:find("d", 1, true) then
			quests[#quests + 1] = quest
			worth = worth + ((quest.level > 0 and quest.level < level - EASY) and EASY_WORTH or 1)
			if quest.level > 0 then
				low = math.min(low or quest.level, quest.level)
				high = math.max(high or quest.level, quest.level)
			end
		end
	end
	if #quests < WORTH then return false end
	local hub = Hub(map, quests)
	if not hub then return false end
	table.sort(quests, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end)
	return { map = map, name = W.MapName(map) or ("Map " .. map), quests = quests, worth = worth,
		low = low, high = high, hub = hub }
end

local function WeighAll()
	if weighed == L.version then return end
	weighed = L.version
	wipe(zones)
	for _, map in ipairs(D.StartMaps()) do zones[map] = Weigh(map) end
end

-- The best `count` zones other than the one the player is in, best first.
-- Each: { map, name, quests, low, high, hub = { thing, x, y, count }, yards }.
function Z.Best(count)
	WeighAll()
	local list = {}
	for map, zone in pairs(zones) do
		if zone and map ~= W.map then
			zone.yards = W.Distance(map, zone.hub.x, zone.hub.y)
			zone.score = zone.worth * (zone.yards and 1 or OVERSEAS) - (zone.yards or 0) / FAR
			list[#list + 1] = zone
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.map < b.map
	end)
	for i = #list, count + 1, -1 do list[i] = nil end
	return list
end

-- One zone regardless of rank: that zone alone weighed, if the log has changed since (a hover on the map asks for
-- the zone under the mouse; weighing every zone for it was a quarter of a second).
Z.weighedAt = {}   -- map -> the log's version it was last weighed at, one by one
function Z.Get(map)
	if weighed ~= L.version and Z.weighedAt[map] ~= L.version then
		if not Z.starts then
			Z.starts = {}
			for _, each in ipairs(D.StartMaps()) do Z.starts[each] = true end
		end
		Z.weighedAt[map] = L.version
		zones[map] = Z.starts[map] and Weigh(map) or nil
	end
	return zones[map] or nil
end

-- "9 quests for you, levels 15-20".
function Z.Summary(zone)
	local levels = ""
	if zone.low then
		levels = zone.low == zone.high and (", level " .. zone.low) or (", levels " .. zone.low .. "-" .. zone.high)
	end
	return #zone.quests .. " quests for you" .. levels
end

-- A setting changed what counts: weigh again.
function Z.Forget()
	weighed = nil
	wipe(Z.weighedAt)
end

-- The first weighing reads every quest that starts anywhere, some thousands of records: all at once it was
-- the hitch as the map first opened. They are read a few a frame instead, a while after logging in, out of a
-- fight, so the weighing finds them read. Not where zones are never suggested, nor while a guide leads (none
-- are then, and the records would be kept for nothing).
local warm = { WAIT = 10, AGAIN = 60, MS = 0.5, MOST = 20, map = 1, quest = 1 }
function warm.Wanted()
	if T.db.zones == "never" then return false end
	for _, stop in ipairs(ns.Route and ns.Route.stops or {}) do
		if stop.kind == "guide" and not stop.side then return false end
	end
	return true
end
-- A frame's share: up to MOST records, MS milliseconds at the most. Whether any are left.
function warm.Step()
	local maps = D.StartMaps()
	local began, read = debugprofilestop(), 0
	while warm.map <= #maps do
		local ids = D.StartsOnMap(maps[warm.map])
		while warm.quest <= #ids do
			D.Quest(ids[warm.quest])
			warm.quest = warm.quest + 1
			read = read + 1
			if read >= warm.MOST or debugprofilestop() - began >= warm.MS then return true end
		end
		warm.map, warm.quest = warm.map + 1, 1
	end
	return false
end
function Z.Warm()
	if warm.driver then return end
	if not warm.Wanted() then
		-- (Asked again in a while: the guide may be done by then, or the setting another.)
		C_Timer.After(warm.AGAIN, Z.Warm)
		return
	end
	warm.driver = CreateFrame("Frame")
	warm.driver:SetScript("OnUpdate", Shy.Clocked("zones: quests read ahead", function(self)
		if InCombatLockdown() then return end
		if not warm.Step() then self:Hide() end
	end))
end
Shy:On("SHY_LOGIN", function() C_Timer.After(warm.WAIT, Z.Warm) end)

-- What there is to do in one zone, for a map that names it from afar (ShyMaps' hover of a zone on a
-- continent, where the ground and the spawns are too small to read):
--   T:ZoneSummary(map) -> rows   a hover's rows: the route's stops in that zone, first to last (what each is,
--                                in its kind's sign and color, with its first line under it), how many more
--                                past SUMMARY.most, then the quests that wait to be taken there. Empty for
--                                a zone with nothing to do.
local SUMMARY = { most = 5,
	tone = { kill = "kill", loot = "loot", gather = "use", talk = "talk", go = "go" },
	sign = { pickup = "talk", turnin = "talk", flight = "fly", fly = "fly", home = "home", buy = "coin", train = "book" } }

-- Whether a stop's map is the zone's, or lies in it (a cave, a floor of a keep).
function SUMMARY.Within(map, zone)
	for _ = 1, 4 do
		if map == zone then return true end
		local info = map and map > 0 and C_Map.GetMapInfo(map)
		map = info and info.parentMapID
		if not map then return false end
	end
	return false
end

function SUMMARY.Row(stop)
	local title, lines = ns.Route.Describe(stop)
	if not title then return nil end
	local sign, tone = ns.StopSign(stop)
	local row = { glyph = sign == "goal" and SUMMARY.tone[tone] or SUMMARY.sign[sign] or "go", tint = ns.StopColor(stop),
		text = title, wrap = false }
	local under = lines and lines[1]
	return row, under and under ~= title and { text = under, quiet = true, indent = 1, wrap = false } or nil
end

function T:ZoneSummary(map)
	local rows, shown, more = {}, 0, 0
	local route = ns.Route
	for _, stop in ipairs(route and route.stops or {}) do
		if stop.map and SUMMARY.Within(stop.map, map) then
			if shown >= SUMMARY.most then
				more = more + 1
			else
				local ok, row, under = pcall(SUMMARY.Row, stop)
				if ok and row then
					shown = shown + 1
					rows[#rows + 1] = row
					if under then rows[#rows + 1] = under end
				end
			end
		end
	end
	if more > 0 then rows[#rows + 1] = { text = ("And %d more"):format(more), quiet = true } end
	local zone = Z.Get(map)
	if zone then rows[#rows + 1] = { glyph = "star", text = Z.Summary(zone) } end
	return rows
end
