-- The trainer: a lesson plan. A window of our own in place of the game's (ClassTrainerFrame, in load-on-demand
-- Blizzard_TrainerUI), built for what a trainer is for: learn what you can now, read what you are buying, and know
-- what comes next and what to save for it. It is a desk (Shop.Desk): the game's window stays the panel the game
-- opens and closes, emptied and taking no mouse; ours is its child, in the make of the quest giver's window, so a
-- talk that leads to the lessons turns into them where it stands; it flows to any size.
--
-- The band: the trainer's face with a book at its corner, who they are, and pills: what is ready and its cost, what
-- you are short of it, when the next lessons come, and at a profession's trainer your skill.
-- Left, the plan: the lessons as a timeline under the family's group heads. Ready now first, in your color, then
-- each level to come (at a profession's trainer each rank of the skill), each head with how many and what they
-- cost, the next one open and the rest folded; what you know last, folded, where the game's filter lists it.
-- Right, the lesson you picked: its picture, name and rank, Learn with its price and what it leaves you, what it
-- needs ticked or crossed, and what it does in the game's own words.
-- The foot: your gold (a pet's training points), and Train all with its sum: everything ready that you can afford,
-- from the top, one lesson per TRAINER_UPDATE, never spending more than you have, stopping when the window closes
-- or a purchase doesn't go through.
--
-- A first profession needs Blizzard's CONFIRM_PROFESSION popup, which reads the skill from Blizzard's window: it is
-- selected there with ClassTrainer_SetSelection. Train all skips it.
-- While on, the module claims "trainAll" (ns.Claim) so ShyTweaks hides its own button.
-- Blizzard's filter menu is not shown: the list is whatever the filter was last set to.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Skin = Shy.Skin
local Slot = Shy.Slot
local C = UI.colors
local Shop = ns.Shop
local Talk = Shy.Talk
local WIN = Talk and Talk.WIN

local L = {
	w = 760, h = 560, least = { 600, 440 },
	top = 8,                               -- from the band to the plan and the lesson
	list = 300,                            -- the plan's width
	gap = 18,                              -- between the plan and the lesson
	right = 14,                            -- the lesson's right margin
	head = 28, fold = 20, row = 30, rowGap = 2, groupTop = 3, groupFoot = 4, between = 4,   -- a group's head and fold, a lesson's row
	rail = 17, branch = 26, indent = 28,   -- the group's rail, where a branch ends, where its rows begin
	icon = Slot.SIZES.button,              -- the picked lesson's picture
	chip = 24,                             -- a thing it needs
	pills = -44,                           -- the band's second line, under who the trainer is
	key = 22,                              -- a button's height
	patience = 2,                          -- seconds Train all waits for a purchase before stopping
}
local DOT = " \194\183 "
local RANK = { available = true, unavailable = true, used = true }
local ICON = Shop.ICON

local WORDS = {
	title = "Trainer", ready = "Ready now", known = "Known", later = "Not yet", full = "Needs a free profession",
	atLevel = "Level %d", after = "After %s", level = "Level %d",
	readyPill = "%d ready", short = "%s short", next = "Next at level %d", nextSkill = "Next at %s", skill = "Your skill: %d / %d",
	caught = "Nothing new for you", none = "Nothing to learn here",
	learn = "Learn", trainAll = "Train all %d", trainSome = "Train %d of %d", training = "Training",
	needs = "Needs", does = "What it does", leaves = "leaves you %s", lack = "%s short",
	noGold = "Not enough gold", noPoints = "Not enough training points", confirm = "You'll be asked to confirm a new profession.",
	cantAny = "You can't afford any of it.",
}

local M              -- the module
local desk           -- our window (Shop.Desk)
local own = { heads = {}, rows = {}, chips = {} }   -- our frames, made once
local visit = {}     -- this visit: role
local services = {}  -- the trainer's lessons, as last read
local groups = {}    -- ... in their groups, in the plan's order: { key, name, order, list, cost }
local opened = {}    -- a group's key -> folded open (true) or shut (false) by you, this session
local picked         -- the picked lesson's key
local run            -- Train all in progress: { last = last lesson asked for, at = when }
local Refresh, Stale, Draw

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

-- Reading the trainer

local function IsPet()
	return C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
end

-- Gold, or a pet's training points.
local function Budget(pet)
	if pet then
		local total, used = C_PetInfo.GetPetTrainingPoints()
		return math.max(0, (total or 0) - (used or 0))
	end
	return GetMoney()
end

local function Sum(amount, pet)
	if pet then return TRAINING_POINTS_ABBREV:format(tostring(amount)) end
	return Shop.Money(amount)
end

-- A lesson by what it is, whatever place the trainer's list gives it after the next update.
local function Key(s)
	return s.name .. "\n" .. (s.rank or "")
end

-- What a lesson needs, each with whether you meet it: { words, met, skill = rank | ability = true }.
local function Needs(s, level)
	local needs = {}
	if s.level > 1 then needs[#needs + 1] = { WORDS.level:format(s.level), level >= s.level } end
	local skill, rank, has = GetTrainerServiceSkillReq(s.index)
	if skill then needs[#needs + 1] = { skill .. " " .. rank, has and true or false, skill = rank } end
	for i = 1, GetTrainerServiceNumAbilityReq(s.index) do
		local ability, known = GetTrainerServiceAbilityReq(s.index, i)
		if ability then needs[#needs + 1] = { ability, known and true or false, ability = true } end
	end
	return needs
end

-- Where a lesson stands in the plan: its group's key, name and place. Ready first, then by the level it comes at,
-- then by the skill it asks for, then what waits on another lesson; what you know last.
local function Place(s)
	if s.kind == "used" then return "known", WORDS.known, 100000 end
	if s.new then return "ready", WORDS.ready, 0 end
	if s.kind == "available" then return "full", WORDS.full, 90000 end   -- a third profession
	for _, need in ipairs(s.needs) do
		if not need[2] then
			if need.skill then return "skill" .. need.skill, need[1], 1000 + need.skill end
			if need.ability then return "after" .. need[1], WORDS.after:format(need[1]), 50000 end
			return "level" .. s.level, WORDS.atLevel:format(s.level), s.level
		end
	end
	return "later", WORDS.later, 80000
end

local function Read()
	wipe(services)
	wipe(groups)
	local pet = IsPet()
	local level = UnitLevel(pet and "pet" or "player")
	local full = select(2, GetProfessions()) ~= nil   -- both profession slots used
	local by = {}
	for index = 1, GetNumTrainerServices() do
		local name, kind, texture, reqLevel, rank, category = GetTrainerServiceInfo(index)
		if name and RANK[kind] then
			local cost, profession = GetTrainerServiceCost(index)
			local s = { index = index, name = name, kind = kind, texture = texture, level = reqLevel or 0,
				rank = (rank and rank ~= "") and rank or nil, category = (category and category ~= "") and category or nil,
				cost = cost or 0, profession = profession and true or false }
			-- Learnable now, cost aside: available and not a third profession.
			s.new = kind == "available" and not (s.profession and full)
			s.needs = Needs(s, level)
			services[#services + 1] = s
			local key, title, order = Place(s)
			local group = by[key]
			if not group then
				group = { key = key, name = title, order = order, list = {}, cost = 0 }
				by[key] = group
				groups[#groups + 1] = group
			end
			group.list[#group.list + 1] = s
			if kind ~= "used" then group.cost = group.cost + s.cost end
		end
	end
	table.sort(groups, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.key < b.key
	end)
end

local function Find(key)
	if not key then return nil end
	for _, s in ipairs(services) do
		if Key(s) == key then return s end
	end
end

-- True when the game shows a confirmation first (a new profession).
local function Asks(s)
	return s.profession and IsTradeskillTrainer()
end

-- What "Train all" can afford: the lessons, their total cost, how many there are in all and what all would cost.
local function PlanAll(budget)
	local plan, total, all, sum = {}, 0, 0, 0
	for _, s in ipairs(services) do
		if s.new and not Asks(s) then
			all, sum = all + 1, sum + s.cost
			if s.cost <= budget - total then
				plan[#plan + 1] = s
				total = total + s.cost
			end
		end
	end
	return plan, total, all, sum
end

-- Learning

local function Learn(s)
	if Asks(s) then
		-- Blizzard's popup reads the skill from its own window, so select it there first.
		local shown = ClassTrainerFrame.skillIndexToDisplayIndex
		ClassTrainer_SetSelection(shown and shown[s.index] or s.index)
		StaticPopup_Show("CONFIRM_PROFESSION")
	else
		BuyTrainerService(s.index)
	end
end

local function Stop()
	run = nil
end

-- Buys one lesson; Refresh calls back here on TRAINER_UPDATE for the next.
local function Step()
	if not run then return end
	local s = PlanAll(Budget(IsPet()))[1]
	if not s then return Stop() end
	local key = Key(s)
	if key == run.last then
		-- Still available: not bought yet, or the purchase failed.
		if GetTime() - run.at > L.patience then Stop() end
		return
	end
	run.last, run.at = key, GetTime()
	BuyTrainerService(s.index)
	C_Timer.After(L.patience + 0.1, function() Stale() end)   -- no update by then: stop
end

local function TrainAll()
	if run then return end
	run = { at = GetTime() }
	Refresh()   -- takes the first step and holds the button while it runs
end

local function LearnPicked()
	local s = Find(picked)
	if run or not s or not s.new or s.cost > Budget(IsPet()) then return end
	Learn(s)
end

local function Pick(s)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	picked = Key(s)
	Refresh()
end

-- Building

-- A lesson's row: its picture, its name with its rank after it, its price at the right.
local function Row(i)
	local row = own.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.stock)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp")
	-- Picked: your color washed in from the left with a fine line of it at the edge. Under the mouse: a glow.
	row.lit = row:CreateTexture(nil, "BACKGROUND")
	row.lit:SetAllPoints()
	row.lit:SetColorTexture(1, 1, 1, 1)
	row.lit:Hide()
	row.edge = row:CreateTexture(nil, "BACKGROUND", nil, 2)
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	UI.Paint(row.edge, Theme.Accent)
	row.edge:Hide()
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.hot, 0.09)
	row.hot:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(Slot.SIZES.small, Slot.SIZES.small)
	row.icon:SetPoint("LEFT", 4, 0)
	row.icon:SetTexCoord(unpack(ICON))
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, size = Slot.SIZES.small, hover = false })
	row.cost = Text(row, UI.NameFont(10), C.dim)
	row.cost:SetPoint("RIGHT", -6, 0)
	row.cost:SetJustifyH("RIGHT")
	row.tick = row:CreateTexture(nil, "ARTWORK")
	row.tick:SetTexture(Skin.GLYPH.tick)
	UI.GlyphFit(row.tick, 10)
	row.tick:SetPoint("RIGHT", -8, 0)
	UI.Tint(row.tick, C.dim)
	row.tick:Hide()
	row.name = Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("LEFT", 36, 0)
	row:SetScript("OnClick", function(self)
		if self.service then Pick(self.service) end
	end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not self.service then return end
		UI.GameTipAt(self, self.icon)
		GameTooltip:SetTrainerService(self.service.index)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	own.rows[i] = row
	return row
end

-- A group's head: the family's (UI.GroupHead), its name on one line, how many and what they cost at its right.
local function Head(i)
	local h = own.heads[i]
	if h then return h end
	h = UI.GroupHead(own.stock, { height = L.head, rail = L.rail, gutter = 34, right = 6, foldSize = L.fold,
		branches = L.branch, line = true,
		click = function(self, button)
			if button ~= "LeftButton" or not self.key then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			opened[self.key] = not self.open
			Refresh()
		end })
	own.heads[i] = h
	return h
end

-- What a lesson needs: a pill, ticked or crossed.
local function Chip(i)
	local chip = own.chips[i]
	if chip then return chip end
	chip = UI.KeyPlate(CreateFrame("Button", nil, own.stage))
	chip:SetHeight(L.chip)
	chip.glyph = chip:CreateTexture(nil, "OVERLAY")
	UI.GlyphFit(chip.glyph, 10)
	chip.glyph:SetPoint("LEFT", 9, 0)
	chip.text = Text(chip, UI.NameFont(12), C.text)
	chip.text:SetPoint("LEFT", 25, 0)
	own.chips[i] = chip
	return chip
end

local function Build()
	desk = Shop.Desk({
		id = "shyskin.trainer", title = WORDS.title, glyph = "book",
		width = L.w, height = L.h, least = L.least,
		frame = function() return ClassTrainerFrame end,
		on = function() return M ~= nil and M.on == true end,
		try = function(fn) Shop.Try(M, fn) end,
		flow = function() if Stale then Stale() end end,
		close = function() CloseTrainer() end,
	})
	local box, shell = desk.box, desk.shell
	own.box, own.shell, own.band, own.foot, own.ground, own.driver = box, shell, shell.band, shell.foot, shell.ground, desk.driver
	local left = WIN.pad - 2

	-- The plan: the lessons under their heads, scrolling.
	local list = UI.ScrollArea(box, L.list, L.h, { smooth = true, shades = C.panel })
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", shell.band, "BOTTOMLEFT", left, -L.top)
	list:SetPoint("BOTTOMLEFT", shell.foot, "TOPLEFT", left, 2)
	list:SetWidth(L.list)
	list:SetFrameLevel(box:GetFrameLevel() + 3)
	own.list = list
	own.stock = CreateFrame("Frame", nil, list.content)
	own.stock:SetPoint("TOPLEFT")
	own.stock:SetSize(L.list, 1)
	own.divide = box:CreateTexture(nil, "ARTWORK")
	own.divide:SetWidth(1)
	own.divide:SetPoint("TOP", shell.band, "BOTTOM", 0, 0)
	own.divide:SetPoint("BOTTOM", shell.foot, "TOP", 0, 0)
	own.divide:SetPoint("LEFT", box, "LEFT", 2 + left + L.list + L.gap / 2, 0)
	UI.Paint(own.divide, C.border, 0.9)

	-- The lesson: its picture, name and rank, Learn; what it needs; what it does.
	local stage = CreateFrame("Frame", nil, box)
	stage:SetFrameLevel(box:GetFrameLevel() + 3)
	own.stage = stage
	own.stageX = left + L.list + L.gap
	own.item = CreateFrame("Frame", nil, stage)
	own.item:SetSize(L.icon, L.icon)
	own.item:SetPoint("TOPLEFT", 0, 0)
	own.icon = own.item:CreateTexture(nil, "ARTWORK")
	own.icon:SetAllPoints()
	own.icon:SetTexCoord(unpack(ICON))
	own.slot = Slot.New(own.item, { to = own.icon, icon = own.icon, size = L.icon, hover = false })
	own.learn = Shop.Button(stage, "go", LearnPicked)
	own.learn:SetHeight(L.key)
	own.learn:SetPoint("TOPRIGHT", 0, -2)
	own.left = Text(stage, UI.NameFont(10), C.dim)
	own.left:SetPoint("TOPRIGHT", 0, -(L.key + 8))
	own.left:SetJustifyH("RIGHT")
	own.name = Text(stage, UI.TitleFont(18), C.head)
	own.name:SetPoint("TOPLEFT", L.icon + 12, -3)
	own.sub = Text(stage, UI.NameFont(11), C.dim)
	own.sub:SetPoint("TOPLEFT", L.icon + 12, -27)
	own.needKick = Shop.Kicker(stage)
	own.needKick:SetPoint("LEFT")
	own.needKick:SetPoint("RIGHT")
	own.doesKick = Shop.Kicker(stage)
	own.doesKick:SetPoint("LEFT")
	own.doesKick:SetPoint("RIGHT")
	own.plate = UI.KeyPlate(CreateFrame("Button", nil, stage))
	own.lines = Shop.Lines(own.plate, { font = 12, pad = 10 })
	own.none = Text(stage, UI.TextFont(13), C.dim)
	own.none:SetPoint("TOPLEFT", 0, -4)
	own.none:SetText(WORDS.none)

	-- The foot: your gold (or a pet's points) at its left end, Train all at its right.
	own.gold = Text(shell.foot, UI.NameFont(12), C.head)
	own.gold:SetPoint("LEFT", WIN.button, 0)
	own.train = UI.Button(shell.foot, "", 96, TrainAll)
	own.train:SetHeight(L.key)
	own.train:SetFrameLevel(shell.foot:GetFrameLevel() + 2)
	own.train.dims = true
	own.train:Hide()

	-- The opening: the plan a line after a line, rising; the lesson with it; the band's and the foot's with the first.
	desk.risers = { { own.stock, list.content }, { stage, shell.band, own.stageX, -(WIN.band + L.top) } }
	desk.Pieces = function()
		local pieces = { stage }
		for _, pool in ipairs({ own.heads, own.rows }) do
			for _, piece in ipairs(pool) do
				if piece:IsShown() then pieces[#pieces + 1] = piece end
			end
		end
		return pieces
	end
	desk.Firsts = function()
		local firsts = { own.gold, own.train }
		for _, pill in ipairs(shell.pills) do firsts[#firsts + 1] = pill end
		return firsts
	end
	desk.Draw = function() Draw() end
	stage.line = 2
end

-- Drawing

-- The band: who the trainer is, and pills: what is ready and its cost, what you are short of it, when the next
-- lessons come, your skill at a profession's trainer; with nothing to say, where you are.
local function DrawBand(pet, budget, wide)
	local shell = own.shell
	local role, place = desk:Meet("npc", visit)
	local words = math.max(80, wide - shell.left - WIN.pad - 4)
	shell.role:SetWidth(words)
	local facts = {}
	local ready = groups[1] and groups[1].key == "ready" and groups[1] or nil
	if ready then
		facts[#facts + 1] = { text = WORDS.readyPill:format(#ready.list) .. (ready.cost > 0 and (DOT .. Sum(ready.cost, pet)) or ""), tone = "hot" }
		if ready.cost > budget then facts[#facts + 1] = { text = WORDS.short:format(Sum(ready.cost - budget, pet)), tone = "bad" } end
	elseif #services > 0 then
		facts[#facts + 1] = { text = WORDS.caught }
	end
	-- The next lessons to come: the first group that waits on a level or a rank of the skill.
	for _, group in ipairs(groups) do
		if group.order > 0 and group.order < 50000 then
			facts[#facts + 1] = { text = group.order < 1000 and WORDS.next:format(group.order) or WORDS.nextSkill:format(group.name) }
			break
		end
	end
	local rank, most = GetTrainerTradeskillRankValues()
	if rank and most and rank > 0 then facts[#facts + 1] = { text = WORDS.skill:format(rank, most) } end
	local shown = shell:Pills(facts, L.pills)
	shell.sub:SetShown(shown == 0)
	shell.sub:SetText(role ~= "" and place or "")
	shell.sub:SetWidth(words)
end

-- Whether a group stands open: as you left it, else Ready now and the next group to come.
local function Open(group, gi)
	if opened[group.key] ~= nil then return opened[group.key] end
	if group.key == "ready" then return true end
	return group.order < 90000 and (gi == 1 or (gi == 2 and groups[1].key == "ready"))
end

local function DrawRow(row, s, pet, budget)
	row.service = s
	row.icon:SetTexture(s.texture)
	row.icon:SetDesaturated(not s.new)
	row.icon:SetAlpha(s.new and 1 or 0.5)
	row.slot:Empty(not s.new)
	row.name:SetText(s.name .. (s.rank and UI.Wrap(C.dim, "  " .. s.rank) or ""))
	UI.Ink(row.name, s.new and C.text or C.dim)
	local known = s.kind == "used"
	row.tick:SetShown(known)
	row.cost:SetText((known or s.cost <= 0) and "" or Sum(s.cost, pet))
	UI.Ink(row.cost, s.new and (s.cost > budget and C.bad or C.head) or C.dim)
	row.name:SetWidth(math.max(40, row:GetWidth() - 36 - row.cost:GetStringWidth() - 14))
	local on = picked == Key(s)
	if on then
		local r, g, b = Theme.Accent()
		row.lit:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.22), CreateColor(r, g, b, 0.02))
	end
	row.lit:SetShown(on)
	row.edge:SetShown(on)
end

-- The plan: each group's head with how many it holds and what they cost, its lessons hanging under it while open.
local function DrawList(pet, budget)
	local stock = own.stock
	local y, rowAt, line = 0, 0, 0
	local width = L.list - 8
	for gi, group in ipairs(groups) do
		local h = Head(gi)
		h.key = group.key
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", stock, "TOPLEFT", 0, -y)
		h:SetWidth(width)
		h:Set(group.name)
		local ready, known = group.key == "ready", group.key == "known"
		local badges = {}
		if not known and group.cost > 0 then
			badges[#badges + 1] = { text = Sum(group.cost, pet), color = (ready and group.cost > budget) and C.bad or C.dim }
		end
		badges[#badges + 1] = { text = tostring(#group.list), color = ready and C.hot or C.dim }
		h:SetBadges(badges)
		h:SetAccent(ready and C.hot or nil)
		local open = Open(group, gi)
		h:SetOpen(open)
		h.line = line
		line = line + 1
		h:Show()
		local top = y
		y = y + L.head
		if open then
			y = y + L.groupTop
			local nodes = {}
			for _, s in ipairs(group.list) do
				rowAt = rowAt + 1
				local row = Row(rowAt)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", stock, "TOPLEFT", L.indent, -y)
				row:SetWidth(width - L.indent)
				DrawRow(row, s, pet, budget)
				row.line = line
				line = line + 1
				row:Show()
				nodes[#nodes + 1] = y - top + L.row / 2
				y = y + L.row + L.rowGap
			end
			y = y + L.groupFoot
			h:Hang(y - top - L.head, nodes)
		else
			h:Hang()
		end
		y = y + L.between
	end
	for i = #groups + 1, #own.heads do own.heads[i]:Hide() end
	for i = rowAt + 1, #own.rows do own.rows[i]:Hide() end
	own.list.content:SetSize(L.list, math.max(1, y))
	stock:SetSize(L.list, math.max(1, y))
	own.list:Update()
end

-- The lesson picked: its picture, name and rank; Learn with its price, and what it leaves you or how far short you
-- are; what it needs, ticked or crossed; what it does, as the game's tooltip says it.
local function DrawStage(pet, budget, width, room)
	local stage = own.stage
	stage:SetSize(width, room)
	local s = Find(picked)
	for _, piece in ipairs({ own.item, own.name, own.sub, own.learn, own.left, own.needKick, own.doesKick, own.plate }) do
		piece:SetShown(s ~= nil)
	end
	own.none:SetShown(s == nil)
	if not s then
		for _, chip in ipairs(own.chips) do chip:Hide() end
		return
	end
	own.icon:SetTexture(s.texture)
	own.icon:SetDesaturated(s.kind ~= "available")
	own.name:SetText(s.name)
	local said = {}
	if s.rank then said[#said + 1] = s.rank end
	if s.category then said[#said + 1] = s.category end
	if s.kind == "used" then said[#said + 1] = WORDS.known end
	own.sub:SetText(table.concat(said, DOT))

	-- Learn: there for a lesson that is ready, with its price; dim while your gold is short of it.
	local short = s.cost > budget
	own.learn:SetShown(s.new)
	own.left:SetShown(s.new and s.cost > 0)
	if s.new then
		own.learn:Say(s.cost > 0 and (WORDS.learn .. DOT .. Sum(s.cost, pet)) or WORDS.learn)
		own.learn:SetOff(short or run ~= nil)
		own.learn.tip = short and { s.name, (pet and WORDS.noPoints or WORDS.noGold) .. "." } or Asks(s) and { s.name, WORDS.confirm } or nil
		own.left:SetText(short and WORDS.lack:format(Sum(s.cost - budget, pet)) or WORDS.leaves:format(Sum(budget - s.cost, pet)))
		UI.Ink(own.left, short and C.bad or C.dim)
	end
	-- (Its name and rank keep clear of Learn and the line under it, whichever is wider.)
	local aside = s.new and math.max(own.learn:GetWidth(), s.cost > 0 and own.left:GetStringWidth() or 0) + 12 or 0
	local words = math.max(60, width - L.icon - 12 - aside)
	own.name:SetWidth(words)
	own.sub:SetWidth(words)

	-- What it needs.
	local y = L.icon + 14
	own.needKick:SetShown(#s.needs > 0)
	if #s.needs > 0 then
		own.needKick:ClearAllPoints()
		own.needKick:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, -y)
		own.needKick:SetPoint("RIGHT", stage, "RIGHT")
		own.needKick:Say(WORDS.needs)
		y = y + 22
		local x = 0
		for i, need in ipairs(s.needs) do
			local chip = Chip(i)
			chip.text:SetText(need[1])
			chip.glyph:SetTexture(need[2] and Skin.GLYPH.tick or UI.CLOSE_GLYPH)
			UI.Tint(chip.glyph, need[2] and C.good or C.bad)
			UI.Ink(chip.text, need[2] and C.text or C.bad)
			chip:SetTone(need[2] and C.good or C.bad)
			chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + 36)
			-- Onto the next line where this one is full.
			if x > 0 and x + chip:GetWidth() > width then x, y = 0, y + L.chip + 6 end
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", stage, "TOPLEFT", x, -y)
			chip:Show()
			x = x + chip:GetWidth() + 8
		end
		y = y + L.chip + 14
	end
	for i = #s.needs + 1, #own.chips do own.chips[i]:Hide() end

	-- What it does: the game's tooltip for it, past its name, as many lines as there is room for.
	own.doesKick:ClearAllPoints()
	own.doesKick:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, -y)
	own.doesKick:SetPoint("RIGHT", stage, "RIGHT")
	own.doesKick:Say(WORDS.does)
	local tall, shown = own.lines:Lay(C_TooltipInfo.GetTrainerService(s.index), 2, width, room - y - 22)
	own.doesKick:SetShown(shown > 0)
	own.plate:SetShown(shown > 0)
	own.plate:ClearAllPoints()
	own.plate:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, -(y + 22))
	own.plate:SetSize(width, math.max(1, tall))
end

-- The foot: your gold or your pet's points, and Train all with its sum: everything ready, or what your gold covers.
local function DrawFoot(pet, budget)
	if pet then own.gold:SetText(TRAINING_POINTS:format(tostring(budget))) else own.gold:SetText(UI.Money(budget, nil, 12)) end
	local plan, total, all, sum = PlanAll(budget)
	local train = own.train
	train:SetShown(all > 0)
	if all == 0 then return end
	if run then
		train.text:SetText(WORDS.training)
	elseif #plan == all or #plan == 0 then
		train.text:SetText(UI.MoneyFit(WORDS.trainAll:format(all) .. DOT .. Sum(sum, pet), train.text))
	else
		train.text:SetText(UI.MoneyFit(WORDS.trainSome:format(#plan, all) .. DOT .. Sum(total, pet), train.text))
	end
	train:SetUsable(#plan > 0 and not run, #plan == 0 and WORDS.cantAny or nil)
	local gold = own.gold:GetUnboundedStringWidth()
	own.shell:Answers({ train }, ((issecretvalue(gold) or not gold) and 0 or gold) + 16)
end

Draw = function()
	local f = ClassTrainerFrame
	Read()
	-- Train all in progress: buy the next one now that the list is current.
	Step()
	local pet = IsPet()
	local budget = Budget(pet)
	-- The lesson picked: yours while it is still listed, else the first that is ready, else the first there is.
	-- (The groups stand in the plan's order: Ready now leads when there is one.)
	if not Find(picked) then
		local first = groups[1] and groups[1].list[1]
		picked = first and Key(first) or nil
	end

	local box = own.box
	local wide, tall = box:GetWidth(), box:GetHeight()
	if issecretvalue(wide) or not wide or wide <= 0 then wide = L.w end
	if issecretvalue(tall) or not tall or tall <= 0 then tall = L.h end
	-- The game's own window, empty under ours, is as wide (up to the width ours is made at): what the game opens
	-- beside it stands clear of ours.
	Shop.Size(f, math.min(wide, L.w), f:GetHeight())

	DrawBand(pet, budget, wide)
	DrawList(pet, budget)
	local width = math.floor(wide - 4 - own.stageX - L.right)
	local room = tall - (UI.HEAD.window.line + UI.LINE) - WIN.band - WIN.foot - 6 - 2 * L.top
	DrawStage(pet, budget, width, room)
	DrawFoot(pet, budget)
	desk:Motion()
end

Refresh = function()
	if not (M and M.on and own.box) then return end
	if ClassTrainerFrame:IsShown() then Shop.Try(M, Draw) end
end

Stale = Shop.Later(function() Refresh() end)

local function EndVisit()
	Stop()
	wipe(visit)
	picked = nil
	if desk and desk.motion then desk:Rest() end
end

-- The module

local EVENTS = { "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_SERVICE_INFO_NAME_UPDATE", "TRAINER_DESCRIPTION_UPDATE", "PLAYER_MONEY",
	"PLAYER_LEVEL_UP", "UNIT_PET_TRAINING_POINTS" }

local function Hook()
	hooksecurefunc("ClassTrainerFrame_Update", function()
		if M.on then Stale() end
	end)
	ClassTrainerFrame:HookScript("OnShow", function()
		if not (M.on and desk) then return end
		Shy.HUD.Update(own.box)
		Shop.Try(M, function()
			own.list:SetVerticalScroll(0)
			desk:Begin("npc")
		end)
		Refresh()
	end)
	ClassTrainerFrame:HookScript("OnHide", EndVisit)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event)
		if event == "TRAINER_CLOSED" then
			EndVisit()
		elseif M.on and ClassTrainerFrame:IsShown() then
			Stale()
		end
	end)
end

local function Paint(m, kit)
	Shop.Try(m, function()
		if not desk then Build() end
		Shy.HUD.Update(own.box)
		Shop.Empty(kit, ClassTrainerFrame, own.box)
		ns.Claim("trainAll", true)
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	Stop()
	if desk then desk:Rest() end
	Shop.Refill(ClassTrainerFrame)
	Shop.Unsize(ClassTrainerFrame)
	ns.Claim("trainAll", false)
	if own.box then Shy.HUD.Update(own.box) end
end

M = ns.Module({
	id = "trainer",
	title = "Trainers",
	desc = "Replaces the trainer window with a lesson plan you can size: what you can learn now and its cost, each lesson's own words before you buy it, what comes at the levels ahead, and Train all that never overspends.",
	Ready = function() return ClassTrainerFrame ~= nil and Shop ~= nil and WIN ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
})
