-- The map's own controls, each where it belongs, so the map's top is left to the names:
--   the look (the drawn map or the terrain) on the black row at the top right, between the breadcrumb
--   and the window's menu button (T:MapMenu: what shows on the map, all in one place);
--   the corner plate in the bottom right, beside the quests' toggle (Window.lua), the quests' key having the
--   left one and the same panel. Its row at the foot: your coordinates at its left, a press on them bringing the map
--   to where you are (dim when you're on another map, whose name their hover gives); and at its right how the
--   map follows you, Off | Follow | Smart: the map stays wherever you put it; you in its middle as you move; or
--   you in sight with a little of your way ahead (View.lua). Over it, only while there is something to say:
--     "Keep it here", offered while the following view was moved by hand far enough that you're out of
--       sight: a press turns the following off, so the map stays where you put it;
--     the mouse's coordinates, opening at the top while the mouse is on the map.
--   Coordinates in tenths as the game's setting asks.
-- Other addons' buttons stand on the bar too, left of the look switch, each a square plate of its own:
--   T:BarButton(key, { art = file, size = 12, order = 0, tip = "Find" (none: no hover, for a button plain to anyone), text = "...", hints = {...},
--                      click = function(button) end, lit = function() return on end, made = function(button) end })
--   Asked again with the same key, nothing changes. The button is made when the bar is, the first time the
--   view is used; it shows and hides with the bar. With `menu = function(root) end` it is no button: the bar
--   keeps to what is reached for most (the finder, the look), and it writes its rows into the map's menu
--   instead (ns.MenuTools, T:MapMenu). `hints` may be a function giving them as the hover opens;
--   `lit` wears the switch's picked fill while true (asked again as the settings change); `made` is told the
--   button once it is made.

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local C = UI.colors

-- The look switch, on the row: hung BAR_X, BAR_Y past the top right of the window's strip (Window.lua stands the
-- strip so the switch is in the row's middle, a gap short of the menu's plate).
local TALL = 22
local LOOK_W = 56           -- each half
local BAR_X, BAR_Y = 11, -11
local SLOT_GAP = 4          -- between the plates on the bar
local slots = {}            -- other addons' buttons on the bar: { key, order, opts, button }, by order

-- The room kept clear at the right of the breadcrumb (Nav.lua): the look switch and the buttons before it.
function ns.BarRoom()
	local plated = 0
	for _, slot in ipairs(slots) do
		if not slot.opts.menu then plated = plated + 1 end
	end
	return LOOK_W * 2 - BAR_X + 8 + plated * (TALL + SLOT_GAP)
end

-- The corner plate, as the quests' key's.
local PAD, ROW = 9, 18      -- padding and row height
local HOVER = 3             -- a row's hover, in from the panel's edge
local INSET = 10            -- from the map's corner
local BESIDE = 4            -- gap to the quest log's toggle
local SPACE = 8             -- between the arrow and the numbers
local COMMA = 5             -- between x and y
local NUMBER = 13
local FOLLOW = { wide = 150 } -- the follow switch (Off | Follow | Smart)
local GLIDE = 0.08          -- seconds for a row to open or close, near enough
local READ = 0.05           -- seconds between readings

local bar, looks, plate, follow, you, keep, mouse
local readIn = 0
local elsewhere             -- the name of your map while it isn't the one shown

local function Look(style)
	if T.db.style == style then return end
	T.db.style = style
	ns.Apply()
end

local function Coord(v)
	if C_CVar.GetCVarBool("coordsByTenths") then return string.format("%.1f", v * 100) end
	return tostring(math.floor(v * 100 + 0.5))
end

-- Eases now toward want: most of the way in GLIDE seconds, landing once close.
local function Ease(now, want, dt, close)
	local left = (want - now) * math.exp(-dt * 3 / GLIDE)
	if math.abs(left) < close then return want end
	return want - left
end

-- One half of the look switch. The picked half wears the theme's selected fill.
local function Half(style, label)
	local b = CreateFrame("Button", nil, bar)
	b:SetSize(LOOK_W, TALL)
	b.style = style
	b.text = UI.Words(b, UI.TextFont(12), C.text)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	UI.Press(b, { fill = C.bgHot, bare = true, sink = { b.text } })
	function b:OnLook(s)
		if s.on and not s.down then UI.Paint(self.shyBg, C.fill) end
	end
	b:SetOn(false)
	b:SetScript("OnClick", function() Look(style) end)
	return b
end

