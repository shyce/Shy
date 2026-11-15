-- Shy.Memory: what the addons' memory sits in, registered here and read by the monitor (ShyMonitor):
-- caches that can be emptied and say how big they are, tables to weigh, namespaces, and what to let go
-- of when time can be spared. Nothing here reads, collects or reports.
--
--   Shy.Memory.Cache(name, clear[, size])   Shy.Memory.Keeps(name, table)   Shy.Memory.Namespace(name, space)
--   Shy.Memory.OnTidy(fn)   Shy.Memory.Tidy()   Shy.Memory.Step()

local M = {}
Shy.Memory = M

-- Time that can be spared (a fight, when nothing else is rebuilt): what the parts keep that they can do
-- without is let go once (Memory.OnTidy registers it), and the game's cleaning is given a small step a time.
--   Shy.Memory.OnTidy(fn)     fn() lets go of what is kept for later
--   Shy.Memory.Tidy()         every OnTidy, once
--   Shy.Memory.Step()         one small step of the game's own cleaning
local tidiers = {}
local STEP = 64   -- KB a step of the game's cleaning looks at
function M.OnTidy(fn)
	tidiers[#tidiers + 1] = fn
end
function M.Tidy()
	for _, fn in ipairs(tidiers) do fn() end
end
function M.Step()
	collectgarbage("step", STEP)
end

-- An addon's namespace (the table its files share), to be read field by field in the report.
local spaces = {}
function M.Namespace(name, space)
	spaces[#spaces + 1] = { name = name, space = space, addon = Shy.AddonOf(2) }
end

-- A part's cache says how to be emptied (it fills again from use) and, with `size`, how big it is now
-- (a count: entries, tiles, searches; cheap, read while the monitor shows it). The report empties each
-- in turn and says how much memory went; the monitor empties one on a click.
--   Shy.Memory.Cache(name, clear[, size])   Shy.Memory.Caches() -> { name, clear, size, addon }...
local caches = {}
function M.Cache(name, clear, size)
	caches[#caches + 1] = { name = name, clear = clear, size = size, addon = Shy.AddonOf(2) }
end
function M.Caches() return caches end

-- A table a part keeps, to be weighed when asked (entries and tables under it), never on a timer.
--   Shy.Memory.Keeps(name, table)   Shy.Memory.Kept() -> { name, table, addon }...
local kept = {}
function M.Keeps(name, table)
	kept[#kept + 1] = { name = name, table = table, addon = Shy.AddonOf(2) }
end
function M.Kept() return kept end
function M.Spaces() return spaces end

-- How many entries a table holds, and how many tables lie under it (each once).
local function Weigh(root, seen)
	local entries, tables = 0, 0
	local stack, top = { root }, 1
	seen[root] = true
	while top > 0 do
		local t = stack[top]
		stack[top] = nil
		top = top - 1
		tables = tables + 1
		for key, value in next, t do
			entries = entries + 1
			-- (A frame is the game's, whoever holds it: its table is not walked, nor the game's tables under it.)
			if type(value) == "table" and not seen[value] and value ~= _G and type(rawget(value, 0)) ~= "userdata" then
				seen[value] = true
				top = top + 1
				stack[top] = value
			end
		end
	end
	return entries, tables
end
M.Weigh = Weigh

