-- Layout mode for the console: dragging the cockpit, and picking the console's layout and size.
--
-- The cockpit is made of Blizzard frames (personal resource display, cooldown
-- viewers, stance bar, cast bar). Each is adopted into Shy.HUD, held still while
-- seated (no mover of its own) and given its seat (Layout.Seat) as a home at the
-- vessel's scale; one stand-in box drags them all. The stand-in covers the whole
-- group as it shows (the box, the gems half out of its top, the tiles half out of
-- its foot, the tracked buffs and their wing, the Shift strip docked at its end), so
-- in the editor it reads as one piece; `hold` is where the cockpit's box lies within
-- it, for turning the stand-in's place back into the cockpit's. The position is saved
-- in T.db.cockpit / cockpitX, the size in T.db.cockpitScale (the wheel on the stand-in),
-- not in Edit Mode. The tracked bars have a home of their own, not in the cockpit (beside the plate in a
-- classic layout, L.Beside; by your frames in one by role, P.BarsHome), unless "Bars and pings on it" joins
-- them to it, and a stand-in of their own over it ("Tracked bars"): dragged, the home moves (ns.char.barsAt,
-- until the next setup or "Back to its place"). The pings and markers are ShyTip's own box (Arrange.lua).
-- Pieces are placed with plain SetPoint (HUD's `plain`) so no Edit Mode code
-- runs from addon code: the stance bar is protected, and waits for combat to end.
-- A piece taken out (Pieces.lua) or moved in Edit Mode is loose: its own HUD box, placed and sized by
-- the player, until it is put back or the next setup (ns.char.loose), or until Edit Mode's "Reset To
-- Default Position" seats it again. In the layout editor the seated pieces have no highlight of their
-- own (ShySkin): the stand-in is the one piece; taken apart (Pieces.lua), every piece has its own.

local ADDON, ns = ...
local T = ns.T
local UI, HUD, Console = Shy.UI, Shy.HUD, ns.Console
local max, min = math.max, math.min

local M = {}
ns.Move = M

local ID = "shydock-cockpit"
local MARGIN = 40          -- minimum gap between the cockpit's top and the screen's
local STRIP_H = 124  -- three rows of buttons (the classic layouts, those by role, the sizes) and a line
local SETTLE = 0.3
local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "ADDON_LOADED" }
-- The totem bar is the one piece that isn't in Layout.ROWS.
local TOTEMS = { key = "totems", frame = "MultiCastActionBarFrame" }

local handle, strip, note, back
-- The tracked bars' stand-in in a layout by role (their home is apart from the cockpit), and that home now.
local BARS_ID = "shydock-bars"
local bars, barsHome
local again   -- "Put it back" was pressed: the layout is set up again as layout mode closes
local buttons, styles = {}, {}
M.buttons, M.styles = buttons, styles
local pieces, adopted = {}, {}
M.pieces = pieces
-- The cockpit's box within the stand-in: offsets, the stand-in's size, and the box's own size.
local hold = { dx = 0, dy = 0, w = 0, h = 0, bw = 300, bh = 79 }
-- Boxes of ShyDock's own seated like the game's frames (the swing row): key -> HUD box id.
local OWN = { swing = "shydock-swing" }
local picked    -- size picked in the strip, set up when layout mode closes
local pickedStyle   -- and layout
local dragNow   -- the plan's inputs, cached during a drag
local pending

-- Pieces and seats

