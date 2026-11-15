-- Taking the cooldown manager apart: a mode within layout mode (or alongside Edit
-- Mode) where the stand-in gives way and every piece of the vessel (the game's frames
-- Move.lua adopts, the swing row, a rogue's blades) has a mover of its own. The vessel keeps its whole
-- shape meanwhile, every socket drawn as an outline; a piece let go within reach of
-- its socket is seated again, anywhere else it is loose: its own box from then on,
-- placed and sized by the player (ns.char.loose, kept by Shy.HUD). Put together
-- again, the vessel reshapes around what is seated.
--
-- Also the vessel's own controls on the editor's panel (Move.lua's stand-in): size,
-- the tracked bars' side, Take apart / Put together, Put every piece back.

local ADDON, ns = ...
local T = ns.T
local UI, HUD, Theme = Shy.UI, Shy.HUD, Shy.Theme
local abs, floor = math.abs, math.floor
local C = UI.colors

local P = {}
ns.Pieces = P

local SNAP_SEAT = 24   -- a piece let go within this of its seat is seated again
-- Boxes of ShyDock's and ShyRogue's own that are pieces: key -> HUD box id, and their names.
local OWN = { swing = "shydock-swing", blades = "shyrogue-combo" }
local TITLES = { swing = "Swing timer", blades = "Combo points" }
-- Which of the plan's rects is a piece's socket (the rest share their key).
local RECT = { essential = "gems", cast = "cast" }

local apart = false
local sockets = {}   -- key -> its outline
local holder         -- the outlines' parent
local tracking       -- { box, key } while a piece is in hand
local driver
local plan           -- the plan the outlines were drawn from
local lit            -- the socket lit gold (within reach)

function P.Apart() return apart end

-- Every piece: key, box, title.
local function Each(fn)
	for _, piece in ipairs(ns.Move.pieces) do fn(piece.key, piece.box, piece.title) end
	for key, id in pairs(OWN) do
		local box = HUD.Find(id)
		if box then fn(key, box, TITLES[key]) end
	end
end

local function KeyOf(box)
	local found
	Each(function(key, each)
		if each == box then found = key end
	end)
	return found
end

local function BoxOf(key)
	local found
	Each(function(each, box)
		if each == key then found = box end
	end)
	return found
end

-- A box's rectangle in screen units: left, bottom, width, height; nil when it can't be read.
local function Rect(box)
	local l, b, w, h = box:GetLeft(), box:GetBottom(), box:GetWidth(), box:GetHeight()
	if l == nil or b == nil or w == nil or h == nil then return nil end
	if issecretvalue(l) or issecretvalue(b) or issecretvalue(w) or issecretvalue(h) then return nil end
	local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * s, b * s, w * s, h * s
end

-- Where a piece's seat puts its bottom left corner, in screen units, for a box of its width.
local function SeatOf(key, box)
	if not plan then return nil end
	local point, x, y = ns.Layout.Seat(key, plan)
	if not point then return nil end
	local _, _, w = Rect(box)
	if not w then return nil end
	local left = UIParent:GetWidth() / 2 + x
	if point == "BOTTOMRIGHT" then left = left - w elseif point == "BOTTOM" then left = left - w / 2 end
	return left, y
end

local function Near(box, key)
	local l, b = Rect(box)
	local sl, sb = SeatOf(key, box)
	if not (l and sl) then return false end
	return abs(l - sl) <= SNAP_SEAT and abs(b - sb) <= SNAP_SEAT
end

-- The sockets: a seat waiting for its piece is the vessel's own recess (the slot art of Cockpit.lua) with the
-- piece's name in it, dim; it lights gold, with a glow, as the piece in hand comes within reach. A seated piece's
-- socket is only a faint outline, so the piece reads as seated.

local GLOW_REACH = 2

local function Socket(key)
	local f = CreateFrame("Frame", nil, holder)
	f:EnableMouse(false)
	-- The seat: a darker well with the hover's rim round it (the family's rim round what stands in a housing).
	f.hollow = f:CreateTexture(nil, "BACKGROUND")
	f.hollow:SetAllPoints()
	f.hollow:SetTexture(Shy.MEDIA .. "HoverRim")
	f.hollow:SetTextureSliceMargins(4, 4, 4, 4)
	f.hollow:SetAlpha(0.85)
	f.well = f:CreateTexture(nil, "BACKGROUND", nil, -1)
	f.well:SetAllPoints()
	f.well:SetColorTexture(0, 0, 0, 0.35)
	f.glow = f:CreateTexture(nil, "ARTWORK")
	f.glow:SetPoint("TOPLEFT", -GLOW_REACH, GLOW_REACH)
	f.glow:SetPoint("BOTTOMRIGHT", GLOW_REACH, -GLOW_REACH)
	f.glow:SetTexture(Shy.Skin.GLOW)
	f.glow:SetTextureSliceMargins(Shy.Skin.GLOW_SLICE, Shy.Skin.GLOW_SLICE, Shy.Skin.GLOW_SLICE, Shy.Skin.GLOW_SLICE)
	f.glow:SetBlendMode("ADD")
	UI.Tint(f.glow, C.alert, 0.55)
	f.outline = CreateFrame("Frame", nil, f)
	f.outline:SetAllPoints()
	UI.Skin(f.outline, { 0, 0, 0, 0 }, C.border)
	f.name = UI.Text(f, "", 11, true, C.dim)
	f.name:SetPoint("CENTER")
	f.name:SetWordWrap(false)
	sockets[key] = f
	return f
end

local function Paint(key, f, gold)
	local loose = ns.char.loose[key]
	f.hollow:SetShown(loose)
	f.well:SetShown(loose)
	f.glow:SetShown(loose and gold)
	f.outline:SetShown(not loose)
	UI.Tint(f.hollow, gold and C.alert or Theme.skin.metal, 0.85)
	f.name:SetShown(loose)
	UI.Ink(f.name, gold and C.alert or C.dim)
end

-- Draws every socket from plan `c` (the last one when nil). Shown only while apart.
function P.Refresh(c)
	if c then plan = c end
	if not (apart and plan and holder) then return end
	local middle = UIParent:GetWidth() / 2
	local used = {}
	Each(function(key, _, title)
		local r = plan.rects[RECT[key] or key]
		if key == "bars" then r = plan.rects.barsWing end
		if r then
			local f = sockets[key] or Socket(key)
			f:ClearAllPoints()
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", middle + r[1], r[2])
			f:SetSize(math.max(1, r[3] - r[1]), math.max(1, r[4] - r[2]))
			f.name:SetText(title or key)
			Paint(key, f, lit == key)
			f:Show()
			used[key] = true
		end
	end)
	for key, f in pairs(sockets) do
		if not used[key] then f:Hide() end
	end
	holder:Show()
end

-- In hand

local function Watch()
	local box, key = tracking.box, tracking.key
	local near = Near(box, key)
	local want = near and key or nil
	if want ~= lit then
		lit = want
		for each, f in pairs(sockets) do Paint(each, f, lit == each) end
	end
end

local function Dropped(box, key)
	if Near(box, key) then
		ns.char.loose[key] = nil
		HUD.Forget(box, true)
	else
		ns.char.loose[key] = true
		if box.foreign then box.given = nil end
	end
	lit = nil
	ns.Move.Touch()
	ns.Arrange.Soon()
	T:Apply()
end

-- Entering and leaving

-- Works in layout mode and alongside Edit Mode alike: there Edit Mode drags the game's frames itself,
-- and P.Watch follows its drags.
function P.Enter()
	if apart then return true end
	if InCombatLockdown() then return false end
	if not HUD.IsUnlocked() then HUD.SetUnlocked(true) end
	if not HUD.IsUnlocked() then return false end
	apart = true
	if not holder then
		holder = CreateFrame("Frame", "ShyDockSockets", UIParent)
		holder:SetAllPoints(UIParent)
		holder:SetFrameStrata("HIGH")
		holder:SetFrameLevel(40)   -- under the movers
		holder:EnableMouse(false)
	end
	for key, id in pairs(OWN) do
		local box = HUD.Find(id)
		if box then HUD.SetStill(box, false) end
	end
	ns.Cockpit.SetApart(true)
	HUD.Update(ns.Move.handle)
	ns.Move.Sync()
	ns.Arrange.Soon()
	return true
end

function P.Leave()
	if not apart then return end
	apart = false
	tracking, lit = nil, nil
	if driver then driver:Hide() end
	if holder then holder:Hide() end
	ns.Cockpit.SetApart(false)
	HUD.Update(ns.Move.handle)
	ns.Move.Sync()
	ns.Arrange.Soon()
	T:Apply()
end

function P.Toggle()
	if apart then P.Leave() else P.Enter() end
end

-- Taking a piece out and putting it back

function P.SetLoose(key, loose)
	local box = BoxOf(key)
	if loose then
		ns.char.loose[key] = true
		if box then
			if box.foreign then box.given, box.placed = nil, nil end
			HUD.SetStill(box, false)
			HUD.Release(box)
		end
	else
		ns.char.loose[key] = nil
		if box then HUD.Forget(box, true) end
	end
	ns.Move.Touch()
	ns.Arrange.Soon()
	T:Apply()
end

function P.PutAll()
	for key in pairs(ns.char.loose) do
		local box = BoxOf(key)
		if box then HUD.Forget(box, true) end
	end
	wipe(ns.char.loose)
	ns.Move.Touch()
	ns.Arrange.Soon()
	T:Apply()
end

function P.AnyLoose()
	return next(ns.char.loose) ~= nil
end

-- A piece's menu (its mover's right-click, and Move.lua's stand-in).
function P.Menu(root, piece)
	local key = piece.key
	if ns.char.loose[key] then
		root:CreateButton("Put back in the cooldown manager", function() P.SetLoose(key, false) end)
	else
		root:CreateButton("Take out of the cooldown manager", function() P.SetLoose(key, true) end)
	end
end

-- The vessel's controls on the editor's panel (built once, laid out each time): the bars' side as two
-- chips, the size as a slider, Take apart and Put all back on one row. (Its look is the theme's, picked
-- on /shy.)

local ROW_LABEL = 14   -- a row's label over its choices
local CHIP_H = 26      -- a side's chip
local DESC = {
	side = "Which side the tracked bars hang off.",
}

local function Setting(key)
	return function() return T.db[key] end, function(v)
		T.db[key] = v
		T:Apply()
	end
end

-- A row: its label, then `keys` as buttons `make` builds, each `each` wide; row:Refresh paints the one picked.
local function Row(panel, group, width, label, keys, height, get, set, make, desc)
	local V = ns.Vessel
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(width, ROW_LABEL + height)
	row.label = UI.Text(row, label, 11, false, C.dim)
	row.label:SetPoint("TOPLEFT")
	row.buttons = {}
	local each = (width - (#keys - 1) * 6) / #keys
	for i, key in ipairs(keys) do
		local b = CreateFrame("Button", nil, row)
		b:SetSize(each, height)
		b:SetPoint("TOPLEFT", (i - 1) * (each + 6), -ROW_LABEL)
		b:SetScript("OnClick", function()
			if InCombatLockdown() then return end
			set(key)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			group:Refresh()
		end)
		UI.Help(b, V.NAMES[key], V.WORDS[key] or desc)
		-- The family's button make round the drawing; the pick stays lit (Refresh).
		UI.KeyPress(b, { fill = C.bg })
		make(b, key, each, height)
		row.buttons[key] = b
	end
	function row:Refresh()
		local picked = get()
		for key, b in pairs(self.buttons) do
			local lit = picked == key
			b:SetOn(lit)
			if b.Draw then b:Draw(lit) end
		end
	end
	group:Add(row)
	return row
end

-- A little box of the vessel's make, for a chip's swatch.
local function Little(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	UI.Skin(f, C.panel, Theme.skin.metal)
	return f
end

local function SideChip(b, key)
	local V = ns.Vessel
	local box = Little(b, 18, 14)
	local flap = Little(b, 8, 8)
	box:SetPoint("LEFT", key == "left" and 14 or 5, 0)
	flap:SetPoint(key == "left" and "RIGHT" or "LEFT", box, key == "left" and "LEFT" or "RIGHT", key == "left" and -2 or 2, 0)
	b.name = UI.Text(b, V.NAMES[key], 11, true)
	b.name:SetPoint("RIGHT", -6, 0)
end

function P.Panel(panel, Put, group, width)
	local v = panel.vessel
	if not v then
		v = {}
		local L, V = ns.Layout, ns.Vessel
		local getSide, setSide = Setting("barsSide")
		v.side = Row(panel, group, width, "Tracked bars", V.SIDES, CHIP_H, getSide, setSide, SideChip, DESC.side)
		-- Taken as the knob is let go: every step would lay the whole vessel out again under a knob in the hand,
		-- beside a panel that stands by it.
		local function Size() return floor((T.db.cockpitScale or 1) * 100 + 0.5) end
		v.size = group:Slider(panel, "Size", floor(L.SCALE_MIN * 100 + 0.5), floor(L.SCALE_MAX * 100 + 0.5), floor(L.SCALE_STEP * 100 + 0.5),
			function() return v.asked or Size() end,
			function(x) v.asked = x end,
			{ width = width, format = function(x) return x .. "%" end,
				desc = "Scales the whole cooldown manager, from 75% to 150%.",
				settle = function(x)
					v.asked = nil
					if x ~= Size() then
						T.db.cockpitScale = L.ClampScale(x / 100)
						T:Apply()
					end
				end })
		-- Take apart and Put all back on one row.
		v.actions = CreateFrame("Frame", nil, panel)
		v.actions:SetSize(width, 22)
		local half = (width - 6) / 2
		v.apart = UI.Button(v.actions, "Take apart", half, function()
			P.Toggle()
			group:Refresh()
		end)
		v.apart:SetPoint("LEFT")
		UI.Help(v.apart, "Take apart", "Every piece gets a handle of its own. Drag one away to take it out, or back onto its socket to seat it again.")
		v.all = UI.Button(v.actions, "Put all back", half, function()
			P.PutAll()
			group:Refresh()
		end)
		v.all:SetPoint("RIGHT")
		UI.Help(v.all, "Put all back", "Puts back every piece you took out or moved in Edit Mode.")
		function v.actions:Refresh()
			v.apart:SetLabel(apart and "Put together" or "Take apart")
			v.all:SetUsable(P.AnyLoose(), "Every piece is in place.")
		end
		group:Add(v.actions)
		panel.vessel = v
	end
	Put(v.side, ROW_LABEL + CHIP_H)
	Put(v.size, 38)
	Put(v.actions, 22)
end

-- Settings changed (T:Apply): the outlines follow the plan.
function P.Apply()
	if apart then P.Refresh() end
end

local function Lifted(box)
	if not apart then return end
	local key = KeyOf(box)
	if not key then return end
	tracking = { box = box, key = key }
	if not driver then
		driver = CreateFrame("Frame")
		driver:SetScript("OnUpdate", Watch)
	end
	driver:Show()
end

local function LetGo(box)
	if not (apart and tracking and tracking.box == box) then return end
	local key = tracking.key
	tracking = nil
	if driver then driver:Hide() end
	Dropped(box, key)
end

-- Alongside Edit Mode the game's frames are dragged by Edit Mode itself: its drag's start and end
-- are followed on each piece's frame (post-hooks; not every system frame has them).
local watched = {}
function P.Watch(piece)
	local frame = piece.box.foreign
	if not frame or watched[frame] then return end
	watched[frame] = true
	if type(frame.OnDragStart) == "function" then hooksecurefunc(frame, "OnDragStart", function() Lifted(piece.box) end) end
	if type(frame.OnDragStop) == "function" then hooksecurefunc(frame, "OnDragStop", function() LetGo(piece.box) end) end
end

function P.Start()
	Shy:On("SHY_HUD_LAYOUT", function(on)
		if not on then P.Leave() end
	end)
	Shy:On("SHY_HUD_MOVING", Lifted)
	Shy:On("SHY_HUD_MOVED", LetGo)
	for _, piece in ipairs(ns.Move.pieces) do P.Watch(piece) end
	Shy:On("SHY_COCKPIT", function()
		if apart then P.Refresh() end
	end)
end
