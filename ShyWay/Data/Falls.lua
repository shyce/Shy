-- Generated file. Do not edit by hand.
-- The spells that slow a fall, as Shy.Way reckons the drops it may lead down, and those that walk on
-- water: each spell, the seconds it lasts, the level it is learned at, its reagent (0: none), its cooldown
-- in seconds, the spells that do away with its reagent, and 1 where it is a glide steered on the way down.
Shy.Way.data.falls = {
	speed = 7, safe = 27,
	spells = {
		{ 130, 30, 12, 17056, 0, {  }, 0 },   -- Slow Fall
		{ 1706, 120, 34, 17056, 0, {  }, 0 },   -- Levitate
		{ 1259416, 10, 0, 0, 90, {  }, 1 },   -- Walk on Air
	},
	water = {
		{ 546, 600, 0, 17058, 0, {  }, 0 },   -- Water Walking
		{ 1706, 120, 34, 17056, 0, {  }, 0 },   -- Levitate
	},
}
