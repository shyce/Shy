-- Shy.Way while ShyWay is off: the same questions, and "not known" for every answer.
--
-- ShyWay puts its own table here when it loads. An addon that asks the way, times a trip or draws one
-- asks Shy.Way and never needs to know which of the two it holds: nil is "not known", as ShyWay's own
-- answers are where the ground isn't known, so whoever asks falls back on the straight line. Lists are
-- empty, nothing is kept, and SHY_TERRAIN, SHY_FLIGHT and SHY_RIDE are never sent.
--
-- Shy.Way.missing is true here and nil in ShyWay's: for what only makes sense with ShyWay there (one of
-- its settings, or handing it something kept before it kept it, which would be lost here).

local function Nothing(...) return nil end
local function Ignored(...) end
local function Empty(...) return {} end

Shy.Way = {
	missing = true,
	GROUND = 0, UNDER = 1, ABOVE = 2, NOWHERE = 3,
	data = {},
	RIDES = {},

	-- On foot
	Has = function(...) return false end,
	Ask = Nothing,
	AskWay = Nothing,
	Without = Nothing,
	With = Nothing,
	Levels = Nothing,
	Water = Nothing,
	Up = Nothing,
	Moves = function(...) return 0, nil, false, nil, 0, nil end,
	Paths = Nothing,
	SetPaths = Ignored,
	-- (A runner's pace: who rides is ShyWay's to notice.)
	Pace = function(...) return 7, false end,
	Paced = function(seconds) return seconds end,
	SetPace = Ignored,
	Roads = function(...) return false end,
	SetGuess = Ignored,
	Mark = function(into)
		into.tiles, into.inflates, into.floorMs, into.step = 0, 0, 0, 0
		return into
	end,

	-- Journeys
	Place = function(world, north, west, opts)
		local place = { world = world, north = north, west = west }
		if opts then place.up, place.level, place.name = opts.up, opts.level, opts.name end
		return place
	end,
	OnMap = Nothing,
	Here = Nothing,
	Journey = Nothing,
	Follow = Ignored,
	Following = Nothing,
	Flights = Empty,
	KnowsFlight = function(...) return false end,
	FlightsRead = function(...) return false end,
	FlightNew = function(...) return false end,
	CanFly = Nothing,
	Learn = Ignored,
	Rides = Empty,
	Stops = Empty,
	RideSeconds = Nothing,

	-- Trails
	Trail = Nothing,
	Trailed = Nothing,
	Trailing = function(...) return false end,
	Along = Nothing,

	-- Rides and flights
	Riding = Nothing,
	RideLeft = Nothing,
	Landing = Nothing,
	Flight = {
		Now = Nothing,
		Left = Nothing,
		Line = Nothing,
		Landing = Nothing,
		Offer = Nothing,
		Route = Nothing,
		Path = Nothing,
		Adopt = Ignored,
	},

	-- Places shared as suggested routes: none come, none go.
	Share = {
		On = function(...) return false end,
		SetOn = Ignored,
		Pin = Nothing,
		Here = Nothing,
		Send = Nothing,
		Targets = Empty,
		Write = Nothing,
		Offers = Empty,
		Accept = function(...) return false end,
		Decline = function(...) return false end,
		Away = Nothing,
		Color = Nothing,
		Ping = Nothing,
		Pings = Empty,
		Lead = function(...) return false end,
	},
}
