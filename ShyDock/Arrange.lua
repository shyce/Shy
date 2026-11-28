-- Homes for the HUD boxes while the console layout is active. A home is a
-- box's default position; a box the player moved is never touched.
--
-- DECK boxes stack on the deck's base (Deck.lua) in the system column at the
-- top right, flush with the minimap panel: the map, the deck under it, the
-- rows' tray under that and the objectives under them, down to the console.
-- With no minimap panel the deck stands on the stack over chat's outer end.
-- HOMES places the rest.
-- Everything applies live, and every state matches what a reload would give.
-- Homes aren't saved by the HUD, so they are set again at login, on layout
-- events and for boxes created later. Secure boxes wait for combat to end.

local ADDON, ns = ...
local T = ns.T
local HUD = Shy.HUD

local A = {}
ns.Arrange = A

local GAP = ns.Console.SEAM

-- Box ids stacked in the deck, floor up (the deck stands under the minimap).
local DECK = { "shyquest", "shy.party" }
-- Box ids with a tab in the deck's header. ShyXP's stats stand in no deck: their tab switches the
-- level a deck box shows for them (ShyQuest's strip).
local TABS = { "shyquest", "shyxp", "shy.party" }

-- The top left's column: a farming session (ShyFarm) tight in the corner where how to play stands, and how to
-- play (ShyCore's keys guide) under it while the session shows; with none, how to play has the corner (its own
-- home). In a raid on a classic layout the raid's frames hang from the corner (Layout.lua's GroupAt; the game's
-- party frames too, while they are the ones in use): how to play stands under them, and the session doesn't show.
local FARM, HOW = "shyfarm", "shy.keys.guide"
local TOP_LEFT = ns.Parts.TOP_LEFT   -- how to play's own home, the corner both share

-- The column's top (an offset from the screen's top): the corner, or under the group's frames hanging from it.
local function ColumnTop(g, now)
	if not (now and now.raiding and not (g and g.role)) then return TOP_LEFT.y end
	local frame = IsInRaid() and _G.CompactRaidFrameContainer or _G.PartyFrame
	if not frame then return TOP_LEFT.y end
	local _, bottom = ns.Console.Rect(frame)
	if not bottom then return TOP_LEFT.y end
	return bottom - UIParent:GetHeight() - GAP
end

local function FarmAt(g, now)
	return "TOPLEFT", "TOPLEFT", TOP_LEFT.x, ColumnTop(g, now)
end
local function HowAt(g, now)
	local top = ColumnTop(g, now)
	local farm = HUD.Find(FARM)
	if farm and farm:IsShown() and not HUD.IsPlaced(farm) then
		top = top - farm:GetHeight() * farm:GetScale() - GAP
	elseif top == TOP_LEFT.y then
		return nil   -- its own home, the corner
	end
	return "TOPLEFT", "TOPLEFT", TOP_LEFT.x, top
end

-- ShyThreat's meter while it is on: its piece for the plan (Parts.lua), else nil.
local ThreatPiece = ns.Parts.ThreatPiece

-- The threat meter's slot in the layout in use, and the most rows it shows there: a meter window standing on the
-- damage meter in a classic layout (Parts.lua, P.Threat), by your target in one by role (P.Role). Returns
-- l, b, r, t, rows; nil while ShyThreat is off.
local function ThreatSlot(g, now)
	local piece = ThreatPiece()
	if not piece then return nil end
	if g.role then
		local plan = ns.Parts.Role(g, now, ns.Layout.Fighting(now), piece)
		local r = plan.threat
		return r[1], r[2], r[3], r[4], plan.rows
	end
	return ns.Parts.Threat(g, now, piece)
end

-- The pings and markers' home, a piece of their own: by role, by your target's frames (Parts.lua, P.StripHome);
-- in a classic layout a seam off the cooldown manager's plate on the side the tracked bars aren't (Layout.lua's
-- c.barsSide), standing on its foot. Returns a point, or nil.
local function StripAt(g, now)
	g = g or ns.Console.Build(now)
	local c = ns.Layout.Cockpit(now)
	if g.role then
		local size = ns.Parts.StripSize()
		local plan = size and ns.Parts.Role(g, now, ns.Layout.Fighting(now), ThreatPiece(), size)
		local r = plan and plan.strip
		if r then return "BOTTOMLEFT", "BOTTOM", r[1], r[2] end
		return nil
	end
	local plate = c.rects.box
	if c.barsSide == "right" then return "BOTTOMRIGHT", "BOTTOM", plate[1] - ns.Console.SEAM, plate[2] end
	return "BOTTOMLEFT", "BOTTOM", plate[3] + ns.Console.SEAM, plate[2]
end

-- The minimap column: the deck under the panel (and the rows under it: the micro
-- menu and the bag bar) at the panel's width, the objectives tracker under that.
-- ShyQuest adopts the tracker into the HUD; its art's overhang is Shy.wings.tracker.
local COLUMN_GAP = ns.Console.SEAM
local TRACKER = "shyquest-tracker"

