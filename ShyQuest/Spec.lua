-- Talent suggestions as a route errand: with a point to spend, a card row names the next talent
-- of the character's leveling build, read against the tree by ShyCore (Shy.Build).
--   A class has several builds: one for each way to play it (a tree, a healer or tank for dungeons,
--     PvP), the first the one for questing alone. The build followed is the one the player picked (the
--     setup window's step, the card's menu, the options), else the one the talents already bought fit
--     best. A build that is a hard way to level says so (`note`), and what to do about it.
--   The next talent is the first in the build's order not yet bought that far. A character with
--     more than STRAYED points outside the build is told so, and to pick another or reset.
--   The row leads the card briefly after a point arrives and while resting; never in combat,
--     on a flight or dead.
--   Nothing is spent unasked. The row's menu learns the next talent in one click (Learn: a rank bought
--     and committed on the active config, as the window's own Apply does; C_Traits and C_ClassTalents'
--     commit are open to addons). A click on the row opens the game's talent window, by a
--     secure click on TalentMicroButton: opening it from addon code taints it and the spellbook
--     sharing its frame, and spells clicked there are then blocked. In a fight the row can't.
--   In that window (or ShySkin's own, while it stands in for it) the build's next talents wear the map's
--     numbered pins, the next one a white ring, and their tooltips say so. A talent you hold past the build wears a
--     crimson ring (Shy.Build.OverRing), and its tooltip says so too. They are frames of ours standing
--     on the talent buttons: the game's own glow and search mark are fields written on its buttons, which
--     addon code must not do.

local ADDON, ns = ...
local T = ns.T
local R = ns.Route
local UI = Shy.UI
local C = UI.colors
local Build = Shy.Build      -- (none until the client restarts with the ShyCore that has it: no suggestions)

local Spec = {}
ns.Spec = Spec

T.defaults.spec = { on = true }      -- unspent talent points as a row on the card

local LEAD_FOR = 30          -- seconds a new point leads the card, from the first moment out of combat
local FIRST_FOR = 120        -- the same for the character's first point
local STRAYED = Build and Build.STRAYED or 5   -- more points than this outside the build: stop naming talents
local AHEAD = Build and Build.AHEAD or 3       -- talents listed after the next one
local PIN = 20               -- a numbered pin on a talent, standing on the talent's top left corner
local RING = 5               -- how far the next talent's ring stands out from it
local OVER = 3               -- how far a crimson ring stands out from a talent past the build
local PLACE = { "next", "2nd", "3rd", "4th" }    -- a marked talent's turn, in its tooltip (AHEAD + 1 of them)

local ready = false          -- spell or trait data has loaded
local fresh                  -- a point just arrived: { span, calmAt }

-- This class's tree and builds: { tree, tabs, from, nodes, builds }, or nil.
local function Class()
	return Build and Build.Class() or nil
end

-- This character's talent state: { seen, skip, first, greeted }. (The pick is ShyCore's.)
local function Mine()
	if not ns.char then return nil end
	local mine = ns.char.spec
	if not mine then
		mine = {}
		ns.char.spec = mine
	end
	-- A pick made before ShyCore kept them: ShyCore's now.
	if mine.build ~= nil and Build then
		if Build.Picked() == nil then Build.Choose(mine.build) end
		mine.build = nil
	end
	return mine
end

local function Calm()
	return not InCombatLockdown() and not UnitAffectingCombat("player") and not UnitOnTaxi("player")
		and not UnitIsDeadOrGhost("player")
end

local function Points(count)
	return count == 1 and "1 point to spend" or ("%d points to spend"):format(count)
end

-- The current reading (Shy.Build.Now), or nil.
function Spec.Now()
	if not ready or not Build or not Mine() then return nil end
	return Build.Now()
end

-- A new point since the last look: it leads the card for a while.
local function Fresh()
	local now, mine = Spec.Now(), Mine()
	if not now or not mine then return end
	if mine.seen and now.earned > mine.seen then fresh = { span = LEAD_FOR } end
	mine.seen = now.earned
	if now.unspent <= 0 then fresh = nil end
