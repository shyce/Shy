-- The talent window (PlayerSpellsFrame.TalentsFrame, in load-on-demand Blizzard_PlayerSpells), painted by the
-- "spells" module in Spellbook.lua while the talent window is ours (the game's is left for another player's talents).
-- With "Game's talent window" on, the game's window is its own and this paints nothing. The game's three trees
-- stay, all three at once, closed up: the talents
-- stand on a tighter grid than the game's (its rows and columns 60 apart, the trees 400), the heads just over
-- the first row, the window as small as that makes it. Talents are slots: your color with the icon in full once
-- you hold a rank, green with the icon dimmed while one can still go in, dim while out of reach, with the rank on
-- a plate at the corner; the starter build's suggestion glows gold. Each tree stands on
-- its own painting from the game's class art. The points left stand in the band by the search.
-- Like the vendor and trainer windows, this lays a window of Blizzard's out again: the talent buttons are
-- placed again after the game places them (a post-hook on TalentButtonUtil.ApplyPositionAtOffset), the tree
-- heads after the game stands them, the window and its background are sized to the grid, and the points'
-- display is stood by the search. The arrows hang on the buttons and follow. Nothing is written on a
-- Blizzard frame or table.
--
--   Talents.Hook(m)          once
--   Talents.Paint(m, kit)    while on
--   Talents.Clear(m)         after the module is switched off
--   Talents.Width(), Talents.Height()   the talents' size while on (PlayerSpellsFrame is this plus its rim)

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local Theme = Shy.Theme
local C, SC = UI.colors, Skin.colors

local Talents = {}
ns.Talents = Talents

-- The game's trees stand 4000 node units apart, their first column at 1020 (the third at 1080) and first row
-- at 2130, a column and a row every 600 (TraitNode's PosX and PosY); a node unit is a tenth of a UI unit.
local TREE, FIRST_X, FIRST_Y, STEP = 4000, 1020, 2130, 600
local BUTTON = 40
local COLUMN, ROW = 54, 54         -- our grid's pitch: 14 between two talents, room for a rank plate
local SPAN = 3 * COLUMN + BUTTON   -- a tree's four columns, edge to edge
local MARGIN, GAP = 28, 48         -- the window's edge to a tree's first button; between two trees
local PITCH = SPAN + GAP
local WIDTH = 2 * MARGIN + 3 * SPAN + 2 * GAP
local PANE_OUT = 20                -- a tree's painting reaches this far past its buttons on each side
-- Down from the window's top (the buttons' parent starts there): the painting's top is the game's, 50 down;
-- the head stands 30 under it; the first row's middle 58 under the head's, room for ShyQuest's build flag.
local HEAD_DOWN, FIRST_ROW = 30, 138
local ROWS = 7
local PANE_FOOT = 36               -- the game's painting ends this far over the window's foot (Apply under it)
local HEIGHT = FIRST_ROW + (ROWS - 1) * ROW + BUTTON / 2 + 22 + PANE_FOOT
local HEAD_X = 3                   -- the game's tree head: its icon sits 3 left of its middle
local BORDER = { x = -2, y = 4 }   -- the game's border (its heads' anchor) round the painting: 2 out, 4 up
local RANK_H = 13
local GATE_W = 24
local CONTROL = 20                 -- a search box's and a small button's plate
local ICON = { 0.08, 0.92, 0.08, 0.92 }
local STATE                        -- TalentButtonUtil.BaseVisualState, once loaded

local M
-- The game's window is restyled only while the talent window is ours: with "Game's talent window" on it is the
-- game's own, its art and its animations as made, and your build's next talents are numbered on it (TalentBuild.lua).
local function Styled() return M ~= nil and M.on and M.opt.gameTalents ~= true end
Talents.Styled = Styled
local painted = false              -- Paint has laid the window out, and Clear has not put it back
function Talents.Painted() return painted end
local weak = { __mode = "k" }
local dressed = setmetatable({}, weak)   -- talent button -> its slot and rank plate
local was = {}                           -- the game's sizes: window
local own = {}                           -- our frames: the points in the foot
Talents.own = own                        -- exposed for inspection

