-- ShyDruid: a druid's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyDruid\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Druid",
	icon = MEDIA .. "ShyDruid",
	smallIcon = MEDIA .. "ShyDruidSmall",
	tagline = "Your keys, for every level",
	savedVariables = "ShyDruidDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isDruid = select(2, UnitClass("player")) == "DRUID"

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isDruid then return end
	ns.SetupKeys()
end

SLASH_SHYDRUID1 = "/shydruid"
SlashCmdList.SHYDRUID = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" then
		ns.Keys.Run()
	elseif cmd == "keys list" then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shydruid  - open options")
		print("  /shydruid keys  - lay out your keys and macros, for every level")
		print("  /shydruid keys list  - every key and what it does")
	end
end
