-- The hearthstone as part of the route. When to use it and where to set it are decided here,
-- live, from where the character is and where the guide goes next; a guide's own "hearth to"
-- and "set your hearthstone" steps count as done while this is on (Guide.lua).
--   What lies ahead: the guide's next steps that have a place (G.Places), with a clock run along
--     them: the way from one to the next (R.Travel) and what each takes (R.Effort: how many, the
--     drop chance, how far apart the spawns stand, other players). Only the stone's hour of
--     them counts: what comes after is another use.
--   Using it: a row that leads when home is the quicker way to what comes next, unless a step
--     within that hour is a use that saves a good deal more: then the card says to save it.
--   Nearly ready: with a few minutes left on the stone and a use that is worth the wait, the row
--     says so.
--   Setting it: a stop at an inn the character stands in or passes, when the stone would save
--     a good deal more from there than from home on the way ahead, or when several of the log's
--     quests are handed in around it.
--   Where home is: the game names it (GetBindLocation) but not its place. The place is noted when
--     the stone is set, and whenever the character rests where the name says (ns.char.home).
-- The stone is never used for you. Setting it is: talking to the inn row's innkeeper picks the
-- bind line and answers the game's question (GuideTalk.lua, under "Auto set hearthstone").

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide

local Hearth = {}
ns.Hearth = Hearth

T.defaults.hearth = { on = true }     -- the hearthstone as rows on the card

local STONE = 6948
local GLOBAL = 2              -- seconds: a cooldown no longer than this is the global one
local SAVES = 90             -- seconds of travel the stone has to save
local CAST = 10              -- seconds it takes to use
local BETTER = 0.5           -- used now when that saves at least this share of the best use ahead
local WAIT = 300             -- seconds: a stone this near ready is waited for
local HOUR = 3600            -- seconds the stone cools down for
local AHEAD = 40             -- guide steps looked at, at most, for the uses within that hour
local TALKS = 20             -- seconds a step takes besides its kills and gathering
local REHOME = 120           -- seconds more the stone has to save from an inn for it to be worth making home
local INN = 150              -- yards: an innkeeper this near is the inn the character stands in
local HUB = 400              -- yards: a hand-in this near brings the character back to the inn
local BACK = 3               -- hand-ins to come back for that make an inn worth being home
local SAME = 300             -- yards: home this near an inn is that inn
local REDO = 400             -- yards walked before what the stone saves is worked out whole again
local RUN = 7                -- yards a second on foot

local put                    -- "Not now": what the stone was not used for

-- This character's: home = { name, map, x, y }, inns = { [innkeeper] = true } not wanted as home.
local function Inns()
	ns.char.inns = ns.char.inns or {}
	return ns.char.inns
end

local function Busy()
	return InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
end

-- Seconds from one place to another, a journey worked out whole once and kept while the journeys stand (R.forgotten
-- counts a flight learned, a fall or water walked, the roads kept to, a carrying off). The same legs come round at
-- every refresh of the guide's places. A journey that is settled is kept; one still being worked out is kept LOOSE
-- seconds as it stands, then asked again. Then whether it was settled.
local legs = { gen = -1, n = 0 }
local LEGS_MOST = 600
local LOOSE = 5
local function Travel(continent, north, west, toNorth, toWest)
	if legs.gen ~= R.forgotten or legs.n > LEGS_MOST then legs = { gen = R.forgotten, n = 0, loose = {} } end
	local key = ("%d:%.0f:%.0f>%.0f:%.0f"):format(continent, north, west, toNorth, toWest)
	local seconds = legs[key]
	if seconds then return seconds, true end
	local loose, now = legs.loose[key], GetTime()
	if loose and now - loose.at < LOOSE then return loose.seconds, false end
	local final, settled
	seconds, final, settled = R.Travel(continent, north, west, toNorth, toWest)
	if final or settled then
		legs[key], legs.loose[key] = seconds, nil
		if not loose then legs.n = legs.n + 1 end
		return seconds, true
	end
	if loose then
		loose.seconds, loose.at = seconds, now
	else
		legs.loose[key] = { seconds = seconds, at = now }
		legs.n = legs.n + 1
	end
	return seconds, false
