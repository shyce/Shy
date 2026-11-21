-- Flight points as part of the route. A flight master nearby or on the way, whose point the character
-- doesn't have yet, is a stop with or without a guide. A guide's own "get the flight path" steps count
-- as done while this is loaded (Guide.lua), because this file sends you for flight points.
--   Known points: ShyWay's (Shy.Way.Flights, by node), learned from the flight map whenever one opens
--     and when the game says a flight path was found beside one. Until a flight map has opened for the
--     character, the nearest flight master is asked to be talked to once, so they are all learned.

local ADDON, ns = ...
local T = ns.T
local W, R = ns.World, ns.Route

local Flights = {}
ns.Flights = Flights

T.defaults.flights = { on = true }    -- flight masters as stops on the card

local LISTED = 600           -- yards: a flight master this near gets a row though it is off the way
local WORDS = {
	unread = {
		title = "Talk to the flight master: %s",
		line = "Talk to them once so the guide knows your flight paths",
		caption = "FLIGHT PATHS  \194\183  NOT KNOWN YET",
		tip = "Until then the guide won't plan flights for you here.",
	},
	new = {
		title = "Get the flight path: %s",
		line = "You don't have this one yet",
		caption = "FLIGHT POINT  \194\183  NEW TO YOU",
		tip = "Talk to the flight master to learn it.",
	},
	maybe = {
		title = "Get the flight path: %s",
		line = "You may have it. Your flight map can't reach it",
		caption = "FLIGHT POINT  \194\183  MAYBE NEW",
		tip = "Talk to the flight master to learn it, or to show the guide you have it.",
	},
}

-- This character's flight points left alone, by the point's key.
local function Skipped()
	ns.char.noFlights = ns.char.noFlights or {}
	return ns.char.noFlights
end

-- The nearest flight point the character lacks: the point, its flight master ({ npc, map, x, y })
-- and how far it is.
local function Missing()
	local known, skipped = Shy.Way.Flights(), Skipped()
	local best, master, least
	for _, point in ipairs(R.FlightPoints()) do
		if point.continent == W.continent and not known[point.node] and not skipped[point.key] then
			local yards = W.Between(W.north, W.west, point.north, point.west)
			local at = (not least or yards < least) and R.FlightMaster(point)
			if at then best, master, least = point, at, yards end
		end
	end
	return best, master, least
end

-- The flight master as a route errand (R.AddErrand), or nil.
local function Find(lead)
	if not T.db.flights.on or not ns.char or not W.Known() then return nil end
	local point, at, yards = Missing()
	if not point then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local passing = not busy and R.Passing("flightpath", at.map, at.x, at.y, lead)
	if not passing and yards > LISTED then return nil end
	-- What the guide knows of this point: your flight points here not read yet (any flight master teaches
	-- them all), surely new, or maybe yours already (cut off from the points your map reached).
	local words = not Shy.Way.FlightsRead(W.continent) and WORDS.unread or Shy.Way.FlightNew(point.node) and WORDS.new
		or WORDS.maybe
	return {
		title = words.title:format(point.town),
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name, words.line },
		caption = words.caption,
		mark = "flight",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		first = passing or nil,
		tip = function(tip) tip:AddLine(words.tip, 0.6, 0.6, 0.6, true) end,
		menu = function(root)
			if words ~= WORDS.unread then
				root:CreateButton("Not this one", function()
					Skipped()[point.key] = true
					ns.Refresh()
				end)
			end
			root:CreateButton("Stop asking about flight points", function()
				T.db.flights.on = false
				ns.Apply()
			end)
		end,
	}
end

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Flight paths along the way", function() return T.db.flights.on end, function()
		T.db.flights.on = not T.db.flights.on
		ns.Apply()
	end)
end)

R.AddErrand("flightpath", Find, "New flight paths")
-- To ask for: the nearest flight point the character lacks.
R.AddOffer("flightpath", function()
	local point = T.db.flights.on and ns.char and W.Known() and Missing()
	return point and { { text = "Flight master: " .. point.town } } or {}
end)
