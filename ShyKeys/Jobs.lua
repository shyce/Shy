-- ShyKeys: What a key does: a class's jobs, their macros, and what the bags hold
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...


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

local ADDON, ns = ...
local Shy = Shy
local UI = Shy.UI

local Keys = {}
Shy.Keys = Keys

-- What this addon keeps, account-wide and by profile: hotkeys (the board's state, the keys you keep and what
-- you picked), keysMove (how you move), keysGuide (the guide left on screen), keysLog (the bindings' log), and
-- by character keysBefore/keysMade/keysBuild, which are the class addon's own. Asked for as it is used: the
-- saved settings are only there from this addon's own load.
local function DB() return ns.T and ns.T.db end

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
	-- Keys the hand on the board can't reach: strafing there is no strafing for it, so the side keys strafe anyway.
	away = { LEFT = true, RIGHT = true, UP = true, DOWN = true },
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
-- that asks the highest level, where what was conjured counts CONJURED levels higher: it costs nothing and is
-- gone when you log out, so a mage's water goes first against what you bought a tier up (Conjured Fresh Water
-- before Melon Juice), and what you bought is left for when it runs out. Two tiers down it is too weak to.
-- Of two the same, the better made.
local CONJURED = 10
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
					local value = (need + (conjured[item] and CONJURED or 0)) * 10000 + (conjured[item] and 5000 or 0) + (worth or 0)
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
	Add({ name = "Bandage", key = "SHIFT-C", what = "Bandage the friend under your mouse, or yourself", supply = { "bandage" }, over = true })
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
		what = "Your mount, a favorite first. Press again to dismount", make = Mount }
	for n, key in ipairs({ "SHIFT-1", "SHIFT-2" }) do
		local race = {}
		for id, pair in pairs(Shy.KeyRacials or EMPTY) do
			-- (the spell itself on its button, no macro: its lines say what it casts, for what is learned and shown)
			race[id] = { name = pair[n][2], what = pair[n][2], spell = pair[n][1], "#showtooltip", ("/cast {%d}"):format(pair[n][1]) }
		end
		jobs[#jobs + 1] = { name = n == 1 and "Racial" or "Racial 2", key = key, asdf = key, stay = true,
			what = "Your racial ability", race = race }
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

-- What the files after this one use.
ns.Bags, ns.Before, ns.Does, ns.EMPTY = Bags, Before, Does, EMPTY
ns.FORM_KEYS, ns.Find, ns.HOT, ns.Held = FORM_KEYS, Find, HOT, Held
ns.ICON, ns.Ident, ns.Kind, ns.LAYOUT = ICON, Ident, Kind, LAYOUT
ns.Learns, ns.Lines, ns.Macro, ns.Made = Learns, Lines, Macro, Made
ns.Mine, ns.NAMED, ns.Owns, ns.PAGES = Mine, NAMED, Owns, PAGES
ns.Pick, ns.Race, ns.Ready, ns.Remove = Pick, Race, Ready, Remove
ns.SOON, ns.SUPPLIES, ns.Slots, ns.Solid = SOON, SUPPLIES, Slots, Solid
ns.Sort, ns.Theirs, ns.Where, ns.loading = Sort, Theirs, Where, loading
ns.watched, ns.DB = watched, DB