end

-- The nearest innkeeper of the character's side: { npc, map, x, y, yards }. Every innkeeper of the data is
-- asked how far, so the answer is kept until the character has walked INN_REDO yards from where it was found
-- (or been carried off, R.forgotten), when an inn too far to matter then can't have come within INN.
local innkeeper = { gen = -1 }
local INN_REDO = 100             -- yards walked before the nearest inn is looked for again, when none is near
local INN_ROUND = INN * 3 + INN_REDO * 3   -- yards: with one near, the innkeepers this near are asked again until then; the rest can't be the nearest
local function Innkeeper()
	local kept = innkeeper
	local same = kept.gen == R.forgotten and kept.continent == W.continent and kept.north
		and W.Between(W.north, W.west, kept.north, kept.west) < INN_REDO
	if same and (not kept.best or kept.best.yards > INN * 3) then return kept.best end
	local best
	-- (One near: how far it is now is asked at every build, of the few round here and not of every inn there is.)
	for _, npc in ipairs(same and kept.near or {}) do
		local map, x, y, yards, dungeon = W.Nearest(npc.places)
		if map and yards and not dungeon and (not best or yards < best.yards) then
			best = { npc = npc, map = map, x = x, y = y, yards = yards }
		end
	end
	if best then return best end
	local near = {}
	for _, id in ipairs(D.Town("inn")) do
		local npc = D.Npc(id)
		if npc and L.Friendly(npc) then
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			if map and yards and not dungeon then
				if yards <= INN_ROUND then near[#near + 1] = npc end
				if not best or yards < best.yards then best = { npc = npc, map = map, x = x, y = y, yards = yards } end
			end
		end
	end
	innkeeper = { gen = R.forgotten, continent = W.continent, north = W.north, west = W.west, best = best, near = near }
	return best
end

-- Whether the place the game names as home is where the character stands.
local function Here(name)
	return name ~= nil and name ~= "" and (name == GetSubZoneText() or name == GetMinimapZoneText() or name == GetZoneText())
end

-- Home as a place, when it is known; and the game's name for it.
local function Home()
	local name, home = GetBindLocation(), ns.char.home
	if home and home.name == name then return home, name end
	return nil, name
end

-- A place as the reckoning below takes it: { name, continent, north, west }, or nil off this continent.
local function Spot(name, map, x, y)
	local spot = { name = name }
	spot.continent, spot.north, spot.west = W.ToWorld(map, x, y)
	if spot.north and spot.continent == W.continent then return spot end
end

-- Notes where home is: at the inn the character stands in, when it was just set there (`set`) or
-- the game's name for home says here.
local function Note(set)
	local home, name = Home()
	if home and not set then return end
	if not name or name == "" or not W.Known() or not (set or Here(name)) then return end
	local inn = Innkeeper()
	if inn and inn.yards <= INN then
		ns.char.home = { name = name, map = inn.map, x = inn.x, y = inn.y }
	elseif set then
		ns.char.home = { name = name, map = W.map, x = W.x, y = W.y }
	end
end

-- Whether home is the inn the character stands in already: talking to its innkeeper again, to
-- sell or for a quest, does not set it again (GuideTalk.lua).
function Hearth.AtHome()
	local noted, name = Home()
	if Here(name) then return true end
	local home = noted and Spot(noted.name, noted.map, noted.x, noted.y)
	return home ~= nil and W.north ~= nil and W.Between(home.north, home.west, W.north, W.west) <= SAME
end

-- Seconds until the stone can be used again; nil when it can be now.
local function Cooling()
	local start, duration = C_Container.GetItemCooldown(STONE)
	if not start or start == 0 or not duration or duration == 0 then return nil end
	local left = start + duration - GetTime()
	return left > 0 and left or nil
end

-- "4 min", "under a minute".
local function Minutes(seconds)
	if seconds < 60 then return "under a minute" end
	return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

local function Quit(root)
	root:CreateButton("Stop asking about the hearthstone", function()
		T.db.hearth.on = false
		ns.Apply()
	end)
end

-- What the stone saves
-- Seconds sooner a place is reached from home than from another place, the cast taken off.
local function Saving(home, north, west, toNorth, toWest)
	local walked = Travel(home.continent, north, west, toNorth, toWest)
	local hearthed = Travel(home.continent, home.north, home.west, toNorth, toWest)
	return walked - hearthed - CAST
end
-- What the stone saves on the way to the stop that leads, worked out once for that stop and home: each is two
-- journeys worked out whole, and it was asked at every errand fitting (a kill, a loot). Again only for another
-- stop or home, somewhere else at once (R.Forget), or a good walk nearer or farther.
local leadSaved = {}
local function LeadSaving(home, lead)
	local key = home.name .. ":" .. lead.north .. ":" .. lead.west
	local away = W.Between(W.north, W.west, lead.north, lead.west)
	if leadSaved.gen ~= R.forgotten then leadSaved = { gen = R.forgotten } end
	local kept = leadSaved[key]
	-- (Walking nearer or farther moves what the stone saves by the seconds of the walk: it is worked out whole,
	-- two journeys, again every REDO yards, and between them moved by the walk.)
	if kept and math.abs(away - kept.away) <= REDO then return kept.saved - (kept.away - away) / RUN end
	local saved = Saving(home, W.north, W.west, lead.north, lead.west)
	leadSaved[key] = { saved = saved, away = away }
	return saved
end

-- What lies ahead: the guide's next places, each with the seconds it takes. Read again whenever the guide is
-- (G.stamp: every route built) or you are somewhere else at once (R.forgotten), but what was worked out for it
-- stands while it reads the same: the same places in the same order, each taking as long.
local way = {}
local function Way()
	local main = G.active[1]
	if not main then return nil end
	local stamp = tostring(G.current) .. ":" .. main.step.index .. ":" .. tostring(G.stamp) .. ":" .. tostring(R.forgotten)
	if way.stamp ~= stamp then
		local places = G.Places(AHEAD)
		local parts = { tostring(G.current), R.forgotten }
		for _, place in ipairs(places) do
			local seconds = TALKS
			for _, task in ipairs(place.tasks) do
				seconds = seconds + (task.quest and R.Effort(task.quest, task.objective) or R.EffortOf(task.item, task.need))
			end
			place.seconds = seconds
			parts[#parts + 1] = ("%d,%d,%.0f,%.0f,%.0f"):format(place.index, place.continent, place.north, place.west, seconds)
		end
		local key = table.concat(parts, ":")
		if way.key == key then
			way.stamp = stamp
		else
			way = { key = key, stamp = stamp, at = GetTime(), places = places, best = {} }
		end
	end
	return way, main
end

-- The best use of the stone with home at `home`, among the places within the stone's hour (only what comes within
-- the hour is lost by using the stone now). Worked out in two passes, BUDGET milliseconds at a go and the rest over
-- the frames after (the route is told once it is known):
--   the walks: from each place to the next, on the way's own clock, up to the hour
--   the uses: a use saves the walk to a place less the way there from home, so never more than that walk less the
--     cast. The longest walks are asked first, and the rest left as soon as none of them can beat the best found:
--     a few journeys from home instead of one for every place.
-- A journey still being worked out makes the answer loose: it is worked out again LOOSE seconds on.
local BUDGET = 3
local worker = CreateFrame("Frame")
worker:Hide()

local function Longest(a, b)
	if a.walk ~= b.walk then return a.walk > b.walk end
	return a.order < b.order
end

-- True once `best` is worked out whole; false when the clock ran to `upTo` first.
local function Work(best, found, home, upTo)
	local places = found.places
	while not best.walked do
		local i = best.at
		if i > #places or best.clock >= HOUR then
			table.sort(best.steps, Longest)
			best.walked = true
			break
		end
		local from, to = places[i - 1], places[i]
		if from.continent == home.continent and to.continent == home.continent then
			local walk, settled = Travel(home.continent, from.north, from.west, to.north, to.west)
			if not settled then best.loose = true end
			best.steps[#best.steps + 1] = { walk = walk, to = to, order = i }
			best.clock = best.clock + walk
		end
		best.clock = best.clock + to.seconds
		best.at = i + 1
		if debugprofilestop() >= upTo then return false end
	end
	local steps = best.steps
	while best.next <= #steps do
		local step = steps[best.next]
		if best.saved and step.walk - CAST < best.saved then break end
		local hearthed, settled = Travel(home.continent, home.north, home.west, step.to.north, step.to.west)
		if not settled then best.loose = true end
		local saved = step.walk - hearthed - CAST
		if not best.saved or saved > best.saved or (saved == best.saved and step.order < best.order) then
			best.saved, best.index, best.order = saved, step.to.index, step.order
		end
		best.next = best.next + 1
		if best.next <= #steps and debugprofilestop() >= upTo then return false end
	end
	best.steps, best.done, best.since = nil, true, GetTime()
	return true
end

-- A loose answer is worked out again behind what shows (best.redo: the same two passes, afresh), LOOSE seconds on
-- when it is next asked for or the ground says ways were found, and takes the answer's place when it is done.
-- The route hears of it only where the answer is another one: its errand rows are fitted again, never the
-- whole route built (a build for every pass of every loose journey was a hitch every few seconds of a walk).
local function Redo(best)
	if best.redo or not (best.done and best.loose) or GetTime() - best.since < LOOSE then return false end
	best.redo = { home = best.home, at = 2, clock = 0, steps = {}, next = 1 }
	worker:Show()
	return true
end

worker:SetScript("OnUpdate", Shy.Clocked("hearth: the way ahead", function(self)
	local found, upTo, open = way, debugprofilestop() + BUDGET, false
	for _, best in pairs(found.best or {}) do
		local redo = best.redo
		if not best.done then
			if not Work(best, found, best.home, upTo) then
				open = true
				break
			end
			worker.news = true
		elseif redo then
			if not Work(redo, found, best.home, upTo) then
				open = true
				break
			end
			if redo.saved ~= best.saved or redo.index ~= best.index then worker.news = true end
			best.saved, best.index, best.order, best.loose, best.since, best.redo = redo.saved, redo.index, redo.order, redo.loose, redo.since, nil
		end
	end
	if not open then
		self:Hide()
		if worker.news then
			worker.news = nil
			ns.RefreshErrands()
		end
	end
end))
do
	local waiting = false
	local function Again()
		waiting = false
		for _, best in pairs(way.best or {}) do Redo(best) end
	end
	Shy:On("SHY_TERRAIN", function(why)
		if why ~= "found" or waiting then return end
		for _, best in pairs(way.best or {}) do
			if best.done and best.loose and not best.redo then
				waiting = true
				C_Timer.After(LOOSE, Again)
				return
			end
		end
	end)
end

-- Seconds saved, the step it is before, and how many of the character's steps on that is; nil while it is being
-- worked out. Then whether the answer is loose: made of journeys still being worked out (after a reload, rough
-- walks where a flight will be found), and worked out again behind what shows.
local function Ahead(home)
	local found, main = Way()
	if not found then return nil end
	local best = found.best[home.name]
	if not best then
		best = { home = home, at = 2, clock = 0, steps = {}, next = 1 }
		found.best[home.name] = best
	end
	if not best.done then
		if not Work(best, found, home, debugprofilestop() + BUDGET) then
			worker:Show()
			return nil
		end
	else
		Redo(best)
	end
	local away = best.index and (G.Number(best.index) or 0) - (G.Number(main.step.index) or 0) or nil
	return best.saved, best.index, away, best.loose == true
end

-- What to do with the stone now, for what leads:
--   "use", saved, what            it is ready and home is the quicker way
--   "wait", saved, what, left     it is ready in `left` seconds, and worth that wait
--   "keep", saved, what, index, away    a step `away` steps on saves a good deal more: `saved` there
--   nil                           nothing to say
-- All three only when the stone would save time on the way to what leads: with home no quicker
-- (what leads is near home, or you are), there is nothing to use it for and nothing to keep it from.
local function Plan(lead)
	if not T.db.hearth.on or not ns.char or not W.Known() or C_Item.GetItemCount(STONE) == 0 then return nil end
	local noted = Home()
	local home = noted and Spot(noted.name, noted.map, noted.x, noted.y)
	if not home then return nil end
	local left = Cooling()
	if left and left > WAIT then return nil end
	if not (lead and lead.north and lead.continent == W.continent) then return nil end
	local saved = LeadSaving(home, lead)
	if saved < SAVES then return nil end
	local what = lead and lead.who or "what comes next"
	local best, index, away = Ahead(home)
	if best and best >= SAVES and away and away > 0 and saved < best * BETTER then
		-- (Said only while the stone is ready: a stone that is cooling is not being kept.)
		if not left then return "keep", best, what, index, away end
		return nil
	end
	if saved >= SAVES and not left then return "use", saved, what end
	if left and saved - left >= SAVES then return "wait", saved, what, left end
	return nil
end

-- Using it, as a route errand with nowhere to go (R.AddErrand), or nil.
local function Use(lead)
	local plan, saved, what, left = Plan(lead)
	if (plan ~= "use" and plan ~= "wait") or put == what then return nil end
	local home = Home()
	local waiting = plan == "wait"
	-- (Where it sets the character down: the way on to what comes next is from there, not from here.)
	local lands = not waiting and Spot(home.name, home.map, home.x, home.y) or nil
	return {
		title = waiting and ("Hearth to %s in %s"):format(home.name, Minutes(left)) or ("Hearth to " .. home.name),
		lines = { ("About %s sooner to %s"):format(Minutes(saved - (waiting and left or 0)), what),
			waiting and "Finish up here while it cools" or nil },
		caption = waiting and "HEARTHSTONE  \194\183  NEARLY READY" or "HEARTHSTONE  \194\183  THE SHORT WAY",
		mark = "home",
		first = not Busy() or nil,
		away = true,             -- (Whatever else goes first is done before it: a bank, a trainer, a vendor here.)
		lands = lands,
		wait = waiting and left or nil,
		tip = function(tip)
			tip:AddLine(waiting and "Waiting for your hearthstone beats walking. Do what's nearby first."
				or "Your hearthstone is ready, and nothing coming up needs it more.", 0.6, 0.6, 0.6, true)
		end,
		menu = function(root)
			root:CreateButton("Not now", function()
				put = what
				ns.Refresh()
			end)
			Quit(root)
		end,
	}
end

-- The card's note under the stop that leads (ns.cardNotes): the stone is kept for a step ahead.
local function Kept(stop)
	if stop.kind == "errand" or stop.kind == "fly" then return nil end
	local plan, saved, _, index, away = Plan(stop)
	if plan ~= "keep" then return nil end
	local view = G.View(index)
	local who = view and view.who
	-- A row of its own under the hearthstone's emblem, so it is never read as the step's: what to do
	-- and what it saves on one line; what it is kept for on its hover.
	local at = away == 1 and "at the next step" or ("%d steps on"):format(away)
	local travel = ns.SignColor("home")
	return { text = "Don't hearth yet", color = Shy.UI.colors.text, sign = "home",
		right = "saves " .. Minutes(saved), rightColor = travel,
		tip = { "Your hearthstone", ("Save it for %s, %s. It saves you about %s there."):format(who or "later", at, Minutes(saved)) } }
end

-- How many of the log's unfinished quests are handed in within HUB yards of here.
local function Returns()
	local back = 0
	for _, entry in ipairs(L.order) do
		local quest = not entry.complete and not entry.failed and D.Quest(entry.id)
		for _, token in ipairs(quest and quest.ends or {}) do
			local thing = (token.kind == "n" or token.kind == "o") and D.Thing(token.kind, token.id)
			if thing and (token.kind == "o" or L.Friendly(thing)) then
				local _, _, _, yards, dungeon = W.Nearest(thing.places)
				if yards and not dungeon and yards <= HUB then
					back = back + 1
					break
				end
			end
		end
	end
	return back
end

-- Making an inn home, as a route errand (R.AddErrand), or nil: the inn the character stands in
-- or passes (R.Passing), when on the guide's way ahead the stone would save REHOME seconds more
-- from there than from where home is now; or, standing in it, when BACK or more of the log's
-- quests come back to it. Not the inn that is home already, nor one turned down.
local function Set(lead)
	if not T.db.hearth.on or not ns.char or not W.Known() or C_Item.GetItemCount(STONE) == 0 then return nil end
	local inn = Innkeeper()
	if not inn or Inns()[inn.npc.id] then return nil end
	local busy = Busy()
	local passing = not busy and R.Passing("sethome", inn.map, inn.x, inn.y, lead, INN)
	if not passing and inn.yards > INN then return nil end
	local noted, name = Home()
	if Here(name) then return nil end
	local there = Spot("inn" .. inn.npc.id, inn.map, inn.x, inn.y)
	local home = noted and Spot(noted.name, noted.map, noted.x, noted.y)
	if not there or (home and W.Between(home.north, home.west, there.north, there.west) <= SAME) then return nil end
	-- What the stone would save on the way ahead from here, over what it saves from home. Only on two whole
	-- answers: with either still being worked out, or made of journeys that are (just after a reload), the
	-- one that is ready would stand against nothing, and an inn be offered as home for a few seconds.
	local fromHere, _, _, hereLoose = Ahead(there)
	local fromHome, homeLoose
	if home then fromHome, _, _, homeLoose = Ahead(home) end
	local sure = fromHere ~= nil and not hereLoose and (not home or (fromHome ~= nil and not homeLoose))
	local gain = sure and math.max(0, fromHere) - math.max(0, fromHome or 0) or 0
	local back = inn.yards <= INN and Returns() or 0
	if gain < REHOME and back < BACK then return nil end
	return {
		title = "Make this inn your home",
		lines = { inn.npc.title and ("%s, %s"):format(inn.npc.name, inn.npc.title) or inn.npc.name,
			back >= BACK and ("You turn in %d quests here"):format(back)
				or ("Your hearthstone saves about %s more from here"):format(Minutes(gain)) },
		caption = "INN  \194\183  SET YOUR HEARTHSTONE",
		mark = "home",
		map = inn.map, x = inn.x, y = inn.y, thing = inn.npc, who = inn.npc.name,
		first = not busy or nil,
		tip = function(tip)
			tip:AddLine((name and name ~= "") and ("Your hearthstone is set to %s."):format(name) or "Your hearthstone isn't set.",
				0.6, 0.6, 0.6, true)
		end,
		menu = function(root)
			root:CreateButton("Not this inn", function()
				Inns()[inn.npc.id] = true
				ns.Refresh()
			end)
			Quit(root)
		end,
	}
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "HEARTHSTONE_BOUND", "PLAYER_UPDATE_RESTING", "BAG_UPDATE_COOLDOWN" }) do
	events:RegisterEvent(event)
