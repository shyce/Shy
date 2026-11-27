-- Restocking as a route errand: food, water, potions and spell reagents.
--   Carry: how many of each to keep, and a quarter of that as the point to refill. Automatic goes
--     by level, class and talents (Auto); the options set an amount per kind, 0 for off.
--   Food and water, automatic: what one fight costs this character (taken from the bags, out of
--     combat and with no vendor, bank, mail, trade or craft open, over the fights fought while
--     carrying some; a guess by class and talents until enough are seen), times the fights before
--     the next vendor on the way (the guide's places, else the log's quests). Short of what those
--     fights take is running low. It comes in whole stacks, one at least: a part stack takes a slot all the same.
--   Topping up: not low, but short of TOP_UP of the carry, in a town with a seller: a row to top up there.
--   Counted: food, drink and potions the character can use that restore at least GOOD of a full
--     bar, or of the best sold for the level when that is less; a weaker one for its share of that.
--     A reagent counts while one of its spells is known and no later rank has replaced it.
--   Bought: the cheapest a vendor sells that fills the bar at once, else the strongest, within
--     SHARE of the gold left after training.
--   Sellers: Data/Supplies.lua, replaced per vendor by what their window showed (T.db.stock).
--   Potions: a vendor keeps a few and runs out, so one who sells them is a stop of its own that
--     never leads, and stays a seller whatever their window showed; a window without any, or a
--     word from the stop's menu, puts them aside for OUT_FOR (T.db.soldOut).
--   Makings: what something made by hand is short of that vendors sell (Supplies.Mats, set by
--     whoever makes it) is bought like a reagent.
-- T:Supplies(ids) tells a vendor window what to offer from its goods. Nothing is bought for you unless
-- "Buy what you need" is on (off by default): then a vendor's window buys what a quest in the log still
-- needs and what restocking asks for within its gold, never anything the game would ask about first
-- (another currency, a high price, no refund). Holding Shift as it opens leaves it to the player.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, G = ns.Data, ns.World, ns.Log, ns.Route, ns.Guide
local UI = Shy.UI

local Supplies = {}
ns.Supplies = Supplies

T.defaults.supplies = {
	on = true,               -- a vendor as a stop on the card when running low
	auto = false,            -- buy what quests and restocking need on opening a vendor's window
	carry = {},              -- amounts set by hand, by kind: water, food, heal, mana, reagents (unset: automatic)
}
T.defaults.stock = {}        -- what a vendor's list showed of these goods, by NPC: "159,1179"
T.keep.stock = true          -- read from the game: per account, not per profile
T.defaults.soldOut = {}      -- when a vendor was last out of potions, by NPC: time()
T.keep.soldOut = true

-- Kinds measured by what they restore: the item's field, the bar it fills, and its names.
-- limited: vendors keep a few of it and run out.
local SIZED = {
	water = { field = "water", share = "waterShare", bar = "mana", label = "Water", word = "water" },
	food = { field = "food", share = "foodShare", bar = "health", label = "Food", word = "food" },
	heal = { field = "heal", bar = "health", label = "Healing potions", word = "healing potions", limited = true },
	mana = { field = "mana", bar = "mana", label = "Mana potions", word = "mana potions", limited = true },
}
local ORDER = { "water", "food", "heal", "mana" }
-- How much a class leans on mana; a table is by talent tab, in the talent window's order, and
-- `early` before the first talent (a druid casts Wrath until it has forms). A judgement no game
-- table holds. A class not listed goes by whether it has mana.
local ROLE = {
	WARRIOR = "melee", ROGUE = "melee", MAGE = "caster", PRIEST = "caster", WARLOCK = "drain", HUNTER = "pet",
	DRUID = { "caster", "hybrid", "caster", early = "caster" },
	PALADIN = { "caster", "hybrid", "hybrid" },
	SHAMAN = { "caster", "hybrid", "caster" },
}
-- Food and drink a fight costs, by role, until the character's own is known.
-- drain: health made into mana (Life Tap); pet: the pet takes the hits.
local GUESS = {
	caster = { water = 0.6, food = 0.15 }, hybrid = { water = 0.3, food = 0.3 }, melee = { water = 0, food = 0.45 },
	drain = { water = 0.35, food = 0.35 }, pet = { water = 0.25, food = 0.25 },
}
local LEARNED = { "water", "food" }
local PRIOR = 15             -- fights the guess weighs as
local KEEP = 150             -- fights remembered: older ones fade
local MARGIN = 1.25          -- carried over what the fights ahead take
local LEAST_FIGHTS = 20      -- enough for this many whatever lies ahead
local MOST_FIGHTS = 150      -- fights ahead reckoned with, at most
local LOG_FIGHTS = 60        -- ... with no guide: about an hour's
local MOST_CARRY = 80
local TOP_UP = 0.5           -- in a town with a seller, short of this share of the carry: a row to top up
local TOWN = 300             -- yards: a place this near a seller is a stop to restock at
local AHEAD = 40             -- guide places looked at for the fights ahead
local AGAIN = 30             -- seconds the fights ahead are kept while the guide's place stays
local BACKPACK, LAST_BAG = 0, 4    -- Enum.BagIndex.Backpack to Bag_4
local GOOD = 0.5             -- restores at least this share of the bar, or of the best sold, to count
local COMMON = 5             -- sellers an item needs to set what "the best sold" is
local SHARE = 1 / 3          -- of the gold left after training, this much at most goes to supplies
local REAGENT_MOST = 20      -- automatic: one stack of a reagent, up to this many
local LISTED = 800           -- yards: running low, a seller this near gets a row on the card
local LISTED_OUT = 2000      -- the same with no food or water left
local OUT_REACH = 300        -- yards: with none left, a seller this near counts as on the way
local FAR = 300              -- yards a seller is set back by for each kind they don't sell
local OUT_FOR = 15 * 60      -- seconds a vendor out of potions is left alone

