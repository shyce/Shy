-- The world map and its quest log (WorldMapFrame, QuestMapFrame). The canvas and its pins are not touched.
-- BorderFrame lies over the whole window in a higher strata than the canvas, so the panel's fill
-- is on WorldMapFrame and the plate on BorderFrame keeps only its edge and title strip.
-- NavBar buttons are pooled and reused: painting follows NavBar_CheckLength.
-- Quest log rows are pooled: painting follows QuestLogQuests_Update. Blizzard recolors a quest's
-- name on every update and hover, so the "plain" option recolors after it each time.
-- Quest detail text is QuestInfo's shared font strings: lightened while in the map's log and
-- restored when QuestInfo_Display moves them elsewhere.
-- A quest's page opened by itself (QuestLogPopupDetailFrame) is dressed with the log: a window of
-- the family's, the same words light on it (see "A quest's page in a window of its own").
-- Six frames are re-anchored, each with Blizzard's anchors kept and restored: the NavBar
-- (Blizzard re-anchors it in Minimize and Maximize), the maximize / minimize frame, the help
-- button, the log's search box and settings button (Blizzard sizes the search box in
-- QuestLogQuests_ShowQuestCount), and the coordinates (top right of the map, faint until the mouse
-- is on them). With a gamepad the log's row is Blizzard's.
-- The window's menus are the family's own (see "The menus").
-- None of them is protected now; ns.AfterCombat covers the case. No field is written on a
-- Blizzard frame or table (weak tables here), and every hook is a post-hook.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors
local GLYPH = Skin.GLYPH

local CLEAR = { 0, 0, 0, 0 }
local WHITE = { 1, 1, 1, 1 }
local ICON = "Interface\\Icons\\INV_Misc_Map02"   -- header icon, as Blizzard_AdventureMap uses

-- Header buttons, right to left: close (ns.Window's plate), maximize / minimize, help: one plate size (a window
-- header's controls), each standing APART left of the one before, level with the close plate's middle.
local BUTTON = UI.HEAD.window.control
local APART = UI.HEAD.window.close - UI.HEAD.window.control   -- gap between plates, as every header's controls
local CLOSE_IN = 4         -- room kept for the close when the title's right is counted (packed from HeadCloseRight)
local SIZE_X = CLOSE_IN + BUTTON + APART              -- right inset of maximize / minimize
local HELP_X = SIZE_X + BUTTON + APART + BUTTON / 2   -- the help button's center
local HELP = { 24, 24, 24, 24 }                   -- its plate in the middle of its 64 square
local MAXMIN = { 0, 0, 0, 0 }                     -- the maximize / minimize frame is stood the plate's size
local TITLE_RIGHT = SIZE_X + BUTTON + 6           -- the title's right inset
local TITLE_HELP = HELP_X + 12 + 4                -- ... while the help button shows (it takes clicks 12 either side of center)

local NAV_X = 8            -- the bar's left inset on the maximized map (WorldMapMixin:Maximize)
local DROP = -5.5          -- crumb text offset from its button's center
local CRUMB = 12           -- crumb font size
-- Plate insets { left, top, right, bottom } in 32 px buttons.
local FILTER = { 5, 8.5, 5, 1.5 }
local PIN = { 5, 7, 5, 3 }
local TOGGLE = { 5, 5, 5, 5 }

-- The log's search row. The log's top is 25 under the window's and its right edge 3 inside.
local ROW = 22             -- row height and settings button width
local ROW_Y = 11           -- under the log's top, level with the filter's plate
local ROW_LEFT = 8         -- search plate's left inset in the log
local ROW_RIGHT = 5        -- settings button's right inset in the log
local ROW_GAP = 4
local PAD = { 4, 2 }       -- ns.SearchBox's plate outset
local RAISE = 20           -- frame levels above the list, so its rows scroll under the row

-- A quest's row is its name and its objectives, and laps 3 over the row above. Its wash (under the
-- mouse, and behind the quest pointed at) covers all of it, this far inside its top and its foot.
local BAND_TOP, BAND_FOOT = 3, 2

local GAP = { 1, 0, 1, 0 }        -- inset between the three buttons under a quest's details
local LIST = 12            -- font size of quest names and zone headers
local LINE = 11            -- font size of objectives

-- Helpers

-- Blizzard's textures on a frame, listed on first sight, before any of ours is added.
local theirs = setmetatable({}, { __mode = "k" })
local FACES = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }

local function Art(frame)
	local list = theirs[frame]
	if not list then
		list = {}
		local listed = {}
		local function Add(texture)
			if texture and not listed[texture] then
				listed[texture] = true
				list[#list + 1] = texture
			end
		end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsObjectType("Texture") then Add(region) end
		end
		-- A button's state textures may not be among its regions.
		if frame:IsObjectType("Button") then
			for _, face in ipairs(FACES) do Add(frame[face](frame)) end
		end
		theirs[frame] = list
	end
	return list
end

local function HideArt(kit, frame, keep)
	for _, texture in ipairs(Art(frame)) do
		if texture ~= keep then kit:Hide(texture) end
	end
end

local function Tint(texture, c, alpha)
	texture:SetVertexColor(c[1], c[2], c[3], alpha or 1)
end

-- Sets a font object, keeping the string's color and justification: a font object brings its
-- own. The color goes through the kit first, so Restore returns Blizzard's.
local function Face(kit, fontString, object, side)
	if not kit:Has(fontString) then
		local r, g, b = fontString:GetTextColor()
		kit:Text(fontString, { r, g, b })
		if side then kit:Justify(fontString, side) end
	end
	local r, g, b = fontString:GetTextColor()
	kit:FontObject(fontString, object)
	if side then fontString:SetJustifyH(side) end
	fontString:SetTextColor(r, g, b)
end

-- Our own glyph texture; the caller anchors and colors it.
local function Mark(kit, owner, key, file, size, layer)
	local texture = ns.Own(kit, owner, key, function(o)
		local t = o:CreateTexture(nil, layer or "ARTWORK")
		t:SetSize(size, size)
		return t
	end)
	texture:SetTexture(file)
	return texture
end

-- Our own font string.
local function Words(kit, owner, key, object, layer)
	return ns.Own(kit, owner, key, function(o)
		return UI.Words(o, object, nil, { layer = layer, wrap = false })
	end)
end

-- Replaces a round gold button's art with the family's button make and a glyph (kit:Key). on: lit at rest.
local function Flat(kit, button, inset, glyph, size, on)
	HideArt(kit, button)
	return kit:Key(button, { inset = inset, icon = glyph, iconSize = size, on = on })
end

-- A hover-colored gradient fading out to the right.
local function Wash(texture)
	local c = UI.colors.hot
	texture:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.2), CreateColor(c[1], c[2], c[3], 0))
end

local function OnGamepad()
	return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Re-anchored frames

local stood = setmetatable({}, { __mode = "k" })   -- frame -> Blizzard's { points, w, h, level }
local ours = setmetatable({}, { __mode = "k" })    -- frame -> currently at our anchors

