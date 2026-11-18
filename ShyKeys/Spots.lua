-- ShyKeys: What you seldom press: a key you choose, kept where it is
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Base, EMPTY, GRID, HOT = ns.Base, ns.EMPTY, ns.GRID, ns.HOT
local Hot, PAGES, Pressable, Scheme = ns.Hot, ns.PAGES, ns.Pressable, ns.Scheme
local Slots, watched = ns.Slots, ns.watched

---------------------------------------------------------------------------
-- What you seldom press: a key you choose, kept where it is
---------------------------------------------------------------------------

-- What a class keeps for now and then (tracking, a long buff for a group, a spell for one place) stands on no key
-- of its own (job.spot): it takes the first of Shift + 6 to = (then 6 to =) whose button is free as it is laid
-- out, and keeps it from then on (keysBefore.spots[name] = the key). A button with something of yours on it is
-- never taken: the job takes the next free one. One you move is yours (as any key's), and one you put on another
-- of these keys yourself has that key from then on. One you take off the bars stays off; but one whose button you
-- fill with something of your own, and which is on no bar then, takes the next free key.
--   Keys.Utility(jobs, { { name = "Track Beasts", spells = { 1494 } }, ... })   adds them (the spell itself on the
--     button: the first of `spells` you know; `by` as any job's, `what` as said)
HOT.spots = { "SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0", "SHIFT--", "SHIFT-=", "6", "7", "8", "9", "0", "-", "=" }

function Keys.Utility(jobs, list)
	for _, one in ipairs(list) do
		local casts = {}
		for i, spell in ipairs(one.spells) do
			casts[i] = (i < #one.spells and "[known:{%d}] {%d}" or "{%d}"):format(spell, spell)
		end
		jobs[#jobs + 1] = { name = one.name, what = one.what or one.name, spot = true, stay = true, by = one.by,
			spell = #one.spells == 1 and one.spells[1] or one.spells, "#showtooltip", "/cast " .. table.concat(casts, "; ") }
	end
end

-- What a key's button holds, as a job that would stand there sees it: "none" (the key presses no button and
-- can't be given one), "empty", "own" (the job's own macro or spell), "ours" (another job's) or "yours".
local function Holder(key, job, opts, made)
	local command = Pressable(key, opts)
	local slots = command and Slots(command, opts)
	if not slots then return "none" end
	local state = "empty"
	for _, slot in ipairs(slots) do
		local kind, id = GetActionInfo(slot)
		if kind then
			local text = C_ActionBar.GetActionText(slot)
			local mine = false
			if text and made[text] then
				mine = text == job.name and "own" or "ours"
			elseif kind == "spell" and job.spell then
				local name = C_Spell.GetSpellName(id)
				for _, spell in ipairs(type(job.spell) == "table" and job.spell or { job.spell }) do
					if name and C_Spell.GetSpellName(spell) == name then mine = "own" end
				end
			end
			if not mine then return "yours" end
			if state == "empty" or mine == "own" then state = mine end
		end
	end
	return state
end

-- The jobs with what you seldom press given their keys.  record: the layout's own (Apply), which keeps what it
-- chose in `before` and takes a key you put one on as its own; otherwise nothing is changed.
local function Spots(jobs, build, opts, made, before, record)
	if not jobs.spot then return jobs end
	local kept = before and before.spots or {}
	local pinned = before and before.pinned or EMPTY
	local used, want = {}, {}
	for _, job in ipairs(jobs) do
		if job.key then used[job.key] = true end
		if job.spot and Keys.Ever(job, opts, build) then want[#want + 1] = job end
	end
	-- (one you put on another of these keys yourself: that key is its own from then on, bound yet or not)
	if record then
		for _, job in ipairs(want) do
			local at = pinned[job.name]
			if at and #at == 1 then
				for _, key in ipairs(HOT.spots) do
					local command = not used[key] and Pressable(key, opts)
					local slots = command and Slots(command, opts)
					if slots and #slots == 1 and slots[1] == at[1] then
						kept[job.name], before.placed[job.name], pinned[job.name] = key, at, nil
						break
					end
				end
			end
		end
	end
	local chosen, filled = {}, {}
	for _, job in ipairs(want) do
		local key = kept[job.name]
		if key and not used[key] then
			local holds = Holder(key, job, opts, made)
			if holds == "yours" then
				filled[job] = true
			elseif holds ~= "none" then
				chosen[job], used[key] = key, true
			end
		end
	end
	-- The rest: a key whose button holds it already (yours, put there before), else the first free one.
	for _, wanted in ipairs({ "own", "empty" }) do
		for _, job in ipairs(want) do
			if not chosen[job] then
				for _, key in ipairs(HOT.spots) do
					if not used[key] and Holder(key, job, opts, made) == wanted then
						chosen[job], used[key] = key, true
						break
					end
				end
			end
		end
	end
	if record then
		for _, job in ipairs(want) do
			-- (its button filled with something of yours while it was on no bar: it comes back, on its new key)
			local at = pinned[job.name]
			if filled[job] and chosen[job] and at and #at == 0 then pinned[job.name] = nil end
			kept[job.name] = chosen[job]
		end
		before.spots = kept
	end
	local out = {}
	for _, job in ipairs(jobs) do
		if job.spot then
			local copy = {}
			for field, value in pairs(job) do copy[field] = value end
			copy.key, copy.asdf, copy.spot = chosen[job], chosen[job], nil
			out[#out + 1] = copy
		else
			out[#out + 1] = job
		end
	end
	return out
end

-- The jobs a build lays out, the way you move: each on its key (what you seldom press on the key it has, or would
-- take now; nothing is changed).
function Keys.Jobs(jobs, build, scheme)
	local out = Base(jobs, build, scheme)
	if not out.spot then return out end
	local who = UnitGUID("player")
	for _, entry in ipairs(watched) do
		if entry.jobs == jobs then
			local db = entry.addon.db
			return Spots(out, build, entry.opts or EMPTY, db.keysMade and db.keysMade[who] or EMPTY,
				db.keysBefore and db.keysBefore[who], false)
		end
	end
	return Spots(out, build, EMPTY, EMPTY, nil, false)
end

-- The free buttons something of yours can move to when a job takes its button, the best first: a button of the
-- flyouts' bars that a key presses and no job has (an extra button), the buttons of the hand's bars no key presses
-- (the ones under the keys you move with, and the two past B), then the rest of the flyouts' bars.
-- Never a button a job's key presses, even one whose job is still to come.
local function Homes(jobs, opts, wants, keep)
	local reserved = {}
	for _, job in ipairs(jobs) do
		local command = job.key and Hot.Pressing(job.key, opts) or ""
		for _, slot in ipairs(command ~= "" and Slots(command, opts) or EMPTY) do reserved[slot] = true end
	end
	local out, seen = {}, {}
	local function Add(slot)
		if slot and not seen[slot] and not reserved[slot] and not wants[slot] and not keep[slot] and not GetActionInfo(slot) then
			seen[slot] = true
			out[#out + 1] = slot
		end
	end
	local function At(command)
		local bar, button = command:match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
		return bar and PAGES[bar] and (PAGES[bar] - 1) * NUM_ACTIONBAR_BUTTONS + tonumber(button) or nil
	end
	for _, bar in ipairs({ HOT.plain, HOT.bar }) do
		for n = 1, NUM_ACTIONBAR_BUTTONS do
			if GetBindingKey(bar .. n) then Add(At(bar .. n)) end
		end
	end
	local way = Scheme()
	for _, row in ipairs(HOT.rows) do
		for key in row:gmatch(".") do
			if way.move[key] and GRID[key] then Add(At(GRID[key])) end
		end
	end
	for n = 1, NUM_ACTIONBAR_BUTTONS do
		local command = "MULTIACTIONBAR2BUTTON" .. n
		if not GetBindingKey(command) then Add(At(command)) end
	end
	for n = 1, NUM_ACTIONBAR_BUTTONS do Add(At(HOT.bar .. n)) end
	for n = 1, NUM_ACTIONBAR_BUTTONS do Add(At("MULTIACTIONBAR4BUTTON" .. n)) end
	return out
end

-- What the files after this one use.
ns.Homes, ns.Spots = Homes, Spots
