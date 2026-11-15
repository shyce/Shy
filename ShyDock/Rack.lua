-- The racks: housings behind the side action bars, one at each wing's outer end
-- (in the open layout, a shelf at each end of the housing).
--
-- Like the housing, a rack follows its bar by reading its rectangle: never
-- anchored to it (the bar is protected) and never drawn on it (a bar measures
-- its regions to lay out). It shows only while the console layout is active and
-- the bar is in its slot; a bar the player moved elsewhere gets none.
--
-- Docking. A rack stands beside its host, the outermost piece of the console that
-- is really there on its side. In the console the plan has that as the wing
-- (Console.Host: the damage meter at the right, chat at the left). What is
-- there is looked at, not assumed: a wing standing beside the housing (its inner
-- end within REACH of a seam off the housing's side, its foot within REACH of
-- the floor) is docked, wherever exactly the player left it, and its rack docks
-- to its outer end as that stands, however wide the wing is now. A wing anywhere
-- else is not part of the console, so its rack docks to the action bars
-- instead, a seam off the housing's side where the wing stood, and goes back
-- when the wing does (Arrange.lua moves the bar through Shy.HUD). While a wing
-- is dragged within reach, the two edges that will meet light up in the accent:
-- the wing's inner edge and the housing's side. Let go of there, a wing dragged
-- as a piece of Shy.HUD's snaps into its place. R.Watch notices a wing that
-- moved with no event to say so.

local ADDON, ns = ...
local T = ns.T
local UI, Theme, Console = Shy.UI, Shy.Theme, ns.Console
local abs, floor, max = math.abs, math.floor, math.max

local R = {}
ns.Rack = R

local SETTLE = 0.3
local SLACK = 3        -- a bar within this of its slot counts as in it
local REACH = 20       -- a wing within this of its place beside the housing docks to it
local WATCH = 0.5      -- seconds between looks at the wings
local LIGHT = 2        -- a lit edge: the piece's own border, this wide
local BRIGHT = 0.75    -- on the accent's ramp: between the accent (0.5) and its light (1)
local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }

-- Layout.RackBar decides which bar each rack holds.
local RACKS = {
	{ key = "right", side = 1 },
	{ key = "left", side = -1 },
}
-- The console's wings: the game's frame, its Edit Mode system, and its art's reach in Shy.wings.
local WINGS = {
	[1] = { frame = "DamageMeter", system = "DamageMeter", wing = "meter" },
	[-1] = { frame = "ChatFrame1", system = "ChatFrame", wing = "chat" },
}

local SIDE_BARS = { "MultiBarRight", "MultiBarLeft" }   -- Layout.RackBar's
local racks = {}    -- key -> frame
local lights = {}   -- side -> { wing = frame, host = frame }: the lit edges
local driver, pending
local dragging = false   -- a piece of the game's is being dragged as one of Shy.HUD's

-- Docking

-- The wing on this side as it stands: its window and its art's reach round it, as { left, bottom, right,
-- top } with x from the screen's centre. nil when it can't be seen (hidden, or its rectangle secret).
local function WingRect(side)
	local def = WINGS[side]
	local frame = rawget(_G, def.frame)
	if not frame then return nil end
	local left, bottom, right, top = Console.Rect(frame)
	if not left then return nil end
	local reach = Shy.wings[def.wing] or {}   -- { left, top, right, bottom }
	local half = UIParent:GetWidth() / 2
	-- Chat lifts from its foot while its edit box is open, inside its art, which stays where it is.
	bottom = bottom - Shy.HUD.Lifted(frame)
	return { left - (reach[1] or 0) - half, bottom - (reach[4] or 0), right + (reach[3] or 0) - half, top + (reach[2] or 0) }
end

-- A wing that can't be seen is taken to be where the console's setup put it unless the player moved it
-- since (in Edit Mode: the layout says; or by dragging it: Shy.HUD says).
local function Anchored(side)
	local def = WINGS[side]
	local system = Enum.EditModeSystem[def.system]
	if system == nil or not ns.Layout.InPlace(system) then return false end
	local frame = rawget(_G, def.frame)
	local box = frame and Shy.HUD.Adopted(frame)
	return not (box and Shy.HUD.IsPlaced(box))
end

-- How far the wing stands from its place beside the housing: its inner end from a seam off the housing's
-- side, and its foot from the floor.
local function Off(g, side, wing)
	local h = g.housing
	local inner = side > 0 and wing[1] or wing[3]
	local beside = side > 0 and h.right + Console.SEAM or h.left - Console.SEAM
	return abs(inner - beside), abs(wing[2] - g.floor)
end

