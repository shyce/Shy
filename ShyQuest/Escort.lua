-- Escorts: quests where you walk someone somewhere (Data\ByHand.lua's `escort`; D.Escort).
-- An escort starts the moment you accept it, so you want to know about it before that:
--
--   how long it takes     timed from accepting it to finishing it, like a flight, and saved for the
--                         account (T.db.escorts.runs). Until one is timed, it is estimated from the
--                         distance between the NPC and where the walk ends, at walking speed, at
--                         the pace the timed ones kept (Pace)
--   where they walk       the way your character went beside them, thinned to a few points. Until
--                         one is walked, a straight line from the NPC to where the walk ends
--
-- The card's leading row gives the time under an escort to accept (ns.cardNotes). The card counts
-- down while you walk one (Running; Card.lua asks). The maps draw the way for every pin that stands
-- for one (Walker; Pins.lua draws it like anyone who walks). While you walk one, the minimap and
-- the world map show the way still ahead as a journey, like a flight's (Shy.Maps.Trip): in the
-- escort's lime under its face, with the time left at its end. Share puts the walk in the chat box.
--
-- The way drawn is the first of these that exists:
--   1. the path the escorted NPC is scripted to take (Data\EscortWays.lua), which is where it walks
--   2. the one walked here, told by another copy, or shipped with the addon (Data\Escorts.lua)
--   3. a straight line from the NPC to where the walk ends
-- The time is the timed one (walked, told or shipped), otherwise estimated along that same way.
--
-- What one copy has timed, every copy can have. A copy tells its group and guild a record once,
-- when it is made. A copy with nothing for an upcoming escort asks once per session. One holder
-- answers after a short random wait, unless another has answered by then. A record is one addon message:
--
--   E1 <tab> quest <tab> tenths of a second <tab> runs <tab> map <tab> the way     a record
--   E? <tab> quest                                                               who has this one?
--
-- The way: four characters per point, x then y, each as its 0-9999 in two base-71 digits (PACK).
-- Records shipped with the addon (Data\Escorts.lua, when there is one) rank behind the account's.

local ADDON, ns = ...
local T = ns.T
local D, L, W, R = ns.Data, ns.Log, ns.World, ns.Route

local Escort = {}
ns.Escort = Escort

local UNITS = 10000
local WALK = 2.5             -- yards a second: an escort walks
local WINDING = 1.25         -- a way is this much longer than the straight line between its ends
local FIGHTS = 1.4           -- seconds an escort takes per second of walking, until some are timed
local NEAR = 150             -- yards from who is walked within which accepting it is the start of the walk
local STEP = 12              -- yards between two points kept of the way
local MOST = 40              -- points a kept way has at most
local FINE = 6               -- yards a kept way may stray from the one walked (doubled until it fits MOST)
local SHORTEST, LONGEST = 15, 3600   -- seconds: outside these it was no escort
local RUNS = 5               -- a time kept is the mean of this many runs at most
local LOST = 10              -- seconds after accepting within which the quest must be in the log
local ASK_GAP = 5            -- seconds between two questions sent
local ASKS = 20              -- questions sent in a session at most
local ANSWER_WAIT = 4        -- an answer waits one second and up to this many more, for another's
local TOLD_RECENTLY = 60     -- seconds a record just told on a channel is not told again
local BEND = 6               -- yards: a journey's way is smoothed in pieces no longer than this
local SEEK = 60              -- points of it looked over past the last one passed
local STRAYED = 40           -- yards off the way from which the whole rest of it is looked over

local PACK = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+"
local BASE = #PACK
local DIGIT = {}
for i = 1, BASE do DIGIT[PACK:byte(i)] = i - 1 end

local function Clock(seconds)
	return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

-- The way as text, and back
local function Pack(points)
	local out = {}
	for i, value in ipairs(points) do
		local half = math.floor(math.max(0, math.min(UNITS - 1, value)) / 2)
		out[i] = PACK:sub(math.floor(half / BASE) + 1, math.floor(half / BASE) + 1) .. PACK:sub(half % BASE + 1, half % BASE + 1)
	end
	return table.concat(out)
end

-- nil for text that is no way.
local function Unpack(text)
	if type(text) ~= "string" or #text < 8 or #text % 4 ~= 0 or #text > MOST * 4 then return nil end
	local points = {}
	for at = 1, #text, 2 do
		local high, low = DIGIT[text:byte(at)], DIGIT[text:byte(at + 1)]
		if not high or not low then return nil end
		points[#points + 1] = (high * BASE + low) * 2
	end
	return points
end

-- Where one starts and ends
-- Who is walked: map, x, y, name. An escort inside a dungeon has no place on a map.
local function Start(id)
	local quest = D.Quest(id)
	for _, token in ipairs(quest and quest.starts or {}) do
		local npc = token.kind == "n" and D.Npc(token.id)
		local place = npc and npc.places[1]
		if place and place.points[1] and not place.dungeon then return place.map, place.points[1], place.points[2], npc.name end
	end
end

-- Where the walk ends, on `map` when given: the place the quest is done at.
local function End(id, map)
	local quest = D.Quest(id)
	for _, place in ipairs(quest and quest.trigger or {}) do
		if place.points[1] and (not map or place.map == map) then return place.map, place.points[1], place.points[2] end
	end
end

-- Yards from who is walked to where the walk ends, as the crow flies; nil where the data lacks either.
local function Yards(id)
	local map, x, y = Start(id)
	local endMap, endX, endY = End(id, map)
	if not map or not endMap then return nil end
	local continent, north, west = W.ToWorld(map, x, y)
	local endContinent, endNorth, endWest = W.ToWorld(endMap, endX, endY)
	if not continent or continent ~= endContinent then return nil end
	return W.Between(north, west, endNorth, endWest)
end

-- What is kept
local shipped = {}           -- quest -> the record that came with the addon, or false
local walkers = {}           -- quest -> who the maps draw the way of (Walker), or false
local journeys = {}          -- quest -> the way in the world as a journey's line (Journey), or false
local trip                   -- what the maps show of the one being walked (Shy.Maps.Trip)
local stamp = 0              -- changes with what is kept

-- The path the escorted NPC is scripted to take, in the world: { continent, flat = { north, west, ... },
-- yards, wait (seconds it stands still on the way) }; nil where none came with the addon. Its text is
-- "wait continent north west north west ...", whole yards. Other paths (ns.data.escortWays made anew)
-- forget what was made of the old ones.
local scripted, scriptedFrom = {}, nil
local function Scripted(id)
	if ns.data.escortWays ~= scriptedFrom then
		scriptedFrom = ns.data.escortWays
		wipe(scripted)
		wipe(walkers)
		wipe(journeys)
		stamp = stamp + 1
	end
	local way = scripted[id]
	if way == nil then
		way = false
		local text = ns.data.escortWays and ns.data.escortWays[id]
		local wait, continent, numbers = (text or ""):match("^(%d+) (%d+) (.+)$")
		if numbers then
			local flat = {}
			for value in numbers:gmatch("%-?%d+") do flat[#flat + 1] = tonumber(value) end
			if #flat >= 4 and #flat % 2 == 0 then
				local yards = 0
				for i = 3, #flat - 1, 2 do yards = yards + W.Between(flat[i - 2], flat[i - 1], flat[i], flat[i + 1]) end
				way = { continent = tonumber(continent), flat = flat, yards = yards, wait = tonumber(wait) }
			end
		end
		scripted[id] = way
	end
	return way or nil
end

-- Seconds of walking from who is walked to where the walk ends, before any fight: along the scripted
-- path with its waits, else the straight line and a quarter more for the road. nil where neither is known.
local function Reckoned(id)
	local way = Scripted(id)
	if way then return way.yards / WALK + way.wait end
	local yards = Yards(id)
	return yards and yards * WINDING / WALK or nil
end

local function Runs()
	local db = T.db and T.db.escorts
	return db and db.runs
end

local function Shipped(id)
	local record = shipped[id]
	if record == nil then
		local text = ns.data.escorts and ns.data.escorts[id]
		local tenths, runs, map, way = (text or ""):match("^(%d+) (%d+) (%d+) ?(%S*)$")
		record = tenths and { s = tonumber(tenths) / 10, n = tonumber(runs), m = tonumber(map), p = way ~= "" and way or nil } or false
		if record and not (record.p and Unpack(record.p)) then record.m, record.p = nil, nil end
		shipped[id] = record
	end
	return record or nil
end

-- A quest's record: { s seconds, n runs, m map and p the way (or neither), mine: timed on this account }.
function Escort.Record(id)
	local runs = Runs()
	return runs and runs[id] or Shipped(id)
end

local function Changed()
	stamp = stamp + 1
	wipe(walkers)
	wipe(journeys)
	if trip then trip:Update() end
	ns.Refresh()
end

-- Measured seconds per reckoned second.
local function Pace()
	local db = T.db.escorts
	if not db or db.reckoned <= 0 then return FIGHTS end
	return math.min(3, math.max(0.6, db.timed / db.reckoned))
end

-- Returns seconds, timed; nil where nothing is known.
function Escort.Seconds(id)
	local record = Escort.Record(id)
	if record then return record.s, true end
	local walking = Reckoned(id)
	if walking then return walking * Pace(), false end
end

-- "Escort: 3:12", "Escort: about 3 min", or the word alone.
function Escort.Says(id)
	local seconds, timed = Escort.Seconds(id)
	if not seconds then return "Escort" end
	if timed then return "Escort: " .. Clock(seconds) end
	return ("Escort: about %d min"):format(math.max(1, math.floor(seconds / 60 + 0.5)))
end

-- The way, in the places format (Data.lua), and whether it is known: the scripted path on the map of
-- who is walked, else the one walked, else a straight line.
function Escort.Path(id)
	local way = Scripted(id)
	local map, x, y = Start(id)
	if way and map then
		local points = {}
		for i = 1, #way.flat - 1, 2 do
			local px, py = Shy.Maps.ToMap(map, way.continent, way.flat[i], way.flat[i + 1])
			if px then
				points[#points + 1] = math.floor(px * UNITS + 0.5)
				points[#points + 1] = math.floor(py * UNITS + 0.5)
			end
		end
		if #points >= 4 then return { { map = map, points = points } }, true end
	end
	local record = Escort.Record(id)
	local points = record and record.p and record.m and Unpack(record.p)
	if points then return { { map = record.m, points = points } }, true end
	local endMap, endX, endY = End(id, map)
	if map and endMap then return { { map = map, points = { x, y, endX, endY } } }, false end
end

-- The way in the world, smoothed as a journey's line (Shy.Maps.Smooth, with its continent): the
-- scripted path as it is, else the places of Path. nil where there is none.
local function Journey(id)
	local line = journeys[id]
	if line == nil then
		line = false
		local flat, continent = {}, nil
		local way = Scripted(id)
		if way then
			flat, continent = way.flat, way.continent
		else
			for _, stretch in ipairs(Escort.Path(id) or {}) do
				for i = 1, #stretch.points - 1, 2 do
					local c, north, west = W.ToWorld(stretch.map, stretch.points[i], stretch.points[i + 1])
					if c and (not continent or c == continent) then
						continent = c
						flat[#flat + 1] = north
						flat[#flat + 1] = west
					end
				end
			end
		end
		local smooth = continent and Shy.Maps.Smooth(flat, BEND)
		if smooth then
			smooth.continent = continent
			line = smooth
		end
		journeys[id] = line
	end
	return line or nil
end

-- An escort's way as someone who walks, for the maps (Pins.lua, Walkers): the same table until what
-- is kept changes. nil for any other quest, for an escort with no way to show, and for the one being
-- walked while the maps show it as a journey.
function Escort.Walker(id)
	if not D.Escort(id) then return nil end
	if trip and Escort.Walking() == id then return nil end
	local walker = walkers[id]
	if walker == nil then
		local path = Escort.Path(id)
		walker = path and { walk = true, path = path, escort = id } or false
		walkers[id] = walker
	end
	return walker or nil
end

-- Keeps a run. mine: timed here (it is averaged into what this account timed before, and feeds the
-- pace once); otherwise heard or handed on, which gives way to what was timed here and to a record
-- of more runs. way: packed, or nil. Returns whether anything changed.
local function Keep(id, seconds, runs, map, way, mine)
	local db = T.db.escorts
	local record = db.runs[id]
	if mine then
		local walking = Reckoned(id)
		if walking and not (record and record.mine) then
			db.timed, db.reckoned = db.timed + seconds, db.reckoned + walking
		end
		if record and record.mine then
			local before = math.min(record.n, RUNS - 1)
			record.s, record.n = (record.s * before + seconds) / (before + 1), before + 1
		else
			record = { s = seconds, n = 1, mine = true, m = record and record.m, p = record and record.p }
			db.runs[id] = record
		end
		if way then record.m, record.p = map, way end
	else
		local had = record or Shipped(id)
		if had and (had.mine or runs < had.n) then
			-- Only a way where there is none.
			if not way or had.p or not record then return false end
			record.m, record.p = map, way
		else
			db.runs[id] = { s = seconds, n = math.min(runs, RUNS), m = way and map or (had and had.m), p = way or (had and had.p) }
			record = db.runs[id]
		end
	end
	record.s = math.floor(record.s * 10 + 0.5) / 10
	Changed()
	return true
end

-- Telling and asking
local asked, asking, asks = {}, {}, 0    -- quests asked about this session; those still to ask; how many went
local lastAsk = 0
local answers = {}           -- quest -> { at, channel }: an answer waiting its turn
local told = {}              -- "quest channel" -> when a record was last told there, by anyone

local function Sharing()
	return T.db.party.share ~= false and not C_ChatInfo.InChatMessagingLockdown()
end

local function Channels()
	local out = {}
	if IsInRaid() then out[1] = "RAID" elseif IsInGroup() then out[1] = "PARTY" end
	if IsInGuild() then out[#out + 1] = "GUILD" end
	return out
end

local function Tell(id, channel)
	local record = Escort.Record(id)
	if not record or not Sharing() then return end
	local text = ("E1\t%d\t%d\t%d\t%d\t%s"):format(id, math.floor(record.s * 10 + 0.5), record.n, record.p and record.m or 0, record.p or "")
	for _, each in ipairs(channel and { channel } or Channels()) do
		T:SendComm(text, each)
		told[id .. " " .. each] = GetTime()
	end
end

-- Ask the others about an escort there is no walked way for (or, with its scripted path, no time):
-- once a session.
function Escort.Want(id)
	if asked[id] or not D.Escort(id) then return end
	local record = Escort.Record(id)
	if record and (record.p or Scripted(id)) then return end
	asked[id] = true
	asking[#asking + 1] = id
end

-- What waits to be sent, a piece a turn.
local function Send()
	local now = GetTime()
	for id, answer in pairs(answers) do
		if now >= answer.at then
			answers[id] = nil
			Tell(id, answer.channel)
		end
	end
	if asking[1] and now - lastAsk >= ASK_GAP then
		local channels = Channels()
		if asks >= ASKS or not Sharing() or not channels[1] then
			-- Nobody to ask: it may be asked again once there is.
			for _, id in ipairs(asking) do asked[id] = nil end
			wipe(asking)
			return
		end
		lastAsk, asks = now, asks + 1
		local id = table.remove(asking, 1)
		for _, channel in ipairs(channels) do T:SendComm("E?\t" .. id, channel) end
	end
end

local SHARED = { PARTY = true, RAID = true, GUILD = true }
Shy:On("SHY_COMM", function(addon, body, sender, channel)
	if addon ~= T or issecretvalue(body) or issecretvalue(channel) or not SHARED[channel] or Shy.IsMe(sender) then return end
	if not (T.db and T.db.escorts) or T.db.party.share == false then return end
	local id = tonumber(body:match("^E%?\t(%d+)$"))
	if id then
		local key = id .. " " .. channel
		if Escort.Record(id) and not answers[id] and GetTime() - (told[key] or -TOLD_RECENTLY) >= TOLD_RECENTLY then
			answers[id] = { at = GetTime() + 1 + math.random() * ANSWER_WAIT, channel = channel }
		end
		return
	end
	local quest, tenths, runs, map, way = body:match("^E1\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%S*)$")
	id = tonumber(quest)
	if not id or not D.Escort(id) then return end
	-- Someone has answered: no need to.
	answers[id] = nil
	told[id .. " " .. channel] = GetTime()
	local seconds = tonumber(tenths) / 10
	runs, map = tonumber(runs), tonumber(map)
	if seconds < SHORTEST or seconds > LONGEST or runs < 1 then return end
	if way == "" or map == 0 or not Unpack(way) then way = nil end
	Keep(id, seconds, runs, map, way, false)
end)

-- Walking one
local run                    -- { id, who, started, seconds, timed, map, north, west, x, y, rough, died, seen, along }
local DONE = 8               -- seconds the card keeps a walk just finished, beaming
local done                   -- { id, who, took, at }: the walk just finished, while the card shows it

local function Stop()
	run = nil
	ns.char.escort = nil
	if trip then trip:Update() end
	ns.Refresh()
end

-- The character's place on the run's map as a point of the way.
local function Point()
	if not W.Known() or not run.map then return end
	local x, y
	if W.map == run.map then
		x, y = W.x, W.y
	else
		local position = C_Map.GetPlayerMapPosition(run.map, "player")
		if position then
			local px, py = position:GetXY()
			if px > 0 or py > 0 then x, y = math.floor(px * UNITS + 0.5), math.floor(py * UNITS + 0.5) end
		end
	end
	if not x then return end
	local at = #run.north + 1
	run.north[at], run.west[at], run.x[at], run.y[at] = W.north, W.west, x, y
end

-- The way walked so far, a point every STEP yards. Dying on the way leaves it unkept: the walk back is
-- none of the escort's.
local function Sample()
	if not run or run.rough or run.died then return end
	if UnitIsDeadOrGhost("player") then
		run.died = true
		return
	end
	local last = #run.north
	if last >= 600 or not W.Known() then return end
	if last > 0 and W.Between(W.north, W.west, run.north[last], run.west[last]) < STEP then return end
	Point()
end

-- The points of the way worth keeping: those that leave it within `fine` yards of the one walked.
local function Thin(first, last, fine, keep)
	local an, aw, bn, bw = run.north[first], run.west[first], run.north[last], run.west[last]
	local dn, dw = bn - an, bw - aw
	local span = dn * dn + dw * dw
	local far, at = fine, nil
	for i = first + 1, last - 1 do
		local t = span > 0 and math.max(0, math.min(1, ((run.north[i] - an) * dn + (run.west[i] - aw) * dw) / span)) or 0
		local off = W.Between(run.north[i], run.west[i], an + dn * t, aw + dw * t)
		if off > far then far, at = off, i end
	end
	if at then
		Thin(first, at, fine, keep)
		keep[#keep + 1] = at
		Thin(at, last, fine, keep)
	end
end

-- The way walked, packed; nil for one too short to be a way.
local function Walked()
	local count = #run.north
	if count < 2 or W.Between(run.north[1], run.west[1], run.north[count], run.west[count]) < STEP and count < 4 then return nil end
	local fine, keep = FINE, nil
	repeat
		keep = { 1 }
		Thin(1, count, fine, keep)
		keep[#keep + 1] = count
		fine = fine * 2
	until #keep <= MOST
	local points = {}
	for _, at in ipairs(keep) do
		points[#points + 1] = run.x[at]
		points[#points + 1] = run.y[at]
	end
	return Pack(points)
end

local function Finish()
	local took = GetTime() - run.started
	local id = run.id
	if not run.rough and took >= SHORTEST and took <= LONGEST then
		local way
		if not run.died then
			Point()
			way = Walked()
		end
		Keep(id, took, 1, run.map, way, true)
		Tell(id)
	end
	done = { id = id, who = run.who, took = took, at = GetTime() }
	Stop()
end

-- rough: nothing is kept of this run (it began far from who is walked, or before a reload).
local function Begin(id, started, rough)
	local map, x, y, who = Start(id)
	local quest = D.Quest(id)
	local seconds, timed = Escort.Seconds(id)
	done = nil
	run = { id = id, who = who or (quest and quest.name) or "them", started = started or GetTime(), seconds = seconds, timed = timed,
		map = map or W.map, north = {}, west = {}, x = {}, y = {}, rough = rough }
	-- A quest that counts something too is done when that is, which says nothing of the walk.
	if quest and #quest.goals > 0 then run.rough = true end
	if not run.rough then
		local yards = map and W.Distance(map, x, y)
		if yards and yards <= NEAR then Point() else run.rough = true end
	end
	if not started then ns.char.escort = { id = id, at = time() } end
	if trip then trip:Update() end
	ns.Refresh()
end

-- After a route rebuild: whether the one being walked is done, failed or gone.
local function Check()
	if not run then return end
	local entry = L.entries[run.id]
	local gone = GetTime() - run.started
	if entry then run.seen = true end
	if entry and entry.failed then
		Stop()
	elseif entry and entry.complete then
		Finish()
	elseif (run.seen and not entry) or (not run.seen and gone > LOST) or gone > LONGEST then
		Stop()
	end
end

-- The escorts coming up: the ones to accept at the route's first stops.
local function Offered(stop)
	for _, action in ipairs(stop.actions or {}) do
		if action.kind == "pickup" and not action.failed and not action.held and D.Escort(action.id) then return action.id end
	end
	for _, line in ipairs(stop.view and stop.view.lines or {}) do
		if line.command == "accept" and line.id and not line.done and D.Escort(line.id) then return line.id end
	end
end

local AHEAD = 3
local function Wanted()
	for i = 1, math.min(AHEAD, #R.stops) do
		local id = Offered(R.stops[i])
		if id then Escort.Want(id) end
	end
	if run then Escort.Want(run.id) end
end

-- The card's countdown while one is walked: who is walked, seconds, share left, the words for the
-- time (GuideTimers' Running answers the same of a flight; the card's plate wears the escort's face, so
-- the name stands alone), and the face it wears (Marks.lua's cells): frazzled once past its time, and
-- beaming for a few seconds once done, with the time it took. nil when none is.
function Escort.Running()
	if not run then
		if done and GetTime() - done.at < DONE then return done.who, done.took, 1, "took " .. Clock(done.took), "escortDone" end
		return nil
	end
	local gone = GetTime() - run.started
	local label = run.who
	local left = run.seconds and run.seconds - gone
	if left and left > 0 then return label, left, left / run.seconds, (run.timed and "" or "about ") .. Clock(left), "escort" end
	return label, gone, 0, Clock(gone) .. " so far", "escortLate"
end

-- Something to say under the mouse on the card's plate, for the face it wears; never the same twice running.
local QUIPS = {
	escort = {
		"Walks at exactly the speed you don't.",
		"Has never once taken the short way.",
		"Will stop to fight anything. Anything at all.",
		"Their pace: scenic.",
		"Every ambush on this road is for them.",
		"Has places to be. Slowly.",
		"Please stay on the path. They won't.",
		"Stops to give a speech. Again.",
	},
	escortLate = {
		"This is fine. Everything is fine.",
		"Somewhere, a flight path is laughing at you.",
		"Longer than last time. Of course it is.",
		"They stopped to admire a rock.",
		"You could have walked there and back. Twice.",
	},
	escortDone = {
		"Delivered. Mostly in one piece.",
		"Free at last.",
		"Never again. Until the next one.",
		"Nobody tell them about the shortcut.",
	},
}
local quipped
function Escort.Quip(face)
	local pool = QUIPS[face] or QUIPS.escort
	local at = math.random(#pool)
	if pool[at] == quipped and #pool > 1 then at = at % #pool + 1 end
	quipped = pool[at]
	return quipped
end

-- The quest being walked, or nil.
function Escort.Walking()
	return run and run.id or nil
end

-- The journey on the maps (Shy.Maps.Trip's Line): the way from the point of it the character is beside
-- on to its end, never back to one passed.
local function TripLine(continent, north, west)
	if not run then return nil end
	local line = Journey(run.id)
	if not line or line.continent ~= continent then return nil end
	local from = run.along or 1
	local at, away = Shy.Maps.Nearest(line, north, west, from, math.min(line.n, from + SEEK))
	if away > STRAYED then at = Shy.Maps.Nearest(line, north, west, from) end
	run.along = at
	return line, math.min(at + 1, line.n), line.n
end

-- The journey's mark wears the face the card's plate does.
local function Look()
	if not trip or not run then return end
	local _, _, _, _, face = Escort.Running()
	trip:Look(ns.MarkSign(face or "escort"), ns.ToneColor("escort"), "Escort")
end

-- The walk in a line for the chat box: who, for which quest, how far along the way and how long is
-- left; or, just done, how long it took. nil when none is walked.
function Escort.ShareText()
	local label, _, share, said = Escort.Running()
	local id = run and run.id or (done and done.id)
	if not label or not id then return nil end
	local quest = GetQuestLink(id) or D.Name("quests", id) or ""
	if not run then return ("Escorted %s for %s: %s"):format(label, quest, said) end
	local parts = {}
	local line = Journey(run.id)
	if line and W.Known() then TripLine(W.continent, W.north, W.west) end
	if line and run.along and line.along[line.n] > 0 then
		parts[#parts + 1] = ("%d%% of the way"):format(math.floor(line.along[run.along] / line.along[line.n] * 100 + 0.5))
	end
	parts[#parts + 1] = share > 0 and said .. " left" or said
	return ("Escorting %s for %s: %s"):format(label, quest, table.concat(parts, ", "))
end

-- Puts the walk in the chat box, as ShyXP shares its progress.
function Escort.Share()
	local text = Escort.ShareText()
	if not text then return end
	local editBox = ChatFrameUtil.GetActiveWindow()
	if editBox then editBox:Insert(text) else ChatFrameUtil.OpenChat(text) end
end

-- What it knows, for /shy quest escort.
function Escort.Report()
	local db = T.db.escorts
	local out = { ("ShyQuest escorts  (%s)"):format(date("%Y-%m-%d %H:%M")) }
	if run then
		out[#out + 1] = ("walking: %d %s, %s so far, %d points%s%s"):format(run.id, run.who, Clock(GetTime() - run.started), #run.north,
			run.rough and ", not kept" or "", run.died and ", died on the way" or "")
	else
		out[#out + 1] = "walking: none"
	end
	out[#out + 1] = ("pace: %.2f (%.0f s timed over %.0f s reckoned)"):format(Pace(), db.timed, db.reckoned)
	out[#out + 1] = ("sharing: %s, to %s; asked %d"):format(Sharing() and "on" or "off", table.concat(Channels(), " and "), asks)
	local ids = {}
	for id in pairs(db.runs) do ids[#ids + 1] = id end
	table.sort(ids)
	out[#out + 1] = ("kept: %d"):format(#ids)
	for _, id in ipairs(ids) do
		local record = db.runs[id]
		out[#out + 1] = ("  %d %s: %s, %d run%s, %s, %s"):format(id, D.Name("quests", id) or "?", Clock(record.s), record.n, record.n == 1 and "" or "s",
			record.mine and "yours" or "heard", record.p and ("%d points on map %d"):format(#record.p / 4, record.m) or "no way")
	end
	local came = 0
	for _ in pairs(ns.data.escorts or {}) do came = came + 1 end
	out[#out + 1] = ("came with the addon: %d"):format(came)
	local ways = 0
	for _ in pairs(ns.data.escortWays or {}) do ways = ways + 1 end
	out[#out + 1] = ("scripted paths: %d"):format(ways)
	if run then
		local way, line = Scripted(run.id), Journey(run.id)
		out[#out + 1] = ("this one: %s, %s"):format(way and ("scripted, %d yd, %d s waiting"):format(way.yards, way.wait) or "no scripted path",
			line and ("journey of %d points, at %s"):format(line.n, tostring(run.along)) or "no journey")
	end
	return table.concat(out, "\n")
end

-- Under the card's leading row: an escort to accept there, and how long it takes.
ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, function(stop)
	local id = Offered(stop)
	if id then return Escort.Says(id), ns.ToneColor("escort"), "escort" end
end)

Shy:On("SHY_LOGIN", function()
	-- Account-wide, outside the profile (`keep` in ShyQuest.lua).
	local db = T.db.escorts or {}
	db.runs, db.timed, db.reckoned = db.runs or {}, db.timed or 0, db.reckoned or 0
	T.db.escorts = db
	if Shy.Maps and Shy.Maps.Trip then
		trip = Shy.Maps.Trip({ color = ns.ToneColor("escort"), sign = ns.MarkSign("escort"), strip = "Escort", Line = TripLine,
			Left = Escort.Running, To = function() return run and run.who end })
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_ACCEPTED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", function(_, event, a, b)
		if event == "QUEST_ACCEPTED" then
			if D.Escort(a) then
				W.Update()
				Begin(a)
			end
		else
			-- After a reload on the way: count on, but keep nothing of it. A login is a fresh start.
			local saved = ns.char.escort
			ns.char.escort = nil
			if b and saved and saved.id and saved.at and C_QuestLog.IsOnQuest(saved.id) and not C_QuestLog.IsComplete(saved.id)
				and not C_QuestLog.IsFailed(saved.id) then
				Begin(saved.id, GetTime() - (time() - saved.at), true)
				run.seen = true
				ns.char.escort = saved
			end
		end
	end)
	ns.OnRoute(function(rebuilt)
		-- The walk just finished has beamed long enough: the card lets it go.
		if done and GetTime() - done.at >= DONE then
			done = nil
			ns.Refresh()
		end
		Sample()
		Look()
		if rebuilt then
			Check()
			Wanted()
		end
		Send()
	end)
end)
