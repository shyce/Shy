-- ShyHunter: a hunter's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyHunter\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Hunter",
	category = "combat",
	icon = MEDIA .. "ShyHunter",
	smallIcon = MEDIA .. "ShyHunterSmall",
	savedVariables = "ShyHunterDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isHunter = select(2, UnitClass("player")) == "HUNTER"

function T:OnLogin()
	if not ns.isHunter then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

if ns.isHunter and Shy.Keys then
	T:Command("keys", "lay out your keys and macros, for every level", function(rest) ns.Keys.Run(rest) end)
	T:Command("keys force", "lay out every key, even ones you kept or moved", function() ns.Keys.Run("force") end)
end
