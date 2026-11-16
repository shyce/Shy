-- The dungeons step of character setup (Shy.Setup): which dungeons' quests join the guide. Three ways
-- (T.db.guide.dungeonPlan): at your level ("ready": each dungeon's quests come in as you reach the levels
-- the Group Finder suggests, and the ones you tick whatever your level), the ones you tick ("ticked"),
-- or none ("never"). Under the ways stands the gallery: every dungeon and raid the Group Finder lists
-- (Shy.Instances), dungeons by level then raids, each as the game's own picture of it (its loading
-- screen, drawn by file ID and cut to 2:1: nothing shipped), its name, its levels and whether it is in.
-- One the guides have steps for on this faction (ns.Detours, by instance map) is ticked with a click;
-- the rest stand grey until a guide covers them, so the whole road is in view from the start. The picks
-- are profile settings, so a setup that changes profile hands them to Shy.Setup.Wait and they land
-- after the reload (Later), as the immersion step's do.

local _, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Dungeons = {}
ns.Dungeons = Dungeons

-- (Each way's line fits a tile's one line.)
local WAYS = {
	{ value = "ready", name = "At my level", glyph = "up", say = "Each as you reach its level, plus any you tick" },
	{ value = "ticked", name = "The ones I pick", glyph = "star", say = "Only the dungeons ticked below" },
	{ value = "never", name = "None", glyph = "go", say = "No dungeon quests in your guide" },
}
local TILE_H, GAP, BREAK = 58, 8, 10   -- a way's tile (the immersion step's); between tiles and cards; ways to gallery
local PER = 4                          -- cards to a row: 244 wide on the window's page, the picture 2:1
local CAPTION = 18                     -- a caption's height

