-- Our own talent window, in place of the game's while the "spells" module is on (Spellbook.lua switches it; with
-- "Game's talent window" on, the game's is its own instead: TalentBuild.lua):
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
-- the one you're not in shows its talents, with Activate where Apply stands. Your build (Shy.Build, ShyCore's: heard
-- again on SHY_BUILD) is read against the tree as shown, staged ranks and all: its tree named under the tree's own,
-- its next talents numbered on plates at their corners, the next one ringed (breathing while you have a point), the
-- ranks it still puts in each talent as faint pips of your color, a talent it never takes a little dimmer, and each
-- talent's turn in its hover.
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
	-- A talent as the game makes one (its square): a 40 button round a 36 icon, its points' text near its foot.
	-- Its frame's opening starts 4 in (its gold, then its black band): the points stand inside it, clear of both.
	node = 40, slot = 36, rankIn = 6,
	col = 48, row = 48,                 -- the pitch of the grid: closer than the game's 60, 8 between two frames
	glow = 61,                          -- the glow round a talent you can put a point in
	arrow = 6, reach = 24,              -- an arrow's thickness; its head's middle, back from the talent it points at
	pad = 16, right = 16,               -- a card's edges to its first and last columns
	crest = 54, first = 12, under = 16, -- a card's head; the head to the first row; the last row's foot to the card's
	gap = 8, margin = 10, below = 8,    -- between two cards; the window's sides to a card; under the header
	foot = 40, undo = 64, footGap = 6,  -- the window's foot; Undo's width, and between it and Apply
	icon = 34,                          -- a tree's icon
	stepLeast = 100,                    -- talents closer than this (in the game's units) stand in one column or row
	-- Your build: how many next talents are numbered, a turn's badge and its middle (in from the icon's corner)
	steps = 6, turn = 20, turnIn = 2,
}
local ICON = { 0.08, 0.92, 0.08, 0.92 }
-- The game's own talent art (its square set, Blizzard_TalentButtonArt), its arrows, and what its window plays.
local ART = {
	shadow = "talents-node-square-shadow", maxed = "talents-node-square-yellow", normal = "talents-node-square-yellow",
	selectable = "talents-node-square-green", disabled = "talents-node-square-gray", locked = "talents-node-square-locked",
	glow = "talents-node-square-greenglow", sheen = "talents-sheen-node", sheenMask = "talents-node-square-sheenmask",
	line = { on = "talents-arrow-line-yellow", off = "talents-arrow-line-gray", shut = "talents-arrow-line-locked" },
	head = { on = "talents-arrow-head-yellow", off = "talents-arrow-head-gray", shut = "talents-arrow-head-locked" },
	clouds = "talents-animations-clouds", particles = "talents-animations-particles", full = "talents-animations-mask-full",
	burst = "talents-animations-gridburst", filigree = "talents-animations-mask-filigree-activate",
	class = "talents-animations-class-",
}
-- Your build's next talent wears your color, as its numbered pin does: its frame, its glow and its points.
-- A state's sheen and hover strength, its points' color (the game's: ClassTalentUtil, TalentButtonUtil).
local STATE = {
	maxed = { sheen = 1, hover = 1 }, normal = { sheen = 1, hover = 1 }, selectable = { sheen = 0, hover = 1 },
	disabled = { sheen = 1, hover = 0.4, dim = 0.25 }, locked = { sheen = 0, hover = 0.4, dim = 0.7 },
}
-- The game's effects as points are applied (166 while they go, 150 once they have, a moment after), and its sheen's
-- round: a sweep every 22 seconds, every talent's in step.
local FX = { working = 166, done = 150, after = 1.2, sheen = { delay = 5, sweep = 6.5, rest = 10.5, reach = 150 } }
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
local plan                  -- your build, read against this tree (Planned)
local PLACE = { "next", "2nd", "3rd", "4th", "5th", "6th" }
local TURN = { mask = Shy.MEDIA .. "TalentIconMask" }

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

-- Your build against the tree as this window read it, staged ranks and all, straight from ShyCore (Shy.Build): the
-- one you picked, else the one your talents fit best. nil for a class with none, another tree, or the other spec
-- shown. { build, name, group, want, over, turns, steps, off, strayed, ended }:
--   want[node]   the ranks the build puts in a talent, all told
--   over[node]   the ranks you hold there past it (crimson on the window, and said in its hover)
--   steps        what is still to buy, in the build's order: { node, count, rank }, a talent's ranks in a row one step
--   turns[node]  a talent's first step
--   off          points you have outside the build; strayed past Shy.Build.STRAYED (nothing is numbered then)
local function Planned(d)
	local Build = Shy.Build
	local spec = Build and Build.Class()
	local build = spec and spec.tree == d.tree and d.active and Build.Followed()
	if not (build and build.order) then return nil end
	local p = { build = build, name = build.name, group = spec.tabs[build.tab], want = {}, over = {}, turns = {}, steps = {}, off = 0 }
	for _, node in ipairs(build.order) do p.want[node] = (p.want[node] or 0) + 1 end
	for _, node in ipairs(d.nodes) do
		local extra = node.ranks - (p.want[node.id] or 0)
		if extra > 0 then p.off, p.over[node.id] = p.off + extra, extra end
	end
	local seen = {}
	for _, id in ipairs(build.order) do
		seen[id] = (seen[id] or 0) + 1
		local node = d.byNode[id]   -- (a talent this window doesn't lay is passed over)
		if node and seen[id] > node.ranks then
			local last = p.steps[#p.steps]
			if last and last.node == id then
				last.count = last.count + 1
			else
				p.steps[#p.steps + 1] = { node = id, count = 1, rank = node.ranks + 1 }
				p.turns[id] = p.turns[id] or #p.steps
			end
		end
	end
	p.strayed = p.off > Build.STRAYED
	p.ended = #p.steps == 0
	return p
end

-- A talent's turn in your build while it is numbered (its first step, among the next few), else nil.
local function Turn(node)
	local turn = plan and not plan.strayed and plan.turns[node.id]
	return turn and turn <= M.steps and turn or nil
end

local Tip                   -- a talent's hover (set below)
local asked = {}            -- talent spell -> its words have been asked for, once

-- A talent's words come with its spell's data, which the client loads on demand: the first hover of a talent
-- reads them empty. They are asked for once, and the hover said again as they land, so the first hover fills
-- itself in instead of waiting for the next one.
local function Ask(spell)
	if asked[spell] then return end
	asked[spell] = true
	local s = Spell:CreateFromSpellID(spell)
	-- Its data is here and the words are still empty: the talent has none at that rank, nothing to wait for.
	if s:IsSpellDataCached() then return end
	s:ContinueOnSpellLoad(function()
		local b = open and Shy.Hover.Owner()
		if b and b.node and buttons[b.node.id] == b then Tip(b) end
	end)
end

-- A talent's name, picture and its words at a rank. No words at that rank: nil, never the empty string the
-- game answers with while the spell's data is still coming.
local function About(node, rank)
	local n = node.info
	local entry = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
	local info = entry and C_Traits.GetEntryInfo(node.config or data.config, entry)
	local def = info and info.definitionID and C_Traits.GetDefinitionInfo(info.definitionID)
	local spell = def and def.spellID
	local name = def and (def.overrideName ~= "" and def.overrideName) or (spell and C_Spell.GetSpellName(spell)) or ""
	local icon = def and def.overrideIcon and def.overrideIcon ~= 0 and def.overrideIcon or (spell and C_Spell.GetSpellTexture(spell))
	local words = entry and rank and rank > 0 and C_Traits.GetTraitDescription(entry, rank) or nil
	if words == "" then words = nil end
	if not words and spell and rank and rank > 0 then Ask(spell) end
	return name, icon, words, entry
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function Text(parent, font, layer)
	return UI.Words(parent, font, nil, { layer = layer, justify = "CENTER" })
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

-- Where a talent's hover stands: off the talent's own top right corner, up and away from the grid, the place
-- every hover over a piece with a picture takes (UI.GameTipAt). Near the screen's right edge it turns to the
-- top left corner instead, so it is never pushed back over the talents.
local CORNER_ROOM = 300   -- the room a card wants past the corner it stands on
local function Corner(button)
	local right = (button:GetRight() or 0) * button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if (UIParent:GetWidth() or 0) - right < CORNER_ROOM then
		return { "BOTTOMRIGHT", button, "TOPLEFT", -2, 2 }
	end
	return { "BOTTOMLEFT", button, "TOPRIGHT", 2, 2 }
end

function Tip(button)
	local node = button.node
	if not node or not data then return end
	local name, icon, now = About(node, math.max(node.ranks, 1))
	local _, _, next = About(node, node.ranks + 1)
	local key = { { text = ("Rank %d of %d"):format(node.ranks, node.max), color = C.dim } }
	if node.staged > 0 then key[2] = { text = ("  \194\183  %d waiting for Apply"):format(node.staged), color = C.alert } end
	local body = {}
	-- What it does reads in full, held or not: the rank line above already says which it is.
	if now then body[#body + 1] = { text = now } end
	if node.ranks > 0 and node.ranks < node.max and next then
		body[#body + 1] = { rows = { { text = next } }, title = "Next rank" }
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
	-- Your build: its turn while numbered, and the ranks it puts here.
	local want = plan and plan.want[node.id]
	local over = plan and not plan.strayed and plan.over[node.id] or 0
	if over > 0 then
		for _, line in ipairs(Shy.Build.OverSays(plan.name, want or 0, node.ranks, data.canRefund)) do body[#body + 1] = line end
	elseif want then
		local turn = Turn(node)
		local step = turn and plan.steps[turn]
		local say = turn and ("%s: %s"):format(plan.name, PLACE[turn] or turn) or plan.name
		if step and step.count > 1 then say = ("%s, %d points"):format(say, step.count) end
		if node.ranks < want then
			say = ("%s  \194\183  %d of %d ranks"):format(say, node.ranks, want)
		else
			say = ("%s  \194\183  done"):format(say)
		end
		body[#body + 1] = { text = say, color = C.hot }
	elseif plan and not plan.strayed and node.ranks == 0 then
		body[#body + 1] = { text = ("Not in %s"):format(plan.name), color = C.dim }
	end
	local hints = {}
	if CanLearn(node) then hints[#hints + 1] = { "left", "Learn" } end
	if CanTakeBack(node) then hints[#hints + 1] = { "right", "Take back" } end
	-- On the talent itself (Corner). It takes no mouse, so the talents it lies over are still hovered and
	-- clicked straight through it, and it leaves the moment the cursor does (the button's OnLeave).
	Shy.Hover.Show(button, { card = true, about = "talent:" .. node.id .. ":" .. node.ranks, icon = icon, title = name,
		kind = node.tab.name, key = key, body = body, hints = hints }, { keep = false, at = Corner(button) })
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

-- The sheen's round started where every other talent's is, so they all sweep together.
local function Sheen(b)
	if b.sheenAnim:IsPlaying() then return end
	local s = FX.sheen
	b.sheenAnim:Play(false, GetTime() % (s.delay + s.sweep + s.rest))
end

-- A talent as the game makes one: its shadow, its picture, a dark wash while out of reach, the frame of its state
-- (and the same lit while the mouse is on it), the sheen that sweeps the frame, the soft green glow while a point
-- can go in, its points as the game writes them.
local function Talent(card)
	local b = CreateFrame("Button", nil, card)
	b:SetSize(M.node, M.node)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.shadow = b:CreateTexture(nil, "BACKGROUND")
	b.shadow:SetAtlas(ART.shadow, true)
	b.shadow:SetPoint("CENTER")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(M.slot, M.slot)
	b.icon:SetPoint("CENTER")
	b.icon:SetTexCoord(unpack(ICON))
	b.dim = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.dim:SetAllPoints(b.icon)
	b.dim:SetColorTexture(0, 0, 0, 1)
	-- (The picture's corners cut as the frame cuts its own, so none shows past it.)
	b.iconMask = b:CreateMaskTexture()
	b.iconMask:SetTexture(TURN.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	b.iconMask:SetAllPoints(b.icon)
	b.icon:AddMaskTexture(b.iconMask)
	b.dim:AddMaskTexture(b.iconMask)
	b.border = b:CreateTexture(nil, "ARTWORK", nil, 2)
	b.border:SetPoint("CENTER")
	b.lit = b:CreateTexture(nil, "ARTWORK", nil, 3)
	b.lit:SetPoint("CENTER")
	b.lit:SetBlendMode("ADD")
	b.lit:Hide()
	b.sheen = b:CreateTexture(nil, "ARTWORK", nil, 4)
	b.sheen:SetAtlas(ART.sheen, true)
	b.sheen:SetBlendMode("ADD")
	b.sheen:SetPoint("RIGHT", b, "LEFT")
	b.sheenMask = b:CreateMaskTexture()
	b.sheenMask:SetAtlas(ART.sheenMask, true, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	b.sheenMask:SetPoint("CENTER")
	b.sheen:AddMaskTexture(b.sheenMask)
	b.sheenAnim = b.sheen:CreateAnimationGroup()
	b.sheenAnim:SetLooping("REPEAT")
	local sweep = b.sheenAnim:CreateAnimation("Translation")
	sweep:SetOffset(FX.sheen.reach, 0)
	sweep:SetStartDelay(FX.sheen.delay)
	sweep:SetDuration(FX.sheen.sweep)
	sweep:SetEndDelay(FX.sheen.rest)
	b.glow = b:CreateTexture(nil, "OVERLAY")
	b.glow:SetAtlas(ART.glow)
	b.glow:SetSize(M.glow, M.glow)
	b.glow:SetPoint("CENTER")
	b.glow:SetBlendMode("ADD")
	b.glow:SetAlpha(0)
	b.glow:Hide()
	b.glowAnim = b.glow:CreateAnimationGroup()
	b.glowAnim:SetLooping("REPEAT")
	b.glowAnim:SetToFinalAlpha(true)
	local rise = b.glowAnim:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(0.15)
	rise:SetDuration(1)
	rise:SetOrder(1)
	rise:SetSmoothing("OUT")
	local fall = b.glowAnim:CreateAnimation("Alpha")
	fall:SetFromAlpha(0.15)
	fall:SetToAlpha(0)
	fall:SetDuration(1)
	fall:SetOrder(2)
	fall:SetSmoothing("IN")
	-- (Its points as every count on the family's icons is written: the rounded face, a thin outline, sized for it.)
	b.rank = b:CreateFontString(nil, "OVERLAY")
	b.rank:SetFont(Shy.FONT_ROUNDED, Slot.CountSize(M.slot), "OUTLINE")
	b.rank:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -M.rankIn, M.rankIn)
	b.rank:SetJustifyH("RIGHT")
	-- Its turn in your build: the family's numbered pin (UI.NumberMark) on the slot's top left corner, the next one lit
	-- in your color.
	b.turn = UI.NumberMark(b, M.turn)
	b.turn:SetPoint("CENTER", b.icon, "TOPLEFT", M.turnIn, -M.turnIn)
	b.turn:SetFrameLevel(b:GetFrameLevel() + 3)
	b.turn:Hide()
	b:SetScript("OnClick", Click)
	b:SetScript("OnEnter", function(self)
		self.lit:Show()
		Tip(self)
	end)
	-- Gone at once, not after the grace a row's hover gets: nothing of it is ever between you and the next talent.
	b:SetScript("OnLeave", function(self)
		self.lit:Hide()
		Shy.Hover.Hide(self, true)
	end)
	b:SetScript("OnShow", Sheen)
	b:SetScript("OnHide", function(self) self.sheenAnim:Stop() end)
	return b
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

-- An arrow as the game draws one: a line in its art from the middle of one talent, and its head (pointing down as
-- drawn) just off the next. A bend for one that turns a corner.
local function Arrow(card, i)
	local a = card.arrows[i]
	if a then return a end
	a = { line = card:CreateLine(nil, "ARTWORK", nil, 4), bend = card:CreateLine(nil, "ARTWORK", nil, 4),
		head = card:CreateTexture(nil, "ARTWORK", nil, 5) }
	a.line:SetThickness(M.arrow)
	a.bend:SetThickness(M.arrow)
	card.arrows[i] = a
	return a
end

---------------------------------------------------------------------------
-- The game's air over the trees, and what it plays as points are applied
---------------------------------------------------------------------------

-- An additive layer of the game's art over the trees, under the talents: two banks of cloud drifting across, two of
-- motes that rise and fade turning slowly, masked soft at the edges as the game masks them; and the burst the game's
-- window plays as points are applied (its grid flying out, your class's sigil flaring), held still till then.
local AIR = {
	clouds = 0.05, drift = 80, span = 1612,                -- the clouds' strength; a crossing's seconds; how far
	near = { alpha = 0.15, fade = 5, hold = 22, travel = 600, turn = 20 },
	far = { alpha = 0.14, fade = 5, hold = 31, travel = 200, turn = -20, w = 800, h = 473 },
	burst = { size = 320, grow = 20, from = 0.65, last = 1.4 },
}

local function Texture(f, atlas, level, sub, size)
	local t = f:CreateTexture(nil, level or "BACKGROUND", nil, sub)
	t:SetAtlas(atlas, size ~= false)
	t:SetBlendMode("ADD")
	t:SetSnapToPixelGrid(false)
	t:SetTexelSnappingBias(0)
	return t
end

local function Masked(f, atlas, ...)
	local mask = f:CreateMaskTexture()
	mask:SetAtlas(atlas, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(f)
	for i = 1, select("#", ...) do select(i, ...):AddMaskTexture(mask) end
	return mask
end

-- A crossing that starts over when done: from `from` across by `by`, in `seconds`.
local function Drift(t, from, by, seconds)
	local g = t:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local start = g:CreateAnimation("Translation")
	start:SetOffset(from, 0)
	start:SetDuration(0)
	start:SetOrder(1)
	local cross = g:CreateAnimation("Translation")
	cross:SetOffset(by, 0)
	cross:SetDuration(seconds)
	cross:SetOrder(2)
	return g
end

-- Motes: in over `fade`, held, out over `fade`, drifting and turning the while.
local function Motes(t, s)
	local g = Drift(t, s.travel / 2, -s.travel, s.hold + s.fade)
	local rise = g:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(s.alpha)
	rise:SetDuration(s.fade)
	rise:SetOrder(2)
	local fall = g:CreateAnimation("Alpha")
	fall:SetFromAlpha(s.alpha)
	fall:SetToAlpha(0)
	fall:SetStartDelay(s.hold)
	fall:SetDuration(s.fade)
	fall:SetOrder(2)
	local turn = g:CreateAnimation("Rotation")
	turn:SetDegrees(s.turn)
	turn:SetDuration(s.hold + s.fade)
	turn:SetOrder(2)
	return g
end

local function Air()
	local air = CreateFrame("Frame", nil, box)
	air:SetClipsChildren(true)
	air:EnableMouse(false)
	box.air = air
	air.clouds1 = Texture(air, ART.clouds, "BACKGROUND", 2)
	air.clouds1:SetPoint("TOPLEFT")
	air.clouds2 = Texture(air, ART.clouds, "BACKGROUND", 2)
	air.clouds2:SetPoint("TOPLEFT")
	for _, t in ipairs({ air.clouds1, air.clouds2 }) do t:SetAlpha(AIR.clouds) end
	air.near = Texture(air, ART.particles, "BACKGROUND", 2)
	air.near:SetPoint("CENTER")
	air.far = Texture(air, ART.particles, "BACKGROUND", 2, false)
	air.far:SetSize(AIR.far.w, AIR.far.h)
	air.far:SetTexCoord(1, 0, 1, 0)
	air.far:SetPoint("CENTER")
	for _, t in ipairs({ air.near, air.far }) do t:SetAlpha(0) end
	Masked(air, ART.full, air.clouds1, air.clouds2, air.near, air.far)
	air.loops = {
		Drift(air.clouds1, 0, -AIR.span, AIR.drift), Drift(air.clouds2, AIR.span, -AIR.span, AIR.drift),
		Motes(air.near, AIR.near), Motes(air.far, AIR.far),
	}

	-- The burst, as the game's: its grid grows out and fades, the class's sigil flares, two more of it swell and go.
	local b = AIR.burst
	air.grid = Texture(air, ART.burst, "BACKGROUND", 3, false)
	air.grid:SetSize(b.size, b.size)
	air.grid:SetPoint("CENTER")
	air.grid:SetAlpha(0)
	Masked(air, ART.filigree, air.grid)
	air.flash = {}
	local g = air.grid:CreateAnimationGroup()
	g:SetToFinalAlpha(true)
	local grow = g:CreateAnimation("Scale")
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(b.grow, b.grow)
	grow:SetDuration(b.last)
	grow:SetSmoothing("IN")
	local fade = g:CreateAnimation("Alpha")
	fade:SetFromAlpha(b.from)
	fade:SetToAlpha(0)
	fade:SetDuration(b.last)
	fade:SetSmoothing("IN")
	air.flash[1] = g
	-- (from, seconds, swell) for each of the sigil's four, as the game times them.
	air.sigils = {}
	for i, s in ipairs({ { 1, 1.2 }, { 1, 1.2 }, { 0.3, 0.3, 1.5 }, { 0.2, 0.5, 1.5 } }) do
		local t = Texture(air, ART.class .. "warrior", "BACKGROUND", 3)
		t:SetPoint("CENTER")
		t:SetAlpha(0)
		air.sigils[i] = t
		local sg = t:CreateAnimationGroup()
		sg:SetToFinalAlpha(true)
		local out = sg:CreateAnimation("Alpha")
		out:SetFromAlpha(s[1])
		out:SetToAlpha(0)
		out:SetDuration(s[2])
		out:SetSmoothing("OUT")
		if s[3] then
			local swell = sg:CreateAnimation("Scale")
			swell:SetScaleFrom(1, 1)
			swell:SetScaleTo(s[3], s[3])
			swell:SetDuration(s[2])
		end
		air.flash[#air.flash + 1] = sg
	end
	Masked(air, ART.full, air.sigils[3], air.sigils[4])

	-- The game's effects on the talents as they're applied, in a scene of its own over the trees.
	local fx = CreateFrame("ModelScene", nil, box, "ScriptAnimatedModelSceneTemplate")
	fx:EnableMouse(false)
	box.fx = fx
end

-- The air laid over the trees, your class's sigil in it, its drift going while the window is open.
local function LayAir(first, last)
	local air, fx = box.air, box.fx
	air:ClearAllPoints()
	air:SetPoint("TOPLEFT", first, "TOPLEFT")
	air:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
	air:SetFrameLevel(first:GetFrameLevel() + 1)
	fx:ClearAllPoints()
	fx:SetAllPoints(air)
	fx:SetFrameLevel(first:GetFrameLevel() + 20)
	local _, class = UnitClass("player")
	local sigil = class and ART.class .. class:lower()
	if sigil and C_Texture.GetAtlasInfo(sigil) then
		for _, t in ipairs(air.sigils) do t:SetAtlas(sigil, true) end
	end
	for _, g in ipairs(air.loops) do
		if not g:IsPlaying() then g:Play() end
	end
end

-- Points applied: each talent they went into plays the game's effect while they go; once they have, a moment later,
-- the game's second effect on each, its sound, and the burst over the trees.
local applying                  -- the talents whose points are being applied
local function Working(nodes)
	applying = nodes
	box.fx:ClearEffects()
	for _, id in ipairs(nodes) do
		local b = buttons[id]
		if b and b:IsVisible() then box.fx:AddEffect(FX.working, b, b, nil, nil, b:GetEffectiveScale() / box.fx:GetEffectiveScale()) end
	end
end

local function Applied()
	local nodes = applying
	applying = nil
	if not nodes then return end
	C_Timer.After(FX.after, function()
		if not (box and box:IsVisible()) then return end
		box.fx:ClearEffects()
		for _, id in ipairs(nodes) do
			local b = buttons[id]
			if b and b:IsVisible() then box.fx:AddEffect(FX.done, b, b, nil, nil, b:GetEffectiveScale() / box.fx:GetEffectiveScale()) end
		end
		for _, g in ipairs(box.air.flash) do g:Stop(); g:Play() end
		PlaySound(SOUNDKIT.UI_CLASS_TALENT_APPLY_COMPLETE)
	end)
end

local function Failed()
	applying = nil
	if box and box.fx then box.fx:ClearEffects() end
end

local function Build()
	box = UI.Window({
		id = "shyskin.talents", name = "ShySkinTalents", title = TALENTS,
		width = 729, height = 507,
		point = { "CENTER", "CENTER", 0, 30 },
		shown = function() return open end,
		onClose = function() open = false end,
		-- Dual spec: Primary and Secondary as the window's own tabs on its strip, after the title (UI.Head lays
		-- them, in its title's type and on the look's own middle).
		head = { size = "window", title = TALENTS, tabs = { { DUAL_SPEC_PRIMARY or "Primary", DUAL_SPEC_SECONDARY or "Secondary" },
			function(i)
				local active = C_SpecializationInfo.GetActiveSpecGroup()
				local want = i ~= active and i or nil
				if want == view then return end
				view = want
				if open then Lay() end
			end } },
	})
	box.specs = box.head.tabs

	-- The foot, on the body: clear of the look's work round the edge (UI.Body), as the cards are.
	local body = UI.Body(box)
	local foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", M.margin, 4)
	foot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -M.margin, 4)
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
		-- (The talents whose points wait, before they are applied and say so no more.)
		local waiting = {}
		for _, node in ipairs(data.nodes) do
			if node.staged > 0 then waiting[#waiting + 1] = node.id end
		end
		-- (Under way before the game is asked: it may say it's done before it answers.)
		committing = GetTime()
		Working(waiting)
		if not C_ClassTalents.CommitConfig() then
			committing = nil
			Failed()
		else
			PlaySound(SOUNDKIT.UI_CLASS_TALENT_APPLY_CHANGES)
			C_Timer.After(6, function()
				if committing and GetTime() - committing >= 5.9 then committing = nil; Soon() end
			end)
		end
		Soon()
	end)
	foot.apply:SetHeight(22)
	-- (Undo and Apply as one pair, its middle the foot's.)
	foot.apply:SetPoint("CENTER", foot, "CENTER", (M.undo + M.footGap) / 2, 0)
	foot.undo = UI.Button(foot, "Undo", M.undo, function()
		if data and data.staged then C_Traits.RollbackConfig(data.config) end
		Soon()
	end)
	foot.undo:SetHeight(22)
	foot.undo:SetPoint("RIGHT", foot.apply, "LEFT", -M.footGap, 0)
	foot.reset = UI.Button(foot, RESET or "Reset", 70, function() end)
	foot.reset:SetHeight(22)
	foot.reset:SetPoint("RIGHT", foot, "RIGHT", -4, 0)
	UI.Twice(foot.reset, function()
		if data and data.currency then C_Traits.ResetTreeByCurrency(data.config, data.tree, data.currency) end
		Soon()
	end)
	UI.Help(foot.reset, RESET or "Reset", function()
		local off = plan and not plan.strayed and plan.off or 0
		if off == 0 then return "Takes back every point in every tree. Nothing changes until you apply it." end
		return ("Takes back every point in every tree. %s in %s: they're the crimson ones. Nothing changes until you apply it.")
			:format(off == 1 and "One of yours isn't" or (off .. " of yours aren't"), plan.name)
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_TREE_CHANGED",
		"ACTIVE_COMBAT_CONFIG_CHANGED", "CONFIG_COMMIT_FAILED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP",
		"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if committing and event == "TRAIT_CONFIG_UPDATED" then Applied() end
		if event == "CONFIG_COMMIT_FAILED" then Failed() end
		if event == "TRAIT_CONFIG_UPDATED" or event == "CONFIG_COMMIT_FAILED" or event == "ACTIVE_COMBAT_CONFIG_CHANGED" then committing = nil end
		if open then Soon() end
	end)
	Shy:On("SHY_THEME", function() if open then Soon() end end)
	-- Another build picked, or the one your talents fit changed.
	Shy:On("SHY_BUILD", function() if open then Soon() end end)
	Air()
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
	-- (A build named as its tree is "Your build": the tree's name stands just over it.)
	local build = plan and plan.group == tab.group and (plan.name == tab.name and "Your build" or plan.name) or nil
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
-- The arrows of one tree: from each talent to the ones that need it, gold once the first is full, locked while the
-- next one's row is shut, grey otherwise (the game's own rule). Each runs from the first's middle; its head stands
-- M.reach back from the next one's middle, along the arrow, just clear of its frame.
local function Arrows(card, tab)
	local used = 0
	local half = M.node / 2
	for _, node in ipairs(tab.nodes) do
		for _, edge in ipairs(node.info.visibleEdges or {}) do
			local to = data.byNode[edge.targetNode]
			if to and to.tab == tab then
				used = used + 1
				local a = Arrow(card, used)
				local shut = to.tab.gate ~= nil and to.row >= to.tab.gate.row
				local kind = (edge.isActive == true or node.ranks >= node.max) and "on" or (shut and "shut") or "off"
				local x0, y0 = ColX(node.col) + half, RowY(node.row) + half
				local x1, y1 = ColX(to.col) + half, RowY(to.row) + half
				local turn = to.col ~= node.col and to.row ~= node.row
				-- (Straight, or across then down: the last stretch is what the head follows.)
				local fx, fy = turn and x1 or x0, turn and y0 or y0
				local dx, dy = x1 - fx, y1 - fy
				local length = math.max(1, math.sqrt(dx * dx + dy * dy))
				local hx, hy = x1 - dx / length * M.reach, y1 - dy / length * M.reach
				a.line:SetAtlas(ART.line[kind])
				a.bend:SetAtlas(ART.line[kind])
				a.line:SetStartPoint("TOPLEFT", card, x0, -y0)
				if turn then
					a.line:SetEndPoint("TOPLEFT", card, fx, -fy)
					a.bend:SetStartPoint("TOPLEFT", card, fx, -fy)
					a.bend:SetEndPoint("TOPLEFT", card, hx, -hy)
					a.bend:Show()
				else
					a.line:SetEndPoint("TOPLEFT", card, hx, -hy)
					a.bend:Hide()
				end
				a.head:SetAtlas(ART.head[kind], true)
				a.head:ClearAllPoints()
				a.head:SetPoint("CENTER", card, "TOPLEFT", hx, -hy)
				-- (Down is the art's own way: screen y runs up, the card's rows down.)
				a.head:SetRotation(math.atan2(-dy, dx) + math.pi / 2)
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

-- A turn's pin: the next one lit in your color, the ones after slate.
local function Badge(turn, n)
	turn:Set(n, n == 1)
	turn:Show()
end

-- One talent as it stands.
local function Dress(b, node)
	local _, icon = About(node)
	b.icon:SetTexture(icon or 134400)
	-- Its state as the game has it: full, some points in, a point can go in, its row still shut, or out of reach.
	local gated = node.tab.gate ~= nil and node.row >= node.tab.gate.row
	local state = (node.ranks >= node.max and "maxed") or (CanLearn(node) and "selectable")
		or (node.ranks > 0 and "normal") or (gated and "locked") or "disabled"
	local look = STATE[state]
	b.state = state
	-- Your build's next talent wears the game's frame in your color, whatever its state, and glows so while a point
	-- waits. One you hold past your build wears it crimson, and nothing about it says "put a point here".
	local turn = Turn(node)
	local next = turn == 1
	local over = plan and not plan.strayed and plan.over[node.id] or 0
	local frame = (next or over > 0) and ART.disabled or ART[state]
	local r, g, bl = 1, 1, 1
	if next then r, g, bl = Theme.Accent() elseif over > 0 then r, g, bl = C.bad[1], C.bad[2], C.bad[3] end
	b.border:SetAtlas(frame, true)
	b.border:SetVertexColor(r, g, bl)
	b.lit:SetAtlas(frame, true)
	b.lit:SetVertexColor(r, g, bl)
	b.lit:SetAlpha(next and 1 or look.hover)
	b.icon:SetDesaturated(look.dim ~= nil)
	b.dim:SetShown(look.dim ~= nil)
	b.dim:SetAlpha(look.dim or 0)
	-- (Hidden, not stopped: it keeps its place in the round the others sweep in.)
	local sheen = (next or over > 0) and 0 or look.sheen
	b.sheen:SetShown(sheen > 0)
	b.sheen:SetAlpha(sheen)
	if b:IsVisible() then Sheen(b) end
	local glow = (state == "selectable" and over == 0) or (next and data.left > 0)
	b.glow:SetShown(glow)
	b.glow:SetDesaturated(next)
	b.glow:SetVertexColor(r, g, bl)
	if glow then
		if not b.glowAnim:IsPlaying() then b.glowAnim:Play() end
	else
		b.glowAnim:Stop()
	end
	b.rank:SetText(("%d/%d"):format(node.ranks, node.max))
	if next or over > 0 then
		b.rank:SetTextColor(r, g, bl)
	else
		local ink = (state == "selectable" and GREEN_FONT_COLOR) or (look.dim and DISABLED_FONT_COLOR) or YELLOW_FONT_COLOR
		b.rank:SetTextColor(ink:GetRGB())
	end
	-- Your build's turns. A talent it never takes stands back a little, so the build reads at a glance.
	local want = plan and not plan.strayed and plan.want[node.id] or 0
	local aside = plan and not plan.strayed and want == 0 and node.ranks == 0 and state ~= "selectable"
	local light = aside and 0.72 or 1
	b.icon:SetVertexColor(light, light, light)
	if turn then Badge(b.turn, turn) else b.turn:Hide() end
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
	foot.reset:SetTone(plan and not plan.strayed and plan.off > 0 and C.bad or nil)
end

Lay = function()
	if not box then return end
	local d = Read()
	data = d
	if not d then return end
	for _, node in ipairs(d.nodes) do node.config = d.config end
	plan = Planned(d)
	local n = #d.tabs
	local cardW = M.pad + (d.cols - 1) * M.col + M.node + M.right
	local cardH = RowY(d.rows) + M.node + M.under
	local top = HEAD.line + UI.LINE + M.below
	local width = 2 * M.margin + n * cardW + (n - 1) * M.gap
	local height = top + cardH + M.below + M.foot
	-- (as big as the cards need, and the look's clearance round them: UI.BodyFit)
	local fit = box.shyBodyFit
	if not fit or math.abs(fit[1] - width) > 0.5 or math.abs(fit[2] - height) > 0.5 then UI.BodyFit(box, width, height) end

	-- The tabs, only with a second spec to switch to.
	local dual = (GetNumSpecGroups and GetNumSpecGroups() or 1) > 1
	box.specs:SetShown(dual)
	if dual then box.specs:Select(d.group) end

	local seen = {}
	for k, tab in ipairs(d.tabs) do
		local card = Card(k)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", UI.Body(box), "TOPLEFT", M.margin + (k - 1) * (cardW + M.gap), -top)
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
	if n > 0 then LayAir(cards[1], cards[n]) end
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
