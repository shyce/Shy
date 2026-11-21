-- Taking the cooldown manager apart: a mode within layout mode (or alongside Edit
-- Mode) where every piece of the vessel (the game's frames Move.lua adopts, the swing row, a rogue's
-- blades) has a mover of its own, standing where it is. The vessel keeps its whole shape meanwhile,
-- every socket drawn as an outline. The stand-in gives way to a grey shell of the cooldown manager off
-- to the side of the screen's open middle (HUD.Room): its own panel on a right-click (Put together, Put
-- all back), and a piece let go on it goes back in. A piece let go within reach of its socket, or over
-- the plate, is seated again; anywhere else it is loose: its own box from then on, placed and sized by
-- the player (ns.char.loose, kept by Shy.HUD). Put together (or leaving layout mode), the vessel
-- reshapes around what is seated.
--
-- A free piece (Move.FREE: the cast bar) works so all the time: its own handle in layout mode, seated or not,
-- and in Edit Mode; while it is in hand its socket shows, lit as it comes within reach.
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
local STILL = 4        -- a piece let go within this of where it was picked up wasn't moved
local SHELL_W, SHELL_H = 300, 56   -- the cooldown manager's shell while it is taken apart
-- Boxes of ShyDock's and ShyRogue's own that are pieces: key -> HUD box id, and their names.
local OWN = { swing = "shydock-swing", blades = "shyrogue-combo" }
local TITLES = { swing = "Swing timer", blades = "Combo points" }
-- Which of the plan's rects is a piece's socket (the rest share their key).
local RECT = { essential = "gems", cast = "cast" }

local apart = false
local shell          -- the cooldown manager's grey shell while it is taken apart
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

-- The sockets: a seat waiting for its piece is the vessel's own recess (the slot art of Cockpit.lua), empty (a
-- name in it would read as a second piece); it lights gold, with a glow, as the piece in hand comes within reach.
-- A seated piece's socket is only a faint outline, so the piece reads as seated.

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
	sockets[key] = f
	return f
end

local function Paint(key, f, gold)
	-- A piece in hand has left its seat: its socket waits for it.
	local loose = ns.char.loose[key] or (tracking ~= nil and tracking.key == key)
	f.hollow:SetShown(loose)
	f.well:SetShown(loose)
	f.glow:SetShown(loose and gold)
	f.outline:SetShown(not loose)
	UI.Tint(f.hollow, gold and C.alert or Theme.skin.metal, 0.85)
end

local function Holder()
	if not holder then
		holder = CreateFrame("Frame", "ShyDockSockets", UIParent)
		holder:SetAllPoints(UIParent)
		holder:SetFrameStrata("HIGH")
		holder:SetFrameLevel(40)   -- under the movers
		holder:EnableMouse(false)
	end
	return holder
end