end

-- Where a talent stands, and how many points it takes in a row. The tab is named only when it isn't
-- the build's own tree.
local function Where(talent, tree)
	local where = talent.tab == tree and ("row %d"):format(talent.row) or ("%s, row %d"):format(talent.tab, talent.row)
	return talent.count > 1 and ("x%d  \194\183  %s"):format(talent.count, where) or where
end

-- In the talent window

local marks = {}             -- our frames on the window's talent buttons: [1] the next talent, then what follows it
local flag                   -- "LEVELING BUILD" under the heading of the build's tree
local trouble                -- the last error from marking the window; said in chat once

-- The game's talent window while it is showing, or nil. It is loaded on its first use.
local function Window()
	local spells = PlayerSpellsFrame
	local window = spells and spells.TalentsFrame
	return window and window:IsVisible() and window or nil
end

-- Whether the window shows the talents the build was read against: not another player's, and not
-- the other set of a dual spec.
local function Ours(window, now)
	return not window:IsInspecting() and window:GetConfigID() == now.config and window:GetTalentTreeID() == now.treeID
end

-- ShySkin's own talent window while it stands in for the game's and is open, or nil. It shows a talent's
-- frame by its node (.Button) and says after every lay (SHY_TALENTS).
local function Skinned()
	local skin = Shy.addons.Skin
	local own = skin and skin.Talents and skin:Talents()
	return own and own.IsOn and own.IsOn() and own.IsOpen and own.IsOpen() and own or nil
end

-- A talent's button in whichever window is marked.
local function ButtonOf(own, window, node)
	if own then return own.Button(node) end
	return window and window:GetTalentButtonByNodeID(node) or nil
end

-- A crimson ring for the nth talent past the build.
local overs = {}
local function Over(n)
	local ring = overs[n]
	if ring then return ring end
	ring = CreateFrame("Frame", nil, UIParent)
	ring:Hide()
	ring.edge = Build.OverRing(ring, OVER)
	overs[n] = ring
	return ring
end

-- A numbered pin on a talent; the first also has the ring round the talent, which breathes while
-- there is a point to spend.
local function Mark(index)
	local mark = marks[index]
	if mark then return mark end
	mark = CreateFrame("Frame", nil, UIParent)
	mark:Hide()
	if index == 1 then
		local slice = Shy.Skin.FRAME_SLICE
		local ring = mark:CreateTexture(nil, "ARTWORK")
		ring:SetTexture(Shy.Skin.FRAME)
		ring:SetTextureSliceMargins(slice, slice, slice, slice)
		ring:SetPoint("TOPLEFT", -RING, RING)
		ring:SetPoint("BOTTOMRIGHT", RING, -RING)
		-- The route's white, as the lit pin: never the accent a talent you hold wears.
		UI.Tint(ring, ns.MARK.route)
		local breathe = ring:CreateAnimationGroup()
		breathe:SetLooping("BOUNCE")
		local fade = breathe:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.35)
		fade:SetDuration(0.8)
		fade:SetSmoothing("IN_OUT")
		mark.ring, mark.breathe = ring, breathe
	end
	mark.pin = ns.CreateMark(mark, PIN, "small")
	mark.pin:SetPoint("CENTER", mark, "TOPLEFT", 2, -2)
	marks[index] = mark
	return mark
end

local function Flag()
	if flag then return flag end
	flag = CreateFrame("Frame", nil, UIParent)
	flag:SetSize(120, 12)
	flag.text = UI.Text(flag, "LEVELING BUILD", 10, true, C.hot)
	flag.text:SetPoint("LEFT")
	return flag
end