-- The instances, as Shy.Instances lists them: { map, name, kind ("dungeon" | "raid"), low, high, players,
-- file (the loading screen's, 0 for none), cut = { left, top, right, bottom } }, and for one a guide has
-- steps for on this faction, `dungeon`: its entry in ns.Detours (short name, the settings' key).
local instances
function Dungeons.Instances()
	if instances then return instances end
	instances = {}
	local guided = {}
	for _, dungeon in ipairs(ns.Detours()) do
		if dungeon.map then guided[dungeon.map] = dungeon end
	end
	for _, shared in ipairs(Shy.Instances and Shy.Instances.List() or {}) do
		local one = { map = shared.map, name = shared.name, kind = shared.kind, low = shared.low, high = shared.high,
			players = shared.players, file = shared.file, cut = shared.cut, dungeon = guided[shared.map] }
		if one.dungeon then one.name = one.dungeon.name end
		instances[#instances + 1] = one
	end
	return instances
end
-- (The faction is known at login; a guide the character grows into is read again at the next look.)
ns.OnApply(function() instances = nil end)

-- An instance's levels: a guided dungeon's are the game's or the guides' (ns.DungeonRange); another's
-- the Group Finder's. A raid names its size.
local function Levels(one)
	local low, high = one.low, one.high
	if one.dungeon then low, high = ns.DungeonRange(one.dungeon) end
	local levels = high > 0 and high ~= low and (low .. "-" .. high) or tostring(low)
	if one.kind == "raid" and one.players > 0 then levels = levels .. "  \194\183  " .. one.players .. " players" end
	return levels, low
end

-- An instance's card is its picture (the game's loading screen, cut to 2:1), the name and levels on a dark
-- band at its foot, and a tick when it is in: in color then, grey when not, faded when there are to be
-- no dungeon quests at all or no guide has steps for it yet. Refresh(p) reads the plan's part (or,
-- without one, the live settings).
function Dungeons.Card(parent, width, one, onClick)
	-- (The card itself is the family's: Shy.Instances.Card.)
	local b = Shy.Instances.Card(parent, width, one)
	b.dungeon = one.dungeon

	-- on: in the guide; why: the word for it; dimmed: nothing to choose here
	function b:Paint(on, why, dimmed)
		local levels = Levels(one)
		self:Say(why and (levels .. "  \194\183  " .. why) or levels)
		self:Lit(on, dimmed)
	end
	function b:Refresh(p)
		local way = p and p.plan or T.db.guide.dungeonPlan
		local dungeon = one.dungeon
		if not dungeon then
			self:Paint(false, "no guide yet", true)
			return
		end
		local ticked = p and p.ticked[dungeon.short] or (not p and T.db.guide.dungeons[dungeon.short] == true)
		if way == "never" then
			self:Paint(false, nil, true)
		elseif ticked then
			self:Paint(true, "in your guide", false)
		elseif way == "ready" then
			local _, low = Levels(one)
			if ns.DungeonReady(dungeon) then
				self:Paint(true, "at your level", false)
			elseif UnitLevel("player") < low then
				self:Paint(false, "from level " .. low, false)
			else
				self:Paint(false, "outgrown", false)
			end
		else
			self:Paint(false, nil, false)
		end
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(one.dungeon)
	end)
	b:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
		local words
		if not one.dungeon then
			words = "No guide steps for it yet. They'll come in a later update."
		else
			words = ("Puts its quests in your guide: where to pick them up, what to do inside and where to turn them in. Click to %s."):format(
				self.on and "take it out" or "keep it in at any level")
		end
		UI.Tip(self, one.name, words, { side = "RIGHT" })
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		UI.SetBorder(self, self.on and C.hot or C.border)
		UI.TipHide(self)
	end)
	return b
end

-- The step's page: the three ways as tiles across the top, the gallery under them, four cards to a row.
-- The plan's part is read each time, never kept: setup plans again in place every time it opens, and a page
-- holding the part it was built with would change one nobody reads any more.
local function Page(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local function P() return plan.dungeons end
	local each = (width - 2 * GAP) / #WAYS
	local ways = {}
	for i, way in ipairs(WAYS) do
		local tile = Shy.Setup.Tile(f, each, nil, way.name, function()
			local p = P()
			p.plan, p.touched = way.value, true
			f:Refresh()
		end, TILE_H)
		Shy.Hover.Glyph(tile.glyph, way.glyph)
		tile.say:SetText(way.say)
		tile:SetPoint("TOPLEFT", (i - 1) * (each + GAP), 0)
		tile.value = way.value
		ways[i] = tile
	end
	local y = TILE_H + BREAK
	local cardW = math.floor((width - (PER - 1) * GAP) / PER)
	local cardH = math.floor(cardW / 2 + 0.5)
	local cards = {}
	local function Tick(d)
		local p = P()
		p.ticked[d.short] = not p.ticked[d.short] or nil
		p.touched = true
		f:Refresh()
	end
	-- Dungeons, then raids, each under a caption, four to a row.
	for _, kind in ipairs({ { "dungeon", "DUNGEONS" }, { "raid", "RAIDS" } }) do
		local count = 0
		for _, one in ipairs(Dungeons.Instances()) do
			if one.kind == kind[1] then
				if count == 0 then
					local caption = UI.Text(f, kind[2], 11, true, C.dim)
					caption:SetPoint("TOPLEFT", 0, -y)
					y = y + CAPTION
				end
				local card = Dungeons.Card(f, cardW, one, Tick)
				card:SetPoint("TOPLEFT", (count % PER) * (cardW + GAP), -y - math.floor(count / PER) * (cardH + GAP))
				cards[#cards + 1] = card
				count = count + 1
			end
		end
		if count > 0 then y = y + math.ceil(count / PER) * (cardH + GAP) - GAP + BREAK end
	end
	f:SetSize(width, y - BREAK)
	f.ways, f.cards = ways, cards

	function f:Refresh()
		local p = P()
		for _, tile in ipairs(ways) do
			tile:Paint(tile.value == p.plan, tile.value == "ready" and "recommended" or false, false, C.good)
		end
		for _, card in ipairs(cards) do card:Refresh(p) end
	end
	f:Refresh()
	return f
end

-- The plan starts from the settings: the way, and what is ticked. A character that never chose (the
-- shipped way with nothing ticked) is recommended its level's dungeons.
local function Plan(plan)
	local db = T.db.guide
	local ticked = {}
	for short, on in pairs(db.dungeons or {}) do
		if on == true then ticked[short] = true end
	end
	local way = db.dungeonPlan
	if way == "ticked" and next(ticked) == nil then way = "ready" end
	plan.dungeons = { plan = way, ticked = ticked, touched = false }
end

local function Named(ticked)
	local names = {}
	for _, dungeon in ipairs(ns.Detours()) do
		if ticked[dungeon.short] then names[#names + 1] = dungeon.name end
	end
	return table.concat(names, ", ")
end

local function Lines(plan)
	local p = plan.dungeons
	local named = Named(p.ticked)
	if p.plan == "never" then return { { text = "No dungeon quests" } } end
	if p.plan == "ready" then
		local lines = { { text = "Dungeon quests at your level", sub = "each one once you reach its Group Finder level" } }
		if named ~= "" then lines[2] = { text = "At any level: " .. named } end
		return lines
	end
	if named == "" then return { { text = "No dungeon ticked", sub = "tick some in the options any time" } } end
	return { { text = "Dungeon quests: " .. named } }
end

-- Writes the way and the ticks into the settings; a ticked dungeon put off before comes back.
local function Apply(answers)
	local db = T.db.guide
	if answers.plan then db.dungeonPlan = answers.plan end
	if answers.ticked then
		wipe(db.dungeons)
		for short in pairs(answers.ticked) do
			db.dungeons[short] = true
			ns.Unsnooze(short)
		end
	end
	ns.Apply()
end

local function Run(plan)
	local p, act = plan.dungeons, Shy.Setup.Act(plan)
	-- Joining a profile keeps its dungeons unless the page was touched.
	if act == "use" and not p.touched then return false end
	local answers = { plan = p.plan, ticked = p.ticked }
	if act == "stay" then Apply(answers) else Shy.Setup.Wait("dungeons", answers) end
	return false
end

Dungeons.Step = {
	id = "dungeons", order = 24, title = "Dungeons", glyph = "kill",
	ask = function() return ("Pick the dungeons you'll run, %s"):format(UnitName("player")) end,
	lead = "Their quests go into your guide, with where to pick them up, what to do inside and where to hand them in.",
	brief = function(plan)
		local p = plan.dungeons
		if p.plan == "never" then return "None" end
		if p.plan == "ready" then return "At your level" end
		local n = 0
		for _, dungeon in ipairs(ns.Detours()) do
			if p.ticked[dungeon.short] then n = n + 1 end
		end
		return n == 0 and "None ticked" or n == 1 and "1 dungeon" or (n .. " dungeons")
	end,
	Plan = Plan,
	Build = Page,
	Lines = Lines,
	Run = Run,
	Later = Apply,
}
-- (The tests load the core without its setup window.)
if Shy.Setup then Shy.Setup.Step(Dungeons.Step) end
