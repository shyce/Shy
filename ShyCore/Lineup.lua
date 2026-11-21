-- The cooldown manager set up for a leveling build: which cooldowns stand in which row and in what order
-- (Data/Lineups.lua, by class and build), written into the game's own store of cooldown layouts as a layout
-- of its own and made the active one. The game reads that store as the interface loads, so a written lineup
-- shows after a reload; it shows only what the character has learned, so it fills in while leveling.
-- Only C_CooldownViewer.SetLayoutData writes: the game's layout code never runs ours.
--
--   Shy.Lineup.Has(build)      a lineup exists for this character's class and the build id
--   Shy.Lineup.Write(build, name)  writes and activates it: true, or false and why
--   Shy.Lineup.Current()       the build id last written for this character
--   Shy.Lineup.Refresh()       at login: writes it again if it would be laid out otherwise now
--   Shy.Lineup.Report()        what the cooldown manager holds, as text

local P = Shy.Profiles

local L = {}
Shy.Lineup = L

local PREFIX = "Shy - "      -- our layouts' names; any one of them under this class is ours to replace
local FORMAT, ENCODING = 5, 1   -- the game's save format and encoding we write

-- The game's save fields (CooldownViewerSettingsDataStoreSerialization.lua).
local VERSION, ACTIVE, LAYOUTS, NAMES = 1, 2, 3, 4
local ORDER, CATEGORIES = 1, 2

local function Mine()
	local db = ShyCoreDB
	db.lineups = db.lineups or {}
	return db.lineups
end

-- What was last written for each character, as Mark gives it: a lineup made otherwise since is rewritten.
local function Marks()
	local db = ShyCoreDB
	db.lineupMarks = db.lineupMarks or {}
	return db.lineupMarks
end

local function Lineup(build)
	local class = UnitClassBase("player")
	local all = Shy.CooldownLineups and class and Shy.CooldownLineups[class]
	return all and build and all[build]
end

function L.Has(build)
	return Lineup(build) ~= nil
end

function L.Current()
	return Mine()[P.Character()]
end

