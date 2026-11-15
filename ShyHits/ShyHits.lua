-- ShyHits: floating damage and healing numbers beside nameplates and beside the player.
-- The combat log is closed to addons on this client (C_CombatLogSecure); UNIT_COMBAT
-- reports each hit a unit takes but not its source, so in a group the numbers on a nameplate are
-- everyone's: so they are in a party; in a raid only those that land as you act are written (Feed.lua).
-- API (Shy.addons.Hits): :IsOn(), :Test()

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyHits\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Hits",
	icon = MEDIA .. "ShyHits",
	smallIcon = MEDIA .. "ShyHitsSmall",
	tagline = "Damage and healing numbers beside the nameplate",
	savedVariables = "ShyHitsDB",
	defaults = {
		on = true,
		plates = true,
		you = true,
		friends = true,     -- heals on your party and your friendly target, on their unit frames
		place = "beside",   -- "beside" | "above"
		motion = "burst",   -- "burst" | "calm"
		size = 1,
		schools = true,
		weigh = true,       -- a blow well over your usual one is written larger
		lettering = true,   -- numbers in the theme's lettering
		-- What you gain, written like the numbers: experience, reputation, coin looted, skill, honor.
		gainXP = true, gainRep = true, gainCoin = true, gainSkill = true, gainHonor = true,
		words = true,
		healer = true,
		-- On nameplates in a party and in a raid: "all" (ours, everyone's hits) | "mine" (ours, only what is
		-- taken for your own) | "game" (Blizzard's numbers, yours alone).
		party = "all", raid = "mine",
		gameFont = true,
		cvars = {},         -- CVar values to restore
	},
})
ns.T = T

function T:IsOn()
	return self.db ~= nil and self.db.on == true
end

local appliers = {}
function ns.OnApply(fn)
	appliers[#appliers + 1] = fn
end

function ns.Apply()
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:Test()
	ns.Feed.Test()
end

function T:OnLoad()
	-- The engine reads this global once at login, so a change applies from the next login.
	if self.db.gameFont then DAMAGE_TEXT_FONT = Shy.FONT_ROUNDED end
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.Where.Start()
	ns.Feed.Start()
	if ns.Gains then ns.Gains.Start() end
end

SLASH_SHYHITS1 = "/shyhits"
SLASH_SHYHITS2 = "/shyh"
SlashCmdList.SHYHITS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "on" or cmd == "off" then
		T.db.on = cmd == "on"
		ns.Apply()
		T:Print(T.db.on and "on." or "off, default combat text is back.")
	elseif cmd == "test" then
		T:Test()
	else
		T:Print("commands:")
		print("  /shyhits  - open options")
		print("  /shyhits on | off  - these numbers, or the default combat text")
		print("  /shyhits test  - play sample hits on your target and on you")
	end
end