local function Window()
	return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

function Talents.Width()
	return WIDTH
end

function Talents.Height()
	return HEIGHT
end

-- Placing the trees

-- Where a node stands on our grid, from the window's top left; nil leaves the game's place.
local function Closed(posX, posY)
	local tree = math.floor(posX / TREE)
	if tree < 0 or tree > 2 then return nil end
	local column = ((posX % TREE) - FIRST_X) / STEP
	local row = (posY - FIRST_Y) / STEP
	if row < -0.5 or row > ROWS - 0.5 then return nil end
	return MARGIN + BUTTON / 2 + tree * PITCH + column * COLUMN, -(FIRST_ROW + row * ROW)
end

-- After the game places a button: the same point, our place. Anchored to the buttons' parent, which is the
-- window's own rect.
local function Place(button, posX, posY)
	if not Styled() then return end
	local window = Window()
	if not window or button:GetTalentFrame() ~= window then return end
	local x, y = Closed(posX, posY)
	if not x then return end
	local point, to, toPoint = button:GetPoint(1)
	if point then button:SetPoint(point, to, toPoint, x, y) end
end

-- The left of tree k's first button, from the window's left.
local function TreeLeft(k)
	return MARGIN + (k - 1) * PITCH
end

-- The tree heads: pooled and stood again each time the points change.
local function StandHeads(window, closed)
	for i, head in ipairs(window.treeHeaders or {}) do
		head:ClearAllPoints()
		if closed then
			-- The head's icon over the tree's first column, HEAD_DOWN under the painting's top.
			head:SetPoint("CENTER", window.BackgroundBorder, "TOPLEFT", TreeLeft(i) + BUTTON / 2 + HEAD_X - BORDER.x,
				-(HEAD_DOWN + BORDER.y))
		else
			head:SetPoint("CENTER", window.BackgroundBorder, "TOPLEFT", 140 + (i - 1) * 400, -100)
		end
	end
end

-- The dual spec's tabs: the game stands them 4 under the border's top. Ours stand on the first tree's
-- painting, the open one's line (along the tab's foot) on the painting's rim, a tab on its page.
local function StandTabs(window, closed)
	local tabs = window.TabSystem
	if not tabs then return end
	tabs:ClearAllPoints()
	tabs:SetPoint("BOTTOMLEFT", window.BackgroundBorder, "TOPLEFT", closed and TreeLeft(1) - PANE_OUT - BORDER.x or 70,
		closed and 1 - BORDER.y or -4)
end

-- The points left, as the Classic window had them: in the foot, left of Apply ("Talent points" and the
-- number on a plate, green while there is one to spend). The game's own display is faded; its SetAmount
-- says the number.
local function Points(window)
	local p = own.points
	if not p then
		p = CreateFrame("Frame", nil, window)
		p:SetSize(1, 22)
		p.label = p:CreateFontString(nil, "OVERLAY")
		UI.TitleFace(p.label, 13)
		p.label:SetPoint("LEFT", 0, 0)
		p.label:SetText("Talent points")
		p.plate = CreateFrame("Frame", nil, p)
		p.plate:SetHeight(RANK_H + 3)
		p.plate:SetPoint("LEFT", p.label, "RIGHT", 7, 0)
		p.number = UI.Words(p.plate, 12)
		p.number:SetPoint("CENTER", 0, 0)
		own.points = p
	end
	p:ClearAllPoints()
	-- On the Apply button's line, left over the first tree's painting.
	p:SetPoint("LEFT", window, "BOTTOMLEFT", MARGIN - PANE_OUT + 2, 19)
	UI.Skin(p.plate, C.panel, C.border)
	UI.Ink(p.label, C.dim)
	return p
end

