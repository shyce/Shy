-- Adds the caster's name, level and class or type to buff and debuff tooltips.
--
-- A caster's level and type need a unit token, and a creature's name is only
-- available while it is nearby, so units seen (nameplate, target, mouseover)
-- and the caster of each aura on the player are cached as they appear.
-- Aura data is secret in combat: cached data still shows, and auras are
-- re-scanned at PLAYER_REGEN_ENABLED. Check issecretvalue before anything else.
-- Blizzard rebuilds an aura tooltip every frame it is hovered, so the
-- post-call must stay a cache lookup.
--
-- An icon the game draws itself (ShyBuffs' aura containers) has a forbidden
-- tooltip that takes no lines, and the post-call never comes for it. Out of a
-- fight ShyBuffs shows the game's ordinary tooltip for the icon under the mouse
-- instead, which comes through here like any other.
--
-- The game shows no Lua errors: anything that fails here is said once in chat,
-- and /shy tweaks casters tells where the last aura tooltip got to.

local ADDON, ns = ...
local Secret = issecretvalue
local UI = Shy.UI

local SEPARATOR = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
local MAX_SEEN = 150
local RETRY = 1      -- seconds before an unresolved caster is looked up again
local ICON = 14

-- Reaction colors; must match ShyTip's.
local HOSTILE, NEUTRAL, FRIENDLY = { 1, 0.27, 0.27 }, { 1, 0.85, 0.25 }, { 0.35, 1, 0.40 }
local RANK = { elite = ELITE, rareelite = ITEM_QUALITY3_DESC .. " " .. ELITE, rare = ITEM_QUALITY3_DESC, worldboss = BOSS }
local RANK_ICON = {
	elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
	rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
}
-- Tooltip getter -> how to find the aura: by instance id, or by index through
-- the C_UnitAuras function named in `ask`. `harmful` where the getter implies it.
local GETTERS = {
	GetUnitAura = { ask = "GetAuraDataByIndex" },
	GetUnitBuff = { ask = "GetBuffDataByIndex", harmful = false },
	GetUnitDebuff = { ask = "GetDebuffDataByIndex", harmful = true },
	GetUnitAuraByAuraInstanceID = {},
	GetUnitBuffByAuraInstanceID = { harmful = false },
	GetUnitDebuffByAuraInstanceID = { harmful = true },
}

local casters
local seen, order = {}, {}    -- guid -> who; guids, oldest first
local kept = {}               -- aura instance id on the player -> { guid, who, own, harmful, asked }
local other = {}              -- { unit, id, entry }: the last aura looked up on another unit
local stale = true            -- `kept` may be incomplete: scan again
local scanned = 0             -- time of the last scan
local last = {}               -- what the latest aura tooltip led to (for the report)
local told = {}               -- error texts already said in chat

-- issecretvalue first: even `secret == nil` is a comparison.
local function Read(value)
	if Secret(value) or value == nil then return nil end
	return value
end

local function Text(value)
	value = Read(value)
	if type(value) == "string" and value ~= "" and value ~= UNKNOWNOBJECT then return value end
end

-- A failure is said once in chat (the game shows no Lua errors) and kept for the report.
local function Report(where, err)
	err = tostring(err)
	last.error = where .. ": " .. err
	if told[err] then return end
	told[err] = true
	ns.T:Print(casters.title .. ", " .. where .. ": " .. err)
end

-- Resolving a caster

-- `whole`: read from a unit, so nothing more can be learned. `into`: the record kept of the same unit, read
-- again in place (a target, a mouseover and each nameplate are read as they come: no new table each time).
local function FromUnit(unit, into)
	local exists = UnitExists(unit)
	if Secret(exists) or not exists then return nil end
	local first, surname = UnitName(unit)
	first, surname = Text(first), Text(surname)
	if not first then return nil end

	local who = into or {}
	if into then wipe(into) end
	who.whole, who.player, who.foe = true, Read(UnitIsPlayer(unit)) == true, Read(UnitCanAttack("player", unit)) == true
	-- On this client a unit's second name is a surname, and only players have one.
	who.name = (who.player and surname) and (first .. SEPARATOR .. surname) or first
	local level = Read(UnitLevel(unit))
	if type(level) == "number" then who.level = level end
	if who.player then
		local classText, class = UnitClass(unit)
		who.classText, who.class = Text(classText), Text(class)
		who.race = Text((UnitRace(unit)))
	else
		-- A pet shows its family (Cat, Imp) rather than its type (Beast, Demon).
		local pet = Read(UnitPlayerControlled(unit)) == true
		who.kind = (pet and Text(UnitCreatureFamily(unit))) or Text(UnitCreatureType(unit))
		who.rank = Text(UnitClassification(unit))
		local reaction = Read(UnitReaction(unit, "player"))
		if type(reaction) == "number" then who.reaction = reaction end
	end
	return who
end

local function FromGUID(guid)
	local who = { player = Read(C_PlayerInfo.GUIDIsPlayer(guid)) == true }
	local first, surname = UnitNameFromGUID(guid)
	first, surname = Text(first), Text(surname)
	if who.player then
		local classText, class, _, _, _, said, _, level = GetPlayerInfoByGUID(guid)
		who.classText, who.class = Text(classText), Text(class)
		if not who.class then
			classText, class = UnitClassFromGUID(guid)
			who.classText, who.class = Text(classText), Text(class)
		end
		level = Read(level)
		if type(level) == "number" and level > 0 then who.level = level end
		who.name = (first and surname and (first .. SEPARATOR .. surname)) or first or Text(said)
	else
		who.name = first
	end
	if not who.name then return nil end
	return who
end

local function Remember(guid, who)
	if not seen[guid] then
		order[#order + 1] = guid
		if #order > MAX_SEEN then seen[table.remove(order, 1)] = nil end
	end
	seen[guid] = who
end

local function See(unit)
	if Secret(unit) or type(unit) ~= "string" then return end
	local guid = Text(UnitGUID(unit))
	if not guid then return end
	local known = seen[guid]
	local who = FromUnit(unit, known and known.whole and known or nil)
	if who then Remember(guid, who) end
end

local function Yours(unit)
	local same = UnitIsUnit(unit, "player")
	if not Secret(same) and same then return true end
	same = UnitIsUnit(unit, "pet")
	if not Secret(same) and same then return true end
	return false
end

-- Returns who, own. Either argument may be nil; own is true for the player or pet.
local function Resolve(guid, source)
	if guid and (guid == Read(UnitGUID("player")) or guid == Read(UnitGUID("pet"))) then return nil, true end
	local unit = source
	-- A token like "target" may point at someone else by now.
	local theirs = unit and Read(UnitGUID(unit))
	if guid and theirs and theirs ~= guid then unit = nil end
	if not unit and guid then unit = Text(UnitTokenFromGUID(guid)) end
	if unit then
		if Yours(unit) then return nil, true end
		local who = FromUnit(unit)
		if who then
			if guid then Remember(guid, who) end
			return who
		end
	end
	if guid then return seen[guid] or FromGUID(guid) end
end

-- An aura's caster

-- Can error (aura gone, or restricted), so Make calls it under pcall.
local function Ask(unit, id, aura)
	if not Secret(aura) and aura == nil then aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id) end
	local source, harmful, name, icon
	if not Secret(aura) and aura then
		source, harmful, name = Text(aura.sourceUnit), Read(aura.isHarmful), Text(aura.name)
		icon = Read(aura.icon)
		if type(icon) ~= "number" then icon = nil end
	end
	return Text(C_UnitAuras.GetAuraCasterGUID(unit, id)), source, harmful, name, icon
end

local function Settled(entry)
	return entry.own or (entry.who and entry.who.whole) or false
end

-- `aura`: its AuraData when at hand. `old`: the previous entry for this aura.
local function Make(unit, id, aura, old)
	local entry = { asked = GetTime() }
	local ok, guid, source, harmful, name, icon = pcall(Ask, unit, id, aura)
	if ok then
		entry.guid, entry.harmful, entry.source, entry.name, entry.icon = guid, harmful, source, name, icon
		if guid or source then entry.who, entry.own = Resolve(guid, source) end
	else
		entry.err = tostring(guid)
	end
	-- Keep what was known before when it can't be read now (combat, caster gone).
	if old and (not entry.guid or entry.guid == old.guid) then
		entry.guid = entry.guid or old.guid
		entry.name, entry.icon = entry.name or old.name, entry.icon or old.icon
		if entry.harmful == nil then entry.harmful = old.harmful end
		if not entry.own and old.own then entry.own = true end
		if old.who and not (entry.who and entry.who.whole) then entry.who = old.who end
	end
	return entry
end

-- Re-reads every aura on the player. Stays stale while auras are secret.
local function Scan()
	stale, scanned = true, GetTime()
	if C_Secrets.ShouldAurasBeSecret() then return end
	local fresh, all = {}, true
	local function Each(aura)
		if not Secret(aura) and aura == nil then return end   -- the slot emptied since
		local id = not Secret(aura) and Read(aura.auraInstanceID)
		if id then fresh[id] = Make("player", id, aura, kept[id]) else all = false end
	end
	local function Slots(token, ...)
		for i = 1, select("#", ...) do
			Each(C_UnitAuras.GetAuraDataBySlot("player", (select(i, ...))))
		end
		return token
	end
	local ok, err = pcall(function()
		for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
			local token
			repeat
				token = Slots(C_UnitAuras.GetAuraSlots("player", filter, nil, token))
			until token == nil
		end
	end)
	if not ok then Report("reading your auras", err) end
	if ok and all then
		kept, stale = fresh, false
	else
		for id, entry in pairs(fresh) do kept[id] = entry end
	end
end

local function Changed(info)
	if Secret(info) or type(info) ~= "table" or Secret(info.isFullUpdate) or info.isFullUpdate then
		Scan()
		return
	end
	local removed, added, updated = info.removedAuraInstanceIDs, info.addedAuras, info.updatedAuraInstanceIDs
	if Secret(removed) or Secret(added) or Secret(updated) then
		stale = true
		return
	end
	for _, id in ipairs(removed or {}) do
		if Secret(id) then stale = true else kept[id] = nil end
	end
	for _, aura in ipairs(added or {}) do
		local id = not Secret(aura) and Read(aura.auraInstanceID)
		if id then kept[id] = Make("player", id, aura, nil) else stale = true end
	end
	-- A recast by someone else can keep the aura instance and change its caster.
	for _, id in ipairs(updated or {}) do
		local entry = not Secret(id) and kept[id]
		if entry then
			local ok, guid = pcall(C_UnitAuras.GetAuraCasterGUID, "player", id)
			guid = ok and Text(guid)
			if guid and guid ~= entry.guid then kept[id] = Make("player", id, nil, nil) end
		end
	end
end

-- The cached entry, refreshed at most once per RETRY while unresolved.
local function Entry(unit, id)
	local now = GetTime()
	if unit == "player" then
		if stale and now - scanned >= RETRY then Scan() end
		local entry = kept[id]
		if not entry or (not Settled(entry) and now - entry.asked >= RETRY) then
			entry = Make(unit, id, nil, entry)
			kept[id] = entry
		end
		return entry
	end
	-- Aura instance ids are per unit, and a token like "target" changes who it is.
	if other.unit ~= unit or other.id ~= id or now - other.entry.asked >= RETRY then
		other.unit, other.id, other.entry = unit, id, Make(unit, id, nil, nil)
	end
	return other.entry
end

-- The line

local function Color(who, harmful)
	if who.player then
		local color = who.class and C_ClassColor.GetClassColor(who.class)
		if color then return color:GetRGB() end
		return 1, 1, 1
	end
	local c
	if who.reaction then
		c = (who.reaction <= 3 and HOSTILE) or (who.reaction == 4 and NEUTRAL) or FRIENDLY
	else
		-- Never seen as a unit: a debuff's caster counts as hostile.
		c = (who.foe or harmful) and HOSTILE or FRIENDLY
	end
	return c[1], c[2], c[3]
end

local function Icon(who)
	local atlas
	if who.player then
		atlas = who.class and GetClassAtlas(who.class:lower())
	else
		atlas = RANK_ICON[who.rank]
	end
	if not atlas then return "" end
	return CreateAtlasMarkup(atlas, ICON, ICON) .. " "
end

local function Level(who)
	local level = who.level
	if not level then return nil end
	local text = level > 0 and tostring(level) or "??"
	if not who.foe then return text end
	if level <= 0 then return UI.Wrap(HOSTILE, text) end
	local c = GetCreatureDifficultyColor(level)
	return UI.Wrap({ c.r, c.g, c.b }, text)
end

-- "Level 24 Priest", "Level 23 Orc Warrior" (enemy players show race), "Level 21 Elite Beast".
local function Detail(who)
	local kind
	if who.player then
		kind = who.classText
		if kind and who.foe and who.race then kind = who.race .. " " .. kind end
	else
		kind = who.kind
		local rank = RANK[who.rank]
		if rank then kind = kind and (rank .. " " .. kind) or rank end
	end
	local level = Level(who)
	if level and kind then return TOOLTIP_UNIT_LEVEL:format(level) .. " " .. kind end
	if level then return TOOLTIP_UNIT_LEVEL:format(level) end
	return kind
end

-- Returns left text, right text (or nil), and the left text's r, g, b.
function ns.CasterLine(who, harmful, detail)
	return Icon(who) .. who.name, detail and Detail(who) or nil, Color(who, harmful)
end

-- Why an entry gets no line: a reason for the report, or nil when it does.
local function Silent(entry, harmful)
	if entry.own then return "cast by you" end
	if not entry.who then
		if entry.err then return "the game refused the caster: " .. entry.err end
		if entry.guid then return "caster " .. entry.guid .. " has no name the game knows" end
		return "the game gives no caster"
	end
	local opt = casters.opt
	if harmful == true and not opt.debuffs then return "debuffs are switched off" end
	if harmful == false and not opt.buffs then return "buffs are switched off" end
	if harmful == nil and not (opt.buffs and opt.debuffs) then return "buffs or debuffs are switched off" end
end

-- The tooltip

local function Handle(tip, data)
	last.at, last.error, last.line, last.why = GetTime(), nil, nil, nil
	-- The game's own aura icon: its tooltip may be asked nothing and given nothing. ShyBuffs names the caster there.
	if tip:IsForbidden() then
		last.forbidden, last.getter = true, nil
		return
	end
	local info = tip:GetProcessingTooltipInfo()
	local how = info and GETTERS[info.getterName]
	local args = how and info.getterArgs
	last.forbidden, last.getter = false, info and info.getterName
	if not args then return end
	local unit, id = args[1], args[2]
	if Secret(unit) or type(unit) ~= "string" or Secret(id) or type(id) ~= "number" then
		last.why = "the game hides buffs during a fight"
		return
	end
	if how.ask then
		local ok, aura = pcall(C_UnitAuras[how.ask], unit, id, args[3])
		id = ok and not Secret(aura) and aura and Read(aura.auraInstanceID)
		if type(id) ~= "number" then
			last.why = "the aura can't be read"
			return
		end
	end
	last.unit = unit

	local entry = Entry(unit, id)
	local harmful = how.harmful
	if harmful == nil then harmful = entry.harmful end
	last.why = Silent(entry, harmful)
	if last.why then return end

	local left, right, r, g, b = ns.CasterLine(entry.who, harmful, casters.opt.detail)
	last.line = left
	local dim = UI.colors.dim
	tip:AddLine(" ")
	if right then
		tip:AddDoubleLine(left, right, r, g, b, dim[1], dim[2], dim[3])
	else
		tip:AddLine(left, r, g, b)
	end
end

-- Runs inside the game's tooltip refresh, where an error would vanish unseen: it is said in chat instead.
local function OnTooltip(tip, data)
	if not casters.running then return end
	local ok, err = pcall(Handle, tip, data)
	if not ok then Report("tooltip", err) end
end

-- For ShyBuffs (Shy.addons.Tweaks:AuraCasters()): the auras on you that someone else cast, buffs first, by name:
-- { id (the aura's instance), name, icon, harmful, guid, who = { name, player, foe, class, ... } }.
-- Nil while the tweak is off or auras are secret.
function ns.T:AuraCasters()
	if not casters.running or C_Secrets.ShouldAurasBeSecret() then return nil end
	if stale then Scan() end
	local list = {}
	for id, entry in pairs(kept) do
		if entry.who and not entry.own and entry.name then
			list[#list + 1] = { id = id, name = entry.name, icon = entry.icon, harmful = entry.harmful == true,
				guid = entry.guid, who = entry.who }
		end
	end
	table.sort(list, function(a, b)
		if a.harmful ~= b.harmful then return not a.harmful end
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	return list
end

-- The report: /shy tweaks casters

local function Ago(at)
	local s = GetTime() - at
	if s < 60 then return ("%d s ago"):format(s) end
	return ("%d min ago"):format(s / 60)
end

-- As text, for the copy box.
function ns.CastersReport()
	local lines = {}
	local function Say(text) lines[#lines + 1] = text end
	local secret = C_Secrets.ShouldAurasBeSecret()
	Say(casters.title .. " is " .. (casters.running and "on" or "off") .. "."
		.. (secret and " The game hides buffs from addons during a fight, so nothing is read until it ends." or ""))
	if last.at then
		if last.forbidden then
			Say("Last aura tooltip " .. Ago(last.at) .. ": the game's own, on a buff icon, which addons can't add to.")
		else
			Say("Last aura tooltip " .. Ago(last.at) .. ": an addon's, through " .. tostring(last.getter) .. (last.unit and (" on " .. last.unit) or "") .. ".")
			if last.line then
				Say("Shown: " .. last.line)
			else
				Say("Nothing shown" .. (last.why and (": " .. last.why) or "") .. ".")
			end
		end
	else
		Say("No buff tooltip shown since login. Tooltips on ShyBuffs' icons don't come through in a fight.")
	end
	if last.error then Say("Last error: " .. last.error) end
	if secret then return table.concat(lines, "\n") end
	Scan()
	local n = 0
	for id, entry in pairs(kept) do
		n = n + 1
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
		local name = (ok and not Secret(aura) and aura and Text(aura.name)) or ("aura " .. id)
		local who = entry.own and "cast by you" or (entry.who and entry.who.name) or Silent(entry, entry.harmful) or "?"
		Say(name .. " - " .. who)
	end
	if n == 0 then Say("No auras on you.") end
	return table.concat(lines, "\n")
end

local hooked
local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function(_, _, _, info) Changed(info) end)

casters = ns.Feature({
	id = "casters",
	category = "Combat",
	title = "Who cast that buff",
	desc = "Buff and debuff tooltips show who cast them, with players in class color. You won't see it on your own.",
	keywords = "show buff debuff aura caster source cast by applied from who whom thank tooltip hover mouseover mob creature enemy player poison curse",
	default = true,
	options = {
		{ key = "buffs", kind = "checkbox", label = "On buffs", default = true,
			desc = "The name stays as long as the buff does, even after they leave." },
		{ key = "debuffs", kind = "checkbox", label = "On debuffs", default = true,
			desc = "Shows the mob or player who put it on you. If it lands in a fight, you'll see the name when the fight ends." },
		{ key = "detail", kind = "checkbox", label = "Level and class", default = true,
			desc = "Adds what they are on the right, like Level 24 Priest." },
	},
	events = {
		PLAYER_ENTERING_WORLD = Scan,
		-- Auras applied in combat are readable now; retry once while the caster's corpse can still be named.
		PLAYER_REGEN_ENABLED = function()
			Scan()
			if stale then C_Timer.After(RETRY, function()
				if casters.running and stale then Scan() end
			end) end
		end,
		NAME_PLATE_UNIT_ADDED = function(_, _, unit) See(unit) end,
		PLAYER_TARGET_CHANGED = function()
			other.unit = nil
			See("target")
		end,
		UPDATE_MOUSEOVER_UNIT = function() See("mouseover") end,
	},
	Enable = function()
		if not hooked then
			local ok, err = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.UnitAura, OnTooltip)
			if ok then hooked = true else Report("hooking aura tooltips", err) end
		end
		watch:RegisterUnitEvent("UNIT_AURA", "player")
		Scan()
	end,
	Disable = function()
		watch:UnregisterEvent("UNIT_AURA")
		kept, seen, order, other, stale = {}, {}, {}, {}, true
	end,
})
