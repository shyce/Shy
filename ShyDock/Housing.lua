-- The housing: a frame behind the bottom action bars.
--
-- The bars are protected, so the housing is never anchored to them (it would
-- become protected in combat): it reads their rectangles and is placed by
-- coordinates. A rect can be secret; then the last good one is kept.
-- Only bars forming one block with the main bar are wrapped. Until the console's
-- layout is in use that block is the game's own row: bars side by side, the menu
-- and the bags beside them. Bars lay out a frame late, so each trigger measures
-- next frame and again after SETTLE; in Edit Mode it measures every frame.
--
-- API:
--   Shy.addons.Dock:HousingRect() -> left, bottom, width, height  (UIParent units; nil with no bottom bar)
--   Shy.addons.Dock:Roof() -> y    top of the wings while the console layout is active, or of the flanks'
--                                  racks; else nil (the other corner layouts have nothing beside the bars)
--   Shy.addons.Dock:WingEdges() -> x, x   inner edges of the left and right wings (or racks), from the screen's center
--   Shy.addons.Dock:Seam() -> the gap between any two pieces
--   Shy.addons.Dock:Reach() -> how far a housing reaches past its bar's sides
--   Shy.addons.Dock:UnderSpan() -> left, right, top   the room kept under the floor (ShyXP's bars), UIParent units
--   "SHY_CONSOLE" on the bus       fired only when the rect or the roof changed

local ADDON, ns = ...
local T = ns.T
local UI, Console = Shy.UI, ns.Console
local max, min = math.max, math.min

local H = {}
ns.Housing = H

-- The side bars count only where they are stacked with the others (the stack layout).
local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }
local MAIN = { "MainActionBar" }
local ROW = { "MicroMenuContainer", "BagsBar" }   -- in the bars' row in the game's own layout
local NEAR = 12        -- bars no further apart than this are one block
local BESIDE = 24      -- side by side in the game's own layout (its two upper bars stand 22 apart)
local SETTLE = 0.3     -- bars have finished laying out by now

local EVENTS = {
	"PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	"UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_BONUS_ACTIONBAR",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
}

local dock, housing, driver
local kit = Shy.Skin.NewKit()

local function AnySecret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-- { left, bottom, right, top } in UIParent units, nil when off screen; second result true when secret.
local function Rect(bar, originX, originY, scale)
	local visible = bar:IsVisible()
	if issecretvalue(visible) then return nil, true end
	if not visible then return end
	local left, bottom, width, height = bar:GetScaledRect()
	if left == nil then return end
	if AnySecret(left, bottom, width, height) then return nil, true end
	return {
		(left - originX) / scale, (bottom - originY) / scale,
		(left + width - originX) / scale, (bottom + height - originY) / scale,
	}
end

-- Stacked on the block: overlapping horizontally and within NEAR vertically. `row`: or beside it in one row,
-- overlapping vertically and within BESIDE horizontally.
local function Touches(rect, block, row)
	local across = min(rect[3], block[3]) - max(rect[1], block[1])
	local narrower = min(rect[3] - rect[1], block[3] - block[1])
	local apart = max(rect[2] - block[4], block[2] - rect[4], 0)
	if across >= narrower / 2 and apart <= NEAR then return true end
	if not row then return false end
	local down = min(rect[4], block[4]) - max(rect[2], block[2])
	local shorter = min(rect[4] - rect[2], block[4] - block[2])
	local aside = max(rect[1] - block[3], block[1] - rect[3], 0)
	return down >= shorter / 2 and aside <= BESIDE
end

