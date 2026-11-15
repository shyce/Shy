-- Every view as text to paste: the to-do list first, then the view's rows, then the forms the old
-- reports had, then the client and the date.

local _, ns = ...
local CP = {}
ns.Copy = CP
local S = ns.Samples
local format = string.format

local function Client()
	local version, build, _, interface = GetBuildInfo()
	return format("Client %s, build %s, interface %s.", tostring(version), tostring(build), tostring(interface))
end

local TIMELINE = { "ShyCore", "ShyQuest", "ShyWay", "ShyBags" }

-- The last two minutes of samples (1 Hz), aligned with the sparklines; marks since Reset on the same clock.
local function Timeline(lines)
	local game = S.frame.game
	local n = game.count
	if n < 2 then return end
	lines[#lines + 1] = format("Timeline (last %d s, 1 Hz; seconds since Reset):", n)
	lines[#lines + 1] = format("%5s %7s %7s %7s  %s", "s", "game", "addons", "heap", table.concat(TIMELINE, " "))
	local start = n - math.min(n, 60) + 1
	for j = start, n do
		local heapAt = S.heap.count - n + j
		local row = format("%5.0f %7.2f %7.2f %7.2f", j, game:Get(j) or 0, S.frame.addons:Get(j) or 0,
			(S.heap:Get(heapAt) or 0) / 1024)
		for _, name in ipairs(TIMELINE) do
			local a = S.by[name]
			row = row .. format(" %7.2f", a and a.msRing:Get(j) or 0)
		end
		lines[#lines + 1] = row
	end
	if #S.marks > 0 then
		lines[#lines + 1] = "Marks (since Reset):"
		for _, mark in ipairs(S.marks) do lines[#lines + 1] = format("  +%.1f  %s", mark.t, mark.label) end
	end
	lines[#lines + 1] = ""
end

local function Stamp(what)
	return format("ShyMonitor: %s, %s%s", what, date("%Y-%m-%d %H:%M:%S"), UnitIsDeadOrGhost("player") and "  (dead)" or "")
end

-- What should be looked at, numbered: the fresh errors, and every flag a view raised (ns.Flags, a
-- list of sentences, kept by the views).
local function ToDo(lines)
	local n = 0
	lines[#lines + 1] = "To do:"
	for _, flag in ipairs(ns.Flags or {}) do
		n = n + 1
		lines[#lines + 1] = format("  %d. %s", n, flag)
	end
	local E = Shy.Errors
	if E then
		for _, entry in ipairs(E.List()) do
			if entry.fresh then
				n = n + 1
				lines[#lines + 1] = format("  %d. %s: %s%s", n, tostring(entry.addon or "an addon"),
					tostring(entry.message or ""):match("^[^\n]*"), entry.count > 1 and format(", %d times", entry.count) or "")
			end
		end
	end
	if n == 0 then lines[#lines + 1] = "  nothing flagged" end
	lines[#lines + 1] = ""
end

-- The clocks, the costliest first: as the old clock report had them, with the owner.
local function Clocks(lines, addonOnly)
	local seconds = math.max(GetTime() - Shy.ClocksSince(), 1)
	local list = {}
	for _, clock in pairs(Shy.Clocks()) do
		if clock.calls > 0 and (not addonOnly or clock.addon == addonOnly) then list[#list + 1] = clock end
	end
	table.sort(list, function(a, b) return a.ms > b.ms end)
	-- (KB/s beside KB a run: a few bytes a frame are nothing a run, and kilobytes a second.)
	lines[#lines + 1] = format("Clocks over %.0f seconds (calls/s, ms/s, ms most, KB a run, KB/s):", seconds)
	lines[#lines + 1] = format("%-44s %-10s %9s %9s %9s %8s %8s", "", "addon", "calls/s", "ms/s", "ms most", "KB", "KB/s")
	for _, c in ipairs(list) do
		local runs = c.calls - c.collected
		local each = runs > 0 and c.kb / runs or 0
		lines[#lines + 1] = format("%-44s %-10s %9.1f %9.2f %9.1f %8.1f %8.1f", c.name, c.addon, c.calls / seconds, c.ms / seconds, c.most,
			each, each * c.calls / seconds)
	end
end

-- Memory as the old report had it: what each addon holds, and once a clean-up has run, what it held
-- after; then each cache's size and what emptying it freed; then what was weighed.
local function Memory(lines, addonOnly)
	local M = ns.Memory
	local held = M and M.heapKept
	if held then
		lines[#lines + 1] = format("Memory: %.2f MB in use, %.2f MB held after the clean-up %.0f s ago (%.2f MB was waiting to be thrown away).",
			S.heapNow / 1024, held / 1024, GetTime() - M.keptAt, (M.heapBefore - held) / 1024)
	else
		lines[#lines + 1] = format("Memory: %.2f MB in use (Collect tells what is held).", S.heapNow / 1024)
	end
	lines[#lines + 1] = "By addon (in use, held after a clean-up):"
	for _, name in ipairs(S.names) do
		if not addonOnly or name == addonOnly then
			local a, kept = S.by[name], M and M.kept[name]
			lines[#lines + 1] = kept and format("  %s: %.2f MB, %.2f MB", name, a.inUse / 1024, kept / 1024) or format("  %s: %.2f MB", name, a.inUse / 1024)
		end
	end
	local any = false
	for _, cache in ipairs(Shy.Memory.Caches()) do
		if not addonOnly or cache.addon == addonOnly then
			if not any then
				any = true
				lines[#lines + 1] = "Caches (size now, freed when last emptied):"
			end
			local ok, size = pcall(cache.size or function() return nil end)
			local freed = M and M.freed[cache]
			lines[#lines + 1] = format("  %s (%s): %s%s%s", cache.name, cache.addon, ok and size and tostring(size) or "-",
				freed and format(", %.2f MB freed", freed / 1024) or "", M and M.cacheFlags[cache] and (", " .. M.cacheFlags[cache]) or "")
		end
	end
	if M then
		for name, list in pairs(M.weighed) do
			if not addonOnly or name == addonOnly then
				lines[#lines + 1] = format("%s, weighed (entries, tables):", name)
				for _, w in ipairs(list) do lines[#lines + 1] = format("  %s: %d, %d", w.name, w.entries, w.tables) end
			end
		end
		if M.churnAt then
			lines[#lines + 1] = format("Made in ten seconds with the clean-up held off: %.0f KB a second in all.", M.churnTotal or 0)
			for _, name in ipairs(S.names) do
				local kb = M.churnBy[name]
				if kb and kb > 1 and (not addonOnly or name == addonOnly) then lines[#lines + 1] = format("  %s: %.0f KB a second", name, kb) end
			end
		end
	end
end

local function Counters(lines, addonOnly)
	for _, set in ipairs(Shy.CounterSets()) do
		if not addonOnly or set.addon == addonOnly then
			lines[#lines + 1] = format("%s (%s):", set.title, set.addon)
			local ok, err = pcall(set.rows, function(label, value, mark, limit)
				local said = mark == "of" and limit and format("%s of %s", tostring(value), tostring(limit)) or tostring(value)
				lines[#lines + 1] = format("  %s: %s%s", label, said, mark == "idle" and "  (should be still)" or "")
			end)
			if not ok then lines[#lines + 1] = "  failed: " .. tostring(err) end
		end
	end
end

-- The hitches written down (Shy.Spike), newest first: a call or a frame that took too long, with what was
-- found of its cause.
local function Hitches(lines)
	local list, total = Shy.Spikes()
	lines[#lines + 1] = format("Hitches written down (%d in all; calls over %d ms, frames over %d ms), newest first:", total, Shy.HITCH.item, Shy.HITCH.frame)
	local now = GetTime()
	for _, each in ipairs(list) do
		lines[#lines + 1] = format("  %4.0f s ago  %s  %.1f ms%s", now - each.at, each.what, each.ms, each.note and ("  " .. each.note) or "")
	end
	if #list == 0 then lines[#lines + 1] = "  none" end
end

function CP.Addon(name)
	local lines = { Stamp(name or "an addon"), "" }
	ToDo(lines)
	local a = S.by[name]
	if a and not a.data and not S.off then
		lines[#lines + 1] = format("%s: %.1f%% of the frame now, %.3f ms a frame (average %.3f, peak %.1f); frames over 5 ms %d, over 50 %d, over 100 %d.",
			name, a.share, a.now, a.avg, a.peak, a.over5, a.over50, a.over100)
		lines[#lines + 1] = ""
	end
	Memory(lines, name)
	lines[#lines + 1] = ""
	Counters(lines, name)
	lines[#lines + 1] = ""
	Clocks(lines, name)
	lines[#lines + 1] = ""
	local E = Shy.Errors
	if E then
		for _, entry in ipairs(E.List()) do
			if entry.addon == name then lines[#lines + 1] = E.EntryText(entry.key) end
		end
	end
	lines[#lines + 1] = Client()
	return "ShyMonitor: " .. tostring(name), table.concat(lines, "\n")
end

function CP.Clock(name, results)
	local clock = Shy.Clocks()[name]
	local lines = { Stamp(name), "" }
	if clock then
		local seconds = math.max(GetTime() - Shy.ClocksSince(), 1)
		local runs = clock.calls - clock.collected
		lines[#lines + 1] = format("%s (%s%s): %d calls, %.1f a second, %.3f ms a call, worst %.2f ms, %.2f KB made a run, %d clean-ups seen.",
			name, clock.addon, clock.where and (", " .. clock.where) or "", clock.calls, clock.calls / seconds,
			clock.calls > 0 and clock.ms / clock.calls or 0, clock.most, runs > 0 and clock.kb / runs or 0, clock.collected)
	end
	if results and #results > 0 then
		lines[#lines + 1] = format("Measured, %d runs through the game's own measure (ms, bytes made, bytes freed):", #results)
		for i, r in ipairs(results) do
			lines[#lines + 1] = format("  %2d: %.3f ms, %d made, %d freed", i, r.elapsedMilliseconds or 0, r.allocatedBytes or 0, r.deallocatedBytes or 0)
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = Client()
	return "ShyMonitor: " .. name, table.concat(lines, "\n")
end

function CP.Addons()
	local lines = { Stamp("all addons"), "" }
	ToDo(lines)
	if S.off then
		lines[#lines + 1] = "The game's addon profiler is off."
	else
		lines[#lines + 1] = format("Frame %.2f ms, addons %.2f ms (%.0f%%).", S.game, S.all, S.game > 0 and S.all / S.game * 100 or 0)
		lines[#lines + 1] = ""
		lines[#lines + 1] = format("%-18s %6s %8s %8s %8s %6s %6s %6s %6s %8s %7s", "addon", "now", "ms now", "ms avg", "ms peak", ">5", ">10", ">50", ">100", "MB", "errors")
		for _, name in ipairs(S.names) do
			local a = S.by[name]
			if a.data then
				lines[#lines + 1] = format("%-18s %6s %8s %8s %8s %6s %6s %6s %6s %8.2f %7d", name, "", "data", "", "", "", "", "", "", a.inUse / 1024, a.errors)
			else
				lines[#lines + 1] = format("%-18s %5.1f%% %8.3f %8.3f %8.1f %6d %6d %6d %6d %8.2f %7d", name, a.share,
					a.now, a.avg, a.peak, a.over5, a.over10, a.over50, a.over100, a.inUse / 1024, a.errors)
			end
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = format("all addons: %.3f ms a frame now, the game %.3f", S.all, S.game)
		lines[#lines + 1] = "costliest now:"
		for _, result in ipairs(S.top) do
			lines[#lines + 1] = format("  %-24s %8.3f ms  %5.1f%%", result.addOnName, result.metricValue, S.Share(result.addOnName))
		end
	end
	lines[#lines + 1] = ""
	Timeline(lines)
	Memory(lines)
	lines[#lines + 1] = ""
	Clocks(lines)
	lines[#lines + 1] = ""
	Hitches(lines)
	lines[#lines + 1] = ""
	lines[#lines + 1] = Client()
	return "ShyMonitor: all addons", table.concat(lines, "\n")
end