-- The cooldown viewers load on demand, so this is retried.
local function Adopt(key, name)
	local frame = name and _G[name]
	if not frame or adopted[name] then return end
	adopted[name] = true
	local piece = { key = key, name = name }
	-- Edit Mode's own name for the frame ("Essential Cooldowns").
	local ok, title = pcall(frame.GetSystemName, frame)
	piece.title = (ok and type(title) == "string" and title ~= "") and title or name
	piece.box = HUD.Adopt(frame, {
		id = "shydock-" .. name, title = piece.title, editMode = true, plain = true, scale = true,
		-- Moved in Edit Mode: drop its home without re-placing it mid-drag.
		taken = function(box)
			ns.char.loose[key] = true
			box.given, box.placed = nil, nil
		end,
		-- Reset to its default position in Edit Mode: its default is its seat.
		reset = function()
			ns.char.loose[key] = nil
			M.Touch()
		end,
	})
	-- Seated, a piece is still: the stand-in moves it. Taken apart or loose, it has its own mover.
	HUD.SetStill(piece.box, true)
	piece.box.menu = function(root)
		if ns.Pieces then ns.Pieces.Menu(root, piece) end
	end
	pieces[#pieces + 1] = piece
	if ns.Pieces then ns.Pieces.Watch(piece) end
end

local function AdoptAll()
	for _, def in ipairs(ns.Layout.ROWS) do
		Adopt(def.key, def.frame)
		Adopt(def.key, def.stead)
	end
	Adopt(TOTEMS.key, TOTEMS.frame)
end

local function Same(a, b)
	if a == nil or b == nil then return a == b end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

-- Seat every piece from cockpit plan `c`; nil returns them to Blizzard's anchors. A seated piece is
-- still (the stand-in moves it) unless the vessel is taken apart; a loose one has its own mover.
local function Seat(c)
	local apart = ns.Pieces ~= nil and ns.Pieces.Apart()
	local moved = false   -- returned: some piece was given another home or scale
	for _, piece in ipairs(pieces) do
		local home, loose = nil, ns.char.loose[piece.key]
		if c and not loose and ns.Layout.WasSeated(piece.key) then
			local point, x, y = ns.Layout.Seat(piece.key, c)
			if point then home = { point, "BOTTOM", x, y } end
		end
		HUD.SetStill(piece.box, home ~= nil and not apart)
		-- Each piece at the scale that puts its own measures on whole pixels (the plan's grid).
		local scale = home and (c.scales[piece.key] or c.scale) or nil
		if not Same(piece.box.given, home) or (home and piece.box.givenScale ~= scale) then
			HUD.SetHome(piece.box, home, scale)
			moved = true
		end
	end
	for key, id in pairs(OWN) do
		local box = HUD.Find(id)
		if box then
			local point, x, y = nil, nil, nil
			if c and not ns.char.loose[key] then point, x, y = ns.Layout.Seat(key, c) end
			if point then
				HUD.SetStill(box, not apart)
				local scale = c.scales[key] or c.scale
				if not Same(box.defaultPoint, { point, "BOTTOM", x, y }) or box.givenScale ~= scale then
					HUD.SetHome(box, { point, "BOTTOM", x, y }, scale)
					moved = true
				end
			else
				HUD.SetStill(box, false)
			end
		end
	end
	return moved
end

-- Which of the plan's rects each row stands in (the rest share their row's key).
local RECT = { essential = "gems", cast = "cast" }

-- The group's rectangle: the box and every piece showing around it, in the plan's units.
local function Union(c)
	local box = c.rects.box
	local l, b, r, t = box[1], box[2], box[3], box[4]
	local function Add(rect)
		if not rect then return end
		l, b, r, t = min(l, rect[1]), min(b, rect[2]), max(r, rect[3]), max(t, rect[4])
	end
	for _, def in ipairs(ns.Layout.ROWS) do
		local key = def.key
		-- Tracked bars with a home of their own are no part of it: they have their own stand-in (BarsHome).
		if not ns.char.loose[key] and not (key == "bars" and c.barsApart) then
			-- The cast bar and the display are the cockpit's while it holds them, shown or not;
			-- the rest only while something of theirs is on screen.
			local held = (key == "cast" or key == "display") and T:CockpitHolds(key) or ns.Layout.RowRect(def) ~= nil
			if held then Add(c.rects[RECT[key] or key]) end
		end
	end
	Add(c.rects.blades)
	-- The plate as a cast has it: grown down round the cast bar's row.
	if T:CockpitHolds("cast") and c.low then Add({ box[1], c.low, box[3], box[4] }) end
	if not ns.char.loose.swing then Add(c.rects.swing) end
	-- The tracked bars' wing, while a bar is up and they are joined to the plate.
	if c.rects.barsWing and not c.barsApart then
		for _, def in ipairs(ns.Layout.ROWS) do
			if def.key == "bars" and ns.Layout.RowRect(def) ~= nil then Add(c.rects.barsWing) end
		end
	end
	-- The Shift strip (ShyTip) docked at the box's end: a Shy box, in screen units.
	local strip = HUD.Find("shytip-strip")
	if strip and strip.docked and strip:IsShown() then
		local left, bottom = strip:GetLeft(), strip:GetBottom()
		if left and bottom and not issecretvalue(left) and not issecretvalue(bottom) then
			local s, middle = strip:GetScale(), UIParent:GetWidth() / 2
			Add({ left * s - middle, bottom * s, (left + strip:GetWidth()) * s - middle, (bottom + strip:GetHeight()) * s })
		end
	end
	return l, b, r, t
end

-- The tracked bars' home of their own (a layout by role) while the plan has one, else nil.
local function BarsHome(c)
	return c and c.barsApart and not ns.char.loose.bars and c.rects.barsWing or nil
end

-- Put the stand-in over the cockpit's group, and the tracked bars' over their home.
local function Home(c)
	local box = c.rects.box
	local l, b, r, t = Union(c)
	hold.dx, hold.dy, hold.w, hold.h = box[1] - l, box[2] - b, r - l, t - b
	hold.bw, hold.bh = box[3] - box[1], box[4] - box[2]
	-- The plan's origin (the height setting) stands this far over the plate's top edge: the top row rides it.
	hold.dt = c.top - box[4]
	handle:SetSize(hold.w, hold.h)
	HUD.SetHome(handle, { "BOTTOMLEFT", "BOTTOM", l, b })
	local home = BarsHome(c)
	barsHome = home
	if home then
		bars:SetSize(home[3] - home[1], home[4] - home[2])
		HUD.SetHome(bars, { "BOTTOMLEFT", "BOTTOM", home[1], home[2] })
	end
	HUD.Update(bars)
end

function M.Sync()
	AdoptAll()
	if not ns.Layout.IsActive() then
		Seat(nil)
		barsHome = nil
		HUD.Update(bars)
		return
	end
	local _, now = ns.Layout.Plan()
	local c = ns.Layout.Cockpit(now)
	local moved = Seat(c)
	if HUD.IsUnlocked() and not HUD.IsDragging(handle) and not HUD.IsDragging(bars) then Home(c) end
	-- Nothing moved: the plate is drawn from the plan just made, not planned from the screen again.
	if moved or not ns.Cockpit.MeasureFrom then ns.Cockpit.Measure() else ns.Cockpit.MeasureFrom(now, c) end
	if ns.Pieces then ns.Pieces.Refresh(c) end
end

-- Sync next frame, and again once row widths have settled. Returns true while a sync is due next frame (the
-- cockpit is measured then too), false when only the settle's is still to come.
local due = false
local function First()
	due = false
	M.Sync()
end
function M.Touch()
	if pending then return due end
	pending, due = true, true
	C_Timer.After(0, First)
	C_Timer.After(SETTLE, function()
		pending = nil
		M.Sync()
	end)
	return true
end

-- Dragging the stand-in

-- Save the cockpit's position from the stand-in's rectangle (screen units), clamped
-- to the screen. The stand-in sized with the wheel (a scale other than 1) sizes the
-- vessel instead, about its top edge's middle, between the smallest and largest sizes.
local function Take(left, bottom, scale)
	local L = ns.Layout
	if math.abs(scale - 1) > 0.001 then
		T.db.cockpitScale = L.ClampScale((T.db.cockpitScale or 1) * scale)
		return
	end
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local bw, bh = hold.bw, hold.bh
	local cx, cy = left + hold.w / 2, bottom + hold.h / 2
	local x = cx + hold.dx + bw / 2 - hold.w / 2 - w / 2
	local top = cy + hold.dy + bh - hold.h / 2 + (hold.dt or 0)
	local reach = (w - bw) / 2
	T.db.cockpitX = max(-reach, min(reach, x))
	T.db.cockpit = max(bh + (hold.dt or 0), min(h - MARGIN, top)) / h * 100
end

-- The tracked bars' home taken from its stand-in's rectangle (screen units): its left edge from the screen's
-- middle and its top edge, per character (Layout.Moved keeps it on screen).
local function TakeBars(left, bottom)
	ns.char.barsAt = { left - UIParent:GetWidth() / 2, bottom + bars:GetHeight() }
end

local function TrackBars()
	local scale, left, bottom = bars:GetScale(), bars:GetLeft(), bars:GetBottom()
	if not (left and bottom) then return end
	TakeBars(left * scale, bottom * scale)
	local c = ns.Layout.Cockpit(dragNow)
	Seat(c)
	ns.Cockpit.Follow(c)
end

-- OnUpdate during a drag.
local function Track()
	local scale, left, bottom = handle:GetScale(), handle:GetLeft(), handle:GetBottom()
	if not (left and bottom) then return end
	Take(left * scale, bottom * scale, scale)
	local c = ns.Layout.Cockpit(dragNow)
	Seat(c)
	ns.Cockpit.Follow(c)
	ns.Arrange.Follow(dragNow)
end

local function Moving(box)
	if (box ~= handle and box ~= bars) or not ns.Layout.IsActive() then return end
	local _, now = ns.Layout.Plan()
	dragNow = now
	box:SetScript("OnUpdate", box == bars and TrackBars or Track)
end

-- The tracked bars' stand-in dropped: their home is where it lies (the wheel doesn't size them).
local function MovedBars()
	bars:SetScript("OnUpdate", nil)
	dragNow = nil
	local saved = Shy.core.db.hud[BARS_ID]
	if saved and saved.x and ns.Layout.IsActive() then
		local scale = saved.scale or 1
		TakeBars(saved.x * scale, saved.y * scale)
	end
	Shy.core.db.hud[BARS_ID] = nil
	bars:SetScale(1)
	M.Sync()
