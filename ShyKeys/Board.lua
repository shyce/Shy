-- ShyKeys: The controls: your keys drawn as the hand finds them, at any level
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local BindingCalled, Button, EMPTY, FORM_KEYS = ns.BindingCalled, ns.Button, ns.EMPTY, ns.FORM_KEYS
local Follow, HOT, Hot, ICON = ns.Follow, ns.HOT, ns.Hot, ns.ICON
local Mine, Pick, Scheme, Slots = ns.Mine, ns.Pick, ns.Scheme, ns.Slots
local Turn, waiting = ns.Turn, ns.waiting

---------------------------------------------------------------------------
-- The controls: your keys drawn as the hand finds them, at any level
---------------------------------------------------------------------------

-- Whether a piece already showed this very state this frame (a window shows it, the room refreshes it, the
-- window refreshes its page: one frame, one drawing). Anything that changes what it shows (keys laid out or put
-- back, how you move, the level) makes the next call draw again.
local function Drawn(piece, ...)
	local stamp = table.concat({ tostring(GetTime()), Keys.gen, Keys.look, Keys.Scheme(), tostring((...)) }, "|")
	if piece.drawn == stamp then return true end
	piece.drawn = stamp
end

local C = UI.colors
local Theme = Shy.Theme
local CAPROW = 24               -- a button's height
local GAP = 8

