-- ShyTip options: position, look with a live preview, unit colors and commands.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI
local floor = math.floor

local LEFT, RIGHT, COL = 24, 320, 260

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function GetColor(key) return function() return unpack(T.db.colors[key]) end end
local function SetColor(key)
	return function(r, g, b) T.db.colors[key] = { r, g, b } end
end
local function Pct(v) return floor(v * 100 + 0.5) .. "%" end
local function Px(v) return v .. " px" end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Anchoring() return T.db.enabled end
local function Theming() return T.db.theme end
local function CustomBg() return T.db.customBg end

-- Preview samples use Blizzard's tooltip template and the same styling code as real tooltips.

local SAMPLE_H, BAR_H = 48, 8

local function Sample(parent, width)
	local f = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
	f:SetSize(width, SAMPLE_H)
	-- Field names match a real tooltip's so ns.Dress can style them.
	f.TextLeft1 = f:CreateFontString(nil, "ARTWORK", "GameTooltipHeaderText")
	f.TextLeft1:SetPoint("TOPLEFT", 10, -10)
	f.TextLeft2 = f:CreateFontString(nil, "ARTWORK", "GameTooltipText")
	f.TextLeft2:SetPoint("TOPLEFT", f.TextLeft1, "BOTTOMLEFT", 0, -2)
	return f
end

local function CreatePreview(page)
	local f = CreateFrame("Frame", nil, page)
	f:SetSize(COL, SAMPLE_H * 2 + BAR_H + 9)

	local plain = Sample(f, COL)
	plain:SetPoint("TOPLEFT")
	plain.TextLeft1:SetText("Default tooltip")
	plain.TextLeft1:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	plain.TextLeft2:SetText("Shown when a card can't be.")
	plain.TextLeft2:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

	local unit = Sample(f, COL)
	unit:SetPoint("TOPLEFT", plain, "BOTTOMLEFT", 0, -8)
	unit.TextLeft2:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	unit.StatusBar = CreateFrame("StatusBar", nil, unit)
	unit.StatusBar:SetPoint("TOPLEFT", unit, "BOTTOMLEFT", 2, -1)
	unit.StatusBar:SetPoint("TOPRIGHT", unit, "BOTTOMRIGHT", -2, -1)
	unit.StatusBar:SetHeight(BAR_H)
	unit.StatusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
	unit.StatusBar:SetMinMaxValues(0, 1)
	unit.StatusBar:SetValue(1)

	function f:Refresh()
		ns.Dress(plain)
		unit.TextLeft1:SetText(UnitName("player"))
		unit.TextLeft2:SetText(UNIT_TYPE_LEVEL_TEMPLATE:format(UnitLevel("player"), (UnitClass("player"))))
		-- Default colors first; Dress only overrides what is enabled.
		unit.TextLeft1:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
		unit.StatusBar:SetStatusBarColor(0, 1, 0)
		ns.Dress(unit, "player")
	end
	return f
end

-- A third sample with the danger mark.
local function CreateWarning(page)
	local f = Sample(page, COL)
	f.TextLeft1:SetText("Dangerous mob")
	f.TextLeft2:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	local gap = f:CreateFontString(nil, "ARTWORK", "GameTooltipText")
	gap:SetPoint("BOTTOMRIGHT", -10, 10)
	gap:SetText("+5")

	function f:Refresh()
		self:SetShown(T.db.danger)
		if not T.db.danger then return end
		local color = ns.Warn(self, 2)
		self.TextLeft1:SetTextColor(unpack(T.db.colors.hostile))
		self.TextLeft2:SetText(TOOLTIP_UNIT_LEVEL:format(UI.Wrap(color, tostring(UnitLevel("player") + 5))))
		gap:SetTextColor(color[1], color[2], color[3])
	end
	return f
end

local function PreviewButtons(page, x, y)
	local function Preview(label, unit, yOff)
		local b = At(UI.Button(page, label, COL, function() end), page, x, yOff)
		b:HookScript("OnEnter", function(self)
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			if UnitExists(unit) then GameTooltip:SetUnit(unit)
			else GameTooltip:SetText("Target something first") end
			GameTooltip:Show()
		end)
		b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end
	At(UI.Header(page, "Try it", COL), page, x, y)
	Preview("Hover: you", "player", y - 34)
	Preview("Hover: your target", "target", y - 64)
end

-- Pages