local items                  -- food, drink, potions, reagents and makings, by item
local sellers                -- NPC -> { [item] = true }
local potions                -- NPC -> { [item] = true }: the potions the data has them sell
local stockAt = 0            -- bumps when a vendor's list is noted
local stale = true
local state                  -- last result of Work
local put = false            -- "Not now": no stop until stocked up again
local bars = { health = 0, mana = 0 }
local tab, tabStale = nil, true
local best = {}              -- kind -> { level, amount }
local counted = {}           -- kind -> food or drink of it in the bags, as last counted
local open = {}              -- windows open that take or give things: vendor, bank, mail, trade, crafting
local closed = 0             -- GetTime() one of those last closed
local ahead = {}             -- the fights before the next vendor, by kind: { key, at, fights }
local Spots

local function Fields(text)
	local out = {}
	for field in (text .. "^"):gmatch("(.-)%^") do out[#out + 1] = field end
	return out
end

local function Load()
	if items then return end
	items = {}
	for id, text in pairs(ns.data.supplies or {}) do
		local f = Fields(text)
		local health, mana = tonumber(f[3]) or 0, tonumber(f[4]) or 0
		local foodShare, waterShare = (f[8] or ""):match("^(%d+)/(%d+)$")
		local potion = f[1] == "p"
		local sold = f[9] or ""
		local _, commas = sold:gsub(",", ",")
		items[id] = {
			id = id, level = tonumber(f[2]) or 0,
			food = potion and 0 or health, water = potion and 0 or mana,
			heal = potion and health or 0, mana = potion and mana or 0,
			foodShare = tonumber(foodShare) or 0, waterShare = tonumber(waterShare) or 0,
			price = tonumber(f[5]) or 0, lot = math.max(1, tonumber(f[6]) or 1),
			sold = sold, common = sold ~= "" and commas + 1 >= COMMON, potion = potion, stack = math.max(1, tonumber(f[10]) or 1),
		}
	end
	for id, text in pairs(ns.data.mats or {}) do
		local f = Fields(text)
		items[id] = { id = id, reagent = true, mat = true, level = 0, stack = math.max(1, tonumber(f[1]) or 1),
			price = tonumber(f[2]) or 0, lot = math.max(1, tonumber(f[3]) or 1), spells = {}, sold = f[4] or "" }
	end
	for id, text in pairs(ns.data.reagents or {}) do
		local f = Fields(text)
		local spells = {}
		for spell, later in (f[4] or ""):gmatch("(%d+)>?(%d*)") do
			spells[#spells + 1] = { tonumber(spell), tonumber(later) }
		end
		items[id] = { id = id, reagent = true, level = 0, stack = math.max(1, tonumber(f[1]) or 1),
			price = tonumber(f[2]) or 0, lot = math.max(1, tonumber(f[3]) or 1), spells = spells, sold = f[5] or "" }
	end
end

-- Who sells what: the data's lists, or for a vendor whose window was seen, that list, and with
-- it the potions the data has them sell (a window read while they were out says nothing).
local function Sellers()
	if sellers then return sellers end
	Load()
	sellers, potions = {}, {}
	local seen = T.db.stock
	for id, item in pairs(items) do
		for digits in item.sold:gmatch("%d+") do
			local npc = tonumber(digits)
			if seen[npc] == nil then
				sellers[npc] = sellers[npc] or {}
				sellers[npc][id] = true
			end
			if item.potion then
				potions[npc] = potions[npc] or {}
				potions[npc][id] = true
			end
		end
	end
	for npc, text in pairs(seen) do
		local shop
		for digits in text:gmatch("%d+") do
			local id = tonumber(digits)
			if items[id] then
				shop = shop or {}
				shop[id] = true
			end
		end
		for id in pairs(potions[npc] or {}) do
			shop = shop or {}
			shop[id] = true
		end
		sellers[npc] = shop
	end
	return sellers
end

-- Whether a vendor was out of potions a moment ago.
local function Out(npc)
	local at = T.db.soldOut[npc]
	return at ~= nil and time() - at < OUT_FOR
end

local function Name(id)
	return C_Item.GetItemNameByID(id) or D.Name("items", id) or "supplies"
end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- This character's choices and what they use: { off = { [reagent] = true }, use = { [kind] =
-- { taken, fights } } }.
local function Mine()
	local mine = ns.char.supplies
	if not mine then
		mine = { off = {} }
		ns.char.supplies = mine
	end
	if not mine.use then
		mine.use = {}
		for _, kind in ipairs(LEARNED) do mine.use[kind] = { taken = 0, fights = 0 } end
	end
	return mine
end

-- The character

local function ReadBars()
	local health, mana = UnitHealthMax("player"), UnitPowerMax("player", Enum.PowerType.Mana)
	if health and not issecretvalue(health) then bars.health = health end
	if mana and not issecretvalue(mana) then bars.mana = mana end
end

-- The talent tab with the most points, or nil before the first.
local function Tab(spec)
	if not tabStale then return tab end
	tabStale, tab = false, nil
	local config = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	if not config then return nil end
	local most = 0
	for _, group in ipairs(C_Traits.GetGroupCurrencyInfo(config, spec.tabs)) do
		local purse = group.currencyInfos[1]
		local spent = purse and purse.spent
		if spent and not issecretvalue(spent) and spent > most then
			for index, id in ipairs(spec.tabs) do
				if id == group.traitNodeGroupID then tab, most = index, spent end
			end
		end
	end
	return tab
end

