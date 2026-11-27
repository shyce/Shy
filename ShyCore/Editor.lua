-- The layout editor around Shy.HUD: a panel for the piece right-clicked in layout mode or in Edit Mode,
-- Shy's pieces kept per Edit Mode layout, and Edit Mode's Save, Revert and "exit without saving"
-- carrying them. Edit Mode itself is dressed as the editor by ShySkin.
--
-- Positions live in ShyCoreDB.hud, which is the active Edit Mode layout's table in
-- ShyCoreDB.layouts (by layout: "preset:2", "account:Name", "character:Name-Realm:Name"). A layout
-- seen for the first time starts as the screen stood. Windows keep their places in every layout.

local HUD, UI = Shy.HUD, Shy.UI
local core = Shy.core
local Act = HUD.Act

local E = {}
HUD.Editor = E

local WIDTH, PAD, GAP = 250, 12, 6
local panel, group, piece
local current          -- the layout ShyCoreDB.hud belongs to
local editing = false  -- Edit Mode is open
local snaps = {}       -- layout -> its table as last saved, while Edit Mode is open
local UNKNOWN = ""     -- the snap's key while the game's layout isn't known yet (no realm name, no layouts)

-- The panel for a picked piece

local function Rect(box)
	local left, bottom, width, height = box:GetLeft(), box:GetBottom(), box:GetWidth(), box:GetHeight()
	if left == nil or bottom == nil or issecretvalue(left) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height) then return nil end
	local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return left * s, bottom * s, width * s, height * s
end

-- Beside the piece, on the side with more room; centred when it can't be measured.
local function Stand()
	local left, bottom, width, height = Rect(piece)
	panel:ClearAllPoints()
	if not left then
		panel:SetPoint("CENTER")
	elseif left + width / 2 < UIParent:GetWidth() / 2 then
		panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + width + 12, bottom + height)
	else
		panel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 12, bottom + height)
	end
end

