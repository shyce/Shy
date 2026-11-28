-- ShyPaladin: your seal on ShyDock's swing bar: the bar in the seal's color (Seal.lua) and seal twisting
-- (Twist.lua), and your keys laid out once for every level (Keys.lua). Loaded for your class alone.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyPaladin\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Paladin",
	category = "combat",
	icon = MEDIA .. "ShyPaladin",
	smallIcon = MEDIA .. "ShyPaladinSmall",
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

function T:OnLogin()
	if not ns.isPaladin then return end
	ns.Twist.Start()
	if ns.Seal then ns.Seal.Start() end   -- guarded: a newly added file isn't loaded until the client restarts
	if ns.SetupKeys then ns.SetupKeys() end
end

if ns.isPaladin then
	local function Report() Shy.UI.ShowCopyBox("Your seal", ns.Twist.Report()) end
	-- For finding faults: how the seal and twist are tracked, to copy. Not listed.
	T:Command("seal", nil, Report)
	T:Command("twist", nil, Report)
	if Shy.Keys then
		T:Command("keys", "lay out your keys and macros, for every level", function(rest) ns.Keys.Run(rest) end)
		T:Command("keys force", "lay out every key, even ones you kept or moved", function() ns.Keys.Run("force") end)
	end
end
