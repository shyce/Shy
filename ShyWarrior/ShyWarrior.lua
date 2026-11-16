-- ShyWarrior: lights an ability's own icon in the cooldown manager (or its action button) while it is open
-- (Openings.lua), times your shout and lights it when it's due (Shout.lua), and a light round the screen in
-- your look (Light.lua) for full rage and threat, with an alarm when a mob turns off you (Threat.lua), and lays
-- your keys out once for every level (Keys.lua). Sunder Armor and your shouts' times are the
-- cooldown manager's tracked bars (ShyCore's lineups). Does nothing on other classes, and the core switches
-- it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyWarrior\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Warrior",
	category = "combat",
	icon = MEDIA .. "ShyWarrior",
	smallIcon = MEDIA .. "ShyWarriorSmall",
	savedVariables = "ShyWarriorDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {
		openings = { shown = true, interrupt = true, charge = true, sound = false },
		shout = { shown = true, battle = true, commanding = true, warnSeconds = 20 },
		rage = { shown = true, from = 0.8 },   -- the light rises from this share of your rage
		-- role: auto (your group role, else your tank or healer layout's, else Defensive Stance) | tank | dps
		threat = { glow = true, strength = 0.7, role = "auto", alarm = true, sound = true },
	},
})
ns.T = T
ns.MEDIA = MEDIA

ns.isWarrior = select(2, UnitClass("player")) == "WARRIOR"

-- The highest rank of an ability you know, or nil. Kept until your spells change.
local known = {}
function ns.Known(key)
	local id = known[key]
	if id == nil then
		id = false
		local spell = ns.spells[key]
		for i = #(spell and spell.ranks or {}), 1, -1 do
			if C_SpellBook.IsSpellKnown(spell.ranks[i]) then
				id = spell.ranks[i]
				break
			end
		end
		known[key] = id
	end
	return id or nil
end

-- Whether the stance you stand in lets you use it; else the name of the first stance that does.
function ns.Stance(key)
	local need = ns.spells[key].stances
	if #need == 0 then return true end
	local form = GetShapeshiftFormID()
	for _, f in ipairs(need) do
		if f == form then return true end
	end
	return false, C_Spell.GetSpellName(ns.stances[need[1]])
end

-- Off cooldown, as far as the game will say: the global cooldown counts as ready, and a cooldown the game
-- keeps secret in a fight is taken as ready too.
function ns.Ready(id)
	local cd = C_Spell.GetSpellCooldown(id)
	if not cd or cd.isOnGCD or not cd.isActive then return true end
	local start, duration = cd.startTime, cd.duration
	if issecretvalue(start) or issecretvalue(duration) then return true end
	return start + duration - GetTime() < 0.25
end

-- Whether you are the tank: the setting, else your role (your group's, else your layout's: Shy.Role), else
-- Defensive Stance.
function ns.IsTank()
	local mode = T.db.threat.role
	if mode == "tank" then return true end
	if mode == "dps" then return false end
	local role = Shy.Role()
	if role then return role == "tank" end
	return GetShapeshiftFormID() == ns.forms.defensive
end

-- Each module adds a refresh function; any option change calls them all.
ns.refreshers = {}
function ns.Refresh()
	for _, fn in ipairs(ns.refreshers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isWarrior then return end
	local spells = CreateFrame("Frame")
	spells:RegisterEvent("SPELLS_CHANGED")
	spells:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
	spells:SetScript("OnEvent", function()
		wipe(known)
		ns.Refresh()
	end)
	ns.SetupOpenings()
	ns.SetupShout()
	ns.SetupThreat()
	if ns.SetupKeys then ns.SetupKeys() end
end

SLASH_SHYWARRIOR1 = "/shywarrior"
SlashCmdList.SHYWARRIOR = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "light" and ns.Threat then
		ns.Threat.Try()
	elseif cmd == "keys" and ns.Keys then
		ns.Keys.Run()
	elseif cmd == "keys list" and ns.Keys then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shywarrior  - open options")
		print("  /shywarrior keys  - lay out your keys and macros, for every level")
		print("  /shywarrior keys list  - every key and what it does")
		print("  /shywarrior light  - show the threat light from held to lost")
	end
end
