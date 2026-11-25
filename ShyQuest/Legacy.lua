-- Legacy points as a route errand. With a Legacy point to spend, a card row names the next Legacy
-- talent in an order made for leveling (Data/Legacy.lua, ns.data.legacy). It is read through C_Traits
-- the way the game's Legacy window reads it: one pool of points for the whole account, three trees,
-- one config per tree.
--   Talented comes first in the order. Each of its ranks starts a character's class talent points a
--     level sooner (level 5 at five ranks), and it needs Well Rested in full. Spec.lua asks here when
--     talents start (TalentsFrom) and, while Talented has ranks left, how to get them (Sooner).
--   A point comes from a challenge (an achievement). While the account has fewer than it can hold,
--     the challenges nearest done on this character are listed.
--   Nothing is spent automatically. A click on the row opens the Legacy window, through the secure
--     click Spec.lua lays over a row (Spec.KeyOver) on LegacyMicroButton.

local ADDON, ns = ...
local T = ns.T
local R = ns.Route
local UI = Shy.UI
local C = UI.colors

local Legacy = {}
ns.Legacy = Legacy

T.defaults.legacy = { on = true }    -- unspent Legacy points as a row on the card

local AHEAD = 3              -- talents listed after the next one
local NEAR = 2               -- challenges listed

local ready = false          -- spell or trait data has loaded
local stale = true
local state                  -- last result of Work, or nil
local names = {}             -- node -> { name, icon }

-- This character's Legacy state: { skip }.
local function Mine()
	if not ns.char then return nil end
	local mine = ns.char.legacy
	if not mine then
		mine = {}
		ns.char.legacy = mine
	end
	return mine
end

local function Points(count)
	return count == 1 and "1 Legacy point to spend" or ("%d Legacy points to spend"):format(count)
end

local function Named(config, node)
	local known = names[node]
	if known then return known[1], known[2] end
	local at = C_Traits.GetNodeInfo(config, node)
	local entry = at and at.entryIDs and at.entryIDs[1]
	local info = entry and C_Traits.GetEntryInfo(config, entry)
	local talent = info and info.definitionID and C_Traits.GetDefinitionInfo(info.definitionID)
	if not talent then return nil end
	local name = talent.overrideName or (talent.spellID and C_Spell.GetSpellName(talent.spellID))
	local icon = talent.overrideIcon or (talent.spellID and C_Spell.GetSpellTexture(talent.spellID))
	if not name then return nil end
	names[node] = { name, icon }
	return name, icon
end

