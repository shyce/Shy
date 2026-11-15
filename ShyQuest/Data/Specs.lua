-- Generated file. Do not edit by hand.
-- Leveling talent builds per class: what each is for, a one-line reason, a caution where it is a hard
-- way to level, and a node for every talent point it plans; with each node's tab, row and rank count
-- from the client's trait tables for 1.60.1.70938. A class's first build is the one for questing alone.
-- An order is numbered by point: the first comes at level 10, or as early as level 5 with the account's
-- legacy talent Talented. Read by Spec.lua.
local _, ns = ...
ns.data = ns.data or {}
ns.data.specs = {
build = "1.60.1.70938",
DRUID = {
	tree = 1089, tabs = { 11328, 11347, 11340 },   -- Druid: Balance, Feral Combat, Restoration
	nodes = {   -- [node] = { tab, row, ranks }
		[104923] = { 1, 1, 5 },   -- Improved Wrath
		[104924] = { 1, 1, 5 },   -- Genesis
		[104925] = { 1, 2, 3 },   -- Moonglow
		[104931] = { 1, 2, 2 },   -- Improved Moonfire
		[104927] = { 1, 2, 2 },   -- Nature's Majesty
		[104929] = { 1, 2, 2 },   -- Nature's Reach
		[104926] = { 1, 3, 3 },   -- Improved Entangling Roots
		[104928] = { 1, 3, 1 },   -- Nature's Splendor
		[104930] = { 1, 4, 1 },   -- Insect Swarm
		[104932] = { 1, 4, 5 },   -- Vengeance
		[104933] = { 1, 4, 5 },   -- Improved Starfire
		[104934] = { 1, 5, 1 },   -- Nature's Grace
		[104935] = { 1, 5, 3 },   -- Eclipse
		[104936] = { 1, 6, 5 },   -- Moonfury
		[104937] = { 1, 7, 1 },   -- Moonkin Form
		[104938] = { 2, 1, 5 },   -- Ferocity
		[104939] = { 2, 1, 5 },   -- Furor
		[104943] = { 2, 2, 2 },   -- Feral Swiftness
		[104940] = { 2, 2, 3 },   -- Feral Instinct
		[104941] = { 2, 2, 2 },   -- Brutal Impact
		[104942] = { 2, 2, 3 },   -- Thick Hide
		[104945] = { 2, 3, 3 },   -- Shredding Attacks
		[104948] = { 2, 3, 2 },   -- Savage Fury
		[104944] = { 2, 3, 1 },   -- Feral Charge
		[104946] = { 2, 3, 2 },   -- Sharpened Claws
		[104952] = { 2, 4, 3 },   -- Predatory Strikes
		[104949] = { 2, 4, 1 },   -- Lacerate
		[104951] = { 2, 4, 1 },   -- Predatory Discipline
		[104947] = { 2, 4, 2 },   -- Blood Frenzy
		[104955] = { 2, 5, 1 },   -- Leader of the Pack
		[104950] = { 2, 5, 2 },   -- Natural Instinct
		[104953] = { 2, 6, 5 },   -- Rend and Tear
		[104954] = { 2, 6, 5 },   -- Natural Reaction
		[104956] = { 2, 7, 1 },   -- Primal Bite
		[113563] = { 2, 7, 1 },   -- Shifting Power
		[104957] = { 3, 1, 5 },   -- Nature's Focus
		[104958] = { 3, 1, 5 },   -- Heart of the Wild
		[104922] = { 3, 2, 5 },   -- Naturalist
		[104920] = { 3, 2, 3 },   -- Reflection
		[104919] = { 3, 2, 3 },   -- Natural Shapeshifter
		[104916] = { 3, 3, 5 },   -- Gift of Nature
		[104918] = { 3, 3, 1 },   -- Bloom
		[104915] = { 3, 4, 5 },   -- Tranquil Spirit
		[104914] = { 3, 4, 3 },   -- Improved Rejuvenation
		[104912] = { 3, 4, 1 },   -- Swiftmend
		[104921] = { 3, 5, 1 },   -- Nature's Swiftness
		[104911] = { 3, 5, 3 },   -- Living Spirit
		[104909] = { 3, 5, 2 },   -- Improved Tranquility
		[104913] = { 3, 6, 5 },   -- Improved Regrowth
		[104910] = { 3, 7, 1 },   -- Wild Growth
	},
	builds = {
		{ id = "cat", name = "Feral cat", goal = "quest", role = "damage", tab = 2,   -- Balance 7, Feral Combat 34, Restoration 10 in 51 points
			why = "Bear until 20, then a cat: quick kills from stealth, no mana to fight.",
			order = {
				104938, 104938, 104938, 104938, 104938,   -- 1-5: Ferocity x5
				104939, 104939, 104939, 104939, 104939,   -- 6-10: Furor x5
				104943, 104943,   -- 11-12: Feral Swiftness x2
				104946, 104946,   -- 13-14: Sharpened Claws x2
				104948, 104948,   -- 15-16: Savage Fury x2
				104952, 104952, 104952,   -- 17-19: Predatory Strikes x3
				104947,   -- 20: Blood Frenzy
				104955,   -- 21: Leader of the Pack
				104947,   -- 22: Blood Frenzy
				104951,   -- 23: Predatory Discipline
				104950, 104950,   -- 24-25: Natural Instinct x2
				104953, 104953, 104953, 104953, 104953,   -- 26-30: Rend and Tear x5
				113563,   -- 31: Shifting Power
				104956,   -- 32: Primal Bite
				104944,   -- 33: Feral Charge
				104958, 104958, 104958, 104958, 104958,   -- 34-38: Heart of the Wild x5
				104922, 104922, 104922, 104922, 104922,   -- 39-43: Naturalist x5
				104924, 104924, 104924, 104924, 104924,   -- 44-48: Genesis x5
				104927, 104927,   -- 49-50: Nature's Majesty x2
				104940,   -- 51: Feral Instinct
			} },
		{ id = "bear", name = "Feral bear", goal = "dungeon", role = "tank", tab = 2,   -- Balance 0, Feral Combat 41, Restoration 10 in 51 points
			why = "Bear tank: Swipe holds the pack, Feral Charge stops a caster.",
			order = {
				104938, 104938, 104938, 104938, 104938,   -- 1-5: Ferocity x5
				104943,   -- 6: Feral Swiftness
				104940, 104940, 104940,   -- 7-9: Feral Instinct x3
				104943,   -- 10: Feral Swiftness
				104944,   -- 11: Feral Charge
				104948, 104948,   -- 12-13: Savage Fury x2
				104946, 104946,   -- 14-15: Sharpened Claws x2
				104949,   -- 16: Lacerate
				104947, 104947,   -- 17-18: Blood Frenzy x2
				104952, 104952,   -- 19-20: Predatory Strikes x2
				104955,   -- 21: Leader of the Pack
				104952,   -- 22: Predatory Strikes
				104942, 104942, 104942,   -- 23-25: Thick Hide x3
				104954, 104954, 104954, 104954, 104954,   -- 26-30: Natural Reaction x5
				104956,   -- 31: Primal Bite
				104958, 104958, 104958, 104958, 104958,   -- 32-36: Heart of the Wild x5
				104953, 104953, 104953, 104953, 104953,   -- 37-41: Rend and Tear x5
				104941, 104941,   -- 42-43: Brutal Impact x2
				104945, 104945, 104945,   -- 44-46: Shredding Attacks x3
				104922, 104922, 104922, 104922, 104922,   -- 47-51: Naturalist x5
			} },
		{ id = "balance", name = "Balance", goal = "quest", role = "damage", tab = 1,   -- Balance 41, Feral Combat 0, Restoration 10 in 51 points
			why = "Wrath and Moonfire from range, with roots to keep enemies off you.",
			note = "Slower than a cat and you drink often. Root, step back and cast. Feral levels faster.",
			order = {
				104923, 104923, 104923, 104923, 104923,   -- 1-5: Improved Wrath x5
				104925, 104925, 104925,   -- 6-8: Moonglow x3
				104929, 104929,   -- 9-10: Nature's Reach x2
				104926, 104926, 104926,   -- 11-13: Improved Entangling Roots x3
				104931, 104931,   -- 14-15: Improved Moonfire x2
				104930,   -- 16: Insect Swarm
				104927, 104927,   -- 17-18: Nature's Majesty x2
				104928,   -- 19: Nature's Splendor
				104932, 104932, 104932, 104932, 104932,   -- 20-24: Vengeance x5
				104934,   -- 25: Nature's Grace
				104936, 104936, 104936, 104936, 104936,   -- 26-30: Moonfury x5
				104937,   -- 31: Moonkin Form
				104933, 104933, 104933, 104933, 104933,   -- 32-36: Improved Starfire x5
				104957, 104957, 104957, 104957, 104957,   -- 37-41: Nature's Focus x5
				104922, 104922, 104922, 104922, 104922,   -- 42-46: Naturalist x5
				104935, 104935, 104935,   -- 47-49: Eclipse x3
				104924, 104924,   -- 50-51: Genesis x2
			} },
		{ id = "resto", name = "Restoration", goal = "dungeon", role = "healer", tab = 3,   -- Balance 11, Feral Combat 0, Restoration 40 in 51 points
			why = "Rejuvenation and Regrowth on the tank, Swiftmend when it gets bad.",
			note = "Kills slowly alone: quest with a friend, or level as Feral cat and heal dungeons in caster gear.",
			order = {
				104958, 104958, 104958, 104958, 104958,   -- 1-5: Heart of the Wild x5
				104922, 104922, 104922, 104922, 104922,   -- 6-10: Naturalist x5
				104920, 104920, 104920,   -- 11-13: Reflection x3
				104916, 104916,   -- 14-15: Gift of Nature x2
				104912,   -- 16: Swiftmend
				104914, 104914, 104914,   -- 17-19: Improved Rejuvenation x3
				104916,   -- 20: Gift of Nature
				104921,   -- 21: Nature's Swiftness
				104916, 104916,   -- 22-23: Gift of Nature x2
				104911, 104911, 104911,   -- 24-26: Living Spirit x3
				104918,   -- 27: Bloom
				104913, 104913, 104913,   -- 28-30: Improved Regrowth x3
				104910,   -- 31: Wild Growth
				104913, 104913,   -- 32-33: Improved Regrowth x2
				104924, 104924, 104924, 104924, 104924,   -- 34-38: Genesis x5
				104927, 104927,   -- 39-40: Nature's Majesty x2
				104925, 104925, 104925,   -- 41-43: Moonglow x3
				104928,   -- 44: Nature's Splendor
				104915, 104915, 104915, 104915, 104915,   -- 45-49: Tranquil Spirit x5
				104909, 104909,   -- 50-51: Improved Tranquility x2
			} },
		{ id = "feralpvp", name = "Feral PvP", goal = "pvp", role = "damage", tab = 2,   -- Balance 0, Feral Combat 38, Restoration 13 in 51 points
			why = "Open from stealth, stun with a longer Bash, turn bear when focused.",
			order = {
				104938, 104938, 104938, 104938, 104938,   -- 1-5: Ferocity x5
				104941, 104941,   -- 6-7: Brutal Impact x2
				104943, 104943,   -- 8-9: Feral Swiftness x2
				104940,   -- 10: Feral Instinct
				104944,   -- 11: Feral Charge
				104946, 104946,   -- 12-13: Sharpened Claws x2
				104948, 104948,   -- 14-15: Savage Fury x2
				104952, 104952, 104952,   -- 16-18: Predatory Strikes x3
				104947, 104947,   -- 19-20: Blood Frenzy x2
				104955,   -- 21: Leader of the Pack
				104939, 104939, 104939, 104939, 104939,   -- 22-26: Furor x5
				104953, 104953, 104953, 104953, 104953,   -- 27-31: Rend and Tear x5
				104951,   -- 32: Predatory Discipline
				113563,   -- 33: Shifting Power
				104945, 104945, 104945,   -- 34-36: Shredding Attacks x3
				104950, 104950,   -- 37-38: Natural Instinct x2
				104958, 104958, 104958, 104958, 104958,   -- 39-43: Heart of the Wild x5
				104922, 104922, 104922, 104922, 104922,   -- 44-48: Naturalist x5
				104919, 104919, 104919,   -- 49-51: Natural Shapeshifter x3
			} },
	},
},
HUNTER = {
	tree = 1091, tabs = { 11372, 11371, 11370 },   -- Hunter: Beast Mastery, Marksmanship, Survival
	nodes = {   -- [node] = { tab, row, ranks }
		[104960] = { 1, 1, 5 },   -- Deadly Aspects
		[104976] = { 1, 1, 5 },   -- Endurance Training
		[104975] = { 1, 2, 2 },   -- Focused Fire
		[104974] = { 1, 2, 3 },   -- Improved Aspect of the Monkey
		[104973] = { 1, 3, 2 },   -- Pathfinding
		[104970] = { 1, 3, 1 },   -- Bestial Swiftness
		[104969] = { 1, 3, 5 },   -- Unleashed Fury
		[104968] = { 1, 4, 2 },   -- Improved Mend Pet
		[104967] = { 1, 4, 5 },   -- Ferocity
		[104966] = { 1, 4, 1 },   -- Summon Hawk
		[104965] = { 1, 5, 2 },   -- Spirit Bond
		[104964] = { 1, 5, 1 },   -- Intimidation
		[104963] = { 1, 5, 2 },   -- Bestial Discipline
		[104962] = { 1, 6, 5 },   -- Frenzy
		[104961] = { 1, 7, 1 },   -- Bestial Wrath
		[105013] = { 2, 1, 3 },   -- Hawk Eye
		[105012] = { 2, 1, 5 },   -- Improved Concussive Shot
		[105011] = { 2, 1, 5 },   -- Lethal Attacks
		[110870] = { 2, 2, 3 },   -- Improved Stings
		[105009] = { 2, 2, 5 },   -- Efficiency
		[105008] = { 2, 2, 5 },   -- Careful Aim
		[105005] = { 2, 3, 2 },   -- Rapid Killing
		[105007] = { 2, 3, 1 },   -- Lone Wolf
		[105004] = { 2, 4, 1 },   -- Trueshot Aura
		[105002] = { 2, 4, 5 },   -- Mortal Shots
		[104999] = { 2, 5, 2 },   -- Rapid Recuperation
		[105001] = { 2, 5, 3 },   -- Barrage
		[105000] = { 2, 5, 1 },   -- Scatter Shot
		[104998] = { 2, 6, 5 },   -- Ranged Weapon Specialization
		[104997] = { 2, 7, 1 },   -- Sniper Shot
		[104996] = { 3, 1, 5 },   -- Improved Tracking
		[104993] = { 3, 2, 2 },   -- Savage Strikes
		[104992] = { 3, 2, 5 },   -- Survivalist
		[104991] = { 3, 3, 2 },   -- Clever Traps
		[104987] = { 3, 3, 3 },   -- Surefooted
		[104986] = { 3, 3, 1 },   -- Deterrence
		[110861] = { 3, 4, 5 },   -- Predator's Edge
		[104983] = { 3, 5, 2 },   -- Resourcefulness
		[104985] = { 3, 5, 2 },   -- Expose Prey
		[110860] = { 3, 5, 2 },   -- Survivalist's Discipline
		[104981] = { 3, 5, 1 },   -- Strider Kick
		[110859] = { 3, 6, 5 },   -- Lightning Reflexes
		[104984] = { 3, 7, 1 },   -- Lacerating Strikes
	},
	builds = {
		{ id = "bm", name = "Beast Mastery", goal = "quest", role = "damage", tab = 1,   -- Beast Mastery 33, Marksmanship 18, Survival 0 in 51 points
			why = "Your pet holds the enemy while you shoot, and later hawks join in.",
			order = {
				104960, 104960, 104960, 104960, 104960,   -- 1-5: Deadly Aspects x5
				104975, 104975,   -- 6-7: Focused Fire x2
				104976, 104976, 104976,   -- 8-10: Endurance Training x3
				104969, 104969, 104969, 104969, 104969,   -- 11-15: Unleashed Fury x5
				104966,   -- 16: Summon Hawk
				104973, 104973,   -- 17-18: Pathfinding x2
				104970,   -- 19: Bestial Swiftness
				104967,   -- 20: Ferocity
				104964,   -- 21: Intimidation
				104967, 104967, 104967, 104967,   -- 22-25: Ferocity x4
				104962, 104962, 104962, 104962, 104962,   -- 26-30: Frenzy x5
				104961,   -- 31: Bestial Wrath
				104963, 104963,   -- 32-33: Bestial Discipline x2
				105011, 105011, 105011, 105011, 105011,   -- 34-38: Lethal Attacks x5
				105008, 105008, 105008, 105008, 105008,   -- 39-43: Careful Aim x5
				105009, 105009, 105009,   -- 44-46: Efficiency x3
				105005, 105005,   -- 47-48: Rapid Killing x2
				105004,   -- 49: Trueshot Aura
				105002, 105002,   -- 50-51: Mortal Shots x2
			} },
		{ id = "mm", name = "Marksmanship", goal = "quest", role = "damage", tab = 2,   -- Beast Mastery 0, Marksmanship 38, Survival 13 in 51 points
			why = "Big Aimed Shots and crits from range while your pet keeps them busy.",
			order = {
				105011, 105011, 105011, 105011, 105011,   -- 1-5: Lethal Attacks x5
				105008, 105008, 105008, 105008, 105008,   -- 6-10: Careful Aim x5
				105005, 105005,   -- 11-12: Rapid Killing x2
				105009, 105009, 105009,   -- 13-15: Efficiency x3
				105004,   -- 16: Trueshot Aura
				105002, 105002, 105002, 105002,   -- 17-20: Mortal Shots x4
				105001, 105001, 105001,   -- 21-23: Barrage x3
				105002,   -- 24: Mortal Shots
				104999, 104999,   -- 25-26: Rapid Recuperation x2
				104998, 104998, 104998, 104998,   -- 27-30: Ranged Weapon Specialization x4
				104997,   -- 31: Sniper Shot
				104998,   -- 32: Ranged Weapon Specialization
				104996, 104996, 104996, 104996, 104996,   -- 33-37: Improved Tracking x5
				104992, 104992, 104992, 104992, 104992,   -- 38-42: Survivalist x5
				104987, 104987, 104987,   -- 43-45: Surefooted x3
				110870, 110870, 110870,   -- 46-48: Improved Stings x3
				105009, 105009,   -- 49-50: Efficiency x2
				105000,   -- 51: Scatter Shot
			} },
		{ id = "survival", name = "Survival melee", goal = "quest", role = "damage", tab = 3,   -- Beast Mastery 7, Marksmanship 10, Survival 34 in 51 points
			why = "Fight beside your pet with axe or blades, a fire trap at your feet.",
			note = "Slow until Predator's Edge: shoot first and step in to finish, or level as Beast Mastery.",
			order = {
				104996, 104996, 104996, 104996, 104996,   -- 1-5: Improved Tracking x5
				104993, 104993,   -- 6-7: Savage Strikes x2
				104992, 104992, 104992,   -- 8-10: Survivalist x3
				104987, 104987, 104987,   -- 11-13: Surefooted x3
				104986,   -- 14: Deterrence
				104991,   -- 15: Clever Traps
				110861, 110861, 110861, 110861, 110861,   -- 16-20: Predator's Edge x5
				104981,   -- 21: Strider Kick
				104983, 104983,   -- 22-23: Resourcefulness x2
				104985, 104985,   -- 24-25: Expose Prey x2
				110859, 110859, 110859, 110859, 110859,   -- 26-30: Lightning Reflexes x5
				104984,   -- 31: Lacerating Strikes
				110860, 110860,   -- 32-33: Survivalist's Discipline x2
				104960, 104960, 104960, 104960, 104960,   -- 34-38: Deadly Aspects x5
				104975, 104975,   -- 39-40: Focused Fire x2
				105011, 105011, 105011, 105011, 105011,   -- 41-45: Lethal Attacks x5
				105008, 105008, 105008, 105008, 105008,   -- 46-50: Careful Aim x5
				104992,   -- 51: Survivalist
			} },
		{ id = "lonewolf", name = "Lone Wolf", goal = "dungeon", role = "damage", tab = 2,   -- Beast Mastery 0, Marksmanship 38, Survival 13 in 51 points
			why = "No pet to pull extra packs, and every shot hits a fifth harder.",
			note = "Alone, nothing holds enemies off you: call the pet to quest and put it away for dungeons.",
			order = {
				105011, 105011, 105011, 105011, 105011,   -- 1-5: Lethal Attacks x5
				105008, 105008, 105008, 105008, 105008,   -- 6-10: Careful Aim x5
				105007,   -- 11: Lone Wolf
				105005, 105005,   -- 12-13: Rapid Killing x2
				105009, 105009,   -- 14-15: Efficiency x2
				105004,   -- 16: Trueshot Aura
				105002, 105002, 105002, 105002,   -- 17-20: Mortal Shots x4
				105001, 105001, 105001,   -- 21-23: Barrage x3
				105002,   -- 24: Mortal Shots
				104999, 104999,   -- 25-26: Rapid Recuperation x2
				104998, 104998, 104998, 104998,   -- 27-30: Ranged Weapon Specialization x4
				104997,   -- 31: Sniper Shot
				104998,   -- 32: Ranged Weapon Specialization
				105009, 105009, 105009,   -- 33-35: Efficiency x3
				104996, 104996, 104996, 104996, 104996,   -- 36-40: Improved Tracking x5
				104992, 104992, 104992, 104992, 104992,   -- 41-45: Survivalist x5
				104987, 104987, 104987,   -- 46-48: Surefooted x3
				110870, 110870, 110870,   -- 49-51: Improved Stings x3
			} },
		{ id = "bmpvp", name = "Beast Mastery PvP", goal = "pvp", role = "damage", tab = 1,   -- Beast Mastery 32, Marksmanship 19, Survival 0 in 51 points
			why = "A tough, fast pet that stays on players and learns to stun them.",
			order = {
				104976, 104976, 104976, 104976, 104976,   -- 1-5: Endurance Training x5
				104975, 104975,   -- 6-7: Focused Fire x2
				104974, 104974, 104974,   -- 8-10: Improved Aspect of the Monkey x3
				104970,   -- 11: Bestial Swiftness
				104969, 104969, 104969, 104969, 104969,   -- 12-16: Unleashed Fury x5
				104968, 104968,   -- 17-18: Improved Mend Pet x2
				104967, 104967,   -- 19-20: Ferocity x2
				104964,   -- 21: Intimidation
				104967, 104967, 104967,   -- 22-24: Ferocity x3
				104965, 104965,   -- 25-26: Spirit Bond x2
				104962, 104962, 104962, 104962, 104962,   -- 27-31: Frenzy x5
				104961,   -- 32: Bestial Wrath
				105013, 105013, 105013,   -- 33-35: Hawk Eye x3
				105012, 105012,   -- 36-37: Improved Concussive Shot x2
				105008, 105008, 105008, 105008, 105008,   -- 38-42: Careful Aim x5
				105012, 105012, 105012,   -- 43-45: Improved Concussive Shot x3
				110870, 110870,   -- 46-47: Improved Stings x2
				105002, 105002, 105002, 105002,   -- 48-51: Mortal Shots x4
			} },
	},
},
MAGE = {
	tree = 1112, tabs = { 11582, 11594, 11601 },   -- Mage: Arcane, Fire, Frost
	nodes = {   -- [node] = { tab, row, ranks }
		[105815] = { 1, 1, 2 },   -- Wand Specialization
		[105813] = { 1, 1, 5 },   -- Improved Channeling
		[105802] = { 1, 1, 3 },   -- Arcane Resilience
		[105812] = { 1, 2, 2 },   -- Arcane Subtlety
		[105811] = { 1, 2, 2 },   -- Magic Absorption
		[105810] = { 1, 2, 5 },   -- Arcane Concentration
		[105809] = { 1, 2, 2 },   -- Missile Barrage
		[105808] = { 1, 3, 2 },   -- Arcane Geometry
		[105807] = { 1, 3, 3 },   -- Arcane Impact
		[105806] = { 1, 3, 1 },   -- Arcane Blast
		[105804] = { 1, 4, 2 },   -- Improved Counterspell
		[105803] = { 1, 4, 3 },   -- Arcane Meditation
		[113627] = { 1, 4, 1 },   -- Arcane Wrath
		[105801] = { 1, 5, 1 },   -- Presence of Mind
		[105800] = { 1, 5, 5 },   -- Arcane Mind
		[105799] = { 1, 6, 3 },   -- Arcane Instability
		[105798] = { 1, 7, 1 },   -- Arcane Power
		[105796] = { 2, 1, 5 },   -- Incineration
		[105795] = { 2, 1, 5 },   -- Accelerant
		[105794] = { 2, 2, 5 },   -- Ignite
		[105793] = { 2, 2, 2 },   -- Flame Throwing
		[105792] = { 2, 2, 3 },   -- Impact
		[105789] = { 2, 3, 3 },   -- Burning Soul
		[105791] = { 2, 3, 3 },   -- Improved Flamestrike
		[105790] = { 2, 3, 1 },   -- Pyroblast
		[105797] = { 2, 3, 2 },   -- Improved Fire Blast
		[105786] = { 2, 4, 1 },   -- Heating Up
		[105785] = { 2, 4, 3 },   -- Master of Elements
		[105784] = { 2, 5, 3 },   -- Critical Mass
		[105783] = { 2, 5, 1 },   -- Blast Wave
		[105782] = { 2, 6, 3 },   -- Fire Power
		[105781] = { 2, 7, 1 },   -- Combustion
		[105780] = { 3, 1, 2 },   -- Frost Warding
		[105779] = { 3, 1, 5 },   -- Improved Frostbolt
		[105778] = { 3, 1, 3 },   -- Precision
		[105777] = { 3, 2, 5 },   -- Ice Shards
		[105774] = { 3, 2, 3 },   -- Frostbite
		[105775] = { 3, 2, 2 },   -- Improved Frost Nova
		[105776] = { 3, 2, 3 },   -- Permafrost
		[105772] = { 3, 3, 3 },   -- Frost Channeling
		[105771] = { 3, 3, 3 },   -- Improved Blizzard
		[105767] = { 3, 3, 1 },   -- Ice Lance
		[105770] = { 3, 4, 2 },   -- Arctic Reach
		[105769] = { 3, 4, 1 },   -- Ice Block
		[105768] = { 3, 4, 3 },   -- Shatter
		[105765] = { 3, 5, 3 },   -- Improved Cone of Cold
		[105766] = { 3, 5, 1 },   -- Cold Snap
		[105764] = { 3, 5, 2 },   -- Fingers of Frost
		[105763] = { 3, 6, 5 },   -- Winter's Chill
		[105762] = { 3, 7, 1 },   -- Ice Barrier
	},
	builds = {
		{ id = "frost", name = "Frost", goal = "quest", role = "damage", tab = 3,   -- Arcane 10, Fire 0, Frost 41 in 51 points
			why = "Frostbolt slows them, Frost Nova pins them, Ice Lance finishes them.",
			order = {
				105779, 105779, 105779, 105779, 105779,   -- 1-5: Improved Frostbolt x5
				105774, 105774, 105774,   -- 6-8: Frostbite x3
				105778, 105778,   -- 9-10: Precision x2
				105767,   -- 11: Ice Lance
				105772, 105772, 105772,   -- 12-14: Frost Channeling x3
				105777,   -- 15: Ice Shards
				105768, 105768, 105768,   -- 16-18: Shatter x3
				105777, 105777,   -- 19-20: Ice Shards x2
				105764, 105764,   -- 21-22: Fingers of Frost x2
				105777, 105777,   -- 23-24: Ice Shards x2
				105769,   -- 25: Ice Block
				105766,   -- 26: Cold Snap
				105778,   -- 27: Precision
				105765, 105765, 105765,   -- 28-30: Improved Cone of Cold x3
				105762,   -- 31: Ice Barrier
				105763, 105763, 105763, 105763, 105763,   -- 32-36: Winter's Chill x5
				105775, 105775,   -- 37-38: Improved Frost Nova x2
				105780, 105780,   -- 39-40: Frost Warding x2
				105771,   -- 41: Improved Blizzard
				105802, 105802, 105802,   -- 42-44: Arcane Resilience x3
				105815, 105815,   -- 45-46: Wand Specialization x2
				105810, 105810, 105810, 105810, 105810,   -- 47-51: Arcane Concentration x5
			} },
		{ id = "arcane", name = "Arcane", goal = "quest", role = "damage", tab = 1,   -- Arcane 38, Fire 10, Frost 3 in 51 points
			why = "Arcane Blast builds power, Arcane Wrath and free Missiles spend it.",
			note = "Drinks often and slows nothing, and only comes together 16 points in, with Arcane Wrath. Frost is safer.",
			order = {
				105813, 105813, 105813, 105813, 105813,   -- 1-5: Improved Channeling x5
				105809, 105809,   -- 6-7: Missile Barrage x2
				105810, 105810, 105810,   -- 8-10: Arcane Concentration x3
				105806,   -- 11: Arcane Blast
				105810, 105810,   -- 12-13: Arcane Concentration x2
				105807, 105807,   -- 14-15: Arcane Impact x2
				113627,   -- 16: Arcane Wrath
				105803, 105803, 105803,   -- 17-19: Arcane Meditation x3
				105807,   -- 20: Arcane Impact
				105801,   -- 21: Presence of Mind
				105800, 105800, 105800, 105800, 105800,   -- 22-26: Arcane Mind x5
				105799, 105799, 105799,   -- 27-29: Arcane Instability x3
				105812,   -- 30: Arcane Subtlety
				105798,   -- 31: Arcane Power
				105778, 105778, 105778,   -- 32-34: Precision x3
				105796, 105796, 105796, 105796, 105796,   -- 35-39: Incineration x5
				105795, 105795, 105795, 105795, 105795,   -- 40-44: Accelerant x5
				105802, 105802, 105802,   -- 45-47: Arcane Resilience x3
				105804, 105804,   -- 48-49: Improved Counterspell x2
				105808, 105808,   -- 50-51: Arcane Geometry x2
			} },
		{ id = "fire", name = "Fire", goal = "quest", role = "damage", tab = 2,   -- Arcane 10, Fire 38, Frost 3 in 51 points
			why = "Fire Blast feeds Heating Up for a quick Pyroblast: big hits, no slows.",
			note = "Nothing slows the enemy and crits are rare this early: open from far off and save Frost Nova.",
			order = {
				105795, 105795, 105795, 105795, 105795,   -- 1-5: Accelerant x5
				105794, 105794, 105794, 105794, 105794,   -- 6-10: Ignite x5
				105790,   -- 11: Pyroblast
				105797, 105797,   -- 12-13: Improved Fire Blast x2
				105789, 105789,   -- 14-15: Burning Soul x2
				105786,   -- 16: Heating Up
				105785, 105785, 105785,   -- 17-19: Master of Elements x3
				105789,   -- 20: Burning Soul
				105783,   -- 21: Blast Wave
				105784, 105784, 105784,   -- 22-24: Critical Mass x3
				105792,   -- 25: Impact
				105782, 105782, 105782,   -- 26-28: Fire Power x3
				105792, 105792,   -- 29-30: Impact x2
				105781,   -- 31: Combustion
				105796, 105796, 105796, 105796, 105796,   -- 32-36: Incineration x5
				105793, 105793,   -- 37-38: Flame Throwing x2
				105778, 105778, 105778,   -- 39-41: Precision x3
				105802, 105802, 105802,   -- 42-44: Arcane Resilience x3
				105815, 105815,   -- 45-46: Wand Specialization x2
				105810, 105810, 105810, 105810, 105810,   -- 47-51: Arcane Concentration x5
			} },
		{ id = "frostaoe", name = "Frost AoE", goal = "quest", role = "damage", tab = 3,   -- Arcane 0, Fire 13, Frost 38 in 51 points
			why = "Gather a pack, freeze it in place and bring Blizzard down on it.",
			note = "Waits for a slowing Blizzard 16 points in, and pack slows are weaker here: keep pulls small, or stay Frost.",
			order = {
				105779, 105779, 105779, 105779, 105779,   -- 1-5: Improved Frostbolt x5
				105775, 105775,   -- 6-7: Improved Frost Nova x2
				105778, 105778, 105778,   -- 8-10: Precision x3
				105772, 105772, 105772,   -- 11-13: Frost Channeling x3
				105776, 105776,   -- 14-15: Permafrost x2
				105771, 105771, 105771,   -- 16-18: Improved Blizzard x3
				105768, 105768, 105768,   -- 19-21: Shatter x3
				105769,   -- 22: Ice Block
				105770, 105770,   -- 23-24: Arctic Reach x2
				105776,   -- 25: Permafrost
				105765, 105765, 105765,   -- 26-28: Improved Cone of Cold x3
				105766,   -- 29: Cold Snap
				105767,   -- 30: Ice Lance
				105762,   -- 31: Ice Barrier
				105777, 105777, 105777, 105777, 105777,   -- 32-36: Ice Shards x5
				105780, 105780,   -- 37-38: Frost Warding x2
				105796, 105796, 105796, 105796, 105796,   -- 39-43: Incineration x5
				105793, 105793,   -- 44-45: Flame Throwing x2
				105792, 105792, 105792,   -- 46-48: Impact x3
				105791, 105791, 105791,   -- 49-51: Improved Flamestrike x3
			} },
		{ id = "frostpvp", name = "Frost PvP", goal = "pvp", role = "damage", tab = 3,   -- Arcane 20, Fire 0, Frost 31 in 51 points
			why = "Heavy slows, a quicker Frost Nova, Ice Block, and Ice Lance to finish.",
			order = {
				105779, 105779, 105779, 105779, 105779,   -- 1-5: Improved Frostbolt x5
				105774, 105774, 105774,   -- 6-8: Frostbite x3
				105776, 105776,   -- 9-10: Permafrost x2
				105767,   -- 11: Ice Lance
				105775, 105775,   -- 12-13: Improved Frost Nova x2
				105776,   -- 14: Permafrost
				105778,   -- 15: Precision
				105769,   -- 16: Ice Block
				105768, 105768, 105768,   -- 17-19: Shatter x3
				105778,   -- 20: Precision
				105764,   -- 21: Fingers of Frost
				105766,   -- 22: Cold Snap
				105764,   -- 23: Fingers of Frost
				105770, 105770,   -- 24-25: Arctic Reach x2
				105778,   -- 26: Precision
				105777, 105777, 105777, 105777,   -- 27-30: Ice Shards x4
				105762,   -- 31: Ice Barrier
				105802, 105802, 105802,   -- 32-34: Arcane Resilience x3
				105813, 105813,   -- 35-36: Improved Channeling x2
				105810, 105810, 105810, 105810, 105810,   -- 37-41: Arcane Concentration x5
				105809, 105809,   -- 42-43: Missile Barrage x2
				105811, 105811,   -- 44-45: Magic Absorption x2
				105812,   -- 46: Arcane Subtlety
				105804, 105804,   -- 47-48: Improved Counterspell x2
				105803, 105803, 105803,   -- 49-51: Arcane Meditation x3
			} },
	},
},
PALADIN = {
	tree = 1100, tabs = { 11486, 11541, 11559 },   -- Paladin: Holy, Protection, Retribution
	nodes = {   -- [node] = { tab, row, ranks }
		[105335] = { 1, 1, 5 },   -- Spiritual Focus
		[113630] = { 1, 1, 5 },   -- Divine Strength
		[105333] = { 1, 2, 3 },   -- Healing Light
		[110871] = { 1, 2, 2 },   -- Reverence
		[105334] = { 1, 2, 5 },   -- Improved Seals
		[105327] = { 1, 2, 2 },   -- Purifying Power
		[105325] = { 1, 3, 1 },   -- Divine Favor
		[105329] = { 1, 3, 5 },   -- Illumination
		[105704] = { 1, 3, 2 },   -- Holy Conduit
		[105324] = { 1, 4, 2 },   -- Divine Precision
		[110873] = { 1, 4, 2 },   -- Infusion of Light
		[105330] = { 1, 4, 1 },   -- Oath of Light
		[105323] = { 1, 5, 1 },   -- Holy Shock
		[113631] = { 1, 5, 2 },   -- Boundless Light
		[105321] = { 1, 6, 5 },   -- Holy Power
		[105320] = { 1, 7, 1 },   -- Light's Vigil
		[105332] = { 2, 1, 5 },   -- Divine Intellect
		[105626] = { 2, 1, 5 },   -- Redoubt
		[105638] = { 2, 2, 3 },   -- Precision
		[105637] = { 2, 2, 2 },   -- Guardian's Favor
		[105625] = { 2, 3, 1 },   -- Templar's Bulwark
		[110874] = { 2, 3, 2 },   -- Shield Specialization
		[105630] = { 2, 3, 5 },   -- Toughness
		[110878] = { 2, 4, 1 },   -- Swift Judgement
		[105634] = { 2, 4, 3 },   -- Improved Righteous Fury
		[105636] = { 2, 4, 5 },   -- Anticipation
		[105628] = { 2, 5, 1 },   -- Holy Shield
		[105627] = { 2, 5, 5 },   -- Reckoning
		[110879] = { 2, 6, 3 },   -- Iron Creed
		[110875] = { 2, 7, 1 },   -- Shieldsworn
		[105707] = { 3, 1, 5 },   -- Deflection
		[105706] = { 3, 1, 5 },   -- Benediction
		[105705] = { 3, 2, 2 },   -- Improved Judgement
		[105703] = { 3, 2, 3 },   -- Conviction
		[105701] = { 3, 2, 3 },   -- Sanctified Judgement
		[105702] = { 3, 3, 3 },   -- Vindication
		[105331] = { 3, 3, 2 },   -- Unyielding Faith
		[105696] = { 3, 3, 1 },   -- Seal of Command
		[105699] = { 3, 3, 2 },   -- Pursuit of Justice
		[105698] = { 3, 4, 2 },   -- Eye for an Eye
		[105700] = { 3, 4, 1 },   -- Sacred Arbiter
		[105697] = { 3, 4, 3 },   -- Two-Handed Weapon Specialization
		[105694] = { 3, 5, 1 },   -- Repentance
		[105693] = { 3, 5, 3 },   -- Vengeance
		[110882] = { 3, 6, 5 },   -- Champion of the Light
		[105692] = { 3, 7, 1 },   -- Unsealed Wrath
	},
	builds = {
		{ id = "ret", name = "Retribution", goal = "quest", role = "damage", tab = 3,   -- Holy 12, Protection 8, Retribution 31 in 51 points
			why = "Seal of Command, Holy Strike and faster running: quick, steady kills.",
			order = {
				105706, 105706, 105706, 105706, 105706,   -- 1-5: Benediction x5
				105705, 105705,   -- 6-7: Improved Judgement x2
				105703, 105703, 105703,   -- 8-10: Conviction x3
				105696,   -- 11: Seal of Command
				105699, 105699,   -- 12-13: Pursuit of Justice x2
				105701, 105701, 105701,   -- 14-16: Sanctified Judgement x3
				105700,   -- 17: Sacred Arbiter
				105697, 105697, 105697,   -- 18-20: Two-Handed Weapon Specialization x3
				105694,   -- 21: Repentance
				105693, 105693, 105693,   -- 22-24: Vengeance x3
				105702,   -- 25: Vindication
				110882, 110882, 110882, 110882, 110882,   -- 26-30: Champion of the Light x5
				105692,   -- 31: Unsealed Wrath
				113630, 113630, 113630, 113630, 113630,   -- 32-36: Divine Strength x5
				105334, 105334, 105334, 105334, 105334,   -- 37-41: Improved Seals x5
				105332, 105332, 105332, 105332, 105332,   -- 42-46: Divine Intellect x5
				105638, 105638, 105638,   -- 47-49: Precision x3
				105704, 105704,   -- 50-51: Holy Conduit x2
			} },
		{ id = "holy", name = "Holy", goal = "dungeon", role = "healer", tab = 1,   -- Holy 33, Protection 7, Retribution 11 in 51 points
			why = "Heals that hold when you're hit, an Oath on your tank, then Holy Shock.",
			note = "Kills slowly alone. Retribution heals the early dungeons too: level as that if questing drags.",
			order = {
				105335, 105335, 105335, 105335, 105335,   -- 1-5: Spiritual Focus x5
				105333, 105333, 105333,   -- 6-8: Healing Light x3
				110871, 110871,   -- 9-10: Reverence x2
				105325,   -- 11: Divine Favor
				105329, 105329, 105329, 105329,   -- 12-15: Illumination x4
				105330,   -- 16: Oath of Light
				105329,   -- 17: Illumination
				110873, 110873,   -- 18-19: Infusion of Light x2
				105334,   -- 20: Improved Seals
				105323,   -- 21: Holy Shock
				113631, 113631,   -- 22-23: Boundless Light x2
				105334, 105334,   -- 24-25: Improved Seals x2
				105321, 105321, 105321, 105321, 105321,   -- 26-30: Holy Power x5
				105320,   -- 31: Light's Vigil
				105332, 105332, 105332, 105332, 105332,   -- 32-36: Divine Intellect x5
				105706, 105706, 105706, 105706, 105706,   -- 37-41: Benediction x5
				105703, 105703, 105703,   -- 42-44: Conviction x3
				105327, 105327,   -- 45-46: Purifying Power x2
				105637, 105637,   -- 47-48: Guardian's Favor x2
				105701, 105701, 105701,   -- 49-51: Sanctified Judgement x3
			} },
		{ id = "prot", name = "Protection", goal = "dungeon", role = "tank", tab = 2,   -- Holy 0, Protection 39, Retribution 12 in 51 points
			why = "Shield up, enemies kept on you, and mana back as you block.",
			note = "Slow alone until Consecration at 20, then you can pull packs. Before that, quest with a friend.",
			order = {
				105626, 105626, 105626, 105626, 105626,   -- 1-5: Redoubt x5
				105638, 105638, 105638,   -- 6-8: Precision x3
				105332, 105332,   -- 9-10: Divine Intellect x2
				105625,   -- 11: Templar's Bulwark
				110874, 110874,   -- 12-13: Shield Specialization x2
				105332, 105332,   -- 14-15: Divine Intellect x2
				110878,   -- 16: Swift Judgement
				105634, 105634, 105634,   -- 17-19: Improved Righteous Fury x3
				105332,   -- 20: Divine Intellect
				105628,   -- 21: Holy Shield
				105627, 105627, 105627, 105627,   -- 22-25: Reckoning x4
				110879, 110879, 110879,   -- 26-28: Iron Creed x3
				105627,   -- 29: Reckoning
				105636,   -- 30: Anticipation
				110875,   -- 31: Shieldsworn
				105636, 105636, 105636, 105636,   -- 32-35: Anticipation x4
				105707, 105707, 105707, 105707, 105707,   -- 36-40: Deflection x5
				105630, 105630, 105630, 105630,   -- 41-44: Toughness x4
				105706, 105706, 105706, 105706, 105706,   -- 45-49: Benediction x5
				105705, 105705,   -- 50-51: Improved Judgement x2
			} },
		{ id = "retpvp", name = "Retribution PvP", goal = "pvp", role = "damage", tab = 3,   -- Holy 20, Protection 0, Retribution 31 in 51 points
			why = "Seal of Command bursts, Repentance locks one out, and fears end sooner.",
			order = {
				105706, 105706, 105706, 105706, 105706,   -- 1-5: Benediction x5
				105705, 105705,   -- 6-7: Improved Judgement x2
				105703, 105703, 105703,   -- 8-10: Conviction x3
				105696,   -- 11: Seal of Command
				105699, 105699,   -- 12-13: Pursuit of Justice x2
				105331, 105331,   -- 14-15: Unyielding Faith x2
				105700,   -- 16: Sacred Arbiter
				105697, 105697, 105697,   -- 17-19: Two-Handed Weapon Specialization x3
				105698,   -- 20: Eye for an Eye
				105694,   -- 21: Repentance
				105698,   -- 22: Eye for an Eye
				105693, 105693, 105693,   -- 23-25: Vengeance x3
				110882, 110882, 110882, 110882, 110882,   -- 26-30: Champion of the Light x5
				105692,   -- 31: Unsealed Wrath
				113630, 113630, 113630, 113630, 113630,   -- 32-36: Divine Strength x5
				105334, 105334, 105334, 105334, 105334,   -- 37-41: Improved Seals x5
				105327, 105327,   -- 42-43: Purifying Power x2
				105704, 105704,   -- 44-45: Holy Conduit x2
				105325,   -- 46: Divine Favor
				105324, 105324,   -- 47-48: Divine Precision x2
				105333, 105333, 105333,   -- 49-51: Healing Light x3
			} },
	},
},
PRIEST = {
	tree = 1114, tabs = { 11608, 11615, 11622 },   -- Priest: Discipline, Holy, Shadow Magic
	nodes = {   -- [node] = { tab, row, ranks }
		[110853] = { 1, 1, 5 },   -- Power in Light
		[105850] = { 1, 1, 2 },   -- Wand Specialization
		[105849] = { 1, 1, 5 },   -- Twin Disciplines
		[105848] = { 1, 2, 3 },   -- Silent Resolve
		[110852] = { 1, 2, 3 },   -- Holy Precision
		[105837] = { 1, 2, 5 },   -- Mental Strength
		[105845] = { 1, 2, 2 },   -- Martyrdom
		[105842] = { 1, 3, 3 },   -- Mental Agility
		[105844] = { 1, 3, 1 },   -- Inner Focus
		[105846] = { 1, 3, 3 },   -- Improved Power Word: Shield
		[105843] = { 1, 3, 3 },   -- Meditation
		[105839] = { 1, 4, 1 },   -- Soul Warding
		[105834] = { 1, 5, 1 },   -- Penance
		[105835] = { 1, 5, 5 },   -- Renewed Hope
		[105840] = { 1, 6, 3 },   -- Divine Aegis
		[105836] = { 1, 7, 1 },   -- Power Infusion
		[105867] = { 2, 1, 3 },   -- Twilight Focus
		[105866] = { 2, 1, 3 },   -- Improved Renew
		[110855] = { 2, 1, 5 },   -- Holy Specialization
		[105863] = { 2, 2, 5 },   -- Divine Fury
		[105862] = { 2, 3, 1 },   -- Holy Nova
		[105860] = { 2, 3, 3 },   -- Inspiration
		[105858] = { 2, 4, 3 },   -- Improved Healing
		[105856] = { 2, 4, 1 },   -- Holy Binding
		[105855] = { 2, 5, 2 },   -- Litany of Light
		[105854] = { 2, 5, 1 },   -- Spirit of Redemption
		[105853] = { 2, 5, 5 },   -- Spiritual Guidance
		[105852] = { 2, 6, 3 },   -- Spiritual Healing
		[105851] = { 2, 7, 1 },   -- Prayer of Mending
		[110851] = { 3, 1, 5 },   -- Shadow Focus
		[105832] = { 3, 1, 5 },   -- Blackout
		[105833] = { 3, 1, 5 },   -- Spirit Tap
		[105831] = { 3, 2, 5 },   -- Improved Mind Blast
		[105830] = { 3, 2, 2 },   -- Improved Shadow Word: Pain
		[105829] = { 3, 2, 2 },   -- Shadow Reach
		[105828] = { 3, 3, 2 },   -- Improved Psychic Scream
		[105826] = { 3, 3, 1 },   -- Mind Flay
		[105825] = { 3, 3, 2 },   -- Improved Mind Flay
		[105820] = { 3, 4, 1 },   -- Vampiric Embrace
		[105821] = { 3, 4, 3 },   -- Shadow Weaving
		[105824] = { 3, 5, 1 },   -- Silence
		[105819] = { 3, 5, 2 },   -- Devouring Contagion
		[110854] = { 3, 6, 2 },   -- Early Demise
		[105818] = { 3, 6, 5 },   -- Darkness
		[105817] = { 3, 7, 1 },   -- Shadowform
	},
	builds = {
		{ id = "shadow", name = "Shadow", goal = "quest", role = "damage", tab = 3,   -- Discipline 17, Holy 0, Shadow Magic 34 in 51 points
			why = "Pain, Mind Flay and wand, then Shadowform; Spirit Tap cuts the rests.",
			order = {
				105850, 105850,   -- 1-2: Wand Specialization x2
				105833, 105833, 105833, 105833, 105833,   -- 3-7: Spirit Tap x5
				105830, 105830,   -- 8-9: Improved Shadow Word: Pain x2
				105831, 105831, 105831,   -- 10-12: Improved Mind Blast x3
				105826,   -- 13: Mind Flay
				105825, 105825,   -- 14-15: Improved Mind Flay x2
				110851, 110851,   -- 16-17: Shadow Focus x2
				105820,   -- 18: Vampiric Embrace
				105821, 105821, 105821,   -- 19-21: Shadow Weaving x3
				105831,   -- 22: Improved Mind Blast
				105819, 105819,   -- 23-24: Devouring Contagion x2
				105831,   -- 25: Improved Mind Blast
				105824,   -- 26: Silence
				110851,   -- 27: Shadow Focus
				105818, 105818, 105818, 105818, 105818,   -- 28-32: Darkness x5
				105817,   -- 33: Shadowform
				105849, 105849, 105849, 105849, 105849,   -- 34-38: Twin Disciplines x5
				110854, 110854,   -- 39-40: Early Demise x2
				105837, 105837, 105837,   -- 41-43: Mental Strength x3
				105842, 105842, 105842,   -- 44-46: Mental Agility x3
				105844,   -- 47: Inner Focus
				105843, 105843, 105843,   -- 48-50: Meditation x3
				110851,   -- 51: Shadow Focus
			} },
		{ id = "wand", name = "Shield and wand", goal = "quest", role = "damage", tab = 1,   -- Discipline 34, Holy 10, Shadow Magic 7 in 51 points
			why = "Shield up, Pain on, wand the rest: safe steady kills, and you can heal.",
			note = "Cheap and safe early, then slower than Shadow once Shadow has Shadowform. Most guides respec to Shadow at 40.",
			order = {
				105850, 105850,   -- 1-2: Wand Specialization x2
				105833, 105833, 105833, 105833, 105833,   -- 3-7: Spirit Tap x5
				105830, 105830,   -- 8-9: Improved Shadow Word: Pain x2
				105849, 105849, 105849, 105849, 105849,   -- 10-14: Twin Disciplines x5
				105837, 105837, 105837,   -- 15-17: Mental Strength x3
				105846, 105846, 105846,   -- 18-20: Improved Power Word: Shield x3
				105842, 105842, 105842,   -- 21-23: Mental Agility x3
				105843, 105843, 105843,   -- 24-26: Meditation x3
				105839,   -- 27: Soul Warding
				105834,   -- 28: Penance
				105844,   -- 29: Inner Focus
				110853, 110853, 110853, 110853, 110853,   -- 30-34: Power in Light x5
				110852, 110852,   -- 35-36: Holy Precision x2
				105835,   -- 37: Renewed Hope
				105836,   -- 38: Power Infusion
				110855, 110855, 110855, 110855, 110855,   -- 39-43: Holy Specialization x5
				105863, 105863, 105863, 105863, 105863,   -- 44-48: Divine Fury x5
				105835, 105835,   -- 49-50: Renewed Hope x2
				110852,   -- 51: Holy Precision
			} },
		{ id = "disc", name = "Discipline", goal = "dungeon", role = "healer", tab = 1,   -- Discipline 32, Holy 19, Shadow Magic 0 in 51 points
			why = "Shields stop the damage before it lands, then Penance heals or hurts.",
			note = "Slow alone: shield, Shadow Word: Pain and wand. Shadow quests faster and still heals early dungeons.",
			order = {
				105850, 105850,   -- 1-2: Wand Specialization x2
				105849, 105849, 105849, 105849, 105849,   -- 3-7: Twin Disciplines x5
				105837, 105837, 105837,   -- 8-10: Mental Strength x3
				105846, 105846, 105846,   -- 11-13: Improved Power Word: Shield x3
				105843, 105843, 105843,   -- 14-16: Meditation x3
				105844,   -- 17: Inner Focus
				105842, 105842,   -- 18-19: Mental Agility x2
				105839,   -- 20: Soul Warding
				105834,   -- 21: Penance
				105835, 105835, 105835, 105835, 105835,   -- 22-26: Renewed Hope x5
				105840, 105840, 105840,   -- 27-29: Divine Aegis x3
				105842,   -- 30: Mental Agility
				105836,   -- 31: Power Infusion
				105866, 105866, 105866,   -- 32-34: Improved Renew x3
				110855, 110855, 110855, 110855, 110855,   -- 35-39: Holy Specialization x5
				105863, 105863, 105863, 105863, 105863,   -- 40-44: Divine Fury x5
				105860, 105860,   -- 45-46: Inspiration x2
				105858, 105858, 105858,   -- 47-49: Improved Healing x3
				105856,   -- 50: Holy Binding
				105837,   -- 51: Mental Strength
			} },
		{ id = "holy", name = "Holy", goal = "dungeon", role = "healer", tab = 2,   -- Discipline 19, Holy 32, Shadow Magic 0 in 51 points
			why = "Faster Heals, Holy Nova for packs, and Flash Heal on others heals you.",
			note = "Slow alone and hungry for mana: Smite, wand and drink. Shadow quests faster and can heal as well.",
			order = {
				105850, 105850,   -- 1-2: Wand Specialization x2
				110855,   -- 3: Holy Specialization
				105866, 105866, 105866,   -- 4-6: Improved Renew x3
				105867,   -- 7: Twilight Focus
				105863, 105863, 105863, 105863, 105863,   -- 8-12: Divine Fury x5
				105862,   -- 13: Holy Nova
				105860, 105860, 105860,   -- 14-16: Inspiration x3
				110855,   -- 17: Holy Specialization
				105856,   -- 18: Holy Binding
				105858, 105858, 105858,   -- 19-21: Improved Healing x3
				110855,   -- 22: Holy Specialization
				105855, 105855,   -- 23-24: Litany of Light x2
				105854,   -- 25: Spirit of Redemption
				105853, 105853,   -- 26-27: Spiritual Guidance x2
				105852, 105852, 105852,   -- 28-30: Spiritual Healing x3
				105853, 105853, 105853,   -- 31-33: Spiritual Guidance x3
				105851,   -- 34: Prayer of Mending
				105849, 105849, 105849, 105849, 105849,   -- 35-39: Twin Disciplines x5
				105837, 105837, 105837,   -- 40-42: Mental Strength x3
				105843, 105843, 105843,   -- 43-45: Meditation x3
				105844,   -- 46: Inner Focus
				105842, 105842, 105842,   -- 47-49: Mental Agility x3
				105846, 105846,   -- 50-51: Improved Power Word: Shield x2
			} },
		{ id = "shadowpvp", name = "Shadow PvP", goal = "pvp", role = "damage", tab = 3,   -- Discipline 18, Holy 0, Shadow Magic 33 in 51 points
			why = "Blackout stuns, a quicker fear and Silence, then Shadowform.",
			note = "No Spirit Tap or wand talent, so you rest more than plain Shadow. Blackout stuns still help alone.",
			order = {
				105832, 105832, 105832, 105832, 105832,   -- 1-5: Blackout x5
				105830, 105830,   -- 6-7: Improved Shadow Word: Pain x2
				110851, 110851, 110851,   -- 8-10: Shadow Focus x3
				105826,   -- 11: Mind Flay
				105828, 105828,   -- 12-13: Improved Psychic Scream x2
				105829, 105829,   -- 14-15: Shadow Reach x2
				105820,   -- 16: Vampiric Embrace
				105821, 105821, 105821,   -- 17-19: Shadow Weaving x3
				105831,   -- 20: Improved Mind Blast
				105824,   -- 21: Silence
				105831, 105831, 105831, 105831,   -- 22-25: Improved Mind Blast x4
				105818, 105818, 105818, 105818, 105818,   -- 26-30: Darkness x5
				105817,   -- 31: Shadowform
				110854, 110854,   -- 32-33: Early Demise x2
				105849, 105849, 105849, 105849, 105849,   -- 34-38: Twin Disciplines x5
				105848, 105848, 105848,   -- 39-41: Silent Resolve x3
				105845, 105845,   -- 42-43: Martyrdom x2
				105842, 105842, 105842,   -- 44-46: Mental Agility x3
				105844,   -- 47: Inner Focus
				105837, 105837, 105837,   -- 48-50: Mental Strength x3
				105843,   -- 51: Meditation
			} },
	},
},
ROGUE = {
	tree = 1111, tabs = { 11580, 11573, 11572 },   -- Rogue: Assassination, Combat, Subtlety
	nodes = {   -- [node] = { tab, row, ranks }
		[105742] = { 1, 1, 3 },   -- Improved Gouge
		[105723] = { 1, 1, 2 },   -- Remorseless Attacks
		[105722] = { 1, 1, 5 },   -- Malice
		[105721] = { 1, 2, 3 },   -- Ruthlessness
		[105739] = { 1, 2, 3 },   -- Improved Slice and Dice
		[105720] = { 1, 3, 2 },   -- Vigor
		[105718] = { 1, 3, 1 },   -- Blood Splatter
		[105716] = { 1, 3, 2 },   -- Lethality
		[105714] = { 1, 4, 5 },   -- Vile Poisons
		[105715] = { 1, 4, 1 },   -- Cold Blood
		[113633] = { 1, 5, 5 },   -- Relentless Strikes
		[105712] = { 1, 5, 1 },   -- Venom
		[105710] = { 1, 6, 3 },   -- Seal Fate
		[105709] = { 1, 7, 1 },   -- Mutilate
		[105708] = { 2, 1, 3 },   -- Coup de Grace
		[105741] = { 2, 1, 2 },   -- Efficient Strikes
		[113398] = { 2, 1, 5 },   -- Lightning Reflexes
		[105719] = { 2, 2, 3 },   -- Puncturing Wounds
		[105738] = { 2, 2, 3 },   -- Deflection
		[105737] = { 2, 2, 3 },   -- Precision
		[105736] = { 2, 3, 2 },   -- Endurance
		[105735] = { 2, 3, 1 },   -- Riposte
		[105759] = { 2, 3, 2 },   -- Composure
		[108100] = { 2, 4, 1 },   -- Flawless Execution
		[105726] = { 2, 4, 2 },   -- Weapon Expertise
		[105730] = { 2, 4, 3 },   -- Aggression
		[113635] = { 2, 5, 2 },   -- Dual Wield Specialization
		[105728] = { 2, 5, 1 },   -- Blade Flurry
		[105727] = { 2, 5, 5 },   -- Hack and Slash
		[105740] = { 2, 6, 5 },   -- Flash of Steel
		[105724] = { 2, 7, 1 },   -- Adrenaline Rush
		[105761] = { 3, 1, 3 },   -- Master of Deception
		[105760] = { 3, 1, 5 },   -- Opportunity
		[105745] = { 3, 2, 2 },   -- Dirty Deeds
		[105756] = { 3, 2, 3 },   -- Camouflage
		[105749] = { 3, 2, 3 },   -- Improved Ambush
		[105757] = { 3, 2, 2 },   -- Dirty Tricks
		[105755] = { 3, 3, 3 },   -- Initiative
		[105743] = { 3, 3, 1 },   -- Premeditation
		[105752] = { 3, 3, 3 },   -- Serrated Blades
		[105753] = { 3, 4, 2 },   -- Elusiveness
		[105754] = { 3, 4, 1 },   -- Ghostly Strike
		[105747] = { 3, 5, 2 },   -- Heightened Senses
		[105746] = { 3, 5, 1 },   -- Preparation
		[105748] = { 3, 5, 1 },   -- Hemorrhage
		[105750] = { 3, 6, 5 },   -- Boot Knife
		[110866] = { 3, 7, 1 },   -- Death Mark
	},
	builds = {
		{ id = "combat", name = "Combat", goal = "quest", role = "damage", tab = 2,   -- Assassination 16, Combat 35, Subtlety 0 in 51 points
			why = "Cheap Sinister Strikes with any weapon, Riposte, Blade Flurry, Shank.",
			order = {
				105741, 105741,   -- 1-2: Efficient Strikes x2
				105708, 105708, 105708,   -- 3-5: Coup de Grace x3
				105738, 105738, 105738,   -- 6-8: Deflection x3
				105737, 105737,   -- 9-10: Precision x2
				105735,   -- 11: Riposte
				105737,   -- 12: Precision
				105736,   -- 13: Endurance
				105759, 105759,   -- 14-15: Composure x2
				108100,   -- 16: Flawless Execution
				105726, 105726,   -- 17-18: Weapon Expertise x2
				105730, 105730,   -- 19-20: Aggression x2
				105728,   -- 21: Blade Flurry
				105727, 105727, 105727, 105727,   -- 22-25: Hack and Slash x4
				105740, 105740, 105740, 105740, 105740,   -- 26-30: Flash of Steel x5
				105724,   -- 31: Adrenaline Rush
				105727,   -- 32: Hack and Slash
				105730,   -- 33: Aggression
				113635, 113635,   -- 34-35: Dual Wield Specialization x2
				105723, 105723,   -- 36-37: Remorseless Attacks x2
				105722, 105722, 105722,   -- 38-40: Malice x3
				105721, 105721, 105721,   -- 41-43: Ruthlessness x3
				105722, 105722,   -- 44-45: Malice x2
				105716, 105716,   -- 46-47: Lethality x2
				105739, 105739,   -- 48-49: Improved Slice and Dice x2
				105720,   -- 50: Vigor
				105715,   -- 51: Cold Blood
			} },
		{ id = "assassination", name = "Assassination", goal = "quest", role = "damage", tab = 1,   -- Assassination 31, Combat 15, Subtlety 5 in 51 points
			why = "Crits and cheap finishers, then poisons, Venom and Mutilate on daggers.",
			note = "Mutilate comes late and needs daggers; do the poison quest at 20. Combat kills faster until then.",
			order = {
				105723, 105723,   -- 1-2: Remorseless Attacks x2
				105722, 105722, 105722,   -- 3-5: Malice x3
				105721, 105721, 105721,   -- 6-8: Ruthlessness x3
				105722, 105722,   -- 9-10: Malice x2
				105716, 105716,   -- 11-12: Lethality x2
				105739, 105739,   -- 13-14: Improved Slice and Dice x2
				105720,   -- 15: Vigor
				105715,   -- 16: Cold Blood
				105714, 105714, 105714, 105714,   -- 17-20: Vile Poisons x4
				105712,   -- 21: Venom
				113633, 113633, 113633, 113633,   -- 22-25: Relentless Strikes x4
				105710, 105710, 105710,   -- 26-28: Seal Fate x3
				113633,   -- 29: Relentless Strikes
				105714,   -- 30: Vile Poisons
				105709,   -- 31: Mutilate
				105760, 105760, 105760, 105760, 105760,   -- 32-36: Opportunity x5
				105708, 105708, 105708,   -- 37-39: Coup de Grace x3
				113398, 113398,   -- 40-41: Lightning Reflexes x2
				105737, 105737, 105737,   -- 42-44: Precision x3
				105719, 105719, 105719,   -- 45-47: Puncturing Wounds x3
				105759, 105759,   -- 48-49: Composure x2
				105736, 105736,   -- 50-51: Endurance x2
			} },
		{ id = "subtlety", name = "Subtlety", goal = "quest", role = "damage", tab = 3,   -- Assassination 15, Combat 5, Subtlety 31 in 51 points
			why = "Dagger Ambush from Stealth, again after Ghostly Strike; then Hemorrhage.",
			note = "Needs a main-hand dagger and Stealth before each pull; slower than Combat until Hemorrhage.",
			order = {
				105760, 105760, 105760, 105760, 105760,   -- 1-5: Opportunity x5
				105756, 105756, 105756,   -- 6-8: Camouflage x3
				105749, 105749,   -- 9-10: Improved Ambush x2
				105743,   -- 11: Premeditation
				105749,   -- 12: Improved Ambush
				105755, 105755, 105755,   -- 13-15: Initiative x3
				105754,   -- 16: Ghostly Strike
				105752, 105752, 105752,   -- 17-19: Serrated Blades x3
				105753,   -- 20: Elusiveness
				105748,   -- 21: Hemorrhage
				105741, 105741,   -- 22-23: Efficient Strikes x2
				105746,   -- 24: Preparation
				105753,   -- 25: Elusiveness
				105745, 105745,   -- 26-27: Dirty Deeds x2
				105750, 105750, 105750, 105750, 105750,   -- 28-32: Boot Knife x5
				110866,   -- 33: Death Mark
				105708, 105708, 105708,   -- 34-36: Coup de Grace x3
				105723, 105723,   -- 37-38: Remorseless Attacks x2
				105722, 105722, 105722, 105722, 105722,   -- 39-43: Malice x5
				105721, 105721, 105721,   -- 44-46: Ruthlessness x3
				105716, 105716,   -- 47-48: Lethality x2
				105718,   -- 49: Blood Splatter
				105739, 105739,   -- 50-51: Improved Slice and Dice x2
			} },
		{ id = "subpvp", name = "Subtlety PvP", goal = "pvp", role = "damage", tab = 3,   -- Assassination 16, Combat 3, Subtlety 32 in 51 points
			why = "Hard to spot, cheap stuns from Stealth, Vanish sooner, Death Mark burst.",
			note = "Made for fighting players: quests slower than Combat. Open with Premeditation and Cheap Shot.",
			order = {
				105761, 105761, 105761,   -- 1-3: Master of Deception x3
				105760, 105760,   -- 4-5: Opportunity x2
				105756, 105756, 105756,   -- 6-8: Camouflage x3
				105745, 105745,   -- 9-10: Dirty Deeds x2
				105743,   -- 11: Premeditation
				105755, 105755, 105755,   -- 12-14: Initiative x3
				105752,   -- 15: Serrated Blades
				105754,   -- 16: Ghostly Strike
				105753, 105753,   -- 17-18: Elusiveness x2
				105752, 105752,   -- 19-20: Serrated Blades x2
				105748,   -- 21: Hemorrhage
				105746,   -- 22: Preparation
				105747, 105747,   -- 23-24: Heightened Senses x2
				105757, 105757,   -- 25-26: Dirty Tricks x2
				105750, 105750, 105750, 105750, 105750,   -- 27-31: Boot Knife x5
				110866,   -- 32: Death Mark
				105708, 105708, 105708,   -- 33-35: Coup de Grace x3
				105722, 105722, 105722, 105722, 105722,   -- 36-40: Malice x5
				105742, 105742, 105742,   -- 41-43: Improved Gouge x3
				105721, 105721,   -- 44-45: Ruthlessness x2
				105716, 105716,   -- 46-47: Lethality x2
				105720, 105720,   -- 48-49: Vigor x2
				105739,   -- 50: Improved Slice and Dice
				105715,   -- 51: Cold Blood
			} },
	},
},
SHAMAN = {
	tree = 1082, tabs = { 11326, 11363, 11362 },   -- Shaman: Elemental Combat, Enhancement, Restoration
	nodes = {   -- [node] = { tab, row, ranks }
		[104773] = { 1, 1, 5 },   -- Convection
		[104772] = { 1, 1, 5 },   -- Concussion
		[104769] = { 1, 2, 3 },   -- Elemental Devastation
		[104767] = { 1, 2, 5 },   -- Reverberation
		[104771] = { 1, 2, 3 },   -- Elemental Alacrity
		[104770] = { 1, 2, 3 },   -- Call of Flame
		[104768] = { 1, 3, 1 },   -- Elemental Focus
		[104763] = { 1, 4, 3 },   -- Eye of the Storm
		[104762] = { 1, 4, 1 },   -- Earthbound
		[104760] = { 1, 5, 1 },   -- Call of Thunder
		[104759] = { 1, 5, 3 },   -- Lightning Overload
		[104766] = { 1, 6, 5 },   -- Elemental Fury
		[104758] = { 1, 7, 1 },   -- Lightning Mastery
		[104757] = { 2, 1, 2 },   -- Earth's Grasp
		[104753] = { 2, 1, 5 },   -- Thundering Strikes
		[104756] = { 2, 1, 5 },   -- Ancestral Knowledge
		[104754] = { 2, 2, 2 },   -- Guardian Totems
		[104755] = { 2, 2, 3 },   -- Mental Dexterity
		[104751] = { 2, 2, 3 },   -- Improved Lightning Shield
		[104750] = { 2, 3, 3 },   -- Elemental Weapons
		[104749] = { 2, 3, 1 },   -- Shamanistic Focus
		[104748] = { 2, 3, 3 },   -- Anticipation
		[104746] = { 2, 4, 5 },   -- Toughness
		[104747] = { 2, 4, 5 },   -- Flurry
		[104743] = { 2, 4, 1 },   -- Stormstrike
		[104752] = { 2, 4, 2 },   -- Improved Ghost Wolf
		[104745] = { 2, 5, 1 },   -- Spirit Weapons
		[104744] = { 2, 5, 2 },   -- Mental Quickness
		[104742] = { 2, 5, 2 },   -- Improved Stormstrike
		[104741] = { 2, 6, 5 },   -- Maelstrom Weapon
		[104740] = { 2, 7, 1 },   -- Rage of the Farseer
		[104739] = { 3, 1, 5 },   -- Improved Healing Wave
		[104729] = { 3, 1, 5 },   -- Tidal Focus
		[104734] = { 3, 2, 3 },   -- Mindfulness
		[104735] = { 3, 2, 5 },   -- Totemic Focus
		[104731] = { 3, 3, 3 },   -- Ancestral Healing
		[104733] = { 3, 3, 3 },   -- Healing Focus
		[104732] = { 3, 3, 1 },   -- Water Shield
		[104738] = { 3, 4, 5 },   -- Tidal Mastery
		[104730] = { 3, 4, 5 },   -- Restorative Totems
		[104728] = { 3, 4, 1 },   -- Mana Tide Totem
		[104727] = { 3, 5, 3 },   -- Healing Way
		[104726] = { 3, 5, 1 },   -- Nature's Swiftness
		[104725] = { 3, 6, 5 },   -- Purification
		[104724] = { 3, 7, 1 },   -- Riptide
	},
	builds = {
		{ id = "enh", name = "Enhancement", goal = "quest", role = "damage", tab = 2,   -- Elemental Combat 7, Enhancement 44, Restoration 0 in 51 points
			why = "Two-handed swings with cheap shocks in between; little time drinking.",
			order = {
				104753, 104753, 104753, 104753, 104753,   -- 1-5: Thundering Strikes x5
				104755, 104755, 104755,   -- 6-8: Mental Dexterity x3
				104756, 104756,   -- 9-10: Ancestral Knowledge x2
				104749,   -- 11: Shamanistic Focus
				104750, 104750, 104750,   -- 12-14: Elemental Weapons x3
				104748,   -- 15: Anticipation
				104743,   -- 16: Stormstrike
				104752, 104752,   -- 17-18: Improved Ghost Wolf x2
				104747, 104747, 104747, 104747, 104747,   -- 19-23: Flurry x5
				104742, 104742,   -- 24-25: Improved Stormstrike x2
				104741, 104741, 104741,   -- 26-28: Maelstrom Weapon x3
				104744, 104744,   -- 29-30: Mental Quickness x2
				104740,   -- 31: Rage of the Farseer
				104741, 104741,   -- 32-33: Maelstrom Weapon x2
				104745,   -- 34: Spirit Weapons
				104746, 104746, 104746, 104746, 104746,   -- 35-39: Toughness x5
				104756, 104756, 104756,   -- 40-42: Ancestral Knowledge x3
				104748, 104748,   -- 43-44: Anticipation x2
				104772, 104772, 104772, 104772, 104772,   -- 45-49: Concussion x5
				104769, 104769,   -- 50-51: Elemental Devastation x2
			} },
		{ id = "ele", name = "Elemental", goal = "quest", role = "damage", tab = 1,   -- Elemental Combat 31, Enhancement 9, Restoration 11 in 51 points
			why = "Lightning Bolt from range; Earthbind roots foes so you keep casting.",
			note = "Slow and thirsty early: drink often and fight beside Searing Totem. It picks up once Call of Thunder lands.",
			order = {
				104773, 104773, 104773, 104773, 104773,   -- 1-5: Convection x5
				104771, 104771, 104771,   -- 6-8: Elemental Alacrity x3
				104772, 104772,   -- 9-10: Concussion x2
				104768,   -- 11: Elemental Focus
				104772, 104772, 104772,   -- 12-14: Concussion x3
				104770,   -- 15: Call of Flame
				104762,   -- 16: Earthbound
				104763, 104763, 104763,   -- 17-19: Eye of the Storm x3
				104770,   -- 20: Call of Flame
				104760,   -- 21: Call of Thunder
				104759, 104759, 104759,   -- 22-24: Lightning Overload x3
				104770,   -- 25: Call of Flame
				104766, 104766, 104766, 104766, 104766,   -- 26-30: Elemental Fury x5
				104758,   -- 31: Lightning Mastery
				104729, 104729, 104729, 104729, 104729,   -- 32-36: Tidal Focus x5
				104734, 104734, 104734,   -- 37-39: Mindfulness x3
				104735, 104735,   -- 40-41: Totemic Focus x2
				104732,   -- 42: Water Shield
				104753, 104753, 104753, 104753, 104753,   -- 43-47: Thundering Strikes x5
				104756, 104756, 104756, 104756,   -- 48-51: Ancestral Knowledge x4
			} },
		{ id = "resto", name = "Restoration", goal = "dungeon", role = "healer", tab = 3,   -- Elemental Combat 0, Enhancement 10, Restoration 41 in 51 points
			why = "Fast Healing Waves and mana that lasts through long dungeon pulls.",
			note = "Kills slowly alone: quest with a partner or fight beside Searing Totem between dungeon runs.",
			order = {
				104739, 104739, 104739, 104739, 104739,   -- 1-5: Improved Healing Wave x5
				104734, 104734, 104734,   -- 6-8: Mindfulness x3
				104729, 104729,   -- 9-10: Tidal Focus x2
				104732,   -- 11: Water Shield
				104733, 104733, 104733,   -- 12-14: Healing Focus x3
				104729,   -- 15: Tidal Focus
				104728,   -- 16: Mana Tide Totem
				104729, 104729,   -- 17-18: Tidal Focus x2
				104738, 104738,   -- 19-20: Tidal Mastery x2
				104726,   -- 21: Nature's Swiftness
				104727, 104727, 104727,   -- 22-24: Healing Way x3
				104738,   -- 25: Tidal Mastery
				104725, 104725, 104725, 104725, 104725,   -- 26-30: Purification x5
				104724,   -- 31: Riptide
				104738, 104738,   -- 32-33: Tidal Mastery x2
				104730, 104730, 104730, 104730, 104730,   -- 34-38: Restorative Totems x5
				104731, 104731, 104731,   -- 39-41: Ancestral Healing x3
				104753, 104753, 104753, 104753, 104753,   -- 42-46: Thundering Strikes x5
				104756, 104756, 104756, 104756, 104756,   -- 47-51: Ancestral Knowledge x5
			} },
		{ id = "tank", name = "Enhancement tank", goal = "dungeon", role = "tank", tab = 2,   -- Elemental Combat 0, Enhancement 51, Restoration 0 in 51 points
			why = "Shield and Rockbiter up front, Earth Shock to hold, dodge and parry.",
			note = "Mail armor and no dependable taunt: fine in early dungeons with a shield. Pull small packs, mark targets.",
			order = {
				104753, 104753, 104753, 104753, 104753,   -- 1-5: Thundering Strikes x5
				104755, 104755, 104755,   -- 6-8: Mental Dexterity x3
				104754, 104754,   -- 9-10: Guardian Totems x2
				104749,   -- 11: Shamanistic Focus
				104748, 104748, 104748,   -- 12-14: Anticipation x3
				104750,   -- 15: Elemental Weapons
				104743,   -- 16: Stormstrike
				104746, 104746, 104746, 104746,   -- 17-20: Toughness x4
				104745,   -- 21: Spirit Weapons
				104742, 104742,   -- 22-23: Improved Stormstrike x2
				104746,   -- 24: Toughness
				104750, 104750,   -- 25-26: Elemental Weapons x2
				104747, 104747, 104747, 104747, 104747,   -- 27-31: Flurry x5
				104744, 104744,   -- 32-33: Mental Quickness x2
				104740,   -- 34: Rage of the Farseer
				104751, 104751, 104751,   -- 35-37: Improved Lightning Shield x3
				104757, 104757,   -- 38-39: Earth's Grasp x2
				104741, 104741, 104741, 104741, 104741,   -- 40-44: Maelstrom Weapon x5
				104756, 104756, 104756, 104756, 104756,   -- 45-49: Ancestral Knowledge x5
				104752, 104752,   -- 50-51: Improved Ghost Wolf x2
			} },
		{ id = "pvp", name = "Enhancement PvP", goal = "pvp", role = "damage", tab = 2,   -- Elemental Combat 12, Enhancement 39, Restoration 0 in 51 points
			why = "Instant Ghost Wolf to close in, Stormstrike and shocks, hard to kill.",
			order = {
				104753, 104753, 104753, 104753, 104753,   -- 1-5: Thundering Strikes x5
				104755, 104755, 104755,   -- 6-8: Mental Dexterity x3
				104754, 104754,   -- 9-10: Guardian Totems x2
				104749,   -- 11: Shamanistic Focus
				104750, 104750, 104750,   -- 12-14: Elemental Weapons x3
				104748,   -- 15: Anticipation
				104743,   -- 16: Stormstrike
				104752, 104752,   -- 17-18: Improved Ghost Wolf x2
				104746, 104746,   -- 19-20: Toughness x2
				104745,   -- 21: Spirit Weapons
				104742, 104742,   -- 22-23: Improved Stormstrike x2
				104747, 104747, 104747, 104747, 104747,   -- 24-28: Flurry x5
				104744, 104744,   -- 29-30: Mental Quickness x2
				104740,   -- 31: Rage of the Farseer
				104741, 104741, 104741, 104741, 104741,   -- 32-36: Maelstrom Weapon x5
				104746, 104746, 104746,   -- 37-39: Toughness x3
				104772, 104772, 104772, 104772, 104772,   -- 40-44: Concussion x5
				104767, 104767, 104767, 104767, 104767,   -- 45-49: Reverberation x5
				104769, 104769,   -- 50-51: Elemental Devastation x2
			} },
	},
},
WARLOCK = {
	tree = 1116, tabs = { 11629, 11636, 11637 },   -- Warlock: Affliction, Demonology, Destruction
	nodes = {   -- [node] = { tab, row, ranks }
		[105921] = { 1, 1, 2 },   -- Improved Life Tap
		[105925] = { 1, 1, 5 },   -- Suppression
		[105924] = { 1, 1, 5 },   -- Improved Corruption
		[105923] = { 1, 2, 2 },   -- Grim Reach
		[105920] = { 1, 2, 3 },   -- Improved Drains
		[105919] = { 1, 3, 2 },   -- Improved Bane of Agony
		[105918] = { 1, 3, 3 },   -- Fel Concentration
		[105916] = { 1, 3, 1 },   -- Amplify Curse
		[105917] = { 1, 3, 3 },   -- Pandemic
		[110876] = { 1, 4, 5 },   -- Malevolence
		[105914] = { 1, 4, 2 },   -- Nightfall
		[105913] = { 1, 4, 1 },   -- Curse of Exhaustion
		[105912] = { 1, 5, 1 },   -- Siphon Life
		[105911] = { 1, 5, 3 },   -- Soul Siphon
		[105910] = { 1, 6, 5 },   -- Shadow Mastery
		[105909] = { 1, 7, 1 },   -- Wrack
		[105907] = { 2, 1, 5 },   -- Demonic Embrace
		[105906] = { 2, 1, 5 },   -- Unholy Power
		[105902] = { 2, 2, 2 },   -- Demonic Aegis
		[105904] = { 2, 2, 3 },   -- Improved Voidwalker
		[105903] = { 2, 2, 3 },   -- Fel Vitality
		[105899] = { 2, 2, 2 },   -- Demonic Energies
		[105901] = { 2, 3, 3 },   -- Improved Sayaad
		[105900] = { 2, 3, 1 },   -- Demonic Sacrifice
		[105898] = { 2, 3, 2 },   -- Master Summoner
		[105897] = { 2, 4, 2 },   -- Decimation
		[105895] = { 2, 4, 1 },   -- Fel Domination
		[105896] = { 2, 4, 3 },   -- Demonic Brand
		[105892] = { 2, 5, 1 },   -- Soul Link
		[105893] = { 2, 5, 3 },   -- Demonic Knowledge
		[105891] = { 2, 6, 5 },   -- Master Demonologist
		[105890] = { 2, 7, 1 },   -- Demonic Pact
		[105889] = { 3, 1, 5 },   -- Improved Shadow Bolt
		[105888] = { 3, 1, 5 },   -- Bane
		[105885] = { 3, 2, 5 },   -- Molten Skin
		[105887] = { 3, 2, 3 },   -- Cataclysm
		[105886] = { 3, 2, 5 },   -- Aftermath
		[105883] = { 3, 3, 5 },   -- Ruin
		[105884] = { 3, 3, 1 },   -- Shadowburn
		[105882] = { 3, 4, 3 },   -- Intensity
		[105879] = { 3, 4, 3 },   -- Agonizing Flames
		[105880] = { 3, 4, 1 },   -- Conflagrate
		[105876] = { 3, 5, 1 },   -- Bane of Havoc
		[105875] = { 3, 6, 5 },   -- Shadow and Flame
		[105874] = { 3, 7, 1 },   -- Incinerate
	},
	builds = {
		{ id = "aff", name = "Affliction", goal = "quest", role = "damage", tab = 1,   -- Affliction 41, Demonology 10, Destruction 0 in 51 points
			why = "Instant Corruption and Agony from range, then Drain Life to heal up.",
			order = {
				105924, 105924, 105924, 105924, 105924,   -- 1-5: Improved Corruption x5
				105925, 105925, 105925, 105925,   -- 6-9: Suppression x4
				105923, 105923,   -- 10-11: Grim Reach x2
				105918, 105918, 105918,   -- 12-14: Fel Concentration x3
				105919, 105919,   -- 15-16: Improved Bane of Agony x2
				105914, 105914,   -- 17-18: Nightfall x2
				105920, 105920,   -- 19-20: Improved Drains x2
				105912,   -- 21: Siphon Life
				105920,   -- 22: Improved Drains
				105911, 105911, 105911,   -- 23-25: Soul Siphon x3
				105910, 105910, 105910, 105910, 105910,   -- 26-30: Shadow Mastery x5
				105909,   -- 31: Wrack
				105921, 105921,   -- 32-33: Improved Life Tap x2
				105917, 105917, 105917,   -- 34-36: Pandemic x3
				110876, 110876, 110876, 110876, 110876,   -- 37-41: Malevolence x5
				105906, 105906, 105906, 105906, 105906,   -- 42-46: Unholy Power x5
				105903, 105903, 105903,   -- 47-49: Fel Vitality x3
				105899, 105899,   -- 50-51: Demonic Energies x2
			} },
		{ id = "demo", name = "Demonology", goal = "quest", role = "damage", tab = 2,   -- Affliction 20, Demonology 31, Destruction 0 in 51 points
			why = "A tougher demon fights beside you while you add curses and Searing Pain.",
			order = {
				105906, 105906, 105906, 105906, 105906,   -- 1-5: Unholy Power x5
				105903, 105903, 105903,   -- 6-8: Fel Vitality x3
				105899, 105899,   -- 9-10: Demonic Energies x2
				105898, 105898,   -- 11-12: Master Summoner x2
				105902, 105902,   -- 13-14: Demonic Aegis x2
				105900,   -- 15: Demonic Sacrifice
				105896, 105896, 105896,   -- 16-18: Demonic Brand x3
				105895,   -- 19: Fel Domination
				105907,   -- 20: Demonic Embrace
				105892,   -- 21: Soul Link
				105893, 105893, 105893,   -- 22-24: Demonic Knowledge x3
				105904,   -- 25: Improved Voidwalker
				105891, 105891, 105891, 105891, 105891,   -- 26-30: Master Demonologist x5
				105890,   -- 31: Demonic Pact
				105924, 105924, 105924, 105924, 105924,   -- 32-36: Improved Corruption x5
				105925, 105925, 105925, 105925, 105925,   -- 37-41: Suppression x5
				105921, 105921,   -- 42-43: Improved Life Tap x2
				105917, 105917, 105917,   -- 44-46: Pandemic x3
				110876, 110876, 110876, 110876, 110876,   -- 47-51: Malevolence x5
			} },
		{ id = "destro", name = "Destruction", goal = "quest", role = "damage", tab = 3,   -- Affliction 9, Demonology 0, Destruction 42 in 51 points
			why = "Immolate, Shadow Bolt and Conflagrate: big hits, best in a group.",
			note = "Burns mana and stands still to cast: send the Voidwalker first, or level Affliction and switch later.",
			order = {
				105888, 105888, 105888, 105888, 105888,   -- 1-5: Bane x5
				105887, 105887, 105887,   -- 6-8: Cataclysm x3
				105886, 105886,   -- 9-10: Aftermath x2
				105884,   -- 11: Shadowburn
				105883, 105883, 105883, 105883,   -- 12-15: Ruin x4
				105880,   -- 16: Conflagrate
				105879, 105879, 105879,   -- 17-19: Agonizing Flames x3
				105883,   -- 20: Ruin
				105876,   -- 21: Bane of Havoc
				105886, 105886, 105886,   -- 22-24: Aftermath x3
				105885,   -- 25: Molten Skin
				105875, 105875, 105875, 105875, 105875,   -- 26-30: Shadow and Flame x5
				105874,   -- 31: Incinerate
				105925, 105925, 105925, 105925,   -- 32-35: Suppression x4
				105885, 105885, 105885, 105885,   -- 36-39: Molten Skin x4
				105889, 105889, 105889, 105889, 105889,   -- 40-44: Improved Shadow Bolt x5
				105924, 105924, 105924, 105924, 105924,   -- 45-49: Improved Corruption x5
				105882, 105882,   -- 50-51: Intensity x2
			} },
		{ id = "demopvp", name = "Soul Link PvP", goal = "pvp", role = "damage", tab = 1,   -- Affliction 30, Demonology 21, Destruction 0 in 51 points
			why = "Hard to kill: more health, a demon back in a moment, then Soul Link.",
			order = {
				105907, 105907, 105907, 105907, 105907,   -- 1-5: Demonic Embrace x5
				105903, 105903, 105903,   -- 6-8: Fel Vitality x3
				105902, 105902,   -- 9-10: Demonic Aegis x2
				105898, 105898,   -- 11-12: Master Summoner x2
				105900,   -- 13: Demonic Sacrifice
				105899, 105899,   -- 14-15: Demonic Energies x2
				105895,   -- 16: Fel Domination
				105901, 105901, 105901,   -- 17-19: Improved Sayaad x3
				105897,   -- 20: Decimation
				105892,   -- 21: Soul Link
				105924, 105924, 105924, 105924, 105924,   -- 22-26: Improved Corruption x5
				105925, 105925, 105925,   -- 27-29: Suppression x3
				105923, 105923,   -- 30-31: Grim Reach x2
				105916,   -- 32: Amplify Curse
				105917, 105917, 105917,   -- 33-35: Pandemic x3
				105919,   -- 36: Improved Bane of Agony
				105913,   -- 37: Curse of Exhaustion
				105914, 105914,   -- 38-39: Nightfall x2
				110876, 110876, 110876, 110876, 110876,   -- 40-44: Malevolence x5
				105912,   -- 45: Siphon Life
				105919,   -- 46: Improved Bane of Agony
				105910, 105910, 105910, 105910, 105910,   -- 47-51: Shadow Mastery x5
			} },
	},
},
WARRIOR = {
	tree = 1117, tabs = { 11650, 11657, 11670 },   -- Warrior: Arms, Fury, Protection
	nodes = {   -- [node] = { tab, row, ranks }
		[105958] = { 1, 1, 3 },   -- Improved Heroic Strike
		[105957] = { 1, 1, 5 },   -- Deflection
		[105956] = { 1, 1, 3 },   -- Improved Rend
		[105955] = { 1, 2, 2 },   -- Improved Charge
		[105954] = { 1, 2, 3 },   -- Improved Tactical Mastery
		[105952] = { 1, 2, 2 },   -- Improved Overpower
		[105951] = { 1, 3, 1 },   -- Anger Management
		[105950] = { 1, 3, 3 },   -- Deep Wounds
		[105948] = { 1, 4, 3 },   -- Two-Handed Weapon Specialization
		[105947] = { 1, 4, 2 },   -- Impale
		[110524] = { 1, 5, 2 },   -- Bloodthrill
		[105945] = { 1, 5, 1 },   -- Sweeping Strikes
		[105944] = { 1, 5, 5 },   -- Weaponmaster
		[110858] = { 1, 6, 2 },   -- Improved Slam
		[105942] = { 1, 6, 3 },   -- Improved Hamstring
		[105941] = { 1, 7, 1 },   -- Mortal Strike
		[105939] = { 2, 1, 5 },   -- Cruelty
		[105937] = { 2, 2, 5 },   -- Unbridled Wrath
		[105953] = { 2, 3, 3 },   -- Furious Precision
		[105935] = { 2, 3, 1 },   -- Piercing Howl
		[105934] = { 2, 3, 3 },   -- Blood Craze
		[105931] = { 2, 3, 5 },   -- Enrage
		[105933] = { 2, 4, 5 },   -- Dual Wield Specialization
		[105932] = { 2, 4, 2 },   -- Improved Execute
		[105978] = { 2, 5, 2 },   -- Improved Berserker Rage
		[105927] = { 2, 5, 1 },   -- Death Wish
		[113569] = { 2, 5, 2 },   -- Gore Drinker
		[105977] = { 2, 6, 2 },   -- Improved Whirlwind
		[105928] = { 2, 6, 3 },   -- Flurry
		[105930] = { 2, 7, 1 },   -- Bloodthirst
		[105974] = { 3, 1, 2 },   -- Improved Bloodrage
		[105976] = { 3, 1, 5 },   -- Shield Specialization
		[105975] = { 3, 2, 5 },   -- Anticipation
		[105969] = { 3, 2, 3 },   -- Improved Revenge
		[105972] = { 3, 2, 3 },   -- Improved Thunder Clap
		[105970] = { 3, 3, 1 },   -- Last Stand
		[105971] = { 3, 3, 2 },   -- Master of Defense
		[110856] = { 3, 3, 3 },   -- Defiance
		[105968] = { 3, 4, 3 },   -- Improved Sunder Armor
		[105966] = { 3, 4, 1 },   -- Vanguard
		[105963] = { 3, 4, 2 },   -- Improved Shield Bash
		[105964] = { 3, 5, 2 },   -- Improved Shield Wall
		[105965] = { 3, 5, 1 },   -- Concussion Blow
		[105961] = { 3, 5, 3 },   -- Focused Rage
		[105962] = { 3, 6, 5 },   -- Bastion
		[105959] = { 3, 7, 1 },   -- Shield Slam
	},
	builds = {
		{ id = "protsolo", name = "Sword and board", goal = "quest", role = "tank", tab = 3,   -- Arms 0, Fury 19, Protection 32 in 51 points
			why = "One-hander and shield: Revenge after every block, and you rarely rest.",
			order = {
				105976, 105976, 105976, 105976, 105976,   -- 1-5: Shield Specialization x5
				105974, 105974,   -- 6-7: Improved Bloodrage x2
				105972, 105972, 105972,   -- 8-10: Improved Thunder Clap x3
				105969, 105969, 105969,   -- 11-13: Improved Revenge x3
				105971, 105971,   -- 14-15: Master of Defense x2
				105966,   -- 16: Vanguard
				105970,   -- 17: Last Stand
				105975, 105975, 105975,   -- 18-20: Anticipation x3
				105965,   -- 21: Concussion Blow
				105961, 105961, 105961,   -- 22-24: Focused Rage x3
				105975,   -- 25: Anticipation
				105962, 105962, 105962, 105962, 105962,   -- 26-30: Bastion x5
				105959,   -- 31: Shield Slam
				105939, 105939, 105939, 105939, 105939,   -- 32-36: Cruelty x5
				105937, 105937, 105937, 105937, 105937,   -- 37-41: Unbridled Wrath x5
				105931, 105931, 105931, 105931, 105931,   -- 42-46: Enrage x5
				105934, 105934, 105934,   -- 47-49: Blood Craze x3
				105935,   -- 50: Piercing Howl
				105975,   -- 51: Anticipation
			} },
		{ id = "arms", name = "Arms", goal = "quest", role = "damage", tab = 1,   -- Arms 33, Fury 18, Protection 0 in 51 points
			why = "One big two-hander: Rend, Overpower, then Mortal Strike.",
			note = "Runs short of rage and rests more than a shield does. Charge into every pull and heal with Victory Rush.",
			order = {
				105956, 105956, 105956,   -- 1-3: Improved Rend x3
				105957, 105957,   -- 4-5: Deflection x2
				105955, 105955,   -- 6-7: Improved Charge x2
				105954, 105954, 105954,   -- 8-10: Improved Tactical Mastery x3
				105951,   -- 11: Anger Management
				105950, 105950, 105950,   -- 12-14: Deep Wounds x3
				105952, 105952,   -- 15-16: Improved Overpower x2
				105948, 105948, 105948,   -- 17-19: Two-Handed Weapon Specialization x3
				105947,   -- 20: Impale
				105945,   -- 21: Sweeping Strikes
				105944, 105944, 105944, 105944, 105944,   -- 22-26: Weaponmaster x5
				105947,   -- 27: Impale
				110858, 110858,   -- 28-29: Improved Slam x2
				110524,   -- 30: Bloodthrill
				105941,   -- 31: Mortal Strike
				110524,   -- 32: Bloodthrill
				105939, 105939, 105939, 105939, 105939,   -- 33-37: Cruelty x5
				105937, 105937, 105937, 105937, 105937,   -- 38-42: Unbridled Wrath x5
				105931, 105931, 105931, 105931, 105931,   -- 43-47: Enrage x5
				105934, 105934, 105934,   -- 48-50: Blood Craze x3
				105958,   -- 51: Improved Heroic Strike
			} },
		{ id = "fury", name = "Fury", goal = "quest", role = "damage", tab = 2,   -- Arms 11, Fury 40, Protection 0 in 51 points
			why = "Two one-handers: crits and fast swings feed rage, then Bloodthirst.",
			note = "Weak until you dual wield at 20 and slow to come together. Swap in better one-handers often.",
			order = {
				105939, 105939, 105939, 105939, 105939,   -- 1-5: Cruelty x5
				105937, 105937, 105937, 105937, 105937,   -- 6-10: Unbridled Wrath x5
				105931, 105931, 105931, 105931, 105931,   -- 11-15: Enrage x5
				105953, 105953, 105953,   -- 16-18: Furious Precision x3
				105933, 105933,   -- 19-20: Dual Wield Specialization x2
				105927,   -- 21: Death Wish
				105933, 105933, 105933,   -- 22-24: Dual Wield Specialization x3
				105934,   -- 25: Blood Craze
				105928, 105928, 105928,   -- 26-28: Flurry x3
				105934, 105934,   -- 29-30: Blood Craze x2
				105930,   -- 31: Bloodthirst
				113569, 113569,   -- 32-33: Gore Drinker x2
				105977, 105977,   -- 34-35: Improved Whirlwind x2
				105978, 105978,   -- 36-37: Improved Berserker Rage x2
				105932, 105932,   -- 38-39: Improved Execute x2
				105935,   -- 40: Piercing Howl
				105958, 105958, 105958,   -- 41-43: Improved Heroic Strike x3
				105957, 105957,   -- 44-45: Deflection x2
				105954, 105954, 105954,   -- 46-48: Improved Tactical Mastery x3
				105955, 105955,   -- 49-50: Improved Charge x2
				105951,   -- 51: Anger Management
			} },
		{ id = "prot", name = "Protection", goal = "dungeon", role = "tank", tab = 3,   -- Arms 4, Fury 5, Protection 42 in 51 points
			why = "Shield tank for dungeons: Thunder Clap and Revenge keep the pack on you.",
			order = {
				105976, 105976, 105976, 105976, 105976,   -- 1-5: Shield Specialization x5
				105972, 105972, 105972,   -- 6-8: Improved Thunder Clap x3
				105974, 105974,   -- 9-10: Improved Bloodrage x2
				110856, 110856, 110856,   -- 11-13: Defiance x3
				105969, 105969, 105969,   -- 14-16: Improved Revenge x3
				105971, 105971,   -- 17-18: Master of Defense x2
				105966,   -- 19: Vanguard
				105970,   -- 20: Last Stand
				105965,   -- 21: Concussion Blow
				105961, 105961, 105961,   -- 22-24: Focused Rage x3
				105968,   -- 25: Improved Sunder Armor
				105962, 105962, 105962, 105962, 105962,   -- 26-30: Bastion x5
				105959,   -- 31: Shield Slam
				105968, 105968,   -- 32-33: Improved Sunder Armor x2
				105975, 105975, 105975, 105975, 105975,   -- 34-38: Anticipation x5
				105964, 105964,   -- 39-40: Improved Shield Wall x2
				105963, 105963,   -- 41-42: Improved Shield Bash x2
				105939, 105939, 105939, 105939, 105939,   -- 43-47: Cruelty x5
				105958, 105958, 105958,   -- 48-50: Improved Heroic Strike x3
				105957,   -- 51: Deflection
			} },
		{ id = "armspvp", name = "Arms PvP", goal = "pvp", role = "damage", tab = 1,   -- Arms 35, Fury 16, Protection 0 in 51 points
			why = "Mortal Strike cuts healing; Hamstring and Piercing Howl stop runners.",
			note = "Casters and hunters keep you at range until Intercept at 30. Fight beside a healer.",
			order = {
				105956, 105956, 105956,   -- 1-3: Improved Rend x3
				105957, 105957,   -- 4-5: Deflection x2
				105954, 105954, 105954,   -- 6-8: Improved Tactical Mastery x3
				105952, 105952,   -- 9-10: Improved Overpower x2
				105951,   -- 11: Anger Management
				105950, 105950, 105950,   -- 12-14: Deep Wounds x3
				105955,   -- 15: Improved Charge
				105948, 105948, 105948,   -- 16-18: Two-Handed Weapon Specialization x3
				105947, 105947,   -- 19-20: Impale x2
				105945,   -- 21: Sweeping Strikes
				110524, 110524,   -- 22-23: Bloodthrill x2
				105955,   -- 24: Improved Charge
				105944,   -- 25: Weaponmaster
				105942, 105942, 105942,   -- 26-28: Improved Hamstring x3
				105944, 105944,   -- 29-30: Weaponmaster x2
				105941,   -- 31: Mortal Strike
				105944, 105944,   -- 32-33: Weaponmaster x2
				110858, 110858,   -- 34-35: Improved Slam x2
				105939, 105939, 105939, 105939, 105939,   -- 36-40: Cruelty x5
				105937, 105937, 105937, 105937, 105937,   -- 41-45: Unbridled Wrath x5
				105935,   -- 46: Piercing Howl
				105931, 105931, 105931, 105931, 105931,   -- 47-51: Enrage x5
			} },
	},
},
}

-- The account's Legacy points: the Legacy window's three trees, what to buy with the points in order
-- (Talented first: its ranks start a character's talent points sooner), why each, and the challenges
-- that each give a point. Read by Legacy.lua.
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
