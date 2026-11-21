-- The default damage meter (Blizzard_DamageMeter, frame DamageMeter) as a console piece.
-- Windows and bars are created on demand, so painting follows DamageMeter:SetupSessionWindow,
-- window:SetupEntry and breakdown:Refresh.
-- The window never minimizes: its button is faded and mouse-disabled, and a minimized window is
-- restored through DamageMeter:SetSessionWindowMinimized.
-- Blizzard's header is 32 high, so the title strip sits 5 under the window's top (the -TOP in
-- Shy.wings.meter). From the window's top: 0..5 empty, 5..25 strip, 25..27 accent line, 27..34
-- Blizzard's. The words and the three dropdowns stand on the strip's middle, 17 down (PlaceLabels):
-- the type's name and its caret at the left, the timer, the segment and the cog at the right, the cog
-- where the faded minimize button was. Each dropdown is sized round what it shows, in the make of the
-- family's own (Chooser), and keeps the game's click and menu.
-- Blizzard resets the buttons' art on every hover, so it is faded and the glyphs are ours.
-- The panel fill is Blizzard's own background texture: Blizzard fades it to the meter's opacity setting.
-- The timer and type name are placed without the kit: in combat the timer's text is secret, and
-- with it the size and position of everything anchored to it, which the kit would try to read.
-- Nothing is anchored to the timer: it stands at the segment's dropdown and grows leftward.
-- A row clips its contents and Blizzard keeps 2 between rows; each bar gets a face that fills its row.
-- Nothing reads a number or a color off the meter: they are secret in combat.

local ADDON, ns = ...
local UI = Shy.UI
local C = Shy.Skin.colors

local CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"   -- square class icons on one sheet
local CROP = 0.018      -- trims each icon's own rim
local CLEAR = { 0, 0, 0, 0 }
local GLYPH = Shy.Skin.GLYPH
local EDGE = 3          -- solid part of a panel's edge

local STRIP = UI.HEAD_STRIP     -- title strip height
local TOP = 25 - STRIP          -- the piece starts this far under the window's top
local HEAD = TOP + STRIP + UI.LINE   -- where the list's background starts
local HEADER = 32               -- Blizzard's header (DamageMeterSessionWindow.xml)
local TEXT = UI.TITLE_SIZE
local ICON = 24                 -- a bar's icon box (DamageMeterEntry.xml)
local RIM = 1                   -- a bar's inset in its row (DamageMeterEntry.lua, SetupDefaultStyle)
local TIP = 2                   -- width of the bright edge at the end of a fill

local PIECE = { 0, TOP, 0, 0 }   -- the piece's inset in the window
-- How far the piece reaches past the window: { left, top, right, bottom }. Its top is inside.
local WING = { 0, -TOP, 0, 0 }

local hooked = {}   -- windows and bars already hooked
local FaceColor, PaintFace, PaintShadows
local box           -- the meter as a Shy.HUD box

-- Tells ShyDock how far the piece reaches past the frame Edit Mode places.
local function TellDock(on)
	local reach = on and WING or nil
	if Shy.wings.meter == reach then return end
	Shy.wings.meter = reach
	Shy:Fire("SHY_WINGS")
end

-- Header labels are localized: a font family.
local function LabelFont(size)
	return UI.TitleFont(size or TEXT)
end

local function PaintLabel(kit, fontString)
	kit:FontObject(fontString, LabelFont())
	kit:Text(fontString, C.text)
end

