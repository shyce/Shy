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

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isHunter then return end
	ns.SetupKeys()
end

SLASH_SHYHUNTER1 = "/shyhunter"
SlashCmdList.SHYHUNTER = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" then
		ns.Keys.Run()
	elseif cmd == "keys list" then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shyhunter  - open options")
		print("  /shyhunter keys  - lay out your keys and macros, for every level")
		print("  /shyhunter keys list  - every key and what it does")
	end
end