local function ShowPoints(amount)
	local p = own.points
	if not p then return end
	if issecretvalue(amount) then amount = 0 elseif type(amount) ~= "number" then amount = tonumber(amount) or 0 end
	p.number:SetText(amount)
	p.plate:SetWidth(math.max(24, math.ceil(p.number:GetStringWidth()) + 12))
	local on = amount > 0 and not Window():IsInspecting()
	UI.Ink(p.number, on and C.good or C.dim)
	UI.SetBorder(p.plate, on and C.good or C.border)
end

-- Painting

local function Mask(region)
	return region and region:GetNumMaskTextures() > 0 and region:GetMaskTexture(1) or nil
end

local function Rank(button)
	local d = dressed[button]
	if not d then return end
	local text = button.SpendText and button.SpendText:GetText()
	local info = button.nodeInfo
	if not text or text == "" or not info or issecretvalue(info.maxRanks) then
		d.rank:Hide()
		return
	end
	d.text:SetText(("%d/%d"):format(info.currentRank or 0, info.maxRanks or 0))
	d.rank:SetWidth(math.max(22, math.ceil(d.text:GetStringWidth()) + 8))
	d.rank:Show()
end

-- A state's colors: the slot's mark and the rank's ink and edge. What you hold (some or all ranks) is in your
-- accent with its icon in full color; what you could still take is green with its icon dimmed. Gated, locked and
-- disabled talents are dim.
local function Colors(state)
	if not STATE then return nil end
	if state == STATE.Maxed or state == STATE.Normal then return { Theme.Accent() } end
	if state == STATE.Selectable then return C.good end
	if state == STATE.RefundInvalid or state == STATE.DisplayError then return C.bad end
	return nil
end

local function Ink(button, state)
	local d = dressed[button]
	if not d then return end
	local color = Colors(state)
	local dim = STATE and (state == STATE.Gated or state == STATE.Disabled or state == STATE.Locked or state == STATE.Selectable)
	if color then d.slot:Mark(color[1], color[2], color[3]) else d.slot:Mark() end
	d.slot:Empty(dim)
	local ink = color or C.dim
	d.text:SetTextColor(ink[1], ink[2], ink[3])
	UI.SetBorder(d.rank, color or C.border)
	Rank(button)
end

-- The rank on a plate at the talent's corner, a control of the family's make (UI.Skin, toned by the look) as
-- the points' plate is; its edge in the state's color.
local function RankPlate(button)
	local plate = CreateFrame("Frame", nil, button)
	plate:SetHeight(RANK_H)
	plate:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -5)
	plate:SetFrameLevel(button:GetFrameLevel() + 6)
	UI.Skin(plate, C.panel, C.border)
	local text = UI.Words(plate, 10)
	text:SetPoint("CENTER", 0, 0)
	return plate, text
end

local function DressButton(kit, button)
	local icon = button.Icon
	if not icon then return end
	kit:Hide(button.Shadow)
	kit:Hide(button.StateBorder)
	kit:Hide(button.StateBorderHover)
	kit:Hide(button.SpendText)
	for _, shadow in ipairs(button.spendTextShadows or {}) do kit:Hide(shadow) end
	-- The game sets these two's alpha itself (the sheen by state, the glow by an animation).
	kit:Art(button.BorderSheen, { 0, 0, 0, 0 })
	kit:Art(button.SelectableGlow, { 0, 0, 0, 0 })
	-- The starter build's glow, as the slot's light: gold, never the accent a talent you hold wears.
	if button.Glow then kit:Lit(button.Glow, icon, C.alert) end
	-- A choice node's two halves keep their own masks; a round node's icon is made square.
	if not button.Icon2 then
		kit:Unmask(icon, button.IconMask)
		kit:Unmask(button.DisabledOverlay, button.DisabledOverlayMask)
		kit:Crop(icon, unpack(ICON))
	end
	local slot = kit:Tile(button, { to = icon, icon = icon })
	if button.DisabledOverlay then slot:Clip(button.DisabledOverlay) end
	local d = dressed[button]
	if not d then
		local plate, text = RankPlate(button)
		d = { rank = plate, text = text }
		dressed[button] = d
	end
	d.slot = slot
	d.kit = kit
	Ink(button, button.visualState)
