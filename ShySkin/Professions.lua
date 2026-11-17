-- The professions window: a window of our own in place of the game's (ProfessionsFrame, in load-on-demand
-- Blizzard_Professions). The game's window stays the panel the game opens and closes (a profession's spell, the
-- professions key, a recipe link, Escape), emptied and taking no mouse: every piece of it goes to the attic
-- (Shop.lua). Ours is a child of it, so it opens and closes with it, in a fight too, and its size never changes.
--
-- Two pages. Your professions: a card for each primary profession on its painting, with its skill and its spells,
-- and one each for Cooking, Fishing and First Aid; a slot you haven't filled says what to do, in the game's words.
-- A profession's recipes, a workbench:
--   the band: your rank and your skill to its cap, a glow on the bar for where Create all should take you;
--   the list: its own filter (All, Can make, Skill-ups, To learn, and with the auction house's prices Profit: the
--   recipes you know that pay, best first, then the ones you could learn now that would, each with its profit), then
--   your favorites and the game's categories
--   under the family's group heads (a category with a point to gain washed from the left in the best color in it),
--   each recipe's name in the game's difficulty color with the chance of a point and how many you can make;
--   the recipe on a stage: the profession's painting under a light, what it makes in its quality's color, star and
--   pin; where it takes your skill (its colors laid over the ranks, you on them); what it needs nearby, and the
--   recipe that builds it when you know one; its reagents, have against need and the bank's count (and, with prices,
--   what they cost); what it is worth: what it sells for against its reagents, what you lack and whether your gold
--   covers it, a recipe you don't know's own price and the crafts that pay it back; what it makes
--   as the game describes it; the foot: a count you step or type, the skill it should give, Create all, Create; while making,
--   the batch on one bar, a piece for each, the ones that gave a point lit; for a recipe you don't know yet, where
--   to learn it.
-- Down the right edge, tabs as the spellbook's: your professions, then each one with recipes, its skill under it.
--
-- Opening a profession and a profession's spells are casts, so those buttons are secure, and like the spellbook the
-- window can't be dragged in a fight. Crafting is the game's C_TradeSkillUI.CraftRecipe from our button's click; an
-- enchant is cast (the cursor then asks for the item), as enchanting is done.
-- Built out of a fight: a window first loaded in one stays the game's until it ends.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Skin = Shy.Skin
local Slot = Shy.Slot
local B = Shy.Brand
local C = UI.colors
local Shop = ns.Shop
local HEAD = UI.HEAD.window
local TAB = ns.SIDE_TAB

local L = {
	w = 800, h = 580, pad = 10,
	band = 34,               -- the head band under the title strip: rank, skill, what's ahead
	key = 22, barIn = 3,     -- its row (Link's height) and the skill bar's inset from the row's top and foot
	bandGap = 12,            -- between the rank, the bar, what's ahead and Link
	list = 292,              -- the list's width
	seg = 24,                -- its filter
	head = 28, fold = 20, row = 30, rowGap = 2, groupTop = 3, groupFoot = 4, between = 4,   -- a group's head and its fold, a recipe row
	rail = 17, branch = 26, indent = 28,   -- the group's rail, where a branch ends, where its rows begin
	gap = 20,                -- between the list and the recipe
	right = 16,              -- the recipe's and the band's right margin: what stands at the right hangs from it
	out = 62, reag = 34,     -- the made item's slot, a reagent's
	cardH = 44,              -- a reagent's card (two a row share the recipe's width)
	foot = 28,
	qty = 96, step = 28,     -- the count's plate, and a step on either end of it
	create = 112, createAll = 132,   -- Create, and Create all beside it
	most = 999,              -- the most a count may be
	batch = 7,               -- the batch's bar
	cut = 5, cutEvery = { 1, 5, 10, 25, 50, 100, 250 },   -- the least room between its cuts, and the steps they may take
	pane = 148, cardGap = 8, -- a primary profession's card, and between two cards
	cardIn = 14, cardIcon = 36, -- a card's inset, its profession's picture
	spell = 34,              -- a profession spell's slot
}
L.head0 = HEAD.line + UI.LINE   -- the header's foot
L.segTop = L.head0 + L.band + 8
L.listTop = L.segTop + L.seg + 6
L.detail = L.pad + L.list + L.gap + 9
L.top = L.head0 + 46
local ICON = Shop.ICON
local DIFF = Enum.TradeskillRelativeDifficulty
-- The game's own colors, what each says about a point, and which is best.
local DIFFICULTY = {
	[DIFF.Optimal] = { DIFFICULT_DIFFICULTY_COLOR, "Always a skill-up", 1 },
	[DIFF.Medium] = { FAIR_DIFFICULTY_COLOR, "Usually a skill-up", 2 },
	[DIFF.Easy] = { EASY_DIFFICULTY_COLOR, "Sometimes a skill-up", 3 },
	[DIFF.Trivial] = { TRIVIAL_DIFFICULTY_COLOR, "No skill-up", 4 },
}
local BAND = { DIFF.Optimal, DIFF.Medium, DIFF.Easy, DIFF.Trivial }   -- the ribbon's colors, left to right
local MODES = { "all", "make", "ups", "learn", "profit" }
local WORDS = {
	modes = { "All", "Can make", "Skill-ups", "To learn" },
	favorites = "Favorites", ahead = "All %d should take you to |cffffffff%d|r", learnAhead = "Orange for you until |cffffffff%d|r",
	up = "%s went up to |cffffffff%d|r", ups = "Skill-ups", point = "%d gives a skill-up", points = "%d give a skill-up",
	noPoints = "No skill-ups left", ready = "%d you can make now", recipes = "%d to learn", you = "You, %d",
	always = "A point every time until |cffffffff%d|r.", now = "%d%% right now", grey = "grey at %d",
	learnOdds = "Orange the day you learn it: a point every time until |cffffffff%d|r.",
	needs = "Needs", reagents = "Reagents", enough = "enough for %d", makes = "What it makes", bank = "%d in your bank",
	build = "Build one: %s", createAll = "Create all (%d)", createNone = "Create all", worth = "About |cffffffff+%d|r skill",
	making = "Making %d of %d", secLeft = "%d sec left", minLeft = "%d min left", learn = "How to learn it",
	short = "Short of reagents", missing = "Something it needs is missing", needsA = "Needs %s",
	favorite = "Favorite", unfavorite = "Not a favorite", track = "Track", untrack = "Stop tracking",
	trackSay = "Its reagents count up on your screen as you gather them.",
	link = "Link", post = "Post it in", theirs = "%s [%s]",
	profit = "Profit", forProfit = "Make for profit", learnProfit = "Learn for profit", paying = "%d make a profit",
	worthHead = "Worth", gain = "Profit %s", loss = "Loss %s", unpriced = "Not priced yet", sells = "Sells for",
	vendorPays = "A vendor pays", reagentsCost = "Reagents", profitCell = "Profit", lossCell = "Loss", noPrice = "No price",
	afterCut = "after the house's %d%% cut", lack = "You lack %s of them",
	lackPoor = "You lack %s of them, more than you have", recipeCost = "The recipe costs %s", payback = ", paid back in %d",
}
-- The secondary professions' cards: the game's painting and words for each.
local SECONDARY = {
	cook = { "Profession-overview-card-generic-cooking", "PROFESSIONS_COOKING", "PROFESSIONS_COOKING_MISSING" },
	fish = { "Profession-overview-card-generic-fishing", "PROFESSIONS_FISHING", "PROFESSIONS_FISHING_MISSING" },
	aid = { "Profession-overview-card-generic-firstaid", "PROFESSIONS_FIRST_AID", "PROFESSIONS_FIRST_AID_MISSING" },
}

