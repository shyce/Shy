-- Generated file. Do not edit by hand.
local _, ns = ...
-- [world] = { sea = { r, g, b }, [level] = { pixels a block, blocks a tile, { [y * 64 + x] = true } } }
ns.lod = {
	[0] = {
		sea = { 0.020, 0.024, 0.031 },
		[0] = { 128, 4, { [837] = true, [901] = true, [326] = true, [390] = true, [454] = true, [518] = true, [582] = true, [646] = true, [710] = true, [774] = true, [838] = true, [902] = true, [966] = true, [327] = true, [391] = true, [455] = true, [519] = true, [583] = true, [647] = true, [711] = true, [775] = true, [839] = true, [903] = true, [967] = true, [328] = true, [392] = true, [456] = true, [520] = true, [584] = true, [648] = true, [712] = true, [776] = true, [840] = true, [904] = true, [968] = true, [329] = true, [393] = true, [457] = true, [521] = true, [585] = true, [649] = true, [713] = true, [777] = true, [841] = true, [905] = true, [330] = true, [394] = true, [458] = true, [522] = true, [586] = true, [650] = true, [714] = true, [778] = true, [842] = true, [906] = true, [395] = true, [459] = true, [651] = true, [715] = true, [779] = true, } },
		[1] = { 32, 8, { [386] = true, [450] = true, [131] = true, [195] = true, [259] = true, [323] = true, [387] = true, [451] = true, [132] = true, [196] = true, [260] = true, [324] = true, [388] = true, [452] = true, [133] = true, [197] = true, [261] = true, [325] = true, [389] = true, [453] = true, } },
		[2] = { 8, 32, { [0] = true, [64] = true, [1] = true, [65] = true, } },
	},
	[1] = {
		sea = { 0.020, 0.024, 0.031 },
		[0] = { 128, 4, { [0] = true, [196] = true, [260] = true, [197] = true, [261] = true, [581] = true, [645] = true, [709] = true, [134] = true, [198] = true, [262] = true, [326] = true, [390] = true, [454] = true, [518] = true, [582] = true, [646] = true, [710] = true, [774] = true, [838] = true, [135] = true, [199] = true, [263] = true, [327] = true, [391] = true, [455] = true, [519] = true, [583] = true, [647] = true, [711] = true, [775] = true, [839] = true, [136] = true, [200] = true, [264] = true, [328] = true, [392] = true, [456] = true, [520] = true, [584] = true, [648] = true, [712] = true, [776] = true, [840] = true, [201] = true, [265] = true, [329] = true, [393] = true, [457] = true, [521] = true, [585] = true, [649] = true, [713] = true, [777] = true, [841] = true, [202] = true, [266] = true, [330] = true, [394] = true, [458] = true, [522] = true, [586] = true, [650] = true, [714] = true, [778] = true, [842] = true, [203] = true, [267] = true, [331] = true, [395] = true, [459] = true, [523] = true, [587] = true, [651] = true, [332] = true, [396] = true, } },
		[1] = { 32, 8, { [0] = true, [66] = true, [130] = true, [258] = true, [322] = true, [67] = true, [131] = true, [195] = true, [259] = true, [323] = true, [387] = true, [68] = true, [132] = true, [196] = true, [260] = true, [324] = true, [388] = true, [69] = true, [133] = true, [197] = true, [261] = true, [325] = true, [389] = true, [134] = true, [198] = true, } },
		[2] = { 8, 32, { [0] = true, [64] = true, [1] = true, [65] = true, } },
	},
	[30] = {
		sea = { 0.388, 0.447, 0.459 },
		[0] = { 128, 4, { [455] = true, [519] = true, [456] = true, [520] = true, } },
		[1] = { 32, 8, { [195] = true, [259] = true, [196] = true, [260] = true, } },
		[2] = { 8, 32, { [0] = true, [64] = true, [1] = true, [65] = true, } },
	},
	[489] = {
		sea = { 0.071, 0.149, 0.204 },
		[0] = { 128, 4, { [390] = true, [454] = true, [391] = true, [455] = true, } },
		[1] = { 32, 8, { [195] = true, } },
		[2] = { 8, 32, { [0] = true, } },
	},
	[529] = {
		sea = { 0.133, 0.220, 0.255 },
		[0] = { 128, 4, { [455] = true, } },
		[1] = { 32, 8, { [195] = true, } },
		[2] = { 8, 32, { [0] = true, } },
	},
	[2991] = {
		sea = { 0.020, 0.024, 0.027 },
		[0] = { 128, 4, { [326] = true, [390] = true, [454] = true, [327] = true, [391] = true, [455] = true, [328] = true, [392] = true, [456] = true, } },
		[1] = { 32, 8, { [131] = true, [195] = true, [132] = true, [196] = true, } },
		[2] = { 8, 32, { [0] = true, [1] = true, } },
	},
	[2997] = {
		sea = { 0.020, 0.031, 0.031 },
		[0] = { 128, 4, { [454] = true, [518] = true, [455] = true, [519] = true, } },
		[1] = { 32, 8, { [195] = true, [259] = true, } },
		[2] = { 8, 32, { [0] = true, [64] = true, } },
	},
}
-- [continent map] = true: it has a wash (Media/Terrain/wash_<map>), for the drawn look
ns.wash = { [1414] = true, [1415] = true, [1463] = true, [1464] = true, }
