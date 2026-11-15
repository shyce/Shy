-- Counters: what an addon counts, as rows the monitor shows and copies. Nothing here reads them:
-- registering is a table write, and rows(row) runs only while that addon's view is on screen.
--
--   Shy.Counters(title, rows[, opts])   rows(row) writes the rows: row(label, value[, mark[, limit]]),
--                                       value a number or a word; mark "idle" (it should not move while
--                                       standing still) or "of" with the limit it is a share of.
--                                       opts.reset = fn (the "since" marks), opts.group = a heading,
--                                       opts.idle = true: the monitor looks at its idle rows every few
--                                       seconds while open (only sets that say so are read unasked).
--   Shy.CounterSets() -> the list, each { title, rows, addon, group, reset, idle }

local sets = {}

function Shy.Counters(title, rows, opts)
	local set = { title = title, rows = rows, addon = Shy.AddonOf(2), group = opts and opts.group, reset = opts and opts.reset,
		idle = opts and opts.idle or nil }
	sets[#sets + 1] = set
	return set
end

function Shy.CounterSets()
	return sets
end