-- By box id, in stacking order from the wing up:
--   at(g, now)   position: box point, screen point, x, y
--   piece        part of the cockpit while `at` returns a slot: docked there with no mover of
--                its own (HUD.SetStill), so it only moves with the cockpit. With no slot the
--                box goes back to its own addon's home, or to `home(g)` when it has one.
--   follows      a piece of its own by the cockpit (not in it): a mover of its own, its home `at` following
--                the cockpit as it moves (Free); while `joins()` says so, a piece of the cockpit at `bay`
--   stack        height reserved in the stack above the chat wing
--   alone        box id that must exist for `stack`; else `at` is used
local HOMES = {
	{ id = "shyrogue-combo",   -- 112 x 14, half out of the cockpit's top edge, at the vessel's size
		piece = true,
		at = function(_, now)
			local c = ns.Layout.Cockpit(now)
			local slot = c.rects.blades
			if slot then return "BOTTOMLEFT", "BOTTOM", slot[1], slot[2], c.scales.blades end
		end },
	{ id = ns.Parts.STRIP_ID,   -- the pings and markers: a piece of their own, never in the cooldown manager (StripAt)
		follows = true,
		at = function(g, now) return StripAt(g, now) end,
		-- Joined to the plate (a setting): in its bay at the plate's end, which grows under it while it is up
		-- (Layout.lua's Bay), a piece of the cockpit.
		joins = function() return T.db.joined end,
		bay = { at = function(_, now)
			if not ns.Cockpit.rect then return nil end
			local bay = ns.Layout.Cockpit(now).strip
			return "BOTTOMLEFT", "BOTTOM", bay.left, bay.bottom
		end } },
	{ id = "shyskin.durability",   -- the armor stand: a seam left of the minimap column's head (Parts.lua, P.Stand)
		at = function(_, now)
			local box = HUD.Find("shyskin.durability")
			local scale = box:GetScale()
			local _, _, r, t = ns.Parts.Stand(now, box:GetWidth() * scale, box:GetHeight() * scale)
			return "TOPRIGHT", "BOTTOM", r, t
		end },
	{ id = "shywarrior-shout",   -- a shout that stands on no button: centered over the cockpit's plate
		at = function(_, now)
			if not ns.Cockpit.rect then return "CENTER", "CENTER", 0, -140 end
			local plate = ns.Layout.Cockpit(now).rects.box
			return "BOTTOM", "BOTTOM", (plate[1] + plate[3]) / 2, plate[4] + 3 * GAP
		end },
	{ id = "shythreat",   -- a meter window on the damage meter at its width, growing up; by role, by your target
		at = function(g, now)
			local l, b, r, t = ThreatSlot(g, now)
			if not l then return nil end
			if g.role then return "TOPLEFT", "BOTTOM", l, t end
			return "BOTTOMRIGHT", "BOTTOM", r, b
		end,
		width = function(g, now)
			local l, _, r = ThreatSlot(g, now)
			return l and r - l or nil
		end },
	{ id = FARM, at = FarmAt },   -- the top left's corner (ShyFarm's session)
	{ id = HOW, at = HowAt },     -- how to play: under the session while it shows, else its own corner
	{ id = "shyrogue-poisons", stack = 134 },
	{ id = "shyrogue-lockboxes", stack = 90 },
	{ id = "shyxp", stack = 150,                   -- last, so its reserved height costs nothing while hidden
		alone = "shyquest", at = function() return "TOPRIGHT", "TOPRIGHT", -310, -230 end },
}

local original = setmetatable({}, { __mode = "k" })   -- box -> the home its own addon gave it
local watched = setmetatable({}, { __mode = "k" })    -- deck boxes hooked for OnShow/OnHide/OnSizeChanged
local waiting, soon
local room   -- tracker height last set here (see Tracker); nil while Blizzard owns its height
local theirs -- tracker height Blizzard last set, restored by LetGo
local fitted = setmetatable({}, { __mode = "k" })     -- box -> its width before the column resized it
local loose  -- the tracker's screen clamp is off (see Clamp)

-- Blizzard keeps resetting the tracker to its Edit Mode height, in combat too
-- (see Tracker). Clamped to the screen, a tracker too tall for its room is
-- pushed up over the deck. So while its height is set here the clamp is off:
-- too tall, it runs off the bottom of the screen instead. Never call while Held.
local function Clamp(tracker, on)
	if on == not loose then return end
	loose = not on
	tracker:SetClampedToScreen(on)
end