local function Role()
	local class = UnitClassBase("player")
	local role = class and ROLE[class]
	if type(role) == "table" then
		local spec = Shy.Build and Shy.Build.Class()
		local picked = spec and Tab(spec)
		if not picked and role.early then return role.early end
		return spec and role[picked or spec.tab] or "hybrid"
	end
	return role or (bars.mana > 0 and "hybrid" or "melee")
end

-- Whether the character can conjure this kind.
local function Makes(kind)
	local list = ns.data.conjure and ns.data.conjure[kind]
	for spell in (list or ""):gmatch("%d+") do
		if C_SpellBook.IsSpellKnown(tonumber(spell)) then return true end
	end
	return false
end

-- Whether a spell the character casts uses this reagent.
local function Used(item)
	for _, spell in ipairs(item.spells) do
		if C_SpellBook.IsSpellKnown(spell[1]) and not (spell[2] and C_SpellBook.IsSpellKnown(spell[2])) then return true end
	end
	return false
end

-- Learning what a fight costs

-- Food and drink in the bags, by kind: whatever restores any of it.
local function Count()
	local found, seen = { water = 0, food = 0 }, {}
	for bag = BACKPACK, LAST_BAG do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			local item = id and not seen[id] and items[id]
			if item and not item.reagent and not item.potion then
				seen[id] = true
				local count = C_Item.GetItemCount(id)
				for _, kind in ipairs(LEARNED) do
					local about = SIZED[kind]
					if item[about.field] > 0 or item[about.share] > 0 then found[kind] = found[kind] + count end
				end
			end
		end
	end
	return found
end

-- The bags changed: one of a kind gone, with nothing open to sell, store, send, trade or cook it,
-- out of combat and alive, was eaten or drunk. (One at a time: a stack gone at once was not.)
local function Track()
	Load()
	local now, use = Count(), Mine().use
	local quiet = next(open) ~= nil or GetTime() - closed < 2 or InCombatLockdown() or UnitIsDeadOrGhost("player")
	for _, kind in ipairs(LEARNED) do
		local was = counted[kind]
		if was and was - now[kind] == 1 and not quiet then use[kind].taken = use[kind].taken + 1 end
		counted[kind] = now[kind]
	end
end

-- A fight began: counted for each kind carried (a fight with none says nothing of what it costs).
local function Fought()
	local use = Mine().use
	for _, kind in ipairs(LEARNED) do
		if (counted[kind] or 0) > 0 then
			local mine = use[kind]
			mine.taken = mine.taken * (1 - 1 / KEEP)
			mine.fights = mine.fights * (1 - 1 / KEEP) + 1
		end
	end
end

-- What a fight costs of a kind, and whether that is the character's own (enough fights seen).
local function Rate(kind)
	local mine, guess = Mine().use[kind], GUESS[Role()] or GUESS.hybrid
	return (mine.taken + guess[kind] * PRIOR) / (mine.fights + PRIOR), mine.fights >= PRIOR
end

-- Whether a shop has any of a kind.
local function Sells(shop, kind)
	local field = SIZED[kind].field
	for id in pairs(shop) do
		local item = items[id]
		if item and not item.reagent and item[field] > 0 then return true end
	end
	return false
end

