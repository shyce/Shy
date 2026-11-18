-- ShyKeys: How to play: the guide, at the level the keys show
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Button, C, Drawn, ICON = ns.Button, ns.C, ns.Drawn, ns.ICON
local Put, Theme = ns.Put, ns.Theme

---------------------------------------------------------------------------
-- How to play: the guide, at the level the keys show
---------------------------------------------------------------------------

-- PLAY: a step's row and its key's plate; the columns' gap; the most steps a column shows.
local PLAY = { row = 32, plate = 22, slot = 22, apart = 24, most = 10, number = 16 }

-- A key as its plate says it: "Q", "Shift Q", "Mouse 4", "Shift Mouse 4".
local function Plate(key)
	return (key:gsub("^SHIFT%-", "Shift "):gsub("BUTTON(%d)", "Mouse %1"))
end

-- A step: its place in the order, the key you press (a keyed plate, as wide as its words), the ability's picture,
-- its name and when to press it under that. The ability's own card on its hover.
local function Step(parent, width)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(width, PLAY.row)
	row:EnableMouse(true)
	row.number = UI.Text(row, "", 11, true, C.dim)
	row.number:SetPoint("LEFT")
	row.number:SetWidth(PLAY.number)
	row.plate = CreateFrame("Button", nil, row)
	row.plate:SetHeight(PLAY.plate)
	row.plate:SetPoint("LEFT", PLAY.number, 0)
	UI.KeyPlate(row.plate)
	row.key = UI.Text(row.plate, "", 11, true, C.head)
	row.key:SetPoint("CENTER")
	row.well = CreateFrame("Frame", nil, row)
	row.well:SetSize(PLAY.slot, PLAY.slot)
	row.well:SetPoint("LEFT", row.plate, "RIGHT", 8, 0)
	row.icon = row.well:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = PLAY.slot, hover = false })
	row.name = UI.Text(row, "", 13)
	row.name:SetPoint("TOPLEFT", row.well, "TOPRIGHT", 8, 2)
	row.name:SetPoint("RIGHT")
	row.when = UI.Text(row, "", 11, false, C.dim)
	row.when:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.when:SetPoint("RIGHT")
	for _, text in ipairs({ row.name, row.when }) do
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
	end
	row:SetScript("OnEnter", function(self)
		if not self.spell then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.spell)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	function row:Set(i, step)
		self.number:SetText(i)
		self.key:SetText(step.key and Plate(step.key) or "-")   -- (no key yet: still to train)
		self:SetAlpha(step.untrained and 0.6 or 1)
		self.plate:SetWidth(math.max(PLAY.plate, math.ceil(self.key:GetStringWidth()) + 12))
		self.icon:SetTexture(step.icon or ICON)
		self.name:SetText(step.name)
		self.when:SetText(step.when or "")
		Theme.Ink(self.when, step.alert and C.alert or C.dim)
		self.name:ClearAllPoints()
		self.name:SetPoint(step.when and "TOPLEFT" or "LEFT", self.well, step.when and "TOPRIGHT" or "RIGHT", 8, step.when and 2 or 0)
		self.name:SetPoint("RIGHT")
		self.spell = step.job and step.spell or nil
	end
	return row
end

