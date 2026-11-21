-- Card countdowns: waits a guide step starts (".timer 14,RP"), and the flight or the ride being taken.
-- A live step's timed task is armed from view.timers on each route rebuild; it runs once the task is done.
-- Flights and rides are ShyWay's (Shy.Way.Flight, Shy.Way.Riding): when one begins or ends the route is
-- worked out again, and while it lasts the card counts it down on its plate.

local ADDON, ns = ...
local T = ns.T
local G, R = ns.Guide, ns.Route

local armed = {}         -- "step:part" -> { index, number, seconds, label }
local armedFor           -- the guide those belong to
local running = {}       -- { label, started, seconds }, soonest to end first

local function Start(seconds, label)
	local now = GetTime()
	for _, timer in ipairs(running) do
		if timer.label == label and now - timer.started < 2 then return end
	end
	running[#running + 1] = { label = label, started = now, seconds = seconds }
	table.sort(running, function(a, b) return a.started + a.seconds < b.started + b.seconds end)
	ns.Refresh()
	C_Timer.After(seconds + 0.1, function() ns.Refresh() end)
end

-- In the air on a flight there is a countdown for (asked to land early: to where it now lands), and the
-- card counts flights.
local function Flying()
	return Shy.Way.Flight.Left() ~= nil
end

-- A ride's sign (ShyWay's: Shy.Way.RIDES): a boat's sail, the tram's car, a zeppelin; an airboat wears
-- the flight's wing.
local function Sign(by)
	local look = Shy.Way.RIDES[by]
	return look and look.sign or "flight"
end

-- Aboard a boat, a zeppelin or an airboat, or in the tram (Shy.Way.Riding), and the card counts those as
-- it does flights: the ride's sign (its mark and color on the card); nil when not.
local function Sailing()
	local ride = Shy.Way.Riding()
	if not ride or not Shy.Way.RideLeft() then return nil end
	return Sign(ride.by)
end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Returns label, seconds left, fraction left, and display text when it isn't a plain clock.
-- `waits` includes guide timers, `flights` includes the current flight.
local function Running(waits, flights)
	if flights and Flying() then return Shy.Way.Flight.Left() end
	if flights and Sailing() then return Shy.Way.RideLeft() end
	if not waits then return nil end
	local now = GetTime()
	while running[1] and now >= running[1].started + running[1].seconds do table.remove(running, 1) end
	local timer = running[1]
	if not timer then return nil end
	local left = timer.started + timer.seconds - now
	return timer.label, left, left / timer.seconds
end

-- In the tram: which end to get off at, under the card's leading row. The game says nowhere while in it,
-- the countdown is gone once the tram has had its time (the car may be on its way back by then), and a
-- distance from the far door names no city. So the line names the end nearer the first place to go,
-- whichever way the car runs; where a tram ride leads (back the way it came), the end it goes to.
local function OffAt(stop)
	local ride = Shy.Way.Riding()
	if not (ride and ride.tram) or stop ~= R.stops[1] then return nil end
	local there
	for _, each in ipairs(R.stops) do
		if each.kind ~= "errand" and each.north then
			there = each.ferry == "tram" and each.land or each
			break
		end
	end
	if not (there and there.north and there.continent) then return nil end
	local door, least
	for _, each in ipairs(Shy.Way.Stops()) do
		if each.by == "tram" and each.name and each.world == there.continent then
			local far = (each.north - there.north) ^ 2 + (each.west - there.west) ^ 2
			if not least or far < least then door, least = each, far end
		end
	end
	if not door then return nil end
	return ("Get off the tram in %s"):format(door.name), ns.SignColor("tram"), "tram"
end
ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, OffAt)

local function Watch()
	if armedFor ~= G.current then
		wipe(armed)
		armedFor = G.current
	end
	for key, timer in pairs(armed) do
		if G.PartDone(timer.index, timer.number) then
			armed[key] = nil
			Start(timer.seconds, timer.label)
		end
	end
	for _, stop in ipairs(R.stops) do
		local view = stop.kind == "guide" and stop.view
		if view and view.timers then
			for _, timer in ipairs(view.timers) do
				if not timer.done then
					armed[view.step.index .. ":" .. timer.number] = { index = view.step.index, number = timer.number,
						seconds = timer.seconds, label = timer.label or "Wait" }
				end
			end
		end
	end
end

Shy:On("SHY_LOGIN", function()
	-- Flight times this addon kept before ShyWay kept them go to ShyWay, once. Crossing times it kept were
	-- by the places of a table of docks there is no more: ShyWay times each ride anew (Ride.lua). (The flight
	-- times are kept while ShyWay is off: there is no one to hand them to.)
	local air = T.db.air
	if air and air.times and not Shy.Way.missing then
		Shy.Way.Flight.Adopt(air)
		air.times, air.timed, air.reckoned = nil, nil, nil
	end
	if air then air.ferries, air.rides, air.rideRuns = nil, nil, nil end
	ns.char.flying, ns.char.ride = nil, nil
	-- Take-off and landing, boarding and coming off: the route is worked out from where it lands, and then
	-- from where the character is again.
	Shy:On("SHY_FLIGHT", function() ns.Refresh() end)
	Shy:On("SHY_RIDE", function() ns.Refresh() end)
	ns.OnRoute(function(rebuilt)
		if rebuilt then Watch() end
	end, true)
end)

ns.GuideTimers = { Running = Running, Start = Start, Flying = Flying, Sailing = Sailing, Sign = Sign, Clock = Clock }
