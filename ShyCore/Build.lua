-- Your talent build: which of your class's leveling builds you play (Data/Builds.lua, from the client's trees),
-- read from the talents you have bought, and the one you picked to follow. Every addon asks here.
--
--   Shy.Build.Played()     the build your talents are now: { id, name, role, goal, tab }, or nil for a class with none.
--   Shy.Build.Spent()      how many talent points are spent: with none, Played is only the build the class starts with
--   Shy.Build.Planned(plan)   the build a setup's plan holds, as Played gives one: what the player picked there
--                          Your pick while your talents still fit it (or none are bought yet), else the build
--                          they fit best: what your keys, your role and your gear go by.
--   Shy.Build.Followed()   the build the talent suggestions follow: your pick, else the one your talents fit best
--   Shy.Build.Now()        the reading, or nil before the game has its talents: { unspent, spent, earned, off, offs,
--                          build (followed), played, fits, chosen, name, why, note, tree, treeIcon, config, treeID,
--                          group, next, plan, ended, strayed, want, over }. next and each of plan: { node, name, icon,
--                          tab, row, rank, ranks, count }. want[node]: the ranks the followed build puts in a talent;
--                          over[node]: the ranks you hold there past it.
--   Shy.Build.Class()      this class's tree and builds: { tree, tabs, nodes, builds }, or nil
--   Shy.Build.Tabs()       the tree's three tabs as the talent window names them: { { name, icon }, ... }, or nil
--   Shy.Build.Icon(build)  its tab's icon (Holy's, Retribution's), from the start
--   Shy.Build.Find(id)     one of the class's builds by id
--   Shy.Build.Picked()     the id you picked, or nil (follow what your talents fit)
--   Shy.Build.Choose(id)   picks one to follow (nil: whatever your talents fit)
--   Shy.Build.Stale()      the talents are to be read again (one was just bought)
--   Shy.Build.Builds()     the class's builds for a picker: { { build, tag, on, reset } }
--   Shy.Build.Pick(id)     picks one from a menu or the settings: followed, and the cooldown manager laid out for it
--   Shy.Build.Lineup(id)   the cooldown manager laid out for a build: true once written (it shows after a reload)
--   Shy.Build.Over(want, have)   the ranks you hold in a talent past what your build puts there (0: none)
--   Shy.Build.OverSays(name, want, have, reset)   what that talent's hover says: { { text, color }, ... }. reset:
--                          the window has a Reset of its own
--   Shy.Build.OverRing(parent, out)   the crimson frame such a talent wears on the game's window, out past its edge
-- SHY_BUILD is said when the build you play changes, and when you pick one ("picked").
-- Picking one is here too: setup's first question (its "Play as" step), the /shy window's Play room, and
-- Leveling build in the core's settings.
--
-- C_Traits has no data until the spellbook is first read (SHY_SPELLS) or a trait event has fired.

local P = Shy.Profiles

local B = {}
Shy.Build = B

B.STRAYED = 5                -- more points than this outside a build: your talents aren't that build
B.AHEAD = 3                  -- talents listed after the next one

local ready = false          -- spell or trait data has loaded
local stale = true
local state                  -- the last reading, or nil
local names = {}             -- node -> { name, icon }
local tabs                   -- the tree's three tabs
local counts = {}            -- build -> { [node] = ranks its order puts there }
local told                   -- the played build's id as last said (SHY_BUILD)

function B.Class()
	local all = Shy.TalentBuilds
	local class = UnitClassBase("player")
	return all and class and all[class] or nil
end

function B.Find(id)
	local spec = B.Class()
	for _, build in ipairs(spec and spec.builds or {}) do
		if build.id == id then return build end
	end
end

-- Your picks, by character.
local function Picks()
	local db = ShyCoreDB
	db.builds = db.builds or {}
	return db.builds
end

function B.Picked()
	local id = Picks()[P.Character()]
	return B.Find(id) and id or nil
end

