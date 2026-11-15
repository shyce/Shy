-- Generated file. Do not edit by hand.
-- A paladin's seals, every rank: spell ID -> kind. Unsealed Wrath (the talent): each melee swing stores
-- the seal in place for `seconds`, `stacks` at most, if it is one of `echoes` (its Echo aura).
local _, ns = ...
ns.seals = {
	[20375] = "command", [20915] = "command", [20918] = "command", [20919] = "command", [20920] = "command",
	[20162] = "crusader", [20305] = "crusader", [20306] = "crusader", [20307] = "crusader", [20308] = "crusader", [21082] = "crusader",
	[20163] = "fury", [20419] = "fury", [20421] = "fury", [20422] = "fury", [20423] = "fury", [1311649] = "fury", [1311656] = "fury",
	[20164] = "justice",
	[20165] = "light", [20347] = "light", [20348] = "light", [20349] = "light",
	[407798] = "martyrdom", [407799] = "martyrdom",
	[20154] = "righteousness", [20287] = "righteousness", [20288] = "righteousness", [20289] = "righteousness", [20290] = "righteousness", [20291] = "righteousness", [20292] = "righteousness", [20293] = "righteousness", [21084] = "righteousness",
	[20166] = "wisdom", [20356] = "wisdom", [20357] = "wisdom",
}
ns.twist = {
	talent = 1310735,
	seconds = 15,
	stacks = 3,
	echoes = { command = 1311703, righteousness = 1311704, fury = 1311701, justice = 1311705, light = 1328198, wisdom = 1328206 },
}