end

-- An arrow's art says its state; it is tinted so: reached in your color, red when a refund breaks it.
local function InkEdge(edge)
	if not Styled() then return end
	local line, head = edge.Line, edge.ArrowHead
	if not line then return end
	local atlas = line:GetAtlas() or ""
	local color, alpha
	if atlas:find("red", 1, true) then color, alpha = C.bad, 1
	elseif atlas:find("yellow", 1, true) then color, alpha = { Theme.Accent() }, 1
	elseif atlas:find("locked", 1, true) then color, alpha = SC.idle, 0.5
	else color, alpha = SC.idle, 0.85 end
	for _, t in ipairs({ line, head }) do
		t:SetDesaturated(true)
		t:SetVertexColor(color[1], color[2], color[3], alpha)
	end
end

local function UninkEdge(edge)
	for _, t in ipairs({ edge.Line, edge.ArrowHead }) do
		if t then
			t:SetDesaturated(false)
			t:SetVertexColor(1, 1, 1, 1)
		end
	end
end

local function DressHead(kit, head)
	kit:Hide(head.MainRing)
	kit:Hide(head.TextBackground)
	kit:Hide(head.Divider)
	kit:Unmask(head.Icon, Mask(head.Icon))
	kit:Crop(head.Icon, unpack(ICON))
	kit:Place(head.Icon, 30, 30, { "CENTER", head, "CENTER", -HEAD_X, 0 })
	kit:Tile(head, { to = head.Icon, icon = head.Icon })
	kit:Text(head.Name, C.head)
	kit:FontObject(head.Name, UI.TitleFont(15))
	kit:Text(head.Name, C.head)
	kit:Place(head.Name, nil, nil, { "LEFT", head.Icon, "RIGHT", 9, 0 })
	-- The points spent, on a plate after the name (ShyQuest's build flag hangs under the name).
	kit:Text(head.Text, C.text)
	kit:Font(head.Text, Shy.FONT_ROUNDED, 11, "")
	kit:Text(head.Text, C.text)
	kit:Place(head.Text, nil, nil, { "LEFT", head.Name, "RIGHT", 10, 0 })
	kit:Justify(head.Text, "CENTER")
	local plate = ns.Own(kit, head, "points", function(o)
		local f = CreateFrame("Frame", nil, o)
		f:SetFrameLevel(o:GetFrameLevel())
		UI.Skin(f, C.panel, C.border)
		return f
	end)
	plate:ClearAllPoints()
	plate:SetPoint("TOPLEFT", head.Text, "TOPLEFT", -5, 3)
	plate:SetPoint("BOTTOMRIGHT", head.Text, "BOTTOMRIGHT", 5, -2)
end

-- The beta's issue reporter hangs its own bug button over the window's title on this tab; the family's
-- reporter (the minimap's) already reports, so it is put away with the window's other spare pieces. It is
-- made as the tab is first set.
local function PutAwayBug()
	local bug = _G["PlayerSpellsFrame.TabSetBugButton"]
	if bug then ns.Shop.PutAway(PlayerSpellsFrame, bug) end
end

local function DressGate(kit, gate)
	if not was[gate] then was[gate] = { gate:GetSize() } end
	gate:SetSize(GATE_W, 20)
	kit:Tint(gate.LockIcon, C.bad)
	kit:Place(gate.LockIcon, 10, 12, { "RIGHT", gate, "RIGHT", -3, 0 })
	kit:Text(gate.GateText, C.bad)
	kit:Font(gate.GateText, Shy.FONT_ROUNDED, 12, "")
	kit:Text(gate.GateText, C.bad)
	kit:Place(gate.GateText, nil, nil, { "RIGHT", gate.LockIcon, "LEFT", -2, 0 })
end

local function UndressGates()
	for gate, size in pairs(was) do
		if type(gate) == "table" and gate.GetObjectType then
			gate:SetSize(size[1], size[2])
			was[gate] = nil
		end
	end
end

-- Each tree's own painting: one third of the class's picture, cut to the tree's width, full height.
local function Panes(kit, window)
	local spec = PlayerSpellsFrame:GetSpecID()
	local visuals = ClassTalentUtil.GetVisualsForSpecID(spec)
	local atlas = visuals and visuals.background
	local info = atlas and C_Texture.GetAtlasInfo(atlas)
	local width = SPAN + 2 * PANE_OUT
	for k = 1, 3 do
		local pane = ns.Own(kit, window, "pane" .. k, function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, 1)
			t:SetPoint("TOP", o.ClassBackground, "TOP")
			t:SetPoint("BOTTOM", o.ClassBackground, "BOTTOM")
			return t
		end)
		pane:SetPoint("LEFT", window, "LEFT", TreeLeft(k) - PANE_OUT, 0)
		pane:SetWidth(width)
		if info and info.file then
			local l, r = info.leftTexCoord, info.rightTexCoord
			local third = (r - l) / 3
			-- The pane is narrower than a third of the picture is for its height: cut evenly from both sides.
			local h = window.ClassBackground:GetHeight()
			local keep = h > 0 and math.min(1, (width / h) / ((info.width / 3) / info.height)) or 0.8
			local cut = (1 - keep) / 2
			pane:SetTexture(info.file)
			pane:SetTexCoord(l + third * (k - 1 + cut), l + third * (k - cut), info.topTexCoord, info.bottomTexCoord)
			pane:SetVertexColor(0.86, 0.86, 0.86)
			pane:Show()
		else
			pane:Hide()
		end
		-- The burn: the pane's top and foot and sides fall away into the window's graphite.
		for i, spec2 in ipairs({ { "TOP", 110, 0.9 }, { "BOTTOM", 90, 0.85 }, { "LEFT", 46, 0.55 }, { "RIGHT", 46, 0.55 } }) do
			local side, size, alpha = spec2[1], spec2[2], spec2[3]
			local burn = ns.Own(kit, window, "burn" .. k .. i, function(o)
				return o:CreateTexture(nil, "BACKGROUND", nil, 2)
			end)
			burn:ClearAllPoints()
			if side == "TOP" or side == "BOTTOM" then
				burn:SetPoint(side .. "LEFT", pane, side .. "LEFT")
				burn:SetPoint(side .. "RIGHT", pane, side .. "RIGHT")
				burn:SetHeight(size)
			else
				burn:SetPoint("TOP" .. side, pane, "TOP" .. side)
				burn:SetPoint("BOTTOM" .. side, pane, "BOTTOM" .. side)
				burn:SetWidth(size)
			end
			local p = C.panel
			burn:SetColorTexture(1, 1, 1, 1)
			local solid, clear = CreateColor(p[1], p[2], p[3], alpha), CreateColor(p[1], p[2], p[3], 0)
			if side == "TOP" then burn:SetGradient("VERTICAL", clear, solid)
			elseif side == "BOTTOM" then burn:SetGradient("VERTICAL", solid, clear)
			elseif side == "LEFT" then burn:SetGradient("HORIZONTAL", solid, clear)
			else burn:SetGradient("HORIZONTAL", clear, solid) end
			burn:SetShown(info ~= nil)
		end
		-- A hairline round the pane: a tree is a page of its own.
		local rim = ns.Own(kit, window, "rim" .. k, function(o)
			local t = o:CreateTexture(nil, "BACKGROUND", nil, 3)
			t:SetTexture(UI.EDGE)
			t:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
			return t
		end)
		rim:ClearAllPoints()
		rim:SetPoint("TOPLEFT", pane, "TOPLEFT", -1, 1)
		rim:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 1, -1)
		rim:SetVertexColor(SC.edge[1], SC.edge[2], SC.edge[3], 0.7)
	end
