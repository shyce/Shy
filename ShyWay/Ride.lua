-- Shy.Way rides: the boat, zeppelin, airboat or tram the character is on, noticed as it happens, for
-- every addon; on the maps as a flight is; and timed, so the next journey takes the time it took.
--
-- The game says nothing of being aboard. Two things do: standing (not swimming) where the ground is open
-- water, as on a ship's deck at the dock; and being carried, the character's place moving much faster than
-- the character moves itself. Either, near a ride's line (Data\Transit.lua's, the client's own), makes the
-- ride being taken the one that line leads to soonest: the next stop, not one past it, and never one that
-- ends here. The ride is followed along its line until the character is off it for a few seconds (landed
-- and walked off, or jumped). The tram has no world map and no place the game tells: being in its own map
-- is the ride, from the door the character was last seen at (else the one the journey they follow goes
-- by: Shy.Way.Following) to the other city's.
--
-- A ride taken from its stop to where it lands is timed (Shy.Way.Kept): from when the character came to
-- stand at its stop, the wait in it, for the journeys; and from when it set off, for the countdown aboard.
-- Untimed it is its line at a transport's speed and the wait for it (the generator's).
--
--   Shy.Way.Riding() -> ride or nil        { by, from, to (stops: to is where it lands), key, since }
--   Shy.Way.RideLeft() -> label, left, share, said   the countdown, as Shy.Way.Flight.Left: "Boat to
--                                              Auberdine", seconds left, the share left, the time in words
--   Shy.Way.Landing() -> place or nil      where the ride, or the flight, lands; with the zone map it is
--                                              on and where on it (place.map, x, y: 0 to 1) where known
--   Shy.Way.RIDES[by] = { word, sign, color }   how each way of riding is called and drawn
--
-- Bus: SHY_RIDE (ride or nil), when a ride begins and when it ends.

local T = Shy.Way
local Maps = Shy.Maps

