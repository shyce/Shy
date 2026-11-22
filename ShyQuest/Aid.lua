-- First Aid as your way to healing potions. Adds stops to learn it and train its recipes, a row to
-- make the potions once your bags hold the materials, and the herb from a nearby auction house.
-- Cloth in your bags goes to the bandages that raise the skill most per cloth, while a skill-up is
-- likely. Cloth that a trainer's next recipe or rank would use far better is saved for that.
--   Recipes: Data/Supplies.lua (ns.data.aid). Only the server knows what a trainer charges, so the
--     cost is read from a first aid trainer's window and saved per account (T.db.aid). Until one
--     has been seen, the trainer is a stop while no potion recipe is known.
--   Known: from the spellbook, a trainer's list, and the game saying a recipe was learned
--     (ns.char.aid). The skill is read the way the game's skills window reads it (C_SkillInfo).
--   Vials and spices are vendor goods. Supplies.lua buys them (Supplies.Mats).
--   Everything follows the healing potions amount (Supplies.lua). Set to Off, none of this shows.
-- Nothing is trained, made or bought for you.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Supplies = ns.Data, ns.World, ns.Log, ns.Route, ns.Supplies
local UI = Shy.UI

local Aid = {}
ns.Aid = Aid

-- A trainer's list: ["Name"] or ["Name|rank"] = { skill, level, copper }; and who showed one, by NPC.
T.defaults.aid = { list = {}, trainers = {} }
T.keep.aid = true            -- read from the game: per account, not per profile

local LEARN = 5              -- level from which learning it is a stop
local LISTED = 800           -- yards: a trainer or an auctioneer this near gets a row on the card
local TRAINER_WORTH = 900    -- yards of walk the trainer is worth, off the way (R.Passing)
local WORTH = 3              -- points of skill the cloth must be good for to get a row; less waits for more cloth
local SLIM = 0.3             -- a bandage less likely than this to raise the skill is no use of cloth
local MOST = 400             -- bandages thought ahead
local NEXT_RANK = 25         -- a rank is taught this far under the cap of the one before
local RANK = 75              -- what a rank adds to the cap
local TITLES = { "First Aid Trainer", "Physician" }   -- what its trainers are called (Data/Town.lua)

local recipes                -- { spell, kind, item, count, yellow, grey, auto, needs = { { id, count }, ... } }, highest first
local line = {}              -- skill lines: aid, tailor, herbs
local state, from            -- last result of Work, and the supplies it went by
local stale = true
local put                    -- "Not now": the row to make this, this many, stays away

local function Load()
	if recipes then return end
	recipes = {}
	for spell, text in pairs(ns.data.aid or {}) do
		local f = {}
		for field in (text .. "^"):gmatch("(.-)%^") do f[#f + 1] = field end
		local recipe = { spell = spell, kind = f[1], item = tonumber(f[2]), count = tonumber(f[3]) or 1,
			yellow = tonumber(f[4]) or 0, grey = tonumber(f[5]) or 0, auto = f[6] == "a", needs = {}, takes = 0 }
		for id, many in (f[7] or ""):gmatch("(%d+):(%d+)") do
			recipe.needs[#recipe.needs + 1] = { tonumber(id), tonumber(many) }
			recipe.takes = recipe.takes + tonumber(many)
		end
		recipes[#recipes + 1] = recipe
	end
	table.sort(recipes, function(a, b)
		if a.yellow ~= b.yellow then return a.yellow > b.yellow end
		return a.spell < b.spell
	end)
	local aid, tailor, herbs = (ns.data.skills or ""):match("^(%d+),(%d+),(%d+)$")
	line.aid, line.tailor, line.herbs = tonumber(aid), tonumber(tailor), tonumber(herbs)
end

-- A skill's points and their cap, as the game's skills window has them; 0 and 0 for one the
-- character has not learned.
local function Skill(id)
	local info = id and C_SkillInfo.GetSkillLineInfoByID(id)
	return info and info.rank or 0, info and info.maxRank or 0
end

-- This character's: { known = { [a trainer's entry] = true }, skip }.
local function Mine()
	local mine = ns.char.aid
	if not mine then
		mine = { known = {} }
		ns.char.aid = mine
	end
	return mine
