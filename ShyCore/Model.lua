-- Shy.Model: a creature or an object drawn whole in its box, in the middle of it and as large as the box allows,
-- whatever its shape (a chest, a fish, an ogre, a dragon) and whatever the box's.
--
-- The game's own model frame chooses its camera itself and says nothing of how large what it draws is: an object
-- sits where its file put it, a creature is cut off at the knees. So the model is drawn in a scene of its own, where
-- its size can be asked (the box its model fills, once it is in) and the camera is ours to place:
--   the middle    the model turns about the middle of its box, which stands in the middle of the view
--   the size      the camera stands back as far as keeps the whole box in view through the whole turn (the box,
--                 turned about its upright middle, sweeps a drum: every point of both its rims is kept inside the
--                 view, less a margin), and no farther, so the larger of its width and height fills the box
--   the view      what the camera sees a unit ahead is asked of the scene itself (three points put through its own
--                 projection), not reckoned from an angle: where the scene won't answer, the angle is taken as the
--                 one across the view's corners, which errs toward too small, never toward cut off, and is asked
--                 again until the scene answers
-- Placed again when the box changes size or the model's measure does.
--
-- What is asked for, in the order tried (each waited on a moment before the next):
--   display    a creature's look, drawn at once out of the game's own files
--   creature   a creature by itself where no look is known: the game draws it only once it has met one. Its look
--              is then asked of the game and drawn as a display, fitted; where the game won't name it, the game's
--              own drawing is shown as it frames it
--   file       an object's own model file
--
--   local view = Shy.Model.New(parent)     a frame: size and anchor it as any other
--   view:Set(what)                         what = { display = id, creature = id, file = id }; nil for nothing
--   view:Drawn() -> bool                   whether what was asked for is in and shown
--   view.turn = radians a second           how fast it turns (0: still, facing out)
--   view.onDrawn = function(view)          called once it is in and shown
--   Shy.Model.Fit(hx, hy, hz, F, R, U, tanH, tanV) -> back, lift     the reckoning alone (see below)
local Shy = Shy
local Model = {}
Shy.Model = Model

local VIEW = {
	yaw = math.pi,        -- the camera stands in front of what it shows
	pitch = 0.14,         -- and looks a little down on it (radians)
	fov = 0.8,            -- the camera's angle (radians)
	margin = 8,           -- units left clear at each edge of the box
	most = 0.3,           -- ... never more than this share of the box's half, in a small box
	rim = 64,             -- points kept in view round each rim of the drum the turning box sweeps
	halves = 32,          -- times the camera's lift is closed in on
	patience = 1.0,      -- seconds one way of asking is waited on before the next is tried
	recheck = 0.5,        -- seconds between looks at whether the measure or the view changed
	same = 0.02,          -- a measure within this share of the last is the same
	distance = 1.15,      -- the game's own drawing of a creature: its camera a little back
}

-- Where a camera stands to keep a box whole in view as the box turns about its upright middle.
--   hx, hy, hz    half the box's depth, width and height; its middle is where the camera looks
--   F, R, U       the camera's forward, right and up, each { x, y, z } of length one
--   tanH, tanV    half of what it sees a unit ahead, across and up
-- Returns how far back along F it stands from the box's middle, and how far along U it is lifted so what it sees
-- stands as far from the top of the view as from the foot (a camera looking down sees the near rim lower).
function Model.Fit(hx, hy, hz, F, R, U, tanH, tanV)
	local reach = math.sqrt(hx * hx + hy * hy)
	local aheads, ups, count = {}, {}, 0
	local above, below, beside = -math.huge, -math.huge, -math.huge
	for i = 1, VIEW.rim do
		local turn = 2 * math.pi * i / VIEW.rim
		local x, y = reach * math.cos(turn), reach * math.sin(turn)
		for side = -1, 1, 2 do
			local z = side * hz
			local ahead = x * F[1] + y * F[2] + z * F[3]
			local across = x * R[1] + y * R[2] + z * R[3]
			local up = x * U[1] + y * U[2] + z * U[3]
			count = count + 1
			aheads[count], ups[count] = ahead, up
			above = math.max(above, up / tanV - ahead)
			below = math.max(below, -up / tanV - ahead)
			beside = math.max(beside, math.abs(across) / tanH - ahead)
		end
	end
	-- Back enough for the highest and the lowest point at once (lifted to where both just fit), and for the widest.
	local back = math.max((above + below) / 2, beside)
	-- The lift from there: what is seen above the middle of the view falls as the camera rises and what is seen
	-- below it grows, so the height where the two are equal is closed in on by halves.
	local low, high = -(reach + hz), reach + hz
	for _ = 1, VIEW.halves do
		local lift = (low + high) / 2
		local over, under = -math.huge, -math.huge
		for i = 1, count do
			local seen = (ups[i] - lift) / math.max(aheads[i] + back, 1e-9)
			over, under = math.max(over, seen), math.max(under, -seen)
		end
		if over > under then low = lift else high = lift end
	end
	return back, (low + high) / 2
