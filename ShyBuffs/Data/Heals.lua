-- Generated file. Do not edit by hand.

local ADDON, ns = ...

-- A healer's own lasting spells, by class: each seat of the healing grid's cells, first to last, with
-- every spell its aura can be. `after`: what stops you casting it again shows in its place once it is gone,
-- a debuff of yours lasting that many seconds at most.
ns.Heals = {
	PRIEST = {
		{ key = "renew", spells = { [139] = true, [6074] = true, [6075] = true, [6076] = true, [6077] = true, [6078] = true, [8362] = true, [10927] = true, [10928] = true, [10929] = true, [11640] = true, [22168] = true, [23895] = true, [25058] = true, [25315] = true, [27606] = true, [28807] = true, [425268] = true, [425269] = true, [425270] = true, [425271] = true, [425272] = true, [425273] = true, [425274] = true, [425275] = true, [425276] = true, [425277] = true, [438341] = true, [450658] = true, [1232734] = true, [1236151] = true, [1289450] = true } },
		{ key = "shield", after = 15, spells = { [17] = true, [592] = true, [600] = true, [3747] = true, [6065] = true, [6066] = true, [10898] = true, [10899] = true, [10900] = true, [10901] = true, [11647] = true, [11835] = true, [11974] = true, [17139] = true, [20697] = true, [22187] = true, [27607] = true, [437930] = true, [1236154] = true } },
		{ key = "mending", spells = { [401877] = true, [402832] = true, [1240848] = true, [1240849] = true } },
		{ key = "ward", spells = { [552] = true, [6346] = true, [10060] = true, [402004] = true, [402839] = true, [459699] = true } },
	},
	DRUID = {
		{ key = "rejuvenation", spells = { [774] = true, [1058] = true, [1430] = true, [2090] = true, [2091] = true, [3627] = true, [8070] = true, [8910] = true, [9839] = true, [9840] = true, [9841] = true, [12160] = true, [15981] = true, [20664] = true, [20701] = true, [25299] = true, [27532] = true, [28716] = true, [417057] = true, [417058] = true, [417059] = true, [417060] = true, [417061] = true, [417062] = true, [417063] = true, [417064] = true, [417065] = true, [417066] = true, [417068] = true, [1236307] = true, [1242979] = true, [1280564] = true, [1308568] = true, [1310499] = true, [1310502] = true, [1317516] = true } },
		{ key = "regrowth", spells = { [8936] = true, [8938] = true, [8939] = true, [8940] = true, [8941] = true, [9750] = true, [9856] = true, [9857] = true, [9858] = true, [16561] = true, [20665] = true, [22373] = true, [22695] = true, [27637] = true, [28744] = true, [436937] = true, [436938] = true, [436939] = true, [436940] = true, [436942] = true, [436943] = true, [436944] = true, [436945] = true, [436946] = true } },
		{ key = "lifebloom", spells = { [408124] = true, [409824] = true } },
		{ key = "growth", spells = { [2893] = true, [14253] = true, [408120] = true, [409810] = true, [1238214] = true, [1238215] = true } },
	},
	SHAMAN = {
		{ key = "riptide", spells = { [22419] = true, [405168] = true, [405194] = true, [405321] = true, [405324] = true, [408521] = true, [409954] = true, [1239242] = true, [1239243] = true } },
		{ key = "earthShield", spells = { [974] = true, [408514] = true, [409947] = true } },
		{ key = "fortitude", spells = { [16177] = true } },
		{ key = "way", spells = { [29206] = true } },
	},
	PALADIN = {
		{ key = "beacon", spells = { [409906] = true } },
		{ key = "sacred", spells = { [53601] = true, [58597] = true, [412018] = true, [412019] = true, [415703] = true, [440651] = true } },
		{ key = "hand", after = 60, spells = { [1022] = true, [1044] = true, [5599] = true, [6940] = true, [10278] = true, [19753] = true, [20729] = true, [409935] = true, [442948] = true, [462853] = true } },
	},
}
