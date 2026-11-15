-- Our own talent window, in place of the game's while the "spells" module is on (Spellbook.lua switches it):
-- nothing in it is secure, so it opens at its own size and moves in a fight too. The game's window is left
-- for another player's talents.
--
-- Three trees side by side, each a card on its third of the class's painting: the tree's icon, name and the
-- points in it at the top, and under the name, while a row is still shut, a lock and the points it opens at;
-- the rows still shut under a veil past a hairline. Talents are
-- slots with their ranks as pips under them: the accent for ranks learned, gold for ranks waiting for Apply;
-- a talent you hold in full color, one you haven't dimmed; a mint mark while a point can go in, the accent once
-- full; grey while out of reach. Arrows light once the talent before is full. The foot: the points left, Undo,
-- Apply changes (gold while ranks wait), Reset. With dual spec, Primary and Secondary stand in the title strip;
-- the one you're not in shows its talents, with Activate where Apply stands. ShyQuest's leveling build
-- (Shy.addons.Quest:TalentPlan(), heard again on SHY_BUILD) names its tree under the tree's own and says each
-- talent's turn in its hover; ShyQuest stands its map pins on the talents themselves (.Button, SHY_TALENTS).
--
-- Everything is the game's talent data, read as the window draws (C_Traits): where each talent stands, its
-- ranks, picture and words, the rows' gates, the arrows, the points. Nothing about the trees is kept here.
-- A click stages a rank (C_Traits.PurchaseRank), a right-click takes a staged one back (RefundRank), Apply
-- commits them (C_ClassTalents.CommitConfig), Undo rolls them back, Reset (asked twice) stages a reset of
-- every tree. Which ranks wait for Apply: what each talent had when nothing was staged, noted as it is read.
--
--   ns.TalentWindow.On(on)    takes the game's talent key and menu button (the module on), or gives them back
--   ns.TalentWindow.Toggle(), .Open(), .Close(), .IsOpen()
-- For other addons, Shy.addons.Skin:Talents() returns the same table, with .Button(node) (a talent's frame while
-- the window shows it) and .Config(); bus SHY_TALENTS after every lay of the window.

local ADDON, ns = ...
local T = ns.T
local UI, Skin, Theme, Slot = Shy.UI, Shy.Skin, Shy.Theme, Shy.Slot
local C, SC = UI.colors, Skin.colors

local TW = {}
ns.TalentWindow = TW
function T:Talents() return TW end