-- Is the wing on this side docked: standing beside the housing? Returns that, and the wing's rectangle
-- when it can be seen.
function R.WingThere(g, side)
	local wing = WingRect(side)
	if not wing then return Anchored(side), nil end
	local across, up = Off(g, side, wing)
	return across <= REACH and up <= REACH, wing
end

-- Does the plan have a wing on this side for a rack to stand beside? (Only the console does.)
local function HasWing(g, side)
	if Console.CORNERS[g.style] then return false end
	local host, h = Console.Host(g, side), g.housing
	return not (host[1] == h.left and host[3] == h.right)
end

-- Where the rack on this side docks:
--   inner, bottom   its bar's inner edge as x from the screen's centre, and its bottom
--   host            { left, bottom, right, top } of what it stands beside (x from the centre)
--   home            true where the layout has it; false while it is docked somewhere else (the action
--                   bars, or a wing that stands a little off its place or is wider than it was)
function R.Dock(g, side)
	local slot = g.rack.slots[side]
	local dock = { inner = slot[1], bottom = slot[2], host = Console.Host(g, side), home = true }
	if g.rack.kind ~= "rack" or not HasWing(g, side) then return dock end
	local h = g.housing
	local there, wing = R.WingThere(g, side)
	if there and wing then
		-- Beside the wing as it stands.
		dock.host = wing
		dock.inner = side > 0 and wing[3] + Console.SEAM + Console.PAD or wing[1] - Console.SEAM - Console.PAD
	elseif not there then
		dock.host = { h.left, h.bottom, h.right, h.top }
		dock.inner = side > 0 and h.right + Console.SEAM + Console.PAD or h.left - Console.SEAM - Console.PAD
	end
	dock.home = abs(dock.inner - slot[1]) < 0.5
	return dock
end

-- The lit edges: while the screen is being arranged (Edit Mode, or a piece dragged), a wing within reach
-- of its place but not in it yet shows that it will dock: its inner border and the housing's border on that
-- side turn a brighter accent. Each light lies inside its own piece's edge, so it is the border that
-- changes color, with the seam between the two left dark.
local function Arranging()
	return dragging or EditModeManagerFrame:IsEditModeActive()
end

-- `x` is the piece's edge; `inward` is the way into the piece from it (1 rightward, -1 leftward).
local function Edge(frame, x, inward, bottom, top)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", inward > 0 and x or x - LIGHT, bottom)
	frame:SetSize(LIGHT, max(1, top - bottom))
	frame:Show()
end

local function Lights(g)
	local half = UIParent:GetWidth() / 2
	for _, side in ipairs({ 1, -1 }) do
		local pair = lights[side]
		local lit = false
		if pair and g and Arranging() and HasWing(g, side) then
			local there, wing = R.WingThere(g, side)
			if there and wing then
				local across, up = Off(g, side, wing)
				-- In its place already: nothing to say.
				if across > 0.5 or up > 0.5 then
					local h = g.housing
					Edge(pair.wing, half + (side > 0 and wing[1] or wing[3]), side, wing[2], wing[4])
					Edge(pair.host, half + (side > 0 and h.right or h.left), -side, h.bottom, h.top)
					lit = true
				end
			end
		end
		if pair and not lit then
			pair.wing:Hide()
			pair.host:Hide()
		end
	end
end

-- Whether the edges on this side are lit.
function R.Lit(side)
	local pair = lights[side]
	return pair ~= nil and pair.wing:IsShown() and pair.host:IsShown()
end

