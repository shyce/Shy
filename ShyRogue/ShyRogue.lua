-- ShyRogue: poison reminders (Poisons.lua), combo points (Combo.lua), lockboxes and pick pocket totals
-- (Thief.lua), poison colors on ShyDock's swing bar (Swing.lua). Does nothing on other classes, and the
-- core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyRogue\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Rogue",
	icon = MEDIA .. "ShyRogue",
	smallIcon = MEDIA .. "ShyRogueSmall",
	tagline = "Poisons, combo points, lockboxes and pick pocket",
	savedVariables = "ShyRogueDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- what was made for your keys, and what stood there before
	defaults = {
		poisons = {
			shown = true,
			mainHand = "instant",
			offHand = "instant",
			warnMinutes = 3,
			warnCharges = 10,
			lowStock = 5,
		},
		combo = { shown = true, when = "target" },   -- target | combat | always
		lockboxes = { shown = true },
		pickpocket = { report = false },
	},
})
ns.T = T

ns.isRogue = select(2, UnitClass("player")) == "ROGUE"

-- Item IDs from the 1.60.1 game data, lowest rank first. ShyDock reads the keys: don't rename them.
ns.POISONS = {
	{ key = "instant",     name = "Instant Poison",      items = { 6947, 6949, 6950, 8926, 8927, 8928 } },
	{ key = "deadly",      name = "Deadly Poison",       items = { 2892, 2893, 8984, 8985, 20844 } },
	{ key = "crippling",   name = "Crippling Poison",    items = { 3775, 3776 } },
	{ key = "mindnumbing", name = "Mind-numbing Poison", items = { 5237, 6951, 9186 } },
	{ key = "wound",       name = "Wound Poison",        items = { 10918, 10920, 10921, 10922 } },
	{ key = "occult",      name = "Occult Poison",       items = { 226374, 234444 } },
	{ key = "numbing",     name = "Numbing Poison",      items = { 217346 } },
	{ key = "sebacious",   name = "Sebacious Poison",    items = { 217345 } },
	{ key = "atrophic",    name = "Atrophic Poison",     items = { 217347 } },
}

ns.SPELL_PICK_LOCK = 1804
ns.SPELL_PICK_POCKET = 921
ns.SKILL_LOCKPICKING = 633

function ns.Money(copper)
	return Shy.UI.Money(copper)
end

-- Each module adds a refresh function; any option change calls them all.
ns.refreshers = {}
function ns.Refresh()
	for _, fn in ipairs(ns.refreshers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:OnLoad()
	ShyRogueCharDB = ShyRogueCharDB or {}
	Shy.MergeDefaults(ShyRogueCharDB, { money = 0, items = 0, value = 0 })
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isRogue then return end
	ns.SetupPoisons()
	ns.SetupCombo()
	ns.SetupThief()
	if ns.SetupKeys then ns.SetupKeys() end
	if ns.SetupSwing then ns.SetupSwing() end   -- guarded: a newly added file isn't loaded until the client restarts
end

SLASH_SHYROGUE1 = "/shyrogue"
SlashCmdList.SHYROGUE = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "keys" and ns.Keys then
		ns.Keys.Run()
	elseif cmd == "keys list" and ns.Keys then
		Shy.Hub.Open("keys")
	elseif cmd == "loot" then
		ns.PrintLoot()
	elseif cmd == "" then
		T:OpenOptions()
	else
		T:Print("commands:")
		print("  /shyrogue  - open options")
		print("  /shyrogue loot  - pick pocket totals")
	end
end