local EVERY = 0.25           -- seconds between looks
local FAR = 1                -- ... and between looks NEAR yards or more from any ride's line or stop: none can begin there
local NEAR = 400
local PATCH = 200            -- yards a side of the patches the ground near rides is kept in (Near)
local HISTORY = 1.5          -- seconds of places the speed is reckoned over
local CARRIED = 5            -- yards a second faster than the character moves itself: carried
local CONFIRM = 25           -- yards carried along a line before the ride is sure (a step at a dock's end is not one)
local FROM_START = 100       -- yards from a line's start within which a ride began at its dock: its time is kept
local FASTEST = 80           -- yards a second: faster than this was no ride but a jump (a hearthstone, a portal)
local ON_LINE = 45           -- yards from a ride's line within which the character may be on it
local OFF_LINE = 80          -- yards: further than this, they are off it
local OFF_FOR = 3            -- seconds off it before the ride is over
local OFF_DECK = 40          -- yards from where a ride halts: landed and this far from it on foot, they are off
local FALLING = 1.2          -- seconds falling: jumped off (a jump on deck is shorter)
local STAYED = 120           -- seconds landed and not carried again: it left without them (no halt is this long)
local ENDS = 60              -- yards from a line's end: a ride that ends here is not the one being taken
local BEND = 15              -- yards: the lines are smoothed in pieces no longer than this
local SEEK = 80              -- points looked over past the last one passed
local LOST = 120             -- seconds with no place (a loading screen) before a ride is given up
local DOOR = 400             -- yards from a tram door within which the last place seen is where the ride began
local ARRIVED = 300          -- yards from the far door within which, out of the tram, the ride is over
local SETTLE = 20            -- seconds after coming out of the tram in which the far door is looked for
local AT_DECK = 25           -- yards from where a boat halts within which standing on open water is its deck
local AT_DOCK = 60           -- yards from a ride's stop where the wait for it begins
local LEFT_DOCK = 250        -- yards from it beyond which that wait is over (gone off elsewhere)

-- Each way of riding: what it is called, its sign (Shy.Maps.SIGNS; an airboat flies, and wears the flight's
-- wing; a portal has none), its color (Shy.Theme.TRAVEL).
local COLOR = Shy.Theme.TRAVEL
T.RIDES = {
	boat = { word = "Boat", sign = "sail", color = COLOR.boat },
	zeppelin = { word = "Zeppelin", sign = "zeppelin", color = COLOR.zeppelin },
	airboat = { word = "Airship", sign = "flight", color = COLOR.airboat },
	tram = { word = "Tram", sign = "tram", color = COLOR.tram },
	portal = { word = "Portal", color = COLOR.portal },
}

local lines = {}             -- by ride: { yards, [k] = smoothed stretch k }
local trail = {}             -- recent places: { at, world, north, west }
local aboard                 -- the ride being taken
local trip                   -- what the maps show of it
local last                   -- where the character was last seen out of the tram: a place
local out                    -- just out of the tram: { ride, took, at }, until the far door is seen
local log = {}               -- what was noticed, last NOTES of it, for the task manager's counters
local NOTES = 60
local speed = 0              -- yards a second carried, as last looked
local near = true            -- within NEAR yards of a ride's line or stop, as last looked

local function Note(what, world, north, west, carried)
	log[#log + 1] = { GetTime(), what, world, north, west, carried }
	while #log > NOTES do table.remove(log, 1) end
end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Where the character really is.
local function Position()
	return Shy.Here(true)
end

-- A ride's line: each of its stretches (one for each piece it sails: a new one after every loading screen)
-- smoothed, with its world; and its yards.
local function Line(ride)
	local made = lines[ride]
	if made then return made end
	made = { yards = 0 }
	for k, stretch in ipairs(ride.line or {}) do
		local flat = {}
		for i = 2, #stretch do flat[i - 1] = stretch[i] end
		local smooth = Maps.Smooth(flat, BEND)
		if smooth then
			smooth.continent = stretch[1]
			made[k] = smooth
			made.yards = made.yards + smooth.along[smooth.n]
		end
	end
	lines[ride] = made
	return made
end

-- Yards of a ride still ahead from point `at` of stretch `k`.
local function Ahead(made, k, at)
	local stretch = made[k]
	local yards = stretch.along[stretch.n] - stretch.along[at]
	for later = k + 1, #made do yards = yards + made[later].along[made[later].n] end
	return yards
end

-- Yards a second the character has been carried over the last few looks, with which way (north, west).
local function Carried(now, world, north, west)
	trail[#trail + 1] = { now, world, north, west }
	while trail[1] and (now - trail[1][1] > HISTORY or trail[1][2] ~= world) do table.remove(trail, 1) end
	local first = trail[1]
	if not first or now - first[1] < 0.5 then return 0, 0, 0 end
	local dn, dw = north - first[3], west - first[4]
	local speed = math.sqrt(dn * dn + dw * dw) / (now - first[1])
	-- (Faster than anything sails or flies: a hearthstone, a portal. Reckoned afresh from here.)
	if speed > FASTEST then
		wipe(trail)
		trail[1] = { now, world, north, west }
		return 0, 0, 0
	end
	local own = GetUnitSpeed("player") or 0
	if issecretvalue(own) then own = 0 end
	return speed - own, dn, dw
end

local function Told()
	if trip then
		local look = aboard and T.RIDES[aboard.by] or T.RIDES.boat
		trip:Look(look.sign or "flight", look.color, look.word)
		trip:Update()
	end
	Shy:Fire("SHY_RIDE", aboard)
end

-- Riding, kept for the character so a reload in the tram still knows which ride it is.
local function Saved()
	local saved = T.Saved()
	saved.riding = saved.riding or {}
	return saved.riding
end

-- When the character came to stand at each stop a ride leaves from (AT_DOCK yards), while they stay by it
-- (LEFT_DOCK): the wait for a ride counts from there.
local docked = {}

local function Docks(now, world, north, west)
	for _, ride in ipairs(T.Rides()) do
		local stop = ride.from
		if ride.line and stop.world == world then
			local yards = math.sqrt((stop.north - north) ^ 2 + (stop.west - west) ^ 2)
			if yards <= AT_DOCK then
				docked[stop] = docked[stop] or now
			elseif yards > LEFT_DOCK then
				docked[stop] = nil
			end
		end
	end
end

-- Standing on a deck at the dock the ride is sure. Carried, it is sure once the character has gone CONFIRM
-- yards along its line (Follow): a step or a stumble at a dock's end is no ride, and no one is told of it.
local function Start(ride, k, at, now, sailing, world, north, west, carried)
	local made = Line(ride)
	aboard = { by = ride.by, from = ride.from, to = ride.to, key = ride.key, ride = ride, line = made,
		k = k, at = at, since = now, seen = now, sailed = sailing and now or nil, docked = docked[ride.from] or now,
		sure = not sailing, began = at, beganOn = k, fromStart = k == 1 and made[1] ~= nil and made[1].along[at] <= FROM_START }
	Note(("start %s, stretch %d point %d, %s%s"):format(ride.key, k, at, sailing and "carried" or "decked",
		aboard.sure and "" or " (not sure yet)"), world, north, west, carried)
	if aboard.sure then Told() end
end

local function End(now, why, world, north, west, carried)
	-- Ridden from its dock to its end and off: how long that took is kept, from the dock with the wait, and
	-- aboard. (Never from a ride joined short of its end: that time would be no ride's.)
	local made = aboard.line
	if aboard.sure and aboard.sailed and aboard.fromStart and made and aboard.k == #made and Ahead(made, aboard.k, aboard.at) <= ENDS then
		local landed = aboard.landed or now
		T.Kept(aboard.ride, landed - aboard.docked)
		T.Kept(aboard.ride, landed - aboard.sailed, true)
	end
	Note(("end %s: %s"):format(aboard.key or "?", why or "?"), world, north, west, carried)
	docked[aboard.from] = nil
	local told = aboard.sure
	aboard = nil
	if told then Told() end
end

-- Which ride's line the character at (north, west) on `world` is on: the one that leads to its end soonest
-- from there, of those that don't end here (and, carried, of those that run the way they go). Standing
-- on open water (decked), only a boat's, and only within a ship's length of where it halts: a pier's end
-- stands over water too, and no one stands on open water under a zeppelin.
local function Which(world, north, west, dn, dw, decked)
	local best, bestK, bestAt, bestYards
	for _, ride in ipairs(T.Rides()) do
		local deck = not decked or (ride.by == "boat" and ride.from.world == world
			and math.sqrt((ride.from.north - north) ^ 2 + (ride.from.west - west) ^ 2) <= AT_DECK)
		if ride.line and deck then
			local made = Line(ride)
			for k, stretch in ipairs(made) do
				if stretch.continent == world then
					local at, away = Maps.Nearest(stretch, north, west)
					if away <= ON_LINE then
						local yards = Ahead(made, k, at)
						local nextAt = math.min(at + 1, stretch.n)
						local along = (stretch.north[nextAt] - stretch.north[at]) * dn + (stretch.west[nextAt] - stretch.west[at]) * dw
						if yards > ENDS and along >= 0 and (not bestYards or yards < bestYards) then
							best, bestK, bestAt, bestYards = ride, k, at, yards
						end
					end
				end
			end
		end
	end
	return best, bestK, bestAt
end

-- Whether a place is within NEAR yards of a ride's line or stop (a ride begins nowhere else): by patches of
-- PATCH yards, marked once for the rides there are, each patch a line or a stop is in with those round it.
local patches, patchesFor = {}, nil
local function Patch(world, north, west)
	return world * 2 ^ 40 + (math.floor(north / PATCH) + 2 ^ 19) * 2 ^ 20 + math.floor(west / PATCH) + 2 ^ 19
end
local function Near(world, north, west)
	local rides = T.Rides()
	if patchesFor ~= rides then
		patchesFor = rides
		wipe(patches)
		local round, prev = math.ceil(NEAR / PATCH), nil
		local function Mark(on, n, w)
			local here = Patch(on, n, w)
			if here == prev then return end
			prev = here
			for dr = -round, round do
				for dc = -round, round do patches[here + dr * 2 ^ 20 + dc] = true end
			end
		end
		for _, ride in ipairs(rides) do
			for _, stop in ipairs({ ride.from, ride.to }) do
				if stop and stop.world then Mark(stop.world, stop.north, stop.west) end
			end
			for _, stretch in ipairs(Line(ride)) do
				for i = 1, stretch.n do Mark(stretch.continent, stretch.north[i], stretch.west[i]) end
			end
		end
	end
	return patches[Patch(world, north, west)] == true
end

-- Following the ride being taken: onto its stretch on this world, onward along it.
local function Follow(now, world, north, west, carried)
	local made = aboard.line
	-- (Through a loading screen onto another world: onto the line's stretch there, from wherever on it.)
	if made[aboard.k].continent ~= world then
		for k = aboard.k + 1, #made do
			if made[k].continent == world then
				aboard.k, aboard.at = k, nil
				Note(("onto stretch %d"):format(k), world, north, west, carried)
				Told()
				break
			end
		end
	end
	local stretch = made[aboard.k]
	local away = math.huge
	if stretch.continent == world then
		local from = aboard.at or 1
		aboard.at, away = Maps.Nearest(stretch, north, west, from, aboard.at and math.min(stretch.n, from + SEEK) or stretch.n)
		-- (Through a loading screen that stays on this world, where a line jumps within it, as the zeppelin
		-- between Grom'gol and the Undercity does: onto its next stretch, from wherever on it.)
		local later = away > OFF_LINE and made[aboard.k + 1]
		if later and later.continent == world then
			local at, far = Maps.Nearest(later, north, west)
			if far <= OFF_LINE then
				aboard.k, aboard.at, away, stretch = aboard.k + 1, at, far, later
				Note(("onto stretch %d"):format(aboard.k), world, north, west, carried)
				Told()
			end
		end
	end
	if away > OFF_LINE then
		if not aboard.off then
			aboard.off = now
			Note(("off the line, %.0f yards"):format(away == math.huge and -1 or away), world, north, west, carried)
		end
		if now - aboard.off >= OFF_FOR then End(now, "off the line for " .. OFF_FOR .. " s", world, north, west, carried) end
		return
	end
	aboard.off = nil
	if not aboard.sure then
		-- (Noticed carried: a ride once carried CONFIRM yards along its line; a step at a dock's end is dropped.)
		if carried < CARRIED then return End(now, "not carried on: no ride", world, north, west, carried) end
		local gone = aboard.k > aboard.beganOn and math.huge or stretch.along[aboard.at] - stretch.along[aboard.began]
		if gone < CONFIRM then return end
		aboard.sure = true
		Note(("sure: carried %.0f yards along"):format(gone == math.huge and 0 or gone), world, north, west, carried)
		Told()
	end
	-- (Landed and carried off again, still aboard: that is the next ride, looked for afresh.)
	if aboard.landed and carried >= CARRIED then return End(now, "landed and carried on", world, north, west, carried) end
	if carried >= CARRIED and not aboard.sailed then
		aboard.sailed = now
		Note("set off", world, north, west, carried)
		Told()
	end
	-- (At its end: landed, though the character may stay aboard a while. Walked off it, onto the pier or
	-- the tower, the ride is over at once: OFF_DECK yards from where it halts, moving on their own.)
	if aboard.k == #made and Ahead(made, aboard.k, aboard.at) <= ENDS and not aboard.landed then
		aboard.landed = now
		Note("landed", world, north, west, carried)
	end
	if aboard.landed and carried < CARRIED and stretch.continent == world then
		local far = math.sqrt((stretch.north[stretch.n] - north) ^ 2 + (stretch.west[stretch.n] - west) ^ 2)
		if far > OFF_DECK then return End(now, ("walked off, %.0f yards from the halt"):format(far), world, north, west, carried) end
		-- (Still by the halt long after any halt lasts: it left without them.)
		if now - aboard.landed >= STAYED then End(now, "landed " .. STAYED .. " s ago and not carried since", world, north, west, carried) end
	end
end

-- The tram -------------------------------------------------------------------------------------------

local function InTram()
	local tram = T.data.transit and T.data.transit.tram
	if not tram then return false end
	local id = select(8, GetInstanceInfo())
	if id == nil or issecretvalue(id) then return false end
	return id == tram.map
end

-- The tram ride by its key, or the one from the door nearest a place (within DOOR yards).
local function TramRide(key, place)
	local best, least
	for _, ride in ipairs(T.Rides()) do
		if ride.by == "tram" then
			if key and ride.key == key then return ride end
			if place and ride.from.world == place.world then
				local yards = math.sqrt((ride.from.north - place.north) ^ 2 + (ride.from.west - place.west) ^ 2)
				if yards <= DOOR and (not least or yards < least) then best, least = ride, yards end
			end
		end
	end
	return best
end

-- The tram ride on the journey the player follows (T.Following), if any.
local function Followed()
	local journey = T.Following()
	for index = 1, journey and journey.n or 0 do
		if journey[index].by == "tram" then return TramRide(journey[index].ride) end
	end
end

local function Board()
	local who = UnitGUID("player") or "?"
	local saved = Saved()[who]
	local ride, entered
	if type(saved) == "table" and saved.key and type(saved.at) == "number" then ride, entered = TramRide(saved.key), saved.at end
	if not ride then
		ride = TramRide(nil, last) or Followed()
		entered = time()
	end
	Saved()[who] = { key = ride and ride.key, at = entered }
	-- (GetTime runs smoothly; time() outlives a reload.)
	aboard = { by = "tram", ride = ride, key = ride and ride.key, from = ride and ride.from, to = ride and ride.to,
		since = GetTime() - (time() - entered), tram = true, sure = true }
	Told()
end

local function Alight()
	if aboard.ride then out = { ride = aboard.ride, took = GetTime() - aboard.since, at = GetTime() } end
	aboard = nil
	Saved()[UnitGUID("player") or "?"] = nil
	Told()
end

-- Out of the tram at the far door: how long it took is kept.
local function Arrived(world, north, west)
	if not out then return end
	local door = out.ride.to
	if world == door.world and math.sqrt((north - door.north) ^ 2 + (west - door.west) ^ 2) <= ARRIVED then
		T.Kept(out.ride, out.took)
		out = nil
	elseif GetTime() - out.at > SETTLE then
		out = nil
	end
end

-- Looking ---------------------------------------------------------------------------------------------

local function Watch()
	local now = GetTime()
	if InTram() then
		if not aboard then Board() end
		return
	end
	if aboard and aboard.tram then Alight() end
	if UnitOnTaxi("player") or UnitIsDeadOrGhost("player") then
		wipe(trail)
		if aboard then End(now, UnitOnTaxi("player") and "on a flight" or "dead") end
		return
	end
	local world, north, west = Position()
	if not world then
		-- (The loading screen of a ride onto another world, or anywhere the game won't say where the
		-- character is: the ride goes on, and is followed again where the game says.)
		wipe(trail)
		if aboard and not aboard.lost then
			aboard.lost = true
			Note("nowhere: no place from the game")
		end
		if aboard and now - (aboard.seen or now) > LOST then End(now, "nowhere for " .. LOST .. " s") end
		return
	end
	last = last or {}
	last.world, last.north, last.west = world, north, west
	Arrived(world, north, west)
	-- (Far from every ride: none begins here, and none was waited for.)
	near = aboard ~= nil or Near(world, north, west)
	if not near then
		wipe(trail)
		wipe(docked)
		return
	end
	if not aboard then Docks(now, world, north, west) end
	if aboard then
		if aboard.lost then Note("a place again", world, north, west) end
		aboard.seen, aboard.lost = now, nil
	end
	local carried, dn, dw = Carried(now, world, north, west)
	speed = carried
	if aboard then
		-- (Over the side: no one swims on a deck. Falling longer than a jump on deck lasts: jumped off.)
		if IsSwimming() then return End(now, "swimming", world, north, west, carried) end
		if IsFalling() then
			aboard.fell = aboard.fell or now
			if now - aboard.fell >= FALLING then return End(now, "falling", world, north, west, carried) end
		else
			aboard.fell = nil
		end
		return Follow(now, world, north, west, carried)
	end
	-- (A jump or a fall carries no one aboard: off a tower's edge or a pier's end is not a ride.)
	if IsFalling() then return end
	local moving = carried >= CARRIED
	local decked = not moving and not IsSwimming() and T.Water(world, north, west) == true
	if not moving and not decked then return end
	local ride, k, at = Which(world, north, west, moving and dn or 0, moving and dw or 0, decked)
	if ride then Start(ride, k, at, now, moving, world, north, west, carried) end
end

function T.Riding()
	if aboard and aboard.sure then return aboard end
	return nil
end

-- The ride being taken and what was noticed lately, as the task manager's counters under this addon.
local function Ago(now, at)
	return at and ("%.0f s ago"):format(now - at) or "no"
end
if Shy.Counters then Shy.Counters("Rides", function(row)
	local now = GetTime()
	local world, north, west = Position()
	row("Where", ("%s, %s on world %s"):format(north and ("%.0f"):format(north) or "?", west and ("%.0f"):format(west) or "?", tostring(world)))
	row("Carried, yards a second", speed)
	row("Swimming", IsSwimming() and "yes" or "no")
	row("Falling", IsFalling() and "yes" or "no")
	row("On a flight", UnitOnTaxi("player") and "yes" or "no")
	if aboard then
		local made = aboard.line
		local stretch = made and made[aboard.k]
		row("Aboard", ("%s (%s to %s)"):format(aboard.key or "?", aboard.by, aboard.to and aboard.to.name or "?"))
		row("Stretch", ("%s of %s on world %s"):format(tostring(aboard.k), tostring(made and #made), tostring(stretch and stretch.continent)))
		row("Point", ("%s of %s, %.0f yards ahead"):format(tostring(aboard.at), tostring(stretch and stretch.n),
			made and stretch and Ahead(made, aboard.k, aboard.at or 1) or 0))
		row("Since", ("%.0f s; set off %s; landed %s; off the line %s; docked %.0f s before"):format(now - aboard.since,
			Ago(now, aboard.sailed), Ago(now, aboard.landed), Ago(now, aboard.off), aboard.since - (aboard.docked or aboard.since)))
		local label, left, share, said = T.RideLeft()
		row("Countdown", ("%s, %.0f s left, share %.2f, \"%s\""):format(tostring(label), left or 0, share or 0, tostring(said)))
	else
		row("Aboard", "nothing")
	end
	for i = #log, 1, -1 do
		local note = log[i]
		row(("%.1f s ago"):format(now - note[1]), ("%s  %s %s %s  %s"):format(note[2], tostring(note[3]),
			note[4] and ("%.0f"):format(note[4]) or "-", note[5] and ("%.0f"):format(note[5]) or "-",
			note[6] and ("%.1f"):format(note[6]) or "-"))
	end
end) end

function T.RideLeft()
	if not aboard or not aboard.sure then return nil end
	if not aboard.ride then
		-- (Into the tram with nothing to say where from: how long so far.)
		return "Deeprun Tram", 0, 0, Clock(GetTime() - aboard.since) .. " so far"
	end
	local look = T.RIDES[aboard.by] or T.RIDES.boat
	local label = look.word .. " to " .. (aboard.to.name or "")
	local whole, sure = T.RideSeconds(aboard.ride)
	if aboard.tram then
		local left = whole - (GetTime() - aboard.since)
		-- Past its time the tram has come in: nothing is left to count, and standing on the platform (or
		-- at someone down there) says nothing of a ride at all.
		if left <= 1 then return nil end
		return label, left, math.min(1, left / whole), (sure and "" or "about ") .. Clock(left)
	end
	-- (A boat's: the time aboard, the wait gone once it sets off. Landed, it stays landed.)
	if aboard.landed then return label, 0, 0, "landed" end
	local made = aboard.line
	whole, sure = T.RideSeconds(aboard.ride, true)
	if not whole or not made or made.yards <= 0 then return label, 0, 0, "aboard" end
	local left = Ahead(made, aboard.k, aboard.at or 1) * whole / made.yards
	-- (At the dock it holds still: the time is the whole ride until it sets off.)
	if left <= 1 then return label, 0, 0, "landing" end
	return label, left, math.min(1, left / whole), (sure and "" or "about ") .. Clock(left)
end

-- Where a flight lands, on a zone map: the continent's map up from the player's own, and on it the zone the
-- place is in. Worked out once a landing.
local landed = {}

local function FlightLanding()
	local world, north, west = T.Flight.Landing()
	if not world then return nil end
	local key = world .. ":" .. north .. ":" .. west
	if landed.key == key then return landed.place end
	landed.key, landed.place = key, T.Place(world, north, west)
	local map = C_Map.GetBestMapForUnit("player")
	local info = map and C_Map.GetMapInfo(map)
	while info and info.mapType ~= Enum.UIMapType.Continent and info.parentMapID and info.parentMapID > 0 do
		info = C_Map.GetMapInfo(info.parentMapID)
	end
	if info and info.mapType == Enum.UIMapType.Continent then
		local vector = CreateVector2D(north, west)
		local _, spot = C_Map.GetMapPosFromWorldPos(world, vector, info.mapID)
		local zone = spot and C_Map.GetMapInfoAtPosition(info.mapID, spot:GetXY())
		local zoneMap = zone and zone.mapID or info.mapID
		local _, there = C_Map.GetMapPosFromWorldPos(world, vector, zoneMap)
		if there then landed.place.map, landed.place.x, landed.place.y = zoneMap, there:GetXY() end
	end
	return landed.place
end

function T.Landing()
	if aboard and aboard.sure then return aboard.to end
	if UnitOnTaxi("player") then return FlightLanding() end
	return nil
end

-- What the maps show: the stretch on the character's world, from where they are on it to where it ends.
-- (Asked every frame, from where they were last seen on it: never a point passed since the last look.)
local function TripLine(world, north, west)
	if not aboard or not aboard.sure or not aboard.line then return nil end
	local stretch = aboard.line[aboard.k]
	if not stretch or stretch.continent ~= world then return nil end
	local from = aboard.at or 1
	local at = Maps.Nearest(stretch, north, west, from, aboard.at and math.min(stretch.n, from + SEEK) or stretch.n)
	return stretch, math.min(at + 1, stretch.n), stretch.n
end

Shy:On("SHY_LOGIN", function()
	if Maps and Maps.Trip then
		local look = T.RIDES.boat
		trip = Maps.Trip({ color = look.color, sign = look.sign, strip = look.word, Line = TripLine, Left = T.RideLeft,
			To = function() return aboard and aboard.to and aboard.to.name end, aboard = true })
	end
	-- The game tells no move of a place, so the character is looked at: every EVERY seconds aboard, in the
	-- tram or within NEAR yards of a ride's line or stop, where a ride can begin; else every FAR seconds.
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	local due = 0
	local function Look()
		local ok, err = pcall(Watch)
		if not ok then geterrorhandler()(err) end
		due = (aboard or out or near) and 0 or GetTime() + FAR
	end
	events:SetScript("OnEvent", Look)
	C_Timer.NewTicker(EVERY, Shy.Clocked("ride: a look", function()
		if GetTime() >= due then Look() end
	end))
end)