-- How to play at the level the keys show (yours to start with): the bracket's levels and build, a sentence on how
-- fights go, then what to press in order against one enemy and against several, each as your key for the way you
-- move. f:Show(level) at a level; it follows the keys' slider.
function Keys.Guide(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local column = math.floor((width - PLAY.apart) / 2)
	f.title = UI.Text(f, "", 15, true, C.head)
	f.title:SetPoint("TOPLEFT")
	-- (the guide out on screen while you play, or put away again)
	f.pull = UI.Button(f, "", 170, function() Keys.ShowGuide(not Keys.GuideShown()) end)
	f.pull:SetPoint("TOPRIGHT", 0, 3)
	local function Pulled() f.pull:SetLabel(Keys.GuideShown() and "Put the guide away" or "Pull out the guide") end
	Pulled()
	Shy:On("SHY_KEYS_GUIDE", Pulled)
	-- (at your own level: what waits at your trainer, and what to buy first with the gold you have)
	f.train = CreateFrame("Frame", nil, f)
	f.train:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
	f.train:SetSize(width, 1)
	f.train.words = UI.Text(f.train, "", 13, false, C.alert)
	f.train.words:SetPoint("TOPLEFT")
	f.train.words:SetWidth(width)
	f.train.words:SetJustifyH("LEFT")
	f.train:SetScript("OnEnter", function(self) if self.list then Keys.TrainingHover(self, self.list) end end)
	f.train:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	f.tip = UI.Text(f, "", 13)
	f.tip:SetPoint("TOPLEFT", f.train, "BOTTOMLEFT", 0, -6)
	f.tip:SetWidth(width)
	f.tip:SetJustifyH("LEFT")
	-- (what to stay in: the aura, stance or form your build keeps on, as a row of its own)
	f.keepCaption = UI.Text(f, "", 11, true, C.dim)
	f.keepCaption:SetPoint("TOPLEFT", f.tip, "BOTTOMLEFT", 0, -14)
	f.keep = Step(f, math.floor((width - PLAY.apart) / 2))
	f.keep:SetPoint("TOPLEFT", f.keepCaption, "BOTTOMLEFT", 0, -6)
	f.lists = {}
	for i, kind in ipairs({ "single", "cleave" }) do
		local list = { kind = kind, rows = {} }
		list.caption = UI.Text(f, i == 1 and "ONE ENEMY" or "SEVERAL ENEMIES", 11, true, C.dim)
		list.caption:SetPoint("TOPLEFT", f.tip, "BOTTOMLEFT", (i - 1) * (column + PLAY.apart), -14)
		for n = 1, PLAY.most do
			local row = Step(f, column)
			row:SetPoint("TOPLEFT", list.caption, "BOTTOMLEFT", 0, -6 - (n - 1) * PLAY.row)
			list.rows[n] = row
		end
		f.lists[i] = list
	end
	local top = GetMaxLevelForPlayerExpansion()
	function f:Show(level)
		local mine = Keys.Mine()
		level = level or math.max(1, math.min(top, UnitLevel("player")))
		if Drawn(self, level) then return end
		self.level = level
		local play = mine and Keys.Play(mine.jobs, mine.opts, level, mine.addon)
		if not play then
			self.title:SetText(mine and "No guide for this class yet" or "No keys for this class yet")
			self.tip:SetText("")
			for _, list in ipairs(self.lists) do
				list.caption:Hide()
				for _, row in ipairs(list.rows) do row:Hide() end
			end
			self:SetSize(width, 24)
			return
		end
		-- (the bracket's levels: from its own start to the next bracket's, for this build)
		local upto = top
		for at in pairs(Keys.PlayLevels(mine.opts)) do
			if at > play.from and at - 1 < upto then upto = at - 1 end
		end
		local build
		if mine.opts.build then build = select(2, mine.opts.build()) end
		local span = upto > play.from and ("Levels %d to %d"):format(play.from, upto) or ("Level %d"):format(play.from)
		self.title:SetText(span .. (build and (", " .. build) or ""))
		local said
		if level == math.max(1, math.min(top, UnitLevel("player"))) then
			local list, sum = Keys.Training(play)
			said = Keys.TrainingSays(list, sum)
			self.train.list = list
		else
			self.train.list = nil
		end
		self.train.words:SetText(said or "")
		self.train:SetHeight(said and math.ceil(self.train.words:GetStringHeight()) or 1)
		self.train:EnableMouse(said ~= nil)
		self.tip:SetText(play.tip or "")
		local keep = play.keep
		self.keepCaption:SetShown(keep ~= nil)
		self.keep:SetShown(keep ~= nil)
		if keep then
			self.keepCaption:SetText(("YOUR %s"):format(keep.word:upper()))
			self.keep:Set("", keep)
		end
		local most = 0
		for i, list in ipairs(self.lists) do
			local steps = play[list.kind]
			list.caption:ClearAllPoints()
			list.caption:SetPoint("TOPLEFT", keep and self.keep or self.tip, "BOTTOMLEFT", (i - 1) * (column + PLAY.apart), keep and -8 or -14)
			list.caption:Show()
			for n, row in ipairs(list.rows) do
				local step = steps[n]
				row:SetShown(step ~= nil)
				if step then row:Set(n, step) end
			end
			most = math.max(most, math.min(#steps, PLAY.most))
		end
		local kept = keep and (14 + 14 + 6 + PLAY.row - 6) or 0
		self:SetSize(width, 24 + 6 + self.train:GetHeight() + 6 + math.ceil(self.tip:GetStringHeight()) + kept + 14 + 14 + 6 + most * PLAY.row)
	end
	-- (Out of sight, only the level is kept: it is drawn as it shows. A room kept for another width of the /shy
	-- window, setup's tab and a class's page each have a guide of their own.)
	Shy:On("SHY_KEYS_LEVEL", function(level)
		if f:IsVisible() then f:Show(level) else f.level = level end
	end)
	Shy:On("SHY_KEYS_STANCE", function()
		if f:IsVisible() then f:Show(f.level) end
	end)
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Show(f.level) end
	end)
	f:SetScript("OnShow", function(self) self:Show(self.level) end)
	f:Show()
	return f
end

-- What the files after this one use.
ns.Plate = Plate
