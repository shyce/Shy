-- ShyPaladin: your seal on ShyDock's swing bar: the bar in the seal's color (Seal.lua) and seal twisting
-- (Twist.lua), and your keys laid out once for every level (Keys.lua). Does nothing on other classes, and the core switches it off for them from their next login.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyPaladin\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Paladin",
	icon = MEDIA .. "ShyPaladin",
	smallIcon = MEDIA .. "ShyPaladinSmall",
	tagline = "Your seal on the swing bar",
	savedVariables = "ShyPaladinDB",
	keep = { keysMade = true, keysBuild = true, keysBefore = true },   -- the macros made for your keys are no setting: a reset keeps them yours
	-- color: the bar in the seal's color. twist: "off", "light", or the light and a sound's key (Twist.lua's SOUNDS).
	defaults = { color = true, twist = "ding" },
})
ns.T = T

ns.isPaladin = select(2, UnitClass("player")) == "PALADIN"

function T:Apply()
	if ns.isPaladin then
		if ns.Seal then ns.Seal.Apply() end
		ns.Twist.Apply()
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	if not ns.isPaladin then return end
	ns.Twist.Start()
	if ns.Seal then ns.Seal.Start() end   -- guarded: a newly added file isn't loaded until the client restarts
	if ns.SetupKeys then ns.SetupKeys() end
end

SLASH_SHYPALADIN1 = "/shypaladin"
SlashCmdList.SHYPALADIN = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "seal" or cmd == "twist" then
		Shy.UI.ShowCopyBox("Your seal", ns.Twist.Report())
	elseif cmd == "keys" and ns.Keys then
		ns.Keys.Run()
	elseif cmd == "keys list" and ns.Keys then
		Shy.Hub.Open("keys")
	else
		T:Print("commands:")
		print("  /shypaladin  - open options")
		print("  /shypaladin keys  - lay out your keys and macros, for every level")
		print("  /shypaladin keys list  - every key and what it does")
		print("  /shypaladin seal  - how your seal and twist are being tracked")
	end
end