end
-- The stone's cooldown as last seen: the game says its cooldowns changed after every spell and potion, and
-- only the stone's own matters here.
local stoneStart, stoneLasts
events:SetScript("OnEvent", function(_, event)
	if not ns.char then return end
	if event == "BAG_UPDATE_COOLDOWN" then
		local start, duration = C_Container.GetItemCooldown(STONE)
		-- (A global cooldown, which every spell cast begins, is the stone ready: it is a cooldown worth waiting
		-- for only when it is more than that.)
		if not duration or duration <= GLOBAL then start, duration = 0, 0 end
		if start == stoneStart and duration == stoneLasts then return end
		stoneStart, stoneLasts = start, duration
	end
	if event == "HEARTHSTONE_BOUND" then
		W.Update()
		Note(true)
		-- (What the stone saves from home is reckoned again.)
		way = {}
	elseif event ~= "BAG_UPDATE_COOLDOWN" then
		Note(false)
	end
	-- (Resting come or gone is read by the errands alone: the stops and the guide stand.)
	if event == "PLAYER_UPDATE_RESTING" then
		ns.RefreshErrands()
		return
	end
	ns.Refresh()
end)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Hearth when it saves time", function() return T.db.hearth.on end, function()
		T.db.hearth.on = not T.db.hearth.on
		ns.Apply()
	end)
end)
ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Kept)

R.AddErrand("hearth", Use, "Using your hearthstone")
R.AddErrand("sethome", Set, "Setting your home inn")
