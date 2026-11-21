-- The class trainer as a route errand: a stop when there are spells to learn, the gold for them,
-- and a trainer worth the walk now (R.Passing: close by, on the way, or no more than WORTH yards
-- off it with no nearer chance before the guide's next fight); a later row when one is within
-- LISTED yards.
--   Spells due: the spellbook's FutureSpell entries whose level is reached. If the spellbook
--     lists none, the last trainer visit is used instead (Since).
--   Costs: no client table has trainer prices, so a class trainer's list is read whenever its
--     window is open and kept per account (T.db.trainers). Unknown until a first visit.
--   Not every future spell is sold (some come from class quests). Once a trainer's full list is
--     known (`whole`: read with the "unavailable" filter on), spells it doesn't list are ignored,
--     and ones it lists but won't sell wait for a class quest turn-in (ns.char.train.blocked).
--   Not every trainer teaches every level: the starting areas' stop at 6 or 8. The trainer chosen
--     teaches the spells due (Train.Teaches: the data's D.Teaches, over what its window showed).
-- Nothing is bought unless "Train at your trainer" is on (off by default): then a class trainer's
-- window teaches everything it offers that the gold covers, one at a time, as the window updates.
-- Holding Shift as it opens leaves it to the player.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R = ns.Data, ns.World, ns.Log, ns.Route
local UI = Shy.UI

local Train = {}
ns.Train = Train

T.defaults.train = { on = true,      -- the trainer as a stop on the card
	auto = false }                   -- learn what a class trainer offers on opening its window
T.defaults.trainers = {}             -- trainer prices: class -> { whole, spells = { ["Rend|Rank 2"] = { level, copper } } }
T.keep.trainers = true               -- read from the game: per account, not per profile
T.defaults.taught = {}               -- what a class trainer's window showed: npc -> { levels = "1,4,6", whole, cap }
T.keep.taught = true

local LISTED = 1500          -- yards: a trainer this near gets a row on the card even when off the route
local WORTH = 1200           -- yards of walk new spells are worth, off the way (R.Passing): across a city, over its ground
local CITY = 2000            -- yards: a map narrower than this is a city's (Town)
local AT_GATES = 800         -- yards: this near a city's trainer, the way to it is the straight one
local WALK = 7               -- yards a second on foot, as the route reckons it (Route.lua)
local MOST_NAMED = 4         -- spells named in the tooltip before "and N more"
local MOST_SHOWN = 6         -- spells listed in the card's hover

-- Spells due at a trainer, as last computed: { count, cost (nil: unknown), names, from, spells }.
local waiting
local stale = true

local function Class()
	local _, token = UnitClass("player")
	return token
end

-- "Warrior Trainer": the NPC title of the player's class trainers.
local function Title()
	local class = Class()
	return class and (class:sub(1, 1) .. class:sub(2):lower() .. " Trainer") or nil
end

-- This character's trainer state: { blocked, open, visited, skip, saw }.
local function Mine()
	local mine = ns.char.train
	if not mine then
		mine = { blocked = {}, open = {} }
		ns.char.train = mine
	end
	return mine
end

local function Prices()
	local all = T.db.trainers
	local class = Class() or "?"
	if not all[class] then all[class] = { whole = false, spells = {} } end
	return all[class]
end

local function Key(name, rank)
	return (name or "") .. "|" .. (rank or "")
end

-- A spell's entry on the trainer's list: by name and rank, or by name and level when the
-- spellbook gives no rank.
local function Listed(known, spell)
	local key = Key(spell.name, spell.rank)
	if known.spells[key] then return key, known.spells[key] end
	if spell.rank == "" or spell.rank == nil then
		local head = spell.name .. "|"
		for other, entry in pairs(known.spells) do
			if entry[1] == spell.level and other:sub(1, #head) == head then return other, entry end
		end
	end
end

-- The spellbook's future spells: how many, how many of those the trainer's list has, and the
-- ones whose level is reached.
local function Book(known)
	local level, listed, matched, due = UnitLevel("player"), 0, 0, {}
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local bank, future = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.FutureSpell
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		-- Skip the general tab, guild perks and off-spec lines.
		if info and line ~= Enum.SpellBookSkillLineIndex.General and not info.isGuild and not info.offSpecID then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if item and item.itemType == future and not item.isOffSpec then
					local spell = { name = item.name, rank = item.subName or "", id = item.spellID,
						level = C_SpellBook.GetSpellBookItemLevelLearned(slot, bank) or 0 }
					listed = listed + 1
					if Listed(known, spell) then matched = matched + 1 end
					if spell.level > 0 and spell.level <= level then due[#due + 1] = spell end
				end
			end
		end
	end
	return listed, matched, due
end

-- Spells due according to the saved trainer list: what was still for sale at the last visit,
-- plus what it lists for the levels gained since.
local function Since(known, mine)
	local due = {}
	if not mine.visited then return due end
	local level = UnitLevel("player")
	for key, entry in pairs(known.spells) do
		if mine.open[key] or (entry[1] > mine.visited and entry[1] <= level) then
			local name, rank = key:match("^(.-)|(.*)$")
			due[#due + 1] = { name = name, rank = rank, level = entry[1] }
		end
	end
	return due
end

local function Work()
	stale, waiting = false, nil
	if not Class() or not ns.char then return end
	local known, mine = Prices(), Mine()
	local listed, matched, found = Book(known)
	mine.saw = { listed = listed, due = #found, level = UnitLevel("player") }
	local from = "book"
	if listed == 0 then found, from = Since(known, mine), "trainer" end
	-- With the trainer's full list known, a spell it doesn't list isn't sold by trainers.
	local strict = from == "book" and known.whole and matched > 0
	local due, cost, names = {}, 0, {}
	for _, spell in ipairs(found) do
		local key, entry = Listed(known, spell)
		if not (key and mine.blocked[key]) and (entry or not strict) then
			due[#due + 1] = spell
			spell.cost = entry and entry[2] or nil
			-- A spell with no known price makes the total unknown.
			if cost then cost = entry and cost + entry[2] or nil end
		end
	end
	if #due == 0 then return end
	table.sort(due, function(a, b)
		if a.level ~= b.level then return a.level > b.level end
		return a.name < b.name
	end)
	for i, spell in ipairs(due) do
		names[i] = (spell.rank and spell.rank ~= "") and ("%s (%s)"):format(spell.name, spell.rank) or spell.name
	end
	waiting = { count = #due, cost = cost, names = names, from = from, spells = due }
end

-- Spells due at a trainer now: { count, cost, names, from, spells }, or nil.
function Train.Waiting()
	if stale then Work() end
	return waiting
end

-- For other addons (ShyCore's keys say what waits for training and what it costs): the spells due now, each
-- { name, rank, level, id, cost (copper; nil while the trainer's prices aren't known) }, or nil.
function T:Training()
	local due = Train.Waiting()
	return due and due.spells or nil
end

-- Copper to keep for the class trainer, for whoever else spends (a weapon master): the spells due now,
-- and once the level is half gone those of the next level, at the prices the trainer showed.
Train.SOON = 0.5   -- share of a level gained before its next spells are saved for
function Train.Reserve()
	local due = Train.Waiting()
	local keep = due and due.cost or 0
	if not Class() then return keep end
	local level, most = UnitLevel("player"), UnitXPMax("player") or 0
	if most > 0 and (UnitXP("player") or 0) / most >= Train.SOON then
		for _, entry in pairs(Prices().spells) do
			if entry[1] == level + 1 then keep = keep + (entry[2] or 0) end
		end
	end
	return keep
end

-- The levels a "1,4,6" list names, as a set (kept: the lists are few and read often).
local sets = {}
local function Levels(text)
	text = text or ""
	local set = sets[text]
	if not set then
		set = {}
		for level in text:gmatch("%d+") do set[tonumber(level)] = true end
		sets[text] = set
	end
	return set
end

-- Whether a class trainer teaches the spells learned at `level`. What its window showed (T.db.taught) comes
-- first: a whole list is its word; a part adds the levels it showed, and `cap` is the level it showed nothing
-- above when every spell not yet learned was listed (none above can have been learned yet). Then the data's
-- (D.Teaches); a trainer nothing is known of teaches every level.
function Train.Teaches(id, level)
	local seen = T.db.taught[id]
	if seen then
		local shown = Levels(seen.levels)
		if seen.whole or shown[level] then return shown[level] == true end
		if seen.cap and level > seen.cap then return false end
	end
	local set = D.Teaches(id)
	return not set or set[level] == true
end

-- Notes what a class trainer's window showed (shown: a set of levels): its whole list when every filter is
-- on; with the spells not yet learned all listed (open), the level it teaches nothing above.
local function Note(id, shown, whole, open, level)
	local seen = T.db.taught[id] or {}
	if not whole then
		for old in pairs(Levels(seen.levels)) do shown[old] = true end
	end
	local levels, top = {}, 0
	for at in pairs(shown) do
		levels[#levels + 1] = at
		top = math.max(top, at)
	end
	table.sort(levels)
	seen.levels, seen.whole = table.concat(levels, ","), (whole or seen.whole) or nil
	if seen.whole then
		seen.cap = nil
	elseif open then
		seen.cap = math.min(seen.cap or math.huge, math.max(top, level))
	end
	T.db.taught[id] = seen
end

-- A map's town: whether the map is a city's, and the flight point that stands in it (false for none).
-- A city's map is told by its width: no table says which maps are cities (they are zones like any
-- other to the game), the widest city's is 1,740 yards across and the narrowest zone's 2,300.
local towns = {}
local function Town(map)
	local town = towns[map]
	if town == nil then
		local continent, north, west = W.ToWorld(map, 0, 0)
		local _, south, east = W.ToWorld(map, 9999, 9999)
		if not continent or not south then return nil end
		town = { city = math.abs(west - east) < CITY, point = false }
		for _, point in ipairs(town.city and R.FlightPoints() or {}) do
			if point.continent == continent and point.north <= north and point.north >= south and point.west <= west and point.west >= east then
				town.point = point
			end
		end
		towns[map] = town
	end
	return town
end

-- Seconds to a trainer standing at a place, or nil where the straight line there says nothing.
--   On the map the player is on it is walked to. In a city it is walked to from its gates, else reached
--   by the city's flight point (walked or flown to, whichever is quicker: R.Travel) and the walk from
--   there. On another zone's map it is reckoned only where the ground between is known (W.Walked):
--   across a zone's border the straight line crosses whatever divides the two (Valley of Trials is
--   1,600 yards from the Crossroads, and a mountain range away).
--   (A walk reckoned by its yards is as the character goes it, as R.Travel's are: Shy.Way.Paced.)
local function Reach(map, x, y, yards)
	local Paced = Shy.Way.Paced
	if map == W.map then return Paced(yards / WALK) end
	local town = Town(map)
	local _, north, west = W.ToWorld(map, x, y)
	if not town or not town.city then
		local _, known = W.Walked(W.continent, W.north, W.west, north, west)
		return known and R.Travel(W.continent, W.north, W.west, north, west) or nil
	end
	if yards <= AT_GATES then return Paced(yards / WALK) end
	local point = town.point
	if not point then return R.Travel(W.continent, W.north, W.west, north, west) end
	return R.Travel(W.continent, W.north, W.west, point.north, point.west) + Paced(W.Between(point.north, point.west, north, west) / WALK)
end

-- The trainer of the player's class soonest reached (Reach): { npc, map, x, y, yards, seconds, spells }. Where
-- none can be reckoned (no trainer on this map and none in a city on this continent), the nearest in a
-- straight line, without `seconds`. title: another kind of trainer's ("Pet Trainer", Pets.lua); ids: the
-- NPCs to choose among instead (Pets.lua's demon trainers, who are no trainers in the town's lists).
-- due: the spells due (Train.Waiting): only a trainer that teaches some of them (Train.Teaches), and one that
-- teaches them all before any that doesn't; `spells` is then the ones it teaches.
function Train.Nearest(title, ids, due)
	title = title or Title()
	local best, nearest = {}, {}     -- by whether it teaches every spell due
	for _, id in ipairs(ids or (title and D.Town(nil, title)) or {}) do
		local npc = D.Npc(id)
		local spells = due and {}
		for _, spell in ipairs(due or {}) do
			if Train.Teaches(id, spell.level) then spells[#spells + 1] = spell end
		end
		local all = not due or #spells == #due
		if npc and L.Friendly(npc) and (not due or #spells > 0) then
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			if map and yards and not dungeon then
				local at = { npc = npc, map = map, x = x, y = y, yards = yards, spells = spells }
				if not nearest[all] or yards < nearest[all].yards then nearest[all] = at end
				local seconds = Reach(map, x, y, yards)
				if seconds and (not best[all] or seconds < best[all].seconds) then
					best[all] = { npc = npc, map = map, x = x, y = y, yards = yards, seconds = seconds, spells = spells }
				end
			end
		end
	end
	return best[true] or nearest[true] or best[false] or nearest[false]
end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- The trainer as a route errand (R.AddErrand), or nil.
local function Find(lead)
	local weighs = ns.Weighed("train")
	if not T.db.train.on then return nil end
	local waiting = Train.Waiting()
	local level = UnitLevel("player")
	if not waiting or (Mine().skip or 0) >= level then return nil end
	local at = Train.Nearest(nil, nil, waiting.spells)
	if not at then return nil end
	-- What this trainer teaches of the spells due, and what that costs (nil: a price not known).
	local due = { count = #at.spells, cost = 0, names = {}, spells = at.spells }
	for i, spell in ipairs(at.spells) do
		due.names[i] = (spell.rank and spell.rank ~= "") and ("%s (%s)"):format(spell.name, spell.rank) or spell.name
		if due.cost then due.cost = spell.cost and due.cost + spell.cost or nil end
	end
	-- (The gold the row waits on: only crossing it brings the row or takes it away.)
	if due.cost and due.cost > 0 then weighs[1] = due.cost end
	if due.cost and Shy.Money() < due.cost then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local passing = not busy and R.Passing("train", at.map, at.x, at.y, lead, nil, WORTH, true)
	if not passing and at.yards > LISTED then return nil end
	local lines = { at.npc.name }
	if due.cost and due.cost > 0 then lines[2] = "Costs " .. Coins(due.cost) end
	return {
		title = ("Train: %d new spell%s"):format(due.count, due.count == 1 and "" or "s"),
		lines = lines,
		caption = ("LEVEL %d  \194\183  YOUR TRAINER"):format(level),
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "train",
		first = passing or nil,
		-- Hover content (CardHover.lua): each spell with icon and price, then the total.
		hover = function()
			local rows = {}
			for i = 1, math.min(MOST_SHOWN, #due.spells) do
				local spell = due.spells[i]
				rows[i] = { icon = spell.id and C_Spell.GetSpellTexture(spell.id) or nil, glyph = "book", text = due.names[i],
					right = spell.cost and spell.cost > 0 and Coins(spell.cost) or nil }
			end
			if #due.spells > MOST_SHOWN then
				rows[#rows + 1] = { glyph = "note", quiet = true, text = ("and %d more"):format(#due.spells - MOST_SHOWN) }
			end
			local sections = { { title = "To learn", rows = rows } }
			if due.cost and due.cost > 0 then
				sections[2] = { title = "Costs", rows = { { glyph = "coin", tint = UI.colors.alert, text = Coins(due.cost),
					right = "of your " .. Coins(Shy.Money()), rightColor = UI.colors.dim } } }
			else
				sections[2] = { title = "Costs", rows = { { glyph = "note", quiet = true, text = "Known after you visit a trainer" } } }
			end
			return sections
		end,
		tip = function(tip)
			for i = 1, math.min(MOST_NAMED, #due.names) do tip:AddLine(due.names[i], 1, 1, 1) end
			if #due.names > MOST_NAMED then tip:AddLine(("and %d more"):format(#due.names - MOST_NAMED), 0.6, 0.6, 0.6) end
			if not due.cost then tip:AddLine("Costs show after you visit a trainer.", 0.6, 0.6, 0.6, true) end
		end,
		menu = function(root)
			root:CreateButton("Ask me next level", function()
				Mine().skip = UnitLevel("player")
				ns.Refresh()
			end)
		end,
	}
end

-- Whether the open trainer window is a class trainer's for the player's class, and that trainer's NPC ID.
-- Weapon masters and riding trainers use the same window type.
local function AtMine()
	if C_Trainer.GetTrainerType() ~= Enum.TrainerType.General or IsTradeskillTrainer() then return false end
	local guid = UnitGUID("npc")
	local id = guid and not issecretvalue(guid) and tonumber((select(6, strsplit("-", guid))))
	local npc = id and D.Npc(id)
	-- An NPC missing from the data is assumed to be one.
	return not (npc and npc.title) or npc.title == Title(), id
end

-- Reads a class trainer's list: prices, what this character can buy, and what is listed but locked.
local function Read()
	local ours, id = AtMine()
	if not ours then return end
	local known, mine, level = Prices(), Mine(), UnitLevel("player")
	mine.open, mine.blocked, mine.visited = {}, {}, level
	-- With the "unavailable" filter on, the list is complete.
	known.whole = known.whole or GetTrainerServiceTypeFilter("unavailable") == true
	-- With "available" too it has every spell not yet learned; with "used" as well, all this trainer teaches.
	local open = GetTrainerServiceTypeFilter("available") == true and GetTrainerServiceTypeFilter("unavailable") == true
	local shown = {}
	for index = 1, GetNumTrainerServices() do
		local name, kind, _, needs, rank = GetTrainerServiceInfo(index)
		if name and (kind == "available" or kind == "unavailable" or kind == "used") then
			if needs and needs > 0 then shown[needs] = true end
			local key = Key(name, rank)
			local cost = GetTrainerServiceCost(index) or 0
			-- A learned spell may report no price: keep the saved one.
			if kind ~= "used" or not known.spells[key] then known.spells[key] = { needs or 0, cost } end
			if kind == "available" then
				mine.open[key] = true
			elseif kind == "unavailable" and (needs or 0) <= level then
				mine.blocked[key] = true
			end
		end
	end
	if id then Note(id, shown, open and GetTrainerServiceTypeFilter("used") == true, open, level) end
end

-- Learning at the window (T.db.train.auto): one service at a time, the next once the window has updated.
-- A service is tried once a visit (by name and rank: the list's order moves as spells are learned).
local teaching               -- { count, cost, tried } while learning

local function Taught()
	local done = teaching
	teaching = nil
	if done and done.count > 0 then
		T:Print(("learned %d spell%s for %s."):format(done.count, done.count == 1 and "" or "s", Coins(done.cost)))
	end
end

local function TeachNext()
	if not teaching then return end
	if InCombatLockdown() or not AtMine() then return Taught() end
	for index = 1, GetNumTrainerServices() do
		local name, kind, _, _, rank = GetTrainerServiceInfo(index)
		local cost = GetTrainerServiceCost(index) or 0
		local key = name and Key(name, rank)
		if kind == "available" and key and not teaching.tried[key] and cost <= GetMoney() then
			teaching.tried[key] = true
			teaching.count, teaching.cost = teaching.count + 1, teaching.cost + cost
			BuyTrainerService(index)
			return
		end
	end
	Taught()
end

-- Whether the window that just opened is to be learned from now.
local function Teach()
	if not T.db.train.auto or IsShiftKeyDown() or InCombatLockdown() or not AtMine() then return end
	teaching = { count = 0, cost = 0, tried = {} }
	TeachNext()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN",
	"TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, id)
	if not ns.char then return end
	if event == "TRAINER_CLOSED" then
		Taught()
	elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
		Read()
		if event == "TRAINER_SHOW" then
			Teach()
		elseif teaching then
			C_Timer.After(0.1, TeachNext)
		end
	elseif event == "QUEST_TURNED_IN" then
		-- A class quest turn-in may unlock a blocked spell.
		local quest = id and D.Quest(id)
		if not (quest and quest.classes) then return end
		Mine().blocked = {}
	end
	stale = true
	-- (The trainer's row is an errand: the errands are fitted again, not the route.)
	ns.RefreshErrands()
end)
-- A spell learned, or a new one to come: the spells due are counted again.
Shy:On("SHY_SPELLS", function()
	stale = true
	if ns.char then ns.RefreshErrands() end
end)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Class trainer when spells are ready", function() return T.db.train.on end, function()
		T.db.train.on = not T.db.train.on
		ns.Apply()
	end)
end)

-- Guarded: the loaded Route.lua may predate R.AddErrand until the client restarts.
if R and R.AddErrand then R.AddErrand("train", Find, "Class trainer") end
-- To ask for: the class trainer, while spells are due there.
if R and R.AddOffer then
	R.AddOffer("train", function()
		local due = T.db.train.on and ns.char and Train.Waiting()
		return due and { { text = ("Class trainer: %d new spell%s"):format(due.count, due.count == 1 and "" or "s") } } or {}
	end)
end
