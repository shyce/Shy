-- Data: ForeverDungeonRoutes, by Checkov23 (https://github.com/Checkov23/ForeverDungeonRoutes). Copyright (c) 2026 Checkov23 MIT license: DungeonRoutes-LICENSE.txt, beside this file.
-- Generated file. Do not edit by hand.
local _, ns = ...
ns.data = ns.data or {}
-- Where the bosses of the dungeons only this game has stand and where you come in, as that project's
-- author placed them by hand from guides and videos: rough places. By instance and floor (as
-- DungeonFloors.lua's, in its yards): bosses (boss:x:y), door (x:y).
ns.data.dungeonRoutesCredit = "Rough boss places and routes of the newest dungeons: ForeverDungeonRoutes, by Checkov23 (https://github.com/Checkov23/ForeverDungeonRoutes)"
ns.data.dungeonRoutes = {
[2959]={{bosses="7:245:156.1;6:421.2:183.6",door="15:28.6"},{bosses="1:371:438.1;3:241:425.6;4:403.5:194.4;5:332.3:168.1;9:182.3:93.1"}},
}
-- The order its routes meet the bosses in, by their places in the game's own list (the game lists these
-- dungeons' bosses in another order than they are met): those it has no stop for last, as the game has them.
ns.data.dungeonOrder = {
[2959]="7,6,1,3,2,4,5,9,8",
}
