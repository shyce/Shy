-- ShyQuest entry point: settings, events and the pulse.
-- Quest events arrive in bursts, so they only mark the route stale; four times a second
-- the pulse rebuilds it if stale or the player has moved, otherwise just re-measures.

local ADDON, ns = ...
if Shy.Memory then Shy.Memory.Namespace(ADDON, ns) end   -- (the task manager reads what it holds)

local T = Shy:NewAddon(ADDON, {
	suffix = "Quest",
	category = "leveling",
	icon = "Interface\\AddOns\\ShyQuest\\Media\\ShyQuest",
	smallIcon = "Interface\\AddOns\\ShyQuest\\Media\\ShyQuestSmall",
	savedVariables = "ShyQuestDB",
	-- Per account, not per profile: flight times kept before ShyWay kept them (GuideTimers.lua hands them
	-- over), escorts timed and walked (Escort.lua), how far the quest survey got (Survey.lua), and whether
	-- this account gathers quest data for the addon's own files (`dev`), and what creatures the game showed
	-- don't drop (`drops`).
	keep = { air = true, escorts = true, survey = true, offers = true, dev = true, floors = true, drops = true },
	defaults = {
		floors = {},                   -- which floor you said a place is on, by world: north, west, level (World.lua, W.Learn)
		dev = false,                   -- gather quest data: the survey and givers' lists (/shyquest dev)
		survey = { build = "", at = 0, answered = 0, missing = {}, done = false },   -- the quest survey's progress (Survey.lua)
		offers = {},                   -- what each giver offered or didn't, and what was done then (Log.lua, L.Heard)
		card = {
			shown = true,
			rows = 4,                  -- steps listed
			hideInCombat = false,
			flying = true,             -- flight countdown (GuideTimers.lua)
		},
		pickups = true,                -- available quests count as steps
		zones = "short",               -- suggest zones: short (when steps run low) | always | never
		lowLevel = false,              -- include outgrown quests
		repeatable = false,            -- include repeatable quests
		tips = true,                   -- quest details on hovering a tracked quest
		marker = true,                 -- glow behind the next quest's marker in the tracker
		grayZone = false,              -- zone mode: also tracks and lists gray (too low) quests
		track = "zone",                -- the tracker's watch list: zone (current zone, route order) | order (tracked quests, route order) | off
		look = {                       -- the restyled tracker (Look.lua)
			on = true,
		},
		mapPins = true,
		minimapPins = true,
		minimapRim = true,             -- a lit area's outline carries on along the minimap's edge (Ground.lua)
		logMarks = true,               -- the map's quest log wears the marks and lights the map (LogRows.lua)
		logSort = true,                -- ... and lists each zone's quests in the route's order
		mapQuests = true,              -- your quests in a window docked beside ShyMaps' own map window (LogRows.lua, T:QuestList)
		services = {},                 -- town services kept on the world map, by kind: inn, flight ... (Pins.lua; set in the finder)
		pinSize = 1,
		doors = {},                    -- dungeon entrances seen, by instance map: { map, x, y } (ns.NoteDoor)
		shops = {},                    -- what an NPC showed, by NPC id: 0 no shop, 1 buys and sells, 2 repairs too (D.NoteShop)
		drops = {},                    -- items a creature was shown not to drop, by NPC id: { [item] = true } (D.NoteDrop)
		goals = true,                  -- objective pins where the default map marks nothing
		hover = { units = true, objects = true, items = true,     -- quest lines in tooltips (Hover.lua)
			careful = true },          -- warnings about dangerous creatures
		plates = { on = true, size = 1, where = "left" },         -- quest marks on nameplates (Plates.lua)
		party = {
			share = true,              -- share progress with the party (Party.lua)
			tell = {                   -- party chat announcements (Notice.lua)
				objectives = true,     -- an objective finished
				starts = true,         -- looted an item that starts a quest
				accepted = false, handedIn = false, abandoned = false,
			},
		},
		sound = "ready",               -- progress sound: off | ready (quest ready to turn in) | all (each objective too)
		beside = { distance = true, elsewhere = true },           -- extras beside the tracker (Beside.lua)
		xp = {                         -- with ShyXP loaded
			steps = true,              -- XP on turn-in and grind steps
		},
		guide = {
			follow = true,             -- follow the guide when there is one for the character
			hardcore = false,          -- hardcore route: fewer risky quests, and the warnings about elites
			selfFound = false,         -- no AH: skip the steps that buy quest items
			group = true,              -- include group quests (the card asks chat for help with one, and ShyGroup for a group)
			dungeons = {},             -- dungeon detours enabled, by short name (Data/Dungeons.lua: RFC, WC, DM ...)
			dungeonPlan = "ticked",    -- which dungeons' quests are in the guide: ticked | ready (any at your level too) | never
			xprate = 1,                -- the server's XP rate
			nearby = true,             -- a turn-in or objective close by goes before the guide's step (Route.lua)
			buttons = true,            -- use and target buttons for the current step (GuideButtons.lua)
			marks = true,              -- raid marker on whoever those buttons target, when solo
			scan = true,               -- alert when a creature a step waits for appears
			timers = true,             -- the guide's countdowns on the card (GuideTimers.lua)
			gossip = false,            -- pick the gossip option a step needs (GuideTalk.lua)
			takeFlights = true,        -- take the flight a step names
			setHome = true,            -- set the hearthstone at a step's innkeeper
		},
		help = {                       -- asking chat for help with a quest (Card.lua's "Ask for help")
			chat = "LookingForGroup",  -- the usual chat, first in the list: SAY, YELL, GROUP, GUILD or a channel's name (UI.Chats)
		},
		giver = {                      -- at a quest giver (GuideTalk.lua)
			auto = true,               -- auto accept and turn in
			accept = true,             -- accept
			turnIn = true,             -- turn in
			gray = false,              -- include gray quests
			again = false,             -- include repeatable quests
		},
	},
})
ns.T = T

ns.MEDIA = "Interface\\AddOns\\ShyQuest\\Media\\"

-- Levelling help: the guide, quests to pick up, zones to go to and the route's errands. Below the top
-- level, or at it while this character keeps it on (ns.char.topHelp). Without it the card lists the quests
-- you have. A dungeon run is a guide of its own and runs at any level.
function ns.AtTop()
	return GameRulesUtil.IsPlayerAtEffectiveMaxLevel()
end

function ns.Levelling()
	return not ns.AtTop() or (ns.char ~= nil and ns.char.topHelp == true)
end

-- The guide leads: the setting is on, and levelling help (or a dungeon run).
function ns.Following()
	if not T.db.guide.follow then return false end
	if ns.Levelling() then return true end
	local state = ns.char and ns.char.guide
	return state ~= nil and state.run ~= nil
end

-- Quests to pick up count as steps.
function ns.Pickups()
	return T.db.pickups and ns.Levelling()
end

-- The card's right-click menu takes switches from the files that own them (Card.lua, "Errands"):
--   ns.CardSwitch(section, write, kept)   write(root) adds the entries; section: "errands" (what the route
--                                   adds on its own), "suggestions" (what the card speaks up about), "offers"
--                                   ("Take me to"). kept: an errand's switch that still acts without levelling
--                                   help (the quests you have, getting back to life).
ns.cardSwitches = {}
function ns.CardSwitch(section, write, kept)
	ns.cardSwitches[#ns.cardSwitches + 1] = { section = section, write = write, kept = kept == true }
end

local REBUILD_YARDS = 60     -- a log change this far from where the route was built chooses the stops again
local NOW_EVENTS = { QUEST_ACCEPTED = true, QUEST_TURNED_IN = true, QUEST_REMOVED = true, PLAYER_LEVEL_UP = true,
	PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true, PLAYER_DEAD = true, PLAYER_ALIVE = true, PLAYER_UNGHOST = true,
	SUPER_TRACKING_CHANGED = true }
local BLOB_YARDS = 150       -- rebuild after moving this far while on the ground the route leads to
local FIGHT_YARDS = 250      -- moved this far in a fight: the route is built again
local REBUILD_GAP = 2        -- seconds: the route is built at most this often, whatever changed
ns.rebuildGap = REBUILD_GAP   -- (a test of the route's own rules sets it to none)
local PULSE = 0.25
ns.terrainSettle = 3         -- seconds the news of ways over the ground is gathered before one rebuild (a test sets it to none)
local STANDING_EVERY = 10    -- seconds between re-checks of reputation and professions

local stale, staleLog = true, true
local guideStale = true   -- what the guide reads may have changed: it is asked again at the next build
local builtAt          -- when the route was last built
local staleStanding, standingAt = false, 0
local builtNorth, builtWest
local listeners, listenerNames = {}, {}

-- Timing: every piece of work is a clock of the core's (Shy.Clocked round a frame's script, a lap by
-- hand through Shy.Clock(name):Lap), read in the task manager under this addon.

-- Listeners get fn(true, changes) after a rebuild, fn(false, measured) on each pulse between. changes is the
-- build's R.changes (what came, went, changed, whether the order moved), or nil when the listener wasn't
-- told of the build before it (two built before it was told): then all of it is to be taken as new.
-- measured: the stops' distances were measured again (false: the player is where they were, nothing in
-- the route moved; a pulse is still a pulse, for what keeps time by it).
local toldBuilt = {}
-- quiet: fn wants only a rebuild or a re-measure, not the pulses where neither came (most of them).
function ns.OnRoute(fn, quiet)
	listeners[#listeners + 1] = fn
	listeners.quiet = listeners.quiet or {}
	listeners.quiet[#listeners] = quiet or nil
	-- Named by the file that listens, for the timing.
	listenerNames[#listeners] = "redraw " .. ((debugstack(2, 1, 0) or ""):match("([%w_]+)%.lua") or #listeners)
end

-- One listener's error must not stop the others.
local function Told(i, rebuilt, measured)
	local from = debugprofilestop()
	local changes = measured
	if rebuilt then
		changes = ns.Route.changes
		if not changes or toldBuilt[i] ~= changes.built - 1 then changes = nil end
		toldBuilt[i] = ns.Route.changes and ns.Route.changes.built
	end
	local ok, err = pcall(listeners[i], rebuilt, changes)
	if rebuilt then Shy.Clock(listenerNames[i]):Lap(debugprofilestop() - from) end
	if not ok then geterrorhandler()(err) end
end

-- A new route is told to its listeners in their order, as many a frame as fit in SHARE: one frame never
-- pays for every redraw at once (the card, then the maps, the tracker, the arrow ...).
local SHARE = 3        -- ms of a frame
local telling          -- the next listener to tell of the route just built; nil once all are told
local teller = CreateFrame("Frame")
teller:Hide()
-- Work that can wait for a quiet frame (ns.Idle): what a likely next route will need, worked out before it is
-- (Route.lua, "Looking ahead of a change"). One piece a frame while there is any, as much as fits in SHARE;
-- never in a fight, while a new route is being told, nor in a frame that built or told one. ns.Idle(nil)
-- drops what waits: a new route has its own guesses.
local idle = { jobs = {}, busy = -1 }
local idler = CreateFrame("Frame")
idler:Hide()
idler:SetScript("OnUpdate", Shy.Clocked("frame: ahead of a change", function()
	if telling or idle.busy == GetTime() or InCombatLockdown() then return end
	local from = debugprofilestop()
	repeat
		local job = table.remove(idle.jobs, 1)
		if not job then break end
		local ok, err = pcall(job)
		if not ok then geterrorhandler()(err) end
	until debugprofilestop() - from >= SHARE
	idler:SetShown(#idle.jobs > 0)
end))
function ns.Idle(job)
	if not job then
		wipe(idle.jobs)
		idler:Hide()
		return
	end
	idle.jobs[#idle.jobs + 1] = job
	idler:Show()
end

local function TellOn()
	local from = debugprofilestop()
	idle.busy = GetTime()
	repeat
		local i = telling
		telling = i < #listeners and i + 1 or nil
		Told(i, true)
	until not telling or debugprofilestop() - from >= SHARE
	teller:SetShown(telling ~= nil)
end
teller:SetScript("OnUpdate", Shy.Clocked("frame: a new route told", TellOn))

-- A re-measure goes to those told of the route as it stands.
local function Tell(rebuilt, measured)
	if rebuilt then
		if #listeners == 0 then return end
		telling = 1
		TellOn()
		return
	end
	local quiet = measured == false and listeners.quiet or nil
	for i = 1, telling and telling - 1 or #listeners do
		if not (quiet and quiet[i]) then Told(i, false, measured) end
	end
end

-- Called from ns.Apply when a setting changed.
local appliers = {}
function ns.OnApply(fn)
	appliers[#appliers + 1] = fn
end

-- What first asked for the rebuild coming (the timing's "rebuilt for"): an event, the file and line that
-- called ns.Refresh, or the pulse's own reason.
local staleWhy
local function Asked(why)
	if not stale then staleWhy = why end
end

-- Each faction's standing and each skill's rank, as one text (what the quests and the guide read of them).
function ns.StandingText()
	local parts = {}
	for index = 1, C_Reputation.GetNumFactions() or 0 do
		local data = C_Reputation.GetFactionDataByIndex(index)
		if data and data.factionID then parts[#parts + 1] = data.factionID .. "=" .. tostring(data.reaction) end
	end
	parts[#parts + 1] = "|"
	for index = 1, C_SkillInfo.GetNumSkillLines() or 0 do
		local info = C_SkillInfo.GetSkillLineInfo(index)
		if info and info.rank then parts[#parts + 1] = tostring(info.name) .. "=" .. info.rank end
	end
	return table.concat(parts, ",")
end

-- Rebuild on the next pulse. `log`: the quest log changed too.
function ns.Refresh(log)
	if not (stale or staleWhy) then staleWhy = (debugstack(2, 1, 0) or ""):match("([%w_]+%.lua\"?%]?:%d+)") or "?" end
	stale, guideStale = true, true
	if log then staleLog = true end
	-- (Something changed besides a walk: what leads is chosen afresh.)
	if ns.Route then ns.Route.held = nil end
	-- (What the guide reads may have changed: what it worked out ahead is worked out again when next asked.)
	if ns.Guide then ns.Guide.stamp = (ns.Guide.stamp or 0) + 1 end
end

-- Rebuild on the next pulse for a change only the route's errands read (an aura, a fight): the guide stands.
function ns.RefreshRoute()
	if not (stale or staleWhy) then staleWhy = (debugstack(2, 1, 0) or ""):match("([%w_]+%.lua\"?%]?:%d+)") or "?" end
	stale = true
end

-- The errands alone, on the next pulse: a loot the quests don't read, or a fight that only holds an errand
-- back. The guide and the stops stay.
local errandsStale = false
function ns.RefreshErrands()
	errandsStale = true
end

-- QUEST_LOG_UPDATE arrived. The log is read on the next pulse (ns.Pulse), not in the event.
local logPending = false
-- A quest just accepted, until the log lists it. Building before that keeps its marker: the log
-- often fills in the frame after QUEST_ACCEPTED, and that news used to land inside the rebuild gap.
local AWAIT, awaiting = 2, {}
local hold = false   -- this pulse: an accept is not in the log yet, so the route is not built
-- Returns whether an accept is still missing from the log, and whether one just arrived there.
local function AcceptWaiting()
	local now, waiting, arrived = GetTime(), false, false
	for id, at in pairs(awaiting) do
		if ns.Log.Has(id) then
			awaiting[id] = nil
			arrived = true
		elseif now - at >= AWAIT then
			awaiting[id] = nil
		else
			waiting = true
		end
	end
	return waiting, arrived
end

-- For a change that affects which quests are available.
-- Carried: on a flight, or aboard a boat, a zeppelin, an airboat or the tram (Shy.Way.Riding). No way to
-- walk is drawn then, and the route is worked out from where it lands.
function ns.Carried()
	return UnitOnTaxi("player") or Shy.Way.Riding() ~= nil
end

function ns.RefreshOffers()
	ns.Log.ForgetOffers()
	ns.Refresh()
end

-- In a fight the route is the one it had as it began (built then when a fight changes what it leads with):
-- nothing more is rebuilt or measured, what changes waits and is worked out once it is over, and the time is
-- spent letting go of what is kept for later (Shy.Memory). A ghost is led back to its body whatever else is
-- going on.
local tidied = false
local builtFighting = false   -- the route stands for a fight (built in one, or kept as a fight can't change it)
local fightBuilt = false      -- it was built in the fight: built again once the fight is over

-- The stops' distances again, unless the player is where they were last measured from, on the same route:
-- standing still, nothing in them can change (a way newly worked out rebuilds the route), and every one
-- is a way asked of the ground, four times a second.
local measured = {}
local marks = { {}, {} }   -- what the ground had cost when a build began and when it ended (Shy.Way.Mark)
local MEASURE_YARDS = 40    -- yards walked before every stop is measured again (each one asks the ground)
local MEASURE_EACH = 3      -- stops measured a pulse: a walk's new distances come over a few pulses, not in one
-- (measured.next: where the pass under way goes on; the card is told once it is done.)
local function Remeasure(W, R)
	if measured.next and measured.built ~= builtAt then measured.next = nil end
	if not measured.next then
		if not ns.Carried() and W.north and measured.north and measured.built == builtAt
			and W.Between(W.north, W.west, measured.north, measured.west) < MEASURE_YARDS then
			return false
		end
		measured.north, measured.west, measured.built, measured.next = W.north, W.west, builtAt, 1
	end
	measured.R = R
	W.FromLanding(measured.slice)
	return measured.next == nil
end
-- (Only the route's first few: they are what may come to lead. The rest wait for the next build.)
measured.FIRST = 4
function measured.slice()
	measured.next = measured.R.Measure(measured.next, MEASURE_EACH, measured.FIRST)
end

-- Another part of the same zone, or a door (ZONE_CHANGED, ZONE_CHANGED_INDOORS), builds the route again only
-- where the route reads it: another map under the player, or a guide that asks for an area by name
-- (Guide.lua, InArea). Home come to or left is the hearthstone's errand alone: the errands are fitted again.
-- within.Changed() says which, once for each change: the route, the errands.
local within = {}
function within.Changed()
	local home = GetBindLocation()
	local atHome = home ~= nil and home ~= "" and (home == GetSubZoneText() or home == GetMinimapZoneText() or home == GetZoneText())
	local map = C_Map.GetBestMapForUnit("player")
	local route, errands = map ~= within.map or ns.Guide.readsArea == true, atHome ~= within.atHome
	within.atHome, within.map = atHome, map
	return route, errands
end

local function ReadLog()
	hold = false
	if not logPending and not next(awaiting) then return end
	logPending = false
	local L = ns.Log
	L.ReadPlayer()
	L.Scan()
	staleLog = false
	-- Not in the log yet: another pulse reads it. A build now would leave the marker where it was.
	local waiting, arrived = AcceptWaiting()
	if waiting and not arrived then
		logPending, hold = true, true
		return
	end
	local kind = L.delta and L.delta.kind or "changed"
	if kind == "counts" and not arrived then
		-- A kill or a drop that is not the last: the camp stays. The card's count is all that moves.
		if ns.Recount then ns.Recount() end
	elseif kind ~= "none" or arrived then
		-- A quest came or went, or an objective finished. Several of these in a few seconds are one
		-- route. An accept that just reached the log is the exception: the build already in the gap
		-- may have read the log before the quest was in it, so that one is built now.
		Asked("QUEST_LOG_UPDATE")
		stale, guideStale = true, true
		ns.Route.held = nil
		if arrived then builtAt = nil end
	end
end

local function Pulse()
	local W, L, R = ns.World, ns.Log, ns.Route
	local known = W.Update()
	local fighting = InCombatLockdown() and not UnitIsDeadOrGhost("player")
	-- (Carried a long way in a fight, by a portal or the stone: not the same ground, the route is built.)
	local carried = known and builtNorth and W.Between(W.north, W.west, builtNorth, builtWest) > FIGHT_YARDS
	if fighting and builtFighting and not carried then
		ReadLog()
		if Shy.Memory then
			if not tidied then
				tidied = true
				Shy.Memory.Tidy()
			end
			-- (A small step of the game's cleaning a pulse: a fight's garbage is not left for one long one after.)
			Shy.Memory.Step()
		end
		return
	end
	tidied = false
	-- (A fight begun or over: built now, whatever the gap, once; unless nothing waits and the fight can't
	-- change the route, when it stands: no errand to hold back as it begins, nothing built in it as it ends.)
	if fighting ~= builtFighting then
		local matters = (fighting and R.FightMatters()) or (not fighting and fightBuilt)
		-- A fight only holds an errand back, or lets it on again as it ends. That is the errand rows,
		-- not a new choosing of every stop (the hitch on a charge).
		if not stale and matters then
			builtFighting, fightBuilt = fighting, fighting
			errandsStale = false
			Asked(fighting and "a fight began" or "a fight is over")
			W.Budgeted(R.RefitErrands)
			Tell(true)
			if fighting then return end
		elseif stale then
			stale, builtAt = true, nil
			Asked(fighting and "a fight began" or "a fight is over")
		else
			builtFighting = fighting
			if fighting then return end
		end
	end
	ns.Guide.Watch()
	if known and builtNorth and not stale then
		-- Not carried (a flight, a crossing): the route is from where it lands, whatever passes below.
		-- (On the ground of the area it leads to, what there is to do is here: the route waits for the player
		-- to step off it, which R.Wandered says, or to go a good way.)
		-- On the lit ground, or just outside it, the route waits. A turn-in beside the work is not
		-- a reason to choose every stop again every minute of walking.
		local yards = (R.OnLead() or (ns.Ground and ns.Ground.Standing(true))) and BLOB_YARDS or REBUILD_YARDS
		if not ns.Carried() and W.Between(W.north, W.west, builtNorth, builtWest) > yards then
			-- The stops are chosen again, but what leads keeps leading unless another is clearly better
			-- (Route.lua, R.held): two near ones would trade the lead while you follow one.
			Asked("walked on")
			stale = true
			R.held = true
		end
		-- ... or onto the ground the leading stop stands on, or off it (Route.lua, "Areas").
		if not stale and R.Wandered() then
			Asked("onto or off the leading ground")
			stale, guideStale = true, true
		end
	elseif known ~= (builtNorth ~= nil) then
		Asked("where you are came to be known")
		stale, guideStale = true, true
	end
	-- Reputation changes with every kill; re-weighing every zone that often costs too much.
	if staleStanding and GetTime() - standingAt >= STANDING_EVERY then
		staleStanding, standingAt = false, GetTime()
		-- (Every kill moves a reputation a little: only a standing gained or lost, or a skill's rank, changes
		-- what is on offer or what a step asks. Anything less builds nothing.)
		local now = ns.StandingText()
		if now ~= ns.standingWas then
			ns.standingWas = now
			L.ForgetOffers()
			Asked("standing changed")
			stale, guideStale = true, true
		end
	end
	ReadLog()
	-- An accept the log does not list yet: the route stays, and the next pulse reads the log again.
	if hold then return end
	if errandsStale and not stale then
		errandsStale = false
		-- (Within the build's share of the ground: W.Budgeted.)
		W.Budgeted(R.RefitErrands)
		Tell(true)
	elseif stale and builtAt and GetTime() - builtAt < ns.rebuildGap then
		-- (What changed is built in a moment, with whatever else changes by then: a few steps and a few
		-- events are one route, the same on the card and both maps.)
		Tell(false, Remeasure(W, R))
	elseif stale then
		errandsStale = false
		builtAt = GetTime()
		builtFighting, fightBuilt = fighting, fighting
		local askGuide = guideStale
		guideStale = false
		local why = staleWhy
		Shy.Clock("rebuilt for: " .. (why or "?")):Lap(0)
		staleWhy = nil
		-- A count, or the last drop of a quest: keep every other quest's stop. Walking far still chooses again.
		ns.Route.reuse = (why == "QUEST_LOG_UPDATE" or why == "BAG_UPDATE_DELAYED")
			and not (builtNorth and known and W.Between(W.north, W.west, builtNorth, builtWest) >= REBUILD_YARDS)
		local from = debugprofilestop()
		if staleLog then
			L.ReadPlayer()
			L.Scan()
			staleLog = false
		end
		local read = debugprofilestop()
		stale = false
		builtNorth, builtWest = known and W.north or nil, known and W.west or nil
		-- (While the guide and the route are worked out, what the game says of done quests is asked once a quest.)
		local guided
		local building = L.Building or function() end
		building(true)
		Shy.Way.Mark(marks[1])
		local ok, err = pcall(function()
			-- (Asked again only when what it reads may have changed: a fight or an aura is nothing to it.)
			if askGuide then ns.Guide.Refresh() end
			guided = debugprofilestop()
			-- (In the air, from where the flight lands. Within the build's share of the ground: W.Budgeted.)
			W.Budgeted(function() W.FromLanding(R.Build) end)
		end)
		R.reuse, R.held = nil, nil
		building(false)
		if not ok then geterrorhandler()(err) end
		guided = guided or read
		local built = debugprofilestop()
		-- (A setting changed, ns.Apply: what shows changes though the stops are the same ones.)
		if ns.applied then
			ns.applied = nil
			if R.changes then R.changes.same = false end
		end
		Tell(true)
		Shy.Clock("rebuild, in all"):Lap(debugprofilestop() - from)
		Shy.Clock("rebuild: read the log"):Lap(read - from)
		Shy.Clock("rebuild: the guide"):Lap(guided - read)
		Shy.Clock("rebuild: the route"):Lap(built - guided)
		-- (A slow one is written down with what the ground did inside it: tiles read, texts unpacked, floor ms, the
		-- longest step. The route's share of the ground checks the clock between asks, not within one.)
		if built - from >= Shy.HITCH.item then
			local before, after = marks[1], Shy.Way.Mark(marks[2])
			local made = R.changes
			Shy.Spike("rebuilt for: " .. (why or "?"), built - from, ("log %.1f, guide %.1f, route %.1f ms; ground: %d tiles read, %d texts unpacked, floors %.1f ms, longest step %.1f ms; stops: %d came, %d went, %d changed%s%s"):format(
				read - from, guided - read, built - guided, after.tiles - before.tiles, after.inflates - before.inflates,
				after.floorMs - before.floorMs, after.step, #made.added, #made.removed, #made.changed, made.moved and ", order moved" or "",
				made.why and (", first change " .. made.why) or ""))
		end
	else
		Tell(false, Remeasure(W, R))
	end
end
ns.Pulse = Pulse

-- Lifecycle

local LOG_EVENTS = {
	"QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
	"PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
}
-- These change which quests are available without changing the quest log.
local STANDING_EVENTS = { UPDATE_FACTION = true, SKILL_LINES_CHANGED = true }
local OTHER_EVENTS = {
	"ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
	"SUPER_TRACKING_CHANGED", "QUEST_POI_UPDATE", "QUEST_WATCH_LIST_CHANGED", "BAG_UPDATE_DELAYED",
	-- A ghost is led back to its body (Death.lua).
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
}

function T:OnLoad()
	ShyQuestCharDB = ShyQuestCharDB or {}
	ns.char = ShyQuestCharDB
	-- Schema 2 keeps guide progress by step id; older progress is dropped and found again from quests done.
	if type(ns.char.schema) ~= "number" or ns.char.schema < 2 then
		ns.char.guide, ns.char.guides = nil, nil
	end
	ns.char.schema = 2
	ns.char.hidden = ns.char.hidden or {}    -- quests the player hid
	ns.char.zones = ns.char.zones or {}      -- by map: true where the zone's other quests join the guide's (Route.lua, R.Extras)
	ns.char.kept = ns.char.kept or {}        -- quests outside the guide the player chose to keep
	ns.char.unoffered = ns.char.unoffered or {}   -- quests a giver was seen not to offer, by giver (Log.lua)
	ns.char.dropped = ns.char.dropped or {}  -- quests abandoned and not accepted again (Log.lua, L.Left)
	ns.char.had = ns.char.had or {}          -- items a quest in the log needs that the bags have held (Log.lua, L.Had)
	-- guideFull replaced guideOpen; carry the old value over.
	if ns.char.guideFull == nil and ns.char.guideOpen ~= nil then ns.char.guideFull = ns.char.guideOpen end
	ns.char.guideOpen = nil
	-- guide.takeFlights and giver.auto replaced these keys, whose saved "off" was only the old default.
	self.db.guide.flights = nil
	self.db.giver.on = nil
	-- The game's own quest markers stay off (the map's "Show Quest Objectives": its pins and areas on the
	-- map, the buttons beside the quest log's rows and the tracker's quests): ours stand in those places.
	Shy.Hold("questPOI", "0")
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.wasLevelling = ns.Levelling()
	ns.Guide.Setup()
	ns.XP.Setup()
	ns.SetupCard()
	ns.SetupTracker()
	ns.SetupPins()

	local events = CreateFrame("Frame")
	for _, event in ipairs(LOG_EVENTS) do events:RegisterEvent(event) end
	for _, event in ipairs(OTHER_EVENTS) do events:RegisterEvent(event) end
	for event in pairs(STANDING_EVENTS) do events:RegisterEvent(event) end
	local isLog = {}
	for _, event in ipairs(LOG_EVENTS) do isLog[event] = true end
	events:SetScript("OnEvent", function(_, event, ...)
		ns.Route.Heard(event, ...)
		-- What the player did or where they are is built at once; the rest (the log filling, the bags, the
		-- ground's news) waits for the gap.
		if NOW_EVENTS[event] then builtAt = nil end
		if event == "PLAYER_LEVEL_UP" then
			-- The top level reached: levelling help goes (the new level shows the frame after the event).
			C_Timer.After(0, function()
				if ns.Levelling() ~= ns.wasLevelling then ns.Apply() end
			end)
		end
		if event == "QUEST_TURNED_IN" then
			ns.Log.Left((...), true)
			ns.Log.ForgetOffers()
		elseif event == "QUEST_REMOVED" then
			ns.Log.Left((...), false)
		elseif event == "QUEST_ACCEPTED" then
			local id = ...
			ns.Log.Taken(id)
			awaiting[id] = GetTime()
		elseif event == "QUEST_LOG_UPDATE" then
			-- Often nothing changed (opening a gossip, a loot). Read on the next pulse, not in this frame.
			logPending = true
			return
		elseif event == "BAG_UPDATE_DELAYED" then
			-- (Only what the quests or the guide read asks the guide again: loot of any other kind is the
			-- errands', and only the route is built again for them.)
			if not ns.Log.BagsChanged() then
				-- A vendor trash looted, a stack counted: the errands may come or go. The route's stops do not.
				Asked("the bags changed")
				ns.RefreshErrands()
				return
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			-- The log refills after a loading screen; that isn't progress.
			ns.Log.Hush()
			ns.Log.BagsChanged()
			ns.NoteDoor()
			within.Changed()
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			within.Changed()
		elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
			-- (A part of the zone the route reads nothing of: it stands. A walk builds it as anywhere.)
			local route, errands = within.Changed()
			if not route then
				if errands then
					Asked(event)
					ns.RefreshErrands()
				end
				return
			end
		elseif STANDING_EVENTS[event] then
			staleStanding = true
			return
		elseif event == "QUEST_POI_UPDATE" then
			-- New quest areas: the stops may be the same ones, but the maps draw them again and ask for
			-- the areas that were a miss (Ground.AreasSent).
			ns.applied = true
		end
		Asked(event)
		ns.Refresh(isLog[event])
	end)
	C_Timer.NewTicker(PULSE, Shy.Clocked("pulse: each quarter second", Pulse))
	-- Text has the accent color written into it: rebuild on a theme change.
	Shy:On("SHY_THEME", function()
		Asked("the theme changed")
		ns.Refresh()
	end)
	-- A way over the ground that was being worked out is known (World.lua): what is nearest may have changed.
	-- (They come a second apart while a trip's ways are worked out: those that come within terrainSettle seconds
	-- of each other are one measuring of the first stops, a few a pulse. The route is built for the reasons in
	-- Pulse, not for these.)
	local settling = false
	Shy:On("SHY_TERRAIN", function()
		if settling then return end
		settling = true
		C_Timer.After(ns.terrainSettle, function()
			settling = false
			-- Ways refined: the yards change, and the lines (each map lays its own again). What leads does
			-- not: the stops are measured again, a few a pulse, and keep their order.
			measured.north, measured.next = nil, nil
		end)
	end)
end

-- Applies every setting live: rebuilds the route and redraws.
function ns.Apply()
	Shy:Fire("SHY_SWITCH", "shyquest")   -- the quest window's switch in layout mode follows its setting
	ns.wasLevelling = ns.Levelling()
	builtAt = nil   -- (a setting changed: shown at once)
	ns.applied = true   -- (... and drawn whole, though the route comes out the same)
	ns.Log.ForgetOffers()
	ns.Zones.Forget()
	ns.Guide.Forget()
	ns.Refresh()
	ns.XP.Apply()
	if ns.ApplyCard then ns.ApplyCard() end
	if ns.ApplyTracker then ns.ApplyTracker() end
	if ns.ApplyLook then ns.ApplyLook() end
	if ns.ApplyPins then ns.ApplyPins() end
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- For other addons (ShyCore's immersion step and section). Each change applies live, as the options do.
--   T:QuestStyle() / T:SetQuestStyle(style)    "guide": the levelling guide leads; "zone": quests by zone
--   T:InstantTurnIn() / T:SetInstantTurnIn(on) accept and hand in at quest givers (GuideTalk.lua)
--   T:HasGuide()                               a guide is live or one fits this character's level
--   T:WaypointArrow() / T:SetWaypointArrow(on) the arrow on screen that follows your steps (Arrow.lua);
--                                              the character's own, not a profile's
--   T:ArrowSample(parent, widest)              that arrow as a picture for a picker, as the screen shows it: a frame
--                                              with :Set(on); widest: the most room its plate gives the words
function T:WaypointArrow()
	return ns.Arrow ~= nil and ns.Arrow.Following()
end

function T:SetWaypointArrow(on)
	local arrow = ns.Arrow
	on = on and true or false
	if not (arrow and ns.char) or arrow.Following() == on then return end
	arrow.Follow(on)
end

function T:ArrowSample(parent, widest)
	local arrow = ns.Arrow
	return arrow and arrow.Sample and arrow.Sample(parent, widest) or nil
end

-- T:Go(map, x, y, title [, shared])   lead somewhere now (x, y: shares of the map): the place goes first in
--                          the route under its name, and the arrow points the way. (No game pin is set: it would
--                          stand over what is marked there and take its clicks.) shared: { by = name, class = token } for a place someone suggested: the
--                          route says whose it is and its trail wears their class's color.
--                          False where the game takes no waypoint on that map.
local MAP_SHARE = 10000     -- a route's places are x, y in ten-thousandths of a map
function T:Go(map, x, y, title, shared)
	local plan = ns.Plan
	if not (plan and ns.char and map and C_Map.CanSetUserWaypointOnMap(map)) then return false end
	plan.Go({ map = map, x = x * MAP_SHARE, y = y * MAP_SHARE, title = title, from = "way",
		by = shared and shared.by, class = shared and shared.class })
	return true
end

-- T:ItemSources(item)     where an item comes from, nearest first: { kind = "npc" | "object" | "vendor", id, name,
--                          chance, level, map, x, y (shares of the map), yards } each; nil where the data doesn't know it
-- T:Nearest(kind)          the nearest town service of a kind the finder lists ("auction", "repair", "inn" ...):
--                          { name, map, x, y, yards }; nil with none on this continent
-- T:Find(text)             opens the finder on a search
function T:ItemSources(item)
	local find = ns.Find
	return find and find.Sources and find.Sources(item) or nil
end

-- T:FarmAt(item, map, x, y, who [, npc])   leads to where you farm now (as :Go), named for the item and `who` it is
--                          from: the ground you farm on is lit in the finder's color (a search result kept on the
--                          map lets go), and the stop stays while you are there. npc: you farm that creature (all
--                          it drops; item, if given, the one of them you count): its own ground. T:EndFarm() when
--                          the farming ends
-- T:FarmKey(item [, npc])   what the farm is known by: in SHY_FARM_GROUND (key, on) and T:FarmGroundYards(key)
function T:FarmAt(item, map, x, y, who, npc)
	local plan = ns.Plan
	if not (plan and ns.char and map and C_Map.CanSetUserWaypointOnMap(map)) then return false end
	local data = item and ns.Data.Item(item)
	local creature = npc and ns.Data.Npc(npc)
	local title
	if data then
		title = data.name .. (who and (", " .. who) or "")
	else
		title = creature and creature.name or who or "Where you farm"
	end
	plan.EndFarm()
	-- (What you farm is what the maps light from now: a search result kept there before lets go.)
	if ns.LetGo then ns.LetGo() end
	plan.Go({ map = map, x = x * MAP_SHARE, y = y * MAP_SHARE, title = title, from = "way", farm = ns.Route.FarmKey(item, npc) })
	return true
end

function T:FarmKey(item, npc)
	return ns.Route.FarmKey(item, npc)
end

-- T:FarmGroundYards(key)   how far you are from the nearest spawn of the ground you'd farm on (R.FarmGround),
--                          straight; nil off its continent. Cheap: ShyFarm asks it as you stop moving.
function T:FarmGroundYards(key)
	local route = ns.Route
	return route and route.FarmGroundYards and route.FarmGroundYards(key) or nil
end

function T:EndFarm(key)
	if ns.Plan and ns.char then ns.Plan.EndFarm(key) end
end

-- T:FarmSpot(item, left [, npc])  where to farm: the heart of the best camp you can farm (Route.lua's R.FarmSpot:
--                          spawns, drop chance, the walk, your level; no vendors, guards, or elites while a plain
--                          one drops it); left: how many you still want; npc: that creature's camps alone.
--                          { map, x, y, yards, among, name, chance, id }
function T:FarmSpot(item, left, npc)
	local route = ns.Route
	return route and route.FarmSpot and route.FarmSpot(item, left, npc) or nil
end

-- T:Farmable(text [, kinds])   what you could farm whose name holds `text`: items had from creatures you could farm
--                          or from nodes, and those creatures; never townsfolk, guards, vendors, quest givers or
--                          places. kinds: { item = true, creature = true } (both when nil). Prefix matches first:
--                          { kind = "item" | "creature", id, ids (one name, every ID), name, level, from, chance } each
-- T:FindFarm([opts])       opens the finder on what to farm: the best farms for you, your favorites and a search of
--                          what you could farm. opts.pick(kind, id): told what was picked, in place of farming it
--                          (the finder closes); opts.close: it closes after a pick anyway
function T:Farmable(text, kinds)
	local farmable = ns.Farmable
	return farmable and farmable.Search(text, kinds) or {}
end

function T:FindFarm(opts)
	if ns.Find and ns.Find.Farm then ns.Find.Farm(opts) end
end

-- T:CampsOf(npc)           every camp of a creature on every continent, thickest first, from no one place (Route.lua's
--                          R.CampsOf): { map, x, y, continent, north, west, supply, spawns } each; empty where it stands nowhere
function T:CampsOf(npc)
	local route = ns.Route
	return route and route.CampsOf and route.CampsOf(npc) or {}
end

-- T:Npc(npc)               what the data says of a creature: { name, minLevel, maxLevel, rank, title, quests } or nil
function T:Npc(npc)
	local thing = ns.Data and ns.Data.Npc(npc)
	if not thing then return nil end
	return { name = thing.name, minLevel = thing.minLevel, maxLevel = thing.maxLevel, rank = thing.rank, title = thing.title,
		quests = (thing.gives and #thing.gives > 0) or (thing.takes and #thing.takes > 0) or false }
end

-- T:Yards(map, x, y)      how far a place (x, y shares of the map) is from you, straight; nil on another continent
function T:Yards(map, x, y)
	local W = ns.World
	return W and map and W.Distance(map, x * 10000, y * 10000) or nil
end

function T:Nearest(kind)
	local find = ns.Find
	return find and find.Nearest and find.Nearest(kind) or nil
end

function T:Find(text)
	if ns.Find then ns.Find.Toggle(true, text) end
end

function T:QuestStyle()
	return ns.Following() and "guide" or "zone"
end

-- At the top level the guide is this character's to take back or put away (levelling help, ns.char.topHelp);
-- the other characters' style stays as it is, unless the guide is asked for and was off for all.
function ns.SetTopHelp(on)
	if not ns.char then return end
	ns.char.topHelp = on and true or nil
	ns.Apply()
end

function T:SetQuestStyle(style)
	local follow = style == "guide"
	if ns.AtTop() and ns.char then
		if follow and not self.db.guide.follow then self.db.guide.follow = true end
		if not follow and ns.char.guide and ns.char.guide.run and ns.Guide.EndRun then ns.Guide.EndRun(false, true) end
		ns.SetTopHelp(follow)
		return
	end
	if self.db.guide.follow == follow then return end
	-- Zone mode ends a dungeon run (Run.lua), the guide kept where it was.
	if not follow and ns.char and ns.char.guide and ns.char.guide.run and ns.Guide.EndRun then ns.Guide.EndRun(false, true) end
	self.db.guide.follow = follow
	ns.Apply()
end

function T:InstantTurnIn()
	return self.db.giver.auto == true
end

function T:SetInstantTurnIn(on)
	on = on and true or false
	if self.db.giver.auto == on then return end
	self.db.giver.auto = on
	ns.Apply()
end

-- The guides load at login; before that there is no answer and none is claimed.
-- Dungeons, by instance map, for the maps' dungeon journal (Run.lua):
--   :DungeonQuests(map)   the dungeon's quests: { { id, name, state, level, needs } }; nil where your guides have none
--   :DungeonPlan(map)     the same quests with who gives and takes each and where, what each waits on and asks
--                         for, and how the run stands (Run.Plan); nil where your guides have none
--   :RunDungeon(map) / :StopDungeon() / :Running()   its run started, ended, and the map of the one being run
--   :DungeonDoor(map)     its way in: { map, x, y }
-- Bus: SHY_DUNGEON_RUN (map | nil) as a run starts or ends.
function T:DungeonQuests(map)
	return ns.Run and ns.Run.Quests and ns.Run.Quests(map) or nil
end

function T:DungeonPlan(map)
	return ns.Run and ns.Run.Plan and ns.Run.Plan(map) or nil
end

function T:RunDungeon(map)
	if ns.Run and ns.Run.StartMap then ns.Run.StartMap(map) end
end

function T:StopDungeon()
	if ns.Run then ns.Run.Stop() end
end

function T:Running()
	return ns.Run and ns.Run.DoingMap and ns.Run.DoingMap() or nil
end

-- The rare creatures on a map, for the world map (ShyMaps): { { id, name, level ("level 24 rare"), low, high, rank,
-- points = { x, y, ... } (0 to 9999, each a place it turns up), path = { { x, y, ... } a stretch it walks } or nil,
-- display (the look it wears, for a model) } }.
function T:Rares(map)
	return ns.Data and ns.Data.Rares and map and ns.Data.Rares(map) or {}
end

function T:DungeonDoor(map)
	return ns.Run and ns.Run.Door and ns.Run.Door(map) or nil
end

function T:HasGuide()
	local G = ns.Guide
	if G.current then return true end
	local ok, chain = pcall(G.Chain)
	if not ok or type(chain) ~= "table" then return false end
	local level = UnitLevel("player")
	for _, guide in ipairs(chain) do
		if guide.high and guide.high + 1 >= level then return true end
	end
	return false
end

-- Hides a quest for this character (the data can list quests a server doesn't have).
function ns.HideQuest(id, title)
	ns.char.hidden[id] = true
	T:Print(("hid |cffffffff%s|r. Show hidden quests again in the options."):format(title or "that quest"))
	ns.RefreshOffers()
end

function ns.UnhideAll()
	wipe(ns.char.hidden)
	ns.RefreshOffers()
end

-- The dungeons the guides have steps for on this character's faction, lowest first
-- (Data/Routes.lua, Data/Dungeons.lua). Their steps show when enabled in guide.dungeons.
function ns.Detours()
	local out, side = {}, ns.Log.Side()
	local whose = ns.data.routeInfo and ns.data.routeInfo.dungeons or {}
	for _, dungeon in ipairs(ns.Data.Dungeons()) do
		local sides = whose[dungeon.short]
		if sides and (side == "" or sides:find(side, 1, true)) then out[#out + 1] = dungeon end
	end
	return out
end

function ns.Detour(short)
	for _, dungeon in ipairs(short and ns.Detours() or {}) do
		if dungeon.short == short then return dungeon end
	end
end

-- Records a dungeon's entrance: the last open-world position before a loading screen into it,
-- by instance map. No client table has the entrances of this client's new dungeons.
function ns.NoteDoor()
	local W = ns.World
	local _, kind, _, _, _, _, _, instance = GetInstanceInfo()
	if kind ~= "party" or not instance or not W.lastMap or not W.x then return end
	T.db.doors[instance] = { W.lastMap, W.x, W.y }
end

-- ShyGroup integration over the bus, by instance map:
--   SHY_GROUP_WANTED (map)   fired here: the player wants a group; ShyGroup starts that run.
--   SHY_GROUP_RUN (map)      from ShyGroup: a run started; its quests are added to the guide.
function ns.CanRecruit(dungeon)
	return dungeon ~= nil and dungeon.map ~= nil and Shy.addons.Group ~= nil
end

function ns.Recruit(dungeon)
	Shy:Fire("SHY_GROUP_WANTED", dungeon.map)
end

-- A group for a quest (one the game says needs one, or any the player asks about): ShyGroup starts a
-- run named after it, listed where its zone is listed.
--   SHY_GROUP_WANTED (nil, { name, quest, zone, size })
function ns.RecruitFor(id, title, stop)
	local zone = stop and stop.map and ns.World.MapName(stop.map) or nil
	Shy:Fire("SHY_GROUP_WANTED", nil, { name = title, quest = id, zone = zone, size = ns.GroupSize and ns.GroupSize(id) or 0 })
end

Shy:On("SHY_GROUP_RUN", function(map)
	local db = T.db and T.db.guide
	if not map or not db or not db.follow then return end
	for _, dungeon in ipairs(ns.Detours()) do
		if dungeon.map == map and (db.dungeons[dungeon.short] ~= true or ns.Snoozed(dungeon.short)) then
			db.dungeons[dungeon.short] = true
			ns.Unsnooze(dungeon.short)
			T:Print(("added the quests for |cffffffff%s|r to your guide. Untick it in the options to remove them."):format(dungeon.name))
			ns.Apply()
		end
	end
end)

-- Dungeon readiness. A dungeon's steps are in the guide when it is ticked, or, with the plan
-- "ready", once you are at its level as the game suggests it; never while it is put off
-- ("Not now" on a step of it: for a couple of hours, until a level, or for good).
local ranges   -- instance map -> { low, high }, the Group Finder's suggested levels

local function Ranges()
	if ranges then return ranges end
	ranges = {}
	if not (C_LFGList and C_LFGList.GetAvailableCategories) then return ranges end
	for _, categoryID in ipairs(C_LFGList.GetAvailableCategories()) do
		for _, id in ipairs(C_LFGList.GetAvailableActivities(categoryID)) do
			local info = C_LFGList.GetActivityInfoTable(id)
			if info and info.mapID and info.mapID > 0 then
				local low = (info.minLevelSuggestion or 0) > 0 and info.minLevelSuggestion or info.minLevel or 0
				local high = info.maxLevelSuggestion or 0
				local have = ranges[info.mapID]
				if have then
					have.low, have.high = math.min(have.low, low), math.max(have.high, high)
				else
					ranges[info.mapID] = { low = low, high = high }
				end
			end
		end
	end
	return ranges
end

-- The levels a dungeon is for: the game's suggestion where it has one, else the guides' data.
function ns.DungeonRange(dungeon)
	local r = dungeon.map and Ranges()[dungeon.map]
	if r and r.low > 0 then return r.low, r.high > 0 and r.high or dungeon.high end
	return dungeon.low, dungeon.high
end

-- Ready for a dungeon: at its level.
function ns.DungeonReady(dungeon)
	local low, high = ns.DungeonRange(dungeon)
	local level = UnitLevel("player")
	return level >= low and (high == 0 or level <= high)
end

-- Why a dungeon is put off ("until level 18", "for 2 h"), or nil. A snooze that has run out ends here.
function ns.Snoozed(short)
	local snoozed = ns.char and ns.char.snoozed
	local s = snoozed and snoozed[short]
	if not s then return nil end
	if s.always then return "for good" end
	if s.level then
		if UnitLevel("player") >= s.level then
			snoozed[short] = nil
			return nil
		end
		return "until level " .. s.level
	end
	local left = (s.till or 0) - time()
	if left <= 0 then
		snoozed[short] = nil
		return nil
	end
	return "for " .. (left >= 3600 and (math.ceil(left / 3600) .. " h") or (math.ceil(left / 60) .. " min"))
end

-- how: "hours" (a couple of hours), "level" (until `level`), "off" (for good, whatever the plan;
-- ticking it in the options brings it back).
function ns.Snooze(dungeon, how, level)
	ns.char.snoozed = ns.char.snoozed or {}
	if how == "off" then
		T.db.guide.dungeons[dungeon.short] = nil
		ns.char.snoozed[dungeon.short] = { always = true }
		T:Print(("took the quests for |cffffffff%s|r out of your guide. Tick it in the options to put them back."):format(dungeon.name))
	elseif how == "level" then
		ns.char.snoozed[dungeon.short] = { level = level }
		T:Print(("skipping |cffffffff%s|r until level %d."):format(dungeon.name, level))
	else
		ns.char.snoozed[dungeon.short] = { till = time() + 2 * 3600 }
		T:Print(("skipping |cffffffff%s|r for a couple of hours."):format(dungeon.name))
	end
	ns.Apply()
end

function ns.Unsnooze(short)
	if ns.char and ns.char.snoozed then ns.char.snoozed[short] = nil end
end

-- Whether a quest is one of a put-off dungeon's. Its steps are out of the guide (DungeonOn); one already in
-- the log, or offered nearby, is no stop of the route either until the dungeon is back.
function ns.PutOff(id)
	local snoozed = ns.char and ns.char.snoozed
	if not (snoozed and next(snoozed)) then return false end
	local short = ns.Guide.DungeonOf(id)
	return short ~= nil and ns.Snoozed(short) ~= nil
end

-- Whether a dungeon's steps belong in the guide right now.
function ns.DungeonOn(short)
	local db = T.db.guide
	if db.dungeonPlan == "never" then return false end
	if ns.Snoozed(short) then return false end
	if db.dungeons[short] == true then return true end
	if db.dungeonPlan == "ready" then
		local dungeon = ns.Detour(short)
		return dungeon ~= nil and ns.DungeonReady(dungeon)
	end
	return false
end

-- Whether a dungeon is in because it was ticked (not only for being at your level).
function ns.DungeonTicked(short)
	local db = T.db.guide
	return db.dungeonPlan ~= "never" and db.dungeons[short] == true and not ns.Snoozed(short)
end

-- A level gained, or a snooze run out, can change which dungeons are in: the guide is laid again.
do
	local function Rethink()
		if not (T.db and T.db.guide and ns.char) then return end
		if T.db.guide.dungeonPlan == "ready" or next(ns.char.snoozed or {}) then ns.Apply() end
	end
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("PLAYER_LEVEL_UP")
	watch:SetScript("OnEvent", function() C_Timer.After(0, Rethink) end)
	C_Timer.NewTicker(60, function()
		local snoozed = ns.char and ns.char.snoozed
		if not snoozed then return end
		for short in pairs(snoozed) do
			if not ns.Snoozed(short) then
				Rethink()
				return
			end
		end
	end)
end

-- Slash command

SLASH_SHYQUEST1, SLASH_SHYQUEST2 = "/shyquest", "/sq"
SlashCmdList.SHYQUEST = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "" then
		T:OpenOptions()
	elseif msg == "next" then
		local stop = ns.Route.stops[1]
		if not stop then
			T:Print("nothing to do nearby.")
			return
		end
		local title, lines, where = ns.Route.Describe(stop)
		local yards = stop.yards and (", " .. ns.World.Yards(stop.yards)) or ""
		T:Print(("next: |cffffffff%s|r%s%s%s"):format(title, lines[1] and (", " .. lines[1]:lower()) or "", where and (" " .. where) or "", yards))
	elseif msg == "guide" then
		ns.ToggleGuideWindow()
	elseif msg == "dungeon" or msg:sub(1, 8) == "dungeon " then
		-- A dungeon's quests from the start (Run.lua). It may not be loaded: a file new to the TOC needs a
		-- client restart.
		if ns.Run then
			ns.Run.Command(msg:sub(9))
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "talk" then
		-- A log of recent quest giver interactions (GuideTalk.lua).
		if ns.ShowTalks then ns.ShowTalks() end
	elseif msg == "areas" then
		-- What the game knows of the log's quest areas (Ground.lua).
		if ns.Ground and ns.Ground.Report then Shy.UI.ShowCopyBox("ShyQuest: quest areas", ns.Ground.Report()) end
	elseif msg == "talents" then
		-- What Spec.lua reads of the talents and found of the talent window.
		if ns.Spec and ns.Spec.Report then Shy.UI.ShowCopyBox("ShyQuest: talents", ns.Spec.Report()) end
	elseif msg == "legacy" then
		-- What Legacy.lua reads of the account's Legacy points. A file new to the TOC needs a client restart.
		if ns.Legacy then
			Shy.UI.ShowCopyBox("ShyQuest: Legacy", ns.Legacy.Report())
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "death" or msg == "death show" then
		-- What Death.lua knows right now, or a look at its row and marks without dying. It may not be
		-- loaded: a file new to the TOC needs a client restart.
		if not ns.Death then
			T:Print("restart the game once to use this.")
		elseif msg == "death" then
			Shy.UI.ShowCopyBox("ShyQuest: death", ns.Death.Report())
		else
			T:Print(ns.Death.Show())
		end
	elseif msg == "escort" then
		-- What Escort.lua has timed, walked and heard. It may not be loaded: a file new to the TOC needs a
		-- client restart.
		if ns.Escort then
			Shy.UI.ShowCopyBox("ShyQuest: escorts", ns.Escort.Report())
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "bank" then
		-- What Stash.lua knows of the quest items in the bags and the bank. It may not be loaded: a file new
		-- to the TOC needs a client restart.
		if ns.Stash then
			Shy.UI.ShowCopyBox("ShyQuest: quest items and the bank", ns.Stash.Report())
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "rows" then
		-- What the map's quest log wears (LogRows.lua). It may not be loaded: a file new to the TOC needs
		-- a client restart.
		if ns.LogRows then
			Shy.UI.ShowCopyBox("ShyQuest: quest log", ns.LogRows.Report())
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "dev" then
		-- Gathering quest data for the addon's own files: the server survey and givers' lists. Off for players.
		T.db.dev = not T.db.dev
		if not T.db.dev and ns.Survey and ns.Survey.Running() then ns.Survey.Stop() end
		T:Print(T.db.dev and "gathering quest data: |cff888888/shyquest survey|r asks the server, and givers' lists are kept."
			or "no longer gathering quest data.")
	elseif msg == "survey" or msg:sub(1, 7) == "survey " then
		-- Ask the server about every quest (Survey.lua). It may not be loaded: a file new to the TOC needs a
		-- client restart.
		if ns.Survey then
			ns.Survey.Command(strtrim(msg:sub(7)))
		else
			T:Print("restart the game once to use this.")
		end
	elseif msg == "skip" then
		local at, total = ns.Guide.Progress()
		if at and ns.Guide.Skip() then
			T:Print(("skipped step %d of %d. |cff888888/shyquest back|r undoes it."):format(at, total))
		else
			T:Print("no guide step to skip.")
		end
	elseif msg == "back" then
		if ns.Guide.Back() then
			local at, total = ns.Guide.Progress()
			T:Print(("back on step %d of %d."):format(at, total))
		else
			T:Print("no earlier guide step to go back to.")
		end
	elseif msg == "where" then
		local zones = ns.Zones.Best(3)
		if #zones == 0 then
			T:Print("no zone has enough quests for you right now.")
			return
		end
		for _, zone in ipairs(zones) do
			T:Print(("|cffffffff%s|r: %s%s"):format(zone.name, ns.Zones.Summary(zone),
				zone.yards and (", " .. ns.World.Yards(zone.yards)) or ""))
		end
	elseif msg == "log" then
		local L, G = ns.Log, ns.Guide
		T:Print(("%d of %d quests in your log."):format(L.held or 0, L.most or 0))
		local spare = L.Spare(G.current and G.Uses or nil)
		if #spare == 0 then T:Print("nothing in it is an obvious one to drop.") end
		for i = 1, math.min(5, #spare) do
			T:Print(("could drop: |cffffffff%s|r (%s)"):format(spare[i].entry.title, spare[i].why))
		end
	elseif msg == "find" or msg:sub(1, 5) == "find " then
		-- Find.lua may not be loaded: a file new to the TOC needs a client restart.
		if ns.Find then
			ns.Find.Toggle(msg ~= "find" or nil, strtrim(msg:sub(6)))
		else
			T:Print("restart the game once to use the finder.")
		end
	elseif msg == "card" then
		T.db.card.shown = not T.db.card.shown
		ns.Apply()
	else
		T:Print("/shyquest opens the options  |cff888888\194\183|r  guide: the whole guide  |cff888888\194\183|r  skip, back: move through guide steps  |cff888888\194\183|r  next: your next step  |cff888888\194\183|r  where: zones with quests for you  |cff888888\194\183|r  log: quests you could drop  |cff888888\194\183|r  card: show or hide the card  |cff888888\194\183|r  find <name>: search  |cff888888\194\183|r  talk: recent quest giver log  |cff888888\194\183|r  survey: ask the server about every quest")
	end
end
