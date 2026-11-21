-- Unit reads for a plate. A plate reads through a "reader": this table.
--
-- Secret values (per UnitDocumentation.lua): health, name, class, threat, raid mark, casts and UnitIsUnit
-- can be secret; level, classification, attackability, reaction, tapped and UnitIsPlayer cannot.
-- Readers return a secret untouched with a flag; the plate passes it to a setter or leaves the piece out.

local ADDON, ns = ...
local L = ns.Layout
local C = L.COLORS

local U = {}
ns.Units = U

function ns.Secret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end
local Secret = ns.Secret

-- Curves: let the game evaluate a secret value for us

local curves
function ns.Curves()
	if curves then return curves end
	-- 1 while any health is missing, 0 at full (ShyCore's, shared with the hover plate).
	curves = { hurt = Shy.UI.HurtCurve() }
	return curves
end

-- 0 below the i-th of `count` points, 1 from it on.
local comboCurves = {}
function ns.ComboCurve(i, count)
	if not comboCurves[i] then
		local curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		local at = (i - 0.5) / count
		curve:AddPoint(0, 0)
		curve:AddPoint(at - 0.001, 0)
		curve:AddPoint(at, 1)
		curve:AddPoint(1, 1)
		comboCurves[i] = curve
	end
	return comboCurves[i]
end

-- Identity

function U.Exists(unit)
	return UnitExists(unit)
end

-- On this client UnitName returns first name and surname. Returns `name, isSecret`.
function U.Name(unit)
	local name, surname = UnitName(unit)
	if Secret(name, surname) then return name, true end
	if name and surname and surname ~= "" and UnitIsPlayer(unit) then
		return name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname, false
	end
	return name or "", false
end

function U.IsPlayer(unit)
	return UnitIsPlayer(unit) and true or false
end

-- A player's guild: `name, yours, isSecret`; no name for none. A secret name is not handed on (whether there is
-- one at all can't be told): the plate keeps the last it read (Plate:Guild).
function U.Guild(unit)
	local guild = GetGuildInfo(unit)
	if Secret(guild) then return nil, false, true end
	if not guild or guild == "" then return nil, false, false end
	local yours = UnitIsInMyGuild(unit)
	return guild, not Secret(yours) and yours == true, false
end

-- The unit's GUID, or nil while the game keeps it secret.
function U.Guid(unit)
	local guid = UnitGUID(unit)
	if guid == nil or Secret(guid) then return nil end
	return guid
end

function U.CanAttack(unit)
	return UnitCanAttack("player", unit) and true or false
end

-- "hostile", "neutral" or "friendly".
function U.Stance(unit)
	if UnitIsPlayer(unit) or UnitPlayerControlled(unit) then
		if UnitCanAttack("player", unit) then return "hostile" end
		return "friendly"
	end
	local reaction = UnitReaction(unit, "player")
	if not reaction or reaction >= 5 then return "friendly" end
	if reaction == 4 then return "neutral" end
	return "hostile"
end

-- The crest of a player's PvP flag (Shy.UI.PvPCrest), or nil.
function U.Crest(unit)
	return Shy.UI.PvPCrest(unit)
end

function U.Tapped(unit)
	return not UnitPlayerControlled(unit) and UnitIsTapDenied(unit) and true or false
end

-- 0 for a hidden level (a boss, or far above the player).
function U.Level(unit)
	local level = UnitEffectiveLevel(unit)
	if not level or level <= 0 then return 0 end
	return level
end

function U.LevelColor(level)
	local color = GetCreatureDifficultyColor(level)
	return color.r, color.g, color.b
end

-- "boss", "rareelite", "elite", "rare" or nil (Shy.UI.UnitRank: a boss the game says is one, whatever its class).
function U.Rank(unit)
	return Shy.UI.UnitRank(unit)
end

-- The class, and so the color, can be secret: pass the result straight to a color setter.
function U.ClassColor(unit)
	local _, class = UnitClass(unit)
	if Secret(class) or class then
		local color = C_ClassColor.GetClassColor(class)
		if not Secret(color) and color then return color.r, color.g, color.b end
	end
	return nil
end

function U.Fighting(unit)
	return UnitAffectingCombat(unit) and true or false
end

-- UnitIsUnit can be secret: returns `value, isSecret`.
local function Same(unit, other)
	local same = UnitIsUnit(unit, other)
	if Secret(same) then return same, true end
	return same and true or false, false
end

function U.IsTarget(unit) return Same(unit, "target") end
function U.IsFocus(unit) return Same(unit, "focus") end
function U.IsMouseover(unit) return Same(unit, "mouseover") end

-- Health

-- Health and max may be secret, so the bar gets both raw. `smooth`: interpolation, or nil for immediate.
function U.FillHealth(bar, unit, smooth)
	local max = UnitHealthMax(unit)
	if not Secret(max) and max == 0 then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
	else
		bar:SetMinMaxValues(0, max)
		bar:SetValue(UnitHealth(unit), smooth)
	end
end

-- Health percent evaluated through `curve`; nil gives 0 to 100.
function U.HealthThrough(unit, curve)
	return UnitHealthPercent(unit, true, curve or CurveConstants.ScaleTo100)
end

function U.HealthValue(unit)
	return AbbreviateNumbers(UnitHealth(unit))
end

-- Threat, in a group only: Shy.Threat's answer (`margin, fighting, tanking, flip`; ShyCore/Core.lua).
function U.Threat(unit, mode)
	return Shy.Threat(unit, mode)
end

-- What your damage over time still has to deal (ShyDots): each spell's share, oldest first, as
-- { school, coming }, and the total; nil when nothing is coming.
function U.Breakdown(unit)
	local dots = Shy.addons.Dots
	if not dots or not dots:IsOn() then return nil end
	return dots:BreakdownOn(unit)
end

-- The segments and the check's meter get the unit's health raw: it can be secret (Doom.lua). Each segment
-- is one spell's share over the most health, the last also what more than them have; the meter the whole
-- over the health left. Returns how many segments are in use.
function U.FillDoom(doom, unit, list, total)
	local max, hp = UnitHealthMax(unit), UnitHealth(unit)
	local dead = not Secret(max) and max == 0
	local segs = doom.segs
	local used = math.min(#list, #segs)
	for i = 1, used do
		local coming = list[i].coming
		if i == used then
			for j = used + 1, #list do coming = coming + list[j].coming end
		end
		local seg = segs[i]
		if dead then
			seg:SetMinMaxValues(0, 1)
			seg:SetValue(0)
		else
			seg:SetMinMaxValues(0, max)
			seg:SetValue(coming)
		end
	end
	if dead then
		doom.meter:SetMinMaxValues(0, 1)
		doom.meter:SetValue(0)
	else
		doom.meter:SetMinMaxValues(0, hp)
		doom.meter:SetValue(total)
	end
	return used
end

-- Marks

-- `index, isThere`; the index may be secret.
function U.RaidMark(unit)
	local index = GetRaidTargetIndex(unit)
	if Secret(index) then return index, true end
	return index, index ~= nil
end

-- The line the game writes under a unit's name: the second tooltip line unless that is its level. `text, isSecret`.
local LEVEL_LINE = TOOLTIP_UNIT_LEVEL:match("^(.-)%%s") or ""
local function Under(unit)
	local data = C_TooltipInfo.GetUnit(unit)
	local line = data and data.lines and data.lines[2]
	local text = line and line.leftText
	if Secret(text) then return nil, true end
	if text and text ~= "" and not (LEVEL_LINE ~= "" and text:sub(1, #LEVEL_LINE) == LEVEL_LINE) then return text, false end
	return nil, false
end

-- An NPC's title. Cached per name.
local titles = {}

function U.Title(unit, name)
	if Secret(name) or name == "" or UnitIsPlayer(unit) then return nil end
	local title = titles[name]
	if title == nil then
		title = Under(unit) or false
		titles[name] = title
	end
	return title or nil
end

-- Minions

-- A player's pet, totem or guardian (a minion, as the game's own nameplates tell one): "mine" for yours, "theirs"
-- for anyone else's, nil for any other unit. Whether it is yours can be secret: it is then taken for another's.
function U.Minion(unit)
	local minion = UnitIsMinion(unit)
	if Secret(minion) or not minion then return nil end
	local mine = UnitIsOwnerOrControllerOfUnit("player", unit)
	if not Secret(mine) and mine then return "mine" end
	return "theirs"
end

-- Whose a minion is, as the game says it ("Ilse Varga's Pet"): `line, isSecret`. Never kept by name, as an NPC's
-- title is: two pets of one name have two owners (the plate keeps its unit's: Plate:Kin).
function U.Owner(unit)
	return Under(unit)
end

-- True while the game draws a minion's nameplate smaller itself (its "simplified nameplates" setting, which its
-- own frame tells the nameplate): what stands on it is then smaller already.
function U.Simplified()
	return C_CVar.GetCVarBitfield("nameplateSimplifiedTypes", Enum.NamePlateSimplifiedType.Minion) == true
end

-- Combo points on the target: `points, source`. The count can be secret.

function U.Combo()
	local source = UnitHasVehicleUI("player") and "vehicle" or "player"
	return GetComboPoints(source, "target"), source
end

-- True while the player uses energy (rogue, cat form) and can attack the unit.
function U.BuildsCombo(unit)
	return UnitPowerType("player") == Enum.PowerType.Energy and UnitCanAttack("player", unit) and true or false
end

function U.ComboLit(source, i, count)
	return UnitPowerPercent(source, Enum.PowerType.ComboPoints, false, ns.ComboCurve(i, count))
end

-- Health bar color: `r, g, b`, possibly secret (class color, or a threat the game keeps to a boolean), so for
-- a color setter only. A fourth result is the threat margin behind a plain threat color (Plate.lua glides
-- between margins and lights the bar when a tank's hold becomes secure).

function U.Color(unit, db, reader)
	reader = reader or U
	if reader.Tapped(unit) then return C.tapped[1], C.tapped[2], C.tapped[3] end
	local stance = reader.Stance(unit)
	local margin, fighting, tanking, inverted = nil, false, nil, false
	if stance ~= "friendly" then
		margin, fighting, tanking, inverted = reader.Threat(unit, db.threat)
	end
	if margin == "theirs" then return C.theirs[1], C.theirs[2], C.theirs[3] end
	if margin then
		local r, g, b = L.ThreatColor(margin)
		return r, g, b, margin
	end
	if Secret(tanking) or tanking ~= nil then
		local yes, no = C.held, C.lost
		if inverted then yes, no = no, yes end
		local Pick = C_CurveUtil.EvaluateColorValueFromBoolean
		return Pick(tanking, yes[1], no[1]), Pick(tanking, yes[2], no[2]), Pick(tanking, yes[3], no[3])
	end
	if db.classColors and reader.IsPlayer(unit) then
		local r, g, b = reader.ClassColor(unit)
		if Secret(r) or r then return r, g, b end
	end
	-- A neutral creature in combat with you counts as hostile.
	if stance == "neutral" and fighting then stance = "hostile" end
	local c = C[stance]
	return c[1], c[2], c[3]
end
