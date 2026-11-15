-- Shy.HUD: on-screen boxes and the layout mode that arranges them (grid, snapping, wheel to resize,
-- arrow keys to nudge, a left click picks, a right click opens the piece's panel with its menu under
-- More). Positions and scales are saved in ShyCoreDB.hud by id.
--
-- A dragged box lines up with what is on the screen: other pieces as they look (a game frame's panel,
-- a deck's column), edge on edge or a seam apart, the screen's middle and a seam in from its edges.
-- Let go of within reach of its home it goes home: the place it was given is dropped (IsPlaced is false
-- again), so whoever arranges the screen has it back. An arranger therefore keeps a box's home up to
-- date while the player has it elsewhere too (SetHome moves nothing then).
--
--   local box = Shy.HUD.Create({
--       id = "xp", title = "ShyXP stats",           -- title is shown in layout mode
--       width = 260, height = 90,
--       point = { "TOP", "TOP", 0, -140 },           -- default: box point, screen point, x, y
--       shown = function() return db.box end,
--       away = function() return docked end,         -- optional: while true, another piece shows this box's
--                                                    -- content, so it is out of layout mode too
--       toggle = { label = "Stats", tip = "...",     -- optional: an on/off switch other addons can offer
--           get = function() return db.box end,      -- (ShyDock's deck shows a tab per box with one)
--           set = function(on) db.box = on end,
--           alert = function() return waiting end,   -- optional: wants attention
--           wanted = function() return run end,      -- optional: offer the switch only while true
--           caret = true,                             -- optional: the tab is a fold, as the menu's rows are: its name
--                                                    -- and a caret down while on, turned onward while off
--           onText = "Just what's next",              -- optional: two or three words for what a click does
--           offText = "The whole guide" },            -- while on / off, when it isn't plain show / hide
--       docked = function(box, on) end,             -- optional: taken into or out of a column of boxes;
--                                                    -- docked, a box hides its own panel art
--       fit = function(box, width, own) end,        -- optional: can be given another width (HUD.Fit); own:
--                                                    -- it is given none any longer, `width` the one it had
--       window = true,                               -- optional: a window: position saved and snapped, but
--                                                    -- not part of layout mode (no mover, no "Reset all")
--       dock = { to = box | id | function,           -- optional, for a window: it docks beside another window
--                side = "LEFT", label = "Beside ..." },  -- (its host), a seam off, and moves with it. Docked
--                                                    -- on `side` until dragged away; dragged back near either
--                                                    -- side it docks there (an outline shows where). Docked, it
--                                                    -- takes the other side where its own runs off the screen,
--                                                    -- and lines its top up with the host's, or its foot where
--                                                    -- the tops would take it off the screen's foot. `label`
--                                                    -- names the switch in its menu.
--       secure = true,                               -- optional: holds secure buttons (see below)
--       inCombat = true,                             -- optional, with secure: stay shown in combat
--       hang = true,                                 -- optional: keeps its top edge when resized (HUD.Resize),
--                                                    -- growing down while the screen has room under it, and
--                                                    -- up, standing on the screen's foot, while it hasn't
--       grip = { flow = true, min = { 300, 200 } },  -- optional: how its corners and sides resize it (Grip.lua).
--                                                    -- Left out, they scale it; false, it has none
--       top = { order = 30 },                        -- optional: it stands in the column down from the top's
--                                                    -- middle, which gives it its place (Top.lua)
--       name = "GlobalName",                         -- optional
--   })
--   box.ownSize = true                  -- the box offers its own sizes: no Size entries in its menu or panel
--   box.panel = function(panel, Put, group, width) end   -- adds the box's own controls to the editor's panel
--                                                        -- (Editor.lua): build once, Put(widget, height) each time
--   Shy.HUD.Update(box)                 -- re-check `shown`
--   Shy.HUD.Resize(box, w, h)           -- new size; a `hang` box keeps its top edge (room allowing)
--   Shy.HUD.Folded(box, on)             -- folded away to its header (UI.FoldHead): no size to drag it to, so
--                                       -- its corner and sides offer none while it is (bus "SHY_HUD_FOLDED")
--   Shy.HUD.SetUnlocked(true)           -- open layout mode; HUD.IsUnlocked()
--   Shy.HUD.DragHandle(box, titleBar)   -- a window's title bar drags it at any time
--   Shy.HUD.Carry(box, control)         -- a control on that bar: clicked as ever, but pressed and moved it
--                                       -- drags the window, and HUD.WasDragged(box) is true in its click
--                                       -- (UI.MenuButton does all of it with opts.drag = box)
--   Shy.HUD.CarryEdit(box, editBox, over)   -- an edit box on that bar: while nobody types in it, a click
--                                       -- puts the cursor in and a press that moves drags the window
--   Shy.HUD.Manage(box, frame, menu)    -- drag to move, right-click for the box's menu (size, align, lock,
--                                       -- reset) with menu(root)'s entries on top, in layout mode too;
--                                       -- box.more(root), set by whoever arranges it, adds entries after them
--   Shy.HUD.Manage(box, frame, false, when)   -- drag only, no menu (a frame with a right click of its own);
--                                       -- when: a function, the frame drags nothing while it is false
--   Shy.HUD.Grip(box, opts)             -- its corners and sides resize it (Grip.lua; a box of ours whose panel
--                                       -- wears brackets is held so without asking, and `grip` above says how)
--   Shy.HUD.Sized(frame)                -- an adopted game frame keeps a width and height of the player's
--   Shy.HUD.Lift(box, units)            -- an adopted game frame stands that much shorter from its foot, its top
--                                       -- kept, for a moment (nothing saved; 0: as placed)
--   Shy.HUD.Lifted(frame)               -- how far it stands lifted now, in UIParent units: add it back to dock to it
--   Shy.HUD.Cover(box, frame)           -- the box's mover lies over `frame` instead of the box (a deck's column)
--   Shy.HUD.SetCarried(box, on)         -- another piece moves it (a box docked in a deck): no mover of its own,
--                                       -- nothing snaps to it; its own size and lock are kept
--   Shy.HUD.Release(box)                -- keeps the box where it stands, as a position the player set
--   Shy.HUD.Dock(box, side)             -- a `dock` window docked on side ("LEFT", "RIGHT", true: the side it
--                                       -- had), or free where it stands (false). Shy.HUD.Docked(box): the side
--                                       -- it stands on now, nil while free
--   Shy.HUD.SetHousing(frame, region)   -- the panel an addon draws for a game frame, larger than the frame
--                                       -- itself (ShyChat's window, ShySkin's minimap): the editor's sheet
--                                       -- fits it. nil takes it back. Shy.HUD.HousingOf(frame)
--   Shy.HUD.WasDragged(box)             -- in a click handler: did this press end a drag
--   Shy.HUD.InHand()                    -- a piece is being dragged, or sized by a handle: the mouse is its
--   Shy.HUD.OverWindow()                -- the mouse is on a window (ours, or a game window held by its corners)
--   Shy.HUD.WindowOn(left, bottom, right, top)   -- a window lies over some of that rectangle (UIParent units):
--                                       -- what stands over the game's frames gives way there (Drawer.lua)
--
--   local box = Shy.HUD.Adopt(DamageMeter, {        -- a Blizzard frame as a box
--       id = "shyskin.meter", title = "Damage meter",
--       active = function() return db.move end,     -- optional: while false, Blizzard places the frame
--       editMode = true,                             -- an Edit Mode frame: moving it there releases it
--       taken = function(box) end,                   -- optional, with editMode: it was moved in Edit Mode
--       reset = function(box) end,                   -- optional, with editMode: Edit Mode's "Reset To Default
--                                                    -- Position" was pressed (after Blizzard placed it)
--       plain = true,                                -- optional: anchor with SetPointBase (see Anchor)
--       scale = true,                                -- optional: layout mode may resize it
--       mover = false,                               -- optional: no mover in layout mode
--   })
--   Shy.HUD.Apply(box)                  -- after `active` changes
--   Shy.HUD.Adopted(frame)              -- the box a Blizzard frame was adopted as, or nil
--
-- An adopted frame keeps Blizzard's visibility, and its size unless `scale`. Nothing is written onto it:
-- the box is a proxy table that forwards calls. When Blizzard re-anchors the frame it is moved back to
-- the saved position, or to its home (HUD.SetHome); reset returns it to the home or to Blizzard's last
-- anchors. ShyCore adopts every Edit Mode frame (Frames.lua); an addon that adopts one of them later
-- takes it over, and the frame is first handed back to Blizzard's place and size.
--
-- Edit Mode is the layout editor, dressed in Shy's look by ShySkin: while it is open, movers stand on
-- Shy's own boxes (Edit Mode moves its frames itself), the world is dimmed and IsUnlocked() is true.
--   Shy.HUD.LayoutButton(parent, width)   -- a "Layout mode" button: opens Edit Mode (secure, see Key)
--   Shy.HUD.EditModeKey(button)           -- the same on a button of your own
--   Shy.HUD.Overlay(frame, opts)          -- the look of a piece being arranged (movers, Edit Mode's highlights)
--   Shy.HUD.Act                           -- what a picked piece can be asked to do (Editor.lua's panel)
--
-- For an addon that arranges the whole screen:
--   Shy.HUD.Each(fn)   Shy.HUD.Find(id)   Shy.HUD.IsPlaced(box)   Shy.HUD.SetHome(box, point, scale)
--   Shy.HUD.Forget(box)   Shy.HUD.Fit(box, width)   Shy.HUD.SetDocked(box, on)   Shy.HUD.SetStill(box, on)
--   Shy.HUD.Attach(box, to, point, relativePoint, x, y)   Shy.HUD.IsDragging(box)
--
--   Shy.HUD.GridStep(v)          -- a distance rounded to the grid (unchanged with Shift held)
--   local x, y = Shy.HUD.Guide(frame)   -- a game window an addon drags itself: on every frame of the drag
--                                -- and as it is let go of, the guides show what it lines up with, and
--                                -- x, y put its BOTTOMLEFT on the screen's there (its own units), or nil
--   Shy.HUD.Unguide()            -- that drag is over: the guides go
--   Shy.HUD.Strip(height)        -- a strip for an addon's controls under layout mode's toolbar
--   Shy.HUD.ResetAll()
--
-- Secure boxes: frames holding secure buttons can't be shown, hidden, moved or resized in combat. A
-- `secure` box hides in combat through a state driver, and changes requested in combat are applied
-- after it. Resize one only when not InCombatLockdown().
--
-- Bus: "SHY_HUD_LAYOUT" (on) as layout mode opens and closes; "SHY_HUD_MOVING" / "SHY_HUD_MOVED" (box)
-- as a drag or resize starts and ends; "SHY_HUD_RESIZED" (box) from HUD.Resize, when the size changed;
-- "SHY_HUD_SCALED" (box) whenever a box's scale is set (what is drawn in whole screen pixels fits again);
-- "SHY_HUD_COVERED" (on) as the world map takes the whole screen and gives it back (HUD.IsCovered()).

local Shy = Shy
local B, UI, Theme = Shy.Brand, Shy.UI, Shy.Theme
local core = Shy.core
local HUD = {}
Shy.HUD = HUD

local boxes = {}
local windows = {}         -- the windows: ours, and the game's held by their corners (HUD.Window)
local owners = {}          -- Blizzard frame -> the box it was adopted as
local unlocked = false
local alongside = false    -- unlocked because Edit Mode is open
local covered = false      -- the world map has the whole screen: no box shows (see Covered)
local selected             -- the box arrow keys nudge
local waiting = {}         -- secure boxes with changes to apply after combat
local Follow               -- places again what is docked to a box (Docking, below)
local Rect                 -- a box's rectangle in UIParent units (Dragging with snapping, below)
local GRID, SNAP = 16, 8
local SEAM = 4             -- the gap two pieces keep: a dragged box snaps this far off another's side
local SEAT = 24            -- a box let go of this near its home goes home
local MIN_SCALE, MAX_SCALE = 0.5, 2

local function Saved(box)
	return core.db.hud[box.id]
end

-- Drops a box's entry once nothing in it differs from where and how the box starts.
local function Tidy(box)
	local saved = Saved(box)
	if not saved or saved.x or saved.locked or saved.w or saved.dock ~= nil then return end
	if saved.scale and math.abs(saved.scale - (box.foreign and (box.homeScale or 1) or 1)) > 0.001 then return end
	core.db.hud[box.id] = nil
end

local function Keep(box)
	local saved = core.db.hud[box.id] or {}
	core.db.hud[box.id] = saved
	return saved
end

-- Box units per UIParent unit. An adopted frame can have a scaled parent (the objective tracker),
-- and anchor offsets are in its effective scale.
local function Scaled(box)
	return box:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Protected frames can't be moved in combat.
local function Busy(box)
	return (box.secure or (box.foreign ~= nil and box.foreign:IsProtected())) and InCombatLockdown()
end

local function Active(box)
	return not box.activeFn or box.activeFn() == true
end

local function Scalable(box)
	return not box.foreign or box.scalable == true
end

-- On screen, as far as can be told: an adopted frame's visibility can be secret.
local function Visible(frame)
	local shown = frame:IsVisible()
	return not issecretvalue(shown) and shown == true
end

-- An Edit Mode frame's SetPoint is EditModeSystemMixin:SetPointOverride, which also notifies Edit
-- Mode's manager; the engine's own is kept as SetPointBase (SetScaleBase for SetScale). A `plain` box
-- uses the Base ones so no Edit Mode code runs tainted: required for protected frames (action bars).
local function Clear(box)
	if box.plain and box.ClearAllPointsBase then box:ClearAllPointsBase() else box:ClearAllPoints() end
end
local function Anchor(box, ...)
	if box.plain and box.SetPointBase then box:SetPointBase(...) else box:SetPoint(...) end
end
local function ScaleTo(box, scale)
	if box.plain and box.SetScaleBase then box:SetScaleBase(scale) else box:SetScale(scale) end
	Shy:Fire("SHY_HUD_SCALED", box)
end

-- Blizzard frames that keep a width and height of the player's (HUD.Sized) -> the size Blizzard last
-- gave them.
local sized = setmetatable({}, { __mode = "k" })

-- A saved width and height (the box's entry, as w and h), else Blizzard's own again; less a lift
-- (HUD.Lift), else as it was before the lift.
local function ApplySize(box, saved, active)
	local own = sized[box.foreign]
	local lift = box.lift or 0
	if not own and lift == 0 and not box.lifted then return end
	local w, h
	if own and active and saved and saved.w and saved.h then
		w, h = saved.w, saved.h
		box.resized = true
	elseif box.resized or lift > 0 or box.lifted then
		box.resized = nil
		local base = own or box.unlifted
		if base then w, h = base.w, base.h end
	end
	if not (w and h) then return end
	box.applying = true
	box:SetSize(w, h - lift)
	box.applying = false
end

-- How much of a lift an anchor at `point` rises by: all of it at the foot, half at the middle, none at
-- the top, so the top stays where it was.
local function Rise(point)
	if type(point) ~= "string" or point:find("TOP") then return 0 end
	return point:find("BOTTOM") and 1 or 0.5
end

-- Whether a box already hangs by that one point of UIParent: it is applied again and again (Blizzard's
-- layout passes set an adopted frame's scale and points over and over, and each comes back here), and
-- moving it to where it is would run every hook on its SetPoint for nothing.
local function Stands(box, point, relativePoint, x, y)
	if box:GetNumPoints() ~= 1 then return false end
	local p, to, rp, px, py = box:GetPoint(1)
	if issecretvalue(px) or issecretvalue(py) or issecretvalue(p) then return false end
	return p == point and to == UIParent and rp == relativePoint and type(px) == "number" and type(py) == "number"
		and math.abs(px - x) < 0.01 and math.abs(py - y) < 0.01
end

-- Saved position first, then a given home, else Blizzard's own anchors; and a saved scale, else the
-- home's scale (SetHome's `scale`, on Blizzard's), else Blizzard's.
local function ApplyForeign(box)
	local saved = Saved(box)
	local active = Active(box)
	ApplySize(box, saved, active)
	local ours = saved ~= nil and saved.x ~= nil and active
	local given = not ours and box.given ~= nil and active
	local scale = box.scalable and active and saved and saved.scale or nil
	local lift = box.lift or 0
	if not ours and not given and not box.placed and not scale and not box.scaled and lift == 0 and not box.lifted then return end
	box.applying = true
	if box.scalable then
		local homed = given and box.givenScale and (box.homeScale or 1) * box.givenScale or nil
		local want = scale or homed or box.homeScale
		if want and math.abs(box:GetScale() - want) > 0.001 then ScaleTo(box, want) end
		box.scaled = scale ~= nil or homed ~= nil
	end
	if ours then
		if not Stands(box, "BOTTOMLEFT", "BOTTOMLEFT", saved.x, saved.y + lift) then
			Clear(box)
			Anchor(box, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y + lift)
		end
	elseif given then
		-- A home is in UIParent units; anchor offsets are in the frame's own.
		local p, s = box.given, Scaled(box)
		local y = p[4] / s + Rise(p[1]) * lift
		if not Stands(box, p[1], p[2], p[3] / s, y) then
			Clear(box)
			Anchor(box, p[1], UIParent, p[2], p[3] / s, y)
		end
	elseif #box.home > 0 then
		-- Blizzard's offsets are in the scale it set; keep its anchors where they were under ours.
		local k = (box.homeScale or 1) / box:GetScale()
		Clear(box)
		for _, point in ipairs(box.home) do
			local up = Rise(point[1]) * lift
			if (k ~= 1 or up ~= 0) and type(point[4]) == "number" and type(point[5]) == "number" then
				Anchor(box, point[1], point[2], point[3], point[4] * k, point[5] * k + up)
			else
				Anchor(box, unpack(point))
			end
		end
	end
	box.applying = false
	box.placed = ours or given
	box.lifted = lift > 0 or nil
end

-- A `hang` box stands by its top and grows down while the screen has room under it; where it hasn't (a piece
-- opened near the screen's foot), it grows up instead, standing on the foot, its top as high as it must be. One
-- taller than the screen keeps its top. y in the box's own units, as SetPoint takes it.
local function Room(box, point, relativePoint, y)
	if not box.hang or point:sub(1, 3) ~= "TOP" then return point, relativePoint, y end
	local s, tall = Scaled(box), UIParent:GetHeight()
	local level = relativePoint:sub(1, 3) == "TOP" and tall or relativePoint:sub(1, 6) == "BOTTOM" and 0 or tall / 2
	local height = box:GetHeight() * s
	if level + y * s - height >= 0 or height >= tall then return point, relativePoint, y end
	-- The same side across, by the foot: "TOPLEFT" stands as "BOTTOMLEFT", "TOP" as "BOTTOM".
	local across = relativePoint:gsub("^TOP", ""):gsub("^BOTTOM", "")
	if across == "CENTER" then across = "" end
	return "BOTTOM" .. point:sub(4), "BOTTOM" .. across, 0
end

-- Docking: a window that stands beside another (its host), a seam off, anchored to it so the engine moves
-- the two together. The side the player docked it on is kept in its entry as `dock` ("LEFT", "RIGHT"; none:
-- its made side), `false` while it stands free.

local OTHER_SIDE = { LEFT = "RIGHT", RIGHT = "LEFT" }

-- The window a box docks to, while there is one.
local function Host(box)
	local d = box.dock
	if not d then return nil end
	local host = d.to
	if type(host) == "function" then host = host() end
	if type(host) == "string" then host = HUD.Find(host) end
	if host == box then return nil end
	return host
end

-- The side the player docked it on, or nil while it stands free (or has no host).
local function DockSide(box)
	if not Host(box) then return nil end
	local saved = Saved(box)
	if saved and saved.dock == false then return nil end
	return (saved and saved.dock) or box.dock.side or "LEFT"
end

-- Where a box `width` by `height` (UIParent units) stands docked on `side` of its host: its left and bottom
-- in UIParent units, the side it takes and how it lines up ("TOP": tops level; "BOTTOM": feet level, where
-- level tops would take it off the screen's foot). `exact`: that side whatever room it has; else the other
-- side where that one runs off the screen and the other doesn't. Nil while the host can't be measured.
local function DockSeat(box, side, width, height, exact)
	local hl, hb, hw, hh = Rect(Host(box))
	if not hl then return nil end
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local function At(s)
		if s == "RIGHT" then return hl + hw + SEAM end
		return hl - SEAM - width
	end
	local left = At(side)
	if not exact and (left < 0 or left + width > sw) then
		local other = OTHER_SIDE[side]
		local there = At(other)
		if there >= 0 and there + width <= sw then side, left = other, there end
	end
	local level, bottom = "TOP", hb + hh - height
	if bottom < 0 and hb + height <= sh then level, bottom = "BOTTOM", hb end
	return left, bottom, side, level
end

-- Anchored to its host's side: TOPLEFT to the host's TOPRIGHT on the right, TOPRIGHT to its TOPLEFT on the left
-- (BOTTOM... where the feet line up). box.dockedOn is the side it stands on.
local function ApplyDocked(box, side)
	local host = Host(box)
	local s = Scaled(box)
	local level = "TOP"
	local _, _, took, lined = DockSeat(box, side, box:GetWidth() * s, box:GetHeight() * s)
	if took then side, level = took, lined end
	box.dockedOn = side
	local point = level .. (side == "RIGHT" and "LEFT" or "RIGHT")
	local relativePoint = level .. side
	local x = (side == "RIGHT" and SEAM or -SEAM) / s
	if box:GetNumPoints() == 1 then
		local p, to, rp, px, py = box:GetPoint(1)
		if p == point and to == host and rp == relativePoint and type(px) == "number" and math.abs(px - x) < 0.01 and py == 0 then return end
	end
	box:ClearAllPoints()
	box:SetPoint(point, host, relativePoint, x, 0)
end

function HUD.Apply(box)
	if Busy(box) then
		waiting[box] = true
		return
	end
	if box.foreign then
		ApplyForeign(box)
		if Follow then Follow(box) end
		return
	end
	local saved = Saved(box)
	local scale = saved and saved.scale or box.givenScale or 1
	if math.abs(box:GetScale() - scale) > 0.0001 then
		box:SetScale(scale)
		Shy:Fire("SHY_HUD_SCALED", box)
	end
	local side = DockSide(box)
	if side then
		box.lastDock = side   -- the side the player had it on, for docking it again (HUD.Dock)
		ApplyDocked(box, side)
	else
		box.dockedOn = nil
		local point, relativePoint, x, y
		if saved and saved.x and box.hang and saved.top then
			point, relativePoint, x, y = "TOPLEFT", "BOTTOMLEFT", saved.x, saved.top
		elseif saved and saved.x then
			point, relativePoint, x, y = "BOTTOMLEFT", "BOTTOMLEFT", saved.x, saved.y
		else
			local p, s = box.defaultPoint, Scaled(box)
			point, relativePoint, x, y = p[1], p[2], p[3] / s, p[4] / s
		end
		point, relativePoint, y = Room(box, point, relativePoint, y)
		if not Stands(box, point, relativePoint, x, y) then
			box:ClearAllPoints()
			box:SetPoint(point, UIParent, relativePoint, x, y)
		end
	end
	if Follow then Follow(box) end
end

function HUD.Update(box)
	if box.foreign then return end   -- Blizzard shows and hides its own frames
	-- Layout mode shows every box except windows and one whose content another piece shows (`away`).
	local away = box.awayFn ~= nil and box.awayFn() == true
	local show = (unlocked and not box.window and not away) or box.shownFn()
	-- Under the world map at full screen nothing of the HUD shows; a window is its player's to open.
	if covered and not box.window then show = false end
	if not box.secure then
		box:SetShown(show)
	elseif InCombatLockdown() then
		waiting[box] = true
	else
		-- Only when the rule changes: Update is called often.
		local rule = show and (box.inCombat and "show" or "[combat] hide; show") or "hide"
		if box.rule ~= rule then
			box.rule = rule
			RegisterStateDriver(box, "visibility", rule)
		end
	end
end

-- Layout mode: dimmed grid, snap guides, toolbar

local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetAllPoints()
overlay:SetFrameStrata("BACKGROUND")
overlay:Hide()
local dim = overlay:CreateTexture(nil, "BACKGROUND")
dim:SetAllPoints()
dim:SetColorTexture(0.02, 0.02, 0.03, 0.55)

local gridLines = {}
local function Line(parent, r, g, b, a)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(r, g, b, a)
	return t
end

local centerV, centerH = overlay:CreateTexture(nil, "ARTWORK"), overlay:CreateTexture(nil, "ARTWORK")
centerV:SetPoint("TOP")
centerH:SetPoint("LEFT")
Theme.Paint(centerV, UI.colors.hot, 0.3)
Theme.Paint(centerH, UI.colors.hot, 0.3)

local function DrawGrid()
	for _, t in ipairs(gridLines) do t:Hide() end
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local n = 0
	local function Get()
		n = n + 1
		gridLines[n] = gridLines[n] or Line(overlay, 1, 1, 1, 0.05)
		gridLines[n]:Show()
		return gridLines[n]
	end
	for x = 0, w, GRID * 4 do
		local t = Get()
		t:SetColorTexture(1, 1, 1, 0.05)
		t:SetSize(1, h)
		t:SetPoint("TOPLEFT", overlay, "TOPLEFT", x, 0)
	end
	for y = 0, h, GRID * 4 do
		local t = Get()
		t:SetColorTexture(1, 1, 1, 0.05)
		t:SetSize(w, 1)
		t:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, y)
	end
	centerV:SetSize(1, h)
	centerH:SetSize(w, 1)
end

-- Guides shown while a box is snapped to something. Children of UIParent so they also show over Edit Mode.
local guides = CreateFrame("Frame", nil, UIParent)
guides:SetAllPoints()
guides:SetFrameStrata("DIALOG")
local guideV, guideH = guides:CreateTexture(nil, "ARTWORK"), guides:CreateTexture(nil, "ARTWORK")
Theme.Paint(guideV, Theme.Accent, 0.9)
Theme.Paint(guideH, Theme.Accent, 0.9)
guideV:SetWidth(2)
guideV:Hide()
guideH:SetHeight(2)
guideH:Hide()
-- The seat: where a dragged box goes if it is let go of now, drawn while it is within reach of its home.
local seat = CreateFrame("Frame", nil, guides)
UI.Skin(seat, function()
	local r, g, b = Theme.Accent()
	return r, g, b, 0.14
end, UI.colors.hot)
seat:Hide()

-- The toolbar: draggable, folds to a slim bar, and opens where it covers no box (see Bar.Place).
local Bar = { strips = {}, FULL_W = 570, FULL_H = 90, SLIM_W = 340, SLIM_H = 42 }
local toolbar = CreateFrame("Frame", nil, UIParent)
toolbar:SetSize(Bar.FULL_W, Bar.FULL_H)
toolbar:SetPoint("TOP", 0, -40)
toolbar:SetFrameStrata("FULLSCREEN_DIALOG")
toolbar:SetMovable(true)
toolbar:SetClampedToScreen(true)
toolbar:Hide()
UI.Panel(toolbar)
local toolbarTitle = B.CreateTitle(toolbar, " layout", 22)
toolbarTitle:SetPoint("TOPLEFT", 14, -8)
Bar.HINT = "Drag to move  \194\183  mouse wheel to resize  \194\183  right-click a piece for its options"
local hint = UI.Text(toolbar, Bar.HINT, 12, false, UI.colors.dim)
hint:SetPoint("BOTTOMLEFT", 14, 28)
Bar.hint = hint
Bar.grip = UI.Text(toolbar, "Arrow keys nudge what you picked  \194\183  hold Shift for no snapping  \194\183  drag this bar away", 12, false, UI.colors.dim)
Bar.grip:SetPoint("BOTTOMLEFT", 14, 12)
for _, line in ipairs({ hint, Bar.grip }) do
	line:SetPoint("RIGHT", toolbar, "RIGHT", -14, 0)
	line:SetJustifyH("LEFT")
	line:SetWordWrap(false)
end

-- Strips stack downward under the toolbar in the order they are created.
local STRIP_GAP = 4
local stripsTall = 0
function HUD.Strip(height)
	local strip = CreateFrame("Frame", nil, toolbar)
	strip:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -STRIP_GAP - stripsTall)
	strip:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -STRIP_GAP - stripsTall)
	strip:SetHeight(height)
	UI.Panel(strip, { line = false, brackets = false })
	stripsTall = stripsTall + height + STRIP_GAP
	Bar.strips[#Bar.strips + 1] = strip
	Bar.Grip(strip)
	Bar.Look()
	return strip
end

-- Dragging with snapping

local function Round(v, step) return math.floor(v / step + 0.5) * step end

function HUD.GridStep(v)
	if IsShiftKeyDown() then return v end
	return Round(v, GRID / 2)
end

-- Box rectangle in UIParent units: left, bottom, width, height. Nil when it can't be read.
function Rect(box)
	local left, bottom, width, height = box:GetLeft(), box:GetBottom(), box:GetWidth(), box:GetHeight()
	if left == nil or bottom == nil or width == nil or height == nil then return nil end
	if issecretvalue(left) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height) then return nil end
	local s = Scaled(box)
	return left * s, bottom * s, width * s, height * s
end

-- What stands on the screen for a box, and so what its edges are: the panel an addon draws round a game
-- frame (HUD.SetHousing: the minimap's, chat's), the frame its mover covers (HUD.Cover: a deck's column),
-- else the box.
local function Face(box)
	if box.foreign then return HUD.HousingOf(box.foreign) or box end
	return box.cover or box
end

-- Where a box's home has it, for a box this wide and tall: left and bottom in UIParent units. The home is
-- its default position, an adopted frame's given one, or the game's own single anchor on the screen; nil
-- where there is none to work out.
local function HomeAt(box, width, height)
	local p
	if not box.foreign then
		p = box.defaultPoint
	elseif box.given then
		p = box.given
	elseif #box.home == 1 then
		-- The game's offsets are in the scale it set.
		local at = box.home[1]
		if (at[2] == UIParent or at[2] == "UIParent") and type(at[3]) == "string" and type(at[4]) == "number" and type(at[5]) == "number" then
			local k = Scaled(box) * (box.homeScale or 1) / box:GetScale()
			p = { at[1], at[3], at[4] * k, at[5] * k }
		end
	end
	if not p or type(p[1]) ~= "string" or type(p[2]) ~= "string" then return nil end
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local x = (p[2]:find("LEFT") and 0 or p[2]:find("RIGHT") and sw or sw / 2) + p[3]
	local y = (p[2]:find("BOTTOM") and 0 or p[2]:find("TOP") and sh or sh / 2) + p[4]
	return x - (p[1]:find("LEFT") and 0 or p[1]:find("RIGHT") and width or width / 2),
		y - (p[1]:find("BOTTOM") and 0 or p[1]:find("TOP") and height or height / 2)
end

-- Where a dragged box at (left, bottom) should stand. Within reach of its home it goes home (box.homing:
-- let go of now it is no longer a box the player placed). Else its face lines up with the screen's middle
-- and edges and with other pieces' faces, side to side or a seam apart; else the grid.
local function Snap(box, left, bottom, width, height)
	guideV:Hide()
	guideH:Hide()
	seat:Hide()
	box.homing, box.docking = nil, nil
	if not left or IsShiftKeyDown() then return left, bottom end
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()

	-- A window that docks: within reach of either side of its host it docks there (box.docking), and its
	-- home is that side, not a place of its own.
	if box.dock then
		local host = Host(box)
		if host and Visible(host) then
			for _, side in ipairs({ "LEFT", "RIGHT" }) do
				local dl, db = DockSeat(box, side, width, height, true)
				if dl and math.abs(left - dl) < SEAT and math.abs(bottom - db) < SEAT then
					box.docking = side
					seat:ClearAllPoints()
					seat:SetPoint("BOTTOMLEFT", guides, "BOTTOMLEFT", dl, db)
					seat:SetSize(width, height)
					seat:Show()
					return dl, db
				end
			end
		end
	end

	-- The face's place and size, from the box's.
	local dx, dy, fw, fh = 0, 0, width, height
	local face = Face(box)
	if face ~= box then
		local bl, bb = Rect(box)
		local fl, fb, w, h = Rect(face)
		if bl and fl then dx, dy, fw, fh = fl - bl, fb - bb, w, h end
	end

	local hl, hb
	if not box.dock then hl, hb = HomeAt(box, width, height) end
	if hl and math.abs(left - hl) < SEAT and math.abs(bottom - hb) < SEAT then
		box.homing = true
		seat:ClearAllPoints()
		seat:SetPoint("BOTTOMLEFT", guides, "BOTTOMLEFT", hl + dx, hb + dy)
		seat:SetSize(fw, fh)
		seat:Show()
		return hl, hb
	end

	-- The nearest line within reach, each way: { how far, where the face's left or bottom goes, the guide }.
	local l, b = left + dx, bottom + dy
	local bestX, bestY
	local function X(to, guide)
		local d = math.abs(l - to)
		if d < SNAP and not (bestX and bestX[1] <= d) then bestX = { d, to, guide } end
	end
	local function Y(to, guide)
		local d = math.abs(b - to)
		if d < SNAP and not (bestY and bestY[1] <= d) then bestY = { d, to, guide } end
	end

	-- The screen's middle, and a seam in from its edges.
	X(sw / 2 - fw / 2, sw / 2)
	Y(sh / 2 - fh / 2, sh / 2)
	X(SEAM, SEAM)
	X(sw - SEAM - fw, sw - SEAM)
	Y(SEAM, SEAM)
	Y(sh - SEAM - fh, sh - SEAM)

	-- Other pieces, except `still` and carried ones (they move with their host) and windows: edge on edge,
	-- or beside one, touching or a seam apart (whichever is nearer).
	for _, other in ipairs(boxes) do
		if other ~= box and not other.still and not other.carried and not other.window and Visible(other) then
			local ol, ob, ow, oh = Rect(Face(other))
			if ol then
				local right, top = ol + ow, ob + oh
				X(ol, ol)
				X(right - fw, right)
				X(right, right)
				X(ol - fw, ol)
				X(right + SEAM, right)
				X(ol - SEAM - fw, ol)
				Y(ob, ob)
				Y(top - fh, top)
				Y(top, top)
				Y(ob - fh, ob)
				Y(top + SEAM, top)
				Y(ob - SEAM - fh, ob)
			end
		end
	end

	-- Otherwise the grid.
	l = bestX and bestX[2] or Round(l, GRID / 2)
	b = bestY and bestY[2] or Round(b, GRID / 2)

	if bestX then
		guideV:SetHeight(sh)
		guideV:ClearAllPoints()
		guideV:SetPoint("BOTTOM", guides, "BOTTOMLEFT", bestX[3], 0)
		guideV:Show()
	end
	if bestY then
		guideH:SetWidth(sw)
		guideH:ClearAllPoints()
		guideH:SetPoint("LEFT", guides, "BOTTOMLEFT", 0, bestY[3])
		guideH:Show()
	end
	return l - dx, b - dy
end

local dragging

-- Whatever is docked to `host` is placed against it again: it moved, changed size, or was placed anew, so a
-- side may have run out of room or the tops may now take a window off the screen's foot.
function Follow(host)
	for _, other in ipairs(boxes) do
		if other ~= host and other ~= dragging and other.dock and Host(other) == host and DockSide(other) then
			HUD.Apply(other)
		end
	end
end

local function Place(box, left, bottom)
	if not left then return end
	local s = Scaled(box)
	box.applying = true
	if box.foreign then
		Clear(box)
		Anchor(box, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / s, bottom / s)
	else
		box:ClearAllPoints()
		box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / s, bottom / s)
	end
	box.applying = false
	box.placed = true
end

local function Remember(box)
	local saved = Keep(box)
	-- An adopted frame keeps Blizzard's scale until it is given one.
	if not box.foreign or box.scaled then saved.scale = box:GetScale() end
	if DockSide(box) then
		-- Docked, its place is its host's side: back against it.
		HUD.Apply(box)
	else
		saved.x, saved.y = box:GetLeft(), box:GetBottom()
		saved.top = box.hang and box:GetTop() or nil
		-- Dragged by its bottom edge: re-anchor by its top.
		if box.hang then HUD.Apply(box) end
	end
	Shy:Fire("SHY_HUD_MOVED", box)
	if box == selected then Bar.Readout() end
end

-- Docked on `side` of its host (Snap's box.docking, the menu, HUD.Dock): no place of its own is kept.
local function Dock(box, side)
	box.docking = nil
	local saved = Keep(box)
	saved.x, saved.y, saved.top = nil, nil, nil
	saved.dock = side ~= (box.dock.side or "LEFT") and side or nil
	Tidy(box)
	HUD.Apply(box)
	Shy:Fire("SHY_HUD_MOVED", box)
	if box == selected then Bar.Readout() end
end

-- Let go of within reach of its home (Snap): the place the player gave it is dropped, so it stands at
-- its home again and whoever arranges the screen has it back.
local function GoHome(box)
	box.homing = nil
	local saved = Saved(box)
	if saved then saved.x, saved.y, saved.top = nil, nil, nil end
	Tidy(box)
	HUD.Apply(box)
	Shy:Fire("SHY_HUD_MOVED", box)
	if box == selected then Bar.Readout() end
end

local driver = CreateFrame("Frame")
local pending   -- a box with the mouse down on it, not yet dragged

local function IsLocked(box)
	local saved = Saved(box)
	return saved ~= nil and saved.locked == true
end

-- The look of a piece being arranged, shared with Edit Mode's own frames (ShySkin dresses them with
-- it): a sheet of frosted glass over a shade of the panel color (the game can't blur, so Glass.tga's
-- clouds stand in: darker and lighter in places, the piece's shape still showing through), in a thin
-- edge of the accent, the piece's name on a dark chip with a line under it. Nothing else: most pieces
-- already wear a panel with brackets and a line, and the sheet lies over it. Two sheets over each other
-- stay readable, and a hovered one rises over its neighbours. Hovered, the glass takes more of the
-- accent; picked, edge, chip line and name turn gold.
--   local o = Shy.HUD.Overlay(frame, { label = "Title", size = 13 })   -- textures on `frame`
--   o:Look("idle" | "hover" | "picked")   o:SetShown(on)   o.label
local Overlay = {}
Overlay.__index = Overlay
local SHADE = { idle = 0.42, hover = 0.34, picked = 0.46 }   -- the flat shade under the glass
local GLASS = { idle = 0.55, hover = 0.5, picked = 0.6 }     -- the glass over it
local WASH = { idle = 0.06, hover = 0.18, picked = 0.08 }    -- the accent in it
local BAND_H, BAND_PAD = 18, 10   -- the chip under the name
local RAISE = 20                  -- frame levels a hovered or picked mover rises

function HUD.Overlay(frame, opts)
	opts = opts or {}
	local o = setmetatable({ parts = {} }, Overlay)
	local function Add(t)
		o.parts[#o.parts + 1] = t
		return t
	end
	o.shade = Add(frame:CreateTexture(nil, "BACKGROUND", nil, -8))
	o.shade:SetAllPoints()
	o.glass = Add(frame:CreateTexture(nil, "BACKGROUND", nil, -7))
	o.glass:SetAllPoints()
	o.glass:SetTexture(UI.GLASS, "REPEAT", "REPEAT")
	o.glass:SetHorizTile(true)
	o.glass:SetVertTile(true)
	o.wash = Add(frame:CreateTexture(nil, "BACKGROUND", nil, -6))
	o.wash:SetAllPoints()
	o.edge = Add(frame:CreateTexture(nil, "BORDER"))
	o.edge:SetAllPoints()
	o.edge:SetTexture(UI.EDGE)
	o.edge:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
	if opts.label then
		o.band = Add(frame:CreateTexture(nil, "ARTWORK"))
		o.band:SetPoint("CENTER")
		o.band:SetHeight(BAND_H)
		o.bandLine = Add(frame:CreateTexture(nil, "ARTWORK", nil, 1))
		o.bandLine:SetPoint("BOTTOMLEFT", o.band, "BOTTOMLEFT")
		o.bandLine:SetPoint("BOTTOMRIGHT", o.band, "BOTTOMRIGHT")
		o.bandLine:SetHeight(1)
		o.label = Add(UI.Text(frame, opts.label, opts.size or 13, true))
		o.label:SetPoint("CENTER")
		o.label:SetWordWrap(false)
	end
	o:Look("idle")
	return o
end

function Overlay:Look(state)
	local gold = state == "picked"
	local edge = gold and UI.colors.alert or UI.colors.hot
	Theme.Paint(self.shade, UI.colors.panel, SHADE[state] or SHADE.idle)
	Theme.Tint(self.glass, UI.colors.panel, GLASS[state] or GLASS.idle)
	Theme.Paint(self.wash, gold and UI.colors.alert or Theme.Accent, WASH[state] or WASH.idle)
	Theme.Tint(self.edge, edge, state == "idle" and 0.6 or 1)
	if self.label then
		Theme.Ink(self.label, gold and UI.colors.alert or UI.colors.text)
		Theme.Paint(self.band, UI.colors.panel, 0.92)
		Theme.Paint(self.bandLine, edge, state == "idle" and 0.6 or 1)
		local wide = self.label:GetStringWidth()
		if wide and not issecretvalue(wide) then self.band:SetWidth(wide + 2 * BAND_PAD) end
	end
	self.state = state
end

function Overlay:SetShown(on)
	for _, t in ipairs(self.parts) do t:SetShown(on) end
end

-- The sheet over `region` instead of the frame it was made on (a piece whose panel is larger than
-- the frame Edit Mode highlights: ShyChat's window).
function Overlay:Fit(region)
	if self.over == region then return end
	self.over = region
	for _, t in ipairs({ self.shade, self.glass, self.wash, self.edge }) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", region, "TOPLEFT")
		t:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
	end
	if self.band then
		self.band:ClearAllPoints()
		self.band:SetPoint("CENTER", region, "CENTER")
		self.label:ClearAllPoints()
		self.label:SetPoint("CENTER", region, "CENTER")
	end
end

-- A mover's look: picked or dragged (gold), hovered, locked (says so).
local function Look(box)
	local m = box.mover
	if not m then return end
	local state = (box == selected or dragging == box) and "picked" or (m.over and "hover" or "idle")
	m.overlay:Look(state)
	-- Over its neighbours while it is the one in hand.
	if m.baseLevel then m:SetFrameLevel(m.baseLevel + (state ~= "idle" and RAISE or 0)) end
	m.label:SetText(IsLocked(box) and (box.title .. "  \194\183  locked") or box.title)
	if HUD.OnLook then HUD.OnLook(box) end
end

local function Select(box)
	local was = selected
	selected = box
	if was then Look(was) end
	if box then Look(box) end
	Bar.Readout()
	if HUD.OnSelect and was ~= box then HUD.OnSelect(box) end
end

local function StopDrag()
	if pending then
		pending = nil
		driver:SetScript("OnUpdate", nil)
		driver:UnregisterEvent("GLOBAL_MOUSE_UP")
	end
	if not dragging then return end
	local box = dragging
	dragging = nil
	driver:SetScript("OnUpdate", nil)
	driver:UnregisterEvent("GLOBAL_MOUSE_UP")
	if not box.foreign then
		box:StopMovingOrSizing()
		box:SetUserPlaced(false)   -- positions are saved here, not in the client's layout cache
		Place(box, Snap(box, Rect(box)))
	end
	if box.docking and not Busy(box) then
		Dock(box, box.docking)
	elseif box.homing and not Busy(box) then
		GoHome(box)
	else
		-- A docking window let go of anywhere else stands free where it is.
		if box.dock then Keep(box).dock = false end
		Remember(box)
	end
	Follow(box)
	Look(box)
	guideV:Hide()
	guideH:Hide()
	seat:Hide()
end

-- Our own boxes are moved by the engine (StartMoving) and snap on release: re-anchoring a frame on
-- every frame of a drag draws its text one frame behind its art on this client. An adopted frame is
-- moved by re-anchoring, since it isn't set movable; from where the press began (cx, cy), so it
-- doesn't lag the cursor by the distance a press travels before it becomes a drag.
local function StartDrag(box, cx, cy)
	dragging = box
	Shy:Fire("SHY_HUD_MOVING", box)
	Look(box)
	if box.foreign then
		if not cx then cx, cy = GetCursorPosition() end
		local ui = UIParent:GetEffectiveScale()
		local left, bottom = Rect(box)
		if not left then
			dragging = nil
			return
		end
		box.dragOffset = { cx / ui - left, cy / ui - bottom }
		driver:SetScript("OnUpdate", function()
			local x, y = GetCursorPosition()
			local _, _, w, h = Rect(box)
			if not w then return end
			Place(box, Snap(box, x / ui - box.dragOffset[1], y / ui - box.dragOffset[2], w, h))
		end)
	else
		-- Docked, it hangs from its host: it stands on the screen by itself for the drag.
		if box.dockedOn then
			local left, bottom = Rect(box)
			if left then
				box.applying = true
				box:ClearAllPoints()
				box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / Scaled(box), bottom / Scaled(box))
				box.applying = false
			end
		end
		box:StartMoving()
		driver:SetScript("OnUpdate", function() Snap(box, Rect(box)) end)   -- guides only
	end
	-- This client sometimes never delivers the mouse-up to a dragged frame.
	driver:RegisterEvent("GLOBAL_MOUSE_UP")
end
driver:SetScript("OnEvent", StopDrag)

-- A game window an addon moves itself (no piece of the screen) lines up as a dragged piece does. It
-- stands in for itself with a proxy, as an adopted frame does: nothing is written onto the window.
local strays = {}   -- game window -> its stand-in

function HUD.Guide(frame)
	local box = strays[frame]
	if not box then
		box = setmetatable({ foreign = frame, home = {} }, { __index = function(_, key)
			local value = frame[key]
			if type(value) ~= "function" then return value end
			return function(_, ...) return value(frame, ...) end
		end })
		strays[frame] = box
	end
	local left, bottom = Snap(box, Rect(box))
	if not left then return nil end
	local s = Scaled(box)
	return left / s, bottom / s
end

function HUD.Unguide()
	guideV:Hide()
	guideH:Hide()
	seat:Hide()
end

-- Keeps the box's center in place.
local function SetScale(box, scale)
	if Busy(box) or not Scalable(box) then return end
	local left, bottom, width, height = Rect(box)
	if not left then return end
	local cx, cy = left + width / 2, bottom + height / 2
	scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
	if box.foreign then
		box.applying = true
		ScaleTo(box, scale)
		box.applying = false
		box.scaled = true
	else
		box:SetScale(scale)
		Shy:Fire("SHY_HUD_SCALED", box)
	end
	local s = Scaled(box)
	local nw, nh = box:GetWidth() * s, box:GetHeight() * s
	Place(box, cx - nw / 2, cy - nh / 2)
	Remember(box)
end

local function Resize(box, delta)
	SetScale(box, box:GetScale() + delta * 0.05)
end

-- Where the box would stand at that scale (SetScale: its center kept), as an outline, for a size being picked
-- that the box takes only once it is let go of; no scale puts the outline away.
local function Outline(box, scale)
	local left, bottom, width, height
	if box and scale then left, bottom, width, height = Rect(box) end
	if not left then
		seat:Hide()
		return
	end
	local k = math.max(MIN_SCALE, math.min(MAX_SCALE, scale)) / box:GetScale()
	seat:ClearAllPoints()
	seat:SetPoint("BOTTOMLEFT", guides, "BOTTOMLEFT", left + width * (1 - k) / 2, bottom + height * (1 - k) / 2)
	seat:SetSize(width * k, height * k)
	seat:Show()
end

-- The bare scale: nothing moved and nothing kept (a corner drag sets it many times before it lets go).
local function Rescale(box, scale)
	scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
	if box.foreign then
		box.applying = true
		ScaleTo(box, scale)
		box.applying = false
		box.scaled = true
	else
		box:SetScale(scale)
		Shy:Fire("SHY_HUD_SCALED", box)
	end
	return scale
end

-- A width and height the player gave a game frame (HUD.Sized): back to the game's own.
local function ResetSize(box)
	local saved = Saved(box)
	if not saved or not saved.w or Busy(box) then return end
	saved.w, saved.h = nil, nil
	Tidy(box)
	HUD.Apply(box)
	Shy:Fire("SHY_HUD_MOVED", box)
end

-- Back to the size it had before layout mode gave it one; the center stays.
local function ResetScale(box)
	ResetSize(box)
	local saved = Saved(box)
	if not saved or not saved.scale then return end
	SetScale(box, box.foreign and (box.homeScale or 1) or 1)
	saved.scale, box.scaled = nil, nil
	Tidy(box)
end

local function Nudge(box, dx, dy)
	if Busy(box) or IsLocked(box) then return end
	local left, bottom = Rect(box)
	if not left then return end
	Place(box, left + dx, bottom + dy)
	Remember(box)
end

-- To the middle of the screen, across (true) or up and down.
local function Center(box, across)
	if Busy(box) then return end
	local left, bottom, width, height = Rect(box)
	if not left then return end
	if across then left = UIParent:GetWidth() / 2 - width / 2 else bottom = UIParent:GetHeight() / 2 - height / 2 end
	Place(box, left, bottom)
	Remember(box)
end

-- Managing a box: its menu, and pressing it

local DRAG_START = 6   -- pixels the mouse must travel before a press becomes a drag
local SIZES = { 0.6, 0.8, 0.9, 1, 1.1, 1.25, 1.5 }

local function WatchPending()
	if not pending then
		driver:SetScript("OnUpdate", nil)
		return
	end
	local x, y = GetCursorPosition()
	if math.abs(x - pending.x) + math.abs(y - pending.y) < DRAG_START then return end
	local box, fromX, fromY = pending.box, pending.x, pending.y
	pending = nil
	-- Off before the drag begins: should it fail, this doesn't run again every frame.
	driver:SetScript("OnUpdate", nil)
	box.wasDragged = true
	StartDrag(box, fromX, fromY)
end

local function Press(box)
	local x, y = GetCursorPosition()
	pending = { box = box, x = x, y = y }
	driver:SetScript("OnUpdate", WatchPending)
	driver:RegisterEvent("GLOBAL_MOUSE_UP")   -- see StartDrag
end

-- The box's menu: its title, the entries the frame's owner writes (`extra`) and the box's own (`more`),
-- then the window's: size, centring, lock, reset, Edit Mode and layout mode. A box with entries of its own
-- keeps the window's under one "Window" entry, so its own stand clear; a bare box lists them plain.
local function OpenMenu(box, owner, extra)
	Select(unlocked and box or selected)
	UI.ContextMenu(owner, function(root)
		root:CreateTitle(box.title)
		if extra then
			extra(root)
			root:CreateDivider()
		end
		if box.more then
			box.more(root)
			root:CreateDivider()
		end
		if root:Count() > 0 then
			root = root:CreateButton("Window")
			root:SetSub("Size, lock and position")
			root:SetIcon(UI.MenuGlyph("window"))
		end
		-- A box that offers its own sizes (ownSize) has no use for these.
		if Scalable(box) and not box.ownSize then
			local size = root:CreateButton("Size")
			size:SetIcon(UI.MenuGlyph("size"))
			for _, scale in ipairs(SIZES) do
				size:CreateRadio(math.floor(scale * 100 + 0.5) .. "%",
					function() return math.abs(box:GetScale() - scale) < 0.02 end,
					function() SetScale(box, scale) end)
			end
		end
		local align = root:CreateButton("Center")
		align:SetIcon(UI.MenuGlyph("center"))
		align:CreateButton("Across the screen", function() Center(box, true) end)
		align:CreateButton("Up and down", function() Center(box, false) end)
		if box.dock and Host(box) then
			root:CreateCheckbox(box.dock.label or "Docked", function() return DockSide(box) ~= nil end, function()
				HUD.Dock(box, not DockSide(box))
			end)
		end
		root:CreateCheckbox("Lock in place", function() return IsLocked(box) end, function()
			local saved = Keep(box)
			saved.locked = not saved.locked or nil
			Look(box)
		end)
		root:CreateButton(box.editMode and "Back to Edit Mode's place" or "Reset position", function()
			local saved = Saved(box)
			if saved then saved.x, saved.y, saved.top, saved.dock = nil, nil, nil, nil end
			Tidy(box)
			HUD.Apply(box)
			Shy:Fire("SHY_HUD_MOVED", box)
		end):SetIcon(UI.MenuGlyph("reset"))
		local saved = Saved(box)
		local scaled = Scalable(box) and saved and saved.scale and math.abs(saved.scale - (box.foreign and box.homeScale or 1)) > 0.001
		if scaled or (saved and saved.w) then
			root:CreateButton(box.editMode and "Back to Edit Mode's size" or "Reset size", function() ResetScale(box) end):SetIcon(UI.MenuGlyph("reset"))
		end
		root:CreateDivider()
		if box.editMode then
			-- Edit Mode opens through a secure button: from addon code its manager would run tainted.
			local edit = root:CreateButton("Edit Mode")
			edit:SetSecure({ type = "macro", macrotext = SLASH_EDITMODE1 })
			edit:SetIcon(UI.MenuGlyph("window"))
			edit:SetTooltip("Opens Edit Mode for this piece's own settings. If you move it there, Edit Mode takes it back over.")
		end
		if not unlocked then root:CreateButton("Layout mode", function() HUD.SetUnlocked(true) end):SetIcon(UI.MenuGlyph("window")) end
	end)
end

-- Boxes

local function MoverShown(box)
	if not unlocked or box.still or box.carried or box.retired or not Active(box) then return false end
	if box.awayFn ~= nil and box.awayFn() == true then return false end
	if alongside and box.editMode then return false end   -- Edit Mode shows its own frames
	if box.foreign then
		-- Not over a frame faded out of sight (ShyDock's swing row stands in for the game's swing bars).
		local alpha = box.foreign:GetEffectiveAlpha()
		if issecretvalue(alpha) or alpha < 0.05 then return false end
		return Visible(box.foreign) and Rect(box) ~= nil
	end
	return true
end

-- A mover lies over its box in layout mode, Shy's own over the game's where they overlap. An adopted
-- frame's is a child of UIParent laid over it, not a child of Blizzard's frame (bars lay out their
-- children), and stands in the frame's strata when that is higher.
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function Mover(box)
	local m
	if box.foreign then
		m = CreateFrame("Frame", nil, UIParent)
		m:SetAllPoints(box.foreign)
		local strata = box.foreign:GetFrameStrata()
		m:SetFrameStrata((STRATA[strata] or 0) > STRATA.HIGH and strata or "HIGH")
		m:SetFrameLevel(50)
	else
		m = CreateFrame("Frame", nil, box)
		m:SetAllPoints()
		m:SetFrameStrata("HIGH")
		m:SetFrameLevel(100)
	end
	m:Hide()
	m.overlay = HUD.Overlay(m, { label = box.title, size = box.foreign and 12 or 14 })
	m.label = m.overlay.label
	m.label:ClearAllPoints()
	m.label:SetPoint("LEFT", 6, 0)
	m.label:SetPoint("RIGHT", -6, 0)
	m.label:SetJustifyH("CENTER")
	m.overlay.band:ClearAllPoints()
	m.overlay.band:SetPoint("CENTER", m.label, "CENTER")
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then return end
		Select(box)
		if not IsLocked(box) and not Busy(box) then Press(box) end
	end)
	m:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			StopDrag()
		elseif button == "RightButton" then
			-- A left click only picks and drags; the right one opens the piece's panel (Editor.lua), with
			-- its menu under More, or the menu itself without an editor.
			if HUD.OnOpen then
				Select(box)
				HUD.OnOpen(box)
			else
				OpenMenu(box, m, box.menu)
			end
		end
	end)
	m:SetScript("OnMouseWheel", function(_, delta)
		if not IsLocked(box) then Resize(box, delta) end
	end)
	m.baseLevel = m:GetFrameLevel()
	m:SetScript("OnEnter", function(self)
		self.over = true
		Look(box)
	end)
	m:SetScript("OnLeave", function(self)
		self.over = nil
		Look(box)
	end)
	box.mover = m
	Look(box)
	return m
end

local function ShowMovers()
	for _, box in ipairs(boxes) do
		if box.mover then box.mover:SetShown(MoverShown(box)) end
	end
end

-- Adopted frames come and go on their own: their movers follow while layout mode is open.
local watch = CreateFrame("Frame")
watch:Hide()
watch.since = 0
watch:SetScript("OnUpdate", function(self, elapsed)
	self.since = self.since + elapsed
	if self.since < 0.2 then return end
	self.since = 0
	ShowMovers()
end)

function HUD.Create(def)
	local box = CreateFrame("Frame", def.name, UIParent)
	box.id, box.title, box.defaultPoint, box.shownFn = def.id, def.title, def.point, def.shown
	box.awayFn = def.away
	box.secure, box.inCombat = def.secure, def.inCombat
	box.hang, box.window = def.hang, def.window
	box.dock = def.window and def.dock or nil
	box.toggle, box.dockedFn, box.fitFn = def.toggle, def.docked, def.fit
	box.grip = def.grip
	box.top, box.madePoint = def.top, def.point   -- madePoint: the place its own addon made it with
	box:SetSize(def.width, def.height)
	box:SetFrameStrata("MEDIUM")
	box:SetClampedToScreen(true)
	box:SetMovable(true)   -- for StartMoving (StartDrag)
	if box.window then
		-- A window comes over what else stands on its layer as it shows and when it is pressed, the game's bars
		-- and menu with the rest: as the game's own windows do.
		box:SetToplevel(true)
		windows[#windows + 1] = box
	else
		Mover(box)
	end
	boxes[#boxes + 1] = box
	HUD.Apply(box)
	HUD.Update(box)
	return box
end

-- A window lies over the pieces of the screen. What a piece keeps above the game's frames on a layer of its
-- own (a drawer's pull, the catcher over what it has tucked away) gives way where one lies, or it would take
-- the window's clicks and draw across it.
-- A game window that is no piece of the screen (HUD.GripFrame's stand-in) is one too.
function HUD.Window(box)
	for _, each in ipairs(windows) do
		if each == box then return end
	end
	windows[#windows + 1] = box
end

-- The mouse is on a window that shows.
function HUD.OverWindow()
	for _, box in ipairs(windows) do
		if Visible(box) then
			local over = box:IsMouseOver()
			if not issecretvalue(over) and over == true then return true end
		end
	end
	return false
end

-- A window that shows lies over some of that rectangle (UIParent units).
function HUD.WindowOn(left, bottom, right, top)
	for _, box in ipairs(windows) do
		if Visible(box) then
			local l, b, w, h = Rect(box)
			if l and l < right and l + w > left and b < top and b + h > bottom then return true end
		end
	end
	return false
end

function HUD.Folded(box, on)
	on = on and true or nil
	if box.folded == on then return end
	box.folded = on
	Shy:Fire("SHY_HUD_FOLDED", box)
end

-- A `hang` box keeps its top edge; a position saved without one gets its top recorded once.
function HUD.Resize(box, width, height)
	local changed = math.abs(box:GetWidth() - width) > 0.01 or math.abs(box:GetHeight() - height) > 0.01
	box:SetSize(width, height)
	local saved = Saved(box)
	if box.hang and saved and saved.x and not saved.top and box:GetTop() and not Busy(box) then
		saved.top = box:GetTop()
		HUD.Apply(box)
	elseif box.hang and changed then
		HUD.Apply(box)   -- down while there is room under it, else up (Room)
	end
	-- Told at once, so whoever stacks the box with others can move them before the frame is drawn.
	if changed then
		Follow(box)
		Shy:Fire("SHY_HUD_RESIZED", box)
	end
end

-- ShyCore's own adoption of a frame gives way to an addon's: the frame goes back to Blizzard's place
-- and size, so the new box reads Blizzard's anchors, and the old box is dropped.
local function Retire(box)
	box.retired = true
	for i, each in ipairs(boxes) do
		if each == box then
			table.remove(boxes, i)
			break
		end
	end
	if box.mover then box.mover:Hide() end
	if selected == box then Select(nil) end
	box.activeFn = function() return false end
	if not Busy(box) then ApplyForeign(box) end
end

function HUD.Adopt(frame, def)
	local held = owners[frame]
	if held and held.generic then Retire(held) end
	-- A proxy: our fields live on this table and frame methods are forwarded, so nothing is written
	-- onto Blizzard's frame.
	local box = setmetatable({
		id = def.id, title = def.title, foreign = frame, activeFn = def.active, home = {},
		plain = def.plain, still = def.mover == false, editMode = def.editMode, generic = def.generic,
		scalable = def.scale == true, homeScale = frame:GetScale(),
	}, { __index = function(proxy, key)
		local value = frame[key]
		if type(value) ~= "function" then return value end
		-- One forwarder a method, kept: it looks the method up as it is called, so a hook added later
		-- still runs.
		local forward = function(_, ...) return frame[key](frame, ...) end
		rawset(proxy, key, forward)
		return forward
	end })
	owners[frame] = box
	for i = 1, frame:GetNumPoints() do box.home[i] = { frame:GetPoint(i) } end

	-- Moved or resized by the player in Edit Mode: from then on Edit Mode's.
	local function Theirs()
		return box.editMode and frame.isSelected == true and EditModeManagerFrame:IsEditModeActive()
	end
	local function Taken()
		local saved = Saved(box)
		if saved then saved.x, saved.y, saved.top, saved.locked = nil, nil, nil, nil end
		Tidy(box)
		box.placed = nil
		if def.taken then def.taken(box) end
	end

	-- Record Blizzard's anchors as they are set, then re-apply ours.
	hooksecurefunc(frame, "ClearAllPoints", Shy.Clocked("hud: " .. tostring(def.id) .. " cleared by the game", function()
		if not box.applying and not box.retired then wipe(box.home) end
	end))
	hooksecurefunc(frame, "SetPoint", Shy.Clocked("hud: " .. tostring(def.id) .. " moved by the game", function(_, point, ...)
		if box.applying or box.retired then return end
		if Theirs() and Saved(box) and Saved(box).x then Taken() end
		-- While Blizzard re-sets anchors for a new scale it reads them back: ours, while it is placed.
		if not (box.rescaling and box.placed) then
			local entry = { point, ... }
			for i, each in ipairs(box.home) do
				if each[1] == point then
					table.remove(box.home, i)
					break
				end
			end
			box.home[#box.home + 1] = entry
		end
		HUD.Apply(box)
	end))
	if box.scalable then
		-- Edit Mode's SetScale is SetScaleBase, then each anchor set again for the new scale.
		if type(frame.SetScaleBase) == "function" then
			hooksecurefunc(frame, "SetScaleBase", function()
				if not box.applying then box.rescaling = true end
			end)
		end
		hooksecurefunc(frame, "SetScale", Shy.Clocked("hud: " .. tostring(def.id) .. " scaled by the game", function(_, scale)
			box.rescaling = false
			if box.applying or box.retired then return end
			local was = box.homeScale
			box.homeScale = scale
			local saved = Saved(box)
			if Theirs() and saved and saved.scale then saved.scale, box.scaled = nil, nil end
			-- A saved place is in the frame's own units: keep it where it was on screen at Blizzard's new size.
			if saved and saved.x and not saved.scale and was and was ~= scale then
				saved.x, saved.y = saved.x * was / scale, saved.y * was / scale
				if saved.top then saved.top = saved.top * was / scale end
			end
			HUD.Apply(box)
		end))
	end
	if def.editMode and type(frame.OnDragStart) == "function" then
		-- Dragged in Edit Mode: its position is Edit Mode's from then on. Not every Edit Mode frame
		-- has OnDragStart (the objective tracker doesn't), and hooking a missing method errors.
		hooksecurefunc(frame, "OnDragStart", function()
			if not box.retired then Taken() end
		end)
	end
	if def.reset and type(frame.ResetToDefaultPosition) == "function" then
		hooksecurefunc(frame, "ResetToDefaultPosition", function()
			if not box.retired then def.reset(box) end
		end)
	end
	if not box.still then Mover(box) end
	boxes[#boxes + 1] = box
	HUD.Apply(box)
	return box
end

function HUD.Adopted(frame)
	return owners[frame]
end

-- A Blizzard frame whose width and height the player may set (the chat, the damage meter): kept in
-- its box's entry as w and h and put back whenever Blizzard sizes it. Sized by the player in Edit
-- Mode, it is Edit Mode's again. Whichever box owns the frame then holds the size.
function HUD.Sized(frame)
	if sized[frame] then return end
	local own = {}
	own.w, own.h = frame:GetSize()
	sized[frame] = own
	hooksecurefunc(frame, "SetSize", Shy.Clocked("hud: " .. (frame:GetName() or "a frame") .. " sized by the game", function(_, w, h)
		local box = owners[frame]
		if not box or box.applying or box.retired then return end
		if type(w) ~= "number" or type(h) ~= "number" or issecretvalue(w) or issecretvalue(h) then return end
		local saved = Saved(box)
		if saved and saved.w and box.editMode and frame.isSelected == true and EditModeManagerFrame:IsEditModeActive() then
			saved.w, saved.h = nil, nil
			Tidy(box)
			saved = Saved(box)
		end
		-- Blizzard sets one of the two at a time and reads the other back: ours, while one is kept.
		local kept = saved and saved.w
		if not kept or math.abs(w - saved.w) > 0.5 then own.w = w end
		if not kept or math.abs(h - saved.h) > 0.5 then own.h = h end
		HUD.Apply(box)
	end))
	local box = owners[frame]
	if box then HUD.Apply(box) end
end

-- An adopted frame standing `units` shorter from its foot, its top where it was (0: as placed). For a
-- moment only, and gliding (the chat window giving its foot to the edit box while it is typed in):
-- nothing is saved, and wherever the frame is placed, by the player, a home or the game, keeps it.
-- Units are the frame's own, as its anchor offsets are.
function HUD.Lift(box, units)
	local frame = box.foreign
	if not frame then return end
	units = math.max(0, math.floor((units or 0) + 0.5))
	if (box.lift or 0) == units then return end
	-- A frame whose size is the game's: the size it had before the lift, to give back.
	if units > 0 and (box.lift or 0) == 0 and not sized[frame] then
		local w, h = frame:GetSize()
		if type(w) == "number" and type(h) == "number" and not issecretvalue(w) and not issecretvalue(h) then
			box.unlifted = { w = w, h = h }
		end
	end
	box.lift = units
	HUD.Apply(box)
end

-- How far an adopted frame stands lifted from its foot now, in UIParent units (0: as placed). What measures
-- the frame to dock against it adds this back: the lift is a moment's, and the frame's place hasn't changed.
function HUD.Lifted(frame)
	local box = owners[frame]
	if not box or (box.lift or 0) == 0 then return 0 end
	return box.lift * Scaled(box)
end

function HUD.IsSized(frame)
	return sized[frame] ~= nil
end

local housings = setmetatable({}, { __mode = "k" })   -- game frame -> the region its panel covers

function HUD.SetHousing(frame, region)
	housings[frame] = region
end

-- The panel's region while it shows; nil otherwise.
function HUD.HousingOf(frame)
	local region = housings[frame]
	if region and region:IsShown() then return region end
	return nil
end

function HUD.DragHandle(box, handle)
	handle:EnableMouse(true)
	handle:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and not (box.secure and InCombatLockdown()) then StartDrag(box) end
	end)
	handle:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then StopDrag() end
	end)
end

-- A control that stands on a window's title bar (a button, the words that open a menu). Pressed and
-- let go it is clicked as ever; pressed and moved DRAG_START pixels it drags the box like the bar under
-- it, and HUD.WasDragged(box) is then true in its click handler, which must do nothing. Like the bar it
-- drags at any time. Call it after the control's own scripts are set.
function HUD.Carry(box, control)
	local held = false
	control:HookScript("OnMouseDown", function(_, button)
		box.wasDragged = false
		if button ~= "LeftButton" or (box.secure and InCombatLockdown()) then return end
		held = true
		Press(box)
	end)
	control:HookScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then return end
		held = false
		StopDrag()
	end)
	-- A dragged frame's mouse-up sometimes never comes (see StartDrag): the control is let go all the same,
	-- so it doesn't stay looking pressed.
	Shy:On("SHY_HUD_MOVED", function(moved)
		if moved ~= box or not held then return end
		local up = control:GetScript("OnMouseUp")
		if up then up(control, "LeftButton") end
	end)
end

-- An edit box on a window's title bar (a search box). While nobody types in it a cover lies over it: a
-- click on the cover puts the cursor in the box, a press that moves drags the box's window. While it is
-- typed in the cover is away and the mouse is the edit box's, to place the cursor and select text. `over`
-- is what the cover lies over when that is more than the edit box (the plate it is set in). Call it after
-- the edit box's own focus scripts are set. Returns the cover.
function HUD.CarryEdit(box, edit, over)
	local cover = CreateFrame("Button", nil, edit)
	cover:SetAllPoints(over or edit)
	cover:SetFrameLevel(edit:GetFrameLevel() + 2)
	cover:SetScript("OnClick", function(_, button)
		if button == "LeftButton" and not HUD.WasDragged(box) then edit:SetFocus() end
	end)
	HUD.Carry(box, cover)
	edit:HookScript("OnEditFocusGained", function() cover:Hide() end)
	edit:HookScript("OnEditFocusLost", function() cover:Show() end)
	cover:SetShown(not edit:HasFocus())
	return cover
end

-- `frame` defaults to the box. A press becomes a drag only after DRAG_START pixels, so clicks still
-- reach the frame. Not for secure boxes: their buttons take the mouse. The menu's entries are also
-- offered by the box's mover in layout mode. `menu` false: the frame only drags the box (a frame with
-- a right-click of its own: a chat tab). `when`: a function; the frame does neither while it is false.
function HUD.Manage(box, frame, menu, when)
	frame = frame or box
	if menu ~= false then box.menu = menu end
	frame:EnableMouse(true)
	frame:HookScript("OnMouseDown", function(_, button)
		box.wasDragged = false
		if button ~= "LeftButton" or unlocked or not Active(box) or Busy(box) then return end
		if when and not when() then return end
		if IsLocked(box) then
			if HUD.OnLocked then HUD.OnLocked(box) end   -- its corner shows why (Grip.lua)
			return
		end
		Press(box)
	end)
	frame:HookScript("OnMouseUp", function(_, button)
		StopDrag()
		if button ~= "RightButton" or menu == false or unlocked or not Active(box) then return end
		if when and not when() then return end
		OpenMenu(box, frame, menu)
	end)
end

function HUD.WasDragged(box)
	return box.wasDragged == true
end

-- The mover over another frame than the box: a deck whose base is only an anchor under its column.
function HUD.Cover(box, frame)
	box.cover = frame   -- and its edges are the box's, for whatever lines up with it (Snap)
	local m = box.mover
	if not m then return end
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", frame, "TOPLEFT")
	m:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
end

-- Keeps the box where it stands as a position the player set (IsPlaced): a docked box taken out of
-- its deck stays put while the deck goes on without it.
function HUD.Release(box)
	if Busy(box) or not Rect(box) then return end
	HUD.SetCarried(box, false)
	Remember(box)
end

-- A carried box is moved by another piece (docked in a deck): no mover of its own and nothing snaps
-- to it, but unlike a `still` box it keeps its own size and lock.
function HUD.SetCarried(box, on)
	on = on and true or false
	if box.carried == on then return end
	box.carried = on
	if box.mover then box.mover:SetShown(MoverShown(box)) end
end

function HUD.IsDragging(box)
	return dragging == box
end

-- A piece is in hand: dragged, or sized by one of its handles (Grip.lua's HUD.Sizing). The mouse is that
-- piece's until it is let go: what comes up under the mouse (a drawer out of its pull) stays as it is.
function HUD.InHand()
	return dragging ~= nil or (HUD.Sizing ~= nil and HUD.Sizing() == true)
end

-- Temporarily anchors a box to another (so the engine drags them together); HUD.Apply undoes it.
-- x and y are in the box's own units.
function HUD.Attach(box, to, point, relativePoint, x, y)
	box.applying = true
	if box.foreign then
		Clear(box)
		Anchor(box, point, to, relativePoint, x, y)
	else
		box:ClearAllPoints()
		box:SetPoint(point, to, relativePoint, x, y)
	end
	box.applying = false
end

-- For an addon that arranges the whole screen

function HUD.Each(fn)
	for _, box in ipairs(boxes) do fn(box) end
end

function HUD.Find(id)
	for _, box in ipairs(boxes) do
		if box.id == id then return box end
	end
end

-- The empty room in the screen's middle: what no piece on screen (windows aside) stands in, a seam clear of
-- them. First the pieces across the middle (the top column, the bars) close it from above and below, then
-- the ones beside that band (the minimap's column, chat's, the meter's) from the sides. Returns its left,
-- bottom, right and top in UIParent units. `except`: a box to leave out (the window to be stood there).
function HUD.Room(except)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local cx, cy = sw / 2, sh / 2
	local rects = {}
	for _, box in ipairs(boxes) do
		if box ~= except and not box.window and not box.still and not box.carried and Visible(box) then
			local l, b, w, h = Rect(Face(box))
			if l and w > 0 and h > 0 then rects[#rects + 1] = { l, b, l + w, b + h } end
		end
	end
	local left, bottom, right, top = SEAM, SEAM, sw - SEAM, sh - SEAM
	for _, r in ipairs(rects) do
		if r[1] < cx and r[3] > cx then
			if (r[2] + r[4]) / 2 < cy then bottom = math.max(bottom, r[4] + SEAM) else top = math.min(top, r[2] - SEAM) end
		end
	end
	for _, r in ipairs(rects) do
		if not (r[1] < cx and r[3] > cx) and r[2] < top and r[4] > bottom then
			if r[3] <= cx then left = math.max(left, r[3] + SEAM) else right = math.min(right, r[1] - SEAM) end
		end
	end
	return left, bottom, right, top
end

function HUD.IsPlaced(box)
	local saved = Saved(box)
	return saved ~= nil and saved.x ~= nil
end

-- Where the player put a box, as a copy to keep somewhere else (nil: they didn't), and given back: for a
-- place that is the player's screen's rather than a profile's (the setup window, opened as profiles change).
function HUD.Spot(box)
	local saved = Saved(box)
	if not (saved and saved.x) then return nil end
	return { x = saved.x, y = saved.y, scale = saved.scale, top = saved.top }
end

function HUD.SetSpot(box, spot)
	if not (spot and spot.x) then return end
	local saved = Keep(box)
	saved.x, saved.y, saved.scale, saved.top = spot.x, spot.y, spot.scale, spot.top
	HUD.Apply(box)
end

-- The home is the box's default position and what reset returns it to; a position the player set
-- wins. point: { boxPoint, screenPoint, x, y }. For an adopted frame, nil returns it to Blizzard's anchors.
-- scale: the size the home comes at (an adopted frame's, on Blizzard's own), until the player sizes it.
function HUD.SetHome(box, point, scale)
	box.givenScale = scale
	if box.foreign then
		box.given = point
	else
		box.defaultPoint = point
	end
	HUD.Apply(box)
end

-- The width a box's place gives it (a column's). `own`: no place gives it one any longer, and `width` is the
-- one it had before; a box that keeps a width of the player's wears that instead, so it is always told.
function HUD.Fit(box, width, own)
	if box.fitFn and (own or math.abs(box:GetWidth() - width) > 0.5) then box.fitFn(box, width, own) end
end

function HUD.SetDocked(box, on)
	on = on and true or false
	if box.docked == on then return end
	box.docked = on
	if box.dockedFn then box.dockedFn(box, on) end
end

-- A `still` box is built into another piece and moves with it: no mover, nothing snaps to it, and
-- its saved position and scale are dropped.
function HUD.SetStill(box, on)
	on = on and true or false
	if on then
		local saved = Saved(box)
		if saved and (saved.x or saved.scale) then
			saved.x, saved.y, saved.top, saved.scale = nil, nil, nil, nil
			HUD.Apply(box)
		end
	end
	if box.still == on then return end
	box.still = on
	if box.mover then box.mover:SetShown(MoverShown(box)) end
end

-- Drops the saved position (back to its home); lock is kept, and scale unless `size`.
function HUD.Forget(box, size)
	local saved = Saved(box)
	if not saved then return end
	saved.x, saved.y, saved.dock = nil, nil, nil
	if size then saved.scale, saved.w, saved.h = nil, nil, nil end
	HUD.Apply(box)
end

-- A `dock` window docked on `side` ("LEFT", "RIGHT"; true: the side it stood on last, else its made one), or
-- free where it stands now (false).
function HUD.Dock(box, side)
	if not (box.dock and Host(box)) or Busy(box) then return end
	if side then
		if side ~= "LEFT" and side ~= "RIGHT" then side = box.lastDock or box.dock.side or "LEFT" end
		Dock(box, side)
		return
	end
	if not DockSide(box) then return end
	local left, bottom = Rect(box)
	Keep(box).dock = false
	if left then Place(box, left, bottom) end
	Remember(box)
end

-- The side a `dock` window stands on beside its host now (it takes the other where its own has no room),
-- nil while it stands free.
function HUD.Docked(box)
	if not DockSide(box) then return nil end
	return box.dockedOn
end

function HUD.IsUnlocked() return unlocked end

-- A piece that stands over the game's windows (dialog strata and up) steps down to the movers' while
-- the screen is being arranged: Edit Mode's panel and the piece editor are dialogs and stay on top.
local function StepDown(box, on)
	if box.foreign or box.secure then return end
	if on then
		local strata = box:GetFrameStrata()
		if (STRATA[strata] or 0) > STRATA.HIGH then
			box.ownStrata = strata
			box:SetFrameStrata("HIGH")
		end
	elseif box.ownStrata then
		box:SetFrameStrata(box.ownStrata)
		box.ownStrata = nil
	end
end

-- Opens or closes the movers; `along` while Edit Mode is open (no grid or toolbar of our own).
local function Unlock(on, along)
	unlocked, alongside = on, on and along or false
	StopDrag()
	if not on then Select(nil) end
	-- Edit Mode draws its own grid: alongside it the screen is only dimmed.
	overlay:SetShown(on)
	toolbar:SetShown(on and not along)
	watch:SetShown(on)
	if on and not along then DrawGrid() end
	for _, t in ipairs(gridLines) do t:SetShown(on and not along and t:IsShown()) end
	centerV:SetShown(not along)
	centerH:SetShown(not along)
	ShowMovers()
	for _, box in ipairs(boxes) do
		StepDown(box, on)
		HUD.Update(box)
	end
	Shy:Fire("SHY_HUD_LAYOUT", on)
	if on and not along then Bar.Look() end   -- after every box is out
end

function HUD.SetUnlocked(on)
	if on and InCombatLockdown() then
		core:Print("layout mode isn't available in combat.")
		return
	end
	if on and EditModeManagerFrame:IsEditModeActive() then return end   -- open alongside it already
	if on and SettingsPanel:IsShown() then SettingsPanel:Close(true) end
	Unlock(on and true or false, false)
end

-- Windows keep their saved positions.
function HUD.ResetAll()
	local kept = {}
	for _, box in ipairs(boxes) do
		if box.window then kept[box.id] = Saved(box) end
	end
	-- In place: the table is the active layout's (Editor.lua).
	wipe(core.db.hud)
	for id, saved in pairs(kept) do core.db.hud[id] = saved end
	for _, box in ipairs(boxes) do
		HUD.Apply(box)
		if box.mover then Look(box) end
	end
	Bar.Readout()
end

local resetAll = UI.Button(toolbar, "Reset all", 96, HUD.ResetAll)
resetAll:SetPoint("TOPRIGHT", -114, -12)
resetAll:HookScript("OnEnter", function(self)
	UI.Tip(self, "Reset all", "Puts everything back where it started. The game's own pieces go back to their Edit Mode place and size.")
end)
resetAll:HookScript("OnLeave", function(self) UI.TipHide(self) end)
local done = UI.Button(toolbar, "Done", 90, function() HUD.SetUnlocked(false) end)
done:SetPoint("TOPRIGHT", -14, -12)

-- Edit Mode opens through a secure button: from addon code its manager would run tainted. Layout mode
-- closes before combat, so the toolbar is never hidden in a fight.
local editMode = CreateFrame("Button", nil, toolbar, "SecureActionButtonTemplate")
editMode:SetSize(100, 24)
editMode:SetPoint("TOPRIGHT", -218, -12)
editMode:RegisterForClicks("AnyUp", "AnyDown")
editMode:SetAttribute("type", "macro")
editMode:SetAttribute("macrotext", SLASH_EDITMODE1)
UI.ButtonFace(editMode, "Edit Mode")
editMode:SetScript("OnEnter", function(self)
	UI.SetBorder(self, UI.colors.hot)
	UI.Tip(self, "Edit Mode", "Opens the game's Edit Mode. You can move these pieces there too.")
end)
editMode:SetScript("OnLeave", function(self)
	UI.SetBorder(self, UI.colors.border)
	UI.TipHide(self)
end)
Bar.editMode = editMode

-- core.db.layoutBar = { x, top, slim }: where the player dropped it, and whether it is folded.

Bar.TOP, Bar.MARGIN = 40, 8

function Bar.Saved()
	core.db.layoutBar = core.db.layoutBar or {}
	return core.db.layoutBar
end

-- Width, height, and height with its strips.
function Bar.Size()
	if Bar.Saved().slim then return Bar.SLIM_W, Bar.SLIM_H, Bar.SLIM_H end
	return Bar.FULL_W, Bar.FULL_H, Bar.FULL_H + stripsTall
end

-- Area of a rectangle covered by boxes.
function Bar.Covered(left, bottom, width, height)
	local area = 0
	for _, box in ipairs(boxes) do
		local l, b, w, h = nil, nil, nil, nil
		if not box.window and Visible(box) then l, b, w, h = Rect(box) end
		if l then
			local across = math.min(left + width, l + w) - math.max(left, l)
			local up = math.min(bottom + height, b + h) - math.max(bottom, b)
			if across > 0 and up > 0 then area = area + across * up end
		end
	end
	return area
end

-- The first spot that covers no box (top center first): center x and top y.
function Bar.Spot()
	local width, _, tall = Bar.Size()
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local side = Bar.MARGIN + width / 2
	local columns = { sw / 2, sw / 4, sw * 3 / 4, side, sw - side }
	local rows = { sh - Bar.TOP, (sh + tall) / 2, tall + Bar.TOP }
	local x, top, least
	for _, y in ipairs(rows) do
		for _, middle in ipairs(columns) do
			local covered = Bar.Covered(middle - width / 2, y - tall, width, tall)
			if covered == 0 then return middle, y end
			if not least or covered < least then x, top, least = middle, y, covered end
		end
	end
	return x, top
end

function Bar.Place()
	local saved = Bar.Saved()
	local width, height, tall = Bar.Size()
	local x, top = saved.x, saved.top
	if not x then x, top = Bar.Spot() end
	toolbar:SetSize(width, height)
	toolbar:SetClampRectInsets(0, 0, 0, height - tall)   -- keeps the strips on screen
	toolbar:ClearAllPoints()
	toolbar:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, top)
end

-- The first line says what is picked, where it stands and its size; with nothing picked, how to work.
function Bar.Readout()
	local box = selected
	local left, bottom = nil, nil
	if box then left, bottom = Rect(box) end
	if not left then
		hint:SetText(Bar.HINT)
		return
	end
	local size = math.floor(box:GetScale() / (box.foreign and box.homeScale or 1) * 100 + 0.5)
	hint:SetText(("%s  \194\183  %d, %d  \194\183  %d%%%s"):format(box.title, math.floor(left + 0.5), math.floor(bottom + 0.5), size,
		IsLocked(box) and "  \194\183  locked" or ""))
end

Bar.fold = UI.Button(toolbar, "Shrink", 80, function()
	local saved = Bar.Saved()
	saved.slim = not saved.slim or nil
	Bar.Look()
end)
Bar.fold:HookScript("OnEnter", function(self)
	UI.Tip(self, self.text:GetText(), "Folds this bar to a slim one, or opens it again. Right-click the bar to send it back to a free spot.")
end)
Bar.fold:HookScript("OnLeave", function(self) UI.TipHide(self) end)

function Bar.Look()
	local slim = Bar.Saved().slim and true or false
	hint:SetShown(not slim)
	Bar.grip:SetShown(not slim)
	resetAll:SetShown(not slim)
	editMode:SetShown(not slim)
	for _, strip in ipairs(Bar.strips) do strip:SetShown(not slim) end
	Bar.fold.text:SetText(slim and "Expand" or "Shrink")
	Bar.fold:ClearAllPoints()
	Bar.fold:SetPoint("TOPRIGHT", slim and -112 or -326, slim and -9 or -12)
	done:ClearAllPoints()
	done:SetPoint("TOPRIGHT", -14, slim and -9 or -12)
	Bar.Readout()
	Bar.Place()
end

Bar.driver = CreateFrame("Frame")
function Bar.Drop()
	Bar.driver:UnregisterEvent("GLOBAL_MOUSE_UP")
	if not Bar.moving then return end
	Bar.moving = nil
	toolbar:StopMovingOrSizing()
	toolbar:SetUserPlaced(false)
	local saved = Bar.Saved()
	saved.x = toolbar:GetCenter()
	saved.top = toolbar:GetTop()
	Bar.Place()
end
-- This client sometimes never delivers the mouse-up to a dragged frame.
Bar.driver:SetScript("OnEvent", Bar.Drop)

-- Drag by the toolbar or a strip; right-click returns it to a free spot.
function Bar.Grip(frame)
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then return end
		Bar.moving = true
		toolbar:StartMoving()
		Bar.driver:RegisterEvent("GLOBAL_MOUSE_UP")
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			Bar.Drop()
		elseif button == "RightButton" then
			local saved = Bar.Saved()
			saved.x, saved.top = nil, nil
			Bar.Place()
		end
	end)
end
Bar.Grip(toolbar)
HUD.Bar = Bar

-- What a picked piece can be asked to do (Editor.lua's panel), and the boxes for a whole layout.
HUD.Act = {
	Scalable = Scalable, IsLocked = IsLocked, SetScale = SetScale, ResetScale = ResetScale, Outline = Outline,
	Center = Center, Nudge = Nudge, Select = Select, Look = Look,
	Selected = function() return selected end,
	Base = function(box) return box.foreign and (box.homeScale or 1) or 1 end,
	-- For whoever sizes a piece by hand (Grip.lua).
	Rect = Rect, Place = Place, Remember = Remember, Keep = Keep, Busy = Busy, Active = Active,
	Rescale = Rescale, ResetSize = ResetSize,
	-- Docked beside its host: its place is the host's side (Grip.lua holds nothing still for it).
	Docked = function(box) return DockSide(box) ~= nil end,
	HasSize = function(box)
		local saved = Saved(box)
		return saved ~= nil and saved.w ~= nil
	end,
	Lock = function(box, on)
		Keep(box).locked = on or nil
		Tidy(box)
		Look(box)
	end,
	ResetPosition = function(box)
		local saved = Saved(box)
		if saved then saved.x, saved.y, saved.top, saved.dock = nil, nil, nil, nil end
		Tidy(box)
		HUD.Apply(box)
		Look(box)
		Shy:Fire("SHY_HUD_MOVED", box)
	end,
	Menu = function(box, owner) OpenMenu(box, owner, box.menu) end,
	-- Every box placed again from core.db.hud (another layout's table, or one put back).
	ApplyAll = function()
		for _, box in ipairs(boxes) do
			HUD.Apply(box)
			if box.mover then Look(box) end
		end
		Bar.Readout()
	end,
}

-- "Layout mode" buttons open Edit Mode, which ShySkin dresses as Shy's layout editor, through one
-- secure button laid over them while the mouse is on them: Edit Mode opened from addon code would
-- run tainted. The secure button is a child of UIParent placed by absolute coordinates, never
-- anchored or parented to the button (that would make a settings page protected), and is hidden in
-- combat; then the button's own click opens Shy's layout mode.
local function Key()
	if HUD.key then return HUD.key end
	local key = CreateFrame("Button", "ShyLayoutKey", UIParent, "SecureActionButtonTemplate")
	key:SetFrameStrata("FULLSCREEN_DIALOG")
	key:SetFrameLevel(500)
	key:RegisterForClicks("AnyUp", "AnyDown")
	key:SetAttribute("type", "macro")
	key:SetAttribute("macrotext", SLASH_EDITMODE1)
	key:Hide()
	-- Hover and press are the button's under it, for its look.
	local function Tell(script)
		return function(self, ...)
			local owner = self.owner
			local fn = owner and owner:GetScript(script)
			if fn then fn(owner, ...) end
		end
	end
	key:SetScript("OnEnter", Tell("OnEnter"))
	key:SetScript("OnLeave", function(self)
		Tell("OnLeave")(self)
		self.owner = nil
		if not InCombatLockdown() then self:Hide() end
	end)
	key:HookScript("OnMouseDown", Tell("OnMouseDown"))
	key:HookScript("OnMouseUp", Tell("OnMouseUp"))
	key:SetScript("PreClick", function(_, _, down)
		if down then return end
		if SettingsPanel:IsShown() then SettingsPanel:Close(true) end
		if unlocked and not alongside then Unlock(false) end
	end)
	HUD.key = key
	return key
end

function HUD.EditModeKey(button)
	button:HookScript("OnEnter", function(self)
		if InCombatLockdown() or not EditModeManagerFrame:CanEnterEditMode() then return end
		local left, bottom, width, height = self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight()
		if not left then return end
		local key, s = Key(), self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		key.owner = self
		key:ClearAllPoints()
		key:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
		key:SetSize(width * s, height * s)
		key:Show()
	end)
end

-- A "Layout mode" button for an options page or window.
function HUD.LayoutButton(parent, width, text)
	local b = UI.Button(parent, text or "Layout mode", width, function() HUD.SetUnlocked(true) end)
	HUD.EditModeKey(b)
	return b
end

-- Esc leaves layout mode and arrow keys nudge the picked box (Shift: by half a grid step); every
-- other key passes through to the game.
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
toolbar:EnableKeyboard(true)
toolbar:SetScript("OnKeyDown", function(self, key)
	local step = NUDGE[key]
	if key == "ESCAPE" then
		self:SetPropagateKeyboardInput(false)
		HUD.SetUnlocked(false)
	elseif step and selected then
		self:SetPropagateKeyboardInput(false)
		local by = IsShiftKeyDown() and GRID / 2 or 1
		Nudge(selected, step[1] * by, step[2] * by)
	else
		self:SetPropagateKeyboardInput(true)
	end
end)

-- Edit Mode: Shy's boxes can be moved while it is open.
EventRegistry:RegisterCallback("EditMode.Enter", function()
	if InCombatLockdown() then return end
	if unlocked then Unlock(false) end   -- layout mode closes as Edit Mode takes over
	Unlock(true, true)
end, HUD)
EventRegistry:RegisterCallback("EditMode.Exit", function()
	if alongside then Unlock(false) end
end, HUD)

-- The world map at full screen has the screen to itself: the game lays black behind it, low, and
-- everything else on the screen would stand on that black beside the map, or over the map where it is
-- higher. So every box goes (a secure one once no fight holds it) and comes back with the map made
-- small or closed; whoever draws something that isn't a box follows SHY_HUD_COVERED.
function HUD.IsCovered() return covered end

local function Covered()
	local map = rawget(_G, "WorldMapFrame")
	local now = map ~= nil and map:IsVisible() == true and map:IsMaximized() == true
	if now == covered then return end
	covered = now
	for _, box in ipairs(boxes) do HUD.Update(box) end
	Shy:Fire("SHY_HUD_COVERED", covered)
end
for _, event in ipairs({ "WorldMapMaximized", "WorldMapMinimized", "WorldMapOnShow", "WorldMapOnHide" }) do
	EventRegistry:RegisterCallback(event, Covered, HUD)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if unlocked then Unlock(false) end
		if HUD.key then HUD.key:Hide() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		for box in pairs(waiting) do
			waiting[box] = nil
			HUD.Apply(box)
			HUD.Update(box)
		end
	elseif unlocked and not alongside then
		DrawGrid()
	end
end)