end

-- Dropped (already snapped) or scaled with the wheel.
local function Moved(box)
	if box == bars then return MovedBars() end
	if box ~= handle then return end
	handle:SetScript("OnUpdate", nil)
	dragNow = nil
	local saved = Shy.core.db.hud[ID]
	local sized = false
	if saved and saved.x and ns.Layout.IsActive() then
		local scale = saved.scale or 1
		sized = math.abs(scale - 1) > 0.001
		Take(saved.x * scale, saved.y * scale, scale)
	end
	-- The stand-in keeps no position of its own: its home is the cockpit.
	Shy.core.db.hud[ID] = nil
	if sized then
		T:Apply()   -- the size is a setting: every drawing of the vessel follows
	else
		M.Sync()
	end
	ns.Arrange.Soon()
end

function M.Reset()
	T.db.cockpitX, T.db.cockpit = T.defaults.cockpitX, T.defaults.cockpit
	ns.char.barsAt = nil
	M.Sync()
	ns.Arrange.Soon()
end

-- Let a piece go loose (its own box from then on) or seat it again.
function M.SetLoose(piece, loose)
	if ns.Pieces then return ns.Pieces.SetLoose(piece.key, loose) end
	ns.char.loose[piece.key] = loose or nil
	if loose then
		piece.box.given, piece.box.placed = nil, nil
		HUD.SetHome(piece.box, nil)
	end
	M.Touch()
