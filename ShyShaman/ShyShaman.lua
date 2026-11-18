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

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isShaman then return end
	if ns.SetupKeys then ns.SetupKeys() end   -- (nothing to lay out without ShyKeys)
end

SLASH_SHYSHAMAN1 = "/shyshaman"
SlashCmdList.SHYSHAMAN = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "keys" and ns.Keys then
		ns.Keys.Run()
	elseif cmd == "keys list" and ns.Keys then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shyshaman  - open options")
		print("  /shyshaman keys  - lay out your keys and macros, for every level")
		print("  /shyshaman keys list  - every key and what it does")
	end
end
