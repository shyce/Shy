-- Generated file. Do not edit by hand.
-- The talents your keys cast: the level each can first be had, by spell. Read by Keys.lua.
Shy.KeyTalents = {
	[5237] = 20,   -- Riposte
	[5570] = 25,   -- Insect Swarm
	[10060] = 40,   -- Power Infusion
	[11113] = 30,   -- Blast Wave
	[11129] = 40,   -- Combustion
	[11366] = 20,   -- Pyroblast
	[11426] = 40,   -- Ice Barrier
	[11958] = 25,   -- Ice Block
	[12042] = 40,   -- Arcane Power
	[12043] = 30,   -- Presence of Mind
	[12292] = 30,   -- Sweeping Strikes
	[12294] = 40,   -- Mortal Strike
	[12323] = 20,   -- Piercing Howl
	[12328] = 30,   -- Death Wish
	[12472] = 30,   -- Cold Snap
	[12809] = 30,   -- Concussion Blow
	[12975] = 20,   -- Last Stand
	[13750] = 40,   -- Adrenaline Rush
	[13877] = 30,   -- Blade Flurry
	[14177] = 25,   -- Cold Blood
	[14183] = 20,   -- Premeditation
	[14185] = 30,   -- Preparation
	[14278] = 25,   -- Ghostly Strike
	[14751] = 20,   -- Inner Focus
	[15237] = 20,   -- Holy Nova
	[15286] = 25,   -- Vampiric Embrace
	[15407] = 20,   -- Mind Flay
	[15473] = 40,   -- Shadowform
	[15487] = 30,   -- Silence
	[16166] = 40,   -- Lightning Mastery
	[16188] = 30,   -- Nature's Swiftness
	[16190] = 25,   -- Mana Tide Totem
	[16511] = 30,   -- Hemorrhage
	[17116] = 30,   -- Nature's Swiftness
	[17364] = 25,   -- Stormstrike
	[17877] = 20,   -- Shadowburn
	[18223] = 25,   -- Curse of Exhaustion
	[18265] = 30,   -- Siphon Life
	[18288] = 20,   -- Amplify Curse
	[18562] = 25,   -- Swiftmend
	[18708] = 25,   -- Fel Domination
	[18788] = 20,   -- Demonic Sacrifice
	[19028] = 30,   -- Soul Link
	[19263] = 20,   -- Deterrence
	[19503] = 30,   -- Scatter Shot
	[19574] = 40,   -- Bestial Wrath
	[19577] = 30,   -- Intimidation
	[20066] = 30,   -- Repentance
	[20216] = 20,   -- Divine Favor
	[20375] = 20,   -- Seal of Command
	[20925] = 30,   -- Holy Shield
	[23881] = 40,   -- Bloodthirst
	[23922] = 40,   -- Shield Slam
	[24858] = 40,   -- Moonkin Form
	[399956] = 40,   -- Mutilate
	[400574] = 20,   -- Arcane Blast
	[400588] = 15,   -- Missile Barrage
	[401859] = 40,   -- Prayer of Mending
	[402174] = 30,   -- Penance
	[407995] = 40,   -- Primal Bite
	[408120] = 40,   -- Wild Growth
	[408510] = 20,   -- Water Shield
	[408521] = 40,   -- Riptide
	[412758] = 40,   -- Incinerate
	[425336] = 40,   -- Rage of the Farseer
	[1225228] = 30,   -- Bane of Havoc
	[1238122] = 20,   -- Feral Charge
	[1293241] = 25,   -- Summon Hawk
	[1293817] = 25,   -- Conflagrate
	[1299346] = 25,   -- Trueshot Aura
	[1310317] = 25,   -- Vanguard
	[1310687] = 40,   -- Sniper Shot
	[1310911] = 40,   -- Light's Vigil
	[1310994] = 25,   -- Swift Judgement
	[1311015] = 20,   -- Templar's Bulwark
	[1311606] = 30,   -- Holy Shock
	[1312002] = 20,   -- Ice Lance
	[1316697] = 40,   -- Wrack
	[1316709] = 40,   -- Death Mark
	[1317257] = 30,   -- Strider Kick
	[1322605] = 40,   -- Shifting Power
	[1326079] = 25,   -- Arcane Wrath
	[1328548] = 25,   -- Oath of Light
	[1328617] = 25,   -- Lacerate
}
-- The level each leveling build first takes one, by class and build (a build that never takes it: none).
Shy.KeyBuilds = {
	DRUID = {
		balance = { [5570] = 25, [24858] = 40 },
		bear = { [407995] = 40, [1238122] = 20, [1328617] = 25 },
		cat = { [1238122] = 41, [1322605] = 40 },
		feralpvp = { [1238122] = 20, [1322605] = 42 },
		resto = { [16188] = 30, [17116] = 30, [18562] = 25, [408120] = 40 },
	},
	HUNTER = {
		bm = { [19574] = 40, [19577] = 30, [1293241] = 25, [1299346] = 58 },
		bmpvp = { [19574] = 40, [19577] = 30 },
		lonewolf = { [1299346] = 25, [1310687] = 40 },
		mm = { [19503] = 60, [1299346] = 25, [1310687] = 40 },
		survival = { [19263] = 23, [1317257] = 30 },
	},
	MAGE = {
		arcane = { [12042] = 40, [12043] = 30, [400574] = 20, [400588] = 15, [1326079] = 25 },
		fire = { [11113] = 30, [11129] = 40, [11366] = 20 },
		frost = { [11426] = 40, [11958] = 34, [12472] = 35, [1312002] = 20 },
		frostaoe = { [11426] = 40, [11958] = 31, [12472] = 38, [1312002] = 39 },
		frostpvp = { [11426] = 40, [11958] = 25, [12472] = 31, [400588] = 51, [1312002] = 20 },
	},
	PALADIN = {
		holy = { [20216] = 20, [1310911] = 40, [1311606] = 30, [1328548] = 25 },
		prot = { [20925] = 30, [1310994] = 25, [1311015] = 20 },
		ret = { [20066] = 30, [20375] = 20 },
		retpvp = { [20066] = 30, [20216] = 55, [20375] = 20 },
	},
	PRIEST = {
		disc = { [10060] = 40, [14751] = 26, [402174] = 30 },
		holy = { [14751] = 55, [15237] = 22, [401859] = 43 },
		shadow = { [14751] = 56, [15286] = 27, [15407] = 22, [15473] = 42, [15487] = 35 },
		shadowpvp = { [14751] = 56, [15286] = 25, [15407] = 20, [15473] = 40, [15487] = 30 },
		wand = { [10060] = 47, [14751] = 38, [402174] = 37 },
	},
	ROGUE = {
		assassination = { [14177] = 25, [399956] = 40 },
		combat = { [5237] = 20, [13750] = 40, [13877] = 30 },
		subpvp = { [14177] = 60, [14183] = 20, [14185] = 31, [14278] = 25, [16511] = 30, [1316709] = 41 },
		subtlety = { [14183] = 20, [14185] = 33, [14278] = 25, [16511] = 30, [1316709] = 42 },
	},
	SHAMAN = {
		ele = { [16166] = 40, [408510] = 51 },
		enh = { [17364] = 25, [425336] = 40 },
		pvp = { [17364] = 25, [425336] = 40 },
		resto = { [16188] = 30, [16190] = 25, [17116] = 30, [408510] = 20, [408521] = 40 },
		tank = { [17364] = 25, [425336] = 43 },
	},
	WARLOCK = {
		aff = { [18265] = 30, [1316697] = 40 },
		demo = { [18708] = 28, [18788] = 24, [19028] = 30 },
		demopvp = { [18223] = 46, [18265] = 54, [18288] = 41, [18708] = 25, [18788] = 22, [19028] = 30 },
		destro = { [17877] = 20, [412758] = 40, [1225228] = 30, [1293817] = 25 },
	},
	WARRIOR = {
		arms = { [12292] = 30, [12294] = 40 },
		armspvp = { [12292] = 30, [12294] = 40, [12323] = 55 },
		fury = { [12323] = 49, [12328] = 30, [23881] = 40 },
		prot = { [12809] = 30, [12975] = 29, [23922] = 40, [1310317] = 28 },
		protsolo = { [12323] = 59, [12809] = 30, [12975] = 26, [23922] = 40, [1310317] = 25 },
	},
}
-- What a mage or a warlock made, of the things your bags' keys use: it comes before what you bought.
Shy.KeyConjured = {
	[1113] = true,   -- Conjured Bread
	[1114] = true,   -- Conjured Rye
	[1487] = true,   -- Conjured Pumpernickel
	[2136] = true,   -- Conjured Purified Water
	[2288] = true,   -- Conjured Fresh Water
	[3772] = true,   -- Conjured Spring Water
	[5232] = true,   -- Minor Soulstone
	[5349] = true,   -- Conjured Muffin
	[5350] = true,   -- Conjured Water
	[5509] = true,   -- Healthstone
	[5510] = true,   -- Greater Healthstone
	[5511] = true,   -- Lesser Healthstone
	[5512] = true,   -- Minor Healthstone
	[5513] = true,   -- Mana Jade
	[8007] = true,   -- Mana Citrine
	[8008] = true,   -- Mana Ruby
	[8075] = true,   -- Conjured Sourdough
	[8076] = true,   -- Conjured Sweet Roll
	[8077] = true,   -- Conjured Mineral Water
	[8078] = true,   -- Conjured Sparkling Water
	[8079] = true,   -- Conjured Crystal Water
	[9421] = true,   -- Major Healthstone
	[16892] = true,   -- Lesser Soulstone
	[16893] = true,   -- Soulstone
	[16895] = true,   -- Greater Soulstone
	[16896] = true,   -- Major Soulstone
	[19004] = true,   -- Minor Healthstone
	[19005] = true,   -- Minor Healthstone
	[19006] = true,   -- Lesser Healthstone
	[19007] = true,   -- Lesser Healthstone
	[19008] = true,   -- Healthstone
	[19009] = true,   -- Healthstone
	[19010] = true,   -- Greater Healthstone
	[19011] = true,   -- Greater Healthstone
	[19012] = true,   -- Major Healthstone
	[19013] = true,   -- Major Healthstone
	[19696] = true,   -- Harvest Bread
	[21236] = true,   -- UNUSED ITEM
	[22895] = true,   -- Conjured Cinnamon Roll
	[231778] = true,   -- Mountain Spring Water
	[268881] = true,   -- Perishable Minor Healing Potion
	[268882] = true,   -- Perishable Lesser Healing Potion
	[268883] = true,   -- Perishable Healing Potion
	[268912] = true,   -- Expiring Crab Cake
	[268913] = true,   -- Expiring Crocolisk Steak
}
-- What your people alone can do: the one for Shift + 1, then the one for Shift + 2, each { spell, its name on a key }.
Shy.KeyRacials = {
	[1] = { { 1259718, "Will to Survive" }, { 20600, "Perception" } },   -- Human
	[2] = { { 20572, "Blood Fury" }, { 1299026, "Shatter Curse" } },   -- Orc
	[3] = { { 20594, "Stoneform" }, { 2481, "Find Treasure" } },   -- Dwarf
	[4] = { { 1259799, "Elune's Light" }, { 20580, "Shadowmeld" } },   -- Night Elf
	[5] = { { 7744, "Forsaken Will" }, { 20577, "Cannibalize" } },   -- Undead
	[6] = { { 20549, "War Stomp" }, { 20552, "Cultivation" } },   -- Tauren
	[7] = { { 20589, "Escape Artist" }, { 1259812, "Eureka!" } },   -- Gnome
	[8] = { { 20554, "Berserking" }, { 1260270, "Regeneration" } },   -- Troll
	[95] = { { 1259416, "Walk on Air" }, { 1259705, "Read Leyline" } },   -- High Order Skyborne
	[96] = { { 1259416, "Walk on Air" }, { 1259686, "Skysight" } },   -- Windshaper Skyborne
}
-- What a class teaches one people alone, by class and race: the one that guards you first; each { spell, its name on a key, on a friend }.
Shy.KeyGifts = {
	PRIEST = {
		[1] = { { 13896, "Feedback", false }, { 1277370, "Divine Grace", "other" } },   -- Human: Feedback, Divine Grace
		[3] = { { 13908, "Desperate Prayer", false }, { 1277331, "Chastise", false } },   -- Dwarf: Desperate Prayer, Chastise
		[4] = { { 2651, "Elune's Grace", false }, { 10797, "Starshards", false } },   -- Night Elf: Elune's Grace, Starshards
		[5] = { { 2652, "Weakness", false }, { 1277324, "Dark Sacrifice", false } },   -- Undead: Touch of Weakness, Dark Sacrifice
		[7] = { { 1277462, "Contingency Plan", true }, { 1277455, "Confounding", false } },   -- Gnome: Contingency Plan, Confounding Flash
		[8] = { { 18137, "Shadowguard", false }, { 9035, "Hex of Weakness", false } },   -- Troll: Shadowguard, Hex of Weakness
	},
}
-- What a pet eats: each diet's name, and the diet a thing in your bags is.
Shy.KeyPetFood = {
	names = { "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit", "Raw Meat", "Raw Fish" },
	items = {
		[117] = 1, [414] = 3, [422] = 3, [724] = 1, [733] = 1, [787] = 2, [1017] = 1, [1082] = 1, [1113] = 4, [1114] = 4, [1326] = 2, [1487] = 4,
		[1707] = 3, [2070] = 3, [2287] = 1, [2679] = 1, [2680] = 1, [2681] = 1, [2682] = 2, [2683] = 2, [2684] = 1, [2685] = 1, [2687] = 1, [2888] = 1,
		[3220] = 1, [3662] = 1, [3663] = 2, [3664] = 1, [3665] = 1, [3666] = 1, [3726] = 1, [3727] = 1, [3728] = 1, [3729] = 1, [3770] = 1, [3771] = 1,
		[3927] = 3, [4457] = 1, [4536] = 6, [4537] = 6, [4538] = 6, [4539] = 6, [4540] = 4, [4541] = 4, [4542] = 4, [4544] = 4, [4592] = 2, [4593] = 2,
		[4594] = 2, [4599] = 1, [4601] = 4, [4602] = 6, [4604] = 5, [4605] = 5, [4606] = 5, [4607] = 5, [4608] = 5, [4656] = 6, [5057] = 6, [5095] = 2,
		[5349] = 4, [5472] = 1, [5473] = 1, [5474] = 1, [5476] = 2, [5477] = 1, [5478] = 1, [5479] = 1, [5480] = 1, [5525] = 2, [5526] = 2, [5527] = 2,
		[6038] = 2, [6290] = 2, [6299] = 2, [6316] = 2, [6458] = 2, [6522] = 2, [6657] = 2, [6887] = 2, [6888] = 1, [6890] = 1, [7097] = 1, [8075] = 4,
		[8076] = 4, [8364] = 2, [8932] = 3, [8948] = 5, [8950] = 4, [8952] = 1, [8953] = 6, [8957] = 2, [9681] = 2, [11109] = 4, [11415] = 6, [11444] = 1,
		[11584] = 6, [11950] = 6, [11951] = 6, [11952] = 6, [12209] = 1, [12210] = 1, [12211] = 1, [12212] = 1, [12213] = 1, [12214] = 1, [12215] = 1, [12216] = 1,
		[12217] = 1, [12218] = 1, [12224] = 1, [12238] = 2, [12763] = 6, [13546] = 2, [13724] = 4, [13755] = 2, [13851] = 1, [13893] = 2, [13927] = 2, [13928] = 2,
		[13929] = 2, [13930] = 2, [13931] = 2, [13932] = 2, [13933] = 2, [13934] = 2, [13935] = 2, [16166] = 4, [16167] = 3, [16168] = 6, [16169] = 4, [16170] = 6,
		[16171] = 6, [16766] = 2, [16971] = 1, [17119] = 1, [17199] = 1, [17222] = 1, [17344] = 4, [17406] = 3, [17407] = 1, [17408] = 1, [17747] = 5, [18045] = 1,
		[18254] = 2, [18255] = 2, [18632] = 4, [18633] = 1, [18635] = 1, [19060] = 4, [19061] = 4, [19062] = 4, [19063] = 4, [19223] = 1, [19224] = 1, [19301] = 4,
		[19304] = 1, [19305] = 1, [19306] = 1, [19696] = 4, [19994] = 6, [19995] = 1, [19996] = 2, [20031] = 4, [20062] = 4, [20063] = 4, [20064] = 4, [20074] = 1,
		[20222] = 4, [20223] = 4, [20224] = 4, [20225] = 4, [20226] = 4, [20227] = 4, [20388] = 4, [20389] = 4, [20390] = 4, [20452] = 1, [20516] = 6, [21023] = 1,
		[21030] = 6, [21031] = 6, [21033] = 6, [21072] = 2, [21215] = 4, [21217] = 2, [21235] = 1, [21236] = 4, [21238] = 2, [21240] = 6, [21254] = 4, [21537] = 4,
		[21552] = 2, [22324] = 6, [22895] = 4, [23160] = 4, [23172] = 6, [23175] = 4, [23683] = 6, [221444] = 4, [232436] = 2, [232438] = 2, [238504] = 2, [238505] = 2,
		[238506] = 2, [238637] = 1, [238638] = 1, [238639] = 1, [238640] = 1, [238641] = 1, [238642] = 1, [246916] = 1, [249791] = 6, [249792] = 6, [249793] = 6, [249794] = 6,
		[249795] = 6, [249796] = 6, [249804] = 1, [250065] = 1, [250066] = 1, [250067] = 1, [250068] = 1, [250069] = 1, [250070] = 1, [250071] = 1, [250072] = 1, [250073] = 1,
		[250074] = 1, [250075] = 1, [250076] = 1, [250077] = 1, [250078] = 1, [250079] = 1, [250080] = 1, [250081] = 2, [251525] = 2, [251917] = 6, [252022] = 1, [252023] = 3,
		[252026] = 4, [252028] = 4, [252029] = 1, [252030] = 3, [252032] = 6, [260623] = 4, [260624] = 6, [260625] = 6, [260627] = 6, [260628] = 6, [262433] = 1, [263507] = 1,
		[263509] = 1, [263512] = 1, [267474] = 5, [268912] = 2, [268913] = 1, [272053] = 4, [272054] = 4, [272055] = 4, [274971] = 2, [274976] = 1, [277313] = 1, [278117] = 1,
		[278118] = 1, [278119] = 4, [278120] = 6, [278121] = 1, [278122] = 6, [278569] = 3, [286152] = 2, [287416] = 4, [287963] = 1, [287973] = 1, [287974] = 2,
	},
}
