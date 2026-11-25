-- Settings: the bundles on a crate's card, and the list.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

T:Settings({
	{ key = "tooltip", label = "Prices on tooltips", words = "waylaid crate tooltip price bundle",
		desc = "A crate's tooltip shows what fills it and what that costs." },
	{ label = "Your crates", button = "Open", words = "waylaid crate fill read label",
		run = function() T:Open() end,
		desc = "See the crates in your bags and fill them." },
})
