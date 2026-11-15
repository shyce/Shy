-- Unit readers and number formatting for the frame texts.
-- Can be secret: health, power, names, class, race, creature type, raid target, combo points, group standing,
-- and in a fight how a unit stands to you (friend or foe, can attack, reaction: seen on the target's target).
-- Never secret: level, classification, connected.

local ADDON, ns = ...

local U = {}
ns.Units = U

local floor, format = math.floor, string.format

function U.Secret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end
local Secret = U.Secret

-- Numbers

-- No ".0" on a whole number.
function U.Num(n)
	return format("%.14g", n)
end

-- To one decimal, exact halves to the even side.
function U.Round1(n)
	local norm = n * 10 + 0.5
	local whole = floor(norm)
	if norm == whole and whole % 2 == 1 then return (whole - 1) / 10 end
	return whole / 10
end

-- 12345 -> "12.3k", 1234567 -> "1.23m"; below ten thousand, the whole number.
function U.Short(v)
	if v >= 10000000 or v <= -10000000 then return format("%.1fm", v / 1000000) end
	if v >= 1000000 or v <= -1000000 then return format("%.2fm", v / 1000000) end
	if v >= 100000 or v <= -100000 then return format("%.0fk", v / 1000) end
	if v >= 10000 or v <= -10000 then return format("%.1fk", v / 1000) end
	return format("%d", floor(v + 0.5))
end

-- 6200 -> "6k", 1234567 -> "1m".
function U.VeryShort(v)
	if v >= 1000000 or v <= -1000000 then return format("%.0fm", v / 1000000) end
	if v >= 1000 or v <= -1000 then return format("%.0fk", v / 1000) end
	return format("%.0f", v)
end

-- Percent to one decimal; 0 of anything is 0.
function U.Percent(value, max)
	if value == 0 then return 0 end
	return U.Round1(value / max * 100)
end

-- "rrggbb", each channel floored, not rounded.
function U.Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255), floor(g * 255), floor(b * 255))
end

-- Text counted in letters, not bytes: how many it has, and its letters first..last counted from 1.
U.Length, U.Sub = Shy.UI.Letters, Shy.UI.Cut

-- Identity

-- First name and surname joined. A secret name can't be joined: returns the two parts and `true`.
function U.Name(unit)
	local name, surname = UnitName(unit)
	if Secret(name, surname) then return name, surname, true end
	if name and surname and surname ~= "" then
		return name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname, nil, false
	end
	return name, nil, false
end

-- A secret answer counts as not a friend: the texts then read as for anything else.
function U.IsFriend(unit)
	local friend = UnitIsFriend("player", unit)
	if Secret(friend) then return false end
	return friend
end

-- A disconnected member of your own group.
function U.Offline(unit)
	if UnitIsConnected(unit) then return false end
	if unit == "player" then return true end
	local inParty, inRaid = UnitInParty(unit), UnitInRaid(unit)
	if Secret(inParty, inRaid) then return false end
	return (inParty or inRaid) and true or false
end

local HOSTILE, NEUTRAL, FRIENDLY = { 226 / 255, 45 / 255, 75 / 255 }, { 1, 1, 34 / 255 }, { 0.2, 0.8, 0.15 }
local CIVILIAN, TAPPED, UNKNOWN_COLOR = { 48 / 255, 113 / 255, 191 / 255 }, { 0.5, 0.5, 0.5 }, { 0.8, 0.8, 0.8 }