end

-- The dual spec's tabs in the family's make: the name in the display font, the open one lit by a line of
-- light under its name with a glow rising behind it (the look every tabbed header shares). A tab button
-- swaps its font object by state, so ours are three shared font objects it is given after each change.
local faces

-- A palette color's words as they read on the window's graphite: the theme's own check (Theme.Readable), worn so
-- the face follows the theme.
local function OnPanel(color)
	return function()
		local p = C.panel
		return Theme.Readable(color[1], color[2], color[3], p[1], p[2], p[3], Theme.LC_LABEL)
	end
end

local function Faces()
	if not faces then
		faces = { CreateFont("ShySkinTalentTab"), CreateFont("ShySkinTalentTabOn"), CreateFont("ShySkinTalentTabOff") }
		for _, face in ipairs(faces) do
			face:SetFontObject(UI.TitleFont(13))
			UI.Follow(face)   -- the tabs keep up with the theme's font
		end
		Theme.Ink(faces[1], OnPanel(C.dim))
		Theme.Ink(faces[2], OnPanel(C.text))
		Theme.Ink(faces[3], OnPanel(C.dim), 0.6)
	end
	return faces
end

local fonts = setmetatable({}, weak)   -- tab -> the game's normal, highlight and disabled font objects

local function InkTab(tab)
	local face = Faces()
	if not fonts[tab] then fonts[tab] = { tab:GetNormalFontObject(), tab:GetHighlightFontObject(), tab:GetDisabledFontObject() } end
	-- The open tab is disabled by the game: it reads in the lit face.
	tab:SetNormalFontObject(tab.isSelected and face[2] or face[1])
	tab:SetHighlightFontObject(face[2])
	tab:SetDisabledFontObject(tab.isSelected and face[2] or face[3])
