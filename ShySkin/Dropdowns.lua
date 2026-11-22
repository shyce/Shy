-- The game's own dropdown menus (Blizzard_Menu) in the family's make, laid out as ours are (UI.Menu): the housing
-- every menu wears (UI.MenuHousing) round the rows, its dark rail down the left holding each row's check, the
-- words past the rail, the row under the mouse lit across the whole menu, the family's font, check and caret.
-- One system with ns.Dropdown (Widgets.lua): a dropdown whose picks nothing reads back in a fight opens our
-- own menu (`ours`, UI.GameMenu); every other one opens the game's, and this is how it looks (the damage
-- meter's, Edit Mode's, the unit menus, any dropdown no module dresses).
-- A menu is put together as it opens, from pooled pieces, inside the game's secure calls, and a row is put
-- together again when it is picked. So each piece is dressed and placed as it is made, by a post-hook on the
-- function that makes it (MenuVariants: a row's words, its highlight, a check or radio, a divider, a submenu
-- arrow), before the menu measures its rows from them: a hook never taints its caller, and the rows come out
-- as wide as our layout needs (our font is narrower than the game's). The pieces go back to the game's pools,
-- which set them to their defaults, so nothing of ours stays on a piece another menu takes; their colors come
-- straight from the palette (Theme.Paint would keep a pooled piece and repaint it wherever it went next). A
-- menu's own frame takes no textures (the game's compositor refuses them), so the housing is a frame of ours
-- over the menu's background (faded) and under its rows, fitted round the rows (the game leaves more room
-- round them than ours), and it lights the row under the mouse itself (the game's highlight covers only the
-- row, not the rail).
-- A row's places are counted from the menu's edge as ours are: the rows start the menu's inset in (its style's
-- GetInset), so a place in a row is the menu's less that.
-- The options dropdowns (the game's settings) make their rows from a template of their own, with none of those
-- pieces: words only, the chosen row's in gold. The housing dresses those as it watches the menu (Plain).
-- Switched off, a menu already open keeps its look until it closes.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local GLYPH = Shy.Skin.GLYPH
local C = UI.colors
local R = UI.MENU_ROW
local abs, min, max = math.abs, math.min, math.max

local FONT, TITLE = 11, 10   -- a row's words and a title's, as UI.Menu's rows and headings
local WASH = 0.2             -- the accent's wash on the row under the mouse, as UI.Menu's
local CARET = 10             -- a submenu's caret
local INSET = { left = 16, top = 10, right = 16, bottom = 10 }   -- a menu style's, if it has none to give
local TICK = "common-dropdown-icon-"   -- the game's art for a chosen mark starts so (its empty box's doesn't)
local PLAIN = "WowMenuDropdownHighlightButtonTemplate"   -- the options dropdowns' rows: words only

local M
local houses = setmetatable({}, { __mode = "k" })   -- menu -> our housing round its rows
local chosen = setmetatable({}, { __mode = "k" })   -- a plain row -> whether the game drew it chosen

local function On()
	return M and M.on
end

-- The inset the menu stands its rows at: a place in a row is the menu's less its left.
local function Inset(menu)
	local inset = menu and menu.GetInset and menu:GetInset()
	return type(inset) == "table" and inset or INSET
end

-- The menu a row stands in: its parent, or in a menu that scrolls, the menu round the scroll box holding it.
local function MenuOf(row)
	local parent = row:GetParent()
	local menu = parent
	for _ = 1, 4 do
		if not menu or menu.isMenuProxy then break end
		menu = menu:GetParent()
	end
	return menu and menu.isMenuProxy and menu or parent
end

-- The game's dropdown a menu was opened from: a root menu's owner; a submenu's through the row it hangs from (it
-- is anchored to that row before its own rows are made).
local function Dropdown(menu)
	for _ = 1, 8 do
		if not menu then return nil end
		local owner = menu.GetOwnerRegion and menu:GetOwnerRegion()
		if type(owner) ~= "table" then owner = nil end
		if owner and not owner.GetElementDescription then return owner end
		local row = owner or select(2, menu:GetPoint(1))
		menu = row and row.GetElementDescription and MenuOf(row) or nil
	end
end

-- The glyphs that dropdown's rows wear (ns.Dropdown's `icons`), if it is one of ours.
local function Icons(menu)
	return ns.DropdownIcons(Dropdown(menu))
end

