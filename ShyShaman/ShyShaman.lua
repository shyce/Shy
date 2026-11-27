-- ShyShaman: a shaman's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyShaman\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Shaman",
	category = "combat",
	icon = MEDIA .. "ShyShaman",
	smallIcon = MEDIA .. "ShyShamanSmall",
	savedVariables = "ShyShamanDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isShaman = select(2, UnitClass("player")) == "SHAMAN"

function T:OnLogin()
	if not ns.isShaman then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

if ns.isShaman and Shy.Keys then
	T:Command("keys", "lay out your keys and macros, for every level", function(rest) ns.Keys.Run(rest) end)
	T:Command("keys force", "lay out every key, even ones you kept or moved", function() ns.Keys.Run("force") end)
end