end

local function UninkTabs()
	for tab, saved in pairs(fonts) do
		if saved[1] then tab:SetNormalFontObject(saved[1]) end
		if saved[2] then tab:SetHighlightFontObject(saved[2]) end
		if saved[3] then tab:SetDisabledFontObject(saved[3]) end
		fonts[tab] = nil
	end
end

local function DressTabs(kit, window)
	local tabs = window.TabSystem and window.TabSystem.tabs or {}
	for _, tab in ipairs(tabs) do
		for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
			kit:Hide(tab[key])
		end
		local text = tab.Text
		local line = ns.Own(kit, tab, "line", function(o)
			local t = o:CreateTexture(nil, "ARTWORK")
			t:SetHeight(2)
			return t
		end)
		-- The game sets the words 5 in from each side of the tab: the line spans the tab, no further.
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -5, -5)
		line:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 5, -5)
		UI.Paint(line, Theme.light)
		local glow = ns.Own(kit, tab, "glow", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND")
			t:SetHeight(20)
			t:SetColorTexture(1, 1, 1, 1)
			return t
		end)
		glow:ClearAllPoints()
		glow:SetPoint("BOTTOMLEFT", line, "TOPLEFT")
		glow:SetPoint("BOTTOMRIGHT", line, "TOPRIGHT")
		local r, g, b = Theme.Accent()
		glow:SetGradient("VERTICAL", CreateColor(r, g, b, 0.26), CreateColor(r, g, b, 0))
		line:SetShown(tab.isSelected == true)
		glow:SetShown(tab.isSelected == true)
		InkTab(tab)
	end
end

-- The search's options, row words to their glyph on our menu's rail (UI.MenuGlyph).
local function SearchIcons()
	local icons = {}
	for name, glyph in pairs({ CLASS_TALENT_SEARCH_OPTION_HIDE_PASSIVES = "hide", CLASS_TALENT_SEARCH_OPTION_SHOW_RANKS = "shows" }) do
		local words = rawget(_G, name)
		if words then icons[words] = glyph end
	end
	return icons
