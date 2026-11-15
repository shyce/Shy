-- ShyMage: a mage's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyMage\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Mage",
	icon = MEDIA .. "ShyMage",
	smallIcon = MEDIA .. "ShyMageSmall",
	tagline = "Your keys, for every level",
	savedVariables = "ShyMageDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isMage = select(2, UnitClass("player")) == "MAGE"

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isMage then return end
	ns.SetupKeys()
end

SLASH_SHYMAGE1 = "/shymage"
SlashCmdList.SHYMAGE = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" then
		ns.Keys.Run()
	elseif cmd == "keys list" then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shymage  - open options")
		print("  /shymage keys  - lay out your keys and macros, for every level")
		print("  /shymage keys list  - every key and what it does")
	end
end
