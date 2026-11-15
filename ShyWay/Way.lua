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
--                         points known, the ride being taken
--
-- Bus: SHY_TERRAIN (a way being worked out is known), SHY_FLIGHT, SHY_RIDE: each file says when.

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

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
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
