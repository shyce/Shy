-- ShyMaps: the world map drawn by a view of its own in a window of its own (the map key's, while it is on): no
-- fog, smooth zoom and pan, the view kept between opens, the places that matter and friends who use it.
-- API (Shy.addons.Maps):
--   :IsOn()          the view is in use (else the game's own map is the map)
--   :View()          the view while in use, else nil. It answers as the game's map canvas does:
--                    GetCanvas(), GetCanvasContainer(), GetCanvasScale(), GetCanvasZoomPercent(), GetMapID(),
--                    GetNormalizedCursorPosition(), GetPinFrameLevel(name), GetPinFrameLevelsManager(), IsShown()
--                    A frame laid on its canvas stands on the view as one on the game's canvas would on
--                    the game's map. On the terrain look's world's map, which shows the ground alone, the
--                    canvas fades out.
--                    GetOverContainer(): where a note or key over the map's window goes. The view may lie
--                    over the whole screen instead, faint and taking no mouse (the overlay, open while the
--                    window is closed): the canvas goes with it, what is over the window stays there.
--                    GetBeyond(): how far past the map's edges it may show, in shares of the map (0 on a
--                    map held to its art): a line that leaves the map runs on that far.
--   :OnView(fn)      fn(why) when the view shows, changes map ("map"), zoom ("scale"), size ("size"), pans
--                    ("pan"), opens ("open"), closes ("close") or is taken into use or given up ("use")
--   :Open(map)       the open map goes to `map`; closed, it opens there next time
--   :MapMenu(root)   the map's menu while the view is in use (what shows on it), which the window's menu
--                    button opens
--   :Friends()       every friend online: { name, level, className, class, zone, map, x, y, placed }, on `map`
--                    at x, y where they answered from, else at the middle of the zone the list gives
--   :ShareTargets()  every friend online as someone to share a place with (Shy.Way.Share): { label, class,
--                    uses, to }
--   :BarButton(key, { art, size, order, tip, text, hints, click, lit, made })
--                    a square plate of another addon's on the map's top bar, left of the look switch (Controls.lua)
--   :Dungeon(map, boss)   opens the dungeon journal (the map window's other side while it is open, else a window
--                    of its own): on a dungeon by its instance map (and one of its bosses, by its place in the
--                    order), on every dungeon with none
--   :Drops(item)     where an item drops: { { map, name (the dungeon's), boss (its name, nil for the rest of the
--                    dungeon), chance (in a hundred, or nil), source ("forever" | "seen" | "classic") } }, or nil
-- Bus: SHY_MAPS (on): the view was taken into use or given up.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyMaps\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Maps",
	category = "leveling",
	icon = MEDIA .. "ShyMaps",
	smallIcon = MEDIA .. "ShyMapsSmall",
	savedVariables = "ShyMapsDB",
	defaults = {
		on = true,
		style = "terrain",  -- a zone's map: "terrain" (the ground from overhead) | "drawn" (the game's art)
		fog = "faded",      -- unexplored areas of a drawn map: "faded" | "clear" | "hidden"
		remember = true,    -- reopen as it was left
		follow = true,      -- the view keeps you in sight as you move (moved by hand, it stays until you walk out of sight)
		followSmart = true, -- ... looking a little ahead along your way (View.lua, lean.LOOK); off, you in the very middle
		flights = true,
		routes = true,      -- the lines between the flight points you know
		travel = true,      -- docks and the tram
		dungeons = true,
		spirits = true,
		zones = true,       -- the zones' names and levels on a continent; the seas' and continents' on the terrain look
		places = true,
		directions = true,  -- the place a guard pointed out, and the map opening on it
		links = true,
		friends = true,     -- friends who use it, on the map, and every friend online at its rim
		coords = true,      -- yours and the mouse's, on the map's controls
		share = true,       -- friends who use it see you on theirs
		guild = true,       -- your guild on the map: who shares where they are, the rest by zone
		shareGuild = false, -- your guild sees you on theirs
		notesOn = true,     -- your notes and drawings on the map (Notes.lua)
		notesFromGroup = false,   -- a pin someone in your group shares is kept as a note too
		rares = true,       -- rare creatures on a zone's map, where they come and go (ShyQuest's word on them)
		notes = {},         -- { id, world, north, west, map, x, y, text, ink, at }
		drawings = {},      -- { world, ink, north, west, north, west, ... }
		overlay = false,    -- the map faintly over the whole screen while its window is closed, clicks passing through
		windowScale = 1,    -- that window's scale
		windowHome = 0,     -- the home the window was last made at (Window.lua's L.home): a size kept from before it is let go of
		quietInside = false,   -- inside an instance, the map without friends, guild, boats, notes or other addons' marks
		overlayOpacity = 0.13,  -- how solid the overlay's map is by day: faint, the game plain under it
		overlayNight = 0.08,    -- ... by night (dawn and dusk ease between them)
		overlayMarks = 0.6,     -- how solid what stands on it is (you, the trail, the pins): plain on the faint map
		views = {},         -- [map] = { zoom (times the whole map's size), x, y }
		last = {},          -- [character] = { map, zone }: what was shown at the last close, and where
		journal = { open = false, forMe = true, sort = "chance" },   -- the dungeon journal's window (DungeonWindow.lua)
		want = {},          -- [item] = true: drops you starred in the journal
		drops = true,       -- an item's hover says which boss drops it
		seen = {},          -- [instance map][creature] = { k = kills looted, n = its name, i = { [item] = times } } (DungeonSeen.lua)
		doors = {},         -- [instance map] = { north, west, up }: where you last came into it by a loading screen (DungeonSeen.lua)
		run = false,        -- the dungeon run you are on: { map, name, copy, began, last, kills = { [boss] = seconds in }, ended } (DungeonRun.lua)
		runs = {},          -- the runs that came to something, newest first: { map, at, took, killed, of }
	},
	-- sharedOn: friends on the map and sharing where you are were turned on once for everyone.
	keep = { views = true, last = true, seen = true, doors = true, run = true, runs = true, sharedOn = true, notes = true, drawings = true,
		noteId = true },
})
ns.T = T