-- The class comes from the emblem's atlas, "classicon-<class>", not from the meter's data.
-- The game sets every row's icon again at each refresh of the meter (several a second in a fight): what an
-- atlas becomes is worked out once (false: not a class's) and handed to the kit as the same table each time.
local iconArt = {}   -- atlas -> { coords } for the kit, or false
local function PaintIcon(kit, entry)
	local icon = entry.Icon.Icon
	local atlas = icon:GetAtlas()
	if issecretvalue(atlas) or not atlas then return end
	local art = iconArt[atlas]
	if art == nil then
		local class = atlas:lower():match("^classicon%-(%a+)$")
		local at = class and CLASS_ICON_TCOORDS[class:upper()]
		art = at and { coords = { at[1] + CROP, at[2] - CROP, at[3] + CROP, at[4] - CROP } } or false
		iconArt[atlas] = art
	end
	if art then kit:Art(icon, CLASSES, art) end
end

-- The icon box is 24 high and clipped by a shorter bar, so the border is drawn round the visible part.
local function PaintIconBorder(kit, entry, list)
	local seen = ns.Own(kit, entry.Icon, "seen", function(owner)
		local t = owner:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("CENTER")
		return t
	end)
	seen:SetSize(ICON, math.min(ICON, list:GetBarHeight()))
	kit:Plate(entry.Icon, { to = seen, fill = C.panel, over = true })
end

local faces = setmetatable({}, { __mode = "k" })   -- entry -> the face over its fill

-- The fill's color is passed straight to the setter: it may be secret.
function FaceColor(entry)
	local face = faces[entry]
	if face then face:SetVertexColor(entry.StatusBar:GetStatusBarTexture():GetVertexColor()) end
end

-- `set` is the kit's track. Everything is anchored to the fill, which the game sizes; nothing is measured.
function PaintFace(kit, entry, set)
	local bar = entry.StatusBar
	local fill = bar:GetStatusBarTexture()
	set.track:ClearAllPoints()
	set.track:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, RIM)
	set.track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -RIM)
	local face = ns.Own(kit, bar, "face", function(owner)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, 2)
		Shy.Skin.Hatch(t)
		t:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, RIM)
		t:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, -RIM)
		return t
	end)
	faces[entry] = face
	FaceColor(entry)
	local lit = ns.Own(kit, bar, "faceLit", function(owner)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, 3)
		t:SetColorTexture(1, 1, 1, 0.16)
		t:SetHeight(1)
		t:SetPoint("TOPLEFT", face, "TOPLEFT")
		t:SetPoint("TOPRIGHT", face, "TOPRIGHT")
		return t
	end)
	local shade = ns.Own(kit, bar, "faceShade", function(owner)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, 3)
		t:SetColorTexture(0, 0, 0, 0.4)
		t:SetHeight(1)
		t:SetPoint("BOTTOMLEFT", face, "BOTTOMLEFT")
		t:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT")
		return t
	end)
	local tip = ns.Own(kit, bar, "faceTip", function(owner)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, 4)
		t:SetColorTexture(1, 1, 1, 0.3)
		t:SetWidth(TIP)
		t:SetPoint("TOPRIGHT", face, "TOPRIGHT")
		t:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT")
		return t
	end)
	return face, lit, shade, tip
end

-- Blizzard sets the shadow textures' alpha itself, so they are given clear art instead of faded.
function PaintShadows(kit, bar)
	kit:Art(bar.Background, CLEAR)
	kit:Art(bar.BackgroundEdge, CLEAR)
end

-- list: the window the bar is in, for its bar height.
local function PaintEntry(m, kit, entry, list)
	local bar = entry.StatusBar
	if not hooked[entry] then
		hooked[entry] = true
		hooksecurefunc(entry, "UpdateIcon", function(self)
			if m.on then PaintIcon(m.kit, self) end
		end)
		hooksecurefunc(entry, "SetStatusBarColor", function(self)
			if m.on then FaceColor(self) end
		end)
		-- Changing the bar style in Edit Mode resets the shadow art.
		hooksecurefunc(entry, "UpdateStyle", function(self)
			if m.on then PaintShadows(m.kit, self.StatusBar) end
		end)
	end
	PaintIcon(kit, entry)
	PaintIconBorder(kit, entry, list)
	if kit:Has(bar) then return end
	PaintFace(kit, entry, kit:Bar(bar))
	PaintShadows(kit, bar)
	local _, size = bar.Name:GetFont()
	kit:FontObject(bar.Name, UI.NameFont(math.floor(size + 0.5), "OUTLINE"))   -- player names: a font family
	ns.Number(kit, bar.Value)
end

local function PaintEntries(m, kit, list)
	list:ForEachEntryFrame(function(entry) PaintEntry(m, kit, entry, list) end)
end

-- The header's three dropdowns, in the family's make (UI.MenuButton's): what each shows, then our caret, a hover
-- box round both, the caret turned over while its menu is open, everything on the strip's middle (MID down from
-- the window's top) as every header's words and controls are. Each stays the game's button with the game's menu:
-- a pick sets what the meter reads back in a fight, and only the game's own click may set it (set from our code
-- it would be tainted, and the meter could no longer work with its secret numbers).
--   left:  the type's name and its caret (the type's dropdown, sized round them)
--   right: the timer, then the segment's glyph and caret, then the cog and its caret
local MID = TOP + UI.HEAD_MID
local CONTROL = UI.HEAD.piece.line - UI.HEAD.piece.lip   -- a control's height: the strip under its lip
local PAD = UI.MENU_BUTTON.pad   -- a chooser's room at each end (ns.Dropdown, "chooser")
local EDGE_X = 11         -- words and glyphs start and end this far in, clear of the corner brackets
local SPACE = 2           -- between the two choosers
local TIMER_GAP = 4       -- between the timer and the segment's chooser
local TIMER_ROOM = 40     -- what the type's name leaves the timer: "10:00" and its gap
local CLOSE = { 6, 5, 4, 7 }            -- where the breakdown's close plate stands in its button

