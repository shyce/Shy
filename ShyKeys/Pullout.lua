-- ShyKeys: The guide pulled out: on screen while you play
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Button, C, HOT, Hot = ns.Button, ns.C, ns.HOT, ns.Hot
local ICON, NONE, Plate, Theme = ns.ICON, ns.NONE, ns.Plate, ns.Theme
local watched = ns.watched

---------------------------------------------------------------------------
-- The guide pulled out: on screen while you play
---------------------------------------------------------------------------

-- How to play at your level, as a window of its own that stays on screen: what to press against one enemy and
-- against several, each as your key and the ability, its when at the right. Opened and closed at any time
-- (ShyKeysDB.keysGuide): from the Keys room, `/shy guide` or its own ×. It stands at the top left until you drag it
-- elsewhere, and follows your level, your build and how you move as they change.
local CARD = { width = 280, least = 230, row = 22, slot = 18, plate = 18, pad = 10, gap = 6, caption = 16, most = 7 }


function Keys.GuideShown() return DB().keysGuide == true end

function Keys.ShowGuide(on)
	DB().keysGuide = on and true or false
	if ns.cardBox then
		Shy.HUD.Update(ns.cardBox)
		if on then ns.cardBox:Fill() end
	end
	Shy:Fire("SHY_KEYS_GUIDE", on and true or false)
end

