-- Settings: what your bars show, then each place's own (under the action bars, the stats window), reputation,
-- the hover and the pace. Where the bars go is picked on tiles, in setup and in the /shy window's Screen room.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats

ns.RefreshOptions = Shy.Settings.Refresh

local HEAD = "XP bar"   -- the tiles' caption in the Screen room

local function Under() return ns.Place() == "under" end
-- The game's own bars stand under the action bars.
local function GameBars() return Under() and T.db.barStyle == "blizzard" end
-- The stats window carries the bars: picked, or standing in while the quest window is hidden.
local function StandsIn() return ns.Place() == "quest" and not ns.dockedBy end
local function Window() return ns.Place() == "box" or StandsIn() end
local function Tipped()
	if T.db.tooltip then return true end
	return false, "Stats on hover is off."
end

local function PlaceNow()
	local now = ns.Place()
	for _, place in ipairs(ns.Places()) do
		if place.value == now then return place.text end
	end
end

-- A color changed: the bars are said again, nothing laid out.
local function Bars()
	ns.Update()
	for bar in pairs(ns.bars) do
		if bar:IsVisible() then bar:Update() end
	end
end

local TOOLTIP_LINES = {
	{ "pace", "XP per hour" },
	{ "eta", "Time to level" },
	{ "bubbles", "Bubbles to go" },
	{ "quests", "Quest XP" },
	{ "kills", "Kills to level" },
	{ "rested", "Rested XP" },
	{ "level", "This level so far" },
	{ "splits", "Level splits" },
}