-- How a unit stands to you, as a color. In a fight the game can keep any of these answers secret
-- (seen on the target's target): then the grey of an unknown class, so nothing is tested that can't be.
local function Standing(unit)
	local isPlayer, controlled = UnitIsPlayer(unit), UnitPlayerControlled(unit)
	if Secret(isPlayer, controlled) then return UNKNOWN_COLOR end
	if isPlayer or controlled then
		local attacksMe, attackable = UnitCanAttack(unit, "player"), UnitCanAttack("player", unit)
		if Secret(attacksMe, attackable) then return UNKNOWN_COLOR end
		if attacksMe then
			if attackable then return HOSTILE end
			return CIVILIAN
		end
		if attackable then return NEUTRAL end
		local pvp = UnitIsPVP(unit)
		if Secret(pvp) then return UNKNOWN_COLOR end
		if pvp then return FRIENDLY end
		return CIVILIAN
	end
	local tapped, dead = UnitIsTapDenied(unit), UnitIsDead(unit)
	if Secret(tapped, dead) then return UNKNOWN_COLOR end
	if tapped or dead then return TAPPED end
	local reaction = UnitReaction(unit, "player")
	if Secret(reaction) or not reaction then return UNKNOWN_COLOR end
	if reaction >= 5 then return FRIENDLY end
	if reaction == 4 then return NEUTRAL end
	return HOSTILE
end

function U.HostileColor(unit)
	local c = Standing(unit)
	return c[1], c[2], c[3]
end

-- Class color, or grey. The numbers can be secret: pass them straight to SetTextColor.
function U.ClassColor(unit)
	local _, class = UnitClass(unit)
	if Secret(class) or class then
		local color = C_ClassColor.GetClassColor(class)
		if not Secret(color) and color then return color.r, color.g, color.b end
	end
	return UNKNOWN_COLOR[1], UNKNOWN_COLOR[2], UNKNOWN_COLOR[3]
end

-- Health bar colors: a unit's own color at one lightness, so no class is louder than another,
-- and the same hue deep for the part that is missing. Worked out in OKLab.

local FILL_L, FILL_C = 0.63, 0.15     -- every fill's lightness, and the most chroma one keeps
local PALE_L, DULL_L = 0.84, 0.48     -- a white (priest) and a grey (tapped) have no hue to carry them
local DEEP_L, DEEP_C = 0.225, 0.45    -- the missing part: its lightness, and its share of the fill's chroma

local function Linear(c)
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Display(c)
	c = math.max(0, math.min(1, c))
	if c <= 0.0031308 then return c * 12.92 end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

local function ToLab(r, g, b)
	r, g, b = Linear(r), Linear(g), Linear(b)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

local function FromLab(L, a, b)
	local l = (L + 0.3963377774 * a + 0.2158037573 * b) ^ 3
	local m = (L - 0.1055613458 * a - 0.0638541728 * b) ^ 3
	local s = (L - 0.0894841775 * a - 1.2914855480 * b) ^ 3
	return Display(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		Display(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		Display(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
end

local tones = {}   -- "r g b" -> { fill r, g, b, missing r, g, b }

-- A color as a bar wears it: the fill, then the missing part.
function U.Tone(r, g, b)
	local key = format("%.3f %.3f %.3f", r, g, b)
	local tone = tones[key]
	if not tone then
		local L, a, bb = ToLab(r, g, b)
		local chroma = math.sqrt(a * a + bb * bb)
		local light = FILL_L
		if chroma < 0.02 then light = L > 0.9 and PALE_L or DULL_L end
		local keep = chroma > FILL_C and FILL_C / chroma or 1
		a, bb = a * keep, bb * keep
		local fr, fg, fb = FromLab(light, a, bb)
		local mr, mg, mb = FromLab(DEEP_L, a * DEEP_C, bb * DEEP_C)
		tone = { fr, fg, fb, mr, mg, mb }
		tones[key] = tone
	end
	return tone[1], tone[2], tone[3], tone[4], tone[5], tone[6]
end

-- A unit's health bar: class for a player, standing for anything else.
-- A secret class color can't be worked on: it comes back as it is, with no second color.
function U.BarColors(unit)
	local r, g, b
	local isPlayer = UnitIsPlayer(unit)
	if not Secret(isPlayer) and isPlayer then
		r, g, b = U.ClassColor(unit)
		if Secret(r, g, b) then return r, g, b end
	else
		r, g, b = U.HostileColor(unit)
	end
	return U.Tone(r, g, b)
end

local CLASSIFICATION = {
	rare = ITEM_QUALITY3_DESC,
	rareelite = ITEM_QUALITY3_DESC .. "-" .. ELITE,
	elite = ELITE,
	worldboss = BOSS,
}

function U.Classification(unit)
	return CLASSIFICATION[UnitClassification(unit)]
end

-- The level ("??" when unknown) and its difficulty color.
function U.Level(unit)
	local level = UnitLevel(unit)
	local color = GetCreatureDifficultyColor(level > 0 and level or 99)
	return level > 0 and level or "??", color.r, color.g, color.b
end

-- A player's race, else creature family or type. Second result: whether it is secret.
function U.Race(unit)
	local race
	if UnitIsPlayer(unit) then
		race = UnitRace(unit)
	else
		local family = UnitCreatureFamily(unit)
		if Secret(family) then return family, true end
		if family then return family, false end
		race = UnitCreatureType(unit)
		if Secret(race) then return race, true end
		return race or UNKNOWN, false
	end
	return race, Secret(race)
end

-- Form buffs by spell ID.
local FORMS = { { 24858, "Moonkin" }, { 1066, "Aquatic" }, { 783, "Travel" } }

-- A buff or debuff of that exact name, from any caster.
-- A secret aura is not returned at all, so false can also mean hidden (Texts.lua checks which).
function U.HasAura(unit, name)
	local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
	if Secret(aura) or aura then return true end
	aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HARMFUL")
	return (Secret(aura) or aura) and true or false
end

function U.DruidForm(unit)
	local _, class = UnitClass(unit)
	if Secret(class) or class ~= "DRUID" then return nil end
	local power = UnitPowerType(unit)
	if power == Enum.PowerType.Rage then return "Bear" end
	if power == Enum.PowerType.Energy then return "Cat" end
	for _, form in ipairs(FORMS) do
		local name = C_Spell.GetSpellName(form[1])
		if name and U.HasAura(unit, name) then return form[2] end
	end
	return nil
end

-- Your own raid subgroup, nil outside a raid.
function U.RaidGroup()
	if not IsInRaid() then return nil end
	for i = 1, GetNumGroupMembers() do
		local me = UnitIsUnit("raid" .. i, "player")
		if not Secret(me) and me then
			local _, _, subgroup = GetRaidRosterInfo(i)
			return subgroup
		end
	end
	return nil
end

-- Health and power

-- A ghost's 1 health counts as 0. Third result: the values are secret.
function U.Health(unit)
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if Secret(hp, max) then return hp, max, true end
	if hp == 1 and UnitIsGhost(unit) then hp = 0 end
	return hp, max, false
end

function U.Power(unit)
	local power, max = UnitPower(unit), UnitPowerMax(unit)
	return power, max, Secret(power, max)
end

-- Mana and energy rest full, rage rests empty; other power types don't count. Nil when secret.
function U.PowerUnrested()
	local power, max, secret = U.Power("player")
	if secret then return nil end
	local kind = UnitPowerType("player")
	if kind == Enum.PowerType.Mana or kind == Enum.PowerType.Energy then return power < max end
	if kind == Enum.PowerType.Rage then return power > 0 end
	return false
end

function U.ManaColor()
	local color = PowerBarColor.MANA
	return color.r, color.g, color.b
end
