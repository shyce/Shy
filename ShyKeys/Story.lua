-- ShyKeys: What comes when: the keys at any level, how to play, what waits for training
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Action, Does, HOT, Hot = ns.Action, ns.Does, ns.HOT, ns.Hot
local Learns, Pressable, SUPPLIES, Scheme = ns.Learns, ns.Pressable, ns.SUPPLIES, ns.Scheme
local Seat, watched, KeyOf = ns.Seat, ns.watched, ns.KeyOf

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
	-- The jobs by what they are, never by the table holding them: Keys.Jobs lays them out afresh on every call
	-- (what you seldom press takes its key as the bars stand), so that table is a new one each time and a stamp
	-- made from it would never match. Two lists of the same jobs on the same keys are the same story.
	-- (the keys a story reads the bindings of, as they are bound now: a binding changed means another story)
	local parts = { tostring(build), Keys.Scheme(), Keys.gen, tostring(addon), UnitLevel("player") }
	for _, job in ipairs(jobs) do
		parts[#parts + 1] = tostring(job.name)
		parts[#parts + 1] = tostring(job.key)
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
	local gold, most = Shy.Money(), #out > 0 and sum or 0
	for _, step in ipairs(steps) do
		local entry = step.untrained and priced[step.name]
		if entry and entry.cost then
			step.when = entry.cost <= gold and ("train it: %s"):format(UI.Money(entry.cost, true, 10))
				or ("train it: %s short"):format(UI.Money(entry.cost - gold, true, 10))
			if entry.cost > most then most = entry.cost end
		end
	end
	-- (The most gold any of this is weighed against: at or above it, a coin changes none of the words.)
	Keys.goldMost = most > 0 and most or nil
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
	local gold = Shy.Money()
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
	local rows, gold = {}, Shy.Money()
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
		DB().keysMove = Keys.SCHEMES[scheme] and scheme or nil
		return true
	end
	if InCombatLockdown() and (Hot.On() or (watched[1] and Keys.Has(watched[1].addon))) then return false end
	DB().keysMove = scheme
	Keys.Rescheme()
	Shy:Fire("SHY_KEYS_SCHEME", scheme)
	return true
end

-- What the files after this one use.
ns.NONE = NONE
