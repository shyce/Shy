-- A bounded, session-only cache of hostile units seen (nameplate, target, mouseover).
-- Level and guild can't be read from a GUID, so Death.lua looks attackers up here.
-- The recap may name a character by first name alone or with the surname: both are indexed.

local ADDON, ns = ...
local Secret = issecretvalue

local S = {}
ns.Seen = S

local MAX = 120
local SEPARATOR = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

local byId, byName = {}, {}
local order, at = {}, 1   -- GUIDs in a ring of MAX; `at` is the oldest's slot, the next to be taken

-- issecretvalue must come first: comparing a secret to nil is an error.
local function Read(value)
	if Secret(value) or value == nil then return nil end
	return value
end

local function Text(value)
	value = Read(value)
	if type(value) == "string" and value ~= "" then return value end
end

local function Forget(id)
	local entry = byId[id]
	if not entry then return end
	byId[id] = nil
	if byName[entry.name] == entry then byName[entry.name] = nil end
	if byName[entry.first] == entry then byName[entry.first] = nil end
end

function S.Note(unit)
	if Secret(unit) or type(unit) ~= "string" then return end
	local exists = UnitExists(unit)
	if Secret(exists) or not exists then return end
	-- Either direction: a neutral creature can be attacked before it can attack.
	local they, you = UnitCanAttack(unit, "player"), UnitCanAttack("player", unit)
	if Secret(they) or Secret(you) or not (they or you) then return end
	local id = Text(UnitGUID(unit))
	if not id then return end
	local first, last = UnitNameUnmodified(unit)
	first, last = Text(first), Text(last)
	if not first then return end

	local entry = byId[id]
	if not entry then
		-- The oldest gives way to a new one past MAX.
		local old = order[at]
		if old then Forget(old) end
		entry = {}
		byId[id] = entry
		order[at] = id
		at = at % MAX + 1
	end
	local player = Read(UnitIsPlayer(unit))
	if player ~= nil then entry.player = player == true end
	entry.first = first
	-- Client quirk: the recap gives creatures a bogus surname, so only players keep one.
	entry.name = (last and entry.player ~= false) and (first .. SEPARATOR .. last) or first
	local level = Read(UnitLevel(unit))
	if type(level) == "number" then entry.level = level end
	if entry.player then
		entry.classText = Text((UnitClass(unit)))
		entry.class = Text((UnitClassBase(unit)))
		entry.race = Text((UnitRace(unit)))
		entry.guild = Text((GetGuildInfo(unit)))
	end
	byName[entry.name], byName[entry.first] = entry, entry
end

-- Lookup by GUID, else by name.
function S.Find(id, name)
	return (id and byId[id]) or (name and byName[name]) or nil
end

function S.Start()
	local events = CreateFrame("Frame")
	events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then
			S.Note(unit)
		elseif event == "PLAYER_TARGET_CHANGED" then
			S.Note("target")
		else
			S.Note("mouseover")
		end
	end)
end