-- A row's places, counted from its own left (the menu's edge less the inset): the rail's middle, where its words
-- start, where the rail ends. The rail is wider in a menu whose rows wear glyphs, as UI.Menu's.
local function Places(frame)
	local menu = MenuOf(frame)
	local left, rail = Inset(menu).left, Icons(menu) and R.railIcons or R.rail
	return R.edge + rail / 2 - left, R.edge + rail + R.inset - left, R.edge + rail - left
end

-- Every font string on a row in the family's font (a title's dim and smaller), its words starting past the
-- rail: set as the piece is made, before the row is measured and given its words and any color of its own.
local function Words(frame)
	local title = not frame:IsObjectType("Button")
	local ink, _, x = title and C.dim or C.text, Places(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") then
			region:SetFontObject(UI.NameFont(title and TITLE or FONT))
			region:SetTextColor(ink[1], ink[2], ink[3])
			region:ClearAllPoints()
			region:SetPoint("LEFT", frame, "LEFT", x, 0)
		end
	end
end

-- The row's glyph on the rail's middle, when its dropdown gives one for its words (or its data); a piece of the
-- row's own (the compositor's), so it goes back to the game's pool with the row. Returns it.
local function Icon(frame, words)
	local icons = Icons(MenuOf(frame))
	if not icons then return nil end
	local description = frame.GetElementDescription and frame:GetElementDescription()
	if not words and description then words = MenuUtil.GetElementText(description) end
	local name = UI.MenuIcon(icons, words, description)
	if not name then return nil end
	local layer = UI.MenuGlyph(name)[1]
	local t = frame:AttachTexture()
	t:SetTexture(layer[1])
	t:SetTexCoord(unpack(layer.coords))
	t:SetSize(R.icon, R.icon)
	t:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
	t:SetPoint("CENTER", frame, "LEFT", (Places(frame)), 0)
	return t
end

-- A row's words, and a button's glyph.
local function Row(frame)
	Words(frame)
	if frame:IsObjectType("Button") then Icon(frame) end
end

-- The game's highlight goes: the housing lights the row under the mouse across the whole menu (Hover).
local function Highlight(frame)
	local t = frame.highlight
	if t then t:SetColorTexture(0, 0, 0, 0) end
end

-- Whether the game drew a row's mark as chosen: a tick over the box, or, where the mark is one texture, the
-- tick's art in it. Read from what the game made and never asked of the row again: a row's answer can come
-- from something only the game may read in a fight (a unit's raid marker), and asking it from here is an error.
local function Chosen(mark, tick)
	if tick then return true end
	local atlas = mark:GetAtlas()
	if issecretvalue(atlas) or type(atlas) ~= "string" then return false end
	return atlas:find(TICK, 1, true) == 1
end

-- A check or radio: our check while chosen, nothing while not, as UI.Menu's rows: on the rail's middle, or after
-- the words when the rail holds the row's glyph. The game makes the mark in one texture or two (a box and a tick
-- over it); the first becomes ours, the second goes.
local function Mark(words, frame)
	Words(frame)
	local mark, tick = frame.leftTexture1, frame.leftTexture2
	if not mark then return end
	local on = Chosen(mark, tick)
	local light = Theme.light
	mark:SetTexture(GLYPH.tick)
	mark:SetTexCoord(0, 1, 0, 1)
	mark:SetSize(R.check, R.check)
	mark:ClearAllPoints()
	if Icon(frame, words) and frame.fontString then
		mark:SetPoint("LEFT", frame.fontString, "RIGHT", R.gap, 0)
	else
		mark:SetPoint("CENTER", frame, "LEFT", (Places(frame)), 0)
	end
	mark:SetVertexColor(light[1], light[2], light[3])
	mark:SetAlpha(on and 1 or 0)
	if tick then tick:SetAlpha(0) end
end

