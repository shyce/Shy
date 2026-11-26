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
-- straight from the palette (Theme.Paint would keep a pooled piece and repaint it wherever it went next).
-- Nothing of ours goes into the game's menus. The game keeps a list of each row's pieces and measures the row
-- from it, and lays a menu out from its children and what is written on them: a piece or a field of ours read
-- there runs the game's menu code as ours, and in a menu holding secret words (a unit's, in an instance) that
-- code then fails. So the housing is a frame of ours beside the menu, not in it: anchored over it at its level
-- (its background faded) and under its rows, fitted round them (the game leaves more room round them than ours).
-- It draws what a row wears of ours (a divider's rule, a glyph), each on the row's place, and lights the row
-- under the mouse itself (the game's highlight covers only the row, not the rail).
-- What the game keeps secret (a row's place or state, in such a menu) is never compared or truth-tested. The row
-- under the mouse is the one the game shows its own highlight on (left unseen), and the light is anchored to it.
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
local houses = setmetatable({}, { __mode = "k" })     -- menu -> our housing over it
local chosen = setmetatable({}, { __mode = "k" })     -- a plain row -> whether the game drew it chosen
local worn = setmetatable({}, { __mode = "k" })       -- a row -> the glyph it wears
local dividers = setmetatable({}, { __mode = "k" })   -- a divider row -> the game's own piece on it

local function On()
	return M and M.on
end

-- A value read from the game, or nil where it is secret.
local function Known(v)
	if issecretvalue(v) then return nil end
	return v
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

-- The glyph a row wears on the rail's middle, when its dropdown gives one for its words (or its data): kept for
-- the housing to draw. Returns its name.
local function Wear(frame, words)
	dividers[frame] = nil
	local icons = Icons(MenuOf(frame))
	local name
	if icons then
		local description = frame.GetElementDescription and frame:GetElementDescription()
		if not words and description then words = MenuUtil.GetElementText(description) end
		name = UI.MenuIcon(icons, words, description)
	end
	worn[frame] = name
	return name
end

-- A row's words, and a button's glyph.
local function Row(frame)
	Words(frame)
	if frame:IsObjectType("Button") then
		Wear(frame)
	else
		worn[frame], dividers[frame] = nil, nil
	end
end

-- The game's highlight is left unseen: the housing lights the row it shows on, across the whole menu (Lit).
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
	local glyph = Wear(frame, words)
	local mark, tick = frame.leftTexture1, frame.leftTexture2
	if not mark then return end
	local on = Chosen(mark, tick)
	local light = Theme.light
	mark:SetTexture(GLYPH.tick)
	mark:SetTexCoord(0, 1, 0, 1)
	mark:SetSize(R.check, R.check)
	mark:ClearAllPoints()
	if glyph and frame.fontString then
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
-- has a size, and the row measures from it alone: as tall as our menu's divider. The housing fades it and draws
-- our rule over it (Rule).
local function Divider(frame)
	worn[frame] = nil
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetHeight(R.rule)
			dividers[frame] = region
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

local function Near(r, g, b, color)
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then return false end
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
	local ink = Known(row:IsEnabled()) == false and C.dim or C.text
	local r, g, b = text:GetTextColor()
	if not Near(r, g, b, ink) then text:SetTextColor(ink[1], ink[2], ink[3]) end
	if Known(row.HighlightBGTex:GetAlpha()) ~= 0 then row.HighlightBGTex:SetAlpha(0) end
end

-- The scroll box of a menu that scrolls, while it does.
local function Box(menu)
	local box = rawget(menu, "ScrollBox")
	return box and Known(box:IsShown()) and box or nil
end

-- The menu's rows in sight: its own, or while it scrolls, those the scroll box's view holds.
local function Rows(menu)
	local rows = {}
	local function Take(...)
		for i = 1, select("#", ...) do
			local row = select(i, ...)
			if row.GetElementDescription and Known(row:IsVisible()) then rows[#rows + 1] = row end
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
	local top, bottom, from = Known(row:GetTop()), Known(row:GetBottom()), Known(house:GetTop())
	if not (top and bottom and from) then return t:Hide() end
	local box = Box(house.menu)
	local high, low = box and Known(box:GetTop()), box and Known(box:GetBottom())
	if box and not (high and low) then return t:Hide() end
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

-- The light across the row under the mouse, from the housing's edge to its edge. Anchored to the row itself, so
-- nothing of its place is read (in a unit's menu it is secret); in a menu that scrolls, kept inside the box.
local function Over(house, t, row)
	local menu = house.menu
	if Box(menu) then return Across(house, t, row, R.edge, true) end
	local inset = Inset(menu)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", row, "TOPLEFT", R.edge - inset.left, 0)
	t:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", R.inset, 0)
	t:Show()
end

-- Whether the mouse is on a row the housing lights: the game shows its highlight there (a row it makes from its
-- pieces), or the mouse is over it (an options row). A disabled row and a title stay unlit.
local function Lit(row)
	if not row:IsObjectType("Button") or Known(row:IsEnabled()) == false then return false end
	local highlight = row.highlight
	if highlight and Known(highlight:GetParent()) == row then return Known(highlight:IsShown()) == true end
	return Known(row:IsMouseOver()) == true
end

-- Whether a row is in sight: always in a menu that doesn't scroll; in one that does, while its middle is in the
-- box (and its place can be read).
local function InSight(house, row)
	local box = Box(house.menu)
	if not box then return true end
	local top, bottom = Known(row:GetTop()), Known(row:GetBottom())
	local high, low = Known(box:GetTop()), Known(box:GetBottom())
	if not (top and bottom and high and low) then return false end
	local mid = (top + bottom) / 2
	return mid <= high and mid >= low
end

-- The housing's i-th texture of a kind ("rules", "glyphs"), made on first need.
local function Piece(house, kind, i)
	local list = house[kind]
	local t = list[i]
	if not t then
		t = house:CreateTexture(nil, "ARTWORK")
		list[i] = t
	end
	return t
end

-- The ones past the n in use go.
local function Rest(list, n)
	for i = n + 1, #list do
		list[i]:Hide()
		list[i].row = nil
	end
end

-- A divider's rule: a unit tall in the border's color, from the rail to the row's end, on the row's middle.
local function Rule(house, i, row)
	local t = Piece(house, "rules", i)
	if t.row ~= row then
		local edge = C.border
		t:SetColorTexture(edge[1], edge[2], edge[3], 0.9)
		t:SetHeight(1)
		t:ClearAllPoints()
		t:SetPoint("LEFT", row, "LEFT", (select(3, Places(row))), 0)
		t:SetPoint("RIGHT", row, "RIGHT")
		t.row = row
	end
	t:SetShown(InSight(house, row))
end

-- A row's glyph on the rail's middle.
local function Glyph(house, i, row, name)
	local t = Piece(house, "glyphs", i)
	if t.row ~= row or t.name ~= name then
		local layer = UI.MenuGlyph(name)[1]
		t:SetTexture(layer[1])
		t:SetTexCoord(unpack(layer.coords))
		t:SetSize(R.icon, R.icon)
		t:SetVertexColor(layer[2][1], layer[2][2], layer[2][3])
		t:ClearAllPoints()
		t:SetPoint("CENTER", row, "LEFT", (Places(row)), 0)
		t.row, t.name = row, name
	end
	t:SetShown(InSight(house, row))
end

-- The housing watching its menu: the plain rows dressed (Plain), dividers and glyphs drawn, the chosen one's
-- check on the rail, and the row under the mouse lit as ours: the fill lifted, an accent wash fading to the
-- right, from the housing's edge to its edge (rail included). A disabled row, a title and a divider stay unlit.
local function Watch(house)
	local menu = house.menu
	if Known(menu:IsShown()) == false then return house:Hide() end
	local over, mark
	local rules, glyphs = 0, 0
	for _, row in ipairs(Rows(menu)) do
		if row.frameTemplateOrFrameType == PLAIN and row.Text and row.HighlightBGTex then
			Plain(row)
			if chosen[row] then mark = row end
		end
		if not over and Lit(row) then over = row end
		local piece = dividers[row]
		if piece and Known(piece:GetParent()) == row then
			piece:SetAlpha(0)
			rules = rules + 1
			Rule(house, rules, row)
		end
		local name = worn[row]
		if name then
			glyphs = glyphs + 1
			Glyph(house, glyphs, row, name)
		end
	end
	Rest(house.rules, rules)
	Rest(house.glyphs, glyphs)
	local lit = house.lit
	for _, t in ipairs({ lit.fill, lit.wash }) do
		if over then Over(house, t, over) else t:Hide() end
	end
	if mark then Across(house, house.tick, mark, R.edge + house.rail:GetWidth() / 2) else house.tick:Hide() end
end

local function Light(house)
	local wash = house.lit.wash
	local r, g, b = Theme.Accent()
	wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, WASH), CreateColor(r, g, b, 0))
end

-- The housing, fitted round the rows: R.pad and the edge over the first and under the last, the rows' tail past
-- their end, the rail from the edge. A frame of ours beside the menu, in its strata at its own level (its
-- background faded) and under the rows (the game stands them 20 over it). In a menu that scrolls, the box and
-- its bar stand a level over the menu, so they stay over the housing; the bar wears ours.
local function House(menu)
	local house = houses[menu]
	if not On() then
		if house then house:Hide() end
		return
	end
	if not house then
		house = CreateFrame("Frame")
		house.menu = menu
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
		house.rules, house.glyphs = {}, {}
		house:SetScript("OnUpdate", Watch)
		houses[menu] = house
	end
	-- Beside the menu, as it stands now (a pooled menu can open under another parent, strata or scale): under the
	-- same parent (the game's menus have none) and drawn at the menu's size on screen, so its rail and the rows'
	-- checks and rules line up.
	local parent = Known(menu:GetParent())
	house:SetParent(parent)
	house:SetFrameStrata(Known(menu:GetFrameStrata()) or "FULLSCREEN_DIALOG")
	local seen, under = Known(menu:GetEffectiveScale()), parent and Known(parent:GetEffectiveScale()) or 1
	house:SetScale(seen and under and under > 0 and seen / under or Known(menu:GetScale()) or 1)
	local level = Known(menu:GetFrameLevel())
	if level then house:SetFrameLevel(level) end
	-- The rail as wide as the rows were laid out for (wider when they wear glyphs).
	house.rail:SetWidth(Icons(menu) and R.railIcons or R.rail)
	local light = Theme.light
	house.tick:SetVertexColor(light[1], light[2], light[3])
	-- Rules and glyphs placed again (the rows, the rail or the palette may have changed).
	Rest(house.rules, 0)
	Rest(house.glyphs, 0)
	local inset, room = Inset(menu), R.edge + 1
	house:ClearAllPoints()
	house:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -(inset.top - room))
	house:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -(inset.right - R.edge - R.inset), inset.bottom - room)
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
		EventRegistry:RegisterCallback("MenuProxy.OnHide", function(_, menu)
			local house = houses[menu]
			if house then house:Hide() end
		end, M)
	end,

	-- A menu open as the module is painted (again) is housed at once; the rest as they open.
	Paint = function()
		for menu in pairs(houses) do
			if Known(menu:IsShown()) then House(menu) end
		end
	end,

	Clear = function()
		-- A menu open now: its own background and dividers back, ours gone (Paint houses it again when this is a
		-- repaint).
		for menu, house in pairs(houses) do
			house:Hide()
			if Known(menu:IsShown()) then
				for _, region in ipairs({ menu:GetRegions() }) do region:SetAlpha(1) end
				for _, row in ipairs(Rows(menu)) do
					local piece = dividers[row]
					if piece then piece:SetAlpha(1) end
				end
			end
		end
	end,
})