local function PositionPage(page, g)
	At(UI.Header(page, "Behavior", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Anchor tooltips to the cursor", Get("enabled"), Set("enabled"),
		{ desc = "Unit, world and unit frame tooltips appear at your cursor instead of the screen corner." }), page, LEFT, -32)
	At(g:Checkbox(page, "Follow the cursor", Get("follow"), Set("follow"),
		{ desc = "The tooltip moves with your cursor.", enabled = Anchoring }), page, LEFT, -58)
	At(g:Checkbox(page, "Hide instantly", Get("instantHide"), Set("instantHide"),
		{ desc = "The tooltip disappears as soon as your mouse leaves a unit, with no fade." }), page, LEFT, -84)
	At(g:Checkbox(page, "Hide world tooltips in combat", Get("hideInCombat"), Set("hideInCombat"),
		{ desc = "Hides unit and world tooltips in combat. Action bar and bag tooltips still show." }), page, LEFT, -110)
	At(g:Checkbox(page, "Hide on your target", Get("hideOnTarget"), Set("hideOnTarget"),
		{ desc = "No tooltip while your mouse is over what you have targeted. Hovering your target frame still shows it." }), page, LEFT, -136)
	At(g:Checkbox(page, "Emotes in unit menus", Get("emotes"), Set("emotes"),
		{ desc = "Right-clicking a unit frame adds Thank, Wave and the other emotes to its menu." }), page, LEFT, -162)
	At(g:Checkbox(page, "Pings and markers on Shift", Get("strip"), Set("strip"),
		{ desc = "Hold Shift with a target to show pings and raid markers for it. Attack comes first for enemies, Assist for everyone else. Right-click a marker to place it on the ground instead. With ShyDock it has a place of its own by the cooldown manager or your target; move it in layout mode." }),
		page, LEFT, -188)

	At(UI.Header(page, "Placement", COL), page, LEFT, -228)
	At(g:Slider(page, "Horizontal offset", -100, 100, 1, Get("x"), Set("x"),
		{ format = Px, enabled = Anchoring, desc = "Scroll the mouse wheel over a slider for fine steps." }), page, LEFT, -260)
	At(g:Slider(page, "Vertical offset", -100, 100, 1, Get("y"), Set("y"),
		{ format = Px, enabled = Anchoring }), page, LEFT, -306)
	At(g:Slider(page, "Tooltip size", 0.5, 2, 0.05, Get("scale"), Set("scale"),
		{ format = Pct }), page, LEFT, -352)

	At(UI.Header(page, "Corner at cursor", COL), page, RIGHT, 0)
	local grid = At(CreateFrame("Frame", nil, page), page, RIGHT, -34)
	grid:SetSize(3 * 32, 3 * 32)
	local cells = {}
	for i, point in ipairs(ns.POINTS) do
		local c = CreateFrame("Button", nil, grid)
		c:SetSize(28, 28)
		c:SetPoint("TOPLEFT", ((i - 1) % 3) * 32, -floor((i - 1) / 3) * 32)
		c:SetScript("OnClick", function()
			if not T.db.enabled then return end
			T.db.point = point
			g:Changed()
		end)
		c:SetScript("OnEnter", function(self)
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetText((point:lower():gsub("^%l", string.upper)))
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
		-- The family's button make; the picked corner is its primary (Refresh).
		UI.KeyPress(c, { fill = UI.colors.bg })
		cells[point] = c
	end
	g:Add({ Refresh = function()
		for point, c in pairs(cells) do
			UI.SetFill(c, point == T.db.point and UI.colors.fill or UI.colors.bg)
		end
		grid:SetAlpha(T.db.enabled and 1 or 0.4)
	end })
	local hint = UI.Text(page, "The lit square is the corner of the tooltip that sits on your cursor. Hover a square to try it.", 12, false, UI.colors.dim)
	hint:SetWidth(COL - 110)
	At(hint, page, RIGHT + 110, -36)

	PreviewButtons(page, RIGHT, -160)
end

local function ThemePage(page, g)
	At(UI.Header(page, "Unit colors", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Color unit tooltips", Get("theme"), Set("theme"),
		{ desc = "Colors player and NPC tooltips by class or by reaction (enemy, neutral, friendly)." }), page, LEFT, -32)
	At(g:Dropdown(page, "Color by", {
		{ value = "smart",    text = "Class for players, reaction for NPCs" },
		{ value = "reaction", text = "Reaction: enemy, neutral, ally" },
		{ value = "class",    text = "Class only (players)" },
	}, Get("colorBy"), Set("colorBy"), { width = COL, enabled = Theming }), page, LEFT, -60)

	At(UI.Header(page, "Apply to", COL), page, LEFT, -124)
	At(g:Checkbox(page, "Border", Get("colorBorder"), Set("colorBorder"), { enabled = Theming }), page, LEFT, -156)
	At(g:Checkbox(page, "Name", Get("colorName"), Set("colorName"), { enabled = Theming }), page, LEFT + 100, -156)
	At(g:Checkbox(page, "Health bar", Get("colorHealth"), Set("colorHealth"), { enabled = Theming }), page, LEFT, -182)
	At(g:Slider(page, "Background tint", 0, 1, 0.05, Get("bgTint"), Set("bgTint"),
		{ format = Pct, enabled = Theming, desc = "How much of the unit's color shows in the background." }), page, LEFT, -212)
	At(g:Checkbox(page, "Special borders for elites, rares and bosses", Get("specialBorder"), Set("specialBorder"),
		{ enabled = Theming, desc = "Overrides the border color. Pick the colors on the Colors tab." }), page, LEFT, -262)
	At(g:Checkbox(page, "Gray out mobs tapped by others", Get("grayTapped"), Set("grayTapped"),
		{ enabled = Theming }), page, LEFT, -288)
	At(g:Checkbox(page, "Mark dangerous mobs", Get("danger"), Set("danger"),
		{ desc = "Mobs 3 or more levels above you, and elites, rares and bosses you haven't outleveled, get corner brackets and a moving light on the tooltip border. The level turns orange or red, with the level gap beside it." }), page, LEFT, -314)
	At(g:Add(CreateWarning(page)), page, LEFT, -346)

	At(UI.Header(page, "Look", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Replace default tooltips", Get("replace"), Set("replace"),
		{ desc = "Shows tooltips as compact cards. Items, spells and buffs show in full at once; how an item compares to yours drops down after a moment or with Shift. Default tooltips still show for units in combat and dungeons, and for tooltips with a bar or reward inside." }), page, RIGHT, -32)
	At(g:Checkbox(page, "Dark tooltip style", Get("shyLook"), Set("shyLook"),
		{ desc = "Default tooltips get a dark background and steel border. Opacity follows Background in /shy, kept a little darker so text stays readable." }), page, RIGHT, -58)
	At(g:Checkbox(page, "Custom background color", Get("customBg"), Set("customBg"),
		{ desc = "Uses your own color behind default tooltips." }), page, RIGHT, -84)
	At(g:ColorSwatch(page, "Background color", GetColor("background"), SetColor("background"),
		{ enabled = CustomBg }), page, RIGHT + 26, -110)
	At(g:Dropdown(page, "Tooltip font", ns.FONTS, Get("font"), Set("font"),
		{ width = COL, desc = "Font for default tooltips. Names in other alphabets still show. Cards keep their own font." }), page, RIGHT, -138)

	At(g:Add(CreatePreview(page)), page, RIGHT, -204)
	PreviewButtons(page, RIGHT, -330)
end

local function ColorsPage(page, g)
	local function Swatches(title, x, list)
		At(UI.Header(page, title, COL), page, x, 0)
		for i, entry in ipairs(list) do
			At(g:ColorSwatch(page, entry[2], GetColor(entry[1]), SetColor(entry[1]), { enabled = Theming }),
				page, x, -6 - i * 26)
		end
	end
	Swatches("Reactions", LEFT, {
		{ "hostile", "Enemy" }, { "neutral", "Neutral" }, { "friendly", "Friendly" }, { "tapped", "Tapped by others" },
	})
	Swatches("Special units", RIGHT, {
		{ "elite", "Elite" }, { "rare", "Rare" }, { "rareelite", "Rare elite" }, { "worldboss", "Boss" },
	})
	local note = UI.Text(page, "Players use the game's class colors when coloring by class.", 12, false, UI.colors.dim)
	At(note, page, LEFT, -150)
	At(UI.Button(page, "Reset colors", 140, function()
		T.db.colors = Shy.CopyTable(T.defaults.colors)
		g:Changed()
	end), page, LEFT, -176)
end

local function MorePage(page, g)
	At(UI.Header(page, "General", COL), page, LEFT, 0)
	At(UI.Button(page, "Open /shy", COL, function() Shy.Hub.Open("home") end), page, LEFT, -34)
	At(UI.Button(page, "Preview splash", COL, function() B.ShowSplash() end), page, LEFT, -64)

	At(UI.Header(page, "Reset", COL), page, LEFT, -110)
	At(UI.Button(page, "Reset this addon", COL, function()
		T:ResetDB()
		g:Changed()
		T:Print("settings reset.")
	end), page, LEFT, -144)

	At(UI.Header(page, "Commands", COL), page, RIGHT, 0)
	local list = UI.Text(page,
		"|cffffd200/shytip|r  open options\n" ..
		"|cffffd200/shytip toggle|r  cursor anchoring\n" ..
		"|cffffd200/shytip follow|r  follow the cursor\n" ..
		"|cffffd200/shytip fade|r  instant hide\n" ..
		"|cffffd200/shytip replace|r  hover cards\n" ..
		"|cffffd200/shytip look|r  dark tooltip style\n" ..
		"|cffffd200/shytip theme|r  unit colors\n" ..
		"|cffffd200/shytip danger|r  danger mark\n" ..
		"|cffffd200/shytip anchor|r  <corner>\n" ..
		"|cffffd200/shytip offset|r  <x> <y>\n" ..
		"|cffffd200/shytip reset|r  reset all options", 13)
	list:SetSpacing(5)
	At(list, page, RIGHT, -32)
end

-- Panel

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)

	local function Build()
		UI.PageHeader(panel, T)

		local pages = {}
		local tabs = UI.Tabs(panel, { "Position", "Theme", "Colors", "More" }, function(i)
			for j, p in ipairs(pages) do p:SetShown(i == j) end
		end, 580)
		tabs:SetPoint("TOPLEFT", 24, -112)

		for i, build in ipairs({ PositionPage, ThemePage, ColorsPage, MorePage }) do
			local page = CreateFrame("Frame", nil, panel)
			page:SetPoint("TOPLEFT", 0, -160)
			page:SetPoint("BOTTOMRIGHT")
			build(page, group)
			pages[i] = page
		end
		tabs:Select(1)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
	end)

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
		group:Refresh()
	end

	ns.RefreshOptions = function() if panel.built then group:Refresh() end end
	return panel
end
