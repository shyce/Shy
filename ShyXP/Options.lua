-- Options: the stats card as a live preview, box controls beside it, then tabs (box stats, XP bar, tooltip).

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

local function Boxed() return T.db.box.shown end
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

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Refresh() end)

	local function Build()
		UI.PageHeader(panel, T)

		local preview = ns.CreateCard(panel)
		preview:SetPoint("TOPLEFT", 24, -112)

		local switchLabel = UI.Text(panel, "Level stats on screen", 15, true)
		switchLabel:SetPoint("TOPLEFT", RIGHT, -114)
		local switch = group:Switch(panel, "Level stats on screen", GetBox("shown"), SetBox("shown"),
			{ desc = "Your level, XP bar and the stats you pick, in the stats box. Hover it for every stat, drag to move, right-click for its menu, Shift-click to share." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)
		-- While another piece shows the level, the box stays away, whatever the switch.
		local note = UI.Text(panel, "", 11, false, UI.colors.alert)
		note:SetPoint("TOPLEFT", switchLabel, "BOTTOMLEFT", 0, -4)
		note:SetWidth(COL + 120)
		note:SetWordWrap(true)
		group:Add({ Refresh = function()
			local by = ns.dockedBy
			if not by then
				note:SetText("")
			elseif by == "ShyQuest" then
				note:SetText("The guide shows your level, so the box stays hidden.")
			else
				note:SetText("Your level shows elsewhere, so the box stays hidden.")
			end
		end })

		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, -156)

		At(group:Dropdown(panel, "Box style", {
			{ value = "card",    text = "Card: bar and stat tiles" },
			{ value = "compact", text = "Compact: one slim line" },
		}, GetBox("style"), SetBox("style"), { width = COL, enabled = Boxed }), panel, RIGHT, -176)
		At(group:Checkbox(panel, "Hide in combat", GetBox("hideInCombat"), SetBox("hideInCombat"),
			{ enabled = Boxed }), panel, RIGHT, -228)

		local pages = {}
		local tabs = UI.Tabs(panel, { "Box stats", "XP bar", "Tooltip & more" }, function(i)
			for j, p in ipairs(pages) do p:SetShown(i == j) end
		end, 580, 15)
		tabs:SetPoint("TOPLEFT", 24, -304)

		for i, build in ipairs({ BoxPage, BarPage, MorePage }) do
			local page = CreateFrame("Frame", nil, panel)
			page:SetPoint("TOPLEFT", 0, -346)
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