-- The ranks a build's order puts in each talent.
local function Counts(build)
	local most = counts[build]
	if most then return most end
	most = {}
	for _, node in ipairs(build.order) do most[node] = (most[node] or 0) + 1 end
	counts[build] = most
	return most
end

-- A talent's name and picture. The game gives an empty override as "" and 0, not nil: the spell's own then. nil
-- while its data hasn't come (asked again next time; only a name found is kept).
local function Named(config, node)
	local known = names[node]
	if known then return known[1], known[2] end
	local at = C_Traits.GetNodeInfo(config, node)
	local entry = at and ((at.activeEntry and at.activeEntry.entryID) or (at.entryIDs and at.entryIDs[1]))
	local info = entry and C_Traits.GetEntryInfo(config, entry)
	local talent = info and info.definitionID and C_Traits.GetDefinitionInfo(info.definitionID)
	if not talent then return nil end
	local spell = talent.spellID
	local name = (talent.overrideName ~= "" and talent.overrideName) or (spell and C_Spell.GetSpellName(spell))
	local icon = (talent.overrideIcon ~= 0 and talent.overrideIcon) or (spell and C_Spell.GetSpellTexture(spell))
	if not name or name == "" then return nil end
	names[node] = { name, icon }
	return name, icon
end

-- A build's tab icon: the client's own for that tab (Data/Builds.lua), there from the start.
function B.Icon(build)
	local spec = build and B.Class()
	return spec and spec.icons and spec.icons[build.tab] or nil
end

function B.Tabs()
	if tabs then return tabs end
	local spec = B.Class()
	if not spec then return nil end
	local out = {}
	for _, shown in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(spec.tree) or {}) do
		for index, group in ipairs(spec.tabs) do
			if shown.groupID == group then out[index] = { name = shown.displayName, icon = shown.icon } end
		end
	end
	if not (out[1] and out[2] and out[3]) then return nil end
	tabs = out
	return out
end

-- One talent of the order: name, tab and row, and the rank the next point buys. ranks: the game's count where it
-- gives one. A name not come yet stands in as its tab's.
local function Entry(spec, config, node, have, count, ranks)
	local name, icon = Named(config, node)
	local about = spec.nodes[node]
	local tab = B.Tabs()[about[1]]
	return { node = node, name = name or tab.name, icon = icon or tab.icon, tab = tab.name, row = about[2],
		rank = have + 1, ranks = ranks or about[3], count = count }
end

