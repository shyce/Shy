-- Account-wide data (ShyBagsStore), separate from settings so profiles never touch it.
--   ShyBagsStore = { version, chars = { [guid] = character }, items = { [itemID] = "quality;level;bind;name" },
--       checks = { [id] = { ok, at, note } } }
--   character = { name, surname, realm, class, faction, level, seen, money, moneyAt,
--       bags = { at = time, [bag] = { slot, ... } } }     the key ring is bag -1
--   slot = "<item>;<count>[;<flags>[;<name>]]", "" when empty
--     <item>   the link after "item:" minus linker level, spec and source context and trailing colons,
--              so identical items compare equal and "item:" .. <item> is a link again
--     <flags>  b bound, q quest item, s starts a quest
--     <name>   only when it differs from the base name ("... of the Monkey")
-- `items` caches what the client may not have loaded for another character's items.
-- A store written by a newer version is left untouched: this session works on a copy.

local ADDON, ns = ...
local T = ns.T

local Store = {}
ns.Store = Store

local VERSION = 1
local STEPS = {}       -- [version] = function(db): migration to that version

local db               -- ShyBagsStore, or a copy of a newer one
local me, myGuid       -- this character
local newer = false
local fresh = {}       -- itemID -> base name, once the client has loaded it
local asked = {}       -- itemID -> load requested

-- Slots

function Store.ItemString(link)
	local body = link:match("|Hitem:([^|]+)|h") or link:match("^item:(.+)$")
	if not body then return nil end
	local fields, n = {}, 0
	for field in (body .. ":"):gmatch("([^:]*):") do
		n = n + 1
		fields[n] = field
	end
	-- Fields 9, 10 and 12: linker level, spec and source context.
	if n >= 9 then fields[9] = "" end
	if n >= 10 then fields[10] = "" end
	if n >= 12 then fields[12] = "" end
	return (table.concat(fields, ":", 1, n):gsub(":+$", ""))
end

function Store.Pack(item, count, flags, name)
	local s = item .. ";" .. (count or 1)
	if name then return s .. ";" .. (flags or "") .. ";" .. name end
	if flags and flags ~= "" then return s .. ";" .. flags end
	return s
end

-- Returns item, count, flags, name; nil for an empty slot.
function Store.Unpack(slot)
	if not slot or slot == "" then return nil end
	local item, count, flags, name = slot:match("^([^;]*);(%d+);?([^;]*);?(.*)$")
	if not item then return nil end
	return item, tonumber(count), flags, name ~= "" and name or nil
end

function Store.ItemID(item)
	return tonumber(item:match("^(%d+)"))
end

function Store.Link(item)
	return "item:" .. item
end

-- Item facts

function Store.Learn(id, quality, level, bind, name)
	db.items[id] = (quality or "") .. ";" .. (level or "") .. ";" .. (bind or "") .. ";" .. (name or "")
end

-- Returns quality, required level, bind, name; nil where unknown.
function Store.Fact(id)
	local s = db.items[id]
	if not s then return nil end
	local quality, level, bind, name = s:match("^(%d*);(%d*);(%d*);(.*)$")
	return tonumber(quality), tonumber(level), tonumber(bind), name ~= "" and name or nil
end

-- Records an item. Returns its base name once the client has it; until then requests the load.
function Store.Note(id, quality, name)
	if fresh[id] then return fresh[id] end
	local base, _, q, _, level, _, _, _, _, _, _, _, _, bind = C_Item.GetItemInfo(id)
	if base then
		fresh[id] = base
		Store.Learn(id, q, level, bind, base)
		return base
	end
	if not db.items[id] then Store.Learn(id, quality, nil, nil, name) end
	if not asked[id] then
		asked[id] = true
		C_Item.RequestLoadItemDataByID(id)
	end
end

-- Characters

function Store.Me() return me end
function Store.Guid() return myGuid end
function Store.Char(guid) return db.chars[guid] end
function Store.IsNewer() return newer end

-- "First Surname".
function Store.Name(c)
	if c.surname and c.surname ~= "" then
		return c.name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. c.surname
	end
	return c.name
end

