-- What a dungeon shows you, noted as you play, by instance map and creature, on the account (T.db.seen):
--   what drops     the corpse you loot (your dead target as its loot opens) with what it held. A corpse counts
--                  once however often its loot is opened. Read out of a fight.
--   who a boss is  a boss the journal knows by name alone (one only this game has) is the creature you target
--                  or loot under that name: from then on the journal can show it, and what it drops is its.
--   what it casts  the spells your target begins while it is one of the dungeon's bosses.
--   where it is    for a boss: the ground you are on by its name as you target or loot it (`z`: the game's own
--                  name for that part of the dungeon), and as you loot it, standing on it, the place itself
--                  where the game says it in there (`w`: north, west, up). The journal sets its mark there on
--                  a floor that has none for it.
--   the way in     where you stand as you come into a dungeon by a loading screen (not a reload inside it), on
--                  the account by instance map (T.db.doors: north, west, up): the journal's way in where its
--                  floor has none.
-- Nothing the game withholds is looked at: a name, a GUID or a spell it keeps secret in a fight is left alone.
-- The journal shows what is noted at once. A drop you starred is called out as it shows up.
--   Seen.Note(map, creature, name, guid, items)   a corpse's loot
--   Seen.Met(map, creature, name)                 a creature met under its name
--   Seen.Cast(map, creature, name, spell)         a spell it began

local ADDON, ns = ...
local T = ns.T

local Seen = {}
ns.DungeonSeen = Seen

local NOTICE = 6             -- seconds a starred drop's notice stays
local counted = {}           -- corpses noted this session, by GUID

-- The creature a GUID is of, or nil for anything else.
local function Creature(guid)
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
	return tonumber(id)
end

local Boss

local function Record(map, creature, name)
	local db = T.db.seen
	db[map] = db[map] or {}
	local record = db[map][creature]
	if not record then
		record = { k = 0, i = {} }
		db[map][creature] = record
	end
	if name then record.n = name end
	return record
end

-- Where you are, onto a boss's record: the ground's name, and with `here` (you stand on it) the place.
local function Where(record, here)
	local name = GetSubZoneText()
	if name and not issecretvalue(name) and name ~= "" then record.z = name end
	if here then
		local north, west, up = Shy.Stand()
		if north then record.w = { north, west, up or 0 } end
	end
end

-- Notes one corpse: `items` what it held (item IDs). Returns its record.
function Seen.Note(map, creature, name, guid, items)
	local record = Record(map, creature, name)
	if counted[guid] then return record end
	counted[guid] = true
	if Boss(map, name) then
		Where(record, true)
		-- (Looted: it is down this run, whatever the game said of its fight.)
		local book = ns.Dungeons.Book(map)
		for index, boss in ipairs(book and ns.DungeonRun and book.bosses or {}) do
			if boss.name == name then ns.DungeonRun.Kill(map, index) end
		end
	end
	record.k = record.k + 1
	for _, item in ipairs(items) do
		record.i[item] = (record.i[item] or 0) + 1
	end
	return record
end

-- Whether a name is one of the dungeon's bosses'.
Boss = function(map, name)
	local book = name and ns.Dungeons and ns.Dungeons.Book(map)
	for _, boss in ipairs(book and book.bosses or {}) do
		if boss.name == name then return true end
	end
	return false
end

-- A creature met under a boss's name: told once, the first time.
function Seen.Met(map, creature, name)
	local known = T.db.seen[map] and T.db.seen[map][creature]
	if known and known.n == name then
		-- (Met again: the ground it is on, where that was not known.)
		if not known.z then Where(known) end
		return false
	end
	Where(Record(map, creature, name))
	Shy:Fire("SHY_MAPS_SEEN", map, creature)
	return true
end

-- A spell a boss began: told the first time it is seen.
function Seen.Cast(map, creature, name, spell)
	local record = Record(map, creature, name)
	record.s = record.s or {}
	local first = record.s[spell] == nil
	record.s[spell] = (record.s[spell] or 0) + 1
	if first then Shy:Fire("SHY_MAPS_SEEN", map, creature) end
	return first
end

local function Wanted(item, link)
	if not (ns.Dungeons and ns.Dungeons.Wanted(item)) then return end
	PlaySound(SOUNDKIT.READY_CHECK)
	if Shy.Notices and Shy.Notices.Voice then
		Shy.Notices.Voice("shymaps-want", { priority = 5, hold = NOTICE, icon = C_Item.GetItemIconByID(item),
			title = C_Item.GetItemNameByID(item) or "A drop you wanted", under = "You starred this" })
	else
		T:Print(("%s dropped. You starred it."):format(link))
	end
end

-- The dungeon you are in (its instance map), and your target as a creature there: map, creature, name, guid.
-- Nothing where you are in no dungeon, have no creature targeted, or the game withholds who it is.
local function Target()
	if not T.db then return end
	local _, kind, _, _, _, _, _, map = GetInstanceInfo()
	if (kind ~= "party" and kind ~= "raid") or not map then return end
	local guid = UnitGUID("target")
	if not guid or issecretvalue(guid) then return end
	local creature = Creature(guid)
	if not creature then return end
	local name = UnitName("target")
	if issecretvalue(name) then name = nil end
	return map, creature, name, guid
end

local function Opened()
	if InCombatLockdown() then return end
	local map, creature, name, guid = Target()
	if not map then return end
	local dead = UnitIsDead("target")
	if issecretvalue(dead) or not dead then return end
	local items = {}
	for slot = 1, GetNumLootItems() do
		local link = GetLootSlotLink(slot)
		if link and not issecretvalue(link) then
			local item = tonumber(link:match("item:(%d+)"))
			if item then
				items[#items + 1] = item
				if not counted[guid] then Wanted(item, link) end
			end
		end
	end
	Seen.Note(map, creature, name, guid, items)
	Shy:Fire("SHY_MAPS_SEEN", map, creature)
end

local function Targeted()
	local map, creature, name = Target()
	if map and Boss(map, name) then Seen.Met(map, creature, name) end
end

local function Began(spell)
	if not spell or issecretvalue(spell) then return end
	local map, creature, name = Target()
	if map and Boss(map, name) then Seen.Cast(map, creature, name, spell) end
end

-- Come into a dungeon: where you stand is its way in. A moment after the loading screen, once the game says where
-- you are in there.
local COME_IN = 0.5          -- seconds after entering the world
local function CameIn()
	if not T.db then return end
	local _, kind, _, _, _, _, _, map = GetInstanceInfo()
	if (kind ~= "party" and kind ~= "raid") or not map then return end
	local north, west, up = Shy.Stand()
	if not north then return end
	T.db.doors[map] = { north, west, up or 0 }
end
Seen.CameIn = CameIn

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
events:SetScript("OnEvent", function(_, event, a, b, spell)
	local ok, err = true, nil
	if event == "LOOT_OPENED" then
		ok, err = pcall(Opened)
	elseif event == "PLAYER_TARGET_CHANGED" then
		ok, err = pcall(Targeted)
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- (a: the first login, b: a reload: neither stands at a way in.)
		if not a and not b then
			C_Timer.After(COME_IN, function()
				local fine, why = pcall(CameIn)
				if not fine then geterrorhandler()(why) end
			end)
		end
	else
		ok, err = pcall(Began, spell)
	end
	if not ok then geterrorhandler()(err) end
end)
