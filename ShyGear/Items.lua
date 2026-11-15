-- Reads an item: stats from C_Item.GetItemStats plus tooltip lines, usability from the tooltip's red text.
--
-- Item: { link, id, name, quality, sell, equipLoc, slots, stats = { str, agi, sta, int, spi, armor,
--   dps, ap, rap, feral, spell, heal, power, health, mana, hp5, mp5, hit, spellHit, crit, spellCrit, haste,
--   expertise, defense, dodge, parry, block }, usable, why (the red line), later (required level, when
--   that is the only bar), extra (has a use, equip or on-hit effect), unread (stat keys not counted),
--   weight (body armor: 1 cloth to 4 plate), kind ("Leather") }. Cached per link; ns.Forget() clears.

local ADDON, ns = ...

-- GetItemStats keys are global string names. Ratings stay ratings here; Model.lua asks the client what
-- they come to at the character's level. Spell power is both damage and healing; the other two one each.
local STAT = {
	ITEM_MOD_STRENGTH_SHORT = "str",
	ITEM_MOD_AGILITY_SHORT = "agi",
	ITEM_MOD_STAMINA_SHORT = "sta",
	ITEM_MOD_INTELLECT_SHORT = "int",
	ITEM_MOD_SPIRIT_SHORT = "spi",
	RESISTANCE0_NAME = "armor",
	ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
	ITEM_MOD_ATTACK_POWER_SHORT = "ap",
	ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
	ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feral",
	ITEM_MOD_SPELL_POWER_SHORT = "power",
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spell",
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
	ITEM_MOD_HEALTH_SHORT = "health",
	ITEM_MOD_MANA_SHORT = "mana",
	ITEM_MOD_HEALTH_REGEN_SHORT = "hp5",
	ITEM_MOD_MANA_REGENERATION_SHORT = "mp5",
	ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
	ITEM_MOD_HIT_RATING_SHORT = "hit",
	ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
	ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit",
	ITEM_MOD_CRIT_RATING_SHORT = "crit",
	ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
	ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit",
	ITEM_MOD_HASTE_RATING_SHORT = "haste",
	ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
	ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense",
	ITEM_MOD_DODGE_RATING_SHORT = "dodge",
	ITEM_MOD_PARRY_RATING_SHORT = "parry",
	ITEM_MOD_BLOCK_RATING_SHORT = "block",
}

-- The game's key for each stat, to name it (the first of two keys for one stat).
ns.STAT_KEY = {}
for key, to in pairs(STAT) do
	if not ns.STAT_KEY[to] or key < ns.STAT_KEY[to] then ns.STAT_KEY[to] = key end
end

-- Bonus armor is already in the tooltip's armor line, which is read below.
local COVERED = { ITEM_MOD_EXTRA_ARMOR_SHORT = true }

-- Whether a GetItemStats key is weighed.
function ns.Counted(key)
	return STAT[key] ~= nil or COVERED[key] == true
end

-- GetItemStats calls a resistance ITEM_MOD_NATURE_RESISTANCE_SHORT, a global the game doesn't have;
-- the game's word for it is its school's RESISTANCEn_NAME ("Nature Resistance").
local SCHOOL = { HOLY = 1, FIRE = 2, NATURE = 3, FROST = 4, SHADOW = 5, ARCANE = 6 }

-- A GetItemStats key as the game words it, capitalized. Never the key itself: one the game has no
-- word for is spelled out from the key ("ITEM_MOD_SOME_THING_SHORT" -> "Some thing").
function ns.StatName(key)
	local name = _G[key]
	if type(name) ~= "string" then
		local school = SCHOOL[key:match("^ITEM_MOD_(%u+)_RESISTANCE_SHORT$") or ""]
		name = school and _G["RESISTANCE" .. school .. "_NAME"]
	end
	if type(name) ~= "string" then
		name = key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower()
	end
	return (name:gsub("^%l", string.upper))
end

-- Tooltip line formats: "%c%s Agility", "%s Armor", "(%s damage per second)".
local LINES = {
	{ "str", "ITEM_MOD_STRENGTH" },
	{ "agi", "ITEM_MOD_AGILITY" },
	{ "sta", "ITEM_MOD_STAMINA" },
	{ "int", "ITEM_MOD_INTELLECT" },
	{ "spi", "ITEM_MOD_SPIRIT" },
	{ "armor", "ARMOR_TEMPLATE" },
	{ "dps", "DPS_TEMPLATE" },
}

-- Two slots means either one; Model.lua drops a one-hander's off-hand slot without dual wield.
local SLOTS = {
	INVTYPE_HEAD = { INVSLOT_HEAD },
	INVTYPE_NECK = { INVSLOT_NECK },
	INVTYPE_SHOULDER = { INVSLOT_SHOULDER },
	INVTYPE_CHEST = { INVSLOT_CHEST },
	INVTYPE_ROBE = { INVSLOT_CHEST },
	INVTYPE_WAIST = { INVSLOT_WAIST },
	INVTYPE_LEGS = { INVSLOT_LEGS },
	INVTYPE_FEET = { INVSLOT_FEET },
	INVTYPE_WRIST = { INVSLOT_WRIST },
	INVTYPE_HAND = { INVSLOT_HAND },
	INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
	INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
	INVTYPE_CLOAK = { INVSLOT_BACK },
	INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
	INVTYPE_2HWEAPON = { INVSLOT_MAINHAND },
	INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND },
	INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND },
	INVTYPE_SHIELD = { INVSLOT_OFFHAND },
	INVTYPE_HOLDABLE = { INVSLOT_OFFHAND },
	INVTYPE_RANGED = { INVSLOT_RANGED },
	INVTYPE_RANGEDRIGHT = { INVSLOT_RANGED },
	INVTYPE_THROWN = { INVSLOT_RANGED },
	INVTYPE_RELIC = { INVSLOT_RANGED },
}