-- Two hands on a keyboard: the plain keys on the left, the same keys with Shift on the right, each the board
-- as a hand meets it (the rows stepped in as a keyboard's are, in caps) with the mouse's side keys past it.
local BOARD = {
	{ x = 0, keys = { "1", "2", "3", "4", "5" } },
	{ x = 0.5, keys = { "Q", "W", "E", "R", "T" } },
	{ x = 0.75, keys = { "A", "S", "D", "F", "G" } },
	{ x = 1.25, keys = { "Z", "X", "C", "V", "B" } },
}
local MOUSE = { { key = "BUTTON4", row = 2 }, { key = "BUTTON5", row = 3 } }
local VIEW = {
	span = 7.5,              -- a hand's width, in caps: the board's widest row and the mouse's keys past it
	mouse = 6.5,             -- where the mouse's keys stand, in caps from the hand's left
	apart = 28,              -- between the hands
	inner = 3,               -- between two caps
	tall = 1.24,             -- a cap's height to its width
	most = 54,               -- the widest a cap's step grows, however wide the room flows
	label = 10,              -- the key's letter on its cap
	name = 9,                -- the macro's name along its foot
	caption = 18,            -- the words over each hand
	turns = 3,               -- what changes at a level: rows a column
	turnRow = 32,
	ruler = 38,              -- the level's slider
	arrow = 24,              -- the buttons either side of it
	notch = { 2, 5 },        -- a mark under the slider where something changes
	mark = 5,                -- a cap's corner mark: a key of yours that changes
}

-- A key as its cap says it: "Q", "4", "M4".
local function Cap(key)
	return (key:gsub("^SHIFT%-", ""):gsub("^BUTTON(%d)", "M%1"))
end

-- One cap: the family's keyed plate, the key's letter at its corner, the ability in a slot, the macro's name
-- along its foot.
local function NewCap(parent, size, high)
	local cap = CreateFrame("Button", nil, parent)
	cap:SetSize(size, high)
	UI.KeyPlate(cap)
	cap:EnableMouse(true)
	cap.letter = UI.Text(cap, "", VIEW.label, true, C.dim)
	cap.letter:SetPoint("TOPLEFT", 4, -3)
	local slot = Shy.Slot.SIZES[size >= 40 and "compact" or "small"]
	cap.well = CreateFrame("Frame", nil, cap)
	cap.well:SetSize(slot, slot)
	cap.well:SetPoint("TOP", 0, -(VIEW.label + 3))
	cap.icon = cap.well:CreateTexture(nil, "ARTWORK")
	cap.icon:SetAllPoints()
	cap.slot = Shy.Slot.New(cap.well, { icon = cap.icon, size = slot, hover = false })
	cap.soon = UI.Text(cap.well, "", 12, true, C.dim)
	cap.soon:SetPoint("CENTER")
	cap.name = UI.Text(cap, "", VIEW.name)
	cap.name:SetPoint("BOTTOM", 0, 3)
	cap.name:SetWidth(size - 4)
	cap.name:SetJustifyH("CENTER")
	cap.name:SetWordWrap(false)
	return cap
end

-- A step of the keys' page: its number on a key's plate, what it is, and under it one sentence that guides; at
-- the right, beside the title, a few words (how many keys change).
--   Hot.StepHead(parent, n, width) -> f: f.title, f.say, f.side; f:Fit() sizes it to what it says (-> its height)
function Hot.StepHead(parent, n, width)
	local f = CreateFrame("Frame", nil, parent)
	f.plate = CreateFrame("Button", nil, f)
	f.plate:SetSize(HOT.step, HOT.step)
	f.plate:SetPoint("TOPLEFT")
	UI.KeyPlate(f.plate)
	f.number = UI.Text(f.plate, tostring(n), 12, true, C.head)
	f.number:SetPoint("CENTER")
	f.title = UI.Text(f, "", 15, true, C.head)
	f.title:SetPoint("LEFT", f.plate, "RIGHT", HOT.stepGap, 0)
	f.side = UI.Text(f, "", 11, true, C.dim)
	f.side:SetPoint("RIGHT", f, "TOPRIGHT", 0, -HOT.step / 2)
	f.side:SetJustifyH("RIGHT")
	f.say = UI.Text(f, "", 12, false, C.dim)
	f.say:SetPoint("TOPLEFT", f.plate, "BOTTOMRIGHT", HOT.stepGap, -5)
	f.say:SetWidth(width - HOT.step - HOT.stepGap)
	f.say:SetJustifyH("LEFT")
	f.say:SetWordWrap(true)
	function f:Fit()
		local said = (self.say:GetText() or "") ~= ""
		self:SetSize(width, HOT.step + (said and (5 + math.ceil(self.say:GetStringHeight())) or 0))
		return self:GetHeight()
	end
	f:Fit()
	return f
end

-- More of a list, a click away: its words in the middle of a line between two hairlines, lit under the mouse.
--   Hot.More(parent, width, onClick) -> b: b:Set(words) (nil or "": hidden); b.text
HOT.moreTall = 24
function Hot.More(parent, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOT.moreTall)
	b.text = UI.Text(b, "", 11, true, C.good)
	b.text:SetPoint("CENTER")
	b.left = b:CreateTexture(nil, "ARTWORK")
	b.right = b:CreateTexture(nil, "ARTWORK")
	for _, rule in ipairs({ b.left, b.right }) do
		Theme.Paint(rule, C.border, 0.8)
		rule:SetHeight(1)
	end
	b.left:SetPoint("LEFT")
	b.left:SetPoint("RIGHT", b.text, "LEFT", -12, 0)
	b.right:SetPoint("LEFT", b.text, "RIGHT", 12, 0)
	b.right:SetPoint("RIGHT")
	b:SetScript("OnClick", function() onClick() end)
	b:SetScript("OnEnter", function(self)
		Theme.Ink(self.text, C.head)
		for _, rule in ipairs({ self.left, self.right }) do Theme.Paint(rule, C.good, 0.6) end
	end)
	b:SetScript("OnLeave", function(self)
		Theme.Ink(self.text, C.good)
		for _, rule in ipairs({ self.left, self.right }) do Theme.Paint(rule, C.border, 0.8) end
	end)
	function b:Set(words)
		self.text:SetText(words or "")
		if words ~= nil and words ~= "" then self:Show() else self:Hide() end
	end
	b:Set(nil)
	return b
end

-- The keys' controls for this character's class: how things stand, lay them out, put yours back, follow the
-- build; and the keys themselves on two hands at the level the slider picks (yours to start with), what each
-- does then, what comes at that level, and how each key grows on its hover. f:Refresh() says how things stand.
-- With a plan (setup's page) the hotkeys' choice is a pick for Finish (plan.keys.pick: "shy", "own" or "off"),
-- and the two buttons and the build's switch stay in the /shy window.
-- part: one part alone, a page of setup's walk through your keys: "choose" (the three choices and what the lit one
-- means), "changes" (what it changes, key by key) or "board" (your keys on two hands, at any level).
function Keys.Panel(parent, width, plan, part)
	local f = CreateFrame("Frame", nil, parent)
	local view = { level = nil }   -- the story, worked out as the panel shows; the level shown
	-- Three steps, one under the other: choose, what that changes, your keys. Each says what to do there.
	f.step1 = Hot.StepHead(f, 1, width)
	f.step1:SetPoint("TOPLEFT")
	f.step1.title:SetText("Choose how your keys work")
	f.status = f.step1.say
	local function Do(act)
		return function()
			local mine = Keys.Mine()
			if mine then act(mine) end
			f:Refresh()
		end
	end
	-- The choice: set up for you, on your own hotkeys, or everything as it was before; what of yours each changes.
	f.hot = Hot.Panel(f, width, plan, function()
		f:Refresh()
		if f.resized then f.resized() end
	end, part)
	f.hot:SetPoint("TOPLEFT", f.step1, "BOTTOMLEFT", 0, -12)
	f.part = part
	-- One button makes the choice looked at (it says which); beside it, that until then nothing is changed.
	local third = math.floor((width - 2 * GAP) / 3)
	f.lay = UI.Button(f, "", third, function()
		f.hot:Use()
		f:Refresh()
		if f.resized then f.resized() end
	end)
	f.lay:SetPoint("TOPLEFT", f.hot, "BOTTOMLEFT", 0, -12)
	f.hint = UI.Text(f, "", 11, false, C.dim)
	f.hint:SetPoint("LEFT", f.lay, "RIGHT", GAP + 4, 0)
	f.hint:SetWidth(third - 4)
	f.hint:SetJustifyH("LEFT")
	-- Following your talents, a line of its own under the button, saying what it does (not a part of setting up).
	f.follow = UI.Checkbox(f, "Follow my talents", function()
		local mine = Keys.Mine()
		return mine ~= nil and mine.addon.db.keysFollow == true
	end, function(on)
		local mine = Keys.Mine()
		if not mine then return end
		mine.addon.db.keysFollow = on
		if on then Turn() end
		f:Refresh()
	end)
	f.follow:SetPoint("TOPLEFT", f.lay, "BOTTOMLEFT", 0, -HOT.followGap)
	f.followSay = UI.Text(f, "When you switch to another talent build, your keys are laid out for it.", 11, false, C.dim)
	f.followSay:SetPoint("LEFT", f.follow, "RIGHT", 12, 0)
	-- An earlier layout's keys: one press draws your bars as they are now, another the new layout again.
	f.flip = UI.Button(f, "", third - GAP, function()
		view.now = not view.now
		f.drawn = nil
		f:Refresh()
	end)
	f.flip:SetPoint("LEFT", f.lay, "RIGHT", GAP, 0)
	f.flip:Hide()
	for _, piece in ipairs({ f.lay, f.hint, f.follow, f.followSay }) do piece:SetShown(plan == nil) end
	-- The two hands.
	local unit = math.min(VIEW.most, math.floor((width - VIEW.apart) / (2 * VIEW.span)))
	local size = unit - VIEW.inner
	local high = math.floor(size * VIEW.tall)
	local hands = (VIEW.span * unit) * 2 + VIEW.apart
	f.step3 = Hot.StepHead(f, 3, width)
	f.step3:SetPoint("TOPLEFT", plan and f.hot or f.follow, "BOTTOMLEFT", 0, -24)
	local board = CreateFrame("Frame", nil, f)
	board:SetSize(hands, VIEW.caption + #BOARD * (high + VIEW.inner))
	board:SetPoint("TOP", f.step3, "BOTTOM", 0, -10)
	-- One part alone: the steps' heads and the buttons go (the page's own heading says what it is).
	if part then
		f.step1:Hide()
		f.step3:Hide()
		-- (the button stays under the choices in the /shy window: nothing changes until it is pressed)
		if plan or part ~= "choose" then
			for _, piece in ipairs({ f.lay, f.hint, f.follow, f.followSay }) do piece:Hide() end
		end
		f.hot:ClearAllPoints()
		f.hot:SetPoint("TOPLEFT")
		if part == "board" then
			f.hot:Hide()   -- (it still says which keys the board is drawn for)
			board:SetPoint("TOP", f, "TOP", 0, 0)
		else
			board:Hide()
		end
	end
	board:SetPoint("LEFT", f, "LEFT", math.floor((width - hands) / 2), 0)
	-- Whose hotkeys the keys are drawn for, and whether those are the ones bound now.
	f.whose = UI.Text(board, "", 11, true, C.head)
	f.whose:SetPoint("TOPRIGHT")
	f.caps = {}
	for side, shift in ipairs({ "", "SHIFT-" }) do
		local left = (side - 1) * (VIEW.span * unit + VIEW.apart)
		local caption = UI.Text(board, side == 1 and "Keys" or "With Shift", 11, true, C.dim)
		caption:SetPoint("TOPLEFT", left, 0)
		local function Place(key, x, row)
			local cap = NewCap(board, size, high)
			cap:SetPoint("TOPLEFT", left + math.floor(x * unit), -(VIEW.caption + (row - 1) * (high + VIEW.inner)))
			cap.key = shift .. key
			cap.letter:SetText(Cap(key))
			-- (a key of yours that does something now and gets a button of its own: marked, said on its hover)
			cap.mark = cap:CreateTexture(nil, "OVERLAY")
			cap.mark:SetSize(VIEW.mark, VIEW.mark)
			cap.mark:SetPoint("TOPRIGHT", -4, -5)
			cap.mark:SetColorTexture(1, 1, 1, 1)
			Theme.Tint(cap.mark, C.alert, 1)
			cap.mark:Hide()
			f.caps[#f.caps + 1] = cap
			return cap
		end
		for row, line in ipairs(BOARD) do
			for i, key in ipairs(line.keys) do Place(key, line.x + i - 1, row) end
		end
		for _, m in ipairs(MOUSE) do Place(m.key, VIEW.mouse, m.row) end
	end

	-- The level: a slider from 1 to the top, a notch where anything changes, a step to the change before and after.
	local top = GetMaxLevelForPlayerExpansion()
	local function Mine() return math.max(1, math.min(top, UnitLevel("player"))) end
	local function Step(by)
		return function()
			local at = view.level or Mine()
			for level = at + by, by > 0 and top or 1, by do
				if view.changes and (#view.changes[level] > 0 or (view.plays and view.plays[level])) then
					f:At(level)
					return
				end
			end
		end
	end
	f.before = UI.GlyphButton(f, Shy.Skin.GLYPH.caret, VIEW.arrow, Step(-1))
	f.before.glyph:SetRotation(-math.pi / 2)
	f.after = UI.GlyphButton(f, Shy.Skin.GLYPH.caret, VIEW.arrow, Step(1))
	f.after.glyph:SetRotation(math.pi / 2)
	local reach = width - 2 * (VIEW.arrow + GAP)
	f.level = UI.Slider(f, "At level", 1, top, 1, function() return view.level or Mine() end, function(v)
		f:At(v)
	end, { width = reach, format = function(v)
		return v == Mine() and ("%d, yours"):format(v) or tostring(v)
	end })
	f.level:SetPoint("TOPLEFT", board, "BOTTOMLEFT", VIEW.arrow + GAP - math.floor((width - hands) / 2), -14)
	f.before:SetPoint("BOTTOMRIGHT", f.level, "BOTTOMLEFT", -GAP, -4)
	f.after:SetPoint("BOTTOMLEFT", f.level, "BOTTOMRIGHT", GAP, -4)
	f.notches = {}

	-- What changes at the level shown (or, when nothing does, at the next level that changes).
	-- (a caption with a hairline to the right, as the window's captions are)
	f.turnsHead = UI.Text(f, "", 11, true, C.dim)
	f.turnsHead:SetPoint("TOPLEFT", f.level, "BOTTOMLEFT", -(VIEW.arrow + GAP), -14)
	f.turnsRule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(f.turnsRule, C.border, 0.7)
	f.turnsRule:SetHeight(1)
	f.turnsRule:SetPoint("LEFT", f.turnsHead, "RIGHT", 10, 0)
	f.turnsRule:SetPoint("RIGHT", f, "RIGHT")
	f.turns = {}
	local column = math.floor((width - GAP) / 2)
	-- A row: the key on its plate (as wide as its words), the ability's picture, its name, what is new under it.
	local plateW = 54
	function f:Turn(i)
		local row = self.turns[i]
		if row then return row end
		row = CreateFrame("Frame", nil, self)
		row:SetSize(column, VIEW.turnRow)
		row.plate = CreateFrame("Button", nil, row)
		row.plate:SetHeight(20)
		row.plate:SetPoint("RIGHT", row, "LEFT", plateW, 0)
		UI.KeyPlate(row.plate)
		row.key = UI.Text(row.plate, "", 11, true, C.head)
		row.key:SetPoint("CENTER")
		row.well = CreateFrame("Frame", nil, row)
		row.well:SetSize(Shy.Slot.SIZES.small, Shy.Slot.SIZES.small)
		row.well:SetPoint("LEFT", plateW + 8, 0)
		row.icon = row.well:CreateTexture(nil, "ARTWORK")
		row.icon:SetAllPoints()
		row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = Shy.Slot.SIZES.small, hover = false })
		row.title = UI.Text(row, "", 13)
		row.title:SetPoint("TOPLEFT", row.well, "TOPRIGHT", 8, 1)
		row.sub = UI.Text(row, "", 11, false, C.dim)
		row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
		for _, text in ipairs({ row.title, row.sub }) do
			text:SetWidth(column - plateW - 8 - Shy.Slot.SIZES.small - 8)
			text:SetWordWrap(false)
		end
		self.turns[i] = row
		return row
	end
	for i = 1, VIEW.turns * 2 do f:Turn(i) end
	f.more = Hot.More(f, width, function()
		view.allTurns = not view.allTurns
		if f.Turns then f.Turns(view.level) end
		if f.resized then f.resized() end
	end)
	-- (as tall as the hotkeys' piece and the rows of what changes at the level shown: Turns sets it)
	local function Above()
		local top = part == "board" and 0 or (f.step1:GetHeight() + 12 + f.hot:GetHeight() + (plan and 0 or HOT.buttons) + 24 + f.step3:GetHeight() + 10)
		return top + board:GetHeight() + 14 + VIEW.ruler + 14 + 16 + 6
	end
	f:SetSize(width, Above() + VIEW.turns * VIEW.turnRow + 16)

	-- A key's hover: what its macro is for, and every ability it casts as you level; a key of yours that
	-- changes, what it does now.
	local function Changing(cap, sections)
		local change = cap.change
		if change and change.from ~= "" then
			sections[#sections + 1] = { rows = { { text = ("Right now this key is %s. Your new keys take it over. Put your keys back to undo that."):format(
				BindingCalled(change.from)), color = C.alert } } }
		end
		return sections
	end
	local function Hover(cap)
		local job = cap.job
		if not job and cap.stance then
			local rows = { { text = "1, 2 and 3: " .. cap.stance }, { text = "They sit on the small bar under your character, each with its key in its corner.", color = C.dim } }
			if cap.keep then rows[#rows + 1] = { text = ("Your build's %s: keep it on."):format(cap.keep), color = C.good } end
			Shy.Hover.Show(cap, { title = "Stance bar", note = Keys.Key(cap.key), sections = Changing(cap, { { rows = rows } }) }, { side = "TOP" })
			return
		end
		if not job and cap.extra then
			Shy.Hover.Show(cap, { title = "Extra button", note = Keys.Key(cap.key),
				sections = Changing(cap, { { rows = { { text = ("A free button for you, on the %s flyout."):format(cap.side) } } } }) },
				{ side = "TOP" })
			return
		end
		if not job then return end
		local rows = {}
		for _, step in ipairs(view.story[job] or {}) do
			rows[#rows + 1] = { icon = step.icon, text = step.name or job.what,
				right = (step.talent and "Talent, level %d" or "Level %d"):format(step.level),
				rightColor = C.dim, done = step.level <= view.level }
		end
		local sections = { { rows = { { text = job.what } } } }
		if #rows > 1 or (rows[1] and rows[1].text ~= job.what) then sections[2] = { title = "As you level", rows = rows } end
		if cap.waits then   -- (another stands in here: say whose key it is, waiting at your trainer)
			sections[#sections + 1] = { rows = { { text = ("%s comes here once you learn it at your trainer."):format(cap.home.name),
				color = C.alert } } }
		end
		if cap.busy then
			sections[#sections + 1] = { rows = { { text = ("Your %s does %s now. Have your hotkeys set up, or bind it to an action button, and %s goes there."):format(
				Keys.Key(job.key), cap.busy, job.name), color = C.alert } } }
		end
		Shy.Hover.Show(cap, { title = job.name, note = Keys.Key(cap.key), sections = Changing(cap, sections) }, { side = "TOP" })
	end
	for _, cap in ipairs(f.caps) do
		cap:SetScript("OnEnter", Hover)
		cap:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	end

	-- Every cap at a level: the job standing on its key then, else the one whose key it is (dim: where it
	-- stands meanwhile, or the level it comes at), else nothing of ours.
	local function Paint(level)
		local mine = Keys.Mine()
		local keep = mine and Keys.Keep(mine.opts, level)   -- (the aura, stance or form your build stays in then)
		local at = view.levels and view.levels[level] or {}
		local on, home, fresh = {}, {}, {}
		for job, info in pairs(at) do
			if info.key then on[info.key] = job end
		end
		for _, job in ipairs(view.jobs or {}) do
			if job.key then home[job.key] = job end
		end
		for _, turn in ipairs(view.changes and view.changes[level] or {}) do
			if turn.key then fresh[turn.key] = true end
		end
		for _, cap in ipairs(f.caps) do
			local job = on[cap.key]
			local own = home[cap.key]
			if view.bare then job, own = nil, nil end   -- (as it was before: no ability of ours on any key)
			cap.job = job or own
			cap.home = own
			cap.waits = own and job and own ~= job and level == math.max(1, math.min(top, UnitLevel("player"))) and Keys.CouldTrain(own) or nil
			cap.busy = own and Keys.Busy(own, mine and mine.opts) or nil
			cap.soon:SetText("")
			cap.change = view.changing and view.changing[cap.key] or nil
			cap.mark:SetShown(cap.change ~= nil and cap.change.from ~= "")
			cap.extra, cap.keep = nil, nil
			if job then
				local info = at[job]
				-- (its key does something else in the hotkeys drawn: the ability faint, and what the key does)
				local other = cap.busy and cap.busy ~= "nothing"
				cap.icon:SetTexture(info.icon or ICON)
				cap.icon:SetAlpha(other and 0.35 or 1)
				cap.slot:Empty(false)
				cap.slot:Fresh(fresh[cap.key] == true)
				cap.name:SetText(other and cap.busy or job.name)
				Theme.Ink(cap.name, cap.busy and C.alert or C.text)
				-- (the one your build stays in, on its key of 1 2 3: its name in green)
				if job.spell and keep and info.name == keep.name then
					cap.keep = keep.word
					if not cap.busy then Theme.Ink(cap.name, C.good) end
				end
				cap:SetAlpha(1)
			elseif own then
				local first = view.story[own] and view.story[own][1]
				local now = at[own]
				cap.icon:SetTexture(nil)
				cap.slot:Empty(true)
				cap.slot:Fresh(false)
				if now then   -- standing on another key meanwhile: its picture faint, and where it is
					cap.icon:SetTexture(now.icon or ICON)
					cap.icon:SetAlpha(0.35)
					cap.name:SetText(now.key and ("on " .. (now.key:find("^SHIFT%-") and "Shift " or "") .. Cap(now.key)) or own.name)
				else
					cap.soon:SetText(first and first.level > level and tostring(first.level) or "")
					cap.name:SetText(own.name)
				end
				-- (a key that does something else, in the hotkeys drawn: what it does, so yours read as yours)
				if cap.busy and cap.busy ~= "nothing" and not now then
					cap.soon:SetText("")
					cap.name:SetText(cap.busy)
				end
				-- (at your level, its ability waits at your trainer: said in gold)
				if level == math.max(1, math.min(top, UnitLevel("player"))) and Keys.CouldTrain(own) and not now then
					cap.name:SetText("Train")
					Theme.Ink(cap.name, C.alert)
				end
				Theme.Ink(cap.name, C.dim)
				cap:SetAlpha(1)
			else
				-- 1 2 3 for a class with a stance bar: what you stay in, as the game's bar has it.
				-- (where the key presses the stance bar in the keys drawn; or nothing yet, and a layout gives it that)
				local pressed = mine and tonumber(cap.key) and tonumber(cap.key) <= FORM_KEYS and Keys.Doing(cap.key)
				local stance = pressed and tonumber(pressed:match("^SHAPESHIFTBUTTON(%d+)$"))
				local icon, _, _, spell
				if stance then icon, _, _, spell = GetShapeshiftFormInfo(stance) end
				cap.stance = stance and (mine.opts.stances or "what you stay in") or nil
				cap.icon:SetTexture(icon)
				cap.icon:SetAlpha(1)
				cap.slot:Empty(icon == nil)
				cap.slot:Fresh(false)
				-- A key you move with says which way (forward and back by name), its plate in your color.
				local scheme = Scheme()
				local moving = scheme.move[cap.key]
				-- A key of the number row with no job: an extra button, on one of the flyouts.
				local extra = not stance and view.board and view.board[cap.key]
				local bar, place = (extra or ""):match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
				cap.extra = (bar == HOT.plain or bar == HOT.bar) and tonumber(place) or nil
				cap.side = bar == HOT.plain and "left" or "right"
				-- Any other key that does something of the game's, in the hotkeys drawn: what it does.
				local command = not (stance or moving or cap.extra) and Keys.Doing(cap.key) or ""
				local does = command ~= "" and (view.bare or not Slots(command, {})) and GetBindingName(command) or nil
				-- (a bar's button, with everything as you had it: said short, the main bar's by its place)
				if does and Slots(command, {}) then does = command:match("^ACTIONBUTTON(%d+)$") and ("Bar " .. command:match("%d+$")) or "Bar" end
				cap.name:SetText(spell and C_Spell.GetSpellName(spell) or cap.key == scheme.forward and "Forward"
					or cap.key == scheme.back and "Back" or moving and "Move" or cap.extra and "Extra" or does or "")
				Theme.Ink(cap.name, moving and C.head or (cap.extra or does) and C.dim or C.text)
				-- (the one your build stays in: its name in green)
				cap.keep = nil
				if stance and spell and keep and C_Spell.GetSpellName(spell) == keep.name then
					cap.keep = keep.word
					Theme.Ink(cap.name, C.good)
				end
				cap:SetTone(moving and Theme.Accent or nil, moving)
				cap:SetAlpha((icon or stance or moving or cap.extra) and 1 or does and 0.8 or 0.45)
			end
			if job or own then cap:SetTone(nil, false) end
		end
		-- Your bars as they are now: on each key, what its button holds.
		for _, cap in ipairs(view.now and mine and f.caps or EMPTY) do
			local command = GetBindingAction(cap.key)
			local slots = command ~= "" and Slots(command, mine.opts) or nil
			local kind, id
			if slots then kind, id = GetActionInfo(slots[1]) end
			if kind then
				local name = kind == "macro" and C_ActionBar.GetActionText(slots[1]) or kind == "spell" and C_Spell.GetSpellName(id)
					or kind == "item" and C_Item.GetItemNameByID(id) or ""
				cap.icon:SetTexture(C_ActionBar.GetActionTexture(slots[1]) or ICON)
				cap.icon:SetAlpha(1)
				cap.slot:Empty(false)
				cap.name:SetText(name or "")
				Theme.Ink(cap.name, C.text)
				cap:SetAlpha(1)
				cap.job, cap.stance, cap.extra = nil, nil, nil
			end
		end
	end

	-- What changes at a level, said a row each.
	local SAY = {
		new = function(turn) return "New: " .. (turn.name or turn.job.what) end,
		moved = function() return "Sits here for now" end,
		grows = function(turn) return "Now " .. (turn.name or turn.job.what) end,
	}
	local function Turns(level)
		f.Turns = Turns
		local shown, list = level, view.changes and view.changes[level] or {}
		if #list == 0 then
			for next = level + 1, top do
				if #view.changes[next] > 0 then
					shown, list = next, view.changes[next]
					break
				end
			end
		end
		if #list == 0 then
			f.turnsHead:SetText("Nothing changes after this level")
		elseif shown == level then
			f.turnsHead:SetText(("At level %d"):format(level))
		else
			f.turnsHead:SetText(("Next, at level %d"):format(shown))
		end
		-- Two columns, down the first and then the second; the first few, and the rest with Show more.
		local most = VIEW.turns * 2
		local shown = view.allTurns and #list or math.min(#list, most)
		local down = math.max(1, math.ceil(shown / 2))
		for i = 1, math.max(shown, #f.turns) do
			local row = i <= shown and f:Turn(i) or f.turns[i]
			local turn = i <= shown and list[i] or nil
			row:SetShown(turn ~= nil)
			if turn then
				local c, r = math.floor((i - 1) / down), (i - 1) % down
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", f.turnsHead, "BOTTOMLEFT", c * (column + GAP), -8 - r * VIEW.turnRow)
				row.plate:SetShown(turn.key ~= nil)
				row.key:SetText(turn.key and Hot.Plate(turn.key) or "")
				row.plate:SetWidth(math.max(22, math.ceil(row.key:GetStringWidth()) + 12))
				row.icon:SetTexture(turn.icon or ICON)
				row.title:SetText(turn.job.name)
				row.sub:SetText(SAY[turn.kind](turn))
			end
		end
		local hidden = #list - shown
		f.more:Set(hidden > 0 and ("Show %d more"):format(hidden) or (view.allTurns and #list > most and "Show fewer") or nil)
		f.more:ClearAllPoints()
		f.more:SetPoint("TOPLEFT", f.turnsHead, "BOTTOMLEFT", 0, -8 - down * VIEW.turnRow - 4)
		f:SetHeight(Above() + down * VIEW.turnRow + (f.more:IsShown() and (HOT.moreTall + 8) or 4))
	end

	-- A notch under the slider at every level where something changes.
	local function Notches()
		local track = f.level.slider
		local knob = track:GetHeight()
		local reachable = track:GetWidth() - knob
		for _, notch in ipairs(f.notches) do notch:Hide() end
		local n = 0
		local plays = view.plays or {}
		for level = 2, top do
			if #view.changes[level] > 0 or level == Mine() or plays[level] then
				n = n + 1
				local notch = f.notches[n]
				if not notch then   -- a mark is a click to its level: a little target round a fine line
					notch = CreateFrame("Button", nil, f.level)
					notch:SetSize(VIEW.notch[1] + 6, VIEW.notch[2] + 8)
					notch.line = notch:CreateTexture(nil, "ARTWORK")
					notch.line:SetColorTexture(1, 1, 1, 1)
					notch.line:SetPoint("TOP")
					notch:SetScript("OnClick", function(self) f:At(self.at) end)
					notch:SetScript("OnEnter", function(self) self.line:SetAlpha(1) Theme.Tint(self.line, C.head, 1) end)
					notch:SetScript("OnLeave", function(self) self:Paint() end)
					f.notches[n] = notch
				end
				notch.at = level
				notch:ClearAllPoints()
				notch:SetPoint("TOP", track, "BOTTOMLEFT", math.floor(knob / 2 + (level - 1) / (top - 1) * reachable), 0)
				-- (yours in gold, longest; where how you play changes in your color, longer; any other change dim)
				local yours, play = level == Mine(), plays[level]
				notch.line:SetSize(VIEW.notch[1], VIEW.notch[2] + (yours and 4 or play and 2 or 0))
				function notch:Paint()
					Theme.Tint(self.line, yours and C.alert or play and Theme.Accent or C.dim, 1)
				end
				notch:Paint()
				notch:Show()
			end
		end
	end

	function f:At(level)
		view.level = math.max(1, math.min(top, level))
		if not view.levels then return end
		Paint(view.level)
		Turns(view.level)
		self.level:Refresh()
		for _, arrow in ipairs({ { self.before, view.level > 1 }, { self.after, view.level < top } }) do
			arrow[1]:SetEnabled(arrow[2])
			arrow[1]:SetAlpha(arrow[2] and 1 or 0.4)
		end
		Shy:Fire("SHY_KEYS_LEVEL", view.level)   -- (the guide to playing follows)
	end

	function f:Refresh()
		if Drawn(self) then return end
		local mine = Keys.Mine()
		local laid = mine ~= nil and Keys.Has(mine.addon)
		self.hot:Refresh()
		-- Step 1's sentence: what the choice lit (or under the mouse) gives you, and when it is done.
		local shown, state = self.hot.shown, self.hot:State()
		local done = plan and "Finish" or "the button below"
		if not mine then
			self.status:SetText("No keys for this class yet.")
		elseif plan == nil and laid and Keys.Old(mine.addon) then
			self.status:SetText("There's a new key layout, shown below. Water and each potion get their own key, your stances, forms or auras are on 1 2 3, and your racials are on Shift + 1 and 2. Your keys stay as they are until you press Update my keys.")
		elseif shown == "shy" and state == "shy" then
			local _, name = nil, nil
			if mine.opts.build then _, name = mine.opts.build() end
			self.status:SetText(("Your keys are set up%s. Each ability lands on its key when you learn it. Move one and it stays where you put it."):format(name and (" for " .. name) or ""))
		elseif shown == "shy" then
			self.status:SetText(("Every ability gets its own key close to your hand, and lands on it when you learn it. Nothing changes until you press %s."):format(done))
		elseif shown == "own" then
			self.status:SetText("Your hotkeys stay as they are, and abilities go on the keys you already use. If a key already does something else, its ability waits.")
		else
			self.status:SetText(state ~= "off" and "Every button and hotkey goes back exactly as you had it."
				or "Everything stays exactly as you have it now.")
		end
		self.step1:Fit()
		self.step3.title:SetText(shown == "shy" and "Your new keys" or "Your keys")
		-- The button: the choice looked at, when it isn't the one in use.
		local pending = self.hot:Pending()
		local block = pending and pending ~= "off" and not laid and self.hot.says and self.hot.says.block
		self.lay:SetLabel(self.hot:Label())
		self.lay:SetPrimary(mine ~= nil and pending ~= nil and not block)
		self.lay:SetUsable(mine ~= nil and pending ~= nil and not block,
			not mine and "No keys for this class yet." or block or "This is what you use now. Pick another choice to see it first.")
		self.hint:SetText(pending and "Nothing changes until you press it." or "")
		self.follow:Refresh()
		-- (the choice alone, or what it changes alone: no keys drawn, and as tall as that part)
		if part == "choose" or part == "changes" then
			for _, piece in ipairs({ board, self.level, self.before, self.after, self.turnsHead, self.turnsRule, self.more }) do piece:Hide() end
			for _, row in ipairs(self.turns) do row:Hide() end
			self:SetHeight(self.hot:GetHeight() + ((plan == nil and part == "choose") and HOT.buttons or 0))
			return
		end
		-- The keys of yours that change, for the caps' marks; the board, for the number row's extra buttons; and
		-- everything as it was before: the keys alone, what each does, with no ability on them.
		local shown, standing = self.hot.shown, self.hot.shown == self.hot:State()
		-- (an earlier layout's keys: the button that draws them as they are, where the hint stands)
		local old = plan == nil and laid and Keys.Old(mine.addon)
		if not old then view.now = false end
		self.flip:SetShown(old)
		self.flip.says = view.now and "Show the new layout" or "Show what I have now"
		self.flip:SetLabel(self.flip.says)
		if old then self.hint:SetText("") end
		view.changing, view.board, view.bare = nil, nil, shown == "off" or view.now == true
		if mine and shown == "shy" then
			view.board = Keys.Board(mine.opts)
			if not Hot.On() then
				view.changing = {}
				for _, change in ipairs(Hot.Plan(mine.opts).changes) do view.changing[change.key] = change end
			end
		end
		self.whose:SetText(view.now and "What you have now" or old and "Preview: the new layout"
			or (standing and "In use: %s" or "Preview: %s"):format(self.hot:Title(shown)))
		Theme.Ink(self.whose, (view.now or (standing and not old)) and C.head or C.alert)
		if mine then
			view.levels, view.changes, view.story, view.jobs = Keys.Story(mine.jobs, mine.opts, mine.addon)
			view.plays = Keys.PlayLevels(mine.opts)
			Notches()
			self:At(view.level or Mine())
		end
		-- (Show more is shown by what it has to say: Turns)
		for _, piece in ipairs({ board, self.level, self.before, self.after, self.turnsHead, self.turnsRule }) do
			piece:SetShown(mine ~= nil)
		end
		for _, row in ipairs(self.turns) do
			if not mine then row:Hide() end
		end
	end
	f:SetScript("OnShow", f.Refresh)
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Refresh() end
	end)
	return f
end

-- What the files after this one use.
ns.C, ns.Drawn, ns.Theme = C, Drawn, Theme
