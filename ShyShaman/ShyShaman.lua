-- ShyShaman: a shaman's keys laid out once for every level (Keys.lua). Does nothing on other classes, and
-- the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyShaman\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Shaman",
	icon = MEDIA .. "ShyShaman",
	smallIcon = MEDIA .. "ShyShamanSmall",
	tagline = "Your keys, for every level",
	savedVariables = "ShyShamanDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	defaults = {},
})
ns.T = T

ns.isShaman = select(2, UnitClass("player")) == "SHAMAN"

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isShaman then return end
	ns.SetupKeys()
end

SLASH_SHYSHAMAN1 = "/shyshaman"
SlashCmdList.SHYSHAMAN = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" then
		ns.Keys.Run()
	elseif cmd == "keys list" then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shyshaman  - open options")
		print("  /shyshaman keys  - lay out your keys and macros, for every level")
		print("  /shyshaman keys list  - every key and what it does")
	end
end
