-- ShyKeys: Where each job stands: the buttons a layout writes and puts back
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Button, EMPTY, Find, HOT = ns.Button, ns.EMPTY, ns.Find, ns.HOT
local Hot, HotBook, HotState, Ident = ns.Hot, ns.HotBook, ns.HotState, ns.Ident
local NAMED, Owns, PAGES, Race = ns.NAMED, ns.Owns, ns.PAGES, ns.Race
local Ready, Scheme, Slots, Solid = ns.Ready, ns.Scheme, ns.Slots, ns.Solid
local Sort, Where, watched = ns.Sort, ns.Where, ns.watched

-- The keys that are drawn other than as they are bound now: the board, while it is the pick (or asked for) and
-- not set yet; your own as they were, asked for while the board is set. Nothing of it while keys are laid out
-- and nothing is asked for: those are drawn as they stand. Worked out once a frame for a state: every key a
-- layout is drawn for asks.
ns.live = false              -- a layout is being made: the keys are read as they are
local function Coming()
	if ns.live then return nil end
	-- (asked for every key of every level a story lays out: nothing is made to answer)
	local at, move = GetTime(), DB() and DB().keysMove
	if HOT.at ~= at or HOT.gen ~= Keys.gen or HOT.look ~= Keys.look or HOT.move ~= move then
		HOT.at, HOT.gen, HOT.look, HOT.move = at, Keys.gen, Keys.look, move
		local mine = watched[1]
		local shown = HOT.pretend or Keys.Mode()
		local map = false
		if shown == "shy" then
			if not Hot.On() and (HOT.pretend or not (mine and Keys.Has(mine.addon))) then map = Keys.Board(mine and mine.opts) end
		elseif Hot.On() then
			map = Hot.Was()
		end
		HOT.coming = map
	end
	return HOT.coming or nil
end

-- What a key does: as it is bound, or as the hotkeys drawn have it.
local function Action(key)
	local coming = Coming()
	local command = coming and coming[key]
	if command ~= nil then return command end
	return GetBindingAction(key)
end
Keys.Doing = Action

-- The button a key presses, or would once bound to its own (it presses nothing, isn't one you move with, and
-- its button has no other key): the binding's name, and true when it would have to be bound first.
-- Another key that presses a button (or will, as the keys are drawn), not `except`.  -> the key, or nil
function Hot.Pressed(button, except)
	local coming = Coming()
	for k, command in pairs(coming or EMPTY) do
		if command == button and k ~= except then return k end
	end
	for _, k in ipairs({ GetBindingKey(button) }) do
		if k ~= except and (not coming or coming[k] == nil or coming[k] == button) then return k end
	end
end

-- A key you keep, or bound to something else yourself since it was set here, is never bound again. Its ability
-- stands on the key's own button while another key presses it: the one you picked for it, or one you bound
-- there yourself, so where you put it is where it stays.
local function Pressable(key, opts, spare)
	local command = Action(key)
	if command ~= "" and Slots(command, opts) then return command end
	local own = Hot.ButtonOf(key)
	if own and Keys.Mode() == "shy" and (Hot.Keeps(key) or Hot.Mine(key)) then
		return Hot.Pressed(own, key) and Slots(own, opts) and own or nil
	end
	if command ~= "" then return nil end
	if Keys.Moving(key) or Hot.Keeps(key) then return nil end   -- (one you keep does nothing, as you have it)
	-- (its own: the grid's, the number row's by its flyout's shape; or its job's spare)
	local want = Button(key) or spare
	if want and not GetBindingKey(want) then return want, true end
end

-- The button a job's key presses as the keys are bound now: its binding's; or, for a key you keep or bound to
-- something else since, its own button while another key of yours presses it. "" for none.
function Hot.Pressing(key, opts)
	local command = GetBindingAction(key)
	if command ~= "" and Slots(command, opts) then return command end
	local own = Hot.ButtonOf(key)
	if own and Keys.Mode() == "shy" and (Hot.Keeps(key) or Hot.Mine(key)) and Hot.Pressed(own, key) then return own end
	return ""
