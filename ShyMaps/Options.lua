-- Settings: the map and how it follows you, the overlay, what shows on the map, sharing, then the dungeons.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- Dimmed, and why: the row says it under the mouse.
local function On()
	if T.db.on then return true end
	return false, "The world map is off."
end
local function Drawn()
	if not T.db.on then return On() end
	if T.db.style == "drawn" then return true end
	return false, "The terrain shows all the ground, explored or not."
end
local function Laid()
	if not T.db.on then return On() end
	if T.db.overlay then return true end
	return false, "Needs the map over the screen."
end
local function Guild()
	if T.db.guild then return true end
	return false, "Needs guild members on the map."
end
local function Suggested()
	if Shy.Way.Share.On() then return true end
	return false, "Needs suggested routes."
end
local function Routed() return not Shy.Way.missing end
local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Read when it is next used: nothing on screen to lay again.
local function Kept() end
-- The overlay alone: the map's pins stay as they lie while a knob is dragged.
local function Faint() ns.View.Faint() end

local function Views()
	local count = 0
	for _ in pairs(T.db.views) do count = count + 1 end
	return count
end

local LAYER = {
	zones = { words = "names levels seas",
		desc = "Each zone's name and levels on a continent, colored by your level. The terrain names the seas too." },
	flights = { words = "flight master taxi", desc = "Flight masters. The ones you haven't found yet are faded." },
	routes = { words = "flight paths lines", desc = "Faint lines along the flight paths between the flight points you know." },
	travel = { words = "tram ships docks", desc = "Where to catch boats, zeppelins and the tram, and where each goes." },
	dungeons = { words = "instance raid", desc = "Each dungeon's entrance and levels. Click one for its floors, bosses and loot." },
	spirits = { words = "graveyard dead", desc = "Spirit healers in each zone. When you're dead, the nearest one lights up." },
	places = { words = "towns landmarks", desc = "Towns, landmarks and other marked places." },
	rares = { words = "rare elite spawn", desc = "Where rare creatures turn up in a zone, with their names and levels." },
	directions = { words = "guard gossip",
		desc = "The place a guard points you to. The map opens on it, and a click has the arrow lead you there." },
	links = { words = "doors caves entrances", desc = "Doors and paths into other maps. Click one to open that map." },
	notesOn = { words = "notes drawings pins", desc = "Your notes and drawings. Add them from Notes in the map's menu." },
	coords = { words = "position x y", desc = "Your coordinates, and the mouse's while it's over the map." },
}
-- Who shows on the map stands with who sees you, under a caption of its own.
local PEOPLE = {
	friends = "Friends who share where they are show on the map. The others wait at its edge, Battle.net friends too.",
	guild = "Guild members who share where they are show as a dot, the rest by zone.",
}

