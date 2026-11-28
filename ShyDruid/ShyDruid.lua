-- ShyDruid: a druid's keys laid out once for every level (Keys.lua). Loaded for your class alone.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyDruid\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Druid",
	category = "combat",
	icon = MEDIA .. "ShyDruid",
	smallIcon = MEDIA .. "ShyDruidSmall",
	savedVariables = "ShyDruidDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isDruid = select(2, UnitClass("player")) == "DRUID"

function T:OnLogin()
	if not ns.isDruid then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

if ns.isDruid and Shy.Keys then
	T:Command("keys", "lay out your keys and macros, for every level", function(rest) ns.Keys.Run(rest) end)
	T:Command("keys force", "lay out every key, even ones you kept or moved", function() ns.Keys.Run("force") end)
end