local function CardRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(CARD.row)
	row.plate = CreateFrame("Button", nil, row)
	row.plate:SetHeight(CARD.plate)
	row.plate:SetPoint("LEFT")
	UI.KeyPlate(row.plate)
	row.key = UI.Text(row.plate, "", 10, true, C.head)
	row.key:SetPoint("CENTER")
	row.well = CreateFrame("Frame", nil, row)
	row.well:SetSize(CARD.slot, CARD.slot)
	row.well:SetPoint("LEFT", row.plate, "RIGHT", 6, 0)
	row.icon = row.well:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = CARD.slot, hover = false })
	row.when = UI.Text(row, "", 10, false, C.dim)
	row.when:SetPoint("RIGHT")
	row.when:SetJustifyH("RIGHT")
	row.when:SetWordWrap(false)
	row.name = UI.Text(row, "", 12)
	row.name:SetPoint("LEFT", row.well, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row.when, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	function row:Set(step)
		self.key:SetText(step.key and Plate(step.key) or "-")   -- (no key yet: still to train)
		self:SetAlpha(step.untrained and 0.6 or 1)
		self.plate:SetWidth(math.max(CARD.plate, math.ceil(self.key:GetStringWidth()) + 10))
		self.icon:SetTexture(step.icon or ICON)
		self.name:SetText(step.name)
		self.when:SetText(step.when or "")
		Theme.Ink(self.when, step.alert and C.alert or C.dim)
		self.when:SetWidth(step.when and math.min(130, math.ceil(self.when:GetStringWidth()) + 2) or 1)
	end
	return row
end

local function MakeCard()
	local box = Shy.HUD.Create({
		id = "shy.keys.guide",
		title = "How to play",
		width = CARD.width,
		height = 120,
		-- At the top left, where the windows you talk through open (a quest giver's, the mail, a vendor's): they
		-- stand over it while open. Dragged by its header anywhere; it keeps where you put it.
		point = { "TOPLEFT", "TOPLEFT", 16, -16 },
		shown = function() return Keys.GuideShown() and Keys.Mine() ~= nil and Keys.Mine().opts.play ~= nil end,
		hang = true,   -- grows downward, so the heading stays put
		-- Sized from its sides it flows: the rows take the width, the height is what they need.
		grip = { flow = function(self, w) self:SetWidth(w) self:Fill() end, min = { CARD.least, 80 } },
	})
	-- What it says stands on its body, inside the width the screen's plan gives it, as tall as it needs (UI.Body).
	box.head = UI.Head(box, { size = "piece", title = "How to play", drag = box, close = function() Keys.ShowGuide(false) end,
		panel = { hud = true, brackets = false }, body = true })
	-- The look keeps another clearance round the body: laid out again.
	Shy:On("SHY_BODY", function(f) if f == box then box:Fill() end end)
	-- What is written straight on the box stands on a frame above its body, whose sheet would cover it.
	local face = CreateFrame("Frame", nil, box)
	face:SetAllPoints(box)
	box.level = UI.Text(face, "", 12, true, C.head)
	box.train = CreateFrame("Frame", nil, box)
	box.train.words = UI.Text(box.train, "", 11, false, C.alert)
	box.train.words:SetPoint("TOPLEFT")
	box.train.words:SetJustifyH("LEFT")
	box.train:SetScript("OnEnter", function(self) if self.list then Keys.TrainingHover(self, self.list) end end)
	box.train:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	box.tip = UI.Text(face, "", 11, false, C.dim)
	box.keepCaption = UI.Text(face, "", 10, true, C.dim)
	box.keep = CardRow(box)
	box.tip:SetJustifyH("LEFT")
	box.lists = {}
	for i, kind in ipairs({ "single", "cleave" }) do
		local list = { kind = kind, rows = {} }
		list.caption = UI.Text(face, i == 1 and "ONE ENEMY" or "SEVERAL ENEMIES", 10, true, C.dim)
		for n = 1, CARD.most do list.rows[n] = CardRow(box) end
		box.lists[i] = list
	end

	-- Laid out top down for what it shows now, as tall as that.
	function box:Fill()
		if not self:IsShown() then return end
		local mine = Keys.Mine()
		local level = math.max(1, math.min(GetMaxLevelForPlayerExpansion(), UnitLevel("player")))
		local play = mine and Keys.Play(mine.jobs, mine.opts, level, mine.addon)
		local inside = UI.Body(self)
		local width = UI.BodySize(self) - 2 * CARD.pad
		local y = UI.HEAD.piece.line + UI.LINE + CARD.pad
		local build = mine and mine.opts.build and select(2, mine.opts.build())
		self.level:ClearAllPoints()
		self.level:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.level:SetText(("Level %d%s"):format(level, build and (", " .. build) or ""))
		y = y + 16
		-- (what waits at your trainer, and what to buy first)
		local list, sum
		if play then list, sum = Keys.Training(play) end
		local said = Keys.TrainingSays(list, sum)
		self.train.list = list
		self.train:ClearAllPoints()
		self.train:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.train.words:SetWidth(width)
		self.train.words:SetText(said or "")
		self.train:SetSize(width, said and math.ceil(self.train.words:GetStringHeight()) or 1)
		self.train:EnableMouse(said ~= nil)
		if said then y = y + self.train:GetHeight() + 4 end
		self.tip:ClearAllPoints()
		self.tip:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.tip:SetWidth(width)
		self.tip:SetText(play and play.tip or "")
		y = y + (play and math.ceil(self.tip:GetStringHeight()) or 0) + CARD.gap
		local keep = play and play.keep
		self.keepCaption:SetShown(keep ~= nil)
		self.keep:SetShown(keep ~= nil)
		if keep then
			self.keepCaption:ClearAllPoints()
			self.keepCaption:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -(y + 4))
			self.keepCaption:SetText(("YOUR %s"):format(keep.word:upper()))
			y = y + CARD.caption
			self.keep:ClearAllPoints()
			self.keep:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
			self.keep:SetWidth(width)
			self.keep:Set(keep)
			y = y + CARD.row + CARD.gap
		end
		for _, list in ipairs(self.lists) do
			local steps = play and play[list.kind] or NONE
			list.caption:SetShown(#steps > 0)
			if #steps > 0 then
				list.caption:ClearAllPoints()
				list.caption:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -(y + 4))
				y = y + CARD.caption
			end
			for n, row in ipairs(list.rows) do
				local step = steps[n]
				row:SetShown(step ~= nil)
				if step then
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
					row:SetWidth(width)
					row:Set(step)
					y = y + CARD.row
				end
			end
			y = y + CARD.gap
		end
		local _, t, _, b = UI.BodyIn(self)
		self:SetHeight(y + CARD.pad - CARD.gap + t + b)
	end
	box:SetScript("OnShow", box.Fill)
	ns.cardBox = box
	box:Fill()
end

-- The hotkeys follow who is playing: on key bindings the account shares, a class with a stance bar has it on
-- 1 2 3 and another has those keys on the flyout. Only keys set here and still as set are touched, out of a fight.
function Hot.Follow()
	if not Hot.On() then return end
	if InCombatLockdown() then
		HOT.follow = true
		return
	end
	HOT.follow = false
	local mine = watched[1]
	if mine and Keys.Old(mine.addon) then return end   -- (an older layout: its keys stay as they are until it is taken)
	local result = Hot.Take(mine and mine.opts, true)
	-- (a key that presses another button now, a flyout's bar laid another way: the job on it follows)
	if result and result.bound > 0 and mine and Keys.Has(mine.addon) and not Keys.Old(mine.addon) and not Keys.Paused(mine.addon) then
		local laid = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if laid then mine.waiting = laid.waiting end
	end
end

---------------------------------------------------------------------------

-- What the files after this one use.
ns.MakeCard = MakeCard