-- A divider row is measured from its pieces on a row the game first makes a pixel wide (and does so again each
-- time the menu is refreshed). So the game's own piece keeps its place across the row's ends, where it always
-- has a size, and the row measures from it alone: cleared, as tall as our menu's divider. The rule is a piece
-- of ours over it, a unit tall in the border's color, from the rail to the row's end: on that pixel-wide row its
-- ends cross and it has no size, so it never counts. Measured from the rule alone, the row would have no size,
-- and every row under it would lose its place (the menu then stretches to the corner of the screen).
local function Divider(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetColorTexture(0, 0, 0, 0)
			region:SetHeight(R.rule)
		end
	end
	local edge, x = C.border, select(3, Places(frame))
	local rule = frame:AttachTexture()
	rule:SetColorTexture(edge[1], edge[2], edge[3], 0.9)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", frame, "LEFT", x, 0)
	rule:SetPoint("RIGHT", frame, "RIGHT")
end

-- A submenu's arrow: our caret turned to point at it, dim.
local function Arrow(frame)
	local t = frame.arrow
	if not t then return end
	local dim = C.dim
	t:SetTexture(GLYPH.caret)
	t:SetSize(CARET, CARET)
	t:SetRotation(math.pi / 2)
	t:SetVertexColor(dim[1], dim[2], dim[3])
end

local function Near(r, g, b, color)
	return abs(r - color[1]) < 0.02 and abs(g - color[2]) < 0.02 and abs(b - color[3]) < 0.02
end

-- A plain row (the options dropdowns'): its words in our font and ink, starting past the rail, and no wash of the
-- game's under the mouse. Its words are put in by the template's own code, so this runs as the housing watches:
-- in full when the game has put the row together (again), its words back in the game's font. Whether it is
-- chosen is read then, from the game's gold, before our ink covers it.
local function Plain(row)
	local text, font = row.Text, UI.NameFont(FONT)
	if text:GetFontObject() ~= font then
		local r, g, b = text:GetTextColor()
		chosen[row] = Near(r, g, b, { NORMAL_FONT_COLOR:GetRGB() })
		text:SetFontObject(font)
		text:ClearAllPoints()
		text:SetPoint("LEFT", row, "LEFT", select(2, Places(row)), 0)
	end
	-- The game inks the words again as the mouse comes and goes.
	local ink, r, g, b = row:IsEnabled() and C.text or C.dim, text:GetTextColor()
	if not Near(r, g, b, ink) then text:SetTextColor(ink[1], ink[2], ink[3]) end
	if row.HighlightBGTex:GetAlpha() > 0 then row.HighlightBGTex:SetAlpha(0) end
end

-- The scroll box of a menu that scrolls, while it does.
local function Box(menu)
	local box = rawget(menu, "ScrollBox")
	return box and box:IsShown() and box or nil
end

-- The menu's rows in sight: its own, or while it scrolls, those the scroll box's view holds.
local function Rows(menu, house)
	local rows = {}
	local function Take(...)
		for i = 1, select("#", ...) do
			local row = select(i, ...)
			if row ~= house and row.GetElementDescription and row:IsVisible() then rows[#rows + 1] = row end
		end
	end
	Take(menu:GetChildren())
	local box = Box(menu)
	if box then
		for _, holder in ipairs({ box:GetScrollTarget():GetChildren() }) do Take(holder:GetChildren()) end
	end
	return rows
end

-- Stands a texture of the housing's across a row's height: from x to the housing's edge, or (no width) centered
-- at x. In a menu that scrolls, only what is in the box's sight: a row half out is lit only up to its edge.
local function Across(house, t, row, x, wide)
	local top, bottom, from = row:GetTop(), row:GetBottom(), house:GetTop()
	if not (top and bottom and from) then return t:Hide() end
	local box = Box(house:GetParent())
	local high, low = box and box:GetTop(), box and box:GetBottom()
	t:ClearAllPoints()
	if wide then
		if high and low then top, bottom = min(top, high), max(bottom, low) end
		if top <= bottom then return t:Hide() end
		t:SetPoint("TOPLEFT", house, "TOPLEFT", x, top - from)
		t:SetPoint("BOTTOMRIGHT", house, "TOPRIGHT", -x, bottom - from)
	else
		local mid = (top + bottom) / 2
		if high and low and (mid > high or mid < low) then return t:Hide() end
		t:SetPoint("CENTER", house, "TOPLEFT", x, mid - from)
	end
	t:Show()
end

-- The housing watching its menu: the plain rows dressed (Plain), the chosen one's check on the rail, and the row
-- under the mouse lit as ours: the fill lifted, an accent wash fading to the right, from the housing's edge to its
-- edge (rail included). A disabled row, a title and a divider stay unlit.
local function Watch(house)
	local over, mark
	for _, row in ipairs(Rows(house:GetParent(), house)) do
		if row.frameTemplateOrFrameType == PLAIN and row.Text and row.HighlightBGTex then
			Plain(row)
			if chosen[row] then mark = row end
		end
		if not over and row:IsObjectType("Button") and row:IsEnabled() and row:IsMouseOver() then over = row end
	end
	local lit = house.lit
	for _, t in ipairs({ lit.fill, lit.wash }) do
		if over then Across(house, t, over, R.edge, true) else t:Hide() end
	end
	if mark then Across(house, house.tick, mark, R.edge + house.rail:GetWidth() / 2) else house.tick:Hide() end
end

local function Light(house)
	local wash = house.lit.wash
	local r, g, b = Theme.Accent()
	wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, WASH), CreateColor(r, g, b, 0))
end

-- The housing, fitted round the rows: R.pad and the edge over the first and under the last, the rows' tail past
-- their end, the rail from the edge. A frame of ours at the menu's own level (its background faded) and under
-- the rows (the game stands them 20 over it). In a menu that scrolls, the box and its bar stand a level over the
-- menu, so they stay over the housing; the bar wears ours.
local function House(menu)
	local house = houses[menu]
	if not On() then
		if house then house:Hide() end
		return
	end
	if not house then
		house = CreateFrame("Frame", nil, menu)
		-- The menu sizes itself round its children (a ResizeLayoutFrame): fitted to the menu, the housing would
		-- widen it at each layout, and itself with it, until it filled the screen.
		house.ignoreInLayout = true
		local parts = UI.MenuHousing(house)
		parts.accent:SetPoint("TOPLEFT", R.edge, -R.edge)
		parts.accent:SetPoint("BOTTOMLEFT", R.edge, R.edge)
		local fill = house:CreateTexture(nil, "BORDER", nil, 0)
		Theme.Paint(fill, C.bgHot, 1)
		local wash = house:CreateTexture(nil, "BORDER", nil, 1)
		wash:SetColorTexture(1, 1, 1, 1)
		house.lit = { fill = fill, wash = wash }
		house.rail = parts.rail
		local tick = house:CreateTexture(nil, "ARTWORK")
		tick:SetTexture(GLYPH.tick)
		tick:SetSize(R.check, R.check)
		house.tick = tick
		house:SetScript("OnUpdate", Watch)
		houses[menu] = house
	end
	-- The rail as wide as the rows were laid out for (wider when they wear glyphs).
	house.rail:SetWidth(Icons(menu) and R.railIcons or R.rail)
	local light = Theme.light
	house.tick:SetVertexColor(light[1], light[2], light[3])
	local inset, room = Inset(menu), R.edge + 1
	house:ClearAllPoints()
	house:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -(inset.top - room))
	house:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -(inset.right - R.edge - R.inset), inset.bottom - room)
	house:SetFrameLevel(menu:GetFrameLevel())
	local bar = rawget(menu, "ScrollBar")
	if bar and bar.Track and bar.Track.Thumb then ns.ScrollBar(M.kit, bar) end
	Light(house)
	Watch(house)
	house:Show()
	for _, region in ipairs({ menu:GetRegions() }) do region:SetAlpha(0) end
