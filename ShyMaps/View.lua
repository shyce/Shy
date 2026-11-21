-- The view: the map drawn by frames of our own, in the map's window (Window.lua, View.Host). Nothing of the
-- game's map is called or written from here, so its pins are never made from addon code (the game refuses
-- that); the game's own map window is left as it is, its canvas the game's.
--
-- The overlay (T.db.overlay): while the window is closed, the same view lies faintly over the whole
-- screen, under everything else, and takes no mouse: its port moves onto a cover of the screen's size,
-- and every frame on it is kept from the mouse (looked over again now and then, for pins made since). What
-- stands on the map (you, the trail, the pins) moves onto a second cover over that one, faded far less
-- (T.db.overlayMarks), so it reads on a map the world shows through. It keeps you in its very middle and
-- turns to your zone as you walk out of the one shown. The window opening takes
-- the view back; closing, it goes onto the overlay again. What stands over the window (its controls,
-- other addons' notes: View.Chrome()) stays with the window. With neither, the view rests out of sight.
--
-- The canvas is a frame of the map art's size (art pixels), scaled by `s` and placed in the port (the
-- game's canvas area) so that the art point cx, cy (shares of the art) stands in the port's middle. The
-- zoom runs from `fit` (the whole art in the port) to `deep`.
--
--   View.Show(map, how)   how: nil (as it was left), "here" (centred on you), "whole" (all of it),
--                         "into" / "out" (from the map shown: the new art starts where it lies on the old
--                         and settles from there)
--   View.Rebase(map)      the same place on screen, told as another map of its world (crossing a zone's edge)
--   View.World(map) -> world, north, west of its top left, north, west of its bottom right (yards)
--   View.Corners(map, world) -> north, west of its top left, of its bottom right in that world's yards
--   View.Region(map, world) -> x1, x2, y1, y2: where that world lies on the world's map (shares)
--   View.SetFree(test)    test(map): the map's world goes on past its edges, and the view with it
--   View.SetBare(test)    test(map): the map shows the ground alone; what stands on the view fades out
--   View.Open(map)        the open map goes to `map`; closed, it opens there next time
--   View.InUse(), View.Map(), View.Port(), View.Scale(), View.Fit(), View.Zoom() (0-1)
--   View.Canvas()         what stands on the map goes here    View.Land()   the map's own ground and art
--   View.Chrome()         what stands over the map's window goes here (its size and place; never on the overlay)
--   View.Overlaid()       the view lies over the screen (the overlay), not in the window
--   View.Size() -> art width, height    View.Cursor() -> x, y (shares of the art; nil off it)
--   View.ToPort(x, y) -> port units from its top left    View.PlayerAt(map) -> x, y
--   View.Place(frame, x, y, size)   a frame on the canvas, `size` times its own size on screen at any zoom
--   View.Glide(x, y, zoom)   View.Seek(zoom): to you, aiming at you until you're in the middle
--   View.Leaning()        ... and stands ahead of you now: its middle is not where you are
--   View.Astray()         moved by hand (or sent somewhere), the view stays there: following waits
--   View.Following()      the view is keeping you in the middle (T.db.follow, and not astray); led somewhere
--                         (Shy.Maps.Led), a little back from the middle, looking ahead along the way
--   View.SeesYou()        you are on the map shown, inside the port
--   View.ZoomAt(factor)   View.Busy()   View.OnChange(fn(why))
--   View.Fly(map, done)   in one move to the whole of `map`    View.Flying() -> the map it is flying to
--   View.Moving()   on its way somewhere of its own    View.Outward()   the zoom is going down
--   ns.Layer{ id, Map(map), Scale(s), Tick(dt), Open(), Close(), Use(on) }   told as the view changes

local ADDON, ns = ...
local T = ns.T

local View = {}
ns.View = View

local LEVEL = 9100          -- above the game's map pins, which its canvas lays no higher than 9000
local ZOOM_SPEED = 34       -- how fast the zoom eases to where it is going (most of the way in a tenth of a second)
local PAN_SPEED = 12
local WHEEL = 1.5           -- zoom a notch of the wheel
local DEEP_LEAST = 2.5      -- the deepest zoom, at least, times the whole map's size
local GLIDE = 5             -- how fast a thrown map slows
local CLICK = 20            -- a press that moves less than this (port units, squared) is a click
local DOUBLE = 0.35         -- seconds between the two clicks of a double click
local FADE = 0.15           -- seconds a new map takes to come in
local FOLLOW_EDGE = 0.18    -- share of the port's size: nearer its edge than this, you are walking out of sight
local FOLLOW_WALK = 0.25    -- share of the port's shorter side you walk before a view moved by hand comes back to you
local FOLLOW_YARDS = 40     -- ... or this far, zoomed out past where that share is a long way
local GROW = 0.25           -- a pin's extra size at the deepest zoom
local MARKS_FADE = 0.3      -- seconds what stands on the map takes to fade out or back in
local FOCUS = {             -- a focus (View.Focus)
	CROWD = 0,              -- what else stands on the map fades to this (out of sight: nothing of it laid as the view moves)
	FADE = 0.2,             -- seconds it takes to fade out or back in
	DIM = 0.16,             -- the land, a shade darker all over
	EDGE = 0.5,             -- ... and this much darker at the port's edges
	REACH = 0.22,           -- ... the edges' shade reaching this share of the port in
}
local REST = { 800, 600 }   -- the size the view keeps out of sight, while no window holds it
local OVERLAY = {
	HUSH = 0.25,            -- seconds between looks over the overlay for frames that would take the mouse
	ZONE_LOOK = 1,          -- seconds between asks, on the overlay, whether you have walked off the map shown
	DAWN = { 5, 7 },        -- game hours the overlay goes from its night opacity to its day one
	DUSK = { 19, 21 },      -- ... and back
	MARKS_NIGHT = 0.75,     -- what stands on the overlay's map by night, as a share of its opacity by day
}

local LEVELS = {            -- frame levels on the canvas, above LEVEL
	-- (Under the art's overlays, from LEVEL + 1: the continent's wash and art under a zone, every zone's paper, the
	-- painted land between them, every zone's painting, the art left fading over them: Art.lua.)
	PIN_FRAME_LEVEL_MAP_EXPLORATION = 8,
	PIN_FRAME_LEVEL_MAP_HIGHLIGHT = 11,
	PIN_FRAME_LEVEL_FLIGHT_ROUTES = 12,    -- the lines between the flight points you know
	PIN_FRAME_LEVEL_ZONE_NAMES = 13,       -- the zones' names and levels on a continent: over the routes, under the pins
	PIN_FRAME_LEVEL_FLIGHT_POINT = 14,
	PIN_FRAME_LEVEL_TRAVEL = 15,           -- docks and the tram
	PIN_FRAME_LEVEL_AREA_POI = 16,
	PIN_FRAME_LEVEL_SPIRIT_HEALER = 17,
	PIN_FRAME_LEVEL_MAP_LINK = 18,
	PIN_FRAME_LEVEL_ACTIVE_QUEST = 40,
	PIN_FRAME_LEVEL_GROUP_MEMBER = 80,
	PIN_FRAME_LEVEL_CORPSE = 90,
	PIN_FRAME_LEVEL_TOPMOST = 120,
}

local port, back, canvas
local marks                    -- over the canvas, its size: everything that stands on the map
local chrome                   -- over the window's map area: what stands over the window (stays with it)
local cover                    -- the whole screen, low: the overlay's home for the port
local marksAlpha = 1
local focus = {                -- one thing on the map looked at alone (View.Focus)
	on = false,
	alpha = 1,                 -- the crowd's now
	crowd = nil,               -- in what stands on the map: every pin and every addon's layer, which a focus fades
	lift = nil,                -- ... and what a focus keeps in sight: you, and what is in focus
	veil = nil,                -- over the land, under every pin: its shade in a focus
}
local using, open = false, false
local own                   -- { box, well, strip } while the map's window holds the view; nil while it is closed
local rest                  -- out of sight: where the view and what stands over the window wait while it is closed
local laid = {                 -- the overlay
	on = false,                -- the port lies on the cover
	over = nil,                -- a cover of its own over the map's, for what stands on the map: faded less
	hushIn = 0,                -- seconds to its next look for frames that would take the mouse
	zoneIn = 0,                -- ... and to its next ask whether you walked off the map shown
}
local map, w, h, most          -- the map shown, its art's size, its art's deepest zoom (times fit)
local fit, deep = 1, 1
local s, cx, cy = 1, 0.5, 0.5
local want = {}                -- s, x, y: where the view is going
local anchor                   -- an art point held under the mouse while the zoom moves
local travel = false           -- carried over from another map: not held inside the art until it settles
local drag, vx, vy = nil, 0, 0
local touched = 0              -- when the player last moved the view
local astray = false           -- the player moved the view: it stays where they left it until they walk out of sight or ask for themselves
local stood                    -- { map, x, y }: where you stood when the view was moved by hand (how far you have walked since)
local chasing = false          -- `want` is where you are: the view is following you
local lastClick = 0
local pending                  -- a map to open on next time
local fading, shownAt = false, 0
local settled = true
local flight                  -- the view flying to a map (View.Fly)
local meX, meY                 -- where you are on the map shown (shares), read each frame
local seek = 0                 -- until when a glide keeps aiming at you (View.Seek)
local SEEK = 1.5               -- seconds it does at most, then lands where you were
local OPEN_FRAMES = 6          -- frames after an opening whose whole length the timing keeps apart
local sinceOpen                -- frames since the map opened, while those are still counted

local layers, watchers = {}, {}

function ns.Layer(def)
	layers[#layers + 1] = def
	return def
end

function View.OnChange(fn)
	watchers[#watchers + 1] = fn
end

-- How long each piece of work takes: a lap on the core's clock of that name (the task manager reads them
-- under this addon).
-- Each clock found by its name once (the layers are timed at every step of a pan or a zoom).
local clockOf = {}
local function Clock(name, took)
	local clock = clockOf[name]
	if not clock then
		clock = Shy.Clock(name)
		clockOf[name] = clock
	end
	clock:Lap(took)
end

local OTHERS = { id = "other addons" }   -- the watchers, timed as one

-- A layer's clock for what it was told, without making its name again each time.
local layerClocks = setmetatable({}, { __mode = "k" })
local function LayerClock(layer, why)
	local byWhy = layerClocks[layer]
	if not byWhy then
		byWhy = {}
		layerClocks[layer] = byWhy
	end
	local clock = byWhy[why]
	if not clock then
		clock = Shy.Clock((layer.id or "?") .. " " .. why)
		byWhy[why] = clock
	end
	return clock
end

-- The opening: the map shows at once with what is needed to see it (its art and ground, you, its
-- controls); the layers marked `later` come in one a frame after it, then whatever else watches the view,
-- under a spinner if that takes long enough to notice.
local loading               -- { step = the next layer, told = the watchers have been told, at = when it began }

-- (A size is a change of zoom to the layers.)
local HANDLER = { map = "Map", scale = "Scale", size = "Scale", pan = "Pan", open = "Open", close = "Close", use = "Use" }

local function TellLayer(layer, why)
	local fn = layer[HANDLER[why]]
	if not fn then return end
	local from = debugprofilestop()
	local ok, err = pcall(fn, (why == "map" and map) or ((why == "scale" or why == "size") and s) or (why == "use" and using) or nil)
	if not ok then geterrorhandler()(err) end
	LayerClock(layer, why):Lap(debugprofilestop() - from)
end

local function TellWatchers(why)
	local from = debugprofilestop()
	for _, fn in ipairs(watchers) do
		local ok, err = pcall(fn, why)
		if not ok then geterrorhandler()(err) end
	end
	if #watchers > 0 then LayerClock(OTHERS, why):Lap(debugprofilestop() - from) end
end

local function Tell(why)
	for _, layer in ipairs(layers) do TellLayer(layer, why) end
	if why == "map" and loading then
		-- (Every layer has the map now: those still to come in have only their opening left.)
		for i = loading.step, #layers do
			if layers[i].later then TellLayer(layers[i], "open") end
		end
		loading.step = #layers + 1
	end
	-- (What watches the view is told of the opening once, last: it then lays everything as it is.)
	if not (loading and not loading.told) then TellWatchers(why) end
	-- (A new map's pins on the overlay are kept from the mouse on the next frame.)
	if why == "map" or why == "open" then laid.hushIn = 0 end
end

-- Geometry

local function Ease(now, goal, dt, speed)
	return goal + (now - goal) * math.exp(-dt * speed)
end

local roomW, roomH   -- the port's size, read once for the frame's tick (Tick), which asks it again and again
local function Room()
	if roomW then return roomW, roomH end
	return math.max(port:GetWidth(), 1), math.max(port:GetHeight(), 1)
end

-- Free: the map lies in a world that goes on past its edges (the terrain look), so the view isn't held
-- to its art and may draw back a little further than the whole map.
local free
function View.SetFree(test) free = test end
local function Free() return free ~= nil and map ~= nil and free(map) end

-- Bare: the map shows the ground alone (the terrain look's world, every continent side by side), so
-- nothing stands on it: what does fades out as the view comes to it, and back in as it leaves.
local bare
function View.SetBare(test) bare = test end
local function Bare() return bare ~= nil and map ~= nil and bare(map) == true end
function View.Bare() return Bare() end

local function Marks(alpha)
	marksAlpha = alpha
	marks:SetAlpha(alpha)
	marks:SetShown(alpha > 0)
end

-- A focus: one thing on the map looked at alone (Rares.lua: a rare and every place it turns up). Everything else that
-- stands on the map fades out and the land takes a shade, deeper at the port's edges; the map stays the map it is (no
-- step into one inside it: Steps.lua). What is in focus stands on the lift (View.Lift), as you do, which no focus
-- fades. Faded out, the crowd is hidden: no addon lays its pins while the view moves (View.Clear: a move of the
-- view waits for it).
local function Crowd(alpha)
	focus.alpha = alpha
	focus.crowd:SetAlpha(alpha)
	focus.crowd:SetShown(alpha > 0)
	local veil = 1 - (alpha - FOCUS.CROWD) / (1 - FOCUS.CROWD)
	focus.veil:SetAlpha(veil)
	focus.veil:SetShown(veil > 0)
end

-- room: { left, top, right, bottom } in port units, the part of the port the map is held to meanwhile (beside what
-- stands over it); nil for the whole port.
function View.Focus(on, room)
	focus.on = on == true
	focus.room = focus.on and room or nil
end
function View.Focused() return focus.on end
function View.Clear() return focus.on and focus.alpha <= FOCUS.CROWD end

-- The overlay keeps you in sight whatever the setting: nothing can move it by hand.
local function Follows() return T.db.follow == true or laid.on end

-- The overlay takes no mouse: each frame on the port that would is kept from it (what it took is kept, to
-- give back as the port goes home). A protected frame is left alone in a fight.
local hushed = setmetatable({}, { __mode = "k" })   -- frame -> { click, motion, wheel } it had

local function Hush(frame, fight)
	local skip = false
	if fight then
		local protected = frame:IsProtected()
		skip = issecretvalue(protected) or protected
	end
	if not skip then
		local click, motion, wheel = frame:IsMouseClickEnabled(), frame:IsMouseMotionEnabled(), frame:IsMouseWheelEnabled()
		if click or motion or wheel then
			if not hushed[frame] then hushed[frame] = { click, motion, wheel } end
			if click then frame:SetMouseClickEnabled(false) end
			if motion then frame:SetMouseMotionEnabled(false) end
			if wheel then frame:EnableMouseWheel(false) end
		end
	end
	if frame:GetNumChildren() > 0 then
		for _, child in ipairs({ frame:GetChildren() }) do Hush(child, fight) end
	end
end

local function Quiet()
	if not laid.on then return end
	local from = debugprofilestop()
	local fight = InCombatLockdown()
	Hush(port, fight)
	-- (What stands on the map is off the port, on its own cover.)
	Hush(marks, fight)
	laid.hushIn = OVERLAY.HUSH
	Clock("overlay kept from the mouse", debugprofilestop() - from)
end

local function Unquiet()
	local fight = InCombatLockdown()
	for frame, was in pairs(hushed) do
		local protected = fight and frame:IsProtected()
		if not (fight and (issecretvalue(protected) or protected)) then
			frame:SetMouseClickEnabled(was[1])
			frame:SetMouseMotionEnabled(was[2])
			frame:EnableMouseWheel(was[3])
		end
	end
	wipe(hushed)
end

-- Where a centre may stand: the art is kept over the whole port; one smaller than the port stands in its
-- middle. Free, it may stray FREE_REACH of the map past any edge. You (`me`, your share on that axis)
-- may always stand in the middle, by the art's edge too.
local FREE_REACH, FREE_LEAST = 0.75, 0.6
local function Hold(c, span, axis, me)
	if Free() then return math.max(-FREE_REACH, math.min(1 + FREE_REACH, c)) end
	local pw, ph = Room()
	local size = axis == "x" and pw or ph
	-- (In a focus the map is held to the room it is given beside what is in focus, not to the whole port.)
	local a, b = 0, size
	local room = focus.on and focus.room
	if room then
		if axis == "x" then a, b = room.left, room.right else a, b = room.top, room.bottom end
	end
	local lo = 0.5 - ((a + b) / 2 - size / 2) / span
	local hi = lo
	if span > b - a then
		lo, hi = (size / 2 - a) / span, 1 - (b - size / 2) / span
	end
	if me then lo, hi = math.min(lo, me), math.max(hi, me) end
	return math.max(lo, math.min(hi, c))
end

-- floor(map): the least zoom on that map, times the whole map's size, or nil for the view's own rule (a
-- map with one round it to step out to has no floor of its own: Steps.lua steps out instead).
local floor, beyond, ceiling
function View.SetFloor(fn) floor = fn end
-- ceiling(map): the deepest zoom, times the whole map's size, when it must go deeper than its art does
-- (as far as the maps inside it take over), or nil.
function View.SetCeiling(fn) ceiling = fn end
-- beyond(): the wheel turned on out with the zoom already at the floor.
function View.SetBeyond(fn) beyond = fn end

local function Least()
	local share = floor and map and floor(map)
	local least = share and fit * share or Free() and fit * FREE_LEAST or fit
	-- (In a focus, as far out as the whole map fits the room it is given.)
	local room = focus.on and focus.room
	if room and w then least = math.min(least, (room.right - room.left) / w, (room.bottom - room.top) / h) end
	return least
end

local function Limits()
	local pw, ph = Room()
	fit = math.min(pw / w, ph / h)
	deep = fit * math.max(most or 1, DEEP_LEAST, ceiling and map and ceiling(map) or 0)
end

-- The zoom's limits asked again (a look that draws the ground closer goes deeper); a zoom past the new
-- deepest eases back to it.
function View.Relimit()
	if not (map and w) then return end
	Limits()
	if s > deep * 1.0001 then
		want.s, settled = deep, false
	end
end

local function Lay()
	local pw, ph = Room()
	local left, top = pw / 2 - cx * w * s, ph / 2 - cy * h * s
	canvas:SetScale(s)
	canvas:ClearAllPoints()
	canvas:SetPoint("TOPLEFT", port, "TOPLEFT", left / s, -top / s)
	-- (On the overlay what stands on the map is off the canvas, over it: the canvas's scale is its own to take.)
	if laid.on then marks:SetScale(s) end
end

local function CursorPort()
	local x, y = GetCursorPosition()
	local e = port:GetEffectiveScale()
	return x / e - port:GetLeft(), port:GetTop() - y / e
end

-- loose: past the art's edge too. Never on the overlay, which the mouse passes through.
function View.Cursor(loose)
	if laid.on or not (map and port:IsVisible()) then return nil end
	local px, py = CursorPort()
	local pw, ph = Room()
	local x, y = cx + (px - pw / 2) / (w * s), cy + (py - ph / 2) / (h * s)
	if not loose and (x < 0 or x > 1 or y < 0 or y > 1) then return nil end
	return x, y
end

function View.Center() return cx, cy end
function View.Anchored() return anchor ~= nil end

-- The art the port shows, in shares: left, right, top, bottom.
function View.Shown()
	local pw, ph = Room()
	local hx, hy = pw / (2 * w * s), ph / (2 * h * s)
	return cx - hx, cx + hx, cy - hy, cy + hy
end

function View.ToPort(x, y)
	local pw, ph = Room()
	return pw / 2 + (x - cx) * w * s, ph / 2 + (y - cy) * h * s
end

function View.InUse() return using end
function View.IsOpen() return using and open end
function View.Overlaid() return laid.on end
function View.Map() return map end
function View.Canvas() return focus.crowd end
function View.Lift() return focus.lift end
function View.Chrome() return chrome end
function View.Land() return canvas end
function View.Port() return port end
function View.Scale() return s end
function View.Fit() return fit end
function View.Deep() return deep end
function View.Size() return w, h end

function View.Zoom()
	if not map or deep <= fit then return 0 end
	return math.max(0, math.min(1, (s - fit) / (deep - fit)))
end

-- (Asked for every pin stood: worked out again only when the zoom or the map has changed.)
local grown = {}
function View.Grow()
	if grown.s ~= s or grown.map ~= map or grown.fit ~= fit or grown.deep ~= deep then
		grown.s, grown.map, grown.fit, grown.deep = s, map, fit, deep
		grown.value = 1 + GROW * View.Zoom()
	end
	return grown.value
end

function View.Level(name)
	return LEVEL + (LEVELS[name] or LEVELS.PIN_FRAME_LEVEL_ACTIVE_QUEST)
end

-- A frame View.Place stands is its alone: its one point and its scale are kept, and a step that changes
-- neither (the player standing still, a pan, which moves the canvas under it) sets nothing. Whatever
-- anchors such a frame otherwise lets go of it first with View.Unplace(frame).
local placed = setmetatable({}, { __mode = "k" })   -- frame -> { scale, x, y, canvas } it was given

function View.Place(frame, x, y, size)
	local scale = (size or 1) * View.Grow() / s
	local px, py = x * w / scale, -y * h / scale
	local at = placed[frame]
	if not at then
		at = {}
		placed[frame] = at
		frame:ClearAllPoints()
	end
	if at.scale ~= scale then
		at.scale = scale
		frame:SetScale(scale)
	end
	if at.x ~= px or at.y ~= py or at.canvas ~= canvas then
		at.x, at.y, at.canvas = px, py, canvas
		frame:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
	end
end

function View.Unplace(frame)
	placed[frame] = nil
end

-- A pin on the canvas: a button (or a plain frame with no `tip`) `size` units square at any zoom, with
-- an icon; `tip(pin)` writes its hover, `click(pin, button)` answers a click. Stood with View.Stand.
function View.Pin(level, size, tip, click)
	local pin = CreateFrame(tip and "Button" or "Frame", nil, focus.crowd)
	pin:SetSize(size, size)
	pin:SetFrameLevel(View.Level(level))
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	if tip then
		pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		pin:SetScript("OnEnter", function(self) tip(self) end)
		pin:SetScript("OnLeave", function(self) Shy.UI.TipHide(self) end)
		pin:SetScript("OnClick", function(self, button)
			if click then click(self, button) end
		end)
	else
		pin:EnableMouse(false)
	end
	pin:Hide()
	return pin
end

-- Stands a pin at x, y (shares of the art), or hides it for nil.
function View.Stand(pin, x, y)
	if not x then
		pin:Hide()
		return
	end
	pin.x, pin.y = x, y
	View.Place(pin, x, y, 1)
	pin:Show()
end

-- What lies past the edge of everything drawn: { r, g, b } (the terrain look's sea), or nil for the panel's dark.
function View.Ground(color)
	if not back then return end
	if color then
		back:SetColorTexture(color[1], color[2], color[3], 1)
	else
		local c = Shy.UI.colors.panel
		back:SetColorTexture(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1)
	end
end

function View.PlayerAt(on)
	if not on then return nil end
	local pos = C_Map.GetPlayerMapPosition(on, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return nil end
	return x, y
end

-- While the view moves on its own or under the hand (layers that look under the mouse wait).
function View.Busy()
	return drag ~= nil or not settled
end

-- The map's art: its size and its deepest zoom.
local function Art(id)
	local art = C_Map.GetMapArtLayers(id)
	local first = art and art[1]
	if not first then return nil end
	local deepest = 1
	for _, layer in ipairs(art) do deepest = math.max(deepest, layer.maxScale or 1) end
	return first.layerWidth, first.layerHeight, deepest
end

-- The rect of map `inner` on map `outer`, in shares of the outer one.
local function Rect(inner, outer)
	local x1, x2, y1, y2 = C_Map.GetMapRectOnMap(inner, outer)
	if not (x1 and x2 and y1 and y2) or x2 <= x1 or y2 <= y1 then return nil end
	return x1, x2, y1, y2
end

-- Memory

local function Save()
	if not (map and w and T.db.remember) or travel or flight then return end
	local v = T.db.views[map]
	if v then
		v.zoom, v.x, v.y = s / fit, cx, cy
	else
		T.db.views[map] = { zoom = s / fit, x = cx, y = cy }
	end
end

-- Following: the view keeps you in the middle as you move (T.db.follow). Moved by hand (a drag, a zoom
-- under the mouse, a flight, a glide to a place), it is astray: it stays where it was put until you walk
-- out of sight (into the port's edge band or past it, FOLLOW_WALK of the port from where you stood when
-- it was moved), then comes back to you. The controls offer to keep it there meanwhile (Controls.lua).
local function Stray()
	astray, chasing, stood = true, false, nil
	if meX then stood = { map = map, x = meX, y = meY } end
end

function View.Astray() return astray end
function View.Following() return Follows() and not astray end

-- You are on the map shown and inside the port.
function View.SeesYou()
	if not (map and meX) then return false end
	local px, py = View.ToPort(meX, meY)
	local pw, ph = Room()
	return px >= 0 and px <= pw and py >= 0 and py <= ph
end

local function HoldWant()
	local pw, ph = Room()
	want.s = math.max(Least(), math.min(deep, want.s))
	if want.x then
		meX, meY = View.PlayerAt(map)
		want.x = Hold(want.x, w * want.s, "x", meX)
		want.y = Hold(want.y, h * want.s, "y", meY)
	end
end

-- Looking ahead: the view that follows you keeps you back from its middle and shows more of what lies ahead.
--
-- Led somewhere (Shy.Maps.Led: the trail to your next step, a flight, a boat): round you lies an ellipse half
-- the port each way, and the middle stands half way from you to where the way leaves it, so you stand a
-- quarter of the port in from one side at the most and the way runs on to a quarter in from the other. Round
-- a bend the middle stands inside the bend; once the place itself is inside the ellipse the middle is half
-- way between the two of you, both in sight, and comes to you as you arrive.
--
-- Headed somewhere of your own (nobody leading, or off across or against the way): the middle stands ahead of
-- you the way you are going, less far (TRAVEL of the reach), the more the faster you go, up to a run. How you
-- go is your place from look to look, smoothed over a second: a turn swings the view round, a fight's to and
-- fro comes to nothing, and standing still brings the middle back to you, or to the way you are led. Along
-- the way, the way has it; the further your heading turns from it (ALONG), the more your heading has.
--
-- The offset is kept in port units, whatever the zoom, and eased. While it stands ahead of you the map shown
-- goes by where you are, not by the middle (View.Leaning, Steps.lua).
-- Smart following (T.db.followSmart) looks no further than LOOK yards along the way, or ahead the way you go: zoomed
-- in, the next stretch of the way is in sight; zoomed out, you stand near the middle, not at the edge of a view the
-- whole way to a far place would pull you to. Following you plainly, you stand in the very middle.
local lean = {
	LOOK = 150,         -- yards a smart following looks ahead, at the most
	REACH = 0.25,       -- share of the port's width and height you may stand from its middle
	TRAVEL = 0.6,       -- how far it looks ahead headed your own way, as a share of the reach
	PACE = 7,           -- yards a second: a run, from which it looks its whole way ahead
	SLOW = 0.3,         -- yards a second under which you are standing still
	LEAP = 100,         -- yards a second nobody goes: carried off (a hearth, a summons), not headed anywhere
	SMOOTH = 1,         -- seconds how you go is smoothed over
	ALONG = 0.5,        -- the cosine between your heading and the way from which the way has it all (60 degrees)
	SPEED = 3,          -- how fast the offset eases to where it is going (most of the way in a second)
	EVERY = 0.15,       -- seconds between looks at where you are and along the way
	STALE = 0.5,        -- seconds unasked after which it starts where it is going (reopened, back from being moved by hand)
	POINTS = 400,       -- points of a way looked along at the most
	x = 0, y = 0,       -- the offset now, from you to the port's middle (port units)
	tx = 0, ty = 0,     -- ... and where it is going
	looked = 0,         -- when it last looked
	eased = 0,          -- when the offset was last eased
	vn = 0, vw = 0,     -- how you go: yards a second north and west, smoothed
	paced = 0,          -- when that was last worked out, and from where (world, north, west)
}

-- How you go, from where you were at the last look to where you are now. Nothing known of the last while
-- (the map was closed, the view moved by hand): as the game says you move, the way you face, until the next
-- looks say better.
function lean.Pace(world, north, west)
	local now = GetTime()
	local dt = now - lean.paced
	if dt <= 0 and lean.world == world then return end
	if lean.world ~= world or dt > lean.STALE then
		lean.vn, lean.vw = 0, 0
		local speed, facing = GetUnitSpeed("player"), GetPlayerFacing()
		if speed and facing and not issecretvalue(speed) and not issecretvalue(facing) and speed > lean.SLOW then
			lean.vn, lean.vw = math.cos(facing) * speed, math.sin(facing) * speed
		end
	else
		local vn, vw = (north - lean.north) / dt, (west - lean.west) / dt
		if vn * vn + vw * vw > lean.LEAP * lean.LEAP then
			vn, vw = 0, 0
		else
			local k = 1 - math.exp(-dt / lean.SMOOTH)
			vn, vw = lean.vn + (vn - lean.vn) * k, lean.vw + (vw - lean.vw) * k
			if vn * vn + vw * vw < lean.SLOW * lean.SLOW then vn, vw = 0, 0 end
		end
		lean.vn, lean.vw = vn, vw
	end
	lean.world, lean.north, lean.west, lean.paced = world, north, west, now
end

-- Where the middle should stand from you at the zoom `scale`, in port units: half way to where the way you
-- are led along leaves the ellipse round you, or ahead of you the way you are going. 0, 0 standing still led
-- nowhere, or where the map shown is no straight piece of the world you are in.
function lean.Aim(scale)
	local world, hereNorth, hereWest = Shy.Here()
	if not hereNorth or not ns.OnMap(map, world, hereNorth, hereWest) then
		lean.world = nil
		return 0, 0
	end
	-- (Following you plainly: you in the very middle.)
	if not T.db.followSmart then return 0, 0 end
	lean.Pace(world, hereNorth, hereWest)
	local _, n0, w0, n1, w1 = View.World(map)
	local pw, ph = Room()
	-- (A yard west and a yard north, in the ellipse's own terms: 1 at its rim.)
	local kx, ky = w * scale / (w1 - w0) / (pw * lean.REACH * 2), h * scale / (n1 - n0) / (ph * lean.REACH * 2)
	-- Led: from you through each point of the way ahead, then to the place itself; the first stretch that
	-- leaves the ellipse is cut at its rim.
	local u, v = 0, 0
	local continent, north, west, line, first, last = Shy.Maps.Led()
	if continent == world then
		local way, at
		if not line then way, at = Shy.Way.Trailed(continent, north, west, hereNorth, hereWest) end
		local from, to = 1, 0
		if line then
			from, to = first or 1, last or line.n
		elseif way then
			from, to = at, way.n
		end
		to = math.min(to, from + lean.POINTS)
		-- (No further along the way than LOOK yards: the point that far along stands for the rest.)
		local walked, lastN, lastW = 0, hereNorth, hereWest
		for i = from, to + 1 do
			local pn, pwest = north, west
			if i <= to then
				if line then pn, pwest = line.north[i], line.west[i] else pn, pwest = way[i * 3 - 2], way[i * 3 - 1] end
			end
			local stretch = math.sqrt((pn - lastN) ^ 2 + (pwest - lastW) ^ 2)
			local capped = walked + stretch > lean.LOOK
			if capped then
				local share = stretch > 0 and (lean.LOOK - walked) / stretch or 0
				pn, pwest = lastN + (pn - lastN) * share, lastW + (pwest - lastW) * share
			end
			walked, lastN, lastW = walked + stretch, pn, pwest
			local nu, nv = (pwest - hereWest) * kx, (pn - hereNorth) * ky
			if nu * nu + nv * nv >= 1 then
				local du, dv = nu - u, nv - v
				local a, b, c = du * du + dv * dv, u * du + v * dv, u * u + v * v - 1
				local t = a > 0 and (-b + math.sqrt(math.max(0, b * b - a * c))) / a or 1
				u, v = u + du * t, v + dv * t
				break
			end
			u, v = nu, nv
			if capped then break end
		end
	end
	-- Headed your own way: TRAVEL of the reach the way you go. It has the middle as far as you go fast and
	-- the way doesn't run that way too.
	local hu, hv = lean.vw * kx, lean.vn * ky
	local long = math.sqrt(hu * hu + hv * hv)
	local speed = math.sqrt(lean.vn * lean.vn + lean.vw * lean.vw)
	local share = math.min(1, speed / lean.PACE)
	if long > 0 and share > 0 then
		-- (No further than LOOK yards the way you go: that far, in the ellipse's own terms.)
		local look = lean.LOOK * long / speed
		local travel = math.min(lean.TRAVEL, look)
		hu, hv = hu / long * travel, hv / long * travel
		local led = math.sqrt(u * u + v * v)
		if led > 0 then
			local along = (u * hu + v * hv) / (led * travel)
			share = share * (1 - math.max(0, math.min(1, along / lean.ALONG)))
		end
		u, v = u + (hu - u) * share, v + (hv - v) * share
	end
	return u * pw * lean.REACH, v * ph * lean.REACH
end

View.LEAN = lean   -- (its numbers, for whoever measures them: LOOK)

-- The offset this frame, in shares of the map: eased toward where it is going, which is looked at every
-- EVERY seconds. Unasked for a while (the map closed, the view moved by hand), it starts there.
function lean.Now()
	-- (The overlay lies over the world you stand in the middle of: you in its very middle, always.)
	if laid.on then
		lean.x, lean.y, lean.tx, lean.ty = 0, 0, 0, 0
		return 0, 0
	end
	local now = GetTime()
	local dt = now - lean.eased
	lean.eased = now
	if now - lean.looked >= lean.EVERY then
		lean.looked = now
		lean.tx, lean.ty = lean.Aim(s)
	end
	if lean.soft then
		-- (From the very middle, gently: View.Seek.)
		lean.soft, lean.x, lean.y = nil, 0, 0
	elseif dt > lean.STALE then
		lean.x, lean.y = lean.tx, lean.ty
	elseif dt > 0 then
		local k = math.exp(-dt * lean.SPEED)
		lean.x, lean.y = lean.tx + (lean.x - lean.tx) * k, lean.ty + (lean.y - lean.ty) * k
		if math.abs(lean.x - lean.tx) < 0.25 and math.abs(lean.y - lean.ty) < 0.25 then lean.x, lean.y = lean.tx, lean.ty end
	end
	return lean.x / (w * s), lean.y / (h * s)
end

-- The offset at once, in shares of the map: a view that starts on you starts looking ahead, and nothing
-- drifts after it opens.
function lean.Start()
	local now = GetTime()
	lean.tx, lean.ty = lean.Aim(s)
	lean.x, lean.y, lean.looked, lean.eased, lean.soft = lean.tx, lean.ty, now, now, nil
	return lean.x / (w * s), lean.y / (h * s)
end

-- The view stands ahead of you: its middle is not where you are. (The map shown goes by you meanwhile, not
-- by the middle: Steps.lua.)
function View.Leaning()
	return (lean.x ~= 0 or lean.y ~= 0) and Follows() and not astray
end

-- Showing a map

function View.Show(id, how)
	if not (using and id) then return false end
	local nw, nh, nmost = Art(id)
	if not nw then return false end
	local was, ws, wx, wy, ww = map, s, cx, cy, w
	if was and open then Save() end
	map, w, h, most = id, nw, nh, nmost
	View.rebased = false
	canvas:SetSize(w, h)
	Limits()

	flight, seek = nil, 0
	-- (Shown anew, it looks ahead of nobody until it starts on you, below, or follows you again.)
	lean.x, lean.y, lean.tx, lean.ty = 0, 0, 0, 0

	-- Where it goes: a step into or out of a map shows all of it.
	local saved = T.db.remember and T.db.views[map]
	local zoom, x, y = 1, 0.5, 0.5
	if how ~= "out" and how ~= "whole" and how ~= "into" and saved then zoom, x, y = saved.zoom or 1, saved.x or 0.5, saved.y or 0.5 end
	local onYou = false
	if how == "here" then
		-- (Shown whole, a drawn map has no room to centre on you; the terrain's ground goes on, so it has.)
		local px, py = View.PlayerAt(map)
		if px and (zoom > 1.01 or Free()) then x, y, onYou = px, py, true end
	end
	want.s, want.x, want.y = zoom * fit, x, y
	HoldWant()

	-- Where it starts: the new art over where it lies on the old one.
	local carried = false
	if was and was ~= map and ws and (how == "into" or how == "out") then
		if how == "into" then
			local x1, x2, y1, y2 = Rect(map, was)
			if x1 then
				s = ws * (x2 - x1) * ww / w
				cx, cy = (wx - x1) / (x2 - x1), (wy - y1) / (y2 - y1)
				carried = true
			end
		else
			local x1, x2, y1, y2 = Rect(was, map)
			if x1 then
				s = ws * ww / ((x2 - x1) * w)
				cx, cy = x1 + wx * (x2 - x1), y1 + wy * (y2 - y1)
				carried = true
			end
		end
	end
	anchor, drag, vx, vy, chasing = nil, nil, 0, 0, false
	if carried then
		travel = true
	else
		travel = false
		s, cx, cy = want.s, want.x, want.y
		want.x, want.y = nil, nil
		-- (On you, and following you: looking ahead from the first frame.)
		if onYou and meX and Follows() and not laid.on and not Bare() then
			local pw, ph = Room()
			local ox, oy = lean.Start()
			cx, cy = Hold(meX + ox, w * s, "x"), Hold(meY + oy, h * s, "y")
		end
	end
	settled = false
	fading, shownAt = true, GetTime()
	canvas:SetAlpha(carried and 0.4 or 0)
	Marks(Bare() and 0 or 1)
	Lay()
	-- (A map is laid at its zoom: no word of the zoom after it. Opening, the opening tells it.)
	if open then Tell("map") end
	return true
end

-- Where a map lies in its world: the world, and the north and west (yards) of its top left and bottom
-- right corners. nil for a map that lies in none.
local worlds = {}
function View.World(id)
	local known = worlds[id]
	if known == nil then
		local world, top = C_Map.GetWorldPosFromMapPos(id, CreateVector2D(0, 0))
		local _, bottom = C_Map.GetWorldPosFromMapPos(id, CreateVector2D(1, 1))
		known = false
		if world and top and bottom then
			local n0, w0 = top:GetXY()
			local n1, w1 = bottom:GetXY()
			if n0 ~= n1 and w0 ~= w1 then known = { world, n0, w0, n1, w1 } end
		end
		worlds[id] = known
	end
	if not known then return nil end
	return known[1], known[2], known[3], known[4], known[5]
end

-- The world's map lays a piece of each world on its art, scaled alike: read from points of it, a world
-- runs straight across it. { north, west at its top left, at its bottom right, box = { x1, x2, y1, y2 }
-- (shares: where that world's points lie on it) }, or nil.
local SAMPLES = 12
local function Sampled(id, world)
	local lo, hi, box
	for i = 1, SAMPLES do
		for j = 1, SAMPLES do
			local x, y = (i - 0.5) / SAMPLES, (j - 0.5) / SAMPLES
			local there, at = C_Map.GetWorldPosFromMapPos(id, CreateVector2D(x, y))
			if there == world and at then
				local north, west = at:GetXY()
				if not lo or x + y < lo[1] + lo[2] then lo = { x, y, north, west } end
				if not hi or x + y > hi[1] + hi[2] then hi = { x, y, north, west } end
				if box then
					box[1], box[2] = math.min(box[1], x), math.max(box[2], x)
					box[3], box[4] = math.min(box[3], y), math.max(box[4], y)
				else
					box = { x, x, y, y }
				end
			end
		end
	end
	if not (lo and hi and hi[1] > lo[1] and hi[2] > lo[2]) then return nil end
	local kw, kn = (hi[4] - lo[4]) / (hi[1] - lo[1]), (hi[3] - lo[3]) / (hi[2] - lo[2])
	if kw == 0 or kn == 0 then return nil end
	local n0, w0 = lo[3] - lo[2] * kn, lo[4] - lo[1] * kw
	return { n0, w0, n0 + kn, w0 + kw, box = box }
end

-- The world's map round a map (the top of its parents).
local function Top(id)
	local info, guard = C_Map.GetMapInfo(id), 0
	while info and info.mapType > Enum.UIMapType.World and guard < 8 do
		info = info.parentMapID and info.parentMapID > 0 and C_Map.GetMapInfo(info.parentMapID) or nil
		guard = guard + 1
	end
	return info and info.mapType == Enum.UIMapType.World and info.mapID or nil
end

-- Where map `id` lies in `world`, in its yards: a map of that world says so itself; the world's map is
-- read from its points in that world; a map of another world lies where the world's map round both lays
-- it beside this one. nil where it can't be told.
local corners = {}
local function Corners(id, world)
	if not (id and world) then return nil end
	local key = id .. ":" .. world
	local known = corners[key]
	if known == nil then
		known = false
		local info = C_Map.GetMapInfo(id)
		local own, n0, w0, n1, w1 = View.World(id)
		if info and info.mapType == Enum.UIMapType.World then
			known = Sampled(id, world) or false
		elseif own == world then
			known = { n0, w0, n1, w1 }
		elseif own then
			local top = Top(id)
			local a, b = top and Corners(top, own), top and Corners(top, world)
			if a and b then
				local function Carry(north, west)
					local x, y = (west - a[2]) / (a[4] - a[2]), (north - a[1]) / (a[3] - a[1])
					return b[1] + y * (b[3] - b[1]), b[2] + x * (b[4] - b[2])
				end
				local N0, W0 = Carry(n0, w0)
				local N1, W1 = Carry(n1, w1)
				known = { N0, W0, N1, W1 }
			end
		end
		corners[key] = known
	end
	return known or nil
end

function View.Corners(id, world)
	local known = Corners(id, world)
	if not known then return nil end
	return known[1], known[2], known[3], known[4]
end

function View.Region(id, world)
	local known = Corners(id, world)
	local box = known and known.box
	if not box then return nil end
	return box[1], box[2], box[3], box[4]
end

-- Turns the view to another map without moving anything on screen: the point in the middle and the
-- yards a unit of the port spans stay as they are. Within a world (the terrain look, crossing a zone's
-- edge), or between the world's map and a map on it (where the world's map lays that map's world).
function View.Rebase(id)
	if not (map and id and id ~= map) then return false end
	local world = View.World(map) or View.World(id)
	local n0, w0, n1, w1 = View.Corners(map, world)
	local N0, W0, N1, W1 = View.Corners(id, world)
	local nw, nh, nmost = Art(id)
	if not (n0 and N0 and nw) then return false end
	local function Carry(x, y)
		local north, west = n0 + y * (n1 - n0), w0 + x * (w1 - w0)
		return (west - W0) / (W1 - W0), (north - N0) / (N1 - N0)
	end
	Save()
	cx, cy = Carry(cx, cy)
	if drag then drag.cx, drag.cy = Carry(drag.cx, drag.cy) end
	if want.x then want.x, want.y = Carry(want.x, want.y) end
	-- A glide in shares of the old map, in shares of the new one.
	vx, vy = vx * (w0 - w1) / (W0 - W1), vy * (n0 - n1) / (N0 - N1)
	s = s * w / (w0 - w1) * (W0 - W1) / nw
	if want.s then want.s = want.s * w / (w0 - w1) * (W0 - W1) / nw end
	-- A zoom under way goes on about the same point (stepping in or out a level with the wheel).
	if anchor then anchor.x, anchor.y = Carry(anchor.x, anchor.y) end
	View.rebased, View.was = true, map    -- (what was shown: its art fades out as the new one comes in)
	map, w, h, most = id, nw, nh, nmost
	canvas:SetSize(w, h)
	Limits()
	Lay()
	Tell("map")
	return true
end

-- Lays `frame` over the port as map `id`'s art (its size), where that map lies under the view: another map
-- of the same world (the continent under a zone, the zone the view just left). False where it can't.
function View.LaySheet(frame, id)
	if not map then return false end
	local world, n0, w0, n1, w1 = View.World(map)
	local world2, N0, W0, N1, W1 = View.World(id)
	local aw, ah = Art(id)
	if not (world and world == world2 and aw) then return false end
	local k = s * (w / (w0 - w1)) * ((W0 - W1) / aw)    -- port units a pixel of its art
	local px, py = View.ToPort((W0 - w0) / (w1 - w0), (N0 - n0) / (n1 - n0))
	frame:SetSize(aw, ah)
	frame:SetScale(k)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", port, "TOPLEFT", px / k, -py / k)
	return true
end

function View.Open(id)
	if using and open then
		View.Show(id)
	else
		pending = id
	end
end

-- Moves the view to an art point and zoom (times the whole map's size), easing there. Sent somewhere,
-- the view is astray: it stays there (see Stray).
function View.Glide(x, y, zoom)
	if not map then return end
	travel, anchor, vx, vy, flight, seek = false, nil, 0, 0, nil, 0
	want.s = zoom and zoom * fit or want.s or s
	want.x, want.y = x, y
	HoldWant()
	settled = false
	Stray()
end

-- Glides to take in `points` (x, y, x, y ... shares of the map shown) whole, a tenth of the port clear round them, no
-- less than FRAME.least of the map each way and no closer than FRAME.most times its whole size.
local FRAME = { least = 0.2, most = 4, edge = 0.1 }
function View.Frame(points)
	local pw, ph = port and port:GetWidth() or 0, port and port:GetHeight() or 0
	if not (map and w and fit and pw > 0 and ph > 0 and #points >= 2) then return false end
	local x1, x2, y1, y2 = math.huge, -math.huge, math.huge, -math.huge
	for i = 1, #points - 1, 2 do
		x1, x2 = math.min(x1, points[i]), math.max(x2, points[i])
		y1, y2 = math.min(y1, points[i + 1]), math.max(y2, points[i + 1])
	end
	if x2 - x1 < FRAME.least then x1, x2 = (x1 + x2 - FRAME.least) / 2, (x1 + x2 + FRAME.least) / 2 end
	if y2 - y1 < FRAME.least then y1, y2 = (y1 + y2 - FRAME.least) / 2, (y1 + y2 + FRAME.least) / 2 end
	local k = math.min(pw * (1 - 2 * FRAME.edge) / ((x2 - x1) * w), ph * (1 - 2 * FRAME.edge) / ((y2 - y1) * h))
	k = math.max(fit, math.min(fit * FRAME.most, deep or fit * FRAME.most, k))
	View.Glide((x1 + x2) / 2, (y1 + y2) / 2, k / fit)
	return true
end

-- Glides to you at `zoom`, aiming at where you are each frame until you stand in the middle (you may
-- move, and the map may turn to your zone on the way in). False when you aren't on the map shown.
function View.Seek(zoom)
	local x, y = View.PlayerAt(map)
	if not x then return false end
	View.Glide(x, y, zoom)
	seek = GetTime() + SEEK
	astray, stood = false, nil
	-- (You in the very middle first; from there the view looks ahead again, gently.)
	lean.soft = true
	return true
end

-- A flight: the view carried to map `id` shown whole in one move. The zoom runs evenly (in times, not in
-- size) while the map's middle slides straight to the port's middle. Within one world it is flown in
-- yards, so the map shown may change under it (Steps.lua turns it as the zoom passes each map's whole
-- size); onto a map of another world it is flown over where that map lies on the one shown. done() once
-- there. Nothing else moves the view meanwhile; a touch of the mouse ends it.
local FLY_LEAST, FLY_MOST, FLY_PER = 0.2, 0.42, 0.035  -- seconds: at least, at most, and per doubling of the zoom

-- The flight's goal as a point of the map shown (shares), and art scale per unit of the flight's zoom.
local function Aim(f)
	if f.world then
		local n0, w0, n1, w1 = View.Corners(map, f.world)
		if not n0 then return nil end
		return (f.west - w0) / (w1 - w0), (f.north - n0) / (n1 - n0), (w0 - w1) / w
	end
	if map ~= f.on then return nil end
	return f.x, f.y, 1
end

function View.Fly(id, done)
	if not (using and open and map and id and w) then return false end
	local aw, ah = Art(id)
	if not aw then return false end
	local pw, ph = Room()
	local f = { id = id, done = done, t = 0 }
	local world, n0, w0, n1, w1 = View.World(id)
	local here = View.World(map)
	if id == map then
		-- (The whole of the map shown.)
		f.on, f.x, f.y, f.k1 = map, 0.5, 0.5, fit
	elseif world and (world == here or not here) and View.Corners(map, world) then
		-- (Within its world, or down from the world's map, which lays that world straight across it.)
		-- (k: port units a yard.)
		f.world, f.north, f.west = world, (n0 + n1) / 2, (w0 + w1) / 2
		f.k1 = math.min(pw / aw, ph / ah) * aw / (w0 - w1)
	else
		local x1, x2, y1, y2 = Rect(id, map)
		if not x1 then return false end
		-- (k: the scale of the map shown.)
		f.on, f.x, f.y = map, (x1 + x2) / 2, (y1 + y2) / 2
		f.k1 = math.min(pw / ((x2 - x1) * w), ph / ((y2 - y1) * h))
	end
	local x, y, u = Aim(f)
	f.k0 = s / u
	f.ox, f.oy = (x - cx) * w * s, (y - cy) * h * s
	f.time = math.max(FLY_LEAST, math.min(FLY_MOST, FLY_LEAST + FLY_PER * math.abs(math.log(f.k1 / f.k0) / math.log(2))))
	if open then Save() end
	anchor, drag, vx, vy, travel, seek = nil, nil, 0, 0, false, 0
	want.s, want.x, want.y = nil, nil, nil
	settled = false
	flight = f
	Stray()
	return true
end

-- The map a flight is going to, or nil.
function View.Flying() return flight and flight.id or nil end

-- A step of the flight; the flight, once it has arrived.
local function FlyStep(dt)
	local f = flight
	local x, y, u = Aim(f)
	if not x then
		flight = nil
		return nil
	end
	f.t = math.min(1, f.t + dt / f.time)
	-- (Under way from the first frame, settling gently.)
	local e = 1 - (1 - f.t) ^ 3
	local r = f.k1 / f.k0
	local k = f.k0 * r ^ e
	-- Where the goal's middle stands from the port's middle. A pure zoom about the one point that stands
	-- still on screen from the start to the end, so the view zooms from where it is and never swings
	-- aside; between maps of about one size (no such point near), it slides straight.
	local px, py
	if math.abs(r - 1) < 0.15 then
		px, py = (1 - e) * f.ox, (1 - e) * f.oy
	else
		local fx, fy = -f.ox * r / (1 - r), -f.oy * r / (1 - r)
		px, py = fx + (f.ox - fx) * k / f.k0, fy + (f.oy - fy) * k / f.k0
	end
	s = k * u
	cx = x - px / (w * s)
	cy = y - py / (h * s)
	want.s = s
	if f.t < 1 then return nil end
	flight = nil
	return f
end

-- The view is on its way somewhere of its own (a flight, a step into or out of a map): what the middle
-- lies over is not where the player went.
function View.Moving() return flight ~= nil or travel end

-- Zooms out of the map, as wanted: the zoom is going down.
function View.Outward()
	if flight then return flight.k1 < flight.k0 end
	return want.s ~= nil and want.s < s * 0.999
end

-- Zooms by `factor`, the art point under the mouse staying under it. While the view follows you, the
-- zoom turns about you instead, so you stay in the middle and the view isn't moved by hand.
function View.ZoomAt(factor)
	if not map then return end
	flight = nil
	local goal = math.max(Least(), math.min(deep, (want.s or s) * factor))
	if math.abs(goal - (want.s or s)) < 1e-6 then
		if factor < 1 and beyond then beyond() end
		return
	end
	local following = View.Following() and meX ~= nil and not Bare()
	local px, py
	if following then px, py = View.ToPort(meX, meY) else px, py = CursorPort() end
	local pw, ph = Room()
	travel, vx, vy, seek, chasing = false, 0, 0, 0, false
	anchor = { x = cx + (px - pw / 2) / (w * s), y = cy + (py - ph / 2) / (h * s), ox = px - pw / 2, oy = py - ph / 2 }
	want.s, want.x, want.y = goal, nil, nil
	touched = GetTime()
	if not following then Stray() end
	settled = false
end

-- Coming in

local LOAD_MOST = 4         -- seconds the spinner waits at most for the map's pictures
local SPIN_AFTER = 0.15     -- seconds of loading before the spinner shows (a quick opening shows none)
local SPIN_FADE = 0.2       -- seconds the spinner takes to come and go
local SPIN = 22             -- the spinner, units on screen
local status, statusAlpha = nil, 0

-- One step of the opening a frame: the next layer still to come in, then what watches the view, then
-- the wait for the map's pictures.
local function Load()
	local step = loading.step
	while layers[step] and not layers[step].later do step = step + 1 end
	if layers[step] then
		loading.step = step + 1
		TellLayer(layers[step], "map")
		TellLayer(layers[step], "open")
		return
	end
	loading.step = step
	if not loading.told then
		loading.told = true
		TellWatchers("open")
		laid.hushIn = 0
		return
	end
	if (ns.Art == nil or ns.Art.Loaded()) or GetTime() - loading.at > LOAD_MOST then
		Clock("opening, until all came in", (GetTime() - loading.at) * 1000)
		loading = nil
	end
end

local function Spin(dt)
	local want = loading and GetTime() - loading.at >= SPIN_AFTER and 1 or 0
	if statusAlpha == want then return end
	statusAlpha = want > statusAlpha and math.min(1, statusAlpha + dt / SPIN_FADE) or math.max(0, statusAlpha - dt / SPIN_FADE)
	status:SetAlpha(statusAlpha)
	status:SetShown(statusAlpha > 0)
end

-- Each frame

-- Each frame the view is at rest or following: aims the view at you, or, led somewhere, a little ahead of
-- you along the way (lean). Astray, it waits until you walk out of sight (see Stray). On a drawn map shown
-- whole there is nowhere to go: the art stays in the middle.
local function Follow()
	if not Follows() or Bare() or drag or flight or anchor or travel or vx ~= 0 or vy ~= 0 then return end
	if want.x and not chasing then return end
	if not meX then return end
	local pw, ph = Room()
	if astray then
		if not stood or stood.map ~= map then
			stood = { map = map, x = meX, y = meY }
			return
		end
		local px, py = View.ToPort(meX, meY)
		local mx, my = pw * FOLLOW_EDGE, ph * FOLLOW_EDGE
		if px >= mx and px <= pw - mx and py >= my and py <= ph - my then return end
		local dx, dy = (meX - stood.x) * w * s, (meY - stood.y) * h * s
		local walk = math.min(pw, ph) * FOLLOW_WALK
		-- (Zoomed far out, a quarter of the view is a long way: a short walk in yards does instead.)
		local _, _, w0, _, w1 = View.World(map)
		if w0 and w1 and w0 ~= w1 then walk = math.min(walk, FOLLOW_YARDS * w * s / math.abs(w0 - w1)) end
		if dx * dx + dy * dy < walk * walk then return end
		astray, stood = false, nil
	end
	if s < fit * 1.05 and not Free() then return end
	-- (Led somewhere, the middle stands ahead of you along the way: lean.)
	local ox, oy = lean.Now()
	local hx, hy = Hold(meX + ox, w * s, "x"), Hold(meY + oy, h * s, "y")
	if math.abs(hx - cx) * w * s < 0.5 and math.abs(hy - cy) * h * s < 0.5 then return end
	want.x, want.y, chasing, settled = hx, hy, true, false
end

-- How solid the overlay is: its day opacity by day, its night one by night, the one easing into the other
-- through dawn and dusk (the game's clock). The dark world makes a pale map stand out, so night is fainter.
local function Daylight()
	local hour, minute = GetGameTime()
	local t, dawn, dusk = hour + minute / 60, OVERLAY.DAWN, OVERLAY.DUSK
	if t < dawn[1] or t >= dusk[2] then return 0 end
	if t < dawn[2] then return (t - dawn[1]) / (dawn[2] - dawn[1]) end
	if t < dusk[1] then return 1 end
	return 1 - (t - dusk[1]) / (dusk[2] - dusk[1])
end

-- The map's ground at its opacity for the hour, and what stands on it (you, the trail, the pins) at its own:
-- far more solid, so it reads on a map the world shows through; a little fainter by night, never fainter
-- than the ground.
local function Fade()
	local night, day, light = T.db.overlayNight, T.db.overlayOpacity, Daylight()
	local ground = night + (day - night) * light
	cover:SetAlpha(ground)
	laid.over:SetAlpha(math.max(ground, T.db.overlayMarks * (OVERLAY.MARKS_NIGHT + (1 - OVERLAY.MARKS_NIGHT) * light)))
end

-- Each frame on the overlay: new frames kept from the mouse now and then, and each second its opacity for
-- the hour and, walked off the map shown, a turn to the map you are on. True when it turned (the frame is
-- the new map's).
local function OverlayStep(dt)
	laid.hushIn = laid.hushIn - dt
	if laid.hushIn <= 0 then Quiet() end
	laid.zoneIn = laid.zoneIn - dt
	if laid.zoneIn > 0 then return false end
	laid.zoneIn = OVERLAY.ZONE_LOOK
	Fade()
	local zone = not meX and not flight and MapUtil.GetDisplayableMapForPlayer()
	return zone ~= nil and zone ~= false and zone ~= map and View.Show(zone, "here")
end

local Step
local function Tick(self, dt)
	roomW, roomH = math.max(port:GetWidth(), 1), math.max(port:GetHeight(), 1)
	local ok, err = pcall(Step, self, dt)
	roomW, roomH = nil, nil
	if not ok then geterrorhandler()(err) end
end

function Step(_, dt)
	if not (using and open and map) then return end
	-- The whole game's frame, ours and everything else's: an opening's hitch next to a frame at rest.
	-- (The first frame's length is the one before the opening.)
	if sinceOpen then
		sinceOpen = sinceOpen + 1
		if sinceOpen > 1 then Clock(("whole frame %d after opening"):format(sinceOpen - 1), dt * 1000) end
		if sinceOpen > OPEN_FRAMES then sinceOpen = nil end
	else
		Clock("whole frame, open", dt * 1000)
	end
	local pw, ph = Room()
	local moved, scaled = false, false
	local landed
	meX, meY = View.PlayerAt(map)

	if laid.on and OverlayStep(dt) then return end

	if drag then
		local px, py = CursorPort()
		local dx, dy = px - drag.px, py - drag.py
		if not drag.moved and dx * dx + dy * dy > CLICK then
			drag.moved = true
			touched = GetTime()
			Stray()
		end
		if drag.moved then
			local nx = Hold(drag.cx - dx / (w * s), w * s, "x", meX)
			local ny = Hold(drag.cy - dy / (h * s), h * s, "y", meY)
			if dt > 0 then
				vx = vx * 0.5 + (nx - cx) / dt * 0.5
				vy = vy * 0.5 + (ny - cy) / dt * 0.5
			end
			cx, cy, moved = nx, ny, true
			touched = GetTime()
		end
	elseif flight then
		landed = FlyStep(dt)
		moved, scaled = true, true
	elseif vx ~= 0 or vy ~= 0 then
		cx, cy = cx + vx * dt, cy + vy * dt
		local k = math.exp(-dt * GLIDE)
		vx, vy = vx * k, vy * k
		if math.abs(vx) + math.abs(vy) < 0.002 then vx, vy = 0, 0 end
		moved = true
	end

	if want.s and s ~= want.s then
		if math.abs(s - want.s) < want.s * 0.0005 then s = want.s else s = Ease(s, want.s, dt, ZOOM_SPEED) end
		scaled = true
	end
	if anchor then
		cx = anchor.x - anchor.ox / (w * s)
		cy = anchor.y - anchor.oy / (h * s)
		moved = true
		if not scaled then anchor = nil end
	elseif want.x and not drag then
		-- Seeking you: where you are now, on the map shown now.
		if meX and GetTime() < seek then want.x, want.y = meX, meY end
		cx, cy = Ease(cx, want.x, dt, PAN_SPEED), Ease(cy, want.y, dt, PAN_SPEED)
		if math.abs(cx - want.x) * w * s < 0.3 and math.abs(cy - want.y) * h * s < 0.3 then
			cx, cy, want.x, want.y, seek, chasing = want.x, want.y, nil, nil, 0, false
		end
		moved = true
	end
	if travel and not scaled and not want.x then travel = false end
	if not (travel or flight) then
		local hx, hy = Hold(cx, w * s, "x", meX), Hold(cy, h * s, "y", meY)
		if hx ~= cx or hy ~= cy then
			if hx ~= cx then vx = 0 end
			if hy ~= cy then vy = 0 end
			cx, cy, moved = hx, hy, true
		end
	end
	if moved or scaled then Lay() end
	if scaled then Tell("scale") elseif moved then Tell("pan") end
	if landed and landed.done then
		local ok, err = pcall(landed.done)
		if not ok then geterrorhandler()(err) end
	end

	local still = not (drag or anchor or want.x or scaled or vx ~= 0 or vy ~= 0)
	if still and not settled then Save() end
	settled = still
	Follow()

	if fading then
		local a = canvas:GetAlpha()
		if (ns.Art and ns.Art.Loaded()) or GetTime() - shownAt > 0.5 then
			a = math.min(1, a + dt / FADE)
			canvas:SetAlpha(a)
		end
		if a >= 1 then fading = false end
	end
	local marked = Bare() and 0 or 1
	if marksAlpha ~= marked then
		local step = dt / MARKS_FADE
		Marks(marked > marksAlpha and math.min(marked, marksAlpha + step) or math.max(marked, marksAlpha - step))
	end
	local crowded = focus.on and FOCUS.CROWD or 1
	if focus.alpha ~= crowded then
		local step = dt * (1 - FOCUS.CROWD) / FOCUS.FADE
		Crowd(crowded > focus.alpha and math.min(crowded, focus.alpha + step) or math.max(crowded, focus.alpha - step))
	end

	for _, layer in ipairs(layers) do
		if layer.Tick then
			local from = debugprofilestop()
			local ok, err = pcall(layer.Tick, dt)
			if not ok then geterrorhandler()(err) end
			LayerClock(layer, "each frame"):Lap(debugprofilestop() - from)
		end
	end
	if loading then Load() end
	Spin(dt)
end

-- The mouse

local function Click(button)
	local x, y = View.Cursor()
	if ns.Nav and ns.Nav.Click(button, x, y) then return end
	if button == "LeftButton" and x then
		local now = GetTime()
		if now - lastClick < DOUBLE then
			lastClick = 0
			View.ZoomAt(2)
		else
			lastClick = now
		end
	end
end

-- A pen on the map (View.SetPen(fn)): while one is set the left button draws, fn("down") as it is pressed and
-- fn("up") as it is let go (the pen reads the cursor itself meanwhile), and the right button pans the map; a
-- right click still goes out a step.
local pen
function View.SetPen(fn) pen = fn end
function View.Pen() return pen end

local function Let(button)
	if button == "LeftButton" and pen then
		pen("up")
		return
	end
	if button == "RightButton" and drag and drag.right then
		local d = drag
		drag, View.right = nil, nil
		if not d.moved then
			vx, vy = 0, 0
			Click(button)
		elseif GetTime() - touched > 0.08 then
			vx, vy = 0, 0
		end
		return
	end
	if button == "LeftButton" then
		local d = drag
		drag = nil
		if not d then return end
		if d.moved then
			-- Held still before letting go: no throw.
			if GetTime() - touched > 0.08 then vx, vy = 0, 0 end
		else
			vx, vy = 0, 0
			Click(button)
		end
	elseif button == "RightButton" then
		local d = View.right
		View.right = nil
		if d then
			local px, py = CursorPort()
			local dx, dy = px - d[1], py - d[2]
			if dx * dx + dy * dy <= CLICK then Click(button) end
		end
	end
end

local function Build()
	rest = CreateFrame("Frame", nil, UIParent)
	rest:SetSize(REST[1], REST[2])
	rest:SetPoint("CENTER")
	rest:Hide()
	port = CreateFrame("Frame", nil, rest)
	port:SetAllPoints(rest)
	port:SetFrameLevel(LEVEL)
	port:SetClipsChildren(true)
	port:EnableMouse(true)
	port:EnableMouseWheel(true)
	port:Hide()
	back = port:CreateTexture(nil, "BACKGROUND", nil, -8)
	back:SetAllPoints()
	View.Ground(nil)
	canvas = CreateFrame("Frame", nil, port)
	canvas:SetFrameLevel(LEVEL + 1)
	canvas:SetSize(1, 1)
	marks = CreateFrame("Frame", nil, canvas)
	marks:SetAllPoints()
	marks:SetFrameLevel(LEVEL + 1)
	for _, key in ipairs({ "crowd", "lift" }) do
		local frame = CreateFrame("Frame", nil, marks)
		frame:SetAllPoints()
		frame:SetFrameLevel(LEVEL + 1)
		focus[key] = frame
	end
	-- The veil: over the land, under every pin (the map's highlight is the lowest): a shade all over, deeper at the edges.
	local veil = CreateFrame("Frame", nil, port)
	veil:SetAllPoints()
	veil:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_MAP_HIGHLIGHT") - 1)
	veil:EnableMouse(false)
	local all = veil:CreateTexture(nil, "BACKGROUND")
	all:SetAllPoints()
	all:SetColorTexture(0, 0, 0, FOCUS.DIM)
	local dark, clear = CreateColor(0, 0, 0, FOCUS.EDGE), CreateColor(0, 0, 0, 0)
	for _, edge in ipairs({ { "LEFT", "HORIZONTAL", dark, clear }, { "RIGHT", "HORIZONTAL", clear, dark },
		{ "BOTTOM", "VERTICAL", dark, clear }, { "TOP", "VERTICAL", clear, dark } }) do
		local band = veil:CreateTexture(nil, "BORDER")
		band:SetColorTexture(1, 1, 1, 1)
		band:SetGradient(edge[2], edge[3], edge[4])
		band:SetPoint(edge[1])
		if edge[2] == "HORIZONTAL" then
			band:SetPoint("TOP")
			band:SetPoint("BOTTOM")
		else
			band:SetPoint("LEFT")
			band:SetPoint("RIGHT")
		end
		veil[edge[1]] = band
	end
	-- (The edges' shade reaches its share of the port, whatever its size.)
	veil:SetScript("OnSizeChanged", function(self, wide, tall)
		self.LEFT:SetWidth(wide * FOCUS.REACH)
		self.RIGHT:SetWidth(wide * FOCUS.REACH)
		self.TOP:SetHeight(tall * FOCUS.REACH)
		self.BOTTOM:SetHeight(tall * FOCUS.REACH)
	end)
	veil:SetAlpha(0)
	veil:Hide()
	focus.veil = veil
	-- What stands over the window: over the map area, the window's own (the port may leave for the overlay).
	chrome = CreateFrame("Frame", nil, rest)
	chrome:SetAllPoints(rest)
	chrome:SetFrameLevel(LEVEL)
	chrome:EnableMouse(false)
	chrome:Hide()
	-- The overlay's home: the whole screen, under everything else.
	cover = CreateFrame("Frame", nil, UIParent)
	cover:SetAllPoints(UIParent)
	cover:SetFrameStrata("BACKGROUND")
	cover:EnableMouse(false)
	-- (Drawn as one picture, then faded, as the game's map window is: faded layer by layer, wherever they
	-- overlap the fades would stack and the map would stand far more solid than its setting.)
	cover:SetIsFrameBuffer(true)
	cover:Hide()
	-- What stands on the map lies on a cover of its own over that one, one picture too, faded less.
	laid.over = CreateFrame("Frame", nil, UIParent)
	laid.over:SetAllPoints(UIParent)
	laid.over:SetFrameStrata("BACKGROUND")
	laid.over:SetFrameLevel(cover:GetFrameLevel() + 1)
	laid.over:EnableMouse(false)
	laid.over:SetIsFrameBuffer(true)
	laid.over:Hide()
	-- The spinner, low in the middle, on a soft shade so it stands off any ground.
	status = CreateFrame("Frame", nil, chrome)
	status:SetSize(SPIN * 3, SPIN * 3)
	status:SetPoint("BOTTOM", chrome, "BOTTOM", 0, SPIN)
	status:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 100)
	status:EnableMouse(false)
	local shade = status:CreateTexture(nil, "BACKGROUND")
	shade:SetTexture(Shy.MEDIA .. "Glow")
	shade:SetVertexColor(0, 0, 0, 0.5)
	shade:SetAllPoints()
	Shy.UI.Spinner(status, SPIN):SetPoint("CENTER")
	status:SetAlpha(0)
	status:Hide()

	port:SetScript("OnUpdate", Tick)
	port:SetScript("OnMouseDown", function(_, button)
		if not map then return end
		if button == "LeftButton" and pen then
			pen("down")
		elseif button == "LeftButton" or (button == "RightButton" and pen) then
			local px, py = CursorPort()
			drag = { px = px, py = py, cx = cx, cy = cy, moved = false, right = button == "RightButton" }
			vx, vy, anchor, travel, flight, seek, chasing = 0, 0, nil, false, nil, 0, false
			want.x, want.y = nil, nil
			want.s = s
		elseif button == "RightButton" then
			View.right = { CursorPort() }
		end
	end)
	port:SetScript("OnMouseUp", function(_, button) Let(button) end)
	port:SetScript("OnMouseWheel", function(_, delta) View.ZoomAt(WHEEL ^ delta) end)
	port:SetScript("OnSizeChanged", function()
		if not map then return end
		local zoom, goal = s / fit, (want.s or s) / fit
		Limits()
		s, want.s = zoom * fit, goal * fit
		HoldWant()
		Lay()
		Tell("size")
	end)
end

-- The window

local function Opened()
	if not using then return end
	local zone = MapUtil.GetDisplayableMapForPlayer()
	local last = T.db.last[ns.Me()]
	local shown
	-- (Not open yet: the map last shown was saved as it closed, and isn't saved again over what is kept.)
	-- (Reopened where it was left, it stays put if it was moved; anywhere else it starts on you.)
	astray, stood, chasing = false, nil, false
	if laid.on then
		-- The overlay opens on you: on the map last shown while you are on it, else on your zone. (A map
		-- waiting to be opened waits for the window.)
		shown = T.db.remember and last and last.map and View.PlayerAt(last.map) ~= nil and View.Show(last.map, "here")
	elseif pending then
		shown = View.Show(pending)
		pending = nil
	elseif T.db.remember and last and last.zone == zone and last.map then
		if T.db.follow then
			-- Following you: the map opens on you, at the zoom it was left at (where it was moved to is let go).
			shown = View.PlayerAt(last.map) ~= nil and View.Show(last.map, "here")
		else
			shown = View.Show(last.map)
			astray = last.astray == true
		end
	end
	if not shown then View.Show(zone, "here") end
	open = true
	touched = 0
	sinceOpen = 0
	-- At once, what it takes to see the map; the rest comes in over the next frames (Load).
	local from = debugprofilestop()
	loading = { step = 1, told = false, at = GetTime() }
	for _, layer in ipairs(layers) do
		if not layer.later then
			TellLayer(layer, "map")
			TellLayer(layer, "open")
		end
	end
	-- (Its pictures already in, as when it reopens on the map left: no fade up from dark.)
	if ns.Art and ns.Art.Loaded() then
		canvas:SetAlpha(1)
		fading = false
	end
	Clock("opening, at once", debugprofilestop() - from)
end

local function Closed()
	if map and open then
		Save()
		T.db.last[ns.Me()] = { map = map, zone = MapUtil.GetDisplayableMapForPlayer(), astray = astray }
	end
	open, drag, vx, vy, anchor, flight = false, nil, 0, 0, nil, nil
	focus.on = false
	Crowd(1)
	loading, statusAlpha = nil, 0
	status:SetAlpha(0)
	status:Hide()
	Tell("close")
	-- What comes in after the map goes with it, so the next opening never shows it as it was.
	for _, layer in ipairs(layers) do
		if layer.later then TellLayer(layer, "map") end
	end
end

-- The map's window (Window.lua): while it is open the view lives in it, what stands over the map with it, and the
-- bar and the crumbs on its strip (each told through View.OnHost). While it is closed they wait out of sight.
local hosts = {}

function View.OnHost(fn) hosts[#hosts + 1] = fn end
-- Where the bar and the crumbs go now: the strip of the window holding the view, or out of sight.
function View.Strip() return own and own.strip or rest end
-- The window holding the view (its box), or out of sight while it is closed.
function View.Window() return own and own.box or rest end
function View.Own() return own ~= nil end

local function Chrome()
	local window = own and own.box or rest
	chrome:SetParent(window)
	chrome:ClearAllPoints()
	chrome:SetAllPoints(own and own.well or rest)
	chrome:SetFrameStrata(window:GetFrameStrata())
	chrome:SetFrameLevel(LEVEL)
	for _, fn in ipairs(hosts) do
		local ok, err = pcall(fn, own ~= nil)
		if not ok then geterrorhandler()(err) end
	end
end

-- The overlay

-- The port onto the overlay's cover (the whole screen, low, kept from the mouse), or back into its window.
local function Lodge(on)
	laid.on = on
	local window = own and own.box or rest
	local home = on and cover or window
	port:SetParent(home)
	port:ClearAllPoints()
	port:SetAllPoints(on and cover or (own and own.well) or rest)
	port:SetFrameStrata(home:GetFrameStrata())
	port:SetFrameLevel(LEVEL)
	-- What stands on the map goes onto the cover over the map's, and back onto the canvas: still laid over
	-- the canvas, whose scale it takes itself while it is off it (Lay).
	marks:SetParent(on and laid.over or canvas)
	marks:ClearAllPoints()
	marks:SetAllPoints(canvas)
	marks:SetScale(on and s or 1)
	marks:SetFrameStrata(home:GetFrameStrata())
	marks:SetFrameLevel(LEVEL + 1)
	-- (The ground past the map's edge is the game itself.)
	back:SetShown(not on)
	cover:SetShown(on)
	laid.over:SetShown(on)
	if on then
		laid.zoneIn = OVERLAY.ZONE_LOOK
		Quiet()
	else
		Unquiet()
	end
end

-- Lays the view where it belongs: over the screen while the overlay is on, the view in use and the window
-- closed; else in the window.
local function Home()
	if not port then return end
	Fade()
	local want = using and T.db.overlay == true and not own
	if want == laid.on then return end
	if want then
		Lodge(true)
		Opened()
	else
		if open then Closed() end
		Lodge(false)
	end
end

-- The map's window opened (box, its well and strip) or closed (nil): the view moves into it, or onto the overlay
-- or out of sight.
function View.Host(to)
	if not port or (to and own and own.box == to.box) or (not to and not own) then return end
	if open then Closed() end
	if laid.on then Lodge(false) end
	own = to
	Lodge(false)
	Chrome()
	if not using then return end
	if own then Opened() else Home() end
end

local function Use(on)
	if on == using or not port then return end
	-- (Given up, the view leaves the overlay first.)
	if not on and laid.on then
		if open then Closed() end
		Lodge(false)
	end
	using = on
	if not on and own then
		own = nil
		Lodge(false)
		Chrome()
	end
	chrome:SetShown(on)
	port:SetShown(on)
	if not on then loading = nil end
	Tell("use")
	if on and own then
		Opened()
	elseif on then
		Home()
	else
		open = false
	end
	Shy:Fire("SHY_MAPS", on)
end

local function Apply()
	if not port then Build() end
	Use(T.db.on == true)
	Home()
end

ns.OnApply(Apply)

local events = CreateFrame("Frame")
events:RegisterEvent("GLOBAL_MOUSE_UP")
events:SetScript("OnEvent", function(_, _, name)
	-- This client sometimes never tells a frame its button came up.
	if drag and name == "LeftButton" then Let("LeftButton") end
end)

-- As the game's map canvas answers (Shy.addons.Maps:View()).

function View:GetCanvas() return focus.crowd end
function View:GetCanvasContainer() return port end
-- (What stands over the map's window, apart: it stays with the window as the view goes onto the overlay.)
function View:GetOverContainer() return chrome end
function View:GetCanvasScale() return s end
function View:GetCanvasZoomPercent() return View.Zoom() end
function View:GetMapID() return map end
function View:IsShown() return using and open end
function View:GetPinFrameLevel(name) return View.Level(name) end
-- How far past the shown map's edges the view may show, in shares of the map: none on a map held to its art;
-- free (the terrain look's ground goes on), as far as its middle may stray and half the widest view more.
-- A line that leaves the map runs on that far, not to the map's edge.
function View:GetBeyond() return Free() and FREE_REACH + 0.5 / FREE_LEAST or 0 end

-- The game's map hands out its pin levels through a manager; the view answers the same, so code that
-- lays a frame over the game's canvas lays it over the view by asking the one in use.
local levels = { GetValidFrameLevel = function(_, name) return View.Level(name) end }
function View:GetPinFrameLevelsManager() return levels end

function View:GetNormalizedCursorPosition()
	if not map then return 0, 0 end
	local px, py = CursorPort()
	local pw, ph = Room()
	local x, y = cx + (px - pw / 2) / (w * s), cy + (py - ph / 2) / (h * s)
	return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end
