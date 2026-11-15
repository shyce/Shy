-- Memory, the costly questions, each asked on purpose: a full clean-up (what each addon holds once the
-- game has taken the rest back), the same every so often while Watch is on, what each cache frees, what a
-- kept table weighs, and what the addons make in ten seconds with the clean-up held off. And the
-- judgement: memory held that keeps growing while the player stands still, a cache that does, a counter
-- that moves while nothing should.
--
--   M.Collect(now)            a full clean-up now: M.heapKept, M.kept[addon], the rings, then the judgement
--   M.SetWatch(on)            a clean-up every T.db.watch seconds while the window is open
--   M.Empty(cache)            empties one cache; M.freed[cache] = KB it freed
--   M.Weigh(root, seen)       entries and tables under a table (each once; frames are the game's and not walked)
--   M.WeighAddon(name)        weighs what the addon registered to keep: M.weighed[name] = { { name, entries, tables } }
--   M.StartChurn(seconds)     the clean-up held off that long; M.churnBy[addon] = KB a second once it ends
--   M.Tick(now)               the refresh's share: stillness, Watch, the idle check, the churn's countdown
--   M.flags[addon] -> a few words; M.cacheFlags[cache]; ns.Flags the sentences for Copy; ns.FlagOf(name)

local _, ns = ...
local T = ns.T
local M = {}
ns.Memory = M
local S, Ring = ns.Samples, ns.Ring
local format, max = string.format, math.max

local KEPT = 40             -- samples of what is held after a clean-up (20 min at 30 s)
local LEAST = 6             -- samples before growth is judged
local FIT = 0.8             -- how steady the growth must be (r squared of a line through the samples)
local ADDON_GROWTH = 1024   -- KB over the window, for an addon
local CACHE_GROWTH = 0.25   -- a share of its first size, for a cache
local STILL = 10            -- seconds standing still before a counter that moves is flagged
local IDLE_EVERY = 5        -- seconds between looks at the counters marked idle
local CHURN = 10            -- seconds the clean-up is held off

M.kept = {}
M.keptRings = {}
M.cacheRings = {}
M.times = Ring.New(KEPT)
M.freed = {}
M.weighed = {}
M.flags = {}
M.cacheFlags = {}
M.idleFlags = {}      -- addon -> { label -> sentence }
M.churnBy = {}
M.churn = { running = false, from = {}, seconds = CHURN }
M.watch = false
M.stillSince = nil
ns.Flags = {}
local lastIdle = 0
local idleState = {}  -- set -> { last = {}, flagged = {} };  clock -> last calls
local flagsDirty = false

-- Standing still: no moving, no fight. Moving ends the window every judgement is made over.
local function Still(now)
	local still = not IsPlayerMoving() and not InCombatLockdown()
	if still then
		M.stillSince = M.stillSince or now
	elseif M.stillSince then
		M.stillSince = nil
		M.times:Clear()
		for _, ring in pairs(M.keptRings) do ring:Clear() end
		for _, ring in pairs(M.cacheRings) do ring:Clear() end
		for _, state in pairs(idleState) do
			if type(state) == "table" then
				for label in pairs(state.last) do state.last[label] = nil end
			end
		end
	end
end

-- A line through the samples: its slope a sample, and how well it fits.
local function Fit(ring)
	local n = ring.count
	local sx, sy, sxx, sxy, syy = 0, 0, 0, 0, 0
	for i = 1, n do
		local y = ring:Get(i)
		sx, sy, sxx, sxy, syy = sx + i, sy + y, sxx + i * i, sxy + i * y, syy + y * y
	end
	local den = n * sxx - sx * sx
	if den == 0 then return 0, 0 end
	local slope = (n * sxy - sx * sy) / den
	local dy = n * syy - sy * sy
	local r2 = dy > 0 and ((n * sxy - sx * sy) ^ 2) / (den * dy) or 0
	return slope, r2
end

local function Judge()
	for name in pairs(M.flags) do M.flags[name] = nil end
	for cache in pairs(M.cacheFlags) do M.cacheFlags[cache] = nil end
	local flags = ns.Flags
	for i = #flags, 1, -1 do flags[i] = nil end
	if M.stillSince and M.times.count >= LEAST then
		local minutes = max(1, (M.times:Last() - M.times:Get(1)) / 60)
		for _, name in ipairs(S.names) do
			local ring = M.keptRings[name]
			if ring and ring.count >= LEAST then
				local slope, r2 = Fit(ring)
				local growth = ring:Last() - ring:Get(1)
				if slope > 0 and r2 >= FIT and growth >= ADDON_GROWTH then
					M.flags[name] = format("+%.1f MB in %.0f min, still", growth / 1024, minutes)
					flags[#flags + 1] = format("%s: memory held grew %.1f MB in %.0f min standing still", name, growth / 1024, minutes)
				end
			end
		end
		for _, cache in ipairs(Shy.Memory.Caches()) do
			local ring = M.cacheRings[cache]
			if ring and ring.count >= LEAST then
				local first, last = ring:Get(1), ring:Last()
				local slope, r2 = Fit(ring)
				if slope > 0 and r2 >= FIT and first > 0 and last - first >= first * CACHE_GROWTH then
					M.cacheFlags[cache] = format("%d to %d in %.0f min, standing still", first, last, minutes)
					flags[#flags + 1] = format("%s: cache \"%s\" grew from %d to %d in %.0f min standing still", cache.addon, cache.name, first, last, minutes)
					if not M.flags[cache.addon] then M.flags[cache.addon] = "a cache grows, still" end
				end
			end
		end
	end
	for addon, by in pairs(M.idleFlags) do
		for _, sentence in pairs(by) do
			flags[#flags + 1] = sentence
			if not M.flags[addon] then M.flags[addon] = "works while still" end
		end
	end
	flagsDirty = false
end

function M.Collect(now)
	now = now or GetTime()
	M.heapBefore = collectgarbage("count")
	if Shy.Excuse then Shy.Excuse() end   -- (a clean-up asked for: no hitch of the game's)
	collectgarbage("collect")
	collectgarbage("collect")
	M.heapKept, M.keptAt = collectgarbage("count"), now
	UpdateAddOnMemoryUsage()
	for _, name in ipairs(S.names) do
		local kb = GetAddOnMemoryUsage(name)
		M.kept[name] = kb
		local ring = M.keptRings[name]
		if not ring then
			ring = Ring.New(KEPT)
			M.keptRings[name] = ring
		end
		ring:Push(kb)
	end
	for _, cache in ipairs(Shy.Memory.Caches()) do
		if cache.size then
			local ring = M.cacheRings[cache]
			if not ring then
				ring = Ring.New(KEPT)
				M.cacheRings[cache] = ring
			end
			local ok, size = pcall(cache.size)
			ring:Push(ok and tonumber(size) or 0)
		end
	end
	M.times:Push(now)
	Judge()
end

function M.SetWatch(on)
	M.watch = on and true or false
end

function M.Empty(cache)
	collectgarbage("collect")
	local had = collectgarbage("count")
	local ok, err = pcall(cache.clear)
	if not ok then geterrorhandler()(err) end
	collectgarbage("collect")
	M.freed[cache] = max(0, had - collectgarbage("count"))
	return M.freed[cache]
end

-- How many entries a table holds, and how many tables lie under it (each once). A frame is the game's,
-- whoever holds it: its table is not walked, nor the game's tables under it.
function M.Weigh(root, seen)
	local entries, tables = 0, 0
	local stack, top = { root }, 1
	seen[root] = true
	while top > 0 do
		local t = stack[top]
		stack[top] = nil
		top = top - 1
		tables = tables + 1
		for _, value in next, t do
			entries = entries + 1
			if type(value) == "table" and not seen[value] and value ~= _G and type(rawget(value, 0)) ~= "userdata" then
				seen[value] = true
				top = top + 1
				stack[top] = value
			end
		end
	end
	return entries, tables
end

function M.WeighAddon(name)
	local list = {}
	for _, keep in ipairs(Shy.Memory.Kept()) do
		if keep.addon == name and type(keep.table) == "table" then
			local entries, tables = M.Weigh(keep.table, {})
			list[#list + 1] = { name = keep.name, entries = entries, tables = tables }
		end
	end
	for _, space in ipairs(Shy.Memory.Spaces()) do
		if space.addon == name and type(space.space) == "table" then
			for key, value in pairs(space.space) do
				if type(value) == "table" then
					local entries, tables = M.Weigh(value, {})
					if entries > 300 then list[#list + 1] = { name = space.name .. "." .. tostring(key), entries = entries, tables = tables } end
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.entries > b.entries end)
	M.weighed[name] = list
	return list
end

-- The churn: the game's clean-up held off, memory counted by addon as it climbs. Ends on the game's own
-- timer, so a closed window never leaves the clean-up off.
local function EndChurn()
	local c = M.churn
	if not c.running then return end
	if Shy.Excuse then Shy.Excuse() end
	UpdateAddOnMemoryUsage()
	local total = 0
	for _, name in ipairs(S.names) do
		local kb = (GetAddOnMemoryUsage(name) - (c.from[name] or 0)) / c.seconds
		M.churnBy[name] = max(0, kb)
		total = total + max(0, kb)
	end
	M.churnTotal = (collectgarbage("count") - c.heapFrom) / c.seconds
	M.churnAt = GetTime()
	collectgarbage("restart")
	c.running = false
end
function M.StartChurn(seconds)
	local c = M.churn
	if c.running or InCombatLockdown() then return false end
	c.seconds = seconds or CHURN
	if Shy.Excuse then Shy.Excuse() end
	collectgarbage("collect")
	UpdateAddOnMemoryUsage()
	for _, name in ipairs(S.names) do c.from[name] = GetAddOnMemoryUsage(name) end
	c.heapFrom = collectgarbage("count")
	c.at = GetTime()
	c.running = true
	collectgarbage("stop")
	C_Timer.After(c.seconds, EndChurn)
	return true
end
function M.StopChurn()
	if M.churn.running then
		collectgarbage("restart")
		M.churn.running = false
	end
end
function M.ChurnLeft(now)
	local c = M.churn
	if not c.running then return nil end
	return max(0, c.seconds - (now - c.at))
end

-- Counters marked idle, and clocks marked idle: one that moves after STILL seconds standing still is
-- flagged until Reset.
local idleNow, idleSet, idleAddon, stillFor
local function IdleRow(label, value, mark)
	if mark ~= "idle" then return end
	local state = idleSet
	local last = state.last[label]
	if last ~= nil and value ~= last and stillFor >= STILL and not state.flagged[label] then
		state.flagged[label] = true
		M.idleFlags[idleAddon] = M.idleFlags[idleAddon] or {}
		M.idleFlags[idleAddon][label] = format("%s: %s moved while standing still (%s)", idleAddon, label, idleNow)
		flagsDirty = true
	end
	state.last[label] = value
end
local function IdleCheck(now)
	stillFor = M.stillSince and (now - M.stillSince) or 0
	for _, set in ipairs(Shy.CounterSets()) do
		if set.idle then
			local state = idleState[set]
			if not state then
				state = { last = {}, flagged = {} }
				idleState[set] = state
			end
			idleSet, idleAddon, idleNow = state, set.addon, set.title
			local ok, err = pcall(set.rows, IdleRow)
			if not ok then geterrorhandler()(err) end
		end
	end
	for name, clock in pairs(Shy.Clocks()) do
		if clock.idle then
			local last = idleState[clock]
			if last ~= nil and clock.calls ~= last and stillFor >= STILL then
				M.idleFlags[clock.addon] = M.idleFlags[clock.addon] or {}
				if not M.idleFlags[clock.addon][name] then
					M.idleFlags[clock.addon][name] = format("%s: clock \"%s\" works while standing still", clock.addon, name)
					flagsDirty = true
				end
			end
			idleState[clock] = clock.calls
		end
	end
	if flagsDirty then Judge() end
end

function M.Tick(now)
	Still(now)
	if M.watch and (not M.keptAt or now - M.keptAt >= (T.db and T.db.watch or 30)) and not InCombatLockdown() then
		M.Collect(now)
	end
	if now - lastIdle >= IDLE_EVERY then
		lastIdle = now
		IdleCheck(now)
	end
end

function M.Reset()
	for name in pairs(M.flags) do M.flags[name] = nil end
	for cache in pairs(M.cacheFlags) do M.cacheFlags[cache] = nil end
	for addon in pairs(M.idleFlags) do M.idleFlags[addon] = nil end
	for key, state in pairs(idleState) do
		if type(state) == "table" then
			for label in pairs(state.flagged) do state.flagged[label] = nil end
		else
			idleState[key] = nil
		end
	end
	M.times:Clear()
	for _, ring in pairs(M.keptRings) do ring:Clear() end
	for _, ring in pairs(M.cacheRings) do ring:Clear() end
	for name in pairs(M.churnBy) do M.churnBy[name] = nil end
	M.churnAt = nil
	for i = #ns.Flags, 1, -1 do ns.Flags[i] = nil end
end

function ns.FlagOf(name)
	return M.flags[name]
end

-- For the tests: the judgement and the idle check, on demand.
M.Judge, M.IdleCheck = Judge, IdleCheck