end

-- name -> how that piece is dressed. Each is a post-hook on MenuVariants' function of that name.
local PIECES = {
	CreateFontString = Row,
	CreateHighlight = Highlight,
	CreateCheckbox = Mark,
	CreateRadio = Mark,
	CreateDivider = Divider,
	CreateSubmenuArrow = Arrow,
}

M = ns.Module({
	id = "dropdowns",
	title = "Dropdown menus",
	desc = "The game's dropdown menus get a dark panel, lit rows and the same checks and font as the rest.",
	group = "window",
	words = "right-click context",

	Hook = function()
		for name, dress in pairs(PIECES) do
			if MenuVariants[name] then
				hooksecurefunc(MenuVariants, name, function(...)
					if On() then
						-- CreateCheckbox and CreateRadio are told the row's words first; the others, the row.
						if name == "CreateCheckbox" or name == "CreateRadio" then dress(...) else dress((...)) end
					end
				end)
			end
		end
		EventRegistry:RegisterCallback("MenuProxy.OnShow", function(_, menu) House(menu) end, M)
	end,

	-- A menu open as the module is painted (again) is housed at once; the rest as they open.
	Paint = function()
		for menu in pairs(houses) do
			if menu:IsShown() then House(menu) end
		end
	end,

	Clear = function()
		-- A menu open now: its own background back, ours gone (Paint houses it again when this is a repaint).
		for menu, house in pairs(houses) do
			house:Hide()
			if menu:IsShown() then
				for _, region in ipairs({ menu:GetRegions() }) do region:SetAlpha(1) end
			end
		end
	end,
})
