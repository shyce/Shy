-- ShyKeys: Your hotkeys: the keyboard bound as the bars draw it
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Button, EMPTY, GRID, HOT = ns.Button, ns.EMPTY, ns.GRID, ns.HOT
local Macro, Pick, Scheme, Shape = ns.Macro, ns.Pick, ns.Scheme, ns.Shape
local watched = ns.watched

---------------------------------------------------------------------------
-- Your hotkeys: the keyboard bound as the bars draw it
---------------------------------------------------------------------------

-- A layout is made for a keyboard bound one way: every key of the grid on its own button, the keys you move with
-- moving you, and the number row apart from the hand's three bars, on the two flyouts: 1 to = the left one's
-- buttons, Shift + 1 to = the right one's, extra buttons for whatever you like (a class's jobs on the number row
-- stand there too, what you stay in on 1 2 3 among them). Most keyboards aren't bound so (the game's own has
-- 1 to = on the main bar and Q and E strafing), and a job whose key does something else can't stand. So the
-- hotkeys are a choice, "shy" (the board, recommended) or "own" (your keys as they are), made before anything
-- changes and undone whole:
--
--   Keys.Board(opts, scheme)   -> want (key -> binding), order (the keys as a hand meets them: plain, then Shift)
--   Keys.Mode()                "shy" or "own". Unpicked: "own" for keys laid out on your own before there was a
--                              choice, else "shy"
--   Keys.Hotkeys.Plan(opts)    what setting them would change now, with nothing done
--       -> { changes = { { key, from, to }, ... } (to "": let go), lose = { binding, ... } (what has a key now and
--            would have none), freed = { key, ... } (keys let go of a button that has its own), bar (the side bar is on) }
--   Keys.Hotkeys.Take(opts, quiet)   sets them, each key's old binding kept the first time it is changed, and a key
--                              that presses another key's button let go (kept too), so every button shows its own.
--                              A key set here and bound to something else by you since is yours: kept as it is
--                              from then on. quiet: only the keys set here before and still as set (the stance
--                              keys of another class on the same key bindings).
--                              -> { bound, cleared, kept } or nil, "combat"
--   Keys.Hotkeys.Back()        every key changed here is as it was, but one you have bound to something else
--                              since.  -> { put, kept, lost } or nil, "combat"
--   Keys.Hotkeys.On()          whether they are set, for the key bindings in use (the account's, or this character's own)
--   Keys.Hotkeys.Kept()        how many of your keys are kept from before, and when they were first set
--   Keys.Hotkeys.Yours(opts)   every key of yours that does something now (not a bar's button) the hotkeys take or
--                              would, a hand's first: { key, from, to, kept, move, must, also }
--   Keys.Hotkeys.Keep(key, on) / Keeps(key)   keeps a key as you have it, out of the board (its job left off);
--                              with the hotkeys set it is done at once.  -> true, or false in a fight
--
-- What a key did before the board took it moves to Ctrl + that key (Keys.Hotkeys.HomeOf: C's character window
-- to Ctrl + C, B's bags to Ctrl + B, Mouse 4's autorun to Ctrl + Mouse 4), while that does nothing yet; one home a
-- binding, and none for what moves you, turns the bar's pages or presses a button. A home is bound, kept and put
-- back like any key set here (it was nothing before), said in chat when it is made, and goes again when you keep
-- the key it came from. The plan's changes hold the homes too (from "": a free key), and plan.homes lists them.
--
-- A layout's hotkeys never take a key of yours unseen: the keys' panel lists each one before you choose, and a
-- chat command that would take one opens the panel instead (Keys.Run).
--
-- Until they are set, what is drawn before a layout (the keys at a level, a busy key) reads the keys as they
-- will be (Coming); a layout itself always reads them as they are (`live`).
--
--   Keys.Lay(addon, jobs, opts)   the hotkeys as picked, then Apply: what a player's "lay out my keys" does
--   Keys.Unlay(addon)          Revert, then the hotkeys back: every button and key as before
--   Keys.SetMode(mode)         picks; with keys laid out it is done at once (put back, the hotkeys switched,
--                              laid out again).  -> true, or false in a fight
--   Keys.Wanted()              whether this character's keys are laid out, or the open setup window means to
--                              (the bars are then all there, with the flyouts: nothing of a layout hides)
--
-- ShyKeysDB.hotkeys (account-wide, kept through a reset and a change of profile) holds mode (the pick), keep (the
-- keys you keep as they are: key -> true) and sets: by the bindings in use ("account" or a character's GUID), was (each
-- key changed here -> what it did before, "" for nothing), set (-> what it was set to, "" for let go), on, at.

local Hot = {}
Keys.Hotkeys = Hot
Hot.ButtonOf = Button        -- a key's own button (the grid's; the number row's by its flyout)
HOT.fixed = 2                -- what a set of hotkeys was last brought up to (state.homed): 1 gave the keys the board
                             -- took a home on Ctrl; 2 has the side keys strafe when the board takes every key that did

-- (The same keyboard gives the same two tables every time: they are read, never written. A board differs by the
-- way you move, what your two side keys do now, and the flyouts' shapes.)
HOT.order, HOT.boards, HOT.orders = {}, {}, {}
for _, shift in ipairs({ "", "SHIFT-" }) do
	for _, row in ipairs(HOT.rows) do
		for key in row:gmatch(".") do HOT.order[#HOT.order + 1] = shift .. key end
	end
	for _, key in ipairs(HOT.mouse) do HOT.order[#HOT.order + 1] = shift .. key end
end

-- Where each thing of the stance bar stands on it now: its name -> its place. nil while the game keeps the bar
-- secret (a fight): whoever asks keeps what it knew.
local function Stances()
	local at = {}
	for i = 1, GetNumShapeshiftForms() do
		local _, _, _, id = GetShapeshiftFormInfo(i)
		if id ~= nil and issecretvalue(id) then return nil end
		local name = id and C_Spell.GetSpellName(id)
		if name then at[name] = at[name] or i end
	end
	HOT.stances = at
	return at
end
Keys.Stances = Stances

-- The keys you keep as they are (ShyKeysDB.hotkeys.keep: key -> true): the board leaves them out, so a job on one
-- is left off. nil for none.
local function Keeping()
	local book = DB() and DB().hotkeys
	local keep = book and book.keep
	return keep and next(keep) ~= nil and keep or nil
end

-- "a, b and c", the first `most` of them and how many more.
local function Several(names, most)
	local shown = {}
	for i = 1, math.min(most, #names) do shown[i] = names[i] end
	local more = #names - #shown
	if more > 0 then return table.concat(shown, ", ") .. (" and %d more"):format(more) end
	if #shown < 2 then return shown[1] or "" end
	return table.concat(shown, ", ", 1, #shown - 1) .. " and " .. shown[#shown]
end

-- What a binding does, as you'd say it: the game's name for it, or the spell, item or macro of yours it names.
local function BindingCalled(command)
	local kind, name = command:match("^(%u+) (.+)$")
	if kind == "MACRO" then return "Macro " .. name end
	if kind == "CLICK" then return (name:gsub(":.*$", "")) end
	if kind then return name end
	return GetBindingName(command)
end
Keys.BindingCalled = BindingCalled

-- Whether a hand relies on what a binding does without looking (HOT.musts), or it is something of yours.
local function Must(command)
	return HOT.musts[command] == true or command:find("^%u+ ") ~= nil
end

-- Whether you can still strafe that way once the board is set: a key that strafes now and that the board leaves
-- as it is (one off the grid, or one you keep), and one the hand on the board reaches (not the arrows). keep:
-- the keys you keep.
local function Strafes(command, way, keep)
	for _, key in ipairs({ GetBindingKey(command) }) do
		if not way.move[key] and not HOT.away[key] and (not GRID[key] or (keep and keep[key])) then return true end
	end
	return false
end

-- The keys you picked for a kept key's ability (ShyKeysDB.hotkeys.standIn: kept key -> the key you picked), while
-- each still does nothing else: kept key -> key, and in order.  -> the table (nil for none), and the pairs as text
local function StandIns(way, keep)
	local book = keep and DB() and DB().hotkeys
	local picked = book and book.standIn
	if not picked or not next(picked) then return nil, "" end
	local out, said, over = {}, {}, book.over or EMPTY
	for key, at in pairs(picked) do
		local button = keep[key] and GRID[key] and not way.move[key] and Button(key)
		local now = button and not GRID[at] and not way.move[at] and GetBindingAction(at)
		if now == "" or (now and (now == button or over[at] == now)) then
			out[key] = at
			said[#said + 1] = key .. ">" .. at
		end
	end
	table.sort(said)
	return #said > 0 and out or nil, table.concat(said, " ")
end
Hot.StandIns = StandIns

-- (whole: every key the board has a use for, the ones you keep with them)
-- Your side keys (A and D for WASD) do what they do now if it moves you sideways, else strafe; and they strafe
-- whenever the board takes every key you strafe with (Q and E as the game ships them), so you never lose it:
-- you turn with the mouse then, or on a key you pick. Kept (the list's Keep mine: keep[key] true) a side key
-- that turns you keeps turning; told to strafe (keep[key] false) it strafes even with a strafe of yours elsewhere.
-- A key you keep whose ability you gave another key (the list's quick bind): that key presses its button, after
-- the board's own in the order.
function Keys.Board(opts, scheme, whole)
	scheme = scheme or Keys.Scheme()
	local way = Keys.SCHEMES[scheme]
	local keeping = Keeping()
	local sides = {}
	for i, side in ipairs({ way.left, way.right }) do
		local strafe = i == 1 and "STRAFELEFT" or "STRAFERIGHT"
		local now = GetBindingAction(side)
		local told = keeping and keeping[side]
		sides[i] = (HOT.sides[now] and (now == strafe or told == true or (told ~= false and Strafes(strafe, way, keeping))))
			and now or strafe
	end
	local left, right = sides[1], sides[2]
	-- (a key you keep stands out of the board; the keys you move with never do)
	local keep, kept = not whole and keeping, ""
	if keep then
		local list = {}
		for key, on in pairs(keep) do
			if on and GRID[key] and not way.move[key] then list[#list + 1] = key end
		end
		table.sort(list)
		kept = table.concat(list, " ")
	end
	local ins, said = StandIns(way, keep)
	local id = scheme .. "|" .. left .. "|" .. right .. "|" .. Shape(HOT.plain).id .. "|" .. Shape(HOT.bar).id .. "|" .. kept .. "|" .. said
	local want = HOT.boards[id]
	if not want then
		want = {}
		for key in pairs(GRID) do
			if not way.move[key] and not (keep and keep[key]) then want[key] = Button(key) end
		end
		want[way.forward], want[way.back], want[way.left], want[way.right] = "MOVEFORWARD", "MOVEBACKWARD", left, right
		local order = HOT.order
		if ins then
			order = {}
			for i, key in ipairs(HOT.order) do order[i] = key end
			for _, key in ipairs(HOT.order) do
				if ins[key] then
					want[ins[key]] = Button(key)
					order[#order + 1] = ins[key]
				end
			end
		end
		HOT.boards[id], HOT.orders[id] = want, order
	end
	return want, HOT.orders[id]
end

-- Whether both flyouts' bars are on (the game's switches of its side bars).
local function Flyouts()
	local on = { GetActionBarToggles() }
	for _, toggle in ipairs(HOT.toggles) do
		if not on[toggle] then return false end
	end
	return true
end

-- What the core keeps of the hotkeys, account-wide.
local function HotBook()
	local db = DB()
	if not db then return { sets = {} } end   -- (asked before the saved settings are in: nothing kept)
	db.hotkeys = db.hotkeys or {}
	db.hotkeys.sets, db.hotkeys.off = db.hotkeys.sets or {}, nil
	return db.hotkeys
end

-- What is kept for the key bindings in use.  -> state, its id
-- (Not one key set here is still as set: the key bindings were reset to the game's, or bound over whole. The
-- hotkeys are no longer set there, and what was kept of them goes: nothing is bound back over what you have.)
local function Lapsed(state)
	if not (state and state.on and next(state.set)) then return false end
	-- (at log-in the game's own keys stand in until yours are loaded: that's no reset of yours)
	if GetCurrentBindingSet() == Enum.BindingSet.Default then return false end
	for key, ours in pairs(state.set) do
		if GetBindingAction(key) == ours then return false end
	end
	return true
end
local function HotState(make)
	local book = HotBook()
	local id = GetCurrentBindingSet() == Enum.BindingSet.Character and UnitGUID("player") or "account"
	local state = book.sets[id]
	if Lapsed(state) then
		book.sets[id], state = nil, nil
		Keys.gen = (Keys.gen or 0) + 1
	end
	if not state and make then
		state = { was = {}, set = {} }
		book.sets[id] = state
	end
	return state, id
end

function Hot.On()
	local state = HotState()
	return state ~= nil and state.on == true
end

-- At log-in the game moves turning and strafing to its newer keys (A and D strafe, Q and E turn), over whatever
-- those keys did. It does it out of sight, once for each character. That isn't you. So what your keys did when
-- last saved is kept (hotkeys.held, by the bindings in use), and with the hotkeys set every key that move touched
-- goes back, said once. A key it didn't touch stays as it is.
local function Held()
	local held = {}
	for _, key in ipairs(HOT.order) do held[key] = GetBindingAction(key) end
	for command in pairs(HOT.sides) do
		for _, key in ipairs({ GetBindingKey(command) }) do held[key] = command end
	end
	return held
end
function Hot.Hold()
	if GetCurrentBindingSet() == Enum.BindingSet.Default then return end   -- (yours aren't loaded yet)
	local book = HotBook()
	local _, id = HotState()
	book.held = book.held or {}
	book.held[id] = Held()
end
-- -> how many keys went back, or nil, "combat" (done once the fight is over)
function Hot.Unturn()
	if InCombatLockdown() then
		HOT.unturn = true
		return nil, "combat"
	end
	HOT.unturn = nil
	local state, id = HotState()
	local held = HotBook().held
	held = held and held[id]
	if not (state and state.on and held) then return 0 end
	local put = 0
	for key, was in pairs(held) do
		local now = GetBindingAction(key)
		if now ~= was and (HOT.sides[now] or HOT.sides[was]) and SetBinding(key, was ~= "" and was or nil) then put = put + 1 end
	end
	if put > 0 then
		SaveBindings(GetCurrentBindingSet())
		Keys.gen = Keys.gen + 1
		Shy.core:Print("the game moved your turn and strafe keys. They're back as you had them.")
	end
	return put
end
hooksecurefunc("SaveBindings", function() Hot.Hold() end)
do
	local game = CreateFrame("Frame")
	game:RegisterEvent("NOTIFY_TURN_STRAFE_CHANGE")
	game:RegisterEvent("PLAYER_LOGOUT")
	game:RegisterEvent("PLAYER_REGEN_ENABLED")
	game:SetScript("OnEvent", function(_, event)
		if event == "NOTIFY_TURN_STRAFE_CHANGE" then
			C_Timer.After(0, Hot.Unturn)   -- (after the game is done moving them)
		elseif event == "PLAYER_LOGOUT" then
			Hot.Hold()
		elseif HOT.unturn then
			Hot.Unturn()
		end
	end)
end

function Hot.State()
	return (HotState())
end

-- (a home counts as none of yours: it did nothing before)
function Hot.Kept()
	local state = HotState()
	local homed = {}
	for _, home in pairs(state and state.homes or EMPTY) do homed[home] = true end
	local n = 0
	for key in pairs(state and state.set or EMPTY) do
		if not homed[key] then n = n + 1 end
	end
	return n, state and state.at
end

-- One key set (command "": let go), what it did before kept the first time. Set back to what it did before,
-- nothing is kept for it.  -> whether it changed
local function HotSet(state, key, command)
	local now = GetBindingAction(key)
	if now == command then return false end
	if not SetBinding(key, command ~= "" and command or nil) then return false end
	local was = state.was[key]
	if was == nil then was = now end
	if was == command then
		state.was[key], state.set[key] = nil, nil
	else
		state.was[key], state.set[key] = was, command
	end
	return true
end

-- A key you have asked the board to take back after it drifted, picked in the list and not saved yet.
local function Took(key)
	local book = DB() and DB().hotkeys
	return book ~= nil and book.took ~= nil and book.took[key] == true
end

-- A key set here that you have bound to something else since: yours, never taken again (Take keeps it).
-- Unless you have asked for it back: from that pick until it is saved it counts as the board's again, so the
-- list draws where it would leave you rather than the drift you are undoing.
local function TheirKey(state, key)
	return state ~= nil and state.on == true and state.set[key] ~= nil and GetBindingAction(key) ~= state.set[key]
		and not Took(key)
end

-- A button of the bars' picture: a key that presses one and isn't its own is let go, so each shows its key.
local function Pictured(command)
	return command:find("^ACTIONBUTTON%d") ~= nil or command:find("^MULTIACTIONBAR%dBUTTON%d") ~= nil
end

-- Whether a binding turns the main bar's pages: the layout keeps the bar on its own page, so it goes without a
-- home, and is said in one line rather than key by key.
function Hot.Paging(command)
	return command:find("ACTIONPAGE") ~= nil
end

-- Where what a key did goes when the board takes the key: Ctrl + that key (the character window from C to
-- Ctrl + C), so a hand finds it by the letter it knows. Only while Ctrl + the key does nothing (or that already),
-- one key a binding, and never what moves you, turns the bar's pages or presses a bar's button (its ability goes
-- with its key). taken: keys and bindings given a home already this time, filled in.  -> the key, or nil
-- The key you picked for it in the list comes first (ShyKeysDB.hotkeys.homeAt: binding -> key), while it is still
-- free; else Ctrl + the key. What moves you goes only to a key you picked (turning, once A strafes).
function Hot.HomeOf(key, command, taken)
	if command == "" or Pictured(command) or Hot.Paging(command) then return nil end
	if taken and taken[command] then return nil end
	local book = DB() and DB().hotkeys
	local picked = book and book.homeAt and book.homeAt[command]
	if HOT.moving[command] and not picked then return nil end
	local over = book and book.over
	for _, home in ipairs({ picked or false, not HOT.moving[command] and HOT.home .. key }) do
		local now = home and not (taken and taken[home]) and not Keys.Moving(home) and GetBindingAction(home)
		-- (the key you picked may do something else, while it is still what you said it could stop doing)
		if now == "" or now == command or (now and home == picked and over and over[home] == now) then
			if taken then taken[home], taken[command] = true, true end
			return home
		end
	end
end

-- What you picked in the list, account-wide beside the keys you keep: homeAt (a binding -> the key it goes to),
-- standIn (a key you keep -> the key its ability goes on) and over (a key you said may be taken from what it did:
-- the key -> what it did then; while it still does that, it is free to pick).
function Hot.Choices()
	local book = HotBook()
	book.homeAt, book.standIn, book.over = book.homeAt or {}, book.standIn or {}, book.over or {}
	book.took = book.took or {}
	return book
end

-- A key you bound to something else yourself after it was set here: yours.
function Hot.Mine(key)
	return TheirKey(HotState(), key)
end

-- Whether a key can be picked in the list for `does` (a binding going to a new home, or the button of `kept`, the
-- key you keep, for its ability): the left and right mouse buttons never, nor a key you move with or one of the
-- board's; and one picked for something else, or that does something else now, only once you are sure.
--   -> true, or false and why, said on the row; and when you can have it once you are sure, the question:
--   { text, yes (the button's words), homeAt (the binding picked for it), standIn (the kept key picked for it),
--   over (what it does now) }, for Hot.TakeOver
function Hot.Free(key, does, kept)
	if not key or key == "" then return false, "" end
	local said = Keys.Key(key)
	if key == "BUTTON1" or key == "BUTTON2" then return false, "Your left and right mouse buttons stay as they are." end
	if Keys.Moving(key) then return false, said .. " moves you. Pick another key." end
	if Keys.Board(nil, nil, true)[key] and not Hot.Keeps(key) then
		return false, said .. " is one of your new keys. Pick one off them, like Ctrl + a key."
	end
	local book = Hot.Choices()
	local here = kept and ("%s's ability"):format(Keys.Key(kept)) or BindingCalled(does)
	local yes = "Use " .. said
	for command, at in pairs(book.homeAt) do
		if at == key and command ~= does then
			local why = ("%s is picked for %s already."):format(said, BindingCalled(command))
			return false, why, { text = ("%s Use it for %s instead?"):format(why, here), yes = yes, homeAt = command }
		end
	end
	for other, at in pairs(book.standIn) do
		if at == key and other ~= kept then
			local why = ("%s is picked for %s's ability already."):format(said, Keys.Key(other))
			return false, why, { text = ("%s Use it for %s instead?"):format(why, here), yes = yes, standIn = other }
		end
	end
	local now = GetBindingAction(key)
	if now ~= "" and now ~= does and book.over[key] ~= now then
		local name = BindingCalled(now)
		local left = false            -- (another key does it too: it keeps that one)
		for _, other in ipairs({ GetBindingKey(now) }) do
			if other ~= key then left = true end
		end
		-- (a kept key's ability: what the key did goes to Ctrl + it, as with the board's keys)
		local home = not left and kept and Hot.HomeOf(key, now)
		local text = ("%s does %s. Use it for %s instead?"):format(said, name, here)
		if left then
			text = ("%s %s stays on its other key."):format(text, name)
		elseif home then
			text = ("%s %s moves to %s."):format(text, name, Keys.Key(home))
		else
			text = ("%s %s is left without a key."):format(text, name)
		end
		return false, ("%s does %s. Pick a key that does nothing yet."):format(said, name),
			{ text = text, yes = yes, over = now }
	end
	return true
end

-- You are sure: the key Hot.Free asked about is yours to pick. What it does now may be bound over (put back
-- whenever the pick or the hotkeys go), or the pick it had lets it go. Then pick it again.  -> true, or false and why
function Hot.TakeOver(key, ask, defer)
	if InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	if ask.over then
		Hot.Choices().over[key] = ask.over
	elseif ask.standIn then
		return Hot.SetStandIn(ask.standIn, nil, defer)
	elseif ask.homeAt then
		-- (the key of yours that did it: where Ctrl + that key is its place again)
		local mine = Keys.Mine()
		for _, entry in ipairs(mine and Hot.Yours(mine.opts) or EMPTY) do
			if entry.from == ask.homeAt then return Hot.SetHome(entry.key, ask.homeAt, nil, defer) end
		end
		Hot.Choices().homeAt[ask.homeAt] = nil
		Keys.gen = Keys.gen + 1
	end
	return true
end

-- What a list of homes says in chat: "Character Info (Ctrl + C) and Open All Bags (Ctrl + B)".
function Hot.Homes(homes)
	local names = {}
	for i, entry in ipairs(homes) do names[i] = ("%s (%s)"):format(BindingCalled(entry.command), Keys.Key(entry.home)) end
	return Several(names, HOT.named)
end

-- The keys that press another key's button, for every button the board gives a key: fn(key, the button's binding).
-- (a key you keep is never let go)
local function Others(want, keep, command, fn, ...)
	for i = 1, select("#", ...) do
		local other = select(i, ...)
		if want[other] == nil and not keep[other] then fn(other, command) end
	end
end
local function Strays(want, order, fn)
	local seen, keep = {}, Keeping() or EMPTY
	for _, key in ipairs(order) do
		local command = want[key]
		if command and Pictured(command) and not seen[command] then
			seen[command] = true
			Others(want, keep, command, fn, GetBindingKey(command))
		end
	end
end

-- (Worked out once a frame for a state, whoever asks: the sentence, the caps' marks, setup's line.)
function Hot.Plan(opts)
	local want, order = Keys.Board(opts)
	local kept = HOT.plan
	if kept and kept.want == want and kept.at == GetTime() and kept.gen == Keys.gen then
		kept.bar = Flyouts()   -- (a bar switched on or off says nothing)
		return kept
	end
	local plan = { changes = {}, lose = {}, freed = {}, homes = {}, want = want, order = order, at = GetTime(), gen = Keys.gen }
	HOT.plan = plan
	local after = {}             -- the keys that change -> what each does then
	local state = HotState()
	local taken, homed = {}, {}
	for _, key in ipairs(order) do
		local to = want[key]
		local from = to and GetBindingAction(key)
		if to and from ~= to and not TheirKey(state, key) then
			plan.changes[#plan.changes + 1] = { key = key, from = from, to = to }
			after[key] = to
			local home = Hot.HomeOf(key, from, taken)
			if home then
				plan.homes[#plan.homes + 1] = { key = key, home = home, command = from }
				homed[from] = true
			end
		end
	end
	Strays(want, order, function(key, command)
		plan.changes[#plan.changes + 1] = { key = key, from = command, to = "" }
		plan.freed[#plan.freed + 1] = key
		after[key] = ""
	end)
	for _, entry in ipairs(plan.homes) do
		if GetBindingAction(entry.home) ~= entry.command then
			-- (a home you picked over something it did: that changes, and is said with the rest)
			plan.changes[#plan.changes + 1] = { key = entry.home, from = GetBindingAction(entry.home), to = entry.command, home = entry.key }
			after[entry.home] = entry.command
		end
	end
	-- What has a key now and would have none: nothing the board itself gives a key, nothing with a key left, and
	-- no button of a bar (the ones under the keys you move with are clicked, as the board means them to be).
	local held, asked = {}, {}
	for _, command in pairs(want) do held[command] = true end
	for _, change in ipairs(plan.changes) do
		local from = change.from
		if from ~= "" and not held[from] and not homed[from] and not asked[from] and not Pictured(from) then
			asked[from] = true
			local left = false
			for _, key in ipairs({ GetBindingKey(from) }) do
				if after[key] == nil then left = true end
			end
			if not left then plan.lose[#plan.lose + 1] = from end
		end
	end
	plan.bar = Flyouts()
	return plan
end

function Hot.Take(opts, quiet)
	if InCombatLockdown() then return nil, "combat" end
	local result = { bound = 0, cleared = 0, kept = 0, freed = 0 }
	local state = HotState(not quiet)
	if not state or (quiet and not state.on) then return result end
	-- Forced (Keys.Run): every key you kept is the board's again, and the key picked for its ability with it.
	local forced = Keys.forced and not quiet
	if forced then
		local book = HotBook()
		for _ in pairs(book.keep or EMPTY) do result.freed = result.freed + 1 end
		book.keep = nil
		if book.standIn then wipe(book.standIn) end
	end
	local want, order = Keys.Board(opts)
	local homes, taken = {}, {}
	-- Set before what a set is brought up to now (quiet too: it is the next log-in): once, the side keys strafe
	-- where the board took every key that did, and every key still as set here gives what it did a home.
	local fixing = state.on == true and (tonumber(state.homed) or (state.homed and 1) or 0) < HOT.fixed
	local way = Scheme()
	local book = HotBook()
	local picked = {}            -- the keys picked for a kept key's ability -> that key
	for kept, at in pairs(book.standIn or EMPTY) do picked[at] = kept end
	for _, key in ipairs(order) do
		local command = want[key]
		if command and forced and TheirKey(state, key) then
			-- (bound to something else by you since: taken all the same, what you bound kept for Put back)
			state.was[key], state.set[key] = nil, nil
			result.freed = result.freed + 1
		end
		if command and not quiet and TheirKey(state, key) then
			if picked[key] then
				-- (the key you picked for an ability, bound to something else since or let go: the pick goes)
				book.standIn[picked[key]], state.was[key], state.set[key] = nil, nil, nil
				if book.over then book.over[key] = nil end
			else
				-- (bound to something else by you since it was set here: yours from now on, kept as it is)
				book.keep = book.keep or {}
				book.keep[key], state.was[key], state.set[key] = true, nil, nil
			end
			result.kept = result.kept + 1
		else
			-- (quiet: a key is ours only while it is still as it was set here; or a side key, brought up to date)
			local side = fixing and (key == way.left or key == way.right) and HOT.sides[GetBindingAction(key)]
			local ours = not quiet or side or (state.set[key] ~= nil and GetBindingAction(key) == state.set[key])
			local now = GetBindingAction(key)
			if command and ours and HotSet(state, key, command) then
				result.bound = result.bound + 1
				local home = not quiet and Hot.HomeOf(key, now, taken)
				if home then homes[#homes + 1] = { key = key, home = home, command = now } end
				-- (a side key that turned you strafes: said, unless turning has a key you picked, said with the homes)
				if HOT.steer[command] and HOT.steer[command] == now and not home then
					result.strafe = (result.strafe and (result.strafe .. " and ") or "") .. Keys.Key(key)
				end
			end
		end
	end
	if fixing then
		for _, key in ipairs(order) do
			local was = state.was[key]
			if state.set[key] ~= nil and GetBindingAction(key) == state.set[key] and was and was ~= "" then
				local home = Hot.HomeOf(key, was, taken)
				if home then homes[#homes + 1] = { key = key, home = home, command = was } end
			end
		end
	end
	if not quiet then
		-- (a key that became yours just now leaves the board first; and once the keys are set, a key you bound to
		-- a button yourself since is yours: only the game's keys from before are let go)
		if result.kept > 0 then want, order = Keys.Board(opts) end
		local before = state.on == true
		Strays(want, order, function(key)
			if before and state.set[key] == nil and not forced then return end
			if HotSet(state, key, "") then result.cleared = result.cleared + 1 end
		end)
		state.on, state.at = true, state.at or time()
	end
	-- What the board took moves to Ctrl + its key (one of yours bound there since is never touched).
	local made, homed = {}, 0
	if state.on then
		state.homes, state.homed = state.homes or {}, HOT.fixed
		for _, entry in ipairs(homes) do
			local there = GetBindingAction(entry.home) == entry.command
			if there or HotSet(state, entry.home, entry.command) then
				state.homes[entry.key] = entry.home
				made[#made + 1] = entry
				if not there then homed = homed + 1 end
			end
		end
		if #made > 0 then
			Shy.core:Print(("you haven't lost anything. On new keys now: %s. /shy keys lists every key that changed."):format(Hot.Homes(made)))
		end
		if result.strafe then
			Shy.core:Print(("%s strafe now, since the keys you strafed with hold abilities. Hold the right mouse button to turn, or keep them turning in /shy keys."):format(result.strafe))
		end
	end
	result.homes = made
	if result.bound + result.cleared + homed > 0 then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	return result
end

function Hot.Back()
	if InCombatLockdown() then return nil, "combat" end
	local result = { put = 0, kept = 0, lost = 0 }
	local state, id = HotState()
	if not state then return result end
	local left = { was = {}, set = {} }   -- a key the game wouldn't take back stays kept, to be put back yet
	for key, ours in pairs(state.set) do
		local was = state.was[key] or ""
		if GetBindingAction(key) ~= ours then
			result.kept = result.kept + 1     -- bound to something else by you since: yours
		elseif SetBinding(key, was ~= "" and was or nil) then
			result.put = result.put + 1
		else
			result.lost = result.lost + 1
			left.was[key], left.set[key] = was, ours
		end
	end
	HotBook().sets[id] = result.lost > 0 and left or nil
	if result.put > 0 then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	return result
end

-- Whether you keep a key as it is.
function Hot.Keeps(key)
	local keep = Keeping()
	return keep ~= nil and keep[key] == true
end

-- Keeps a key as it is, or lets the hotkeys have it. With the hotkeys set it is done now: the key back as it was
-- (only while it is still as set here) or set, and keys laid out are laid out again around it. A side key let go
-- is told to strafe (false), so a strafe of yours elsewhere doesn't leave it turning (Keys.Board).
--   -> true, or false in a fight. defer: only noted, nothing bound (setup's page: Finish does it)
function Hot.Keep(key, on, defer)
	local way = Scheme()
	if on then
		on = true
	elseif key == way.left or key == way.right then
		on = false
	else
		on = nil
	end
	local had = HotBook().keep
	local state = HotState()
	-- A key bound to something else since it was set here counts as yours whether you said to keep it or not,
	-- so the list draws it as kept. Asking for the board's key back has to go through, or there is no way to
	-- take it: the early way out would see nothing to change and leave the key as it drifted.
	local drifted = not on and TheirKey(state, key)
	if (had and had[key]) == on and not drifted then return true end
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false end
	local book = Hot.Choices()
	book.keep = book.keep or {}
	book.keep[key] = on
	-- Asking a drifted key back is a pick of its own: there is nothing in the keys you keep to take it out of,
	-- so without this the list would see no change and the key would stay as it drifted. Noted now, done on save.
	book.took[key] = (drifted and defer) and true or nil
	if not on then book.standIn[key] = nil end   -- (the board's again: its ability on it, no other key for it; Take lets that one go)
	local mine = watched[1]
	local laid = set and mine ~= nil and Keys.Has(mine.addon)
	if laid then Keys.Revert(mine.addon) end
	if not on and TheirKey(state, key) then
		state.was[key], state.set[key] = nil, nil   -- (bound since: what it does now is what goes back)
	end
	if set and on and state.set[key] ~= nil and GetBindingAction(key) == state.set[key] then
		local was = state.was[key] or ""
		if SetBinding(key, was ~= "" and was or nil) then
			state.was[key], state.set[key] = nil, nil
			-- (back on its key, it leaves Ctrl + the key: while that is still as it was set here)
			local home = state.homes and state.homes[key]
			if home then
				state.homes[key] = nil
				if state.set[home] ~= nil and GetBindingAction(home) == state.set[home] then
					local before = state.was[home] or ""
					if SetBinding(home, before ~= "" and before or nil) then state.was[home], state.set[home] = nil, nil end
				end
			end
			SaveBindings(GetCurrentBindingSet())
		end
	elseif set and not on then
		Hot.Take(mine and mine.opts)
	end
	Keys.gen = Keys.gen + 1
	if laid then
		local result = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if result then mine.waiting = result.waiting end
	end
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- One binding of the hotkeys' own put back as it was, while it is still as set here.
local function HotUnset(state, key)
	if not (state and state.set[key] ~= nil and GetBindingAction(key) == state.set[key]) then return false end
	local was = state.was[key] or ""
	if not SetBinding(key, was ~= "" and was or nil) then return false end
	state.was[key], state.set[key] = nil, nil
	return true
end

-- Picks the key what `key` did goes to (command: what it did), or nil for Ctrl + the key again. With the
-- hotkeys set it moves at once: off the key it was on (while that is as set here), onto the new one.
--   -> true, or false and why (a key that can't be picked, or a fight), and Hot.Free's question when there is one
function Hot.SetHome(key, command, at, defer)
	-- (Ctrl + the key is its place anyway, while that does nothing else; one that does is asked about like any
	-- other key: Ctrl + V is the game's all nameplates, and pressing it for the enemy ones has to ask, not
	-- forget the pick)
	if at == HOT.home .. key and not HOT.moving[command] then
		local now = GetBindingAction(at)
		if now == "" or now == command then at = nil end
	end
	if at then
		local free, why, ask = Hot.Free(at, command)
		if not free then return false, why, ask end
	end
	local state = HotState()
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	local book = Hot.Choices()
	local was = book.homeAt[command]
	if was and was ~= at then book.over[was] = nil end   -- (a key you let go of is asked about again)
	book.homeAt[command] = at
	if set then
		state.homes = state.homes or {}
		local old = state.homes[key]
		if old then HotUnset(state, old) end
		state.homes[key] = nil
		local home = Hot.HomeOf(key, command, {})
		if home and (GetBindingAction(home) == command or HotSet(state, home, command)) then state.homes[key] = home end
		SaveBindings(GetCurrentBindingSet())
	end
	Keys.gen = Keys.gen + 1
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- Picks the key a kept key's ability goes on (nil: none, the ability left off). With the hotkeys set it is done
-- now: the key you picked before let go, the new one set to the kept key's button, and keys laid out are laid out
-- again on it.  -> true, or false and why, and Hot.Free's question when there is one
function Hot.SetStandIn(key, at, defer)
	local button = Hot.ButtonOf(key)
	if not button then return false, "" end
	if at then
		local free, why, ask = Hot.Free(at, button, key)
		if not free then return false, why, ask end
	end
	local state = HotState()
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	-- (an ability on another key: its own key is one you keep, back as you had it)
	if not Hot.Keeps(key) and not Hot.Keep(key, true, defer) then return false, "Your keys can be changed once the fight is over." end
	local book = Hot.Choices()
	local mine = watched[1]
	local laid = set and mine ~= nil and Keys.Has(mine.addon)
	if laid then Keys.Revert(mine.addon) end
	local old = book.standIn[key]
	if old and old ~= at then book.over[old] = nil end   -- (a key you let go of is asked about again)
	book.standIn[key] = at
	if set and old and old ~= at and HotUnset(state, old) then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	if set then Hot.Take(mine and mine.opts) end
	if laid then
		local result = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if result then mine.waiting = result.waiting end
	end
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- Every key of yours the hotkeys take, or would: one that does something of the game's or of yours now (not a
-- bar's button, whose ability goes wherever its key does, and not nothing), the ones a hand relies on first, then
-- as a hand meets them. Each { key, from (what it does, or did before it was set here), to (what the board
-- gives it), kept (it stays as it is), move (a key you move with: the board's whatever you keep), must (a hand
-- relies on it), also (another key that does it then, or nil), home (Ctrl + the key, where it goes or went, or
-- nil), paging (it turns the bar's pages: said in one line, after the rest), steer (a side key that turned you:
-- side is the strafe the board gives it, strafeAt the key you strafe that way with while it keeps turning, and
-- strafeFrom the key of yours that strafed before) }.
function Hot.Yours(opts)
	local whole, order = Keys.Board(opts, nil, true)
	local way = Scheme()
	local keep, state, move = Keeping() or EMPTY, HotState(), way.move
	local on = state ~= nil and state.on == true
	local homes, taken = state and state.homes or EMPTY, {}
	local book = DB() and DB().hotkeys
	-- (the strafe a side key gives you; a key you keep: off the keys you move with, or a side key kept turning)
	local function Side(key) return (key == way.left and "STRAFELEFT") or (key == way.right and "STRAFERIGHT") or nil end
	local function Kept(key) return keep[key] == true and (not move[key] or Side(key) ~= nil) end
	-- (a key the board changes yet: not while the hotkeys are set, when every change is made)
	local function Changes(key)
		local to = whole[key]
		return not on and to ~= nil and GetBindingAction(key) ~= to and not Kept(key)
	end
	local out = {}
	for i, key in ipairs(order) do
		local to, now = whole[key], GetBindingAction(key)
		local from, kept
		local pending              -- (noted on setup's page, not done yet: Finish does it)
		local took = Took(key) and not Kept(key)   -- (a drifted key you asked back, not saved yet)
		if on and state.set[key] ~= nil and now == state.set[key] then
			from = state.was[key] or ""
			if Kept(key) then kept, pending = true, true end
		elseif took then
			from, pending = now, true   -- what it does now is what moves, once you save
		elseif Kept(key) or TheirKey(state, key) then
			from, kept = now, true
		elseif Side(key) and to == now and now == HOT.steer[Side(key)] then
			-- (a side key the board leaves turning, as a strafe of yours elsewhere still stands: listed all the same,
			-- as one kept turning, so you see it and can have it strafe)
			from, kept = now, true
		elseif not on and now ~= to then
			from = now
		end
		-- (a side key kept turning: said against the strafe it would have had)
		local side = Side(key)
		local steer = side ~= nil and from ~= nil and from == HOT.steer[side]
		if steer and kept then to = side end
		if from and from ~= to and from ~= "" and not Pictured(from) then
			local also
			for _, other in ipairs({ GetBindingKey(from) }) do
				-- (its own new key isn't another: the row stays where it is as you switch it)
				if other ~= key and other ~= homes[key] and not Changes(other) then
					also = other
					break
				end
			end
			-- (or a key the board gives it: A strafing once Q is the board's)
			for _, other in ipairs(order) do
				if not also and other ~= key and whole[other] == from and not Kept(other) then also = other end
			end
			local home
			if took then
				home = Hot.HomeOf(key, from, taken)   -- (where it would go: the key isn't taken yet)
			elseif on and not kept then
				home = homes[key]
				if home and GetBindingAction(home) ~= from then home = nil end
				-- (another key picked for it since, not bound yet: the one it will have)
				local picked = book and book.homeAt and book.homeAt[from]
				if picked and picked ~= home and (GetBindingAction(picked) == "" or GetBindingAction(picked) == from) then
					home, pending = picked, true
				end
			elseif not kept then
				home = Hot.HomeOf(key, from, taken)
			end
			-- (a key you keep: the key you picked for its ability, while it stands)
			local ins = kept and StandIns(way, keep)
			-- (a side key kept turning: the key you strafe that way with then, the one you picked first)
			local strafeAt
			if steer and kept then
				strafeAt = book and book.homeAt and book.homeAt[side]
				for _, other in ipairs({ GetBindingKey(side) }) do
					if not strafeAt and other ~= key and not move[other] and not Changes(other) then strafeAt = other end
				end
			end
			out[#out + 1] = { key = key, from = from, to = to, kept = kept == true, move = move[key] == true,
				must = Must(from), also = also, home = home, standIn = ins and ins[key] or nil,
				paging = Hot.Paging(from), pending = pending, at = i,
				steer = steer or nil, side = steer and side or nil, strafeAt = strafeAt }
		end
	end
	-- (the key of yours that strafed before: where strafing is picked a key, as on its own row)
	for _, entry in ipairs(out) do
		if entry.steer then
			for _, other in ipairs(out) do
				if other.from == entry.side and not other.move then entry.strafeFrom = other.key end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.paging ~= b.paging then return b.paging end
		if a.must ~= b.must then return a.must end
		return a.at < b.at
	end)
	return out
end

function Keys.Mode()
	local picked = HotBook().mode
	if picked == "shy" or picked == "own" then return picked end
	local mine = watched[1]
	if mine and Keys.Has(mine.addon) and not Hot.On() then return "own" end
	return "shy"
end

-- The hotkeys a page draws the keys for, whatever is set: "shy" (the board) or "own" (yours: as they are, or
-- as they were before the board was set), or nil for the ones that stand. Setup's pick before Finish, and
-- either choice while the mouse is on it: you see both before you choose.
function Keys.Pretend(mode)
	if HOT.pretend == mode then return end
	HOT.pretend = mode
	Keys.look = Keys.look + 1   -- (what is drawn is drawn again; the keys themselves haven't changed)
end
Keys.look = 0

-- Which hotkeys the keys are drawn for, and whether those are the ones bound now.
function Keys.Shown()
	local shown = HOT.pretend or Keys.Mode()
	return shown, (shown == "shy") == Hot.On()
end

-- Your own keys while the board is set: every key changed here and still as set -> what it did before ("": nothing).
function Hot.Was()
	local state = HotState()
	local was = {}
	for key, ours in pairs(state and state.set or {}) do
		if GetBindingAction(key) == ours then was[key] = state.was[key] or "" end
	end
	return was
end

---------------------------------------------------------------------------
-- Picks made together: noted as you make them, done on one press
---------------------------------------------------------------------------

-- What you have picked in the list (the keys you keep, where what a key did goes, the key a kept key's ability
-- is on), as it stands. Setup's page and the /shy window both note picks against a copy of this and do them
-- together, so nothing of yours is bound until you say so and one press puts the lot back.
--   Hot.Picks()        -> a copy to keep
--   Hot.Unpick(was)    every pick since goes: the page is as it was
--   Hot.Changed(was)   whether anything has been picked since
--   Hot.Settle(was)    the picks since, done: bound now where the hotkeys are set, else kept for when they are
local PICKED = { "keep", "homeAt", "standIn", "over", "took" }

function Hot.Picks()
	local book = Hot.Choices()
	local copy = {}
	for _, name in ipairs(PICKED) do
		copy[name] = {}
		for k, v in pairs(book[name] or EMPTY) do copy[name][k] = v end
	end
	return copy
end

function Hot.Unpick(was)
	local book = Hot.Choices()
	for _, name in ipairs(PICKED) do
		book[name] = {}
		for k, v in pairs(was[name] or EMPTY) do book[name][k] = v end
	end
	Keys.gen = Keys.gen + 1
end

-- (the keys you said may be taken aren't a change of their own: they only let another pick be made)
function Hot.Changed(was)
	if not was then return false end
	local book = Hot.Choices()
	for _, name in ipairs(PICKED) do
		if name ~= "over" then
			local now, before = book[name] or EMPTY, was[name] or EMPTY
			for k, v in pairs(now) do
				if before[k] ~= v then return true end
			end
			for k, v in pairs(before) do
				if now[k] ~= v then return true end
			end
		end
	end
	return false
end

function Hot.Settle(was)
	if not was then return end
	local now = Hot.Picks()
	Hot.Unpick(was)
	Hot.Choices().over = now.over   -- (the keys you said may be taken: so, before the picks that take them)
	local mine = Keys.Mine()
	local from = {}              -- a binding -> the key of yours it was on
	for _, entry in ipairs(mine and Hot.Yours(mine.opts) or EMPTY) do from[entry.from] = from[entry.from] or entry.key end
	local seen = {}
	for _, list in ipairs({ now.keep, was.keep }) do
		for key in pairs(list) do
			if not seen[key] and now.keep[key] ~= was.keep[key] then Hot.Keep(key, now.keep[key]) end
			seen[key] = true
		end
	end
	-- The drifted keys you asked back, before the homes: the key has to be the board's again for what it did
	-- to be given somewhere to go.
	for key in pairs(now.took) do
		if not was.took[key] then Hot.Keep(key, nil) end
	end
	seen = {}
	for _, list in ipairs({ now.homeAt, was.homeAt }) do
		for command in pairs(list) do
			if not seen[command] and now.homeAt[command] ~= was.homeAt[command] then
				if from[command] then
					Hot.SetHome(from[command], command, now.homeAt[command])
				else
					Hot.Choices().homeAt[command] = now.homeAt[command]
				end
			end
			seen[command] = true
		end
	end
	for key, at in pairs(now.standIn) do
		if was.standIn[key] ~= at then Hot.SetStandIn(key, at) end
	end
	for key in pairs(was.standIn) do
		if now.standIn[key] == nil and Hot.Choices().standIn[key] ~= nil then Hot.SetStandIn(key, nil) end
	end
end

-- What the files after this one use.
ns.BindingCalled, ns.Hot, ns.HotBook, ns.HotState = BindingCalled, Hot, HotBook, HotState
ns.Keeping, ns.Several, ns.StandIns = Keeping, Several, StandIns