function T:IsOn()
	return self.db ~= nil and self.db.on == true
end

local appliers = {}
function ns.OnApply(fn)
	appliers[#appliers + 1] = fn
end

function ns.Apply()
	for _, fn in ipairs(appliers) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:View()
	return ns.View and ns.View.InUse() and ns.View or nil
end

function T:OnView(fn)
	ns.View.OnChange(fn)
end

function T:Open(map)
	if ns.View then ns.View.Open(map) end
end

-- The view turned to `map` and gliding to take in `points` whole ({ x, y } shares of that map): what someone points
-- at on the map (ShyQuest's list of your quests: one quest's ground). False while no map of ours is open.
function T:Frame(map, points)
	local View = ns.View
	if not (View and View.InUse and View.InUse() and map) then return false end
	local flat = {}
	for _, point in ipairs(points or {}) do
		flat[#flat + 1], flat[#flat + 2] = point.x, point.y
	end
	-- (Another map: shown whole, not as it was last left, and framed at once. Left drawn back, or with the view
	-- following you elsewhere, it would be another map again by the frame after, and nothing framed.)
	if View.Map() ~= map and not View.Show(map, "whole") then return false end
	return View.Frame(flat)
end

-- The map opened on `map` as you use it (Shy.Maps.Open): in its window. False while the view is off (the game's map
-- is then yours, and not ours to open).
function T:ShowMap(map)
	if not (self:IsOn() and ns.Window and ns.View) then return false end
	if not ns.Window.Shown() then ns.Window.Set(true) end
	if map then ns.View.Open(map) end
	return true
end

-- The map's window of its own closed, where it is open (whoever docks beside it closes it with their own x).
function T:CloseWindow()
	if ns.Window and ns.Window.Shown() then ns.Window.Set(false) end
end

-- Whether the map stands in a window of its own now (Window.lua).
function T:WindowShown()
	return ns.Window ~= nil and ns.Window.Shown()
end

-- Each layer's switch, as written in the settings and the map's menu. needs: the addon it shows nothing without.
ns.SWITCHES = {
	{ key = "zones", label = "Place names" },
	{ key = "flights", label = "Flight points" },
	{ key = "routes", label = "Flight routes" },
	{ key = "travel", label = "Boats and zeppelins" },
	{ key = "dungeons", label = "Dungeon entrances" },
	{ key = "spirits", label = "Spirit healers" },
	{ key = "places", label = "Points of interest" },
	{ key = "rares", label = "Rare creatures", needs = "Quest" },
	{ key = "directions", label = "Guard directions" },
	{ key = "links", label = "Ways to other maps" },
	{ key = "friends", label = "Friends" },
	{ key = "guild", label = "Guild members" },
	{ key = "notesOn", label = "Your notes" },
	{ key = "coords", label = "Coordinates" },
}

-- The map's one menu while the view is in use, on the window's menu button: ShyQuest's rows where it is
-- loaded, every layer, how unexplored ground looks, and the rest of the settings.
function T:MapMenu(root)
	if not self:IsOn() then return end
	root:CreateTitle("Show on the map")
	local quest = Shy.addons.Quest
	if quest and quest.MapMenu then
		quest:MapMenu(root)
		root:CreateDivider()
	end
	-- The map's own tools that keep off the bar (Controls.lua, T:BarButton's `menu`): notes, sharing, the overlay.
	local tools = ns.MenuTools and ns.MenuTools() or {}
	for _, write in ipairs(tools) do write(root) end
	if #tools > 0 then root:CreateDivider() end
	for _, switch in ipairs(ns.SWITCHES) do
		if not switch.needs or Shy.addons[switch.needs] then
			root:CreateCheckbox(switch.label, function() return T.db[switch.key] == true end, function()
				T.db[switch.key] = not T.db[switch.key]
				ns.Apply()
			end)
		end
	end
	root:CreateDivider()
	root:CreateTitle("Unexplored areas")
	for _, item in ipairs({ { "faded", "Faded" }, { "clear", "As explored" }, { "hidden", "Hidden" } }) do
		local entry = root:CreateRadio(item[2], function() return T.db.fog == item[1] end, function()
			T.db.fog = item[1]
			ns.Apply()
		end)
		entry:SetEnabled(T.db.style ~= "terrain")
	end
	root:CreateDivider()
	root:CreateButton("All map settings", function() T:OpenOptions() end)
end

-- Levels against the player's: the game's quest colors, a range read as the game reads a quest of its
-- lowest level until you are in it, then as one of two under its highest.
local function Hue(level, mine)
	local diff = level - mine
	if diff >= 5 then return QuestDifficultyColors.impossible end
	if diff >= 3 then return QuestDifficultyColors.verydifficult end
	if diff >= -2 then return QuestDifficultyColors.difficult end
	if -diff <= UnitQuestTrivialLevelRange("player") then return QuestDifficultyColors.standard end
	return QuestDifficultyColors.trivial
end

function ns.LevelColor(low, high)
	local mine = UnitLevel("player")
	if mine < low then return Hue(low, mine) end
	if mine <= high then return QuestDifficultyColors.difficult end
	return Hue(high - 2, mine)
end

-- "12-18", "Level 12-18" (said), and its color; nil where the game gives no levels.
function ns.Levels(low, high, said)
	if not (low and high) or high <= 0 then return nil end
	local text = low == high and tostring(low) or (low .. "-" .. high)
	return said and ("Level " .. text) or text, ns.LevelColor(low, high)
end

-- A zone's waters for you, if you fish: "Fishing 150" (every cast lands from that skill: Data/Fishing.lua's base
-- and 95) and its color against your skill with what you wear (good from there; gold while some get away; bad
-- while none land); nil where nothing is known, or you don't fish. Your skill is read again as it changes.
local angler = { read = false }
local function Angler()
	if not angler.read then
		angler.read, angler.skill = true, nil
		local fish = select(4, GetProfessions())
		if fish then
			local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fish)
			angler.skill = (rank or 0) + (modifier or 0)
		end
	end
	return angler.skill