-- Body armor, lightest first; the index is its weight. Cloaks get none.
local ARMOR = { Enum.ItemArmorSubclass.Cloth, Enum.ItemArmorSubclass.Leather, Enum.ItemArmorSubclass.Mail, Enum.ItemArmorSubclass.Plate }
local WEIGHT = {}
for weight, subclass in ipairs(ARMOR) do WEIGHT[subclass] = weight end

function ns.ArmorName(weight)
	return (C_Item.GetItemSubClassInfo(Enum.ItemClass.Armor, ARMOR[weight]))
end

local cache = {}
local patterns, levelPattern, durabilityPattern, effects

-- Turns a line format into a pattern capturing its sign and number.
local CAPTURE = { c = "([%+%-])", s = "([%d%.,]+)", d = "(%d+)" }
local function Pattern(format)
	local p = format:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
	p = p:gsub("%%([csd])", CAPTURE)
	return "^" .. p .. "$"
end

local function Patterns()
	patterns = {}
	for _, line in ipairs(LINES) do
		patterns[#patterns + 1] = { key = line[1], pattern = Pattern(_G[line[2]]) }
	end
	levelPattern = Pattern(ITEM_MIN_LEVEL)
	durabilityPattern = Pattern(DURABILITY_TEMPLATE)
	effects = { ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC }
end

-- Parses a localized number; called with (sign, digits) or (digits).
local function Amount(a, b)
	local sign, digits = a, b
	if not digits then sign, digits = nil, a end
	local plain = digits
	if DECIMAL_SEPERATOR ~= "." then
		plain = plain:gsub("%.", ""):gsub(DECIMAL_SEPERATOR, ".")
	else
		plain = plain:gsub(LARGE_NUMBER_SEPERATOR, "")
	end
	local n = tonumber(plain)
	if not n then return end
	return sign == "-" and -n or n
end

local function Red(color)
	return color ~= nil and color.r > 0.9 and color.g < 0.3 and color.b < 0.3
end

local function StartsWith(text, word)
	return text:sub(1, #word) == word
end

-- Returns false when the tooltip can't be read.
local function ReadTooltip(item)
	local data = C_TooltipInfo.GetHyperlink(item.link)
	if not data or not data.lines then return false end
	if not patterns then Patterns() end
	local shown = {}
	item.usable = true
	for _, line in ipairs(data.lines) do
		local text, right = line.leftText, line.rightText
		if issecretvalue(text) or issecretvalue(right) then return false end
		if type(text) == "string" then
			for _, p in ipairs(patterns) do
				local a, b = text:match(p.pattern)
				local n = a and Amount(a, b)
				if n then shown[p.key] = (shown[p.key] or 0) + n end
			end
			for _, word in ipairs(effects) do
				if StartsWith(text, word) then item.extra = true end
			end
			if Red(line.leftColor) and not text:match(durabilityPattern) then
				local level = tonumber(text:match(levelPattern))
				if level then
					item.later = level
				else
					item.usable, item.why = false, item.why or text
				end
			end
		end
		-- Armor type and weapon type are the right-hand text of the slot line.
		if type(right) == "string" and Red(line.rightColor) then
			item.usable, item.why = false, item.why or right
		end
	end
	if not item.usable then item.later = nil end
	-- The tooltip includes random enchantments and enchants that GetItemStats can omit.
	for key, n in pairs(shown) do
		if n > (item.stats[key] or 0) then item.stats[key] = n end
	end
	return true
end

function ns.Read(link)
	if type(link) ~= "string" or issecretvalue(link) then return end
	local item = cache[link]
	if item then return item end
	local name, _, quality, _, _, _, kind, _, equipLoc, _, sell, classID, subclassID = C_Item.GetItemInfo(link)
	if not name then
		-- Not loaded yet: GET_ITEM_INFO_RECEIVED follows for it, and only then are verdicts asked again.
		local id = C_Item.GetItemInfoInstant(link)
		if id then ns.awaited[id] = true end
		return
	end
	item = {
		link = link, id = C_Item.GetItemInfoInstant(link), name = name, quality = quality,
		sell = sell or 0, equipLoc = equipLoc, slots = SLOTS[equipLoc], classID = classID, stats = {},
	}
	if classID == Enum.ItemClass.Armor and equipLoc ~= "INVTYPE_CLOAK" and WEIGHT[subclassID] then
		item.weight, item.kind = WEIGHT[subclassID], kind
	end
	if item.slots then
		local stats = C_Item.GetItemStats(link)
		if stats then
			for key, n in pairs(stats) do
				local to = STAT[key]
				if to then
					item.stats[to] = (item.stats[to] or 0) + n
				elseif not COVERED[key] then
					item.unread = item.unread or {}
					item.unread[#item.unread + 1] = key
				end
			end
		end
		-- No tooltip yet: don't cache, and ask again soon.
		if not ReadTooltip(item) then
			ns.Later()
			return
		end
	end
	cache[link] = item
	return item
end

function ns.Worn(slot)
	local link = GetInventoryItemLink("player", slot)
	return link and ns.Read(link)
end

function ns.Forget()
	wipe(cache)
end
