-- ShyCrates: Waylaid Crates, filled in one click. A crate's tooltip lists the bundles that fill it and what each costs.
-- At the auction house a page of its window says what every crate you hold still needs and buys it; what you buy comes
-- by mail. Then the crate on the bags' rail glimmers, and its window (/shy crates) fills them, a click a crate.
--
-- API (Shy.addons.Crates):
--   :Bundles(crate)   the bundles that fill a labelled crate, the one to use first (Plan.lua has their fields), or nil
--   :Held()           the crates in your bags (Plan.Held)
--   :Count()          how many crates your characters hold, wherever ShyBags reads (your bags alone without it)
--   :Favor()          the currency a filled crate is handed in for (Merchant's Favor), as the game numbers it
--   :Icon()           a Waylaid Crate's picture
--   :Open()           the auction house's Crates page while you stand at one, else the window that fills them
-- Bus: SHY_CRATES () when what you hold or a price changes.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Crates",
	category = "items",
	icon = "Interface\\AddOns\\ShyCrates\\Media\\ShyCrates",
	smallIcon = "Interface\\AddOns\\ShyCrates\\Media\\ShyCratesSmall",
	savedVariables = "ShyCratesDB",
	defaults = {
		tooltip = true,   -- a crate's bundles on its card
	},
})
ns.T = T

function T:OnLogin()
	ns.Plan.Start()
	ns.Cast.Start()
	ns.Tooltip.Start()
	ns.Rail.Start()
end

function T:Bundles(crate)
	return ns.Plan.Of(crate)
end

function T:Held()
	return ns.Plan.Held()
end

-- Every crate, labelled or not to be read yet: the set ShyBags counts.
local every
local function Every()
	if not every then
		every = {}
		for crate in pairs(ns.crates) do every[crate] = true end
		for crate in pairs(ns.unread) do every[crate] = true end
	end
	return every
end

function T:Count()
	local bags = Shy.addons.Bags
	if bags and bags.Total then return bags:Total(Every()) end
	local held, n = ns.Plan.Held(), 0
	for _, count in pairs(held.counts) do n = n + count end
	return n + (held.unread and held.unread.count or 0)
end

function T:Favor()
	return ns.favor
end

function T:Icon()
	return C_Item.GetItemIconByID((next(ns.unread)))
end

function T:Open()
	local auction = Shy.addons.Auction
	if auction and auction.IsOpen and auction:IsOpen() and auction:Show("crates") then return end
	ns.Window.Open()
end

function T:Apply()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

T:Command("", "open your Waylaid Crates", function() T:Open() end)
