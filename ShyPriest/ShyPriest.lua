-- ShyPriest: a priest's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyPriest\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Priest",
	category = "combat",
	icon = MEDIA .. "ShyPriest",
	smallIcon = MEDIA .. "ShyPriestSmall",
	savedVariables = "ShyPriestDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isPriest = select(2, UnitClass("player")) == "PRIEST"

function T:OnLogin()
	if not ns.isPriest then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

if ns.isPriest and Shy.Keys then
	T:Command("keys", "lay out your keys and macros, for every level", function() ns.Keys.Run() end)
end