-- The segment shown, by its glyph: the fight going on, every fight added up, or one gone by.
local SEGMENT = { fight = GLYPH.sword, overall = GLYPH.sum, past = GLYPH.clock }

local choosers = setmetatable({}, { __mode = "k" })   -- dropdown -> its chooser (ns.Dropdown)
local sized = {}                                       -- dropdown -> the game's size

local function Size(button, width, height)
	if not sized[button] then sized[button] = { button:GetSize() } end
	button:SetSize(width, height)
end

local function Unsize()
	for button, size in pairs(sized) do
		button:SetSize(size[1], size[2])
		sized[button] = nil
	end
end

-- The segment's words and glyph. A fight gone by is named as the game's list names it.
local function Segment(window)
	local kind, id = window:GetSessionType(), window:GetSessionID()
	if kind == Enum.DamageMeterSessionType.Overall then return DAMAGE_METER_OVERALL_SESSION, "overall" end
	if kind == Enum.DamageMeterSessionType.Current then return DAMAGE_METER_CURRENT_SESSION, "fight" end
	for _, fight in ipairs(C_DamageMeter.GetAvailableCombatSessions()) do
		local name = fight.name
		if fight.sessionID == id and not issecretvalue(name) and name and name ~= "" then return name, "past" end
	end
	return DAMAGE_METER_COMBAT_NUMBER:format(tonumber(id) or 0), "past"
end

-- The glyphs the rows of the header's menus wear (the game's own menus, dressed: Dropdowns.lua). The settings' and
-- the types' by their words; the segments' by their data, as a fight gone by is named after itself.
local function ByWords(names)
	local out = {}
	for name, glyph in pairs(names) do
		local words = rawget(_G, name)
		if words then out[words] = glyph end
	end
	return out
end

local SETTINGS_ICONS = ByWords({
	DAMAGE_METER_OPEN_SETTINGS = "options", DAMAGE_METER_OPEN_EDIT_MODE = "size",
	DAMAGE_METER_LOCK_WINDOW = "lock", DAMAGE_METER_UNLOCK_WINDOW = "lock",
	DAMAGE_METER_MAKE_UNINTERACTABLE = "hide", DAMAGE_METER_MAKE_INTERACTABLE = "shows",
	DAMAGE_METER_RESET_ALL_SESSIONS = "reset", DAMAGE_METER_HIDE_WINDOW = "abandon", DAMAGE_METER_SHOW_NEW_WINDOW = "window",
})
local TYPE_ICONS = ByWords({ DAMAGE_METER_CATEGORY_DAMAGE = "sword", DAMAGE_METER_CATEGORY_HEALING = "heal",
	DAMAGE_METER_CATEGORY_ACTIONS = "action" })

local function SegmentIcon(_, description)
	local data = description and description:GetData()
	if type(data) ~= "table" then return nil end
	if data.type == Enum.DamageMeterSessionType.Overall then return "sum" end
	if data.type == Enum.DamageMeterSessionType.Current then return "sword" end
	return data.sessionID and "clock" or nil
end

-- One of the header's dropdowns as a chooser (ns.Dropdown), the game's button sized round it.
local function Chooser(kit, button, opts)
	opts.look = "chooser"
	local c = ns.Dropdown(kit, button, opts)
	choosers[button] = c
	Size(button, c.width, CONTROL)
	return c
end

-- The segment's glyph: set each time the window is given a segment.
local function ShowSegment(window)
	local c = choosers[window.SessionDropdown]
	if not c then return end
	local _, mark = Segment(window)
	c:SetGlyph(SEGMENT[mark])
end

-- The type's name as long as it is, up to the room the header leaves it, its caret just after it, and the
-- dropdown sized round the two. Nothing here hangs on the timer, whose size is secret in a fight.
local function FitKind(window)
	local kind = window.DamageMeterTypeDropdown
	local c, gear = choosers[kind], choosers[window.SettingsDropdown]
	if not (c and gear) then return end
	local most = window:GetWidth() - 2 * (EDGE_X - PAD) - 2 * gear.width - SPACE - TIMER_ROOM
	Size(kind, c:Fit(most), CONTROL)
