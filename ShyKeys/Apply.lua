-- ShyKeys: Laying the keys out, and putting every one of them back
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Bags, Base, Before, BindingCalled = ns.Bags, ns.Base, ns.Before, ns.BindingCalled
local Does, EMPTY, Empty, HOT = ns.Does, ns.EMPTY, ns.Empty, ns.HOT
local Held, Holds, Homes, Hot = ns.Held, ns.Holds, ns.Homes, ns.Hot
local HotBook, HotState, JobButton, KeyAt = ns.HotBook, ns.HotState, ns.JobButton, ns.KeyAt
local Kind, LAYOUT, Learns, Macro = ns.Kind, ns.LAYOUT, ns.Learns, ns.Macro
local Made, Moved, Owns, Press = ns.Made, ns.Moved, ns.Owns, ns.Press
local Pressable, Put, Remove, Restore = ns.Pressable, ns.Put, ns.Remove, ns.Restore
local Seat, Several, Slots, Solid = ns.Seat, ns.Several, ns.Slots, ns.Solid
local Spots, Standing, Theirs, watched = ns.Spots, ns.Standing, ns.Theirs, ns.watched

function Keys.Apply(addon, jobs, opts)
	opts = opts or {}
	if InCombatLockdown() then return nil, "combat" end
	ns.live = true               -- (the keys as they are bound, whatever is drawn of the keys to come)
	Keys.gen = Keys.gen + 1   -- (what the keys show is worked out again)
	local board = Hot.On() and Keys.Board(opts) or {}   -- the keys the hotkeys hold: a layout lets none of them go
	local made, before = Made(addon), Before(addon)
	local build, buildName
	if opts.build then build, buildName = opts.build() end
	jobs = Base(jobs, build)   -- (what you seldom press is given its key once what you moved is read: below)
	local learns = Learns(opts.knows)
	local result = { placed = 0, waiting = 0, waits = {}, cleared = 0, bound = 0, tidied = 0, kept = 0, left = {}, new = {}, moved = {}, at = {}, learns = learns, build = build, buildName = buildName, shared = 0,
		rehomed = {}, homeless = 0 }
	local pinned = before.pinned
	if not before.theirs then before.theirs = Theirs(made) end   -- (your macros, before the first layout: never deleted here)
	local function Drop(name)
		Remove(name, made, before)
	end
	-- A macro made here for another build's job goes: a character holds few. So does one whose job has no key the
	-- way you move (said).
	local wanted = {}
	for _, job in ipairs(jobs) do
		if job.key or job.spot then
			wanted[job.name] = true
		else
			result.left[#result.left + 1] = { job, "move" }
		end
	end
	for name in pairs(made) do
		if not wanted[name] then Drop(name) end
	end
	Moved(made, before, opts)
	-- (the key bindings it is first laid out on: the ones you chose it for, where a key that does nothing may be bound)
	if before.layout == nil and before.set == nil then before.set = select(2, HotState()) end
	before.layout = LAYOUT   -- (from here on, a macro off its button was moved by you)
	-- What you seldom press, on the key it has or the next free one (none free: it is left, said so).
	if jobs.spot then
		local spotted = Spots(jobs, build, opts, made, before, true)
		jobs = {}
		for _, job in ipairs(spotted) do
			if job.key then
				jobs[#jobs + 1] = job
			elseif Keys.Ever(job, opts, build) then
				result.left[#result.left + 1] = { job, "spots" }
				if made[job.name] then Drop(job.name) end
			end
		end
	end
	local owned = {}         -- the buttons each job stands on as this layout begins: slot -> its name
	for _, slots in ipairs({ before.placed, before.pinned }) do
		for name, at in pairs(slots) do
			for _, slot in ipairs(at) do owned[slot] = name end
		end
	end
	addon.db.keysBuild = addon.db.keysBuild or {}
	addon.db.keysBuild[UnitGUID("player")] = build or ""
	local best, known = Bags(), {}
	local seats, waits = Seat(jobs, opts, made, best, learns, known, pinned, before.last)
	-- A job with no seat has no macro: one left by an earlier layout goes, and with it leaves its buttons.
	for _, job in ipairs(waits) do
		result.waiting = result.waiting + 1
		result.waits[#result.waits + 1] = job.name
		if made[job.name] then
			Drop(job.name)
			result.cleared = result.cleared + 1
		end
	end
	local taken = {}         -- what of yours stood on a button a job took just now: { slot, held }
	-- A job you moved stays where you put it, its macro (or its item) kept up there; the buttons it left are yours too.
	local held, keep = {}, {}   -- the buttons you put a key on; and those, with the ones it left
	for _, job in ipairs(jobs) do
		local at = seats[job] and pinned[job.name]
		if at then
			if Solid(job) then
				Held(job, made, best, before)
				for _, slot in ipairs(at) do Put(job, slot, before, made, nil, owned) end
			else
				Macro(job, made, best, before)
			end
			for _, slot in ipairs(at) do held[slot], keep[slot] = true, true end
			for _, slot in ipairs(before.placed[job.name] or {}) do keep[slot] = true end
			result.placed, result.kept = result.placed + 1, result.kept + 1
		end
	end
	-- Each other seated job's macro (or item), on the buttons of its seat.
	local wants = {}         -- slot -> the job
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		if seat and not pinned[job.name] then
			local command, bound
			if seat == job.key then
				command, bound = JobButton(job, opts, before)
			else
				command, bound = Press(seat, opts, before)
			end
			if bound then result.bound = result.bound + 1 end
			local was = made[job.name]
			local index, why, new
			if not command then
				why = Hot.Keeps(seat) and "kept" or "key"
			elseif Solid(job) then
				index, why, new = Held(job, made, best, before)
			else
				index, why, new = Macro(job, made, best, before)
			end
			local slots = {}
			for _, slot in ipairs(index and Slots(command, opts) or {}) do
				if not held[slot] then
					slots[#slots + 1] = slot
					wants[slot] = job
				end
			end
			if index and #slots == 0 then index, why = nil, "taken" end
			if index then
				before.placed[job.name] = slots
				result.placed = result.placed + 1
				if new then
					result.new[#result.new + 1] = job
				elseif type(was) == "string" and was ~= seat then
					result.moved[#result.moved + 1] = job
				end
				made[job.name] = seat
				result.at[job.name] = seat
			else
				result.left[#result.left + 1] = { job, why }
			end
		end
	end
	-- Every button of the layout: the macro that stands there now, or (one of ours no longer does) what
	-- stood there before. A key bound for a job that isn't on it is let go.
	local occupied = {}
	for job, seat in pairs(seats) do occupied[seat] = job end
	for _, job in ipairs(jobs) do
		local command = job.key and Hot.Pressing(job.key, opts) or ""
		for _, slot in ipairs(command ~= "" and Slots(command, opts) or {}) do
			local want = wants[slot]
			if want then
				Put(want, slot, before, made, taken, owned)
			elseif not keep[slot] then
				Empty(slot, before, made)
			end
		end
		-- (a key the layout bound, still as it bound it; or on the job's own spare button: one an older layout bound)
		local given = job.key and before.keys[job.key]
		local ours = (type(given) == "string" and command == given) or (job.spare ~= nil and command == job.spare)
		if job.key and ours and not occupied[job.key] and board[job.key] ~= command then
			SetBinding(job.key)
			before.keys[job.key] = nil
			result.unbound = true
		end
	end
	-- A macro made here that stands on a button no key of the layout presses any more (its key was bound to
	-- another button since: the hotkeys set, or put back) leaves it, and what stood there before comes back.
	for _, slots in pairs(Standing(made, before)) do
		for _, slot in ipairs(slots) do
			if not wants[slot] and not keep[slot] then Empty(slot, before, made) end
		end
	end
	-- The player's own buttons for what a key now does are tidied away, wherever on any bar they stand: an
	-- ability stands in one place. What a key does is everything its macro can cast now, on any of its lines
	-- (a stance it passes through, the Bloodrage a Charge ends in), not what it would only fall back to.
	-- Each button is remembered, and comes back when the keys are put back. An ability tidied once and put on a
	-- bar again by you stays, and so do those of a key you moved: where those stand is yours.
	local tidy, done = {}, {}
	for job in pairs(learns and seats or {}) do
		if not pinned[job.name] then
			for _, name in ipairs(Does(job, known, nil, true)) do tidy[name] = true end
		end
	end
	for _, was in pairs(before.slots) do
		local name = was and was[3] and C_Spell.GetSpellName(was[2])
		if name then done[name] = true end
	end
	-- The same for what the bags hold: a kind of item a key now uses (your water, once Drink has it) stands on that
	-- key alone. (An item one of our jobs stands as is on a button the layout wants, or one you moved it to.)
	local carried, used = {}, {}
	for job in pairs(seats) do
		if job.supply and not pinned[job.name] then
			for _, kind in ipairs(job.supply) do carried[kind] = true end
		end
	end
	for _, was in pairs(before.slots) do
		local kind = was and was[3] and was[1] == "item" and Kind(was[2])
		if kind then used[kind] = true end
	end
	for slot = 1, MULTIBAR_7_ACTIONBAR_PAGE * NUM_ACTIONBAR_BUTTONS do
		local kind, id = GetActionInfo(slot)
		local name = not wants[slot] and kind == "spell" and C_Spell.GetSpellName(id)
		local sort = not wants[slot] and not keep[slot] and kind == "item" and Kind(id)
		if (name and tidy[name] and not done[name]) or (sort and carried[sort] and not used[sort]) then
			if not before.slots[slot] then before.slots[slot] = { kind, id, true } end
			PickupAction(slot)
			ClearCursor()
			result.tidied = result.tidied + 1
		end
	end
	-- Nothing of yours disappears: what a job took a button from just now, and no key does, moves to a free button
	-- (and goes back where it stood when the keys are put back, or the job leaves).
	local homes
	for _, entry in ipairs(taken) do
		local was = entry.held
		local covered
		if was[1] == "spell" then
			local name = C_Spell.GetSpellName(was[2])
			covered = name ~= nil and tidy[name] == true
		elseif was[1] == "item" then
			local sort = Kind(was[2])
			covered = sort ~= nil and carried[sort] == true
		end
		if not covered then
			homes = homes or Homes(jobs, opts, wants, keep)
			local home = table.remove(homes, 1)
			if home and Restore(home, was) then
				-- (what you put there after the layout stays on its new button: the one it left goes back to what
				-- stood there first)
				if not entry.later then before.homes[home] = entry.slot end
				result.rehomed[#result.rehomed + 1] = { held = was, from = entry.slot, to = home }
			else
				result.homeless = result.homeless + 1
			end
		end
	end
	if result.bound > 0 or result.unbound then SaveBindings(GetCurrentBindingSet()) end
	for _, entry in ipairs(watched) do
		if entry.addon == addon then entry.waiting = result.waiting end   -- whether a job still waits for a spell
	end
	for _ in pairs(before.account) do result.shared = result.shared + 1 end   -- (how many of its macros are the account's)
	ns.live = false
	return result
end

-- Laid out as a player asks for it: the hotkeys first, when the board is the pick, so every job's key presses
-- its own button; then every job on its key.  -> Apply's result, with hot (Take's) when the hotkeys were set
function Keys.Lay(addon, jobs, opts)
	if InCombatLockdown() then return nil, "combat" end
	-- (no room for its macros: nothing is begun, so nothing is left half laid out)
	local space = Keys.Space(addon, jobs, opts)
	if space.short > 0 then return nil, "macros", space end
	local hot
	if Keys.Mode() == "shy" then hot = Hot.Take(opts) end
	local result = Keys.Apply(addon, jobs, opts)
	if result then result.hot = hot end
	return result
end

-- Put back as a player asks for it: every button as it was, then every hotkey.  -> Revert's result, with hot (Back's)
function Keys.Unlay(addon)
	if InCombatLockdown() then return nil, "combat" end
	local result = Keys.Revert(addon)
	result.hot = Hot.Back()
	return result
end

-- Picks whose hotkeys a layout uses. With keys laid out (or the hotkeys set) it is done now: the keys put
-- back, the hotkeys set or returned, and the keys laid out again on what the keyboard then presses.
--   -> true, or false in a fight
function Keys.SetMode(mode)
	if mode ~= "shy" and mode ~= "own" then return false end
	local mine = watched[1]
	local laid = mine ~= nil and Keys.Has(mine.addon)
	local stands = mode == Keys.Mode() and (Hot.On() == (mode == "shy") or not laid)
	if not stands and (laid or Hot.On()) then
		if InCombatLockdown() then return false end
		if laid then Keys.Revert(mine.addon) end
		HotBook().mode = mode
		if mode == "own" then Hot.Back() elseif laid then Hot.Take(mine.opts) end
		if laid then Keys.Apply(mine.addon, mine.jobs, mine.opts) end
	end
	HotBook().mode = mode
	Keys.gen = Keys.gen + 1
	Shy:Fire("SHY_KEYS_MODE", mode)
	return true
end

-- Whether this character's keys are laid out, or the open setup window means to lay them out: every bar of
-- the layout is wanted on screen then, the flyout with them.
function Keys.Wanted()
	local mine = watched[1]
	if not mine then return false end
	local plan = Shy.Setup and Shy.Setup.Current and Shy.Setup.Current()
	local pick = plan and plan.keys and plan.keys.pick
	if pick then return pick ~= "off" and pick ~= "skip" end   -- (No, or nothing laid out: no bars wanted for it)
	return Keys.Has(mine.addon)
end

function Keys.Revert(addon)
	if InCombatLockdown() then return nil, "combat" end
	Keys.gen = Keys.gen + 1
	local who = UnitGUID("player")
	local made, before = Made(addon), Before(addon)
	local ours = {}          -- the buttons our macros and items stand on: empty once they go
	for name, slots in pairs(Standing(made, before)) do
		for _, slot in ipairs(slots) do ours[slot] = true end
		-- (an item you moved, or that stands where the layout didn't put it: off that button too)
		if before.last[name] then before.pinned[name] = slots end
	end
	local names = {}
	for name in pairs(made) do names[#names + 1] = name end
	for _, name in ipairs(names) do
		Remove(name, made, before)             -- deleted, it leaves every button it stood on
	end
	for slot in pairs(ours) do                 -- (one that was yours before, and so stays: off our buttons all the same)
		if C_ActionBar.GetActionText(slot) then
			PickupAction(slot)
			ClearCursor()
		end
	end
	-- What a job moved to a free button leaves it: it goes back where it stood.
	for home, from in pairs(before.homes) do
		local held = before.slots[from]
		if held and Holds(home, held) then
			PickupAction(home)
			ClearCursor()
		end
	end
	local result = { put = 0, lost = 0 }
	for slot, held in pairs(before.slots) do
		-- (what you have put on a button since stays)
		if held and (ours[slot] or not GetActionInfo(slot)) then
			if Restore(slot, held) then
				result.put = result.put + 1
			else
				result.lost = result.lost + 1
			end
		end
	end
	local unbound = false
	for key, command in pairs(before.keys) do
		-- (a key you have bound to something else since stays yours)
		if command == true or GetBindingAction(key) == command then
			SetBinding(key)
			unbound = true
		end
	end
	if unbound then SaveBindings(GetCurrentBindingSet()) end
	addon.db.keysBefore[who], addon.db.keysMade[who] = nil, nil
	if addon.db.keysBuild then addon.db.keysBuild[who] = nil end
	return result
end

local WHY = {
	key = "its key does something else: have your hotkeys set up in /shy keys, or bind it to an action button",
	kept = "you kept its key as you had it. Untick it in /shy keys to give it the key",
	yours = "you have a macro of your own by that name: rename yours, then lay them out again",
	full = "there is no room for another macro, this character's or the account's",
	name = "the game can't name one of its spells yet: lay them out again in a moment",
	taken = "you put another key's ability on its button",
	move = "it has no key yet for the way you move",
	spots = "Shift + 6 to = all hold something of yours: free one, then lay them out again",
	none = "your bags hold none",
}

-- What a button held, as it is said: a spell's or an item's name, a macro's.
local function Called(held)
	if held[1] == "spell" then return C_Spell.GetSpellName(held[2]) or "a spell" end
	if held[1] == "item" then return C_Item.GetItemNameByID(held[2]) or "an item" end
	return tostring(held[2])
end

-- What a layout would take a button from that no key then does, with nothing done: your own buttons that would
-- move to a free one, by name (a spell, an item, a macro of yours). Read for the keys as they are drawn (the
-- hotkeys looked at), once a frame and state.
function Keys.Displaces(addon, jobs, opts)
	opts = opts or {}
	local kept = HOT.moves
	if kept and kept.at == GetTime() and kept.gen == Keys.gen and kept.look == Keys.look and kept.addon == addon then return kept.list end
	local who = UnitGUID("player")
	local made = addon.db.keysMade and addon.db.keysMade[who] or EMPTY
	local before = addon.db.keysBefore and addon.db.keysBefore[who]
	local pinned, last = before and before.pinned or EMPTY, before and before.last or EMPTY
	jobs = Keys.Jobs(jobs, opts.build and (opts.build()))
	local best, known = Bags(), {}
	local learns = Learns(opts.knows)
	local seats = Seat(jobs, opts, made, best, learns, known, pinned, last)
	local does, carried = {}, {}
	for job in pairs(seats) do
		for _, name in ipairs(learns and Does(job, known, nil, true) or EMPTY) do does[name] = true end
		for _, kind in ipairs(job.supply or EMPTY) do carried[kind] = true end
	end
	local names, seen = {}, {}
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		local command = seat and not pinned[job.name] and Pressable(seat, opts, seat == job.key and job.spare or nil)
		for _, slot in ipairs(command and Slots(command, opts) or EMPTY) do
			local kind, id = GetActionInfo(slot)
			local held
			if kind == "macro" then
				local text = C_ActionBar.GetActionText(slot)
				held = text and not made[text] and { kind, text } or nil
			elseif kind then
				held = { kind, id }
				for name in pairs(last) do
					if made[name] and Owns(name, before, kind, id) then held = nil end   -- (one of ours)
				end
			end
			local covered = held and ((kind == "spell" and does[C_Spell.GetSpellName(id) or ""]) or (kind == "item" and carried[Kind(id) or ""]))
			local name = held and not covered and Called(held)
			if name and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	HOT.moves = { at = GetTime(), gen = Keys.gen, look = Keys.look, addon = addon, list = names }
	return names
end

-- asked: the choice was made where every key it changes is shown (the keys' panel, setup). Not asked (a chat
-- command), hotkeys that would take a key of yours lay nothing out: the keys' page opens to show each one.
function Keys.Run(addon, jobs, opts, asked)
	opts = opts or {}
	if not asked and Keys.Mode() == "shy" and not Hot.On() and not InCombatLockdown() then
		-- (every one a hand relies on said by name, the rest counted)
		local taking, musts = 0, {}
		for _, entry in ipairs(Hot.Yours(opts)) do
			if not entry.kept then
				taking = taking + 1
				if entry.must then
					musts[#musts + 1] = ("%s (%s%s)"):format(Keys.Key(entry.key), BindingCalled(entry.from),
						entry.home and (", to " .. Keys.Key(entry.home)) or "")
				end
			end
		end
		if taking > 0 then
			addon:Print(("nothing is changed yet. Setting up your keys would change %d of your keys%s. /shy keys lists each one, so you can keep any you want before you press Set up my keys."):format(
				taking, #musts > 0 and (", among them " .. Several(musts, HOT.named)) or ""))
			Shy.Hub.Open("keys")
			return
		end
	end
	local result, why, space = Keys.Lay(addon, jobs, opts)
	if why == "macros" then
		addon:Print(("your keys aren't laid out: they need %d macros and there is room for %d. Delete %d you don't use, this character's or the account's, then lay them out. Nothing was changed."):format(
			space.need, space.need - space.short, space.short))
		return
	end
	if not result then
		addon:Print("your keys can be laid out once the fight is over.")
		return
	end
	addon:Print(("%d keys laid out%s%s.%s"):format(result.placed,
		result.buildName and (" for " .. result.buildName) or "", result.bound > 0 and (", %d bound"):format(result.bound) or "",
		result.waiting > 0 and (" %d more come as you learn what they do."):format(result.waiting) or ""))
	local changed = result.hot and (result.hot.bound + result.hot.cleared) or 0
	if changed > 0 then
		print(("  %d of your hotkeys were set to match. Each is kept as it was, and comes back if you put your keys back."):format(changed))
	end
	if result.hot and result.hot.kept > 0 then
		print(("  %d keys you bound to something else yourself stay as you have them."):format(result.hot.kept))
	end
	if result.shared > 0 then
		print(("  This character's macros are full, so %d of your keys' macros are among the account's. They go when you put your keys back; yours are never touched."):format(result.shared))
	end
	if result.tidied > 0 then
		print(("  %d of your own buttons for abilities that are on a key now were taken off. They come back if you put your keys back."):format(result.tidied))
	end
	if #result.rehomed > 0 then
		local names = {}
		for i, entry in ipairs(result.rehomed) do names[i] = Called(entry.held) end
		print(("  %d of your own buttons moved to a free button: %s. They go back where they were if you put your keys back."):format(
			#names, table.concat(names, ", ")))
	end
	if result.homeless > 0 then
		print(("  %d of your own buttons had no free button to move to. They come back if you put your keys back."):format(result.homeless))
	end
	if result.cleared > 0 then
		print(("  %d keys that had nothing to do yet were taken off again."):format(result.cleared))
	end
	if result.kept > 0 then
		print(("  %d keys you moved stay where you put them."):format(result.kept))
	end
	for _, entry in ipairs(result.left) do
		local job = entry[1]
		print(("  %s%s was left: %s."):format(job.name, job.key and (" (" .. Keys.Key(job.key) .. ")") or "", WHY[entry[2]]))
	end
	if not result.learns then
		print("  This game's macros can't ask what you have learned: a key keeps its first ability.")
	end
	print("  /shy keys  - what each key does, and how to put yours back")
	return result
end

function Keys.Back(addon)
	local result = Keys.Unlay(addon)
	if not result then
		addon:Print("your keys can be put back once the fight is over.")
		return
	end
	addon:Print(("your keys are as they were%s."):format(result.lost > 0
		and (", but for %d buttons whose old ability couldn't be found"):format(result.lost) or ""))
	local hot = result.hot
	if hot and hot.put > 0 then
		print(("  %d hotkeys are as they were before, too."):format(hot.put))
	end
	if hot and hot.kept > 0 then
		print(("  %d keys you have bound to something else since stay as you have them."):format(hot.kept))
	end
	if hot and hot.lost > 0 then
		print(("  %d keys the game wouldn't take back yet are still kept: put your keys back again in a moment."):format(hot.lost))
	end
	return result
end

function Keys.List(jobs, opts, addon)
	local lines = {}
	-- Where each job stands for this character now (one you moved, where you put it); then what is still to
	-- come, on the key it will have.
	opts = opts or {}
	jobs = Keys.Jobs(jobs, opts.build and (opts.build()))
	local before = addon and addon.db.keysBefore and addon.db.keysBefore[UnitGUID("player")]
	local pinned = before and before.pinned or {}
	local seats, waits = Seat(jobs, opts, {}, Bags(), Learns(opts.knows), {}, pinned)
	for _, job in ipairs(jobs) do
		if seats[job] then
			local at = pinned[job.name]
			local where = at and (KeyAt(at, opts) or "No key") or Keys.Key(Hot.KeyFor(seats[job], opts))
			lines[#lines + 1] = ("%s   %s"):format(where, job.what)
		end
	end
	if #waits > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Still to come, as you learn them:"
		for _, job in ipairs(waits) do
			lines[#lines + 1] = ("%s   %s"):format(Keys.Key(job.key), job.what)
		end
	end
	return table.concat(lines, "\n")
end