local HEAD = UI.HEAD.window
local M = {
	slot = 37, col = 50, row = 50,      -- a talent's slot, and the pitch of the grid
	pad = 20, right = 20,               -- a card's edges to its first and last columns
	crest = 54, first = 14, under = 23, -- a card's head; the head to the first row; the last row's foot to the card's
	gap = 8, margin = 10, below = 8,    -- between two cards; the window's sides to a card; under the header
	foot = 40,                          -- the window's foot
	pip = 5, pipH = 3, pipGap = 2, pipDown = 3,
	icon = 34,                          -- a tree's icon
	stepLeast = 100,                    -- talents closer than this (in the game's units) stand in one column or row
}
local ICON = { 0.08, 0.92, 0.08, 0.92 }
local BURNS = { { "TOP", 110, 0.94 }, { "BOTTOM", 90, 0.85 }, { "LEFT", 46, 0.5 }, { "RIGHT", 46, 0.5 } }

local on, open = false, false
local view                  -- the spec group shown, when not the active one
local box                   -- the window
local cards = {}            -- one a tree
local buttons = {}          -- node -> its talent's button
local data                  -- the tree as last read
local committed = {}        -- config -> node -> ranks it had when nothing was staged
local committing            -- Apply pressed: until the game says it is done
local soon                  -- a lay is asked for the next frame
local plan                  -- ShyQuest's leveling build, for this tree: byNode[node] = its turn, counts, group, name
local PLACE = { "next", "2nd", "3rd", "4th", "5th" }

local function Num(v)
	if type(v) ~= "number" or issecretvalue(v) then return 0 end
	return v
end

---------------------------------------------------------------------------
-- Reading the tree
---------------------------------------------------------------------------

-- The grid's pitch: the step seen most often between neighbouring places (the smaller on a tie), ignoring those
-- closer than stepLeast. One talent standing off the grid can't set it.
local function Step(values)
	local seen, places = {}, {}
	for _, v in ipairs(values) do
		if not seen[v] then
			seen[v] = true
			places[#places + 1] = v
		end
	end
	table.sort(places)
	local count, best = {}, nil
	for i = 2, #places do
		local d = places[i] - places[i - 1]
		if d >= M.stepLeast then
			count[d] = (count[d] or 0) + 1
			if not best or count[d] > count[best] or (count[d] == count[best] and d < best) then best = d end
		end
	end
	return best or 1
end

-- A tree's talents that stand together along one axis: runs of talents no more than two pitches apart, the run
-- most of them stand in kept. A talent the game's data leaves far from its tree stands alone and is left out.
local function Together(nodes, key, pitch)
	local sorted = {}
	for i, node in ipairs(nodes) do sorted[i] = node end
	table.sort(sorted, function(a, b) return a[key] < b[key] end)
	local best, run = {}, {}
	for i, node in ipairs(sorted) do
		if i > 1 and node[key] - sorted[i - 1][key] > 2 * pitch then run = {} end
		run[#run + 1] = node
		if #run > #best then best = run end
	end
	local keep = {}
	for _, node in ipairs(best) do keep[node] = true end
	return keep
end

-- How far a place is from the nearest line of the grid, in pitches.
local function OffGrid(value, origin, pitch)
	local at = (value - origin) / pitch
	return math.abs(at - math.floor(at + 0.5))
end

local function Read()
	local active = C_SpecializationInfo.GetActiveSpecGroup()
	local group = view or active
	local config = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
	local info = config and C_Traits.GetConfigInfo(config)
	local tree = info and info.treeIDs and info.treeIDs[1]
	if not tree then return nil end
	local d = { group = group, active = group == active, config = config, tree = tree, tabs = {}, byGroup = {}, nodes = {}, byNode = {} }
	for _, shown in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(tree) or {}) do
		local tab = { group = shown.groupID, name = shown.displayName, icon = shown.icon, order = shown.orderIndex or 0, spent = 0, nodes = {} }
		d.tabs[#d.tabs + 1] = tab
		d.byGroup[shown.groupID] = tab
	end
	table.sort(d.tabs, function(a, b) return a.order < b.order end)
	if #d.tabs == 0 then return nil end
	local groups = {}
	for i, tab in ipairs(d.tabs) do
		tab.index = i
		groups[i] = tab.group
	end
	for _, spent in ipairs(C_Traits.GetGroupCurrencyInfo(config, groups) or {}) do
		local tab, purse = d.byGroup[spent.traitNodeGroupID], spent.currencyInfos and spent.currencyInfos[1]
		if tab and purse then tab.spent = Num(purse.spent) end
	end
	local purse = (C_Traits.GetTreeCurrencyInfo(config, tree, false) or {})[1]
	d.left = purse and Num(purse.quantity) or 0
	d.currency = purse and purse.traitCurrencyID
	d.staged = C_Traits.ConfigHasStagedChanges(config)
	local had = committed[config]
	if not d.staged or not had then
		had = {}
		committed[config] = had
	end

	-- The talents, each on its tree's grid.
	local xs, ys, found = {}, {}, {}
	for _, id in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
		local n = C_Traits.GetNodeInfo(config, id)
		if n and n.ID ~= 0 and n.isVisible and type(n.posX) == "number" and type(n.posY) == "number" then
			local tab
			for _, g in ipairs(n.groupIDs or {}) do tab = tab or d.byGroup[g] end
			if tab then
				local ranks = Num(n.ranksPurchased)
				if not d.staged then had[id] = ranks end
				local node = { id = id, info = n, tab = tab, x = n.posX, y = n.posY, ranks = ranks, max = Num(n.maxRanks) }
				node.staged = math.max(0, ranks - (had[id] or ranks))
				found[tab] = found[tab] or {}
				found[tab][#found[tab] + 1] = node
				xs[#xs + 1], ys[#ys + 1] = node.x, node.y
			end
		end
	end
	local across, down = Step(xs), Step(ys)
	-- Some trees' data keep a talent far off the window, where the game's own window never shows it: only the
	-- talents standing with the rest of their tree, on its grid, are laid.
	local kept, top = {}, math.huge
	for _, tab in ipairs(d.tabs) do
		local nodes = found[tab] or {}
		local byX, byY = Together(nodes, "x", across), Together(nodes, "y", down)
		local left = math.huge
		for _, node in ipairs(nodes) do
			if byX[node] and byY[node] then left = math.min(left, node.x) end
		end
		kept[tab] = {}
		for _, node in ipairs(nodes) do
			if byX[node] and byY[node] and OffGrid(node.x, left, across) <= 0.25 then
				kept[tab][#kept[tab] + 1] = node
				top = math.min(top, node.y)
			end
		end
		tab.left = left
	end
	d.cols, d.rows = 1, 1
	for _, tab in ipairs(d.tabs) do
		for _, node in ipairs(kept[tab]) do
			if OffGrid(node.y, top, down) <= 0.25 then
				node.col = math.floor((node.x - tab.left) / across + 0.5)
				node.row = math.floor((node.y - top) / down + 0.5) + 1
				d.cols, d.rows = math.max(d.cols, node.col + 1), math.max(d.rows, node.row)
				d.nodes[#d.nodes + 1] = node
				d.byNode[node.id] = node
				tab.nodes[#tab.nodes + 1] = node
			end
		end
	end

	-- The rows' gates: the first one still shut in each tree.
	local treeInfo = C_Traits.GetTreeInfo(config, tree)
	d.canRefund = not (treeInfo and treeInfo.cannotRefund)
	for _, gate in ipairs(treeInfo and treeInfo.gates or {}) do
		local node = d.byNode[gate.topLeftNodeID]
		local cond = node and C_Traits.GetConditionInfo(config, gate.conditionID)
		if cond and not cond.isMet then
			local tab = node.tab
			if not tab.gate or node.row < tab.gate.row then
				tab.gate = { row = node.row, need = Num(cond.spentAmountRequired) }
			end
		end
	end

	-- What leads to each talent (for its hover).
	for _, node in ipairs(d.nodes) do
		for _, edge in ipairs(node.info.visibleEdges or {}) do
			local target = d.byNode[edge.targetNode]
			if target then
				target.from = target.from or {}
				target.from[#target.from + 1] = node
			end
		end
	end
	return d
end

-- A talent's name, picture and its words at a rank.
local function About(node, rank)
	local n = node.info
	local entry = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
	local info = entry and C_Traits.GetEntryInfo(node.config or data.config, entry)
	local def = info and info.definitionID and C_Traits.GetDefinitionInfo(info.definitionID)
	local spell = def and def.spellID
	local name = def and (def.overrideName ~= "" and def.overrideName) or (spell and C_Spell.GetSpellName(spell)) or ""
	local icon = def and def.overrideIcon and def.overrideIcon ~= 0 and def.overrideIcon or (spell and C_Spell.GetSpellTexture(spell))
	local words = entry and rank and rank > 0 and C_Traits.GetTraitDescription(entry, rank)
	return name, icon, words, entry
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function Text(parent, font, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY")
	text:SetFontObject(font)
	UI.Follow(text)
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	return text
end

local function Fill(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

-- What the editable view can do with a talent right now.
local function CanLearn(node)
	return data.active and not committing and data.left > 0 and node.info.canPurchaseRank == true and node.ranks < node.max
end

local function CanTakeBack(node)
	return data.active and not committing and node.staged > 0 and node.info.canRefundRank == true
end

local function Tip(button)
	local node = button.node
	if not node or not data then return end
	local name, icon, now = About(node, math.max(node.ranks, 1))
	local _, _, next = About(node, node.ranks + 1)
	local key = { { text = ("Rank %d of %d"):format(node.ranks, node.max), color = C.dim } }
	if node.staged > 0 then key[2] = { text = ("  \194\183  %d waiting for Apply"):format(node.staged), color = C.alert } end
	local body = {}
	if node.ranks > 0 and now then
		body[#body + 1] = { text = now }
	elseif node.ranks == 0 and now then
		body[#body + 1] = { text = now, color = C.dim }
	end
	if node.ranks > 0 and node.ranks < node.max and next then
		body[#body + 1] = { rows = { { text = next, quiet = true } }, title = "Next rank" }
	end
	local needs = {}
	local gate = node.tab.gate
	if gate and node.row >= gate.row then
		needs[#needs + 1] = { text = ("%d points in %s"):format(gate.need, node.tab.name), color = C.bad }
	end
	for _, from in ipairs(node.from or {}) do
		if from.ranks < from.max then
			needs[#needs + 1] = { text = ("%s, all %d ranks"):format((About(from)), from.max), color = C.bad }
		end
	end
	if #needs > 0 then body[#body + 1] = { rows = needs, title = "Needs" } end
	local turn = plan and plan.byNode[node.id]
	if turn then
		local say = ("Leveling build: %s"):format(PLACE[turn] or turn)
		local count = plan.counts[node.id] or 1
		if count > 1 then say = ("%s, %d points"):format(say, count) end
		body[#body + 1] = { text = say, color = C.hot }
	end
	local hints = {}
	if CanLearn(node) then hints[#hints + 1] = { "left", "Learn" } end
	if CanTakeBack(node) then hints[#hints + 1] = { "right", "Take back" } end
	Shy.Hover.Show(button, { card = true, about = "talent:" .. node.id .. ":" .. node.ranks, icon = icon, title = name,
		kind = node.tab.name, key = key, body = body, hints = hints }, { at = UI.Beside(box, button) })   -- past the window: never over the next talent
end

local Lay

local function Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		if open then Lay() end
	end)
end

local function Click(button, mouse)
	local node = button.node
	if not node or not data then return end
	if mouse == "RightButton" then
		if CanTakeBack(node) then C_Traits.RefundRank(data.config, node.id) end
	elseif CanLearn(node) then
		if C_Traits.PurchaseRank(data.config, node.id) then PlaySound(SOUNDKIT.UI_CLASS_TALENT_NODE_SPEND) end
	end
	Soon()
end

local function Talent(card)
	local b = CreateFrame("Button", nil, card)
	b:SetSize(M.slot, M.slot + M.pipDown + M.pipH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(M.slot, M.slot)
	b.icon:SetPoint("TOPLEFT")
	b.icon:SetTexCoord(unpack(ICON))
	b.slot = Slot.New(b, { to = b.icon, icon = b.icon })
	b.pips = {}
	b:SetScript("OnClick", Click)
	b:SetScript("OnEnter", Tip)
	b:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	return b
end

-- A rank's pip: a face in whole screen pixels on a dark backing a pixel larger all round (UI.BoxFit).
local function Pip(b, i)
	local pip = b.pips[i]
	if pip then return pip end
	pip = { back = Fill(b, "BACKGROUND", 2), face = Fill(b, "ARTWORK", 2) }
	pip.back:SetVertexColor(0, 0, 0, 0.65)
	pip.back:SetSnapToPixelGrid(true)
	pip.back:SetTexelSnappingBias(0)
	b.pips[i] = pip
	return pip
end

-- The pips under a talent, one a rank, centred under its slot: whole pixels apart, the first on the pixel grid.
local function Pips(b, ranks)
	local px = PixelUtil.GetPixelToUIUnitFactor() / b:GetEffectiveScale()
	local w, g = UI.BoxPixels(b, M.pip), UI.BoxPixels(b, M.pipGap)
	local total = ranks * w + (ranks - 1) * g
	for i = 1, ranks do
		local pip = Pip(b, i)
		UI.BoxFit(pip.face, M.pip, M.pipH)
		pip.back:SetSize(w + 2 * px, UI.BoxPixels(b, M.pipH) + 2 * px)
		pip.back:ClearAllPoints()
		if i == 1 then
			pip.back:SetPoint("TOPLEFT", b, "TOPLEFT", (M.slot - total) / 2 - px, -(M.slot + M.pipDown) + px)
		else
			pip.back:SetPoint("LEFT", b.pips[i - 1].back, "RIGHT", g - 2 * px, 0)
		end
		pip.face:ClearAllPoints()
		pip.face:SetPoint("TOPLEFT", pip.back, "TOPLEFT", px, -px)
		pip.back:Show()
		pip.face:Show()
	end
	for i = ranks + 1, #b.pips do
		b.pips[i].back:Hide()
		b.pips[i].face:Hide()
	end
end

local function Card(i)
	local card = cards[i]
	if card then return card end
	card = CreateFrame("Frame", nil, box)
	card.art = card:CreateTexture(nil, "BACKGROUND", nil, 1)
	card.art:SetAllPoints()
	card.burns = {}
	for j, burn in ipairs(BURNS) do
		local t = Fill(card, "BACKGROUND", 2)
		local side, size, alpha = burn[1], burn[2], burn[3]
		if side == "TOP" or side == "BOTTOM" then
			t:SetPoint(side .. "LEFT")
			t:SetPoint(side .. "RIGHT")
			t:SetHeight(size)
		else
			t:SetPoint("TOP" .. side)
			t:SetPoint("BOTTOM" .. side)
			t:SetWidth(size)
		end
		card.burns[j] = { t = t, side = side, alpha = alpha }
	end
	card.rim = card:CreateTexture(nil, "BORDER")
	card.rim:SetTexture(UI.EDGE)
	card.rim:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
	card.rim:SetPoint("TOPLEFT", -1, 1)
	card.rim:SetPoint("BOTTOMRIGHT", 1, -1)

	-- The head: the tree's icon, its name, the points in it, a line under them.
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(M.icon, M.icon)
	card.icon:SetPoint("TOPLEFT", 12, -10)
	card.icon:SetTexCoord(unpack(ICON))
	card.slot = Slot.New(card, { to = card.icon, icon = card.icon, hover = false })
	card.name = Text(card, UI.TitleFont(18))
	card.points = Text(card, UI.TitleFont(26))
	card.points:SetPoint("RIGHT", card, "TOPRIGHT", -14, -(10 + M.icon / 2))
	-- Under the name while a row is still shut: a lock and the points it opens at.
	card.lock = card:CreateTexture(nil, "ARTWORK")
	card.lock:SetTexture(Skin.GLYPH.lock)
	UI.GlyphFit(card.lock, 10)
	card.lock:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 9, 2)
	card.gate = Text(card, UI.TextFont(11))
	card.gate:SetPoint("LEFT", card.lock, "RIGHT", 4, 0)
	card.line = Fill(card, "ARTWORK")
	card.line:SetHeight(1)
	card.line:SetPoint("TOPLEFT", 12, -M.crest)
	card.line:SetPoint("TOPRIGHT", -12, -M.crest)

	-- The veil over the rows still shut, from a hairline.
	card.veil = Fill(card, "BORDER", 3)
	card.frontier = Fill(card, "ARTWORK", 3)
	for _, t in ipairs({ card.line, card.frontier }) do
		t:SetSnapToPixelGrid(true)
		t:SetTexelSnappingBias(0)
	end
	card.arrows = {}
	cards[i] = card
	return card
end

-- An arrow: a stroke, and a caret for its head (pointing down as drawn).
local function Arrow(card, i)
	local a = card.arrows[i]
	if a then return a end
	a = { line = Fill(card, "ARTWORK", 4), head = card:CreateTexture(nil, "ARTWORK", nil, 5) }
	a.head:SetTexture(Skin.GLYPH.caret)
	UI.GlyphFit(a.head, 10)
	a.bend = Fill(card, "ARTWORK", 4)
	for _, t in ipairs({ a.line, a.bend }) do
		t:SetSnapToPixelGrid(true)
		t:SetTexelSnappingBias(0)
	end
	card.arrows[i] = a
	return a
end

local function Build()
	box = UI.Window({
		id = "shyskin.talents", name = "ShySkinTalents", title = TALENTS,
		width = 729, height = 507,
		point = { "CENTER", "CENTER", 0, 30 },
		shown = function() return open end,
		onClose = function() open = false end,
		head = { size = "window", title = TALENTS },
	})
	local head = box.head
	-- The class's icon before the title.
	head.class = head:CreateTexture(nil, "ARTWORK")
	head.class:SetSize(HEAD.icon, HEAD.icon)
	head.class:SetPoint("LEFT", head, "TOPLEFT", HEAD.pad, -head.mid)
	head.class:SetTexCoord(unpack(ICON))
	if head.title then
		head.title:ClearAllPoints()
		head.title:SetPoint("LEFT", head.class, "RIGHT", 6, 0)
	end
	-- Dual spec: Primary and Secondary on the strip's accent line, after the title.
	box.specs = UI.Tabs(head, { DUAL_SPEC_PRIMARY or "Primary", DUAL_SPEC_SECONDARY or "Secondary" }, function(i)
		local active = C_SpecializationInfo.GetActiveSpecGroup()
		local want = i ~= active and i or nil
		if want == view then return end
		view = want
		if open then Lay() end
	end, nil, 13, box, { tall = HEAD.line - 2, mid = head.mid - 2 })
	local after = HEAD.pad + HEAD.icon + 6 + (head.title and math.ceil(head.title:GetStringWidth()) or 0) + 20
	box.specs:SetPoint("BOTTOMLEFT", head, "TOPLEFT", after, -HEAD.line)

	-- The foot.
	local foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", M.margin, 4)
	foot:SetPoint("BOTTOMRIGHT", -M.margin, 4)
	foot:SetHeight(M.foot - 4)
	box.foot = foot
	foot.label = Text(foot, UI.TitleFont(13))
	foot.label:SetPoint("LEFT", 4, 0)
	foot.label:SetText("Points left")
	foot.plate = CreateFrame("Frame", nil, foot)
	foot.plate:SetSize(28, 22)
	foot.plate:SetPoint("LEFT", foot.label, "RIGHT", 7, 0)
	UI.Skin(foot.plate, C.bg, C.border)
	foot.left = Text(foot.plate, UI.TitleFont(16))
	foot.left:SetPoint("CENTER", 0, 0)
	foot.apply = UI.Button(foot, "Apply changes", 150, function()
		if not data then return end
		if not data.active then
			C_SpecializationInfo.SetActiveSpecGroup(data.group)
			return
		end
		if C_ClassTalents.CommitConfig() then
			committing = GetTime()
			PlaySound(SOUNDKIT.UI_CLASS_TALENT_APPLY_CHANGES)
			C_Timer.After(6, function()
				if committing and GetTime() - committing >= 5.9 then committing = nil; Soon() end
			end)
		end
		Soon()
	end)
	foot.apply:SetHeight(22)
	foot.apply:SetPoint("CENTER", foot, "CENTER", 0, 0)
	foot.undo = UI.Button(foot, "Undo", 64, function()
		if data and data.staged then C_Traits.RollbackConfig(data.config) end
		Soon()
	end)
	foot.undo:SetHeight(22)
	foot.undo:SetPoint("RIGHT", foot.apply, "LEFT", -6, 0)
	foot.reset = UI.Button(foot, RESET or "Reset", 70, function() end)
	foot.reset:SetHeight(22)
	foot.reset:SetPoint("RIGHT", foot, "RIGHT", -4, 0)
	UI.Twice(foot.reset, function()
		if data and data.currency then C_Traits.ResetTreeByCurrency(data.config, data.tree, data.currency) end
		Soon()
	end)
	UI.Help(foot.reset, RESET or "Reset", "Takes back every point in every tree. Nothing changes until you apply it.")

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_TREE_CHANGED",
		"ACTIVE_COMBAT_CONFIG_CHANGED", "CONFIG_COMMIT_FAILED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP",
		"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "TRAIT_CONFIG_UPDATED" or event == "CONFIG_COMMIT_FAILED" or event == "ACTIVE_COMBAT_CONFIG_CHANGED" then committing = nil end
		if open then Soon() end
	end)
	Shy:On("SHY_THEME", function() if open then Soon() end end)
	-- ShyQuest's leveling build picked again.
	Shy:On("SHY_BUILD", function() if open then Soon() end end)
end

---------------------------------------------------------------------------
-- Laying it out
---------------------------------------------------------------------------

-- The class's painting, three trees side by side: tree k of n cut to a card w by h.
local function Paint(card, k, n, w, h)
	local _, class = UnitClass("player")
	local info = class and C_Texture.GetAtlasInfo("talent-background-" .. class:lower())
	if not info or not info.file then
		card.art:Hide()
		return
	end
	local l, r = info.leftTexCoord, info.rightTexCoord
	local part = (r - l) / n
	local keep = math.min(1, (w / h) / ((info.width / n) / info.height))
	local cut = (1 - keep) / 2
	card.art:SetTexture(info.file)
	card.art:SetTexCoord(l + part * (k - 1 + cut), l + part * (k - cut), info.topTexCoord, info.bottomTexCoord)
	card.art:SetVertexColor(0.86, 0.86, 0.86)
	card.art:SetAlpha(0.8)
	card.art:Show()
end

local function Burns(card)
	local p = C.panel
	for _, burn in ipairs(card.burns) do
		local solid, clear = CreateColor(p[1], p[2], p[3], burn.alpha), CreateColor(p[1], p[2], p[3], 0)
		local side = burn.side
		if side == "TOP" then burn.t:SetGradient("VERTICAL", clear, solid)
		elseif side == "BOTTOM" then burn.t:SetGradient("VERTICAL", solid, clear)
		elseif side == "LEFT" then burn.t:SetGradient("HORIZONTAL", solid, clear)
		else burn.t:SetGradient("HORIZONTAL", clear, solid) end
	end
	card.rim:SetVertexColor(SC.edge[1], SC.edge[2], SC.edge[3], 0.75)
end

local function RowY(row) return M.crest + M.first + (row - 1) * M.row end
local function ColX(col) return M.pad + col * M.col end

-- The line under a tree's name: while a row is still shut, a lock and the points it opens at; on the leveling
-- build's tree, its name. The rows still shut lie under a veil from a hairline.
local function Rows(card, tab)
	local shut = tab.gate ~= nil
	local build = plan and plan.group == tab.group and plan.name or nil
	local sub = shut or build ~= nil
	card.name:ClearAllPoints()
	if sub then
		card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 9, 1)
	else
		card.name:SetPoint("LEFT", card.icon, "RIGHT", 9, 0)
	end
	card.lock:SetShown(shut)
	card.gate:SetShown(sub)
	card.gate:ClearAllPoints()
	if shut then
		card.gate:SetPoint("LEFT", card.lock, "RIGHT", 4, 0)
	else
		card.gate:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 9, 1)
	end
	-- "Row 3 at 10 points", short of its last word beside the build's name.
	local words = shut and ("Row %d at %d%s"):format(tab.gate.row, tab.gate.need, build and "" or " points") or ""
	if build then
		words = words .. (shut and "  \194\183  " or "") .. UI.Wrap(C.hot, build)
	end
	card.gate:SetText(words)
	Theme.Tint(card.lock, C.dim)
	UI.Ink(card.gate, C.dim)
	card.veil:SetShown(shut)
	card.frontier:SetShown(shut)
	if not shut then return end
	local y = RowY(tab.gate.row) - 7
	local p = C.panel
	card.veil:ClearAllPoints()
	card.veil:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
	card.veil:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
	card.veil:SetGradient("VERTICAL", CreateColor(p[1], p[2], p[3], 0.62), CreateColor(p[1], p[2], p[3], 0.4))
	card.frontier:ClearAllPoints()
	card.frontier:SetHeight(UI.BoxPixels(card, 1))
	card.frontier:SetPoint("TOPLEFT", 12, -y)
	card.frontier:SetPoint("TOPRIGHT", -12, -y)
	Theme.Paint(card.frontier, SC.metal or C.dim, 0.35)
end

-- The arrows of one tree: from each talent to the ones that need it.
local function Arrows(card, tab)
	local used = 0
	local thick = UI.BoxPixels(card, 2)   -- a stroke in whole screen pixels
	for _, node in ipairs(tab.nodes) do
		for _, edge in ipairs(node.info.visibleEdges or {}) do
			local to = data.byNode[edge.targetNode]
			if to and to.tab == tab then
				used = used + 1
				local a = Arrow(card, used)
				local lit = edge.isActive == true or node.ranks >= node.max
				local x0, y0 = ColX(node.col) + M.slot / 2, RowY(node.row)
				local x1, y1 = ColX(to.col) + M.slot / 2, RowY(to.row)
				a.line:ClearAllPoints()
				a.bend:Hide()
				if to.col == node.col then
					-- Down the column, from under the talent's pips to its head over the next.
					local from, till = y0 + M.slot + M.pipDown + M.pipH + 2, y1 - 9
					a.line:SetSize(thick, math.max(1, till - from))
					a.line:SetPoint("TOP", card, "TOPLEFT", x0, -from)
					a.head:SetRotation(0)
					a.head:ClearAllPoints()
					a.head:SetPoint("TOP", card, "TOPLEFT", x0, -(till - 2))
				elseif to.row == node.row then
					-- Across the row.
					local right = x1 > x0
					local from = right and ColX(node.col) + M.slot + 2 or ColX(node.col) - 2
					local till = right and ColX(to.col) - 9 or ColX(to.col) + M.slot + 9
					a.line:SetSize(math.max(1, math.abs(till - from)), thick)
					a.line:SetPoint("LEFT", card, "TOPLEFT", math.min(from, till), -(y0 + M.slot / 2))
					a.head:SetRotation(right and math.pi / 2 or -math.pi / 2)
					a.head:ClearAllPoints()
					a.head:SetPoint("CENTER", card, "TOPLEFT", right and till + 3 or till - 3, -(y0 + M.slot / 2))
				else
					-- Across, then down to it.
					local right = x1 > x0
					local from = right and ColX(node.col) + M.slot + 2 or ColX(node.col) - 2
					a.line:SetSize(math.max(1, math.abs(x1 - from)), thick)
					a.line:SetPoint("LEFT", card, "TOPLEFT", math.min(from, x1), -(y0 + M.slot / 2))
					local till = y1 - 9
					a.bend:ClearAllPoints()
					a.bend:SetSize(thick, math.max(1, till - (y0 + M.slot / 2)))
					a.bend:SetPoint("TOP", card, "TOPLEFT", x1, -(y0 + M.slot / 2))
					a.bend:Show()
					a.head:SetRotation(0)
					a.head:ClearAllPoints()
					a.head:SetPoint("TOP", card, "TOPLEFT", x1, -(till - 2))
				end
				for _, t in ipairs({ a.line, a.bend }) do
					if lit then Theme.Paint(t, Theme.Accent) else Theme.Paint(t, C.dim, 0.75) end
				end
				if lit then Theme.Tint(a.head, Theme.Accent) else Theme.Tint(a.head, C.dim) end
				a.line:Show()
				a.head:Show()
			end
		end
	end
	for i = used + 1, #card.arrows do
		local a = card.arrows[i]
		a.line:Hide()
		a.head:Hide()
		a.bend:Hide()
	end
end

-- One talent as it stands.
local function Dress(b, node)
	local _, icon = About(node)
	b.icon:SetTexture(icon or 134400)
	local full = node.ranks >= node.max
	local learn = CanLearn(node)
	local reach = node.ranks > 0 or (node.info.isAvailable == true and node.info.meetsEdgeRequirements ~= false
		and not (node.tab.gate and node.row >= node.tab.gate.row))
	b.icon:SetDesaturated(not reach)
	b.icon:SetVertexColor(reach and 1 or 0.55, reach and 1 or 0.55, reach and 1 or 0.55)
	if full then
		b.slot:Mark(Theme.Accent())
	elseif learn then
		b.slot:Mark(C.good[1], C.good[2], C.good[3])
	else
		b.slot:Mark()
	end
	-- A talent you hold shows in full color; one you could only take, or can't, is dimmed.
	b.slot:Empty(node.ranks == 0)
	Pips(b, node.max)
	for i = 1, node.max do
		local pip = b.pips[i]
		if i <= node.ranks - node.staged then
			Theme.Paint(pip.face, Theme.Accent)
		elseif i <= node.ranks then
			Theme.Paint(pip.face, C.alert)
		elseif learn then
			Theme.Paint(pip.face, C.good, 0.55)
		else
			Theme.Paint(pip.face, C.dim, reach and 0.45 or 0.3)
		end
	end
end

-- The foot: points, Undo, Apply (or Activate), Reset.
local function Foot()
	local foot = box.foot
	local left = data.active and data.left or 0
	foot.left:SetText(left)
	foot.plate:SetWidth(math.max(28, math.ceil(foot.left:GetStringWidth()) + 14))
	UI.Ink(foot.left, left > 0 and C.good or C.dim)
	UI.SetBorder(foot.plate, left > 0 and C.good or C.border)
	UI.Ink(foot.label, C.dim)
	foot.label:SetShown(data.active)
	foot.plate:SetShown(data.active)
	local apply = foot.apply
	if not data.active then
		apply:SetLabel("Activate")
		apply:SetTone(nil)
		local fight = InCombatLockdown()
		apply:SetUsable(not fight, "Not in a fight.")
		foot.undo:Hide()
		foot.reset:Hide()
		return
	end
	local can, add, why = C_ClassTalents.CanChangeTalents()
	local waiting = data.staged and not committing
	apply:SetLabel(committing and "Applying..." or "Apply changes")
	apply:SetTone(waiting and C.alert or nil)
	apply:SetUsable(waiting and (can or add) and true or false, waiting and why or nil)
	foot.undo:Show()
	foot.undo:SetUsable(waiting and true or false)
	local any = false
	for _, tab in ipairs(data.tabs) do any = any or tab.spent > 0 end
	foot.reset:SetShown(data.canRefund)
	foot.reset:SetUsable(any and not committing)
end

Lay = function()
	if not box then return end
	local d = Read()
	data = d
	if not d then return end
	for _, node in ipairs(d.nodes) do node.config = d.config end
	-- ShyQuest's leveling build, when it reads this same tree.
	plan = nil
	local quest = Shy.addons.Quest
	local given = quest and quest.TalentPlan and quest:TalentPlan()
	if given and d.active and given.config == d.config and given.tree == d.tree then
		plan = { byNode = {}, counts = {}, group = given.group, name = given.name, unspent = given.unspent }
		for turn, step in ipairs(given.nodes or {}) do
			plan.byNode[step.node], plan.counts[step.node] = turn, step.count
		end
	end
	local n = #d.tabs
	local cardW = M.pad + (d.cols - 1) * M.col + M.slot + M.right
	local cardH = RowY(d.rows) + M.slot + M.under
	local top = HEAD.line + UI.LINE + M.below
	local width = 2 * M.margin + n * cardW + (n - 1) * M.gap
	local height = top + cardH + M.below + M.foot
	if math.abs(box:GetWidth() - width) > 0.5 or math.abs(box:GetHeight() - height) > 0.5 then Shy.HUD.Resize(box, width, height) end

	local _, class = UnitClass("player")
	box.head.class:SetTexture(class and ("Interface\\Icons\\ClassIcon_" .. class:sub(1, 1) .. class:sub(2):lower()) or nil)
	-- The tabs, only with a second spec to switch to.
	local dual = (GetNumSpecGroups and GetNumSpecGroups() or 1) > 1
	box.specs:SetShown(dual)
	if dual then box.specs:Select(d.group) end

	local seen = {}
	for k, tab in ipairs(d.tabs) do
		local card = Card(k)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", box, "TOPLEFT", M.margin + (k - 1) * (cardW + M.gap), -top)
		card:SetSize(cardW, cardH)
		card:Show()
		Paint(card, k, n, cardW, cardH)
		Burns(card)
		card.icon:SetTexture(tab.icon)
		card.name:SetText(tab.name)
		UI.Ink(card.name, C.head)
		card.points:SetText(tab.spent)
		if tab.spent > 0 then Theme.Ink(card.points, Theme.Accent) else Theme.Ink(card.points, C.dim, 0.45) end
		card.line:SetHeight(UI.BoxPixels(card, 1))
		if tab.spent > 0 then
			Theme.Paint(card.line, Theme.Accent)
			card.line:SetAlpha(0.8)
		else
			Theme.Paint(card.line, C.border)
			card.line:SetAlpha(1)
		end
		Rows(card, tab)
		Arrows(card, tab)
		for _, node in ipairs(tab.nodes) do
			local b = buttons[node.id]
			if not b or b:GetParent() ~= card then
				if b then b:Hide() end
				b = Talent(card)
				buttons[node.id] = b
			end
			b.node = node
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", card, "TOPLEFT", ColX(node.col), -RowY(node.row))
			b:SetFrameLevel(card:GetFrameLevel() + 4)
			Dress(b, node)
			b:Show()
			seen[node.id] = true
			if Shy.Hover.Owner() == b then Tip(b) end
		end
	end
	for k = n + 1, #cards do cards[k]:Hide() end
	for id, b in pairs(buttons) do
		if not seen[id] then
			b:Hide()
			b.node = nil
		end
	end
	Foot()
	Shy:Fire("SHY_TALENTS")
end

---------------------------------------------------------------------------
-- Opening
---------------------------------------------------------------------------

function TW.IsOpen() return open end

function TW.Open()
	if not box then Build() end
	view = nil
	open = true
	Lay()
	Shy.HUD.Update(box)
	PlaySound(SOUNDKIT.UI_CLASS_TALENT_OPEN_WINDOW)
end

function TW.Close()
	if not open then return end
	open = false
	if box then Shy.HUD.Update(box) end
	PlaySound(SOUNDKIT.UI_CLASS_TALENT_CLOSE_WINDOW)
end

function TW.Toggle()
	if open then TW.Close() else TW.Open() end
end

function TW.Button(node)
	local b = open and buttons[node]
	return b and b:IsShown() and b or nil
end

function TW.Config() return data and data.config end

-- Whether the window stands in for the game's (the module on): ShyQuest's card opens it then.
function TW.IsOn() return on end

-- The key the game's talent binding is on, clicked by our override bindings.
local key = CreateFrame("Button", "ShySkinTalentsKey", UIParent)
key:RegisterForClicks("AnyDown")
key:SetScript("OnClick", function() TW.Toggle() end)

local function MicroTip(cover)
	local bound = GetBindingKey("TOGGLETALENTS")
	UI.Tip(cover, TALENTS, bound and ("Key: " .. GetBindingText(bound)) or nil, { side = "TOP" })
end

function TW.On(want)
	want = want and true or false
	if want == on then return end
	on = want
	if on then
		ns.Keys.Take("talents", { binding = "TOGGLETALENTS", button = "ShySkinTalentsKey", micro = TalentMicroButton, click = TW.Toggle, tip = MicroTip })
	else
		ns.Keys.Give("talents")
		TW.Close()
	end
end