-- The block around the main bar (or the lowest bar); `main` alone: the main bar's own. nil with no bar on screen;
-- false when a rect was secret. `loose`: the console's layout isn't the one in use, so the bars stand as the game's
-- layout or the player's own has them: side by side too, the menu and the bags in the row with them, one block.
local function Block(main, loose)
	local originX, originY = UIParent:GetScaledRect()
	local scale = UIParent:GetEffectiveScale()
	local rects = {}
	for i, name in ipairs(main and MAIN or BARS) do
		local rect, secret = Rect(_G[name], originX, originY, scale)
		if secret then return false end
		if rect then
			rect.main = i == 1
			rect.side = i > 3   -- a side bar: beside the block it is a rack of its own, never one of its rows
			rects[#rects + 1] = rect
		end
	end
	if #rects == 0 then return nil end
	local seed = 1
	for i, rect in ipairs(rects) do
		if rect.main then
			seed = i
			break
		end
		if rect[2] < rects[seed][2] then seed = i end
	end
	local block = table.remove(rects, seed)
	-- (The menu and the bags only join a block of bars: with no bar on screen there is none.)
	if loose and not main then
		for _, name in ipairs(ROW) do
			local frame = _G[name]
			-- (One stood down by its rolesets is shown still, and off the screen: ShyBags' way with the bags.)
			if not frame:IsRolesetFiltered() then
				local rect, secret = Rect(frame, originX, originY, scale)
				if secret then return false end
				rects[#rects + 1] = rect
			end
		end
	end
	local grew = true
	while grew do
		grew = false
		for i = #rects, 1, -1 do
			local rect = rects[i]
			if Touches(rect, block, loose and not rect.side) then
				block[1], block[2] = min(block[1], rect[1]), min(block[2], rect[2])
				block[3], block[4] = max(block[3], rect[3]), max(block[4], rect[4])
				table.remove(rects, i)
				grew = true
			end
		end
	end
	return block
end

-- With ShyFrames' plates over the housing, `head` raises its top so the plates meet
-- the roof (Console.Build). `alone`: the layout shows the main bar alone and fades the others in while you point
-- at them (the minimal one): the housing is the main bar's, the others have one of their own that fades with them
-- (Drawers.lua). `loose`: the console's layout isn't the one in use, so the housing goes round the bars as they
-- stand (Block). Never recomputed in combat.
local head, alone, loose

local function Head()
	if InCombatLockdown() then return end
	local L = ns.Layout
	local active = L.IsActive()
	head = L.Plates() > 0 and active and L.Plan().head or nil
	alone = active and L.Plan().role ~= nil and L.Plan().role.reveal == true
	loose = not active
end

local function Tell(changed)
	local roof = T:Roof()
	if changed or roof ~= H.roof then
		H.roof = roof
		Shy:Fire("SHY_CONSOLE")
	end
end

-- following = true while Edit Mode is open and this runs every frame.
function H.Measure(following)
	if following ~= true then Head() end
	local bars = Block(alone, loose)
	if bars == false then return end   -- secret rect: keep the last position
	if not bars then
		dock:Hide()
		local had = H.rect ~= nil
		H.rect = nil
		Tell(had)
		return
	end
	local left, bottom, right, top = Console.Wrap(bars[1], bars[2], bars[3], bars[4], head)
	local was = H.rect
	local changed = not (was and was[1] == left and was[2] == bottom and was[3] == right and was[4] == top)
	if changed then
		H.rect = { left, bottom, right, top }
		dock:ClearAllPoints()
		dock:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		dock:SetSize(right - left, top - bottom)
	end
	-- The buttons are its content: a look with a well sinks them, its rim round them.
	UI.LookContent(housing.shyLook, { bars[1] - left, top - bars[4], right - bars[3], bars[2] - bottom })
	dock:Show()
	Tell(changed)
end

function T:HousingRect()
	local rect = H.rect
	if not rect then return nil end
	return rect[1], rect[2], rect[3] - rect[1], rect[4] - rect[2]
end

-- What stands beside the bars for the small unit frames to stand on: the wings' roof, or the
-- flanks' racks' top. The other corner layouts have nothing beside the bars that tall, unless the
-- screen is too narrow for the small frames beside the plates: then they stand on the wings' roofs there too.
function T:Roof()
	if not ns.Layout.IsActive() then return nil end
	local style = ns.Layout.Style()
	if Console.ROLES[style] then return nil end   -- by role your frames stand round your character (T:UnitHomes)
	if not Console.CORNERS[style] then return ns.Layout.Plan().wingTop end
	local g = ns.Layout.Plan()
	if g.roofed then return g.line end
	if Console.RACKED[style] then return (g.rack.left or g.rack.right) and g.rack.top or nil end
	return nil
end

-- The room kept under the floor (ShyXP's bars): its left and right edges, those of what always stands across the
-- floor (g.span: the minimal layout's main bar alone, not the side bars that only show while you point), and
-- its top, a seam under the floor (by role, a seam under the pet bar), in UIParent units from its bottom left. The top
-- is read off the housing where it stands, so it is right however the layout was written. nil while the console's
-- layout is not in use or the housing is not on screen.
function T:UnderSpan()
	local rect = H.rect
	if not (rect and ns.Layout.IsActive()) then return nil end
	local g, now = ns.Layout.Plan()
	local half = UIParent:GetWidth() / 2
	local below = g.floor - ((g.xp or 0) + (now.under or 0))   -- from the room's top up to the floor
	return half + g.span.left, half + g.span.right, rect[2] - below
end

-- The gap between any two pieces of the console.
function T:Seam()
	return Console.SEAM
end

-- How far a housing reaches past its bar's sides (the bars' own, a rack's): what stands beside a bar keeps that
-- clear of it, and a seam. 0 with the housings off.
function T:Reach()
	return T.db.housing and Console.PAD or 0
end

-- Where the wings begin, from the screen's center: the left wing's right edge, the right wing's left edge.
-- In a corner layout whose small frames stand on the wings' roofs, the wings' inner ends.
function T:WingEdges()
	local rect = H.rect
	if not (rect and ns.Layout.IsActive()) then return nil end
	local style = ns.Layout.Style()
	local half = UIParent:GetWidth() / 2
	if Console.ROLES[style] then return nil end
	if Console.CORNERS[style] then
		local g = ns.Layout.Plan()
		if g.roofed then return g.chat.art[3], g.meter and g.meter.art[1] or rect[3] + Console.SEAM - half end
		if not Console.RACKED[style] then return nil end
	end
	return rect[1] - Console.SEAM - half, rect[3] + Console.SEAM - half
end

local pending
function H.Touch()
	if pending then return end
	pending = true
	C_Timer.After(0, function() H.Measure() end)
	C_Timer.After(SETTLE, function()
		pending = nil
		H.Measure()
	end)
end

function H.Apply()
	local on = T.db.housing
	housing:SetShown(on)
	UI.SetFill(housing, ns.Graphite)
	-- Hide the gryphons through a kit so they can be restored.
	if on then
		local caps = MainActionBar.EndCaps
		kit:Hide(caps.LeftEndCap.Texture)
		kit:Hide(caps.RightEndCap.Texture)
	else
		kit:Restore()
	end
	H.Measure()
end

function H.Start()
	dock = CreateFrame("Frame", "ShyDockHousing", UIParent)
	-- LOW: under the bars (MEDIUM, ActionBarMixin:UpdateFrameStrata) and over ShyChat's wing
	-- (BACKGROUND). Level 30 clears the chat window (LOW, level 5, raised on click).
	dock:SetFrameStrata("LOW")
	dock:SetFrameLevel(30)
	dock:EnableMouse(false)
	dock:Hide()
	H.dock = dock

	housing = CreateFrame("Frame", nil, dock)
	housing:SetAllPoints()
	housing:EnableMouse(false)
	UI.Panel(housing, { cap = true, facets = false, line = false, brackets = 10 })
	H.art = housing

	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:SetScript("OnEvent", function(_, event)
		-- A fight beginning moves no bar unless one is shown in fights only (or out of them) in Edit Mode.
		if event == "PLAYER_REGEN_DISABLED" and not ns.Layout.FightShows(BARS) then return end
		H.Touch()
	end)

	hooksecurefunc("MultiActionBar_Update", H.Touch)   -- a bar turned on or off
	-- The XP bar showing or hiding restacks bars in their default positions.
	EventRegistry:RegisterCallback("EditModeManager.UpdateBottomActionBarPositions", H.Touch, H)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", H.Touch, H)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		driver:SetScript("OnUpdate", function() H.Measure(true) end)
	end, H)
	Shy:On("SHY_HUD_LAYOUT", H.Touch)
	Shy:On("SHY_FRAMES", H.Touch)
	-- A Blizzard frame dragged in layout mode is followed as in Edit Mode.
	Shy:On("SHY_HUD_MOVING", function(box)
		if box.foreign then driver:SetScript("OnUpdate", function() H.Measure(true) end) end
	end)
	Shy:On("SHY_HUD_MOVED", function()
		if not EditModeManagerFrame:IsEditModeActive() then driver:SetScript("OnUpdate", nil) end
		H.Touch()
	end)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		driver:SetScript("OnUpdate", nil)
		H.Touch()
	end, H)
end
