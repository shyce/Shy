-- Reads the generated records in Data/*.lua. Each record is one string, parsed on first use:
--
--   quest   name ^ level ^ minLevel ^ maxLevel ^ side ^ classes ^ starts ^ ends
--           ^ zone ^ flags ^ preSingle ^ preGroup ^ exclusive ^ next ^ parent
--           ^ skill ^ minRep ^ maxRep ^ breadcrumbFor ^ goals ^ untilDone
--           ^ disabledBy ^ spec ^ trigger ^ breadcrumbs ^ xp ^ opens ^ needs
--   npc     name ^ minLevel ^ maxLevel ^ rank ^ side ^ places ^ title ^ gives ^ takes ^ ground ^ path
--   object  name ^ places ^ gives ^ takes ^ ground ^ among
--   item    name ^ sources ^ more ^ begins ^ trade ^ asks
--   dungeon (dungeonInfo, five-player only)   short ^ low ^ high ^ map ^ places
--   offer   money ^ items ^ choices ^ spell ^ says   (Data/Offers.lua: what a quest gives besides XP and
--           what it asks for, as the server describes the quest; D.Offer)
--
--   side     quest: "" anyone, "A", "H", or race IDs ("1/3/95"). NPC: factions it is friendly to ("A", "H", "AH").
--   starts   n<npc>, o<object>, i<item>          ends   n<npc>, o<object>
--   flags    r repeatable, h never offered (or not in the game yet), g raid, d dungeon, p PvP
--   goals    c<npc> kill, o<object> use, i<item> collect, k<npc>/<npc> kill any of,
--            s<item> an item the quest needs but doesn't count
--   sources  n<npc>:<percent> drops it, o<object> contains it, v<npc> sells it
--   places   <map>[@<dungeon>]:<xxxxyyyy...> ; ...   x and y in 0-9999 (hundredths of a percent of
--            the map). With @, the place is inside that dungeon and the points are its entrances;
--            "a" or "h" after the dungeon marks an entrance for one faction only. A thing with
--            many spawns lists only its cluster centers here.
--   ground   every spawn, in the places format, for things whose places are cluster centers (D.Ground)
--   path     where an NPC who walks goes, in the places format: each group one stretch of the way,
--            its points in the order walked (D.Path)
--   among    object: an NPC ID naming the creatures most of its spawns are near
--   preGroup all must be turned in first; a negative ID strictly, others unless a quest
--            exclusive with them was turned in instead
--   breadcrumbs  quests that only lead to this one        opens  quests this one unlocks
--   xp       the quest's XP at its own level, when known
--   needs    items, any one of which the giver waits to see in your bags before offering it
--   title    the NPC's subtitle ("Innkeeper")             gives, takes  quests it starts, ends
--   more     NPC IDs that also drop the item              begins  quests the item starts
--   trade    "t" for a trade good
--   asks     quests the item is for: counted, needed, or given to carry
--
-- Every NPC and object with a location and every item with a source has a record, so anything
-- can be searched by name (D.Names). Data/Town.lua lists town services (D.Town).
-- A position is always (map, x, y) with integer x and y from 0 to 9999.

local ADDON, ns = ...

local D = {}
ns.Data = D

local data = ns.data
local cache = { quests = {}, npcs = {}, objects = {}, items = {}, starts = {}, offers = {} }

local function Fields(text)
	local out, n, from = {}, 0, 1
	while true do
		local stop = text:find("^", from, true)
		n = n + 1
		if not stop then
			out[n] = text:sub(from)
			return out
		end
		out[n] = text:sub(from, stop - 1)
		from = stop + 1
	end
end

local function Number(text)
	return text ~= nil and text ~= "" and tonumber(text) or nil
end

local function Numbers(text)
	if not text or text == "" then return nil end
	local out = {}
	for token in text:gmatch("[^,]+") do out[#out + 1] = tonumber(token) end
	return out
end

-- "185:50" -> { id = 185, value = 50 }
local function Pair(text)
	if not text or text == "" then return nil end
	local id, value = text:match("^(%-?%d+):(%-?%d+)$")
	return { id = tonumber(id), value = tonumber(value) }
end

-- "n234,o31" -> { { kind = "n", id = 234 }, ... }; a kill-any group keeps its ids.
local function Tokens(text)
	local out = {}
	if not text or text == "" then return out end
	for token in text:gmatch("[^,]+") do
		local kind, rest = token:sub(1, 1), token:sub(2)
		local entry = { kind = kind }
		if kind == "k" then
			entry.ids = {}
			for id in rest:gmatch("%d+") do entry.ids[#entry.ids + 1] = tonumber(id) end
			entry.id = entry.ids[1]
		else
			local id, chance = rest:match("^(%d+):?(%d*)$")
			entry.id, entry.chance = tonumber(id), tonumber(chance)
		end
		out[#out + 1] = entry
	end
	return out
end

-- Entrances marked for the other faction are skipped.
local OTHER_SIDE = { Alliance = "h", Horde = "a" }

-- A way into a dungeon that lies near a door ShyWay knows (the tram's) is that door: the data marks the
-- entrance by the sign on the map, some yards from where the way in is walked through.
local DOOR_REACH = 300   -- yards

local function DoorFor(map, x, y)
	local transit = Shy.Way.data.transit
	local W = ns.World
	local _, north, west = W.ToWorld(map, x, y)
	if not (transit and north) then return x, y end
	local best, bestX, bestY = DOOR_REACH, nil, nil
	for _, stop in ipairs(transit.stops) do
		if stop[1] == "tram" and stop[10] == map and tostring(stop[8]):find("^trigger:") then
			local _, n, w = W.ToWorld(map, stop[11], stop[12])
			local yards = n and math.sqrt((n - north) ^ 2 + (w - west) ^ 2)
			if yards and yards < best then best, bestX, bestY = yards, stop[11], stop[12] end
		end
	end
	return bestX or x, bestY or y
end

local function Places(text)
	local places = {}
	if not text or text == "" then return places end
	local theirs = OTHER_SIDE[UnitFactionGroup("player")]
	for group in text:gmatch("[^;]+") do
		local map, dungeon, whose, digits = group:match("^(%d+)@?(%d*)([ah]?):(%d*)$")
		if whose == "" or whose ~= theirs then
			local points = {}
			for across, down in digits:gmatch("(%d%d%d%d)(%d%d%d%d)") do
				local x, y = tonumber(across), tonumber(down)
				if dungeon ~= "" then x, y = DoorFor(tonumber(map), x, y) end
				points[#points + 1] = x
				points[#points + 1] = y
			end
			places[#places + 1] = { map = tonumber(map), dungeon = tonumber(dungeon), points = points }
		end
	end
	return places
end

function D.Quest(id)
	local quest = cache.quests[id]
	if quest == nil then
		local text = data.quests[id]
		if not text then
			cache.quests[id] = false
			return nil
		end
		local f = Fields(text)
		quest = {
			id = id,
			name = f[1],
			level = Number(f[2]) or 0,
			minLevel = Number(f[3]) or 0,
			maxLevel = Number(f[4]),
			side = f[5] or "",
			classes = Number(f[6]),
			starts = Tokens(f[7]),
			ends = Tokens(f[8]),
			zone = Number(f[9]),
			flags = f[10] or "",
			preSingle = Numbers(f[11]),
			preGroup = Numbers(f[12]),
			exclusive = Numbers(f[13]),
			next = Number(f[14]),
			parent = Number(f[15]),
			skill = Pair(f[16]),
			minRep = Pair(f[17]),
			maxRep = Pair(f[18]),
			breadcrumbFor = Number(f[19]),
			goals = Tokens(f[20]),
			untilDone = Number(f[21]),
			disabledBy = Number(f[22]),
			spec = Number(f[23]),
			trigger = Places(f[24]),
			breadcrumbs = Numbers(f[25]),
			xp = Number(f[26]),
			opens = Numbers(f[27]),
			needs = Numbers(f[28]),
		}
		-- A negative preGroup ID is strict: no exclusive quest can stand in for it.
		for i, before in ipairs(quest.preGroup or {}) do
			if before < 0 then
				quest.preGroup[i] = -before
				quest.strict = quest.strict or {}
				quest.strict[-before] = true
			end
		end
		cache.quests[id] = quest
	end
	return quest or nil
end

-- Where objective `index` of quest `id` was seen to advance in this game (QuestsSeen.lua: players, else the client's
-- quest map), as places; for a quest asking for an item ours know no source of. nil where nothing was seen.
function D.GoalSeen(id, index)
	local text = data.goalsSeen and data.goalsSeen[id]
	if not text then return nil end
	for part in text:gmatch("[^%^]+") do
		local objective, places = part:match("^(%d+)=(.*)$")
		if tonumber(objective) == index then return Places(places) end
	end
	return nil
end

-- "80,4604:5" -> { { item = 80, count = 1 }, { item = 4604, count = 5 } }
local function Counted(text)
	local out = {}
	for token in (text or ""):gmatch("[^,]+") do
		local item, count = token:match("^(%d+):?(%d*)$")
		if item then out[#out + 1] = { item = tonumber(item), count = tonumber(count) or 1 } end
	end
	return out
end

-- What a quest gives besides XP, and what it asks for in its own sentence, as the server describes it:
-- { money (copper; below zero what it costs), items, choices ({ item, count } each), spell, says }. nil for
-- a quest the data has no word on. "$n" in the sentence is the player's name, "$g his:her;" a word by
-- their sex: D.Says writes them out.
function D.Offer(id)
	local offer = cache.offers[id]
	if offer == nil then
		local text = data.offers and data.offers[id]
		if not text then
			cache.offers[id] = false
			return nil
		end
		local f = Fields(text)
		offer = { money = Number(f[1]) or 0, items = Counted(f[2]), choices = Counted(f[3]), spell = Number(f[4]),
			says = f[5] ~= "" and f[5] or nil }
		cache.offers[id] = offer
	end
	return offer or nil
end

-- A quest's sentence with the player written in: their name for "$n", their class for "$c", their race for
-- "$r", and for "$g his:her;" the word for their sex.
function D.Says(text)
	if not text or not text:find("$", 1, true) then return text end
	local female = UnitSex("player") == 3
	text = text:gsub("%$[gG]%s*([^:;]*):([^;]*);", function(his, her) return female and her or his end)
	text = text:gsub("%$[nN]", function() return UnitName("player") or "" end)
	text = text:gsub("%$[cC]", function() return (UnitClass("player") or ""):lower() end)
	text = text:gsub("%$[rR]", function() return (UnitRace("player") or ""):lower() end)
	return text
end

function D.Npc(id)
	local npc = cache.npcs[id]
	if npc == nil then
		local text = data.npcs[id]
		if not text then
			cache.npcs[id] = false
			return nil
		end
		local f = Fields(text)
		npc = {
			id = id,
			name = f[1],
			minLevel = Number(f[2]) or 0,
			maxLevel = Number(f[3]) or 0,
			rank = Number(f[4]) or 0,
			side = f[5] or "",
			places = Places(f[6]),
			title = f[7] ~= "" and f[7] or nil,
			gives = Numbers(f[8]),
			takes = Numbers(f[9]),
			spread = f[10] ~= "" and f[10] or nil,
			walk = f[11] ~= "" and f[11] or nil,
		}
		cache.npcs[id] = npc
	end
	return npc or nil
end

function D.Object(id)
	local object = cache.objects[id]
	if object == nil then
		local text = data.objects[id]
		if not text then
			cache.objects[id] = false
			return nil
		end
		local f = Fields(text)
		object = { id = id, name = f[1], places = Places(f[2]), gives = Numbers(f[3]), takes = Numbers(f[4]),
			spread = f[5] ~= "" and f[5] or nil, among = Number(f[6]) }
		cache.objects[id] = object
	end
	return object or nil
end

-- Every spawn of an NPC or object, in the places format (parsed on first use), for shading
-- the map. Falls back to its places when those are already all its spawns.
function D.Ground(thing)
	if not thing.ground then
		thing.ground = thing.spread and Places(thing.spread) or thing.places
	end
	return thing.ground
end

-- The way an NPC walks, in the places format (parsed on first use): each entry one stretch of it,
-- the points in the order walked. nil for an object, and for someone who stays where they stand.
function D.Path(thing)
	if thing.path == nil then
		thing.path = thing.walk and Places(thing.walk) or false
	end
	return thing.path or nil
end

-- What players measured an item dropping in this game (Data/QuestsSeen.lua: "npc:chance;..."), laid over its sources:
-- the chance of a creature its sources name; one of the others that drop it (item.more: named with no chance)
-- becomes a source at that chance; the creatures the data places only for an item that lists no dropper.
local function Measured(item, text)
	local sources, dropper = item.sources, item.more ~= nil and item.more[1] ~= nil
	for _, source in ipairs(sources) do
		if source.kind == "n" then dropper = true end
	end
	for npcText, chanceText in text:gmatch("(%d+):([%d%.]+)") do
		local npc, chance = tonumber(npcText), tonumber(chanceText)
		local found = false
		for _, source in ipairs(sources) do
			if source.kind == "n" and source.id == npc then
				source.chance, found = chance, true
			end
		end
		for index = #(item.more or {}), 1, -1 do
			if not found and item.more[index] == npc then
				table.remove(item.more, index)
				sources[#sources + 1] = { kind = "n", id = npc, chance = chance }
				found = true
			end
		end
		if not found and not dropper and data.npcs and data.npcs[npc] then sources[#sources + 1] = { kind = "n", id = npc, chance = chance } end
	end
end

function D.Item(id)
	local item = cache.items[id]
	if item == nil then
		local text = data.items[id]
		if not text then
			cache.items[id] = false
			return nil
		end
		local f = Fields(text)
		item = { id = id, name = f[1], sources = Tokens(f[2]), more = Numbers(f[3]), begins = Numbers(f[4]), trade = f[5] == "t",
			asks = Numbers(f[6]), given = Numbers(f[7]) }
		local seen = data.dropsSeen and data.dropsSeen[id]
		if seen then Measured(item, seen) end
		cache.items[id] = item
	end
	return item or nil
end

-- What the game showed a creature doesn't drop, kept for the account (ShyQuestDB.drops; Hover.lua notes it):
-- by NPC ID, the items it was seen not to drop. The game names on a creature every objective it counts for;
-- the data's lists of who drops what are wider than that.
D.dropsVersion = 0

local function Drops()
	local db = ns.T and ns.T.db
	return db and db.drops
end

-- Whether the game showed this creature doesn't drop the item.
function D.Dropless(npc, item)
	local drops = Drops()
	local seen = drops and drops[npc]
	return seen ~= nil and seen[item] == true
end

-- Notes whether a creature drops an item, as the game showed. Returns true when that changed anything.
function D.NoteDrop(npc, item, drops)
	local all = Drops()
	if not all or not npc or not item then return false end
	local seen = all[npc]
	if (seen ~= nil and seen[item] == true) == not drops then return false end
	if drops then
		seen[item] = nil
		if next(seen) == nil then all[npc] = nil end
	else
		if not seen then
			seen = {}
			all[npc] = seen
		end
		seen[item] = true
	end
	D.dropsVersion = D.dropsVersion + 1
	return true
end

-- Whether the data says this creature drops the item (the game may since have shown otherwise: D.Dropless).
function D.ListsDropper(id, npc)
	local item = D.Item(id)
	if not item then return false end
	for _, source in ipairs(item.sources) do
		if source.kind == "n" and source.id == npc then return true end
	end
	for _, each in ipairs(item.more or {}) do
		if each == npc then return true end
	end
	return false
end

-- The NPCs that drop an item: { { npc, chance = in a hundred, nil where unknown }, ... }.
function D.Droppers(id)
	local out, item = {}, D.Item(id)
	for _, source in ipairs(item and item.sources or {}) do
		if source.kind == "n" and not D.Dropless(source.id, id) then out[#out + 1] = { npc = source.id, chance = source.chance } end
	end
	for _, npc in ipairs(item and item.more or {}) do
		if not D.Dropless(npc, id) then out[#out + 1] = { npc = npc } end
	end
	return out
end

-- How seldom a drop comes, in words ("drops about 1 in 40"); nil for one that comes nearly every time
-- (nearer 1 in 1 than 1 in 2) or with no chance known.
--   short: the odds alone ("1 in 40"), for the end of a line that names what drops it.
function D.OneIn(chance, short)
	if not chance or chance <= 0 then return nil end
	local kills = math.floor(100 / chance + 0.5)
	if kills < 2 then return nil end
	return (short and "1 in %d" or "drops about 1 in %d"):format(kills)
end

-- Whether a quest is an escort: someone is walked somewhere, and sets off when it is accepted
-- (Data/ByHand.lua's list; nothing in the game says so).
function D.Escort(id)
	local byHand = data.byHand
	return byHand ~= nil and byHand.escort ~= nil and byHand.escort[id] == true
end

-- What brings out an NPC that stands nowhere until then (Data/Summons.lua), or nil:
-- { { kind = "d" | "f" | "o" | "i" | "q" | "e", ids = { ... }, chance = percent }, ... }
--   d a creature dies, f a fight with one, o an object used, i an item used, q a quest taken,
--   e a quest handed in.
local summoned = {}
function D.Summons(npc)
	local found = summoned[npc]
	if found == nil then
		local text = data.summons and data.summons[npc]
		found = false
		if text then
			found = {}
			for kind, ids, chance in text:gmatch("(%a)([%d/]+):?(%d*)") do
				found[#found + 1] = { kind = kind, ids = Numbers((ids:gsub("/", ","))), chance = tonumber(chance) or 100 }
			end
		end
		summoned[npc] = found
	end
	return found or nil
end

-- The NPC or object behind an "n", "c", "v" or "o" token.
function D.Thing(kind, id)
	if kind == "o" then return D.Object(id) end
	return D.Npc(id)
end

-- What a thing looks like, for a hover's stage (Data/Looks.lua): an NPC ("n"), the display it wears, which
-- the game can draw without having met one; an object ("o"), its model's file. nil where unknown.
function D.Look(kind, id)
	local looks = data.looks
	if not (looks and id) then return nil end
	return (kind == "o" and looks.o or looks.n)[id]
end

function D.DungeonName(area)
	return area and data.dungeons[area] or nil
end

-- The five-player dungeons, lowest first: { area, name, short (the key guides and settings
-- use), low, high (the Group Finder's levels), map (instance map) }.
local dungeons
function D.Dungeons()
	if not dungeons then
		dungeons = {}
		for area, text in pairs(data.dungeonInfo or {}) do
			local f = Fields(text)
			dungeons[#dungeons + 1] = { area = area, name = data.dungeons[area] or f[1], short = f[1],
				low = Number(f[2]) or 0, high = Number(f[3]) or 0, map = Number(f[4]) }
		end
		table.sort(dungeons, function(a, b)
			if a.low ~= b.low then return a.low < b.low end
			return a.area < b.area
		end)
	end
	return dungeons
end

function D.StartsOnMap(map)
	local list = cache.starts[map]
	if not list then
		list = Numbers(data.starts[map]) or {}
		cache.starts[map] = list
	end
	return list
end

-- A quest-starting item worth seeking out (listed in Data/Starts.lua):
-- { id, quests, sources (as an item's sources) }, or nil.
local startItems = {}
function D.StartItem(id)
	local start = startItems[id]
	if start == nil then
		local text = data.startItems and data.startItems[id]
		if text then
			local f = Fields(text)
			start = { id = id, quests = Numbers(f[1]) or {}, sources = Tokens(f[2]) }
		else
			start = false
		end
		startItems[id] = start
	end
	return start or nil
end

-- Whether a source of a quest-starting item can be counted on: anything that sells or holds it, or a
-- creature that drops it at least LONG_SHOT times in a hundred and isn't a rare spawn (which may not
-- be up at all). `least`: the lowest chance the item's sources have, which a dropper the data gives
-- no chance for is taken to drop it at.
local LONG_SHOT = 20
function D.Sure(source, least)
	if source.kind ~= "n" then return true end
	local npc = D.Npc(source.id)
	if npc and (npc.rank == 2 or npc.rank == 4) then return false end
	local chance = source.chance or least
	return not chance or chance >= LONG_SHOT
end

-- The lowest drop chance among an item's sources, or nil.
function D.Least(sources)
	local least
	for _, source in ipairs(sources) do
		if source.chance and (not least or source.chance < least) then least = source.chance end
	end
	return least
end

-- Whether a quest-starting item is a long shot: none of its sources can be counted on (D.Sure). One to
-- keep an eye out for while passing, not to go and grind for.
function D.LongShot(id)
	local start = D.StartItem(id)
	if not (start and start.sources[1]) then return false end
	local least = D.Least(start.sources)
	for _, source in ipairs(start.sources) do
		if D.Sure(source, least) then return false end
	end
	return true
end

function D.StartItems()
	if not cache.startItems then
		cache.startItems = {}
		for id in pairs(data.startItems or {}) do cache.startItems[#cache.startItems + 1] = id end
		table.sort(cache.startItems)
	end
	return cache.startItems
end

-- Items a quest's giver waits to see in the bags before offering it (a quest's `needs`), sorted.
function D.OfferedWith()
	if not cache.offeredWith then
		cache.offeredWith = {}
		for id in pairs(data.offeredWith or {}) do cache.offeredWith[#cache.offeredWith + 1] = id end
		table.sort(cache.offeredWith)
	end
	return cache.offeredWith
end

function D.StartMaps()
	if not cache.maps then
		cache.maps = {}
		for map in pairs(data.starts) do cache.maps[#cache.maps + 1] = map end
		table.sort(cache.maps)
	end
	return cache.maps
end

-- Every record name of a kind ("quests", "npcs", "objects", "items") for searching:
-- { { id, lower-case name }, ... }, built on first use without parsing the records.
local names = {}
function D.Names(kind)
	local list = names[kind]
	if not list then
		list = {}
		for id, text in pairs(data[kind]) do
			local name = text:match("^[^%^]+")
			if name then list[#list + 1] = { id, name:lower() } end
		end
		table.sort(list, function(a, b)
			if a[2] ~= b[2] then return a[2] < b[2] end
			return a[1] < b[1]
		end)
		names[kind] = list
	end
	return list
end

-- A record's name, without parsing the record.
function D.Name(kind, id)
	local text = data[kind][id]
	return text and text:match("^[^%^]+") or nil
end

-- A name the game keeps for itself ("[DNT] Kill Credit: ...", "DNT KILL CREDIT"): an unseen creature a quest's
-- count is credited to, nobody to find or target.
function D.Internal(name)
	return type(name) == "string" and (name:find("^%[DNT%]") ~= nil or name:find("^DNT ") ~= nil)
end

-- What the game itself showed of an NPC, kept for the account (ShyQuestDB.shops; Bags.lua notes
-- it): 0 no shop, 1 buys and sells, 2 also repairs. Nothing in the client's files says who keeps
-- a shop, so the lists in Data/Town.lua give way to these.
D.NO_SHOP, D.SHOP, D.REPAIRS = 0, 1, 2
D.shopsVersion = 0
local SHOPS = { vendor = D.SHOP, repair = D.REPAIRS, ammo = false, bags = false, reagents = false, food = false, poisons = false,
	trade = false }

local function Shops()
	local db = ns.T and ns.T.db
	return db and db.shops
end

function D.Shop(id)
	local shops = Shops()
	return shops and shops[id] or nil
end

local town = {}

-- Notes what an NPC showed. A shop seen open is not taken back by a window without one, unless
-- the player says so (`sure`). Returns true when that changed anything.
function D.NoteShop(id, what, sure)
	local shops = Shops()
	if not shops or not id then return false end
	local was = shops[id]
	if was == what or (what == D.NO_SHOP and not sure and was ~= nil and was > D.NO_SHOP) then return false end
	shops[id] = what
	D.shopsVersion = D.shopsVersion + 1
	for kind in pairs(SHOPS) do town[kind] = nil end
	return true
end

-- Town services of `kind` (flight, inn, bank, auction, stable, repair, spirit, profession, vendor, ammo,
-- bags, reagents, food, poisons, trade: NPC IDs; mail, stone: object IDs), or the trainers titled `title`.
function D.Town(kind, title)
	local key = title and ("t:" .. title) or kind
	local list = town[key]
	if not list then
		if title then list = Numbers(data.trainers[title]) else list = Numbers(data.town[kind]) end
		list = list or {}
		local least, shops = SHOPS[kind], Shops()
		if least ~= nil and not title and shops and next(shops) then
			local kept, listed = {}, {}
			for _, id in ipairs(list) do
				listed[id] = true
				if shops[id] ~= D.NO_SHOP then kept[#kept + 1] = id end
			end
			if least then
				for id, what in pairs(shops) do
					if what >= least and not listed[id] and data.npcs[id] then kept[#kept + 1] = id end
				end
				table.sort(kept)
			end
			list = kept
		end
		town[key] = list
	end
	return list
end

-- The professions trainers teach, by name (the game's), and the trainers of one.
function D.Professions()
	if not town.professions then
		town.professions = {}
		for name in pairs(data.professions or {}) do town.professions[#town.professions + 1] = name end
		table.sort(town.professions)
	end
	return town.professions
end

function D.ProfessionTrainers(name)
	local key = "p:" .. name
	if not town[key] then town[key] = Numbers(data.professions and data.professions[name]) or {} end
	return town[key]
end

-- The levels a class trainer teaches, as a set ({ [6] = true, ... }), or nil for one that teaches every level
-- (the starting areas' trainers teach only the first few).
local teaches = {}
function D.Teaches(id)
	local set = teaches[id]
	if set == nil then
		set = false
		local levels = Numbers(data.teaches and data.teaches[id])
		if levels then
			set = {}
			for _, level in ipairs(levels) do set[level] = true end
		end
		teaches[id] = set
	end
	return set or nil
end

function D.TrainerTitles()
	if not town.titles then
		town.titles = {}
		for title in pairs(data.trainers) do town.titles[#town.titles + 1] = title end
		table.sort(town.titles)
	end
	return town.titles
end

-- The rare creatures (rare and rare elite) standing on a map: { { id, name, level, low, high, rank, points = { x, y,
-- ... }, path = { { x, y, ... } a stretch walked, ... } or nil, display (the look it wears, or nil) } }, x and y 0 to 9999. Which creatures are rare is read
-- once out of their records' rank field; only those are read whole.
local rares, raresOn = nil, {}
function D.Rares(map)
	local known = raresOn[map]
	if known then return known end
	if not rares then
		rares = {}
		for id, text in pairs(data.npcs) do
			local rank = text:match("^[^%^]*%^[^%^]*%^[^%^]*%^(%d+)")
			if rank == "2" or rank == "4" then rares[#rares + 1] = id end
		end
		table.sort(rares)
	end
	known = {}
	for _, id in ipairs(rares) do
		local npc = D.Npc(id)
		for _, place in ipairs(npc and npc.places or {}) do
			if place.map == map and not place.dungeon and #place.points >= 2 then
				local path
				for _, stretch in ipairs(D.Path(npc) or {}) do
					if stretch.map == map and #stretch.points >= 4 then
						path = path or {}
						path[#path + 1] = stretch.points
					end
				end
				known[#known + 1] = { id = id, name = npc.name, level = D.LevelText(npc), low = npc.minLevel, high = npc.maxLevel,
					rank = npc.rank, points = place.points, path = path, display = D.Look("n", id) }
			end
		end
	end
	raresOn[map] = known
	return known
end

-- "level 12-13", with the rank when not normal ("level 20 elite").
local RANKS = { [1] = "elite", [2] = "rare elite", [3] = "boss", [4] = "rare" }
function D.LevelText(npc)
	if npc.maxLevel == 0 then return nil end
	local level = npc.minLevel == npc.maxLevel and tostring(npc.maxLevel) or (npc.minLevel .. "-" .. npc.maxLevel)
	local rank = RANKS[npc.rank]
	return "level " .. level .. (rank and (" " .. rank) or "")
end

-- The task manager: how many records have been read so far and the spawn points read with them, as
-- counters; each kind's records as a table to weigh.
if Shy.Memory and Shy.Counters then
	local KINDS = { "quests", "npcs", "objects", "items" }
	local READ, SPAWNS = {}, {}
	for _, kind in ipairs(KINDS) do
		Shy.Memory.Keeps("quest data: " .. kind, cache[kind])
		READ[kind], SPAWNS[kind] = kind .. " read", kind .. ": spawn points"
	end
	Shy.Counters("Quest data read", function(row)
		for _, kind in ipairs(KINDS) do
			local read, spawns = 0, 0
			for _, record in pairs(cache[kind]) do
				if record then
					read = read + 1
					for _, place in ipairs(record.ground or record.places or {}) do spawns = spawns + #place.points / 2 end
				end
			end
			row(READ[kind], read)
			row(SPAWNS[kind], spawns)
		end
	end)
end