local function Keep(frame)
	if ours[frame] then return end
	local s = { points = {}, level = frame:GetFrameLevel() }
	s.w, s.h = frame:GetSize()
	for i = 1, frame:GetNumPoints() do s.points[i] = { frame:GetPoint(i) } end
	stood[frame] = s
end

-- A single point: Blizzard sometimes sets a point without ClearAllPoints, and must not find a
-- second one of ours. anchor = { point, to, toPoint, x, y }; width, height and level are optional.
local function Stand(frame, anchor, width, height, level)
	Keep(frame)
	local s = stood[frame]
	frame:ClearAllPoints()
	frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
	if width then
		s.sized = true
		frame:SetSize(width, height)
	end
	if level then
		s.raised = true
		frame:SetFrameLevel(level)
	end
	ours[frame] = true
end

-- Two corners, so the frame's size is its anchors' and a size Blizzard gives it changes nothing on screen.
-- For an edit box that matters: its size changing says its text changed, and the log's search box answers
-- that, while a search is typed, by building the list again (which gives it its size again ...). Anchored
-- again only when its place has moved: setting the same points is a change to it too.
local function Span(frame, from, to, level)
	Keep(frame)
	local s = stood[frame]
	local same = ours[frame] and frame:GetNumPoints() == 2
	for i, want in ipairs(same and { from, to } or {}) do
		local point, rel, toPoint, x, y = frame:GetPoint(i)
		if point ~= want[1] or rel ~= want[2] or toPoint ~= want[3] or math.abs(x - want[4]) > 0.01 or math.abs(y - want[5]) > 0.01 then
			same = false
		end
	end
	if not same then
		frame:ClearAllPoints()
		frame:SetPoint(from[1], from[2], from[3], from[4], from[5])
		frame:SetPoint(to[1], to[2], to[3], to[4], to[5])
	end
	if level and frame:GetFrameLevel() ~= level then
		s.raised = true
		frame:SetFrameLevel(level)
	end
	ours[frame] = true
end

local function PutBack(frame)
	local s = stood[frame]
	if not (s and ours[frame]) then return end
	ours[frame] = nil
	frame:ClearAllPoints()
	for _, p in ipairs(s.points) do frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
	if s.sized then frame:SetSize(s.w, s.h) end
	if s.raised then frame:SetFrameLevel(s.level) end
end

-- Runs now, or after combat if any of the frames is protected.
local function Move(key, frames, fn)
	for _, frame in ipairs(frames) do
		if frame:IsProtected() then
			ns.AfterCombat(key, fn)
			return
		end
	end
	fn()
end

-- Maximize / minimize and the help button, left of the close button.
local function StandHeader(m)
	local border = WorldMapFrame.BorderFrame
	local size, help = border.MaximizeMinimizeFrame, border.Tutorial
	Move("worldmap:header", { size, help }, function()
		if m.on then
			Stand(size, { "CENTER", border.CloseButton, "CENTER", -BUTTON - APART, 0 }, BUTTON, BUTTON)
			Stand(help, { "CENTER", size, "CENTER", -BUTTON - APART, 0 })
		else
			PutBack(size)
			PutBack(help)
		end
	end)
end

-- The log's search box and settings button.
local function StandRow(m)
	local log, scroll = QuestMapFrame, QuestScrollFrame
	local search, gear = scroll.SearchBox, scroll.SettingsDropdown
	Move("worldmap:row", { search, gear }, function()
		if m.on and not OnGamepad() then
			local level = scroll:GetFrameLevel() + RAISE
			Stand(gear, { "TOPRIGHT", log, "TOPRIGHT", -ROW_RIGHT, -ROW_Y }, ROW, ROW, level)
			-- From the row's left to the settings button, the plate reaching PAD past the box all round. Its size
			-- is its corners' (Span): Blizzard sizes it again at every build of the list.
			Span(search, { "TOPLEFT", log, "TOPLEFT", ROW_LEFT + PAD[1], -(ROW_Y + PAD[2]) },
				{ "BOTTOMRIGHT", log, "TOPRIGHT", -(ROW_RIGHT + ROW + ROW_GAP + PAD[1]), -(ROW_Y + ROW - PAD[2]) }, level)
		else
			PutBack(search)
			PutBack(gear)
		end
	end)
end

-- The window