end

local function DressChrome(kit, window)
	for _, key in ipairs({ "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight",
		"DividerVerticalLeft", "DividerVerticalRight", "ClassBackground" }) do
		kit:Hide(window[key])
	end
	-- Animated by the game: emptied, not faded.
	kit:Art(window.OverlayBackgroundRight, { 0, 0, 0, 0 })
	kit:Art(window.OverlayBackgroundMid, { 0, 0, 0, 0 })
	kit:Art(window.BackgroundFlash, { 0, 0, 0, 0 })

	-- The game's points display, faded: ours stands in the foot (Points).
	kit:Hide(window.ClassCurrencyDisplay)
	local spec = window.ActiveSpec
	if spec then
		kit:Title(spec.ActiveLabel, 14)
		ns.Button(kit, spec.ActivateButton)
		local glow = spec.ActivateButton.YellowGlow
		if glow then
			for _, key in ipairs({ "Left", "Middle", "Right" }) do kit:Tint(glow[key], C.alert) end
		end
	end
	ns.Button(kit, window.ApplyButton)
	local glow = window.ApplyButton.YellowGlow
	if glow then
		for _, key in ipairs({ "Left", "Middle", "Right" }) do kit:Tint(glow[key], C.alert) end
	end
	for _, button in ipairs({ window.ResetButton, window.UndoButton }) do
		if button then
			kit:Hide(button:GetHighlightTexture())
			kit:Tint(button.Icon, SC.glyph)
			kit:Key(button, { inset = { 1, 1, 1, 1 } })
		end
	end
	-- The search box and its options at the family's control height: the box is 30 tall for Blizzard's art.
	local box = window.SearchBox
	if box then
		local inset = math.max(0, (box:GetHeight() - CONTROL) / 2)
		-- The game's box art reaches past the box's left: the plate does too, and the glass stands inside it.
		ns.SearchBox(kit, box, { 4, -inset })
		kit:Place(box.searchIcon, 10, 10, { "LEFT", box, "LEFT", 2, 0 })
		if box.Instructions then
			kit:Text(box.Instructions, C.dim)
			kit:FontObject(box.Instructions, UI.TextFont(11))
			kit:Text(box.Instructions, C.dim)
		end
	end
	local options = window.SearchOptionsDropdown
	if options then
		-- Square, as tall as the search box's plate, its middle on the box's (the game stands it 2 lower). Its
		-- picks are the search's settings, nothing a fight reads: it opens our menu, the game's rows with our
		-- glyphs on the rail.
		local w, h = options:GetSize()
		local x, y = math.max(0, (w - CONTROL) / 2), math.max(0, (h - CONTROL) / 2)
		ns.Dropdown(kit, options, { look = "key", inset = { x, y - 2, x, y + 2 }, ours = true, icons = SearchIcons() })
	end
	local preview = window.SearchPreviewContainer
	if preview then
		for _, key in ipairs({ "Background", "BorderAnchor", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder" }) do
			kit:Hide(preview[key])
		end
		kit:Plate(preview, { panel = true, brackets = false, looks = false })
	end
	DressTabs(kit, window)
end

-- Every pooled piece as it stands: buttons, arrows, heads, gates.
local function DressAll(kit)
	local window = Window()
	if not window then return end
	for button in window:EnumerateAllTalentButtons() do DressButton(kit, button) end
	if window.edgePool then
		for edge in window.edgePool:EnumerateActive() do InkEdge(edge) end
	end
	for _, head in ipairs(window.treeHeaders or {}) do DressHead(kit, head) end
	if window.gatePool then
		for gate in window.gatePool:EnumerateActive() do DressGate(kit, gate) end
	end
	StandHeads(window, true)
	PutAwayBug()
end

-- The module's parts

function Talents.Hook(m)
	M = m
	local window = Window()
	STATE = TalentButtonUtil.BaseVisualState
	hooksecurefunc(TalentButtonUtil, "ApplyPositionAtOffset", Place)
	hooksecurefunc(TalentButtonArtMixin, "UpdateStateBorder", function(button, state)
		if Styled() and dressed[button] then Ink(button, state) end
	end)
	hooksecurefunc(TalentButtonUtil, "SetSpendText", function(button)
		if Styled() then Rank(button) end
	end)
	hooksecurefunc(TalentEdgeArrowMixin, "UpdateState", InkEdge)
	hooksecurefunc(window, "RefreshTreeHeaders", function(self)
		if not Styled() then return end
		for _, head in ipairs(self.treeHeaders or {}) do DressHead(M.kit, head) end
		StandHeads(self, true)
	end)
	hooksecurefunc(window, "UpdateSpecBackground", function(self)
		if Styled() then Panes(M.kit, self) end
	end)
	for _, tab in ipairs(window.TabSystem and window.TabSystem.tabs or {}) do
		hooksecurefunc(tab, "SetTabSelected", function()
			if Styled() then DressTabs(M.kit, window) end
		end)
	end
	if window.ClassCurrencyDisplay then
		hooksecurefunc(window.ClassCurrencyDisplay, "SetAmount", function(_, amount)
			if Styled() then ShowPoints(amount) end
		end)
	end
	-- The issue reporter's button is made as the tab is set.
	EventRegistry:RegisterCallback("PlayerSpellsFrame.TabSet", function()
		C_Timer.After(0, function() if Styled() then PutAwayBug() end end)
	end, Talents)
	-- New buttons, arrows and gates come from pools as the tree loads.
	EventRegistry:RegisterCallback("TalentFrameBase.ButtonsUpdated", function()
		if Styled() and Window():IsShown() then DressAll(M.kit) end
	end, Talents)
end

-- The talents' own size. Once the window's secure sizers are made (Spellbook.lua) they are protected, and in
-- a fight the size waits for its end; first loaded in a fight, before the sizers, they are sized at once.
local function Resize(window, w, h)
	if math.abs(window:GetWidth() - w) < 0.5 and math.abs(window:GetHeight() - h) < 0.5 then return end
	if InCombatLockdown() and window:IsProtected() then
		ns.AfterCombat("talents:size", function() Resize(window, w, h) end)
		return
	end
	window:SetSize(w, h)
end

function Talents.Paint(m, kit)
	local window = Window()
	painted = true
	if not was.window then was.window = { window:GetSize() } end
	Resize(window, WIDTH, HEIGHT)
	-- The game's background is 20 taller than the window, from its foot; the painting, its border, the tabs and
	-- the search hang from it, so they follow it to the shorter window.
	kit:Place(window.Background, nil, HEIGHT + 20, { "BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0 })
	StandTabs(window, true)
	Points(window):Show()
	local amount = window.ClassCurrencyDisplay and window.ClassCurrencyDisplay.CurrentAmountContainer.CurrencyAmount:GetText()
	ShowPoints(tonumber(amount) or 0)
	DressChrome(kit, window)
	Panes(kit, window)
	DressAll(kit)
	-- The game placed the buttons for its own width: placed again, closed up.
	window:UpdateAllTalentButtonPositions()
	window:UpdateAllGatePositions()
end

function Talents.Clear(m)
	local window = Window()
	painted = false
	if not window then return end
	if was.window then
		Resize(window, was.window[1], was.window[2])
		was.window = nil
	end
	StandTabs(window, false)
	if own.points then own.points:Hide() end
	UndressGates()
	if window.edgePool then
		for edge in window.edgePool:EnumerateActive() do UninkEdge(edge) end
	end
	for _, d in pairs(dressed) do d.rank:Hide() end
	StandHeads(window, false)
	UninkTabs()
	window:UpdateAllTalentButtonPositions()
	window:UpdateAllGatePositions()
end