-- The fights before the next vendor of a kind: the guide's places up to the first by a seller
-- after some fighting, else everything the log's quests still ask.
local function Ahead(kind)
	local main = G.active and G.active[1]
	local key = (main and (tostring(G.current) .. ":" .. main.step.index) or "log") .. ":" .. kind
	local kept = ahead[kind]
	if kept and kept.key == key and GetTime() - kept.at <= AGAIN then return kept.fights end
	local fights = 0
	-- (The guide's places are the same for every kind: asked of the guide once for all of them.)
	local step = main and (tostring(G.current) .. ":" .. main.step.index) or "log"
	local seen = ahead.places
	if not (seen and seen.key == step and GetTime() - seen.at <= AGAIN) then
		seen = { key = step, at = GetTime(), list = G.Places and G.Places(AHEAD) or {} }
		ahead.places = seen
	end
	local places = seen.list
	if #places > 0 then
		for _, place in ipairs(places) do
			if fights > 0 and place.north then
				local near = false
				for _, at in ipairs(Spots()) do
					if at.continent == place.continent and W.Between(place.north, place.west, at.north, at.west) <= TOWN
						and Sells(at.shop, kind) then
						near = true
						break
					end
				end
				if near then break end
			end
			for _, task in ipairs(place.tasks) do
				fights = fights + (task.quest and R.Fights(task.quest, task.objective) or R.FightsOf(task.item, task.need))
			end
			if fights >= MOST_FIGHTS then break end
		end
	else
		-- (Not where the vendors are between them: the log's quests are taken as one trip, LOG_FIGHTS at most.)
		for id in pairs(L.entries or {}) do
			for index in ipairs(L.Goals(id)) do fights = fights + R.Fights(id, index) end
		end
		fights = math.min(fights, LOG_FIGHTS)
	end
	fights = math.min(MOST_FIGHTS, math.floor(fights + 0.5))
	ahead[kind] = { key = key, at = GetTime(), fights = fights }
	return fights
end

-- The most a commonly sold item of a kind restores at this level, and how many of it stack.
local function Best(kind, level)
	local known = best[kind]
	if known and known[1] == level then return known[2], known[3] end
	local most, stack, field = 0, 1, SIZED[kind].field
	for _, item in pairs(items) do
		if item.common and item.level <= level and item[field] > most then most, stack = item[field], item.stack end
	end
	best[kind] = { level, most, stack }
	return most, stack
end

-- The automatic amount for a kind, or for a reagent; for food and water also what the fights
-- before the next vendor take.
local function Auto(key, item)
	if item then return math.min(item.stack, REAGENT_MOST) end
	local level, mana = UnitLevel("player"), bars.mana > 0
	if key == "food" or key == "water" then
		if (key == "water" and not mana) or Makes(key) then return 0 end
		local rate = Rate(key)
		if rate <= 0 then return 0 end
		local fights = Ahead(key)
		-- (Whole stacks of what's sold: a part stack takes a bag slot all the same.)
		Load()
		local _, stack = Best(key, level)
		local carry = math.ceil(rate * math.max(fights, LEAST_FIGHTS) * MARGIN / stack) * stack
		return math.min(math.max(MOST_CARRY, stack), carry), math.ceil(rate * fights)
	elseif key == "heal" then
		return level >= 10 and 5 or 0
	elseif key == "mana" then
		local role = Role()
		return mana and level >= 15 and (role == "caster" or role == "drain") and 5 or 0
	end
	return 0
end
Supplies.Auto = Auto

local function Carry(key, item)
	local set = T.db.supplies.carry[item and "reagents" or key]
	if type(set) == "number" then return set end
	return Auto(key, item)
end

local function Low(carry)
	return math.min(math.max(1, math.floor(carry / 4)), carry - 1)
end

-- What an item restores of a kind, for a bar of this size.
local function Gives(item, kind, bar)
	local about = SIZED[kind]
	return item[about.field] + (about.share and item[about.share] * bar / 100 or 0)
end

-- The gold for supplies, and what is kept back for the trainer. What the trainer asks is a price weighed.
local function Budget(weighs)
	local money = Shy.Money()
	local due = ns.Train and ns.Train.Waiting()
	local cost = due and due.cost
	if cost and cost > 0 then weighs[#weighs + 1] = cost end
	local kept = cost and cost <= money and cost or 0
	return math.floor((money - kept) * SHARE), kept
end

-- A budget compared with `spent + need`: the gold at which that turns, a price the rows hang on (ns.Weighed).
local function Weigh(spent, need)
	local weighs = state and state.weighs
	if weighs then weighs[#weighs + 1] = state.kept + math.ceil((spent + need) / SHARE) end
end

-- Counts the bags and works out what is short.
local function Work()
	stale = false
	Load()
	ReadBars()
	local level = UnitLevel("player")
	-- (Gold that crosses a price weighed here lets this go: worked out again at the next fitting.)
	local weighs = ns.Weighed("supplies", Supplies.Stale)
	local budget, kept = Budget(weighs)
	state = { level = level, budget = budget, kept = kept, weighs = weighs, plans = {}, wants = {}, checks = {}, tops = {}, picked = {},
		checked = {}, topped = {} }

	local held = {}
	for bag = BACKPACK, LAST_BAG do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and items[id] and held[id] == nil then held[id] = C_Item.GetItemCount(id) end
		end
	end

	local plans = state.plans
	for _, key in ipairs(ORDER) do
		local carry, need = Carry(key)
		local about = SIZED[key]
		local bar, sold = bars[about.bar], Best(key, level)
		local ref = (bar > 0 and sold > 0) and math.min(bar, sold) or math.max(bar, sold)
		if carry > 0 and ref > 0 then
			-- A weaker one counts for its share of a good one.
			local have, weak, worth = 0, 0, 0
			for id, count in pairs(held) do
				local item = items[id]
				local gives = not item.reagent and item.level <= level and Gives(item, key, bar) or 0
				if gives >= ref * GOOD then
					have = have + count
				elseif gives > 0 then
					weak, worth = weak + count, worth + count * gives / (ref * GOOD)
				end
			end
			worth = math.floor(worth)
			local plan = { key = key, kind = key, label = about.label, word = about.word, carry = carry, low = Low(carry),
				have = have + worth, all = have + weak, weak = weak, worth = worth, ref = ref, limited = about.limited }
			-- Short of what the fights before the next vendor take.
			if need then
				plan.low = math.min(carry - 1, math.max(plan.low, need - 1))
				plan.fights, plan.rate, plan.own = Ahead(key), Rate(key)
			end
			plans[#plans + 1] = plan
		end
	end
	local off, reagents = Mine().off, {}
	for id, item in pairs(items) do
		if item.reagent and not off[id] and Used(item) then reagents[#reagents + 1] = item end
	end
	table.sort(reagents, function(a, b) return a.id < b.id end)
	for _, item in ipairs(reagents) do
		local carry = Carry("reagents", item)
		if carry > 0 then
			local name = Name(item.id)
			plans[#plans + 1] = { key = item.id, kind = "reagent", item = item, label = name, word = name, carry = carry,
				low = Low(carry), have = held[item.id] or 0, weak = 0 }
		end
	end
	-- Makings: bought at the next vendor's, and worth a stop once `urgent`.
	local asked, makings = Supplies.Mats and Supplies.Mats() or {}, {}
	for id in pairs(asked) do
		if items[id] and items[id].mat and not off[id] then makings[#makings + 1] = id end
	end
	table.sort(makings)
	for _, id in ipairs(makings) do
		local want, name = asked[id], Name(id)
		plans[#plans + 1] = { key = id, kind = "reagent", item = items[id], label = name, word = name, carry = want.carry,
			low = want.urgent and want.carry - 1 or -1, have = C_Item.GetItemCount(id), weak = 0 }
	end
	for _, plan in ipairs(plans) do
		if plan.have <= plan.low then
			local list = plan.limited and state.checks or state.wants
			list[#list + 1] = plan
		elseif (plan.kind == "food" or plan.kind == "water") and plan.have < plan.carry * TOP_UP then
			-- (Not low yet, but well short: worth topping up while a seller is right there.)
			state.tops[#state.tops + 1] = plan
		end
	end
end

-- What is carried and what is short: { level, budget, plans, wants, checks }, or nil before login.
-- A plan: { key, kind, label, word, carry, low, have, weak, ref, limited }; food and water also all
-- (how many, weak or not), worth (what the weak count as), and when automatic fights (before the
-- next vendor), rate (taken a fight) and own (learned, not guessed). wants: the plans running low;
-- checks: those of them that vendors only keep a few of.
function Supplies.Now()
	if not ns.char then return nil end
	if stale then Work() end
	return state
end

-- An item as the data has it ({ id, level, heal, mana, price, lot, ... }), or nil.
function Supplies.Item(id)
	Load()
	return items[id]
end

-- Whether an item is strong enough to count toward a plan of a kind measured by what it restores.
function Supplies.Strong(id, plan)
	Load()
	local item = items[id]
	if not item or item.reagent or not SIZED[plan.kind] or not state then return false end
	return item.level <= state.level and Gives(item, plan.kind, bars[SIZED[plan.kind].bar]) >= plan.ref * GOOD
end

-- Something a plan goes by has changed: counted again at the next route build.
function Supplies.Stale()
	stale = true
end

-- What to buy

-- The item to buy for a plan from a shop's goods ({ [item] = true }), or nil. With a budget,
-- only what one purchase of fits in it. spent: what the budget had paid before it (its prices are weighed).
local function Pick(plan, shop, budget, spent)
	if plan.kind == "reagent" then
		local item = plan.item
		if spent and shop[item.id] and item.price > 0 then Weigh(spent, item.price) end
		return shop[item.id] and item.price > 0 and (not budget or item.price <= budget) and item or nil
	end
	local field, level = SIZED[plan.kind].field, state.level
	local pick, covers, unit, gives
	for id in pairs(shop) do
		local item = items[id]
		local its = item and not item.reagent and item.price > 0 and item.level <= level and item[field] or 0
		if spent and its >= plan.ref * GOOD then Weigh(spent, item.price) end
		if its >= plan.ref * GOOD and (not budget or item.price <= budget) then
			local full, each = its >= plan.ref, item.price / item.lot
			local better
			if not pick then
				better = true
			elseif full ~= covers then
				better = full
			elseif full then
				-- Both fill the bar: the cheaper, then the stronger.
				better = each < unit or (each == unit and (its > gives or (its == gives and id < pick.id)))
			else
				better = its > gives or (its == gives and (each < unit or (each == unit and id < pick.id)))
			end
			if better then pick, covers, unit, gives = item, full, each, its end
		end
	end
	return pick
end

-- How many to buy and what it costs: whole purchases up to the amount carried, within the budget.
-- spent: as Pick's. Below what these lots cost there are fewer. Short of what is carried, one more lot is more.
local function Lot(plan, item, budget, spent)
	local want, can = math.ceil((plan.carry - plan.have) / item.lot), math.floor(budget / item.price)
	local lots = math.min(want, can)
	if lots < 1 then return 0, 0 end
	if spent then
		Weigh(spent, lots * item.price)
		if can < want then Weigh(spent, (can + 1) * item.price) end
	end
	return lots * item.lot, lots * item.price
end

-- What a shop can fill of the plans given, in order, sharing one budget: { { plan, item, qty, cost }, ... }.
local function Fill(plans, shop, budget)
	local picks, start = {}, budget
	for _, plan in ipairs(plans) do
		local item = Pick(plan, shop, budget, start - budget)
		local qty, cost = 0, 0
		if item then qty, cost = Lot(plan, item, budget, start - budget) end
		if qty > 0 then
			picks[#picks + 1] = { plan = plan, item = item, qty = qty, cost = cost }
			budget = budget - cost
		end
	end
	return picks
end

-- Every friendly seller's position: { npc, shop, map, x, y, continent, north, west }.
local spots, spotsFor
Spots = function()
	local key = L.Side() .. ":" .. stockAt .. ":" .. D.shopsVersion
	if spotsFor ~= key then
		spots, spotsFor = {}, key
		for id, shop in pairs(Sellers()) do
			local npc = D.Shop(id) ~= D.NO_SHOP and D.Npc(id)
			for _, place in ipairs(npc and L.Friendly(npc) and npc.places or {}) do
				for i = 1, place.dungeon and 0 or #place.points, 2 do
					local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
					if north then
						spots[#spots + 1] = { npc = npc, shop = shop, map = place.map, x = place.points[i], y = place.points[i + 1],
							continent = continent, north = north, west = west }
					end
				end
			end
		end
	end
	return spots
end

-- The seller to go to for the plans given: the nearest, set back for each kind they lack.
--   picked: what each shop fills of them, kept between calls. stocked: not one who is out for now.
local function Nearest(now, plans, picked, stocked)
	if not W.Known() then return nil end
	local found, least, far
	for _, at in ipairs(Spots()) do
		if at.continent == W.continent and not (stocked and Out(at.npc.id)) then
			local picks = picked[at.shop]
			if picks == nil then
				picks = Fill(plans, at.shop, now.budget)
				picked[at.shop] = picks
			end
			if #picks > 0 then
				local yards = W.Between(W.north, W.west, at.north, at.west)
				local score = yards + FAR * (#plans - #picks)
				if not least or score < least then found, least, far = at, score, yards end
			end
		end
	end
	return found, far, found and picked[found.shop]
end

-- A vendor's list, as last seen or as the data has it, without some items.
local function Without(npc, picks)
	local shop, gone, left = Sellers()[npc] or {}, {}, {}
	for _, pick in ipairs(picks) do gone[pick.item.id] = true end
	for id in pairs(shop) do
		if not gone[id] then left[#left + 1] = id end
	end
	table.sort(left)
	return table.concat(left, ",")
end

local function Restock()
	stockAt = stockAt + 1
	sellers, stale = nil, true
	ns.Refresh()
end

-- The vendor as a route errand (R.AddErrand), or nil.
local function Find(lead)
	if not T.db.supplies.on then return nil end
	local now = Supplies.Now()
	if not now then return nil end
	if #now.wants == 0 and #now.tops == 0 then
		put = false
		return nil
	end
	if put then return nil end
	-- Nothing low: only topping up, and only in a town with a seller (TOWN yards). A suggestion, never a lead.
	local topping = #now.wants == 0
	local at, yards, picks = Nearest(now, topping and now.tops or now.wants, topping and now.topped or now.picked)
	if not at or (topping and yards > TOWN) then return nil end
	local out = false
	for _, pick in ipairs(picks) do
		if pick.plan.have == 0 and (pick.plan.kind == "food" or pick.plan.kind == "water") then out = true end
	end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	local passing = not busy and R.Passing("supplies", at.map, at.x, at.y, lead, out and OUT_REACH or nil)
	if not passing and yards > (out and LISTED_OUT or LISTED) then return nil end

	local first = picks[1]
	local title, caption
	if topping then
		local plan = first.plan
		title = #picks == 1 and ("Top up %s: %d of %d"):format(plan.word, plan.have, plan.carry) or ("Top up %s and %s"):format(plan.word, picks[2].plan.word)
		caption = "IN TOWN  \194\183  TOP UP HERE"
	elseif #picks == 1 then
		local plan = first.plan
		local left = (plan.all or plan.have) == 0 and "none left" or plan.have == 0 and "only weak left" or (plan.have .. " left")
		title = ("Buy %s: %s"):format(plan.word, left)
		caption = plan.kind == "reagent" and "RUNNING LOW  \194\183  BUY HERE"
			or ("%s %s  \194\183  BUY HERE"):format((plan.all or plan.have) == 0 and "OUT OF" or "LOW ON", plan.word:upper())
	elseif #picks == 2 then
		title = ("Buy %s and %s"):format(first.plan.word, picks[2].plan.word)
	else
		title = ("Buy %s, %s and %d more"):format(first.plan.word, picks[2].plan.word, #picks - 2)
	end
	local lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name,
		("%d %s  \194\183  %s"):format(first.qty, Name(first.item.id), Coins(first.cost)) }
	return {
		title = title,
		lines = lines,
		caption = caption or "RUNNING LOW  \194\183  BUY HERE",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "buy",
		-- (Topping up is worth doing here and now, among the errands; it never leads.)
		first = passing or nil,
		hover = function()
			local buy, bags, fights = {}, {}, nil
			for i, pick in ipairs(picks) do
				local plan = pick.plan
				buy[i] = { icon = C_Item.GetItemIconByID(pick.item.id), glyph = "coin",
					text = ("%d %s"):format(pick.qty, Name(pick.item.id)), right = Coins(pick.cost) }
				bags[#bags + 1] = { glyph = "bag", text = plan.label, right = ("%d of %d"):format(plan.have, plan.carry),
					rightColor = UI.colors.dim }
				if plan.weak > 0 then
					bags[#bags + 1] = { quiet = true, indent = 2, text = ("%d weaker ones count as %d"):format(plan.weak, plan.worth) }
				end
				if plan.own then
					bags[#bags + 1] = { quiet = true, indent = 2, text = ("You %s about %d every 10 fights"):format(
						plan.kind == "water" and "drink" or "eat", math.floor(plan.rate * 10 + 0.5)) }
				end
				fights = math.max(fights or 0, plan.fights or 0)
			end
			if fights and fights > 0 then
				buy[#buy + 1] = { quiet = true, text = ("About %d fights before the next vendor"):format(fights) }
			end
			return { { title = "To buy", rows = buy }, { title = "In your bags", rows = bags } }
		end,
		tip = function(tip)
			for _, pick in ipairs(picks) do
				tip:AddLine(("%d %s"):format(pick.qty, Name(pick.item.id)), 1, 1, 1)
			end
		end,
		menu = function(root)
			root:CreateButton("Ask me when I run low", function()
				put = true
				ns.Refresh()
			end)
			for _, pick in ipairs(picks) do
				local plan = pick.plan
				root:CreateButton(("Stop asking for %s"):format(plan.word), function()
					if plan.kind == "reagent" then Mine().off[plan.key] = true else T.db.supplies.carry[plan.key] = 0 end
					ns.Apply()
				end)
			end
			root:CreateButton(("%s doesn't sell this. Find another"):format(at.npc.name), function()
				T.db.stock[at.npc.id] = Without(at.npc.id, picks)
				Restock()
			end)
		end,
	}
end

-- A vendor who may have potions, as a route errand of its own: a row to follow or leave, never a
-- lead, and gone for a while once they are known to be out.
local function Check(lead)
	if not T.db.supplies.on then return nil end
	local now = Supplies.Now()
	if not now or #now.checks == 0 then return nil end
	local at, yards, picks = Nearest(now, now.checks, now.checked, true)
	if not at then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	if yards > LISTED and (busy or not R.Passing("potions", at.map, at.x, at.y, lead)) then return nil end
	local first = picks[1]
	return {
		title = #picks == 1 and ("Check for %s"):format(first.plan.word) or "Check for potions",
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name, "Sells a few at a time" },
		caption = "WORTH A LOOK  \194\183  MAY BE SOLD OUT",
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "potion",
		-- (It leads only when asked for: the card's "Take me to" menu.)
		first = (not busy and R.Asked and R.Asked("potions")) and true or nil,
		hover = function()
			local buy, bags = {}, {}
			for i, pick in ipairs(picks) do
				buy[i] = { icon = C_Item.GetItemIconByID(pick.item.id), glyph = "coin",
					text = ("%d %s"):format(pick.qty, Name(pick.item.id)), right = Coins(pick.cost) }
				bags[i] = { glyph = "bag", text = pick.plan.label, right = ("%d of %d"):format(pick.plan.have, pick.plan.carry),
					rightColor = UI.colors.dim }
			end
			buy[#buy + 1] = { quiet = true, text = "Sells a few at a time, may be sold out" }
			return { { title = "To buy, if they have it", rows = buy }, { title = "In your bags", rows = bags } }
		end,
		tip = function(tip)
			for _, pick in ipairs(picks) do
				tip:AddLine(("%d %s"):format(pick.qty, Name(pick.item.id)), 1, 1, 1)
			end
		end,
		menu = function(root)
			root:CreateButton("Out of stock or away: check again later", function()
				T.db.soldOut[at.npc.id] = time()
				Restock()
			end)
			for _, pick in ipairs(picks) do
				root:CreateButton(("Stop asking for %s"):format(pick.plan.word), function()
					T.db.supplies.carry[pick.plan.key] = 0
					ns.Apply()
				end):SetSub("Turn it back on under Errands")
			end
		end,
	}
end

-- Public, via Shy.addons.Quest: what to offer from a vendor's goods (item IDs), most urgent
-- first: { { key, id, title, missing, have, need, low, within }, ... }. `missing` is how many to buy;
-- `key` names the kind, and stays the same when a better item is picked for it. within: the gold
-- set aside for supplies covers it (else `missing` is one purchase, shown for the window to grey).
function T:Supplies(ids)
	if type(ids) ~= "table" or not T.db.supplies.on then return nil end
	local now = Supplies.Now()
	if not now then return nil end
	local shop = {}
	for _, id in ipairs(ids) do shop[id] = true end
	local orders, budget = {}, now.budget
	for pass = 1, 2 do
		for _, plan in ipairs(now.plans) do
			local low = plan.have <= plan.low
			if (pass == 1) == low and (low or plan.have <= plan.carry * TOP_UP) then
				-- Past the budget the order is still shown, one purchase of it: the window greys it when gold is short.
				local item = Pick(plan, shop, budget) or Pick(plan, shop)
				if item then
					local qty, cost = Lot(plan, item, budget)
					budget = budget - cost
					local what = plan.kind == "reagent" and "" or (" on " .. plan.word)
					orders[#orders + 1] = { key = plan.key, id = item.id, missing = qty > 0 and qty or item.lot, have = plan.have,
						need = plan.carry, low = low, within = qty > 0,
						title = (plan.all or plan.have) == 0 and plan.kind ~= "reagent" and ("Out of " .. plan.word)
							or (low and "Running low" or "Stock up") .. what }
				end
			end
		end
	end
	return orders
end

-- A vendor's window: what it lists of these goods is that vendor's stock from now on.

local function Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	local kind, id = guid:match("^(%a+)%-.-%-.-%-.-%-.-%-(%d+)")
	return kind == "Creature" and tonumber(id) or nil
end

local function Note()
	local npc, count = Talker(), GetMerchantNumItems()
	if not npc or count == 0 then return end
	Load()
	local ids = {}
	for index = 1, count do
		local id = GetMerchantItemID(index)
		if id and items[id] then ids[#ids + 1] = id end
	end
	table.sort(ids)
	local text = table.concat(ids, ",")
	-- A list with none of these is only worth noting for someone thought to sell them.
	if text == "" and T.db.stock[npc] == nil and not Sellers()[npc] then return end
	-- Their potions: there now, or out of them for a while.
	local sells, has = Sellers() and potions[npc], false
	for _, id in ipairs(ids) do
		if items[id].potion then has = true end
	end
	local was = Out(npc)
	if has then
		T.db.soldOut[npc] = nil
	elseif sells and not was then
		T.db.soldOut[npc] = time()
	end
	if T.db.stock[npc] ~= text or was ~= Out(npc) then
		T.db.stock[npc] = text
		Restock()
	end
end

-- Buying at the window (T.db.supplies.auto): what quests in the log still need, then what restocking asks
-- for within its gold. Only what the game buys without asking: no other currency, no high price, a refund.
local PURCHASES = 4          -- purchases of one item at most per visit (a purchase is one vendor stack at most)

local function Buyable(index, info)
	return info and info.isPurchasable ~= false and not info.hasExtendedCost and (info.price or 0) > 0
		and info.price < MERCHANT_HIGH_PRICE_COST and C_MerchantFrame.IsMerchantItemRefundable(index)
end

-- Buys `want` of the item at `index` in whole vendor stacks; returns how many and what they cost.
local function Purchase(index, info, want)
	local stack = math.max(1, info.stackCount or 1)
	local most = math.max(stack, math.floor((GetMerchantItemMaxStack(index) or stack) / stack) * stack)
	local left = math.ceil(want / stack) * stack
	if info.numAvailable and info.numAvailable >= 0 then left = math.min(left, info.numAvailable * stack) end
	local got, cost, money = 0, 0, GetMoney()
	for _ = 1, PURCHASES do
		local qty = math.min(left, most, math.floor(money / info.price) * stack)
		if qty <= 0 then break end
		BuyMerchantItem(index, qty)
		local paid = math.floor(info.price * qty / stack + 0.5)
		got, cost, money, left = got + qty, cost + paid, money - paid, left - qty
	end
	return got, cost
end

local function Buy()
	if not T.db.supplies.auto or IsShiftKeyDown() or InCombatLockdown() then return end
	local count = GetMerchantNumItems()
	if count == 0 then return end
	local at, ids = {}, {}
	for index = 1, count do
		local id = GetMerchantItemID(index)
		local info = id and C_MerchantFrame.GetItemInfo(index)
		if Buyable(index, info) then
			at[id] = { index = index, info = info }
			ids[#ids + 1] = id
		end
	end
	local bought, spent = {}, 0
	local function Take(id, want)
		local good = at[id]
		if not good or want <= 0 then return end
		local got, cost = Purchase(good.index, good.info, want)
		if got > 0 then
			bought[#bought + 1] = ("%dx %s"):format(got, good.info.name or Name(id))
			spent = spent + cost
		end
		at[id] = nil
	end
	for _, id in ipairs(ids) do Take(id, T:Wanted(id) or 0) end
	for _, order in ipairs(T:Supplies(ids) or {}) do
		if order.within then Take(order.id, order.missing) end
	end
	if #bought > 0 then T:Print(("bought %s for %s."):format(table.concat(bought, ", "), Coins(spent))) end
end

local TALENTS = { PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true, ACTIVE_TALENT_GROUP_CHANGED = true }

local trackSoon
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP",
	"PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
	"PLAYER_REGEN_DISABLED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
	"TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE" }) do
	events:RegisterEvent(event)
end
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
events:SetScript("OnEvent", function(_, event, kind)
	if not ns.char then return end
	-- What eating and drinking are told apart from: nothing to rebuild.
	if event == "PLAYER_REGEN_DISABLED" then
		Fought()
		return
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "TRADE_SKILL_SHOW" then
		open[kind or "craft"] = true
		return
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" or event == "TRADE_SKILL_CLOSE" then
		open[kind or "craft"], closed = nil, GetTime()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		Track()
	elseif event == "BAG_UPDATE_DELAYED" then
		-- A loot already has the bags and the log to read. Count food and drink on the next frame.
		if not trackSoon then
			trackSoon = true
			C_Timer.After(0, function()
				trackSoon = nil
				Track()
			end)
		end
	end
	stale = true
	-- (A change in the bags builds the route again already, ShyQuest.lua: the guide is asked only when it reads them.)
	if event == "BAG_UPDATE_DELAYED" then return end
	if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		Note()
		if event == "MERCHANT_SHOW" then Buy() end
		-- (Every item bought or sold fires an update: what a vendor sells is the supplies errand's alone.)
		ns.RefreshErrands()
		return
	elseif event == "UNIT_MAXHEALTH" or event == "UNIT_MAXPOWER" then
		-- Bars move with every buff: counted again at the next route build, no rebuild asked for.
		return
	end
	if TALENTS[event] then tabStale = true end
	ns.Refresh()
end)
-- The spellbook, told by ShyCore when it changes: what to buy is worked out again. The supplies are an errand,
-- so the errands are fitted again, not the route. (Gold: ns.Weighed in Work.)
Shy:On("SHY_SPELLS", function()
	stale, tabStale = true, true
	if ns.char then ns.RefreshErrands() end
end)

ns.OnApply(function()
	stale = true
end)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Restock when food, water or reagents run low", function() return T.db.supplies.on end, function()
		T.db.supplies.on = not T.db.supplies.on
		ns.Apply()
	end)
	-- What a stop's "Stop asking for" put away, each to tick back on here.
	if not T.db.supplies.on or not ns.char then return end
	local carry = T.db.supplies.carry
	for _, key in ipairs(ORDER) do
		if carry[key] == 0 then
			root:CreateCheckbox("Ask for " .. SIZED[key].word, function() return carry[key] ~= 0 end, function()
				carry[key] = carry[key] ~= 0 and 0 or nil
				ns.Apply()
			end)
		end
	end
	local off, ids = Mine().off, {}
	for id in pairs(off) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		root:CreateCheckbox("Ask for " .. Name(id), function() return not off[id] end, function()
			off[id] = not off[id] or nil
			ns.Apply()
		end)
	end
end)

-- Settings: whether vendors become stops when you run low, and how much of each thing to carry.
local AMOUNTS = { water = { 10, 20, 40, 60, 80 }, food = { 10, 20, 40, 60, 80 }, heal = { 5, 10, 20 }, mana = { 5, 10, 20 }, reagents = { 5, 10, 20 } }

local function Amount(key, label, desc)
	local choices = { { value = "auto", text = "Automatic" }, { value = 0, text = "Off" } }
	for _, count in ipairs(AMOUNTS[key]) do choices[#choices + 1] = { value = count, text = tostring(count) } end
	return { label = label, items = choices, default = "auto", sub = true, desc = desc, words = "carry stock amount",
		enabled = function() return T.db.supplies.on end,
		get = function()
			local set = T.db.supplies.carry[key]
			return type(set) == "number" and set or "auto"
		end,
		set = function(v)
			T.db.supplies.carry[key] = type(v) == "number" and v or nil
			-- Picking an amount asks about every reagent again.
			if key == "reagents" and ns.char then wipe(Mine().off) end
		end }
end

T:Settings({
	{ section = "Food, water and supplies" },
	{ key = "supplies.on", label = "Restock at vendors",
		desc = "When you run low, a vendor who sells what you need becomes a stop. You do the buying." },
	Amount("water", "Water", "How much water to carry. Automatic plans for the fights before the next vendor."),
	Amount("food", "Food", "How much food to carry. Automatic plans for the fights before the next vendor."),
	Amount("reagents", "Spell reagents", "Runes, ankhs, candles and seeds. Automatic keeps a stack of each, up to 20."),
	Amount("heal", "Healing potions", "How many to carry. Automatic is 5 from level 10."),
	Amount("mana", "Mana potions", "How many to carry. Automatic is 5 for casters from level 15."),
})

-- Guarded: the loaded Route.lua may predate R.AddErrand until the client restarts.
if R and R.AddErrand then
	R.AddErrand("supplies", Find, "Restocking supplies")
	R.AddErrand("potions", Check, "Checking for potions")
end
-- To ask for: a vendor who may have the potions that are short.
if R and R.AddOffer then
	R.AddOffer("potions", function()
		local now = T.db.supplies.on and Supplies.Now()
		local plan = now and now.checks[1]
		return plan and { { text = "Vendor that may sell " .. plan.word } } or {}
	end)
end