end

-- The stand-in's menu: take the vessel apart, and each piece of it, seated or loose.
local function Menu(root)
	if ns.Pieces then
		root:CreateButton(ns.Pieces.Apart() and "Put together" or "Take apart", function() ns.Pieces.Toggle() end)
		root:CreateDivider()
	end
	for _, piece in ipairs(pieces) do
		local frame = _G[piece.name]
		-- Tracked bars with a home of their own are no piece of the cooldown manager's.
		if frame and ns.Layout.WasSeated(piece.key) and not (piece.key == "bars" and barsHome) then
			root:CreateCheckbox(piece.title .. " in the cooldown manager",
				function() return not ns.char.loose[piece.key] end,
				function() M.SetLoose(piece, not ns.char.loose[piece.key]) end)
		end
	end
end

-- The layout and size strip under layout mode's toolbar

local function PaintStrip()
	local active, size, style = ns.Layout.IsActive(), ns.Layout.Size(), ns.Layout.Style()
	for key, b in pairs(buttons) do
		local lit = picked == key or (picked == nil and active and size == key)
		UI.SetFill(b, lit and UI.colors.fill or UI.colors.bgHot)
	end
	for key, b in pairs(styles) do
		local lit = pickedStyle == key or (pickedStyle == nil and active and style == key)
		UI.SetFill(b, lit and UI.colors.fill or UI.colors.bgHot)
	end
	-- Nothing to put back while the console isn't the layout in use.
	back:SetShown(active)
	if picked or pickedStyle then
		note:SetText(("Press Done to set up %s at %s. Needs a reload."):format(
			ns.Preview.STYLE_NAMED[pickedStyle or style], ns.Preview.NAMES[picked or size]:lower()))
	elseif active then
		note:SetText("Drag the cooldown manager into place. Pick a layout or size and it changes when you press Done, or press Put it back to reset every piece (needs a reload).")
	else
		note:SetText("The console isn't set up on this character. Pick a layout or size and press Done to set it up (needs a reload).")
	end
end

local function Ghost()
	if picked or pickedStyle then
		ns.Preview.ShowGhost(picked, false, pickedStyle)
	else
		ns.Preview.HideGhost()
	end
end

-- A second click on a size, or a click on the one in use, unpicks.
local function Pick(key)
	local inUse = ns.Layout.IsActive() and ns.Layout.Size() == key
	picked = (picked ~= key and not inUse) and key or nil
	Ghost()
	PaintStrip()
end

local function PickStyle(key)
	local inUse = ns.Layout.IsActive() and ns.Layout.Style() == key
	pickedStyle = (pickedStyle ~= key and not inUse) and key or nil
	Ghost()
	PaintStrip()
end

-- Every piece back in its place and at its size, in one press: the layout and size lit in the strip (the
-- ones in use unless others are picked) are set up again as layout mode closes.
function M.PutBack()
	if InCombatLockdown() then
		T:Print("you're in combat, so the console wasn't changed. Put it back after the fight.")
		return
	end
	again = true
	HUD.SetUnlocked(false)
