-- The class's pet as route errands, as talents are (Spec.lua): one module, one sign (a paw print, fawn).
--   Hunter: the pet trainer while it has ranks for the levels gained since a visit (a trainer window at a
--     "Pet Trainer", read and kept with the character), and Beast Training while the pet can learn
--     something with its training points (the trainer window of type Pet, titled with the pet's name, read
--     per pet; a click on its row casts Beast Training through a secure key, Spec.KeyOver). Where that
--     window was seen at a pet trainer instead, the trainer is the stop for it.
--   Warlock: the demon trainer (an NPC the data titles "Demon Trainer", no trainer in the town's lists; its
--     vendor window sells grimoires) while grimoires wait there for levels gained since a visit.
--   The class's pet quests: a hunter's taming (hunter-only quests with a creature to count) and a warlock's
--     bindings (warlock-only quests up to BOUND with a creature to count: the demon bound in the circle),
--     each with the quests leading to it. The first one the character can take is a stop at whoever gives
--     it; one in the log is the route's own. A taming quest's stop says the beast is tamed, not killed.
-- Nothing is bought, taught or tamed for you.

local ADDON, ns = ...
local T = ns.T
local D, L, W, R = ns.Data, ns.Log, ns.World, ns.Route
local UI = Shy.UI
local C = UI.colors

local Pets = {}
ns.Pets = Pets

T.defaults.pets = { on = true }      -- the pet's trainers, its training and its class quests as rows on the card

local PET_TRAINER, DEMON_TRAINER = "Pet Trainer", "Demon Trainer"   -- their NPC titles in the data
local CLASSES = { HUNTER = 4, WARLOCK = 256 }                       -- the class's bit in a quest's classes
local BOUND = 30                     -- a warlock's binding quests are up to this level (later ones are no pet's)
local CHAIN = 8                      -- quests followed along a chain to find where it leads
local TRAINING = { 5149, 5300 }      -- Beast Training, as the client has it (SpellName)
local TAME = { 1515 }                -- Tame Beast (SpellName)
local LEVEL = 10                     -- a pet comes with this level
local LISTED = 1500                  -- yards: a trainer this near gets a row while never visited
local WORTH = 900                    -- yards of walk new ranks or a pet quest are worth, off the way (R.Passing)
local MOST_SHOWN = 6                 -- skills listed in a hover

local stale, state = true, nil

local function Class()
	local class = UnitClassBase("player")
	return CLASSES[class] and class or nil
end

-- What this character keeps: { trainer = { visited, spells, open }, demons = { visited, goods },
-- pets = { [pet] = { visited, skills, open, used, at, fresh } }, skip }.
local function Mine()
	if not ns.char then return nil end
	local mine = ns.char.pets or {}
	mine.pets = mine.pets or {}
	ns.char.pets = mine
	return mine
end

-- The pet out now, as it is kept: "Name:Family", or nil.
local function PetKey()
	if not UnitExists("pet") then return nil end
	local name, family = UnitName("pet"), UnitCreatureFamily("pet")
	if name == nil or issecretvalue(name) or issecretvalue(family) then return nil end
	return name .. ":" .. (family or "")
end

local function Key(name, rank)
	return (name or "") .. "|" .. (rank or "")
end

local function Named(key)
	local name, rank = key:match("^(.-)|(.*)$")
	return (rank and rank ~= "") and ("%s (%s)"):format(name, rank) or name
end

local function Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind == "Creature" and tonumber(id) or nil
end

-- Beast Training's spell, where the character has it.
local function Training()
	for _, spell in ipairs(TRAINING) do
		if C_SpellBook.IsSpellKnown(spell) then return spell end
	end
