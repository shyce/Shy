-- Shy.Way: how to get anywhere, for every Shy addon. The quickest way from a place to another on foot over
-- the ground itself (Ground.lua: stairs, lifts, drops, the floor that high, walls, water swum; Trail.lua:
-- the one way the player is led along, kept for every map and arrow), and by
-- every ride there is (Journey.lua: flights, boats, zeppelins, the airboat, the tram, portals); the ride
-- the character is on, noticed as it happens (Ride.lua, Flight.lua); and the flight master's times
-- (Aloft.lua). Each file says its part of the API; this one makes the table they share, in place of
-- ShyCore's (the same questions, "not known" for every answer, while ShyWay is off).
--
--   Shy.Way.data          what ships: nodes, floors and roads (by world, from ShyWay_Ground_<world>, loaded on
--                         demand), lifts, falls, flightPaths, flightWays, transit (Data\*.lua)
--   Shy.Way.Saved()       what this account keeps (ShyWayDB): lifts ridden, flight and ride times, flight
--                         points known, the ride being taken, each character's pace
--   Shy.Way.Pace()        -> yards a second the character travels over open ground, and true where that is
--                         riding: a runner's pace until they are seen on a mount, their mount's from then on
--   Shy.Way.Paced(seconds) -> the seconds a walk the ground reckons on foot takes them: ridden, the mounting
--                         in it, where that is the quicker
--   Shy.Way.SetPace(pace) the character was seen riding at that pace (kept, by character); nil or a runner's
--                         pace: they go on foot again
--
-- Bus: SHY_TERRAIN (a way being worked out is known; "pace": the character's pace changed), SHY_FLIGHT,
-- SHY_RIDE: each file says when.

local Way = {
	data = { nodes = {}, floors = {}, roads = {}, lifts = {}, falls = { speed = 7, safe = 14, spells = {} }, flightPaths = {}, flightWays = {} },
}
Shy.Way = Way

-- (What ShyCore kept before there was a ShyWay is ShyWay's from the first time it loads.)
local ADOPTED = { "lifts", "air", "flightPoints", "riding", "flying" }

function Way.Saved()
	if type(ShyWayDB) ~= "table" then ShyWayDB = {} end
	return ShyWayDB
end

-- The character's pace ---------------------------------------------------------------------------------
-- The ground reckons every walk at a runner's pace (FOOT). Someone with a mount rides the long ones: once
-- they are seen on one, the run speed the game gives them there is their pace (ShyWayDB.pace, by character:
-- the speed of the mount they have and the riding they know, which nothing else tells), and whoever weighs a
-- walk against a ride, a flight or a wait reads it here. A walk is ridden where that is the quicker with the
-- mounting in it, so a few steps stay a few steps.
local PACE = {
	FOOT = 7,                -- yards a second: a runner's
	MOUNTING = 3,            -- seconds to be on a mount
	LEAST = 1.1,             -- a pace under this many times a runner's is no mount's
	MOST = 3,                -- ... nor one over this many: something else carried them
}

local function Paces()
	local saved = Way.Saved()
	if type(saved.pace) ~= "table" then saved.pace = {} end
	return saved.pace
end

function Way.Pace()
	local pace = Paces()[UnitGUID("player") or "?"]
	if pace then return pace, true end
	return PACE.FOOT, false
end

function Way.Paced(seconds)
	local pace, riding = Way.Pace()
	if not riding then return seconds end
	return math.min(seconds, PACE.MOUNTING + seconds * PACE.FOOT / pace)
end

function Way.SetPace(pace)
	local guid = UnitGUID("player") or "?"
	if not pace or pace < PACE.FOOT * PACE.LEAST then
		pace = nil
	elseif pace > PACE.FOOT * PACE.MOST then
		return
	end
	local paces = Paces()
	local was = paces[guid]
	if was == pace or (was and pace and math.abs(was - pace) < 0.05) then return end
	paces[guid] = pace
	Shy:Fire("SHY_TERRAIN", "pace")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, name)
	if event ~= "ADDON_LOADED" then
		-- (On a mount, not carried by a flight: the run speed the game gives them now is their mount's. One no
		-- quicker than a runner's says nothing: the mount's speed may not be theirs yet as the event comes.)
		if not IsMounted() or UnitOnTaxi("player") then return end
		local _, run = GetUnitSpeed("player")
		if run and not issecretvalue(run) and run >= PACE.FOOT * PACE.LEAST then Way.SetPace(run) end
		return
	end
	if name ~= "ShyWay" then return end
	events:UnregisterEvent("ADDON_LOADED")
	local saved, older = Way.Saved(), type(ShyCoreDB) == "table" and ShyCoreDB or nil
	for _, key in ipairs(ADOPTED) do
		if older and older[key] ~= nil then
			if saved[key] == nil then saved[key] = older[key] end
			older[key] = nil
		end
	end
end)