-- Reads the trees: points unspent and earned, Talented's ranks, and the order's next talents.
local function Work()
	stale, state = false, nil
	local data = ns.data.legacy
	if not data then return end
	-- A config a tree. None yet: the account hasn't Legacy, or it isn't loaded. Asked again next time.
	local configs = {}
	for index, tree in ipairs(data.trees) do
		configs[index] = C_Traits.GetConfigIDByTreeID(tree[1])
		if not configs[index] then
			stale = true
			return
		end
	end
	local purse = C_Traits.GetTreeCurrencyInfo(configs[1], data.trees[1][1], false)
	purse = purse and purse[1]
	if not purse or issecretvalue(purse.quantity) or issecretvalue(purse.spent) then return end

	local have = {}
	for node, about in pairs(data.nodes) do
		local at = C_Traits.GetNodeInfo(configs[about[1]], node)
		-- A talent whose rank count differs from the data: the trees have changed, say nothing.
		if not at or at.maxRanks ~= about[2] or issecretvalue(at.ranksPurchased) then return end
		have[node] = at.ranksPurchased
	end

	-- The first talent of the order still to buy, and the next few.
	local plan, count = {}, {}
	for _, node in ipairs(data.order) do
		count[node] = (count[node] or 0) + 1
		if count[node] > have[node] then
			local about, last = data.nodes[node], plan[#plan]
			if last and last.node == node then
				last.count = last.count + 1
			elseif #plan <= AHEAD then
				local name, icon = Named(configs[about[1]], node)
				if not name then
					stale = true     -- name not loaded yet: retry next time
					return
				end
				plan[#plan + 1] = { node = node, name = name, icon = icon, tree = _G[data.trees[about[1]][2]],
					rank = have[node] + 1, ranks = about[2], count = 1, why = about[3] }
			else
				break
			end
		end
	end

	state = {
		unspent = purse.quantity, earned = purse.quantity + purse.spent, cap = purse.maxQuantity,
		talented = have[data.talented], ranks = data.nodes[data.talented][2],
		next = plan[1], plan = plan,
	}
end

-- The current state, or nil: { unspent, earned, cap, talented, ranks, next, plan }.
-- next and each of plan: { node, name, icon, tree, rank, ranks, count, why }.
function Legacy.Now()
	if not ready then return nil end
	if stale then Work() end
	return state
end

-- The level a character's talent points start at: the game's own, less a level a rank of Talented.
function Legacy.TalentsFrom()
	local now = Legacy.Now()
	return math.max(1, Constants.LevelConstsExposed.MIN_TALENT_LEVEL - (now and now.talented or 0))
end

-- Challenges

-- The challenges that give a point and aren't done, the nearest done first: { name, have, need }.
-- A challenge counts by its one criterion (a level reached, a skill): what this character has of it.
local function Nearest(most)
	local out, seen = {}, {}
	for _, id in ipairs(ns.data.legacy.challenges) do
		local _, name, _, completed, _, _, _, description = GetAchievementInfo(id)
		local words = description ~= nil and description ~= "" and description or name
		if words and not completed and not seen[words] and GetAchievementNumCriteria(id) == 1 then
			local _, _, done, have, need = GetAchievementCriteriaInfo(id, 1)
			if not done and type(have) == "number" and type(need) == "number" and need > 0 and have > 0 then
				seen[words] = true
				out[#out + 1] = { name = words, have = have, need = need }
			end
		end
	end
	table.sort(out, function(a, b)
		local left, right = a.have / a.need, b.have / b.need
		if left ~= right then return left > right end
		return a.name < b.name
	end)
	for index = #out, most + 1, -1 do out[index] = nil end
	return out
end

-- For the talent row's hover (Spec.lua): how to get talent points sooner, while Talented has ranks
-- left to buy. A hover section, or nil.
function Legacy.Sooner()
	local now = Legacy.Now()
	if not now or now.talented >= now.ranks then return nil end
	local rows = { { glyph = "up", text = "Talented: talent points start at level " ..(Constants.LevelConstsExposed.MIN_TALENT_LEVEL - now.ranks),
		right = ("%d of %d"):format(now.talented, now.ranks), rightColor = C.dim } }
	if now.unspent > 0 then
		rows[2] = { glyph = "note", quiet = true, text = ("You have %s. Talented is in the Legacy window's Adventure tree, after Well Rested."):format(Points(now.unspent):lower()) }
	elseif now.earned < now.cap then
		local near = Nearest(NEAR)
		rows[2] = { glyph = "note", quiet = true, text = #near > 0 and "It costs Legacy points, which all your characters earn together. Closest ones for you:"
			or "It costs Legacy points, which all your characters earn from the Legacy window's challenges." }
		for _, one in ipairs(near) do
			rows[#rows + 1] = { glyph = "star", text = one.name, right = ("%d/%d"):format(one.have, one.need), rightColor = C.dim }
		end
	else
		rows[2] = { glyph = "note", quiet = true, text = "Your Legacy points are spent on other talents. Reset a tree in the Legacy window to move them." }
	end
	return { title = "Talent points sooner", rows = rows }
end

-- On the card

local function Window()
	return LegacySystemFrame ~= nil and LegacySystemFrame:IsShown()
end

-- The row's own click, which the key takes while it is up: so this is a fight, or the window is open.
local function Click()
	if InCombatLockdown() and not Window() then T:Print("can't open Legacy from the card in combat.") end
end

-- Lays Spec.lua's key over the card's row while the mouse is on it (the errand's `over`).
local function Cover(row)
	local spec = ns.Spec
	if spec and spec.KeyOver then spec.KeyOver(row, LegacyMicroButton, "legacy", Window()) end
end

-- A Legacy point to spend as a route errand (R.AddErrand), or nil.
local function Find()
	if not T.db.legacy.on then return nil end
	local now, mine = Legacy.Now(), Mine()
	local talent = now and now.next
	if not talent or not mine or now.unspent <= 0 or (mine.skip or 0) >= now.earned then return nil end
	return {
		title = "Legacy: " .. talent.name,
		lines = {
			talent.ranks > 1 and ("%s  \194\183  rank %d of %d"):format(talent.tree, talent.rank, talent.ranks) or talent.tree,
			Points(now.unspent),
		},
		caption = "LEGACY  \194\183  FOR EVERY CHARACTER",
		mark = "talent",
		menu = function(root)
			root:CreateButton("Ask me at the next point", function()
				Mine().skip = now.earned
				ns.Refresh()
			end)
		end,
		click = Click,
		over = Cover,
		hint = "Open Legacy",
		menuHint = "Not now",
		-- Hover content (CardHover.lua): the order's next talents, the one to take lit, then why it.
		hover = function()
			local rows = {}
			for index, other in ipairs(now.plan) do
				rows[index] = { icon = other.icon, glyph = "star", text = other.name, lit = index == 1 or nil,
					right = other.count > 1 and ("x%d  \194\183  %s"):format(other.count, other.tree) or other.tree, rightColor = C.dim }
			end
			return { { title = Points(now.unspent), rows = rows },
				{ title = "Why " .. talent.name, rows = { { glyph = "note", quiet = true, text = talent.why } } } }
		end,
		tip = function(tip)
			tip:AddLine(talent.why, C.dim[1], C.dim[2], C.dim[3], true)
			tip:AddLine("Click to open Legacy.", C.dim[1], C.dim[2], C.dim[3], true)
		end,
	}
end

-- What was read of the Legacy trees, as text.
function Legacy.Report()
	local now = Legacy.Now()
	local out = { ("Legacy suggestions %s, trait data %s."):format(T.db.legacy.on and "on" or "off", ready and "loaded" or "not loaded yet") }
	if not now then
		out[#out + 1] = "No reading of the Legacy trees: not unlocked on this account, changed since the data was made, or not loaded yet."
		return table.concat(out, "\n")
	end
	out[#out + 1] = ("%d to spend, %d earned of %d. Talented %d of %d: talent points from level %d."):format(now.unspent, now.earned,
		now.cap, now.talented, now.ranks, Legacy.TalentsFrom())
	for index, talent in ipairs(now.plan) do
		out[#out + 1] = ("%d. %s (%s), rank %d of %d%s"):format(index, talent.name, talent.tree, talent.rank, talent.ranks,
			talent.count > 1 and (", %d points"):format(talent.count) or "")
	end
	if #now.plan == 0 then out[#out + 1] = "Every talent of the order is bought." end
	for _, near in ipairs(Nearest(5)) do
		out[#out + 1] = ("Challenge: %s (%d/%d)"):format(near.name, near.have, near.need)
	end
	return table.concat(out, "\n")
end

-- Events

-- Trait events come in bursts: one deferred refresh covers them.
local looking = false
local function Soon()
	if looking then return end
	looking = true
	C_Timer.After(0.3, function()
		looking = false
		-- (Legacy points are an errand's: the errands are fitted again, not the route.)
		if ready and ns.char then ns.RefreshErrands() end
	end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
	"TRAIT_NODE_CHANGED", "ACHIEVEMENT_EARNED" }) do
	events:RegisterEvent(event)
end
local function Changed()
	ready, stale = true, true
	Soon()
end
events:SetScript("OnEvent", Changed)
Shy:On("SHY_SPELLS", Changed)

ns.CardSwitch("suggestions", function(root)
	root:CreateCheckbox("Legacy suggestions", function() return T.db.legacy.on end, function()
		T.db.legacy.on = not T.db.legacy.on
		ns.Apply()
	end)
end)

if R and R.AddErrand then R.AddErrand("legacy", Find, "Legacy talents") end