-- Whose run the splits are set against: the furthest by default, nobody, or a character of the account's.
local function Runs()
	local items = { { value = "auto", text = "Your furthest character" }, { value = "off", text = "Nobody" } }
	for _, other in ipairs(ns.Splits and ns.Splits.Others() or {}) do
		items[#items + 1] = { value = other.guid, text = ("%s, level %d"):format(other.record.name or "?", other.top + 1) }
	end
	return items
end

local list = {
	apply = function() ns.Refresh() end,
	-- (That an old save was carried over is not a setting: Defaults keeps it.)
	reset = function()
		local top = T.db.repAtTop
		T:ResetDB()
		T.db.box.full = true
		if ns.Rep and T.db.repAtTop ~= top then ns.Rep.SetAtTop(T.db.repAtTop) end
		ns.Refresh()
	end,
	{ label = "Where your bars go", button = "Change", says = PlaceNow, words = "place quest window action bars stats window move",
		run = function() Shy.Hub.OpenAt("screen", HEAD) end,
		desc = "On the quest window, under your action bars or in the stats window. You pick in the Screen room." },
	{ note = "The quest window is hidden, so they show in the stats window.", alert = true, shown = StandsIn },
	{ key = "bubbles", label = "Bubbles", words = "5% twenty segments", shown = function() return not GameBars() end,
		desc = "Marks every 5% on your bars, 20 bubbles a level." },
	{ key = "questOverlay", label = "Quest XP bands", words = "overlay hand in log",
		desc = "Your bar shows where handing in your finished quests would put you, and your whole log after that." },
	{ key = "questColor", label = "Ready to hand in", color = true, sub = true, apply = Bars,
		desc = "The color for quests ready to hand in." },
	{ key = "logColor", label = "Your whole log", color = true, sub = true, apply = Bars,
		desc = "The color for every quest in your log." },
	{ note = "Shift-click your XP bar to put your progress in the chat box." },

	{ section = "Under the action bars", shown = Under },
	{ key = "barStyle", label = "Bar style",
		items = { { value = "shy", text = "Restyled" }, { value = "blizzard", text = "Default" } },
		desc = "Restyled bars match the rest of your screen. Default keeps the game's own XP bar." },
	{ key = "blizzText", label = "Default XP text", sub = true, shown = GameBars,
		desc = "Keeps the game's own XP numbers on its bar." },
	{ key = "barText", label = "Progress text",
		items = { { value = "hover", text = "On hover" }, { value = "always", text = "Always" }, { value = "off", text = "Never" } },
		desc = "How far along you are and the time to level, written on the bars." },

	{ section = "Stats window", shown = Window },
	{ key = "box.style", label = "Style", words = "card compact box",
		items = { { value = "card", text = "Card" }, { value = "compact", text = "Compact" } },
		desc = "Card is a bar with the stats switched on below. Compact is one slim line with the first two." },
}
local function Add(entries)
	for _, entry in ipairs(entries) do list[#list + 1] = entry end
end

for _, def in ipairs(ns.TILES) do
	Add({ { key = "box.tiles." .. def.key, label = def.label, sub = true, words = "tile stat box" } })
end
if ns.Rep then
	Add({ { note = "While it shows a reputation, it has these stats instead." } })
	for _, def in ipairs(ns.REP_TILES) do
		Add({ { key = "box.repTiles." .. def.key, label = def.label, sub = true, words = "reputation tile stat box" } })
	end
end
Add({
	{ key = "box.hideInCombat", label = "Hide in combat", desc = "Hides the stats window while you fight." },
	Shy.Settings.Layout("Move the stats window."),
})

if ns.Rep then
	Add({
		{ section = "Reputation" },
		{ key = "repAtTop", label = "Reputation at max level", set = function(v) ns.Rep.SetAtTop(v) end,
			desc = "At max level, tracks the next reputation you gain when you track none. The stats window shows it." },
		{ label = "Tracked reputation", button = "Pick one", run = function(button) T:TrackMenu(button) end,
			says = function()
				local data = ns.Rep.Watched()
				return data and data.name or "None"
			end,
			desc = "Right-clicking a bar works too. It gets a bar of its own, or takes your XP's place in the stats window." },
	})
end

Add({
	{ section = "Tooltip" },
	{ key = "tooltip", label = "Stats on hover", words = "tooltip card mouseover",
		desc = "Hovering a bar shows a card with the stats switched on below." },
})
for _, entry in ipairs(TOOLTIP_LINES) do
	Add({ { key = "lines." .. entry[1], label = entry[2], sub = true, enabled = Tipped, words = "tooltip line" } })
end
Add({
	{ section = "XP per hour and level ups" },
	{ key = "paceWindow", label = "XP per hour over", min = 5, max = 60, step = 5, format = function(v) return v .. " min" end,
		apply = function() ns.Update() end,
		desc = "Shorter follows how you're playing right now. Longer is steadier." },
	{ key = "levelSummary", label = "Level-up recap", desc = "Says in chat how long the level took, with its kills and quests." },
	{ key = "compare", label = "Splits against", items = Runs,
		shown = function() return ns.Splits ~= nil and #ns.Splits.Others() > 0 end,
		desc = "Sets each level's time beside another character's on this account." },
	{ label = "Your progress", button = "Share", run = function() ns.Share() end, desc = "Puts your progress in the chat box." },
	{ label = "This level's stats", button = "Reset", confirm = true, run = function()
		S.ResetLevel()
		ns.Refresh()
	end, desc = "Starts this level's time, kills and quests from nothing." },
})

T:Settings(list)

-- Where your bars go, as tiles: on setup's Screen page (a tab beside the layout and the cooldowns) and in the
-- /shy window's Screen room. A pick goes on at once, so you see it; setup puts back what stood when you close
-- it without Finish.
local PLACE = {
	quest = { glyph = "book", brief = "Quest window", say = "Your XP and reputation sit on the quest window, with your next step." },
	under = { glyph = "up", brief = "Under the bars", say = "Thin bars under your action bars, where the game puts its own." },
	box = { glyph = "note", brief = "Stats window", say = "A small window with all your levelling stats. Move it anywhere." },
}
local TILE = { H = 76, GAP = 8 }

local function PlaceTiles(parent, width, get, set)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, TILE.H)
	local places, tiles = ns.Places(), {}
	local each = (width - (#places - 1) * TILE.GAP) / #places
	for i, entry in ipairs(places) do
		local words = PLACE[entry.value]
		local tile = Shy.Setup.Tile(f, each, nil, entry.text, function()
			set(entry.value)
			f:Refresh()
		end, TILE.H)
		Shy.Hover.Glyph(tile.glyph, words.glyph)
		tile.say:SetText(words.say)
		tile.say:SetMaxLines(2)
		tile:SetPoint("TOPLEFT", (i - 1) * (each + TILE.GAP), 0)
		tile.value = entry.value
		tiles[i] = tile
	end
	function f:Refresh()
		local now = get()
		for _, tile in ipairs(tiles) do tile:Paint(tile.value == now) end
	end
	return f
end

local function Put(place)
	if T.db.place ~= place then ns.SetPlace(place) end
end

if not (Shy.Setup and Shy.Setup.Step) then return end

Shy.Setup.Step({
	id = "xp", order = 21.5, title = "XP bar", glyph = "up", tab = "screen",
	ask = "Where do you want your XP bar?",
	lead = "Your XP and the reputation you track. You'll see it move on your screen as you pick.",
	brief = function(plan) return (PLACE[plan.xp.place] or PLACE.under).brief end,
	Plan = function(plan) plan.xp = { place = ns.Place() } end,
	Build = function(parent, width, plan)
		return PlaceTiles(parent, width, function() return plan.xp.place end, function(v)
			plan.xp.place = v
			Put(v)
		end)
	end,
	Lines = function(plan)
		local words = PLACE[plan.xp.place] or PLACE.under
		return { { text = "XP bar: " .. words.brief:lower(), sub = words.say } }
	end,
	Run = function(plan)
		local answers = { place = plan.xp.place }
		if Shy.Setup.Act(plan) == "stay" then Put(answers.place) else Shy.Setup.Wait("xp", answers) end
		return false
	end,
	Later = function(answers) Put(answers.place) end,
	Worn = function() return T.db.place end,
	PutBack = function(kept) Put(kept) end,
})

-- The /shy window's Screen room, after the cooldown manager.
Shy.HubSection("screen", function(page, top)
	local head = Shy.HubHead(page, top, HEAD)
	local tiles = PlaceTiles(page, page.width, ns.Place, Put)
	tiles:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
	return tiles, function() tiles:Refresh() end
end, 45)
