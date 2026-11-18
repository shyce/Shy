-- ShyCore: addon registration, the message bus, profiles and addon comms.
--
-- In an addon's .toc:   ## Dependencies: ShyCore
--
--   local T = Shy:NewAddon(..., {
--       suffix = "Tip",                         -- shown as "Shy" + "Tip"
--       icon = "Interface\\AddOns\\ShyTip\\Media\\ShyTip",            -- where its pictures are, by name
--       smallIcon = "Interface\\AddOns\\ShyTip\\Media\\ShyTipSmall",  -- round, for a minimap button or a notice
--       mark = ...,                             -- what stands for it wherever it is shown (icon .. "Mark" if nil)
--       category = "interface",                 -- the group it is listed under (Shy.CATEGORIES)
--       tagline = "...",                        -- optional; the .toc's Notes (without its slash command) if nil
--       savedVariables = "ShyTipDB",            -- optional; becomes T.db with defaults merged in
--       defaults = { ... },
--       keep = { key = true },                  -- optional; saved keys that are account-wide, not per profile
--   })
--   function T:OnLoad() end                     -- ADDON_LOADED; T.db is ready
--   function T:OnLogin() end                    -- PLAYER_LOGIN
--   function T:OnComm(msg, sender, channel) end -- from another player's copy of this addon
--   function T:OnBNComm(msg, gameAccountID) end -- the same over Battle.net, from that game account
--   function T:OpenWindow() end                 -- optional; opened from the minimap menu and the hub
--
--   T:Print(msg)   T:ResetDB()   T:SendComm(msg, channel, target)   T:SendBNComm(msg, gameAccountID)
--   T:Once(flag, fn)                            -- fn(settings) once per account, on T.db and every profile's copy;
--                                               -- `flag` must be named in `keep`
--   T:RegisterOptions(frame)   T:OpenOptions()
--   Shy:On(event, fn)   Shy:Off(event, fn)   Shy:Fire(event, ...)
--   Shy:OnFor(event, key, fn)   Shy:OffFor(event, key, fn)   -- only when the event's first value is `key`
--   Shy.Profiles                               -- see "Profiles" below
--   Shy.Hold(setting, value)                    -- see "Game settings an addon holds" below
--
-- Bus events: SHY_ADDON_LOADED (addon), SHY_LOGIN, SHY_COMM (addon, msg, sender, channel),
-- SHY_BN_COMM (addon, msg, gameAccountID), SHY_THEME (accent changed, Theme.lua), SHY_SLOT (icon slot
-- shape changed, Skin.lua)

local CORE = ...
Shy = {}
local Shy = Shy

local GetMeta = C_AddOns.GetAddOnMetadata

Shy.MEDIA = "Interface\\AddOns\\ShyCore\\Media\\"
Shy.FONT = Shy.MEDIA .. "LilitaOne.ttf"             -- display font (Latin only)
-- The rounded and text fonts hold every alphabet but Chinese and Korean (Latin, Cyrillic, Greek, Thai),
-- symbols, arrows, box drawing and one-color emoji, so anything a player types draws in one face.
Shy.FONT_ROUNDED = Shy.MEDIA .. "NunitoExtraBold.ttf" -- player-made text (names) and numbers
Shy.FONT_TEXT = Shy.MEDIA .. "NunitoSansText.ttf"   -- running text (chat); Shy.UI.TextFont picks the cut
Shy.FONT_TEXT_LARGE = Shy.MEDIA .. "NunitoSansTextLarge.ttf" -- lighter cut for sizes 16 and up
Shy.ICON = Shy.MEDIA .. "ShyCore"
Shy.SMALL_ICON = Shy.MEDIA .. "ShyRound"
Shy.COMM_PREFIX = "Shy"
-- Shy.wings.chat / .meter / .tracker = { left, top, right, bottom }: how far a skinned wing's art
-- reaches past its Blizzard frame (negative when inside); nil while unskinned. Set by the addon that
-- skins it, read by ShyDock. The tracker's top is inverted: how far its art starts below the frame's top.
Shy.wings = {}
Shy.addons = {}   -- by suffix
Shy.order = {}    -- in load order
local byName = {}

-- Tables

