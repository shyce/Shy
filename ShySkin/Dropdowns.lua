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
-- Switched off, a menu already open keeps its look until it closes.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local GLYPH = Shy.Skin.GLYPH
local C = UI.colors
local R = UI.MENU_ROW

local FONT, TITLE = 11, 10   -- a row's words and a title's, as UI.Menu's rows and headings
local WASH = 0.2             -- the accent's wash on the row under the mouse, as UI.Menu's
local CARET = 10             -- a submenu's caret
local INSET = { left = 16, top = 10, right = 16, bottom = 10 }   -- a menu style's, if it has none to give
local TICK = "common-dropdown-icon-"   -- the game's art for a chosen mark starts so (its empty box's doesn't)

local M
local houses = setmetatable({}, { __mode = "k" })   -- menu -> our housing round its rows

local function On()
	return M and M.on
end

-- The inset the menu stands its rows at: a place in a row is the menu's less its left.
local function Inset(menu)
	local inset = menu and menu.GetInset and menu:GetInset()
	return type(inset) == "table" and inset or INSET
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
		menu = row and row.GetElementDescription and row:GetParent() or nil
	end
end

-- The glyphs that dropdown's rows wear (ns.Dropdown's `icons`), if it is one of ours.
local function Icons(menu)
	return ns.DropdownIcons(Dropdown(menu))
end

-- A row's places, counted from its own left (the menu's edge less the inset): the rail's middle, where its words
-- start, where the rail ends. The rail is wider in a menu whose rows wear glyphs, as UI.Menu's.
local function Places(frame)
	local menu = frame:GetParent()
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
	local icons = Icons(frame:GetParent())
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

-- A rule of the border's color from the rail to the row's end, a unit tall.
local function Divider(frame)
	local edge, x = C.border, select(3, Places(frame))
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetColorTexture(edge[1], edge[2], edge[3], 0.9)
			region:SetHeight(1)
			region:ClearAllPoints()
			region:SetPoint("LEFT", frame, "LEFT", x, 0)
			region:SetPoint("RIGHT", frame, "RIGHT")
		end
	end
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

-- The row under the mouse, lit as ours: the fill lifted, an accent wash fading to the right, from the housing's
-- edge to its edge (rail included). A disabled row, a title and a divider stay unlit.
local function Hover(house)
	local menu = house:GetParent()
	local over
	for _, child in ipairs({ menu:GetChildren() }) do
		if child ~= house and child.GetElementDescription and child:IsObjectType("Button") and child:IsShown()
			and child:IsEnabled() and child:IsMouseOver() then
			over = child
			break
		end
	end
	local lit = house.lit
	if not over then
		lit.fill:Hide()
		lit.wash:Hide()
		return
	end
	local top, bottom, from = over:GetTop(), over:GetBottom(), house:GetTop()
	if not (top and bottom and from) then return end
	for _, t in ipairs({ lit.fill, lit.wash }) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", house, "TOPLEFT", R.edge, top - from)
		t:SetPoint("BOTTOMRIGHT", house, "TOPRIGHT", -R.edge, bottom - from)
		t:Show()
	end
end

local function Light(house)
	local wash = house.lit.wash
	local r, g, b = Theme.Accent()
	wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, WASH), CreateColor(r, g, b, 0))
end

-- The housing, fitted round the rows: R.pad and the edge over the first and under the last, the rows' tail past
-- their end, the rail from the edge. A frame of ours a level over the menu's own (its background faded under it)
-- and under the rows (the game stands them 20 over it).
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
		house:SetScript("OnUpdate", Hover)
		houses[menu] = house
	end
	-- The rail as wide as the rows were laid out for (wider when they wear glyphs).
	house.rail:SetWidth(Icons(menu) and R.railIcons or R.rail)
	local inset, room = Inset(menu), R.edge + 1
	house:ClearAllPoints()
	house:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -(inset.top - room))
	house:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -(inset.right - R.edge - R.inset), inset.bottom - room)
	house:SetFrameLevel(menu:GetFrameLevel() + 1)
	Light(house)
	Hover(house)
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
	desc = "Restyles the game's own dropdown menus to match the family's: a dark panel with the accent line, lit rows, and the family's checks and fonts.",

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