-- Draws every socket from plan `c` (the last one when nil). Shown while apart, and a free piece's while it
-- is in hand.
function P.Refresh(c)
	if c then plan = c end
	local only = not apart and tracking and tracking.key or nil
	if not ((apart or only) and plan) then return end
	Holder()
	local middle = UIParent:GetWidth() / 2
	local used = {}
	-- The swing timer's seat is the cast bar's row: one socket for the two, the swing's only while it alone is out.
	local shared = plan.rects.swing ~= nil and plan.rects.cast ~= nil
	local swingOwns = shared and ns.char.loose.swing == true and not ns.char.loose.cast
	Each(function(key)
		local r = plan.rects[RECT[key] or key]
		if key == "bars" then r = plan.rects.barsWing end
		if only ~= nil and only ~= key then r = nil end
		if shared and only == nil and ((key == "swing" and not swingOwns) or (key == "cast" and swingOwns)) then r = nil end
		if r then
			local f = sockets[key] or Socket(key)
			f:ClearAllPoints()
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", middle + r[1], r[2])
			f:SetSize(math.max(1, r[3] - r[1]), math.max(1, r[4] - r[2]))
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

local Shelve

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

-- Is the middle of the piece over the cooldown manager's plate (as planned, its row open)? Let go there, it goes
-- back in: nothing is left lying on top of it.
local function Over(box)
	local l, b, w, h = Rect(box)
	local r = plan and plan.rects.box
	if not (l and r) then return false end
	local x, y = l + w / 2 - UIParent:GetWidth() / 2, b + h / 2
	return x >= r[1] and x <= r[3] and y >= math.min(r[2], plan.low or r[2]) and y <= r[4]
end

-- Is the middle of the piece over the cooldown manager's shell (taken apart)? Let go there, it goes back in.
local function OnShell(box)
	if not (apart and shell) then return false end
	local l, b, w, h = Rect(box)
	local sl, sb, sw, sh = Rect(shell)
	if not (l and sl) then return false end
	local x, y = l + w / 2, b + h / 2
	return x >= sl and x <= sl + sw and y >= sb and y <= sb + sh
end

-- Let go where it was picked up (a click, or a drag of a hair): nothing changes, as it was before.
local function Unmoved(from, box)
	local l, b = Rect(box)
	return from ~= nil and l ~= nil and abs(l - from[1]) <= STILL and abs(b - from[2]) <= STILL
end

P.Watching = Watch   -- (each frame of a drag: the socket lit as the piece in hand comes within reach)

local function Dropped(box, key, from, wasLoose)
	if Unmoved(from, box) then
		ns.char.loose[key] = wasLoose
		if not wasLoose then HUD.Forget(box) end
	elseif Near(box, key) or Over(box) or OnShell(box) then
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

-- The shell: the cooldown manager while it is taken apart, grey, at the side of the screen's open middle (what
-- no piece stands in, whatever the screen's size and the layout), so it lies on nothing. It is the cooldown
-- manager's own piece meanwhile: its panel and menu are the stand-in's.
function Shelve()
	if not shell or HUD.IsPlaced(shell) then return end
	local left, bottom, _, top = HUD.Room(shell)
	HUD.SetHome(shell, { "LEFT", "BOTTOMLEFT", left, (bottom + top) / 2 })
end

local function Shell()
	shell = HUD.Create({
		id = "shydock-shell", title = "Cooldown manager",
		width = SHELL_W, height = SHELL_H,
		point = { "CENTER", "CENTER", 0, 0 },   -- placeholder: Shelve seats it
		shown = function() return false end,      -- in layout mode only,
		away = function() return not apart end,    -- and only while it is taken apart
		grey = function() return "Taken apart  \194\183  drop a piece here to put it back" end,
	})
	shell.ownSize = true
	shell.panel = function(...) return P.Panel(...) end
	shell.menu = function(root) if ns.Move.handle.menu then ns.Move.handle.menu(root) end end
	P.shell = shell
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
	Holder()
	for key, id in pairs(OWN) do
		local box = HUD.Find(id)
		if box then HUD.SetStill(box, false) end
	end
	ns.Cockpit.SetApart(true)
	HUD.Update(ns.Move.handle)
	Shelve()
	HUD.Update(shell)
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
	if shell then HUD.Update(shell) end
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
		-- Taken out from a menu, it waits under the cooldown manager (Move.lua) to be placed: never on its plate.
		ns.char.loose[key] = "wait"
		if box then
			if box.foreign then box.given, box.placed = nil, nil end
			HUD.SetStill(box, false)
			HUD.Forget(box, true)
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
		UI.Help(v.apart, "Take apart", "Every piece gets its own handle. Drag one away to take it out, or back onto its socket to put it back.")
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
	local key = KeyOf(box)
	if not key or not (apart or ns.Move.FREE[key]) then return end
	local l, b = Rect(box)
	tracking = { box = box, key = key, from = l and { l, b } or nil, wasLoose = ns.char.loose[key] }
	if not driver then
		driver = CreateFrame("Frame")
		driver:SetScript("OnUpdate", Watch)
	end
	driver:Show()
	P.Refresh()
	Watch()   -- lit at once when picked up within reach
end

local function LetGo(box)
	if not (tracking and tracking.box == box) then return end
	local key, from, wasLoose = tracking.key, tracking.from, tracking.wasLoose
	tracking = nil
	if driver then driver:Hide() end
	if not apart and holder then holder:Hide() end
	Dropped(box, key, from, wasLoose)
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

-- Pieces left out where they don't belong come back in, as the vessel is laid out (Move.Sync, plan `c`): a bar
-- this character has nothing in, or one lying on the cooldown manager's plate (left there before a piece let go
-- over it went back in, or moved there in Edit Mode). Not while one is in hand, nor in a fight.
function P.Tidy(c)
	if tracking or InCombatLockdown() then return end
	if c then plan = c end
	for key, how in pairs(ns.char.loose) do
		local box = BoxOf(key)
		if ns.Move.Unused(key) or (box and how ~= "wait" and Over(box)) then
			ns.char.loose[key] = nil
			if box then HUD.Forget(box, true) end
		end
	end
end

function P.Start()
	Shell()
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