end

-- Stands the words and the three dropdowns on the strip's middle (ours), or all of them back at Blizzard's
-- anchors (DamageMeterSessionWindow.xml). The timer is placed, never measured: it stands at the segment's
-- chooser and grows leftward.
local function PlaceLabels(window, ours)
	local timer, session = window.SessionTimer, window.SessionDropdown
	local kind = window.DamageMeterTypeDropdown
	local name = kind.TypeName
	local gear = window.SettingsDropdown
	local header = window.Header
	for _, region in ipairs({ timer, name, gear, session, kind }) do region:ClearAllPoints() end
	if ours then
		gear:SetPoint("RIGHT", header, "TOPRIGHT", -(EDGE_X - PAD), -MID)
		session:SetPoint("RIGHT", gear, "LEFT", -SPACE, 0)
		timer:SetPoint("RIGHT", session, "LEFT", -TIMER_GAP, 0)
		kind:SetPoint("LEFT", header, "TOPLEFT", EDGE_X - PAD, -MID)
		name:SetPoint("LEFT", header, "TOPLEFT", EDGE_X, -MID)
	else
		gear:SetPoint("RIGHT", window.MinimizeButton, "LEFT", -2, -2)
		session:SetPoint("RIGHT", gear, "LEFT", -2, 3)
		timer:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -9)
		kind:SetPoint("TOPLEFT", timer, "TOPRIGHT", 0, 6)
		name:SetWidth(0)
		name:SetPoint("LEFT", kind.Arrow, "RIGHT", 0, 3)
		name:SetPoint("RIGHT", session, "LEFT", -5, 0)
	end
	name:SetWordWrap(not ours)
end

local function PaintClose(kit, button, inset)
	ns.Close(kit, button, inset, nil, nil, "piece")
end

-- ours: the skin is on. Restores a minimized window and disables the minimize button's mouse; off re-enables it.
local unfoldable = {}   -- windows whose minimize button we mouse-disabled

local function SetFolding(window, ours)
	local button = window.MinimizeButton
	if ours then
		if window:IsMinimized() then DamageMeter:SetSessionWindowMinimized(window, false) end
		unfoldable[window] = true
		button:EnableMouse(false)
	elseif unfoldable[window] then
		unfoldable[window] = nil
		button:EnableMouse(true)
	end
end

-- Blizzard's corner handle, on a window whose corners and sides are our grip: its art goes, and its mouse
-- (an unseen corner would size the window too). Off gives the mouse back as Blizzard had it.
local unbuttoned = {}   -- resize button -> whether its mouse was on

local function SetHandle(kit, button, ours)
	if ours then
		kit:Hide(button:GetNormalTexture())
		kit:Hide(button:GetPushedTexture())
		kit:Hide(button:GetHighlightTexture())
		if unbuttoned[button] == nil then unbuttoned[button] = button:IsMouseEnabled() end
		button:EnableMouse(false)
	elseif unbuttoned[button] ~= nil then
		button:EnableMouse(unbuttoned[button])
		unbuttoned[button] = nil
	end
end

-- The other windows and every breakdown are sized as Blizzard's corner does, from every corner and side
-- they can give: a breakdown hangs from its window by the top and the near side, so only its far side,
-- its foot and the corner between them.
local FAR_RIGHT = { "RIGHT", "BOTTOM", "BOTTOMRIGHT" }
local FAR_LEFT = { "LEFT", "BOTTOM", "BOTTOMLEFT" }

local function GripWindows(m, window, piece, plate)
	if not Shy.HUD.GripFrame then return end
	local index = window:GetSessionWindowIndex()
	if window ~= DamageMeter:GetPrimarySessionWindow() then
		Shy.HUD.GripFrame(window, { id = "shyskin.meter." .. index, title = "Damage meter", size = true, inside = true,
			over = function() return m.kit:Outline(piece) end,
			shown = function() return m.on and window:CanMoveOrResize() and not window:IsNonInteractive() end })
	end
	local breakdown = window.MinimizeContainer.SourceWindow
	Shy.HUD.GripFrame(breakdown, { id = "shyskin.meter.breakdown." .. index, title = "Breakdown", size = true, inside = true,
		points = function() return breakdown:IsRightSide() and FAR_RIGHT or FAR_LEFT end,
		over = function() return m.kit:Outline(plate) end,
		shown = function() return m.on end,
		kept = function(frame) frame:SetUserPlaced(false) end })