function Shy.CopyTable(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and Shy.CopyTable(v) or v end
	return out
end

function Shy.MergeDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			Shy.MergeDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

-- Clocks

-- What an addon's work costs, piece by piece: every handler the game calls into it is timed under a name,
-- with whatever it calls in other addons. Nothing here reads, formats or prints; the monitor does.
--   Shy.Clocked(name, fn) -> fn, timed:  calls, ms, the worst call and when, and while detail is on the
--                            KB each run made (a run the game cleaned up inside counts as a collection)
--   Shy.Clock(name[, addon]) -> the entry;  clock:Lap(ms[, kb]) adds a lap timed by hand
--   Shy.Clocks() -> every entry by name (Shy.clocks);  Shy.ClocksSince() -> when they were last reset
--   Shy.ResetClocks()
--   Shy.ClockDetail(on) -> on:  the monitor's switch; closed, a clocked call costs two reads of the
--                            stopwatch and one call, as ever; detail adds two reads of the heap to each
--   Shy.ClockMeasure(name, runs, done) -> true: the clock's next `runs` calls go through the game's own
--                            measure (exact time, bytes made and freed); done(results) once they have
--   Shy.AddonOf(level) -> the Shy addon whose file is `level` calls up (1: the caller), "ShyCore" else
-- An entry: { name, addon, group, calls, ms, most, mostAt, kb, collected }: the addon whose file registered
-- it, and the words before the first colon of its name (its subsystem).
local clocks, clockedAt = {}, GetTime()
Shy.clocks = clocks
local detail = false
local slots = setmetatable({}, { __mode = "k" })   -- each wrapper's slot { clock, fn, run }, while it lives

-- Whose file a call came from (`level` calls up from the caller of Caller), and its file:line.
local function Caller(level)
	local line = debugstack(level + 1, 1, 0) or ""
	local file, at = line:match("([%w_]+%.lua):(%d+)")
	return line:match("AddOns[/\\](Shy[%w_]*)[/\\]") or "ShyCore", file and (file .. ":" .. at) or nil
end
function Shy.AddonOf(level)
	return (Caller((level or 1) + 1))
end
local Entry = {}
Entry.__index = Entry
-- (addon: given, or read from the stack: Clock, the API function, then the addon's own file, whose
-- file:line the entry keeps as `where`.)
local function Clock(name, addon)
	local clock = clocks[name]
	if not clock then
		local from, where = Caller(3)
		clock = setmetatable({ name = name, addon = addon or from, where = not addon and where or nil,
			group = name:match("^(.-):") or name:match("^[%w_]+") or name,
			calls = 0, ms = 0, most = 0, mostAt = 0, kb = 0, collected = 0 }, Entry)
		clocks[name] = clock
	end
	return clock
end
-- Hitches: a clocked call of HITCH.item ms or more, and a frame that came HITCH.frame ms or more after the
-- one before (all the game spent, drawing too), each written down with what can tell its cause: the largest
-- clocked call of the frame (the outermost, where calls nest) and the change in the game's memory over it. A
-- drop in memory with no big call is the game cleaning up, which no clock shows.
--   Shy.Spike(what, ms[, note])   write one down      Shy.ResetSpikes()
--   Shy.Spikes() -> list, total   newest first, each { at, what, ms, note }; total: all ever written
--   Shy.HITCH = { item, frame, keep }   the limits in ms, and how many are kept
local HITCH = { item = 8, frame = 50, keep = 40 }
Shy.HITCH = HITCH
local spikes, spiked, spikeTotal = {}, 0, 0
local worst, worstMs = nil, 0   -- the largest clocked call since the last frame began
-- A measurement's own cost (the task manager's walk of every addon's memory, which the game makes in one go) is
-- no hitch of the game's: Shy.Excuse() from inside it, and neither the call nor the frame it ran in is written down.
local excused = false
function Shy.Excuse() excused = true end
function Shy.Spike(what, ms, note)
	spiked = spiked % HITCH.keep + 1
	spikeTotal = spikeTotal + 1
	local entry = spikes[spiked]
	if not entry then
		entry = {}
		spikes[spiked] = entry
	end
	entry.at, entry.what, entry.ms, entry.note = GetTime(), what, ms, note
end
function Shy.Spikes()
	local out, size = {}, #spikes
	for back = 0, size - 1 do out[back + 1] = spikes[(spiked - 1 - back) % size + 1] end
	return out, spikeTotal
end
function Shy.ResetSpikes()
	wipe(spikes)
	spiked, spikeTotal = 0, 0
end
do
	local watch = CreateFrame("Frame")
	local last, heap, skip = debugprofilestop(), collectgarbage("count"), true
	-- (A loading screen is no hitch: the frame after one is not looked at.)
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("PLAYER_LEAVING_WORLD")
	watch:SetScript("OnEvent", function() skip = true end)
	watch:SetScript("OnUpdate", function()
		local now, size = debugprofilestop(), collectgarbage("count")
		if skip then
			skip = false
		elseif now - last >= HITCH.frame and not excused then
			Shy.Spike("frame", now - last, ("largest call: %s, %.1f ms; memory %+.0f KB%s"):format(
				worst and worst.name or "none", worstMs, size - heap, size < heap and " (cleaned up)" or ""))
		end
		last, heap, worst, worstMs, excused = now, size, nil, 0, false
	end)
end

local function Took(clock, from, ...)
	local took = debugprofilestop() - from
	clock.calls, clock.ms = clock.calls + 1, clock.ms + took
	if took > clock.most then clock.most, clock.mostAt = took, GetTime() end
	if took > worstMs then worst, worstMs = clock, took end
	if took >= HITCH.item and not excused then Shy.Spike(clock.name, took) end
	return ...
end
local function Made(clock, heap, ...)
	local made = collectgarbage("count") - heap
	if made < 0 then clock.collected = clock.collected + 1 else clock.kb = clock.kb + made end
	return ...
end
local function Detailed(slot)
	local clock, fn = slot.clock, slot.fn
	return function(...) return Made(clock, collectgarbage("count"), fn(...)) end
end
local timed = setmetatable({}, { __mode = "k" })   -- every handler a clock times (the census leaves them be)
function Shy.Clocked(name, fn)
	local clock = Clock(name)
	local slot = { clock = clock, fn = fn }
	slot.run = detail and Detailed(slot) or fn
	slots[slot] = true
	local run = function(...) return Took(clock, debugprofilestop(), slot.run(...)) end
	timed[run] = true
	return run
end

-- The census: what the clocks miss. While it is on, every OnUpdate and OnEvent a Shy addon sets with no clock
-- round it is timed under where it was set ("unclocked: ShyDock/Move.lua:295 OnUpdate"), so the monitor lists
-- it with the rest. It looks at every script set in the game (a post-hook on the widgets' own SetScript) and
-- takes only those set from a Shy file, so it is off unless asked for, and runs for one session: asked for, it
-- starts with the next reload and is off again at the one after (whatever it did, logging in again ends it).
--   Shy.SetCensus(on)   asked for (ShyCoreDB.census) or taken back      Shy.Census() -> on now
-- What ShyCore's own files set as they load is set before it starts, and is not in it.
-- (No edit box among the widgets asked for their methods: one made, even unseen, takes the keyboard.)
-- (The mouse's scripts too: a click on an option runs its handler and whatever that applies, in no clock.)
local census = { on = false, SCRIPTS = { OnUpdate = true, OnEvent = true, OnClick = true, OnMouseUp = true, OnMouseDown = true,
	OnValueChanged = true, OnEnter = true, OnLeave = true }, DEEP = 6, KEPT = 12,
	WIDGETS = { "Frame", "Button", "CheckButton", "StatusBar", "ScrollFrame", "Slider" } }
function Shy.Census() return census.on end
function Shy.SetCensus(on)
	if not ShyCoreDB then return end
	ShyCoreDB.census = on and true or nil
	if not on then ShyCoreDB.censusUnread = nil end
end
-- Whose line set a script: the nearest file on the stack above the hook (the game's own functions between have
-- none), DEEP calls up at most. A Shy addon's: the addon, the file, the line. Any other file's, the game's
-- included: nil, and the script is never touched.
function census.Setter(stack)
	for line in stack:gmatch("[^\n]+") do
		local path = line:match("Interface[/\\]([^%]\":<>]-%.lua)")
		if path then
			local addon, file = path:match("^AddOns[/\\](Shy[%w_]*)[/\\](.+)$")
			if not addon then return nil end
			return addon, (file:gsub("\\", "/")), line:match("%.lua[%]\"]*:(%d+)") or "?"
		end
	end
end
-- A script just set: one of ours with no clock is set again, timed.
function census.Set(frame, script, fn)
	if census.setting or not census.SCRIPTS[script] or type(fn) ~= "function" or timed[fn] then return end
	local run = census.runs[fn]
	if not run then
		local stack = debugstack(2, census.DEEP, 0) or ""
		local addon, file, line = census.Setter(stack)
		if not addon then
			-- (One that names no file at all, or a Shy file behind another's, was not taken: the first few are
			-- kept, to see why.)
			local unread = census.unread
			if unread and #unread < census.KEPT and (stack:find("AddOns[/\\]Shy") or not stack:find("Interface[/\\]")) then
				unread[#unread + 1] = script .. "\n" .. stack
			end
			return
		end
		local clock = Clock(("unclocked: %s/%s:%s %s"):format(addon, file, line, script), addon)
		run = function(...) return Took(clock, debugprofilestop(), fn(...)) end
		census.runs[fn], timed[run] = run, true
	end
	census.setting = true
	pcall(frame.SetScript, frame, script, run)
	census.setting = false
end
function census.Start()
	if census.on then return end
	census.on, census.runs = true, setmetatable({}, { __mode = "k" })
	census.unread = {}
	if ShyCoreDB then ShyCoreDB.censusUnread = census.unread end
	local seen = {}
	for _, kind in ipairs(census.WIDGETS) do
		-- (One of each kind, made only to be asked for its methods: hidden, taking no mouse.)
		local probe = CreateFrame(kind)
		probe:Hide()
		probe:EnableMouse(false)
		local meta = getmetatable(probe)
		local index = meta and meta.__index
		if type(index) == "table" and not seen[index] then
			seen[index] = true
			hooksecurefunc(index, "SetScript", census.Set)
		end
	end
end
Shy.census = census
function Shy.Clock(name, addon)
	local clock = Clock(name, addon)   -- (not a tail call: the owner is read from this frame's caller)
	return clock
end
function Entry:Lap(took, made)
	self.calls, self.ms = self.calls + 1, self.ms + took
	if took > self.most then self.most, self.mostAt = took, GetTime() end
	if took > worstMs then worst, worstMs = self, took end
	if made then
		if made < 0 then self.collected = self.collected + 1 else self.kb = self.kb + made end
	end
end
function Shy.Clocks() return clocks end
function Shy.ClocksSince() return clockedAt end

function Shy.ResetClocks()
	for _, clock in pairs(clocks) do
		clock.calls, clock.ms, clock.most, clock.mostAt, clock.kb, clock.collected = 0, 0, 0, 0, 0, 0
	end
	clockedAt = GetTime()
end

function Shy.ClockDetail(on)
	if on == nil then return detail end
	on = on and true or false
	if on ~= detail then
		detail = on
		for slot in pairs(slots) do
			if not slot.measuring then slot.run = on and Detailed(slot) or slot.fn end
		end
	end
	return detail
end

-- Whether a clock has a handler to route through a measure (a lap clock, or the bus's, has none).
function Shy.ClockMeasurable(name)
	local clock = clocks[name]
	if not clock then return false end
	for slot in pairs(slots) do
		if slot.clock == clock then return true end
	end
	return false
end

local function Kept(list, result, ...)
	list[#list + 1] = result
	return ...
end
function Shy.ClockMeasure(name, runs, done)
	local clock, results, left, mine = clocks[name], {}, runs, {}
	if not clock then return false end
	for slot in pairs(slots) do
		if slot.clock == clock and not slot.measuring then mine[#mine + 1] = slot end
	end
	if #mine == 0 then return false end
	local function Restore()
		for _, slot in ipairs(mine) do
			slot.measuring = nil
			slot.run = detail and Detailed(slot) or slot.fn
		end
		done(results)
	end
	for _, slot in ipairs(mine) do
		local fn = slot.fn
		slot.measuring = true
		slot.run = function(...)
			if left <= 0 then return fn(...) end
			left = left - 1
			if left == 0 then
				return Kept(results, C_AddOnProfiler.MeasureCall(fn, ...)), Restore()
			end
			return Kept(results, C_AddOnProfiler.MeasureCall(fn, ...))
		end
	end
	return true
end

-- An event's list is never changed in place: On and Off put a new one in its stead, so a Fire under way
-- goes on through the list it began with, and firing copies nothing.
local listeners = {}
local owners = setmetatable({}, { __mode = "k" })   -- a listener's addon, for the detail clocks

function Shy:On(event, fn)
	local list = { unpack(listeners[event] or {}) }
	list[#list + 1] = fn
	listeners[event] = list
	owners[fn] = Shy.AddonOf(2)
	return fn
end

function Shy:Off(event, fn)
	local list = listeners[event]
	if not list then return end
	local kept = {}
	for _, each in ipairs(list) do
		if each ~= fn then kept[#kept + 1] = each end
	end
	listeners[event] = kept
end

-- A listener for one subject of an event: called only when the event's first value is `key` (a box for the
-- SHY_HUD_* events, an id, a kind of change), so a piece that cares about its own box isn't called for every
-- box on the screen. Kept as the plain lists are (a new list in place of the old), and run after them.
local keyed = {}   -- event -> key -> { fn, ... }
function Shy:OnFor(event, key, fn)
	if key == nil then return Shy:On(event, fn) end
	local byKey = keyed[event]
	if not byKey then
		byKey = setmetatable({}, { __mode = "k" })   -- a box gone is a key gone
		keyed[event] = byKey
	end
	local list = { unpack(byKey[key] or {}) }
	list[#list + 1] = fn
	byKey[key] = list
	owners[fn] = Shy.AddonOf(2)
	if not listeners[event] then listeners[event] = {} end   -- so Fire looks
	return fn
end

function Shy:OffFor(event, key, fn)
	local byKey = keyed[event]
	local list = byKey and key ~= nil and byKey[key]
	if not list then return end
	local kept = {}
	for _, each in ipairs(list) do
		if each ~= fn then kept[#kept + 1] = each end
	end
	byKey[key] = #kept > 0 and kept or nil
end

-- One listener's error never stops the others. Each event's listeners are timed together as "bus EVENT"
-- (ShyCore's, since the game charges it with them); in detail, each addon's listeners also as
-- "bus EVENT → Addon", so the monitor can show whose work it was.
local busClocks, busBy = {}, {}
local function FireFor(event, ...)
	local byKey = keyed[event]
	if not byKey then return end
	local key = ...
	if key == nil or issecretvalue(key) then return end
	local list = byKey[key]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then geterrorhandler()(err) end
	end
end
function Shy:Fire(event, ...)
	local list = listeners[event]
	if not list then return end
	local clock = busClocks[event]
	if not clock then
		clock = Clock("bus " .. tostring(event), "ShyCore")
		busClocks[event] = clock
	end
	local from = debugprofilestop()
	if detail then
		local by = busBy[event]
		if not by then
			by = {}
			busBy[event] = by
		end
		for i = 1, #list do
			local fn = list[i]
			local addon = owners[fn] or "ShyCore"
			local each = by[addon]
			if not each then
				each = Clock("bus " .. tostring(event) .. " \226\134\146 " .. addon, addon)
				by[addon] = each
			end
			local at, heap = debugprofilestop(), collectgarbage("count")
			local ok, err = pcall(fn, ...)
			Made(each, heap)
			Took(each, at)
			if not ok then geterrorhandler()(err) end
		end
	else
		for i = 1, #list do
			local ok, err = pcall(list[i], ...)
			if not ok then geterrorhandler()(err) end
		end
	end
	FireFor(event, ...)
	Took(clock, from)
end

-- Where the player is
--
-- The game says where the player stands on a map as a vector, and where that is in the world as another: each a
-- table with every method of a vector written into it, made anew at each asking (two a reading: 3.6 KB, by the
-- monitor's count of a reading four times a second). UnitPosition says the same place in plain numbers, which
-- make nothing. Once it has been seen to agree with the game's vectors (which of its two is north is learned by
-- comparing them) it is read instead, and held against them again every CHECK seconds on the move, every STILL
-- seconds standing, and at once when the zone changes. Where it says nothing (an instance) or does not agree,
-- the vectors are read as before.
--   Shy.Here([fresh]) -> continent, north, west   nil where the game says nothing (an instance, a loading screen)
--   Shy.Stand() -> north, west, up | nil          where the player stands by UnitPosition alone, on whatever map
--                                                 (an instance's too, should the game say it there): nil where it
--                                                 says nothing, withholds it, or which of its two is north has
--                                                 not been learned yet this session (it is, out of doors)
--   Shy.HereOn([fresh]) -> map, x, y              the map the game puts the player on, and where on it (0 to 1);
--                                                 x nil where it says nothing
--   Shy.MapFrame(map) -> { continent, north, west, north across, west across } | false
--                                                 how a map lies on its continent: its top left corner and how
--                                                 far it runs each way (asked once a map); false for one with no
--                                                 place in the world
-- A reading by vectors is kept for the frame (the minimap, the arrows and the card ask in one); `fresh` reads again
-- whatever was read this frame (a ticker, an event: where the player is now).
do
	local here = { CHECK = 1, STILL = 5, NEAR = 1, SAME = 0.0005, at = -1, checked = -math.huge, loose = {} }
	Shy.here = here   -- (for a test of how the place is read)
	local frames = {}
	local abs = math.abs

	function Shy.MapFrame(map)
		local frame = frames[map]
		if frame == nil then
			frame = false
			local c0, a = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 0))
			local c1, b = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(1, 1))
			if c0 and a and b and c1 == c0 then
				local n0, w0 = a:GetXY()
				local n1, w1 = b:GetXY()
				frame = { c0, n0, w0, n1 - n0, w1 - w0 }
			end
			frames[map] = frame
		end
		return frame
	end

	-- Which of UnitPosition's two is north: 1 the first, 2 the second; nil where neither way is the place.
	local function Agree(a, b, north, west)
		if abs(a - north) < here.NEAR and abs(b - west) < here.NEAR then return 1 end
		if abs(b - north) < here.NEAR and abs(a - west) < here.NEAR then return 2 end
	end

	-- The game's own answer, by its vectors; and UnitPosition (a, b on `instance`) held against it.
	local function Ask(now, a, b, instance)
		here.at, here.checked, here.a, here.b, here.asked = now, now, a, b, true
		local map = C_Map.GetBestMapForUnit("player")
		local position = map and C_Map.GetPlayerMapPosition(map, "player")
		local x, y, continent, north, west
		if position then
			x, y = position:GetXY()
			if x == nil or issecretvalue(x) or issecretvalue(y) then
				x, y = nil, nil
			else
				local world
				continent, world = C_Map.GetWorldPosFromMapPos(map, position)
				if continent and world then north, west = world:GetXY() else continent = nil end
			end
		end
		here.map, here.x, here.y, here.continent, here.north, here.west = map, x, y, continent, north, west
		here.order = nil
		if a and continent then
			here.order, here.instance = Agree(a, b, north, west), instance
			-- (Which of the two is north is the game's own way, the same on every map: kept once learned.)
			here.north1 = here.order or here.north1
			-- (A map that does not lie on its continent as one rectangle: where on it is the game's to say each time.)
			local frame = Shy.MapFrame(map)
			if frame and frame[4] ~= 0 and frame[5] ~= 0
				and (abs((west - frame[3]) / frame[5] - x) > here.SAME or abs((north - frame[2]) / frame[4] - y) > here.SAME) then
				here.loose[map] = true
			end
		end
	end

	function Shy.Here(fresh)
		local now = GetTime()
		local a, b, _, instance = UnitPosition("player")
		if a == nil or b == nil or issecretvalue(a) or issecretvalue(b) or issecretvalue(instance) then a, b = nil, nil end
		if a and here.order and here.instance == instance
			and now - here.checked < ((a == here.a and b == here.b) and here.STILL or here.CHECK) then
			here.asked = false
			if here.order == 1 then here.north, here.west = a, b else here.north, here.west = b, a end
		elseif fresh or here.at ~= now or not here.asked then
			Ask(now, a, b, instance)
		end
		return here.continent, here.north, here.west
	end

	function Shy.Stand()
		local a, b, up = UnitPosition("player")
		if a == nil or b == nil or not here.north1 or issecretvalue(a) or issecretvalue(b) or issecretvalue(up) then return nil end
		if here.north1 == 1 then return a, b, up end
		return b, a, up
	end

	function Shy.HereOn(fresh)
		local continent, north, west = Shy.Here(fresh)
		if here.asked then return here.map, here.x, here.y end
		local map = C_Map.GetBestMapForUnit("player")
		local frame = map and not here.loose[map] and Shy.MapFrame(map)
		if frame and frame[1] == continent and frame[4] ~= 0 and frame[5] ~= 0 then
			return map, (west - frame[3]) / frame[5], (north - frame[2]) / frame[4]
		end
		local position = map and C_Map.GetPlayerMapPosition(map, "player")
		if not position then return map end
		local x, y = position:GetXY()
		if x == nil or issecretvalue(x) or issecretvalue(y) then return map end
		return map, x, y
	end

	-- (Another zone, another floor of one, a loading screen: what agreed a moment ago is asked again.)
	local zones = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
		zones:RegisterEvent(event)
	end
	zones:SetScript("OnEvent", function() here.checked = -math.huge end)
end

-- Addons

local Addon = {}
Addon.__index = Addon
Shy.AddonPrototype = Addon

-- What an addon does, in a line: its .toc's Notes, without the slash command they end on. The one place
-- it is written; the game's addon list shows the Notes whole.
local function Tagline(notes)
	return notes and (notes:gsub("%s*|c%x%x%x%x%x%x%x%x/[^|]*|r%s*$", "")) or nil
end

function Shy:NewAddon(name, info)
	local a = setmetatable(info or {}, Addon)
	a.name = name
	a.suffix = a.suffix or name:gsub("^Shy", "")
	a.version = a.version or GetMeta(name, "Version")
	a.tagline = a.tagline or Tagline(GetMeta(name, "Notes"))
	a.smallIcon = a.smallIcon or a.icon   -- no mini icon yet
	a.mark = a.mark or (a.icon or Shy.ICON) .. "Mark"   -- (one with no art of its own wears the fox)
	if not Shy.addons[a.suffix] then table.insert(Shy.order, a) end
	Shy.addons[a.suffix] = a
	byName[name] = a
	return a
end

-- Where addons are listed (the /shy window, the minimap's menu) they stand under these, in this order, and by
-- name within each. An addon names its own (`category`); one that names none stands under the last.
Shy.CATEGORIES = {
	{ key = "leveling", title = "Leveling" },
	{ key = "combat", title = "Combat" },
	{ key = "items", title = "Items and gold" },
	{ key = "social", title = "Chat and groups" },
	{ key = "interface", title = "Interface" },
	{ key = "other", title = "More" },
}

-- The addons a list shows (none internal; only those `keep(a)` is true of, if given), by category:
-- { { key, title, addons }, ... }, only the categories that hold one.
function Shy.Listed(keep)
	local by, out = {}, {}
	for _, c in ipairs(Shy.CATEGORIES) do by[c.key] = { key = c.key, title = c.title, addons = {} } end
	for _, a in ipairs(Shy.order) do
		if not a.internal and (not keep or keep(a)) then
			local group = by[a.category] or by.other
			group.addons[#group.addons + 1] = a
		end
	end
	for _, c in ipairs(Shy.CATEGORIES) do
		local group = by[c.key]
		if #group.addons > 0 then
			table.sort(group.addons, function(x, y) return x.suffix:lower() < y.suffix:lower() end)
			out[#out + 1] = group
		end
	end
	return out
end

function Addon:Print(msg)
	local B = Shy.Brand
	local icon = B.Icon(self.mark, 14) .. " "
	print(icon .. B.Name(self.suffix) .. "|cff888888:|r " .. tostring(msg))
end

-- Keys named in `keep` are account-wide and survive a reset.
function Addon:ResetDB()
	if not self.db then return end
	for key in pairs(self.db) do
		if not (self.keep and self.keep[key]) then self.db[key] = nil end
	end
	Shy.MergeDefaults(self.db, self.defaults or {})
end

-- Profiles
--
-- A profile is every addon's settings (T.db) together, the core's included (box positions, accent).
-- A character uses Global (the default), its own, or a custom named one.
--
-- Each addon's saved table stays one flat account-wide table holding one profile's settings at a
-- time (named in `live`); the others are copies in ShyCoreDB.profiles. Settings are swapped as an
-- addon loads, before it sees T.db, so a switch takes effect on reload: P.Use, P.CopyFrom and
-- P.Fresh return true when a reload is needed. A new profile is a copy of the current settings
-- and needs none.
--
--   ShyCoreDB.profiles[name] = { kind = "global" | "character" | "custom", data = { [addon] = settings } }
--   ShyCoreDB.uses[character] = name     nil: Global
--   ShyCoreDB.live[addon] = name         nil: Global. NONE: no profile's (P.CopyFrom, P.Fresh)
--   ShyCoreDB.seen[addon] = true         every addon that ever saved settings, loaded or not
--
--   P.Current()          profile this character uses
--   P.Character()        name of this character's own profile ("First Surname - Realm")
--   P.List()             { name, kind, current, mine, new } each: Global, own, then the rest
--   P.Create(name)       custom copy of the current settings, now in use: ok, why ("empty" | "taken")
--   P.Use(name)          switch to it: true when a reload is needed
--   P.CopyFrom(name)     copy its settings into the current profile: true when a reload is needed
--   P.Delete(name)       true when deleted (never Global or the one in use)
--   P.Free(name)         the trimmed name if it is available, else nil, why ("empty" | "taken")
--   P.Fresh(name, kind)  create or empty a profile on default settings and switch to it: needs a reload
--   P.Label(entry)       display text for a List entry

local GLOBAL, NONE = "Global", ""
local P = { GLOBAL = GLOBAL }
Shy.Profiles = P

local function Store()
	local db = ShyCoreDB
	db.profiles, db.uses, db.live, db.seen = db.profiles or {}, db.uses or {}, db.live or {}, db.seen or {}
	return db
end

-- nil for a deleted profile; Global always exists.
local function Profile(name)
	local profiles = Store().profiles
	if name == GLOBAL and not profiles[GLOBAL] then profiles[GLOBAL] = { kind = "global", data = {} } end
	return profiles[name]
end

function P.Character()
	local name, surname = UnitName("player")
	if surname and surname ~= "" then name = name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname end
	return name .. " - " .. GetRealmName()
end

function P.Current()
	local store = Store()
	local name = store.uses[P.Character()]
	return name and store.profiles[name] and name or GLOBAL
end

-- The profile an addon's saved table holds now.
local function Holds(a)
	return Store().live[a.name] or GLOBAL
end

-- Stores a copy of an addon's current settings under a profile.
local function Take(a, name)
	local profile = Profile(name)
	if not profile then return end   -- deleted since
	local copy = {}
	for key, value in pairs(_G[a.savedVariables]) do
		if not (a.keep and a.keep[key]) then copy[key] = type(value) == "table" and Shy.CopyTable(value) or value end
	end
	profile.data[a.name] = copy
end

-- Loads a profile's settings into an addon's saved table. A profile with none for this addon keeps
-- what is there, unless it is `blank` (P.Fresh): then the addon starts from its defaults.
local function Give(a, name)
	local profile, saved = Profile(name), _G[a.savedVariables]
	local settings = profile.data[a.name]
	if settings or profile.blank then
		for key in pairs(saved) do
			if not (a.keep and a.keep[key]) then saved[key] = nil end
		end
		for key, value in pairs(settings or {}) do saved[key] = value end
		profile.data[a.name] = nil
	end
	Store().live[a.name] = name ~= GLOBAL and name or nil
end

local function Pour(a)
	local want, has = P.Current(), Holds(a)
	if want == has then return end
	Take(a, has)
	Give(a, want)
end

-- A change to saved settings made once per account: on the settings in use and on every profile's copy,
-- so switching profiles doesn't bring the old value back. `flag` is account-wide (named in `keep`), so a
-- reset doesn't run it again and a later change by the player stands.
function Addon:Once(flag, fn)
	if not self.db or self.db[flag] then return end
	fn(self.db)
	if ShyCoreDB then
		for _, profile in pairs(Store().profiles) do
			local settings = profile.data and profile.data[self.name]
			if settings then fn(settings) end
		end
	end
	self.db[flag] = true
end

-- A new profile takes over the loaded addons' current settings; the old profile keeps a copy.
local function Start(name, kind)
	local store = Store()
	store.profiles[name] = { kind = kind, data = {} }
	for _, a in ipairs(Shy.order) do
		if a.savedVariables and a.db then
			Take(a, Holds(a))
			store.live[a.name] = name
		end
	end
	store.uses[P.Character()] = name
end

function P.List()
	local store, me, current = Store(), P.Character(), P.Current()
	local out = { { name = GLOBAL, kind = "global" }, { name = me, kind = "character", mine = true, new = store.profiles[me] == nil } }
	local rest = {}
	for name, profile in pairs(store.profiles) do
		if name ~= GLOBAL and name ~= me then rest[#rest + 1] = { name = name, kind = profile.kind } end
	end
	-- Custom profiles first, then other characters', each by name.
	table.sort(rest, function(a, b)
		if a.kind ~= b.kind then return a.kind == "custom" end
		return a.name < b.name
	end)
	for _, entry in ipairs(rest) do out[#out + 1] = entry end
	for _, entry in ipairs(out) do entry.current = entry.name == current end
	return out
end

function P.Label(entry)
	if entry.kind == "global" then return "Global (all characters)" end
	if entry.mine then return "Only " .. (entry.name:match("^(.-) %- ") or entry.name) end
	if entry.kind == "character" then return entry.name .. " (own profile)" end
	return entry.name
end

function P.Free(name)
	name = strtrim(name or "")
	if name == "" then return nil, "empty" end
	if Store().profiles[name] or name:lower() == GLOBAL:lower() or name == P.Character() then return nil, "taken" end
	return name
end

function P.Create(name)
	local free, why = P.Free(name)
	if not free then return false, why end
	Start(free, "custom")
	return true
end

-- Nothing changes before the reload: addons holding this profile are marked NONE so Give resets them
-- as they next load. Don't reset loaded addons here through their options pages' OnDefault: a page
-- that was never opened errors.
function P.Fresh(name, kind)
	local store = Store()
	local profile = Profile(name)
	if not profile then
		profile = { kind = kind or "custom" }
		store.profiles[name] = profile
	end
	profile.data, profile.blank = {}, true
	for addon in pairs(store.seen) do
		if (store.live[addon] or GLOBAL) == name then store.live[addon] = NONE end
	end
	store.uses[P.Character()] = name ~= GLOBAL and name or nil
	return true
end

function P.Use(name)
	local store, me = Store(), P.Character()
	if name == P.Current() then return false end
	if name == me and not store.profiles[me] then
		Start(me, "character")
		return false
	end
	if not Profile(name) then return false end
	store.uses[me] = name ~= GLOBAL and name or nil
	return true
end

-- Applied as the addons next load; until then their tables are marked NONE.
function P.CopyFrom(name)
	local store, current = Store(), P.Current()
	local from = name ~= current and Profile(name)
	if not from then return false end
	local to = Profile(current)
	for addon, settings in pairs(from.data) do
		to.data[addon] = Shy.CopyTable(settings)
		store.live[addon] = NONE
	end
	return true
end

-- Characters that used it go back to Global.
function P.Delete(name)
	local store = Store()
	if name == GLOBAL or name == P.Current() or not store.profiles[name] then return false end
	store.profiles[name] = nil
	for character, used in pairs(store.uses) do
		if used == name then store.uses[character] = nil end
	end
	return true
end

local function SafeCall(obj, method, ...)
	if not obj[method] then return end
	local ok, err = pcall(obj[method], obj, ...)
	if not ok then geterrorhandler()(err) end
end

-- Addon messages: one shared prefix, routed by suffix

C_ChatInfo.RegisterAddonMessagePrefix(Shy.COMM_PREFIX)

function Addon:SendComm(msg, channel, target)
	C_ChatInfo.SendAddonMessage(Shy.COMM_PREFIX, self.suffix .. "\t" .. tostring(msg), channel, target)
end

-- To a Battle.net friend's game account (any realm): heard there as OnBNComm.
function Addon:SendBNComm(msg, gameAccountID)
	C_BattleNet.SendGameData(gameAccountID, Shy.COMM_PREFIX, self.suffix .. "\t" .. tostring(msg))
end

-- nil when solo and guildless.
function Shy.GroupChannel()
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	if IsInGuild() then return "GUILD" end
end

-- Chat and addon messages give "First Surname" as one string; a unit gives them apart.
-- False for a secret name.
function Shy.IsMe(sender)
	if sender == nil or issecretvalue(sender) then return false end
	local name, surname = UnitNameUnmodified("player")
	if surname and surname ~= "" then
		name = name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname
	end
	return Ambiguate(sender, "none") == name
end

-- Your role, for what reads differently for a tank or a healer:
--   Shy.Role()              "tank", "healer" or "dps", and where it comes from ("group", "build", "layout"): the
--                           role your group gave you; else the one of the talent build you follow (the one picked
--                           in setup: Protection is a tank's, Holy a healer's); else the one the layout in use was
--                           made for (ShyDock's tank and healer layouts), when your class can play it. nil when
--                           none says
--   Shy.CanFill(class, role) whether a class can play a role (an unlisted class counts as able to do anything)
--   Shy.SetLayoutRole(role) ShyDock: the layout in use's role, "tank" or "healer", nil for any other
--   Shy.RoleSays()          how your role is told, in words ("Tank, from your Protection build"), or nil
-- Bus SHY_ROLE when the answer changes by the build or the layout (the group's own change is the game's
-- PLAYER_ROLES_ASSIGNED).
do
	local ASSIGNED = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
	local BUILT = { tank = "tank", healer = "healer", damage = "dps" }
	local NAMED = { tank = "Tank", healer = "Healer", dps = "Damage" }
	local CLASS_ROLES = {
		WARRIOR = { tank = true, dps = true },
		PALADIN = { tank = true, healer = true, dps = true },
		DRUID   = { tank = true, healer = true, dps = true },
		PRIEST  = { healer = true, dps = true },
		SHAMAN  = { healer = true, dps = true },
		HUNTER  = { dps = true },
		ROGUE   = { dps = true },
		MAGE    = { dps = true },
		WARLOCK = { dps = true },
	}
	local layoutRole
	local last               -- the answer the build and the layout gave when last asked

	function Shy.CanFill(class, role)
		local roles = class and CLASS_ROLES[class]
		return not roles or roles[role] or false
	end

	-- The build you follow (ShyQuest's), when it is there: its role, and its name.
	local function Built()
		local quest = Shy.addons.Quest
		local build = quest and quest.Build and quest:Build()
		if build and BUILT[build.role] then return BUILT[build.role], build.name end
	end

	-- What the build, then the layout, say: the role, where from, and the build's name.
	local function Own()
		local role, name = Built()
		if role then return role, "build", name end
		if layoutRole and Shy.CanFill(select(2, UnitClass("player")), layoutRole) then return layoutRole, "layout" end
	end

	function Shy.Role()
		local role = UnitGroupRolesAssigned("player")
		if not issecretvalue(role) and ASSIGNED[role] then return ASSIGNED[role], "group" end
		return Own()
	end

	function Shy.RoleSays()
		local role, from, name = Shy.Role()
		if not role then return nil end
		if from == "group" then return NAMED[role] .. ", as your group has you" end
		if from == "build" then return ("%s, from your %s build"):format(NAMED[role], name) end
		return NAMED[role] .. ", from your screen's layout"
	end

	-- Said when the build or the layout changes the answer.
	local function Changed()
		local role = Own()
		if role == last then return end
		last = role
		Shy:Fire("SHY_ROLE", role)
	end

	function Shy.SetLayoutRole(role)
		if role ~= "tank" and role ~= "healer" then role = nil end
		if role == layoutRole then return end
		layoutRole = role
		Changed()
	end

	Shy:On("SHY_BUILD", Changed)
	Shy:On("SHY_TALENTS", Changed)
	Shy:On("SHY_LOGIN", Changed)
end

-- How threat is read for you: the family's one choice (the threat meter, the nameplates' threat colors, a class's
-- screen light all read it) and its one warning sound.
--   Shy.ThreatRole()           "tank" or "dps": the pick; else by your role (Shy.Role); else a class's hint (a
--                              warrior's Defensive Stance); else anyone else's
--   Shy.ThreatRolePick()       "auto", "tank" or "dps"            Shy.SetThreatRole(pick)   bus SHY_THREAT_ROLE
--   Shy.TankHint(fn)           a class addon: fn() says whether how you stand now is a tank's (asked only with no
--                              role from the group, the build or the layout)
--   Shy.AdoptThreatRole(pick)  an addon's own pick from before there was one: taken once, while the family's is "auto"
--   Shy.ThreatSound()          whether aggro changing hands plays the warning (Shy.Aggro)   Shy.SetThreatSound(on)
do
	local hints = {}
	local function Saved() return Shy.core and Shy.core.db and Shy.core.db.threat end

	function Shy.ThreatRolePick()
		local saved = Saved()
		local pick = saved and saved.role
		if pick == "tank" or pick == "dps" then return pick end
		return "auto"
	end

	function Shy.ThreatRole()
		local pick = Shy.ThreatRolePick()
		if pick ~= "auto" then return pick end
		local role = Shy.Role()
		if role then return role == "tank" and "tank" or "dps" end
		for _, hint in ipairs(hints) do
			if hint() then return "tank" end
		end
		return "dps"
	end

	function Shy.SetThreatRole(pick)
		local saved = Saved()
		if not saved then return end
		if pick ~= "tank" and pick ~= "dps" then pick = "auto" end
		if saved.role == pick then return end
		saved.role = pick
		Shy:Fire("SHY_THREAT_ROLE", pick)
	end

	function Shy.AdoptThreatRole(pick)
		if (pick == "tank" or pick == "dps") and Shy.ThreatRolePick() == "auto" then Shy.SetThreatRole(pick) end
	end

	function Shy.TankHint(fn) hints[#hints + 1] = fn end

	function Shy.ThreatSound()
		local saved = Saved()
		return not (saved and saved.sound == false)
	end

	function Shy.SetThreatSound(on)
		local saved = Saved()
		if saved then saved.sound = on and true or false end
	end
end

-- Your threat on a unit, in a group only. Shy.Threat(unit, mode) returns `margin, fighting, tanking, flip`:
--   mode      "tank", "dps", "auto" (as Shy.ThreatRole reads you) or "off"
--   margin    1 as it should be with room to spare (a tank holds it with a lead no one can pull through;
--             a damage dealer or healer is far from pulling), down through 0.5 (slipping) to 0 (a tank has
--             lost it; it is on you and you are no tank); "theirs" when another tank holds it; nil when
--             there is nothing to say (solo, not fighting you, the mode is off, or the game keeps it secret)
--   fighting  the unit is in combat with you
--   tanking   with no margin, when the game keeps the numbers secret but says whether you are tanking it:
--             a boolean, itself secret, for a boolean-evaluating setter (nil when even that is secret)
--   flip      true when that boolean means trouble (you are no tank): the setter wants the opposite
-- A tank's lead: UnitThreatPercentageOfLead is your threat as a share of the next player's (100 is level).
-- A melee attacker pulls at 110, a ranged one at 130: at 130 and over nothing can take it from you.
-- A damage dealer's share: UnitDetailedThreatSituation's scaled percentage, 100 being the pull.
do
	local LEAD_SAFE, LEAD_LEVEL = 130, 100   -- a tank's lead: held from here; lost at level with the next player
	local PULL_FAR, PULL = 60, 100           -- a damage dealer's share: held up to here; lost at the pull
	local LEAD_STEPS = { [0] = 1, 0.66, 0.33, 0.1 }   -- UnitThreatLeadSituation: none, yellow, orange, red

	local function IsTank(mode)
		if mode == "tank" then return true end
		if mode == "dps" then return false end
		return Shy.ThreatRole() == "tank"
	end

	local function Clamp(x)
		if x < 0 then return 0 elseif x > 1 then return 1 end
		return x
	end

	-- Whether the unit's own target is another player tanking it: a tank by role, or a pet.
	local function Theirs(unit)
		local target = unit .. "target"
		if not UnitExists(target) then return false end
		if target == "playertarget" then return false end
		local pet = UnitIsUnit(target, "pet")
		if not issecretvalue(pet) and pet then return true end
		local player = UnitIsPlayer(target)
		if issecretvalue(player) or not player then return false end
		local role = UnitGroupRolesAssigned(target)
		return not issecretvalue(role) and role == "TANK"
	end

	function Shy.Threat(unit, mode)
		if mode == "off" then return nil, false end
		local status = UnitThreatSituation("player", unit)
		if status == nil then return nil, false end
		if issecretvalue(status) then
			-- The state is secret: ask whether you are tanking it, and hand that on.
			if not IsInGroup() then return nil, false end
			local tanking = UnitDetailedThreatSituation("player", unit)
			if not issecretvalue(tanking) and tanking == nil then return nil, false end
			if IsTank(mode) then return nil, true, tanking end
			return nil, true, tanking, true
		end
		if not IsInGroup() then return nil, true end
		if IsTank(mode) then
			if status >= 2 then
				local lead = UnitThreatPercentageOfLead("player", unit)
				if lead ~= nil and not issecretvalue(lead) then
					return Clamp((lead - LEAD_LEVEL) / (LEAD_SAFE - LEAD_LEVEL)), true
				end
				local step = UnitThreatLeadSituation("player", unit)
				if step ~= nil and not issecretvalue(step) and LEAD_STEPS[step] then return LEAD_STEPS[step], true end
				return status == 3 and 1 or 0.4, true
			end
			if status == 1 then return 0.15, true end
			if Theirs(unit) then return "theirs", true end
			return 0, true
		end
		if status >= 2 then return 0, true end
		if status == 1 then return 0.1, true end
		local _, _, share = UnitDetailedThreatSituation("player", unit)
		if share ~= nil and not issecretvalue(share) then return Clamp((PULL - share) / (PULL - PULL_FAR)), true end
		return 1, true
	end
end

-- Who has the mobs you fight: your target and every nameplate, in a group fight, each read by Shy.Threat as
-- Shy.ThreatRole has you. A mob is told apart by its GUID, or where that is secret (a dungeon) by its nameplate,
-- which stands for one mob while it shows, or as your target while it has none.
--   Shy.Aggro.Want(id, on)   an addon asks for it (the threat meter, a class's light); nothing runs while none does
--   Shy.Aggro.Worst()        the worst margin over them now (Shy.Threat's), or nil
--   Shy.Aggro.Loose()        read as a tank: how many of the mobs you are fighting are on someone who is no tank
--                            (another tank's are theirs, not loose); nil when you read as no tank or nothing runs
-- Bus SHY_AGGRO(change) after a look that changed anything. change: "lost" (read as a tank: a mob you held went to
-- someone who is no tank), "pulled" (read as no tank: a mob came onto you), "back" (a lost one taken back), or nil
-- (the margin or the count moved). The family's warning sound plays here, and only here, at "lost" and "pulled",
-- once in a few seconds, while Shy.ThreatSound() says so: two addons warning of the same thing play it once.
do
	local A = { wanted = {} }
	Shy.Aggro = A
	local EVERY = 0.2      -- seconds between looks in a fight
	local GAP = 3          -- seconds at least between two warning sounds
	local worst, loose     -- the last look's answers
	local held = {}        -- mob -> true while it was on you, "lost" once a tank's turned
	local soundAt = 0
	local driver

	local function Readable(v) return not issecretvalue(v) and v ~= nil end

	-- The units to ask, each with what tells its mob apart when the GUID won't.
	local function Units()
		local list = {}
		for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
			if not plate:IsForbidden() and plate.unitToken then list[#list + 1] = { plate.unitToken, plate } end
		end
		if UnitExists("target") and not C_NamePlate.GetNamePlateForUnit("target") then list[#list + 1] = { "target", "target" } end
		return list
	end

	-- Of two changes in one look, the one to tell: a loss first, then a pull, then one taken back.
	local RANK = { lost = 3, pulled = 2, back = 1 }

	local function Look()
		local tank = Shy.ThreatRole() == "tank"
		local mode = tank and "tank" or "dps"
		local least, count, change = nil, 0, nil
		local seen = {}
		local function Note(what)
			if not change or RANK[what] > RANK[change] then change = what end
		end
		-- (Solo there is no one to lose a mob to: nothing is read.)
		for _, u in ipairs(IsInGroup() and Units() or {}) do
			local unit = u[1]
			local guid = UnitGUID(unit)
			local key = Readable(guid) and guid or u[2]
			local can = UnitCanAttack("player", unit)
			if not seen[key] and Readable(can) and can then
				seen[key] = true
				local m = Shy.Threat(unit, mode)
				if type(m) == "number" then
					if least == nil or m < least then least = m end
					if tank and m == 0 then count = count + 1 end
				end
				local status = UnitThreatSituation("player", unit)
				if Readable(status) then
					if status >= 2 then
						if held[key] == "lost" then Note("back")
						elseif held[key] == nil and not tank then Note("pulled") end
						held[key] = true
					elseif held[key] == true then
						if tank and m ~= "theirs" then
							held[key] = "lost"
							Note("lost")
						else
							held[key] = nil
						end
					end
				end
			end
		end
		-- A mob no longer seen (gone from the screen, dead) is forgotten.
		for key in pairs(held) do
			if not seen[key] then held[key] = nil end
		end
		if not tank or not IsInGroup() then count = nil end
		local moved = change ~= nil or least ~= worst or count ~= loose
		worst, loose = least, count
		if (change == "lost" or change == "pulled") and Shy.ThreatSound() and GetTime() - soundAt > GAP then
			soundAt = GetTime()
			PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING, "Master")
		end
		if moved then Shy:Fire("SHY_AGGRO", change) end
	end

	local function Wake()
		local on = next(A.wanted) ~= nil and UnitAffectingCombat("player") == true
		driver:SetShown(on)
		if on then
			Look()
			return
		end
		wipe(held)
		if worst ~= nil or loose ~= nil then
			worst, loose = nil, nil
			Shy:Fire("SHY_AGGRO", nil)
		end
	end

	function A.Want(id, on)
		A.wanted[id] = on and true or nil
		Wake()
	end
	function A.Worst() return worst end
	function A.Loose() return loose end

	driver = CreateFrame("Frame")
	driver:Hide()
	local wait = 0
	driver:SetScript("OnUpdate", function(_, dt)
		wait = wait - dt
		if wait > 0 then return end
		wait = EVERY
		Look()
	end)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", Wake)
	Shy:On("SHY_THREAT_ROLE", function()
		wipe(held)
		Wake()
	end)
end

-- Game settings an addon holds
--
--   Shy.Hold(setting, value)   a game setting (CVar) stays at `value` while the addon that asks is on,
--                              whatever else changes it. Asked at every load, no later than login.
--
-- What the character had is kept (ShyCoreDB.held, by character) the first time the setting is changed
-- for a hold, and given back at the first login where nothing holds it any more: the addon was
-- switched off. A setting changed while it is held is put back a frame later, not from inside the
-- game's own telling of the change: the game tells its listeners one after another, and one that came
-- after us would hear the old news last and act on it.

local holds = {}      -- setting -> the value it is held at, as text
local refused = {}    -- setting -> true: the game would not take it; not tried again before a reload
local loggedIn, putting = false, false

-- CVars come back as text: "0" and "0.000000" are the same value.
local function Same(a, b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and x == y
end

-- What this character had: setting -> { what it had, what it was held at }. make: for writing.
local function Had(make)
	local all = ShyCoreDB.held
	if not all then
		if not make then return nil end
		all = {}
		ShyCoreDB.held = all
	end
	local me = P.Character()
	if not all[me] and make then all[me] = {} end
	return all[me]
end

local function Put(setting)
	local value = holds[setting]
	local now = C_CVar.GetCVar(setting)
	if now == nil or refused[setting] or Same(now, value) then return end
	C_CVar.SetCVar(setting, value)
	-- The game keeps some settings from addons without a word, so the value is read back.
	if not Same(C_CVar.GetCVar(setting), value) then
		refused[setting] = true
		return
	end
	local had = Had(true)
	if had[setting] == nil then had[setting] = { now, value } end
end

local function PutAll()
	for setting in pairs(holds) do Put(setting) end
end

-- At login, once every addon has asked: the held settings are set, and what nothing holds any more
-- goes back to what the character had, unless it was changed since it was last held.
local function Settle()
	loggedIn = true
	PutAll()
	local had = Had()
	if not had then return end
	for setting, kept in pairs(had) do
		if holds[setting] == nil then
			if Same(C_CVar.GetCVar(setting), kept[2]) then C_CVar.SetCVar(setting, kept[1]) end
			had[setting] = nil
		end
	end
	if next(had) == nil then ShyCoreDB.held[P.Character()] = nil end
end

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function(_, event, setting, value)
	if event ~= "CVAR_UPDATE" then
		PutAll()
	elseif holds[setting] ~= nil and not putting and not Same(value, holds[setting]) then
		putting = true
		C_Timer.After(0, function()
			putting = false
			PutAll()
		end)
	end
end)

function Shy.Hold(setting, value)
	holds[setting] = tostring(value)
	watch:RegisterEvent("CVAR_UPDATE")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	if loggedIn then Put(setting) end
end

-- Lifecycle

-- An addon for one class (its TOC's "X-Shy-Class: ROGUE") is switched off for a character of another, from
-- its next login: it does nothing for them and needn't load. Quietly: nothing to do about it, and the
-- addon list shows it. The game keeps a change to its addon list only once it is saved.
-- Your own class's, installed but off for you (a character the game had kept another addon list for), is
-- switched on once, and a reload offered; switched off by you after that, it stays off (ShyCoreDB.woken).
local function Classed()
	local class, guid, changed = UnitClassBase("player"), UnitGUID("player"), false
	for _, a in ipairs(Shy.order) do
		local only = GetMeta(a.name, "X-Shy-Class")
		if only and only ~= "" and only ~= class then
			C_AddOns.DisableAddOn(a.name, guid)
			changed = true
		end
	end
	local me = P.Character()
	ShyCoreDB.woken = ShyCoreDB.woken or {}
	local woken = ShyCoreDB.woken[me] or {}
	local named = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and GetMeta(name, "X-Shy-Class") == class and not C_AddOns.IsAddOnLoaded(name) and not woken[name] then
			C_AddOns.EnableAddOn(name, guid)
			woken[name] = true
			named[#named + 1] = name
			changed = true
		end
	end
	if next(woken) then ShyCoreDB.woken[me] = woken end
	if changed then C_AddOns.SaveAddOns() end
	if #named > 0 then
		Shy.Reload(("%s was off for this character. Reload to turn it on."):format(table.concat(named, ", ")))
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("BN_CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local a = byName[...]
		if not a then return end
		if a.savedVariables then
			a.isNew = _G[a.savedVariables] == nil   -- nothing was ever saved for it on this account
			_G[a.savedVariables] = _G[a.savedVariables] or {}
			if ShyCoreDB then Store().seen[a.name] = true end
			-- Must run before a.db is set; under pcall so a profile error can't stop the addon loading.
			local ok, err = pcall(Pour, a)
			if not ok then geterrorhandler()(err) end
			a.db = Shy.MergeDefaults(_G[a.savedVariables], a.defaults or {})
		end
		-- (The census, asked for before this reload: on before the core's own OnLoad and every addon after it,
		-- for this session alone.)
		if a == Shy.core and a.db and a.db.census then
			a.db.census = nil
			census.Start()
		end
		SafeCall(a, "OnLoad")
		Shy:Fire("SHY_ADDON_LOADED", a)
	elseif event == "PLAYER_LOGIN" then
		for _, a in ipairs(Shy.order) do SafeCall(a, "OnLogin") end
		Shy:Fire("SHY_LOGIN")
		local ok, err = pcall(Settle)
		if not ok then geterrorhandler()(err) end
		ok, err = pcall(Classed)
		if not ok then geterrorhandler()(err) end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, text, channel, sender = ...
		if prefix ~= Shy.COMM_PREFIX then return end
		local suffix, body = text:match("^([^\t]*)\t(.*)$")
		local a = suffix and Shy.addons[suffix]
		if not a then return end
		SafeCall(a, "OnComm", body, sender, channel)
		Shy:Fire("SHY_COMM", a, body, sender, channel)
	elseif event == "BN_CHAT_MSG_ADDON" then
		local prefix, text, _, senderID = ...
		if prefix ~= Shy.COMM_PREFIX then return end
		local suffix, body = text:match("^([^\t]*)\t(.*)$")
		local a = suffix and Shy.addons[suffix]
		if not a then return end
		SafeCall(a, "OnBNComm", body, senderID)
		Shy:Fire("SHY_BN_COMM", a, body, senderID)
	end
end)

-- `internal` keeps the core out of the hub list and menus.
Shy.core = Shy:NewAddon(CORE, {
	suffix = "Core",
	icon = Shy.ICON,
	smallIcon = Shy.SMALL_ICON,
	internal = true,
	savedVariables = "ShyCoreDB",
	-- strength: panel opacity in percent (Theme.lua). rest: seconds the mouse rests on a thing before its
	-- hover shows more (Hover.lua). immersion: Immersion.lua.
	defaults = { splash = true, minimap = true, minimapAngle = 200, hud = {}, theme = { mode = "class", hue = 212 }, slot = "now",
		strength = 55, sheet = 88, rest = 1, immersion = { immersive = false, fade = false },
		-- threat: how it is read for you and whether aggro changing hands sounds (Shy.ThreatRole, Shy.ThreatSound).
		threat = { role = "auto", sound = true } },
	keep = { profiles = true, uses = true, live = true, seen = true, held = true },
})