-- Other addons' buttons on the bar: a plate like the switch's, the picture pressed in it as a half is.
local function Slot(slot)
	local opts = slot.opts
	local plate = CreateFrame("Frame", nil, View.Window())
	plate:SetFrameLevel(bar:GetFrameLevel())
	plate:SetSize(TALL, TALL)
	UI.Skin(plate, C.bgHot)
	local b = CreateFrame("Button", nil, plate)
	b:SetAllPoints()
	b.glyph = b:CreateTexture(nil, "ARTWORK")
	b.glyph:SetTexture(opts.art)
	b.glyph:SetSize(opts.size or 12, opts.size or 12)
	b.glyph:SetPoint("CENTER")
	UI.Tint(b.glyph, C.text)
	UI.Press(b, { fill = C.bgHot, bare = true, sink = { b.glyph } })
	if opts.lit then
		function b:OnLook(s)
			if s.on and not s.down then UI.Paint(self.shyBg, C.fill) end
		end
		b:SetOn(opts.lit() == true)
	end
	b:SetScript("OnClick", function(self) opts.click(self) end)
	-- Its hover under it, by the mouse: the bar is the map's top edge. (None for a button plain to anyone: no tip.)
	if opts.tip then
		b:SetScript("OnEnter", function(self)
			local hints = type(opts.hints) == "function" and opts.hints() or opts.hints
			UI.Tip(self, opts.tip, opts.text, { side = "BOTTOM", hints = hints })
		end)
		b:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	end
	plate:SetShown(bar:IsShown())
	slot.plate, slot.button = plate, b
	if opts.made then opts.made(b) end
end

