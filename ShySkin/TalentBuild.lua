-- Your build on the game's talent window (PlayerSpellsFrame.TalentsFrame) when you keep that window ("Game's talent
-- window" in the spells module): its paintings and its animations as made. Nothing of the game's is moved, sized or
-- written on; our frames stand on its talent buttons.
--   On the talents: your build's next talents numbered on pins at their corners (UI.NumberMark), the next one ringed,
--     the ring breathing while you have a point to put in it.
--   A talent you hold past your build (bought before the build changed, or by hand): a crimson ring round it, and its
--     hover says so (Shy.Build.OverSays). Not while you're past Shy.Build.STRAYED.
--   In a talent's hover: its turn.
-- The build is ShyCore's (Shy.Build: the one you picked, else the one your talents fit), read against the tree the
-- window shows, staged ranks and all. With more of your points outside it than it allows, nothing is numbered.
-- ShyQuest's own pins stand aside while this is on (T.owns.talentMarks).
--   ns.TalentBuild.On(on)    from the spells module: on while the game's window is its own

local ADDON, ns = ...
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = UI.colors

local TB = {}
ns.TalentBuild = TB

local M = {
	steps = 6,                  -- next talents numbered
	turn = 20, turnIn = 2,      -- a turn's pin, its middle this far in from the talent's top left corner
	ring = 4,                   -- the next talent's ring, this far out round the button
	over = 3,                   -- a talent past your build: its crimson ring, this far out
}
local PLACE = { "next", "2nd", "3rd", "4th", "5th", "6th" }

local on = false
local hooked = false
local soon = false
local marks = {}            -- [turn] our frame on that talent's button
local overs = {}            -- crimson rings, one for each talent past your build
local plan                  -- your build against the window's tree (Planned), or nil

local function Num(v)
	if type(v) ~= "number" or issecretvalue(v) then return 0 end
	return v
end

local function Window()
	local f = PlayerSpellsFrame
	local window = f and f.TalentsFrame
	return window and window:IsVisible() and window or nil
end

-- The window shows your own talents, of the spec you're in.
local function Ours(window)
	if window:IsInspecting() then return false end
	local active = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	return active ~= nil and window:GetConfigID() == active
end