end

-- The key a seat's ability is pressed with: the seat itself, or the key of yours that presses its button.
function Hot.KeyFor(seat, opts)
	local own = Hot.Pressing(seat, opts)
	if own ~= "" and own ~= GetBindingAction(seat) then return Hot.Pressed(own, seat) or seat end
	return seat
end

-- The button a key presses, binding it to its own (or the job's spare) when it presses nothing.
--   -> the binding's name or nil, and true when a key was bound
-- A layout made for your keys set up, on key bindings where they aren't set (reset to the game's, or a
-- character's own switched to): it waits, nothing moved or bound, until you set them up there or put it back.
function Keys.Paused(addon)
	return Keys.Has(addon) and HotBook().mode == "shy" and not Hot.On()
end

-- Whether a layout may bind a key of yours that does nothing: where you chose it (your hotkeys set up on these key
-- bindings, or your own hotkeys picked), or on the key bindings it was first laid out on. Never on others you
-- switched to since (a character's own, as the game ships them): nothing is bound there until you choose.
function Hot.MayBind(before)
	if Hot.On() or HotBook().mode == "own" then return true end
	local _, id = HotState()
	return before ~= nil and before.set ~= nil and before.set == id
end

local function Press(key, opts, before, spare)
	local command, unbound = Pressable(key, opts, spare)
	if not unbound then return command end
	if not Hot.MayBind(before) then return nil end
	if SetBinding(key, command) then
		before.keys[key] = command
		return command, true
	end
end

local function JobButton(job, opts, before)
	return Press(job.key, opts, before, job.spare)
end

-- A macro is put on a button by its name, found as it is put: the game keeps a character's macros in the order of
-- their names, so making one moves every one after it, and a place noted before that names another macro.
-- What stood on a button is kept the first time a job takes it.  -> what was kept just now, if anything stood there
-- On a button a job took before, something you have put there since is yours too (-> it, and true): it is not
-- what the button goes back to, but it isn't lost either.
local function Keep(slot, before, made)
	local kind, id = GetActionInfo(slot)
	if before.slots[slot] ~= nil then
		if kind == "macro" then
			local text = C_ActionBar.GetActionText(slot)
			if text and not made[text] then return { kind, text }, true end
		elseif kind then
			for name in pairs(before.last) do
				if made[name] and Owns(name, before, kind, id) then return nil end   -- (one of ours)
			end
			return { kind, id }, true
		end
		return nil
	end
	local held = false
	if kind == "macro" then
		local text = C_ActionBar.GetActionText(slot)
		if text and not made[text] then held = { kind, text } end   -- one of ours from before isn't the player's
	elseif kind then
		held = { kind, id }
	end
	before.slots[slot] = held
	return held or nil
end

-- A job is put on a button: its macro, or the item it stands as. `taken` gathers what of yours stood there.
-- `owned`: the buttons each job already stood on (slot -> its name): what such a button holds is the job's own,
-- an item it held before, and nothing of yours to keep.
local function Put(job, slot, before, made, taken, owned)
	local name = job.name
	if Solid(job) then
		local item = before.last[name]
		if not item then return end
		local kind, id = GetActionInfo(slot)
		local same = kind == Sort(name, before) and id == item
		if not (owned and owned[slot] == name) then
			-- (yours, even when it is the very item: it is put back there when the keys are)
			local held, later = Keep(slot, before, made)
			if held and taken and not same then taken[#taken + 1] = { slot = slot, held = held, later = later } end
		end
		if same then return end
		if job.spell then C_Spell.PickupSpell(item) else C_Item.PickupItem(item) end
		if GetCursorInfo() then PlaceAction(slot) end   -- (none left to pick up: the button keeps the one it shows)
		ClearCursor()
		return
	end
	if C_ActionBar.GetActionText(slot) == name then return end
	local index = Find(name, Where(name, before))
	if not index then return end
	local held, later = Keep(slot, before, made)
	if held and taken then taken[#taken + 1] = { slot = slot, held = held, later = later } end
	PickupMacro(index)
	PlaceAction(slot)
	ClearCursor()
end

-- Whether a button holds that very thing of yours ({ kind, id }: a spell or an item by ID, a macro by name).
local function Holds(slot, held)
	local kind, id = GetActionInfo(slot)
	if kind ~= held[1] then return false end
	if kind == "macro" then return C_ActionBar.GetActionText(slot) == held[2] end
	return id == held[2]
end

-- Something of yours a job moved to a free button leaves it again: it is about to stand where it was.
local function Unhome(slot, before)
	local held = before.slots[slot]
	for home, from in pairs(before.homes) do
		if from == slot then
			if held and Holds(home, held) then
				PickupAction(home)
				ClearCursor()
			end
			before.homes[home] = nil
		end
	end
end

-- Puts back on a button what stood there before (a spell or an item by its ID, a macro by its name).
--   -> whether it could be found
local function Restore(slot, held)
	local kind, id = held[1], held[2]
	if kind == "spell" then
		C_Spell.PickupSpell(id)
	elseif kind == "item" then
		C_Item.PickupItem(id)
	elseif kind == "macro" then
		local index = Find(id, true)
		if index then PickupMacro(index) end
	end
	local found = GetCursorInfo() ~= nil
	if found then PlaceAction(slot) end
	ClearCursor()
	return found
end

-- Where each job stands now.  -> seats (job -> key), waits (the jobs with no seat, in order), and the
-- abilities that now stand on a key (name -> true)
-- A job with something to do stands on its own key. An ability stands on one key: a job that could only cast
-- what earlier jobs already have waits for something of its own (Rend's key while Rend is still what the
-- strike's key falls back to). Then what you can press gets the best place it can have: an easy key whose own job
-- isn't learned yet takes a job from a key that needs Shift or a reach, the one of its own letter first (Shift +
-- Q's comes to Q), else the next in order; that job goes home when the key's own arrives. A job from the bags stays where it is (and keeps its
-- key while its macro still names what it last held: the button shows what to buy).
local KeyOf                  -- (the key that presses a button: below)
local function Seat(jobs, opts, made, best, learns, known, pinned, last)
	pinned = pinned or {}    -- (a job you moved stays where you put it: it takes no other key)
	local seats, waits, abilities, stays = {}, {}, {}, {}
	for _, job in ipairs(jobs) do
		local ready, does = Ready(job, best, learns, known, opts.shifts)
		if ready and does and not job.supply and job.shared ~= true then
			local taken = job.shared == "stays" and stays or abilities
			local own = false
			for _, name in ipairs(does) do
				if not taken[name] then own = true end
			end
			if own then
				for _, name in ipairs(does) do taken[name] = true end
			else
				ready = false
			end
		end
		if not ready and job.supply and made[job.name] then
			if job.item then
				ready = last ~= nil and last[job.name] ~= nil   -- (the item it last held is still on its button)
			else
				local index, text = Find(job.name)
				if not index then index, text = Find(job.name, "account") end   -- (made among the account's)
				ready = index ~= nil and (text:find("/use ", 1, true) ~= nil or text:find("/castsequence ", 1, true) ~= nil)
			end
		end
		if not job.key then
			-- (no key the way you move: it stands nowhere, and Apply says so)
		elseif ready then
			seats[job] = job.key
		else
			waits[#waits + 1] = job
		end
	end
	local prime, home = {}, {}
	local PRIME = Scheme().prime
	for _, key in ipairs(PRIME) do prime[key] = true end
	for _, job in ipairs(jobs) do
		if job.key then home[job.key] = job end
	end
	-- Prime keys whose own job isn't learned yet, and that press a button (or can): a better place, meanwhile, for
	-- a job you can press that waits behind Shift or a reach. (A key with no job of its own isn't filled: keys
	-- are placed for the fingers and the rotation, never filled for their own sake.)
	local free = {}
	for _, key in ipairs(PRIME) do
		if home[key] and not seats[home[key]] and Pressable(key, opts) then free[#free + 1] = key end
	end
	local function Take(job, at)
		seats[job] = table.remove(free, at)
	end
	-- A job that made way for another on an easy key (job.early: the key) stands there until that one arrives.
	for _, job in ipairs(jobs) do
		if job.early and seats[job] == job.key and not job.supply and not pinned[job.name] then
			for at, key in ipairs(free) do
				if key == job.early then
					Take(job, at)
					break
				end
			end
		end
	end
	for pass = 1, 2 do
		for _, job in ipairs(jobs) do
			-- (a job with `stay` never stands in: one a slip on an easy key would do harm with, a summon over your pet)
			if #free > 0 and job.key and seats[job] == job.key and not prime[job.key] and not job.supply and not job.stay and not pinned[job.name] then
				local letter = job.key:match("^SHIFT%-(.+)$")
				for at, key in ipairs(free) do
					if pass == 2 or key == letter then
						Take(job, at)
						break
					end
				end
			end
		end
	end
	-- An ability you moved onto another job's key: that job takes the key yours left, a swap, now or when it is
	-- learned (never left with no key because you moved another).
	for _, job in ipairs(jobs) do
		local at = pinned[job.name]
		local key = at and #at > 0 and seats[job] and KeyOf(at, opts)
		if key and key ~= seats[job] then
			local left, free = seats[job], true
			for other, seat in pairs(seats) do
				if other ~= job and seat == left then free = false end
			end
			for other, seat in pairs(seats) do
				if free and other ~= job and seat == key and not pinned[other.name] then
					seats[other], free = left, false
				end
			end
		end
	end
	return seats, waits, taken
end

-- Empties a button of a macro made here that no longer stands there: what stood there before comes back.
local function Empty(slot, before, made)
	local text = C_ActionBar.GetActionText(slot)
	if text then
		if not made[text] then return end      -- a macro of the player's own
		PickupAction(slot)
		ClearCursor()
	else
		local kind, id = GetActionInfo(slot)
		local ours = false
		-- (an item one of our jobs stands as, on a button a job took before: one of yours of that kind on a
		-- button no job ever took is tidied with the rest, and remembered)
		if (kind == "item" or kind == "spell") and before.slots[slot] ~= nil then
			for name in pairs(before.last) do
				if made[name] and Owns(name, before, kind, id) then ours = true end
			end
		end
		if ours then
			PickupAction(slot)
			ClearCursor()
		elseif kind then
			return                             -- something else of the player's
		end
	end
	local held = before.slots[slot]
	if held and held[3] then return end        -- tidied away: it comes back with the rest, not before
	if held then
		Unhome(slot, before)
		Restore(slot, held)
	end
	before.slots[slot] = nil
end

-- Where the jobs laid out here stand now, on every bar: name -> { slot, ... }. A job is known by its macro's
-- name, or by the item it stands as (a spell at any rank).
local function Standing(made, before)
	local at, items = {}, nil
	for name, item in pairs(before and before.last or EMPTY) do
		if made[name] then
			items = items or {}
			items[Ident(Sort(name, before), item)] = name
		end
	end
	for slot = 1, MULTIBAR_7_ACTIONBAR_PAGE * NUM_ACTIONBAR_BUTTONS do
		local text = C_ActionBar.GetActionText(slot)
		local name = text and made[text] and text or nil
		if not name and items and not text then
			local kind, id = GetActionInfo(slot)
			name = (kind == "item" or kind == "spell") and items[Ident(kind, id)] or nil
		end
		if name then
			at[name] = at[name] or {}
			table.insert(at[name], slot)
		end
	end
	return at
end

local function Same(a, b)
	if #a ~= #b then return false end
	local set = {}
	for _, slot in ipairs(a) do set[slot] = true end
	for _, slot in ipairs(b) do
		if not set[slot] then return false end
	end
	return true
end

-- The keys you moved since they were laid out: a macro made here that no longer stands on the buttons it was
-- put on stays where you have it now (other buttons, or none), and is moved no more; put back where it was, it
-- follows the layout again. With none of ours on any bar the bars aren't read yet (just logged in): nothing is
-- decided then.
local function Moved(made, before, opts)
	local at = Standing(made, before)
	if next(at) == nil then return end
	-- A layout made before macros were put by their names (LAYOUT) may have put one where another's name had
	-- moved it: nothing of it is taken as moved by you, and every macro goes back to its own button once.
	if (before.layout or 1) < NAMED then
		wipe(before.pinned)
		return
	end
	for name, seat in pairs(made) do
		local placed = before.placed[name]
		if not placed and type(seat) == "string" then   -- laid out before the buttons were kept: its key's
			local command = GetBindingAction(seat)
			placed = command ~= "" and Slots(command, opts) or nil
		end
		if placed then
			local now = at[name] or {}
			before.pinned[name] = not Same(now, placed) and now or nil
		end
	end
	-- (once for each character: a spell job on no bar goes back to its button, where it may have stood at another
	-- rank and not been counted)
	if not before.ranked then
		before.ranked = true
		for name, slots in pairs(before.pinned) do
			if #slots == 0 and Sort(name, before) == "spell" then before.pinned[name] = nil end
		end
	end
	-- A key you took off its button since (bound to something that is no action button, or to nothing, in the
	-- game's key bindings): its ability stays on its button, as one you moved does, and is shown with whatever
	-- key presses that button now. (A key you bound to another button takes its job there, as before; and while
	-- another key of yours presses its button, the button is still the key's: its own job comes to it.)
	for name, seat in pairs(made) do
		local placed = before.placed[name]
		if type(seat) == "string" and placed and #placed > 0 and not before.pinned[name] and at[name] then
			local command = Hot.Pressing(seat, opts)
			if command == "" or not Slots(command, opts) then before.pinned[name] = placed end
		end
	end
end

-- The key that presses one of these buttons (its binding's key: "SHIFT-W"), or nil.
function KeyOf(slots, opts)
	for _, slot in ipairs(slots) do
		local page = math.floor((slot - 1) / NUM_ACTIONBAR_BUTTONS) + 1
		local n = (slot - 1) % NUM_ACTIONBAR_BUTTONS + 1
		local command
		if page == 1 or (page > NUM_ACTIONBAR_PAGES and page <= NUM_ACTIONBAR_PAGES + (opts.forms or 0)) then
			command = "ACTIONBUTTON" .. n
		else
			for bar, at in pairs(PAGES) do
				if at == page then command = bar .. n end
			end
		end
		local key = command and GetBindingKey(command)
		if key then return key end
	end
end

-- The same, as it is said ("Shift + W").
local function KeyAt(slots, opts)
	local key = KeyOf(slots, opts)
	return key and Keys.Key(key)
end

-- The keys the game names in capitals of its own that a hand calls something else. (The arrows above all:
-- "Still on LEFT" is the game's word for it, not yours.)
local SAID = {
	LEFT = "Left Arrow", RIGHT = "Right Arrow", UP = "Up Arrow", DOWN = "Down Arrow",
	PAGEUP = "Page Up", PAGEDOWN = "Page Down", PRINTSCREEN = "Print Screen",
	SCROLLLOCK = "Scroll Lock", NUMLOCK = "Num Lock", CAPSLOCK = "Caps Lock",
	BACKSPACE = "Backspace", ESCAPE = "Escape", INSERT = "Insert", DELETE = "Delete",
	HOME = "Home", END = "End", SPACE = "Space", TAB = "Tab", ENTER = "Enter",
}

-- A key as it is said: "Shift + Mouse 4", "Ctrl + C", "Left Arrow".
function Keys.Key(key)
	local said = (key:gsub("ALT%-", "Alt + "):gsub("CTRL%-", "Ctrl + "):gsub("SHIFT%-", "Shift + "):gsub("BUTTON(%d)", "Mouse %1"))
	-- (the key itself is what is left at the end, once what is held with it is said)
	local tail = said:match("([%u%d]+)$")
	if tail and SAID[tail] then said = said:sub(1, #said - #tail) .. SAID[tail] end
	return said
end

-- A key as a keycap says it: "Ctrl C", "Shift Mouse 4".
function Hot.Plate(key)
	return (Keys.Key(key):gsub(" %+ ", " "))
end

-- A key pressed with whatever is held with it, as the game names a binding ("CTRL-SHIFT-B").
function Hot.Chord(key)
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

-- The talent build followed (ShyQuest's, when it is there): its id and name, or nil.
function Keys.Build()
	local quest = Shy.addons.Quest
	local build = quest and quest.Build and quest:Build()
	if build then return build.id, build.name end
end

-- The jobs as a build lays them out: on each key the job's own for that build (job.by[build]), else the job.
-- The jobs as a build lays them out, on the keys of the way you move: on each key the job's own for that build
-- (job.by[build]), else the job; its key the one it has for ASDF (job.asdf) when you move that way, else its key.
-- A job with no key for ASDF whose key you move with there has no key (it is left, said so). A build that has
-- nothing for a key leaves it out (job.by[build] = false); a build's own job may name keys of its own (key, asdf,
-- early, asdfEarly), where that build presses it more or less than the others do.
-- The same jobs, build and way of moving give the same tables every time (what is worked out for a job is kept by
-- it), so the jobs are laid out once a build and a way.
local laidOut = setmetatable({}, { __mode = "k" })   -- jobs -> "build|scheme" -> the jobs laid out
local function Base(jobs, build, scheme)
	scheme = scheme or Keys.Scheme()
	local race = Race()
	local mine = laidOut[jobs]
	if not mine then
		mine = {}
		laidOut[jobs] = mine
	end
	local id = tostring(build) .. "|" .. scheme .. "|" .. tostring(race)
	if mine[id] then return mine[id] end
	local out = {}
	mine[id] = out
	for _, job in ipairs(jobs) do
		-- What the key does: the build's own job, and of that your people's own.
		-- (a build with nothing for the key says so, `by = { build = false }`: no job)
		local own = job
		if build and job.by and job.by[build] ~= nil then own = job.by[build] end
		local yours = own and own.race and own.race[race]
		local does = yours or own
		-- (a key only some peoples have something for, and yours isn't one of them: no job)
		if own and (yours or not own.race or #own > 0 or own.supply) then
			-- Its keys: the build's own job may name its own (where that build's hand wants it, for either way of
			-- moving; `false` for an early key: none), else they are the job's.
			local function Own(field)
				local value
				if own ~= job then value = own[field] end
				if value == nil then value = job[field] end
				return value or nil
			end
			local asdf = Own("asdf")
			local key = scheme == "asdf" and asdf or Own("key")
			if scheme == "asdf" and not asdf and Keys.SCHEMES.asdf.move[key] then key = nil end
			-- (the key it made way on, the way you move; and a job that never stands in doesn't for any build)
			local early = nil
			if scheme == "asdf" then early = Own("asdfEarly") else early = Own("early") end
			if does ~= job or key ~= job.key or early ~= job.early then
				local copy = {}
				for field, value in pairs(does) do copy[field] = value end
				copy.key, copy.spare, copy.asdf = key, key == job.key and job.spare or nil, asdf
				copy.early, copy.asdfEarly, copy.stay = early, Own("asdfEarly"), copy.stay or job.stay
				copy.by, copy.race = nil, nil
				out[#out + 1] = copy
			else
				out[#out + 1] = job
			end
			if does.spot then out.spot = true end
		end
	end
	return out
end

-- What the files after this one use.
ns.Action, ns.Base, ns.Empty, ns.Holds = Action, Base, Empty, Holds
ns.JobButton, ns.Keep, ns.KeyAt, ns.Moved = JobButton, Keep, KeyAt, Moved
ns.Press, ns.Pressable, ns.Put, ns.Restore = Press, Pressable, Put, Restore
ns.Seat, ns.Standing, ns.KeyOf = Seat, Standing, KeyOf