-- A wing let go of within reach of its place snaps into it: dragged as a piece of Shy.HUD's (its title, or
-- in layout mode) it is handed back to the layout, which has it there. (One moved in Edit Mode is Edit
-- Mode's to place: it docks where it was left.)
local function Seat(box)
	if not (box and box.foreign and ns.Layout.IsActive()) then return end
	local g = ns.Layout.Plan()
	for _, side in ipairs({ 1, -1 }) do
		local def = WINGS[side]
		local system = Enum.EditModeSystem[def.system]
		if box.foreign == rawget(_G, def.frame) and HasWing(g, side) and Shy.HUD.IsPlaced(box) then
			if R.WingThere(g, side) and system ~= nil and ns.Layout.InPlace(system) then Shy.HUD.Forget(box) end
		end
	end
end

-- A wing moved, came or went: nothing says so (the meter is dragged by its title at any time), so the
-- wings are looked at twice a second, and what follows them is told when one has changed.
-- The wings as last looked at: four whole numbers a side, or false for a wing not seen. Compared in place.
local watched
local SIDES = { 1, -1 }
function R.Watch()
	local first = watched == nil
	watched = watched or {}
	local changed = false
	for s, side in ipairs(SIDES) do
		local wing = WingRect(side)
		for i = 1, 4 do
			local v = wing and floor(wing[i] + 0.5) or false
			local at = (s - 1) * 4 + i
			if watched[at] ~= v then
				watched[at] = v
				changed = true
			end
		end
	end
	if first or not changed or not ns.Layout.IsActive() then return end
	R.Touch()
	ns.Arrange.Soon()
end

-- The racks

local function Measure(def, g)
	local rack = racks[def.key]
	local bar = g and T.db.housing and ns.Layout.RackBar(def.side)
	if not bar then
		rack:Hide()
		return
	end
	local left, bottom, right, top = Console.Rect(bar)
	if left == false then return end   -- secret rect: keep the last position
	if not left then
		rack:Hide()
		return
	end
	if not (g.rack[def.key] and g.rack.rects[def.side]) then
		rack:Hide()   -- no room for a rack on this screen, or a row in the housing (Console.Build)
		return
	end
	local middle = UIParent:GetWidth() / 2
	local dock = R.Dock(g, def.side)
	local inner, foot = dock.inner, dock.bottom
	local edge = def.side > 0 and left or right
	if abs(edge - middle - inner) > SLACK or abs(bottom - foot) > SLACK then
		rack:Hide()   -- the bar isn't at its dock: the player moved it, or it is on its way there
		return
	end
	-- From the plan's foot to its top: the wings' in the console, the housing's foot to the shelf's top in the open layout.
	rack:ClearAllPoints()
	rack:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - Console.PAD, g.rack.foot)
	rack:SetSize(right - left + 2 * Console.PAD, g.rack.top - g.rack.foot)
	-- The bar's buttons are its content: a look with a well sinks them, its rim round them.
	UI.LookContent(rack.shyLook, { Console.PAD, g.rack.top - top, Console.PAD, bottom - g.rack.foot })
	rack:Show()
end

function R.Measure()
	local g = ns.Layout.IsActive() and ns.Layout.Plan() or nil
	for _, def in ipairs(RACKS) do Measure(def, g) end
	Lights(g)
	if ns.Drawers then ns.Drawers.Sync() end   -- the racks' drawers follow their racks
end

function R.Touch()
	if pending then return end
	pending = true
	C_Timer.After(0, R.Measure)
	C_Timer.After(SETTLE, function()
		pending = nil
		R.Measure()
	end)
end

function R.Apply()
	for _, rack in pairs(racks) do UI.SetFill(rack, ns.Graphite) end
	R.Measure()
end

-- A lit edge: a border's width of the accent a tone brighter, over everything, taking no mouse.
local function Bright()
	return Theme.Ramp(BRIGHT)
end

local function Light()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(60)
	f:EnableMouse(false)
	f:Hide()
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetAllPoints()
	UI.Paint(f.line, Bright, 1)
	return f
end

function R.Start()
	for _, def in ipairs(RACKS) do
		local rack = CreateFrame("Frame", "ShyDockRack" .. def.key:gsub("^%l", string.upper), UIParent)
		-- LOW, like the housing: under the bar's buttons (MEDIUM).
		rack:SetFrameStrata("LOW")
		rack:SetFrameLevel(30)
		rack:EnableMouse(false)
		rack:Hide()
		UI.Panel(rack, { cap = true, facets = false, line = false, brackets = 10 })
		racks[def.key] = rack
		lights[def.side] = { wing = Light(), host = Light() }
	end
	R.frames, R.lights = racks, lights

	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:SetScript("OnEvent", function(_, event)
		-- A fight beginning moves no side bar unless one is shown in fights only (or out of them) in Edit Mode.
		if event == "PLAYER_REGEN_DISABLED" and not ns.Layout.FightShows(SIDE_BARS) then return end
		R.Touch()
	end)
	hooksecurefunc("MultiActionBar_Update", R.Touch)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", R.Touch, R)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		driver:SetScript("OnUpdate", R.Measure)
	end, R)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		driver:SetScript("OnUpdate", nil)
		R.Touch()
	end, R)
	Shy:On("SHY_CONSOLE", R.Touch)
	-- A Blizzard frame dragged in layout mode (or by a handle of Shy.HUD's, as the meter's title) is followed
	-- as in Edit Mode; let go of within reach of its place, a wing snaps into it.
	Shy:On("SHY_HUD_MOVING", function(box)
		if box.foreign then
			dragging = true
			driver:SetScript("OnUpdate", R.Measure)
		end
	end)
	Shy:On("SHY_HUD_MOVED", function(box)
		dragging = false
		if not EditModeManagerFrame:IsEditModeActive() then driver:SetScript("OnUpdate", nil) end
		Seat(box)
		R.Measure()
		R.Touch()
	end)
	C_Timer.NewTicker(WATCH, R.Watch)
end