-- Your realm's ruleset where the game hasn't said its name yet: as this character last had it, else another of yours
-- on that realm (asked in one order, so the answer is always the same).
local function Ruleset()
	if me and me.realm and me.realm ~= "" then return Shy.Ruleset(me.realm) end
	local mine, guids = Shy.RealmOf(myGuid), {}
	for guid, c in pairs(db.chars) do
		if c.realm and c.realm ~= "" and Shy.RealmOf(guid) == mine then guids[#guids + 1] = guid end
	end
	table.sort(guids)
	return guids[1] and Shy.Ruleset(db.chars[guids[1]].realm) or nil
end

-- { guid, char } each of the characters on your realm (Shy.SameServer: and on a PvP one your side): this character
-- first whatever its level, then the highest level down, then the most gold, then by name. The rest are kept, not shown.
function Store.List()
	local list = {}
	local ruleset = Shy.Ruleset() or Ruleset()
	for guid, c in pairs(db.chars) do
		if guid == myGuid or Shy.SameServer(guid, c, ruleset) then list[#list + 1] = { guid = guid, char = c } end
	end
	table.sort(list, function(a, b)
		if (a.guid == myGuid) ~= (b.guid == myGuid) then return a.guid == myGuid end
		local al, bl = a.char.level or 0, b.char.level or 0
		if al ~= bl then return al > bl end
		local ag, bg = a.char.money or 0, b.char.money or 0
		if ag ~= bg then return ag > bg end
		local an, bn = Store.Name(a.char), Store.Name(b.char)
		if an ~= bn then return an < bn end
		return a.guid < b.guid
	end)
	return list
end

-- Never the current character.
function Store.Forget(guid)
	if guid == myGuid or not db.chars[guid] then return false end
	db.chars[guid] = nil
	Shy:Fire("SHY_BAGS_SCANNED", guid, "forgotten")
	return true
end

-- Stamps a source of this character as just read.
function Store.Touch(source)
	if not me then return end
	if type(me[source]) == "table" then me[source].at = ns.Now() end
	Shy:Fire("SHY_BAGS_SCANNED", myGuid, source)
end

function Store.Verdict(id, ok, note)
	db.checks[id] = { ok = ok, at = ns.Now(), note = note }
end

function Store.Checks() return db.checks end

-- Opening and closing

-- Drops cached facts for items nobody holds, has in the mail or has listed.
local function Sweep()
	local held = {}
	local function Slots(list)
		for _, slot in ipairs(list) do
			local item = Store.Unpack(slot)
			if item then held[Store.ItemID(item) or 0] = true end
		end
	end
	local function Bags(source)
		if not source then return end
		for _, list in pairs(source) do
			if type(list) == "table" then Slots(list) end
		end
	end
	for _, c in pairs(db.chars) do
		Bags(c.bags)
		Bags(c.bank)
		for _, row in ipairs(c.mail and c.mail.rows or {}) do Slots(row.items or {}) end
		for _, auction in ipairs(c.auctions or {}) do
			if auction.item then held[Store.ItemID(auction.item) or 0] = true end
		end
	end
	for id in pairs(db.items) do
		if not held[id] then db.items[id] = nil end
	end
end

function Store.Open()
	ShyBagsStore = ShyBagsStore or {}
	db = ShyBagsStore
	local version = db.version or 0
	if version > VERSION then
		newer = true
		db = Shy.CopyTable(db)
	else
		for step = version + 1, VERSION do
			if STEPS[step] then STEPS[step](db) end
		end
		db.version = VERSION
	end
	db.chars, db.items, db.checks = db.chars or {}, db.items or {}, db.checks or {}
end

-- Your realm's name, once the game says it: a moment into a session it may still be empty, and an empty one is never
-- kept over the one known.
function Store.Realm(c)
	local realm = GetRealmName()
	if type(realm) == "string" and not issecretvalue(realm) and realm ~= "" then c.realm = realm end
end

-- Nothing is stored until the player's GUID is readable.
function Store.Login()
	local guid = UnitGUID("player")
	if guid == nil or issecretvalue(guid) then return end
	local c = db.chars[guid] or {}
	db.chars[guid] = c
	local name, surname = UnitNameUnmodified("player")
	if name and not issecretvalue(name) then
		c.name = name
		c.surname = (surname and not issecretvalue(surname) and surname ~= "") and surname or nil
	end
	c.name = c.name or "?"
	local _, class = UnitClass("player")
	if class and not issecretvalue(class) then c.class = class end
	Store.Realm(c)
	c.ruleset = nil   -- (once kept, and read from an empty name: the realm's name says it)
	c.faction = UnitFactionGroup("player")
	c.level = UnitLevel("player")
	c.seen = ns.Now()
	me, myGuid = c, guid
	if newer then
		T:Print("saved data is from a newer ShyBags. Nothing new is saved until you update.")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, a, b)
	if not db then return end
	if event == "ITEM_DATA_LOAD_RESULT" then
		if asked[a] and b then
			asked[a] = nil
			Store.Note(a)
		end
	elseif event == "PLAYER_LEVEL_UP" then
		if me then me.level = a end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if me then Store.Realm(me) end
	else
		ns.Guard(Sweep)
	end
end)