end

local function BuildStrip()
	strip = HUD.Strip(STRIP_H)
	-- The classic layouts on one row, those by role on the next, the sizes under them, each row labelled.
	local function Row(label, y, keys, names, width, onPick, into)
		local text = UI.Text(strip, label, 11, true, UI.colors.head)
		text:SetPoint("TOPLEFT", 14, y - 5)
		local at = 66
		for _, key in ipairs(keys) do
			local b = UI.Button(strip, names[key], width, function() onPick(key) end)
			b:SetHeight(22)
			b:SetPoint("TOPLEFT", at, y)
			into[key] = b
			at = at + width + 6
		end
	end
	Row("Layout", -7, Console.CLASSIC_ORDER, ns.Preview.STYLES, 90, PickStyle, styles)
	Row("By role", -35, Console.ROLE_ORDER, ns.Preview.STYLES, 90, PickStyle, styles)
	Row("Size", -63, Console.SIZE_ORDER, ns.Preview.NAMES, 90, Pick, buttons)
	-- At the layouts' row's end.
	back = UI.Button(strip, "Put it back", 104, M.PutBack)
	back:SetHeight(22)
	back:SetPoint("TOPRIGHT", -14, -7)
	UI.Help(back, "Put it back", "Returns every piece to its place and size in this layout. Needs a reload.")
	M.back = back
	note = UI.Text(strip, "", 11, false, UI.colors.dim)
	note:SetPoint("BOTTOMLEFT", 14, 8)
	note:SetPoint("BOTTOMRIGHT", -14, 8)
	note:SetJustifyH("LEFT")
	note:SetWordWrap(true)
end

local function Enter()
	picked, pickedStyle, again = nil, nil, nil
	if not strip then BuildStrip() end
	PaintStrip()
	if ns.Layout.IsActive() then
		local _, now = ns.Layout.Plan()
		Home(ns.Layout.Cockpit(now))
	else
		handle:Hide()
		barsHome = nil
		HUD.Update(bars)
	end
end

local function Leave()
	ns.Preview.HideGhost()
	local size, style, redo = picked, pickedStyle, again
	picked, pickedStyle, again = nil, nil, nil
	if not (size or style or redo) then return end
	if InCombatLockdown() then
		T:Print("you're in combat, so the console wasn't changed. Pick it again after the fight.")
		return
	end
	ns.Layout.Report(ns.Layout.SetUp(size, style))
end

function M.Start()
	-- Discard a position left by a logout mid-drag.
	Shy.core.db.hud[ID] = nil
	local box = ns.Layout.BOX
	handle = HUD.Create({
		id = ID, title = "Cooldown manager",
		width = box.w, height = box.h,
		point = { "BOTTOMLEFT", "BOTTOM", -box.w / 2, 300 },   -- placeholder until Home
		shown = function() return false end,                    -- visible in layout mode only
		-- Taken apart, the pieces stand for themselves.
		away = function() return ns.Pieces ~= nil and ns.Pieces.Apart() end,
	})
	M.handle = handle
	handle.menu = Menu
	-- The tracked bars' own stand-in, over their home in a layout by role; dragged, their home moves.
	Shy.core.db.hud[BARS_ID] = nil
	bars = HUD.Create({
		id = BARS_ID, title = "Tracked bars",
		width = 240, height = 40,
		point = { "BOTTOMLEFT", "BOTTOM", -120, 300 },   -- placeholder until Home
		shown = function() return false end,              -- visible in layout mode only
		away = function() return barsHome == nil or (ns.Pieces ~= nil and ns.Pieces.Apart()) end,
	})
	M.bars = bars
	bars.ownSize = true
	bars.menu = function(root)
		root:CreateButton("Back to its place", function()
			ns.char.barsAt = nil
			M.Sync()
		end)
	end
	handle.ownSize = true   -- the wheel sizes the vessel (Take); its panel has the Size control
	handle.panel = function(panel, Put, group, width)
		if ns.Pieces then ns.Pieces.Panel(panel, Put, group, width) end
	end
	Shy:On("SHY_HUD_LAYOUT", function(on)
		if on then Enter() else Leave() end
	end)
	Shy:On("SHY_HUD_MOVING", Moving)
	Shy:On("SHY_HUD_MOVED", Moved)

	local driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:SetScript("OnEvent", M.Touch)
	EventRegistry:RegisterCallback("EditMode.Exit", M.Touch, M)
	M.Sync()
end
