-- Dying. While you are dead, getting back to life leads the route. It comes before a stop you
-- singled out, the guide's step, a flight or a zone to go to (an "urgent" errand, Route.lua).
--   dead, not released   a row to release, or to take a resurrection someone offers
--   a ghost              the way back to your body: the card's first row, the waypoint arrow, and
--                        the lit mark on both maps (a red skull: Marks.lua's "body"). The mark is
--                        all that shows the place. No ground is drawn round it, and none for
--                        quests meanwhile. Once the body is in reach the row says so, and nothing
--                        points any more.
-- Each time, a quote shows under the row (ns.LastWords). The row's menu has the switch for it, and
-- tells a chat you choose who killed you and where your body is.
-- Nothing is done for the player. Releasing and coming back are theirs to accept.
--
--   /shy quest death        what this file knows right now, to copy
--   /shy quest death show   the row, the mark and the ground for half a minute, as if a ghost

local ADDON, ns = ...
local T = ns.T
local W, R = ns.World, ns.Route
local UI = Shy.UI
local C = UI.colors

local Death = {}
ns.Death = Death

T.defaults.death = { quotes = true }   -- a line of someone's words with each death

local UNITS = 10000
local NEAR = 35              -- yards: this near the body counts as there, where the game hasn't said so (after a reload)
local SHOW = 30              -- seconds a look lasts (Death.Show)

local inRange, inside = false, false   -- the game's word: the body is in reach; it lies inside a dungeon
local said                   -- which line this death has (ns.LastWords)
local trial                  -- a look: { map, x, y, till }
local failed                 -- the finder's last error, for the report

local function Units(share)
	return math.floor(share * UNITS + 0.5)
end

-- The body on a map, as shares of it; nil when it isn't on that map.
local function OnMap(map)
	local at = map and C_DeathInfo.GetCorpseMapPosition(map)
	if not at then return nil end
	local x, y = at:GetXY()
	if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

-- Where the body lies: { map, x, y } on the zone it is in. The player's own map first; a body in
-- another zone is looked for on the maps above, and from there on the zone under that spot.
local function Body()
	if trial then return { map = trial.map, x = trial.x, y = trial.y } end
	local map = W.map
	if not map then return nil end
	local x, y = OnMap(map)
	if x then return { map = map, x = Units(x), y = Units(y) } end
	local info = C_Map.GetMapInfo(map)
	local up = info and info.parentMapID
	while up and up > 0 do
		x, y = OnMap(up)
		if x then
			local zone = C_Map.GetMapInfoAtPosition(up, x, y)
			local id = zone and zone.mapID
			if id and id ~= up then
				local zx, zy = OnMap(id)
				if zx then return { map = id, x = Units(zx), y = Units(zy) } end
			end
			return { map = up, x = Units(x), y = Units(y) }
		end
		info = C_Map.GetMapInfo(up)
		up = info and info.parentMapID
	end
end

-- "ghost", "dead" (not released yet), or nil while alive.
local function State()
	if trial then
		if GetTime() < trial.till then return "ghost" end
		trial = nil
	end
	if UnitIsGhost("player") then return "ghost" end
	if UnitIsDead("player") then return "dead" end
end

-- This death's line: { words, whose }. Not the one the last death had.
local function Words()
	local all = ns.LastWords
	if not all or #all == 0 then return nil end
	if not (said and all[said]) then
		local last = ns.char and ns.char.lastWords
		said = math.random(#all)
		if said == last and #all > 1 then said = said % #all + 1 end
		if ns.char then ns.char.lastWords = said end
	end
	return all[said]
end

-- Where the body lies (the player, before release): map, x, y in the map's units.
local function Lies()
	if State() == "ghost" then
		local body = Body()
		if body then return body.map, body.x, body.y end
	elseif W.Known() and W.map and W.x then
		return W.map, W.x, W.y
	end
end

-- The same as shares of the map, for its pin.
local function Where()
	local map, x, y = Lies()
	if map then return map, x / UNITS, y / UNITS end
end

-- What chat is told: who killed you (ShyRecap's record of this death), where the body lies and when.
-- Returns the line and whether it names a killer.
local function Told()
	local map, x, y = Lies()
	local spot = map and ("%.0f, %.0f"):format(x / 100, y / 100)
	local recap = Shy.addons.Recap
	local death = recap and recap.ShareText and recap:Latest()
	if death and ns.char and ns.char.died and math.abs(death.at - ns.char.died) <= 5 then
		return recap:ShareText(death, spot), death.killed == true
	end
	local zone = map and W.MapName(map)
	local text = zone and ("Died in %s"):format(zone) or "Died"
	if spot then text = text .. " (" .. spot .. ")" end
	return text, false
end

local function Menu(root)
	if not trial then
		local _, named = Told()
		UI.TellMenu(root, named and "Tell who killed you" or "Tell where you died", function() return (Told()) end, Where)
	end
	root:CreateCheckbox("Quote with each death", function() return T.db.death.quotes end, function()
		T.db.death.quotes = not T.db.death.quotes
		ns.Refresh()
	end)
end

local function Find()
	local state = State()
	if not state then return nil end
	if not trial and C_GameRules.IsHardcoreActive() then return nil end
	local stop = { urgent = true, tone = "body", who = "Your body", caption = "YOU DIED", strip = "You died", menu = Menu,
		menuHint = "Tell chat", lines = {} }
	if state == "dead" then
		-- A name can be secret in a fight: ask before testing it.
		local raiser = ResurrectGetOfferer()
		local hidden = issecretvalue(raiser)
		if hidden or (raiser and raiser ~= "") then
			stop.title = "Take the resurrection"
			stop.lines = { hidden and "Someone is raising you" or ("%s is raising you"):format(raiser) }
		else
			stop.title = DEATH_RELEASE
		end
		return stop
	end
	local body = Body()
	-- The row is its name and how far: nobody needs telling how dying works.
	stop.title = "Back to your body"
	if not body then
		stop.lines = { "Too far away to show the way" }
		return stop
	end
	stop.map, stop.x, stop.y = body.map, body.x, body.y
	local yards = W.Distance(body.map, body.x, body.y)
	if inside and not trial then
		stop.lines = { "Inside the dungeon" }
	elseif (inRange and not trial) or (yards and yards <= NEAR) then
		stop.among, stop.found = "body", "Your body is here"
	end
	return stop
end

-- The line under the row.
ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, function(stop)
	if stop.errand ~= "death" or not T.db.death.quotes then return nil end
	local words = Words()
	if not words then return nil end
	local whose = words[2] ~= "" and ("  " .. UI.Wrap(C.dim, words[2])) or ""
	return ("\"%s\"%s"):format(words[1], whose), C.text
end)

-- What this file knows right now, for the copy box.
function Death.Report()
	local state = State()
	local out = { "state: " .. (state or "alive") .. (trial and " (a look)" or "") }
	out[#out + 1] = ("the game: in reach %s, inside a dungeon %s"):format(tostring(inRange), tostring(inside))
	local ok, body = pcall(Body)
	if not ok then
		out[#out + 1] = "body: error: " .. tostring(body)
	elseif body then
		local yards = W.Distance(body.map, body.x, body.y)
		out[#out + 1] = ("body: %s %.1f, %.1f, %s"):format(W.MapName(body.map) or ("map " .. body.map), body.x / 100, body.y / 100,
			yards and W.Yards(yards) or "no distance")
	else
		out[#out + 1] = "body: the game gives no place for it"
	end
	local lead = R.stops[1]
	out[#out + 1] = "leading: " .. (lead and ((lead.errand or lead.kind) .. ": " .. (R.Describe(lead))) or "nothing")
	if state then
		local fine, line = pcall(Told)
		out[#out + 1] = "chat is told: " .. (fine and line or ("error: " .. tostring(line)))
	end
	out[#out + 1] = ("quotes: %s, %d to draw from"):format(T.db.death.quotes and "on" or "off", ns.LastWords and #ns.LastWords or 0)
	if failed then out[#out + 1] = "last error: " .. failed end
	return table.concat(out, "\n")
end

-- A look without dying: for SHOW seconds the route leads to a body a little east of the player.
function Death.Show()
	if not (W.Known() and W.map and W.x) then return "no position here to show it from." end
	trial = { map = W.map, x = math.max(0, math.min(UNITS - 1, W.x + 250)), y = W.y, till = GetTime() + SHOW }
	said = nil
	ns.Refresh()
	C_Timer.After(SHOW + 0.5, function() ns.Refresh() end)
	return ("shown for %d seconds: the card, the arrow and both maps lead to a body east of you."):format(SHOW)
end

-- Guarded: the loaded Route.lua may predate R.AddErrand until the client restarts.
if R and R.AddErrand then
	R.AddErrand("death", function()
		-- The game shows no errors: one here is kept for the report.
		local ok, stop = pcall(Find)
		if ok then return stop end
		failed = tostring(stop)
		geterrorhandler()(stop)
	end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "CORPSE_IN_RANGE", "CORPSE_OUT_OF_RANGE",
	"CORPSE_IN_INSTANCE", "RESURRECT_REQUEST" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_DEAD" then
		-- A new death: new words, and nothing known of the body yet. When, to find ShyRecap's record of it.
		said, inRange, inside = nil, false, false
		if ns.char then ns.char.died = time() end
	elseif event == "CORPSE_IN_RANGE" then
		inRange = true
	elseif event == "CORPSE_IN_INSTANCE" then
		inside = true
	elseif event == "CORPSE_OUT_OF_RANGE" or event == "PLAYER_UNGHOST" then
		inRange, inside = false, false
	end
	ns.Refresh()
end)