end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- The demon trainers in the data, by NPC.
local demons
local function DemonTrainers()
	if demons then return demons end
	demons = {}
	for id, text in pairs(ns.data.npcs or {}) do
		if text:find(DEMON_TRAINER, 1, true) then
			local npc = D.Npc(id)
			if npc and npc.title == DEMON_TRAINER then demons[#demons + 1] = id end
		end
	end
	table.sort(demons)
	return demons
end

-- Reading the windows

local function ReadTrainer(mine)
	local rec = { visited = UnitLevel("player"), spells = {}, open = {} }
	for index = 1, GetNumTrainerServices() do
		local name, kind, icon, needs, rank = GetTrainerServiceInfo(index)
		if name and (kind == "available" or kind == "unavailable" or kind == "used") then
			local key = Key(name, rank)
			rec.spells[key] = { needs or 0, GetTrainerServiceCost(index) or 0, icon }
			if kind == "available" then rec.open[key] = true end
		end
	end
	-- Ranks bought since the last reading are new skills for every pet to learn.
	local before = mine.trainer
	for key in pairs(before and before.open or {}) do
		if not rec.open[key] and rec.spells[key] then
			for _, kept in pairs(mine.pets) do kept.fresh = true end
			break
		end
	end
	mine.trainer = rec
end

local function ReadPet(mine, npc)
	local key = PetKey()
	if not key then return end
	local rec = { visited = UnitLevel("pet"), skills = {}, open = {}, used = {}, at = npc }
	for index = 1, GetNumTrainerServices() do
		local name, kind, icon, needs, rank = GetTrainerServiceInfo(index)
		if name then
			local skill = Key(name, rank)
			rec.skills[skill] = { needs or 0, GetTrainerServiceCost(index) or 0, icon }
			if kind == "available" then rec.open[skill] = true elseif kind == "used" then rec.used[skill] = true end
		end
	end
	mine.pets[key] = rec
end

local function ReadTrainers()
	local mine = Mine()
	if not mine or Class() ~= "HUNTER" then return end
	local npc = Talker()
	if C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then
		ReadPet(mine, npc)
	elseif C_Trainer.GetTrainerType() == Enum.TrainerType.General and not IsTradeskillTrainer() then
		local who = npc and D.Npc(npc)
		if who and who.title == PET_TRAINER then ReadTrainer(mine) end
	end
end

-- A demon trainer's goods: each item with the level it asks for and its price.
local function ReadDemons()
	local mine, npc = Mine(), Talker()
	local who = npc and D.Npc(npc)
	if not mine or Class() ~= "WARLOCK" or not (who and who.title == DEMON_TRAINER) then return end
	local rec = { visited = UnitLevel("player"), goods = {} }
	for index = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID(index)
		local info = id and C_MerchantFrame.GetItemInfo(index)
		if info then rec.goods[id] = { select(5, C_Item.GetItemInfo(id)) or 0, info.price or 0 } end
	end
	mine.demons = rec
end

-- What waits

-- New ranks or grimoires at a trainer: { list = { { key, cost, icon, id } }, cost, least }, or nil.
local function AtTrainer(mine)
	local level, list, cost, least = UnitLevel("player"), {}, 0, nil
	local function Add(entry)
		list[#list + 1] = entry
		cost = cost + entry.cost
		if not least or entry.cost < least then least = entry.cost end
	end
	local rec = mine.trainer
	for key, entry in pairs(rec and rec.spells or {}) do
		if rec.open[key] or (entry[1] > rec.visited and entry[1] <= level) then Add({ key = key, cost = entry[2], icon = entry[3] }) end
	end
	local goods = mine.demons
	for id, entry in pairs(goods and goods.goods or {}) do
		if entry[1] > goods.visited and entry[1] <= level then
			Add({ key = (C_Item.GetItemNameByID(id) or ("Item " .. id)) .. "|", cost = entry[2], icon = C_Item.GetItemIconByID(id), id = id })
		end
	end
	if #list == 0 then return nil end
	table.sort(list, function(a, b) return a.key < b.key end)
	return { list = list, cost = cost, least = least }
end

-- Skills the pet out can learn now: { list, free, fresh, at }, or nil.
local function ForPet(mine)
	local key = PetKey()
	local rec = key and mine.pets[key]
	if not rec or not rec.visited then return nil end
	local total, used = C_PetInfo.GetPetTrainingPoints()
	local free = math.max(0, (total or 0) - (used or 0))
	local level, list = UnitLevel("pet"), {}
	for skill, entry in pairs(rec.skills) do
		local open = rec.open[skill] or (not rec.used[skill] and entry[1] > rec.visited)
		if open and not rec.used[skill] and entry[1] <= level and entry[2] <= free then
			list[#list + 1] = { key = skill, cost = entry[2], icon = entry[3] }
		end
	end
	if #list == 0 and not (rec.fresh and free > 0) then return nil end
	table.sort(list, function(a, b) return a.key < b.key end)
	return { list = list, free = free, fresh = rec.fresh and #list == 0, at = rec.at }
end

local function Work()
	stale, state = false, nil
	local mine, class = Mine(), Class()
	if not mine or not class or UnitLevel("player") < LEVEL then return end
	state = { class = class, trainer = AtTrainer(mine), pet = class == "HUNTER" and ForPet(mine) or nil,
		visited = (class == "HUNTER" and mine.trainer or mine.demons) ~= nil }
end

function Pets.Now()
	if stale then Work() end
	return state
end

local function Busy()
	return InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
end

local function Rows(list, right)
	local rows = {}
	for i = 1, math.min(MOST_SHOWN, #list) do
		local skill = list[i]
		rows[i] = { icon = skill.icon, glyph = "book", text = Named(skill.key), right = right(skill), rightColor = C.dim }
	end
	if #list > MOST_SHOWN then rows[#rows + 1] = { glyph = "note", quiet = true, text = ("and %d more"):format(#list - MOST_SHOWN) } end
	return rows
end

local function Skipped()
	local mine = Mine()
	return mine ~= nil and (mine.skip or 0) >= UnitLevel("player")
end

local function Skip(root)
	root:CreateButton("Not now: ask again next level", function()
		Mine().skip = UnitLevel("player")
		stale = true
		ns.Refresh()
	end)
end

-- The pet's trainer as a route errand (R.AddErrand), or nil: the pet trainer, or the demon trainer.
local function Trainer(lead)
	if not T.db.pets.on or Skipped() then return nil end
	local now = Pets.Now()
	if not now then return nil end
	local hunter = now.class == "HUNTER"
	if hunter and not UnitExists("pet") then return nil end
	local due, pet = now.trainer, now.pet
	-- Beast Training's window seen at the trainer: the pet's skills are learned there too.
	local there = pet and pet.at and not Training()
	if due and GetMoney() < due.least then due = nil end
	if not due and not there and now.visited then return nil end
	local at = ns.Train and ns.Train.Nearest and ns.Train.Nearest(PET_TRAINER, not hunter and DemonTrainers() or nil)
	if not at then return nil end
	local passing = not Busy() and R.Passing("pettrainer", at.map, at.x, at.y, lead, nil, (due or there) and WORTH or nil)
	if not passing and at.yards > LISTED then return nil end
	local count = (due and #due.list or 0) + (there and #pet.list or 0)
	local word = hunter and "skill" or "grimoire"
	local lines = { at.npc.name }
	if due and due.cost > 0 then lines[2] = ("%s of your %s"):format(Coins(due.cost), Coins(GetMoney())) end
	return {
		title = count > 0 and ("%s: %d new %s%s"):format(hunter and "Pet trainer" or "Demon trainer", count, word, count == 1 and "" or "s")
			or (hunter and "Pet trainer" or "Demon trainer"),
		lines = lines,
		caption = ("LEVEL %d  \194\183  YOUR PET"):format(UnitLevel("player")),
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "pet",
		first = (due or there) and passing or nil,
		hover = function()
			local sections = {}
			if due then
				sections[#sections + 1] = { title = hunter and "To learn" or "To buy", rows = Rows(due.list, function(skill)
					return skill.cost > 0 and Coins(skill.cost) or nil
				end) }
			end
			if there then
				sections[#sections + 1] = { title = "For your pet", rows = Rows(pet.list, function(skill)
					return ("%d TP"):format(skill.cost)
				end) }
			end
			return sections
		end,
		menu = Skip,
	}
end

-- Beast Training as a route errand: no place; a click opens the pet's training window.
local function Teach()
	if not T.db.pets.on then return nil end
	local now = Pets.Now()
	local pet = now and now.pet
	local spell = Training()
	if not pet or not spell or Busy() then return nil end
	local name = UnitName("pet")
	if name == nil or issecretvalue(name) then name = "your pet" end
	local count = #pet.list
	local function Open()
		local window = rawget(_G, "ClassTrainerFrame")
		return window ~= nil and window:IsShown()
	end
	return {
		title = pet.fresh and ("Teach %s new skills"):format(name)
			or ("Teach %s: %d skill%s"):format(name, count, count == 1 and "" or "s"),
		lines = { ("%d training point%s free"):format(pet.free, pet.free == 1 and "" or "s") },
		caption = ("PET LEVEL %d  \194\183  BEAST TRAINING"):format(UnitLevel("pet")),
		mark = "pet",
		first = IsResting() or nil,
		hint = "Open Beast Training",
		over = function(row) ns.Spec.KeyOver(row, nil, "teach", Open(), spell) end,
		click = function()
			if InCombatLockdown() then T:Print("can't open Beast Training from the card in combat.") end
		end,
		hover = function()
			if pet.fresh then
				return { { title = "For your pet", rows = { { glyph = "note", quiet = true, text = "New ranks from the pet trainer" } } } }
			end
			return { { title = "For your pet", rows = Rows(pet.list, function(skill) return ("%d TP"):format(skill.cost) end) } }
		end,
	}
end

-- The class's pet quests

-- A quest's class bit, read from its record's text without reading the rest.
local function ClassBit(text)
	return tonumber(text:match("^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^(%d*)")) or 0
end

local function Counts(quest)
	for _, token in ipairs(quest.goals or {}) do
		if token.kind == "c" then return true end
	end
	return false
end

-- Where a pet's chain ends: a hunter's taming, a warlock's binding.
local function Bound(quest, bit)
	if quest.classes ~= bit or not Counts(quest) then return false end
	return bit == CLASSES.HUNTER or quest.level <= BOUND
end

local quests, questsFor = nil, nil   -- the class's pet quests: [id] = true
local after = {}                     -- of those, the ones that come after a taming or binding: [id] = true
local function PetQuests(class)
	if questsFor == class then return quests end
	quests, questsFor = {}, class
	wipe(after)
	local bit = CLASSES[class]
	if not bit then return quests end
	local class = {}
	for id, text in pairs(ns.data.quests or {}) do
		if ClassBit(text) == bit then
			class[#class + 1] = id
			local quest = D.Quest(id)
			for _ = 1, CHAIN do
				if not quest then break end
				if Bound(quest, bit) then
					quests[id] = true
					break
				end
				quest = quest.next and D.Quest(quest.next)
			end
		end
	end
	-- And what comes right after a taming or a binding (a hunter's Training the Beast).
	for _, id in ipairs(class) do
		local quest = D.Quest(id)
		for _, before in ipairs(quest.preSingle or {}) do
			local was = D.Quest(before)
			if was and Bound(was, bit) and not quests[id] then
				quests[id], after[id] = true, true
			end
		end
	end
	return quests
end

-- What the rules last went by: [spell] = known. A change asks again what is on offer (SPELLS_CHANGED below).
local knew = {}
local function Knows(spells)
	local any = nil
	for _, spell in ipairs(spells) do
		local known = C_SpellBook.IsSpellKnown(spell)
		knew[spell] = known
		if known and not any then any = spell end
	end
	return any
end

-- A hunter's pet quest whose lesson is known already (L.Taught): every race's trainer has a taming chain of
-- their own, and a guide may pass two. One who can tame has none of them left to take, and one with Beast
-- Training no Training the Beast.
function L.Taught(quest)
	if quest.classes ~= CLASSES.HUNTER or Class() ~= "HUNTER" or not PetQuests("HUNTER")[quest.id] then return nil end
	return Knows(after[quest.id] and TRAINING or TAME)
end

local function Relearned()
	for spell, known in pairs(knew) do
		if C_SpellBook.IsSpellKnown(spell) ~= known then return true end
	end
	return false
end

-- Whether a quest is the class's taming or binding, or leads to one.
function Pets.Quest(id, class)
	return PetQuests(class or Class() or "") [id] == true
end

-- Whether a quest is one of the class's taming quests: hunter only, with a creature to count.
function Pets.Taming(id)
	local quest = D.Quest(id)
	return quest ~= nil and Bound(quest, CLASSES.HUNTER) and quest.classes == CLASSES.HUNTER
end

-- The pet quest the character can take now, the lowest first: { quest, npc, map, x, y, yards }, or nil. A
-- breadcrumb gives way to the quest it leads to where that can be taken as well.
local function Offered()
	local class = Class()
	if not class then return nil end
	local best, open = nil, {}
	for id in pairs(PetQuests(class)) do
		local quest = D.Quest(id)
		if quest and not L.Has(id) and L.CanStart(quest) then open[id] = quest end
	end
	for _, quest in pairs(open) do
		if not (quest.breadcrumbFor and open[quest.breadcrumbFor]) then
			for _, token in ipairs(quest.starts) do
				local npc = token.kind == "n" and D.Npc(token.id)
				local map, x, y, yards, dungeon = W.Nearest(npc and npc.places or {})
				if map and not dungeon and (not best or quest.level < best.quest.level
					or (quest.level == best.quest.level and (yards or math.huge) < (best.yards or math.huge))) then
					best = { quest = quest, npc = npc, map = map, x = x, y = y, yards = yards }
				end
			end
		end
	end
	return best
end

-- Whether the route already has a stop to take it (a quest giver nearby is a stop of its own).
local function Taken(id)
	for _, stop in ipairs(R.stops or {}) do
		for _, action in ipairs(stop.actions or {}) do
			if action.kind == "pickup" and action.id == id then return true end
		end
	end
	return false
end

-- The pet quest as a route errand (R.AddErrand), or nil.
local function Quest(lead)
	if not T.db.pets.on or Skipped() or Busy() then return nil end
	local offered = Offered()
	if not offered or Taken(offered.quest.id) then return nil end
	local quest, npc = offered.quest, offered.npc
	local passing = R.Passing("petquest", offered.map, offered.x, offered.y, lead, nil, WORTH, true)
	if not passing and (offered.yards or math.huge) > LISTED then return nil end
	return {
		title = "Pet quest: " .. quest.name,
		lines = { npc.name },
		caption = ("LEVEL %d  \194\183  YOUR PET"):format(UnitLevel("player")),
		map = offered.map, x = offered.x, y = offered.y, thing = npc, who = npc.name,
		mark = "pet",
		first = passing or nil,
		menu = Skip,
	}
end

-- The card's note under a leading stop that works on a taming quest (ns.cardNotes).
local function Note(stop)
	if Class() ~= "HUNTER" or stop.kind == "errand" then return nil end
	for _, action in ipairs(stop.view and stop.view.actions or stop.actions or {}) do
		if action.kind == "goal" and not action.done and action.id and Pets.Taming(action.id) and L.Has(action.id)
			and not C_QuestLog.IsComplete(action.id) then
			return "Tame it, don't kill it"
		end
	end
end

-- Events

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "SPELLS_CHANGED", "TRAINER_SHOW",
	"TRAINER_UPDATE", "MERCHANT_SHOW", "UNIT_PET_TRAINING_POINTS", "QUEST_TURNED_IN", "QUEST_ACCEPTED" }) do
	events:RegisterEvent(event)
end
events:RegisterUnitEvent("UNIT_PET", "player")
events:RegisterUnitEvent("UNIT_LEVEL", "pet")
events:SetScript("OnEvent", function(_, event)
	if not ns.char or not Class() then return end
	if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
		ReadTrainers()
	elseif event == "MERCHANT_SHOW" then
		ReadDemons()
	elseif event == "SPELLS_CHANGED" and Relearned() then
		-- (A lesson learned, Tame Beast after the last taming: what is on offer is asked again.)
		wipe(knew)
		ns.RefreshOffers()
	end
	stale = true
	-- (What a trainer or a vendor lists is the pet errand's alone: the errands are fitted again, not the route.)
	ns.RefreshErrands()
end)

ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Note)

ns.CardSwitch("errands", function(root)
	if not Class() then return end
	root:CreateCheckbox("Your pet's trainer and quests", function() return T.db.pets.on end, function()
		T.db.pets.on = not T.db.pets.on
		ns.Apply()
	end)
end)

ns.OnApply(function() stale = true end)

if R and R.AddErrand then
	R.AddErrand("pettrainer", Trainer, "Pet trainer")
	R.AddErrand("teach", Teach, "Teaching your pet")
	R.AddErrand("petquest", Quest, "Pet quests")
end
if R and R.AddOffer then
	R.AddOffer("pettrainer", function()
		local now = T.db.pets.on and ns.char and Class() and Pets.Now()
		local due = now and now.trainer
		if not due then return {} end
		return { { text = ("%s: %d new %s%s"):format(now.class == "HUNTER" and "Pet trainer" or "Demon trainer", #due.list,
			now.class == "HUNTER" and "skill" or "grimoire", #due.list == 1 and "" or "s") } }
	end)
	R.AddOffer("petquest", function()
		local offered = T.db.pets.on and ns.char and Class() and Offered()
		return offered and { { text = "Pet quest: " .. offered.quest.name } } or {}
	end)
end
