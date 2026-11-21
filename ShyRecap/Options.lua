-- Settings: the line that comes up when you die, how long it stays, and which deaths bring it up.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function On() return T.db.on end

T:Settings({
	apply = function() ns.Apply() end,
	{ key = "on", label = "Death recap", words = "died killed killer blows line",
		desc = "When you die, a line says who killed you. Click it to see every blow." },
	{ key = "stay", label = "Stays up", sub = true, enabled = On, words = "close hide alive release reload",
		items = {
			{ value = "closed", text = "Until you close it" },
			{ value = "alive", text = "Until you're alive again" },
		},
		desc = "How long the line stays. Releasing or reloading doesn't close it." },
	{ key = "creatures", label = "PvE deaths", sub = true, enabled = On, words = "creatures mobs falling drowning players pvp",
		desc = "Dying to a creature, a fall or drowning brings the line up too. /shy recap shows your last death either way." },
	{ label = "Sample death", button = "Show", enabled = On, words = "test preview example",
		run = function() ns.Test() end,
		desc = "A made-up death comes up, so you can see how it looks." },
	Shy.Settings.Layout("Move the line on your screen."),
	{ note = "Shift-click the line to put your death in the chat box. Right-click it for more." },
})
