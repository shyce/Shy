-- Generated file. Do not edit by hand.
-- A warrior's abilities by key: every rank, lowest first, and the stances (form IDs) each needs.
local _, ns = ...
ns.spells = {
	overpower = { ranks = { 7384, 7887, 11584, 11585 }, stances = { 17 } },   -- Overpower
	revenge = { ranks = { 6572, 6574, 7379, 11600, 11601, 25288 }, stances = { 18 } },   -- Revenge
	execute = { ranks = { 20647, 5308, 20658, 20660, 20661, 20662 }, stances = { 17, 19 } },   -- Execute
	victoryRush = { ranks = { 402927 }, stances = {  } },   -- Victory Rush
	ragingBlow = { ranks = { 402911 }, stances = {  } },   -- Raging Blow
	pummel = { ranks = { 6552, 6554 }, stances = { 19 } },   -- Pummel
	shieldBash = { ranks = { 72, 1671, 1672 }, stances = { 17, 18 } },   -- Shield Bash
	charge = { ranks = { 100, 6178, 11578 }, stances = { 17 } },   -- Charge
	intercept = { ranks = { 20252, 20616, 20617 }, stances = { 19 } },   -- Intercept
	taunt = { ranks = { 355 }, stances = { 18 } },   -- Taunt
	mockingBlow = { ranks = { 694, 7400, 7402, 20559, 20560 }, stances = { 17 } },   -- Mocking Blow
	sunder = { ranks = { 7386, 7405, 8380, 11596, 11597 }, stances = {  } },   -- Sunder Armor
	demoShout = { ranks = { 1160, 6190, 11554, 11555, 11556 }, stances = {  } },   -- Demoralizing Shout
	thunderClap = { ranks = { 6343, 8198, 8204, 8205, 11580, 11581 }, stances = { 17, 18 } },   -- Thunder Clap
	hamstring = { ranks = { 1715, 7372, 7373 }, stances = { 17, 19 } },   -- Hamstring
	mortalStrike = { ranks = { 12294, 21551, 21552, 21553 }, stances = {  } },   -- Mortal Strike
	rend = { ranks = { 772, 6546, 6547, 6548, 11572, 11573, 11574 }, stances = { 17, 18 } },   -- Rend
	battleShout = { ranks = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 }, stances = {  }, seconds = 180 },   -- Battle Shout
	commandingShout = { ranks = { 403215 }, stances = {  }, seconds = 300 },   -- Commanding Shout
}
-- The stances' form IDs (GetShapeshiftFormID).
ns.forms = { battle = 17, defensive = 18, berserker = 19 }
-- Stance form ID -> the stance's spell.
ns.stances = {
	[17] = 2457,   -- Battle Stance
	[18] = 71,   -- Defensive Stance
	[19] = 2458,   -- Berserker Stance
}
