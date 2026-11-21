-- ShyMage: a mage's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyMage\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Mage",
	category = "combat",
	icon = MEDIA .. "ShyMage",
	smallIcon = MEDIA .. "ShyMageSmall",
	savedVariables = "ShyMageDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isMage = select(2, UnitClass("player")) == "MAGE"

function T:OnLogin()
	if not ns.isMage then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

if ns.isMage and Shy.Keys then
	T:Command("keys", "lay out your keys and macros, for every level", function() ns.Keys.Run() end)
end