-- Lays the buttons right to left from the switch, the lowest order nearest it.
local function Slots()
	table.sort(slots, function(a, b) return a.order < b.order end)
	local to = bar
	local window = View.Window()
	for _, slot in ipairs(slots) do
		-- (One in the map's menu has no plate on the bar: ns.MenuTools.)
		if not slot.opts.menu then
			if not slot.plate then Slot(slot) end
			-- (On the window holding the view, or out of sight with it.)
			slot.plate:SetParent(window)
			slot.plate:SetFrameStrata(window:GetFrameStrata())
			slot.plate:SetFrameLevel(bar:GetFrameLevel())
			slot.plate:ClearAllPoints()
			slot.plate:SetPoint("RIGHT", to, "LEFT", -SLOT_GAP, 0)
			to = slot.plate
		end
	end
end

-- The tools that write their rows into the map's menu (T:BarButton's `menu`), in their order.
function ns.MenuTools()
	table.sort(slots, function(a, b) return a.order < b.order end)
	local out = {}
	for _, slot in ipairs(slots) do
		if slot.opts.menu then out[#out + 1] = slot.opts.menu end
	end
	return out
end

function T:BarButton(key, opts)
	for _, slot in ipairs(slots) do
		if slot.key == key then return end
	end
	slots[#slots + 1] = { key = key, order = opts.order or 0, opts = opts }
	if bar then Slots() end
	if ns.BarRoomChanged then ns.BarRoomChanged() end
end

-- The view moved into the window or out of it: the bar goes with it, to the strip of the window holding it.
View.OnHost(function()
	if not bar then return end
	local window = View.Window()
	bar:SetParent(window)
	bar:SetFrameStrata(window:GetFrameStrata())
	bar:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", View.Strip(), "TOPRIGHT", BAR_X, BAR_Y)
	Slots()
end)

-- The plate's rows

-- x and y in columns of their own, so the digits stand still as they change.
local function Numbers(row, color, right)
	row.x = UI.Text(row, "", NUMBER)
	row.y = UI.Text(row, "", NUMBER)
	for _, text in ipairs({ row.x, row.y }) do
		text:SetFont(Shy.FONT_ROUNDED, NUMBER, "")
		text:SetJustifyH("RIGHT")
		UI.Ink(text, color)
	end
	row.y:SetPoint("RIGHT", -right, 0)
end

local function Say(row, x, y)
	row.x:SetText(Coord(x) .. ",")
	row.y:SetText(Coord(y))
end

-- A row stands this far up the plate, `inset` in from its sides.
local function Lift(row, y, inset)
	row:ClearAllPoints()
	row:SetPoint("BOTTOMLEFT", inset or 0, y)
	row:SetPoint("BOTTOMRIGHT", -(inset or 0), y)
end

-- The mouse's numbers stand over yours, `y` up the plate.
local function MouseAt(y)
	mouse:ClearAllPoints()
	mouse:SetPoint("BOTTOMLEFT", PAD - HOVER, y)
end

-- The plate's width: your numbers at their widest, so they stay put as they change (none while the coordinates
-- are off), then the follow switch; never less than the offer needs.
local function Width()
	local on = T.db.coords == true
	you:SetShown(on)
	local wide = PAD + math.ceil(follow:GetWidth()) + PAD
	if on then
		local sample = you.x
		sample:SetText(Coord(0.888) .. ",")
		local x = sample:GetStringWidth()
		sample:SetText(Coord(0.888))
		local y = sample:GetStringWidth()
		sample:SetText("")
		local numbers = math.ceil(x) + COMMA + math.ceil(y)
		for _, row in ipairs({ you, mouse }) do
			row.x:SetPoint("RIGHT", row.y, "RIGHT", -(math.ceil(y) + COMMA), 0)
			row:SetWidth(numbers + 2 * HOVER)
		end
		wide = wide + numbers + SPACE
	end
	wide = math.max(wide, PAD + math.ceil(keep.text:GetStringWidth()) + PAD)
	plate:SetWidth(wide)
	readIn = 0
end

-- Beside the quests' toggle while there is one (it stands as far in from the corner as the coordinates), else in
-- the corner.
local function Stand()
	if not plate then return end
	local toggle = ns.Window and ns.Window.Toggle and ns.Window.Toggle()
	local right = INSET
	if toggle and toggle:IsShown() then right = INSET + toggle:GetWidth() + BESIDE end
	-- (Offsets are the plate's own, smaller, units: kept in screen terms.)
	local k = Shy.Maps.OVER
	plate:ClearAllPoints()
	plate:SetPoint("BOTTOMRIGHT", View.Port(), "BOTTOMRIGHT", -right / k, INSET / k)
end

local function Paint()
	if not bar then return end
	for _, b in ipairs(looks) do b:SetOn(T.db.style == b.style) end
	for _, slot in ipairs(slots) do
		if slot.button and slot.opts.lit and not slot.opts.menu then slot.button:SetOn(slot.opts.lit() == true) end
	end
	follow:Refresh()
	Width()
end

-- To where you are, in the very middle: on the map shown if you're on it, else on your zone.
local function FindMe()
	if not View.PlayerAt(View.Map()) and not View.Show(MapUtil.GetDisplayableMapForPlayer(), "here") then return end
	View.Seek(math.max(View.Scale() / View.Fit(), 1.5))
end
ns.FindMe = FindMe

-- Over the row, by the mouse: the plate stands in the map's bottom corner.
local function Tip(self)
	UI.Tip(self, elsewhere and ("In " .. elsewhere) or "Where you are", nil, { side = "TOP", hints = { { "left", "Show it" } } })
end

-- What the rows say, 20 times a second; whether the mouse's and the offer show is eased every frame.
local function Read()
	local map = View.Map()
	elsewhere = nil
	local x, y, dim
	if map then
		x, y = View.PlayerAt(map)
		if not x then
			-- On another map: where you are on it, dim, and its name in the hover.
			local mine = C_Map.GetBestMapForUnit("player")
			local mx, my = View.PlayerAt(mine)
			local info = mx and C_Map.GetMapInfo(mine)
			if info then x, y, dim, elsewhere = mx, my, true, info.name end
		end
	end
	if x then
		Say(you, x, y)
	else
		you.x:SetText("")
		you.y:SetText("")
	end
	UI.Ink(you.x, dim and C.dim or C.text)
	UI.Ink(you.y, dim and C.dim or C.text)

	-- The offer: the following view was moved by hand and has come to rest with you out of sight.
	keep.on = map ~= nil and T.db.follow == true and View.Astray() and x ~= nil and not dim
		and not View.SeesYou() and not View.Busy()

	mouse.on = false
	if map and T.db.coords == true and View.Port():IsMouseOver() and not plate:IsMouseOver() then
		local cx, cy = View.Cursor()
		if cx then
			Say(mouse, cx, cy)
			mouse.on = true
		end
	end
end

local function Build()
	-- The look switch: one plate on the bar, its two halves inside it.
	bar = CreateFrame("Frame", nil, View.Window())
	bar:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	bar:SetSize(LOOK_W * 2, TALL)
	bar:SetPoint("TOPRIGHT", View.Strip(), "TOPRIGHT", BAR_X, BAR_Y)
	bar:EnableMouse(true)
	UI.Skin(bar, C.bgHot)
	looks = { Half("drawn", "Map"), Half("terrain", "Terrain") }
	looks[1]:SetPoint("LEFT", bar, "LEFT", 0, 0)
	looks[2]:SetPoint("LEFT", looks[1], "RIGHT", 0, 0)
	Slots()

	-- The corner plate, over the window (never on the overlay). A row comes into view as the plate opens over it.
	plate = CreateFrame("Frame", nil, View.Chrome())
	plate:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 150)
	plate:EnableMouse(true)
	plate:SetClipsChildren(true)
	plate:SetScale(Shy.Maps.OVER)   -- (as everything laid over the map: the map gets the room)
	UI.Panel(plate, { brackets = false })
	plate.height = PAD * 2 + ROW
	plate:SetHeight(plate.height)

	-- How the map follows you, at the foot: not at all, you in the very middle, or smart (a little ahead along your way,
	-- View.lua). Following, the map comes to you at once.
	follow = UI.Segmented(plate, { "Off", "Follow", "Smart" },
		function() return not T.db.follow and 1 or T.db.followSmart and 3 or 2 end,
		function(index)
			T.db.follow, T.db.followSmart = index > 1, index == 3
			ns.Apply()
			if index > 1 then FindMe() end
		end,
		{ width = FOLLOW.wide, height = ROW, tips = {
			"The map stays where you put it.",
			"You stay in the middle of the map.",
			"You stay in view, with some of the way ahead." } })
	follow:ClearAllPoints()
	follow:SetPoint("BOTTOMRIGHT", -PAD, PAD)

	-- Your numbers at the row's left: the button, its hover just round them (HOVER).
	you = CreateFrame("Button", nil, plate)
	you:SetHeight(ROW)
	you:SetPoint("BOTTOMLEFT", PAD - HOVER, PAD)
	Numbers(you, C.text, HOVER)
	UI.Press(you, { fill = C.bgHot, bare = true, sink = { you.x, you.y } })
	you:SetScript("OnClick", FindMe)
	you:SetScript("OnEnter", Tip)
	you:SetScript("OnLeave", function(self) UI.TipHide(self) end)

	-- The offer, over your row: a press keeps the map where you put it (the following goes off).
	keep = CreateFrame("Button", nil, plate)
	keep:SetHeight(ROW)
	Lift(keep, PAD + ROW, HOVER)
	keep.text = UI.Text(keep, "Keep it here", NUMBER, true, C.head)
	keep.text:SetPoint("CENTER")
	UI.KeyPress(keep, { fill = C.fill, words = keep.text, sink = { keep.text } })
	keep:SetScript("OnClick", function()
		T.db.follow = false
		ns.Apply()
	end)
	keep:SetAlpha(0)
	keep:Hide()
	keep.on, keep.h = false, 0

	-- The mouse's row, at the top.
	mouse = CreateFrame("Frame", nil, plate)
	mouse:SetHeight(ROW)
	Numbers(mouse, C.hot, HOVER)
	MouseAt(PAD + ROW)
	mouse:SetAlpha(0)
	mouse.on, mouse.h = false, 0
	plate.follow, plate.you, plate.keep, plate.mouse = follow, you, keep, mouse

	Stand()
	Paint()
end

ns.Layer({
	id = "controls",
	Use = function(on)
		if on and not bar then Build() end
		if bar then
			bar:SetShown(on)
			for _, slot in ipairs(slots) do
				if slot.plate then slot.plate:SetShown(on) end
			end
			plate:SetShown(on)
			Stand()
		end
	end,
	Open = function()
		Stand()
		Paint()
	end,
	Tick = function(dt)
		-- (On the overlay the plate stays with the closed window.)
		if View.Overlaid() then return end
		readIn = readIn - dt
		if readIn <= 0 then
			readIn = READ
			Read()
		end
		-- The plate opens to hold the offer and the mouse's row, and closes after them; the mouse's row
		-- rides up over the offer as it comes.
		local keepH = keep.on and ROW or 0
		if keep.h ~= keepH then
			keep.h = Ease(keep.h, keepH, dt, 0.5)
			keep:SetAlpha(keep.h / ROW)
			keep:SetShown(keep.h > 0)
			MouseAt(PAD + ROW + keep.h)
		end
		local mouseH = mouse.on and ROW or 0
		if mouse.h ~= mouseH then mouse.h = Ease(mouse.h, mouseH, dt, 0.5) end
		local height = PAD * 2 + ROW + keep.h + mouse.h
		if plate.height ~= height then
			plate.height = height
			plate:SetHeight(height)
		end
		local now, want = mouse:GetAlpha(), mouse.on and 1 or 0
		if math.abs(now - want) > 0.001 then mouse:SetAlpha(Ease(now, want, dt, 0.02)) end
	end,
})

ns.OnApply(Paint)
