-- ShyKeys: Their homes: the /shy window's Keys room and a tab of setup's
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local BindingCalled, C, Drawn, EMPTY = ns.BindingCalled, ns.C, ns.Drawn, ns.EMPTY
local HOTVIEW, Hot, Lines, MiniBoard = ns.HOTVIEW, ns.Hot, ns.Lines, ns.MiniBoard
local Pick, Press, Ready, Scheme = ns.Pick, ns.Press, ns.Ready, ns.Scheme
local Several, Theme = ns.Several, ns.Theme

---------------------------------------------------------------------------
-- Their homes: the /shy window's Keys room and a tab of setup's
---------------------------------------------------------------------------

-- The width the keys' controls are drawn best at: a room of the /shy window, inside its margins.
Keys.WIDE = 676

local function Brief()
	local mine = Keys.Mine()
	return Scheme().name .. (mine and Keys.Has(mine.addon) and ", laid out" or ", not laid out")
end

-- The /shy window's Keys room: one page to change your keys on, not setup's walk again. Each part is a line on
-- the rail to go to, and they come in the order one thing decides the next:
--   how they work   whether your keys are laid out at all, and on whose hotkeys
--   how you move    the hand everything else is laid out around
--   what changes    the keys that fall out of those two, and where what they did goes
--   level by level  those keys drawn as a hand meets them
--   how to play     what to press, once they are yours
-- The two that settle the rest come first. A list of keys read before the things that decide it is a list of
-- answers to a question you haven't been asked.
--
-- The keys' own part keeps its Save at the window's foot (Shy.HubFoot) rather than under the list: a change
-- picked at the top of a long list is saved without hunting for the button.
local ROOM_PARTS = {
	{ label = "How they work", ask = "How your keys work", order = 10,
		lead = "Set them up for your class, keep your own hotkeys, or leave them alone. Pick one, then press the button under them.",
		build = function(page) return Keys.Panel(page, page.width, nil, "choose") end },
	{ label = "How you move", ask = "How do you move?", order = 20,
		lead = "Your keys are laid out around the hand you move with.",
		build = function(page) return Keys.Movement(page, page.width) end },
	-- (the room's own heading says Keys and the column over the plates says KEY: this one says what the list
	-- is for, not the same word a third time)
	{ label = "What changes", ask = "What changes", order = 30,
		lead = "Here's every key that changes, and where its old job goes.",
		build = function(page)
			local panel = Keys.Panel(page, page.width, nil, "changes")
			panel.hot.foot = function(bar) Shy.HubFoot(page, bar) end
			return panel
		end },
	{ label = "Level by level", ask = "Your keys, level by level", order = 40,
		lead = "Drag the level to see what comes when. Point at a key to see what it does.",
		build = function(page) return Keys.Panel(page, page.width, nil, "board") end },
	{ label = "How to play", ask = "How to play", order = 50,
		lead = "What to press and when, at the level the keys show.",
		build = function(page)
			-- (in a plain frame of its own: the guide's Show draws it at a level, and the room shows a part by its frame)
			local holder = CreateFrame("Frame", nil, page)
			holder.guide = Keys.Guide(holder, page.width)
			holder.guide:SetPoint("TOPLEFT")
			function holder:Refresh()
				self.guide:Show(self.guide.level)
				self:SetSize(page.width, math.max(1, self.guide:GetHeight()))
			end
			holder:Refresh()
			return holder
		end },
}
for _, def in ipairs(ROOM_PARTS) do
	Shy.HubSection("keys", function(page, top)
		local head = Shy.HubHead(page, top, def.ask, def.lead, def.label)
		local piece = def.build(page)
		piece:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
		return piece, function() piece:Refresh() end
	end, def.order)
end

Shy.HubBrief("keys", Brief)

-- The whole of it in one column, captioned as the room is: how you move, your keys, how to play.
--   Keys.Room(parent, width)   f:Refresh()
local function Caption(parent, text, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 14)
	local words = UI.Text(f, text:upper(), 11, true, C.dim)
	words:SetPoint("LEFT")
	local rule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.6)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", words, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT")
	return f