-- The game's categories in the order it lists them, every cooldown's place by default.
local function Sets()
	local C = Enum.CooldownViewerCategory
	local order, default, cooldowns, auras = {}, {}, {}, {}
	local kinds = {
		{ C.Essential, cooldowns }, { C.Utility, cooldowns }, { C.TrackedBuff, auras }, { C.TrackedBar, auras },
		{ C.EquipSlotEssential }, { C.EquipSlotTracked }, { C.SpecAgnosticEssential }, { C.SpecAgnosticTracked },
	}
	for _, kind in ipairs(kinds) do
		for _, id in ipairs(C_CooldownViewer.GetCooldownViewerCategorySet(kind[1], true)) do
			local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
			if info and not default[id] then
				order[#order + 1] = id
				default[id] = info.category
				if kind[2] and info.spellID then kind[2][info.spellID] = id end
			end
		end
	end
	return order, default, cooldowns, auras
end

local function Decode(text)
	if text == nil or text == "" then return {} end
	local bar = text:find("|", 1, true)
	if not bar or tonumber(text:sub(1, bar - 1)) ~= ENCODING then return nil end
	local packed = C_EncodingUtil.DecodeBase64(text:sub(bar + 1))
	local plain = packed and C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
	local data = plain and C_EncodingUtil.DeserializeCBOR(plain)
	return type(data) == "table" and data or nil
end

local function Encode(data)
	local plain = C_EncodingUtil.SerializeCBOR(data)
	local packed = C_EncodingUtil.CompressString(plain, Enum.CompressionMethod.Deflate)
	return ENCODING .. "|" .. C_EncodingUtil.EncodeBase64(packed)
end

-- The layout: the lineup's cooldowns first, row by row, each with its category written. A class cooldown
-- the lineup does not name is hidden: the rows show the build's rotation and its utility, not the rest of
-- what the class can do. A racial or a trinket keeps the game's own place.
local function Layout(lineup)
	local C = Enum.CooldownViewerCategory
	local list, category, cooldowns, auras = Sets()
	local hidden = {
		[C.Essential] = C.HiddenActive, [C.Utility] = C.HiddenActive,
		[C.TrackedBuff] = C.HiddenPassive, [C.TrackedBar] = C.HiddenPassive,
	}
	local order, placed, categories = {}, {}, {}
	local function Put(id, category)
		if not id or placed[id] then return end
		placed[id] = true
		order[#order + 1] = id
		categories[category] = categories[category] or {}
		table.insert(categories[category], id)
	end
	local rows = {
		{ "essential", cooldowns, C.Essential }, { "utility", cooldowns, C.Utility },
		{ "bars", auras, C.TrackedBar }, { "buffs", auras, C.TrackedBuff },
		{ "hideCooldowns", cooldowns, C.HiddenActive }, { "hideAuras", auras, C.HiddenPassive },
	}
	for _, row in ipairs(rows) do
		for _, spell in ipairs(lineup[row[1]] or {}) do Put(row[2][spell], row[3]) end
	end
	for _, id in ipairs(list) do
		if not placed[id] then
			local away = hidden[category[id]]
			if away then Put(id, away) else order[#order + 1] = id end
		end
	end
	return { [ORDER] = order, [CATEGORIES] = categories }
end

-- A layout as one string: its order, then each category's cooldowns. The game saves its layouts in an
-- order of its own, so what we wrote is held against what we would write now, never against its store.
local function Mark(layout)
	local parts, categories = { table.concat(layout[ORDER], ",") }, {}
	for category in pairs(layout[CATEGORIES]) do categories[#categories + 1] = category end
	table.sort(categories)
	for _, category in ipairs(categories) do
		parts[#parts + 1] = category .. ":" .. table.concat(layout[CATEGORIES][category], ",")
	end
	return table.concat(parts, "|")
end

-- Rewrites this character's lineup when it would be written otherwise now (the lineups or the way they are
-- laid out changed), and asks for a reload: the game reads that store as the interface loads. Only while
-- our lineup is the active layout: a layout the player chose, or their changes to ours, stay as they are.
function L.Refresh()
	if not Enum.CooldownViewerCategory.HiddenActive then return end
	local build = L.Current()
	local lineup = Lineup(build)
	if not lineup or not C_CooldownViewer.IsCooldownViewerAvailable() then return end
	local data = Decode(C_CooldownViewer.GetLayoutData())
	local spec = C_SpecializationInfo.GetSpecialization()
	if not (data and spec) then return end
	local tag = select(3, UnitClass("player")) * 10 + spec
	local active = (data[ACTIVE] or {})[tag]
	local known = active and (data[NAMES] or {})[active]
	if type(known) ~= "string" or known:sub(1, #PREFIX) ~= PREFIX then return end
	if Marks()[P.Character()] == Mark(Layout(lineup)) then return end
	if L.Write(build, known:sub(#PREFIX + 1)) then
		Shy.Reload("Your cooldown manager is laid out for your build. Reload to see it.")
	end
end

Shy:On("SHY_LOGIN", function() L.Refresh() end)

-- Writes the build's lineup into the game's cooldown layouts and makes it this class's active one,
-- replacing any lineup written before. The character's other layouts are kept as they are.
function L.Write(build, name)
	local lineup = Lineup(build)
	if not lineup then return false, "There is no cooldown lineup for this build." end
	local available, why = C_CooldownViewer.IsCooldownViewerAvailable()
	if not available then return false, why ~= "" and why or "The cooldown manager isn't available." end
	-- Set by the game's cooldown manager once it has loaded, with the categories it hides cooldowns in.
	if not Enum.CooldownViewerCategory.HiddenActive then return false, "The cooldown manager isn't on." end
	local spec = C_SpecializationInfo.GetSpecialization()
	if not spec then return false, "The game has no specialization for this character yet." end
	local tag = select(3, UnitClass("player")) * 10 + spec

	local data = Decode(C_CooldownViewer.GetLayoutData())
	if not data then return false, "The game's cooldown layouts couldn't be read." end
	local version = data[VERSION]
	if version ~= nil and (version < 4 or version > FORMAT) then
		return false, "Your cooldown layouts are saved in a format this can't write."
	end
	data[VERSION] = FORMAT
	data[ACTIVE] = data[ACTIVE] or {}
	data[LAYOUTS] = data[LAYOUTS] or {}
	data[NAMES] = data[NAMES] or {}
	local names, mine = data[NAMES], data[LAYOUTS][tag] or {}
	data[LAYOUTS][tag] = mine

	-- Our earlier lineup gives up its place; its id is kept for the new one.
	local id
	for layoutID in pairs(mine) do
		local known = names[layoutID]
		if type(known) == "string" and known:sub(1, #PREFIX) == PREFIX then
			mine[layoutID], names[layoutID] = nil, nil
			id = id or layoutID
		end
	end
	if not id then
		id = 0
		for _, layouts in pairs(data[LAYOUTS]) do
			for layoutID in pairs(layouts) do id = math.max(id, layoutID) end
		end
		id = id + 1
	end
	mine[id] = Layout(lineup)
	names[id] = PREFIX .. (name or build)
	data[ACTIVE][tag] = id

	C_CooldownViewer.SetLayoutData(Encode(data))
	Mine()[P.Character()] = build
	Marks()[P.Character()] = Mark(mine[id])
	return true
end

-- What the cooldown manager holds for this character, for the copy box.
function L.Report()
	local out = {}
	local function Add(text, ...) out[#out + 1] = select("#", ...) > 0 and text:format(...) or text end
	local available, why = C_CooldownViewer.IsCooldownViewerAvailable()
	Add("Cooldown manager: %s%s", available and "available" or "not available", (why and why ~= "") and (" (" .. why .. ")") or "")
	Add("Switched on: %s", tostring(C_CVar.GetCVarBool("cooldownViewerEnabled")))
	local spec = C_SpecializationInfo.GetSpecialization()
	Add("Class %s, specialization %s, layout tag %s", tostring(UnitClassBase("player")), tostring(spec),
		spec and tostring(select(3, UnitClass("player")) * 10 + spec) or "none")
	Add("Lineup written: %s (has data: %s)", tostring(L.Current()), tostring(L.Has(L.Current())))
	local data = Decode(C_CooldownViewer.GetLayoutData())
	if data then
		Add("Saved layouts (format %s):", tostring(data[VERSION]))
		for tag, layouts in pairs(data[LAYOUTS] or {}) do
			for id in pairs(layouts) do
				Add("  %s: %s%s", tostring(tag), tostring((data[NAMES] or {})[id]), (data[ACTIVE] or {})[tag] == id and "  (active)" or "")
			end
		end
	else
		Add("Saved layouts: unreadable")
	end
	if not available then return table.concat(out, "\n") end
	local C = Enum.CooldownViewerCategory
	for _, kind in ipairs({ { "Essential", C.Essential }, { "Utility", C.Utility }, { "Tracked buffs", C.TrackedBuff }, { "Tracked bars", C.TrackedBar } }) do
		local learned, all = {}, C_CooldownViewer.GetCooldownViewerCategorySet(kind[2], true)
		for _, id in ipairs(all) do
			local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
			if info and info.isKnown then
				learned[#learned + 1] = ("%s (%d)"):format(C_Spell.GetSpellName(info.spellID) or "?", info.spellID or 0)
			end
		end
		Add("%s by default: %d, learned %d: %s", kind[1], #all, #learned, table.concat(learned, ", "))
	end
	return table.concat(out, "\n")
end

-- (For finding faults: what the cooldown manager holds. Not listed.)
Shy.Command("cooldowns", nil, function()
	Shy.UI.ShowCopyBox("The cooldown manager", L.Report())
end)
