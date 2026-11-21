-- Settings: the meter, when it shows and what it shows.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function On()
	if T.db.on == true then return true end
	return false, "The threat meter is off."
end

T:Settings({
	apply = ns.Apply,
	{ key = "on", label = "Threat meter", words = "aggro table",
		desc = "Who has aggro on the mob you're fighting, and who's about to pull it." },
	{ key = "when", label = "Show it", items = ns.WHEN, enabled = On, words = "combat always group solo out of combat",
		desc = "In combat skips fights you're in alone with no pet. Always keeps the last fight up between fights." },
	Shy.Settings.Layout("Move and size the threat meter."),
	{ label = "Made-up fight", button = "Show", words = "test sample preview try", run = function() ns.Meter.Try() end,
		desc = "Fills the meter for ten seconds, so you can see your changes on it." },

	{ section = "What it shows" },
	{ key = "rows", label = "Rows at first", min = 3, max = 10, step = 1, settle = true, enabled = On, words = "height size tall",
		desc = "How tall the meter is until you size it yourself in layout mode. The rest scroll." },
	{ key = "pets", label = "Pets", enabled = On,
		desc = "Pets get a row too, in a darker shade of their owner's color." },
	{ key = "hover", label = "Follow your mouseover", enabled = On, words = "nameplate hover mouse",
		desc = "In a fight, mouse over an enemy's nameplate to see its threat. The meter goes back to your target after." },
	{ key = "warn", label = "Warn near the pull", enabled = On, words = "header light gold red",
		desc = "The meter's header lights gold, then red, as you get close to pulling. Tanking, it lights as the next player catches up." },
	{ note = "Your nameplates turn the same colors on the same mob.", needs = "Plates" },
})