-- Reads the tree: ranks bought, points unspent, the builds, and the followed one's next talents.
local function Work()
	stale, state = false, nil
	local spec = B.Class()
	if not spec then return end
	local config = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	local info = config and C_Traits.GetConfigInfo(config)
	if not info then
		stale = true         -- talents not loaded yet: retry next time
		return
	end
	-- A different tree than the builds were written for: say nothing.
	if info.treeIDs[1] ~= spec.tree or not B.Tabs() then return end
	local purse = C_Traits.GetTreeCurrencyInfo(config, spec.tree, false)[1]
	if not purse or issecretvalue(purse.quantity) then return end
	local unspent = purse.quantity

	-- One talent the game has otherwise than the data (hidden, or another count of ranks) leaves the rest read: it
	-- counts as the game has it. Only another tree says nothing.
	local have, can, most, spent = {}, {}, {}, 0
	local telling = false        -- canPurchaseRank is true for at least one node
	for _, node in ipairs(C_Traits.GetTreeNodes(spec.tree) or {}) do
		local at = C_Traits.GetNodeInfo(config, node)
		local ranks = at and at.ranksPurchased or 0
		if issecretvalue(ranks) then return end
		have[node], can[node] = ranks, at ~= nil and at.canPurchaseRank == true
		if at and at.ID ~= 0 and type(at.maxRanks) == "number" and at.maxRanks > 0 then most[node] = at.maxRanks end
		telling = telling or can[node]
		spent = spent + ranks
	end
	for node in pairs(spec.nodes) do
		have[node] = have[node] or 0
	end

	-- The followed build: your pick, else the one the talents bought fit best (the first of equals, so the one for
	-- questing alone while nothing is bought). offs: points outside each build, by id.
	local offs, build, fits = {}, nil, nil
	local picked = B.Picked()
	for _, one in ipairs(spec.builds) do
		local most, off = Counts(one), 0
		for node, ranks in pairs(have) do
			if ranks > (most[node] or 0) then off = off + ranks - (most[node] or 0) end
		end
		offs[one.id] = off
		if one.id == picked then build = one end
		if not fits or off < offs[fits.id] then fits = one end
	end
	local chosen = build ~= nil
	build = build or fits
	local off = offs[build.id]
	-- The build you play: the followed one while your talents fit it, else the one they fit.
	local played = (spent == 0 or off <= B.STRAYED) and build or fits

	-- The talents of the order still to buy, the next few. Their prerequisites are the order's earlier talents, so
	-- the first should be purchasable. Where the game says it isn't while it says another of the order is (the tree
	-- isn't quite what the data says), the first it allows leads and the rest keep the order's turns after it. If no
	-- node reports purchasable, the flag isn't trusted. A name not come yet stands in as its tab's for now, and the
	-- tree is read again on the next ask: the reading is never held back for one.
	local lead
	if unspent > 0 and telling then
		local seen = {}
		for _, node in ipairs(build.order) do
			seen[node] = (seen[node] or 0) + 1
			if seen[node] > have[node] and can[node] then
				lead = node
				break
			end
		end
	end
	local plan, count, left, waiting = {}, {}, 0, false
	for _, node in ipairs(build.order) do
		count[node] = (count[node] or 0) + 1
		if count[node] > have[node] then
			left = left + 1
			local last = plan[#plan]
			if last and last.node == node and #plan <= B.AHEAD + 1 and not plan.full then
				last.count = last.count + 1
			elseif plan.full then
				-- Past the ones listed: only counted.
			elseif #plan <= B.AHEAD then
				if not Named(config, node) then waiting = true end
				plan[#plan + 1] = Entry(spec, config, node, have[node], 1, most[node])
			else
				plan.full = true
			end
		end
	end
	plan.full = nil
	if lead and plan[1] and plan[1].node ~= lead then
		for i = 2, #plan do
			if plan[i].node == lead then
				table.insert(plan, 1, table.remove(plan, i))
				break
			end
		end
	end

	-- The talents you hold past the followed build.
	local want, over = Counts(build), {}
	for node, ranks in pairs(have) do
		if ranks > (want[node] or 0) then over[node] = ranks - (want[node] or 0) end
	end

	local tree = B.Tabs()[build.tab]
	state = {
		unspent = unspent, spent = spent, earned = spent + unspent, off = off, offs = offs,
		build = build, played = played, fits = fits, chosen = chosen, name = build.name, why = build.why, note = build.note,
		tree = tree.name, treeIcon = tree.icon,
		config = config, treeID = spec.tree, group = spec.tabs[build.tab],
		next = plan[1], plan = plan,
		-- The order has no talent left to name: every one is bought.
		ended = left == 0,
		strayed = off > B.STRAYED,
		want = want, over = over,
	}
	if waiting then stale = true end
end

function B.Now()
	if not ready then return nil end
	if stale then Work() end
	return state
end

function B.Stale()
	stale = true
end

-- A talent you hold past your build: bought before the build changed, or by hand. Every talent window marks it
-- the same way, crimson, and its hover says the same words.
function B.Over(want, have)
	return math.max(0, (have or 0) - (want or 0))
end

function B.OverSays(name, want, have, reset)
	local C = Shy.UI.colors
	local over = B.Over(want, have)
	if over == 0 then return {} end
	local first = (want or 0) == 0 and ("%s doesn't take this."):format(name)
		or ("%s takes %d of your %d ranks."):format(name, want, have)
	local point = over == 1 and "the point" or ("the %d points"):format(over)
	local second = reset and ("Reset frees %s. Then follow the numbers."):format(point)
		or ("Reset your talents to move %s."):format(point)
	return { { text = first, color = C.bad }, { text = second, color = C.dim } }
end

function B.OverRing(parent, out)
	local Skin = Shy.Skin
	local slice = Skin.FRAME_SLICE
	local ring = parent:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(Skin.FRAME)
	ring:SetTextureSliceMargins(slice, slice, slice, slice)
	ring:SetPoint("TOPLEFT", -out, out)
	ring:SetPoint("BOTTOMRIGHT", out, -out)
	Shy.UI.Tint(ring, Shy.UI.colors.bad)
	return ring
end

function B.Followed()
	local now = B.Now()
	if now then return now.build end
	local spec = B.Class()
	if not spec then return nil end
	return B.Find(B.Picked()) or spec.builds[1]
end

local function Plain(build)
	if build then return { id = build.id, name = build.name, role = build.role, goal = build.goal, tab = build.tab } end
end

function B.Played()
	local now = B.Now()
	return Plain(now and now.played or B.Followed())
end

-- How many talent points are spent: 0 for a character with none yet, whose build (B.Played) is then only the one
-- its class starts with, not anything its talents say.
function B.Spent()
	local now = B.Now()
	return now and now.spent or 0
end

-- The build a setup's plan holds: what setup's other steps go by (the layout a healer or a tank gets), before it
-- is chosen for good.
function B.Planned(plan)
	return Plain(B.Find(plan and plan.talents and plan.talents.build))
end

-- Says SHY_BUILD when the build you play isn't the one last said, or (why: "picked") whatever it is.
local function Tell(why)
	local played = B.Played()
	local id = played and played.id
	if why or id ~= told then
		told = id
		Shy:Fire("SHY_BUILD", why)
	end
end

function B.Choose(id)
	Picks()[P.Character()] = B.Find(id) and id or nil
	stale = true
	Tell("picked")
end

-- Talent and spellbook events come in bursts: one look after them covers them.
local looking = false
local Look = Shy.Clocked("ShyCore build", function()
	looking = false
	Tell()
end)
local function Changed()
	ready, stale = true, true
	if looking then return end
	looking = true
	C_Timer.After(0.3, Look)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
	"TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
	"PLAYER_LEVEL_UP" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", Changed)
Shy:On("SHY_SPELLS", Changed)

---------------------------------------------------------------------------
-- Picking one: a menu, the core's settings, the setup window's step
---------------------------------------------------------------------------

local UI = Shy.UI
local C = UI.colors

-- What a build is for, in a word or two. first: the class's first, the one for questing alone.
local function Tag(build, first)
	if first then return "recommended" end
	if build.goal == "pvp" then return "PvP" end
	if build.goal ~= "dungeon" then return "questing" end
	return build.role == "healer" and "dungeon healer" or build.role == "tank" and "dungeon tank" or "dungeons"
end

-- reset: the talents already bought don't fit it, so it would take a reset at a trainer.
function B.Builds()
	local spec, now, current = B.Class(), B.Now(), B.Followed()
	local out = {}
	for index, build in ipairs(spec and spec.builds or {}) do
		out[index] = { build = build, tag = Tag(build, index == 1), on = build == current,
			reset = now ~= nil and now.offs[build.id] > B.STRAYED }
	end
	return out
end

-- (Guarded: the loaded core's Lineup.lua is older than this file until the client restarts.)
function B.Lineup(id)
	local lineup = Shy.Lineup
	if not (lineup and lineup.Has(id)) then return false end
	local one = B.Find(id)
	local ok, why = lineup.Write(id, one and one.name)
	if not ok then Shy.core:Print(why) end
	return ok
end

local RELOAD = "Your cooldown manager is laid out for your build. Reload to see it."

function B.Pick(id)
	B.Choose(id)
	Shy.Settings.Refresh()
	if B.Lineup(id) then Shy.Reload(RELOAD) end
end
B.RELOAD = RELOAD

Shy.core:Settings({
	{ section = "Talents", shown = function() return #B.Builds() >= 2 end },
	{ label = "Leveling build", words = "spec talents build", shown = function() return #B.Builds() >= 2 end,
		default = function()
			local first = B.Builds()[1]
			return first and first.build.id
		end,
		items = function()
			local items = {}
			for index, one in ipairs(B.Builds()) do
				items[index] = { value = one.build.id, text = ("%s  (%s)"):format(one.build.name, one.tag) }
			end
			return items
		end,
		get = function()
			local build = B.Followed()
			return build and build.id
		end,
		set = function(v) B.Pick(v) end,
		desc = "How you'll play while leveling. Your keys, role and gear advice go by it. If your talents don't fit, a class trainer can reset them." },
})

-- What to play: the class's builds as choice tiles, each with its tree's icon, what it is for, why, and its
-- caution. In setup (a plan) the pick is kept in plan.talents.build, and the steps that go by it are told
-- (Setup.Follow). With no plan (the /shy window's Play room) a click picks it at once.
--   B.Tiles(parent, width, plan, opts)   opts.per: tiles to a row (2); opts.caption: a caption over them;
--                                        opts.picked(build): after a click; opts.asked: a question still open
--                                        (the welcome), so none is lit until one is picked or a point is spent
-- TILE: a tile's height (a why of two lines and a caution of two); GAP: between tiles; CAPTION: a caption's room.
local TILE, GAP, CAPTION = 96, 8, 22

-- A build your talents don't fit: said as a catch on its card.
local RESET = "Needs a talent reset at your trainer."
-- A build's kind, the game's own role icon for it and its word: what it does in a fight.
local ROLE = { damage = { "roleicon-tiny-dps", "Damage" }, healer = { "roleicon-tiny-healer", "Healer" },
	tank = { "roleicon-tiny-tank", "Tank" } }

function B.Tiles(parent, width, plan, opts)
	opts = opts or {}
	local spec = B.Class()
	local builds = spec and spec.builds or {}
	local per = opts.per or math.max(1, math.min(#builds, 4))
	local each = (width - (per - 1) * GAP) / per
	local top = opts.caption and CAPTION or 0
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, top + math.ceil(#builds / per) * (TILE + GAP) - GAP)
	if opts.caption then
		f.caption = UI.Text(f, opts.caption:upper(), 11, true, C.dim)
		f.caption:SetPoint("TOPLEFT")
	end
	local function Held()
		if plan then
			local talents = plan.talents
			if opts.asked and B.Spent() == 0 and not (talents and talents.picked) then return nil end
			return talents and talents.build
		end
		local build = B.Followed()
		return build and build.id
	end
	f.tiles = {}
	for index, build in ipairs(builds) do
		local tile = Shy.Setup.Tile(f, each, nil, build.name, function()
			if plan then
				plan.talents = plan.talents or {}
				plan.talents.build, plan.talents.picked = build.id, true
				if Shy.Setup.Follow then Shy.Setup.Follow(plan) end
			else
				B.Pick(build.id)
			end
			f:Refresh()
			if opts.picked then opts.picked(build) end
		end, TILE, true, true)
		tile.say:SetText(build.why)
		local role = ROLE[build.role]
		if role and tile.SetKind then tile:SetKind(role[1], role[2]) end
		f.tiles[index] = tile
	end
	-- Cards stand as tall as the tallest one's words, a row of them a line (again as their catches change).
	local function Lay()
		local tall = TILE
		for _, tile in ipairs(f.tiles) do
			if tile.Fit then tall = math.max(tall, tile:Fit()) end
		end
		for index, tile in ipairs(f.tiles) do
			tile:SetHeight(tall)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", ((index - 1) % per) * (each + GAP), -top - math.floor((index - 1) / per) * (tall + GAP))
		end
		f:SetHeight(top + math.ceil(#builds / per) * (tall + GAP) - GAP)
	end
	function f:Refresh()
		local held = Held()
		for index, one in ipairs(B.Builds()) do
			local tile = self.tiles[index]
			tile:SetIcon(B.Icon(one.build))
			-- Its tag is its own word; that it takes a talent reset is a catch, said with the others.
			local note = one.build.note
			if one.reset then note = RESET .. (note and ("\n" .. note) or "") end
			tile.note:SetText(note or "")
			tile:Paint(one.build.id == held, one.tag, false, index == 1 and C.hot or nil)
			-- (asked on the welcome: once one is picked, the others step back)
			if opts.asked and held and one.build.id ~= held then tile:SetAlpha(0.5) end
		end
		Lay()
	end
	Lay()
	return f
end

local function Picked(plan)
	for _, one in ipairs(B.Builds()) do
		if one.build.id == plan.talents.build then return one.build end
	end
end

-- Setup's first question, before the theme and the screen: the layout, the keys and the gear advice go by it.
B.Step = {
	id = "talents", order = 12, title = "Play as", glyph = "up", guided = true,
	ask = "What do you want to play?",
	brief = function(plan)
		local build = Picked(plan)
		return build and build.name
	end,
	-- (Told once there is something to tell: a point spent, or a pick made in this setup. Before that the build
	-- is only the one the class starts with.)
	told = function(plan) return B.Spent() > 0 or (plan.talents ~= nil and plan.talents.picked == true) end,
	why = function(plan)
		local build, played = Picked(plan), B.Played()
		if not build or (plan.talents and plan.talents.picked) then return nil end
		return B.Spent() > 0 and played and played.id == build.id and "based on your talents" or nil
	end,
	-- When the talent points start: level 10, or sooner with the account's Talented (ShyQuest knows it).
	lead = function()
		local quest = Shy.addons.Quest
		local from = quest and quest.TalentsFrom and quest:TalentsFrom() or 10
		if UnitLevel("player") >= from then return "Your layout, keys and gear advice go by it. You can change it any time in /shy." end
		return ("Your layout, keys and gear advice go by it. Talent points start at level %d."):format(from)
	end,
	-- (picked: the player chose it in this setup, so it counts whatever the talents say yet. A plan filled again
	-- keeps such a pick.)
	Plan = function(plan)
		local was = plan.talents
		if was and was.picked and B.Find(was.build) then return end
		local build = B.Followed()
		plan.talents = { build = build and build.id }
	end,
	Build = function(parent, width, plan) return B.Tiles(parent, width, plan) end,
	Lines = function(plan)
		local build = Picked(plan)
		if not build then return {} end
		local lines = { { text = "Leveling build: " .. build.name, sub = build.why } }
		if Shy.Lineup and Shy.Lineup.Has(build.id) then
			lines[2] = { text = "Cooldown manager laid out for " .. build.name, sub = "main abilities first, buffs you keep up as bars" }
		end
		-- A tank's or a healer's build says how threat reads: on the nameplates and the threat meter.
		if build.role == "tank" then
			lines[#lines + 1] = { text = "Nameplates and threat treat you as a tank", sub = "green while you hold aggro, red as you lose it" }
		elseif build.role == "healer" then
			lines[#lines + 1] = { text = "Nameplates and threat treat you as a healer", sub = "green while the tank holds aggro, red once it turns on you" }
		end
		return lines
	end,
	-- Kept with the character, not in a profile: there is nothing to wait for. The cooldown manager's lineup
	-- shows after the reload that ends the setup.
	Run = function(plan)
		if not Picked(plan) then return false end
		plan.talents.picked = nil   -- (chosen for good now: the next plan reads it as any other)
		B.Choose(plan.talents.build)
		return B.Lineup(plan.talents.build)
	end,
}
-- (The tests load the core without its setup window.)
if Shy.Setup then Shy.Setup.Step(B.Step) end

-- The /shy window's Play room: the same tiles first, a click picking the build at once.
if Shy.Setup and Shy.HubSection then
	Shy.HubSection("play", function(page, top)
		if #B.Builds() < 2 then return nil end
		local section = B.Tiles(page, page.width, nil, { caption = "What you play" })
		Shy.HubPlace(page, section, top)
		return section, function() section:Refresh() end
	end, 5)
end
