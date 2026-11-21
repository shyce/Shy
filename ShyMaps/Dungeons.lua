-- The dungeon journal's book: every dungeon and raid the Group Finder lists (Shy.Instances), its bosses in
-- order, what each does and what drops, read out of Data/Dungeons.lua and Data/DungeonLoot.lua as it is asked
-- for, with what you have seen yourself (DungeonSeen.lua). The window (DungeonWindow.lua) and other addons read it here.
--   J.List()                 the instances with a boss list: Shy.Instances' records
--   J.Book(map)              { map, one (the instance), bosses = { { index, encounter, name, npc, display } } }
--   J.Order(map)             the bosses' places in the game's list, in the order they are met: the game's own
--                            order, or for a dungeon the game lists otherwise the order its way meets them in.
--                            The number a boss wears everywhere is its place in this
--   J.Step(map, index)       that number: which boss of the run it is
--   J.Spells(map, index)     { { spell, when, a, b, cues, seen } }: what a boss casts; seen: noted in your own
--                            fights (DungeonSeen.lua), not in the data
--   J.Look(map, index)       what a boss's stage shows: { display } where its look is known, { creature } for one
--                            you have met that the data knows by name alone, nil where neither
--   J.When(row)              "Every 15 to 25 seconds", or nil where nothing is known of when
--   J.Says(spell)            what a spell does, in words: the game's own where it has any, else the sentence the
--                            data carries for it (made from the game's spell numbers), else ""
--   J.Rewards(quest, carried)   what a quest pays: { { item, note ("Choose one" | "You get"), source = "quest" } },
--                            the game's own word for a quest in your log, else Classic's
--   J.Cues(row)              { { key, words, color, mine } }: what a spell asks of a group (mine: of you)
--   J.Loot(map, key)         key a boss's index or "trash": { { item, chance, source, kills, mine } }, the likeliest
--                            first. source: "forever" (recorded in this game by the players of another addon's
--                            database), "seen" (by you or in the making of this data), "classic" (the Classic game's,
--                            which this one may differ from)
--   J.Others(map)            bosses the recorded drops name that the game's own list doesn't: { { name, loot } }
--   J.Door(map)              where you came into the dungeon, as you last did by a loading screen: { north, west,
--                            up }, or nil (DungeonSeen.lua notes it)
--   J.Drops(item)            where an item drops (T:Drops)
--   J.Search(text)           { { map, boss (index or nil), name, under } } for a dungeon's or a boss's name
--   J.ByName(name)           the instance map of the dungeon of that name ("The Deadmines" is "Deadmines")
--   J.Can(kind)              whether you know a spell that answers: "kick", "purge", "M", "C", "D", "P"
--   J.Wanted(item) / J.Want(item, on)   the drops you starred
--   J.CREDIT                 the credit the recorded drops are shown under

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local J = {}
ns.Dungeons = J

-- (Shown wherever the journal lists its sources, as that data's license asks.)
J.CREDIT = "Data from ForeverDB.net (https://foreverdb.net)"

local NONE = {}
local books = {}
local data = ns.data or NONE

-- A record's fields, by the one character between them.
local function Fields(text, sep)
	local out = {}
	for field in (text .. sep):gmatch("([^%" .. sep .. "]*)%" .. sep) do out[#out + 1] = field end
	return out
end

function J.Book(map)
	local book = books[map]
	if book ~= nil then return book or nil end
	local records = map and data.dungeons and data.dungeons[map]
	local one = Shy.Instances and Shy.Instances.ByMap(map)
	if not (records and one) then
		books[map or 0] = false
		return nil
	end
	book = { map = map, one = one, bosses = {} }
	for index, record in ipairs(records) do
		local f = Fields(record, "^")
		book.bosses[index] = { index = index, encounter = tonumber(f[1]), name = f[2], npc = tonumber(f[3]) or 0,
			display = tonumber(f[4]) or 0 }
	end
	books[map] = book
	return book
end

function J.Order(map)
	local book = J.Book(map)
	if not book then return NONE end
	if not book.order then
		local order, step = {}, {}
		for said in ((data.dungeonOrder and data.dungeonOrder[map]) or ""):gmatch("%d+") do
			local index = tonumber(said)
			if book.bosses[index] and not step[index] then
				order[#order + 1] = index
				step[index] = #order
			end
		end
		for index = 1, #book.bosses do
			if not step[index] then
				order[#order + 1] = index
				step[index] = #order
			end
		end
		book.order, book.step = order, step
	end
	return book.order
end

function J.Step(map, index)
	J.Order(map)
	local book = J.Book(map)
	return book and book.step[index] or index
end

local list
function J.List()
	if list then return list end
	list = {}
	for _, one in ipairs(Shy.Instances and Shy.Instances.List() or NONE) do
		if J.Book(one.map) then list[#list + 1] = one end
	end
	return list
end

---------------------------------------------------------------------------
-- What a boss does
---------------------------------------------------------------------------
-- A boss's notes from play on this account, and the creature they are under: its creature's, or by its name
-- where the data knows no creature (a boss only this game has, met in play).
local function Noted(map, boss)
	local notes = T.db and T.db.seen and T.db.seen[map]
	if not notes then return nil end
	if boss.npc > 0 and notes[boss.npc] then return notes[boss.npc], boss.npc end
	for creature, record in pairs(notes) do
		if record.n == boss.name then return record, creature end
	end
end

-- Where a boss was met in play: the place you stood as you looted it (north, west, up: where the game says it in
-- there), and the name of the ground you were on. Nil for each that was never noted.
function J.Met(map, index)
	local book = J.Book(map)
	local boss = book and book.bosses[index]
	local record = boss and Noted(map, boss)
	if not record then return nil end
	return record.w, record.z
end

-- The item sets with a piece among a dungeon's drops: { { set, pieces = { item }, here = { { row, from } } } },
-- the set with the most of its pieces here first. `from`: the boss that drops a piece (its name), or nil for
-- the rest of the dungeon.
function J.Sets(map)
	local book = J.Book(map)
	if not (book and data.dungeonSets) then return {} end
	local drops = {}
	local function Take(key, from)
		for _, row in ipairs(J.Loot(map, key)) do
			if not drops[row.item] then drops[row.item] = { row = row, from = from } end
		end
	end
	for index, boss in ipairs(book.bosses) do Take(index, boss.name) end
	Take("trash", nil)
	local out = {}
	for set, text in pairs(data.dungeonSets) do
		local one = { set = set, pieces = {}, here = {} }
		for piece in text:gmatch("%d+") do
			local item = tonumber(piece)
			one.pieces[#one.pieces + 1] = item
			if drops[item] then one.here[#one.here + 1] = drops[item] end
		end
		if #one.here > 0 then out[#out + 1] = one end
	end
	table.sort(out, function(a, b)
		if #a.here ~= #b.here then return #a.here > #b.here end
		return a.set < b.set
	end)
	return out
end

function J.Spells(map, index)
	local text = data.dungeonSpells and data.dungeonSpells[map] and data.dungeonSpells[map][index]
	local out, have = {}, {}
	for _, part in ipairs(text and Fields(text, ";") or NONE) do
		local f = Fields(part, ":")
		local spell = tonumber(f[1])
		if spell then
			out[#out + 1] = { spell = spell, when = f[2] or "", a = tonumber(f[3]) or 0, b = tonumber(f[4]) or 0, cues = f[5] or "" }
			have[spell] = true
		end
	end
	-- What you saw it cast yourself, that the data hasn't: the oftenest first.
	local book = J.Book(map)
	local record = book and book.bosses[index] and Noted(map, book.bosses[index])
	local seen = {}
	for spell, times in pairs(record and record.s or NONE) do
		if not have[spell] then seen[#seen + 1] = { spell = spell, when = "", a = 0, b = 0, cues = "", seen = true, times = times } end
	end
	table.sort(seen, function(x, y)
		if x.times ~= y.times then return x.times > y.times end
		return x.spell < y.spell
	end)
	for _, row in ipairs(seen) do out[#out + 1] = row end
	return out
end

function J.Look(map, index)
	local book = J.Book(map)
	local boss = book and book.bosses[index]
	if not boss then return nil end
	if boss.display > 0 then return { display = boss.display } end
	local _, creature = Noted(map, boss)
	creature = boss.npc > 0 and boss.npc or creature
	return creature and { creature = creature } or nil
end

local WHEN = {
	p = "On the pull", d = "As it dies", s = "From the start", k = "When you cast",
	l = "When one of its own is hurt", b = "Kept up",
}
function J.When(row)
	if row.when == "t" then
		if row.b > row.a and row.a > 0 then return ("Every %d to %d seconds"):format(row.a, row.b) end
		local every = math.max(row.a, row.b)
		return every > 0 and ("Every %d seconds"):format(every) or "Through the fight"
	elseif row.when == "h" then
		return row.a > 0 and ("Below %d%% health"):format(row.a) or "When it's hurt"
	end
	return WHEN[row.when]
end

function J.Says(spell)
	local says = C_Spell.GetSpellDescription(spell)
	if says and says ~= "" then return says end
	return data.dungeonSays and data.dungeonSays[spell] or ""
end

-- Whether you know a spell of a kind (Data/Dungeons.lua's dungeonAnswers), asked once a session and again
-- when your spells change.
local can = {}
function J.Can(kind)
	local known = can[kind]
	if known ~= nil then return known end
	known = false
	for _, spell in ipairs(data.dungeonAnswers and data.dungeonAnswers[kind] or NONE) do
		if C_SpellBook.IsSpellKnown(spell) then
			known = true
			break
		end
	end
	can[kind] = known
	return known
end

local DISPEL = { M = "Magic", C = "Curse", D = "Disease", P = "Poison" }
local HOLDS = { f = "Fears", r = "Roots", x = "Silences", z = "Takes someone out", t = "Stuns", m = "Charms" }
-- What a spell asks of a group, the part that is yours to answer first.
function J.Cues(row)
	local out = {}
	local cues = row.cues
	local function Add(key, words, color, mine)
		out[#out + 1] = { key = key, words = words, color = color, mine = mine or false }
	end
	local own = cues:find("u", 1, true) ~= nil
	if cues:find("c", 1, true) then
		local mine = J.Can("kick")
		Add("kick", mine and "Interrupt it" or "Can be interrupted", mine and C.hot or C.text, mine)
	end
	for letter, name in pairs(DISPEL) do
		if cues:find(letter, 1, true) then
			if own then
				local mine = letter == "M" and J.Can("purge")
				Add("purge", mine and "Purge it" or (name .. " on itself"), mine and C.hot or C.text, mine)
			else
				local mine = J.Can(letter)
				Add("dispel", mine and (name .. ": dispel it") or name, mine and C.hot or C.text, mine)
			end
		end
	end
	if cues:find("e", 1, true) then Add("enrage", "Enrages", C.alert) end
	if cues:find("h", 1, true) then Add("heal", "Heals", C.good) end
	if cues:find("n", 1, true) then Add("adds", "Calls help", C.alert) end
	if cues:find("a", 1, true) and not own then Add("area", "Hits an area", C.text) end
	if cues:find("o", 1, true) and not own then Add("dot", "Damage over time", C.text) end
	for letter, words in pairs(HOLDS) do
		if cues:find(letter, 1, true) and not own then Add("hold", words, C.text) end
	end
	table.sort(out, function(x, y)
		if x.mine ~= y.mine then return x.mine end
		return x.words < y.words
	end)
	return out
end

---------------------------------------------------------------------------
-- What drops
---------------------------------------------------------------------------
local RANK = { forever = 3, seen = 2, classic = 1 }
function J.Loot(map, key)
	local rows, by = {}, {}
	local function Add(item, chance, source, kills)
		local row = by[item]
		if not row then
			row = { item = item }
			by[item] = row
			rows[#rows + 1] = row
		end
		if not row.source or RANK[source] > RANK[row.source] then
			row.chance, row.source, row.kills = chance, source, kills
		end
		return row
	end
	local seen = data.dungeonSeen and data.dungeonSeen[map]
	local text = seen and seen[key]
	for _, part in ipairs(text and Fields(text, ";") or NONE) do
		local f = Fields(part, ":")
		local item = tonumber(f[1])
		if item then Add(item, tonumber(f[2]), "forever", tonumber(f[3])) end
	end
	local ours = data.dungeonLoot and data.dungeonLoot[map]
	text = ours and ours[key]
	for _, part in ipairs(text and Fields(text, ";") or NONE) do
		local f = Fields(part, ":")
		local item = tonumber(f[1])
		if item then Add(item, tonumber(f[2]), f[3] == "s" and "seen" or "classic", tonumber(f[4])) end
	end
	-- What you have seen yourself: its own row where nothing else has the item, a mark on the row where something does.
	local book = J.Book(map)
	local boss = book and type(key) == "number" and book.bosses[key]
	local record = boss and Noted(map, boss)
	if record and (record.k or 0) > 0 then
		for item, times in pairs(record.i or NONE) do
			local row = by[item] or Add(item, 100 * times / record.k, "seen", record.k)
			row.mine = true
		end
	end
	for _, row in ipairs(rows) do
		if row.chance and row.chance <= 0 then row.chance = nil end
	end
	table.sort(rows, function(x, y)
		local cx, cy = x.chance or -1, y.chance or -1
		if cx ~= cy then return cx > cy end
		return x.item < y.item
	end)
	return rows
end

-- What a quest pays. One in your log is asked of the game; another is as Classic had it.
function J.Rewards(quest, carried)
	local out = {}
	local function Add(item, note)
		if item then out[#out + 1] = { item = item, note = note, source = "quest" } end
	end
	if carried then
		for i = 1, GetNumQuestLogChoices(quest, true) do
			local link = GetQuestLogItemLink("choice", i, quest)
			Add(link and tonumber(link:match("item:(%d+)")), "Choose one")
		end
		for i = 1, GetNumQuestLogRewards(quest) do
			local link = GetQuestLogItemLink("reward", i, quest)
			Add(link and tonumber(link:match("item:(%d+)")), "You get")
		end
		if #out > 0 then return out end
	end
	local text = data.dungeonRewards and data.dungeonRewards[quest]
	for kind, item in (text or ""):gmatch("([cg])(%d+)") do
		Add(tonumber(item), kind == "c" and "Choose one" or "You get")
	end
	return out
end

function J.Others(map)
	local seen = data.dungeonSeen and data.dungeonSeen[map]
	local out = {}
	for _, other in ipairs(seen and seen.others or NONE) do
		local rows = {}
		for _, part in ipairs(Fields(other[2], ";")) do
			local f = Fields(part, ":")
			local item = tonumber(f[1])
			if item then rows[#rows + 1] = { item = item, chance = tonumber(f[2]), source = "forever", kills = tonumber(f[3]) } end
		end
		out[#out + 1] = { name = other[1], loot = rows }
	end
	return out
end

function J.Door(map)
	local doors = T.db and T.db.doors
	return doors and doors[map]
end

-- Every drop by item. Made a dungeon at a time a while after logging in, out of a fight (all at once on the first
-- hover it was a hitch), and whatever is left of it at once if asked first.
J.drops = { by = {}, done = 0, WAIT = 20, EVERY = 0.2 }
local function TakeDungeon(one)
	local by, book = J.drops.by, J.Book(one.map)
	local function Take(key, boss)
		for _, row in ipairs(J.Loot(one.map, key)) do
			local list = by[row.item]
			if not list then
				list = {}
				by[row.item] = list
			end
			list[#list + 1] = { map = one.map, name = one.name, boss = boss, index = type(key) == "number" and key or nil,
				chance = row.chance, source = row.source }
		end
	end
	for index, boss in ipairs(book.bosses) do Take(index, boss.name) end
	Take("trash")
end
-- The dungeons up to `last` taken in; true once all are.
function J.drops.Upto(last)
	local list, d = J.List(), J.drops
	while d.done < math.min(last, #list) do
		d.done = d.done + 1
		TakeDungeon(list[d.done])
	end
	return d.done >= #list
end
function J.Drops(item)
	J.drops.Upto(math.huge)
	return item and J.drops.by[item] or nil
end
Shy:On("SHY_LOGIN", function()
	C_Timer.After(J.drops.WAIT, function()
		local ticker
		ticker = C_Timer.NewTicker(J.drops.EVERY, function()
			if InCombatLockdown() then return end
			if J.drops.Upto(J.drops.done + 1) then ticker:Cancel() end
		end)
	end)
end)

---------------------------------------------------------------------------
-- Finding, and what you want
---------------------------------------------------------------------------
-- A name as it is compared: small letters, without a leading "the".
local function Plain(name)
	return (name or ""):lower():gsub("^the%s+", "")
end

-- The instance map of the dungeon a name is (an entrance's on the world map), or nil.
local named
function J.ByName(name)
	if not named then
		named = {}
		for _, one in ipairs(J.List()) do named[Plain(one.name)] = one.map end
	end
	return named[Plain(name)]
end

function J.Search(text)
	local out = {}
	text = strtrim(text or ""):lower()
	if text == "" then return out end
	for _, one in ipairs(J.List()) do
		if one.name:lower():find(text, 1, true) then
			out[#out + 1] = { map = one.map, name = one.name, under = one.kind == "raid" and "Raid" or "Dungeon" }
		end
		for index, boss in ipairs(J.Book(one.map).bosses) do
			if boss.name:lower():find(text, 1, true) then
				out[#out + 1] = { map = one.map, boss = index, name = boss.name, under = one.name }
			end
		end
	end
	return out
end

function J.Wanted(item)
	return T.db ~= nil and T.db.want[item] == true
end

function J.Want(item, on)
	T.db.want[item] = on and true or nil
	Shy:Fire("SHY_MAPS_WANT", item, on and true or false)
end

-- The drops you starred that a dungeon has: { { item, boss (its name or nil) } }.
function J.WantedIn(map)
	local out = {}
	if not (T.db and next(T.db.want)) then return out end
	J.Drops()
	for item in pairs(T.db.want) do
		for _, drop in ipairs(J.drops.by[item] or NONE) do
			if drop.map == map then
				out[#out + 1] = { item = item, boss = drop.boss, index = drop.index }
				break
			end
		end
	end
	table.sort(out, function(x, y) return x.item < y.item end)
	return out
end

-- Your spells changed: what you can answer is asked again.
Shy:On("SHY_SPELLS", function() wipe(can) end)