end

function ns.Fishing(map)
	local base = map and ns.fishing and ns.fishing[map]
	local skill = base and Angler()
	if not skill then return nil end
	local need = math.max(1, base + 95)
	local C = Shy.UI.colors
	local color = skill >= need and C.good or (skill - base + 5 > 0 and C.alert or C.bad)
	return ("Fishing %d"):format(need), color
end

local skills = CreateFrame("Frame")
skills:RegisterEvent("SKILL_LINES_CHANGED")
skills:SetScript("OnEvent", function() angler.read = false end)

-- A flight point of your side or of nobody's.
function ns.Ours(node)
	local side = UnitFactionGroup("player")
	return node.faction == Enum.FlightPathFaction.Neutral
		or (node.faction == Enum.FlightPathFaction.Horde and side == "Horde")
		or (node.faction == Enum.FlightPathFaction.Alliance and side == "Alliance")
end

-- A place in the world (continent, north, west yards) as shares of a map, from where the map's corners
-- lie (View.World); nil off its world or for a map that is no zone or continent.
local placeable = {}
function ns.OnMap(map, continent, north, west)
	local ok = placeable[map]
	if ok == nil then
		local info = C_Map.GetMapInfo(map)
		ok = info ~= nil and (info.mapType == Enum.UIMapType.Continent or info.mapType == Enum.UIMapType.Zone)
		placeable[map] = ok
	end
	if not ok then return nil end
	local world, n0, w0, n1, w1 = ns.View.World(map)
	if world ~= continent then return nil end
	return (west - w0) / (w1 - w0), (north - n0) / (n1 - n0)