-- Stands the marks on the window's talent buttons and the flag under the heading of the build's tree.
-- The buttons and headings are pooled, so every mark is placed again each time. ShySkin's window, when it is
-- the one open, is marked the same way; it names the build under the tree itself, so it takes no flag.
local function Lay()
	for index = 1, AHEAD + 1 do
		if marks[index] then marks[index]:Hide() end
	end
	if flag then flag:Hide() end
	for _, ring in pairs(overs) do ring:Hide() end
	-- ShySkin marks your build itself: on its own window, and on the game's while it keeps that one the game's own.
	local skin = Shy.addons.Skin
	if Skinned() or (skin and skin.owns and skin.owns.talentMarks) then return end
	local own = nil
	local window = Window()
	local now = (own or window) and T.db.spec.on and Spec.Now() or nil
	if not now then return end
	if own and own.Config() ~= now.config then return end
	if window and not Ours(window, now) then return end
	for _, header in ipairs(window and window.treeHeaders or {}) do
		local shown = header.displayInfo
		if shown and shown.groupID == now.group then
			local f = Flag()
			f:SetParent(header)
			f:SetFrameLevel(header:GetFrameLevel() + 1)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", header.Name, "BOTTOMLEFT", 0, -2)
			f:Show()
		end
	end
	if now.strayed then return end
	local n = 0
	for node in pairs(now.over or {}) do
		local button = ButtonOf(own, window, node)
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
	-- A talent the order comes back to wears the number of its first turn only.
	local worn = {}
	for index, talent in ipairs(now.plan) do
		local button = not worn[talent.node] and ButtonOf(own, window, talent.node)
		worn[talent.node] = true
		if button then
			local mark = Mark(index)
			mark:SetParent(button)
			mark:SetFrameLevel(button:GetFrameLevel() + 5)
			mark:ClearAllPoints()
			mark:SetAllPoints(button)
			mark.pin:Set("step", index == 1, index)
			if mark.ring then
				local lit = now.unspent > 0
				mark.ring:SetShown(lit)
				-- Laid again on every lay of the window: a breath already going is left to go on.
				if not lit then mark.breathe:Stop() elseif not mark.breathe:IsPlaying() then mark.breathe:Play() end
			end
			mark:Show()
		end
	end
end

-- The talent a button of the window is marked as: its place among the build's next, and the talent.
local function Marked(window, now, button)
	if now.strayed then return nil end
	for index, talent in ipairs(now.plan) do
		if window:GetTalentButtonByNodeID(talent.node) == button then return index, talent end
	end
end

-- A marked talent's tooltip says its turn.
local function Tell(button, tip)
	local skin = Shy.addons.Skin
	if skin and skin.owns and skin.owns.talentMarks then return end
	local window = Window()
	local now = window and T.db.spec.on and Spec.Now() or nil
	if not now or not Ours(window, now) then return end
	local node = not now.strayed and button.GetNodeID and button:GetNodeID()
	if node and now.over and now.over[node] then
		for _, line in ipairs(Build.OverSays(now.name, now.want[node] or 0, (now.want[node] or 0) + now.over[node])) do
			tip:AddLine(line.text, line.color[1], line.color[2], line.color[3], true)
		end
		tip:Show()
		return
	end
	local index, talent = Marked(window, now, button)
	if not index then return end
	local line = "Leveling build: " .. PLACE[index]
	if talent.count > 1 then line = ("%s, %d points"):format(line, talent.count) end
	tip:AddLine(line, C.hot[1], C.hot[2], C.hot[3])
	tip:Show()
end

-- The game hides errors: a failure here is said once in chat and kept for the report.
local function Guarded(fn)
	return function(_, ...)
		local ok, err = pcall(fn, ...)
		if ok then return end
		if not trouble then T:Print("couldn't mark the talent window: " .. tostring(err)) end
		trouble = tostring(err)
	end
end
local Dress = Guarded(Lay)

EventRegistry:RegisterCallback("TalentFrameBase.ButtonsUpdated", Dress, Spec)
EventRegistry:RegisterCallback("PlayerSpellsFrame.TalentTab.Show", Dress, Spec)
EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", Guarded(Tell), Spec)
Shy:On("SHY_TALENTS", Dress)
Shy:On("SHY_SKIN_OWNS", function(piece) if piece == "talentMarks" then Dress() end end)