local list = {
	apply = function() ns.Apply() end,
	reset = function()
		T:ResetDB()   -- saved views, notes and what you saw drop are kept
		if Routed() then Shy.Way.Share.SetOn(true) end
		ns.Apply()
	end,

	{ key = "on", label = "World map", words = "default off",
		desc = "Your map key opens this map. Turn it off to get the default map back." },

	{ section = "The map" },
	{ key = "style", label = "Zone look", enabled = On, words = "terrain drawn ground satellite",
		items = { { value = "drawn", text = "Drawn map" }, { value = "terrain", text = "Terrain from above" } },
		desc = "Terrain is the real ground from above, and you can pan into the zones around you." },
	{ key = "fog", label = "Unexplored areas", enabled = Drawn, words = "fog explored",
		items = {
			{ value = "faded", text = "Shown faded" },
			{ value = "clear", text = "Shown as explored" },
			{ value = "hidden", text = "Hidden" },
		},
		desc = "How the drawn map shows places you haven't been." },
	{ label = "Follow you", default = "smart", enabled = On, words = "center middle track",
		items = { { value = "off", text = "Off" }, { value = "me", text = "Center" }, { value = "smart", text = "Smart" } },
		get = function() return not T.db.follow and "off" or T.db.followSmart and "smart" or "me" end,
		set = function(v) T.db.follow, T.db.followSmart = v ~= "off", v == "smart" end,
		-- (As the switch in the map's corner: following, an open map comes to you at once.)
		apply = function(v)
			ns.Apply()
			if v ~= "off" and ns.Window.Shown() then ns.FindMe() end
		end,
		desc = "Smart keeps you in view with the way ahead. Drag the map and it offers to stay put." },
	{ key = "remember", label = "Remember your view", enabled = On, apply = Kept,
		desc = "The map reopens on the place and zoom you left, until you move to another zone." },
	{ label = "Saved views", button = "Forget", confirm = true, words = "reset zoom",
		says = function()
			local count = Views()
			return count == 0 and "None" or tostring(count)
		end,
		run = function() ns.ForgetViews() end,
		desc = "Every map opens whole again, not where you left it." },
	{ key = "windowScale", label = "Window scale", min = 0.6, max = 1.5, step = 0.05, format = Percent, settle = true,
		enabled = On, words = "size bigger smaller",
		desc = "How big everything in the map window is. Drag a corner to resize the window itself." },

	{ section = "Overlay" },
	{ key = "overlay", label = "Map over the screen", enabled = On, words = "transparent hud",
		desc = "With the map closed, it shows faintly over the game and clicks go through it. Key Bindings has a key for it." },
	{ key = "overlayOpacity", label = "Opacity by day", sub = true, min = 0.05, max = 0.7, step = 0.01, format = Percent,
		enabled = Laid, apply = Faint, desc = "How solid the map is in daylight." },
	{ key = "overlayNight", label = "Opacity at night", sub = true, min = 0.05, max = 0.7, step = 0.01, format = Percent,
		enabled = Laid, apply = Faint,
		desc = "The map stands out in the dark, so it can be fainter. Dawn and dusk blend the two." },
	{ key = "overlayMarks", label = "Trail and pins", sub = true, min = 0.2, max = 1, step = 0.01, format = Percent,
		enabled = Laid, apply = Faint, desc = "How solid you, your trail and the pins stay on the faint map." },

	{ section = "On the map" },
}
local function Add(entries)
	for _, entry in ipairs(entries) do list[#list + 1] = entry end
end

local people = {}
for _, item in ipairs(ns.SWITCHES) do
	local layer = LAYER[item.key]
	if layer then
		Add({ { key = item.key, label = item.label, needs = item.needs, enabled = On, words = layer.words, desc = layer.desc } })
	else
		people[item.key] = { key = item.key, label = item.label, enabled = On, desc = PEOPLE[item.key] }
	end
end
Add({
	{ key = "quietInside", label = "Clear in instances", enabled = On, words = "dungeon raid battleground",
		desc = "In a dungeon, raid or battleground the map leaves out friends, your guild, boats, notes and quest marks." },

	{ section = "Friends and guild" },
	{ key = "share", label = "Share where you are", words = "location privacy",
		desc = "Friends with this map see you on theirs. Your group sees which room of a dungeon you're in." },
	people.friends,
	people.guild,
	{ key = "shareGuild", label = "Share with your guild", sub = true, enabled = Guild,
		words = "location privacy", desc = "Guild members with this map see you on theirs." },
	{ label = "Suggested routes", default = true, shown = Routed, apply = Kept, words = "shared pin offer",
		get = function() return Shy.Way.Share.On() end, set = function(v) Shy.Way.Share.SetOn(v) end,
		desc = "When a friend or someone in your group shares a pin, you can take it as a route or pass." },
	{ key = "notesFromGroup", label = "Group pins as notes", sub = true, shown = Routed, apply = Kept,
		enabled = Suggested,
		desc = "A pin someone in your group shares is saved as a note too." },
})

if ns.Dungeons then
	Add({
		{ section = "Dungeons" },
		{ label = "Bosses and loot", button = "Open", words = "journal dungeon raid drops",
			run = function()
				Shy.Hub.Close()
				ns.Journal.Toggle(true)
			end,
			desc = "Every dungeon's floors, its bosses, what they do and what they drop." },
		{ key = "drops", label = "Where items drop", apply = Kept, words = "tooltip boss loot chance",
			desc = "An item's tooltip says which boss drops it, and how often." },
		-- The recorded drops are shown under their credit, as their license asks.
		{ note = ns.Dungeons.CREDIT },
	})
end
-- The painted land between the zones on the drawn map: the credit its license asks for.
if ns.data and ns.data.gapFillsCredit then Add({ { note = ns.data.gapFillsCredit } }) end

T:Settings(list)