-- { name, left, turns, steps, want, over, strayed }, or nil: steps is what is still to buy, in the build's order
-- ({ node, count }, a talent's ranks in a row one step); turns[node] a talent's first step; want[node] the ranks the
-- build puts there, over[node] the ranks you hold past it; strayed past Shy.Build.STRAYED points outside the build.
local function Planned(window)
	local Build = Shy.Build
	local spec = Build and Build.Class()
	if not spec or not Ours(window) then return nil end
	local config, tree = window:GetConfigID(), window:GetTalentTreeID()
	if tree ~= spec.tree then return nil end
	local build = Build.Followed()
	if not (build and build.order) then return nil end
	local purse = (C_Traits.GetTreeCurrencyInfo(config, tree, false) or {})[1]
	local want, over = {}, {}
	local p = { name = build.name, left = purse and Num(purse.quantity) or 0, turns = {}, steps = {}, want = want, over = over }
	local ranks, off = {}, 0
	for _, node in ipairs(build.order) do want[node] = (want[node] or 0) + 1 end
	for _, id in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
		local n = C_Traits.GetNodeInfo(config, id)
		if n and n.ID ~= 0 then
			ranks[id] = Num(n.ranksPurchased)
			local extra = math.max(0, ranks[id] - (want[id] or 0))
			if extra > 0 then off, over[id] = off + extra, extra end
		end
	end
	local seen = {}
	for _, id in ipairs(build.order) do
		seen[id] = (seen[id] or 0) + 1
		local have = ranks[id]
		if have and seen[id] > have then
			local last = p.steps[#p.steps]
			if last and last.node == id then
				last.count = last.count + 1
			else
				p.steps[#p.steps + 1] = { node = id, count = 1 }
				p.turns[id] = p.turns[id] or #p.steps
			end
		end
	end
	p.strayed = off > Build.STRAYED
	p.ranks = ranks
	return p
end

-- A crimson ring for the nth talent past your build.
local function Over(n)
	local ring = overs[n]
	if ring then return ring end
	ring = CreateFrame("Frame", nil, UIParent)
	ring:Hide()
	ring.edge = Shy.Build.OverRing(ring, M.over)
	overs[n] = ring
	return ring
end

-- Our frame on a talent's button: its turn on the family's numbered pin (UI.NumberMark: the next one lit in your
-- color), and for the next one a ring that breathes while a point waits.
local function Mark(turn)
	local mark = marks[turn]
	if mark then return mark end
	mark = CreateFrame("Frame", nil, UIParent)
	mark:Hide()
	mark.plate = UI.NumberMark(mark, M.turn)
	mark.plate:SetPoint("CENTER", mark, "TOPLEFT", M.turnIn, -M.turnIn)
	mark.plate:Set(turn, turn == 1)
	local next = turn == 1
	if next then
		local slice = Skin.FRAME_SLICE
		local ring = mark:CreateTexture(nil, "OVERLAY")
		ring:SetTexture(Skin.FRAME)
		ring:SetTextureSliceMargins(slice, slice, slice, slice)
		ring:SetPoint("TOPLEFT", -M.ring, M.ring)
		ring:SetPoint("BOTTOMRIGHT", M.ring, -M.ring)
		Theme.Tint(ring, Theme.Accent)
		local breathe = ring:CreateAnimationGroup()
		breathe:SetLooping("BOUNCE")
		local fade = breathe:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.35)
		fade:SetDuration(0.8)
		fade:SetSmoothing("IN_OUT")
		mark.ring, mark.breathe = ring, breathe
	end
	marks[turn] = mark
	return mark
end

-- Every mark stood again on the window's buttons (the game pools them: placed afresh on every lay).
local function Lay()
	for _, mark in pairs(marks) do mark:Hide() end
	for _, ring in pairs(overs) do ring:Hide() end
	local window = on and Window() or nil
	plan = window and Planned(window) or nil
	if not (plan and not plan.strayed) then return end
	local n = 0
	for node in pairs(plan.over) do
		local button = window:GetTalentButtonByNodeID(node)
		if button then
			n = n + 1
			local ring = Over(n)
			ring:SetParent(button)
			ring:SetFrameLevel(button:GetFrameLevel() + 4)
			ring:ClearAllPoints()
			ring:SetAllPoints(button)
			ring:Show()
		end
	end
	for turn, step in ipairs(plan.steps) do
		if turn > M.steps then break end
		local button = plan.turns[step.node] == turn and window:GetTalentButtonByNodeID(step.node)
		if button then
			local mark = Mark(turn)
			mark:SetParent(button)
			mark:SetFrameLevel(button:GetFrameLevel() + 5)
			mark:ClearAllPoints()
			mark:SetAllPoints(button)
			if mark.breathe then
				-- (A breath already going is left to go on.)
				if plan.left <= 0 then mark.breathe:Stop() elseif not mark.breathe:IsPlaying() then mark.breathe:Play() end
			end
			mark:Show()
		end
	end
end

local function Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		Lay()
	end)
end

-- A marked talent's hover says its turn, and one past your build says so.
local function Tell(_, button, tooltip)
	if not (on and plan and not plan.strayed and button and button.GetNodeID) then return end
	local node = button:GetNodeID()
	if plan.over[node] then
		for _, line in ipairs(Shy.Build.OverSays(plan.name, plan.want[node] or 0, plan.ranks[node] or 0)) do
			tooltip:AddLine(line.text, line.color[1], line.color[2], line.color[3], true)
		end
		tooltip:Show()
		return
	end
	local turn = plan.turns[node]
	if not turn or turn > M.steps then return end
	local say = ("%s: %s"):format(plan.name, PLACE[turn] or turn)
	local step = plan.steps[turn]
	if step and step.count > 1 then say = ("%s, %d points"):format(say, step.count) end
	tooltip:AddLine(say, C.hot[1], C.hot[2], C.hot[3])
	tooltip:Show()
end

local function Hook()
	if hooked then return end
	hooked = true
	EventRegistry:RegisterCallback("TalentFrameBase.ButtonsUpdated", Soon, TB)
	EventRegistry:RegisterCallback("PlayerSpellsFrame.TalentTab.Show", Soon, TB)
	EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", Tell, TB)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
		"ACTIVE_COMBAT_CONFIG_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function() if on then Soon() end end)
	Shy:On("SHY_BUILD", function() if on then Soon() end end)
	-- The talents' page shown again (the marks went with it).
	local window = PlayerSpellsFrame.TalentsFrame
	if window then window:HookScript("OnShow", function() if on then Soon() end end) end
end

function TB.On(want)
	want = want and true or false
	if want and PlayerSpellsFrame then Hook() end
	if want == on then
		if on then Soon() end
		return
	end
	on = want
	ns.Claim("talentMarks", on)
	Lay()
end

-- For a look (and the tests).
function TB.Plan() return plan end
function TB.Mark(turn) return marks[turn] end
function TB.Over(n) return overs[n] end
