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

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isPriest then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

SLASH_SHYPRIEST1 = "/shypriest"
SlashCmdList.SHYPRIEST = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" and ns.Keys then
		ns.Keys.Run()
	elseif cmd == "keys list" and ns.Keys then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shypriest  - open options")
		print("  /shypriest keys  - lay out your keys and macros, for every level")
		print("  /shypriest keys list  - every key and what it does")
	end
end
