-- ShyKeys: How you move and whose hotkeys: the choices, and what of yours they change
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local BindingCalled, Button, C, Drawn = ns.BindingCalled, ns.Button, ns.C, ns.Drawn
local EMPTY, HOT, Hot, Keep = ns.EMPTY, ns.HOT, ns.Hot, ns.Keep
local Keeping, Pick, Press, Pressable = ns.Keeping, ns.Pick, ns.Press, ns.Pressable
local Put, Scheme, Several, StandIns = ns.Put, ns.Scheme, ns.Several, ns.StandIns
local Theme, watched = ns.Theme, ns.watched

---------------------------------------------------------------------------
-- How you move: the choice
---------------------------------------------------------------------------

-- Two choices, each with a little board: the keys you move with lit in your color.
local MINI = { cap = 15, gap = 2, tall = 76, apart = 12, rows = { { 0, "QWERT" }, { 0.35, "ASDFG" }, { 0.75, "ZXCVB" } } }

-- f:Light(lit): the keys lit, lit(letter) saying which.
local function MiniBoard(parent, lit)
	local f = CreateFrame("Frame", nil, parent)
	local step = MINI.cap + MINI.gap
	f:SetSize(math.ceil((5 + MINI.rows[#MINI.rows][1]) * step), #MINI.rows * step)
	local caps = {}
	for r, row in ipairs(MINI.rows) do
		for i = 1, #row[2] do
			local letter = row[2]:sub(i, i)
			local cap = CreateFrame("Button", nil, f)
			cap:SetSize(MINI.cap, MINI.cap)
			cap:SetPoint("TOPLEFT", math.floor((row[1] + i - 1) * step), -(r - 1) * step)
			cap:EnableMouse(false)   -- (a picture: the click is the choice's it stands on)
			UI.KeyPlate(cap)
			cap.words = UI.Text(cap, letter, 9, true, C.dim)
			cap.words:SetPoint("CENTER")
			caps[letter] = cap
		end
	end
	function f:Light(which)
		for letter, cap in pairs(caps) do
			local on = which(letter) == true
			cap:SetTone(on and Theme.Accent or nil, on)
			Theme.Ink(cap.words, on and C.head or C.dim)
		end
	end
	if lit then f:Light(lit) end
	return f
end

local function Choice(parent, width, scheme, words, onPick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, MINI.tall)
	UI.KeyPress(b, { fill = C.bg })
	b.board = MiniBoard(b, function(letter) return Keys.SCHEMES[scheme].move[letter] end)
	b.board:SetPoint("LEFT", 14, 0)
	b.title = UI.Text(b, Keys.SCHEMES[scheme].name, 16, true, C.head)
	b.title:SetPoint("TOPLEFT", b.board, "TOPRIGHT", 16, 2)
	b.say = UI.Text(b, words, 12, false, C.dim)
	b.say:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
	b.say:SetPoint("RIGHT", -12, 0)
	b.say:SetJustifyH("LEFT")
	b.say:SetWordWrap(true)
	b.say:SetMaxLines(2)
	b:SetScript("OnClick", function() onPick(scheme) end)
	return b
end

---------------------------------------------------------------------------
-- Your hotkeys: the choice, and what of yours it changes
---------------------------------------------------------------------------

-- Three choices side by side, each a state your keys can be in, said as a player would say it: "Set it up for
-- me" (every ability on its key, the hotkeys set to match: recommended), "Keep my hotkeys" (the same abilities
-- on the keys you already have) and "How I had it" (nothing laid out: every button and hotkey as you had it).
-- Each has its title, its name inside a sentence (name), its word on setup's rail (brief), what the button
-- says to make it (act) and a sentence. The one in use says so. A click, or the mouse
-- on one, looks at it: the keys are drawn for that choice and nothing is bound. Under them, what the choice
-- looked at does to what is yours, in a sentence with a tick (nothing of yours is lost), then what loses its
-- key, the keys let go of a bar, the macros that go among the account's, and in gold why it can't be used yet.
-- In the /shy window one button makes the choice looked at (f:Use; the keys' panel has it); in setup the choice
-- is plan.keys.pick ("shy", "own", "off"), made on Finish.
--   Keys.Hotkeys.Panel(parent, width, plan, onPick)   f:Refresh()
--   f:State()      what is in use: "shy", "own", "off", or "set" (the hotkeys set and no keys laid out here)
--   f:Pending()    the choice looked at, when it isn't the one in use; nil in setup
--   f:Label()      what the button says: what it would do
--   f:Use()        makes it.  -> true, or false in a fight
--   f.shown        the choice the keys are drawn for
local HOTVIEW = {
	tall = 62, apart = 12, pad = 14, tick = 14, most = 5,
	-- The list of your keys that change: a row (what happens, then the line that picks where it goes) and its
	-- caption; the key's plate and the text after it; whose key it is, at the right, under the column that
	-- says what that answers; the numbers beside the caption.
	row = 52, caption = 16, plate = 22, lead = 96, choice = 132, target = 118, tallyWidth = 230,
	cols = 22,               -- the line naming the columns, over the first row (and the air under it)
	band = 16,               -- the heading over each part of the list
	cell = 32,               -- an ordinary key's row: one line of cells, read straight across
	movedLeast = 116,        -- the column naming what this key pushed off it, at its narrowest and widest
	movedMost = 210,         -- ("Item Comparison Cycling", "Sheath/Unsheath Weapon")
	asideTall = 16,          -- the line under the cells, where one is needed
	saveTall = 46,           -- the bar that comes up once something is waiting to be saved
	saveUnder = 14,          -- its fill carried on below it, to the window's own edge
	saveShade = 16,          -- the shade over it: the list carries on under the bar
	rows = 6,                -- the rows shown before "Show N more" (the ones a hand relies on come first)
	choose = 118,            -- a choice on setup's page of choices alone: tall enough for its sentence whole
	more = 22,               -- that line's height
	order = { "shy", "own", "off" },
	picks = {
		shy = { title = "Set it up for me", name = "your new keys", brief = "set up", tag = "Recommended", act = "Set up my keys",
			say = "Every ability gets its own key. What a key did before moves to Ctrl + that key." },
		own = { title = "Keep my hotkeys", name = "your own hotkeys", brief = "on my hotkeys", tag = "Not recommended", act = "Keep my hotkeys",
			say = "Abilities go on the keys you already use. Any whose key is taken is left off." },
		off = { title = "How I had it", name = "how you had it", brief = "left alone", tag = "Yours", act = "Put it all back",
			say = "Your buttons and hotkeys, exactly as you had them." },
	},
}
-- The jobs that can't stand on the keys as they are bound now: their keys do something else.
local function Stuck(mine)
	local out = {}
	local was = ns.live
	ns.live = true
	for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
		if job.key and not Pressable(job.key, mine.opts, job.spare) then out[#out + 1] = job end
	end
	ns.live = was
	return out
end

-- What a pick does to your keys, for whoever says it: safe (the sentence), notes (what loses its key, what is
-- let go, which abilities are left off), warn (a flyout's bar is off), changes (how many keys of yours change).
function Hot.Says(pick, plan)
	local mine = watched[1]
	local says = { notes = {}, changes = 0 }
	if pick == "off" then
		says.safe = ((mine and Keys.Has(mine.addon)) or Hot.On()) and "Every button and hotkey goes back exactly as you had it."
			or "This is what you have now. Nothing of yours is changed."
		return says
	end
	-- What of yours a layout would move to a free button: said before anything is done.
	local moves = mine and Keys.Displaces(mine.addon, mine.jobs, mine.opts) or EMPTY
	if #moves > 0 then
		says.notes[#says.notes + 1] = ("%s of your own move to a free button: %s. %s back where %s when you put your keys back."):format(
			#moves == 1 and "One" or tostring(#moves), Several(moves, HOTVIEW.most), #moves == 1 and "It goes" or "They go", #moves == 1 and "it was" or "they were")
	end
	-- The macros a layout comes to: among the account's when the character's are full, and no layout without room.
	local space = mine and Keys.Space(mine.addon, mine.jobs, mine.opts)
	if space and space.short > 0 then
		says.block = ("Not enabled yet: your keys need %d macros and there is room for %d. Delete %d you don't use, this character's or the account's, and they can be laid out. Your own macros are never touched here."):format(
			space.need, space.need - space.short, space.short)
	elseif space and space.spill > 0 then
		says.notes[1] = ("This character has room for %d of your keys' %d macros, so %d go among the account's, which every character sees. They are removed when you go back; your own are never touched."):format(
			math.max(0, space.character), space.need, space.spill)
	end
	if pick == "own" then
		says.safe = Hot.On() and "Your own hotkeys come back, each as it was before."
			or "Your hotkeys stay as they are. Only a key that does nothing now may be given a button."
		-- (the abilities that wait, their keys doing something else: listed on the page, a row each)
		local stuck = mine and not Hot.On() and Stuck(mine) or {}
		if #stuck > 0 then says.waits = stuck end
		return says
	end
	-- The abilities whose keys you keep: left off, said by name.
	local keep = Keeping()
	if keep and mine then
		local off = {}
		local ins = StandIns(Scheme(), keep) or EMPTY   -- (one you gave another key isn't left off)
		for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
			-- (nor one whose kept key presses its button anyway: it stands, as you have it)
			if job.key and keep[job.key] and not ins[job.key] and not Keys.Moving(job.key) and Hot.Pressing(job.key, mine.opts) == "" then
				off[#off + 1] = ("%s (%s)"):format(job.name, Keys.Key(job.key))
			end
		end
		-- (said on the page by each kept key's row, not again under the sentence)
		if #off > 0 then says.keptOff = ("Left off, because you keep their keys: %s."):format(Several(off, HOTVIEW.most)) end
	end
	if Hot.On() then
		-- (counted as the plan counted them: the keys that did something before)
		local state = Hot.State()
		local kept = 0
		for key in pairs(state and state.set or EMPTY) do
			if (state.was[key] or "") ~= "" then kept = kept + 1 end
		end
		says.safe = kept > 0 and ("%d of your hotkeys were changed. Each is saved, and one click puts them all back."):format(kept)
			or "Your hotkeys already matched: nothing of yours was changed."
		return says
	end
	local will = Hot.Plan(mine and mine.opts)
	for _, change in ipairs(will.changes) do
		if change.from ~= "" then says.changes = says.changes + 1 end
	end
	local back = plan and "one click in /shy keys puts them all back" or "one click puts them all back"
	if says.changes > 0 then
		says.safe = ("%d of your hotkeys change. Each is saved, and %s."):format(says.changes, back)
	elseif #will.changes > 0 then
		says.safe = ("None of your hotkeys change: %d keys that do nothing now get a button."):format(#will.changes)
	else
		says.safe = "Your hotkeys already match: nothing of yours changes."
	end
	-- (what loses its key is said key by key in the list under it: Hot.Yours)
	if #will.freed > 0 then
		local keys = {}
		for i, key in ipairs(will.freed) do keys[i] = Keys.Key(key) end
		says.notes[#says.notes + 1] = ("These no longer press a bar: %s."):format(Several(keys, 12))
	end
	if not will.bar then says.warn = "A side bar is off, so the number row's buttons don't all show yet. The console's layout turns both on." end
	return says
end

-- A choice: its name across the top, under it what it is called for ("Recommended") and, on the one in use, a
-- tick and "In use" at the right; then its sentence. The keys under the tiles are its picture.
local function HotTile(parent, width, pick, onPick)
	local def = HOTVIEW.picks[pick]
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOTVIEW.tall)
	UI.KeyPress(b, { fill = C.bg })
	b.title = UI.Text(b, def.title, 15, true, C.head)
	b.title:SetPoint("TOPLEFT", HOTVIEW.pad, -HOTVIEW.pad)
	b.title:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.title:SetJustifyH("LEFT")
	b.title:SetWordWrap(false)
	b.tag = UI.Text(b, def.tag, 11, true, pick == "shy" and C.good or C.dim)
	b.tag:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
	b.use = UI.Text(b, "Now", 11, true, C.good)   -- (what you have now, whatever is lit)
	b.use:SetPoint("TOP", b.tag, "TOP")
	b.use:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.tick = b:CreateTexture(nil, "ARTWORK")
	b.tick:SetTexture(Shy.Skin.GLYPH.tick)
	b.tick:SetSize(10, 10)
	b.tick:SetPoint("RIGHT", b.use, "LEFT", -5, 0)
	Theme.Tint(b.tick, C.good, 1)
	-- (its sentence isn't shown on the card: the line under the cards says what the lit one does, whole)
	b.say = UI.Text(b, def.say, 12, false, C.dim)
	b.say:Hide()
	b.say:SetPoint("TOPLEFT", b.tag, "BOTTOMLEFT", 0, -9)
	b.say:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.say:SetJustifyH("LEFT")
	b.say:SetWordWrap(true)
	b.say:SetMaxLines(3)
	b:SetScript("OnClick", function() onPick(pick) end)
	return b
end

function Hot.Panel(parent, width, plan, onPick, part)
	local f = CreateFrame("Frame", nil, parent)
	local each = math.floor((width - (#HOTVIEW.order - 1) * HOTVIEW.apart) / #HOTVIEW.order)
	local tiles = {}
	function f:State()
		local mine = watched[1]
		if mine and Keys.Has(mine.addon) then
			-- (laid out, but on key bindings the hotkeys were never set for, a character's own: it stands on your keys)
			local mode = Keys.Mode()
			if mode == "shy" and not Hot.On() then return "own" end
			return mode
		end
		return Hot.On() and "set" or "off"
	end
	-- The choice lit: setup's pick; in the /shy window the one clicked, else the one in use, or the set-up
	-- while nothing is laid out (the one to try, drawn before it is made).
	local function Lit()
		if plan then
			local pick = plan.keys and plan.keys.pick
			return HOTVIEW.picks[pick] and pick or "off"   -- (left alone, "skip": drawn as you have them)
		end
		if HOT.viewing then return HOT.viewing end
		local state = f:State()
		-- (set up is your pick, but not set on these key bindings yet, a character's own: it is offered, every key listed)
		if state == "own" and Keys.Mode() == "shy" then return "shy" end
		return HOTVIEW.picks[state] and state ~= "off" and state or "shy"
	end
	function f:Pending()
		if plan then return nil end
		local lit = Lit()
		if lit ~= self:State() then return lit end
		-- (the choice in use, laid out by an earlier make of the layout: the new one is there to take)
		local mine = watched[1]
		return mine and lit ~= "off" and Keys.Old(mine.addon) and "new" or nil
	end
	function f:Title(pick)
		return HOTVIEW.picks[pick].name
	end
	function f:Label()
		local pending = self:Pending()
		if pending == "new" then return "Update my keys" end
		return pending and HOTVIEW.picks[pending].act or "In use"
	end
	function f:Use()
		local mine = watched[1]
		local pick = self:Pending()
		if not pick or not mine then return true end
		if InCombatLockdown() then
			Shy.core:Print("your keys can be changed once the fight is over.")
			return false
		end
		HOT.viewing = nil
		if pick == "new" then
			local result = Keys.Run(mine.addon, mine.jobs, mine.opts, true)
			if result then mine.waiting = result.waiting end
		elseif pick == "off" then
			Keys.Back(mine.addon)
		elseif Keys.Has(mine.addon) then
			Keys.SetMode(pick)
			mine.addon:Print(pick == "shy" and "your keys are set up now, hotkeys and all." or "your abilities are on your own hotkeys now.")
		else
			Keys.SetMode(pick)
			local result = Keys.Run(mine.addon, mine.jobs, mine.opts, true)   -- (every key it changes was listed)
			if result then mine.waiting = result.waiting end
		end
		return true
	end
	-- The pick being made on a row, and why a pick couldn't be: both held by the key they are about, never by the
	-- row that draws it. The list is sorted again whenever anything changes, so a row frame draws whichever key
	-- the list has in its place that time; a pick that went by the frame would land on another key.
	local listening              -- the row the keyboard is on, re-pointed to the key's row each time it is drawn
	local asked                  -- the entry the pick was begun on: what it is made for, whatever the list does
	local errs = {}              -- key -> why its last pick couldn't be made (its row says it, in red)
	-- Nothing of yours is bound as you pick. The rows show where a pick would leave you, Save does the lot at
	-- once, and Discard forgets them. (Setup's page has always worked this way and does them on Finish: there
	-- `plan` holds what to go back to.)
	--
	-- What to go back to is taken at the first pick and nowhere else. More than one of these lists is alive at
	-- a time -- the /shy window's and the one in the game's own options, and the room's other parts beside it --
	-- and a list that took it when it was built would hold a picture of your keys from before you ever touched
	-- the page. Putting that back on being hidden would undo every pick another list had saved, the whole book
	-- of them, not just its own. A list that you have not picked on has nothing to put back and holds nothing.
	f.was = nil
	local function Noting()
		if not plan and not f.was then f.was = Hot.Picks() end
		return true
	end
	-- (the owner draws everything again, this piece with it; alone, it draws itself)
	local function Again(pick)
		Keys.look = Keys.look + 1
		if onPick then onPick(pick) else f:Refresh() end
	end
	-- A click looks, and it stays looked at; nothing is bound.
	local function Pick(pick)
		if plan then
			plan.keys = plan.keys or {}
			plan.keys.pick = pick
		else
			HOT.viewing = pick
		end
		Again(pick)
	end
	-- Pointed at, a choice is drawn (its keyboards are some 40 ms): drawn again only where what is shown changes,
	-- and a leave waits a frame, so passing from one tile to the next draws once and the one lit not at all.
	local function Look(pick)
		f.leaving = nil
		-- (a key is being picked: the list stays as it is, so the row under the hand keeps its key)
		if listening then return end
		if f.looking == pick then return end
		local was = f.looking or Lit()
		f.looking = pick
		if (pick or Lit()) ~= was then Again() end
	end
	local function Leave()
		f.leaving = true
		C_Timer.After(0, function()
			if f.leaving then Look(nil) end
		end)
	end
	for i, pick in ipairs(HOTVIEW.order) do
		tiles[pick] = HotTile(f, each, pick, Pick)
		tiles[pick]:SetPoint("TOPLEFT", (i - 1) * (each + HOTVIEW.apart), 0)
		tiles[pick]:HookScript("OnEnter", function() Look(pick) end)
		tiles[pick]:HookScript("OnLeave", Leave)
	end
	f.tiles = tiles
	-- Step 2, what the choice changes: its title by the choice, its sentence that nothing of yours is lost, and at
	-- the right how many keys move, stay yours or wait.
	f.step2 = Hot.StepHead(f, 2, width)
	f.step2:SetPoint("TOPLEFT", 0, -(HOTVIEW.tall + 20))
	f.safe = f.step2.say
	f.tally = f.step2.side
	local indent = HOT.step + HOT.stepGap
	-- One part alone (a page of setup's walk): the choices, with what the lit one means under them; or what it
	-- changes, its sentence at the top and the list under it.
	f.part = part
	if part == "changes" then
		for _, tile in pairs(tiles) do tile:Hide() end
		f.step2:ClearAllPoints()
		f.step2:SetPoint("TOPLEFT")
		f.step2.plate:Hide()
		f.step2.title:Hide()
		f.safe:ClearAllPoints()
		f.safe:SetPoint("TOPLEFT")
		f.safe:SetWidth(width - HOTVIEW.tallyWidth)
		indent = 0
	elseif part == "choose" then
		f.step2:Hide()
		-- (each choice says what it is, whole; under them, what the lit one does to your keys)
		for _, tile in pairs(tiles) do
			tile:SetHeight(HOTVIEW.choose)
			tile.say:Show()
		end
		f.chosen = UI.Text(f, "", 13, false, C.text)
		f.chosen:SetPoint("TOPLEFT", 0, -(HOTVIEW.choose + 16))
		f.chosen:SetWidth(width)
		f.chosen:SetJustifyH("LEFT")
		f.chosen:SetWordWrap(true)
	end
	f.notes = UI.Text(f, "", 11, false, C.dim)
	f.notes:SetPoint("TOPLEFT", f.safe, "BOTTOMLEFT", 0, -6)
	f.notes:SetWidth(width - indent)
	f.notes:SetJustifyH("LEFT")
	f.warn = UI.Text(f, "", 11, false, C.alert)
	f.warn:SetWidth(width - indent)
	f.warn:SetJustifyH("LEFT")

	-- Every key of yours that changes, a row each across the page: the key on its plate and what it did (in gold
	-- when a hand relies on it), what happens to it in one line, the choice (the new key, or keep yours), and the
	-- key the thing that moves goes to: what the key did (Ctrl + it, unless you pick another), or the ability of
	-- a key you keep. Click that key, then press the one you want: it is checked and done at once. A key you move
	-- with is the board's whatever you pick: said, with no choice.
	f.caption = UI.Text(f, "", 11, false, C.dim)
	f.caption:SetJustifyH("LEFT")
	f.caption:SetWidth(width - indent)
	f.rows = {}
	local function Listen(row, on)
		if row == nil then return end
		row.target:EnableKeyboard(on)
		row.target:SetScript("OnKeyDown", on and row.heard or nil)
	end
	local function Stop()
		local row = listening
		listening, asked = nil, nil
		if row then Listen(row, false) end
		return row
	end
	f.Stop = Stop
	-- What a key you pressed is picked for: done, or why not (said on the row, in red, until the next pick).
	-- A key that does something else, or is picked for something else, is asked about: sure, it is yours.
	local function Pick(entry, key)
		-- (in setup only noted: Finish does it, Not now forgets it)
		-- (a side key kept turning: the key you strafe with, as the key that strafed before picks it)
		if entry.steer and entry.kept then return Hot.SetHome(entry.strafeFrom or entry.key, entry.side, key, Noting()) end
		if entry.kept then return Hot.SetStandIn(entry.key, key, Noting()) end
		return Hot.SetHome(entry.key, entry.from, key, Noting())
	end
	-- (sure of one thing, the key may yet ask another: a key picked for something else that did something before)
	local function Try(row, entry, key, ok, why, ask)
		errs[entry.key] = not ok and not ask and why ~= "" and why or nil
		Again()
		if not ask then return end
		UI.Confirm(row.target, ask.text, ask.yes, function()
			local sure, failed = Hot.TakeOver(key, ask, Noting())
			if not sure then return Try(row, entry, key, false, failed) end
			Try(row, entry, key, Pick(entry, key))
		end)
	end
	-- (the pick is made for the key the row showed when it began, never for whatever the list has there now)
	local function Picked(row, key)
		local entry = asked
		Stop()
		if not entry then return end
		Try(row, entry, key, Pick(entry, key))
	end
	-- (a fight is coming: the keyboard goes back to the game before it can't)
	f.guard = CreateFrame("Frame", nil, f)
	f.guard:RegisterEvent("PLAYER_REGEN_DISABLED")
	f.guard:SetScript("OnEvent", function()
		if Stop() then Again() end
	end)
	local function YourRow(i)
		local row = f.rows[i]
		if row then return row end
		row = CreateFrame("Frame", nil, f)
		row:SetSize(width, HOTVIEW.row)
		-- The row's own body, every other one banded. Its cells are far apart across a wide window, and
		-- without this the eye has nothing to carry it from the key to the choice at the far end: a plate
		-- halfway along reads as belonging to whichever row it sits nearest.
		row.band = row:CreateTexture(nil, "BACKGROUND")
		row.band:SetPoint("TOPLEFT", -8, 0)
		row.band:SetPoint("BOTTOMRIGHT", 8, 0)
		Theme.Paint(row.band, C.row, 0.5)
		row.band:Hide()
		-- The key, on its plate.
		row.key = CreateFrame("Button", nil, row)
		row.key:SetHeight(HOTVIEW.plate)
		row.key:SetPoint("TOPRIGHT", row, "TOPLEFT", HOTVIEW.lead - 12, -3)   -- (against the words, as a key's legend)
		UI.KeyPlate(row.key)
		row.keyText = UI.Text(row.key, "", 12, true, C.head)
		row.keyText:SetPoint("CENTER")
		-- The key the thing that moves goes to: click, then press one (lit while it listens). It stands in the
		-- second line, right after the words naming what it moves, rather than off in a column of its own.
		row.target = CreateFrame("Button", nil, row)
		row.target:SetSize(HOTVIEW.target, HOTVIEW.plate)
		row.target:RegisterForClicks("LeftButtonUp")
		UI.KeyPress(row.target, { fill = C.bg })
		row.targetText = UI.Text(row.target, "", 12, true, C.head)
		row.targetText:SetPoint("CENTER")
		-- What the picker moves, named right before its plate and pointing at it. (The same picker moves what
		-- the key did on one row and the ability on the next: against the plate it can't be taken for the
		-- other, and nothing of the name is lost to a column too narrow to hold it.)
		row.moved = UI.Text(row, "", 11, false, C.dim)
		row.moved:SetWordWrap(false)
		row.target:SetScript("OnEnter", function(self)
			if listening ~= row then
				UI.Tip(self, ("A key for %s"):format(row.moves or "it"),
					"Click, then press the key you want. Esc cancels; Backspace gives back the key we picked.")
			end
		end)
		row.target:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		row.target:SetScript("OnClick", function(self)
			UI.TipHide(self)
			if listening == row then
				Stop()
			elseif InCombatLockdown() then
				errs[row.entry.key] = "Your keys can be changed once the fight is over."
			else
				Stop()
				errs[row.entry.key] = nil
				listening, asked = row, row.entry
				Listen(row, true)
			end
			Again()
		end)
		-- (the middle and side mouse buttons are keys too; the left and right ones click)
		row.target:HookScript("OnMouseDown", function(_, button)
			local key = listening == row and HOT.mice[button]
			if key then Picked(row, Hot.Chord(key)) end
		end)
		row.heard = function(_, key)
			if HOT.metas[key] then return end
			if key == "ESCAPE" then
				Stop()
				Again()
			elseif key == "BACKSPACE" or key == "DELETE" then
				Picked(row, nil)
			else
				Picked(row, Hot.Chord(key))
			end
		end
		-- What becomes of this key: it changes for the layout, or it stays as you had it. (Two words answering
		-- the column they stand under; the head beside them says what each means for you.)
		row.choice = UI.Segmented(row, { "Changes", "Stays" }, function()
			return row.entry and row.entry.kept and 2 or 1
		end, function(i)
			Stop()
			local entry = row.entry
			if entry then
				errs[entry.key] = nil
				if not Hot.Keep(entry.key, i == 2, Noting()) then errs[entry.key] = "Your keys can be changed once the fight is over." end
			end
			Again()
		end, { width = HOTVIEW.choice, height = HOTVIEW.plate })
		row.choice:SetPoint("TOPRIGHT", 0, -3)   -- (under its column: the picker is on the line below now)
		-- What the key gives you now: the first cell of an ordinary row, and the loudest thing on it. (You are
		-- here to see what your keys do; what they did before is the column after it.)
		row.does = UI.Text(row, "", 13)
		row.does:SetJustifyH("LEFT")
		row.does:SetWordWrap(false)
		-- What it did, and what happens to it: the rows that need sentences rather than cells.
		row.head = UI.Text(row, "", 13)
		row.sub = UI.Text(row, "", 11, false, C.dim)
		for _, text in ipairs({ row.head, row.sub }) do
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)
		end
		row.does:SetPoint("TOPLEFT", HOTVIEW.lead, -4)
		row.head:SetPoint("TOPLEFT", HOTVIEW.lead, -3)
		row.sub:SetPoint("TOPLEFT", row.head, "BOTTOMLEFT", 0, -7)
		-- (every cell in a column of its own, so the list reads down the page as well as across it)
		row.target:SetPoint("TOPRIGHT", -(HOTVIEW.choice + HOTVIEW.apart), -3)
		row.moved:SetPoint("RIGHT", row.target, "LEFT", -10, 0)
		row.moved:SetJustifyH("RIGHT")
		-- Why a pick wouldn't go, or what to press while one is being made: under the cells, where there is
		-- room for a sentence without the columns having to hold one.
		row.aside = UI.Text(row, "", 11, false, C.dim)
		row.aside:SetPoint("TOPLEFT", row.does, "BOTTOMLEFT", 0, -4)
		row.aside:SetJustifyH("LEFT")
		row.aside:SetWordWrap(false)
		f.rows[i] = row
		return row
	end
	-- The jobs by key, for what a key becomes.
	local function ByKey()
		local mine, at = watched[1], {}
		if not mine then return at end
		for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
			if job.key then at[job.key] = job end
		end
		return at
	end
	-- How wide the column of names before the plates is, for the window this list was built for: enough for
	-- the long ones ("Item Comparison Cycling") where there is room, never so much that what the key does is
	-- left without any. The rest of the line is what the key does.
	f.movedW = math.max(HOTVIEW.movedLeast, math.min(HOTVIEW.movedMost, math.floor(width * 0.22)))
	-- The columns, named once over the first row rather than guessed at row by row: where what a key did goes,
	-- and what becomes of the key itself.
	f.cols = CreateFrame("Frame", nil, f)
	f.cols:SetHeight(HOTVIEW.cols)
	f.cols.goes = UI.Text(f.cols, "WHICH MOVES TO", 10, true, C.dim)
	f.cols.goes:SetWidth(HOTVIEW.target)
	f.cols.goes:SetJustifyH("CENTER")
	-- (the headings are the rest of the sentence each row is: "R does Strike, instead of Chat Reply, which
	-- moves to Ctrl + R")
	f.cols.does = UI.Text(f.cols, "DOES", 10, true, C.dim)
	f.cols.does:SetPoint("TOPLEFT", HOTVIEW.lead, 0)
	f.cols.off = UI.Text(f.cols, "INSTEAD OF", 10, true, C.dim)
	f.cols.off:SetWidth(f.movedW)
	f.cols.off:SetJustifyH("RIGHT")
	f.cols.whose = UI.Text(f.cols, "THIS KEY", 10, true, C.dim)
	f.cols.whose:SetWidth(HOTVIEW.choice)
	f.cols.whose:SetJustifyH("CENTER")
	f.cols.whose:SetPoint("TOPRIGHT")
	f.cols.goes:SetPoint("TOPRIGHT", f.cols.whose, "TOPLEFT", -HOTVIEW.apart, 0)
	f.cols.off:SetPoint("TOPRIGHT", f.cols.goes, "TOPLEFT", -10, 0)
	-- (the key plates hang off the words, right against them, so their column is named to the same edge)
	f.cols.key = UI.Text(f.cols, "KEY", 10, true, C.dim)
	f.cols.key:SetJustifyH("RIGHT")
	f.cols.key:SetPoint("TOPRIGHT", f.cols, "TOPLEFT", HOTVIEW.lead - 12, 0)
	-- The list comes in two parts, the keys you reach for most first. That was a colour on the words and
	-- nothing else: a hand could see two kinds of row and had nothing to tell it what the two were.
	f.bands = {}
	local function Band(i)
		local band = f.bands[i]
		if band then return band end
		band = UI.Text(f, "", 10, true, C.dim)
		band:SetJustifyH("LEFT")
		f.bands[i] = band
		return band
	end
	f.Band = Band
	-- The keys that turned the bar's pages, and the side keys that strafe now: lines under the rows, not a row each.
	f.paging = UI.Text(f, "", 11, false, C.dim)
	f.paging:SetWidth(width)
	f.paging:SetJustifyH("LEFT")
	f.paging:SetSpacing(4)
	-- "Show N more": the rest of the list, and back.
	f.more = Hot.More(f, width, function()
		f.expanded = not f.expanded
		Again()
	end)
	-- The bar that comes up once you have changed something: what waits, and the two words for it. It stands
	-- at the page's foot and goes again when nothing is waiting, so a page you only read never carries it.
	function f:Changed() return f.was ~= nil and Hot.Changed(f.was) end
	-- (saved or forgotten, the list holds nothing to put back until you pick again)
	function f:Save()
		if InCombatLockdown() then return false end
		Stop()
		Hot.Settle(f.was)
		f.was = nil
		Again()
		return true
	end
	function f:Discard()
		Stop()
		if f.was then Hot.Unpick(f.was) end
		f.was = nil
		errs = {}
		Again()
	end
	if not plan then
		-- The bar stands over the page, so it is a surface of its own and not a see-through strip: its own fill
		-- (opaque, whatever the theme does to the window behind it), a shade above it saying the list carries on
		-- under there, and the rule between the two.
		local bar = CreateFrame("Frame", nil, f)
		bar:SetHeight(HOTVIEW.saveTall)
		bar:SetPoint("LEFT")
		bar:SetPoint("RIGHT")
		bar.fill = bar:CreateTexture(nil, "BACKGROUND")
		bar.fill:SetPoint("TOPLEFT", 0, 0)
		bar.fill:SetPoint("BOTTOMRIGHT", 0, -HOTVIEW.saveUnder)   -- (down to the window's edge, under the buttons)
		Theme.Paint(bar.fill, C.bg, 1)
		bar.shade = bar:CreateTexture(nil, "BACKGROUND")
		bar.shade:SetHeight(HOTVIEW.saveShade)
		bar.shade:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 0)
		bar.shade:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
		bar.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.45))
		bar.rule = bar:CreateTexture(nil, "ARTWORK")
		bar.rule:SetHeight(1)
		bar.rule:SetPoint("TOPLEFT")
		bar.rule:SetPoint("TOPRIGHT")
		Theme.Paint(bar.rule, C.border, 0.8)
		bar.says = UI.Text(bar, "", 12, false, C.text)
		bar.says:SetJustifyH("LEFT")
		bar.save = UI.Button(bar, "Save", 104, function() f:Save() end)
		bar.discard = UI.Button(bar, "Discard", 96, function() f:Discard() end)
		bar.discard:SetPoint("RIGHT", bar.save, "LEFT", -8, 0)
		-- The bar spans the whole of its side of the window; what it holds stands in from that by the margins
		-- the rows keep, so the words and the buttons line up with the list the bar covers the foot of.
		function bar:Inset(left, right)
			self.inset = { left, right }
			self.says:ClearAllPoints()
			self.says:SetPoint("LEFT", left, -2)
			self.save:ClearAllPoints()
			self.save:SetPoint("RIGHT", -right, -2)
		end
		bar:Inset(0, 0)
		bar:Hide()
		f.bar = bar
	end
	-- What waits, counted as a player would say it: a key picked over twice is one change, and the three picks
	-- a key can carry (kept, taken back, its ability's key) are the one key between them.
	local function Waiting()
		if not f.was then return nil end
		local book, n = Hot.Choices(), 0
		local keys = {}
		for _, name in ipairs({ "keep", "standIn", "took", "homeAt" }) do
			local now, before = book[name] or EMPTY, f.was[name] or EMPTY
			local seen = name == "homeAt" and {} or keys
			for k, v in pairs(now) do
				if before[k] ~= v then seen[k] = true end
			end
			for k, v in pairs(before) do
				if now[k] ~= v then seen[k] = true end
			end
			if name == "homeAt" then
				for _ in pairs(seen) do n = n + 1 end
			end
		end
		for _ in pairs(keys) do n = n + 1 end
		if n == 0 then return nil end
		return ("%d %s waiting. Nothing of yours is bound until you save."):format(n, n == 1 and "change" or "changes")
	end
	f.Waiting = Waiting
	-- "Shift + 1 to 6" for a run of the number row, else each key.
	local function KeysSaid(keys)
		local shift, digits = true, {}
		for i, key in ipairs(keys) do
			local n = key:match("^SHIFT%-(%d)$")
			if not n then shift = false end
			digits[i] = tonumber(n)
		end
		if shift and #keys > 2 and digits[#digits] - digits[1] == #keys - 1 then
			return ("Shift + %d to %d"):format(digits[1], digits[#digits])
		end
		local said = {}
		for i, key in ipairs(keys) do said[i] = Keys.Key(key) end
		return Several(said, HOT.named)
	end
	-- An ordinary key's row, read straight across as one sentence: R does Strike, instead of Chat Reply, which
	-- moves to [a key]. The cells are the words; the columns over them are the rest of it.
	--   -> does (what the key gives you now), or nil where the row needs sentences instead
	-- A key you keep is the same shape: it does what it always did, and the ability it turned away is the
	-- thing that moves. So the third column is always what lost this key, and the fourth where that goes.
	local function RowDoes(entry, job, on)
		if entry.note or entry.wait or entry.steer or entry.move then return nil end
		if entry.kept then return BindingCalled(entry.from) end
		return job and job.name or "a free button"
	end
	-- A row's two lines, for the keys that need telling rather than tabling (a note, an ability still waiting,
	-- a side key that turned you, a key you move with): what the key did and what happens to it, then what the
	-- key itself does then and where the rest goes. on: the hotkeys are set (said as done).
	local function RowSays(entry, job, on)
		local key = Keys.Key(entry.key)
		if entry.note then return entry.note.head, entry.note.sub end
		if entry.wait then
			local does = GetBindingAction(entry.key)
			return ("%s waits for a key"):format(entry.wait.name),
				does ~= "" and ("%s stays %s."):format(key, BindingCalled(does)) or ("%s stays as it is."):format(key)
		end
		local name = BindingCalled(entry.from)
		-- (a side key that turned you: it strafes, and where turning goes; or it keeps turning, and where strafing goes)
		if entry.steer then
			local strafe = GetBindingName(entry.side)
			if entry.kept then
				-- (already there, as a strafe of yours elsewhere is: is on, not goes on)
				local there = entry.strafeAt and GetBindingAction(entry.strafeAt) == entry.side
				return ("%s stays on %s"):format(name, key), entry.strafeAt
					and ("%s %s %s."):format(strafe, (on or there) and "is on" or "goes on", Keys.Key(entry.strafeAt))
					or ("Pick a key for %s, or it has none."):format(strafe)
			end
			local sub
			if entry.home then
				sub = ("%s %s %s."):format(name, on and "is on" or "goes on", Keys.Key(entry.home))
			elseif entry.also then
				sub = ("%s is still on %s."):format(name, Keys.Key(entry.also))
			else
				sub = ("Pick a key for %s, or hold the right mouse button to turn."):format(name)
			end
			return ("%s %s %s"):format(strafe, on and "is on" or "goes on", key), sub
		end
		if entry.move then
			return ("%s %s %s"):format(GetBindingName(entry.to), on and "is on" or "goes on", key),
				("%s did %s. It's one of the keys you move with."):format(key, name)
		end
		if entry.kept then
			local sub
			if not job then
				sub = "Kept as you have it."
			elseif entry.standIn then
				sub = ("%s %s %s instead."):format(job.name, on and "is on" or "goes on", Keys.Key(entry.standIn))
			else
				sub = ("%s is left off until you pick a key for it."):format(job.name)
			end
			return ("%s stays on %s"):format(name, key), sub
		end
		local becomes = ("%s %s %s."):format(key, on and "is" or "becomes", job and job.name or "a free button")
		if entry.home then
			return ("%s %s %s"):format(name, on and "is on" or "moves to", Keys.Key(entry.home)), becomes
		end
		local still = entry.also and (" Still on %s."):format(Keys.Key(entry.also))
			or (on and " It has no key now: pick one." or " Pick a key for it, or it has none.")
		return ("%s %s %s"):format(name, on and "is no longer on" or "leaves", key), becomes .. still
	end
	-- The list in numbers, beside its caption: "8 move · 2 yours · 1 with no key".
	local function Tally(entries)
		local moved, kept, none = 0, 0, 0
		for _, entry in ipairs(entries) do
			if entry.note then
				-- (said in a row of its own, not counted)
			elseif entry.kept then
				kept = kept + 1
			elseif entry.home or entry.move then
				moved = moved + 1
			elseif not entry.also then
				none = none + 1
			end
		end
		local parts = {}
		if moved > 0 then parts[#parts + 1] = ("%d %s"):format(moved, moved == 1 and "moves" or "move") end
		if kept > 0 then parts[#parts + 1] = ("%d kept as yours"):format(kept) end
		if none > 0 then parts[#parts + 1] = ("%d with no key"):format(none) end
		return table.concat(parts, "  ·  ")
	end
	-- Whether the list holds a key of the other kind than this one, so there are two parts to name apart.
	local function AnyOther(rows, tail, must)
		for i = 1, tail - 1 do
			local entry = rows[i]
			if entry and not entry.note and (entry.must == true) ~= (must == true) then return true end
		end
		return false
	end
	-- Lays the list under `above`.  -> its height (0: no list)
	-- The list stands whole wherever it is the page: there is nothing under it to make room for, and a page
	-- that scrolls shouldn't ask to be unfolded first. ("changes" is the keys alone, in /shy and in setup.)
	local whole = part == "changes"
	local function Yours(above, shown)
		local mine = watched[1]
		local all = shown == "shy" and mine and Hot.Yours(mine.opts) or EMPTY
		-- (on your own hotkeys: the abilities that wait, their keys doing something else)
		if shown == "own" and f.says and f.says.waits then
			all = {}
			for i, job in ipairs(f.says.waits) do all[i] = { key = job.key, from = "", wait = job, at = i } end
		end
		-- (the keys that turned the bar's pages are said in a line; the side keys that turned you come after the
		-- list, always shown, side by side)
		local entries, paging, sides = {}, {}, {}
		for _, entry in ipairs(all) do
			if entry.paging and not entry.kept then
				paging[#paging + 1] = entry.key
			elseif entry.steer then
				sides[#sides + 1] = entry
			else
				entries[#entries + 1] = entry
			end
		end
		-- (what you'd miss first: what a hand relies on, then the rest, each under its own heading; within each,
		-- what moves or would have no key before what another key still does; each as a hand meets them)
		local function Rank(entry)
			local rank = (entry.must and 0 or 2) + 1
			return (entry.also and not entry.home) and rank + 1 or rank
		end
		table.sort(entries, function(a, b)
			local ra, rb = Rank(a), Rank(b)
			if ra ~= rb then return ra < rb end
			return a.at < b.at
		end)
		-- Where each key sits is settled the first time it is listed and kept from then on. What a key becomes
		-- changes as you work (it gains a home, it keeps yours), and that would rank it again: the list would
		-- reorder under the hand that is using it. A key new to the list takes its rank's place among the rest.
		if f.placedFor ~= shown then
			f.place, f.placed, f.placedFor = {}, 0, shown
		end
		for _, entry in ipairs(entries) do
			if not f.place[entry.key] then
				f.placed = f.placed + 1
				f.place[entry.key] = f.placed
			end
		end
		table.sort(entries, function(a, b) return f.place[a.key] < f.place[b.key] end)
		f.yours = entries
		-- The rows shown. On a page of its own there is nothing to make room for, so the list is whole;
		-- sharing a page, the first few, and the rest behind "Show N more" (one being picked, or that said
		-- why not, stays out where it is). After them, your side keys that turned you (strafe, or keep
		-- turning, and a key for the other), and the keys that turned the bar's pages: a row with nothing to pick.
		local visible = {}
		for i, entry in ipairs(entries) do
			-- (the key being picked, or one that said why not, stays in the list wherever it has reached)
			local held = (asked ~= nil and asked.key == entry.key) or errs[entry.key] ~= nil
			if whole or i <= HOTVIEW.rows or f.expanded or held then visible[#visible + 1] = entry end
		end
		local hidden = #entries - #visible
		local on = Hot.On()
		local notes = {}
		for _, entry in ipairs(sides) do notes[#notes + 1] = entry end
		if #paging > 0 then
			notes[#notes + 1] = { key = paging[1], note = { plate = (KeysSaid(paging):gsub(" %+ ", " "):gsub(" to ", "-")),
				head = on and "These no longer turn your bar's pages" or "These will no longer turn your bar's pages",
				sub = "They press your right side bar's buttons instead." } }
		end
		f.caption:SetShown(#entries + #notes > 0)
		f.tally:SetShown(#entries > 0)
		f.paging:Hide()
		f.more:Set((hidden > 0 and ("Show %d more"):format(hidden)) or (f.expanded and #entries > HOTVIEW.rows and "Show fewer") or nil)
		local rows = {}
		for _, entry in ipairs(visible) do rows[#rows + 1] = entry end
		local tail = #rows + 1       -- (the first row after the list: Show more stands above it)
		for _, entry in ipairs(notes) do rows[#rows + 1] = entry end
		for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
		for _, band in ipairs(f.bands) do band:Hide() end   -- (the ones drawn this time show themselves again)
		if #rows == 0 then
			f.more:Set(nil)
			return 0
		end
		if shown == "own" then
			f.caption:SetText("These wait for a key, because theirs does something else. Set it up for me gives each one its own.")
			f.tally:SetText(("%d %s"):format(#entries, #entries == 1 and "waits" or "wait"))
		else
			f.caption:SetText(on and "Switch any back, or click a key to pick where it went."
				or "Take the new key or keep yours. Click a key on the right to pick another.")
			f.tally:SetText(Tally(entries))
		end
		if part == "changes" then f.caption:SetText("") end   -- (its page's heading says it)
		f.caption:ClearAllPoints()
		f.caption:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -10)
		local jobs = ByKey()
		-- (the picker is on the second line now: the first has the row's width less the choice at its end)
		local textRight = width - HOTVIEW.lead - HOTVIEW.choice - HOTVIEW.apart
		-- Where the column of names before the plates ends: the plates stand in a column of their own, and the
		-- name of what each moves is right against the plate it points at.
		local movedRight = width - HOTVIEW.choice - HOTVIEW.apart - HOTVIEW.target - 10
		local y = -8
		local bands = 0           -- the headings drawn over the two parts of the list, counted to put the rest away
		local banded = {}         -- which kinds of key have had their heading already
		local striped = 0         -- the rows counted down the list, every other one given its band
		-- The columns, named once over the list rather than guessed at row by row.
		local named = false
		for _, entry in ipairs(rows) do
			if not ((entry.move and not entry.steer) or entry.note or entry.wait) then named = true end
		end
		f.cols:SetShown(named)
		if named then
			f.cols:ClearAllPoints()
			f.cols:SetWidth(width)
			f.cols:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y)
			y = y - HOTVIEW.cols
		end
		for i, entry in ipairs(rows) do
			-- (Show more stands between the list and the rows after it)
			if i == tail and i > 1 and f.more:IsShown() then
				f.more:ClearAllPoints()
				f.more:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y + 2)
				y = y - HOT.moreTall - 6
			end
			-- The heading over each part of the list, where it turns from the keys you reach for most to the
			-- rest. (Only where there is a second part to tell apart from the first.)
			-- (once for each kind, the first time it comes up: the rows keep the places they settled into, so
			-- a key you reach for can be listed after one you don't)
			if i < tail and not entry.note and not banded[entry.must == true] and AnyOther(rows, tail, entry.must) then
				banded[entry.must == true] = true
				bands = bands + 1
				local band = f.Band(bands)
				band:SetText(entry.must and "KEYS YOU REACH FOR MOST" or "THE REST OF THEM")
				band:ClearAllPoints()
				band:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y - (i > 1 and 10 or 0))
				band:Show()
				y = y - HOTVIEW.band - (i > 1 and 10 or 0)
			end
			local row = YourRow(i)
			row.entry = entry
			local job = not entry.note and jobs[entry.key] or nil
			local head, sub = RowSays(entry, job, on and not entry.pending)
			row.keyText:SetText(entry.note and entry.note.plate or Hot.Plate(entry.key))
			row.key:SetWidth(math.max(HOTVIEW.plate + 8, math.ceil(row.keyText:GetStringWidth()) + 14))
			row.head:SetText(head)
			-- (a key you move with, or a note, has no choice: a note's words run the row's width; a key you move
			-- with keeps room for the key what it did goes to; a side key that turned you has the choice)
			local fixed = (entry.move and not entry.steer) or entry.note
			local wide = entry.note and (width - HOTVIEW.lead) or textRight
			row.head:SetWidth(wide)
			-- (the keys you reach for most are told apart by the heading over them, not by a colour on the
			-- words that nothing explains; gold here is kept for what went wrong)
			Theme.Ink(row.head, C.text)
			-- (the key being picked, or what went wrong last, takes the second line)
			local err = errs[entry.key]
			local picking = asked ~= nil and not entry.note and asked.key == entry.key
			if picking then
				local what = entry.steer and (entry.kept and GetBindingName(entry.side) or BindingCalled(entry.from))
					or entry.kept and (job and job.name or "it") or BindingCalled(entry.from)
				sub = ("Press the key for %s. Esc cancels."):format(what)
			end
			-- The choice: none for a key you move with (but a side key that turned you), one that waits or a
			-- note; the key that moves: none for a key you keep with no ability.
			row.choice:SetShown(not fixed and not entry.wait)
			row.choice:Refresh()
			-- (the key that moves: what the key did, even where another key still does it or the key is one you
			-- move with, so every key we take can be given one of your own; or a kept key's ability; a side key
			-- that turned you: turning's key, or strafing's while it keeps turning)
			local target = entry.steer == true or (not entry.note and not entry.wait
				and (entry.kept and job ~= nil or not entry.kept)) or false
			row.target:SetShown(target)
			-- What the picker moves: the ability on a key you keep, else what the key did. It names the one
			-- thing on the line the picker stands in, so the two jobs the one control has are never confused.
			row.moves = nil
			if target then
				row.moves = entry.steer and (entry.kept and GetBindingName(entry.side) or BindingCalled(entry.from))
					or entry.kept and (job and job.name or nil)
					or (entry.from ~= nil and entry.from ~= "" and BindingCalled(entry.from) or nil)
			end
			-- An ordinary key is a line of cells; one that needs telling keeps its two lines of words.
			local does = RowDoes(entry, job, on and not entry.pending)
			row.does:SetShown(does ~= nil)
			row.head:SetShown(does == nil)
			row.sub:SetShown(does == nil)
			-- (what the row isn't saying this time says nothing at all: a hand reading the other shape's words
			-- would be reading whichever row drew them last)
			if does then row.head:SetText("") row.sub:SetText("") else row.does:SetText("") end
			if does then
				row.does:SetText(does)
				row.does:SetWidth(math.max(60, movedRight - HOTVIEW.lead - HOTVIEW.apart - f.movedW))
				Theme.Ink(row.does, C.text)
				row.moved:SetWidth(f.movedW)
			else
				row.sub:SetText(err or sub)
				Theme.Ink(row.sub, err and C.alert or picking and C.head or C.dim)
				row.sub:SetWidth(target and movedRight - HOTVIEW.lead or wide)
				row.moved:SetWidth(0)
			end
			row.moved:SetShown(target and row.moves ~= nil)
			if target then
				local at = entry.steer and (entry.kept and entry.strafeAt or entry.home)
					or entry.kept and entry.standIn or (not entry.kept and entry.home)
				row.moved:SetText(row.moves or "")
				row.targetText:SetText(picking and "Press a key" or (at and Hot.Plate(at)) or "Pick a key")
				Theme.Ink(row.targetText, (picking or not at) and C.good or C.head)
				row.target:SetOn(picking)
			end
			-- Under the cells, only while there is something to say: why a pick wouldn't go, what to press
			-- while one is being made, or the key that still does the thing this one no longer does.
			-- (nothing picked yet for what the key did, but another key still does it: said, so Pick a key reads
			-- as a choice, not a loss)
			local aside = err or (picking and sub)
				or (does and not entry.kept and not entry.home and entry.also
					and ("%s is still on %s."):format(BindingCalled(entry.from), Keys.Key(entry.also)))
				or (does and not target and not entry.kept and "It has no key now.") or nil
			row.aside:SetShown(does ~= nil and aside ~= nil)
			if not (does and aside) then row.aside:SetText("") end
			if does and aside then
				row.aside:SetText(aside)
				row.aside:SetWidth(movedRight - HOTVIEW.lead)
				Theme.Ink(row.aside, err and C.alert or picking and C.head or C.dim)
			end
			local tall = does and (HOTVIEW.cell + (aside and HOTVIEW.asideTall or 0)) or HOTVIEW.row
			row:SetSize(width, tall)
			-- (banded by where it stands in the list, not by what kind of key it is: the band is for the eye
			-- to follow across, and says nothing of its own)
			striped = striped + 1
			row.band:SetShown(i < tail and striped % 2 == 0)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y)
			row:Show()
			y = y - tall
		end
		-- The keyboard follows the key being picked onto whichever row draws it now, so the key you press is
		-- the one you asked for. Its key gone from the list, the pick goes with it rather than onto another.
		if asked then
			local now
			for _, row in ipairs(f.rows) do
				if row:IsShown() and row.entry and not row.entry.note and row.entry.key == asked.key then now = row end
			end
			if not now then
				Stop()
			elseif now ~= listening then
				Listen(listening, false)
				listening = now
				Listen(now, true)
			end
		end
		-- (nothing after the list: Show more under it)
		if f.more:IsShown() and tail > #rows then
			f.more:ClearAllPoints()
			f.more:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y + 2)
			y = y - HOT.moreTall - 6
		end
		local tall = 10 + math.ceil(f.caption:GetStringHeight()) - y + 4
		return tall
	end

	function f:Refresh()
		local lit, state = Lit(), self:State()
		-- The keys are drawn for the choice under the mouse, else the one lit: the board for the set-up, your
		-- own keys for the other two.
		local shown = self.looking or lit
		self.shown = shown
		Keys.Pretend(shown == "shy" and "shy" or "own")
		-- What you had before is said as safe while anything of it is changed.
		local changed = state ~= "off"
		tiles.off.tag:SetText(changed and "Kept safe" or HOTVIEW.picks.off.tag)
		Theme.Ink(tiles.off.tag, changed and C.good or C.dim)
		for name, tile in pairs(tiles) do
			local used = name == state
			-- (painted again only when it changes: the lit card stays as it is while another is pointed at)
			if tile.shyButton.on ~= (name == lit) then tile:SetOn(name == lit) end
			tile.tick:SetShown(used)
			tile.use:SetShown(used)
		end
		local says = Hot.Says(shown, plan)   -- (said of the choice the keys are drawn for)
		self.says = says
		self.step2.title:SetText(shown == "shy" and "What changes for you" or shown == "own" and "What stays, and what waits"
			or (changed and "Everything goes back" or "Nothing changes"))
		self.safe:SetText(says.safe)
		self.tally:SetText("")
		-- (the choices alone: what the lit one means, and anything that stands in its way)
		if part == "choose" then
			self.chosen:SetText(says.safe)
			local warn = says.block or says.warn
			self.warn:ClearAllPoints()
			self.warn:SetPoint("TOPLEFT", self.chosen, "BOTTOMLEFT", 0, -8)
			self.warn:SetText(warn or "")
			for _, piece in ipairs({ self.notes, self.caption, self.paging, self.more }) do piece:Hide() end
			for _, row in ipairs(self.rows) do row:Hide() end
			self:SetSize(width, HOTVIEW.choose + 16 + math.ceil(self.chosen:GetStringHeight())
				+ (warn and 8 + math.ceil(self.warn:GetStringHeight()) or 0))
			return
		end
		self.notes:SetText(table.concat(says.notes, "\n"))
		says.warn = says.block or says.warn
		self.warn:SetText(says.warn or "")
		local tall = part == "changes" and math.ceil(self.safe:GetStringHeight()) or HOTVIEW.tall + 20 + self.step2:Fit()
		if #says.notes > 0 then tall = tall + 6 + math.ceil(self.notes:GetStringHeight()) end
		self.warn:ClearAllPoints()
		local last = #says.notes > 0 and self.notes or self.safe
		self.warn:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
		if says.warn then
			tall = tall + 6 + math.ceil(self.warn:GetStringHeight())
			last = self.warn
		end
		tall = tall + Yours(last, shown)
		-- The bar, while something waits to be saved. Where a window can hold it at its own foot (the /shy
		-- window: self.foot) it stays there however far the list is scrolled; otherwise it stands under the
		-- list, as the last thing on the page.
		if self.bar then
			local waiting = Waiting()
			self.bar.says:SetText(waiting or "")
			if self.foot then
				self.foot(waiting ~= nil and self.bar or nil)
			else
				self.bar:SetShown(waiting ~= nil)
				if waiting then
					self.bar:ClearAllPoints()
					self.bar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(tall + 14))
					self.bar:SetPoint("RIGHT")
					tall = tall + 14 + HOTVIEW.saveTall
				end
			end
		end
		self:SetSize(width, tall)
	end
	-- The page starts from where your keys stand: nothing waiting, nothing to put back until you pick.
	function f:Fresh()
		f.was = nil
		errs = {}
	end
	f:SetScript("OnShow", function(self)
		self:Fresh()
		self:Refresh()
	end)
	f:SetScript("OnHide", function(self)
		self.looking = nil   -- (the choice clicked stays looked at as you go between the room's parts)
		self.Stop()                -- (a key half picked: the keyboard goes back to the game)
		-- Anything picked here and not saved goes with the page: nothing of yours was bound for it, and
		-- leaving it noted would have the list draw a change you never see again. (Only ever picks made on
		-- this list: with nothing picked, self.was is nil and there is nothing of anyone's to put back.)
		if self.was then
			if Hot.Changed(self.was) then Hot.Unpick(self.was) end
			self.was = nil
		end
		Keys.Pretend(nil)
	end)
	f:Refresh()
	return f
end
-- How you move, picked: WASD or ASDF side by side, and a word when the game still moves you with other keys.
-- f:Refresh() shows the pick.
function Keys.Movement(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local half = math.floor((width - MINI.apart) / 2)
	local choices = {}
	local function Pick(scheme)
		if not Keys.SetScheme(scheme) then Shy.core:Print("you can switch how you move once the fight is over.") end
		f:Refresh()
	end
	choices.wasd = Choice(f, half, "wasd", "W forward, S back. The game's own.", Pick)
	choices.asdf = Choice(f, half, "asdf", "S forward, F back. Your hand rests a key to the right.", Pick)
	choices.wasd:SetPoint("TOPLEFT")
	choices.asdf:SetPoint("LEFT", choices.wasd, "RIGHT", MINI.apart, 0)
	f.note = UI.Text(f, "", 12, false, C.alert)
	f.note:SetPoint("TOPLEFT", choices.wasd, "BOTTOMLEFT", 0, -10)
	f.note:SetWidth(width)
	f.note:SetJustifyH("LEFT")
	function f:Refresh()
		if Drawn(self) then return end
		local now = Keys.Scheme()
		for scheme, b in pairs(choices) do b:SetOn(scheme == now) end
		-- (picked, but the game still moves you with other keys: say so)
		local forward = Scheme().forward
		local moves = false
		for _, key in ipairs({ GetBindingKey("MOVEFORWARD") }) do
			if key == forward then moves = true end
		end
		self.note:SetText(moves and "" or (Keys.Mode() == "shy" and "Your %s doesn't move you forward yet. Setting up your keys takes care of it."
			or "Your %s doesn't move you forward yet. Bind it in the game's key bindings."):format(forward))
		self:SetSize(width, MINI.tall + (moves and 0 or 26))
	end
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Refresh() end
	end)
	f:SetScript("OnShow", f.Refresh)
	f:Refresh()
	return f
end

-- What the files after this one use.
ns.HOTVIEW, ns.MiniBoard = HOTVIEW, MiniBoard