end

-- The title strip and its line, in the top of Blizzard's header. The edge and lower brackets are the body's.
local function PaintHead(kit, window)
	local header = window.Header
	-- (An inner piece of the window's housing: the body's plate wears the theme's look for the whole window, its
	-- fill from the line down. The head has the piece's fill under its strip, as every header has: PaintWindow
	-- carries it down to the body's.)
	local head = kit:Plate(window, { key = "head", panel = true, cap = true, title = STRIP, to = header,
		inset = { 0, TOP, 0, HEADER - HEAD - EDGE }, hud = true, looks = false })
	head.edge:Hide()
	head.brackets[3]:Hide()
	head.brackets[4]:Hide()
	return head
end

local function PaintWindow(m, kit, window)
	kit:Art(window.Header, CLEAR)
	SetFolding(window, true)
	local head = PaintHead(kit, window)
	PaintLabel(kit, window.SessionTimer)
	PlaceLabels(window, true)

	local minimize = window.MinimizeButton
	kit:Hide(minimize:GetNormalTexture())
	kit:Hide(minimize:GetPushedTexture())
	kit:Hide(minimize:GetHighlightTexture())
	-- The three dropdowns as choosers (ns.Dropdown): the cog and the segment's glyph each with its caret, the
	-- type's name with its caret after it. The game's letter for the segment gives way to the glyph. Their menus
	-- are the game's (Dropdowns.lua dresses them).
	kit:Hide(window.SettingsDropdown.Icon)
	Chooser(kit, window.SettingsDropdown, { glyph = GLYPH.gear, icons = SETTINGS_ICONS })
	local session = window.SessionDropdown
	kit:Hide(session.SessionName)
	Chooser(kit, session, { icons = SegmentIcon })
	ShowSegment(window)
	local kind = window.DamageMeterTypeDropdown
	PaintLabel(kit, kind.TypeName)
	Chooser(kit, kind, { words = kind.TypeName, icons = TYPE_ICONS })
	FitKind(window)

	local body = window.MinimizeContainer
	-- Blizzard's own background (faded to the meter's opacity setting) goes: the fill is the housing's, at
	-- the Background strength like every piece on screen.
	kit:Hide(body.Background)
	-- The edge and the two lower brackets; the upper corners are the head's. The theme's look (its shade, its
	-- halo, its edge) is fitted to the whole window, head and body as one housing; the fill from the line down.
	local piece = kit:Plate(body, { panel = true, cap = true, inset = PIECE, brackets = 10, hud = true,
		looks = { to = window, inset = { 0, TOP, 0, 0 }, fill = { 0, HEAD, 0, 0 }, head = HEAD - TOP } })
	piece.brackets[1]:Hide()
	piece.brackets[2]:Hide()
	-- The head's fill reaches down to the body's, wherever the look sets that in: one fill, top to foot.
	head.fill:ClearAllPoints()
	head.fill:SetPoint("TOP", window.Header, "TOP", 0, -TOP)
	head.fill:SetPoint("BOTTOMLEFT", piece.fill, "TOPLEFT")
	head.fill:SetPoint("BOTTOMRIGHT", piece.fill, "TOPRIGHT")
	-- The primary window's corners and sides are the meter's grip: a drag there sets its width and
	-- height from that side. Every grip stands on the whole housing, head and body: the fill starts
	-- under the head in every look but the forged one.
	if box and Shy.HUD.Grip and window == DamageMeter:GetPrimarySessionWindow() then
		Shy.HUD.Grip(box, { size = true, over = function() return m.kit:Outline(piece) end })
	end
	-- What stands on the screen for the meter is the piece, TOP under the window's top: its seat and
	-- snapping go by that, as chat's go by its panel.
	if window == DamageMeter:GetPrimarySessionWindow() then Shy.HUD.SetHousing(DamageMeter, m.kit:Outline(piece)) end
	PaintLabel(kit, body.NotActive)
	SetHandle(kit, body.ResizeButton, true)
	PaintEntry(m, kit, body.LocalPlayerEntry, window)
	PaintEntries(m, kit, window)

	-- The breakdown window: no title strip, the accent line inside its top edge.
	local breakdown = body.SourceWindow
	kit:Art(breakdown.Background, C.panel)
	local plate = kit:Plate(breakdown, { panel = true, cap = true, fill = CLEAR })
	local line = kit:Line(breakdown, breakdown.Background).line
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", breakdown, "TOPLEFT", 2, -2)
	line:SetPoint("TOPRIGHT", breakdown, "TOPRIGHT", -2, -2)
	SetHandle(kit, breakdown.ResizeButton, true)
	PaintClose(kit, breakdown.CloseButton, CLOSE)
	PaintEntries(m, kit, breakdown)
	GripWindows(m, window, piece, plate)
