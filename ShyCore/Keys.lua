-- A class's keys, laid out once for every level. Each key has a job (Strike, Wall, Potion, ...) and each job is
-- a macro of the character's own that chooses the ability by stance and by what has been learned. A job is put
-- on its key when it has something to do (one of its spells is known, or the bags hold what it uses) and not
-- before, so no key stands empty; from then on its ability changes by itself as more is trained. What stood
-- on a button before is remembered, and one press puts it all back. A class addon gives its jobs; this lays
-- them out the same way for every class.
--
--   Shy.Keys.Apply(addon, jobs, opts)   writes the macros of the jobs that have something to do, puts each on the
--                                       action button its key presses, and binds the keys that press nothing yet
--                                       (the stance bar's first buttons on 1 2 3 for a class that has one:
--                                       opts.stances; and a job's spare button). Only a macro made here is
--                                       rewritten: one of the player's by the same name is left alone and named.
--                                       Out of a fight.
--                                       -> { placed, waiting, bound, left = { { job, why } }, new = { job }, learns }
--   Shy.Keys.Revert(addon)              the macros made here go, and every button and key is as it was before
--                                       the first layout.  -> { put, lost } (buttons put back; ones that couldn't be)
--   Shy.Keys.Run / Shy.Keys.Back        the same two, said in chat
--   Shy.Keys.Watch(addon, jobs, opts)   from then on: a job comes to its key when it first has something to do
--                                       (said in chat), a job from the bags follows what the bags hold, and the
--                                       whole layout follows the talent build
--   Shy.Keys.Has(addon)                 whether this character's keys are laid out
--   Shy.Keys.List(jobs, opts, addon)    every key and what it does, as text (addon: one you moved, where it is)
--   Shy.Keys.Text(job)                  a job's macro as it would be written now, or nil
--   Shy.Keys.At(jobs, opts, level, addon)   the keys as they would stand at a level: job -> { key, name, icon, ... }
--   Shy.Keys.Story(jobs, opts, addon)   every level's keys, what changes at each, and each key's abilities by level
--   Shy.Keys.Panel(parent, width)       the keys' controls for this character's class: lay out, put back, follow the
--                                       build, and the keys drawn on two hands at any level (Keys.WIDE across).
--                                       On the hub's page, and on a class addon's own.
--
-- A job: name (the macro's, it stands under the button), key, what (the job in words), spare (the button its key
-- is bound to when the key presses nothing), and either its lines, naming spells by ID in braces ("/cast {78}":
-- written as the game's own names), or supply = { kind, ... } (food, drink, potion, mana, rage, energy, bandage,
-- healthstone, soulstone, managem): the best of each kind in the bags that the character can use, one line a
-- kind; me = true uses it on yourself, friend = true on a friend or you, over = true on the friend the mouse is
-- on, else you; turns = true uses one a press, in the order of its kinds (a healthstone, then the potion); lines
-- beside a supply come after it (the spell that makes one). item = true: the job stands as the item itself, no
-- macro (the first of its kinds the bags hold): its button shows the item and how many you have.
-- An ability stands on one key: a job that could only cast what earlier jobs already have waits
-- (shared = true: it stands all the same, as an attack key named for a strike). early = a key (asdfEarly: for
-- ASDF): the easy key it stands on until that key's own job arrives (it made way there for the stop, which
-- comes later). stay = true: it never stands in on an easy key (a summon, a long buff on the number row).
-- A job's by = { [build id] = job } is what its key does for that talent build instead (no key of
-- its own); a macro made for a job the build doesn't have is deleted, so a class stays within a character's
-- macros.
-- opts: build (a function: the build's id and name; Shy.Keys.Build asks ShyQuest), forms (the stances whose
-- page of the main bar gets the job too) with plain (and the bar's own page: a class not always in a form),
-- knows (a spell the class always has, to ask whether macros can tell what is learned), stances (what 1 2 3
-- are, in words), list (the command that lists the keys), keep (what to stay in on the stance bar, by build: { plain =
-- { spell, ... }, [build id] = { spell, ... } }, the first of a list you have counts; any rank, by name) and keeps
-- (what one is called: "aura", "stance", "form").
--
-- Laid out, the keys are yours: a key's ability you move to another button (or take off the bars) stays where
-- you put it from then on, and is moved no more; put it back where it was and it follows the layout again. An
-- ability the layout tidied away and you put back on a bar stays too. Putting the keys back leaves what you put
-- on a button since, and a key you bound to something else since.
--
-- Nothing of yours is lost to a layout: your own button for an ability or a kind of item a key now holds is
-- taken off and remembered; anything else a job takes a button from (a racial, a trinket, a macro of yours)
-- moves to a free button, and goes back where it was when the keys are put back.
--
-- addon.db holds, by character: keysMade (the macros made here), keysBuild (the build last laid out) and
-- keysBefore (what was on each button and key before, and where each macro was put and where you moved it).
-- Name the three in the addon's `keep`.
--
-- Your hotkeys are a choice of their own (Keys.Mode: "shy" or "own"), made before anything changes:
--   Keys.Board(opts, scheme)         the keys a layout is made for: key -> binding, and the keys in order
--   Keys.Hotkeys.Plan(opts)          what setting them would change now, with nothing done
--   Keys.Hotkeys.Take / Back / On    set them, put every one back as it was, whether they are set
--   Keys.Lay(addon, jobs, opts)      the hotkeys as picked, then Apply; Keys.Unlay(addon): Revert, then the hotkeys back
--   Keys.SetMode(mode)               picks; with keys laid out it is done at once
-- See "Your hotkeys" below.

local Shy = Shy
local UI = Shy.UI

local Keys = {}
Shy.Keys = Keys

local ICON = 134400          -- the question mark: the game then shows what the macro will cast or use
local LONGEST = 255          -- characters a macro holds
local FORM_KEYS = 3          -- the stance bar's buttons that get a key: 1 2 3
local SOON = 1               -- seconds after spells change before the keys are looked at again
local LAYOUT = 4             -- a layout's make (keysBefore.layout): 2 puts macros by their names; 3 has a key for each
                             -- thing in the bags, what you stay in on 1 2 3 and your people's abilities; 4 has the
                             -- number row on the two flyouts, and what you stay in there as the spell itself
local NAMED = 2              -- the make from which a macro off its button was moved by you

local watched = {}           -- { addon, jobs, opts, waiting }: the class whose keys are followed (Keys.Watch)

-- Your hotkeys: the two side bars the number row presses (the left flyout's with a plain key, the right flyout's
-- with Shift; their bindings, their places among the game's bar switches), the board's rows as a hand meets them,
-- and what moves you sideways (a side key that turns you is left turning you).
local HOT = {
	plain = "MULTIACTIONBAR4BUTTON", bar = "MULTIACTIONBAR3BUTTON", toggles = { 3, 4 },
	rows = { "1234567890-=", "QWERT", "ASDFG", "ZXCVB" }, mouse = { "BUTTON4", "BUTTON5" },
	sides = { STRAFELEFT = true, STRAFERIGHT = true, TURNLEFT = true, TURNRIGHT = true },
	never = 9,               -- a place no stance bar has: a macro's "[stance:9]" is never so
	feeds = 15,              -- levels under a pet's that food still feeds it well
	stories = {}, told = 0, tells = 4,   -- the stories kept (Keys.Story), how many, and the most
	-- What a hand reaches for without looking: a key of yours that does one of these is listed first, and in gold,
	-- before the hotkeys take it (so is one that casts, uses or clicks something of yours).
	musts = { TOGGLEAUTORUN = true, STARTAUTORUN = true, JUMP = true, TOGGLERUN = true, MOVEANDSTEER = true,
		MOVEFORWARD = true, MOVEBACKWARD = true, STRAFELEFT = true, STRAFERIGHT = true, TURNLEFT = true, TURNRIGHT = true,
		SITORSTAND = true, OPENALLBAGS = true, TOGGLEBACKPACK = true, TOGGLEWORLDMAP = true, TOGGLEMINIMAP = true,
		TOGGLECHARACTER0 = true, TOGGLESPELLBOOK = true, TOGGLETALENTS = true, TOGGLEQUESTLOG = true,
		INTERACTTARGET = true, INTERACTMOUSEOVER = true, TARGETNEARESTENEMY = true, TARGETNEARESTFRIEND = true,
		TOGGLEGAMEMENU = true, OPENCHAT = true, REPLY = true },
	named = 10,              -- the most of those named in a chat line before "and N more"
	-- What moves you: the board's keys do that, so nothing of it moves to Ctrl + its key (Hot.HomeOf).
	moving = { MOVEFORWARD = true, MOVEBACKWARD = true, STRAFELEFT = true, STRAFERIGHT = true, TURNLEFT = true,
		TURNRIGHT = true, MOVEANDSTEER = true },
	home = "CTRL-",          -- where what a key did goes: Ctrl + that key
	step = 22, stepGap = 10, -- a step of the keys' page: its number's plate, and the room after it
	followGap = 12, buttons = 12 + 24 + 12 + 20,   -- the button under the choices, and Follow my talents under it
	steer = { STRAFELEFT = "TURNLEFT", STRAFERIGHT = "TURNRIGHT" },   -- the turn each side key did before it strafed
	-- Picking a key in the list: a key held with another is no key of its own; the mouse's other buttons are keys.
	metas = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true },
	mice = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" },
}

-- The bars a key can press a button of: the binding's name -> the bar's page (the main bar has none of its own).
local PAGES = {
	MULTIACTIONBAR1BUTTON = BOTTOMLEFT_ACTIONBAR_PAGE,
	MULTIACTIONBAR2BUTTON = BOTTOMRIGHT_ACTIONBAR_PAGE,
	MULTIACTIONBAR3BUTTON = RIGHT_ACTIONBAR_PAGE,
	MULTIACTIONBAR4BUTTON = LEFT_ACTIONBAR_PAGE,
}

-- What is in the bags, by the spell it casts: a kind -> spells of that name (any rank of food is "Food").
local SUPPLIES = {
	food = { 433, 1248377 },
	drink = { 430, 1249906 },
	potion = { 439, 21393 },
	mana = { 437 },
	rage = { 6612, 6613, 17528 },
	energy = { 9512 },
	bandage = { 746 },
	healthstone = { 6262, 6263, 5720, 5723, 11732 },
	soulstone = { 20707 },
	managem = { 5405 },
	-- A rogue's poisons: the quick one for the main hand, the others for the off hand.
	instant = { 8679, 8686, 8688, 11338, 11339, 11340 },
	venom = { 2823, 2824, 11355, 11356, 25351, 3408, 5761, 8693, 11399, 13219, 439465, 439464, 458821, 1214171, 439462 },
	-- What a hunter's pet eats (told by the pet's diet, not by a spell: this one is the key's picture).
	petfood = { 6991 },
}
local EMPTY = {}
local kinds              -- spell name -> kind
local loading = {}       -- item -> true: asked of the game, its answer still to come (Keys.Watch looks again then)

local function Kinds()
	if kinds then return kinds end
	kinds = {}
	for kind, spells in pairs(SUPPLIES) do
		for _, id in ipairs(spells) do
			local name = C_Spell.GetSpellName(id)
			if name then kinds[name] = kind end
		end
	end
	return kinds
end

-- The kind an item is (food, drink, ...), or nil: something you use up, told by the spell it casts (a belt
-- that casts "Rage" is no rage potion). One the game hasn't loaded yet is asked for.
local function Kind(item)
	local _, _, _, _, _, class = C_Item.GetItemInfoInstant(item)
	if class ~= Enum.ItemClass.Consumable then return nil end
	local spell = C_Item.GetItemSpell(item)
	if not spell then
		if not loading[item] and not C_Item.IsItemDataCachedByID(item) then
			loading[item] = true
			C_Item.RequestLoadItemDataByID(item)
		end
		return nil
	end
	return Kinds()[spell]
end
Keys.Kind = Kind

-- The best of each kind in the bags that the character is of a level to use: kind -> item. The best is the one
-- that asks the highest level; of two that ask the same, one that was conjured (it costs nothing, and is gone
-- when you log out), then the better made.
local function Bags()
	local best, rank = {}, {}
	local level = UnitLevel("player")
	local conjured = Shy.KeyConjured or EMPTY
	-- What your pet eats (a hunter's, with its pet out): the diets the game says it has, by their place.
	local food, eats = Shy.KeyPetFood, nil
	local diets = food and C_PetInfo.GetPetFoodTypes()
	if diets and #diets > 0 then
		eats = {}
		for id, name in ipairs(food.names) do
			for _, diet in ipairs(diets) do
				if diet == name then eats[id] = true end
			end
		end
	end
	local enough = (tonumber(UnitLevel("pet")) or 0) - HOT.feeds
	for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local item = C_Container.GetContainerItemID(bag, slot)
			if item and eats and eats[food.items[item] or 0] then
				local _, _, _, _, need = C_Item.GetItemInfo(item)
				need = need or 0
				if need <= level then
					-- (the plainest food that still feeds a pet of its level well: the good food is yours; else the best)
					local value = need >= enough and -need or need - 1000
					if not rank.petfood or value > rank.petfood then best.petfood, rank.petfood = item, value end
				end
			end
			local kind = item and Kind(item)
			if kind then
				local _, _, _, worth, need = C_Item.GetItemInfo(item)
				need = need or 0
				if need <= level then
					local value = need * 10000 + (conjured[item] and 5000 or 0) + (worth or 0)
					if not rank[kind] or value > rank[kind] then best[kind], rank[kind] = item, value end
				end
			end
		end
	end
	return best
end

-- A macro's text: its spells named, or its supplies as the bags hold them. nil when the game can't name a
-- spell yet or the text is longer than a macro holds.
function Keys.Text(job, best)
	local lines = job
	if job.make then
		lines = job.make()
		if not lines then return nil end
	elseif job.supply then
		best = best or Bags()
		local use = job.friend and ("/use " .. Keys.FRIEND .. " item:%d") or job.over and "/use [@mouseover,help,nodead][@player] item:%d"
			or job.me and "/use [@player] item:%d" or "/use item:%d"
		lines = { job.show or "#showtooltip" }
		-- (its lines that come before the item: the spell a pet's food is fed with)
		for _, line in ipairs(job.before or EMPTY) do lines[#lines + 1] = line end
		local held = {}
		for _, kind in ipairs(job.supply) do
			if best[kind] and not (job.only and #held > 0) then held[#held + 1] = best[kind] end
		end
		if job.turns and #held > 1 then
			-- One a press, in turn (a healthstone, then the potion: each has its own cooldown, and one press
			-- shouldn't spend both); the end of the fight starts it over.
			for i, item in ipairs(held) do held[i] = "item:" .. item end
			lines[#lines + 1] = "/castsequence reset=combat " .. table.concat(held, ", ")
		else
			for _, item in ipairs(held) do lines[#lines + 1] = use:format(item) end
		end
		-- Its own lines come after: what makes one when the bags hold none (a warlock's stones).
		for _, line in ipairs(job) do lines[#lines + 1] = line end
	end
	local whole = true
	-- A stance named by its spell ("[stance:{768}]") is written as its place on your stance bar, so the macro
	-- asks for the form you have there whatever you skipped; one the bar doesn't hold is a place it never has.
	-- ("{9634|5487}": whichever of them the bar holds, a form and the one that replaces it.)
	local at
	local function Place(ids)
		at = at or Keys.Stances() or HOT.stances or EMPTY
		for id in ids:gmatch("%d+") do
			local name = C_Spell.GetSpellName(tonumber(id))
			if name and at[name] then return tostring(at[name]) end
		end
		return tostring(HOT.never)
	end
	local text = table.concat(lines, "\n"):gsub("(stance:)([%d/{}|]+)", function(word, places)
		return word .. (places:gsub("{([%d|]+)}", Place))
	end)
	text = text:gsub("{(%d+)}", function(id)
		local name = C_Spell.GetSpellName(tonumber(id))
		if not name then whole = false end
		return name or ""
	end)
	if whole and #text <= LONGEST then return text end
end

-- Lines a class's jobs are written with.
-- A heal or a blessing's target: the friend the mouse is on, else the friend targeted, else you.
Keys.FRIEND = "[@mouseover,help,nodead][help,nodead][@player]"
Keys.OTHER = "[@mouseover,help,nodead][help,nodead]"   -- (a friend, never you)
-- A raise's target: the dead friend the mouse is on, else the one targeted, else nobody, so the game gives you its
-- glowing hand and you click who to raise (a body whose owner has let go of it is reached no other way).
Keys.DEAD = "[@mouseover,help,dead][help,dead][@none]"

-- A spell for a friend, and the one it stands in for until it is learned: "/cast (friend) New; (friend) Old".
function Keys.Grows(new, old)
	local known = ("[known:{%d},@mouseover,help,nodead][known:{%d},help,nodead][known:{%d},@player]"):format(new, new, new)
	return ("/cast %s {%d}; %s {%d}"):format(known, new, Keys.FRIEND, old)
end

-- Whichever one of several spells is known (asked by ID, so a long list fits a macro).
function Keys.Either(spells)
	local parts = {}
	for i, id in ipairs(spells) do
		parts[i] = (i < #spells and "[known:%d] {%d}" or "{%d}"):format(id, id)
	end
	return "/cast " .. table.concat(parts, "; ")
end

-- The bags' keys, the same on every class: with Shift on the bottom row, Eat, Drink, Bandage, Healing, and the
-- class's own potion. Added to a class's jobs, after its own.
--   spec.drink    a class with mana drinks: one without has nothing on Shift + X, so the row reads the same on
--                 every character
--   spec.stone    a healthstone someone gave you comes before the potion (not for the class that makes them on
--                 a key of its own)
--   spec.potion   { name, kind, what }: the class's own (mana, rage, energy)
function Keys.Carried(jobs, spec)
	local function Add(job)
		job.asdf = job.key
		jobs[#jobs + 1] = job
	end
	Add({ name = "Eat", key = "SHIFT-Z", what = "Eat your best food", supply = { "food" }, item = true })
	if spec.drink then
		Add({ name = "Drink", key = "SHIFT-X", what = "Drink your best water", supply = { "drink" }, item = true })
	end
	Add({ name = "Bandage", key = "SHIFT-C", what = "Bandage the friend the mouse is on, else yourself", supply = { "bandage" }, over = true })
	if spec.stone then
		Add({ name = "Healing", key = "SHIFT-V", what = "A healthstone if you carry one, then your best healing potion",
			supply = { "healthstone", "potion" }, turns = true })
	else
		Add({ name = "Healing", key = "SHIFT-V", what = "Drink your best healing potion", supply = { "potion" }, item = true })
	end
	if spec.potion then
		Add({ name = spec.potion.name, key = "SHIFT-B", what = spec.potion.what, supply = { spec.potion.kind }, item = true })
	end
	return jobs
end
Keys.MANA = { name = "Mana", kind = "mana", what = "Drink your best mana potion" }

-- Who you are, for what your people alone can do: the race's ID (two peoples share a name in the game's files).
local function Race()
	local _, _, id = UnitRace("player")
	return id
end

-- Your mount, as a macro's lines, and its picture: a favorite first, and of those one you can ride here; nil with
-- none. Pressed again it gets you off. (A job's make = a function that gives its lines so: it stands once it has any.)
local function Mount()
	local pick, name, icon, worth
	for _, id in ipairs(C_MountJournal.GetMountIDs()) do
		local called, _, picture, _, usable, _, favorite, _, _, hidden, collected = C_MountJournal.GetMountInfoByID(id)
		local value = (favorite and 2 or 0) + (usable and 1 or 0)
		if collected and not hidden and (not worth or value > worth) then pick, name, icon, worth = id, called, picture, value end
	end
	if not pick then return nil end
	return { "#showtooltip " .. name, ("/run if IsMounted() then Dismount() else C_MountJournal.SummonByID(%d) end"):format(pick) }, icon
end

-- Your people's two abilities, the same keys on every class: Shift + 1 the one you answer with in a fight,
-- Shift + 2 the other (Shy.KeyRacials: race -> the two, each { spell, its name on a key }); and your mount on
-- Shift + 3. Added to a class's jobs; a job's race = { [race ID] = job } is what its key does for that people (a
-- people with none has no job).
function Keys.People(jobs)
	jobs[#jobs + 1] = { name = "Mount", key = "SHIFT-3", asdf = "SHIFT-3", stay = true,
		what = "Your mount, a favorite first; pressed again it gets you off", make = Mount }
	for n, key in ipairs({ "SHIFT-1", "SHIFT-2" }) do
		local race = {}
		for id, pair in pairs(Shy.KeyRacials or EMPTY) do
			-- (the spell itself on its button, no macro: its lines say what it casts, for what is learned and shown)
			race[id] = { name = pair[n][2], what = pair[n][2], spell = pair[n][1], "#showtooltip", ("/cast {%d}"):format(pair[n][1]) }
		end
		jobs[#jobs + 1] = { name = n == 1 and "Racial" or "Racial 2", key = key, asdf = key, stay = true,
			what = "What your people alone can do", race = race }
	end
	return jobs
end

-- What you stay in (a stance, a form, an aura) on 1 2 3: the spell itself on the left flyout's first buttons,
-- a second place for what the game's own bar of them holds. Added to a class's jobs. modes = { plain = { mode,
-- ... }, [build id] = { ... } }: a mode is { name = "Bear Form", spell, ... } (the first of its spells you know
-- stands there), a build's list is what it has on 1 2 3 instead, and a build with none says {}.
function Keys.Stays(jobs, modes)
	local function Job(mode)
		local casts, spells = {}, {}
		for i, spell in ipairs(mode) do
			casts[i] = (i < #mode and "[known:{%d}] {%d}" or "{%d}"):format(spell, spell)
			spells[i] = spell
		end
		-- (shared among themselves alone: a key that also takes you into a stance doesn't keep the stance off its
		-- own button, while of two that come to the same aura the second waits)
		return { name = mode.name, what = mode.what or mode.name, spell = #spells == 1 and spells[1] or spells, shared = "stays",
			stay = true, "#showtooltip", "/cast " .. table.concat(casts, "; ") }
	end
	local builds = {}
	for build in pairs(modes) do
		if build ~= "plain" then builds[#builds + 1] = build end
	end
	table.sort(builds)
	for i = 1, FORM_KEYS do
		local first = modes.plain and modes.plain[i]
		for _, build in ipairs(builds) do first = first or modes[build][i] end
		if first then
			local job = Job(first)
			job.key, job.asdf, job.by = tostring(i), tostring(i), {}
			for _, build in ipairs(builds) do
				local mode = modes[build][i]
				if not mode then
					job.by[build] = false
				elseif mode ~= first then
					job.by[build] = Job(mode)
				end
			end
			jobs[#jobs + 1] = job
		end
	end
	return jobs
end

-- What a class teaches one people alone (Shy.KeyGifts: class -> race -> its two, each { spell, name, on a
-- friend }): the nth of each, as a job's `race`. One for a friend goes to the friend under the mouse, else the
-- friend you target, else you; one the game won't cast on yourself ("other") waits for a friend, and shows
-- itself all the same (with no friend its cast is no spell, and the button would be a question mark).
function Keys.Gifts(class, n)
	local race = {}
	for id, pair in pairs(Shy.KeyGifts and Shy.KeyGifts[class] or EMPTY) do
		local gift = pair[n]
		if gift then
			local other = gift[3] == "other"
			race[id] = { name = gift[2], what = gift[2], other and ("#showtooltip {%d}"):format(gift[1]) or "#showtooltip",
				("/cast %s{%d}"):format(other and (Keys.OTHER .. " ") or gift[3] and (Keys.FRIEND .. " ") or "", gift[1]) }
		end
	end
	return race
end

local function Lines(text)
	return select(2, text:gsub("\n", "\n"))
end

-- Whether the game's macros can ask what you have learned: the keys that change as you level need it.
local function Learns(spell)
	local name = spell and C_Spell.GetSpellName(spell)
	return name ~= nil and SecureCmdOptionParse("[known:" .. name .. "] 1; 0") == "1"
end

-- The best rank of a spell in your spellbook (by the level it is learned at), else the spell as given.
local function Highest(spell)
	local name = C_Spell.GetSpellName(spell)
	if not name then return spell end
	local best, top = spell, -1
	local bank = Enum.SpellBookSpellBank.Player
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		for slot = info and info.itemIndexOffset + 1 or 1, info and info.itemIndexOffset + info.numSpellBookItems or 0 do
			local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
			local id = item and item.itemType == Enum.SpellBookItemType.Spell and item.name == name and (item.spellID or item.actionID)
			local level = id and C_Spell.GetSpellLevelLearned(id) or -1
			if id and level >= top then best, top = id, level end
		end
	end
	return best
end

-- Whether a spell is known, asked as a macro asks: its name, or nil. `known` keeps the answers of one layout.
local function Known(id, known)
	if known[id] == nil then
		local name = C_Spell.GetSpellName(tonumber(id))
		known[id] = name ~= nil and SecureCmdOptionParse("[known:" .. name .. "] 1; 0") == "1" and name or false
	end
	return known[id] or nil
end

-- What a job can cast now, as names: the spells its macro could come to (the line its button shows: a written
-- "#showtooltip ...", else its first /cast), with what is learned decided and every other condition (a stance,
-- a fight, a target) left open; a spell not known yet, and one in `shifts` (a stance the key only passes
-- through), is no part of it. nil for a job that casts nothing by name.
local function Does(job, known, shifts, every)
	-- (a job that stands as the spell itself is for that spell, whatever other keys only pass through)
	if job.spell ~= nil then shifts = nil end
	-- (every: all it casts, on any of its lines, as a Charge that ends in Bloodrage does.)
	if every then
		local all = {}
		for _, line in ipairs(job) do
			if line:match("^/cast%s") then
				for _, name in ipairs(Does({ line }, known, shifts) or {}) do all[#all + 1] = name end
			end
		end
		return all
	end
	local chain
	for i, line in ipairs(job) do
		chain = (i == 1 and line:match("^#showtooltip%s+(.+)")) or line:match("^/cast%s+(.+)")
		if chain then break end
	end
	if not chain then return nil end
	local does, ids, whens = {}, {}, {}   -- (and each one's spell, by ID, and the clause it comes from)
	local met = {}           -- the other conditions an earlier clause already answers: the same again is never come to
	for clause in (chain .. ";"):gmatch("%s*(.-);") do
		-- A clause can be come to when one of its bracketed groups holds on what is learned (its other
		-- conditions may or may not hold, unless an earlier clause took those very ones); it is sure, and
		-- ends the line, when one holds on what is learned alone.
		local open, sure, groups = false, false, 0
		for group in clause:gmatch("%b[]") do
			groups = groups + 1
			local holds, rest = true, {}
			for cond in group:sub(2, -2):gmatch("[^,]+") do
				local no, id = cond:match("^%s*(n?o?)known:{?(%d+)}?%s*$")
				if id then
					if (Known(id, known) ~= nil) == (no == "no") then holds = false end
				elseif not cond:match("^%s*@") then   -- (whom it is cast on is no condition)
					rest[#rest + 1] = strtrim(cond)
				end
			end
			if holds then
				table.sort(rest)
				local others = table.concat(rest, ",")
				if others == "" then
					open, sure = true, true
				elseif not met[others] then
					met[others] = true
					open = true
				end
			end
		end
		if groups == 0 then open, sure = true, true end
		if open then
			local id = clause:match("{(%d+)}%s*$")
			local name = id and Known(id, known)
			if name and not (shifts and shifts[tonumber(id)]) then
				does[#does + 1] = name
				ids[#ids + 1] = tonumber(id)
				whens[#whens + 1] = clause
			end
			if sure then break end
		end
	end
	return does, ids, whens
end

Keys.Does = Does

-- Whether a job has something to do now: the bags hold what it uses, or its macro could cast a spell that is
-- known. Where macros can't ask what is known, every job is taken to.  -> ready, and what it can cast
local function Ready(job, best, learns, known, shifts)
	if job.make then return job.make() ~= nil end   -- (a job that writes its own lines: when it has any)
	if job.supply then
		for _, kind in ipairs(job.supply) do
			if best[kind] then return true end
		end
		-- (with none in the bags it has something to do only when its own lines make one: a warlock's stones)
		local makes = false
		for _, line in ipairs(job) do
			if line:find("^/cast") then makes = true end
		end
		if not makes then return false end
	end
	if not learns then return true end
	local does = Does(job, known, shifts)
	if not does then return true end
	return #does > 0, does
end

-- The action slots a binding's button holds: one, or the main bar's on each stance's page.  -> { slot, ... } or nil
local function Slots(command, opts)
	local n = tonumber(command:match("^ACTIONBUTTON(%d+)$"))
	if n then
		local forms = opts.forms or 0
		local slots = {}
		if forms == 0 or opts.plain then slots[1] = n end
		for form = 1, forms do
			slots[#slots + 1] = (NUM_ACTIONBAR_PAGES + form - 1) * NUM_ACTIONBAR_BUTTONS + n
		end
		return slots
	end
	local bar, button = command:match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
	local page = bar and PAGES[bar]
	if page then return { (page - 1) * NUM_ACTIONBAR_BUTTONS + tonumber(button) } end
end

-- A macro by that name: this character's (its index and text); with `any` true the account's too, after it;
-- with "account" the account's alone (one made here that had no room among the character's).
local function Find(name, any)
	local account, own = GetNumMacros()
	local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
	for index = base + 1, any ~= "account" and base + own or 0 do
		local found, _, text = GetMacroInfo(index)
		if found == name then return index, text end
	end
	for index = 1, any and account or 0 do
		local found, _, text = GetMacroInfo(index)
		if found == name then return index, text end
	end
end

-- What the addon keeps for this character under a name: a table, made when first asked for.
local function Mine(addon, field)
	local db = addon.db
	db[field] = db[field] or {}
	local who = UnitGUID("player")
	db[field][who] = db[field][who] or {}
	return db[field][who]
end

local function Made(addon) return Mine(addon, "keysMade") end

-- What stood on each button and key before a job took it: slots[slot] = { kind, id } (a macro by its name) or
-- false for an empty one; keys[key] = the binding given to a key that pressed nothing. And each macro's
-- buttons: placed[name] = { slot, ... } where the layout put it, pinned[name] = { slot, ... } where you moved it.
-- And the macros: account[name] = true for one made here among the account's (the character's were full), and
-- theirs = { account = { name = true }, character = { ... } }, every macro you had before the first layout:
-- none of those is ever deleted here, whatever its name.
-- last[name] = the item a job that stands as its item holds (or last held: its button then shows what to buy),
-- or the spell one stands as (sorts[name] = "spell").
-- homes[slot] = the button something of yours stood on before a job took it and it moved to `slot`.
local function Before(addon)
	local before = Mine(addon, "keysBefore")
	if before.placed == nil then before.ranked = true end   -- (a new layout knows a spell at any rank: Moved)
	before.slots, before.keys = before.slots or {}, before.keys or {}
	before.placed, before.pinned = before.placed or {}, before.pinned or {}
	before.account = before.account or {}
	before.last, before.homes, before.sorts = before.last or {}, before.homes or {}, before.sorts or {}
	return before
end

-- What a job that stands as the thing itself stands as: "item" (a bags' job), or "spell".
local function Sort(name, before)
	return before.sorts[name] or "item"
end

-- What a button holds (kind, id), as such a job is known by: an item by itself, a spell by its name, so any rank
-- of it is the same job's (the game puts a new rank in an old one's place).
local function Ident(kind, id)
	local name = kind == "spell" and C_Spell.GetSpellName(id)
	return name and ("spell:" .. name) or (tostring(kind) .. ":" .. tostring(id))
end

-- Whether a button holding (kind, id) holds what the job `name` stands as.
local function Owns(name, before, kind, id)
	local item = before.last[name]
	return item ~= nil and kind == Sort(name, before) and Ident(kind, id) == Ident(kind, item)
end

-- Whether a job stands as the thing itself, with no macro: its item (job.item), or the spell (job.spell).
local function Solid(job)
	return job.item == true or job.spell ~= nil
end

-- Where a macro made here is: among the account's, or (nil) the character's.
local function Where(name, before)
	return before.account[name] and "account" or nil
end

-- Every macro you have that wasn't made here, by name: the account's and the character's.
local function Theirs(made)
	local theirs = { account = {}, character = {} }
	local account, own = GetNumMacros()
	local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
	for index = 1, account do
		local name = GetMacroInfo(index)
		if name then theirs.account[name] = true end
	end
	for index = base + 1, base + own do
		local name = GetMacroInfo(index)
		if name and not made[name] then theirs.character[name] = true end
	end
	return theirs
end

-- A macro made here goes: deleted where it was made, unless one by that name there was yours before the first layout.
local function Remove(name, made, before)
	local where = Where(name, before)
	local index = Find(name, where)
	local yours = before.theirs and before.theirs[where or "character"][name]
	if index and not yours then DeleteMacro(index) end
	-- (a job that stood as its item or its spell: off the buttons it was put on, or you moved it to)
	local item = before.last[name]
	if item then
		for _, slots in ipairs({ before.placed[name] or EMPTY, before.pinned[name] or EMPTY }) do
			for _, slot in ipairs(slots) do
				if Owns(name, before, GetActionInfo(slot)) then
					PickupAction(slot)
					ClearCursor()
				end
			end
		end
	end
	made[name], before.placed[name], before.pinned[name], before.account[name], before.last[name] = nil, nil, nil, nil, nil
	before.sorts[name] = nil
end

function Keys.Has(addon)
	local made = addon.db and addon.db.keysMade and addon.db.keysMade[UnitGUID("player")]
	return made ~= nil and next(made) ~= nil
end

-- Whether a character's keys were laid out by an earlier make of the layout: they stay exactly as they are (nothing
-- follows the bags, the spells or the build) until the player takes the new one, from the keys' panel or setup.
function Keys.Old(addon)
	if not Keys.Has(addon) then return false end
	local before = addon.db.keysBefore and addon.db.keysBefore[UnitGUID("player")]
	return not before or before.layout ~= LAYOUT
end

-- The job's macro as it should be: its index, or nil and why ("yours": a macro of the player's has the name;
-- "full": no room for another; "name": a spell the game can't name yet), and true when it was made just now.
-- A job from the bags keeps what it last held of a kind the bags have run out of: its button then shows what
-- to buy.
-- A new macro is one of the character's while they have room, else one of the account's (before.account
-- says so; never beside one of yours by that name there, which a look by name couldn't tell from it).
local function Macro(job, made, best, before)
	local text = Keys.Text(job, best)
	if not text then return nil, "name" end
	local where = Where(job.name, before)
	local index, old = Find(job.name, where)
	if index then
		if old == text then
			made[job.name] = true
			return index
		end
		if not made[job.name] then return nil, "yours" end
		if job.supply and Lines(text) < Lines(old) then return index end
		EditMacro(index, job.name, ICON, text)
		return (Find(job.name, where))
	end
	before.account[job.name] = nil
	local account, own = GetNumMacros()
	local character = own < Constants.MacroConsts.MAX_CHARACTER_MACROS
	if not character then
		if account >= Constants.MacroConsts.MAX_ACCOUNT_MACROS then return nil, "full" end
		if Find(job.name, "account") then return nil, "yours" end
		before.account[job.name] = true
	end
	CreateMacro(job.name, ICON, text, character)
	made[job.name] = true
	return (Find(job.name, Where(job.name, before))), nil, true
end

-- The item a job that stands as its item (job.item) should hold now: the best of the first of its kinds the
-- bags hold, else what it last held (its button then shows what to buy), or nil.
local function Pick(job, best, before)
	-- (the spell itself, at the best rank you have: a people's ability, or the first you know of what you stay in)
	if type(job.spell) == "table" then
		for _, spell in ipairs(job.spell) do
			if Learns(spell) then return Highest(spell) end
		end
		return before.last[job.name]
	elseif job.spell then
		return Highest(job.spell)
	end
	for _, kind in ipairs(job.supply) do
		if best[kind] then return best[kind] end
	end
	return before.last[job.name]
end

-- Such a job as it should be: its item (kept as what the job holds), or nil and why ("none": the bags never held
-- one), and true when the job is new here. A macro an earlier layout made for the job goes.
local function Held(job, made, best, before)
	local item = Pick(job, best, before)
	if not item then return nil, "none" end
	local new = made[job.name] == nil
	if not new and before.last[job.name] == nil then
		local where = Where(job.name, before)
		local index = Find(job.name, where)
		local yours = before.theirs and before.theirs[where or "character"][job.name]
		if index and not yours then DeleteMacro(index) end
		before.account[job.name] = nil
	end
	before.last[job.name] = item
	before.sorts[job.name] = job.spell and "spell" or nil
	made[job.name] = made[job.name] or true
	return item, nil, new
end

-- The room a layout's macros have. A layout comes to one macro a job: those not made yet need a place, the
-- character's first, then the account's.
--   -> { need, character, account (free places), spill (how many go among the account's), short (how many have no place) }
function Keys.Space(addon, jobs, opts)
	opts = opts or {}
	local made = addon.db and addon.db.keysMade and addon.db.keysMade[UnitGUID("player")] or {}
	local need = 0
	for _, job in ipairs(Keys.Jobs(jobs, opts.build and (opts.build()))) do
		if job.key and not made[job.name] and not Solid(job) then need = need + 1 end   -- (the thing itself needs no macro)
	end
	local account, own = GetNumMacros()
	local character = Constants.MacroConsts.MAX_CHARACTER_MACROS - own
	local shared = Constants.MacroConsts.MAX_ACCOUNT_MACROS - account
	return { need = need, character = character, account = shared,
		spill = math.max(0, math.min(need - character, shared)), short = math.max(0, need - character - shared) }
end

---------------------------------------------------------------------------
-- How you move: the hand's place on the keyboard
---------------------------------------------------------------------------

-- Two ways to move, and so two places the hand rests. WASD is the game's own: W forward, S back, the ring finger
-- on A, the middle on W and S, the index on D. ASDF: S forward, F back, the hand a key further right, pinky on A,
-- ring on S (forward), middle on D, index on F (back). Each names its four moving keys (no job stands on one)
-- and the keys under the hand with nothing held, easiest first (while one's own job isn't learned yet, a job you
-- can press that stands behind Shift or a reach comes up to it). With ASDF the ring finger holds S to run, so W
-- over it comes after the keys the middle, index and pinky reach while running. The second side button of the
-- mouse is none of them: a short hand can't reach it in a hurry, so nothing stands in there, and only what is
-- never hurried has it for a key. Nor is the number row: it stands apart from the hand, for what is slow.
Keys.SCHEMES = {
	wasd = { name = "WASD", forward = "W", back = "S", left = "A", right = "D", move = { W = true, A = true, S = true, D = true },
		prime = { "E", "Q", "R", "F", "BUTTON4", "T", "G", "C", "V", "X", "Z", "B" } },
	asdf = { name = "ASDF", forward = "S", back = "F", left = "A", right = "D", move = { A = true, S = true, D = true, F = true },
		prime = { "E", "R", "Q", "G", "BUTTON4", "T", "W", "V", "C", "X", "Z", "B" } },
}

-- The keyboard as the bars draw it: each key's own button, the bars a picture of the board (the main bar Q W E R
-- T, Mouse 4 and 5, then Shift + Q W E R T; the bottom left A S D F G, Shift + Mouse 4 and 5, Shift + A S D F G;
-- the bottom right Z X C V B, two with no key, Shift + Z X C V B). Those three bars are the hand's; the number
-- row stands apart, on the two side bars (the flyouts): 1 2 3 4 5 6 7 8 9 0 - = on the left one, and the same
-- with Shift on the right one, each read as a keyboard is whatever shape its bar has: the first key at the top
-- left, then across, then down (Button; here as on a bar of one line). A key that presses nothing is bound to
-- its own button there when a job needs it (and let go again when it is put back); a moving key never is.
local GRID, ROW = {}, {}     -- (ROW: a key of the number row -> its flyout's bar and its place in reading order)
do
	local n = 0
	for key in HOT.rows[1]:gmatch(".") do
		n = n + 1
		GRID[key], GRID["SHIFT-" .. key] = HOT.plain .. n, HOT.bar .. n
		ROW[key], ROW["SHIFT-" .. key] = { HOT.plain, n }, { HOT.bar, n }
	end
end

-- A flyout's buttons in the order they are read: the top left first, then across, then down. The game says how a
-- bar is laid (isHorizontal, numRows, numButtonsShowable): a bar across fills its rows from the bottom up, an
-- upright one its columns from the left, each downward (its "rows" are then its columns). Buttons the bar
-- doesn't show come after, in their own order.  -> { id = the shape, [n] = the bar's nth button as read }; one
-- table a shape
HOT.shapes, HOT.frames = {}, { MULTIACTIONBAR4BUTTON = "MultiBarLeft", MULTIACTIONBAR3BUTTON = "MultiBarRight" }
local function Shape(bar)
	bar = rawget(_G, HOT.frames[bar]) or HOT
	local across = bar.isHorizontal == true
	local lines = type(bar.numRows) == "number" and math.max(1, bar.numRows) or 1
	local shown = type(bar.numButtonsShowable) == "number" and math.min(NUM_ACTIONBAR_BUTTONS, bar.numButtonsShowable) or NUM_ACTIONBAR_BUTTONS
	local id = (across and "a" or "u") .. lines .. "/" .. shown
	local at = HOT.shapes[id]
	if at then return at end
	local stride = math.floor((shown + lines - 1) / lines)
	local columns, rows = across and stride or lines, across and lines or stride
	at = { id = id }
	local taken, n = {}, 0
	for row = 1, rows do
		for column = 1, columns do
			local button = across and (rows - row) * stride + column or (column - 1) * stride + row
			if button <= shown then
				n = n + 1
				at[n], taken[button] = button, true
			end
		end
	end
	for button = 1, NUM_ACTIONBAR_BUTTONS do
		if not taken[button] then
			n = n + 1
			at[n] = button
		end
	end
	HOT.shapes[id] = at
	return at
end
Keys.Shape = Shape

-- A key's own button: the grid's; a key of the number row's by its flyout's shape.
local function Button(key)
	local row = ROW[key]
	if not row then return GRID[key] end
	return row[1] .. Shape(row[1])[row[2]]
end
for i, key in ipairs({ "Q", "W", "E", "R", "T", "BUTTON4", "BUTTON5", "SHIFT-Q", "SHIFT-W", "SHIFT-E", "SHIFT-R", "SHIFT-T" }) do
	GRID[key] = "ACTIONBUTTON" .. i
end
for i, key in ipairs({ "A", "S", "D", "F", "G", "SHIFT-BUTTON4", "SHIFT-BUTTON5", "SHIFT-A", "SHIFT-S", "SHIFT-D", "SHIFT-F", "SHIFT-G" }) do
	GRID[key] = "MULTIACTIONBAR1BUTTON" .. i
end
for i, key in ipairs({ "Z", "X", "C", "V", "B", "", "", "SHIFT-Z", "SHIFT-X", "SHIFT-C", "SHIFT-V", "SHIFT-B" }) do
	if key ~= "" then GRID[key] = "MULTIACTIONBAR2BUTTON" .. i end
end
Keys.GRID = GRID

-- How you move: as picked (the core's keysMove), else as your keys say (S moving you forward is ASDF).
function Keys.Scheme()
	local picked = Shy.core.db and Shy.core.db.keysMove
	if Keys.SCHEMES[picked] then return picked end
	for _, key in ipairs({ GetBindingKey("MOVEFORWARD") }) do
		if key == "S" then return "asdf" end
	end
	return "wasd"
end

local function Scheme() return Keys.SCHEMES[Keys.Scheme()] end

-- Whether a key is one you move with.
function Keys.Moving(key)
	return Scheme().move[key] == true
end

---------------------------------------------------------------------------
-- Your hotkeys: the keyboard bound as the bars draw it
---------------------------------------------------------------------------

-- A layout is made for a keyboard bound one way: every key of the grid on its own button, the keys you move with
-- moving you, and the number row apart from the hand's three bars, on the two flyouts: 1 to = the left one's
-- buttons, Shift + 1 to = the right one's, extra buttons for whatever you like (a class's jobs on the number row
-- stand there too, what you stay in on 1 2 3 among them). Most keyboards aren't bound so (the game's own has
-- 1 to = on the main bar and Q and E strafing), and a job whose key does something else can't stand. So the
-- hotkeys are a choice, "shy" (the board, recommended) or "own" (your keys as they are), made before anything
-- changes and undone whole:
--
--   Keys.Board(opts, scheme)   -> want (key -> binding), order (the keys as a hand meets them: plain, then Shift)
--   Keys.Mode()                "shy" or "own". Unpicked: "own" for keys laid out on your own before there was a
--                              choice, else "shy"
--   Keys.Hotkeys.Plan(opts)    what setting them would change now, with nothing done
--       -> { changes = { { key, from, to }, ... } (to "": let go), lose = { binding, ... } (what has a key now and
--            would have none), freed = { key, ... } (keys let go of a button that has its own), bar (the side bar is on) }
--   Keys.Hotkeys.Take(opts, quiet)   sets them, each key's old binding kept the first time it is changed, and a key
--                              that presses another key's button let go (kept too), so every button shows its own.
--                              A key set here and bound to something else by you since is yours: kept as it is
--                              from then on. quiet: only the keys set here before and still as set (the stance
--                              keys of another class on the same key bindings).
--                              -> { bound, cleared, kept } or nil, "combat"
--   Keys.Hotkeys.Back()        every key changed here is as it was, but one you have bound to something else
--                              since.  -> { put, kept, lost } or nil, "combat"
--   Keys.Hotkeys.On()          whether they are set, for the key bindings in use (the account's, or this character's own)
--   Keys.Hotkeys.Kept()        how many of your keys are kept from before, and when they were first set
--   Keys.Hotkeys.Yours(opts)   every key of yours that does something now (not a bar's button) the hotkeys take or
--                              would, a hand's first: { key, from, to, kept, move, must, also }
--   Keys.Hotkeys.Keep(key, on) / Keeps(key)   keeps a key as you have it, out of the board (its job left off);
--                              with the hotkeys set it is done at once.  -> true, or false in a fight
--
-- What a key did before the board took it moves to Ctrl + that key (Keys.Hotkeys.HomeOf: C's character window
-- to Ctrl + C, B's bags to Ctrl + B, Mouse 4's autorun to Ctrl + Mouse 4), while that does nothing yet; one home a
-- binding, and none for what moves you, turns the bar's pages or presses a button. A home is bound, kept and put
-- back like any key set here (it was nothing before), said in chat when it is made, and goes again when you keep
-- the key it came from. The plan's changes hold the homes too (from "": a free key), and plan.homes lists them.
--
-- A layout's hotkeys never take a key of yours unseen: the keys' panel lists each one before you choose, and a
-- chat command that would take one opens the panel instead (Keys.Run).
--
-- Until they are set, what is drawn before a layout (the keys at a level, a busy key) reads the keys as they
-- will be (Coming); a layout itself always reads them as they are (`live`).
--
--   Keys.Lay(addon, jobs, opts)   the hotkeys as picked, then Apply: what a player's "lay out my keys" does
--   Keys.Unlay(addon)          Revert, then the hotkeys back: every button and key as before
--   Keys.SetMode(mode)         picks; with keys laid out it is done at once (put back, the hotkeys switched,
--                              laid out again).  -> true, or false in a fight
--   Keys.Wanted()              whether this character's keys are laid out, or the open setup window means to
--                              (the bars are then all there, with the flyouts: nothing of a layout hides)
--
-- core.db.hotkeys (account-wide, kept through a reset and a change of profile) holds mode (the pick), keep (the
-- keys you keep as they are: key -> true) and sets: by the bindings in use ("account" or a character's GUID), was (each
-- key changed here -> what it did before, "" for nothing), set (-> what it was set to, "" for let go), on, at.

local Hot = {}
Keys.Hotkeys = Hot
Shy.core.keep.hotkeys = true
Hot.ButtonOf = Button        -- a key's own button (the grid's; the number row's by its flyout)
HOT.fixed = 2                -- what a set of hotkeys was last brought up to (state.homed): 1 gave the keys the board
                             -- took a home on Ctrl; 2 has the side keys strafe when the board takes every key that did

-- (The same keyboard gives the same two tables every time: they are read, never written. A board differs by the
-- way you move, what your two side keys do now, and the flyouts' shapes.)
HOT.order, HOT.boards, HOT.orders = {}, {}, {}
for _, shift in ipairs({ "", "SHIFT-" }) do
	for _, row in ipairs(HOT.rows) do
		for key in row:gmatch(".") do HOT.order[#HOT.order + 1] = shift .. key end
	end
	for _, key in ipairs(HOT.mouse) do HOT.order[#HOT.order + 1] = shift .. key end
end

-- Where each thing of the stance bar stands on it now: its name -> its place. nil while the game keeps the bar
-- secret (a fight): whoever asks keeps what it knew.
local function Stances()
	local at = {}
	for i = 1, GetNumShapeshiftForms() do
		local _, _, _, id = GetShapeshiftFormInfo(i)
		if id ~= nil and issecretvalue(id) then return nil end
		local name = id and C_Spell.GetSpellName(id)
		if name then at[name] = at[name] or i end
	end
	HOT.stances = at
	return at
end
Keys.Stances = Stances

-- The keys you keep as they are (core.db.hotkeys.keep: key -> true): the board leaves them out, so a job on one
-- is left off. nil for none.
local function Keeping()
	local book = Shy.core.db and Shy.core.db.hotkeys
	local keep = book and book.keep
	return keep and next(keep) ~= nil and keep or nil
end

-- "a, b and c", the first `most` of them and how many more.
local function Several(names, most)
	local shown = {}
	for i = 1, math.min(most, #names) do shown[i] = names[i] end
	local more = #names - #shown
	if more > 0 then return table.concat(shown, ", ") .. (" and %d more"):format(more) end
	if #shown < 2 then return shown[1] or "" end
	return table.concat(shown, ", ", 1, #shown - 1) .. " and " .. shown[#shown]
end

-- What a binding does, as you'd say it: the game's name for it, or the spell, item or macro of yours it names.
local function BindingCalled(command)
	local kind, name = command:match("^(%u+) (.+)$")
	if kind == "MACRO" then return "Macro " .. name end
	if kind == "CLICK" then return (name:gsub(":.*$", "")) end
	if kind then return name end
	return GetBindingName(command)
end
Keys.BindingCalled = BindingCalled

-- Whether a hand relies on what a binding does without looking (HOT.musts), or it is something of yours.
local function Must(command)
	return HOT.musts[command] == true or command:find("^%u+ ") ~= nil
end

-- Whether you can still strafe that way once the board is set: a key that strafes now and that the board leaves
-- as it is (one off the grid, or one you keep). keep: the keys you keep.
local function Strafes(command, way, keep)
	for _, key in ipairs({ GetBindingKey(command) }) do
		if not way.move[key] and (not GRID[key] or (keep and keep[key])) then return true end
	end
	return false
end

-- The keys you picked for a kept key's ability (core.db.hotkeys.standIn: kept key -> the key you picked), while
-- each still does nothing else: kept key -> key, and in order.  -> the table (nil for none), and the pairs as text
local function StandIns(way, keep)
	local book = keep and Shy.core.db and Shy.core.db.hotkeys
	local picked = book and book.standIn
	if not picked or not next(picked) then return nil, "" end
	local out, said, over = {}, {}, book.over or EMPTY
	for key, at in pairs(picked) do
		local button = keep[key] and GRID[key] and not way.move[key] and Button(key)
		local now = button and not GRID[at] and not way.move[at] and GetBindingAction(at)
		if now == "" or (now and (now == button or over[at] == now)) then
			out[key] = at
			said[#said + 1] = key .. ">" .. at
		end
	end
	table.sort(said)
	return #said > 0 and out or nil, table.concat(said, " ")
end
Hot.StandIns = StandIns

-- (whole: every key the board has a use for, the ones you keep with them)
-- Your side keys (A and D for WASD) do what they do now if it moves you sideways, else strafe; and they strafe
-- whenever the board takes every key you strafe with (Q and E as the game ships them), so you never lose it:
-- you turn with the mouse then. A key you keep whose ability you gave another key (the list's quick bind):
-- that key presses its button, after the board's own in the order.
function Keys.Board(opts, scheme, whole)
	scheme = scheme or Keys.Scheme()
	local way = Keys.SCHEMES[scheme]
	local keeping = Keeping()
	local sides = {}
	for i, side in ipairs({ way.left, way.right }) do
		local strafe = i == 1 and "STRAFELEFT" or "STRAFERIGHT"
		local now = GetBindingAction(side)
		sides[i] = (HOT.sides[now] and (now == strafe or Strafes(strafe, way, keeping))) and now or strafe
	end
	local left, right = sides[1], sides[2]
	-- (a key you keep stands out of the board; the keys you move with never do)
	local keep, kept = not whole and keeping, ""
	if keep then
		local list = {}
		for key in pairs(keep) do
			if GRID[key] and not way.move[key] then list[#list + 1] = key end
		end
		table.sort(list)
		kept = table.concat(list, " ")
	end
	local ins, said = StandIns(way, keep)
	local id = scheme .. "|" .. left .. "|" .. right .. "|" .. Shape(HOT.plain).id .. "|" .. Shape(HOT.bar).id .. "|" .. kept .. "|" .. said
	local want = HOT.boards[id]
	if not want then
		want = {}
		for key in pairs(GRID) do
			if not way.move[key] and not (keep and keep[key]) then want[key] = Button(key) end
		end
		want[way.forward], want[way.back], want[way.left], want[way.right] = "MOVEFORWARD", "MOVEBACKWARD", left, right
		local order = HOT.order
		if ins then
			order = {}
			for i, key in ipairs(HOT.order) do order[i] = key end
			for _, key in ipairs(HOT.order) do
				if ins[key] then
					want[ins[key]] = Button(key)
					order[#order + 1] = ins[key]
				end
			end
		end
		HOT.boards[id], HOT.orders[id] = want, order
	end
	return want, HOT.orders[id]
end

-- Whether both flyouts' bars are on (the game's switches of its side bars).
local function Flyouts()
	local on = { GetActionBarToggles() }
	for _, toggle in ipairs(HOT.toggles) do
		if not on[toggle] then return false end
	end
	return true
end

-- What the core keeps of the hotkeys, account-wide.
local function HotBook()
	local db = Shy.core.db
	if not db then return { sets = {} } end   -- (asked before the saved settings are in: nothing kept)
	db.hotkeys = db.hotkeys or {}
	db.hotkeys.sets, db.hotkeys.off = db.hotkeys.sets or {}, nil
	return db.hotkeys
end

-- What is kept for the key bindings in use.  -> state, its id
-- (Not one key set here is still as set: the key bindings were reset to the game's, or bound over whole. The
-- hotkeys are no longer set there, and what was kept of them goes: nothing is bound back over what you have.)
local function Lapsed(state)
	if not (state and state.on and next(state.set)) then return false end
	for key, ours in pairs(state.set) do
		if GetBindingAction(key) == ours then return false end
	end
	return true
end
local function HotState(make)
	local book = HotBook()
	local id = GetCurrentBindingSet() == Enum.BindingSet.Character and UnitGUID("player") or "account"
	local state = book.sets[id]
	if Lapsed(state) then
		book.sets[id], state = nil, nil
		Keys.gen = (Keys.gen or 0) + 1
	end
	if not state and make then
		state = { was = {}, set = {} }
		book.sets[id] = state
	end
	return state, id
end

function Hot.On()
	local state = HotState()
	return state ~= nil and state.on == true
end

function Hot.State()
	return (HotState())
end

-- (a home counts as none of yours: it did nothing before)
function Hot.Kept()
	local state = HotState()
	local homed = {}
	for _, home in pairs(state and state.homes or EMPTY) do homed[home] = true end
	local n = 0
	for key in pairs(state and state.set or EMPTY) do
		if not homed[key] then n = n + 1 end
	end
	return n, state and state.at
end

-- One key set (command "": let go), what it did before kept the first time. Set back to what it did before,
-- nothing is kept for it.  -> whether it changed
local function HotSet(state, key, command)
	local now = GetBindingAction(key)
	if now == command then return false end
	if not SetBinding(key, command ~= "" and command or nil) then return false end
	local was = state.was[key]
	if was == nil then was = now end
	if was == command then
		state.was[key], state.set[key] = nil, nil
	else
		state.was[key], state.set[key] = was, command
	end
	return true
end

-- A key set here that you have bound to something else since: yours, never taken again (Take keeps it).
local function Theirs(state, key)
	return state ~= nil and state.on == true and state.set[key] ~= nil and GetBindingAction(key) ~= state.set[key]
end

-- A button of the bars' picture: a key that presses one and isn't its own is let go, so each shows its key.
local function Pictured(command)
	return command:find("^ACTIONBUTTON%d") ~= nil or command:find("^MULTIACTIONBAR%dBUTTON%d") ~= nil
end

-- Whether a binding turns the main bar's pages: the layout keeps the bar on its own page, so it goes without a
-- home, and is said in one line rather than key by key.
function Hot.Paging(command)
	return command:find("ACTIONPAGE") ~= nil
end

-- Where what a key did goes when the board takes the key: Ctrl + that key (the character window from C to
-- Ctrl + C), so a hand finds it by the letter it knows. Only while Ctrl + the key does nothing (or that already),
-- one key a binding, and never what moves you, turns the bar's pages or presses a bar's button (its ability goes
-- with its key). taken: keys and bindings given a home already this time, filled in.  -> the key, or nil
-- The key you picked for it in the list comes first (core.db.hotkeys.homeAt: binding -> key), while it is still
-- free; else Ctrl + the key.
function Hot.HomeOf(key, command, taken)
	if command == "" or Pictured(command) or HOT.moving[command] or Hot.Paging(command) then return nil end
	if taken and taken[command] then return nil end
	local book = Shy.core.db and Shy.core.db.hotkeys
	local picked = book and book.homeAt and book.homeAt[command]
	local over = book and book.over
	for _, home in ipairs({ picked or false, HOT.home .. key }) do
		local now = home and not (taken and taken[home]) and not Keys.Moving(home) and GetBindingAction(home)
		-- (the key you picked may do something else, while it is still what you said it could stop doing)
		if now == "" or now == command or (now and home == picked and over and over[home] == now) then
			if taken then taken[home], taken[command] = true, true end
			return home
		end
	end
end

-- What you picked in the list, account-wide beside the keys you keep: homeAt (a binding -> the key it goes to),
-- standIn (a key you keep -> the key its ability goes on) and over (a key you said may be taken from what it did:
-- the key -> what it did then; while it still does that, it is free to pick).
function Hot.Choices()
	local book = HotBook()
	book.homeAt, book.standIn, book.over = book.homeAt or {}, book.standIn or {}, book.over or {}
	return book
end

-- A key you bound to something else yourself after it was set here: yours.
function Hot.Mine(key)
	return Theirs(HotState(), key)
end

-- Whether a key can be picked in the list for `does` (a binding going to a new home, or the button of `kept`, the
-- key you keep, for its ability): the left and right mouse buttons never, nor a key you move with or one of the
-- board's; and one picked for something else, or that does something else now, only once you are sure.
--   -> true, or false and why, said on the row; and when you can have it once you are sure, the question:
--   { text, yes (the button's words), homeAt (the binding picked for it), standIn (the kept key picked for it),
--   over (what it does now) }, for Hot.TakeOver
function Hot.Free(key, does, kept)
	if not key or key == "" then return false, "" end
	local said = Keys.Key(key)
	if key == "BUTTON1" or key == "BUTTON2" then return false, "Your left and right mouse buttons stay as they are." end
	if Keys.Moving(key) then return false, said .. " moves you. Pick another key." end
	if Keys.Board(nil, nil, true)[key] and not Hot.Keeps(key) then
		return false, said .. " is one of your new keys. Pick one off them, like Ctrl + a key."
	end
	local book = Hot.Choices()
	local here = kept and ("%s's ability"):format(Keys.Key(kept)) or BindingCalled(does)
	local yes = "Use " .. said
	for command, at in pairs(book.homeAt) do
		if at == key and command ~= does then
			local why = ("%s is picked for %s already."):format(said, BindingCalled(command))
			return false, why, { text = ("%s Use it for %s instead?"):format(why, here), yes = yes, homeAt = command }
		end
	end
	for other, at in pairs(book.standIn) do
		if at == key and other ~= kept then
			local why = ("%s is picked for %s's ability already."):format(said, Keys.Key(other))
			return false, why, { text = ("%s Use it for %s instead?"):format(why, here), yes = yes, standIn = other }
		end
	end
	local now = GetBindingAction(key)
	if now ~= "" and now ~= does and book.over[key] ~= now then
		local name = BindingCalled(now)
		local left = false            -- (another key does it too: it keeps that one)
		for _, other in ipairs({ GetBindingKey(now) }) do
			if other ~= key then left = true end
		end
		-- (a kept key's ability: what the key did goes to Ctrl + it, as with the board's keys)
		local home = not left and kept and Hot.HomeOf(key, now)
		local text = ("%s does %s. Use it for %s instead?"):format(said, name, here)
		if left then
			text = ("%s %s stays on its other key."):format(text, name)
		elseif home then
			text = ("%s %s moves to %s."):format(text, name, Keys.Key(home))
		else
			text = ("%s %s is left without a key."):format(text, name)
		end
		return false, ("%s does %s. Pick a key that does nothing yet."):format(said, name),
			{ text = text, yes = yes, over = now }
	end
	return true
end

-- You are sure: the key Hot.Free asked about is yours to pick. What it does now may be bound over (put back
-- whenever the pick or the hotkeys go), or the pick it had lets it go. Then pick it again.  -> true, or false and why
function Hot.TakeOver(key, ask, defer)
	if InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	if ask.over then
		Hot.Choices().over[key] = ask.over
	elseif ask.standIn then
		return Hot.SetStandIn(ask.standIn, nil, defer)
	elseif ask.homeAt then
		-- (the key of yours that did it: where Ctrl + that key is its place again)
		local mine = Keys.Mine()
		for _, entry in ipairs(mine and Hot.Yours(mine.opts) or EMPTY) do
			if entry.from == ask.homeAt then return Hot.SetHome(entry.key, ask.homeAt, nil, defer) end
		end
		Hot.Choices().homeAt[ask.homeAt] = nil
		Keys.gen = Keys.gen + 1
	end
	return true
end

-- What a list of homes says in chat: "Character Info (Ctrl + C) and Open All Bags (Ctrl + B)".
function Hot.Homes(homes)
	local names = {}
	for i, entry in ipairs(homes) do names[i] = ("%s (%s)"):format(BindingCalled(entry.command), Keys.Key(entry.home)) end
	return Several(names, HOT.named)
end

-- The keys that press another key's button, for every button the board gives a key: fn(key, the button's binding).
-- (a key you keep is never let go)
local function Others(want, keep, command, fn, ...)
	for i = 1, select("#", ...) do
		local other = select(i, ...)
		if want[other] == nil and not keep[other] then fn(other, command) end
	end
end
local function Strays(want, order, fn)
	local seen, keep = {}, Keeping() or EMPTY
	for _, key in ipairs(order) do
		local command = want[key]
		if command and Pictured(command) and not seen[command] then
			seen[command] = true
			Others(want, keep, command, fn, GetBindingKey(command))
		end
	end
end

-- (Worked out once a frame for a state, whoever asks: the sentence, the caps' marks, setup's line.)
function Hot.Plan(opts)
	local want, order = Keys.Board(opts)
	local kept = HOT.plan
	if kept and kept.want == want and kept.at == GetTime() and kept.gen == Keys.gen then
		kept.bar = Flyouts()   -- (a bar switched on or off says nothing)
		return kept
	end
	local plan = { changes = {}, lose = {}, freed = {}, homes = {}, want = want, order = order, at = GetTime(), gen = Keys.gen }
	HOT.plan = plan
	local after = {}             -- the keys that change -> what each does then
	local state = HotState()
	local taken, homed = {}, {}
	for _, key in ipairs(order) do
		local to = want[key]
		local from = to and GetBindingAction(key)
		if to and from ~= to and not Theirs(state, key) then
			plan.changes[#plan.changes + 1] = { key = key, from = from, to = to }
			after[key] = to
			local home = Hot.HomeOf(key, from, taken)
			if home then
				plan.homes[#plan.homes + 1] = { key = key, home = home, command = from }
				homed[from] = true
			end
		end
	end
	Strays(want, order, function(key, command)
		plan.changes[#plan.changes + 1] = { key = key, from = command, to = "" }
		plan.freed[#plan.freed + 1] = key
		after[key] = ""
	end)
	for _, entry in ipairs(plan.homes) do
		if GetBindingAction(entry.home) ~= entry.command then
			-- (a home you picked over something it did: that changes, and is said with the rest)
			plan.changes[#plan.changes + 1] = { key = entry.home, from = GetBindingAction(entry.home), to = entry.command, home = entry.key }
			after[entry.home] = entry.command
		end
	end
	-- What has a key now and would have none: nothing the board itself gives a key, nothing with a key left, and
	-- no button of a bar (the ones under the keys you move with are clicked, as the board means them to be).
	local held, asked = {}, {}
	for _, command in pairs(want) do held[command] = true end
	for _, change in ipairs(plan.changes) do
		local from = change.from
		if from ~= "" and not held[from] and not homed[from] and not asked[from] and not Pictured(from) then
			asked[from] = true
			local left = false
			for _, key in ipairs({ GetBindingKey(from) }) do
				if after[key] == nil then left = true end
			end
			if not left then plan.lose[#plan.lose + 1] = from end
		end
	end
	plan.bar = Flyouts()
	return plan
end

function Hot.Take(opts, quiet)
	if InCombatLockdown() then return nil, "combat" end
	local result = { bound = 0, cleared = 0, kept = 0 }
	local state = HotState(not quiet)
	if not state or (quiet and not state.on) then return result end
	local want, order = Keys.Board(opts)
	local homes, taken = {}, {}
	-- Set before what a set is brought up to now (quiet too: it is the next log-in): once, the side keys strafe
	-- where the board took every key that did, and every key still as set here gives what it did a home.
	local fixing = state.on == true and (tonumber(state.homed) or (state.homed and 1) or 0) < HOT.fixed
	local way = Scheme()
	local book = HotBook()
	local picked = {}            -- the keys picked for a kept key's ability -> that key
	for kept, at in pairs(book.standIn or EMPTY) do picked[at] = kept end
	for _, key in ipairs(order) do
		local command = want[key]
		if command and not quiet and Theirs(state, key) then
			if picked[key] then
				-- (the key you picked for an ability, bound to something else since or let go: the pick goes)
				book.standIn[picked[key]], state.was[key], state.set[key] = nil, nil, nil
				if book.over then book.over[key] = nil end
			else
				-- (bound to something else by you since it was set here: yours from now on, kept as it is)
				book.keep = book.keep or {}
				book.keep[key], state.was[key], state.set[key] = true, nil, nil
			end
			result.kept = result.kept + 1
		else
			-- (quiet: a key is ours only while it is still as it was set here; or a side key, brought up to date)
			local side = fixing and (key == way.left or key == way.right) and HOT.sides[GetBindingAction(key)]
			local ours = not quiet or side or (state.set[key] ~= nil and GetBindingAction(key) == state.set[key])
			local now = GetBindingAction(key)
			if command and ours and HotSet(state, key, command) then
				result.bound = result.bound + 1
				if HOT.steer[command] and HOT.steer[command] == now then
					result.strafe = (result.strafe and (result.strafe .. " and ") or "") .. Keys.Key(key)
				end
				local home = not quiet and Hot.HomeOf(key, now, taken)
				if home then homes[#homes + 1] = { key = key, home = home, command = now } end
			end
		end
	end
	if fixing then
		for _, key in ipairs(order) do
			local was = state.was[key]
			if state.set[key] ~= nil and GetBindingAction(key) == state.set[key] and was and was ~= "" then
				local home = Hot.HomeOf(key, was, taken)
				if home then homes[#homes + 1] = { key = key, home = home, command = was } end
			end
		end
	end
	if not quiet then
		-- (a key that became yours just now leaves the board first; and once the keys are set, a key you bound to
		-- a button yourself since is yours: only the game's keys from before are let go)
		if result.kept > 0 then want, order = Keys.Board(opts) end
		local before = state.on == true
		Strays(want, order, function(key)
			if before and state.set[key] == nil then return end
			if HotSet(state, key, "") then result.cleared = result.cleared + 1 end
		end)
		state.on, state.at = true, state.at or time()
	end
	-- What the board took moves to Ctrl + its key (one of yours bound there since is never touched).
	local made, homed = {}, 0
	if state.on then
		state.homes, state.homed = state.homes or {}, HOT.fixed
		for _, entry in ipairs(homes) do
			local there = GetBindingAction(entry.home) == entry.command
			if there or HotSet(state, entry.home, entry.command) then
				state.homes[entry.key] = entry.home
				made[#made + 1] = entry
				if not there then homed = homed + 1 end
			end
		end
		if #made > 0 then
			Shy.core:Print(("nothing of yours is lost. On new keys now: %s. /shy keys lists every key that changed."):format(Hot.Homes(made)))
		end
		if result.strafe then
			Shy.core:Print(("%s strafe now, since the keys you strafed with hold abilities. To turn, hold the right mouse button and move the mouse."):format(result.strafe))
		end
	end
	result.homes = made
	if result.bound + result.cleared + homed > 0 then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	return result
end

function Hot.Back()
	if InCombatLockdown() then return nil, "combat" end
	local result = { put = 0, kept = 0, lost = 0 }
	local state, id = HotState()
	if not state then return result end
	local left = { was = {}, set = {} }   -- a key the game wouldn't take back stays kept, to be put back yet
	for key, ours in pairs(state.set) do
		local was = state.was[key] or ""
		if GetBindingAction(key) ~= ours then
			result.kept = result.kept + 1     -- bound to something else by you since: yours
		elseif SetBinding(key, was ~= "" and was or nil) then
			result.put = result.put + 1
		else
			result.lost = result.lost + 1
			left.was[key], left.set[key] = was, ours
		end
	end
	HotBook().sets[id] = result.lost > 0 and left or nil
	if result.put > 0 then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	return result
end

-- Whether you keep a key as it is.
function Hot.Keeps(key)
	local keep = Keeping()
	return keep ~= nil and keep[key] == true
end

-- Keeps a key as it is, or lets the hotkeys have it. With the hotkeys set it is done now: the key back as it was
-- (only while it is still as set here) or set, and keys laid out are laid out again around it.
--   -> true, or false in a fight. defer: only noted, nothing bound (setup's page: Finish does it)
function Hot.Keep(key, on, defer)
	on = on and true or nil
	if (Hot.Keeps(key) or nil) == on then return true end
	local state = HotState()
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false end
	local book = Hot.Choices()
	book.keep = book.keep or {}
	book.keep[key] = on
	if not on then book.standIn[key] = nil end   -- (the board's again: its ability on it, no other key for it; Take lets that one go)
	local mine = watched[1]
	local laid = set and mine ~= nil and Keys.Has(mine.addon)
	if laid then Keys.Revert(mine.addon) end
	if not on and Theirs(state, key) then
		state.was[key], state.set[key] = nil, nil   -- (bound since: what it does now is what goes back)
	end
	if set and on and state.set[key] ~= nil and GetBindingAction(key) == state.set[key] then
		local was = state.was[key] or ""
		if SetBinding(key, was ~= "" and was or nil) then
			state.was[key], state.set[key] = nil, nil
			-- (back on its key, it leaves Ctrl + the key: while that is still as it was set here)
			local home = state.homes and state.homes[key]
			if home then
				state.homes[key] = nil
				if state.set[home] ~= nil and GetBindingAction(home) == state.set[home] then
					local before = state.was[home] or ""
					if SetBinding(home, before ~= "" and before or nil) then state.was[home], state.set[home] = nil, nil end
				end
			end
			SaveBindings(GetCurrentBindingSet())
		end
	elseif set and not on then
		Hot.Take(mine and mine.opts)
	end
	Keys.gen = Keys.gen + 1
	if laid then
		local result = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if result then mine.waiting = result.waiting end
	end
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- One binding of the hotkeys' own put back as it was, while it is still as set here.
local function HotUnset(state, key)
	if not (state and state.set[key] ~= nil and GetBindingAction(key) == state.set[key]) then return false end
	local was = state.was[key] or ""
	if not SetBinding(key, was ~= "" and was or nil) then return false end
	state.was[key], state.set[key] = nil, nil
	return true
end

-- Picks the key what `key` did goes to (command: what it did), or nil for Ctrl + the key again. With the
-- hotkeys set it moves at once: off the key it was on (while that is as set here), onto the new one.
--   -> true, or false and why (a key that can't be picked, or a fight), and Hot.Free's question when there is one
function Hot.SetHome(key, command, at, defer)
	if at == HOT.home .. key then at = nil end
	if at then
		local free, why, ask = Hot.Free(at, command)
		if not free then return false, why, ask end
	end
	local state = HotState()
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	local book = Hot.Choices()
	local was = book.homeAt[command]
	if was and was ~= at then book.over[was] = nil end   -- (a key you let go of is asked about again)
	book.homeAt[command] = at
	if set then
		state.homes = state.homes or {}
		local old = state.homes[key]
		if old then HotUnset(state, old) end
		state.homes[key] = nil
		local home = Hot.HomeOf(key, command, {})
		if home and (GetBindingAction(home) == command or HotSet(state, home, command)) then state.homes[key] = home end
		SaveBindings(GetCurrentBindingSet())
	end
	Keys.gen = Keys.gen + 1
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- Picks the key a kept key's ability goes on (nil: none, the ability left off). With the hotkeys set it is done
-- now: the key you picked before let go, the new one set to the kept key's button, and keys laid out are laid out
-- again on it.  -> true, or false and why, and Hot.Free's question when there is one
function Hot.SetStandIn(key, at, defer)
	local button = Hot.ButtonOf(key)
	if not button then return false, "" end
	if at then
		local free, why, ask = Hot.Free(at, button, key)
		if not free then return false, why, ask end
	end
	local state = HotState()
	local set = not defer and state ~= nil and state.on == true and Keys.Mode() == "shy"
	if set and InCombatLockdown() then return false, "Your keys can be changed once the fight is over." end
	-- (an ability on another key: its own key is one you keep, back as you had it)
	if not Hot.Keeps(key) and not Hot.Keep(key, true, defer) then return false, "Your keys can be changed once the fight is over." end
	local book = Hot.Choices()
	local mine = watched[1]
	local laid = set and mine ~= nil and Keys.Has(mine.addon)
	if laid then Keys.Revert(mine.addon) end
	local old = book.standIn[key]
	if old and old ~= at then book.over[old] = nil end   -- (a key you let go of is asked about again)
	book.standIn[key] = at
	if set and old and old ~= at and HotUnset(state, old) then SaveBindings(GetCurrentBindingSet()) end
	Keys.gen = Keys.gen + 1
	if set then Hot.Take(mine and mine.opts) end
	if laid then
		local result = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if result then mine.waiting = result.waiting end
	end
	Shy:Fire("SHY_KEYS_MODE", Keys.Mode())
	return true
end

-- Every key of yours the hotkeys take, or would: one that does something of the game's or of yours now (not a
-- bar's button, whose ability goes wherever its key does, and not nothing), the ones a hand relies on first, then
-- as a hand meets them. Each { key, from (what it does, or did before it was set here), to (what the board
-- gives it), kept (it stays as it is), move (a key you move with: the board's whatever you keep), must (a hand
-- relies on it), also (another key that does it then, or nil), home (Ctrl + the key, where it goes or went, or
-- nil), paging (it turns the bar's pages: said in one line, after the rest) }.
function Hot.Yours(opts)
	local whole, order = Keys.Board(opts, nil, true)
	local keep, state, move = Keeping() or EMPTY, HotState(), Scheme().move
	local on = state ~= nil and state.on == true
	local homes, taken = state and state.homes or EMPTY, {}
	-- (a key the board changes yet: not while the hotkeys are set, when every change is made)
	local function Changes(key)
		local to = whole[key]
		return not on and to ~= nil and GetBindingAction(key) ~= to and not (keep[key] and not move[key])
	end
	local out = {}
	for i, key in ipairs(order) do
		local to, now = whole[key], GetBindingAction(key)
		local from, kept
		local pending              -- (noted on setup's page, not done yet: Finish does it)
		if on and state.set[key] ~= nil and now == state.set[key] then
			from = state.was[key] or ""
			if keep[key] and not move[key] then kept, pending = true, true end
		elseif (keep[key] and not move[key]) or Theirs(state, key) then
			from, kept = now, true
		elseif not on and now ~= to then
			from = now
		end
		if from and from ~= to and from ~= "" and not Pictured(from) then
			local also
			for _, other in ipairs({ GetBindingKey(from) }) do
				-- (its own new key isn't another: the row stays where it is as you switch it)
				if other ~= key and other ~= homes[key] and not Changes(other) then
					also = other
					break
				end
			end
			-- (or a key the board gives it: A strafing once Q is the board's)
			for _, other in ipairs(order) do
				if not also and other ~= key and whole[other] == from and not (keep[other] and not move[other]) then also = other end
			end
			local home
			if on and not kept then
				home = homes[key]
				if home and GetBindingAction(home) ~= from then home = nil end
				-- (another key picked for it since, not bound yet: the one it will have)
				local book = Shy.core.db and Shy.core.db.hotkeys
				local picked = book and book.homeAt and book.homeAt[from]
				if picked and picked ~= home and (GetBindingAction(picked) == "" or GetBindingAction(picked) == from) then
					home, pending = picked, true
				end
			elseif not kept then
				home = Hot.HomeOf(key, from, taken)
			end
			-- (a key you keep: the key you picked for its ability, while it stands)
			local ins = kept and StandIns(Scheme(), keep)
			out[#out + 1] = { key = key, from = from, to = to, kept = kept == true, move = move[key] == true,
				must = Must(from), also = also, home = home, standIn = ins and ins[key] or nil,
				paging = Hot.Paging(from), pending = pending, at = i }
		end
	end
	table.sort(out, function(a, b)
		if a.paging ~= b.paging then return b.paging end
		if a.must ~= b.must then return a.must end
		return a.at < b.at
	end)
	return out
end

function Keys.Mode()
	local picked = HotBook().mode
	if picked == "shy" or picked == "own" then return picked end
	local mine = watched[1]
	if mine and Keys.Has(mine.addon) and not Hot.On() then return "own" end
	return "shy"
end

-- The hotkeys a page draws the keys for, whatever is set: "shy" (the board) or "own" (yours: as they are, or
-- as they were before the board was set), or nil for the ones that stand. Setup's pick before Finish, and
-- either choice while the mouse is on it: you see both before you choose.
function Keys.Pretend(mode)
	if HOT.pretend == mode then return end
	HOT.pretend = mode
	Keys.look = Keys.look + 1   -- (what is drawn is drawn again; the keys themselves haven't changed)
end
Keys.look = 0

-- Which hotkeys the keys are drawn for, and whether those are the ones bound now.
function Keys.Shown()
	local shown = HOT.pretend or Keys.Mode()
	return shown, (shown == "shy") == Hot.On()
end

-- Your own keys while the board is set: every key changed here and still as set -> what it did before ("": nothing).
function Hot.Was()
	local state = HotState()
	local was = {}
	for key, ours in pairs(state and state.set or {}) do
		if GetBindingAction(key) == ours then was[key] = state.was[key] or "" end
	end
	return was
end

-- The keys that are drawn other than as they are bound now: the board, while it is the pick (or asked for) and
-- not set yet; your own as they were, asked for while the board is set. Nothing of it while keys are laid out
-- and nothing is asked for: those are drawn as they stand. Worked out once a frame for a state: every key a
-- layout is drawn for asks.
local live = false           -- a layout is being made: the keys are read as they are
local function Coming()
	if live then return nil end
	-- (asked for every key of every level a story lays out: nothing is made to answer)
	local at, move = GetTime(), Shy.core.db and Shy.core.db.keysMove
	if HOT.at ~= at or HOT.gen ~= Keys.gen or HOT.look ~= Keys.look or HOT.move ~= move then
		HOT.at, HOT.gen, HOT.look, HOT.move = at, Keys.gen, Keys.look, move
		local mine = watched[1]
		local shown = HOT.pretend or Keys.Mode()
		local map = false
		if shown == "shy" then
			if not Hot.On() and (HOT.pretend or not (mine and Keys.Has(mine.addon))) then map = Keys.Board(mine and mine.opts) end
		elseif Hot.On() then
			map = Hot.Was()
		end
		HOT.coming = map
	end
	return HOT.coming or nil
end

-- What a key does: as it is bound, or as the hotkeys drawn have it.
local function Action(key)
	local coming = Coming()
	local command = coming and coming[key]
	if command ~= nil then return command end
	return GetBindingAction(key)
end
Keys.Doing = Action

-- The button a key presses, or would once bound to its own (it presses nothing, isn't one you move with, and
-- its button has no other key): the binding's name, and true when it would have to be bound first.
-- Another key that presses a button (or will, as the keys are drawn), not `except`.  -> the key, or nil
function Hot.Pressed(button, except)
	local coming = Coming()
	for k, command in pairs(coming or EMPTY) do
		if command == button and k ~= except then return k end
	end
	for _, k in ipairs({ GetBindingKey(button) }) do
		if k ~= except and (not coming or coming[k] == nil or coming[k] == button) then return k end
	end
end

-- A key you keep, or bound to something else yourself since it was set here, is never bound again. Its ability
-- stands on the key's own button while another key presses it: the one you picked for it, or one you bound
-- there yourself, so where you put it is where it stays.
local function Pressable(key, opts, spare)
	local command = Action(key)
	if command ~= "" and Slots(command, opts) then return command end
	local own = Hot.ButtonOf(key)
	if own and Keys.Mode() == "shy" and (Hot.Keeps(key) or Hot.Mine(key)) then
		return Hot.Pressed(own, key) and Slots(own, opts) and own or nil
	end
	if command ~= "" then return nil end
	if Keys.Moving(key) or Hot.Keeps(key) then return nil end   -- (one you keep does nothing, as you have it)
	-- (its own: the grid's, the number row's by its flyout's shape; or its job's spare)
	local want = Button(key) or spare
	if want and not GetBindingKey(want) then return want, true end
end

-- The button a job's key presses as the keys are bound now: its binding's; or, for a key you keep or bound to
-- something else since, its own button while another key of yours presses it. "" for none.
function Hot.Pressing(key, opts)
	local command = GetBindingAction(key)
	if command ~= "" and Slots(command, opts) then return command end
	local own = Hot.ButtonOf(key)
	if own and Keys.Mode() == "shy" and (Hot.Keeps(key) or Hot.Mine(key)) and Hot.Pressed(own, key) then return own end
	return ""
end

-- The key a seat's ability is pressed with: the seat itself, or the key of yours that presses its button.
function Hot.KeyFor(seat, opts)
	local own = Hot.Pressing(seat, opts)
	if own ~= "" and own ~= GetBindingAction(seat) then return Hot.Pressed(own, seat) or seat end
	return seat
end

-- The button a key presses, binding it to its own (or the job's spare) when it presses nothing.
--   -> the binding's name or nil, and true when a key was bound
-- A layout made for your keys set up, on key bindings where they aren't set (reset to the game's, or a
-- character's own switched to): it waits, nothing moved or bound, until you set them up there or put it back.
function Keys.Paused(addon)
	return Keys.Has(addon) and HotBook().mode == "shy" and not Hot.On()
end

-- Whether a layout may bind a key of yours that does nothing: where you chose it (your hotkeys set up on these key
-- bindings, or your own hotkeys picked), or on the key bindings it was first laid out on. Never on others you
-- switched to since (a character's own, as the game ships them): nothing is bound there until you choose.
function Hot.MayBind(before)
	if Hot.On() or HotBook().mode == "own" then return true end
	local _, id = HotState()
	return before ~= nil and before.set ~= nil and before.set == id
end

local function Press(key, opts, before, spare)
	local command, unbound = Pressable(key, opts, spare)
	if not unbound then return command end
	if not Hot.MayBind(before) then return nil end
	if SetBinding(key, command) then
		before.keys[key] = command
		return command, true
	end
end

local function Button(job, opts, before)
	return Press(job.key, opts, before, job.spare)
end

-- A macro is put on a button by its name, found as it is put: the game keeps a character's macros in the order of
-- their names, so making one moves every one after it, and a place noted before that names another macro.
-- What stood on a button is kept the first time a job takes it.  -> what was kept just now, if anything stood there
-- On a button a job took before, something you have put there since is yours too (-> it, and true): it is not
-- what the button goes back to, but it isn't lost either.
local function Keep(slot, before, made)
	local kind, id = GetActionInfo(slot)
	if before.slots[slot] ~= nil then
		if kind == "macro" then
			local text = C_ActionBar.GetActionText(slot)
			if text and not made[text] then return { kind, text }, true end
		elseif kind then
			for name in pairs(before.last) do
				if made[name] and Owns(name, before, kind, id) then return nil end   -- (one of ours)
			end
			return { kind, id }, true
		end
		return nil
	end
	local held = false
	if kind == "macro" then
		local text = C_ActionBar.GetActionText(slot)
		if text and not made[text] then held = { kind, text } end   -- one of ours from before isn't the player's
	elseif kind then
		held = { kind, id }
	end
	before.slots[slot] = held
	return held or nil
end

-- A job is put on a button: its macro, or the item it stands as. `taken` gathers what of yours stood there.
-- `owned`: the buttons each job already stood on (slot -> its name): what such a button holds is the job's own,
-- an item it held before, and nothing of yours to keep.
local function Put(job, slot, before, made, taken, owned)
	local name = job.name
	if Solid(job) then
		local item = before.last[name]
		if not item then return end
		local kind, id = GetActionInfo(slot)
		local same = kind == Sort(name, before) and id == item
		if not (owned and owned[slot] == name) then
			-- (yours, even when it is the very item: it is put back there when the keys are)
			local held, later = Keep(slot, before, made)
			if held and taken and not same then taken[#taken + 1] = { slot = slot, held = held, later = later } end
		end
		if same then return end
		if job.spell then C_Spell.PickupSpell(item) else C_Item.PickupItem(item) end
		if GetCursorInfo() then PlaceAction(slot) end   -- (none left to pick up: the button keeps the one it shows)
		ClearCursor()
		return
	end
	if C_ActionBar.GetActionText(slot) == name then return end
	local index = Find(name, Where(name, before))
	if not index then return end
	local held, later = Keep(slot, before, made)
	if held and taken then taken[#taken + 1] = { slot = slot, held = held, later = later } end
	PickupMacro(index)
	PlaceAction(slot)
	ClearCursor()
end

-- Whether a button holds that very thing of yours ({ kind, id }: a spell or an item by ID, a macro by name).
local function Holds(slot, held)
	local kind, id = GetActionInfo(slot)
	if kind ~= held[1] then return false end
	if kind == "macro" then return C_ActionBar.GetActionText(slot) == held[2] end
	return id == held[2]
end

-- Something of yours a job moved to a free button leaves it again: it is about to stand where it was.
local function Unhome(slot, before)
	local held = before.slots[slot]
	for home, from in pairs(before.homes) do
		if from == slot then
			if held and Holds(home, held) then
				PickupAction(home)
				ClearCursor()
			end
			before.homes[home] = nil
		end
	end
end

-- Puts back on a button what stood there before (a spell or an item by its ID, a macro by its name).
--   -> whether it could be found
local function Restore(slot, held)
	local kind, id = held[1], held[2]
	if kind == "spell" then
		C_Spell.PickupSpell(id)
	elseif kind == "item" then
		C_Item.PickupItem(id)
	elseif kind == "macro" then
		local index = Find(id, true)
		if index then PickupMacro(index) end
	end
	local found = GetCursorInfo() ~= nil
	if found then PlaceAction(slot) end
	ClearCursor()
	return found
end

-- Where each job stands now.  -> seats (job -> key), waits (the jobs with no seat, in order), and the
-- abilities that now stand on a key (name -> true)
-- A job with something to do stands on its own key. An ability stands on one key: a job that could only cast
-- what earlier jobs already have waits for something of its own (Rend's key while Rend is still what the
-- strike's key falls back to). Then what you can press gets the best place it can have: an easy key whose own job
-- isn't learned yet takes a job from a key that needs Shift or a reach, the one of its own letter first (Shift +
-- Q's comes to Q), else the next in order; that job goes home when the key's own arrives. A job from the bags stays where it is (and keeps its
-- key while its macro still names what it last held: the button shows what to buy).
local KeyOf                  -- (the key that presses a button: below)
local function Seat(jobs, opts, made, best, learns, known, pinned, last)
	pinned = pinned or {}    -- (a job you moved stays where you put it: it takes no other key)
	local seats, waits, abilities, stays = {}, {}, {}, {}
	for _, job in ipairs(jobs) do
		local ready, does = Ready(job, best, learns, known, opts.shifts)
		if ready and does and not job.supply and job.shared ~= true then
			local taken = job.shared == "stays" and stays or abilities
			local own = false
			for _, name in ipairs(does) do
				if not taken[name] then own = true end
			end
			if own then
				for _, name in ipairs(does) do taken[name] = true end
			else
				ready = false
			end
		end
		if not ready and job.supply and made[job.name] then
			if job.item then
				ready = last ~= nil and last[job.name] ~= nil   -- (the item it last held is still on its button)
			else
				local index, text = Find(job.name)
				if not index then index, text = Find(job.name, "account") end   -- (made among the account's)
				ready = index ~= nil and (text:find("/use ", 1, true) ~= nil or text:find("/castsequence ", 1, true) ~= nil)
			end
		end
		if not job.key then
			-- (no key the way you move: it stands nowhere, and Apply says so)
		elseif ready then
			seats[job] = job.key
		else
			waits[#waits + 1] = job
		end
	end
	local prime, home = {}, {}
	local PRIME = Scheme().prime
	for _, key in ipairs(PRIME) do prime[key] = true end
	for _, job in ipairs(jobs) do
		if job.key then home[job.key] = job end
	end
	-- Prime keys whose own job isn't learned yet, and that press a button (or can): a better place, meanwhile, for
	-- a job you can press that waits behind Shift or a reach. (A key with no job of its own isn't filled: keys
	-- are placed for the fingers and the rotation, never filled for their own sake.)
	local free = {}
	for _, key in ipairs(PRIME) do
		if home[key] and not seats[home[key]] and Pressable(key, opts) then free[#free + 1] = key end
	end
	local function Take(job, at)
		seats[job] = table.remove(free, at)
	end
	-- A job that made way for another on an easy key (job.early: the key) stands there until that one arrives.
	for _, job in ipairs(jobs) do
		if job.early and seats[job] == job.key and not job.supply and not pinned[job.name] then
			for at, key in ipairs(free) do
				if key == job.early then
					Take(job, at)
					break
				end
			end
		end
	end
	for pass = 1, 2 do
		for _, job in ipairs(jobs) do
			-- (a job with `stay` never stands in: one a slip on an easy key would do harm with, a summon over your pet)
			if #free > 0 and job.key and seats[job] == job.key and not prime[job.key] and not job.supply and not job.stay and not pinned[job.name] then
				local letter = job.key:match("^SHIFT%-(.+)$")
				for at, key in ipairs(free) do
					if pass == 2 or key == letter then
						Take(job, at)
						break
					end
				end
			end
		end
	end
	-- An ability you moved onto another job's key: that job takes the key yours left, a swap, now or when it is
	-- learned (never left with no key because you moved another).
	for _, job in ipairs(jobs) do
		local at = pinned[job.name]
		local key = at and #at > 0 and seats[job] and KeyOf(at, opts)
		if key and key ~= seats[job] then
			local left, free = seats[job], true
			for other, seat in pairs(seats) do
				if other ~= job and seat == left then free = false end
			end
			for other, seat in pairs(seats) do
				if free and other ~= job and seat == key and not pinned[other.name] then
					seats[other], free = left, false
				end
			end
		end
	end
	return seats, waits, taken
end

-- Empties a button of a macro made here that no longer stands there: what stood there before comes back.
local function Empty(slot, before, made)
	local text = C_ActionBar.GetActionText(slot)
	if text then
		if not made[text] then return end      -- a macro of the player's own
		PickupAction(slot)
		ClearCursor()
	else
		local kind, id = GetActionInfo(slot)
		local ours = false
		-- (an item one of our jobs stands as, on a button a job took before: one of yours of that kind on a
		-- button no job ever took is tidied with the rest, and remembered)
		if (kind == "item" or kind == "spell") and before.slots[slot] ~= nil then
			for name in pairs(before.last) do
				if made[name] and Owns(name, before, kind, id) then ours = true end
			end
		end
		if ours then
			PickupAction(slot)
			ClearCursor()
		elseif kind then
			return                             -- something else of the player's
		end
	end
	local held = before.slots[slot]
	if held and held[3] then return end        -- tidied away: it comes back with the rest, not before
	if held then
		Unhome(slot, before)
		Restore(slot, held)
	end
	before.slots[slot] = nil
end

-- Where the jobs laid out here stand now, on every bar: name -> { slot, ... }. A job is known by its macro's
-- name, or by the item it stands as (a spell at any rank).
local function Standing(made, before)
	local at, items = {}, nil
	for name, item in pairs(before and before.last or EMPTY) do
		if made[name] then
			items = items or {}
			items[Ident(Sort(name, before), item)] = name
		end
	end
	for slot = 1, MULTIBAR_7_ACTIONBAR_PAGE * NUM_ACTIONBAR_BUTTONS do
		local text = C_ActionBar.GetActionText(slot)
		local name = text and made[text] and text or nil
		if not name and items and not text then
			local kind, id = GetActionInfo(slot)
			name = (kind == "item" or kind == "spell") and items[Ident(kind, id)] or nil
		end
		if name then
			at[name] = at[name] or {}
			table.insert(at[name], slot)
		end
	end
	return at
end

local function Same(a, b)
	if #a ~= #b then return false end
	local set = {}
	for _, slot in ipairs(a) do set[slot] = true end
	for _, slot in ipairs(b) do
		if not set[slot] then return false end
	end
	return true
end

-- The keys you moved since they were laid out: a macro made here that no longer stands on the buttons it was
-- put on stays where you have it now (other buttons, or none), and is moved no more; put back where it was, it
-- follows the layout again. With none of ours on any bar the bars aren't read yet (just logged in): nothing is
-- decided then.
local function Moved(made, before, opts)
	local at = Standing(made, before)
	if next(at) == nil then return end
	-- A layout made before macros were put by their names (LAYOUT) may have put one where another's name had
	-- moved it: nothing of it is taken as moved by you, and every macro goes back to its own button once.
	if (before.layout or 1) < NAMED then
		wipe(before.pinned)
		return
	end
	for name, seat in pairs(made) do
		local placed = before.placed[name]
		if not placed and type(seat) == "string" then   -- laid out before the buttons were kept: its key's
			local command = GetBindingAction(seat)
			placed = command ~= "" and Slots(command, opts) or nil
		end
		if placed then
			local now = at[name] or {}
			before.pinned[name] = not Same(now, placed) and now or nil
		end
	end
	-- (once for each character: a spell job on no bar goes back to its button, where it may have stood at another
	-- rank and not been counted)
	if not before.ranked then
		before.ranked = true
		for name, slots in pairs(before.pinned) do
			if #slots == 0 and Sort(name, before) == "spell" then before.pinned[name] = nil end
		end
	end
	-- A key you took off its button since (bound to something that is no action button, or to nothing, in the
	-- game's key bindings): its ability stays on its button, as one you moved does, and is shown with whatever
	-- key presses that button now. (A key you bound to another button takes its job there, as before; and while
	-- another key of yours presses its button, the button is still the key's: its own job comes to it.)
	for name, seat in pairs(made) do
		local placed = before.placed[name]
		if type(seat) == "string" and placed and #placed > 0 and not before.pinned[name] and at[name] then
			local command = Hot.Pressing(seat, opts)
			if command == "" or not Slots(command, opts) then before.pinned[name] = placed end
		end
	end
end

-- The key that presses one of these buttons (its binding's key: "SHIFT-W"), or nil.
function KeyOf(slots, opts)
	for _, slot in ipairs(slots) do
		local page = math.floor((slot - 1) / NUM_ACTIONBAR_BUTTONS) + 1
		local n = (slot - 1) % NUM_ACTIONBAR_BUTTONS + 1
		local command
		if page == 1 or (page > NUM_ACTIONBAR_PAGES and page <= NUM_ACTIONBAR_PAGES + (opts.forms or 0)) then
			command = "ACTIONBUTTON" .. n
		else
			for bar, at in pairs(PAGES) do
				if at == page then command = bar .. n end
			end
		end
		local key = command and GetBindingKey(command)
		if key then return key end
	end
end

-- The same, as it is said ("Shift + W").
local function KeyAt(slots, opts)
	local key = KeyOf(slots, opts)
	return key and Keys.Key(key)
end

-- A key as it is said: "Shift + Mouse 4", "Ctrl + C".
function Keys.Key(key)
	return (key:gsub("ALT%-", "Alt + "):gsub("CTRL%-", "Ctrl + "):gsub("SHIFT%-", "Shift + "):gsub("BUTTON(%d)", "Mouse %1"))
end

-- A key as a keycap says it: "Ctrl C", "Shift Mouse 4".
function Hot.Plate(key)
	return (Keys.Key(key):gsub(" %+ ", " "))
end

-- A key pressed with whatever is held with it, as the game names a binding ("CTRL-SHIFT-B").
function Hot.Chord(key)
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

-- The talent build followed (ShyQuest's, when it is there): its id and name, or nil.
function Keys.Build()
	local quest = Shy.addons.Quest
	local build = quest and quest.Build and quest:Build()
	if build then return build.id, build.name end
end

-- The jobs as a build lays them out: on each key the job's own for that build (job.by[build]), else the job.
-- The jobs as a build lays them out, on the keys of the way you move: on each key the job's own for that build
-- (job.by[build]), else the job; its key the one it has for ASDF (job.asdf) when you move that way, else its key.
-- A job with no key for ASDF whose key you move with there has no key (it is left, said so). A build that has
-- nothing for a key leaves it out (job.by[build] = false); a build's own job may name keys of its own (key, asdf,
-- early, asdfEarly), where that build presses it more or less than the others do.
-- The same jobs, build and way of moving give the same tables every time (what is worked out for a job is kept by
-- it), so the jobs are laid out once a build and a way.
local laidOut = setmetatable({}, { __mode = "k" })   -- jobs -> "build|scheme" -> the jobs laid out
local function Base(jobs, build, scheme)
	scheme = scheme or Keys.Scheme()
	local race = Race()
	local mine = laidOut[jobs]
	if not mine then
		mine = {}
		laidOut[jobs] = mine
	end
	local id = tostring(build) .. "|" .. scheme .. "|" .. tostring(race)
	if mine[id] then return mine[id] end
	local out = {}
	mine[id] = out
	for _, job in ipairs(jobs) do
		-- What the key does: the build's own job, and of that your people's own.
		-- (a build with nothing for the key says so, `by = { build = false }`: no job)
		local own = job
		if build and job.by and job.by[build] ~= nil then own = job.by[build] end
		local yours = own and own.race and own.race[race]
		local does = yours or own
		-- (a key only some peoples have something for, and yours isn't one of them: no job)
		if own and (yours or not own.race or #own > 0 or own.supply) then
			-- Its keys: the build's own job may name its own (where that build's hand wants it, for either way of
			-- moving; `false` for an early key: none), else they are the job's.
			local function Own(field)
				local value
				if own ~= job then value = own[field] end
				if value == nil then value = job[field] end
				return value or nil
			end
			local asdf = Own("asdf")
			local key = scheme == "asdf" and asdf or Own("key")
			if scheme == "asdf" and not asdf and Keys.SCHEMES.asdf.move[key] then key = nil end
			-- (the key it made way on, the way you move; and a job that never stands in doesn't for any build)
			local early = nil
			if scheme == "asdf" then early = Own("asdfEarly") else early = Own("early") end
			if does ~= job or key ~= job.key or early ~= job.early then
				local copy = {}
				for field, value in pairs(does) do copy[field] = value end
				copy.key, copy.spare, copy.asdf = key, key == job.key and job.spare or nil, asdf
				copy.early, copy.asdfEarly, copy.stay = early, Own("asdfEarly"), copy.stay or job.stay
				copy.by, copy.race = nil, nil
				out[#out + 1] = copy
			else
				out[#out + 1] = job
			end
			if does.spot then out.spot = true end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- What you seldom press: a key you choose, kept where it is
---------------------------------------------------------------------------

-- What a class keeps for now and then (tracking, a long buff for a group, a spell for one place) stands on no key
-- of its own (job.spot): it takes the first of Shift + 6 to = (then 6 to =) whose button is free as it is laid
-- out, and keeps it from then on (keysBefore.spots[name] = the key). A button with something of yours on it is
-- never taken: the job takes the next free one. One you move is yours (as any key's), and one you put on another
-- of these keys yourself has that key from then on. One you take off the bars stays off; but one whose button you
-- fill with something of your own, and which is on no bar then, takes the next free key.
--   Keys.Utility(jobs, { { name = "Track Beasts", spells = { 1494 } }, ... })   adds them (the spell itself on the
--     button: the first of `spells` you know; `by` as any job's, `what` as said)
HOT.spots = { "SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0", "SHIFT--", "SHIFT-=", "6", "7", "8", "9", "0", "-", "=" }

function Keys.Utility(jobs, list)
	for _, one in ipairs(list) do
		local casts = {}
		for i, spell in ipairs(one.spells) do
			casts[i] = (i < #one.spells and "[known:{%d}] {%d}" or "{%d}"):format(spell, spell)
		end
		jobs[#jobs + 1] = { name = one.name, what = one.what or one.name, spot = true, stay = true, by = one.by,
			spell = #one.spells == 1 and one.spells[1] or one.spells, "#showtooltip", "/cast " .. table.concat(casts, "; ") }
	end
end

-- What a key's button holds, as a job that would stand there sees it: "none" (the key presses no button and
-- can't be given one), "empty", "own" (the job's own macro or spell), "ours" (another job's) or "yours".
local function Holder(key, job, opts, made)
	local command = Pressable(key, opts)
	local slots = command and Slots(command, opts)
	if not slots then return "none" end
	local state = "empty"
	for _, slot in ipairs(slots) do
		local kind, id = GetActionInfo(slot)
		if kind then
			local text = C_ActionBar.GetActionText(slot)
			local mine = false
			if text and made[text] then
				mine = text == job.name and "own" or "ours"
			elseif kind == "spell" and job.spell then
				local name = C_Spell.GetSpellName(id)
				for _, spell in ipairs(type(job.spell) == "table" and job.spell or { job.spell }) do
					if name and C_Spell.GetSpellName(spell) == name then mine = "own" end
				end
			end
			if not mine then return "yours" end
			if state == "empty" or mine == "own" then state = mine end
		end
	end
	return state
end

-- The jobs with what you seldom press given their keys.  record: the layout's own (Apply), which keeps what it
-- chose in `before` and takes a key you put one on as its own; otherwise nothing is changed.
local function Spots(jobs, build, opts, made, before, record)
	if not jobs.spot then return jobs end
	local kept = before and before.spots or {}
	local pinned = before and before.pinned or EMPTY
	local used, want = {}, {}
	for _, job in ipairs(jobs) do
		if job.key then used[job.key] = true end
		if job.spot and Keys.Ever(job, opts, build) then want[#want + 1] = job end
	end
	-- (one you put on another of these keys yourself: that key is its own from then on, bound yet or not)
	if record then
		for _, job in ipairs(want) do
			local at = pinned[job.name]
			if at and #at == 1 then
				for _, key in ipairs(HOT.spots) do
					local command = not used[key] and Pressable(key, opts)
					local slots = command and Slots(command, opts)
					if slots and #slots == 1 and slots[1] == at[1] then
						kept[job.name], before.placed[job.name], pinned[job.name] = key, at, nil
						break
					end
				end
			end
		end
	end
	local chosen, filled = {}, {}
	for _, job in ipairs(want) do
		local key = kept[job.name]
		if key and not used[key] then
			local holds = Holder(key, job, opts, made)
			if holds == "yours" then
				filled[job] = true
			elseif holds ~= "none" then
				chosen[job], used[key] = key, true
			end
		end
	end
	-- The rest: a key whose button holds it already (yours, put there before), else the first free one.
	for _, wanted in ipairs({ "own", "empty" }) do
		for _, job in ipairs(want) do
			if not chosen[job] then
				for _, key in ipairs(HOT.spots) do
					if not used[key] and Holder(key, job, opts, made) == wanted then
						chosen[job], used[key] = key, true
						break
					end
				end
			end
		end
	end
	if record then
		for _, job in ipairs(want) do
			-- (its button filled with something of yours while it was on no bar: it comes back, on its new key)
			local at = pinned[job.name]
			if filled[job] and chosen[job] and at and #at == 0 then pinned[job.name] = nil end
			kept[job.name] = chosen[job]
		end
		before.spots = kept
	end
	local out = {}
	for _, job in ipairs(jobs) do
		if job.spot then
			local copy = {}
			for field, value in pairs(job) do copy[field] = value end
			copy.key, copy.asdf, copy.spot = chosen[job], chosen[job], nil
			out[#out + 1] = copy
		else
			out[#out + 1] = job
		end
	end
	return out
end

-- The jobs a build lays out, the way you move: each on its key (what you seldom press on the key it has, or would
-- take now; nothing is changed).
function Keys.Jobs(jobs, build, scheme)
	local out = Base(jobs, build, scheme)
	if not out.spot then return out end
	local who = UnitGUID("player")
	for _, entry in ipairs(watched) do
		if entry.jobs == jobs then
			local db = entry.addon.db
			return Spots(out, build, entry.opts or EMPTY, db.keysMade and db.keysMade[who] or EMPTY,
				db.keysBefore and db.keysBefore[who], false)
		end
	end
	return Spots(out, build, EMPTY, EMPTY, nil, false)
end

-- The free buttons something of yours can move to when a job takes its button, the best first: a button of the
-- flyouts' bars that a key presses and no job has (an extra button), the buttons of the hand's bars no key presses
-- (the ones under the keys you move with, and the two past B), then the rest of the flyouts' bars.
-- Never a button a job's key presses, even one whose job is still to come.
local function Homes(jobs, opts, wants, keep)
	local reserved = {}
	for _, job in ipairs(jobs) do
		local command = job.key and Hot.Pressing(job.key, opts) or ""
		for _, slot in ipairs(command ~= "" and Slots(command, opts) or EMPTY) do reserved[slot] = true end
	end
	local out, seen = {}, {}
	local function Add(slot)
		if slot and not seen[slot] and not reserved[slot] and not wants[slot] and not keep[slot] and not GetActionInfo(slot) then
			seen[slot] = true
			out[#out + 1] = slot
		end
	end
	local function At(command)
		local bar, button = command:match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
		return bar and PAGES[bar] and (PAGES[bar] - 1) * NUM_ACTIONBAR_BUTTONS + tonumber(button) or nil
	end
	for _, bar in ipairs({ HOT.plain, HOT.bar }) do
		for n = 1, NUM_ACTIONBAR_BUTTONS do
			if GetBindingKey(bar .. n) then Add(At(bar .. n)) end
		end
	end
	local way = Scheme()
	for _, row in ipairs(HOT.rows) do
		for key in row:gmatch(".") do
			if way.move[key] and GRID[key] then Add(At(GRID[key])) end
		end
	end
	for n = 1, NUM_ACTIONBAR_BUTTONS do
		local command = "MULTIACTIONBAR2BUTTON" .. n
		if not GetBindingKey(command) then Add(At(command)) end
	end
	for n = 1, NUM_ACTIONBAR_BUTTONS do Add(At(HOT.bar .. n)) end
	for n = 1, NUM_ACTIONBAR_BUTTONS do Add(At("MULTIACTIONBAR4BUTTON" .. n)) end
	return out
end

function Keys.Apply(addon, jobs, opts)
	opts = opts or {}
	if InCombatLockdown() then return nil, "combat" end
	live = true               -- (the keys as they are bound, whatever is drawn of the keys to come)
	Keys.gen = Keys.gen + 1   -- (what the keys show is worked out again)
	local board = Hot.On() and Keys.Board(opts) or {}   -- the keys the hotkeys hold: a layout lets none of them go
	local made, before = Made(addon), Before(addon)
	local build, buildName
	if opts.build then build, buildName = opts.build() end
	jobs = Base(jobs, build)   -- (what you seldom press is given its key once what you moved is read: below)
	local learns = Learns(opts.knows)
	local result = { placed = 0, waiting = 0, waits = {}, cleared = 0, bound = 0, tidied = 0, kept = 0, left = {}, new = {}, moved = {}, at = {}, learns = learns, build = build, buildName = buildName, shared = 0,
		rehomed = {}, homeless = 0 }
	local pinned = before.pinned
	if not before.theirs then before.theirs = Theirs(made) end   -- (your macros, before the first layout: never deleted here)
	local function Drop(name)
		Remove(name, made, before)
	end
	-- A macro made here for another build's job goes: a character holds few. So does one whose job has no key the
	-- way you move (said).
	local wanted = {}
	for _, job in ipairs(jobs) do
		if job.key or job.spot then
			wanted[job.name] = true
		else
			result.left[#result.left + 1] = { job, "move" }
		end
	end
	for name in pairs(made) do
		if not wanted[name] then Drop(name) end
	end
	Moved(made, before, opts)
	-- (the key bindings it is first laid out on: the ones you chose it for, where a key that does nothing may be bound)
	if before.layout == nil and before.set == nil then before.set = select(2, HotState()) end
	before.layout = LAYOUT   -- (from here on, a macro off its button was moved by you)
	-- What you seldom press, on the key it has or the next free one (none free: it is left, said so).
	if jobs.spot then
		local spotted = Spots(jobs, build, opts, made, before, true)
		jobs = {}
		for _, job in ipairs(spotted) do
			if job.key then
				jobs[#jobs + 1] = job
			elseif Keys.Ever(job, opts, build) then
				result.left[#result.left + 1] = { job, "spots" }
				if made[job.name] then Drop(job.name) end
			end
		end
	end
	local owned = {}         -- the buttons each job stands on as this layout begins: slot -> its name
	for _, slots in ipairs({ before.placed, before.pinned }) do
		for name, at in pairs(slots) do
			for _, slot in ipairs(at) do owned[slot] = name end
		end
	end
	addon.db.keysBuild = addon.db.keysBuild or {}
	addon.db.keysBuild[UnitGUID("player")] = build or ""
	local best, known = Bags(), {}
	local seats, waits = Seat(jobs, opts, made, best, learns, known, pinned, before.last)
	-- A job with no seat has no macro: one left by an earlier layout goes, and with it leaves its buttons.
	for _, job in ipairs(waits) do
		result.waiting = result.waiting + 1
		result.waits[#result.waits + 1] = job.name
		if made[job.name] then
			Drop(job.name)
			result.cleared = result.cleared + 1
		end
	end
	local taken = {}         -- what of yours stood on a button a job took just now: { slot, held }
	-- A job you moved stays where you put it, its macro (or its item) kept up there; the buttons it left are yours too.
	local held, keep = {}, {}   -- the buttons you put a key on; and those, with the ones it left
	for _, job in ipairs(jobs) do
		local at = seats[job] and pinned[job.name]
		if at then
			if Solid(job) then
				Held(job, made, best, before)
				for _, slot in ipairs(at) do Put(job, slot, before, made, nil, owned) end
			else
				Macro(job, made, best, before)
			end
			for _, slot in ipairs(at) do held[slot], keep[slot] = true, true end
			for _, slot in ipairs(before.placed[job.name] or {}) do keep[slot] = true end
			result.placed, result.kept = result.placed + 1, result.kept + 1
		end
	end
	-- Each other seated job's macro (or item), on the buttons of its seat.
	local wants = {}         -- slot -> the job
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		if seat and not pinned[job.name] then
			local command, bound
			if seat == job.key then
				command, bound = Button(job, opts, before)
			else
				command, bound = Press(seat, opts, before)
			end
			if bound then result.bound = result.bound + 1 end
			local was = made[job.name]
			local index, why, new
			if not command then
				why = Hot.Keeps(seat) and "kept" or "key"
			elseif Solid(job) then
				index, why, new = Held(job, made, best, before)
			else
				index, why, new = Macro(job, made, best, before)
			end
			local slots = {}
			for _, slot in ipairs(index and Slots(command, opts) or {}) do
				if not held[slot] then
					slots[#slots + 1] = slot
					wants[slot] = job
				end
			end
			if index and #slots == 0 then index, why = nil, "taken" end
			if index then
				before.placed[job.name] = slots
				result.placed = result.placed + 1
				if new then
					result.new[#result.new + 1] = job
				elseif type(was) == "string" and was ~= seat then
					result.moved[#result.moved + 1] = job
				end
				made[job.name] = seat
				result.at[job.name] = seat
			else
				result.left[#result.left + 1] = { job, why }
			end
		end
	end
	-- Every button of the layout: the macro that stands there now, or (one of ours no longer does) what
	-- stood there before. A key bound for a job that isn't on it is let go.
	local occupied = {}
	for job, seat in pairs(seats) do occupied[seat] = job end
	for _, job in ipairs(jobs) do
		local command = job.key and Hot.Pressing(job.key, opts) or ""
		for _, slot in ipairs(command ~= "" and Slots(command, opts) or {}) do
			local want = wants[slot]
			if want then
				Put(want, slot, before, made, taken, owned)
			elseif not keep[slot] then
				Empty(slot, before, made)
			end
		end
		-- (a key the layout bound, still as it bound it; or on the job's own spare button: one an older layout bound)
		local given = job.key and before.keys[job.key]
		local ours = (type(given) == "string" and command == given) or (job.spare ~= nil and command == job.spare)
		if job.key and ours and not occupied[job.key] and board[job.key] ~= command then
			SetBinding(job.key)
			before.keys[job.key] = nil
			result.unbound = true
		end
	end
	-- A macro made here that stands on a button no key of the layout presses any more (its key was bound to
	-- another button since: the hotkeys set, or put back) leaves it, and what stood there before comes back.
	for _, slots in pairs(Standing(made, before)) do
		for _, slot in ipairs(slots) do
			if not wants[slot] and not keep[slot] then Empty(slot, before, made) end
		end
	end
	-- The player's own buttons for what a key now does are tidied away, wherever on any bar they stand: an
	-- ability stands in one place. What a key does is everything its macro can cast now, on any of its lines
	-- (a stance it passes through, the Bloodrage a Charge ends in), not what it would only fall back to.
	-- Each button is remembered, and comes back when the keys are put back. An ability tidied once and put on a
	-- bar again by you stays, and so do those of a key you moved: where those stand is yours.
	local tidy, done = {}, {}
	for job in pairs(learns and seats or {}) do
		if not pinned[job.name] then
			for _, name in ipairs(Does(job, known, nil, true)) do tidy[name] = true end
		end
	end
	for _, was in pairs(before.slots) do
		local name = was and was[3] and C_Spell.GetSpellName(was[2])
		if name then done[name] = true end
	end
	-- The same for what the bags hold: a kind of item a key now uses (your water, once Drink has it) stands on that
	-- key alone. (An item one of our jobs stands as is on a button the layout wants, or one you moved it to.)
	local carried, used = {}, {}
	for job in pairs(seats) do
		if job.supply and not pinned[job.name] then
			for _, kind in ipairs(job.supply) do carried[kind] = true end
		end
	end
	for _, was in pairs(before.slots) do
		local kind = was and was[3] and was[1] == "item" and Kind(was[2])
		if kind then used[kind] = true end
	end
	for slot = 1, MULTIBAR_7_ACTIONBAR_PAGE * NUM_ACTIONBAR_BUTTONS do
		local kind, id = GetActionInfo(slot)
		local name = not wants[slot] and kind == "spell" and C_Spell.GetSpellName(id)
		local sort = not wants[slot] and not keep[slot] and kind == "item" and Kind(id)
		if (name and tidy[name] and not done[name]) or (sort and carried[sort] and not used[sort]) then
			if not before.slots[slot] then before.slots[slot] = { kind, id, true } end
			PickupAction(slot)
			ClearCursor()
			result.tidied = result.tidied + 1
		end
	end
	-- Nothing of yours disappears: what a job took a button from just now, and no key does, moves to a free button
	-- (and goes back where it stood when the keys are put back, or the job leaves).
	local homes
	for _, entry in ipairs(taken) do
		local was = entry.held
		local covered
		if was[1] == "spell" then
			local name = C_Spell.GetSpellName(was[2])
			covered = name ~= nil and tidy[name] == true
		elseif was[1] == "item" then
			local sort = Kind(was[2])
			covered = sort ~= nil and carried[sort] == true
		end
		if not covered then
			homes = homes or Homes(jobs, opts, wants, keep)
			local home = table.remove(homes, 1)
			if home and Restore(home, was) then
				-- (what you put there after the layout stays on its new button: the one it left goes back to what
				-- stood there first)
				if not entry.later then before.homes[home] = entry.slot end
				result.rehomed[#result.rehomed + 1] = { held = was, from = entry.slot, to = home }
			else
				result.homeless = result.homeless + 1
			end
		end
	end
	if result.bound > 0 or result.unbound then SaveBindings(GetCurrentBindingSet()) end
	for _, entry in ipairs(watched) do
		if entry.addon == addon then entry.waiting = result.waiting end   -- whether a job still waits for a spell
	end
	for _ in pairs(before.account) do result.shared = result.shared + 1 end   -- (how many of its macros are the account's)
	live = false
	return result
end

-- Laid out as a player asks for it: the hotkeys first, when the board is the pick, so every job's key presses
-- its own button; then every job on its key.  -> Apply's result, with hot (Take's) when the hotkeys were set
function Keys.Lay(addon, jobs, opts)
	if InCombatLockdown() then return nil, "combat" end
	-- (no room for its macros: nothing is begun, so nothing is left half laid out)
	local space = Keys.Space(addon, jobs, opts)
	if space.short > 0 then return nil, "macros", space end
	local hot
	if Keys.Mode() == "shy" then hot = Hot.Take(opts) end
	local result = Keys.Apply(addon, jobs, opts)
	if result then result.hot = hot end
	return result
end

-- Put back as a player asks for it: every button as it was, then every hotkey.  -> Revert's result, with hot (Back's)
function Keys.Unlay(addon)
	if InCombatLockdown() then return nil, "combat" end
	local result = Keys.Revert(addon)
	result.hot = Hot.Back()
	return result
end

-- Picks whose hotkeys a layout uses. With keys laid out (or the hotkeys set) it is done now: the keys put
-- back, the hotkeys set or returned, and the keys laid out again on what the keyboard then presses.
--   -> true, or false in a fight
function Keys.SetMode(mode)
	if mode ~= "shy" and mode ~= "own" then return false end
	local mine = watched[1]
	local laid = mine ~= nil and Keys.Has(mine.addon)
	local stands = mode == Keys.Mode() and (Hot.On() == (mode == "shy") or not laid)
	if not stands and (laid or Hot.On()) then
		if InCombatLockdown() then return false end
		if laid then Keys.Revert(mine.addon) end
		HotBook().mode = mode
		if mode == "own" then Hot.Back() elseif laid then Hot.Take(mine.opts) end
		if laid then Keys.Apply(mine.addon, mine.jobs, mine.opts) end
	end
	HotBook().mode = mode
	Keys.gen = Keys.gen + 1
	Shy:Fire("SHY_KEYS_MODE", mode)
	return true
end

-- Whether this character's keys are laid out, or the open setup window means to lay them out: every bar of
-- the layout is wanted on screen then, the flyout with them.
function Keys.Wanted()
	local mine = watched[1]
	if not mine then return false end
	local plan = Shy.Setup and Shy.Setup.Current and Shy.Setup.Current()
	local pick = plan and plan.keys and plan.keys.pick
	if pick then return pick ~= "off" and pick ~= "skip" end   -- (No, or nothing laid out: no bars wanted for it)
	return Keys.Has(mine.addon)
end

function Keys.Revert(addon)
	if InCombatLockdown() then return nil, "combat" end
	Keys.gen = Keys.gen + 1
	local who = UnitGUID("player")
	local made, before = Made(addon), Before(addon)
	local ours = {}          -- the buttons our macros and items stand on: empty once they go
	for name, slots in pairs(Standing(made, before)) do
		for _, slot in ipairs(slots) do ours[slot] = true end
		-- (an item you moved, or that stands where the layout didn't put it: off that button too)
		if before.last[name] then before.pinned[name] = slots end
	end
	local names = {}
	for name in pairs(made) do names[#names + 1] = name end
	for _, name in ipairs(names) do
		Remove(name, made, before)             -- deleted, it leaves every button it stood on
	end
	for slot in pairs(ours) do                 -- (one that was yours before, and so stays: off our buttons all the same)
		if C_ActionBar.GetActionText(slot) then
			PickupAction(slot)
			ClearCursor()
		end
	end
	-- What a job moved to a free button leaves it: it goes back where it stood.
	for home, from in pairs(before.homes) do
		local held = before.slots[from]
		if held and Holds(home, held) then
			PickupAction(home)
			ClearCursor()
		end
	end
	local result = { put = 0, lost = 0 }
	for slot, held in pairs(before.slots) do
		-- (what you have put on a button since stays)
		if held and (ours[slot] or not GetActionInfo(slot)) then
			if Restore(slot, held) then
				result.put = result.put + 1
			else
				result.lost = result.lost + 1
			end
		end
	end
	local unbound = false
	for key, command in pairs(before.keys) do
		-- (a key you have bound to something else since stays yours)
		if command == true or GetBindingAction(key) == command then
			SetBinding(key)
			unbound = true
		end
	end
	if unbound then SaveBindings(GetCurrentBindingSet()) end
	addon.db.keysBefore[who], addon.db.keysMade[who] = nil, nil
	if addon.db.keysBuild then addon.db.keysBuild[who] = nil end
	return result
end

local WHY = {
	key = "its key does something else: have your hotkeys set up in /shy keys, or bind it to an action button",
	kept = "you kept its key as you had it. Untick it in /shy keys to give it the key",
	yours = "you have a macro of your own by that name: rename yours, then lay them out again",
	full = "there is no room for another macro, this character's or the account's",
	name = "the game can't name one of its spells yet: lay them out again in a moment",
	taken = "you put another key's ability on its button",
	move = "it has no key yet for the way you move",
	spots = "Shift + 6 to = all hold something of yours: free one, then lay them out again",
	none = "your bags hold none",
}

-- What a button held, as it is said: a spell's or an item's name, a macro's.
local function Called(held)
	if held[1] == "spell" then return C_Spell.GetSpellName(held[2]) or "a spell" end
	if held[1] == "item" then return C_Item.GetItemNameByID(held[2]) or "an item" end
	return tostring(held[2])
end

-- What a layout would take a button from that no key then does, with nothing done: your own buttons that would
-- move to a free one, by name (a spell, an item, a macro of yours). Read for the keys as they are drawn (the
-- hotkeys looked at), once a frame and state.
function Keys.Displaces(addon, jobs, opts)
	opts = opts or {}
	local kept = HOT.moves
	if kept and kept.at == GetTime() and kept.gen == Keys.gen and kept.look == Keys.look and kept.addon == addon then return kept.list end
	local who = UnitGUID("player")
	local made = addon.db.keysMade and addon.db.keysMade[who] or EMPTY
	local before = addon.db.keysBefore and addon.db.keysBefore[who]
	local pinned, last = before and before.pinned or EMPTY, before and before.last or EMPTY
	jobs = Keys.Jobs(jobs, opts.build and (opts.build()))
	local best, known = Bags(), {}
	local learns = Learns(opts.knows)
	local seats = Seat(jobs, opts, made, best, learns, known, pinned, last)
	local does, carried = {}, {}
	for job in pairs(seats) do
		for _, name in ipairs(learns and Does(job, known, nil, true) or EMPTY) do does[name] = true end
		for _, kind in ipairs(job.supply or EMPTY) do carried[kind] = true end
	end
	local names, seen = {}, {}
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		local command = seat and not pinned[job.name] and Pressable(seat, opts, seat == job.key and job.spare or nil)
		for _, slot in ipairs(command and Slots(command, opts) or EMPTY) do
			local kind, id = GetActionInfo(slot)
			local held
			if kind == "macro" then
				local text = C_ActionBar.GetActionText(slot)
				held = text and not made[text] and { kind, text } or nil
			elseif kind then
				held = { kind, id }
				for name in pairs(last) do
					if made[name] and Owns(name, before, kind, id) then held = nil end   -- (one of ours)
				end
			end
			local covered = held and ((kind == "spell" and does[C_Spell.GetSpellName(id) or ""]) or (kind == "item" and carried[Kind(id) or ""]))
			local name = held and not covered and Called(held)
			if name and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	HOT.moves = { at = GetTime(), gen = Keys.gen, look = Keys.look, addon = addon, list = names }
	return names
end

-- asked: the choice was made where every key it changes is shown (the keys' panel, setup). Not asked (a chat
-- command), hotkeys that would take a key of yours lay nothing out: the keys' page opens to show each one.
function Keys.Run(addon, jobs, opts, asked)
	opts = opts or {}
	if not asked and Keys.Mode() == "shy" and not Hot.On() and not InCombatLockdown() then
		-- (every one a hand relies on said by name, the rest counted)
		local taking, musts = 0, {}
		for _, entry in ipairs(Hot.Yours(opts)) do
			if not entry.kept then
				taking = taking + 1
				if entry.must then
					musts[#musts + 1] = ("%s (%s%s)"):format(Keys.Key(entry.key), BindingCalled(entry.from),
						entry.home and (", to " .. Keys.Key(entry.home)) or "")
				end
			end
		end
		if taking > 0 then
			addon:Print(("nothing is changed yet. Setting up your keys would change %d of your keys%s. /shy keys lists each one, so you can keep any you want before you press Set up my keys."):format(
				taking, #musts > 0 and (", among them " .. Several(musts, HOT.named)) or ""))
			Shy.Hub.Open("keys")
			return
		end
	end
	local result, why, space = Keys.Lay(addon, jobs, opts)
	if why == "macros" then
		addon:Print(("your keys aren't laid out: they need %d macros and there is room for %d. Delete %d you don't use, this character's or the account's, then lay them out. Nothing was changed."):format(
			space.need, space.need - space.short, space.short))
		return
	end
	if not result then
		addon:Print("your keys can be laid out once the fight is over.")
		return
	end
	addon:Print(("%d keys laid out%s%s.%s"):format(result.placed,
		result.buildName and (" for " .. result.buildName) or "", result.bound > 0 and (", %d bound"):format(result.bound) or "",
		result.waiting > 0 and (" %d more come as you learn what they do."):format(result.waiting) or ""))
	local changed = result.hot and (result.hot.bound + result.hot.cleared) or 0
	if changed > 0 then
		print(("  %d of your hotkeys were set to match. Each is kept as it was, and comes back if you put your keys back."):format(changed))
	end
	if result.hot and result.hot.kept > 0 then
		print(("  %d keys you bound to something else yourself stay as you have them."):format(result.hot.kept))
	end
	if result.shared > 0 then
		print(("  This character's macros are full, so %d of your keys' macros are among the account's. They go when you put your keys back; yours are never touched."):format(result.shared))
	end
	if result.tidied > 0 then
		print(("  %d of your own buttons for abilities that are on a key now were taken off. They come back if you put your keys back."):format(result.tidied))
	end
	if #result.rehomed > 0 then
		local names = {}
		for i, entry in ipairs(result.rehomed) do names[i] = Called(entry.held) end
		print(("  %d of your own buttons moved to a free button: %s. They go back where they were if you put your keys back."):format(
			#names, table.concat(names, ", ")))
	end
	if result.homeless > 0 then
		print(("  %d of your own buttons had no free button to move to. They come back if you put your keys back."):format(result.homeless))
	end
	if result.cleared > 0 then
		print(("  %d keys that had nothing to do yet were taken off again."):format(result.cleared))
	end
	if result.kept > 0 then
		print(("  %d keys you moved stay where you put them."):format(result.kept))
	end
	for _, entry in ipairs(result.left) do
		local job = entry[1]
		print(("  %s%s was left: %s."):format(job.name, job.key and (" (" .. Keys.Key(job.key) .. ")") or "", WHY[entry[2]]))
	end
	if not result.learns then
		print("  This game's macros can't ask what you have learned: a key keeps its first ability.")
	end
	print("  /shy keys  - what each key does, and how to put yours back")
	return result
end

function Keys.Back(addon)
	local result = Keys.Unlay(addon)
	if not result then
		addon:Print("your keys can be put back once the fight is over.")
		return
	end
	addon:Print(("your keys are as they were%s."):format(result.lost > 0
		and (", but for %d buttons whose old ability couldn't be found"):format(result.lost) or ""))
	local hot = result.hot
	if hot and hot.put > 0 then
		print(("  %d hotkeys are as they were before, too."):format(hot.put))
	end
	if hot and hot.kept > 0 then
		print(("  %d keys you have bound to something else since stay as you have them."):format(hot.kept))
	end
	if hot and hot.lost > 0 then
		print(("  %d keys the game wouldn't take back yet are still kept: put your keys back again in a moment."):format(hot.lost))
	end
	return result
end

function Keys.List(jobs, opts, addon)
	local lines = {}
	-- Where each job stands for this character now (one you moved, where you put it); then what is still to
	-- come, on the key it will have.
	opts = opts or {}
	jobs = Keys.Jobs(jobs, opts.build and (opts.build()))
	local before = addon and addon.db.keysBefore and addon.db.keysBefore[UnitGUID("player")]
	local pinned = before and before.pinned or {}
	local seats, waits = Seat(jobs, opts, {}, Bags(), Learns(opts.knows), {}, pinned)
	for _, job in ipairs(jobs) do
		if seats[job] then
			local at = pinned[job.name]
			local where = at and (KeyAt(at, opts) or "No key") or Keys.Key(Hot.KeyFor(seats[job], opts))
			lines[#lines + 1] = ("%s   %s"):format(where, job.what)
		end
	end
	if #waits > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Still to come, as you learn them:"
		for _, job in ipairs(waits) do
			lines[#lines + 1] = ("%s   %s"):format(Keys.Key(job.key), job.what)
		end
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- What comes when: the keys at any level
---------------------------------------------------------------------------

-- The level a spell can first be had: a talent's once its row of the tree is open (Data/KeyTalents.lua), any
-- other's as the game says it is trained.  -> level, and whether it is a talent
-- With a leveling build, a talent comes at the level that build first takes it, and never for a build that doesn't
-- (Shy.KeyBuilds, by class and build). Asked once a spell and build: none of it changes while you play.
local NEVER = math.huge
local learnt = {}            -- "class|build" -> spell -> { level, talent }
local function Learned(spell, build)
	local class = select(2, UnitClass("player"))
	local id = tostring(class) .. "|" .. tostring(build)
	local mine = learnt[id]
	if not mine then
		mine = {}
		learnt[id] = mine
	end
	local kept = mine[spell]
	if not kept then
		local talent = Shy.KeyTalents and Shy.KeyTalents[spell]
		if talent then
			local own = build and Shy.KeyBuilds and Shy.KeyBuilds[class] and Shy.KeyBuilds[class][build]
			kept = { own and (own[spell] or NEVER) or talent, true }
		else
			kept = { C_Spell.GetSpellLevelLearned(spell), false }
		end
		mine[spell] = kept
	end
	return kept[1], kept[2]
end

-- What a macro would know at a level, for a build: every spell that can be had by then. (A table Known reads.)
-- With `real`, only what you really know as well (asked as a macro asks): at your own level and below, the keys
-- are what you have trained, not all a trainer would have taught you by then.
local function KnownAt(level, build, real)
	return setmetatable({}, { __index = function(known, id)
		local spell = tonumber(id)
		local name = spell and C_Spell.GetSpellName(spell)
		local learned = name and Learned(spell, build)
		local value = name ~= nil and learned ~= nil and math.max(learned, 1) <= level and name or false
		if value and real and real.learns and SecureCmdOptionParse("[known:" .. name .. "] 1; 0") ~= "1" then value = false end
		rawset(known, id, value)
		return value
	end })
end

-- Whether a job can ever have something to do, for a build: the bags' always; any other when the build can learn
-- one of the abilities its button shows (a talent the build never takes it can't).
function Keys.Ever(job, opts, build)
	if job.supply then return true end
	local does = Does(job, KnownAt(GetMaxLevelForPlayerExpansion(), build), opts and opts.shifts)
	return does == nil or #does > 0
end

-- The bags as though they held every kind: a bags' key stands from the start, once you carry what it uses.
local CARRIED = {}
for kind in pairs(SUPPLIES) do CARRIED[kind] = true end

-- A bags' key's picture: the spell its first kind casts (any food's "Food").
local function SupplyIcon(job)
	local spells = job.supply and SUPPLIES[job.supply[1]]
	return spells and C_Spell.GetSpellTexture(spells[1])
end

-- The keys as they stand at a level, laid out as Apply would lay them (a key you moved stays where you put
-- it).  -> job -> { key, spell, name, icon } for every job on a key
-- With `real` ({ learns }: whether macros can ask what is known), only what you really know counts.
function Keys.At(jobs, opts, level, addon, real)
	opts = opts or {}
	local before = addon and addon.db.keysBefore and addon.db.keysBefore[UnitGUID("player")]
	local pinned = before and before.pinned or {}
	local known = KnownAt(level, opts.build and (opts.build()), real)
	local seats = Seat(jobs, opts, {}, CARRIED, true, known, pinned)
	local at = {}
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		if seat then
			local does, ids, whens = Does(job, known, opts.shifts)
			local spell = ids and ids[1]
			if pinned[job.name] then seat = KeyOf(pinned[job.name], opts) end   -- (nil: on no key you have)
			at[job] = { key = seat, spell = spell, name = does and does[1], does = does or {}, ids = ids or {}, whens = whens or {},
				icon = spell and C_Spell.GetSpellTexture(spell) or (job.make and select(2, job.make())) or SupplyIcon(job) }
		end
	end
	return at
end

-- The levels at which the keys can change: the first, and each level a spell a job names comes at (between them
-- what macros know is the same, so the keys are).
local function Turning(jobs, build, top)
	local at = { [1] = true }
	for _, job in ipairs(jobs) do
		for _, line in ipairs(job) do
			for id in line:gmatch("(%d+)") do
				local level = Learned(tonumber(id), build)
				if level and level >= 1 and level <= top then at[level] = true end
			end
		end
	end
	return at
end

-- What a story was worked out for, and what it is kept against: a story stands until one of these changes.
-- Keys.gen goes up when the keys are laid out or put back, the build or the talents change, or how you move.
Keys.gen = 0
local told = {}              -- the last story: { stamp, levels, changes, story, jobs }
local function Bump() Keys.gen = Keys.gen + 1 end
local function Stamp(jobs, build, addon)
	-- (the keys a story reads the bindings of, as they are bound now: a binding changed means another story)
	local parts = { tostring(jobs), tostring(build), Keys.Scheme(), Keys.gen, tostring(addon), UnitLevel("player") }
	for _, job in ipairs(jobs) do
		if job.key then parts[#parts + 1] = Action(job.key) end
	end
	for _, key in ipairs(Scheme().prime) do parts[#parts + 1] = Action(key) end
	return table.concat(parts, "|")
end

-- Every level's keys, and what changes at each: a key's job comes (new), goes to another key (moved), or
-- casts another ability (grows). Laid out only at the levels where anything can change, and kept until what it
-- reads changes.
--   -> { [level] = at }, { [level] = { { job, kind, key, name, icon }, ... } }, { [job] = { { level, name, icon }, ... } },
--      and the jobs as laid out
local NONE = {}
function Keys.Story(jobs, opts, addon)
	opts = opts or {}
	local build = opts.build and (opts.build())
	jobs = Keys.Jobs(jobs, build)
	local stamp = Stamp(jobs, build, addon)
	if told.stamp == stamp then return told.levels, told.changes, told.story, told.jobs end
	-- (one of the last few: your own hotkeys and the board's, looked at in turn)
	local kept = HOT.stories[stamp]
	if kept then
		told = kept
		return told.levels, told.changes, told.story, told.jobs
	end
	local top = GetMaxLevelForPlayerExpansion()
	local turning = Turning(jobs, build, top)
	-- (your own level and below: what you really know; above it, what you can learn by then)
	local current = math.max(1, math.min(top, UnitLevel("player")))
	local real = { learns = Learns(opts.knows) }
	turning[current], turning[math.min(top, current + 1)] = true, true
	local levels, changes, story = {}, {}, {}
	local was = {}
	for level = 1, top do
		if not turning[level] then
			levels[level], changes[level] = was, NONE
		else
			local at = Keys.At(jobs, opts, level, addon, level <= current and real or nil)
			local here = {}
			for _, job in ipairs(jobs) do
				local now, before = at[job], was[job]
				local kind
				if now and not before then
					kind = "new"
				elseif now and now.key ~= before.key then
					kind = "moved"
				elseif now and now.name ~= before.name then
					kind = "grows"
				end
				if kind then here[#here + 1] = { job = job, kind = kind, key = now.key, name = now.name, icon = now.icon } end
				-- (its story: every ability it comes to cast, at the level it first can; a bags' key, as it comes)
				if now then
					story[job] = story[job] or {}
					local steps = story[job]
					if #now.does == 0 and #steps == 0 then steps[1] = { level = level, icon = now.icon } end
					for i, name in ipairs(now.does) do
						local seen = false
						for _, step in ipairs(steps) do
							if step.name == name then seen = true end
						end
						if not seen then
							steps[#steps + 1] = { level = level, name = name, icon = C_Spell.GetSpellTexture(now.ids[i]),
								talent = select(2, Learned(now.ids[i], build)) }
						end
					end
				end
			end
			levels[level], changes[level], was = at, here, at
		end
	end
	-- (and at your level, what a trainer would have taught you: the guide says what is still to train)
	told = { stamp = stamp, levels = levels, changes = changes, story = story, jobs = jobs, current = current,
		could = Keys.At(jobs, opts, current, addon) }
	if HOT.told >= HOT.tells then HOT.stories, HOT.told = {}, 0 end
	HOT.stories[stamp], HOT.told = told, HOT.told + 1
	return levels, changes, story, jobs
end

---------------------------------------------------------------------------
-- How to play: a class's guide by level and build
---------------------------------------------------------------------------

-- A class's opts.play: brackets { from, build, tip, single = { { job, when }, ... }, cleave = { ... } }. The one
-- for a level: a build's own once one has begun (the latest of them by then), else the latest plain one.
local function Bracket(play, build, level)
	local plain, own
	for _, bracket in ipairs(play or {}) do
		if bracket.from <= level then
			if bracket.build == nil then
				if not plain or bracket.from > plain.from then plain = bracket end
			elseif bracket.build == build then
				if not own or bracket.from > own.from then own = bracket end
			end
		end
	end
	return own or plain
end

-- The ability a step means, of all its key can cast: the one whose clause holds `as` ("stealth", "stance:3"), else
-- the first you'd cast out in the open (a stealth opener is what the key does from Stealth, not in the fight).
--   -> name, spell, or nil when the key casts nothing by name
local function Fighting(info, as)
	local first
	for i, clause in ipairs(info.whens or NONE) do
		if as then
			if clause:find(as, 1, true) then return info.does[i], info.ids[i] end
		elseif not clause:find("[%[,]%s*stealth") then
			return info.does[i], info.ids[i]
		end
		first = first or i
	end
	if first then return info.does[first], info.ids[first] end
end

-- How to play at a level: the bracket's tip, and its two orders, each step as the key you press the way you move
-- and what that key casts then. A step whose ability isn't had yet at that level drops out. Read off the story
-- (kept), so it costs nothing to ask again.
--   -> { tip, from, single = { { job, key, name, icon, when }, ... }, cleave = { ... } } or nil
-- What to stay in on the stance bar at a level (a paladin's aura, a warrior's stance, a druid's form), for the build:
-- the first of its list that is had by then (at your level and below, what you really know). Where it stands on the
-- stance bar is read by its name (any rank), with the key that presses it; at your level, whether it is on (unknown
-- while the game keeps that secret). As a step of the guide: { name, spell, icon, key, when, alert, word, on }, or nil.
local function StayKey(opts, spell)
	for _, entry in ipairs(watched) do
		if entry.opts == opts then
			for _, job in ipairs(Keys.Jobs(entry.jobs, opts.build and (opts.build()))) do
				local stands = job.spell
				for _, id in ipairs(type(stands) == "table" and stands or { stands }) do
					if id == spell then return job.key end
				end
			end
		end
	end
end

function Keys.Keep(opts, level)
	local lists = opts and opts.keep
	if not lists then return nil end
	local build = opts.build and (opts.build())
	local list = lists[build] or lists.plain
	if not list then return nil end
	local current = math.max(1, math.min(GetMaxLevelForPlayerExpansion(), UnitLevel("player")))
	level = level or current
	local known = KnownAt(level, build, level <= current and { learns = Learns(opts.knows) } or nil)
	local spell, name
	for _, id in ipairs(list) do
		if known[id] then
			spell, name = id, known[id]
			break
		end
	end
	if not spell then return nil end
	local step = { name = name, spell = spell, job = true, icon = C_Spell.GetSpellTexture(spell), word = opts.keeps or "stance" }
	step.key = StayKey(opts, spell)   -- (its key of 1 2 3, where it stands as the spell itself)
	for i = 1, GetNumShapeshiftForms() do
		local _, active, _, id = GetShapeshiftFormInfo(i)
		local found = id ~= nil and not issecretvalue(id) and C_Spell.GetSpellName(id)
		if found == name then
			step.index = i
			-- (the key that presses it: as the keys are drawn, else as you have it bound)
			step.key = step.key or GetBindingKey("SHAPESHIFTBUTTON" .. i)   -- (else as you have the bar bound)
			if level == current and not issecretvalue(active) then step.on = active and true or false end
			break
		end
	end
	if step.on == true then
		step.when = "it's on"
	elseif step.on == false then
		step.alert = true
		step.when = step.key and ("it's off: press " .. Keys.Key(step.key)) or "it's off: click it under you"
	else
		step.when = "keep it on"
	end
	return step
end

function Keys.Play(jobs, opts, level, addon)
	opts = opts or {}
	local build = opts.build and (opts.build())
	local bracket = Bracket(opts.play, build, level)
	if not bracket then return nil end
	local levels, _, _, laid = Keys.Story(jobs, opts, addon)
	local at = levels[level] or NONE
	local named = {}
	for _, job in ipairs(laid) do named[job.name] = job end
	local function Steps(list)
		local out = {}
		for _, step in ipairs(list or {}) do
			local job = named[step[1]]
			local info = job and at[job]
			-- (at your level, one a trainer would have taught you by now that you haven't learned: no key yet)
			local could = not (info and info.key) and level == told.current and job and told.could and told.could[job]
			if info and info.key then
				local name, spell = Fighting(info, step.as)
				out[#out + 1] = { job = job, key = info.key, name = name or info.name or job.name, spell = spell or info.spell,
					icon = spell and C_Spell.GetSpellTexture(spell) or info.icon, when = step[2] }
			elseif could then
				local name, spell = Fighting(could, step.as)
				out[#out + 1] = { job = job, name = name or could.name or job.name, spell = spell or could.spell,
					icon = spell and C_Spell.GetSpellTexture(spell) or could.icon, when = "learn it at your trainer", untrained = true }
			end
		end
		return out
	end
	return { tip = bracket.tip, from = bracket.from, build = bracket.build, single = Steps(bracket.single), cleave = Steps(bracket.cleave),
		keep = Keys.Keep(opts, level) }
end

---------------------------------------------------------------------------
-- What waits for training
---------------------------------------------------------------------------

-- Whether a job's ability is one you could have trained by now and haven't (at your own level).
function Keys.CouldTrain(job)
	return told.could ~= nil and told.could[job] ~= nil and told.levels ~= nil
		and told.levels[told.current] ~= nil and told.levels[told.current][job] == nil
end

-- What your trainer has for you now, in the order to buy it when gold is short: the abilities the guide presses
-- that you haven't learned, in its order (each comes to its key once you do), then new ranks of the ones it
-- presses, in its order, then the rest. Prices are ShyQuest's (read at your trainer; nil until a first visit).
-- An ability the guide asks for that you haven't learned gets its price, and what you're short, as its when.
--   play: Keys.Play at your level   -> { { name, rank, cost, key, new }, ... }, their sum (nil: one unknown)
function Keys.Training(play)
	local quest = Shy.addons.Quest
	local due = quest and quest.Training and quest:Training() or NONE
	local priced = {}            -- name -> { cost (summed over ranks; nil: one unknown), rank (the highest) }
	for _, spell in ipairs(due) do
		local entry = priced[spell.name]
		if not entry then
			entry = { cost = 0, level = 0 }
			priced[spell.name] = entry
		end
		entry.cost = entry.cost and spell.cost and entry.cost + spell.cost or nil
		if (spell.level or 0) >= entry.level then entry.rank, entry.level = spell.rank, spell.level or 0 end
	end
	local out, taken = {}, {}
	local function Add(name, key, new, rank)
		if taken[name] then return end
		taken[name] = true
		local entry = priced[name]
		out[#out + 1] = { name = name, key = key, new = new, rank = not new and entry and entry.rank or rank,
			cost = entry and entry.cost or nil }
	end
	local steps = {}
	for _, kind in ipairs({ "single", "cleave" }) do
		for _, step in ipairs(play and play[kind] or NONE) do steps[#steps + 1] = step end
	end
	for _, step in ipairs(steps) do
		if step.untrained then Add(step.name, step.job.key, true) end
	end
	for _, step in ipairs(steps) do
		if not step.untrained and priced[step.name] then Add(step.name, step.key, false) end
	end
	for _, spell in ipairs(due) do
		if not taken[spell.name] then Add(spell.name, nil, false) end
	end
	local sum = 0
	for _, entry in ipairs(out) do sum = sum and entry.cost and sum + entry.cost or nil end
	-- (each ability the guide asks for that you haven't learned: its price as its when)
	local gold = GetMoney()
	for _, step in ipairs(steps) do
		local entry = step.untrained and priced[step.name]
		if entry and entry.cost then
			step.when = entry.cost <= gold and ("train it: %s"):format(UI.Money(entry.cost, true, 10))
				or ("train it: %s short"):format(UI.Money(entry.cost - gold, true, 10))
		end
	end
	return out, #out > 0 and sum or nil
end

-- The training in a sentence or two, for the guide: what to buy first with the gold you have.
--   -> words, or nil when nothing waits
function Keys.TrainingSays(list, sum)
	if not list or #list == 0 then return nil end
	-- (the names from the top to `to`; `all`: the whole list, so "and N more" says the rest)
	local function Named(from, to, all)
		local names = {}
		for i = from, math.min(to, #list) do names[#names + 1] = list[i].name end
		local more = all and #list > to and (" and %d more"):format(#list - to) or ""
		if #names > 1 and more == "" then
			return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
		end
		return table.concat(names, ", ") .. more
	end
	if not sum then return ("At your trainer: %s."):format(Named(1, 3, true)) end
	local gold = GetMoney()
	if sum <= gold then return ("At your trainer: %s, %s. You can afford it all."):format(Named(1, 3, true), UI.Money(sum, true, 11)) end
	-- (the most that fits, from the top)
	local can, spent = 0, 0
	for i, entry in ipairs(list) do
		if spent + entry.cost > gold then break end
		can, spent = i, spent + entry.cost
	end
	if can == 0 then
		return ("Train %s first, %s: you're %s short."):format(list[1].name, UI.Money(list[1].cost, true, 11),
			UI.Money(list[1].cost - gold, true, 11))
	end
	return ("Train %s first, %s. You're %s short of the rest."):format(Named(1, math.min(can, 3)), UI.Money(spent, true, 11),
		UI.Money(sum - gold, true, 11))
end

-- Its hover: every lesson in that order, its price against your gold.
function Keys.TrainingHover(owner, list)
	local rows, gold = {}, GetMoney()
	for _, entry in ipairs(list or NONE) do
		local can = entry.cost and entry.cost <= gold
		if entry.cost then gold = gold - entry.cost end
		rows[#rows + 1] = { text = entry.name .. (entry.rank and entry.rank ~= "" and (" (" .. entry.rank .. ")") or "")
			.. (entry.new and entry.key and ("  on " .. Keys.Key(entry.key)) or ""),
			right = entry.cost and UI.Money(entry.cost, true, 10) or "at your trainer",
			rightColor = entry.cost and (can and UI.colors.good or UI.colors.bad) or UI.colors.dim }
	end
	Shy.Hover.Show(owner, { title = "At your trainer", note = UI.Money(GetMoney(), true, 10),
		sections = { { rows = rows } } }, { side = "RIGHT" })
end

-- The levels a class's guide changes at, for this build: level -> true.
function Keys.PlayLevels(opts)
	local out = {}
	local build = opts and opts.build and (opts.build())
	for _, bracket in ipairs(opts and opts.play or {}) do
		if bracket.build == nil or bracket.build == build then out[bracket.from] = true end
	end
	return out
end

-- What a key does now, when no job can stand on it: the binding's name ("nothing": it presses nothing and its
-- own button has another key), else nil (it presses a button, or will once bound to its own).
function Keys.Busy(job, opts)
	if not job.key then return nil end
	opts = opts or {}
	if Pressable(job.key, opts, job.spare) then return nil end
	local command = Action(job.key)
	if command == "" then return "nothing" end
	return GetBindingName(command)
end

-- Lays your keys out again for the way you move now: put back as they were, then laid out on the new keys (a
-- key you moved goes back with the rest). Out of a fight.  -> true when done
function Keys.Rescheme()
	local mine = watched[1]
	local laid = mine ~= nil and Keys.Has(mine.addon)
	if not laid and not Hot.On() then return true end
	if laid and Keys.Paused(mine.addon) then return true end   -- (waiting for your keys: nothing moved)
	if InCombatLockdown() then return false end
	if laid then Keys.Revert(mine.addon) end
	-- (the hotkeys, where they are set: the keys you move with now move you, the ones you moved with press buttons)
	if Hot.On() then Hot.Take(mine and mine.opts) end
	local result = laid and Keys.Apply(mine.addon, mine.jobs, mine.opts)
	if result then
		mine.waiting = result.waiting
		mine.addon:Print(("your keys are laid out for %s now."):format(Scheme().name))
	end
	return true
end

-- Picks how you move ("wasd", "asdf"), and lays your keys out for it when they are laid out.
function Keys.SetScheme(scheme)
	if not Keys.SCHEMES[scheme] or scheme == Keys.Scheme() then
		Shy.core.db.keysMove = Keys.SCHEMES[scheme] and scheme or nil
		return true
	end
	if InCombatLockdown() and (Hot.On() or (watched[1] and Keys.Has(watched[1].addon))) then return false end
	Shy.core.db.keysMove = scheme
	Keys.Rescheme()
	Shy:Fire("SHY_KEYS_SCHEME", scheme)
	return true
end

---------------------------------------------------------------------------
-- Kept up: new abilities, the bags, the build
---------------------------------------------------------------------------

local watch, waiting, turning, growing, soon

-- The class's keys for this character, when its addon is here: { addon, jobs, opts }.
function Keys.Mine()
	return watched[1]
end

-- Jobs that had nothing to do may have now (a spell trained, food bought): they come to their keys, each said.
local function Grow()
	soon = false
	if InCombatLockdown() then
		growing = true
		return
	end
	growing = false
	for _, entry in ipairs(watched) do
		if Keys.Has(entry.addon) and not Keys.Old(entry.addon) and not Keys.Paused(entry.addon) and (entry.waiting ~= 0 or entry.stale) then
			entry.stale = nil
			local result = Keys.Apply(entry.addon, entry.jobs, entry.opts)
			if result then
				entry.waiting = result.waiting
				for _, job in ipairs(result.new) do
					entry.addon:Print(("%s is on %s now."):format(job.name, Keys.Key(result.at[job.name])))
				end
				for _, job in ipairs(result.moved) do
					entry.addon:Print(("%s moved to %s."):format(job.name, Keys.Key(result.at[job.name])))
				end
			end
		end
	end
end
Keys.Grow = Grow

local function Later()
	if soon then return end
	soon = true
	C_Timer.After(SOON, Grow)
end
Keys.Later = Later

-- Every watched job from the bags whose macro was made here is written again where the bags hold better (or
-- another) now; one not yet on its key comes to it when the bags first hold what it uses. Macros can't be
-- written in a fight: it waits for the end of one.
local function Follow()
	if InCombatLockdown() then
		waiting = true
		return
	end
	waiting = false
	local best               -- the bags, read once and only when a job needs them
	for _, entry in ipairs(watched) do
		local made = entry.addon.db and entry.addon.db.keysMade
		made = made and made[UnitGUID("player")]
		if made and next(made) and not Keys.Old(entry.addon) then
			local before = Before(entry.addon)
			for _, job in ipairs(Keys.Jobs(entry.jobs, entry.opts.build and (entry.opts.build()))) do
				if job.supply and job.key then
					best = best or Bags()
					if made[job.name] and job.item then
						-- (the item itself: another goes on its button, which only a layout may do)
						if Pick(job, best, before) ~= before.last[job.name] then
							entry.stale = true
							Later()
						end
					elseif made[job.name] then
						Macro(job, made, best, before)
					else
						for _, kind in ipairs(job.supply) do
							if best[kind] then
								entry.waiting = nil
								Later()
							end
						end
					end
				end
			end
		end
	end
end
Keys.Follow = Follow

-- The build changed (another was picked, or the talents now fit another): a character whose keys were laid
-- out here has them laid out again for it, and is told. In a fight it waits for the end of it.
local function Turn()
	if InCombatLockdown() then
		turning = true
		return
	end
	turning = false
	local who = UnitGUID("player")
	for _, entry in ipairs(watched) do
		local opts, db = entry.opts, entry.addon.db
		if opts and opts.build and db.keysFollow == true and Keys.Has(entry.addon) and not Keys.Old(entry.addon) and not Keys.Paused(entry.addon) then
			local build, name = opts.build()
			if (db.keysBuild and db.keysBuild[who]) ~= (build or "") then
				local result = Keys.Apply(entry.addon, entry.jobs, opts)
				if result then
					entry.waiting = result.waiting
					entry.addon:Print(("your keys are laid out for %s now."):format(name or "your talents"))
				end
			end
		end
	end
end
Keys.Turn = Turn

function Keys.Watch(addon, jobs, opts)
	watched[#watched + 1] = { addon = addon, jobs = jobs, opts = opts or {} }
	Keys.gen = Keys.gen + 1   -- (whose keys are drawn has changed)
	if watch then return end
	watch = CreateFrame("Frame")
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
		"ITEM_DATA_LOAD_RESULT", "NEW_MOUNT_ADDED" }) do
		watch:RegisterEvent(event)
	end
	watch:RegisterUnitEvent("UNIT_PET", "player")
	watch:SetScript("OnEvent", function(_, event, item)
		if event == "PLAYER_REGEN_ENABLED" then
			if waiting then Follow() end
			if turning then Turn() end
			if growing then Later() end
		elseif event == "ITEM_DATA_LOAD_RESULT" then
			-- (something in the bags the game hadn't loaded when they were read: it may be food)
			if loading[item] then
				loading[item] = nil
				Follow()
			end
		elseif event == "BAG_UPDATE_DELAYED" or event == "UNIT_PET" then
			Follow()   -- (another pet eats other things)
		else
			Keys.gen = Keys.gen + 1   -- (what you know changed: what the keys show is worked out again)
			if event == "PLAYER_LEVEL_UP" or event == "NEW_MOUNT_ADDED" then   -- (and what in your bags you can use, what you can ride)
				for _, entry in ipairs(watched) do entry.stale = true end
			end
			Later()
		end
	end)
	Shy:On("SHY_BUILD", Turn)
	Shy:On("SHY_TALENTS", Turn)
end

---------------------------------------------------------------------------
-- The controls: your keys drawn as the hand finds them, at any level
---------------------------------------------------------------------------

-- Whether a piece already showed this very state this frame (a window shows it, the room refreshes it, the
-- window refreshes its page: one frame, one drawing). Anything that changes what it shows (keys laid out or put
-- back, how you move, the level) makes the next call draw again.
local function Drawn(piece, ...)
	local stamp = table.concat({ tostring(GetTime()), Keys.gen, Keys.look, Keys.Scheme(), tostring((...)) }, "|")
	if piece.drawn == stamp then return true end
	piece.drawn = stamp
end

local C = UI.colors
local Theme = Shy.Theme
local ROW = 24               -- a button's height
local GAP = 8

-- Two hands on a keyboard: the plain keys on the left, the same keys with Shift on the right, each the board
-- as a hand meets it (the rows stepped in as a keyboard's are, in caps) with the mouse's side keys past it.
local BOARD = {
	{ x = 0, keys = { "1", "2", "3", "4", "5" } },
	{ x = 0.5, keys = { "Q", "W", "E", "R", "T" } },
	{ x = 0.75, keys = { "A", "S", "D", "F", "G" } },
	{ x = 1.25, keys = { "Z", "X", "C", "V", "B" } },
}
local MOUSE = { { key = "BUTTON4", row = 2 }, { key = "BUTTON5", row = 3 } }
local VIEW = {
	span = 7.5,              -- a hand's width, in caps: the board's widest row and the mouse's keys past it
	mouse = 6.5,             -- where the mouse's keys stand, in caps from the hand's left
	apart = 28,              -- between the hands
	inner = 3,               -- between two caps
	tall = 1.24,             -- a cap's height to its width
	most = 54,               -- the widest a cap's step grows, however wide the room flows
	label = 10,              -- the key's letter on its cap
	name = 9,                -- the macro's name along its foot
	caption = 18,            -- the words over each hand
	turns = 3,               -- what changes at a level: rows a column
	turnRow = 32,
	ruler = 38,              -- the level's slider
	arrow = 24,              -- the buttons either side of it
	notch = { 2, 5 },        -- a mark under the slider where something changes
	mark = 5,                -- a cap's corner mark: a key of yours that changes
}

-- A key as its cap says it: "Q", "4", "M4".
local function Cap(key)
	return (key:gsub("^SHIFT%-", ""):gsub("^BUTTON(%d)", "M%1"))
end

-- One cap: the family's keyed plate, the key's letter at its corner, the ability in a slot, the macro's name
-- along its foot.
local function NewCap(parent, size, high)
	local cap = CreateFrame("Button", nil, parent)
	cap:SetSize(size, high)
	UI.KeyPlate(cap)
	cap:EnableMouse(true)
	cap.letter = UI.Text(cap, "", VIEW.label, true, C.dim)
	cap.letter:SetPoint("TOPLEFT", 4, -3)
	local slot = Shy.Slot.SIZES[size >= 40 and "compact" or "small"]
	cap.well = CreateFrame("Frame", nil, cap)
	cap.well:SetSize(slot, slot)
	cap.well:SetPoint("TOP", 0, -(VIEW.label + 3))
	cap.icon = cap.well:CreateTexture(nil, "ARTWORK")
	cap.icon:SetAllPoints()
	cap.slot = Shy.Slot.New(cap.well, { icon = cap.icon, size = slot, hover = false })
	cap.soon = UI.Text(cap.well, "", 12, true, C.dim)
	cap.soon:SetPoint("CENTER")
	cap.name = UI.Text(cap, "", VIEW.name)
	cap.name:SetPoint("BOTTOM", 0, 3)
	cap.name:SetWidth(size - 4)
	cap.name:SetJustifyH("CENTER")
	cap.name:SetWordWrap(false)
	return cap
end

-- A step of the keys' page: its number on a key's plate, what it is, and under it one sentence that guides; at
-- the right, beside the title, a few words (how many keys change).
--   Hot.StepHead(parent, n, width) -> f: f.title, f.say, f.side; f:Fit() sizes it to what it says (-> its height)
function Hot.StepHead(parent, n, width)
	local f = CreateFrame("Frame", nil, parent)
	f.plate = CreateFrame("Button", nil, f)
	f.plate:SetSize(HOT.step, HOT.step)
	f.plate:SetPoint("TOPLEFT")
	UI.KeyPlate(f.plate)
	f.number = UI.Text(f.plate, tostring(n), 12, true, C.head)
	f.number:SetPoint("CENTER")
	f.title = UI.Text(f, "", 15, true, C.head)
	f.title:SetPoint("LEFT", f.plate, "RIGHT", HOT.stepGap, 0)
	f.side = UI.Text(f, "", 11, true, C.dim)
	f.side:SetPoint("RIGHT", f, "TOPRIGHT", 0, -HOT.step / 2)
	f.side:SetJustifyH("RIGHT")
	f.say = UI.Text(f, "", 12, false, C.dim)
	f.say:SetPoint("TOPLEFT", f.plate, "BOTTOMRIGHT", HOT.stepGap, -5)
	f.say:SetWidth(width - HOT.step - HOT.stepGap)
	f.say:SetJustifyH("LEFT")
	f.say:SetWordWrap(true)
	function f:Fit()
		local said = (self.say:GetText() or "") ~= ""
		self:SetSize(width, HOT.step + (said and (5 + math.ceil(self.say:GetStringHeight())) or 0))
		return self:GetHeight()
	end
	f:Fit()
	return f
end

-- More of a list, a click away: its words in the middle of a line between two hairlines, lit under the mouse.
--   Hot.More(parent, width, onClick) -> b: b:Set(words) (nil or "": hidden); b.text
HOT.moreTall = 24
function Hot.More(parent, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOT.moreTall)
	b.text = UI.Text(b, "", 11, true, C.good)
	b.text:SetPoint("CENTER")
	b.left = b:CreateTexture(nil, "ARTWORK")
	b.right = b:CreateTexture(nil, "ARTWORK")
	for _, rule in ipairs({ b.left, b.right }) do
		Theme.Paint(rule, C.border, 0.8)
		rule:SetHeight(1)
	end
	b.left:SetPoint("LEFT")
	b.left:SetPoint("RIGHT", b.text, "LEFT", -12, 0)
	b.right:SetPoint("LEFT", b.text, "RIGHT", 12, 0)
	b.right:SetPoint("RIGHT")
	b:SetScript("OnClick", function() onClick() end)
	b:SetScript("OnEnter", function(self)
		Theme.Ink(self.text, C.head)
		for _, rule in ipairs({ self.left, self.right }) do Theme.Paint(rule, C.good, 0.6) end
	end)
	b:SetScript("OnLeave", function(self)
		Theme.Ink(self.text, C.good)
		for _, rule in ipairs({ self.left, self.right }) do Theme.Paint(rule, C.border, 0.8) end
	end)
	function b:Set(words)
		self.text:SetText(words or "")
		if words ~= nil and words ~= "" then self:Show() else self:Hide() end
	end
	b:Set(nil)
	return b
end

-- The keys' controls for this character's class: how things stand, lay them out, put yours back, follow the
-- build; and the keys themselves on two hands at the level the slider picks (yours to start with), what each
-- does then, what comes at that level, and how each key grows on its hover. f:Refresh() says how things stand.
-- With a plan (setup's page) the hotkeys' choice is a pick for Finish (plan.keys.pick: "shy", "own" or "off"),
-- and the two buttons and the build's switch stay in the /shy window.
-- part: one part alone, a page of setup's walk through your keys: "choose" (the three choices and what the lit one
-- means), "changes" (what it changes, key by key) or "board" (your keys on two hands, at any level).
function Keys.Panel(parent, width, plan, part)
	local f = CreateFrame("Frame", nil, parent)
	local view = { level = nil }   -- the story, worked out as the panel shows; the level shown
	-- Three steps, one under the other: choose, what that changes, your keys. Each says what to do there.
	f.step1 = Hot.StepHead(f, 1, width)
	f.step1:SetPoint("TOPLEFT")
	f.step1.title:SetText("Choose how your keys work")
	f.status = f.step1.say
	local function Do(act)
		return function()
			local mine = Keys.Mine()
			if mine then act(mine) end
			f:Refresh()
		end
	end
	-- The choice: set up for you, on your own hotkeys, or everything as it was before; what of yours each changes.
	f.hot = Hot.Panel(f, width, plan, function()
		f:Refresh()
		if f.resized then f.resized() end
	end, part)
	f.hot:SetPoint("TOPLEFT", f.step1, "BOTTOMLEFT", 0, -12)
	f.part = part
	-- One button makes the choice looked at (it says which); beside it, that until then nothing is changed.
	local third = math.floor((width - 2 * GAP) / 3)
	f.lay = UI.Button(f, "", third, function()
		f.hot:Use()
		f:Refresh()
		if f.resized then f.resized() end
	end)
	f.lay:SetPoint("TOPLEFT", f.hot, "BOTTOMLEFT", 0, -12)
	f.hint = UI.Text(f, "", 11, false, C.dim)
	f.hint:SetPoint("LEFT", f.lay, "RIGHT", GAP + 4, 0)
	f.hint:SetWidth(third - 4)
	f.hint:SetJustifyH("LEFT")
	-- Following your talents, a line of its own under the button, saying what it does (not a part of setting up).
	f.follow = UI.Checkbox(f, "Follow my talents", function()
		local mine = Keys.Mine()
		return mine ~= nil and mine.addon.db.keysFollow == true
	end, function(on)
		local mine = Keys.Mine()
		if not mine then return end
		mine.addon.db.keysFollow = on
		if on then Turn() end
		f:Refresh()
	end)
	f.follow:SetPoint("TOPLEFT", f.lay, "BOTTOMLEFT", 0, -HOT.followGap)
	f.followSay = UI.Text(f, "When you switch to another talent build, your keys are laid out for it.", 11, false, C.dim)
	f.followSay:SetPoint("LEFT", f.follow, "RIGHT", 12, 0)
	-- An earlier layout's keys: one press draws your bars as they are now, another the new layout again.
	f.flip = UI.Button(f, "", third - GAP, function()
		view.now = not view.now
		f.drawn = nil
		f:Refresh()
	end)
	f.flip:SetPoint("LEFT", f.lay, "RIGHT", GAP, 0)
	f.flip:Hide()
	for _, piece in ipairs({ f.lay, f.hint, f.follow, f.followSay }) do piece:SetShown(plan == nil) end
	-- The two hands.
	local unit = math.min(VIEW.most, math.floor((width - VIEW.apart) / (2 * VIEW.span)))
	local size = unit - VIEW.inner
	local high = math.floor(size * VIEW.tall)
	local hands = (VIEW.span * unit) * 2 + VIEW.apart
	f.step3 = Hot.StepHead(f, 3, width)
	f.step3:SetPoint("TOPLEFT", plan and f.hot or f.follow, "BOTTOMLEFT", 0, -24)
	local board = CreateFrame("Frame", nil, f)
	board:SetSize(hands, VIEW.caption + #BOARD * (high + VIEW.inner))
	board:SetPoint("TOP", f.step3, "BOTTOM", 0, -10)
	-- One part alone: the steps' heads and the buttons go (the page's own heading says what it is).
	if part then
		f.step1:Hide()
		f.step3:Hide()
		-- (the button stays under the choices in the /shy window: nothing changes until it is pressed)
		if plan or part ~= "choose" then
			for _, piece in ipairs({ f.lay, f.hint, f.follow, f.followSay }) do piece:Hide() end
		end
		f.hot:ClearAllPoints()
		f.hot:SetPoint("TOPLEFT")
		if part == "board" then
			f.hot:Hide()   -- (it still says which keys the board is drawn for)
			board:SetPoint("TOP", f, "TOP", 0, 0)
		else
			board:Hide()
		end
	end
	board:SetPoint("LEFT", f, "LEFT", math.floor((width - hands) / 2), 0)
	-- Whose hotkeys the keys are drawn for, and whether those are the ones bound now.
	f.whose = UI.Text(board, "", 11, true, C.head)
	f.whose:SetPoint("TOPRIGHT")
	f.caps = {}
	for side, shift in ipairs({ "", "SHIFT-" }) do
		local left = (side - 1) * (VIEW.span * unit + VIEW.apart)
		local caption = UI.Text(board, side == 1 and "Keys" or "With Shift", 11, true, C.dim)
		caption:SetPoint("TOPLEFT", left, 0)
		local function Place(key, x, row)
			local cap = NewCap(board, size, high)
			cap:SetPoint("TOPLEFT", left + math.floor(x * unit), -(VIEW.caption + (row - 1) * (high + VIEW.inner)))
			cap.key = shift .. key
			cap.letter:SetText(Cap(key))
			-- (a key of yours that does something now and gets a button of its own: marked, said on its hover)
			cap.mark = cap:CreateTexture(nil, "OVERLAY")
			cap.mark:SetSize(VIEW.mark, VIEW.mark)
			cap.mark:SetPoint("TOPRIGHT", -4, -5)
			cap.mark:SetColorTexture(1, 1, 1, 1)
			Theme.Tint(cap.mark, C.alert, 1)
			cap.mark:Hide()
			f.caps[#f.caps + 1] = cap
			return cap
		end
		for row, line in ipairs(BOARD) do
			for i, key in ipairs(line.keys) do Place(key, line.x + i - 1, row) end
		end
		for _, m in ipairs(MOUSE) do Place(m.key, VIEW.mouse, m.row) end
	end

	-- The level: a slider from 1 to the top, a notch where anything changes, a step to the change before and after.
	local top = GetMaxLevelForPlayerExpansion()
	local function Mine() return math.max(1, math.min(top, UnitLevel("player"))) end
	local function Step(by)
		return function()
			local at = view.level or Mine()
			for level = at + by, by > 0 and top or 1, by do
				if view.changes and (#view.changes[level] > 0 or (view.plays and view.plays[level])) then
					f:At(level)
					return
				end
			end
		end
	end
	f.before = UI.GlyphButton(f, Shy.Skin.GLYPH.caret, VIEW.arrow, Step(-1))
	f.before.glyph:SetRotation(-math.pi / 2)
	f.after = UI.GlyphButton(f, Shy.Skin.GLYPH.caret, VIEW.arrow, Step(1))
	f.after.glyph:SetRotation(math.pi / 2)
	local reach = width - 2 * (VIEW.arrow + GAP)
	f.level = UI.Slider(f, "At level", 1, top, 1, function() return view.level or Mine() end, function(v)
		f:At(v)
	end, { width = reach, format = function(v)
		return v == Mine() and ("%d, yours"):format(v) or tostring(v)
	end })
	f.level:SetPoint("TOPLEFT", board, "BOTTOMLEFT", VIEW.arrow + GAP - math.floor((width - hands) / 2), -14)
	f.before:SetPoint("BOTTOMRIGHT", f.level, "BOTTOMLEFT", -GAP, -4)
	f.after:SetPoint("BOTTOMLEFT", f.level, "BOTTOMRIGHT", GAP, -4)
	f.notches = {}

	-- What changes at the level shown (or, when nothing does, at the next level that changes).
	-- (a caption with a hairline to the right, as the window's captions are)
	f.turnsHead = UI.Text(f, "", 11, true, C.dim)
	f.turnsHead:SetPoint("TOPLEFT", f.level, "BOTTOMLEFT", -(VIEW.arrow + GAP), -14)
	f.turnsRule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(f.turnsRule, C.border, 0.7)
	f.turnsRule:SetHeight(1)
	f.turnsRule:SetPoint("LEFT", f.turnsHead, "RIGHT", 10, 0)
	f.turnsRule:SetPoint("RIGHT", f, "RIGHT")
	f.turns = {}
	local column = math.floor((width - GAP) / 2)
	-- A row: the key on its plate (as wide as its words), the ability's picture, its name, what is new under it.
	local plateW = 54
	function f:Turn(i)
		local row = self.turns[i]
		if row then return row end
		row = CreateFrame("Frame", nil, self)
		row:SetSize(column, VIEW.turnRow)
		row.plate = CreateFrame("Button", nil, row)
		row.plate:SetHeight(20)
		row.plate:SetPoint("RIGHT", row, "LEFT", plateW, 0)
		UI.KeyPlate(row.plate)
		row.key = UI.Text(row.plate, "", 11, true, C.head)
		row.key:SetPoint("CENTER")
		row.well = CreateFrame("Frame", nil, row)
		row.well:SetSize(Shy.Slot.SIZES.small, Shy.Slot.SIZES.small)
		row.well:SetPoint("LEFT", plateW + 8, 0)
		row.icon = row.well:CreateTexture(nil, "ARTWORK")
		row.icon:SetAllPoints()
		row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = Shy.Slot.SIZES.small, hover = false })
		row.title = UI.Text(row, "", 13)
		row.title:SetPoint("TOPLEFT", row.well, "TOPRIGHT", 8, 1)
		row.sub = UI.Text(row, "", 11, false, C.dim)
		row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
		for _, text in ipairs({ row.title, row.sub }) do
			text:SetWidth(column - plateW - 8 - Shy.Slot.SIZES.small - 8)
			text:SetWordWrap(false)
		end
		self.turns[i] = row
		return row
	end
	for i = 1, VIEW.turns * 2 do f:Turn(i) end
	f.more = Hot.More(f, width, function()
		view.allTurns = not view.allTurns
		if f.Turns then f.Turns(view.level) end
		if f.resized then f.resized() end
	end)
	-- (as tall as the hotkeys' piece and the rows of what changes at the level shown: Turns sets it)
	local function Above()
		local top = part == "board" and 0 or (f.step1:GetHeight() + 12 + f.hot:GetHeight() + (plan and 0 or HOT.buttons) + 24 + f.step3:GetHeight() + 10)
		return top + board:GetHeight() + 14 + VIEW.ruler + 14 + 16 + 6
	end
	f:SetSize(width, Above() + VIEW.turns * VIEW.turnRow + 16)

	-- A key's hover: what its macro is for, and every ability it casts as you level; a key of yours that
	-- changes, what it does now.
	local function Changing(cap, sections)
		local change = cap.change
		if change and change.from ~= "" then
			sections[#sections + 1] = { rows = { { text = ("Now this key is %s. It gets a button of its own, and putting your keys back returns it."):format(
				BindingCalled(change.from)), color = C.alert } } }
		end
		return sections
	end
	local function Hover(cap)
		local job = cap.job
		if not job and cap.stance then
			local rows = { { text = "1, 2 and 3: " .. cap.stance }, { text = "They stand on the small bar under your character, each with its key in its corner.", color = C.dim } }
			if cap.keep then rows[#rows + 1] = { text = ("Your build's %s: keep it on."):format(cap.keep), color = C.good } end
			Shy.Hover.Show(cap, { title = "Stance bar", note = Keys.Key(cap.key), sections = Changing(cap, { { rows = rows } }) }, { side = "TOP" })
			return
		end
		if not job and cap.extra then
			Shy.Hover.Show(cap, { title = "Extra button", note = Keys.Key(cap.key),
				sections = Changing(cap, { { rows = { { text = ("Yours to fill, on the %s flyout."):format(cap.side) } } } }) },
				{ side = "TOP" })
			return
		end
		if not job then return end
		local rows = {}
		for _, step in ipairs(view.story[job] or {}) do
			rows[#rows + 1] = { icon = step.icon, text = step.name or job.what,
				right = (step.talent and "Talent, level %d" or "Level %d"):format(step.level),
				rightColor = C.dim, done = step.level <= view.level }
		end
		local sections = { { rows = { { text = job.what } } } }
		if #rows > 1 or (rows[1] and rows[1].text ~= job.what) then sections[2] = { title = "As you level", rows = rows } end
		if cap.waits then   -- (another stands in here: say whose key it is, waiting at your trainer)
			sections[#sections + 1] = { rows = { { text = ("%s comes here once you learn it at your trainer."):format(cap.home.name),
				color = C.alert } } }
		end
		if cap.busy then
			sections[#sections + 1] = { rows = { { text = ("Your %s does %s now. Have your hotkeys set up, or bind it to an action button, and %s goes there."):format(
				Keys.Key(job.key), cap.busy, job.name), color = C.alert } } }
		end
		Shy.Hover.Show(cap, { title = job.name, note = Keys.Key(cap.key), sections = Changing(cap, sections) }, { side = "TOP" })
	end
	for _, cap in ipairs(f.caps) do
		cap:SetScript("OnEnter", Hover)
		cap:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	end

	-- Every cap at a level: the job standing on its key then, else the one whose key it is (dim: where it
	-- stands meanwhile, or the level it comes at), else nothing of ours.
	local function Paint(level)
		local mine = Keys.Mine()
		local keep = mine and Keys.Keep(mine.opts, level)   -- (the aura, stance or form your build stays in then)
		local at = view.levels and view.levels[level] or {}
		local on, home, fresh = {}, {}, {}
		for job, info in pairs(at) do
			if info.key then on[info.key] = job end
		end
		for _, job in ipairs(view.jobs or {}) do
			if job.key then home[job.key] = job end
		end
		for _, turn in ipairs(view.changes and view.changes[level] or {}) do
			if turn.key then fresh[turn.key] = true end
		end
		for _, cap in ipairs(f.caps) do
			local job = on[cap.key]
			local own = home[cap.key]
			if view.bare then job, own = nil, nil end   -- (as it was before: no ability of ours on any key)
			cap.job = job or own
			cap.home = own
			cap.waits = own and job and own ~= job and level == math.max(1, math.min(top, UnitLevel("player"))) and Keys.CouldTrain(own) or nil
			cap.busy = own and Keys.Busy(own, mine and mine.opts) or nil
			cap.soon:SetText("")
			cap.change = view.changing and view.changing[cap.key] or nil
			cap.mark:SetShown(cap.change ~= nil and cap.change.from ~= "")
			cap.extra, cap.keep = nil, nil
			if job then
				local info = at[job]
				-- (its key does something else in the hotkeys drawn: the ability faint, and what the key does)
				local other = cap.busy and cap.busy ~= "nothing"
				cap.icon:SetTexture(info.icon or ICON)
				cap.icon:SetAlpha(other and 0.35 or 1)
				cap.slot:Empty(false)
				cap.slot:Fresh(fresh[cap.key] == true)
				cap.name:SetText(other and cap.busy or job.name)
				Theme.Ink(cap.name, cap.busy and C.alert or C.text)
				-- (the one your build stays in, on its key of 1 2 3: its name in green)
				if job.spell and keep and info.name == keep.name then
					cap.keep = keep.word
					if not cap.busy then Theme.Ink(cap.name, C.good) end
				end
				cap:SetAlpha(1)
			elseif own then
				local first = view.story[own] and view.story[own][1]
				local now = at[own]
				cap.icon:SetTexture(nil)
				cap.slot:Empty(true)
				cap.slot:Fresh(false)
				if now then   -- standing on another key meanwhile: its picture faint, and where it is
					cap.icon:SetTexture(now.icon or ICON)
					cap.icon:SetAlpha(0.35)
					cap.name:SetText(now.key and ("on " .. (now.key:find("^SHIFT%-") and "Shift " or "") .. Cap(now.key)) or own.name)
				else
					cap.soon:SetText(first and first.level > level and tostring(first.level) or "")
					cap.name:SetText(own.name)
				end
				-- (a key that does something else, in the hotkeys drawn: what it does, so yours read as yours)
				if cap.busy and cap.busy ~= "nothing" and not now then
					cap.soon:SetText("")
					cap.name:SetText(cap.busy)
				end
				-- (at your level, its ability waits at your trainer: said in gold)
				if level == math.max(1, math.min(top, UnitLevel("player"))) and Keys.CouldTrain(own) and not now then
					cap.name:SetText("Train")
					Theme.Ink(cap.name, C.alert)
				end
				Theme.Ink(cap.name, C.dim)
				cap:SetAlpha(1)
			else
				-- 1 2 3 for a class with a stance bar: what you stay in, as the game's bar has it.
				-- (where the key presses the stance bar in the keys drawn; or nothing yet, and a layout gives it that)
				local pressed = mine and tonumber(cap.key) and tonumber(cap.key) <= FORM_KEYS and Keys.Doing(cap.key)
				local stance = pressed and tonumber(pressed:match("^SHAPESHIFTBUTTON(%d+)$"))
				local icon, _, _, spell
				if stance then icon, _, _, spell = GetShapeshiftFormInfo(stance) end
				cap.stance = stance and (mine.opts.stances or "what you stay in") or nil
				cap.icon:SetTexture(icon)
				cap.icon:SetAlpha(1)
				cap.slot:Empty(icon == nil)
				cap.slot:Fresh(false)
				-- A key you move with says which way (forward and back by name), its plate in your color.
				local scheme = Scheme()
				local moving = scheme.move[cap.key]
				-- A key of the number row with no job: an extra button, on one of the flyouts.
				local extra = not stance and view.board and view.board[cap.key]
				local bar, place = (extra or ""):match("^(MULTIACTIONBAR%dBUTTON)(%d+)$")
				cap.extra = (bar == HOT.plain or bar == HOT.bar) and tonumber(place) or nil
				cap.side = bar == HOT.plain and "left" or "right"
				-- Any other key that does something of the game's, in the hotkeys drawn: what it does.
				local command = not (stance or moving or cap.extra) and Keys.Doing(cap.key) or ""
				local does = command ~= "" and (view.bare or not Slots(command, {})) and GetBindingName(command) or nil
				-- (a bar's button, with everything as you had it: said short, the main bar's by its place)
				if does and Slots(command, {}) then does = command:match("^ACTIONBUTTON(%d+)$") and ("Bar " .. command:match("%d+$")) or "Bar" end
				cap.name:SetText(spell and C_Spell.GetSpellName(spell) or cap.key == scheme.forward and "Forward"
					or cap.key == scheme.back and "Back" or moving and "Move" or cap.extra and "Extra" or does or "")
				Theme.Ink(cap.name, moving and C.head or (cap.extra or does) and C.dim or C.text)
				-- (the one your build stays in: its name in green)
				cap.keep = nil
				if stance and spell and keep and C_Spell.GetSpellName(spell) == keep.name then
					cap.keep = keep.word
					Theme.Ink(cap.name, C.good)
				end
				cap:SetTone(moving and Theme.Accent or nil, moving)
				cap:SetAlpha((icon or stance or moving or cap.extra) and 1 or does and 0.8 or 0.45)
			end
			if job or own then cap:SetTone(nil, false) end
		end
		-- Your bars as they are now: on each key, what its button holds.
		for _, cap in ipairs(view.now and mine and f.caps or EMPTY) do
			local command = GetBindingAction(cap.key)
			local slots = command ~= "" and Slots(command, mine.opts) or nil
			local kind, id
			if slots then kind, id = GetActionInfo(slots[1]) end
			if kind then
				local name = kind == "macro" and C_ActionBar.GetActionText(slots[1]) or kind == "spell" and C_Spell.GetSpellName(id)
					or kind == "item" and C_Item.GetItemNameByID(id) or ""
				cap.icon:SetTexture(C_ActionBar.GetActionTexture(slots[1]) or ICON)
				cap.icon:SetAlpha(1)
				cap.slot:Empty(false)
				cap.name:SetText(name or "")
				Theme.Ink(cap.name, C.text)
				cap:SetAlpha(1)
				cap.job, cap.stance, cap.extra = nil, nil, nil
			end
		end
	end

	-- What changes at a level, said a row each.
	local SAY = {
		new = function(turn) return "New: " .. (turn.name or turn.job.what) end,
		moved = function() return "Moves here meanwhile" end,
		grows = function(turn) return "Now " .. (turn.name or turn.job.what) end,
	}
	local function Turns(level)
		f.Turns = Turns
		local shown, list = level, view.changes and view.changes[level] or {}
		if #list == 0 then
			for next = level + 1, top do
				if #view.changes[next] > 0 then
					shown, list = next, view.changes[next]
					break
				end
			end
		end
		if #list == 0 then
			f.turnsHead:SetText("Nothing changes after this level")
		elseif shown == level then
			f.turnsHead:SetText(("At level %d"):format(level))
		else
			f.turnsHead:SetText(("Next, at level %d"):format(shown))
		end
		-- Two columns, down the first and then the second; the first few, and the rest with Show more.
		local most = VIEW.turns * 2
		local shown = view.allTurns and #list or math.min(#list, most)
		local down = math.max(1, math.ceil(shown / 2))
		for i = 1, math.max(shown, #f.turns) do
			local row = i <= shown and f:Turn(i) or f.turns[i]
			local turn = i <= shown and list[i] or nil
			row:SetShown(turn ~= nil)
			if turn then
				local c, r = math.floor((i - 1) / down), (i - 1) % down
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", f.turnsHead, "BOTTOMLEFT", c * (column + GAP), -8 - r * VIEW.turnRow)
				row.plate:SetShown(turn.key ~= nil)
				row.key:SetText(turn.key and Hot.Plate(turn.key) or "")
				row.plate:SetWidth(math.max(22, math.ceil(row.key:GetStringWidth()) + 12))
				row.icon:SetTexture(turn.icon or ICON)
				row.title:SetText(turn.job.name)
				row.sub:SetText(SAY[turn.kind](turn))
			end
		end
		local hidden = #list - shown
		f.more:Set(hidden > 0 and ("Show %d more"):format(hidden) or (view.allTurns and #list > most and "Show fewer") or nil)
		f.more:ClearAllPoints()
		f.more:SetPoint("TOPLEFT", f.turnsHead, "BOTTOMLEFT", 0, -8 - down * VIEW.turnRow - 4)
		f:SetHeight(Above() + down * VIEW.turnRow + (f.more:IsShown() and (HOT.moreTall + 8) or 4))
	end

	-- A notch under the slider at every level where something changes.
	local function Notches()
		local track = f.level.slider
		local knob = track:GetHeight()
		local reachable = track:GetWidth() - knob
		for _, notch in ipairs(f.notches) do notch:Hide() end
		local n = 0
		local plays = view.plays or {}
		for level = 2, top do
			if #view.changes[level] > 0 or level == Mine() or plays[level] then
				n = n + 1
				local notch = f.notches[n]
				if not notch then   -- a mark is a click to its level: a little target round a fine line
					notch = CreateFrame("Button", nil, f.level)
					notch:SetSize(VIEW.notch[1] + 6, VIEW.notch[2] + 8)
					notch.line = notch:CreateTexture(nil, "ARTWORK")
					notch.line:SetColorTexture(1, 1, 1, 1)
					notch.line:SetPoint("TOP")
					notch:SetScript("OnClick", function(self) f:At(self.at) end)
					notch:SetScript("OnEnter", function(self) self.line:SetAlpha(1) Theme.Tint(self.line, C.head, 1) end)
					notch:SetScript("OnLeave", function(self) self:Paint() end)
					f.notches[n] = notch
				end
				notch.at = level
				notch:ClearAllPoints()
				notch:SetPoint("TOP", track, "BOTTOMLEFT", math.floor(knob / 2 + (level - 1) / (top - 1) * reachable), 0)
				-- (yours in gold, longest; where how you play changes in your color, longer; any other change dim)
				local yours, play = level == Mine(), plays[level]
				notch.line:SetSize(VIEW.notch[1], VIEW.notch[2] + (yours and 4 or play and 2 or 0))
				function notch:Paint()
					Theme.Tint(self.line, yours and C.alert or play and Theme.Accent or C.dim, 1)
				end
				notch:Paint()
				notch:Show()
			end
		end
	end

	function f:At(level)
		view.level = math.max(1, math.min(top, level))
		if not view.levels then return end
		Paint(view.level)
		Turns(view.level)
		self.level:Refresh()
		for _, arrow in ipairs({ { self.before, view.level > 1 }, { self.after, view.level < top } }) do
			arrow[1]:SetEnabled(arrow[2])
			arrow[1]:SetAlpha(arrow[2] and 1 or 0.4)
		end
		Shy:Fire("SHY_KEYS_LEVEL", view.level)   -- (the guide to playing follows)
	end

	function f:Refresh()
		if Drawn(self) then return end
		local mine = Keys.Mine()
		local laid = mine ~= nil and Keys.Has(mine.addon)
		self.hot:Refresh()
		-- Step 1's sentence: what the choice lit (or under the mouse) gives you, and when it is done.
		local shown, state = self.hot.shown, self.hot:State()
		local done = plan and "Finish" or "the button below"
		if not mine then
			self.status:SetText("No keys for this class yet.")
		elseif plan == nil and laid and Keys.Old(mine.addon) then
			self.status:SetText("Your keys have a new layout, drawn below: water and each potion on a key of its own, what you stay in on 1 2 3, and what your people alone can do on Shift + 1 and 2. Yours stay as they are until you press Update my keys.")
		elseif shown == "shy" and state == "shy" then
			local _, name = nil, nil
			if mine.opts.build then _, name = mine.opts.build() end
			self.status:SetText(("Your keys are set up%s. An ability comes to its key when you learn it; move one and it stays where you put it."):format(name and (" for " .. name) or ""))
		elseif shown == "shy" then
			self.status:SetText(("Every ability gets its own key, close to where your hand rests, and comes to it as you learn it. Nothing changes until you press %s."):format(done))
		elseif shown == "own" then
			self.status:SetText("Your hotkeys stay as they are, and abilities go on the keys you already use. Any whose key does something else waits.")
		else
			self.status:SetText(state ~= "off" and "Every button and hotkey goes back exactly as you had it."
				or "Everything stays exactly as you have it now.")
		end
		self.step1:Fit()
		self.step3.title:SetText(shown == "shy" and "Your new keys" or "Your keys")
		-- The button: the choice looked at, when it isn't the one in use.
		local pending = self.hot:Pending()
		local block = pending and pending ~= "off" and not laid and self.hot.says and self.hot.says.block
		self.lay:SetLabel(self.hot:Label())
		self.lay:SetPrimary(mine ~= nil and pending ~= nil and not block)
		self.lay:SetUsable(mine ~= nil and pending ~= nil and not block,
			not mine and "No keys for this class yet." or block or "This is what you use now. Pick another choice to see it first.")
		self.hint:SetText(pending and "Nothing changes until you press it." or "")
		self.follow:Refresh()
		-- (the choice alone, or what it changes alone: no keys drawn, and as tall as that part)
		if part == "choose" or part == "changes" then
			for _, piece in ipairs({ board, self.level, self.before, self.after, self.turnsHead, self.turnsRule, self.more }) do piece:Hide() end
			for _, row in ipairs(self.turns) do row:Hide() end
			self:SetHeight(self.hot:GetHeight() + ((plan == nil and part == "choose") and HOT.buttons or 0))
			return
		end
		-- The keys of yours that change, for the caps' marks; the board, for the number row's extra buttons; and
		-- everything as it was before: the keys alone, what each does, with no ability on them.
		local shown, standing = self.hot.shown, self.hot.shown == self.hot:State()
		-- (an earlier layout's keys: the button that draws them as they are, where the hint stands)
		local old = plan == nil and laid and Keys.Old(mine.addon)
		if not old then view.now = false end
		self.flip:SetShown(old)
		self.flip.says = view.now and "Show the new layout" or "Show what I have now"
		self.flip:SetLabel(self.flip.says)
		if old then self.hint:SetText("") end
		view.changing, view.board, view.bare = nil, nil, shown == "off" or view.now == true
		if mine and shown == "shy" then
			view.board = Keys.Board(mine.opts)
			if not Hot.On() then
				view.changing = {}
				for _, change in ipairs(Hot.Plan(mine.opts).changes) do view.changing[change.key] = change end
			end
		end
		self.whose:SetText(view.now and "What you have now" or old and "Preview: the new layout"
			or (standing and "In use: %s" or "Preview: %s"):format(self.hot:Title(shown)))
		Theme.Ink(self.whose, (view.now or (standing and not old)) and C.head or C.alert)
		if mine then
			view.levels, view.changes, view.story, view.jobs = Keys.Story(mine.jobs, mine.opts, mine.addon)
			view.plays = Keys.PlayLevels(mine.opts)
			Notches()
			self:At(view.level or Mine())
		end
		-- (Show more is shown by what it has to say: Turns)
		for _, piece in ipairs({ board, self.level, self.before, self.after, self.turnsHead, self.turnsRule }) do
			piece:SetShown(mine ~= nil)
		end
		for _, row in ipairs(self.turns) do
			if not mine then row:Hide() end
		end
	end
	f:SetScript("OnShow", f.Refresh)
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Refresh() end
	end)
	return f
end


---------------------------------------------------------------------------
-- How you move: the choice
---------------------------------------------------------------------------

-- Two choices, each with a little board: the keys you move with lit in your color.
local MINI = { cap = 15, gap = 2, tall = 76, apart = 12, rows = { { 0, "QWERT" }, { 0.35, "ASDFG" }, { 0.75, "ZXCVB" } } }

-- f:Light(lit): the keys lit, lit(letter) saying which.
local function MiniBoard(parent, lit)
	local f = CreateFrame("Frame", nil, parent)
	local step = MINI.cap + MINI.gap
	f:SetSize(math.ceil((5 + MINI.rows[#MINI.rows][1]) * step), #MINI.rows * step)
	local caps = {}
	for r, row in ipairs(MINI.rows) do
		for i = 1, #row[2] do
			local letter = row[2]:sub(i, i)
			local cap = CreateFrame("Button", nil, f)
			cap:SetSize(MINI.cap, MINI.cap)
			cap:SetPoint("TOPLEFT", math.floor((row[1] + i - 1) * step), -(r - 1) * step)
			cap:EnableMouse(false)   -- (a picture: the click is the choice's it stands on)
			UI.KeyPlate(cap)
			cap.words = UI.Text(cap, letter, 9, true, C.dim)
			cap.words:SetPoint("CENTER")
			caps[letter] = cap
		end
	end
	function f:Light(which)
		for letter, cap in pairs(caps) do
			local on = which(letter) == true
			cap:SetTone(on and Theme.Accent or nil, on)
			Theme.Ink(cap.words, on and C.head or C.dim)
		end
	end
	if lit then f:Light(lit) end
	return f
end

local function Choice(parent, width, scheme, words, onPick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, MINI.tall)
	UI.KeyPress(b, { fill = C.bg })
	b.board = MiniBoard(b, function(letter) return Keys.SCHEMES[scheme].move[letter] end)
	b.board:SetPoint("LEFT", 14, 0)
	b.title = UI.Text(b, Keys.SCHEMES[scheme].name, 16, true, C.head)
	b.title:SetPoint("TOPLEFT", b.board, "TOPRIGHT", 16, 2)
	b.say = UI.Text(b, words, 12, false, C.dim)
	b.say:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
	b.say:SetPoint("RIGHT", -12, 0)
	b.say:SetJustifyH("LEFT")
	b.say:SetWordWrap(true)
	b.say:SetMaxLines(2)
	b:SetScript("OnClick", function() onPick(scheme) end)
	return b
end

---------------------------------------------------------------------------
-- Your hotkeys: the choice, and what of yours it changes
---------------------------------------------------------------------------

-- Three choices side by side, each a state your keys can be in, said as a player would say it: "Set it up for
-- me" (every ability on its key, the hotkeys set to match: recommended), "Keep my hotkeys" (the same abilities
-- on the keys you already have) and "How I had it" (nothing laid out: every button and hotkey as you had it).
-- Each has its title, its name inside a sentence (name), its word on setup's rail (brief), what the button
-- says to make it (act) and a sentence. The one in use says so. A click, or the mouse
-- on one, looks at it: the keys are drawn for that choice and nothing is bound. Under them, what the choice
-- looked at does to what is yours, in a sentence with a tick (nothing of yours is lost), then what loses its
-- key, the keys let go of a bar, the macros that go among the account's, and in gold why it can't be used yet.
-- In the /shy window one button makes the choice looked at (f:Use; the keys' panel has it); in setup the choice
-- is plan.keys.pick ("shy", "own", "off"), made on Finish.
--   Keys.Hotkeys.Panel(parent, width, plan, onPick)   f:Refresh()
--   f:State()      what is in use: "shy", "own", "off", or "set" (the hotkeys set and no keys laid out here)
--   f:Pending()    the choice looked at, when it isn't the one in use; nil in setup
--   f:Label()      what the button says: what it would do
--   f:Use()        makes it.  -> true, or false in a fight
--   f.shown        the choice the keys are drawn for
local HOTVIEW = {
	tall = 62, apart = 12, pad = 14, tick = 14, most = 5,
	-- The list of your keys that change: a row (two lines) and its caption; the key's plate and the text after
	-- it; the choice and the key that moves, at the right; the numbers beside the caption.
	row = 40, caption = 16, plate = 22, lead = 96, choice = 170, target = 118, tallyWidth = 230,
	rows = 6,                -- the rows shown before "Show N more" (the ones a hand relies on come first)
	choose = 118,            -- a choice on setup's page of choices alone: tall enough for its sentence whole
	more = 22,               -- that line's height
	order = { "shy", "own", "off" },
	picks = {
		shy = { title = "Set it up for me", name = "your new keys", brief = "set up", tag = "Recommended", act = "Set up my keys",
			say = "Every ability gets its own key. What a key did before moves to Ctrl + that key." },
		own = { title = "Keep my hotkeys", name = "your own hotkeys", brief = "on my hotkeys", tag = "Not recommended", act = "Keep my hotkeys",
			say = "Abilities go on the keys you already use. Any whose key is taken is left off." },
		off = { title = "How I had it", name = "how you had it", brief = "left alone", tag = "Yours", act = "Put it all back",
			say = "Your buttons and hotkeys, exactly as you had them." },
	},
}
-- The jobs that can't stand on the keys as they are bound now: their keys do something else.
local function Stuck(mine)
	local out = {}
	local was = live
	live = true
	for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
		if job.key and not Pressable(job.key, mine.opts, job.spare) then out[#out + 1] = job end
	end
	live = was
	return out
end

-- What a pick does to your keys, for whoever says it: safe (the sentence), notes (what loses its key, what is
-- let go, which abilities are left off), warn (a flyout's bar is off), changes (how many keys of yours change).
function Hot.Says(pick, plan)
	local mine = watched[1]
	local says = { notes = {}, changes = 0 }
	if pick == "off" then
		says.safe = ((mine and Keys.Has(mine.addon)) or Hot.On()) and "Every button and hotkey goes back exactly as you had it."
			or "This is what you have now. Nothing of yours is changed."
		return says
	end
	-- What of yours a layout would move to a free button: said before anything is done.
	local moves = mine and Keys.Displaces(mine.addon, mine.jobs, mine.opts) or EMPTY
	if #moves > 0 then
		says.notes[#says.notes + 1] = ("%s of your own move to a free button: %s. %s back where %s when you put your keys back."):format(
			#moves == 1 and "One" or tostring(#moves), Several(moves, HOTVIEW.most), #moves == 1 and "It goes" or "They go", #moves == 1 and "it was" or "they were")
	end
	-- The macros a layout comes to: among the account's when the character's are full, and no layout without room.
	local space = mine and Keys.Space(mine.addon, mine.jobs, mine.opts)
	if space and space.short > 0 then
		says.block = ("Not enabled yet: your keys need %d macros and there is room for %d. Delete %d you don't use, this character's or the account's, and they can be laid out. Your own macros are never touched here."):format(
			space.need, space.need - space.short, space.short)
	elseif space and space.spill > 0 then
		says.notes[1] = ("This character has room for %d of your keys' %d macros, so %d go among the account's, which every character sees. They are removed when you go back; your own are never touched."):format(
			math.max(0, space.character), space.need, space.spill)
	end
	if pick == "own" then
		says.safe = Hot.On() and "Your own hotkeys come back, each as it was before."
			or "Your hotkeys stay as they are. Only a key that does nothing now may be given a button."
		-- (the abilities that wait, their keys doing something else: listed on the page, a row each)
		local stuck = mine and not Hot.On() and Stuck(mine) or {}
		if #stuck > 0 then says.waits = stuck end
		return says
	end
	-- The abilities whose keys you keep: left off, said by name.
	local keep = Keeping()
	if keep and mine then
		local off = {}
		local ins = StandIns(Scheme(), keep) or EMPTY   -- (one you gave another key isn't left off)
		for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
			-- (nor one whose kept key presses its button anyway: it stands, as you have it)
			if job.key and keep[job.key] and not ins[job.key] and not Keys.Moving(job.key) and Hot.Pressing(job.key, mine.opts) == "" then
				off[#off + 1] = ("%s (%s)"):format(job.name, Keys.Key(job.key))
			end
		end
		-- (said on the page by each kept key's row, not again under the sentence)
		if #off > 0 then says.keptOff = ("Left off, because you keep their keys: %s."):format(Several(off, HOTVIEW.most)) end
	end
	if Hot.On() then
		-- (counted as the plan counted them: the keys that did something before)
		local state = Hot.State()
		local kept = 0
		for key in pairs(state and state.set or EMPTY) do
			if (state.was[key] or "") ~= "" then kept = kept + 1 end
		end
		says.safe = kept > 0 and ("%d of your hotkeys were changed. Each is saved, and one click puts them all back."):format(kept)
			or "Your hotkeys already matched: nothing of yours was changed."
		return says
	end
	local will = Hot.Plan(mine and mine.opts)
	for _, change in ipairs(will.changes) do
		if change.from ~= "" then says.changes = says.changes + 1 end
	end
	local back = plan and "one click in /shy keys puts them all back" or "one click puts them all back"
	if says.changes > 0 then
		says.safe = ("%d of your hotkeys change. Each is saved, and %s."):format(says.changes, back)
	elseif #will.changes > 0 then
		says.safe = ("None of your hotkeys change: %d keys that do nothing now get a button."):format(#will.changes)
	else
		says.safe = "Your hotkeys already match: nothing of yours changes."
	end
	-- (what loses its key is said key by key in the list under it: Hot.Yours)
	if #will.freed > 0 then
		local keys = {}
		for i, key in ipairs(will.freed) do keys[i] = Keys.Key(key) end
		says.notes[#says.notes + 1] = ("These no longer press a bar: %s."):format(Several(keys, 12))
	end
	if not will.bar then says.warn = "A side bar is off, so the number row's buttons don't all show yet. The console's layout turns both on." end
	return says
end

-- A choice: its name across the top, under it what it is called for ("Recommended") and, on the one in use, a
-- tick and "In use" at the right; then its sentence. The keys under the tiles are its picture.
local function HotTile(parent, width, pick, onPick)
	local def = HOTVIEW.picks[pick]
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOTVIEW.tall)
	UI.KeyPress(b, { fill = C.bg })
	b.title = UI.Text(b, def.title, 15, true, C.head)
	b.title:SetPoint("TOPLEFT", HOTVIEW.pad, -HOTVIEW.pad)
	b.title:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.title:SetJustifyH("LEFT")
	b.title:SetWordWrap(false)
	b.tag = UI.Text(b, def.tag, 11, true, pick == "shy" and C.good or C.dim)
	b.tag:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
	b.use = UI.Text(b, "Now", 11, true, C.good)   -- (what you have now, whatever is lit)
	b.use:SetPoint("TOP", b.tag, "TOP")
	b.use:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.tick = b:CreateTexture(nil, "ARTWORK")
	b.tick:SetTexture(Shy.Skin.GLYPH.tick)
	b.tick:SetSize(10, 10)
	b.tick:SetPoint("RIGHT", b.use, "LEFT", -5, 0)
	Theme.Tint(b.tick, C.good, 1)
	-- (its sentence isn't shown on the card: the line under the cards says what the lit one does, whole)
	b.say = UI.Text(b, def.say, 12, false, C.dim)
	b.say:Hide()
	b.say:SetPoint("TOPLEFT", b.tag, "BOTTOMLEFT", 0, -9)
	b.say:SetPoint("RIGHT", -HOTVIEW.pad, 0)
	b.say:SetJustifyH("LEFT")
	b.say:SetWordWrap(true)
	b.say:SetMaxLines(3)
	b:SetScript("OnClick", function() onPick(pick) end)
	return b
end

function Hot.Panel(parent, width, plan, onPick, part)
	local f = CreateFrame("Frame", nil, parent)
	local each = math.floor((width - (#HOTVIEW.order - 1) * HOTVIEW.apart) / #HOTVIEW.order)
	local tiles = {}
	function f:State()
		local mine = watched[1]
		if mine and Keys.Has(mine.addon) then
			-- (laid out, but on key bindings the hotkeys were never set for, a character's own: it stands on your keys)
			local mode = Keys.Mode()
			if mode == "shy" and not Hot.On() then return "own" end
			return mode
		end
		return Hot.On() and "set" or "off"
	end
	-- The choice lit: setup's pick; in the /shy window the one clicked, else the one in use, or the set-up
	-- while nothing is laid out (the one to try, drawn before it is made).
	local function Lit()
		if plan then
			local pick = plan.keys and plan.keys.pick
			return HOTVIEW.picks[pick] and pick or "off"   -- (left alone, "skip": drawn as you have them)
		end
		if HOT.viewing then return HOT.viewing end
		local state = f:State()
		-- (set up is your pick, but not set on these key bindings yet, a character's own: it is offered, every key listed)
		if state == "own" and Keys.Mode() == "shy" then return "shy" end
		return HOTVIEW.picks[state] and state ~= "off" and state or "shy"
	end
	function f:Pending()
		if plan then return nil end
		local lit = Lit()
		if lit ~= self:State() then return lit end
		-- (the choice in use, laid out by an earlier make of the layout: the new one is there to take)
		local mine = watched[1]
		return mine and lit ~= "off" and Keys.Old(mine.addon) and "new" or nil
	end
	function f:Title(pick)
		return HOTVIEW.picks[pick].name
	end
	function f:Label()
		local pending = self:Pending()
		if pending == "new" then return "Update my keys" end
		return pending and HOTVIEW.picks[pending].act or "In use"
	end
	function f:Use()
		local mine = watched[1]
		local pick = self:Pending()
		if not pick or not mine then return true end
		if InCombatLockdown() then
			Shy.core:Print("your keys can be changed once the fight is over.")
			return false
		end
		HOT.viewing = nil
		if pick == "new" then
			local result = Keys.Run(mine.addon, mine.jobs, mine.opts, true)
			if result then mine.waiting = result.waiting end
		elseif pick == "off" then
			Keys.Back(mine.addon)
		elseif Keys.Has(mine.addon) then
			Keys.SetMode(pick)
			mine.addon:Print(pick == "shy" and "your keys are set up now, hotkeys and all." or "your abilities are on your own hotkeys now.")
		else
			Keys.SetMode(pick)
			local result = Keys.Run(mine.addon, mine.jobs, mine.opts, true)   -- (every key it changes was listed)
			if result then mine.waiting = result.waiting end
		end
		return true
	end
	-- (the owner draws everything again, this piece with it; alone, it draws itself)
	local function Again(pick)
		Keys.look = Keys.look + 1
		if onPick then onPick(pick) else f:Refresh() end
	end
	-- A click looks, and it stays looked at; nothing is bound.
	local function Pick(pick)
		if plan then
			plan.keys = plan.keys or {}
			plan.keys.pick = pick
		else
			HOT.viewing = pick
		end
		Again(pick)
	end
	-- Pointed at, a choice is drawn (its keyboards are some 40 ms): drawn again only where what is shown changes,
	-- and a leave waits a frame, so passing from one tile to the next draws once and the one lit not at all.
	local function Look(pick)
		f.leaving = nil
		if f.looking == pick then return end
		local was = f.looking or Lit()
		f.looking = pick
		if (pick or Lit()) ~= was then Again() end
	end
	local function Leave()
		f.leaving = true
		C_Timer.After(0, function()
			if f.leaving then Look(nil) end
		end)
	end
	for i, pick in ipairs(HOTVIEW.order) do
		tiles[pick] = HotTile(f, each, pick, Pick)
		tiles[pick]:SetPoint("TOPLEFT", (i - 1) * (each + HOTVIEW.apart), 0)
		tiles[pick]:HookScript("OnEnter", function() Look(pick) end)
		tiles[pick]:HookScript("OnLeave", Leave)
	end
	f.tiles = tiles
	-- Step 2, what the choice changes: its title by the choice, its sentence that nothing of yours is lost, and at
	-- the right how many keys move, stay yours or wait.
	f.step2 = Hot.StepHead(f, 2, width)
	f.step2:SetPoint("TOPLEFT", 0, -(HOTVIEW.tall + 20))
	f.safe = f.step2.say
	f.tally = f.step2.side
	local indent = HOT.step + HOT.stepGap
	-- One part alone (a page of setup's walk): the choices, with what the lit one means under them; or what it
	-- changes, its sentence at the top and the list under it.
	f.part = part
	if part == "changes" then
		for _, tile in pairs(tiles) do tile:Hide() end
		f.step2:ClearAllPoints()
		f.step2:SetPoint("TOPLEFT")
		f.step2.plate:Hide()
		f.step2.title:Hide()
		f.safe:ClearAllPoints()
		f.safe:SetPoint("TOPLEFT")
		f.safe:SetWidth(width - HOTVIEW.tallyWidth)
		indent = 0
	elseif part == "choose" then
		f.step2:Hide()
		-- (each choice says what it is, whole; under them, what the lit one does to your keys)
		for _, tile in pairs(tiles) do
			tile:SetHeight(HOTVIEW.choose)
			tile.say:Show()
		end
		f.chosen = UI.Text(f, "", 13, false, C.text)
		f.chosen:SetPoint("TOPLEFT", 0, -(HOTVIEW.choose + 16))
		f.chosen:SetWidth(width)
		f.chosen:SetJustifyH("LEFT")
		f.chosen:SetWordWrap(true)
	end
	f.notes = UI.Text(f, "", 11, false, C.dim)
	f.notes:SetPoint("TOPLEFT", f.safe, "BOTTOMLEFT", 0, -6)
	f.notes:SetWidth(width - indent)
	f.notes:SetJustifyH("LEFT")
	f.warn = UI.Text(f, "", 11, false, C.alert)
	f.warn:SetWidth(width - indent)
	f.warn:SetJustifyH("LEFT")

	-- Every key of yours that changes, a row each across the page: the key on its plate and what it did (in gold
	-- when a hand relies on it), what happens to it in one line, the choice (the new key, or keep yours), and the
	-- key the thing that moves goes to: what the key did (Ctrl + it, unless you pick another), or the ability of
	-- a key you keep. Click that key, then press the one you want: it is checked and done at once. A key you move
	-- with is the board's whatever you pick: said, with no choice.
	f.caption = UI.Text(f, "", 11, false, C.dim)
	f.caption:SetJustifyH("LEFT")
	f.caption:SetWidth(width - indent)
	f.rows = {}
	local listening              -- the row whose key is being picked
	local function Listen(row, on)
		if row == nil then return end
		row.target:EnableKeyboard(on)
		row.target:SetScript("OnKeyDown", on and row.heard or nil)
	end
	local function Stop()
		local row = listening
		listening = nil
		if row then Listen(row, false) end
		return row
	end
	f.Stop = Stop
	-- What a key you pressed is picked for: done, or why not (said on the row, in red, until the next pick).
	-- A key that does something else, or is picked for something else, is asked about: sure, it is yours.
	local function Pick(entry, key)
		-- (in setup only noted: Finish does it, Not now forgets it)
		if entry.kept then return Hot.SetStandIn(entry.key, key, plan ~= nil) end
		return Hot.SetHome(entry.key, entry.from, key, plan ~= nil)
	end
	-- (sure of one thing, the key may yet ask another: a key picked for something else that did something before)
	local function Try(row, entry, key, ok, why, ask)
		row.err = not ok and not ask and why ~= "" and why or nil
		Again()
		if not ask then return end
		UI.Confirm(row.target, ask.text, ask.yes, function()
			local sure, failed = Hot.TakeOver(key, ask, plan ~= nil)
			if not sure then return Try(row, entry, key, false, failed) end
			Try(row, entry, key, Pick(entry, key))
		end)
	end
	local function Picked(row, key)
		Stop()
		Try(row, row.entry, key, Pick(row.entry, key))
	end
	-- (a fight is coming: the keyboard goes back to the game before it can't)
	f.guard = CreateFrame("Frame", nil, f)
	f.guard:RegisterEvent("PLAYER_REGEN_DISABLED")
	f.guard:SetScript("OnEvent", function()
		if Stop() then Again() end
	end)
	local function YourRow(i)
		local row = f.rows[i]
		if row then return row end
		row = CreateFrame("Frame", nil, f)
		row:SetSize(width, HOTVIEW.row)
		-- The key, on its plate.
		row.key = CreateFrame("Button", nil, row)
		row.key:SetHeight(HOTVIEW.plate)
		row.key:SetPoint("TOPRIGHT", row, "TOPLEFT", HOTVIEW.lead - 12, -3)   -- (against the words, as a key's legend)
		UI.KeyPlate(row.key)
		row.keyText = UI.Text(row.key, "", 12, true, C.head)
		row.keyText:SetPoint("CENTER")
		-- The key the thing that moves goes to: click, then press one (lit while it listens).
		row.target = CreateFrame("Button", nil, row)
		row.target:SetSize(HOTVIEW.target, HOTVIEW.plate)
		row.target:SetPoint("TOPRIGHT", 0, -3)
		row.target:RegisterForClicks("LeftButtonUp")
		UI.KeyPress(row.target, { fill = C.bg })
		row.targetText = UI.Text(row.target, "", 12, true, C.head)
		row.targetText:SetPoint("CENTER")
		row.target:SetScript("OnEnter", function(self)
			if listening ~= row then
				UI.Tip(self, "Pick a key", "Click, then press the key you want. Esc cancels; Backspace gives back the key we picked.")
			end
		end)
		row.target:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		row.target:SetScript("OnClick", function(self)
			UI.TipHide(self)
			if listening == row then
				Stop()
			elseif InCombatLockdown() then
				row.err = "Your keys can be changed once the fight is over."
			else
				Stop()
				row.err = nil
				listening = row
				Listen(row, true)
			end
			Again()
		end)
		-- (the middle and side mouse buttons are keys too; the left and right ones click)
		row.target:HookScript("OnMouseDown", function(_, button)
			local key = listening == row and HOT.mice[button]
			if key then Picked(row, Hot.Chord(key)) end
		end)
		row.heard = function(_, key)
			if HOT.metas[key] then return end
			if key == "ESCAPE" then
				Stop()
				Again()
			elseif key == "BACKSPACE" or key == "DELETE" then
				Picked(row, nil)
			else
				Picked(row, Hot.Chord(key))
			end
		end
		-- The new key, or keep yours.
		row.choice = UI.Segmented(row, { "New key", "Keep mine" }, function()
			return row.entry and row.entry.kept and 2 or 1
		end, function(i)
			Stop()
			row.err = nil
			if row.entry and not Hot.Keep(row.entry.key, i == 2, plan ~= nil) then row.err = "Your keys can be changed once the fight is over." end
			Again()
		end, { width = HOTVIEW.choice, height = HOTVIEW.plate })
		row.choice:SetPoint("TOPRIGHT", -(HOTVIEW.target + HOTVIEW.apart), -3)
		-- What it did, and what happens to it.
		row.head = UI.Text(row, "", 13)
		row.sub = UI.Text(row, "", 11, false, C.dim)
		for _, text in ipairs({ row.head, row.sub }) do
			text:SetJustifyH("LEFT")
			text:SetWordWrap(false)
		end
		row.head:SetPoint("TOPLEFT", HOTVIEW.lead, -2)
		row.sub:SetPoint("TOPLEFT", row.head, "BOTTOMLEFT", 0, -4)
		f.rows[i] = row
		return row
	end
	-- The jobs by key, for what a key becomes.
	local function ByKey()
		local mine, at = watched[1], {}
		if not mine then return at end
		for _, job in ipairs(Keys.Jobs(mine.jobs, mine.opts.build and (mine.opts.build()))) do
			if job.key then at[job.key] = job end
		end
		return at
	end
	-- The keys that turned the bar's pages, and the side keys that strafe now: lines under the rows, not a row each.
	f.paging = UI.Text(f, "", 11, false, C.dim)
	f.paging:SetWidth(width)
	f.paging:SetJustifyH("LEFT")
	f.paging:SetSpacing(4)
	-- "Show N more": the rest of the list, and back.
	f.more = Hot.More(f, width, function()
		f.expanded = not f.expanded
		Again()
	end)
	-- "Shift + 1 to 6" for a run of the number row, else each key.
	local function KeysSaid(keys)
		local shift, digits = true, {}
		for i, key in ipairs(keys) do
			local n = key:match("^SHIFT%-(%d)$")
			if not n then shift = false end
			digits[i] = tonumber(n)
		end
		if shift and #keys > 2 and digits[#digits] - digits[1] == #keys - 1 then
			return ("Shift + %d to %d"):format(digits[1], digits[#digits])
		end
		local said = {}
		for i, key in ipairs(keys) do said[i] = Keys.Key(key) end
		return Several(said, HOT.named)
	end
	-- A row's two lines: what the key did and what happens to it (in gold when a hand relies on it), then what
	-- the key itself does then and where the rest goes. on: the hotkeys are set (said as done).
	local function RowSays(entry, job, on)
		local key = Keys.Key(entry.key)
		if entry.note then return entry.note.head, entry.note.sub end
		if entry.wait then
			local does = GetBindingAction(entry.key)
			return ("%s waits for a key"):format(entry.wait.name),
				does ~= "" and ("%s stays %s."):format(key, BindingCalled(does)) or ("%s stays as it is."):format(key)
		end
		local name = BindingCalled(entry.from)
		if entry.move then
			local turning = HOT.steer[entry.to] == entry.from
			return ("%s %s %s"):format(GetBindingName(entry.to), on and "is on" or "goes on", key),
				turning and ("%s turned you. To turn, hold the right mouse button and move the mouse."):format(key)
				or ("%s did %s. It's one of the keys you move with."):format(key, name)
		end
		if entry.kept then
			local sub
			if not job then
				sub = "Kept as you have it."
			elseif entry.standIn then
				sub = ("%s %s %s instead."):format(job.name, on and "is on" or "goes on", Keys.Key(entry.standIn))
			else
				sub = ("%s is left off until you pick a key for it."):format(job.name)
			end
			return ("%s stays on %s"):format(name, key), sub
		end
		local becomes = ("%s %s %s."):format(key, on and "is" or "becomes", job and job.name or "a free button")
		if entry.home then
			return ("%s %s %s"):format(name, on and "is on" or "moves to", Keys.Key(entry.home)), becomes
		end
		local still = entry.also and (" Still on %s."):format(Keys.Key(entry.also))
			or (on and " It has no key now: pick one." or " Pick a key for it, or it has none.")
		return ("%s %s %s"):format(name, on and "is no longer on" or "leaves", key), becomes .. still
	end
	-- The list in numbers, beside its caption: "8 move · 2 yours · 1 with no key".
	local function Tally(entries)
		local moved, kept, none = 0, 0, 0
		for _, entry in ipairs(entries) do
			if entry.note then
				-- (said in a row of its own, not counted)
			elseif entry.kept then
				kept = kept + 1
			elseif entry.home or entry.move then
				moved = moved + 1
			elseif not entry.also then
				none = none + 1
			end
		end
		local parts = {}
		if moved > 0 then parts[#parts + 1] = ("%d %s"):format(moved, moved == 1 and "moves" or "move") end
		if kept > 0 then parts[#parts + 1] = ("%d kept as yours"):format(kept) end
		if none > 0 then parts[#parts + 1] = ("%d with no key"):format(none) end
		return table.concat(parts, "  ·  ")
	end
	-- Lays the list under `above`.  -> its height (0: no list)
	local function Yours(above, shown)
		local mine = watched[1]
		local all = shown == "shy" and mine and Hot.Yours(mine.opts) or EMPTY
		-- (on your own hotkeys: the abilities that wait, their keys doing something else)
		if shown == "own" and f.says and f.says.waits then
			all = {}
			for i, job in ipairs(f.says.waits) do all[i] = { key = job.key, from = "", wait = job, at = i } end
		end
		-- (the keys that turned the bar's pages, and the side keys that strafe now, are said in lines, not rows)
		local entries, paging, sides = {}, {}, {}
		for _, entry in ipairs(all) do
			if entry.paging and not entry.kept then
				paging[#paging + 1] = entry.key
			elseif entry.move and HOT.steer[entry.to] == entry.from then
				sides[#sides + 1] = entry.key
			else
				entries[#entries + 1] = entry
			end
		end
		-- (what you'd miss first: what a hand relies on that moves or would have no key, then the rest with no
		-- other key, then what another key still does; each as a hand meets them)
		local function Rank(entry)
			if entry.must and (entry.home or not entry.also) then return 1 end
			return entry.also and 3 or 2
		end
		table.sort(entries, function(a, b)
			local ra, rb = Rank(a), Rank(b)
			if ra ~= rb then return ra < rb end
			return a.at < b.at
		end)
		f.yours = entries
		-- The rows shown: the first few, and the rest with "Show N more" (one being picked, or that said why
		-- not, stays out where it is). After them, the keys you move with that strafe now and the ones that turned
		-- the bar's pages: a row each, with nothing to pick.
		local visible = {}
		for i, entry in ipairs(entries) do
			local row = f.rows[i]
			if i <= HOTVIEW.rows or f.expanded or (row and (row == listening or row.err)) then visible[#visible + 1] = entry end
		end
		local hidden = #entries - #visible
		local on = Hot.On()
		local notes = {}
		if #sides > 0 then
			local said = {}
			for i, key in ipairs(sides) do said[i] = Keys.Key(key) end
			notes[#notes + 1] = { key = sides[1], note = { plate = table.concat(sides, " "),
				head = ("%s %s"):format(table.concat(said, " and "), on and "strafe now" or "will strafe"),
				sub = "To turn, hold the right mouse button and move the mouse." } }
		end
		if #paging > 0 then
			notes[#notes + 1] = { key = paging[1], note = { plate = (KeysSaid(paging):gsub(" %+ ", " "):gsub(" to ", "-")),
				head = on and "These no longer turn your bar's pages" or "These will no longer turn your bar's pages",
				sub = "They press your right side bar's buttons instead." } }
		end
		f.caption:SetShown(#entries + #notes > 0)
		f.tally:SetShown(#entries > 0)
		f.paging:Hide()
		f.more:Set((hidden > 0 and ("Show %d more"):format(hidden)) or (f.expanded and #entries > HOTVIEW.rows and "Show fewer") or nil)
		local rows = {}
		for _, entry in ipairs(visible) do rows[#rows + 1] = entry end
		for _, entry in ipairs(notes) do rows[#rows + 1] = entry end
		for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
		if listening and not listening:IsShown() then Stop() end
		if #rows == 0 then
			f.more:Set(nil)
			return 0
		end
		if shown == "own" then
			f.caption:SetText("These wait for a key, because theirs does something else. Set it up for me gives each one its own.")
			f.tally:SetText(("%d %s"):format(#entries, #entries == 1 and "waits" or "wait"))
		else
			f.caption:SetText(on and "Switch any back, or click a key to pick where it went."
				or "Take the new key or keep yours. Click a key on the right to pick another.")
			f.tally:SetText(Tally(entries))
		end
		if part == "changes" then f.caption:SetText("") end   -- (its page's heading says it)
		f.caption:ClearAllPoints()
		f.caption:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -10)
		local jobs = ByKey()
		local textRight = width - HOTVIEW.lead - HOTVIEW.target - HOTVIEW.choice - 2 * HOTVIEW.apart
		local y = -8
		for i, entry in ipairs(rows) do
			-- (Show more stands between the list and its notes)
			if entry.note and rows[i - 1] and not rows[i - 1].note and f.more:IsShown() then
				f.more:ClearAllPoints()
				f.more:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y + 2)
				y = y - HOT.moreTall - 6
			end
			local row = YourRow(i)
			row.entry = entry
			local job = not entry.note and jobs[entry.key] or nil
			local head, sub = RowSays(entry, job, on and not entry.pending)
			row.keyText:SetText(entry.note and entry.note.plate or Hot.Plate(entry.key))
			row.key:SetWidth(math.max(HOTVIEW.plate + 8, math.ceil(row.keyText:GetStringWidth()) + 14))
			row.head:SetText(head)
			-- (a key you move with, or a note, has no choice: its words run the row's width)
			local wide = (entry.move or entry.note) and (width - HOTVIEW.lead) or textRight
			row.head:SetWidth(wide)
			Theme.Ink(row.head, entry.must and C.alert or C.text)
			row.sub:SetWidth(wide)
			-- (the key being picked, or what went wrong last, takes the second line)
			local picking = listening == row
			if picking then
				sub = entry.kept and ("Press the key for %s. Esc cancels."):format(job and job.name or "it")
					or ("Press the key for %s. Esc cancels."):format(BindingCalled(entry.from))
			end
			row.sub:SetText(row.err or sub)
			Theme.Ink(row.sub, row.err and C.alert or picking and C.head or C.dim)
			-- The choice: none for a key you move with, one that waits or a note; the key that moves: none for a
			-- key you keep with no ability.
			row.choice:SetShown(not entry.move and not entry.wait and not entry.note)
			row.choice:Refresh()
			-- (the key that moves: what the key did, unless another key still does it; or a kept key's ability)
			local target = not entry.move and not entry.wait and not entry.note
				and (entry.kept and job ~= nil or (not entry.kept and (entry.home ~= nil or not entry.also))) or false
			row.target:SetShown(target)
			if target then
				local at = entry.kept and entry.standIn or (not entry.kept and entry.home)
				row.targetText:SetText(picking and "Press a key" or (at and Hot.Plate(at)) or "Pick a key")
				Theme.Ink(row.targetText, (picking or not at) and C.good or C.head)
				row.target:SetOn(picking)
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y)
			row:Show()
			y = y - HOTVIEW.row
		end
		-- (no notes: Show more under the list)
		if f.more:IsShown() and not (rows[#rows] and rows[#rows].note) then
			f.more:ClearAllPoints()
			f.more:SetPoint("TOPLEFT", f.caption, "BOTTOMLEFT", -indent, y + 2)
			y = y - HOT.moreTall - 6
		end
		local tall = 10 + math.ceil(f.caption:GetStringHeight()) - y + 4
		return tall
	end

	function f:Refresh()
		local lit, state = Lit(), self:State()
		-- The keys are drawn for the choice under the mouse, else the one lit: the board for the set-up, your
		-- own keys for the other two.
		local shown = self.looking or lit
		self.shown = shown
		Keys.Pretend(shown == "shy" and "shy" or "own")
		-- What you had before is said as safe while anything of it is changed.
		local changed = state ~= "off"
		tiles.off.tag:SetText(changed and "Kept safe" or HOTVIEW.picks.off.tag)
		Theme.Ink(tiles.off.tag, changed and C.good or C.dim)
		for name, tile in pairs(tiles) do
			local used = name == state
			tile:SetOn(name == lit)
			tile.tick:SetShown(used)
			tile.use:SetShown(used)
		end
		local says = Hot.Says(shown, plan)   -- (said of the choice the keys are drawn for)
		self.says = says
		self.step2.title:SetText(shown == "shy" and "What changes for you" or shown == "own" and "What stays, and what waits"
			or (changed and "Everything goes back" or "Nothing changes"))
		self.safe:SetText(says.safe)
		self.tally:SetText("")
		-- (the choices alone: what the lit one means, and anything that stands in its way)
		if part == "choose" then
			self.chosen:SetText(says.safe)
			local warn = says.block or says.warn
			self.warn:ClearAllPoints()
			self.warn:SetPoint("TOPLEFT", self.chosen, "BOTTOMLEFT", 0, -8)
			self.warn:SetText(warn or "")
			for _, piece in ipairs({ self.notes, self.caption, self.paging, self.more }) do piece:Hide() end
			for _, row in ipairs(self.rows) do row:Hide() end
			self:SetSize(width, HOTVIEW.choose + 16 + math.ceil(self.chosen:GetStringHeight())
				+ (warn and 8 + math.ceil(self.warn:GetStringHeight()) or 0))
			return
		end
		self.notes:SetText(table.concat(says.notes, "\n"))
		says.warn = says.block or says.warn
		self.warn:SetText(says.warn or "")
		local tall = part == "changes" and math.ceil(self.safe:GetStringHeight()) or HOTVIEW.tall + 20 + self.step2:Fit()
		if #says.notes > 0 then tall = tall + 6 + math.ceil(self.notes:GetStringHeight()) end
		self.warn:ClearAllPoints()
		local last = #says.notes > 0 and self.notes or self.safe
		self.warn:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
		if says.warn then
			tall = tall + 6 + math.ceil(self.warn:GetStringHeight())
			last = self.warn
		end
		tall = tall + Yours(last, shown)
		self:SetSize(width, tall)
	end
	f:SetScript("OnHide", function(self)
		self.looking = nil   -- (the choice clicked stays looked at as you go between the room's parts)
		self.Stop()                -- (a key half picked: the keyboard goes back to the game)
		Keys.Pretend(nil)
	end)
	f:Refresh()
	return f
end
-- How you move, picked: WASD or ASDF side by side, and a word when the game still moves you with other keys.
-- f:Refresh() shows the pick.
function Keys.Movement(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local half = math.floor((width - MINI.apart) / 2)
	local choices = {}
	local function Pick(scheme)
		if not Keys.SetScheme(scheme) then Shy.core:Print("you can switch how you move once the fight is over.") end
		f:Refresh()
	end
	choices.wasd = Choice(f, half, "wasd", "W forward, S back. The game's own.", Pick)
	choices.asdf = Choice(f, half, "asdf", "S forward, F back. Your hand rests a key to the right.", Pick)
	choices.wasd:SetPoint("TOPLEFT")
	choices.asdf:SetPoint("LEFT", choices.wasd, "RIGHT", MINI.apart, 0)
	f.note = UI.Text(f, "", 12, false, C.alert)
	f.note:SetPoint("TOPLEFT", choices.wasd, "BOTTOMLEFT", 0, -10)
	f.note:SetWidth(width)
	f.note:SetJustifyH("LEFT")
	function f:Refresh()
		if Drawn(self) then return end
		local now = Keys.Scheme()
		for scheme, b in pairs(choices) do b:SetOn(scheme == now) end
		-- (picked, but the game still moves you with other keys: say so)
		local forward = Scheme().forward
		local moves = false
		for _, key in ipairs({ GetBindingKey("MOVEFORWARD") }) do
			if key == forward then moves = true end
		end
		self.note:SetText(moves and "" or (Keys.Mode() == "shy" and "Your %s doesn't move you forward yet. Setting up your keys takes care of it."
			or "Your %s doesn't move you forward yet. Bind it in the game's key bindings."):format(forward))
		self:SetSize(width, MINI.tall + (moves and 0 or 26))
	end
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Refresh() end
	end)
	f:SetScript("OnShow", f.Refresh)
	f:Refresh()
	return f
end

---------------------------------------------------------------------------
-- How to play: the guide, at the level the keys show
---------------------------------------------------------------------------

-- PLAY: a step's row and its key's plate; the columns' gap; the most steps a column shows.
local PLAY = { row = 32, plate = 22, slot = 22, apart = 24, most = 10, number = 16 }

-- A key as its plate says it: "Q", "Shift Q", "Mouse 4", "Shift Mouse 4".
local function Plate(key)
	return (key:gsub("^SHIFT%-", "Shift "):gsub("BUTTON(%d)", "Mouse %1"))
end

-- A step: its place in the order, the key you press (a keyed plate, as wide as its words), the ability's picture,
-- its name and when to press it under that. The ability's own card on its hover.
local function Step(parent, width)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(width, PLAY.row)
	row:EnableMouse(true)
	row.number = UI.Text(row, "", 11, true, C.dim)
	row.number:SetPoint("LEFT")
	row.number:SetWidth(PLAY.number)
	row.plate = CreateFrame("Button", nil, row)
	row.plate:SetHeight(PLAY.plate)
	row.plate:SetPoint("LEFT", PLAY.number, 0)
	UI.KeyPlate(row.plate)
	row.key = UI.Text(row.plate, "", 11, true, C.head)
	row.key:SetPoint("CENTER")
	row.well = CreateFrame("Frame", nil, row)
	row.well:SetSize(PLAY.slot, PLAY.slot)
	row.well:SetPoint("LEFT", row.plate, "RIGHT", 8, 0)
	row.icon = row.well:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = PLAY.slot, hover = false })
	row.name = UI.Text(row, "", 13)
	row.name:SetPoint("TOPLEFT", row.well, "TOPRIGHT", 8, 2)
	row.name:SetPoint("RIGHT")
	row.when = UI.Text(row, "", 11, false, C.dim)
	row.when:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.when:SetPoint("RIGHT")
	for _, text in ipairs({ row.name, row.when }) do
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
	end
	row:SetScript("OnEnter", function(self)
		if not self.spell then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.spell)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	function row:Set(i, step)
		self.number:SetText(i)
		self.key:SetText(step.key and Plate(step.key) or "-")   -- (no key yet: still to train)
		self:SetAlpha(step.untrained and 0.6 or 1)
		self.plate:SetWidth(math.max(PLAY.plate, math.ceil(self.key:GetStringWidth()) + 12))
		self.icon:SetTexture(step.icon or ICON)
		self.name:SetText(step.name)
		self.when:SetText(step.when or "")
		Theme.Ink(self.when, step.alert and C.alert or C.dim)
		self.name:ClearAllPoints()
		self.name:SetPoint(step.when and "TOPLEFT" or "LEFT", self.well, step.when and "TOPRIGHT" or "RIGHT", 8, step.when and 2 or 0)
		self.name:SetPoint("RIGHT")
		self.spell = step.job and step.spell or nil
	end
	return row
end

-- How to play at the level the keys show (yours to start with): the bracket's levels and build, a sentence on how
-- fights go, then what to press in order against one enemy and against several, each as your key for the way you
-- move. f:Show(level) at a level; it follows the keys' slider.
function Keys.Guide(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local column = math.floor((width - PLAY.apart) / 2)
	f.title = UI.Text(f, "", 15, true, C.head)
	f.title:SetPoint("TOPLEFT")
	-- (the guide out on screen while you play, or put away again)
	f.pull = UI.Button(f, "", 170, function() Keys.ShowGuide(not Keys.GuideShown()) end)
	f.pull:SetPoint("TOPRIGHT", 0, 3)
	local function Pulled() f.pull:SetLabel(Keys.GuideShown() and "Put the guide away" or "Pull out the guide") end
	Pulled()
	Shy:On("SHY_KEYS_GUIDE", Pulled)
	-- (at your own level: what waits at your trainer, and what to buy first with the gold you have)
	f.train = CreateFrame("Frame", nil, f)
	f.train:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
	f.train:SetSize(width, 1)
	f.train.words = UI.Text(f.train, "", 13, false, C.alert)
	f.train.words:SetPoint("TOPLEFT")
	f.train.words:SetWidth(width)
	f.train.words:SetJustifyH("LEFT")
	f.train:SetScript("OnEnter", function(self) if self.list then Keys.TrainingHover(self, self.list) end end)
	f.train:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	f.tip = UI.Text(f, "", 13)
	f.tip:SetPoint("TOPLEFT", f.train, "BOTTOMLEFT", 0, -6)
	f.tip:SetWidth(width)
	f.tip:SetJustifyH("LEFT")
	-- (what to stay in: the aura, stance or form your build keeps on, as a row of its own)
	f.keepCaption = UI.Text(f, "", 11, true, C.dim)
	f.keepCaption:SetPoint("TOPLEFT", f.tip, "BOTTOMLEFT", 0, -14)
	f.keep = Step(f, math.floor((width - PLAY.apart) / 2))
	f.keep:SetPoint("TOPLEFT", f.keepCaption, "BOTTOMLEFT", 0, -6)
	f.lists = {}
	for i, kind in ipairs({ "single", "cleave" }) do
		local list = { kind = kind, rows = {} }
		list.caption = UI.Text(f, i == 1 and "ONE ENEMY" or "SEVERAL ENEMIES", 11, true, C.dim)
		list.caption:SetPoint("TOPLEFT", f.tip, "BOTTOMLEFT", (i - 1) * (column + PLAY.apart), -14)
		for n = 1, PLAY.most do
			local row = Step(f, column)
			row:SetPoint("TOPLEFT", list.caption, "BOTTOMLEFT", 0, -6 - (n - 1) * PLAY.row)
			list.rows[n] = row
		end
		f.lists[i] = list
	end
	local top = GetMaxLevelForPlayerExpansion()
	function f:Show(level)
		local mine = Keys.Mine()
		level = level or math.max(1, math.min(top, UnitLevel("player")))
		if Drawn(self, level) then return end
		self.level = level
		local play = mine and Keys.Play(mine.jobs, mine.opts, level, mine.addon)
		if not play then
			self.title:SetText(mine and "No guide for this class yet" or "No keys for this class yet")
			self.tip:SetText("")
			for _, list in ipairs(self.lists) do
				list.caption:Hide()
				for _, row in ipairs(list.rows) do row:Hide() end
			end
			self:SetSize(width, 24)
			return
		end
		-- (the bracket's levels: from its own start to the next bracket's, for this build)
		local upto = top
		for at in pairs(Keys.PlayLevels(mine.opts)) do
			if at > play.from and at - 1 < upto then upto = at - 1 end
		end
		local build
		if mine.opts.build then build = select(2, mine.opts.build()) end
		local span = upto > play.from and ("Levels %d to %d"):format(play.from, upto) or ("Level %d"):format(play.from)
		self.title:SetText(span .. (build and (", " .. build) or ""))
		local said
		if level == math.max(1, math.min(top, UnitLevel("player"))) then
			local list, sum = Keys.Training(play)
			said = Keys.TrainingSays(list, sum)
			self.train.list = list
		else
			self.train.list = nil
		end
		self.train.words:SetText(said or "")
		self.train:SetHeight(said and math.ceil(self.train.words:GetStringHeight()) or 1)
		self.train:EnableMouse(said ~= nil)
		self.tip:SetText(play.tip or "")
		local keep = play.keep
		self.keepCaption:SetShown(keep ~= nil)
		self.keep:SetShown(keep ~= nil)
		if keep then
			self.keepCaption:SetText(("YOUR %s"):format(keep.word:upper()))
			self.keep:Set("", keep)
		end
		local most = 0
		for i, list in ipairs(self.lists) do
			local steps = play[list.kind]
			list.caption:ClearAllPoints()
			list.caption:SetPoint("TOPLEFT", keep and self.keep or self.tip, "BOTTOMLEFT", (i - 1) * (column + PLAY.apart), keep and -8 or -14)
			list.caption:Show()
			for n, row in ipairs(list.rows) do
				local step = steps[n]
				row:SetShown(step ~= nil)
				if step then row:Set(n, step) end
			end
			most = math.max(most, math.min(#steps, PLAY.most))
		end
		local kept = keep and (14 + 14 + 6 + PLAY.row - 6) or 0
		self:SetSize(width, 24 + 6 + self.train:GetHeight() + 6 + math.ceil(self.tip:GetStringHeight()) + kept + 14 + 14 + 6 + most * PLAY.row)
	end
	-- (Out of sight, only the level is kept: it is drawn as it shows. A room kept for another width of the /shy
	-- window, setup's tab and a class's page each have a guide of their own.)
	Shy:On("SHY_KEYS_LEVEL", function(level)
		if f:IsVisible() then f:Show(level) else f.level = level end
	end)
	Shy:On("SHY_KEYS_STANCE", function()
		if f:IsVisible() then f:Show(f.level) end
	end)
	Shy:On("SHY_KEYS_SCHEME", function()
		if f:IsVisible() then f:Show(f.level) end
	end)
	f:SetScript("OnShow", function(self) self:Show(self.level) end)
	f:Show()
	return f
end

---------------------------------------------------------------------------
-- Their homes: the /shy window's Keys room, a tab of setup's, a class's own page
---------------------------------------------------------------------------

-- The width the keys' controls are drawn best at: a room of the /shy window, inside its margins.
Keys.WIDE = 676

local function Brief()
	local mine = Keys.Mine()
	return Scheme().name .. (mine and Keys.Has(mine.addon) and ", laid out" or ", not laid out")
end

-- The /shy window's Keys room: the same parts as setup's walk through your keys, a page each, picked on the rail
-- (a paged room). A choice is made by its button; what changes, key by key, is done there and then.
local ROOM_PARTS = {
	{ label = "Your choice", ask = "How should your keys work?",
		lead = "Pick one, then press the button under them. Nothing changes until you do.",
		build = function(page) return Keys.Panel(page, page.width, nil, "choose") end },
	{ label = "How you move", ask = "How do you move?", lead = "Your keys are laid out around the hand you move with.",
		build = function(page) return Keys.Movement(page, page.width) end },
	{ label = "What changes", ask = "What changes for you",
		lead = "Every key of yours that changes, and where what it did goes. Take the new key or keep yours.",
		build = function(page) return Keys.Panel(page, page.width, nil, "changes") end },
	{ label = "Your new keys", ask = "Your keys, level by level",
		lead = "Drag the level to see what comes when. Point at a key to see what it does.",
		build = function(page) return Keys.Panel(page, page.width, nil, "board") end },
	{ label = "How to play", ask = "How to play", lead = "What to press, and when, at the level the keys show.",
		build = function(page)
			-- (in a plain frame of its own: the guide's Show draws it at a level, and the room shows a part by its frame)
			local holder = CreateFrame("Frame", nil, page)
			holder.guide = Keys.Guide(holder, page.width)
			holder.guide:SetPoint("TOPLEFT")
			function holder:Refresh()
				self.guide:Show(self.guide.level)
				self:SetSize(page.width, math.max(1, self.guide:GetHeight()))
			end
			holder:Refresh()
			return holder
		end },
}
for i, def in ipairs(ROOM_PARTS) do
	Shy.HubSection("keys", function(page, top)
		local head = Shy.HubHead(page, top, def.ask, def.lead, def.label)
		local piece = def.build(page)
		piece:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
		return piece, function() piece:Refresh() end
	end, i * 10)
end

Shy.HubBrief("keys", Brief)

-- The whole of it in one column, captioned as the room is: how you move, your keys, how to play.
--   Keys.Room(parent, width)   f:Refresh()
local function Caption(parent, text, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 14)
	local words = UI.Text(f, text:upper(), 11, true, C.dim)
	words:SetPoint("LEFT")
	local rule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.6)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", words, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT")
	return f
end

function Keys.Room(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local pieces = {}
	local function Under(above, caption, piece)
		local head = Caption(f, caption, width)
		head:SetPoint("TOPLEFT", above, above == f and "TOPLEFT" or "BOTTOMLEFT", 0, above == f and 0 or -26)
		piece:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
		pieces[#pieces + 1] = piece
		return piece
	end
	local moving = Under(f, "How you move", Keys.Movement(f, width))
	local panel = Under(moving, "Your keys", Keys.Panel(f, width, plan))
	-- (setup's tab is for choosing: how to play is the /shy window's, once the keys are yours)
	local guide = Keys.Guide(f, width)
	if plan then guide:Hide() else Under(panel, "How to play", guide) end
	f.moving, f.panel, f.guide = moving, panel, guide
	function f:Refresh()
		if Drawn(self) then return end
		moving:Refresh()
		panel:Refresh()
		if not plan then guide:Show(guide.level) end
		local tall = 0
		for _, piece in ipairs(pieces) do tall = tall + 14 + 12 + 26 + piece:GetHeight() end
		self:SetSize(width, tall)
	end
	-- (a pick's sentences and its list of your keys make it taller or shorter; setup's window then scrolls that far)
	panel.resized = function()
		f:Refresh()
		if plan and Shy.Setup and Shy.Setup.Grew then Shy.Setup.Grew() end
	end
	f:SetScript("OnShow", f.Refresh)
	return f
end

-- What you picked in the list (the keys you keep, where a thing goes, a kept key's ability's key), as it stands:
-- setup's page notes picks there and Finish does them; Not now puts these back.
local function Picks()
	local book = Hot.Choices()
	local copy = {}
	for _, name in ipairs({ "keep", "homeAt", "standIn", "over" }) do
		copy[name] = {}
		for k, v in pairs(book[name] or EMPTY) do copy[name][k] = v end
	end
	return copy
end
local function Unpick(was)
	local book = Hot.Choices()
	for _, name in ipairs({ "keep", "homeAt", "standIn", "over" }) do
		book[name] = {}
		for k, v in pairs(was[name] or EMPTY) do book[name][k] = v end
	end
	Keys.gen = Keys.gen + 1
end
-- Finish: the picks noted on setup's page since it opened, done as the /shy window does them (bound now where
-- the hotkeys are set, else kept for when they are).
local function Settle(was)
	if not was then return end
	local now = Picks()
	Unpick(was)
	Hot.Choices().over = now.over   -- (the keys you said may be taken: so, before the picks that take them)
	local mine = Keys.Mine()
	local from = {}              -- a binding -> the key of yours it was on
	for _, entry in ipairs(mine and Hot.Yours(mine.opts) or EMPTY) do from[entry.from] = from[entry.from] or entry.key end
	local seen = {}
	for _, list in ipairs({ now.keep, was.keep }) do
		for key in pairs(list) do
			if not seen[key] and (now.keep[key] or nil) ~= (was.keep[key] or nil) then Hot.Keep(key, now.keep[key]) end
			seen[key] = true
		end
	end
	seen = {}
	for _, list in ipairs({ now.homeAt, was.homeAt }) do
		for command in pairs(list) do
			if not seen[command] and now.homeAt[command] ~= was.homeAt[command] then
				if from[command] then
					Hot.SetHome(from[command], command, now.homeAt[command])
				else
					Hot.Choices().homeAt[command] = now.homeAt[command]
				end
			end
			seen[command] = true
		end
	end
	for key, at in pairs(now.standIn) do
		if was.standIn[key] ~= at then Hot.SetStandIn(key, at) end
	end
	for key in pairs(was.standIn) do
		if now.standIn[key] == nil and Hot.Choices().standIn[key] ~= nil then Hot.SetStandIn(key, nil) end
	end
end

-- Setup's page for your keys: one question in the middle of the page, and Yes or No. Yes walks through setting
-- them up (setup's walk of your keys, below); No leaves your key binds, macros and bars alone, all of them.
-- Answered, the answer stays lit and a line under it says what it comes to; Yes again walks through it again.
--   Keys.Ask(parent, width, plan, room) -> f: f:Refresh(), f:Fit(room)
local ASK = { width = 460, gap = 16, button = 136, board = 22, pad = 40 }
Keys.QUESTION = "Do you want me to interactively set up your key binds, macros and bars as you level?"
function Keys.Ask(parent, width, plan, room)
	local f = CreateFrame("Frame", nil, parent)
	f.room = room or 400
	f:SetSize(width, f.room)
	local column = CreateFrame("Frame", nil, f)
	column:SetWidth(ASK.width)
	column:SetPoint("CENTER")
	f.column = column
	-- (the keys you move with, lit, over the question: what it is about, at a glance)
	f.board = MiniBoard(column, function(letter) return Scheme().move[letter] == true end)
	f.board:SetPoint("TOP")
	f.question = UI.Text(column, Keys.QUESTION, 18, true, C.head)
	f.question:SetPoint("TOP", f.board, "BOTTOM", 0, -ASK.board)
	f.say = UI.Text(column, "Every ability gets a key close to your hand, your bars and macros are laid out for you, and each new ability comes to its key as you learn it. You see everything before anything changes, and one click puts it all back.", 12, false, C.dim)
	f.say:SetPoint("TOP", f.question, "BOTTOM", 0, -10)
	f.answer = UI.Text(column, "", 12, false, C.text)
	for _, text in ipairs({ f.question, f.say, f.answer }) do
		text:SetWidth(ASK.width)
		text:SetJustifyH("CENTER")
		text:SetWordWrap(true)
	end
	local function Answer(yes)
		plan.keys = plan.keys or {}
		plan.keys.asked = true
		if yes then
			-- (set up, unless there is a pick of yours already to look through again)
			if not HOTVIEW.picks[plan.keys.pick] then
				local mine = Keys.Mine()
				plan.keys.pick = mine and Keys.Has(mine.addon) and Keys.Mode() or "shy"
			end
			f:Refresh()
			if Shy.Setup and Shy.Setup.Walk then Shy.Setup.Walk("keys") end
		else
			plan.keys.pick = "skip"
			f:Refresh()
			if Shy.Setup and Shy.Setup.Walk then Shy.Setup.Walk("keys") end   -- (its pages go from the rail)
		end
	end
	f.yes = UI.Button(column, "Yes", ASK.button, function() Answer(true) end)
	f.no = UI.Button(column, "No", ASK.button, function() Answer(false) end)
	f.yes:SetPoint("TOPRIGHT", f.say, "BOTTOM", -ASK.gap / 2, -ASK.gap - 6)
	f.no:SetPoint("TOPLEFT", f.say, "BOTTOM", ASK.gap / 2, -ASK.gap - 6)
	f.answer:SetPoint("TOP", f.say, "BOTTOM", 0, -(ASK.gap + 6 + 24 + ASK.gap))
	function f:Fit(height)
		self.room = height or self.room
		local tall = self.board:GetHeight() + ASK.board + math.ceil(self.question:GetStringHeight()) + 10
			+ math.ceil(self.say:GetStringHeight()) + ASK.gap + 6 + 24
			+ ((self.answer:GetText() or "") ~= "" and (ASK.gap + math.ceil(self.answer:GetStringHeight())) or 0)
		column:SetHeight(tall)
		self:SetSize(width, math.max(self.room, tall + 2 * ASK.pad))
	end
	function f:Refresh()
		local keys = plan.keys or {}
		local pick = keys.pick
		local yes = keys.asked and pick ~= "skip"
		local no = pick == "skip" and keys.asked
		self.yes:SetPrimary(not no)
		self.yes:SetOn(yes == true)
		self.no:SetOn(no == true)
		self.board:Light(function(letter) return Scheme().move[letter] == true end)
		if no then
			self.answer:SetText("Your key binds, macros and bars stay exactly as they are. Nothing of them is touched.")
		elseif yes then
			local line = Keys.STEP.Lines(plan)[1]
			self.answer:SetText(("%s. Press Yes to look through it again."):format(line.text))
		else
			self.answer:SetText("")
		end
		self:Fit()
	end
	f:Refresh()
	return f
end

-- The walk's last page: each part of it in a sentence, with Change to go back to its page.
--   Keys.Review(parent, width, plan) -> f: f:Refresh()
function Keys.Review(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(width)
	local parts = {}
	local function Part(n, title, page)
		local head = Hot.StepHead(f, n, width - 104)
		head.title:SetText(title)
		head.change = UI.Button(f, "Change", 92, function()
			if Shy.Setup and Shy.Setup.Show then Shy.Setup.Show(page) end
		end)
		head.change:SetPoint("TOPRIGHT", head, "TOPRIGHT", 104, 0)
		parts[#parts + 1] = head
		return head
	end
	f.choice = Part(1, "Your choice", "keys.pick")
	f.moving = Part(2, "How you move", "keys.move")
	f.changes = Part(3, "What changes", "keys.changes")
	f.board = Part(4, "Your new keys", "keys.board")
	f.foot = UI.Text(f, "Finish in setup does all of this. Until then nothing of yours changes, and later one click in /shy keys puts it all back.", 12, false, C.alert)
	f.foot:SetWidth(width)
	f.foot:SetJustifyH("LEFT")
	function f:Refresh()
		local pick = plan.keys and plan.keys.pick
		local def = HOTVIEW.picks[pick] or HOTVIEW.picks.off
		self.choice.say:SetText(("%s. %s"):format(def.title, def.say))
		self.moving.say:SetText(Keys.Scheme() == "asdf" and "ASDF: S forward, F back. Your hand rests a key to the right."
			or "WASD: W forward, S back, as the game has it.")
		local line = Keys.STEP.Lines(plan)[1]
		self.changes.say:SetText(line.sub and line.sub ~= "" and line.sub or line.text)
		self.board.say:SetText(pick == "shy" and "Every ability on its own key, from your first level to your last. Each new one comes to its key as you learn it."
			or pick == "own" and "Your abilities on the keys you already use. Any whose key does something else waits."
			or "Your keys as you have them now.")
		local y = 0
		for _, part in ipairs(parts) do
			part:ClearAllPoints()
			part:SetPoint("TOPLEFT", 0, -y)
			y = y + part:Fit() + 22
		end
		self.foot:ClearAllPoints()
		self.foot:SetPoint("TOPLEFT", 0, -(y + 4))
		self:SetHeight(y + 4 + math.ceil(self.foot:GetStringHeight()))
	end
	f:SetScript("OnShow", f.Refresh)
	f:Refresh()
	return f
end

-- Setup: your keys, a page of its own with one question (Keys.Ask). The pick is the hotkeys' (plan.keys.pick):
-- "skip" (No: your keys, macros and bars left alone, whatever they are), "shy" (the board, recommended), "own"
-- (your keys as they are) or "off" (nothing laid out, and keys that are laid out put back). Taken, never given:
-- a character whose keys aren't laid out starts at "skip", so nobody finishes setup to find anything of theirs
-- changed; laid out, they keep the way they are. Yes walks through it (Keys.WALK): the choice, how you move,
-- what changes, your new keys, and a look over all of it. Finish does it, with nothing to reload. (Setup is the
-- core's own, loaded before this file; a test that leaves it out has no window to put the page in.)
Keys.STEP = {
	id = "keys", order = 23.5, title = "Your keys", glyph = "action",
	ask = "Your keys", lead = "",
	-- (Yes: the walk through them hangs under this page on the rail, and Next goes through it)
	walks = function(plan)
		local pick = plan and plan.keys and plan.keys.pick
		return pick ~= nil and pick ~= "skip"
	end,
	brief = function(plan)
		local pick = plan and plan.keys and plan.keys.pick
		if pick == "skip" then return "Left as they are" end
		if not HOTVIEW.picks[pick] or not Keys.Mine() then return Brief() end
		return Scheme().name .. ", " .. HOTVIEW.picks[pick].brief
	end,
	Plan = function(plan)
		local mine = Keys.Mine()
		plan.keys = { pick = mine and Keys.Has(mine.addon) and Keys.Mode() or "skip", was = Picks() }
	end,
	-- (the list's picks are noted as they are made: put back if the window closes without Finish)
	Worn = Picks,
	PutBack = function(was) Unpick(was) end,
	Build = function(parent, width, plan, room) return Keys.Ask(parent, width, plan, room) end,
	Lines = function(plan)
		local mine = Keys.Mine()
		local pick = plan.keys and plan.keys.pick
		if pick == "skip" then
			return { { text = "Your keys stay as they are", sub = "your key binds, macros and bars are left alone" } }
		end
		if not mine or not pick then return { { text = Brief() } } end
		local laid = Keys.Has(mine.addon)
		local says = Hot.Says(pick, plan)
		if pick == "off" then
			return { { text = laid and "Your keys are put back" or "Your keys stay as they are",
				sub = laid and "every button and hotkey as it was before" or "lay them out any time from /shy keys" } }
		end
		if says.block and not laid then
			return { { text = "Your keys aren't laid out yet", sub = "there is no room for their macros: see the Keys page" } }
		end
		-- (set up stands only where the hotkeys are set: not on a character's own key bindings, until Finish)
		local stands = laid and pick == Keys.Mode() and (pick ~= "shy" or Hot.On())
		local text
		if pick == "shy" then
			text = stands and "Your keys stay set up" or "Your keys are set up, hotkeys and all"
		else
			text = stands and "Your abilities stay on your own hotkeys" or "Your abilities go on your own hotkeys"
		end
		-- Set up from here: what a hand relies on that moves, by name and where it goes, and that A and D strafe
		-- (setup's overview shows this sentence, before Finish).
		if pick == "shy" and not stands then
			local moves, sides = {}, {}
			for _, entry in ipairs(Hot.Yours(mine.opts)) do
				if not entry.kept and entry.must and entry.home then
					moves[#moves + 1] = ("%s to %s"):format(BindingCalled(entry.from), Keys.Key(entry.home))
				elseif entry.move and HOT.steer[entry.to] == entry.from then
					sides[#sides + 1] = Keys.Key(entry.key)
				end
			end
			local parts = {}
			if #moves > 0 then parts[#parts + 1] = ("Moves %s."):format(Several(moves, HOTVIEW.most)) end
			if #sides > 0 then parts[#parts + 1] = ("%s strafe; hold the right mouse button to turn."):format(table.concat(sides, " and ")) end
			if #parts > 0 then
				parts[#parts + 1] = "Everything of yours is saved, and one click puts it back."
				return { { text = text, sub = table.concat(parts, " ") } }
			end
		end
		return { { text = text, sub = says.safe } }
	end,
	Run = function(plan)
		local mine = Keys.Mine()
		local pick = plan.keys and plan.keys.pick
		if not mine or not pick or pick == "skip" then return false end   -- (No: nothing of your keys is touched)
		Settle(plan.keys.was)    -- (what was picked in the list: done now, as Finish promises)
		local laid = Keys.Has(mine.addon)
		if pick == "off" then
			if laid then Keys.Unlay(mine.addon) end
			return false
		end
		Keys.SetMode(pick)       -- (keys laid out already are switched at once)
		if not laid or Keys.Old(mine.addon) then
			local result = Keys.Lay(mine.addon, mine.jobs, mine.opts)
			if result then mine.waiting = result.waiting end
		end
		return false
	end,
}

-- The walk through your keys: its pages, each a part of the keys' page alone, under setup's heading for it.
local function Page(build)
	return function(parent, width, plan)
		local page = build(parent, math.min(width, Keys.WIDE + 124), plan)
		page.resized = function()
			if Shy.Setup and Shy.Setup.Grew then Shy.Setup.Grew() end
		end
		return page
	end
end
local function Picked(plan) return plan and plan.keys and plan.keys.pick end
Keys.WALK = {
	{ id = "keys.pick", order = 23.51, walk = "keys", title = "Your choice", glyph = "action",
		ask = "How should your keys work?", lead = "Pick one. The next pages show exactly what it means for you.",
		brief = function(plan) local def = HOTVIEW.picks[Picked(plan)]; return def and def.title end,
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "choose") end) },
	{ id = "keys.move", order = 23.52, walk = "keys", title = "How you move", glyph = "go",
		ask = "How do you move?", lead = "Your keys are laid out around the hand you move with.",
		brief = function() return Scheme().name end,
		Build = Page(function(parent, width) return Keys.Movement(parent, width) end) },
	{ id = "keys.changes", order = 23.53, walk = "keys", title = "What changes", glyph = "link",
		ask = function(plan)
			local pick = Picked(plan)
			return pick == "shy" and "What changes for you" or pick == "own" and "What stays, and what waits" or "Nothing changes"
		end,
		lead = function(plan)
			local pick = Picked(plan)
			return pick == "shy" and "Every key of yours that changes, and where what it did goes. Take the new key or keep yours."
				or pick == "own" and "Your hotkeys stay. These abilities wait, because their keys do something else."
				or "Every button and hotkey stays as it is."
		end,
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "changes") end) },
	{ id = "keys.board", order = 23.54, walk = "keys", title = "Your new keys", glyph = "window",
		ask = "Your keys, level by level", lead = "Drag the level to see what comes when. Point at a key to see what it does.",
		Build = Page(function(parent, width, plan) return Keys.Panel(parent, width, plan, "board") end) },
	{ id = "keys.review", order = 23.55, walk = "keys", title = "Review", glyph = "done",
		ask = "Ready when you are", lead = "All of it at a glance. Change anything, or press Done and then Finish.",
		Build = Page(function(parent, width, plan) return Keys.Review(parent, width, plan) end) },
}
if Shy.Setup then
	Shy.Setup.Step(Keys.STEP)
	for _, step in ipairs(Keys.WALK) do Shy.Setup.Step(step) end
end

---------------------------------------------------------------------------
-- The guide pulled out: on screen while you play
---------------------------------------------------------------------------

-- How to play at your level, as a window of its own that stays on screen: what to press against one enemy and
-- against several, each as your key and the ability, its when at the right. Opened and closed at any time
-- (core.db.keysGuide): from the Keys room, `/shy guide` or its own ×. It stands at the top left until you drag it
-- elsewhere, and follows your level, your build and how you move as they change.
local CARD = { width = 280, least = 230, row = 22, slot = 18, plate = 18, pad = 10, gap = 6, caption = 16, most = 7 }

local cardBox

function Keys.GuideShown() return Shy.core.db.keysGuide == true end

function Keys.ShowGuide(on)
	Shy.core.db.keysGuide = on and true or false
	if cardBox then
		Shy.HUD.Update(cardBox)
		if on then cardBox:Fill() end
	end
	Shy:Fire("SHY_KEYS_GUIDE", on and true or false)
end

local function CardRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(CARD.row)
	row.plate = CreateFrame("Button", nil, row)
	row.plate:SetHeight(CARD.plate)
	row.plate:SetPoint("LEFT")
	UI.KeyPlate(row.plate)
	row.key = UI.Text(row.plate, "", 10, true, C.head)
	row.key:SetPoint("CENTER")
	row.well = CreateFrame("Frame", nil, row)
	row.well:SetSize(CARD.slot, CARD.slot)
	row.well:SetPoint("LEFT", row.plate, "RIGHT", 6, 0)
	row.icon = row.well:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.slot = Shy.Slot.New(row.well, { icon = row.icon, size = CARD.slot, hover = false })
	row.when = UI.Text(row, "", 10, false, C.dim)
	row.when:SetPoint("RIGHT")
	row.when:SetJustifyH("RIGHT")
	row.when:SetWordWrap(false)
	row.name = UI.Text(row, "", 12)
	row.name:SetPoint("LEFT", row.well, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row.when, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	function row:Set(step)
		self.key:SetText(step.key and Plate(step.key) or "-")   -- (no key yet: still to train)
		self:SetAlpha(step.untrained and 0.6 or 1)
		self.plate:SetWidth(math.max(CARD.plate, math.ceil(self.key:GetStringWidth()) + 10))
		self.icon:SetTexture(step.icon or ICON)
		self.name:SetText(step.name)
		self.when:SetText(step.when or "")
		Theme.Ink(self.when, step.alert and C.alert or C.dim)
		self.when:SetWidth(step.when and math.min(130, math.ceil(self.when:GetStringWidth()) + 2) or 1)
	end
	return row
end

local function MakeCard()
	local box = Shy.HUD.Create({
		id = "shy.keys.guide",
		title = "How to play",
		width = CARD.width,
		height = 120,
		-- At the top left, where the windows you talk through open (a quest giver's, the mail, a vendor's): they
		-- stand over it while open. Dragged by its header anywhere; it keeps where you put it.
		point = { "TOPLEFT", "TOPLEFT", 16, -16 },
		shown = function() return Keys.GuideShown() and Keys.Mine() ~= nil and Keys.Mine().opts.play ~= nil end,
		hang = true,   -- grows downward, so the heading stays put
		-- Sized from its sides it flows: the rows take the width, the height is what they need.
		grip = { flow = function(self, w) self:SetWidth(w) self:Fill() end, min = { CARD.least, 80 } },
	})
	-- What it says stands on its body, inside the width the screen's plan gives it, as tall as it needs (UI.Body).
	box.head = UI.Head(box, { size = "piece", title = "How to play", drag = box, close = function() Keys.ShowGuide(false) end,
		panel = { hud = true, brackets = false }, body = true })
	-- The look keeps another clearance round the body: laid out again.
	Shy:On("SHY_BODY", function(f) if f == box then box:Fill() end end)
	box.level = UI.Text(box, "", 12, true, C.head)
	box.train = CreateFrame("Frame", nil, box)
	box.train.words = UI.Text(box.train, "", 11, false, C.alert)
	box.train.words:SetPoint("TOPLEFT")
	box.train.words:SetJustifyH("LEFT")
	box.train:SetScript("OnEnter", function(self) if self.list then Keys.TrainingHover(self, self.list) end end)
	box.train:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	box.tip = UI.Text(box, "", 11, false, C.dim)
	box.keepCaption = UI.Text(box, "", 10, true, C.dim)
	box.keep = CardRow(box)
	box.tip:SetJustifyH("LEFT")
	box.lists = {}
	for i, kind in ipairs({ "single", "cleave" }) do
		local list = { kind = kind, rows = {} }
		list.caption = UI.Text(box, i == 1 and "ONE ENEMY" or "SEVERAL ENEMIES", 10, true, C.dim)
		for n = 1, CARD.most do list.rows[n] = CardRow(box) end
		box.lists[i] = list
	end

	-- Laid out top down for what it shows now, as tall as that.
	function box:Fill()
		if not self:IsShown() then return end
		local mine = Keys.Mine()
		local level = math.max(1, math.min(GetMaxLevelForPlayerExpansion(), UnitLevel("player")))
		local play = mine and Keys.Play(mine.jobs, mine.opts, level, mine.addon)
		local inside = UI.Body(self)
		local width = UI.BodySize(self) - 2 * CARD.pad
		local y = UI.HEAD.piece.line + UI.LINE + CARD.pad
		local build = mine and mine.opts.build and select(2, mine.opts.build())
		self.level:ClearAllPoints()
		self.level:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.level:SetText(("Level %d%s"):format(level, build and (", " .. build) or ""))
		y = y + 16
		-- (what waits at your trainer, and what to buy first)
		local list, sum
		if play then list, sum = Keys.Training(play) end
		local said = Keys.TrainingSays(list, sum)
		self.train.list = list
		self.train:ClearAllPoints()
		self.train:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.train.words:SetWidth(width)
		self.train.words:SetText(said or "")
		self.train:SetSize(width, said and math.ceil(self.train.words:GetStringHeight()) or 1)
		self.train:EnableMouse(said ~= nil)
		if said then y = y + self.train:GetHeight() + 4 end
		self.tip:ClearAllPoints()
		self.tip:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
		self.tip:SetWidth(width)
		self.tip:SetText(play and play.tip or "")
		y = y + (play and math.ceil(self.tip:GetStringHeight()) or 0) + CARD.gap
		local keep = play and play.keep
		self.keepCaption:SetShown(keep ~= nil)
		self.keep:SetShown(keep ~= nil)
		if keep then
			self.keepCaption:ClearAllPoints()
			self.keepCaption:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -(y + 4))
			self.keepCaption:SetText(("YOUR %s"):format(keep.word:upper()))
			y = y + CARD.caption
			self.keep:ClearAllPoints()
			self.keep:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
			self.keep:SetWidth(width)
			self.keep:Set(keep)
			y = y + CARD.row + CARD.gap
		end
		for _, list in ipairs(self.lists) do
			local steps = play and play[list.kind] or NONE
			list.caption:SetShown(#steps > 0)
			if #steps > 0 then
				list.caption:ClearAllPoints()
				list.caption:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -(y + 4))
				y = y + CARD.caption
			end
			for n, row in ipairs(list.rows) do
				local step = steps[n]
				row:SetShown(step ~= nil)
				if step then
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", inside, "TOPLEFT", CARD.pad, -y)
					row:SetWidth(width)
					row:Set(step)
					y = y + CARD.row
				end
			end
			y = y + CARD.gap
		end
		local _, t, _, b = UI.BodyIn(self)
		self:SetHeight(y + CARD.pad - CARD.gap + t + b)
	end
	box:SetScript("OnShow", box.Fill)
	cardBox = box
	box:Fill()
end

-- The hotkeys follow who is playing: on key bindings the account shares, a class with a stance bar has it on
-- 1 2 3 and another has those keys on the flyout. Only keys set here and still as set are touched, out of a fight.
function Hot.Follow()
	if not Hot.On() then return end
	if InCombatLockdown() then
		HOT.follow = true
		return
	end
	HOT.follow = false
	local mine = watched[1]
	if mine and Keys.Old(mine.addon) then return end   -- (an older layout: its keys stay as they are until it is taken)
	local result = Hot.Take(mine and mine.opts, true)
	-- (a key that presses another button now, a flyout's bar laid another way: the job on it follows)
	if result and result.bound > 0 and mine and Keys.Has(mine.addon) and not Keys.Old(mine.addon) and not Keys.Paused(mine.addon) then
		local laid = Keys.Apply(mine.addon, mine.jobs, mine.opts)
		if laid then mine.waiting = laid.waiting end
	end
end

---------------------------------------------------------------------------
-- A key's tooltip on the bars
---------------------------------------------------------------------------

-- The bars cut a macro's name short ("Bles..."), so a key's button leads its tooltip with the key: the key that
-- presses it and the key's name whole, what the key is for, and what it comes to cast next. Only on a button a
-- job of the layout stands on: its macro by name, or the item or spell it stands as.
--   Keys.On(slot)       -> { name, key ("Shift + 4"; nil with none), what (nil when the name says it), next } or nil
--   Keys.Carded()       whether the game's tooltip is shown as a card that leads with it (ShyTip's says so); the
--                       game's own tooltip gets the same as lines under what the game says (Keys.Tip)
local tipped = {}            -- the jobs by name, for the state they were read in
local function Named()
	local mine = watched[1]
	if not mine then return nil end
	local build = mine.opts.build and (mine.opts.build())
	local stamp = Keys.gen .. "|" .. tostring(build) .. "|" .. Keys.Scheme()
	if tipped.stamp ~= stamp then
		tipped.stamp, tipped.jobs = stamp, {}
		for _, job in ipairs(Keys.Jobs(mine.jobs, build)) do tipped.jobs[job.name] = job end
	end
	return tipped.jobs, mine
end

function Keys.On(slot)
	local jobs, mine = Named()
	local who = UnitGUID("player")
	local made = jobs and mine.addon.db.keysMade and mine.addon.db.keysMade[who]
	if not made then return nil end
	local name = C_ActionBar.GetActionText(slot)
	if not (name and made[name]) then
		name = nil
		local before = mine.addon.db.keysBefore and mine.addon.db.keysBefore[who]
		local kind, id = GetActionInfo(slot)
		-- (on a button it was put on, or you moved it to: the same spell on a button of your own is yours)
		for held in pairs(before and before.last or EMPTY) do
			if made[held] and Owns(held, before, kind, id) then
				for _, slots in ipairs({ before.placed[held] or EMPTY, before.pinned[held] or EMPTY }) do
					for _, at in ipairs(slots) do
						if at == slot then name = held end
					end
				end
			end
		end
	end
	local job = name and jobs[name]
	if not job then return nil end
	-- What it comes to cast next: the first ability of its story past your level.
	local coming
	local _, _, story = Keys.Story(mine.jobs, mine.opts, mine.addon)
	local level = UnitLevel("player")
	for _, step in ipairs(story[job] or EMPTY) do
		if step.name and step.level > level and (not coming or step.level < coming.level) then coming = step end
	end
	return { name = job.name, key = KeyAt({ slot }, mine.opts), what = job.what ~= job.name and job.what or nil,
		next = coming and ("Next: %s at level %d"):format(coming.name, coming.level) or nil }
end

function Keys.Carded() return false end

function Keys.Tip(tooltip)
	if tooltip ~= GameTooltip or Keys.Carded() then return end
	local owner = tooltip:GetOwner()
	if not owner or owner:IsForbidden() then return end
	local slot = owner.action
	if type(slot) ~= "number" or issecretvalue(slot) then return end
	local lead = Keys.On(slot)
	if not lead then return end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(lead.name, lead.key or "", C.head[1], C.head[2], C.head[3], C.dim[1], C.dim[2], C.dim[3])
	if lead.what then tooltip:AddLine(lead.what, C.dim[1], C.dim[2], C.dim[3], true) end
	if lead.next then tooltip:AddLine(lead.next, C.dim[1], C.dim[2], C.dim[3], true) end
	tooltip:Show()
end
TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, Keys.Tip)

Shy:On("SHY_LOGIN", function()
	C_Timer.After(SOON, Hot.Follow)
	C_Timer.After(SOON, function()
		local mine = watched[1]
		if mine and Keys.Old(mine.addon) then
			mine.addon:Print("your keys have a new layout. Look at it in /shy keys: yours stay as they are until you take it.")
		end
	end)
	local keyboard = CreateFrame("Frame")
	keyboard:RegisterEvent("UPDATE_BINDINGS")
	keyboard:RegisterEvent("PLAYER_REGEN_ENABLED")
	keyboard:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	keyboard:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	keyboard:SetScript("OnEvent", function(_, event)
		if event == "UPDATE_BINDINGS" then
			Keys.gen = Keys.gen + 1   -- (a key bound in the game's own window: what the keys show is worked out again)
		elseif event == "UPDATE_SHAPESHIFT_FORMS" then
			-- (a form, an aura or a stance learned: 1 2 3 press what you stay in wherever the bar now has it, and a
			-- macro that asks for a form by its place is written again)
			Keys.gen = Keys.gen + 1
			for _, entry in ipairs(watched) do entry.stale = true end
			Keys.Later()
			C_Timer.After(SOON, Hot.Follow)
		elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
			-- (another layout: a flyout's bar may stand another way, and the number row follows it once it has)
			Keys.gen = Keys.gen + 1
			C_Timer.After(SOON, Hot.Follow)
		elseif HOT.follow then
			Hot.Follow()
		end
	end)
	MakeCard()
	-- It follows your level, your build and how you move.
	-- (and what you can afford at your trainer: your gold, and what you've learned there)
	local watch, soon = CreateFrame("Frame"), false
	-- (and your aura, stance or form going on or off)
	for _, event in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_MONEY", "LEARNED_SPELL_IN_SKILL_LINE", "TRAINER_CLOSED",
		"UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS" }) do
		watch:RegisterEvent(event)
	end
	watch:SetScript("OnEvent", function()
		if soon then return end
		soon = true
		C_Timer.After(0.2, function()
			soon = false
			cardBox:Fill()
			Shy:Fire("SHY_KEYS_STANCE")
		end)
	end)
	for _, event in ipairs({ "SHY_BUILD", "SHY_TALENTS", "SHY_KEYS_SCHEME" }) do
		Shy:On(event, function() cardBox:Fill() end)
	end
end)

Shy.Command("guide", "how to play at your level, on screen or put away", function()
	Keys.ShowGuide(not Keys.GuideShown())
end)

Shy.Command("keys", "your keys, and what comes to them as you level", function()
	Shy.Hub.Open("keys")
end)

-- Why your keys are as they are, as text: every job, the key it stands on or what it waits for, and what in your
-- bags each of the bags' keys found. For a copy box: a question about a key is answered by reading it.
function Keys.Report()
	local mine = watched[1]
	if not mine then return "No keys for this class." end
	local opts = mine.opts
	local build, buildName
	if opts.build then build, buildName = opts.build() end
	local who = UnitGUID("player")
	local made = mine.addon.db.keysMade and mine.addon.db.keysMade[who] or EMPTY
	local before = mine.addon.db.keysBefore and mine.addon.db.keysBefore[who]
	local pinned = before and before.pinned or EMPTY
	local jobs = Keys.Jobs(mine.jobs, build)
	local best, known = Bags(), {}
	local seats = Seat(jobs, opts, made, best, Learns(opts.knows), known, pinned, before and before.last)
	local lines = {
		("Level %d %s, %s, moving with %s."):format(UnitLevel("player"), (UnitClass("player")), buildName or "no build", Scheme().name),
		Keys.Has(mine.addon) and (Keys.Old(mine.addon) and "Laid out by an earlier layout: nothing changes until you take the new one."
			or ("Laid out, on %s."):format(Keys.Mode() == "shy" and "the hotkeys set up for you" or "your own hotkeys"))
			or "Not laid out: this is what a layout would do.",
		"",
	}
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		local says
		if not job.key then
			says = "no key for the way you move"
		elseif seat and pinned[job.name] then
			says = (KeyAt(pinned[job.name], opts) or "no key") .. "  (where you put it)"
		elseif seat then
			local busy = not Pressable(seat, opts, seat == job.key and job.spare or nil) and Action(seat)
			says = Keys.Key(seat) .. (seat ~= job.key and ("  (its own key is %s: it stands here until that key's ability is learned)"):format(Keys.Key(job.key)) or "")
				.. (busy and busy ~= "" and ("  BUT that key does %s now, so it can't stand there"):format(GetBindingName(busy)) or "")
		elseif job.supply then
			says = ("waits on %s: none in your bags (%s)"):format(Keys.Key(job.key), table.concat(job.supply, " or "))
		else
			local does = Does(job, known, opts.shifts)
			says = ("waits on %s: %s"):format(Keys.Key(job.key), does and #does > 0 and "another key already casts what it would" or "not learned yet")
		end
		lines[#lines + 1] = ("%-18s %s"):format(job.name, says)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "In your bags:"
	local kinds = {}
	for kind in pairs(SUPPLIES) do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	for _, kind in ipairs(kinds) do
		local item = best[kind]
		lines[#lines + 1] = ("%-18s %s"):format(kind, item and (C_Item.GetItemNameByID(item) or ("item " .. item)) or "none you can use")
	end
	return table.concat(lines, "\n")
end

Shy.Command("why", "why each of your keys is where it is, or what it waits for", function()
	UI.ShowCopyBox("Your keys", Keys.Report())
end)

---------------------------------------------------------------------------
-- Every change to your key bindings, whoever makes it
---------------------------------------------------------------------------

-- What changed your keys, and when: every binding set or let go, every set of them loaded or saved, by this
-- addon, the game's own window or anything else, with the file that asked (core.db.keysLog, the last 80, kept
-- through a reload). At each log-in, which key bindings are in use and what a few keys do. /shy bindings shows it.
HOT.logMost = 80
local function Noted(what)
	local db = Shy.core.db
	if not db then return end
	db.keysLog = db.keysLog or {}
	local log = db.keysLog
	-- (the file that asked: the first line of the stack past this one)
	local who = "?"
	for line in (debugstack(3) or ""):gmatch("[^\n]+") do
		local file, at = line:match("Interface/AddOns/([^%]\"]+%.lua)[^:]*:(%d+)")
		if file and not file:find("ShyCore/Keys.lua", 1, true) then
			who = file .. ":" .. at
			break
		elseif file then
			who = file .. ":" .. at
			break
		end
	end
	log[#log + 1] = ("%s  set %s  %s  (%s)"):format(date("%H:%M:%S"), tostring(GetCurrentBindingSet()), what, who)
	while #log > HOT.logMost do table.remove(log, 1) end
end
for _, name in ipairs({ "SetBinding", "SetBindingClick", "SetBindingSpell", "SetBindingMacro", "SetBindingItem" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function(key, command)
			Noted(("%s %s = %s"):format(name, tostring(key), tostring(command)))
		end)
	end
end
for _, name in ipairs({ "LoadBindings", "SaveBindings" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function(set) Noted(("%s(%s)"):format(name, tostring(set))) end)
	end
end
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_LOGIN")
	login:SetScript("OnEvent", function()
		Noted(("logged in: Q = %s, E = %s, 1 = %s, C = %s, Mouse 4 = %s"):format(GetBindingAction("Q"), GetBindingAction("E"),
			GetBindingAction("1"), GetBindingAction("C"), GetBindingAction("BUTTON4")))
	end)
end

Shy.Command("bindings", "every change to your key bindings lately, and who made it", function()
	local log = Shy.core.db and Shy.core.db.keysLog
	UI.ShowCopyBox("Your key bindings, as they changed", log and #log > 0 and table.concat(log, "\n") or "No change to your key bindings yet.")
end)
