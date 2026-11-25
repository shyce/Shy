-- Generated file. Do not edit by hand.
-- The account's Legacy points: the Legacy window's three trees, what to buy with the points in order
-- (Talented first: its ranks start a character's talent points sooner), why each, and the challenges
-- that each give a point. Read by Legacy.lua.
local _, ns = ...
ns.data = ns.data or {}
ns.data.legacy = {
	currency = 4225, cap = 16, talented = 110298,
	trees = { { 1187, "LEGACY_TREE_PROFESSIONS" }, { 1188, "LEGACY_TREE_ADVENTURE" }, { 1189, "LEGACY_TREE_PROGRESSION" } },   -- tree, the game's name for it (a global string): Professions, Adventure, Resourcefulness
	nodes = {   -- [node] = { tree's index, ranks, why }
		[110301] = { 2, 5, "Rested experience builds faster, and Talented needs all five ranks." },   -- Well Rested
		[110298] = { 2, 5, "Talent points from level 5 instead of 10, on every character." },   -- Talented
		[110296] = { 2, 5, "Health and mana back after every kill: less sitting down." },   -- Thrill of Adventure
		[110304] = { 2, 3, "The first step toward Frequent Flier's faster, cheaper flights." },   -- Field Guide
	},
	order = {
		110301, 110301, 110301, 110301, 110301,   -- Well Rested x5
		110298, 110298, 110298, 110298, 110298,   -- Talented x5
		110296, 110296, 110296, 110296, 110296,   -- Thrill of Adventure x5
		110304,   -- Field Guide
	},
	challenges = {
		61499, 61500, 61501, 61502, 61503, 61504, 61989, 61992, 61993, 61994, 61995, 61996,
		61997, 61998, 61999, 62000, 62001, 62002, 62003, 62004, 62005, 62006, 62007, 62008,
		62009, 62010, 62011, 62012, 62013, 62014, 62015, 62016, 62017, 62018, 62019, 62020,
		62021, 62022, 62023, 62024, 62025, 62026, 62028, 62029, 62030, 62054, 62382, 62031,
		62032, 62033, 62034, 62035, 62041, 62042, 62043, 62044, 62045, 62046, 62047, 62048,
		62049, 684, 63340, 63341, 63342, 63969, 63970, 63971, 63972, 63973, 63974, 63975,
		63976, 63977, 63978, 63979, 63980, 63981, 63982, 63983, 63984, 63985, 63986, 63987,
		63988, 63989, 63990, 63991, 63992, 63993, 63994, 63995, 63996, 63997, 63998, 63999,
		64000, 64001, 64002, 64003, 64004, 64005, 64006, 64007, 64008, 64009, 64010, 64011,
		64012, 64013, 64014, 64015, 64016, 64017, 64018, 64019, 64020, 64021, 64022, 64023,
		64024, 64025, 64026, 64027, 64028, 64029, 64030, 64031, 64032, 64033,
	},
}
