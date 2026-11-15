-- The console's drawers (Shy.Drawer): the menu's tray under the guide, and the racks beside the dock.
--
-- "menu": the micro menu and the bag bar in a tray of the console's make, as wide as the column. Pull and
-- tray are one HUD box, the menu (W.box): Arrange.lua docks it a seam under the guide while the deck
-- stands in the minimap column, else under the minimap, and stands the rows in it wherever it is. The
-- player drags it like any other piece (by its pull too, as a window by its title bar), and it snaps
-- to what is on the screen. In a drawer (T.db.menuDrawer) the tray
-- is tucked by default: its pull, the piece's header (Shy.Drawer heads the panel with it), is all that
-- shows; the tray slides down out of the pull under the mouse, over what hangs below, and pinned out it takes its
-- room and the column moves down for it. Tucked, the rows are parked (Arrange.lua sizes them down to
-- nothing at their place, through Shy.HUD), so no button nobody can see is clicked over the
-- objectives; they are brought back as the drawer starts out. With the drawer switched off (or the
-- arranging, which it needs) the tray is held out, with no pull (and drawn only while the bar housing is on).
--
-- "rack-right" / "rack-left": each side bar in its rack, out by default. The pull is a grip astride
-- the seam between the rack and its host, the piece it stands beside (the dock in the corner layouts;
-- in the console the wing at that end: the damage meter, or chat): it fills the gap between them, is
-- as tall as the host, and belongs to it: it shows only while the mouse is on the host (or on the
-- grip or the rack). The right rack slides out rightward from it and tucks back leftward, the left
-- one the other way. The drawer's sliding panel is the rack's own
-- rectangle exactly (the rack's panel, Rack.lua, is kept out of sight meanwhile), so out it stands
-- as the rack does: on the dock's floor, with the dock's pad. The stack has no racks and no rack drawers.
--
-- Like the housing and racks, a drawer follows the game's frames by reading their rectangles, never
-- anchored to them; a bar is protected, and is only ever faded.

local ADDON, ns = ...
local T = ns.T
local Console = ns.Console
local max, min = math.max, math.min

local W = {}
ns.Drawers = W

local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }

local menu, racks = nil, {}
local driver

-- No bag row while ShyBags stands the default bar down (its bags are in its window).
local function BagsGone()
	local bags = Shy.addons.Bags
	return bags ~= nil and bags.owns.bagbar == true
end

-- The tray under the pull: where Arrange.lua stands it in the menu's box (A.menu.bay: it homes the rows, and
-- parks them small while the drawer is tucked, so their own rectangles say nothing then), read where the box
-- is now; else a pad round the rows as they stand; nil with neither on screen; false while a rect is secret.
local function MenuRect()
	local tray = ns.Arrange.menu
	if tray then return ns.Arrange.Live(tray.bay) end
	local l, b, r, t = nil, nil, nil, nil
	for _, frame in ipairs({ _G.MicroMenuContainer, not BagsGone() and BagsBar or nil }) do
		local fl, fb, fr, ft = Console.Rect(frame)
		if fl == false then return false end
		if fl then
			l, b = min(l or fl, fl), min(b or fb, fb)
			r, t = max(r or fr, fr), max(t or ft, ft)
		end
	end
	if not l then return nil end
	local pad = Console.PAD
	return l - pad, b - pad, min(UIParent:GetWidth(), r + pad), t + pad
end

