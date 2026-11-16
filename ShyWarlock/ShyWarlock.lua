-- ShyWarlock: a warlock's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyWarlock\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Warlock",
	category = "combat",
	icon = MEDIA .. "ShyWarlock",
	smallIcon = MEDIA .. "ShyWarlockSmall",
	savedVariables = "ShyWarlockDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isWarlock = select(2, UnitClass("player")) == "WARLOCK"

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isWarlock then return end
	ns.SetupKeys()
end

SLASH_SHYWARLOCK1 = "/shywarlock"
SlashCmdList.SHYWARLOCK = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" then
		ns.Keys.Run()
	elseif cmd == "keys list" then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shywarlock  - open options")
		print("  /shywarlock keys  - lay out your keys and macros, for every level")
		print("  /shywarlock keys list  - every key and what it does")
	end
end
