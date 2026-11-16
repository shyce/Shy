-- Options: the stats card as a live preview, box controls beside it, then tabs (box stats, XP bar, reputation, tooltip).

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function GetBox(key) return function() return T.db.box[key] end end
local function SetBox(key) return function(v) T.db.box[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Boxed() return ns.Place() == "box" end
local function Carded() return T.db.box.style == "card" end

local TOOLTIP_LINES = {
	{ "pace", "XP per hour" },
	{ "eta", "Time to level" },
	{ "bubbles", "Bubbles to go" },
	{ "quests", "Quest XP, ready and in your log" },
	{ "kills", "Kills to level" },
	{ "rested", "Rested XP" },
	{ "level", "Time, kills and quests this level" },
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

local function BoxPage(page, g)
	At(UI.Header(page, "Stats in the box", 576), page, LEFT, 0)
	local hint = UI.Text(page, "The preview above updates as you pick.", 12, false, UI.colors.dim)
	At(hint, page, LEFT, -28)
	for i, def in ipairs(ns.TILES) do
		local x = (i % 2 == 1) and LEFT or RIGHT
		local y = -54 - math.floor((i - 1) / 2) * 28
		At(g:Checkbox(page, def.label, function() return T.db.box.tiles[def.key] end,
			function(v) T.db.box.tiles[def.key] = v end,
			{ enabled = function() return Boxed() and Carded() end }), page, x, y)
	end
	local note = UI.Text(page, "Compact shows the first two on one line.", 12, false, UI.colors.dim)
	At(note, page, LEFT, -170)
end

local function BarPage(page, g)
	local function BlizzardLook() return T.db.barStyle == "blizzard" end

	At(UI.Header(page, "XP bar", COL), page, LEFT, 0)
	At(g:Dropdown(page, "Bar style", {
		{ value = "shy",      text = "Restyled, with bubbles" },
		{ value = "blizzard", text = "Default XP bar" },
	}, Get("barStyle"), Set("barStyle"), { width = COL,
		desc = "Restyled draws over the default XP bar, so its hover and tooltip still work." }), page, LEFT, -28)
	At(g:Checkbox(page, "Bubbles (5% each)", Get("bubbles"), Set("bubbles"),
		{ desc = "Splits the restyled bar and the stats box bar into 20 bubbles." }), page, LEFT, -82)
	At(g:Checkbox(page, "Default XP text on the bar", Get("blizzText"), Set("blizzText"),
		{ desc = "The default \"XP: 1234 / 5000\" text. Only on the default XP bar.", enabled = BlizzardLook }), page, LEFT, -108)
	At(g:Dropdown(page, "Progress text on the bar", {
		{ value = "hover",  text = "On hover" },
		{ value = "always", text = "Always" },
		{ value = "off",    text = "Never" },
	}, Get("barText"), Set("barText"), { width = COL,
		desc = "Level, percent, bubbles to go and time to level." }), page, LEFT, -136)

	At(UI.Header(page, "Quest XP", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Quest XP bands on the bar", Get("questOverlay"), Set("questOverlay"),
		{ desc = "Marks where your XP will be after you hand in finished quests, and after every quest in your log. The stats box always shows them." }), page, RIGHT, -32)
	At(g:ColorSwatch(page, "Ready to hand in", function() return unpack(T.db.questColor) end,
		function(r, g2, b) T.db.questColor = { r, g2, b } end), page, RIGHT, -58)
	At(g:ColorSwatch(page, "Your whole log", function() return unpack(T.db.logColor) end,
		function(r, g2, b) T.db.logColor = { r, g2, b } end), page, RIGHT, -84)
	local tip = UI.Text(page, "Shift-click the XP bar or the stats box to put your progress in the chat box.", 12, false, UI.colors.dim)
	tip:SetWidth(COL)
	At(tip, page, RIGHT, -124)
end

local function MorePage(page, g)
	At(UI.Header(page, "Tooltip", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Stats on the XP bar", Get("tooltip"), Set("tooltip"),
		{ desc = "Hovering the XP bar shows the stats ticked below." }), page, LEFT, -32)
	for i, entry in ipairs(TOOLTIP_LINES) do
		local key = entry[1]
		At(g:Checkbox(page, entry[2], function() return T.db.lines[key] end,
			function(v) T.db.lines[key] = v end,
			{ enabled = function() return T.db.tooltip end }), page, LEFT + 16, -58 - (i - 1) * 26)
	end

	At(UI.Header(page, "XP per hour and level ups", COL), page, RIGHT, 0)
	At(g:Slider(page, "XP per hour over the last", 5, 60, 5, Get("paceWindow"), Set("paceWindow"),
		{ width = COL, format = function(v) return v .. " min" end,
		desc = "Shorter follows how you are playing right now; longer is steadier." }), page, RIGHT, -30)
	At(g:Checkbox(page, "Level-up recap in chat", Get("levelSummary"), Set("levelSummary"),
		{ desc = "How long the level took, with its kills and quests." }), page, RIGHT, -80)
	At(UI.Button(page, "Share my progress", 130, function() ns.Share() end), page, RIGHT, -114)
	At(UI.Button(page, "Reset this level", 130, function()
		S.ResetLevel()
		ns.Refresh()
	end), page, RIGHT + 140, -114)

	local against = g:Dropdown(page, "Splits against", Runs(), Get("compare"), Set("compare"), { width = COL,
		desc = "Each level's time is shown beside another character's on this account." })
	At(against, page, RIGHT, -156)
	page:HookScript("OnShow", function() against:SetItems(Runs()) end)
end

local function RepPage(page, g)
	At(UI.Header(page, "Reputation", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Reputation at max level", Get("repAtTop"), function(v) ns.Rep.SetAtTop(v) end,
		{ desc = "At max level the bar and the box show the reputation you track. With none tracked, the next one you gain is." }), page, LEFT, -32)
	local pick = UI.Button(page, "Track a reputation", 160, function(self) T:TrackMenu(self) end)
	At(pick, page, LEFT, -76)
	local now = UI.Text(page, "", 12, false, UI.colors.dim)
	now:SetPoint("LEFT", pick, "RIGHT", 12, 0)
	now:SetWidth(COL - 172)
	now:SetWordWrap(false)
	g:Add({ Refresh = function()
		local data = ns.Rep.Watched()
		now:SetText(data and data.name or "None")
	end })
	local tip = UI.Text(page, "Or right-click the XP bar or the box. Below max level, tracking one shows it in place of your XP.", 12, false, UI.colors.dim)
	tip:SetWidth(COL)
	At(tip, page, LEFT, -112)

	At(UI.Header(page, "In the box", COL), page, RIGHT, 0)
	for i, def in ipairs(ns.REP_TILES) do
		At(g:Checkbox(page, def.label, function() return T.db.box.repTiles[def.key] end,
			function(v) T.db.box.repTiles[def.key] = v end,
			{ enabled = function() return Boxed() and Carded() end }), page, RIGHT, -32 - (i - 1) * 26)
	end
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Refresh() end)

	local function Build()
		UI.PageHeader(panel, T)

		-- The tabs and their pages hang from this, so a tall card pushes them down: never into them.
		local lower = CreateFrame("Frame", nil, panel)
		lower:SetSize(1, 1)
		lower:SetPoint("TOPLEFT", 0, -304)
		local preview = ns.CreateCard(panel, function(_, height)
			lower:SetPoint("TOPLEFT", 0, -math.max(304, 112 + height + 18))
		end)
		preview:SetPoint("TOPLEFT", 24, -112)

		local place = group:Dropdown(panel, "Where your bars go", ns.Places(), Get("place"), function(v) ns.SetPlace(v) end,
			{ width = COL, desc = "Your XP and the reputation you track get a bar each on the quest window or under the action bars, or share one bar in the stats window." })
		At(place, panel, RIGHT, -112)
		place:HookScript("OnShow", function(self) self:SetItems(ns.Places()) end)
		-- On the quest window while it can't carry them (hidden), they stand in the stats window (Box.lua).
		local note = UI.Text(panel, "", 11, false, UI.colors.alert)
		At(note, panel, RIGHT, -166)
		note:SetWidth(COL)
		group:Add({ Refresh = function()
			local stands = ns.Place() == "quest" and not ns.dockedBy
			note:SetText(stands and "The quest window is hidden, so they show in the stats window." or "")
		end })

		At(group:Dropdown(panel, "Stats window", {
			{ value = "card",    text = "Card: bar and stat tiles" },
			{ value = "compact", text = "Compact: one slim line" },
		}, GetBox("style"), SetBox("style"), { width = COL, enabled = Boxed }), panel, RIGHT, -186)
		At(group:Checkbox(panel, "Hide in combat", GetBox("hideInCombat"), SetBox("hideInCombat"),
			{ enabled = Boxed }), panel, RIGHT, -238)
		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, -266)

		local pages = {}
		local names, builds = { "Box stats", "XP bar" }, { BoxPage, BarPage }
		if ns.Rep then
			names[#names + 1], builds[#builds + 1] = "Reputation", RepPage
		end
		names[#names + 1], builds[#builds + 1] = "Tooltip & more", MorePage
		local tabs = UI.Tabs(panel, names, function(i)
			for j, p in ipairs(pages) do p:SetShown(i == j) end
		end, 580, 15)
		tabs:SetPoint("TOPLEFT", lower, "TOPLEFT", 24, 0)

		for i, build in ipairs(builds) do
			local page = CreateFrame("Frame", nil, panel)
			page:SetPoint("TOPLEFT", lower, "TOPLEFT", 0, -42)
			page:SetPoint("BOTTOMRIGHT")
			page:Hide()
			build(page, group)
			pages[i] = page
		end
		tabs:Select(1)
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then group:Refresh() end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		ns.Refresh()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ns.Refresh()
	end

	return panel
end

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
	local list, tiles = ns.Places(), {}
	local each = (width - (#list - 1) * TILE.GAP) / #list
	for i, entry in ipairs(list) do
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
	lead = "Your XP and the reputation you watch. It moves on your screen as you pick.",
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
	local head = Shy.HubHead(page, top, "XP bar")
	local tiles = PlaceTiles(page, page.width, ns.Place, Put)
	tiles:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
	return tiles, function() tiles:Refresh() end
end, 45)