local function Row(...)
	local buttons = { ... }
	local w = (WIDTH - 2 * PAD - (#buttons - 1) * GAP) / #buttons
	for i, b in ipairs(buttons) do
		b:SetWidth(w)
		b:SetHeight(22)
		if i > 1 then b:SetPoint("LEFT", buttons[i - 1], "RIGHT", GAP, 0) end
	end
	return buttons[1]
end

-- The picked piece's size in percent of the one it starts at, and the one its panel's knob stands at while it
-- is held (the piece takes it when the knob is let go).
local asked
local function Size()
	return piece and math.floor(piece:GetScale() / Act.Base(piece) * 100 + 0.5) or 100
end

local function Build()
	panel = CreateFrame("Frame", "ShyLayoutPiece", UIParent)
	panel:SetWidth(WIDTH)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(300)   -- over Edit Mode's own settings
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()
	local head = UI.Head(panel, { title = "", close = function() Act.Select(nil) end })
	panel.extras = {}   -- widgets a piece's own `panel` function laid out last time
	panel.parts = {}    -- box -> its "On" box, for the pieces of another that can be switched off (HUD.Lead)
	panel.title = head.title

	group = UI.Group()
	local y = -(UI.HEAD_STRIP + 10)
	-- The piece takes its size as the knob is let go: sized under a knob in the hand, it was laid out again at
	-- every step and this panel, which stands beside it, moved with the knob still held. Meanwhile an outline
	-- shows the size it would take.
	panel.size = group:Slider(panel, "Size", 50, 200, 5,
		function() return asked or Size() end,
		function(v)
			asked = v
			if piece then Act.Outline(piece, Act.Base(piece) * v / 100) end
		end,
		{ width = WIDTH - 2 * PAD, format = function(v) return v .. "%" end, settle = function(v)
			asked = nil
			Act.Outline(nil)
			if piece and v ~= Size() then Act.SetScale(piece, Act.Base(piece) * v / 100) end
		end })
	panel.size:SetPoint("TOPLEFT", PAD, y)
	-- A piece that can be switched off (its box's `switch`): on or off, first.
	panel.on = group:Checkbox(panel, "On",
		function() return piece ~= nil and piece.switch ~= nil and piece.switch.get() == true end,
		function(on)
			if not (piece and piece.switch) then return end
			piece.switch.set(on)
			HUD.Switched(piece)
		end,
		{ desc = "When off, it's hidden in play and shows grey here." })
	panel.lock = group:Checkbox(panel, "Lock in place",
		function() return piece ~= nil and Act.IsLocked(piece) end,
		function(on) if piece then Act.Lock(piece, on) end end,
		{ desc = "Keeps it from being dragged by accident, here and in play." })

	panel.across = UI.Button(panel, "Center across", 100, function() Act.Center(piece, true) end)
	panel.upDown = UI.Button(panel, "Up and down", 100, function() Act.Center(piece, false) end)
	panel.place = UI.Button(panel, "Reset position", 100, function() Act.ResetPosition(piece) end)
	panel.scale = UI.Button(panel, "Reset size", 100, function()
		Act.ResetScale(piece)
		group:Refresh()
	end)
	panel.more = UI.Button(panel, "More", 100, function(self) Act.Menu(piece, self) end)
	-- The game's frame's own settings are Edit Mode's.
	panel.edit = HUD.LayoutButton(panel, 100, "Edit Mode")
	Row(panel.across, panel.upDown)
	Row(panel.place, panel.scale)
	Row(panel.more, panel.edit)
end

-- Lays the panel out for `piece`: only what applies to it.
local function Fill()
	local y = -(UI.HEAD_STRIP + 10)
	-- (on its body: clear of the look's work round the edge, UI.Body)
	local function Put(widget, height)
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", UI.Body(panel), "TOPLEFT", PAD, y)
		widget:Show()
		y = y - height - GAP
	end
	panel.title:SetText(piece.title or "")
	if asked then   -- a size the last piece's knob was left at: this piece never asked for it
		asked = nil
		Act.Outline(nil)
	end
	-- A piece with sizes of its own (ownSize) lays its own Size control in `panel`.
	panel.on:SetShown(piece.switch ~= nil)
	if piece.switch then Put(panel.on, 20) end
	local sized = Act.Scalable(piece) and not piece.ownSize
	panel.size:SetShown(sized)
	if sized then Put(panel.size, 38) end
	Put(panel.lock, 20)
	-- The pieces it leads that can be switched off (the column's under the head): an "On" box each, by its name.
	for _, check in pairs(panel.parts) do check:Hide() end
	HUD.Each(function(box)
		if box.leader ~= piece or not box.switch then return end
		local check = panel.parts[box]
		if not check then
			check = group:Checkbox(panel, box.title,
				function() return box.switch.get() == true end,
				function(on)
					box.switch.set(on)
					HUD.Switched(box)
				end,
				{ desc = box.switch.hint })
			panel.parts[box] = check
		end
		Put(check, 20)
	end)
	for _, widget in ipairs(panel.extras) do widget:Hide() end
	wipe(panel.extras)
	local function Extra(widget, height)
		panel.extras[#panel.extras + 1] = widget
		Put(widget, height)
	end
	if piece.panel then piece.panel(panel, Extra, group, WIDTH - 2 * PAD) end
	-- The controls of the pieces it leads (the group piece's settings, under the head): theirs are its panel's.
	HUD.Each(function(box)
		if box.leader == piece and box.panel then box.panel(panel, Extra, group, WIDTH - 2 * PAD) end
	end)
	Put(panel.across, 22)
	Put(panel.place, 22)
	panel.scale:SetEnabled(sized or Act.HasSize(piece))   -- a width and height given by its corner count too
	local more, edit = piece.menu ~= nil, piece.editMode == true and not editing
	panel.more:SetShown(more)
	panel.edit:SetShown(edit)
	if more or edit then
		local first = more and panel.more or panel.edit
		Put(first, 22)
		if more and edit then
			panel.edit:ClearAllPoints()
			panel.edit:SetPoint("LEFT", panel.more, "RIGHT", GAP, 0)
		end
	end
	UI.BodyFit(panel, WIDTH, -y + PAD - GAP)
	group:Refresh()
	Stand()
end

-- Picked (a left click, or by arrow keys): the panel follows the pick while it is open; nothing picked
-- closes it. Opened (a right click): the panel shows for the piece. A piece picked up and dragged isn't a
-- pick to show: the panel it followed to closes as the drag starts (`followed`), and stays for the one it was
-- opened on.
local followed = false   -- the panel's piece is the last one picked, not the one it was opened on
function HUD.OnSelect(box)
	piece = box
	if not box then
		if panel then panel:Hide() end
		return
	end
	if panel and panel:IsShown() then
		followed = true
		Fill()
	end
end

function HUD.OnOpen(box)
	piece = box
	followed = false
	if not panel then Build() end
	Fill()
	panel:Show()
end

-- A switch's setting changed elsewhere (its addon's options): the panel's "On" follows.
Shy:On("SHY_SWITCH", function(id)
	if not (panel and panel:IsShown() and piece) then return end
	local box = id and HUD.Find(id)
	if id == nil or piece.id == id or (box and box.leader == piece) then group:Refresh() end
end)

Shy:On("SHY_HUD_MOVING", function(box)
	if panel and panel:IsShown() and box == piece and followed then panel:Hide() end
end)

Shy:On("SHY_HUD_MOVED", function(box)
	if panel and panel:IsShown() and box == piece then
		group:Refresh()
		Stand()
	end
end)

-- Shy's pieces per Edit Mode layout

local function LayoutKey()
	local info = C_EditMode.GetLayouts()
	local index = info and info.activeLayout
	if not index then return nil end
	local presets = Enum.EditModePresetLayoutsMeta.NumValues
	if index <= presets then return "preset:" .. index end
	local layout = info.layouts[index - presets]
	if not layout then return nil end
	if layout.layoutType == Enum.EditModeLayoutType.Character then
		-- (Not before the realm's name is known: a key without it would be a second layout of this character's.)
		local realm = Shy.Realm(true)
		if not realm then return nil end
		return "character:" .. UnitName("player") .. "-" .. realm .. ":" .. layout.layoutName
	end
	return "account:" .. layout.layoutName
end

-- This character's layouts kept with the realm left off (a session's first moment, before the game said it): each
-- moved under its whole key. Where both are kept, the whole key's stands.
local function Fold()
	local realm = Shy.Realm(true)
	if not realm then return end
	local layouts, name = core.db.layouts, UnitName("player")
	local stray = "character:" .. name .. "-:"
	local found = {}
	for key in pairs(layouts) do
		if key:sub(1, #stray) == stray then found[#found + 1] = key end
	end
	for _, key in ipairs(found) do
		local whole = "character:" .. name .. "-" .. realm .. ":" .. key:sub(#stray + 1)
		if key ~= current then
			if layouts[whole] == nil then layouts[whole] = layouts[key] end
			layouts[key] = nil
		end
	end
end

local function Snap(key, data)
	key = key or UNKNOWN
	if editing and not snaps[key] then snaps[key] = Shy.CopyTable(data) end
end

function E.Follow()
	local key = LayoutKey()
	if key == current then Fold() end
	if not key or key == current then return end
	local layouts = core.db.layouts
	local was = core.db.hud
	if current then layouts[current] = was end
	local now = layouts[key]
	if not now then
		now = Shy.CopyTable(was)
		layouts[key] = now
	end
	HUD.Each(function(box)
		if box.window then now[box.id] = was[box.id] end
	end)
	current = key
	core.db.layoutKey = key
	Snap(key, now)
	if now ~= was then
		core.db.hud = now
		Act.ApplyAll()
	end
	Fold()
end

-- Puts back every layout changed since Edit Mode last saved, as Edit Mode does with its own.
function E.Revert()
	for key, data in pairs(snaps) do
		local target = key == (current or UNKNOWN) and core.db.hud or core.db.layouts and core.db.layouts[key]
		if target then
			wipe(target)
			for id, saved in pairs(Shy.CopyTable(data)) do target[id] = saved end
		end
	end
	Act.Select(nil)
	Act.ApplyAll()
end

local function Saved()
	wipe(snaps)
	Snap(current, core.db.hud)
end

-- The saved variables are read back as separate tables: the active layout's is ShyCoreDB.hud again.
local function Start()
	core.db.layouts = core.db.layouts or {}
	current = core.db.layoutKey
	if current then core.db.layouts[current] = core.db.hud end
	E.Follow()
end

Shy:On("SHY_LOGIN", Start)
local events = CreateFrame("Frame")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")   -- (the realm's name may come only now: LayoutKey)
events:SetScript("OnEvent", function()
	if core.db.layouts then E.Follow() end
end)

EventRegistry:RegisterCallback("EditMode.Enter", function()
	editing = true
	wipe(snaps)
	if core.db.layouts then E.Follow() end
	Snap(current, core.db.hud)
end, E)
EventRegistry:RegisterCallback("EditMode.Exit", function()
	editing = false
	wipe(snaps)
end, E)
EventRegistry:RegisterCallback("EditMode.SavedLayouts", Saved, E)
-- Edit Mode's own Revert, and leaving or switching layouts without saving.
EditModeManagerFrame.RevertAllChangesButton:HookScript("OnClick", E.Revert)
EditModeUnsavedChangesDialog.ProceedButton:HookScript("OnClick", E.Revert)
-- A frame of the game's picked in Edit Mode: Shy's piece lets go.
hooksecurefunc(EditModeManagerFrame, "SelectSystem", function() Act.Select(nil) end)