-- WorldMapFrame draws through a frame buffer (its XML), so nothing on it shows past its rect, and BorderFrame lies
-- over the canvas: what lies behind the window (the look's shade and its glow round the window, UI.LOOK_BEHIND)
-- stands on a frame of its own beside the map, just under it, shown with it. The kit still owns those regions: the
-- skin going off hides them.
local outside
local function Outside(map, border)
	if not outside then
		outside = CreateFrame("Frame", nil, UIParent)
		outside:SetAllPoints(border)
		local function Sync()
			outside:SetFrameStrata(map:GetFrameStrata())
			outside:SetFrameLevel(math.max(0, map:GetFrameLevel() - 1))
			outside:SetShown(map:IsShown())
		end
		map:HookScript("OnShow", Sync)
		map:HookScript("OnHide", Sync)
		hooksecurefunc(map, "Maximize", Sync)   -- the map takes another strata maximized
		hooksecurefunc(map, "Minimize", Sync)
		Sync()
	end
	return outside
end

-- The look's face (the riveted plate's brushing and sheen, the stitched grain, a well's dark) would lie over the
-- canvas as well, darkening the map: it is laid on the map frame itself, under the canvas and over the ground, so
-- it shows only round the map (a look of its own file's face too, made when it is first worn). The well's bevel
-- stays on the border, over the canvas's edge. What lies behind the window goes on the frame outside it.
local function Under(map, border, set)
	if set.look then UI.LookFace(set.look, map, Outside(map, border)) end
end

local function PaintWindow(kit)
	local map = WorldMapFrame
	local border = map.BorderFrame
	local help = border.Tutorial
	local W = ns.WINDOW

	-- The ground's fill stands where a housing's does, over the sky laid under it (Under), so the sky shows as dim
	-- here as in every other window.
	local ground = kit:Plate(map, { key = "ground", fill = C.panel, border = CLEAR })
	ground.fill:SetDrawLayer("BACKGROUND", -6)
	-- Blizzard hides the help button on the maximized map.
	local set = ns.Window(kit, border, { portrait = "own", right = help:IsShown() and TITLE_HELP or TITLE_RIGHT })
	set.fill:SetColorTexture(0, 0, 0, 0)   -- BorderFrame lies over the canvas
	Under(map, border, set)
	kit:Hide(border.InsetBorderTop)
	kit:Hide(border.FrameGlow)

	local icon = Mark(kit, border, "icon", ICON, W.icon, "OVERLAY")
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", border, "TOPLEFT", set.iconX, set.iconY)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trims the icon's dark rim

	-- The two stand as one pair with the close button: the same plate, 24 square (Blizzard's frame is 28).
	local size = border.MaximizeMinimizeFrame
	HideArt(kit, size.MaximizeButton)
	HideArt(kit, size.MinimizeButton)
	ns.Close(kit, size.MaximizeButton, MAXMIN, GLYPH.maximize)
	ns.Close(kit, size.MinimizeButton, MAXMIN, GLYPH.restore)

	-- The help button. Blizzard animates the alpha of its two pulses, so they get clear art instead of a fade.
	HideArt(kit, help)
	kit:Art(help.BigIPulse, CLEAR)
	kit:Art(help.RingPulse, CLEAR)
	kit:Key(help, { inset = HELP, size = BUTTON, label = "?", labelSize = 12 })

	local line = ns.Hairline(kit, border, "band")
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", map.ScrollContainer, "TOPLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", map.ScrollContainer, "TOPRIGHT", 0, 0)
end

-- The breadcrumb (NavBar)

local navKept            -- Blizzard's top left anchor for the windowed map
local navOurs = false    -- the bar is at our anchor

-- NAV_X from the spacer's left while the skin is on and the map is windowed; else Blizzard's anchor.
local function StandNav(m)
	local map = WorldMapFrame
	local bar = map.NavBar
	Move("worldmap:nav", { bar }, function()
		if m.on and not map:IsMaximized() then
			if navOurs then return end
			for i = 1, bar:GetNumPoints() do
				local point, to, toPoint, x, y = bar:GetPoint(i)
				if point == "TOPLEFT" then
					navKept = { point, to, toPoint, x, y }
					bar:SetPoint(point, to, toPoint, NAV_X, y)
					navOurs = true
				end
			end
		elseif navOurs then
			navOurs = false
			bar:SetPoint(navKept[1], navKept[2], navKept[3], navKept[4], navKept[5])
		end
	end)
end

-- The current map bright, its parents dim, the hovered one in the hover color.
local function InkCrumb(kit, bar, button, hot)
	local color = UI.colors.dim
	if not button:IsEnabled() then
		color = UI.colors.text
	elseif hot then
		color = UI.colors.hot
	end
	kit:Text(button.text, color)
	if button == bar.home and OnGamepad() then Tint(Mark(kit, button, "globe", Shy.MEDIA .. "GlyphGlobeS", 12), color) end
end

local crumbs = setmetatable({}, { __mode = "k" })   -- crumbs with enter / leave hooks

-- Blizzard's crumb: its art away, its words in our font, a chevron before it. Its words, home's globe
-- and its list button's caret are what a gamepad sees: with a mouse the crumb wears a split button of
-- ours over them (DressCrumb), which has its own.
local function Crumb(m, kit, bar, button)
	HideArt(kit, button)
	local home = button == bar.home
	local pad = OnGamepad()
	local text = button.text
	Face(kit, text, UI.NameFont(CRUMB), "LEFT")
	kit:Place(text, nil, nil, { "LEFT", button, "LEFT", home and 21 or 20, DROP })
	if home and pad then
		local globe = Mark(kit, button, "globe", Shy.MEDIA .. "GlyphGlobeS", 12)
		globe:ClearAllPoints()
		globe:SetPoint("CENTER", button, "LEFT", 10, DROP)
	elseif not home then
		-- Between two crumbs: a slash. Nothing that looks like a thing to click (an angle did, beside the
		-- carets). With a mouse DressCrumb stands it in the middle of the gap between the two buttons.
		local slash = Words(kit, button, "slash", UI.NameFont(CRUMB))
		slash:ClearAllPoints()
		slash:SetPoint("CENTER", button, "LEFT", 5, DROP)
		slash:SetText("/")
		slash:SetTextColor(C.idle[1], C.idle[2], C.idle[3])
	end

	-- The sibling-maps button. Blizzard animates its textures' alpha, so they get clear art.
	local arrow = button.MenuArrowButton
	if arrow then
		kit:Hide(arrow.Art)
		kit:Art(arrow:GetNormalTexture(), CLEAR)
		kit:Art(arrow:GetPushedTexture(), CLEAR)
		kit:Hide(arrow:GetHighlightTexture())
		if pad then
			local caret = Mark(kit, arrow, "caret", GLYPH.caret, 9)
			caret:ClearAllPoints()
			caret:SetPoint("CENTER", arrow, "CENTER", 0, DROP)
			Tint(caret, C.idle)
			local lit = Mark(kit, arrow, "lit", GLYPH.caret, 9, "HIGHLIGHT")
			lit:ClearAllPoints()
			lit:SetPoint("CENTER", arrow, "CENTER", 0, DROP)
			Tint(lit, C.hover)
		end
	end

	if not crumbs[button] then
		crumbs[button] = true
		button:HookScript("OnEnter", function(self)
			if m.on then InkCrumb(m.kit, bar, self, true) end
		end)
		button:HookScript("OnLeave", function(self)
			if m.on then InkCrumb(m.kit, bar, self, false) end
		end)
	end
	InkCrumb(kit, bar, button, button:IsMouseMotionFocus())
end

local DressCrumb   -- a crumb's split button, laid over it (see "The menus")

local function PaintCrumbs(m, kit, bar)
	-- before: what stands left of a crumb. The crumb before it, or the overflow button where Blizzard has
	-- hidden the ones that don't fit.
	local before
	for _, button in ipairs(bar.navList) do
		Crumb(m, kit, bar, button)
		DressCrumb(m, kit, bar, button, before)
		before = button:IsShown() and button or bar.overflow
	end

	-- The overflow button.
	local more = bar.overflow
	HideArt(kit, more)
	local face = UI.NameFont(CRUMB)
	local dots = Words(kit, more, "dots", face)
	dots:ClearAllPoints()
	dots:SetPoint("LEFT", more, "LEFT", 10, DROP)
	dots:SetText("...")
	dots:SetTextColor(UI.colors.dim[1], UI.colors.dim[2], UI.colors.dim[3])
	local lit = Words(kit, more, "lit", face, "HIGHLIGHT")
	lit:ClearAllPoints()
	lit:SetPoint("LEFT", more, "LEFT", 10, DROP)
	lit:SetText("...")
	lit:SetTextColor(UI.colors.hot[1], UI.colors.hot[2], UI.colors.hot[3])
end

local function PaintNav(m, kit)
	local bar = WorldMapFrame.NavBar
	HideArt(kit, bar)
	HideArt(kit, bar.overlay)
	PaintCrumbs(m, kit, bar)
end

-- The controls on and beside the canvas

-- Finds one of the map's overlay frames by a key it has.
local function Overlay(has)
	for _, frame in ipairs(WorldMapFrame.overlayFrames) do
		if has(frame) then return frame end
	end
end

-- The pin button: border lit while placing a pin, glyph dim on a map that takes none.
local function PaintPin(kit, button)
	local active = button.isActive == true
	local set = Flat(kit, button, PIN, GLYPH.pin, 14, active)
	Tint(set.icon, (not button:IsEnabled() and C.idle) or (active and UI.colors.hot) or C.glyph)
end

local function PaintControls(kit)
	local map = WorldMapFrame
	if map.WorldMapTrackingOptionsButton then
		Flat(kit, map.WorldMapTrackingOptionsButton, FILTER, GLYPH.funnel, 12)
	end
	if map.WorldMapTrackingPinButton then PaintPin(kit, map.WorldMapTrackingPinButton) end

	local toggle = map.SidePanelToggle
	if toggle then
		Flat(kit, toggle.OpenButton, TOGGLE, GLYPH.caret, 10):Turn(-math.pi / 2)
		Flat(kit, toggle.CloseButton, TOGGLE, GLYPH.caret, 10):Turn(math.pi / 2)
	end

	local floors = Overlay(function(frame) return frame.ShouldShowTrackingIconOnFloor end)
	if floors then ns.Dropdown(kit, floors) end

end

-- The quest log

-- Blizzard's quest count text, at the right of the search box while it is empty.
local function Count(kit)
	local search = QuestScrollFrame.SearchBox
	local text = Words(kit, search, "count", UI.TextFont(LINE))
	text:ClearAllPoints()
	text:SetPoint("RIGHT", search, "RIGHT", -24, 0)   -- clear of the box's clear button
	text:SetJustifyH("RIGHT")
	text:SetText(QuestLogQuestCount:GetText() or "")
	text:SetTextColor(UI.colors.dim[1], UI.colors.dim[2], UI.colors.dim[3])
	text:SetShown(search:GetText() == "")
end

local function PaintLog(kit)
	local log, scroll = QuestMapFrame, QuestScrollFrame

	local seam = ns.Hairline(kit, log, "seam")
	seam:ClearAllPoints()
	seam:SetPoint("TOPLEFT", log, "TOPLEFT", -2, 25 - ns.WINDOW.head)   -- the log's top is 25 down
	seam:SetPoint("BOTTOMLEFT", log, "BOTTOMLEFT", -2, -1)

	kit:Hide(scroll.Background)
	kit:Hide(scroll.BorderFrame)
	kit:Hide(scroll.Contents.Separator)
	kit:Text(scroll.EmptyText, UI.colors.dim)
	kit:Text(scroll.NoSearchResultsText, UI.colors.dim)
	ns.ScrollBar(kit, scroll.ScrollBar)

	-- The search box overlaps the list's top, so its plate is opaque.
	local search = scroll.SearchBox
	local bg = UI.colors.bg
	ns.SearchBox(kit, search).fill:SetColorTexture(bg[1], bg[2], bg[3], 1)
	kit:Text(search.Instructions, UI.colors.dim)

	if OnGamepad() then
		-- Gamepad: Blizzard's row, with its count as plain text.
		kit:Hide(QuestLogCount.Left)
		kit:Hide(QuestLogCount.Middle)
		kit:Hide(QuestLogCount.Right)
		Face(kit, QuestLogQuestCount, UI.TextFont(LINE))
		kit:Text(QuestLogQuestCount, UI.colors.dim)
	else
		kit:Hide(QuestLogCount)   -- it sits where the settings button now is
		Count(kit)
	end

	Flat(kit, scroll.SettingsDropdown, nil, GLYPH.gear, 12)
end

-- The pooled rows

local function InkHeader(kit, button, hot)
	local label = Words(kit, button, "label", UI.TitleFont(LIST))
	local c = hot and UI.colors.hot or UI.colors.head
	label:SetTextColor(c[1], c[2], c[3])
end

-- Objectives are dim, bright while their quest is hovered; a finished quest's line is green.
local function InkObjective(kit, line, hot)
	local color = UI.colors.dim
	if line.questID and C_QuestLog.IsComplete(line.questID) then
		color = UI.colors.good
	elseif hot then
		color = UI.colors.text
	end
	kit:Text(line.Text, color)
	kit:Text(line.Dash, color)
end

-- Blizzard has just colored the name by difficulty; it is only recolored with "plain" on.
local function InkTitle(m, kit, button, hot)
	if not m.opt.plain then return end
	local color = hot and UI.colors.hot or UI.colors.text
	kit:Text(button.Text, color)
	kit:Text(button.TagText, color)
end

local function Hover(m, button, hot)
	if not m.on then return end
	InkTitle(m, m.kit, button, hot)
	for line in QuestScrollFrame.objectiveFramePool:EnumerateActive() do
		if line.questID == button.questID then InkObjective(m.kit, line, hot) end
	end
end

local rows = setmetatable({}, { __mode = "k" })   -- headers and quests with enter / leave hooks

local function Header(m, kit, button)
	HideArt(kit, button)
	kit:Hide(button.CollapseButton)   -- its icon is reset on every update, so we draw our own
	kit:Hide(button.ButtonText)       -- the button resets its text's font on every state change, so we draw our own

	local label = Words(kit, button, "label", UI.TitleFont(LIST))
	label:ClearAllPoints()
	label:SetPoint("LEFT", button, "LEFT", 20, 0)
	label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	label:SetText(button:GetText())
	local fold = Mark(kit, button, "fold", button.CollapseButton.collapsed and GLYPH.plus or GLYPH.minus, 10)
	fold:ClearAllPoints()
	fold:SetPoint("LEFT", button, "LEFT", 4, 0)
	Tint(fold, C.idle)
	local under = ns.Hairline(kit, button, "under")
	under:ClearAllPoints()
	under:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	under:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)

	if not rows[button] then
		rows[button] = true
		button:HookScript("OnEnter", function(self)
			if m.on then InkHeader(m.kit, self, true) end
		end)
		button:HookScript("OnLeave", function(self)
			if m.on then InkHeader(m.kit, self, false) end
		end)
	end
	InkHeader(kit, button, button:IsMouseMotionFocus())
end

-- Marks the super-tracked quest with an accent line and the hover gradient.
local function Select(kit)
	local tracked = C_SuperTrack.GetSuperTrackedQuestID()
	for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
		local wash = ns.Own(kit, button, "wash", function(o)
			local t = o:CreateTexture(nil, "BACKGROUND")
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, -BAND_TOP)
			t:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, BAND_FOOT)
			t:SetColorTexture(1, 1, 1, 1)
			return t
		end)
		Wash(wash)
		local light = ns.Own(kit, button, "light", function(o)
			local t = o:CreateTexture(nil, "BORDER")
			t:SetPoint("TOPLEFT", o, "TOPLEFT", 0, -BAND_TOP)
			t:SetPoint("BOTTOM", o, "BOTTOM", 0, BAND_FOOT)
			t:SetWidth(2)
			return t
		end)
		light:SetColorTexture(Shy.Theme.light[1], Shy.Theme.light[2], Shy.Theme.light[3], 1)
		local on = tracked ~= nil and tracked ~= 0 and button.questID == tracked
		wash:SetShown(on)
		light:SetShown(on)
	end
