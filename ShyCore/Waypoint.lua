-- Shy.Waypoint: the game's own map pin and what its arrow points at, set by every Shy addon through here.
--
-- In a fight with the world map open, the map redraws its pins the moment either changes, and the game
-- blocks that redraw when an addon asked for the change. So a change asked for then waits until the fight
-- ends or the map closes, the latest of each kind kept; what is read through here is already that change.
--
--   Shy.Waypoint.Set(map, x, y [, track])   the pin there (x, y: shares of the map); track true or false points
--                                           the arrow at it or takes it off, nil leaves the arrow be.
--                                           False where the map takes no pin
--   Shy.Waypoint.Clear()                    no pin
--   Shy.Waypoint.Track(on)                  the arrow points at the pin, or not
--   Shy.Waypoint.Quest(id [, before])       the arrow points at a quest (0: at none); before() runs just
--                                           before it is set, now or once the wait is over
--   Shy.Waypoint.Get() -> point or nil      the pin: { uiMapID, position = { x, y } }
--   Shy.Waypoint.Has()                      whether there is a pin
--   Shy.Waypoint.QuestID()                  the quest the arrow points at, or 0
--   Shy.Waypoint.Tracking()                 whether the arrow points at the pin
--   Shy.Waypoint.Held()                     true while a change asked for now would wait

local Waypoint = {}
Shy.Waypoint = Waypoint

local WAIT = 0.25   -- seconds between looks at whether what waits can be set now

local point         -- the pin waiting: { map, x, y }, false for none; nil while no pin change waits
local arrow         -- the arrow's change waiting: { quest = id, before = fn } or { pin = on }; nil for none
local looking = false

function Waypoint.Held()
	if not InCombatLockdown() then return false end
	local map = WorldMapFrame
	return map ~= nil and map:IsVisible()
end

local function Apply()
	local pin, aim = point, arrow
	point, arrow = nil, nil
	if pin then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(pin.map, pin.x, pin.y))
	elseif pin == false and C_Map.HasUserWaypoint() then
		C_Map.ClearUserWaypoint()
	end
	if not aim then return end
	if aim.quest then
		if aim.before then aim.before() end
		C_SuperTrack.SetSuperTrackedQuestID(aim.quest)
	else
		C_SuperTrack.SetSuperTrackedUserWaypoint(aim.pin)
	end
end

local Look
local function Go()
	if Waypoint.Held() then
		if not looking then
			looking = true
			C_Timer.After(WAIT, Look)
		end
		return
	end
	Apply()
end

function Look()
	looking = false
	if point ~= nil or arrow then Go() end
end

-- (Taking the arrow off the pin leaves a quest it was turned to pointed at.)
local function Aim(want)
	if want.pin == false and arrow and arrow.quest then return end
	arrow = want
end

function Waypoint.Set(map, x, y, track)
	if not (map and x and y and C_Map.CanSetUserWaypointOnMap(map)) then return false end
	point = { map = map, x = x, y = y }
	if track ~= nil then Aim({ pin = track }) end
	Go()
	return true
end

function Waypoint.Clear()
	if not Waypoint.Has() then return end
	point = false
	-- (The arrow can't stay on a pin that is gone.)
	if arrow and arrow.pin then arrow = nil end
	Go()
end

function Waypoint.Track(on)
	Aim({ pin = on and true or false })
	Go()
end

function Waypoint.Quest(id, before)
	Aim({ quest = id or 0, before = before })
	Go()
end

function Waypoint.Get()
	if point then return { uiMapID = point.map, position = { x = point.x, y = point.y } } end
	if point == false or not C_Map.HasUserWaypoint() then return nil end
	return C_Map.GetUserWaypoint()
end

function Waypoint.Has()
	if point ~= nil then return point ~= false end
	return C_Map.HasUserWaypoint() == true
end

function Waypoint.QuestID()
	if arrow then
		if arrow.quest then return arrow.quest end
		if arrow.pin then return 0 end
	end
	return C_SuperTrack.GetSuperTrackedQuestID() or 0
end

function Waypoint.Tracking()
	if point == false then return false end
	if arrow then
		if arrow.pin ~= nil then return arrow.pin end
		if arrow.quest ~= 0 then return false end
	end
	return C_SuperTrack.IsSuperTrackingUserWaypoint() == true
end