end

local function Knows(recipe)
	if recipe.auto or C_SpellBook.IsSpellKnown(recipe.spell) then return true end
	local name = C_Spell.GetSpellName(recipe.spell)
	return name ~= nil and Mine().known[name] == true
end

local function Name(id)
	return C_Item.GetItemNameByID(id) or D.Name("items", id) or "them"
end

-- Whether vendors sell this: the rest is found, or bought from other players.
local function Sold(id)
	local item = Supplies.Item(id)
	return item ~= nil and item.mat == true
end

-- How many of a recipe the bags hold the makings of.
local function Can(recipe)
	local most
	for _, need in ipairs(recipe.needs) do
		local fits = math.floor(C_Item.GetItemCount(need[1]) / need[2])
		most = most and math.min(most, fits) or fits
	end
	return most or 0
end

-- The chance that making it raises the skill: sure until it turns yellow, none once it is grey.
local function Chance(recipe, skill)
	if skill < recipe.yellow then return 1 end
	if skill >= recipe.grey then return 0 end
	return (recipe.grey - skill) / (recipe.grey - recipe.yellow)
end
Aid.Chance = Chance          -- any recipe with `yellow` and `grey` (Camp.lua's cooking)

-- The cloth in the bags made into bandages one at a time, each the one likeliest to raise the skill
-- for the cloth it takes, as far as that is still likely. `more`: recipes to count as known, `cap`:
-- the cap to count on (what a trainer would teach now). Returns the bandages in the order they come
-- up, { { recipe, count, points }, ... }, and the points of skill all of it should bring.
local function Cloth(now, more, cap)
	local known, left, legs, points, skill = {}, {}, {}, 0, now.skill
	cap = cap or now.cap
	for _, each in ipairs(recipes) do
		if each.kind == "b" and each.takes > 0 and (Knows(each) or more ~= nil and more[each] == true) then
			known[#known + 1] = each
			for _, need in ipairs(each.needs) do left[need[1]] = C_Item.GetItemCount(need[1]) end
		end
	end
	for _ = 1, MOST do
		if skill >= cap then break end
		local best, chance, worth
		for _, each in ipairs(known) do
			local likely, fits = Chance(each, skill), true
			for _, need in ipairs(each.needs) do
				if left[need[1]] < need[2] then fits = false end
			end
			local value = likely / each.takes
			if fits and likely >= SLIM and (not best or value > worth or (value == worth and likely > chance)) then
				best, chance, worth = each, likely, value
			end
		end
		if not best then break end
		for _, need in ipairs(best.needs) do left[need[1]] = left[need[1]] - need[2] end
		local leg = legs[#legs]
		if not leg or leg.recipe ~= best then
			leg = { recipe = best, count = 0, points = 0 }
			legs[#legs + 1] = leg
		end
		leg.count, leg.points = leg.count + 1, leg.points + chance
		points = points + chance
		skill = now.skill + math.floor(points + 0.001)
	end
	return legs, points
end

local function Work()
	stale, state = false, nil
	Load()
	local supplies = Supplies.Now()
	from = supplies
	if not supplies or not T.db.supplies.on or T.db.supplies.carry.heal == 0 then return end
	local skill, cap = Skill(line.aid)
	-- Learned: the skills window has it, or a trainer was seen to have taught something of it.
	state = { level = supplies.level, skill = skill, cap = cap, has = skill > 0 or cap > 0 or next(Mine().known) ~= nil,
		tailor = Skill(line.tailor) > 0, herbalist = Skill(line.herbs) > 0 }
	for _, plan in ipairs(supplies.plans) do
		if plan.key == "heal" then state.plan = plan end
	end
	-- The potion to make: the strongest known that counts at this level. And one stronger still to learn.
	for _, recipe in ipairs(recipes) do
		local item = recipe.kind == "p" and Supplies.Item(recipe.item)
		if item and item.level <= state.level and not state.potion then
			if state.has and Knows(recipe) then
				if not state.plan or Supplies.Strong(recipe.item, state.plan) then state.potion = recipe end
			elseif not state.learn then
				state.learn = recipe
			end
		end
	end
end

-- Where first aid stands: { level, skill, cap, has, tailor, herbalist, plan (the healing potions'),
-- potion (the recipe to make them by), learn (a better one not known yet) }, or nil when it is off.
function Aid.Now()
	if not ns.char then return nil end
	if stale or Supplies.Now() ~= from then Work() end
	return state
end

-- What the potion's vendor goods come to: enough for every potion short, and worth a stop once
-- the bags hold the rest of one.
function Supplies.Mats()
	local now = Aid.Now()
	local recipe, plan = now and now.potion, now and now.plan
	local short = recipe and plan and plan.carry - plan.have or 0
	local out = {}
	if short <= 0 then return out end
	local ready
	for _, need in ipairs(recipe.needs) do
		if not Sold(need[1]) then
			local fits = math.floor(C_Item.GetItemCount(need[1]) / need[2])
			ready = ready and math.min(ready, fits) or fits
		end
	end
	ready = math.min(ready or 0, short)
	for _, need in ipairs(recipe.needs) do
		if Sold(need[1]) then
			out[need[1]] = { carry = need[2] * short, urgent = ready > 0 and C_Item.GetItemCount(need[1]) < need[2] * ready }
		end
	end
	return out
end

-- The herb the potions short still take: { { id, count }, ... }.
local function Herbs(now)
	local recipe, plan, buy = now.potion, now.plan, {}
	if not recipe or not plan then return buy end
	for _, need in ipairs(recipe.needs) do
		local missing = need[2] * (plan.carry - plan.have) - C_Item.GetItemCount(need[1])
		if not Sold(need[1]) and missing > 0 then buy[#buy + 1] = { id = need[1], count = missing } end
	end
	return buy
end

-- The trainer

-- What a trainer would teach now that is worth having: { { name, cost }, ... } and the gold for it.
local function Due(now)
	local want, mine = {}, Mine()
	for _, recipe in ipairs(recipes) do
		local item = Supplies.Item(recipe.item)
		local wanted = recipe.kind == "p" and item and item.level <= now.level or recipe.kind == "b" and not now.tailor
		local name = wanted and not Knows(recipe) and C_Spell.GetSpellName(recipe.spell)
		if name then want[name] = recipe end
	end
	local own = C_TradeSkillUI.GetTradeSkillDisplayName(line.aid)
	local due, cost = {}, 0
	for key, entry in pairs(T.db.aid.list) do
		local name = key:match("^(.-)|") or key
		-- A rank is named for the skill ("Journeyman First Aid"); the next one is taught just under the cap.
		local rank = own ~= nil and (name == own or name:sub(-#own - 1) == " " .. own) and now.cap > 0 and entry[1] >= now.cap - NEXT_RANK
		if not mine.known[key] and entry[1] <= now.skill and entry[2] <= now.level and (want[name] or rank) then
			due[#due + 1] = { name = name, cost = entry[3], recipe = want[name] or nil, rank = rank == true }
			cost = cost + entry[3]
		end
	end
	table.sort(due, function(a, b) return a.name < b.name end)
	return due, cost
end

-- What to do with the cloth, worked out once for each look at the bags: { legs, points } as Cloth
-- gives them, and `waits` when what a trainer would teach now makes the cloth worth that many
-- points instead. Then the cloth is kept for it, but for what would be made first either way.
-- The plan let go, to be worked out again: the gold crossed what a trainer asks.
function Aid.Recount()
	stale = true
	Supplies.Stale()
end

local function Plans(now)
	local plan = now.cloth
	if plan then return plan end
	plan = { legs = {}, points = 0 }
	now.cloth = plan
	if now.tailor or not now.has then return plan end
	plan.legs, plan.points = Cloth(now)
	local due, cost = Due(now)
	-- (Gold that crosses what the trainer asks changes the plan: it is worked out again then.)
	local weighs = ns.Weighed("aid", Aid.Recount)
	if #due > 0 and cost > 0 then weighs[1] = cost end
	if #due == 0 or cost > Shy.Money() or (Mine().skip or 0) >= now.level then return plan end
	local more, cap = {}, now.cap
	for _, each in ipairs(due) do
		if each.recipe then more[each.recipe] = true end
		if each.rank then cap = now.cap + RANK end
	end
	local legs, points = Cloth(now, more, cap)
	if points - plan.points < WORTH then return plan end
	local was, lead = plan.legs[1], legs[1]
	plan.waits, plan.legs, plan.points = points, {}, 0
	if was and lead and was.recipe == lead.recipe then
		local less = lead.count <= was.count and lead or was
		plan.legs[1], plan.points = less, less.points
	end
	return plan
end

local function Nearest(ids)
	local best
	for id in pairs(ids) do
		local npc = D.Npc(id)
		if npc and L.Friendly(npc) then
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			if map and yards and not dungeon and (not best or yards < best.yards) then
				best = { npc = npc, map = map, x = x, y = y, yards = yards }
			end
		end
	end
	return best
end

local function Trainer()
	local ids = {}
	for _, title in ipairs(TITLES) do
		for _, id in ipairs(D.Town(nil, title)) do ids[id] = true end
	end
	for id in pairs(T.db.aid.trainers) do ids[id] = true end
	return Nearest(ids)
end

local function Busy()
	return InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

local function Points(points)
	local whole = math.max(1, math.floor(points + 0.5))
	return whole == 1 and "1 point" or whole .. " points"
end

local function Quit(root)
	root:CreateButton("Stop asking about healing potions", function()
		T.db.supplies.carry.heal = 0
		ns.Apply()
	end):SetSub("Turn it back on under Errands")
end

-- The trainer as a route errand (R.AddErrand), or nil.
local function Train(lead)
	local weighs = ns.Weighed("aidtrain")
	local now = Aid.Now()
	if not now or (Mine().skip or 0) >= now.level then return nil end
	local title, why, due, cost
	if not now.has then
		if now.level < LEARN then return nil end
		title, why = "Learn First Aid", "You'll make your own healing potions"
	else
		due, cost = Due(now)
		if #due > 0 then
			if cost > 0 then weighs[1] = cost end
			if cost > Shy.Money() then return nil end
			title = #due == 1 and ("Train: " .. due[1].name) or ("Train: %d First Aid recipes"):format(#due)
			why = cost > 0 and ("Costs " .. Coins(cost)) or nil
		elseif next(T.db.aid.list) == nil and not now.potion then
			-- No trainer's list was read yet: what there is to learn shows there.
			title, why = "First Aid: see the trainer", "For a potion recipe"
		else
			return nil
		end
	end
	local at = Trainer()
	if not at then return nil end
	-- Cloth kept for what there is to learn: the trainer has a row however far off.
	local waits = due and Plans(now).waits
	local passing = not Busy() and R.Passing("aid", at.map, at.x, at.y, lead, nil, TRAINER_WORTH)
	if not passing and at.yards > LISTED and not waits then return nil end
	if waits then why = ("After this, your cloth gives about %s"):format(Points(waits)) end
	return {
		title = title,
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name, why },
		caption = now.has and ("FIRST AID %d  \194\183  YOUR TRAINER"):format(now.skill) or "FIRST AID  \194\183  YOUR POTIONS",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "aid",
		first = passing or nil,
		hover = function()
			local rows = {}
			for i, each in ipairs(due or {}) do
				rows[i] = { glyph = "book", text = each.name, right = each.cost > 0 and Coins(each.cost) or nil }
			end
			if #rows == 0 or waits then rows[#rows + 1] = { glyph = "note", quiet = true, text = why } end
			return { { title = "To learn", rows = rows } }
		end,
		tip = function(tip)
			for _, each in ipairs(due or {}) do tip:AddLine(each.name, 1, 1, 1) end
		end,
		menu = function(root)
			root:CreateButton("Ask me next level", function()
				Mine().skip = now.level
				ns.Refresh()
			end)
			Quit(root)
		end,
	}
end

-- Making

-- What to make from the bags now: the potions short, else the bandages the cloth is best made
-- into (Plans). Returns the recipe, how many, and for the skill the points they should bring.
local function Makes(now)
	local plan, recipe = now.plan, now.potion
	if recipe and plan and plan.have < plan.carry then
		local count = math.min(Can(recipe), plan.carry - plan.have)
		if count > 0 then return recipe, count, nil end
	end
	local cloth = Plans(now)
	local leg = cloth.legs[1]
	if leg and cloth.points >= WORTH then return leg.recipe, leg.count, leg.points end
end

-- The row to make them, as a route errand with nowhere to go (R.AddErrand), or nil.
local function Make()
	local now = Aid.Now()
	if not now or not now.has then return nil end
	local recipe, count, forSkill = Makes(now)
	if not recipe then return nil end
	local key = recipe.spell .. ":" .. count
	if put == key then return nil end
	local plan, name = now.plan, Name(recipe.item)
	return {
		title = ("Make %d %s"):format(count * recipe.count, name),
		lines = { forSkill and ("First Aid %d of %d: worth about %s"):format(now.skill, now.cap, Points(forSkill))
			or "You have what you need in your bags" },
		caption = forSkill and "FIRST AID  \194\183  USE YOUR CLOTH"
			or ("%s HEALING POTIONS  \194\183  MAKE THEM"):format(plan.have == 0 and "OUT OF" or "LOW ON"),
		mark = forSkill and "aid" or "potion",
		first = (not forSkill and not Busy() and plan.have <= plan.low) or nil,
		click = function()
			if not InCombatLockdown() then C_TradeSkillUI.OpenRecipe(recipe.spell) end
		end,
		hover = function()
			local used = {}
			for i, need in ipairs(recipe.needs) do
				used[i] = { icon = C_Item.GetItemIconByID(need[1]), glyph = "bag", text = Name(need[1]),
					right = ("%d of %d"):format(need[2] * count, C_Item.GetItemCount(need[1])), rightColor = UI.colors.dim }
			end
			return { { title = "To make", rows = { { icon = C_Item.GetItemIconByID(recipe.item), glyph = "book",
				text = ("%d %s"):format(count * recipe.count, name) } } }, { title = "From your bags", rows = used } }
		end,
		tip = function(tip)
			tip:AddLine("Click to open the recipe in First Aid.", 0.6, 0.6, 0.6, true)
		end,
		menu = function(root)
			root:CreateButton("Not now", function()
				put = key
				ns.Refresh()
			end)
			if not forSkill then Quit(root) end
		end,
	}
end

-- The herb

-- An auctioneer near by as a route errand (R.AddErrand) while the potions' herb is short, or nil.
local function Herb(lead)
	local now = Aid.Now()
	local plan = now and now.plan
	-- (Asked for, it need not wait until the potions run low.)
	if not plan or now.herbalist or (plan.have > plan.low and not R.Asked("aidherb")) then return nil end
	local buy = Herbs(now)
	if #buy == 0 then return nil end
	local ids = {}
	for _, id in ipairs(D.Town("auction")) do ids[id] = true end
	local at = Nearest(ids)
	if not at then return nil end
	local passing = not Busy() and R.Passing("aidherb", at.map, at.x, at.y, lead)
	if not passing and at.yards > LISTED then return nil end
	local potion = Name(now.potion.item)
	return {
		title = ("Auction house: %d %s"):format(buy[1].count, Name(buy[1].id)),
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name,
			("For %d %s"):format(plan.carry - plan.have, potion) },
		caption = ("%s HEALING POTIONS  \194\183  BUY THE HERB"):format(plan.have == 0 and "OUT OF" or "LOW ON"),
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "herb",
		first = passing or nil,
		hover = function()
			local rows = {}
			for i, each in ipairs(buy) do
				rows[i] = { icon = C_Item.GetItemIconByID(each.id), glyph = "coin", text = ("%d %s"):format(each.count, Name(each.id)) }
			end
			return { { title = "To buy", rows = rows }, { title = "It makes", rows = { { icon = C_Item.GetItemIconByID(now.potion.item),
				glyph = "book", text = ("%d %s"):format(plan.carry - plan.have, potion) } } } }
		end,
		tip = function(tip)
			for _, each in ipairs(buy) do tip:AddLine(("%d %s"):format(each.count, Name(each.id)), 1, 1, 1) end
		end,
		menu = Quit,
	}
end

-- What the game shows

-- A first aid trainer's window: what each thing on its list asks, and what this character has of it.
local function Read()
	if not IsTradeskillTrainer() then return end
	Load()
	local own = C_TradeSkillUI.GetTradeSkillDisplayName(line.aid)
	local mine, list, ours, shown = Mine(), T.db.aid.list, false, {}
	for index = 1, GetNumTrainerServices() do
		local name, kind, _, level, rank = GetTrainerServiceInfo(index)
		local skill, points = GetTrainerServiceSkillReq(index)
		if name and (kind == "available" or kind == "unavailable" or kind == "used")
			and (skill == own or GetTrainerServiceSkillLine(index) == own) then
			local key = (rank and rank ~= "") and (name .. "|" .. rank) or name
			-- Something learned may report no price: keep the saved one.
			if kind ~= "used" or not list[key] then list[key] = { points or 0, level or 0, GetTrainerServiceCost(index) or 0 } end
			mine.known[key] = kind == "used" or nil
			ours, shown[key] = true, true
		end
	end
	-- What a first aid trainer listed before and lists no more was learned: a rank goes off the list,
	-- and so does a recipe while the window hides what is known.
	if ours and GetTrainerServiceTypeFilter("available") and GetTrainerServiceTypeFilter("unavailable") then
		for key in pairs(list) do
			if not shown[key] then mine.known[key] = true end
		end
	end
	local guid = ours and UnitGUID("npc")
	local kind, id = nil, nil
	if guid and not issecretvalue(guid) then kind, id = guid:match("^(%a+)%-.-%-.-%-.-%-.-%-(%d+)") end
	if kind == "Creature" then T.db.aid.trainers[tonumber(id)] = true end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "NEW_RECIPE_LEARNED", "TRAINER_SHOW", "TRAINER_UPDATE", "AUCTION_HOUSE_SHOW" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, id)
	if not ns.char then return end
	if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
		Read()
	elseif event == "NEW_RECIPE_LEARNED" then
		Load()
		for _, recipe in ipairs(recipes) do
			local name = recipe.spell == id and C_Spell.GetSpellName(id)
			if name then Mine().known[name] = true end
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		-- At the auction house: what the potions still take, said once in chat.
		local now = Aid.Now()
		if now and not now.herbalist then
			for _, each in ipairs(Herbs(now)) do
				T:Print(("buy |cffffffff%d %s|r for your healing potions."):format(each.count, Name(each.id)))
			end
		end
		return
	end
	stale = true
	Supplies.Stale()
	-- (A change in the bags builds the route again already, ShyQuest.lua: the guide is asked only when it reads them.)
	if event == "BAG_UPDATE_DELAYED" then return end
	-- (Gold, a trainer's list, a recipe: the first-aid errand's alone. The errands are fitted again, not the route.)
	ns.RefreshErrands()
end)
-- The spellbook, told by ShyCore when it changes: the same. (Gold: ns.Weighed above.)
Shy:On("SHY_SPELLS", function()
	if not ns.char then return end
	stale = true
	Supplies.Stale()
	ns.RefreshErrands()
end)

ns.OnApply(function()
	stale = true
end)

R.AddErrand("aid", Train, "First Aid trainer")
R.AddErrand("aidmake", Make, "Making First Aid")
R.AddErrand("aidherb", Herb, "Herbs for First Aid")
-- To ask for: its trainer, while there is something to learn there.
R.AddOffer("aid", function()
	local now = Aid.Now()
	if not now then return {} end
	if not now.has then return now.level >= LEARN and { { text = "First Aid trainer: learn the skill" } } or {} end
	return #Due(now) > 0 and { { text = "First Aid trainer: new recipes" } } or {}
end)
-- ... and an auctioneer, while the potions' herb is short.
R.AddOffer("aidherb", function()
	local now = Aid.Now()
	local buy = now and not now.herbalist and Herbs(now) or {}
	return buy[1] and { { text = ("Auction house: %d %s"):format(buy[1].count, Name(buy[1].id)) } } or {}
end)