end

local function Title(m, kit, button)
	local text = button.Text
	if not kit:Has(text) then
		Face(kit, text, UI.TitleFont(LIST), "LEFT")
		Face(kit, button.TagText, UI.TitleFont(LIST))

		local glow = button.HighlightTexture
		kit:Art(glow, WHITE)
		kit:Tint(glow, UI.colors.hot, true)
		kit:Place(glow, nil, nil, { "TOPLEFT", button, "TOPLEFT", 0, -BAND_TOP }, { "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, BAND_FOOT })
		Wash(glow)

		-- The track checkbox; Blizzard shows and hides the check.
		local box = button.Checkbox
		HideArt(kit, box, box.CheckMark)
		kit:Plate(box, { inset = { 1, 1, 1, 1 }, fill = UI.colors.bg, hover = true })
		kit:Art(box.CheckMark, Shy.MEDIA .. "GlyphCheck", { fit = box, x = 3, y = 3, color = C.on })

		if not rows[button] then
			rows[button] = true
			button:HookScript("OnEnter", function(self) Hover(m, self, true) end)
			button:HookScript("OnLeave", function(self) Hover(m, self, false) end)
		end
	end
	InkTitle(m, kit, button, button:IsMouseMotionFocus())
end

local function Objective(kit, line)
	if not kit:Has(line.Text) then
		Face(kit, line.Text, UI.TextFont(LINE), "LEFT")
		Face(kit, line.Dash, UI.TextFont(LINE))
	end
	InkObjective(kit, line, false)
end

-- Runs after Blizzard rebuilds the list from its pools.
local function PaintList(m, kit)
	local scroll = QuestScrollFrame
	for button in scroll.headerFramePool:EnumerateActive() do Header(m, kit, button) end
	for button in scroll.titleFramePool:EnumerateActive() do Title(m, kit, button) end
	for line in scroll.objectiveFramePool:EnumerateActive() do Objective(kit, line) end
	Select(kit)
end

-- A quest's details

-- Some quests have a page of their own (a letter, a notice: the quest's theme, which the game reads with
-- C_QuestLog.GetQuestDetailsTheme): the game lays that paper behind the words (SealMaterialBG) and closes them
-- with a seal and a signature. Such a quest keeps its page: the paper shows as the game lays it, and the words
-- stay in the ink the game writes on paper in. Any other quest's page is the window's own ground, its words light.
-- holder: the frame whose page it is (the log's details, or the page's own window).
local function Paper(kit, holder)
	local paper = holder.SealMaterialBG
	local atlas = paper:IsShown() and paper:GetAtlas() or nil
	local papered = atlas ~= nil and atlas ~= ""
	kit:Fade(paper, papered and 1 or 0)
	return papered
end

local function PaintDetails(kit)
	local details = QuestMapFrame.DetailsFrame
	kit:Hide(details.Bg)
	Paper(kit, details)
	kit:Hide(details.BorderFrame)
	HideArt(kit, details.BackFrame)
	ns.Button(kit, details.BackFrame.BackButton)
	ns.ScrollBar(kit, details.ScrollFrame.ScrollBar)

	-- The rewards overlap the scrolling text, so their background is opaque.
	local rewards = details.RewardsFrameContainer.RewardsFrame
	kit:Hide(rewards.Top)
	kit:Hide(rewards.Bottom)
	kit:Hide(rewards.Background)
	kit:Plate(rewards, { fill = { C.panel[1], C.panel[2], C.panel[3], 1 }, border = CLEAR })
	local top = ns.Hairline(kit, rewards, "top")
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", rewards, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", rewards, "TOPRIGHT", 0, 0)
	Face(kit, rewards.Label, UI.TitleFont(14))
	kit:Text(rewards.Label, C.text)

	HideArt(kit, details.ShareButton)  -- its two dividers
	ns.Button(kit, details.AbandonButton, GAP)
	ns.Button(kit, details.ShareButton, GAP)
	ns.Button(kit, details.TrackButton, GAP)
end

-- QuestInfo's font strings are shared between windows and dark for parchment. Blizzard only
-- recolors most of them when the material changes, so each one's color is kept and restored
-- when they leave the map's log.
local lit = setmetatable({}, { __mode = "k" })   -- font string -> { was = Blizzard's color, now = ours }

local function Same(r, g, b, c)
	return math.abs(r - c[1]) < 0.01 and math.abs(g - c[2]) < 0.01 and math.abs(b - c[3]) < 0.01
end

local function Lighten(fontString, heading)
	if not fontString then return end
	local r, g, b = fontString:GetTextColor()
	local was = lit[fontString]
	if was and Same(r, g, b, was.now) then return end   -- still as we left it
	local color
	if Same(r, g, b, { QUEST_OBJECTIVE_COMPLETED_FONT_COLOR:GetRGB() }) then
		color = UI.colors.good
	elseif 0.299 * r + 0.587 * g + 0.114 * b < 0.5 then
		color = heading and UI.colors.head or UI.colors.text
	else
		lit[fontString] = nil   -- already light
		return
	end
	lit[fontString] = { was = { r, g, b }, now = { color[1], color[2], color[3] } }
	fontString:SetTextColor(color[1], color[2], color[3])
end

local function Darken()
	for fontString, e in pairs(lit) do
		local r, g, b = fontString:GetTextColor()
		if Same(r, g, b, e.now) then fontString:SetTextColor(e.was[1], e.was[2], e.was[3]) end
	end
	wipe(lit)
end

local function LightenDetails()
	Lighten(QuestInfoTitleHeader, true)
	Lighten(QuestInfoDescriptionHeader, true)
	Lighten(QuestInfoQuestType)
	Lighten(QuestInfoObjectivesText)
	Lighten(QuestInfoTimerText)
	Lighten(QuestInfoSpellObjectiveLearnLabel)
	Lighten(QuestInfoRequiredMoneyText)
	Lighten(QuestInfoGroupSize)
	Lighten(QuestInfoDescriptionText)
	Lighten(QuestInfoSealFrame.Text)
	for _, objective in ipairs(QuestInfoObjectivesFrame.Objectives) do Lighten(objective) end
end

-- True while QuestInfo's text is in the map's log.
local function InLog()
	return QuestInfoTitleHeader:GetParent() == QuestMapFrame.DetailsFrame.ScrollFrame.Contents
end

-- A quest's page in a window of its own
-- "Open Quest Details" on a tracked quest opens the log's page for it by itself (QuestLogPopupDetailFrame): on
-- parchment, in a stone window. Here it is one of the family's windows: the page's words light, as they are in
-- the map's log, the rewards' own among them (the map's log has rewards of another make), and the log's buttons
-- under them. The game leaves its title strip empty: it says what the window is.

local PAGE_KEY = { 0, 5, 0, 5 }   -- the Show Map button's plate in its 32 tall button

-- Where QuestInfo's text stands while it is in that window.
local function PageWords()
	return QuestLogPopupDetailFrame.ScrollFrame.ScrollChild
end

local function InPage()
	return QuestInfoTitleHeader:GetParent() == PageWords()
end

local function LightenPage()
	LightenDetails()
	Lighten(QuestInfoObjectivesHeader, true)
	Lighten(QuestInfoRewardText)
	local rewards = QuestInfoRewardsFrame
	Lighten(rewards.Header, true)
	Lighten(rewards.ItemChooseText)
	Lighten(rewards.ItemReceiveText)
	Lighten(rewards.PlayerTitleText)
	Lighten(rewards.QuestSessionBonusReward)
	Lighten(rewards.XPFrame.ReceiveText)
end

-- QuestInfo's words, inked for where they stand now: light on a page of ours, the game's own ink on a quest's own
-- paper, and the game's again anywhere else (the quest giver's window).
local function InkQuest(m, parent)
	local details = QuestMapFrame.DetailsFrame
	if m.on and parent == details.ScrollFrame.Contents then
		if Paper(m.kit, details) then Darken() else LightenDetails() end
	elseif m.on and parent == PageWords() then
		if Paper(m.kit, QuestLogPopupDetailFrame) then Darken() else LightenPage() end
	else
		Darken()
	end
end

local function PaintPage(kit)
	local page = QuestLogPopupDetailFrame
	HideArt(kit, page)   -- the stone, the parchment, the book in the corner
	Paper(kit, page)     -- (a quest's own paper stays)
	local set = ns.Window(kit, page, { portrait = false })
	kit:Hide(page.Inset.NineSlice)
	kit:Hide(page.Inset.Bg)
	ns.ScrollBar(kit, page.ScrollFrame.ScrollBar)

	local title = Words(kit, page.TitleContainer, "title", UI.TitleFont(UI.HEAD.window.text))
	title:ClearAllPoints()
	title:SetPoint("LEFT", set.titleText, "LEFT", 0, 0)
	title:SetText(QUEST_LOG)
	title:SetTextColor(UI.TitleInk(C.text))
	if set.look then UI.LookTitle(set.look, title) end   -- these are the window's title, not the game's empty one

	-- Show Map: the game's picture of a map beside the words gives way to a button with the words on it.
	local show = page.ShowMapButton
	kit:Hide(show.Texture)
	kit:Hide(show.Highlight)
	kit:Key(show, { inset = PAGE_KEY })
	Face(kit, show.Text, UI.TextFont(12))
	kit:Text(show.Text, C.text)
	kit:Place(show.Text, nil, nil, { "CENTER", show, "CENTER", 0, 0 })

	ns.Button(kit, page.AbandonButton, GAP)
	ns.Button(kit, page.ShareButton, GAP)
	ns.Button(kit, page.TrackButton, GAP)
end

-- The coordinates
-- Top right of the map, out of the foot's left corner where the quests' key stands; faint until the
-- mouse is on them. Blizzard anchors the panel again at every refresh of the map (PostRefresh), so it
-- is stood again after each. The fade is on its three labels, eased by a frame of ours on the map.

local COORDS = { 10, 8 }       -- in from the canvas's right edge, and down from its top
local COORDS_REST = 0.25       -- the labels' alpha with the mouse elsewhere
local COORDS_FADE = 0.15       -- seconds between faint and full
local COORDS_REACH = { 12, 80 }   -- how far round the panel the mouse still counts as on it: above, below and right; left (the words run that way)
local COORD_KEYS = { "CursorCoords", "CrosshairCoords", "PlayerCoords" }

local function Coords()
	return Overlay(function(frame) return frame.PlayerCoords and frame.CursorCoords end)
end

-- again: Blizzard has just anchored it, so where it stands now is Blizzard's place for it.
local function StandCoords(m, again)
	local coords = Coords()
	if not coords then return end
	Move("worldmap:coords", { coords }, function()
		if m.on then
			if again then ours[coords] = nil end
			Stand(coords, { "TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -COORDS[1], -COORDS[2] })
		else
			PutBack(coords)
		end
	end)
end

local coordsNow = COORDS_REST   -- the labels' alpha now

local function PaintCoords(kit, coords)
	for _, key in ipairs(COORD_KEYS) do
		local label = coords[key].Label
		ns.Number(kit, label)
		-- From the right edge leftwards: a long line (the name of another zone) grows into the map.
		kit:Justify(label, "RIGHT")
		kit:Place(label, nil, nil, { "RIGHT", coords[key], "RIGHT", 0, 0 })
		kit:Fade(label, coordsNow)
	end
end

local function WatchCoords(m)
	local coords = Coords()
	if not coords then return end
	local watch = CreateFrame("Frame", nil, WorldMapFrame)   -- runs while the map is open
	watch:SetScript("OnUpdate", function(_, elapsed)
		if not m.on then return end
		local reach = COORDS_REACH
		local want = coords:IsMouseOver(reach[1], -reach[1], -reach[2], reach[1]) and 1 or COORDS_REST
		if coordsNow == want then return end
		local step = elapsed / COORDS_FADE * (1 - COORDS_REST)
		coordsNow = want > coordsNow and math.min(want, coordsNow + step) or math.max(want, coordsNow - step)
		for _, key in ipairs(COORD_KEYS) do m.kit:Fade(coords[key].Label, coordsNow) end
	end)
end

-- The menus
-- Every menu of this window is the family's own (UI.Menu), check marks and all: the map's filter, the
-- quest log's settings, the floors of a map, a crumb's list of maps, and the right-click menus of a
-- quest and of a zone's heading. Blizzard's buttons stay the buttons: after the game has opened its
-- own menu for one, that menu is closed and ours opens in its place, in the same script, so the
-- game's is never seen. With a gamepad the menus are Blizzard's.
--
-- ShyQuest writes its own rows where it is loaded (Shy.addons.Quest: MapMenu, LogMenu, QuestMenu). Its
-- pins and objectives stand in for the game's quest markers, so the game's "quest objectives" filter is
-- then only listed while it is on, to switch it off.

local function Ours(m)
	return m.on and not OnGamepad()
end

local function Quest()
	return Shy.addons.Quest
end

local swapped = setmetatable({}, { __mode = "k" })   -- dropdowns of Blizzard's with our hook

-- write(root, dropdown): the menu's entries, written each time it opens. yield(): true while another
-- addon of ours opens this menu itself.
local function Swap(m, dropdown, write, yield)
	if not dropdown or swapped[dropdown] then return end
	swapped[dropdown] = true
	hooksecurefunc(dropdown, "OpenMenu", function(self)
		if not (Ours(m) and self:IsEnabled()) or (yield and yield()) then return end
		Menu.GetManager():CloseMenus()
		UI.DropMenu(self, function(root) write(root, self) end)
	end)
end

-- The game's filters, in the order its own menu lists them (WorldMapTrackingOptionsButtonMixin:SetupMenu).
-- The button only has the ones this client offers.
local FILTERS = { "questPOI", "showQuestLevel", "showQuestDifficultyColor", "dragonRidingRacesFilter", "showDungeonEntrancesOnMap",
	"showDelveEntrancesOnMap", "showTamers", "questPOILocalStory", "trivialQuests", "showAccountCompletedQuests", "contentTrackingFilter" }

local function FilterMenu(root, button)
	root:CreateTitle("Show on the map")
	local quest = Quest()
	local replaced = quest ~= nil and quest.MapMenu ~= nil and quest:MapMenu(root) == true
	for _, name in ipairs(FILTERS) do
		local filter = button:GetWorldMapFilter(name)
		local markers = name == "questPOI" and replaced
		if filter and not (markers and not filter:Get()) then
			local entry = root:CreateCheckbox(markers and "The game's own quest markers" or filter:GetText(),
				function() return filter:Get() end, function() filter:Set(not filter:Get()) end)
			local tip = filter:GetTooltipText()
			if tip then entry:SetTooltip(tip) end
		end
	end
end

local function LogMenu(m, root)
	root:CreateTitle("Quest log")
	-- The game draws its list again when this setting changes.
	root:CreateCheckbox("Objectives under each quest", function() return C_CVar.GetCVarBool("showQuestObjectivesInLog") end, function()
		C_CVar.SetCVar("showQuestObjectivesInLog", C_CVar.GetCVarBool("showQuestObjectivesInLog") and "0" or "1")
	end)
	local quest = Quest()
	if quest and quest.LogMenu then quest:LogMenu(root) end
	root:CreateCheckbox("Quest names in one color", function() return m.opt.plain == true end, function()
		m:SetOption("plain", not m.opt.plain)
	end)
end

local function FloorMenu(root)
	local map = WorldMapFrame
	local shown = map:GetMapID()
	local group = shown and C_Map.GetMapGroupID(shown)
	for _, floor in ipairs(group and C_Map.GetMapGroupMembersInfo(group) or {}) do
		root:CreateRadio(floor.name, function() return map:GetMapID() == floor.mapID end, function() map:SetMapID(floor.mapID) end)
	end
end

-- A crumb's list (the maps beside it), or the overflow button's (the crumbs that don't fit): what the
-- bar's own list function gives, each entry run as the bar would.
local function CrumbMenu(owner)
	return function(root, dropdown)
		local bar = owner:GetParent()
		local current = owner.data and owner.data.id
		for _, entry in ipairs(owner.listFunc and owner:listFunc() or {}) do
			local function Go() entry.func(dropdown, entry.id, bar) end
			if current then
				root:CreateRadio(entry.text, function() return entry.id == current end, Go)
			else
				root:CreateButton(entry.text, Go)
			end
		end
	end
end

-- A crumb is one of the family's split buttons (UI.SplitButton), laid over Blizzard's own: its word
-- goes to that map, its caret lists the maps beside it. The map shown has nowhere to go, so the whole
-- of it opens the list; a crumb with no list is its word alone. Blizzard's crumb under it keeps its
-- place and its width (its words and its own caret are faded), and still does the going: the word's
-- click is a click on it. With a gamepad the crumbs are Blizzard's.
local CRUMB_TALL = 20
local CRUMB_X, CRUMB_Y = 11, -5    -- our button on a crumb: in from its left (home's from 0), and under its middle, on a whole pixel
local CRUMB_CARET = 1              -- the caret against the words' line: this face has its letters high in it
local MORE_REACH = 24              -- where the overflow button's dots end, from its left
local splits = setmetatable({}, { __mode = "k" })   -- crumb -> our button on it

local function HideSplits()
	for _, split in pairs(splits) do split:Hide() end
end

-- before: what stands left of the crumb (PaintCrumbs).
DressCrumb = function(m, kit, bar, crumb, before)
	local home = crumb == bar.home
	local arrow = crumb.MenuArrowButton or nil
	local split = splits[crumb]
	-- Blizzard's words show only without ours (and the globe and caret Crumb draws are only drawn then).
	if OnGamepad() then
		kit:Fade(crumb.text, 1)
		if split then split:Hide() end
		return
	end
	kit:Fade(crumb.text, 0)
	if not split then
		split = UI.SplitButton(crumb, { font = UI.NameFont(CRUMB), height = CRUMB_TALL, inset = 9, caretY = CRUMB_CARET,
			write = function(root) CrumbMenu(crumb)(root, crumb.MenuArrowButton) end })
		split:SetPoint("LEFT", crumb, "LEFT", home and 0 or CRUMB_X, CRUMB_Y)
		if home then split:SetIcon(Shy.MEDIA .. "GlyphGlobeS") end
		-- Its words: the map shown bright, its parents dim, and the hover color while a click on them would go there.
		local look = split.OnLook
		function split:OnLook(s)
			look(self, s)
			local color = self.rest or UI.colors.dim
			if s.on then
				color = UI.colors.text
			elseif s.over and not (s.tail and self.act) then
				color = UI.colors.hot
			end
			UI.Ink(self.text, color)
			if self.icon then UI.Tint(self.icon, color) end
		end
		splits[crumb] = split
	end
	local here = not crumb:IsEnabled()   -- Blizzard disables the crumb of the map shown
	split:SetFrameLevel(crumb:GetFrameLevel() + 4)   -- over the crumb's own list button
	split.rest = here and UI.colors.text or UI.colors.dim
	split:SetAction(not here and function() crumb:Click() end or nil)
	split:SetChoices(arrow ~= nil and arrow:IsShown())
	split:SetLabel(crumb.text:GetText() or "")
	split:OnLook(split.shyPress)
	split:Show()
	-- The slash before it: in the middle of the room between the button before and this one. Blizzard
	-- stands a crumb at the end of the one before (which is wider than our button on it), so the room is
	-- worked out from the two widths.
	if not home then
		local x = 5
		if before then
			local last = splits[before]
			local reach = MORE_REACH
			if last and last:IsShown() then reach = (before == bar.home and 0 or CRUMB_X) + last:GetWidth() end
			local room = before:GetWidth() + (before.xoffset or 0) + CRUMB_X - reach
			x = CRUMB_X - room / 2
		end
		local slash = Words(kit, crumb, "slash", UI.NameFont(CRUMB))
		slash:ClearAllPoints()
		slash:SetPoint("CENTER", crumb, "LEFT", x, CRUMB_Y)
	end
end

-- A quest's right-click menu.
local function QuestMenu(row)
	local id = row.questID
	if not id then return end
	UI.ContextMenu(row, function(root)
		root:CreateTitle(C_QuestLog.GetTitleForQuestID(id) or "")
		local quest = Quest()
		local routed = quest ~= nil and quest.QuestMenu ~= nil and quest:QuestMenu(root, id) == true
		if routed then root:CreateDivider() end
		local watched = C_QuestLog.GetQuestWatchType(id) ~= nil
		if not watched or QuestUtil.CanRemoveQuestWatch() then
			root:CreateButton(watched and "Stop tracking" or "Track", function() QuestMapQuestOptions_TrackQuest(id) end)
		end
		-- (ShyQuest's "Head here first" is this and more.)
		if not routed then
			local pointed = Shy.Waypoint.QuestID() == id
			root:CreateButton(pointed and "Stop pointing the way" or "Point the way", function()
				Shy.Waypoint.Quest(pointed and 0 or id)
			end)
		end
		-- The game only lets an addon share a quest out of a fight.
		local fight = InCombatLockdown()
		local share = root:CreateButton("Share with your group", function()
			if not InCombatLockdown() then QuestMapQuestOptions_ShareQuest(id) end
		end)
		share:SetEnabled(not fight and C_QuestLog.IsPushableQuest(id) and IsInGroup())
		if fight then share:SetSub("After the fight") end
		if C_QuestLog.CanAbandonQuest(id) then
			root:CreateButton("Abandon", function() QuestMapQuestOptions_AbandonQuest(id) end)
		end
	end)
end

-- Tracks, or stops tracking, every quest under a zone's heading (as QuestLogMixin:SetHeaderQuestsTracked).
local function TrackUnder(index, track)
	for i = index + 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if not info or info.isHeader then break end
		local id = info.questID
		local watched = id and C_QuestLog.GetQuestWatchType(id) ~= nil
		if id and track and not watched then
			C_QuestLog.AddQuestWatch(id)
		elseif id and not track and watched and QuestUtil.CanRemoveQuestWatch() then
			C_QuestLog.RemoveQuestWatch(id)
		end
	end
end

local function HeadingMenu(heading)
	local index = heading.questLogIndex
	if not index then return end
	UI.ContextMenu(heading, function(root)
		root:CreateTitle(heading:GetText() or "")
		root:CreateButton("Track all", function() TrackUnder(index, true) end)
		if QuestUtil.CanRemoveQuestWatch() then
			root:CreateButton("Stop tracking all", function() TrackUnder(index, false) end)
		end
	end)
end

-- The bar's crumbs are pooled and handed out again: each one's list button, and the overflow button,
-- as they come.
-- (At every turn of the map: a crumb already swapped is passed over before its writer is made.)
local function SwapCrumbs(m, bar)
	if bar.overflow and not swapped[bar.overflow] then Swap(m, bar.overflow, CrumbMenu(bar.overflow)) end
	for _, crumb in ipairs(bar.navList) do
		local arrow = crumb.MenuArrowButton
		if arrow and not swapped[arrow] then Swap(m, arrow, CrumbMenu(crumb)) end
	end
end

-- ShyMaps' view draws the map with its own layers, and the game's filters draw nothing on it: while it
-- is in use the filter's menu is ShyMaps' (Shy.addons.Maps:MapMenu), which it opens itself.
local function MapsOwnFilter()
	local maps = Shy.addons.Maps
	return maps ~= nil and maps.View ~= nil and maps:View() ~= nil
end

local function HookMenus(m)
	local map = WorldMapFrame
	Swap(m, map.WorldMapTrackingOptionsButton, FilterMenu, MapsOwnFilter)
	Swap(m, QuestScrollFrame.SettingsDropdown, function(root) LogMenu(m, root) end)
	Swap(m, Overlay(function(frame) return frame.ShouldShowTrackingIconOnFloor end), FloorMenu)
	SwapCrumbs(m, map.NavBar)
	hooksecurefunc("QuestMapLogTitleButton_CreateContextMenu", function(row)
		if not Ours(m) then return end
		Menu.GetManager():CloseMenus()
		QuestMenu(row)
	end)
	hooksecurefunc("QuestMapLogHeaderButton_CreateContextMenu", function(heading)
		if not Ours(m) then return end
		Menu.GetManager():CloseMenus()
		HeadingMenu(heading)
	end)
end

ns.Module({
	id = "worldmap",
	title = "World map",
	desc = "Restyles the world map and quest log as one dark window, windowed or maximized, with plain-text breadcrumbs, flat buttons and its menus in the same style. The map itself is untouched.",

	options = {
		{ key = "plain", label = "Quest names in one color", default = false,
			desc = "Shows every quest name in the log in one light color. Off keeps the default difficulty colors." },
	},

	Ready = function()
		return WorldMapFrame ~= nil and QuestMapFrame ~= nil and QuestScrollFrame ~= nil and QuestLogPopupDetailFrame ~= nil and ns.Window ~= nil
	end,

	Hook = function(m)
		local map = WorldMapFrame
		-- Blizzard anchors the bar in both, and shows the help button in one and
		-- hides it in the other: the title ends where there is room.
		hooksecurefunc(map, "Minimize", function()
			navOurs = false
			StandNav(m)
			if m.on then PaintWindow(m.kit) end
		end)
		hooksecurefunc(map, "Maximize", function()
			navOurs = false
			if m.on then PaintWindow(m.kit) end
		end)
		hooksecurefunc("NavBar_CheckLength", function(bar)
			if bar ~= map.NavBar then return end
			SwapCrumbs(m, bar)
			if m.on then PaintCrumbs(m, m.kit, bar) end
		end)
		HookMenus(m)
		-- Blizzard anchors the coordinates again at every refresh of the map.
		local coords = Coords()
		if coords then
			hooksecurefunc(coords, "PostRefresh", function()
				if m.on then StandCoords(m, true) end
			end)
		end
		WatchCoords(m)
		-- Blizzard rebuilds the list, resizes the search box and rewrites the count here.
		hooksecurefunc("QuestLogQuests_Update", function()
			if not m.on then return end
			PaintList(m, m.kit)
			StandRow(m)
			if not OnGamepad() then Count(m.kit) end
		end)
		QuestScrollFrame.SearchBox:HookScript("OnTextChanged", function()
			if m.on and not OnGamepad() then Count(m.kit) end
		end)
		-- Called twice for the log (details, then rewards), or once for another window.
		hooksecurefunc("QuestInfo_Display", function(_, parent)
			local details = QuestMapFrame.DetailsFrame
			if parent == details.RewardsFrameContainer.RewardsFrame then return end
			InkQuest(m, parent)
		end)
		local pin = map.WorldMapTrackingPinButton
		if pin then
			local function Again(self)
				if m.on then PaintPin(m.kit, self) end
			end
			hooksecurefunc(pin, "SetActive", Again)
			hooksecurefunc(pin, "Refresh", Again)
		end
		local events = CreateFrame("Frame")
		events:RegisterEvent("SUPER_TRACKING_CHANGED")
		events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")   -- mouse <-> gamepad
		events:SetScript("OnEvent", function(_, event)
			if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
				m:Refresh()
			elseif m.on then
				Select(m.kit)
			end
		end)
	end,

	-- Not tracked by the kit: the quest text colors and the re-anchored frames.
	Clear = function(m)
		Darken()
		if not m.on then
			StandNav(m)
			StandHeader(m)
			StandRow(m)
			StandCoords(m)
			HideSplits()
		end
	end,

	Paint = function(m, kit)
		StandNav(m)
		StandHeader(m)
		StandRow(m)
		StandCoords(m)
		PaintWindow(kit)
		PaintNav(m, kit)
		PaintControls(kit)
		local coords = Coords()
		if coords then PaintCoords(kit, coords) end
		PaintLog(kit)
		PaintList(m, kit)
		PaintDetails(kit)
		PaintPage(kit)
		if InLog() or InPage() then InkQuest(m, QuestInfoTitleHeader:GetParent()) end
	end,
})
