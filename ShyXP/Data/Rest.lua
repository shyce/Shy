-- Generated file. Do not edit by hand.
local _, ns = ...
ns.data = ns.data or {}
-- Rested XP. talent: the Legacy talent Well Rested (its tree, node and spell), and by rank how many
-- percent faster rested XP builds and how many percent more of it you can hold. The camp's auras:
-- the sleeping bag's buff (XP percent a stack, stacks at most), a camp tent nearby, the tent's rest
-- already had, sitting by a welcoming fire; tentShare: the percent of a level the tent raises rested XP to.
ns.data.rest = {
	talent = { tree = 1188, node = 110301, spell = 1225478, rate = { 4, 8, 12, 16, 20 }, cap = { 4, 8, 12, 16, 20 } },
	bag = 429959, bagEach = 1, bagMost = 3,
	tent = 1229487, had = 1229451, sitting = 1229739, tentShare = 5,
}
