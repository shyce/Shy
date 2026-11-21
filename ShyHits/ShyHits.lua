-- ShyHits: floating damage and healing numbers beside nameplates and beside the player.
-- The combat log is closed to addons on this client (C_CombatLogSecure); UNIT_COMBAT
-- reports each hit a unit takes but not its source, so in a group the numbers on a nameplate are
-- everyone's: so they are in a party; in a raid only those that land as you act are written (Feed.lua).
-- API (Shy.addons.Hits): :IsOn(), :Test()

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyHits\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Hits",
	category = "combat",
	icon = MEDIA .. "ShyHits",
	smallIcon = MEDIA .. "ShyHitsSmall",
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
	Shy:Fire("SHY_SWITCH", "shyhits-you")   -- its piece's switch in layout mode follows its setting
end

function T:Test()
	ns.Feed.Test()
end

function T:OnLoad()
	-- The engine reads this global once at login, so a change applies from the next login.
	if self.db.gameFont then DAMAGE_TEXT_FONT = Shy.FONT_ROUNDED end
end

function T:OnLogin()
	ns.Where.Start()
	ns.Feed.Start()
	if ns.Gains then ns.Gains.Start() end
end

local function Switch(on)
	T.db.on = on
	ns.Apply()
	T:Print(on and "on." or "off, default combat text is back.")
end

T:Command("on", "turn the numbers on", function() Switch(true) end)
T:Command("off", "go back to the default combat text", function() Switch(false) end)
-- For finding faults: sample hits. Not listed.
T:Command("test", nil, function() T:Test() end)
