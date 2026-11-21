-- The options page's lower sections (tooltips, nameplates, tracker extras, party, finder).
-- Options.lua calls ns.MoreOptions at the end of its page when this file is loaded.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

-- get and set for T.db[a][b] (or T.db[a][b][c]).
local function Get(a, b, c)
	return function()
		local value = T.db[a][b]
		if c then return value[c] end
		return value
	end
end
local function Set(a, b, c)
	return function(v)
		if c then T.db[a][b][c] = v else T.db[a][b] = v end
	end
end

local function Marked() return T.db.plates.on end
local function Tracking() return T.db.track == "zone" end

function ns.MoreOptions(panel, group, y)
	At(UI.Header(panel, "In the world", COL), panel, LEFT, y)
	At(group:Checkbox(panel, "Quest info on creature tooltips", Get("hover", "units"), Set("hover", "units"),
		{ desc = "A creature's tooltip lists your quests that need it or its drops, with your progress and the drop rate, plus quests it gives or takes. Nothing the default tooltip already shows is repeated." }), panel, LEFT, y - 32)
	At(group:Checkbox(panel, "... on object tooltips", Get("hover", "objects"), Set("hover", "objects"),
		{ desc = "The same for chests and other objects you can click in the world." }), panel, LEFT, y - 58)
	At(group:Checkbox(panel, "... on item tooltips", Get("hover", "items"), Set("hover", "items"),
		{ desc = "An item's tooltip names the quest that needs it and how many you have, or the quest it starts." }), panel, LEFT, y - 84)
	At(group:Checkbox(panel, "Mark quest nameplates", Get("plates", "on"), Set("plates", "on"),
		{ desc = "A mark beside the nameplate of anything you still need to kill or loot for a quest, showing which. The NPC your next step sends you to is marked too." }), panel, LEFT, y - 110)
	At(group:Dropdown(panel, "Mark position", {
		{ value = "left",  text = "Left of the nameplate" },
		{ value = "right", text = "Right of it" },
		{ value = "above", text = "Above it" },
	}, Get("plates", "where"), Set("plates", "where"), { width = COL, enabled = Marked,
		desc = "Where the quest mark sits on a nameplate." }), panel, LEFT, y - 142)
	At(group:Slider(panel, "Mark size", 0.7, 1.6, 0.1, Get("plates", "size"), Set("plates", "size"),
		{ width = COL, enabled = Marked, format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
		desc = "Size of the quest mark on nameplates." }), panel, LEFT, y - 204)
	At(group:Checkbox(panel, "Pins for unmarked objectives", function() return T.db.goals end, function(v) T.db.goals = v end,
		{ desc = "Where the default map shows no area for a quest, each unfinished objective gets a mark on the world map and, for the nearest, the minimap. Click one to outline where to look, colored by what to do there." }), panel, LEFT, y - 256)
	At(group:Checkbox(panel, "Warn about dangerous creatures", Get("hover", "careful"), Set("hover", "careful"),
		{ desc = "On the hardcore route or a hardcore realm: tooltips flag hostile elites three or more levels above you, and chat warns you once when you target one." }), panel, LEFT, y - 282)

	At(UI.Header(panel, "Beside the quest tracker", COL), panel, LEFT, y - 322)
	At(group:Checkbox(panel, "Distance to each quest", Get("beside", "distance"), Set("beside", "distance"),
		{ desc = "Shows the distance to each tracked quest's next stop under its marker." }), panel, LEFT, y - 354)
	At(group:Checkbox(panel, "Count quests in other zones", Get("beside", "elsewhere"), Set("beside", "elsewhere"),
		{ enabled = Tracking, desc = "While the tracker lists only your current zone, its title shows how many quests are elsewhere. Hover it to see which and where." }), panel, LEFT, y - 380)

	At(UI.Header(panel, "Your party", COL), panel, RIGHT, y)
	At(group:Checkbox(panel, "Share quest progress", Get("party", "share"), Set("party", "share"),
		{ desc = "Party members' progress shows under each objective in tooltips (\"Clara 3/8, Bron done\") and yours shows in theirs. Works with other quest addons that share progress. Party only, not raids. Escort times and routes are traded with your group and guild too." }), panel, RIGHT, y - 32)
	local telling = UI.Text(panel, "Tell my party in chat when I", 13, false, UI.colors.text)
	At(telling, panel, RIGHT, y - 64)
	local tells = {
		{ "objectives", "finish an objective", "Sends a line like \"<Shy> Gnoll Paw: 8/8 for [Patrolling Westfall]\"." },
		{ "starts", "loot an item that starts a quest", "Names the item and its quest. When solo, you get the line in your own chat instead." },
		{ "accepted", "accept a quest", "Sends \"<Shy> Accepted [quest]\"." },
		{ "handedIn", "turn one in", "Sends \"<Shy> Turned in [quest]\"." },
		{ "abandoned", "abandon one", "Sends \"<Shy> Abandoned [quest]\"." },
	}
	for i, tell in ipairs(tells) do
		At(group:Checkbox(panel, tell[2], Get("party", "tell", tell[1]), Set("party", "tell", tell[1]), { desc = tell[3] }),
			panel, RIGHT + 12, y - 60 - i * 26)
	end
	At(group:Dropdown(panel, "Progress sound", {
		{ value = "off",   text = "None" },
		{ value = "ready", text = "Quest ready to turn in" },
		{ value = "all",   text = "Quest ready and each objective" },
	}, function() return T.db.sound end, function(v) T.db.sound = v end, { width = COL,
		desc = "Plays the quest-complete chime when a quest is ready to turn in, and a map ping for each finished objective." }), panel, RIGHT, y - 226)

	At(UI.Header(panel, "Finder", COL), panel, RIGHT, y - 296)
	At(UI.Button(panel, "Open the finder", 150, function() ns.Find.Toggle(true) end), panel, RIGHT, y - 328)
	local finding = UI.Text(panel, "Search quests, creatures, objects and items by name and see them on the map, or find the nearest innkeeper, flight master, repair vendor, mailbox or trainer. Also |cffffffff/shyquest find|r.", 12, false, UI.colors.dim)
	finding:SetWidth(COL)
	At(finding, panel, RIGHT, y - 360)
end