-- What was found of the talent window, as text: for a look when a talent goes unmarked.
function Spec.Report()
	local now = Spec.Now()
	local out = { ("Suggestions %s, talent data %s."):format(T.db.spec.on and "on" or "off", ready and "loaded" or "not loaded yet") }
	if not now then
		out[#out + 1] = "No reading of the tree: no builds for this class, another tree than theirs, or not loaded yet."
	else
		out[#out + 1] = ("Build %s (%s), %d of the class's."):format(now.name, now.chosen and "picked" or "fits the talents best", #Class().builds)
		out[#out + 1] = ("%d to spend, %d spent, %d outside the build%s. Tree %s (%d), config %s."):format(now.unspent, now.spent, now.off,
			now.strayed and " (strayed)" or "", now.tree, now.treeID, tostring(now.config))
	end
	local spells = PlayerSpellsFrame
	local window = spells and spells.TalentsFrame
	local own = Skinned()
	-- Each of the build's next talents: its button in the window, and whether it wears its mark.
	local function Listed()
		for index, talent in ipairs(now and not now.strayed and now.plan or {}) do
			local button = ButtonOf(own, window, talent.node)
			local mark = marks[index]
			local on = button and mark and mark:IsShown() and mark:GetParent() == button
			out[#out + 1] = ("%d. %s (%d): %s"):format(index, talent.name, talent.node, not button and "no button"
				or not on and "button found, not marked" or mark.ring and mark.ring:IsShown() and "marked, ringed" or "marked")
		end
	end
	if own then
		out[#out + 1] = ("ShySkin's talent window: open, config %s."):format(tostring(own.Config()))
		Listed()
	elseif not window then
		out[#out + 1] = "Talent window: not loaded yet. Open it once."
	else
		out[#out + 1] = ("Talent window: %s, config %s, tree %s%s."):format(window:IsVisible() and "showing" or "closed",
			tostring(window:GetConfigID()), tostring(window:GetTalentTreeID()), window:IsInspecting() and ", inspecting" or "")
		Listed()
		out[#out + 1] = ("Tree headings: %d, flag %s."):format(#(window.treeHeaders or {}), flag and flag:IsShown() and "shown" or "not shown")
	end
	if trouble then out[#out + 1] = "Last error: " .. trouble end
	return table.concat(out, "\n")
end

-- Opening the window

local key                    -- the secure button laid over the card's row
local over                   -- the row the mouse was last on

local function Away()
	key.row = nil
	key:Hide()
end

-- A secure click on one of the micro menu's buttons (see the file header). The button is a child of
-- UIParent placed by absolute coordinates, never anchored or parented to the row (that would make the
-- card protected), and is put away as a fight begins. The row keeps its hover and its menu through it.
local function Key()
	if key then return key end
	key = CreateFrame("Button", "ShyQuestTalentsKey", UIParent, "SecureActionButtonTemplate")
	key:RegisterForClicks("AnyUp", "AnyDown")
	key:SetAttribute("type1", "click")
	key:Hide()
	local function Pass(script)
		return function(self, ...)
			local row = self.row
			local fn = row and row:GetScript(script)
			if fn then fn(row, ...) end
		end
	end
	local menu = Pass("OnMouseUp")
	key:SetScript("OnEnter", Pass("OnEnter"))
	key:SetScript("OnLeave", function(self)
		Pass("OnLeave")(self)
		if not InCombatLockdown() then Away() end
	end)
	key:HookScript("OnMouseUp", function(self, button)
		if button == "RightButton" then menu(self, button) end
	end)
	-- Once open, a second click would close it again.
	key:SetScript("PostClick", function(_, button, down)
		if button == "LeftButton" and not down and not InCombatLockdown() then Away() end
	end)
	-- The card may fill its rows anew under the mouse.
	key:SetScript("OnUpdate", Shy.Clocked("frame: spec key", function(self)
		local row = self.row
		if row and row.stop and row.stop.errand == self.errand and row:IsVisible() then return end
		if not InCombatLockdown() then Away() end
	end))
	return key
end

-- Lays the key over a card's row while the mouse is on it, to click `button` of the micro menu, or
-- with `spell` to cast that spell (Pets.lua: Beast Training opens the pet's training window).
-- errand: the row's stop's (the key goes when the row is given to another). open: the window is up
-- already, where a click would close it. Legacy.lua's errand uses it too.
function Spec.KeyOver(row, button, errand, open, spell)
	over = row
	if InCombatLockdown() or open then return end
	if key and key.row == row and key:IsShown() then return end
	local left, bottom = row:GetLeft(), row:GetBottom()
	if not left then return end
	local k, s = Key(), row:GetEffectiveScale() / UIParent:GetEffectiveScale()
	k.row, k.errand = row, errand
	k:SetAttribute("type1", spell and "spell" or "click")
	k:SetAttribute("spell", spell)
	k:SetAttribute("clickbutton", button)
	k:SetFrameStrata(row:GetFrameStrata())
	k:SetFrameLevel(row:GetFrameLevel() + 20)
	k:ClearAllPoints()
	k:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
	k:SetSize(row:GetWidth() * s, row:GetHeight() * s)
	k:Show()
end

-- ShySkin's own talent window, while it stands in for the game's: it opens from any code, in a fight too.
local function Own()
	local skin = Shy.addons.Skin
	local own = skin and skin.Talents and skin:Talents()
	return own and own.IsOn and own.IsOn() and own or nil
end

-- The talent row's `over`: the secure key to the game's window; none for ShySkin's, which the row's click opens.
local function Cover(row)
	if Own() then return end
	Spec.KeyOver(row, TalentMicroButton, "spec", Window() ~= nil)
end

-- The row's own click, which the key takes while it is up: so this is ShySkin's window, a fight, or the window is open.
local function Click()
	local own = Own()
	if own then
		own.Open()
	elseif InCombatLockdown() and not Window() then
		T:Print("can't open talents from the card in combat.")
	end
end

-- Learns the build's next talent: one rank, bought on the active config and committed. Never over changes
-- the player has made in the talent window and not applied, and never in a fight. True when it went in.
function Spec.Learn()
	local now = Spec.Now()
	local talent = now and not now.strayed and now.next
	if not talent or now.unspent <= 0 or InCombatLockdown() then return false end
	local config = now.config
	if C_Traits.ConfigHasStagedChanges(config) then
		T:Print("apply or undo the changes in the talent window first.")
		return false
	end
	if not C_Traits.PurchaseRank(config, talent.node) then return false end
	if not C_ClassTalents.CommitConfig() then
		C_Traits.RollbackConfig(config)
		return false
	end
	Build.Stale()
	return true
end

-- The build

-- The build the suggestions follow: your pick, else the one your talents fit best. nil for a class with none.
function Spec.Build()
	return Build and Build.Followed() or nil
end

-- The class's builds for a picker (Shy.Build.Builds): { { build, tag, on, reset } }.
function Spec.Builds()
	return Build and Build.Builds() or {}
end

-- Follows a build from now on (by id; nil: whichever the talents fit best again).
function Spec.Choose(id)
	if Build then Build.Choose(id) end
end

-- A build picked, here or anywhere: the row asks again, and the window and the card show it.
Shy:On("SHY_BUILD", function(why)
	if why ~= "picked" then return end
	local mine = Mine()
	if mine then mine.skip = nil end
	Dress()
	ns.Refresh()
end)

-- When the talent points start, for ShyCore's setup step: level 10, or sooner with the account's Talented.
function T:TalentsFrom()
	return ns.Legacy and ns.Legacy.TalentsFrom and ns.Legacy.TalentsFrom() or nil
end

-- For other addons (ShySkin's own talent window marks them): the build's next talents while suggestions are on and
-- the talents still follow it: { name, config, tree, group (the build's tree), unspent, nodes = { { node, count }, ... }
-- } in the order to buy them, each talent once. nil when there is nothing to suggest.
function T:TalentPlan()
	local now = T.db.spec.on and Spec.Now() or nil
	if not now or now.strayed then return nil end
	local nodes, seen = {}, {}
	for _, talent in ipairs(now.plan) do
		if not seen[talent.node] then
			seen[talent.node] = true
			nodes[#nodes + 1] = { node = talent.node, count = talent.count }
		end
	end
	return { name = now.name, config = now.config, tree = now.treeID, group = now.group, unspent = now.unspent, nodes = nodes }
end

-- The builds as a list in a menu (the card's). Picking one is ShyCore's (Shy.Build.Pick).
function Spec.Menu(root)
	local builds = Spec.Builds()
	if #builds < 2 then return end
	local list = root:CreateButton("Leveling build")
	for _, one in ipairs(builds) do
		local build = one.build
		local entry = list:CreateRadio(build.name, function() return Spec.Build() == build end, function() Build.Pick(build.id) end)
		entry:SetDetail(one.reset and "needs a talent reset" or one.tag)
		entry:SetTooltip(build.note and (build.why .. " " .. build.note) or build.why)
	end
	local current = Spec.Build()
	if current and Shy.Lineup and Shy.Lineup.Has(current.id) then
		list:CreateDivider()
		local entry = list:CreateButton("Lay out cooldowns", function()
			if Build.Lineup(current.id) then Shy.Reload(Build.RELOAD) end
		end)
		entry:SetTooltip("Lays out your cooldown manager for " .. current.name .. ": main abilities first, buffs you keep up as bars.")
	end
end

-- On the card

-- Whether the row goes before the guide's step right now.
local function Leads()
	if not Calm() then return false end
	if IsResting() then return true end
	if not fresh then return false end
	if not fresh.calmAt then
		fresh.calmAt = GetTime()
		-- The route only rebuilds on a change, so ask for one when the lead time ends.
		C_Timer.After(fresh.span + 0.5, function() ns.Refresh() end)
	end
	if GetTime() - fresh.calmAt <= fresh.span then return true end
	fresh = nil
	return false
end

-- The talent point as a route errand (R.AddErrand), or nil.
local function Find()
	if not T.db.spec.on then return nil end
	local now, mine = Spec.Now(), Mine()
	if not now or not mine or now.unspent <= 0 or (mine.skip or 0) >= now.earned then return nil end
	local level = UnitLevel("player")
	-- Why this build, and its caution where it is a hard way to level.
	local why = { title = "Why " .. now.name, rows = { { glyph = "note", quiet = true, text = now.why } } }
	if now.note then why.rows[2] = { glyph = "note", tint = C.alert, color = C.alert, text = now.note } end
	-- Talent points sooner: the account's Talented, while it has ranks left to buy (Legacy.lua).
	local sooner = ns.Legacy and ns.Legacy.Sooner and ns.Legacy.Sooner() or nil
	local stop = {
		caption = (mine.first == now.earned and "LEVEL %d  \194\183  YOUR FIRST TALENT" or "LEVEL %d  \194\183  TALENTS"):format(level),
		mark = "talent",
		menu = function(root)
			root:CreateButton("Ask me at the next point", function()
				Mine().skip = now.earned
				fresh = nil
				ns.Refresh()
			end)
		end,
		click = Click,
		over = Cover,
		hint = "Open talents",
		menuHint = "Not now, another build",
	}
	local talent = now.next
	if now.strayed or not talent then
		stop.title = now.unspent == 1 and "A talent point to spend" or ("%d talent points to spend"):format(now.unspent)
		if now.ended and now.off <= STRAYED then
			-- Every talent of the build is bought.
			stop.lines = { ("%s has no more talents planned yet"):format(now.name) }
			stop.hover = function() return { why } end
		else
			-- Off the build: say so, and what can be done.
			local away = { title = "Not on this build", rows = { { glyph = "note", quiet = true,
				text = (now.chosen and "%d of your points aren't in %s. Reset your talents at a class trainer (it's on your card), or pick the build you play from this row's menu."
					or "%d of your points aren't in %s. Pick the build you play from this row's menu, or reset your talents at a class trainer."):format(now.off, now.name) } } }
			stop.lines = { ("Not on the %s build"):format(now.name) }
			stop.hover = function() return { away, why } end
		end
		stop.tip = function(tip)
			tip:AddLine(now.why, C.dim[1], C.dim[2], C.dim[3], true)
		end
		return stop
	end
	-- A long name fills the row without the prefix.
	stop.title = #talent.name <= 22 and ("Talent: " .. talent.name) or talent.name
	local later = stop.menu
	stop.menu = function(root)
		local name = talent.ranks > 1 and ("%s (rank %d)"):format(talent.name, talent.rank) or talent.name
		root:CreateButton("Learn " .. name, function() Spec.Learn() end)
		later(root)
	end
	stop.menuHint = "Learn it, not now, another build"
	stop.lines = {
		talent.ranks > 1 and ("%s, row %d  \194\183  rank %d of %d"):format(talent.tab, talent.row, talent.rank, talent.ranks)
			or ("%s, row %d"):format(talent.tab, talent.row),
		Points(now.unspent),
	}
	stop.first = Leads() or nil
	-- Hover content (CardHover.lua): the build's next talents, the one to take lit, then why this build.
	stop.hover = function()
		local rows = {}
		for index, other in ipairs(now.plan) do
			rows[index] = { icon = other.icon, glyph = "star", text = other.name, lit = index == 1 or nil,
				right = Where(other, now.tree), rightColor = C.dim }
		end
		return { { title = Points(now.unspent), rows = rows }, why, sooner }
	end
	stop.tip = function(tip)
		tip:AddLine(("%s: %s"):format(now.name, now.why), C.dim[1], C.dim[2], C.dim[3], true)
		local after = {}
		for index = 2, #now.plan do
			local other = now.plan[index]
			after[#after + 1] = other.count > 1 and ("%s x%d"):format(other.name, other.count) or other.name
		end
		if #after > 0 then tip:AddLine("Then " .. table.concat(after, ", "), 1, 1, 1, true) end
		tip:AddLine("Click to open talents.", C.dim[1], C.dim[2], C.dim[3], true)
	end
	return stop
end

-- A build was picked that the talents bought don't fit: talents are unlearned at a class trainer (the
-- trainer's own dialogue, which names its price), so the nearest one is a stop, at any distance, with a
-- sign of its own. It leads when it is worth the walk now (R.Passing: on the way, or no more than
-- RESET_WORTH yards off it with no nearer chance before the guide's next fight) or asked for ("Take
-- me to"). Gone once the talents fit, or the pick is taken back. The route errand (R.AddErrand), or nil.
local RESET_WORTH = 1200
local function Reset(lead)
	if not T.db.spec.on then return nil end
	local now = Spec.Now()
	if not now or not now.chosen or now.off <= STRAYED then return nil end
	local at = ns.Train and ns.Train.Nearest and ns.Train.Nearest()
	if not at then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local passing = not busy and R.Passing("reset", at.map, at.x, at.y, lead, nil, RESET_WORTH, true)
	return {
		title = "Reset talents",
		lines = { at.npc.name, ("For the %s build"):format(now.name) },
		caption = "TALENTS  \194\183  YOUR TRAINER",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "reset",
		first = passing or nil,
		menuHint = "Keep my talents",
		menu = function(root)
			root:CreateButton("Keep my talents: follow the build they fit", function() Spec.Choose(nil) end)
		end,
		-- Hover content (CardHover.lua): what to do there, and why.
		hover = function()
			return { { title = "To do", rows = {
				{ glyph = "talk", text = ("Ask %s to unlearn your talents. You'll see the price before you agree."):format(at.npc.name) },
				{ glyph = "note", quiet = true, text = ("%d of your points aren't in %s."):format(now.off, now.name) },
			} } }
		end,
		tip = function(tip)
			tip:AddLine(("Unlearn your talents at a class trainer to follow %s. You'll see the price before you agree."):format(now.name),
				C.dim[1], C.dim[2], C.dim[3], true)
		end,
	}
end

-- The first point, and events

-- Announces a character's first talent point once, out of combat.
local function Greet()
	local now, mine = Spec.Now(), Mine()
	if not now or not mine or mine.greeted or not T.db.spec.on then return end
	-- Not for a character that has already spent points.
	if now.spent > 0 then
		mine.greeted = true
		return
	end
	if now.unspent <= 0 or not Calm() then return end
	mine.greeted, mine.first = true, now.earned
	fresh = { span = FIRST_FOR }
	T:Print(("you have your first talent point. Your leveling build is |cffffffff%s|r. %s"):format(now.name, now.why))
	local talent = now.next
	if talent then
		T:Print(("start with |cffffffff%s|r (%s, row %d). To level another way, right-click the card and pick Leveling build."):format(
			talent.name, talent.tab, talent.row))
	end
end

-- Talent and spellbook events come in bursts: one deferred refresh covers them.
local looking = false
local routing = false   -- the look coming asks again: "route" (the card's row moved), "all" (the talents changed)
local told = nil        -- the talents as the guide was last told of them (Said)
-- What the guide reads of your talents, in a line. Only a change in it rebuilds the guide.
local function Said()
	local now = Spec.Now()
	if not now then return "" end
	return ("%d %d %s %s"):format(now.unspent, now.spent, tostring(now.build.id), tostring(now.next and now.next.node))
end
local function Look()
	looking = false
	local route = routing
	routing = false
	if not ready or not ns.char then return end
	Fresh()
	Greet()
	Dress()
	local said = route == "all" and Said()
	if said and said ~= told then
		told = said
		ns.Refresh(nil, "talents")
	elseif route then
		-- (The card's row alone moved: a fight, a rest, the same talents told again. The errands are fitted again.)
		ns.RefreshErrands()
	end
end
local function Soon(route)
	if route == "all" or (route and not routing) then routing = route end
	if looking then return end
	looking = true
	C_Timer.After(0.3, Look)
end

-- A point to spend: the card's row, which a fight or a rest moves (Leads).
local function Spending()
	local now = T.db.spec.on and Spec.Now()
	return now and now.unspent > 0 or false
end

-- Events that don't mean talent data changed.
local QUIET = { PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true, PLAYER_UPDATE_RESTING = true }

local events = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
	"TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
	"PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING" }) do
	events:RegisterEvent(event)
end
local function Seen(_, event)
	if event == "PLAYER_LEVEL_UP" then
		-- The new point may be counted a moment after the level-up event.
		if Build then Build.Stale() end
		C_Timer.After(1.5, function()
			if Build then Build.Stale() end
			routing = "all"
			Look()
		end)
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Last chance to put the key away before combat lockdown.
		if key and key:IsShown() then Away() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- The mouse may have rested on the row through the fight.
		if over and over:IsVisible() and over:IsMouseOver() and over.stop and over.stop.over then over.stop.over(over) end
	elseif not QUIET[event] then
		ready = true          -- (ShyCore reads the talents again on the same events)
	end
	if not QUIET[event] then Soon("all") else Soon(Spending() and "route") end
end
events:SetScript("OnEvent", Seen)
-- The spellbook read or changed (ShyCore, only when it really did): the talents can be read now.
Shy:On("SHY_SPELLS", function() Seen(nil, "SHY_SPELLS") end)

ns.OnApply(function() Dress() end)

ns.CardSwitch("suggestions", function(root)
	root:CreateCheckbox("Talent suggestions", function() return T.db.spec.on end, function()
		T.db.spec.on = not T.db.spec.on
		ns.Apply()
	end)
	Spec.Menu(root)
end)

-- Settings: whether talents are suggested. (Which build is ShyCore's: Leveling build, in its settings.)
T:Settings({
	{ section = "Talents" },
	{ key = "spec.on", label = "Suggest talents",
		desc = "With a point to spend, the quest window names your build's next talent. The talent window numbers the next few." },
})

-- Guarded: the loaded Route.lua may predate R.AddErrand until the client restarts.
if R and R.AddErrand then
	R.AddErrand("spec", Find, "Talent points")
	R.AddErrand("reset", Reset, "Talent resets")
end
if R and R.AddOffer then
	R.AddOffer("reset", function()
		local now = T.db.spec.on and ns.char and Spec.Now()
		return now and now.chosen and now.off > STRAYED and { { text = "Class trainer: reset talents" } } or {}
	end)
end