local M              -- the module
local own = { waiting = {} }   -- our frames, made once; items asked of the server, drawn again once they come
local folds = {}     -- group -> folded, for the session
local prof           -- the profession open
local heads = {}     -- its groups in the list's order: { key, name, recipes }
local tally = { all = 0, make = 0, ups = 0 }   -- what each filter would show (the learned ones)
local picked         -- the recipe shown
local count = 1      -- how many Create makes
local making         -- crafting: { recipe, total, skill (at the start), last (skill), ups (craft -> gave a point), icon, color, span (a cast's seconds) }
local page = "book"  -- "book" (your professions) or "craft" (a profession's recipes)
local mode = "all"   -- the list's filter
local mouse          -- the game's window took the mouse before we emptied it
local seen = {}      -- professionID -> the skill last drawn, so a point gained shows
local toast          -- { text, untilTime }
local made = {}      -- recipe -> what one craft makes and needs, for pricing ({ item, count, reagents }), or false
local plans = {}     -- recipe -> its plan at the house's prices (the list's), or false; let go when prices change
local Refresh, Stale

local function Frame() return ProfessionsFrame end

-- A list head's hover stands past the window's left edge (its right, past the tabs, where the left has no room).
local SIDE = { side = "LEFT", reach = TAB.w }
-- The game's tooltip for a piece of the window, at its picture's top right corner.
local function TipAt(piece) return UI.GameTipAt(piece, piece.icon) end

-- The room the recipe has now: the window flows, so what is measured is laid at its body's width (UI.Body).
local function Wide() return math.floor(UI.BodySize(own.box) - L.detail - L.right) end

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

local function Global(name)
	return rawget(_G, name) or ""
end

local function Dot() return " \194\183 " end

-- Reading the professions

-- Your professions, by the overview's places: two primary, then Cooking, Fishing and First Aid.
local function Yours()
	local prof1, prof2, aid, fish, cook = GetProfessions()
	local out = {}
	for _, spot in ipairs({ { prof1, "primary" }, { prof2, "primary" }, { cook, "cook" }, { fish, "fish" }, { aid, "aid" } }) do
		local index = spot[1]
		local p = { kind = spot[2] }
		if index then
			local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier = GetProfessionInfo(index)
			p.name, p.icon, p.rank, p.max, p.modifier = name, texture, rank or 0, maxRank or 0, rankModifier or 0
			p.skillLine, p.spells = skillLine, {}
			for i = 1, numSpells or 0 do
				local info = C_SpellBook.GetSpellBookItemInfo(spellOffset + i, Enum.SpellBookSpellBank.Player)
				if info and info.spellID then p.spells[#p.spells + 1] = { id = info.spellID, name = info.name, icon = info.iconID } end
			end
			local first = p.spells[1]
			p.crafts = first ~= nil and C_TradeSkillUI.CanTradeSkillShowCraftingUI(first.id) == true
		end
		out[#out + 1] = p
	end
	return out
end

-- Your skill in the profession open, as the game colors recipes by it.
local function Skill()
	return prof and ((prof.skillLevel or 0) + (prof.skillModifier or 0)) or 0
end

-- A recipe's ranks: learned at, yellow from, green from, grey from (nil where the data has none).
local function Ranks(id)
	local t = ns.recipeRanks and ns.recipeRanks[id]
	if not t then return nil end
	return t[1], t[2], math.floor((t[2] + t[3]) / 2), t[3]
end

-- The chance of a point making it at `skill` (nil where the data has none).
local function Chance(id, skill)
	local _, yellow, _, grey = Ranks(id)
	if not yellow then return nil end
	if skill < yellow then return 1 end
	if skill >= grey or grey <= yellow then return 0 end
	return (grey - skill) / (grey - yellow)
end

-- A recipe's difficulty: the game's for one you know, from its ranks for one you don't.
local function Difficulty(r)
	if r.learned then return r.relativeDifficulty end
	local _, yellow, green, grey = Ranks(r.recipeID)
	if not yellow then return r.relativeDifficulty end
	local s = Skill()
	return (s < yellow and DIFF.Optimal) or (s < green and DIFF.Medium) or (s < grey and DIFF.Easy) or DIFF.Trivial
end

-- Where making `n` should take you: each craft's chance worked from the skill the one before leaves you at.
local function Ahead(id, n)
	local s, gain = Skill(), 0
	for _ = 1, n do
		local p = Chance(id, s)
		if not p then return nil end
		gain, s = gain + p, s + p
	end
	return gain
end

-- Your own recipes, to make: not someone's linked list, a guild's, or an NPC's (as the game's InLocalCraftingMode).
local function Local()
	return not (C_TradeSkillUI.IsNPCCrafting() or C_TradeSkillUI.IsTradeSkillGuild() or C_TradeSkillUI.IsTradeSkillGuildMember()
		or C_TradeSkillUI.IsTradeSkillLinked())
end

-- Pricing: the auction house's prices, when ShyAuction is in.
local function Auction() return Shy.addons.Auction end

-- What one craft makes (the middle of a range) and the reagents it takes. Nil while the game hasn't the recipe's
-- item yet; false for one that makes no item (an enchant).
local function Makes(id)
	local m = made[id]
	if m ~= nil then return m or nil end
	local out = C_TradeSkillUI.GetRecipeOutputItemData(id)
	if not out then return nil end
	m = false
	local schematic = out.itemID and C_TradeSkillUI.GetRecipeSchematic(id, false)
	if schematic then
		local least = schematic.quantityMin or 1
		m = { item = out.itemID, count = (least + math.max(least, schematic.quantityMax or least)) / 2, reagents = {} }
		for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
			local reagent = slot.required and slot.reagents and slot.reagents[1]
			if reagent and reagent.itemID then m.reagents[#m.reagents + 1] = { item = reagent.itemID, need = slot.quantityRequired } end
		end
	end
	made[id] = m
	return m or nil
end

local function Held(item) return C_Item.GetItemCount(item, true) or 0 end

-- A recipe's plan at the house's prices (ShyAuction's CraftPlan): the list's kept until prices change, the stage's
-- worked out fresh (what you hold and your gold change).
local function PlanOf(r, fresh)
	local auction = Auction()
	if not auction then return nil end
	local id = r.recipeID
	if not fresh and plans[id] ~= nil then return plans[id] or nil end
	local m = Makes(id)
	if not m then return nil end
	local plan = auction:CraftPlan({ item = m.item, count = m.count, reagents = m.reagents, have = Held, gold = GetMoney(),
		recipe = not r.learned and ns.recipeItems and ns.recipeItems[id] or nil }) or false
	plans[id] = plan
	return plan or nil
end

-- A recipe you don't know that your skill lets you learn now.
local function Learnable(r)
	local at = Ranks(r.recipeID)
	return at == nil or Skill() >= at
end

-- The profession open, its recipes by group, and the recipe shown.
local function Read()
	local info = C_TradeSkillUI.GetChildProfessionInfo()
	if not info or info.professionID == 0 then info = C_TradeSkillUI.GetBaseProfessionInfo() end
	prof = info
	wipe(heads)
	if not info or info.professionID == 0 then return end
	local searching = (C_TradeSkillUI.GetRecipeItemNameFilter() or "") ~= ""
	local learning = mode == "learn"
	local profiting = mode == "profit"
	local mine = Local()
	local byKey, favorites = {}, nil
	local all, make, ups = 0, 0, 0
	for _, id in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs() or {}) do
		local r = C_TradeSkillUI.GetRecipeInfo(id)
		if r and not r.isDummyRecipe and (searching or C_TradeSkillUI.IsRecipeInSkillLine(id, info.professionID)) then
			local n = (r.learned and mine) and C_TradeSkillUI.GetCraftableCount(id) or 0
			r.made = n
			if r.learned then
				all = all + 1
				if n > 0 then make = make + 1 end
				if r.relativeDifficulty ~= DIFF.Trivial then ups = ups + 1 end
			end
			local keep
			if learning then
				keep = not r.learned
			elseif profiting then
				local plan = (r.learned or Learnable(r)) and PlanOf(r)
				keep = plan and plan.profit and plan.profit > 0
				r.profit = keep and plan.profit or nil
			else
				keep = r.learned and (mode ~= "make" or n > 0) and (mode ~= "ups" or r.relativeDifficulty ~= DIFF.Trivial)
			end
			if keep then
				local key = (profiting and (r.learned and "make" or "learn")) or ((r.favorite and not learning) and "favorites")
					or r.categoryID
				local group = byKey[key]
				if not group then
					local name = (key == "favorites" and WORDS.favorites) or (key == "make" and WORDS.forProfit)
						or (key == "learn" and WORDS.learnProfit)
					if not name then
						local about = C_TradeSkillUI.GetCategoryInfo(r.categoryID)
						name = about and about.name or OTHER
					end
					group = { key = key, name = name, recipes = {} }
					byKey[key] = group
					if key == "favorites" then favorites = group else heads[#heads + 1] = group end
				end
				group.recipes[#group.recipes + 1] = r
			end
		end
	end
	if favorites then table.insert(heads, 1, favorites) end
	-- For profit: what you know first, then what you could learn; the best profit first in each.
	if profiting then
		table.sort(heads, function(a, b) return a.key == "make" and b.key ~= "make" end)
		for _, group in ipairs(heads) do
			table.sort(group.recipes, function(a, b)
				if a.profit ~= b.profit then return a.profit > b.profit end
				return a.recipeID < b.recipeID
			end)
		end
	end
	if not learning then tally.all, tally.make, tally.ups = all, make, ups end
	-- The recipe shown stays while it is listed; else the first you can make, else the first.
	local still
	for _, group in ipairs(heads) do
		for _, r in ipairs(group.recipes) do
			if picked and r.recipeID == picked.recipeID then still = r end
		end
	end
	if not still then
		for _, group in ipairs(heads) do
			for _, r in ipairs(group.recipes) do
				if not still and (r.made or 0) > 0 then still = r end
			end
		end
		still = still or (heads[1] and heads[1].recipes[1])
		count = 1
	end
	picked = still
end

local function Have(itemID)
	return C_Item.GetItemCount(itemID) or 0
end

local function Open()
	return prof ~= nil and prof.professionID ~= 0
end


-- Your profession's link, where the game's Link button puts it: the macro being written, or the chat box open.
-- Link's words: into the macro being written, else the chat box you have open, else a chat box opened with it
-- (on the channel you last spoke in), so a click always puts it somewhere you can send it.
local function InsertLink()
	local link = C_TradeSkillUI.GetTradeSkillListLink()
	if not link then return end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	local macro = rawget(_G, "MacroFrameText")
	if macro and macro:IsShown() and macro:HasFocus() then
		if strlenutf8(macro:GetText()) + strlenutf8(link) <= macro:GetMaxLetters() then macro:Insert(link) end
	elseif ChatFrameUtil.GetActiveWindow() then
		ChatFrameUtil.InsertLink(link)
	else
		ChatFrameUtil.OpenChat(link)
	end
end

-- The list's filter: the game's unlearned list for To learn, both of its lists for Profit, ours over the learned ones
-- otherwise.
local function Lists(m) return m ~= "learn", m == "learn" or m == "profit" end
local function SetMode(i)
	local was = mode
	mode = MODES[i] or "all"
	local learned, unlearned = Lists(mode)
	local wasLearned, wasUnlearned = Lists(was)
	if learned ~= wasLearned then C_TradeSkillUI.SetShowLearned(learned) end
	if unlearned ~= wasUnlearned then C_TradeSkillUI.SetShowUnlearned(unlearned) end
	picked = nil
	Stale()
end

-- The game's lists put back as its own window keeps them.
local function Unlearn()
	if mode ~= "learn" and mode ~= "profit" then return end
	mode = "all"
	C_TradeSkillUI.SetShowLearned(true)
	C_TradeSkillUI.SetShowUnlearned(false)
	if own.filter then own.filter:Select(1) end
end

-- Making

local function Craft(n)
	if not picked or n < 1 or picked.isEnchantingRecipe or not picked.learned then return end
	-- Its points are lit in the color it gives them in now (yellow where it's grey: none should come).
	local d = DIFFICULTY[picked.relativeDifficulty]
	local c = (d and picked.relativeDifficulty ~= DIFF.Trivial) and d[1] or FAIR_DIFFICULTY_COLOR
	making = { recipe = picked.recipeID, total = n, skill = Skill(), last = Skill(), ups = {}, icon = picked.icon,
		color = { c.r, c.g, c.b } }
	C_TradeSkillUI.CraftRecipe(picked.recipeID, n)
	Stale()
end

-- A secure button: mouse only, acting on the release (a press can start nothing here).
local function Secure(parent, name)
	local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("useOnKeyDown", false)
	return b
end

-- Building: the frame

local function Bar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height or 11)
	bar:SetStatusBarTexture(Skin.HATCH)
	Skin.Hatch(bar:GetStatusBarTexture())
	-- A framed track, so the room still to go reads on any painting.
	UI.Skin(bar, C.bg, C.border)
	bar.text = Text(bar, UI.NameFont(10), C.text)
	bar.text:SetPoint("RIGHT", -4, 0)
	return bar
end

local function SetBar(bar, value, cap, plus)
	bar:SetMinMaxValues(0, math.max(1, cap))
	bar:SetValue(value)
	Theme.Tint(bar:GetStatusBarTexture(), Theme.Accent)
	bar.text:SetText(value .. ((plus or 0) > 0 and (" (+" .. plus .. ")") or "") .. " / " .. cap)
end

-- A side tab on the spine, as the spellbook's: a slot, a wash of your color and a line of light while open, and a
-- profession's skill as a hairline under its slot.
local function Tab(i, secure)
	local box = own.box
	local tab = secure and Secure(box, "ShySkinProfessionTab" .. i) or CreateFrame("Button", nil, box)
	tab:SetSize(TAB.w, TAB.h)
	tab:SetPoint("TOPLEFT", box, "TOPRIGHT", 0, -(TAB.top + (i - 1) * (TAB.h + 2)))
	tab.wash = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
	tab.wash:SetPoint("TOPLEFT", 0, 1)
	tab.wash:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.wash:SetColorTexture(1, 1, 1, 1)
	tab.hot = tab:CreateTexture(nil, "HIGHLIGHT")
	tab.hot:SetPoint("TOPLEFT", 0, 1)
	tab.hot:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.hot:SetColorTexture(1, 1, 1, 1)
	tab.line = tab:CreateTexture(nil, "ARTWORK")
	tab.line:SetPoint("TOPLEFT")
	tab.line:SetPoint("BOTTOMLEFT")
	tab.line:SetWidth(2)
	tab.line:SetColorTexture(1, 1, 1, 1)
	tab.rule = tab:CreateTexture(nil, "ARTWORK")
	tab.rule:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 5, 0)
	tab.rule:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", -5, 0)
	tab.rule:SetHeight(1)
	UI.Paint(tab.rule, C.border, 0.9)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(TAB.slot, TAB.slot)
	tab.icon:SetPoint("CENTER", tab, "CENTER", TAB.x, 0)
	tab.icon:SetTexCoord(unpack(ICON))
	tab.slot = Slot.New(tab, { to = tab.icon, icon = tab.icon })
	tab.track = tab:CreateTexture(nil, "ARTWORK")
	tab.track:SetPoint("TOPLEFT", tab.icon, "BOTTOMLEFT", 1, -3)
	tab.track:SetPoint("TOPRIGHT", tab.icon, "BOTTOMRIGHT", -1, -3)
	tab.track:SetSnapToPixelGrid(true)
	tab.track:SetTexelSnappingBias(0)
	UI.Paint(tab.track, C.bg, 1)
	tab.fill = tab:CreateTexture(nil, "ARTWORK", nil, 1)
	tab.fill:SetPoint("TOPLEFT", tab.track)
	tab.fill:SetSnapToPixelGrid(true)
	tab.fill:SetTexelSnappingBias(0)
	UI.Paint(tab.fill, Theme.Accent)
	tab.track:Hide()
	tab.fill:Hide()
	tab:SetScript("OnEnter", function(self) if self.tip then UI.Tip(self, self.tip, self.skillSay, { side = "RIGHT" }) end end)
	tab:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	return tab
end

local function PaintTab(tab, on)
	local r, g, b = Theme.Accent()
	tab.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.3), CreateColor(r, g, b, 0))
	local h = C.hot
	tab.hot:SetGradient("HORIZONTAL", CreateColor(h[1], h[2], h[3], 0.16), CreateColor(h[1], h[2], h[3], 0))
	tab.line:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
	tab.wash:SetShown(on)
	tab.line:SetShown(on)
	tab.slot:Steel(on and C.hot or nil)
	local v = on and 1 or 0.74
	tab.icon:SetVertexColor(v, v, v)
	-- Its skill, in whole pixels.
	local has = tab.cap ~= nil and tab.cap > 0
	tab.track:SetShown(has)
	tab.fill:SetShown(has and (tab.skill or 0) > 0)
	if has then
		local thick = UI.BoxPixels(tab, 2)
		local wide = tab.track:GetWidth() or 0
		tab.track:SetHeight(thick)
		tab.fill:SetSize(math.max(UI.BoxPixels(tab, 1), wide * math.min(1, (tab.skill or 0) / tab.cap)), thick)
	end
end

-- Picks up a profession's spell dragged from its card, as the spellbook does: in the restricted environment, so a
-- drag works in a fight too.
local DRAG = [[
	local spell = self:GetAttribute("pickup")
	if spell then return "spell", spell end
]]

-- A profession's spell (Smelting, Find Minerals, Cooking): a secure button casting it, its slot and its name; dragged,
-- it goes onto your bars.
local function SpellButton(parent, key)
	local b = Secure(parent, "ShySkinProfessionSpell" .. key)
	b:SetSize(150, L.spell)
	b:RegisterForDrag("LeftButton")
	own.dragger = own.dragger or CreateFrame("Frame", nil, own.book, "SecureHandlerBaseTemplate")
	SecureHandlerWrapScript(b, "OnDragStart", own.dragger, DRAG)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(L.spell, L.spell)
	b.icon:SetPoint("LEFT")
	b.icon:SetTexCoord(unpack(ICON))
	b.slot = Slot.New(b, { to = b.icon, icon = b.icon })
	b.name = Text(b, UI.TitleFont(13), C.text)
	b.name:SetPoint("LEFT", L.spell + 8, 0)
	b.name:SetPoint("RIGHT", 0, 0)
	b:SetScript("OnEnter", function(self)
		if not self.spell then return end
		TipAt(self)
		GameTooltip:SetSpellByID(self.spell)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- A card on the overview: its painting under a burn, its icon, name, skill, spells, or the words for an empty slot.
local function Card(key, w, h)
	local card = CreateFrame("Frame", nil, own.book)
	card:SetSize(w, h)
	card.art = card:CreateTexture(nil, "BACKGROUND", nil, 1)
	card.art:SetAllPoints()
	card.burn = card:CreateTexture(nil, "BACKGROUND", nil, 2)
	card.burn:SetAllPoints()
	card.burn:SetColorTexture(1, 1, 1, 1)
	card.rim = card:CreateTexture(nil, "BORDER")
	card.rim:SetTexture(UI.EDGE)
	card.rim:SetTextureSliceMargins(UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE, UI.EDGE_SLICE)
	card.rim:SetPoint("TOPLEFT", -1, 1)
	card.rim:SetPoint("BOTTOMRIGHT", 1, -1)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(L.cardIcon, L.cardIcon)
	card.icon:SetPoint("TOPLEFT", L.cardIn, -L.cardIn)
	card.icon:SetTexCoord(unpack(ICON))
	card.slot = Slot.New(card, { to = card.icon, icon = card.icon, hover = false })
	card.name = Text(card, UI.TitleFont(18), C.head)
	card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
	card.bar = Bar(card, math.min(260, w - 90))
	card.bar:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 10, 2)
	-- An empty slot: its heading where a profession's name stands, the game's words wrapping under it.
	card.missing = Text(card, UI.TitleFont(16), C.head)
	card.missing:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
	card.missing:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	card.words = Text(card, UI.TextFont(12), C.dim)
	card.words:SetPoint("TOPLEFT", card.missing, "BOTTOMLEFT", 0, -6)
	card.words:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	card.words:SetJustifyV("TOP")
	card.words:SetWordWrap(true)
	card.words:SetMaxLines(6)
	-- The spells hang right under the heading: in a row on a primary card, stacked on a small one, so whatever
	-- height is left falls to the painting below them. Secure buttons anchor to the card, not to the icon.
	card.spells = { SpellButton(card, key .. "a"), SpellButton(card, key .. "b") }
	local under = -(L.cardIn + L.cardIcon + 12)
	for j, b in ipairs(card.spells) do
		if w > 400 then
			b:SetPoint("TOPLEFT", card, "TOPLEFT", L.cardIn + (j - 1) * 170, under)
		else
			b:SetPoint("TOPLEFT", card, "TOPLEFT", L.cardIn, under - (j - 1) * (L.spell + 8))
		end
	end
	return card
end

local function Search(parent)
	return Shop.Search(parent, SEARCH, function(text)
		if text ~= (C_TradeSkillUI.GetRecipeItemNameFilter() or "") then C_TradeSkillUI.SetRecipeItemNameFilter(text) end
	end)
end

-- A small section word over a hairline that fades out ("REAGENTS"): the one the vendor and the trainer wear too.
local Kicker = Shop.Kicker

-- Building: the recipes page

local function Pick(r)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if not picked or picked.recipeID ~= r.recipeID then
		count = 1
		if own.count then own.count:ClearFocus() end
	end
	picked = r
	Refresh()
end

local function Row(i)
	local row = own.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.list.content)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp")
	-- Picked: your color washed in from the left with a fine line of it at the edge, as a group head wears a meaning
	-- color. Under the mouse: the head's own glow. (Both behind the words: a HIGHLIGHT texture draws over them.)
	row.lit = row:CreateTexture(nil, "BACKGROUND")
	row.lit:SetAllPoints()
	row.lit:SetColorTexture(1, 1, 1, 1)
	row.lit:Hide()
	row.edge = row:CreateTexture(nil, "BACKGROUND", nil, 2)
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetSnapToPixelGrid(true)
	row.edge:SetTexelSnappingBias(0)
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
	row.pill = row:CreateTexture(nil, "ARTWORK")
	row.pill:SetHeight(16)
	row.pill:SetPoint("RIGHT", -5, 0)
	row.pill:SetColorTexture(1, 1, 1, 1)
	row.count = Text(row, UI.NameFont(10), C.good)
	row.count:SetPoint("CENTER", row.pill, "CENTER", 0, 0)
	row.lock = row:CreateTexture(nil, "ARTWORK")
	row.lock:SetTexture(Skin.GLYPH.lock)
	UI.GlyphFit(row.lock, 10)
	row.lock:SetPoint("RIGHT", -8, 0)
	UI.Tint(row.lock, C.dim)
	row.pct = Text(row, UI.NameFont(10), C.dim)
	row.pct:SetPoint("RIGHT", -32, 0)
	row.pct:SetJustifyH("RIGHT")
	row.profit = Text(row, UI.NameFont(10), C.good)
	row.profit:SetPoint("LEFT", row, "LEFT", 36, -7)
	row.pin = row:CreateTexture(nil, "ARTWORK")
	row.pin:SetTexture(Skin.GLYPH.pin)
	UI.GlyphFit(row.pin, 11)
	UI.Tint(row.pin, C.hot)
	row.name = Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("LEFT", 36, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
	row:SetScript("OnClick", function(self, button)
		if not self.recipe then return end
		if IsModifiedClick() then
			local id = self.recipe.recipeID
			if not HandleModifiedItemClick(C_TradeSkillUI.GetRecipeLink(id)) and IsModifiedClick("RECIPEWATCHTOGGLE") and self.recipe.learned then
				C_TradeSkillUI.SetRecipeTracked(id, not C_TradeSkillUI.IsRecipeTracked(id, false), false)
				Stale()
			end
			return
		end
		Pick(self.recipe)
	end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		if not self.recipe then return end
		TipAt(self)
		GameTooltip:SetRecipeResultItem(self.recipe.recipeID)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		GameTooltip:Hide()
	end)
	own.rows[i] = row
	return row
end

local function Head(i)
	local h = own.heads[i]
	if h then return h end
	h = UI.GroupHead(own.list.content, { height = L.head, rail = L.rail, gutter = 34, right = 6, foldSize = L.fold,
		branches = L.branch, line = true,
		tip = function(self) return self.name, self.say, { at = UI.Beside(own.box, self, SIDE) } end,
		click = function(self, button)
			if button ~= "LeftButton" or not self.key then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			folds[self.key] = not folds[self.key] or nil
			Refresh()
		end })
	own.heads[i] = h
	return h
end

local function Reagent(i)
	local r = own.reagents[i]
	if r then return r end
	r = UI.KeyPlate(CreateFrame("Button", nil, own.detail))
	r:SetSize(200, L.cardH)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(L.reag, L.reag)
	r.icon:SetPoint("LEFT", 5, 0)
	r.icon:SetTexCoord(unpack(ICON))
	r.slot = Slot.New(r, { to = r.icon, icon = r.icon })
	r.need = r:CreateFontString(nil, "OVERLAY")
	r.slot:Count(r.need)
	r.name = Text(r, UI.NameFont(12), C.text)
	r.name:SetPoint("TOPLEFT", L.reag + 13, -7)
	r.name:SetPoint("RIGHT", -8, 0)
	r.cost = Text(r, UI.NameFont(11), C.dim)
	r.cost:SetPoint("TOPRIGHT", -8, -8)
	r.cost:SetJustifyH("RIGHT")
	r.have = Text(r, UI.NameFont(11), C.dim)
	r.have:SetPoint("TOPLEFT", L.reag + 13, -23)
	r.have:SetPoint("RIGHT", -8, 0)
	-- The gauge: have against need, a hairline under the words.
	r.track = r:CreateTexture(nil, "ARTWORK")
	r.track:SetPoint("BOTTOMLEFT", L.reag + 13, 4)
	r.track:SetPoint("BOTTOMRIGHT", -8, 4)
	r.track:SetHeight(2)
	r.track:SetSnapToPixelGrid(true)
	UI.Paint(r.track, C.bg, 1)
	r.fill = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.fill:SetPoint("BOTTOMLEFT", r.track)
	r.fill:SetHeight(2)
	r.fill:SetSnapToPixelGrid(true)
	r:EnableMouse(true)
	r:SetScript("OnEnter", function(self)
		if not self.item then return end
		TipAt(self)
		GameTooltip:SetItemByID(self.item)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	own.reagents[i] = r
	return r
end

-- What it needs nearby: a pill, ticked or crossed.
local function Need(i)
	local n = own.needs[i]
	if n then return n end
	n = UI.KeyPlate(CreateFrame("Button", nil, own.detail))
	n:SetHeight(24)
	n.glyph = n:CreateTexture(nil, "OVERLAY")
	UI.GlyphFit(n.glyph, 10)
	n.glyph:SetPoint("LEFT", 9, 0)
	n.text = Text(n, UI.NameFont(12), C.text)
	n.text:SetPoint("LEFT", 25, 0)
	own.needs[i] = n
	return n
end

local function Line(i)
	local line = own.lines[i]
	if line then return line end
	line = { left = Text(own.item, UI.TextFont(12), C.text), right = Text(own.item, UI.TextFont(12), C.text) }
	line.right:SetJustifyH("RIGHT")
	own.lines[i] = line
	return line
end

-- The skill ribbon: the recipe's orange, yellow, green and grey over the ranks, you on it.
local function Ribbon(parent)
	local rb = CreateFrame("Frame", nil, parent)
	rb:SetSize(400, 30)
	rb.segs, rb.cuts = {}, {}
	for i = 1, 4 do
		local t = rb:CreateTexture(nil, "ARTWORK")
		t:SetHeight(8)
		t:SetColorTexture(1, 1, 1, 1)
		t:SetSnapToPixelGrid(true)
		rb.segs[i] = t
	end
	for i = 1, 3 do
		local cut = Text(rb, UI.NameFont(10), C.dim)
		cut:SetJustifyH("CENTER")
		rb.cuts[i] = cut
	end
	rb.needle = rb:CreateTexture(nil, "OVERLAY")
	rb.needle:SetSnapToPixelGrid(true)
	UI.Paint(rb.needle, C.head)
	rb.knob = rb:CreateTexture(nil, "OVERLAY", nil, 1)
	rb.knob:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(rb.knob, 7)
	UI.Tint(rb.knob, C.head)
	rb.tag = Text(rb, UI.NameFont(10), C.head)
	return rb
end

local function SetRibbon(rb, id, learnedAt, skill, wide)
	local _, yellow, green, grey = Ranks(id)
	local lo, hi = 1, math.max(grey + 15, skill + 10)
	rb:SetWidth(wide)
	local function X(v) return wide * (v - lo) / (hi - lo) end
	local marks = { lo, yellow, green, grey, hi }
	for i = 1, 4 do
		local t = rb.segs[i]
		local c = DIFFICULTY[BAND[i]][1]
		local r, g, b = c:GetRGB()
		local left, right = X(marks[i]), X(marks[i + 1])
		t:SetShown(right - left > 0.5)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", rb, "TOPLEFT", left, -8)
		t:SetWidth(math.max(1, right - left - (i < 4 and 1 or 0)))
		t:SetGradient("VERTICAL", CreateColor(r, g, b, 0.75), CreateColor(r, g, b, 1))
	end
	-- The ranks under it: grey's first, then yellow's and green's where they have room (a cramped range keeps
	-- where it goes grey).
	local placed = {}
	for _, i in ipairs({ 3, 1, 2 }) do
		local cut, at = rb.cuts[i], X(marks[i + 1])
		local room = true
		for _, x in ipairs(placed) do room = room and math.abs(x - at) >= 22 end
		cut:SetShown(room)
		if room then
			placed[#placed + 1] = at
			cut:SetText(marks[i + 1])
			cut:ClearAllPoints()
			cut:SetPoint("TOP", rb, "TOPLEFT", at, -18)
		end
	end
	local x = X(math.max(lo, math.min(hi, skill)))
	local thick = UI.BoxPixels(rb, 2)
	rb.needle:ClearAllPoints()
	rb.needle:SetPoint("TOPLEFT", rb, "TOPLEFT", x - thick / 2, -2)
	rb.needle:SetSize(thick, 18)
	rb.knob:ClearAllPoints()
	rb.knob:SetPoint("CENTER", rb, "TOPLEFT", x, -2)
	rb.tag:SetText(WORDS.you:format(skill))
	-- (Held inside the ribbon at either end.)
	local half = math.ceil(rb.tag:GetStringWidth() / 2)
	rb.tag:ClearAllPoints()
	rb.tag:SetPoint("BOTTOM", rb, "TOPLEFT", math.max(half, math.min(wide - half, x)), 2)
	return learnedAt
end

local function BuildCraft(box)
	-- Everything under the header stands on the window's body: clear of the look's work round the edge (UI.Body).
	local craft = CreateFrame("Frame", nil, box)
	craft:SetAllPoints(UI.Body(box))
	own.craft = craft
	own.rows, own.heads, own.reagents, own.needs, own.lines = {}, {}, {}, {}, {}

	-- The band: your rank, your skill to its cap, a glow for what's ahead, and a word when a point comes. One row
	-- holds it all, Link its full height and the bar a few pixels in from its top and foot (LayBand), so every edge
	-- in it stands whole pixels from the row's top and they fall on the screen's pixels alike, in any look.
	local band = CreateFrame("Frame", nil, craft)
	band:SetPoint("TOPLEFT", L.pad + 4, -(L.head0 + (L.band - L.key) / 2))
	band:SetPoint("TOPRIGHT", -L.right, -(L.head0 + (L.band - L.key) / 2))
	band:SetHeight(L.key)
	own.band = band
	own.rank = Text(band, UI.TitleFont(15), C.head)
	own.rank:SetPoint("LEFT")
	own.bar = Bar(band, 380, L.key - 2 * L.barIn)
	own.ghost = own.bar:CreateTexture(nil, "ARTWORK", nil, 2)
	own.ghost:SetTexture(Skin.HATCH)
	Skin.Hatch(own.ghost)
	UI.Tint(own.ghost, C.head, 0.6)
	own.ghost:SetPoint("TOP")
	own.ghost:SetPoint("BOTTOM")
	own.ghost:SetPoint("LEFT", own.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
	own.ghost:Hide()
	function own.LayGhost()
		if own.ghostShare then own.ghost:SetWidth(math.max(1, own.bar:GetWidth() * own.ghostShare)) end
	end
	own.bar:HookScript("OnSizeChanged", own.LayGhost)
	-- Link: its words put your profession's link in the chat box you have open; its caret posts it to a chat.
	own.link = UI.SplitButton(band, { plate = true, height = L.key, click = InsertLink,
		tip = Global("LINK_TRADESKILL_TOOLTIP") ~= "" and Global("LINK_TRADESKILL_TOOLTIP") or nil,
		write = function(root)
			UI.TellMenu(root, WORDS.post, function() return C_TradeSkillUI.GetTradeSkillListLink() or "" end)
		end })
	own.link:SetLabel(WORDS.link)
	own.link:SetPoint("TOPRIGHT")
	own.link:SetPoint("BOTTOMRIGHT")
	-- What's ahead, its words' own width, against Link; the bar fills from your rank to them.
	own.ahead = Text(band, UI.TextFont(11), C.dim)
	own.ahead:SetJustifyH("RIGHT")
	-- Laid at every draw and as the band flows: the row's height and the bar's room in whole pixels where it stands.
	function own.LayBand()
		local function Px(units) return units > 0 and UI.BoxPixels(band, units) or 0 end
		band:SetHeight(Px(L.key))
		local said = own.ahead:GetText()
		local aheadW = (said and said ~= "") and math.ceil(own.ahead:GetStringWidth()) + 1 or 0
		own.ahead:SetWidth(math.max(aheadW, 0.01))
		local linkW = own.link:IsShown() and own.link:GetWidth() + L.bandGap or 0
		own.ahead:ClearAllPoints()
		own.ahead:SetPoint("RIGHT", band, "RIGHT", -Px(linkW), 0)
		local left = Px(math.ceil(own.rank:GetStringWidth()) + L.bandGap)
		local right = Px(linkW + (aheadW > 0 and aheadW + L.bandGap or 0))
		own.bar:ClearAllPoints()
		own.bar:SetPoint("TOPLEFT", band, "TOPLEFT", left, -Px(L.barIn))
		own.bar:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -right, Px(L.barIn))
	end
	band:SetScript("OnSizeChanged", function() own.LayBand() end)
	own.search = Search(craft)
	own.search:SetPoint("RIGHT", box, "TOPRIGHT", -(HEAD.pad + HEAD.close + 6), -box.head.mid)
	own.search:SetFrameLevel(box.head:GetFrameLevel() + 10)

	-- The list: its filter, then the groups.
	-- The list's filter: the family's tabs, the open one lit on its line, a quiet count where it says something.
	local modes = { unpack(WORDS.modes) }
	if Auction() then modes[#modes + 1] = WORDS.profit end
	own.filter = UI.Tabs(craft, modes, SetMode, L.list, 12, nil, { tall = L.seg, sides = 10 })
	own.filter:SetPoint("TOPLEFT", L.pad, -L.segTop)
	own.filter:SetRoom(L.list)
	own.filter.selected = 1
	for j, t in ipairs(own.filter.tabs) do
		t.bar:SetShown(j == 1)
		UI.Ink(t.text, j == 1 and t.inkOpen or t.inkRest)
	end
	own.list = UI.ScrollArea(craft, L.list, L.h - L.listTop - L.pad, { quiet = true })
	own.list:SetPoint("TOPLEFT", L.pad, -L.listTop)
	own.list:SetPoint("BOTTOMLEFT", L.pad, L.pad)
	own.split = craft:CreateTexture(nil, "ARTWORK")
	own.split:SetWidth(1)
	own.split:SetPoint("TOPLEFT", L.pad + L.list + L.gap / 2, -L.segTop)
	own.split:SetPoint("BOTTOMLEFT", L.pad + L.list + L.gap / 2, L.pad)
	UI.Paint(own.split, C.border, 0.9)

	-- The recipe's stage: the profession's painting, a light behind what it makes.
	local stage = CreateFrame("Frame", nil, craft)
	stage:SetPoint("TOPLEFT", L.pad + L.list + L.gap / 2 + 1, -L.head0 - L.band)
	stage:SetPoint("BOTTOMRIGHT", -2, 2)
	stage:SetClipsChildren(true)
	own.stage = stage
	-- The painting covers the stage at its own proportions, its foot and right edge kept (where the game's paintings
	-- stand their scene), what runs past cut by the stage; laid again at every draw (DrawStage), so it fills as the
	-- window flows.
	own.paint = stage:CreateTexture(nil, "BACKGROUND", nil, 1)
	own.paint:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, 0)
	own.paint:SetBlendMode("ADD")
	own.light = stage:CreateTexture(nil, "BACKGROUND", nil, 2)
	own.light:SetTexture(B.GLOW)
	own.light:SetSize(360, 260)
	own.light:SetPoint("CENTER", stage, "TOPLEFT", 140, -40)
	UI.Tint(own.light, Theme.Accent, 0.22)

	-- The recipe.
	local d = CreateFrame("Frame", nil, craft)
	d:SetPoint("TOPLEFT", L.detail, -L.top)
	d:SetPoint("BOTTOMRIGHT", -L.right, L.pad + L.foot + 8)
	own.detail = d
	own.bloom = d:CreateTexture(nil, "BACKGROUND")
	own.bloom:SetTexture(B.GLOW)
	own.bloom:SetSize(122, 122)
	own.bloom:SetPoint("CENTER", d, "TOPLEFT", L.out / 2, -L.out / 2)
	UI.Tint(own.bloom, Theme.Accent, 0.5)
	own.out = CreateFrame("Frame", nil, d)
	own.out:SetSize(L.out, L.out)
	own.out:SetPoint("TOPLEFT")
	own.out.icon = own.out:CreateTexture(nil, "ARTWORK")
	own.out.icon:SetAllPoints()
	own.out.icon:SetTexCoord(unpack(ICON))
	own.out.slot = Slot.New(own.out, { icon = own.out.icon })
	own.out:EnableMouse(true)
	own.out:SetScript("OnEnter", function(self)
		if not picked then return end
		TipAt(self)
		GameTooltip:SetRecipeResultItem(picked.recipeID)
		GameTooltip:Show()
	end)
	own.out:SetScript("OnLeave", function() GameTooltip:Hide() end)
	own.name = Text(d, UI.TitleFont(22), C.text)
	own.name:SetPoint("TOPLEFT", L.out + 14, -6)
	own.name:SetPoint("RIGHT", d, "RIGHT", -60, 0)
	own.sub = Text(d, UI.NameFont(11), C.dim)
	own.sub:SetPoint("TOPLEFT", L.out + 15, -34)
	own.sub:SetPoint("RIGHT", d, "RIGHT", -60, 0)
	-- Star and pin: the game's favorite and tracking.
	own.star = UI.GlyphButton(d, Skin.GLYPH.star, 24, function()
		if not picked or not picked.learned then return end
		C_TradeSkillUI.SetRecipeFavorite(picked.recipeID, not picked.favorite)
		Stale()
	end, { glyph = 12 })
	own.star:SetPoint("TOPRIGHT", d, "TOPRIGHT", -28, -2)
	own.star:HookScript("OnEnter", function(self)
		UI.Tip(self, picked and picked.favorite and WORDS.unfavorite or WORDS.favorite, nil, { side = "TOP" })
	end)
	own.star:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	own.pin = UI.GlyphButton(d, Skin.GLYPH.pin, 24, function()
		if not picked or not picked.learned then return end
		C_TradeSkillUI.SetRecipeTracked(picked.recipeID, not C_TradeSkillUI.IsRecipeTracked(picked.recipeID, false), false)
		Stale()
	end, { glyph = 12 })
	own.pin:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, -2)
	own.pin:HookScript("OnEnter", function(self)
		local on = picked and C_TradeSkillUI.IsRecipeTracked(picked.recipeID, false)
		UI.Tip(self, on and WORDS.untrack or WORDS.track, WORDS.trackSay, { side = "TOP" })
	end)
	own.pin:HookScript("OnLeave", function(self) UI.TipHide(self) end)

	own.skillKick = Kicker(d)
	own.skillKick:SetPoint("LEFT")
	own.skillKick:SetPoint("RIGHT")
	own.ribbon = Ribbon(d)
	own.odds = Text(d, UI.TextFont(12), C.text)
	own.needKick = Kicker(d)
	own.needKick:SetPoint("LEFT")
	own.needKick:SetPoint("RIGHT")
	own.build = UI.Button(d, "", 200, function()
		if own.build.recipe then Pick(own.build.recipe) end
	end)
	own.build:SetHeight(22)
	own.reagKick = Kicker(d)
	own.reagKick:SetPoint("LEFT")
	own.reagKick:SetPoint("RIGHT")
	own.worthKick = Kicker(d)
	-- What it's worth: three figures side by side on a plate (what it sells for, its reagents, the profit), and
	-- under it what you lack, or a recipe's own price.
	own.worthPlate = UI.KeyPlate(CreateFrame("Button", nil, d))
	own.worthPlate:SetHeight(42)
	own.worthCells = {}
	for i = 1, 3 do
		local cell = CreateFrame("Frame", nil, own.worthPlate)
		cell:SetHeight(42)
		cell.label = Text(cell, UI.NameFont(10), C.dim)
		cell.label:SetPoint("TOPLEFT", 10, -6)
		cell.money = Text(cell, UI.NameFont(i == 3 and 15 or 13), C.text)
		cell.money:SetPoint("BOTTOMLEFT", 10, 6)
		if i > 1 then
			cell.rule = cell:CreateTexture(nil, "ARTWORK")
			cell.rule:SetPoint("TOPLEFT", 0, -8)
			cell.rule:SetPoint("BOTTOMLEFT", 0, 8)
			cell.rule:SetWidth(1)
			cell.rule:SetColorTexture(1, 1, 1, 1)
		end
		own.worthCells[i] = cell
	end
	own.worthSay = Text(d, UI.TextFont(12), C.text)
	own.worthSay:SetJustifyH("LEFT")
	own.worthSay:SetWordWrap(true)
	own.worthSay:SetSpacing(3)
	own.itemKick = Kicker(d)
	own.itemKick:SetPoint("LEFT")
	own.itemKick:SetPoint("RIGHT")
	own.item = UI.KeyPlate(CreateFrame("Button", nil, d))

	-- The foot, one line under a hairline: how many (a stepper you can also type in) and the skill they should give,
	-- then Create all and Create; while making, the batch; for a recipe you don't know, where to learn it.
	local foot = CreateFrame("Frame", nil, craft)
	foot:SetPoint("BOTTOMLEFT", L.detail, L.pad + 2)
	foot:SetPoint("BOTTOMRIGHT", -L.right, L.pad + 2)
	foot:SetHeight(L.foot)
	own.foot = foot
	own.footRule = foot:CreateTexture(nil, "ARTWORK")
	own.footRule:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 9)
	own.footRule:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 9)
	own.footRule:SetHeight(1)
	own.footRule:SetColorTexture(1, 1, 1, 1)
	own.qty = UI.KeyPlate(CreateFrame("Button", nil, foot))
	own.qty:SetSize(L.qty, L.foot)
	own.qty:SetPoint("LEFT")
	-- A step: its sign alone on the stepper's plate, brighter under the mouse.
	local function Step(sign, by, side)
		local b = CreateFrame("Button", nil, own.qty)
		b:SetSize(L.step, L.foot)
		b:SetPoint(side, 0, 0)
		b.text = Text(b, UI.NameFont(15), C.dim)
		b.text:SetPoint("CENTER", 0, 1)
		b.text:SetText(sign)
		b:SetScript("OnClick", function(self)
			if self.off then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			own.count:ClearFocus()
			count = math.max(1, math.min(L.most, count + by))
			Refresh()
		end)
		b:SetScript("OnEnter", function(self) if not self.off then UI.Ink(self.text, C.hot) end end)
		b:SetScript("OnLeave", function(self) UI.Ink(self.text, self.off and C.border or C.dim) end)
		function b:SetOff(off)
			self.off = off
			UI.Ink(self.text, off and C.border or C.dim)
		end
		return b
	end
	own.less = Step("\226\136\146", -1, "LEFT")
	own.more = Step("+", 1, "RIGHT")
	-- The count, typed: digits only, read as you type (the skill beside it follows); Enter or a click away settles
	-- it to what you can make, Escape puts back what was there.
	local box = CreateFrame("EditBox", nil, own.qty)
	box:SetPoint("TOPLEFT", L.step, 0)
	box:SetPoint("BOTTOMRIGHT", -L.step, 0)
	box:SetFontObject(UI.NameFont(14))
	box:SetShadowOffset(1, -1)
	box:SetShadowColor(0, 0, 0, 1)
	UI.Ink(box, C.head)
	box:SetJustifyH("CENTER")
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(#tostring(L.most))
	box:SetScript("OnEditFocusGained", function(self)
		self.was = count
		self:HighlightText()
		own.qty:SetTone(Theme.Accent, true)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		own.qty:SetTone(Theme.Accent, false)
		Refresh()
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		count = self.was or count
		self:ClearFocus()
	end)
	box:SetScript("OnTextChanged", function(self, typed)
		if not typed then return end
		local n = tonumber(self:GetText())
		if n and n >= 1 then
			count = math.min(L.most, n)
			Refresh()
		end
	end)
	own.count = box
	-- What the count should give, or why nothing can be made: quiet words beside the stepper.
	own.worth = Text(foot, UI.NameFont(11), C.dim)
	own.worth:SetPoint("LEFT", own.qty, "RIGHT", 10, 0)
	own.worth:SetJustifyH("LEFT")
	own.worth:SetWordWrap(false)
	own.status = Text(foot, UI.NameFont(11), C.bad)
	own.status:SetPoint("LEFT", own.qty, "RIGHT", 10, 0)
	own.status:SetJustifyH("LEFT")
	own.status:SetWordWrap(true)
	own.status:SetMaxLines(2)
	-- Create: secure, so an enchant can be cast (its attributes set as the recipe is picked, out of a fight); a
	-- plain recipe is made from its click afterwards.
	local create = Secure(foot, "ShySkinProfessionCreate")
	create:SetSize(L.create, L.foot)
	create:SetPoint("RIGHT", 0, 0)
	UI.ButtonFace(create, CREATE_PROFESSION or "Create")
	create:SetPrimary(true)
	create:HookScript("PostClick", function(self)
		if self.off then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		own.count:ClearFocus()
		Craft(count)
	end)
	own.create = create
	-- Create all: as many as your reagents make, in one go.
	local all = CreateFrame("Button", nil, foot)
	all:SetSize(L.createAll, L.foot)
	all:SetPoint("RIGHT", create, "LEFT", -8, 0)
	UI.ButtonFace(all, "")
	all:SetScript("OnClick", function(self)
		if self.off or not picked then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		own.count:ClearFocus()
		Craft(math.min(L.most, C_TradeSkillUI.GetCraftableCount(picked.recipeID)))
	end)
	own.createAll = all
	-- Cut short of the buttons, never under them.
	own.worth:SetPoint("RIGHT", all, "LEFT", -10, 0)
	own.status:SetPoint("RIGHT", all, "LEFT", -10, 0)
	-- The batch: one bar for all of it, cut into a piece for each one queued. The ones made are filled, the one being
	-- made fills as its cast runs (a spark on its edge), and each one that gave a point is lit in the skill-up color;
	-- over it, how far along, the time left, and a badge of the points so far.
	local convey = CreateFrame("Frame", nil, foot)
	convey:SetPoint("TOPLEFT")
	convey:SetPoint("BOTTOMRIGHT", create, "BOTTOMLEFT", -12, 0)
	convey.icon = convey:CreateTexture(nil, "ARTWORK")
	convey.icon:SetSize(Slot.SIZES.compact, Slot.SIZES.compact)
	convey.icon:SetPoint("LEFT")
	convey.icon:SetTexCoord(unpack(ICON))
	convey.slot = Slot.New(convey, { to = convey.icon, icon = convey.icon, size = Slot.SIZES.compact, hover = false })
	local bar = CreateFrame("Frame", nil, convey)
	bar:SetPoint("BOTTOMLEFT", convey.icon, "BOTTOMRIGHT", 10, 0)
	bar:SetPoint("RIGHT")
	bar:SetHeight(L.batch)
	UI.Skin(bar, C.bg, C.border)
	-- Inside the bar's edge: what is laid by width.
	bar.room = CreateFrame("Frame", nil, bar)
	bar.room:SetPoint("TOPLEFT", 1, -1)
	bar.room:SetPoint("BOTTOMRIGHT", -1, 1)
	local function Fill(sub, alpha)
		local t = bar.room:CreateTexture(nil, "ARTWORK", nil, sub)
		Skin.Hatch(t)
		Theme.Tint(t, Theme.Accent)
		t:SetAlpha(alpha)
		return t
	end
	bar.done = Fill(1, 1)
	bar.now = Fill(1, 0.5)
	bar.spark = bar.room:CreateTexture(nil, "ARTWORK", nil, 4)
	bar.spark:SetColorTexture(1, 1, 1, 0.85)
	bar.done:Hide()
	bar.now:Hide()
	bar.spark:Hide()
	bar.ups, bar.cuts = {}, {}
	convey.bar = bar
	convey.text = Text(convey, UI.NameFont(12), C.text)
	convey.text:SetPoint("TOPLEFT", convey.icon, "TOPRIGHT", 10, 1)
	convey.text:SetWordWrap(false)
	convey.aside = Text(convey, UI.TextFont(11), C.dim)
	convey.aside:SetPoint("LEFT", convey.text, "RIGHT", 6, 0)
	convey.aside:SetJustifyH("LEFT")
	convey.aside:SetWordWrap(false)
	convey.badge = UI.Badge(convey)
	convey.badge:SetPoint("TOPRIGHT", 0, 3)
	convey:SetScript("OnUpdate", function(self) self:Lay() end)

	-- A piece of the bar, made the first time it's wanted: a cut between two, or the light on one that gave a point.
	local function Piece(list, i, sub)
		local t = list[i]
		if not t then
			t = bar.room:CreateTexture(nil, "ARTWORK", nil, sub)
			t:SetColorTexture(1, 1, 1, 1)
			list[i] = t
		end
		return t
	end
	-- A piece laid `x` in from the bar's left, `w` wide, its full height.
	local function Span(t, x, w)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", x, 0)
		t:SetPoint("BOTTOMLEFT", x, 0)
		t:SetWidth(w)
	end
	local function Hide(list, from)
		for i = from, #list do list[i]:Hide() end
	end
	-- Laid every frame while making: the cast's own clock fills the piece in hand.
	function convey:Lay()
		local m = making
		if not m then return end
		local total = m.total
		local left = C_TradeSkillUI.GetRemainingRecasts() or 0
		local now = math.min(total, math.max(1, total - left))
		local p = 0
		local _, _, _, from, to, _, _, _, spell = UnitCastingInfo("player")
		if spell ~= nil and not issecretvalue(spell) and spell == m.recipe and not issecretvalue(from) and not issecretvalue(to)
			and to > from then
			m.span = (to - from) / 1000
			p = math.max(0, math.min(1, (GetTime() * 1000 - from) / (to - from)))
		end
		-- How far along, and about how long the rest takes at the pace of a cast.
		self.text:SetText(WORDS.making:format(now, total))
		local secs = m.span and math.ceil((total - now + 1 - p) * m.span)
		self.aside:SetText(not secs and "" or secs < 60 and WORDS.secLeft:format(secs) or WORDS.minLeft:format(math.ceil(secs / 60)))
		local w = bar.room:GetWidth()
		if issecretvalue(w) or w <= 0 then return end
		local each = w / total
		local doneW, nowW = (now - 1) * each, p * each
		bar.done:SetShown(doneW >= 1)
		Span(bar.done, 0, math.max(1, doneW))
		bar.now:SetShown(nowW >= 1)
		Span(bar.now, doneW, math.max(1, nowW))
		bar.spark:SetShown(p > 0 and p < 1)
		Span(bar.spark, math.max(0, doneW + nowW - 1), 2)
		-- The cuts: one between each two while there's room, else one every 5, 10, 25... so they never crowd.
		local step = 1
		for _, n in ipairs(L.cutEvery) do
			step = n
			if each * n >= L.cut then break end
		end
		local c = 0
		for i = step, total - 1, step do
			c = c + 1
			local t = Piece(bar.cuts, c, 5)
			t:SetVertexColor(0, 0, 0, 0.6)
			Span(t, math.floor(i * each), 1)
			t:Show()
		end
		Hide(bar.cuts, c + 1)
		-- The ones that gave a point, lit.
		local u = 0
		for i in pairs(m.ups) do
			if i <= total then
				u = u + 1
				local t = Piece(bar.ups, u, 2)
				local col = m.color
				t:SetVertexColor(col[1], col[2], col[3], 0.95)
				Span(t, (i - 1) * each, math.max(2, each))
				t:Show()
			end
		end
		Hide(bar.ups, u + 1)
	end
	own.convey = convey
	convey:Hide()
	-- Where to learn it.
	own.learn = CreateFrame("Button", nil, foot)
	own.learn:SetPoint("BOTTOMLEFT", 0, -2)
	own.learn:SetPoint("BOTTOMRIGHT", 0, -2)
	own.learn:SetHeight(46)
	UI.KeyPlate(own.learn)
	own.learn:SetTone(C.alert)
	own.learn.title = Text(own.learn, UI.TitleFont(13), C.head)
	own.learn.title:SetPoint("TOPLEFT", 10, -6)
	own.learn.words = Text(own.learn, UI.TextFont(11), C.text)
	own.learn.words:SetPoint("TOPLEFT", 10, -23)
	own.learn.words:SetPoint("RIGHT", -10, 0)
	own.learn.words:SetWordWrap(true)
	own.learn.words:SetMaxLines(2)
	own.learn:Hide()
end

-- Building: the window

local function Build()
	local f = Frame()
	local box = UI.Window({
		id = "shyskin.professions", title = TRADE_SKILLS,
		width = L.w, height = L.h,
		point = { "CENTER", "CENTER", -120, 40 },
		shown = function() return M ~= nil and M.on == true end,
		secure = true, inCombat = true,
		head = { size = "window", title = TRADE_SKILLS, close = false },
		-- It flows: everything hangs from its edges, and what is measured is laid again at the size it's given.
		grip = { flow = function() if Stale then Stale() end end, min = { L.w, L.h } },
	})
	own.box = box
	-- Opens and closes with the game's window.
	box:SetParent(f)
	-- The ×: the game's own close, so a trade skill open closes as the game closes it.
	local close = Secure(box.head, "ShySkinProfessionsClose")
	close:SetSize(HEAD.close, HEAD.close)
	close:SetPoint("RIGHT", box.head, "TOPRIGHT", -HEAD.pad + 2, -box.head.mid)
	close:SetAttribute("type1", "click")
	close:SetAttribute("clickbutton", f.CloseButton)
	close.glyph = close:CreateTexture(nil, "OVERLAY")
	close.glyph:SetTexture(UI.CLOSE_GLYPH)
	UI.GlyphFit(close.glyph, HEAD.glyph)
	close.glyph:SetPoint("CENTER")
	UI.KeyPress(close, { glyphs = { close.glyph }, sink = { close.glyph } })
	close:SetFrameLevel(box.head:GetFrameLevel() + 10)
	own.close = close

	-- On the window's body, as the craft is: clear of the look's work round the edge (UI.Body).
	own.book = CreateFrame("Frame", nil, box)
	own.book:SetAllPoints(UI.Body(box))
	local inner = L.w - 2 * L.pad
	own.cards = {
		Card("p1", inner, L.pane), Card("p2", inner, L.pane),
	}
	local small = math.floor((inner - 2 * L.cardGap) / 3)
	local tall = L.h - L.head0 - 8 - 2 * L.pane - 2 * L.cardGap - L.pad
	for i, key in ipairs({ "cook", "fish", "aid" }) do
		own.cards[2 + i] = Card(key, small, tall)
	end
	-- They flow: the two wide cards hang from both sides; the three small ones share the width (LayBook) and reach
	-- down to the window's foot.
	own.cards[1]:SetPoint("TOPLEFT", L.pad, -(L.head0 + 8))
	own.cards[1]:SetPoint("TOPRIGHT", -L.pad, -(L.head0 + 8))
	own.cards[2]:SetPoint("TOPLEFT", own.cards[1], "BOTTOMLEFT", 0, -L.cardGap)
	own.cards[2]:SetPoint("TOPRIGHT", own.cards[1], "BOTTOMRIGHT", 0, -L.cardGap)
	own.cards[3]:SetPoint("TOPLEFT", own.cards[2], "BOTTOMLEFT", 0, -L.cardGap)
	own.cards[3]:SetPoint("BOTTOM", own.book, "BOTTOM", 0, L.pad)
	for i = 4, 5 do
		own.cards[i]:SetPoint("TOPLEFT", own.cards[i - 1], "TOPRIGHT", L.cardGap, 0)
		own.cards[i]:SetPoint("BOTTOM", own.book, "BOTTOM", 0, L.pad)
	end

	BuildCraft(box)
	own.tabs = { Tab(1, false) }
	own.tabs[1]:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		page = "book"
		Refresh()
	end)
	own.tabs[1].tip = TRADE_SKILLS
	own.tabs[1].icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	for i = 2, 6 do own.tabs[i] = Tab(i, true) end
end

-- Filling the window: your professions

local function Painting(card, p)
	local atlas = p.kind == "primary" and p.name and ("Profession-overview-Card-" .. p.name) or (SECONDARY[p.kind] and SECONDARY[p.kind][1])
	local info = atlas and C_Texture.GetAtlasInfo(atlas)
	if info then
		card.art:SetAtlas(atlas)
		card.art:SetAlpha(0.75)
		card.art:Show()
	else
		card.art:Hide()
	end
	local q = C.panel
	card.burn:SetGradient("HORIZONTAL", CreateColor(q[1], q[2], q[3], 0.92), CreateColor(q[1], q[2], q[3], 0.25))
	card.rim:SetVertexColor(Skin.colors.edge[1], Skin.colors.edge[2], Skin.colors.edge[3], 0.75)
end

-- The professions' spells and tabs: secure, so set out of a fight.
local function Arm(list)
	ns.AfterCombat("professions:arm", function()
		local at = 1
		for i, p in ipairs(list) do
			local card = own.cards[i]
			for j, b in ipairs(card.spells) do
				local spell = p.spells and p.spells[j]
				b.spell = spell and spell.id
				b:SetAttribute("type1", spell and "spell" or nil)
				b:SetAttribute("spell", spell and spell.id or nil)
				b:SetAttribute("pickup", spell and spell.id or nil)
			end
			if p.crafts then
				at = at + 1
				local tab = own.tabs[at]
				if tab then
					tab:SetAttribute("type1", "spell")
					tab:SetAttribute("spell", p.spells[1].id)
					tab.skillLine, tab.tip = p.skillLine, p.name
					tab.skill, tab.cap, tab.skillSay = p.rank, p.max, p.rank .. " / " .. p.max
					tab.icon:SetTexture(p.icon)
					PaintTab(tab, tab.wash:IsShown())
				end
			end
		end
		for i = at + 1, #own.tabs do
			local tab = own.tabs[i]
			tab:SetAttribute("type1", nil)
			tab.skillLine = nil
			tab:Hide()
		end
		for i = 2, at do own.tabs[i]:Show() end
		own.spine:Fit(own.tabs[at])
		own.armed = list
	end)
end

-- A piece that holds secure buttons (a card's spells, the book the cards stand on) is the game's alone to show,
-- hide or size in a fight: it is left as it is then, and the window is drawn again as the fight ends
-- (PLAYER_REGEN_ENABLED). Whether it may be touched now.
local function Free(frame)
	return not (InCombatLockdown() and frame:IsProtected())
end

local function DrawBook()
	local list = Yours()
	-- The three small cards share the window's width (it flows).
	local small = math.floor((UI.BodySize(own.box) - 2 * L.pad - 2 * L.cardGap) / 3)
	for i = 3, 5 do
		if Free(own.cards[i]) then own.cards[i]:SetWidth(small) end
	end
	for i, p in ipairs(list) do
		local card = own.cards[i]
		local has = p.name ~= nil
		Painting(card, p)
		card.icon:SetShown(has)
		card.slot:Empty(not has)   -- an empty slot stays, dimmed, where the profession's picture would be
		card.name:SetShown(has)
		card.bar:SetShown(has)
		card.missing:SetShown(not has)
		card.words:SetShown(not has)
		if has then
			card.icon:SetTexture(p.icon)
			card.name:SetText(p.name)
			UI.Ink(card.name, C.head)
			local info = p.skillLine and C_TradeSkillUI.GetProfessionInfoBySkillLineID(p.skillLine)
			local skill, cap = p.rank, p.max
			if info and info.maxSkillLevel and info.maxSkillLevel > 0 then skill, cap = info.skillLevel, info.maxSkillLevel end
			SetBar(card.bar, skill, cap, p.modifier)
			-- Its tab's hairline (tabs are matched by skill line; a tab's place is set out of a fight).
			for t = 2, #own.tabs do
				local tab = own.tabs[t]
				if tab.skillLine == p.skillLine then tab.skill, tab.cap, tab.skillSay = skill, cap, skill .. " / " .. cap end
			end
		elseif p.kind == "primary" then
			card.missing:SetText(i == 1 and Global("PROFESSIONS_FIRST_PROFESSION") or Global("PROFESSIONS_SECOND_PROFESSION"))
			card.words:SetText(Global("PROFESSIONS_MISSING_PROFESSION"))
		else
			card.missing:SetText(Global(SECONDARY[p.kind][2]))
			card.words:SetText(Global(SECONDARY[p.kind][3]))
		end
		for j, b in ipairs(card.spells) do
			local spell = has and p.spells[j]
			if spell then
				b.icon:SetTexture(spell.icon)
				b.name:SetText(spell.name)
			end
			if not InCombatLockdown() then b:SetShown(spell ~= nil and spell ~= false) end
		end
	end
	if not InCombatLockdown() then Arm(list) end
end

-- Filling the window: the band

-- Your rank's name (Journeyman) by your cap, as the game's book names it; the profession's name without one.
local function Rank()
	local cap = prof and prof.maxSkillLevel or 0
	for _, r in ipairs(rawget(_G, "PROFESSION_RANKS") or {}) do
		if r[1] == cap and type(r[2]) == "string" then return r[2] end
	end
	return prof and (prof.parentProfessionName or prof.professionName) or ""
end

local function DrawBand()
	local skill, cap = prof and prof.skillLevel or 0, prof and prof.maxSkillLevel or 0
	local mine = Local()
	own.rank:SetText(Rank())
	SetBar(own.bar, skill, cap, prof and prof.skillModifier)
	own.link:SetShown(mine and C_TradeSkillUI.CanTradeSkillListLink() == true)
	-- A point gained since the window last drew it: a word for a moment (yours: someone's linked list isn't).
	local key = mine and prof and prof.professionID
	if key and seen[key] and skill > seen[key] then
		toast = { text = WORDS.up:format(prof.parentProfessionName or prof.professionName or "", skill), at = GetTime() + 4 }
		C_Timer.After(4.1, Stale)
	end
	if key then seen[key] = skill end
	local gain = (mine and picked and picked.learned and not making) and Ahead(picked.recipeID, picked.made or 0) or nil
	-- The ghost: from the end of the fill, its share of the bar (laid again as the bar flows).
	own.ghostShare = (gain and gain > 0.05 and cap > 0) and math.min(gain, cap - skill) / cap or nil
	own.ghost:SetShown(own.ghostShare ~= nil)
	own.LayGhost()
	if toast and toast.at > GetTime() then
		own.ahead:SetText(toast.text)
	elseif mine and picked and not picked.learned and Ranks(picked.recipeID) then
		local _, yellow = Ranks(picked.recipeID)
		own.ahead:SetText(Skill() < yellow and WORDS.learnAhead:format(yellow) or "")
	elseif gain and gain > 0.05 then
		own.ahead:SetText(WORDS.ahead:format(picked.made, math.floor(skill + gain + 0.5)))
	else
		own.ahead:SetText("")
	end
	-- Its own width: the bar fills the rest of the band (with nothing to say, right up to Link).
	own.LayBand()
end

-- Filling the window: the list

-- The best color a group holds: orange over yellow over green; none when every one is grey.
local function Best(group)
	local best
	for _, r in ipairs(group.recipes) do
		local dif = DIFFICULTY[Difficulty(r)]
		if dif and dif[3] < 4 and (not best or dif[3] < best[3]) then best = dif end
	end
	return best and best[1]
end

-- What a group holds, at its head's right: how many give a point (an up chevron in the best color in it) and how
-- many you can make now (a tick); its hover says both in words.
local function Badges(group)
	if mode == "learn" then
		return { { text = #group.recipes, color = C.dim, glyph = Skin.GLYPH.lock } }, WORDS.recipes:format(#group.recipes)
	end
	if mode == "profit" then
		return { { text = #group.recipes, color = C.good } }, WORDS.paying:format(#group.recipes) .. "."
	end
	local ups, ready = 0, 0
	for _, r in ipairs(group.recipes) do
		if r.relativeDifficulty ~= DIFF.Trivial then ups = ups + 1 end
		if (r.made or 0) > 0 then ready = ready + 1 end
	end
	local list = {}
	if ready > 0 then list[#list + 1] = { text = ready, color = C.good, glyph = Skin.GLYPH.tick } end
	local best = Best(group)
	if ups > 0 and best then
		list[#list + 1] = { text = ups, color = { best.r, best.g, best.b }, glyph = Skin.GLYPH.chevron, turn = math.pi / 2 }
	end
	local said = ups > 0 and (ups == 1 and WORDS.point or WORDS.points):format(ups) or WORDS.noPoints
	if ready > 0 then said = said .. ". " .. WORDS.ready:format(ready) end
	return list, said .. "."
end

local function DrawRow(row, r)
	row.recipe = r
	row.icon:SetTexture(r.icon)
	row.icon:SetDesaturated(not r.learned)
	row.name:SetText(r.name)
	local dif = DIFFICULTY[Difficulty(r)]
	if r.learned and dif then row.name:SetTextColor(dif[1]:GetRGB()) else UI.Ink(row.name, C.dim) end
	local n = r.made or 0
	row.count:SetText(n > 0 and n or "")
	row.count:SetShown(n > 0)
	row.pill:SetShown(n > 0)
	if n > 0 then
		row.pill:SetWidth(math.max(18, math.ceil(row.count:GetStringWidth()) + 10))
		UI.Paint(row.pill, C.good, 0.12)
	end
	row.lock:SetShown(not r.learned)
	-- The chance of a point, where it is neither every time nor never.
	local p = r.learned and Chance(r.recipeID, Skill()) or nil
	local odds = p and p > 0 and p < 1
	row.pct:SetShown(odds == true)
	if odds then
		row.pct:SetText(math.floor(p * 100 + 0.5) .. "%")
		row.pct:SetTextColor(dif[1]:GetRGB())
	end
	-- Under its name, with the house's prices: its profit or its loss making one.
	local plan = PlanOf(r)
	local profit = plan and plan.profit
	row.profit:SetShown(profit ~= nil)
	row.name:SetPoint("LEFT", row, "LEFT", 36, profit and 5 or 0)
	if profit then
		local words = profit >= 0 and WORDS.gain or WORDS.loss
		row.profit:SetText(words:format(UI.Money(math.floor(math.abs(profit) + 0.5), true, 10, row.profit)))
		UI.Ink(row.profit, profit >= 0 and C.good or C.bad)
	end
	local tracked = r.learned and C_TradeSkillUI.IsRecipeTracked(r.recipeID, false)
	row.pin:SetShown(tracked == true)
	if tracked then
		row.pin:ClearAllPoints()
		row.pin:SetPoint("RIGHT", row, "RIGHT", odds and -60 or -34, 0)
	end
	local on = picked and picked.recipeID == r.recipeID
	if on then
		local cr, cg, cb = Theme.Accent()
		row.lit:SetGradient("HORIZONTAL", CreateColor(cr, cg, cb, 0.22), CreateColor(cr, cg, cb, 0.02))
		row.edge:SetWidth(UI.BoxPixels(row, 2))
	end
	row.lit:SetShown(on == true)
	row.edge:SetShown(on == true)
end

local function DrawList()
	local y, rowAt = 0, 0
	local width = L.list - 8
	for gi, group in ipairs(heads) do
		local h = Head(gi)
		h.key = group.key
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", own.list.content, "TOPLEFT", 0, -y)
		h:SetWidth(width)
		h:Set(group.name)
		local badges, said = Badges(group)
		h:SetBadges(badges)
		h.name, h.say = group.name, said
		h:SetAccent(mode ~= "profit" and Best(group) or nil)
		local open = not folds[group.key]
		h:SetOpen(open)
		h:Show()
		local top = y
		y = y + L.head
		if open then
			y = y + L.groupTop
			local nodes = {}
			for _, r in ipairs(group.recipes) do
				rowAt = rowAt + 1
				local row = Row(rowAt)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", own.list.content, "TOPLEFT", L.indent, -y)
				row:SetWidth(width - L.indent)
				DrawRow(row, r)
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
	for i = #heads + 1, #own.heads do own.heads[i]:Hide() end
	for i = rowAt + 1, #own.rows do own.rows[i]:Hide() end
	own.list.content:SetSize(L.list, math.max(1, y))
	own.list:Update()
	own.filter:SetCount(2, tally.make > 0 and tally.make or nil)
	own.filter:SetCount(3, tally.ups > 0 and tally.ups or nil)
end

-- Filling the window: the recipe

-- The spell focus it needs, and the recipe you know that builds one.
local function Builder(id)
	local focus = ns.recipeFocus and ns.recipeFocus[id]
	for _, spell in ipairs(focus and ns.focusBuilders and ns.focusBuilders[focus] or {}) do
		local r = C_TradeSkillUI.GetRecipeInfo(spell)
		if r and r.learned then return r end
	end
end

-- An item's name, or nil while the game hasn't seen it yet: then it is asked for, and the recipe is drawn again
-- when it comes (ITEM_DATA_LOAD_RESULT).
local function ItemName(item)
	local name = C_Item.GetItemNameByID(item)
	if not name then
		own.waiting[item] = true
		C_Item.RequestLoadItemDataByID(item)
	end
	return name
end

local function DrawRecipe()
	local d = own.detail
	d:SetShown(picked ~= nil)
	if Free(own.foot) then own.foot:SetShown(picked ~= nil) end   -- it holds Create, a secure button
	own.bloom:SetShown(picked ~= nil)
	if not picked then return end
	local id = picked.recipeID
	local learned = picked.learned == true
	local mine = Local()
	local skill = Skill()
	local schematic = C_TradeSkillUI.GetRecipeSchematic(id, false)
	local output = C_TradeSkillUI.GetRecipeOutputItemData(id)
	local itemID = output and output.itemID
	local quality = itemID and C_Item.GetItemQualityByID(itemID)
	own.out.icon:SetTexture((output and output.icon) or picked.icon)
	own.out.icon:SetDesaturated(not learned)
	local qc = quality and ITEM_QUALITY_COLORS[quality]
	own.out.slot:Quality(quality)
	own.name:SetText((itemID and ItemName(itemID)) or picked.name)
	if qc then own.name:SetTextColor(qc.r, qc.g, qc.b) else UI.Ink(own.name, C.text) end
	local made = schematic and schematic.quantityMin or 1
	if schematic and schematic.quantityMax and schematic.quantityMax > made then made = made .. "-" .. schematic.quantityMax end
	local parts = { itemID and ("Makes " .. made) or (picked.alternateVerb ~= "" and picked.alternateVerb) or "" }
	local cat = C_TradeSkillUI.GetCategoryInfo(picked.categoryID)
	if cat and cat.name then parts[#parts + 1] = cat.name end
	own.sub:SetText(table.concat(parts, Dot()))
	own.star:SetShown(learned and mine)
	own.pin:SetShown(learned and mine)
	if learned and mine then
		own.star:SetOn(picked.favorite == true)
		own.pin:SetOn(C_TradeSkillUI.IsRecipeTracked(id, false) == true)
	end

	-- Where it takes your skill.
	local y = L.out + 20
	local difKey = Difficulty(picked)
	local dif = DIFFICULTY[difKey]
	own.skillKick:SetPoint("TOP", d, "TOP", 0, -y)
	own.skillKick:Say(WORDS.ups, dif and dif[2], dif and dif[1])
	y = y + 34
	local learnedAt = Ranks(id)
	own.ribbon:SetShown(learnedAt ~= nil)
	if learnedAt then
		SetRibbon(own.ribbon, id, learnedAt, skill, Wide())
		own.ribbon:ClearAllPoints()
		own.ribbon:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
		y = y + 34
	end
	local _, yellow, _, grey = Ranks(id)
	local p = Chance(id, skill)
	local odds
	if not learned and yellow then
		odds = WORDS.learnOdds:format(yellow)
	elseif yellow and difKey == DIFF.Optimal then
		odds = WORDS.always:format(yellow)
	elseif p and p > 0 then
		local r, g, b = dif[1]:GetRGB()
		odds = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5),
			WORDS.now:format(math.floor(p * 100 + 0.5)))
			.. "|cff888888" .. Dot() .. WORDS.grey:format(grey) .. "|r"
	end
	own.odds:SetShown(odds ~= nil)
	if odds then
		own.odds:SetText(odds)
		own.odds:ClearAllPoints()
		own.odds:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
		y = y + 28
	end

	-- What it needs nearby: the game's requirements, a cooldown, and the recipe that builds what's missing.
	local needs = {}
	if learned and mine then
		for _, req in ipairs(C_TradeSkillUI.GetRecipeRequirements(id) or {}) do
			needs[#needs + 1] = { req.name, req.met, WORDS.needsA:format(req.name) }
		end
		local cooldown, _, charges = C_TradeSkillUI.GetRecipeCooldown(id)
		if cooldown and cooldown > 0 and not (charges and charges > 0) then
			local ready = "Ready in " .. SecondsToTime(cooldown)
			needs[#needs + 1] = { ready, false, ready }
		end
	end
	local x = 0
	local unmet
	for i, need in ipairs(needs) do
		local n = Need(i)
		n.text:SetText(need[1])   -- a tool or a fire alike: its name, ticked or crossed
		n.glyph:SetTexture(need[2] and Skin.GLYPH.tick or UI.CLOSE_GLYPH)
		UI.Tint(n.glyph, need[2] and C.good or C.bad)
		UI.Ink(n.text, need[2] and C.text or C.bad)
		n:SetTone(need[2] and C.good or C.bad)
		n:SetWidth(math.ceil(n.text:GetStringWidth()) + 36)
		n:ClearAllPoints()
		n:SetPoint("TOPLEFT", d, "TOPLEFT", x, -y)
		x = x + n:GetWidth() + 8
		n:Show()
		if not need[2] then unmet = true end
	end
	for i = #needs + 1, #own.needs do own.needs[i]:Hide() end
	local builder = unmet and Builder(id)
	own.build.recipe = builder
	own.build:SetShown(builder ~= nil)
	if builder then
		own.build:SetLabel(WORDS.build:format(builder.name))
		own.build:SetWidth(math.ceil(own.build.text:GetStringWidth()) + 24)
		own.build:ClearAllPoints()
		own.build:SetPoint("TOPLEFT", d, "TOPLEFT", x, -y)
	end
	own.needKick:Hide()
	if #needs > 0 then y = y + 22 + 14 end

	-- The reagents, two a row: have against need, the bank's beside it, and what they cost.
	local plan = itemID and PlanOf(picked, true)
	local costs = {}
	for _, row in ipairs(plan and plan.reagents or {}) do costs[row.item] = row.unit end
	local can = (learned and mine) and C_TradeSkillUI.GetCraftableCount(id) or 0
	own.reagKick:ClearAllPoints()
	own.reagKick:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
	own.reagKick:SetPoint("RIGHT", d, "RIGHT")
	own.reagKick:Say(WORDS.reagents, can > 0 and WORDS.enough:format(can) or nil)
	y = y + 22
	local shown = 0
	local times = learned and math.max(1, count) or 1
	for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
		local reagent = slot.required and slot.reagents and slot.reagents[1]
		local item = reagent and reagent.itemID
		if item then
			shown = shown + 1
			local r = Reagent(shown)
			r.item = item
			r.icon:SetTexture(C_Item.GetItemIconByID(item))
			r.slot:Quality(C_Item.GetItemQualityByID(item))
			r.need:SetText(slot.quantityRequired > 1 and slot.quantityRequired or "")
			r.name:SetText(ItemName(item) or "")
			local have, want = Have(item), slot.quantityRequired * times
			local unit = costs[item]
			r.cost:SetShown(unit ~= nil)
			if unit then
				r.cost:SetText(UI.Money(math.floor(unit * want + 0.5), true, 11, r.cost))
				r.name:SetPoint("RIGHT", r.cost, "LEFT", -6, 0)
			else
				r.name:SetPoint("RIGHT", r, "RIGHT", -8, 0)
			end
			local bank = math.max(0, (C_Item.GetItemCount(item, true) or 0) - have)
			r.have:SetText(UI.Wrap(have >= want and C.good or C.bad, have) .. " of " .. want
				.. (bank > 0 and (Dot() .. WORDS.bank:format(bank)) or ""))
			r.icon:SetDesaturated(have < want)
			-- Two a row, sharing the room the recipe has.
			local card = math.floor((Wide() - 8) / 2)
			r:SetWidth(card)
			local wide = card - L.reag - 21
			r.fill:SetWidth(math.max(1, wide * math.min(1, have / math.max(1, want))))
			UI.Paint(r.fill, have >= want and C.good or C.bad)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", d, "TOPLEFT", ((shown - 1) % 2) * (card + 8), -(y + math.floor((shown - 1) / 2) * (L.cardH + 8)))
			r:Show()
		end
	end
	for i = shown + 1, #own.reagents do own.reagents[i]:Hide() end
	own.reagKick:SetShown(shown > 0)
	y = y + math.ceil(shown / 2) * (L.cardH + 8) + 6

	-- What it's worth: what it sells for, its reagents and the profit side by side; under them what you lack, or for a
	-- recipe you don't know, its own price and the crafts that pay it back.
	own.worthKick:SetShown(plan ~= nil)
	own.worthPlate:SetShown(plan ~= nil)
	own.worthSay:SetShown(false)
	if plan then
		local function Coins(c, at) return UI.Money(math.floor(c + 0.5), true, nil, at) end
		own.worthKick:ClearAllPoints()
		own.worthKick:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
		own.worthKick:SetPoint("RIGHT", d, "RIGHT")
		own.worthKick:Say(WORDS.worthHead, (not plan.profit and WORDS.unpriced)
			or (plan.rate and WORDS.afterCut:format(math.floor(plan.rate * 100 + 0.5))) or nil, C.dim)
		y = y + 22
		local priced = #plan.reagents > 0
		for _, row in ipairs(plan.reagents) do priced = priced and row.unit ~= nil end
		local cells = {
			{ plan.worth == "vendor" and WORDS.vendorPays or WORDS.sells, plan.value, C.text },
			{ WORDS.reagentsCost, priced and plan.cost or nil, C.text },
			{ (plan.profit or 0) < 0 and WORDS.lossCell or WORDS.profitCell, plan.profit and math.abs(plan.profit),
				plan.profit and (plan.profit >= 0 and C.good or C.bad) or C.dim },
		}
		local plate, wide = own.worthPlate, Wide()
		plate:ClearAllPoints()
		plate:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
		plate:SetWidth(wide)
		local e = C.border
		for i, cell in ipairs(own.worthCells) do
			local c = cells[i]
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", plate, "TOPLEFT", math.floor((i - 1) * wide / 3), 0)
			cell:SetWidth(math.floor(wide / 3))
			cell.label:SetText(c[1])
			cell.money:SetText(c[2] and Coins(c[2], cell.money) or WORDS.noPrice)
			UI.Ink(cell.money, c[2] and c[3] or C.dim)
			if cell.rule then cell.rule:SetVertexColor(e[1], e[2], e[3], 0.6) end
		end
		y = y + 42 + 8
		local lines = {}
		if learned and mine and (plan.buy or 0) > 0 then
			lines[#lines + 1] = (plan.afford and WORDS.lack or WORDS.lackPoor):format(Coins(plan.buy))
		end
		if not learned and plan.learn and plan.learn.cost then
			lines[#lines + 1] = WORDS.recipeCost:format(Coins(plan.learn.cost))
				.. (plan.learn.crafts and WORDS.payback:format(plan.learn.crafts) or "")
		end
		if #lines > 0 then
			local say = own.worthSay
			say:SetWidth(wide)
			say:SetText(UI.MoneyFit(table.concat(lines, "\n"), say))
			say:ClearAllPoints()
			say:SetPoint("TOPLEFT", d, "TOPLEFT", 2, -y)
			say:Show()
			y = y + math.ceil(say:GetStringHeight()) + 10
		end
	end

	-- What it makes, as the game describes the item: its tooltip's lines after the name, as many as fit.
	local tip = itemID and C_TooltipInfo.GetRecipeResultItem(id)
	local lines = (type(tip) == "table" and not issecretvalue(tip) and tip.lines) or {}
	local used = 0
	own.itemKick:ClearAllPoints()
	own.itemKick:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -y)
	own.itemKick:SetPoint("RIGHT", d, "RIGHT")
	own.itemKick:Say(WORDS.makes)
	local ly = 8
	local room = (select(2, UI.BodySize(own.box)) - L.top - L.pad - L.foot - 8) - y - 30
	local inner = Wide() - 20   -- the box's width inside its padding
	for i = 2, #lines do
		local line = lines[i]
		local left = line and line.leftText
		if type(left) == "string" and not issecretvalue(left) and left ~= "" and ly + 15 <= room then
			used = used + 1
			local l = Line(used)
			local right = line.rightText
			right = type(right) == "string" and not issecretvalue(right) and right or ""
			-- A line alone wraps to the box (a Use: line runs long), as many lines as are left; one with words at
			-- its right stays one line, cut short of them.
			l.left:SetWidth(right ~= "" and math.floor(inner * 0.65) or inner)
			l.left:SetWordWrap(right == "")
			l.left:SetMaxLines(right == "" and math.max(1, math.floor((room - ly) / 15)) or 1)
			l.left:SetText(left)
			l.left:ClearAllPoints()
			l.left:SetPoint("TOPLEFT", own.item, "TOPLEFT", 10, -ly)
			l.right:SetText(right)
			l.right:ClearAllPoints()
			l.right:SetPoint("TOPRIGHT", own.item, "TOPRIGHT", -10, -ly)
			local color = line.leftColor
			if color and color.GetRGB then l.left:SetTextColor(color:GetRGB()) else UI.Ink(l.left, C.text) end
			local rc = line.rightColor
			if rc and rc.GetRGB then l.right:SetTextColor(rc:GetRGB()) else UI.Ink(l.right, C.text) end
			l.left:Show()
			l.right:Show()
			ly = ly + math.max(15, math.ceil(l.left:GetStringHeight())) + 2
		end
	end
	for i = used + 1, #own.lines do
		own.lines[i].left:Hide()
		own.lines[i].right:Hide()
	end
	own.itemKick:SetShown(used > 0)
	own.item:SetShown(used > 0)
	own.item:ClearAllPoints()
	own.item:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -(y + 22))
	own.item:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, -(y + 22))
	own.item:SetHeight(ly + 6)

	-- The foot.
	local met, missing = true, nil
	for _, need in ipairs(needs) do
		met = met and need[2]
		if not need[2] then missing = missing or need[3] end
	end
	local enchant = picked.isEnchantingRecipe == true
	local busy = making ~= nil
	if enchant then count = 1 end
	count = math.max(1, math.min(count, math.max(can, 1)))
	local why = (not met and (missing or WORDS.missing)) or (can < 1 and WORDS.short) or nil
	local usable = learned and can > 0 and met and not busy
	-- The count as typed stays while you type; settled, it shows what Create will make.
	local box = own.count
	local typing = box:HasFocus() and usable and not enchant
	if box:HasFocus() and not typing then box:ClearFocus() end
	if not typing then box:SetText(count) end
	box:EnableMouse(usable and not enchant)
	-- Beside the count, the skill it should give.
	local gain = (usable and not enchant) and Ahead(id, count) or nil
	local create = own.create
	create.off, create.why = not usable, why
	create:SetAlpha(usable and 1 or 0.45)
	if not InCombatLockdown() then
		create:SetAttribute("type1", (enchant and usable) and "spell" or nil)
		create:SetAttribute("spell", (enchant and usable) and id or nil)
	end
	local all = own.createAll
	all.off = not usable
	all:SetAlpha(usable and 1 or 0.45)
	all.text:SetText(can > 0 and WORDS.createAll:format(math.min(L.most, can)) or WORDS.createNone)
	own.less:SetOff(not usable or count <= 1 or enchant)
	own.more:SetOff(not usable or count >= can or enchant)
	-- A recipe you don't know: the foot says where to learn it.
	-- Someone else's list: nothing to make here, as the game's own window has it.
	local stepping = learned and mine and not busy
	own.learn:SetShown(not learned and mine)
	if not InCombatLockdown() then create:SetShown(learned and mine) end
	own.qty:SetShown(stepping)
	all:SetShown(stepping and not enchant)
	own.worth:SetShown(stepping and why == nil and gain ~= nil and gain >= 0.5)
	own.worth:SetText(gain and WORDS.worth:format(math.floor(gain + 0.5)) or "")
	own.status:SetShown(stepping and why ~= nil)
	own.status:SetText(why or "")
	own.footRule:SetShown(learned and mine)
	local e = C.border
	own.footRule:SetGradient("HORIZONTAL", CreateColor(e[1], e[2], e[3], 0), CreateColor(e[1], e[2], e[3], 0.9))
	if not learned and mine then
		own.learn.title:SetText(WORDS.learn)
		local source = C_TradeSkillUI.GetRecipeSourceText(id)
		own.learn.words:SetText(type(source) == "string" and not issecretvalue(source) and source:gsub("|n", "  ") or "")
	end
	-- The batch, on its bar in the room left of Create. A point gained is the last one finished's: its piece lit.
	own.convey:SetShown(busy and learned)
	if busy then
		local m, convey = making, own.convey
		local skill = Skill()
		if skill > m.last then
			local left = C_TradeSkillUI.GetRemainingRecasts() or 0
			m.ups[math.max(1, math.min(m.total, m.total - left - 1))] = true
			m.last = skill
		end
		convey.icon:SetTexture(m.icon)
		local gained = math.max(0, skill - m.skill)
		convey.badge:SetShown(gained > 0)
		if gained > 0 then convey.badge:Set({ text = gained, color = m.color, glyph = Skin.GLYPH.chevron, turn = math.pi / 2 }) end
		convey.aside:SetPoint("RIGHT", gained > 0 and convey.badge or convey, gained > 0 and "LEFT" or "RIGHT", -6, 0)
		convey:Lay()
	end
end

-- The profession's painting behind the recipe, as the game's own recipe page has it.
local function DrawStage()
	local game = rawget(_G, "Professions")
	local atlas = prof and game and game.GetProfessionBackgroundAtlas and game.GetProfessionBackgroundAtlas(prof)
	local info = atlas and C_Texture.GetAtlasInfo(atlas)
	own.paint:SetShown(info ~= nil)
	if info then
		own.paint:SetAtlas(atlas)
		own.paint:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.7), CreateColor(1, 1, 1, 0))
		-- Cover the stage: the window's room less the list and the band, at the painting's own proportions.
		local w = UI.BodySize(own.box) - (L.pad + L.list + L.gap / 2 + 1) - 2
		local h = select(2, UI.BodySize(own.box)) - (L.head0 + L.band) - 2
		local aw, ah = info.width or 0, info.height or 0
		if aw > 0 and ah > 0 then
			local k = math.max(w / aw, h / ah)
			own.paint:SetSize(aw * k, ah * k)
		else
			own.paint:SetSize(w, h)
		end
	end
end

-- The game's window, emptied: every piece of it in the attic, its art hidden, no mouse. Out of a fight only: its
-- book page holds secure buttons, so it is protected.
local function Empty(kit)
	local f = Frame()
	if InCombatLockdown() then return end
	local attic = Shop.AtticOf(f)
	local kids = {}
	for _, kid in ipairs({ f:GetChildren() }) do
		if kid ~= own.box and kid ~= attic and not kid:IsForbidden() then kids[#kids + 1] = kid end
	end
	Shop.PutAway(f, unpack(kids))
	for _, region in ipairs({ f:GetRegions() }) do kit:Hide(region) end
	if mouse == nil then mouse = f:IsMouseEnabled() end
	f:EnableMouse(false)
end

local function Draw()
	-- While the game rebuilds its recipe list, the recipes read last stay (TRADE_SKILL_LIST_UPDATE draws again once
	-- it's built, as the game's own window waits). Your professions don't come from that list, so they never wait.
	if not C_TradeSkillUI.IsDataSourceChanging() then Read() end
	-- The game's pages say which is up: the book page, or a profession's recipes once they're read (the page asked
	-- for is kept, so a profession opened while its list is built shows when it arrives).
	local craft = page == "craft" and Open()
	if Free(own.book) then own.book:SetShown(not craft) end
	if Free(own.craft) then own.craft:SetShown(craft) end
	-- The title: the profession, and whose it is when someone linked theirs (as the game's title says it).
	local title = craft and prof and (prof.parentProfessionName or prof.professionName) or TRADE_SKILLS
	local linked, whose = C_TradeSkillUI.IsTradeSkillLinked()
	if craft and linked and type(whose) == "string" and not issecretvalue(whose) then title = WORDS.theirs:format(title, whose) end
	own.box.head.title:SetText(title)
	DrawBook()
	-- The tabs: your professions, then the profession open (yours; none for someone else's).
	local mine = Local()
	PaintTab(own.tabs[1], not craft)
	for i = 2, #own.tabs do
		local tab = own.tabs[i]
		PaintTab(tab, craft and mine and prof ~= nil and tab.skillLine ~= nil
			and (tab.skillLine == prof.parentProfessionID or tab.skillLine == prof.professionID))
	end
	if not craft then return end
	DrawList()
	DrawRecipe()
	DrawBand()
	DrawStage()
end

Refresh = function()
	local f = Frame()
	if not (M and M.on and own.box and f and f:IsShown()) then return end
	Shop.Try(M, Draw)
end

Stale = Shop.Later(function() Refresh() end)

-- The module

local EVENTS = { "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW", "TRADE_SKILL_NAME_UPDATE", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
	"TRADE_SKILL_CLOSE", "TRADE_SKILL_FAVORITES_CHANGED", "TRACKED_RECIPE_UPDATE", "PLAYER_REGEN_ENABLED", "ITEM_DATA_LOAD_RESULT",
	"PLAYER_MONEY" }

local function Hook()
	local f = Frame()
	f:HookScript("OnShow", function()
		if not M.on then return end
		page = (f.BookPage and f.BookPage:IsShown()) and "book" or (Open() and "craft" or "book")
		Refresh()
	end)
	f:HookScript("OnHide", function()
		making = nil
		Unlearn()
	end)
	-- The game moves between its pages (they are in the attic, so no OnShow comes from them): ours follows its calls.
	if f.SelectBookPage then hooksecurefunc(f, "SelectBookPage", function() if M.on then page = "book"; Stale() end end) end
	EventRegistry:RegisterCallback("Professions.ProfessionSelected", function() if M.on then Stale() end end, own)
	-- Prices changed (a scan, a search at the auction house): the list's plans are worked out again.
	Shy:On("SHY_AUCTION", function(why)
		if why ~= "scan" and why ~= "price" then return end
		wipe(plans)
		if M.on and Frame():IsShown() then Stale() end
	end)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event, unit, _, spellID)
		if event == "ITEM_DATA_LOAD_RESULT" then
			if not own.waiting[unit] then return end   -- unit is the item here: only ours draw again
			own.waiting[unit] = nil
		elseif event:find("^UNIT_SPELLCAST") then
			if unit ~= "player" or not making then return end
			local left = C_TradeSkillUI.GetRemainingRecasts() or 0
			if event == "UNIT_SPELLCAST_SUCCEEDED" then
				if spellID == making.recipe and left == 0 then making = nil end
			elseif event ~= "UNIT_SPELLCAST_START" and left == 0 then
				making = nil   -- stopped or failed with nothing more to make
			end
		elseif event == "TRADE_SKILL_SHOW" then
			page = "craft"
		elseif event == "TRADE_SKILL_CLOSE" then
			making = nil
			Unlearn()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if M.on and not own.box then M:Refresh() end   -- first loaded in a fight: built now
		end
		if M.on and Frame():IsShown() then Stale() end
	end)
end

local function Paint(m, kit)
	-- Secure frames are made, parented and armed out of a fight.
	if not own.box and InCombatLockdown() then return end
	Shop.Try(m, function()
		if not own.box then Build() end
		Shy.HUD.Update(own.box)
		own.spine = ns.Spine(kit, own.box, "profSpine")
		Empty(kit)
		-- The list's filter stands in for the game's two: theirs off, so nothing hides a recipe out of sight.
		if C_TradeSkillUI.GetOnlyShowMakeableRecipes() then C_TradeSkillUI.SetOnlyShowMakeableRecipes(false) end
		if C_TradeSkillUI.GetOnlyShowSkillUpRecipes() then C_TradeSkillUI.SetOnlyShowSkillUpRecipes(false) end
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	making = nil
	Unlearn()
	local f = Frame()
	ns.AfterCombat("professions:clear", function()
		if M.on then return end
		Shop.BringBack(f)
		if mouse ~= nil then f:EnableMouse(mouse) end
		if own.box then Shy.HUD.Update(own.box) end
	end)
end

M = ns.Module({
	id = "professions",
	title = "Professions",
	desc = "Replaces the professions window with one of your own: your professions with their skills and spells, and each profession's recipes with where they take your skill and what each needs.",
	Ready = function() return ProfessionsFrame ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
})