end

local function HookWindow(m, window)
	if hooked[window] then return end
	hooked[window] = true
	local body = window.MinimizeContainer
	hooksecurefunc(window, "SetupEntry", function(self, entry)
		if m.on then PaintEntry(m, m.kit, entry, self) end
	end)
	hooksecurefunc(body.SourceWindow, "Refresh", function(self)
		if m.on then PaintEntries(m, m.kit, self) end
	end)
	hooksecurefunc(window, "SetMinimized", function(self)
		if m.on then SetFolding(self, true) end
	end)
	-- Blizzard gives its corner handle the mouse with the window's: ours stays the only one.
	hooksecurefunc(window, "SetNonInteractive", function(self, nonInteractive)
		local button = self.MinimizeContainer.ResizeButton
		if not m.on or unbuttoned[button] == nil then return end
		unbuttoned[button] = not nonInteractive
		button:EnableMouse(false)
	end)
	-- The header's choosers follow the segment, the type and the window's width. (Each lights itself under the
	-- mouse and while its menu is open; the game's dropdown names the segment under the mouse.)
	hooksecurefunc(window, "SetSession", function(self)
		if m.on then ShowSegment(self) end
	end)
	hooksecurefunc(window, "SetDamageMeterType", function(self)
		if m.on then FitKind(self) end
	end)
	window:HookScript("OnSizeChanged", function(self)
		if m.on then FitKind(self) end
	end)
	-- The type's name is lettered the frame after it is painted, and again with the theme's font or text effect:
	-- over a deeper shadow or in an outline it is longer than it was measured, so it is fitted again each time.
	for _, set in ipairs({ "SetFontObject", "SetShadowOffset" }) do
		hooksecurefunc(window.DamageMeterTypeDropdown.TypeName, set, function()
			if m.on then FitKind(window) end
		end)
	end
	-- The icon borders depend on the bar height.
	hooksecurefunc(window, "SetBarHeight", function(self)
		if not m.on then return end
		PaintEntry(m, m.kit, body.LocalPlayerEntry, self)
		PaintEntries(m, m.kit, self)
	end)
	hooksecurefunc(body.SourceWindow, "SetBarHeight", function(self)
		if m.on then PaintEntries(m, m.kit, self) end
	end)
	-- The primary window fills the frame Edit Mode places, so it is that box's drag handle.
	if box and window == DamageMeter:GetPrimarySessionWindow() then Shy.HUD.Manage(box, window) end
end

ns.Module({
	id = "meter",
	title = "Damage meter",
	desc = "The game's damage meter gets a dark panel and class-colored bars. Drag its title to move it.",
	group = "screen",
	words = "dps healing",

	Ready = function()
		local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_DamageMeter")
		return loaded
	end,

	Hook = function(m)
		box = Shy.HUD.Adopt(DamageMeter, {
			id = "shyskin.meter", title = "Damage meter", editMode = true,
			active = function() return m.on end,
		})
		DamageMeter:ForEachSessionWindow(function(window) HookWindow(m, window) end)
		hooksecurefunc(DamageMeter, "SetupSessionWindow", function(self, index)
			local window = self:GetSessionWindow(index)
			HookWindow(m, window)
			if m.on then PaintWindow(m, m.kit, window) end
		end)
	end,

	Paint = function(m, kit)
		DamageMeter:ForEachSessionWindow(function(window) PaintWindow(m, kit, window) end)
		Shy.HUD.Apply(box)
		TellDock(true)
	end,

	Clear = function(m)
		Shy.HUD.Apply(box)
		Shy.HUD.SetHousing(DamageMeter, nil)
		-- The kit doesn't track the label anchors, the dropdowns' sizes, the minimize button or the corner
		-- handles' mouse.
		DamageMeter:ForEachSessionWindow(function(window)
			PlaceLabels(window, false)
			SetFolding(window, m.on)
			SetHandle(m.kit, window.MinimizeContainer.ResizeButton, false)
			SetHandle(m.kit, window.MinimizeContainer.SourceWindow.ResizeButton, false)
		end)
		Unsize()
		-- Clear also runs before a repaint; only switching off changes the wing.
		if not m.on then TellDock(false) end
	end,
})