end

local function Axes(scene)
	return { scene:GetCameraForward() }, { scene:GetCameraRight() }, { scene:GetCameraUp() }
end

-- Half of what the scene's camera sees a unit ahead, across and up, and whether the scene itself said so.
local function Seen(scene, wide, tall, F, R, U)
	local px, py, pz = scene:GetCameraPosition()
	local step = 0.1
	local cx, cy = scene:Project3DPointTo2D(px + F[1], py + F[2], pz + F[3])
	local sx = scene:Project3DPointTo2D(px + F[1] + step * R[1], py + F[2] + step * R[2], pz + F[3] + step * R[3])
	local _, ty = scene:Project3DPointTo2D(px + F[1] + step * U[1], py + F[2] + step * U[2], pz + F[3] + step * U[3])
	-- (The point straight ahead is the view's middle, so its place is half the view's size in the scene's own measure.)
	if cx and cy and sx and ty and cx > 0 and cy > 0 and sx ~= cx and ty ~= cy
		and math.abs(cx / cy - wide / tall) < 0.05 * wide / tall then
		return step * cx / math.abs(sx - cx), step * cy / math.abs(ty - cy), true
	end
	local half, corner = math.tan(VIEW.fov / 2), math.sqrt(wide * wide + tall * tall)
	return half * wide / corner, half * tall / corner, false
end

-- Half the depth, width and height of the box the actor's model fills, or nil while it has none.
local function Measure(actor)
	local x0, y0, z0, x1, y1, z1 = actor:GetActiveBoundingBox()
	if not (x0 and y0 and z0 and x1 and y1 and z1) then return nil end
	local hx, hy, hz = math.abs(x1 - x0) / 2, math.abs(y1 - y0) / 2, math.abs(z1 - z0) / 2
	if hx + hy + hz <= 0 then return nil end
	return hx, hy, hz
end

-- Stands the camera where the measured box fits the view. Whether it could (a view with no size can't be fitted).
local function Place(view)
	local scene, box = view.scene, view.box
	local wide, tall = scene:GetWidth(), scene:GetHeight()
	if not (wide and tall and wide > 0 and tall > 0) then return false end
	local F, R, U = Axes(scene)
	local tanH, tanV, exact = Seen(scene, wide, tall, F, R, U)
	local clearH = 1 - math.min(VIEW.most, 2 * VIEW.margin / wide)
	local clearV = 1 - math.min(VIEW.most, 2 * VIEW.margin / tall)
	local back, lift = Model.Fit(box[1], box[2], box[3], F, R, U, tanH * clearH, tanV * clearV)
	scene:SetCameraPosition(lift * U[1] - back * F[1], lift * U[2] - back * F[2], lift * U[3] - back * F[3])
	local reach = math.sqrt(box[1] * box[1] + box[2] * box[2] + box[3] * box[3])
	scene:SetCameraNearClip(math.max(0.01, (back - reach) / 2))
	scene:SetCameraFarClip(back + 2 * reach + 1)
	view.exact, view.wide, view.tall = exact, wide, tall
	return true
end

local function Veil(view, alpha)
	view.scene:SetAlpha(alpha)
	view.actor:SetAlpha(alpha)
end

-- Asks for what the way now tried names, nothing shown until it is in.
local function Ask(view)
	local way = view.ways[view.way]
	view.waited, view.since, view.box, view.placed, view.drawn = 0, 0, nil, false, false
	Veil(view, 0)
	view.actor:ClearModel()
	view.own:SetAlpha(0)
	view.own:ClearModel()
	view.own:SetShown(way ~= nil and way.creature ~= nil)
	if not way then return end
	if way.display then
		view.actor:SetModelByCreatureDisplayID(way.display)
	elseif way.file then
		view.actor:SetModelByFileID(way.file)
	else
		view.own:SetCreature(way.creature, 0)
		view.own:SetFacing(view.facing)
		return
	end
	view.actor:SetAnimation(0, 0, 1.0)
	view.actor:SetYaw(view.facing)
end

local function Shown(view)
	view.drawn = true
	if view.onDrawn then view.onDrawn(view) end
end

-- A creature asked for by itself: once the game has drawn it, the look it wears is asked for as a display (the
-- way becomes that one, so it is measured and fitted); a creature whose look the game won't name stays as drawn.
local function Creature(view, way)
	if view.drawn then return end
	-- (No model yet: the frame has no file to name.)
	local ok, file = pcall(view.own.GetModelFileID, view.own)
	if not (ok and type(file) == "number" and file > 0) then return end
	local display = view.own:GetDisplayInfo()
	if type(display) == "number" and display > 0 then
		way.creature, way.display = nil, display
		Ask(view)
		return
	end
	view.own:SetPortraitZoom(0)
	view.own:SetCamDistanceScale(VIEW.distance)
	view.own:RefreshCamera()
	view.own:SetAlpha(1)
	Shown(view)
end

-- A display or a file, in the scene: placed once it is in and has a measure, and again when either changed.
local function Fitted(view, elapsed)
	local due = not view.placed
	view.since = view.since + elapsed
	if view.since >= VIEW.recheck then view.since, due = 0, true end
	if not due then return end
	if not view.actor:IsLoaded() then
		-- (Shown, and the game let its model go: asked for again.)
		if view.drawn then Ask(view) end
		return
	end
	local hx, hy, hz = Measure(view.actor)
	if not hx then return end
	local box = view.box
	local same = box and math.abs(box[1] - hx) <= VIEW.same * box[1] and math.abs(box[2] - hy) <= VIEW.same * box[2]
		and math.abs(box[3] - hz) <= VIEW.same * box[3]
	local sized = view.wide == view.scene:GetWidth() and view.tall == view.scene:GetHeight()
	if not (same and sized and view.placed and view.exact) then
		view.box = { hx, hy, hz }
		view.placed = Place(view)
	end
	if view.placed and not view.drawn then
		Veil(view, 1)
		Shown(view)
	end
end

local function Update(view, elapsed)
	local way = view.ways and view.ways[view.way]
	if not way then return end
	if view.turn ~= 0 then
		view.facing = (view.facing + elapsed * view.turn) % (2 * math.pi)
		if way.creature then view.own:SetFacing(view.facing) else view.actor:SetYaw(view.facing) end
	end
	if way.creature then Creature(view, way) else Fitted(view, elapsed) end
	if view.drawn then return end
	-- Not in after a moment: the next way of asking, where there is one.
	view.waited = view.waited + elapsed
	if view.waited > VIEW.patience and view.ways[view.way + 1] then
		view.way = view.way + 1
		Ask(view)
	end
end

local View = {}

function View:Set(what)
	local display, creature, file = what and what.display, what and what.creature, what and what.file
	local named = (display and ("d" .. display) or "") .. (creature and ("c" .. creature) or "") .. (file and ("f" .. file) or "")
	local key = named ~= "" and named or nil
	if key ~= self.key then
		local ways = {}
		if display then ways[#ways + 1] = { display = display } end
		if creature then ways[#ways + 1] = { creature = creature } end
		if file then ways[#ways + 1] = { file = file } end
		self.key, self.ways, self.way, self.facing = key, ways, 1, 0
		Ask(self)
	end
	self:SetShown(key ~= nil)
end

function View:Drawn()
	return self.drawn == true
end

function Model.New(parent)
	local view = CreateFrame("Frame", nil, parent)
	local scene = CreateFrame("ModelScene", nil, view)
	scene:SetAllPoints()
	scene:EnableMouse(false)
	scene:SetCameraFieldOfView(VIEW.fov)
	scene:SetCameraOrientationByYawPitchRoll(VIEW.yaw, VIEW.pitch, 0)
	local actor = scene:CreateActor(nil, "ModelSceneActorTemplate")
	actor:SetUseCenterForOrigin(true, true, true)
	actor:SetPosition(0, 0, 0)
	local own = CreateFrame("PlayerModel", nil, view)
	own:SetAllPoints()
	own:SetKeepModelOnHide(true)
	own:Hide()
	view.scene, view.actor, view.own = scene, actor, own
	view.turn, view.facing, view.ways, view.way, view.drawn = 0, 0, {}, 1, false
	view.Set, view.Drawn = View.Set, View.Drawn
	Veil(view, 0)
	-- (Another size: placed again at the next look.)
	scene:SetScript("OnSizeChanged", function() view.placed = false end)
	view:SetScript("OnUpdate", Update)
	view:Hide()
	return view
end
