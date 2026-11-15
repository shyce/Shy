-- What the window reads, sampled while it is open: the game's profiler, the heap, each addon's memory
-- and errors. Every ring is made once and never grows; closed, nothing here runs.
--
--   S.names                 the loaded Shy addons, in the game's order (S.Names() reads them again)
--   S.by[name]              { data, share, now, avg, peak, last, over1 ... over1000, inUse, errors,
--                             msRing, memRing }: the profiler's numbers now, memory in use (KB) and
--                             the last two minutes of each, a second apart; `data` for an addon that is
--                             only data (a world's ground), which the profiler never times
--   S.frame.game / .addons  the game's and all addons' ms a frame, a second apart, two minutes
--   S.heap                  the heap in KB, a second apart, ten minutes
--   S.game, S.all, S.heapNow, S.top (the costliest addons of all), S.off (the profiler is off)
--   S.errorsFresh, S.errorsTotal
--   S.Tick(now)             the refresh: the profiler twice a second, the rings once, memory every thirty
--   S.Mark(label)           a moment while the window is open (combat, loot), seconds since Reset
--   S.marks                   { t, label }, for Copy's timeline
--   S.Reset()               the rings emptied

local _, ns = ...
local S = {}
ns.Samples = S
local Ring = ns.Ring

-- Seconds between UpdateAddOnMemoryUsage: it walks every addon's memory, some 45 ms of one frame with the family
-- loaded, a hitch of the window's own making that the profiler then charges to whoever's frame it ran in (it is
-- kept out of the hitches written down, Shy.Excuse, and out of fights). The costliest addons are listed every
-- TOP_EVERY.
local MEMORY_EVERY, TOP_EVERY = 30, 5
local TOP = 8            -- the costliest addons of all, listed

S.frame = { game = Ring.New(120), addons = Ring.New(120) }
S.heap = Ring.New(600)
S.by = {}
S.names = {}
S.top = {}
S.game, S.all, S.heapNow = 0, 0, 0
S.errorsFresh, S.errorsTotal = 0, 0
S.off = false
S.marks = {}
local lastSecond, lastMemory, lastTop = 0, 0, 0

function S.Mark(label)
	S.marks[#S.marks + 1] = { t = GetTime() - Shy.ClocksSince(), label = label }
end

-- An addon that is only data (a world's ground): registered nothing, clocks nothing, counts nothing.
local function Registered(name)
	for _, addon in ipairs(Shy.order) do
		if addon.name == name then return true end
	end
	for _, clock in pairs(Shy.Clocks()) do
		if clock.addon == name then return true end
	end
	for _, set in ipairs(Shy.CounterSets()) do
		if set.addon == name then return true end
	end
	for _, cache in ipairs(Shy.Memory.Caches()) do
		if cache.addon == name then return true end
	end
	return false
end

function S.Names()
	for i = #S.names, 1, -1 do S.names[i] = nil end
	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(index)
		if name and name:find("^Shy") and C_AddOns.IsAddOnLoaded(name) then
			S.names[#S.names + 1] = name
			local a = S.by[name]
			if not a then
				a = { share = 0, now = 0, avg = 0, peak = 0, last = 0,
					over1 = 0, over5 = 0, over10 = 0, over50 = 0, over100 = 0, over500 = 0, over1000 = 0,
					inUse = 0, errors = 0, msRing = Ring.New(120), memRing = Ring.New(120) }
				S.by[name] = a
			end
			a.data = not Registered(name)
		end
	end
end

-- The profiler's numbers now. Allocates nothing: every value lands in a field that exists.
local function Profile()
	local P, M = C_AddOnProfiler, Enum.AddOnProfilerMetric
	if not (P and P.IsEnabled()) then
		S.off = true
		return
	end
	S.off = false
	local app, all = P.GetApplicationMetric(M.RecentAverageTime), P.GetOverallMetric(M.RecentAverageTime)
	S.game, S.all = app, all
	for _, name in ipairs(S.names) do
		local a = S.by[name]
		if not a.data then
			local own = P.GetAddOnMetric(name, M.RecentAverageTime)
			local whole = app - all + own
			a.now = own
			a.share = whole > 0 and own / whole * 100 or 0
			a.avg = P.GetAddOnMetric(name, M.SessionAverageTime)
			a.peak = P.GetAddOnMetric(name, M.PeakTime)
			a.last = P.GetAddOnMetric(name, M.LastTime)
			a.over1 = P.GetAddOnMetric(name, M.CountTimeOver1Ms)
			a.over5 = P.GetAddOnMetric(name, M.CountTimeOver5Ms)
			a.over10 = P.GetAddOnMetric(name, M.CountTimeOver10Ms)
			a.over50 = P.GetAddOnMetric(name, M.CountTimeOver50Ms)
			a.over100 = P.GetAddOnMetric(name, M.CountTimeOver100Ms)
			a.over500 = P.GetAddOnMetric(name, M.CountTimeOver500Ms)
			a.over1000 = P.GetAddOnMetric(name, M.CountTimeOver1000Ms)
		end
	end
end

-- Memory in use, by addon (the game's walk of every addon, so seldom), and the costliest addons of all (a
-- list the game makes new each time, so every few seconds).
local function Memory()
	-- (The window's own doing: not written down among the game's hitches.)
	if Shy.Excuse then Shy.Excuse() end
	UpdateAddOnMemoryUsage()
	for _, name in ipairs(S.names) do
		local a = S.by[name]
		a.inUse = GetAddOnMemoryUsage(name)
		a.memRing:Push(a.inUse)
	end
end
local function Top()
	if not S.off then
		S.top = C_AddOnProfiler.GetTopKAddOnsForMetric(Enum.AddOnProfilerMetric.RecentAverageTime, TOP) or S.top
	end
end

-- Errors by addon, from the bag.
local function Errors()
	for _, name in ipairs(S.names) do S.by[name].errors = 0 end
	S.errorsFresh, S.errorsTotal = 0, 0
	local E = Shy.Errors
	if not E then return end
	for _, entry in ipairs(E.List()) do
		S.errorsTotal = S.errorsTotal + 1
		local a = entry.addon and S.by[entry.addon]
		if a then a.errors = a.errors + 1 end
	end
	S.errorsFresh = E.Fresh()
end

function S.Tick(now)
	Profile()
	S.heapNow = collectgarbage("count")
	if now - lastSecond >= 1 then
		lastSecond = now
		S.frame.game:Push(S.game)
		S.frame.addons:Push(S.all)
		S.heap:Push(S.heapNow)
		for _, name in ipairs(S.names) do
			local a = S.by[name]
			a.msRing:Push(a.now)
		end
	end
	-- (Never in a fight: the walk is a hitch, and a fight is what is being watched. It comes once the fight is over.)
	if now - lastMemory >= MEMORY_EVERY and not InCombatLockdown() then
		lastMemory = now
		Memory()
	end
	if now - lastTop >= TOP_EVERY then
		lastTop = now
		Top()
	end
	Errors()
end

-- The share of the frame an addon takes, as the game's addon list counts it: its time against the game's
-- own with every other addon's taken out.
function S.Share(name)
	local P, M = C_AddOnProfiler, Enum.AddOnProfilerMetric
	local own = P.GetAddOnMetric(name, M.RecentAverageTime)
	local whole = S.game - S.all + own
	return whole > 0 and own / whole * 100 or 0
end

function S.Reset()
	S.frame.game:Clear()
	S.frame.addons:Clear()
	S.heap:Clear()
	for _, a in pairs(S.by) do
		a.msRing:Clear()
		a.memRing:Clear()
	end
	for i = #S.marks, 1, -1 do S.marks[i] = nil end
	lastSecond, lastMemory, lastTop = 0, 0, 0
end