-- The tracker can't be touched in combat while it is protected, which it is
-- only while something secure is parented to it (its own quest item buttons aren't).
local function Held(tracker)
	return InCombatLockdown() and tracker:IsProtected()
end

-- Hand the tracker back to Blizzard: its own anchors and its own height. Waits while Held.
local function LetGo()
	local tracker = HUD.Find(TRACKER)
	if not tracker or not (room or tracker.given) then
		room = nil
		return
	end
	if Held(tracker) then
		waiting = true
		return
	end
	room = nil
	if tracker.given then HUD.SetHome(tracker, nil) end
	if theirs and math.abs(tracker:GetHeight() - theirs) > 0.5 then tracker:SetHeight(theirs) end
	Clamp(tracker, true)
end

-- Give deck boxes and the deck their own widths back.
local function Unfit()
	for box, width in pairs(fitted) do
		fitted[box] = nil
		HUD.Fit(box, width, true)
	end
	ns.Deck.Fit(ns.Console.DECK)
end

local function Same(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

-- Returns false when the player has placed the box. scale: the size the home comes at (a cockpit piece's).
-- A placed box is given its home all the same (it stays where the player has it): let go of within
-- reach of it, Shy.HUD puts it back, and it is arranged again.
local function Home(box, point, scale)
	if box.foreign then return false end
	original[box] = original[box] or box.defaultPoint
	if not Same(box.defaultPoint, point) or box.givenScale ~= scale then HUD.SetHome(box, point, scale) end
	return not HUD.IsPlaced(box)
end

-- Restore the home the box's own addon gave it.
local function GiveBack(box)
	local point = original[box]
	if not point then return end
	original[box] = nil
	HUD.SetDocked(box, false)
	HUD.SetCarried(box, false)
	HUD.SetStill(box, false)
	if not Same(box.defaultPoint, point) then HUD.SetHome(box, point) end
end

-- A cockpit piece (see HOMES). g: the console's plan, for a piece with a home outside the cockpit.
-- While the cockpit is taken apart (Pieces.lua) a piece keeps a mover of its own.
local function Piece(box, def, now, g)
	local point, screenPoint, x, y, scale = def.at(nil, now)
	if not point then
		if def.home and g then
			HUD.SetDocked(box, false)
			HUD.SetStill(box, false)
			Home(box, { def.home(g) })
		else
			GiveBack(box)
		end
		return
	end
	local apart = ns.Pieces ~= nil and ns.Pieces.Apart()
	HUD.SetStill(box, not apart)   -- still: also drops any saved position
	Home(box, { point, screenPoint, x, y }, scale)
	HUD.SetDocked(box, true)
end

-- A piece of its own that stands by the cockpit (`follows`, see HOMES): never docked in it, a mover of its own, its
-- home following the cockpit as it moves or changes shape; a place the player gave it stands. g: the console's
-- plan, or nil to make it.
local function Free(box, def, now, g)
	-- Joined, in the plate's bay while the plate is up; with the plate down, at its own home meanwhile.
	if def.joins and def.joins() and def.bay.at(g, now) then return Piece(box, def.bay, now, g) end
	HUD.SetDocked(box, false)
	HUD.SetStill(box, false)
	local point = { def.at(g, now) }
	if not point[1] then return GiveBack(box) end
	Home(box, point)
end

-- The rows of the system column (the micro menu's frame and the bag bar): each is the game's frame adopted
-- into the HUD (ShyCore's Frames.lua), unless the player placed it. They stand in the menu, one HUD box
-- of their own (Drawers.lua's, MENU) holding the drawer's pull and the tray: its home is a seam under
-- `under` (the deck's foot, or nil for the map's), sized to the column where Edit Mode's sliders leave a
-- row wider (Console.Column). The player can drag the menu like any other piece, snapping to what is on
-- the screen; let go of near its home it docks there again. The rows are given homes in the box wherever
-- it stands (anchored to it while it is dragged), and carried by it: no mover of their own. While the
-- drawer is tucked the box is the pull alone and the rows are parked: at their place but PARKED small,
-- so nothing nobody can see takes a click over what the tray slides out over; the drawer's coming out
-- brings them back (Drawers.lua asks, through A.Apply). Returns the plan's column while the menu is
-- docked, else nil (none, or the player has it elsewhere: the column keeps no room for it). A.menu: the
-- menu's box with the bay (the tray under the pull) and the pull, as { left, bottom, right, top } from the box's
-- top right in its own units (A.Live reads them on the screen), and whether the player placed it;
-- A.parked: whether the rows are parked.
local ROWS = { { "MicroMenuContainer", "menu" }, { "BagsBar", "bags" } }
local PARKED = 0.05
local MENU = "shydock-menu"
local rowsGiven = setmetatable({}, { __mode = "k" })   -- box -> given a home here

local function RowBox(name)
	local frame = _G[name]
	local box = frame and HUD.Adopted(frame)
	if box and not HUD.IsPlaced(box) then return box end
end

-- No menu box: it goes from the screen (layout mode too).
local function MenuGone()
	A.menu, A.parked = nil, false
	local box = HUD.Find(MENU)
	if box then HUD.Update(box) end
end

local function RowsBack()
	for box in pairs(rowsGiven) do
		rowsGiven[box] = nil
		HUD.SetCarried(box, false)
		if box.given then HUD.SetHome(box, nil) end
	end
	MenuGone()
end

-- A rect kept from the menu box's top right in its own units, on the screen now (UIParent units): docked,
-- from its home (exact, whenever it is asked); placed or dragged, from where the frame stands. nil while
-- the box can't be read.
function A.Live(rel)
	local box = A.menu and A.menu.box
	if not (box and rel) then return nil end
	local k = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local right, top
	if not A.menu.placed and not HUD.IsDragging(box) then
		local p = box.defaultPoint
		right, top = UIParent:GetWidth() + p[3], UIParent:GetHeight() + p[4]
	else
		right, top = box:GetRight(), box:GetTop()
		if right == nil or top == nil then return nil end
		right, top = right * k, top * k
	end
	return right + rel[1] * k, top + rel[2] * k, right + rel[3] * k, top + rel[4] * k
end

-- A row the player has elsewhere keeps its home, where it would stand with the others: let go of within
-- reach of it (Shy.HUD), it is a row of the tray again. kept: box -> true for the rows homed in the tray;
-- every other row's home is dropped.
local function RowsAway(now, under, kept)
	local half, H = now.screen / 2, now.height
	local full
	for _, def in ipairs(ROWS) do
		local frame = _G[def[1]]
		local box = frame and HUD.Adopted(frame)
		if box and not kept[box] and now.column[def[2]] and HUD.IsPlaced(box) then
			full = full or ns.Console.Column({ screen = now.screen, height = now.height, map = now.map, column = now.column,
				drawer = now.drawer, tucked = now.tucked }, under, true)
			local rect = full[def[2]]
			local point = { "TOPRIGHT", "TOPRIGHT", rect[3] - half, rect[4] - H }
			local was = box.given
			if not (was and was[1] == point[1] and math.abs(was[3] - point[3]) < 0.01 and math.abs(was[4] - point[4]) < 0.01) then
				HUD.SetHome(box, point)
			end
			HUD.SetCarried(box, false)
			rowsGiven[box] = true
			kept[box] = true
		end
	end
	for box in pairs(rowsGiven) do
		if not kept[box] then
			rowsGiven[box] = nil
			HUD.SetCarried(box, false)
			if box.given then HUD.SetHome(box, nil) end
		end
	end
end

local function Rows(now, under)
	local menu = HUD.Find(MENU)
	local rows, boxes = {}, {}
	for _, def in ipairs(ROWS) do
		local box = now.column[def[2]] and RowBox(def[1])
		if box then rows[def[2]], boxes[def[2]] = now.column[def[2]], box end
	end
	if next(rows) == nil or not menu then
		RowsAway(now, under, {})
		MenuGone()
		return nil
	end
	local column = ns.Console.Column({ screen = now.screen, height = now.height, map = now.map, column = rows,
		drawer = now.drawer, tucked = now.tucked }, under, true)
	local parked = ns.Drawers ~= nil and ns.Drawers.Parked() == true
	local half, H = now.screen / 2, now.height
	-- The menu's home: the tray's top right (the pull's top with a drawer). Tucked it is the pull alone, so
	-- what is arranged round it lines up with what shows; out (or being arranged) the pull and the tray.
	local right, top = column.right, column.pull and column.pull[4] or column.tray[4]
	local tall = (column.pull and now.tucked and not HUD.IsUnlocked()) and ns.Console.PULL or top - column.tray[2]
	-- Not while it is dragged: given its home then, it would jump back to it under the mouse.
	local towing = HUD.IsDragging(menu)
	if not towing then
		HUD.Resize(menu, right - column.tray[1], tall)
		Home(menu, { "TOPRIGHT", "TOPRIGHT", right - half, top - H })
	end
	local function Rel(rect) return { rect[1] - right, rect[2] - top, rect[3] - right, rect[4] - top } end
	A.menu = { box = menu, placed = HUD.IsPlaced(menu), pull = column.pull and Rel(column.pull) or nil }
	HUD.Update(menu)
	-- The rows in the box as it stands: their homes follow it; while it is dragged they hang on it.
	local k = menu:GetScale()
	wipe(A.rowFit)
	for key, box in pairs(boxes) do
		local rel = Rel(column[key])
		local fit = column.scale[key] * k
		A.rowFit[box] = math.abs(fit - 1) > 0.001 and fit or false
		local scale = parked and PARKED or (math.abs(fit - 1) > 0.001 and fit or nil)
		local _, _, r, t = A.Live(rel)
		if not r then r, t = column[key][3] + half, column[key][4] end
		if towing then
			local own = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
			HUD.Attach(box, menu, "TOPRIGHT", "TOPRIGHT", rel[3] * k / own, rel[4] * k / own)
		else
			local point = { "TOPRIGHT", "TOPRIGHT", r - UIParent:GetWidth(), t - UIParent:GetHeight() }
			local was = box.given
			if not (was and was[1] == point[1] and math.abs(was[3] - point[3]) < 0.01 and math.abs(was[4] - point[4]) < 0.01)
				or box.givenScale ~= scale then
				HUD.SetHome(box, point, scale)
			else
				HUD.Apply(box)   -- off the box it hung on while dragged, back on its home
			end
		end
		HUD.SetCarried(box, true)   -- the menu's mover moves it
		rowsGiven[box] = true
	end
	A.menu.bay = Rel(column.tray)
	local kept = {}
	for _, box in pairs(boxes) do kept[box] = true end
	RowsAway(now, under, kept)
	A.parked = parked
	if A.menu.placed then return nil end
	return column
end

-- The rows parked or brought back where they stand, as a fight begins or ends: their scale alone changes, so
-- that is all that is set. Nothing else on the screen is arranged again. (Anything more: A.Apply.)
A.rowFit = setmetatable({}, { __mode = "k" })   -- row box -> its scale in the column, unparked (false: none)
function A.Park()
	local menu = A.menu and A.menu.box
	if not menu or HUD.IsDragging(menu) then return A.Apply() end
	local parked = ns.Drawers ~= nil and ns.Drawers.Parked() == true
	if parked == A.parked then return end
	for box, fit in pairs(A.rowFit) do
		if box.given then HUD.SetHome(box, box.given, parked and PARKED or fit or nil) end
	end
	A.parked = parked
end

function A.MenuPlaced()
	local menu = HUD.Find(MENU)
	return menu ~= nil and HUD.IsPlaced(menu)
end

-- The racks' bars follow their docks (Rack.lua's Dock): one whose wing the player has moved out of its place
-- gets a home beside the action bars, through Shy.HUD (the bar is the game's, adopted by ShyCore's
-- Frames.lua; it is protected, so in a fight the move waits for the fight to end); back in its place, the
-- home is dropped and the bar is where the layout has it again. A bar the player placed is left alone.
local racksGiven = setmetatable({}, { __mode = "k" })   -- box -> given a home here

local function RacksBack(keep)
	local moved = false
	for box in pairs(racksGiven) do
		if not (keep and keep[box]) then
			racksGiven[box] = nil
			if box.given then HUD.SetHome(box, nil) end
			moved = true
		end
	end
	return moved
end

local function Racks(g)
	local keep, moved = {}, false
	if g.rack.kind == "rack" then
		for _, side in ipairs({ 1, -1 }) do
			local bar = g.rack.rects[side] and ns.Layout.RackBar(side)
			local box = bar and HUD.Adopted(bar)
			if box and not HUD.IsPlaced(box) then
				local dock = ns.Rack.Dock(g, side)
				if not dock.home then
					keep[box] = true
					local point = { side > 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", "BOTTOM", dock.inner, dock.bottom }
					local was = box.given
					if not (was and was[1] == point[1] and math.abs(was[3] - point[3]) < 0.01 and math.abs(was[4] - point[4]) < 0.01) then
						HUD.SetHome(box, point)
						moved = true
					end
					racksGiven[box] = true
				end
			end
		end
	end
	if RacksBack(keep) then moved = true end
	if moved then ns.Rack.Touch() end
end

local function Restore()
	for box in pairs(original) do GiveBack(box) end
	Unfit()
	LetGo()
	RowsBack()
	if RacksBack() then ns.Rack.Touch() end
end

local function Watch(box)
	if watched[box] then return end
	watched[box] = true
	box:HookScript("OnShow", A.Soon)
	box:HookScript("OnHide", A.Soon)
	box:HookScript("OnSizeChanged", A.Soon)
end

-- ShySkin's minimap panel as left, bottom, right, top; nil without one.
local function Panel()
	local skin = Shy.addons.Skin
	if not (skin and skin.MinimapPanel) then return nil end
	return skin:MinimapPanel()
end

-- Tracker(right, y, floor): art top at `y`, right edge at `right`, height down to `floor`.
-- Blizzard resets the tracker to its Edit Mode height (800 by default) whenever
-- it is shown again (ObjectiveTrackerContainerMixin:OnShow, UpdateHeight) and
-- from ManageFramePositions, in combat too. So the height set here is kept in
-- `room` and re-applied after each UpdateHeight (KeepRoom, hooked in A.Start).
local TRACKER_MIN = 120

local function KeepRoom(frame)
	local height = frame:GetHeight()
	if not issecretvalue(height) then theirs = height end
	if not room then return end
	if Held(frame) then
		waiting = true
		return
	end
	if math.abs(frame:GetHeight() - room) > 0.5 then frame:SetHeight(room) end
end

local function Tracker(right, y, floor)
	local tracker = HUD.Find(TRACKER)
	if not tracker then
		room = nil
		return
	end
	if HUD.IsPlaced(tracker) then
		-- Placed by the player: give it Blizzard's height back.
		if room and Held(tracker) then
			waiting = true
			return
		end
		if room and theirs and math.abs(tracker:GetHeight() - theirs) > 0.5 then tracker:SetHeight(theirs) end
		room = nil
		Clamp(tracker, true)
		-- Its home in the column is kept all the same: let go of within reach of it, it is the column's again.
		if not Held(tracker) then
			local reach = Shy.wings.tracker or { 0, 0, 0, 0 }
			local x, top = right - reach[3] - UIParent:GetWidth(), y + reach[2] - UIParent:GetHeight()
			local was = tracker.given
			if not (was and math.abs(was[3] - x) < 0.01 and math.abs(was[4] - top) < 0.01) then
				HUD.SetHome(tracker, { "TOPRIGHT", "TOPRIGHT", x, top })
			end
		end
		return
	end
	if Held(tracker) then return end
	if not room then theirs = tracker:GetHeight() end
	local reach = Shy.wings.tracker or { 0, 0, 0, 0 }
	local height = math.max(TRACKER_MIN, y - floor - reach[2] - reach[4])
	room = height
	Clamp(tracker, false)
	if math.abs(tracker:GetHeight() - height) > 0.5 then tracker:SetHeight(height) end
	HUD.SetHome(tracker, { "TOPRIGHT", "TOPRIGHT", right - reach[3] - UIParent:GetWidth(), y + reach[2] - UIParent:GetHeight() })
end

local function On()
	return T.db.arrange and ns.Layout.IsActive()
end


-- Later files (Auras.lua) register a callback run on every Apply, so this file
-- never calls one that a reload hasn't loaded yet.
local also = {}
A.On = On
function A.Also(fn)
	also[#also + 1] = fn
end

-- Boxes among `ids` that exist, have a toggle, aren't secure, and pass toggle.wanted.
local function Boxes(ids)
	local list = {}
	for _, id in ipairs(ids) do
		local box = HUD.Find(id)
		if box and box.toggle and not box.secure and not (box.toggle.wanted and not box.toggle.wanted()) then
			list[#list + 1] = box
			Watch(box)
		end
	end
	return list
end

-- Is there a box the deck could hold? Without one its switch changes nothing.
function A.Decks()
	for _, id in ipairs(DECK) do
		local box = HUD.Find(id)
		if box and box.toggle and not box.secure then return true end
	end
	return false
end

-- The chat wing's measured outer end (chat may have been resized in Edit Mode);
-- the plan's value if chat no longer meets the housing. In the open layout
-- chat stands alone in the corner: its own left edge.
local function ChatEnd(g)
	-- In the corner layouts the deck's place is the plan's, whatever chat's width.
	if g.line then return g.deck.left end
	local planned = g.left
	local left, _, width = ChatFrame1:GetScaledRect()
	if left == nil or issecretvalue(left) or issecretvalue(width) then return planned end
	local origin = UIParent:GetScaledRect()
	local scale, middle = UIParent:GetEffectiveScale(), UIParent:GetWidth() / 2
	local reach = Shy.wings.chat
	local right = (left + width - origin) / scale - middle
	if math.abs(right - g.chat.right) > 2 then return planned end
	local rack = g.rack.left and g.rack.width + ns.Console.SEAM or 0
	return (left - origin) / scale - middle - (reach and reach[1] or 0) - rack
end

-- Base at (x, y), boxes stacked on it, header above. Returns the column's top;
-- if the player moved the base, the boxes stack there and y is returned unused.
local function Deck(x, y)
	local boxes = Boxes(DECK)
	local base = ns.Deck.Show(Boxes(TABS))
	if not base then return y end
	local scale = base:GetScale()
	local free
	-- During a drag the boxes are anchored to the base.
	local towing = HUD.IsDragging(base)
	if towing or not Home(base, { "BOTTOMLEFT", "BOTTOM", x, y }) then
		free = y
		x, y = base:GetLeft() * scale - UIParent:GetWidth() / 2, base:GetBottom() * scale
	end
	local floor = y
	y = y + base:GetHeight() * scale
	local top, edges = y, {}
	for _, box in ipairs(boxes) do
		-- (A box in the deck has no place of its own: one kept from before, when a box could be taken out, is let go.)
		if HUD.IsPlaced(box) then HUD.Forget(box) end
		local docked
		if towing then
			docked = true
			HUD.Attach(box, base, "BOTTOMLEFT", "BOTTOMLEFT", 0, (y - floor) / box:GetScale())
		else
			docked = Home(box, { "BOTTOMLEFT", "BOTTOM", x, y })
		end
		HUD.SetDocked(box, docked)
		HUD.SetCarried(box, docked)   -- docked, the deck's mover moves it; no mover of its own
		if docked and box:IsShown() then
			if y > top then edges[#edges + 1] = y - top end
			y = y + box:GetHeight() * box:GetScale()
		end
	end
	y = y + ns.Deck.Stand(y - top, edges) * scale
	return free or y
end

-- Dragging a box fires no event, and neither does the minimap panel moving or a box's switch coming on offer,
-- so Deck.lua polls A.Watch, which compares this signature.
-- The signature is a list of plain values, filled in place (it is looked at twice a second): nothing is made.
local taken, looked = {}, {}

local function Taken(into)
	local n = 0
	for _, id in ipairs(DECK) do
		local box = HUD.Find(id)
		n = n + 1
		into[n] = box and HUD.IsPlaced(box) and true or false
	end
	for _, id in ipairs(TABS) do
		local box = HUD.Find(id)
		local toggle = box and box.toggle
		n = n + 1
		into[n] = toggle and not (toggle.wanted and not toggle.wanted()) and true or false
	end
	local base = ns.Deck.base
	local placed = HUD.IsPlaced(base)
	n = n + 4
	into[n - 3], into[n - 2], into[n - 1], into[n] = placed, placed and math.floor(base:GetLeft() + 0.5) or false,
		placed and math.floor(base:GetBottom() + 0.5) or false, placed and base:GetScale() or false
	local left, bottom, right = Panel()
	n = n + 3
	into[n - 2], into[n - 1], into[n] = left and math.floor(left + 0.5) or false, left and math.floor(bottom + 0.5) or false,
		left and math.floor(right + 0.5) or false
	for i = n + 1, #into do into[i] = nil end
	return into
end

function A.Watch()
	Taken(looked)
	for i = 1, math.max(#looked, #taken) do
		if looked[i] ~= taken[i] then return A.Soon() end
	end
end

local columnRoom   -- the minimap column's height for the deck, under the map and over the rows; nil with the deck off

-- For a deck box that can lay itself out shorter (ShyQuest's quest window, ShyThreat's rows): the height it
-- may take, in its own units. The column's room less the deck's header and foot and the other boxes in
-- it. nil while the deck is off.
function T:DeckRoom(box)
	local base = ns.Deck.base
	if not columnRoom or not base then return nil end
	local room = columnRoom - (base:GetHeight() + ns.Deck.Head()) * base:GetScale()
	for _, other in ipairs(Boxes(DECK)) do
		if other ~= box and other:IsShown() then room = room - other:GetHeight() * other:GetScale() end
	end
	return math.max(200, room / box:GetScale())
end

local function Stack()
	for _, fn in ipairs(also) do fn() end
	if not (On() and T.db.deck) then ns.Deck.Hide() end
	if not On() then
		if InCombatLockdown() then
			waiting = true
			return
		end
		waiting = nil
		Restore()
		return
	end
	Taken(taken)
	local g, now = ns.Layout.Plan()
	Racks(g)
	-- y: above the chat wing, clear of the small unit frames on it. In the corner
	-- layouts chat's top is on the corners' line; the small frames stand on it too where the screen is too
	-- narrow for them beside the plates.
	local y = ns.Parts.StackFloor(g, now)
	-- The minimap column comes down to the console (in the corner layouts to the roof, chat's and the meter's top),
	-- and stops over the threat meter where that stands on the damage meter under it.
	local columnFoot = y + GAP
	local left = ChatEnd(g)
	local panelLeft, panelBottom, panelRight = Panel()
	if panelLeft then
		local half = now.screen / 2
		columnFoot = ns.Parts.ColumnClear(g, now, ThreatPiece(), columnFoot, panelLeft - half, panelRight - half)
	end
	-- The system column, flush with the minimap panel: the deck under the map, the rows (the micro menu and the
	-- bag bar, Console.Column) under the deck while it stands there, else under the map, and the objectives under
	-- them, down to the console. The menu the player has elsewhere keeps no room in it.
	local column = ns.Console.Column(now, nil, true)
	local rowsTall = (column.rows > 0 and not A.MenuPlaced()) and column.rows + COLUMN_GAP or 0
	-- (The objectives under the rows keep their least: the deck lays itself out in what is left.)
	columnRoom = T.db.deck and panelLeft and panelBottom - COLUMN_GAP - rowsTall - (TRACKER_MIN + COLUMN_GAP) - columnFoot or nil
	if panelLeft then
		local foot
		local base = T.db.deck and ns.Deck.Show(Boxes(TABS))
		if base then
			-- The deck's height is summed first, so its foot is known before it is stood (Deck stacks up from it).
			local width = panelRight - panelLeft
			ns.Deck.Fit(width)
			local scale = base:GetScale()
			-- (Its header's height depends on whether a box shows in it: the closed deck is the header alone.)
			local tall, open = base:GetHeight() * scale, false
			for _, box in ipairs(Boxes(DECK)) do
				fitted[box] = fitted[box] or box:GetWidth()
				HUD.Fit(box, width / box:GetScale())
				if box:IsShown() then
					tall = tall + box:GetHeight() * box:GetScale()
					open = true
				end
			end
			tall = tall + ns.Deck.Head(open) * scale
			local bottom = panelBottom - COLUMN_GAP - tall
			-- Where it was put (not moved by the player): the rows under it, the objectives under them.
			if Deck(panelRight - width - now.screen / 2, bottom) > bottom then
				local under = Rows(now, bottom)   -- (a seam under it: Console.Column keeps it)
				foot = (under and under.foot or bottom) - COLUMN_GAP
			end
		end
		-- No deck over them (off, none to show, or the player moved it): the rows under the map.
		if not foot then
			local under = Rows(now, nil)
			local mapFoot = A.MenuPlaced() and ns.Console.Column({ screen = now.screen, height = now.height, map = now.map }).foot
			foot = (under and under.foot or mapFoot or ns.Console.Column(now).foot) - COLUMN_GAP
		end
		Tracker(panelRight, foot, columnFoot)
	else
		-- No minimap panel (ShySkin's minimap skin off, or the map round): the rows under the map, the objectives
		-- Blizzard's, and the deck beside chat's outer end on the floor, or where there's no room for it there, on
		-- the stack over chat (which goes on above it).
		LetGo()
		Rows(now, nil)
		if T.db.deck then
			Unfit()
			local beside = left - ns.Console.SEAM - ns.Console.DECK
			if beside >= -now.screen / 2 then
				Deck(beside, g.floor)
			else
				local top = Deck(left, y)
				if top > y then y = top + GAP end
			end
		end
	end
	if not T.db.deck then
		Unfit()
		for _, id in ipairs(DECK) do
			local box = HUD.Find(id)
			if box then
				HUD.SetDocked(box, false)
				HUD.SetCarried(box, false)
			end
			if box and original[box] then
				local point = original[box]
				original[box] = nil
				if not Same(box.defaultPoint, point) then HUD.SetHome(box, point) end
			end
		end
	end
	if InCombatLockdown() then
		waiting = true
		return
	end
	waiting = nil
	for _, def in ipairs(HOMES) do
		local box = HUD.Find(def.id)
		if box then
			if def.piece then
				Piece(box, def, now, g)
			elseif def.follows then
				Free(box, def, now, g)
			elseif def.stack and not (def.alone and not HUD.Find(def.alone)) then
				if Home(box, { "BOTTOMLEFT", "BOTTOM", left, y }) then y = y + def.stack + GAP end
			else
				local point = { def.at(g, now) }
				if not point[1] then
					GiveBack(box)
				elseif Home(box, point) and def.width then
					-- At home, as wide as its slot (the threat meter: the damage meter's width, or its role's).
					local width = def.width(g, now)
					if width then HUD.Fit(box, width / box:GetScale()) end
				end
			end
		end
	end
end

-- The threat meter's most rows in its slot (ShyThreat's card asks): fewer where the minimap column over it would
-- be left too little room, or the role asks for fewer. nil while the console isn't in use.
function T:MeterRows()
	if not On() then return nil end
	local g, now = ns.Layout.Plan()
	local _, _, _, _, rows = ThreatSlot(g, now)
	return rows
end

-- Where ShyFrames' frames stand in a layout by role (Parts.lua, P.Role): by kind ("player", "target",
-- "targettarget", "focus", "pet", "party") a home { point, "BOTTOM", x, y }, with `partyShape` ("row" or
-- "column") and `partyWidth` (how wide the party's place is, in screen units: the group's, or its own by your
-- frames, the plan's partyAt). nil in a classic layout, or while the console isn't in use: ShyFrames' own homes
-- stand.
function T:UnitHomes()
	if not On() then return nil end
	local g, now = ns.Layout.Plan()
	if not g.role then return nil end
	local plan = ns.Parts.Role(g, now, ns.Layout.Fighting(now))
	local G = plan.partyAt
	local homes = { partyShape = plan.party, partyWidth = G[3] - G[1] }
	for _, key in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
		local r = plan[key]
		homes[key] = { "BOTTOM", "BOTTOM", (r[1] + r[3]) / 2, r[2] }
	end
	-- The healer's party is a row along its place's foot (under your character, nearest the bars), centred there;
	-- elsewhere a column hung from its place's top by the side nearest the middle, where your frames are, so
	-- cells the player made narrower or wider keep their gap to them.
	if plan.party == "row" then
		homes.party = { "BOTTOM", "BOTTOM", (G[1] + G[3]) / 2, G[2] }
	elseif G[1] + G[3] < 0 then
		homes.party = { "TOPRIGHT", "BOTTOM", G[3], G[4] }
	else
		homes.party = { "TOPLEFT", "BOTTOM", G[1], G[4] }
	end
	return homes
end

local stacking   -- inside A.Apply: a box it resizes is looked at again next frame, not at once

function A.Apply()
	stacking = true
	Stack()
	stacking = false
	-- The rows may have moved: their drawer's handle follows.
	if ns.Drawers then ns.Drawers.Touch() end
end

-- A docked box given a new size (HUD.Resize): the deck is stacked again at once, so the box
-- never shows a frame at its old foot with its new height.
local function Resized(box)
	-- (The session grew as loot came: how to play under it moves down with its foot.)
	if box.id == FARM then return A.Soon() end
	for _, id in ipairs(DECK) do
		if box.id == id then
			if stacking or not box.docked then A.Soon() else A.Apply() end
			return
		end
	end
end

-- Called every frame while the cockpit is dragged (Move.lua).
function A.Follow(now)
	if not On() or InCombatLockdown() then return end
	for _, def in ipairs(HOMES) do
		local box = (def.piece or def.follows) and HUD.Find(def.id)
		if box and def.piece then Piece(box, def, now) elseif box then Free(box, def, now) end
	end
end

-- At setup: every box goes back to its place and its size (a piece scaled by its corner as well as the game's
-- frames, back to the console's sizes). Windows keep theirs.
function A.TakeIn()
	if not T.db.arrange then return end
	HUD.Each(function(box)
		if not box.window then HUD.Forget(box, true) end
	end)
end

-- Apply next frame, once: a box being filled resizes several times in a frame.
function A.Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = nil
		A.Apply()
	end)
end

-- The cockpit moved or changed shape (a fight's cooldowns came, a cast opened its row): what is docked to it
-- follows, and nothing else is arranged again, since nothing else stands by it. In a fight the pieces wait
-- for its end with the rest (a whole Apply then).
local piecesSoon
local function Pieces()
	piecesSoon = nil
	if soon then return end   -- a whole Apply is coming this frame
	for _, fn in ipairs(also) do fn() end
	if not On() then return A.Apply() end
	if InCombatLockdown() then
		-- (Only the pieces wait: after the fight they follow, and the rest stays as it stands.)
		waiting = waiting or "pieces"
		return
	end
	if waiting == "pieces" then waiting = nil end
	local g, now = ns.Layout.Plan()
	for _, def in ipairs(HOMES) do
		local box = (def.piece or def.follows) and HUD.Find(def.id)
		if box and def.piece then Piece(box, def, now, g) elseif box then Free(box, def, now, g) end
	end
end
function A.PiecesSoon()
	if piecesSoon or soon then return end
	piecesSoon = true
	C_Timer.After(0, Pieces)
end

function A.Start()
	local events = CreateFrame("Frame")
	events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")   -- a raid's frames come to the top left's corner, or leave it
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("UI_SCALE_CHANGED")
	events:RegisterEvent("DISPLAY_SIZE_CHANGED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if waiting == "pieces" then Pieces() elseif waiting then A.Apply() end
		else
			A.Soon()
		end
	end)
	Shy:On("SHY_LOGIN", A.Apply)
	EventRegistry:RegisterCallback("EditMode.Exit", A.Soon, A)
	-- The minimap panel settles a moment after login.
	C_Timer.After(1, A.Soon)
	-- The minimap made square or round: its panel appears or goes, and the column with it.
	hooksecurefunc(Shy, "SetMinimapShape", A.Soon)
	Shy:On("SHY_HUD_LAYOUT", A.Soon)
	Shy:On("SHY_COCKPIT", A.PiecesSoon)   -- a piece docked to the box follows it up and down
	Shy:On("SHY_DRAWER", A.Soon)    -- the menu's drawer pinned open or tucked: the column under it moves
	Shy:On("SHY_THREAT_PIECE", A.Soon)   -- the threat meter on or off, or its rows: its slot and the column over it move
	Shy:On("SHY_FARM_PIECE", A.Soon)     -- the farming session's planned size: how to play stands under it
	-- A session begun or ended: how to play goes under it, or back to its corner.
	Shy:On("SHY_FARM", function(why) if why == "start" or why == "stop" then A.Soon() end end)
	Shy:On("SHY_HUD_MOVING", function(box)
		if box == ns.Deck.base or box == HUD.Find(MENU) then A.Apply() end
	end)
	-- A piece let go of: the deck, one of its boxes taken out or put back, a row, a piece of the game's
	-- dragged in layout mode (chat or the meter out of its place, or back: the racks dock by what is there).
	-- Whatever it was, what stands with it is arranged again.
	Shy:On("SHY_HUD_MOVED", A.Soon)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", A.Soon, A)
	Shy:On("SHY_HUD_RESIZED", Resized)
	hooksecurefunc(HUD, "Create", A.Soon)   -- boxes created after login
	local tracker = ObjectiveTrackerFrame
	if tracker and type(tracker.UpdateHeight) == "function" then hooksecurefunc(tracker, "UpdateHeight", KeepRoom) end
end
