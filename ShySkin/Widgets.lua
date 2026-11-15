-- Painters for Blizzard's stock controls, shared by the window modules. Each takes the module's kit,
-- is safe to run again, and never sizes, shows or hides a Blizzard frame (leading controls on the title
-- strip are anchored beside the ×; the × itself stays on Blizzard's anchors).
--
--   ns.Window(kit, frame, opts)     -- a PortraitFrame / ButtonFrame / DefaultPanel as a panel; returns the plate's parts
--                                   -- (.headLeft where the strip's content begins, .iconX / .iconY for an own icon)
--                                   -- opts: to = region to fit instead of the frame
--                                   --       portrait = false (none) or "own" (room kept for the caller's 16 px icon)
--                                   --       right = title's inset from the right edge (26)
--                                   --       close = { l, t, r, b } inset of the close plate in its button
--                                   --       leading = { ... } packed beside the × (UI.HeadRail)
--   ns.WINDOW                       -- header metrics: title, head, icon, iconX, iconY
--   ns.ScrollBar(kit, bar)          -- a MinimalScrollBar
--   ns.Button(kit, button, inset, size, primary)   -- a UIPanelButtonTemplate or three-slice text button in the
--                                   -- family's button make (kit:Key); size: text (12); primary: the accent's
--   ns.Dropdown(kit, dropdown, opts)   -- any game dropdown, every one through here (look: field, key, chooser);
--                                   -- opts.ours: it opens our menu with the game's rows (UI.GameMenu), else the
--                                   -- game's menu, which Dropdowns.lua dresses (see the function for all opts)
--   ns.SearchBox(kit, box, pad)     -- a SearchBoxTemplate edit box; pad = { x, y } outset
--   ns.Check(kit, check, opts)      -- a check button; opts: size (14), color (Shy.Skin.colors.on)
--   ns.Hairline(kit, owner, key, layer)   -- a 1-unit line for the caller to anchor
--   ns.IconPicker(kit, frame)       -- an IconSelectorPopupFrameTemplate window; returns the plate's parts
--   ns.Slider(kit, slider)          -- a MinimalSliderWithSteppersTemplate: groove, knob, steppers, labels
--   ns.Input(kit, box)              -- an InputBoxTemplate edit box
--   ns.Dialog(kit, frame, opts)     -- a frame with a DialogBorder*Template `Border` as a panel; returns the plate
--                                   -- opts: title = strip height (none without), close = { l, t, r, b }
--   ns.Toggle(kit, frame, opts)     -- a frame holding a check `Button` and its `Label` (Edit Mode's toggles)
--   ns.Spine(kit, frame, key)       -- the housing down a window's right edge behind square side tabs;
--                                   -- spine:Fit(lastTab) stands it down to that tab (nil hides it)
--   ns.SPINE                        -- its measures: top, under, out, lap
--   ns.SIDE_TAB                     -- a side tab on it: w, h, slot, left, top, x (every window's alike)
--
-- A button's three state fonts and a check button's follow-along mark aren't tracked by the kit:
-- `After` restores them on the kit's Restore.
-- Blizzard resets scroll bar and dropdown arrow art on every hover and press (SetAtlas), so that
-- art is faded by alpha, never swapped.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors

local CLEAR = { 0, 0, 0, 0 }

-- The window header's numbers are the core's (UI.HEAD.window).
local TITLE = UI.HEAD.window.line - 2   -- title strip height, inside the panel's edge
local ICON = UI.HEAD.window.icon        -- icon in the title strip
local HEAD = TITLE + 4                  -- bottom of the strip and its line
local ICON_X, ICON_Y = UI.HEAD.window.pad - 1, -(TITLE + 2 - ICON) / 2
-- Legacy inset kept for callers that still pass it; ns.Close sizes the game's button to the header control.
local CLOSE = { 0, 0, 0, 0 }
ns.CLOSE = CLOSE
local CHECK = Shy.MEDIA .. "GlyphCheck"

ns.WINDOW = { title = TITLE, head = HEAD, icon = ICON, iconX = ICON_X, iconY = ICON_Y }

-- Restoring what the kit doesn't track

local undo = setmetatable({}, { __mode = "k" })   -- kit -> functions to run after its Restore

-- Runs fn once after the kit's next Restore. The kit is our own table, so wrapping its Restore taints nothing.
local function After(kit, fn)
	local list = undo[kit]
	if not list then
		list = {}
		undo[kit] = list
		local restore = kit.Restore
		kit.Restore = function(self)
			restore(self)
			local todo = undo[self]
			undo[self] = {}
			for _, job in ipairs(todo) do job() end
		end
	end
	list[#list + 1] = fn
end

-- A window

function ns.Window(kit, frame, opts)
	opts = opts or {}
	local to = opts.to or frame
	kit:Hide(frame.NineSlice)
	kit:Hide(frame.Bg)
	kit:Hide(frame.TopTileStreaks)

	local icon
	local holder = frame.PortraitContainer
	local portrait = holder and holder.portrait
	if portrait then
		if opts.portrait == nil and portrait:IsShown() then
			if kit:Has(portrait) then kit:Fade(portrait, 1) end   -- undo a fade from an earlier pass
			kit:Unmask(portrait, holder.CircleMask)
			icon = portrait
		else
			kit:Hide(portrait)
			if opts.portrait == "own" then icon = true end
		end
	end
	local title = frame.TitleContainer and frame.TitleContainer.TitleText
	local closeInset = opts.close or CLOSE
	local set = kit:Head(frame, { to = to, text = title, icon = icon, right = opts.right, leading = opts.leading })
	set.owner = frame
	-- Where an owner's own 16 px icon stands (portrait = "own"): nested inside the look's border as the kit's is.
	set.iconX, set.iconY = set.headLeft - 1, ICON_Y
	local pack = { leading = opts.leading, closeTrim = closeInset[3] or 0, closePlate = closeInset }
	if frame.CloseButton then
		ns.Close(kit, frame.CloseButton, closeInset)
		pack.close = frame.CloseButton
	end
	kit:HeadRail(set, pack)
	return set
end

-- A scroll bar

local RAIL = 4   -- drawn width of the track and thumb (the bar is 8)

local function Rail(owner, layer, sublevel, width, overhang)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetPoint("TOP", owner, "TOP", 0, overhang)
	t:SetPoint("BOTTOM", owner, "BOTTOM", 0, -overhang)
	t:SetWidth(width)
	return t
end

function ns.ScrollBar(kit, bar)
	local track = bar.Track
	local thumb = track.Thumb
	kit:Hide(track.Begin)
	kit:Hide(track.Middle)
	kit:Hide(track.End)
	kit:Hide(thumb.Begin)
	kit:Hide(thumb.Middle)
	kit:Hide(thumb.End)
	kit:Hide(bar.Back.Texture)
	kit:Hide(bar.Forward.Texture)

	local groove = ns.Own(kit, track, "groove", function(owner) return Rail(owner, "BACKGROUND", 0, RAIL, 0) end)
	groove:SetColorTexture(0, 0, 0, 0.55)
	local rim = ns.Own(kit, thumb, "rim", function(owner) return Rail(owner, "ARTWORK", 0, RAIL + 2, 1) end)
	rim:SetColorTexture(0, 0, 0, 1)
	local face = ns.Own(kit, thumb, "face", function(owner) return Rail(owner, "ARTWORK", 1, RAIL, 0) end)
	face:SetColorTexture(1, 1, 1, 1)
	face:SetGradient("HORIZONTAL", CreateColor(C.metal[1], C.metal[2], C.metal[3], 1), CreateColor(C.idle[1], C.idle[2], C.idle[3], 1))
	-- The HIGHLIGHT layer only draws on hover.
	local hot = ns.Own(kit, thumb, "hot", function(owner) return Rail(owner, "HIGHLIGHT", 0, RAIL, 0) end)
	hot:SetColorTexture(C.hover[1], C.hover[2], C.hover[3], 0.85)
end

-- A text button

-- A button swaps its font object by state (normal, highlight, disabled), so the skin is three
-- shared font objects a text size, recolored on each paint.
local BUTTON_TEXT = 12
local facesBySize = {}
local function Faces(size)
	local faces = facesBySize[size]
	if not faces then
		local tail = size == BUTTON_TEXT and "" or tostring(size)
		faces = { CreateFont("ShySkinButtonText" .. tail), CreateFont("ShySkinButtonTextHot" .. tail), CreateFont("ShySkinButtonTextOff" .. tail) }
		for _, face in ipairs(faces) do face:SetFontObject(UI.TextFont(size)) end
		facesBySize[size] = faces
	end
	local dim = UI.colors.dim
	faces[1]:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
	faces[2]:SetTextColor(1, 1, 1, 1)
	faces[3]:SetTextColor(dim[1], dim[2], dim[3], 0.6)
	return faces
end

local fonts = setmetatable({}, { __mode = "k" })   -- button -> Blizzard's three font objects

local function PutFonts(button)
	local was = fonts[button]
	if not was then return end
	fonts[button] = nil
	if was[1] then button:SetNormalFontObject(was[1]) end
	if was[2] then button:SetHighlightFontObject(was[2]) end
	if was[3] then button:SetDisabledFontObject(was[3]) end
end

function ns.Button(kit, button, inset, size, primary)
	-- UIPanelButtonTemplate has Left, Middle, Right; three-slice buttons Left, Center, Right.
	kit:Hide(button.Left)
	kit:Hide(button.Middle)
	kit:Hide(button.Center)
	kit:Hide(button.Right)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetDisabledTexture())
	kit:Hide(button:GetHighlightTexture())
	local set = kit:Key(button, { inset = inset, primary = primary })

	local face = Faces(size or BUTTON_TEXT)
	if not fonts[button] then
		fonts[button] = { button:GetNormalFontObject(), button:GetHighlightFontObject(), button:GetDisabledFontObject() }
		After(kit, function() PutFonts(button) end)
	end
	-- The current text, before the button's next state change applies the fonts.
	local text = button:GetFontString()
	if text then kit:FontObject(text, button:IsEnabled() and face[1] or face[3]) end
	button:SetNormalFontObject(face[1])
	button:SetHighlightFontObject(face[2])
	button:SetDisabledFontObject(face[3])
	return set
end

-- A dropdown

local dropdowns = setmetatable({}, { __mode = "k" })   -- dropdown -> its kit (false once restored)
local choosers = setmetatable({}, { __mode = "k" })    -- dropdown -> its chooser (look "chooser")
local icons = setmetatable({}, { __mode = "k" })       -- dropdown -> its rows' glyphs (opts.icons)

-- A painted dropdown's rows' glyphs (UI.MenuIcon's), for the game's menu it opens (Dropdowns.lua).
function ns.DropdownIcons(dropdown)
	return dropdown and dropdowns[dropdown] and icons[dropdown] or nil
end

local function InkDropdown(dropdown)
	if not dropdown.Text then return end
	local c = dropdown:IsEnabled() and C.text or UI.colors.dim
	dropdown.Text:SetTextColor(c[1], c[2], c[3])
end

-- A chooser: lit under the mouse and while its menu is open, dim at rest, its caret turned over while open.
local function ChooserLook(dropdown)
	local c = choosers[dropdown]
	if not c then return end
	local open = dropdown:IsMenuOpen()
	local ink = (open or c.over) and UI.colors.text or C.glyph
	for _, t in ipairs({ c.glyph, c.caret }) do t:SetVertexColor(ink[1], ink[2], ink[3]) end
	if open then c.caret:SetTexCoord(0, 1, 1, 0) else c.caret:SetTexCoord(0, 1, 0, 1) end
end

local Chooser = {}
Chooser.__index = Chooser

-- The glyph before the caret (a Skin.GLYPH entry).
function Chooser:SetGlyph(file)
	self.glyph:SetTexture(file)
	self.glyph:SetShown(file ~= nil)
end

-- A chooser of words: the words as long as they are, cut to `most`, the caret just after them. Returns the
-- chooser's width (room, words, gap, caret, room) for the caller to size the game's button. Words that fit are
-- left their own length, so nothing they are lettered in afterwards (a shadow, an outline) can cut them.
function Chooser:Fit(most)
	local b, words = UI.MENU_BUTTON, self.words
	words:SetWidth(0)
	local whole = math.ceil(words:GetStringWidth())
	local wide = whole
	if most then wide = math.max(10, math.min(whole, most - 2 * b.pad - b.gap - b.caret)) end
	if wide < whole then words:SetWidth(wide) end
	self.caret:ClearAllPoints()
	self.caret:SetPoint("LEFT", words, "LEFT", wide + b.gap, b.caretY)
	self.width = 2 * b.pad + wide + b.gap + b.caret
	return self.width
end

local function DressChooser(kit, dropdown, opts)
	local b = UI.MENU_BUTTON
	local c = choosers[dropdown] or setmetatable({}, Chooser)
	choosers[dropdown] = c
	kit:Plate(dropdown, { fill = CLEAR, border = CLEAR, hover = true })
	c.glyph = ns.Own(kit, dropdown, "chooserGlyph", function(o)
		local t = o:CreateTexture(nil, "OVERLAY")
		t:SetSize(b.glyph, b.glyph)
		t:SetPoint("LEFT", o, "LEFT", b.pad, 0)
		return t
	end)
	c.caret = ns.Own(kit, dropdown, "chooserCaret", function(o)
		local t = o:CreateTexture(nil, "OVERLAY")
		t:SetTexture(Skin.GLYPH.caret)
		t:SetSize(b.caret, b.caret)
		return t
	end)
	c.words = opts.words
	if c.words then
		c.glyph:Hide()
		c:Fit()
	else
		c:SetGlyph(opts.glyph)
		c.caret:ClearAllPoints()
		c.caret:SetPoint("LEFT", dropdown, "LEFT", b.pad + b.glyph + b.gap, b.caretY)
		c.width = 2 * b.pad + b.glyph + b.gap + b.caret
	end
	-- Once a dropdown: the mouse and the menu's opening and closing light it.
	if not c.hooked then
		c.hooked = true
		local function Mouse(over)
			return function(self)
				if not dropdowns[self] then return end
				choosers[self].over = over
				ChooserLook(self)
			end
		end
		dropdown:HookScript("OnEnter", Mouse(true))
		dropdown:HookScript("OnLeave", Mouse(false))
		for _, event in ipairs({ "OnMenuOpened", "OnMenuClosed" }) do
			hooksecurefunc(dropdown, event, function(self)
				if dropdowns[self] then ChooserLook(self) end
			end)
		end
	end
	ChooserLook(dropdown)
	return c
end

-- The game's dropdowns, every one through here: the button in the family's make, and the menu it opens.
--   look "field" (default)  a WowStyle1 dropdown: its words on a plate, our caret at its end
--        "key"              an arrow-only dropdown (WowStyle1Arrow): a square plate with our caret
--        "chooser"          a header's, quiet until hovered: a glyph (opts.glyph) or words of the game's (opts.words,
--                           a font string it shows) and our caret after them; lit and its caret turned while its
--                           menu is open. Returns the chooser: :SetGlyph(file), :Fit(most), .width (the caller
--                           sizes the game's button: a painter here never does)
--   ours = true             it opens the family's own menu with the game's rows (UI.GameMenu). Only for a menu whose
--                           picks nothing reads back in a fight: a pick runs in our code. Otherwise it opens the
--                           game's menu, which Dropdowns.lua dresses as ours.
--   icons                   its rows' glyphs on the rail, in either menu: { [row's words] = a UI.MenuGlyph name } or
--                           function(words, description) -> a name (UI.MenuIcon)
--   inset                   the plate in the button (field: { 0, 1, 0, 2 }; key: none)
-- Returns the kit's set (field, key) or the chooser.
function ns.Dropdown(kit, dropdown, opts)
	opts = opts or {}
	local look = opts.look or "field"
	icons[dropdown] = opts.icons
	if opts.ours then
		UI.GameMenu(dropdown, { when = function() return dropdowns[dropdown] and true or false end, icons = opts.icons,
			menu = look == "field" and { fit = true } or nil })
	end
	-- The game's art, as far as the dropdown's template has any (an arrow-only one has no background). The arrow's
	-- atlas is set again on every state change: faded, never swapped. A chooser shows its own glyph or words, so
	-- the dropdown's own words (its choice's name, which the game writes in again) are faded too.
	for _, key in ipairs({ "Background", "Arrow", look == "chooser" and "Text" or nil }) do
		local art = rawget(dropdown, key)
		if art and art ~= opts.words then kit:Hide(art) end
	end
	local made
	if look == "chooser" then
		made = DressChooser(kit, dropdown, opts)
	elseif look == "key" then
		made = kit:Key(dropdown, { inset = opts.inset, icon = Skin.GLYPH.caret, iconSize = UI.MENU_BUTTON.caret })
	else
		-- The button is 25 tall with its text 13 down: the plate is 22, centered on the text.
		made = kit:Key(dropdown, { inset = opts.inset or { 0, 1, 0, 2 }, icon = Skin.GLYPH.caret })
		made:Stand("RIGHT", made.fill, "RIGHT", -5, 0)
		kit:FontObject(dropdown.Text, UI.TextFont(11))
		kit:Text(dropdown.Text, C.text)
		-- Blizzard recolors the text on every state change.
		if dropdowns[dropdown] == nil then
			hooksecurefunc(dropdown, "OnButtonStateChanged", function(self)
				if dropdowns[self] then InkDropdown(self) end
			end)
		end
	end
	if not dropdowns[dropdown] then
		After(kit, function() dropdowns[dropdown] = false end)
	end
	dropdowns[dropdown] = kit
	if look == "field" then InkDropdown(dropdown) end
	return made
end

-- A search box

function ns.SearchBox(kit, box, pad)
	pad = pad or { 4, 2 }
	kit:Hide(box.Left)
	kit:Hide(box.Middle)
	kit:Hide(box.Right)
	kit:Tint(box.searchIcon, C.glyph)
	if box.clearButton then kit:Tint(box.clearButton.Icon, C.glyph) end
	return kit:Plate(box, { x = -pad[1], y = -pad[2], fill = UI.colors.bg, hover = true })
end

-- A check button

local marks = setmetatable({}, { __mode = "k" })   -- check button without checked art -> { mark, on = skinned }

local function ShowMark(check)
	local m = marks[check]
	if m then m.mark:SetShown(m.on and check:GetChecked() == true) end
end

function ns.Check(kit, check, opts)
	opts = opts or {}
	local size = opts.size or 14
	local color = opts.color or C.on
	local w, h = check:GetSize()
	local x, y = (w - size) / 2, (h - size) / 2
	kit:Hide(check:GetNormalTexture())
	kit:Hide(check:GetPushedTexture())
	kit:Hide(check:GetHighlightTexture())
	-- The box as the family's checkbox is made (a keyed piece), the mark in the accent.
	local set = kit:Key(check, { inset = { x, y, x, y } })

	local checked = check:GetCheckedTexture()
	if checked then
		-- The engine shows and hides the checked texture, so the mark is its art.
		kit:Art(checked, CHECK, { fit = check, x = x + 2, y = y + 2, color = color, blend = "BLEND" })
		kit:Art(check:GetDisabledCheckedTexture(), CHECK, { fit = check, x = x + 2, y = y + 2, color = C.idle, blend = "BLEND" })
		return set
	end

	-- No checked texture: our own mark. A click checks without calling SetChecked, so both are hooked.
	local mark = ns.Own(kit, check, "mark", function(owner)
		local t = owner:CreateTexture(nil, "OVERLAY")
		t:SetTexture(CHECK)
		return t
	end)
	mark:ClearAllPoints()
	mark:SetPoint("TOPLEFT", check, "TOPLEFT", x + 2, -(y + 2))
	mark:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", -(x + 2), y + 2)
	mark:SetVertexColor(color[1], color[2], color[3])
	local m = marks[check]
	if not m then
		m = { mark = mark }
		marks[check] = m
		hooksecurefunc(check, "SetChecked", ShowMark)
		check:HookScript("OnClick", ShowMark)
	end
	if not m.on then
		After(kit, function() m.on = false end)
	end
	m.on = true
	ShowMark(check)
	return set
end

-- A hairline

function ns.Hairline(kit, owner, key, layer)
	local line = ns.Own(kit, owner, key or "hairline", function(o)
		local t = o:CreateTexture(nil, layer or "ARTWORK")
		t:SetSize(1, 1)
		return t
	end)
	UI.Paint(line, UI.colors.border)
	return line
end

-- An icon picker (IconSelectorPopupFrameTemplate)

-- BorderBox holds the nine slice and also the name box and buttons, so its pieces are faded one by one.
-- The grid gets its view on first show and its buttons are pooled: each is skinned from the scroll
-- box's initialize callback. A button's icon texture is never changed: Blizzard reads the pick back from it.
local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local TRIM = { 0.08, 0.92, 0.08, 0.92 }   -- trims the icon's own dark rim

local pickers = setmetatable({}, { __mode = "k" })   -- picker -> its kit (false once restored)
local seats = setmetatable({}, { __mode = "k" })     -- icon button -> Blizzard's empty-slot texture (false: none)

-- The empty-slot texture is unnamed: found once, before we add any texture, as the one that isn't a named piece.
local function Seat(button)
	local seat = seats[button]
	if seat == nil then
		seat = false
		local icon, light, picked = button:GetNormalTexture(), button:GetHighlightTexture(), button.SelectedTexture
		for _, region in ipairs({ button:GetRegions() }) do
			if region:IsObjectType("Texture") and region ~= icon and region ~= light and region ~= picked then seat = region end
		end
		seats[button] = seat
	end
	return seat or nil
end

-- Once per button: afterwards Blizzard only changes its icon and toggles SelectedTexture.
local function IconButton(kit, button)
	local icon = button:GetNormalTexture()
	if not icon or kit:Has(icon) then return end
	kit:Hide(Seat(button))
	kit:Hide(button:GetHighlightTexture())   -- the slot has its own hover glow
	kit:Tile(button, { to = icon, icon = icon })
	kit:Crop(icon, unpack(TRIM))
	kit:Lit(button.SelectedTexture, icon, { Shy.Theme.Accent() })
end

-- Color first, so the kit records Blizzard's: a font object brings its own.
local function Label(kit, text, color)
	if not text then return end
	kit:Text(text, color)
	kit:FontObject(text, UI.TextFont(11))
	kit:Text(text, color)
end

function ns.IconPicker(kit, frame)
	local box = frame.BorderBox
	kit:Hide(frame.BG)
	for _, piece in ipairs(NINE) do kit:Hide(box[piece]) end
	local set = kit:Plate(frame, { panel = true, window = true })

	local edit = box.IconSelectorEditBox
	kit:Hide(edit.IconSelectorPopupNameLeft)
	kit:Hide(edit.IconSelectorPopupNameMiddle)
	kit:Hide(edit.IconSelectorPopupNameRight)
	kit:Plate(edit, { inset = { -6, -2, -6, -2 }, fill = UI.colors.bg, hover = true })
	-- The edit box keeps Blizzard's font. An edit box is its own font object: swapping and restoring
	-- it makes it its own parent and the client crashes with a stack overflow.
	Label(kit, box.EditBoxHeaderText, UI.colors.dim)
	Label(kit, box.IconSelectionText, UI.colors.dim)
	Label(kit, box.SelectedIconArea.SelectedIconText.SelectedIconHeader, UI.colors.dim)
	IconButton(kit, box.SelectedIconArea.SelectedIconButton)

	ns.Button(kit, box.OkayButton)
	ns.Button(kit, box.CancelButton)
	ns.Dropdown(kit, box.IconTypeDropdown, { ours = true })

	local selector = frame.IconSelector
	ns.ScrollBar(kit, selector.ScrollBar)
	local grid = selector.ScrollBox
	if pickers[frame] == nil then
		grid:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, button)
			local dressing = pickers[frame]
			if dressing then IconButton(dressing, button) end
		end, pickers)
	end
	if not pickers[frame] then
		After(kit, function() pickers[frame] = false end)
	end
	pickers[frame] = kit
	-- The grid has no view until the picker has shown once.
	if grid:HasView() then
		grid:ForEachFrame(function(button) IconButton(kit, button) end)
	end
	return set
end

-- A slider with steppers (MinimalSliderWithSteppersTemplate): a groove filled in the accent up to a
-- steel knob over Blizzard's thumb, minus and plus plates for the steppers, labels in Shy's font.
local GROOVE, KNOB_W, KNOB_H, STEP = 6, 6, 14, 14

function ns.Slider(kit, holder)
	local slider = holder.Slider
	kit:Hide(slider.Left)
	kit:Hide(slider.Middle)
	kit:Hide(slider.Right)
	local thumb = slider:GetThumbTexture()
	kit:Hide(thumb)
	local y = math.max(0, (slider:GetHeight() - GROOVE) / 2)
	local groove = kit:Plate(slider, { key = "groove", inset = { 0, y, 0, y }, fill = UI.colors.bg })
	local flow = ns.Own(kit, slider, "flow", function(owner) return owner:CreateTexture(nil, "ARTWORK") end)
	flow:ClearAllPoints()
	flow:SetPoint("BOTTOMLEFT", groove.fill, "BOTTOMLEFT", 1, 1)
	flow:SetPoint("RIGHT", thumb, "CENTER")
	UI.Paint(flow, Shy.Theme.Accent)
	local knob = ns.Own(kit, slider, "knob", function(owner) return owner:CreateTexture(nil, "OVERLAY") end)
	knob:ClearAllPoints()
	knob:SetPoint("CENTER", thumb, "CENTER")
	knob:SetSize(KNOB_W, KNOB_H)
	UI.Paint(knob, UI.colors.text)
	-- The steppers are odd shapes (11 x 19, 9 x 18): each gets one small square plate, centred.
	for _, step in ipairs({ { holder.Back, Skin.GLYPH.minus }, { holder.Forward, Skin.GLYPH.plus } }) do
		local button = step[1]
		if button then
			kit:HideRegions(button)
			local x, y = (button:GetWidth() - STEP) / 2, (button:GetHeight() - STEP) / 2
			kit:Key(button, { key = "step", inset = { x, y, x, y }, icon = step[2], iconSize = 8 })
		end
	end
	for _, text in ipairs(holder.Labels or {}) do Label(kit, text, UI.colors.text) end
	return groove
end

-- An edit box (InputBoxTemplate). It keeps Blizzard's font: an edit box is its own font object.
function ns.Input(kit, box)
	kit:Hide(box.Left)
	kit:Hide(box.Middle)
	kit:Hide(box.Right)
	return kit:Plate(box, { inset = { -6, -2, -2, -2 }, fill = UI.colors.bg, hover = true })
end

-- A dialog whose border is a DialogBorder*Template frame (`Border`, laid at the dialog's own level).
-- The plate is drawn on the border: a dialog that lays itself out measures its own regions, never a
-- child it ignores in layout.
function ns.Dialog(kit, frame, opts)
	opts = opts or {}
	local border = frame.Border
	kit:HideRegions(border)
	for _, piece in ipairs(NINE) do kit:Hide(border[piece]) end
	kit:Hide(border.Bg)
	local set = kit:Plate(border, { panel = true, title = opts.title, window = true })
	if frame.Title then
		kit:FontObject(frame.Title, UI.TitleFont(UI.HEAD.window.text))
		kit:Text(frame.Title, UI.colors.text)
		-- Left on the strip's middle, as every Shy window's title, clear of the close button.
		if opts.title then
			kit:Justify(frame.Title, "LEFT")
			kit:Place(frame.Title, nil, nil, UI.HeadPoint("LEFT", set, "LEFT", UI.HeadLeft(set) + 2),
				UI.HeadPoint("RIGHT", set, "RIGHT", -UI.HeadCloseReserve(set)))
		end
	end
	set.owner = frame
	local closeInset = opts.close or CLOSE
	local pack = { closeTrim = closeInset[3] or 0, closePlate = closeInset }
	if frame.CloseButton then
		ns.Close(kit, frame.CloseButton, closeInset)
		pack.close = frame.CloseButton
	end
	kit:HeadRail(set, pack)
	return set
end

-- A toggle: a frame holding a check button (`Button`) and its `Label`. Blizzard's box is 32 wide for
-- an 18 plate, so the label is brought in to sit by the plate (a region's anchor, not the frame's).
local TOGGLE = 18
function ns.Toggle(kit, frame, opts)
	local button = frame.Button
	local size = (opts and opts.size) or TOGGLE
	ns.Check(kit, button, { size = size })
	local text = frame.Label
	if not text then return end
	kit:Text(text, UI.colors.text)
	kit:FontObject(text, UI.TextFont(12))
	kit:Text(text, UI.colors.text)
	local lip = (button:GetWidth() - size) / 2
	kit:Place(text, nil, nil, { "LEFT", button, "RIGHT", 6 - lip, 0 })
end

-- A spine: fill and edge on the window's BACKGROUND layer, under the window's own edge (BORDER), so the two
-- read as one housing; brackets in the accent on its outer corners; the window's look round it (its rim and
-- light, no shade or glow of its own: the window's runs round both). It starts SPINE.top down, laps SPINE.lap
-- under the window's edge, and ends SPINE.under below the last tab and SPINE.out past it.
-- A side tab on a spine (ns.SIDE_TAB, the character window's and the spellbook's alike): w by h, its slot
-- `slot` square, `left` in from the window's edge and 5 from the tab's other sides. With the spine's measures
-- that leaves the same 9 round the slots on every side of the rail: the window's edge to a slot, a slot to the
-- spine's far side, the spine's top (the header's line, 26 down) to the first, the last to its foot. The first
-- tab stands 30 down, as the character window's do.
ns.SPINE = { top = 26, under = 4, out = 4, lap = 3 }
ns.SIDE_TAB = { w = 42, h = 38, slot = 28, left = 9, top = 30 }
ns.SIDE_TAB.x = math.floor(ns.SIDE_TAB.left + (ns.SIDE_TAB.slot - ns.SIDE_TAB.w) / 2)   -- the slot's middle from the tab's
local SPINE = ns.SPINE
local spines = setmetatable({}, { __mode = "k" })   -- frame -> key -> the look's regions, built once

local SpineMixin = {}

function SpineMixin:Fit(last)
	for _, part in ipairs(self.parts) do part:SetShown(last ~= nil) end
	if not last then
		for _, t in ipairs(UI.LookParts(self.look)) do t:Hide() end
		return
	end
	for i = 1, 2 do   -- fill and edge; the brackets and the look's regions are anchored to the edge
		local t = self.parts[i]
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", -SPINE.lap, -SPINE.top)
		t:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", SPINE.out, -SPINE.under)
	end
	-- Shown whole above: dressed again, so only the look's own regions stay.
	self:Dress()
end

function SpineMixin:Dress()
	local look, panel = Shy.Theme.Look(), Skin.colors.panel
	-- The fill the window's own is, in its look (the leather's tone, the steel's).
	self.parts[1]:SetColorTexture(UI.LookFill(look, panel[1], panel[2], panel[3], panel[4] or 1))
	UI.LookDress(self.look, look, { fill = self.parts[1], forged = self.forged, metal = Skin.colors.metal })
	self.look.shade:Hide()
	self.look.halo:Hide()
end

function ns.Spine(kit, frame, key)
	key = key or "spine"
	local SC = Skin.colors
	local fill = ns.Own(kit, frame, key .. "Fill", function(o) return o:CreateTexture(nil, "BACKGROUND", nil, -7) end)
	fill:SetColorTexture(SC.panel[1], SC.panel[2], SC.panel[3], SC.panel[4] or 1)
	local edge = ns.Own(kit, frame, key .. "Edge", function(o)
		local t = o:CreateTexture(nil, "BACKGROUND", nil, 6)
		t:SetTexture(UI.EDGE)
		t:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
		return t
	end)
	edge:SetVertexColor(SC.metal[1], SC.metal[2], SC.metal[3])
	local s = setmetatable({ frame = frame, parts = { fill, edge }, forged = { edge } }, { __index = SpineMixin })
	local r, g, b = Shy.Theme.Accent()
	for _, def in ipairs(UI.BRACKETS) do
		if def[1] == "TOPRIGHT" or def[1] == "BOTTOMRIGHT" then
			local bracket = ns.Own(kit, frame, key .. def[1], function(o)
				local t = o:CreateTexture(nil, "BACKGROUND", nil, 7)
				t:SetTexture(UI.BRACKET)
				t:SetTexCoord(def[2], def[3], def[4], def[5])
				t:SetSize(UI.BRACKET_SIZE, UI.BRACKET_SIZE)
				t:SetPoint(def[1], edge, def[1], 0, 0)
				return t
			end)
			bracket:SetVertexColor(r, g, b)
			s.parts[#s.parts + 1] = bracket
			s.forged[#s.forged + 1] = bracket
		end
	end
	-- The look's regions, fitted to the edge, under the window's own: built once a frame and key.
	local byKey = spines[frame]
	if not byKey then
		byKey = {}
		spines[frame] = byKey
	end
	local look = byKey[key]
	if not look then
		-- A look kind's regions, made later, go under the window's own art with the rest.
		look = UI.LookBuild(frame, edge, { 0, 0, 0, 0 }, function(_, region, kind) if kind then UI.LookUnder(region) end end)
		look.solid = true
		for _, k in ipairs({ "shade", "halo", "frost", "sky", "sheen", "foot", "brushed" }) do look[k]:SetDrawLayer("BACKGROUND", 4) end
		look.plateSheen:SetDrawLayer("BACKGROUND", 5)
		look.brushedLit:SetDrawLayer("BACKGROUND", 5)
		look.edge:SetDrawLayer("BACKGROUND", 6)
		look.pane:SetDrawLayer("BACKGROUND", 6)
		look.metalEdge:SetDrawLayer("BACKGROUND", 6)
		look.wellFill:SetDrawLayer("BACKGROUND", 5)
		look.well:SetDrawLayer("BACKGROUND", 6)
		look.light:SetDrawLayer("BACKGROUND", 7)
		look.rivetLayer = { "BACKGROUND", 7 }
		byKey[key] = look
	end
	for _, k in ipairs(UI.LOOK_PARTS) do s.parts[#s.parts + 1] = look[k] end
	s.look = look
	-- The spine is the window's housing, its look's regions with it (rivets made later too): reported once a
	-- frame and key, so the watch fades it and nothing takes it for what the window shows.
	if not look.housed then
		look.housed = true
		local own = { fill, edge }
		for i = 3, #s.forged + 1 do own[#own + 1] = s.parts[i] end
		Skin.House(frame, function()
			local out = { unpack(own) }
			for _, t in ipairs(UI.LookParts(look)) do out[#out + 1] = t end
			return out
		end)
	end
	s:Dress()
	return s
end