-- The menu's pull: the tray's header, the top of the menu's box (Console.Column's pull), as wide as the tray.
-- With the rows not in the box (Shy.HUD hasn't taken them): flush on the tray's top, never wider than the
-- minimap's panel it hangs under.
local function MenuGrip()
	local tray = ns.Arrange.menu
	if tray then
		if not tray.pull then return nil end
		return ns.Arrange.Live(tray.pull)
	end
	local l, _, r, t = MenuRect()
	if not l then return nil end
	local skin = Shy.addons.Skin
	if skin and skin.MinimapPanel then
		local pl, _, pr = skin:MinimapPanel()
		if pl and pl < r and pr > l then l, r = max(l, pl), min(r, pr) end
	end
	return l, t, r, t + Console.PULL
end

local function MenuFrames()
	return { _G.MicroMenuContainer, not BagsGone() and BagsBar or nil }
end

local function RackRect(key)
	local rack = ns.Rack.frames[key]
	if not (rack and rack:IsShown()) then return nil end
	local l, b = rack:GetLeft(), rack:GetBottom()
	if l == nil or b == nil then return nil end
	return l, b, l + rack:GetWidth(), b + rack:GetHeight()
end

-- A rack's grip (Console.Grip): astride the seam on the rack's inner side, as tall as the rack's host,
-- the piece it stands beside (Console.Host: the dock in the corner layouts; in the console the wing,
-- the meter or chat). The host's place is kept, in screen units, for Near.
local hosts = {}

local function RackGrip(key, side)
	local l, _, r = RackRect(key)
	if not l then
		hosts[key] = nil
		return nil
	end
	-- The host is what the rack is docked beside now (Rack.lua: the wing, or the action bars while the wing
	-- is out of its place).
	local host = ns.Rack.Dock(ns.Layout.Plan(), side).host
	local half = UIParent:GetWidth() / 2
	hosts[key] = { host[1] + half, host[2], host[3] + half, host[4] }
	local centre = (side > 0 and l or r) - side * Console.SEAM / 2
	return centre - Console.GRIP / 2, host[2], centre + Console.GRIP / 2, host[4]
end

-- The mouse on a rack's host: its grip shows only then (or with the mouse on the grip or the rack).
local function Near(key)
	local host = hosts[key]
	if not host then return false end
	local x, y = GetCursorPosition()
	if x == nil or issecretvalue(x) or issecretvalue(y) then return false end
	local scale = UIParent:GetEffectiveScale()
	x, y = x / scale, y / scale
	return x >= host[1] and x <= host[3] and y >= host[2] and y <= host[4]
end

-- The tucked rows are parked (Arrange.lua): the drawer on and all the way in. Never in a fight, where a
-- frame of the game's may not be sized: they wait at their place then, out of sight under a catcher.
local fighting = false
function W.Parked()
	return menu ~= nil and menu.on and not fighting and T.db.menuDrawer and T.db.arrange
		and menu.want ~= true and menu.level <= 0
end

-- The drawer starts out, or is all the way in: the rows are brought back, or parked, at once.
local function Rehang()
	if ns.Arrange.On() then ns.Arrange.Apply() end
end

-- (A piece in hand, the guide sized by its foot over the menu: the column is stacked again on every frame of
-- it, and the menu's pull and tray, which stand by coordinates, go with it in that same frame.)
function W.Touch()
	if menu then
		if Shy.HUD.InHand and Shy.HUD.InHand() then menu:Measure() end
		menu:Touch()
	end
	for _, d in pairs(racks) do d:Touch() end
end

-- The racks moved, came or went: their drawers follow, as they are (one out under the mouse stays out).
function W.Sync()
	for _, d in pairs(racks) do d:Sync() end
end

function W.Apply()
	if not Shy.Drawer then return end
	if menu then menu:Apply() end
	for _, d in pairs(racks) do d:Apply() end
end

-- A rack's drawer out ("right" or "left"), as the console's layout keeps it; out until it is in use.
function W.RackOut(key)
	local d = racks[key]
	if not (d and ns.Layout.IsActive()) then return true end
	return d:IsOpen() == true
end

-- Setup's picks for the racks ({ right = out, left = out }): pinned while the console's layout is in use
-- (a drawer's pin is kept per layout). Returns whether they could be.
function W.PinRacks(sides)
	if not ns.Layout.IsActive() then return false end
	for key, d in pairs(racks) do
		if sides[key] ~= nil and d:IsOpen() ~= sides[key] then d:Pin(sides[key]) end
	end
	return true
end

function W.Start()
	if not Shy.Drawer then return end
	-- The menu's box: pull and tray as one piece of the HUD. It draws nothing (the drawer does) and takes no
	-- mouse but its mover's in layout mode and the pull's; Arrange.lua sizes it and gives it its home.
	W.box = Shy.HUD.Create({
		id = "shydock-menu", title = "Menu", name = "ShyDockMenu",
		width = Console.DECK, height = Console.PULL, hang = true, grip = false,
		point = { "TOPRIGHT", "TOPRIGHT", -Console.CORNER, -300 },   -- placeholder until Arrange.lua gives it a home
		shown = function() return ns.Arrange.menu ~= nil end,
		away = function() return ns.Arrange.menu == nil end,
	})
	menu = Shy.Drawer.Create({
		id = "menu", title = "Menu", side = "top", default = "tucked", over = true, pad = 0,
		frames = MenuFrames, rect = MenuRect, grip = MenuGrip, carry = W.box,
		shown = function() return ns.Layout.IsActive() end,
		held = function() return not (T.db.menuDrawer and T.db.arrange) end,
		paneled = function() return (T.db.menuDrawer and T.db.arrange) or T.db.housing end,
		catch = function() return not ns.Arrange.parked end,
		onOut = Rehang, onTucked = Rehang,
		help = "The game's menu and your bags. They slide out while you point here.",
	})
	-- Dragged, the menu's pull, panel and catcher are placed again each frame: they stand by coordinates.
	local follow = CreateFrame("Frame")
	local function Follow() menu:Measure() end
	Shy:OnFor("SHY_HUD_MOVING", W.box, function() follow:SetScript("OnUpdate", Follow) end)
	Shy:OnFor("SHY_HUD_MOVED", W.box, function() follow:SetScript("OnUpdate", nil) end)
	-- A rack slides out away from the dock: the right one's grip is on its left, the left one's on its right.
	for key, side in pairs({ right = 1, left = -1 }) do
		racks[key] = Shy.Drawer.Create({
			id = "rack-" .. key, title = "Side bar", side = side > 0 and "left" or "right", default = "open", pad = 0,
			frames = function()
				local bar = T.db.housing and ns.Layout.IsActive() and ns.Layout.RackBar(side)
				return { bar or nil }
			end,
			rect = function() return RackRect(key) end,
			grip = function() return RackGrip(key, side) end,
			near = function() return Near(key) end,
			housing = ns.Rack.frames[key],
			shown = function() return ns.Layout.IsActive() and ns.Rack.frames[key]:IsShown() == true end,
			help = "Click to put this bar away, or to bring it back.",
		})
	end
	for _, name in ipairs({ "MicroMenuContainer", "BagsBar" }) do
		local frame = _G[name]
		if frame and frame.Layout then hooksecurefunc(frame, "Layout", W.Touch) end
	end
	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:SetScript("OnEvent", function(_, event)
		-- A fight begins: the parked rows are brought back while they still may be; after it they are parked again.
		-- Rows that aren't parked (the drawer pinned out, or no drawer) have nothing to change as it begins.
		if event == "PLAYER_REGEN_DISABLED" then
			fighting = true
			if not ns.Arrange.parked then return end
			Rehang()
			menu:Measure()   -- the catcher over them, at once
		elseif event == "PLAYER_REGEN_ENABLED" then
			fighting = false
			Rehang()
			menu:Measure()
		end
		W.Touch()
	end)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", W.Touch, W)
	EventRegistry:RegisterCallback("EditMode.Exit", W.Touch, W)
	Shy:On("SHY_HUD_MOVED", W.Touch)
	Shy:On("SHY_CONSOLE", W.Touch)
	Shy:On("SHY_BAGS_OWNS", function(piece)
		if piece == "bagbar" then W.Apply() end
	end)
	W.Apply()
	-- Setup's picks for the racks wait for its reload when the layout they're for wasn't in use yet (ns.char.sides),
	-- once the game has handed out its layouts.
	if ns.char.sides then
		C_Timer.After(5, function()
			if ns.char.sides and W.PinRacks(ns.char.sides) then ns.char.sides = nil end
		end)
	end
end