end

-- The character's key for what it left the map showing: its whole name (a first name and a surname).
function ns.Me()
	local name, surname = UnitNameUnmodified("player")
	if surname and surname ~= "" then name = (name or "?") .. " " .. surname end
	return (name or "?") .. "@" .. (GetNormalizedRealmName() or "")
end

function T:OnLoad()
	-- Friends see each other only when both sides share: on for everyone once, off again only by choice.
	self:Once("sharedOn", function(settings)
		settings.friends, settings.share = true, true
	end)
	-- (The map's own window is the map now: the switch that chose between it and the game's is gone.)
	self.db.window = nil
end

-- Inside a dungeon, raid or battleground with the map kept clear there: friends, your guild, boats, notes and every
-- addon's marks (Shy.Maps.Hush) are put away. Never while the map is off: the game's map is left as it is.
function ns.Inside()
	if not (T.db.on and T.db.quietInside) then return false end
	local inside, kind = IsInInstance()
	return inside == true and (kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena")
end

local inside = CreateFrame("Frame")
inside:RegisterEvent("PLAYER_ENTERING_WORLD")
inside:RegisterEvent("ZONE_CHANGED_NEW_AREA")
inside:SetScript("OnEvent", function()
	if not T.db then return end
	local now = ns.Inside()
	Shy.Maps.Hush("ShyMaps", now)
	if now ~= inside.was then
		inside.was = now
		ns.Apply()
	end
end)
-- (Kept in step here too: the switch may change while you are inside.)
ns.OnApply(function()
	inside.was = ns.Inside()
	Shy.Maps.Hush("ShyMaps", inside.was)
end)

function T:OnLogin()
	ns.Apply()
end

function T:OnComm(msg, sender, channel)
	-- (Which room of a dungeon someone of your group is in: the journal's. Everything else: your friends'.)
	if type(msg) == "string" and msg:sub(1, 5) == "room\t" then
		if ns.Journal and ns.Journal.Heard then ns.Journal.Heard(msg, sender) end
		return
	end
	if ns.Friends then ns.Friends.Heard(msg, sender, channel) end
end

function T:OnBNComm(msg, account)
	if ns.Friends then ns.Friends.HeardBN(msg, account) end
end

function T:Friends()
	return ns.Friends and ns.Friends.List() or {}
end

function T:ShareTargets()
	return ns.Friends and ns.Friends.Targets and ns.Friends.Targets() or {}
end

function T:Dungeon(map, boss)
	if ns.Journal and ns.Journal.Open then ns.Journal.Open(map, boss) end
end

function T:Drops(item)
	return ns.Dungeons and ns.Dungeons.Drops and ns.Dungeons.Drops(item) or nil
end

-- Where every map was left, forgotten: each opens whole again.
function ns.ForgetViews()
	wipe(T.db.views)
	wipe(T.db.last)
	if ns.RefreshOptions then ns.RefreshOptions() end
end

local function Switch(on)
	T.db.on = on
	ns.Apply()
	T:Print(on and "on." or "off, the default map is back.")
end

T:Command("on", "use this map", function() Switch(true) end)
T:Command("off", "go back to the default map", function() Switch(false) end)
T:Command("window", "open or close the map", function()
	if ns.Window then ns.Window.Set(not ns.Window.Shown()) end
end)
T:Command("overlay", "the map faintly over the screen, or not", function()
	if ns.Overlay then ns.Overlay.Set(not T.db.overlay) end
end)
T:Command("forget", "forget where you left every map", function()
	ns.ForgetViews()
	T:Print("saved views forgotten.")
end)
-- For finding faults: who your list says is where, to copy. Not listed.
T:Command("friends", nil, function()
	if ns.Friends then Shy.UI.ShowCopyBox("ShyMaps friends", ns.Friends.Report()) end
end)