end

function Keys.Room(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local pieces = {}
	local function Under(above, caption, piece)
		local head = Caption(f, caption, width)
		head:SetPoint("TOPLEFT", above, above == f and "TOPLEFT" or "BOTTOMLEFT", 0, above == f and 0 or -26)
		piece:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
		pieces[#pieces + 1] = piece
		return piece
	end
	local moving = Under(f, "How you move", Keys.Movement(f, width))
	local panel = Under(moving, "Your keys", Keys.Panel(f, width, plan))
	-- (setup's tab is for choosing: how to play is the /shy window's, once the keys are yours)
	local guide = Keys.Guide(f, width)
	if plan then guide:Hide() else Under(panel, "How to play", guide) end
	f.moving, f.panel, f.guide = moving, panel, guide
	function f:Refresh()
		if Drawn(self) then return end
		moving:Refresh()
		panel:Refresh()
		if not plan then guide:Show(guide.level) end
		local tall = 0
		for _, piece in ipairs(pieces) do tall = tall + 14 + 12 + 26 + piece:GetHeight() end
		self:SetSize(width, tall)
	end
	-- (a pick's sentences and its list of your keys make it taller or shorter; setup's window then scrolls that far)
	panel.resized = function()
		f:Refresh()
		if plan and Shy.Setup and Shy.Setup.Grew then Shy.Setup.Grew() end
	end
	f:SetScript("OnShow", f.Refresh)
	return f
end

-- (the model's: setup's page and the /shy window's Save both note picks and do them together)
local Picks, Unpick = Hot.Picks, Hot.Unpick
local Settle = Hot.Settle
-- Setup's page for your keys: one question in the middle of the page, and Yes or No. Yes walks through setting
-- them up (setup's walk of your keys, below); No leaves your key binds, macros and bars alone, all of them.
-- Answered, the answer stays lit and a line under it says what it comes to; Yes again walks through it again.
--   Keys.Ask(parent, width, plan, room) -> f: f:Refresh(), f:Fit(room)
local ASK = { width = 460, gap = 16, button = 136, board = 22, pad = 40 }
Keys.QUESTION = "Want your key binds, macros and bars set up for you as you level?"
function Keys.Ask(parent, width, plan, room)
	local f = CreateFrame("Frame", nil, parent)
	f.room = room or 400
	f:SetSize(width, f.room)
	local column = CreateFrame("Frame", nil, f)
	column:SetWidth(ASK.width)
	column:SetPoint("CENTER")
	f.column = column
	-- (the keys you move with, lit, over the question: what it is about, at a glance)
	f.board = MiniBoard(column, function(letter) return Scheme().move[letter] == true end)
	f.board:SetPoint("TOP")
	f.question = UI.Text(column, Keys.QUESTION, 18, true, C.head)
	f.question:SetPoint("TOP", f.board, "BOTTOM", 0, -ASK.board)
	f.say = UI.Text(column, "Every ability gets a key close to your hand. Your bars and macros are set up for you. Each new ability goes on its key when you learn it. You'll see it all before anything changes, and one click puts it all back.", 12, false, C.dim)
	f.say:SetPoint("TOP", f.question, "BOTTOM", 0, -10)
	f.answer = UI.Text(column, "", 12, false, C.text)
	for _, text in ipairs({ f.question, f.say, f.answer }) do
		text:SetWidth(ASK.width)
		text:SetJustifyH("CENTER")
		text:SetWordWrap(true)
	end
	local function Answer(yes)
		plan.keys = plan.keys or {}
		plan.keys.asked = true
		if yes then
			-- (set up, unless there is a pick of yours already to look through again)
			if not HOTVIEW.picks[plan.keys.pick] then
				local mine = Keys.Mine()
				plan.keys.pick = mine and Keys.Has(mine.addon) and Keys.Mode() or "shy"
			end
			f:Refresh()
			if Shy.Setup and Shy.Setup.Walk then Shy.Setup.Walk("keys") end
		else
			plan.keys.pick = "skip"
			f:Refresh()
			if Shy.Setup and Shy.Setup.Walk then Shy.Setup.Walk("keys") end   -- (its pages go from the rail)
		end
	end
	f.yes = UI.Button(column, "Yes", ASK.button, function() Answer(true) end)
	f.no = UI.Button(column, "No", ASK.button, function() Answer(false) end)
	f.yes:SetPoint("TOPRIGHT", f.say, "BOTTOM", -ASK.gap / 2, -ASK.gap - 6)
	f.no:SetPoint("TOPLEFT", f.say, "BOTTOM", ASK.gap / 2, -ASK.gap - 6)
	f.answer:SetPoint("TOP", f.say, "BOTTOM", 0, -(ASK.gap + 6 + 24 + ASK.gap))
	function f:Fit(height)
		self.room = height or self.room
		local tall = self.board:GetHeight() + ASK.board + math.ceil(self.question:GetStringHeight()) + 10
			+ math.ceil(self.say:GetStringHeight()) + ASK.gap + 6 + 24
			+ ((self.answer:GetText() or "") ~= "" and (ASK.gap + math.ceil(self.answer:GetStringHeight())) or 0)
		column:SetHeight(tall)
		self:SetSize(width, math.max(self.room, tall + 2 * ASK.pad))
	end
	function f:Refresh()
		local keys = plan.keys or {}
		local pick = keys.pick
		-- (No is lit until you say Yes: it is what Next and Finish do)
		local yes = keys.asked and pick ~= "skip"
		local no = pick == "skip" or pick == nil
		self.yes:SetPrimary(not no)
		self.yes:SetOn(yes == true)
		self.no:SetOn(no == true)
		self.board:Light(function(letter) return Scheme().move[letter] == true end)
		if no then
			self.answer:SetText("Your key binds, macros and bars stay exactly as they are.")
		elseif yes then
			local line = Keys.STEP.Lines(plan)[1]
			self.answer:SetText(("%s. Press Yes to look through it again."):format(line.text))
		else
			self.answer:SetText("")
		end
		self:Fit()
	end
	f:Refresh()
	return f
end

-- The walk's last page: each part of it in a sentence, with Change to go back to its page.
--   Keys.Review(parent, width, plan) -> f: f:Refresh()
function Keys.Review(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(width)
	local parts = {}
	local function Part(n, title, page)
		local head = Hot.StepHead(f, n, width - 104)
		head.title:SetText(title)
		head.change = UI.Button(f, "Change", 92, function()
			if Shy.Setup and Shy.Setup.Show then Shy.Setup.Show(page) end
		end)
		head.change:SetPoint("TOPRIGHT", head, "TOPRIGHT", 104, 0)
		parts[#parts + 1] = head
		return head
	end
	f.choice = Part(1, "Your choice", "keys.pick")
	f.moving = Part(2, "How you move", "keys.move")
	f.changes = Part(3, "What changes", "keys.changes")
	f.board = Part(4, "Your new keys", "keys.board")
	f.foot = UI.Text(f, "Nothing changes until you press Finish. Later, one click in /shy keys puts it all back.", 12, false, C.alert)
	f.foot:SetWidth(width)
	f.foot:SetJustifyH("LEFT")
	function f:Refresh()
		local pick = plan.keys and plan.keys.pick
		local def = HOTVIEW.picks[pick] or HOTVIEW.picks.off
		self.choice.say:SetText(("%s. %s"):format(def.title, def.say))
		self.moving.say:SetText(Keys.Scheme() == "asdf" and "ASDF: S forward, F back. Your hand rests a key to the right."
			or "WASD: W forward, S back, as the game has it.")
		local line = Keys.STEP.Lines(plan)[1]
		self.changes.say:SetText(line.sub and line.sub ~= "" and line.sub or line.text)
		self.board.say:SetText(pick == "shy" and "Every ability gets its own key, from your first level to your last. Each new one goes on its key when you learn it."
			or pick == "own" and "Your abilities go on the keys you already use. If a key does something else, its ability waits."
			or "Your keys as you have them now.")
		local y = 0
		for _, part in ipairs(parts) do
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", 0, -y)
			y = y + part:Fit() + 22
		end
		self.foot:ClearAllPoints()
		self.foot:SetPoint("TOPLEFT", 0, -(y + 4))
		self:SetHeight(y + 4 + math.ceil(self.foot:GetStringHeight()))
	end
	f:SetScript("OnShow", f.Refresh)
	f:Refresh()
	return f
end

-- Setup: your keys, a page of its own with one question (Keys.Ask). The pick is the hotkeys' (plan.keys.pick):
-- "skip" (No: your keys, macros and bars left alone, whatever they are), "shy" (the board, recommended), "own"
-- (your keys as they are) or "off" (nothing laid out, and keys that are laid out put back). Taken, never given:
-- every setup starts at "skip", so nobody finishes setup to find anything of theirs changed, and keys laid out
-- before are left as they are. Yes walks through it (Keys.WALK): the choice, how you move,
-- what changes, your new keys, and a look over all of it. Finish does it, with nothing to reload. (Setup is the
-- core's own, loaded before this file; a test that leaves it out has no window to put the page in.)
Keys.STEP = {
	id = "keys", order = 23.5, title = "Your keys", glyph = "action",
	ask = "Your keys", lead = "",
	-- (Yes: the walk through them hangs under this page on the rail, and Next goes through it)
	walks = function(plan)
		local pick = plan and plan.keys and plan.keys.pick
		return pick ~= nil and pick ~= "skip"
	end,
	brief = function(plan)
		local pick = plan and plan.keys and plan.keys.pick
		if pick == "skip" then return "Left as they are" end
		if not HOTVIEW.picks[pick] or not Keys.Mine() then return Brief() end
		return Scheme().name .. ", " .. HOTVIEW.picks[pick].brief
	end,
	-- (always No to begin with: Next after Next never walks into your keys, and Finish leaves them as they are,
	-- laid out or not; Yes is the only way in)
	Plan = function(plan)
		plan.keys = { pick = "skip", was = Picks() }
	end,
	-- (the list's picks are noted as they are made: put back if the window closes without Finish)
	Worn = Picks,
	PutBack = function(was) Unpick(was) end,
	Build = function(parent, width, plan, room) return Keys.Ask(parent, width, plan, room) end,
	Lines = function(plan)
		local mine = Keys.Mine()
		local pick = plan.keys and plan.keys.pick
		if pick == "skip" then
			return { { text = "Your keys stay as they are", sub = "your key binds, macros and bars don't change" } }
		end
		if not mine or not pick then return { { text = Brief() } } end
		local laid = Keys.Has(mine.addon)
		local says = Hot.Says(pick, plan)
		if pick == "off" then
			return { { text = laid and "Your keys are put back" or "Your keys stay as they are",
				sub = laid and "every button and hotkey as it was before" or "set them up any time from /shy keys" } }
		end
		if says.block and not laid then
			return { { text = "Your keys aren't set up yet", sub = "there's no room for their macros. See the Keys page" } }
		end
		-- (set up stands only where the hotkeys are set: not on a character's own key bindings, until Finish)
		local stands = laid and pick == Keys.Mode() and (pick ~= "shy" or Hot.On())
		local text
		if pick == "shy" then
			text = stands and "Your keys stay set up" or "Your keys are set up, hotkeys and all"
		else
			text = stands and "Your abilities stay on your own hotkeys" or "Your abilities go on your own hotkeys"
		end
		-- Set up from here: what a hand relies on that moves, by name and where it goes, and that A and D strafe
		-- (setup's overview shows this sentence, before Finish).
		if pick == "shy" and not stands then
			local moves, sides = {}, {}
			for _, entry in ipairs(Hot.Yours(mine.opts)) do
				if not entry.kept and entry.must and entry.home then
					moves[#moves + 1] = ("%s to %s"):format(BindingCalled(entry.from), Keys.Key(entry.home))
				elseif entry.steer and not entry.kept then
					sides[#sides + 1] = Keys.Key(entry.key)
				end
			end
			local parts = {}
			if #moves > 0 then parts[#parts + 1] = ("Moves %s."):format(Several(moves, HOTVIEW.most)) end
			if #sides > 0 then parts[#parts + 1] = ("%s strafe. Hold the right mouse button to turn."):format(table.concat(sides, " and ")) end
			if #parts > 0 then
				parts[#parts + 1] = "Your old setup is saved, and one click puts it back."
				return { { text = text, sub = table.concat(parts, " ") } }
			end
		end
		return { { text = text, sub = says.safe } }
	end,
	Run = function(plan)
		local mine = Keys.Mine()
		local pick = plan.keys and plan.keys.pick
		if not mine or not pick or pick == "skip" then return false end   -- (No: nothing of your keys is touched)
		Settle(plan.keys.was)    -- (what was picked in the list: done now, as Finish promises)
		local laid = Keys.Has(mine.addon)
		if pick == "off" then
			if laid then Keys.Unlay(mine.addon) end
			return false
		end
		Keys.SetMode(pick)       -- (keys laid out already are switched at once)
		if not laid or Keys.Old(mine.addon) then
			local result = Keys.Lay(mine.addon, mine.jobs, mine.opts)
			if result then mine.waiting = result.waiting end
		end
		return false
	end,
}

-- The walk through your keys: its pages, each a part of the keys' page alone, under setup's heading for it.
local function Page(build)
	return function(parent, width, plan)
		local page = build(parent, math.min(width, Keys.WIDE + 124), plan)
		page.resized = function()
			if Shy.Setup and Shy.Setup.Grew then Shy.Setup.Grew() end
		end
		return page
	end
end
local function Picked(plan) return plan and plan.keys and plan.keys.pick end
Keys.WALK = {
	{ id = "keys.pick", order = 23.51, walk = "keys", title = "Your choice", glyph = "action",
		ask = "How should your keys work?", lead = "Pick one. The next pages show exactly what it means for you.",
		brief = function(plan) local def = HOTVIEW.picks[Picked(plan)]; return def and def.title end,
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "choose") end) },
	{ id = "keys.move", order = 23.52, walk = "keys", title = "How you move", glyph = "go",
		ask = "How do you move?", lead = "Your keys are laid out around the hand you move with.",
		brief = function() return Scheme().name end,
		Build = Page(function(parent, width) return Keys.Movement(parent, width) end) },
	{ id = "keys.changes", order = 23.53, walk = "keys", title = "What changes", glyph = "link",
		ask = function(plan)
			local pick = Picked(plan)
			return pick == "shy" and "What changes for you" or pick == "own" and "What stays, and what waits" or "Nothing changes"
		end,
		lead = function(plan)
			local pick = Picked(plan)
			return pick == "shy" and "Every key that changes, and where its old job goes. Take the new key or keep yours."
				or pick == "own" and "Your hotkeys stay. These abilities wait, because their keys do something else."
				or "Every button and hotkey stays as it is."
		end,
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "changes") end) },
	{ id = "keys.board", order = 23.54, walk = "keys", title = "Your new keys", glyph = "window",
		ask = "Your keys, level by level", lead = "Drag the level to see what comes when. Point at a key to see what it does.",
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "board") end) },
	{ id = "keys.review", order = 23.55, walk = "keys", title = "Review", glyph = "done",
		ask = "Ready when you are", lead = "All of it at a glance. Change anything, or press Done and then Finish.",
		Build = Page(function(parent, width, plan) return Keys.Review(parent, width, plan) end) },
}
if Shy.Setup then
	Shy.Setup.Step(Keys.STEP)
	for _, step in ipairs(Keys.WALK) do Shy.Setup.Step(step) end
end
