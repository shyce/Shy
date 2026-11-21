-- Art: OpenMap, by the OpenMap contributors (https://www.curseforge.com/wow/addons/openmap). Copyright (c) 2026 OpenMap contributors MIT license: GapFills-LICENSE.txt, beside this file.
-- Generated file. Do not edit by hand.
local _, ns = ...
ns.data = ns.data or {}
-- The land no zone map covers, painted in the zone maps' style (Media/GapFill/<prefix>_<tile>): its tiles'
-- prefix, its box on the world's map (947) in shares (left, top, right, bottom), its size in pixels, its
-- columns of 256-pixel tiles, and the tiles drawn (row by row, from 1).
ns.data.gapFillsCredit = "Painted land between the zones: OpenMap, by the OpenMap contributors (https://www.curseforge.com/wow/addons/openmap)"
ns.data.gapFills = {
	{ "G01", { 0.671633, 0.406726, 0.864248, 0.641381 }, 1930, 1568, 8, { 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 40, 41, 42, 43, 44, 45, 48, 49, 50, 52, 56 } },   -- dun-morogh-riverglades
	{ "G02", { 0.111262, 0.684443, 0.251482, 0.862961 }, 1405, 1192, 6, { 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 } },   -- tanaris-silithus
	{ "G03", { 0.739747, 0.103208, 0.914397, 0.255154 }, 1750, 1015, 7, { 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 27 } },   -- eastern-plaguelands-western-plaguelands
	{ "G04", { 0.116252, 0.372692, 0.185614, 0.506300 }, 695, 892, 3, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 } },   -- stonetalon-mountains-the-barrens
	{ "G05", { 0.654916, 0.338612, 0.729767, 0.429929 }, 750, 610, 3, { 1, 2, 3, 4, 5, 6, 7, 8, 9 } },   -- silverpine-forest-hillsbrad-foothills
	{ "G06", { 0.163658, 0.643276, 0.278428, 0.722617 }, 1150, 530, 5, { 2, 3, 4, 5, 6, 7, 8, 9, 10, 15 } },   -- thousand-needles-feralas
	{ "G07", { 0.205823, 0.193051, 0.329576, 0.282497 }, 1240, 597, 5, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 15 } },   -- winterspring-darkshore
	{ "G08", { 0.224536, 0.333395, 0.315853, 0.406749 }, 915, 490, 4, { 1, 2, 3, 4, 5, 6, 7 } },   -- ashenvale-azshara
	{ "G09", { 0.713050, 0.687040, 0.795385, 0.787339 }, 825, 670, 4, { 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12 } },   -- stranglethorn-vale-blasted-lands
	{ "G10", { 0.234516, 0.629428, 0.314356, 0.735341 }, 800, 708, 4, { 1, 2, 3, 4, 5, 6, 7, 9, 10, 11 } },   -- thousand-needles-dustwallow-marsh
	{ "G11", { 0.109017, 0.553830, 0.166652, 0.611090 }, 577, 383, 3, { 1, 2, 4, 5, 6 } },   -- desolace-feralas
}
